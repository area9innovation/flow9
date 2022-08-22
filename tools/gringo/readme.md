# Gringo

This is a Parsing Expression Grammar tool. It provides a way
to write a parser, which will convert a string to another string
or an AST.

It is designed to allow succinct and composable grammars to be
written.

## YouTube video

There is a video showing how to write a grammar using Gringo
here:

https://youtu.be/ZnIlsZbY4JY

## Grammar

The (simplified) grammar for Gringo itself is given here:

	term = 
		term "|>" ws term 							$"GPrecedence"
		|> term "|" ws term 						$"GChoice"
		|> term term								$"GSeq"
		|> "$" ws term								$"GUnquote"
		|> "<" ws term								$"GLower"
		|> "#" ws term								$"GError"
		|> term "*" ws								$"GStar"
		|> term "+" ws								$"GPlus"
		|> term "?" ws								$"GOpt"
		|> "!" ws term								$"GNegate"
		|> 
			"(" ws term ")" ws							
			| '"' string '"' ws							$"GString"
			| "'" char "'" ws "-" ws "'" char "'" ws	$"GRange"
			| "'" stringq "'" ws						$"GString"
			| id ws "=" ws term ";" ws term				$"GRule"
			| id ws										$"GVar"
		;

See `gringo.gringo` for the real grammar.

## Semantics

A gringo program takes a string, and produces a sequence of events based
on a stack-based action semantics. It will call the events as a stack of 
matched strings and operations from "unquotes". This can be used to construct
an AST or a post-fix Forth style program that builds an AST. This is
explaining below.

## Handling precedence and associativity

The precedence is handled using the |> operator.

	e = e ("+" e)
		|> e ("*" e)
		|> int;
	e
	
which is a short-hand syntax for this grammar:

	e = e1 ("+" e) | e1;
	e1 = e2 ("*" e1) | e2;
	e2 = int;
	e

and thus provides a short syntax for the common definition of precedence.

To get the associativity of "minus" right, use the "<" lower operator:

	e = e "|" e $"Or"
		|> e 
			<(
				("+" e $"Plus" | "-" e $"Minus")*
			)
		|> e "*" e $"Prod"
		|> $var; 
	var = ('0'-'9')+;
	e

which is short for this grammar:

	e = (e1 ((("|" e) $$"Or"))?);
	e1 = (e2 (((("+" e2) $"Plus") | (("-" e2) $"Minus")))*);
	e2 = (e3 ((("*" e2) $"Prod"))?);
	e3 = $var;

	var = ('0'-'9')+;
	e

The "<" only works on the right-hand side of a sequence.

In some situations, you can use the empty string to ensure that
right-recursive constructs refer to top-level expression, rather than
the following once:

	exp = ...
		|> '\' ws lambdaargs "->" ws exp ""  // The "" makes right-recursion disappear
		|> ...
		;

## Actions

The `$<term>` construct is used to produce semantic actions. This will send
the matched output of the `<term>` as a string to the `addVerbatim` action 
function. As a user of the grammar, you provide an `addVerbatim` and a 
`addMatched` functionto the parser, and that way, the grammar can have
an effect.

The `$` operator comes in a few different forms:

	$"operation"	-> will call addVerbatim with "operation" (but match epsilon)
	$$"fakematch"	-> will call addMatched with "fakematch" (but match epsilon)
	$term			-> will call addMatched with the string matched by term
	$$pos			-> will call addVerbatim with a string representation of the 
					   input position in the input

To help define the `addVerbatim` and `addMatched` in a reasonable way, there is
a helper in

	import text/gringo/gringo_typed_action;

which provides useful building blocks for making a stack-based semantic
actions for expression-based languages with unary, binary and ternary operators.

See the tutorial below for real examples of how this works.

By default, this semantic helper works well for expression-based languages. In case
your language has both statements and expressions, then you have to define a union for
both statements and expressions, and use that for the semantic actions. Since Gringo
is built to support fully typed semantic actions, this is the best compromise in terms 
of power and safety.

## Error recovery

Gringo has a construct to help with recovering better from parsing errors, using the # 
prefix. We support two different recovery strategies:

	#";"	-> matches ;. If ; is missing, we report an error, but otherwise continue
	#!";"	-> does not match ;. If there is a ;, we match it and report an error, but otherwise continue

## Tutorial

In the `tutorial/` folder, there is a complete parser for a simple expression language
with the main part being like this:

	exp = exp "||" ws exp $"||"
		|> exp "&&" ws exp $"&&"
		|> exp "==" ws exp $"==" | exp "!=" ws exp $"!="
		|> exp ("<=" ws exp $"<=" | "<" ws exp $"<" | ">=" ws exp $">=" | ">" ws exp $">")
		|> exp < ("+" ws exp $"+" | "-" ws exp ws $"-")*
		|> exp ("*" ws exp $"*" | "/" ws exp $"/" | "%" ws exp $"%")*

		|> exp ("[" ws exp "]" ws $"index")+ 
		|> exp ("." ws exp $"dot")+
		|> exp "?" ws exp ":" ws exp $"ifelse"

		|> "-" ws exp $"negate"

		|> (
			"if" ws "(" ws exp ")" ws exp "else" ws exp $"ifelse" 
			| "if" ws "(" ws exp ")" ws exp $"if"
			| "(" ws exp ")" ws 
			| "true" $"true"
			| "false" $"false"
			| string ws $"unescape"
			| int ws $"s2i"
			| "[" ws exps "]" ws
		);

This grammar has correct precendence and associativity similar to C. It also features the 
recommended approach to handling white-space, which is very similar to `Lingo`.

The main program `tutorial.flow` demonstrates how to use the interpreter to parse a simple language
into this, simple AST:

	Exp ::= Int, String, Call, Array;

	Int(i : int);
	String(s : string);
	Call(op : string, args : [Exp]);
	Array(values : [Exp]);

The program contains all main aspects of how to make a grammar and using it to construct the 
typed AST, using three different approaches:

  1) Parsing and preparing the grammar at runtime, and the interpreting it to parse
  2) Using a pre-processed grammar that is interpreted to parse.
  3) Using generated flow code to parse

Option 1 is flexible, since you can change the grammar and quickly check that it works.
Option 2 is mostly useful as a demonstration. The grammar is saved in exp_grammar,
using the `out=1` option to `Gringo`. Can be helpful when debugging.
Option 3 is the most efficient, and recommended for production. The parser is saved in
exp_parser.flow using the `compile=1` option to Gringo.

So when you start a new grammar, we recommend you use approach 1. Once your grammar and
semantic actions are complete, then switch to the third approach for the best performance.

We also recommend that you consider to use `gringoParseWithActionCheck` which will check
that any actions ($"action") mentioned are present in your semantic actions, as well
as do a coverage analysis to check if a specific text parsed covers all semantic actions.
See `parseExpWithPreprocessedGringo` in the tutorial for an example.

## Semantic action helper

To help with semantic actions, the `gringoTypedAction` helper provides a number of
built-in actions:

	s2i		Convert a string to a typed int
	s2d		Convert a string to a typed double
	true	Make the constant "true"
	false	Make the constant "false"
	list	Construct an empty list or array
	cons	Append an element to a list or array

The `list` and `cons` constructs are very helpful to construct arrays of elements. 
Most often used in combination with `+` and `*` constructs. See the Array construct 
in the tutorial to see how this pattern works in the `exps` production.

## Using the DSL parser and associated semantic actions

An alternative is to use the action provider working on the DslAst type, which comes
with a helper function to parse according to a given grammar, and produce a `DslAst`
structure as the result:

	parseProgram(file : string, grammar : DslGrammar, program : string) -> DslAst;

See `lib\tools\dsl\dsl_parse` and the readme in that folder for more info.

### Producing types from the grammar

If you use the DSL semantic actions, then you can also get a set of appropriate 
flow types produced by Gringo:

	gringo myfile.gringo types=1 type-prefix=My

this will produce a `myfile_types.flow` file with flow types prefixed with `My`
that match the grammar.

This works by doing a type inference evaluation of the grammar, and use that to 
determine what type each rule results in. These are then converted into the appropriate
unions and structs as flow types.

If you also add a `master-type=Name` argument, a typed parser will also be constructed
that uses the inferred types. This works by parsing to the DslAst type, and then invoking
a constructed converted from DslAST to the typed union for the grammar.

If you also add `eclasses=1`, each of the types will get an eclass field, initialized to 0,
which is helpful for type inference and other things.

See `gringo/tflow` for an example that demonstrates this approach for a simple grammar.

TODO:
- Add option to get position tracking added to the grammar

## Using a compiled grammar

Put your grammar in a `.gringo` file, and compile it with something like:

	gringo file=mygrammar.gringo out=1 compile=1

and it will produce a `mygrammar_parser.flow` file with the grammar where it will export
a function like

	parse_exp(acc : DParseAcc<?>) -> bool;

Then use like this:

	import mygrammar;
	import text/gringo/gringo_typed_action;
	import math/math;

	parseExp(a : string, onError : (string) -> void) -> Exp {
		gringoTypedParse(a, expTypeAction(onError), parse_exp, String("Empty parse stack"), onError);
	}

See also the tutorial for more hints.

## Comparison with Lingo

Gringo is an expression-based grammar, while Lingo has "production statements" and then terms. 
This is why your grammar in Gringo has to end with the name of the production to match. 
In Gringo, productions are just let-bindings with a body:

	a = <term>;
	body

Gringo does not have caching, and thus is potentially more efficient for grammars that do not
need much backtracking, since we do not use memory to keep a cache. Since Gringo automatically 
transforms left-recursion, as well as provides features for handling precendence and associativity, 
the resulting grammars are shorter and easier to understand.

Gringo does not use bindings for semantic actions, but rather is based on a stack discipline.
This is also more efficient, since it does not require a binding environment, but just a
simple stack (in the form of a List).

This also allows Gringo to support fully typed semantic actions, in contrast to Lingo, which
relies on the dynamic "flow" type to allow semantic actions.

Gringo has simple support for error recovery, while Lingo does not. The implementation of 
Gringo itself is shorter and simpler than Lingo. This is a result of Gringo being an 
expression-based language.

Gringo is a relatively new tool. A complete grammar for flow has been written in Gringo, and
is known to work well. There are no known bugs in the parsers. That said, it might be that 
there are some rough edges in the tooling.

## Potential optimizations in the generated code

The code generated by the compiler is decent, but can be improved.

The compiler works by converting the grammar to the DCode opcodes, and then compiling
those to flow code.

Optimizations possible in generated Gringo parser: 

- Change NOT to be a sequence
- Epsilon is probably correctly compiled to TRUE
- Add a C++ or Rust backend for DCode and try to use Wasm

## TODO for Gringo itself

- This construct is exponential:
	exp1 = exp2 (...)+ | exp2

  but can be changed to 

	exp1 = exp2 (...)*

  which is not. Do this, and found out why we did not warn about it.

- Warn if the "last" level of a GPrecedence sequence has left- or right-
  recursion, which will break precedence

- Add error message when we have left recursion deep inside a choice

- Support multiple grammars to allow composition

Consider to make an overlay, where the semantic actions can be written
inline:

	"if" !letterOrDigit ws "(" ws exp ")" ws exp "else" ws exp \PIf($0, $1, $2)

where we look at the right hand side of \, and find the biggest $, and use
that to extract that number of elements from the stack, and thus, can generate
the action tree.

semaction = "\" sem-exp
	sem-exp = id "(" sem-exps ")" | $ int;
	sem-exps = $"list" sem-exp ("," sem-exp $"cons")* | $"list";

## Inspiration

Extending PEG with various things:
https://norswap.com/pubs/thesis.pdf

Optimizing PEG grammars:
https://mpickering.github.io/papers/parsley-icfp.pdf

Normal forms (page 22 in parsely.pdf):

	Choice: right associate
	(p | q) | r   =>   p | (q | r)

	Seq: left associative
	p (q r)  => (p q) r

For choice sequences, if the first char of each choice is defined, it can be tabled by the
first char.

Overly complicated opcodes (page 39):

	CharTok
		Tab			- specialization to keep column number efficient
		Newline		- specialization to keep line number efficient
	String			- They are preprocessed to update line/col efficient
	Sat

Initial pegcode paper:
http://www.inf.puc-rio.br/~roberto/docs/peg.pdf

Adding error recovery:
https://www.eyalkalderon.com/nom-error-recovery/

They have a "throw" error failure state with a label, instead of just a bool "fail". This state is not
handled by choice, but bubbles up. For each label, there is another grammar which recovers from that 
error.

If that recovery rule is epsilon, that means that we are tolerant to missing tokens, and just report an
error, but otherwise continue. This works for ; and missing trailing ).

Another recovery rule skips everything until an unbalanced } is hit.

They describe a procedure of using first(*) and follow(*) operators to automatically come up with recovery
schemes.

The simplest way of handling syntax errors a bit better is to include the max. position we have seen.

We could also introduce a construct that just keeps going until we see a specific token.
I.e. explicitly add

  e |>
	| recover-at ";";

construct, which reports an error, but otherwise, keeps parsing.

To refine it, we could maybe have a construct which recovers, but understands structure to 
some degree: { }, ( ) [ ] are recursively matched.

We did try a scheme for precedence and associativy inspired by the approach in

	https://matklad.github.io//2020/04/13/simple-but-powerful-pratt-parsing.html

but it turned out to not work well, so we changed to the |> operator instead.
