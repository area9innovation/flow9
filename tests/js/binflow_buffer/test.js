// Tests of platforms/js/JSBinflowBuffer.hx: values built by Native.toBinary round-trip unchanged,
// nesting up to 512 containers decodes and can be printed/written again, and input that is too deep,
// cut short, declares too many elements, has a footer
// of the wrong shape or a footer offset outside the input yields the default value quickly.
// Needs the haxe CLI on PATH. Run: npm test

const test = require('node:test');
const { after } = test;
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const root = path.join(__dirname, '..', '..', '..');
const outDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sec-depth-binflow-buffer-'));

// Compiles the class with the runtime it imports, the same sources flowc gives to haxe
const runtime = (function() {
	const outFile = path.join(outDir, 'binflow_buffer.js');
	execFileSync('haxe', [
		'-cp', __dirname, '-cp', path.join(root, 'platforms', 'js'), '-cp', path.join(root, 'platforms', 'common', 'haxe'),
		'-D', 'jsruntime', '-D', 'no-deprecation-warnings', '-D', 'js-classic',
		'-main', 'BinflowBufferExports', '-js', outFile,
	], { stdio: 'inherit' });
	// The runtime reads a few browser globals when it loads
	globalThis.window = globalThis;
	globalThis.navigator = { userAgent: '' };
	globalThis.location = { href: '', search: '', hash: '' };
	globalThis.matchMedia = function() { return { matches: false }; };
	return require(outFile);
})();
const { JSBinflowBuffer, Native, HaxeRuntime, RuntimeType, FlowRefObject } = runtime;

after(function() {
	fs.rmSync(outDir, { recursive: true, force: true });
	delete globalThis.window;
	delete globalThis.navigator;
	delete globalThis.location;
	delete globalThis.matchMedia;
});

// Structs as the flow runtime registers them; None is the answer of a fixups function without a fixup
const NONE_ID = 1, SOME_ID = 2, LEAF_ID = 3, NODE_ID = 4, BOX_ID = 5, EMPTY_ID = 6;
HaxeRuntime.initStruct(NONE_ID, 'None', [], []);
HaxeRuntime.initStruct(SOME_ID, 'Some', ['value'], [RuntimeType.RTUnknown]);
HaxeRuntime.initStruct(LEAF_ID, 'Leaf', ['id', 'name', 'weight', 'flag'],
	[RuntimeType.RTInt, RuntimeType.RTString, RuntimeType.RTDouble, RuntimeType.RTBool]);
HaxeRuntime.initStruct(NODE_ID, 'Node', ['label', 'items', 'link'],
	[RuntimeType.RTString, RuntimeType.RTArray(RuntimeType.RTUnknown), RuntimeType.RTRefTo(RuntimeType.RTUnknown)]);
HaxeRuntime.initStruct(BOX_ID, 'Box', ['value'], [RuntimeType.RTUnknown]);
HaxeRuntime.initStruct(EMPTY_ID, 'Empty', [], []);

const leaf = function(id, name, weight, flag) { return { _id: LEAF_ID, id: id, name: name, weight: weight, flag: flag }; };
const node = function(label, items, link) { return { _id: NODE_ID, label: label, items: items, link: link }; };
const ref = function(value) { return new FlowRefObject(value); };
const box = function(value) { return { _id: BOX_ID, value: value }; };

const DEFAULT = { defaultValue: true };
const noFixups = function() { return { _id: NONE_ID }; };

const wordsOf = function(s) {
	const words = [];
	for (let i = 0; i < s.length; i++) words.push(s.charCodeAt(i));
	return words;
};
const encode = function(value) { return wordsOf(Native.toBinary(value)); };
const bufferOf = function(words, littleEndian) {
	const bytes = new ArrayBuffer(words.length * 2);
	const view = new DataView(bytes);
	words.forEach(function(word, i) { view.setUint16(i * 2, word, littleEndian); });
	return new JSBinflowBuffer(bytes, 0, bytes.byteLength, littleEndian);
};
const deserialise = function(words, littleEndian) {
	return bufferOf(words, littleEndian !== false).deserialise(DEFAULT, noFixups);
};

// The two header words hold the footer offset the way toBinary writes it
const header = function(footerOffset) { return [footerOffset & 0xFFFF, footerOffset >>> 16]; };
const footerOffsetOf = function(words) { return words[0] | (words[1] << 16); };
const bodyOf = function(words) { return words.slice(2, footerOffsetOf(words)); };
const footerOf = function(words) { return words.slice(footerOffsetOf(words)); };
const assemble = function(body, footer) { return header(body.length + 2).concat(body, footer); };
const withWord = function(words, index, word) {
	const copy = words.slice();
	copy[index] = word;
	return copy;
};
const withInt = function(words, index, value) { return withWord(withWord(words, index, value & 0xFFFF), index + 1, value >>> 16); };
// The words of a string value shorter than 65536 characters
const stringWords = function(s) { return [0xFFFA, s.length].concat(wordsOf(s)); };
const structDef = function(arity, name) { return [0xFFF8, 2, arity].concat(stringWords(name)); };

const nestedArrays = function(depth, inner) {
	let value = inner;
	for (let i = 0; i < depth; i++) value = [value];
	return value;
};
const nestedRefs = function(depth, inner) {
	let value = inner;
	for (let i = 0; i < depth; i++) value = ref(value);
	return value;
};
const nestedStructs = function(depth, inner) {
	let value = inner;
	for (let i = 0; i < depth; i++) value = box(value);
	return value;
};
// Each node adds two levels: the struct and its items array
const nestedNodes = function(count, inner) {
	let value = inner;
	for (let i = 0; i < count; i++) value = node('n', [value], ref(0));
	return value;
};

const sampleLeaf = leaf(2, 'alpha', 1.5, false);
const sampleNode = node('root', [sampleLeaf, [1.5, 'beta']], ref(7.5));

// Exercise the real recursive writer and printer on accepted decoded values as well
const checkDecoded = function(words, expected, littleEndian) {
	const actual = deserialise(words, littleEndian);
	assert.deepStrictEqual(actual, expected);
	const printed = HaxeRuntime.toString(actual);
	assert.ok(!printed.includes('<native>'), 'the runtime printer handles the entire value');
	assert.strictEqual(printed, HaxeRuntime.toString(expected));
	assert.strictEqual(Native.toBinary(actual), Native.toBinary(expected));
};
const checkRoundTrip = function(name, value) {
	test('round trip of ' + name, function() {
		checkDecoded(encode(value), value);
	});
};

// A short description of a wrong result; a big value in an assertion message takes too much memory
const describe = function(value) {
	if (Array.isArray(value)) return 'an array of ' + value.length;
	if (value instanceof FlowRefObject) return 'a ref';
	if (value !== null && typeof value == 'object') return 'an object with keys ' + Object.keys(value).join(',');
	return typeof value + ' ' + String(value).substring(0, 60);
};

const damagedCases = [];
let damagedTime = 0;
const checkDamaged = function(name, words) {
	damagedCases.push(name);
	test('damaged ' + name, function() {
		const start = performance.now();
		const result = deserialise(words);
		damagedTime += performance.now() - start;
		assert.ok(result === DEFAULT, 'expected the default value, got ' + describe(result));
	});
};

// A plain number is a double for toBinary; ints travel as struct fields typed RTInt
checkRoundTrip('double', 3.25);
checkRoundTrip('true', true);
checkRoundTrip('false', false);
checkRoundTrip('string', 'héllo, wörld');
checkRoundTrip('empty string', '');
checkRoundTrip('long string', 'x'.repeat(70000));
checkRoundTrip('empty array', []);
checkRoundTrip('array', [1.5, 2.5]);
checkRoundTrip('long array', Array.from({ length: 70000 }, function(_, i) { return i + 0.5; }));
checkRoundTrip('ref', ref(5.5));
checkRoundTrip('struct with small int', sampleLeaf);
checkRoundTrip('struct with big int', leaf(123456789, 'big', 0.5, true));
checkRoundTrip('nested value', sampleNode);
checkRoundTrip('arrays nested 512 deep', nestedArrays(512, 1.5));
checkRoundTrip('refs nested 512 deep', nestedRefs(512, 1.5));
checkRoundTrip('structs nested 512 deep', nestedStructs(512, 1.5));
checkRoundTrip('nodes nested 256 deep (512 containers)', nestedNodes(256, 1.5));
checkRoundTrip('siblings each use their own depth', [nestedArrays(511, 1.5), nestedRefs(511, 1.5), nestedStructs(511, 1.5)]);

test('a negative int', function() {
	// 0xFFF5 holds a 32-bit int as two words, low first; 0xFFF7 is an empty footer
	assert.strictEqual(deserialise(assemble([0xFFF5, 0xFFF9, 0xFFFF], [0xFFF7])), -7);
});

test('round trip of a big endian buffer', function() {
	assert.deepStrictEqual(deserialise(encode(sampleNode), false), sampleNode);
});

test('a fixup builds the struct value', function() {
	const fixups = function(name) {
		return name == 'Leaf' ? { _id: SOME_ID, value: function(args) { return { fixed: args }; } } : { _id: NONE_ID };
	};
	assert.deepStrictEqual(bufferOf(encode(sampleLeaf), true).deserialise(DEFAULT, fixups), { fixed: [2, 'alpha', 1.5, false] });
});

test('a fixup receives an older schema with different field count and types', function() {
	const words = assemble([0xFFF4, 0].concat(stringWords('old')), [0xFFF8, 1, 0xFFF8, 2, 1].concat(stringWords('Leaf')));
	const fixups = function() {
		return { _id: SOME_ID, value: function(args) {
			assert.deepStrictEqual(args, ['old']);
			return leaf(7, args[0], 0.5, true);
		} };
	};
	assert.deepStrictEqual(bufferOf(words, true).deserialise(DEFAULT, fixups), leaf(7, 'old', 0.5, true));
});

// fromBinary under the guard deserializeBinary2 puts around it
const guardedFromBinary = function(buffer, fixups) {
	return Native.catchDecodeError(function() { return Native.fromBinary(buffer, DEFAULT, fixups); }, function() { return DEFAULT; });
};

test('a throwing fixup gives the whole default, including inside containers', function() {
	const fixups = function() { return { _id: SOME_ID, value: function() { throw new Error('callback failed'); } }; };
	[sampleLeaf, [sampleLeaf], ref(sampleLeaf), { _id: NONE_ID }].forEach(function(value) {
		assert.strictEqual(guardedFromBinary(bufferOf(encode(value), true), fixups), DEFAULT);
	});
});

test('a buffer can be decoded again after a fixup exception', function() {
	const buffer = bufferOf(encode(sampleLeaf), true);
	const fixups = function() { return { _id: SOME_ID, value: function() { throw 'callback failed'; } }; };
	assert.strictEqual(guardedFromBinary(buffer, fixups), DEFAULT);
	assert.deepStrictEqual(Native.fromBinary(buffer, DEFAULT, noFixups), sampleLeaf);
});

test('a fixup that overflows the stack gives the default', function() {
	const recurse = function(n) { return n == 0 ? 0 : 1 + recurse(n - 1); };
	const fixups = function() { return { _id: SOME_ID, value: function() { return recurse(1e8); } }; };
	assert.strictEqual(guardedFromBinary(bufferOf(encode(sampleLeaf), true), fixups), DEFAULT);
});

test('catchDecodeError gives the result, or onError of the error text', function() {
	const onError = function(error) { return { error: error }; };
	[DEFAULT, null, 42, { _id: LEAF_ID }].forEach(function(value) {
		assert.strictEqual(Native.catchDecodeError(function() { return value; }, onError), value);
	});
	assert.deepStrictEqual(Native.catchDecodeError(function() { throw new Error('callback failed'); }, onError), { error: 'Error: callback failed' });
});

test('catchDecodeError lets a fail() through', function() {
	const onError = function() { return DEFAULT; };
	assert.throws(function() { Native.catchDecodeError(function() { Native.failWithError('corrupt save'); }, onError); }, /Runtime failure: corrupt save/);
	const failingFixup = function() { Native.failWithError('corrupt save'); };
	const fixups = function() { return { _id: SOME_ID, value: failingFixup }; };
	assert.throws(function() { guardedFromBinary(bufferOf(encode(sampleLeaf), true), fixups); }, function(error) {
		// The stack is the one of the fail(), not of the rethrow
		return /corrupt save/.test(String(error)) && /failingFixup/.test(error.stack);
	});
});

test('a second call with other fixups does not reuse the first', function() {
	const words = encode(sampleLeaf);
	const fixups = function(name) {
		return name == 'Leaf' ? { _id: SOME_ID, value: function(args) { return { fixed: args }; } } : { _id: NONE_ID };
	};
	const buffer = bufferOf(words, true);
	assert.deepStrictEqual(buffer.deserialise(DEFAULT, fixups), { fixed: [2, 'alpha', 1.5, false] });
	assert.deepStrictEqual(buffer.deserialise(DEFAULT, noFixups), sampleLeaf);
});

// Build nested input independently of the recursive writer
const nestedBody = function(prefix, depth, leaf) {
	const body = [];
	for (let i = 0; i < depth; i++) body.push(...prefix);
	return body.concat(leaf);
};
const boxFooter = [0xFFF8, 1].concat(structDef(1, 'Box'));
const emptyStructFooter = [0xFFF8, 1].concat(structDef(0, 'Empty'));
const nestingCases = [
	{ name: 'short array', prefix: [0xFFF8, 1], footer: [0xFFF7], nest: nestedArrays },
	{ name: 'long array', prefix: [0xFFF9, 1, 0], footer: [0xFFF7], nest: nestedArrays },
	{ name: 'ref', prefix: [0xFFF6], footer: [0xFFF7], nest: nestedRefs },
	{ name: 'struct', prefix: [0xFFF4, 0], footer: boxFooter, nest: nestedStructs },
];
for (const kind of nestingCases) {
	for (const depth of [511, 512, 513]) {
		const words = assemble(nestedBody(kind.prefix, depth, [5]), kind.footer);
		const name = kind.name + ' nesting ' + depth;
		if (depth > 512) checkDamaged(name, words);
		else test(name, function() {
			checkDecoded(words, kind.nest(depth, 5));
			checkDecoded(words, kind.nest(depth, 5), false);
		});
	}
}

// Empty arrays and zero-field structs add a level even though they leave no open frame
for (const leaf of [[0xFFF7], [0xFFF8, 0], [0xFFF9, 0, 0]]) {
	test('empty array at depth 512 tag ' + leaf[0], function() {
		checkDecoded(assemble(nestedBody([0xFFF6], 511, leaf), [0xFFF7]), nestedRefs(511, []));
	});
	checkDamaged('empty array at depth 513 tag ' + leaf[0], assemble(nestedBody([0xFFF6], 512, leaf), [0xFFF7]));
}
test('zero-field struct at depth 512', function() {
	checkDecoded(assemble(nestedBody([0xFFF8, 1], 511, [0xFFF4, 0]), emptyStructFooter), nestedArrays(511, { _id: EMPTY_ID }));
});
checkDamaged('zero-field struct at depth 513', assemble(nestedBody([0xFFF8, 1], 512, [0xFFF4, 0]), emptyStructFooter));

for (const leaf of [1.5, true, false, 's', '', null]) {
	checkRoundTrip('scalar ' + String(leaf) + ' below 512 containers', nestedArrays(512, leaf));
}
checkRoundTrip('mixed nesting 512', nestedArrays(170, nestedRefs(171, nestedStructs(171, 5))));
checkDamaged('mixed nesting 513', encode(nestedArrays(171, nestedRefs(171, nestedStructs(171, 5)))));

test('the nesting limit is checked before constructing a struct', function() {
	let calls = 0;
	const fixups = function() { return { _id: SOME_ID, value: function(args) { calls++; return box(args[0]); } }; };
	const accepted = assemble(nestedBody([0xFFF4, 0], 512, [5]), boxFooter);
	assert.deepStrictEqual(bufferOf(accepted, true).deserialise(DEFAULT, fixups), nestedStructs(512, 5));
	assert.strictEqual(calls, 512);
	calls = 0;
	const rejected = assemble(nestedBody([0xFFF4, 0], 513, [5]), boxFooter);
	assert.strictEqual(bufferOf(rejected, true).deserialise(DEFAULT, fixups), DEFAULT);
	assert.strictEqual(calls, 0);
});

// Former unbounded-depth cases now exercise prompt default handling instead
checkDamaged('arrays nested 100000 deep', assemble(nestedBody([0xFFF8, 1], 100000, [5]), [0xFFF7]));
checkDamaged('refs nested 100000 deep', assemble(nestedBody([0xFFF6], 100000, [5]), [0xFFF7]));

(function() {
	// The count word follows the array tag
	const b = encode([1.5, 2.5, 3.5]);
	checkDamaged('array count past the end', withWord(b, b.indexOf(0xFFF8) + 1, 60000));
	const l = encode(Array.from({ length: 70000 }, function(_, i) { return i; }));
	checkDamaged('long array count past the end', withInt(l, l.indexOf(0xFFF9) + 1, 1000000));
	// The footer holds [[arity, name]] for each struct, the arity is its third word
	const s = encode(sampleLeaf);
	checkDamaged('struct arity past the end', assemble(bodyOf(s), withWord(footerOf(s), 4, 50)));
})();

(function() {
	const b = encode(sampleNode);
	const body = bodyOf(b);
	const footer = footerOf(b);
	for (let n = 0; n < body.length; n++) {
		checkDamaged('body cut to ' + n + ' words', assemble(body.slice(0, n), footer));
	}
	[1, 2, 5, Math.floor(b.length / 2), b.length - 1].forEach(function(n) {
		checkDamaged('input cut to ' + n + ' words', b.slice(0, n));
	});
})();

(function() {
	const b = encode([1.5, 2.5, 3.5]);
	const rest = b.slice(2);
	const n = b.length;
	checkDamaged('footer offset 0', header(0).concat(rest));
	checkDamaged('footer offset at the body start', header(2).concat(rest));
	checkDamaged('footer offset at the end', header(n).concat(rest));
	checkDamaged('footer offset past the end', header(n + 10).concat(rest));
	checkDamaged('footer offset far past the end', header(0x7FFFFFFF).concat(rest));
	checkDamaged('negative footer offset', header(-5).concat(rest));
	// A first int of 1 means the offset is split over the next two ints
	checkDamaged('six word header with offset 0', header(1).concat(header(0), header(0), rest));
	checkDamaged('six word header cut short', header(1).concat([0]));
	checkDamaged('empty input', []);
	checkDamaged('one word input', [0xFFF7]);
})();

(function() {
	// A footer entry is [arity, name]: an array of exactly an int and a string
	const body = bodyOf(encode(sampleLeaf));
	const name = stringWords('Leaf');
	const footer = function(entry) { return [0xFFF8, 1].concat(entry); };
	checkDamaged('footer entry of one element', assemble(body, footer([0xFFF8, 1, 4])));
	checkDamaged('footer entry of three elements', assemble(body, footer([0xFFF8, 3, 4].concat(name, [0]))));
	checkDamaged('footer entry that is an int', assemble(body, footer([4])));
	checkDamaged('footer arity that is a string', assemble(body, footer([0xFFF8, 2].concat(stringWords('4'), name))));
	checkDamaged('footer arity that is a double', assemble(body, footer([0xFFF8, 2].concat(bodyOf(encode(4.5)), name))));
	checkDamaged('negative footer arity', assemble(body, footer([0xFFF8, 2, 0xFFF5, 0xFFFF, 0xFFFF].concat(name))));
	checkDamaged('footer name that is an int', assemble(body, footer([0xFFF8, 2, 4, 7])));
	checkDamaged('footer name cut short', assemble(body, footer([0xFFF8, 2, 4, 0xFFFA, 4, 0x4C])));
	checkDamaged('footer that is an int', assemble(body, [4]));
	test('a footer entry the body does not use', function() {
		const unused = [0xFFF8, 2, 0].concat(stringWords('None'));
		assert.deepStrictEqual(deserialise(assemble(body, [0xFFF8, 2, 0xFFF8, 2, 4].concat(name, unused))), sampleLeaf);
	});
})();

(function() {
	// The struct index word follows the struct tag; only one struct is defined
	const b = encode([true, sampleLeaf, false]);
	checkDamaged('struct index out of range', withWord(b, b.indexOf(0xFFF4) + 1, 7));
	const s = encode('x'.repeat(70000));
	checkDamaged('negative long string length', withInt(s, s.indexOf(0xFFFB) + 1, -1));
	const l = encode(Array.from({ length: 70000 }, function(_, i) { return i; }));
	checkDamaged('negative long array count', withInt(l, l.indexOf(0xFFF9) + 1, -1));
	// A sized value that reaches the footer: a double tag as the last body word
	const d = encode(1.5);
	checkDamaged('double cut by the footer', assemble(bodyOf(d).slice(0, 1), footerOf(d)));
})();

test('fromBinary lets a throwing fixup lookup reach the caller', function() {
	const throwing = function() { throw new Error('fixup lookup failed'); };
	assert.throws(function() { Native.fromBinary(bufferOf(encode(sampleLeaf), true), DEFAULT, throwing); }, /fixup lookup failed/);
});

test('fromBinary returns a plain string unchanged', function() {
	const s = Native.toBinary(sampleLeaf);
	assert.strictEqual(Native.fromBinary(s, DEFAULT, noFixups), s);
});

test('all damaged cases together finish quickly', function() {
	assert.ok(damagedCases.length > 40, 'damaged cases are registered');
	assert.ok(damagedTime < 5000, damagedCases.length + ' damaged cases took ' + Math.round(damagedTime) + ' ms');
});
