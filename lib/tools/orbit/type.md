# Representing Types as Domains in Orbit

## Introduction

This document describes how type systems, particularly one similar to Flow9's, can be represented and reasoned about using Orbit's core mechanism: associating expressions with **Domains** via the `:` operator. Orbit's domain-unified rewriting approach allows type information to be integrated seamlessly with other kinds of reasoning, such as mathematical properties or effects, within the same framework.

While Flow9 uses a sophisticated internal E-Graph for its type inference, Orbit provides a language-level abstraction where types are simply one category of Domain that can be inferred or asserted for expressions.

## Types as Domains

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

// Maybe subtyping (covariant)
Maybe<A> ⊂ Maybe<B> if A ⊂ B;

// Constraints can trigger assertions
// If 'a' has Type Domain T1, and T1 is a subtype of T2,
// then 'a' also belongs to Type Domain T2.
a : T₁ ⊢ a : T₂ if T₁ ⊂ T₂;

// Unification constraint (example using GLB - Greatest Lower Bound)
// If 'a' must belong to both T1 and T2, it belongs to their GLB.
a : T₁, a : T₂ => a : GLB(T₁, T₂);

```

## Inferring Type Domains via Rewriting

Type inference, the process of determining the type of an expression, is achieved in Orbit through rewrite rules that associate language constructs with their corresponding Type Domains.

```orbit
// Associating language expressions with their Type Domains

// Literals
1 => 1 : int;
3.14 => 3.14 : float;
"hello" => "hello" : string;
true => true : bool;
[] => [] : list<?>; // Empty list is polymorphic
None() => None() : None;

// Variables get their Type Domain from the environment (lookup mechanism needed)
// x => x : lookupTypeDomain(x, env);

// Binary operators infer Type Domain based on operand Domains
a + b => (a + b) : int if a : int && b : int;
a + b => (a + b) : float if (a : float || b : float) && (a : number && b : number); // Assuming number ⊂ float, number ⊂ int
a + b => (a + b) : string if a : string || b : string; // String concatenation

// Comparisons result in Bool Domain
a == b => a == b : bool if a : T && b : T; // Requires operands have compatible domains

// Function application infers result Type Domain
// (Requires matching function domain and argument domains)
f(args) => f(args) : ReturnTypeDomain(f) if MatchesFunctionDomain(f, TypeDomainsOf(args));

// Conditionals require Bool Domain for condition; result is LUB of branches
if (c) e1 else e2 => if (c) e1 else e2 : LUB(TypeDomainOf(e1), TypeDomainOf(e2)) if c : bool;

// Let binding (example simplified)
let x = e1; e2 => let x = e1; e2 : TypeDomainOf(e2);

// Arrays infer a list Type Domain based on element LUB
[e1, e2] => [e1, e2] : list<LUB(TypeDomainOf(e1), TypeDomainOf(e2))>;

// Maybe unwrapping (Flow's ?? operator)
e1 ?? e2 => e1 ?? e2 : T if e1 : Maybe<T> && e2 : T; // Result Type Domain is T

```

## Operations on Type Domains (LUB/GLB)

Type systems often rely on Least Upper Bounds (LUB) and Greatest Lower Bounds (GLB) to find common types. These are simply operations defined on the Type Domain terms.

```orbit
// LUB and GLB form a lattice structure over Type Domains
LUB : Semilattice; // LUB is associative, commutative, idempotent
GLB : Semilattice; // GLB is associative, commutative, idempotent

// LUB definition based on subtyping hierarchy
LUB(T₁, T₂) => T₁ if T₂ ⊂ T₁;
LUB(T₁, T₂) => T₂ if T₁ ⊂ T₂;
// LUB(T₁, T₂) => commonSupertypeDomain(T₁, T₂); // Needs specific rules per hierarchy

// Example LUB rules
LUB(int, float) => float;
LUB(list<int>, list<float>) => list<float>; // Covariance
LUB(Maybe<int>, Maybe<float>) => Maybe<float>; // Covariance
LUB(None, Maybe<T>) => Maybe<T>;
LUB(T, Any) => Any;
LUB(T, Void) => T; // Assuming Void is the bottom type

// GLB definition based on subtyping hierarchy
// ... similar rules for GLB ...
GLB(int, float) => int;
GLB(T, Any) => T;
GLB(T, Void) => Void;

// LUB/GLB for function types
LUB((A₁ → B₁), (A₂ → B₂)) => (GLB(A₁, A₂) → LUB(B₁, B₂));
GLB((A₁ → B₁), (A₂ → B₂)) => (LUB(A₁, A₂) → GLB(B₁, B₂)); // Check variance rules

```

## Polymorphism and Type Variables

Polymorphic types involve Type Domains that contain placeholders (type variables like `?`) or are generalized (type schemas like `forall`).

```orbit
// Type variable Domains (placeholders)
? => freshTypeVarDomain(); // Create a unique placeholder domain

// Instantiation: Replacing placeholders in a Type Domain
// Example: Instantiate list<?> with int => list<int>
Instantiate(list<?>, int) => list<int>;
Instantiate((? → ?), (int, string)) => (int → string);

// Generalization: Creating a polymorphic Type Domain (Schema)
// generalize(TypeDomain, Env) => ForallDomain(...)

```

## EGraph Implementation Note

While Orbit defines typing rules at the language level using Domains, an efficient implementation (like Flow9's) would likely use an EGraph structure internally. In such an implementation:
*   Expressions and subexpressions become nodes in the EGraph.
*   The `:` associations link expression nodes to nodes representing their Domains (e.g., `int`, `list<float>`).
*   Operations like `union` (when two expressions are found equivalent) and `find` (to get the canonical representation) are used on expression nodes.
*   Type constraints (`⊂`, unification) trigger operations that merge or relate the *Domain nodes* associated with the expressions.
*   The OGraph manages the consistency of these relationships.

## Type Error Reporting

Type errors arise from conflicting Domain associations or relationships.

```orbit
// Potential error conditions expressed via rules

// Unification Failure: Cannot satisfy conflicting Type Domains
a : int, a : string => typeError("Type mismatch: cannot unify int and string", getContext(a));

// Subtyping Failure: Asserted subtype relation doesn't hold
a : string |- a : int => typeError("Type error: string is not a subtype of int", getContext(a)) if !(string ⊂ int);

// Occurs Check Failure (Cyclic Type Domain):
// Requires specific rules detecting cycles during unification/subtyping on recursive types.
// unify(?, list<?>) => typeError("Recursive type detected", ...);

```

## Algebraic Properties of Type Domains

The operations (`LUB`, `GLB`) and relationships (`⊂`) on Type Domains often form algebraic structures like lattices, which can be declared in Orbit for potential optimization or verification.

```orbit
// Declaring algebraic properties of operations on Type Domains
LUB : Semilattice;
GLB : Semilattice;

// Potential lattice laws (examples)
LUB(A, GLB(B, C)) <=> GLB(LUB(A, B), LUB(A, C)); // Distributivity
LUB(A, GLB(A, B)) <=> A; // Absorption
GLB(A, LUB(A, B)) <=> A; // Absorption

```

## Conclusion

Representing types as Domains in Orbit provides a unified framework for type checking and inference alongside other forms of program analysis and transformation. Key advantages include:

1.  **Unified Framework:** Type rules are just another set of rewrite rules operating on Domain associations.
2.  **Integration:** Type information (e.g., `expr : int`) can directly interact with other domains (e.g., `expr : Positive`, `expr : Pure`) within the same rule system.
3.  **Extensibility:** Adding new type constructs or rules involves defining new Domain terms and rewrite rules.
4.  **Formalism:** The rewrite rules provide a clear, declarative specification of the type system's logic.

This approach shifts the perspective from a dedicated type system to viewing typing as one specific, albeit crucial, application of Orbit's general-purpose, domain-based rewriting capabilities.
