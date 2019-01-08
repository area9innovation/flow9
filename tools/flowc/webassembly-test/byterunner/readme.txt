to compile wasm byterunner:
	- it's required to have an emscripten sdk installed.
	check https://kripken.github.io/emscripten-site/docs/tools_reference/emsdk.html

	- check flow9/tools/flowc/webassembly-test/byterunner/compile.bat for correct paths and execute it

test files located in flow9/tools/flowc/webassembly-test/byterunner/tests. to compile tests into bytecode use compile_flow.bat or compile_flowc.bat
result will be saved in flow9/tools/flowc/webassembly-test/byterunner/out

execution:

launch http://localhost/flow/tools/flowc/webassembly-test/byterunner/out/byterunner.html?flowfile=test2.bytecode&verbose=0

verbose=1 will cause more detailed console output (will work slowly)