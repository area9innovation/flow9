# Flow9 Type Checker: Formal Rules

## 1. Type Lattice

Flow9's internal types (`FType`) form a lattice:

```
FBasicType — int, double, string, bool, void
FStruct(name, typars) — concrete struct types (e.g. Some<int>, ArrayNop)
    ↑
FUnion(name, typars) — named union types (e.g. Maybe<int>)
    ↑
FUnnamedUnion(types) — anonymous unions {A, B, C} (intermediate during inference)
    ↑
FFields(fields, seenNames, excluded) — row types (known fields, unknown struct)
    ↑
FFlow — top, any type (flow)
```

Subtyping relation `≤`:
- `S ≤ U` when struct S is a member of union U
- `T ≤ flow` for all T
- `FUnion ≤ FUnnamedUnion` when all union members are in the unnamed union
- `FStruct ≤ FFields` when struct has all fields in the row type

Additional types:
- `FTypeVar(id)` — type variable (tyvar), resolved during inference
- `FTypePar(id)` — type parameter `?`, `??`, etc. (from polymorphic definitions)
- `FFunction(args, rt)` — function type
- `FArray(type)` — array type
- `FRef(read, write)` — reference type
- `FBounded(lower, upper)` — bounded type range `{lower .. upper}`

**`FTopBottom`** is NOT a type in the lattice. It is a sentinel used only inside `FBounded` to mark an open (unconstrained) end of a bounded range. When one side of a unification is `FTopBottom`, the other side is used as-is — it simply means "no information yet":
```
unify(FTopBottom, T) = T
unify(T, FTopBottom) = T
```
Once the bound is filled with a real type, normal subtyping rules apply.

## 2. Constraints

The type checker works in two phases:

**Phase 1 — Constraint generation** (typechecker.flow): Walks the AST and emits constraints. Each expression generates constraints between the types of its subexpressions. Constraints are recorded as `FcTypeExpect` values in `env.local.expects`.

**Phase 2 — Constraint solving** (ftype_solve.flow): Processes constraints one by one. Each constraint translates to a `unifyType` call with a specific `FUnification` kind (see §4). Solving a constraint may update tyvars, which affects subsequent constraints. The order of processing matters — constraints are solved in the order they were generated (FIFO from the `List<FcTypeExpect>`).

A constraint relates two `FcType` expressions with a direction. For example, `FcLessOrEqual(type(arg), paramType)` means "the argument type must be a subtype of the parameter type." During solving, both sides are converted from `FcType` to `FType` via `fctype2ftype`, then unified.

Constraint kinds are described in detail in §5.

## 3. Type Variables (Tyvars)

Each tyvar `αᵢ` maps to an `FType` in `env.tyvars : Tree<int, FType>`.

**Lifecycle:**
1. Created as unbound (no entry in tyvars)
2. First constraint (§2) sets the initial value
3. Subsequent constraints refine via unification (grow_right, reduce_left, etc.)
4. Finalization resolves remaining bounds and deps

**Dependencies** (`env.tyvarDeps : Tree<FType, [FUnifyType]>`):

When two tyvars are related by a constraint, the solver records a dependency so the constraint can be re-checked later. The key is `FType` (typically `FTypeVar(id)`), the value is a list of `FUnifyType(kind, targetType)`.

Example: processing a constraint `α₁ ≤ α₂` (α₁ is subtype of α₂) records `deps[α₁] += FUnifyType(FUnifyLeft, α₂)`.

This means: "whenever α₁ changes, re-check that α₁ ≤ α₂ still holds."

Dependencies are re-executed during finalization's `rerunDeps` phase (§8). At that point, tyvars may have been refined by other constraints, so re-running dependencies propagates new type information transitively. For example:
```
α₁ = Tree<int, CalendarEvent>     (from assignment)
α₁ ≤ α₂                           (from function call)
α₂ ≤ Tree<int, MyUnion>           (from another constraint)
```
After initial solving, `rerunDeps` re-checks `α₁ ≤ α₂` with their current values, propagating the relationship.

**Polarity** (`env.tyvarPolarity : Tree<int, int>`):

Each tyvar has a polarity classification derived from where it appears in constraints:
- `+1` = **covariant** — appears only in output/positive positions
- `-1` = **contravariant** — appears only in input/negative positions
- `0` = **invariant** — appears in both, or in ref/mutable positions
- absent = unclassified (treated as invariant)

Polarity is collected by `collectTyvarPolarity` (see §9) before finalization and used by `setFTyvar` during final type resolution (see §10).

## 4. Bounded Types: `{lower .. upper}`

A tyvar holding `FBounded(lower, upper)`:
- **lower**: the most specific type the value ACTUALLY has (accumulated from all sources)
- **upper**: the most general type the value can be USED AS (accumulated from all usage sites)
- **Invariant**: `lower ≤ upper` must always hold

Creation:
- `makeFBounded(env, lower, upper, onError)`: if `lower == upper`, returns the type directly. If `lower == FTopBottom`, returns `FBounded(FTopBottom, upper)`. Otherwise creates `FBounded(lower, upper)`.
- `makeFBoundedEnv(env, lower, upper, kind, ...)`: dispatches to special cases:
  - Same-name FStruct: calls `unify()` (recursive unification of type params)
  - Same-name FUnion: calls `unify()` (recursive unification of type params)
  - Different-name FUnion: calls `def()` (creates `FBounded` range)
  - FStruct vs FFields: if all fields match struct, calls `unify()`; otherwise `def()`
  - All other: `def()` → `makeFBounded`

**Bounds helpers:**
```
lowerBound({l..u}) = l     lowerBound(T) = T  (for non-bounded)
upperBound({l..u}) = u     upperBound(T) = T  (for non-bounded)
```

## 5. Unification Kinds

Four operations, each with distinct semantics for what they return and how they modify types.

### 5.1 FGrowRight — Join (Least Upper Bound)

**Semantics**: `grow_right(A, B) = C` where C is the smallest type containing both A and B (their join/union).

The name "grow_right" reflects the implementation: the right operand is the accumulator that grows to include the left operand. In `grow_right(newValue, accumulator)`, the accumulator expands. The result is the new accumulator value.

**Purpose**: Accumulate the type from multiple value sources. Used for:
- Array construction: `[a, b, c]` — result type grows to accommodate all elements
- If/else branches: `if (...) a else b` — result grows to contain both
- Switch case results: result type grows across all case bodies

**Key rules:**

1. **Same parameterized type.** If both sides have the same name `A` (whether struct or union), type parameters are unified recursively:
   ```
   grow_right(A(m), A(n)) = A(grow_right(m, n))
   ```

2. **Struct member of a union** — see Rules G1/G2 below.

3. **Unrelated structs** with no common parent union form an anonymous union:
   ```
   grow_right(Foo, Bar) = FUnnamedUnion(Foo, Bar)
   ```

#### Rules G1 and G2: Struct-Union Join (Type Parameter Propagation)

When growing a struct into its parent union, the struct may carry type information in its fields that corresponds to the union's type parameters.

**Rule G1 (Parametric struct)**: If the struct uses the parent union's type parameters in its fields, the struct's type params propagate to the union:

Example — building `[Cons<Form>, EmptyList]`, the solver computes the join of all elements:
```
List<?> ::= EmptyList, Cons<?>;
Cons(head : ?, tail : List<?>);
EmptyList();

grow_right(EmptyList, Cons<Form>) = List<Form>
```
`EmptyList` has no `?` field (Rule G2), but `Cons.head : ?` tells us `? = Form` (Rule G1).

**Rule G2 (Phantom struct)**: If the struct does NOT use any of the parent union's type parameters, the union's existing type params are preserved:

Example:
```
grow_right(EmptyList, List<int>) = List<int>
```
`EmptyList` has no fields using `?` — it carries no information about what `?` should be. The union's existing `? = int` is kept.

Another example with `Maybe`:
```
Maybe<?> ::= None, Some<?>;
Some(value : ?);
None();

grow_right(None, Maybe<Json>) = Maybe<Json>
```
`None` has no `?` field, so `Maybe`'s existing type param `Json` is preserved.

**Current implementation status**: `funifyUnionAndStruct` in the FGrowRight path unifies the struct's type params with the union's type params (via `unifyTypes`), but returns the original union unchanged:

```flow
// funify_cases.flow, funifyUnionAndStruct, FGrowRight path:
et = fns.unifyType(env, leftt, rightt, FGrowRight(), fns.onError);
FEnvType(et.env, union);  // returns original union, not grown type params
```

The returned union type always keeps its original type params — the explicit Rule G1 return-type propagation is not implemented. However, this works correctly in practice through **side effects**: the union's type params are typically `FTypeVar`s, and the `unifyType` call updates those tyvars in the returned `et.env.tyvars`. When the union is later resolved (during `ftype2fctype` finalization), those tyvars are looked up and give the correct types.

This means G1 is implemented via side effects rather than explicit return-value propagation. It is a **code smell** (fragile, relies on tyvars being the type params) but not a functional bug in the current system, because union type params at this point in inference are always tyvars.

The `gl1` guard in `funifyBounded` (§5.2) provides an additional safety net for cases where the lower bound of a bounded type needs to reflect grown type params. See §11.

### 5.2 FUnifyLeft — Subtype Check (left ≤ right)

**Semantics**: `unifyLeft(A, B)` verifies that A is a subtype of B. Returns the **new left-hand side**.

**Purpose**: Containment checks. Used for:
- Function arguments: `f(x)` generates `type(x) ≤ paramType`
- Let bindings with annotations: `x : T = expr` generates `type(expr) ≤ T`
- Switch variable: `type(x) ≤ switchType`
- Cast expressions: `cast(e : From -> To)` — see below

**Constraint origin**: `FcLessOrEqual(e1, e2, ...)` → `unifyType(e1, e2, FUnifyLeft(), ...)` at line 136 of `ftype_solve.flow`.

**Key rules:**

- **Struct ≤ its union**: `Some ≤ Maybe` — struct fits in its parent union
- **Same parameterized type**: `unifyLeft(A<m>, A<n>)` = `A<unify(m,n)>` — check type params match
- **Subunion ≤ superunion**: all members of the left union are also members of the right union

#### Rules for Bounded Types in FUnifyLeft

**Rule U1 (bounded on left)**: Checking `{l₁ .. u₁} ≤ T`:
```
Step 1: etr = grow_right(l₁, T)    — check lower bound fits target
Step 2: etl = reduce_left(u₁, T)   — narrow upper bound to target
Result: makeFBoundedEnv(l₁, etl.type)
```

**CRITICAL**: The lower bound `l₁` is NOT replaced by `etr.type`. The lower bound represents what the value **actually is**. A subtype check verifies compatibility but does not change the value's actual type.

**Exception (gl1 guard, current workaround)**: When both `l₁` and `etr.type` are `FUnion` with the same name, the gl1 guard replaces `l₁` with `etr.type`. This compensates for cases where the grow_right side-effect mechanism (§5.1) doesn't fully propagate type params to the lower bound of a bounded type. See §11 for details.

**Rule U2 (bounded on right)**: Checking `T ≤ {l₂ .. u₂}`:
```
Step 1: etl = reduce_left(u₂, T)   — narrow upper bound
Step 2: etr = grow_right(l₂, T)    — grow lower bound (new value source)
Result: makeFBoundedEnv(l₂, etl.type)
```

The lower bound `l₂` is preserved (not replaced by `etr.type` — the gl2 guard was removed to fix Bug 6).

### 5.3 FReduceLeft — Meet (Greatest Lower Bound)

**Semantics**: `reduce_left(A, B) = C` where C is the largest type contained in both A and B. Returns the **new left-hand side** (the accumulated type shrinks leftward).

**Purpose**: Narrow the upper bound. Used in:
- Bounded type resolution: `reduce_left(upperBound, constraint)` narrows the upper bound
- `funifyBounded` step 2 in FUnifyLeft path

**Key rules:**

- **Same parameterized type**: `reduce_left(A<m>, A<n>)` = `A<reduce_left(m,n)>` — narrow type params recursively
- **Struct in its union**: `reduce_left(Some<m>, Maybe<n>)` = `Some<reduce_left(m,n_mapped)>` — struct is narrower, keep it

### 5.4 FUnifyRight — Subtype Check (right ≤ left)

**Semantics**: Symmetric to FUnifyLeft with sides swapped. `unifyRight(A, B)` verifies B ≤ A. Returns the **new right-hand side**.

## 6. Constraint Kinds

#### FcLessOrEqual (→ FUnifyLeft)

The primary constraint. Generated as `FcLessOrEqual(source, target, description, info, expr)`.

Processing (ftype_solve.flow:136-145):
```
FcLessOrEqual(e1, e2, d, info, ex):
    left = fctype2ftype(env, e1)
    right = fctype2ftype(env, e2)
    unifyType(env, left, right, FUnifyLeft(), onError)
```

Sources:
- **Function call**: `f(arg)` → `FcLessOrEqual(type(arg), paramType)`
- **Let binding with annotation**: `x : T = e` → `FcLessOrEqual(type(e), T)`
- **Switch result**: each case body → `FcLessOrEqual(caseType, switchResultType)`
- **Array element**: `[a, b]` → `FcLessOrEqual(type(a), arrayElemType)`, `FcLessOrEqual(type(b), arrayElemType)`
- **If branches**: `FcLessOrEqual(thenType, resultType)`, `FcLessOrEqual(elseType, resultType)`
- **Struct construction**: `S(a, b)` → `FcLessOrEqual(type(a), fieldType)`
- **Switch cases**: `FcLessOrEqual(caseType, unionType)` — case type fits switch type
- **Cast**: `cast(e : From -> To)` — three cases:
  1. **Primitive conversions** (int, double, string): no subtype check, built-in
  2. **Strict mode**: `FcLessOrEqual(fromType, toType)` — only upcasts allowed
  3. **Non-strict mode** (default): `FcLessOrEqual(toType, supertype)` and `FcLessOrEqual(fromType, supertype)` — only requires a common supertype
  In all cases, the expression type is verified: `FcVerifyType(type(e), fromType)`

#### FcGrowToFit (→ FGrowRight)

Like FcLessOrEqual, but uses `FGrowRight` instead of `FUnifyLeft`. Designed for function call arguments where a shared type parameter needs to grow (join/LUB) rather than be checked for containment.

Infrastructure is in place (`type_expect.flow`, `ftype_solve.flow`, `ftype_finalize.flow`) but **not currently emitted** at any call site. See `typechecker_improvements.md` §4 for why — FGrowRight is too aggressive for lambda parameters that need field access.

#### FcVerifyType

Similar to FcLessOrEqual but only verifies compatibility without constraining.

Used for:
- Let binding WITHOUT annotation: `x = e` → `FcVerifyType(type(e), freshTyvar)`
- Switch variable verification

#### FcExpectField

Generated for field access: `expr.fieldName` → `FcExpectField(fieldName, fieldType, exprType)`.

Resolves to `FFields` row type that constrains the expression to have the named field.

#### FcSetMutableField

Generated for mutable field assignment: `expr.field ::= value` → `FcSetMutableField(exprType, fieldName, valueType)`.

#### FcCheckAnnotation

Post-solve check for type annotations. Generated alongside `FcLessOrEqual` for let bindings with explicit type annotations:
```
x : T = expr
→ FcLessOrEqual(type(expr), T)       // for inference
→ FcCheckAnnotation(type(expr), T)   // post-solve verification
```

Checked in `checkFinalTypeExpect` after all constraints are resolved. Detects incompatible type annotations that `FcLessOrEqual` silently accepted during inference.

## 7. Tyvar Update Dispatch

When a constraint involves a tyvar, the solver dispatches based on the kind:

```
unifyTyvar(env, id, type, left, kind):
    ftype = env.tyvars[id]    // current tyvar value

    FUnifyLeft/FUnifyRight:
        result = unifyType(ftype, type, kind)
        env.tyvars[id] = result
        return the side that is NOT the tyvar

    FGrowRight:
        result = unifyType(ftype, type, FGrowRight)
        env.tyvars[id] = result
        return the side that is NOT the tyvar

    FReduceLeft:
        result = unifyType(ftype, type, FReduceLeft)
        env.tyvars[id] = result
        return the side that is NOT the tyvar
```

**Orientation**: `left=true` means the tyvar is on the left of the operation.
- `growRightTyvar`: grows `ftype` to accommodate `type`:
  ```
  left=true:  grow_right(ftype, type)  → α grows rightward
  left=false: grow_right(type, ftype)  → α grows rightward
  ```
- `unifyTyvar` (FUnifyLeft, left=true): `unifyType(ftype, type, FUnifyLeft)` — current value must fit in target
- `unifyTyvar` (FUnifyLeft, left=false): `unifyType(type, ftype, FUnifyLeft)` — target must fit in current value

**Tyvar-vs-tyvar** (`unifyTyvars`): Criss-cross pattern:
```
α₁ ≤ α₂:
    1. unifyTyvar(α₂, value(α₁), left=false)  // push α₁'s value to α₂
    2. unifyTyvar(α₁, value(α₂), left=true)   // push α₂'s value back to α₁
    3. addDependency(α₁ ≤ α₂)                 // record for rerunDeps
```

## 8. Finalization Pipeline

After all constraints are processed, `finalizeIteration` resolves remaining tyvars:

```
Phase 1 (Exact):
    resolveAllTypes    — resolve FFields and unnamed unions
    resolveBounds(0)   — unify bounds (exact)
    rerunDeps          — re-execute tyvar dependencies

Phase 2 (Heuristic):
    resolveKisses      — resolve Cassiopeia constructs
    resolveCassiopeia   — collect {..u ≤ α} patterns → α = union of uppers
    resolveCassiopeia2  — second pass

Phase 3 (Final):
    resolveBounds(1)    — heuristic bound resolution
    resolveBounds(2)    — resolve remaining lower-bound-only tyvars
    rerunDeps           — re-execute deps with final values
    resolveTyvarVsTyvar — fix tyvar-vs-tyvar conflicts
    resolveTyvarsToTypars — bind unbound tyvars to type parameters
    setFTyvar           — commit all tyvars to final types (uses per-tyvar polarity, see §10)
    checkFinalTypeExpect — run FcCheckAnnotation checks
```

**rerunDeps**: Iterates `env.tyvarDeps`, re-executing each recorded dependency:
```
for each (from → [FUnifyType(kind, to)]) in tyvarDeps:
    if both sides are determined: skip (optimization)
    else: funify(from, to, kind)
```

**Bug 6 contamination mechanism**: During `rerunDeps`, a dependency `α₁ ≤ α₂` is re-executed. If α₂ was widened by another constraint since the original processing, α₁ gets contaminated with the wider type.

## 9. Per-Tyvar Polarity Collection

Polarity is collected from the constraint positions **after constraint solving, before finalization**. The function `collectTyvarPolarity` (in `ftype_solve.flow`) walks all `FcTypeExpect` constraints and classifies each tyvar.

**Algorithm:**

For each constraint:
- `FcLessOrEqual(output, input, ...)`: tyvars in `output` are covariant (+1), tyvars in `input` are contravariant (-1)
- `FcGrowToFit(output, input, ...)`: same as FcLessOrEqual
- `FcVerifyType(e1, e2, ...)`: both sides are invariant (0) — verify checks both directions
- `FcExpectField(_, fieldType, t, ...)`: both `t` and `fieldType` are covariant (+1)
- `FcSetMutableField(struct, _, ftype, ...)`: `struct` is covariant (+1), `ftype` is contravariant (-1)

**Within a type**, polarity propagation follows variance rules:
- Array element: same polarity as parent
- Function args: **flipped** polarity (contravariant position)
- Function return: same polarity as parent
- Ref type: invariant (0) — both read and written
- Struct mutable fields: invariant (0)
- Struct immutable fields: same polarity as parent
- Union/struct type params: same polarity as parent

**Merging**: If a tyvar appears with the same polarity in multiple constraints, it keeps that polarity. If it appears with conflicting polarities (e.g. +1 in one constraint, -1 in another), it becomes invariant (0).

The result is stored in `env.tyvarPolarity : Tree<int, int>`, mapping tyvar id to polarity.

**Why per-tyvar, not per-evaluation-context**: An earlier approach threaded a `positive:bool` parameter through `ftype2fctype` and flipped it at function arg positions during finalization. This was fundamentally flawed: the same tyvar's `FBounded` could be resolved through multiple code paths at different polarities during a single finalization, producing inconsistent results. Per-tyvar polarity ensures each tyvar gets a single, consistent classification.

## 10. FBounded Resolution and Polarity

During finalization, `setFTyvar` commits each tyvar to a final `FcType`. When the tyvar's value is `FBounded(lower, upper)`, the polarity determines which bound to prefer:

```
setFTyvar(env, tyvar, type, onError):
    polarity = lookupTreeDef(env.tyvarPolarity, tyvar, 0)
    positive = (polarity >= 0)    // covariant or invariant → true
    ftype2fctype(env, type, seen, positive, onError)
```

- **positive=true** (covariant or invariant): prefer lower bound (most specific actual type)
- **positive=false** (contravariant): prefer upper bound (most general required type)

Example:
```
tyvar α has bounds {Cons<string> .. List<string>}

If α is covariant (only in output positions):
    → resolves to Cons<string> (lower, most specific)

If α is contravariant (only in input positions, e.g. lambda parameter):
    → resolves to List<string> (upper, most general)
```

When `ftype2fctype` encounters `FTypeVar(id)` during recursive resolution, it also uses that tyvar's own polarity (not the inherited context):

```
FTypeVar(id):
    ot = lookupTree(env.tyvars, id)
    polarity = lookupTreeDef(env.tyvarPolarity, id, 0)
    positive = (polarity >= 0)
    ftype2fctype(env, ot, seen, positive, onError)
```

This ensures each tyvar in a chain is resolved according to its own polarity classification, not the context of the outer tyvar being finalized.

**Resolution path**: `ftype2fctype` → `FBounded(lower, upper)` → `frange2fctype(lower, upper)` → `combinePositiveAndNegative(lower, upper, positive)` → returns candidates ordered by polarity → `ftypes2fctypes` picks first element.

## 11. Named Union Resolution

### struct2unions

`env.env.program.acc.names.struct2unions : Tree<string, [string]>` maps each struct name to the list of union names it belongs to.

Key property: Only maps STRUCT names, not union names. To find if a union name is known, use `lookupTree(env.env.program.acc.names.unions, name)`.

### Common parent check

`unnamedUnionsShareCommonUnion(env, names)`: checks if ALL struct names in the set share at least one common parent union. Used in Bug 5/5b fixes to allow unnamed unions like `{MathRoundingOption, IsEqualMathsStrict}` when both are members of `IsEqualMathsOption`.

## 12. Switch Type Checking

For `switch (x : T) { Case1(): ...; Case2(): ...; }`:

1. `tt` = fresh tyvar for switch result type
2. For each case: `FcLessOrEqual(caseBodyType, tt)` — body type grows result
3. For struct cases: bind case variable to struct type, check `FcLessOrEqual(structType, switchType)`
4. For union cases: expand union to leaf structs, check `FcLessOrEqual(unionType, switchType)`
5. For polymorphic union cases: add `FcLessOrEqual(varType, un)` to link type params

**Union case switch type**: Uses `unionType` (the type of the switch expression after widening to its union) instead of `varType` (the raw type of x). This ensures the switch variable inside a union case body has the correct union type.

## 13. Known Bugs and Limitations

### Bug 4 (gl1 compensates for incomplete G1)

`grow_right(Some<GR>, Maybe<TR>)` unifies GR and TR as a side effect via tyvars, but returns `Maybe<TR>` (the original union). Since TR is a tyvar that now points to the grown result in env.tyvars, this usually works correctly. However, when the result feeds into a bounded type's lower bound (e.g. `FBounded(Maybe<TR>, ...)`), the lower bound captures the FUnion struct with the original tyvar references. The `gl1` guard in `funifyBounded` patches this by replacing the lower bound with the grown result when both are same-name `FUnion`.

### Bug 6 (gl1 contaminates Tree types)

`gl1` replaces `Tree<int, CalendarEvent>` with `Tree<int, UnionMessage>` because Tree is `FUnion("Tree", ...)` and matches the same-name guard. The guard is too broad — it fires for ALL same-name unions, not just the cases where G1 side effects need help. A proper fix would either: (a) make gl1 more selective (only fire when the lower bound's tyvars are still unresolved), or (b) make `funifyUnionAndStruct` return explicit grown type params so gl1 is unnecessary.

### Annotation masking

Type annotations `x : T = expr` set the type environment to `T` (not `type(expr)`). All downstream uses of `x` see `T`. If `T` is narrower than `type(expr)`, the annotation silently hides the mismatch during inference. The post-solve `FcCheckAnnotation` partially catches this.

### getFiUnionRelation disabled

`isFiSubType`'s `getFiUnionRelation` is disabled — returns `FiRelationEqual()` for ALL union-vs-union comparisons. Comment: "We cause too many false positives, so turn things off for now." This means the type verifier cannot distinguish sub/super union relationships.

### wigi_difference.flow type error (exposed by G1 fix)

Fixing G1 more aggressively could expose a real type error in `wigi_difference.flow`. The struct `MergeReplacesData` declares:
```flow
nops : [Pair<ArrayOperation<WigiText>, ArrayReplace<WigiText>>]
```

But the fold iterates over `protocol : [ArrayOperation<WigiElement>]`, and at line 675:
```flow
Pair(op, ArrayReplace(oldindex, newindex, element))
```
`op` has type `ArrayOperation<WigiElement>` (from the fold parameter), not `ArrayOperation<WigiText>`. This code is inside a `WigiText(__, __):` switch case which narrows `element` to `WigiText`, but `op` is NOT narrowed — it remains `ArrayOperation<WigiElement>`.

The constraint is `FcLessOrEqual` (subtype check), not FGrowRight. So the issue is not in constraint resolution — it's a genuine type mismatch. The current compiler silently accepts it because type parameter propagation through side effects doesn't always catch this level of detail.

Fix: change `nops` field type to `[Pair<ArrayOperation<WigiElement>, ArrayReplace<WigiElement>>]`, or narrow `op` explicitly.

### FRef unification bug (pre-existing)

`FRef` unification uses the same `kind` for both read and write types, but write should be contravariant. Currently:
```flow
FRef(rt1, wt1) vs FRef(rt2, wt2):
    unify(rt1, rt2, kind)    // read type: correct (covariant)
    unify(wt1, wt2, kind)    // write type: should use flipped kind (contravariant)
```

## 14. Implementation Map

| Rule | File | Function | Status |
|------|------|----------|--------|
| G1/G2 | funify_cases.flow:321 | funifyUnionAndStruct | WORKS VIA SIDE EFFECTS (returns original union, tyvars updated) |
| U1 (gl1) | funify_cases.flow:1176 | funifyBounded | WORKAROUND (gl1 guard, too broad — causes Bug 6) |
| U1 (gl2) | funify_cases.flow:1193 | funifyBounded | FIXED (gl2 removed) |
| Tyvar update | ftype_solve.flow:493 | unifyTyvar | OK |
| Grow right | ftype_solve.flow:641 | growRightTyvar | OK |
| Reduce left | ftype_solve.flow:677 | reduceLeftTyvar | OK |
| Tyvar deps | ftype_solve.flow:711 | unifyTyvars | OK |
| Bounded creation | ftype_bound.flow:19 | makeFBoundedEnv | OK |
| Finalization | ftype_finalize.flow:75 | finalizeIteration | OK |
| RerunDeps | ftype_finalize.flow:236 | rerunDeps | KNOWN ISSUE (contamination) |
| Annotation check | ftype_finalize.flow | checkFinalTypeExpect | OK |
| Common parent | funify_cases.flow | unnamedUnionsShareCommonUnion | OK |
| Per-tyvar polarity | ftype_solve.flow | collectTyvarPolarity | OK (collects from constraints) |
| Polarity in resolution | ftype2fctype.flow | setFTyvar | OK (uses tyvarPolarity) |
| Polarity in FTypeVar | ftype2fctype.flow | ftype2fctype FTypeVar case | OK (per-tyvar lookup) |
| FcGrowToFit | type_expect.flow + solver | — | INFRASTRUCTURE ONLY (not emitted) |
| FRef variance | funify_cases.flow | funifyRef | BUG (write type not contravariant) |
