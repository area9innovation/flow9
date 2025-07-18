# A Purpose

The main goal is to provide a way to gradually build up a complex state management engine for rendering UI by adding and subscribing new nodes to a graph.

To isolate a mutable state inside a Frp lib and describe nodes connections using pure functions.

# A Problem

A changes propagation systems typically updated in step-by-step manner (node by node), and as a result,
before reaching a final steady state it goes through a series of intermediate states.

If a graph is built by using something like select2, select3 and so operations, that describe dependency a node from other 2 and more nodes, it can lead sometimes to inconsistent states of nodes and extra computations, include memory allocations and server requests.

For example, we have a graph that built from A,B,C,D nodes, where B and C dependent on A, and D node in turn dependent on B and C (used select2).
When we update A node it lead to update B and D, and then to update C and D again. Thus we get a glitch on D node -  wrong intermediate state, and have an extra calculation of node D value, which will be immediately discarded.

Such extra calculation can include memory allocations and server requests also and lead to completely wrong graph state.

To avoid this, we need a way to calculate the new node value only after all node's sources have been updated.

# A Solution

This Frp solution based on using 2-pass updating of the Frp-graph: in first pass all dependent nodes are marked as to be updated (outdated status value), in the second pass new values ​​are calculated for each node, and then the node are marked as updated.

The key point is that a new value is assigned to a node when all its sources have already been updated.
Thus select2, select3 and so on operations work without glitches and extra computation.

To make this solution work correctly with cycles in the graph and avoid unnecessary computations, a "distinct update" method is used, which means that propagation stops if the new value of a node is equal to the old value of the node.

# Basic types
```
	FrpCell<?> ::= FrpConst<?>, FrpValue<?>;
	FrpNode<?> ::= FrpCell<?>, FrpArray<?>;

	FrpConst(value : ?);

	FrpValue(
		value : ref ?,
		status : ref bool,
		subscribers : DList<(FrpEventType) -> void>,
		disposers : ref List<() -> void>
	);

	FrpArray(
		values : ref [ref ?],
		status : ref bool,
		subscribers : DList<(FrpEventType) -> void>,
		disposers : ref List<() -> void>
	);
```
Basic and common purpose type is `FrpValue`.

A `FrpValue` node also can contain an array value, but to reduce memory allocation on arrays operations, also added a special type - `FrpArray`, its values type is `ref [ref ?]`, that allow do some optimizations.
The disadvantage of using `FrpArray` is less flexibility and it has support for a smaller set of operations.

# Constructors

```
rconst(v : ?) -> FrpConst<?>;
rmake(v : ?) -> FrpValue<?>;
rmakeA(elements : [?]) -> FrpArray<?>;
```
# Update node value

```
rnext(cell : FrpValue<?>, value : ?) -> void;
```
There is also setters to batch update several nodes - rnext2, rnext3 ... rnextMany
Because they first of all mark all dependent nodes as outdated (will be updated),
whole batch update will done without glitches.

setters for FrpArray nodes:
```
rnextA(cell : FrpArray<?>, values : [?]) -> void;
rnextElement(cell : FrpArray<?>, index : int, value : ?) -> void;
```

rnextElement is optimized setter to update one element in array

# Creating graph

use rselect family to create new nodes for the graph
```
rselect(
	src : FrpCell<?>,
	fn : (?) -> ??
) -> FrpValue<??>;
```
and there is versions for 2 and more sources.

There is also a separated set of operations for FrpArray:
```
rselectA(
	src : FrpArray<?>,
	fn : ([?]) -> ??
) -> FrpValue<??>;

rselectARange(
	src : FrpArray<?>,
	start : int,
	count : int,
	fn : ([?]) -> ??
) -> FrpValue<??>;

rselectARangeMap(
	src : FrpArray<?>,
	start : int,
	count : int,
	fn : (?) -> ??
) -> FrpArray<??>;

rselectARangeDynamic(
	src : FrpArray<?>,
	start : FrpCell<int>,
	count : FrpCell<int>,
	fn : ([?]) -> ??
) -> FrpValue<??>;

rselectARangeMapDynamic(
	src : FrpArray<?>,
	start : FrpCell<int>,
	count : FrpCell<int>,
	fn : (?) -> ??
) -> FrpArray<??>;

rselectAZip(
	src1 : FrpArray<?>,
	src2 : FrpArray<??>,
	fn : (?, ??) -> ???
) -> FrpArray<???>;
```

# Disconnect node from sources

```
rdisconnect(cell : FrpNode<flow>) -> void;
```
Call it to remove connection a node to its sources but not break connections to dependent nodes.
It must be called when the node is no longer needed, otherwise the subscriptions inside will prevent its sources from being garbage collected, which obviously leads to memory leaks.

# rconnect and graph with loops

The rselect family in essence is helpers for rconnect family, to easy create and connect a derivative node.

```
rconnect(
	src : FrpCell<?>,
	dst : FrpValue<??>,
	init : bool,
	fn : (?) -> ??,
) -> void;
```
There is a set operations for more then one source also.

In most cases creation Frp-graph using rselect family is more convenient then using `rconnect` directly.
But rconnect can help with some specific tasks, as creating loop in a graph, for example:

```
node1 = rmake(...);
node2 = rselect(node1, v-> {...});
node3 = rmake(...);
rconnect(node2, node3, true, )
```

# rconnectX functions family

use `rconnect2`, `rconnect3` ... to connect a node to 2 or more sources

```
node1 = rmake(...);
node2 = rmake(...);
node3 = rmake(...);
rconnect2(node1, node2, node3, \v1,v2 -> {...});
```
or use `rselect2`, `rselect3`... to create a node dependent on 2 or more sources more easy:
```
node1 = rmake(...);
node2 = rmake(...);
node3 = rselect2(node1, node2, \v1,v2 -> {...});
```

Two separated connectors to 2 different sources works as alternative update paths (this may be useful in rare cases, use at your own risk):
```
node1 = rmake(...);
node2 = rmake(...);
node3 = rmake(...);
rconnect(node1, node3, \v -> {...});
rconnect(node2, node3, \v -> {...});
```

# rsubscribeX family

use `rsubscribe`, `rsubscribe2` ... to output a data from the frp-network mainly, and use `rselect` or `rconnect` to create frp-graph:
```
node1 = rmake(...);
bhv = make(...);
uns = rsubscribe(node1, true, \v -> nextDistinct(bhv, ...));

```
`rsubscribe` doesn't propagate status events (to mark nodes as outdated and updated), thus it can't replace `rconnect`.

```
node1 = rmake(...);
node2 = rmake(...);
uns = rsubscribe(node1, true, \v -> rnext(node2, ...));
```
it will work if we will not merge sources from sub-net of node1 and sub-net of node2,
otherwise we will get glitches:

```
node3 = rselect2(node1, node2, \v1,v2 -> {...});
```
node3 can get wrong value immediately after you set a new value for node1 and then again will be re-computed on update a node2.
The final value will be correct, but the intermediate one is a glitch.

# Bidirectional connections

A bidirectional connection between two nodes can be created using

```
rBidiConnect(
	cell1 : FrpValue<?>,
	cell2 : FrpValue<??>,
	init : bool,
	fn1 : (?) -> ??,
	fn2 : (??) -> ?
) -> void;

rBidiSelect(
	cell : FrpValue<?>,
	fn1 : (?) -> ??,
	fn2 : (??) -> ?
) -> FrpValue<??>;
```

rBidiSelect is just syntax sugar to create a new node with bidi-connection to an original.
Then we can connect a bidi-nodes pair to one or many other nodes using `rconnect`,`rconnect2`.. functions family.

```
bidi1 = rmake(...);
bidi2 = rBidiSelect(cell1, \v-> ..., \v-> ...);

rconnect3(cell1, cell2, cell3, bidi1, false, \v1,v2,v3 -> ...);
rconnect2(cell4, cell5, bidi2, false, \v1,v2 -> ...);

```
Here `cell1`, `cell2`, `cell3`  work as sources for `bidi1` node, and `cell4`, `cell5`  work as sources for bidi2.
You can also connect other nodes to get data from bidi-nodes using normal `rconnect` or `rselect` functions. 
