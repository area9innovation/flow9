Pebbles
-------

A pebble is a small stone, which you can drop to trace out a path, so you can find your
way back. This is a metaphor for the role they play in our system. In our setting, pebbles
are thus the address of each screen in the program. The home screen has one address, the
admin screen has another. A form for filling out details has a third. Each of these addresses
is called a pebble. As such, the pebbles serve as a similar role as Uniform Resource Locator
on the internet.

In addition to be able to record the pebbles for each screen, our pebbles are also magic
in the sense that you can pass a given pebble to a program, and it will bring up that
screen.

Pebble structure
----------------

A specific screen in a particular place in the program in ideal world should have their
own `Pebble` with specified parameters.

The goal of a pebble is to be able to exactly re-display the same screen with the
same object(s), but without storing the data of object itself. So if we have a screen of
a user with their address, we should NOT store the address of the user, but rather the ID
of the user, and then the program will retrieve the latest address from the database.

This is the structure of a pebble:

	Pebble(
		// The path to overall screen we are in. The first PathPart is the path to the first screen
		// from where we can get into the second one and so on.
		path : [PathPart]
	);

`Pebble.path` reflects the fact that most screens are implemented by nested Material constructs.
At the top level, you have the overall view, which presents a number of tabs. Each tab
itself might have some other hierarchical structure. This is reflected in the `Pebble.path`.

	PathPart(
		// name of the screen
		name : string,

		// Parameters: What overall object is displayed. This is a key/value map with ids of
		// objects and similar. Use IDs that are as stable as possible. Do NOT include
		// the data of the record itself.
		parameters : [KeyValue],
	);

A stack of pebbles is basically an array of these:

	PebbleStack(pebbles : [Pebble]);

And it is a history where you were. Thus, we have a central pebble stacking functionality,
which records what the current stack of pebbles is.

Pebble stack is not meant to be changed manually and is hidden inside of `PebbleController`
together with the rest of technical details. A controller is created once and is a single
per application. It's used to register pebble dispatchers for every screen, maintain stack and
global `Material` view.

This is done by having a function like this that we call whenever a screen is
displayed in a component, or some `parameters` were changed:

	setViewFromPebble : (
		// Global application controller that stores pebbles stack, dispatchers, technical details
		controller : PebbleController,
		// The location of this part of the UI as a pebble
		pebble : Pebble,
		// Should this entry go into the back/forward navigation history or not? I.e
		// should it appear in the browser history as part of a # url update?
		recordHistory : bool
	) -> void;

The main idea of pebbles is to have a possibility to recreate specific view from given `Pebble`.
To make it works you can implement your own mechanism or use mechanism implemented in `meta_app`,
which explained below. In other words, instead of changing global view yourself, call `setViewFromPebble`
and it will be changed based on the dispatcher registered for the pebble you passed it.

Meta-app and Pebbles
--------------------

`meta_app` is an proprietary tool for generating application with `Material` library.
Out of the box, `meta_app` supports constructing apps that follow the pebble protocol.
All generated screens (aka views) registered in the controller as dispatchers to some
concrete pebbles. All generated tabs and tables are wrapped with `MLinkPebbleParameters`
and support actions like switching tab, adding/deleting/editing table rows, filtering
and searching as pebble parameters.

Manual pebbling
---------------

However, for any other screens in your program, you have to use the above mechanism by hand.
Register every custom screen and corresponding pebble as a dispatcher in the controller
(see details in pebble_controller.flow). For meta_app based applications simply extend
`register<App-Name>ViewDispatchers` function in `<app-name>_view.flow`. In order to make
screen work with pebble parameters use `MLinkPebbleParameters` and link any parameter with
corresponding action.

This is required to get navigation, regression testing and the other benefits. If you do not need
those parts in specific parts of the program, you do not need to implement pebbles.

Navigation using pebbles
------------------------

The central pebble facility will maintain the global position of the current state of the program
as an array of `PathPart` with specific `parameters`, as well as a linear navigation
history in the form of an `PebbleStack`.

This allows us to implement back/forward functionality of the app in a general way. In `JS` each
`Pebble`, that was pushed in `PebbleStack` with `recordHistory == true` will modify
hash part of the browser URL and will be stored in browser history. Moving along the history by
back/forward buttons we will recreate `Pebble` from hash part of the URL and then recreate view
which is mapped with this very `Pebble`.

We can also map the Android and Windows Phone back-buttons to backwards navigation this way.

Given the paths in the pebbles, we can also implement a logical "up" operation: It works by doing
an "up" operation of the last `Pebble` in the `PebbleStack`. Up is done by going to the parent
pebble (by removing the last element of the `path` of the current `Pebble`). If that is
successful, then the new screen is defined by pushing new `Pebble` in `PebbleStack`. If that
fails you can act on your own (`onError` handler passed to controller will be called).

Adding new view
---------------

In case you need to introduce new independent view (a screen which is not a dialog, a pop-up or an extra tab) to the existing application you need to use `setViewFromPebble`. It takes a pebble as argument which consist of multiple path parts. String representation of a pebble will look like this:

	home&mode=study/project&projectId=17/component&componentId=54

`/` splits pebble into path parts, each corresponds to a separate screen. `home`, `project`, `component` are the names of the screens in the order of hierarchy: `project` can be opened from `home`, `component` from `project`. UP button will bring you to the parent screen, i.e. from `component` you will get to `project` and then to `home`.

So, if you need to open `cases` screen screen when on `component` the pebble will be changed to something like this:

	home&mode=study/project&projectId=17/component&componentId=54/cases&caseId=101

i.e. new screen is added in the end of the pebble. You can build it manually or use helpers like `extendCurrentPebbleWithPathPart` that will add your path part to the current pebble. All together it can look like this (last argument of the function means that you want to change URL when opening new screen):

	setViewFromPebble(controller, extendCurrentPebbleWithPathPart(controller, PathPart("cases", [KeyValue("caseId", "101")])), true);

Now, in order `setViewFromPebble` to work and to make direct URL (like `flowjs.html?name=app#home&mode=study/project&projectId=17/component&componentId=54/cases&caseId=101`) open your screen you need to register it in the global controller (`PebbleController`) using `registerDispatcher`. It takes mask of the pebble as argument, i.e. pebble without parameters (parameters define concrete look of each screen, not hierarchy of the screens, so in `registerDispatcher` parameters don't matter). In our example you will need to call

	registerDispatcher(controller, "home/project/component/cases", \-> buildCasesView())

As you can see you are registering not only the screen, but the order in which it will be opened. If the screen can be opened from multiple places, you need to register dispatchers for all of them (e.g. `"home/cases"`).

Usually all dispatchers are being registered together when application loads and it's a common practice to pass `state` as an argument using closure:

	registerAppViewDispatchers(state : AppState) -> void {
		registerDispatcher(controller, "home/project/component/cases", \-> buildCasesView(state))
		...
	}

Now we need to take care of screen parameters. If it's simply parameters that look or behaviour of the screen depend on you can just pass them to `setViewFromPebble` as we did it above (`caseId=101`) and then read them inside of `buildCasesView` using helpers like `getCurrentPebbleLastParameter` ("last" means that parameter will be taken from the last path part, which is usually what you need). If parameter corresponds to some DB entity, it might be handy to use `buildPebbleParameterBasedView` helper.

If you need dynamic parameters, i.e. parameter that will change depending on user actions (for example button click), or parameter that will correspond to dialog on your screen being shown, use `MLinkPebbleParameters`. There you need to specify parameter name, `DynamicBehaviour` that you can change in order to change parameter value and a callback that will be triggered every time parameter value is changed. To simplify things you can choose parameter type (positive integer, boolean, string) to avoid manual conversions. Also you can define what should happen with pebble when parameter is being changed (`PebbleAction`): do you want URL to be updated, do you want to store parameter changes in the history, etc.

There are some helpers that you can use depending on what purpose of the dynamic parameter you are introducing. For buttons use `MPebbleIconButton`/`MPebbleTextButton`, for tabs use `buildPebbledTabs` and friends, for dialogs show use `makePebbleStringEditDialogTrigger`,

Note, usually you want to use ID or some key of the DB entity as parameter, not the value itself. The idea is that you should be able to send URL to another user and she will see exactly the same screen as you. This also means that the set of parameters should be exhaustive in order to load everything what is needed from the DB when user opens direct link and the code of `buildCasesView` should be able to load everything required from scratch if direct link is used. For example if one of the parent views loads some data that will be used in the child view, you need to make sure to load this data in the child view as well in case child view was opened directly:

	registerDispatcher(controller, "home/project", \-> buildProjectView(state))
	...
	registerDispatcher(controller, "home/project/component/cases", \-> buildCasesView(state))

	buildProjectView(state) -> Material {
		loadExtraState(\extraState -> {
			next(state.extraStateB, Some(extraState));
			...
		})
	}
	buildCasesView(state) -> Material {
		if (isNone(getValue(state.extraStateB))) {
			loadExtraState(\extraState -> {
				next(state.extraStateB, Some(extraState));
				buildCasesView2(state);
			}
		} else {
			buildCasesView2(state);
		}
	}
	buildCasesView2(state) -> Material {
		...
	}

Helpers
-------

- `MLinkPebbleParameters`: allows to link screen behaviour with the value of the given pebble parameter.
For example every time dialog appears on the screen "&mydialog=true" will be added to the URL
and vice versa, adding "&mydialog=true" to the URL will cause opening of the dialog.

- `MConfirmPebbleParameterSwitch`: allows to confirm value change of the given pebble parameter.
For example can be used to show "save changes" dialog when user is about to leave the screen.

- `PebbleTab`: allows to link tabs in the UI with pebble parameter. For example "&t=5" parameter
will correspond to fifth tab on the screen. Switching the tab in the UI will cause parameter change
and vice versa, changing parameter will switch the tab.

Debugging
---------

Use "&debug_pebbles=true" to see pebbles logs in the console

Example
-------

	import pebbles/pebble_controller;
	import pebbles/pebble_parameters;
	import material/material2tropic;

	main () {
		mManager = makeMaterialManager([]);
		controller = makePebbleController(println);
		mrender(mManager, true, getPebblesControlledView(controller));

		registerDispatcher(controller, "home", \-> showView(controller));

		validateCurrentPebbleAndInitView(controller, mManager, makeSimplePebble("home"));
	}

	showView(controller) -> Material {
		valueB = make(0);

		MLinkPebbleParameters(
			controller,
			[
				PebbleIntLink(
					"param",
					valueB,
					\value -> println("value = " + i2s(value)),
					RecordURLChange()
				)
			],
			MLines([
				MTextButton("Click me to change parameter", \-> {
					next(valueB, getValue(valueB) + 1)
				}, [], []),
				MSelect(valueB, \value -> {
					MText("Value is " + i2s(value), [])
				})
			])
		)
	}

Under the hood
--------------

In this section we describe the rules we want to follow in the pebbles library. Existing code may differ from these rules, we must adjust such code.

Pebbles involve 4 types of behavior:
1. URL (addUrlHashListener, setUrlHash)
2. Current pebble (PebbleController.currentPebbleB)
3. Pebble stack (PebbleController.pebbleStackB, it is an internal behavior)
4. Pebble parameters (PebbleParameterLink.valueB, PebbleParameterLink.valueT)

Event map is:
- A.  URL -> Current pebble
- B.  Current pebble -> Pebble stack
- C.  Current pebble -> Pebble parameters
- D.  Pebble parameters -> URL

Event A can be cancelled with PebbleController.confirmations (see confirmPebbleSwitch function),
if it is canceled, then a new event A occurred with the previous pebble.
