# Possible Mango extensions

## Types

We can combine the type and Mango grammars this way:

``` tools/mango/mango_typed.mango
@slice<term @include<mango>>

@slice<(type typedef) @include<types>>

term = term ":" ws type TypeAnnotation/2 |> term;

ws term
```

@run<flowcpp --batch mango/mango.flow -- grammar=mango/mango_typed.mango types=2 typeprefix=Mt_>

## Optimizations

Requires dependency graph:
- Common sub-expression elimination in a loop-free version of the grammar starting from leaves. 
- Dead-code elimination using topological sort of the dependency graph.

## Advanced macros

### Factoring grammars into bits

``` mango
// Basil becomes:
@rewrite<left right> =
	(rewrite = 
		@left "=>" ws @right RewriteRule/2
		| @left "<=>" ws @right RewriteBidir/2
		| @left "<=" ws @right @swap RewriteRule/2;
	@array<rewrite ";"> Rewrites/1);
```

``` mango
// AST language:
ast = 
	"true" kwsep @true BoolValue/1
	| "false" kwsep @false BoolValue/1
	| $double ws @s2d DoubleValue/1 
	| $int ws @s2i IntValue/1 
	| $string ws @unescape StringValue/1
	| "[" ws @array<ast ","> "]" ws ArrayValue/1
	| uid "(" ws @array<ast ","> ")" ws ConstructorNode/2
	| id BindVar/1
	;

// How to "combine" languages:
@pattern<ext node> =
	@import(ast)
	ast = ast | "`" @ext "`" @lift(node);
	ast;
```

`@lift` takes semantic values and lifts them into ConstructorNode and BindVar when matching node.

### Whitespace macro

We want a macro, which helps add whitespace and handle keywords. It should work like this:

``` mango
@ws(
	(
		"import" $(bid ('/' bid)*) ws body Import/2 
		| typename "::=" @array<struct ","> body UnionDefBody/3
		| uid ":" '(' @array<structarg ","> ')' body StructDefBody/3
	)
	|> functions
		| lid "=" exp body Let/3 
		| lid ":" type "=" exp body LetTyped/4
) =
	(
		"import" kwsep $(bid ('/' ws bid)*) ws body Import/2 
		| typename "::=" ws @array<struct ","> body UnionDefBody/3
		| uid ":" ws '(' ws @array<structarg ","> ')' ws body StructDefBody/3
	)
	|> functions
		| lid "=" ws exp body Let/3 
		| lid ":" ws type "=" ws exp body LetTyped/4
```

`ws` could be defined like this:

``` melon
	mangoFns("
		ws(r) = 

@ws<r> =
	@melon(
		"
			// Define a function which determines if a string is a word
			isWord = \s -> ...;
			// Set up a basil parse with value, value and melon conditions:
			rewrite(r, basil(value, value, melon, `
				String(s) => Sequence(String(s), Negate(Rule("isalnum))) when @isWord(s)@;
				String(s) => Sequence(String(s), Rule("ws));
			`)))
		"
	)
```

It works like this:

1. After keyword constant strings, add "!alnum":

``` basil
String(s) => Sequence(String(s), Negate(Rule("isalnum))) when @isWord(s)@;
```

where isWord is defined in Melon in the Melon block.

2. After constant strings, add "@ws". This will happen `@array` has been evaluated, so it is good:

``` basil
String(s) => Sequence(String(s), Rule("ws))
```

Provided that Basil understand "when @condition@" in some third language.

Instead of defining the function inside Mango, we could arguably also define it in Melon.

