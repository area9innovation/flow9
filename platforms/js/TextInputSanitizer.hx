// Sanitizer of the text typed into text inputs with preventXSS enabled.
//
// The input value itself is not rendered as HTML, so we change the text only when it really contains
// something dangerous. Otherwise sanitizing would destroy harmless text the user is typing:
// e.g. while erasing '>' of '<br>' the unclosed '<br' swallows the rest of the text.
//
// 1. Dangerous tags (script, iframe, style, meta, ...) are always sanitized.
// 2. Otherwise we split the text into HTML tokens (tags, comments, raw text elements) and ask DOMPurify
//    what it would remove from them. The text is dangerous if DOMPurify removes:
//    - an attribute with a value (onerror=..., href=javascript:..., etc.)
//    - a known element
//    - an unknown element with an attribute value (e.g. <test onclick=...>)
//    - a comment with markup inside
//    The text is also dangerous if textarea or title contains markup.
//    Plain comments, unknown tags and empty attributes ('<test>', 'x<y, a>b', '<br E | F |') are harmless.
//
// Texts can be huge, so only unique tokens are checked and short tokens found safe are cached:
// usually a keystroke checks only the tag being edited.
// Tags which depend on the parser context (td, select, body, ...) are checked as <div>,
// DOMPurify checks attributes the same way for any element.
class TextInputSanitizer {
	// tests/js/text_input_sanitizer runs this code in Node, so it must stay a self-contained expression
	private static var sanitizeText : String -> String = untyped __js__("
		(function() {
			var safeTokens = new Set();
			var safeTokensLength = 0;

			return function(text) {
				if (!/<[a-zA-Z!\\/?]/.test(text)) {
					return text;
				}

				if (/<\\/?(?:script|iframe|frame|frameset|object|embed|applet|svg|math|link|style|meta|base|noscript|template)(?=[\\s\\/>]|$)/i.test(text)) {
					return DOMPurify.sanitize(text);
				}

				var space = '[\\\\t\\\\n\\\\f\\\\r ]';
				var tagEnd = '(?=[\\\\t\\\\n\\\\f\\\\r \\\\/>]|$)';
				var attributes =
					'(?:[\\\\t\\\\n\\\\f\\\\r \\\\/]+|[^\\\\t\\\\n\\\\f\\\\r \\\\/>][^\\\\t\\\\n\\\\f\\\\r \\\\/>=]*(?:' + space + '*=' + space + '*(?:\"[^\"]*\"|\\'[^\\']*\\'|[^\\\\t\\\\n\\\\f\\\\r >]*))?)*';
				var rawTextTag = function(name) {
					return '<' + name + tagEnd + attributes + '(?:>[^]*?(?:<\\\\/' + name + tagEnd + attributes + '>?|$))?';
				};
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
				var contextTagPattern = /^(<\\/?)(?:html|head|body|table|caption|colgroup|col|tbody|thead|tfoot|tr|td|th|select|option|optgroup|form)(?=[\\t\\n\\f\\r \\/>]|$)/i;

				// Tokens are cached as safe only after the check, so an exception can't leave them unchecked
				var newTokens = Array.from(new Set(text.match(tokenPattern) || [])).filter(function(token) {
					return !safeTokens.has(token);
				});

				if (newTokens.length == 0) {
					return text;
				}

				var hasAttributeValue = function(attributes) {
					for (var i = 0; i < attributes.length; i++) {
						if (attributes[i].value != '') {
							return true;
						}
					}

					return false;
				};

				var body = DOMPurify.sanitize(
					newTokens.map(function(token) { return token.replace(contextTagPattern, '$1div'); }).join(''),
					{ FORCE_BODY: true, RETURN_DOM: true }
				);

				// Textarea and title keep markup as text, but it becomes markup again in other contexts
				// (e.g. inside <svg>), so such texts are sanitized and DOMPurify escapes the markup
				var hasMarkupInText = !!body && !!body.getElementsByTagName && ['textarea', 'title'].some(function(tagName) {
					return Array.prototype.some.call(body.getElementsByTagName(tagName), function(element) {
						return /<[\\/\\w!]/.test(element.textContent);
					});
				});

				var isXSS = hasMarkupInText || DOMPurify.removed.some(function(removed) {
					if (removed.attribute) {
						return removed.attribute.value != '';
					}

					var element = removed.element;
					// Comments are not executed, but markup inside them may break out of raw text containers
					// (<!--</textarea><img onerror=...>-->), so such comments are sanitized like DOMPurify does
					if (element.nodeType == 8) {
						return /<[\\/\\w!]/.test(element.data);
					}

					// BODY is the DOMPurify wrapper, removed only by its mXSS heuristics on plain text
					if (element.nodeType != 1 || element.nodeName == 'BODY') {
						return false;
					}

					var isUnknownElement =
						Object.prototype.toString.call(element) == '[object HTMLUnknownElement]'
						|| element.nodeName.indexOf('-') > 0;

					return !isUnknownElement || hasAttributeValue(element.attributes);
				});

				if (isXSS) {
					return DOMPurify.sanitize(text);
				}

				if (safeTokensLength > 1000000) {
					safeTokens.clear();
					safeTokensLength = 0;
				}

				newTokens.forEach(function(token) {
					// Long tokens (unclosed comments, textarea, etc.) change with every keystroke, so they are not cached
					if (token.length > 256) {
						return;
					}

					// Copy the token: a substring may keep the whole text alive in memory
					var copy = token.split('').join('');
					safeTokens.add(copy);
					safeTokensLength += copy.length;
				});

				return text;
			};
		})()
	");

	public static function sanitize(text : String) : String {
		return sanitizeText(text);
	}
}
