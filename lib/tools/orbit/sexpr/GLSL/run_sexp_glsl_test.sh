#!/bin/bash

# Script to compile a .sexp file to GLSL, integrate with the interpreter, build, and run.

# Exit on any error
set -e

# --- Configuration ---
# Directory where generated GLSL data files for individual tests will be stored
GENERATED_GLSL_DATA_DIR="tests"

# Fixed filename that the main interpreter GLSL will include.
# The generated GLSL data for the current test will be copied to this path.
TARGET_INTERPRETER_DATA_FILE="${GENERATED_GLSL_DATA_DIR}/current_test_data.glsl"
# --- End Configuration ---

# Check if a .sexp file argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_sexp_file>"
    echo "Example: $0 tests/basic3.sexp"
    exit 1
fi

SEXP_INPUT_FILE="$1"

if [ ! -f "${SEXP_INPUT_FILE}" ]; then
    echo "Error: S-expression file not found: ${SEXP_INPUT_FILE}"
    exit 1
fi

# Derive a unique name for the GLSL data file generated directly from this .sexp file
SEXP_FILENAME_WITH_EXT=$(basename -- "${SEXP_INPUT_FILE}")
SEXP_BASENAME="${SEXP_FILENAME_WITH_EXT%.*}"
SPECIFIC_GENERATED_GLSL_FILE="${GENERATED_GLSL_DATA_DIR}/${SEXP_BASENAME}_data.glsl"

echo "--- Starting GLSL S-expression Test Runner ---"
echo "Input S-expression: ${SEXP_INPUT_FILE}"

# Step 1: Compile the .sexp file to its specific GLSL data file
echo "Step 1: Compiling ${SEXP_INPUT_FILE} to ${SPECIFIC_GENERATED_GLSL_FILE}..."
if ! sexpr "${SEXP_INPUT_FILE}" "glsl=${SPECIFIC_GENERATED_GLSL_FILE}"; then
    echo "ERROR: Flow S-expression compilation to GLSL failed for ${SEXP_INPUT_FILE}."
    exit 1
fi
echo "Successfully generated ${SPECIFIC_GENERATED_GLSL_FILE}"

# Step 2: Copy the specific GLSL data file to the target path used by the main interpreter
echo "Step 2: Copying ${SPECIFIC_GENERATED_GLSL_FILE} to ${TARGET_INTERPRETER_DATA_FILE}..."
if ! cp "${SPECIFIC_GENERATED_GLSL_FILE}" "${TARGET_INTERPRETER_DATA_FILE}"; then
    echo "ERROR: Failed to copy GLSL data to ${TARGET_INTERPRETER_DATA_FILE}."
    exit 1
fi
echo "Data for interpreter is now at ${TARGET_INTERPRETER_DATA_FILE}"

# Step 3: (Optional but recommended) Clean previous build artifacts
echo "Step 3: Cleaning previous build..."
if ! make clean; then
    echo "WARNING: 'make clean' encountered an issue, but proceeding."
fi

# Step 4: Build the Vulkan host and the GLSL interpreter (which now includes the new data)
echo "Step 4: Building main project (interpreter and host)..."
if ! make; then
    echo "ERROR: Project build failed (make)."
    exit 1
fi
echo "Project built successfully."

# Step 5: Run the compiled host application
echo "Step 5: Running the test via Vulkan host..."
# The output from 'make run' will be displayed directly
if ! make run; then
    echo "ERROR: Test execution failed (make run)."
    exit 1
fi

echo "--- Test run for ${SEXP_INPUT_FILE} complete. ---"
