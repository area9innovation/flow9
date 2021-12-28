# DSL & Rewriting engine

This is a system to try to define syntax & semantics for languages, including
rewrite rules.

# E-graph matching library

makeEGraph requires a function to split a value into the head and the children.

makeEMatchEngine requires a default value, as well as a function to combine a head
and children, as well as an expression to start from.

To do replacements, we need a pattern which is:

	EPattern<?> ::= EPatternVar, EPatternTerm<?>;
		EPatternVar(id : string);
		EPatternTerm(head : ?, args : [EPattern<?>]);

and then a replacement, which takes bindings and produces a new value, as well
as the root class to start out with. So when constructing the graph, we have to
remember the root class to do the replacement from.

To extract the best value,
	extractEGraph(e : EGraph<?>, benefitFn : (ENode<?>, [EClassBenefit<?>]) -> EClassBenefit<?>) -> Tree<int, EClassBenefit<?>>;

# Example

    SimpleLanguage {
        Num(i32),
        "+" = Add([Id; 2]),
        "*" = Mul([Id; 2]),
    }

    rewrite!("commute-add"; "(+ ?a ?b)" => "(+ ?b ?a)"),
    rewrite!("commute-mul"; "(* ?a ?b)" => "(* ?b ?a)"),
    rewrite!("add-0"; "(+ ?a 0)" => "?a"),
    rewrite!("mul-0"; "(* ?a 0)" => "0"),
    rewrite!("mul-1"; "(* ?a 1)" => "?a"),

We could attempt to write that as Gringo with a simple grammar like this:

	exp = exp "+" exp $"plus" |> exp "*" exp $"mul") |> int $"int";
	int = $('0'-'9'+);

and for

	0 + 2 * 1

we would get a stack like

	0
	"int"
	2
	"int"
	1
	"int"
	"mul"
	"plus"

To turn that into a tree, we would need the arity of the operators:

	"int" -> 1
	"mul" -> 2
	"plus" -> 2

With that, we would get a tree

	plus(int(0), mul(int(2), int(1)))

We could express the rewrite rules with this

	a + b => b + a
	a * b => b * a
	a + 0 => a
	a * 0 => 0
	a * 1 => a

With that, and a grammar to have patterns like this:

	rules = rule*;
	rule = pattern "=>" pattern $"rule";
	pattern = (exp += |> id $"bind");	// This extends the exp grammar with a new case at the end of the grammar
	id = 'a'-'z';

and define "bind" to have arity of 1, and "rule" to have arity of 2,
we would get the rules out as trees:

	rule(plus(bind(a), bind(b)), plus(bind(b), bind(a)),
	rule(mul(bind(a), bind(b)), mul(bind(b), bind(a)),
	rule(plus(bind(a), int(0)), bind(a)),
	rule(mul(bind(a), int(0)), int(0)),
	rule(mul(bind(a), int(1)), bind(a)),

We still need a default value, which could be the basic value.

## Rewriting engine syntax proposal

OK, so the above example can be expressed using this syntax:

	// The grammar of the language where arity of actions is a naming convention
	grammar mylang {
		exp = exp "+" exp $"plus_2" 
			|> exp "*" exp $"mul_2") 
			|> $int $"int_1"
			|> $id $"bind_1";	// For pattern matching
		int = '0'-'9'+;
		id = 'a'-'z';
	}

	// The set of rewriting rules we want
	rules mylang {
		a + b => b + a;
		a * b => b * a;
		a + 0 => a;
		a * 0 => 0;
		a * 1 => a;
	}

	// For the plumbing to work, we need a default value (in the language syntax)
	default mylang {
		0
	}

	// These costs refer to the semantic actions without arity
	// so we can figure out what the costs are. This is used to extract the best reduction
	cost mylang {
		int => 1;
		plus => 2;
		mul => 3;
	}

	// This is a prototype for how to define an compiler/evaluator of a language.
	// Probably, we need some conversion method for instantiation
	compile mylang => text {
		plus(a, b) => plus_int($a, $b);
		mul(a, b) = mul_int($a, $b);
		int(n) = n;
	}

And with that, we could attempt to make a saturating rewrite engine and
extraction method, as well as a compiler.

For the compiler, we could attempt to have built-in set of natives to get an evaluator
out.

TODO:
- Pretty-printing as a special case of compilation?
- Test cases for both reduction, evaluation and compilation?
- Define type system?
- Figure out precedence for blueprint/text output?

