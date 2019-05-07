import js.Browser;
import pixi.loaders.Loader;

import Platform;

class FontLoader {
	public static function loadWebFonts(onDone : Void -> Void) {
		if (untyped __typeof__(WebFont) != "undefined") {
			var webfontconfig : Dynamic = haxe.Json.parse(haxe.Resource.getString("webfontconfig"));
			if (webfontconfig != null && Reflect.fields(webfontconfig).length > 0) {
				webfontconfig.active = onDone;
				webfontconfig.inactive = onDone;
				webfontconfig.loading = function() {
					workaroundiOSWebFontLoading(webfontconfig);
					Errors.print("Loading web fonts...");
				};
				WebFont.load(webfontconfig);
			} else {
				onDone();
			}
		} else {
			Errors.print("WebFont is not defined");
			onDone();
		}
	}

	// On some iOS devices (especially old iPad)
	// We have to append text with described google families to body
	// Because browser starts load once it's used by the page
	private static function workaroundiOSWebFontLoading(config : Dynamic) {
		if (!Platform.isIOS) return;

		var fontList = Reflect.field(Reflect.field(config, "google"), "families");
		if (fontList == null)
			return;

		for (i in 0...fontList.length) {
			var font = untyped fontList[i];
			var parts : Array<String> = font.split(":");
			var family = parts[0];
			if (parts.length > 1) {
				var weights = parts[1].split(",");
				for (i in 0...weights.length)
					addStyledText(family, untyped weights[i]);
			} else {
				addStyledText(family);
			}
		}
	}

	private static function addStyledText(family : String, weight : String = "") {
		var text = Browser.document.createElement('span');
		text.innerText = "load the font";
		text.style.fontFamily = family;
		if (weight != "")
			text.style.fontWeight = weight;
		text.style.visibility = "hidden";
		Browser.document.body.appendChild(text);
	}
}