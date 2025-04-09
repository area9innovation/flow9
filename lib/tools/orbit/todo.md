Proof of concept:
- Small language for Orbit
- Pattern match
- Evaluation with environment
- Pretty printer
- Extract minimal program

Add Graphviz export of an Ograph.
Change orbit to be a language by itself that parses without Mango switch at runtime. This language has nice syntax for the different languages we want.
Wrap patterns and rewrites in () if necessary in syntax.
Then hook in parsers for each language statically, with a convention for how patterns are defined.
Maybe it is just special ids we always use?
Have an operator language, where we can just use (+) as the syntax for such a node.
Implement pattern matching (unification).
Each language should have an evaluator with a given environment. Should we have the environment in the ograph?
Add pretty printers for each language.
Find out how we can write library code for functions to be used in rewrites and on the right hand side.