# Orbit's Approach to Probability Distributions for Program Optimization

## Project Goal

The primary goal of this project is to integrate a comprehensive understanding of probability distributions into the Orbit rewriting system. By enabling Orbit to represent, analyze, and manipulate probabilistic information associated with program variables, expressions, and control flow, we aim to unlock advanced program optimization capabilities. This involves:

1.  **Symbolic Representation:** Defining how various probability distributions (including univariate and key multivariate ones) and their parameters are represented within Orbit's domain system. This is analogous to how different matrix types and their properties are defined (see [`matrix1.md`](./matrix1.md) and [`matrix2.md`](./matrix2.md)).
2.  **Inferential Reasoning:** Developing mechanisms for Orbit to infer the distributional properties of program elements (e.g., the result of an operation, the state after a conditional branch), leveraging the rich interconnections between distributions.
3.  **Rewrite Rules:** Creating a rich set of rewrite rules that operate on these distributions to simplify expressions, propagate information, recognize equivalences between distributions, and transform program structures based on probabilistic insights. This mirrors the rule-based optimization for matrix operations.
4.  **Optimization Applications:** Utilizing the inferred probabilistic knowledge to guide optimization decisions, such as branch prediction, function inlining, memory layout, speculative execution, and value range analysis.

Ultimately, this will allow Orbit to move beyond deterministic analysis and make more nuanced, data-driven (or model-driven) decisions to generate more efficient code. This series of documents will lay the groundwork for these capabilities.

## Proposed Chapter Outline

This series of documents will explore the integration of probability distributions into Orbit:

*   **[Probability Part 1: Foundations](./probability1.md)**: Establishes the core concepts, Orbit domain representations for distributions, and basic operations. (Parallels [`matrix1.md`](./matrix1.md))
*   **[Probability Part 2: A Catalogue of Common Probability Distributions](./probability2.md)**: Details a comprehensive set of specific discrete and continuous univariate and multivariate distributions, their properties, Orbit domains, and importantly, their hierarchical relationships and specializations. (Parallels the detailed structural information in [`matrix2.md`](./matrix2.md))
*   **[Probability Part 3: Transformations and Combinations of Random Variables](./probability3.md)**: Explores how distributions change under program operations and how they combine, leveraging the catalogue from Part 2. (Parallels matrix operations and decompositions in [`matrix3.md`](./matrix3.md))
*   **[Probability Part 4: Multivariate Distributions and Conditional Probability](./probability4.md)**: Provides an in-depth treatment of multivariate distributions (building on their introduction in Part 2) and conditional probability, essential for modeling complex dependencies. (Parallels advanced analysis in [`matrix4.md`](./matrix4.md))
*   **[Probability Part 5: Probabilistic Inference and Propagation in Orbit Programs](./probability5.md)**: Discusses the application of these concepts for program analysis and optimization, showing how Orbit uses the probabilistic framework. (Parallels application-focused [`matrix5.md`](./matrix5.md))
*   **[Probability Part 6: Advanced Topics and Future Directions](./probability6.md)**: Covers more complex scenarios like information theory, stochastic processes, approximation methods, and learning distributions from profiles.

### Detailed breakdown for each planned document

**[Probability Part 1: Foundations](./probability1.md)**
*Inspired by how [`matrix1.md`](./matrix1.md) sets up core matrix algebra.*

*   **1.1. Introduction**
    *   1.1.1. Motivation: The role of probabilistic reasoning in program optimization.
    *   1.1.2. Goals: Annotating Orbit programs with distributions, inferring distributional properties.
    *   1.1.3. Overview of the Orbit Approach: Symbolic representation, rewrite rules, and inference.
*   **1.2. Representing Probability Distributions in Orbit**
    *   1.2.1. Core Concepts: Random Variables (Discrete, Continuous), Sample Spaces, Events.
    *   1.2.2. Orbit Domain System for Probability:
        *   `Distribution<ElementType, DomainSpace>` (e.g., `DomainSpace` could be `DiscreteSpace`, `ContinuousSpace`).
        *   Fundamental Descriptors: PMF, PDF, CDF.
    *   1.2.3. Representing Parameters and Properties: Mean, Variance, Mode, Median, Moments, Support.
*   **1.3. Basic Operations on Distributions in Orbit**
    *   1.3.1. Evaluation: `pmf`, `pdf`, `cdf`.
    *   1.3.2. Inverse CDF (Quantile Function): `quantile`.
    *   1.3.3. Expectation: `E` or `mean`.
    *   1.3.4. Variance: `Var` or `variance`.
    *   1.3.5. Conceptual Sampling: `sample`.
*   **1.4. Algebraic Properties and Symmetries in Orbit Rules**
    *   1.4.1. Linearity of Expectation.
    *   1.4.2. Variance Properties.
    *   1.4.3. Symmetries for Canonicalization.

---

**[Probability Part 2: A Catalogue of Common Probability Distributions](./probability2.md)**
*Analogous to [`matrix2.md`](./matrix2.md) which details specialized matrix structures. This part now incorporates a much richer set of distributions and their interrelations.*

*   **2.0. Hierarchy and Relationships of Probability Distributions:** Detailed lattice showing subtype relationships, specializations, and limiting cases for a wide array of distributions.
*   **2.1. Discrete Univariate Distributions:** Bernoulli, Binomial, Categorical, Geometric, Negative Binomial, Poisson, UniformDiscrete.
*   **2.2. Continuous Univariate Distributions:** UniformContinuous, Normal, LogNormal, Exponential, Gamma, ChiSquared, Beta, Student's T, Cauchy, Laplace.
*   **2.3. Multivariate Distributions (Introduction):** Multinomial, Dirichlet, MultivariateNormal, Wishart, InverseWishart.
*   *For each distribution:* Orbit domain definition, key mathematical properties, and documented relationships (equivalences, derivations) to other distributions, forming the basis for rewrite rules.

---

**[Probability Part 3: Transformations and Combinations of Random Variables](./probability3.md)**
*Covers how distributions are affected by operations, similar to how [`matrix3.md`](./matrix3.md) discusses matrix decompositions and operations on blocks.*

*   **3.1. Functions of a Single Random Variable**
    *   3.1.1. General Case: Deriving distribution of `Y = g(X)` if `X ~ D`.
    *   3.1.2. Linear Transformations: `Y = a*X + b`.
        *   Orbit rules for `Distribution(Y)` given `Distribution(X)`.
    *   3.1.3. Common Non-linear Transformations: `X^2`, `log(X)`, `exp(X)`, `abs(X)`.
*   **3.2. Operations on Multiple Random Variables**
    *   3.2.1. Sums, Differences, Products, Quotients.
    *   3.2.2. Convolutions: Sums of independent random variables.
        *   Orbit rules for special cases (e.g., Sum of Normals, Sum of Poissons).
    *   3.2.3. Approximations: Central Limit Theorem implications and its use in Orbit.
*   **3.3. Mixture Distributions**
    *   3.3.1. Definition: `p*D_1 + (1-p)*D_2`.
    *   3.3.2. Orbit Domain: `MixtureDistribution(weights: Vector<Real>, distributions: Vector<Distribution>)`.
    *   3.3.3. Importance for modeling outcomes after conditional branches.
    *   3.3.4. Orbit rules for properties (mean, variance) of mixtures.
*   **3.4. Order Statistics**
    *   3.4.1. Distributions of `Min(X_1, ..., X_n)` and `Max(X_1, ..., X_n)`.

---

**[Probability Part 4: Multivariate Distributions and Conditional Probability](./probability4.md)**
*Delves into more complex relationships, akin to the advanced analytical topics in [`matrix4.md`](./matrix4.md).*

*   **4.1. Joint Distributions**
    *   4.1.1. Representing `P(X_1, ..., X_n)`.
    *   4.1.2. Orbit Domain: `JointDistribution(distributions: Vector<Distribution>, correlation_structure: Matrix)` (note the use of Matrix here).
*   **4.2. Marginal Distributions**
    *   4.2.1. Deriving `P(X_i)` from a joint distribution using Orbit rules.
*   **4.3. Conditional Distributions**
    *   4.3.1. Representing `P(X | Y)`.
    *   4.3.2. Bayes' Theorem as a rewrite rule in Orbit: `P(A|B) ↔ (P(B|A) * P(A)) / P(B)`.
*   **4.4. Independence and Conditional Independence**
    *   4.4.1. Definition: `P(X,Y) = P(X)*P(Y)`.
    *   4.4.2. Rewrite rules for simplification given independence.
    *   4.4.3. Inferring independence from program structure.
*   **4.5. Covariance and Correlation**
    *   4.5.1. `Cov(X,Y)`, `Corr(X,Y)`.
*   **4.6. Key Multivariate Distributions**
    *   4.6.1. Multivariate Normal Distribution: `MultivariateNormal(mean_vector: Vector, cov_matrix: Matrix)`.
    *   4.6.2. Dirichlet Distribution: `Dirichlet(alpha_vector: Vector)`.
*   **4.7. Probabilistic Graphical Models (Conceptual Link)**
    *   4.7.1. Representing dependencies between distributions of program variables.

---

**[Probability Part 5: Probabilistic Inference and Propagation in Orbit Programs](./probability5.md)**
*Focuses on application within Orbit for analysis and optimization, similar to how [`matrix5.md`](./matrix5.md) details specialized matrices for graphics.*

*   **5.1. Annotating Program Constructs with Distributions**
    *   5.1.1. Variables: `x : Normal(0.0, 1.0)`.
    *   5.1.2. Function return values.
    *   5.1.3. Loop iteration counts (e.g., `Geometric(p)` for "loop until success").
    *   5.1.4. Input data profiles.
*   **5.2. Forward Inference through Control Flow Graphs (CFGs)**
    *   5.2.1. Sequential Statements: Updating distributions based on operations (linking to [Probability Part 3](./probability3.md)).
    *   5.2.2. Conditional Branches (`if-then-else`):
        *   Calculating branch probabilities: `P(condition_is_true)`.
        *   Deriving conditional distributions for variables within each branch path (e.g., `Distribution(x | condition_is_true)`).
        *   Combining distributions at join points (e.g., using `MixtureDistribution`).
    *   5.2.3. Loops (`while`, `for`):
        *   Inferring distributions of variables after N iterations.
        *   Fixed-point iteration to find stable/convergent distributions (if applicable).
        *   Approximations for complex loop-carried dependencies.
*   **5.3. Applications for Optimization**
    *   5.3.1. Branch Prediction: Using inferred branch probabilities.
    *   5.3.2. Value Range Analysis / Profile Inference: Inferring likely ranges or sets of values.
    *   5.3.3. Inlining Decisions: Based on likelihood of function calls, distributional properties of arguments.
    *   5.3.4. Memory Layout & Prefetching: Based on probabilistic access patterns.
    *   5.3.5. Speculative Execution Guidance.
    *   5.3.6. Guiding Data Structure Choices.
*   **5.4. Uncertainty Propagation and Management**
    *   5.4.1. Tracking variance or confidence intervals.
    *   5.4.2. How Orbit represents and updates uncertainty as computations proceed.
    *   5.4.3. Rules for combining uncertainties.

---

**[Probability Part 6: Advanced Topics and Future Directions](./probability6.md)**

*   **6.1. Information Theory Concepts in Orbit**
    *   6.1.1. Entropy: `H(Distribution)` as a measure of uncertainty/information.
    *   6.1.2. Mutual Information, KL Divergence: Quantifying relationships or differences.
    *   6.1.3. Using these for optimization heuristics (e.g., minimizing entropy).
*   **6.2. Stochastic Processes and Markov Chains (Conceptual)**
    *   6.2.1. Modeling program state evolution over time or iterations.
    *   6.2.2. Inferring steady-state distributions for loops or recursive structures.
*   **6.3. Approximation Methods for Intractable Distributions**
    *   6.3.1. Handling cases where transformations lead to distributions not in the catalogue.
    *   6.3.2. Techniques: Moment Matching, Variational Approximations (conceptual).
    *   6.3.3. Perturbation Methods.
*   **6.4. Learning Distributions from Profiles**
    *   6.4.1. How dynamic program profile data could be used to seed initial distributions or refine parameters within Orbit.
    *   6.4.2. Combining static analysis with profile-guided probabilistic models.
*   **6.5. Decision Theory for Optimal Compiler Choices**
    *   6.5.1. Framing optimization choices (e.g., to inline or not, which loop unroll factor) as decisions under uncertainty.
    *   6.5.2. Using expected utility based on inferred probabilities and cost models.
*   **6.6. Probabilistic Type Systems**
    *   6.6.1. Extending Orbit's domain system to represent types that carry distributional information.
