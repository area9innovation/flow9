Proof of concept:
☑ Small language for Orbit
☑ Driver, types
- Evaluation with environment. Change call to use the closure in the lambda instead of a new registry0
- Pattern match (unification)
☑ Pretty printer
- Use AST type to avoid evaluating arguments to special calls but keep as ASTs.
- Have `include` in Orbit
- Runtime function to read & parse files
- Build ograph to/from OrMath_exp
- Extract minimal program from ograph via cost function

Other languages:
- Extend to allow JS and other syntaxes more naturally. Wrap patterns and rewrites in () if necessary in syntax.
- Then hook in parsers for each language statically, with a convention for how patterns are defined.
- Maybe it is just special ids we always use?
- Have an operator language, where we can just use (+) as the syntax for such a node.
- Each language should have an evaluator with a given environment. Should we have the environment in the ograph?
- Add pretty printers for each language.
