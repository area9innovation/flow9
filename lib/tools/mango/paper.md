# Type Inference for Poppy and Mango: A Comprehensive Analysis

## Abstract

This paper presents a detailed analysis of the type inference algorithm implemented for Poppy (a stack-based concatenative language) and Mango (a parsing expression grammar with semantic actions). The system employs a unification-based approach with equivalence classes, word composition, polymorphism, implicit union extraction, and support for recursion and mutual recursion. The type system is designed to infer types for concatenative programs where function composition is the primary operation.

## 1. Introduction

Poppy is a stack-based concatenative language where programs are composed by sequencing operations that transform the stack. Mango is a parser generator that produces Poppy code as semantic actions. The type system must handle:

- Stack-based composition of words (functions)
- Polymorphism with type variables
- Recursive and mutually recursive definitions
- Implicit union type extraction
- Struct field extraction from usage patterns
- Overloading resolution

The implementation is based on unification with equivalence classes (eclasses) similar to Hindley-Milner but adapted for concatenative languages.

## 2. Type Representation

### 2.1 Core Type Language

The type system uses the following core constructs (defined in `tools/poppy/type/types.flow:2-22`):

```
PType ::= PTypeName | PTypeEClass | PTypeWord | PTypeOverload | PTypeEval | PTypeCompose
```

**PTypeName(name, typars)**: Named types with type parameters
- Examples: `int`, `string`, `List<α>`, `Option<β>`
- Type parameters are themselves PTypes, enabling nested polymorphism

**PTypeEClass(eclass)**: Equivalence class for type variables
- Used for unification during type inference
- Represents unknown types to be determined
- Also used to represent polymorphic type variables

**PTypeWord(inputs, outputs)**: The type of a word/function
- Represents stack transformation: `(inputs → outputs)`
- `inputs`: Types consumed from the stack (right to left)
- `outputs`: Types produced to the stack (left to right)
- Example: `([int, int] → [int])` for addition
- Special case: `([] → [T])` is equivalent to just `T`

**PTypeOverload(overloads)**: Overloaded function types
- Contains multiple alternative type signatures
- Used for operations like `while` that have different types depending on context

**PTypeEval()**: Special type for the `eval` operation
- Represents stack polymorphism: `( → a) ◦ eval = a`
- Enables higher-order stack manipulation
- Critical for implementing control flow constructs

**PTypeCompose(left, right)**: Deferred composition
- Represents `left ◦ right` when composition cannot be immediately resolved
- Used when one or both sides contain unresolved type variables
- Enables lazy evaluation of type composition

### 2.2 Type Environment

The type environment (`PTypeEnv` in `tools/poppy/type/env.flow:8-25`) maintains:

**unionFindMap**: Union-find data structure mapping eclasses to their type constraints
- Key: eclass identifier (int)
- Value: list of types unified with this eclass
- Merge function: `sortUnique(concat(l, r))` - combines and deduplicates types
- Used for efficient equivalence class merging during unification

**eclassNames**: Suggested names for eclasses
- Maps eclass IDs to human-readable names
- Used for generating meaningful union type names
- Populated from variable names and rule names

**words**: Maps word/function names to their types
- Populated with core types from RunCore primitives
- Extended during type inference with user-defined words
- Used for lookup during type checking

**unions**: Discovered union types
- Maps union type names to their constituent struct types
- Populated during implicit union extraction phase
- Used to distinguish between structs and unions

**structs**: Set of discovered struct names
- Tracks all struct types encountered during inference
- Used to avoid creating redundant union types

**unique**: Counter for generating fresh eclass IDs
- Incremented for each new type variable
- Ensures global uniqueness of eclasses

## 3. Type Inference Algorithm

### 3.1 Overview

The type inference process for Mango grammars (`inferMangoTypes` in `tools/mango/type_inference.flow:13-26`) follows these phases:

1. **Rule Discovery**: Extract all grammar rules from the term
2. **Topological Sorting**: Order rules by dependencies to handle recursion
3. **First Pass**: Initialize type environment with placeholder eclasses
4. **Type Inference**: Process rules in topological order
5. **Elaboration**: Resolve composed types and eclasses
6. **Union Extraction**: Identify and name implicit union types
7. **Struct Extraction**: Collect struct definitions with field types

### 3.2 Rule Discovery and Topological Sorting

**Rule Discovery** (`findRules` in `tools/mango/rules.flow:9-49`):
- Traverses the Mango grammar term tree
- Collects mapping from rule names to their definitions
- Detects duplicate rules and warns about inconsistencies

**Topological Sorting** (`topoRules` in `tools/mango/topo.flow:10-27`):
- Constructs dependency graph between rules
- Rule A depends on rule B if A's definition references variable B
- Computes topological order using Tarjan's algorithm
- Handles cycles by computing loop-free subgraph
- Ensures dependencies are typed before dependents
- Critical for handling mutual recursion correctly

Example dependency analysis (`tools/mango/topo.flow:30-68`):
```
exp = term "+" exp { Binop }
  | term
term = id { Var }
```
Creates dependency: `exp → term`, allowing `term` to be typed first.

### 3.3 First Pass Initialization

The first pass (`firstPass` in `tools/mango/type_inference.flow:96-141`) walks the grammar to:

1. **Create placeholder eclasses for each rule**:
   - For each `Rule(id, term1, term2)`, create `eclass = makePTypeEClass(env, id)`
   - Store in `env.words` with the rule name as key
   - This breaks circular dependencies for recursive rules

2. **Process Poppy definitions in StackOp nodes**:
   - StackOp nodes contain embedded Poppy code
   - These may contain `define` statements that create new words
   - Process these early to populate the word environment

Example from `tools/mango/type_inference.flow:121-127`:
```
Rule(id, term1, term2): {
    eclass = makePTypeEClass(env, id)
    env.words := setTree(^(env.words), id, eclass)
    firstPass(env, term1)
    firstPass(env, term2)
}
```

### 3.4 Type Inference for Mango Terms

The main inference function (`mangoType2` in `tools/mango/type_inference.flow:144-248`) processes each term type:

**Variable(id)**:
- Lookup type in `env.words`
- Instantiate polymorphism by replacing `?` placeholders with fresh eclasses
- Returns instantiated type

**Construct(uid, arity)**:
- Creates constructor type: `(τ₁, ..., τₙ → Uid<τ₁,...,τₙ>)`
- Each field gets a fresh eclass as its type
- Records struct name in `env.structs`

Example from `tools/mango/type_inference.flow:164-170`:
```
Construct(uid, int1): {
    typars = generate(0, s2i(int1), \i -> makePTypeEClass(env, ""))
    type = PTypeWord(typars, [PTypeName(uid, typars)])
    env.structs := insertSet(^(env.structs), uid)
    [type]
}
```

**Sequence(term1, term2)**:
- Infer types for both terms: `t1 = mangoType2(env, term1)`, `t2 = mangoType2(env, term2)`
- Compose all combinations: `t1ᵢ ◦ t2ⱼ` for all i, j
- Return list of all valid compositions
- Empty list propagates through (identity for composition)

The composition logic (`tools/mango/type_inference.flow:202-218`):
```
if (t1 == []) t2
else if (t2 == []) t1
else {
    concatA(map(t1, \tt1 -> {
        map(t2, \tt2 -> {
            mtype = composeIfFeasible(env, tt1, tt2)
            mtype ?? mtype : perror(...)
        })
    }))
}
```

**Choice(term1, term2)**:
- Unified handling using `unifyChoices`
- Flattens nested choices
- Infers types for all alternatives
- Returns sorted unique list of types
- Unification determines if types are compatible

**Rule(id, term1, term2)**:
- Processes rule body (term2)
- Looks up rule's eclass from first pass
- Returns inferred types from body
- The eclass links recursive references back to this rule

**PushMatch(term)**:
- Produces a string containing the matched text
- Type: `( → string)`

**StackOp(id)**:
- Special operations: `pos` returns `int`, `switch` returns `(string → Top)`
- Other operations: Parse as Poppy code and infer type
- Calls `findPoppyDefines` then `poppyType`

**String, Range**: No-op types `( → )` - consume nothing, produce nothing

**Star, Plus, Optional, Error, Lower, Negate**: Recursively process subterms

### 3.5 Type Inference for Poppy

The Poppy type inference (`poppyType` in `tools/poppy/type/infer_type.flow:30-215`) handles:

**Primitives**:
- `PoppyDup`: `(α → α α)` - polymorphic duplication
- `PoppyDrop`: `(α → )` - polymorphic removal
- `PoppySwap`: `(α β → β α)` - polymorphic swap
- `PoppyCons`: `(list<α> α → list<α>)` - list construction
- `PoppyNil`: `( → list<α>)` - empty list
- Literals: `PoppyInt` → `int`, `PoppyString` → `string`, etc.

**PoppyDefine(word, body)** - Critical for recursion:

1. **Placeholder creation** (`tools/poppy/type/infer_type.flow:114-115`):
   ```
   placeholder = makePTypeEClass(env, word)
   env.words := setTree(^(env.words), word, placeholder)
   ```
   This breaks circular dependencies for recursive definitions.

2. **Body inference** (`tools/poppy/type/infer_type.flow:123`):
   ```
   type = poppyType(namedEnv, body)
   ```
   Infer the type of the body. If body references `word`, it gets the placeholder.

3. **Substitution** (`tools/poppy/type/infer_type.flow:133`):
   ```
   rtype = substitutePType(placeholder, type, type)
   ```
   Replace placeholder with inferred type to get recursive type.

4. **Update eclass** (`tools/poppy/type/infer_type.flow:135`):
   ```
   setUnionMapValue(env.unionFindMap, placeholder.eclass, [rtype])
   ```

5. **Elaboration** (`tools/poppy/type/infer_type.flow:148`):
   ```
   ftype = elaboratePType(env, makeSet1(root), ref makeSet(), rtype)
   ```
   Resolve compositions and simplify type.

6. **Union extraction** (`tools/poppy/type/infer_type.flow:155-157`):
   ```
   unionize = extractImplicitUnions(env, ref makeSet(), word, ftype)
   utype = elaboratePType(env, makeSet1(root), ref makeSet(), unionize)
   ```

7. **Final type assignment** (`tools/poppy/type/infer_type.flow:160`):
   ```
   env.words := setTree(^(env.words), word, utype)
   ```

**PoppySequence(poppy1, poppy2)**:
- Similar to Mango sequences
- Compose types using `composeIfFeasible`

**PoppyWord(word)**:
- Lookup type and instantiate polymorphism
- Fresh eclasses for each use (enables separate unification)

**PoppyEval**:
- Returns `PTypeEval()` for later resolution during composition
- Stack polymorphic evaluation of quotations

**PoppyIfte** (if-then-else):
- Type: `(bool ( → α) ( → α) → α) ◦ eval`
- Composes conditional with eval for execution

**PoppyWhile**:
- Overloaded type with two cases:
  - `(( → bool) α → α) ◦ eval` - simple condition
  - `((β → β bool) γ → γ) ◦ eval` - body produces value and condition

### 3.6 Rule Type Processing

After topological sorting, `mangoTypesOfRules` (`tools/mango/type_inference.flow:29-93`) processes each rule:

1. **Lookup rule's eclass**: `mtype = lookupTree(^(env.words), rule)`

2. **Infer rule body types**: `types = mangoType2(env, tt)`

3. **Unify with eclass**:
   ```
   forall(types, \t -> unifyPType(env, false, t, etype))
   ```
   This connects the inferred types with the placeholder from first pass.

4. **Optional resolution**: Attempt to resolve types to remove eclasses
   - If single type and is nop: update eclass to this type
   - Otherwise: resolve eclasses and update unionFindMap

5. **Recurse**: Process next rule in topological order

## 4. Word Composition

Word composition is the fundamental operation in concatenative languages. The algorithm is in `composeIfFeasible` (`tools/poppy/type/compose.flow:15-155`).

### 4.1 Basic Composition Rules

**Named Types**:
```
Name₁ ◦ Name₂ = ( → Name₁ Name₂)
```
Two values on the stack.

**Name with Word**:
```
Name ◦ (inputs → outputs) = ( → Name) ◦ (inputs → outputs)
```
Lift name to nullary word, then compose.

**Word Composition** (key case):

For words `(i₁... → o₁... b₁)` and `(i₂... b₂ → o₂...)`:

1. **Empty outputs left**: `(i₁... → ) ◦ (i₂... → o₂...) = (i₂... i₁... → o₂...)`
   - No outputs to unify, just concatenate inputs

2. **Empty inputs right**: `(i₁... → o₁...) ◦ ( → o₂...) = (i₁... → o₁... o₂...)`
   - No inputs to consume, just concatenate outputs

3. **General case** (`tools/poppy/type/compose.flow:172-204`):
   - Extract last output `b₁` from left word
   - Extract last input `b₂` from right word
   - Check unifiability: `unifyPType(env, true, b1, b2)`
   - If unifiable:
     - Unify for real: `unifyPType(env, false, b1, b2)`
     - Recursively compose: `composeIfFeasible(env, PTypeWord(a.inputs, o1), PTypeWord(i2, b.outputs))`
   - If not unifiable: return `None()`

Example:
```
(int → int int) ◦ (int → bool)
= (int → int) ◦ ( → bool)     // Unify last output (int) with last input (int)
= (int → int bool)             // Compose residual
```

### 4.2 Composition with EClasses

**Name with EClass**:
```
Name ◦ ε = ( → Name ε)
```
Creates a pair on the stack.

**Word with EClass** (`tools/poppy/type/compose.flow:54-76`):
- If word has outputs, defer composition: `(i... → o...) ◦ ε = makePTypeCompose(...)`
- If word has no outputs: `(i... → ) ◦ ε = ε`

**Resolving EClass composition** (`composeWithEClass` in `tools/poppy/type/compose.flow:290-308`):
- Lookup eclass values from unionFindMap
- If empty: defer as `makePTypeCompose(a, PTypeEClass(eclass))`
- If non-empty: try to compose with each value
  - Keep compatible compositions
  - If single result: return it
  - If multiple: create new eclass containing results

### 4.3 Composition with Eval

The `eval` operation has special composition rules (`composeEval` in `tools/poppy/type/compose.flow:214-277`):

**Empty stack**: `( → (i... → o...)) ◦ eval = (i... → o...)`
- The function is just returned as-is

**Nullary function**: `( → ( → o...)) ◦ eval = ( → o...)`
- Execute the function: `inputs ++ fnoutputs`

**Function application**:
```
( → inputs (fninputs → fnoutputs)) ◦ eval
```
where `inputs = [..., a]` and `fninputs = [..., a']`:

1. Unify last input `a` with last fnarg `a'`
2. Curry: remove matched arguments
3. Recursively compose:
   ```
   ( → restInput (restArgs → fnoutputs)) ◦ eval
   ```

Example:
```
( → 3 (int → int)) ◦ eval
= ( → ) ◦ eval        // Unify 3:int with int
= ( → int)            // Apply and get result
```

This enables:
- Higher-order functions
- Partial application
- Control flow with quotations

### 4.4 Overload Resolution

**Overload on left** (`tools/poppy/type/compose.flow:102-112`):
```
Overload([t₁, ..., tₙ]) ◦ b = Overload(filtermap([t₁, ..., tₙ], \tᵢ -> composeIfFeasible(env, tᵢ, b)))
```
- Try composing each overload with right side
- Keep those that succeed
- If single result: resolve to that type
- If multiple: keep as overload
- If none: composition fails

**Overload on right**: Symmetric to left case

### 4.5 Associativity and Deferred Composition

**Left-associative grouping**:
```
(a ◦ b) ◦ c = a ◦ (b ◦ c)
```

Implementation (`tools/poppy/type/compose.flow:114-143`):
```
PTypeCompose(left1, right1) ◦ b:
    middle = composeIfFeasible(env, right1, b)
    match middle:
        Some(m) ->
            if isPTypeCompose(m):
                Some(makePTypeCompose(left1 ◦ right1, b))
            else:
                composeIfFeasible(env, left1, m)
        None() -> None()
```

**Double composition**:
```
(l₁ ◦ r₁) ◦ (l₂ ◦ r₂) = l₁ ◦ (r₁ ◦ l₂) ◦ r₂
```

This reassociation is critical for:
- Enabling type inference to proceed when some compositions are blocked
- Allowing later phases to resolve deferred compositions
- Supporting incremental type refinement

## 5. Unification

The unification algorithm (`unifyPType` in `tools/poppy/type/unify.flow:10-183`) determines type compatibility and builds equality constraints.

### 5.1 Unification Modes

The algorithm operates in two modes controlled by `checkOnly`:

**Check Mode** (`checkOnly = true`):
- Verifies if two types can be unified
- Does not modify the environment
- Returns boolean result
- Used before committing to unification

**Update Mode** (`checkOnly = false`):
- Performs actual unification
- Updates unionFindMap with new constraints
- Merges eclasses
- Used after check succeeds

### 5.2 Unification Rules

**PTypeName with PTypeName** (`tools/poppy/type/unify.flow:55-68`):
```
unify(Name₁<τ₁,...,τₙ>, Name₂<σ₁,...,σₘ>):
    if Name₁ ≠ Name₂:
        return isUpperLetter(Name₁[0]) && isUpperLetter(Name₂[0])
    if n ≠ m:
        return false
    return ∀i. unify(τᵢ, σᵢ)
```
- Different struct names can unify if both start with uppercase
- This enables implicit union creation
- Type parameters must unify recursively

**PTypeEClass with PType** (`tools/poppy/type/unify.flow:81-106`):

In check mode:
```
unify(ε, t):
    values = getUnionMapValue(env.unionFindMap, ε)
    return ∀v ∈ values. unify(v, t)
```

In update mode:
```
bind(ε, t):
    types = getUnionMapValue(env.unionFindMap, ε)
    ntypes = sortUnique(types ++ [t])
    setUnionMapValue(env.unionFindMap, ε, ntypes)
    ∀v ∈ types. unify(v, t)  // Check existing values are compatible
```

**PTypeEClass with PTypeEClass** (`tools/poppy/type/unify.flow:84-100`):

In check mode: pairwise unify all values from both eclasses

In update mode:
```
unify(ε₁, ε₂):
    root = unionUnionMap(env.unionFindMap, ε₁, ε₂)
```
Merges the two eclasses in union-find structure, combining their constraints.

**PTypeWord with PTypeWord** (`tools/poppy/type/unify.flow:108-111`):
```
unify((i₁... → o₁...), (i₂... → o₂...)):
    return unify(i₁..., i₂...) && unify(o₁..., o₂...)
```
Inputs and outputs must match element-wise.

**PTypeWord with PTypeName** (`tools/poppy/type/unify.flow:109-117`):
```
unify(([] → [t]), Name):
    return unify(t, Name)
```
Nullary word is equivalent to its single output type.

**PTypeWord with PTypeCompose** (`tools/poppy/type/unify.flow:121-158`):

Several cases for `unify((i₁... → o₁...), (left ◦ right))`:

1. **Right is Word**:
   ```
   unify((i₁... → o₁...), (_ ◦ (i₂... → o₂...))):
       return unify(i₁..., i₂...) && unify(o₁..., o₂...)
   ```

2. **Right is EClass**:
   ```
   unify((i₁... → o₁...), ((i₂... → o₂...) ◦ ε)):
       unify(i₁..., i₂...)
       bind(ε, PTypeWord([ε'₁,...,ε'ₘ], [ε''₁,...,ε''ₙ]))
   ```
   Creates fresh eclasses for the unknown right side based on the known outputs.

**Overload handling** (`tools/poppy/type/unify.flow:197-213`, `unifyPOverload`):
```
unify(Overload([t₁,...,tₙ]), t):
    compatible = filtermap([t₁,...,tₙ], \tᵢ ->
        if unify(tᵢ, t) in check mode then Some(tᵢ) else None)
    For each compatible tᵢ:
        unify(tᵢ, t) in update mode
    return length(compatible) > 0
```

### 5.3 List Unification

Helper `unifyPTypes` (`tools/poppy/type/unify.flow:185-195`):
```
unify([t₁,...,tₙ], [s₁,...,sₘ]):
    ts = filterNops([t₁,...,tₙ])
    ss = filterNops([s₁,...,sₘ])
    if length(ts) ≠ length(ss): return false
    return ∀i. unify(tsᵢ, ssᵢ)
```

Filters out nop types `( → )` before comparison, as they are identity elements.

## 6. Elaboration

Elaboration (`elaboratePType` in `tools/poppy/type/elaborate.flow:39-107`) resolves eclasses and simplifies composed types.

### 6.1 Algorithm

```
elaborate(env, recursive, seen, pt):
    match pt:
        PTypeName(name, typars):
            return PTypeName(name, [elaborate(..., tᵢ) | tᵢ ← typars])

        PTypeEClass(ε):
            if ε ∈ seen: return pt  // Prevent infinite recursion
            seen := seen ∪ {ε}
            types = getUnionMapValue(env.unionFindMap, findRoot(ε))
            rtypes = [elaborate(..., t) | t ← types, hasNoRecursiveEClass(t, recursive)]
            if |rtypes| == 1 && hasNoEClasses(rtypes[0]):
                return rtypes[0]
            else:
                return pt  // Keep as eclass

        PTypeWord(inputs, outputs):
            ein = [elaborate(..., i) | i ← inputs]
            eout = [elaborate(..., o) | o ← outputs]
            if inputs == [] && |outputs| == 1 && isNamed(outputs[0]):
                return outputs[0]  // ( → T) = T
            else:
                return PTypeWord(ein, eout)

        PTypeCompose(left, right):
            l = elaborate(..., left)
            r = elaborate(..., right)
            result = composeIfFeasible(env, l, r)
            match result:
                Some(composed):
                    if composed ≠ pt:
                        return elaborate(..., composed)  // Fixed point
                    else:
                        return composed
                None():
                    return makePTypeCompose(l, r)
```

### 6.2 Key Features

**Cycle Detection**:
- `seen` set tracks visited eclasses
- If eclass already in `seen`, return it as-is to prevent infinite loops
- Critical for recursive types

**Recursive Type Filtering**:
- `recursive` set contains eclasses that are recursive
- Filter out types containing recursive eclasses from eclass resolution
- Prevents ill-formed types like `T = T`

**Composition Resolution**:
- Attempt to compose using `composeIfFeasible`
- If successful and different from input, recursively elaborate (fixed-point iteration)
- If fails, keep as deferred `PTypeCompose`

**Type Consolidation** (`consolidateByName` in `tools/poppy/type/elaborate.flow:110-120`):
```
consolidateByName(env, types):
    For each type t in types:
        Find existing type in acc with same name
        If found:
            merged = mergePTypes(env, existing, t)
            Replace existing with merged
        Else:
            Add t to acc
```

This merges multiple occurrences of the same struct with potentially different field types, creating a most general struct.

**Type Merging** (`mergePTypes` in `tools/poppy/type/elaborate.flow:123-168`):
```
merge(Name₁<τ₁,...,τₙ>, Name₂<σ₁,...,σₘ>):
    if Name₁ == Name₂:
        return Name₁<merge(τ₁,σ₁), ..., merge(τₙ,σₙ)>
    else:
        // Create implicit union
        ε = makePTypeEClass(env, Name₂)
        setUnionMapValue(env.unionFindMap, ε, [Name₁<...>, Name₂<...>])
        return ε
```

## 7. Recursion and Mutual Recursion

### 7.1 Handling Recursion in Poppy

The algorithm in `poppyType` for `PoppyDefine` handles recursion using the placeholder technique:

**Step-by-step**:

1. **Create placeholder** before processing body:
   ```
   placeholder = makePTypeEClass(env, word)
   env.words := setTree(^(env.words), word, placeholder)
   ```

2. **Infer body type**:
   - If body references `word`, it gets `placeholder` type
   - Inference proceeds with placeholder as a type variable

3. **Substitute placeholder**:
   ```
   rtype = substitutePType(placeholder, type, type)
   ```
   Replaces all occurrences of `placeholder` in `type` with `type` itself, creating a recursive type equation.

4. **Store in unionFindMap**:
   ```
   setUnionMapValue(env.unionFindMap, placeholder.eclass, [rtype])
   ```

**Example**: Consider `factorial` defined as:
```
factorial = dup 1 <= [] [dup 1 - factorial *] ifte eval
```

Inference proceeds:
- Create `placeholder = ε₁`
- Set `env.words[factorial] = ε₁`
- Infer body, which references `factorial`, getting `ε₁`
- Result type: `(int → int)`
- Substitute: `ε₁ := (int → int)`
- Store in unionFindMap

The recursive reference is resolved through the eclass, avoiding infinite regress.

### 7.2 Handling Mutual Recursion in Mango

Mango's topological sort handles mutual recursion:

**Example**:
```
exp = term "+" exp { Binop }
    | term
term = "(" exp ")" { Parens }
     | number
```

Dependency: `exp → term`, `term → exp` (cycle)

**Processing**:

1. **Topological sort** (`topoRules` in `tools/mango/topo.flow:10-27`):
   - Detects cycle: `{exp, term}`
   - Computes loop-free graph: breaks cycle (e.g., removes `term → exp` edge)
   - Produces order: `[term, exp]` (or may include both in a cycle component)

2. **First pass** (`firstPass`):
   - Create `env.words[exp] = ε₁`
   - Create `env.words[term] = ε₂`

3. **Process `term`**:
   - Infers type referencing `exp`, which is `ε₁`
   - Result: `ε₂ := ( → Parens | int)`
   - Unify with `ε₂`

4. **Process `exp`**:
   - Infers type referencing `term`, which is `ε₂`
   - Result: `ε₁ := ( → Binop | Parens | int)`
   - Unify with `ε₁`

5. **Unification** propagates constraints between `ε₁` and `ε₂`, resolving the mutual recursion.

The key insight: eclasses act as "future-type" placeholders, allowing references to not-yet-computed types. Unification retroactively ensures consistency.

### 7.3 Cycle Detection in Elaboration

During elaboration, cycles are detected and prevented:

```
elaboratePType(env, recursive, seen, pt):
    case PTypeEClass(ε):
        if ε ∈ seen: return pt  // Already visiting this eclass
        seen := seen ∪ {ε}
        ...
```

The `recursive` parameter contains eclasses known to be recursive (from topological sort or substitution analysis). Types containing these eclasses are filtered out during eclass resolution to prevent malformed types.

## 8. Implicit Union Extraction

Implicit unions arise when multiple struct types are unified with the same eclass. The algorithm extracts and names these unions.

### 8.1 Union Extraction Algorithm

`extractImplicitUnions` (`tools/poppy/type/unions.flow:18-42`) walks the type, looking for eclasses with multiple struct types:

```
extractImplicitUnions(env, seen, id, type):
    case PTypeEClass(ε):
        if ε ∈ seen: return type  // Avoid cycles
        seen := seen ∪ {ε}
        types = getUnionMapValue(env.unionFindMap, findRoot(ε))
        return unionize(env, seen, ε, types)
```

**Unionize** (`tools/poppy/type/unions.flow:45-107`) determines union type:

1. **Best name** from eclass names: `bestUnionName(env, ε)`

2. **Consolidate by name**: Merge structs with same name

3. **Remove self-references**: Filter out the union name itself

4. **Check for existing union**:
   - Search `env.unions` for a union containing these types
   - If found: reuse existing union name
   - If not found: create new union

5. **Single type**: If only one type remains, return it directly

6. **Multiple types**: Create union `PTypeName(name, [])`
   - Store in `env.unions[name] = types`
   - Update unionFindMap: `setUnionMapValue(ε, [union])`

**Example**:

Suppose `ε₁` has unified with `Int`, `String`, `Bool`:
- Best name: "Value" (derived from eclass name)
- Create `Value` union
- Store: `env.unions[Value] = [Int, String, Bool]`
- Replace: `ε₁ := Value`

### 8.2 Union Name Selection

`bestUnionName` (`tools/poppy/type/unions.flow:110-119`) selects the best name:

1. **Collect names**: Get all eclass names in the equivalence class (including merged eclasses)

2. **Pick best**: Use `pickBestName` with capital=true

`pickBestName` (`tools/poppy/type/unions.flow:121-134`) scores names:
```
score(n) = strlen(n) + capPenalty + existPen
    where capPenalty = 0 if capitalized correctly, 100 otherwise
          existPen = 0 if name not in structs/unions, 20 otherwise
```

Selects name with lowest score (shortest, already capitalized, doesn't conflict).

### 8.3 Union Reuse

To avoid creating redundant unions, the algorithm checks if a union with the same (or superset) constituents already exists:

```
existing = foldTree(env.unions, [], \un, utypes, acc ->
    unames = map(utypes, getName)
    if isSubArray(removeFirst(names, un), unames):
        arrayPush(acc, Pair(length(utypes), un))
    else: acc
)
```

Sorts by size and reuses the smallest existing union that covers the required types.

## 9. Struct Field Extraction

The algorithm extracts struct definitions by traversing all types and collecting struct usages.

### 9.1 Extraction Algorithm

`collectPTypeStructs` (`tools/poppy/type/structs.flow:12-31`) collects all structs:

1. **Visit words**: For each word in `env.words`, extract structs from its type

2. **Visit eclasses**: For each eclass in unionFindMap, extract structs from its types

3. **Merge definitions**: If struct appears multiple times with different field types, merge them

`extractPTypeStruct` (`tools/poppy/type/structs.flow:39-63`) recursively extracts:

```
extractPTypeStruct(env, structs, p):
    case PTypeName(name, typars):
        if name == "Top": return structs  // Skip Top
        if name in structs:
            return structs  // Already processed
        else:
            structs' = addPTypeStruct(env, structs, name, p)
            return extractPTypeStructs(env, structs', typars)  // Recurse into parameters

    case PTypeEClass(ε):
        values = getUnionMapValue(env.unionFindMap, ε)
        return extractPTypeStructs(env, structs, values)

    case PTypeWord(inputs, outputs):
        structs' = extractPTypeStructs(env, structs, inputs)
        return extractPTypeStructs(env, structs', outputs)
```

### 9.2 Struct Merging

`addPTypeStruct` (`tools/poppy/type/structs.flow:66-80`) adds or merges a struct:

```
addPTypeStruct(env, structs, name, struct):
    if not isUpperLetter(name[0]): return structs  // Skip lowercase

    existing = lookupTree(structs, name)
    match existing:
        None:
            return setTree(structs, name, struct)
        Some(e):
            if e == struct:
                return structs  // Already have this exact type
            else:
                // Merge field types
                merged = PTypeName(name, [
                    mergePTypes(env, struct.typars[i], e.typars[i])
                    for i in 0..length(struct.typars)
                ])
                return setTree(structs, name, merged)
```

**Merging logic** uses `mergePTypes` from elaboration:
- If field types are same name: recursively merge type parameters
- If different names: create implicit union eclass
- Result: struct with most general field types

**Example**:

Suppose we see:
```
Point(x: int, y: int)
Point(x: int, y: double)
```

Merging:
- `x`: `merge(int, int) = int`
- `y`: `merge(int, double) = ε₁` where `ε₁ = {int, double}`

Result: `Point(x: int, y: ε₁)` which elaborates to `Point(x: int, y: Number)` if an implicit union is created.

### 9.3 Field Type Propagation

Field types propagate through unification:

1. **Constructor instantiation** creates eclasses for fields:
   ```
   Construct(Point, 2) → (ε₁, ε₂ → Point<ε₁, ε₂>)
   ```

2. **Usage unifies fields**:
   ```
   3 5 Point  →  unify(ε₁, int) && unify(ε₂, int)
   ```

3. **Struct extraction** collects unified types:
   ```
   Point<int, int>
   ```

This enables field type inference from usage patterns without explicit field annotations.

## 10. Type Resolution

Type resolution (`resolvePType` in `tools/poppy/type/resolve.flow:21-64`) determines if a type is fully resolved (no unbound eclasses).

### 10.1 Algorithm

```
resolvePType(env, seen, t):
    case PTypeName(name, typars):
        rtypars = [resolvePType(env, seen, τ) | τ ← typars]
        if all succeeded:
            return Some(PTypeName(name, rtypars))
        else:
            return None()

    case PTypeEClass(ε):
        root = findRoot(env.unionFindMap, ε)
        if root ∈ seen:
            return None()  // Unresolved cycle
        seen := seen ∪ {root}
        types = getUnionMapValue(env.unionFindMap, root)
        rtypes = [resolvePType(env, seen, t) | t ← types]
        if all succeeded:
            return Some(PTypeEClass(root))  // Keep as eclass to preserve name
        else:
            return None()

    case PTypeWord(inputs, outputs):
        rinputs = [resolvePType(env, seen, i) | i ← inputs]
        routputs = [resolvePType(env, seen, o) | o ← outputs]
        if all succeeded:
            return Some(PTypeWord(rinputs, routputs))
        else:
            return None()
```

### 10.2 Usage

Resolution is used in `mangoTypesOfRules` to determine if a rule's type can be simplified:

```
rtypes = resolvePTypes(env, ref makeSet(), types)
if rtypes != [] && types != []:
    if length(rtypes) == 1:
        env.words := setTree(^(env.words), rule, rtypes[0])
    setUnionMapValue(env.unionFindMap, eclass, rtypes)
```

If resolution succeeds, the eclass is updated with the resolved types and the rule's type is set to the single resolved type (if unique).

## 11. Polymorphism and Instantiation

### 11.1 Polymorphism Representation

Polymorphic types use the `?` placeholder syntax:
- `?` - primary type variable
- `??` - secondary type variable
- `???` - tertiary type variable, etc.

These are represented as `PTypeName("?", [])`, etc.

### 11.2 Instantiation

`instantiatePolymorphism` (`tools/poppy/type/instantiate.flow:10-37`) replaces `?` placeholders with fresh eclasses:

```
instantiatePolymorphism(unique, typars, type):
    case PTypeName(name, tps):
        if name is only "?" characters:
            existing = lookupTree(typars, name)
            match existing:
                Some(e): return e  // Reuse same eclass for same placeholder
                None:
                    eclass = PTypeEClass(^unique)
                    unique := ^unique + 1
                    typars := setTree(typars, name, eclass)
                    return eclass
        else:
            return PTypeName(name, [instantiate(..., tp) | tp ← tps])

    // Recurse for other types
```

### 11.3 Example

Polymorphic type: `dup: (? → ? ?)`

Instantiation at two call sites:
- Site 1: Creates `ε₁`, type is `(ε₁ → ε₁ ε₁)`
- Site 2: Creates `ε₂`, type is `(ε₂ → ε₂ ε₂)`

`ε₁` and `ε₂` are distinct, enabling separate unification:
- Site 1: `ε₁` unifies with `int`, type becomes `(int → int int)`
- Site 2: `ε₂` unifies with `string`, type becomes `(string → string string)`

No conflict because each use has its own instantiation.

## 12. Type Pretty Printing and Debugging

### 12.1 Pretty Printing

The pretty printer converts types to readable strings (defined in `tools/poppy/type/pretty.flow`):

**PTypeName**: Print name and type parameters
- `Int` → "int"
- `List<int>` → "list<int>"

**PTypeEClass**: Print as `εN` where N is the eclass id
- If eclass has values, can optionally print those
- If eclass has a name, can print as named union

**PTypeWord**: Print as `(inputs → outputs)`
- `(int int → int)` for binary operation
- `( → string)` for string literal

**PTypeOverload**: Print as `(t₁ | t₂ | ...)`

**PTypeEval**: Print as `eval`

**PTypeCompose**: Print as `t₁ ◦ t₂`

### 12.2 Environment Debugging

`debugPTypeEnv` prints the full state:
- All words and their types
- All eclasses and their constraints
- All unions and their constituents
- All structs

Enabled with `verbose > 2` parameter.

## 13. Comparison with Other Type Systems

### 13.1 Relationship to Hindley-Milner

**Similarities**:
- Unification-based inference
- Type variables (eclasses)
- Polymorphism through instantiation
- Let-polymorphism via definitions

**Differences**:
- Hindley-Milner: function types `α → β`
- Poppy/Mango: word types `([α...] → [β...])` with multiple inputs/outputs
- Hindley-Milner: application `f x`
- Poppy/Mango: composition `f ◦ g`
- Hindley-Milner: generalization at let-bindings
- Poppy/Mango: generalization at word definitions with implicit union extraction

### 13.2 Relationship to Substructural Type Systems

Poppy's stack-based nature relates to linear types:
- Each stack element is "consumed" exactly once by composition
- No implicit duplication (explicit `dup` required)
- No implicit dropping (explicit `drop` required)

However, the type system doesn't enforce linearity—it focuses on tracking stack transformations.

### 13.3 Relationship to Concatenative Language Type Systems

**Cat by Christopher Diggins**:
- Uses row polymorphism for stack types
- Stack type: `forall α. (α X Y → α Z)`
- Similar to Poppy's `PTypeWord` but explicit about stack remainder

**Factor**:
- Stack effect inference with declared effects
- Effects: `( x y -- z w )`
- More declarative than Poppy's fully inferred approach

**Poppy/Mango**:
- Fully automatic inference without annotations
- Implicit union extraction for flexibility
- Handles mutual recursion in grammars
- Integrates with parsing (Mango constructs produce typed parse trees)

## 14. Algorithmic Complexity

### 14.1 Time Complexity

**Type Inference**:
- Rules: O(R) where R is number of rules
- Terms per rule: O(T) where T is term size
- Composition per term: O(C) where C depends on overload branching
- Overall: O(R × T × C)

**Unification**:
- Union-find operations: O(α(N)) amortized per operation
- Unification per term: O(D) where D is type depth
- Overall: O(D × α(N)) per unification

**Elaboration**:
- Visits each type once: O(T)
- Composition attempts: O(C) per type
- Fixed-point iteration: usually 1-2 passes
- Overall: O(T × C)

**Struct Extraction**:
- Visits all types in environment: O(W + E) where W is words, E is eclasses
- Per-type traversal: O(D)
- Overall: O((W + E) × D)

### 14.2 Space Complexity

**Type Environment**:
- Words: O(W)
- EClasses: O(E)
- Union-find structure: O(E)
- Structs: O(S) where S is number of structs
- Overall: O(W + E + S)

**Type Representations**:
- Each type: O(D) for depth D
- Type parameters: multiplicative factor
- Shared structure via eclasses reduces duplication

## 15. Limitations and Future Work

### 15.1 Current Limitations

**Overloading**:
- Overload resolution can be ambiguous
- No prioritization or specificity ordering
- All compatible overloads are kept, potentially delaying resolution

**Union Naming**:
- Heuristic-based name selection
- May produce non-intuitive names
- No user control over union names (per current implementation comments)

**Field Naming**:
- Field names not tracked (per TODO comments in elaborate.flow)
- Struct fields are positional only
- Loss of semantic information from field names

**Implicit Unions**:
- Can be overly aggressive in creating unions
- Self-referential unions can occur (filtered but indicates issue)
- Union explosion with many eclasses

**Error Messages**:
- Type errors show internal representation
- No source location tracking (TODO in elaborate.flow)
- Difficult to map errors back to original source

### 15.2 Potential Improvements

**Row Polymorphism**:
- Explicit stack remainder types: `(α... X Y → α... Z)`
- Would enable more precise composition typing
- Better handling of stack-polymorphic operations

**Effect System**:
- Track side effects (I/O, state, etc.)
- Separate pure and impure operations
- Enable more reasoning about code behavior

**Type Classes/Traits**:
- Ad-hoc polymorphism for operations like `+`, `==`
- Overloading with resolution based on type class instances
- More structured than current `PTypeOverload`

**Dependent Types**:
- Length-indexed vectors
- Statically verified stack depths
- Refinement types for parsing (e.g., "non-empty string")

**Bidirectional Typing**:
- Mode analysis: check vs. infer
- Explicit type annotations guide inference
- Better error messages from expected vs. actual

**Field Records**:
- Named fields in structs: `Point {x: int, y: int}`
- Row polymorphism for records
- Structural subtyping

**Gradual Typing**:
- Mix of static and dynamic typing
- `Dynamic` type for unannotated code
- Runtime checks at boundaries

### 15.3 Research Directions

**Formalization**:
- Formal semantics for Poppy and Mango
- Soundness proof for type system
- Progress and preservation theorems

**Type Inference Decidability**:
- Current algorithm always terminates (via topological sort and cycle detection)
- Formal proof of termination
- Complexity bounds

**Completeness**:
- Is every well-typed program typeable?
- Are there programs that should type-check but don't?
- Principal types: does every expression have a most general type?

**Practical Evaluation**:
- Case studies on real-world grammars
- Performance benchmarks
- Comparison with other parser generators

## 16. Conclusion

The Poppy/Mango type inference system implements a sophisticated unification-based algorithm adapted for concatenative languages and parsing. Key contributions include:

1. **Composition-based inference**: Type checking via word composition rather than function application

2. **Equivalence classes for unification**: Efficient handling of type variables and constraints using union-find

3. **Implicit union extraction**: Automatic identification and naming of union types from usage patterns

4. **Recursion handling**: Placeholder technique for recursive and mutually recursive definitions

5. **Struct field inference**: Extraction of struct definitions with field types from constructors and usage

6. **Stack polymorphism**: Support for stack-polymorphic operations like `eval` via special composition rules

7. **Elaboration and resolution**: Multi-phase inference with elaboration to simplify composed types

The system successfully infers types for complex grammars with recursive definitions, producing structural types for parse trees. While there are areas for improvement (field naming, error messages, union control), the core algorithm is robust and handles real-world parsing tasks effectively.

The approach demonstrates that type inference for concatenative languages requires different techniques than traditional functional languages, particularly in handling composition, stack transformations, and the tight integration with parsing combinators in Mango.

## References

1. Christopher Diggins. "The Cat Programming Language" (2007)
   - Early work on type systems for concatenative languages

2. Northeastern University PRL. "Stack Languages: An Introduction"
   https://prl.khoury.northeastern.edu/blog/static/stack-languages-talk-notes.pdf
   - Theoretical foundation for stack-based type systems

3. Oleg Kiselyov. "Unification and Specialization"
   https://citeseerx.ist.psu.edu/document?repid=rep1&type=pdf&doi=17e9322160dc1e26cc85bb26f8ef7b8a560cb07c
   - Techniques for handling higher-order operations in type inference

4. Robert Tarjan. "Depth-First Search and Linear Graph Algorithms" (1972)
   - Topological sorting algorithm used for rule ordering

5. Bernard A. Galler and Michael J. Fischer. "An improved equivalence algorithm" (1964)
   - Union-find algorithm used for eclass management

## Appendix A: Type System Summary

### A.1 Type Grammar

```
τ ::= Name<τ₁,...,τₙ>           Named type
    | εᵢ                        Equivalence class (type variable)
    | (τ₁...τₙ → σ₁...σₘ)       Word type
    | (τ₁ | τ₂ | ... | τₙ)      Overloaded type
    | eval                      Eval type
    | τ₁ ◦ τ₂                   Composed type
```

### A.2 Composition Rules (Summary)

```
Name₁ ◦ Name₂ = ( → Name₁ Name₂)

(i₁... → ) ◦ (i₂... → o₂...) = (i₂... i₁... → o₂...)

(i₁... → o₁...) ◦ ( → o₂...) = (i₁... → o₁... o₂...)

(i₁... → o₁... b₁) ◦ (i₂... b₂ → o₂...) =
    if unify(b₁, b₂):
        (i₁... → o₁...) ◦ (i₂... → o₂...)
    else:
        ERROR

( → ( → o...)) ◦ eval = ( → o...)

( → inputs (fninputs → fnoutputs)) ◦ eval =
    match inputs with fninputs and curry
```

### A.3 Unification Rules (Summary)

```
unify(Name₁<τ...>, Name₂<σ...>):
    Name₁ = Name₂ ∧ ∀i. unify(τᵢ, σᵢ)  [if same name]
    isUpper(Name₁) ∧ isUpper(Name₂)    [if different names]

unify(ε, τ):
    bind(ε, τ)  [add τ to ε's constraints]

unify(ε₁, ε₂):
    merge(ε₁, ε₂)  [union-find merge]

unify((i₁... → o₁...), (i₂... → o₂...)):
    unify(i₁..., i₂...) ∧ unify(o₁..., o₂...)
```

### A.4 Inference Rules (Key Cases)

```
Γ ⊢ Construct(uid, n) : (τ₁,...,τₙ → Uid<τ₁,...,τₙ>)
    where τᵢ are fresh eclasses

Γ ⊢ term₁ : σ₁...    Γ ⊢ term₂ : σ₂...
─────────────────────────────────────────
Γ ⊢ Sequence(term₁, term₂) : {σᵢ ◦ σⱼ | σᵢ ∈ σ₁..., σⱼ ∈ σ₂...}

Γ ⊢ term₁ : σ₁...    Γ ⊢ term₂ : σ₂...
─────────────────────────────────────────
Γ ⊢ Choice(term₁, term₂) : sortUnique(σ₁... ++ σ₂...)

Γ[id ↦ ε] ⊢ body : τ    substitute(ε, τ, τ) = τ'
───────────────────────────────────────────────────
Γ ⊢ Rule(id, _, body) : τ'
    where ε is fresh eclass
```

## Appendix B: Implementation Statistics

Based on the source files analyzed:

- **Core type files**: 14 files in `tools/poppy/type/`
- **Mango integration**: 3 files in `tools/mango/` for type inference
- **Total lines**: Approximately 2,500 lines of type system code
- **Languages supported**: Poppy (concatenative) and Mango (PEG with actions)
- **Key algorithms**:
  - Unification: ~214 lines
  - Composition: ~308 lines
  - Elaboration: ~169 lines
  - Union extraction: ~144 lines
  - Struct extraction: ~81 lines

## Appendix C: Example Type Derivations

### C.1 Simple Sequence

**Code**: `3 4 +`

**Derivation**:
```
⊢ 3 : int
⊢ 4 : int
⊢ + : (int int → int)

3 ◦ 4:
    int ◦ int = ( → int int)

( → int int) ◦ (int int → int):
    Unify outputs [int, int] with inputs [int, int]
    Result: ( → int)

Final type: ( → int)
```

### C.2 Polymorphic Operation

**Code**: `dup`

**Type**: `(? → ? ?)`

**Usage**: `5 dup`

**Derivation**:
```
⊢ 5 : int
⊢ dup : (? → ? ?)

Instantiate dup: (ε₁ → ε₁ ε₁)

5 ◦ dup:
    int ◦ (ε₁ → ε₁ ε₁)
    = ( → int) ◦ (ε₁ → ε₁ ε₁)
    Unify int with ε₁
    = ( → int int)

Final type: ( → int int)
```

### C.3 Recursive Function

**Code**: `factorial = dup 1 <= [] [dup 1 - factorial *] ifte eval`

**Derivation**:
```
Create placeholder: ε_fact

⊢ dup : (ε₁ → ε₁ ε₁)
⊢ 1 : int
⊢ <= : (int int → bool)
...
⊢ factorial : ε_fact  [recursive reference]
...

Compose all operations:
    Result type before substitution: (int → int)

Substitute ε_fact with (int → int):
    No change (factorial not in type structure directly)

Final: factorial : (int → int)
```

## Appendix D: Source File Organization

```
tools/
├── poppy/
│   └── type/
│       ├── types.flow           - Core type definitions
│       ├── env.flow             - Type environment
│       ├── infer_type.flow      - Poppy type inference
│       ├── compose.flow         - Word composition
│       ├── unify.flow           - Unification algorithm
│       ├── elaborate.flow       - Type elaboration
│       ├── resolve.flow         - Type resolution
│       ├── unions.flow          - Implicit union extraction
│       ├── structs.flow         - Struct field extraction
│       ├── instantiate.flow     - Polymorphism instantiation
│       ├── substitute.flow      - Type substitution
│       ├── pretty.flow          - Pretty printing
│       ├── utils.flow           - Utility functions
│       ├── core.flow            - Core type conversions
│       └── name.flow            - Naming utilities
└── mango/
    ├── type_inference.flow      - Mango type inference (main entry)
    ├── rules.flow               - Rule discovery
    ├── topo.flow                - Topological sorting
    └── util.flow                - Mango utilities
```
