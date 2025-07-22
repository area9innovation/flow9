# FRP async library

 The library to support Frp nodes graphs, that can work in async manner.

```
FrpAsyncStatus ::=  FrpAsyncReady, FrpAsyncInProgress, FrpAsyncError;
FrpAsyncReady(); FrpAsyncInProgress(); FrpAsyncError(e : [string]);
FrpAsyncNode<?> ::= FrpAsyncValue<?>, FrpAsyncArray<?>;

FrpAsyncValue(
	frpNode : FrpValue<?>,
	asyncStatus : FrpValue<FrpAsyncStatus>,
);

FrpAsyncArray(
	frpNode : FrpArray<?>,
	asyncStatus : FrpValue<FrpAsyncStatus>,
);
```

The basic struct is a FrpAsyncNode struct, consists of FrpAsyncValue (or FrpArray) as node value and
`asyncStatus : FrpValue<FrpAsyncStatus>` field.

The lib provide functions to build a complex graph from `FrpAsyncNode` structs.

## Basic idea

We have a graph consists of `FrpAsyncNode`  connected to each other, one `dst` node can be connected to one or more `src` nodes.

1) if any source node get `FrpAsyncError` then `dst` node get `FrpAsyncError` status also
2) else if any source node get FrpAsyncInProgress status then  `dst` node get FrpAsyncInProgress status also
3) `dst` node get `FrpAsyncReady` value only if all sources have `FrpAsyncReady` value.

Both fields of `FrpAsyncNode` can be used for creating UI views separately: `frpNode` - to creating main view content that will be updated seamlessly,
and asyncStatus field can be used to show a progress dialog if need.

## Update process

Update process contains 2 steps:
1) set `FrpAsyncInProgress` status for a node, that will be propagated immediately through whole graph.
As a result, all dependent nodes receive the same status, but their values do not change.
2) set a value to the node and status value `FrpAsyncReady`, the value will be  propagated through whole graph
and all dependent nodes get new values and status `FrpAsyncReady`.

2-step update method allow us do select from 2 or more async nodes and avoid glitches, extra calculation and unnecessary data loading.
This because a dependent node (dst) will be updated only when all his src nodes are updated already.

### Async update

```
node = makeFrpAsyncValue(10);

onButtonClick = \-> {
	rAsyncSetInProgress(node);

	loadDataFromDB(
		...,
		\data -> rAsyncSetValue(node, data), // on OK callback
		\err -> rAsyncSetError(node, err) // on error callback
	);
}
```

### Sync update

`rAsyncNext(node : FrpAsyncValue<?>, value : ?) -> void;`

can be used to update node in sync manner, it set `FrpAsyncInProgress` status and immediately set a new value with `FrpAsyncReady` status.

Set functions as `rAsyncSetValue, rAsyncSetError, rAsyncSetInProgress, rAsyncNext` must be used mostly on fringe of a frp-graph,
to connect its leafs to other code like button click handlers and `DynamicBehaviours`.

## Creating a graph

### rAsyncConnect, rAsyncConnect2 ...

They guys are used to connect one or more `src` nodes to a **existed** `dst` node with help a sync pure function `fn`.

For example
```
rAsyncConnect(
	src : FrpAsyncValue<?>,
	dst : FrpAsyncValue<??>,
	init : bool,
	fn : (?) -> ??,
	errorFn : ([string]) -> [string],
) -> void;
```
connect src node to dst node, dst node

```
node1 =  makeFrpAsyncValue(10);
unsubscriber = rAsyncConnect(node1, node2, true, \v -> v * 2, idfn);
```

A `init` parameter force run fn when `rAsyncConnect` called to **initialize** dst value.

`errorFn` collects `src` errors to create a result error in `dst` node.
Errors will be ignored if it returns [].

### frpAsyncSelect, frpAsyncSelect2 ...

```
rAsyncSelect(
	src : FrpAsyncValue<?>,
	fn : (?) -> ??,
	errorFn : ([string]) -> [string]
) -> FrpAsyncValue<??>;
```
create a new node and connect to it sources

## Connect nodes using async functions

`rAsyncFnConnect, rAsyncFnConnect2` ...

It is most powerful tool to creating a FRP async graph.

```
rAsyncFnConnect(
		src : FrpAsyncValue<?>,
		dst : FrpAsyncValue<??>,
		init : bool,
		bufferPolicy : FrpAsyncBufferPolicy,
		asyncFn : (?, ??/*currentValue*/, (??) -> void /*onDone*/, (string) -> void /*onError*/) -> void,
		errorFn : ([string]) -> [string],
	) -> void;
```
basically it's similar to `rAsyncConnect` but with some major differences:

1. `asyncFn` works asynchronously, it is called when all sources get `FrpAsyncReady` status,
and calls `onDone` to return a value, or calls `onError` on an error.
2. before `asyncFn` will done the work, it can't be called again
3. if `bufferPolicy` argument is passed, the  events that happen while the function is still running will be buffered and handled later
4. `asyncFn` get a `currentValue` argument, that allow to create fold-like async nodes, that can accumulate value.

Thus, it allows you to build complex components that load data from DB and interact asynchronously.

```
idNode =  makeFrpAsyncValue(10);
dataNode =  makeFrpAsyncValue([]);

rAsyncFnConnect(idNode, dataNode, FrpAsyncBufferNone(), true,
	\id, currentData, onDone, onError -> {
		loadAnArrayFromDb(id, ... ,
			\data -> onDone(concat(currentData, data)), // accumulate data
			\err -> onError(err),
		);
	},
	idfn, //collect src errors fn
);

```
## disconnect

```
rAsyncDisconnect(node : FrpAsyncNode<?>) -> void;
```

## Subscribers

`rAsyncSubscribe, rAsyncSubscribe2 ...`

 are mainly intended to connect Frp async graph to outer world, to updating `DynamicBehaviours` to render a UI for example.

```
	rAsyncSubscribe(
		cell : FrpAsyncValue<?>,
		init : bool,
		fn : (?, FrpAsyncStatus) -> void,
	) -> () -> void;
```

`init` argument force run `fn` on call `rAsyncSubscribe`

## Usage cases

### Case 1: engine with async state

```
AState(...); // struct to represent a internal component's state
AData(...); // struct to represent a component's output data

makeEngine(
	src1 : FrpAsyncValue<...>,
	src2 : FrpAsyncValue<...>
) -> FrpAsyncValue<AData>{

	engineState = makeFrpAsyncValue(AState(...));

	rAsyncFnConnect2(src1, src2, engineState, FrpAsyncBufferFirst(10), true,
		\v1, v2, currentState, onDone, onError -> {
			loadSomethingFromDb(v1, v2, ... ,
				\data -> onDone(AState(...)), // create a new state value from data
				\err -> onError(err),
			);
		},
		idfn, //collect src errors fn
	);

	makeOutputFn = \state : AState -> AData(...);
	// make a new output value from the state

	outputErrorFn = \erros : [string] -> ["something went wrong"];
	// returns a simple error message, real errors are dropped

	rAsyncSelect(state, makeOutputFn, outputErrorFn); // returns an output cell
}

```

We create here an async state, that contains value of a complex `AState` type.
A new `engineState` value is computed  from `currentState` value and a new data loaded from DB.
The data loading process starts when any of `src1` or `src2` is changed and both have got status `FrpAsyncReady`.
The  `v1`, `v2`, `currentState` callback's parameters can be used to run the loading process and to calculate a new `engineState` value.

If one of the sources has a  `FrpAsyncError` status, then the `engineState` also gets this status (that contains all errors collected from its sources).
If one of the sources has a  `FrpAsyncInProgress` status, then the `engineState` also gets this status.


The `AState` struct can consist of many internal fields, necessary only for the functioning of the engine itself, like a initial data that loaded on creating engine only, maybe an init flag, that show engine ready to work, maybe some caches and so on.

To convert the complex `engineState` value into externally visible output value of `AData` type, we create yet another cell using  `rAsyncSelect`.
The `makeOutputFn` function is responsible for this transformation, and `outputErrorFn` transforms and pass errors from `engineState` to output.
Thus, `FrpAsyncInProgress` and `FrpAsyncError` statuses is translated also to output with transformation or not.

Because `src1` and `scr2` are async nodes also, they can change their values before the previous loading operation and updating `engineState` will be completed. To solve this problem, we use a buffer delayed updates, here is arbitrary set into `FrpAsyncBufferFirst(10)`.

The updates buffer help us resolve an async initialization problem.
This engine initialization process starts by calling `rAsyncFnConnect2` here, if `src1` or `scr2` changes occur before it is completed, then they will be buffered as delayed updates.

### Case 2: engine with only-once initialized state

```
AState(...); // struct to represent a internal component's state
AData(...); // struct to represent a component's output data

makeEngine(
	src1 : FrpAsyncValue<...>,
	src2 : FrpAsyncValue<...>
) -> FrpAsyncValue<AData>{

	engineState = makeFrpAsyncValue(AState(...));
	rAsyncSetInProgress(engineState);

	loadDataFromDB(
		...,
		\data -> rAsyncSetValue(engineState, data), // on OK callback
		\err -> rAsyncSetError(engineState, err) // on error callback
	);

	makeOutputFn = \v1, v2, state : AState -> AData(...);
	// make a new output value from the state and sources

	outputErrorFn = \erros : [string] -> ["something went wrong"];
	// returns a simple error message, real errors are dropped

	rAsyncSelect3(src1, src2, state, makeOutputFn, outputErrorFn); // returns an output cell
}
```
In this example engine output depends on `src1`, `src2` and `engineState`, but `engineState` initialized only once and does not depend on  any sources.
Until the state is fully initialized, output cell has `FrpAsyncInProgress` status.
