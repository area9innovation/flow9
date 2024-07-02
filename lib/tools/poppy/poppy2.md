# Type inference of Poppy & Mango

The Poppy language is a functional stack language, and as such, it is amenable to type inference using unification as in Hindley-Milner. In this chapter, we will describe how we implement type inference and checking for Poppy. This will also serve as the backbone for type inference of Mango.

![mango type structuralist sculture, artstation raytracing](images/DALL·E 2022-11-21 13.12.44 - mango type structuralist sculture, artstation raytracing.png)

## Type Language

Type inference of stack based languages has been studied for some time. This [paper](https://prl.khoury.northeastern.edu/blog/static/stack-languages-talk-notes.pdf) contains a nice summary of the research. However, our variant includes a bunch of advanced features, such as polymorphism, first-order functions, subtyping and overloading:

``` tools/poppy
1 2 + 1.1 3.9 + "Hello" " World" + // gives 3 5 "Hello World"
```

This makes type inference more complex. To handle these constructs, we define our type language is to have these constructs:

``` melon
PType ::= 
	// This is really ( -> name<typars>) implicitly
	PTypeName(name : string, typars : [PType]),
	// For type variables to be determined - also used for polymorphism
	PTypeEClass(eclass : int),
	// This is the type of a word that takes (inputs -> outputs)
	PTypeWord(inputs : [PType], outputs : [PType]),
	// This is an overload of words
	PTypeOverload(overloads : [PType]),

	// The type of `eval` is this construct, which has stack polymorphism: 
	// ( -> a) ◦ eval = a
	// ( -> a b) ◦ eval = a b
	// (a (a -> b)) ◦ eval = b
	// (a b (a b -> c)) ◦ eval = c
	// ...
	PTypeEval(),

	// Composing two types: This is function composition
	PTypeCompose(left : PType, right : PType),

	// When we infer the name of fields in structs, we use this one
	PTypeFieldName(name : string, type : PType);
```

TODO: Make example of eval for stack polymorphism, as well as subtyping

In existing research, stack polymorphism is handled by having two different kinds of type variables: Normal ones for polymorphism, and stack ones for stack polymorphism. In our approach, we simplify this setup by having a specific type construct `PTypeEval` that evaluates a quotation. This construct is implicitly stack polymorphic.

## Union find map

A core operation in Hindley-Milner type inference is unification. A common algorithm and data structure to support this is known as union-find. With this data structure, type variables can be unified in constant time. We extend this data structure to also contain a mapping for each *root* of the union-find data structure. This mapping is used to store an array of all the potential types each type variable can have. This is used for subtyping.

Since these type variables are unified, we call them "eclasses" for "equivalence classes". Each eclass has a root, which is the representative of the eclass. The root is used to look up the mapping of potential types.

TODO: Describe the union-find map data structure and key operations

## Type environment

TODO: Describe the type environment we use for type inference

## Type inference 

TODO: Describe how we convert each Poppy constructor into a corresponding type.

## Type evaluation

TODO: Describe type evaluation works

## Type composition

TODO: Describe how type composition works

## Type unification

TODO: Describe how type unification works

## Type extraction

After type inference and evaluation, we have determined a set of types for each word in the program. If a word has multiple named types as the result, we want to lift those into an implicit union.

TODO: Describe how all of this works.

## Type inference of Mango

Now describe how this works: We just replace the first part of the type inference. Instead of constructing a type for each Poppy construct, we construct a type for each Mango expression. This works well. If we meet an embedded Poppy construct, we use the same type environment and just invoke the type inference of Poppy.

TODO: Expand on tjhis and include an example of how we can infer the type of a AST type that fits any grammar
