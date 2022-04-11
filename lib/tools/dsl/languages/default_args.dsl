{
	/*
		Adds syntax for default arguments in functions
		with "top-level" function syntax

		foo(a = 1, b = 2) {
			exp
		}
		scope

		becomes

		foo = \a, b -> exp;
		foo = \a -> foo(a, 2);
		foo = \ -> foo(1, 2);
		scope
	*/
	registerDslParserExtension("default_args", << 
		atom = id "(" ws fundef_args ")" ws "{" ws exp "}" ws expsemi $"brace_1" $"function_4" | atom;

		fundef_args = $"nil" fundef_arg $"cons" ("," ws fundef_arg $"cons")* ("," ws)? | $"nil";
		fundef_arg = id "=" ws exp $"funargdef_2" | id $"funarg_1";
	>>);

	// function(id, args, body) => id = \args -> body
	registerDslLowering("desugar", "default_args", "ast", "lambda", ";;", <<
		function($id, $args, $body, $scope) => {
			nargs = length(args);
			argIds = map(args, \a -> nodeChild(a, 0));

			hasDefVal = \node -> { nodeName(node) == "funargdef" };

			hasAllFollowingDefs = \i -> {
				if (i < nargs) hasDefVal(listAt(args, i)) && hasAllFollowingDefs(i + 1)
				else true
			};

			// Takes I elements from the head of the list and add to acc
			takeUnto = \acc, list, i -> {
				if (i > 0) takeUnto(cons(head(list), acc), tail(list), i - 1) else acc
			};

			// Takes I elements from the head of the list
			take = \list, i -> {
				takeUnto(nil(), list, i)
			};

			// Removes I element from the head
			peel = \list, i -> {
				if (i <= 0) list
				else peel(tail(list), i - 1)
			};
			// Keep argno arguments in the lambda
			// For the rest, add defaults
			buildLambda = \acc, argno -> {
				defArgCount = nargs - argno;
				// println("Building a shortcut from " + argno + " with " + defArgCount + " defaults");
				fargs = peel(argIds, defArgCount);
				passArgs = map(fargs, \a -> var(a));
				defVals = map(args, \a-> nodeChild(a, 1));
				callargs = takeUnto(passArgs, defVals, defArgCount);
				defcall = call(var(id), callargs);
				let(id, lambda(fargs, defcall), acc)
			};

			defArg = range(0, nargs - 1);
			helpers = fold(defArg, scope, \acc, argno -> {
				if (hasAllFollowingDefs(argno)) {
					buildLambda(acc, argno)
				} else acc;
			});
			main = let(id, lambda(argIds, body), helpers);
			main
		} ;;
	>>);
}
