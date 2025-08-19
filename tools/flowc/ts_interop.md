# Flow9 to TypeScript Interoperability Layer Generation Specification

TODO:

We will do it in a different way: We will compile flow in debug mode to avoid mangling, and that makes it much easier to map to TS types. This requires that the final result is mangled by a JS minifier.
For dbconnector, we do not need to expose refs directly in the types. We can just expose the flow behaviour functions.


## 1. Introduction

This document specifies the requirements and methodology for generating a TypeScript (TS) interoperability layer for Flow9 programs compiled to JavaScript (JS). The goal is to enable TypeScript projects to consume Flow9-generated JS modules with type safety and ergonomic APIs, including the use of natural field names even when interacting with mangled/optimized Flow9 JS output.

This specification is intended to guide the development of a stand-alone tool that, given metadata about exposed Flow9 types and functions, generates the necessary TypeScript definition files (`.d.ts`) and adapter modules (`.ts`).

## 2. Core Principles

### 2.1. Two-Tier Type Definitions

Two sets of TypeScript type definitions will be generated for structs and unions:

1.  **Mangled/Direct Reality Types (`*_Mangled.d.ts` or directly in a common `.d.ts`):**
    *   These types accurately reflect the JavaScript objects as they are produced and consumed by the Flow9 runtime, especially in non-debug/mangled builds.
    *   They will use mangled field names (e.g., `_0`, `_1`) and internal discriminants (e.g., `_id: number_literal`).
    *   These types are used for declaring the signatures of the raw Flow9 JS functions.

2.  **TS Facade Types (`*_Adapter.ts`):**
    *   These types provide an ergonomic, TypeScript-friendly interface using natural (original Flow9) field names and descriptive variant names for unions.
    *   This layer is for primary use by TypeScript developers.

### 2.2. Build Mode Awareness

The generation process must be aware of the Flow9 build mode (debug/readable vs. non-debug/optimized/mangled) because the JS representation of structs (field names, discriminants) differs. The generated types must correspond to the specific JS output. This specification primarily focuses on the non-debug/mangled mode for the "Mangled Reality" types, as this is the more complex case requiring adaptation. Readable/debug mode types will also be described.

### 2.3. Generation of Helper Functions

The TS Facade layer will include:
*   **Conversion functions:** To map between TS Facade types and Mangled Reality types.
*   **Wrapper functions:** For exposed Flow9 functions, handling the type conversions implicitly.

## 3. Type Mapping and Generation

This section details how each Flow9 type is represented and how its corresponding TS types and helper functions are generated.

### 3.1. Basic Types

Flow9 basic types map directly to TypeScript types. No special adapter layer is typically needed beyond direct type mapping in function signatures.

| Flow9 Type | JavaScript Runtime | TypeScript Type         | Mangled Reality   | TS Facade         |
| :--------- | :----------------- | :---------------------- | :---------------- | :---------------- |
| `int`      | `number`           | `number`                | `number`          | `number`          |
| `double`   | `number`           | `number`                | `number`          | `number`          |
| `bool`     | `boolean`          | `boolean`               | `boolean`         | `boolean`         |
| `string`   | `string`           | `string`                | `string`          | `string`          |
| `void`     | `undefined`/`null` | `void` (or `undefined`) | `void`            | `void`            |

### 3.2. Arrays

Flow9 arrays `[T]` map to JavaScript arrays.

*   **Mangled Reality (`.d.ts`):** `Mangled_T[]`
*   **TS Facade:** `Facade_T[]`
*   **Conversion:** If `T` requires conversion (e.g., it's a struct), array conversion will involve mapping each element using `T`'s conversion functions.
    ```typescript
	// Example: In *_Adapter.ts
	export function toMangledArray_Facade_T(items: Facade_T[]): Mangled_T[] {
	  return items.map(toMangled_Facade_T); // Assuming toMangled_Facade_T exists
	}
	export function fromMangledArray_Facade_T(items: Mangled_T[]): Facade_T[] {
	  return items.map(fromMangled_Facade_T); // Assuming fromMangled_Facade_T exists
	}
```

### 3.3. Refs

Flow9 `ref T` are represented as objects with a `__v` property.

*   **JS Runtime Object:** `{ __v: value_of_T }`
*   **Mangled Reality & TS Facade (`.d.ts` or common types file):**
    ```typescript
	export interface Ref<T> {
	  __v: T; // T will be the Mangled_T or Facade_T depending on context
	}
```
    If `T` itself is a type that has different mangled and facade representations (like a struct), then `Ref<Mangled_T>` would be used for the mangled reality and `Ref<Facade_T>` for the facade. Conversion helpers might be needed for the inner type.

### 3.4. Structs

#### 3.4.1. Input Metadata for Struct Generation

For each exposed Flow9 struct, the tool requires:
*   `flowStructName`: The original Flow9 name (e.g., "User").
*   `jsMangledId`: (Non-debug mode) The unique integer ID (e.g., `0`).
*   `jsReadableName`: (Debug mode) The string name used as a discriminant (e.g., `"User"`).
*   `isSingleton`: Boolean indicating if it's a Flow9 singleton struct (no fields).
*   `fields`: An array of field information:
    *   `originalName`: (e.g., "userName")
    *   `flowType`: The Flow9 type of the field.
    *   `jsMangledName`: (Non-debug mode) The mangled JS property name (e.g., `"_0"`).
    *   `jsReadableName`: (Debug mode) The JS property name (usually same as `originalName`).
    *   `tsTypeMangled`: The TypeScript type for this field in the mangled representation.
    *   `tsTypeFacade`: The TypeScript type for this field in the facade representation.

#### 3.4.2. Mangled Reality Struct Types (`.d.ts`)

*   **Non-Debug/Mangled Mode:**
    ```typescript
	// For Flow9 struct User(name: string, age: int) with ID 0, fields _0, _1
	export interface User_Mangled {
	  readonly _id: 0; // Literal type for discrimination
	  readonly _0: string; // Corresponds to 'name'
	  readonly _1: number; // Corresponds to 'age'
	}
```
*   **Debug/Readable Mode:**
    ```typescript
	export interface User_Readable {
	  readonly _name: "User"; // Literal string for discrimination
	  readonly name: string;
	  readonly age: number;
	}
```
*   **Singleton Structs (Non-Debug):**
    ```typescript
	// For Flow9 singleton AdminRole with ID 1
	export interface AdminRole_Mangled {
	  readonly _id: 1;
	}
	// JS global: declare const st_1: AdminRole_Mangled; (if applicable)
```
*   **Singleton Structs (Debug):**
    ```typescript
	export interface AdminRole_Readable {
	  readonly _name: "AdminRole";
	}
	// JS global: declare const st_AdminRole: AdminRole_Readable; (if applicable)
```

#### 3.4.3. TS Facade Struct Types (`*_Adapter.ts`)

```typescript
// For Flow9 struct User(name: string, age: int)
export interface User_TS {
	name: string;
	age: number;
	// other fields with original names and facade types
}

// For Flow9 singleton AdminRole
export interface AdminRole_TS {
	// Typically empty, or might have a 'kind' property if part of a larger union facade
}
```

#### 3.4.4. Conversion Functions for Structs (`*_Adapter.ts`)

*   **To Mangled (Non-Debug):**
    ```typescript
	export function toUserMangled(tsUser: User_TS): User_Mangled {
	  return { _id: 0, _0: tsUser.name, _1: tsUser.age };
	}
```
*   **From Mangled (Non-Debug):**
    ```typescript
	export function fromUserMangled(mangledUser: User_Mangled): User_TS {
	  // Optional: runtime check mangledUser._id === 0
	  return { name: mangledUser._0, age: mangledUser._1 };
	}
```
*   Similar functions for Debug/Readable mode (e.g., `toUserReadable`, `fromUserReadable`) would map to/from the `_name` and natural field names directly if the JS representation uses them. If the adapter is only for mangled mode, these might not be needed, or the facade types directly align.

### 3.5. Unions (Sum Types)

Flow9 unions are typically represented as a set of distinct structs, each corresponding to a union variant. Discrimination happens via the struct's `_id` (non-debug) or `_name` (debug).

#### 3.5.1. Input Metadata for Union Generation

For each exposed Flow9 union, the tool requires:
*   `flowUnionName`: The original Flow9 name (e.g., "Shape").
*   `variants`: An array of variant information. Each variant is effectively a struct:
    *   `flowVariantName`: (e.g., "Circle")
    *   `jsMangledId`: (Non-debug mode) The unique integer ID of the struct representing this variant.
    *   `jsReadableName`: (Debug mode) The string name of the struct representing this variant.
    *   `isSingletonVariant`: Boolean.
    *   `fields`: (If not singleton) Array of field information for this variant (same structure as struct fields).

#### 3.5.2. Mangled Reality Union Types (`.d.ts`)

Each variant is defined as a mangled struct type. The union type is a TypeScript union of these variant struct types.

*   **Non-Debug/Mangled Mode:**
    ```typescript
	// For Flow9 union Shape ::= Circle(radius: double) | Square(side: double)
	// Circle -> struct ID 10, field _0 for radius
	// Square -> struct ID 11, field _0 for side
	export interface Circle_Mangled {
	  readonly _id: 10;
	  readonly _0: number; // radius
	}
	export interface Square_Mangled {
	  readonly _id: 11;
	  readonly _0: number; // side
	}
	export type Shape_Mangled = Circle_Mangled | Square_Mangled;
```
*   **Debug/Readable Mode:**
    ```typescript
	export interface Circle_Readable {
	  readonly _name: "Circle";
	  readonly radius: number;
	}
	export interface Square_Readable {
	  readonly _name: "Square";
	  readonly side: number;
	}
	export type Shape_Readable = Circle_Readable | Square_Readable;
```

#### 3.5.3. TS Facade Union Types (`*_Adapter.ts`)

A discriminated union in TypeScript using a `kind` property (or similar) with natural variant names.

```typescript
export interface Circle_TS {
	kind: "Circle";
	radius: number;
}
export interface Square_TS {
	kind: "Square";
	side: number;
}
// For a singleton variant e.g. Point_TS
// export interface Point_TS { kind: "Point"; }

export type Shape_TS = Circle_TS | Square_TS;
```

#### 3.5.4. Conversion Functions for Unions (`*_Adapter.ts`)

*   **To Mangled (Non-Debug):**
    ```typescript
	export function toShapeMangled(tsShape: Shape_TS): Shape_Mangled {
	  switch (tsShape.kind) {
		case "Circle":
		  return { _id: 10, _0: tsShape.radius };
		case "Square":
		  return { _id: 11, _0: tsShape.side };
		// default: throw new Error("Unknown Shape_TS variant"); // Or handle exhaustiveness
	  }
	}
```
*   **From Mangled (Non-Debug):**
    ```typescript
	export function fromShapeMangled(mangledShape: Shape_Mangled): Shape_TS {
	  switch (mangledShape._id) {
		case 10: // Circle_Mangled
		  return { kind: "Circle", radius: mangledShape._0 };
		case 11: // Square_Mangled
		  return { kind: "Square", side: mangledShape._0 };
		default:
		  // Handle exhaustiveness for known _ids, or throw error
		  const _exhaustiveCheck: never = mangledShape;
		  throw new Error("Unknown Shape_Mangled variant id");
	  }
	}
```
*   Similar functions for Debug/Readable mode would switch on `_name` and map fields accordingly.

## 4. Function Exposure

#### 4.1. Input Metadata for Function Generation

For each exposed Flow9 function:
*   `flowFunctionName`: Original Flow9 name.
*   `jsExportedName`: The name under which the function is exported from the JS module.
*   `parameters`: An array of parameter info:
    *   `flowType`: The Flow9 type of the parameter.
    *   `tsMangledType`: The TS type for the mangled representation.
    *   `tsFacadeType`: The TS type for the facade representation.
*   `returnType`: Info for the return value:
    *   `flowType`: Flow9 type.
    *   `tsMangledType`: Mangled TS type.
    *   `tsFacadeType`: Facade TS type.

#### 4.2. Mangled Reality Function Signatures (`.d.ts`)

Declare the JS function with its mangled/direct types.

```typescript
// For a Flow9 function: processUser(u: User): bool
// JS export: flow_processUser
export declare function flow_processUser(user: User_Mangled): boolean;
```

#### 4.3. TS Facade Wrapper Functions (`*_Adapter.ts`)

Generate wrapper functions that use facade types and handle conversions.

```typescript
// Continuing example for flow_processUser
// Assuming 'User_Mangled' and 'User_TS' and conversion functions are defined
import * as FlowGenerated from './flow_generated_types'; // Contains User_Mangled, flow_processUser

export function processUser(tsUser: User_TS): boolean {
	const mangledUser = toUserMangled(tsUser); // Defined in *_Adapter.ts
	const result = FlowGenerated.flow_processUser(mangledUser);
	// Assuming boolean doesn't need 'fromMangled' conversion.
	// If result was a complex type: return fromComplexTypeMangled(result);
	return result;
}
```

## 5. Generated Output Structure (Example)

A common approach is to generate two main files:

1.  **`flow_generated_types.d.ts` (or similar name):**
    *   Contains all `*_Mangled` or `*_Readable` interface definitions for structs and unions.
    *   Contains `declare function` statements for the raw exported Flow9 JS functions.
    *   Contains generic types like `Ref<T>`.

2.  **`flow_adapter.ts` (or similar name):**
    *   Imports from `flow_generated_types.d.ts`.
    *   Contains all `*_TS` (facade) interface/type definitions.
    *   Contains all conversion functions (`to*Mangled`, `from*Mangled`).
    *   Contains all wrapper functions for exposed Flow9 routines, providing the ergonomic API.

## 6. Tool Input (Conceptual Summary)

The stand-alone generation tool would require structured input derived from the Flow9 compiler's internal representations after it has processed the source code and prepared for JavaScript generation. This input, likely serialized as JSON or a similar format by an extension to the Flow9 compiler, should detail:

*   A list of **Structs** to be exposed, each with:
    *   `originalName`: The original Flow9 struct name (e.g., "User").
        *   *Compiler Source:* `FiTypeStruct.name` (from `module.structs`), key in `FiJsOverlayGroup.structs`.
    *   `id`:
        *   *Mangled Mode:* The numeric integer ID assigned (e.g., `0`).
            *   *Compiler Source:* `FiJsStruct.id` (from `FiJsOverlayGroup.structs[originalName].id`).
        *   *Readable Mode:* The original struct name, used as the `_name` discriminant (e.g., `"User"`).
            *   *Compiler Source:* `FiTypeStruct.name` itself.
    *   `isSingleton`: Boolean, true if the struct has no arguments/fields.
        *   *Compiler Source:* Check `length(FiTypeStruct.args) == 0`.
    *   `fields`: An array of field information for non-singleton structs:
        *   `originalFieldName`: The original Flow9 field name (e.g., "userName").
            *   *Compiler Source:* `FiStructArg.name` (from `FiTypeStruct.args`).
        *   `mangledFieldName`: (Mangled Mode) The mangled JS property name (e.g., `"_0"`).
            *   *Compiler Source:* Lookup `originalFieldName` in `FiJsOverlayGroup.fieldRenamings`. Preserved if "head" or "tail".
        *   `readableFieldName`: (Readable Mode) The JS property name, usually same as `originalFieldName` or with `__` suffix for keywords.
            *   *Compiler Source:* `originalFieldName` (potentially processed by `fiJsRename` logic for keywords).
        *   `flowType`: The declared Flow9 type of the field (e.g., "string", "int", "MyOtherStruct").
            *   *Compiler Source:* `FiStructArg.type` (represented as `FiType`). This needs to be serialized into a string or structured type representation.

*   A list of **Unions**, each with:
    *   `originalName`: The original Flow9 union name (e.g., "Shape").
    *   `variants`: An array, where each element describes a variant. Each variant is treated like a struct for generation purposes:
        *   `originalVariantName`: The original Flow9 name of the variant (e.g., "Circle").
            *   *Compiler Source:* The struct name that represents the union case (`FiCase.struct`).
        *   `id`: (As per struct `id` above, specific to this variant struct).
        *   `isSingleton`: (As per struct `isSingleton` above, specific to this variant struct).
        *   `fields`: (As per struct `fields` above, specific to this variant struct).

*   A list of **Functions** to be exposed, each with:
    *   `originalName`: The original Flow9 function name.
        *   *Compiler Source:* `FiDeclaration.name`.
    *   `jsExportedName`: The name under which the function is exported/available in the generated JavaScript module.
        *   *Compiler Source:* Result of `fiJsPrefixedName(cfg, ctx, id)` or `fiJsRename(cfg, ctx, name)` based on context. Look up in `FiJsOverlayGroup.renamings` for mangled names.
    *   `parameters`: An array of parameter information:
        *   `flowType`: The Flow9 type of the parameter (e.g., "string", "User", "Shape[]").
            *   *Compiler Source:* `FiLambda.args[i].derived` (or equivalent type info from `FiDeclaration`).
    *   `returnType`:
        *   `flowType`: The Flow9 type of the return value.
            *   *Compiler Source:* `FiLambda.e0`'s type (or equivalent type info from `FiDeclaration`).

*   A **Mangling Map** (especially for non-debug/mangled builds). This provides the direct translations used by the Flow9 compiler:
    *   `structIdMap`: A map from `originalStructName` to its numeric `id` (for mangled mode) or string `_name` (for readable mode).
        *   *Compiler Source Extract From:* Iterate `FiJsOverlayGroup.structs`. Key is `originalStructName`, value is `FiJsStruct(id, _)`._name` (for readable mode).
    *   `structFieldManglingMap`: A nested map: `originalStructName` -> (`originalFieldName` -> `mangledFieldName`).
        *   *Compiler Source Extract From:* For each struct in `FiJsOverlayGroup.structs`, iterate its `FiTypeStruct.args`. For each `FiStructArg.name` (original field name), look it up in `FiJsOverlayGroup.fieldRenamings` (if mangled mode and field is not "head"/"tail").
    *   This map is essential for the tool to correctly generate the `*_Mangled.d.ts` types and the conversion functions in the adapter layer.
    *   For debug/readable builds, this map might confirm original names are used or provide the `_name` discriminant string.

*   **Configuration**:
    *   Target build mode (mangled, readable) to determine which JS representation to target for the `*_Mangled` or `*_Readable` types.
    *   Output paths for generated files.
    *   Module import paths (if the generated TS code needs to import from other TS modules).

**Point of Data Extraction from Flow9 Compiler:**

The information detailed above, particularly the contents of `FiJsOverlayGroup` (like `structs`, `fieldRenamings`, `renamings`) and the `FiProgram` structure (for original type definitions), should be collected *after* the compiler has performed its initial analysis, type checking, and generation of these internal lookup tables, but *before* or *during* the final JavaScript code string generation. An explicit step or function can be added to the Flow9 compiler backend to serialize this collected information into the required format for the stand-alone tool.

This specification provides a blueprint for creating a robust TypeScript interoperability layer, enhancing developer experience when integrating Flow9-compiled JavaScript into TypeScript projects.
