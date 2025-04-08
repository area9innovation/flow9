# Orbit: Domain-Unified Rewriting Engine: Bridging Mathematical Formalism and Practical Programming

## Introduction

We present a novel approach to program transformation and optimization that unifies three powerful technologies: equivalence graphs (e-graphs) accelerated by WebGPU, a domain-unified rewriting system based on group theory, and Mango's concise grammar framework. This synthesis creates a powerful cross-language rewriting engine capable of applying formal mathematical theorems directly to program code.

## Theoretical Foundation: Domains and Symmetry Groups

At the heart of our system lies the insight that computational domains themselves—whether programming languages, algebraic structures, or formal systems—should be first-class citizens in the rewriting process. By representing domains explicitly within our e-graph structure, we enable:

1. **Cross-Domain Reasoning**: Values can exist simultaneously in multiple domains through e-class equivalence
2. **Canonical Representations**: Each domain leverages its natural symmetry group for canonicalization
3. **Deep Algebraic Structures**: The system automatically discovers and exploits algebraic properties

For example, addition exhibits symmetry group S₂ (the symmetric group of order 2), which captures commutativity. When we encounter expressions like `a + b` in any language, the system can automatically canonicalize to a standard form based on this algebraic property, thus avoiding exponential blowup.

## Mango: Concise Multi-Language Grammar Definitions

The Mango parser generator serves as our gateway to multiple languages. Its concise grammar syntax allows us to define parsers for programming languages and domain-specific languages with minimal effort:

```mango
exp =
	exp ("+" ws exp Add/0 BinOp/3 | "-" ws exp Sub/0 BinOp/3)
	|> exp ("*" ws exp Mul/0 BinOp/3 | "/" ws exp Div/0 BinOp/3)
	|> "-" Negative/0 ws <exp @swap UnOp/2
	|> exp ("(" ws @array<exp ","> ")" ws Call/2)?
	|> id Var/1 | $int ws @s2i Int/1
	;
```

This allows us to rapidly create parsers for multiple languages (Python, JavaScript, Lean, etc.) and define transformations between them. Each language becomes a domain in our unified system, with Mango providing the infrastructure to convert text to typed ASTs that can be processed by our e-graph engine.

## Cross-Domain Transformations with E-Graphs on WebGPU

Our system leverages WebGPU to dramatically accelerate e-graph saturation, enabling complex rewriting operations across domains. The e-graph structure:

1. Represents equivalence classes of expressions
2. Each eclass belongs to some domain
3. Applies cross-domain rewrite rules efficiently, so eclasses across different domains can be unified
4. Extracts optimal representations based on domain-specific cost models

We compile expressions and rewrite rules directly into specialized WebGPU Compute Shaders (WGSL), where the e-graph saturation process takes advantage of parallel GPU processing. This approach allows for real-time optimization of complex expressions across multiple domains.

# Domain-Unified Rewriting System: Grammar and Semantics

## Core Notation and Semantics

The Domain-Unified Rewriting System uses a specialized notation to express relationships between expressions across different domains:

```
// a is in equivalence class A
a : A

// If a is in A, then a and b are equivalent, and b is in B
a : A => b : B

// Entailment: Addition between two reals is commutative
a : Real + b : Real  ⊢  + : S₂
a : Real + b : Real  => (a + b) : Real : S₂

// The addition of two reals is a real
a : Real + b : Real <=> (a + b) : Real

// The domain of Int is a subset of Real
Int ⊂ Real
```

### Operator Semantics in E-Graph Context

| Operator | ASCII Alternative | E-Graph Interpretation | Semantic Meaning | Example | E-Class Merging Behavior |
|----------|------------------|------------------------|------------------|---------|--------------------------|
| `:` | `:` | Domain annotation | In patterns: Constrains matches to the specified domain. In results: Asserts the expression belongs to the domain (merges eclasses) | `x : Algebra` | Creates two eclasses: one for `x` and one for `Algebra`. Then merges these eclasses across domain boundaries. The expression `x` becomes the root of this merged eclass, since it is more specific. |
| `⇒` | `=>` | Rewrite rule | Unifies eclasses with the right side becoming the root, can include conditions | `a + b : JavaScript => a + b : Python` | Creates eclasses for `a + b` in the `JavaScript` domain, `a + b` in the `Python` domain. Then merges the LHS and RHS eclasses, with `sum([a, b])` becoming the root. Both expressions now represent the same computation across language domains. |
| `⇔` | `<=>` | Equivalence | Declares bidirectional equivalence between patterns, merging their eclasses | `x * (y + z) : Algebra <=> (x * y) + (x * z) : Algebra` | Creates eclasses for both expressions and merges them into a single eclass. Depending on what side was matched, either form might be selected as the root, but both are considered completely equivalent. |
| `⊢` | `\|-` | Entailment | When the left pattern matches, the right side annotation is applied | `a : Field + b : Field \|- + : S₂` | When an expression matching `a : Field + b : Field` is found, then the eclass for the `+` is unified with an eclass for `S₂`. This attaches the property `S₂` (commutativity) to the + operator in fields. |
| `⊂` | `c=` | Subset relation | Indicates domain hierarchy, automatically applying parent domain rules to children | `Integer c= Real` | Creates a relationship between domain eclasses where rules applied to `Real` are automatically inherited by `Integer`. This corresponds to a general rule `a : Integer => a : Real`, and thus we merge an eclass `Real` onto any `Integer` eclass, but keep the `Integer` eclass as the more specific one |

In the e-graph implementation, each unique expression and domain is initially represented by its own eclass. The operators above define how these eclasses should be merged or related:

- Domain annotations (`:`) establish cross-domain relationships, unifying expressions with their domain types.
- Rewrite rules (`⇒`) merge the eclasses of their left and right sides, with the right side becoming the canonical form.
- Equivalence statements (`⇔`) merge eclasses bidirectionally, treating both patterns as equally valid.
- Entailments (`⊢`) conditionally apply properties or domains to expressions when patterns match.
- Subset relations (`⊂`) establish rule inheritance without merging domain eclasses, preventing incorrect equivalence implications.

These merging behaviors enable the system to maintain a unified view of equivalent expressions across different domains, while respecting the specific semantics of each operator.

The system's power comes from its ability to represent domain-crossing relationships directly within the e-graph structure. Domain annotations serve dual purposes: as pattern constraints when matching, and as domain entailments when creating new nodes.

The domains are organized in a lattice with a partial order, so the eclassess always point to the most specific domain. This allows us to have a single S₂ eclass annotated on many operators. When we then do a S₂ <=> C₂ rewrite, it will apply to all operators that are annotated with S₂, and the result will be a C₂ eclass. This is a very powerful way to express the symmetry of the operators, and it allows us to have a single eclass for all the operators that are equivalent under S₂, giving us an exponential reduction in the number of eclasses we have to deal with.

## Mango Grammar Definition

```mango
@include<lexical>  // Basic lexical rules (ws, id, string, etc.)
@include<list>

@make_pattern<expr, pattern_variable, domain> = (
	// Pattern is extended with domain-annotated expression
	pattern =
		pattern ":" ws domain DomainPattern/2
		| pattern_variable PatternVariable/1
		| expr Pattern/1
		;
	// Recursively extend expressions with pattern
	expr = pattern | expr;
);

// Instantiate a rewriting system with a given set of languages
@make_rewrite_system<lhs, rhs, cond_expr, rule_sep> = (

	rewrite_system = @array<rewrite rule_sep> RewriteSystem/1;

	// Main grammar function that takes parameters to customize syntax for different contexts
	rewrite =
		rule_definition
		| equivalence
		| entailment
		| domain_hierarchy
		| lhs
		;

	// Rule definition: lhs => rhs with optional condition
	rule_definition = lhs ("=>" | "⇒") ws rhs @opt<conditional> Rule/3;

	// Equivalence statement: expr1 ⇔ expr2
	equivalence = lhs ("<=>" | "⇔") ws lhs @opt<conditional>  Equivalence/3;

	// Entailment: lhs ⊢ lhs
	entailment = lhs ("|-" | "⊢" ws) lhs @opt<conditional>  Entailment/3;

	// Domain hierarchy: Domain1 ⊂ Domain2
	domain_hierarchy = domain_expr ("c=" | "⊂" ws) domain_expr DomainHierarchy/2;

	// Optional conditional clause for rules
	conditional = "if" ws cond_expr Conditional/1;
);
""
```

This grammar defines a parameterized function `@make_rewrite_system` that instantiates a rewriting system for specific domain languages. The function takes these parameters:
- `expr`: Base expression grammar for the target domain
- `pattern_variable`: Grammar for pattern variables, typically @a, uid or lid.
- `domain_expr`: Grammar for domain expressions
- `cond_expr`: Grammar for conditional expressions
- `rule_sep`: Separator between rules in a ruleset, typically `;` or `.`

Using this grammar, you can create specialized rewrite systems for different domains (algebra, programming languages, formal systems) while maintaining a consistent semantic interpretation within the e-graph structure. When expressions cross domain boundaries, the e-graph representation unifies eclasses appropriately, allowing formal reasoning across language barriers.

## Pattern Matching vs. Entailment

Here's a more precise description of how domain annotations work in different contexts:

### 1. Pattern Matching (Left-Hand Side)

```
expr : Domain
```

On the left-hand side of a rule, this is a **constraint** requiring that:
- The matched node must already have a domain annotation indicating it belongs to `Domain`
- This acts as a filter in pattern matching, restricting the match to specific domains

```
a + b : Algebra :S₂
```

This matches:
- An addition expression
- That exists in the Algebra domain
- With S₂ symmetry property (matches any permutation in the S₂ orbit)

### 2. Entailment (Right-Hand Side)

```
result : Domain
```

On the right-hand side, this is an **assertion** that:
- The resulting node should be annotated as belonging to `Domain`
- This adds domain membership information to the e-class

```
optimized : Python :PureFunction
```

This asserts:
- The result belongs to the Python domain
- It has the PureFunction property

### 3. Explicit Entailment Rules

```
condition ⊢ expr : Domain
```

This creates a conditional domain annotation:
- When `condition` is true for a node matching `expr`
- The node's e-class gets the `Domain` annotation

For example:
```
isPrime(n) ⊢ n : Prime
is_commutative(op) ⊢ op : CommutativeOp
```

## Domain Hierarchies and Rule Inheritance

Our system organizes domains into hierarchies with rule inheritance. For example:

```
AbelianGroup ⊂ Ring ⊂ Field
Integer ⊂ Real ⊂ Complex
Python.List ⊂ Python.Iterable
```

Rules defined at more abstract levels automatically apply to concrete instances. For example, commutativity defined for `AbelianGroup` applies to integers in Python, allowing the system to apply `a + b ⇔ b + a` without explicitly defining this rule for Python integers.

## Implementation via Domain-Aware E-Graph

The implementation combines several key technologies:

1. **Domain Nodes in E-Graph**: Values exist simultaneously in multiple domains through equivalence
2. **Symmetry-Based Canonicalization**: Each domain applies its natural symmetry groups
3. **Cross-Domain Unification**: Domain conversions are treated as regular e-graph rewrites
4. **WebGPU Acceleration**: Specialized WGSL code for efficient e-graph saturation
5. **Mango Parsing**: Concise grammar definitions for multiple languages

This creates a powerful, unified system where mathematical formalism and practical programming seamlessly interact, all accelerated by modern GPU technology.

# Domain-Crossing Rewrite System with Symmetry-Based Canonicalization

## 1. E-Graph Representation

In the e-graph, this syntax maps to:

1. **Nodes**: Each `expression : Domain` creates a domain-specific node for the expression, and another for the Domain. They belong to each of their own domains, but are unified to be equivalent through the eclass.
2. **E-classes**: Equivalent expressions across domains share an e-class

```
// Core data structures for the orbit e-graph
ONode(
	domain: ODomain,    // The domain this node belongs to
	op: string,        // Operator or function name
	children: [int]  // References to child eclasses
);

OClass(
	mutable root: int,         // Index of the canonical representation
	nodes: [ONode],    // Equivalent nodes in this equivalence class
);

OGraph(
	mutable classes : Tree<int, int>,  // Map from id to eclass
);

ODomain(
	domain : string
);
```

Our egraph is special in the sense that the equivalences come with a direction. They point from the general to the specific. Also, we do not  we can have many instances of Int in the graph, but each of them is not equivalent. We do not want transitively infer that given 1 : Int, and 2 : Int, 1 is NOT equivalent with 2, because they point to a seperate node for Int. If Int was the same eclass for both, we would wrongly infer 1 and 2 are equivalent, and we intentionally do not want that. It is natural that the most specific node is the root when we have multiple domains.

## 2. Defining domain syntaxes

We use Mango macros to instantiate a number of domain-specific syntaxes. The `@make_pattern` macro allows us to define a pattern for each domain, which can be used in the rewrite rules.

```
@js<> = @make_pattern<js_expr, uid, math>;
@python<> = @make_pattern<python_expr, uid, math>;
@math<> = @make_pattern<math_expr, uid, math>;
@lean<> = @make_pattern<lean_expr, uid, math>;
```

## 3. Cross-Domain Rewrites

```
// Rewriting from JavaScript to Python, using the math domain and JS conditions.
@rewrite_system<@js, @python, js_expr, ".">(
	// JavaScript array to Python list conversion
	arr.map(x => y) => [y for x in arr].
)


// Rewriting from one area of math to another
@rewrite_system<@math, @math, @math, ".">(
	map(f, S) : Algebra => {f(x) | x ∈ S} : SetTheory
)
```

## 4. Domain-Specific Canonicalization with Symmetry Groups

To avoid exponential blowup due to commutative properties, we define symmetry groups for each domain. This allows us to canonicalize expressions based on their symmetry properties.

```
@algebra<> = @make_pattern<algebra_expr, uid, domain_expr>;

Integer ⊂ Rational ⊂ Real ⊂ Complex ⊂ Abelian;

@rewrite_system<@algebra, @algebra, math, ";">(
	// Define that addition is commutative
	(a : Abelian) + (b : Abelian)  |-   + : S₂;

	// S₂ symmetry (commutativity) with explicit ordering
	(a + b) : S₂ => a + b : Canonical if a <= b;
	(a + b) : S₂ => b + a : Canonical if b < a;

	// Same for multiplication. We could use an AST syntax to generalize this to any binary operator
	a * b : S₂ => a * b : Canonical if a <= b;
	a * b : S₂ => b * a : Canonical if b < a;

	// For S₃ symmetry (e.g., in associative operators with 3 arguments)
	a * b * c : S₃ => ordered3(a, b, c);

	// Helper function that implements the explicit ordering
	ordered3(a, b, c) => a * b * c : Canonical if a <= b && b <= c;
	ordered3(a, b, c) => a * c * b : Canonical if a <= c && c <= b;
	ordered3(a, b, c) => b * a * c : Canonical if b <= a && a <= c;
	ordered3(a, b, c) => b * c * a : Canonical if b <= c && c <= a;
	ordered3(a, b, c) => c * a * b : Canonical if c <= a && a <= b;
	ordered3(a, b, c) => c * b * a : Canonical if c <= b && b <= a;
);

// Cross-domain canonicalization
@rewrite_system<@js, @js, js_expr, ";">(
	// JavaScript array operations in canonical order
	array.map(f).filter(p) => array.filter(p).map(f) : Canonical;
)

@rewrite_system<@js, @python, python_expr, ";">(
	// Then map to target domain maintaining canonical form
	array.filter(p).map(f) : Canonical => [f(x) for x in array if p(x)] : Python : Canonical;
);
```

The key additions here are:

1. Explicit ordering conditions using `if a < b` to determine the canonical representation
2. For operations with S₃ symmetry (6 permutations), we define all possible orderings and select the one that meets our lexicographic ordering criteria
3. The `ordered3` helper function implements the explicit ordering logic, comparing elements and selecting the appropriate permutation

This approach ensures that equivalent expressions are always transformed to the exact same canonical representation, which is essential for:

1. Efficient e-graph operation (avoiding redundant eclasses)
2. Deterministic pattern matching
3. Consistent extraction of optimized expressions

The ordering function (represented by `<` here) would typically be implemented as a lexicographic comparison or a structural ordering based on the expression tree, ensuring a total ordering on all possible expressions in the domain.

# Math-to-JavaScript Bijection for Solving Quadratic Equations

An example that demonstrates how we can use canonical mathematical syntax to solve second-degree polynomials using a bidirectional mapping with JavaScript.

## 1. Math Domain Definition in Mango

First, let's define a grammar for mathematical expression:

TODO: 
Allow more natural syntax: ax² + bx + c = 0. 
Add equations.
Also add sets. 
Add $ or similar notation for evaluation on the right hand side.
Use Mango precedence to shorten grammar.

```mango
@include<lexical>
@include<list>

math_expr =
	math_expr "+" ws term Addition/2
	|> math_expr "-" ws term Subtraction/2
	|> term
	;

term =
	term "*" ws factor Multiplication/2
	|> term "/" ws factor Division/2
	|> factor
	;

factor =
	factor "^" ws power Exponentiation/2
	|> atom
	;

atom =
	$double ws @s2d Number/1
	| id Variable/1
	| "(" ws math_expr ")" ws
	| "-" ws factor Negation/1
	| "sqrt" ws "(" ws math_expr ")" ws Sqrt/1
	;

ws math_expr
```

## 2. JavaScript Expression Domain

We have a complete JS grammar. No need to define it here, but you get the idea.

```mango
js_expr =<...>
```

## 3. Define Bidirectional Domain Crossing

Now, let's establish the bijection between math expressions and JavaScript using bidirectional rewrites:

```mango
@math<> = @make_pattern<math_expr, id, domain_expr>;
@js<> = @make_pattern<js_expr, id, domain_expr>;

// Bidirectional Math <=> JavaScript transformations
@rewrite_system<@math, @js, math_expr, ";">(
	// Basic operators
	a + b <=> a + b;
	a - b <=> a - b;
	a * b <=> a * b;
	a / b <=> a / b;
	a ^ b <=> a ** b;
	-a <=> -a;

	// Functions - todo we have to define what a is a pattern var here, and sqrt is not
	sqrt(a) <=> Math.sqrt(a);

	// Mapping sets to and from arrays
	{}	<=> [];
	{a} <=> [a];
	{a, b} <=> [a, b];

	// Bridge between solving equations in math and JS
	solve x in y <=> solve((x) => y);
);
```

## 4. Quadratic Equation Solving Rules

Let's define the mathematical rules for solving quadratic equations:

```mango
@rewrite_system<@math, @math, math_expr, ";">(

	// Moving terms from right to left side
	A = B + C <=> A - C = B;
	A = B - C <=> A + C = B;

	// Moving terms with coefficient
	A = B + n*C <=> A - n*C = B;
	A = B - n*C <=> A + n*C = B;

	// Moving all terms to the left side (canonical form preparation)
	A = B <=> A - B = 0 : Canonical;

	// Combining like terms for x^2
	a*x^2 + b*x^2 <=> (a+b)*x^2;
	a*x^2 - b*x^2 <=> (a-b)*x^2;

	// Combining like terms for x
	a*x + b*x <=> (a+b)*x;
	a*x - b*x <=> (a-b)*x;

	// Combining constants
	a + b <=> $(a+b) : Canonical  if is_constant(a) && is_constant(b);
	a - b <=> $(a-b) : Canonical  if is_constant(a) && is_constant(b);

	(x + c)  !:  ExplicitCoef  => (1 * x + c) : ExplicitCoef   ; // How to avoid infinite recursion?

	// Two real solutions when discriminant > 0
	a*x^2 + b*x + c = 0 <=> {
		(-b + sqrt(b^2 - 4*a*c))/(2*a),
		(-b - sqrt(b^2 - 4*a*c))/(2*a)
	} if  b^2 - 4*a*c > 0;

	// One real solution when discriminant = 0
	a*x^2 + b*x + c = 0 <=> {
		-b/(2*a)
	} if  b^2 - 4*a*c = 0;

	// No real solutions when discriminant < 0
	a*x^2 + b*x + c = 0 <=> {} if b^2 - 4*a*c < 0;

	// Optionally, include complex solutions for negative discriminant
	a*x ^2 + b*x + c = 0 : Complex <=> {
		-b/(2*a) + sqrt(-(b^2 - 4*a*c))/(2*a) * i,
		-b/(2*a) - sqrt(-(b^2 - 4*a*c))/(2*a) * i
	} if b^2 - 4*a*c < 0;

	// Resolve the canonical form to bindings
	solve x in (y : Set) <=>  x = y : Canonical;
);
```

With this concise bijection in place, we can now solve any quadratic equation by:

1. Writing it in canonical mathematical notation (ax² + bx + c = 0)
2. Letting the system apply the transformation rules automatically
3. Getting JavaScript code that computes the solutions

## 5. JS example

Here is an example

```js
// Example usage
console.log(solve((x) => x**2 - 1 == 2*x));
// Behind the scenes, the following transformations occur:
// 0. We lift into math world
// 1. x^2 - 1 = 2*x                (original input)
// 2. x^2 - 1 - 2*x = 0            (move all terms to left)
// 3. x^2 - 2*x - 1 = 0            (arrange in standard form)
// 4. a=1, b=-2, c=-1              (extract coefficients)
// 5. Discriminant = 4+4 = 8 > 0   (calculate discriminant)
// 6. {(-(-2) + sqrt(8))/2, (-(-2) - sqrt(8))/2}
// 7. {(2 + 2.83)/2, (2 - 2.83)/2}
// 8. {2.41, -0.41}                (solutions)
// 9. [2.41, -0.41]                (final result in JS)

// Another example with no real solutions
console.log(solve((x) => x**2 + 4 == 0));
// 1. x^2 + 4 = 0                  (already in canonical form)
// 2. a=1, b=0, c=4                (extract coefficients)
// 3. Discriminant = 0-16 = -16 < 0 (calculate discriminant)
// 4. []                           (no real solutions)

// Example with exactly one solution
console.log(solve((x) => x**2 - 6*x + 9 == 0));
// 1. x^2 - 6*x + 9 = 0            (already in canonical form)
// 2. a=1, b=-6, c=9               (extract coefficients)
// 3. Discriminant = 36-36 = 0     (calculate discriminant)
// 4. [-(-6)/(2*1)]                (one solution formula)
// 5. [3]                          (solution)
```


## 5. Entailment Rules

We can do more advanced number theory and algebraic properties using entailment rules. This allows us to define properties of numbers and functions, and then use them in our rewrite rules.

```
@rewrite_system<@math, @math, math_expr, ";">(
	// Type-based entailments
	2 ⊢ 2 : Prime;
	3 ⊢ 3 : Prime;

	// Explicit entailment with a condition
	n : Integer  ⊢  n : Odd   if   n % 2 = 1;

	// Property-based entailments
	f ⊢ f : CommutativeOp   if   commutes(f);
	S ⊢ S : Group   if   has_inverses(S);
	fn ⊢ fn : PureFunction   if   deterministic(fn);

	// Context-dependent entailments
	matrix ⊢ matrix : NumpyMatrix if in_module("numpy");
	tensor ⊢ tensor : TensorFlow if in_context("tensorflow");
);
```

## 6. Systematic Examples

### Example 1: Cross-Language Optimization Chain

```
@js<> = @make_pattern<js_expr, uid, domain_expr>;
@python<> = @make_pattern<python_expr, uid, domain_expr>;
@algebra<> = @make_pattern<algebra_expr, uid, domain_expr>;

// JavaScript to Python transformation
@rewrite_system<@js, @python, js_expr, ";">(
	array.map(f).reduce((a,b) => op(a,b), init) : JavaScript =>
		sum(f(x) for x in array) : Python;
);

// Python to Algebra transformation
@rewrite_system<@python, @algebra, python_expr, ";">(
	sum(c * x for x in array) : Python =>
		c * sum(array) : Algebra :Distributive;
);

// Algebra simplification
@rewrite_system<@algebra, @algebra, algebra_expr, ";">(
	c * sum(array) : Algebra :Distributive =>
		c * sum(array) : Algebra; // Now in canonical form
);

// Algebra back to Python
@rewrite_system<@algebra, @python, algebra_expr, ";">(
	c * sum(array) : Algebra =>
		c * sum(array) : Python;
);
```

### Example 2: Group Theory and Programming Language Bridge

```
@group<> = @make_pattern<group_expr, uid, domain_expr>;
@python<> = @make_pattern<python_expr, uid, domain_expr>;

// Define domain hierarchies
@rewrite_system<@group, @group, group_expr, ";">(
	S₂ ⊂ SymmetricGroup;  // Symmetric group of order 2
	C₄ ⊂ CyclicGroup;     // Cyclic group of order 4
);

// Connect mathematical concepts to programming constructs
@rewrite_system<@group, @python, group_expr, ";">(
	action(S₂, [a, b]) : Group => [b, a] : Python;
	action(C₄, arr) : Group => arr[n:] + arr[:n] : Python;
);

// Entailment between operations and groups
@rewrite_system<@group, @group, group_expr, ";">(
	op ⊢ op : S₂Operation if is_commutative(op);
	op ⊢ op : C₄Operation if is_rotation(op);
);

// Pattern recognition across domains
@rewrite_system<@python, @group, python_expr, ";">(
	[b, a] : Python => action(S₂, [a, b]) : Group;
	arr[n:] + arr[:n] : Python => action(C₄, arr) : Group;
);

// Optimization using group properties
@rewrite_system<@group, @python, group_expr, ";">(
	// Double swap is identity in S₂
	action(S₂, action(S₂, arr)) : Group => arr : Python;

	// Four rotations is identity in C₄
	action(C₄, action(C₄, action(C₄, action(C₄, arr)))) : Group => arr : Python;
);
```

### Example 4: Lean Theorem Application to Python

```
@lean<> = @make_pattern<lean_expr, uid, domain_expr>;
@algebra<> = @make_pattern<algebra_expr, uid, domain_expr>;
@python<> = @make_pattern<python_expr, uid, domain_expr>;

// Bridge from Lean to general algebraic domain
@rewrite_system<@lean, @algebra, lean_expr, ";">(
	"∀ (f : α → β) (g : β → γ) (xs : List α), (xs.map f).fold g = xs.fold (λ acc x => g (f x))" : Lean =>
		fold(g, map(f, xs)) = fold(compose(g, f), xs) : Algebra;
);

// Application to Python list comprehension
@rewrite_system<@algebra, @python, algebra_expr, ";">(
	fold(g, map(f, xs)) : Algebra =>
		sum(g(f(x)) for x in xs) : Python;
	fold(compose(g, f), xs) : Algebra =>
		sum(g(f(x)) for x in xs) : Python;
);

// Concrete Python optimization
@rewrite_system<@python, @python, python_expr, ";">(
	// Original pattern
	sum(f(x) for x in xs) : Python =>
		// Optimized pattern for special case where f(x) = x * c
		c * sum(xs) : Python if is_mul_by_constant(f, c);
);
```

## 5. Domain Hierarchy and Inheritance

```
@rewrite_system<@math, @math, math_expr, ";">(
	// Domain hierarchy declarations
	Integer ⊂ Rational ⊂ Real ⊂ Complex;
	JavaScript.Array ⊂ JavaScript.Iterable;
	Python.List ⊂ Python.Iterable;
	Semigroup ⊂ Monoid ⊂ Group ⊂ AbelianGroup;

	// Rule inheritance follows the hierarchy
	a + b : AbelianGroup :S₂ => ordered(a, b) : AbelianGroup :S₂;
);

@rewrite_system<@group, @python, group_expr, ";">(
	// Explicit domain bridge for group theory to programming
	action(S₃, elems) : Group =>
		permute(elems, perm) : Python.List;
);
```

## 10. Complete Cross-Domain Optimization Example

```
@js<> = @make_pattern<js_expr, uid, domain_expr>;
@python<> = @make_pattern<python_expr, uid, domain_expr>;
@algebra<> = @make_pattern<algebra_expr, uid, domain_expr>;

// Step 1: Cross-Domain Translation
@rewrite_system<@js, @python, js_expr, ";">(
	array.map(x => x * c).reduce((a, b) => a + b, 0) : JavaScript =>
		sum(x * c for x in array) : Python;
);

// Step 2: Python to Algebra Domain Bridge
@rewrite_system<@python, @algebra, python_expr, ";">(
	sum(x * c for x in array) : Python =>
		sum(map(λx.c*x, array)) : Algebra;
);

// Step 3: Algebra Domain has Distributive Property
@rewrite_system<@algebra, @algebra, algebra_expr, ";">(
	c : Number ⊢ λx.c*x : DistributiveFunction;
);

// Step 4: Apply Algebraic Optimization
@rewrite_system<@algebra, @algebra, algebra_expr, ";">(
	sum(map(λx.c*x, array)) : Algebra :Distributive =>
		c * sum(array) : Algebra;
);

// Step 5: Convert Back to Target Language
@rewrite_system<@algebra, @python, algebra_expr, ";">(
	c * sum(array) : Algebra => c * sum(array) : Python;
);
```
