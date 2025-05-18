#!/bin/bash

# Orbit Test Suite Runner
# This script runs all .orb files in a directory and captures their output

# Default settings
TEST_DIR="tests"
OUTPUT_DIR="test_output"
EXPECTED_DIR="expected_output"  # Directory for expected outputs
TRACE=0
SEXPR=0  # Flag for using the S-expression evaluation engine (used ONLY if not comparing)
COMPARE_ENGINES=0  # Flag to run each test with both engines and compare execution results
SEXPR_ROUNDTRIP=0  # Flag to PERFORM an additional SExpr->Orbit->SExpr roundtrip integrity check
VERBOSE=0
TIMEOUT=10  # Timeout in seconds
GENERATE_EXPECTED=0  # Flag to generate expected output files
CLEANUP=0  # Flag to check for and optionally remove obsolete output files
REMOVE_OBSOLETE=0  # Flag to actually remove obsolete files (requires --cleanup)

# Function to clean up output files by removing timing information and exit codes
# which cause unnecessary diffs in git
clean_output_file() {
	local file="$1"
	# Create a temporary file
	local tmpfile="${file}.tmp"

	# Remove timing information, exit code reporting, and irrelevant warnings
	sed -E '/done in [0-9]+.[0-9]+s/d' "$file" |
		sed -E '/cgihost->quitCode == [0-9]+/d' |
		sed -E '/app->exec() == [0-9]+/d' |
		sed -E '/QStandardPaths: wrong permissions/d' > "$tmpfile"

	# Replace original file with cleaned version
	mv "$tmpfile" "$file"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
	case $1 in
		--test-dir=*)
			TEST_DIR="${1#*=}"
			shift
			;;
		--output-dir=*)
			OUTPUT_DIR="${1#*=}"
			shift
			;;
		--timeout=*)
			TIMEOUT="${1#*=}"
			shift
			;;
		--trace)
			TRACE=1
			shift
			;;
		# --sexpr flag is now only relevant when NOT comparing engines
		--sexpr)
			SEXPR=1
			shift
			;;
		--compare-engines)
			COMPARE_ENGINES=1
			shift
			;;
		# --sexpr-roundtrip now ONLY triggers the additional check
		--sexpr-roundtrip)
			SEXPR_ROUNDTRIP=1
			shift
			;;
		# --compare-with-roundtrip enables BOTH comparison AND the check
		--compare-with-roundtrip)
			COMPARE_ENGINES=1
			SEXPR_ROUNDTRIP=1
			shift
			;;
		--verbose)
			VERBOSE=1
			shift
			;;
		--generate-expected)
			GENERATE_EXPECTED=1
			shift
			;;
		--cleanup)
			CLEANUP=1
			shift
			;;
		--remove-obsolete)
			CLEANUP=1
			REMOVE_OBSOLETE=1
			shift
			;;
		--help)
			echo "Orbit Test Suite Runner"
			echo "Usage: $0 [options]"
			echo "Options:"
			echo "  --test-dir=DIR    Directory containing test files (default: 'tests')"
			echo "  --output-dir=DIR  Directory to save test outputs (default: 'test_output')"
			echo "  --timeout=SECONDS Maximum time to allow a test to run (default: 10 seconds)"
			echo "  --trace           Enable detailed tracing of interpretation steps"
			echo "  --sexpr           Use the S-expression evaluation engine (only if not using --compare-engines)"
			echo "  --sexpr-roundtrip Perform an additional check of the SExpr->Orbit->SExpr roundtrip integrity"
			echo "  --compare-engines Run each test with both default and SExpr engines and compare execution results"
			echo "  --compare-with-roundtrip  Compare engine execution results AND perform the SExpr roundtrip integrity check"
			echo "  --verbose         Show detailed output for each test"
			echo "  --generate-expected  Generate expected output files from current outputs"
			echo "  --cleanup         Check for obsolete output files (test cases that no longer exist)"
			echo "  --remove-obsolete Check for AND remove obsolete output files"
			echo "  --help            Show this help message"
			exit 0
			;;
		*)
			echo "Unknown option: $1"
			echo "Use --help for usage information"
			exit 1
			;;
	esac
done

# Check if test directory exists
if [ ! -d "$TEST_DIR" ]; then
	echo "Error: Test directory '$TEST_DIR' does not exist or is not a directory"
	exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Create expected output directory if generating expected outputs
if [ $GENERATE_EXPECTED -eq 1 ]; then
	mkdir -p "$EXPECTED_DIR"
	echo "Will generate expected output files in: $EXPECTED_DIR"
fi

# Find all .orb files in the test directory
TEST_FILES=$(find "$TEST_DIR" -name "*.orb" | sort)

# Initialize counters and arrays
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
FAILURE_LIST=""
ROUNDTRIP_FAILURES=0
ROUNDTRIP_FAILURE_LIST=""

# Summary file path
SUMMARY_FILE="$OUTPUT_DIR/_summary.txt"

# Start summary file
echo "Orbit Test Suite Results" > "$SUMMARY_FILE"
echo "======================" >> "$SUMMARY_FILE"
echo "Run at: $(date)" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

echo "Running Orbit test suite from directory: $TEST_DIR"
echo "Saving output to: $OUTPUT_DIR"

# Process each test file
for TEST_FILE in $TEST_FILES; do
	# Extract just the filename without path
	FILE_NAME=$(basename "$TEST_FILE")

	# Create output filename for the primary execution result
	OUTPUT_FILE="$OUTPUT_DIR/${FILE_NAME%.orb}.output"

	# Prepare base parameters
	PARAMS=""
	if [ $TRACE -eq 1 ]; then
		PARAMS="$PARAMS trace=1"
	fi

	# Determine primary execution parameters and run
	PRIMARY_PARAMS="$PARAMS"
	PRIMARY_EXIT_CODE=0
	PRIMARY_OUTPUT=""

	if [ $COMPARE_ENGINES -eq 1 ]; then
		# --- Engine Comparison Mode ---
		echo "Running test (comparing engines): $FILE_NAME"

		# Run with default engine
		echo "  - Running with default engine"
		DEFAULT_PARAMS="$PARAMS" # Default engine doesn't need specific flags
		DEFAULT_OUTPUT=$(timeout --kill-after=2 $TIMEOUT orbit $DEFAULT_PARAMS "$TEST_FILE" 2>&1 | grep -v "Flow compiler" | grep -v "Processing 'tools/orbit/orbit'" | sed '/^$/d')
		DEFAULT_EXIT_CODE=$?

		# Save default output and clean it
		echo "$DEFAULT_OUTPUT" > "$OUTPUT_FILE"
		clean_output_file "$OUTPUT_FILE"

		# Run with S-expression engine
		echo "  - Running with S-expression engine"
		SEXPR_ENGINE_PARAMS="$PARAMS sexpr=1"
		SEXPR_ENGINE_OUTPUT=$(timeout --kill-after=2 $TIMEOUT orbit $SEXPR_ENGINE_PARAMS "$TEST_FILE" 2>&1 | grep -v "Flow compiler" | grep -v "Processing 'tools/orbit/orbit'" | sed '/^$/d')
		SEXPR_ENGINE_EXIT_CODE=$?

		# Save SExpr engine output and clean it
		SEXPR_OUTPUT_FILE="$OUTPUT_DIR/${FILE_NAME%.orb}.sexpr.output"
		echo "$SEXPR_ENGINE_OUTPUT" > "$SEXPR_OUTPUT_FILE"
		clean_output_file "$SEXPR_OUTPUT_FILE"
		# Remove mode informational lines which would cause false differences in the diff
		sed -i '/SExpr mode: Using SExpr interpreter and pretty printer/d' "$SEXPR_OUTPUT_FILE"

		# Compare the outputs
		DIFF_OUTPUT=$(diff -u "$OUTPUT_FILE" "$SEXPR_OUTPUT_FILE")
		DIFF_EXIT_CODE=$?

		if [ $DIFF_EXIT_CODE -eq 0 ]; then
			echo "  ✓ Default and SExpr engines produced identical output"
		else
			echo "  ⚠ Engine outputs differ!"
			DIFF_SUMMARY_FILE="$OUTPUT_DIR/${FILE_NAME%.orb}.engine_diff"
			echo "$DIFF_OUTPUT" > "$DIFF_SUMMARY_FILE"
			echo "  - Differences saved to: $DIFF_SUMMARY_FILE"
		fi

		# Use the default engine's output and exit code for the primary pass/fail check
		PRIMARY_OUTPUT="$DEFAULT_OUTPUT"
		PRIMARY_EXIT_CODE=$DEFAULT_EXIT_CODE
		# Note: The pass/fail check later will still use OUTPUT_FILE (default engine's cleaned output)

	else
		# --- Single Engine Mode ---
		echo "Running test: $FILE_NAME"
		if [ $SEXPR -eq 1 ]; then
			PRIMARY_PARAMS="$PARAMS sexpr=1"
			echo "  (Using S-expression engine)"
		else
			PRIMARY_PARAMS="$PARAMS" # Default engine
			echo "  (Using default engine)"
		fi

		# Run orbit with the test file and capture the output with timeout
		PRIMARY_OUTPUT=$(timeout --kill-after=2 $TIMEOUT orbit $PRIMARY_PARAMS "$TEST_FILE" 2>&1 | grep -v "Flow compiler" | grep -v "Processing 'tools/orbit/orbit'" | sed '/^$/d')
		PRIMARY_EXIT_CODE=$?

		# Save the output and clean it
		echo "$PRIMARY_OUTPUT" > "$OUTPUT_FILE"
		clean_output_file "$OUTPUT_FILE"
		# Clean specific messages if needed (e.g., if running sexpr=1 standalone)
		if [ $SEXPR -eq 1 ]; then
			sed -i '/SExpr mode: Using SExpr interpreter and pretty printer/d' "$OUTPUT_FILE"
		fi
	fi

	# --- Perform SExpr roundtrip integrity check if requested ---
	if [ $SEXPR_ROUNDTRIP -eq 1 ]; then
		echo "  - Performing SExpr roundtrip integrity check"
		# Use base PARAMS, add sexpr-roundtrip=1, ensure sexpr=1 is NOT present
		ROUNDTRIP_CHECK_PARAMS="$PARAMS sexpr-roundtrip=1"
		ROUNDTRIP_CHECK_PARAMS=${ROUNDTRIP_CHECK_PARAMS/sexpr=1/}

		ROUNDTRIP_CHECK_OUTPUT=$(timeout --kill-after=2 $TIMEOUT orbit $ROUNDTRIP_CHECK_PARAMS "$TEST_FILE" 2>&1 | grep -v "Flow compiler" | grep -v "Processing 'tools/orbit/orbit'")
		# ROUNDTRIP_CHECK_EXIT_CODE=$? # Exit code might not be relevant here

		ROUNDTRIP_LOG_FILE="$OUTPUT_DIR/${FILE_NAME%.orb}.sexpr_roundtrip.log"
		echo "$ROUNDTRIP_CHECK_OUTPUT" > "$ROUNDTRIP_LOG_FILE"

		# Check for success message in the output
		if echo "$ROUNDTRIP_CHECK_OUTPUT" | grep -q "SUCCESS: The SExpr->Orbit->SExpr roundtrip produced identical SExpr!"; then
			echo "  ✓ SExpr roundtrip check PASSED"
		else
			echo "  ✗ SExpr roundtrip check FAILED (See $ROUNDTRIP_LOG_FILE)"
			ROUNDTRIP_FAILURES=$((ROUNDTRIP_FAILURES + 1))
			ROUNDTRIP_FAILURE_LIST="$ROUNDTRIP_FAILURE_LIST $FILE_NAME"
		fi
	fi

	# --- Determine Test Status based on primary execution result (using OUTPUT_FILE) ---
	TOTAL_TESTS=$((TOTAL_TESTS + 1))
	STATUS="UNKNOWN" # Default status

	# Check timeout status based on the primary execution exit code
	if [ $PRIMARY_EXIT_CODE -eq 124 ] || [ $PRIMARY_EXIT_CODE -eq 137 ]; then
		STATUS="TIMEOUT"
		echo "TIMEOUT after $TIMEOUT seconds" >> "$OUTPUT_FILE" # Add timeout message to the primary output file
		FAILED_TESTS=$((FAILED_TESTS + 1))
		FAILURE_LIST="$FAILURE_LIST $FILE_NAME(timeout)"
	else
		# Check against expected output file if it exists
		EXPECTED_FILE="$EXPECTED_DIR/${FILE_NAME%.orb}.expected"

		if [ -f "$EXPECTED_FILE" ]; then
			# Compare primary output file with expected output
			if diff -q "$OUTPUT_FILE" "$EXPECTED_FILE" > /dev/null; then
				STATUS="PASSED"
				PASSED_TESTS=$((PASSED_TESTS + 1))
			else
				STATUS="OUTPUT-MISMATCH"
				FAILED_TESTS=$((FAILED_TESTS + 1))
				FAILURE_LIST="$FAILURE_LIST $FILE_NAME(output-mismatch)"

				# Add diff to output file for debugging if verbose
				if [ $VERBOSE -eq 1 ]; then
					echo "\n==== EXPECTED OUTPUT DIFF (vs $OUTPUT_FILE) ====" >> "$OUTPUT_FILE"
					diff -u "$EXPECTED_FILE" "$OUTPUT_FILE" >> "$OUTPUT_FILE" # Diff expected vs actual
				fi
				# Also create a separate diff file for easier viewing
				MISMATCH_DIFF_FILE="$OUTPUT_DIR/${FILE_NAME%.orb}.expected_diff"
				diff -u "$EXPECTED_FILE" "$OUTPUT_FILE" > "$MISMATCH_DIFF_FILE"
				echo "  - Output mismatch diff saved to: $MISMATCH_DIFF_FILE"

			fi
		else
			# No expected file exists - base status on exit code and output content (heuristic)
			# Check if the primary exit code was success and output looks reasonable
			if [ $PRIMARY_EXIT_CODE -eq 0 ] && grep -q "Result:" "$OUTPUT_FILE"; then
					# Missing expected output file - create one with VERIFY marker
					mkdir -p "$EXPECTED_DIR"
					# Copy the primary output but add VERIFY marker at the end
					cat "$OUTPUT_FILE" > "$EXPECTED_FILE"
					echo "" >> "$EXPECTED_FILE" # Add a blank line for separation
					echo "VERIFY - THIS EXPECTED OUTPUT NEEDS HUMAN VERIFICATION (Generated $(date))" >> "$EXPECTED_FILE"
					echo "  Auto-generated expected output for $FILE_NAME (needs verification)"

					# Still mark as failing until verified
					STATUS="VERIFY-NEEDED"
					FAILED_TESTS=$((FAILED_TESTS + 1))
					FAILURE_LIST="$FAILURE_LIST $FILE_NAME(verify-needed)"
			else
					STATUS="FAILED"
					FAILED_TESTS=$((FAILED_TESTS + 1))
					FAILURE_LIST="$FAILURE_LIST $FILE_NAME(exit_code=$PRIMARY_EXIT_CODE)"
			fi
		fi
	fi

	# Generate expected output if requested (and test didn't timeout/fail outright)
	if [ $GENERATE_EXPECTED -eq 1 ] && [ "$STATUS" != "TIMEOUT" ] && [ "$STATUS" != "FAILED" ]; then
			EXPECTED_FILE="$EXPECTED_DIR/${FILE_NAME%.orb}.expected"
			# Copy the primary output file (cleaned default or single-engine output)
			cp "$OUTPUT_FILE" "$EXPECTED_FILE"
			echo "Generated expected output for: $FILE_NAME (using $OUTPUT_FILE)"
			# If status was VERIFY-NEEDED, remove the verify marker as we are explicitly generating
			if [ "$STATUS" == "VERIFY-NEEDED" ]; then
					sed -i '/VERIFY - THIS EXPECTED OUTPUT NEEDS HUMAN VERIFICATION/d' "$EXPECTED_FILE"
			fi
	fi

	# Add primary status to summary
	echo "$FILE_NAME: $STATUS" >> "$SUMMARY_FILE"

	# Show primary output if verbose
	if [ $VERBOSE -eq 1 ]; then
		echo "---------------------------------------------------"
		echo "Test output for $FILE_NAME ($OUTPUT_FILE):"
		echo "---------------------------------------------------"
		# Use the already saved and cleaned OUTPUT_FILE
		cat "$OUTPUT_FILE"
		echo ""
	fi
done

# --- Final Summary ---

# Add summary statistics
echo "" >> "$SUMMARY_FILE"
echo "Tests run: $TOTAL_TESTS, Passed: $PASSED_TESTS, Failed: $FAILED_TESTS" >> "$SUMMARY_FILE"

# Add failing tests if any
if [ $FAILED_TESTS -gt 0 ]; then
	echo "Failed tests:$FAILURE_LIST" >> "$SUMMARY_FILE"
fi

# Add engine comparison summary if enabled
if [ $COMPARE_ENGINES -eq 1 ]; then
	echo "" >> "$SUMMARY_FILE"
	echo "Engine Comparison Summary (Default vs SExpr)" >> "$SUMMARY_FILE"
	echo "-------------------------------------------" >> "$SUMMARY_FILE"

	# Count how many tests had differences between engines
	DIFF_COUNT=$(find "$OUTPUT_DIR" -name "*.engine_diff" | wc -l)

	if [ $DIFF_COUNT -eq 0 ]; then
		echo "All tests produced identical execution results with both engines." >> "$SUMMARY_FILE"
		echo "\nAll tests produced identical execution results with both engines."
	else
		echo "$DIFF_COUNT test(s) showed differences between engine execution results:" >> "$SUMMARY_FILE"
		echo "\n$DIFF_COUNT test(s) showed differences between engine execution results:"

		for DIFF_FILE in $(find "$OUTPUT_DIR" -name "*.engine_diff"); do
			BASE_NAME=$(basename "$DIFF_FILE" .engine_diff)
			echo "  - $BASE_NAME (see $DIFF_FILE)" >> "$SUMMARY_FILE"
			echo "  - $BASE_NAME"
		done
	fi
fi

# Add SExpr Roundtrip check summary if enabled
if [ $SEXPR_ROUNDTRIP -eq 1 ]; then
		echo "" >> "$SUMMARY_FILE"
		echo "SExpr Roundtrip Integrity Check Summary" >> "$SUMMARY_FILE"
		echo "---------------------------------------" >> "$SUMMARY_FILE"
		if [ $ROUNDTRIP_FAILURES -eq 0 ]; then
				echo "All tests PASSED the SExpr->Orbit->SExpr roundtrip integrity check." >> "$SUMMARY_FILE"
				echo "\nAll tests PASSED the SExpr->Orbit->SExpr roundtrip integrity check."
		else
				echo "$ROUNDTRIP_FAILURES test(s) FAILED the SExpr->Orbit->SExpr roundtrip integrity check:" >> "$SUMMARY_FILE"
				echo "\n$ROUNDTRIP_FAILURES test(s) FAILED the SExpr->Orbit->SExpr roundtrip integrity check:"
				for FAILED_RT_TEST in $ROUNDTRIP_FAILURE_LIST; do
						LOG_FILE="$OUTPUT_DIR/${FAILED_RT_TEST%.orb}.sexpr_roundtrip.log"
						echo "  - $FAILED_RT_TEST (see $LOG_FILE)" >> "$SUMMARY_FILE"
						echo "  - $FAILED_RT_TEST"
				done
		fi
fi


# Print summary to console
cat "$SUMMARY_FILE"

# Check for obsolete output files if requested (No changes needed in this section)
if [ $CLEANUP -eq 1 ]; then
	echo ""
	echo "Checking for obsolete output files..."
	echo "--------------------------------"

	OBSOLETE_COUNT=0
	OBSOLETE_FILES=""

	# Define all potential output file patterns to check
	declare -a OUTPUT_PATTERNS=("*.output" "*.sexpr.output" "*.engine_diff" "*.expected_diff" "*.sexpr_roundtrip.log")
	declare -a EXPECTED_PATTERNS=("*.expected")

	# Check for obsolete files in OUTPUT_DIR
	if [ -d "$OUTPUT_DIR" ]; then
		for PATTERN in "${OUTPUT_PATTERNS[@]}"; do
			shopt -s nullglob # Prevent loop from running if no files match
			for FILE in "$OUTPUT_DIR"/$PATTERN; do
					# Extract base name - needs care due to multiple possible extensions
					BASE_NAME=$(basename "$FILE")
					# Remove known extensions iteratively or use regex
					BASE_NAME=${BASE_NAME%.output}
					BASE_NAME=${BASE_NAME%.sexpr.output}
					BASE_NAME=${BASE_NAME%.engine_diff}
					BASE_NAME=${BASE_NAME%.expected_diff}
					BASE_NAME=${BASE_NAME%.sexpr_roundtrip.log}

					# Check if corresponding test file exists
					if [ ! -f "$TEST_DIR/$BASE_NAME.orb" ]; then
						OBSOLETE_COUNT=$((OBSOLETE_COUNT + 1))
						OBSOLETE_FILES="$OBSOLETE_FILES\n  $FILE"
						if [ $REMOVE_OBSOLETE -eq 1 ]; then
							echo "Removing obsolete output file: $FILE"
							rm "$FILE"
						else
							echo "Obsolete output file: $FILE"
						fi
					fi
			done
			shopt -u nullglob # Restore default behavior
		done
	fi

	# Check for obsolete files in EXPECTED_DIR
	if [ -d "$EXPECTED_DIR" ]; then
		for PATTERN in "${EXPECTED_PATTERNS[@]}"; do
			 shopt -s nullglob
			 for FILE in "$EXPECTED_DIR"/$PATTERN; do
				 BASE_NAME=$(basename "$FILE" .expected)
				 if [ ! -f "$TEST_DIR/$BASE_NAME.orb" ]; then
					 OBSOLETE_COUNT=$((OBSOLETE_COUNT + 1))
					 OBSOLETE_FILES="$OBSOLETE_FILES\n  $FILE"
					 if [ $REMOVE_OBSOLETE -eq 1 ]; then
						 echo "Removing obsolete expected file: $FILE"
						 rm "$FILE"
					 else
						 echo "Obsolete expected file: $FILE"
					 fi
				 fi
			 done
			 shopt -u nullglob
		done
	fi


	# Add obsolete files count to summary
	echo "" >> "$SUMMARY_FILE"
	if [ $OBSOLETE_COUNT -gt 0 ]; then
		echo "Found $OBSOLETE_COUNT obsolete output/expected file(s)" >> "$SUMMARY_FILE"
		echo -e "Obsolete files:$OBSOLETE_FILES" >> "$SUMMARY_FILE"
		echo ""
		if [ $REMOVE_OBSOLETE -eq 1 ]; then
			echo "Removed $OBSOLETE_COUNT obsolete file(s)"
		else
			echo "Found $OBSOLETE_COUNT obsolete file(s) (use --remove-obsolete to delete them)"
		fi
	else
		echo "No obsolete output/expected files found" >> "$SUMMARY_FILE"
		echo "No obsolete output/expected files found"
	fi
fi

# Return number of primary execution failed tests (excludes roundtrip check failures)
exit $FAILED_TESTS