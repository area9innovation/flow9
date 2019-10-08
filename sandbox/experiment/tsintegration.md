# Using flow code in Typescript

At the end of the JS file, the flow compiler produces if we call the library <test>, 
add this:

<test> = {foo:foo};

Wrap d.ts file with 

	declare module <test> {
		export function foo():void;
		...
	}

Then do this in the TS file:

/// <reference types="../@types/test/test" />

	// And now we can call:
    test.foo();

And add this in the HTML:

<html>
    <head>
		<script src="test.js"></script>
		...
    </head>
    <body >
	...
    </body>
</html>
I


# Using JS in flow code

Create a DOM node with a <script> element.

Then use "hostcall" to call functions.


# Using Typescript in flow code:

Export TS types to declaration file:

	tsc --emitDeclarationOnly --declaration --declarationDir c:\temp

and we get something like:

	declare var load: () => void;
	declare function bar(a: number): number;

We could parse this, and produce flow wrapper functions to use these.

	import @types/file.d.ts;
	dynamic @types/file.d.ts;


// Raw JS

