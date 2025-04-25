# Orbit TODO List
- Glex rules for polynomial rings
- Relational algebra and optimizations of that
- Reuse nodes with add
- Support for pattern matching where we visit all the equivalent nodes as well. => vs -> maybe
- Subscripts on operators
- Explain how we do not have a cost function anymore, but just canonical forms in each domain
- Explain the gather approach in the paper for canonical in n log n time, rather than implicit n^2 from binary bubblesort
- Equivalence between subscripts in unicode and _ and superscripts and ^
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
- Check ograph dot export
✅ Implement attaching Domain on rhs of pattern (in substitution maybe?)
✅ Check ograph operations
✅ Implement pattern matching in ograph
- Extract minimal program from ograph via cost function or domain annotation?
- Implement domain hierarchy relationships (e.g., Integer ⊂ Real)
- Add cost model for extracting optimal expressions from ograph
- Add domain-specific canonicalization via symmetry groups
- Implement canonical form computation for common groups (Sₙ, Cₙ, Dₙ, Aₙ)
- Add support for Gröbner basis canonicalization for polynomial rings
- Integrate matrix group canonicalization (GL, SL, O groups)
- Implement efficient mechanism to pattern match from a domain down to the terms in that domain

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
✅ Add syntax support for quaternion group Q₈
✅ Add syntax support for integers modulo n (ℤ/nℤ or ℤₙ)
✅ Add syntax support for abstract group operation (· or Compose(g,h))
✅ Add syntax support for order of group G (|G|)
✅ Add syntax support for normal subgroup relation (⊲)
✅ Add syntax support for isomorphism (≅)
✅ Add syntax support for homomorphism (φ)

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

## Testing
- ✅ Create comprehensive test suite infrastructure with automated testing (run_orbit_tests.sh)
- ✅ Add timeout mechanism to prevent infinite loops in tests (default: 10 seconds)
- ✅ Make test suite output stable by filtering out timing information and exit codes
- ✅ Add expected output validation to catch incorrect behavior even when exit code is 0
- ✅ Add `--generate-expected` flag for easy creation of expected output files
- ✅ Add test cases demonstrating pattern matching with sequences (pattern_matching_fixed_test.orb)
