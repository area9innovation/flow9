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

