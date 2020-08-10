import js.Browser;
import pixi.loaders.Loader;

import Platform;

class FontLoader {
	private static var FontLoadingTimeout = 30000; //ms

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

		// 400italic, 400 - examples of valid strings to parse
		var wsReg = ~/([0-9]+)([A-Za-z]*)/;

		for (i in 0...fontList.length) {
			var font = untyped fontList[i];
			var parts : Array<String> = font.split(":");
			var family = parts[0];
			var testString = testStringsMap.get(family);
			if (parts.length > 1) {
				var styles = parts[1].split(",");
				for (j in 0...styles.length) {
					var weight = "", style = "";

					if (wsReg.match(styles[j])) {
						weight = wsReg.matched(1);
						style = wsReg.matched(2);
					}
					addStyledText(family, untyped weight, untyped style, testString);
				}
			} else {
				addStyledText(family, "", "", testString);
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
		Browser.document.body.appendChild(text);

		Native.timer(FontLoadingTimeout, function() {
			Browser.document.body.removeChild(text);
		});
	}
}