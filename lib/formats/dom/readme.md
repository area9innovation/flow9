# DOM structures

These are typed version of the HTML DOM types in browsers.

TODO:
- Replace events QExp with lambdas. Can events be considered as structures, or RAssigns?
  They probably can. Decide which is better.
  
- Complete the types and conversions

- Add FRP version for interactives

- Add "efficient" updating function for rendering with some FRP
  or lvalue-based approach

- Add default constructors for each element to make code easier

- Add helpers without crazy amount of parameters:
  Define what parameters are commonly used, and have sane defaults for others:

  // EP(html : string, children : [EDom], style : CssValues, attributes : GlobalAttributes, events : [DomEvent])

	// Easy:
	eP(html : string) -> EP;
	// Use:
	EP(eP("Hello world") with children = [whatever]);

- Add converters to/from lvalue:
	html.body.p = "Hello world"
	html.body.p.style = "Bold"

  is the same as

	  EHtml(EBody(EP("Hello world", style=Bold)))

  in some shape or form.

- Add "extraction" function which takes the real DOM or an lvalue, and returns EDom?
