import js.Browser;
import pixi.loaders.Loader;

import Platform;

class FontLoader {
	private static var DFontVersionExpected : Int = 4;
	private static var DFonts : Map<String,Bool> = new Map();

	public static function hasDFont(fontfamily : String) : Bool {
		return DFonts.exists(fontfamily);
	}

	public static function LoadFonts(use_dfont : Bool, on_done : Void -> Void) {
		var done = 0;
		var onDone = function() {
			done++;
			if (done == 2)
				on_done();
		}

		// Refresh page and force reload of html file when DFont version is incompatible
		if (untyped PIXI.VERSION[0] > 3 && untyped window.DFONT_VERSION != DFontVersionExpected) {
			Browser.window.location.reload(true);
		}

		// Load the distance field fonts. Even if not using dfonts, we want to load the font
		// metrics (if embedded), in order to hint pixi's text rendering
		loadDFonts(onDone, use_dfont);

		// Web fonts should always be loaded, since they are used by the native widgets
		loadWebFonts(onDone);
	}

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

	// 'onDone' is called when we are finishing downloading all the fonts, including the textures.
	// If 'downloadTextures' is false, just set the embedded font metrics, which can be useful to hint
	// PIXI's text rendering with the correct metrics (instead of having them reverse engineering from
	// canvas renderings, which is what they do by default)
	public static function loadDFonts(onDone : Void -> Void, downloadTextures : Bool) {
		var dfonts : Array<Dynamic> = [];
		var uniqueDFonts : Array<Dynamic> = [];

		// Load the list of dfonts from a haxe resource. The resource string is encoded in json,
		// representing an array of {name: String, url: String} values. If the url is missing, we
		// assume "/dfonts/<name>/index.json".
		// A resource can be created with the --fontconfig-file option during js compilation,
		// or have the "fontconfig-file" variable set in the flow.config file (see Options.hx)
		var dfontsResource : String = haxe.Resource.getString("dfonts");
		if (dfontsResource != null) {
			dfonts = haxe.Json.parse(dfontsResource);
			if (dfonts.length == 0) {
				onDone();
				return;
			}

			for (dfont in dfonts) {
				if (dfont.url == null)
					Reflect.setField(dfont, "url", "dfontjs/" + dfont.name + "/index.json");
			}
		} else if (dfonts.length == 0) {
			Errors.print("Warning: No dfonts resource!");
			onDone();
			return;
		}

		// this fontnames override comes from a html page which loads PixiJS code
		// The fonts are added to the list of loaded fonts, unless the
		// js.Browser.window.dfonts_override variable is set
		var fontnamesStr : String = untyped js.Browser.window.dfontnames;
		if (fontnamesStr != null) {
			var fontnames : Array<String> = [for (fn in fontnamesStr.split("\n")) StringTools.trim(fn)];
			fontnames = fontnames.filter(function(s) { return s != ""; });
			var extraDFonts = [for (fn in fontnames) {name: fn, url: 'dfontjs/' + fn + '/index.json'}];
			dfonts = (untyped js.Browser.window.dfonts_override != null)? extraDFonts : dfonts.concat(extraDFonts);
		}

		// Make sure font names are unique
		var fontURLs : Map<String, String> = [for (f in dfonts) f.name => f.url];

		Errors.print("Loading dfield fonts...");

		// TODO: Pages 0 of the font textures should be put at the head of the download queue
		var loader = new Loader();
		var pending = false;

		DFonts = new Map<String,Bool>();
		for (name in fontURLs.keys()) {
			var embedded_dfont : String = haxe.Resource.getString(name);
			if (embedded_dfont != null) {
				// DFont index.json is embedded
				var dfont = haxe.Json.parse(embedded_dfont);
				if (dfont) {
					DFontTextNative.initDFontData(name, dfont);
				} else {
					Errors.print("Error parsing embedded dfont for " + name);
				}
			} else if (downloadTextures){
				// DFont index.json is NOT embedded, so download it
				pending = true;
				loader.add(name, fontURLs[name]);
			}
			DFonts[name] = true;
		}

		if (!downloadTextures) {
			onDone();
			return;
		}

		// Download the font textures
		var onLoaded : Void -> Void = function () {
			var texture_pages : Array<DFontTexturePage> = [];
			for (name in fontURLs.keys()) {
				var numPages = DFontTextNative.getNumPages(name);
				for (page in 0...numPages)
					texture_pages.push(new DFontTexturePage(name, page));
			}

			// Sort texture pages by page number since the first page typically contains the ASCII characters
			texture_pages.sort(function(p1 : DFontTexturePage, p2 : DFontTexturePage) {
				return p1.page - p2.page;
			});

			for (page in texture_pages) {
				DFontTextNative.addTexture2Loader(page.fontname, getDFontInfo(page.fontname), page.page, function() {
					untyped RenderSupportHx.InvalidateStage();
				}, loader);
			}

			loader.load();
			loader.once("complete", onDone);
		}

		if (pending) {
			loader.load();
			loader.once("complete", onLoaded);
		} else {
			onLoaded();
		}
	}

	// Returns the object from DFontText.dfont_table
	private static function getDFontInfo(fontfamily : String) : Dynamic {
		return untyped __js__ ("DFontText.dfont_table[fontfamily]");
	}
}