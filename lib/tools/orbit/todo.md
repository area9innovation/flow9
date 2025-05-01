# Orbit TODO List
- Port the entire thing to run in our scheme
  ✅ Convert OrMath_expr to/from SExpr
  ✅ Check roundtrip Orbit to SExpr and back
  - Imports are not resolved correctly, so we do not convert those right
  - Migrate to eval using SExpr. 
    ✅ Pattern matching needs to support "if" conditions
	✅ Difference in array vs call: Clojure uses [] for vector, and :name for self-evaluating ids
  - get import of .orb files to work in sexpr world
  - Change ograph to use SExpr
  - Apply all existing functions in the ograph if they "fit"
  - Extract functions from the Scheme runtime env and insert as code in the ograph
  - Extract functions from the ograph and insert as code in the Scheme runtime env

- Glex rules for polynomial rings
- Relational algebra and optimizations of that
- Reuse nodes with add
- Support for pattern matching where we visit all the equivalent nodes as well. => vs -> maybe
- Subscripts on operators
- Explain how we do not have a cost function anymore, but just canonical forms in each domain
- Explain the gather approach in the paper for canonical in n log n time, rather than implicit n^2 from binary bubblesort
- Equivalence between subscripts in unicode and _ and superscripts and ^
- foo.1 for field access?
- Figure out how we can do "lazy" rule saturation. If we ask for a CodeSize, JS domain of something, it should transitively find out how to convert Math expression to runnable, short JS code.
- Hook in evaluation functions to implement interpretation of AST nodes directly in Orbit itself, potentially using rewriting
- Support for pattern matching within sequences. We look at neighbours
	1+2+3 ⇒ match exactly [1,2,3]
	1+2+3+... ⇒ match start in [1,2,3] 
	...+1+2+3 ⇒ match ending in [1,2,3]
	...+1+2+3+... ⇒ match [1,2,3] anywhere

Here are the operators that are traditionally considered associative and would benefit from array-based representation:

1. **Addition (`+`)** - `Add/2`
2. **Multiplication (`*` or `·`)** - `Multiply/2`
3. **Logical AND (`&&` or `∧`)** - `LogicalAnd/2`
4. **Logical OR (`||` or `∨`)** - `LogicalOr/2`
5. **Function Composition (`∘`)** - `Compose/2`
6. **Set Union (`union` or `∪`)** - `Union/2`
7. **Set Intersection (`intersect` or `∩`)** - `Intersection/2`
8. **Direct Product (`×`)** - `DirectProduct/2`
9. **Sequence (`;`)** - `Sequence/2`

Non-associative operators (like subtraction, division, exponentiation, etc.) would still use the traditional binary representation, although subtraction is addition with a negative.

## Pattern Matching Improvements
- Strengthen pattern variable reuse constraints (ensure consistency when same variable appears multiple times)
- Support for deep pattern matching with nested patterns
✅ Support multiple patterns with fallthrough in match expressions
✅ Handle constructor pattern matching correctly
✅ Fix execution of multiple expressions in pattern match bodies

## OGraph Enhancements
✅ Check that inserting into and extraction from ograph works correct
✅ lib/tools/orbit/tests/ograph_rewrite_single.orb:
✅ Check ograph dot export
✅ Implement attaching Domain on rhs of pattern (in substitution maybe?)
✅ Check ograph operations
✅ Implement pattern matching in ograph
- Extract minimal program from ograph via domain annotation?
- Implement domain hierarchy relationships (e.g., Integer ⊂ Real)
- Cost model is done using different canonical forms. You can have size, memory, speed as different canonical forms
- Implement canonical form computation for common groups (Sₙ, Cₙ, Dₙ, Aₙ)
- Canonical forms of group product, semiproducts
- Add support for Gröbner basis canonicalization for polynomial rings
- Integrate matrix group canonicalization (GL, SL, O groups)
- Implement efficient mechanism to pattern match from a domain down to the terms in that domain
- https://iclr-blogposts.github.io/2025/blog/sparse-autodiff/
- https://greydanus.github.io/2023/03/05/ncf-tutorial/

## Group Theory Implementation
- Implement core group operations (multiplication, inverses, identity checking)
- Add support for cyclic groups Cₙ and rotation operations
- Implement dihedral group Dₙ operations (rotations and reflections)
- Add symmetric group Sₙ and permutation operations
- Implement alternating group Aₙ operations
- Support matrix groups (GL, SL, O) and their operations
- Implement group product operations (direct, semi-direct)
- Add group decomposition functionality
- Implement group isomorphism testing

## Algebraic Structure Support
- Add support for detecting and working with rings, fields, and vector spaces
- Implement Boolean algebra operations and canonicalization
- Add support for lattice operations and partial orders
- Implement semiring detection and optimization
- Add support for modular arithmetic and finite fields

## Multi-Language Support
- Extend to allow JS and other syntaxes more naturally
- Hook in parsers for each language statically, with conventions for patterns
- Create special ids or syntax conventions for cross-language patterns
- Implement an operator language where we can use `(+)` for operator nodes
- Add language-specific evaluators with environment handling
- Create pretty printers for each supported language
- Consider how to handle environment in the ograph for different languages
