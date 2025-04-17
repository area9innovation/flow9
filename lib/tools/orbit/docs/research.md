- **Graph canonical labeling & automorphism**  
  - **nauty & Traces**: C libraries for graph/digraph automorphism groups and canonical labeling, with companion “gtools” programs for graph generation and manipulation citeturn1search0turn1search11.  
  - **Bliss**: Open‑source C++ tool focusing on conflict‑propagation and component recursion for fast canonical labeling and automorphism computation citeturn0search0.  
  - Others in this space include **saucy**, **conauto**, **GI‑EXT**, and **VSEP** citeturn1search11.

- **Finite group & form canonicalization**  
  - **GAP** with the **Forms** package: computes canonical representatives of sesquilinear and quadratic forms (IsometricCanonicalForm) within classical groups citeturn0search1turn0search6.  

- **Polynomial & ideal bases**  
  - **Singular**: `groebner()` and related routines compute Gröbner (standard) bases, yielding canonical remainders for polynomial ideals citeturn0search2turn0search7.  
  - **CoCoA**, **Macaulay2** and **SageMath** similarly provide multiple algorithms for canonical Gröbner bases.

- **Matrix canonical forms**  
  - **Maple**: `JordanCanonicalForm` / `Canonicalize` commands for Jordan form and Boolean normal forms citeturn0search3turn0search8.  
  - **Mathematica**: `JordanDecomposition` for Jordan form; `BooleanConvert` for CNF/DNF/etc. citeturn2search1turn2search2.  
  - Numeric libraries (e.g. SciPy/NumPy) offer eigendecompositions and Jordan routines.

- **Boolean & logical normal forms**  
  - **SymPy**: `to_anf`, `SOPform`/`POSform` for algebraic, conjunctive/disjunctive normal forms; automatic simplification to canonical expression trees citeturn0search9.  

- **Tensor index canonicalization**  
  - **SymPy’s** `tensor_can` module: computes canonical index orderings under slot symmetries and dummy permutations citeturn0search4.

- **General‑purpose computer algebra systems**  
  - **Maple**, **Mathematica**, **SageMath**, **Magma**, and **SymPy** more broadly expose routines for canonical forms of expressions, matrices, polynomials, logical formulas, differential equations, etc. citeturn0search3turn0search9.

Each of these systems targets one or more data‑structure families (graphs, groups, rings, matrices, tensors, Boolean algebras), often via highly optimized specialized algorithms.