// Tests of platforms/js/TextInputSanitizer.hx with the DOMPurify bundled in www/js.
// Run: npm install && npm test

const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const root = path.join(__dirname, '..', '..', '..');
const window = new JSDOM('').window;
const DOMPurify = require(path.join(root, 'www', 'js', 'purify', 'purify.min.js'))(window);

// Takes the JS code from the Haxe source, so the test always checks what is compiled
const sanitizerSource = (function() {
	const source = fs.readFileSync(path.join(root, 'platforms', 'js', 'TextInputSanitizer.hx'), 'utf8');
	const match = /untyped __js__\("([^]*?)\n\t"\);/.exec(source);
	assert.ok(match, 'JS code is not found in TextInputSanitizer.hx');
	// Haxe string literal to JS code
	return match[1].replace(/\\(.)/g, function(_, char) {
		return { n: '\n', t: '\t', r: '\r' }[char] || char;
	});
})();

// Every sanitizer has its own cache of safe tokens
const createSanitizer = function(purify) {
	return new Function('DOMPurify', 'return ' + sanitizerSource.trim())(purify || DOMPurify);
};

// The input value is not rendered, the danger is a consumer rendering it as HTML in any context
const findLiveXSS = function(html) {
	return ['', '<svg>', '<math>', '<table>', '<select>', '<textarea>', '<title>', '<noscript>'].some(function(context) {
		const document = new JSDOM('<!doctype html><body>' + context + html).window.document;
		return Array.prototype.some.call(document.querySelectorAll('*'), function(element) {
			return element.nodeName.toLowerCase() == 'script'
				|| Array.prototype.some.call(element.attributes, function(attribute) {
					return (/^on/i.test(attribute.name) && attribute.value.trim() != '') || /^\s*(javascript|data):/i.test(attribute.value);
				});
		});
	});
};

const harmlessTexts = [
	'',
	'plain text',
	'x<y, a>b',
	'if a<b and c>d then',
	'a <= b >= c',
	'1 < 2 > 0',
	'<test>',
	'<br><br> **D** <br> E | F |',
	'<br',
	'Hello <br world and more text',
	'<b>bold</b> and <i>it</i>',
	'<a href="https://example.com">link</a>',
	'<a id=x name=y>',
	'<x-foo onclick>hi</x-foo>',
	'<input disabled>',
	'a <!-- plain note --> b',
	'typing <!--',
	'<!-- x > y, a < b -->',
	'<!-- note --> <b>x</b>',
	'Use the <title> tag for page titles. More text here.',
	'<textarea>plain</textarea> <title>T</title>',
	'<textarea>&lt;b&gt;</textarea>',
	'<td>cell</td> <option>one</option>',
];

const dangerousTexts = [
	'<script>alert(1)</script>',
	'text <script src=//evil.example></script>',
	'<iframe src=//evil.example>',
	'<svg onload=alert(1)>',
	'<style>',
	'<img src=x onerror=alert(1)>',
	'<image src=x onerror=alert(1)>',
	'<a href=javascript:alert(1)>x</a>',
	'<a href=" jav&#x09;ascript:alert(1)">x</a>',
	'<a href="data:text/html,<script>alert(1)</script>">x</a>',
	'<button formaction=javascript:alert(1)>x</button>',
	'<form><button formaction=javascript:alert(1)>x',
	'<form action=javascript:alert(1)><input type=submit>',
	'<details open ontoggle=alert(1)>',
	'<x-foo onclick=alert(1)>x</x-foo>',
	'<test onclick=alert(1)>x</test>',
	'<td onclick=alert(1)>x</td>',
	'<isindex action=javascript:alert(1) type=image>',
	'<select><img src=x onerror=alert(1)></select>',
	'<select><button><img src=x onerror=alert(1)></button></select>',
	'<table><img src=x onerror=alert(1)>',
	'<!--</textarea><img src=x onerror=alert(1)>-->',
	'<!--</title><img src=x onerror=alert(1)>-->',
	'<!--</noembed><img src=x>-->',
	'<!--><img src=x onerror=alert(1)>-->',
	'<a title="</textarea><img src=x onerror=alert(1)>">x</a>',
	'<a title=\'</textarea><img src=x onerror=alert(1)>\'>x</a>',
	'<textarea></textarea><img src=x onerror=alert(1)></textarea>',
	'<textarea><img src=x onerror=alert(1)></textarea>',
	'<textarea><img src=x onerror=alert(1)>',
	'<title><img src=x onerror=alert(1)></title>',
	'<noembed><img title="</noembed><img src onerror=alert(1)>"></noembed>',
	'<xmp><img src=x onerror=alert(1)></xmp>',
];

test('harmless texts are kept', function() {
	const sanitize = createSanitizer();
	harmlessTexts.forEach(function(text) {
		assert.strictEqual(sanitize(text), text);
	});
});

test('dangerous texts are sanitized by DOMPurify', function() {
	const sanitize = createSanitizer();
	dangerousTexts.forEach(function(text) {
		const result = sanitize(text);
		assert.notStrictEqual(result, text, text);
		assert.strictEqual(result, DOMPurify.sanitize(text), text);
	});
});

test('results have no live XSS in any context', function() {
	const sanitize = createSanitizer();
	harmlessTexts.concat(dangerousTexts).forEach(function(text) {
		assert.ok(!findLiveXSS(sanitize(text)), text);
	});
});

test('cached safe tokens do not hide dangerous ones', function() {
	const sanitize = createSanitizer();
	const text = '<b>bold</b> <a href="https://example.com">link</a> ';
	assert.strictEqual(sanitize(text), text);

	dangerousTexts.forEach(function(dangerous) {
		assert.notStrictEqual(sanitize(text + dangerous), text + dangerous, dangerous);
		assert.notStrictEqual(sanitize(dangerous + text), dangerous + text, dangerous);
	});
});

test('typing a text char by char', function() {
	const sanitize = createSanitizer();
	const text = 'See <a href="https://example.com/page">the page</a>, <b>it</b> is <br> fine. x<y. ';
	for (let i = 1; i <= text.length; i++) {
		assert.strictEqual(sanitize(text.substring(0, i)), text.substring(0, i));
	}

	const dangerous = text + '<img src=x onerror=alert(1)>';
	assert.notStrictEqual(sanitize(dangerous), dangerous);
});

test('tokens are not cached as safe when the check fails', function() {
	let fail = true;
	const failingPurify = {
		sanitize: function(text, config) {
			if (fail) {
				throw new Error('DOMPurify failed');
			}

			return DOMPurify.sanitize(text, config);
		},
		get removed() {
			return DOMPurify.removed;
		}
	};

	const sanitize = createSanitizer(failingPurify);
	const text = '<img src=x onerror=alert(1)>';
	assert.throws(function() { sanitize(text); });

	fail = false;
	assert.notStrictEqual(sanitize(text), text);
});

test('huge texts are fast', function() {
	const sanitize = createSanitizer();
	const n = 50000;
	const texts = {
		'plain': 'Lorem ipsum dolor sit amet. '.repeat(n),
		'tags': '<p>Lorem <b>ipsum</b> <a href="https://example.com/x">dolor</a>.</p>\n'.repeat(n / 5),
		'unique tags': Array.from({ length: n / 5 }, function(_, i) { return '<a href="/p' + i + '">x</a> '; }).join(''),
		'attributes': '<a ' + 'a=b='.repeat(n),
		'quotes': '<a ' + '="'.repeat(n),
		'slashes': '<a' + ' /'.repeat(n),
		'textarea ends': '<textarea>' + '</textarea '.repeat(n),
		'comments': '<!--'.repeat(n),
		'unclosed tags': '<a '.repeat(n),
	};

	Object.keys(texts).forEach(function(name) {
		const start = Date.now();
		sanitize(texts[name]);
		sanitize(texts[name] + 'x');
		const time = Date.now() - start;
		assert.ok(time < 5000, name + ': ' + time + ' ms');
	});
});
