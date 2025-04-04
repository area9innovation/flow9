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

## Summary

With just a few dozen lines of Mango grammar, we've created a complete expression language with:

1. Precedence-aware parsing
2. Type-safe AST generation
3. Proper associativity handling
4. Function call support
5. Error detection and reporting

Mango's power lies in its expressive grammar syntax and automatic generation of type-safe parsers, making it an excellent choice for creating domain-specific languages in Flow9.

# Mango Parser Generator

## Project Overview

Mango is a sophisticated parser generator tool built with Flow9. It takes grammar definitions written in the Mango language (`.mango` files) and generates various outputs, including:

*   **Flow9 Parsers**: Compiles grammars into efficient Flow9 code that can parse input text according to the defined grammar.
*   **Type Definitions**: Infers and generates Flow9 (`.flow`) or Melon (`.melon`) type definitions corresponding to the Abstract Syntax Tree (AST) produced by the parser.
*   **VS Code Extensions**: Creates basic Visual Studio Code extensions providing syntax highlighting for the language defined by the Mango grammar.
*   **Linters**: Generates simple linter programs based on the compiled parser.

The system leverages Flow9's functional programming principles and includes features like precedence handling, grammar functions (macros), includes, optimization, and type inference. It appears to be bootstrapped, meaning the Mango grammar language itself is defined using Mango.

**Primary Technologies:** Flow9, Mango (custom grammar language), Poppy (custom stack language for semantic actions).

## Core Components

1.  **Main Driver (`mango.flow`)**:
	*   The command-line interface (CLI) entry point.
	*   Parses arguments to determine operations (compile, generate types, generate VS Code extension, parse input, etc.).
	*   Orchestrates the entire process: parsing the `.mango` grammar, preprocessing, analysis, and generation steps.

2.  **Grammar Preprocessing**:
	*   **Function/Include Evaluation (`evaluate_functions.flow`)**: Processes `@include` directives and evaluates grammar functions (`@func<...>=...`) defined within the grammar.
	*   **Restructuring (`restructure.flow`)**: Combines multiple definitions of the same rule into choices.
	*   **Precedence Expansion (`precedence.flow`)**: Translates precedence operators (`|>`) and associativity hints (`<`) into simpler sequences and choices, handling left/right recursion adjustments.
	*   **Rewriting (`mango_rewrite.flow`, `mango.basil`)**: Applies simplification and optimization rules to the grammar's `Term` AST, using an external tool/language called Basil.

3.  **Compiler (`compiler/`)**:
	*   **Mango to Opcode (`mango2opcode.flow`)**: Converts the `Term` AST into an intermediate representation (`MOpCode`).
	*   **Effects Analysis (`opcode_effects.flow`)**: Statically analyzes `Term` and `MOpCode` to determine stack usage and backtracking requirements, enabling optimizations. Uses fixpoint iteration for recursive rules.
	*   **Optimization (`optimize.flow`)**: Optimizes the `MOpCode` sequence (e.g., simplifying conditionals, removing redundant checkpoints).
	*   **Opcode to Code (`opcode2code.flow`)**: Generates executable Flow9 parser code from the optimized `MOpCode`, utilizing `mcode_lib.flow`.
	*   **Main Compiler Logic (`compile.flow`)**: Orchestrates the compilation pipeline.
	*   **Linter Generation (`linter.flow`)**: Creates Flow9 code for a basic linter using the compiled parser.

4.  **Type Inference (`type/`)**:
	*   **Type Evaluation (`type_eval.flow`)**: Infers the types produced by each grammar rule by simulating parsing at the type level, managing a type stack (`MType`).
	*   **Type Generation (`infer_types.flow`, `type2melon.flow`)**: Resolves inferred types (including generating names for implicit unions) and outputs `.flow` or `.melon` type definition files.

5.  **VS Code Extension Generator (`vscode/`)**:
	*   **TextMate Generation (`term2tmlanguage.flow`)**: Converts grammar rules (especially those annotated with `@highlight`) into TextMate grammar definitions.
	*   **Packaging (`tmlanguage_compile.flow`)**: Creates the necessary `package.json`, `language-configuration.json`, and syntax files for a functional VS Code extension.

6.  **Runtime & Interpretation**:
	*   **Compiled Parser Runtime (`mcode_lib.flow`)**: Contains Flow9 helper functions required by the generated parsers (e.g., `mmatchString`, `mparseStar`, checkpoint management, profiling).
	*   **Interpreter (`mango_interpreter.flow`)**: Directly interprets a Mango `Term` AST to parse input (likely for bootstrapping or debugging). Uses `env.flow` for its execution environment.

7.  **Analysis & Utility**:
	*   **Exponential Detection (`exponential.flow`)**: Warns about grammar patterns that could lead to exponential parsing times.
	*   **Pretty Printing (`mango2string.flow`, `pretty/`)**: Converts `Term` AST back to Mango syntax. Contains experimental code for inferring pretty-printers.
	*   **Visualization (`mango2dot.flow`)**: Generates Graphviz DOT files from grammars.
	*   **Error Reporting (`line.flow`)**: Converts character offsets to line/column numbers for user-friendly error messages.

## Code Structure

*   `flow9/lib/tools/mango/`: Root directory.
	*   `mango.flow`: Main CLI entry point.
	*   `mango_types.flow`/`.melon`: Core `Term` AST definition.
	*   `mango_grammar.flow`/`.melon`: Bootstrapped Mango grammar AST.
	*   `mcode_lib.flow`: Runtime library for compiled parsers.
	*   `mango_interpreter.flow`, `env.flow`: Interpreter logic.
	*   Preprocessing files: `evaluate_functions.flow`, `precedence.flow`, `restructure.flow`, `mango_rewrite.flow`, etc.
	*   Analysis files: `exponential.flow`, `mango2string.flow`, `mango2dot.flow`, etc.
	*   Utility files: `line.flow`, `rules.flow`, `util.flow`, etc.
*   `compiler/`: Contains the code generation pipeline (Term -> MOpCode -> Flow9).
*   `type/`: Houses the type inference logic and type definition generation.
*   `vscode/`: Contains logic for generating VS Code extensions (TextMate grammars, packaging).
*   `lib/`: Contains reusable `.mango` grammar snippets (lexical rules, list patterns, etc.).
*   `pretty/`: Experimental pretty-printer inference logic.
*   `*.mango`: Mango grammar definition files (including standard library snippets in `lib/`).
*   `*.md`: Documentation files.

## Key Abstractions

*   **`Term` (`mango_types.flow`)**: The primary AST representing a Mango grammar. Defines nodes like `Rule`, `Choice`, `Sequence`, `Construct`, `PushMatch`, `StackOp`, etc.
*   **`MOpCode` (`compiler/mopcode.flow`)**: Intermediate Representation (IR) used during compilation. Represents low-level parsing operations (e.g., `MoMatchString`, `MoCall`, `MoPushCheckpoint`).
*   **`MType` (`type/types.flow`)**: Represents the types inferred from the grammar (e.g., `MTypeInt`, `MTypeString`, `MTypeConstructor`, `MTypeUnion`, `MTypeStar`).
*   **`MOpCodeEffects` (`compiler/opcode_effects.flow`)**: Data structure holding the results of static analysis (whether a `Term` or `MOpCode` modifies the stack or needs backtracking).
*   **`TmLanguage` (`vscode/tmlanguage_types.flow`)**: Represents the structure of a VS Code TextMate grammar (`.tmLanguage.json`).
*   **`MEnv` (`env.flow`)**: The environment used by the `mango_interpreter`. Holds input, position, rules, result stack, etc.
*   **`MoParseAcc` (`mcode_lib.flow`)**: The runtime state object passed around in *compiled* parsers. Holds input, position, stack (`PEnv`), checkpoint stacks, etc.

## Dependencies and Integration Points

*   **Internal Tools**:
	*   `tools/poppy`: Used for the stack-based semantic actions (`@...` syntax). Mango parses these actions and uses Poppy's interpreter/compiler and type system (`penv`, `poppy_interpreter`, `poppy_grammar`, `poppy_types`).
	*   `tools/basil`: Used for applying grammar rewrite rules (`mango.basil`, `mango_rewrite.flow`).
	*   `tools/gringo`: Mango can export Gringo files (`mango2gterm.flow`, `gringo_ops.flow`) but this is obsoleted by the native compiler.
*   **Flow9 Standard Library**: Uses `ds/` (Tree, Set, Stack, Array, List), `fs/filesystem`, `text/blueprint`, `string`, `math/math`, `net/url_parameter`.
	
## Control Flow

1.  **Initialization**: `mango.flow` parses CLI arguments.
2.  **Grammar Loading**: Reads the specified `.mango` file.
3.  **Parsing**: Parses the `.mango` file content into a `Term` AST (using the bootstrapped `mangoGrammar`).
4.  **Preprocessing**:
	*   Evaluate Functions/Includes (`evaluateMangoFunctions`).
	*   Restructure (`restructureMango`).
	*   Expand Precedence (`expandPrecedence`).
	*   Rewrite Term (`transitiveRewriteTerm`).
5.  **Analysis**:
	*   Type Inference (`inferTypes` -> `mangoTypeEval`).
	*   Exponential Behavior Check (`detectExponentialBehavior`).
6.  **Generation (based on CLI flags)**:
	*   **Compile (`--compile=1`)**: `compileMango` -> `mango2opcode` -> `optimizeMOpCode` -> `opcode2code` -> Save `_compiled_parser.flow`. Optionally generate `_linter.flow`.
	*   **Types (`--types=1` or `2`)**: `produceTypes` -> `makeTypeDefinitions` -> Save `_types.melon` or `_types.flow`.
	*   **VS Code (`--vscode=1`)**: `term2tmlanguage` -> `saveTmLanguage` -> Save extension files in `extensions/`.
	*   **Other**: Save reduced grammar (`--savereduced`), generate DOT (`--dot`), generate GTerm (`--gringo`).
7.  **Execution (optional, `--input=<file>`)**:
	*   Parses the input file using either the interpreted (`mangoParse` via `mango_interpreter`) or compiled grammar (`parseCompiledMango` via `mcode_lib` and the generated parser).
	*   Outputs result or errors. Saves output AST if `--output` is specified.

## Observations and Notes

*   This is a powerful and complex system integrating parsing, compilation, type inference, and IDE tooling.
*   The use of an intermediate representation (`MOpCode`) and static effects analysis (`opcode_effects.flow`) allows for significant optimizations in the compiled parsers.
*   The type inference system (`type/`) adds strong typing to the generated ASTs.
*   The system relies heavily on Flow9's functional nature.
*   Bootstrapping (defining Mango in Mango) is a common technique for parser generators.
*   The reliance on custom annotations (`@include`, `@highlight`, `@list`, etc.) within `.mango` files is central to its extensibility.
*   The pretty-printing inference (`pretty/`) seems less mature than other components.
*   Understanding the interaction with `poppy`, `basil`, and `gringo` would require examining those tools.
