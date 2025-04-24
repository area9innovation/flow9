#!/bin/bash

# Orbit Test Suite Runner
# This script runs all .orb files in a directory and captures their output

# Default settings
TEST_DIR="tests"
OUTPUT_DIR="test_output"
EXPECTED_DIR="expected_output"  # Directory for expected outputs
TRACE=0
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
  
  # Create output filename
  OUTPUT_FILE="$OUTPUT_DIR/${FILE_NAME%.orb}.output"
  
  # Run the test
  echo "Running test: $FILE_NAME"
  
  # Prepare trace parameter if needed
  TRACE_PARAM=""
  if [ $TRACE -eq 1 ]; then
    TRACE_PARAM="trace=1"
  fi
  
  # Run orbit with the test file and capture the output with timeout
  OUTPUT=$(timeout --kill-after=2 $TIMEOUT orbit $TRACE_PARAM "$TEST_FILE" 2>&1 | grep -v "Flow compiler (3rd generation)" | grep -v "Processing 'tools/orbit/orbit' on http server" | sed '/^$/d')
  EXIT_CODE=$?
  
  # Save the output
  echo "$OUTPUT" > "$OUTPUT_FILE"
  
  # Clean up the output file to remove timing and exit code information
  clean_output_file "$OUTPUT_FILE"
  
  # Update counters
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  
  # Check timeout status
  if [ $EXIT_CODE -eq 124 ] || [ $EXIT_CODE -eq 137 ]; then
    STATUS="TIMEOUT"
    echo "TIMEOUT after $TIMEOUT seconds" >> "$OUTPUT_FILE"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    FAILURE_LIST="$FAILURE_LIST $FILE_NAME(timeout)"
  else
    # Check for expected output file
    EXPECTED_FILE="$EXPECTED_DIR/${FILE_NAME%.orb}.expected"
    
    if [ -f "$EXPECTED_FILE" ]; then
      # If expected output exists, compare with actual output
      if diff -q "$OUTPUT_FILE" "$EXPECTED_FILE" > /dev/null; then
        STATUS="PASSED"
        PASSED_TESTS=$((PASSED_TESTS + 1))
      else
        STATUS="OUTPUT-MISMATCH"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILURE_LIST="$FAILURE_LIST $FILE_NAME(output-mismatch)"
        
        # Add diff to output file for debugging if verbose
        if [ $VERBOSE -eq 1 ]; then
          echo "\n==== EXPECTED OUTPUT DIFF ====" >> "$OUTPUT_FILE"
          diff "$OUTPUT_FILE" "$EXPECTED_FILE" >> "$OUTPUT_FILE"
        fi
      fi
    else
      # Check if the output indicates a test passed
      if [ $EXIT_CODE -eq 0 ] && echo "$OUTPUT" | grep -q "Result:"; then
        # Missing expected output file - create one with VERIFY marker
        mkdir -p "$EXPECTED_DIR"
        # Copy the output but add VERIFY marker at the end
        cat "$OUTPUT_FILE" > "$EXPECTED_FILE"
        echo "VERIFY - THIS OUTPUT NEEDS HUMAN VERIFICATION" >> "$EXPECTED_FILE"
        echo "Auto-generated expected output for $FILE_NAME (needs verification)"
        
        # Still mark as failing until verified
        STATUS="VERIFY-NEEDED"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILURE_LIST="$FAILURE_LIST $FILE_NAME(verify-needed)"
      else
        STATUS="FAILED"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILURE_LIST="$FAILURE_LIST $FILE_NAME"
      fi
    fi
  fi
  
  # Generate expected output if requested
  if [ $GENERATE_EXPECTED -eq 1 ]; then
    # Only generate expected output for tests that pass with the old criteria
    if [ $EXIT_CODE -eq 0 ] && echo "$OUTPUT" | grep -q "Result:"; then
      EXPECTED_FILE="$EXPECTED_DIR/${FILE_NAME%.orb}.expected"
      cp "$OUTPUT_FILE" "$EXPECTED_FILE"
      echo "Generated expected output for: $FILE_NAME"
    fi
  fi
  
  # Add to summary
  echo "$FILE_NAME: $STATUS" >> "$SUMMARY_FILE"
  
  # Show output if verbose
  if [ $VERBOSE -eq 1 ]; then
    echo "---------------------------------------------------"
    echo "Test output for $FILE_NAME:"
    echo "---------------------------------------------------"
    echo "$OUTPUT"
    echo ""
  fi
done

# Add summary statistics
echo "" >> "$SUMMARY_FILE"
echo "Tests run: $TOTAL_TESTS, Passed: $PASSED_TESTS, Failed: $FAILED_TESTS" >> "$SUMMARY_FILE"

# Add failing tests if any
if [ $FAILED_TESTS -gt 0 ]; then
  echo "Failed tests:$FAILURE_LIST" >> "$SUMMARY_FILE"
fi

# Print summary to console
cat "$SUMMARY_FILE"

# Check for obsolete output files if requested
if [ $CLEANUP -eq 1 ]; then
  echo ""
  echo "Checking for obsolete output files..."
  echo "--------------------------------"
  
  OBSOLETE_COUNT=0
  OBSOLETE_FILES=""
  
  # Check for obsolete files in OUTPUT_DIR
  if [ -d "$OUTPUT_DIR" ]; then
    for OUTPUT_FILE in "$OUTPUT_DIR"/*.output; do
      if [ -f "$OUTPUT_FILE" ]; then
        # Extract base name without extension
        BASE_NAME=$(basename "$OUTPUT_FILE" .output)
        # Check if corresponding test file exists
        if [ ! -f "$TEST_DIR/$BASE_NAME.orb" ]; then
          OBSOLETE_COUNT=$((OBSOLETE_COUNT + 1))
          OBSOLETE_FILES="$OBSOLETE_FILES\n  $OUTPUT_FILE"
          if [ $REMOVE_OBSOLETE -eq 1 ]; then
            echo "Removing obsolete output file: $OUTPUT_FILE"
            rm "$OUTPUT_FILE"
          else
            echo "Obsolete output file: $OUTPUT_FILE"
          fi
        fi
      fi
    done
  fi
  
  # Check for obsolete files in EXPECTED_DIR
  if [ -d "$EXPECTED_DIR" ]; then
    for EXPECTED_FILE in "$EXPECTED_DIR"/*.expected; do
      if [ -f "$EXPECTED_FILE" ]; then
        # Extract base name without extension
        BASE_NAME=$(basename "$EXPECTED_FILE" .expected)
        # Check if corresponding test file exists
        if [ ! -f "$TEST_DIR/$BASE_NAME.orb" ]; then
          OBSOLETE_COUNT=$((OBSOLETE_COUNT + 1))
          OBSOLETE_FILES="$OBSOLETE_FILES\n  $EXPECTED_FILE"
          if [ $REMOVE_OBSOLETE -eq 1 ]; then
            echo "Removing obsolete expected file: $EXPECTED_FILE"
            rm "$EXPECTED_FILE"
          else
            echo "Obsolete expected file: $EXPECTED_FILE"
          fi
        fi
      fi
    done
  fi
  
  # Add obsolete files count to summary
  echo "" >> "$SUMMARY_FILE"
  if [ $OBSOLETE_COUNT -gt 0 ]; then
    echo "Found $OBSOLETE_COUNT obsolete output file(s)" >> "$SUMMARY_FILE"
    echo -e "Obsolete files:$OBSOLETE_FILES" >> "$SUMMARY_FILE"
    echo ""
    if [ $REMOVE_OBSOLETE -eq 1 ]; then
      echo "Removed $OBSOLETE_COUNT obsolete file(s)"
    else
      echo "Found $OBSOLETE_COUNT obsolete file(s) (use --remove-obsolete to delete them)"
    fi
  else
    echo "No obsolete output files found" >> "$SUMMARY_FILE"
    echo "No obsolete output files found"
  fi
fi

# Return number of failed tests
exit $FAILED_TESTS