{
	registerDslLowering("compile", "concert", "ast", "ast", ";;", <<
		var($id) => CVar($id, ConcertPos("", 0, 0));;		

		add($a, $b) => CCallBuiltin("+", [$a,$b], ConcertPos("", 0, 0));;
		mul($a, $b) => CCallBuiltin("*", [$a,$b], ConcertPos("", 0, 0));;
		sub($a, $b) => CCallBuiltin("-", [$a,$b], ConcertPos("", 0, 0));;
		div($a, $b) => CCallBuiltin("/", [$a,$b], ConcertPos("", 0, 0));;
		mod($a, $b) => CCallBuiltin("MOD", [$a,$b], ConcertPos("", 0, 0));;
		negate($a)	=> CCallBuiltin("-", [$a], ConcertPos("", 0, 0));;

		and($a, $b)	=> CCallBuiltin("&&", [$a,$b], ConcertPos("", 0, 0));;
		or($a, $b)	=> CCallBuiltin("||", [$a,$b], ConcertPos("", 0, 0));;
		not($a)		=> CCallBuiltin("not", [$a], ConcertPos("", 0, 0));;

		less($a, $b)			=> CCallBuiltin("<", [$a,$b], ConcertPos("", 0, 0));;		
		greater($a, $b) 		=> CCallBuiltin(">", [$a,$b], ConcertPos("", 0, 0));;		
		less_equal($a, $b) 		=> CCallBuiltin("<=", [$a,$b], ConcertPos("", 0, 0));;
		greater_equal($a, $b) 	=> CCallBuiltin(">=", [$a,$b], ConcertPos("", 0, 0));;
		equal($a, $b) 			=> CCallBuiltin("==", [$a,$b], ConcertPos("", 0, 0));;
		not_equal($a, $b) 		=> CCallBuiltin("!=", [$a,$b], ConcertPos("", 0, 0));;
		
		true => CBool(true);;
		false => CBool(false);;

		int($i)		=> CInt($i);;
		double($d)	=> CDouble($d);;
		string($s)	=> CString($s);;

		let($name, $value, $body) => CLet($name, $value, $body, ConcertPos("", 0, 0));;
		brace($s) => CSequence($s);;

		lambda($args, $body) => CLambda($args, $body);;

		bind($e) => CUnquote($e);;
		quote($e) => CQuote($e);;

		call(CVar("nil", ConcertPos("", 0, 0)), $children) => CArray(CArrayView(0, 0), []);;
		call(CVar("cons", ConcertPos("", 0, 0)), [$value, $array]) => CCall(
			CVar("arrayPush", ConcertPos("", 0, 0)), 
			[
				$array,
				$value
			],
			ConcertPos("", 0, 0)
		);;
		call($fn, $children) => CCall($fn, $children, ConcertPos("", 0, 0));;	

		ifelse($cond, $then, $else) => CIf($cond, $then, $else, ConcertPos("", 0, 0));;
	>>)
}
