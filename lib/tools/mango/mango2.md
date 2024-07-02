# Bootstrapping Mango

Our goal is to have an implementation of the Mango grammar language, so we can use it to define other programming languages. The first step is to define this grammar language using Mango itself.

But wait! how can we write the grammar language in the grammar language itself? It is a chicken and egg situation: we cannot implement the grammar language in itself, before we have it.  On the other hand, it nevertheless makes sense to write a grammar for it for several reasons:  It is still a good way to specify concisely the language.  Later when we do have a working parser generator, we *can* use the grammar to reimplement itself.  At that point, future changes to the grammar language *can* be implemented in the grammar language itself!

Once we have a grammar for Mango, then we will manually translate that to a corresponding Abstract Syntax Tree (AST) data structure - i.e. let ourselves be the parser. After this, a simple interpreter of the Mango AST will allow us to parse Mango itself, and then we can proceed from there, and we have completed *bootstrapping*.

![mango with butterflies, Damien Hirst](images/DALL·E 2022-08-18 10.50.55 - mango with butterflies, Damien Hirst.png)

## Grammar for Mango in Mango

The grammar for Mango is defined by *terms*, and captured here in Mango itself:

``` tools/mango/mango.mango
term = 
	term "|>" ws <term 						Precedence/2
	|> term "|" ws <term 					Choice/2
	|> term <term							Sequence/2
	|> "$" ws term							PushMatch/1
	|> "<" ws term							Lower/1
	|> "#" ws term							Error/1
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
		| "@" ws id "<" ws term ">" ws "=" ws term ";" ws term	GrammarFn/4
		| "@" ws id "<" ws term ">" ws		GrammarCall/2
		| "@" ws id !"<"					StackOp/1
		| "@" ws stringq					StackOp/1
```

The terms of the grammar should be clear - the only tricky bit is the convention of following lexical constructs by the whitespace rule `ws`. Whitespace is what we call the use of spaces, tabs and newlines in text files to format the grammar in a nice way. The whitespace is ignored and should not have an impact on the meaning of the grammar in the AST.

The lexical terms are also defined in Mango, and go like this:

``` tools/mango/mango.mango
id = $bid ws;
bid = ('a'-'z' | '_') (alnum)*; // Initial lower case only
uid = $('A'-'Z' alnum*) ws; 	// Initial upper case only
alnum = 'a'-'z' | 'A'-'Z' | '_' | '0'-'9';

int = '0'-'9'+;

string = '"' $(!'"' anychar)* '"' ws;
stringq = "'" $(!"'" anychar)* "'" ws;

char = "'" $("0x" hexdigit+ | anychar) "'" ws;

hexdigit = '0'-'9' | 'a'-'f' | 'A'-'F';
```

The lexing of other primitive tokens is arguably a bit harder to follow, but it is a benefit that Mango is used for both the grammatical structure and the lexing. In addition to normal whitespace characters, the grammar also allows us to use C++-style line comments with `// comment` and C-style comments like `/* comment */`:

``` tools/mango/lib/whitespace.mango
ws = s*;
s = cs+;
cs = " " | "\t" | "\n" | "//" (!"\n" anychar)* "\n" | "/*" (!"*/" anychar)* "*/" | "\r";
anychar = '0x0000'-'0xffff';
```

The final grammar can now be defined. We have to accept white-space at the start of the file, but otherwise, the grammar is nothing but a term:

``` tools/mango/mango.mango
grammar = ws term;
grammar
```

The three parts together are 45 lines in total and handles all aspects of the parsing Mango itself, including handling white-space with C-style comments and capturing the result as an AST. 

Hopefully, this demonstrates the succinctness and power of the Mango grammar language itself.

### Simplified grammar

The Mango grammar above use the full range of constructs, which makes it easy to read and write. However, to be able to bootstrap the system and use it for parsing, it is helpful to reduce it to using fewer constructs, that are easier to interpret and parse.

If we unroll the precedence operations used, and optimize the grammar, the result is the same grammar, but using fewer constructs:

@run<flowcpp --batch mango/mango.flow -- grammar=mango/mango.mango savereduced=out/mango_reduced.mango savegrammar=mango/mango_grammar.flow savemelon=mango/mango_grammar.melon types=1>
``` out/mango_reduced.mango
term = term1 ("|>" ws term Precedence/2)?;
term1 = term2 ("|" ws term1 Choice/2)?;
term2 = term3 (term2 Sequence/2)?;
term3 = "$" ws term4 PushMatch/1 | term4;
term4 = "@" ws id "<" ws term ">" ws GrammarMacro/2 | StackOp/1 | term5;
term5 = "<" ws term6 Lower/1 | term6;
term6 = "#" ws term7 Error/1 | term7;
term7 = term8 ("*" ws Star/1)?;
term8 = term9 ("+" ws Plus/1)?;
term9 = term10 ("?" ws Optional/1)?;
term10 = "!" ws term11 Negate/1 | term11;
term11 = "(" ws term ")" ws | uid "/" ws int Construct/2 | string String/1 | 
  char "-" char Range/2 | stringq String/1 | id "=" ws term ";" ws term Rule/3 | 
  Variable/1;
```

Later, we will see how this output can be automatically generated once we have the Mango compiler working, but for now, it allows us to bootstrap the Mango parser by implementing the subset of constructs used in this grammar.

This reduced grammar does *not* use these constructs:

- `|>` for precedence 
- `@` for stack operations or macros
- `<` for lowering of precedence
- `#` for error handling

so we can skip the implementation of those in our bootstrapping effort.

## The Abstract Syntax Tree for Mango

Each construct in the final AST is constructed using the `Construct/3` constructors. For each construct in the grammar, a corresponding structure is constructed where we capture the parameters. Here we write the corresponding data types by hand:

``` tools/mango/mango_types.melon
Term ::=
	Choice(term1 : Term, term2 : Term),
	Construct(uid : string, string1 : string),
	Error(term : Term),
	GrammarCall(id : string, term : Term),
	GrammarFn(id : string, term1 : Term, term2 : Term, term3 : Term),
	Lower(term : Term),
	Negate(term : Term),
	Optional(term : Term),
	Plus(term : Term),
	Precedence(term1 : Term, term2 : Term),
	PushMatch(term : Term),
	Range(char1 : string, char2 : string),
	Rule(id : string, term1 : Term, term2 : Term),
	Sequence(term1 : Term, term2 : Term),
	StackOp(string1 : string),
	Star(term : Term),
	String(string1 : string),
	Variable(id : string);
```

These types define the valid structures that can be produced by parsing a grammar, and allow us to concentrate on the essentials in a nice structure. 

Advanced note: Later, we will see how these types can be automatically generated from the grammar itself. That is done using type evaluation of the grammar on a stack machine. That is worthwhile since it brings type safety, and it allows us to write code less by hand. When that is done, the result matches the above.

### Manual AST constructed for Mango

Now, we will translate the reduced Mango grammar to the AST structures.
If we look at the first line, `term = term1 ("|>" ws term Precedence/2)?;`, we can manually construct the corresponding data structure using constructors, and it becomes something like this:

``` melon
Rule("term", 
	Sequence(
		Variable("term1"), 
		Optional(
			Sequence(
				String("|>"), 
				Sequence(
					Variable("ws"), 
					Sequence(
						Variable("term"), 
						Construct("Precedence", "2")
					)
				)
			)
		)
	),
	...
)
```

Doing this is tedious, but once we have done it, we will have the grammar for Mango itself as a data structure, and the next step is to use this to parse. Later, once we have bootstrapped the parser, we can use Mango itself to reconstruct the same and improve using the parser and grammar itself completing the bootstrap.

## Interpreting Mango

The following code interprets the Mango AST to parse a string according to a given grammar. It works by constructing an environment, where we collect rules, the stack of results, as well as bookkeeping to make the parse possible. The environment is defined by this data structure:

``` melon
Env(
	// The text string we are parsing
	input : string,
	// The rules defined in the grammar
	names : Tree<string, Term>,
	// The result stack used for semantic actions
	result : List<?>,
	// The current parsing position in the input
	i : int,
	// Did parsing fail?
	fail : bool,
);
```

The structure of the parser is an interpreter, which implements the specific operations using this data structure. It looks like this at the top level where we *dispatch* on the current term, and the result is a new, updated environment:

``` melon
parse(env : Env<?>, t : Term) -> Env<?> {
	switch (t) {
		...
		// Here, we will interpret each AST construct 
		// and return a new, updated environment
		...
	}
}
```

Our grammar to parse is defined as a big data structure of terms, and the parse thus works by starting at the root of the AST and the start of the text. The idea is that we parse all the terms in the AST from top to bottom, moving the input position along, and either ends with a successful result on the stack, or a failure. 

The current position of the string we are parsing is known as `env.i`, and at each step, we have to match the current term at that point. The term can be any of the AST nodes in our grammar, so we have to implement all of them in the `switch` above.

If the term matches the current position, we move the `env.i` position forward according, and consider the parse successful. If the term does NOT match the current position, we end the parse with the `env.fail` flag set to `true`.

As we will see, each operator is simple to implement, but the total magic comes from the *compositionality* of them in the recursive use according to the structure of the grammar AST.

First, let us implement the matching of strings:

``` melon
	String(text): {
		if (strContainsAt(env.input, env.i, text)) {
			ni = env.i + strlen(text);
			Env(env with i = ni)
		} else {
			Env(env with fail = true)
		}
	}
```

We check if the text in the string occurs at the current parsing position, and if so, move the parsing position `i` forward with the length of the text, and the parse is successful. If not, we fail the parse by setting the `fail` flag.

Note: The `Env(env with i = ni)` is syntax for a special constructor, where we make a new `Env` struct by copying all the fields of `env`, except for the `i` field, which is initialized to `ni` instead. This is a functional way to handle "state": Construct a new value, instead of mutating the existing.

Similarly, here is the code for the character range parsing where we check that the current character is within the character range:

``` melon
	Range(lower, upper): {
		code = getCharAt(env.input, env.i);
		if (lower <= code && code <= upper) {
			ni = env.i + 1;
			Env(env with i = ni)
		} else {
			Env(env with fail = true)
		}
	}
```

A sequence works by first parsing the left hand side using recursion, and if that succeeds, then parse the right hand side:

``` melon
	Sequence(left, right): {
		lenv = parse(env, left);
		if (lenv.fail) lenv else parse(lenv, right);
	}
```

A choice is similar, except that if the first fails, we try the second, right-hand term:

``` melon
	Choice(left, right): {
		lenv = parse(env, left);
		if (lenv.fail) parse(env, right) else lenv
	}
```

Since we always construct a new environment `Env` in the recursive calls to `parse`, (rather than mutating the `env` value) we do not have to "undo" any changes done in the `left` choice if it fails. We can just refer back to the `env` as it is in the recursive call to the `right` choice. This is a great benefit of functional code: You do not have worry about side effects and mutation, but can think more mathematically about the code.

The star operator works by repeatedly parsing itself until it fails:

``` melon
	Star(term): {
		senv = parse(env, term);
		if (senv.fail) env else parse(senv, t)
	}
```

The plus is modelled as a sequence of the term and then a star:

``` melon
	Plus(term): {
		senv = parse(env, term);
		if (senv.fail) senv else parse(senv, Star(term))
	}
```

The optional `?` operator checks if the term parses, and if so keeps the result. If not, we just proceed without failing:

``` melon
	Optional(term): {
		senv = parse(env, term);
		if (senv.fail) env else senv
	}
```

The `!` negate operator checks that we do *not* parse the child, and if so, succeed. Otherwise, we fail:

``` melon
	Negate(term): {
		senv = parse(env, term);
		if (senv.fail) env else Env(env with fail = true)
	}
```

The let-bindings `id = binding; body` and rule reference `id` go together. When we encounter a let-binding, we record the rule binding in the environment, and then parse the body:

``` melon
	Rule(id, binding, body): {
		nenv = Env(env with names = setTree(env.names, id, binding));
		parse(nenv, body);
	}
```

When we see a reference to a rule `id`, we look it up in the environment, and parse using the binding:

``` melon
	Variable(id): {
		if (containsKeyTree(env.names, id)) {
			parse(env, lookupTreeDef(env.names, id, t))
		} else {
			println("Unknown name: " + id);
			Env(env with fail = true);
		}
	}
```

For semantic actions, the `$` operator captures the string matched, and pushes it to the result stack:

``` melon
	PushMatch(term): {
		starti = env.i;
		rec = parse(env, term);
		if (rec.fail) {
			rec;
		} else {
			matched = substring(env.input, starti, rec.i - starti);
			Env(rec with result = Cons(matched, rec.result))
		}
	}
```

Finally, to implement the constructors, we pop the arguments according to the arity using a helper function called `popNStack`, and push the resulting structure to the result stack:

``` melon
	Construct(id, arity): {
		envArgs : Pair<List<?>, [?]> = popNStack(env.result, arity);
		out = construct(id, envArgs.second);
		Env(env with result = Cons(out, envArgs.first))
	}
```

This completes the operations used in the reduced Mango grammar, so if we rig this up, we can use it to parse the reduced grammar itself. We do this by making an initial environment with the input to parse, and then invoke the interpreter:

``` melon
env = Env(input, makeTree(), 0, false);
result = parse(env, grammar);
if (result.fail || result.i != strlen(input)) {
	println("Could not parse at " + i2s(result.i));
} else {
	println("Result is " + result.result);
}
```

To use this, we take the hand-written AST as structures, and use that to parse the reduced Mango grammar itself. When we do that, we can verify that the result works by parsing itself using the result:

``` cmd
	mango mango_reduced.mango savegrammar=mango_grammar.melon
```

If we do this twice, and the result is stable, we have successfully bootstrapped the reduced Mango language in less than 100 lines of code, plus 45 lines for the grammar.

TODO: Do dead-code elimination in Mango to remove dead rules
TODO: Add warning if the grammar is wrong: `"read" | "read_write"`. Here, we never get to `"read_write"`.

## Expanding precedence and lowering

A key piece missing is to implement the automatic lowering of precedence `|>` construct as described in the previous chapter. After parsing the grammar, we will do this expansion using the function `expandPrecedence`, which will recursively expand any `Precedence` constructs in rules:

``` tools/mango/precedence.melon
expandPrecedence(t : Term) -> Term {
	switch (t) {
		Choice(term1, term2): Choice(expandPrecedence(term1), expandPrecedence(term2));
		Construct(uid, int_0): t;
		Error(term): Error(expandPrecedence(term));
		GrammarFn(id, term1, term2, term3): {
			println("Did not expect grammar fn here: " + id);
			t;
		}
		GrammarCall(id, term): t;
		Lower(term): {
			println("ERROR: Did not expect < outside rule");
			expandPrecedence(term);
		}
		Negate(term): Negate(expandPrecedence(term));
		Optional(term): Optional(expandPrecedence(term));
		Plus(term): Plus(expandPrecedence(term));
		Precedence(term1, term2): {
			println("ERROR: Do not expect precedence outside rule");
			Choice(expandPrecedence(term1), expandPrecedence(term2));
		}
		PushMatch(term): PushMatch(expandPrecedence(term));
		Range(char1, char2): t;
		Rule(id, term1, term2): {
			// Precedence expansion is only defined inside rules
			expandPrecedenceInRule(id, term1, expandPrecedence(term2), 0)
		}
		Sequence(term1, term2): Sequence(expandPrecedence(term1), expandPrecedence(term2));
		StackOp(id): t;
		Star(term): Star(expandPrecedence(term));
		String(stringq): t;
		Variable(id): t;
	}
}
```

This function will recursively go down all terms and expand all precedence inside rules, as well as report errors in case we use precedence or lowering outside a rule.

The expansion itself is handled by `expandPrecedenceInRule`. This function requires the name `id` of the rule we are working on so we can detect recursion, what `term` we need to expand precedence in, the `body` for the expanded rule, and finally what precedence `level` we are currently at, starting at 0.

First, we construct the expanded name of the rule according to the current level, and then check if we have a precedence construct or not. If we do not, then we are done with the current rule, and just return the rule with new name.

``` tools/mango/precedence.melon
expandPrecedenceInRule(id : string, term : Term, body : Term, level : int) -> Rule {
	// What is the new name of the rule?
	newid = getRuleLevelId(id, level);
	switch (term) {
		default: {
			// No precedence in this rule, so expand any other nested rules
			// and reconstruct the rule with the new name
			nterm = expandPrecedence(term);
			Rule(newid, nterm, body)
		}
```

Here, `getRuleLevelId` is a simple helper that appends the precedence number to the rule name, except for level 0:

``` tools/mango/precedence.melon
getRuleLevelId(id : string, level : int) -> string {
	id + (if (level == 0) "" else i2s(level));
}
```

If we do find a precedence relation in our rule, we need to expand recursive calls and construct a choice. The following code does this:

``` tools/mango/precedence.melon
		Precedence(left, right): {
			// Replace recursive calls with the nest level, except mid-recursion
			nleft = replaceRecursion(id, level, false, false, left);
			// Construct a new right hand side
			nright = Variable(getRuleLevelId(id, level + 1));
			// Construct the final rule at this level
			rewritten = switch (nleft) {
				Sequence(t1, t2): {
					if (t1 == nright) {
						Sequence(t1, Optional(t2))
					} else {
						Choice(nleft, nright);
					}
				}
				default: Choice(nleft, nright);
			}
			Rule(newid, 
				rewritten,
				expandPrecedenceInRule(id, right, body, level + 1)
			)
		}
	}
}
```

To understand this code, let us look at a simple example:

``` mango
term = term "*" |> more;
```

The left hand side of the precedence construct is `term "*"`. This is called `left` in the code above. First, we call `replaceRecursion` with this value. This function replaces recursion inside the term with the rule at the next level, unless it is mid-recursion. In our case, `term` is left-recursive, and we get `term1 "*"` as the result from `replaceRecursion`. The left hand side can now be constructed as `term1 "*" | term1`, while the right hand side becomes the new rule at the next level, and the final result is:

``` mango
term = term1 ("*") | term1;
term1 = more;
```

The tricky part left is to understand how to replace the recursive calls to the next level. To do this, we use `replaceRecursion`. This takes the name of the recursive calls as `recid` and what precedence `level` we are currently at. 

To decide whether a recursive call is left, right or middle recursion, we use two bools `somethingBefore` and `somethingAfter`. These track whether we could have seen any tokens before or after the current term `t`.

``` tools/mango/precedence.melon
// Replace left and right recursion with the recid at the next level
replaceRecursion(recid : string, level : int, somethingBefore : bool, somethingAfter : bool, t : Term) -> Term {
```

This function works by recursively replacing `Variable` occurrences with the next level, unless it is middle-recursion:

``` tools/mango/precedence.melon
	switch (t) {
		Variable(id): {
			if (id == recid) {
				// Recursive call found
				if (!somethingBefore || !somethingAfter) {
					// Left or right recursion. Replace with next level
					newid = getRuleLevelId(id, level + 1);
					Variable(newid);
				} else {
					// Middle-recursion, we keep as is
					t;
				}
			} else t;
		}
```

With this in place, it is simple to implement the `<` lower construct, which "keeps" a recursive call at the same level by pretending we are a level above:

``` tools/mango/precedence.melon
		Lower(term): {
			if (somethingBefore && somethingAfter) {
				replaceRecursion(recid, level, false, false, term);
			} else {
				replaceRecursion(recid, level - 1, somethingBefore, somethingAfter, term);
			}
		}
```

To be able to track whether we are left- and right-recursive, we check sequences for any tokens before and after each side:

``` tools/mango/precedence.melon
		Sequence(term1, term2): {
			left = replaceRecursion(recid, level, somethingBefore, canBeMatched(term2) || somethingAfter, term1);
			right = replaceRecursion(recid, level, somethingBefore || canBeMatched(left), somethingAfter, term2);
			Sequence(left, right);
		}
```

The `canBeMatched` helper determines if a term can match a token or not. It works by returning `true` if the construct can somehow match a `String` or `Range`:

``` tools/mango/precedence.melon
// Could this term match something concrete?
canBeMatched(t : Term) -> bool {
	switch (t) {
		Range(char1, char2): true;
		String(stringq): true;
		Variable(id): true; // We assume all rules are something, not epsilon
		Construct(uid, int_0): false;
		GrammarFn(id, term1, term2, term3): false;
		GrammarCall(id, term): false; // Assume these are expanded
		Negate(term): false;
		StackOp(id): false;
		Error(term): switch (term) {
			Negate(nterm): false;
			default: canBeMatched(term);
		}
		Lower(term): canBeMatched(term);
		Optional(term): canBeMatched(term);
		Plus(term): canBeMatched(term);
		PushMatch(term): canBeMatched(term);
		Star(term): canBeMatched(term);
		Rule(id, term1, term2): canBeMatched(term2);
		Choice(term1, term2): canBeMatched(term1) || canBeMatched(term2);
		Precedence(term1, term2): canBeMatched(term1) || canBeMatched(term2);
		Sequence(term1, term2): canBeMatched(term1) || canBeMatched(term2);
	}
}
```

With this in place, we can add the precedence expansion to the parser, and verify that we get the same grammar as when we expanded the Mango grammar by hand. When we do, we find that it is the same, except for optimizations. Consider another example from an expression grammar:

``` mango
exp = exp ("+" exp)+ |> more;
```

With the above, we get:

``` mango
exp = exp1 ("+" exp1)+ | exp1;
exp1 = more 
```

However, this can be optimized further to give:

``` mango
exp = exp1 ("+" exp1)*;
exp1 = more 
```

We will see how this is achieved using rewrite rules later.

## Implementing macros and imports

The final pieces of functionality in the core parser are the functions and imports. They are implemented by doing a lowering phase before we interpret the grammar.

It works by recording all grammar functions as `MangoMacro` structures with a list of arguments and the body to expand to into the `defines` tree:

TODO: Update this implementation to grammar macros
``` tools/mango/macros.melon
MangoMacro : (args : [string], body : Term);

expandMangoMacros(defines : ref Tree<string, MangoMacro>, t : Term) -> Term {
	rec = \tt -> expandMangoMacros(defines, tt);
	switch (t) {
		GrammarMacro(id, term): {
			if (id == "define") {
				// Deconstruct the three parts into tname, args and the body
				switch (term) {
					Sequence(tname, rest): {
						switch (rest) {
							Sequence(targs, body): {
								name = getVariableName(tname);
								args = map(getSequence(targs), getVariableName);
								// We are ready to record the macro definition
								defines := setTree(^defines, name, MangoMacro(args, body));
								// The definition "disappears"
								String("");
							}
							default: {
								println("Error: Define expects @define<name (args) body>");
								t;
							}
						}
					}
					default: {
						println("Error: Define expects @define<name (args) body>");
						t;
					}
				}
```

When we see a use of a macro, we look it up in the `defines` tree, and expand the body after binding the names to the arguments:

``` tools/mango/macros.melon
			} else if (containsKeyTree(^defines, id)) {
				// Find the macro definition
				macro = lookupTreeDef(^defines, id, MangoMacro([], term));
				args = getSequence(term);
				// Bind the arguments as the given names
				ndefines = foldi(args, ^defines, \i, acc, arg -> {
					setTree(acc, macro.args[i], MangoMacro([], arg))
				});
				// Expand in the body
				expandMangoMacros(ref ndefines, macro.body);
```

This relies on `@name` to be expanded to the corresponding value, and thus we make sure `StackOp` does exactly that:

``` tools/mango/macros.melon
		StackOp(id): {
			if (containsKeyTree(^defines, id)) {
				macro = lookupTreeDef(^defines, id, MangoMacro([], t));
				macro.body;
			} else {
				t;
			}
		}
```

The result we can now use the `@list<term separator>` macro and friends to reduce repetition and increase clarity of our grammars.

The last thing we need to do is to handle the `@include` macro:

``` tools/mango/macros.melon
			} else if (id == "include") {
				// Extract the name of the include
				path = getVariableName(term);
				// Read the file
				grammar = getFileContent(resolveMangoPath(path + ".mango"));
				// Parse it
				include = mangoParse(mangoGrammar(), grammar, String(""));
				// Process this to grab any defines it might have
				expandMangoMacros(defines, include);
```

We resolve includes into a real file path with a small helper. It just checks if the file is in the Mango standard library:

``` tools/mango/macros.melon
resolveMangoPath(p : string) -> string {
	if (fileExists(p)) p
	else if (fileExists("mango/lib/" + p)) "mango/lib/" + p
	else {
		println("Can not find include " + p);
		p;
	}
}
```

With that in place, we can now have common lexical constructs such as white-space, ids, integers, doubles and strings in a standard Mango library and reference them using `@include` increasing reuse and consistency.

## Improving error handling

Next, to get to a production state, we will add better error handling - in particular, we will keep track of the furthest successful parse, so error reports can be pointed to the last place where an error occurred as `maxi` and keep a tree of errors from the error construct as `errors` in the parsing environment:

``` tools/mango/mango_interpreter.melon
MEnv : (
```
```	melon
	...
```
``` tools/mango/mango_interpreter.melon
	// What is the longest we have parsed?
	maxi : int,
	// What errors did we get?
	errors : Tree<int, string>,
```
``` melon
	...
);
```	

The `maxi` position is kept up to date whenever we move the `i` position forward in lexical strings:

``` tools/mango/mango_interpreter.melon
					ni = env.i + strlen(text);
					MEnv(env with i = ni, maxi = max(env.maxi, ni))
```

We also remember the maximum position whenever there are different paths using this helper:

``` tools/mango/mango_interpreter.melon
maxPos(e : MEnv<?>, o : MEnv<?>) -> MEnv<?> {
	MEnv(e with maxi = max(e.maxi, o.maxi));
}
```

As an example, this is how we change the choice construct to keep track of the farthest we have parsed:

``` tools/mango/mango_interpreter.melon
		Choice(left, right): {
			lenv = parse(env, left);
			if (lenv.fail) parse(maxPos(env, lenv), right) else lenv
		}
```

The `env.errors` field contains a tree of errors from string index to error message as detected by the `Error` construct `#e`. This is interpreted like this with a branch for superfluous elements and another for missing elements:

``` tools/mango/mango_interpreter.melon 
		Error(term): {
			switch (term) {
				Negate(nterm): {
					senv = parse(env, nterm);
					if (senv.fail) {
						MEnv(senv with fail = false);
					} else {
						error = "Superfluous " + summarizeTerm(nterm);
						MEnv(senv with errors = setTree(env.errors, env.i, error));
					}
				}
				default: {
					senv = parse(env, term);
					if (senv.fail) {
						error = "Expected " + summarizeTerm(term);
						MEnv(senv with fail = false, errors = setTree(env.errors, env.i, error));
					} else {
						senv;
					}
				}
			}
```

With this in place, we can point to exactly where in the input string any parse error happens and wrap that up in a nice helper `mangoParse`, which takes a grammar, an input string, as well as a default value when the parse fails. This function will parse the input, as well as print any parsing errors we find, and return the final result:

``` tools/mango/mango_parse.melon 
mangoParse(grammar : Term, content : string, def : ?) -> ? {
	env = parseMango(grammar, content, \n : string, vals -> {
		makeStructValue(n, vals, def);
	});

	// Print any errors we collected with the Error construct first:
	foldTree(env.errors, 0, \pos, error, acc -> {
		println(error + " at line " + getLinePos(content, pos, 1, 0));
	});
	// If we failed the parse, or did not parse everything, print an error 
	if (env.fail || env.i < strlen(content)) {
		println("Failed parsing at pos " + i2s(env.maxi) + ", line " + getLinePos(content, env.maxi, 1, 0));
		def;
	} else {
		headList(env.result, def);
	}
}
```

### Resolving indexes into lines and columns

We use an index `i` into the input string while parsing, but it is useful to report errors using line and columns numbers. Also, it is helpful to include the text of the line with the error when reporting errors. This is exactly what `getLinePos` does:

``` tools/mango/mango_parse.melon 
getLinePos(c : string, pos : int, line : int, i : int) -> string {
	if (i >= strlen(c)) {
		// The position is beyond the end of the file. Give up
		i2s(line) + ":\n";
	} else {
		// Find the next line break
		eol = strRangeIndexOf(c, "\n", i, strlen(c));
		if (eol == -1) {
			// We reached the end of the file.
			i2s(line) + ":" + i2s(pos - i + 1) + ":\n" + substring(c, i, strlen(c));
		} else if (eol >= pos) {
			// We have the position on this line, great!
			i2s(line) + ":" + i2s(pos - i + 1) + ":\n" + substring(c, i, eol - i);
		} else {
			// We need to go further - go to the next line
			getLinePos(c, pos, line + 1, eol + 1);
		}
	}
}
```

It checks to see if we have reached the position `pos` desired, while keeping track of what line we are at with the `line` argument. It recursively calls itself for each line, until we find it or are at the end of the file.

With this, we have finally completed the implementation of our parser generator and provided a helpful function `mangoParse`. Mango allows very short and clear specification of production quality grammars with typed AST construction. The grammars are very close to pseudo-code, but still work. They allow natural solution of the tricky problems of precedence and associativity, and use a simple stack-based model for semantic actions. Experience has shown that this is indeed a nice grammar language, and we will be using it throughout the book.
