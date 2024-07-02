# Poppy

Mango defines the syntax for parsing languages and includes basic operations for constructing the AST. However, it is not able to do more complex AST manipulations, such as parsing strings into doubles, constructing arrays of values, expanding syntactic sugar and similar tasks. For these purposes, we need a different language that operates on the stack of results constructed by Mango.

Since Mango already uses a stack, it makes sense to use a stack-based language to manipulate the AST. This is the purpose of Poppy, a stack-based language that operates on the AST constructed by Mango. Poppy is designed to be easy to parse and to work with the AST, and it is a good tool for working with grammars and ASTs. It is inspired by Joy, an existing functional stack language.

In my youth, I owned an HP28s calculator and often wrote small, entertaining programs during boring moments in classes for my friends. This calculator was stack-based and utilized Reverse Polish Notation (RPN), and it taught me the succinct nature of stack languages. In stack languages, operations are executed directly on a stack of elements, eliminating the need for operator precedence rules or parentheses.

Inspired by the simplicity and direct data manipulation offered by the HP28s, and drawing from the principles of Joy, Poppy is crafted to embrace these qualities. It aims to leverage the succinctness and clarity of stack-based computation to facilitate seamless AST construction and manipulation.

Poppy is easy to parse with Mango as it is. That makes Poppy a nice tool for working with grammars and ASTs, and it will play a helpful role in subsequent chapters. By integrating Poppy's syntax within Mango, we create a hybrid language that combines Mango's parsing strengths with Poppy's stack manipulation capabilities. This synergy allows for an intuitive and direct approach to defining semantic actions, enhancing our ability to efficiently process and transform parsed data.

TODO: We have manually added PoppyConstructor so do we not run types=2
@run<flowcpp --batch mango/mango.flow -- grammar=poppy/poppy.mango savegrammar=poppy/poppy_grammar.flow typeprefix=Poppy>

@run<flowcpp --batch mango/mango.flow -- grammar=poppy/type/ptype.mango savegrammar=poppy/type/ptype_grammar.flow savereduced=poppy/type/ptype_reduced.mango>


@run<flowcpp poppy/poppy.flow -- file=poppy/tests/test.poppy>

## Syntax

A Poppy program is composed of a series of instructions called *words* that are executed in sequence from left to right. Each instruction manipulates the stack or controls the flow of the program in some way. Instructions in Poppy can take various forms, including words, control flow constructs (`ifte`, `while`), quotations, definitions, and values (bools, double, integer, string, constructors). Here is the grammar:

``` tools/poppy/poppy.mango
poppy = poppy (poppy Sequence/2)*
	|> switch_grammar
	| command kwsep 
	| "define" kwsep word poppy ";" ws Define/2
	| "->" ws word Set/1
	| uid "/" ws $int ws @s2i ConstructArity/2
	| "[" ws poppy "]" ws MakeList/1
	| value
	| word Word/1;

command = 
	"nil" Nil/0 | "cons" Cons/0
	| "swap" Swap/0 | "drop" Drop/0 | "dup" Dup/0
	| "eval" Eval/0 | "print" Print/0 | "dump" Dump/0
	| "ifte" Ifte/0 | "while" While/0 | "nop" Nop/0
	;

value = 
	"true" kwsep @true Bool/1 
	| "false" kwsep @false Bool/1
	| $double ws @s2d Double/1 
	| $int ws @s2i Int/1 
	| string @unescape String/1
	;

word = 
	$(
		!(';' | '(' | ')' | '[' | ']' | '"' | '0'-'9' | "->" | "//" | "/*") '!'-'0xffff' 
		(!(';' | '(' | ')' | '[' | ']' | '"') '!'-'0xffff')*
	) ws
	;
```

Notice that words allow a wide range of characters, which enables arithmetic to use natural syntax like `1 2 +` where `+` is considered a word for addition.

### Key Operations

- **nil**: Pushes an empty list onto the stack.

- **cons**: Takes two elements from the stack, a value and a list, and pushes a new list onto the stack with the value added to the front of the original list.

- **true/false**: Push boolean values onto the stack.

- **swap**: Swaps the top two elements on the stack

- **drop**: Removes the top element from the stack.

- **dup**: Duplicates the top element on the stack, pushing a copy onto the stack.

- **print**: Outputs the top element of the stack to the standard output. This command is useful for debugging and displaying results.

- **dump**: Outputs the entire content of the stack to the standard output, providing a view of the stack's state. This command is invaluable for debugging and understanding the stack's state at any point in the program's execution.

In addition, we expose all core operations from the value library with their natural names. The following are especially helpful for parsing:

- **s2i**: Converts the top string element on the stack to an integer.

- **s2d**: Converts the top string element on the stack to a double-precision floating-point number.

- **parsehex**: Parses the top string element on the stack as a hexadecimal number and pushes the corresponding integer value.

- **unescape**: Processes the top string element on the stack, converting escape sequences into their represented characters.

## Constructors

Use this syntax to construct structs in Poppy of a given arity:

``` tools/poppy
42 Some/1 			// Some(42)
42 true Pair/2		// Pair(52, true)
```

## Definitions

The `define <word> = <code>;` syntax is used to define names in Poppy:

``` tools/poppy
define pi = 3.14159 ; 
define tau = pi 2.0 * ; tau		// --> 6.28318
```

The way this works is that we bind the commands as they are in the definition to the name in the environment. We say that the code has been quoted. When the name is referenced, we lookup what the code is and evaluate it.

Step by step, the way this works is the definition `define pi = 3.14159 ;` is parsed and the code `3.14159` is quoted and bound to the name `pi` in the environment. Next, we define `tau` as `define tau = pi 2.0 * ;`. The code `pi 2.0 *` is quoted and bound to the name `tau` in the environment. Notice we do not evaluate `pi` at this point.

Now, when we reference `tau`, we lookup the code `pi 2.0 *` as a sequence of commands. Next, we evaluate this code in steps. First, we lookup `pi` and evaluate it to get the result `3.14159`. Then we push `2.0` to the stack. Finally, we evaluate `*` and the result is `6.28318`.

## Updating values

Values can be updated using `-><id>` syntax:

``` tools/poppy
3.14 ->pi
3.141569 ->pi
pi	// --> 3.141569
```

## Control flow

This is how we express an if-conditional using the `ifte` word:

``` tools/poppy
true [41 1 + ] [12]  ifte 	// --> 42
```

The `ifte` word takes three arguments from the stack: a boolean value, a *quotation* for the true branch, and a quotation for the false branch. If the boolean value is true, the true branch is evaluated; otherwise, the false branch is evaluated.

This program prints the values 1 to 10 using `while`:

``` tools/poppy
1 [dup 10 <] [dup print 1 + ] while
```

It works by first pushing `1` onto the stack. Then, it enters the `while` loop. The `while` loop first checks if the top of the stack is less than `10`. If it is, it executes the code inside the loop. The code inside the loop duplicates the top of the stack, prints it, adds `1` to it, and then the loop repeats. This continues until the top of the stack is no longer less than `10`.

This is the structure of these words where code in `[<code>]` are quotations:

``` tools/poppy
<cond> [<then<>] [<else>] ifte
[<cond>] [<body>] while
```

## Higher-order Programming & Control Flow

The `[ code ]` syntax is a general quotation mechanism. Similar to Joy, we can use this to delay evaluation:

``` tools/poppy
[42 12 + ] eval    // --> 54
```

The quoting mechanism allows for the construction of code as data, delaying execution until explicitly invoked by `eval`. This feature enables higher-order programming, where code can be used as building blocks for other operators. It also allows constructing code using code, thus enabling meta-programming.

## Using Poppy in Mango

### Integrating Poppy with Mango for Enhanced Stack Manipulation

Poppy can be embedded within Mango using the `@word` syntax to encapsulate Poppy operations. 

- **Creating an Empty List**

```mango
@nil
```

This valid Mango program uses a Poppy operation `@nil` to push an empty list onto the stack.

- **Appending an Element to a List**

```mango
id = ...;
@nil $id @cons
```

This Mango program defines a rule for an identifier, such as `foo`. Then it pushes an empty list `[]` onto the stack. We parse the identifier and pushes `"foo"` onto the stack. The `@cons` operation then appends `"foo"` to the empty list, resulting in `["foo"]` on the stack.

For capturing lists of items, such as a list of identifiers, we can do this:

```mango
@nil (id @cons)* Ids/1
```

This results in `Ids([])` for no identifiers, or `Ids([a,b,c])` for a sequence of identifiers.

- **Type Conversions**

Converting strings to integers or doubles is streamlined with explicit Poppy calls:

```mango
$('0'-'9'+) @s2i
```

This parses an integer from a string, converting `"123"` to `123` on the stack. Similarly, for double-precision numbers:

```mango
$('0'-'9'+ '.' '0'-'9'*) @s2d
```

Converts a string representation of a floating-point number to its numeric double equivalent.

Converting hexadecimal strings to integers and unescaping characters in strings are handled with `parsehex`:

```mango
$"0xdeadbeef" @parsehex
$"Poppy \\u1F33A\\n" @unescape // Poppy 🌺
```

#### Advanced Stack Manipulation

Beyond basic list handling and type conversions, Poppy enriches Mango with a suite of stack manipulation operations:

- **Swapping Elements**

```mango
@true @false @swap
```

This sequence swaps the top two elements on the stack, illustrating the direct manipulation capability brought by Poppy.

### Using Poppy words to implement logic in Mango

In general, you can define words in Poppy using `@'<poppy code>'` syntax. In this example, we set up a counter, which can be incremented each time we invoke the `@line` word from the grammar:

```mango
// Use Poppy syntax embedded in Mango to define a counter and a word to increment it
@'
// Set the counter to 0
0 ->counter

// Increment the counter each time we invoke it
define newline
	counter 1 + dup ->counter;
'

// Define a simple grammar for a line ending with a newline:
line = $(!'\n'* '\n');

// Now define a grammar which parses each line, and includes the current 
// line number in the Line constructor
(line @newline Line/2)* Lines/1
```

- **Debugging and Output**

For debugging purposes, printing the stack's contents or dumping its entire content is straightforward:

```mango
@print
@dump
```

## Interpreting Poppy

Poppy is a stack-based language, and its operations are executed directly on the stack. The stack is a linear data structure that follows the Last-In-First-Out (LIFO) principle. This means that the last element pushed onto the stack is the first to be popped off. We represent this in the environment as a `List`:

``` tools/poppy/poppy_env.flow
	PoppyEnv(
		stack : List<PoppyStackValue<?>>,
		words : Tree<string, Poppy>,
		runCore : RunCore,
	);
```

Notice that values are extended with `PoppyArray` to represent arrays and `ExtValue` to keep external data:
``` melon
	PoppyStackValue<?> ::= Poppy, PoppyArray(value : [PoppyStackValue<?>]), ExtValue(value : ?);
```

The evaluator is very simple:

``` melon
evalPoppy(env : PoppyEnv<?>, ins : Poppy) -> PoppyEnv<?> {
	push = \v : PoppyStackValue<?> -> PoppyEnv(env with result = Cons(v, env.result));
	popn = \n : int -> popNStack(env.result, n);
	switch (ins : Poppy) {
		PoppySequence(poppy1, poppy2): evalPoppy(evalPoppy(env, poppy1), poppy2);
		PoppyBool(bool1): push(ins);
		PoppyInt(int1): push(ins);
		PoppyDouble(double1): push(ins);
		PoppyString(string1): push(ins);
		...
		PoppyNil(): push(PoppyArray([]));
		PoppyCons(): {
			elms = popn(2);
			a = getPoppyArray(elms.second[0]);
			res = PoppyArray(arrayPush(a, elms.second[1]));
			PoppyEnv(env with result = Cons(res, elms.first));
		}
		...
	}
}
```

We use the *runcore* library to implement all the basic operations.

## Concatenative languages

### Concatenative Languages and the Power of Function Composition

Concatenative programming languages, such as Forth, Joy, and Poppy, are characterized by their unique approach to function composition and application. The core principle of these languages is that the composition of functions, or more generally, operations, is achieved through concatenation.

#### Associativity of Concatenation

A fundamental property of concatenative languages is that function composition is associative. This means that when you concatenate operations or functions together, the order in which these compositions are grouped does not change the outcome. For example, given three functions *f*, *g*, and *h*, the result of composing *f* with *g* and then with *h* is the same as composing *f* with the result of composing *g* with *h*. In mathematical terms, this can be expressed as *(f ∘ g) ∘ h = f ∘ (g ∘ h)*, where (∘) denotes composition.

This associativity is a direct consequence of the concatenative nature of these languages. Since the composition of operations is achieved by laying them end to end, the execution flow is inherently linear and sequential, making the composition naturally associative.

#### Implications for Parallel Compilation

The associativity of function composition in concatenative languages implies that they can be compiled from high-level instructions into assembly or machine code in parallel. Since the order of function composition does not affect the outcome, individual instructions or operations can be translated into their assembly counterparts in parallel. This parallel translation process significantly enhances the efficiency of compiling concatenative languages.

Once each high-level operation is translated into its corresponding assembly snippet, the final compiled program can be obtained simply by concatenating these assembly snippets together. This process is streamlined and efficient because there's no need to reanalyze or reorganize the assembly code once it's generated; the sequential nature of the source language ensures that the concatenated assembly code will faithfully represent the original program's logic and structure.

## SPECULATION: Compiling Mango to Poppy

We have to have the environment on the stack. We will bind names using Poppy, and the result stack will be below the current stack position.

``` melon
Env(
	// The text string we are parsing
	input : string,
	// The current parsing position in the input
	i : int,
	// Did parsing fail?
	fail : bool
)
```

To make it easier to write the code, we can compile a subset of Melon to Poppy.

``` tools/poppy
define String(text) = 
	@melon(
		if (strContainsAt(env.input, env.i, text)) {
			ni = env.i + strlen(text);
			Env(env with i = ni)
		} else {
			Env(env with fail = true)
		}
	)
	// becomes this popy:
	[env.i text strlen + env set.env.i]
	[env set.env.fail = true]
	env.input env.i text strContainsAt
	ifte
;

```

I.e. we need to allow some Melon syntax, and lower that to poppy.

``` blueprint
	@melon(call(arg0, arg1, arg2)) -> @poppy(arg0 arg1 arg2 call)
	@melon(if (cond) t else e) -> @poppy([t] [e] cond ifte)
```

TODO: Compile structs & unions to Poppy functions

We also have to translate struct definitions to functions for fields:

	Foo(a : int, b : string);
->
define foo.a (Foo -> int) = 0 getField;
define foo.b (Foo -> string) = 1 getField;
define set.foo.a (Foo int -> Foo) = 0 swap setField;
define set.foo.b (Foo string -> Foo) = 1 swap setField;

// 42 Some/1 0 41 setField print  => Some(1)
