*form*
======

*form* is an embedded domain specific language for building interactive user interfaces. 
It is influenced by SVG and HTML document models, as well as common user interface toolkits 
like WinForms, Qt and GTK. It tries to make it easier to make dynamic, animated, 
optimized designs using declarative programming.

Based on the experience of using *form* for years, we have since implemented `Tropic` 
and `Material`. `Material` is the recommended technology to build UIs, and can be
seen as an improved version of *form*. This document explains the background of *form*
and thus `Material`, including behaviours, FRP and compositionality, all of which is
still relevant in `Material`.

Design goals
------------

The main goals of *form* are the following:

 - To allow quick and correct implementation of visually beautiful, interactive user
   interfaces
 - To be compositional, meaning that the user interfaces should be built from blocks,
   which themselves can be built from other, lower-level blocks.
 - To support a wide range of targets and display resolutions, and still preserve the
   ability to easily design beautiful and functional user interfaces

*form* is implemented in *flow*. The blocks are expressed as a mix of fundamental, lower-level
structs such as `Text`, `Picture`, `Graphic` and `Interactive`, and then a layer of convenient
higher-level blocks such as `Table2d` and `Slider`.

Hello world
-----------

To whet your appetite, here is "Hello world":

	import form/form;
	import form/renderform;

	main() {
		render(Text("Hello world!", []));
	}

First, we import the `Form` types, and the rendering backend. In `main`, we simply call `render` which
will render the given `Form`. In this case, the `Form` is a simple `Text`. The empty array is a place
for styling information for the text, but in this case, we are happy with the default font style
so the array is empty.

What is a `Form` anyway?
------------------------

The practical definition of a `Form` is

  1. a struct which is a subtype of the `Form` type, or
  2. it is a function which produces such a thing.

To better understand what this means, let's take a look at the prototype of the low-level function
that `render` calls to render a form (see `flow/renderform.flow` if you want to read all of it):

	renderForm(rform : Form, available : Behaviour<WidthHeight>) -> RenderResult;

where RenderResult is defined like this:

	RenderResult(clips : [native], widthHeight : Behaviour<WidthHeight>,
	             dispose : () -> void, capabilities : ClipCapabilities)	;

First of all, we can see that when we render something, it produces a list of clips. Clips
is the `native` type that can display something. This is similar to a `Sprite` (i.e. `MovieClip`)
as known from Flash, while it could be a `Canvas` in HTML5, or some native graphics element on 
the iPhone or with Android.

Secondly, the `Form` is a value-type, which can be produced by functions, copied, composed into
a new `Form`. One key benefit is that the re-layout of the user interface is handled automatically 
when changes occur in the user interface, and as you will find, the use of behaviours make dynamic
UI easier to handle.

The second parameter to the call is a *behaviour*: the `available` metric. For now, consider this
as a size which specifies how much space is available for this `Form` to render itself. The `Form`
does not have to obey this specification. Consider it a hint given by the surrounding environment
which is useful for some `Form`s to work well. The prime example is the `Align` form which can
center, right-align or bottom-align a `Form` in some available space.
(In case the content of the `Align` can not fit in the available space, it just ends up
putting itself where it is and uses as much space as is necessary, overflowing the available space.)

Besides the clips, the result of the function gives the resulting width and height of itself here and
a dispose function (as well as a capabilities structure which is used for optimizations, and can be
ignored here.)
So every `Form` has a size, which is always a rectangle. The visual look of a `Form` can obviously
be anything but a rectangle, but in terms of layout, positioning and so on, all `Form`s are rectangular. 
In practice, most `Form`s will announce the tight bounding rectangle that contains the contents of
the `Form`.

The final interesting thing about rendering a `Form` is that it also returns a disposal function.
This is a convention used in the implementation of `Form`, which is key to the support of dynamic,
changing user interfaces. This function coming out of the rendering pipeline has a
simple, but important purpose: When you call this function, the form will be disposed of and
disappear from the screen, freeing up any resources or event handlers registered to handle it.

This insight to integrate the destruction of `Form`s with the rendering might seem like a simple
implementation detail, but in fact, it is the key to support correct compositional construction
of dynamic user interfaces. There are two tasks to building a dynamic user interface:
Constructing things on the screen, but it is just as important to be able to remove it again. The
disposers play a key role in making this possible.

To understand this a little better, let's introduce the underlying helping structure that allows
the efficient implementation of changing forms in *flow*: Behaviours.

Behaviours
----------

Behaviours are a construct known from
[functional reactive programming](http://okmij.org/ftp/Computation/monads.html#fair-bt-stream)
([overview paper](http://www.cs.rit.edu/~eca7215/frp-independent-study/Survey.pdf)),
found as libraries for
[Haskell](http://www.haskell.org/haskellwiki/Functional_Reactive_Programming),
[JavaScript](http://www.flapjax-lang.org/docs/) ([2](http://www.cs.brown.edu/~sk/Publications/Papers/Published/mgbcgbk-flapjax/paper.pdf)),
and other languages. They are somewhat similar to signal/slots as known from Qt and
other places. They also exist in C# as the
[Rx framework](http://msdn.microsoft.com/en-us/devlabs/ee794896.aspx)
([2](http://msdn.microsoft.com/en-us/library/ff403103\(v=VS.92\).aspx))
([3](http://rxwiki.wikidot.com/101samples#toc24))
from Microsoft. There is also [research](http://www.mpi-sws.org/~umut/papers/pldi10.pdf) about
how to optimize such things, although that is not directly applicable to our purposes.

The main point of a behaviour is to capture dynamic values over time. It works by setting up a
behaviour with a default value of some type by calling `make`. Observers can subscribe to this
behaviour using `subscribe`, and will get notified when a new value is "sent" using `next`.
Importantly, `subscribe` returns a disposal function which can be called to unsubscribe from a
behaviour again, after which any changes to the behaviour are ignored by that subscription. Let's
look at an example illustrating this:

	a = make(0.0);
	dispose = subscribe(a, \v -> println(v));
	next(a, 1.0);
	dispose();
	next(a, 2.0);

First, we construct a behaviour. They are so frequently used that we use the short name `make`
for construction it. Next, we `subscribe` to it so that we will print the values this
behaviour experiences. (`\v -> println(v)` is the declaration of an anonymous lambda function
that takes one parameter `v` and executes the body `println(v)` when called.) Then, we
change the value of it using `next`, `dispose` of the subscription, and finally sends
another value (to no-one). At first, you might think that this program prints

	1

but in fact, it prints

	0
	1

Why is that? That is because the variant of Functional Reactive Programming we use *always* has a
value. You can query this value at any time using `getValue`. This is different from so-called
*observables*, which do not start out with a default value. They are more complicated to deal
with because you have to handle the uninitialized value all over the place, and it turns out that
the code is much easier to write when you can rely on every behaviour to have a value. So since
the behaviour has a value when we `subscribe` to it, subscribe will make sure we are immediately
notified of the current value, so that we can also maintain that property of always having a
value from the start.

And that is really all there is to the behaviour.

So seemingly a very simple concept, so why all the hoopla around them? Well, the behaviours
really start to make sense when they are combined with transformations which can "listen" to
multiple behaviours at the same time, transform them to other types, sample them at regular
intervals, and other things. This allows you to implement spreadsheet-like functionality in a
declarative and safe way:

	a1 = make(4.0);
	a2 = make(3.0);
	sum = select2(a1, a2, \v1, v2 -> v1+v2); // is 7 now
	average = select(sum, \v -> v / 2.0); // is 3.5 now
	timer(2000, \ ->
		next(a2, 1.0) // After 2 seconds, sum and average are updated to 5.0 and 2.5
	);

In this code, `select2` will monitor the given behaviours, and every time one of them changes, it
will transform (project) the value using the given function. The result is a new behaviour, which then can
be composed with other behaviours. (The name `select` comes from SQL, where it serves the same
role although that is not immediately clear. 
Read [this blog post](https://blogs.msdn.microsoft.com/ericwhite/2008/04/22/projection-2/) 
about projection for better understanding.)

The main point here is that behaviours and transformations of behaviours are compositional. You
can stack them together in a complex dependency graph. (If you make a loop, the program will go
into a infinite loop, though. There are transformations that allow you to break such loops, such
as `distinctUntilChanged`, `untilChanged`, `throttle` and `delay`, but if you want to mess it up,
you can.)

A behaviour is always available for composition, and has a value. Mentally, it is useful to
consider behaviours as streams of values that change one after another. That can happen in the
same "time step" or call-stack of the execution, but it can also happen when an event happens 
later in real time, such as after a mouse click. It is useful to picture the behaviours as a line 
with changing values as time goes to the right, and transformations as taking these values at 
various points in time and then produce a new one:

	a1:      4.0 ------------------------------------>
	a2:      3.0 ------ 1.0 ------------------------->
	          ||         ||
	          \/         \/
	sum:     7.0------- 5.0 ------------------------->
              ||         ||
              \/         \/
	average: 3.5--------2.5 ------------------------->

Flow comes with a very simple implementation of behaviours, along with a set of useful
transformations. The links above contain hundreds of different transformations that are useful in
various circumstances. Most simple transformations are not more than 5 lines of code, and
up to 20 lines for a really complicated one, but combining them gives the power. As an example, 
here is the implementation of `select`:

	select(behaviour, fn) {
		// subscribe immediately calls the function, so we start out with mapping the initial value
		provider = make(fn(getValue(behaviour)));
		subscribe2(behaviour, \v -> next(provider, fn(v)));
		provider;
	}

(If you check the source code, you will see that the production implementation is slightly
different, but those subtleties are not important for now.)

In `Form`, the behaviours are used to support dynamically updating user interfaces: A `Mutable`
observes a stream of `Form`s, implemented as a behaviour. This is the full declaration of the
`Mutable` form:

	Mutable(form : Behaviour<Form>);

To see this in action, here is a program that automatically changes the text after 2 seconds, and
cleans itself up after 4 seconds.

	form = make(Text("Hello", []));
	dispose = render(Mutable(form));
	timer(2000, \ -> next(form, Text("world!", [])));
	timer(4000, \ -> dispose());

But we are getting ahead of ourselves. Let's turn the attention to the basic `Form`s available
first.

Physical forms
---------------

Let's start with the simplest `Form` there is:

	Empty();

`Empty` is the empty form. It has size 0.0,0.0, and is useful to remove parts of an interface when
they serve no purpose anymore.

Next up is the Text, which we saw a minute ago:

	Text(text : string, style : [CharacterStyle]);

This is a static text in a given character style. `CharacterStyle` is a union of concrete
style attributes such as `FontFamily`, `FontSize`, and `Fill` for specifying the text color. It
uses another pattern in `Form`: Instead of having an ever increasing number of arguments, we use 
an array of properties instead and only include those we need to change from the defaults. This 
is better for making the code readable, and it is easier to extend with new style features this 
way.

Besides the `Text` form, there are other similar forms for `Picture`s, vector `Graphic`s.
See the `lib/form.flow` file for documentation about these. It is interesting to note that the
`Picture` form reports its size as 0.0,0.0 until the picture is loaded, which can happen many seconds
later. But since everything is set up to handle dynamic changes, this does not have any harmful
consequences: Once the `Picture` has been loaded and is inserted, the code just sends out the
new size, and everything updates accordingly. Gone are the days where you had to insert the
size of the JPG in the code.

Compositional forms
-------------------

The next category of forms are compositional. The first is

	Group(layers : [Form]);

which takes an array of forms, and arranges them on top of each other in separate layers.
The first element goes the farthest away from the screen into the back, while the last
one is on top in the z-order. The size of this group is the total bounding rectangle
that can contain all children.

The other main compositional form is the `Grid`:

	Grid(cells: [[Form]]);

This is a simple, 2d grid that arranges the children in an aligned table. The height of
a row is defined by the highest form in that row, and similarly for the columns. The
Grid does *not* expose any "filling" behaviour. They just arrange the elements in a 
predictable grid without expanding anything. (That said, the cells in the table will 
get the `available` size reported to exploit any free space there is in that row/column 
cell size.)

It goes without saying that the Grid supports changing metrics of the children, and will move
everything around to fit the grid when changes in sizes happen in some cell.

If you need to make a table that exploits the available space with fancy resizing, or you need
to have "colspan"- or "rowspan"-like behaviour, then look for `ui/table2d`.

Transformational forms
----------------------

All `Form`s define their own coordinate system starting at 0.0,0.0 in the upper, left corner.
A complete set of `Form`s allow you to manipulate these coordinate systems. As an example,
let's take a look at `Translate`:

	Translate(x : Behaviour<double>, y : Behaviour<double>, form : Form);

This will render the child form at the given offset from the parent. The size of the form itself
is the same as the child form, even though it is positioned differently. (If you want the size
to change along with movements, either use `Border` for static offsets or a combination of `Size`
and `Inspect` forms and some secret behaviour transformations). If the behaviour of `x` or `y`
changes, the form will move accordingly. This provides an easy way to implement animation of a
form: Just construct a transformation that generate a stream of coordinates over time, and away it
goes.

In this family of forms, you will also find `Scale` which does change metrics, and `Rotate`,
which does not. It turns out that you hardly never want that anyways.

`Alpha` can adjust the complete transparency of a form into this category, although it does not 
change any coordinate systems. Another related `Form` called `Mask` which can do an alpha-channel 
style masking of a form with another form as the alpha channel does change the metrics of the 
result based on the *mask* only. If you want to hide a form, then use `Visible`. Notice that the 
size changes to 0,0 once you hide a form using `Visible`.

The `Crop` form allows you to cut out to a specific rectangle of a form. This is useful for
cropping images and other elements, or for implementing scrolling panes with scrollbars.

Another category of transformational forms contains `Align`, which provides a way to center-,
right- or bottom-align forms in the available space. Related to this is the `Available` form
which provides a way to override the available space for a form from the environment. Using
this form, you can simply dictate how much available space to report to the children.
Notice that `Align` changes the size of the resulting form to match the available area. This
is often *not* what you need. For those cases where you want the size to remain the same,
use `Align2` instead.
Of a similar nature, we have the `Size` form, which provides a way to dictate the size of
a given form to any interested parties, regardless of the physical size it might have.

In `gui.flow`, there is a bunch of helpful forms that can resize forms to specific sizes,
exploit available space, and similar.

Dynamic forms
-------------

There are two main dynamic forms in *form*: The `Mutable` form we say earlier and the
`Switch` form:

	Mutable(form : Behaviour<Form>);
	Switch(case : Behaviour<int>, cases: [Form]);

The first parameter to `Switch` is a integer, which defines which "case" to display. The cases are packed
together in the array, and when the `case` changes, the user interface changes accordingly. This
is not more efficient than a `Mutable`, but sometimes convenient. You might consider to use an
`Alpha` if you want to hide something temporarily, but restore it again without reconstructing it
from scratch for performance reasons. However, that is often a bad idea, because that will not
prevent spurious mouse events from disturbing things. It is better to just use `Visible` and
`Invisible` from `gui.flow` which can be considered for elements that need to be hidden and shown at
various points in time.

Meta-forms
----------

Let's turn the attention to the first interesting meta-form:

	Disposer(form : Form, fn : () -> void);

This form is special in that it has no special visual representation itself, or even any effect
on the child. It looks exactly like the `Form` it takes as a child, so customers will never know
it is there. The interesting thing about a `Disposer` is that it comes out at night, when it is
disposed of into the dark. At that point, it will first dispose of the child, and after that,
call the given function before it fades away. This is useful when you have additional
subscriptions or other resources associated with the logic or presentation of the child forms,
because it provides a principled approach to handle the thorny problem of cleaning up after
ourselves.

Alternative to `Disposer` form is the following:

	Constructor(form : Form, fn : () -> () -> void);

Like `Disposer` it has no visual representation itself. It provides not only dispose facility,
but also construct one. The function provided is a good place for additional subscriptions or other
resources associated with the logic or presentation of the child: it will be called just before
form rendering, and the returned disposer will be called on form dispose. While `Disposer` could be
used for once living forms only, `Constructor` could be reused with all its resources as many
times as required.

The `Disposer` and `Constructor` forms are also remarkable for another reason: they are the only
`Form`s which does not take any child `Form` as the *last* parameter. That is otherwise the
convention which all `Form`s should obey to avoid social isolation. However, the disposable
function is called at the end of the form's life, so it made sense to put the form as the first
parameter.

Another useful meta-form is the `Inspect` form, which provides a disciplined approach to extract
metric information about a form:

	Inspect(inspectors : [Inspector], form : Form);

Now, this declaration does not make much sense without clarifying what the `Inspector` type is:

	Inspector ::= ISize, IAvailable2;
		ISize(widthHeight : DynamicBehaviour<WidthHeight>);
		IAvailable2(widthHeight : DynamicBehaviour<WidthHeight>);

Now the picture emerges. Using the `Inspect` form, you have a handy way to learn the dimensions
of a form. Notice how the behaviours help again. Since everything is compositional, you can do 
things like this:

	size = make(WidthHeight(0.0, 0.0));
	avail = make(WidthHeight(0.0, 0.0));

	// A monitor of a sizes value. To prevent infinite updates, we stay a fixed size
	m = \n, wh -> Size2(
		// This is a constant behaviour, and a more efficient
		// version of make() when you know the value never changes.
		const(WidthHeight(80.0, 20.0)),
		Select(wh, \cwh -> {   // Select(...) is a better version of Mutable(select(...))
			t = n + ":" + d2s(cwh.width) + "x" + d2s(cwh.height);
			Text(t, [])
		})
	);

	d = render(Inspect(
		[ ISize(size), IAvailable2(avail) ],
		Grid([
			[ m("Size", size) ],
			[ m("Available", avail) ],
		])
	));

When you run this, you get the metrics of the display of the metrics themselves displayed. As you
resize the window, the metrics for the available area updates automatically. If you wanted to, it
would be trivial to calculate and display the screen area in pixels this way using a simple
`select2`. It's a one-liner, so try to find it.

Layout, `Grid` and available space
----------------------------------

A fundamental part of *form* is how layout is handled. The ingredients of layout are the
notions of size, available space, and how things are positioned relative to each other.

In terms of the size, most `Form`s have an intrinsic size that is purely a function of parameters
of that `Form`. The exception concerns functions that resize themselves based on how much
available space is available. As examples of such, consider these two:

  - The `Align` form
  - The `Inspect` form when `AvailableWidth` and `AvailableHeight` are inspected

Transitively, if another form contains one of these elements as a child or subchild, it might
itself become dependent on the available space. I.e.

	Group([ Text("Top left", []), Align(0.5, 0.5, Text("Hello!", [])) ])

will grow as more space is available. (See the function `availableDependent` in `optimizeForm.flow`
for the specific definition.)

The main exception to this rule is the `Grid`. The `Grid` itself is *never* dependent on the
available space. It is always conservative and will only take up as much space as is minimally
required by its cells. Why is this so? Wouldn't it be useful to distribute any available
space evenly to the children according to some criteria? Yes, that is useful in some situations,
but experience with Arctic shows that this complicates layout unnecessarily. Having that behaviour
is simply too fragile. Change a single cell in the bottom right corner of the grid, and suddenly,
the entire grid takes a completely new layout, even introducing scrollbars in areas of the design
which fit before. Life is too short to debug such crap, especially since the change could be done
deep inside some function far away from the grid itself.

For this reason, the Grid is strict and will totally ignore any available width and just do its
own thing. Notice that this can cause surprises. You might think code like this will effectively
right-align the "Hello world" text:

	Grid([ [ Align(1.0, 0.0, Empty()), Text("Hello world", []) ] ]);

However, it does not. In fact, this code behaves exactly like this:

	Text("Hello world", []);

And similarly, if you do this:

	aw = make(0.0);
	ah = make(0.0);
	Grid([ [ Inspect([AvailableWidth(aw), AvailableHeight(ah)], Empty()), Fixed(10.0, 20.0) ] ]);

you might expect `aw` and `ah` to get the available space of the grid, constrained by the fixed element
at the end. However, the reality is that in `aw` will be 0.0 constantly, and `ah` will be 20.0, no matter
how much available space is available to the grid.

If you want to distribute available space to children of a Grid, you have to do that manually:

	aw = make(0.0);
	ah = make(0.0);
	Inspect([AvailableWidth(aw), AvailableHeight(ah)], Grid( myCells(aw, ah) );

where myCells will have to distribute the available space to the cells after whatever criteria you need
using the `Available` form to dictate how much each column or cell gets.

In practice, doing this quickly becomes tedious, so we have a bunch of helpers that are useful for making
layout. In particular, have a look at `ui/table2d.flow`.


Interactive forms
-----------------

The final basic `Form` is the one that makes interactive user interfaces possible. It might
surprise you to learn that there is in fact only one single `Form` for all interactions with
the user:

	Interactive(listeners: [EventHandler], form : Form);

Once again, it is hard to understand without the EventHandler type listed, so let's show that,
in simplified form:

	EventHandler ::= MouseDown, MouseUp, MouseMove, RollOver, RollOut, KeyDown, KeyUp;

	MouseDown(fn : (() -> MouseInfo) -> bool);
	MouseUp(fn : (() -> MouseInfo) -> void);
	MouseMove : (fn : (() -> MouseInfo) -> void);
	// Into this form (or any of the children). Ignore the mouse hit bool for best results
	RollOver : (fn : (() -> MouseInfo) -> void);
	RollOut : (fn : (() -> MouseInfo) -> void);
		MouseInfo(x : double, y : double, inside : bool);
	MouseWheel(fn : (() -> MouseWheelInfo) -> void);
		MouseWheelInfo(x : double, y : double, delta : double, inside : bool);

	KeyDown(fn : (KeyEvent) -> void);
	KeyUp(fn : (KeyEvent) -> void);
		KeyEvent(utf : string, ctrl : bool, shift : bool, alt : bool, meta : bool, keycode : int);

(The real `EventHandler` type is a little different. See "Z-order" section below.)

Basically, this form allows you to register event listeners to the various kinds of events that
can happen. If you subscribe to the mouse click event, the coordinates of the mouse in the
`Interactive` form's coordinate system can be requested, along with a `bool`
indicating whether the mouse is inside that form itself, as the form of a MouseInfo structure.
You do that by calling the function you retrieve.

The `KeyDown` and `KeyUp` events provide the name of the key as a string, the status of the
shift, ctrl and alt keys, as well as the key-code as an integer. Notice that keyboard events
are not 100% reliable, and many keys can not be accurately captured on all platforms, such as
Flash on a Mac. Also, the keyboard codes might be reported as if the keyboard layout is English,
really making many key events useless for international usage. There is nothing we can do
about that.

This basic building block is enough to implement `Button`s and drag'n'drop elements using
functions that produce forms. More about that in a minute. But first, let's introduce

	TextInput(state : [TextInputState], listeners: [TextInputEvent], stateaccess : [StateAccess]);

This is a relatively complicated prototype, but this is because a text input box is very
configurable, and supports a wide range of properties and events. The first parameter, `state`,
defines the initial state of the text input using a bunch of properties:

	TextInputState ::= Content, Size, Selection, Focus, Multiline, Numeric, MaxChars;
	Content(content : string, style : [CharacterStyle]);
	Size(width : double, height : double);
	// To set the cursor at a given place, set both start and end to that spot
	Selection(start : int, end : int);
	Focus(focus : bool);
	Multiline(multiline: bool);
	Numeric(numeric : bool);
	MaxChars(n : int);

As a minimum, you need to include a `Size()` state. The next parameter, `listeners`, defines
which events you want to subscribe to:

	TextInputEvent ::= TextChange, FocusIn, FocusOut;
	TextChange(fn : (TextInputModel) -> flow);
	FocusIn(fn : () -> flow);
	FocusOut(fn : () -> flow);

The TextChange event will send a `TextInputModel` with lots of details about the state of the
text input when the user changes something in the text input. The definition is here:

	TextInputModel(content : string, cursorPosition: int, selection : Selection, focus : bool);

The final parameter in a text input, `stateaccess`, provides access to query the state of a
text input at any time, as well as the option to change the state of the text input at any time:

	StateAccess ::= StateChanger, StateQuery;
	StateChanger(state : Behaviour);
	StateQuery(reader : (() -> TextInputModel) -> void);

The `StateQuery` structure takes a function, which is called when rendering the text input.
This function is called with a function that allows you to read the state of the text input
at any point in time you need it. An example:

	// At first, we provide a dummy function
	stateQueryFn = ref \ -> TextInputModel("", 0, Selection(0,0), false);
	// When rendered, we capture the function to get the real state
	dispose = render(TextInput([...],[...],[StateQuery(\f -> stateQueryFn := f)]));

	...

	// And now, at any point, we can query the current state of the text input:
	getTextState = ^stateQueryFn;
	textModel = getTextState();

Luckily, there are simpler helpers to construct basic `TextInput`s meeting common needs. Have a
look in `gui.flow` and `ui/texteditors.flow` to find one that might suit you.


Functions that produce forms
----------------------------

As mentioned above, the architecture of form is based on building increasingly higher-level
forms which can be used to compose a user interface from big chunks of functionality. There
is a growing library of such forms. See `gui.flow` for more information, but some of the
simpler ones are:

	Lines([form]) -> Form;
	Cols([form]) -> Form;
	Fixed(width : double, height : double) -> Form;
	Border(left : double, top : double, right : double, bottom : double, form : Form) -> Form;
	Offset(x : double, y : double, form : Form) -> Form;

We also have a more or less complete set of widgets. Although `Material` is the recommended
toolkit, if you need custom designs, widgets in `Form` can be helpful. See the ui/ folder and 
you can find things like:

	CheckBox(caption: Form, value: DynamicBehaviour<bool>, size : double) -> Form;
	ComboBox(width : double, maxdropheight : double, items : [Form], selected : DynamicBehaviour<int>, wBorder: double, hBorder: double) -> Form;
	Slider(x : Behaviour, y : Behaviour, maxX : Behaviour, maxY : Behaviour, handle : Form) -> Form;

For the common case of the need of a button, see `EasyButton` which is very handy for the most
common cases. If you need a more fancy button, then have a look at `CustomButton` and `CustomFormButton`
in `buttons.flow`. Those are very configurable and flexible button functions, including full support for
508 accessibility. Never try to make your own button - it will be buggy, because it is surprisingly
hard.

Z-order
-------

In the interactive element above, we presented the MouseDown event like this:

	MouseDown(fn : (() -> MouseInfo) -> void);

In fact, the real definition is more complicated:

	MouseDown2 : (fn : (handled : bool, () -> MouseInfo) -> bool);

To support overlapping user interfaces, it is necessary to have a way to control z-order.
In `Form`, z-order is controlled by the `Group` Form. This means that the z-order generally
follows the visual display.

One thing to know is that when you use a `Grid` and then use `Translate` to move one cell on top
of another cell, the z-order does *not* increase. In this case, it is unpredictable what will
happen. To ensure correct z-order, you have to use `Group`.

The event dispatcher mechanism then sorts all event handlers registered to each event, and
sends the events from the top-level z-order down to the lowest one.
The `handled` bool starts out being `false`, and the idea is then that the first event which
"captures" the event returns `true`. In this way, the following event handlers further down
in z-order can see that the event has already been handled by someone else, so they can choose
to ignore it.

The typical pattern looks like this:

	Interactive([
			MouseDown2(\handled, mifn -> {
				if (!handled) {
					mi = mifn; // Get the mouse info
					if (mi.inside()) {
						println("We got it!");
						// Mark that we handle this event
						true;
					} else {
						// It is not inside us, so send the event to the next handler
						false;
					}
				} else {
					// Someone above us already handled it
					true;
				}
			}
		],
		form
	)

All of this is captured by the MouseClick helper:

	Interactive([
			MouseClick(\mi -> {
				println("We got it!");
			})
		],
		form
	)


When are behaviours not so great?
---------------------------------

Behaviours are an extremely useful abstraction, which naturally captures many patterns. However,
there are situations where behaviours are not the right choice. To understand when, let's look at
this function:

	example(data : DynamicBehaviour<double>) -> DynamicBehaviour<int> {

	}

From the prototype, we can see that this function takes some data of double type and returns some 
other data which is of int type. Since both arguments are dynamic behaviours, we promise that
both the result and the input can be changed by from outside. And we also promise that both
behaviours have a sane value at all times. So in other words, behaviours implicitly promise that
the value they model is always up to date. In some situations, such a promise can be hard to keep,
especially if multiple such bidirectional links are tied together, because that will quickly form
a loop, which might never terminate.

Another problem is that often, you can have hundreds of subscriptions to an important behaviour.
In this case, it will be a performance problem if that behaviour is updated a lot. That can cause
a lot of unnecessary work.

The final consideration is the memory overhead of behaviours. Although a behaviour itself is very
lightweight, the subscriptions and associated closures can often require extra memory, so that can
add up. As a special detail, it is worth noting that most transforms in fact are leaky: They do not
clean up properly. You have to use the transforms with the "u" suffix and keep track of the unsubscribers
to ensure memory is not leaked.

There is an alternative to behaviours in the form of Transforms. These are used in `Tropic`, and are
leak-free. Other than that, they share the same challenge of making a big promise that the values
will always be sane. See the documentation for Tropic to learn more about these.
