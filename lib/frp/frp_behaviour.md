# Main purpose

Main idea is keep a state of a view inside a Frp-node, and connect it to `Material` using `DynamicBehaviours`.

Frp-node would be responsible to keep an always state **consistent** value, computation new state values in effective manner, but `DynamicBehaviours` would be used only to connect the state with UI.


# Example 1

```
AViewState(...);

AViewOutput(...);

AViewEngine(
	outNode : FrpValue<AViewOutput>,
	textB : DynamicBehaviour<string>,
	flagB : DynamicBehaviour<bool>,
	resetFn : () -> void, // maybe call it on button click
	...
);

makeAViewState() -> AViewEngine {
	stateNode = rmake(AViewState());
	textB = make("");
	switchB = make(false);

	rbConnectStar2(stateNode, textB, switchB,
		\currentState,text,flag -> {...},
		\currentState -> {...}, // to text value
		\currentState -> {...} // to switch value
	);

	resetFn = \-> rnext(stateNode, ...);
	outputNode = rselect(stateNode, \stateV -> {...}); // AViewState -> AViewOutput

	AViewEngineUIConnectors(outputNode, textB, flagB);
}
```
