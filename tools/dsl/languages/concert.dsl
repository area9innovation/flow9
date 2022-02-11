registerDslLowering("compile", "concert", "ast", "lambda", ";;", <<
	var($id) => CVar(id, ConcertPos("", 0, 0));;		

	add($a, $b) => CCallBuiltin("+", cons(b, cons(a, nil())), ConcertPos("", 0, 0));;
	mul($a, $b) => CCallBuiltin("*", cons(b, cons(a, nil())), ConcertPos("", 0, 0));;
	sub($a, $b) => CCallBuiltin("-", cons(b, cons(a, nil())), ConcertPos("", 0, 0));;
	div($a, $b) => CCallBuiltin("/", cons(b, cons(a, nil())), ConcertPos("", 0, 0));;
	mod($a, $b) => CCallBuiltin("MOD", cons(b, cons(a, nil())), ConcertPos("", 0, 0));;
	negate($a)	=> CCallBuiltin("-", cons(a, cons(CInt(0), nil())), ConcertPos("", 0, 0));;

	and($a, $b)	=> CCallBuiltin("&&", cons(b, cons(a, nil())), ConcertPos("", 0, 0));;
	or($a, $b)	=> CCallBuiltin("||", cons(b, cons(a, nil())), ConcertPos("", 0, 0));;
	not($a)	=> CCallBuiltin("not", cons(a, nil()), ConcertPos("", 0, 0));;

	less($a, $b)			=> CCallBuiltin("<", cons(b, cons(a, nil())), ConcertPos("", 0, 0));;		
	greater($a, $b) 		=> CCallBuiltin(">", cons(b, cons(a, nil())), ConcertPos("", 0, 0));;		
	less_equal($a, $b) 		=> CCallBuiltin("<=", cons(b, cons(a, nil())), ConcertPos("", 0, 0));;
	greater_equal($a, $b) 	=> CCallBuiltin(">=", cons(b, cons(a, nil())), ConcertPos("", 0, 0));;
	equal($a, $b) 			=> CCallBuiltin("==", cons(b, cons(a, nil())), ConcertPos("", 0, 0));;
	not_equal($a, $b) 		=> CCallBuiltin("!=", cons(b, cons(a, nil())), ConcertPos("", 0, 0));;
	
	true => CBool(true);;
	false => CBool(false);;

	int($i)		=> CInt(i);;
	double($d)	=> CDouble(d);;
	string($s)	=> CString(s);;

	let($name, $value, $body) => CLet(name, value, body, ConcertPos("", 0, 0));;
	brace($s) => CSequence(s);;

	lambda($args, $body) => CLambda(args, body);;

	call($fn, $children) => {
		if (nodeChild(fn, 0) == "cons") {
			CArray(CArrayView(0, 0), cons(
				listAt(children, 1),
				nodeChild(listAt(children, 0), 1)
			))
		}
		else if (nodeChild(fn, 0) == "nil") CArray(CArrayView(0, 0), nil())
		else CCall(fn, children, ConcertPos("", 0, 0))
	};;	

	ifelse($cond, $then, $else) => CIf(cond, then, else, ConcertPos("", 0, 0));;
>>)