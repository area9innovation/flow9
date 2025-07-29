# frp_behaviour library

## Main purpose

Main purpose of the lib is provide a helpers to to create an UI engine, that works without glitches and in effective manner.

Such an engine should have the following properties:
1. to work without any glitches (its output must get only correct values)
2. to compute a new value in effective direct manner (avoid extra computations which result will be dropped)
3. to work in background regardless rendered an UI that uses it or not (because its data can be can be used in several views at the same time)
4. to allow connected/disconnected different UI implementations at any time (to more easy support mobile/tablet/desktop UI versions and variants of UI)
5. to allow to easy connect to Material controls
6. to allow to create a more complex engine from simple engines (a way to compose it)

Main idea is creating an separated from UI engine using a Frp-cell to keep a state of an UI view, and connect the cell to `Material` using `DynamicBehaviours`.
Frp-cell would be responsible to keep an always consistent state value, but `DynamicBehaviours` would be used only to connect the state with UI.


## API

The lib provides functions that allow to connect a Frp-cell to one or more behaviours and works in bidi- manner.
That means changes are propagated only in one direction: from a Frp-cell to the behaviour or from the behaviour to the Frp-cell.
If a change propagation started from a behaviour, it leads in first hand to update Frp-cell using the cellFn and then to update others behaviours using a corresponded `behFn`.

```
rbBidiConnect(
	cell : FrpValue<?>,
	beh : DynamicBehaviour<??>,
	cellFn : (?, ??) -> ?,
	behFn : (?) -> ??,
) -> void;

rbConnectStar2(
	cell : FrpValue<?>,
	beh1 : DynamicBehaviour<??>,
	beh2 : DynamicBehaviour<???>,
	cellFn : (?, ??, ???) -> ?,
	behFn1 : (?) -> ??,
	behFn2 : (?) -> ???,
) -> void;

```
The `rbBidiConnect` function allows to create ordinary bidi-link between Frp-cell and  `DynamicBehaviour`.

`rbConnectStar2`, `rbConnectStar3` and family are more interested, they provide a way to make a star-like construct, where Frp-cell can be considered as star-body and will contains a always consistent state value, and behaviours, that can be considered as star-beams, provide a way to update state value from UI.

The `cellFn` take a current cell value as first argument, thus  we can create a complex behavior like accumulation data and changing logic on some event (after initialization for example).

## Disconnector

When we create a connections between `FrpValue` cell and one or more `DynamicBehaviour`s, a disconnector-fn saved inside `FrpValue` cell. Call `rdisconnect` for it to remove any subscribers from both `DynamicBehaviour`s and `FrpValue` cell.

## Example 1

```
AViewState(...); // struct to keep an encapsulated state value

AViewOutput(...); // provides a value that will be used in a view and to creating more complex engines also

AViewEngine(// an interface to get and update the viewe state
	out : FrpValue<AViewOutput>,
	textB : DynamicBehaviour<string>, // to use with MTextButton and so on
	flagB : DynamicBehaviour<bool>, // to use with MSwitchControl and so on
	resetFn : () -> void, // maybe call it on button click
	...
);

makeAViewEngine(...) -> AViewEngine {
	stateCell = rmake(AViewState(...));
	textB = make("");
	flagB = make(false);

	rbConnectStar2(stateCell, textB, flagB,
		\currentState,text,flag -> {...},
		\currentState -> {...}, // to text value
		\currentState -> {...} // to switch value
	);

	resetFn = \-> rnext(stateCell, ...);
	outputCell = rselect(stateCell, \v -> {...}); // AViewState -> AViewOutput

	AViewEngine(outputCell, textB, flagB, resetFn);
}
```

In this example we create a cell (`stateCell`) to keep a state value and derive from it an output cell, that contains a more simple calculated value that must be visible outside.
The `stateCell` is encapsulated private variable, that can contain a specific fields necessary only for correct update of state.
We also create here an interface to connect engine to `MTextInput`, `MSwitchControl` and a `MTextButton` (or some others suitable to replace).

This is just a template, many of these elements may be missing or some others may be present.


## Example 2

```
AViewState(...);
AViewOutput(...);

AViewEngine(
	out : FrpValue<AViewOutput>,
	userSelectedIdB : DynamicBehaviour<int>,
);

makeAViewEngine(pebbleIdB : DynamicBehaviour<int>) -> AViewEngine {
	userSelectedIdB = make(-1);
	idCell = rmake(-1);

	// (1)
	rbConnectStar2(idCell, pebbleIdB, userSelectedIdB,
		\__,pebbleId,userSelectedId -> {if (userSelectedId > 0) userSelectedId else pebbleId},
		\id -> id, // to pebble id
		\id -> id // to user selector
	);

	// (2)
	stateCell = FrpAsyncValue(AViewState(...));

	// (3)
	asyncUpdateFn = \id, __, onDone, onError -> {
		loadADataFromDb(id, ...,
			\data -> {
				onDone(AViewState(...));
			},
			\err : string -> {
				onError(err);
			}
		);
	}

	// (4)
	rAsyncFnConnect(
		wrapFrpAsyncValue(idValueCell), // FrpValue -> FrpAsyncValue
		stateCell,
		false,
		FrpAsyncBufferNone(),
		asyncUpdateFn, // run on any src value change
		idfn, //collect error fn
	);

	// (5)
	outputCell = rselect(stateCell, \v -> AViewOutput(...));

	// (6)
	AViewEngine(outputCell, userSelectedIdB);
}
//...
// use it

// (7)
buildAViewDesktop(engine : AViewEngine) -> Material {
	// do something suitable for desktop
	MColsA([
		MDropDown(engine.userSelectedIdB, "", items, []),
		MSelect(rbSelectB(engine.out).first, \data -> ...)
	]);
}
buildAViewMobile(engine : AViewEngine) -> Material {
	// do something suitable for mobile
	MLinesA([
		MDropDown(engine.userSelectedIdB, "", items, []),
		MSelect(rbSelectB(engine.out).first, \data -> ...)
	]);
}

// (8)
showADialog() -> void {
	pebbleIdB = make(-1);
	engine = makeAViewEngine(pebbleIdB);

	view = if (mobile) buildAViewMobile(engine) else buildAViewDesktop(engine);
	...
	ShowMDialog(
		...,
		MLinkPebbleParameters(
			pebbleController,
			[
				PebbleIntLink(..., pebbleIdB, ...)
				...
			],
			view
		)
	);
}

```
In this example, we create a view engine that combines 2 input data streams representing an object identifier is used to load data from the server.

1. 2 input streams are merged using `rbConnectStar2` with a fn that allow resolve any possible conflicts (1), `idCell` keep a always correct current object id
2. created an async state (2) using `rAsyncFnConnect` that use  `idCell` as input and load a relevant data from a server on any `idCell` change
3. created a converter from a complex private state value into a more simple value inside `outputCell` that must be used from outside (5)
4.  `outputCell` and any additional `DynamicBehaviour`s (and maybe `onClick` functions) packed in one engine struct (6)
5. created 2 different views that both works with the engine (7), and can be used in a dialog (8) depending on a `mobile` flag

Note:
1. the engine still works even if no view is rendered, it always keep a correct value
2. the engine code is completely separated from view code, this allow to support easy many different views for one engine
3. the `FrpNode` struct and frp-operation used to create a reliable state engine, while `DynamicBehaviour`s are just used to connect the engine to an UI
4. an engine can work in sync or async manner
