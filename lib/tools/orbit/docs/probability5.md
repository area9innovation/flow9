# Probability Part 5: Probabilistic Inference and Propagation in Orbit Programs

*This chapter builds upon the foundational probabilistic framework ([Part 1](./probability1.md)), the distribution catalogue ([Part 2](./probability2.md)), transformation rules ([Part 3](./probability3.md)), and multivariate/conditional concepts ([Part 4](./probability4.md)). We now focus on how Orbit applies this framework to analyze programs: annotating constructs, inferring and propagating distributions through Control Flow Graphs (CFGs), and leveraging this probabilistic knowledge for optimization. This mirrors how [`matrix5.md`](./matrix5.md) applies matrix algebra to graphics, or how `semantics.md` uses domains and rules for semantic property inference.*

## Introduction

The practical utility of Orbit's probabilistic reasoning lies in its application to program code. By understanding the likelihood of variable values and execution paths, Orbit can make more informed optimization decisions. This chapter details the mechanisms for this probabilistic inference, treating distributions as first-class properties that flow through the program, much like types or other semantic annotations.

## 5.1. Annotating Program Constructs with Distributions

Probabilistic inference begins with initial distribution annotations, which serve as axioms in our reasoning system. These can be attached to variables, function returns, or even abstract properties like loop iteration counts.

**Orbit Domain Annotations:**
Distributions are associated with program entities (variables, expressions) via Orbit's domain system. An expression `e` having distribution `D` can be represented as `e : D` or an e-class property `DistributionOf(e) = D`.

### 5.1.1. Variables
Source-level annotations or type-like declarations can specify distributions for variables.

```orbit
// Source Annotation Examples:
// input_user_age : Normal(35.0, 100.0);
// network_latency_ms : Exponential(0.01);
// success_flag : Bernoulli(0.95);

// Orbit Rule to internalize source annotations:
// (Conceptual: assumes parser provides 'SourceAnnotation' terms)
SourceAnnotation(var_name, dist_constructor_expr)
	⊢ var_name : eval(dist_constructor_expr); // e.g., var_name : Normal(35.0, 100.0)
```

### 5.1.2. Function Return Values
Function signatures can declare the distribution of their return values.

```orbit
// Source Signature:
// def get_sensor_reading() -> temperature : Normal(20.0, 0.25);

// Orbit Rule from function definition:
fn_def(f_name, params, return_annotation : DistributionType, body_expr)
	⊢ ReturnDistribution(f_name) : return_annotation;

// When a call occurs:
assign(result_var, call(f_name, args_list))
	where ReturnDistribution(f_name) is D_return
	⊢ result_var : D_return;
```
Alternatively, the return distribution can be inferred from the function body's operations on input distributions.

### 5.1.3. Loop Iteration Counts
The number of times a loop executes, `N_iter`, can be modeled as a random variable.

```orbit
// Annotation for a loop:
// loop_construct : HasIterationCountDistribution(Geometric(0.8));

// Orbit Rule (example inference for simple retry loop):
// while (status != SUCCESS) { attempt_call(); status = get_status(); }
// Assume attempt_call() leads to status=SUCCESS with probability p_success.
while_loop(cond_expr, body_expr)
	where ConditionIsSuccessCheck(cond_expr, p_continue_per_iter) // p_continue = 1 - p_success
	⊢ LoopIterationCount(while_loop) : Geometric(1.0 - p_continue_per_iter); // Geometric gives #trials until first success
```
`ConditionIsSuccessCheck` is a conceptual predicate matching specific loop patterns.

### 5.1.4. Input Data Profiles
Statistical profiles of input data can seed initial distributions.

```orbit
// Transaction amounts from profile data: transaction_amount : LogNormal(5.0, 1.5);
// This would be an initial annotation similar to 5.1.1.
```

## 5.2. Forward Inference through Control Flow Graphs (CFGs)

Orbit performs a dataflow-like analysis, propagating distributions through the CFG. Each program point (or e-class representing an expression at a point) can be annotated with the inferred distributions of live variables.

### 5.2.1. Sequential Statements: Updating Distributions
Assignments `lhs = rhs_expr` are key. The distribution of `lhs` is determined by the distribution of `rhs_expr`.

```orbit
// General Rule for Assignment:
assign(lhs_var, rhs_expr)
	where DistributionOf(rhs_expr) is D_rhs // D_rhs inferred from ops in rhs_expr
	⊢ lhs_var : D_rhs;

// Example: Linear Transformation (using rule from Part 3)
// Code: y = 2.0 * x + 5.0;
// Assume x_var : Normal(10.0, 4.0) is known.
assign(y_var, `*`(2.0, x_var) + 5.0)
	where x_var : D_x : Normal(10.0, 4.0) // D_x could be from prior inference
	// Let op_multiply = `*`(2.0, x_var). D_op_multiply = LinearTransform(D_x, 2.0, 0.0) = Normal(20.0, 16.0)
	// Let op_add = op_multiply + 5.0. D_op_add = LinearTransform(D_op_multiply, 1.0, 5.0) = Normal(25.0, 16.0)
	⊢ y_var : Normal(25.0, 16.0);
	// This relies on Part 3 rules like: DistributionOf(a*X+b) ↔ LinearTransform(DistributionOf(X),a,b)
	// And LinearTransform(Normal(μ,σ²),a,b) → Normal(aμ+b, a²σ²)

// Example: Sum of Independent Variables (using rule from Part 3)
// Code: z = x + y;
// Assume x_var : Poisson(3.0), y_var : Poisson(5.0), IndependentOf(x_var, y_var)
assign(z_var, x_var + y_var)
	where x_var : D_x : Poisson(3.0),
				y_var : D_y : Poisson(5.0),
				D_x : IndependentOf(D_y) // This property is crucial
	// DistributionOf(x_var + y_var) ↔ SumOfIndependent(D_x, D_y) (from Part 3)
	// SumOfIndependent(Poisson(λ1), Poisson(λ2)) → Poisson(λ1+λ2) (from Part 3)
	⊢ z_var : Poisson(8.0);
```

### 5.2.2. Conditional Branches (`if-then-else`)

1.  **Calculating Branch Probabilities:**
    The probability of the condition `cond_expr` being true is computed. This may involve evaluating the CDF/PMF of the distribution of `cond_expr` (if it's a simple comparison) or more complex reasoning.

    ```orbit
	// Code: if (x > 0.5) { path_true } else { path_false }
	// Assume x_var : Normal(0.0, 1.0)
	if_stmt(cond_expr : `>`(x_var, 0.5), path_true, path_false)
	  where x_var : D_x : Normal(0.0, 1.0)
	  // Let P_true = P(x_var > 0.5 | D_x) = 1.0 - CDF(D_x, 0.5)
	  // CDF(Normal(0,1), 0.5) is a known value or function call.
	⊢ path_true : HasPathProbability(P_true_val),    // e.g., P_true_val = 0.3085
	  path_false : HasPathProbability(1.0 - P_true_val);
```

2.  **Deriving Conditional Distributions (Path-Specific Inference):**
    Within each branch, variable distributions are refined based on the branch condition.

    ```orbit
	// Continuing: x_var : Normal(0.0, 1.0)
	// Inside path_true (condition x > 0.5 holds):
	// Rule to update distribution of x_var *within the scope of path_true*:
	var_access(x_var, scope_path_true)
	  where OriginalDistribution(x_var, scope_if_stmt) is D_x_orig : Normal(0.0, 1.0),
			PathCondition(scope_path_true) is `>`(x_var, 0.5) // Condition for this path
	  // ConditionalDistribution(Normal(μ,σ²), Var > c) → TruncatedNormal(μ,σ²,lower=c,upper=∞) (from Part 4)
	⊢ x_var : TruncatedNormal(0.0, 1.0, 0.5, Infinity) : InScope(scope_path_true);

	// Similarly for path_false (condition x <= 0.5):
	var_access(x_var, scope_path_false)
	  where OriginalDistribution(x_var, scope_if_stmt) is D_x_orig : Normal(0.0, 1.0),
			PathCondition(scope_path_false) is `<=`(x_var, 0.5)
	⊢ x_var : TruncatedNormal(0.0, 1.0, NegativeInfinity, 0.5) : InScope(scope_path_false);
```

3.  **Combining Distributions at Join Points:**
    At a control flow join point, the distribution of a variable modified in multiple incoming paths becomes a `MixtureDistribution` (from Part 3).

    ```orbit
	// Code: if (cond) { v = expr1; /* v:D1 */ } else { v = expr2; /* v:D2 */ } /* join */
	// Let PathProbability(path_true_scope) be P_true
	// Let PathProbability(path_false_scope) be P_false
	var_at_join(v_var, scope_join)
	  where DistributionOf(v_var, scope_path_true) is D1,
			DistributionOf(v_var, scope_path_false) is D2,
			PathProbability(scope_path_true) is P_true,
			PathProbability(scope_path_false) is P_false
	⊢ v_var : MixtureDistribution([P_true, P_false], [D1, D2]) : InScope(scope_join);
```

### 5.2.3. Loops (`while`, `for`)

1.  **Distribution of Loop Iteration Count `N_iter`:** (As in 5.1.3) This is fundamental. May be annotated or inferred for specific patterns.

2.  **Distribution of Loop-Carried Variables:** This typically involves an iterative process.
    Let `D_v_k` be the distribution of variable `v` at the beginning of iteration `k`.
    `D_v_k+1 = TransformInLoopBody(D_v_k, D_other_vars_k)`.

    **Fixed-Point Iteration for Stationary Distributions:** Orbit can attempt to find a stable distribution `D_v_stable` such that `D_v_stable = TransformInLoopBody(D_v_stable, ...)`.
    ```orbit
	// Conceptual Rule for fixed-point seeking:
	// This is more of an algorithm applied by Orbit's engine.
	DefineLoopAnalysis(loop_id, loop_vars, loop_body_transform_fn) // Setup
	RunFixedPointIteration(loop_id, initial_distributions, convergence_threshold)
	  // Result is a set of D_stable for loop_vars
	  ⊢ loop_var_i : D_stable_i : AtLoopExit(loop_id);
```

3.  **Overall Distribution after Loop:** If `N_iter` has distribution `D_N_iter`, and `D_v(k)` is the distribution of `v` after exactly `k` iterations, then the distribution of `v` after the loop is a mixture:
    `MixtureDistribution( [P(N_iter=k|D_N_iter) for k], [D_v(k) for k] )`.
    This is complex to compute in full generality. Orbit might:
    *   Use the stationary distribution `D_v_stable` if `N_iter` is expected to be large.
    *   Approximate by considering only a few terms of `D_N_iter` (e.g., mean, mean±stddev).
    *   Use moment propagation: Track `E[v_k]` and `Var[v_k]` iteratively. For `E[v_k+1] = E[f(v_k)]`, this might use approximations like `E[f(v_k)] ≈ f(E[v_k])` (crude) or Taylor expansion (delta method).

    ```orbit
	// Example approximation using mean of N_iter:
	var_after_loop(v_var, scope_after_loop)
	  where LoopIterationCount(parent_loop) is D_N_iter,
			Mean(D_N_iter) is μ_N_iter,
			DistributionOf(v_var | N_iter = round(μ_N_iter)) is D_v_at_mean_N // Approx.
	⊢ v_var : D_v_at_mean_N : IsApproximation : InScope(scope_after_loop);
```

## 5.3. Applications for Optimization

Inferred probabilistic information enables targeted optimizations.

### 5.3.1. Branch Prediction
Path probabilities directly inform static branch prediction hints.
```orbit
// if_stmt(cond, then_b, else_b)
// PathProbability(then_b) is P_then (from rule 5.2.2.1)
Rule "Static Branch Prediction Hint":
	if_stmt(cond_expr, then_block, else_block)
		where PathProbability(then_block) is P_then,
					P_then > branch_prediction_threshold_taken // e.g., 0.7
	⊢ AddOptimizationHint(if_stmt, PredictBranchTaken);

	if_stmt(cond_expr, then_block, else_block)
		where PathProbability(then_block) is P_then,
					P_then < branch_prediction_threshold_not_taken // e.g., 0.3
	⊢ AddOptimizationHint(if_stmt, PredictBranchNotTaken);
```

### 5.3.2. Value Range Analysis / Profile Inference
Distributions provide likely value ranges, aiding various optimizations.
```orbit
// Example: Strength reduction if index is likely small.
// array_access(arr, index_var)
// index_var : D_idx
Rule "Value Range Based Strength Reduction":
	multiply_op(var_expr, const_val)
		where var_expr : D_var,
					Mode(D_var) is mode_val, // Most likely value
					IsPowerOfTwo(mode_val * const_val) is shift_amount, // Check if product is power of two for mode
					HighProbabilityNearMode(D_var, range_for_specialization) // e.g. P(var near mode) > 0.9
	⊢ SpecializeAndReplace(multiply_op, ShiftLeft(var_expr_specialized, shift_amount))
		if var_expr in range_for_specialization;
```
This is highly conceptual, showing how a specialized version could be triggered.

### 5.3.3. Inlining Decisions
Function call likelihood and argument distributions guide inlining.
```orbit
// call_expr(f_name, args)
// PathProbability(call_expr_scope) is P_call_reached
Rule "Probabilistic Inlining Heuristic":
	call_expr(f_name, args_list)
		where PathProbability(ScopeOf(call_expr)) is P_call,
					FunctionInfo(f_name, Size is F_Size, IsRecursive is false),
					EstimatedBenefit(P_call, F_Size, args_list) > inlining_threshold
					// EstimatedBenefit might consider if args have constant-like distributions.
	⊢ AddOptimizationHint(call_expr, InlineThisCall);
```

### 5.3.4. Memory Layout & Prefetching
Distribution of memory access indices can guide layout or prefetching.
```orbit
// array_access(arr_name, index_expr)
// index_expr : D_idx
Rule "Probabilistic Prefetching Hint":
	array_access(arr_expr, index_expr)
		where index_expr : D_idx : Normal(μ_idx, σ_sq_idx),
					σ_sq_idx < prefetch_variance_trigger, // Index is somewhat predictable
					CurrentInstructionPointer() is IP_current
	⊢ AddPrefetchInstruction(address_of(arr_expr) + μ_idx * element_size, prefetch_locality_hint)
		if IP_current : NotInsidePrefetchCooldown; // Avoid excessive prefetching
```

### 5.3.5. Speculative Execution Guidance
Path probabilities can guide hardware speculation or software speculative precomputation.
```orbit
// After an if_stmt, the path with higher PathProbability is a candidate for speculation.
Rule "Speculative Execution Path Choice":
	join_point(after_if_stmt)
		where PredecessorPath(join_point, then_path), PathProbability(then_path) is P_then,
					PredecessorPath(join_point, else_path), PathProbability(else_path) is P_else,
					P_then > P_else && P_then > speculation_activation_threshold
	⊢ AddSpeculationTarget(then_path, speculation_priority_high);
```

### 5.3.6. Guiding Data Structure Choices (Advanced)
Expected size distributions might influence data structure selection (e.g., during a refactoring step or for a JIT).
```orbit
// list_append_op(list_var, element)
// list_var : HasSizeDistribution(D_size)
Rule "Data Structure Transformation Hint":
	program_construct(uses=collection_var)
		where collection_var : D_current_type, // e.g. LinkedList
*   **5.3.7. Automatic Caching for Pure, Hot Functions**
	*   If a function is determined to be `Pure` (no side effects) and "Hot" (frequently executed, based on profiling), Orbit can infer the potential benefits of caching its results. The choice of caching policy depends heavily on the inferred probability distribution of its inputs.
	*   **Uniform Distribution of Inputs**: If the input values are likely to be uniformly distributed, a simple **Least Recently Used (LRU)** cache is often effective. This is because new, distinct inputs are common, and older, less relevant entries should be evicted.
```orbit
        f_pure_hot : Function(InputType) -> OutputType,
        f_pure_hot : IsPure,
        f_pure_hot : IsHot(call_frequency_high),
        InputType : Distribution(Uniform(min, max))
        ⊢ SuggestCachingPolicy(f_pure_hot, LRUCache(size_heuristic));
        ```
	*   **Power-Law / Zipfian Distribution of Inputs**: If inputs follow a power-law or Zipfian distribution (a few inputs are extremely common, while most are rare), a **Least Frequently Used (LFU)** or a **Most Frequently Used (MFU)** cache might be more appropriate. LFU ensures that popular items remain cached even if not recently accessed. MFU can be useful if the most frequent items are the ones most likely to be requested again soon, and older, less frequent items are less important. The choice between LFU and MFU can depend on access patterns and cache size.
```orbit
        f_pure_hot : Function(InputType) -> OutputType,
        f_pure_hot : IsPure,
        f_pure_hot : IsHot(call_frequency_high),
        InputType : Distribution(PowerLaw(alpha)) or InputType : Distribution(Zipf(s))
        ⊢ SuggestCachingPolicy(f_pure_hot, LFUCache(size_heuristic));
        // or SuggestCachingPolicy(f_pure_hot, MFUCache(size_heuristic));
        ```
	*   **Categorical / Small Discrete Set of Inputs**: If the function inputs come from a small, fixed set of discrete values (Categorical distribution with few categories), a **direct lookup table or a simple array/map-based cache** that covers all possible inputs might be optimal. This essentially precomputes and stores all possible results.
```orbit
        f_pure_hot : Function(InputType) -> OutputType,
        f_pure_hot : IsPure,
        f_pure_hot : IsHot(call_frequency_high),
        InputType : Distribution(Categorical(probabilities)) where Cardinality(InputType) < small_threshold
        ⊢ SuggestCachingPolicy(f_pure_hot, FullLookupCache());
        ```
	*   **Other Distributions / Complex Cases**: For other distributions or when inputs are complex data structures, more sophisticated caching strategies or adaptive caching might be considered. This could involve analyzing the distribution of specific features of the input data. Orbit might suggest a default (e.g., LRU) or flag it for further analysis.
```orbit
        f_pure_hot : Function(InputType) -> OutputType,
        f_pure_hot : IsPure,
        f_pure_hot : IsHot(call_frequency_high),
        InputType : Distribution(OtherComplexDist)
        ⊢ SuggestCachingPolicy(f_pure_hot, AdaptiveCache(size_heuristic)) or SuggestCachingPolicy(f_pure_hot, DefaultLRUCache(size_heuristic));
        ```
	*   The `size_heuristic` for caches would be determined by factors like available memory, the cost of computing the function, and the frequency of calls.

					collection_var : HasSizeDistribution(D_size),
					Mean(D_size) > array_list_threshold_size, // If list expected to be large
					PerformanceModel(ArrayList, D_size) > PerformanceModel(LinkedList, D_size)
	⊢ SuggestRefactoring(collection_var, From=LinkedList, To=ArrayList);
```

## 5.4. Uncertainty Propagation and Management

Orbit must track how uncertainty (e.g., variance) evolves.

### 5.4.1. Tracking Variance
Variance is a key property of distributions, stored or derived via rules from Part 2, 3, and 4.

```orbit
// assign(y_var, a * x_expr + b)
// x_expr : D_x with Var(D_x)
// Rule implies: y_var : D_y with Var(D_y) = a^2 * Var(D_x)

// assign(z_var, x_expr + y_expr)
// x_expr : D_x, y_expr : D_y
// JointDist(x_expr, y_expr) is J_xy
// Rule implies: z_var : D_z with Var(D_z) = Var(D_x) + Var(D_y) + 2*Covariance(J_xy)
```
These are outcomes of the distribution derivation rules, not separate variance tracking rules.

### 5.4.2. Confidence Intervals
For critical computations, Orbit could derive confidence intervals.
```orbit
// output_var : D_output
Rule "Confidence Interval Annotation":
	critical_output(var_name)
		where var_name : D_var,
					lower_bound = Quantile(D_var, 0.025),
					upper_bound = Quantile(D_var, 0.975)
	⊢ var_name : HasConfidenceInterval95([lower_bound, upper_bound]);
```

### 5.4.3. Representing Approximations
When exact inference is intractable, approximations are used. These should be marked.
```orbit
// If D_approx is an approximation of D_true:
result_expr : D_approx : IsApproximation(ApproximationMethodUsed, ErrorMetricEstimate);
```
This domain tag `IsApproximation` allows downstream tools or developers to be aware of potential inaccuracies.

--- 

This chapter has demonstrated how Orbit's probabilistic framework can be integrated into program analysis. By systematically propagating distributions and using them to inform optimization heuristics, Orbit can unlock more nuanced and potentially powerful program transformations. The next and final chapter, **[Probability Part 6: Advanced Topics and Future Directions](./probability6.md)**, will explore more sophisticated concepts and avenues for future work in this domain.