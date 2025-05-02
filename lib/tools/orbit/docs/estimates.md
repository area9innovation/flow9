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
    *   Standard algebraic rules (commutativity, associativity via `gather`/`scatter`, distributivity, exponents) operating on sub-expressions.
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

**8. Addressing Tao's Wishlist & Limitations:**

*   **Handling `≲`, `∼`:** Addressed via `ApproxLE`, `ApproxEq` rules ignoring constants and the LP strategy.
*   **Complex Assumptions:** Handled via `Assumption` nodes and rules/context querying them. `Max`/`Min`/`Median` rules are key.
*   **LP Solver:** **Requires integration** of an external LP solver callable from Orbit.
*   **Case Splitting:** **Implementation remains a key challenge** for a purely declarative system.
*   **Sums/Integrals/Function Norms:** Significant future work.
*   **Proof Certificate:** Trace + pretty-printing. Lean export is extra tooling.
*   **Automation Level:** Orbit automates rule application. Case splitting logic and strategy selection (e.g., when to use LP) might need meta-rules or guidance.

**Conclusion:**

This proposal strongly incorporates the log-transform + LP strategy from Tao's code as a central mechanism for verifying multiplicative estimates. Orbit's rewriting and canonicalization handle sub-expression simplification. Key implementation challenges include the robust handling of case splitting across multiple contexts and the integration of an external LP solver. Dependency tracking remains a valuable potential Orbit enhancement. This provides a clearer path toward implementing Tao's proof-of-concept within the Orbit framework.