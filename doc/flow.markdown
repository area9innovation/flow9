*flow*
======

*flow* is a statically typed functional language for building software with
dynamic user interfaces. It has taken elements primarily from ML & haXe.
It is a relatively small and simple language, although it does have first-order
functions, polymorphism, closures and simple pattern matching.

* [Design goals](#goals)
* [Modules, imports, exports, and main](#modules)
* [Declarations](#decls)
* [Simple types and values](#types)
* [Arrays](#arrays)
* [Maybe](#maybe)
* [References](#refs)
* [Functions and lambdas](#funcs)
* [Function call: pipe-forward](#pipe)
* [Sequence](#sequence)
* [Structs](#structs)
* [Unions](#unions)
* [switch](#switch)
* [Mutable fields](#mutable)
* [Casts](#casts)
* [Special types `flow` and `native`](#special)
* [Parameterized types](#parameterized)
* [Impure functions](#impure)
* [Native functions](#native)
* [Quoting and unquoting](#quoting)
* [Coding conventions](#coding)
* [Data structures](#data)
* [Loops](#loops)
* [Structs of functions](#structsoffunctions)
* [Language finesses](#languagefinesses)
* [flow vs. JavaScript](#javascript)

<h2 id=goals>Design goals</h2>

The main design goals of *flow* are:

 - Support easy construction of complex user interfaces
 - Allow programmers to use a normal text editor and compiler work flow
 - The language should be easy to implement on multiple platforms, including desktop, 
   iPhone, Android and HTML5. This implies that the runtime needs to be small, because 
   we can not reuse the same implementation on all these targets.
   
Although *flow* can be utilized to build server-side functionality, it is primarily used for 
building complicated UIs. That is the field where it starts shining and shows its real power. 
Worth keeping in mind when working with it.

The main flow compiler is implemented in flow itself. The compiler produces a simple bytecode, 
native JavaScript, Java and other targets. See the [runtimes.markdown](runtimes.markdown) document for 
an overview of the targets.

<h2 id=modules>Modules, imports, exports, and main</h2>

A *flow* program consists of modules. A module `example` is defined by a file named
`example.flow`.  (It is intentional that you do not to have to write the name of the
module inside the file itself. Therefore, you can only use a restricted set of
filenames for your flow files. Also be aware that all filenames are case sensitive,
because the result needs to run on Unix systems. The convention is to use lower-case
only filenames.)

Each module (file) can import any number of modules as dependencies. This is done
with

	import module1;
	import module2;

lines at the top of the file. The `import` directive supports Unix-path syntax, with 
the restriction that all path components have to be valid ids.

	import formdesigner/types/generator;

If there is no path given in the import, it will look in the `lib/` directory of the
flow installation, as well as the current directory of the compiler when invoked and
any include paths given. You have to use the full path to import files from other places, 
even if the file you are importing is a file in the same folder as the current file.
Effectively, the includes combine into one global, combined path name-space.

Each module exports a set of names. These are declared with an `export` block:

	export {
		foo : int;
		bar(i : int, s : string) -> void;
		FooBar();
	}

The intent is that you are only allowed to reference exported names in other modules.
(Even though you do not export a name, that name is currently still inserted into a
global scope and can cause name conflicts. This might change in the future.)

Execution starts by calling `main` in the main module compiled. Example command line for
the C++ runner that compiles and then calls `main` in the `helloworld` module:

	flowcpp sandbox/hello.flow

Run from the root of your flow installation, such as `c:\flow9\` on Windows.

See `windows.markdown`, `mac.markdown`, `linux.markdown` to learn how to use other targets.


<h2 id=decls>Declarations</h2>

Following the import statements, a flow file consists of one or more declarations.
Declarations are either variable declarations, function declarations, type declarations,
or native function declarations in arbitrary order. Grammar:

    top-level ::= decl {decl}

	decl ::= variable-decl | function-decl | type-decl | native-decl

	variable-decl ::= id "=" exp ";"
	function-decl ::= id "(" id {"," id}) exp ";"
	type-decl ::= id ":" type;
	native-decl ::= "native" id ":" "(" type {"," type} ")" "->" type "=" id {"." id} ";"

In other words, _variables_ are declared like this:

	a = 1;

_Functions_ are declared like this:

	fac(n) { if (n <= 1) 1 else n * fac(n-1); }

Notice you can leave out the semicolon if you end with a brace.

_Type declarations_ for functions (and variables) can be declared separately, like in Haskell:

    // Haskell style, not as common
	fac : (int) -> int;

For documentation reasons, it is possible to include optional names of the parameters
in a _type declaration_:

	fac : (n : int) -> int;
	// A function that gets the mouse coordinates and a bool
	mouseEvent(x : double, y : double, mouseInside : bool) -> flow;

The special type `flow` is similar to `Object` in Java, `Dynamic` in haXe. It is boxed at
runtime, and dynamically typed. This is rarely used.

Similarly, the types of variables can be declared, here with a host of different
types to give a taste of the type syntax:

	a : int;

	// Declaring an array uses [type] syntax
	intArray : [int];

	// References use ref type syntax
	referenceToInt : ref int;

	/* Structs in flow are special in that they always need a name. */
	Text(text : string, style : [[string]]);

Notice that these declarations have the name as the first thing in the syntax.
This is intentional in order to make it easy to read the names defined by a module
at a glance. Conventionally, the type declarations are put at the top of the files.

Native functions are discussed later, but first, let's introduce the types and values in flow.


<h2 id=types>Simple types and values</h2>

The simple type syntaxes supported along with use are listed here:

	b : bool;
	b = true || false;

	i : int;
	i = 1 + 0xdeadbeef;

	d : double;
	d = 2.0 - 3.0;

	s : string;
	s = "My string\n";

Names are a sequence of letters, numbers and _, not starting with a number. Variables
conventionally start with small letters.
`int`s are digits, or hexadecimal digits with an `0x` prefix. `double`s are digits
with a single `.` along them. (Currently, we do not support exponents in
double syntax.)

Ints are 32-bit. Comparisons and multiplicative operations on ints are signed.
Doubles are 64-bit. Strings are UTF-16 encoded (i.e. 16 bit).

Strings support \n, \t, \\ and \" escaping, as well as \xHH and \uHHHH where
the HH are hexadecimal digits. Notice that it does not support \r out of the box,
because those are problematic, and we try to avoid those. If we added this escape, 
people might forget that we want to avoid them. (You can get it with \x0d).

It is possible to define long strings in external files:

	string_constant = "#include path/to/file.txt";

Such constants are inlined at compile time.

<h2 id=arrays>Arrays</h2>

Arrays are immutable, and the syntax for declaring types and values is shown:

	a : [int] = [1, 2, 3, 4];

	aa : [[int]] = [[1], [2,3], [4,5,6]];

	ab = [1, 2, 3]; // Type is inferred

	// ac_error = [1, 2.0]; // Type error! All elements in an array must be compatible
	ad : [flow] = [flow(1), 2.0]; // OK: The type annotation makes it work to be dynamic
	ae = [flow(1), 2.0]; // OK in expressions: Type inference will make this [flow]

Array indexing is constant time, and the index is zero-based, and does bounds checking at runtime:

	a = [0,1,2,3,4];

	zero = a[0];	// Array indexing is 0-based
	one = a[1];

	crash = a[1000];	// This will crash at runtime. Don't do this.

The runtime defines some pure functions to work with arrays, all of which produce new arrays
when applicable. See `array.flow`.

Concatenation of two arrays:

	concat : ([?], [?]) -> [?];

	big = concat([1,2],[3,4]);
	assert(big == [1,2,3,4], "Error: Big is not big");

The `[?]` type means that `length` works on any kind of array. I.e. that the function is polymorphic,
somewhat similar to templates in C++ and other languages. See the section on parameterized types
below.

Getting the length of an array:

	length : ([?]) -> int;

	assert(length(big) == 4, "Error: 2 + 2 != 4");

In flow, there is no `for` or `while` statement, so `map` and `mapi` are used for iteration
that produce results, or just `iter` and `iteri` for computations without results.
As you know it from functional programming, `map` applies a function to each element of an
array to give a new array with the results:

	map : ([?], (?)->??) -> [??];

	bigger = map(big, \i -> i*i);
	assert(bigger == [1,4,9,16], "Error: big is not bigger");

Often you need the iteration number, and in these cases `mapi` is your friend.
`mapi` applies a function which takes an index and each element of an array to give a
new array:

	mapi : ([?], (int, ?)->??) -> [??];

	doubleFirst = mapi(bigger, \i, v -> if (i == 0) 2 * v else v);
	assert(doubleFirst == [2,4,9,16], "Error: First is not doubled");

The indexes are 0 based.

If you need to find an index of the element in an array, use `findi`.
The second argument is function that takes an element from list and returns bool. When this 
function returns true, `findi` returns the index of the current element. If function returns 
false for each element, `findi` returns `None`.

	findi : (a : [?], fn : (?) -> bool) -> Maybe<int>;

	names = ["Alice", "Bob", "Carol"];
	index1 = findi(names, \name -> if (name == "Bob") true else false); // = Some(1)
	index2 = findi(names, \name -> name == "Mary");// = None() 

Another common operation is to reduce an array to a value, also called folding.

	fold : ([?], init : ??, fn : (??, ?)->??) -> ??;

	assert(fold(doubleFirst, 0, \x,y -> x+y) == 31, "Error: Sum of all elements should be 31");

This fold is a left-fold, and can used to find the minimum, maximum, sum, product and
so on of arrays, although functions for those things often already exist.

There are a bunch of other useful iteration primitives listed in `runtime.flow`
and `array.flow`.

Mutable arrays can be simulated using `replace`. This will "replace" a given element
at an index in an array with a new value to give a *new* array:

	replace : ([?], int, ?) -> [?];

	backAgain = replace(doubleFirst, 0, 1);
	assert(backAgain == bigger, "Error: We are not back to basics");

	// Can also be used to append to an array
	oneMore = replace(backAgain, length(backAgain), 25);
	assert(oneMore == [1,4,9,16,25], "Error: Append did not work");

Note that `replace` has to make a full copy of the original array, so it will
not perform well for much replacement work. You can also consider to use the list 
in `list.flow`, which is a normal functional list. There are useful native helpers 
`list2array` and `list2string` which provides efficient ways to concatenate lots of 
elements into one big array or string in linear time.

You can use `subrange` to extract parts of an array:

	subrange : ([?], index : int, length : int) -> [?];

	assert(subrange(oneMore, 2, 3) == [9,16,25], "Error: Subrange is borked");

Someday you will need to get an array from some other array without a first element. In 
this case `tail` is exactly what you need. `tail([1, 2])` returns `[2]` and `tail([2])` 
returns `[]`.

Besides arrays and structs, there are no other compositional builtin data structures in flow,
but several data structures such as lists, binary trees (i.e. maps), double linked lists, and
graphs are implemented in flow itself.

<h2 id=maybe>Maybe</h2>

The `Maybe` type is used for when you are not sure you have a value.

For example, you are looking for the index of an element in an array
with `findi`. The index is an `int`, but what if the array does not
contain the element?  In that case it will return `None()`.  So the type
returned is either `int` or `None`.  This is encoded with a union:

	Maybe<?> ::= None, Some<?>;
        None();
        Some(value : ?);

And `findi` returns `Maybe<int>`.

There are useful functions in `maybe.flow` that help working with `Maybe`.

	maybeApply : (m: Maybe<?>, f: (?) -> void) -> void;

`maybeApply(m, f)` applies `f` to `m` if `m` is really a value; if it is
`None`, nothing is done.  

`Maybe` is similar to boxed objects in Java that can be either Null or
some object instance, or pointers in other languages that can be null
(or nil).

Another useful function for working with Maybe<?> types is `either`:

    s = Some(1);
    n = None();
    a = either(s, 0); // a = 1
    b = either(n, 0); // b = 0

`Maybe` seems a very natural solution in many cases, but it has some
disadvantages. Code that uses functions that return `Maybe` becomes more
complicated. It would be annoying if `/` returned `Maybe<double>`
because `x/0` is `None`.  So think twice before you return `Maybe`: Is
there a simpler solution? There are at least two alternatives.

1)  In a lot of situations you can find a value which is an alternative to None.
For functions returning ints, sometimes `0` or `-1` or intMax can meaningfully 
represent "none".  Often the neutral element of another operation can be a good
"none", e.g. empty string:

    personToString(maybePerson) + "\n" + addressToString(maybeAddress).

It can also be some default structure like Empty() or TreeEmpty().
The best and the most used example is probably `strIndexOf(text, substring)`
which returns `-1` if `substring` is not found in `text`. `sum([int])` returns 
`0` for an empty array.

2) Another way is to pass a default value to the function. Then people who
use your function `f`, can write:

    f(input, defaultvalue)

rather than `either(f(input), defaultvalue)` or 

    switch (f(input)) {
        None(): defaultvalue;
        Some(x): ....
    }

It is especially useful in "template" functions where you can't specify a
default "none" value for all types. Examples: `findDef`, `firstElement`,
`lookupTreeDef`.

## The `??` operator for deconstructing `Maybe` values

Although the use of default values is a common practice which helps avoid the
use of `Maybe`, it is still very common. To help decompose values of type
Maybe, the `??` operator is helpful:

	foo(m : Maybe<int>) -> int {
		m ?? m + 2 : 0;
	}

This is equivalent to a switch:

	foo(m : Maybe<int>) -> int {
		switch (m) {
			Some(v): v + 2;
			None(): 0;
		}
	}

The `??` operator has this form: `<var> ?? <exp1> : <exp2>`, and it is short for
this code:

		switch (<var>) {
			None(): <exp2>;
			Some(<value>): <exp1> where <var> is replaced by <value>;
		}

Here is a list of examples on how this operator can replace some of the `Maybe` helpers:

	m ?? m : a               == either(m, a)
	m ?? fn(m) : a           == eitherMap(m, fn, a)
	m ?? fn(m) : afn()       == eitherFn(m, fn, afn)
	m ?? f(m) : None()       == maybeBind(m, f)
	m ?? Some(f(m)) : None() == maybeMap(m, f)
	m ?? f(m) : {}           == maybeApply(m, f)
	m ?? true : false        == isSome(m)

<h2 id=refs>References</h2>

In *flow*, all variables are immutable. To support imperative programming, you
have to use references, similar to ML:

	r : ref double = ref 1.0;

	old = ^r; // Dereference
	r := 2.0; // Destructive update
	assert(old == 1.0, "Error: Assignment by copy");
	assert(^r == 2.0, "Error: Reference is not updated");

	dr : ref flow = ref 1.0;
	dr := "Strange";
	assert(^dr == "Strange", "Error: Flow is wild");
	dr := 1; // OK

Although flow supports references, their use is discouraged because side effects are 
a bad thing to deal with. Usually it is better to pass data as function parameters 
instead of side-effecting it.

<h2 id=funcs>Functions and lambdas</h2>

As seen before, function types are declared like this:

	// Functions
	fib(int, int) -> int;

	// With names for documentation
	fac2(n : int) -> int;

	print(f : flow) -> void;

and defined like this:

	fib(i1 : int, i2 : int) -> int {
		...;
		...;
		i3;
	}

Notice there is no `return` statement. In fact, there are no statements at all.
Flow is an expression based language. At the top-level, we support a special
syntax for defining functions, but at the expression level, we do not. Instead,
you can use _lambdas_:

	myAddition = \x, y -> x + y;
	assert(myAddition(1, 2) == 3, "Error: Lambda addition is broken");

The `\x, y -> x + y` bit is a declaration of an anonymous function which takes
two parameters, `x` and `y`, and calculates their sum `x + y`.

Instead of having a bare `return` statement, use the empty sequence `{}` as the void value.

<h2 id=pipe>Function call: pipe-forward</h2>

Usually, function call uses "`f(x)`" syntax:

	// Function declaration
	println : (f : flow) -> void;

	// Function call
	println("Hello");

The language also allows point-free call style using the `|>` ("pipe-forward") operator to
express `x |> f`:

	// Function call with pipe-forward operator
	"Hello" |> println;

This is useful to chain a number of sequential function calls:

	// Calculate sum of squares of even elements
	sumSqr = [0,1,2,3,4,5,6,7,8,9]
		|> (\lst -> filter(lst, \x->x%2==0))
		|> (\filtered -> map(filtered, \x->x*x))
		|> (\squared -> fold(squared, 0, \a, x -> a+x));

	// Print the result
	println(sumSqr);

This will print "120".

Be careful: The lambda syntax is greedy, so the following example will report an identifier redefinition error:

	// Identifier "l" redefinition error
	sumSqr = [0,1,2,3,4,5,6,7,8,9]
		|> \l -> filter(l, \x->x%2==0)
		|> \l -> map(l, \x->x*x)
		|> \l -> fold(l, 0, \a, x -> a+x);

Corrected example:

	// No identifier "l" redefinition error
	sumSqr = [0,1,2,3,4,5,6,7,8,9]
		|> (\l -> filter(l, \x->x%2==0))
		|> (\l -> map(l, \x->x*x))
		|> (\l -> fold(l, 0, \a, x -> a+x));

The pipe-syntax does obscure the type of the entire expression as such, so we recommend to limit the use
to situations where the type is the same throughout or otherwise obvious.

if
--

`if` expressions are like in C, except they are expressions:

	if (hungry) {
		eat();
	}

	if (time == money) {
		hurryup();
	} else {
		takeItEasy();
	}

	absi = if (i > 0) {
		i;
	} else {
		-i;
	};

If you leave out the `else`-branch, the result in the then-branch has to
be void, also spelled {}:

	if (hungry) {
		food = gather();
		meal = cook(food);
		eat(meal); // Might return the number of calories
		{} // To make sure the statement type checks
	}

<h2 id=seq>Sequence</h2>

We emulate statements with the sequence expression:

	{
		exp1; exp2; exp3
	}

The value of the sequence is the last expression:

	whatIsTheMeaningOfLife = {
		askThisGuy();
		askThatGuy();
		42;
	}

(Thus you can see why we do not need a `return` statement.)

The grammar is forgiving about end braces and semicolons at the end:

	a = {0}
	a = {0;}
	a = {0;};

<h2 id=structs>Structs</h2>

All structs in *flow* are named. To define a struct value, you first have to
declare the type at the top level using either of the following syntaxes:

	Mystruct(arg1 : int, arg2 : double);
	Mystruct : (arg1 : int, arg2 : double);

Either syntax is acceptable.  Both are used in our codebases, although the 
first is most common.

Then to make an instance:

	val = Mystruct(1, 2.0);

We have a strong conventions that the names of structs are written in caps,
while variables and functions are written in lower-caps. There is an exception
about functions that return user-interface elements, like `Form` and `Material`, where
these functions can have a capitalized initial letter. We should never use a lower
case initial letter for structs or unions, though.

The syntax for making instances is intentionally the same as function calls, since when 
you are programming user interfaces, most often it does not matter if something is a struct 
or a function that produces a struct.

Languages like Prolog and Pico also have a similar syntax for the corresponding concept
called constructors. In those languages, there really is no difference between a
call and a constructor, but there is in flow.

This requires some subtleties in the syntax for types. Notice that

 - `(int)` is an `int`
 - `(n : int)` is a struct type
 - `(int) -> int` and `(n : int) -> int` are function types.

Having structs as a separate type allows us to get to the contents of a struct easily
using the `.` field syntax. Continuing the code above:

	i = val.arg1;
	d = val.arg2;

If you have used enums in Haxe, you know that getting things out of an algebraic datatype
requires a lot of syntax with switch-statements. In *flow*, you can also use a switch, but
the `.` syntax is often very handy. If you need to get to the name of a struct, use the
special `structname` syntax: `val.structname;` which will give you the name as a string.
`structname` is a low-level construct, and the use should be minimized, since it requires
comparing against a string. That is not very type safe. Often, a better choice is to
use the function `isSameStructType` defined in `flowstructs.flow`.

Also there is one more way to make an instance of a struct value:

	oldval = Mystruct(1, 2.0);
	val = Mystruct(oldval with arg1=1);

It is useful when there is a lot of fields in struct, and you need to make another instance
with one or two fields different from the source. You can even make a completely new
instance by enumerating all fields after "with":

	val = Mystruct(oldval with arg1=5, arg2=3.8);

Notice, that this is just syntactic sugar. The compiler transforms such construction into
regular struct instantiation with the respective limitations. Avoid to produce or use any
side effects within this construction, since it could work not as expected. E.g:

	val = Mystruct(oldval with arg2={globalVar:=1; 5.1;}, arg1={globalVar:=2; 10;});

So you would expect `globalVar` to have value *2*, but it has value *1*, because this example
will be transformed into:

	val = Mystruct({globalVar:=2; 10;}, {globalVar:=1; 5.1;});

<h2 id=unions>Unions</h2>

Structs can be grouped into unions using the `::=` syntax at the top-level:

	Form ::= Text, Grid, Picture;
	Text : (text : string, style : [[string]]);
	Grid : (cells : [[Form]]);
	Picture : (url : string, style : [[string]]);

`Form` is introduced as a typing relationship between the different structs, and is
used for static type checks, as well as exhaustiveness checks in switches.

You can not create values of `Form` - only of the subtypes of it. For type-checking reasons,
you can cast a value to a union, but it has no runtime consequence.

A union can include other unions as a short-hand:

	MegaForm ::= Form, Mega;
	Mega : (big : double);

This is the same as listing all subtypes explicitly:

	MegaForm ::= Text, Grid, Picture, Mega;


<h2 id=switch>switch</h2>

You can switch on a struct value using the `switch` statement. First, let's define some struct
types:

	Form ::= Text, Grid, Picture;
	Text : (text : string, style : [[string]]);
	Grid : (cells : [[Form]]);
	Picture : (url : string, style : [[string]]);

Then, given some Form, we can dispatch based on the type:

	switch (form : Form) {
    	Text(text, style): println(text);
    	Grid(cells) : iter(cells, \row -> map(row, println));
    	default: println("Not implemented yet?");
	}

Note the use of `default` as a catch-all case (as in C and Java). Normally, we recommend
not using a `default` case, since that turns off exhaustiveness checking, even if that means
listing 10-20 cases for structs with identical behaviour. You can also often match a union
to reduce boilerplate, but notice that the body on match on unions is duplicated for each
struct in the union in the background, causing code bloat if your body is big.

switch can not dispatch on `int`s and other basic types. Just use if-statements instead.

So contrary to `switch` in languages like C, C# and Java, the `switch` in *flow* does
**two** things: It implements the normal "if/goto" like behaviour, but also, it "deconstructs"
the value given into the switch and extracts the values of the struct into local variables.
Example:

	Pair : (first : ?, second : ??);
	a = Pair(1, "text");
	switch (a : Pair) {
		Pair(f, s):  {
			println(f); // Prints 1
			println(s); // Prints "text"
		}
	}

This code is practically equivalent to

	Pair : (first : ?, second : ??);
	a = Pair(1, "text");
	if (a.structname == "Pair") {
		f = a.first;
		s = a.second;
		println(f); // Prints 1
		println(s); // Prints "text"
	}

although it is more efficient with the switch.

Since flow is an expression-based language, `switch` works just like any other expression and it's result 
may be assigned.

	StructSign ::= Plus(), Minus();
	sign : string = 
		switch (structSign) {
			Plus(): "+";
			Minus(): "-";
		}

<h3 id=mutable>Mutable fields</h3>

As a special optimization feature intended for reducing the memory usage caused by certain
data structures, struct fields can be declared as mutable:

    DLink(v : ?, mutable before : DNode, mutable after : DNode);

Such fields behave exactly as any other struct field, except that it is possible to use
the following syntax to change the value after the initial creation of the struct.

    link.before ::= node;

No special accommodations are made to ensure stable comparison order when the values 
in the fields change.  The comparison order may change after garbage collection on some
platforms.  (If you have a struct A with mutable, and compare it with
a function or something like that, it might give A < fn at one point,
but fn < A at another point. It is a rare edge case, but worth knowing
about. The problem arises from the combination of a copying garbage
collector and the use of memory addresses for comparison.  Note that
comparison won't change unless you actually mutate the mutable field.)

With `mutable` you can create struct cycles that will cause infinite
recursion during comparison operations.  So generally when you use
`mutable` you should only use the `isSameObj` native function to compare 
them, which does a simple pointer comparison for equality without looking at
the fields.

`mutable` should only be used after a careful evaluation for structures 
that are proven by profiling to consume a noticeable percentage of
memory because of the refs. In ordinary circumstances, refs should be
the first choice.

An example of the use of `mutable` in the Flow standard library is in the
implementation of behaviours (see the Form documentation).  It was
introduced only after memory usage issues were observed in practice.

<h2 id=casts>Casts</h2>

There are no implicit casts in flow, not even between `double` and `int`. Instead,
you have to use the type-cast function:

	a : double;
	a = cast(1 : int -> double);

The number of casts supported is currently limited to `int <-> double`, `int/double -> string`,
and everything can be casted to/from `flow`. Also, casts can be used to convert from subtypes to union
types for type checking reasons only.

To help with common casts, the following functions are defined:

 	- `i2d`, `d2i`
 	- `i2s`, `s2i`
 	- `d2s`, `s2d`
 	- `b2s`

where i stands for int, d for double, s for string, and b for bool. For that reason,
you rarely ever need to use `cast` directly.

When you switch on a value v, the type of v will automatically be downcasted to whatever
case is matched in the case body of the switch:

	U ::= Foo, Bar;
		Foo(foo : int);
		Bar(bar : int);
	
	foobar(v : U) {
		switch (v) {
			Foo(a): {
				// Here, v is of type Foo
				v.foo;
			}
			Bar(a): {
				// Here, v is of type bar
				v.bar;
			}
		}
	}
	
<h2 id=special>Special types `flow` and `native`</h2>

The `flow` type means "any type":

	dynamic : flow;
	dynamic = "Anything"; // Could be anything

This is similar to Dynamic in Haxe, Object in Java, and so on.
The flow type is untyped and boxed at runtime, so use it sparingly.

`flow` was added to the language to be able to give a type to built-in
functions that get data from the "outside world", e.g., unstreaming
binary data. It is not meant to be used for other purposes.

Specifically, if you have a type that can be several types, use unions
to model this in your datatypes, NOT `flow`.  Or model this union of
types with other types.  And consider, whether you need this type. Is
there ever a time where you should use `flow`?  Probably not.

For casting to/from flow, there are a range of helpers in the `dynamic.flow` module.

There is another type `native`, which can only be constructed by native functions, but
you can use the type in declarations, as well as pass values of these around.
Of course, they are meant to be consumed by other native functions.

	native currentClip : () -> native = RenderSupport.currentClip;
	renderTo : (clip : native, form : Form) -> () -> void;

To provide information to flow optimizers, we have a type annotation "`io`" which marks
that a given (native) function is impure and can not be calculated at compile time.

<h2 id=parameterized>Parameterized types</h2>

*flow* supports parameterizing types, similar to what exists in ML, Haxe, Java, C# and
similar language. Let's look at an example:

	max(?, ?) -> ?;

This declares a function which takes 2 arguments, which have to be the same type,
and returns a value, which also is required to be of the same type.

(The same would be written something like `max<N>(n1 : N, n2 : N) : N;` in Haxe. Notice that
our syntax is shorter, and arguably clearer.)

Another example is `concat`, which concatenates arrays of the same type, and gives an array of
the same type:

	concat([?], [?]) -> [?];

Parameterized type-declaration only have scope of the single declaration. So for every declaration,
the ? type introduces a new type parameter with no direct relation to other declarations.

A more complicated example `fold`:

	fold : ([?], init : ??, fn : (??, ?) -> ??) -> ??;

This takes an array of some type, then an initial value of another type. The third argument
is a function that combines these two values, and returns a result which is "folded" back
in the next iteration. You can see that the return type of that function has to match the
initial value for this threading to work.

You can also parameterize structs, which is useful for container-style code:

	myTree : Tree<int, string>;

This declares a dictionary from `int`s to `string`s. The implementation of the binary
tree declares the general binary tree like this:

	Tree<?, ??> ::= TreeNode<?, ??>, TreeEmpty;
		TreeNode : (key : ?, value : ??, left : Tree<?, ??>, right : Tree<?, ??>, depth : int);
		TreeEmpty : ();

Additional type safety around type parameters is based on the fact that all functions that work on 
binary trees do have those parameters, and as long as each of those are disciplined about transferring 
the types around the parameters in and out of itself, the effect is that everything works out. 

Secondly, the relation between the angle <bracket syntax> and the `?` syntax is given by
the number of question marks: The first parameter in a bracketed list of types corresponds to the `?`
type. The second parameter corresponds to the `??`, and so on. This trick is what saves us from having
to declare the type parameters and give them names.

However, it is good style to explicitly add type parameters to the union itself:

    Ast<?> ::= Node1<?>, Node2<?>;

This is a mechanism which can be used to make sure that the type parameter in `Node1` and `Node2`
is the same when they are considered as an `Ast`.


<h2 id=impure>Impure functions</h2>

All of flow is pure, except for `native` functions marked with the `io` type modifier.
If a function uses a function marked with `io`, it itself becomes impure as well.
The following are examples of impure functions:

    // Crashes the program when not satisfied. Normally only used in console-programs,
    // since we do not want interactive programs to crash.
    assert(b : bool, errorMessage : string) -> void;

    // Pretty-prints any value on the console
    println : (flow) -> void;

    // A random number between 0 and 1
    random : () -> double;

    // Get the current time, in seconds since epoch 1970
    timestamp : () -> double;

    // Get a callback in x milliseconds
    timer : (int, () -> void) -> void;

Any impure function can not be evaluated at compile time.

<h2 id=native>Native functions</h2>

In order to interface with the surrounding runtime environment, it is possible to declare
_native functions_ implemented in the hosting code:

    native random : () -> double = Native.random;

    // The call is just like a normal function call
    assert(0.0 <= random() && random() < 1.0, "Error: Random should give values between 0 and 1");

The `Native.random` part of the declaration is the name of the function in the native language.
In the Haxe target, a call to this function roughly translates to:

    // haXe code
    return new Native(interpreter).random();

    // ...we would have this supporting code to implement this method:
    class Native {
        ...
        public function random(args : Array<Flow>, pos : Position) : flow {
            return ConstantDouble(Math.rand(), pos);
        }
    }

Notice that adding new natives is done rarely. In many cases, we try to avoid it, because it comes 
with a promise for the future. It makes porting flow to new platforms more expensive.

However, if a new native is required, it needs to be implemented in all runtimes. This includes
at least 2 different Haxe runtimes, C++, and Java.

When the native is needed only for optimization purposes, or makes sense only for one target,
it is possible to define a fallback body for the native as an ordinary flow function:

    native add_10 : (int) -> int = Native.optimized_add_10;

    add_10(x : int) -> int {
        x + 10
    }

The body definition must be placed in the same source file _after_ the actual native declaration,
and have the same number and types of arguments and return value. This pair of definitions is
compiled in such a way that any targets that actually implement the native would use it, while
those that don't will fall back to the flow implementation instead of signalling an error.
Targets that cannot detect if they implement a native without causing an error always use the 
fallback.

<h2 id=quoting>Quoting and unquoting</h2>

There is support for quoting expressions in flow. This provides a way to use flow syntax to
construct an AST (Abstract Syntax Tree) structure directly in the source code.

This is done with the `@<exp>` syntax:

	import qexp;	// You have to add this import yourself for quoting to work
	import runtime;

	foo() {
		@1;	// This is short for QInt(1)
		@1+2; // This is short for QCallPrim(QAddPrim(), [QInt(1), QInt(2)]);

		println(QInt(1) == @1); // Will print 'true'
	}

The type of a `@` expression is thus the union `QExp`. This type defines an (untyped) AST 
of all flow expression constructs (except for `cast`, which is not supported). It is mirrored
exactly after the type `FiExp` used inside the `flowc` compiler, except that it is untyped and does not
contain position information.

The quoting feature is thus a way to shortly and naturally write constants that define code instead of
writing a lot of structs manually.

If you want to have variables in the resulting AST, then you can unquote expressions inside a quote, 
using the `$<atom>` syntax. This can be used like this:

	import qexp;	// You have to add this import yourself for quoting to work

	foo(a : int) {
		@1+$a; // This is short for QCallPrim(QAddPrim(), [QInt(1), QInt(a)]);
	}

This works for any expression:

	import qexp;	// You have to add this import yourself for quoting to work

	foo(a : int) {
		@1+$(a+2*3); // This is short for QCallPrim(QAddPrim(), [QInt(1), QInt(a+2*3)]);
	}

When you unquote, we only support unquoting expressions of type `bool`, `int`, 
`double`, `string`, or array types of these. (We might later allow structs of type `QExp`
to be unquoted, but so far there has been no need for this.)

Quoting and unquoting is an advanced feature, which is not often used. It can be used to make
embedded DSLs that naturally interact with flow. That will often be done by having an
interpreter of the `DExp` union that implements whatever semantics you desire. (There is 
currently no implementation of a flow interpreter based on the `QExp` type.)

<h2 id=coding>Coding conventions</h2>

To make sure all code is uniform, we have to have some coding conventions. This is a reference
to the recommended way to format code in *flow*:

	// Spacing around : and ->, because horizontal space is plentiful
	fac(n : int) -> int;

	// Space after // in comment, because it looks better

	// Start brace on same line to conserve vertical space
	fac(n) {
		if (n <= 1) {
			n;
		} else {
			n * fac(n - 1);
		}
	}

	// Space around operators
	a = 1;

	// Space before ( in if, { brace on same line
	if (a == 1) {
		// Function call without space before (
		println("a is 1");
	}

	// No space after \, space around ->
	lambda = \v -> i;

	// Camel humping identifiers
	myReference = ref 1;

	^myReference;

	// Space after comma
	array = [1, 2, 3, 4];

	// Always space after comma
	big = concat([1, 2], [3, 4]);
	test = \a, b -> 1;

	// A function call that spreads over many lines
	result = makeList([
		firstParameter,
		secondParameter,
		third(
			3,
			4,
			veryDeep
		)
	]);

	// These are also acceptable - we do not want to be ridiculous
	f : (x : flow, y: (int)->int, z : double) : int;
	seven = 1 + 2*3;

<h2 id=data>Data structures</h2>

Besides the builtin array and structs, some useful data structures
have been implemented in *flow* itself. Most useful is arguably the
binary tree implemented in `ds/tree.flow`.

This implements a key/value store organized in a binary tree. This data
structure implements dictionaries (`setTree`) as well as heaps using 
`popmax` and `popmin`. It is also the basis of the `Set` data structure.
It also has useful helpers when you need to store multiple values per key in 
the form of the `treePushToArrayValue` and `getTreeArrayValue` helpers. These 
allow you to add any number of items to a key, and then extract those as an 
array as a multi-map.

If you need to build data structures one element at a time, use a `List`
declared in `ds/list.flow`. This is a traditional functional list, implemented
using structs. It supports constant time append (`Cons`), contrary to an
array where append is linear time. You can convert a  `List` to an array
using `list2array`. (You can also convert to a string using `list2string`.)

Have a look in the `ds/` folder to find other useful data structures.

<h2 id=loops>Loops</h2>

Loop constructs are an indispensable feature in many imperative
languages.  Flow being an imperative language, it certainly makes sense
to have loops as well.  You can iterate both with loop constructs and
using recursion.  Both ways have their pros & cons.  I think the
programmer who knows both the imperative and the functional style of
programming will find that in most cases recursion expresses his intent
better than loops.

In some cases, still, loops are the right thing to do.  A while loop is,
however, not included in *flow*.  One reason is, it is important to keep
the complexity of a programming language down. Another is that we would
like to promote the use of `map` and other functional constructs that
arguably are clearer, and easier to optimize.

Here is a tough example of something hard to change to recursion:

	foo(i : int, j : int, n : int) -> int {
		while(true) {
			if (i > j) return n;
			if (! cons(i)) break; i++;
		}
		i++;
		while(true) {
			while(true) {
				if (i > j) return n;
				if (cons(i)) break;
				i++;
			}
			i++;
			n++;
			while(true) {
				if (i > j) return n;
				if (! cons(i)) break;
				i++;
			}
			i++;
		}
	}

Lots of control flow (return & break) going everywhere.  That does not
prove anything other than code that is hard to read is hard to rewrite.
If you really tried rewriting it using recursion, you would probably
produce code much easier to read & debug & maintain.  Nevertheless, that
is not always convenient.  For instance, if you are porting code with
while loops, you do not want to rewrite every loop.  In that case, you
can still convert loops to recursion using a mechanical, almost textual
conversion, as follows:

Convert every while to a function:

	while (true) { BODY; }
		---->
	while1() {
		BODY;
		while1();
	}

Convert return statements to just the expression:

	return n;     ---->    n

In general, convert every jump in the code to a function call, e.g.,
breaks too.  Here, as an example, is the code above converted to
functions:

	main() {
		while1(0, 10, 15);  // start the first while loop
	}
	while1(i, j, n) {
		if (i > j) n
		else if (! cons(i)) break1(i, j, n)    // Call break1() to break from the first while loop
		else {while1(i + 1, j, n);}
	}
	break1(i, j, n) {   // define function break1() to mark where the first while loop ends
		while2(i + 1, j, n);
	}
	while2(i, j, n) {
		while3(i, j, n);
	}
	while3(i, j, n) {
		if (i > j) n;
		else if (cons(i)) break3(i, j, n)
		else {while3(i + 1, j, n);}
	}
	break3(i, j, n) {
		while4(i + 1, j, n +1);
	}
	while4(i, j, n) {
		if (i > j) n;
		else if (! cons(i)) break4(i, j, n)
		else {while4(i + 1, j, n);}
	}
	break4(i, j, n) {
		while2(i + 1, j, n);
	}


<h2 id=structsoffunctions>Structs of functions</h2>

Flow does not have a special construct supporting multiple
implementations of the same API, like interfaces in Java, functors in
ML, or typeclasses in Haskell.

If you find yourself missing this, consider using a struct of
functions.  This is a standard technique in functional programming.

For example, in Java we might write:

    // interface
    interface Animal {
      String name();
      void speak();
    }
    void testAnimal(Animal a) {
      System.out.println(a.name());
      a.speak();
    }
    // implementation
    class Dog implements Animal {
      String name;
      Dog(String name) { this.name = name; }
      public String name() { return name; }
      public void speak() { System.out.println("woof"); }
    }
    class Duck implements Animal {
      String name;
      Duck(String name) { this.name = name; }
      public String name() { return name; }
      public void speak() { System.out.println("quack"); }
    }
    public static void main(...) {
      testAnimal(new Dog("Rover"));
      testAnimal(new Duck("Ping"));
    }

In Flow this becomes:

    // interface
    Animal(
        name : () -> string,
        speak : () -> void,
    );
    testAnimal(a : Animal) {
        println(a.name());
        a.speak();
    }
    // implementation
    Dog(name : string);
    dogAsAnimal(d : Dog) -> Animal {
        Animal(\ -> d.name, \ -> println("woof"));
    }
    Duck(name : string);
    duckAsAnimal(d : Duck) -> Animal {
        Animal(\ -> d.name, \ -> println("quack"));
    }
    main() {
        myDog = Dog("Rover");
        myDuck = Duck("Ping");
        testAnimal(dogAsAnimal(myDog));
        testAnimal(duckAsAnimal(myDuck));
    }

Or perhaps, if we want Dog and Duck to be more closely related types:

    // interface
    Animal(
        name : () -> string,
        speak : () -> void,
    );
    testAnimal(a : Animal) {
        println(a.name());
        a.speak();
    }
    // implementation
    Pet ::= Dog, Duck;
    Dog(name : string);
    Duck(name : string);
    petAsAnimal(p : Pet) -> Animal {
        switch (p) {
          Dog(name) :
              Animal(\ -> name, \ -> println("woof"));
          Duck(name) :
              Animal(\ -> name, \ -> println("quack"));
        }
    }
    main() {
        myDog = Dog("Rover");
        myDuck = Duck("Ping");
        testAnimal(petAsAnimal(myDog));
        testAnimal(petAsAnimal(myDuck));
    }

This technique is used often in flow codebases. The pattern is usually signaled 
by "Api" or "API" in the name of a type.

Not all uses of structs of functions require all this machinery.
Just as in Java I can implement the interface directly in
an anonymous class:

    new Animal() {
      public String name() { return "Tiger"; }
      public void speak() { System.out.println("meow"); }
    }

so in Flow I can directly write:

    Animal(
      \ -> "Tiger",
      \ -> println("meow")
    )

This shorter form is the preferred way to do it.


<h2 id=languagefinesses>Language finesses</h2>
Flow as any other language has some unobvious moments. Let's consider some of them:

### Example 1

	println("Value is " + if (value) {""} else {"not "} + "true");

Here program will print just "Value is " in case of value=true, since flow parser grabs "true" within the *else* block. Because *{"not" }* is considered as basic block as well as "true",
and then they are processed as the arguments of **+** operator, which serves as final expression for the *else* block.
Fix will look like this

	println("Value is " + (if (value) {""} else {"not "}) + "true");


### Example 2

	func() -> [string] {
		t = if (b) {
			"asd"
		} else {
			"qwe"
		}
		[t]
	}

Similar to previous example. Code will not be compiled, since parser grabs *[t]* and gives final expression for *else* block as **"qwe"[t]**, while *t* isn't declared yet.
Fix will look like 

	func() -> [string] {
		t = if (b) {
			"asd"
		} else {
			"qwe"
		};
		[t]
	}


<h2 id=javascript>flow vs. javascript</h2>
	// Javascript                            // flow

	var constant = 1;                        constant = 1;

    var s = "Hello world";                   s = "Hello world";
    var s2 = "#" + 1;                        s2 = "#" + i2s(1);
    var ar = [1,2,3];                        ar = [1,2,3];

    var n = 1 + 1.5;                         n = 1.0 + 1.5;

	var a = 1;                               a = ref 1;
	var b = a;                               b = ^a;
	a = 2;                                   a := 2;
	var c = a;                               c = ^a;
	a++;                                     a := 1 + ^a;

    if (meaning) 42 else -1;                 if (meaning) 42 else -1;
    var d = 1 < 2 ? 0 : 1;                   d = if (1 < 2) 0 else 1;

	function one() { return 1; }             one() { 1 }
    function twice(n) { return 2 * n; }      twice(n) { 2 * n }
    var zero = function() return 0;          zero = \ -> 0;
    var neg = function(n) return -n;         neg = \n -> -n;

    var ar2 = ar.map(twice);                 ar2 = map(ar, twice);

    switch (grade) {
    case 'A': document.write("Good job");    if (grade == "A") println("Good job")
    case 'B': document.write("OK");          else if (grade == "B") println("OK")
    default: document.write("Hmm");          else println("Hmm");
    }


    var i;                                   fori(1, 10, \i -> println(i2s(i) + " beers"));
    for (i = 1; i <= 10; i++) {              // See other similar helpers in runtime.flow and array.flow
    	document.write(i + " beers");
    }

    function log2(n) {                       log2(n) {
      var divs = 0;                            if (n <= 1) 0;
      while (n > 1) {                          else 1 + log2(n / 2);
    	n / 2;                               }
    	divs++;                              // See also section on loops above
      }
      return divs;
    }

                                             import ds/tree;
    var dict = new Hash();                   dict = makeTree();
    dict[1] = 2;                             dict2 = setTree(dict, 1, 2);
    var two = dict[1];                       two = lookUpTreeDef(dict2, 1, -1);
