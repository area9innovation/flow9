# Type Inference for Orbit using Orbit

## Introduction

This document explores how Orbit's own domain-based rewriting capabilities could theoretically be used to perform type inference on Orbit source code. The core idea is to treat the syntax tree of an Orbit program, as defined by the parser using `orbit.mango`, as data within an OGraph. Rewrite rules can then be defined to associate these syntax tree nodes with "Type Domains" representing their inferred types *within the Orbit language*.

This process requires defining:

1.  **Orbit Type Domains:** Simplified domains like `Int`, `Double`, `String`, `Function`, etc., representing the types of values within Orbit.
2.  **Inference Rules:** Rewrite rules that match Orbit syntax (e.g., `l + r`) and associate these expressions with the appropriate Type Domain using the `:` operator. Helpers like `astname` and `astchildren` can be used in guards (`if` conditions) if needed to inspect the structure.

**Note:** This is a conceptual outline. Handling the typing environment robustly is a key challenge.

## Representing Orbit's Types as Domains

We define Domain terms to represent the types used within Orbit itself:

```orbit
// Basic Type Domains for Orbit Primitives
Int ⊂ OrbitType;    // 32-bit integer (as per Flow9/Orbit context)
Double ⊂ OrbitType; // 64-bit floating point
String ⊂ OrbitType;
Bool ⊂ OrbitType;

// Type Domain for Orbit Functions
// Stores parameter type domains and return type domain
Function(paramDomains : list<OrbitType>, returnDomain : OrbitType) ⊂ OrbitType;

// Type Domain for AST/syntax nodes themselves (when treated as data)
Ast ⊂ OrbitType;

// Type Domain for Domain terms themselves
DomainTerm ⊂ OrbitType; // Type for things like Int, Real, etc.

// Other potential Orbit-specific types
// RuleType ⊂ OrbitType; // If rules become first-class typed values
// OgraphType ⊂ OrbitType; // If ographs become first-class typed values
Void ⊂ OrbitType; // For statements or functions with no return value

// A top type (superclass of all Orbit types)
AnyType ⊂ OrbitType; // All types are subtypes of AnyType

// Hierarchy example
Int ⊂ Number;
Double ⊂ Number;
Number ⊂ AnyType;

```

## Core Type Inference Rules via Rewriting

Type inference works by defining rules that match Orbit syntax and assert a Type Domain for that expression based on its components and context.

```orbit
// Typing Literals
// Use astname in guards to identify literal nodes
e => e : Int if astname(e) == "Int";
e => e : Double if astname(e) == "Double";
e => e : String if astname(e) == "String";
e => e : Bool if astname(e) == "Bool";

// Typing Binary Operations (Using infix syntax in patterns)
l : Int + r : Int => (l + r) : Int;
l : Double + r : Double => (l + r) : Double;
l : String + r : String => (l + r) : String; // Concatenation

l : T == r : T => (l == r) : Bool; // Equality needs compatible types T
l : Number < r : Number => (l < r) : Bool; // Comparison needs numeric types

// Typing If-Else
if c then t else e => (if c then t else e) : LUB(TypeT, TypeE)
	if c : Bool && t : TypeT && e : TypeE;

// Typing Identifiers
// Requires environment context. Placeholder rule:
x => x : T if typeOf(x, env) == T; // typeOf helper needs implementation

// Typing Let Bindings
// The type of a let is the type of its body. Need contextual inference.
(let x = e1; e2) => (let x = e1; e2) : TypeE2
	if e1 : TypeE1 && (e2 : TypeE2 if x : TypeE1); // Contextual 'if'

// Typing Function Definitions
// The function itself gets a Function type domain.
(fn f(p1:T1, p2:T2) = body) => (fn f(...) = body) : Function([T1, T2], TBody)
	if (body : TBody if p1:T1, p2:T2); // Contextual inference for body
	// This rule should also update the environment: env |- f : Function(...)

// Typing Function Applications
// The type of the application is the return type of the function.
f(a1, a2) => f(a1, a2) : RetType
	if f : Function([P1Type, P2Type], RetType) && a1 : A1Type && a2 : A2Type
	   && CanApply([A1Type, A2Type], [P1Type, P2Type]); // Check assignability/subtyping

// Typing Lambdas
(\x:T1 -> body) => (\x:T1 -> body) : Function([T1], TBody)
	if (body : TBody if x:T1); // Contextual inference

// Typing Explicit Domain Annotations in the source code
// The annotation asserts the domain onto the expression.
(e : D) => (e : D) : DomainTypeOf(D) // The expression itself has the type of the Domain term
	|- e : D;                     // Also assert that 'e' belongs to Domain 'D'

// Example helper functions (need implementation)
// astname(syntaxNode) -> string
// astchildren(syntaxNode) -> list<syntaxNode>
// typeOf(identifier, env) -> OrbitTypeDomain (e.g., Int, String)
// LUB(OrbitTypeDomain, OrbitTypeDomain) -> OrbitTypeDomain
// CanApply(argTypes : list<OrbitTypeDomain>, paramTypes : list<OrbitTypeDomain>) -> bool
// DomainTypeOf(domainSyntaxNode) -> DomainTerm // Type of the domain term itself
```

## Environment Management Challenge

Handling the typing environment (mapping `x` to `Int`, `f` to `Function(...)`) remains a significant challenge for a pure rewrite system. Strategies mentioned previously (context propagation, multi-pass, graph annotations, implicit context) would be necessary for a complete implementation. The contextual `if` syntax used above (`body : TBody if x:T1`) is a placeholder for such a mechanism.

## Example Snippet Walkthrough (Conceptual)

Consider this Orbit code:

```orbit
let y = 10;
let f = \x -> x + y;
f(5)
```

Inference steps:

1.  `10` matches `e => e : Int if astname(e) == "Int"`. Node `10` gets domain `Int`.
2.  `let y = 10; ...`: Rule notes `y` has type `Int` for the body scope.
3.  `\x -> x + y`:
    *   Assume `x` gets inferred/annotated type `Int`.
    *   Inside body `x + y`: `x` is `Int`, `y` is `Int` (from env).
    *   Matches `l : Int + r : Int => (l + r) : Int`. Body `x + y` gets domain `Int`.
    *   Lambda rule matches. `(\x -> ...)` gets domain `Function([Int], Int)`.
4.  `let f = (\...); f(5)`: Rule notes `f` has type `Function([Int], Int)` for the scope `f(5)`.
5.  `5` matches `e => e : Int if astname(e) == "Int"`. Node `5` gets domain `Int`.
6.  `f(5)` matches application rule `f(a1)`:
    *   `f` domain: `Function([Int], Int)`.
    *   Arg `5` domain: `Int`.
    *   Argument type `[Int]` matches parameter type `[Int]`.
    *   Rule asserts return type `Int`. Node `f(5)` gets domain `Int`.
7.  The final expression `f(5)` has type `Int`.

## Conclusion

Using Orbit to type Orbit itself via rewrite rules operating directly on Orbit syntax is conceptually sound. It involves:

*   Defining Orbit's types as Domains (`Int`, `Double`, `Function`, etc.).
*   Writing rules that match Orbit syntax patterns (like `l + r`) and infer the resulting Type Domain.
*   Using helpers like `astname` sparingly when direct syntax matching isn't enough.
*   Leveraging Orbit's core `:` operator to associate syntax nodes with their inferred Type Domains.

Practical implementation requires solving the environment management problem. However, this approach demonstrates the potential for a unified system where language semantics and analysis are defined declaratively using Orbit's own rewriting engine.
