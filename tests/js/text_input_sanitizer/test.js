// Tests of platforms/js/TextInputSanitizer.hx with the DOMPurify bundled in www/js.
// The sanitizer relies on what DOMPurify removes, so run them after every update of www/js/purify.
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

// Internal function of the sanitizer with the patterns it uses, the code from the patterns to the next function
const scanTagToken = (function() {
	const start = sanitizerSource.indexOf('var tagPattern');
	const end = sanitizerSource.indexOf('var hasAttributeValue');
	assert.ok(start >= 0 && end > start && sanitizerSource.indexOf('var scanTagToken') > start, 'scanTagToken is not found');
	return new Function(sanitizerSource.substring(start, end) + 'return scanTagToken;')();
})();

// Every sanitizer has its own cache of safe tokens
const createSanitizer = function(purify) {
	return new Function('DOMPurify', 'return ' + sanitizerSource.trim())(purify || DOMPurify);
};

// The input value is not rendered, the danger is a consumer rendering it as HTML in any context.
// All dangerous texts call alert, so other handlers and urls (e.g. onerror=</p from '<img onerror=' + '</p>')
// come from the consumer markup and are not under control of the user.
// DOMParser has scripting disabled, so <noscript> isn't raw text here, <xmp> and <noembed> check raw text contexts.
const parser = new window.DOMParser();
const liveXSSResults = new Map();
const findLiveXSS = function(html) {
	if (!liveXSSResults.has(html)) {
		liveXSSResults.set(html, findLiveXSSUncached(html));
	}

	return liveXSSResults.get(html);
};
const contexts = [
	'', '<svg>', '<math>', '<svg><foreignObject>', '<math><mi>', '<table>', '<select>', '<noscript>',
	'<textarea>', '<title>', '<xmp>', '<noembed>', '<noframes>', '<iframe>', '<style>', '<!--',
];
// Only its closing makes markup of the html in a raw text context or a comment, so other contexts are skipped
const contextClosings = {
	'<textarea>': /<\/textarea/i, '<title>': /<\/title/i, '<xmp>': /<\/xmp/i, '<noembed>': /<\/noembed/i,
	'<noframes>': /<\/noframes/i, '<iframe>': /<\/iframe/i, '<style>': /<\/style/i, '<!--': /--!?>/,
};
const isLiveElement = function(element) {
	const name = element.nodeName.toLowerCase();
	return name == 'script'
		|| (name == 'base' && element.hasAttribute('href'))
		|| (name == 'meta' && /refresh/i.test(element.getAttribute('http-equiv') || ''))
		|| (name == 'template' && Array.prototype.some.call(element.content.querySelectorAll('*'), isLiveElement))
		|| Array.prototype.some.call(element.attributes, function(attribute) {
			// Browsers ignore control chars and spaces in urls: ' jav\tascript:'
			const url = attribute.value.replace(/[\u0000-\u0020]/g, '');
			return /alert/.test(attribute.value)
				&& (/^on/i.test(attribute.name) || /^(javascript|vbscript|data):/i.test(url) || attribute.name.toLowerCase() == 'srcdoc');
		});
};
const findLiveXSSUncached = function(html) {
	return contexts.some(function(before) {
		if (contextClosings[before] && !contextClosings[before].test(html)) {
			return false;
		}

		return ['', '</p><b class="x">x</b>', "</p><b class='x'>x</b>"].some(function(after) {
			const document = parser.parseFromString('<!doctype html><body>' + before + html + after, 'text/html');
			return Array.prototype.some.call(document.querySelectorAll('*'), isLiveElement);
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
	'x<y & a>b <textarea>&lt;a onclick=x&gt;</textarea> <title>&lt;img onerror=x&gt;</title> 5 > 3 <br',
	'<td>cell</td> <option>one</option>',
	'<a href="https://example.com"',
	'<a href=https://example.com',
	'<xmp>plain</xmp> <noembed>x > y</noembed> <noframes>no frames</noframes>',
	// case, whitespace and self-closing tags
	'<B>bold</B> <BR> <Br/> <test/>',
	'<a\nhref="https://example.com"\n>x</a> <a\thref=\'https://example.com\'>y</a>',
	// things that only look like tags
	'<>', '</>', '< b>', '<1>', '<<>>', '<a <b>', 'a<b>c',
	'<john@example.com> <https://example.com>',
	'C<T> List<int> Map<K, V>',
	'<scripting> <svgfoo> <stylesheet> <iframes>',
	'&lt;script&gt;alert(1)&lt;/script&gt;',
	'<!doctype html> <?xml version="1.0"?>',
	'</textarea> </title> </xmp>',
	// attribute values
	'<a title="a > b">x</a> <a title=\'a "b" c\'>y</a>',
	'<a href="https://example.com/?a=1&b=2#c">x</a> <a href="mailto:a@b.c">y</a> <a href="#">z</a>',
	'<img src="https://example.com/a.png">',
	'<a href="https://example.com>link</a> forgot the quote',
	// unknown attributes with values safe as a link
	'<a ref="https://example.com/page">x</a> <b foo=bar data-x=1 hrf=#top>y</b>',
	'<ahref="https://example.com/page" title="The page">x</a>',
	// unicode
	'😀 <b>жирный</b> 😀 <ü>',
	// long unclosed tokens
	'<!-- ' + 'x'.repeat(1000),
	'<textarea>' + 'x'.repeat(1000),
	'<a title="' + 'x'.repeat(1000),
	// harmless markup inside comments and raw text elements
	'<!-- <b>note</b> --> <!<b> <!-- <!-- nested --> -->',
	'<title>A<B</title> <textarea><b>x</b></textarea>',
	'<!--</textarea><b>x</b>-->',
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
	'<!--</noembed><img src=x onerror=alert(1)>-->',
	'<!--><img src=x onerror=alert(1)>-->',
	'<a title="</textarea><img src=x onerror=alert(1)>">x</a>',
	'<a title=\'</textarea><img src=x onerror=alert(1)>\'>x</a>',
	'<textarea></textarea><img src=x onerror=alert(1)></textarea>',
	'<textarea><img src=x onerror=alert(1)></textarea>',
	'<textarea><img src=x onerror=alert(1)>',
	'<title><img src=x onerror=alert(1)></title>',
	'<noembed><img title="</noembed><img src onerror=alert(1)>"></noembed>',
	'<xmp><img src=x onerror=alert(1)></xmp>',
	'<xmp title=x>plain</xmp>',
	'<noframes><img src=x onerror=alert(1)></noframes>',
	'<img src=x onerror=alert(1)',
	'text <img src=x onerror=alert(1) more text',
	'<a href=javascript:alert(1)',
	'<textarea autofocus onfocus=alert(1)',
	// unclosed quotes are closed by the consumer markup
	'<img src=x onerror="alert(1)//',
	'<img src=x onerror=\'alert(1)//',
	'<img src=x onerror=alert(1) x="',
	'<img src=x onerror="alert(1)// <b>bold</b>',
	'<a href="javascript:alert(1)//',
	// case
	'<ScRiPt>alert(1)</sCrIpT>',
	'<IMG SRC=x ONERROR=alert(1)>',
	'<a href="JaVaScRiPt:alert(1)">x</a>',
	// separators
	'<img\nsrc=x\nonerror=alert(1)>',
	'<img\tsrc=x\tonerror=alert(1)>',
	'<img/onerror=alert(1)/src=x>',
	'<svg/onload=alert(1)>',
	'<img src="x"onerror="alert(1)">',
	'<img src=x onerror\n=\nalert(1)>',
	'<img src=x onerror = "alert(1)">',
	'<img src=x onerror=alert(1)/>',
	'<img src=x onerror="a>b;alert(1)">',
	'<a title="x" <img src=x onerror=alert(1)>',
	// encoded urls and handlers
	'<img src=x onerror=&#97;lert(1)>',
	'<img src=x onerror=`alert(1)`>',
	'<a href="&#106;avascript:alert(1)">x</a>',
	'<a href="javascript&colon;alert(1)">x</a>',
	'<a href="java\nscript:alert(1)">x</a>',
	'<a href=" javascript:alert(1)">x</a>',
	// elements handled by context
	'<body onload=alert(1)>',
	'<html onmouseover=alert(1)>',
	'<td><img src=x onerror=alert(1)></td>',
	'<option><img src=x onerror=alert(1)>',
	'<frameset onload=alert(1)>',
	// other elements and handlers
	'<input autofocus onfocus=alert(1)>',
	'<video><source onerror=alert(1)>',
	'<audio src=x onerror=alert(1)>',
	'<marquee onstart=alert(1)>',
	'<x-foo is=x onclick=alert(1)>',
	'<embed src=javascript:alert(1)>',
	'<form><input formaction=javascript:alert(1) type=submit>',
	// declarations, processing instructions and CDATA
	'<!doctype html><img src=x onerror=alert(1)>',
	'<?xml?><img src=x onerror=alert(1)>',
	'<![CDATA[<img src=x onerror=alert(1)>]]>',
	'<a title="</title><img src=x onerror=alert(1)>">',
	'<a title="--><img src=x onerror=alert(1)>">',
	// unknown attributes executable or with markup
	'<button formaction=javascript:alert(1)>x</button>',
	'<a hraf="javascript:alert(1)">x</a>',
	'<b foo="</title><img src=x onerror=alert(1)>">x</b>',
	'<b foo="--><img src=x onerror=alert(1)>">x</b>',
	'<set attributename=onmouseover to=alert(1)>',
	'<ahref="x" onclick=alert(1)>x</a>',
	'<ahref="x" title="javascript:alert(1)">x</a>',
	// dangerous markup nested in comments and raw text elements
	'<!-- <!-- </textarea><img src=x onerror=alert(1)> -->',
	'<title><b><img src=x onerror=alert(1)></b></title>',
	'<textarea><!--</textarea><img src=x onerror=alert(1)>--></textarea>',
	'<!' + '<!--'.repeat(10) + '<img src=x onerror=alert(1)>',
	// values closing containers in attributes dropped by the parser: of end tags and repeated ones
	'</x title="</textarea><img src=x onerror=alert(1)>">',
	'</x title="</title><img src=x onerror=alert(1)>">',
	'</x title="--><img src=x onerror=alert(1)>">',
	'<b a=1 a="</textarea><img src=x onerror=alert(1)>">x</b>',
	'<b title=x title="</textarea><img src=x onerror=alert(1)>">x</b>',
	'<textarea>x</textarea title="</textarea><img src=x onerror=alert(1)>">',
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

// Mentioned tags which change parsing of the text after them are sanitized like dangerous ones
test('texts mentioning dangerous tags are sanitized by DOMPurify', function() {
	const sanitize = createSanitizer();
	['Use <style> for CSS', 'e.g. <svg> icons', '<math> formula', '<template> literal', '<noscript> fallback'].forEach(function(text) {
		assert.strictEqual(sanitize(text), DOMPurify.sanitize(text), text);
	});
});

// Texts sanitized by DOMPurify must not stay sanitized on every change: '&lt;' in textarea is harmless
test('typing after a sanitized text keeps the typed text', function() {
	const sanitize = createSanitizer();
	dangerousTexts.forEach(function(text) {
		const result = sanitize(text);
		// Texts with dangerous tags are sanitized on every change by design
		if (/<\/?(?:script|iframe|frame|frameset|object|embed|applet|svg|math|link|style|meta|base|noscript|template)\b/i.test(result)) {
			return;
		}

		assert.strictEqual(sanitize(result + ' x<y <br'), result + ' x<y <br', text);
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

// Every prefix and every text with one char erased, as while typing and erasing
const edits = function(text) {
	const result = [];
	for (let i = 0; i <= text.length; i++) {
		result.push(text.substring(0, i));
		if (i < text.length) {
			result.push(text.substring(0, i) + text.substring(i + 1));
		}
	}

	return result;
};

test('erasing a char of harmless text keeps it', function() {
	const sanitize = createSanitizer();
	[
		'<br><br> **D** <br> E | F |',
		'See <b>it</b> is <i>fine</i>, x<y. <!-- note -->',
		// Erasing a char of 'https:' makes an unknown scheme, which DOMPurify doesn't allow in links
		'See <a href="/page" title="The page">the page</a>.',
	].forEach(function(text) {
		edits(text).forEach(function(edit) {
			assert.strictEqual(sanitize(edit), edit);
		});
	});
});

test('typing and erasing dangerous texts never leaves live XSS', function() {
	const sanitize = createSanitizer();
	dangerousTexts.forEach(function(text) {
		edits(text).forEach(function(edit) {
			assert.ok(!findLiveXSS(sanitize(edit)), JSON.stringify(edit));
		});
	});
});

test('sanitizing a result again keeps it', function() {
	harmlessTexts.concat(dangerousTexts).forEach(function(text) {
		const result = createSanitizer()(text);
		assert.strictEqual(createSanitizer()(result), result, text);
	});
});

test('cache does not change results', function() {
	const texts = harmlessTexts.concat(dangerousTexts);
	const expected = texts.map(function(text) { return createSanitizer()(text); });
	const sanitize = createSanitizer();
	[texts, texts.slice().reverse(), texts].forEach(function(order) {
		order.forEach(function(text) {
			assert.strictEqual(sanitize(text), expected[texts.indexOf(text)], text);
		});
	});

	// Overflow the cache bound with unique safe tokens
	for (let i = 0; i < 2; i++) {
		sanitize(Array.from({ length: 2100 }, function(_, j) { return '<a id="' + i + '-' + j + '-' + 'x'.repeat(220) + '">'; }).join(''));
	}

	texts.forEach(function(text, i) {
		assert.strictEqual(sanitize(text), expected[i], text);
	});
});

// Tokens are checked joined, but cached one by one, so safe tokens must stay safe next to any others
test('cached tokens of texts do not change results of joined texts', function() {
	const texts = harmlessTexts.filter(function(text) { return text.length < 100; });
	const others = texts.concat(dangerousTexts.slice(0, 20));
	texts.forEach(function(a) {
		const sanitize = createSanitizer();
		others.forEach(function(b) { sanitize(b); });
		others.forEach(function(b) {
			assert.strictEqual(sanitize(a + b), createSanitizer()(a + b), a + b);
		});
	});
});

// Tags of all combinations of the chars which change the tokenizer state are closed
// if the marker after them is text outside of attributes and raw text elements
test('closing of the last tag follows the HTML tokenizer', function() {
	const isClosed = function(html) {
		const body = parser.parseFromString('<!doctype html><body>' + html + 'Z', 'text/html').body;
		const walker = body.ownerDocument.createTreeWalker(body, 4);
		for (let node = walker.nextNode(); node; node = walker.nextNode()) {
			if (node.data.endsWith('Z')) {
				return !/^(TEXTAREA|TITLE|XMP|NOEMBED|NOFRAMES)$/.test(node.parentNode.nodeName);
			}
		}

		return false;
	};

	const check = function(chars, suffix, depth) {
		['<x', '</x'].forEach(function(prefix) {
			const tag = prefix + suffix;
			const closing = scanTagToken(tag).closing;
			assert.ok(isClosed(tag + closing), JSON.stringify(tag) + ' + ' + JSON.stringify(closing));
		});

		if (depth > 0) {
			chars.forEach(function(char) { check(chars, suffix + char, depth - 1); });
		}
	};

	check(['a', '=', '"', "'", ' ', '/', '>'], '', 5);
	check(['a', '=', '"', '\t', '\n', '>'], '', 3);
	[
		'<textarea>x</textarea', '<textarea>x</textarea a="', '<title>a</b>c</title b=\'', '<xmp a=">">x</xmp ',
		'<textarea>x</textarea a="</b', '<xmp>x</xmp a="</b c=\'', '<TEXTAREA>x</textarea a=\'',
	].forEach(function(token) {
		assert.ok(isClosed(token + scanTagToken(token).closing), token);
	});
});

test('safe tokens are checked once', function() {
	let checkedLength = 0;
	const countingPurify = {
		sanitize: function(text, config) {
			checkedLength += text.length;
			return DOMPurify.sanitize(text, config);
		},
		get removed() {
			return DOMPurify.removed;
		},
		isValidAttribute: function(tag, attribute, value) {
			return DOMPurify.isValidAttribute(tag, attribute, value);
		}
	};

	const sanitize = createSanitizer(countingPurify);
	[
		// Unique tags: the same tags in a text are checked once anyway
		Array.from({ length: 2000 }, function(_, i) { return '<p>Lorem <a href="https://example.com/' + i + '">dolor</a>.</p>\n'; }).join(''),
		// Long tokens are not cached, but kept for the next text
		Array.from({ length: 200 }, function(_, i) { return '<!-- ' + i + ' ' + 'x'.repeat(300) + ' --> <b>' + i + '</b> '; }).join(''),
		Array.from({ length: 200 }, function(_, i) { return '<textarea>' + i + ' ' + 'x'.repeat(300) + '</textarea> '; }).join(''),
	].forEach(function(text) {
		assert.strictEqual(sanitize(text), text);
		checkedLength = 0;
		assert.strictEqual(sanitize(text + ' x<y <b>'), text + ' x<y <b>');
		assert.ok(checkedLength < 100, String(checkedLength));
	});
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
		},
		isValidAttribute: function(tag, attribute, value) {
			return DOMPurify.isValidAttribute(tag, attribute, value);
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
		'unclosed quote': '<a title="' + '<b>x</b> '.repeat(n),
		'unclosed quotes': '<a title="x" b=\''.repeat(n),
	};

	Object.keys(texts).forEach(function(name) {
		const start = Date.now();
		sanitize(texts[name]);
		sanitize(texts[name] + 'x');
		const time = Date.now() - start;
		assert.ok(time < 5000, name + ': ' + time + ' ms');
	});
});
