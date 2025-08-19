# Statistical Tests and Their Relation to Probability Distributions in Orbit

## Introduction

This chapter bridges the theoretical probability distributions detailed in the previous "Probability Parts" documents ([Part 1: Foundations](./probability1.md), [Part 2: Catalogue](./probability2.md), [Part 3: Transformations](./probability3.md), [Part 4: Multivariate](./probability4.md)) with their practical applications in statistical inference and hypothesis testing. While Orbit's primary goal is to use probabilistic models for program analysis and optimization ([Part 5: Inference](./probability5.md)), understanding the statistical context of these distributions enriches their interpretation and highlights their broader significance in reasoning from data. Orbit can further leverage its rule-based system to symbolically reason about which statistical tests are appropriate given certain hypotheses and data characteristics.

Many of the distributions Orbit models are precisely those that form the bedrock of classical and Bayesian statistics. This chapter will outline key statistical concepts, common tests, and how Orbit might symbolically infer test applicability, explicitly linking them to the distributions Orbit can represent.

## Core Statistical Concepts

*   **Population vs. Sample:**
    *   A **population** is the entire set of individuals, items, or data points of interest. Represented by a `Distribution` domain in Orbit (e.g., `Normal(μ, σ²)`).
    *   A **sample** is a subset of the population. Represented by `SampleData(values: Vector, size: Integer, ...)`.

*   **Parameters vs. Statistics:**
    *   A **parameter** is a numerical characteristic of a population distribution (e.g., `Mean(D_population)`, `Variance(D_population)`).
    *   A **statistic** (or **estimator**) is calculated from `SampleData` (e.g., `SampleMean(sample_data_obj)`, `SampleVariance(sample_data_obj)`). It is a random variable with a **sampling distribution**.

*   **Sampling Distributions:**
    The distribution of a sample statistic. For example, the sampling distribution of `SampleMean` from `D_pop : Normal(μ, σ²)` is `Normal(μ, σ²/sample_data_obj.size)`. This is critical for constructing tests.

## Hypothesis Testing Framework in Orbit

Hypothesis testing is a formal procedure for making decisions about population parameters based on sample evidence. Orbit can symbolically represent hypotheses and infer appropriate testing procedures.

### Symbolic Hypothesis Representation in Orbit

We introduce a way to represent hypotheses symbolically:

```orbit
// General form for a hypothesis statement
// Hypothesis(parameter_query: Expression, relation: RelationalOp, value: Scalar)
//   parameter_query: e.g., Mean(D_population), Variance(D_population), Proportion(D_population)
//   relation: e.g., Equals, NotEquals, GreaterThan, LessThan

// Example H₀: μ = μ₀ for a Normal population D_pop = Normal(μ_true, σ_sq_true)
H0_MeanEquals : Hypothesis(Mean(D_pop), Equals, μ₀);

// Example H₁: μ ≠ μ₀
H1_MeanNotEquals : Hypothesis(Mean(D_pop), NotEquals, μ₀);

// Data characteristics might be represented as:
// SampleCharacteristics(population_dist: Distribution, sample_obj: SampleData, known_params: Map<String, Any>)
// e.g., SampleCharacteristics(D_pop, sample1, {"population_variance": σ²_known})
```

### General Test Inference Structure

Orbit rules can infer a suitable test based on the hypothesis and data characteristics.

```orbit
// Conceptual structure for test inference rules
InferStatisticalTest(
	null_hypothesis : Hypothesis,
	alternative_hypothesis : Hypothesis,
	sample_chars : SampleCharacteristics
	) ↔ TestProcedure(
		test_name : String,                 // e.g., "OneSampleTTest"
		test_statistic_symbolic : Expression, // Formula for the test statistic
		null_distribution : Distribution,     // Distribution of test_statistic under H₀
		conditions_for_validity : Vector<Expression> // Assumptions for the test
	);
```

*   **Null Hypothesis (H₀) & Alternative Hypothesis (H₁/Hₐ):** As defined symbolically above.
*   **Test Statistic:** A value calculated from `SampleData` and hypothesized parameters.
*   **Significance Level (α), p-value, Type I/II Errors:** These are standard statistical concepts Orbit assumes the user would apply when interpreting results derived from the `TestProcedure`.

## Common Statistical Tests: Symbolic Inference in Orbit

### Tests for Means

1.  **One-Sample Z-Test (for a population mean)**
    *   **Hypothesis Example:** `H₀: Mean(D_pop) = μ₀` vs. `H₁: Mean(D_pop) ≠ μ₀`.
    *   **Orbit Rule:**
        ```orbit
		InferStatisticalTest(
			Hypothesis(Mean(D_pop : Normal), Equals, μ₀), // H₀
			Hypothesis(Mean(D_pop : Normal), NotEquals, μ₀), // H₁
			SampleChars(population_dist=D_pop, sample=S_obj, known_params=KP_map)
		  ) ↔ TestProcedure(
				test_name = "OneSampleZTest",
				test_statistic_symbolic = (SampleMean(S_obj) - μ₀) / (KnownPopulationStdDev(KP_map) / sqrt(S_obj.size)),
				null_distribution = Normal(0.0, 1.0), // Standard Normal from probability2.md
				conditions_for_validity = [
					(IsNormal(D_pop) || S_obj.size >= 30), // Population normal or large sample (CLT from probability3.md)
					HasKey(KP_map, "population_std_dev")     // Population std dev must be known
				]
			) if HasKey(KP_map, "population_std_dev"); // Guard for rule applicability
```

2.  **One-Sample t-Test (for a population mean)**
    *   **Hypothesis Example:** `H₀: Mean(D_pop) = μ₀` vs. `H₁: Mean(D_pop) ≠ μ₀`.
    *   **Orbit Rule:**
        ```orbit
		InferStatisticalTest(
			Hypothesis(Mean(D_pop : Normal), Equals, μ₀),
			Hypothesis(Mean(D_pop : Normal), NotEquals, μ₀),
			SampleChars(population_dist=D_pop, sample=S_obj, known_params=KP_map)
		  ) ↔ TestProcedure(
				test_name = "OneSampleTTest",
				test_statistic_symbolic = (SampleMean(S_obj) - μ₀) / (SampleStdDev(S_obj) / sqrt(S_obj.size)),
				null_distribution = StudentT(S_obj.size - 1), // StudentT from probability2.md
				conditions_for_validity = [
					(IsNormal(D_pop) || S_obj.size >= 30),
					!HasKey(KP_map, "population_std_dev") // Population std dev is unknown
				]
			) if !HasKey(KP_map, "population_std_dev");
```

3.  **Two-Sample t-Test (independent samples, for comparing two means)**
    *   **Hypothesis Example:** `H₀: Mean(D_pop1) - Mean(D_pop2) = 0` vs. `H₁: Mean(D_pop1) - Mean(D_pop2) ≠ 0`.
    *   **Orbit Rule (simplified, assumes pooled variance for brevity):**
        ```orbit
		InferStatisticalTest(
			Hypothesis(Mean(D_pop1:Normal) - Mean(D_pop2:Normal), Equals, 0),
			Hypothesis(Mean(D_pop1:Normal) - Mean(D_pop2:Normal), NotEquals, 0),
			SampleChars(populations=[D_pop1, D_pop2], samples=[S1_obj, S2_obj], known_params=KP_map)
		  ) ↔ TestProcedure(
				test_name = "TwoSampleTTestPooledVariance",
				test_statistic_symbolic = /* ... complex formula with S1_obj, S2_obj, pooled_std_dev ... */,
				null_distribution = StudentT(S1_obj.size + S2_obj.size - 2),
				conditions_for_validity = [
					IsNormal(D_pop1) || S1_obj.size >= 30,
					IsNormal(D_pop2) || S2_obj.size >= 30,
					SamplesAreIndependent(S1_obj, S2_obj),
					AssumeEqualVariances(KP_map) // Assumption of equal pop variances
				]
			) if AssumeEqualVariances(KP_map);
```

4.  **ANOVA (Analysis of Variance, for comparing means of >=3 groups)**
    *   **Hypothesis Example:** `H₀: Mean(D1)=Mean(D2)=Mean(D3)` vs. `H₁: At least one mean differs`.
    *   **Orbit Rule:**
        ```orbit
		InferStatisticalTest(
			Hypothesis(AllMeansEqual([D1:Normal, D2:Normal, D3:Normal]), Equals, true),
			Hypothesis(AllMeansEqual([D1:Normal, D2:Normal, D3:Normal]), NotEquals, true),
			SampleChars(populations=[D1,D2,D3], samples=[S1,S2,S3], known_params=KP_map)
		  ) ↔ TestProcedure(
				test_name = "ANOVA_FTest",
				test_statistic_symbolic = /* Ratio of (Variance between groups) / (Variance within groups) */,
				null_distribution = FDistribution(k-1, N-k), // F-dist, k=groups, N=total samples
				conditions_for_validity = [/* Normality, Independence, Homoscedasticity */]
			);
```

### Tests for Proportions (using Normal Approximation to Binomial)

1.  **One-Sample Z-Test for Proportion**
    *   **Hypothesis Example:** `H₀: Proportion(D_pop:BernoulliFamily) = p₀`.
    *   **Orbit Rule:**
        ```orbit
		InferStatisticalTest(
			Hypothesis(Proportion(D_pop : BernoulliFamily), Equals, p₀), // D_pop could be Bernoulli or Binomial
			Hypothesis(Proportion(D_pop : BernoulliFamily), NotEquals, p₀),
			SampleChars(population_dist=D_pop, sample=S_obj, known_params=KP_map)
		  ) ↔ TestProcedure(
				test_name = "OneSampleZTestProportion",
				test_statistic_symbolic = (SampleProportion(S_obj) - p₀) / sqrt(p₀*(1-p₀)/S_obj.size),
				null_distribution = Normal(0.0, 1.0),
				conditions_for_validity = [
					S_obj.size * p₀ >= 10,             // Large sample condition for Normal approx
					S_obj.size * (1-p₀) >= 10          // (Relies on Binomial from probability2.md and CLT)
				]
			);
```

### Tests for Variances

1.  **Chi-Squared Test for Variance (One Sample)**
    *   **Hypothesis Example:** `H₀: Variance(D_pop:Normal) = σ₀²`.
    *   **Orbit Rule:**
        ```orbit
		InferStatisticalTest(
			Hypothesis(Variance(D_pop : Normal), Equals, σ₀_sq),
			Hypothesis(Variance(D_pop : Normal), NotEquals, σ₀_sq),
			SampleChars(population_dist=D_pop, sample=S_obj, known_params=KP_map)
		  ) ↔ TestProcedure(
				test_name = "ChiSquaredTestVariance",
				test_statistic_symbolic = (S_obj.size - 1) * SampleVariance(S_obj) / σ₀_sq,
				null_distribution = ChiSquared(S_obj.size - 1), // ChiSquared from probability2.md
				conditions_for_validity = [IsNormal(D_pop)]
			);
```

### Goodness-of-Fit Tests

1.  **Chi-Squared Goodness-of-Fit Test**
    *   **Hypothesis Example:** `H₀: DistributionOf(SampleCategoryCounts) matches D_hypothesized_categorical`.
    *   **Orbit Rule:**
        ```orbit
		InferStatisticalTest(
			Hypothesis(DistributionOf(SampleCounts_obj), Matches, D_theoretical : CategoricalFamily),
			Hypothesis(DistributionOf(SampleCounts_obj), NotMatches, D_theoretical : CategoricalFamily),
			SampleChars(sample=SampleCounts_obj, population_dist=D_theoretical, known_params=KP_map)
		  ) ↔ TestProcedure(
				test_name = "ChiSquaredGoodnessOfFit",
				test_statistic_symbolic = SumOverCategories(((Observed_i - Expected_i(D_theoretical))^2) / Expected_i(D_theoretical)),
				null_distribution = ChiSquared(num_categories - 1 - num_estimated_params),
				conditions_for_validity = [/* All Expected_i >= 5 (heuristic) */]
			);
```

## Confidence Intervals (Symbolic Representation)

Orbit can also symbolically represent the construction of confidence intervals.

```orbit
// Conceptual representation of a Confidence Interval Query
// QueryConfidenceInterval(parameter_query: Expression, confidence_level: Real, sample_chars: SampleCharacteristics)

Rule "CI for Mean, Known Variance":
	QueryConfidenceInterval(Mean(D_pop:Normal), conf_level, SampleChars(..., sample=S_obj, known_params=KP_map with {"population_std_dev": σ_known})) ↔
	ConfidenceIntervalResult(
		parameter = Mean(D_pop),
		interval_expr = Pair(
			SampleMean(S_obj) - Quantile(Normal(0,1), (1+conf_level)/2) * (σ_known / sqrt(S_obj.size)),
			SampleMean(S_obj) + Quantile(Normal(0,1), (1+conf_level)/2) * (σ_known / sqrt(S_obj.size))
		),
		method = "ZIntervalKnownVariance"
	);
// Quantile function from probability1.md
```


### Summary Table of Tests for Means and Proportions

| Test Name                      | Population Parameter(s)             | Null Hypothesis Example                      | Test Statistic Distribution (under H₀) | Key Conditions / Assumptions                                  | Orbit `InferStatisticalTest` Inputs (Conceptual)                                |
| :----------------------------- | :---------------------------------- | :------------------------------------------- | :--------------------------------------- | :------------------------------------------------------------ | :------------------------------------------------------------------------------ |
| **One-Sample Z-Test (Mean)**   | Population Mean (μ)                 | `μ = μ₀`                                     | `Normal(0,1)`                            | Population Normal or large sample (n≥30), Population σ known    | `Hypothesis(Mean(D_pop), Op, μ₀)`, `SampleChars(D_pop, S, KP_map has pop_std_dev)` |
| **One-Sample t-Test (Mean)**   | Population Mean (μ)                 | `μ = μ₀`                                     | `StudentT(n-1)`                          | Population Normal or large sample (n≥30), Population σ unknown  | `Hypothesis(Mean(D_pop), Op, μ₀)`, `SampleChars(D_pop, S, KP_map no pop_std_dev)` |
| **Two-Sample t-Test (Means)**  | Difference of Means (μ₁ - μ₂)     | `μ₁ - μ₂ = 0` or `μ₁ = μ₂`                     | `StudentT(df)`                           | Independent samples, Normality/large samples, Equal variances (for pooled) | `Hypothesis(Mean(D1)-Mean(D2), Op, 0)`, `SampleChars([D1,D2], [S1,S2], ...)`    |
| **Paired t-Test (Means)**      | Mean of Differences (μ_diff)        | `μ_diff = 0`                                 | `StudentT(n-1)`                          | Paired samples, Differences Normal or large sample (n_pairs≥30) | `Hypothesis(Mean(D_diffs), Op, 0)`, `SampleChars(D_diffs, S_pairs, ...)`        |
| **ANOVA F-Test (Means)**       | Means of ≥3 Groups (μ₁,μ₂,...,μₖ) | `μ₁ = μ₂ = ... = μₖ`                         | `FDistribution(k-1, N-k)`                | Independent groups, Normality, Homoscedasticity (equal variances) | `Hypothesis(AllMeansEqual([...]), Op, true)`, `SampleChars([D1..Dk],[S1..Sk],...)` |
| **One-Sample Z-Test (Prop.)**  | Population Proportion (p)           | `p = p₀`                                     | `Normal(0,1)` (approx.)                  | Large sample (np₀≥10, n(1-p₀)≥10)                             | `Hypothesis(Proportion(D_pop_bin), Op, p₀)`, `SampleChars(D_pop_bin, S_counts, ...)` |
| **Two-Sample Z-Test (Prop.)**  | Difference of Props (p₁ - p₂)     | `p₁ - p₂ = 0` or `p₁ = p₂`                     | `Normal(0,1)` (approx.)                  | Independent samples, Large samples for both groups          | `Hypothesis(Prop(D1)-Prop(D2), Op, 0)`, `SampleChars([D1,D2], [Counts1,Counts2], ...)` |

*(Note: `Op` refers to comparison operators like `=`, `≠`, `<`, `>`. `D_pop` implies a distribution like `Normal` or `Binomial`. `S` refers to sample data characteristics.)*

## Relevance to Orbit and Its Probabilistic Framework

The symbolic representation of hypotheses and test inference rules extends Orbit's capabilities:

1.  **Automated Analysis Guidance:** Given a dataset's characteristics (represented as `SampleData` and `SampleCharacteristics`) and a hypothesis, Orbit could suggest appropriate statistical tests. This could be part of an interactive environment or a system that reasons about empirical data.
2.  **Validation of Probabilistic Models:** If Orbit infers a distribution `D_inferred` for a program variable ([Part 5](./probability5.md)), and empirical data for this variable is available, Orbit could:
    *   Formulate `H₀: TrueDistribution = D_inferred`.
    *   Use `InferStatisticalTest` to determine a suitable goodness-of-fit test.
    *   This provides a pathway to (semi-)automatically check the validity of its own probabilistic models against real-world observations.
3.  **Program Synthesis/Refinement based on Statistical Evidence:** In advanced scenarios, if Orbit is tasked with generating code that should meet certain probabilistic criteria (e.g., output follows `Normal(μ,σ²)`), it could generate candidate programs and then use this framework to outline how these candidates would be statistically validated.
4.  **Enriching Optimization Heuristics:** Understanding the statistical significance of observed differences (e.g., in execution times under different configurations) can lead to more robust optimization decisions. Orbit could use the `TestProcedure` information to assess if an observed improvement is likely real or due to chance before committing to an optimization.
5.  **Formalizing Experimental Design:** For A/B testing or evaluating program changes, Orbit could symbolically outline the hypothesis to test (e.g., `H₀: MeanPerformance_A = MeanPerformance_B`) and determine the correct statistical test, thus aiding in the design and interpretation of experiments.

## Conclusion

By integrating symbolic representations of statistical hypotheses and rules for inferring appropriate tests, Orbit gains a powerful layer of reasoning that connects its abstract probabilistic models to concrete data analysis methodologies. This allows Orbit not just to model probability internally, but also to reason about how those models and their parameters would be scrutinized and validated using standard statistical practice. This opens avenues for more robust, data-aware program analysis and optimization.
