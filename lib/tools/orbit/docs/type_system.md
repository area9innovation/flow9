# Type System in Orbit: Representing Types as Domains

## Introduction

This document describes how type systems can be represented and reasoned about using Orbit's core mechanism: associating expressions with **Domains** via the `:` operator. Orbit's domain-unified rewriting approach allows type information to be integrated seamlessly with other kinds of reasoning, such as mathematical properties or effects, within the same framework.

## Conceptual Overview: Types as Domains

In Orbit, there isn't a separate system for "types." Instead, terms representing types are treated like any other Domain term that can be associated with an expression node using the `:` operator.

Examples of Type Domains:
*   Primitive Types: `int`, `float`, `string`, `bool`
*   Constructed Types: `list<int>`, `map<string, bool>`, `Maybe<float>`
*   Function Types: `(int, string) -> bool`, `(float) -> float`
*   Type Variables: `?`, `??` (representing placeholders in polymorphic types)
*   Type Schemas: `forall ? . list<?> -> int` (representing generalized polymorphic types)
*   Special Types: `None`, `Any`, `Void`

An expression node in the underlying OGraph can be associated with one or more Domains simultaneously. For example, an expression might be associated with `int` (its type domain) and `Positive` (a property domain).

## Type Relationships as Domain Relationships

Relationships inherent to type systems, like subtyping, are expressed as relationships between the corresponding Domain terms.

```orbit
// Define relationships between Type Domains
int ⊂ float;       // Subtyping: int is a subtype of float
string ⊂ Any;      // All types are subtypes of Any
None ⊂ Maybe<?>;   // None is a subtype of any Maybe type

// Function subtyping (contravariant in args, covariant in return)
(A₁ → B₁) ⊂ (A₂ → B₂) if A₂ ⊂ A₁ && B₁ ⊂ B₂;

// List subtyping (covariant)
list<A> ⊂ list<B> if A ⊂ B;

// Constraints can trigger assertions
a : T₁ ⊢ a : T₂ if T₁ ⊂ T₂;
```

## Inferring Type Domains via Rewriting

Type inference is achieved in Orbit through rewrite rules that associate language constructs with their corresponding Type Domains.

```orbit
// Associating language expressions with their Type Domains

// Literals
1 => 1 : int;
3.14 => 3.14 : float;
"hello" => "hello" : string;
true => true : bool;

// Binary operators infer Type Domain based on operand Domains
a + b => (a + b) : int if a : int && b : int;
a + b => (a + b) : float if (a : float || b : float) && (a : number && b : number);
a + b => (a + b) : string if a : string || b : string; // String concatenation

// Comparisons result in Bool Domain
a == b => a == b : bool if a : T && b : T; // Requires operands have compatible domains

// Conditionals require Bool Domain for condition; result is LUB of branches
if (c) e1 else e2 => if (c) e1 else e2 : LUB(TypeDomainOf(e1), TypeDomainOf(e2)) if c : bool;
```

## Operations on Type Domains (LUB/GLB)

Type systems often rely on Least Upper Bounds (LUB) and Greatest Lower Bounds (GLB) to find common types.

```orbit
// LUB and GLB form a lattice structure over Type Domains
LUB : Semilattice; // LUB is associative, commutative, idempotent
GLB : Semilattice; // GLB is associative, commutative, idempotent

// LUB definition based on subtyping hierarchy
LUB(T₁, T₂) => T₁ if T₂ ⊂ T₁;
LUB(T₁, T₂) => T₂ if T₁ ⊂ T₂;

// Example LUB rules
LUB(int, float) => float;
LUB(list<int>, list<float>) => list<float>; // Covariance
```

## Orbit's Own Type System Implementation

Orbit can use its own rewriting capabilities to implement type inference on Orbit code. This involves:

1. **Orbit Type Domains:** Domains that represent Orbit's own types

```orbit
// Basic Type Domains for Orbit Primitives
Int ⊂ OrbitType;    // 32-bit integer
Double ⊂ OrbitType; // 64-bit floating point
String ⊂ OrbitType;
Bool ⊂ OrbitType;

// Type Domain for Orbit Functions
Function(paramDomains : list<OrbitType>, returnDomain : OrbitType) ⊂ OrbitType;

// Other Orbit-specific types
Ast ⊂ OrbitType;
DomainTerm ⊂ OrbitType; // Type for domain terms like Int, Real
```

2. **Type Inference Rules:** Rewrite rules that operate on Orbit syntax

```orbit
// Typing Literals
e => e : Int if astname(e) == "Int";
e => e : Double if astname(e) == "Double";
e => e : String if astname(e) == "String";
e => e : Bool if astname(e) == "Bool";

// Typing Binary Operations
l : Int + r : Int => (l + r) : Int;
l : Double + r : Double => (l + r) : Double;
l : String + r : String => (l + r) : String; // Concatenation

// Typing Function Applications
f(a1, a2) => f(a1, a2) : RetType
	if f : Function([P1Type, P2Type], RetType) && a1 : A1Type && a2 : A2Type
		 && CanApply([A1Type, A2Type], [P1Type, P2Type]);
```

## Environment Management Challenges

A key challenge in type inference is handling the typing environment (mapping from variables to their types). Strategies include:

1. **Context Propagation:** Passing environment explicitly through rewrite rules
2. **Multi-Pass Analysis:** First pass collects bindings, second pass applies them
3. **Graph Annotations:** Store environment information in the OGraph structure
4. **Implicit Context:** Use a context-sensitive interpretation of rewrite rules

## Example Type Inference Walkthrough

Consider this Orbit code:
```orbit
let y = 10;
let f = \x -> x + y;
f(5)
```

Inference steps:
1. `10` gets domain `Int`
2. `y` gets domain `Int` in the environment
3. Inside `\x -> x + y`, assuming `x` is `Int`:
   - `x + y` matches `l : Int + r : Int => (l + r) : Int`
   - The lambda gets domain `Function([Int], Int)`
4. `f` gets domain `Function([Int], Int)` in the environment
5. `5` gets domain `Int`
6. `f(5)` matches application rule, gets domain `Int`

## Type Error Reporting

Type errors arise from conflicting Domain associations or relationships:

```orbit
// Unification Failure: Cannot satisfy conflicting Type Domains
a : int, a : string => typeError("Type mismatch: cannot unify int and string", getContext(a));

// Subtyping Failure: Asserted subtype relation doesn't hold
a : string |- a : int => typeError("Type error: string is not a subtype of int", getContext(a)) if !(string ⊂ int);
```

## Conclusion

Representing types as Domains in Orbit provides a unified framework for type checking and inference alongside other forms of program analysis and transformation. Key advantages include:

1. **Unified Framework:** Type rules are just another set of rewrite rules operating on Domain associations.
2. **Integration:** Type information can directly interact with other domains within the same rule system.
3. **Extensibility:** Adding new type constructs or rules involves defining new Domain terms and rewrite rules.
4. **Self-Application:** Orbit can theoretically use its own rewriting system to implement type inference on Orbit code.

This approach shifts the perspective from a dedicated type system to viewing typing as one specific application of Orbit's general-purpose, domain-based rewriting capabilities.