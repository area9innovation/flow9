# Experiment to bootstrap Gringo with Gringo

This is a test bed for how to get Gringo bootstrapped using
Gringo and the DSL infrastructure in the best possible way.

To get to robust parsing, we need these this:

- Expand precedence

   	   e = e tail e |> rest;

   is converted to

		e = e1 tail e1 | e1;
		e1 = rest;

  and after this, there are no more precedence clauses

  We also replace recursion with the expanded names according to somewhat
  tricky rules. left and right recursion is special in this regard.

- Reduce common (optimization)
  -  Builds a dependency graph of the rules, and replaces common subexpressions
     in a loop-free version of the graph starting from the leaves
  -  Does dead-code elimination from the dependency graph as well, including 
     identity rules

- Common prefix. Rewrites

	e = pr tail1 | pr tail2 | rest
		=>
	e = pr (tail1 | tail2) | rest
 
- Right associate gterms

	// Turns ((a | b) | c)  into (a | (b | c))
  
- Rewrite left recursion. Rewrites

	e1 = e1 tail | rest
	== GRule(e1, GChoice(GSeq(GVar(rule), tail), rest))

	-> 

	e1 = rest tail*;
	== GRule(e1, GSeq(rest, GStar(tail)))

- Reduce common (optimization)

- Optimize (optimization)
  - <epsilon> | right   => right?
  - left | <epsilon>    => left?
  - term | term  		=> term
  - <epsilon> term   => term
  - term <epsilon>   => term
  - "st" "ring"  	 => "string"
  - term*?           => term*
  - term??           => term?
  - l-l   => "l"

TODO:
Add a choice reordering phase.
If the prefixes between two choices do not overlap,
then we can reorder them. Use this to optimize the
grammar and get more common prefixes exposed.

# Summary

The tricky part is reducing the precedence.
Next tricky bit is CSE, respecting dependencies, as
well as DCE.
The rest is term rewriting.
Evaluation is relatively simple.
