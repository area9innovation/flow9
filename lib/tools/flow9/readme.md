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

md2wigi.flow: Impossible to figure out what the type errors mean

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
