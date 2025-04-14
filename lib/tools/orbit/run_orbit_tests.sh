#!/bin/bash

# Orbit Test Suite Runner
# This script runs all .orb files in a directory and captures their output

# Default settings
TEST_DIR="tests"
OUTPUT_DIR="test_output"
TRACE=0
VERBOSE=0
TIMEOUT=10  # Timeout in seconds

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
    --help)
      echo "Orbit Test Suite Runner"
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --test-dir=DIR    Directory containing test files (default: 'tests')"
      echo "  --output-dir=DIR  Directory to save test outputs (default: 'test_output')"
      echo "  --timeout=SECONDS Maximum time to allow a test to run (default: 10 seconds)"
      echo "  --trace           Enable detailed tracing of interpretation steps"
      echo "  --verbose         Show detailed output for each test"
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
  OUTPUT=$(timeout --kill-after=2 $TIMEOUT flowcpp --batch orbit.flow -- $TRACE_PARAM "$TEST_FILE" 2>&1)
  EXIT_CODE=$?
  
  # Save the output
  echo "$OUTPUT" > "$OUTPUT_FILE"
  
  # Update counters
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  
  # Check timeout status
  if [ $EXIT_CODE -eq 124 ] || [ $EXIT_CODE -eq 137 ]; then
    STATUS="TIMEOUT"
    echo "TIMEOUT after $TIMEOUT seconds" >> "$OUTPUT_FILE"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    FAILURE_LIST="$FAILURE_LIST $FILE_NAME(timeout)"
  # Check if the test passed
  elif [ $EXIT_CODE -eq 0 ] && echo "$OUTPUT" | grep -q "Result:"; then
    STATUS="PASSED"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    STATUS="FAILED"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    FAILURE_LIST="$FAILURE_LIST $FILE_NAME"
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

# Return number of failed tests
exit $FAILED_TESTS