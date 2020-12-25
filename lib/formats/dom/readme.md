# DOM structures

These are typed version of the HTML DOM types in browsers.

TODO:
- Replace events QExp with lambdas
- Complete the types and conversions
- Add rendering function of EGeneric and string
- Add FRP version for interactives

- Add default constructors for each


- Add converters to/from lvalue:
	html.body.p = "Hello world"
	html.body.p.style = "Bold"

  is the same as

	  EHtml(EBody(EP("Hello world", style=Bold)))

  in some shape or form.

- Add helpers without crazy amount of parameters:
  Define what parameters are always used, and turn the rest
  into helpers somehow:

  // EP(html : string, children : [EDom], style : CssValues, attributes : GlobalAttributes, events : [DomEvent])

	// Easy:
	EP(eP("Hello world") with children = [whatever]);

