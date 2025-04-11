# Orbit TODO List

## Core Functionality
☑ Small language for Orbit
☑ Driver, types
☑ Evaluation with environment. Change call to use the closure in the lambda instead of a new registry
☑ Pattern match (unification)
☑ Pretty printer
☑ Use AST type to avoid evaluating arguments to special calls but keep as ASTs
☑ Build ograph to/from OrMath_exp. Debug it

## High Priority Tasks
- Extend pattern matching to handle all expression types (currently missing many cases)
  - Add cases for comparison operators (OrGreaterThan, OrLessEquals, etc.)
  - Add cases for logical operators (OrLogicalAnd, OrLogicalOr, etc.)
  - Support for set operations and mathematical constructs
- Implement conditionals in pattern matching (the `if` part of rules)
- Support multiple patterns with fallthrough (current match only works with simple rules)
- Extract minimal program from ograph via cost function
- Runtime function to read & parse files
- Implement `include` in Orbit

## Interpreter Extensions
- Complete all TODOs in `interpretOrbit` (many expression types are unimplemented)
- Better error handling and recovery mechanisms

## Pattern Matching Improvements
- Add support for commutative pattern matching (e.g., `a + b` matching `b + a`)
- Add associative pattern matching (e.g., `(a + b) + c` matching `a + (b + c)`)
- Implement pattern variable reuse constraints (ensure same variable binds to same value)
- Add wildcard pattern support (`_` matching anything)
- Support for deep pattern matching with nested patterns

## OGraph Enhancements
- Complete domain annotation handling in ograph
- Implement domain hierarchy relationships (e.g., Integer ⊂ Real)
- Add cost model for extracting optimal expressions from ograph
- Improve cycle detection and handling in ograph
- Add domain-specific canonicalization via symmetry groups
- Support more efficient e-class analysis algorithms

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

## Performance Optimization
- Optimize pattern matching for large expression trees
- Improve hash-consing for expression deduplication
- Add memoization for commonly evaluated expressions
- Optimize ograph operations for large graphs
- Consider parallel processing for e-graph saturation

## Testing
- Create comprehensive test suite for all language features
- Add regression tests for pattern matching edge cases
- Test cross-domain transformations thoroughly
- Create benchmarks for performance evaluation
- Add property-based testing for ograph invariants