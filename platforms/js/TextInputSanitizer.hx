// Sanitizer of the text typed into text inputs with preventXSS enabled.
//
// The input value itself is not rendered as HTML, so we change the text only when it really contains
// something dangerous. Otherwise sanitizing would destroy harmless text the user is typing:
// e.g. while erasing '>' of '<br>' the unclosed '<br' swallows the rest of the text.
//
// 1. Dangerous tags (script, iframe, style, meta, ...) are always sanitized, even when only mentioned ('Use <style>'):
//    some of them change parsing of all the text after them (svg, math, noscript, template, style, ...).
// 2. Otherwise we split the text into HTML tokens (tags, comments, raw text elements) and ask DOMPurify
//    what it would remove from them. The text is dangerous if DOMPurify removes:
//    - an attribute with a value (onerror=..., href=javascript:..., etc.), except unknown attributes
//      with values safe as a link (e.g. 'ref' while editing 'href')
//    - a known element, except xmp, noembed and noframes without dangerous text inside and attribute values
//    - an unknown element with an attribute value (e.g. <test onclick=...>)
//    - a comment with dangerous text inside
//    The text is also dangerous if textarea or title contains dangerous text.
//    Plain comments, unknown tags and empty attributes ('<test>', 'x<y, a>b', '<br E | F |') are harmless.
//    A tag unclosed at the end of the text (e.g. by an unclosed quote) is checked closed by '>', '">' or "'>":
//    the parser drops it, but '>' or a quote rendered by a consumer after the text closes it.
//    Texts inside comments, textarea, title and other raw text elements become markup in other contexts
//    (after '</textarea>' in a comment, inside <svg>), so they are checked by the same rules.
//
// Texts can be huge, so only unique tokens are checked and short tokens found safe are cached:
// usually a keystroke checks only the tag being edited.
// The cache assumes the global DOMPurify config and hooks don't change after the first check.
// Tags which depend on the parser context (td, select, body, ...) are checked as <div>,
// DOMPurify checks attributes the same way for any element.
class TextInputSanitizer {
	// tests/js/text_input_sanitizer runs this code in Node, so it must stay a self-contained expression
	private static var sanitizeText : String -> String = untyped __js__("
		(function() {
			var safeTokens = new Set();
			var safeTokensLength = 0;

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
			var contextTagPattern = /^(<\\/?)(?:html|head|body|table|caption|colgroup|col|tbody|thead|tfoot|tr|td|th|select|option|optgroup|form)(?=[\\t\\n\\f\\r \\/>]|$)/i;
			var markupPattern = /<[\\/\\w!]/;
			// Tokens are prefixed by '<', so a checked end tag is cached with '>' prefix
			var endTagPrefix = '>';
			// DOMPurify removes these raw text elements together with their text
			var removedRawTextElements = ['XMP', 'NOEMBED', 'NOFRAMES'];

			// Browsers ignore unknown attributes (e.g. 'ref' while editing 'href'), but some of them are unknown to DOMPurify
			// and still executable (event handlers, formaction), so only values safe as a link and without markup are harmless
			var isHarmlessUnknownAttribute = function(attribute) {
				return !/^on/i.test(attribute.name)
					&& DOMPurify.isValidAttribute('a', 'href', attribute.value)
					&& !markupPattern.test(attribute.value);
			};

			// Returns what closes a tag token unclosed at the end of the text: '>', '\">', \"'>\" or '' if it is closed.
			// Follows the states of the HTML tokenizer: the tag is closed by '>' outside of attribute values.
			var getTagClosing = function(token) {
				var state = 'tagName';
				for (var i = token.charAt(1) == '/' ? 2 : 1; i < token.length; i++) {
					var char = token.charAt(i);
					var isSpace = ' \\t\\n\\f\\r'.indexOf(char) >= 0;

					if (state == 'doubleQuoted' || state == 'singleQuoted') {
						if (char == (state == 'doubleQuoted' ? '\"' : \"'\")) {
							state = 'afterQuoted';
						}
					} else if (char == '>') {
						// Raw text elements (<textarea>...</textarea) end with their closing tag, if there is one
						var closingTagStart = token.lastIndexOf('</');
						return i == token.length - 1 || closingTagStart <= i ? '' : getTagClosing(token.substring(closingTagStart));
					} else if (state == 'beforeValue') {
						state = isSpace ? state : char == '\"' ? 'doubleQuoted' : char == \"'\" ? 'singleQuoted' : 'unquoted';
					} else if (state == 'unquoted') {
						state = isSpace ? 'beforeName' : state;
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

				return state == 'doubleQuoted' ? '\">' : state == 'singleQuoted' ? \"'>\" : '>';
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

				// Textarea and title keep markup as text, but it becomes markup again in other contexts
				// (e.g. inside <svg>), so such texts are sanitized when they are dangerous
				var hasDangerousText = !!body && !!body.getElementsByTagName && ['textarea', 'title'].some(function(tagName) {
					return Array.prototype.some.call(body.getElementsByTagName(tagName), function(element) {
						return isDangerousText(element.textContent);
					});
				});

				return hasDangerousText || removedNodes.some(function(removed) {
					if (removed.attribute) {
						var isUnknownAttribute = !!removed.from
							&& !DOMPurify.isValidAttribute(removed.from.nodeName.toLowerCase(), removed.attribute.name, 'x');
						return removed.attribute.value != '' && !(isUnknownAttribute && isHarmlessUnknownAttribute(removed.attribute));
					}

					var element = removed.element;
					// Comments are not executed, but markup inside them may break out of raw text containers
					// (<!--</textarea><img onerror=...>-->), so comments with dangerous text are sanitized
					if (element.nodeType == 8) {
						return isDangerousText(element.data);
					}

					// BODY is the DOMPurify wrapper, removed only by its mXSS heuristics on plain text
					if (element.nodeType != 1 || element.nodeName == 'BODY') {
						return false;
					}

					// Raw text is harmless unless it becomes markup in other contexts, like in textarea and title
					if (removedRawTextElements.indexOf(element.nodeName) >= 0) {
						return hasAttributeValue(element.attributes) || isDangerousText(element.textContent);
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
				var newTokens = Array.from(new Set(tokens)).filter(function(token) {
					return !safeTokens.has(token);
				});

				// The parser drops a tag unclosed at the end of the text, but a consumer may render '>' or a quote after it
				// ('<img src=x onerror=\"alert(1)//' + '</p><b class=\"x\">'), so such a tag is checked closed.
				// It is cached separately: a token found safe elsewhere in a text isn't checked closed.
				var lastToken = tokens[tokens.length - 1];
				var endTagClosing = !!lastToken && tagPattern.test(lastToken) && text.slice(-lastToken.length) == lastToken
					? getTagClosing(lastToken) : '';
				var endTag = endTagClosing != '' && !safeTokens.has(endTagPrefix + lastToken) ? lastToken : null;

				if (newTokens.length == 0 && endTag == null) {
					return text;
				}

				// The closed end tag doesn't swallow the tokens after it, so it is checked together with them
				var checkedTokens = endTag == null ? newTokens : newTokens.filter(function(token) {
					return token != endTag;
				}).concat([endTag + endTagClosing]);

				var isXSS = hasDangerousTokens(checkedTokens);

				if (isXSS) {
					return DOMPurify.sanitize(text);
				}

				if (endTag != null) {
					newTokens.push(endTagPrefix + endTag);
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

					// Copy the token into a new flat string: a substring (sliced string in V8) keeps
					// a reference to the whole text and would keep it alive in memory
					var copy = token.split('').join('');
					safeTokens.add(copy);
					safeTokensLength += copy.length;
				});

				return text;
			};

			return sanitize;
		})()
	");

	public static function sanitize(text : String) : String {
		return sanitizeText(text);
	}
}
