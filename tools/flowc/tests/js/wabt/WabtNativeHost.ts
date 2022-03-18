import * as typenames from "./WabtNativeHost-types.d";
import wabt from 'wabt';

// Parses a WebAssembly text format source to a module.
export function parseWat(filename: string, buffer: string, options: typenames.WasmFeatures, on_module : (m :typenames.WasmModule) => void): void {
	wabt().then(w => {
		const m = w.parseWat(filename, buffer, options);
		const module : typenames.WasmModule = {
			name: "WasmModule",
			_id : -1,
			validate: () => m.validate(),
			resolveNames: () => m.resolveNames(),
			generateNames: () => m.generateNames(),
			applyNames: () => m.applyNames(),
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
		on_module(module);
	});
}

// Reads a WebAssembly binary to a module.
export function readWasm(buffer: number[], read_options: typenames.ReadWasmOptions, options: typenames.WasmFeatures, on_module : (m :typenames.WasmModule) => void): void {
	wabt().then(w => {
		const all_opts = {...read_options, ...options};
		const m = w.readWasm(Uint8Array.from(buffer), all_opts);
		const module : typenames.WasmModule = {
			name: "WasmModule",
			_id : -1,
			validate: () => m.validate(),
			resolveNames: () => m.resolveNames(),
			generateNames: () => m.generateNames(),
			applyNames: () => m.applyNames(),
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
		on_module(module);
	});
}

export function runAdd(bin : typenames.ToBinaryResult, a1 : number, a2 : number, callback: (r: number) => void): void {
	//var importObject = { imports: { i: arg => console.log(arg) } };
	WebAssembly.instantiate(new Uint8Array(bin.buffer)).then(instance => {
		let addition: any = instance.instance.exports.add;
		callback(addition(a1, a2));
	});
}

export function runFunc(bin : typenames.ToBinaryResult, fn_name : string, as : any[], callback: (r: any) => void): void {
	//var importObject = { imports: { i: arg => console.log(arg) } };
	WebAssembly.instantiate(new Uint8Array(bin.buffer)).then(instance => {
		let fn: any = instance.instance.exports[fn_name];
		callback(fn(...as));
	});
}

export function runFunc1(bin : typenames.ToBinaryResult, fn_name : string, as : any[]): typenames.Promise<any, any> {
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