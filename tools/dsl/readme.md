# DSL & Rewriting engine

This is a system to define syntax & semantics for languages, including
rewrite rules and compilers. In other words, a toolbox for making programming
languages.

## Architecture

This system is designed to make programming languages and language features
"first-class". The goal is to separate out the various aspects of programming
languages, make them easy to define in isolation, and importantly, to make them 
compositional so a language can be build from independent pieces.

The result is a system where you can define new programming languages by picking
a base language, and then adding language features on top. The library will then
figure out how to build a combined parser, desugaring, type checker, optimizer, 
evaluator and even compilers for this new combination.

Thus, language features and capabilities become multiplicative: A given language 
feature can be added to many languages, and any new optimization or code generator
will work for many languages.

## Lambda core

There is a special core, basic language called Lambda. This is a simple, pure, 
untyped expression-based lambda calculus with syntax like *flow* expressions. It contains
bools, ints, doubles, string and lists, plus AST nodes. This language has the property
that the AST of Lambda itself (and all other languages in scope) can be represented
in the language itself. So you can also think of Lambda as a kind of Lisp where
programs = data. This property is maintained, so that the system itself can use Lambda 
as the grounding layer for defining new languages and extensions in this language.

### Quoting and unquoting in Lambda

To make working with code as data easy, Lambda includes quoting and unquoting constructs:

	a = 2;
	@1 + $a

evaluates to an value "plus(int(1), int(2))", which represents the program "1+2" in natural
syntax.

### Lowering to Lambda

When you stack language extensions on top of each others, they will lower themselves
down to lower languages until they reach Lambda. That in turn means that the end result
can be evaluated, compiled and so forth, since Lambda itself can do all these things.

You do not have to use Lambda as the base language. You will not directly benefit from 
existing evaluation and compilation targets for Lambda if you don't, but since languages 
are easy to define and extend, this framework still helps in case you want to implement 
some other language.

## Philosophy

The system is designed around some core ideas, which together provide a lot of expressive
power:

- Syntax is important, and defined by the composable PEG-based Gringo parser
- Well designed, functional semantics of the languages and features
- Pure expression-based languages rather than statement based
- Term-rewriting rules for desugaring, lowering and optimizations
- Representing the program AST as an e-graph of equivalent AST nodes in different languages

Consider Flow. Flow itself is NOT expression based. Top-level syntax like "import", "export", 
types and top-level functions are examples that break the expression condition. This turns out 
to be somewhat problematic for various aspects. So in this library, the design has been 
changed to be based around pure expression-based languages.

This property means that rewriting rules become much simpler to reason about and will work
more generally. Experience shows that this approach is superior for compositionality.

## Status

This system is still in early development. The core features are present, and in the
`test.flow` file and `tests` folder, a number of examples of languages and combinations
can be seen.

Most of the language extensions are written in `.dsl` files. See the `languages` folder
for a range of examples.

# Aspects of languages

The system is architectured around some core aspects of programming languages:

- Syntax and parsing. Results of parsing is an AST represented as the `DslAst` type in flow.
- Rewriting/lowering. Term-rewriting rules to transform ASTs to other ASTs,
  both for desugaring, lowering and optimizations through e-graphs. 
- Runtime. Language extensions can provide runtime functions to help implement
  the language features.
- Evaluation. Lambda comes with an evaluator, and a small runtime
- Compilation. Using pattern matching and a blueprint-like language, compilation
  to text formats is easy to specify

## Syntax

The grammar of langugages is specified using Gringo, and will be prepared 
with `registerDslParser(language : string, grammar : string, requires : [string])`.

The semantics actions are defined using actions like "plus_2", "negate_1", where
the suffix defines the arity of the semantic action, i.e. the number of arguments
that AST node should take.

Here is a simple grammar for expressions:

	// The grammar of the language where arity of actions is a naming convention
	registerDslParser("mylang", <<
		exp = exp "+" ws exp $"plus_2" 
			|> exp "*" ws exp $"mul_2"
			|> int
			|> id $"bind_1";	// For pattern matching
		ws exp
	>>, ["ws", "id", "int"]); // adds the expected definitions for these

The `parseDslProgram` call will now parse a string using a given grammar:

	defaultValue : DslAstEnv = parseDslProgram("mylang", <<1+2*a>>);
	println(prettyDsl(defaultValue.ast));

The result is a DslAst representation of the semantic actions, here
pretty-printed:

	plus(int(1), mul(int(2), bind(a)))

### Semantic actions in Gringo

Built in actions include:
- nil for the empty list
- cons for appending to a list
- reverse for reversing a list on the stack
- swap for swapping two elements on the stack
- drop for dropping an element on the stack
- true for DslBool(true)
- false for DslBool(false)
- s2i for converting the top string on the stack to a DslInt
- s2d for converting the top string on the stack to a DslDouble
- dump for printing the contents of the stack - helpful for debugging
- unescape will unescape escaped chars in a string with quotes
- make_node will construct a node with args from the top, and the name
  from the second top 

TODO:
- Integrate the higher-level gringo which has these constructs:
	list(exp) = $"nil" (exp $"cons")*
	listof(exp, sep) = $"nil" exp $"cons" (sep exp $"cons")* sep? | $"nil";
	keyword(name : string) = name !letterOrDigit ws;

  We have the dsl2flow thing now, which should make it relatively simple

- Add a function which adds whitespace after lexical elements

	addws(id "=" exp ";" expsemi $"brace_1" $"let_3") =>
		id "=" ws exp ";" ws expsemi $"brace_1" $"let_3"

	This would almost work, except we would have a problem with keywords:

		addws(keyword(true)) => addws("true" !letterOrDigit ws)
			=> "true" ws !letterOrDigit ws

	if we have natural evaluation order. So avoid that

- Figure out how to add position to all nodes for better error reporting

- Add functions/conditions to Gringo, so we can do the rules grammar
  at a higher level

## E-graph rewriting

The DSL library comes with support for doing semantic term-rewriting using an
e-graph. A rewrite is a pattern on the left hand side that matches AST nodes,
and a rewrite on the right hand side in some language.

	<pattern> => <rewrite>;

Each side is defined using a given syntax. Thus, the language on the left hand 
side can be different from the language on the right hand side. If the language
is the same on both sides, it is often used for optimizations.
When the languages are different, it is often a lowering from a high-level language
to a lower-level language, or it can be a compilation from one language to another.

## Patterns

The patterns on the left-hand side of rewriting rules are simple pattern matching.
They define the AST nodes to match on, and will "bind" variables in the pattern to
an environment.

The pattern can be defined in different syntaxes, as long as the corresponding grammar
for the language has a "bind_1" AST node.

The most general pattern matching language is called "ast", and it matches any AST
node. This pattern:

	plus($l, $r)

will match any "plus" node in the AST, and bind the left hand side to a variable called
"l", and the right hand side to "r".

The same pattern can be written in more natural Lambda syntax like this:

	$l + $r

since the grammar for Lambda will construct a "plus" node for the + sign.

Patterns can have deeper structure, so rewrite rules like this are possible:

	$l + $l + $l => 3 * $l

which will transform expressions like 2 + 2 + 2 to 3 * 2.

TODO:
- Introduce guards in patterns written in some language, maybe with a syntax like this:

	<pattern> => <rewrite> when <condition>

- Add multi-pattern rules. This will allow two separate nodes in the AST to be found,
  and thus things like common-expressions can be found. This is best done if the e-graph
  is represented as a relational structure. https://arxiv.org/pdf/2101.01332.pdf

- Do a DSL for pattern matching itself, maybe like https://arxiv.org/pdf/1807.01872v1.pdf

- Generalize rules for equality (i.e. bidirectional rules), and stopping
   = is equality (substituion both way)
   != is a stopping condition for rewriting.

### Substitutions or the right hand side of rules

The syntax used for the right hand side can be chosen freely. The right hand side
is typically code that will be evaluated with the environment bound. So the code
on the right hand side is typically code, which is evaluated to give the resulting
AST node that will be defined as an equivalent value in the given language.

As the most simple example, look at this pattern which goes from a AST pattern on the 
left hand side to a Lambda program on the right hand side:

	array($e) => e;

The effect of this rule is to "strip" away any "array" nodes, and replaces them with the 
child.

Often, the goal is not to just evaluate the right hand side, but rather do substitution.
This can be done using quoting. In this example, we match an AST syntax on the left, and 
substitute using lanbda on the right:

	exponent($x, $y) => @power($x, $y);

The left hand side matches an AST node called exponent, and binds the two variables into
x and y, while the right hand side constructs a function call to a function called power, 
with the two arguments instantiated.

A similar example is this one:

	for($id, $e1, $e2) => @iter($e1, \$id -> $e2);

In this case, the "iter" runtime function is NOT called at substitution time, since it is quoted. 
Instead, we will construct a call to that function with the given expression for the list, as
well as construct a new lambda for the iter function.

TODO:
- Rewrite the compiler component to be a lowering with blueprint as the language to run
  on the right hand side

- TODO: Make it so we can write the Gringo lowering like this:

  	lowering= prepareDslLowering(gringo, ".",
		<<
			list(@t @s) => $"nil" @t $"cons" (@s @t $"cons")* @s? | $"nil".
			list(@t) => $"nil" (@t $"cons")*.
			keyword(@k) => @k !letterOrDigit ws.
		>>);

### Example of rewriting

Here we define some rewriting rules to optimize simple math expressions in Lambda:

	// The set of rewriting rules we want for optimizations
	registerDslRewriting("optimize", "lambda", "lambda", "lambda", ";",
		<<
			$a + $b => $b + $a;
			$a * $b => $b * $a;
			$a + $a => 2 * $a;
			2 * $a => $a + $a;
			$a + 0 => $a;
			$a * 0 => 0;
			$a * 1 => $a;
			if (true) $a else $b => $a;
			if (false) $a else $b => $b;
		>>,
		// These costs refer to the semantic actions without arity
		// so we can figure out what the costs are. This is used to extract the best reduction
		<<
			int => 1;
			add => 2;
			sub => 2;
			mul => 3;
			div => 4;
		>>,
		// For the plumbing to work with the rewrite engine, we need a default value (in the language syntax)
		<< 0 >>
	);

Now, these rules can be applied using the `performDslTransformations` call:
	
	value : DslAstEnv = parseDslProgram("mylang", << 0 + 123 + 0 * 23 + 1 * 23 + 34 * 2>>);
	replaced = performDslTransformations("optimize", "lambda", value);

	println(prettyDsl(value.ast));
	println("is optimized to\n");
	println(prettyDsl(replaced.ast));

gives this output:

	plus(
		0,
		plus(
			123,
			plus(
				mul(0, 23),
				plus(
					mul(1, 23),
					mul(34, 2)
				)
			)
		)
	)

	is optimized to

	plus(
		123,
		plus(
			23,
			plus(34, 34)
		)
	)

Thus, the transitive application of these rules will simplify the math as much
as possible.

TODO:
- Add stopping criteria for rewriting in the sense of specific eclasses: If the root
  contains a given eclass, we can stop

- Add pulsing: After N iterations, extract the best, and then rerun rules again from
  that point. These two things is what Caviar does https://arxiv.org/abs/2111.12116
  Is verified against Halide

## Evaluator

A runtime evaluator in the form on an interpreter will evaluate programs using a
pre-defined set of natives, which correspond to a simple functional language:

	println(prettyDsl(evalDslProgram(makeDslEnv(), "lambda", program).ast));

The natives defined include:

	ifelse, let, var, call, lambda
	equal, not_equal, less, less_equal, greater, greater_equal
	and, or, not
	add, sub, mul, div, mod, negate
	brace (keeps last value)
	nil, cons, head, tail			// For lists
	nodeName, nodeChild, makeNode	// For nodes
	println

The Lambda language is a very basic, although it does have function overloading.

## Blueprints for compilers

The `makeCompiler` call can prepare a compiler, which compiles a language to
a string.

It uses a syntax like

	plus(a, b)  => $a(40) "+" $b(39);
	minus(a, b) => $a(40) "-" $b(39);
	mul(a, b)   => $a(50) "*" $b(49);
	call(args)  => $glue(args, ",");

where the left-hand side is a pattern to match in the source program, and
the right hand side is a "blueprint". $a(50) means expand the string 
representation of the matched node. The number in parenthesis is to 
help with precedence and associativity. If it is omitted, it is 
understood to be intMax.

This way, we can model precedence and associativity.

To expand lists, we have this construct:

	$glue(<binding>, sep-string)

which will expand the binding (which is a List) and separate each element
using the sep-string.

TODO:
- Introduce blueprint as a right-hand side language, so we can express compilations
  as lowerings

- Compiling Gringo is a problem, since "string" is wrong. Solutions: 
  - Add guards for patterns, so we can check if the string contains " or '. 
  - Add escape for strings when expanding

- Add API to the registry for compiling

## Language registry

The `populateDsls(folder)` call will read all .dsl files in a folder, and
register them into the language registry. That makes them available for
use in the basic apis.

## Runtime

Some language constructs require a runtime, such as fold, map for list-comprehensions,
first, second and third for tuples, and so on. There is a mechanism to define these,
and there is a small common library in `dsl_runtime_common.flow` that is often used.

See `languages/tuples.dsl` for an example of how to reuse common functions, as well
as define custom runtime functions.

# Languages

We have a bunch of languages implemented:

- Lambda is a basic lisp/lambda calculus with flow syntax
- Gringo is the parser language
- AST syntax is the basic syntax for the values in the DSL world
  useful for pattern matching

There are a number of language extensions available:
- dot provides "a.first" syntax as syntactic sugar for first(a)
- arrays provides [1,2] and a[1] syntax for list construction and indexing
- tuples provides (), (1,), (1,2) syntax and first(), second(), ... functions 
  for tuples extracting values from tuples
- datafun provides list comprehension syntax for folds: [ 2 * a | a in list, a != 3 ]
- records provides { a: 1, b: 2 } syntax and accessor functions for the fields
- structs provides "struct Circle(radius)" syntax for making constructors of records
- default_args provides "foo(a, b) { body }" syntax for defining lambdas, as well as
  default arguments like foo(a, b = 2) { body }). These are like C++.
- named_args provides "foo(a =2, b = 3) { body}; foo(a:4, b: 4)" syntax. It is an
  alternative to the C++ convention, which is easier to read.
- ternary_if provides "a ? t : e" syntax for if-then-else
- assign_operators provides "a += 1; a" syntax for "updates"

TODO:
- Allow dependencies between extensions: named_args relies on records.

- Figure out good syntax for stepped range: 1, 3, ... , 9, "1..9 in steps of 2", "1..9 (+2)", ...
  stepped(1..9, 2) could be an option

- Add default values to structs
  - struct Circle(radius = 1), and then "Circle()" gives that
  The goal is to can combine that with named_args and get constructors with named
  parameters: Rect(height: 5)

- Optimize min/max/count/sum/product things for set comprehensions

- Add "guess", "require", and "encourage" constructs for a simple solver:

		guess a in 1..10, b in 1..5;
		require a < b;
		cost (a + b) - 5;
		scope

	which can be converted to something like this:

		best = min([ ((a + b) - 5, a, b) | a in 1..10, b in 1..5, a < b ]);
		a = best.second;
		b = best.third;
		scope;

- Add "with" for structs
    r = Rect(1, 2);
    Rect(r with height = 3)  => Rect(1, 3).

- Add field updates:
    r = Rect(1, 2);
	r.height = 3;  -> Rect(r with height = 3) => Rect(1, 3)

- Add type declaration syntax: 
  - "int a" C style
  - "a : int" flow style

- Add OpenSCAD compiler

- Add GLSL compiler

# Future plans

- Improve debugging of language extensions. Right now, it is hard to figure out why
  a parser, rewrite rule or lowering does not work.
- Add DSL for type checking
- Add DSL for test cases for all of the above
- Add DSL for grammar rewriting
- Add DSL for macros/compile evaluation
- Add DSL for layout

# Use cases

## Material Layout

Define operators for laying out a list of components, so we get high-level design
contruction mechanism.

Operators include:
	,   cols2
	\n  lines2
	over  group2
	<op> 3 <op>   is repeat, and alternate. So ", 3 \n" makes a three columns
	table(<op>)   means that the cols/lines inside should be collected to a table
	if (<con>) op else op   allows responsive design
	"oracle(1..n)" with "cost" allows optimization of parameters of a program
	alternative(...)  uses the oracle to help find the best alternative of a list of those

TODO:
- Add structs with default arguments
- Allow constructors with named arguments

## Database

- Data structures suitable for databases
  - Postgres has 1 GB big files with blocks of fixed size.
  - Each block has an array of pointers to tuples inside it.
  - Thus, pointing to something is a block number and then the line number for it. This is called a TID
  - B-tree for indexes
  - Linear scan follows pointers
  - Bitmap scan first builds a bitmap of what rows match a condition, and then run through the bitmap to retrieve them
    - Useful when we do not want duplicates, or if there are multiple conditions in which case "or" and "and" of the bitmaps
      can be helpful
  - Hash tables for keys
    - Has buckets for hash code and TID.
    - There is an overflow area for collisions
    - There is a bitmap for what overflow areas are free
  - The choice of algorithm for doing a query depends on whether the data is physically sorted on disk similar to the data
    or not
So a query is converted into a set of operations of specific data structures.

Postgres has a notion of partial indexes. Basically, we only index rows that obey some condition.

Bloom filters allow false positives, but not false negatives.

Idea:
- Have multiple data structures depending on the schema of the data, and automatically construct
  the corresponding algorithms to use them

The data structures need to support insert, update, delete, and retrieval.

Queries can be mathematically simplified using adjunctions:
https://dl.acm.org/doi/pdf/10.1145/3236781

The core idea is that we can use set comprehension syntax to implement all relational
operations, including joins, but with bag semantics and efficiency. Also, since this
is highly mathematical, a lot of optimizations are possible on this DSL.

So concisely, relational algebra can be translated into bag-comprehensions. The key
operator is an indexing step, which can build (or reuse an existing) index over a table.

Here is an implementation of relational algebra, probably using this approach:
http://hjemmesider.diku.dk/~henglein/src/

See also this one:
https://www.awelm.com/posts/simple-db/

Pipeline:
Relational algebra
 (optimizations)
List/bag-comprehensions
 (optimizations)
Compile list/bag-comprehensions into tight code.

# Journal logging for persistence

Memory database with replication through logging and CRDTs.

# CRDTs

Reflexivity
Commutativity
Idemponence

Operation required: Less or equal to be defined (leq)

With a map CRDT defined, we get counters (map from unique id to counter),
and sets (map to null).

Deletion: Model it by ordering: undefined, defined, deleted.

Time: Relies on less than (rather than less or equal). If machine A sends
a message to machine B, we can deduce that the sending happened before receiving it.
That defines a lattice/partial ordering.

The core convergence is defined by three kinds of operations:
1) Doing some update on a CRDT data structure
2) Sending an update to another machine
3) Receiving an update from another machine
These three things imply that things are good.

Last Write Wins is a CRDT for storing any opaque value without comparison.

With a LWW and a deletion ordering combined, we can get a cell that support deleting and readding.

# Challenge

Design a programming language which can define all the basic algorithms
and CRDTs.

https://github.com/automerge/automerge

# Prolog

// https://www.swi-prolog.org/download/publications/A_Portable_Prolog_Compiler.pdf

Instructions:

enter - marks the change from head to body of a clause.
call - call has an offset to the procedure to call
exit - ends a clause

Terms:
const <offset> - pointer to an integer or atom
var <number> - each variable is numbered

function <offset>
<code for first arg>
<code for second arg>
pop

The paper has an interpreter for this VM, which looks pretty simple.

There is a Java implementation here:
https://github.com/arnobastenhof/prolog-jvm

// WAM

https://pdf.sciencedirectassets.com/271869/1-s2.0-S0743106600X00891/1-s2.0-0743106694900310/main.pdf?X-Amz-Security-Token=IQoJb3JpZ2luX2VjEPH%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLWVhc3QtMSJHMEUCIQCxASki9hl67E1oqllEM1lfsXQcKYChi1bPoWr26K%2F0UQIgIwxeoXpEiUBNzi6X3L4GwC%2BphjTNRjAhqG5sCuRkZzoq%2BgMIKRAEGgwwNTkwMDM1NDY4NjUiDCN7vttTBFXIovjGNCrXA3WbZBVnmNtl3BqVldzhpIZEahOjuaTe6nB5Afp4YUOlCwCrXj7Hw0LeC5O8T%2BVrkIoZYNl9cS%2BLnhze9m%2FEHPeLvuC0sCmiOZ5zhuFSV4YEpEVmJ%2Fc7n5%2FxrQDMCHsbIPmGVW3xBxepJS2Vj2lJ73gcVEOoIpBuQI5cSG%2BEQePMe2ovwyBhuGv8JyWJp%2Btroobd%2BujsurmWcrAp1oSBRxEHDY737wQdqMbDTJv4wXxBgDIoVjWj2Z4pRI%2B8z%2FzvfpJb%2BExnRIwG7VuLeL86%2FywU6atWlEyJRePh3%2Bpd%2FkWHx%2Fz6jxD%2B09plD2Hc1JlrDyBdkTIUTBfJQqI%2FtPHhghjGlEz6306SmvGHOwwrdN8uuSmp2hW2JRTbaC1mRVn4As4CprOEPGtWPJTMn3C4dNG5nku%2FGpriqji4%2B51Du%2F3DcgpaSVZkrAz2aSD592RiCBRhiP%2F3pV02pGRWOaxxWXsZu07z9r2TUueJLBZYzD%2BVXKVuvZ9lFXVdEYhHGGGUUMS%2Bx2ibbbaYAGBvoaeVJuloyQjbLzctVjrAnsYmss7Oo09yuzIFp4y7EIqHJwncz%2FG2vwU0G%2FVIL1pBxKYsn%2BktQEFRAQ%2BCAlZbFtbGUCSosqRPVFCQkzDut96PBjqlAZllgKH%2BQulc7RRxuvOec2VgP5V4NvgyBIDIorzVhKWQe%2FJiU%2B0j9%2BIHKaUnZp6PmAl%2B4piHlbhsiZtqfWS5kYsNeNu9EvUscQ7zu5a8aBnrLybjRTfQKzApk7S%2FnpWlo6DUsGRQAEO1EZrsH88mayG4c%2BInpUu88oSGMupxXfHoECjNhnSTDiHGZUIwLPO6PkUTZ6tqxQwWyfcA4TMURGF72oNYkg%3D%3D&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20220131T084944Z&X-Amz-SignedHeaders=host&X-Amz-Expires=300&X-Amz-Credential=ASIAQ3PHCVTY3ADRNLHN%2F20220131%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Signature=25033d6ea351b7d37ddaa4b902d8effabda6f93349f51547174a488af9bfadfe&hash=bb966ce3016168914f694189a48ee88aba436edd7ff80556c629882873272719&host=68042c943591013ac2b2430a89b270f6af2c76d8dfd086a07176afe7c76c2c61&pii=0743106694900310&tid=spdf-068bb2f6-720b-4d07-83f5-ee0088d755e0&sid=d0b923618409e84b5668a6b-a85181ce0962gxrqb&type=client

Small implementation in simple Java
https://drops.dagstuhl.de/opus/volltexte/2018/8453/pdf/OASIcs-ICLP-2017-10.pdf

https://github.com/ptarau/iProlog/blob/master/IP/src/iProlog/Engine.java

In clojure:
https://github.com/nbyouri/miniprolog/tree/master/miniprolog

In TS:
https://github.com/nathsou/Picolog

In Haskell with a nice AST:
https://github.com/kfl/miniprolog

In c++:
https://www.cl.cam.ac.uk/~am21/research/funnel/prolog.c
https://github.com/apaz-cli/Prolog-Interpreter/blob/master/prolog.c

In Rust:
https://github.com/julian-blaauboer/ergo



# Other Ideas

More language features:
- references
- import, export
- native
- "with" syntax
- switch expressions
- ?? maybe syntax

More backends:
- Kotlin
- Java
- C++

Standard library:
- string library
- math functions
- DS: Tree -> rewrite the flow one?

- New layout for Material

   [ Text("asdfasdf") | a in some-list ]  

  ,  -> cols2
  \n  -> lines2

  "n-times".   , 3 \n
    1   2   3
	4   5   6
	7   8   9
 (if mobile , 2 \n else , 4 \n)

- width = oracle(5 .. 10);
  cost = overlap(this andet, ) < 0 && line-width < 70 chars per line;
  optimize(sdf)

- graphics library based on math, in particular raymarching

- SSql new syntax based on set comprehensions

	[ u.name | u in users, c in classes, cl in class_learners cl, cl.class_id == index(c.id), cl.user_id == u.id ]

- math rule engine. Integrate that here
 
- Compiler generator
- master key
- ssql
- wigi, wigiexp
