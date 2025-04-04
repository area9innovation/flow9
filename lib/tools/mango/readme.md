# Mango Tutorial: Building an Expression Parser

## What is Mango?

Mango is a PEG (Parsing Expression Grammar) parser generator for Flow9. It allows you to define language grammars concisely, automatically generate type definitions, and create parsers that transform text into typed Abstract Syntax Trees (ASTs).

## Step 1: Creating a Grammar

Let's build a grammar for a simple expression language that handles arithmetic operations, variables, and function calls:

```mango
@include<lexical> // Defines ws, id, int, double, string lexical rules
@include<list>	  // For @opt & @array handling

exp =
	exp ("+" ws exp Add/0 BinOp/3 | "-" ws exp Sub/0 BinOp/3)
	|> exp ("*" ws exp Mul/0 BinOp/3 | "/" ws exp Div/0 BinOp/3 | "%" ws exp Mod/0 BinOp/3)
	|> exp "^" ws <exp Pow/0 BinOp/3  // Right-associative power operation
	|> "-" Negative/0 ws <exp @swap UnOp/2
	|> exp ("(" ws @array<exp ","> ")" ws Call/2)?  // Function calls
	|>
		"(" ws exp ")" ws
		| $double ws @s2d Double/1
		| $int ws @s2i Int/1
		| "true" kwsep @true Bool/1
		| "false" kwsep @false Bool/1
		| id Var/1
	;

ws exp
```

## Step 2: Understanding Mango Concepts

### Rules and Matching
- Rules like `exp = ...` define grammar patterns
- String literals (`"+"`) match exact text
- `ws` matches whitespace (spaces, tabs, newlines)
- `id` matches identifiers (pre-defined in `<lexical>`)

### Precedence with `|>`
The `|>` operator defines precedence levels, ensuring operations are parsed in the correct order:
- Addition/subtraction (lowest precedence)
- Multiplication/division/modulo (higher precedence)
- Exponentiation (even higher)
- Negation (higher still)
- Parenthesized expressions, literals, variables (highest)

### AST Construction with Semantic Actions
- `Add/0` creates an operator token without arguments
- `BinOp/3` creates a binary operation node with 3 arguments
- `$int ws @s2i Int/1` captures an integer literal, converts it to an integer, and builds an `Int` node

## Step 3: Compiling the Grammar

Compiling the grammar with Mango:
```bash
flowcpp --batch tools/mango/mango.flow -- grammar=expression.mango types=2 compile=1 linter=1
```

This generates:
- Type definitions in `expression_types.flow`
- Parser implementation in `expression_compiled_parser.flow`
- A simple linter in `expression_linter.flow`

## Step 4: Generated Types

Mango automatically generates our AST structures in `expression_types.flow`:

```flow
Exp ::= BinOp, Bool, Call, Double, Int, UnOp, Var;
	BinOp(exp1 : Exp, exp2 : Exp, binop_1 : Binop_1);
	Bool(bool1 : bool);
	Call(exp1 : Exp, exps : [Exp]);
	Double(double1 : double);
	Int(int1 : int);
	UnOp(exp1 : Exp, negative : Negative);
	Var(id : string);

Binop_1 ::= Add, Div, Mod, Mul, Pow, Sub;
	Add();
	Div();
	Mod();
	Mul();
	Pow();
	Sub();

Negative();
```

## Step 5: Building an Evaluator

We can now implement a complete evaluator for our expression language:

```flow
evalExpression(env : Tree<string, Value>, expr : Exp) -> Value {
	switch (expr) {
		BinOp(left, right, op): {
			leftVal = evalExpression(env, left);
			rightVal = evalExpression(env, right);
			switch (op) {
				Add(): valueAdd(leftVal, rightVal);
				Sub(): valueSub(leftVal, rightVal);
				Mul(): valueMul(leftVal, rightVal);
				Div(): valueDiv(leftVal, rightVal);
				Mod(): valueMod(leftVal, rightVal);
				Pow(): valuePow(leftVal, rightVal);
			}
		}
		// Handle other expression types...
	}
}
```

## Step 6: Testing the Parser and Evaluator

Our tests demonstrate the parser's handling of:

1. **Precedence and associativity**:
```
	 1 + 2 * 3         -> (1 + (2 * 3))         -> 7
	 (1 + 2) * 3       -> ((1 + 2) * 3)         -> 9
	 2 ^ 3 ^ 2         -> (2 ^ (3 ^ 2))         -> 512
```

2. **Function calls**:
```
	 sin(pi / 2)       -> sin((pi / 2))         -> 1
	 max(1, 5, 3, 10)  -> max(1, 5, 3, 10)      -> 10
```

3. **Error handling**:
```
	 1 / 0             -> (1 / 0)               -> error: Division by zero
	 sqrt(-1)          -> sqrt(-1)              -> error: sqrt requires non-negative argument
```

## Conclusion

With just a few dozen lines of Mango grammar, we've created a complete expression language with:

1. Precedence-aware parsing
2. Type-safe AST generation
3. Proper associativity handling
4. Function call support
5. Error detection and reporting

Mango's power lies in its expressive grammar syntax and automatic generation of type-safe parsers, making it an excellent choice for creating domain-specific languages in Flow9.
