# The Ripe Mango

This chapter is not done, but should cover how to make pretty printing and a VS code plugin for syntax highlighting from Mango grammars.

![self portrait of ripe mango, basquiat](images/DALL·E 2022-08-18 10.19.35 - self portrait of ripe mango, basquiat.png)

## Syntax highlighting

When programming, we typically use an Integrated Development Environment (IDE). This is a program which allows us to edit, save and run our programs. An IDE provides a lot of useful features that help productivity, and one of the most important is *syntax highlighting*. This is the process of colorizing and styling the program to enhance readability.

![VS Code with syntax highlighting for Mango](images/vscode.png)

In this section, we will implement automatic compilation of Mango grammars into syntax highlighting definitions, which can be used by VS Code and other editors. Thus, the idea is that any grammar we write with Mango can easily be compiled into a VS code plugin which will add syntax highlighting for that language.

The syntax highlighting file used by VS Code is based on regular expressions. Such regular expressions are associated with a highlighting class, or font style, which defines how tokens matching the regular expression are presented in the IDE. Thus, our job is to compile PEG rules into regular expressions for the given styles.

This problem is impossible in general, since regular expressions are not as powerful as PEG parsers. However, since VS Code only supports regular expressions for highlighting anyways, our job will be done if we can compile our PEG grammars into suitable regular expression for the effectively lexical terms of our grammars.

### Mapping rules to syntax highlighting classes

The first step is to define the mapping from rules in our grammar to the classes. We will do that using a `@highlight` function which takes a rule id, and then a class for what style to use for things that match the rule. The function itself is defined to result in the empty string, so it does not affect the grammar itself where it is used:

``` tools/mango/lib/highlight.mango
@highlight<rule class> = "";
```

That allows us to include a range of definitions to set up the syntax highlighting of a grammar. Here are the corresponding definitions for the Mango grammar itself:

``` tools/mango/mango.mango
@include<highlight>
@highlight<id "variable.parameter">
@highlight<uid "entity.name.function">
@highlight<int "constant.numeric">
@highlight<string "string.quoted.double">
@highlight<stringq "string.quoted.single">
@highlight<char "constant.character">
@highlight<ws "comment.block">
```

The names of the classes follow a [naming convention](https://macromates.com/manual/en/language_grammars#naming_conventions) used by VS Code and other editors.

Our goal is now to construct a `syntaxes\mango.tmLanguage.json` file according to the VS Code standard. As an example, let us see how the `id` and `uid` rules can be converted to regular expressions. The rules looks like this in the original Mango grammar:

``` mango
id = $('a'-'z' alphanum*) ws;  	// Initial lower case only
uid = $('A'-'Z' alphanum*) ws; 	// Initial upper case only
alphanum = 'a'-'z' | 'A'-'Z' | '0'-'9' | '_';
```

The syntax of regular expressions is different from PEG, and in particular does not support named rules. Thus, first we inline the `alphanum` rule and drop the irrelevant `$()` matching construct. Also, notice that `ws` is marked as the whitespace rule in the grammar using the `@highlight<ws "comment.block">` definition. A useful heuristic is to ignore whitespace in our highlighting, and we end up with this simplified grammar:

``` mango
id = 'a'-'z' ('a'-'z' | 'A'-'Z' | '0'-'9' | '_')*;
uid = 'A'-'Z' ('a'-'z' | 'A'-'Z' | '0'-'9' | '_')*;
```

This is now ready to be converted into regular expression syntax. Here is a brief comparison of PEG syntax with the correspond syntax as a regular expression we can use as a key:

|Construct|PEG|Regular expression|
|------|----|----|
|String|`"a"`|`a`|
|Range|`'a'-'z'`|`[a-z]`|
|Sequence|`"a" "b"`|`ab`|
|Optional|`"a"?`|`a?`|
|Repeats|`"a"+ "a"*`|`a+ a*`|
|Negation|`!"a"`|`[^a]`|

Using this translation, we can see that we get `[a-z][a-zA-Z0-9_]*` as the regular expression for `id`. Similar for `uid`. The final step is to wrap it up in the proper JSON format in the `mango.tmLanguage.json` file where we associate the `id` and `uid` with the suitable regular expressions and the corresponding classes:

@run<flowcpp --batch mango/mango.flow -- grammar=mango/mango.mango vscode=1>

``` extensions/area9.mango-1.0.0/syntaxes/mango.tmLanguage.json
		"id": {
			"patterns": [{
				"name": "variable.parameter",
				"match": "[a-z_][a-zA-Z_0-9]*"
			}]
		},
		"uid": {
			"patterns": [{
				"name": "entity.name.function",
				"match": "[A-Z][a-zA-Z_0-9]*"
			}]
		},
```

We do the same for all the other rules, and the end result is an automatic syntax highlighting generation from the lexical rules of our grammars. In addition to this, we extract keywords from rules that match the "keyword" or "type" classes. Also, we support defining what are considered brackets in the language, as well as have treatment of line and block comments. These are done by knowing about line-based comments and block comments, and encoding them with the appropriate regular expressions. The final thing is to support defining command lines that can be invoked from the editor. 

Here is how we use these constructs in the Mango grammar to end up with a fairly complete and very useful VS Code plugin for Mango:

``` tools/mango/mango.mango
@bracket<"(" ")">
@linecomment<"//">
@blockcomment<"/*" "*/">
@vscommand<"Mango check" "mango grammar=${relativeFile}" "F7">
```

Similarly, to demonstrate the generality of this, here are the syntax highlighting definitions for Melon:

``` melon/melon.mango
@include<highlight>
@highlight<exp "keyword.control">
@highlight<type "storage.type">
@highlight<id "variable.parameter">
@highlight<uid "entity.name.function">
@highlight<hexint "constant.numeric">
@highlight<double "constant.numeric">
@highlight<int "constant.numeric">
@highlight<string "string.quoted.double">
@highlight<ws "comment.block">
@bracket<"(" ")">
@bracket<"[" "]">
@bracket<"{" "}">
@linecomment<"//">
@blockcomment<"/*" "*/">
@vscommand<"Melon check" "melon ${relativeFile}" "F7">
```

The result looks something like this:

@run<flowcpp --batch mango/mango.flow -- grammar=melon/melon.mango vscode=1>

![VS Code with Melon syntax highlighting](images/vscode2.png)

You can find the code that implements all of this in the appendix.

### Syntax highlighting to Kiwi

Using the analysis above, we can also add support for syntax highlighting to the Markdown processor Kiwi. We do not have to convert all the way to regular expression syntax, but can just keep each syntax class as a simplified PEG grammar.

First, we replace the existing translation of Kiwi to HTML in Basil to call a new function `syntaxCode`:

``` kiwi/kiwi2html.basil
Code(line, ss) => `<pre><code>@syntaxCode(line, strGlue(ss, "\n"))@</code></pre>`;
```

This function takes the filename or language as well as the raw text to highlight, and produces a suitable syntax colored HTML string:

``` kiwi/code.flow
syntaxCode(codeline : [string], code : string) -> string
```

The function works by parsing the Mango grammar for the language, processing it for syntax highlighting as described above, and then uses the list of patterns of classes to do the syntax highlighting. Notice that we do not use the original PEG grammar as is, since syntax highlighting is different from parsing. When we are syntax highlighting, we have to work for snippets of code that might not parse correctly as they are. Thus, we just process each pattern at each char so it will work decently even for pseudo-code.

The syntax highlighting loop itself uses this data structure:

``` kiwi/code.flow
SyntaxHighlight(
	// The syntax patterns we have to match
	patterns : [TmPattern],
	// The code we are highlighting
	code : string,
	// The current index into the code we are highlighting
	i : int,
	// The syntax colored result we have built so far
	result : string
);
```

And the function itself just checks at each character in the code if any pattern matches. If it does, it will find the end of the match, and color that section with the given syntax highlighting class:

``` kiwi/code.flow
syntaxHighlight(acc : SyntaxHighlight) -> SyntaxHighlight {
	if (acc.i < strlen(acc.code)) {
		// Check all patterns at this point in the string
		macc = fold(acc.patterns, acc, \acc2, p -> {
			if (acc2.i == acc.i) {
				// Does this pattern match?
				ni = patternMatch(acc2, p);
				if (ni != acc2.i && ni != -1) {
					// We have a hit. Wrap the matches text in the syntax class
					word = "<span class='" + strReplace(p.name, ".", "_") + "'>" 
						+ escapeHtml(substring(acc.code, acc.i, ni - acc.i)) 
						+ "</span>";
					SyntaxHighlight(acc2 with i = ni, result = acc2.result + word);
				} else acc2;
			} else {
				acc2;
			}
		});
		if (macc.i != acc.i) {
			// OK, we already did it, so proceed
			syntaxHighlight(macc);
		} else {
			// No match. Just add the char directly as is
			syntaxHighlight(
				SyntaxHighlight(acc with 
					i = acc.i + 1, 
					result = acc.result + escapeHtml(getCharAt(acc.code, acc.i))
				)
			);
		}
	} else acc;
}
```

The pattern matching itself is done by this function, which will return the end of the match if the pattern matches:

``` kiwi/code.flow
// Moves "i" forward as much as this pattern matches
patternMatch(acc : SyntaxHighlight, pattern : TmPattern) -> int {
	switch (pattern) {
		TmMatch(id, name, term, regexp): {
			env = parseMango(term, strRight(acc.code, acc.i), 
				\s -> flow(s), \s -> s, \b -> b, \i -> i, \d -> d, 
				\ -> flow([]), \e, a -> arrayPush(a, e), \n : string, vals -> {
				makeStructValue(n, vals, String(""));
			});
			if (!env.fail) env.i + acc.i
			else acc.i;
		}
		TmNested(id, name, onlyInside, begin, end, insidePattern): {
			if (strContainsAt(acc.code, acc.i, begin)) {
				hit = strRangeIndexOf(acc.code, end, acc.i + strlen(begin), strlen(acc.code));
				if (hit >= 0) hit + strlen(end)
				else acc.i
			} else acc.i;
		}
	}
}
```

The code you see above is processed by this code to bring the colors, through these CSS rules:

``` kiwi/kiwi.css
code span.constant_character { color: #4070a0; }
code span.comment_line { color: #60a0b0; font-style: italic; }
code span.comment_block { color: #60a0b0; font-style: italic; }
code span.storage_type { color: #902000; font-weight: bold; }
code span.constant_numeric { color: #40a070; }
code span.entity_name_function { color: #007020; font-weight: bold; }
code span.keyword_control { color: #007020; }
code span.string_quoted_single { color: #bb6688; }
code span.string_quoted_double { color: #4070a0; }
code span.variable_parameter { color: #19177c; font-weight: bold; }
```

## Abstract Evaluation for Pretty Printing

Often we have an AST, but want to print it out in natural syntax to read it more nicely. This is called pretty printing, and allows us to take any value from the AST and produce a nice string for it. Ideally, the string will parse back to the exact same AST, so we can do round tripping. This problem is in not well defined since there are infinitely many ways to write the same AST as syntax, but we can build a good starting point, and then the programmer only has to tweak the few rules, which are not ideal.

@run<flowcpp --batch mango/mango.flow -- grammar=mango/mango.mango pretty=1>
@run<basil.bat file=mango/mango_pretty.basil compile=Mango to=Blueprint target=string>
@run<basil.bat file=mango/mango_pretty.basil compile=Mango to=Blueprint target=string melon=1>

This is done by an abstract interpretation of each node in the Mango AST. The idea is to associate a stream of tokens and variables with each choice in the grammar until we find a constructor. At that point, we "flush" all the collected elements, and build a Basil rule that maps from the constructor to the individual strings and variables for that.

We do not want to include the white-space rules in the result. So before the abstract interpretation, we first identify what rules actively use the stack. White-space rules are not *active* on the stack, so at the end of this preprocessing, we can automatically cull out all inactive rules, which also includes all the whitespace.

One extra detail is that we want to keep track of the current level of precedence. Each time we have a `|>` precedence choice, we will increase a precedence counter. This allows us to keep track of where to insert parenthesis later.

If we do this process for the grammar of Mango itself, we end up with this Basil program, which defines how each AST node should be turned into a string:

TODO: Change to Kiwi syntax and handle precedence directly instead of as comments

``` tools/mango/mango_pretty.basil
Choice(term1, term2) => `$term1|$term2` /* /1 */;
Construct(uid, int1) => `$uid/$int1` /* /11 */;
Error(term) => `#$term` /* /6 */;
GrammarMacro(id, term) => `@"\x40"@$id<$term>` /* /4 */;
Lower(term) => `<$term` /* /5 */;
Negate(term) => `!$term` /* /10 */;
Optional(term) => `$term?` /* /9 */;
Plus(term) => `$term+` /* /8 */;
Precedence(term1, term2) => `$term1|>$term2` /* /0 */;
PushMatch(term) => `@"\x24"@$term` /* /3 */;
Range(char1, char2) => `'$char1'-'$char2'` /* /11 */;
Rule(id, term1, term2) => `$id=$term1;$term2` /* /11 */;
Sequence(term1, term2) => `$term1$term2` /* /2 */;
StackOp(string1) => `@"\x40"@$id` /* /4 */;
Star(term) => `$term*` /* /7 */;
String(string1) => `"$string1"` /* /11 */;
Variable(id) => `$id` /* /11 */;
```

The result is decent, although not perfect. To get a nicer pretty printing, what we want to do is to override a few of the rules to improve the layout with some better spacing:

``` basil
Precedence(l, r) => `$l 
|> $r`;
Choice(l, r) => `$l | $r`;
Sequence(term1, term2) => `$term1 $term2`;
Rule(id, val, body) => `
$id = $val;
$body`
```

Using this pretty printer, we get this output grammar for Mango itself:

TODO: Change this to be the real thing

@run<flowcpp --batch mango/mango.flow -- grammar=mango/mango.mango prettyprint=output/mango.mango>

``` output/mango.mango
term = 
  term "|>" ws <term Precedence/2
|> term "|" ws <term Choice/2
|> term <term Sequence/2
|> "$" ws term PushMatch/1
|> "@" ws id "<" ws term ">" ws GrammarMacro/2
   | 
  "@" ws id StackOp/1
|> "<" ws term Lower/1
|> "#" ws term Error/1
|> term "*" ws Star/1
|> term "+" ws Plus/1
|> term "?" ws Optional/1
|> "!" ws term Negate/1
|> "(" ws term ")" ws
   | uid "/" ws int Construct/2 | string String/1 | char "-" char Range/2 | 
  stringq String/1 | id "=" ws term ";" ws term Rule/3 | id Variable/1;
id = $('a'-'z' (alphanum)*) ws;
uid = $('A'-'Z' (alphanum)*) ws;
alphanum = 'a'-'z' | 'A'-'Z' | '0'-'9' | "_";
int = $(('0'-'9')+) ws;
string = "\"" $((!"\"" anychar)*) "\"" ws;
stringq = "'" $((!"'" anychar)*) "'" ws;
char = "'" $("0x" (hexdigit)+ | anychar) "'" ws;
hexdigit = 'a'-'f' | 'A'-'F' | '0'-'9';
```

The approach adopted is a fairly pragmatic approach, which is not very general. It will fail for more complicated grammars. I did investigate doing a more advanced approach. This was based on reversing the meaning of the parsing algorithm. Thus, the problem could be considered as a reverse interpretation of the AST into the text. In particular, the most promising approach seemed to construct the text in reverse, from the end to the start. I got this approach to work for quite a lot of constructs, but in the end, handling all the stack manipulation operations become excessively complicated.

Given that the heuristic above does a decent job, and that the programmer has to do some manual formatting anyways, I decided that the simple approach is good enough. Sometimes perfect is the enemy of good. Solving pretty printing in general is a research-level question, and even though there is probably a way to make it much more robust compared to the simple heuristic, we have to decide where to invest the energy. Maybe other things can bring more practical value, especially since writing a pretty printer by hand is easy, especially when you get a head-start from a simple heuristic.



## Mango summary

At this point, we have reached a point, where the Mango grammar language can do a lot:

1. Support writing very succinct and clear grammars for both lexing and parsing
2. Provide a standard library of common, reusable grammar constructs
3. Automatically get the type definitions for the corresponding AST
4. Get an efficient parser for the language that constructs the strongly typed AST
5. Have a simple pretty printer automatically generated
6. Get a functional VS code plugin for the language with minimal effort
7. Support syntax highlighting in Kiwi Markdown documents of the language

Consider that the grammar for Melon is 150 lines of code, but we literally get thousands of lines of code generated for us with very useful functionality. And importantly, all of this code is maintained from the 150 lines of code. Whenever a change is done, all of the rest of the code can easily be updated as well. This is a model of how to accomplishing a lot with little code.


