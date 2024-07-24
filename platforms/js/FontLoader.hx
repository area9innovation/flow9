import js.Browser;
import pixi.loaders.Loader;

import Platform;

class FontLoader {
	private static var FontLoadingTimeout = 30000; //ms
	private static var loadedFonts = [];

	// Parse css rules from a stylesheet and preload fonts
	private static function loadFontsFromStylesheet(name: String) {
		var fontFamilies = [];
		untyped Array.from(Browser.document.styleSheets).forEach(function(sheet) {
			try {
				if (sheet.href != null && sheet.href.includes(name)) {
					var rules = sheet.cssRules || sheet.rules; // cssRules for standard browsers, rules for IE
					untyped Array.from(rules).forEach(function(rule) {
						var regex = ~/font-family:\s*(['"]?)([^'";]+)\1;/g;
						var match;
						var cssText = rule.cssText;

						while (regex.match(cssText)) {
							cssText = regex.matchedRight();
							var family = regex.matched(2);
							if (fontFamilies.indexOf(family) < 0) {
								fontFamilies.push(family);
								addStyledTexts(family, null, null);
							}
						}
					});
				}
			} catch (e) {
				untyped console.error("Could not access CSS rules from a stylesheet.", e);
			}
		});
		return fontFamilies;
	}

	public static function loadPreconfiguredWebFonts(names : Array<String>, onDone : Void -> Void) {
		var config : Dynamic = haxe.Json.parse(haxe.Resource.getString("webfontconfig"));
		var fontFields = ["google", "custom"];
		for (i in 0...names.length) untyped loadCSSFileInternal("fonts/"+names[i]+"/def.css", function() {
			loadFontsFromStylesheet("fonts/"+names[i]+"/def.css");
		});

		for (i in 0...fontFields.length) {
			var fontFieldsConfig = Reflect.field(config, fontFields[i]);
			var fonts = Reflect.field(fontFieldsConfig, "families");
			if (fonts != null) for (j in 0...fonts.length) {
				var font = untyped fonts[j];
				var parts : Array<String> = font.split(":");
				var family = parts[0];
				var testString : String = null;
				if (names.indexOf(family) >= 0) {
					var testStrings = Reflect.field(fontFieldsConfig, "testStrings");
					if (testStrings != null) {
						testString = Reflect.field(testStrings, family);
						if (testString == null) testString = "русский العصور english";
					}
					addStyledTexts(family, parts.length > 1? parts[1] : null, testString);
				}
			}
		}
		untyped __js__("setTimeout(onDone, 25)");
	}

	public static function loadFSFont(family : String, url : String) {
		addFontFace(family, url);
		addStyledText(family);
	}

	public static function loadWebFonts(onDone : Void -> Void) {
		if (HaxeRuntime.typeof(WebFont) != "undefined") {
			var webfontconfig : Dynamic = haxe.Json.parse(haxe.Resource.getString("webfontconfig"));
			if (webfontconfig != null && Reflect.fields(webfontconfig).length > 0) {
				webfontconfig.active = onDone;
				webfontconfig.inactive = onDone;
				webfontconfig.loading = function() {
					workaroundWebFontLoading(webfontconfig);
					Errors.print("Loading web fonts...");
				};
				WebFont.load(webfontconfig);
			} else {
				untyped __js__("setTimeout(onDone, 25)");
			}
			return webfontconfig;
		} else {
			Errors.print("WebFont is not defined");
			untyped __js__("setTimeout(onDone, 25)");
			return untyped {};
		}
	}

	// On some iOS devices (especially old iPad)
	// We have to append text with described google families to body
	// Because browser starts load once it's used by the page
	private static function workaroundWebFontLoading(config : Dynamic) {
		var fontFields = ["google", "custom"];
		var fontList = [];
		var testStringsMap : Map<String, String> = [""=>""];

		for (i in 0...fontFields.length) {
			var fontFieldsConfig = Reflect.field(config, fontFields[i]);
			var fonts = Reflect.field(fontFieldsConfig, "families");
			if (fonts != null) fontList = fontList.concat(fonts);

			var testStrings = Reflect.field(fontFieldsConfig, "testStrings");
			if (testStrings != null) {
				for (family in Reflect.fields(testStrings)) {
					testStringsMap.set(family, Reflect.field(testStrings, family));
				}
			}
		}

		for (i in 0...fontList.length) {
			var font = untyped fontList[i];
			var parts : Array<String> = font.split(":");
			var family = parts[0];
			var testString = testStringsMap.get(family);
			addStyledTexts(family, parts.length > 1? parts[1] : null);
		}
	}

	// 400italic, 400 - examples of valid strings to parse
	private static var wsReg = ~/([0-9]+)([A-Za-z]*)/;

	private static function addStyledTexts(family : String, facesStr : String, testString : String = "") {
		if (facesStr == null) {
			addStyledText(family, "", "", testString);
		} else {
			var styles = facesStr.split(",");
			for (j in 0...styles.length) {
				var weight = "", style = "";

				if (wsReg.match(styles[j])) {
					weight = wsReg.matched(1);
					style = wsReg.matched(2);
				}
				addStyledText(family, untyped weight, untyped style, testString);
			}

		}
	}

	private static function addStyledText(family : String, weight : String = "", style : String = "", testString : String = "") {
		var text = Browser.document.createElement('span');
		text.innerText = "Loading font '" + family + "' [" + testString + "]...";
		text.style.fontFamily = family;
		if (weight != "") text.style.fontWeight = weight;
		if (style != "") text.style.fontStyle = style;
		text.style.visibility = "hidden";
		text.style.position = "fixed";
		Browser.document.body.appendChild(text);

		Native.timer(FontLoadingTimeout, function() {
			Browser.document.body.removeChild(text);
		});
	}

	private static function addFontFace(family : String, url : String) {
		var css = "@font-face {	font-family: " + family + "; src: url(" + url + "); }";
		var style = Browser.document.createElement('style');
		style.appendChild(Browser.document.createTextNode(css));
		Browser.document.head.appendChild(style);
	}

	public static function onFontsLoadingDone(event : Dynamic) {
		if (event.fontfaces != null) {
			FontLoader.loadedFonts = FontLoader.loadedFonts.concat(event.fontfaces.map(function(font) {
				return font.family;
			}));
		}
	}

	public static function isFontLoaded(fontname : String) : Bool {
		return FontLoader.loadedFonts.contains(fontname);
	}
}