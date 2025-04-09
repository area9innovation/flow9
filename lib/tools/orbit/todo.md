Proof of concept:
☑ Small language for Orbit
☑ Driver, types
- Pattern match (unification)
- Evaluation with environment
- Pretty printer
- Extract minimal program
- Have include in Orbit
- Way to read files and parse them and rewrite them and extract them

Math functions for functions to be used in rewrites and on the right hand side.

- Extend to allow JS and other syntaxes. Wrap patterns and rewrites in () if necessary in syntax.
- Then hook in parsers for each language statically, with a convention for how patterns are defined.
- Maybe it is just special ids we always use?
- Have an operator language, where we can just use (+) as the syntax for such a node.
- Each language should have an evaluator with a given environment. Should we have the environment in the ograph?
- Add pretty printers for each language.
