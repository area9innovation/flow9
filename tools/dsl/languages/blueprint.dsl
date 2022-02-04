syntax lambda+quotestring+array {

registerDslParser("blueprint", <<
	output = ws $"nil" (blueprint $"cons")* $"blueprint_1";

	blueprint = 
		glue
		| bind 
		| string $"string_1";

	glue = "$glue" ws "(" id "," ws string ")" ws $"glue_2";

	bind = "$" id "(" ws int ")" ws $"bind_2"
		| "$" id $"0" $"s2i" $"bind_2";

	output
>>, ["ws", "id", "int", "string"]
);

/*
	A stub of how we could define the evaluator of Blueprint
	eval = \env, blueprint -> {
		list = nodeChild(blueprint, 0);
		prec = intMax;
		fold(list, \e -> {
			match(e, <<
				string($s) => s;
				bind($v, prec) => env[v];
				glue($id, $sep) => {
					foldi(id, "", \i, acc, elm -> {
						if (i == 0) elm else acc + sep + elm
					})
				}
			>>);
		})
	}
*/
}