# Orbit TODO List

## Core Functionality
✅ Small language for Orbit
✅ Driver, types
✅ Evaluation with environment. Change call to use the closure in the lambda instead of a new registry
✅ Pattern match (unification)
✅ Pretty printer
✅ Use AST type to avoid evaluating arguments to special calls but keep as ASTs
✅ Build ograph to/from OrMath_exp. Debug it
✅ Add test suite mode to orbit.flow with automated test execution and reporting

## High Priority Tasks
- Add proper error handling and reporting for pattern matching failures
- Extract minimal program from ograph via cost function
- Runtime function to read & parse files
- Implement `include` in Orbit
- Operators as symbols
- Subscripts on operators
- Implement symmetry group based canonicalization rules from canonical.md
- Add support for domain annotations and constraints (`: Domain` and `!: Domain`)
- Implement group operations (direct product, semi-direct product)

## Interpreter Extensions
- Complete all TODOs in `interpretOrbit` (many expression types are unimplemented):
  - Mathematical operations: `OrExponent`, `OrCompose`, `OrDirectProduct`
  - Set operations: `OrSetLiteral`, `OrSetComprehension`, `OrUnion`, `OrIntersection`, `OrSubset`, `OrElementOf`
  - Rewrite rules: `OrRule`, `OrEquivalence`, `OrEntailment`
  - Type operations: `OrTypeAnnotation`, `OrTypeSubstitution`, `OrTypeVar`, `OrFunctionType`
  - Quantifiers: `OrForall`, `OrExists`
  - Notation elements: `OrGreekLetter`, `OrSubscript`, `OrSuperscript`, `OrField`
- Better error handling and recovery mechanisms
- Support for group decomposition syntax and semantics
- Implement bidirectional type mappings as described in canonical.md
- Add support for common group property detection

## Pattern Matching Improvements
- Add support for commutative pattern matching (e.g., `a + b` matching `b + a`)
- Add associative pattern matching (e.g., `(a + b) + c` matching `a + (b + c)`)
- Strengthen pattern variable reuse constraints (ensure consistency when same variable appears multiple times)
- Add wildcard pattern support (`_` matching anything)
- Support for deep pattern matching with nested patterns
✅ Support multiple patterns with fallthrough in match expressions
✅ Handle constructor pattern matching correctly
✅ Fix execution of multiple expressions in pattern match bodies
- Improve pattern matching performance with more efficient algorithms
- Add pattern guards for more complex conditional matching
- Implement destructuring patterns for complex data structures
- Add domain-specific pattern matching (match expressions within specific mathematical domains)
- Support for pattern matching on domain annotations (e.g., `expr : Domain`)
- Implement negative domain constraints (`!: Domain`) for pattern matching
- Add symmetry group based pattern matching (Sₙ, Cₙ, Dₙ, etc.)

## OGraph Enhancements
- Complete domain annotation handling in ograph
- Implement domain hierarchy relationships (e.g., Integer ⊂ Real)
- Add cost model for extracting optimal expressions from ograph
- Improve cycle detection and handling in ograph
- Add domain-specific canonicalization via symmetry groups
- Support more efficient e-class analysis algorithms
- Implement canonical form computation for common groups (Sₙ, Cₙ, Dₙ, Aₙ)
- Add support for Gröbner basis canonicalization for polynomial rings
- Integrate matrix group canonicalization (GL, SL, O groups)

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

## Documentation and Examples
- Create comprehensive documentation for Orbit language features
- Add more examples demonstrating pattern matching and rewriting
- Document OGraph API and usage patterns
- Create tutorials for common use cases (symbolic math, program transformation)
- Add examples of cross-domain transformations
- Document canonical form computation for each supported group
- Create usage guide for symmetry-based optimization

## Performance Optimization
- Optimize pattern matching for large expression trees
- Improve hash-consing for expression deduplication
- Add memoization for commonly evaluated expressions
- Optimize ograph operations for large graphs
- Consider parallel processing for e-graph saturation
- Optimize group-theoretic operations for performance
- Implement efficient canonicalization algorithms for common groups

## Testing
- ✅ Create comprehensive test suite infrastructure with automated testing (run_orbit_tests.sh)
- ✅ Add timeout mechanism to prevent infinite loops in tests (default: 10 seconds)
- ✅ Make test suite output stable by filtering out timing information and exit codes
- ✅ Add expected output validation to catch incorrect behavior even when exit code is 0
- ✅ Add `--generate-expected` flag for easy creation of expected output files
- ✅ Add test cases demonstrating pattern matching with sequences (pattern_matching_fixed_test.orb)
- Add test cases for group-theoretic rewriting rules
- Create tests for canonical form computation in different groups
- Add tests for domain annotation and constraint handling
- Test group decomposition functionality
- Ensure all examples from canonical.md have corresponding tests

- Updated test results: 11 tests pass, 11 tests fail (including 5 timeouts and 3 output mismatches)
- Fix failing tests:
  - Syntax parsing errors:
    - `advanced_runcore_test.orb` - Parse error with array syntax
    - `custom_functions_test.orb` - Parse error in function definition
    - `runcore_test.orb` - Parse error with array syntax
  - Timeout issues (potential infinite loops):
    - `lazy_ograph.orb` - Times out after 10 seconds
    - `lazy_ograph_fixed.orb` - Times out after 10 seconds
    - `ograph_demo.orb` - Times out after 10 seconds
    - `pretty_test.orb` - Times out after 10 seconds
    - `simple_ograph.orb` - Times out after 10 seconds
  - Output mismatch issues (functionality not correctly implemented):
    - `lazy.orb` - Errors in lazy evaluation implementation
    - `match_test.orb` - TODO in pattern match interpreter
    - `pattern_matching.orb` - Type handling errors

- Next steps for testing improvements:
  - Fix tests with output mismatches (implement lazy evaluation correctly)
  - Implement proper handler for OrRule interpretation to fix match_test.orb
  - Fix type handling in pattern matching to properly handle int vs string
  - Add test cases for edge cases in pattern matching
  - Update expected output files as implementation improves
  - Add regression tests for pattern matching edge cases
  - Test cross-domain transformations thoroughly
  - Create benchmarks for performance evaluation
  - Add property-based testing for ograph invariants
  - Consider a more structured test result format (JSON) for better analysis

## Future Work / Exploration
- Implement the orbit function and get it to work with the ograph.
- Add the examples to the tests/ and get them to work.
- Do more advanced examples, for example with Gröbner bases or similar to attempt to generally solve systems of equations in fields.
- Implement the full set of group operations described in canonical.md
- Create real-world optimization examples using symmetry groups
- Develop a mechanism for inferring algebraic structures from code
- Explore applications in program verification using group theory
- Investigate automatic canonicalization based on detected algebraic properties