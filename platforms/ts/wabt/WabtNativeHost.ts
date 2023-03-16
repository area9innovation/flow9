import * as typenames from "./WabtNativeHost-types.d";
import wabt from 'wabt';

// Parses a WebAssembly text format source to a module.
export function parseWat(filename: string, buffer: string, options: typenames.WasmFeatures): typenames.Promise<typenames.WasmModule, string> {
	let fn = (fulfill: (x: any) => void, reject: (x: any) => void) =>
		wabt().then(w => {
			try {
				const m = w.parseWat(filename, buffer, options);
				if (m) {
					const module : typenames.WasmModule = {
						name: "WasmModule",
						_id : -1,
						validate: () => {
							try {
								m.validate();
								return  "";
							} catch (err) {
								return err.toString();
							}
						},
						resolveNames: () => m.resolveNames(),
						generateNames: () => m.generateNames(),
						applyNames: () => {
							try {
								m.applyNames();
								return "";
							} catch (err) {
								return err.toString();
							}
						},
						toText: (options: typenames.ToTextOptions) => {
							return m.toText(options);
						},
						toBinary: (options: typenames.ToBinaryOptions) => {
							const res = m.toBinary(options);
							const ret : typenames.ToBinaryResult = {
								name : "ToBinaryResult",
								_id : -1,
								buffer: Array.from(res.buffer),
								log: res.log
							};
							return ret;
						},
						destroy: () => m.destroy()
					};
					fulfill(module);
				} else {
					reject("Failed to load *.wat file: " + filename);
				}
			} catch (err) {
				reject(err.toString());
			}
		});
	const ret: typenames.Promise<any, any> = {
		name: "Promise",
		_id : -1,
		f: fn
	};
	return ret;
}

// Reads a WebAssembly binary to a module.
export function readWasm(buffer: number[], read_options: typenames.ReadWasmOptions, options: typenames.WasmFeatures): typenames.Promise<typenames.WasmModule, string>  {
	let fn = (fulfill: (x: any) => void, reject: (x: any) => void) =>
		wabt().then(w => {
			const all_opts = {...read_options, ...options};
			try {
				const m = w.readWasm(Uint8Array.from(buffer), all_opts);
				if (m) {
					const module : typenames.WasmModule = {
						name: "WasmModule",
						_id : -1,
						validate: () => {
							try {
								m.validate();
								return  "";
							} catch (err) {
								return err.toString();
							}
						},
						resolveNames: () => m.resolveNames(),
						generateNames: () => m.generateNames(),
						applyNames: () => {
							try {
								m.applyNames();
								return "";
							} catch (err) {
								return err.toString();
							}
						},
						toText: (options: typenames.ToTextOptions) => {
							return m.toText(options);
						},
						toBinary: (options: typenames.ToBinaryOptions) => {
							const res = m.toBinary(options);
							const ret : typenames.ToBinaryResult = {
								name : "ToBinaryResult",
								_id : -1,
								buffer: Array.from(res.buffer),
								log: res.log
							};
							return ret;
						},
						destroy: () => m.destroy()
					};
					fulfill(module);
				} else {
					reject("Failed to load wasm binary");
				}
			} catch (err) {
				reject(err.toString());
			}
		});
	const ret: typenames.Promise<any, any> = {
		name: "Promise",
		_id : -1,
		f: fn
	};
	return ret;
}

export function runWasmFunc(bin : typenames.ToBinaryResult, fn_name : string, as : any[]): typenames.Promise<any, any> {
	//var importObject = { imports: { i: arg => console.log(arg) } };
	let fn = (fulfill: (x: any) => void, reject: (x: any) => void) =>
		WebAssembly.instantiate(new Uint8Array(bin.buffer)).then(
			instance => {
				let fn: any = instance.instance.exports[fn_name];
				fulfill(fn(...as));
			},
			reject
		);
	const ret: typenames.Promise<any, any> = {
		name: "Promise",
		_id : -1,
		f: fn
	};
	return ret;
}
