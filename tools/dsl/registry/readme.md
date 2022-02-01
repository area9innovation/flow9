# DSL Registry

This is a facility to make a central registry of languages and extensions, such that
these can be registered in Lambda itself.

## Transformations

The registry basically collects a bunch of transformations on programs. Each of these
is fundamentally a function from (AST, environment) to (AST, environment).

## Specifications

The specification is a pattern or rule that describes what this transformation does to a language. 

Read | as "cut" in these:
"lambda|-syntax" means "lambda-syntax" is converted to "lambda", i.e. parsed
"dot|-syntax" means "*dot-syntax" is converted to "dot", i.e. parsed
"|-comprehension" means "lang-comprehension" is lowered to "lang"

So we convert a language with the suffix to a language without the part after the |.

# TODO

- Redo all languages to use this registry

- What about the common runtime, runtime and native fns?

- What about compilers and typing?  We could do:
  - "lambda => flow-syntax" for compilers
  - "lambda => lambda+type" for typing

- Hook up compilers

- Challenge: If we compile lambda+array to flow, we might have special rules that work for array.

- Do we really need the phases?

- Should we have another representation of languages that is not strings?

- Rework the AstEnv to be the egraph
  