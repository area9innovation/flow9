# Flow Serializer (Scheme S-expression -> GPU-Optimized AST)

## Status: IMPLEMENTED ✅

The utility in Flow9 converts the standard S-expression AST (as defined by `sexpr_types.flow`) into a GPU-friendly binary format. This binary format is a flattened representation of the AST, optimized for read-only access by many GLSL threads.

## Usage

The serializer can be used in two ways:

### 1. Directly from the S-expression Interpreter

```bash
flowcpp sexpr.flow your_program.sexp glsl=output_file.glsl
```

This will:
- Parse and evaluate your S-expression program
- Generate a GLSL file containing the serialized AST and constant pool

### 2. Programmatically from Flow9 Code

```flow
import tools/orbit/sexpr/GLSL/glsl_serializer;
import tools/orbit/sexpr/GLSL/glsl_generator;

// Serialize an S-expression to binary format
result = sexprToGLSL(expr);
binaryAST = result.first;       // The binary AST as [double]
constantPool = result.second;   // The constant pool as [double]

// Generate GLSL code file
generateProgramGLSL(expr, "output.glsl");
```

## Implementation

The Flow serializer implements all the key tasks specified in the requirements:

1.  **AST Traversal:**
    *   Recursively traverses the input `Sexpr` AST provided by the parser.

2.  **Constant Pool Generation:**
    *   Identifies all unique strings within the `Sexpr` AST including string literals, variable names, constructor names, and operator names
    *   Collects these unique strings into a tree and assigns unique indices
    *   Serializes this collection into a flat numerical array (the "Constant Pool")

3.  **S-expression Node Serialization:**
    *   Converts each node in the `Sexpr` AST into its binary representation
    *   Assigns the correct primary type tag (e.g., `TAG_SSINT`, `TAG_SSLIST`)
    *   Stores literal values directly or as indices into the Constant Pool
    *   For compound types, stores pointers (indices) to their children

4.  **Output Format:**
    *   Generates the "binary program AST" as a flat array of doubles
    *   Produces a separate "Constant Pool" array
    *   Outputs a GLSL file containing both arrays as uniform data

5.  **Handling of `lambda`:**
    *   Serializes `SLambda` nodes like any other special form, with their bodies and parameter lists included recursively

The implementation resides in three main files:

- `glsl_representation.flow` - Defines constants and type tags
- `glsl_serializer.flow` - Core serialization logic
- `glsl_generator.flow` - Generates GLSL code from serialized data

This Flow9 utility acts as a compiler backend, translating the high-level `Sexpr` ADT into a low-level data format suitable for the custom GLSL execution engine.

# Using the Flow Serializer for GLSL S-expression Evaluation

This document provides detailed instructions for using the Flow serializer to convert S-expression programs into GPU-optimized binary format for GLSL evaluation.

## 1. Overview

The Flow serializer converts Scheme S-expressions (parsed and represented using the `Sexpr` type from `sexpr_types.flow`) into a GPU-friendly binary format with two main components:

1. **Binary Program AST**: A flattened numerical array representing the entire S-expression AST
2. **Constant Pool**: A flat array containing all unique strings (variable names, string literals, etc.)

This binary representation is designed for efficient access by GLSL compute shaders running in parallel.

## 2. Quick Start

### Using the S-expression Interpreter Command Line

The simplest way to use the serializer is directly from the S-expression interpreter:

```bash
flowcpp sexpr.flow your_program.sexp glsl=output_file.glsl
```

This will:
1. Parse your S-expression program
2. Evaluate it (for verification)
3. Generate a GLSL file at the specified path containing the serialized program

### Example

```bash
# Create a simple factorial program
echo '(define factorial (lambda (n) (if (= n 0) 1 (* n (factorial (- n 1))))))' > factorial.sexp

# Serialize it to GLSL
flowcpp sexpr.flow factorial.sexp glsl=factorial.glsl
```

## 3. GLSL Output Format

The generated GLSL file contains:

1. **Type Tag Definitions**: Constants for all node types (TAG_SSINT, TAG_SSLIST, etc.)
2. **Special Form IDs**: Constants for all special forms (SFORM_LAMBDA, SFORM_IF, etc.)
3. **Size Information**: Program AST and constant pool sizes
4. **Binary Program AST**: The serialized AST as a float array
5. **Constant Pool**: All string data as a float array

Example output:

```glsl
// Auto-generated GLSL code for S-expression interpreter
// AST size: 42 elements
// Constant Pool size: 15 elements

// Type tags for AST nodes
#define TAG_SSINT 1
#define TAG_SSDOUBLE 2
// ... more definitions ...

// Special form IDs
#define SFORM_AND 1
#define SFORM_BEGIN 2
// ... more definitions ...

// Program size information
#define PROGRAM_AST_SIZE 42
#define CONSTANT_POOL_SIZE 15

const float u_constant_pool[15] = float[](
	// String data as float values
	// ...
);

const float u_program_ast[42] = float[](
	// Binary AST as float values
	// ...
);
```

## 4. Using in GLSL Interpreter

To use the generated GLSL file in your interpreter:

1. **Include the generated file** in your GLSL compute shader:
   ```glsl
	 #include "factorial.glsl"
```

2. **Access the data** in your GLSL evaluator:
   ```glsl
	 // Read a node type
	 float nodeType = u_program_ast[nodeIndex];

	 if (nodeType == TAG_SSINT) {
			 // Handle integer node
			 float value = u_program_ast[nodeIndex + 1];
			 // ...
	 } else if (nodeType == TAG_SSLIST) {
			 // Handle list node
			 float childCount = u_program_ast[nodeIndex + 1];
			 float childrenOffset = u_program_ast[nodeIndex + 2];
			 // ...
	 }
```

3. **Access string data** from the constant pool:
   ```glsl
	 // Get string from constant pool
	 float stringIndex = u_program_ast[nodeIndex + 1]; // Index into constant pool
	 float stringLength = u_constant_pool[int(stringIndex)];
	 // Characters are stored after the length
```

## 5. Programmatic Usage in Flow9

If you need more control, you can use the serializer programmatically:

```flow
import tools/orbit/sexpr/GLSL/glsl_serializer;
import tools/orbit/sexpr/GLSL/glsl_generator;

// 1. Serialize an S-expression to binary format
result = sexprToGLSL(expr);
binaryAST = result.first;       // The binary AST as [double]
constantPool = result.second;   // The constant pool as [double]

// 2. Generate GLSL code with the serialized data
glslCode = generateGLSLCode(binaryAST, constantPool);

// 3. Write to a file
setFileContent("output.glsl", glslCode);

// Or use the all-in-one function
generateProgramGLSL(expr, "output.glsl");
```

## 6. Binary Format Details

### Node Representations

Each node in the binary AST has a specific format based on its type:

| Node Type | Format |
|-----------|--------|
| `SSInt` | `[TAG_SSINT, int_value]` |
| `SSDouble` | `[TAG_SSDOUBLE, double_value]` |
| `SSBool` | `[TAG_SSBOOL, 0.0/1.0]` |
| `SSString` | `[TAG_SSSTRING, pool_index, length]` |
| `SSVariable` | `[TAG_SSVARIABLE, pool_index]` |
| `SSConstructor` | `[TAG_SSCONSTRUCTOR, pool_index]` |
| `SSOperator` | `[TAG_SSOPERATOR, pool_index]` |
| `SSList` | `[TAG_SSLIST, child_count, first_child_offset]` |
| `SSVector` | `[TAG_SSVECTOR, child_count, first_child_offset]` |
| `SSSpecialForm` | `[TAG_SSSPECIALFORM, form_id, child_count, first_child_offset]` |

### Constant Pool Format

The constant pool stores strings as follows:

```
[length, char_code_1, char_code_2, ..., length, char_code_1, ...]
```

Each string is prefixed with its length, followed by the UTF-16 character codes for each character.

## 7. Summary

The Flow serializer provides a complete solution for converting S-expressions to a GPU-friendly format. By using the direct integration with the S-expression interpreter, you can quickly generate GLSL code for any S-expression program and include it in your GLSL interpreter.

This approach enables efficient parallel evaluation of Scheme programs on the GPU, with each GLSL thread maintaining its own evaluation state while sharing the same program AST.