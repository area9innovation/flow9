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
fn main() (
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
fn add(a, b) (
	a + b
);

// Single-expression function (alternative syntax)
fn multiply(a, b) = a * b;

// Function with multiple statements
fn calculateArea(width, height) (
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
let add = \a,b.a + b;

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
fn sum(n) (
	if n <= 0 then 0
	else n + sum(n - 1)
);

// Factorial function
fn factorial(n) (
	if n <= 1 then 1
	else n * factorial(n - 1)
);

// Processing lists recursively
fn length(list) (
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
let sum = fold(numbers, 0, \acc,x.acc + x);
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
fn simplify(expr : ast) (
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
```

The `ast` annotation indicates that an expression should be treated as syntax rather than being evaluated.
</ast_manipulation>

<standard_library>
Orbit has a small runtime with basic functions:

```orbit
// String functions
length("hello");    // 5
"hello" + "world";  // "helloworld"
substring(s, 0, 3); // First 3 characters

// Conversion functions
i2s(42);            // "42"
s2i("42");          // 42
i2d(5);             // 5.0
d2i(5.7);           // 5

// I/O functions
println("Hello");   // Prints to console

// Mathematical functions
abs(-5);            // 5
sqrt(16);           // 4.0
sin(3.14159 / 2);   // ~1.0
```
</standard_library>
