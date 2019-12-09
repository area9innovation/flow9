*Preprocessor*
==============

This is general-purpose preprocessor. Can be used to prepare sources for parsing, compilation etc.

Conditional preprocessing
-------------------------

Preprocessor supports conditional directive `#ifdef`. Here is an example:

	#ifdef DEFINITION_NAME
		Some text source that will be preserved, if "DEFINITION_NAME" presents in preprocessor's definitions list
	#else
		Some text source that will be preserved, if "DEFINITION_NAME DOES NOT present in preprocessor's definitions list
	#endif

Also multiple conditions are supported as well with using `#elif` directive:

	#ifdef DEFINITION_NAME
		Some source text
	#elif DEFINITION_NAME_2
		Some source text 2
	#else
		Some source text 3
	#endif

`#else` directive is optional and could be omitted:

	prod = case1
	#ifdef ADDITIONAL_CASES
		| case 2
		| case 3
	#endif
		| case 4;

_Definition names_ have same restrictions as ids in flow.

Support
-------

Lingo has an option to preprocess grammar before compiling it.
See *lib/lingo/pegcode/pegcompiler.flow* keys for details.
Also there is a couple of functions in *preprocessor_utils.flow*