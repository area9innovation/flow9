# Automatic FFT Derivation Through Orbit's Group-Theoretic Rewrites

## Introduction

The Discrete Fourier Transform (DFT) and its fast implementation, the Fast Fourier Transform (FFT), represent a perfect case study for Orbit's group-theoretic approach to algorithm discovery. This document demonstrates how Orbit can automatically derive the FFT from the DFT definition by identifying and exploiting mathematical symmetries, without explicitly encoding the FFT algorithm.

The standard DFT has O(N²) complexity, while the FFT achieves O(N log N) when N is a power of 2. This exponential speedup is one of the most important algorithmic improvements in computing history. Rather than treating FFT as a separate algorithm, we show how it emerges naturally through the application of algebraic rewrites to the DFT when certain divisibility conditions are met.

TODO:
To get this implemented in a general way, we need:
- Evaluation in the ograph world
- Managing an enviornment in the graph, so we can lift fn(x) in sums out in specialized forms: dft(x,n) = sum(k, sum(j, x[j]*twiddle(n, j, k))). This has to be rewritten so the index is the single argument of the inner term, so we can spot the sum pattern. I.e. we have to extract a function of the j variable, and then an env with n, k and x. The same with the sum, where we have to lift x & n out to the env.
- An env requires a binary tree in the ograph space?
- Extraction rules for isolating a variable and putting the rest in the env
- Inline back to normal code.

## Expressing DFT in Orbit

We begin by expressing the DFT in Orbit's domain-specific language:

```orbit
// Define domains for DFT operations
DFT ⊂ LinearTransform
TwiddleFactor ⊂ ComplexExponential
Summation ⊂ LinearOperation

// Define complex exponential twiddle factors
W_N^k : TwiddleFactor → exp(-i*2*π*k/N) : C_N; // C_N denotes the cyclic group of order N

// Define DFT in terms of twiddle factors
dft(x, N, k) : DFT → sum(j, 0, N-1, x[j] * W_N^(j*k)) : Summation;

// The full transform for all output indices
dft(x, N) : DFT → [dft(x, N, k) for k = 0 to N-1] : Transform;
```

This representation explicitly connects the DFT to the cyclic group C_N through the twiddle factors, which Orbit can exploit to discover symmetries.

## The Key Insight: Divide-and-Conquer Through Group Theory

The critical insight enabling the FFT is recognizing how the DFT can be split when N is divisible by certain factors. Instead of encoding this division directly, we express it through algebraic rewrites that Orbit can discover:

```orbit
// The foundational insight: Split DFT sum into even and odd indices
dft(x, N, k) : DFT !: Split → (
	sum(j, 0, N/2-1, x[2*j] * W_N^(2*j*k)) + 
	sum(j, 0, N/2-1, x[2*j+1] * W_N^((2*j+1)*k))
) : Split if can_split_indices(N);

// Define the condition for splitting: N must be even
can_split_indices(N) → eval(N % 2 == 0);
```

This rewrite captures the essential divide step: separating the sum into two parts based on whether the index j is even or odd. The `!: Split` negative guard ensures this rule only applies once to prevent infinite recursion.

## Exploiting Symmetries in Twiddle Factors

Next, we identify the critical symmetry patterns in the twiddle factors that make the FFT efficient:

```orbit
// Recognize that W_N^(2*j*k) = W_{N/2}^(j*k)
W_N^(2*j*k) : TwiddleFactor → W_{N/2}^(j*k) : TwiddleFactor; 

// And that W_N^((2*j+1)*k) = W_N^k * W_N^(2*j*k)
W_N^((2*j+1)*k) : TwiddleFactor → W_N^k * W_N^(2*j*k) : TwiddleFactor;
				→ W_N^k * W_{N/2}^(j*k) : TwiddleFactor;
```

These rewrites leverage the cyclic group structure (C_N) of the twiddle factors, allowing us to recognize patterns that would otherwise be hidden in the complex exponentials.

## Automatic Discovery of Algebraic Identities

While previous sections showed how specific identities enable FFT optimization, Orbit can systematically discover these identities in the first place. The system could leverage its algebraic rewriting capabilities to automatically find the patterns that lead to algorithmic improvements.

### Systematic Identity Exploration

```orbit
// Define an automatic identity discovery process for expressions with group structure
DiscoverIdentities(expr : GroupStructured) : Analysis → {
  // Analyze the structure of the expression
  group = detect_group_structure(expr);
  
  group is {
    // For cyclic groups, systematically explore transformations
    C_N => {
      // Check periodicity identities
      verify_identity(expr(x + N) = expr(x)) : Periodicity;
      
      // For even N, check half-period identities
      if N % 2 == 0 then
        verify_identity(expr(x + N/2) = f(expr(x))) : HalfPeriod;
      
      // For composite N, check decomposition by factors
      factors = get_factors(N);
      for factor in factors:
        verify_identity(expr(factor * x) = g(expr(x))) : FactorRelation;
    };
    
    // For multiplicative groups (Z/NZ)*, check structural properties
    MultGroup => {
      if is_prime(N) then {
        // Check for primitive roots 
        root = find_primitive_root(N);
        verify_identity(all non-zero elements = {root^k mod N | k=0...N-2}) : PrimitiveRoot;
      };
    };
  };
}
```

### Leveraging Orbit's Domain Annotation System

The true power of Orbit for identity discovery comes from its domain annotation system. By propagating algebraic properties from basic expressions to complex ones, Orbit can transfer group-theoretic knowledge:

```orbit
// Define propagation rules for group properties
W_N^x : C_N, W_N^y : C_N ⊢ W_N^(x+y) : C_N;  // Closure under addition in exponent
W_N^x : C_N, W_M^y : C_M, N divides M ⊢ (W_N^x = W_M^(M/N * x)) : Embedding;  // Subgroup relations

// When an expression has cyclic group structure, try specific rewrites
expr : C_N !: Analyzed → analyze_cyclic_structure(expr) : Analyzed;

// Automatically recognize odd/even patterns in arguments
f(2*n) : Pattern ⊢ pattern_kind = "even";
f(2*n+1) : Pattern ⊢ pattern_kind = "odd";

// Leverage pattern detection for systematic rewriting
sum(j, 0, N-1, expr(j)) : Summation, Pattern = "splittable" →
  sum(j, 0, N/2-1, expr(2*j)) + sum(j, 0, N/2-1, expr(2*j+1)) : SplitSum;
```

### Automatic Derivation of Critical FFT Identities

```orbit
// Automatic derivation of the core FFT identity
deriveIdentity(W_N^(j*k)) → {
  // Substitute j = 2m (even)
  W_N^(2*m*k) : TwiddleFactor → expand(W_N^(2*m*k))
                            → exp(-i*2*π*2*m*k/N)
                            → exp(-i*2*π*m*k/(N/2))
                            → W_{N/2}^(m*k);
  
  // Verify the identity algebraically
  if verify_algebraic(W_N^(2*m*k) = W_{N/2}^(m*k)) then
    register_identity("cooley_tukey_even", W_N^(2*j*k) = W_{N/2}^(j*k));
  
  // Similarly for odd indices...
};
```

### Generalizing to Other Summations

This approach extends beyond FFT to any summation with similar group-theoretic properties:

```orbit
// General pattern for summations with kernel functions that have group structure
AnalyzeSummation(sum(i, 0, N-1, x[i] * kernel(i, params...)) : Summation) → {
  // Identify the algebraic structure of the kernel
  kernel_structure = identify_structure(kernel);
  
  // For kernels with cyclic group properties
  if has_property(kernel_structure, "cyclic") then {
    // Check if the sum can be split recursively
    if N % 2 == 0 then
      try_transform("split_even_odd", sum);
      
    // For prime N, try reindexing transformations
    if is_prime(N) then
      try_transform("reindex_via_primitive_root", sum);
      
    // Look for convolution patterns
    try_transform("convert_to_convolution", sum);
  };
};
```

Using this framework, Orbit could automatically discover optimizations for transforms like:

1. **Walsh-Hadamard Transform**: sum(j, 0, N-1, x[j] * (-1)^(bit_count(j&k)))
2. **Number Theoretic Transform**: sum(j, 0, N-1, x[j] * r^(j*k mod p))
3. **Hartley Transform**: sum(j, 0, N-1, x[j] * (cos(2πjk/N) + sin(2πjk/N)))

The symmetry patterns in these transforms include:

```orbit
// Example pattern discovery for Walsh-Hadamard kernel
(-1)^(bit_count((2*j) & k)) : WalshKernel →
  (-1)^(bit_count(j & (k/2))) if k % 2 == 0 : EvenPattern;

// Pattern discovery for Number Theoretic Transform kernel
r^((2*j)*k mod p) : NTTKernel →
  (r^2)^(j*k mod p) : SquaredBasePattern;
```

### Practical Applications

The same principles apply to many practical computational tasks with hidden algebraic structure:

```orbit
// Matrix multiplication with Strassen-like decomposition
matrix_multiply(A, B) : MatrixOperation !: Optimized, is_large_enough(A, B) →
  discover_block_decomposition(A, B) : Optimized;

// Multi-dimensional signal processing
md_transform(data, dims) : NDTransform !: Factorized →
  discover_separable_structure(data, dims) : Factorized;

// Graph algorithms with algebraic structure
graph_operation(G) : GraphAlgorithm, has_symmetry(G) →
  exploit_symmetry_structure(G) : OptimizedAlgorithm;
```

This generalized approach to automatic identity discovery is what makes Orbit powerful - rather than encoding specific optimizations, the system can derive them from first principles by understanding the underlying mathematical structure.

## Deriving the FFT's Divide Step

We can now rewrite the split DFT using these twiddle factor identities:

```orbit
// Apply twiddle factor symmetries to rewrite the split sum
dft(x, N, k) : Split !: Factored → (
	sum(j, 0, N/2-1, x[2*j] * W_{N/2}^(j*k)) + 
	W_N^k * sum(j, 0, N/2-1, x[2*j+1] * W_{N/2}^(j*k))
) : Factored;

// Recognize that these sums are DFTs of the even and odd subsequences
sum(j, 0, N/2-1, x[2*j] * W_{N/2}^(j*k)) : Summation → dft(x_even, N/2, k) : DFT
	where x_even[j] = x[2*j];

sum(j, 0, N/2-1, x[2*j+1] * W_{N/2}^(j*k)) : Summation → dft(x_odd, N/2, k) : DFT
	where x_odd[j] = x[2*j+1];

// Combine these recognitions into the key FFT divide step
dft(x, N, k) : Factored !: DivideStep → (
	dft(x_even, N/2, k) + W_N^k * dft(x_odd, N/2, k)
) : DivideStep;
```

This is the heart of the FFT algorithm - expressing a size-N DFT in terms of two size-N/2 DFTs. The beauty is that Orbit discovers this pattern through algebraic rewrite rules rather than explicit algorithm coding.

## Optimizing the Second Half of Outputs

Another key insight of the FFT is that we can reuse computations for the second half of the output indices (k ≥ N/2):

```orbit
// Recognize periodicity in twiddle factors: W_N^(k+N/2) = -W_N^k
W_N^(k+N/2) : TwiddleFactor → -W_N^k : TwiddleFactor;

// Apply this to optimize the divide step for k+N/2
dft(x, N, k+N/2) : DFT !: SecondHalf → (
	dft(x_even, N/2, k) - W_N^k * dft(x_odd, N/2, k)
) : SecondHalf if k < N/2;
```

This rewrite exploits the periodicity property of twiddle factors, allowing us to compute the second half of outputs with minimal additional work - a key optimization in the FFT.

## Combining Results and Recursive Application

We can now combine these insights to express the full DFT-to-FFT transformation:

```orbit
// Complete FFT butterfly pattern for all indices
dft(x, N) : DFT !: Complete → [
	// First half: k = 0 to N/2-1
	for k = 0 to N/2-1: dft(x_even, N/2, k) + W_N^k * dft(x_odd, N/2, k),
	
	// Second half: k = N/2 to N-1
	for k = 0 to N/2-1: dft(x_even, N/2, k) - W_N^k * dft(x_odd, N/2, k)
] : Complete if can_split_indices(N);

// Base case for recursion
dft(x, 1, 0) : DFT → x[0];
```

The power of this approach is that these same rewrite rules will recursively apply to the smaller DFTs, automatically generating the full FFT butterfly structure when N is a power of 2. No explicit recursion needs to be encoded - it emerges naturally from repeated rule application.

## Generalization to Non-Power-of-2 Sizes

The approach isn't limited to powers of 2. We can generalize to any composite N by recognizing factors:

```orbit
// Generalized splitting for any factor p of N
dft(x, N, k) : DFT !: FactorSplit → (
	sum(r=0 to p-1, W_N^(r*k) * dft(x_r, N/p, k))
) : FactorSplit if has_factor(N, p);

// Where x_r contains every p-th element of x starting at offset r
x_r[j] → x[p*j + r];

// Check if N has a factor p
has_factor(N, p) → eval(N % p == 0 && p > 1);
```

This generalization enables automatic discovery of the Cooley-Tukey FFT algorithm for any composite N (not just powers of 2), as well as prime-factor and mixed-radix FFT variants.

## Handling Prime Lengths: Rader's Algorithm

When N is prime, the divide-and-conquer approach breaks down since N has no factors. However, Orbit can discover Rader's algorithm, which uses deeper group-theoretic properties to transform the problem:

```orbit
// Define multiplicative group of integers modulo N
ZnStar : Group ⊂ MultiplicativeGroup

// When N is prime, the multiplicative group (Z/NZ)* is cyclic of order N-1
(Z/NZ)* : ZnStar ⊢ (Z/NZ)* : C_{N-1} if is_prime(N);

// There exists a primitive root g whose powers generate all non-zero elements
g : PrimitiveRoot ⊢ {g^k mod N | k = 0,1,...,N-2} = {1,2,...,N-1} if is_prime(N);
```

Rader's insight was that when N is prime, we can reindex the DFT using a primitive root g of the multiplicative group modulo N:

```orbit
// For prime N, reindex DFT using the primitive root g
dft(x, N) : DFT !: Rader → (
  // Handle index 0 separately (DC component)
  y[0] = sum(j, 0, N-1, x[j]),
  
  // Reindexing for k ≠ 0 using primitive root g
  y[g^m mod N] = x[0] + sum(n, 0, N-2, x[g^n mod N] * W_N^(g^(m+n) mod N)) for m = 0,1,...,N-2
) : Rader if is_prime(N);

// The reindexed sum is actually a circular convolution
sum(n, 0, N-2, x[g^n mod N] * W_N^(g^(m+n) mod N)) : Summation →
  convolution(x', w')[m] : Convolution
  where x'[n] = x[g^n mod N] and w'[n] = W_N^(g^n mod N);
```

The brilliant transformation here is that a prime-length DFT becomes a circular convolution of length N-1, which can be efficiently computed if N-1 is composite (often a power of 2):

```orbit
// Apply FFT-based fast convolution if N-1 is composite
convolution(x', w') : Convolution !: FastConvolution →
  ifft(fft(x') * fft(w')) : FastConvolution if is_composite(length(x'));
```

This demonstrates Orbit's ability to discover profound mathematical insights - that a prime-length problem can be transformed into a composite-length problem where the previously derived FFT techniques apply.

## Bluestein's Algorithm: Universal FFT

For completeness, Orbit can also discover Bluestein's chirp z-transform algorithm, which works for any length N by expressing the DFT as a convolution through a clever identity:

```orbit
// Bluestein's algorithm transforms any-length DFT into convolution
W_N^(j*k) : TwiddleFactor → W_N^((j^2+k^2-j^2-k^2)/2) : TwiddleFactor;
                          → W_N^(j^2/2) * W_N^(k^2/2) * W_N^(-(j-k)^2/2) : TwiddleFactor;

// Express DFT as a linear convolution
dft(x, N) : DFT !: Bluestein → (
  // Multiply input by chirp
  let x' = [x[j] * W_N^(-j^2/2) for j = 0 to N-1];
  
  // Prepare convolution kernel
  let h = [W_N^(k^2/2) for k = 0 to N-1];
  
  // Zero-pad to power of 2 and compute via convolution
  let y' = convolution_padded(x', h);
  
  // Multiply by output chirp
  [y'[k] * W_N^(-k^2/2) for k = 0 to N-1]
) : Bluestein;
```

This approach works for any N by padding to a power of 2 size, offering a universal FFT algorithm derived purely from mathematical identities.

## Example: Tracing the Derivation for N=8

To illustrate how these rewrites transform a DFT into an FFT, let's trace the derivation for N=8:

```
dft(x, 8)
→ [dft(x, 8, k) for k = 0 to 7]

// Apply split to each dft(x, 8, k)
→ [dft(x_even, 4, k) + W_8^k * dft(x_odd, 4, k) for k = 0..3,
   dft(x_even, 4, k) - W_8^k * dft(x_odd, 4, k) for k = 0..3]

// Recursively apply to the size-4 DFTs:
→ [
  [dft(x_even_even, 2, k) + W_4^k * dft(x_even_odd, 2, k) for k = 0..1,
   dft(x_even_even, 2, k) - W_4^k * dft(x_even_odd, 2, k) for k = 0..1]
  +
  W_8^k * [dft(x_odd_even, 2, k) + W_4^k * dft(x_odd_odd, 2, k) for k = 0..1,
           dft(x_odd_even, 2, k) - W_4^k * dft(x_odd_odd, 2, k) for k = 0..1]
  for k = 0..3
]

// Continue to the size-2 DFTs and size-1 base cases...
→ Eventually resolves to the full butterfly structure
```

This derivation happens automatically through the application of our rewrite rules, without any explicit coding of the FFT algorithm.

## Example: Prime Length N=7 with Rader's Algorithm

For prime N=7, Orbit would apply Rader's algorithm:

```
// Find primitive root: g=3 for N=7 works (3^k mod 7 generates {1,2,3,4,5,6})
// Apply Rader's algorithm
dft(x, 7)
→ y[0] = x[0] + x[1] + x[2] + x[3] + x[4] + x[5] + x[6]

// For remaining indices, reindex using g=3:
// g^0=1, g^1=3, g^2=2, g^3=6, g^4=4, g^5=5 (all mod 7)

// Create convolution vectors (length 6):
x' = [x[1], x[3], x[2], x[6], x[4], x[5]]
w' = [W_7^1, W_7^3, W_7^2, W_7^6, W_7^4, W_7^5]

// Compute convolution using FFT since length 6 = 2×3
y = [y[0]] + ifft(fft(x') * fft(w'))

// Reorder output (using inverse mapping) to get the final result
```

This transforms the prime-length DFT into a composite-length convolution, demonstrating Orbit's ability to discover sophisticated mathematical transformations.

## Example: Non-Power-of-2 Size N=12

For N=12, the generalized approach would:

1. First split by factor 2: 12 → 6 × 2
2. Then split the size-6 problem by factor 2 again: 6 → 3 × 2
3. Finally, the size-3 problems by factor 3: 3 → 1 × 3

This mixed-radix approach still provides significant speedup over the naive O(N²) DFT, even though N=12 isn't a power of 2.

## Role of Symmetry Groups in the Derivation

The key to this automatic derivation is Orbit's understanding of the underlying group-theoretic structure:

1. **Cyclic Group C_N**: The twiddle factors W_N^k form a cyclic group under multiplication, with periodicity N. Orbit recognizes this structure via the `: C_N` annotation.

2. **Subgroup Relationship**: When N is composite, the twiddle factors exhibit subgroup relationships that enable the divide-and-conquer approach. For example, the even-indexed twiddle factors form a cyclic subgroup of order N/2.

3. **Group Action Optimization**: The FFT butterfly structure emerges from optimizing the group action of twiddle factors on the input sequence through decomposition into smaller group actions.

4. **Group Isomorphisms**: Rader's algorithm exploits the isomorphism between the multiplicative group (Z/NZ)* and a cyclic group C_{N-1} when N is prime, enabling transformation to a different domain where the problem becomes tractable.

5. **Cross-Domain Transformations**: Both Rader's and Bluestein's algorithms demonstrate Orbit's ability to discover transformations between problem domains that preserve algebraic structure while enabling more efficient computation.

These symmetry properties are what Orbit leverages to automatically discover the FFT algorithm and its variants from first principles.

## Unified Selection Strategy

A fully-featured Orbit system could automatically choose the optimal FFT algorithm based on the input size:

```orbit
// Unified FFT approach selecting the best algorithm
fft(x, N) : Transform →
  cooley_tukey_fft(x, N) : Transform if is_power_of_2(N);
  mixed_radix_fft(x, N) : Transform if is_composite(N);
  rader_fft(x, N) : Transform if is_prime(N);
  bluestein_fft(x, N) : Transform otherwise; // Fallback for any length
```

This demonstrates how Orbit can build a decision tree for selecting the optimal approach based on input characteristics, without these algorithms being explicitly encoded.

## Beyond FFT: Generalization to Other Algorithms

The approach demonstrated here can be generalized to discover other divide-and-conquer algorithms:

```orbit
// General divide-and-conquer pattern
operation(data, N) : DivideAndConquer !: Split → (
	combine([operation(subset(data, i), N/p) for i = 0 to p-1])
) : Split if can_split_problem(N, p);

// The condition function determines when we can divide
can_split_problem(N, p) → eval(N % p == 0 && N > 1);
```

This template can potentially discover algorithms like:

1. **Karatsuba multiplication**: O(n^1.58) integer multiplication via splitting
2. **Strassen's algorithm**: O(n^2.81) matrix multiplication
3. **Fast convolution algorithms**: Using the FFT pattern for other linear convolutions
4. **Divide-and-conquer sorting**: Recursive structure of merge sort, quicksort

Additionally, the cross-domain transformation insights from Rader's and Bluestein's algorithms suggest Orbit could potentially discover other non-obvious algorithmic optimizations by identifying structural equivalences between seemingly different problems.

## Conclusion

This document demonstrates how Orbit's group-theoretic approach enables automatic discovery of the FFT algorithm family from the DFT definition, without explicitly encoding them. By expressing the mathematical symmetries as rewrite rules and leveraging algebraic group structures, Orbit can derive multiple variants of the FFT algorithm suited to different input sizes.

The key insights are:

1. **Algebraic structure recognition**: Identifying the cyclic group structure in DFT's twiddle factors
2. **Conditional rewrites**: Applying transformations based on number-theoretic properties
3. **Recursive pattern emergence**: The FFT structure emerges naturally from repeated rule application
4. **Cross-domain transformations**: Problems in one domain can be mapped to different domains with better algorithms (as in Rader's algorithm)
5. **Unified algorithm selection**: A single framework can automatically choose among Cooley-Tukey, Rader's, and Bluestein's algorithms based on input characteristics
6. **Automatic identity discovery**: The system can systematically explore algebraic properties to discover the core identities that enable optimization

This capability represents a significant step toward automated algorithm discovery - where Orbit doesn't just optimize existing algorithms but can actually derive complex algorithms from mathematical first principles, potentially discovering novel optimizations that human programmers might overlook.
