Frequently Asked Questions
==========================


Flow language
-------------

#### Why use flow in the first place? Why not HTML5?

Primary reasons: HTML5 still performs bad on some mobile devices. HTML+CSS+JavaScript is 10 times
more verbose than flow. Thus productivity is better for the kind of programs flow is designed for.

Historical background: Flow was designed at a point in time when HTML5 did not exist, and you
had to use Flash to decent performance in browsers. Nothing existed that could target Flash,
as well as iOS and Android. We tried to get haxe to work for a long time, but it turned out to
be too hard. In the end, we were forced to make a solution ourselves, and the result is flow.

Since then, flow has turned out to be the best possible defense we have against changing
technologies. With flow, we can relatively quickly add new targets as the technology
landscape changes. Examples include migrating from Flash as the main platform to HTML5.
Migrating from a DOM-based rendering backend to a Pixi-based rendering backend in HTML5.

Similarly, we have added our own JIT for desktop execution, and even a Windows Mobile
target (which has been allowed to bitrot as that platform has died). This is proof that 
software written in flow can made to work well on new platforms as they come, and get the 
benefits of those without having to rewrite all the code in flow.

#### What about WebAssembly?

We do have an alpha-stage backend in `tools/flowc/backens/wasm` and it can run a lot of
code. However, our benchmarks show that WebAssembly is currently around 5 times slower 
than JS, even on integer-only code. So work has paused on this until browsers are able 
to run WebAssembly at least as fast as JS.

#### Why can I not `switch` on ints or strings?

The reasoning is that the code is more clear using structs in almost all cases,
so we do not mind having to use a series of if-statements in the few cases where 
that is useful.

#### When should I use `default` in switches? ####

In general, we recommend NOT using `default` in switches, since that turns off completeness
checking in the type checker. Instead, the convention is to include all structs in the union
you are switching on, even if this means very repetitive code. In short, instead of

	switch (foo) {
		Special(): ...do whatever...;
		default: ...common path...;
	}

we prefer:

	def = \ -> ...common path...;
	switch (foo) {
		Special(): ...do whatever...;
		Unused1(): def();
		Unused2(): def();
		Unused3(): def();
		Unused4(): def();
		...
		Unused25(): def();
	}

or

	Unused ::= Unused1, Unused2, ..., Unused25;
	switch (foo) {
		Special(): ...do whatever...;
		Unused(): ...common path...;
	}

The reason is that when we add `Whatever26`, then we get a compile error, and actively have to
consider whether the common path is correct in that case as well.

#### Why is there no support for recursive local functions, or lambdas? ####

This is a known limitation, but experience has shown that top-level function most often are
more clear anyways. This is because each function becomes relatively limited in length when
all the "nested" lambdas are forced outside, which is good for overview and maintenance.

#### Why are there no exceptions in flow? ####

These are very common in all languages, but are surprisingly difficult to implement without
a performance penalty or advanced optimizations, so we elected to try to avoid exceptions
completely instead. Two constructs can cause a crash: array out of bounds, and working on
dynamic data with type errors.

Using practices such as passing default values in calls help mitigate the downsides of
lack of exceptions. See `lookupTreeDef` as an example. The use of `Maybe` returns can also
work, but those very often lead to verbose code that is often slower than using the
default-as-parameter approach.

#### Why not monads?

Monads are complicated, and require very sophisticated optimizations to run fast.
There was an experiment using monadic programming in the form of failstate and other similar
constructs. Experience has shown that this is a bad approach: It runs really slow,
it makes debugging much harder, since callstacks are useless, and profiling just shows that
the overhead of monads is expensive.
The benefits in a flow context do not really exist, so don't use those things.

#### Why is there a global name space?

Yeah, this sucks, but it is hard to fix. It requires changing not only the compiler and all
the backends, but also the debugger, the profiler and other similar tools. We originally
thought that we would have to fix this quickly to be able to work many people together, but
after many years of working with flow, it turns out not to be as bad. Of course, it is annoying,
and we want to fix it, but at the same time, in practice, there are also what we can call
collateral benefits. The most important is that any top-level name is unambiguous which helps
communication and avoid mistakes.
However, it might be something we will try to tackle.

#### How to break infinite recursion in includes between files?

The situation happens like this:

	a.flow:
	import b;

	b.flow:
	import c;

	c.flow:
	import a;

This will not compile. To break the loop, you have to analyze the uses of names that causes the
recursion. You can use `flowuses` for this. This will allow you to understand what names
from other modules are used. Very often, it is a matter of types that are needed. A useful
fix is then to split out the definition of the required types into a separate `whatever_types.flow`
file without any functions.

In some situations, this is not enough. When this happens, the recommended fix
is to either pass the function you need as a parameter in the problematic
calls, or if there are many of those, then use API-style structs, which you
can populate with the functions from another module. This struct is then
passed as a parameter to the problematic functions.

API-style structs is also a common pattern that is used to make big parts of
code optional, so that programs that do not require all functionality can
avoid taking the footprint hit of such code.

#### How to do efficient string concatenation

Consider the task of concatenating a lot of strings together. When you are used to languages like Java
or C#, you might write something like this:

    txt = ref "";
    iter(items, \item -> {
        txt := ^txt + item2string(item);
    });
    ^txt;

However, in a functional language, you can express it much more directly using fold:

	fold(items, "", \acc, item -> acc + item2string(item));

Both of these versions is O(n^2), so if the array is very long, you might want to use a `List` instead and
collapse it to a `string` in one operation:

	l = fold(items, makeList(), \acc, item, Cons(item2string(item), acc) );
	list2string(l);

This will produce much less garbage in memory and take linear time.

In this particular case, the best option is arguably to use the `concatStrings` function from `string.flow`:

    concatStrings(map(items, item2string));

#### When I deserialize my data, I get an int back instead of a double. What is going on?

When this happens, you get a runtime error that a double was expected. This is
caused by serialization of some kinds of data in the JS target. The fix is to
use the `number2double` native before using the double in question, or make sure
all doubles are directly exposed in structs. Arrays of doubles and such can
not be deserialized correctly due to limitations in JS. The reason is that JS
only has doubles, and no first-class ints. That means that the double `2.0` will
be serialized as 2.

Our runtime contains some partial fixes for this problem in the form of
explicit types on structures with explicit doubles inside in the runtime,
which is then used by `makeStructValue`, which constructs the data. However,
these type annotations are only partial, and does not work for polymorphic
types (i.e. `Pair<double, double>`), arrays (`[double]`) or other similar
constructed types.

##### Serialization of behaviours

Since the implementation of behaviours contain a `DList` of subscribers,
which is a self-recursive structure, you can not print them. `toString` of a
DList with subscriptions needs to following the back and forward pointers
forever, and that is not possible.

So just avoid serializing behaviours. If you really need to do it, then you
have to make sure all your behaviours are "clean" without any subscribers, but
we do not recommend this.

#### Too many heap sections

When I try to compile bigger programs using "flow", I get this error message. What to do?

See `flow9/resources/neko/1.8.2 - 2.0.0/unlimited/`

#### When I get a crash, there are no line numbers. What to do?

If you are running with flowcpp, then add the "--no-jit" parameter. Also,
make sure you produce debug info when compiling to bytecode. This will
automatically happen if you pass a .flow file to flowcpp:

	flowcpp --no-jit myprogram/crash.flow

will give better callstacks.

If you are running with JS, make sure to compile with debug to get
useful names in the generated JS.

#### I've been told to make sure my code can be translated to other languages. How do I do this?

Wrap constant strings using the _() function from `translation.flow` in a way similar to gettext:

	println(_("This should be translated"));

This is then used by the compiler to extract all strings that need to be translated, and at
runtime, we can load the translations and the _() function will make sure to lookup the
correct translation for the given constant string.

So in particular, do NOT use string-tables or constant global variables with the content of strings,
or other such practices. These just obfuscate the code, and makes life harder. Keep it simple, and
just use the `_()` function. This is similar to GNU translate.

If you need to translate runtime data from users, you can use `getTranslation()` instead. See
`translation.flow` for more details.

Here are some tips that doesn't seem obvious sometimes:

1) Use _() around a string, rather than a constant containing it. E.g. if you need to use a translation
multiple times and decide to store the string in a separate constant, this would be wrong:

	text = "Hello";
	println(_(text));

The correct way is:

	text = _("Hello");
	println(text);

2) If you want to put a very long string in multiple lines, do not use '+' to concatenate its parts. This
produces two strings for translation ("This should be " and "translated"):

	println(_("This should be " +
		"translated"));

And it is impossible to translate them correctly into other languages. Instead, just omit the '+' and it
would work fine:

	println(_("This should be "
		"translated"));

3) Use `formatString` if you need to add something to the string.

	items = 5;
	println(_("You have " + i2s(items) + " items left."));
	println(i2s(items) + _(" items left."));
	println(_("Items left: ") + i2s(items) + ".");

All these examples are wrong. The first one produces only one line for translation ("You have"). Moreover
it requires a separate translation for each value of `items`. The second one doesn't take into account
the number: some languages might require to put it somewhere else (e.g. at the end of the line). The third
one also has untranslated full stop symbol: in Chinese and Japanese it is different. All these issues can
be solved by using `formatString`:

	items = 5;
	println(formatString(_("You have %1 items left."), [i2s(items)]));
	println(formatString(_("%1 items left."), [i2s(items)]));
	println(formatString(_("Items left: %1."), [i2s(items)]);

Don't forget that you might require to translate parameters in the array as well.

4) Put everything in one translation rather than splitting the text somehow. It will help people who
translate these lines to better understand the context and provide a better translation.

#### Does flow have threads?

See [concurrent.flow](https://github.com/area9innovation/flow9/blob/master/lib/concurrent.flow). Due to big 
differences in our targets, the APIs for parallel code are very different from target to target.

#### How can I do asynchronous call?

Let's say we would like to load data from DB into state using `loadState` function which is doing DB request, 
i.e. it's an asynchronous call. Consider following example:

	state = makeEmptyState();
	loadState(state);
	useState(state);

This is a wrong and dangerous way of doing this as there is no guarantee that
state will be loaded before `useState` starts. Writing code like this you
introduce race conditions that might be unnoticeable in the beginning when DB
is very small (or when running locally, having good connection) but later very
hard to debug. Instead, you should use callbacks, i.e. write something like this:

	loadState(\state -> {
		useState(state);
	}, \error -> {
		...
	})

Now `useState` will only run once `loadState` is finished. This is a better
way also because you don't introduce global variable. But even if you have to
introduce a global variable you should write it like this:

	state = makeEmptyState();
	loadState(state, \-> {
		useState(state);
	}, \error -> {
		...
	})

This is the only way to guarantee correct order. 

It is also helpful to consider the use of Promises for asynchronous code. See `promise.flow`.

#### How can I do multiple asynchronous calls?

Say we have array of some items and want to run asynchronous call for each of
them. For example, load data from DB for tables from the list. I.e. having a
function like:

	loadDataForItem(item : MyItem, callback : (MyData) -> void, onError : (string) -> void) -> void

You want to write something like:

	processAllItems(items : [MyItem]) -> void {
	 	loadAllData(items, \allData -> {
	  		println("All data loaded");
	  		processAllData(allData);
		}, \error -> {
			println("Can't load data: " + error)
		})
	}

One common way to do it is to make a recursive function with accumulator that
on each iteration will load data and append it to the accumulator.

	loadAllData(items : [MyItem], acc : [MyData], callback : ([MyData]) -> void, onError : (string) -> void) -> void {
		if (items == []) {
			callback(acc)
		} else {
	  		item = items[0];

			loadDataForItem(item, \data -> {
				acc2 = arrayPush(acc, data);

				loadAllData(tail(items), acc2, callback, onError)
			}, \error -> {
				onError(error)
			})
		}
	}

And you call it with empty accumulator

	loadAllData(items, [], callback, onError)

Another way to do it is to use promises. You can find them (together with and
some explanation and links) in `flow9/lib/promise.fow`

Basically for each item you create a promise that can call one of two
callbacks. In our simple case it's just a wrapper around `loadDataForItem`.

Then you just call array of promises and either process the result array or
error case if at least one promise failed

	loadAllData(items : [MyItem], callback : ([MyData]) -> void, onError : (string) -> void) -> void {
		promises = map(items, \item -> {
			Promise(\fulfill, reject -> {
				loadDataForItem(item, fulfill, reject)
			})
		});

		doneP(allP(promises), \allData -> {
			callback(allData)
		}, \error -> {
			onError(error)
		})
	}

#### What data structures are available?

See the "ds" folder where there are things like binarytree, set, easygraph, datastream, dlist, list, 
inttree, inttrie, trie, iterator, ntree, quadtree, sentence_matching, limitedheap.

#### Should I avoid using refs?

Using refs can come in handy in rare cases or may help to improve performance,
but in general using refs introduce side effects, make code harder to change
and easier to make a mistake.

For example, this is a wrong usage of refs:

	countValues(tree : Tree<int, string>) -> int {
		count = ref 0;
		traversePreOrder(tree, \key, value -> {
			if (checkCondition(value)) {
				count := ^count + 1;
			}
		});
		^count;
	}

The right way to do it is:

	countValues(tree : Tree<int, string>) -> int {
		foldTree(tree, 0, \key, value, acc -> {
			if (checkCondition(value)) {
				acc + 1
			} else {
				acc
			}
		})
	}

The same for arrays and other data structures. Always try to use `fold` or
`map` instead of introducing reference variable. If there is no `fold` for the
data structure you are using, use recursion or consider introducing `fold` for
it (like we have foldTree for trees, foldSet for sets).

#### What is wrong with pipe syntax (|>) ? It looks very nice to me. Why should I avoid it?

The problem is that it is hard to understand code written using pipes because
a reader have to turn logic inside out every time.

When you sequentially call functions the most important function is the one
that is called the last while the rest are just details of implementation (at
least this true when you read code the first time). That's why you would
prefer to see "outer" function first when reading a line. For example: `x =
foo(bar(...))`. Here `foo` is more important than `bar`.

Another problem is that last function called defines a type of the result. For
example, looking at `x = make(foo(y))` you can immediately understand type of
`x` - it is a Behaviour<?>. While if it's written like this `x = y |> foo |>
make` the first thing you pay attention is `y` which is not important for
understanding type of `x`.

There is even more strange way of using pipe syntax. It's when developer
invents artificial lambda. For example: `x |> \m -> MBorder(...., m)` makes no
sense as it's clearly more complicated to read than just `MBorder(..., x)`. It
gets even more worse if you have a wrapper around it, something like this: ```
MLines([   MText(...) |> \m -> MBorder(..., m)   ... ]) ``` Here logic is even
more complex while what we are trying to do is very simple. ``` MLines([
MBorder(..., MText(...))   ... ]) ```

If you do not want to nest that deeply, then you local variables, and the result
will be simpler than pipes with lambdas.

There are a few situations when using the pipe syntax is acceptable. For example
in case functions don't change type, something like `message |> addQuotes |>
trimSpaces |> addAuthor`. Here we just transform string sequentially. But in
general try to avoid `|>`.

#### What is the difference between MConstruct and MDispose? When should I use each of them?

The arguments of MConstruct are array of lambdas that will be called when the
element is being rendered as well as array of lambdas that will be called when
the element is hidden from the screen. MDispose takes only array of lambdas
that will be called when element is hidden. In other words, `MConstruct([\->
\-> foo()], ...)` is the same as `MDispose([\-> foo()], ...)`.

The common pattern (anti-pattern?) is like this:

	a : Material = {
	   b = bar();
	   MDispose([\-> foo(b)], m)
	}

Here the intent is to call `bar()` on render and `foo()` on dispose. However
this is correct in case `a` will be rendered only once during the time
application is running.

Let's say `a` will be rendered twice (for example, it's a part of the dialog
that can be opened and closed multiple times). First time `bar()` will be
called on render and `foo()` on dispose. But when rendering `a` second time
`bar()` will not be called while `foo()` will still be called on dispose.

It might be the behavior you want for the code. But most likely you want
`bar()` be called on every render. For example it's very common to run
subscribers on render and unsubscribers on dispose. In this case it's important
that subscribers will be called the same number of times as unsubscribers.
Then you want use `MConstruct` instead:

	a : Material = MConstruct([\-> {
	  b=bar();
	  \-> foo(b)
	}], m)

Here `bar()` will be called on every render and `foo()` will be called on every dispose.

Note, it's quite often that you don't know if the element you are developing
will ever be rendered twice. If so, it's better to assume it will be. In other
words, use `MDispose` only in case you really don't need to call anything on
render.

Antipatterns
--------

#### In the beginning was the Subscribe

Don't make code more complicated than it could be. We have a core function to
react on some behaviours changes, it's `subscribe` at [behaviour.flow](https:/
/github.com/area9innovation/flow9/blob/master/lib/behaviour.flow). Then
Material was invented. And there is a MConstruct with such syntax
`MConstruct(constructors : [() -> () -> void], m : Material);`. So writing
like this doesn't look good:

	MConstruct(
		[
			\ -> subscribe(smth1, doSmth1),
			\ -> subscribe2(smth2, doSmth2),
		],
		material
	)

That's why we added `makeSubscribe` at [fusion.flow](https://github.com/area9innovation/flow9/blob/master/lib/fusion.flow). It has a more convenient syntax
for using inside `MConstruct` (but all these guys from fusion are distinctive,
be careful and read a comment at makeSubscribe declaration). So now we can do
like this:

	MConstruct(
		[
			makeSubscribe(smth1, doSmth1),
			makeSubscribe2(smth2, doSmth2),
		],
		material
	)

And now we are ready to discuss an obvious antipattern: when you need only a
simple `subscribe` don't create a lambda `makeSubscribe` and call it
immediately. Thus an example of this antipattern is:

	subscribeToSomething() -> () -> void {
		makeSubscribe(smth1, doSmth1)()
	}

#### Fold with array accumulator

Note that using fold with array accumulator (e.g. fold + arrayPush/ifArrayPush
or similar) is usually an antipattern and may cause a serious slowdown in
program's performance (as it is O(n^2) with also O(n^2) memory usage and
consumes a lot of resources on high dimensions).

Note that fold + arrayPush is normally map and fold + ifArrayPush is normally
filter or filtermap (which is now efficient enough too). For example:

	// availableVoices : [SpeechSynthesisVoice]
	// prefVoices : [string]

	availablePrefVoices = fold(prefVoices, [], \acc, p -> {
		voice = find(availableVoices, \v -> strContains(v.name, p));
		eitherMap(voice, \v -> arrayPush(acc, v), acc)
	})

It's better to do this way:

	availablePrefVoices = filtermap(prefVoices, \p -> {
		find(availableVoices, \v -> strContains(v.name, p))
	})

#### Why we must use tail recursions

You should writing code in a manner which would allow compiler to perform tail recursion 
optimisations. Ignoring this optimisation may lead to stack overflow.
See [tests/tail_recursion_example.flow](../tests/tail_recursion_example.flow) as an example. 
While collect2 method in this file might look nicer - it will not be converted into cycle 
by compiler and would lead to stack overflow.


#### Creating Maybe in iterators

There are two common antipatterns:

	m : Maybe<?>
	filter(arr, \a : ? -> Some(a) == m)

	v : ?
	filter(arr, \a : Maybe<?> -> a == Some(v))

The problem is that Some is created on the heap at each iteration. There are a lot of ways to avoid this, for example:

In the first case if v is none, we don't need to run through the array at all, so it can be replaced by:

	eitherMap(m, \v -> filter(arr, \a -> a == v), [])

The second case can be fixed by moving Some(v) out of the loop :)

Some kind of mistakes
--------

#### Why can we get different time values for the same moment

In most cases, we will not get such an effect in productive databases.
This is most likely to happen during the development process when our database server uses the local time zone.
Let's look at one of the probable reasons for this.

Basically, data is generated in one of the following places:  
1) On the client side, when we fill out the structures to send them to the server  
2) On the server side (for example, fields with the `default` property in the database).

In the first case, we will get the date and time of the client, in the second case we will have server time.
As we can guess, when our zone is not UTC+0, we can get different times for each of these cases.

For example, we have a structure that is filled and sent to the database

	SomeDataStructure(
		id,                       // id : int,
		userId,                   // userId : int,
			...
		stamp2time(timestamp()),  // created : Time,
			...
	)

The `timestamp` function creates a timestamp using the averaged GMT of UTC+0 and, if we apply the `time2string` function to it, we get a string representing our local time, which consider our time zone.
But, if we use `time2stringUtc`, we get the time for the UTC+0 zone, i.e. not considering our location.
The `stamp2time` function does just that - it uses `time2stringUtc` to convert `timestamp` to a string without regard to the time zone.
And this is in a certain sense correct, if we do not need information about the zone in which the event occurred, then the zone can be safely cut off, stored in UTC+0 format and then transferred to the client, converted to its time zone.

Now imagine that in our database there is such a table

	create table some_database_table(
		id int(11) not null auto_increment,
		user_id int(11),
			...
		created timestamp not null,
		updated timestamp not null default current_timestamp on update current_timestamp,
			...
	)

If we put the data that we created above into this table, then the values ​​of the `created` and` updated` fields will diverge to the value corresponding to the time zone in which the database server is located (+3 hours for me).
In fact, this behavior is obvious and expected.
To prevent this from happening, make sure that your server is running in the UTC+0 zone, and that the `select utc_timestamp;` and `select current_timestamp;` sql requests show the same time.
Another option to avoid this error regarding database architecture: we can use `utc_timestamp` instead of `current_timestamp` for all fields that automatically generate values.

Such an error is unlikely if you are using a remote database or docker container
