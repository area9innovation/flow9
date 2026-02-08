# Type inference of Parsing Expression Grammars

In the following, we present a system for defining, parsing, and performing type inference on Parsing Expression Grammars (PEGs) using an integrated approach that combines a grammar language and a stack-based language. This framework allows for the creation of concise and expressive grammars while providing robust tools for semantic actions and abstract syntax tree (AST) manipulations in a strongly typed manner.

## Example: JSON grammar and types

Here is a grammar for JSON:

``` mango
@include<list>

json = "{" ws @array<member ","> "}" ws Object/1
	| "[" ws @array<json ","> "]" ws Array/1
	| "true" ws @true Bool/1
	| "false" ws @false Bool/1
	| string String/1
	| double ws @s2d Number/1
	| "null" ws Null/0
	;

member = string ":" ws json Member/2;

@include<lexical>

ws json
```

Based on this, we can automatically infer these types:

``` melon
// Inferred types from grammar
Json ::=
	Array(jsons : [Json]),
	Bool(bool1 : bool),
	Null(),
	Number(double1 : double),
	Object(members : [Member]),
	String(string1 : string);

Member : (string1 : string, json : Json);
```

With this in place, we could parse `{ "name": "Poppy", "age": 42 }` and get the following strongly typed AST:

``` melon
Object([
	Member("name", String("Poppy")),
	Member("age", Number(42))
])
```

## Outline

We cover the following:

1. **The Grammar Language**: Description of the grammar language, including its constructs, syntax, and examples.
2. **The Stack Language**: Overview of the stack-based language, its constructs, and how it integrates with the grammar language to handle semantic actions.
3. **Type Language**: Explanation of the the type language, type inference algorithms, and handling of polymorphism and overloading.
4. **Type Inference of the Stack Language**: Detailed explanation of the type inference process for the stack language.
5. **Type Inference of the Grammar Language**: Description of the type inference process for the grammar language.

In total, this describes how to integrate a PEG grammar with a stack language, and how to leverage the type inference system to ensure type-safe parsing and AST manipulations.

## Implementation Note

In the actual implementation, type-related names are prefixed with `P` to distinguish them from other type systems in the codebase:
- `Type` → `PType`
- `TypeEnv` → `PTypeEnv`
- `TypeName` → `PTypeName`
- `grammarType()` → `mangoType2()`
- `unifyType()` → `unifyPType()`

Throughout this document, we use the unprefixed names for clarity. When reading the code in `lib/tools/mango/type_inference.flow` and `lib/tools/poppy/type/*.flow`, remember to add the `P` prefix.

## The Grammar Language Constructs

Here is the grammar language used:

| **Grammar construct**     | **Description**                        | **Example**                         |
|----------------|---------------------------------------------------|-------------------------------------|
| `string`       | Matches the exact string                          | `"hello"`                           |
| `char-char`    | Matches any character in the range                | `'a'-'z'`                           |
| `term term`    | Matches a sequence of terms					     | `"hello" " world"`                  |
| `term | term`  | Matches the first term if possible; otherwise the second term (committed choice) | `"a" | "b"` |
| `term+`        | Matches one or more terms                         | `'a'-'z'+`                          |
| `term*`        | Matches zero or more terms                        | `'0'-'9'*`                          |
| `term?`        | Matches optional sequence                         | `"hello" " world"?`                 |
| `!term`        | Matches anything except term                      | `!"i" 'a'-'z'`                      |
| `id = term; term` | Defines a rule and its scope                  | `id = 'a'-'z' ('a'-'z' | '0'-'9' | "_")*; id "," id` |
| `$term`        | Pushes the matching string of a parse on the result stack  | `$id`                      |
| `Constructor/int` | Pushes a constructor with *n* arguments from the result stack | `$id Id/1`           |
| `@stackop`     | Performs semantic actions using a stack language on the result stack  | `@nil` or `@'swap s2i'` |
| `@pos`         | Built-in: Returns current parse position as int                       | `@pos`                  |
| `@switch`      | Built-in: Special switching operation (string -> Top)                 | `@switch`               |

The grammar written in itself is here. The `|>` and `>` constructs help implement associativity & precedence and allows some forms of left-recursion. It expands into multiple productions using a set of simple rules, so can be ignored for the type inference.

``` mango
term = 
	term "|" ws <term 						Choice/2
	|> term <term							Sequence/2
	|> "$" ws term							PushMatch/1
	|> term "*" ws							Star/1
	|> term "+" ws							Plus/1
	|> term "?" ws							Optional/1
	|> "!" ws term							Negate/1
	|> 
		"(" ws term ")" ws					
		| uid "/" ws $int ws				Construct/2
		| string		 					String/1
		| char "-" char						Range/2	
		| stringq 							String/1
		| id "=" ws term ";" ws term		Rule/3
		| id 								Variable/1
		| "@" ws id !"<"					StackOp/1
		| "@" ws stringq					StackOp/1
	;

id = $bid ws;
bid = ('a'-'z' | '_') (alnum)*; // Initial lower case only
uid = $('A'-'Z' alnum*) ws; 	// Initial upper case only
alnum = 'a'-'z' | 'A'-'Z' | '_' | '0'-'9';

int = '0'-'9'+;

string = '"' $(!'"' anychar)* '"' ws;
stringq = "'" $(!"'" anychar)* "'" ws;

char = "'" $("0x" hexdigit+ | anychar) "'" ws;

hexdigit = '0'-'9' | 'a'-'f' | 'A'-'F';

ws = s*;
s = cs+;
cs = " " | "\t" | "\n" | "//" (!"\n" anychar)* "\n" | "/*" (!"*/" anychar)* "*/" | "\r";
anychar = '0x0000'-'0xffff';

grammar = ws term;
grammar
```

## The Stack Language for Semantic Actions

The stack language is a functional Joy-inspired stack language. The syntax is a postfix notation of words like other stack languages. It has typical stack-based constructs & useful helper words for use in grammars operating on the result stack. When this language is used in the grammar context, the code should be written using the `@s2i` (to convert a string to an integer), or `@'nil 1 cons'` syntax (constructs a list with a single element), since we embed the stack language inside the grammar language.

| **Construct**    | **Description**                                                                  | **Example**                         |
|------------------|----------------------------------------------------------------------------------|-------------------------------------|
| `nil`            | Pushes an empty list onto the stack                                              | `nil`                               |
| `cons`           | Takes two elements from the stack and pushes a new list with the value added     | `nil 1 cons`                        |
| `swap`           | Swaps the top two elements on the stack                                          | `1 2 swap`                          |
| `drop`           | Removes the top element from the stack                                           | `1 drop`                            |
| `dup`            | Duplicates the top element on the stack                                          | `1 dup`                             |
| `print`          | Outputs the top element of the stack                                             | `42 print`                          |
| `dump`           | Outputs the entire content of the stack                                          | `1 2 3 dump`                        |
| `nop`            | No operation                                                                     | `nop`                               |
| `true`           | Pushes boolean true onto the stack                                               | `true`                              |
| `false`          | Pushes boolean false onto the stack                                              | `false`                             |
| `<int>`          | Pushes an integer onto the stack                                                 | `42`                                |
| `<double>`       | Pushes a double-precision floating-point number onto the stack                   | `3.14`                              |
| `<string>`       | Pushes a string onto the stack                                                   | `"hello"`                           |
| `[...]`          | Constructs a quotation, i.e. a chunk                                             | `[42 1 +]`                          |
| `eval`           | Evaluates the top quotation on the stack                                         | `[42 1 +] eval`                     |
| `ifte`           | If-then-else construct                                                           | `true [41 1 +] [12] ifte`           |
| `while`          | While loop construct                                                             | `1 [dup 10 <] [dup print 1 +] while`|
| `define`         | Defines a word                                                                   | `define pi = 3.14159 ;`             |
| `->id`           | Updates a value using the `->` syntax                                            | `3.14 ->pi`                         |
| `<Uid>/<int>`    | Constructs a structure with a given arity                                        | `42 Some/1`                         |
| `s2i`            | Converts the top string element on the stack to an integer                       | `"123" s2i`                         |
| `s2d`            | Converts the top string element on the stack to a double                         | `"3.14" s2d`                        |
| `unescape`       | Processes the top string element on the stack, converting escape sequences       | `"Poppy \\u1F33A\\n" unescape`      |
| `hex2int`        | Parses the top string element on the stack as a hexadecimal number               | `"0xdeadbeef" hex2int`              |

The grammar is given here. This would parse `nil 1 cons` as `Sequence(Nil(), Sequence(Int(1), Cons()))`. Notice we use the `@` grammar construct to demonstrate how to use the stack language itself in the grammar:

``` mango
poppy = poppy (poppy Sequence/2)*
	|> command kwsep 
	| "define" kwsep word poppy ";" ws Define/2
	| "->" ws word Set/1
	| uid "/" ws $int ws @s2i ConstructArity/2
	| "[" ws poppy "]" ws Quote/1
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

kwsep = !alnum ws;

double = signed_int "." int? exponent?
	| "." int exponent?
	| signed_int exponent;
	signed_int = "-"? int;
	exponent = ("E" | "e") ( "+" | "-" )? int;

ws poppy
```

## Type System & Inference

We can do type inference on the stack language. The approach is inspired by the techniques described in [Talk Notes by Rob Kleffner](https://prl.khoury.northeastern.edu/blog/static/stack-languages-talk-notes.pdf). Instead of full stack-based polymorphisms as they do, we instead have a type construct `TypeEval`, which captures the stack polymorphism. We extend their approach to also include overloading. The type inference process involves several steps: inferring types, composing types, and unifying types.

### Type Language

This is the type language:

``` flow
Type ::= TypeName, TypeEClass, TypeWord,  TypeCompose, TypeOverload, TypeEval;

	// This is a short for `( -> name<typars>)`
	TypeName(name : string, typars : [Type]);

	// For type variables to be determined - also used for polymorphism
	TypeEClass(eclass : int);

	// This is the type of a word that takes (inputs -> outputs)
	TypeWord(inputs : [Type], outputs : [Type]);

	// Composing two types: This is function composition
	TypeCompose(left : Type, right : Type);

	// This is an overload of types - used for + and other constructs
	TypeOverload(overloads : [Type]);

	// The type of the keyword `eval` is this construct, which has stack polymorphism: 
	// ( -> a) ◦ eval = a
	// ( -> a b) ◦ eval = a b
	// (a (a' -> b)) ◦ eval = b (unifying a and a')
	// (a b (a' b' -> c)) ◦ eval = c (unifying a and a' & b and b')
	// ...
	TypeEval();
```

We support polymorphism, overloading, and stack polymorphism.

#### Polymorphism Instantiation

When a polymorphic function (like `cons` or `drop`) is used, the system creates fresh type variables for each use. This is handled by the `instantiatePolymorphism()` function:

**How it works:**
1. When looking up a word's type from the environment, the stored type may contain type variables (eclasses)
2. `instantiatePolymorphism()` creates fresh eclasses for each type variable
3. A cache ensures consistent substitution within a single instantiation
4. Each call gets completely fresh variables—no sharing across different uses

**Example:**
```flow
cons : (List<?>, ?) -> List<?>

// First use:  (List<ε₁>, ε₁) -> List<ε₁>   (where ε₁ is a fresh eclass)
// Second use: (List<ε₂>, ε₂) -> List<ε₂>   (where ε₂ is a different fresh eclass)
```

This allows the same polymorphic function to be used with different types in different contexts, with type inference determining the actual types based on usage.

See `lib/tools/poppy/type/instantiate.flow` for the implementation.

### Type Inference of the Stack language

Based on this type language, the type inference of the stack language is done using this type environment:

``` flow
	TypeEnv(
		// Used to track the types of eclasses using a union-find map indexed by eclass
		unionFindMap : UnionFindMap<[Type]>,
		// Suggested names for eclasses (used for generating good field names and union names)
		eclassNames : ref Tree<int, string>,
		// What is the type of each word (function)?
		words : ref Tree<string, Type>,
		// The unions we have uncovered so far (accumulated during type inference)
		unions : ref Tree<string, [Type]>,
		// The constructor names we have encountered
		structs : ref Set<string>,
		// For generating unique eclasses
		unique : ref int,
		// For debug output formatting (current indentation level)
		indent : ref string,
		// Debug verbosity level (0 = quiet, 1-4 = increasingly verbose)
		verbose : int,
	);
```

Notice that for each equivalence class, we have an array of types in the union-find-map. This is used for subtyping. Given the special nature of grammars, we do not need a subtyping construct in the type language - it is sufficient to capture it in the eclass environment.

The basic type inferences goes like this:

``` flow
poppyType(env : TypeEnv, pop : Poppy) -> Type {
	switch (pop) {
		Bool(bool1): TypeName("bool", []);
		Int(int1): TypeName("int", []);
		Double(double1): TypeName("double", []);

		Cons(): {
			poly = makeTypeEClass(env, "");
			list = TypeName("List", [poly]);
			TypeWord([list, poly], [list]);
		}
		Drop(): {
			poly = makeTypeEClass(env, "");
			TypeWord([poly], []);
		}

		Constructor(uid, args): {
			targs = map(args, \a -> poppyType(env, a));
			TypeName(uid, targs)
		}
		Word(word): {
			mtype = lookupTree(^(env.words), word);
			mtype ?? {
				instantiatePolymorphism(env.unique, ref makeTree(), mtype);
			} : {
				perror("Unknown type of word " + word);
			}
		}

		...

		Eval(): {
			TypeEval();
		}
		Ifte(): {
			// (bool ε ε -> ε) ◦ eval
			poly = makeTypeEClass(env, "");
			TypeCompose(
				TypeWord([TypeName("bool", []), poly, poly], [poly]),
				TypeEval()
			);
		}

		ConstructArity(uid, int1): {
			typars = generate(0, int1, \i -> makeTypeEClass(env, uid));
			TypeWord(typars, [TypeName(uid, typars)]);
		}

		Define(word, poppy): {
			// OK, what is the original eclass of this word?
			meclass = lookupTree(^(env.words), word);

			// To handle recursion, we use a placeholder tyvar to avoid infinite recursion
			placeholder = makeTypeEClass(env, word);
			env.words := setTree(^(env.words), word, placeholder);

			// Now type the body
			type = poppyType(env, poppy);

			// Replace the placeholder in the inferred type
			rtype = substituteType(placeholder, type, type);

			setUnionMapValue(env.unionFindMap, placeholder.eclass, [rtype]);

			// And we have the type
			env.words := setTree(^(env.words), word, rtype);

			meclass ?? {
				unifyType(env, false, meclass, rtype);
				{}
			} : {}
			TypeWord([], []);
		}

		Sequence(poppy1, poppy2): {
			t1 = poppyType(env, poppy1);
			t2 = poppyType(env, poppy2);
			mtype = composeIfFeasible(env, t1, t2);
			mtype ?? {
				mtype;
			} : {
				perror("Cannot compose " + prettyPoppy(poppy1) + " : " + prettyType(env, t1) + "   with   " + prettyPoppy(poppy2) + " : " + prettyType(env, t2));
			}
		}
	}
}
```

### Composing types

This uses the following composition function:

``` flow
// If a and b can be composed, do that as much as possible
composeIfFeasible(env : TypeEnv, a : Type, b : Type) -> Maybe<Type> {
	switch (a) {
		TypeName(name, typars): {
			switch (b) {
				TypeName(name2, typars2): Some(TypeWord([], [a, b]));
				TypeEClass(eclass): composeWithEClass(env, a, eclass);
				TypeWord(inputs, outputs): liftA();
				TypeOverload(overloads): composeRightOverload(env, a, b);
				TypeEval(): None();
				TypeCompose(left, right): {
					// a ◦ (left ◦ right) = (a ◦ left) ◦ right
					mfirst = composeIfFeasible(env, a, left);
					mfirst ?? {
						composeIfFeasible(env, mfirst, right);
					} : None();
				}
			}
		}
		TypeEClass(eclass): {
			switch (b) {
				TypeName(name, typars): {
					// e1   ◦   a    = (-> e1 a)
					Some(TypeWord([], [a, b]));
				}
				TypeWord(inputs, outputs): {
					if (inputs != []) {
						// e1  ◦ (inputs... a  -> outputs)
						//    ==   unify(e1, a)  && (inputs... -> outputs)
						liftA();
					} else if (outputs == []) {
						// e1  ◦ ( -> )   ==   e1
						Some(a);
					} else {
						// e1  ◦ (  -> outputs)
						Some(TypeWord([], [a, b]));
					}
				}
				TypeCompose(left, right): Some(makeTypeCompose(a, b));
				TypeEClass(eclass2): Some(makeTypeCompose(a, b));
			}
		}
		TypeWord(inputs1, outputs1): {
			switch (b) {
				TypeName(name, typars): {
					// (inputs -> outputs) ◦ a = (inputs -> outputs) ◦ ( -> a)
					composeIfFeasible(env, a, TypeWord([], [b]));
				}
				TypeEClass(eclass): {
					// When word has outputs, could potentially peel off outputs as inputs to eclass
					// For now, defer composition
					Some(makeTypeCompose(a, b));
				}
				TypeWord(inputs2, outputs2): composeWords(env, a, b);
				TypeOverload(overloads): composeRightOverload(env, a, b);
				TypeEval(): composeEval(env, inputs1, outputs1);
				TypeCompose(left, right): {
					// a ◦ (left ◦ right) = (a ◦ left) ◦ right
					mfirst = composeIfFeasible(env, a, left);
					mfirst ?? {
						composeIfFeasible(env, mfirst, right);
					} : None();
				}
			}
		}
		TypeOverload(overloads): {
			ok = filtermap(overloads, \o -> composeIfFeasible(env, o, b));
			if (length(ok) == 0) {
				None();
			} else if (length(ok) == 1) {
				// We have managed to simplify the overload!
				Some(ok[0]);
			} else {
				// Keep those that are still compatible
				Some(TypeOverload(ok));
			}
		}
		TypeCompose(left1, right1): {
			// When the left side is already a deferred composition, use associativity
			assoc = \ -> {
				// (left1 ◦ right1) ◦ b = left1 ◦ (right1 ◦ b)
				mfirst = composeIfFeasible(env, right1, b);
				mfirst ?? {
					// Check if result is still a compose - if so, defer the whole thing
					if (isPTypeCompose(mfirst)) {
						Some(makeTypeCompose(a, b));
					} else {
						composeIfFeasible(env, left1, mfirst);
					}
				} : None();
			}
			switch (b) {
				TypeName(name, typars): assoc();
				TypeEClass(eclass): Some(makeTypeCompose(a, b));
				TypeWord(inputs, outputs): assoc();
				TypeOverload(overloads): assoc();
				TypeEval(): Some(makeTypeCompose(a, b));
				TypeCompose(left2, right2): {
					// (left1 ◦ right1) ◦ (left2 ◦ right2) = left1 ◦ (right1 ◦ left2) ◦ right2
					middle = composeIfFeasible(env, right1, left2);
					middle ?? {
						mthree = composeIfFeasible(env, left1, middle);
						switch (mthree) {
							None(): None();
							Some(three): composeIfFeasible(env, three, right2);
						}
					} : None();
				}
			}
		}
		TypeEval(): Some(makeTypeCompose(a, b));
	}
}

makeTypeCompose(a : Type, b : Type) -> Type {
	if (a == TypeWord([], [])) {
		b
	} else if (b == TypeWord([], [])) {
		a
	} else {
		TypeCompose(a, b)
	}
}
```

The most interesting case is composing words:

``` flow
composeWords(env : TypeEnv, a : TypeWord, b : TypeWord) -> Maybe<Type> {
	if (a.outputs == []) {
		// (i1... → ) ◦ (i2... → o2...) = (i2... i1... → o2...)
		Some(makeTypeWord(concat(b.inputs, a.inputs), b.outputs));
	} else if (b.inputs == []) {
		// (i1... → o1...) ◦ ( → o2...) = (i1... → o1... o2...)
		Some(makeTypeWord(a.inputs, concat(a.outputs, b.outputs)));
	} else {
		// (i1... → o1... b1) ◦ (i2... b2 → o2...) = (i1... → o1...) ◦ (i2... → o2...) 
		l1 = length(a.outputs);
		b1 = a.outputs[l1 - 1]; // The last output
		o1 = take(a.outputs, l1 - 1);

		l2 = length(b.inputs);
		b2 = b.inputs[l2 - 1]; // The last input
		i2 = take(b.inputs, l2 - 1);

		// Are those types unifyable? Do NOT unify, just check
		if (!unifyType(env, true, b1, b2)) {
			// No, we can not compose then
			None();
		} else {
			// OK, then do unification for real
			unifyType(env, false, b1, b2);
			composeIfFeasible(env, TypeWord(a.inputs, o1), TypeWord(i2, b.outputs));
		}
	}
}

makeTypeWord(inputs : [Type], outputs : [Type]) -> Type {
	// Simplify ( -> T) to just T
	if (inputs == [] && length(outputs) == 1) {
		outputs[0]
	} else {
		TypeWord(inputs, outputs)
	}
}

composeEval(env : TypeEnv, inputs1 : [Type], outputs1 : [Type]) -> Maybe<Type> {
	// Compose a word type with eval: (inputs1 -> outputs1) ◦ eval
	// This is the key to stack polymorphism - eval applies the function on top of stack

	a = TypeWord(inputs1, outputs1);
	l1 = length(outputs1);
	fn = outputs1[l1 - 1]; // The last output is the function to eval
	inputs = take(outputs1, l1 - 1); // Remaining outputs become potential inputs

	switch (fn) {
		TypeWord(fninputs, fnoutputs): {
			// ( -> inputs (fninputs -> fnoutputs)) ◦ eval
			if (fninputs == []) {
				// (b ( -> a)) ◦ eval = (b a)
				// Function takes no args, just append its outputs
				Some(TypeWord(inputs1, concat(inputs, fnoutputs)));
			} else if (inputs == []) {
				// ( -> (fninputs -> fnoutputs)) ◦ eval
				// No values available to pass as arguments - cannot eval
				None();
			} else {
				// ( -> inputs (fninputs -> fnoutputs)) ◦ eval
				// Try to match available values with required arguments
				firstInput = inputs[length(inputs) - 1];
				firstArg = fninputs[length(fninputs) - 1];

				if (unifyType(env, true, firstInput, firstArg)) {
					// Types match! Unify them and recurse for remaining args
					unifyType(env, false, firstInput, firstArg);
					restInput = take(inputs, length(inputs) - 1);
					restArgs = take(fninputs, length(fninputs) - 1);

					// Build curried function with remaining args
					// ( -> restInput (restArgs -> fnoutputs)) ◦ eval
					remaining = TypeWord(inputs1, arrayPush(restInput, TypeWord(restArgs, fnoutputs)));
					composeIfFeasible(env, remaining, TypeEval());
				} else {
					// Types don't match - cannot eval
					None();
				}
			}
		}
		TypeName(name, typars): {
			// ( -> a) ◦ eval -> a  (when inputs1 is empty)
			if (inputs1 == []) Some(a)
			else Some(makeTypeCompose(a, TypeEval())); // Defer
		}
		TypeEClass(eclass): {
			// Try to resolve eclass first
			values = getUnionMapValue(env.unionFindMap, eclass);
			if (length(values) == 1) {
				// Resolve and compose
				resFn = TypeWord(inputs1, replace(outputs1, l1 - 1, values[0]));
				composeIfFeasible(env, resFn, TypeEval());
			} else {
				// Cannot resolve yet - defer
				Some(makeTypeCompose(a, TypeEval()));
			}
		}
		default: {
			// Other cases - defer composition
			Some(makeTypeCompose(a, TypeEval()));
		}
	}
}

composeRightOverload(env : TypeEnv, a : Type, b : TypeOverload) -> Maybe<Type> {
	// Try to compose with each overload, keep those that work
	ok = filtermap(b.overloads, \o -> composeIfFeasible(env, a, o));
	if (length(ok) == 0) {
		None();
	} else if (length(ok) == 1) {
		// Simplified to single type
		Some(ok[0]);
	} else {
		// Multiple overloads still compatible
		Some(TypeOverload(ok));
	}
}

composeWithEClass(env : TypeEnv, a : Type, eclass : int) -> Maybe<Type> {
	// Compose a type with an equivalence class
	values = getUnionMapValue(env.unionFindMap, eclass);
	if (values == []) {
		// No values yet - defer composition
		Some(makeTypeCompose(a, TypeEClass(eclass)));
	} else {
		// Try to compose with each value in the eclass
		compat = filtermap(values, \v -> composeIfFeasible(env, a, v));
		if (length(compat) == 0) {
			// None compatible
			None();
		} else if (length(compat) == 1) {
			// One compatible
			Some(compat[0]);
		} else {
			// Multiple compatible - create new eclass to hold results
			newClass = makeTypeEClass(env, "");
			setUnionMapValue(env.unionFindMap, newClass.eclass, compat);
			Some(newClass);
		}
	}
}

isPTypeCompose(p : Type) -> bool {
	switch (p) {
		TypeCompose(__, __): true;
		default: false;
	}
}
```

### Unifying types

This is how we structurally unify types:

``` flow
// Unify these types. If `checkOnly` is true, we do not update the eclasses, but only check 
// if they can be unified. Returns true if they can be unified, false otherwise.
unifyType(env : TypeEnv, checkOnly : bool, a : Type, b : Type) -> bool {
	switch (a) {
		TypeName(name1, typars1): {
			switch (b) {
				TypeName(name2, typars2): {
					if (name1 != name2) {
						// We allow unification of upper case names (implicit subtyping), 
						// not lowercase
						isUpperLetter(strLeft(a.name, 1)) && isUpperLetter(strLeft(b.name, 1))
					} else if (length(typars1) != length(typars2)) {
						error("Different number of type parameters");
					} else {
						ok = mapi(typars1, \i, tp1 -> {
							unifyType(env, false, tp1, typars2[i])
						});
						forall(ok, idfn);
					}
				}
				TypeEClass(eclass): bind(eclass, a);
				TypeWord(inputs, outputs): {
					if (inputs == [] && length(outputs) == 1) {
						unifyType(env, false, a, outputs[0])
					} else error("Can not unify a word with a type name");
				}
				TypeOverload(overloads): unifyOverload(env, checkOnly, b, a);
			}
		}

		TypeEClass(eclass1): {
			switch (b) {
				TypeName(name, typars): bind(eclass1, b);
				TypeEClass(eclass2): {
					if (checkOnly) {
						types1 = getUnionMapValue(env.unionFindMap, eclass1);
						types2 = getUnionMapValue(env.unionFindMap, eclass2);
						forall(types1, \t1 -> {
							// This is excessive. We only need to do half, but never mind
							forall(types2, \t2 -> {
								unifyType(env, false, t1, t2)
							})
						});
					} else {
						root = unionUnionMap(env.unionFindMap, eclass1, eclass2);
						true;
					}
				}
				TypeWord(inputs, outputs): bind(eclass1, b);
				TypeOverload(overloads): bind(eclass1, b);
				TypeEval(): bind(eclass1, b);
				TypeCompose(__, __): bind(eclass1, b);
			}
		}

		TypeWord(inputs1, outputs1): {
			switch (b) {
				TypeWord(inputs2, outputs2): {
					unifyTypes(env, checkOnly, inputs1, inputs2) 
					&& unifyTypes(env, checkOnly, outputs1, outputs2);
				}
				TypeName(name, typars): {
					if (inputs1 == [] && length(outputs1) == 1) {
						unifyType(env, false, b, outputs1[0])
					} else error("Can not unify a word with a type name");
				}
				TypeEClass(eclass): bind(eclass, a);
				TypeOverload(overloads): unifyOverload(env, checkOnly, b, a);
				TypeCompose(left, right): {
					leftCheck = \ -> {
						switch (left) {
							TypeWord(inputs2, outputs2): {
								// (inputs1 -> outputs1)   =    (inputs2 -> outputs2) ◦ x
								// then we should unify inputs1 = inputs2
								unifyTypes(env, checkOnly, inputs1, inputs2);
							}
						}
					};
					switch (right) {
						TypeWord(inputs3, outputs3): {
							// (inputs1 -> outputs1)   =    x ◦ (inputs3 -> outputs3)
							// then we should unify outputs1 = outputs3
							leftCheck() && unifyTypes(env, checkOnly, outputs1, outputs3);
						}
						TypeEClass(eclass): {
							switch (left) {
								TypeWord(inputs2, outputs2): {
									// (inputs1 -> outputs1)  =  (inputs2 -> outputs2) ◦ ε
									// Then we should bind ε to 
									// (<ε as outputs2> -> <ε as outputs1>)
									eleft = map(outputs2, \__ -> makeTypeEClass(env, ""));
									eright = map(outputs1, \__ -> makeTypeEClass(env, ""));
									leftCheck() && bind(eclass, TypeWord(eleft, eright));
								}
								default: leftCheck();
							}
						}
					}
				}
			}
		}
	}	
}

bind(eclass : int, type : Type) -> bool {
	if (checkOnly) {
		types = getUnionMapValue(env.unionFindMap, eclass);
		forall(types, \t -> {
			unifyType(env, checkOnly, t, type)
		})
	} else {
		types = getUnionMapValue(env.unionFindMap, eclass);
		canUnify = map(types, \t -> {
			pos = unifyType(env, true, t, type);
			if (pos) {
				unifyPype(env, false, t, type);
				{}
			}
			pos;
		});
		ntypes = sortUnique(arrayPush(types, type));
		setUnionMapValue(env.unionFindMap, eclass, ntypes);
		true;
	}
}
```

### Types of the Standard Library

We have a standard library of functions in the stack language, and using a natural type syntax, here are the types of those:

``` flow
println : (?) -> ();
not : (bool) -> bool;
i2s : (int) -> string;
s2i : (string) -> int;
d2s : (double) -> string;
s2d : (string) -> double;
i2b : (int) -> bool;
b2i : (bool) -> int;
hex2int : (string) -> int;
unescape : (string) -> string;
string2ints : (string) -> [int];
ints2string : ([int]) -> string;
capitalize : (string) -> string;
decapitalize : (string) -> string;
list2array : (List<?>) -> [?];
strlen : (string) -> int;
length : ([?]) -> int;
reverse : ([?]) -> [?];
isBool : (?) -> bool;
isInt : (?) -> bool;
isDouble : (?) -> bool;
isString : (?) -> bool;
isArray : (?) -> bool;
isConstructor : (?) -> bool;
getConstructor : (?) -> string;

&& : (bool, bool) -> bool;
|| : (bool, bool) -> bool;
+ : overload( (int, int) -> int, (double, double) -> double, 
		(string, string) -> string, ([?], [?]) -> [?]);
- : overload( (int, int) -> int, (double, double) -> double);
* : overload( (int, int) -> int, (double, double) -> double);
/ : overload( (int, int) -> int, (double, double) -> double);
% : overload( (int, int) -> int, (double, double) -> double);
<=> : (?, ?) -> int;
== : (? , ?) -> bool;
!= : (? , ?) -> bool;
< : (? , ?) -> bool;
<= : (? , ?) -> bool;
> : (? , ?) -> bool;
>= : (? , ?) -> bool;
getField : (?, string) -> ?;
strGlue : (string, string) -> string;

substring : (string, int, int) -> string;
subrange : ([?], int, int) -> [?];
setField : (?, string, ??) -> ();
```

With this in place, we can do type inference of the stack language. After type inference, we have the types of all words and the program as a whole, as well as a bunch of equivalence classes, each with a number of types inside. From this, we can then postprocess these to infer union-types to capture implicit subtyping.

## Type Inference of the Grammar Language

Type inference of the grammar language is based on the same type language. We will describe the algorithm below, but first let us have a look at the results.

### Inferred Types of the Grammar Language itself

The types of the grammar language are automatically inferred to be this from the grammar alone:

``` flow
Term ::=
	Choice(term1 : Term, term2 : Term),
	Construct(uid : string, string1 : string),
	Negate(term : Term),
	Optional(term : Term),
	Plus(term : Term),
	Precedence(term1 : Term, term2 : Term),
	PushMatch(term : Term),
	Range(char1 : string, char2 : string),
	Rule(id : string, term1 : Term, term2 : Term),
	Sequence(term1 : Term, term2 : Term),
	StackOp(id : string),
	Star(term : Term),
	String(id : string),
	Variable(id : string);
```

### Inferred Types of the Stack Language

Similarly, the type of the stack language is inferred from the grammar alone to this:

``` flow
Poppy ::=
	Command,
	ConstructArity(uid : string, int1 : int),
	Define(word : string, poppy : Poppy),
	Quote(poppy : Poppy),
	Sequence(poppy1 : Poppy, poppy2 : Poppy),
	Set(word : string),
	Value,
	Word(word : string);

Command ::=
	Cons(), Drop(), Dump(), Dup(), Eval(), Ifte(), Nil(), Nop(), Print(), Swap(), While();

Value ::=
	Bool(bool1 : bool),
	Double(double1 : double),
	Int(int1 : int),
	String(string1 : string);
```

Notice we manage to track the types of the `Bool`, `Int`, `Double` constructs after the use of stack language manipulations that do the conversions.

### Type Inference of Grammars

Since we embed the stack language textually inside the grammar language, we have to do a bit of work to type the combination of the languages. The type inference of the grammar language shares the type language, the type environment and the helpers `composeIfFeasible` and unification with the stack language.

We allow the user to define stack-words using `define` inside the grammar after the use of such words. For that reason, the grammar type inference uses a **two-phase algorithm**:

**Phase 1 - Setup (firstPass)**:
The first pass traverses the entire grammar to:
- Find all `Rule(id, term1, term2)` definitions
- Create a fresh equivalence class (eclass) for each rule
- Process all `@stackop` nodes to extract any Poppy `define` statements

This phase doesn't perform full type inference yet—it just sets up the type environment so that rules can reference each other, even with forward references or mutual recursion.

**Phase 2 - Inference (mangoTypesOfRules)**:
The second pass processes rules in topological dependency order:
- For each rule in order, call `grammarType()` (implemented as `mangoType2()`) to infer its type
- Unify the inferred type with the rule's pre-allocated eclass
- Handle recursive rules specially using named union placeholders

This two-phase approach enables forward references and mutual recursion between rules.

#### Topological Ordering

Before type inference, rules must be processed in the right order to handle dependencies. The `topoRules()` function computes this order:

1. **Build dependency graph**: Extract all `Rule(id, term1, term2)` definitions and analyze which rules reference which others (via `Variable(id)` nodes)
2. **Topological sort**: Order rules so that each rule is processed before any rule that depends on it (when possible)
3. **Handle cycles**: For mutually recursive rules, the system detects cycles and processes them specially using named union placeholders

This ensures that when typing rule A that references rule B, we already have an eclass allocated for B (from phase 1), allowing the unification to work correctly.

See `lib/tools/mango/topo.flow` for the implementation of `topoRules()`, `findRules()`, and cycle detection.

``` flow
inferMangoTypes(name : string, env : TypeEnv, t : Term) -> Type {
	// Grab any Stack Language definitions and stuff required for the rules into the type environment
	firstPass(env, t);

	r = findRules(makeTree(), t);
	order = topoRules(t);
	
	typesOfRules(env, makeSet(), order, r);
	types = grammarType(env, t);
	eclass = makeTypeEClass(env, name);
	unionize(env, ref makeSet(), name, eclass.eclass, types);
}

typesOfRules(env : TypeEnv, done : Set<string>, order : [string], r : Tree<string, Term>) -> void {
	if (order == []) {
	} else {
		rule = order[0];
		mtt = lookupTree(r, rule);
		mtt ?? {
			tt = mtt;
			vars = getVariables(makeSet(), tt);
			unknown = differenceSets(vars, done);
			mtype = lookupTree(^(env.words), rule);
			switch (mtype) {
				None(): {
					println("ERROR: Unknown eclass for rule '" + rule + "'");
				}
				Some(etype): {
					eclass = getTypeEClass(etype);
					type = if (containsSet(unknown, rule)) {
						recursiveType(env, eclass, rule, tt)
					} else {
						types = grammarType(env, tt);
						unionize(env, ref makeSet(), rule, eclass, types);
					}
				
					unifyType(env, false, type, etype) |> ignore;
					
					if (isTypeNop(env, type)) {
						// This is required to ensure we do not have too many eclasses.
						env.words := setTree(^(env.words), rule, type);
					}

					newDone = insertSet(done, rule);
					typesOfRules(env, newDone, tail(order), r);
				}
			}
		} : {
			println("ERROR: Unknown rule '" + rule + "'");
		}
	}
}
```

If a rule is recursive, we set up a named placeholder for the type while inferring it. Notice this is different from the stack language, where we use substitution to handle recursion. In the grammar context, it is natural to use a named union placeholder type instead:

``` flow
// Type a recursive rule - if required, we invent a union name for this one
recursiveType(env : TypeEnv, eclass : int, rule : string, tt : Term) -> Type {
	uname = makeUniqueName(env, capitalize(rule));
	placeholder = TypeName(uname, []);

	unifyType(env, false, placeholder, TypeEClass(eclass));
	
	types = grammarType(env, tt);
	unionize(env, ref makeSet(), rule, eclass, types);
}
```

Since we implicitly infer union types for subtyping, we have a helper to do this:

``` flow
// See if these types end up as a union. If so, pick any existing one that works, or make a new one
unionize(env : TypeEnv, seen : ref Set<int>, id : string, eclass : int, types : [Type]) -> Type
```

### Type Inference of Grammar Constructs

The type inference of the grammar constructs is straightforward. We infer the types of each grammar language constructs expressed using our type language. This is different from typing the stack language in that each grammar term can result in a number of types:

``` flow
grammarType(env : TypeEnv, t : Term) -> [Type] {
	switch (t) {
		Choice(term1, term2): {
			// Grab all choices in sequence
			choices = getChoices(t);
			sortUnique(concatA(map(choices, \c -> grammarType(env, c))));
		}
		Construct(uid, int1): {
			typars = generate(0, s2i(int1), \i -> makeTypeEClass(env, ""));
			type = TypeWord(typars, [TypeName(uid, typars)]);

			env.structs := insertSet(^(env.structs), uid);
			[type];
		}
		Negate(term): grammarType(env, term);
		Optional(term): grammarType(env, term);
		Plus(term): grammarType(env, term);
		PushMatch(term): [pstringType()];
		Range(char1, char2): [TypeWord([], [])];
		Rule(id, term1, term2): {
			mtype = lookupTree(^(env.words), id);
			mtype ?? {
				grammarType(env, term2);
			} : {
				[perror("Unknown type of rule '" + id + "'")];
			}
		}
		Sequence(term1, term2): {
			t1 = grammarType(env, term1);
			t2 = grammarType(env, term2);
			if (t1 == []) t2
			else if (t2 == []) t1
			else {
				concatA(map(t1, \tt1 -> {
					map(t2, \tt2 -> {
						mtype = composeIfFeasible(env, tt1, tt2);
						mtype ?? mtype : {
							perror("Cannot compose " + term2string(term1) + " : " + prettyType(env, tt1) + "   with   " + term2string(term2) + " : " + prettyType(env, tt2));
						}
					})
				}))
			}
		}
		StackOp(id): {
			// Parse the op as Poppy and infer the type of that
			poppy = parse(poppyGrammar(), id, PoppyNil());
			findPoppyDefines(env, poppy);
			[poppyType(env, poppy)];
		}
		Star(term): grammarType(env, term);
		String(string1): [TypeWord([], [])];
		Variable(id): {
			mtype = lookupTree(^(env.words), id);
			switch (mtype) {
				None(): [perror("Unknown type of rule " + id)];
				Some(type): [instantiatePolymorphism(env.unique, ref makeTree(), type)];
			}
		}
	};
} 	
```

### Post-Inference Processing

After the initial type inference completes, several post-processing phases refine and finalize the types:

#### Type Elaboration
The `elaboratePType()` function resolves deferred type constructs:
- Resolves equivalence classes (eclasses) to their concrete types
- Filters out recursive eclasses to prevent infinite loops
- Consolidates duplicate types that have the same name
- Composes any deferred `TypeCompose` constructs
- Recursively processes type parameters

See `lib/tools/poppy/type/elaborate.flow` for the implementation.

#### Union Extraction
The `extractImplicitUnions()` and `unionize()` functions identify and name implicit union types:
- Traverse all types looking for eclasses with multiple possible types
- For each such eclass, create a named union type
- Use suggested names from `eclassNames` to pick good union names (e.g., `Term` rather than `Union_42`)
- Apply naming heuristics based on capitalization, common prefixes, and alphabetical sorting
- Avoid self-referential unions by filtering

See `lib/tools/poppy/type/unions.flow` for the implementation.

#### Union Simplification
The `simplifyPUnions()` function removes redundant unions:
- Identifies cases where one union is a subset of another
- Merges or eliminates redundant union definitions
- Produces cleaner, more readable final types

See `lib/tools/poppy/type/simplify.flow` for the implementation.

#### Field Name Generation
Struct field names are automatically generated based on type information:
- For named types: use humpCase of the type name (e.g., `String` → `string1`)
- For arrays: pluralize the element type (e.g., `[Term]` → `terms`)
- Collect suggested names from eclass name tracking
- Handle duplicates by appending numbers (`string1`, `string2`, etc.)

See `lib/tools/mango/type_driver.flow` (function `pfieldName`) for the implementation.

This multi-phase approach produces clean, readable type definitions with meaningful names for unions and struct fields.

## Standard Library Integration

The type system integrates with the RunCore standard library to provide built-in types and operations. When the type environment is initialized via `makePTypeEnv()`, it automatically loads core types from the RunCore library:

```flow
makePTypeEnv() -> PTypeEnv {
    coreTypes = getRunCoreTypes();
    pcore = mapTree(coreTypes, coreType2PType);
    // Initialize env.words with pcore...
}
```

This provides standard types and operations like:
- Basic types: `bool`, `int`, `double`, `string`, `array`
- List operations: `cons`, `nil`, conversions
- String operations: `s2i`, `s2d`, `i2s`, `d2s`, `unescape`
- Comparison operators: `==`, `!=`, `<`, `<=`, `>`, `>=`, `<=>`
- Arithmetic operators: `+`, `-`, `*`, `/`, `%` (with overloading for int/double/string)
- Boolean operators: `&&`, `||`, `not`
- Type checking: `isBool`, `isInt`, `isDouble`, `isString`, `isArray`, `isConstructor`

See `lib/tools/poppy/type/core.flow` for the `coreType2PType()` conversion and `lib/tools/runcore/runcoretypes.flow` for the RunCore type definitions.

## URL Parameters for Type Generation and Debugging

The implementation supports several URL parameters for controlling type generation and debugging output:

| Parameter | Values | Description |
|-----------|--------|-------------|
| `types` | `1`, `2`, or `3` | Generate type definitions: `1` = Melon format (.melon), `2` = Flow format (.flow), `3` = TypeScript format (.ts) |
| `verbose` | `0`-`4` | Control debug output verbosity: `0` = quiet, `1` = basic, `2` = detailed, `3`-`4` = very detailed |
| `gringoops` | `1` | Generate GringoOps helper functions for AST manipulation |
| `typeprefix` | string | Prefix to strip from type names when generating field names |

**Examples:**
```
# Generate Melon type definitions
?types=1

# Generate TypeScript definitions with verbose output
?types=3&verbose=2

# Generate Flow types and GringoOps
?types=2&gringoops=1
```

These parameters are processed in `lib/tools/mango/type_driver.flow` after type inference completes.

## Conclusion

The full grammar language also supports grammar includes, grammar functions and applications, as well as precedence & associativity constructs. Since these are lowered into the constructs above, they do not have influence on the type inference. 

There is also both an interpreter & optimizing compiler for both languages, as well as another compilation target to a VS Code plugin to get syntax highlighting using compilation to regular expressions for the lexical parts.

In the end, we have a practical grammar language that can do the following from just the grammar itself:

1. Support writing succinct and clear grammars for both lexing and parsing
2. Provide a standard library of common, reusable grammar constructs
3. Use a Turing-complete stack language for semantic actions
4. Automatically infer the type definitions for the corresponding AST
5. Generate type definitions in multiple formats (Melon, Flow, TypeScript)
6. Get an efficient parser for the language that constructs the strongly typed AST
7. Get a functional VS Code plugin for the language as well
