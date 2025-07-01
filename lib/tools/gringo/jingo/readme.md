# Jingo - Gringo Joy&Forth

Jingo is a language, which can be used for the semantic actions in a Gringo
grammar. This is naturally a stack-based, postfix language, given the nature of a
PEG-style parser. 

This language also serves as a secondary goal to compile Gringo grammars into. 
It makes sense to try to make this the same language as the semantic actions.

So the goal is define a stack-based language, which can be evaluated effectively,
as well as be compiled to other languages, so we can compile the parsers and semantic
actions to a host of languages.

Jingo is that language.

## Status

Jingo is incomplete.

It turns out that Jingo is not really needed. Experience has shown that the
typed action helpers is sufficient for almost all grammars we have seen so far.
Also, it was surprisingly easy to produce relatively good flow code for the
parsers, so the point of Jingo eroded.

Study Jingo if you are interested in Forth, but there is no production use
of Jingo at this point in time, and no plans to develop it further.

## Inspirations

We are inspired by Forth, Factor, and Joy.

An awesome implementation of Forth:
https://github.com/nornagon/jonesforth/blob/master/jonesforth.S

Factor is a typed Forth:
https://factorcode.org/

Joy is a concatenative functional language:
http://joy-lang.org/

## Literals/types

We support these values:

- ints
- string
- arrays (which also works as qouted code)
- native

## Syntax

Here is a simple program, which squares the number 5 using a "sq" operand:

	let sq = dup *;
	5 sq

## Operators or Words

Common stack operations:

	x drop ->
	x dup -> x x
	x print ->
	x y swap -> y x
	x y z rot -> y z x
	x y dup2 -> x y x y

We support arrays, but this syntax is also used to quote code:

	[ lit lit ... lit ]	   -> <array>
	[ word word ... word ] -> <quoted-program>

This is similar to Joy.

In addition, we support common int operations:

	x y + -> x+y
	x y - -> x-y
	x y * -> x*y
	x y / -> x/y
	x y % -> x%y

String:

	<string> length -> <int>
	<string> <int> get -> <string>
	<string> <int> getcode -> <int>
	<string> s2i -> <int>
	<int> i2s -> <string>
	<string> <string> + -> <string>

TODO:

	x y over -> x y x
	x y z rot- -> z x y
	x y drop2 ->
	x ... n dropn ->

Array:
	[y] x cons -> [x, y]
	[h tail] uncons -> x [y] (or maybe the other way around?)

	[x] [y] concat

	[x] size

	[x] i get


Comparisons & logic:

	x y = -> 0/1
	...
	x y and -> 0/1
	x y or -> 0/1
	x not -> 0/1

From Joy:
	[q] i  		-> eval(q)    will evaluate a quoted argument	(aka eval)

	x [q] dip   -> eval(q) x
		let dip = i swap;
	nullary
	map
	step
	sieve
	filter
	infra
	linrec

## Builtins

We support conditionals:

	b [then] [else] ifte  -> <eval then or elsse>

TODO:
	b {code} if  -> <eval code0 or nothing>

Also, we support eval to unquote an array:

	[quote] eval -> (result of code)

The word "i" is a synonym for "eval" to be compatible with Joy.

## Standard library

We could set up a standard library in Jingo itself:

	x sq -> x*x
	fold
	map
	while

## Peg codes

We want to have a std library for pegcodes, so we can compile a Gringo grammar
to a complete Jingo program.

## Loops a la RPL?

index_from index_to FOR variable_name loop_statement NEXT

index_from index_to FOR variable_name loop_statement <int> STEP

 WHILE condition REPEAT loop_statement END
 DO loop_statement UNTIL condition END
