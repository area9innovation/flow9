*Tropic* & *Material*
=====================

*Tropic* is the second generation layout language for *flow* building on the lessons learned from *Form*. The main key difference is that *Tropic* no longer contains code, only data. This makes the language more robust, perform better and work at a higher level. The name *Tropic* relates to our first layout library developed in Haxe called *Arctic*. This library got superseded by *Form* in *flow*, which now in turn is superseded by *Tropic*,
which in turn is adopted by *Material*.

*Material* is the recommended library for making UIs.

Design Goals
-------------

The main goals for *Tropic* & *Material* are: 

- Better basic layouts.
- Lowering the cognitive load when building user interfaces.
- Increased control over responsive designs across platforms.
- Avoid doing manual inspects of metrics, which avoids loops in the layout code.
- Better performance.
- Minimal API size - easy to get an overview, hard to make an error.
- Backwards compatibility with `Form`.

`Tropic` is implemented in *Flow*, and does support `Form` elements, so existing user interface components can be utilized in `Tropic` layouts.

`Tropic` serves as the foundation for the `Material` library, which contains all of `Tropic`, and which is what you normally want to use.
So learning `Tropic` is helpful, since the underlying principles and constructs are directly embedded in `Material`.

Hello World using Tropic
------------------------
As always, "Hello World":

	import tropic/trender;

	main() {
    	trender(TText("Hello World", []), []);
	}

We construct the text as a `TText`, and then render it. All basic entities are very similar to `Form` elements, and have a similar interface, e.g `TText(text : string, style : [CharacterStyle]);`. 
This goes for `TEmpty`, `TGraphics`, `TPicture` as well as `TScale`, `TTranslate`, `TRotate` and so on, including common helpers like `TFixed` that construct an empty box of a given size. Notice that we shorten "Tropic" to "T" almost everywhere for brevity.

They are all documented in `tropic.flow` and are all modelled after the corresponding `Form` equivalents, with smaller modifications.

Hello World using Material
--------------------------

	import material/material2tropic;

	main() {
		mManager = makeMaterialManager([]);
		ui = MText("Hello World", []);
		mrender(mManager, true, ui);
	}

This is similar to `Tropic`, except you need a Material Manager to use `Material`. This is a construct,
which tracks keyboard focus, z-order and other global aspects of a modern UI.

Similar to the T-prefix for Tropic constructs, there is an M-prefix for Material constructs. See the `lib/material/`
folder and especially `material.flow` to see the definitions.

Most constructs exist as both a T-version, and an M-version. You normally want to use the M-version, but since
`Tropic` is a bit easier to use and display in small examples, we will use that in this document. The exact same 
principles apply to the `Material` versions, though.

Tropic has a place for high-design UIs, where you need pixel-precise control over the UI, but it is important
to repeat that `Material` is the recommended toolkit for most programs, also since Tropic is completely compatible
and embedded in `Material`.

Examples
--------

See the Material demo, as well as Material test programs to learn how to use Material (and Tropic):

	c:\flow9> flowcpp demos/demos.flow

	c:\flow9> flowcpp material/tests/material_test.flow

Also, check out the 7 GUIs challenge in `demos/7guis`. Those examples exist in many other languages,
so that is a good way to compare and contrast.

Basic layout
------------

We have helpers `TCols`, `TLines`, `TGroup` and `TGrid` to make layouts.

	import tropic/trender;

    main() {
        helloWorld = 
                TCols([
                    TText("Hello ", []), 
                    TText("World", [])
                ]);
    	trender(helloWorld, []);
    }

For the common case of putting two elements together, we have the variants `TCols2`, `TLines2`, `TGroup2`.

	import tropic/trender;

    main() {
        helloWorld = 
                TCols2(
                    TText("Hello ", []), 
                    TText("World", [])
                );
	    trender(helloWorld, []);
	}

In this example, `TCols2` is used to combine the two texts. It arranges two elements side by side (in two columns), aligning the top of the bounding boxes.

Filler
-------

To make our hello-world example above align right, we use a horizontal filler: 

	import tropic/trender;

	main() {
		helloWorld = 
			TCols2(
				TFillX(),
				TText("Hello World", [])
			);
		trender(helloWorld, []);
	}

which introduces the filler element `TFillX`. A filler is an actual physical element of whatever size it can achieve - up to the maximum possible. An `TFillX` is thus as wide as it can be, always with zero height. Similarly, we have `TFillY`, which expands in the height up to the maximum possible, always with zero width. The combination `TFillXY` is useful if you need something that grows in both directions.

Alignment is often done with fillers like this, or you can use the `TCenterX` helper. You can think of that as defined like this:

	TCenterX(b : Tropic) -> Tropic {
		TCols([TFillX(), b, TFillX()]);
	}

You can see that by surrounding the element by two fillers that expand equally, the effect is that the element is centered. We also have `TCenterY` for vertical centering, and `TCenter` that centers in both directions. (In reality, `TCenterX` and friends are implemented using a powerful `TTweak` construct underneath, but the above helps illustrate the concept of fillers.)

The filler is a well-proven concept, which dates all the way back to TeX.

Notice that fillers only grow if there is space to grow in. So in code like this:

    main() {
        huge =
            TCols2(
                TFillX(),
                TPicture("10000x10000 pixels.jpg", [])
            );
        trender(huge, []);
    }

the filler will be of size 0x0, since the huge picture takes all space first (unless you have a resolution bigger than 10000 pixels in the width.)

Rounded rectangles
------------------

A rounded rectangle `TRounded` is built into `Tropic`. It draws a rounded rectangle of the same size as a given tropic.

Similarly, `TRectangle` also does that except that the corners are not round:

	import tropic/trender;

	main() {
		trender(TRectangle([Fill(0xff0000)], TFillXY()), []);
	}

This paints the entire screen red.

Notice that the size of the rectangle is defined as TFillXY(). This is very flexible, and also helps to reduce the cognitive load: By having fewer, but more useful primitives, you do not need to learn about as many names.

The fill-box
------------

The fillers all expand according to how much space is available. At the top level, the available space is defined to be the entire screen/window. This area can be controlled using the `TAvailable` primitive. This will center the text in a 300x200 pixel box:

	import tropic/trender;

	main() {
		trender(
			TCenterIn(TText("Center", []), TFixed(300.0, 200.0)),
			[]
		);
	}

which uses `TAvailable` behind the scenes:

	TCenterIn(b : Tropic, frame : Tropic) -> Tropic {
		TAvailable(TCenter(b), frame)
	}

Notice that the second argument to `TAvailable` is NOT just a dimension, but a physical `TFixed` element. This is important, since in `Tropic`, we try to use the same type for everything.

`TCenter` is conceptually expanded to a number of `TFillX` and `TFillY` instances around the text. These fillers refer to the parent available area, which we defined to be 300x200 pixels in this case. The result is that the text is centered in that box. Since everything is physical in `Tropic`, the fillers are also physical, and the entire thing will thus be 300x200 pixels big.

Inside an available-area, each filler gets a equal share. This is independent on where they occur in the hierarchy of constructs - thus making the fillers behave in a compositional manner.

Zooming
-------

Another advanced functionality is `TZoom`: 

	import tropic/trender;

	main() {
		helloWorld = 
			TZoom(
				TText("Hello World", []), 
				TFillXY(),
				true
			);
		trender(helloWorld, []);
	}

The `TZoom` construct increases (or decreases) the actual size of a `Tropic` element by scaling it:

	TZoom(box : Tropic, target : Tropic, keepAspect : bool)

If the `target` tropic is greedy, then our `TZoom` will be greedy. The zoom will either maintain the aspect ratio of the box, or just changing the layout to fill the space depending on the bool. If the aspect ratio is kept, then any surplus space is wasted.

Notice that this operation is zoom-to-fit, not zoom-to-fill. You can use `TTweak` to implement zoom-to-fill.

When you use `Material`, you normally do not want to use `TZoom` and friends, since `Material` comes with
good defaults for sizes of things depending on your DPI.

TSelect
-------

This is the construct to use for dynamic parts of the user interface. `TSelect` is really implemented through `TMutable`, which stores a concrete value. (There is also a variant called TFSelect, which uses the Transform-fusion-enabled behaviours. These are useful to avoid leaks from behaviour transforms. This is an advanced topic, you can read about in `lib/fusion.flow` to understand this better.)

TIf
---

A common pattern is to have two variants of something on the screen. The `TIf` construct is optimized for this use case:

	TIf(condition : Transform<bool>, then : Tropic, else : Tropic);

The advantage of having this construct compared to a `TSelect` with a function with an `if`, is that everything is data, and that in turns means that it is open for optimizations. In particular, if the then-branch and the else-branch share the same decoration, it can be lifted outside of the TIf, so as little as possible in the screen becomes dynamic.

Embedding Form
--------------

It is possible to reuse existing `Form` code seamlessly in `Tropic` by using the `TForm` element:

	import tropic/trender;
    import ui/easybutton;

    main() {
        withForm = 
                TCols2(
                    TText("Here comes a form: ", []), 
                    TForm(EasyButton("Click me", "", orange, \ -> println("Click"), []))
                );
	    trender(withForm, []);
	}

This works for any kind of `Form`. This is useful as a way to reuse existing code using Form. When using `TForm`, the embedded Form will get 0,0 available area, and the resulting size will be the size of the `Form`.

If you need some `Form` constructs to adapt to some available area, you can use `TFormIn`:

	import tropic/trender;
	import form/gui;
	import ui/easybutton;

	main() {
		trender(
			TFormIn(
				Align(0.5, 0.5, EasyButton("Centered", "", orange, \ -> println("Click"), [])),
				TFillXY()
			),
			[]
		);
	}

This will center the button using the Form `Align` in the box provided by Tropic. This way, you can use Tropic to implement resizing designs using Form components relatively easily. The size of a `TFormIn` is given by the Tropic box. It is thus not possible to have a resizing `Form` tell Tropic how big it is. Either Form decides from available 0,0, or Tropic decides the size.

Since `Form` can contain code, we recommend that you use the native Tropic versions of elements whenever possible. See `tropic_gui.flow` for useful helpers, as well as `tropic_ui.flow` for various wrappers of `Form` user interface elements using Tropic interfaces.

Having both a minimum and maximum size
--------------------------------------

Often, you want to construct an area of a given minimum size, such that it can grow up to another size.
This constructs a `TRectangle` which has a minimum size of 100x100, but a maximum of 1000x1000 pixels:

	import tropic/trender;

	main() {
		trender(
			TRectangle(
				[Fill(0xff0000)], 
				// Construct a fill rect of min 100x100, max 1000x1000 pixels
				TFillXYXY(100.0, 100.0, 1000.0, 1000.0)
			),
			[]
		);
	}

This is so common that we have added helpers `TFillXH`, `TFillWY` and `TFillXYXY` which define
fillers with fixed size.  See `tropic_gui.flow` for the full story.

TAttach
-------

Since `Tropic` uses other `Tropic` elements for most layout jobs, this causes an increase in the number of `Tropic`s to deal with by the layout engine. This is normally not a problem, but in some cases, profiling shows that there is a problem. In those cases, it is possible to use `TAttach` to retrieve the specific metrics of a given Tropic, and use code to perform the layout of other logic that depends on the metrics.

Drag'n'drop
-----------

Tropic supports a simple interface to implementing drag'n'drop in your GUI. The drops are communicated through a behaviour, using identification values that you choose yourself.

To use drag'n'drop, you first have to construct a `TManager`, which is done with `makeTManager`. 
You initialize this manager with a default identification value that signifies nothing is being dropped.

Then use `TDraggable` to construct draggable items in your user interface. Use `TDropSpot` to define areas
where drags can be dropped. If you use draggable element also as dropSpot you should specify `TDragShape`
style with a certain tropic which isn't the same as stationary and not `TEmpty`.

A key thing is that you have to use `trenderManager` to render your tropic user interface before
drag'n'drop will work.

See `tropic_dragdrop.flow` and `tropic_manager.flow` for the full interface. If you use Material, there
is a corresponding construct in `material.flow`.

Advanced topics
===============

In the following, more advanced topics are discussed. When getting started, those things are not of importance to you. If you are using the `Material` library, there are more direct solutions available to many of the problems discussed, so you can skip this section.

GUI components
--------------

There are a number of GUI components written directly in Tropic. See `tropic_ui.flow` for `TTextInput`, 
`TTextButton`, `TRawButton` and `TTab` for tab control.

For a button, use `TTextButton`, or if that is not flexible enough, `TRawButton`. This construct is 
hopefully strong enough to be able to realize all the hundreds of buttons we have in `Form` with 
trivial code.

But as mentioned, normally, you want to use the Material components, which have a higher level of
graphical design, and better support for touch-devices out of the box.

TParagraph
----------

There is a paragraph construct in `Tropic`, which will word wrap text and other non-mutable constructs.
In contrast to a `Paragraph` in `Form`, the `TParagraph` will NOT reflow the contents if an element changes
size after construction. In addition, you have to provide a minimum and a maximum width for your paragraph. 
The reason is that a paragraph does not scale linearly, and that is hard to handle in layout. If the available 
width is very small, then the paragraph becomes very tall. At the other extreme, if the available width is
very big, the paragraph becomes very short.

`Tropic` is not smart enough to exploit this to find the best way to use the available space, so therefore
we require a reasonable minimum and maximum width for each `TParagraph`. This helps avoid the extreme cases,
and makes layout easier. A consequence is that a `TParagraph` will sometimes have extra unused space at the
bottom, but this is unavoidable with the current layout algorithm.

It turns out that very short or very long lines are hard to read, so from a usability point of view,
it is not necessarily a disadvantage to restrict the range of widths for a paragraph. In 
*The Elements of Typographic Style*, Robert Bringhurst recommends somewhere between 45 and 75 characters.
If you have a paragraph with only text of the same font in it, then the helper `TTextParagraph` will implement
that heuristic, although we allow slightly slimmer paragraphs with a minimum of 35 characters.

Performance considerations
--------------------------

Tropic is faster than `Form` for some things, and slower for other things. The key to understanding Tropic performance is to know that each Tropic goes through 4 different phases:

1. Optimize Tropic
2. Construct Tropic and metrics (fusion)
3. Display through FForm
4. Disposal

The key difference between `Form` and `Tropic` lies in the optimization phase, as well as the metrics. In `Form`, the metrics phase can be very expensive, because it is very easy by mistake to make a layout-metric loop, which causes performance problems. This happens much less frequently in Tropic, but at the cost of bigger set-up time.

To render a Tropic, the Tropic structure first has to be optimized, and then all the metric calculations have be constructed, including conversion to `FForm`. If you profile rendering Tropic, you will see calls like `optimizeTropic`, `fuse` and `doFuse` in the profile. These correspond to phases 1 & 2. There will also be some "special" entries in the profile, which correspond to the physical rendering itself, but it is surprising to see how much time metrics, setup and destruction itself takes.

The best way to make sure your Tropic is fast is to make it as tight as possible. The time required is proportional to the number of Tropics that you need to display. For that reason, do not duplicate the same big chunk of Tropic many times if it can be avoided.

Imagine we want to display the same complicated Tropic two times below each others. A naive implementation might look like this:

	TRepeatBad(a : Tropic) {
		TLines2(a, a)
	}

However, this function will double the size of the argument, since it is repeated twice. This will cause the optimization phase of tropic to be twice as long, since it has to be done two times, once for each `a`. To avoid this, it is better to use `TLet`:

	TRepeatBetter(a : Tropic) {
		TLet("a", a, TLines2(TDisplay("a"), TDisplay("a"))
	}

Now Tropic only has to optimize the `a` Tropic once, and then it can be used twice to display it. This is faster in most cases. The exception would be cases where `a` is very simple, such as a single `TText` or other element without other Tropic children.

If you find yourself in this situation, there is a profiler for Tropic in `tropic/tropic_profile.flow`. You can call the function `profileTropic` with the Tropic you display, and get a break down of the size as well as sharing in it. Notice this does not go "beneath" TSelect and TMutable, so you have to make sure you give it the right values for the analysis to make sense.

Physical sizes & ghosts
-----------------------

In Tropic, we avoid using physical sizes, but instead manipulate and represent them in the form of concrete `Tropic` elements, or so-called *ghosts*. 

A *ghost* is an invisible, but real box with the same metrics as the original Tropic element it refers to. As such, it is a concrete element, just like a filler is. Everything in tropic is concrete. You will see how to make a ghost in the next section.

So we rarely work on metrics directly in Tropic, but only on actual physical elements. The important insight is that everything is physical. The reason for this design is to make `Tropic` behave like a small algebra for working with design.

Let's see how to make a ghost using assignments.

Assignments
-----------

In Tropic, `TLet` introduces an assignment. This defines a named value within a scope. The family of `TLet`, `TDisplay` and `TGhost` allows for implementing a pattern to use the size of elements in building layout:

		TLet(
			"pic", TPicture("www/images/roadsigns/redcircle.png", []),
			TGroup2(
				TDisplay("pic"),
				TCenterIn(
					TText("Hello", []),
					TGhost("pic")
				)
			)
		);

Notice the `TLet` that defines a named item "pic", which is then referenced for displaying in `TDisplay` and as the ghost for another item in a `TCenter`. This way we can make any `Tropic` control the available size for another `Tropic`.

Notice again the `TGhost` element, which is a real, but invisible, `Tropic` with the specified metrics.

It is important that you use `TDisplay` at some point in the scope of the `TLet`, otherwise `TGhost` will not work. The reason is that the size of the ghost is only defined once the value is displayed.

You can display a let-bound tropic multiple times. In this case, the TGhost will refer to the last occurrence, but it is probably not a good style to rely on this.

Notice you have to display any `TDisplay` and `TGhost` at the same rendering point in time as the `TLet` binding happens. I.e. you can not have a `TLet` with a TSelect in the scope with `TDisplay` inside, since the scope might be executed much later, and then the binding is not valid anymore.

While `TLet` and friends are useful constructs, we recommend that you try to find a suitable helper that can do the specific size-adjustments you are looking for.

Zoom fill
---------

A great construct in Tropic `TZoomFill`. This construct will scale up the child to exploit the available space, preserving the aspect ratio of the child, but in such a way that the fillers of the child will expand well enough to match the aspect ratio of the fill box. This is typically used at the top-level of your Tropic user interface to make it scale nice.
It effectively means that we will scale as much as we can, without breaking the aspect ratio, including to reduce fillers to make zoom possible.

In Material, there is little need for TZoomFill, since Material comes with good DPI-adjustments out of the box.

Pixels and hi-res screens for high-design Tropic UIs
----------------------------------------------------

Since `Tropic` is vector-based in the sense that anything but pictures can be resized without becoming pixelized, we are in fact free to choose whatever unit we want instead of physical pixels. As you can see above, `Tropic` continues the tradition of using pixels for metrics in `TFixed`, `TBorder`, `TTranslate`, font-sizes as well as maximums in `TAvailable`.

Why is this?

The primary reason is that this makes it easier to implement graphical designs, which typically come in PNG or PSD files with physical pixels. That makes it simpler to measure things and use the proper constants in the code.

However, there is also another more subtle reason, which deals with how to make designs that work well on retina devices.

The key insight to make user interfaces work well on many devices is to reduce the complexity of the task. Tropic supports one particular approach, which can help by employing a simple rule:

- Implement your user interface as if you work on a standard 160 DPI display non-retina device
- Make sure to implement your user interface in the smallest reasonable version, typically minimum 480x480 although this can vary. (If you target a mobile device, remember your minimal size has to have room for any virtual keyboard.)
- Next, using fillers, make sure your interface looks great in max resolution of maybe 1536x1536.

This means that we resize well in all aspect ratios from 480x480 pixels up to 1536x1536 pixels.

If you follow these rules, then the process of getting the design to work everywhere is simple: At the top level, we first scale the entire thing according to DPI to fit the theoretical 160 DPI. So if you have a retina device with 192 DPI, then we basically enlarge everything by a factor of 1,2 to compensate. (On the web, where we do not have a reliable DPI measurement, we can just assume that the DPI is bigger when the width is more than 1536 pixels.)

Next, we render the entire thing, and just zoom it to fit using `TZoomFill`.

Proper use of the maximum size in a `TAvailable` will help you to make your design not grow bigger than the recommended 1536x1536 pixels. At some point, you do not want your user interface to expand more, but rather instead zoom up.

	import tropic/trender;

	main() {
		trender(
			TZoomFill(
				TGrid([
					[ TText("NW", []), TFillX(), TText("NE", []) ],
					[ TFillY() ],
					[ TFillX(), TText("Center", []), TFillX()],
					[ TFillY() ],
					[ TText("SW", []), TFillX(), TText("SE", []) ],
				]),
			),
			[]
		);
	}

This example demonstrates the concept: Make a user interface, which has a very small minimum size, but
can grow up to a bigger size. The span covers a wide range of different aspect ratios. Then the entire
thing is wrapped with the TZoomFill, and now the user interface will look and behave great on all sorts
of DPIs and resolutions.

The `trender` call will do any required retina scaling, as well as add hooks to get Ctrl + and Ctrl - zooming
working. So normally, you will not be using `tropic2form`, but rather `trender` to display your tropic GUI.

The second parameter of `trender` is an array of TRenderStyle union elements. TRender style 
includes a `Stylesheet` structure. Setting `Stylesheet` in trender gives ability to use CSS stylesheets to 
skin Tropic user interfaces. See `doc/css.markdown` for more information.

Making two tropics the same size without scaling
------------------------------------------------

Let's say we have two `Tropic`s of unknown size, but we want to display them beneath each other
with the same row height (the maximum of the two). How is that done? In `Form`, we would start
with `Inspect`, behaviours and so on like before. If we were not careful, our implementation might 
runs into infinite loops, because since the available space would change, that might cause subtle 
change in the sizes, causing things to loop between the two as being the biggest.

We don't want that, so how do we solve this problem in `Tropic`? The trick is to use `TGroup2` to
find the maximum of two sizes. Let's define a function `TLines2SameSize`, which takes two `Tropics`, 
finds their maximum size, and returns a new `Tropic` where they are centered in that box.

	TLines2SameSize(a : Tropic, b : Tropic) -> Tropic {
		TLet("a", a,
			TLet("b", b,
				TLet("max", TGroup2(TGhost("a"), TGhost("b")),
					TLines2(
						TCenterIn(TDisplay("a"), TDisplay("max")),
						TCenterIn(TDisplay("b"), TGhost("max")),
					)
				)
			)
		)
	}

It is hard to make a layout loop in `Tropic`,
unless you have one in a `TForm`, `TFormIn`, `TAttach` or with a behaviour loop triggering problems
in `TSelect` that might have side-effects.

Size arithmetic
---------------

As you can see, all sizes are expressed as real `Tropic` elements, not as a separate size-structure. 
Therefore, it is generally useful to understand how to manipulate the metrics in the world of `Tropic`.
The following explains how to do size arithmetic using different `Tropic` constructs:

	maximum(s1, s2) = TGroup2(s1, s2)
	minimum(s1, s2) = TMinimumGroup2(s1, s2)
	c * s1 = TScale(const(Factor(c, c)), s1)
	width(s1) = TScale(const(Factor(1.0, 0.0)), s1)
	height(s1) = TScale(const(Factor(0.0, 1.0)), s1)
	addWidth(s1, s2) = TCol2(s1, s2)
	addHeight(s1, s2) = TLines2(s1, s2)
	s1 + s2 = TCols2(TLines2(s1, s2), s2) = TLet("s2", s2, TCols2(TLines2(s1, TDisplay("s2")), TGhost("s2")))
	s1 - s2 = TSubtractGroup(s1, s2)

Remember that all of these operations are physical, so they will all display something if s1 or s2
is not a ghost.

Tooltips
-----------

Tropic also supports tooltips, use `TTooltip` from `tropic_ui.flow`. Notice that tropic tooltips using is possible only through
`trenderManager`, because `TTooltip` uses `TManager.xy` field as mouse global coordinates for positioning.

Stylesheet
----------

It is possible to use CSS stylesheets to skin Tropic user interfaces. To do this, parse a CSS file, process it, and get a Stylesheet. Then you send this to the `trender` call you need, and everyplace where a `TStyle` is given, the stylesheet will be consulted. You can also use `TStyleWithSelector` if needed.

`TText` supports these properties from CSS stylesheet: `font-family`, `font-size`, `font-background`, `font-weight`, `font-style`, `text-decoration`, `color`, `letter-spacing`, `opacity`.


`TRounded` and `TFrame` use properties `background`, `width`, `height`, `border-radius`, `border-*-radius`, `opacity`.

`TTextButton` use all properties that `TText` is using and all properties from `TRounded`. Be careful, if `background` and `font-background` have different values, result will look strange.
Don't set `width` and `height` properties to style that you use with `TTextButton`, button will not look correctly.
To set different views for `TTextButton` in different states(hovered, pressed, disabled), use css selectors `:hovered`, `:pressed`, `:disabled`.

	TCssBlock(style : [TCssBlockStyle], tropic : Tropic);
		TCssBlockStyle ::= TStyle, TStyleWithSelector;

`TCssBlock` - allows you to create a Tropic from a CSS style. The second argument will be rendered, if unable to create Tropic from css stylesheet.
Currently it is trying to create `TGroup2(TRounded, TPicture)`, if there enough properties in given css style.

Built-in rendering
------------------

In JS by default both Tropic and Material are rendered, using `<body>` as a root. You can make it via `trender` and `mrender`, respectively.

But there is also an option to render them inside some specific element on a page. To make it, you should have static HTML page and
add `<script type="text/javascript" src="flow_starter.js?name=<script_name>"></script>` to it. On flow side use `RenderRoot` style in `makeMaterialManager` with id of some html element on a page, which you want to be considered as renderRoot. It would be nice to set width/height attributes for this element, but default case is also handled.

Multiple render roots are also supported, but in this case you have to create separate MaterialManager for each root.

You will be able to find all flow stuff inside shadow DOM.

Check [html](../www/test/test_flow_builtin.html) + [flow](../lib/material/test/test_flow_builtin.flow) for a tescase.

Pay attention to the fact that this feature is available for JS target only.