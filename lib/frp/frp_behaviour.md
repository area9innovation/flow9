# Main purpose

Main purpose of the lib is allow to create an UI engine, that works without glitches and in effective manner.

Such an engine should have the following properties:
1. to work without any glitches (its output must get only correct values)
2. to compute a new value in effective direct manner (avoid extra computations which result will be dropped)
3. to work in background regardless rendered an UI that uses it or not (because its data can be can be used in several views at the same time)
4. to allow connected/disconnected different UI implementations at any time (to more easy support mobile/tablet/desktop UI versions and variants of UI)
5. to allow to easy connect to Material controls
6. to allow to create a more complex engine from simple engines (a way to compose it)

Main idea is creating an separated from UI engine using a Frp-cell to keep a state of an UI view, and connect the cell to `Material` using `DynamicBehaviours`.
Frp-cell would be responsible to keep an always consistent state value, but `DynamicBehaviours` would be used only to connect the state with UI.


# API

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

# An example

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

makeAViewState(...) -> AViewEngine {
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

	AViewEngineUIConnectors(outputCell, textB, flagB, resetFn);
}
```

In this example we create a cell (`stateCell`) to keep a state value and derive from it an output cell, that contains a more simple calculated value that must be visible outside.
The `stateCell` is encapsulated private variable, that can contain a specific fields necessary only for correct update of state.
We also create here an interface to connect engine to `MTextInput`, `MSwitchControl` and a `MTextButton` (or some others suitable to replace).

This is just a template, many of these elements may be missing or some others may be present.
