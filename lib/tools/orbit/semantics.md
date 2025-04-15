# Inferring Semantic Properties as Domains in Orbit

## Introduction

Beyond type inference, Orbit's domain-based rewriting system can be used to infer deeper *semantic properties* of functions and operations. By analyzing the structure and components of expressions, we can associate them with domains representing properties like `Associative`, `Commutative`, `Invertible`, or `Idempotent`.

This document describes how we infer and propagate semantic properties through expressions, enabling optimizations, verification, and transformations.

## Defining Semantic Property Domains

We define domains to represent semantic properties that can be inferred and propagated.

```orbit
// Symmetry groups and algebraic properties
S₂ ⊂ SymmetryGroup;     // Symmetric group of order 2 (commutativity)
Associative ⊂ Property;
Distributive ⊂ Property;
Idempotent ⊂ Property;

// Invertibility properties
Invertible ⊂ Property;      // Operation has an inverse
InvertibleIf(cond) ⊂ Property;  // Conditional invertibility

// Numeric domains
Int32 ⊂ Integer ⊂ Rational ⊂ Real ⊂ Complex;
```

## Inferring Properties via Pattern Matching

We use direct pattern matching and the entailment operator (⊢) to identify operations and infer their properties.

### 1. Properties of Basic Arithmetic Operations

```orbit
// Addition has symmetry group S₂ (commutativity) for all numeric domains
a : Numeric + b : Numeric ⊢ + : S₂;

// Addition is associative for all numeric domains
a : Numeric + b : Numeric ⊢ + : Associative;

// Multiplication has symmetry group S₂ (commutativity) for all numeric domains
a : Numeric * b : Numeric ⊢ * : S₂;

// Multiplication is associative for all numeric domains
a : Numeric * b : Numeric ⊢ * : Associative;

// Multiplication distributes over addition
a : Numeric * (b : Numeric + c : Numeric) ⊢ * : Distributive;
```

### 2. Int32-Specific Rules

```orbit
// Int32 addition has well-defined overflow behavior
a : Int32 + b : Int32 => (a + b) : Int32 : WrappingOverflow;

// Int32 multiplication has well-defined overflow behavior
a : Int32 * b : Int32 => (a * b) : Int32 : WrappingOverflow;

// Int32 division is only defined when the divisor is not zero
a : Int32 / b : Int32 => (a / b) : Int32 : PartialFunction if b != 0;

// Int32 modulo is only defined when the divisor is not zero
a : Int32 % b : Int32 => (a % b) : Int32 : PartialFunction if b != 0;
```

### 3. Propagating Properties (Bubbling Up)

A key insight is that properties can bubble up from subexpressions to their parents:

```orbit
// Operations composed of associative operations maintain associativity. todo: use unicode compose syntax
compose(f : Associative, g : Associative) ⊢ compose(f, g) : Associative;
```

### 4. Inverse Operations With Constraints

```orbit
// Addition is always invertible - inverse is subtraction
a : Numeric + b : Numeric ⊢ (a + b) : Invertible;

// Multiplication is invertible only when both operands are non-zero
a : Numeric * b : Numeric ⊢ (a * b) : Invertible if a != 0 && b != 0;

// Division is invertible only when the dividend is non-zero
a : Numeric / b : Numeric ⊢ (a / b) : Invertible if a != 0;

// Exponentiation is invertible under specific conditions
a : Numeric ^ b : Numeric ⊢ (a ^ b) : Invertible if a > 0;
```

## Benefits of Property Inference and Bubbling

This approach to property inference enables:

* **Compositional Reasoning:** Properties of complex expressions are derived from properties of their components
* **Targeted Optimizations:** Apply transformations only when required properties are present
* **Provable Correctness:** Verify that transformations preserve semantics
* **Domain-Specific Rules:** Different behaviors for different numeric domains (Int32 vs. Real)
* **Conditional Transformations:** Apply optimizations only when conditions are met (e.g., non-zero divisors)

## Examples with Int32 Domain

```orbit
// Int32-specific distributivity with overflow awareness
(a : Int32 * (b : Int32 + c : Int32)) : WrappingOverflow <=>
	((a : Int32 * b : Int32) + (a : Int32 * c : Int32)) : WrappingOverflow;

// Int32 addition commutativity
a : Int32 + b : Int32 ⊢ + : S₂;

// Int32 multiplication by 0 simplification
a : Int32 * 0 : Int32 => 0 : Int32;

// Int32 multiplication by powers of 2 can be replaced by shifts
a : Int32 * 2 : Int32 => a << 1 : Int32;
a : Int32 * 4 : Int32 => a << 2 : Int32;
a : Int32 * 8 : Int32 => a << 3 : Int32;
```

## Conclusion

By using pattern matching with domain annotations and the entailment operator, Orbit can infer semantic properties of expressions and propagate them appropriately. The ability to bubble up properties from subexpressions is particularly powerful, allowing for compositional reasoning about complex expressions while maintaining precision. This approach enables sophisticated program transformation while preserving semantic guarantees.