Start from sources in the graph, following supertypes out from the nodes. We can safely assume there are no cycles in the graph, but it is a DAG.If the node is a tyvar, then compare the incoming subtypes from the previous nodes with the subtypes of our node and keep only the biggest, prefering the direct subtypes. If our node has multiple identical ones that are biggest, keep all. Use can use 
    // Finds the Least Upper Bound (LUB) of these two types, preferring the first if equal.
    // If none exist, the constructor has an empty name.
    findConsLub(g : EGraph, cons1 : Constructor, cons2 : Constructor, infos : Set<int>) -> Constructor;
    // The same for Greatest Lower Bound (GLB)
    findConsGlb(g : EGraph, cons1 : Constructor, cons2 : Constructor, infos : Set<int>) -> Constructor;

for this purpose. Once we have the LUB, send it up to all supertypes and continue the process. Since we have a dag, it is fine to process the same node multiple times, each time combining to have an updated LUB reflecting the transitive subtypes.
Once we have the LUB, then we can check if it has any supertypes 
    // Does this name have a subtype? I.e. are we a union
    canHaveSubtype(g : EGraph, name : string) -> bool;
    // Does this name have a supertype? I.e. are we in a union
    canHaveSupertype(g : EGraph, name : string) -> bool;

If it can not have any supertype, we know it is a unique solution, and we can unify with the lub to resolve it. Then we can send this along as the LUB to the supertypes.
If the node is a cons, then propagate that as the subtype to the outgoing nodes.
If the node is a fn, then stop propagation.

Similarly, do the symmetrical thing from the sinks of the graph, collecting GLBs. Notice that when we go from the supertypes down, we can also use the subtypes as an upper bound in case there is no upperbound.
Similarly, if a GLB does not have any subtypes, we know it is a solution, and can unify with that.
Also, if the LUB and GLB for a node matches, we also know this is a solution, and can unify that.
If they do not match, we can not resolve it yet, so ignore the node.



# Type Unification with Bounds

## Overview
This specification describes how to process type unifications to find solutions for type variables by tracking and refining bounds. The type system has subtyping as well as overloading, i.e. alternatives. The goal is to find a consistent solution for all type variables.

For example, we might have these unifications:

``` flow
a1 <: a2
Some<int> <: a3 <: Maybe<a1>
```

and we have to find the tighest bounds for `a1`, `a2`, `a3` that satisfy all constraints.
In this case, a1 and a2 can be inferred to be `int`, and a3 can be either `Some<int>` or `Maybe<int>`. We prefer the subtype, so we should pick `Some<int>`.

## Assumptions

We know there are no cycles in the unification graph.

# **Specification: Constraint-Based Type Resolution in a Directed Acyclic Graph (DAG)**

## **1. Problem Definition**
We are given a **directed acyclic graph (DAG)** representing subtyping constraints between **type variables** and **type constructors**. Each node in the graph represents either:
1. A **Type Variable** \( T_i \), which must be resolved to a specific type.
2. A **Type Constructor** \( C_k \), which is a concrete type in the system.

Edges represent subtyping constraints:
- An edge \( A \to B \) means that \( A \) is a subtype of \( B \).

The goal is to resolve as many **type variables** as possible, ensuring correctness by considering only **local constraints** when possible and **falling back to an exhaustive search only when necessary**.

---

## **2. Properties of the Constraint Graph**
1. **Directed & Acyclic:** The graph is a DAG, meaning that all dependencies have a strict ordering.
2. **Types are Partially Ordered:** Each type variable is constrained by its subtypes and supertypes.
3. **No Cycles:** If cycles existed, they would indicate that the involved types must unify, but our graph structure avoids this.
4. **Local Resolution is Preferred:** A type should be resolved whenever possible using only direct constraints, without considering transitive information unless necessary.
5. **Exhaustive Search Only When Required:** If no further resolution is possible through direct constraints, we resort to an exhaustive search over remaining possibilities.

---

## **3. Resolution Criteria**
A type variable \( T_i \) is **resolvable** if:
1. **It has a unique solution based on direct constraints.**  
   - If \( T_i \)'s subtypes have a **unique least upper bound (LUB)** that has no further supertypes.  
   - If \( T_i \)'s supertypes have a **unique greatest lower bound (GLB)** that has no further subtypes.  
   - If the intersection of \( T_i \)'s subtypes and supertypes results in a single valid type.

2. **It is not indirectly affected by unresolved variables.**  
   - Resolution should be performed when all necessary constraints are locally available.  
   - Merge points (confluence points) should not introduce uncertainty.

3. **When resolution is ambiguous, we defer solving until necessary.**  
   - If multiple valid solutions exist, the node remains unresolved until an exhaustive search is required.

---

## **4. Algorithm Design**
The algorithm follows a **progressive approach**, resolving as many nodes as possible deterministically before resorting to exhaustive search.

### **4.1 Data Structures**
- **`possibleTypes[node]`** → A set of all possible types for each node.
- **`resolved[node]`** → A mapping of resolved nodes to their assigned types.
- **`subs[node]`** → Direct subtype constraints (set of immediate subtypes).
- **`supers[node]`** → Direct supertype constraints (set of immediate supertypes).

---

### **4.2 Phase 1: Initialize Possible Types**
For each **type variable** \( T_i \):
- Compute its **set of possible types** from:
  - **Subtypes:** Compute the least upper bound (LUB) of all known subtypes.
  - **Supertypes:** Compute the greatest lower bound (GLB) of all known supertypes.
- If there is only one valid type, resolve it immediately.

---

### **4.3 Phase 2: Iterative Deterministic Resolution**
While there are unresolved nodes:
1. **Find all uniquely resolvable nodes** \( T_i \):
   - If `possibleTypes[T_i]` has exactly **one** element, assign that type.
   - Remove \( T_i \) from the graph and update constraints on remaining nodes.

2. **Propagate newly resolved constraints**:
   - If a resolved type affects another node's subtype or supertype constraints, update `possibleTypes` accordingly.
   - If this update results in another uniquely resolvable type, continue resolving.

3. **Repeat until no more nodes can be resolved directly.**

---

### **4.4 Phase 3: Handling Stuck Nodes**
If some nodes remain unresolved:
- Identify nodes where `possibleTypes[node]` has multiple candidates.
- Prioritize nodes with **the smallest number of remaining options** (minimizing search space).

---

### **4.5 Phase 4: Exhaustive Search**
For unresolved nodes:
1. **Select the node \( X \) with the fewest possible solutions.**
2. **Try each candidate type for \( X \), propagating constraints:**
   - Assign a type from `possibleTypes[X]`.
   - Update constraints for related nodes.
   - Check if this assignment creates contradictions.
   - If a contradiction arises, **backtrack** and try the next candidate.
3. **Repeat until all nodes are resolved or no solution is found.**

---

## **5. Termination and Correctness**
1. **Guarantees Resolution When Possible:**  
   - If a valid assignment of types exists, the exhaustive search will find it.
2. **Avoids Premature Assumptions:**  
   - Direct resolution is only performed when unambiguous.
3. **Minimizes Unnecessary Search:**  
   - The algorithm first attempts a deterministic approach, reducing the number of nodes requiring exhaustive search.
4. **Graph Structure Ensures Progress:**  
   - Since the graph is a DAG, there is always at least one node that can be resolved or explored.

---

## **6. Example Execution**
### **Input Graph**
```
  T1 → T2 → T3
  T1 → C1
  T2 → C2
  T3 → C3
```
Where:
- \( C1, C2, C3 \) are **concrete types**.
- \( T1, T2, T3 \) are **type variables**.

### **Resolution Steps**
1. Initialize `possibleTypes`:
   ```
   possibleTypes[T1] = {C1}
   possibleTypes[T2] = {C2}
   possibleTypes[T3] = {C3}
   ```
   - Since `possibleTypes[T1]` contains **only C1**, resolve **T1 = C1**.
   - Since `possibleTypes[T2]` contains **only C2**, resolve **T2 = C2**.
   - Since `possibleTypes[T3]` contains **only C3**, resolve **T3 = C3**.

2. **All nodes resolved without search.**

---

## **7. Worst-Case Complexity**
- **Best Case:** \( O(n) \) (All nodes resolve iteratively)
- **Worst Case:** \( O(2^k) \) (Exhaustive search over \( k \) nodes with multiple candidate types)

In practice, the exhaustive search is only necessary when a type variable remains ambiguous after all deterministic resolution steps.

---

## **8. Summary**
This approach systematically resolves type constraints by:
1. **Prioritizing local deterministic resolution** to avoid unnecessary complexity.
2. **Propagating constraints efficiently** to iteratively reduce ambiguity.
3. **Falling back on exhaustive search only when required**, ensuring correctness without relying on heuristics.

By structuring the resolution in **stages**, we ensure **maximum efficiency**, solving most cases without search and handling complex cases with minimal computational effort.