# Modeling Relational Algebra with Orbit and O-Graphs

## 1. Introduction

Relational algebra provides the theoretical foundation for relational databases and query languages like SQL. It defines a set of operators for manipulating relations (tables). Optimizing relational algebra expressions (logical query plans) is crucial for database performance.

Orbit, with its O-Graph data structure and rewriting capabilities, offers a powerful framework for modeling, optimizing, and specializing relational algebra expressions. This document outlines how Orbit can represent relational algebra, implement standard optimizations, model the lower-level physical execution plans, handle practical database variants like MySQL, and incorporate profiling information for advanced, context-aware query specialization.

## 2. Representing Relational Algebra (Logical Plan)

We can represent relational algebra constructs as Orbit expressions. Relations can be represented by names or terms containing metadata, and operators become Orbit functions or custom operators.

### 2.1 Basic Constructs

*   **Relations (Tables)**: Represented as variables or constants (e.g., `Employees`, `Departments`). Metadata like schemas can be associated using domain annotations or dedicated terms.
    ```orbit
	// Representing a table schema via domain annotation
	Employees : Schema({id: int, name: string, deptId: int});
```
*   **Attributes**: Represented as strings or symbols (e.g., `name`, `salary`).
*   **Conditions**: Boolean expressions used in selection and joins (e.g., `salary > 50000`, `Employees.deptId == Departments.id`).

### 2.2 Relational Algebra Operators

Core operators can be represented as Orbit functions:

*   **Selection (σ)**: `select(condition, relation)`
    ```orbit
	// σ_{salary > 60000}(Employees)
	select(salary > 60000, Employees)
```
*   **Projection (π)**: `project([attribute1, attribute2, ...], relation)`
    ```orbit
	// π_{name, salary}(Employees)
	project([name, salary], Employees)
```
*   **Cartesian Product (×)**: `crossProduct(relation1, relation2)`
    ```orbit
	crossProduct(Employees, Departments)
```
*   **Join (⋈)**: `join(condition, relation1, relation2)` (Natural join can be a variant)
    ```orbit
	// Employees ⋈_{Employees.deptId == Departments.id} Departments
	join(Employees.deptId == Departments.id, Employees, Departments)
```
*   **Union (∪)**: `union(relation1, relation2)`
*   **Intersection (∩)**: `intersect(relation1, relation2)`
*   **Difference (-)**: `difference(relation1, relation2)`

These expressions form the basis of logical query plans that can be added to an O-Graph.

## 3. Optimization of Logical Plans using O-Graphs

Orbit's O-Graphs and rewriting engine (`orbit` function) can implement standard relational algebra optimizations through equality saturation.

1.  **Add Query to Graph**: An initial logical query plan (Orbit expression) is added using `addOGraph`.
2.  **Define Rewrite Rules**: Algebraic equivalences are defined as Orbit rewrite rules.
3.  **Equality Saturation**: The `orbit` function applies rules repeatedly, populating the O-Graph with equivalent logical plan variations.
4.  **Cost Function**: A cost function estimates the execution cost of different plan nodes in the O-Graph (initially based on logical structure, later refined for physical plans).
5.  **Extraction**: The `extractOptimal` function selects the lowest-cost plan from the saturated O-Graph.

### 3.1 Example Logical Optimization Rules

```orbit
fn quote(e: ast) = e;

let relationalAlgebraRules = quote(
	// 1. Push Selections down
	// σ_C(R ⋈_J S) <=> σ_CR(R) ⋈_J σ_CS(S)  (Simplified: assumes C splits cleanly)
	select(Condition, join(JoinCond, R, S)) <=>
		join(JoinCond, select(conditionFor(Condition, R), R), select(conditionFor(Condition, S), S));

	// σ_C1(σ_C2(R)) <=> σ_{C1 ∧ C2}(R)
	select(C1, select(C2, R)) <=> select(C1 and C2, R);

	// 2. Push Projections down (Simplified)
	// π_A(σ_C(R)) <=> σ_C(π_{A ∪ Attrs(C)}(R))
	project(Attrs, select(Cond, R)) <=>
		select(Cond, project(union(Attrs, attributesOf(Cond)), R));

	// 3. Combine Projections
	// π_A1(π_A2(R)) <=> π_A1(R)
	project(A1, project(A2, R)) <=> project(A1, R);

	// 4. Join Reordering (if join is commutative and associative)
	// Assuming join operator has S₂ and Associative properties defined via other rules
	join(C1, R, S) : S₂ <=> join(C1, S, R);
	join(C1, R, join(C2, S, T)) : Associative <=> join(C2, join(C1, R, S), T);

	// 5. Convert Cross Product + Select to Join
	select(Condition, crossProduct(R, S)) <=> join(Condition, R, S);
);


// Using the orbit function for logical optimization
// Extraction relies on canonical forms, not an explicit cost function here.
fn optimizeLogicalQuery(queryPlan: ast) -> ast = (
	orbit(relationalAlgebraRules, queryPlan)
);
```

The O-Graph effectively stores many equivalent logical query plans.

## 4. Modeling Physical Query Plans

While the logical plan defines *what* operations to perform, the **physical plan** defines *how* to execute them using specific algorithms and data access methods (e.g., hash join vs. merge join, table scan vs. index scan). Orbit can model this level effectively.

### 4.1 Representing Physical Operators

Define Orbit terms for specific physical algorithms:

*   `hashJoin(condition, buildInput, probeInput)`
*   `nestedLoopJoin(condition, outerInput, innerInput)`
*   `indexNestedLoopJoin(condition, outerInput, innerInput, index)`
*   `mergeJoin(condition, leftInput:Sorted, rightInput:Sorted)` (Note domain annotation for required properties)
*   `tableScan(tableName, filterCondition)`
*   `indexScan(tableName, indexName, keyCondition)`
*   `indexOnlyScan(tableName, indexName, keyCondition)`
*   `sort(input, sortKeys)`
*   `hashAggregate(groupKeys, aggregates, input)`
*   `streamAggregate(groupKeys, aggregates, input:Sorted)`
*   `materialize(input)` (Force intermediate result storage)
*   `exchange(input, distribution)` (For distributed systems)

### 4.2 Domain Annotations for Physical Properties

Domain annotations are crucial for guiding physical plan selection:

*   **Data Properties:** Mark inputs/outputs with properties required or guaranteed by operators (e.g., `:Sorted(columnA)`, `:Partitioned(columnB)`, `:HashTable`).
*   **Algorithm Variants:** Differentiate variations (e.g., `:BuildSide(left)`, `:GraceHashJoin`).
*   **Cost Estimates:** Attach detailed estimated costs (CPU, I/O, memory) based on the algorithm and profile data (`:Cost(cpu=100, io=50, mem=200)`).
*   **Resource Usage:** Annotate potential memory usage or temporary storage needs.
*   **Implementation Details:** Mark plans specific to storage engines (`:InnoDB`, `:MyISAM`) or database versions.
*   **Index Availability:** Mark relations or conditions (`:HasIndex(col)`, `:UsesIndex(col)`).

### 4.3 Logical-to-Physical Rewrite Rules

These rules translate logical operators into possible physical implementations, often considering data properties, indexes, and statistics (represented via domains).

```orbit
let logicalToPhysicalRules = quote(
	// Join -> Hash Join (Default for large inputs)
	join(C, R, S) : LogicalPlan, R:Size(large), S:Size(large)
		=> hashJoin(C, R, S) : PhysicalPlan : Cost(...); // Cost placeholder

	// Join -> Index Nested Loop Join (If index available on inner side's join key)
	join(R.id = S.fk, R, S) : LogicalPlan, S : HasIndex(fk)
		=> indexNestedLoopJoin(R.id = S.fk, R, S, "idx_fk") : PhysicalPlan : UsesIndex(fk) : Cost(...);

	// Join -> Merge Join (If inputs are already sorted on join keys)
	join(R.key = S.key, R:Sorted(key), S:Sorted(key)) : LogicalPlan
		=> mergeJoin(R.key = S.key, R, S) : PhysicalPlan : Cost(...);

	// Select -> Table Scan (No suitable index)
	select(C, R) : LogicalPlan, R !: HasIndexFor(C) // HasIndexFor is a conceptual check
		=> tableScan(R, filter=C) : PhysicalPlan : Cost(...);

	// Select -> Index Scan (Index available for the condition)
	select(R.indexedCol = val, R) : LogicalPlan, R : HasIndex(indexedCol)
		=> indexScan(R, "idx_indexedCol", R.indexedCol = val) : PhysicalPlan : Cost(...);

	// Aggregate -> Hash Aggregate (Default)
	aggregate(keys, funcs, R) : LogicalPlan
		=> hashAggregate(keys, funcs, R) : PhysicalPlan : Cost(...);

	// Aggregate -> Stream Aggregate (If input is sorted by group keys)
	aggregate(keys, funcs, R:Sorted(keys)) : LogicalPlan
		=> streamAggregate(keys, funcs, R) : PhysicalPlan : Cost(...);
);
```

### 4.4 Physical-to-Physical Rewrite Rules

Optimize within the physical plan itself, refining algorithm choices or properties.

```orbit
let physicalOptimizationRules = quote(
	// Reorder build/probe side of Hash Join based on estimated sizes (cardinality)
	hashJoin(C, R:Cardinality(N), S:Cardinality(M)) : PhysicalPlan, N < M
		=> hashJoin(C, R, S) : BuildSide(R) : Cost(...); // Prefer smaller build side
	hashJoin(C, R:Cardinality(N), S:Cardinality(M)) : PhysicalPlan, M <= N
		=> hashJoin(C, S, R) : BuildSide(S) : Cost(...); // Swapped order, S is build side

	// Introduce explicit Sort if Merge Join requires it but input isn't sorted
	mergeJoin(C, R, S) : PhysicalPlan, R !: Sorted(key), S : Sorted(key)
		=> mergeJoin(C, sort(R, key), S) : PhysicalPlan; // Added sort on R

	// Combine adjacent sorts if keys are compatible
	sort(sort(Input, Keys1), Keys2) : PhysicalPlan <=> sort(Input, combineKeys(Keys1, Keys2));

	// Rule to enforce a specific physical operator based on a hint or profile
	hashJoin(C, R, S) : PhysicalPlan, R : Profile("prefer_nl_join")
		=> nestedLoopJoin(C, R, S) : PhysicalPlan : Cost(...); // Force NL join based on profile
);
```

### 4.5 O-Graph Saturation and Cost-Based Extraction (Physical Level)

*   The O-Graph can hold multiple competing physical plan fragments for the same logical operation.
*   Saturation explores various physical implementations and their combinations by applying both logical-to-physical and physical-to-physical rules.
*   The cost function becomes critical, evaluating the estimated cost attached via domain annotations (`:Cost(...)`) to each physical node.
*   Extraction uses the canonical form representative, guided by domain annotations.

### 4.6 Combining Levels

You can model both logical and physical levels within the same O-Graph. Rules transform logical nodes into physical ones, existing alongside purely logical equivalences. Alternatively, optimization can be phased:
1. Optimize the logical plan using `relationalAlgebraRules`.
2. Extract the best logical plan.
3. Start a new saturation phase from that logical plan using `logicalToPhysicalRules` and `physicalOptimizationRules` to find the best physical plan.

The phased approach often simplifies rule writing and cost modeling.

## 5. Modeling MySQL Specifics

Real-world databases like MySQL have specific operators, functions, storage engine behaviors, and indexing capabilities not covered by pure relational algebra or generic physical plans. Orbit's domain annotations can model these specifics.

*   **Distinguish Domains**: Use domains like `:PureAlgebra`, `:MySQL`, `:InnoDB`, `:MyISAM`, `:MySQL_8_0`.
*   **MySQL-Specific Operators/Functions**: Represent MySQL functions (e.g., `DATE_FORMAT`, `GROUP_CONCAT`) and annotate them with `:MySQL`.
*   **Index Information**: Annotate relations or conditions with index availability (`:HasIndex(deptId)`). Use physical operators like `indexScan` which explicitly mention indexes.
*   **MySQL-Specific Rules**: Write rules that translate from generic physical plans to MySQL-specific plans or implement MySQL-specific optimizations/heuristics.

```orbit
let mysqlRules = quote(
	// Prefer MySQL's specific index join implementation if available
	indexNestedLoopJoin(C, R, S, Idx) : PhysicalPlan
		=> mysqlIndexJoin(C, R, S, Idx) : MySQL : Cost(...);

	// Translate standard aggregate to MySQL syntax if targeting MySQL
	hashAggregate(groupAttrs, avg(salary), R) : PhysicalPlan
		=> mysql_aggregate(groupAttrs, AVG(salary), R) : MySQL;

	// Rule to handle specific MySQL storage engine behavior
	tableScan(R, filter=C) : PhysicalPlan, R : StorageEngine(MyISAM)
		=> myisamTableScan(R, filter=C) : MySQL : Cost(...); // Potentially different cost
);
```

By combining generic rules with MySQL-specific rules, Orbit can optimize queries considering both general algorithms and practical MySQL capabilities.

## 6. Profiling-Guided Optimization (PGO)

Database performance often depends heavily on data characteristics (sizes, cardinalities, value distributions) and query patterns (frequency of specific predicates). Orbit can incorporate this profiling data to create highly specialized query plans.

### 6.1 Representing Profile Data

Profile data can be added to the O-Graph as distinct terms or as domain annotations on existing nodes.

```orbit
// Option 1: Profile data as separate nodes linked via domains
let g = makeOGraph("query_optimization_pgo");
// Add profile data nodes
let profile_Employees_card = addOGraph(g, quote(ProfileData(table="Employees", cardinality=1000000)));
let profile_Empl_deptId_5_selectivity = addOGraph(g, quote(ProfileData(table="Employees", predicate="deptId=5", selectivity=0.01)));
// Add relation node
let employees_node = addOGraph(g, quote(Employees));
// Link relation node to profile data
addDomainToNode(g, employees_node, profile_Employees_card);

// Option 2: Profile data directly as domains
let g = makeOGraph("query_optimization_pgo");
let employees_node = addOGraph(g, quote(Employees));
// Add profile domains directly to the relation node
addDomainToNode(g, employees_node, quote(:Cardinality(1000000)));
addDomainToNode(g, employees_node, quote(:Selectivity(deptId=5, 0.01)));

// Add query node
let query_node = addOGraph(g, quote(select(deptId = 5, Employees)));
// Link query node to relevant profile (can be inferred or explicitly linked)
// e.g., addDomainToNode(g, query_node, quote(:UsesProfile(predicate="deptId=5")));

```

### 6.2 Profile-Aware Rewrite Rules

Rewrite rules (especially logical-to-physical and physical-to-physical) can match on these profile domain annotations to choose specialized execution strategies or refine cost estimates.

```orbit
let profileAwareRules = quote(
	// Choose Join algorithm based on profiled cardinality and selectivity
	join(R.id = S.fk, R:Cardinality(N), S:Cardinality(M)) : LogicalPlan,
		 R : Selectivity(id=val, sel_R), S : Selectivity(fk=val, sel_S),
		 (N * sel_R < Threshold) // Check if expected result after selection on R is small
		=> nestedLoopJoin(R.id = S.fk, select(id=val, R), S) : PhysicalPlan : Cost(...); // Prefer NL if one side is small after filtering

	// Refine cost estimate based on profile data
	tableScan(R, filter=C) : PhysicalPlan, R : Cardinality(N), R : Selectivity(C, sel)
		=> tableScan(R, filter=C) : PhysicalPlan : Cost(cpu=..., io=N*sel*blockSize, ...); // Update cost annotation

	// Force a specific plan based on frequent query pattern profile
	select(deptId = 5, Employees) : LogicalPlan,
		Employees : Profile(query="select(deptId=5, Employees)", frequency="high", bestPlan="indexScan_deptId")
		=> indexScan(Employees, "idx_deptId", deptId = 5) : PhysicalPlan : ForcedByProfile;
);
```

This allows the O-Graph to contain multiple specialized plans optimized for different data characteristics or query patterns. Profile data may influence which canonical form is selected as the representative for an e-class, but extraction itself follows the canonical representative.

## 7. Conclusion

Orbit provides a flexible and powerful framework for modeling and optimizing relational databases, spanning both logical and physical query plan levels. By leveraging O-Graphs for representing equivalent query plans and using domain annotations with rewrite rules, Orbit can:

*   Implement standard logical algebraic optimizations.
*   Explore various physical execution strategies (join algorithms, access methods).
*   Refine physical plans based on data properties and resource constraints.
*   Model and optimize for specific database systems like MySQL.
*   Incorporate detailed profiling information to generate highly specialized and efficient query plans tailored to specific data distributions and access patterns.

This unified approach bridges the gap between theoretical relational algebra, practical database implementation details, and data-driven performance tuning, offering a promising direction for advanced query optimization research and implementation.
