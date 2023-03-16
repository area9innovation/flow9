# Initial prompt to teach GPT4 flow

Flow is a functional programming language in the ML family, with typescript like syntax.

A *flow* program consists of modules. A module `example` is defined by a file named
`example.flow`.  The convention is to use lower-case
only filenames.

Each module (file) can import any number of modules as dependencies. This is done
with

	import runtime;
	import ds/set; // Set data structure

Each module exports a set of names. These are declared with an `export` block:

	export {
		// A global variable "foo" of type int
		foo : int;

		// A function taking an int and a string, and returns an array of bools
		bar(i : int, s : string) -> [bool];

		// A structure with two fields
		Text(text : string, style : [[string]]);
	}

The syntax for values is listed here:

	b : bool = true || false;
	i : int = 1 + 0xdeadbeef;
	d : double = 2.0 - 3.0;
	s : string = "My string\n";
	a : [int] = [1,2,3];
	text : Text = Text("Hello", [["bold"]]);

Ints are 32-bit. Comparisons and multiplicative operations on ints are signed.
Doubles are 64-bit. Strings are UTF-16 encoded (i.e. 16 bit). Arrays are immutable. There are a number of polymorphic array functions defines in `ds/array`, such as:

	concat([?], [?]) -> [?];
	length([?]) -> int;
	map([?], (?)->??) -> [??];
	subrange([?], index : int, length : int) -> [?];
	fold([?], init : ??, fn : (??, ?)->??) -> ??;

The `Maybe` type is used for when you are not sure you have a value. It is defined as this polymorphic union, or abstract data type:

	Maybe<?> ::= None, Some<?>;
        None();
        Some(value : ?);


`Maybe` is a union type, while `None` and `Some` are structs. Structs and unions start with uppercase, while functions and variables start with lowercase.

You can switch on unions using the `switch` syntax:

    switch (value) {
        None(): defaultvalue;
        Some(x): { ... };
    }

You can access fields of structs using `.`:

	i = mySome.value;

Functions are written like this:

	// Functions
	fact(n : int) -> int {
		if (n <= 1) n
		else n * fact(n - 1);
	}

The last value in a sequence is the result. Flow is an expression-based language without statements. here is no `return` expression.

Lambdas are defined using this syntax:

	\x, y -> x + y;

Polymorphic functions use `?`, `??` and so on as polymorphic types:

	max(l : ?, r : ?) -> ? {
		if (l < r) r else l
	}

`if` expressions are like in C, except they are expressions:

	absi = if (i > 0) {
		i;
	} else {
		-i;
	};

Some important functions in the standard library are:

	println(?) -> void;
	strlen(string) -> int;
	strContains(str: string, substr: string) -> bool;
	substring(s : string, start : int, length : int) -> string;

Some important functional data structures include ordered, balanced, binary tree in `ds/tree`, a set in `ds/set`, a Cons-list in `ds/list`.

# After sending that to GPT4,. it summarizes the language in a nice way.

Nice summary. Given this type for the ordered, balanced, binary tree:

	// A binary tree with keys of type ? and values of type ??
	Tree<?, ??> ::= TreeNode<?, ??>, TreeEmpty;
		TreeNode : (key : ?, value : ??, left : Tree<?, ??>, right : Tree<?, ??>, depth : int);
		TreeEmpty : ();

with functions like
setTree(tree : Tree<?, ??>, key : ?, value : ??) -> Tree<?, ??>;
lookupTree(tree : Tree<?, ??>, key : ?) -> Maybe<??>;
isEmptyTree(t : Tree<?, ??>) -> bool;
and
rebalancedTree(k : ?, v : ??, left : Tree<?, ??>, right : Tree<?, ??>) -> Tree<?, ??>

can you implement a tail recursive version of 

mergeTree(t1 : Tree<?, ??>, t2 : Tree<?, ??>) -> Tree<?, ??>;

which preserves balancing and order?

