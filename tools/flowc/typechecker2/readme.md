# GType checker

This type checker is enabled using "gtype=1".

Also, you can use "explicit-flow=1" to get more precise checking of the use of the flow
type.

The entry point is gtype_solve.flow.

1. First, recursively deconstruct all relations based on the expectations and build a graph
of requirements for each tyvar. I.e. we know what types should be above, below or equivalent
to a given tyvar and record that in a graph (`GRelations`). This is what happens `gtypeSolve` 
around line 122. The constraints are expressed as `GType`, which is our type language.
This is like normal flow types, except we have `GTypeVar`, `GNamed` with type-pars for both 
structs and unions, and `GField(name : string, type : GType)` which marks that we require
a field of that type.

2. The tyvars are stored in a queue `GRelations.tyvarQueue` as `GQueueItem`s. We process 
them in prioritized order to figure out how to resolve them one by one, trying to take all information 
about it into account. This is done in `resolveGGraph`, called from `gtypeSolve`.

A tyvar constraint is classified into four buckets (`GResolutionStage`):

* Resolve all unambigious cases, not considering fields.
* Also resolve unambigious cases, but consider field constraints as well.
* Here we do prolog-style search of all allowed results, and check if they pan out
* Convert connected, unbound tyvars to type pars

The priority of a tyvar is then defined as the stage, the `GPriority` structure, and the tyvar
id itself. This captures various information about the constraints and is constructed in `makeGQueueItem`.

To decide whether a set of constraints is ambigious, we basically construct all
possible types that are possible as the intersection of all possible types that
support the upper bound and all possible types that support the lower bound.

So first we convert a tyvar id to a set of requirements using `buildGTyvarRequirement`,
which transitively collects all requirements above and below the tyvar. This is
expressed as `GBounds`, which tracks requirements for specific types, named types, 
fields, tyvars and the flow type separately.

Given two bounds, we try to resolve the type in `clarifyGTyvar`. If a tyvar can not
be resolved in the given ResolutionStage, it is pushed into the queue again in the 
next stage.

This continues until the queue is empty.

3. Once we have resolved all tyvars, we convert the `GType`s back to `FcType`s and
populate the environment with them, and we are done.

## Status

gtype=1 works. It is a bit slower than the existing type checker, but it works
better in many situations.

## GSubtypeGraph

This is a static graph we build to track type-relationships between structs,
unions and fields.
