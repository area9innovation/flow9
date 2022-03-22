# Test cases

These are generated using this site:

https://mbebenita.github.io/WasmExplorer/

Be sure to set optimization level to 0.

test1.wasm is this one:

	int main() {
		int i = 0;
		while (i < 10) {
			i++;
		};
		return i;
	}

See what the web-site generates in test1_online.wat.

The test1.wat is what WABT wasm2wat produces.

