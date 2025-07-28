# Flow9 TypeScript Integration Test

This project demonstrates how to integrate Flow9 code with TypeScript, including complete type safety, bundling, and minification.

## Status: ✅ COMPLETE

✅ A way to export a JS library with all exported Flow names & types exposed  
✅ Generate the .d.ts file for these in the right structure  
✅ Figure out how to compile TS file with imported Flow code using standard TS compilation workflows  
✅ Figure out how to minify the Flow code  
✅ **NEW:** Flow unions properly translated to TypeScript union types  
✅ **NEW:** Structs use `kind` discriminant field for TypeScript namespace compatibility  
✅ **NEW:** Complete type safety with Flow structs and unions in TypeScript  
✅ **NEW:** Working pattern matching on union types  
✅ **NEW:** Full build pipeline with bundling and minification  
✅ **NEW:** Comprehensive test suite (27 tests passing)  

🎯 **Future work:**
- Figure out how to call TS code from Flow with shared state
- Figure out how to call trender into DOM from TS

https://github.com/area9innovation/flow9/blob/master/doc/tropic.markdown#built-in-rendering

## Overview

This test case demonstrates complete Flow9 to TypeScript integration:

1. **Flow9 Code**: `flow_export.flow` exports structs, unions, and functions
   - `Foo` struct with simple fields
   - `Shape` union (Circle | Rectangle | Triangle) with pattern matching
   - `Result<T>` generic union (Success<T> | Error) with type parameters
   - Functions that work with these types using proper union discrimination

2. **Generated Types**: TypeScript `.d.ts` files with perfect type mapping
   - Structs become TypeScript interfaces with `kind` discriminant
   - Unions become TypeScript union types (e.g., `Shape = Circle | Rectangle | Triangle`)
   - Generic types are properly mapped (e.g., `Result<T> = Success<T> | Error`)
   - Constructor functions with correct type signatures

3. **TypeScript Integration**: Full type safety and union type support
   - Pattern matching works correctly on union discriminants
   - Type-safe struct creation and access
   - Generic union types work with type parameters
   - Compile-time type checking prevents runtime errors

4. **Build Pipeline**: Production-ready bundling and minification
   - Complete build system with TypeScript compilation
   - Webpack bundling for deployment
   - Terser minification for production
   - Comprehensive test suite with 27 passing tests

## Generated Files

### Flow Compilation
- `flow_export.js` - Compiled JavaScript from Flow code
- `types/` - Generated TypeScript definitions
  - `flow_export.d.ts` - Types for our exports
  - `maybe.d.ts` - Maybe type definitions
  - `index.d.ts` - Re-exports all types

### TypeScript Code
- `src/main.ts` - Main TypeScript program using Flow exports
- `src/flow-wrapper.ts` - Bridge between Flow JS and TypeScript types

## Project Structure

```
├── flow_export.flow          # Original Flow code
├── flow_export.js            # Compiled Flow JavaScript
├── compile.sh                # Flow compilation script
├── types/                    # Generated TypeScript definitions
│   ├── index.d.ts
│   ├── flow_export.d.ts
│   └── maybe.d.ts
├── src/                      # TypeScript source code
│   ├── main.ts
│   └── flow-wrapper.ts
├── dist/                     # Build output
│   ├── bundle.js             # Bundled code
│   └── bundle.min.js         # Minified bundle
├── package.json              # Dependencies and scripts
├── tsconfig.json             # TypeScript configuration
├── webpack.config.js         # Webpack bundling configuration
├── build.sh                  # Complete build script
└── test.js                   # Test runner
```

## Building and Running

### Prerequisites
- Node.js (v16 or later)
- npm
- Flow9 compiler (for recompiling Flow code)

### Quick Start

1. **Install dependencies**:
   ```bash
	 npm install
```

2. **Build everything**:
   ```bash
	 ./build.sh
```

3. **Run the program**:
   ```bash
	 node dist/bundle.js
```

4. **Run tests**:
   ```bash
	 node test.js
```

### Individual Build Steps

```bash
# Compile Flow code (generates JS and .d.ts files)
./compile.sh

# Type check TypeScript
npm run type-check

# Compile TypeScript
npm run compile

# Bundle with webpack
npm run bundle

# Minify
npm run minify

# Development mode (watch for changes)
npm run dev
```

## Features Demonstrated

### Union Type Integration
- **Flow unions** → **TypeScript union types**: `Shape ::= Circle | Rectangle | Triangle` becomes `type Shape = Circle | Rectangle | Triangle`
- **Discriminant fields**: All structs include `kind: number` for runtime discrimination
- **Pattern matching**: Flow's `switch` expressions work with TypeScript's union types
- **Generic unions**: `Result<?>` becomes `Result<T>` with proper type parameter mapping
- **Type safety**: TypeScript compiler enforces correct union usage at compile time

### Struct to Interface Mapping
- Flow structs become TypeScript interfaces with readonly fields
- Constructor functions generated automatically (`createFoo`, `createCircle`, etc.)
- Proper type signatures for all exported functions
- `kind` discriminant field enables runtime type checking

### Integration Pattern
- Direct import from generated Flow JavaScript: `import { Flow } from './flow_export.js'`
- Type-only imports for compile-time safety: `import type { Shape, Result } from './flow_export.js'`
- No wrapper needed - direct Flow function calls with TypeScript type safety
- Runtime discrimination via `kind` field matches TypeScript union types

### Build Pipeline
- Flow compilation with TypeScript definition generation (`tsd=1`, `js-namespace=1`)
- TypeScript compilation with strict type checking
- Webpack bundling for deployment targets
- Terser minification for production
- Comprehensive test suite (27 tests) validating type safety

### Example Usage

```typescript
import { Flow, type Foo, type Shape, type Result } from './flow_export.js';

// Type-safe struct creation
const foo: Foo = Flow.createFoo(42);
Flow.addFoo(foo);

// Union types with discriminant-based pattern matching
const shapes: Shape[] = [
	Flow.createCircle(5.0),           // Circle with kind: 11
	Flow.createRectangle(10.0, 8.0),  // Rectangle with kind: 14
	Flow.createTriangle(6.0, 4.0)     // Triangle with kind: 16
];

// TypeScript knows these are Shape union types
for (const shape of shapes) {
	const area = Flow.calculateArea(shape);  // Flow function handles discrimination
	const type = Flow.getShapeType(shape);   // Returns: "circle" | "rectangle" | "triangle"
	console.log(`${type}: area = ${area}`);
}

// Generic union types
const result: Result<number> = Flow.createSuccessResult(42);  // Success<number>
const error: Result<number> = Flow.createErrorResult("fail"); // Error

// Pattern matching in Flow functions
console.log(Flow.handleResult(result)); // "Success: 42"
console.log(Flow.handleResult(error));  // "Error: fail"

// TypeScript enforces type safety
function processShape(shape: Shape): number {
	// TypeScript knows shape.kind exists and discriminates the union
	return Flow.calculateArea(shape);  // Type-safe!
}
```

## Configuration Files

- **`tsconfig.json`**: TypeScript compiler options with strict type checking
- **`webpack.config.js`**: Bundles TypeScript with Flow JS for Node.js target
- **`.eslintrc.js`**: ESLint rules for TypeScript code quality
- **`package.json`**: Dependencies and build scripts

## Output Analysis

The build produces:
- **`dist/bundle.js`**: Complete bundled application
- **`dist/bundle.min.js`**: Minified version for production
- Source maps for debugging
- Type declarations for library usage

## Extending This Setup

To add more Flow exports:

1. Add exports to `flow_export.flow`
2. Recompile: `./compile.sh` 
3. Update `flow-wrapper.ts` to re-export new functions
4. Use in TypeScript with full type safety

This demonstrates a complete integration workflow from Flow9 to TypeScript with production-ready bundling and minification.