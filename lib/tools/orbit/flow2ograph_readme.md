# Flow to OGraph Converter

This tool generates automatic converters between Flow types (structs and unions) and OGraph representations. OGraph is a directed graph structure with equivalence classes used to efficiently represent and manipulate structured data.

## Overview

The flow2ograph tool analyzes Flow type definitions and automatically generates code to:

1. Convert Flow structs and unions to OGraph nodes
2. Convert OGraph nodes back to Flow structs and unions

This bidirectional conversion enables applications to work with Flow types normally, while also accessing the powerful graph-based operations provided by the OGraph system.

## Usage

```sh
flowcpp tools/orbit/flow2ograph.flow -- --file=/path/to/your/types.flow
```

This will generate a new file named `types_ograph.flow` in the same directory as your input file. This new file will contain all the conversion functions for the types defined in your original file.

## Generated Code

For each type definition in your Flow file, the tool generates two functions:

### For Structs

```flow
// Convert MyStruct to OGraph node
myStruct2ograph(graph : OGraph, value : MyStruct) -> int;

// Convert OGraph node to MyStruct
ograph2myStruct(graph : OGraph, nodeId : int) -> MyStruct;
```

### For Unions

```flow
// Convert MyUnion to OGraph node
myUnion2ograph(graph : OGraph, value : MyUnion) -> int;

// Convert OGraph node to MyUnion
ograph2myUnion(graph : OGraph, nodeId : int) -> MyUnion;
```

## Type Support

The converter supports the following types:

- Basic types: int, double, string, bool
- Arrays: [type]
- Custom structs and unions
- Nested combinations of the above

## OGraph Structure

The OGraph structure provides a powerful way to represent and manipulate data:

- **Nodes**: Represent structs, union variants, and primitive values
- **Equivalence Classes**: Group equivalent expressions
- **Domains**: Categorize nodes by their source (e.g., "flow" for Flow types)

## Example

If you have the following Flow types:

```flow
Person(
	name : string,
	age : int
);

Shape ::= Circle, Rectangle, Triangle;
	Circle(radius : double);
	Rectangle(width : double, height : double);
	Triangle(a : double, b : double, c : double);
```

The tool will generate conversion functions that create OGraph representations of these types, with nodes for each struct and union variant.