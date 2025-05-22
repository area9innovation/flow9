# Automatic Differentiation in Orbit: Dense and Sparse

This document defines a set of Domain-Annotated Orbit rewrite rules to implement general automatic differentiation (AD) and automatic sparse differentiation (ASD) in the Orbit e-graph system. It covers pair representations `(value, derivative)`, chain-rule propagation, Jacobian/Hessian accumulation, sparsity pattern detection, coloring, and compressed evaluation.

## 1. Domains and Representations

```orbit
// Value domains
Value       ⊂ Domain

// Dense derivative types
GradScalar  ⊂ Vector<1>         // scalar gradient (length-1)
GradVector  ⊂ Vector<N>         // dense vector of length N
Jacobian    ⊂ Matrix<M,N>       // dense Jacobian M×N
Hessian     ⊂ Matrix<N,N>       // dense Hessian N×N

// Sparse derivative types (list of (i,v) pairs)
SparseVector⟦(Int,Value)⟧ : Sₙ : GradVector
SparseMatrix⟦(Int,Int,Value)⟧ : Sₙ : Jacobian

// Flags to prevent repeated processing
!: Differentiated
!: Sparsified

// Pair type for value+derivative bundles
Pair<V,D>   // shorthand for (V, D)
```  

## 2. Pair Representation and Entry Rules

```orbit
// Wrap a value into a pair with zero derivative
v : Value !: Differentiated → (v, zero(Dom)) : Pair<Value,Dom> : Differentiated
// `zero(Dom)` yields a zero vector/matrix or empty sparse map in `Dom`.
```  

## 3. Primitive Rewrite Rules

### 3.1 Constants and Variables
```orbit
// Constant c has zero derivative
const(c) : Value !: Differentiated → (const(c), zero(D)) : Pair<Value,Dom>

// Input variable x_i has unit derivative at index i
var(i, x) : Value !: Differentiated → (x, basis(i,N)) : Pair<Value,GradVector>
// `basis(i,N)` is Dense [0…1…0] or Sparse[(i,1)].
```  

### 3.2 Addition and Subtraction
```orbit
// Dense addition
(add u v) : Pair<V,GV> + Pair<V,GV> !: Differentiated → (
	u + v,
	merge_dense(GV_u, GV_v)
) : Pair<Value,GradVector>

// Sparse addition
(add u gu:SparseVector) + (v gv:SparseVector) !: Differentiated → (
	u+v,
	merge_sparse(gu, gv) : SparseVector
) : Pair<Value,SparseVector>

// Subtraction analogous
(sub u gu) - (v gv) → (u-v, merge(gu, scale(gv,-1)))
```  

### 3.3 Multiplication and Division
```orbit
// Dense multiplication (u* v)' = u'*v + u*v'
(mul u gu) * (mul v gv) → (
	u * v,
	merge_dense(scale_dense(gu, v), scale_dense(gv, u))
)

// Sparse multiplication
(mul u gu:S) * (mul v gv:S) → (
	u*v,
	merge_sparse(
	  scale_sparse(gu, v),
	  scale_sparse(gv, u)
	)
)

// Division (u/v)' = (u'*v - u*v')/v^2
(div u gu) / (div v gv) → (
	u/v,
	divide_dense(
	  merge_dense(scale(gu,v), scale(gv,-u)),
	  v*v
	)
)
```  

### 3.4 Power and Exponential
```orbit
// u^n, n constant integer
(pow u gu : Pair) → (
	u^n,
	scale_dense(gu, n*u^(n-1))
)

// exp, log, sin, cos, tanh, etc.
(exp u gu) → (exp(u), scale_dense(gu, exp(u)))
(log u gu) → (log(u), scale_dense(gu, 1/u))
(sin u gu) → (sin(u), scale_dense(gu, cos(u)))
(cos u gu) → (cos(u), scale_dense(gu, -sin(u)))
// ...
```  

### 3.5 N-ary Operations
```orbit
// Sum of list of Pairs
(sum [e1…eK]) : Pair !:Differentiated → (
	sum_i ui,
	merge_list([du_i])
) : Pair<Value,GradVector>

// Product of list
(prod [e1…eK]) → (
	prod_i ui,
	merge_list([scale(du_i, prod_j≠i uj)])
)
```  

## 4. Chain-Rule for Composite Functions

```orbit
// General composite function f(g(x))
(f (g x:Pair)) !: Differentiated → (
	f(u),
	scale(du_g, df/du at u)
)
// This matches `f` applied to the inner Pair, applies `f`'s derivative at the value.
```  

## 5. Vector and Matrix AD

### 5.1 Jacobian Accumulation (Dense)
```orbit
// Call f:ℝ^N→ℝ^M on vector of Pairs
(call f [(u1, g1)…(uN, gN)]) → (
	y:f(u1…uN),
	J = [∂f/∂ui]_{i=1..N} // merge each gi scaled by partials
)
```  

### 5.2 Hessian via Forward-over-Reverse
```orbit
// H := ∇² f, use JVP over VJP
function hessian(f, x)
	// 1. VJP to get gradient operator
	∇f(x)    = vjp(f, x)
	// 2. For each eᵢ or colored seeds, JVP(∇f, seed)
	H_rows   = [ jvp(∇f, seed_j) ]
	// 3. Assemble Hessian
	return stack(H_rows)
end
```  

## 6. Sparse Pattern Detection (Abstract Interpretation)

```orbit
// Represent each Pair's derivative component as an index-set type
(indexSeed (i)) → SparseVector([(i,1)]) : SparsityTag

// For add/mul/div
(add u idx_u) + (v idx_v) → merge_set(idx_u, idx_v)
(mul u idx_u) * (v idx_v) → merge_set(idx_u, idx_v) // any input participates
(sign u idx_u) → empty_set // no derivative → no indices
// ...
```  

## 7. Graph Coloring for Compression

```orbit
// Build graph G(columns, edges) where edges connect overlapping index-sets
PatternGraph[P] → Graph(cols, edges)

// Greedy coloring heuristic
coloring = greedy_color(Graph)
seeds[i] = sum(e_j for j where color(j)=i)

// Compressed derivative eval
(compressedJVP seeds) → outputs C_i

// Decompression rule
(decompress C_i with seeds) → assign entries back to matrix
```  

## 8. Illustrative Example: f(x,y,z)=x*y+sin(z)

```orbit
// Variables
x_i : var(0), y_j : var(1), z_k : var(2)

// Multiply
x * y → (x*y, [(0,y),(1,x)])
// sin
sin(z) → (sin(z), [(2,cos(z))])
// Add
add((x*y,..),(sin(z),..)) → (
	x*y+sin(z),
	[(0,y),(1,x),(2,cos(z))]
)
```  

## 9. Remarks

- **Sparsity**: Switching pair rules to SparseVector types yields ASD.  
- **Domain Guards**: `!:Differentiated` prevents infinite reapplication.  
- **Group Sₙ**: Sorting index-pairs ensures canonical order and merges.  
- **Extendibility**: Add new primitives by specifying their derivative rule and index-set abstraction.  
