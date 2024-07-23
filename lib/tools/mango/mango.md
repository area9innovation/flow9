# Mango: Parsing Language

When making new programming languages, we want to be able to define the syntax of them. To do that, we need a language for writing the grammars of languages. This defines the legal structure of terms in that language. The goal is to be able to specify notation that is easy to understand, practical and compositional.
At the end, we will have a way to define the syntax of a language and get a function, which can turn a string representation of programs - in that language - into a typed data structure that represents the syntax of that program. That data structure is called an Abstract Syntax Tree (abbreviated AST), and the entire process is what we call parsing.

``` melon
parse("print(42)") == Call(Variable("print"), [Int(42)])
```

![Art picture of machine made of mango](images/DALL·E 2022-08-18 09.55.35 - art picture of machine made of mango.png)

## The Mango grammar syntax

Our grammar will be based on Parsing Expression Grammars (PEG). This is an elegant formalism that comes with parsing constructs such as matching strings, choices, repeats, and semantic actions.
We call our version of this language *Mango*, and the constructs and syntax are introduced in this section. If you know of regular expressions, BNFs or similar, these concepts should be familiar, but we will illustrate the core concepts now.

The language is divided into two main parts: The matching constructs, and the semantic actions.

### Lexical matching

This grammar matches the string `hello`:
``` mango
"hello"
```

In PEG parsers, we do not separate between lexing and parsing, but do both with the same formalism. This makes writing grammars simpler, since there is no need for a separate lexing phase that turns characters into tokens - the PEG parser skips the concept of tokens entirely, and works on the characters directly.

This matches the string `hello world` through three strings. Notice the space is explicit:
``` mango
"hello"  " "  "world"
```

Any sequence of operations will be matched in sequence. This example contains a sequence of three strings. (Of course, we could write that as a single string `"hello world"`.)

This matches any lowercase letter using the "character range" construct:
``` mango
'a'-'z'
```

As an interesting case, this grammar matches any 16-bit Unicode character:
``` mango
'0x0'-'0xFFFF'
```
The range construct thus supports hexadecimal notation. Technically, if you have a Unicode smiley in your text to parse, this construct will not work. This is because some Unicode characters require multiple UTF-16 characters for correct representation. Using choices and the appropriate ranges, it is possible to write a Mango grammar for matching any Unicode character.

### Structural matching

This matches either an `a` or a `b`, using a *choice operator*:
``` mango
"a" | "b"
```
The grammar works by recursive descent. That means it tries to match the first branch first. If that succeeds, we are done, and the branch with `b` is ignored. If it fails, it tries to match the second branch of the choice. Choices allow arbitrary backtracking in case choices have common prefixes. That makes it very easy and convenient to write the grammars.

So unlike some parser techniques you may know, the order of the choices do matter in PEG parsing. This helps make PEG grammars faster, and in most cases the result is the same as with other technologies. Only in rare cases do you need to worry about the order of choices. It also means that composing grammars is much easier to reason about, as we will see later.

Similar to regular expressions, there are operators for repeating and optional parts. This matches one or more letters using the `+` operator:
``` mango
'a'-'z'+
```

This matches zero or more digits using the repetition operator `*`:
``` mango
'0'-'9'*
```

This matches `hello` or `hello world` using the optional operator `?`:
``` mango
"hello" " world"?
```

(It could also be written as `"hello" (" world" | "" )` using an empty string in the second choice.)

This matches any letter except `i`:
``` mango
!"i" 'a'-'z'
```

That might be useful in a grammar for names of math variables, where `i` should be reserved for imaginary numbers. The `!` prefix negation operator will not proceed parsing if the argument matches, but not consume any characters on it's own. You can use any term inside the `!`, not just strings.

TODO: Add diagrams a la https://www.sqlite.org/lang_select.html to illustrate these constructs

### Defining rules

It is possible to bind grammars to names, similar to let-bindings in normal programming. We call such bindings *rules*. This grammar defines an `id` rule and matches any string with two identifiers separated by commas:

``` mango
id = 'a'-'z' ('a'-'z' | '0'-'9' | "_")*;
id "," id
```

Binding rules uses lower-case identifiers only, and always requires a scope for the body where the binding is valid: `<id> = <binding> ; <body>`. The rule is meant to be used in the body, but it is valid to use it inside the binding itself - a recursive use.

### Semantic Actions: Capturing parsing results

It is a result of research that the above constructs are sufficient to parse most programming languages. So now, we can define the syntax of our language and check whether a text matches that. However, to use the result of the parser, it is necessary to construct the Abstract Syntax Tree using *semantic actions*.

We do that using a *result stack*. A stack is a data structure which works like a stack of plates: You can put a plate on top of a stack (called push), and take a plate away if the stack is not empty (called pop). We do not allow you to remove plates in the middle of the stack. A sequence of pushes and pops will occur during the parsing, and if a parse is successful, the stack will have a single plate at the end, which will be the final result of the parse.

The first semantic action pushes the result of a parse on the result stack using the `$` prefix.  This grammar matches an identifier, and pushes the string of the id on the result stack:

``` mango
$id
```

So if we give this grammar the text `foo`, and parse that, the result stack will have a single string `"foo"` on it.

### Constructors

The following grammar constructs a data structure named `Id` with the name of the identifier inside. The `/1` defines the arity of the structure. That is the number of arguments we will pop from the stack and put inside the structure:

``` mango
$id Id/1
```

Constructors like `Id` is the name we give to functions that construct a data structure, and must always be written with capital letters.

So with that rule, first we will parse the identifier `foo` and push the resulting string `"foo"` on the stack. After that, the constructor `Id/1` will be evaluated. It pops the string from the top of the stack, and uses that as an argument to a data structure called `Id` with a single, string argument, and the pushes the result so the stack has a single value, which we can write like this: `Id("foo")`.

Now, assume we have a rule `ws` that matches whitespace, and another rule `exp` that matches expressions and pushes it. Then the following matches if-then-else expressions and captures the combined result in an `If`-structure with the condition as the first argument, the then-branch as the second and the else-branch as the third. 

``` mango
"if" ws exp "then" ws exp "else" ws exp If/3 
```

If we parse the text `if a then b else c`, first, we would push the value of `a` on the stack, then push `b`, and then `c`. At this point, the `If/3` constructor will be evaluated, and pop the three values and push a single value `If(a, b, c)` on the stack where `a`, `b`, and `c` are any expression structures themselves.

In the next chapter, we will define an entire language that can be used to manipulate the result stack.

### Error handling

To make a grammar more resilient to syntax errors, it is useful to catch two categories of errors: Missing elements and superfluous elements. Mango introduces the `#` prefix construct to help with recovering better from parsing errors.

This matches a `;` in the text. If it is missing, we report an error, but otherwise continue parsing:
``` mango
#";"
```

This grammar will report an error if there is a `;`, but otherwise continue:
``` mango
#!";"
```

If these constructs are not used, then parsing will stop on the first error that occurs.

### Handling precedence with `|>`

This grammar is an attempt at a grammar for mathematical expressions with addition and multiplication of integers:

``` mango
exp = exp ("+" exp)+ | exp ("*" exp)+ | '0'-'9'+;
exp
```

@run<flowcpp --batch tools/mango/mango.flow -- grammar=tools/mango/tests/exp1.mango savereduced=out/exp1_reduced.mango types=0>

However, since the grammar is based on a PEG parser, it does recursive descent. That ultimately means `1*2+3` is parsed correctly, but `1+2*3` is not - it ends up as `(1+2)*3`. To handle this, the `|>` operator can define the precedence of choices:

``` tools/mango/tests/exp1.mango
exp = exp ("+" exp)+ |> exp ("*" exp)+ |> '0'-'9'+;
exp
```

and with this, both the two strings are parsed correctly as `(1*2)+3` and `1+(2*3)` respectively.

The way the `|>` works is that it rewrites the grammar to have multiple levels for each precedence.

``` out/exp1_reduced.mango
exp = exp1 ("+" exp1)*;
exp1 = exp2 ("*" exp2)*;
exp2 = ('0'-'9')+;
exp
```

Left recursion and right recursion is automatically expanded to the next precedence. Recursions in the middle will keep referring to the top level. To understand these terms, imagine we have a grammar like this somewhere, with three recursive references:

``` mango
exp = ...
			Middle recursion
			   |
			  \|/
	| exp ... exp  ... exp; 
       ^				^
	   |				|
left recursion		right recursion
```

In generality, if there is any way a recursive rule reference can be matched at the start of the rule, then it is left recursive. Similarly, if there is any way a rule can be matched at the end of the rule, it is right recursive. If it can neither, it is what we call a middle recursion.

So in this example:
``` mango
exp = 'export'? exp ":" exp "=" exp? @drop @drop Foo/1;
```

the first `exp` is left recursive, and the third is right recursive, since they can both be the first and last things to match anything in some situations - since the `export` string is optional and semantic actions do not affect matching. The second one is middle recursive, since it can never be the first or last thing to match.

In a PEG grammar, it is not allowed to have left-recursion, since that results in an infinite loop. However, in Mango, the `|>` operator allows you to do this, as long as the final right-hand side of your precedences does not have left-recursion:

``` mango
// This is OK since the last choice can not be left-recursive
exp = exp "+" |> exp "-" |> "1"; 

// This is NOT OK since the last choice could be left-recursive
exp = exp "+" |> exp "-" | "1"; 
```

The reason is that we rewrite the rules to not be left-recursive after the precedence are expanded as seen above.

### Handling associativity with `<`

In this grammar, we have introduced `-` for subtraction and `^` for exponentiation, as well as prefix `-` for negation:

``` tools/mango/tests/exp2.mango
exp = exp ("+" exp | "-" exp)* 
	|> exp ("*" exp)* 
	|> exp ("^" exp)*
	|> "-" exp
	|> '0'-'9'+; 
exp
```

This parses `1-2-3` as left-associative `(1-2)-3` which follows mathematical tradition.

However, `2^3^4` will parse as `(2^3)^4` which is wrong. We want `^` to be right-associative instead.

@run<flowcpp --batch tools/mango/mango.flow -- grammar=tools/mango/tests/exp2.mango savereduced=out/exp2_reduced.mango types=0>

If we look at the expanded version, we see that we get

``` out/exp2_reduced.mango
exp = exp1 ("+" exp1 | "-" exp1)*;
exp1 = exp2 ("*" exp2)*;
exp2 = exp3 ("^" exp3)*;
exp3 = "-" exp4 | exp4;
exp4 = ('0'-'9')+;
exp
```

We want the last `exp3` in the rule for exponentiation to be `exp2` instead. We can change this to be right associative by using the `<` lower construct:

``` tools/mango/tests/exp3.mango
exp = exp ("+" exp | "-" exp)* 
	|> exp ("*" exp)* 
	|> exp ("^" <exp)*
	|> "-" <exp
	|> '0'-'9'+; 
exp
```

We also changed negation to use `<`, since we can could not parse double negation: `- -2` before. Now we have the correct result:

@run<flowcpp --batch mango/mango.flow -- grammar=mango/tests/exp3.mango savereduced=out/exp3_reduced.mango types=0>

``` out/exp3_reduced.mango
exp = exp1 ("+" exp1 | "-" exp1)*;
exp1 = exp2 ("*" exp2)*;
exp2 = exp3 ("^" exp2)*;
exp3 = "-" exp3 | exp4;
exp4 = ('0'-'9')+;
exp
```

The difference is subtle, but it makes the difference we need.

Sometimes, we do not want right recursion to stay at the current level, but rather make it refer to the top level. That is possible by adding an empty string at the end, so it is not technically right recursion:

``` tools/mango/tests/exp4.mango
exp = exp "+" exp |> exp "*" exp 
	|> "\\" "->" exp ""   // The "" prevents right recursion
	|> '0'-'9'+;
exp
```

@run<flowcpp --batch mango/mango.flow -- grammar=mango/tests/exp4.mango savereduced=out/exp4_reduced.mango types=0>

and this expands to

``` mango
exp = exp1 ("+" exp1)?;
exp1 = exp2 ("*" exp2)?;
exp2 = "\\" "->" exp | exp3;
exp3 = ('0'-'9')+;
exp
```

where `exp2` refers to the top-level exp on the right hand side.

This will allow expressions like `\->1+2` to parse as `(\->1+2)` rather than `(\->1)+2` following expectations for this notation.

TODO: Document common stack operations like nil, cons, s2i as a preview before we get to Poppy

### Grammar functions

There are common patterns in grammars, such as collecting a list of elements:

``` mango
exps = @nil (exp @cons)*;
```

This is common, but quite verbose. To help express that more clearly, Mango provides functions:

``` tools/mango/lib/list.mango
@list0<e> = @nil (e @cons)*;
```

A function definition thus has the form `@id<args> = body; ...`. In this case, we define a function called `list0`, which takes one argument called `e`. This is then expanded in the body, and the result is that `@list0<exp>` expands into `@nil (exp @cons)*` as desired:

``` mango
exps = @list0<exp> // Expands to @nil (exp @cons)*;
```

We define `@list1` in a similar way:

``` tools/mango/lib/list.mango
@list1<e> = @nil (e @cons)+;
```

which corresponds to `e+` while we collect the results in a list.

Another common pattern is to collect lists of items separated by commas:

``` mango
exps = @nil (exp @cons ("," ws exp @cons)* ("," ws)?)?;
```

Tracking of all of that is a bit tricky, since we have to handle the case of no expressions, collect all of the expressions into a list, and allow trailing commas. This is quite verbose, but at the same time common. Let us define a grammar function `@list<term separator>` to express that more clearly:

``` tools/mango/lib/list.mango
@list<e sep> = @nil (e @cons (sep ws e @cons)* (sep ws)?)? @list2array;
```

and now `@list<exp ",">` expands into the above, and that helps make grammars easier to write and understand.

In addition to `@list`, `@list0` and `@list1`, we also define `@array*` versions of these, which collects the list into an array. The list versions have constant type append behaviour while the list is constructed. However, in the AST, you often want to have an array instead of a list, so the `@array*` versions are useful for that: They construct the list first, and then convert that in linear time to an array at the end using `@list2array`:

``` tools/mango/lib/list.mango
@array<e sep> = @list<e sep> @list2array;
@array0<e> = @list0<e> @list2array;
@array1<e> = @list1<e> @list2array;
```

### Including Mango files in Mango files

Mango also provides the `@include<name>` syntax for inclusion of other Mango files in a file. If we place the functions for `list0`, `list1` and `list` in a file called `list.mango`, then we can import these with `@include<list>` and use them in the grammar:

@run<mango2.bat grammar=mango/tests/define.mango>

``` tools/mango/tests/define.mango
@include<list>
ints = "ints" @list<int ",">;
star = "star" @list0<int>;
plus = "plus" @list1<int>;
int = $'0'-'9';
exp = ints | star | plus;
exp
```

and the result is that we get this grammar after expansion:

``` mango
ints = "ints" @nil (int @cons ("," ws int @cons)* ("," ws)?)?;
star = "star" @nil (int @cons)*;
plus = "plus" @nil (int @cons)+;
int = $('0'-'9');
exp = ints | star | plus;
exp
```
