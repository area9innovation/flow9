# Probability Part 4: Multivariate Distributions and Conditional Probability in Orbit

*Building on the catalogue of distributions in [Probability Part 2: A Catalogue of Common Probability Distributions](./probability2.md) and the transformations in [Probability Part 3: Transformations and Combinations of Random Variables](./probability3.md), this chapter delves into the realm of multiple random variables. We explore how Orbit can represent and reason about joint distributions, marginal distributions, conditional probability, independence, and key multivariate distributions. This is akin to how [`matrix4.md`](./matrix4.md) handles advanced matrix topics like eigen-problems, which involve the interplay of multiple components.*

## Introduction

Many real-world systems and program behaviors involve the interaction of multiple random variables. Their values are often not independent; the state of one variable can influence the likelihood of states for others. Understanding their joint behavior, dependencies, and conditional relationships is crucial for accurate modeling and effective probabilistic inference within Orbit. This chapter lays out how Orbit can manage these complexities, enabling more sophisticated program analysis and optimization.

## 4.1. Joint Distributions

A joint probability distribution describes the probabilistic behavior of a set of two or more random variables considered simultaneously.

### 4.1.1. Representation and Orbit Domain

For a set of random variables `X₁, ..., Xₙ`, their joint distribution, denoted `P(X₁, ..., Xₙ)`, characterizes the probability of them simultaneously taking on specific values or falling into specific ranges.

*   **Discrete Case:** The joint Probability Mass Function (PMF) is `pmf(x₁, ..., xₙ) = P(X₁=x₁, ..., Xₙ=xₙ)`.
*   **Continuous Case:** The joint Probability Density Function (PDF) is `pdf(x₁, ..., xₙ)`, where `P((X₁,...,Xₙ) ∈ A) = ∫...∫_A pdf(x₁,...,xₙ) dx₁...dxₙ`.

Orbit can represent this with a general domain for abstract joint distributions and specific domains for well-known multivariate forms:

```orbit
// General conceptual domain for a joint distribution.
// ElementTypes would be a list or tuple of the types of the individual RVs (e.g., [Real, Integer]).
// DomainSpace would indicate if all are discrete, all continuous, or mixed.
JointDistribution(variables: Vector<VariableSymbol>, definition: PDF_or_PMF_Symbolic_Expression_or_Table)
// Alternatively, specific known joint distributions are primary:

// Specific domains (introduced in probability2.md):
MultivariateNormal(mean_vec: Vector<Real>, cov_matrix: Matrix<Real>)
Dirichlet(alphas: Vector<Real>)
Multinomial(n: Integer, probs: Vector<Real>)
Wishart(scale_matrix: Matrix<Real>, nu_df: Real)
InverseWishart(scale_matrix: Matrix<Real>, nu_df: Real)
```

In `MultivariateNormal`, the `cov_matrix` not only stores pairwise covariances but defines the entire dependency structure. For custom or empirically derived joint distributions, Orbit might store them as:
*   Explicit tables (for discrete cases with a small number of variables/states).
*   Symbolic expressions representing the PMF/PDF if a functional form is known.
*   A constructive definition (e.g., as a result of transformations on other known distributions).

### 4.1.2. Properties of Joint Distributions

Key properties of joint distributions that Orbit should be able to query or operate on include:
*   **Evaluation of Joint PMF/PDF/CDF:** Functions like `EvaluateJointPDF(JointDist, values_vector)`.
*   **Expectation of functions of multiple RVs:** `E[g(X₁, ..., Xₙ)]`. This is generally `∫...∫ g(x₁,...,xₙ) * pdf(x₁,...,xₙ) dx₁...dxₙ`. Orbit might handle this for specific `g` or specific joint distributions through rules.

## 4.2. Marginal Distributions

A marginal distribution is the probability distribution of a subset of random variables from a larger set described by a joint distribution. It is obtained by "integrating out" or "summing out" the variables not in the subset.

### 4.2.1. Deriving Marginal Distributions in Orbit

Orbit can use rewrite rules to derive marginal distributions from known joint distributions. For two variables `X` and `Y` with joint PDF `pdf_XY(x,y)`, the marginal PDF of `X` is `pdf_X(x) = ∫ pdf_XY(x,y) dy` (integrated over all possible values of `y`).

**Orbit Rules:**

```orbit
// Conceptual operator for marginalization
// MarginalDistribution(JointDist, indices_to_keep: Vector<Integer>) → Distribution

// Specific rule for Multivariate Normal:
// If J_Dist = MultivariateNormal([μ₁, μ₂, ...], [[Σ₁₁, Σ₁₂, ...], [Σ₂₁, Σ₂₂, ...], ...]),
// then selecting variable Xᵢ (at index i) results in Normal(μᵢ, Σᵢᵢ).

Rule "Marginal of MVN (single variable)":
	MarginalDistribution(MVN_Dist : MultivariateNormal, [idx_i]) ↔ Normal(MVN_Dist.mean_vec[idx_i], MVN_Dist.cov_matrix[idx_i, idx_i]);

Rule "Marginal of MVN (sub-vector)":
	MarginalDistribution(MVN_Dist : MultivariateNormal, indices_vec : Vector<Integer>) ↔
		MultivariateNormal(
			select_elements(MVN_Dist.mean_vec, indices_vec),
			select_submatrix(MVN_Dist.cov_matrix, indices_vec, indices_vec)
		)
	if length(indices_vec) > 1;

// Specific rule for Dirichlet:
// If (P₁,...,Pₖ) ~ Dirichlet([α₁,...,αₖ]), then Pᵢ ~ Beta(αᵢ, sum(αⱼ for j≠i)).
Rule "Marginal of Dirichlet":
	MarginalDistribution(D_Dist : Dirichlet, [idx_i]) ↔
		Beta(D_Dist.alphas[idx_i], sum(D_Dist.alphas) - D_Dist.alphas[idx_i]);

// Specific rule for Multinomial (marginal distribution of one count kᵢ):
// If (K₁,...,Kₘ) ~ Multinomial(n, [p₁,...,pₘ]), then Kᵢ ~ Binomial(n, pᵢ).
Rule "Marginal of Multinomial":
	MarginalDistribution(M_Dist : Multinomial, [idx_i]) ↔
		Binomial(M_Dist.n, M_Dist.probs[idx_i]);
```
These rules enable Orbit to simplify analyses by focusing on individual variables or smaller subsets when the full joint complexity is not required or when specific marginal properties are of interest.

## 4.3. Conditional Distributions

A conditional probability distribution `P(X|Y=y)` (or `pdf(x|y)`) describes the probability distribution of a random variable (or vector) `X`, given that another random variable (or vector) `Y` is observed to have a specific value `y`.

### 4.3.1. Definition and Representation

For continuous variables, `pdf(x|y) = pdf_XY(x,y) / pdf_Y(y)`, provided `pdf_Y(y) > 0`.
For discrete variables, `P(X=x|Y=y) = P(X=x, Y=y) / P(Y=y)`, provided `P(Y=y) > 0`.

Orbit can represent conditional distributions symbolically, for example:
```orbit
// Conceptual domain for a conditional distribution object
// ConditionalDistribution(JointDist, conditioned_vars_indices: Vector<Integer>, given_vars_indices: Vector<Integer>, given_values: Vector)
// Or more directly by defining what distribution results from conditioning:

// Example: X_given_Y_is_y_dist = DistributionOf(X_expr | Y_expr = y_val)
```

### 4.3.2. Bayes' Theorem as a Rewrite Rule

Bayes' Theorem, `P(A|B) = P(B|A) * P(A) / P(B)`, is fundamental for inverting conditional probabilities and performing inference.

**Orbit Rule (conceptual, for transforming distribution objects):**
```orbit
// Let D_A_given_B be the distribution object for P(A|B)
// Let D_B_given_A be the distribution object for P(B|A)
// Let D_A be the distribution object for P(A)
// Let D_B be the distribution object for P(B)

Rule "Bayes' Theorem for Distributions":
	D_A_given_B ↔ TransformDistribution([D_B_given_A, D_A, D_B],
																			fn(d_bga, d_a, d_b, a_val, b_val) =
																				(EvaluatePDF(d_bga, b_val | a_val) * EvaluatePDF(d_a, a_val)) / EvaluatePDF(d_b, b_val)
																		 )
	// This is highly conceptual. A more direct rule for queries might be:
	// QueryPDF(P(A|B), a_val, b_val) ↔ (QueryPDF(P(B|A), b_val, a_val) * QueryPDF(P(A), a_val)) / QueryPDF(P(B), b_val);
```
This allows Orbit to transform probabilistic queries or distribution representations into forms that might be easier to evaluate or simplify based on available information or previously derived distributions.

### 4.3.3. Conditional Distributions for Specific Multivariate Forms

*   **Multivariate Normal:** If `(X₁, X₂)ᵀ` is Multivariate Normal, where `X₁` and `X₂` are sub-vectors, then the conditional distribution `X₁ | X₂=x₂` is also Multivariate Normal. Orbit rules can derive its parameters.
    Let `MVN_Dist = MultivariateNormal([μ₁,μ₂]ᵀ, [[Σ₁₁, Σ₁₂],[Σ₂₁, Σ₂₂]])`.
    Then `X₁ | X₂=x₂ ~ Normal(μ_cond, Σ_cond)` where:
    `μ_cond = μ₁ + Σ₁₂ * Σ₂₂⁻¹ * (x₂ - μ₂)`
    `Σ_cond = Σ₁₁ - Σ₁₂ * Σ₂₂⁻¹ * Σ₂₁`

    **Orbit Rule:**
    ```orbit
	Rule "Conditional of MVN":
	  ConditionalDistribution(MVN_Dist : MultivariateNormal, indices1_to_find: Vector<Integer>, indices2_given: Vector<Integer>, values_x2: Vector<Real>) ↔
		let μ1 = select_elements(MVN_Dist.mean_vec, indices1_to_find);
		let μ2 = select_elements(MVN_Dist.mean_vec, indices2_given);
		let Σ11 = select_submatrix(MVN_Dist.cov_matrix, indices1_to_find, indices1_to_find);
		let Σ12 = select_submatrix(MVN_Dist.cov_matrix, indices1_to_find, indices2_given);
		let Σ21 = select_submatrix(MVN_Dist.cov_matrix, indices2_given, indices1_to_find); // Σ21 = Σ12ᵀ
		let Σ22_inv = inverse(select_submatrix(MVN_Dist.cov_matrix, indices2_given, indices2_given));
		let μ_cond = μ1 + Σ12 * Σ22_inv * (values_x2 - μ2);
		let Σ_cond = Σ11 - Σ12 * Σ22_inv * Σ21;
		MultivariateNormal(μ_cond, Σ_cond)
	  // Requires matrix algebra support from Orbit (inverse, multiplication, addition).
```

*   **Dirichlet and Multinomial (Conjugate Priors):** If `P ~ Dirichlet(alphas_prior)` (prior distribution for Multinomial parameters) and `Data_counts ~ Multinomial(n, P)` (likelihood of observing data), then the posterior distribution `P | Data_counts ~ Dirichlet(vector_add(alphas_prior, Data_counts))`. This is a cornerstone of Bayesian updates.

    **Orbit Rule (for Bayesian inference context):**
    ```orbit
	Rule "Dirichlet-Multinomial Posterior":
	  PosteriorDistribution(Prior_P : Dirichlet, Likelihood_Data : Multinomial, Observed_Counts : Vector<Integer>) ↔
		Dirichlet(vector_add(Prior_P.alphas, Observed_Counts))
	  // Assumes Likelihood_Data.n == sum(Observed_Counts) and length(Observed_Counts) == length(Prior_P.alphas)
```

## 4.4. Independence and Conditional Independence

### 4.4.1. Definitions

*   **Independence:** Two random variables (or vectors) `X` and `Y` are independent if their joint distribution is the product of their marginal distributions: `P(X,Y) = P(X)P(Y)`. This implies `P(X|Y) = P(X)` and `P(Y|X) = P(Y)`.
*   **Conditional Independence:** `X` and `Y` are conditionally independent given `Z` if `P(X,Y|Z) = P(X|Z)P(Y|Z)`. This implies `P(X|Y,Z) = P(X|Z)`.

### 4.4.2. Orbit Representation and Rewrite Rules

Independence can be an explicit property or domain annotation in Orbit, associated with variables or their distributions.

```orbit
// X_expr and Y_expr are expressions in the program.
// DistributionOf(X_expr) : IndependentOf(DistributionOf(Y_expr))
// (DistributionOf(X_expr), DistributionOf(Y_expr)) : ConditionallyIndependentGiven(DistributionOf(Z_expr))

Rule "Joint PMF/PDF of Independent Variables":
	EvaluateJointPDF(JointDist_XY_Placeholder, [x_val, y_val]) ↔
		EvaluatePDF(DistributionOf(X_expr), x_val) * EvaluatePDF(DistributionOf(Y_expr), y_val)
	if X_expr : CorrespondsTo(0, JointDist_XY_Placeholder) &&
		 Y_expr : CorrespondsTo(1, JointDist_XY_Placeholder) &&
		 DistributionOf(X_expr) : IndependentOf(DistributionOf(Y_expr));
	// (A similar rule for PMFs)

Rule "Conditional Probability Simplification with Independence":
	ConditionalDistribution(DistributionOf(X_expr) | Y_expr = y_val) ↔ DistributionOf(X_expr)
	if DistributionOf(X_expr) : IndependentOf(DistributionOf(Y_expr));
	// This means the distribution object itself is returned, not just its PDF value.

Rule "Conditional Probability Simplification with Conditional Independence":
	ConditionalDistribution(DistributionOf(X_expr) | Y_expr = y_val, Z_expr = z_val) ↔
		ConditionalDistribution(DistributionOf(X_expr) | Z_expr = z_val)
	if (DistributionOf(X_expr), DistributionOf(Y_expr)) : ConditionallyIndependentGiven(DistributionOf(Z_expr));
```

### 4.4.3. Inferring Independence from Program Structure

Orbit can potentially infer independence if variables are computed from disjoint sets of inputs or through separate, non-interacting code paths. For example, if `x = f(a,b)` and `y = g(c,d)` where `{a,b}` and `{c,d}` are disjoint sets of independent inputs, then `x` and `y` might be inferred as independent. This relies on data-flow and dependency analysis.

## 4.5. Covariance and Correlation

These measures quantify the linear relationship between two random variables.

*   **Covariance:** `Cov(X,Y) = E[(X - E[X])(Y - E[Y])] = E[XY] - E[X]E[Y]`.
*   **Correlation Coefficient:** `Corr(X,Y) = Cov(X,Y) / (StdDev(X) * StdDev(Y))`. `Corr(X,Y)` ranges from -1 to 1.

**Orbit Rules for Properties and Calculation:**
```orbit
// Let D_X = DistributionOf(X_expr), D_Y = DistributionOf(Y_expr)
// Let J_XY be the joint distribution of (X_expr, Y_expr)

Covariance(J_XY) → E(ProductOfComponents(J_XY)) - E(MarginalDistribution(J_XY, [0])) * E(MarginalDistribution(J_XY, [1]));
// ProductOfComponents(J_XY) represents the distribution of X*Y.

Correlation(J_XY) ↔ Covariance(J_XY) / (StdDev(MarginalDistribution(J_XY, [0])) * StdDev(MarginalDistribution(J_XY, [1])));

Rule "Covariance Self":
	Covariance(J_XX) ↔ Var(MarginalDistribution(J_XX, [0]))
	if J_XX is joint of (X,X);
	// More directly: Cov(D_X, D_X) ↔ Var(D_X)

Rule "Covariance Symmetry":
	Covariance(J_XY) ↔ Covariance(SwapComponents(J_XY)); // If J_YX is J_XY with components swapped.

Rule "Covariance Scaling":
	// If J_aXb_cYd is joint dist of (aX+b, cY+d)
	Covariance(J_aXb_cYd) ↔ a * c * Covariance(Original_J_XY)
		if a,b,c,d are constants;

Rule "Covariance of Independent Variables":
	Covariance(J_XY) → 0.0
		if MarginalDistribution(J_XY, [0]) : IndependentOf(MarginalDistribution(J_XY, [1]));

Rule "Correlation of Independent Variables":
	Correlation(J_XY) → 0.0
		if MarginalDistribution(J_XY, [0]) : IndependentOf(MarginalDistribution(J_XY, [1]));
```
Note: `Cov(X,Y)=0` (and thus `Corr(X,Y)=0`) does not necessarily imply independence, unless `X` and `Y` are jointly Normally distributed.

For a `MultivariateNormal(mean_vec, cov_matrix)`, `cov_matrix[i,j]` directly gives `Cov(Xᵢ, Xⱼ)`.

## 4.6. In-depth on Key Multivariate Distributions

This section revisits the properties and Orbit interactions for key multivariate distributions catalogued in [Probability Part 2](./probability2.md).

### 4.6.1. Multivariate Normal Distribution
*   **Orbit Domain:** `MultivariateNormal(mean_vec: Vector<Real>, cov_matrix: Matrix<Real>)`
*   **Properties:** `cov_matrix` must be symmetric and positive semi-definite.
*   **Marginals & Conditionals:** As detailed in sections 4.2.1 and 4.3.3, marginals and conditionals are also (Multivariate) Normal, with parameters derivable via matrix operations.
*   **Linear Combinations:** If `X ~ MultivariateNormal(μ, Σ)` and `Y = AX + b` (where `A` is a matrix and `b` a vector of constants), then `Y ~ MultivariateNormal(Aμ + b, AΣAᵀ)`.
    **Orbit Rule:**
    ```orbit
	Rule "Linear Transformation of MVN":
	  DistributionOf(A_matrix * X_vec_expr + b_vec) ↔
		MultivariateNormal(
		  A_matrix * MVN_Dist.mean_vec + b_vec,
		  A_matrix * MVN_Dist.cov_matrix * transpose(A_matrix)
		)
	  if DistributionOf(X_vec_expr) is MVN_Dist : MultivariateNormal &&
		 A_matrix : ConstantMatrix && b_vec : ConstantVector;
```
*   **Independence:** For jointly Normal variables, zero covariance implies independence. 
    **Orbit Rule:**
    ```orbit
	Rule "Independence from Covariance in MVN":
	  MarginalDistribution(MVN_Dist : MultivariateNormal, [idx_i]) :
		IndependentOf(MarginalDistribution(MVN_Dist, [idx_j]))
	  if MVN_Dist.cov_matrix[idx_i, idx_j] == 0.0 && idx_i != idx_j;
```

### 4.6.2. Dirichlet Distribution
*   **Orbit Domain:** `Dirichlet(alphas: Vector<Real>)` (vector of positive concentration parameters).
*   **Properties:** Distribution over the `K-1` simplex (vectors `p = [p₁, ..., pₖ]` where `pᵢ ≥ 0`, `sum(pᵢ) = 1`). Conjugate prior for Categorical/Multinomial parameters.
*   **Marginals:** Marginal of `pᵢ` is `Beta(alphas[i], sum(alphas) - alphas[i])` (Rule in 4.2.1).
*   **Aggregation:** If `(p₁, ..., pₖ) ~ Dirichlet(α₁, ..., αₖ)`, then `(p₁ + ... + pⱼ, pⱼ₊₁ + ... + pₖ) ~ Dirichlet(α₁ + ... + αⱼ, αⱼ₊₁ + ... + αₖ)` (property for aggregation). Orbit could have rules for this.

### 4.6.3. Multinomial Distribution
*   **Orbit Domain:** `Multinomial(n: Integer, probs: Vector<Real>)` (`n` trials, `probs` for `K` categories).
*   **Marginals:** Count of category `i` is `Binomial(n, probs[i])` (Rule in 4.2.1).
*   **Sum of Independent Multinomials:** If `X ~ Multinomial(n₁, p)` and `Y ~ Multinomial(n₂, p)` are independent, then `X+Y ~ Multinomial(n₁+n₂, p)`.
    **Orbit Rule:**
    ```orbit
	Rule "Sum of Independent Multinomials":
	  SumOfIndependent(M1 : Multinomial(n1, p_vec), M2 : Multinomial(n2, p_vec)) ↔ Multinomial(n1+n2, p_vec)
	  if p_vec == M2.probs; // Ensure same probability vector
```

### 4.6.4. Wishart and Inverse Wishart Distributions
*   **Domains:** `Wishart(ScaleMatrix: Matrix<Real>, df: Real)`, `InverseWishart(ScaleMatrix: Matrix<Real>, df: Real)`.
*   **Properties:** Distributions over symmetric positive-definite matrices. Used as priors for covariance matrices in Bayesian statistics.
*   **Relationship:** If `W ~ Wishart(Σ, ν)`, then `W⁻¹ ~ InverseWishart(Σ⁻¹, ν)` (approximately, under certain parameterizations).
    **Orbit Rule:**
    ```orbit
	Rule "Wishart-InverseWishart Relationship":
	  DistributionOf(inverse(W_matrix_expr)) ↔ InverseWishart(inverse(W_Dist.ScaleMatrix), W_Dist.df)
	  if DistributionOf(W_matrix_expr) is W_Dist : Wishart;
```

## 4.7. Probabilistic Graphical Models (Conceptual Link)

Probabilistic Graphical Models (PGMs), such as Bayesian Networks and Markov Random Fields, provide a framework to represent complex probabilistic relationships using graphs. Nodes represent random variables, and edges (or their absence) encode conditional independence assumptions.

*   **Factorization:** PGMs allow the joint distribution `P(X₁, ..., Xₙ)` to be factored into a product of simpler conditional probabilities based on the graph structure. For a Bayesian Network: `P(X₁,...,Xₙ) = Π P(Xᵢ | Parents(Xᵢ))`. 

While Orbit's core may not implement a full PGM inference engine initially, the tools developed in this chapter (representing distributions, conditional probabilities, independence) are essential prerequisites. Orbit could:
1.  Represent PGM structures by annotating program variables and their dependencies.
2.  Use PGM factorization to simplify joint probability queries.
3.  Apply its rewrite rules to individual factors `P(Xᵢ | Parents(Xᵢ))`. 

This becomes particularly relevant in **[Probability Part 5: Probabilistic Inference and Propagation in Orbit Programs](./probability5.md)**, where the flow of probabilistic information through program constructs will be analyzed, often mirroring the structure of a PGM.

---

This chapter has detailed how Orbit can handle the complexities of multiple random variables. By providing mechanisms for representing joint and conditional distributions, deriving marginals, and reasoning about independence and key multivariate forms, Orbit is equipped for more nuanced probabilistic program analysis. These capabilities are essential for the applications discussed in the subsequent chapters. 
