# Probability Part 3: Transformations and Combinations of Random Variables

*This chapter builds upon the catalogue of distributions in [Probability Part 2](./probability2.md) and the foundations in [Probability Part 1](./probability1.md). It explores how Orbit can represent and reason about the distributions of random variables that result from various transformations and combinations. This is analogous to how [`matrix3.md`](./matrix3.md) details matrix operations and decompositions.*

## Introduction

Program variables are rarely static; they are transformed by operations, combined with other variables, and influenced by control flow. Understanding how these actions affect their underlying probability distributions is crucial for probabilistic program analysis. This chapter details methods for deriving the distribution of a new random variable `Y` when `Y` is a function of one or more other random variables `X₁, ..., Xₙ` whose distributions are known. Orbit aims to symbolically perform these derivations using rewrite rules, leveraging its domain system to manage distributional properties.

## 3.1. Functions of a Single Random Variable

When a random variable `X` with a known distribution `D_X` is transformed by a function `g`, the resulting random variable `Y = g(X)` will have a new distribution `D_Y`.

### 3.1.1. General Case: Deriving Distribution of `Y = g(X)`

For a random variable `X` with PDF `f_X(x)` (or PMF `p_X(x)`) and CDF `F_X(x)`, and a transformation `Y = g(X)`:

*   **CDF Technique (for monotonic `g`):**
    If `g` is strictly increasing, `F_Y(y) = P(Y ≤ y) = P(g(X) ≤ y) = P(X ≤ g⁻¹(y)) = F_X(g⁻¹(y))`.
    If `g` is strictly decreasing, `F_Y(y) = P(g(X) ≤ y) = P(X ≥ g⁻¹(y)) = 1 - F_X(g⁻¹(y))` (assuming `X` is continuous here for the `1 - F_X` part, for discrete it would be `1 - P(X < g⁻¹(y))`).
    The PDF `f_Y(y)` can then be found by differentiating `F_Y(y)`: `f_Y(y) = d/dy F_Y(y)`.

*   **Change of Variable Formula (for continuous, differentiable, invertible `g`):**
    If `Y = g(X)` and `g` is differentiable and has an inverse `x = g⁻¹(y)` such that `dx/dy = d(g⁻¹(y))/dy` exists and is continuous, then the PDF of `Y` is given by:
    `f_Y(y) = f_X(g⁻¹(y)) * |d(g⁻¹(y))/dy|`.
    This formula can be extended to cases where `g` is not monotonic by summing over the preimages `x_k` such that `g(x_k)=y`: `f_Y(y) = Σ_k f_X(g_k⁻¹(y)) * |d(g_k⁻¹(y))/dy|` for each invertible branch `g_k`.

*   **For Discrete Variables:**
    The PMF of `Y` is `p_Y(y) = Σ_{x | g(x)=y} p_X(x)`. This involves summing the probabilities of all `x` values that map to a given `y`.

Orbit can implement these general techniques through rewrite rules for specific classes of functions `g` or rely on pre-derived results for common transformations. The challenge lies in symbolically computing inverses, derivatives, and sums.

### 3.1.2. Linear Transformations: `Y = aX + b`

If `X` is a random variable with mean `E[X]` and variance `Var(X)`, and `Y = aX + b` where `a` and `b` are constants:
*   `E[Y] = a * E[X] + b`
*   `Var(Y) = a² * Var(X)`

These rules for mean and variance hold universally, even if the resulting distribution `D_Y` is not easily catalogued.

**Orbit Rules and Domain Transformations:**

```orbit
// General rules for mean and variance of linear transformations
// Let X_expr be an expression and D_X = DistributionOf(X_expr)
E(DistributionOf(a * X_expr + b)) ↔ a * E(D_X) + b
	if is_const(a) && is_const(b);

Var(DistributionOf(a * X_expr + b)) ↔ a^2 * Var(D_X)
	if is_const(a) && is_const(b);

// Specific distribution transformations via a conceptual LinearTransform operator
// Operator: LinearTransform(distribution, a, b)

LinearTransform(D_X : Normal(μ, σ_sq), a, b) → Normal(a*μ + b, a^2 * σ_sq);

LinearTransform(D_X : UniformContinuous(min_v, max_v), a, b) →
		if a > 0.0 then UniformContinuous(a*min_v + b, a*max_v + b)
		else if a < 0.0 then UniformContinuous(a*max_v + b, a*min_v + b)
		else DistributionOf(b); // Results in a PointMass/DiracDelta at b

LinearTransform(D_X : Gamma(α, β_rate), a, b) →
		if a > 0.0 then ShiftedScaledGamma(α, β_rate/a, b, a) // Parameters: shape, new_rate, shift, scale
		// Note: ShiftedScaledGamma might not be a base domain; might need a more general representation
		// or this rule applies only if b=0 (scaling only) yielding Gamma(α, β_rate/a)
		else if a == 0.0 then DistributionOf(b) // PointMass
		else /* a < 0 */ Undefined; // Standard Gamma is non-negative

// Rule to connect expression to the transformation operator:
DistributionOf(a * X_expr + b) ↔ LinearTransform(DistributionOf(X_expr), a, b)
	if is_const(a) && is_const(b);
```
`PointMass(c)` (or `DiracDelta(c)` for continuous) represents a distribution `P(X=c)=1`.
`ShiftedScaledGamma` is a conceptual placeholder; handling scaled/shifted distributions might involve a generic `TransformedDistribution` domain or explicit PDF/CDF manipulation.

### 3.1.3. Common Non-linear Transformations

Orbit will catalogue rules for common non-linear transformations.

*   **`Y = X²`**
    *   If `X ~ Normal(0, 1)`, then `Y ~ ChiSquared(1)`.
        ```orbit
		// X_expr such that DistributionOf(X_expr) is Normal(0.0, 1.0)
		DistributionOf(X_expr^2) ↔ ChiSquared(1)
		  if DistributionOf(X_expr) == Normal(0.0, 1.0);
```
    *   If `X ~ Normal(μ, σ²)`, `Y = ((X-μ)/σ)² ~ ChiSquared(1)`. Then `X²` needs more complex handling (Non-central Chi-Squared if `μ != 0`).
    *   If `X ~ UniformContinuous(-c, c)` with `c > 0`, then `Y = X²` has PDF `f_Y(y) = 1/(2c*sqrt(y))` for `0 < y < c²`.
    *   If `X` has PDF `f_X(x)`, and `Y=X²`, then for `y > 0`, `F_Y(y) = P(X² ≤ y) = P(-sqrt(y) ≤ X ≤ sqrt(y)) = F_X(sqrt(y)) - F_X(-sqrt(y))`. Then `f_Y(y) = (f_X(sqrt(y)) + f_X(-sqrt(y))) / (2*sqrt(y))`. If `f_X` is symmetric around 0, `f_Y(y) = f_X(sqrt(y))/sqrt(y)`.

*   **`Y = log(X)` and `Y = exp(X)`** (assuming base `e` for `log`)
    *   If `X ~ LogNormal(μ, σ²)` (defined such that `log(X) ~ Normal(μ, σ²)`), then:
        ```orbit
		// X_expr such that DistributionOf(X_expr) is LogNormal(μ, σ_sq)
		DistributionOf(log(X_expr)) ↔ Normal(μ, σ_sq)
		  if DistributionOf(X_expr) == LogNormal(μ, σ_sq);
```
    *   Conversely, if `X ~ Normal(μ, σ²)`, then:
        ```orbit
		// X_expr such that DistributionOf(X_expr) is Normal(μ, σ_sq)
		DistributionOf(exp(X_expr)) ↔ LogNormal(μ, σ_sq)
		  if DistributionOf(X_expr) == Normal(μ, σ_sq);
```
    * If `X ~ UniformContinuous(a,b)` with `0 < a < b`, then `Y = log(X)` has CDF `F_Y(y) = (exp(y) - a) / (b-a)` for `log(a) < y < log(b)`. PDF is `exp(y)/(b-a)`.

*   **`Y = abs(X)`**
    *   If `X` is continuous with PDF `f_X(x)` and CDF `F_X(x)`: For `y > 0`, `F_Y(y) = P(abs(X) ≤ y) = P(-y ≤ X ≤ y) = F_X(y) - F_X(-y)`. Then `f_Y(y) = f_X(y) + f_X(-y)` for `y > 0`.
    *   If `X ~ Normal(0, σ²)`, then `Y ~ FoldedNormal(0, σ²)`. PDF `f_Y(y) = (2 / (σ*sqrt(2π))) * exp(-y² / (2σ²))` for `y ≥ 0`.
        ```orbit
		// FoldedNormal(μ_orig, σ_orig_sq) as a potential domain
		DistributionOf(abs(X_expr)) ↔ FoldedNormal(0.0, σ_sq)
		  if DistributionOf(X_expr) == Normal(0.0, σ_sq);
```
    *   If `X ~ Cauchy(0, γ)`, then `Y ~ HalfCauchy(0, γ)`. PDF `f_Y(y) = (2 / (πγ(1 + (y/γ)²)))` for `y ≥ 0`.
        ```orbit
		// HalfCauchy(loc_orig, scale_orig) as a potential domain
		DistributionOf(abs(X_expr)) ↔ HalfCauchy(0.0, γ)
		  if DistributionOf(X_expr) == Cauchy(0.0, γ);
```

## 3.2. Operations on Multiple Random Variables

When combining two or more random variables, the distribution of the result depends on the operation and the joint distribution of the variables, particularly their independence.

### 3.2.1. Sums, Differences, Products, Quotients

Let `X` and `Y` be random variables with distributions `D_X` and `D_Y` respectively.

*   **Sums and Differences:** (`Z = X ± Y`)
    *   `E[Z] = E[D_X] ± E[D_Y]` (always holds).
    *   If `X` and `Y` are independent: `Var(Z) = Var(D_X) + Var(D_Y)`.
        ```orbit
		// D_X = DistributionOf(X_expr), D_Y = DistributionOf(Y_expr)
		E(DistributionOf(X_expr + Y_expr)) ↔ E(D_X) + E(D_Y);
		E(DistributionOf(X_expr - Y_expr)) ↔ E(D_X) - E(D_Y);

		Var(DistributionOf(X_expr + Y_expr)) ↔ Var(D_X) + Var(D_Y)
		  if D_X : IndependentOf(D_Y);

		Var(DistributionOf(X_expr - Y_expr)) ↔ Var(D_X) + Var(D_Y)
		  if D_X : IndependentOf(D_Y);
```
*   **Products:** (`Z = XY`)
    *   If `X` and `Y` are independent: `E[Z] = E[D_X] * E[D_Y]`.
    *   If `X` and `Y` are independent: `Var(Z) = Var(D_X)Var(D_Y) + (E[D_X])²Var(D_Y) + (E[D_Y])²Var(D_X)`.
        ```orbit
		// D_X = DistributionOf(X_expr), D_Y = DistributionOf(Y_expr)
		E(DistributionOf(X_expr * Y_expr)) ↔ E(D_X) * E(D_Y)
		  if D_X : IndependentOf(D_Y);

		Var(DistributionOf(X_expr * Y_expr)) ↔ Var(D_X)*Var(D_Y) + E(D_X)^2*Var(D_Y) + E(D_Y)^2*Var(D_X)
		  if D_X : IndependentOf(D_Y);
```
*   **Quotients:** (`Z = X/Y`)
    *   `E[Z]` and `Var(Z)` are generally complex and may not exist (e.g., if `P(Y=0) > 0` or `Y` can be close to 0). Approximations (e.g., using Taylor series expansion, known as the delta method) can be used with caution.
    *   Special case: Ratio of two independent standard Normal variables `X, Y ~ N(0,1)` is `Cauchy(0,1)`.
        ```orbit
		// D_X = DistributionOf(X_expr), D_Y = DistributionOf(Y_expr)
		DistributionOf(X_expr / Y_expr) ↔ Cauchy(0.0, 1.0)
		  if D_X == Normal(0.0, 1.0) && D_Y == Normal(0.0, 1.0) && D_X : IndependentOf(D_Y);
```

### 3.2.2. Convolutions: Sums of Independent Random Variables

If `X` and `Y` are independent continuous random variables with PDFs `f_X(x)` and `f_Y(y)`, the PDF of `Z = X + Y` is given by their convolution: `f_Z(z) = ∫ f_X(x) * f_Y(z-x) dx` (integration over the support of `X`). For discrete variables, a sum is used: `P(Z=z) = Σ_k P(X=k)P(Y=z-k)`.

Orbit will store rules for sums of common independent distributions:

```orbit
// Operator: SumOfIndependent(Dist1, Dist2, ...)

SumOfIndependent(D1 : Normal(μ1, σ1_sq), D2 : Normal(μ2, σ2_sq)) ↔ Normal(μ1+μ2, σ1_sq+σ2_sq);

SumOfIndependent(D_list : Array<Normal(μ, σ_sq)>) ↔
	Normal(length(D_list)*μ, length(D_list)*σ_sq)
	if AllIdentical(D_list); // Simplified for i.i.d.

SumOfIndependent(D1 : Poisson(λ1), D2 : Poisson(λ2)) ↔ Poisson(λ1+λ2);

SumOfIndependent(D1 : Gamma(α1, β_rate), D2 : Gamma(α2, β_rate)) ↔ Gamma(α1+α2, β_rate);
// This implies:
SumOfIndependent(D1 : ChiSquared(k1), D2 : ChiSquared(k2)) ↔ ChiSquared(k1+k2);
// From Gamma(k/2, 0.5)

SumOfIndependent(D_list : Array<Exponential(λ)>) ↔ Gamma(length(D_list), λ)
	if AllIdentical(D_list);

SumOfIndependent(D1 : Binomial(n1, p), D2 : Binomial(n2, p)) ↔ Binomial(n1+n2, p);

SumOfIndependent(D1 : NegativeBinomial(r1, p), D2 : NegativeBinomial(r2, p)) ↔ NegativeBinomial(r1+r2, p);

// Rule to connect expressions to the operator:
DistributionOf(X_expr + Y_expr) ↔ SumOfIndependent(DistributionOf(X_expr), DistributionOf(Y_expr))
  if DistributionOf(X_expr) : IndependentOf(DistributionOf(Y_expr));
// Similar for n-ary sum `DistributionOf(`+`(args...))`
```

### 3.2.3. Approximations: Central Limit Theorem (CLT)

The CLT states that the sum (or average) of a large number of independent and identically distributed (i.i.d.) random variables, each with finite mean `μ` and variance `σ²`, will be approximately normally distributed, regardless of the original distribution.
*   If `X₁, ..., Xₙ` are i.i.d. with mean `μ` and variance `σ²`, then their sum `Sₙ = ΣXᵢ` is approximately `Normal(nμ, nσ²)` for large `n`.
*   The sample mean `X̄ = Sₙ/n` is approximately `Normal(μ, σ²/n)` for large `n`.

**Orbit Implications:**
Orbit can use the CLT to approximate the distribution of a sum or average when:
1.  The number of variables `n` is "large enough" (heuristic, e.g., `n > 30`).
2.  The variables are (approximately) independent and (approximately) identically distributed.
3.  Direct derivation of the sum's distribution is intractable or not catalogued.

```orbit
// Conceptual rule for CLT application on a sum of expressions
DistributionOf(`+`(Expr_list)) ↔ Normal(n * μ_common, n * σ_sq_common) : IsApproximation
	if let D_list = map(Expr_list, DistributionOf);
		 let n = length(D_list);
		 n > 30 && // Heuristic for "large enough"
		 AllTrue(map_pairwise(D_list, IndependentOf)) && // Check all pairs for independence
		 AllIdentical(D_list, μ_common, σ_sq_common); // Checks if all distributions are identical and extracts common mean/var

// `IsApproximation` is a domain tag indicating the result is not exact.
// `AllIdentical` would check if all distributions in D_list are the same type and parameters.
```

## 3.3. Mixture Distributions

Mixture distributions arise when a random variable's distribution is a weighted combination of other distributions.

### 3.3.1. Definition

A random variable `Y` follows a mixture distribution if its PDF (or PMF) `f_Y(y)` is of the form:
`f_Y(y) = Σᵢ wᵢ * fᵢ(y)`
where `fᵢ(y)` are PDFs (or PMFs) of component distributions `Dᵢ`, and `wᵢ` are weights such that `wᵢ ≥ 0` and `Σᵢ wᵢ = 1`.

### 3.3.2. Orbit Domain

Orbit represents mixture distributions as:
```orbit
MixtureDistribution(
	weights: Vector<Real>,                  // e.g., [w1, w2, ..., wk]
	distributions: Vector<Distribution>     // e.g., [D1, D2, ..., Dk]
) ⊂ Distribution<ElementType, DomainSpace>
```
The `ElementType` and `DomainSpace` would typically be common to all component distributions or generalized.

### 3.3.3. Importance for Modeling

Mixture distributions are crucial for:
*   Modeling outcomes after conditional branches in a program (e.g., `if (cond) then x = expr1 else x = expr2`, where `DistributionOf(x)` becomes a mixture of `DistributionOf(expr1)` and `DistributionOf(expr2)` weighted by `P(cond)` and `1-P(cond)`).
*   Representing data from heterogeneous populations.
*   Approximating complex, multi-modal distributions.

### 3.3.4. Orbit Rules for Properties of Mixtures

If `Y` is drawn from distribution `Dᵢ` with probability `wᵢ`, and `E[Dᵢ]` and `Var(Dᵢ)` are the mean and variance of `Dᵢ`:
*   **Mean:** `E[Y] = Σᵢ wᵢ * E[Dᵢ]`
*   **Variance:** `Var(Y) = Σᵢ wᵢ * (Var(Dᵢ) + (E[Dᵢ] - E[Y])²)`
    Alternatively: `Var(Y) = (Σᵢ wᵢ * (Var(Dᵢ) + E[Dᵢ]²)) - (E[Y])²` which is `E[Y²] - (E[Y])²`.

```orbit
// M_dist : MixtureDistribution(weights_vec, dists_vec)

E(M_dist : MixtureDistribution(wv, dv)) ↔
		vector_dot_product(wv, map(dv, E)); // sum(w_i * E[D_i])

Var(M_dist : MixtureDistribution(wv, dv)) ↔
	let means_i = map(dv, E);
	let overall_mean = vector_dot_product(wv, means_i);
	let variances_i = map(dv, Var);
	let term1_components = vector_map_product_elementwise(wv, variances_i); // [w_i * Var(D_i)]
	let squared_diff_means = map(means_i, fn(μ_i) = (μ_i - overall_mean)^2);
	let term2_components = vector_map_product_elementwise(wv, squared_diff_means); // [w_i * (E[D_i] - E[Y])^2]
	sum(term1_components) + sum(term2_components);

// Helper function concepts:
// vector_dot_product(v1, v2) = sum of v1[i]*v2[i]
// map(vector, func) - applies func to each element
// vector_map_product_elementwise(v1, v2) - element-wise product [v1[i]*v2[i]]
```

## 3.4. Order Statistics

Order statistics concern the distributions of sorted random variables from a sample.

### 3.4.1. Distributions of `Min(X₁, ..., Xₙ)` and `Max(X₁, ..., Xₙ)`

Let `X₁, ..., Xₙ` be `n` independent and identically distributed (i.i.d.) random variables with CDF `F_X(x)` and PDF `f_X(x)`.
Let `Y_min = Min(X₁, ..., Xₙ)` and `Y_max = Max(X₁, ..., Xₙ)`.

*   **CDF of Maximum:** `F_max(y) = P(Y_max ≤ y) = P(all Xᵢ ≤ y) = (F_X(y))ⁿ`
    *   PDF of Maximum: `f_max(y) = n * (F_X(y))ⁿ⁻¹ * f_X(y)`
*   **CDF of Minimum:** `F_min(y) = P(Y_min ≤ y) = 1 - P(Y_min > y) = 1 - P(all Xᵢ > y) = 1 - (1 - F_X(y))ⁿ`
    *   PDF of Minimum: `f_min(y) = n * (1 - F_X(y))ⁿ⁻¹ * f_X(y)`

**Examples and Orbit Rules:**
*   If `Xᵢ ~ UniformContinuous(0, 1)` (so `F_X(x) = x`, `f_X(x) = 1` for `0 ≤ x ≤ 1`):
    *   `Y_max ~ Beta(n, 1)`.
    *   `Y_min ~ Beta(1, n)`.
    ```orbit
	// X_dists is an array of n UniformContinuous(0.0, 1.0) distributions
	DistributionOf(Max(X_expr_list)) ↔ Beta(length(X_expr_list), 1.0)
	  if AllDistributionsMatch(map(X_expr_list, DistributionOf), UniformContinuous(0.0, 1.0)) &&
	     AllIndependent(map(X_expr_list, DistributionOf));

	DistributionOf(Min(X_expr_list)) ↔ Beta(1.0, length(X_expr_list))
	  if AllDistributionsMatch(map(X_expr_list, DistributionOf), UniformContinuous(0.0, 1.0)) &&
	     AllIndependent(map(X_expr_list, DistributionOf));
```
*   If `Xᵢ ~ Exponential(λ)` (so `F_X(x) = 1 - exp(-λx)`, `f_X(x) = λexp(-λx)` for `x ≥ 0`):
    *   `Y_min = Min(X₁, ..., Xₙ) ~ Exponential(nλ)`. This is a key property in reliability.
    ```orbit
	// X_dists is an array of n Exponential(λ) distributions
	DistributionOf(Min(X_expr_list)) ↔ Exponential(length(X_expr_list) * λ_common)
	  if AllDistributionsMatchParam(map(X_expr_list, DistributionOf), Exponential(_), λ_common) &&
	     AllIndependent(map(X_expr_list, DistributionOf));
	// AllDistributionsMatchParam checks type and extracts common parameter λ_common.
```

**Orbit Implications for general order statistics:**
Orbit can use these formulas to derive distributions for `min` and `max` operations. For the `k`-th order statistic, the PDF is more complex but can be represented. These are vital for analyzing extreme values, percentiles, or failure conditions (e.g., time to `k`-th failure if `Xᵢ` are component lifetimes).

```orbit
// General (conceptual) operator for OrderStatistic
// OrderStatistic(Dist_X_common, n, k) -> DistributionOfKthOrderStat
// where Dist_X_common is the i.i.d. distribution of X_i.

// DistributionOf(Max(X_expr_list)) can use OrderStatistic with k=n
DistributionOf(Max(X_expr_list)) ↔ OrderStatistic(D_common, n, n)
	if let D_list = map(X_expr_list, DistributionOf);
		 let n = length(D_list);
		 AllIndependentAndIdentical(D_list, D_common); // D_common is the shared dist

// DistributionOf(Min(X_expr_list)) can use OrderStatistic with k=1
DistributionOf(Min(X_expr_list)) ↔ OrderStatistic(D_common, n, 1)
	if let D_list = map(X_expr_list, DistributionOf);
		 let n = length(D_list);
		 AllIndependentAndIdentical(D_list, D_common);
```

---

This chapter has outlined how Orbit can systematically derive or represent the distributions of variables resulting from transformations and combinations. These capabilities are foundational for the more complex analyses discussed in subsequent chapters, such as dealing with multivariate distributions ([Probability Part 4](./probability4.md)) and performing probabilistic inference in Orbit programs ([Probability Part 5](./probability5.md)).
