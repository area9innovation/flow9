# Orbit System Notation and Terminology

This table defines the preferred notation for mathematical concepts and operations within the Orbit system, aiming for consistency and alignment with Lean notation where practical, while incorporating specified user preferences and grammar capabilities.

| Concept/Operation             | Orbit Notation                 | Math Symbol (Unicode) | Lean Notation (if applicable) | Description                                                                 |
| :---------------------------- | :----------------------------- | :-------------------- | :---------------------------- | :-------------------------------------------------------------------------- |
| **Basic Arithmetic & Algebra** |                                |                       |                               |                                                                             |
| Addition                      | `a + b`                        | \\( a + b \\)           | `a + b`                       | Sum of two elements.                                                        |
| Subtraction                   | `a - b`                        | \\( a - b \\)           | `a - b`                       | Difference between two elements.                                            |
| Multiplication                | `a * b`                        | \\( a \\cdot b \\) or \\( ab \\) | `a * b`                       | Product of two elements.                                                    |
| Division                      | `a / b`                        | \\( \\frac{a}{b} \\) or \\( a/b \\) | `a / b`                       | Quotient of two elements.                                                   |
| Exponentiation                | `a ^ b`                        | \\( a^b \\)             | `a ^ b`                       | `a` raised to the power of `b`. (User Preference)                           |
| Negation (Additive Inverse)   | `-a`                           | \\( -a \\)              | `-a`                          | Additive inverse.                                                           |
| Reciprocal (Mult. Inverse)    | `a⁻¹` or `inverse(a)`        | \\( a^{-1} \\) or \\( 1/a \\) | `a⁻¹`                        | Multiplicative inverse. (Lean symbol preferred, function available)                 |
| Equality                      | `a = b`                        | \\( a = b \\)           | `a = b`                       | Equality test.                                                              |
| Inequality                    | `a ≠ b` or `a != b`            | \\( a \\neq b \\)        | `a ≠ b`                       | Inequality test. (Lean symbol preferred)                                    |
| Less Than                     | `a < b`                        | \\( a < b \\)           | `a < b`                       | Less than comparison.                                                       |
| Less Than or Equal            | `a ≤ b` or `a <= b`            | \\( a \\le b \\)         | `a ≤ b`                       | Less than or equal comparison. (Lean symbol preferred)                      |
| Greater Than                  | `a > b`                        | \\( a > b \\)           | `a > b`                       | Greater than comparison.                                                    |
| Greater Than or Equal         | `a ≥ b` or `a >= b`            | \\( a \\ge b \\)         | `a ≥ b`                       | Greater than or equal comparison. (Lean symbol preferred)                 |
| Absolute Value                | `abs(x)`                       | \\( \|x\| \\)             | `abs x`                       | Absolute value (integer/double). (User Preference `f(x)`)                 |
| Square Root                   | `sqrt(x)`                      | \\( \\sqrt{x} \\)        | `sqrt x`                      | Square root function. (User Preference `f(x)`)                             |
| Function Application          | `f(x)`, `f(a, b)`              | \\( f(x) \\)            | `f x`                         | Applying function `f` to arguments. (User Preference `f(x)`)               |
| Function Composition          | `f ∘ g`                        | \\( f \\circ g \\)       | `f ∘ g`                       | Composition of functions `f` and `g`. (Lean symbol preferred)             |
| Pi                            | `pi`                           | \\( \\pi \\)          | `Real.pi` or `π`            | Mathematical constant pi (approx 3.14159).                                |
| Euler's Number                | `e`                            | \\( e \\)             | `Real.exp 1` or `e`       | Base of the natural logarithm (approx 2.71828).                         |
| Infinity                      | `Infinity`                     | \\( \\infty \\)         | `∞` or `⊤` (context dep.) | Concept of positive infinity.                                               |
| **Logic & Set Theory**        |                                |                       |                               |                                                                             |
| Logical AND                   | `a ∧ b` or `a && b`            | \\( a \\land b \\)       | `a ∧ b`                       | Logical conjunction. (Lean symbol preferred)                                |
| Logical OR                    | `a ∨ b` or `a \|\| b`          | \\( a \\lor b \\)        | `a ∨ b`                       | Logical disjunction. (Lean symbol preferred)                                |
| Logical NOT                   | `¬a` or `!a`                   | \\( \\neg a \\)          | `¬ a`                         | Logical negation. (Lean symbol preferred)                                   |
| Implication                   | `a → b` or `a -> b`            | \\( a \\implies b \\)    | `a → b`                       | Logical implication. (Lean symbol preferred)                                |
| Equivalence (Logic)           | `a ↔ b` or `a <-> b`           | \\( a \\iff b \\)       | `a ↔ b`                       | Logical equivalence (iff). (Lean symbol preferred)                          |
| Universal Quantifier          | `∀ x: P(x)`                    | \\( \\forall x, P(x) \\) | `∀ x, P x`                  | For all `x`, property `P(x)` holds. (Lean symbol, user func style)        |
| Existential Quantifier        | `∃ x: P(x)`                    | \\( \\exists x, P(x) \\) | `∃ x, P x`                  | There exists an `x` such that `P(x)` holds. (Lean symbol, user func style) |
| Element Of                    | `x ∈ A`                        | \\( x \\in A \\)         | `x ∈ A`                       | `x` is an element of set `A`. (Lean symbol preferred)                     |
| Subset                        | `A ⊆ B`                        | \\( A \\subseteq B \\)   | `A ⊆ B`                       | Set `A` is a subset of set `B`. (Lean symbol preferred)                   |
| Union                         | `A ∪ B`                        | \\( A \\cup B \\)        | `A ∪ B`                       | Union of sets `A` and `B`. (Lean symbol preferred)                          |
| Intersection                  | `A ∩ B`                        | \\( A \\cap B \\)        | `A ∩ B`                       | Intersection of sets `A` and `B`. (Lean symbol preferred)                 |
| Set Difference                | `A \\ B`                        | \\( A \\setminus B \\)   | `A \\ B`                       | Elements in `A` but not in `B`. (Lean symbol preferred, Grammar updated)    |
| Empty Set                     | `∅`                            | \\( \\emptyset \\)       | `∅`                           | The set containing no elements. (Lean symbol preferred, Grammar updated)    |
| Cartesian Product             | `A × B`                        | \\( A \\times B \\)      | `A × B`                       | Set of all ordered pairs from `A` and `B`. (Lean symbol preferred)        |
| **Linear Algebra**            |                                |                       |                               |                                                                             |
| Vector                        | `[a, b, c]`                    | \\( \\mathbf{v} \\)      | `vector R n`                  | Ordered list (Array literal).                                               |
| Matrix                        | `[[a,b],[c,d]]`                | \\( A, \\mathbf{A} \\)   | `matrix R m n`              | Rectangular array (Array literal).                                          |
| Vector/Matrix Element Access  | `V[i]`, `M[r][c]`              | \\( v_i \\), \\( A_{rc} \\)| `v i`, `A r c`              | Standard array indexing (0-based).                                          |
| Indexing                      | `D(i, j)`                      | \\( D_{ij} \\)          | `D i j`                       | Prefers function style for specific indexing contexts.           |
| Matrix Transpose              | `Mᵀ`                           | \\( A^T \\)             | `Mᵀ`                          | Matrix transpose. (Lean symbol preferred)                                   |
| Matrix Inverse                | `M⁻¹` or `inverseM(M)`         | \\( A^{-1} \\)          | `M⁻¹`                         | Matrix inverse. (Lean symbol preferred, function available)                 |
| Matrix Multiplication         | `A * B`                        | \\( AB \\)              | `A * B`                       | Standard matrix product. (Operator preferred over `mulM`)                   |
| Dot Product                   | `u ⋅ v` or `dot_product(u, v)`        | \\( \\mathbf{u} \\cdot \\mathbf{v} \\) | `dot_product u v`      | Inner product. (Symbol preferred, function available)                       |
| Cross Product                 | `u × v` or `cross_product(u, v)`      | \\( \\mathbf{u} \\times \\mathbf{v} \\) | `cross_product u v`    | Vector cross product. (Symbol preferred, function available)              |
| Norm (Vector)                 | `‖v‖` or `norm(v)`          | \\( \\|\\mathbf{v}\\| \\)  | `norm v`                      | Magnitude/length. (Symbol preferred, function available)                    |
| Determinant                   | `det(M)`                       | \\( \\det(A) \\) or \\( |A| \\) | `matrix.det M`       | Determinant of a square matrix. (User Preference `f(x)`)                   |
| Trace                         | `tr(M)`                        | \\( \\mathrm{tr}(A) \\)  | `matrix.trace M`       | Sum of diagonal elements. (User Preference `f(x)`)                         |
| Hadamard Product              | `hadamard_product(A, B)`       | \\( A \\circ B \\)       | -                             | Element-wise matrix product. (Use function, avoid `∘`)                      |
| Kronecker Product             | `A ⊗ B` or `kronecker(A, B)`   | \\( A \\otimes B \\)     | `matrix.kronecker A B` | Kronecker tensor product. (Symbol preferred, function available)          |
| **Calculus**                  |                                |                       |                               |                                                                             |
| Derivative                    | `diff(f, x)`                   | \\( \\frac{df}{dx} \\)    | `deriv f x`                   | Derivative. (User Preference `f(x)`)                                        |
| Partial Derivative            | `∂f/∂xᵢ`                       | \\( \\frac{\\partial f}{\\partial x_i} \\) | `λ x, deriv ...`        | Partial derivative. (Symbol preferred)                                      |
| Gradient                      | `∇f` or `grad(f)`              | \\( \\nabla f \\)        | `gradient f`                  | Vector of partial derivatives. (Symbol preferred, function available)       |
| Jacobian Matrix               | `J(f)` or `jacobian(f)`        | \\( J_f \\)             | `jacobian f`                  | Matrix of first-order partial derivatives. (Symbol preferred, function available)|
| Hessian Matrix                | `H(f)` or `hessian(f)`         | \\( H_f \\)             | `hessian f`                   | Matrix of second-order partial derivatives. (Symbol preferred, function available)|
| Integral (Indefinite)         | `integrate(f, x)`              | \\( \\int f(x) \\, dx \\) | `∫ x, f x`                  | Antiderivative function. (Use function, unary `∫` for prefix)             |
| Integral (Definite)           | `integrate(f, x, a, b)`        | \\( \\int_a^b f(x) \\, dx \\) | `∫ x in a..b, f x`      | Definite integral function.                                                 |
| Summation                     | `summation(f, i, a, b)`        | \\( \\sum_{i=a}^b f(i) \\) | `∑ i in range a b, f i` | Summation function. (Use function, unary `∑` for prefix)                    |
| Limit                         | `limit(f, x, a)`               | \\( \\lim_{x \\to a} f(x) \\) | `tendsto f (at x₀)`   | Limit function.                                                             |
| **Group Theory**              |                                |                       |                               |                                                                             |
| Group Operation               | `g * h`                        | \\( g \\cdot h \\)       | `g * h`                       | Abstract group operation. (Lean symbol preferred)                           |
| Identity Element              | `1` or `e`                     | \\( e_G \\)             | `1`                           | Identity element (context dependent). (Lean symbol preferred)               |
| Inverse Element               | `g⁻¹` or `inverse(g)`        | \\( g^{-1} \\)          | `g⁻¹`                         | Inverse element. (Lean symbol preferred, Parsed via superscript, function available) |
| Group Action                  | `g • x`                        | \\( g \\cdot x \\)       | `g • x`                       | Action of `g` on `x`. (Lean symbol preferred, Grammar updated)              |
| Direct Product                | `G × H`                        | \\( G \\times H \\)      | `G × H`                       | Direct product of groups. (Lean symbol preferred)                           |
| Semi-Direct Product           | `H ⋊[φ] G`                     | \\( H \\rtimes_{\\varphi} G \\) | `H ⋊[φ] G`              | Semi-direct product. (Lean symbol preferred)                              |
| **Polynomials**               |                                |                       |                               |                                                                             |
| Leading Term                  | `leading_term(f)`              | \\( LT(f) \\)           | `leading_term f`            | Leading term function.                                                      |
| Ideal                         | `⟨f₁, f₂⟩`                     | \\( \\langle f_1, f_2 \\rangle \\) | `ideal {f₁, f₂}`      | Ideal generated by polynomials. (Symbol preferred)                          |
| Gröbner Basis                 | `groebner_basis(...)`           | \\( G \\)               | `groebner_basis I`          | Gröbner basis function.                                                     |
| Normal Form                   | `normal_form(f, G)`            | \\( NF_G(f) \\)         | `f % G`                       | Normal form function.                                                       |
| **Asymptotic Notation**       |                                |                       |                               |                                                                             |
| Big O                         | `O(f(n))`                      | \\( O(f(n)) \\)         | `is_O f g`                  | Asymptotic upper bound.                                                     |
| Big Theta                     | `Theta(f(n))`                  | \\( \\Theta(f(n)) \\)    | `is_Theta f g`              | Asymptotic tight bound.                                                     |
| Big Omega                     | `Omega(f(n))`                  | \\( \\Omega(f(n)) \\)    | `is_Omega f g`              | Asymptotic lower bound.                                                     |
| Approx Less/Equal (Tao)       | `A ≲ B`                        | \\( A \\lesssim B \\)    | -                             | \\( A \\le C B \\) for some C. (Symbol preferred, Grammar updated)             |
| Approx Equal (Tao)            | `A ∼ B`                        | \\( A \\sim B \\)        | -                             | \\( c A \\le B \\le C A \\) for c, C. (Symbol preferred, Grammar updated)      |
| **Orbit Specific**            |                                |                       |                               |                                                                             |
| Domain Annotation             | `expr : Domain`                | -                     | -                             | Associates `expr` with `Domain`.                                            |
| Negative Domain Guard         | `expr !: Domain`               | -                     | -                             | Matches if `expr` does *not* belong to `Domain`.                            |
| Rewrite Rule (Unidir)         | `lhs → rhs`                    | \\( \\rightarrow \\)      | `lhs => rhs` (Lean tactic) | Transforms `lhs` to `rhs`. (Lean symbol preferred)                          |
| Rewrite Rule (Bidir)          | `lhs ↔ rhs`                    | \\( \\leftrightarrow \\)  | `lhs = rhs` (Lean tactic)   | Declares equivalence. (Lean symbol preferred)                               |
| Entailment                    | `pattern ⊢ property`           | \\( P \\vdash Q \\)      | `P → Q`                       | If `pattern` matches, assert `property`.                                    |
| Sub-domain                    | `D1 ⊂ D2`                      | \\( D_1 \\subseteq D_2 \\) | `D₁ extends D₂`           | `D1` inherits properties from `D2`. (Symbol preferred)                      |
| AST Quoting                   | `quote(expr)`                  | \\(\\texttt{"expr"}\\)   | -                             | Prevents evaluation, yields AST.                                            |
| AST Evaluation                | `eval(expr)`                   | `\\llbracket expr \\rrbracket` | -                             | Evaluates AST `expr`.                                                       |
| N-ary S-expression Form       | `` `+`(a, b, c) ``               | -                     | -                             | Internal representation for A/C operators.                                  |
