# Probability Part 2: A Catalogue of Common Probability Distributions in Orbit

*Following the foundational concepts in [Probability Part 1: Foundations](./probability1.md), this chapter provides a catalogue of common probability distributions that Orbit can represent and reason about. For each distribution, we define its Orbit domain, list its key mathematical properties (such as PMF/PDF, CDF, mean, and variance), and detail its relationships with other distributions. This is analogous to how [`matrix2.md`](./matrix2.md) details various specialized matrix structures.*

## Introduction

A rich library of known probability distributions is essential for modeling various phenomena encountered in programs. By defining these distributions as specific domains within Orbit, we can associate them with expressions and variables, enabling specialized analysis and optimization. The properties listed for each distribution can be accessed or inferred by Orbit's rewrite rules, for example, through dedicated functions like `mean(Distribution)` or `variance(Distribution)` as outlined in [Probability Part 1](./probability1.md).

## 2.0. Hierarchy and Relationships of Probability Distributions

To organize these distributions and leverage their interconnections, we define a hierarchy and outline key relationships. All specific distributions are subtypes of the general `Distribution<Type, DomainSpace>` domain.

```orbit
// Base Domains from probability1.md
// Distribution<Type, DomainSpace>
// DiscreteSpace
// ContinuousSpace

// --- Univariate Discrete Distributions ---

// Bernoulli & Related
Bernoulli(p: Real) ⊂ Distribution<Integer, DiscreteSpace> // Outputs 0 or 1
Binomial(n: Integer, p: Real) ⊂ Distribution<Integer, DiscreteSpace>
Categorical(probs: Vector<Real>) ⊂ Distribution<Integer, DiscreteSpace> // Assumes outcomes 0..K-1 for a K-dim vector

// Geometric & Related
Geometric(p: Real) ⊂ Distribution<Integer, DiscreteSpace> // Number of trials X >= 1
NegativeBinomial(r: Integer, p: Real) ⊂ Distribution<Integer, DiscreteSpace> // Number of trials X >= r

// Poisson
Poisson(lambda: Real) ⊂ Distribution<Integer, DiscreteSpace>

// Uniform Discrete
UniformDiscrete(a: Integer, b: Integer) ⊂ Distribution<Integer, DiscreteSpace>

// --- Univariate Continuous Distributions ---

// Uniform Continuous
UniformContinuous(a: Real, b: Real) ⊂ Distribution<Real, ContinuousSpace>

// Normal & Related
Normal(mu: Real, sigma_sq: Real) ⊂ Distribution<Real, ContinuousSpace>
LogNormal(mu: Real, sigma_sq: Real) ⊂ Distribution<Real, ContinuousSpace>
StudentT(nu: Real) ⊂ Distribution<Real, ContinuousSpace> // nu are degrees of freedom
Cauchy(x0: Real, gamma: Real) ⊂ Distribution<Real, ContinuousSpace>

// Exponential & Related (Gamma family)
Exponential(lambda: Real) ⊂ Distribution<Real, ContinuousSpace>
Gamma(alpha_shape: Real, beta_rate: Real) ⊂ Distribution<Real, ContinuousSpace>
ChiSquared(k: Integer) ⊂ Distribution<Real, ContinuousSpace> // k are degrees of freedom

// Beta
Beta(alpha_shape: Real, beta_shape: Real) ⊂ Distribution<Real, ContinuousSpace>

// Laplace
Laplace(mu: Real, b_scale: Real) ⊂ Distribution<Real, ContinuousSpace>

// --- Multivariate Distributions ---

// Multinomial & Dirichlet (Discrete counts, Continuous parameters)
Multinomial(n: Integer, probs: Vector<Real>) ⊂ Distribution<Vector<Integer>, DiscreteSpace>
Dirichlet(alphas: Vector<Real>) ⊂ Distribution<Vector<Real>, ContinuousSpace> // Vector<Real> where sum is 1

// Multivariate Normal & Wishart (Continuous)
MultivariateNormal(mean_vec: Vector<Real>, cov_matrix: Matrix<Real>) ⊂ Distribution<Vector<Real>, ContinuousSpace>
Wishart(scale_matrix: Matrix<Real>, nu_df: Real) ⊂ Distribution<Matrix<Real>, ContinuousSpace> // nu_df are degrees of freedom
InverseWishart(scale_matrix: Matrix<Real>, nu_df: Real) ⊂ Distribution<Matrix<Real>, ContinuousSpace>
```

**Key Conceptual Relationships (to be formalized as rewrite rules or used in transformations in Chapter 3):**

*   `Bernoulli(p) ↔ Binomial(1, p)`
*   `Binomial(n, p)` as sum of `n` i.i.d. `Bernoulli(p)`.
*   `Categorical(probs) ↔ Multinomial(1, probs)`
*   `Multinomial(n, probs)` as sum of `n` i.i.d. `Categorical(probs)`.
*   `Geometric(p) ↔ NegativeBinomial(1, p)`
*   `NegativeBinomial(r, p)` as sum of `r` i.i.d. `Geometric(p)`.
*   `Poisson(λ)` as limiting form of `Binomial(n,p)` where `n*p → λ`.
*   Linear transformation of `Normal` is `Normal`.
*   Sum of independent `Normal` is `Normal`.
*   `LogNormal(μ, σ²)` is `exp(X)` where `X ~ Normal(μ, σ²)`.
*   `Exponential(λ) ↔ Gamma(1, λ)`.
*   `ChiSquared(k) ↔ Gamma(k/2.0, 0.5)`.
*   `StudentT(ν)` from `Normal(0,1)` and `ChiSquared(ν)`.
*   `Cauchy(0,1)` from ratio of two i.i.d. `Normal(0,1)`.
*   `Gamma(α, β)` as sum of `α` i.i.d. `Exponential(β)` if `α` is integer.
*   Marginals and conditionals of `MultivariateNormal` are `Normal` or `MultivariateNormal`.
*   `Dirichlet([α1, α2]) ↔ Beta(α1, α2)`.

## 2.1. Discrete Distributions

### 2.1.1. Bernoulli Distribution

*   **Description:** Represents a single trial with two possible outcomes (e.g., success/failure, 1/0).
*   **Orbit Domain:** `Bernoulli(p: Real)` (`0 ≤ p ≤ 1`).
*   **PMF:** `P(X=1) = p`, `P(X=0) = 1-p`.
*   **Mean:** `p`.
*   **Variance:** `p * (1-p)`.
*   **Relationships & Specializations:**
    *   Is a special case of `Binomial(1, p)`.
        ```orbit
		D : Bernoulli(p_val) ↔ Binomial(1, p_val);
```
*   **Orbit Rules/Properties (Conceptual):**
    ```orbit
	mean(D : Bernoulli(p_val)) → p_val;
	variance(D : Bernoulli(p_val)) → p_val * (1.0 - p_val);
```

### 2.1.2. Binomial Distribution

*   **Description:** Number of successes in `n` independent Bernoulli trials.
*   **Orbit Domain:** `Binomial(n: Integer, p: Real)` (`n ≥ 0`, `0 ≤ p ≤ 1`).
*   **PMF:** `P(X=k) = C(n, k) * p^k * (1-p)^(n-k)`.
*   **Mean:** `n * p`.
*   **Variance:** `n * p * (1-p)`.
*   **Relationships & Specializations:**
    *   If `n=1`, it is a `Bernoulli(p)` distribution.
    *   Can be derived from sum of `n` i.i.d. `Bernoulli(p)` variables (see [Probability Part 3](./probability3.md)).
    *   Approximates `Poisson(λ)` for large `n`, small `p`, with `λ = n*p`.
    *   Approximates `Normal(np, np(1-p))` for large `n`.
*   **Orbit Rules/Properties (Conceptual):**
    ```orbit
	mean(D : Binomial(n_val, p_val)) → n_val * p_val;
	variance(D : Binomial(n_val, p_val)) → n_val * p_val * (1.0 - p_val);
```

### 2.1.3. Categorical Distribution

*   **Description:** Single trial with `K` possible outcomes (indexed `0` to `K-1`).
*   **Orbit Domain:** `Categorical(probs: Vector<Real>)` (`probs` is `[p_0,...,p_(K-1)]`, `sum(probs) = 1`).
*   **PMF:** `P(X=i) = probs[i]`.
*   **Relationships & Specializations:**
    *   If `K=2` with `probs = [1-p, p]`, equivalent to `Bernoulli(p)` (mapping outcome 1 to success).
    *   Is a special case of `Multinomial(1, probs)`.
        ```orbit
		D : Categorical(probs_val) ↔ Multinomial(1, probs_val);
```

### 2.1.4. Geometric Distribution

*   **Description:** Number of trials `X` to get the first success (Variant: `X ∈ {1, 2, ...}`).
*   **Orbit Domain:** `Geometric(p: Real)` (`0 < p ≤ 1`).
*   **PMF:** `P(X=k) = (1-p)^(k-1) * p` for `k ≥ 1`.
*   **Mean:** `1/p`.
*   **Variance:** `(1-p) / p^2`.
*   **Relationships & Specializations:**
    *   Is a special case of `NegativeBinomial(1, p)`.
        ```orbit
		D : Geometric(p_val) ↔ NegativeBinomial(1, p_val);
```
*   **Orbit Rules/Properties (Conceptual):**
    ```orbit
	mean(D : Geometric(p_val)) → 1.0 / p_val;
	variance(D : Geometric(p_val)) → (1.0 - p_val) / (p_val * p_val);
```

### 2.1.5. Negative Binomial Distribution

*   **Description:** Number of trials `X` to get `r` successes (Variant: `X ∈ {r, r+1, ...}`).
*   **Orbit Domain:** `NegativeBinomial(r: Integer, p: Real)` (`r ≥ 1`, `0 < p ≤ 1`).
*   **PMF:** `P(X=k) = C(k-1, r-1) * p^r * (1-p)^(k-r)` for `k ≥ r`.
*   **Mean:** `r/p`.
*   **Variance:** `r*(1-p) / p^2`.
*   **Relationships & Specializations:**
    *   If `r=1`, it is a `Geometric(p)` distribution.
    *   Can be derived from sum of `r` i.i.d. `Geometric(p)` variables (see [Probability Part 3](./probability3.md)).
*   **Orbit Rules/Properties (Conceptual):**
    ```orbit
	mean(D : NegativeBinomial(r_val, p_val)) → r_val / p_val;
	variance(D : NegativeBinomial(r_val, p_val)) → r_val * (1.0 - p_val) / (p_val * p_val);
```

### 2.1.6. Poisson Distribution

*   **Description:** Number of events in a fixed interval if events occur with a known constant mean rate.
*   **Orbit Domain:** `Poisson(lambda: Real)` (`lambda > 0`).
*   **PMF:** `P(X=k) = (lambda^k * exp(-lambda)) / k!` for `k ≥ 0`.
*   **Mean:** `lambda`.
*   **Variance:** `lambda`.
*   **Relationships & Specializations:**
    *   Limiting form of `Binomial(n,p)` as `n→∞`, `p→0`, `np→lambda`.
    *   Sum of independent Poisson variables is Poisson (see [Probability Part 3](./probability3.md)).
*   **Orbit Rules/Properties (Conceptual):**
    ```orbit
	mean(D : Poisson(lambda_val)) → lambda_val;
	variance(D : Poisson(lambda_val)) → lambda_val;
```

### 2.1.7. Discrete Uniform Distribution

*   **Description:** `N` equally likely distinct integer values.
*   **Orbit Domain:** `UniformDiscrete(a: Integer, b: Integer)` (`a ≤ b`).
*   **PMF:** `P(X=k) = 1/(b-a+1)` for `k ∈ {a, ..., b}`.
*   **Mean:** `(a+b) / 2.0`.
*   **Variance:** `((b-a+1)^2 - 1) / 12.0`.

## 2.2. Continuous Distributions

### 2.2.1. Continuous Uniform Distribution

*   **Description:** All values in a finite interval `[a,b]` are equally likely.
*   **Orbit Domain:** `UniformContinuous(a: Real, b: Real)` (`a < b`).
*   **PDF:** `f(x) = 1/(b-a)` for `a ≤ x ≤ b`.
*   **Mean:** `(a+b) / 2.0`.
*   **Variance:** `(b-a)^2 / 12.0`.
*   **Relationships & Specializations:**
    *   Is a special case of `Beta(1.0, 1.0)` when scaled to `[0,1]` (see [Probability Part 3](./probability3.md) for scaling).
        ```orbit
		// For the standard uniform on [0,1]
		D : Beta(1.0, 1.0) ↔ UniformContinuous(0.0, 1.0);
```
*   **Orbit Rules/Properties (Conceptual):**
    ```orbit
	mean(D : UniformContinuous(a_val, b_val)) → (a_val + b_val) / 2.0;
	variance(D : UniformContinuous(a_val, b_val)) → pow(b_val - a_val, 2) / 12.0;
```

### 2.2.2. Normal (Gaussian) Distribution

*   **Description:** Bell-shaped distribution, central to probability theory (Central Limit Theorem).
*   **Orbit Domain:** `Normal(mu: Real, sigma_sq: Real)` (`sigma_sq > 0`).
*   **PDF:** `f(x) = (1 / (sqrt(2*pi*sigma_sq))) * exp(-(x-mu)^2 / (2*sigma_sq))`.
*   **Mean:** `mu`.
*   **Variance:** `sigma_sq`.
*   **Relationships & Specializations:**
    *   Standard Normal: `Normal(0.0, 1.0)`.
    *   Linear transformation `aX+b` of a Normal RV `X` is Normal.
    *   Sum of independent Normal RVs is Normal (see [Probability Part 3](./probability3.md)).
    *   If `X ~ Normal(mu, sigma_sq)`, then `exp(X) ~ LogNormal(mu, sigma_sq)`.
*   **Orbit Rules/Properties (Conceptual):**
    ```orbit
	mean(D : Normal(mu_val, _)) → mu_val;
	variance(D : Normal(_, sig_sq_val)) → sig_sq_val;
```

### 2.2.3. Log-Normal Distribution

*   **Description:** `X` is log-normally distributed if `log(X)` is normally distributed.
*   **Orbit Domain:** `LogNormal(mu: Real, sigma_sq: Real)` (`mu` and `sigma_sq` are mean/variance of `log(X)`).
*   **PDF:** `f(x) = (1 / (x * sqrt(sigma_sq) * sqrt(2*pi))) * exp(-(log(x)-mu)^2 / (2*sigma_sq))` for `x > 0`.
*   **Mean:** `exp(mu + sigma_sq/2.0)`.
*   **Variance:** `(exp(sigma_sq) - 1.0) * exp(2.0*mu + sigma_sq)`.
*   **Relationships & Specializations:**
    *   If `Y ~ LogNormal(mu, sigma_sq)`, then `log(Y) ~ Normal(mu, sigma_sq)`.
*   **Orbit Rules/Properties (Conceptual):**
    ```orbit
	mean(D : LogNormal(mu_val, sig_sq_val)) → exp(mu_val + sig_sq_val / 2.0);
	// Transformation rule for log will be in probability3.md
```

### 2.2.4. Exponential Distribution

*   **Description:** Time between events in a Poisson point process.
*   **Orbit Domain:** `Exponential(lambda: Real)` (rate `lambda > 0`).
*   **PDF:** `f(x) = lambda * exp(-lambda * x)` for `x ≥ 0`.
*   **Mean:** `1/lambda`.
*   **Variance:** `1/lambda^2`.
*   **Relationships & Specializations:**
    *   Is a special case of `Gamma(1, lambda)`.
        ```orbit
		D : Exponential(lambda_val) ↔ Gamma(1.0, lambda_val);
```
    *   Difference of two i.i.d. Exponential variables can form a Laplace distribution.
*   **Orbit Rules/Properties (Conceptual):**
    ```orbit
	mean(D : Exponential(lambda_val)) → 1.0 / lambda_val;
	variance(D : Exponential(lambda_val)) → 1.0 / (lambda_val * lambda_val);
```

### 2.2.5. Gamma Distribution

*   **Description:** Flexible distribution for waiting times.
*   **Orbit Domain:** `Gamma(alpha_shape: Real, beta_rate: Real)` (`alpha_shape > 0`, `beta_rate > 0`).
*   **PDF:** `f(x) = (beta_rate^alpha_shape / Gamma_fn(alpha_shape)) * x^(alpha_shape-1) * exp(-beta_rate*x)` for `x > 0`.
*   **Mean:** `alpha_shape / beta_rate`.
*   **Variance:** `alpha_shape / beta_rate^2`.
*   **Relationships & Specializations:**
    *   If `alpha_shape=1`, it is `Exponential(beta_rate)`. (Covered by rule above).
    *   If `alpha_shape=k/2.0` and `beta_rate=0.5`, it is `ChiSquared(k)`.
        ```orbit
		D : Gamma(k_val / 2.0, 0.5) ↔ ChiSquared(k_val) where k_val : Integer;
```
    *   Sum of `k` i.i.d. `Exponential(beta_rate)` is `Gamma(k, beta_rate)` (see [Probability Part 3](./probability3.md)).
*   **Orbit Rules/Properties (Conceptual):**
    ```orbit
	mean(D : Gamma(a_val, b_val)) → a_val / b_val;
	variance(D : Gamma(a_val, b_val)) → a_val / (b_val * b_val);
```

### 2.2.6. Chi-Squared Distribution

*   **Description:** Sum of squares of `k` independent standard normal RVs.
*   **Orbit Domain:** `ChiSquared(k: Integer)` (degrees of freedom `k > 0`).
*   **Mean:** `k`.
*   **Variance:** `2k`.
*   **Relationships & Specializations:**
    *   Is a special case of `Gamma(k/2.0, 0.5)`.
*   **Orbit Rules/Properties (Conceptual):**
    ```orbit
	mean(D : ChiSquared(k_val)) → k_val;
	variance(D : ChiSquared(k_val)) → 2.0 * k_val;
```

### 2.2.7. Beta Distribution

*   **Description:** Defined on `[0,1]`, models probabilities or proportions.
*   **Orbit Domain:** `Beta(alpha_shape: Real, beta_shape: Real)` (`alpha_shape > 0`, `beta_shape > 0`).
*   **PDF:** `f(x) = (x^(alpha_shape-1) * (1-x)^(beta_shape-1)) / Beta_fn(alpha_shape, beta_shape)`.
*   **Mean:** `alpha_shape / (alpha_shape + beta_shape)`.
*   **Relationships & Specializations:**
    *   If `alpha_shape=1, beta_shape=1`, it is `UniformContinuous(0.0, 1.0)`.
    *   Corresponds to `Dirichlet([alpha_shape, beta_shape])` (see Multivariate section or [Probability Part 4](./probability4.md)).
*   **Orbit Rules/Properties (Conceptual):**
    ```orbit
	mean(D : Beta(a_val, b_val)) → a_val / (a_val + b_val);
```

### 2.2.8. Student's T-Distribution

*   **Description:** Arises when estimating the mean of a normally distributed population with small sample size.
*   **Orbit Domain:** `StudentT(nu: Real)` (degrees of freedom `nu > 0`).
*   **PDF:** Complex form involving Gamma function.
*   **Mean:** `0` for `nu > 1`.
*   **Variance:** `nu / (nu - 2)` for `nu > 2`.
*   **Relationships & Specializations:**
    *   Derived from `Z / sqrt(V/nu)` where `Z ~ Normal(0,1)` and `V ~ ChiSquared(nu)` are independent.
    *   As `nu → ∞`, `StudentT(nu) → Normal(0,1)`.

### 2.2.9. Cauchy Distribution

*   **Description:** A distribution with heavy tails; mean and variance are undefined.
*   **Orbit Domain:** `Cauchy(x0: Real, gamma: Real)` (`x0` is location (median), `gamma > 0` is scale).
*   **PDF:** `f(x) = 1 / (pi * gamma * (1 + ((x-x0)/gamma)^2))`.
*   **Mean & Variance:** Undefined.
*   **Relationships & Specializations:**
    *   Ratio of two i.i.d. `Normal(0,1)` variables is `Cauchy(0,1)`.
    *   Special case of `StudentT(1)` is `Cauchy(0,1)`.
        ```orbit
		D : StudentT(1.0) ↔ Cauchy(0.0, 1.0);
```

### 2.2.10. Laplace Distribution (Double Exponential)

*   **Description:** Represents the difference of two i.i.d. exponential random variables.
*   **Orbit Domain:** `Laplace(mu: Real, b_scale: Real)` (`mu` is location, `b_scale > 0` is scale).
*   **PDF:** `f(x) = (1/(2*b_scale)) * exp(-abs(x-mu)/b_scale)`.
*   **Mean:** `mu`.
*   **Variance:** `2 * b_scale^2`.

## 2.3. Multivariate Distributions

*(To be detailed further in [Probability Part 4: Multivariate Distributions and Conditional Probability](./probability4.md), but introduced here for completeness of the catalogue).*

### 2.3.1. Multinomial Distribution

*   **Description:** Generalizes Binomial to `n` trials, each with `K` outcomes.
*   **Orbit Domain:** `Multinomial(n: Integer, probs: Vector<Real>)` (Outcome is `Vector<Integer>` of counts).
*   **Relationships & Specializations:**
    *   If `n=1`, it is `Categorical(probs)`.
    *   If `K=2` (e.g. `probs = [p, 1-p]`), the marginal count for one outcome is `Binomial(n,p)`.

### 2.3.2. Dirichlet Distribution

*   **Description:** Distribution over parameters of Multinomial/Categorical (i.e., over probability vectors that sum to 1).
*   **Orbit Domain:** `Dirichlet(alphas: Vector<Real>)` (`alphas` is vector of concentration parameters `α_i > 0`).
*   **Relationships & Specializations:**
    *   If `K=2` (i.e., `alphas = [α1, α2]`), it is equivalent to `Beta(α1, α2)` for the first component.
        ```orbit
		// For K=2, D : Dirichlet([alpha1_val, alpha2_val]), the distribution of the first component (p1)
		// corresponds to Beta(alpha1_val, alpha2_val).
		// This is more a property for marginals (Chapter 4) than direct equivalence of the vector dist.
		// However, can define a specific equivalence for Orbit:
		D : Dirichlet(alpha_vec) where length(alpha_vec)=2 ↔ Beta(alpha_vec[0], alpha_vec[1]); // if interpreting Beta as dist of p1
```
    *   Conjugate prior for Multinomial and Categorical distributions.

### 2.3.3. Multivariate Normal Distribution

*   **Description:** Generalization of Normal distribution to multiple dimensions.
*   **Orbit Domain:** `MultivariateNormal(mean_vec: Vector<Real>, cov_matrix: Matrix<Real>)` (`cov_matrix` must be symmetric positive definite).
*   **Relationships & Specializations:**
    *   Marginal distributions are Normal.
    *   Conditional distributions are Normal.
    *   If `cov_matrix` is diagonal, components are independent Normal RVs.

### 2.3.4. Wishart Distribution

*   **Description:** Distribution of sum of outer products of `ν` independent multivariate normal vectors. Used for covariance matrix estimation.
*   **Orbit Domain:** `Wishart(scale_matrix: Matrix<Real>, nu_df: Real)` (`scale_matrix` is symmetric positive definite, `nu_df ≥ dimension_of_matrix`).

### 2.3.5. Inverse Wishart Distribution

*   **Description:** Conjugate prior for the covariance matrix of a Multivariate Normal distribution.
*   **Orbit Domain:** `InverseWishart(scale_matrix: Matrix<Real>, nu_df: Real)`.

---

This catalogue provides Orbit with a foundational set of distributions and their interrelations. The next chapter, **[Probability Part 3: Transformations and Combinations of Random Variables](./probability3.md)**, will explore how Orbit can derive the distributions of new random variables that result from operations on these known distributions.
