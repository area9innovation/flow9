// OK, extend this language with the "dot" syntax
registerDslParserExtension("dot", << 
	postfix = postfix | "." ws $"nil" $"swap" $"cons" id $"var_1" $"swap" ( "(" ws mexps ")" ws)? $"call_2";
	mexps = exp $"cons" ("," ws exp $"cons")* ("," ws)?;
>>)
