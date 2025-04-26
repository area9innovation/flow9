# Teaching Orbit Programming Language

<overview>
Orbit is a functional programming language designed as a domain-unified rewriting engine that bridges mathematical formalism and practical programming.
</overview>

<language_characteristics>
- **Functional paradigm**: Orbit is purely functional with immutable variables
- **No loops or returns**: No `while`, `for`, or `return` keywords (use recursion instead)
- **Sequence notation**: Uses `()` and `;` as sequence operators instead of `{}`
- **Pattern matching**: Uses `is` syntax for pattern matching
- **No static typing**: Dynamic type system
- **Math-inspired**: Syntax designed to resemble mathematical notation
- **AST manipulation**: First-class support for abstract syntax trees
</language_characteristics>

<basic_syntax>
Orbit programs use parentheses for grouping statements and semicolons as separators:

```orbit
// This is a basic Orbit program
fn main() = (
	let x = 5;
	let y = 10;
	let result = x + y;
	println("The result is: " + i2s(result))
);
```

Comments use C-style `//` for single line comments or `/* ... */`.
</basic_syntax>

<variables_and_expressions>
Variables in Orbit are immutable - once assigned, they cannot be changed. Variable binding uses the `let` keyword:

```orbit
let x = 42;               // Integer
let pi = 3.14159;         // Double
let greeting = "Hello";   // String
let isActive = true;      // Boolean
let tuple = Pair(1, 2);   // Constructor

// Expressions
let sum = x + 10;
let message = greeting + " World";
```

CRITICAL: Unlike some languages, Orbit variables cannot be reassigned. Once a value is bound to a name, that binding cannot be changed.

CRITICAL: Variables are lowercase. We reserve uppercase for constructors and types.

Incorrect (will cause errors):
```orbit
let counter = 0;
counter = counter + 1;  // ERROR: Cannot reassign to immutable binding
```

Correct approach (use new variables or recursion):
```orbit
let counter = 0;
let newCounter = counter + 1;  // Create a new binding
```
</variables_and_expressions>

<functions>
Functions in Orbit are defined using the `fn` keyword, followed by the function name, parameters, and body:

```orbit
// Basic function definition
fn add(a, b) = (
	a + b
);

// Single-expression function (alternative syntax)
fn multiply(a, b) = a * b;

// Function with multiple statements
fn calculateArea(width, height) = (
	let area = width * height;
	println("Calculating area: " + i2s(width) + " * " + i2s(height));
	area  // Last expression is the return value
);
```

IMPORTANT: Orbit NEVER uses a `return` keyword. The last expression in a function body is automatically the result.
</functions>

<lambdas>
Lambda functions (anonymous functions) use the backslash syntax:

```orbit
// Lambda syntax with one parameter
let increment = \x.x + 1;

// Lambda with multiple parameters
let add = \(a, b).a + b;

// Using lambdas as arguments
let doubled = map([1, 2, 3], \x.x * 2);
```
</lambdas>

<conditionals>
Orbit uses `if` expressions for conditional logic:

```orbit
// Basic if expression
let max = if a > b then a else b;

// If with multiple statements in branches
let category = if (score >= 90) then (
	println("Excellent!");
	"A"
) else if (score >= 80) then (
	println("Good job!");
	"B"
) else (
	println("Keep trying!");
	"C"
)
```

Conditions don't require parentheses, but they're often used for clarity:

```orbit
// Parentheses are optional
let isPositive = if x > 0 then true else false;
```
</conditionals>

<pattern_matching>
One of Orbit's most powerful features is pattern matching using the `is` keyword:

```orbit
// Pattern matching with is
expr is (
	0 => "Zero";
	1 => "One";
	n + 1 => "One more than " + i2s(n);
	_ => "Something else"
)

// Pattern matching with constructors
shape is (
	Circle(r) => 3.14159 * r * r;
	Rectangle(w, h) => w * h;
	Triangle(b, h) => 0.5 * b * h;
	_ => 0
)

// Pattern matching with conditions
expr is (
	n => "Positive" if n > 0;
	n => "Negative" if n < 0;
	_ => "Zero"
)
```

Pattern matching can be used for destructuring:

```orbit
point is (
	Point(x, y) => "x: " + i2s(x) + ", y: " + i2s(y);
	_ => "Not a point"
)
```
</pattern_matching>

<data_construction>
Orbit uses a simple constructor syntax to create structured data:

```orbit
// Creating values with constructors
let point = Point(10, 20);
let person = Person("John", 30, true);
let nested = Pair(Point(1, 2), Point(3, 4));

// Accessing fields
point is (
	Point(x, y) => "The x-coordinate is " + i2s(x)
)

// Alternatively:
let getName = \p -> p is (Person(name, _, _) => name);
let age = person is (Person(_, a, _) => a);
```

There is no special class or struct declaration - constructors are defined implicitly when used.
</data_construction>

<recursion>
Since Orbit has no loops, recursion is the primary method for iteration:

```orbit
// Sum numbers from 1 to n using recursion
fn sum(n) = (
	if n <= 0 then 0
	else n + sum(n - 1)
);

// Factorial function
fn factorial(n) = (
	if n <= 1 then 1
	else n * factorial(n - 1)
);

// Processing lists recursively
fn length(list) = (
	list is (
		Nil() => 0;
		Cons(_, tail) => 1 + length(tail)
	)
)
```
</recursion>

<arrays>
Orbit supports arrays:

```orbit
// Array syntax
let numbers = [1, 2, 3, 4, 5];
let empty = [];
let nested = [[1, 2], [3, 4]];

// Array operations
let first = numbers[0];
let length = length(numbers);
let combined = [1, 2] + [3, 4];  // [1, 2, 3, 4]
```

Common array operations:

```orbit
// Map: Transform each element
let doubled = map(numbers, \x.x * 2);

// Filter: Keep elements that match a predicate
let evens = filter(numbers, \x.x % 2 == 0);

// Fold: Accumulate values
let sum = fold(numbers, 0, \(acc, x).acc + x);
```
</arrays>

<math_operations>
Orbit has rich support for mathematical operations:

```orbit
// Basic arithmetic
let sum = a + b;
let difference = a - b;
let product = a * b;
let quotient = a / b;
let remainder = a % b;
let power = a ^ b;  // Exponentiation

// Comparisons
let equal = a = b;
let notEqual = a != b;
let less = a < b;
let lessOrEqual = a <= b;
let greater = a > b;
let greaterOrEqual = a >= b;

// Logical operators
let and = p && q;
let or = p || q;
let not = !p;
```

Orbit also supports more advanced mathematical notation:

```orbit
// Set operations
let union = A ∪ B;       // Union
let intersection = A ∩ B; // Intersection

// Logic symbols
let forall = ∀ x: P(x);  // Universal quantifier
let exists = ∃ x: P(x);  // Existential quantifier
```
</math_operations>

<import>
```orbit
import lib/sort;
```
</import>

<running_and_debugging>
## Running and Debugging Orbit Programs

### Running a Single Orbit Program

To run a single Orbit program, use the Flow compiler with the orbit.flow file as the entry point:

```bash
flow9/lib/tools/orbit> flowcpp --batch orbit.flow -- path/to/yourprogram.orb
```

### Program Execution Model

Unlike some programming languages, Orbit does not automatically run any main function when a program is loaded. You need to explicitly call any function you want to execute. This makes Orbit more similar to Python and other scripting languages where code at the top level is executed as it's encountered.

For example, if you want a program to do something when it runs, you need to have executable statements at the top level or call your main function explicitly:

```orbit
// Define a main function
fn main() = (
	println("Hello, world!")
);

// Call it explicitly to execute it
main();

// Alternatively, have executable statements at the top level
println("This will execute when the file is loaded");

// The last expression's value becomes the program's return value
0;  // Return 0 as the program result
```

### Tracing Program Execution

Orbit provides a detailed tracing feature that shows all steps of interpretation, which is invaluable for debugging and understanding program execution. To enable tracing, add the `trace=1` parameter:

```bash
flowcpp --batch orbit.flow -- trace=1 path/to/yourprogram.orb
```

### Pretty Printing Orbit Programs

Orbit provides a command-line flag to pretty print the parse tree of a program without executing it. This is useful for understanding how your code is parsed and structured.

To pretty print an Orbit program, use the `pretty=1` parameter:

```bash
flowcpp --batch orbit.flow -- pretty=1 path/to/yourprogram.orb
```
</running_and_debugging>

<ast_manipulation>
Orbit has powerful capabilities for working with abstract syntax trees (ASTs):

```orbit
// Quote an expression (prevent evaluation)
fn quote(e : ast) = e;

// Create an AST
let expr = quote(a + b * c);

// Pattern match on AST structure
expr is (
	a + b => "Addition";
	a * b => "Multiplication";
	a - b => "Subtraction";
	_ => "Other expression"
)

// Transform an AST
fn simplify(expr : ast) = (
	expr is (
		a + 0 => a;
		0 + a => a;
		a * 1 => a;
		1 * a => a;
		a * 0 => 0;
		0 * a => 0;
		_ => expr
	)
)

// Pretty print an AST
println(prettyOrbit(expr));

// Programmatically construct AST nodes
let addExpr = makeAst("+", [a, b]);        // Creates the AST for a + b
let condition = makeAst("<", [x, 10]);     // Creates the AST for x < 10
let ifExpr = makeAst("if", [condition,     // Creates a complete if expression
													makeAst("*", [x, 2]),
													x]);
```

The `ast` annotation indicates that an expression should be treated as syntax rather than being evaluated.

### Using eval() with AST parameters

Normally, when a function parameter is marked with `:ast`, the corresponding argument is not evaluated before being passed to the function. However, you can selectively evaluate parts of an AST argument using the `eval()` function:

```orbit
// Function that works with AST
fn is_number(expr : ast) = (astname(expr) == "Int" || astname(expr) == "Double");

// Function that selectively evaluates parts of its AST argument
fn is_complex_expr(expr : ast) = (
	// eval() causes its argument to be evaluated, even within an AST context
	is_number(eval(expr)) ||
	expr is (
		a * b => is_complex_expr(eval(a)) && is_complex_expr(eval(b));
		_ => false
	)
);

// Usage
println(is_complex_expr(x^2));        // Evaluates parts of the expression
println(is_complex_expr(quote(x^2)));  // Keeps the expression as quoted AST
```

This capability allows for powerful hybrid approaches where you can manipulate expressions structurally while selectively evaluating parts of them.

### Using makeAst() to Construct AST Nodes

Orbit provides a convenient function for programmatically constructing AST nodes:

```orbit
// Create an AST node with a specific operator and arguments
makeAst(op : string, args : [*]) -> ast
```

This function lets you build AST nodes dynamically, which is useful for code generation, transformations, and metaprogramming.

#### Examples

```orbit
// Create basic arithmetic expressions
let addExpr = makeAst("+", [x, y]);       // Equivalent to x + y
let mulExpr = makeAst("*", [a, b]);       // Equivalent to a * b

// Create function calls
let fnCall = makeAst("call", [fnName, arg1, arg2]);  // Equivalent to fnName(arg1, arg2)

// Create control flow structures
let condition = makeAst("<", [x, 10]);
let ifExpr = makeAst("if", [condition, thenBlock, elseBlock]);

// Create arrays
let arrayExpr = makeAst("Array", [1, 2, 3]);  // Equivalent to [1, 2, 3]

// Chain operations
let expr = makeAst("+", [
	makeAst("*", [a, b]),
	makeAst("/", [c, d])
]); // Equivalent to (a * b) + (c / d)
```

#### Supported Operators

The `makeAst` function supports all standard operators in Orbit, including:

- Arithmetic: `"+"`, `"-"`, `"*"`, `"/"`, `"%"`, `"^"`
- Comparison: `"="`, `"!="`, `"<"`, `"<="`, `">"`, `">="`
- Logical: `"&&"`, `"||"`, `"!"`
- Collections: `"Array"`, `"SetLiteral"`
- Control flow: `"if"`, `"seq"`
- Function calls: `"call"`

For constructors and identifiers, you can create them directly:

```orbit
// Create a constructor call: Point(10, 20)
let point = makeAst("call", [makeAst("Identifier", [], "Point"), 10, 20]);
```

### Using gather() and scatter() for Expression Transformation

Orbit provides special functions for transforming between nested binary operations and array-based representations:

```orbit
// gather: Converts nested binary operations into a function call with an array of operands
fn gather(expr : ast, template : ast) -> ast;

// scatter: Converts a function call with an array of operands back into binary operations
fn scatter(expr : ast) -> ast;
```

#### gather

`gather` transforms nested binary operations (like addition or multiplication) into a function call with an array of arguments. It "flattens" a chain of associative binary operations into a single function call, normalizing different groupings of the same operation.

For example, both `(a + b) + c` and `a + (b + c)` will be gathered into the same representation: ``+``([a, b, c]). This leverages the associative property of operations like addition and multiplication.

```orbit
// Gather addition operations
let expr = quote(a + b + c);
let gathered = gather(expr, `+`);
// Result: `+`([a, b, c])

// Different groupings yield the same gathered form
let expr1 = quote((1 + 2) + 3);
let expr2 = quote(1 + (2 + 3));
let gathered1 = gather(expr1, `+`);
let gathered2 = gather(expr2, `+`);
// Both result in: `+`([1, 2, 3])
```

#### scatter

`scatter` is the inverse of `gather`. It transforms a function call with an array of arguments back into a chain of binary operations with a specific grouping (left-to-right by default).

```orbit
// Converting back to binary operations
let expr = quote(`+`([a, b, c]));
let scattered = scatter(expr);
// Result: (a + b) + c (left-to-right grouping)

// Works with multiplication
let expr2 = quote(`*`([a, b, c, d]));
let scattered2 = scatter(expr2);
// Result: ((a * b) * c) * d (left-to-right grouping)

// Works with other operators too
let expr3 = quote(`^`([2, x]));
let scattered3 = scatter(expr3);
// Result: 2^x
```

#### Extracting Arguments with Pattern Matching

One of the most powerful use cases for `gather` and `scatter` is their ability to work with pattern matching to extract arguments from expressions. This allows you to peel apart and recombine AST nodes easily:

```orbit
// Define a function that doesn't evaluate its argument
fn quote(e : ast) = e;

// Extract all arguments from a chained OR expression
let asCall = gather(quote(a||c||b), `||`);
println(prettyOrbit(asCall));
// Output: `||`([a, c, b])

// Pattern match to extract the arguments
let arguments = asCall is (`||`(args) => args);
println(prettyOrbit(arguments));
// Output: [a, c, b]

// Reconstruct the binary expression
let back = scatter(asCall);
println(prettyOrbit(back));
// Output: ((a ∨ c) ∨ b)
```

This approach makes it easy to:
- Extract all operands from a chain of operations
- Process each operand individually 
- Reconstruct the expression with modified operands
- Transform between different operator representations

These functions are particularly useful for:
- Normalizing expressions for comparison
- Simplifying pattern matching
- Implementing mathematical algorithms
- Expression optimization
- Manipulating and transforming AST structures
</ast_manipulation>

<runtime_functions>
Orbit provides a comprehensive set of built-in runtime functions. These are the core functions available in the language:

## Unique ID Generation
```orbit
uid(prefix : string) -> string   // Generate a unique ID with prefix (e.g., "button0", "button1")
```

## Math Functions
```orbit
// Trigonometric functions
sin(x : double) -> double        // Sine function
cos(x : double) -> double        // Cosine function
tan(x : double) -> double        // Tangent function
asin(x : double) -> double       // Arc sine (inverse sine)
acos(x : double) -> double       // Arc cosine (inverse cosine)
atan(x : double) -> double       // Arc tangent (inverse tangent)
atan2(y : double, x : double) -> double  // Two-argument arc tangent

// Exponential and logarithmic functions
sqrt(x : double) -> double       // Square root
exp(x : double) -> double        // Exponential function (e^x)
log(x : double) -> double        // Natural logarithm (base e)
log10(x : double) -> double      // Base-10 logarithm

// Power functions
pow(base : int, exp : int) -> int       // Integer power
dpow(base : double, exp : double) -> double  // Double power

// Rounding functions
round(x : double) -> int         // Round to nearest integer
floor(x : double) -> int         // Round down to nearest integer
ceil(x : double) -> int          // Round up to nearest integer
dround(x : double) -> double     // Round to nearest double
dfloor(x : double) -> double     // Round down to nearest double
dceil(x : double) -> double      // Round up to nearest double

// Number properties
abs(x : double) -> double        // Absolute value for doubles
iabs(x : int) -> int             // Absolute value for integers
sign(x : double) -> double       // Sign of a number (-1.0, 0.0, or 1.0)
isign(x : int) -> int            // Sign of an integer (-1, 0, or 1)
even(x : int) -> bool            // Check if number is even
odd(x : int) -> bool             // Check if number is odd

// Modular arithmetic
mod(a : int, b : int) -> int     // Integer modulo (always non-negative)
dmod(a : double, b : double) -> double  // Double modulo (always non-negative)

// Special functions
factorial(n : int) -> int        // Factorial function
gcd(a : int, b : int) -> int     // Greatest common divisor
lcm(a : int, b : int) -> int     // Least common multiple

// Min/max functions
max(a : *|double, b : *|double) -> *|double  // Maximum of two values
min(a : *|double, b : *|double) -> *|double  // Minimum of two values
```

## Comparison Operations
```orbit
<=> (a : *, b : *) -> int      // Compare: -1 if a<b, 0 if a=b, 1 if a>b
```

## Type Conversion
```orbit
i2s(x : int) -> string         // Convert integer to string
d2s(x : double) -> string      // Convert double to string
i2b(x : int) -> bool           // Convert integer to boolean (0=false, otherwise true)
b2i(x : bool) -> int           // Convert boolean to integer (false=0, true=1)
s2i(x : string) -> int         // Convert string to integer
s2d(x : string) -> double      // Convert string to double
```

## Type Checking
```orbit
isBool(x : *) -> bool          // Check if value is a boolean
isInt(x : *) -> bool           // Check if value is an integer
isDouble(x : *) -> bool        // Check if value is a double
isString(x : *) -> bool        // Check if value is a string
isArray(x : *) -> bool         // Check if value is an array
isConstructor(x : *) -> bool   // Check if value is a constructor
```

## String Operations
```orbit
strlen(s : string) -> int           // Get string length
strIndex(s : string, sub : string) -> int  // Find index of substring
substring(s : string, start : int, len : int) -> string  // Extract substring
strContainsAt(s : string, sub : string, pos : int) -> bool  // Check if string contains substring at position
strGlue(arr : [string], separator : string) -> string  // Join strings with separator
string2ints(s : string) -> [int]    // Convert string to array of character codes
ints2string(arr : [int]) -> string  // Convert array of character codes to string
escape(s : string) -> string        // Escape special characters in string
unescape(s : string) -> string      // Unescape special characters in string
parsehex(s : string) -> int         // Parse hexadecimal string to integer
capitalize(s : string) -> string    // Capitalize first letter of string
decapitalize(s : string) -> string  // Decapitalize first letter of string
```

## Array Operations
```orbit
length(arr : [*]) -> int            // Get array length
reverse(arr : [*]) -> [*]           // Reverse array
subrange(arr : [*], start : int, len : int) -> [*]  // Extract subarray
list2array(list : *) -> [*]         // Convert list to array
```

## Constructor Operations
```orbit
getConstructor(x : *) -> string     // Get constructor name of value
getField(obj : *, field : int) -> *  // Get field from constructor by index
setField(obj : *, field : int, value : *) -> *  // Set field in constructor by index
```

## AST Manipulation
```orbit
prettyOrbit(expr : ast) -> string   // Format an AST expression as readable code
makeAst(op : string, args : [*]) -> ast  // Construct an AST node with the given operator and arguments
```

## Input/Output
```orbit
println(s : string) -> void         // Print string with newline
```

Note: In the type signatures above:
- `*` represents any type
- `int|double` means either an integer or a double
- `[*]` represents an array of any type
- The actual behavior of operators may depend on the types of their operands
</runtime_functions>

<stdlib>
This document summarizes the standard library modules provided for the Orbit language, located in `orbit/lib`.

*   **`array.orb`:** Provides common functional utilities for arrays like `map`, `filter`, `fold`, `take`, `iter`, `contains`, `uniq`, etc., including versions with index access (`mapi`, `filteri`, `foldi`).
*   **`bdd.orb`:** Implements Binary Decision Diagrams (BDDs) for representing and manipulating Boolean formulas efficiently. Includes functions for creation (`to_bdd`), logical operations (`apply_and`, `apply_or`, `negate_bdd`), conversion back (`from_bdd`), equivalence checking, quantification, and model counting.
*   **`booth.orb`:** Contains Booth's algorithm for finding the lexicographically smallest cyclic shift (canonical form) of an array in linear time.
*   **`combinatorics.orb`:** Offers basic combinatorial functions: `factorial`, `binomial_coefficient`, `permutations`, and functions to generate permutations and combinations of array elements.
*   **`complex.orb`:** Defines complex number arithmetic, including addition, subtraction, multiplication, division, magnitude, argument, conjugate, exponentiation, logarithm, and power functions. Uses `Complex(real, imag)` representation.
*   **`glex_order.orb`:** Implements Graded Lexicographic (GLEX) ordering for rewriting polynomial expressions. Sorts terms first by total degree, then lexicographically. Handles basic and compound variables.
*   **`linalg.orb`:** Basic linear algebra library for vectors (arrays) and matrices (arrays of arrays). Includes vector addition, subtraction, scaling, dot product, norm; matrix creation, element access, addition, scaling, transpose, multiplication, determinant, and inverse.
*   **`logic.orb`:** Implements conversion of logical expressions to Conjunctive Normal Form (CNF) and Disjunctive Normal Form (DNF) using rewrite rules, and simplification techniques.
*   **`number_theory.orb`:** Provides number theoretic functions such as primality testing (`is_prime`), Greatest Common Divisor (`gcd`), Least Common Multiple (`lcm`), Extended Euclidean Algorithm (`extended_gcd`), modular inverse (`mod_inverse`), modular exponentiation (`modPow`), and prime factorization (`prime_factorization`).
*   **`polynomials.orb`:** A library for symbolic manipulation of polynomials using GLEX ordering. Defines internal representations for monomials, terms, and polynomials. Includes addition, subtraction, multiplication, division (`divP`), evaluation (`evalP`), degree finding (`degreeP`), and differentiation (`differentiateP`).
*   **`reflect.orb`:** Contains reflection utilities for working with Abstract Syntax Trees (ASTs), such as quoting (`quote`), type checks (`is_number`, `is_var`), degree calculation (`term_degree`), and AST construction (`makeFoldedAst`).
*   **`rewrite.orb`:** A core library for applying rewrite rules to Orbit OGraphs. Provides functions for pattern matching (`matchOGraphPattern`), rule application (`applyRewriteRule`, `applyRules`), and fixed-point iteration (`applyRulesUntilFixedPoint`).
*   **`sort.orb`:** Implements a stable merge sort (`mergeSort`) algorithm, allowing custom comparison functions. Includes a standard `sort` using default comparison.
*   **`statistics.orb`:** Offers basic statistical functions like `mean`, `variance`, `standard_deviation`, `median`, approximations for the normal distribution PDF/CDF (`normal_pdf`, `normal_cdf`), and `correlation`.
</stdlib>
