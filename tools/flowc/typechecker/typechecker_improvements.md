# Type Checker Improvements

## 1. Contradictory type parameter constraints

When a polymorphic function like `fif(Transform<bool>, Transform<?>, Transform<?>) -> Transform<?>`
receives arguments with different inner types (e.g. `Transform<Maybe<MFocus>>` and
`Transform<Maybe<MFocusGroup>>`), the type parameter `?` should resolve to the join
(`Maybe<MaterialFocus>`). Currently the compiler silently picks one value and reports
a type error on the other argument with a misleading message showing the wrong expected type.

The compiler should detect when a type parameter has contradictory constraints and
report "cannot resolve type parameter" with both conflicting types shown, rather than
silently picking one and producing confusing swapped-type errors.

Pre-existing bug. Repro: `tools/flowc/tests/fif_repro.flow`

## 2. Fresh Tyvars in grow_right(struct, union)

## Problem

In `funifyUnionAndStruct`, when computing `grow_right(Some<MTB>, Maybe<α>)`:

```
inst = Some<α>              // α is union's shared tyvar
unifyType(Some<MTB>, Some<α>, FGrowRight)  // side effect: α = MTB
return Maybe<α>             // α contaminated by side effect
```

The `FGrowRight` unification directly mutates `α` via `growRightTyvar`.
This is wrong because `α` is the union's type parameter shared across
all members. Setting `α = MTB` contaminates all other uses of `α`.

Moreover, `α` could be **less** than MTB — `None` is also a member of
`Maybe<α>` and doesn't constrain `α` at all.

## Fix: Fresh Result Tyvars

The result of `grow_right(struct, union)` should use **fresh** type
parameters, decoupled from both inputs. This is the same pattern as
introducing a binding `v : T = expression; v;` instead of returning
`expression` directly.

```
grow_right(Some<MTB>, Maybe<α>)

α_1 = fresh tyvar
add constraint: MTB ≤ α_1     // result accommodates struct's param
add constraint: α ≤ α_1       // result accommodates union's existing param
return Maybe<α_1>              // fresh, decoupled from both inputs
```

No `unifyType(..., FGrowRight)` call on the struct params. No side
effects on `α`. The fresh `α_1` is resolved by the solver as the join
of its lower bounds through normal constraint propagation.

## Proposed Implementation

In `funifyUnionAndStruct`, FGrowRight path:

1. For each union type parameter `αᵢ`, create a fresh tyvar `αᵢ'`
2. For each struct type param position, extract the concrete type `Tᵢ`
3. Add constraint `Tᵢ ≤ αᵢ'` via `unifyType(Tᵢ, αᵢ', FUnifyLeft)`
4. Add constraint `αᵢ ≤ αᵢ'` via `unifyType(αᵢ, αᵢ', FUnifyLeft)`
5. Return `FUnion(name, [α₀', α₁', ...])`

The struct's concrete type params and the union's existing params both
become **lower bounds** on the fresh result params. The solver resolves
each `αᵢ'` to the join of its lower bounds.

### Status: REVERTED

Attempted in commit 619333e2c, reverted in commit 90bf0dd28. Two problems:
1. **Phantom params** (like `?` in `None()`): fresh tyvars with no lower
   bounds created infinite chains of unresolved tyvars.
2. **Non-phantom params** (like `Cons`): fresh tyvars incorrectly narrowed
   `List` to `Cons` because the fresh tyvar's only lower bound was the
   struct's concrete param.

The current implementation works through side effects: `funifyUnionAndStruct`
calls `unifyType(inst, struct, FGrowRight)` which updates tyvars in the
union's type params as a side effect, then returns the original union. This
is correct because union type params at this point are always tyvars, so
they get updated via `et.env.tyvars` and resolve correctly later.

## 3. Same bug in reduce_left(struct, union) during bounds resolution

### Problem

The same contamination happens in the `reduce_left` path of
`funifyUnionAndStruct`, triggered during finalization bounds resolution.

When the solver has a bounded tyvar `{Some<MFocusGroup> .. Maybe<α>}`
where `α = MaterialFocus`, it checks lower ≤ upper via `reduce_left`:

```
reduce_left(Some<MFocusGroup>, Maybe<α=MaterialFocus>)
→ instantiate Maybe to matching struct: Some<α>
→ reduce_left(MFocusGroup, α=MaterialFocus)
→ sets α = MFocusGroup          ← CONTAMINATES shared tyvar!
```

The check should verify `Some<MFocusGroup> ≤ Maybe<MaterialFocus>`
without mutating α. The answer is "yes" (MFocusGroup is a member of
MaterialFocus), but the side effect narrows α from MaterialFocus to
MFocusGroup, corrupting all other types that share α.

### Where it happens

In `fif_repro.flow`, function `getCurrentActiveItemBehaviour2`:

```flow
switchMaterialFocus(foc,
    \f -> fif(f.active, const(Some(f)), acc),                         // f : MFocus
    \f -> fif(f.active, const(Some(f)), getCurrentActiveItemBehaviour2(f))  // f : MFocusGroup
)
```

`const`'s type parameter in each branch gets bounded:
- Branch 1: `{Some<MFocus> .. Maybe<α>}`        (α = MaterialFocus)
- Branch 2: `{Some<MFocusGroup> .. Maybe<α>}`    (same α!)

α is shared because both fif results are joined through
switchMaterialFocus into fifsome's single type parameter.

Bounds resolution of branch 1 sets α = MFocus. Then bounds
resolution of branch 2 finds α = MFocus and errors:
"Expected MFocus, got MFocusGroup".

### Fix

Same approach as item 2: fresh tyvars in the `reduce_left` path of
`funifyUnionAndStruct`. The bounds check should not mutate the
union's type parameters.

### Status: NOT IMPLEMENTED

The fresh-tyvar approach for FGrowRight (item 2) was reverted due to
regressions. The reduce_left case has the same fundamental problems
(phantom params, chain explosion). This remains an open issue.
Pre-existing bug. Repro: `tools/flowc/tests/fif_repro.flow`.

## 4. FGrowRight for shared type parameters in function calls

### Problem

When a polymorphic function like `fif : (?, (?) -> ??, ??) -> ??` is called,
`instantiateTypeTyPars` creates ONE tyvar per type parameter name: α for `?`,
β for `??`. The same α is shared across all argument positions where `?` appears.

Currently, each argument emits `FcLessOrEqual(argType, paramType)` which maps to
`FUnifyLeft` in the solver. `FUnifyLeft` triggers `reduce_left(struct, union)`
in `funifyUnionAndStruct`, which mutates the shared tyvar as a side effect.
The first argument that resolves the shared tyvar "locks" it, and subsequent
arguments with different concrete types cause errors.

Example: `fif(someExpr, const(Some(focus)), acc)` where someExpr has type
`Transform<bool>`, the second arg has type `Transform<Maybe<MFocus>>`, and
acc has type `Transform<Maybe<MFocusGroup>>`. The shared `??` (β) gets locked
to `Maybe<MFocus>` from the second arg, then the third arg fails because
`Maybe<MFocusGroup> ≤ Maybe<MFocus>` is not valid.

The correct result: β should grow to `Maybe<MaterialFocus>` (the join/LUB of
MFocus and MFocusGroup).

### Attempted fix: FcGrowToFit

Tried emitting `FcGrowToFit` (using `FGrowRight`) instead of `FcLessOrEqual`
(`FUnifyLeft`) for arguments with shared type parameters. Infrastructure added
(`FcGrowToFit` in `type_expect.flow`, handled in solver and finalize).

**Result: too aggressive.** `FGrowRight` grows the shared tyvar to the parent
union, which is wrong for types used as lambda parameters. Example:
`fold_deferred(foldedTree, init, \acc, node -> { ... foldTree(node, ...) }, onDone)`
— `?` is shared across args 1 and 3. FGrowRight grows `?` from `TreeNode` to `Tree`,
but the lambda parameter `node` must stay `TreeNode` (needs `.depth` field access).
The call-site approach changes the fundamental constraint direction, breaking
struct-level field access on lambda parameters.

### Status

FcGrowToFit infrastructure is in place but NOT used. The fresh-tyvar fix in
`funifyUnionAndStruct` (items 2 and 3) handles the contamination at the right
level — inside the unification engine, not at the constraint emission level.

## 5. Polarity-aware bounds resolution for FBounded tyvars

### Problem

When a tyvar has bounds `{Cons<string> .. List<string>}` (lower = struct,
upper = parent union), the final resolution in `ftype2fctype` must pick a
concrete type. Currently `frange2fctype` calls `combinePositiveAndNegative`
which returns `[Cons<string>, List<string>]` (struct first, union second),
and `ftypes2fctypes` picks `t[0]` — always the **lower bound** (struct).

This is correct for **covariant** positions (local bindings, return values):
`a = expr` should have the most specific type the expression produces.

But it is **wrong for contravariant positions** (function parameters):
`\res -> Cons(")", res)` where `res` has bounds `{Cons<string> .. List<string>}`.
Resolving `res` to `Cons<string>` makes the lambda type
`(Cons<string>) -> Cons<string>`, which rejects `List<string>` arguments.
The correct resolution is `List<string>` — the parameter must accept all
values the caller might pass.

### Where it happens

In `failBindFI(failFoldi(..., Cons(first, acc), ...), \res -> Cons(")", res))`:

- `failBindFI : (Fail<?>, (?) -> ??) -> Fail<??>`
- `failFoldi` accumulator `??` has bounds `{Cons<string> .. List<string>}`:
  - Lower: init = `Cons(first, acc)` gives `Cons<string> ≤ ??`
  - Upper: `Cons(sql2, acc2)` uses acc2 as tail → `?? ≤ List<string>`
- `??` resolves to `Cons<string>` (lower bound picked by `t[0]`)
- This feeds into `failBindFI`'s `?` = `Cons<string>`
- Lambda param `res : ?` gets type `Cons<string>` instead of `List<string>`

### Resolution path

`ftype2fctype` → `FBounded(lower, upper)` → `frange2fctype(lower, upper)` →
`combinePositiveAndNegative(Cons, List)` → returns `[Cons, List]` →
`ftypes2fctypes` picks `t[0]` = `Cons` ← **wrong for contravariant tyvars**

### Fix: per-tyvar polarity from constraint graph

The solver needs **polarity tracking** for tyvars. When resolving
`FBounded(lower, upper)`:
- **Covariant tyvar** (output position): pick lower bound (most specific)
- **Contravariant tyvar** (input position): pick upper bound (most general)
- **Invariant tyvar** (both positions): pick lower bound (safe default)

### Failed attempt 1: polarity parameter in ftype2fctype

Added `positive : bool` parameter to `ftype2fctype`, `ftypes2fctypes`,
`frange2fctype`, and `posPolarity : bool` to `combinePositiveAndNegative`.
Polarity flips at function argument positions (`!positive`).

**Fundamentally flawed**: This is per-evaluation-context polarity. During
finalization, `setFTyvar` resolves each tyvar ONCE, but the type it resolves
may contain nested FTypeVars that get evaluated through `ftype2fctype` at
different polarity contexts. The same tyvar's FBounded would get resolved
differently depending on which code path evaluates it, producing inconsistent
results (e.g. `SentenceHitExtended` in one context, `SentenceMatch` in
another within the same compilation of rhapsode_server).

### Failed attempt 2: track bound origin (autoGrownUpperBounds)

Added `autoGrownUpperBounds : Set<int>` to FEnv, marking tyvars whose upper
bound came from `growRightTyvar` (struct → parent union auto-growth) vs
explicit constraints. The idea: auto-grown → prefer lower, real → prefer upper.

**Also flawed**: The auto-growth flag is a property of the bound creation
site, not the tyvar's usage context. A tyvar might get auto-grown upper
bounds AND real constraints, and the flag can't distinguish the combination.

### Implemented fix: per-tyvar polarity from constraint positions

**Key insight**: Each tyvar should have a **single** polarity classification
based on where it appears in the constraint graph (before finalization), not
based on which code path evaluates it during finalization.

**Implementation** (branch `polarity-aware-bounds`, commit 6bd21af4a):

1. Added `tyvarPolarity : Tree<int, int>` to `FEnv` (replaces
   `autoGrownUpperBounds`). Maps tyvar id → polarity: +1 covariant,
   -1 contravariant, 0 invariant.

2. `collectTyvarPolarity` (ftype_solve.flow) walks all `FcTypeExpect`
   constraints after solving, before finalization:
   - `FcLessOrEqual(output, input)`: tyvars in output → +1, in input → -1
   - `FcGrowToFit(output, input)`: same
   - `FcVerifyType(e1, e2)`: both sides → 0 (invariant)
   - Function arg positions flip polarity; ref/mutable → 0

3. `setFTyvar` looks up `tyvarPolarity` for the tyvar being resolved:
   ```
   polarity = lookupTreeDef(env.tyvarPolarity, tyvar, 0)
   positive = (polarity >= 0)  // covariant or invariant → true
   ftype2fctype(env, type, seen, positive, onError)
   ```

4. `ftype2fctype` FTypeVar case also uses per-tyvar polarity when recursing
   into resolved types — each tyvar in a chain uses its own polarity.

**Result**: 0 regressions vs master baseline. The `positive : bool` parameter
is still threaded through `ftype2fctype`/`combinePositiveAndNegative` but is
now driven by per-tyvar polarity rather than inherited evaluation context.

### Remaining issue

The polarity collection currently treats invariant (0) and unknown the same
as covariant (prefer lower bound). For the cases described above:
- mapAsync `{JsonObject .. Json}`: tyvar is contravariant → picks upper (Json) ✓
- sql.flow `{Cons .. List}`: tyvar is contravariant → picks upper (List) ✓
- interpreter_lib `{MRTableCol .. MRExp}`: tyvar is covariant → picks lower (MRTableCol) ✓

However, verification against these specific cases has not been done yet
(they require the full codebase). The test suite (165 tests) and
material_textinput.flow compile with 0 regressions.
