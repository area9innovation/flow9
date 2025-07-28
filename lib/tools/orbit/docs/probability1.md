# Probability Part 1: Foundations of Probability in Orbit

*This document lays the groundwork for integrating probabilistic reasoning into the Orbit system, drawing inspiration from how Orbit handles core matrix algebra as detailed in [`matrix1.md`](./matrix1.md).*

## 1.1. Introduction

Probability theory provides a formal framework for reasoning about uncertainty and randomness. In the context of program analysis and optimization, understanding the probabilistic behavior of programs can lead to more informed and effective transformations. Many aspects of program execution, such as input data, branch outcomes, or loop iteration counts, can be modeled as random variables. By equipping Orbit with the ability to represent and reason about probability distributions, we can unlock a new class of optimizations.

### 1.1.1. Motivation: The Role of Probabilistic Reasoning in Program Optimization

Traditional compilers often operate under deterministic assumptions or rely on simple heuristics. However, real-world programs interact with uncertain environments and process varied data. Probabilistic reasoning allows us to:

*   **Model Uncertainty:** Explicitly represent the likelihood of different program states or variable values.
*   **Improve Predictions:** Enhance branch prediction, estimate value ranges more accurately, and predict resource usage.
*   **Guide Heuristics:** Make optimization choices (e.g., inlining, loop unrolling, data layout) based on the most probable execution scenarios rather than worst-case or average-case assumptions that may not hold.
*   **Optimize for Expected Performance:** Focus optimization efforts on paths and data patterns that occur most frequently.

### 1.1.2. Goals: Annotating Orbit Programs with Distributions, Inferring Distributional Properties

The primary goals for integrating probability into Orbit are:

1.  **Annotation:** To allow Orbit programs and expressions to be annotated with their underlying probability distributions (e.g., `x : Normal(0,1)`).
2.  **Representation:** To define a robust system within Orbit for representing various probability distributions and their parameters.
3.  **Inference:** To enable Orbit to automatically infer the probability distribution of an expression resulting from operations on other distributed variables (e.g., if `X ~ Normal(0,1)` and `Y ~ Normal(0,1)`, what is the distribution of `X+Y`?).
4.  **Transformation:** To use rewrite rules to simplify probabilistic expressions and propagate distributional information through the program.
5.  **Optimization:** To leverage this probabilistic information to make smarter optimization decisions.

### 1.1.3. Overview of the Orbit Approach: Symbolic Representation, Rewrite Rules, and Inference

Orbit's approach to probability will mirror its handling of other algebraic structures, such as matrices:

*   **Symbolic Representation in O-Graphs:** Probabilistic expressions and distributions will be represented symbolically within Orbit's e-graph (O-Graph) structure.
*   **Domain-Driven Algebraic Rewriting:** Expressions will be annotated with their distributional domains (e.g., `Normal(μ, σ²)`). Orbit will apply rewrite rules based on fundamental laws of probability and statistics.
*   **Canonicalization:** For distributions or operations with known symmetries, Orbit can leverage canonicalization to simplify representations.
*   **Emergent Optimized Pathways:** Optimized program transformations will emerge from rule application and probabilistic inference.

This document, **Probability Part 1**, focuses on establishing the foundational symbolic representations and basic operations for probability distributions within Orbit.

## 1.2. Representing Probability Distributions in Orbit

Similar to how [`matrix1.md`](./matrix1.md) defines domains for matrix operations, we start by defining the core concepts and Orbit domains for probability distributions.

### 1.2.1. Core Concepts: Random Variables (Discrete, Continuous), Sample Spaces, Events

*   **Random Variable (RV):** A variable whose value is a numerical outcome of a random phenomenon. Orbit will associate expressions or program variables with RVs.
*   **Sample Space (Ω):** The set of all possible outcomes of a random phenomenon.
*   **Event:** A subset of the sample space.
*   **Discrete Random Variable:** An RV that can take on a finite or countably infinite number of distinct values.
*   **Continuous Random Variable:** An RV that can take on any value within a continuous range.

### 1.2.2. Orbit Domain System for Probability

Orbit's domain system is central to representing distributions:

*   **Core Distribution Domain:**
```orbit
	// General domain for any probability distribution
	Distribution<Type, DomainSpace> // Type is the type of values the RV takes (e.g., Real, Integer)
										 // DomainSpace indicates if discrete or continuous (e.g., DiscreteSpace, ContinuousSpace)
```
*   **Fundamental Descriptors:** These are functions or properties associated with a distribution. They are not domains themselves but are key to defining and working with distributions.
    *   **Probability Mass Function (PMF):** For discrete RVs, `P(X=x)`. Conceptually:
```orbit
		// Represents the PMF of a discrete distribution 'Dist'
		// pmf_of(Dist : Distribution<T, DiscreteSpace>) → Function<T, Probability>
```
    *   **Probability Density Function (PDF):** For continuous RVs, `f(x)` such that `P(a ≤ X ≤ b) = ∫[a,b] f(x)dx`. Conceptually:
```orbit
		// Represents the PDF of a continuous distribution 'Dist'
		// pdf_of(Dist : Distribution<T, ContinuousSpace>) → Function<T, Density>
```
    *   **Cumulative Distribution Function (CDF):** For both discrete and continuous RVs, `F(x) = P(X ≤ x)`. Conceptually:
```orbit
		// Represents the CDF of a distribution 'Dist'
		// cdf_of(Dist : Distribution<T, _>) → Function<T, Probability>
```

    Where `Probability` is a type representing values in `[0,1]` and `Density` represents non-negative real values.

### 1.2.3. Representing Parameters and Properties

Specific distributions (e.g., Normal, Poisson) are characterized by parameters. These, along with derived properties, can be represented as functions or attributes accessible via Orbit rules.

```orbit
// Generic property extraction (conceptual)
// mean_val = mean(MyDistribution : Normal(μ, σ²)) // yields μ
// variance_val = variance(MyDistribution : Normal(μ, σ²)) // yields σ²

// Example domains for specific distributions (to be detailed in probability2.md)
Normal(μ: Real, σ_sq: Real) ⊂ Distribution<Real, ContinuousSpace>
Poisson(λ: Real) ⊂ Distribution<Integer, DiscreteSpace>
Bernoulli(p: Real) ⊂ Distribution<Integer, DiscreteSpace> // Output 0 or 1
```

Other properties include:
*   **Standard Deviation:** `stddev(Dist) → sqrt(variance(Dist))`
*   **Mode:** The value(s) at which PMF/PDF is maximized.
*   **Median:** The value `m` such that `cdf(Dist, m) = 0.5`.
*   **Moments:** Higher-order expectations (e.g., `E[X^k]`).
*   **Skewness & Kurtosis:** Measures of shape.
*   **Support:** The set of values for which the PMF/PDF is non-zero.

## 1.3. Basic Operations on Distributions in Orbit

Orbit will provide rewrite rules and potentially intrinsic functions to perform common operations involving distributions.

### 1.3.1. Evaluation

These operations allow querying the probability or density at specific points:

```orbit
// Evaluate PMF for a discrete distribution
// pmf(D : Distribution<T, DiscreteSpace>, value : T) → prob_val : Probability

// Evaluate PDF for a continuous distribution
// pdf(D : Distribution<T, ContinuousSpace>, value : T) → density_val : Density

// Evaluate CDF for any distribution
// cdf(D : Distribution<T, _>, value : T) → prob_val : Probability
```
For example, for a `Normal(0,1)` distribution `N01`:
`pdf(N01, 0.0) → 1/sqrt(2*pi)`
`cdf(N01, 0.0) → 0.5`

### 1.3.2. Inverse CDF (Quantile Function)

This function returns the value below which a given proportion of observations lie:

```orbit
// quantile(D : Distribution<T, _>, prob : Probability) → val : T
```
For `N01` (Normal(0,1)):
`quantile(N01, 0.5) → 0.0`
`quantile(N01, 0.975) → 1.96` (approx.)

### 1.3.3. Expectation

Returns the mean or expected value of a distribution:

```orbit
// E(D : Distribution<T, _>) → mean_val : Type_or_Scalar
// mean(D : Distribution<T, _>) → mean_val : Type_or_Scalar
```
For example:
`E(Normal(μ, σ²)) → μ`
`E(Poisson(λ)) → λ`

### 1.3.4. Variance

Returns the variance of a distribution:

```orbit
// Var(D : Distribution<T, _>) → variance_val : Scalar
// variance(D : Distribution<T, _>) → variance_val : Scalar
```
For example:
`Var(Normal(μ, σ²)) → σ²`
`Var(Poisson(λ)) → λ`

### 1.3.5. Generating Samples (Conceptual)

While Orbit's primary goal isn't direct simulation, the concept of sampling is fundamental to defining distributions and their properties. This might be represented as a conceptual operation:

```orbit
// sample(D : Distribution<T, _>) → val : T
```
This can be used in deriving properties or in more advanced analyses where expected behavior under sampling is considered (e.g., Monte Carlo method concepts if Orbit were extended to certain numerical optimizations).

## 1.4. Algebraic Properties and Symmetries in Orbit Rules

Many probabilistic concepts have algebraic properties that can be encoded as rewrite rules in Orbit, similar to how matrix algebra rules are defined.

### 1.4.1. Linearity of Expectation

One of the most fundamental properties. If `X` and `Y` are random variables (represented by their distributions `Dx` and `Dy` in Orbit) and `a`, `b` are constants:

```orbit
// Assuming X and Y are expressions whose distributions are known
// E(a*X + b*Y) ↔ a*E(X) + b*E(Y)

// In Orbit syntax, if X_dist = distribution_of(X) and Y_dist = distribution_of(Y):
E(distribution_of(a*X + b*Y)) ↔ a*E(X_dist) + b*E(Y_dist)
	// This rule might require that X and Y are numeric and a,b are scalars.
	// More precisely, if we define an operation AddDistributions and ScaleDistribution:
	// E(AddDistributions(ScaleDistribution(Dx, a), ScaleDistribution(Dy, b))) ↔ a*E(Dx) + b*E(Dy)
```
This rule holds regardless of whether `X` and `Y` are independent.

### 1.4.2. Variance Properties

*   `Var(a*X + b) = a² * Var(X)`
```orbit
	// Var(distribution_of(a*X + b)) ↔ a^2 * Var(distribution_of(X))
```
*   If `X` and `Y` are independent: `Var(X + Y) = Var(X) + Var(Y)`
```orbit
	// Assuming X_dist = distribution_of(X), Y_dist = distribution_of(Y)
	// and independence is known (e.g., X_dist : IndependentOf(Y_dist))
	Var(AddDistributions(X_dist, Y_dist)) ↔ Var(X_dist) + Var(Y_dist)
		if X_dist : IndependentOf(Y_dist);
```

### 1.4.3. Symmetries for Canonicalization

Certain operations involving multiple random variables might exhibit symmetries that Orbit can exploit for canonicalization. For example:

*   **Sum of Independent and Identically Distributed (i.i.d.) Variables:** The order of summation doesn't matter. If `X₁, X₂, ..., Xₙ` are i.i.d., then `X₁ + X₂` has the same distribution as `X₂ + X₁`. If such sums are represented n-arily in Orbit (e.g., `sum_dist(D1, D2, D3)`), the argument list could be sorted for canonicalization, similar to commutative arithmetic operations, provided they are i.i.d.
```orbit
	// Conceptual rule for sum of i.i.d. RVs, assuming an internal SumOfDistributions operator
	SumOfDistributions(args...) : AllArgsIID !: S_n_Canonical → SumOfDistributions(sort_args_canonical(args...)) : S_n_Canonical;
```
*   **Joint Distributions:** If variables in a joint distribution are exchangeable, their order in the representation might be canonicalized.
