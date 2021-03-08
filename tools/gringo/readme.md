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

We might consider to add:

		| term(13) ":" type		// Type annotation

## Semantics

A gringo program takes a string, and produces a sequence of events based
on a stack-based action semantics. It will call the events as a stack of 
matched strings and operations from unquotes. This can be used to construct
an AST or a post-fix forth style program that builds an AST.

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
the matched output of the <term> as a string. As a special case, if you use
$"string", it will produce the verbatim output "string" instead.

These actions are defined through an event-based API. By default, we use a
Forth-like output where the matched tokens are pushed on a stack as strings, 
and then semantic actions are pushed as operations.

Concretely, strings are written as "string" on a separate line, and then 
operations are produced verbatim.

	$"operation"	-> will call addVerbatim with "operation", but match epsilon
	$$"fakematch"	-> will call addMatched with "fakematch", but match epsilon
	$term			-> will call addMatched with the string matched by term
	$$pos			-> will call addVerbatim with a string representation of the position
					   in the input

## TODO

- This construct is exponential:
	exp1 = exp2 (...)+ | exp2

  but can be changed to 

	exp1 = exp2 (...)*

  which is not. Do this, and found out why we did not warn about it.

- Warn if the "last" level of a GPrecedence sequence has left- or right-
  recursion, which will break precedence

- Add error message when we have left recursion deep inside a choice

- JSON output format, with some convention for #args for actions from the name?

- "flowfile" to make a parser driver

- Support multiple grammars to allow composition

- Add JSON action output, parse flow types, and construct actions for that

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

We could introduce an "if this is not there, report error, but otherwise continue" kind of thing.

That can work for missing ; and } and ).

We could also introduce a construct that just keeps going until we see a specific token.
I.e. explicitly add

  e |>
	| recover-at ";";
	
construct, which reports an error, but otherwise, keeps parsing.

Another case is superfluous chars. Here, we could do a match, but otherwise ignore it.

So potentially, the way to do it is to have a "turn error into acceptance, but report it" construct.

	#";"	-> matches ;. If ; is missing, we report an error, but otherwise continue
	#!";"	-> does not match ;. If there is a ;, we match it and report an error, but otherwise continue

To refine it, we could maybe have a construct which recovers, but understands structure to some extend:
{ }, ( ) [ ] are recursively matched.

Another 

We did try a scheme for precedence and associativy inspired by the approach in

	https://matklad.github.io//2020/04/13/simple-but-powerful-pratt-parsing.html

but it turned out to not work well, so we changed to the |> operator instead.

## Expression grammar

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
