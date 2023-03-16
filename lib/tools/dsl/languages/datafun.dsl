syntax lambda+quotestring+array {
	// OK, extend this language with the "bag/list comprehension" syntax
	registerDslParserExtension("datafun", << 
		atom = atom | datafun;

		datafun = '[' ws exp '|' ws datafun_exps ']' ws $"datafun_2";

		datafun_exps = // listof(datafun_exp, ",")
			$"nil" datafun_exp $"cons" ("," ws datafun_exp $"cons")*;

		datafun_exp = idbind ws "in" ws exp $"datafun_in_2" // This is a loop
			| exp $"datafun_filter_1"; 					// This is just a filter
	>>);

	// TODO: Figure out how to handle an arbitrary list of conditions in the loop part
	registerDslLowering("desugar", "datafun", "lambda+datafun", "lambda", ";", << 
			// 1-d loop
			[ $e | $a in $c ] 					=> @map($c, \$a -> $e);
			[ $e | $a in $c, $f ] 				=> @fold($c, nil(), \acc, $a -> if ($f) cons($e, acc) else acc);

			// 2-d loops
			[ $e | $a in $c, $b in $d ] 		=> @fold($c, nil(), \acc, $a -> fold($d, acc, \acc2, $b -> cons($e, acc2)));
			[ $e | $a in $c, $b in $d, $f ] 	=> @fold($c, nil(), \acc, $a -> 
													fold($d, acc, \acc2, $b -> if ($f) cons($e, acc2) else acc2)
												);
			[ $e | $a in $c, $f, $b in $d ] 	=> @fold($c, nil(), \acc, $a -> 
													if ($f) fold($d, acc, \acc2, $b -> cons($e, acc2)) else acc
												);
			[ $e | $a in $c, $f, $b in $d, $g ] => @fold($c, nil(), \acc, $a -> 
													if ($f) fold($d, acc, \acc2, $b -> if ($g) cons($e, acc2) else acc2) else acc
												);
		>>);

	// [ u.name | u in users, c in classes, cl in class_learners cl, cl.class_id == index(c.id), cl.user_id == u.id ]

	registerDslRuntime("datafun", "lambda+array", << ["fold", "map"] >>);

/*
			[ $e | a_1 in $c_1, a_2 in $c_2 ] => fold($c_1, nil(), \acc_1, a_1 -> 
				fold($c_2, acc_1, \acc_2, a_2 -> cons($e, acc_2))
			);

			[ $e | a_1 in $c_1, a_2 in $c_2, ..., a_n in $c_2 ] => fold($c_1, nil(), \acc_1, a_1 -> 
				fold($c_2, acc_1, \acc_2, a_2 -> 
					...
					fold($c_n, acc_(n - 1), \acc_n, a_n -> cons($e, acc_n))
				)
			);
*/
}
