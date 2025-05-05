# Estimate Verification in Orbit (Tao-Inspired) - v2

This proposal address the verification of asymptotic estimates (`A ≤ C*B` or `A ≪ B`) as described by Terry Tao, leveraging Orbit's O-graph, domain system, rewriting, and canonicalization capabilities.

https://terrytao.wordpress.com/2025/05/01/a-proof-of-concept-tool-to-verify-estimates/

**1. Core Problem Mapping to Orbit:**

*   **Goal:** Automate the verification of inequalities like `A ≤ C*B` (denoted `A ≲ B`) or `A ∼ B` (comparable up to constants), where expressions involve positive real parameters, arithmetic operations (+, *, /, ^), max/min, and potentially functional dependencies, often holding only for "sufficiently large" parameters.
*   **Orbit Approach:** Represent expressions and estimates in the O-graph. Use domain annotations to track properties (parameter dependencies, positivity). Use rewrite rules for simplification, case splitting, and verification logic, **including a core strategy based on logarithmic transformation and linear programming**. Canonical forms simplify sub-expressions.

**2. Representation in the O-Graph:**

*   **Expressions:** Standard Orbit ASTs for arithmetic (`+`, `*`, `/`, `^`), comparison.
    *   Introduce `Max(args...)`, `Min(args...)`, `Median(args...)` constructors. Sₙ canonicalization on the arguments (`args`) can help simplify these (e.g., `Max([a,b,c])` after sorting `[a,b,c]` trivially identifies the max).
    *   Handle `<N> = (1+N²)¹ᐟ²` via a specific function/constructor or simplification rules.
*   **Estimates & Assumptions:**
    *   `ApproxLE(A: ast, B: ast)`: Represents `A ≲ B`. Semantically, `∃ C: AbsoluteConstant, LE(A, C*B)`.
    *   `ApproxGE(A: ast, B: ast)`: Represents `A ≳ B`.
    *   `ApproxEq(A: ast, B: ast)`: Represents `A ∼ B`.
    *   `Assumption(estimate: ast)`: Represents given constraints, e.g., `Assumption(ApproxEq(Max(N1,N2,N3), N))`.
    *   `Verify(estimate: ast, assumptions: [Assumption])`: The top-level node representing the verification task.
*   **Target Nodes:** Canonical `TrueEstimate`, `FalseEstimate`.

**3. Domain Annotations (Refined):**

*   **`Parameter(N: symbol)`:** Identifies primary parameters (like `N`, `ε`).
*   **`AbsoluteConstant`:** For explicit numbers or symbols (like `π`, `e`) independent of all parameters.
*   **`PositiveReal`:** Assume all variables/parameters are positive unless stated otherwise. (Crucial for log transforms, division).
*   **`DependsOn(N: symbol)` / `IndependentOf(N: symbol)`:** Track functional dependencies (potential extension beyond Tao's code).
*   **`CaseContext(assumptions: [ast])`:** A domain attached *during* rewriting to track the current set of case-specific assumptions (e.g., `CaseContext([ApproxGE(a,b), ApproxGE(a,c)])`). This enables conditional rules based on the current case.
*   **`SufficientlyLarge(N: symbol)`:** Gates rules holding only for large `N`.
*   **(Advanced) `FunctionSpace(Type)`**: e.g., `FunctionSpace(Lp(p))`, `FunctionSpace(Sobolev(s,p))`.
*   **(Advanced) `Norm(Function, Space)`**: e.g., `Norm(f, Lp(2))`.

**4. Core Verification Strategy: Log-Transform and Linear Programming**

Inspired by Tao's Python code, a primary strategy for verifying multiplicative estimates like `ApproxLE(A, B)` involves:

1.  **Transformation:** Convert the goal `A ≲ B` to checking `B/A ≳ 1` (ignoring constants).
2.  **Simplification:** Simplify the expression `E = B/A` using algebraic rules and any assumptions active in the current case context (see below).
3.  **Monomial Extraction:** Extract the multiplicative structure of the simplified `E` into a dictionary of terms and their exponents: `{term₁: exp₁, term₂: exp₂, ...}`. Orbit needs a function `extract_monomials(expr: ast) -> Dict[ast, double]` analogous to Tao's `monomials` function. This extraction must treat non-multiplicative structures (like `Max`, `Min`, or unevaluated additions) as base terms.
4.  **Logarithmic View:** Conceptually, take the logarithm. The goal becomes proving `log(E) ≥ 0`. The monomials `term^exponent` transform to `exponent * log(term)`. The available assumptions (`U ≲ V` or `U ∼ V`) transform to `log(V) - log(U) ≥ 0`.
5.  **Linear Programming Setup:** Formulate an LP problem:
    *   **Variables:** Non-negative weights `wᵢ` associated with each log-transformed assumption `log(Vᵢ) - log(Uᵢ) ≥ 0` available in the current context.
    *   **Constraints:** For each base `termⱼ` appearing in the monomials of `E`, enforce the constraint `Σᵢ wᵢ * (exponent_of_termⱼ_in_Vᵢ - exponent_of_termⱼ_in_Uᵢ) = exponent_of_termⱼ_in_E`. That is, the weighted sum of log-differences from the assumptions must exactly reconstruct the required log-term `exponent * log(term)` for each term in the target expression `E`.
    *   **Objective:** Minimize `Σ wᵢ` (or any dummy objective).
6.  **LP Solving:** Call an integrated LP solver. If a feasible solution exists (the constraints can be satisfied with non-negative weights), the original inequality `A ≲ B` holds true within the current case context.
7.  **Integration:** This strategy can be implemented via dedicated Orbit functions called by rewrite rules, or potentially encoded as a series of rewrite rules that transform the `Verify` node into an `LP_Check(monomials, assumptions)` node, which then calls the solver.

**5. Rewrite Rules & Strategy (Supporting the LP Approach):**

Rewrite rules are still essential for simplification and managing the overall process.

*   **Simplification:**
    *   Standard algebraic rules (commutativity, associativity, distributivity, exponents) operating on sub-expressions.
    *   *Tao-specific Simplifications:*
```orbit
		// Rule for A+B ∼ Max(A,B) for positive A,B
		A+B → ApproxEq(A+B, Max(A,B)) if A:PositiveReal ∧ B:PositiveReal

		// Rule for <N> ∼ N for large N
		FuncApp("<>", [N]) → ApproxEq(FuncApp("<>", [N]), N) : SufficientlyLarge(N)
```

*   **Handling `Approx` Estimates (Must Ignore Constants):**
```orbit
	// Constant factor irrelevance (crucial for LP setup)
	ApproxLE(K * A, B) ↔ ApproxLE(A, B) if K : AbsoluteConstant ∧ K > 0
	ApproxLE(A, K * B) ↔ ApproxLE(A, B) if K : AbsoluteConstant ∧ K > 0
	ApproxEq(K * A, L * B) ↔ ApproxEq(A, B) if K:AbsConst ∧ L:AbsConst ∧ K>0 ∧ L>0

	// Dominant term in sum (use ApproxLE/GE)
	ApproxLE(A + B, C) → ApproxLE(A, C) if ApproxLE(B, A) // If B is dominated by A

	// Relationships
	ApproxEq(A, B) ↔ ApproxLE(A, B) ∧ ApproxGE(A, B)
	ApproxLE(A, B) → FalseEstimate if ApproxGE(A, K*B) ∧ K > 1 // Contradiction up to constants
```

*   **Case Splitting (Crucial Challenge):** Tao's code iterates through all combinations (`product`).
    *   **Orbit Implementation:** Requires a mechanism to manage verification across multiple hypothetical contexts.
    *   **Option 1: `AllTrue` Meta-Node:** As proposed earlier. A rule expands `Verify(..., Max(X,Y,Z), ...)` into `AllTrue([...])`, triggering sub-verifications. The `AllTrue` node only simplifies to `TrueEstimate` if *all* branches do.
```orbit
		// Rule to initiate case splitting for Max
		Verify(Est(..., Max(X,Y,Z), ...), As) →
			AllTrue([
				Verify(Est(..., Max(X,Y,Z), ...), As + [Assumption(ApproxGE(X,Y)), Assumption(ApproxGE(X,Z))]),
				// ... other cases ...
			])

		// Rule to simplify Max within a case context (using CaseContext domain)
		Max(X,Y,Z) : CaseContext(Assumps) → X
			if Contains(Assumps, ApproxGE(X,Y)) ∧ Contains(Assumps, ApproxGE(X,Z))

		AllTrue([TrueEstimate, TrueEstimate, ...]) → TrueEstimate
		AllTrue([... FalseEstimate ...]) → FalseEstimate
```
    *   **Option 2: External Driver:** An external script/program generates each case context and calls Orbit to verify the goal within that single context.
    *   **Assumption Representation within Case:** The `CaseContext(assumptions)` domain seems viable. Alternatively, the LP solver function might need the current assumption set passed explicitly.

*   **Logarithmic Transformation (as a specific strategy):**
```orbit
	// Rule to potentially trigger log transform
	Verify(ApproxLE(A, B), As) : PreferLogTransform => LogVerify(A, B, As)
	// LogVerify node would then trigger the LP setup
```

**6. Role of Canonical Forms:**

Essential for simplifying sub-expressions *before* monomial extraction or estimate rule application:

*   **Glex/Polynomials:** Standardize terms like `N² + N`.
*   **Sₙ/Commutative Ops:** Normalize sums/products. Sort args of `Max`/`Min`/`Median`.
*   **General Simplification:** Reduces expression variations.

**7. Verification Process (Reflecting LP Strategy):**

1.  **Input:** `Verify(EstimateNode, [AssumptionNodes...])`.
2.  **Initial Annotation:** Annotate parameters, constants, dependencies.
3.  **Saturation:** Apply Orbit rewrite rules.
    *   Simplification rules canonicalize sub-expressions.
    *   Estimate rules manipulate `ApproxLE`, `ApproxEq`.
    *   **Case-splitting rules may expand `Verify` into `AllTrue([...])` with different `CaseContext` annotations or assumptions.**
    *   **Within a case context, rules may trigger the Log-Transform + LP strategy for `ApproxLE`/`ApproxGE`.**
    *   The LP strategy involves: simplifying `B/A`, extracting monomials, setting up constraints based on context assumptions, calling the LP solver.
4.  **Result:**
    *   If the top-level `Verify` (or resulting `AllTrue`) node rewrites to `TrueEstimate`, verification succeeds.
    *   If it rewrites to `FalseEstimate`, it's refuted.
    *   If it remains unresolved or loops, the system failed.

**8. Addressing Tao's Wishlist & Basic Limitations:**

*   **Handling `≲`, `∼`:** Addressed via `ApproxLE`, `ApproxEq` rules ignoring constants and the LP strategy.
*   **Complex Assumptions:** Handled via `Assumption` nodes and rules/context querying them. `Max`/`Min`/`Median` rules are key. (See Section 9.3 for more).
*   **LP Solver:** **Requires integration** of an external LP solver callable from Orbit.
*   **Case Splitting:** **Implementation remains a key challenge** for a purely declarative system.
*   **Proof Certificate:** Trace + pretty-printing. Lean export is extra tooling.
*   **Automation Level:** Orbit automates rule application. Case splitting logic and strategy selection (e.g., when to use LP) might need meta-rules or guidance.

**9. Future Directions: Handling Advanced Techniques**

This section addresses the more advanced capabilities mentioned by Tao, requiring significant extensions to the basic framework.

**9.1 Functional Estimates (Function Spaces & Norms)**

*   **Concept:** Verify estimates involving unknown functions (`f`, `g`) residing in spaces like `Lᵖ(ℝⁿ)` or Sobolev spaces `Hˢ(ℝⁿ)`. Estimates typically involve norms, e.g., `||fg||_{L^p} ≲ ||f||_{L^q} ||g||_{L^r}`.
*   **Orbit Representation:**
    *   Introduce symbols representing functions (`f`, `g`).
    *   Introduce domains for function spaces: `FunctionSpace(Lp(p))`, `FunctionSpace(Sobolev(s, p))`.
    *   Introduce constructors for norms: `Norm(function: symbol, space: domain)`, e.g., `Norm(f, Lp(2))`.
    *   Annotate functions: `f : FunctionSpace(Lp(p))`.
*   **Orbit Rewriting:**
    *   Need rules encoding standard functional inequalities (Hölder, Minkowski, Sobolev embedding theorems, interpolation inequalities).
    *   These rules would transform `ApproxLE(Norm(..., ...), ...)` expressions based on the function space domains.
        ```orbit
		// Example: Holder Inequality Rule
		ApproxLE(Norm(f*g, Lp(p)), C * Norm(f, Lp(q)) * Norm(g, Lp(r))) → TrueEstimate
		   if f:FunctionSpace(Lp(q)) ∧ g:FunctionSpace(Lp(r)) ∧ (1/p = 1/q + 1/r) ∧ C:AbsoluteConstant
```
    *   Dependency tracking becomes more complex (e.g., does the implied constant depend on the dimension `n`?).

**9.2 Sums (∑) and Integrals (∫)**

*   **Concept:** Verify estimates involving symbolic sums or integrals, often infinite or over complex domains.
*   **Orbit Representation:**
    *   Introduce constructors: `Sum(expression: ast, index: symbol, lower_bound, upper_bound)`, `Integral(expression: ast, variable: symbol, lower_bound, upper_bound)`.
*   **Orbit Rewriting:** Requires a significant library of calculus and summation rules:
    *   Convergence tests (comparison, ratio, integral tests) potentially rewriting `Sum(...)` or `Integral(...)` to `Convergent` or `Divergent` domains.
    *   Standard summation formulas (geometric series, p-series).
    *   Integral evaluation rules (FTC, standard integrals).
    *   Integral/Sum bound rules (comparison properties, integral estimates like `∫f ≤ sup(f) * length(domain)`).
    *   Techniques like splitting the domain of summation/integration.
        ```orbit
		// Example: Splitting an integral
		Integral(f, x, a, c) → Integral(f, x, a, b) + Integral(f, x, b, c)

		// Example: Geometric Series Estimate
		Sum(r^k, k, 0, ∞) → ApproxEq(Sum(r^k, k, 0, ∞), 1) if Abs(r) < 1 ∧ r:AbsoluteConstant
```
    *   This likely requires integrating with more powerful symbolic calculus engines or libraries.

**9.3 Complex Hypotheses (Definitions)**

*   **Concept:** Handle assumptions where terms are defined complexly, e.g., `Assumption(ApproxEq(Max(N1,N2,N3), N))`.
*   **Orbit Representation:** Tao's Python uses standard expression objects on both sides. Orbit can do the same.
*   **Orbit Rewriting:** The challenge is efficiently *using* such assumptions. The `order_simplify` logic in Python handles this by recursively simplifying expression components based on the known orderings derived from assumptions.
    *   Orbit needs similar simplification rules that can utilize `Assumption` nodes within the current `CaseContext`.
        ```orbit
		// Rule using a complex assumption within a context
		Max(N1,N2,N3) : CaseContext(As) → N if Contains(As, Assumption(ApproxEq(Max(N1,N2,N3), N)))
```
    *   The case-splitting mechanism inherently helps by simplifying terms like `Max(N1,N2,N3)` down to one of `N1`, `N2`, or `N3` within a specific case, making the complex assumption easier to apply.

**9.4 Standard Mathematical Toolkit Integration**

*   **Concept:** Allow users to specify a set of allowed high-level mathematical techniques (e.g., "Use Hölder", "Use IBP", "Split integral at x=1").
*   **Orbit Representation:** Could use specific domains or flags to enable/disable sets of rules corresponding to these techniques.
    *   `EnableTool(HolderInequality)`, `EnableTool(IntegrationByParts)`.
*   **Orbit Rewriting:** Rewrite rules corresponding to these techniques would be gated by the presence of these "tool enabling" flags or domains.
    ```orbit
	// Rule for Integration by Parts (only applies if enabled)
	Integral(u * Diff(v, x), x, a, b) → (u*v | from a to b) - Integral(v * Diff(u, x), x, a, b)
	   if ToolEnabled(IntegrationByParts)
```
    *   This allows controlling the search space and verifying if an estimate can be proven *using only* a restricted set of methods.
