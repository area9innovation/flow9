*lingo*
======

*lingo* is a technology to make it easy to construct Domain Specific Languages or parsers. It is a language 
for specifying grammars that work well with *flow* code. It takes a grammar written in *lingo*, and can use that
to lex and parse a string and construct a structure to represent that. In other words, it is a language that
is useful to implement lexing, parsing and AST construction for compilers or interpreters. Lingo itself
is interpreted by a *flow* program, found in `lingo/pegcode/pegcompiler.flow` for the Lingo compiler that 
produces pegcode bytecode representing the grammar, and in `lingo/pegcode/pegcode.flow` for the parser that 
interprets pegcode bytecode.

*lingo* is based on [Parsing Expression Grammars (PEG)](http://en.wikipedia.org/wiki/Parsing_expression_grammar)
and inspired by [Ometa](http://tinlizzie.org/ometa/).

* [Syntax](#syntax)
* [Bindings and actions](#bindings-and-actions)
* [Position of match in string](#position-of-match-in-string)
* [Testing a grammar](#testing-a-grammar)
* [Debug](#debug)
* [Tracing](#tracing)
* [Caching](#caching)
* [Clearing the cache](#clearing-the-cache)
* [Instruction level rule profiling](#instruction-level-rule-profiling)
* [Common problems](#common-problems)
* [Basic way of using a grammar in a flow program](#basic-way-of-using-a-grammar-in-a-flow-program)
* [Using custom semantic actions](#using-custom-semantic-actions)
* [Precompiling a grammar for efficiency](#precompiling-a-grammar-for-efficiency)
* [How to handle white-space](#how-to-handle-white-space)
* [Checking text for matching to grammar](#checking-text-for-matching-to-grammar)
* [Joining multiple grammars](#joining-multiple-grammars)
* [Compiling to native flow code](#compiling-to-native-flow-code)



## Syntax

A *lingo* grammar consists of productions:

	language = "World, hello" | "World, goodbye";

A production starts with a name ('language'), an equal sign, and then a list of choices separated by
pipes, and end with a semi-colon. This grammar matches the two strings "World, hello" or "World, goodbye".

Each choice itself is a sequence of parsing elements. The following matches the same grammar:

	language = "World," " " "hello" | "World," " " "goodbye";

where each choice is a sequence of three terminals. 

A terminal is the name used for lexical elements in a grammar - i.e. the basic elementary symbols 
or words of the language, such as integers, keywords, identifiers, operator-symbols and similar. 
Conversely, non-terminals are the "grammar" rules, where the rules for how the terminals (words) 
can combine. In addition to terminals and non-terminals, normally white-space is considered a separate
category. White-space is commonly any sequence, potentially empty, of space, tabs, newlines, carriage
returns as well as comments. White-space is parsed, but otherwise thrown away.

As you can see, in *lingo*, lexing and parsing is combined, so when you write *lingo*
grammars, you have to remember to specify where white-space is accepted. In other words, *lingo*
parses both terminal and non-terminals. In other parser-generators, such as Lex/Yacc, normally
you use Lex (flex) to *lex* the strings into terminals, and then Yacc defines the rules for how
to parse the stream of terminals. In *lingo*, these two concerns are handled in the same language,
making it quicker to use, easier to understand and more flexible.

You can reference other productions by name:

	language = world ws "hello" | world ws "goodbye";
	world = "World,";
	ws = " ";

Even though this grammar requires look-ahead to resolve, PEG grammars can parse such 
grammars efficiently, because it can cache partial parsings, and thus backtracking is
efficient.

The choice operator (`|`) is a committed choice operator, so if two choices are ambiguous, 
the first one matching is chosen:

	dangling_else_solved = "if" exp "then" exp "else" exp | "if" exp "then" exp;

This grammar solves the classical *dangling else* ambiguity, and makes the `else`-clause
bind to the innermost `if`.

Besides the sequence of terminals and rules, you can use different operators:

	ws = " "+;                               // One or more spaces
	star = "Hello" ws "cruel"* ws "world";   // Zero, one or more "cruel"s allowed
	optional = "Bye" ws "cruel"? ws "world"; // Zero or one "cruel" allowed
	letter = "a"-"z";                        // Character range, inclusive in both ends
	letter_except_b = !'b' 'a'-'z';          // Negation - does NOT match if the given expression matches

Nested choices are also supported (except with the obsolete interpreter):

	does_not_work = "Hello" (" " | "\n")+ "world";

There are a few legacy places that use the obsolete interpreter. In those cases, move the nested 
choices to the top-most choice level and it will work fine:

	works = "Hello"$h sp+ "world" {$h};
	sp = " " | "\n";

For all normal use, the compiler does this automatically in the background.

## Bindings and actions

To build a structure to represent the outcome of a parsing, you can bind the results of productions
to names, and use actions to build structures. Let's start with a simple grammar for adding 
numbers:

	exp = int "+" exp 
		| int;
	int = digit+;
	digit = '0'-'9';

This grammar is not really useful, since it does not support white-space or other operations, but
it serves the purpose of explaining bindings.

We add bindings using ":" and "$" followed by a name, and then actions in `{}` to construct the results:

	exp = int:e1 "+" exp:e2 { Add(:e1, :e2) } 
		| int:e { :e };
	int = digit+$d { Int(s2i($d)) };
	digit = '0'-'9';

The `$name` syntax binds to the text that matches, while `:name` binds to the result of that production. 
This grammar will produce a structure like 

	Add(Int(1), Add(Int(2), Int(3)))

for a string like "1+2+3", where `Add` and `Int` are flow structures defined like this in a flow file:

	Exp ::= Add, Int;
		Add : (e1 : Exp, e2 : Exp);
		Int : (i : int);

The `s2i` name is a predefined action that converts the string to a number. You can see which predefined actions
exist in `lingo/pegaction.flow`. It is relatively easy to add your own by adding to that default action tree.

Probably you've noticed that this grammar produces a wrong AST: it uses right recursion and as a result
it builds the tree starting from the rightmost operation. So instead of (1+2)+3 we get 1+(2+3). This doesn't
matter much if you use only '+' in your grammar. But it will matter when you use '-': 1-2-3 should be parsed as
(1-2)-3 rather than 1-(2-3). The easiest way to fix this issue is to use semantic actions and it will be explained
a bit further.

Note, a grammar must return a top-level construction. If you fail to do so the parsing will return "PARSING 
FAILED".

When you match varying number of items with ?, + or *, the semantic result is an array. With this in a flow
file:

	Exps(exps : [Exp]);

these semantic actions show how to capture zero, one or more expressions:

	optional = exp?:e { Exps(:e) };
	plus = exp+:e { Exps(:e) };
	star = exp*:e { Exps(:e) };

Unfortunately, you cannot include information about the AST data structures type in the lingo file so you have 
to either include the corresponding file in the flow program or, if you running lingo from command line, into 
`pegcompiler.flow`.

## Position of match in string

As a special action, you can use `#` as a name which will give the index into the parsed string at this point.
The grammar

	a = 'a'+ {#}:s 'b'+ { BRange(:s, #) };

will give the position of where the b's start, as well as where they end.

## Testing a grammar

In this section we are going to change files in flow/lib folder. Make sure not to commit this to the public repo.

The recommended way of testing a lingo grammar:

- put the lingo grammar in a separate file, with a .lingo extension;
- put the AST into a separate flow file in flow/lib folder;
- make a test file with a text to be parsed;
- import the flow file with AST in `lib/lingo/pegcode/pegcompiler.flow` file;
- run pegcompiler.flow passing the lingo and test files into it.

Make a `sandbox/mygrammar.lingo` file with the contents:

	exp = int:e1 "+" exp:e2 { Add(:e1, :e2) }
		| int:e { :e };
	int = digit+$d { Int(s2i($d)) };
	digit = '0'-'9';

Make a `flow/lib/mygrammar.flow` file with the contents:

	Exp ::= Add, Int;
		Add : (e1 : Exp, e2 : Exp);
		Int : (i : int);

Make a `sandbox/testcase.txt` file with a text to be parsed like this:

		11+15

There are no spaces or new lines in this sample.

Add this line to the top of `lingo/pegcode/pegcompiler.flow`:

	import mygrammar;

Run a command:

	flowcpp lib/lingo/pegcode/pegcompiler.flow -- file=sandbox/mygrammar.lingo testfile=sandbox/testcase.txt

This will parse the grammar, check it for errors, and then use it to parse the contents of the `testcase.txt`
file. It will report whether the file parsed or not. If you want to inspect the semantic output of the file,
then add `result=1`:

	flowcpp lib/lingo/pegcode/pegcompiler.flow -- file=sandbox/mygrammar.lingo testfile=sandbox/testcase.txt result=1

The output for the files above would be:

	Running grammar on sandbox/testcase.txt
	PARSE OF TEST SUCCESSFUL
	Time to parse: 0.00010302734375
	Result:
	ParseResult(5, Some(Add(Int(11), Int(15))))

If we want to test the flow grammar itself, add this line to the top of `pegcompiler.flow`:

	import lingo/flow/flowast;

to get all definitions of the flow AST structures defined, and test with this

	flowcpp lingo/pegcode/pegcompiler.flow -- file=tools/flowc/flow.lingo testfile=lib/maybe.flow result=1

and it should dump the AST for the maybe.flow file.

A useful shorthand is to use `test=a=1` instead of `testfile` if you just need to parse a short string:

	flowcpp lingo/pegcode/pegcompiler.flow -- file=tools/flowc/flow.lingo test=a=1 result=1

which prints

	Running grammar on 'a=1'
	Time to parse: 0
	Result:
	ParseResult(3, Some(FaProgram([], [FaVarDecl("a", [], [FaInt(1, 2, 3)], 0, 3)], 0)))

As you can see, the program also prints the number of seconds required to parse the string. Often, this number
is too small to be noticeable. To get more statistical data, you can parse the same string many times using
the `testruns=10` flag:

	flowcpp lingo/pegcode/pegcompiler.flow -- file=tools/flowc/flow.lingo test=a=1 testruns=100

which takes 0.0156 seconds for 100 runs on my machine.

## Debug

To help debugging lingo syntax and constructions the debug() pegaction, which prints the current Flow construct 
to console, helps quite a bit. Changing the example above: 

	exp = int:e1 { debug(:e1) } "+" exp:e2 { debug(Add(:e1, :e2)) } 
		| int:e { :e };
	int = digit+$d { debug(Int(s2i($d))) };
	digit = '0'-'9';

will produce this console output

	Debug
	[Int(1)]	// from the end of the int production
	Debug
	[Int(1)]	// from the start of the exp production
	Debug
	[Int(2)]	// from the end of the int production
	Debug
	[Add(Int(1), Int(2))]	// from the end of the exp production

for the input string "1+2".

## Tracing

Another option to using the `debug()` action is to use tracing. This is done by adding `trace=1` to the invocation
of pegcompiler when testing your grammar:

	flowcpp lingo/pegcode/pegcompiler.flow -- file=tools/flowc/flow.lingo test=a=1 trace=1

The result is something like this:

	Running grammar on 'a=1'
	Debug: ["Unknown var: ws", ""]
	Debug: ["Unknown var: letter", "a"]
	Debug: ["Unknown var: id", "a"]
	Debug: ["Unknown var: ws", ""]
	Debug: ["Unknown var: ws", ""]
	Debug: ["Unknown var: digit", "1"]
	Debug: ["Unknown var: int", "1"]
	Debug: ["Unknown var: number", FaInt(1, 2, 3)]
	Debug: ["Unknown var: ws", ""]
	Debug: ["Unknown var: atom", FaInt(1, 2, 3)]
	Debug: ["Unknown var: call", "1"]
	Debug: ["Unknown var: factor", "1"]
	Debug: ["Unknown var: term", "1"]
	Debug: ["Unknown var: exp6", "1"]
	Debug: ["Unknown var: exp5", "1"]
	Debug: ["Unknown var: exp4", "1"]
	Debug: ["Unknown var: exp3", "1"]
	Debug: ["Unknown var: exp2", "1"]
	Debug: ["Unknown var: exp", "1"]
	Debug: ["Unknown var: lastexp", "1"]
	Debug: ["Unknown var: assign", FaVarDecl("a", [], ["1"], 0, 3)]
	Debug: ["Unknown var: toplevelDeclaration", "a=1"]
	Debug: ["Unknown var: program", FaProgram([], ["a=1"], 0)]
	PARSE OF TEST SUCCESSFUL
	Time to parse: 0.0156240234375

For each successful matched rule, the name of the rule is printed, with the result of the rule after that.
Thus, the first line shows the `ws` rule matched the empty string. The next shows that `letter` matched 
'a'. The third line shows that the "id" rule gave the semantic result "a", and so on.

If we just wanted to focus on a few rules, we could list the names of the rules we are interested in:

	flowcpp lingo/pegcode/pegcompiler.flow -- file=tools/flowc/flow.lingo test=a=1 trace=atom,exp

which results in this:

	Running grammar on 'a=1'
	Debug: ["Unknown var: atom", FaInt(1, 2, 3)]
	Debug: ["Unknown var: exp", FaInt(1, 2, 3)]
	PARSE OF TEST SUCCESSFUL
	Time to parse: 0

## Caching

To speed up parsing, it is possible to enable caching of the parsing of productions. This is useful
to make backtracking efficient. To enable caching, append an exclamation mark right after the production name:

	digit! = '0'-'9';

To find out what parts of the grammar should have caching enabled, there is some cache-hit analysis
code in `pegcode.flow` that should be uncommented. Search for 'Enable cache analysis here:' in that file.

After that, change the `grammar2code.flow` code where it says

	// Enable cache analysis here:
	if (/* true || */ g.productions[i].caching) {

to

	// Enable cache analysis here:
	if (true || g.productions[i].caching) {

to force caching for all productions. Then run your parser on some representative input using pegcompiler
above, and it will report a list of productions that might benefit from caching.

Add `!` to those productions, and uncomment the forced addition of caching for all productions in `grammar2code.flow` 
to verify you did it right. Then get rid of the cache profiling, and be happy. When optimizing, it is always
best to have real timings before and after the optimization on representative inputs to verify that
you are in fact optimizing.

If you are not using the pegcompiler to test, you can also manually call something
like

	grammar = compilePegGrammar2("#include lingo/flow.lingo");
	dumpParseCacheStats(foldTree(grammar.second, [], \k, v, acc -> arrayPush(acc, v)))

to dump the cache stats in your own program.

## Clearing the cache

As an advanced feature, Lingo supports marking places in the grammar when the parsing cache can be safely
cleared using the ~ operator:

	program = exp ("," ws ~exp)*;

In this example, we know that if an expression parsed, there is never a need to backtrack, and thus it
is safe to clear the parsing cache. That is what the ~ operator does. See papers by Mizushima and friends
to learn more: [Cut points in PEG](http://www.romanredz.se/papers/FI2015.pdf). We do not have any
automated analysis to find cutpoints, but we do support up-cuts and down-cuts with the semantics of
clearing the cache. There is no choice-cut optimization implemented for these operators yet, but since
we optimize the pegcode, there is probably little gain to be had from this.

## Instruction level rule profiling

Normally, you get acceptable performance from adding the correct caching as noticed above, but sometimes,
you really need to optimize a grammar to the max. In that situation, it is useful to do a very detailed 
profiling of the grammar. This is possible by searching for 

	// Enable rule profiling here

in `pegcode.flow` and change two places to enable rule profiling. Then test your grammar with pegcompiler 
as described above, and you will get a detailed analysis of what productions are used and how frequent, 
including how many times each individual pegcode instruction is run to parse your test case. This data allows 
you to see what choices to reorder to move the most common taken routes to the top, notice any parsing errors, 
and otherwise allow fine-tuning of the grammar.

## Common problems

Unfortunately, our parser is not clever enough to find certain, common problems. Grammars
like the following will seemingly compile just fine, but when you try to use them, they will 
not work.

Unreachable choices:

	unreachable_choice = "a" | "a" "b";

Since the choice operator matches the first successful choice, the second choice is never
matched.

Direct left recursion will not work:

	string_of_a = string_of_a 'a' | 'a';

Most often, that can be expressed more clearly with a plus operator anyways:

	string_of_a = 'a'+;

Indirect left recursion:

	exp = product | sum | int;
	sum = exp '+' exp | exp '-' exp;
	product = exp '*' exp | exp '/' exp;
	int = digit+;
	digit = '0'-'9';

This will not parse. You have to restructure the grammar not to have any indirect left-recursion:

	exp = product '+' exp | product '-' exp | product;
	product = int '*' product | int '/' product | int;
	int = digit+;
	digit = '0'-'9';

## Basic way of using a grammar in a flow program

Normally using the pegcompiler directly to compile and test your grammar is the best way to develop it,
but sometimes, you want to use special semantic actions or integrate the grammar in an interactive
program. In this case, *flow* code like the following will work to prepare and run the grammar:

	import lingo/pegcode/driver;

	// Singleton keeping the compiled grammar
	lingoGrammarOp : ref Maybe<[PegOp]> = ref None();

	lingoGrammar() {
		// Prepare the grammar in the given file using flow syntax for inlining a string from a file
		// but be sure to only do this once
		onlyOnce(lingoGrammarOp, \ -> {
			compilePegGrammar("#include lingo/lingo.lingo");
		});
	}

	main() {
		// Here we parse a string against the grammar
		result = parsic(lingoGrammar(), "Hello world", defaultPegActions);
	}

`result` will contain the result of the action of the first production in the grammar. 

In production code where less console output is wanted `parsic3` can be used. It prepares a nice
error message on parse failures, as well as a default value on errors.

Once the grammar works, then you want to precompile the grammar for efficiency and use that in production. 
See the next section to learn how to do that.

## Using custom semantic actions

Now let's consider the example with a sum of integers and see how we can build a correct tree. Let's use
subtraction to see why the order really matters. Here is the grammar:

	exp = int:e1 "-" exp:e2 { Sub(:e1, :e2) } 
		| int:e { :e };
	int = digit+$d { Int(s2i($d)) };
	digit = '0'-'9';

And flow structures:

	Expr ::= Int, Sub;
	Int(value : int);
	Sub(l : Expr, r : Expr);

It uses right-recursion and folds the expression starting with the rightmost operation. Let's review parsing
step by step for string "1-2-3". We expect to get `exp` in the input. The first rule starts with an `int`, so we
grab all digits ("1"), convert them to Int(1) and put it on stack:

	1-2-3
	 ^
	Stack: Int(1)

The next expected terminal is "-" and we find it in the input string, so we continue with the first rule:

	1-2-3
	  ^
	Stack: Int(1)

Repeat the same once again, so we get "1-2-" parsed and have Int(1) and Int(2) on stack:

	1-2-3
	    ^
	Stack: Int(1), Int(2)

We try to parse the rest of the string (which is "3") by matching to the first rule of `exp`. We successfully
parse "3", put Int(3) on stack, but fail to find '-', so we forget all work in the current step and switch to
the second rule of `exp`.

	1-2-3
	    ^
	Stack: Int(1), Int(2)

In second rule we again parse "3" and put Int(3) on stack

	1-2-3
	     ^
	Stack: Int(1), Int(2), Int(3)

We reach the end of input and do not expect anything else, so we fold our results:
	
	AST: Empty
	Stack: Int(1), Int(2), Int(3)

We apply the second rule of `exp`:

	AST: Int(3)
	Stack: Int(1), Int(2)

Then the first rule:

	AST: Sub(Int(2), Int(3))
	Stack: Int(1)

And once again:

	AST: Sub(Int(1), Sub(Int(2), Int(3)))
	Stack:

So we get Sub(Int(1), Sub(Int(2), Int(3))) which corresponds to 1-(2-3).

Instead of parsing each term separately we can grab all of them at once and then build the tree in the correct
order using a special semantic action `buildSub` (we'll define it later):

	exp = int:i sub*:is {buildSub(:i, :is)};
	sub = '-' int:t { :t };
	int = digit+$d { Int(s2i($d)) };
	digit = '0'-'9';

Let's see how it will parse the same input. The first integer is parsed in the same way:

	1-2-3
	 ^
	Stack: Int(1)

Now we expect any number of `sub`. The parser is greedy so it will take as much of them as it can. Please
notice that we use `sub*`, not just `sub`, so we get an array of `Int`s.

	1-2-3
	   ^
	Stack: Int(1), [Int(2)]

	1-2-3
	     ^
	Stack: Int(1), [Int(2), Int(3)]

We reach the end of input, but we do not expect anything else. So we fold the results and get 
buildSub([Int(1), [Int(2), Int(3)]])

Now we need to define `buildSub` in our code. We have a list of arguments: the first one is the leftmost
integer (which corresponds to `int` in `exp` rule), the second one is the array of all other integers
(which corresponds to `sub*` in the `exp` rule), so we can just fold them this way:

	buildSub(xs : [flow]) {
		fold(xs[1], xs[0], \acc, x -> Sub(acc, x))
	}

This function will produce Sub(Sub(Int(1), Int(2)), Int(3)) for the given example which can be evaluated as
(1-2)-3. Now all we need is to pass this semantic action to the parser:

	specialPegActions = {
		t = setTree(defaultPegActions.t, "buildSub", buildSub);
		SemanticActions(t);
	}
	parsic(lingoGrammar(), s, specialPegActions);

## Precompiling a grammar for efficiency

Instead of compiling the grammar at runtime with code like the above, it is more efficient to precompile 
the grammar to pegcodes and then just use the opcodes at runtime.

This is done like this:

	flowcpp lingo/pegcode/pegcompiler.flow -- file=path/to/grammar.lingo out=path/to/grammar_pegop.flow

which will produce a `grammar_pegop.flow` file which defines a global variable named after the file. In this instance, 
`pegop4Grammar`. In general, the name of the variable will be <code>pegop4&lt;*name-of-grammar-file*></code>. 
On Windows be careful to use forward dashes in the path in the file parameter. The variable will contain 
the compiled grammar. To use it, also construct a driver using a `flowfile=path/to/grammar_parse.flow` parameter,
and you will get a suitable .flow file that defines a parsing function for you.

You can also set the result-type of the grammar using `parsetype=MyAst` switch to make the parsing function
more typesafe. An example driver as produced could look like this:

	// Generated by
	//   flowcpp lingo/pegcode/pegcompiler.flow -- file=lib/formats/mouse/mouse.lingo out=lib/formats/mouse/mouse_pegop.flow flowfile=lib/formats/mouse/mouse_parse.flow parsetype=MGrammar

	import lingo/pegcode/driver;
	import lib/formats/mouse/mouse_pegop;
	import lib/formats/mouse/mouse_ast;

	export {
		// Parses a string in Mouse format. Returns 'def' on failure.
		// The second int is how far we parsed, and the string is an error message on failure.
		parseMouse(text : string, def : MGrammar) -> Triple<MGrammar, int, string>;
	}

	parseMouse(text : string, def : MGrammar) -> Triple<MGrammar, int, string> {
		parsic3(pegOps4Mouse, text, defaultPegActions, def);
	}

The command line listed in the comment thus produced both the `mouse_pegop.flow` and `mouse_parser` file, 
and by convention included a `mouse_ast` import to get the AST struct node definitions.

This way, the grammar is compiled into optimized pegcodes, and the startup is much faster, since
there is no parsing of the grammar required. This is the best way to use Lingo in production.

If you do this, obviously, you have to regenerate the `*_pegop.flow`  file when the grammar changes, just like 
when you use Yacc or Bison.

If you need to have debugging info for the grammar, you can add `debug=1` to the pegcompiler, and it will also
define a pegop4GrammarDebug variable. This is rarely needed.

## How to handle white-space

You must pick a consistent policy for white-space (ws), so you do not have 
more than one white-space rule in a row (for efficiency), but more importantly: 
so that you can be sure there is no string that will be unparseable because it
has a whitespace too much. The latter is really hard to debug.

The best policy is to add "ws" at the start of the top-level grammar, and
then after each token or terminal rule. Then you have the invariant that
every non-terminal rule supports and parses trailing ws.

As an example, here is a grammar for very simple expressions with integers, 
ids & addition:

	// The very first rule should have ws at the start to take leading ws
	program = ws exp;

	// There are rules that all directly or indirect eat trailing white-space
	// so we only have to handle ws after the token "+". exp1 and exp 
	// recursively ensure that all "exp" handle trailing ws.
	exp = exp1 "+" ws exp
		| exp1;

	// When we reference token rules like int and id, we have to handle
	// following ws our selves
	exp1 = int ws | id ws;

	// These are all tokens, and do not eat whitespace.
	// When referencing these, you have to add "ws" at the end to handle
	// ws after these rules.
	int = digit+;
	id = letter+;
	digit = '0'-'9';
	letter = 'a' - 'z' | 'A' - 'Z';

	// The rules for white-space
	ws = s*;
	s = " " | "\t" | "\n";

The key insight is to know for each rule whether it eats trailing whitespace 
or not. Strive to make your rules always eat whitespace, and then you only
need to add whitespace after strings, i.e. tokens, also knows as non-terminals.

Conventionally, the token-productions for terminals are placed at the end of the
grammar, and typically have names such as id, int, and similar.

As you can see, we naturally divide the grammar into token-like productions and 
normal rules. Then normal rules always eat white-space directly or indirectly, 
while the token-like never eat ws.

This pattern will parse correctly, is easy to follow and will be efficient in that 
white-space is always only parsed once.

A common mistake is to add too many "ws" references:

	program = ws exp ws;

	exp = "break" ws;

In this example, it is wrong to have a "ws" after the "exp" reference in the 
"program" rule. This is wrong, since "exp" handles "ws" itself, so there is
no need for references to this rule to also do it.

The reason is that it causes unnecessary unambiguity, since effectively, the result 
corresponds to a rule like this:

	program = ws "break" ws ws;

Notice the double "ws" at the end. If we expand "ws" itself, we get:

	program = s* "break" s* s*;

Now, it is clear that there are many ways to parse multiple spaces: If we have 
100 spaces after the "break" keyword, there would be 100 different ways
to parse that white-space depending on how many the last s* handles. Normally, 
this does not happen, since *Lingo* is eager and deterministic, but in case of 
parse errors, the engine will backtrack and could run into exponential slowdowns 
because of an error like this.


## Checking text for matching to grammar

If you just want to check if some text is matching to grammar you can use 
`matchLingo(grammar : string, text : string) -> bool` from `lingo/match.flow`.

	matchLingo("#include my.lingo", "r5")
	matchLingo("digit = ('0'-'9')$s {$s};", "1")

## Joining multiple grammars
When you use the pegcompiler to compile Lingo grammars, it is possible to provide multiple `.lingo` files to 
join together into one grammar.

Consider this example:

In file a.lingo, we have:

	number = int;
	int = digit+;
	digit = '0'-'9';

In file b.lingo, we have:

	number = double | number;
	double = int "." int;

Then we can combine these grammars into one using

	flowcpp lingo/pegcode/pegcompiler.flow -- file=a.lingo,b.lingo out=combined_pegop.flow

and it would be the same as if I had this grammar:

	number = double | number;
	double = int "." int;
	int = digit+;
	digit = '0'-'9';

in one file. This is useful when you want to make hybrid languages. As an example, see Datawarp, which combines
SQL and Flow syntax.

In terms of the corresponding mixed AST that will result, a useful practice is to introduce a "Foreign" AST node
that allows foreign grammars to introduce their own constructs into the AST:

	Ast ::= Add, Divide, Integer, Foreign;
	Foreign(payload : ?, children : [Ast]);

See the flow AST for an example.

## Compiling to native flow code

When the ultimate parsing speed is required, you can compile a Lingo grammar to a flow program, 
which parses the grammar efficiently.

	flowcpp lingo/pegcode/pegcompiler.flow -- file=tools/flowc/flow.lingo flowparser=path/flow_parser.flow

This will produce a parser for the flow grammar in the `flow_parser.flow` file. That file will
expose exactly one function:

	export {
		parse_flow(t : string) -> SyntaxTree;
	}

This function takes a string, parses it, and returns a `SyntaxTree`. `SyntaxTree` is defined like this:

	SyntaxTree(rule : string, choice : int, start : int, end : int, children : [[SyntaxTree]]);

As you can see, for each rule, we will record what rule was matched, what choice in that rule was used,
what was the starting and ending characters positions for the match, as well as the results of any
recursive rules matched in our rule.

This compiler will thus ignore all bindings and actions of your grammar, and always produce
a SyntaxTree-based AST.

If there is a compile error, the "choice" field will be -1, and the "rule" string will contain a
error message. You can use the `start` and `end` positions to find out where the parse error is.

To make it easier to work with the SyntaxTree structure, you can use the `flowparserast=flow_ast.flow`
switch:

	flowcpp lingo/pegcode/pegcompiler.flow -- file=tools/flowc/flow.lingo flowparser=path/flow_parser.flow
				flowparserast=flow_ast.flow

and now the compiler will also produce a file with a long list of functions, which help extract the
results of each match. 

To extract the matching text of a SyntaxTree node, you can use `grabSTText` from 
`lingo/compiler/syntaxtree_util`. You give it a SyntaxTree node, the original text that was
passed to `parse_flow`, and you get the matching text out.

The parsers produced by this approach are up to 10 times faster than the pegcode-based compilers,
but the downside is that the AST is untyped, and you have to manually convert that to a suitable
typed AST using the AST functions and `grabSTText`.

Before you use this approach, be sure to profile and optimize your grammar using the normal 
pegcode-based parser and the instructions above. All optimizations done with that will carry
directly over to the flow-based parser.
