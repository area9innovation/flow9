# Flow9

This is an attempt to use Mindcode to help write a new flow9 compiler.
The purpose is to to get a new compiler which has fine-grained incremental type checking, instead of local.
Status: Alpha. Incremental is known to be broken. Use `update-incremental=1` to force recompiles.

## Changes compared to existing compiler

Function arguments are always lower case.
Structs & Unions are always upper case.
Semi-colon required after top-level variables.
No semi-colon allowed after `with` fields.
No extra () around types allowed.
No implicit string concat "Hello " "world". Use one long line to avoid have retranslations.
Polymorphism in unions have to be resolved. If a struct is polymorphic, but the union is not, then the instance of the struct has to be Struct<flow> or some other resolved type.
`Foo(if (a) else b with c = 1)` should be `Foo((if (a) else b) with c = 1)`
Structs and unions are not allowed to be defined (even the same) multiple places.
import, forbid, export has to be in that sequence
`a ?? if (b) c else d : e` has to be   `a ?? (if (b) c else d) : e`
Import resolution of names and types is strict: Names have to be imported transitively.
Top-level names with polymorphism have to be annotated with types.
Recursive top-levels have to have full type annotation
Implicit subtyping in unions is not allowed. U1 ::= Foo, Bar; U2 ::= Foo, Bar, Baz; In this case, U1 is not a subtype of U2 anymore. You should do U2 ::= U1, Baz instead. This is to allow precise incremental compilation.
Switches are not allowed to match bigger types than the switch variable.
"return" is not allowed as name
`switch (a.b)` will not specialize the type of `a.b` in the cases. Only switch on named vars will. 
Top-level variables can not be polymorphic.
It is not allowed to mention vars in switch cases on unions: `Union(vars): ...`
Even unused variables need to have a resolved type.
We do not allow .field on flow type.

New things:
`a : int` is allowed as expression anywhere.
Polymorphism and resolution is more principled now, and `Either<?, ??> ::= Left<?>, Right<??>` works.
Type inference is per-file, not global.

## TODO

- Debug Incremental
  - Fix dependency tracking to make finegrained incremental in typecheck
- Have warnings and errors. Implicit auto in toplevel is a warning, for example.
- Desugaring: checking duplicate & keyword names across struct, union, native, toplevels, fields
- Improve type errors: Do systematic test?
  - duplicates. list types of both
  - wrong use of call, list types
- Check for direct redundancy in unions
- type defs without implementation
- Exhaustive check for switch. 
- pipe-warn
- forbid
- Do type check without error tracking for speed. Only when we find an error, then repeat type inference with error tracking.
- Undefined variable or function 'updateBehaviourDistinct'. We should look up where it comes from at the end and suggest imports
- Notice when there is a difficult type var, and suggest type annotation
- We do not need to do contract alternatives all the time, only when merging eclasses.
- Use of non-exported name just gives error, instead of more precise
- Calculate more precise type for "default:" by removing those that are matched?

# Plan

flow9 /home/alstrup/area9/innovation/components/mwigi/mwigi/external_recursives/highlighter.flow tracing=2 name=makeWigiFormulaHelperExt trace=mw_material_utils >out2.c


# Analysis of the Subtype2.flow Type Inference Issue

Based on the debug trace and the code snippet, I can see this is a complex issue with the Flow9 type inference system around handling alternatives in function field access.

## The Problem

Let me explain what's happening:

1. We have two struct types with a `.position` field:
   - `Style1(position: DynamicBehaviour<int>)`
   - `Style2(position: Behaviour<int>)`

2. We have two functions:
   - `getValue(a: Behaviour<?>)` - accepts any `Behaviour` (including `DynamicBehaviour`)
   - `next(a: DynamicBehaviour<?>, v: ?)` - specifically requires `DynamicBehaviour`

3. In the `foo()` function, we create two functions that use a `state` parameter:
   ```flow
	 fn1 = \state -> {
		 curPos = getValue(state.position); // Just needs Behaviour
	 };
	 fn2 = \state -> {
		 next(state.position, 1); // Specifically needs DynamicBehaviour
	 }
```

4. The error happens because the type system resolves the type too early:
   - When processing `fn1`, `state.position` gets the type alternatives `Behaviour<int>` or `DynamicBehaviour<int>`
   - Since `getValue` only requires `Behaviour<?>`, the system resolves `state.position` to `Behaviour<int>`
   - Later in `fn2`, we need `state.position` to be `DynamicBehaviour<int>`, causing a conflict

## The Specific Issue in the Trace

The critical part of the trace shows:

```
Resolving bounds for α20: (α5) -> α11 ={α12, α20*} ∈{ (Style1=α13) -> DynamicBehaviour<int=α26>=α15, (Style2=α17) -> Behaviour<int=α26>=α18 }
Function bounds filter: Return type α11 has 1 upper bounds
Multiple return types found: Behaviour<int=α26>=α18, DynamicBehaviour<int=α26>=α29

Resolving bounds for α11: α11=α11
Upper bounds: Behaviour<α8>=α9
Working upper: Behaviour
Unifying α11=α11 and Behaviour<α41>=α42
```

The problem is that when resolving `α11` (the type of `state.position`), the system only sees an upper bound of `Behaviour<α8>` and decides to resolve it to `Behaviour<α41>`. But this is premature since later we need it to be `DynamicBehaviour<int>`.




# Specification: Minimal Alternative-Aware Type Resolution

## 1. Data Structure Changes

Extend the `EClass` structure by adding a field to track which alternatives this type is part of:

```flow
EClass(
	node : TypeNode,         // What is this node?
	mutable root : int,      // Representative ID
	alternatives : Set<int>, // If not empty, we know this eclass has to be exactly one of these alternative types
	subtypes : Set<int>,     // Subtypes of this eclass
	supertypes : Set<int>,   // Supertypes of this eclass
	subtypeContexts : Set<TypeRelationContext>,   // Contexts for subtype relationships
	supertypeContexts : Set<TypeRelationContext>, // Contexts for supertype relationships
	infos : Set<EContext>,   // For error reporting, we keep source infos
	// NEW: Set of alternative sets this eclass is part of
	partOfAlternatives : Set<int>  // IDs of alternative sets this type is a component of
);
```

## 2. Alternative Registration

When constructing alternatives for field access, function arguments, etc., update the code to track the relationship between component types and their parent alternatives:

```flow
// When creating a new alternative set
// This would be in the code that handles field access (state.position)
registerAlternativeComponents(g : EGraph, alternativeId : int, componentIds : [int]) -> void {
	iter(componentIds, \componentId -> {
		componentRoot = findEGraphRoot(g, componentId);
		eclass = getEClassDef(g, componentRoot);

		// Only update if we're adding a new alternative dependency
		if (!containsSet(eclass.partOfAlternatives, alternativeId)) {
			// Add this alternative to the component's dependencies
			newEClass = EClass(
				eclass.node,
				eclass.root,
				eclass.alternatives,
				eclass.subtypes,
				eclass.supertypes,
				eclass.subtypeContexts,
				eclass.supertypeContexts,
				eclass.infos,
				insertSet(eclass.partOfAlternatives, alternativeId)
			);

			updateEClass(g, componentRoot, newEClass);
		}
	});
}
```

## 3. Handling EClass Merging

When two EClasses are merged, we need to update the partOfAlternatives sets:

```flow
// In mergeEClasses function
mergeEClasses(g : EGraph, id1 : int, id2 : int) -> int {
	// Find the canonical representatives
	r1 = findEGraphRoot(g, id1);
	r2 = findEGraphRoot(g, id2);

	if (r1 == r2) {
		// Already merged
		r1
	} else {
		// Get the two eclasses
		ec1 = getEClassDef(g, r1);
		ec2 = getEClassDef(g, r2);

		// Merge all fields as before...

		// ADDED: Merge the partOfAlternatives sets
		mergedPartOfAlts = mergeSets(ec1.partOfAlternatives, ec2.partOfAlternatives);

		// Create the merged eclass with all merged properties
		merged = EClass(
			// other fields as before...
			mergedPartOfAlts
		);

		// Update as before...
		updateEClass(g, r1, merged);

		// Continue with existing merge logic...
		r1
	}
}
```

## 4. Field Access Alternative Handling

When processing a field access that creates alternatives (e.g., state.position), register both the owner type and the result type:

```flow
// When processing field access with multiple possible struct types
processFieldAccessAlternatives(g : EGraph, ownerTypeId : int, fieldName : string, resultTypeId : int, alternatives : Set<int>) -> void {
	// Register that both the owner type and result type are components of this alternative set
	registerAlternativeComponents(g, resultTypeId, [ownerTypeId, resultTypeId]);

	// Handle each alternative to extract return types
	iter(set2array(alternatives), \altId -> {
		altFnNode = getNodeDef(g, altId);
		switch (altFnNode) {
			Function(__, returnTypeId): {
				// The return type is also part of this alternative
				registerAlternativeComponents(g, resultTypeId, [returnTypeId]);
			}
			default: {}
		}
	});
}
```

## 5. Delay Resolution Logic

Modify the resolution logic in `resolveEClassBounds` to delay resolution when a type is part of alternatives:

```flow
resolveEClassBounds(g : EGraph, root : int, bounds : TypeBounds, speculate : bool, cache : TypeGraphCache) -> void {
	r = findEGraphRoot(g, root);
	if (r == root && !isTopDecidedNode(g, r)) {
		// Existing code to calculate bounds...

		eclass = getEClassDef(g, r);

		// NEW: Check if this is part of any alternative sets
		shouldDelay = !isEmptySet(eclass.partOfAlternatives) && !speculate;

		// If we should delay resolution, only update alternatives, don't resolve to a single type
		if (shouldDelay) {
			// Only filter alternatives against bounds, don't resolve to a single type yet
			filtered = filterAlternativesAgainstTypeBounds(g, eclass, lowerCons, upperCons, bounds, cache);
			if (!updateAlternatives(g, r, filtered)) {
				// If we couldn't update alternatives, we might need to resolve anyway
				// but be more cautious about it
				if (g.tracing > 0) {
					debugMsg(g, 1, "Delaying full resolution for α" + i2s(r) +
						" as it's part of alternatives: " +
						superglue(set2array(eclass.partOfAlternatives),
							\altId -> "α" + i2s(altId), ", "));
				}
			}
		} else {
			// Existing resolution logic...
			boundLimits();
		}
	}
}
```

## 6. Speculative Resolution Pass

Add a final pass that resolves any remaining types after all constraints are known:

```flow
// After main propagateBounds
resolveDelayedEClasses(g : EGraph) -> void {
	// Find all eclasses that were delayed due to being part of alternatives
	delayed = filterMap(getEGraphEClasses(g), \id, eclass ->
		if (!isEmptySet(eclass.partOfAlternatives) && isTypeVar(eclass.node))
			Some(id)
		else
			None()
	);

	// Sort them to process dependent types in the right order
	sorted = topoSortEClassDependencies(g, delayed);

	// Resolve each delayed eclass with speculate=true to force resolution
	iter(sorted, \id -> {
		bounds = getTypeBounds(g, id, makeTypeBoundsCache(g));
		resolveEClassBounds(g, id, bounds, true, makeTypeBoundsCache(g));
	});
}
```

## 7. Integration in Type Inference Pipeline

In your main type inference pipeline, modify the sequence:

```flow
propagateBounds(g : EGraph, name : string, speculate : bool) -> void {
	// Existing code...

	// First pass - conservative, delay types in alternatives
	iter(sortedNodes, \id -> {
		// Get the reachable sets from the precomputed closures
		reachableLower = lookupTreeDef(cache.lowerClosure, id, makeSet());
		reachableUpper = lookupTreeDef(cache.upperClosure, id, makeSet());

		resolveEClassBounds(g, id, TypeBounds(reachableLower, reachableUpper), false, cache)
	});

	// If speculate is true, do a second pass to resolve remaining delayed types
	if (speculate) {
		resolveDelayedEClasses(g);
	}
}
```

## Implementation Approach

1. First, update the `EClass` structure in `types.flow` to add the `partOfAlternatives` field
2. Modify the `EGraph` construction to initialize this field as an empty set
3. Update the code that creates field access alternatives to register component dependencies
4. Modify `mergeEClasses` to properly merge the partOfAlternatives sets
5. Update `resolveEClassBounds` to delay resolution when appropriate
6. Add the final speculative resolution pass if needed

This minimal approach doesn't try to be overly smart about when to delay or how to infer from alternatives - it simply delays resolution for any type that's part of an alternative set. This addresses the specific problem in `subtype2.flow` while being conservative with changes to the type system.


--


TODO: Send in all unions & structs to compiler backend, so it knows what are unions and how to expand them in switches.

mwigi/mwigi/external_recursives/highlighter.flow:84

Two alternatives, where both would work, but for some reason, we do not pick one.

in this type checker, as a final phase, we do subtype_unification. However, before we do that, we could do the bounds resolution in a speculative mode. The difference is that if we have a unique top-type, then we do not require no tyvars above, but can still resolve with that. Can you implement this change? We have a test case in md2string.flow which currently does not type.

- Figure out how to reduce memory usage from incremental use. Share the module interface? Streamline it, to only keep exported for the current module?

- Incremental is wrong somehow. We changed MSortItem to not be polymorphic, but incremental files kept it

unifyLubInfoTypes should take EContext instead of just info?

EContext can contain names of vars we have to lookup and print the type of

material/internal/material_icons_list.flow:  Very slow.

find out why passing many files to compile does not work in our driver. We parse them, but they never reach type checking for some reason.

#  flowc/tests

OK:
- test1, test100: Missing type pars
- error23b, error30, error42, error47: Not really a problem.
- wasm/test25.flow: comparison across different types not allowed
- cpp/test11.flow: mossing fold import
- improvable/test158.flow: Works as it should

TODO:
- tests/type13.flow: Default is de-facto a single case switch.
- type34.flow: If with isSameStruct specialization

- test44.flow: Reduce number of errors for missing tyvars.

- error25: using keywords like "bool" as local name
- error33: Union is defined by itself
- error46: investigate

Shadowing:
- error10: local shadowing global. Is that a problem?
- error11, error13: arg shadowing local
- error12: arg shadowing global
- error15: switch var shadowing global
- error17: switch var shadowing switch var
- error18: arg shadowing arg
- error19: arg shadowing switch var

# Remaining Type Problems

experimental/flow9.flow: Parsed: 0, typed: 394, errors: 0, used incremental: 0, retypechecked: 394 in 8.25s
flow9.flow: Parsed: 0, typed: 437, errors: 0 in 57.37s
flowc.flow: Parsed: 0, typed: 365, errors: 0 in 56.55s

- Optimization: Prune the environment PER function to help reduce search space for alternatives

## Covariance proposal

`extractStruct` could have anntotations to restrict it to follow the input

- `T!` means invariant
- `T+` could mean we allow supertypes (opposite to other languages for some reason)
- `T-` could mean we allow subtypes (opposite to other languages for some reason)

Then we could have: `extractStruct(a : [?], e : ??!) -> ??!;`

## Generalised if/switch syntax proposal

e is {
	Some(v) && v > 100 && v is Foo(a): {
		asdfasdf;
	}
	None(): asdcs;
	k == 42: sadfasd;
	true: asdfasdf;
}

e is {
	true: {
		ASDDFASDFASDFasdf
		;
		asdfasdf
	} 
	false: asdf;
}

I think the grammar is something like this:

```mango
is = exp "is" ("{" case+ "}" | case);
case = pattern ":" exp ";";
pattern = uid "(" @array<id ","> ")" / constructor with binding
	| pattern "&&" pattern 
	| is
	| exp;
```

It is not clear if this parses as intended or not, though.
