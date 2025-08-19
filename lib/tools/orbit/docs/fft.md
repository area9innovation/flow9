# Automatic FFT Derivation Through Orbit's Group-Theoretic Rewrites

## Introduction

The Discrete Fourier Transform (DFT) and its fast implementation, the Fast Fourier Transform (FFT), represent a perfect case study for Orbit's group-theoretic approach to algorithm discovery. This document demonstrates how Orbit can automatically derive the FFT from the DFT definition by identifying and exploiting mathematical symmetries, without explicitly encoding the FFT algorithm.

The standard DFT has O(N²) complexity, while the FFT achieves O(N log N) when N is a power of 2. This exponential speedup is one of the most important algorithmic improvements in computing history. Rather than treating FFT as a separate algorithm, we show how it emerges naturally from applying algebraic rewrite rules to the DFT when certain structural symmetries are detected within its definition.

## The Main Point: Generalized Summation Optimization via Symmetry Detection

The core mechanism enabling the automatic derivation of FFT (and potentially other fast transforms) in Orbit is not a set of rules specific *only* to FFT, but a **general strategy for analyzing and optimizing summations based on detected symmetries in their kernel functions.**

Consider a general summation:
`sum(i, 0, N-1, x[i] * kernel(i, k, N))`

Orbit's optimization strategy proceeds as follows:
1.  **Kernel Identification:** When a summation pattern like `sum(Idx, Start, End, Term)` is encountered, Orbit attempts to isolate the `kernel` part of `Term`. This often involves identifying parts of `Term` that depend on the summation index `Idx` and other parameters (like `k` and `N` in the DFT example). The `kernel` is the part of `Term` that, when the input array `x[i]` is factored out, remains as `kernel(i, k, N)`.
2.  **Kernel Annotation:** Once identified, the kernel expression can be marked for specific symmetry analysis, for example, by a preliminary rule: `Arr[Idx] * KernelExpr` within a sum might lead to `KernelExpr` being annotated `PotentialKernel`.
3.  **Symmetry Probing via Rewriting and E-Class Equivalence:** Instead of specific rules to *detect* if `kernel(2*I, K, N)` is *algebraically equivalent* to a simpler form like `kernel(I, K, N/2)`, Orbit uses its general algebraic rewrite engine and e-class mechanism. It constructs two versions of the kernel expression:
    *   `Kernel_Even_Transformed = substitute(OriginalKernelExpr, {Idx: 2*I})` (representing `kernel(2*I, K, N)`)
    *   `Kernel_Target_Even = TargetSimplifiedKernelExpr` (representing the hypothesized simplified form, e.g., `kernel(I, K, N/2)`, where `TargetSimplifiedKernelExpr` might be `substitute(OriginalKernelExpr, {Idx: I, N: N/2})` or a known canonical form for the even-indexed sub-problem).
    Orbit then adds both `Kernel_Even_Transformed` and `Kernel_Target_Even` to the O-Graph. If, after applying all relevant algebraic simplification rules (like `TWIDDLE_EVEN_ARG` for DFT kernels), these two expressions end up in the **same e-class**, they are considered equivalent. This establishes a property like `HalvingSymmetry(TargetSimplifiedKernelExpr)` on the `OriginalKernelExpr`.
    A similar process is used for the odd part:
    *   `Kernel_Odd_Transformed = substitute(OriginalKernelExpr, {Idx: 2*I+1})`
    *   `Kernel_Target_Odd_Factorized = FactorExpr * TargetSimplifiedKernelExpr` (representing `Factor * kernel(I, K, N/2)`)
    If `Kernel_Odd_Transformed` and `Kernel_Target_Odd_Factorized` merge into the same e-class, the odd-even relationship with a specific `FactorExpr` (relative to the `TargetSimplifiedKernelExpr`) is confirmed. This establishes a property like `OddEvenFactorable(FactorExpr, TargetSimplifiedKernelExpr)`.
4.  **Conditional Sum Rewrite:** If these e-class equivalences are established (and thus the kernel is annotated accordingly), a general rule for splitting summations can fire.

The Orbit rules would look conceptually like this:
```orbit
// Rule to tag a kernel function part of a summation term (simplified concept)
sum(Idx, Low, High, Arr[Idx] * KernelExpr) : Summation !: KernelTagged
	→ sum(Idx, Low, High, Arr[Idx] * (KernelExpr : PotentialKernel)) : Summation : KernelTagged;
	// Actual kernel extraction would identify KernelExpr based on Idx and other params.

// RULE 1: Check for Even-Part Halving Symmetry via E-Class Equivalence
// KernelCand is the identified kernel from the sum, e.g., W(N, Idx*K)
// TargetSimplifiedKernel is the form we expect for the even part, e.g., W(N/2, I*K)
// The actual structures of KernelCand and TargetSimplifiedKernel depend on the specific transform.
// For DFT: KernelCand might be W(N_param, Idx_param * K_param)
//          TargetSimplifiedKernel might be W(N_param/2, NewIdx_param * K_param)

sum(IdxSum, 0, N_sum-1, Arr[IdxSum] * KernelCand : PotentialKernel !: HalvingSymChecked) : Summation,
// Construct the actual expression for the even-indexed kernel term
// Example: If KernelCand is W(N, Idx*K), TransformedEvenKernel becomes W(N, (2*I)*K)
TransformedEvenKernel = substitute(KernelCand, {IdxParamInKernel: 2*I}), // IdxParamInKernel is the variable in KernelCand that corresponds to IdxSum
// Construct the actual expression for the target simplified even kernel
// Example: If TargetSimplifiedKernel is W(N/2, InnerI*K), this becomes W(N/2, I*K)
TargetEvenKernelInstance = substitute(TargetSimplifiedKernel, {InnerIdxParam: I}),
// If, after Orbit's internal rule applications, they are in the same e-class
eval(eclass_equiv(TransformedEvenKernel, TargetEvenKernelInstance))
	→ sum(IdxSum, 0, N_sum-1, Arr[IdxSum] * (KernelCand : HalvingSymmetry(TargetSimplifiedKernel))) : Summation
	  : HalvingSymChecked; // Mark as checked

// RULE 2: Check for Odd-Part Factorable Symmetry (relative to the TargetSimplifiedKernel from RULE 1)
sum(IdxSum, 0, N_sum-1, Arr[IdxSum] * KernelCand : PotentialKernel : HalvingSymmetry(TargetSimplifiedKernel) !: OddEvenFactorChecked) : Summation,
// Construct the actual expression for the odd-indexed kernel term
// Example: If KernelCand is W(N, Idx*K), TransformedOddKernel becomes W(N, (2*I+1)*K)
TransformedOddKernel = substitute(KernelCand, {IdxParamInKernel: 2*I+1}),
// Construct the target factorized odd kernel: ExpectedFactorExpression * TargetSimplifiedKernelInstance
// Example: For DFT, ExpectedFactorExpression is W(N, K). TargetSimplifiedKernelInstance is W(N/2, I*K)
TargetOddKernelFactorized = ExpectedFactorExpression * substitute(TargetSimplifiedKernel, {InnerIdxParam: I}),
eval(eclass_equiv(TransformedOddKernel, TargetOddKernelFactorized))
	→ sum(IdxSum, 0, N_sum-1, Arr[IdxSum] * (KernelCand : OddEvenFactorable(ExpectedFactorExpression, TargetSimplifiedKernel))) : Summation
	  : OddEvenFactorChecked;

// GENERALIZED SUM SPLIT RULE (using math syntax, triggered by established symmetries)
// This rule now relies on the annotations from RULE 1 and RULE 2.
// KernelData is KernelCand with its new annotations.
sum(Idx, 0, N-1, Arr[Idx] * KernelData : OddEvenFactorable(FactorExpr, EvenKernelFormTemplate)) : Summation,
eval_is_even(N), eval_greater_than(N, 1)
	→ ( // Sum of even parts
		 sum(I, 0, (N/2)-1, Arr[2*I] * substitute(EvenKernelFormTemplate, {InnerIdxParam: I}) )
	  +  // Sum of odd parts, with the factor
		 FactorExpr * sum(I, 0, (N/2)-1, Arr[2*I+1] * substitute(EvenKernelFormTemplate, {InnerIdxParam: I}) )
	  ) : SplitSum;
```

## Expressing DFT and its Kernel Symmetries (Math Syntax)


```orbit
// Define domains
DFT ⊂ LinearTransform
TwiddleFactor ⊂ ComplexExponential
Summation ⊂ LinearOperation
KernelFunc ⊂ Function // KernelFunc might be implicitly handled by PotentialKernel and its subsequent annotations
Complex ⊂ Field // Assuming Complex numbers form a Field

// Define complex exponential twiddle factors W_N^k = exp(-i*2*π*k/N)
// Represented using functional notation W(N, K_Expr)
W(N, K_Expr) : TwiddleFactor : C_N; // Annotate with its inherent cyclic group property

// DFT Definition (bidirectional rule for folding/unfolding)
dft(Arr, N, K) : DFT ↔
	sum(J, 0, N-1, Arr[J] * W(N, J*K)) : Summation;
```


### Detecting Symmetries in the DFT Kernel (`W(N, J*K)`)

The specific `HalvingSymmetry(TargetSimplifiedKernelForm)` and `OddEvenFactorable(Factor, TargetSimplifiedKernelForm)` annotations on the kernel (e.g., `W(N, J*K)`) are established by the e-class equivalence checks described in "The Main Point" section. Orbit relies on its existing set of algebraic simplification rules for `W(N, Expr)` to prove these equivalences.

For the DFT kernel `W(N, J*K)` (where `J` is the summation index, `N` and `K` are parameters):
*   **HalvingSymmetry Check:**
    *   `Kernel_Even_Transformed = substitute(W(N, J*K), {J: 2*I})` which is `W(N, (2*I)*K)`.
    *   `TargetSimplifiedKernelForm` for DFT is `W(N/2, InnerIdx*K)`. So, `TargetEvenKernelInstance = substitute(W(N/2, InnerIdx*K), {InnerIdx: I})` which is `W(N/2, I*K)`.
    *   Using a rule like `TWIDDLE_EVEN_ARG: W(N_val, 2 * P_val) → W(N_val / 2, P_val) if eval_is_even(N_val)`, the expression `W(N, (2*I)*K)` (which is `W(N, 2*(I*K))`) simplifies to `W(N/2, I*K)`.
    *   Since `W(N, (2*I)*K)` and `W(N/2, I*K)` become the same expression in the O-Graph (i.e., they are in the same e-class), the original kernel `W(N, J*K)` gets annotated with `HalvingSymmetry(W(N/2, InnerIdx*K))`. (Here `InnerIdx*K` is the template for the exponent).

*   **OddEvenFactorable Check:**
    *   `Kernel_Odd_Transformed = substitute(W(N, J*K), {J: 2*I+1})` which is `W(N, (2*I+1)*K)`.
    *   `ExpectedFactorExpression` for DFT is `W(N, K)`.
    *   `TargetSimplifiedKernelForm` is `W(N/2, InnerIdx*K)`. So, `TargetOddKernelFactorized = W(N, K) * W(N/2, I*K)`.
    *   Using rules like `TWIDDLE_EXP_SUM: W(N_val, A+B) → W(N_val, A) * W(N_val, B)` and `TWIDDLE_EVEN_ARG`, the expression `W(N, (2*I+1)*K)` (which is `W(N, 2*I*K + K)`) simplifies to `W(N, 2*I*K) * W(N, K)`, which further simplifies to `W(N/2, I*K) * W(N, K)`.
    *   Since `W(N, (2*I+1)*K)` and `W(N, K) * W(N/2, I*K)` merge into the same e-class, the kernel `W(N, J*K)` (already annotated with `HalvingSymmetry`) gets further annotated with `OddEvenFactorable(W(N, K), W(N/2, InnerIdx*K))`.

These annotations then enable the `GENERALIZED SUM SPLIT RULE`.

```orbit
// --- Rules for simplifying W(N, Expr) ---

// TWIDDLE_EXP_SUM: W(N, A+B) = W(N, A) * W(N, B)
W(N, A + B) : TwiddleFactor → W(N, A) * W(N, B) : TwiddleFactor;

// TWIDDLE_EVEN_ARG: W(N, 2*P) = W(N/2, P) (if N is even)
W(N, 2 * P) : TwiddleFactor → W(N / 2, P) : TwiddleFactor
	if eval_is_even(N);

// TWIDDLE_HALF_N: W(N, N/2) = -1 (if N is even)
W(N, N / 2) : TwiddleFactor → Complex(-1.0, 0.0) : TwiddleFactor
	if eval_is_even(N);

// TWIDDLE_ZERO_EXP: W(N, 0) = 1
W(N, 0) : TwiddleFactor → Complex(1.0, 0.0) : TwiddleFactor;

// TWIDDLE_PERIODICITY: W(N, K+N) = W(N, K)
W(N, K + N_val) : TwiddleFactor → W(N, K) : TwiddleFactor if eval(N == N_val);
```

## Deriving the FFT's Divide-and-Conquer Structure (Math Syntax)

1.  **Base Case for Recursion:**
    
```orbit
	// FFT_BASE_CASE: dft(Arr, 1, 0) = Arr[0]
	dft(Arr, 1, 0) : DFT !: BaseCase → Arr[0] : BaseCase;
	// Assuming K must be 0 when N=1 for DFT
```

2.  **Initial DFT Split (Triggered by Detected Symmetries):**
    The `GENERALIZED SUM SPLIT RULE` (from "The Main Point" section) applied to the `dft(Arr, N, K)` definition (which is `sum(J, 0, N-1, Arr[J] * W(N, J*K))`) results in:
    
```orbit
	// Result after GENERALIZED SUM SPLIT RULE applies to dft(X, N, K) definition:
	// Given Kernel W(N,J*K) was annotated with:
	// HalvingSymmetry(W(N/2, InnerIdx*K)) and
	// OddEvenFactorable(W(N,K), W(N/2, InnerIdx*K))
	( // Even sum
	  sum(I, 0, (N/2)-1, X[2*I] * W(N/2, I*K) ) // W(N/2, I*K) comes from substitute(W(N/2, InnerIdx*K), {InnerIdx:I})
	+ // Odd sum factored
	  W(N, K) * sum(I, 0, (N/2)-1, X[2*I+1] * W(N/2, I*K) )
	) : SplitSum
	// This happens because the GENERALIZED SUM SPLIT RULE uses the annotations derived from e-class equivalence,
	// which in turn relied on fundamental rules like TWIDDLE_EVEN_ARG and TWIDDLE_EXP_SUM.
```

3.  **Folding Back to DFTs (Recursive Structure Recognition):**
    The bidirectional `DEF_DFT` rule recognizes the two summations above as smaller DFTs, substituting them back.

```orbit
	// FFT_RECURSIVE_STRUCTURE: Fold the simplified sums back into dft calls
	// This matches the structure produced by the split rule after simplifications.
	Expr : SplitSum !: RecursiveForm → // Match structure from step 2
		dft(sub_array_even(X), N/2, K)
	  + W(N, K) * dft(sub_array_odd(X), N/2, K)
	   : RecursiveForm
		if (eval_is_even N) && (eval_greater_than N 1) && (eval_less_than K (N / 2));
		// Condition K < N/2 is for the first half butterfly calculation.
```

    *(Note: `sub_array_even(X)` and `sub_array_odd(X)` are helper terms representing the necessary input arrays for the smaller DFTs. The actual mechanism might involve index transformations within the dft calls.)*

4.  **Second Half Optimization (Butterfly):**
    
```orbit
	// FFT_SECOND_HALF: dft(X, N, K + N/2) -> dft_even(K) - W(N, K) * dft_odd(K)
	// This optimization emerges from applying the recursive step and simplifying
	// using W(N, K+N/2) = -W(N, K) and DFT periodicity properties.
	dft(X, N, KOuter + (NInner / 2)) : DFT !: SecondHalf →
		dft(sub_array_even(X), NInner / 2, KOuter)
	  - W(NInner, KOuter) * dft(sub_array_odd(X), NInner / 2, KOuter)
	   : SecondHalf
		if (eval_is_even NInner) && (eval(N == NInner)) && (eval_greater_than NInner 1) && (eval_less_than KOuter (NInner / 2));
```

**Helper/Underlying Rules Needed:**

*   **Sub-Array Access:** Rules defining how `Arr[Index]` interacts with `sub_array_even` and `sub_array_odd`.
    
```orbit
	// ACCESS_EVEN_SUB_ARRAY: X_even[J] = X[2*J]
	sub_array_even(X)[J] → X[2*J];

	// ACCESS_ODD_SUB_ARRAY: X_odd[J] = X[2*J+1]
	sub_array_odd(X)[J] → X[2*J + 1];
```

*   **DFT Periodicity:** (Essential for relating `dft(..., K)` to `dft(..., K+N/2)`)
    
```orbit
	// DFT_K_PLUS_PERIOD: dft(Arr, Len, K + Len) = dft(Arr, Len, K)
	dft(Arr, Len, K + Len_val) : DFT → dft(Arr, Len, K) : DFT
		if eval(Len == Len_val);
```

*   **Summation Properties:** Rules for manipulating sums (splitting range, pulling out factors, etc.).
*   **Algebraic Simplification:** Standard rules for `+`, `-`, `*`, `/`.

## Expressing DFT in Orbit

We begin by expressing the DFT in Orbit's domain-specific language:

```orbit
// Define domains for DFT operations
DFT ⊂ LinearTransform
TwiddleFactor ⊂ ComplexExponential
Summation ⊂ LinearOperation

// Define complex exponential twiddle factors
W_N^k : TwiddleFactor → exp(-i*2*π*k/N) : C_N; // C_N denotes the cyclic group of order N

// Define DFT in terms of twiddle factors
dft(x, N, k) : DFT → sum(j, 0, N-1, x[j] * W_N^(j*k)) : Summation;

// The full transform for all output indices
dft(x, N) : DFT → [dft(x, N, k) for k = 0 to N-1] : Transform;
```

This representation explicitly connects the DFT to the cyclic group C_N through the twiddle factors, which Orbit can exploit to discover symmetries.

## The Key Insight: Divide-and-Conquer Through Group Theory

The critical insight enabling the FFT is recognizing how the DFT can be split when N is divisible by certain factors. This split is now understood to be an application of the `GENERALIZED SUM SPLIT RULE` discussed earlier, which is triggered when the kernel `W_N^(j*k)` is proven to have the necessary `HalvingSymmetry` and `OddEvenFactorable` properties via e-class equivalence.

The rule:
```orbit
// The foundational insight: Split DFT sum into even and odd indices
dft(x, N, k) : DFT !: Split → (
	sum(j, 0, N/2-1, x[2*j] * W_N^(2*j*k)) +
	sum(j, 0, N/2-1, x[2*j+1] * W_N^((2*j+1)*k))
) : Split if can_split_indices(N);

// Define the condition for splitting: N must be even
can_split_indices(N) → eval(N % 2 == 0);
```
This rule, while specific to DFT, represents the outcome of the generalized sum splitting mechanism when applied to the DFT definition. The `!: Split` negative guard ensures this rule only applies once to prevent infinite recursion if this specific rule is used directly.

## Exploiting Symmetries in Twiddle Factors

Next, we identify the critical symmetry patterns in the twiddle factors that make the FFT efficient:

```orbit
// Recognize that W_N^(2*j*k) = W_{N/2}^(j*k)
W_N^(2*j*k) : TwiddleFactor → W_{N/2}^(j*k) : TwiddleFactor;

// And that W_N^((2*j+1)*k) = W_N^k * W_N^(2*j*k)
W_N^((2*j+1)*k) : TwiddleFactor → W_N^k * W_N^(2*j*k) : TwiddleFactor;
				→ W_N^k * W_{N/2}^(j*k) : TwiddleFactor;
```

These rewrites leverage the cyclic group structure (C_N) of the twiddle factors, allowing us to recognize patterns that would otherwise be hidden in the complex exponentials. These are the fundamental algebraic identities that allow the e-class equivalence checks (for `HalvingSymmetry` and `OddEvenFactorable`) to succeed.

## Automatic Discovery of Algebraic Identities

While previous sections showed how specific identities enable FFT optimization, Orbit can systematically discover these identities in the first place. The system could leverage its algebraic rewriting capabilities to automatically find the patterns that lead to algorithmic improvements. The e-class equivalence check for sum splitting *relies* on these fundamental identities (like `W_N^(2jk) = W_{N/2}^(jk)`) already being present as rules in the system.

### Systematic Identity Exploration

```orbit
// Define an automatic identity discovery process for expressions with group structure
DiscoverIdentities(expr : GroupStructured) : Analysis → {
	// Analyze the structure of the expression
	group = detect_group_structure(expr);

	group is {
		// For cyclic groups, systematically explore transformations
		C_N => {
			// Check periodicity identities
			verify_identity(expr(x + N) = expr(x)) : Periodicity;

			// For even N, check half-period identities
			if N % 2 == 0 then
				verify_identity(expr(x + N/2) = f(expr(x))) : HalfPeriod;

			// For composite N, check decomposition by factors
			factors = get_factors(N);
			for factor in factors:
				verify_identity(expr(factor * x) = g(expr(x))) : FactorRelation;
		};

		// For multiplicative groups (Z/NZ)*, check structural properties
		MultGroup => {
			if is_prime(N) then {
				// Check for primitive roots
				root = find_primitive_root(N);
				verify_identity(all non-zero elements = {root ^ k mod N | k=0...N-2}) : PrimitiveRoot;
			};
		};
	};
}
```

### Leveraging Orbit's Domain Annotation System

The true power of Orbit for identity discovery comes from its domain annotation system. By propagating algebraic properties from basic expressions to complex ones, Orbit can transfer group-theoretic knowledge:

```orbit
// Define propagation rules for group properties
W_N^x : C_N, W_N^y : C_N ⊢ W_N^(x+y) : C_N;  // Closure under addition in exponent
W_N^x : C_N, W_M^y : C_M, N divides M ⊢ (W_N^x = W_M^(M/N * x)) : Embedding;  // Subgroup relations

// When an expression has cyclic group structure, try specific rewrites
expr : C_N !: Analyzed → analyze_cyclic_structure(expr) : Analyzed;

// Automatically recognize odd/even patterns in arguments
f(2*n) : Pattern ⊢ pattern_kind = "even";
f(2*n+1) : Pattern ⊢ pattern_kind = "odd";

// Leverage pattern detection for systematic rewriting
sum(j, 0, N-1, expr(j)) : Summation, Pattern = "splittable" →
	sum(j, 0, N/2-1, expr(2*j)) + sum(j, 0, N/2-1, expr(2*j+1)) : SplitSum;
```

### Automatic Derivation of Critical FFT Identities

```orbit
// Automatic derivation of the core FFT identity
deriveIdentity(W_N^(j*k)) → {
	// Substitute j = 2m (even)
	W_N^(2*m*k) : TwiddleFactor → expand(W_N^(2*m*k))
														→ exp(-i*2*π*2*m*k/N)
														→ exp(-i*2*π*m*k/(N/2))
														→ W_{N/2}^(m*k);

	// Verify the identity algebraically
	if verify_algebraic(W_N^(2*m*k) = W_{N/2}^(m*k)) then
		register_identity("cooley_tukey_even", W_N^(2*j*k) = W_{N/2}^(j*k));

	// Similarly for odd indices...
};
```

### Generalizing to Other Summations

This e-class based symmetry detection approach extends beyond FFT to any summation. For example:

1.  **Walsh-Hadamard Transform**: `sum(j, 0, N-1, x[j] * (-1)^(bit_count(j&k)))`
    Orbit would have simplification rules for `bit_count` and `(-1)^power`.
    *   `Kernel_Even_Transformed = substitute((-1)^(bit_count(j&k)), {j: 2*I})` (i.e., `(-1)^(bit_count((2*I)&k))`)
    *   `TargetSimplifiedKernelForm` might be `(-1)^(bit_count(InnerIdx & (k/2)))` if `k` is even.
    *   `TargetEvenKernelInstance = substitute((-1)^(bit_count(InnerIdx & (k/2))), {InnerIdx: I})`
    If these two expressions for the kernel land in the same e-class after simplification (using rules about `bit_count((2*I)&k)` vs `bit_count(I&(k/2))`), the `HalvingSymmetry` is established for the Walsh-Hadamard kernel. Similar logic applies for the `OddEvenFactorable` property.

2.  **Number Theoretic Transform**: `sum(j, 0, N-1, x[j] * r ^ (j*k mod p))`
    Simplification rules for modular exponentiation (e.g., `r^((2*I)*k mod p)` vs. `(r^2)^(I*k mod p)`) would allow Orbit to establish e-class equivalence for the kernel's even part transformation.

3.  **Hartley Transform**: `sum(j, 0, N-1, x[j] * (cas(2πjk/N)))` where `cas(x) = cos(x) + sin(x)`.
    Trigonometric identities would be used to simplify `cas(2π(2I)k/N)` and relate it to `cas(2πIk/(N/2))`, establishing e-class equivalence.

The core idea remains: define the basic algebraic properties of the kernel's components, and let Orbit's saturation engine prove the equivalences needed for the `GENERALIZED SUM SPLIT RULE` to apply.

### Practical Applications

The same principles apply to many practical computational tasks with hidden algebraic structure:

```orbit
// Matrix multiplication with Strassen-like decomposition
matrix_multiply(A, B) : MatrixOperation !: Optimized, is_large_enough(A, B) →
	discover_block_decomposition(A, B) : Optimized;

// Multi-dimensional signal processing
md_transform(data, dims) : NDTransform !: Factorized →
	discover_separable_structure(data, dims) : Factorized;

// Graph algorithms with algebraic structure
graph_operation(G) : GraphAlgorithm, has_symmetry(G) →
	exploit_symmetry_structure(G) : OptimizedAlgorithm;
```

This generalized approach to automatic identity discovery is what makes Orbit powerful - rather than encoding specific optimizations, the system can derive them from first principles by understanding the underlying mathematical structure.

## Deriving the FFT's Divide Step

We can now rewrite the split DFT using these twiddle factor identities:

```orbit
// Apply twiddle factor symmetries to rewrite the split sum
dft(x, N, k) : Split !: Factored → (
	sum(j, 0, N/2-1, x[2*j] * W_{N/2}^(j*k)) +
	W_N^k * sum(j, 0, N/2-1, x[2*j+1] * W_{N/2}^(j*k))
) : Factored;

// Recognize that these sums are DFTs of the even and odd subsequences
sum(j, 0, N/2-1, x[2*j] * W_{N/2}^(j*k)) : Summation → dft(x_even, N/2, k) : DFT
	where x_even[j] = x[2*j];

sum(j, 0, N/2-1, x[2*j+1] * W_{N/2}^(j*k)) : Summation → dft(x_odd, N/2, k) : DFT
	where x_odd[j] = x[2*j+1];

// Combine these recognitions into the key FFT divide step
dft(x, N, k) : Factored !: DivideStep → (
	dft(x_even, N/2, k) + W_N^k * dft(x_odd, N/2, k)
) : DivideStep;
```

This is the heart of the FFT algorithm - expressing a size-N DFT in terms of two size-N/2 DFTs. The beauty is that Orbit discovers this pattern through algebraic rewrite rules rather than explicit algorithm coding.

## Optimizing the Second Half of Outputs

Another key insight of the FFT is that we can reuse computations for the second half of the output indices (k ≥ N/2):

```orbit
// Recognize periodicity in twiddle factors: W_N^(k+N/2) = -W_N^k
W_N^(k+N/2) : TwiddleFactor → -W_N^k : TwiddleFactor;

// Apply this to optimize the divide step for k+N/2
dft(x, N, k+N/2) : DFT !: SecondHalf → (
	dft(x_even, N/2, k) - W_N^k * dft(x_odd, N/2, k)
) : SecondHalf if k < N/2;
```

This rewrite exploits the periodicity property of twiddle factors, allowing us to compute the second half of outputs with minimal additional work - a key optimization in the FFT.

## Combining Results and Recursive Application

We can now combine these insights to express the full DFT-to-FFT transformation:

```orbit
// Complete FFT butterfly pattern for all indices
dft(x, N) : DFT !: Complete → [
	// First half: k = 0 to N/2-1
	for k = 0 to N/2-1: dft(x_even, N/2, k) + W_N^k * dft(x_odd, N/2, k),

	// Second half: k = N/2 to N-1
	for k = 0 to N/2-1: dft(x_even, N/2, k) - W_N^k * dft(x_odd, N/2, k)
] : Complete if can_split_indices(N);

// Base case for recursion
dft(x, 1, 0) : DFT → x[0];
```

The power of this approach is that these same rewrite rules will recursively apply to the smaller DFTs, automatically generating the full FFT butterfly structure when N is a power of 2. No explicit recursion needs to be encoded - it emerges naturally from repeated rule application.

## Generalization to Non-Power-of-2 Sizes

The approach isn't limited to powers of 2. We can generalize to any composite N by recognizing factors:

```orbit
// Generalized splitting for any factor p of N
dft(x, N, k) : DFT !: FactorSplit → (
	sum(r=0 to p-1, W_N^(r*k) * dft(x_r, N/p, k))
) : FactorSplit if has_factor(N, p);

// Where x_r contains every p-th element of x starting at offset r
x_r[j] → x[p*j + r];

// Check if N has a factor p
has_factor(N, p) → eval(N % p == 0 && p > 1);
```

This generalization enables automatic discovery of the Cooley-Tukey FFT algorithm for any composite N (not just powers of 2), as well as prime-factor and mixed-radix FFT variants.

## Handling Prime Lengths: Rader's Algorithm

When N is prime, the divide-and-conquer approach breaks down since N has no factors. However, Orbit can discover Rader's algorithm, which uses deeper group-theoretic properties to transform the problem:

```orbit
// Define multiplicative group of integers modulo N
ZnStar : Group ⊂ MultiplicativeGroup

// When N is prime, the multiplicative group (Z/NZ)* is cyclic of order N-1
(Z/NZ)* : ZnStar ⊢ (Z/NZ)* : C_{N-1} if is_prime(N);

// There exists a primitive root g whose powers generate all non-zero elements
g : PrimitiveRoot ⊢ {g^k mod N | k = 0,1,...,N-2} = {1,2,...,N-1} if is_prime(N);
```

Rader's insight was that when N is prime, we can reindex the DFT using a primitive root g of the multiplicative group modulo N:

```orbit
// For prime N, reindex DFT using the primitive root g
dft(x, N) : DFT !: Rader → (
	// Handle index 0 separately (DC component)
	y[0] = sum(j, 0, N-1, x[j]),

	// Reindexing for k ≠ 0 using primitive root g
	y[g^m mod N] = x[0] + sum(n, 0, N-2, x[g^n mod N] * W_N^(g^(m+n) mod N)) for m = 0,1,...,N-2
) : Rader if is_prime(N);

// The reindexed sum is actually a circular convolution
sum(n, 0, N-2, x[g^n mod N] * W_N^(g^(m+n) mod N)) : Summation →
	convolution(x', w')[m] : Convolution
	where x'[n] = x[g^n mod N] and w'[n] = W_N^(g^n mod N);
```

The brilliant transformation here is that a prime-length DFT becomes a circular convolution of length N-1, which can be efficiently computed if N-1 is composite (often a power of 2):

```orbit
// Apply FFT-based fast convolution if N-1 is composite
convolution(x', w') : Convolution !: FastConvolution →
	ifft(fft(x') * fft(w')) : FastConvolution if is_composite(length(x'));
```

This demonstrates Orbit's ability to discover profound mathematical insights - that a prime-length problem can be transformed into a composite-length problem where the previously derived FFT techniques apply.

## Bluestein's Algorithm: Universal FFT

For completeness, Orbit can also discover Bluestein's chirp z-transform algorithm, which works for any length N by expressing the DFT as a convolution through a clever identity:

```orbit
// Bluestein's algorithm transforms any-length DFT into convolution
W_N^(j*k) : TwiddleFactor → W_N^((j^2+k^2-(j-k)^2)/2) : TwiddleFactor; // Corrected identity
													→ W_N^(j^2/2) * W_N^(k^2/2) * W_N^(-(j-k)^2/2) : TwiddleFactor;

// Express DFT as a linear convolution
dft(x, N) : DFT !: Bluestein → (
	// Multiply input by chirp
	let x_chirp = [x[j] * W_N^(-j^2/2) for j = 0 to N-1];

	// Prepare convolution kernel (chirp)
	let h_chirp = [W_N^(k^2/2) for k = -(N-1) to N-1]; // Needs chirp for negative indices too

	// Zero-pad to appropriate length (e.g., >= 2N-1, often power of 2) and compute linear convolution
	let y_conv = linear_convolution_fft(x_chirp, h_chirp); // Use FFT-based convolution

	// Multiply by output chirp (extract relevant part of convolution result)
	[y_conv[k + N - 1] * W_N^(-k^2/2) for k = 0 to N-1] // Adjust index for convolution result
) : Bluestein;
```
*(Note: Corrected Bluestein's identity and implementation details for clarity)*

This approach works for any N by padding to a suitable size (often a power of 2), offering a universal FFT algorithm derived purely from mathematical identities.

## Example: Tracing the Derivation for N=8

To illustrate how these rewrites transform a DFT into an FFT, let's trace the derivation for N=8:

```
dft(x, 8)
→ [dft(x, 8, k) for k = 0 to 7]

// Apply split to each dft(x, 8, k)
→ [dft(x_even, 4, k) + W_8^k * dft(x_odd, 4, k) for k = 0..3,
	 dft(x_even, 4, k) - W_8^k * dft(x_odd, 4, k) for k = 0..3]

// Recursively apply to the size-4 DFTs:
→ [
	[dft(x_even_even, 2, k) + W_4^k * dft(x_even_odd, 2, k) for k = 0..1,
	 dft(x_even_even, 2, k) - W_4^k * dft(x_even_odd, 2, k) for k = 0..1]
	+
	W_8^k * [dft(x_odd_even, 2, k) + W_4^k * dft(x_odd_odd, 2, k) for k = 0..1,
					 dft(x_odd_even, 2, k) - W_4^k * dft(x_odd_odd, 2, k) for k = 0..1]
	for k = 0..3 // This part needs correction: W_8^k applies differently to second half
]
// Refined Trace Visualization (Conceptual Butterfly):
// Level 1 (N=8 -> N=4): Compute dft(x_even, 4) and dft(x_odd, 4)
// Level 1 Combine: Combine results using W_8^k factors (k=0..3) for dft(x, 8, k) and dft(x, 8, k+4)

// Level 2 (N=4 -> N=2): Compute 4 DFTs of size 2 recursively (even_even, even_odd, odd_even, odd_odd)
// Level 2 Combine: Combine results using W_4^k factors (k=0..1)

// Level 3 (N=2 -> N=1): Compute 8 DFTs of size 1 (base cases)
// Level 3 Combine: Combine results using W_2^k factors (k=0)

→ Eventually resolves to the full butterfly structure via recursive application.
```

This derivation happens automatically through the application of our rewrite rules, without any explicit coding of the FFT algorithm.

## Example: Prime Length N=7 with Rader's Algorithm

For prime N=7, Orbit would apply Rader's algorithm:

```
// Find primitive root: g=3 for N=7 works (3^k mod 7 generates {1,2,3,4,5,6})
// Apply Rader's algorithm
dft(x, 7)
→ y[0] = x[0] + x[1] + x[2] + x[3] + x[4] + x[5] + x[6]

// For remaining indices, reindex using g=3:
// Indices: g^0=1, g^1=3, g^2=2, g^3=6, g^4=4, g^5=5 (all mod 7)

// Create convolution vectors (length N-1 = 6):
x_reordered = [x[1], x[3], x[2], x[6], x[4], x[5]] // x[g^n mod N] for n=0..5
w_reordered = [W_7^1, W_7^3, W_7^2, W_7^6, W_7^4, W_7^5] // W_N^(g^n mod N) for n=0..5

// Compute circular convolution (length 6) using FFT since length 6 = 2×3 is composite
conv_result = circular_convolution_fft(x_reordered, w_reordered)

// Add x[0] to each element of the convolution result
y_permuted = [x[0] + conv_result[m] for m = 0..5]

// Combine DC component and reorder output (using inverse mapping of g^m) to get the final result
y = [y[0]] + [y_permuted associated with y[g^m mod N]] // Map conv_result indices back
```

This transforms the prime-length DFT into a composite-length convolution, demonstrating Orbit's ability to discover sophisticated mathematical transformations.

## Example: Non-Power-of-2 Size N=12

For N=12, the generalized approach (Cooley-Tukey mixed-radix) would:

1.  First split by factor p=2 (or p=3): N=12 -> N/p = 6 (or 4). For p=2, creates 2 DFTs of size 6.
    `dft(x, 12, k) = dft(x_even, 6, k) + W_12^k * dft(x_odd, 6, k)` (for k=0..5, similar for k=6..11)
2.  Then split the size-6 problem by factor p=3 (or p=2): N=6 -> N/p = 2 (or 3). For p=3, creates 3 DFTs of size 2 from each size-6 DFT.
3.  Finally, solve the size-2 (or size-3) problems. Size-2 uses a simple butterfly. Size-3 could use Rader's or direct computation.

This mixed-radix approach still provides significant speedup over the naive O(N²) DFT, even though N=12 isn't a power of 2. Orbit applies the `FactorSplit` rule recursively.

## Role of Symmetry Groups in the Derivation

The key to this automatic derivation is Orbit's understanding of the underlying group-theoretic structure:

1.  **Cyclic Group C_N**: The twiddle factors W_N^k form a cyclic group under multiplication, with periodicity N. Orbit recognizes this structure via the `: C_N` annotation.

2.  **Subgroup Relationship**: When N is composite, the twiddle factors exhibit subgroup relationships that enable the divide-and-conquer approach. For example, the even-indexed twiddle factors `W_N^(2jk) = W_{N/2}^(jk)` relate the group C_N to its subgroup C_{N/2}.

3.  **Group Action Optimization**: The FFT butterfly structure emerges from optimizing the group action of twiddle factors on the input sequence through decomposition into smaller group actions based on subgroups.

4.  **Group Isomorphisms**: Rader's algorithm exploits the isomorphism between the multiplicative group (Z/NZ)* and a cyclic group C_{N-1} when N is prime, enabling transformation to a different domain (convolution) where the problem becomes tractable via efficient algorithms for composite lengths.

5.  **Cross-Domain Transformations**: Both Rader's and Bluestein's algorithms demonstrate Orbit's ability to discover transformations between problem domains (DFT to convolution) that preserve algebraic structure while enabling more efficient computation.

These symmetry properties are what Orbit leverages to automatically discover the FFT algorithm and its variants from first principles.

## Unified Selection Strategy

A fully-featured Orbit system could automatically choose the optimal FFT algorithm based on the input size N:

```orbit
// Unified FFT approach selecting the best algorithm
fft(x, N) : Transform →
	cooley_tukey_power_of_2_fft(x, N) : Transform if is_power_of_2(N);
	cooley_tukey_mixed_radix_fft(x, N) : Transform if is_composite(N) and not is_power_of_2(N);
	rader_fft(x, N) : Transform if is_prime(N); // Often combined with Cooley-Tukey for N-1
	bluestein_fft(x, N) : Transform otherwise; // Fallback for any length, or potentially optimal for some lengths
```
*(Note: Refined the selection strategy description)*

This demonstrates how Orbit can build a decision tree for selecting the optimal approach based on input characteristics, without these algorithms being explicitly encoded.

## Beyond FFT: Generalization to Other Algorithms

The approach demonstrated here can be generalized to discover other divide-and-conquer algorithms:

```orbit
// General divide-and-conquer pattern
operation(data, N) : DivideAndConquer !: Split → (
	combine([operation(subset(data, i), N/p) for i = 0 to p-1], combine_params...) // Combine needs parameters
) : Split if can_split_problem(N, p);

// The condition function determines when we can divide
can_split_problem(N, p) → eval(N % p == 0 && N > 1 && p > 1); // Ensure p is a non-trivial factor
```

This template can potentially discover algorithms like:

1.  **Karatsuba multiplication**: O(n^log2(3) ≈ n^1.58) integer multiplication via splitting into 3 subproblems.
2.  **Strassen's algorithm**: O(n^log2(7) ≈ n^2.81) matrix multiplication via splitting into 7 subproblems.
3.  **Fast convolution algorithms**: Using the FFT pattern for other linear convolutions via convolution theorem.
4.  **Divide-and-conquer sorting**: Recursive structure of merge sort, quicksort based on splitting.

Additionally, the cross-domain transformation insights from Rader's and Bluestein's algorithms suggest Orbit could potentially discover other non-obvious algorithmic optimizations by identifying structural equivalences between seemingly different problems.

## Conclusion

This document demonstrates how Orbit's group-theoretic approach enables automatic discovery of the FFT algorithm family from the DFT definition, without explicitly encoding them. By expressing the mathematical symmetries as rewrite rules and leveraging algebraic group structures, Orbit can derive multiple variants of the FFT algorithm suited to different input sizes.

The key insights are:

1.  **Algebraic structure recognition**: Identifying the cyclic group structure in DFT's twiddle factors and related groups like (Z/NZ)*.
2.  **Conditional rewrites**: Applying transformations based on number-theoretic properties of the size N (prime, composite, power-of-2).
3.  **Recursive pattern emergence**: The FFT structure emerges naturally from repeated application of divide-and-conquer rewrite rules.
4.  **Cross-domain transformations**: Problems in one domain (like prime-length DFT) can be mapped to different domains (like composite-length convolution) with better algorithms, leveraging isomorphisms or identities like Bluestein's.
5.  **Unified algorithm selection**: A single framework based on rewrite rules and conditions can automatically choose among Cooley-Tukey, Rader's, and Bluestein's algorithms based on input characteristics.
6.  **Automatic identity discovery**: The system can systematically explore algebraic properties (like twiddle factor identities) to discover the core relationships that enable optimization. This is now primarily achieved by establishing e-class equivalence between transformed kernel expressions, relying on a base set of fundamental algebraic rules.

This capability represents a significant step toward automated algorithm discovery - where Orbit doesn't just optimize existing algorithms but can actually derive complex algorithms from mathematical first principles, potentially discovering novel optimizations that human programmers might overlook.
