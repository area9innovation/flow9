# Flow9 Incremental Compilation Mutation Tester

## Overview

This directory contains a Python script (`run_mutation_test.py`) designed to test the robustness and correctness of the Flow9 incremental compiler. Instead of using purely synthetic test cases, this tool leverages mutations applied to a real Flow9 program codebase.

The core idea is to simulate realistic development scenarios where files are modified, and test whether the incremental compiler correctly identifies which dependent files need recompilation and whether the final program state (success or expected error) is achieved.

## Testing Strategy

The testing strategy involves the following concepts:

1.  **Real Codebase:** Start with a working Flow9 program.
2.  **Defined Mutations:** For specific source files (`.flow`), create two alternative versions:
	*   A `.flow.non_breaking` version: Contains changes that *should not* invalidate or cause errors in dependent files when compiled incrementally. The program should still compile successfully.
	*   A `.flow.breaking` version: Contains changes (e.g., modifying exported types/functions incompatibly) that *should* cause compilation errors in dependent files when compiled incrementally.
3.  **Automated Driver:** The `run_mutation_test.py` script orchestrates the testing:
	*   Performs an initial clean compile with `update-incremental=1`.
	*   Runs a loop for a specified number of iterations. In each iteration:
		*   Randomly selects a file that has defined mutations.
		*   Randomly chooses either the `non_breaking` or `breaking` mutation.
		*   Applies the mutation (by replacing the original `.flow` file with the chosen mutation version).
		*   Performs an incremental compilation (without `update-incremental=1`).
		*   Checks if the compilation result (success or failure) matches the expectation for the applied mutation type.
	*   Restores all original `.flow` files.
	*   Performs a final incremental compilation check to ensure the project returns to a valid state.
4.  **Reproducibility:** Uses a fixed random seed by default, ensuring that a test run with the same codebase and seed is deterministic.

## File Naming Convention

To enable the script, mutation files **must** reside in the **same directory** as the original source file and follow this naming convention:

*   **Original File:** `path/to/your/module/component.flow`
*   **Non-Breaking Mutation:** `path/to/your/module/component.flow.non_breaking`
*   **Breaking Mutation:** `path/to/your/module/component.flow.breaking`

The script automatically discovers files where all three versions exist.

**Example Directory Structure:**

```

your_project/
└── src/
    ├── utils/
    │   ├── helpers.flow                 # Original
    │   ├── helpers.flow.non_breaking    # Non-breaking change version
    │   └── helpers.flow.breaking        # Breaking change version
    ├── services/
    │   └── data_processor.flow          # Original (no mutations defined here)
    └── main.flow                        # Entry point

```

## Workflow Summary

The `run_mutation_test.py` script executes the following steps:

1.  **Discover Mutations:** Scans the `--src-dir` for files matching the naming convention.
2.  **Backup Originals:** Creates temporary backups of the original `.flow` files that will be mutated.
3.  **Initial Compile:** Compiles the `--entry-point` with `update-incremental=1` to establish a baseline cache. Checks for success.
4.  **Mutation Loop:**
	*   For `N` iterations:
		*   Select random file & mutation type (`non_breaking` or `breaking`).
		*   Copy mutation file over the original `.flow` file.
		*   Compile incrementally.
		*   Verify success for `non_breaking` or failure for `breaking`.
		*   Log results for the iteration.
5.  **Restore Originals:** Copies the backed-up original files back into place.
6.  **Final Check:** Performs one last incremental compile to ensure the project is back in a working state.
7.  **Report:** Summarizes the test run (PASSED/FAILED) based on iteration results and the final check.
8.  **Cleanup:** Removes the temporary backup directory (unless `--keep-backups` is used).

## Prerequisites

*   **Python:** Version 3.7 or higher.
*   **Flow9 Compiler:** The Flow9 compiler executable (`flowcpp ...` or similar) must be accessible in your system's PATH or specified explicitly via the `--compiler-cmd` argument.

## Setup

1.  **Identify Target Files:** Choose `.flow` files within your project where you want to test incremental compilation behavior.
2.  **Create Mutations:** For each chosen target file (e.g., `target.flow`):
	*   Create `target.flow.non_breaking` with changes that should be compatible.
	*   Create `target.flow.breaking` with changes that should cause downstream errors.
	*   Ensure these files are placed in the same directory as `target.flow`.

## Usage

Run the script from your terminal:

```
bash
python run_mutation_test.py \
    --src-dir /path/to/your/project/src \
    --entry-point main.flow \
    [--iterations N] \
    [--seed S] \
    [--compiler-cmd "your_flow_compiler_command --"] \
    [--cache-dir /path/to/custom/cache] \
    [--keep-backups]

```

**Arguments:**

*   `--src-dir` (Required): Path to the root directory containing your Flow9 source code.
*   `--entry-point` (Required): Relative path from `--src-dir` to the main Flow9 file to be compiled (e.g., `main.flow`, `app/start.flow`).
*   `--compiler-cmd` (Optional): The command to execute the Flow9 compiler. Defaults to `"flowcpp --batch flow9.flow --"`. Make sure to include `--` at the end if your compiler expects options after the source file.
*   `--iterations` (Optional): Number of random mutation test cycles to run. Defaults to `20`.
*   `--seed` (Optional): Integer seed for the random number generator for reproducible runs. Defaults to `42`.
*   `--cache-dir` (Optional): Specify a path for the Flow9 incremental cache directory. If not provided, the compiler's default location/mechanism is used.
*   `--keep-backups` (Optional): If set, the temporary directory containing backups of the original `.flow` files will not be deleted after the script finishes. Useful for debugging.

## Interpreting Output

*   The script logs its actions, including which mutations are being applied and the results of each compilation check (`PASSED` or `FAILED`).
*   Compiler output (stdout/stderr) is logged at the DEBUG level and printed for failed checks.
*   A final `TEST SUMMARY` indicates the overall `PASSED` or `FAILED` status. The test fails if any iteration check fails or if the final restoration check fails.

## Benefits

*   Tests incremental compilation logic against realistic code changes and dependencies.
*   Can uncover edge cases missed by simpler, synthetic tests.
*   Provides a reproducible way (using `--seed`) to investigate specific failure scenarios.
