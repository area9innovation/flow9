# Gringo

This is a Parsing Expression Grammar tool. It provides a way
to write a parser, which will convert a string to another string.

It is designed to allow succinct and composable grammars to be
written.

## Grammar

The (simplified) grammar for Gringo is given here:

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
matched strings and operations from unquotes. This can be used to construct
an AST or a post-fix Forth style program that builds an AST.

## Handling precedence and associativity

The precedence is handled using the |> operator.

	e = e ("+" e)
		|> e ("*" e)
		|> int;
	e
	
is a short-hand syntax for this grammar:

	e = e1 ("+" e) | e1;
	e1 = e2 ("*" e1) | e2;
	e2 = int;
	e

and thus provides a short syntax for the common definition of precedence.

To get minus associativity right, use the "<" lower operator:

	e = e "|" e $$"Or"
		|> e 
			<(
				("+" e | "-" e)*
			)
		|> e "*" e
		|> $var ; 
	var = ('0'-'9')+;
	e

which is short for this grammar:

	e = (e1 ((("|" e) $$"Or"))?);
	e1 = (e2 (((("+" e2) $$"Plus") | (("-" e2) $$"Minus")))*);
	e2 = (e3 ((("*" e2) $$"Prod"))?);
	e3 = $var;

	var = ('0'-'9')+;
	e

The "<" only works on the right-hand side of a sequence.

## Actions

The $<term> construct is used to produce semantic output. This will produce
the matched output of the <term> as a string. The `addVerbatim` and `addMatched`
functions are passed to the parser, and that way, the grammar can have
an effect.

The $ operator comes in a few different forms:

	$"operation"	-> will call addVerbatim with "operation", but match epsilon
	$$"fakematch"	-> will call addMatched with "fakematch", but match epsilon
	$term			-> will call addMatched with the string matched by term
	$$pos			-> will call addVerbatim with a string representation of the 
					   input position in the input

To help define the `addVerbatim` and `addMatched` in a reasonable way, there is
a helper in

	import text/gringo/gringo_typed_action;

which provides useful building blocks for making a stack-based semantic
actions for expression-based languages with unary, binary and ternary operators.

By default, this semantic helper works well for expression-based languages. In case
your language has both statements and expressions, then you have to define a union for
both statements and expressions, and use that for the semantic actions.

## Error recovery

Gringo has a construct to help with recovering better from parsing errors, using the # 
prefix. We support two different recovery strategies:

	#";"	-> matches ;. If ; is missing, we report an error, but otherwise continue
	#!";"	-> does not match ;. If there is a ;, we match it and report an error, but otherwise continue

## Example: Expression grammar

Here is an example expression grammar that matches C
associativity and precedence.

	exp = exp "||" exp $"||"
		|> exp "&&" exp $"&&"
		|> exp "==" exp $"==" | exp "!=" exp $"!="
		|> exp ("<=" | "<" | ">=" | ">") exp
		|> exp <(("+" exp $"+" | "-" exp $"-")*)
		|> exp <(("*" exp $"*" | "/" exp $"/" | "%" exp $"%")*)
		|> exp ("[" exp "]" $"index")+	// Right associative
		|> exp ("." exp $"dot")+		// Right associative
		|> exp "?" exp ":" exp $"ifelse"
		|> 
			"(" exp ")"
			| "-" exp $"negate"
			| "if" exp exp "else" exp $"ifelse" 
			| "if" exp exp $"if"
			| $('0x30'-'0x39'+)
		;
		exp

For real use, it is necessary to add white-space handling, but it should
illustrate how the core grammar can be defined with suitable semantic actinos.

Put your grammar in a .gringo file, and compile it with something like:

	gringo file=mygrammar.gringo out=1 flow=1

and it will produce a mygrammar.flow file with the grammar where it will export
a function like

	parse_exp(DParseAcc) -> bool;

Then use like this:

	import mygrammar;
	import text/gringo/gringo_typed_action;
	import math/math;

	parseExp(a : string, onError : (string) -> void) -> Exp {
		gringoTypedParse(a, expTypeAction(onError), parse_exp, String("Empty parse stack"), onError);
	}

	// This defines the semantic actions used in the grammar
	expTypeAction(onError : (string) -> void) -> GringoAction<List<Exp>> {
		gringoTypedAction(
			// Make a string
			\s : string -> String(s),
			// Extract a string from a value (typically a string)
			\e : Exp -> switch (e) {
				String(s): s;
				default: { onError("Expected string"); ""; }
			},
			// Construct the basic value
			\b -> Bool(b),
			\i -> Int(s2i(i)),
			\d -> Double(s2d(d)),
			// Construct an empty array
			\ -> Array([]),
			// Append an element to an array
			\h, t -> {
				switch (t) {
					Array(es): Array(arrayPush(es, h));
					default: t;
				}
			},
			// A Tree<string, (Exp) -> Exp> of unary operator constructors
			makeTree(), 
			// A Tree<string, (Exp, Exp) -> Exp> of binary operator constructors
			makeTree(), 
			// A Tree<string, (Exp, Exp, Exp) -> Exp> of ternary operator constructors
			makeTree(), 
		);
	}

To construct arrays, the gringoTypedAction helper provides a number of
built-in actions:

	s2i		Convert a string to a typed int
	s2d		Convert a string to a typed double
	true	Make the constant "true"
	false	Make the constant "false"
	list	Construct an empty list or array
	cons	Append an element to a list or array

The `list` and `cons` constructs are very helpful to construct arrays of elements.
Most often used in combination with + and * constructs.

## TODO for Gringo itself

- This construct is exponential:
	exp1 = exp2 (...)+ | exp2

  but can be changed to 

	exp1 = exp2 (...)*

  which is not. Do this, and found out why we did not warn about it.

- Warn if the "last" level of a GPrecedence sequence has left- or right-
  recursion, which will break precedence

- Add error message when we have left recursion deep inside a choice

- Support "flowfile" to make a parser driver

- Support multiple grammars to allow composition

## Inspiration

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
Opcodes from PEGCODE:
	- Match string
	- Jump <address>
	- Backtrack to Choice <address>
	- Call <address>
	- Return
	- Commit <address>
	- Capture
	- Fail

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
some extend: { }, ( ) [ ] are recursively matched.

We did try a scheme for precedence and associativy inspired by the approach in

	https://matklad.github.io//2020/04/13/simple-but-powerful-pratt-parsing.html

but it turned out to not work well, so we changed to the |> operator instead.
