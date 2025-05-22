import argparse
import logging
import os
import pathlib
import random
import shutil
import subprocess
import sys
import tempfile
from typing import List, Dict, Tuple, Literal, Optional

# --- Constants ---
NON_BREAKING_SUFFIX = ".flow.non_breaking"
BREAKING_SUFFIX = ".flow.breaking"
ORIGINAL_SUFFIX = ".flow"
ERROR_PATTERNS = ["Error:", "Failed to convert", "Undefined symbol", "Type mismatch"]

# --- Logging Setup ---
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)


def find_mutation_sets(src_dir: pathlib.Path) -> List[pathlib.Path]:
    """
    Finds files for which .flow, .flow.non_breaking, and .flow.breaking versions exist.

    Args:
        src_dir: The root directory to search within.

    Returns:
        A list of Path objects representing the base path of each valid mutation set
        (e.g., /path/to/src/module/component if component.flow,
         component.flow.non_breaking, component.flow.breaking exist).
    """
    mutation_sets = []
    logging.info(f"Searching for mutation sets in {src_dir}...")
    # Iterate through potential non-breaking files
    for nb_file in src_dir.rglob(f"*{NON_BREAKING_SUFFIX}"):
        base_path_str = str(nb_file).removesuffix(NON_BREAKING_SUFFIX)
        base_path = pathlib.Path(base_path_str)
        original_file = base_path.with_suffix(ORIGINAL_SUFFIX)
        breaking_file = base_path.with_suffix(BREAKING_SUFFIX)

        if original_file.is_file() and breaking_file.is_file():
            logging.debug(f"Found valid mutation set for: {base_path}")
            mutation_sets.append(base_path)
        else:
            logging.debug(f"Skipping incomplete set for: {base_path}")
            if not original_file.is_file():
                logging.debug(f"  Missing: {original_file}")
            if not breaking_file.is_file():
                 logging.debug(f"  Missing: {breaking_file}")


    if not mutation_sets:
        logging.warning(f"No complete mutation sets found in {src_dir}")
    else:
         logging.info(f"Found {len(mutation_sets)} valid mutation sets.")
    return mutation_sets


def backup_originals(
    mutation_bases: List[pathlib.Path], backup_dir: pathlib.Path
) -> Dict[pathlib.Path, pathlib.Path]:
    """
    Copies the original .flow files corresponding to mutation bases to a backup directory.

    Args:
        mutation_bases: List of base paths for mutation sets.
        backup_dir: The directory to store backups in.

    Returns:
        A dictionary mapping original file paths to their backup locations.
    """
    backup_mapping = {}
    logging.info(f"Backing up original files to {backup_dir}...")
    backup_dir.mkdir(parents=True, exist_ok=True)
    for base_path in mutation_bases:
        original_file = base_path.with_suffix(ORIGINAL_SUFFIX)
        # Preserve relative structure within the backup directory
        relative_path = original_file.relative_to(base_path.parent.parent) # Assuming src dir structure
        backup_path = backup_dir / relative_path
        backup_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            shutil.copy2(original_file, backup_path)  # copy2 preserves metadata
            backup_mapping[original_file] = backup_path
            logging.debug(f"Backed up {original_file} to {backup_path}")
        except Exception as e:
            logging.error(f"Failed to backup {original_file}: {e}")
            # Decide whether to continue or raise the exception
            raise  # Re-raise to stop the process if backup fails

    logging.info(f"Backed up {len(backup_mapping)} original files.")
    return backup_mapping


def restore_originals(backup_mapping: Dict[pathlib.Path, pathlib.Path]):
    """Restores original files from their backups."""
    logging.info("Restoring original files from backups...")
    restored_count = 0
    for original_file, backup_path in backup_mapping.items():
        if backup_path.exists():
            try:
                shutil.copy2(backup_path, original_file)
                logging.debug(f"Restored {original_file} from {backup_path}")
                restored_count += 1
            except Exception as e:
                 logging.error(f"Failed to restore {original_file} from {backup_path}: {e}")
                 # Consider how critical restoration failure is
        else:
             logging.warning(f"Backup file {backup_path} not found for {original_file}. Cannot restore.")
    logging.info(f"Restored {restored_count} files.")

def compile_and_check(
    compiler_cmd: List[str],
    entry_point_path: pathlib.Path,
    expected_result: Literal["success", "failure"],
    context_info: str,
    compile_options: Optional[List[str]] = None,
    cache_dir: Optional[pathlib.Path] = None,
) -> bool:
    """
    Runs the compiler and checks if the outcome matches the expected result.

    Args:
        compiler_cmd: The base command for the compiler (e.g., ['flowcpp', '--batch', 'flow9.flow', '--']).
        entry_point_path: Path to the main Flow file to compile.
        expected_result: "success" or "failure".
        context_info: A string describing the current test step (for logging).
        compile_options: Additional options like ["update-incremental=1"].
        cache_dir: Specific cache directory to use (optional).

    Returns:
        True if the actual result matches the expected result, False otherwise.
    """
    command = compiler_cmd + [str(entry_point_path)]
    if compile_options:
        command.extend(compile_options)
    command.append("verbose=1") # Always add verbose for logging

    logging.info(f"--- Compiling {entry_point_path.name} ({context_info}) ---")
    logging.debug(f"Running command: {' '.join(command)}")

    env = os.environ.copy()
    if cache_dir:
        env["FLOW_CACHE_DIR"] = str(cache_dir)
        logging.debug(f"Using FLOW_CACHE_DIR={cache_dir}")

    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False, # Don't raise exception on non-zero exit code
            env=env,
        )
        output = f"Exit Code: {result.returncode}\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
        logging.debug(f"Compiler Output:\n{output}") # Log full output for debugging

        actual_result: Literal["success", "failure"] = "success"
        if result.returncode != 0:
            actual_result = "failure"
        else:
            # Even with exit code 0, check output for known error patterns
            full_output = result.stdout + result.stderr
            if any(pattern in full_output for pattern in ERROR_PATTERNS):
                 logging.warning("Compiler exited 0 but error patterns found in output.")
                 actual_result = "failure"


        if actual_result == expected_result:
            logging.info(f"--- PASSED: Expected {expected_result}, got {actual_result} for {context_info} ---")
            return True
        else:
            logging.error(f"--- FAILED: Expected {expected_result}, got {actual_result} for {context_info} ---")
            # Log relevant parts of the output on failure
            print(f"Relevant output for failure ({context_info}):\n"
                  f"Exit Code: {result.returncode}\n"
                  f"{result.stdout[-500:]}\n{result.stderr[-500:]}", file=sys.stderr) # Print last 500 chars
            return False

    except FileNotFoundError:
        logging.error(f"Compiler command not found: {command[0]}. Please check path or configuration.", exc_info=True)
        return False
    except Exception as e:
        logging.error(f"An unexpected error occurred during compilation: {e}", exc_info=True)
        return False


def main():
    parser = argparse.ArgumentParser(description="Run incremental compilation mutation tests.")
    parser.add_argument(
        "--src-dir", type=pathlib.Path, required=True, help="Root directory of the source code."
    )
    parser.add_argument(
        "--entry-point", type=str, required=True, help="Relative path from src-dir to the main entry point file (e.g., main.flow)."
    )
    parser.add_argument(
        "--compiler-cmd",
        type=str,
        default="flowcpp --batch flow9.flow --",
        help="Base command to run the Flow9 compiler.",
    )
    parser.add_argument(
        "--iterations", type=int, default=20, help="Number of random mutation iterations."
    )
    parser.add_argument(
        "--seed", type=int, default=42, help="Random seed for reproducibility."
    )
    parser.add_argument(
        "--cache-dir", type=pathlib.Path, default=None, help="Specify a directory for the incremental cache (optional, uses compiler default otherwise)."
    )
    parser.add_argument(
        "--keep-backups", action="store_true", help="Keep the backup directory after the script finishes."
    )


    args = parser.parse_args()

    # Validate paths
    if not args.src_dir.is_dir():
        logging.error(f"Source directory not found: {args.src_dir}")
        sys.exit(1)
    entry_point_path = args.src_dir / args.entry_point
    if not entry_point_path.is_file():
         logging.error(f"Entry point file not found: {entry_point_path}")
         sys.exit(1)

    compiler_cmd_list = args.compiler_cmd.split()

    # Seed random generator
    random.seed(args.seed)
    logging.info(f"Using random seed: {args.seed}")

    # --- Preparation ---
    mutation_bases = find_mutation_sets(args.src_dir)
    if not mutation_bases:
        logging.error("No valid mutation sets found. Exiting.")
        sys.exit(1)

    # Create a temporary directory for backups
    backup_dir_obj = tempfile.TemporaryDirectory(prefix="flow_mutation_backup_")
    backup_dir = pathlib.Path(backup_dir_obj.name)
    backup_mapping: Dict[pathlib.Path, pathlib.Path] = {}
    overall_success = True
    final_check_passed = False


    try:
        backup_mapping = backup_originals(mutation_bases, backup_dir)
        if len(backup_mapping) != len(mutation_bases):
             logging.error("Failed to back up all necessary original files. Aborting.")
             sys.exit(1) # Or handle more gracefully

        # --- Initial Compilation ---
        logging.info("=== STEP 1: Initial clean compile with update-incremental=1 ===")
        if not compile_and_check(
            compiler_cmd_list,
            entry_point_path,
            expected_result="success",
            context_info="initial compile",
            compile_options=["update-incremental=1"],
            cache_dir=args.cache_dir
        ):
            logging.error("Initial compilation failed. Aborting tests.")
            overall_success = False
            sys.exit(1) # Cannot proceed if initial compile fails

        # --- Mutation Loop ---
        logging.info(f"=== STEP 2: Running {args.iterations} random mutation tests ===")
        failed_iterations = 0
        current_mutation_state: Dict[pathlib.Path, str] = {} # Track which file has which mutation

        for i in range(args.iterations):
            iteration_num = i + 1
            logging.info(f"--- Iteration {iteration_num}/{args.iterations} ---")

            # Pick a random file base to mutate
            base_path = random.choice(mutation_bases)
            src_file = base_path.with_suffix(ORIGINAL_SUFFIX)

            # Pick a random mutation type
            mutation_type: Literal["non_breaking", "breaking"] = random.choice(["non_breaking", "breaking"])
            mutation_suffix = NON_BREAKING_SUFFIX if mutation_type == "non_breaking" else BREAKING_SUFFIX
            mutation_source_file = base_path.with_suffix(mutation_suffix)
            expected_result: Literal["success", "failure"] = "success" if mutation_type == "non_breaking" else "failure"

            logging.info(f"Applying mutation: {mutation_type} to {src_file.relative_to(args.src_dir)} (from {mutation_source_file.name})")

            try:
                shutil.copy2(mutation_source_file, src_file)
                current_mutation_state[src_file] = mutation_type # Record current state
            except Exception as e:
                 logging.error(f"Failed to apply mutation {mutation_source_file} to {src_file}: {e}")
                 overall_success = False
                 failed_iterations += 1
                 continue # Skip compilation check if copy failed


            # Compile incrementally and check the result
            context_info = f"iteration {iteration_num}, {mutation_type} mutation on {src_file.relative_to(args.src_dir)}"
            if not compile_and_check(
                compiler_cmd_list,
                entry_point_path,
                expected_result=expected_result,
                context_info=context_info,
                cache_dir=args.cache_dir
            ):
                overall_success = False
                failed_iterations += 1
                logging.error(f"Iteration {iteration_num} FAILED.")
                # Decide whether to stop on first failure or continue
                # break # Uncomment to stop on first failure
            else:
                 logging.info(f"Iteration {iteration_num} PASSED.")

            # Option: Restore this specific file immediately?
            # shutil.copy2(backup_mapping[src_file], src_file)
            # Or leave mutations cumulative (current behavior)


        logging.info(f"Mutation testing loop finished with {failed_iterations} failures out of {args.iterations} iterations.")

    finally:
        # --- Final Restoration and Check ---
        logging.info("=== STEP 3: Restoring all original files ===")
        if backup_mapping: # Only restore if backups were successfully created
            restore_originals(backup_mapping)
        else:
            logging.warning("No backup mapping available, skipping restoration.")


        logging.info("=== STEP 4: Final compilation check with restored originals (incremental) ===")
        # This checks if the compiler + cache can recover to a working state after all mutations
        if overall_success: # Only run final check if loop seemed okay or we want to see recovery
            final_check_passed = compile_and_check(
                compiler_cmd_list,
                entry_point_path,
                expected_result="success",
                context_info="final check with restored originals",
                cache_dir=args.cache_dir
            )
            if not final_check_passed:
                overall_success = False
        else:
             logging.warning("Skipping final check because errors occurred during mutation loop.")
             final_check_passed = False # Mark as failed if loop failed

        # Clean up the temporary backup directory unless requested otherwise
        if not args.keep_backups:
            logging.info("Cleaning up backup directory...")
            backup_dir_obj.cleanup() # Safely removes the temp directory
        else:
             logging.info(f"Keeping backup directory: {backup_dir}")


    # --- Report Result ---
    logging.info("=== TEST SUMMARY ===")
    if overall_success and final_check_passed:
        logging.info("Overall Result: PASSED")
        sys.exit(0)
    else:
        logging.error("Overall Result: FAILED")
        if failed_iterations > 0:
            logging.error(f"  - {failed_iterations} failure(s) detected during mutation iterations.")
        if not final_check_passed:
            logging.error("  - Failure detected during final check with restored originals.")
        sys.exit(1)


if __name__ == "__main__":
    main()