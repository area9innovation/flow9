# Flow Type System in Orbit: Domain-Driven Type Inference

## Introduction

This document describes how the Flow9 type inference system can be represented and enhanced using Orbit's domain-unified rewriting approach. Flow9 uses a sophisticated type system with subtyping, polymorphism, and structural types, all implemented through an E-Graph-based constraint system. By reformulating this system in Orbit, we gain the ability to leverage group-theoretic properties and cross-domain optimization.

## Type Nodes and EGraph Representation

In Flow's type system, types are represented in an EGraph with three kinds of nodes:

1. **Constructor**: Named types with optional parameters (e.g., `Int`, `Array(Int)`) 
2. **Function**: Function types with argument and return types
3. **Variable**: Type variables for polymorphism

In Orbit, we can represent these concepts directly as domain nodes:

```
@egraph<> = @make_pattern<egraph_expr, uid, domain_expr>;

@rewrite_system<@egraph, @egraph, egraph_expr, ";">(
	// Define TypeNode domain
	Constructor(name, params) ⊂ TypeNode;
	Function(args, ret) ⊂ TypeNode;
	Variable(id) ⊂ TypeNode;
);
```

## Type Constraints as Domain Relationships

The Flow type system uses constraints to enforce relationships between types. In Orbit, these constraints can be expressed directly through domain relationships:

```
@rewrite_system<@type, @type, type_expr, ";">(
	// Subtyping constraint
	a : T₁ ⊢ a : T₂ if T₁ ⊂ T₂;

	// Unification constraint
	a : T₁, a : T₂ => a : MeetType(T₁, T₂);

	// Function subtyping (contravariant in args, covariant in return)
	(A₁ → B₁) ⊂ (A₂ → B₂) if A₂ ⊂ A₁ && B₁ ⊂ B₂;

	// Array subtyping (covariant)
	Array(A) ⊂ Array(B) if A ⊂ B;

	// Maybe subtyping (covariant)
	Maybe(A) ⊂ Maybe(B) if A ⊂ B;
);
```

## Type Inference Through Rewriting

In Flow's implementation, type inference is performed by traversing the AST and generating constraints. With Orbit, we can express this as rewrite rules that connect language constructs to their types:

```
@lang<> = @make_pattern<lang_expr, uid, domain_expr>;

@rewrite_system<@lang, @type, lang_expr, ";">(
	// Literals
	1 => 1 : Int;
	3.14 => 3.14 : Double;
	"hello" => "hello" : String;
	true => true : Bool;
	[] => [] : Array(?);
	None() => None() : None;

	// Variables get their type from context
	x => x : $type(x);

	// Binary operators
	a + b => (a + b) : Int if a : Int && b : Int;
	a + b => (a + b) : Double if (a : Double || b : Double) && (a : Number && b : Number);
	a + b => (a + b) : String if a : String || b : String;

	// Comparisons
	a == b => a == b : Bool if a : T && b : T;

	// Function application
	f(args) => f(args) : ReturnType(f) if MatchesFunctionType(f, TypesOf(args));

	// Conditionals
	if (c) e1 else e2 => if (c) e1 else e2 : LUB(TypeOf(e1), TypeOf(e2)) if c : Bool;

	// Let binding
	let x = e1; e2 => let x = e1; e2 : TypeOf(e2);

	// Arrays
	[e1, e2, ..., en] => [e1, e2, ..., en] : Array(LUB(TypeOf(e1), TypeOf(e2), ..., TypeOf(en)));

	// Maybe unwrapping (Flow's ?? operator)
	e1 ?? e2 => e1 ?? e2 : T if e1 : Maybe(T) && e2 : T;
);
```

## Subtyping Constraints and Least Upper Bounds

A key feature of Flow's type system is its use of subtyping with least upper bounds (LUBs) and greatest lower bounds (GLBs). Orbit can express these operations with explicit group-theoretic rules:

```
@rewrite_system<@type, @type, type_expr, ";">(
	// LUB and GLB form a lattice structure
	LUB : Semilattice;  // LUB is associative, commutative, idempotent
	GLB : Semilattice;  // GLB is associative, commutative, idempotent

	// LUB of basic types follows the type hierarchy
	LUB(T₁, T₂) => T₁ if T₂ ⊂ T₁;
	LUB(T₁, T₂) => T₂ if T₁ ⊂ T₂;
	LUB(T₁, T₂) => commonSupertype(T₁, T₂);

	// LUB of function types
	LUB((A₁ → B₁), (A₂ → B₂)) => (GLB(A₁, A₂) → LUB(B₁, B₂));

	// LUB of container types
	LUB(Array(A), Array(B)) => Array(LUB(A, B));
	LUB(Maybe(A), Maybe(B)) => Maybe(LUB(A, B));
	LUB(None, Maybe(T)) => Maybe(T);
);
```

## Polymorphic Type Handling

Flow uses type variables (denoted as `?` or `??`) to represent polymorphic types. In Orbit, we can handle these with instantiation and generalization rules:

```
@rewrite_system<@type, @type, type_expr, ";">(
	// Type schema instantiation
	forall α. T => T[α := fresh()];

	// Type variable instantiation
	? => freshTypeVar();
	?? => freshTypeVar();

	// Type generalization
	generalize(T, localVars) => forall αs. T where αs = freeVars(T) - localVars;

	// Instantiation of a type with explicit substitution
	T[α := S] => substitute(α, S, T);
);
```

## Type Inference Algorithm in Orbit

Flow's type inference algorithm walks the AST and generates constraints. With Orbit, this can be expressed as a set of transformation rules that operate directly on the AST:

```
@rewrite_system<@lang, @typed_lang, lang_expr, ";">(
	// Expression typing
	infer(e, env) => typed(e, infer_expr(e, env));

	// Type environment lookup
	infer_expr(var(x), env) => lookup(env, x);

	// Literal typing
	infer_expr(int_lit(n), _) => Int;
	infer_expr(double_lit(d), _) => Double;
	infer_expr(string_lit(s), _) => String;
	infer_expr(bool_lit(b), _) => Bool;

	// Function typing
	infer_expr(lambda(params, body), env) => {
		paramTypes = map(params, \p -> freshTypeVar());
		extendedEnv = extendEnv(env, zip(params, paramTypes));
		retType = infer_expr(body, extendedEnv);
		FunctionType(paramTypes, retType)
	};

	// Function application
	infer_expr(apply(func, args), env) => {
		funcType = infer_expr(func, env);
		argTypes = map(args, \a -> infer_expr(a, env));
		retType = freshTypeVar();
		addConstraint(funcType, FunctionType(argTypes, retType));
		retType
	};
);
```

## Examples of Type Inference with Orbit

Let's examine how the Orbit system would perform type inference on some Flow examples:

### Example 1: Simple Function with Polymorphism

```
// Flow code
id = \x -> x;

// Orbit type inference
@rewrite_system<@flow, @typed_flow, flow_expr, ";">(
	\x -> x => (\x -> x) : forall α. α -> α;

	id(3) => id(3) : Int;
	id("hello") => id("hello") : String;
);
```

### Example 2: Subtyping with Maybe

```
// Flow code
processValue = \v -> if (v == None()) "empty" else v + " processed";

// Orbit type inference
@rewrite_system<@flow, @typed_flow, flow_expr, ";">(
	// First, infer the parameter type
	v == None() => v == None() : Bool |- v : Maybe(String);

	// Then, infer the branches
	"empty" => "empty" : String;
	v + " processed" => v + " processed" : String |- v : String;

	// For the if-else, take the LUB of the branches
	if (v == None()) "empty" else v + " processed" =>
		if (v == None()) "empty" else v + " processed" : String;

	// Finally, infer the lambda
	\v -> if (v == None()) "empty" else v + " processed" =>
		\v -> if (v == None()) "empty" else v + " processed" : Maybe(String) -> String;
);
```

### Example 3: Structural Typing with Records

```
// Flow code
makePoint = \x, y -> { x : x, y : y };

// Orbit type inference
@rewrite_system<@flow, @typed_flow, flow_expr, ";">(
	// First, infer parameters
	x => x : α;
	y => y : u03b2;

	// Then, infer the record
	{ x : x, y : y } => { x : x, y : y } : { x : α, y : u03b2 };

	// Finally, infer the function
	\x, y -> { x : x, y : y } => \x, y -> { x : x, y : y } : (α, u03b2) -> { x : α, y : u03b2 };
);
```

## Egraph-based Type Inference Implementation

Flow's implementation uses an EGraph-based approach to efficiently represent and solve type constraints. In Orbit, we can model the key operations of this engine:

### EClass Operations

```
@rewrite_system<@egraph, @egraph, egraph_expr, ";">(
	// Create a new EClass from a TypeNode
	makeEClass(node) => EClass(node, freshId(), emptySet(), emptySet(), emptySet(), emptySet());

	// Finding the representative
	find(id) => id if isRoot(id);
	find(id) => find(parent(id)) if !isRoot(id);

	// Union operation
	union(id1, id2) => {
		root1 = find(id1);
		root2 = find(id2);
		if (root1 != root2) {
			parent(root2) := root1;
			mergeContexts(root1, root2);
		}
		root1
	};

	// Canonicalization
	canonicalizeEClass(id) => {
		root = find(id);
		updateNode(root, canonicalForm(getNode(root)));
		maybe_congruence(root);
		root
	};
);
```

### Subtyping Operations

```
@rewrite_system<@egraph, @egraph, egraph_expr, ";">(
	// Add a subtype relationship
	addSubtype(sub, sup, context) => {
		subRoot = find(sub);
		supRoot = find(sup);
		addSubtypeSet(subRoot, supRoot);
		addContext(subRoot, supRoot, context);
		propagateSubtyping(subRoot, supRoot);
	};

	// Subtype transitivity
	propagateSubtyping(sub, sup) => {
		// Apply transitivity: If A <: B and B <: C, then A <: C
		foreach (direct_super in getDirectSupertypes(sub))
			addSubtype(direct_super, sup, "transitivity");

		foreach (direct_sub in getDirectSubtypes(sup))
			addSubtype(sub, direct_sub, "transitivity");
	};
);
```

## Type Error Reporting

One of the strengths of the Flow type system is its ability to provide detailed error messages. In Orbit, we can capture error contexts and report them through domain-aware rules:

```
@rewrite_system<@egraph, @error, egraph_expr, ";">(
	// Type mismatch error
	unify(t1, t2) => typeError("Type mismatch: expected " + prettyPrint(t1) +
		", but got " + prettyPrint(t2), getContexts(t1, t2)) if !canUnify(t1, t2);

	// Subtyping error
	subtype(sub, sup) => typeError("Type error: " + prettyPrint(sub) +
		" is not a subtype of " + prettyPrint(sup), getSubtypeContexts(sub, sup))
		if !canBeSubtype(sub, sup);

	// Occurs check error (cyclic types)
	occursCheck(var, type) => typeError("Recursive type detected: " +
		prettyPrint(var) + " occurs in " + prettyPrint(type), getContexts(var, type))
		if occursIn(var, type);
);
```

## Group Theoretic Properties of Flow Types

The Flow type system exhibits several algebraic group properties that can be exploited for optimization using Orbit:

```
@rewrite_system<@type, @type, type_expr, ";">(
	// Type operators form algebraic structures
	LUB : Semilattice;  // Least Upper Bound forms a semilattice
	GLB : Semilattice;  // Greatest Lower Bound forms a semilattice

	// Distributivity laws
	LUB(A, GLB(B, C)) => GLB(LUB(A, B), LUB(A, C));

	// Neutral elements
	LUB(T, Any) => Any;
	LUB(T, Void) => T;
	GLB(T, Any) => T;
	GLB(T, Void) => Void;

	// Absorption laws
	LUB(A, GLB(A, B)) => A;
	GLB(A, LUB(A, B)) => A;
);
```

## Conclusion

By representing Flow's type system in Orbit, we gain several advantages:

1. **Formal verification**: The domain-crossing rules provide a formal specification of the type system
2. **Optimization**: Group-theoretic properties enable more efficient type constraint solving
3. **Extensibility**: New type features can be added by simply extending the rewrite rules
4. **Cross-language interoperability**: Types can be translated across language boundaries

The Orbit representation demonstrates that Flow's sophisticated type system, with its subtyping, polymorphism, and structural types, can be expressed elegantly through domain-unified rewriting rules that capture both the operational aspects of type inference and the algebraic properties of the type system.
