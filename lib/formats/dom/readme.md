# DOM structures

These are typed version of the HTML DOM types in browsers.

TODO:
- Replace events QExp with lambdas
- Complete the types and conversions
- Add rendering function of EGeneric and string
- Add FRP version for interactives

- Add default constructors for each
- Add helpers without crazy amount of parameters

- Add converters to/from lvalue:
	html.body.p = "Hello world"
	html.body.p.style = "Bold"

  is the same as

	  EHtml(EBody(EP("Hello world", style=Bold)))

  in some shape or form.

- Maybe we can do a hybrid inspired by Swift UI syntax
