## Simple Values in Programming

The concept of values is foundational to the creation, manipulation, and expression of data. Simple values are the atomic elements that serve as the building blocks for more complex data structures and algorithms.

Values are the essence of communication between a program and its execution environment, and define the result of computation. They represent data, including boolean values that denote truth or falsehood, numeric types for mathematical computations, strings for textual information, and arrays for ordered collections. Each of these types serves a unique purpose, enabling programmers to describe and manipulate the world within their computational models.

### Boolean Values

`true` and `false` are used for controlling the flow of execution through conditional statements and allows reasoning with logical operations like `not` , `and`, and `or`. The syntax for these values is straightforward.

### Numeric Types

Numeric types, including integers and floating-point numbers, written as `42` and `3.141` respectively. These types are crucial for performing arithmetic operations, representing quantities, and modeling real-world phenomena that involve measurements and calculations.

### Strings
Strings are represented simply as sequences of characters encoded as UTF-8. They are fundamental for text processing and user interaction. We use unescaping sequences to handle special characters.

``` melon
"Hello world."
"This is the first line.\nSome characters are escaped with \ like \\, \r, \t, \n"
"Unicode chars are also supported: \u1234 for hex, \123 for decimal."
```

Operations on strings include concatenation, substring, and length, as well as conversions to/from numeric types.

### Arrays
Arrays, surrounded by square brackets `[]` and separated by commas, are ordered collections of values. They allow for the aggregation of multiple values into a single entity, facilitating operations on sequences of data. Operations include indexing, subranging & concatenation.

### Constructors
Constructors is a mechanism for creating instances of more complex data structures from simple values. The syntax `Nil()` and `Cons(1, nil)` look like calls, but are to be considered as *constructors* that constructs the corresponding struct values. A constructor is thus a special value with a name and associated data called *fields*. Normally, we separate function calls from struct constructors using the name: If it is an upper case name, it is a constructor. If it is lower case, it is a function call.

Operations on constructors include deconstructing & retrieval of the fields.

### The grammar for values

Here is the precise grammar for values that we will be using in this book:

``` runcore/value.mango
value = 
	"true" kwsep @true Bool/1 
	| "false" kwsep @false Bool/1
	| $double ws @s2d Double/1 
	| $int ws @s2i Int/1 
	| string @unescape String/1
	| "[" ws @array<value ","> "]" ws Array/1
	| uid "(" ws @array<value ","> ")" ws Constructor/2
```

### The types of values

The values construct a compositional hierarchy of values, in the form of the `Value` union:

``` melon
Value ::=
	Bool(bool1 : bool),
	Int(int1 : int),
	Double(double1 : double),
	String(string1 : string),
	Array(exps : [Value]),
	Constructor(uid : string, exps : [Value]);
```

@run<flowcpp --batch mango/mango.flow -- grammar=runcore/value.mango types=2 typeprefix=Core savegrammar=runcore/value_grammar.flow>
@run<flowcpp --batch mango/mango.flow -- grammar=runcore/value.mango types=1 typeprefix=Core>

### Basic operations

In addition to the raw values, were are range of operations on these values. These include logical operations like not `!`; and `&&`, or `||`, arithmetic operations like `+`, `-`, `*`, `/`, and `%` for modulu, and comparison operations like `==`, `!=`, `<`, `<=`, `>`, and `>=`. 

There are also operations for getting the length of strings & arrays, indexing into arrays, as well as extracting subranges of strings & arrays.

We also have operations for converting between different types of values, like converting/parsing between int & doubles and strings, string to/from an array of integer characters.

We implement a small library of such functions:

``` runcore/core_fns.flow
	andValue(l : CoreValue, r : CoreValue) -> CoreBool;
	orValue(l : CoreValue, r : CoreValue) -> CoreBool;
	notValue(l : CoreValue) -> CoreBool;

	// Also does string & array concatenation
	addValue(l : CoreValue, r : CoreValue) -> CoreValue;
	minusValue(l : CoreValue, r : CoreValue) -> CoreValue;
	mulValue(l : CoreValue, r : CoreValue) -> CoreValue;
	divideValue(l : CoreValue, r : CoreValue) -> CoreValue;
	modValue(l : CoreValue, r : CoreValue) -> CoreValue;
```

The implementations are simple:

``` runcore/core_fns.flow
andValue(l : CoreValue, r : CoreValue) -> CoreBool {
	CoreBool(value2b(l) && value2b(r))
}
```

We have a range of helpers:

``` runcore/value_util.flow
	value2b(v : CoreValue) -> bool;
	value2i(v : CoreValue) -> int;
	value2d(v : CoreValue) -> double;
	value2s(v : CoreValue) -> string;
	value2array(v : CoreValue) -> [CoreValue];
	value2constructor(v : CoreValue) -> CoreConstructor;
```

Each is very simple:

``` runcore/value_util.flow
value2b(v : CoreValue) -> bool {
	switch (v) {
		CoreBool(b): b;
		default: {
			println("ERROR: Expected bool, not " + prettyValue(v));
			false;
		}
	}
}
```

This provides the basic operations that will be used in our programs. We will also use these operations to implement more complex operations on values, like `map`, `fold`, and `filter`, as well as operations on strings and arrays and so on.

## Type system

@run<flowcpp --batch mango/mango.flow -- grammar=runcore/types.mango types=2 savegrammar=runcore/types_grammar.flow typeprefix=Core>
