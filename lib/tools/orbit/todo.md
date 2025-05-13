# Orbit TODO List (Prioritized)

## 🔴 Priority 1: Core S-Expression Backend & Rewriting Feasibility

**Focus:** Ensure the S-expression based interpreter and rewriting engine are functional and validate the core canonicalization mechanism. Retire the old Orbit interpreter.

*   **S-Expression Backend Migration:**
    ✓   **Verify Orbit <-> S-Expression Conversion Integrity:**
        *   Run: `./run_orbit_tests.sh --sexpr-roundtrip`
        *   Goal: Ensure all tests pass the integrity check, meaning the `orbit sexpr-roundtrip=1` mode reports "SUCCESS" for the Orbit -> SExpr -> Orbit -> SExpr conversion process. Investigate any failures reported in the `.sexpr_roundtrip.log` files. This step checks the *conversion mechanism* itself, not the execution results.
		  - imports are dropped. Fine
		  - We use [] instead of (). Fine
		  - ast annotation is lost. Fine.
		  - x : P(x) is parsed as (x : P)(x) and that gives problems
    *   **Verify S-Expression Engine Execution Equivalence:**
        *   Run: `./run_orbit_tests.sh --compare-engines`
        *   Goal: Ensure all tests produce identical *execution output* between the default engine and the S-expression engine (`sexpr=1`). Address any discrepancies found in the `.engine_diff` files. This confirms the S-expression backend *runs* code equivalently.
		    - and, or, not instead of c syntax
			- `not` instead of ¬
			- ERROR: matchOGraphSexprPattern callback must be a lambda
			- dft_test: unquote
			✓ evalWithBindings is missing
			✓ find_ograph_id_test findOGraphId is missing
			- fun is strange
			- fun2: ERROR: addSexprWithSub third argument must be a list of bindings
			- tree: undefined name key, value...
    *   **O-Graph S-Expression Integration:** Modify O-Graph internal representation to primarily use S-Expressions or have seamless S-Expression interoperability. Test basic O-Graph operations (add, extract) using `tests/ograph_basic.orb` (if exists) with `--sexpr` and check results (or use `--compare-engines`).
    *   **Validate Rewriting Engine:**
        *   Run: `./run_orbit_tests.sh --compare-engines` on core rewriting tests (e.g., `tests/rewrite.orb`, `tests/pattern.orb`, `tests/algebra.orb` - adjust names based on actual files).
        *   Goal: Ensure identical execution results. Fix any differences reported by the comparison.
        *   Also run specific rewriting tests using only the SExpr engine: `./run_orbit_tests.sh --sexpr tests/rewrite.orb` and verify output.
    *   **Implement Basic Evaluation:** Implement evaluation for simple conditions (e.g., `<`, `>`, arithmetic) within the S-Expression based O-Graph/rewriting context. Test with rules using `if` conditions (e.g., `tests/conditional_rewrite.orb`), checking results with `--sexpr`.
    *   **Implement Minimal Environment:** Implement basic environment handling for scoped variables (e.g., function parameters, let bindings, summation indices) within the S-Expression evaluator. Test with `tests/scopes.orb`, `tests/lambda.orb`, or tests involving summations, checking results with `--sexpr`.
*   **Core O-Graph Rewriting & Canonicalization (using S-Expr backend):**
    *   **Implement & Test `S₂` Canonicalization:**
        *   Run: `./run_orbit_tests.sh --sexpr tests/commutativity.orb` (or similar test).
        *   Goal: Verify sorting/canonicalization via `mergeOGraphNodes` and `S₂` rules works correctly by checking the output.
    *   **Implement & Test `Cₙ` Canonicalization:**
        *   Run: `./run_orbit_tests.sh --sexpr tests/cyclic.orb` (or similar test using `booth_canonical`).
        *   Goal: Verify Booth's algorithm implementation via rules/functions linked to `: Cₙ` by checking the output.
    *   **Verify `addOGraphWithSub` / `matchOGraphPattern`:**
        *   Run: `./run_orbit_tests.sh --sexpr tests/ograph_subst.orb` (or similar).
        *   Goal: Ensure robust handling of S-Expression bindings and substitutions in pattern matching and rewriting by checking the output.
    *   **Verify `gather`/`scatter`:**
        *   Run: `./run_orbit_tests.sh --sexpr tests/gather_scatter.orb` (or similar).
        *   Goal: Ensure array-based representation works correctly with pattern matching for associative ops by checking the output.
*   **Simple Derivation Example (using S-Expr backend):**
    *   Implement rewrite rules for Horner's method derivation *OR* initial FFT split rules.
    *   Create a specific test file (e.g., `tests/horner_derivation.orb` or `tests/fft_split.orb`).
    *   Run: `./run_orbit_tests.sh --sexpr tests/your_derivation_test.orb`
    *   Goal: Verify `applyRulesUntilFixedPoint` successfully transforms the expression using the S-expression backend by checking the output.

## 🟡 Priority 2: Expand Core Functionality & Algorithms

**Focus:** Broaden the base of supported canonical forms, group operations, and fundamental algebraic/algorithmic derivations (using S-Expr backend). All tests below should primarily run with `--sexpr` and output verified, or use `--compare-engines` if a default engine equivalent exists.

*   **O-Graph Enhancements:**
    *   Implement domain hierarchy relationships (`⊂` / `c=`) and rule inheritance. Test with `tests/hierarchy.orb`.
    *   Implement `⇔` (bidirectional) and `⊢` (entailment) rule semantics. Test with `tests/bidir_entail.orb`.
    *   Formalize how canonical forms replace cost functions for extraction (document/refine extraction based on domains).
    *   Implement efficient mechanism to pattern match from a domain down to the terms in that domain.
*   **Canonicalization:**
    *   Implement canonical forms for `Dₙ`, `Aₙ`. Test with `tests/dihedral.orb`, `tests/alternating.orb`.
    *   Implement GLEX rules for polynomial rings. Test with `tests/glex.orb`, `tests/polynomials.orb`.
    *   Implement canonical forms for group products. Test with `tests/group_products.orb`.
*   **Algorithms & Derivations:**
    *   Implement rules for Strassen derivation steps. Test with `tests/strassen.orb`.
    *   Implement rules for Karatsuba derivation steps. Test with `tests/karatsuba.orb`.
    *   Implement rules for deriving triangular matrix inverse optimization. Test with `tests/matrix_inv.orb`.
    *   Implement rules for basic automatic differentiation. Test with `tests/autodiff.orb`.
    *   Implement rules for basic recurrence solving (Master Theorem). Test with `tests/master_theorem.orb`.
*   **Pattern Matching:**
    *   Strengthen pattern variable reuse constraints (semantic equivalence in O-Graph).
    *   Support for deep pattern matching with nested patterns.
*   **Core Group Theory:**
    *   Implement core group operations. Test with `tests/group_ops.orb`.
    *   Add support for Cₙ, Dₙ, Sₙ, Aₙ operations and properties.

## 🟢 Priority 3: Advanced Features & Domains

**Focus:** Implement more complex canonical forms, algorithms, and support for specialized domains (using S-Expr backend).

*   **O-Graph & Rewriting:**
    *   Support pattern matching within sequences (prefix, suffix, subsequence).
    *   Figure out "lazy" rule saturation.
    *   Hook in evaluation functions for direct interpretation of AST nodes.
*   **Canonicalization & Domains:**
    *   Add support for Gröbner basis canonicalization.
    *   Integrate matrix group canonicalization (GL, SL, O).
    *   Implement BDD canonicalization/operations. Test with `tests/bdd.orb`.
    *   Implement Tensor canonicalization.
    *   Implement Interval Arithmetic rules.
    *   Implement Relational Algebra rules and optimizations. Test with `tests/relalg.orb`.
    *   Implement rules for Chemistry domain.
    *   Implement rules for Approximation/Estimates (ULP). Test with `tests/approx.orb`.
    *   Implement rules for SSA form and scope analysis / closure conversion. Test with `tests/ssa.orb`.
*   **Algorithms:**
    *   Complete FFT derivation rules (Rader's, Bluestein's). Test with `tests/fft_advanced.orb`.
    *   Implement advanced recurrence solvers (Akra-Bazzi, GF, etc.). Test with `tests/recurrence_advanced.orb`.
    *   Implement rules for complexity analysis propagation.
    *   Implement rules for loop transformations/polyhedral model.
*   **Algebraic Structure Support:**
    *   Add support for detecting rings, fields, vector spaces.
    *   Implement Boolean algebra operations. Test with `tests/logic.orb`.
    *   Add support for lattice operations.
    *   Implement semiring detection.
    *   Add support for modular arithmetic. Test with `tests/number_theory.orb`.
*   **Group Theory:**
    *   Support matrix groups (GL, SL, O) and their operations.
    *   Implement group product operations (direct, semi-direct).
    *   Add group decomposition functionality.
    *   Implement group isomorphism testing.

## 🔵 Priority 4: Tooling, Ecosystem & Explanations

**Focus:** Improve developer/user experience, external integrations, and documentation clarity.

*   **Scheme Integration:**
    *   Fully port the system to run natively in the target Scheme environment.
    *   Integrate O-Graph seamlessly with Scheme runtime environment.
*   **External Systems:**
    *   Implement WebGPU backend for acceleration.
    *   Integrate with Lean/Mathlib for verification.
*   **Language & Usability:**
    *   Implement an operator language `(+)`.
    *   Support for subscripts (`_`) and superscripts (`^`) in notation, mapping to internal representation.
    *   Define syntax for field access (e.g., `foo.1`).
    *   Extend to allow JS/other syntaxes (parsing, pretty-printing).
    *   Consider environment handling across languages.
*   **Documentation & Explanation:**
    *   Explain canonical forms vs. cost functions.
    *   Explain gather/scatter benefits.
    *   Consolidate and refine all documentation (`.md` files) based on the final implementation.
