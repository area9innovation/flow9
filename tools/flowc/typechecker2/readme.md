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


## Idea about doing fields as overloading instead

### Level 1 inference

Foo(foo : int);
Bar(foo : int);

foofighter(f : Foo) {
	acc + f.foo
}

### Level 2 inference

Level 2:
Foo(foo : int);
Bar(foo : int);

foofighter(fs : [Foo]) {
	fold(fs, 0, \acc, foo -> {
		acc + foo.foo
	})
}

### Level 3 inference

Union ::= Foo, Bar;
	Foo(foo : int);
	Bar(foo : int);

foofighter(fs) {
	fold(fs, 0, \acc, foo -> {
		acc + foo.foo
	})
}

### Level 4 inference

// Union ::= Foo, Bar; // This is implicit in some sense
	Foo(foo : int);
	Bar(foo : int);

foofighter(fs) {
	fold(fs, 0, \acc, foo -> {
		acc + foo.foo
		acc + foo'field(foo)
	})
}

### Level 5 inference

Foo(foo : int);
Bar(foo : double);

foofighter(fs : [Foo]) {
	fold(fs, 0, \acc, foo -> {
		acc + foo.foo
		acc + foo'field(foo)
	})
}

### Level 6 inference

Foo(foo : int);
Bar(foo : double);

foofighter(f) {
	0 + f.foo
}

### Level 7 inference


Foo(foo : int);
Bar(foo : double);

foofighter(fs) {
	fold(fs, 0, \acc, foo -> {
		acc + foo.foo
		acc + foo'field(foo)
	})
}

### Notes on how to do it

First, we implicitly construct functions that extract the field value
from each struct:

	foo(a : Foo) -> int; // Mangled also known as foo'Foo
	foo(a : Bar) -> int; // Mangled also known as foo'Bar

Now, to check type "a.foo", think of it as "foo(a)". Then we introduce a new construct

	GOverloadedFunction(name : string, oneOf : Set:<string>);

which represents a function type of an overloaded name, but we do not know which yet.

So when we see

	foo(a)

we run:

foo_type = typecheck(foo);

println(foo_type)
	
	GOverloadedFunction("foo", ["foo'Foo", "foo'Bar"])


instance_alpha_arg = mkTyvar();
instance_alpha_return = mkTyvar();
instance_call_type = GFunction([instance_alpha_arg], instance_alpha_return);

	less_or_equal(instance_call_type, foo_type, pos)


--

Code generation should look up what function to call based on how
the overloading was resolved.

plus_Int(int, int) -> int
plus_Double(double, double) -> double
plus_String(string, string) -> string

--

	GOverloadedFunction(foo, [foo_Foo, Foo_Bar]);

foo_type = typecheck(foo(a));

alpha_foo <= GOverloadedFunction(foo, [foo_Foo, foo_Bar]);

println(foo_type)
	GFunction(
		[
			alpha_arg0
		],
		int
	)

--

Plus(a : int, b : int) -> int;
Plus(a : int, b : double) -> double;

Plus_int_int
Plus_int_double


Plus : GOverloadedFunction(plus, [Plus_int_int, Plus_int_double])


