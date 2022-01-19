# DSL & Rewriting engine

This is a system to define syntax & semantics for languages, including
rewrite rules.

## Syntax

The grammar is specified using gringo, and prepared with `defineGrammar(name, grammar, additions)`.

The semantics actions are defined using actions like "plus_2", "negate_1", where
the suffix defines the arity of the semantic action.

Here is a simple grammar for expressions:

	// The grammar of the language where arity of actions is a naming convention
	mylang = defineGrammar("mylang", <<
		exp = exp "+" ws exp $"plus_2" 
			|> exp "*" ws exp $"mul_2"
			|> int
			|> id $"bind_1";	// For pattern matching
		ws exp
	>>, ["ws", "id", "int"]); // adds the expected definitions for these

### Semantic actions in Gringo

Built in actions include:
- nil for the empty list
- cons for appending to a list
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

		addws(keyword(true) => addws("true" !letterOrDigit ws)
			=> "true" ws !letterOrDigit ws

	if we have natural evaluation order.
	Maybe that can be fixed in practice by having a "ws !letterOrDigit ws" => "!letterOrDigit ws"
	rule, or we should have a guard against 'string !term' so we do not process that.

- Figure out how to add position to all nodes for better error reporting

- Add functions to Gringo?

## Parsing

The `parseProgram` will parse a string using a given grammar from `defineGrammar`:

	defaultValue : DslAst = parseProgram(mylang, <<123+0*434+abd>>);
	println(prettyDsl(defaultValue));

The result is a DslAst representation of the semantic actions. 

## E-graph rewriting

The DSL library comes with support for doing semantic term-rewriting using an
e-graph.

# Example

	// The set of rewriting rules we want
	rules = parseRules(mylang, <<
		a + b => b + a;
		a * b => b * a;
		a + a => 2 * a;
		2 * a => a + a;
		a + 0 => a;
		a * 0 => 0;
		a * 1 => a;
	>>);

	// For the plumbing to work with the rewrite engine, we need a default value (in the language syntax)
	defaultValue : DslAst = parseProgram(mylang, << 0 >>);

	// These costs refer to the semantic actions without arity
	// so we can figure out what the costs are. This is used to extract the best reduction
	costs = rewriteCosts(<<
		int => 1;
		plus => 2;
		mul => 3;
	>>);

	testValue = parseProgram(mylang, << 0 + 123 + 0 * 23 + 1 * 23 + 34 * 2 >>);

	replaced = rewriteDsl(testValue, defaultValue, rules.rules, costs.costs, 2);
	println(prettyDsl(testValue));
	println("is optimized to\n");
	println(prettyDsl(replaced));

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

TODO:
- Add stopping criteria for rewriting in the sense of specific eclasses: If the root
  contains a given eclass, we can stop
- Add pulsing: After N iterations, extract the best, and then rerun rules again from
  that point. These two things is what Caviar does https://arxiv.org/abs/2111.12116
  Is verified against Halide

## Patterns

Our patterns are simple matching only, but we should allow guards written in Lambda.

TODO:
- Figure out how patterns can be reused from e-graph to compiling to lowering.
  Should we do an egraph implementation directly on DslAst?

- Figure out how to work with AST directly in Lambda. Maybe it is trivial?

- Do a DSL for pattern matching, maybe like https://arxiv.org/pdf/1807.01872v1.pdf

## Lowering

In addition to rewriting using the e-graph, we should have a more predictable
rewriting system for lowering phases where we do not have any costs.

- TODO: Make it so we can write the Gringo lowering like this:

  	lowering= prepareDslLowering(gringo, ".",
		<<
			list(@t @s) => $"nil" @t $"cons" (@s @t $"cons")* @s? | $"nil".
			list(@t) => $"nil" (@t $"cons")*.
			keyword(@k) => @k !letterOrDigit ws.
		>>);

# Evaluator

A runtime evaluator in the form on an interpreter will evaluate programs using a
pre-defined set of natives, which correspond to a simple functional language:

	println(prettyDsl(evaluateDsl(makeDslEnv(), program)));

The natives defined include:

	ifelse, let, var, call, lambda
	equal, not_equal, less, less_equal, greater, greater_equal
	and, or, not
	add, sub, mul, div, mod, negate
	brace (keeps last value)
	nil, cons, head, tail		// For lists
	name, child					// For nodes

TODO: Add "construct" for node construction.

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

- Compiling Gringo is a problem, since "string" is wrong. Solutions: 
  - Add guards for patterns, so we can check if the string contains " or '. 
  - Add escape for strings when expanding

## Composition of languages

Right now, it is a manual process to extend the languages together. Figure out a way
to make it more automatic, so you can just parse/eval/run any language combination.

## Runtime

Some language constructs require a runtime, such as fold, map for list-comprehensions,
first, second and third for tuples, and so on.
Implement a mechanism for these.

# Future plans

- Add DSL for type checking
- Add DSL for test cases for all of the above
- Add DSL for grammar rewriting
- Add DSL for macros/compile evaluation
- Add DSL for layout

## Speedrun towards DB

- DSL language v0.1
 - Add multi-pattern rules. https://arxiv.org/pdf/2101.01332.pdf

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


Pipeline:
Relational algebra
 (optimizations)
Bag-comprehensions
 (optimizations)
Compile bag-comprehensions into tight code.

# Journal logging for persistence

Memory database with replication
CRDTs

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
