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

# TypeScript Compilation Target

Mango can compile grammars directly to TypeScript, enabling you to use Mango-generated parsers in Node.js, web browsers, and other TypeScript/JavaScript environments. This provides a powerful alternative to Flow9 parsers when you need to integrate with JavaScript ecosystems.

## Compiling Grammars to TypeScript

To generate a TypeScript parser from your Mango grammar:

```bash
flowcpp --batch tools/mango/mango.flow -- grammar=your_grammar.mango ts=output_parser.ts types=3
```

This generates:
- **TypeScript parser**: `output_parser.ts` - Complete parser implementation
- **Type definitions**: `your_grammar_types.ts` - AST node interfaces
- **Runtime library**: `mcode_lib.ts` - Required parsing functions

### Command Options

- `ts=filename.ts`: Generate TypeScript parser with specified filename
- `types=3`: Generate TypeScript type definitions (use `types=2` for Flow types)
- `main=parser_name`: Customize the main parser function name (default: grammar filename)

## Using Generated TypeScript Parsers

### Basic Usage

```typescript
import { parseYourGrammarCompiled } from './your_grammar_parser';

const input = "your input text here";
const result = parseYourGrammarCompiled(input);

if (result.error === "") {
	console.log("Parse successful:", result.result);
	// result.result contains the typed AST
} else {
	console.log("Parse error:", result.error);
}
```

### Working with Typed ASTs

The generated TypeScript types use discriminated unions with semantic field names:

```typescript
// Generated types (your_grammar_types.ts)
export interface Choice {
	kind: 'Choice';
	left: Term;
	right: Term;
}

export interface Rule {
	kind: 'Rule';
	name: string;
	pattern: Term;
	body: Term;
}

export type Term = Choice | Rule | Variable | String | /* ... */;

// Type-safe AST processing
function processAST(node: Term): void {
	switch (node.kind) {
		case 'Choice':
			// TypeScript knows node.left and node.right exist
			processAST(node.left);
			processAST(node.right);
			break;
		case 'Rule':
			// TypeScript knows node.name, node.pattern, node.body exist
			console.log(`Rule: ${node.name}`);
			processAST(node.pattern);
			break;
		// Handle other cases...
	}
}
```

### Advanced Usage with Error Handling

```typescript
import { parseYourGrammarCompiled } from './your_grammar_parser';
import type { Term } from './your_grammar_types';

function parseWithValidation(input: string): Term | null {
	const result = parseYourGrammarCompiled(input);

	if (result.error !== "") {
		console.error(`Parse failed: ${result.error}`);
		return null;
	}

	// Type-safe result
	return result.result as Term;
}

// Usage in larger applications
const ast = parseWithValidation(userInput);
if (ast) {
	processAST(ast);
}
```

## Generated Type Features

### Semantic Field Names

The TypeScript generator creates meaningful field names based on context:

- **Binary operators**: `left` and `right` (Choice, Sequence, Precedence)
- **Unary operators**: `expression` (Star, Plus, Optional, Negate)
- **Grammar constructs**: `name`, `parameter`, `definition`, `body` (GrammarFn)
- **Constructs**: `name` and `arity` (Construct)

### Type Safety Features

- **Discriminated unions** with `kind` field for type guards
- **Full TypeScript compatibility** - no compilation errors
- **IDE auto-completion** with semantic field names
- **Type guards** for runtime type checking

```typescript
// Generated type guard functions
export function isChoice(node: any): node is Choice {
	return node && node.kind === 'Choice';
}

// Usage
if (isChoice(node)) {
	// TypeScript knows node is Choice type
	processChoice(node.left, node.right);
}
```

## Runtime Requirements

The generated TypeScript parser requires:

1. **Node.js** 14+ or modern browser environment
2. **TypeScript** 4.0+ for type checking
3. **Generated runtime library** (`mcode_lib.ts`) in the same directory

### Installing in a Project

```bash
# Copy generated files to your project
cp your_grammar_parser.ts your_project/src/
cp your_grammar_types.ts your_project/src/
cp mcode_lib.ts your_project/src/

# Or use relative imports if in the same repository
```

### Browser Usage

The generated parsers work in browsers without modification:

```html
<script type="module">
import { parseYourGrammarCompiled } from './your_grammar_parser.js';

const result = parseYourGrammarCompiled(document.getElementById('input').value);
// Use result...
</script>
```

## Self-Hosting Example

Mango can compile its own grammar to TypeScript, demonstrating the full capability:

```bash
# Compile Mango's grammar to TypeScript
flowcpp --batch tools/mango/mango.flow -- grammar=mango.mango ts=mango_self.ts types=3 main=mango_self

# The generated parser can parse Mango grammars in TypeScript environments
```

## Benefits of TypeScript Target

### vs Flow9 Parsers
- **Broader ecosystem**: Use in Node.js, browsers, React, Vue, etc.
- **Better tooling**: VS Code IntelliSense, debugging, refactoring
- **Smaller runtime**: No Flow9 runtime dependency
- **Easier deployment**: Standard JavaScript/TypeScript toolchain

### vs Hand-Written Parsers
- **Automatic generation**: No manual parser maintenance
- **Type safety**: Generated types prevent AST manipulation errors
- **Grammar-driven**: Easy to modify by changing the grammar
- **Optimized**: Generated code includes backtracking optimizations

## Performance Characteristics

Generated TypeScript parsers provide:
- **Linear time complexity** for most grammar patterns
- **Efficient backtracking** with checkpoint optimization
- **Memory efficiency** through stack management
- **Error recovery** with position tracking

Suitable for parsing files up to ~10MB efficiently.

## Integration Examples

### Express.js API

```typescript
import express from 'express';
import { parseYourGrammarCompiled } from './grammar_parser';

app.post('/parse', (req, res) => {
	const result = parseYourGrammarCompiled(req.body.input);

	if (result.error === "") {
		res.json({ success: true, ast: result.result });
	} else {
		res.status(400).json({ success: false, error: result.error });
	}
});
```

### React Component

```typescript
import React, { useState } from 'react';
import { parseYourGrammarCompiled } from './grammar_parser';

function GrammarEditor() {
	const [input, setInput] = useState('');
	const [ast, setAST] = useState(null);
	const [error, setError] = useState('');

	const handleParse = () => {
		const result = parseYourGrammarCompiled(input);
		if (result.error === "") {
			setAST(result.result);
			setError('');
		} else {
			setError(result.error);
			setAST(null);
		}
	};

	return (
		<div>
			<textarea value={input} onChange={(e) => setInput(e.target.value)} />
			<button onClick={handleParse}>Parse</button>
			{error && <div className="error">{error}</div>}
			{ast && <pre>{JSON.stringify(ast, null, 2)}</pre>}
		</div>
	);
}
```

## Using Multiple Parsers in the Same Program

When using multiple Mango-generated parsers in the same TypeScript program, you need to avoid naming conflicts between their generated types. Mango provides the `typeprefix` parameter to namespace each parser's types:

### Generating Parsers with Type Prefixes

```bash
# Generate first parser with Bool prefix
flowcpp --batch tools/mango/mango.flow -- grammar=bool_grammar.mango ts=bool_parser.ts types=3 typeprefix=Bool

# Generate second parser with Expr prefix
flowcpp --batch tools/mango/mango.flow -- grammar=expr_grammar.mango ts=expr_parser.ts types=3 typeprefix=Expr
```

### Generated Types with Prefixes

Each parser generates completely isolated type namespaces:

```typescript
// bool_types.ts - Bool parser types
export interface BoolLiteral {
	kind: 'BoolLiteral';
	value: boolean;
}
export type BoolASTNode = BoolLiteral;
export function isBoolBoolLiteral(node: any): node is BoolLiteral;

// expr_types.ts - Expr parser types
export interface ExprLiteral {
	kind: 'ExprLiteral';
	value: number;
}
export type ExprASTNode = ExprLiteral;
export function isExprExprLiteral(node: any): node is ExprLiteral;
```

### Using Multiple Parsers Together

```typescript
// Import types from different parsers - no conflicts!
import type { BoolASTNode } from './bool_types';
import type { ExprASTNode } from './expr_types';
import { parseBoolCompiled } from './bool_parser';
import { parseExprCompiled } from './expr_parser';
import { isBoolBoolLiteral } from './bool_types';
import { isExprExprLiteral } from './expr_types';

interface MultiParserApp {
	boolResult: BoolASTNode | null;
	exprResult: ExprASTNode | null;
}

function parseInputs(boolInput: string, exprInput: string): MultiParserApp {
	const boolResult = parseBoolCompiled(boolInput);
	const exprResult = parseExprCompiled(exprInput);

	return {
		boolResult: boolResult.error === "" ? boolResult.result : null,
		exprResult: exprResult.error === "" ? exprResult.result : null
	};
}

// Type-safe processing of each parser's results
function processBoolResult(node: BoolASTNode): void {
	if (isBoolBoolLiteral(node)) {
		console.log(`Boolean: ${node.value}`);
	}
}

function processExprResult(node: ExprASTNode): void {
	if (isExprExprLiteral(node)) {
		console.log(`Expression: ${node.value}`);
	}
}
```

### Benefits of Type Prefixing

- ✅ **No naming conflicts** between multiple parsers
- ✅ **Complete type isolation** - each parser has its own namespace  
- ✅ **Type-safe composition** - combine different languages safely
- ✅ **IDE support** - auto-completion works correctly for each parser
- ✅ **Maintainable** - clear separation between different grammar types

### Best Practices for Multiple Parsers

1. **Always use descriptive typeprefixes**: `JSON`, `SQL`, `CSS`, etc.
2. **Keep parsers in separate files**: `json_parser.ts`, `sql_parser.ts`
3. **Import types explicitly**: Import only what you need from each parser
4. **Use distinct file naming**: Include the grammar name in generated files

This approach allows you to build complex applications that parse multiple domain-specific languages while maintaining full type safety and avoiding any naming conflicts.

The TypeScript compilation target makes Mango parsers accessible to the vast JavaScript ecosystem while maintaining the type safety and correctness of the original Flow9 implementation.

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
*   `tests/`: Contains test cases for the Mango grammar and its components.
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

## Creating VS Code Extensions with Mango

Mango can automatically generate VS Code extensions that provide syntax highlighting, bracket matching, and custom commands for languages defined in your `.mango` grammars.

### Generating a VS Code Extension

#### Step 1: Create and annotate your grammar

Create your `.mango` grammar file with appropriate annotations for syntax highlighting, bracket matching, etc. (see examples below).

#### Step 2: Compile the grammar with VS Code extension generation

Use the Mango compiler with the `vscode=1` flag to generate a VS Code extension:

```bash
flowcpp --batch tools/mango/mango.flow -- grammar=your_grammar.mango vscode=1
```

This generates all necessary extension files in the `extensions/` directory (typically `extensions/area9.your_grammar_name-1.0.0/`).

#### Step 3: Compile your extension (optional)

If you want to package your extension for distribution:

1. Navigate to the generated extension directory:
   ```bash
	 cd extensions/area9.your_grammar_name-1.0.0/
```

2. Install the necessary VS Code Extension development tools if you haven't already:
   ```bash
	 npm install -g @vscode/vsce
```

3. Package your extension:
   ```bash
	 vsce package
```

   This will create a `.vsix` file that can be distributed and installed by other users.

The generated extension includes:
- Syntax highlighting definitions based on your `@highlight` annotations
- Bracket matching configuration from your `@bracket` annotations
- Comment toggling support using your `@linecomment` and `@blockcomment` definitions
- Custom commands defined by your `@vscommand` annotations

### Annotating Your Grammar for VS Code

To customize the VS Code extension, add annotations to your Mango grammar file:

#### Syntax Highlighting

Use the `@highlight` annotation to specify which grammar rules should be highlighted and how:

```mango
@include<highlight>
@highlight<ws "comment.block">
@highlight<id "variable.parameter">
@highlight<uid "entity.name.function">
@highlight<int "constant.numeric">
@highlight<string "string.quoted.double">
```

The highlighting class names follow TextMate naming conventions.

#### Bracket Matching

Define matching brackets with the `@bracket` annotation:

```mango
@bracket<"(" ")">
@bracket<"[" "]">
@bracket<"{" "}">
```

#### Comment Support

Specify line and block comments for your language:

```mango
@linecomment<"//">
@blockcomment<"/*" "*/">
```

#### Custom Commands

Add custom commands that can be triggered from VS Code:

```mango
@vscommand<"Grammar check" "mango grammar=${relativeFile}" "F7">
```

This defines a command named "Grammar check" that will execute the command `mango grammar=${relativeFile}` when the F7 key is pressed.

### Installing and Using the Extension

#### Option 1: Install from local directory

1. Copy the generated extension from `extensions/area9.your_grammar_name-1.0.0/` to your VS Code extensions directory:
   - Windows: `%USERPROFILE%\.vscode\extensions\`
   - macOS/Linux: `~/.vscode/extensions/`

2. Restart VS Code.

#### Option 2: Install from VSIX file (if you packaged the extension)

1. In VS Code, open the Command Palette (Ctrl+Shift+P or Cmd+Shift+P)
2. Type "Extensions: Install from VSIX"
3. Browse to and select your .vsix file

#### Option 3: Install without copying (for development)

For testing during development, you can also directly use the extension without copying:

1. In VS Code, go to the Extensions view (Ctrl+Shift+X)
2. Click the "..." menu in the top-right of the Extensions view
3. Select "Install from Location..."
4. Browse to your extension's directory

#### Using the extension

Once installed, open a file that matches your language extension. VS Code will automatically detect the file type based on the extension configuration and apply the syntax highlighting and other features.

### Example

Here's a complete example that defines syntax highlighting for a Mango grammar:

```mango
@include<highlight>
@highlight<id "variable.parameter">
@highlight<uid "entity.name.function">
@highlight<int "constant.numeric">
@highlight<string "string.quoted.double">
@highlight<stringq "string.quoted.single">
@highlight<char "constant.character">
@highlight<ws "comment.block">
@bracket<"(" ")">
@linecomment<"//">
@blockcomment<"/*" "*/">
@vscommand<"Mango check" "mango grammar=${relativeFile}" "F7">
```

This will create a VS Code extension with syntax highlighting for identifiers, uppercase identifiers, numeric constants, strings, characters, and comments, along with bracket matching and a custom F7 command.

## Observations and Notes

*   This is a powerful and complex system integrating parsing, compilation, type inference, and IDE tooling.
*   The use of an intermediate representation (`MOpCode`) and static effects analysis (`opcode_effects.flow`) allows for significant optimizations in the compiled parsers.
*   The type inference system (`type/`) adds strong typing to the generated ASTs.
*   The system relies heavily on Flow9's functional nature.
*   Bootstrapping (defining Mango in Mango) is a common technique for parser generators.
*   The reliance on custom annotations (`@include`, `@highlight`, `@list`, etc.) within `.mango` files is central to its extensibility.
*   The pretty-printing inference (`pretty/`) seems less mature than other components.
*   Understanding the interaction with `poppy`, `basil`, and `gringo` would require examining those tools.
