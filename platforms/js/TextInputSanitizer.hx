// Sanitizer of the text typed into text inputs with preventXSS enabled.
//
// The input value itself is not rendered as HTML, so we change the text only when it really contains
// something dangerous. Otherwise sanitizing would destroy harmless text the user is typing:
// e.g. while erasing '>' of '<br>' the unclosed '<br' swallows the rest of the text.
//
// 1. Texts with dangerous tags (script, iframe, style, meta, ...) are passed to DOMPurify, even when the tags are only
//    mentioned ('Use <style>'): some of them change parsing of all the text after them (svg, math, noscript, style, ...).
//    DOMPurify may keep such tags (<svg></svg>), so such texts stay sanitized by DOMPurify on every change.
// 2. Otherwise we split the text into HTML tokens (tags, comments, raw text elements) and ask DOMPurify
//    what it would remove from them. The text is dangerous if DOMPurify removes:
//    - an attribute with a value (onerror=..., href=javascript:..., etc.), except unknown attributes
//      with values safe as a link (e.g. 'ref' while editing 'href')
//    - a known element, except xmp, noembed and noframes without attribute values
//    - an unknown element with an attribute value (e.g. <test onclick=...>), except names which can't be elements
//      in any context ('<ahref="..."' while erasing a space), checked like unknown attributes
//    - a comment with dangerous text inside
//    DOMPurify also removes id and name values clobbering DOM properties (<a name=action>), so such texts are sanitized.
//    The text is also dangerous if:
//    - textarea, title, xmp, noembed or noframes contains dangerous text: it becomes markup in other contexts
//      (inside <svg>), like texts of comments after '</textarea>' in a comment
//    - an attribute value closes a comment or a raw text element ('-->', '</textarea'): the parser drops attributes
//      of end tags and repeated attributes, so DOMPurify doesn't see them, but they break out of consumer containers
//    Plain comments, unknown tags and empty attributes ('<test>', 'x<y, a>b', '<br E | F |') are harmless.
//    A tag unclosed at the end of the text (e.g. by an unclosed quote) is checked closed by '>', '">' or "'>":
//    the parser drops it, but '>' or a quote rendered by a consumer after the text closes it.
//
// Texts can be huge, so only unique tokens are checked and short tokens found safe are cached:
// usually a keystroke checks only the tag being edited. Long tokens are kept only for the next text.
// The cache assumes the global DOMPurify config and hooks don't change after the first check.
// Tags which depend on the parser context (td, select, body, ...) are checked as <div>,
// DOMPurify checks attributes the same way for any element.
class TextInputSanitizer {
	// tests/js/text_input_sanitizer runs this code in Node, so it must stay a self-contained expression
	private static var sanitizeText : String -> String = untyped __js__("
		(function() {
			var safeTokens = new Set();
			var safeTokensLength = 0;
			// Long tokens aren't cached as they change while edited, so only the long tokens of the last text are kept.
			// They are substrings of the last text and keep only it in memory.
			var lastLongSafeTokens = new Set();

			var dangerousTagPattern = /<\\/?(?:script|iframe|frame|frameset|object|embed|applet|svg|math|link|style|meta|base|noscript|template)(?=[\\s\\/>]|$)/i;
			var space = '[\\\\t\\\\n\\\\f\\\\r ]';
			var tagEnd = '(?=[\\\\t\\\\n\\\\f\\\\r \\\\/>]|$)';
			var attributes =
				'(?:[\\\\t\\\\n\\\\f\\\\r \\\\/]+|[^\\\\t\\\\n\\\\f\\\\r \\\\/>][^\\\\t\\\\n\\\\f\\\\r \\\\/>=]*(?:' + space + '*=' + space + '*(?:\"[^\"]*(?:\"|$)|\\'[^\\']*(?:\\'|$)|[^\\\\t\\\\n\\\\f\\\\r >]*))?)*';
			var rawTextTag = function(name) {
				return '<' + name + tagEnd + attributes + '(?:>[^]*?(?:<\\\\/' + name + tagEnd + attributes + '>?|$))?';
			};
			// A tag token in plain JS regex syntax, where S is [\\t\\n\\f\\r ]:
			// </?[a-zA-Z][^S/>]*(?:[S/]+|[^S/>][^S/>=]*(?:S*=S*(?:\"[^\"]*(?:\"|$)|'[^']*(?:'|$)|[^S>]*))?)*>?
			var tokenPattern = new RegExp(
				[
					'<!--(?:-?>|[^]*?(?:--!?>|$))',
					'<(?:!|\\\\?|\\\\/(?![a-zA-Z]))[^>]*>?',
					'<plaintext' + tagEnd + '[^]*'
				]
				.concat(['textarea', 'title', 'xmp', 'noembed', 'noframes'].map(rawTextTag))
				.concat(['<\\\\/?[a-zA-Z][^\\\\t\\\\n\\\\f\\\\r \\\\/>]*' + attributes + '>?'])
				.join('|'),
				'gi'
			);
			var tagPattern = /^<\\/?[a-zA-Z]/;
			var rawTextTagPattern = /^<(textarea|title|xmp|noembed|noframes)(?=[\\t\\n\\f\\r \\/>]|$)/i;
			var contextTagPattern = /^(<\\/?)(?:html|head|body|table|caption|colgroup|col|tbody|thead|tfoot|tr|td|th|select|option|optgroup|form)(?=[\\t\\n\\f\\r \\/>]|$)/i;
			var markupPattern = /<[\\/\\w!]/;
			// Values closing comments and raw text elements, which DOMPurify removes from attributes
			var closingValuePattern = /((--!?|])>)|<\\/(style|script|title|xmp|textarea|noscript|iframe|noembed|noframes)/i;
			// DOMPurify removes these raw text elements together with their text
			var removedRawTextElements = ['XMP', 'NOEMBED', 'NOFRAMES'];

			// Browsers ignore unknown attributes (e.g. 'ref' while editing 'href'), but some of them are unknown to DOMPurify
			// and still executable (event handlers, formaction), so only values safe as a link and without markup are harmless
			var isHarmlessUnknownAttribute = function(attribute) {
				return !/^on/i.test(attribute.name)
					&& DOMPurify.isValidAttribute('a', 'href', attribute.value)
					&& !markupPattern.test(attribute.value);
			};

			// Scans the tag starting at the index, following the states of the HTML tokenizer. Returns:
			// - end: the index of '>' closing the tag outside of attribute values, or -1
			// - closing: what closes the tag if it is unclosed: '>', '\">' or \"'>\"
			// - hasClosingValue: if an attribute value closes a comment or a raw text element ('-->', '</textarea').
			//   The parser drops attributes of end tags and repeated ones, so DOMPurify can't remove such values,
			//   but they break out of comments and raw text elements of a consumer.
			var scanTag = function(text, start) {
				var state = 'tagName';
				var valueStart = -1;
				var hasClosingValue = false;
				var endValue = function(end) {
					hasClosingValue = hasClosingValue || valueStart >= 0 && closingValuePattern.test(text.substring(valueStart, end));
					valueStart = -1;
				};

				for (var i = start + (text.charAt(start + 1) == '/' ? 2 : 1); i < text.length; i++) {
					var char = text.charAt(i);
					var isSpace = ' \\t\\n\\f\\r'.indexOf(char) >= 0;

					if (state == 'doubleQuoted' || state == 'singleQuoted') {
						if (char == (state == 'doubleQuoted' ? '\"' : \"'\")) {
							endValue(i);
							state = 'afterQuoted';
						}
					} else if (char == '>') {
						endValue(i);
						return { end: i, closing: '', hasClosingValue: hasClosingValue };
					} else if (state == 'beforeValue') {
						if (!isSpace) {
							state = char == '\"' ? 'doubleQuoted' : char == \"'\" ? 'singleQuoted' : 'unquoted';
							valueStart = state == 'unquoted' ? i : i + 1;
						}
					} else if (state == 'unquoted') {
						if (isSpace) {
							endValue(i);
							state = 'beforeName';
						}
					} else if (isSpace) {
						state = state == 'attributeName' || state == 'afterName' ? 'afterName' : 'beforeName';
					} else if (char == '/') {
						state = 'beforeName';
					} else if (char == '=' && (state == 'attributeName' || state == 'afterName')) {
						state = 'beforeValue';
					} else if (state != 'tagName') {
						state = 'attributeName';
					}
				}

				endValue(text.length);
				return {
					end: -1,
					closing: state == 'doubleQuoted' ? '\">' : state == 'singleQuoted' ? \"'>\" : '>',
					hasClosingValue: hasClosingValue
				};
			};

			// Scans a tag token, raw text elements (<textarea>...</textarea>) with their text and closing tag.
			// Returns the closing of the token, if an attribute value closes a container, and the raw text.
			var scanTagToken = function(token) {
				var startTag = scanTag(token, 0);
				var rawTextTag = startTag.end >= 0 ? rawTextTagPattern.exec(token) : null;
				if (rawTextTag == null) {
					return { closing: startTag.closing, hasClosingValue: startTag.hasClosingValue, text: null };
				}

				// The first closing tag ends the raw text, like in the token pattern
				var closingTagPattern = new RegExp('<\\\\/' + rawTextTag[1] + '(?=[\\\\t\\\\n\\\\f\\\\r \\\\/>]|$)', 'gi');
				closingTagPattern.lastIndex = startTag.end + 1;
				var closingTagMatch = closingTagPattern.exec(token);
				if (closingTagMatch == null) {
					return { closing: '', hasClosingValue: startTag.hasClosingValue, text: token.substring(startTag.end + 1) };
				}

				var closingTag = scanTag(token, closingTagMatch.index);
				return {
					closing: closingTag.closing,
					hasClosingValue: startTag.hasClosingValue || closingTag.hasClosingValue,
					text: token.substring(startTag.end + 1, closingTagMatch.index)
				};
			};

			var hasAttributeValue = function(attributes, isHarmless) {
				for (var i = 0; i < attributes.length; i++) {
					if (attributes[i].value != '' && !(isHarmless && isHarmless(attributes[i]))) {
						return true;
					}
				}

				return false;
			};

			// Texts inside comments and raw text elements may be nested ('<!--<!--<!--...'), so deep ones with markup
			// are dangerous without the check to keep the time linear
			var textDepth = 0;
			var isDangerousText = function(text) {
				if (!markupPattern.test(text)) {
					return false;
				}

				if (textDepth >= 2) {
					return true;
				}

				textDepth++;
				try {
					return sanitize(text) != text;
				} finally {
					textDepth--;
				}
			};

			// Checks if DOMPurify removes something dangerous from the tokens
			var hasDangerousTokens = function(tokens) {
				var body = DOMPurify.sanitize(
					tokens.map(function(token) { return token.replace(contextTagPattern, '$1div'); }).join(''),
					{ FORCE_BODY: true, RETURN_DOM: true }
				);
				// Recursive checks call DOMPurify again, which resets DOMPurify.removed
				var removedNodes = DOMPurify.removed;

				// DOMPurify ignores the config after DOMPurify.setConfig, so its results can't be trusted
				if (!body || body.nodeType != 1) {
					return true;
				}

				return removedNodes.some(function(removed) {
					if ('attribute' in removed) {
						// DOMPurify failed to get the attribute node
						if (!removed.attribute) {
							return true;
						}

						var isUnknownAttribute = !!removed.from
							&& !DOMPurify.isValidAttribute(removed.from.nodeName.toLowerCase(), removed.attribute.name, 'x');
						return removed.attribute.value != '' && !(isUnknownAttribute && isHarmlessUnknownAttribute(removed.attribute));
					}

					var element = removed.element;
					if (!element) {
						return true;
					}

					// Comments are not executed, but markup inside them may break out of raw text containers
					// (<!--</textarea><img onerror=...>-->), so comments with dangerous text are sanitized
					if (element.nodeType == 8) {
						return isDangerousText(element.data);
					}

					// BODY is the DOMPurify wrapper, removed only by its mXSS heuristics on plain text.
					// FORCE_BODY adds an empty <remove> element, which is harmless as an unknown element without attributes.
					if (element.nodeType != 1 || element.nodeName == 'BODY') {
						return false;
					}

					// Their raw text is checked with the tokens
					if (removedRawTextElements.indexOf(element.nodeName) >= 0) {
						return hasAttributeValue(element.attributes);
					}

					var isUnknownElement =
						Object.prototype.toString.call(element) == '[object HTMLUnknownElement]'
						|| element.nodeName.indexOf('-') > 0;

					// Unknown elements may be known in other contexts (e.g. <set> inside <svg>), so their attributes are dangerous,
					// unless the name can't be an element at all, like '<ahref=\"https:' while erasing a space of '<a href=\"https:'
					var isElementName = /^[a-z][a-z0-9-]*$/i.test(element.nodeName);
					return !isUnknownElement || hasAttributeValue(element.attributes, isElementName ? null : isHarmlessUnknownAttribute);
				});
			};

			var sanitize = function(text) {
				if (!/<[a-zA-Z!\\/?]/.test(text)) {
					return text;
				}

				if (dangerousTagPattern.test(text)) {
					return DOMPurify.sanitize(text);
				}

				// Tokens are cached as safe only after the check, so an exception can't leave them unchecked
				var tokens = text.match(tokenPattern) || [];
				var longSafeTokens = new Set();
				var newTokens = Array.from(new Set(tokens)).filter(function(token) {
					if (lastLongSafeTokens.has(token)) {
						longSafeTokens.add(token);
						return false;
					}

					return !safeTokens.has(token);
				});

				var isXSS = false;
				var checkedTokens = newTokens.map(function(token) {
					if (!tagPattern.test(token)) {
						return token;
					}

					var tagToken = scanTagToken(token);
					// Textarea, title and other raw text elements keep markup as text, but it becomes markup again
					// in other contexts (e.g. inside <svg>). The text is checked before entities are decoded:
					// '&lt;' never becomes markup.
					isXSS = isXSS || tagToken.hasClosingValue || tagToken.text != null && isDangerousText(tagToken.text);

					// The parser drops a tag unclosed at the end of the text, but '>' or a quote rendered by a consumer
					// after the text closes it ('<img src=x onerror=\"alert(1)//' + '</p><b class=\"x\">'), so it is checked closed.
					// Only the last token can be unclosed, it runs to the end of the text, so it can be cached as checked closed.
					return token + tagToken.closing;
				});

				isXSS = isXSS || newTokens.length > 0 && hasDangerousTokens(checkedTokens);

				if (isXSS) {
					return DOMPurify.sanitize(text);
				}

				if (safeTokensLength > 1000000) {
					safeTokens.clear();
					safeTokensLength = 0;
				}

				newTokens.forEach(function(token) {
					// Long tokens (unclosed comments, textarea, etc.) change while edited, so they are kept only for the next text
					if (token.length > 256) {
						longSafeTokens.add(token);
						return;
					}

					// Copy the token into a new flat string: a substring (sliced string in V8) keeps
					// a reference to the whole text and would keep it alive in memory
					var copy = token.split('').join('');
					safeTokens.add(copy);
					safeTokensLength += copy.length;
				});

				// Texts checked inside other texts don't replace the long tokens of the text
				if (textDepth == 0) {
					lastLongSafeTokens = longSafeTokens;
				}

				return text;
			};

			return sanitize;
		})()
	");

	public static function sanitize(text : String) : String {
		return sanitizeText(text);
	}
}
