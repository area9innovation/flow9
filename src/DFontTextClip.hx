using DisplayObjectHelper;

class DFontTextClip extends TextField {
	private static inline var FireFoxMaxTextWidth : Float = 32765.0;

	public override function setTextAndStyle(
		text : String, fontfamily : String,
	fontsize : Float, fontweight : Int, fontslope : String,
		fillcolor : Int, fillopacity : Float, letterspacing : Float,
		backgroundcolour : Int, backgroundopacity : Float
	) {
		if (Platform.isFirefox && text.length * fontsize > FireFoxMaxTextWidth /* raw estimate */) {
			text = text.substr(0, Math.floor(FireFoxMaxTextWidth / fontsize));
		}

		if (getDFontInfo(fontfamily) == null) {
			var defaultFontFamily = getFirstDFontFamily();
			var met = getDFontInfo(defaultFontFamily);
			if (met != null) {
				Errors.print("Trying to render DFont " + fontfamily + " which is not loaded. Will use default font");
				untyped __js__ ("DFontText.dfont_table[fontfamily] = met");
				fontfamily = defaultFontFamily;
			} else {
				Errors.print("Trying to render DFont " + fontfamily + " which is not loaded yet. Default font is not loaded yet too");
				return;
			}
		}

		metrics = getDFontInfo(fontfamily);

		style.font = fontsize + "px " + fontfamily;
		style.tint = fillcolor != 0 ? fillcolor : 0x010101;
		style.letterSpacing = letterspacing;

		super.setTextAndStyle(
			text, fontfamily, fontsize, fontweight, fontslope,
			fillcolor, fillopacity,
			letterspacing, backgroundcolour, backgroundopacity);
	}

	private override function makeTextClip(text : String, style : Dynamic) : Dynamic {
		var clip : Dynamic = new DFontTextNative(text, style);

		clip.resolution = RenderSupportJSPixi.PixiRenderer.resolution; // calculateBounds needs that
		clip.on("resize", function (ratio : Float) {
			clip.resolution = ratio;
		});

		clip.alpha = fillOpacity;

		if (TextField.cacheTextsAsBitmap) {
			clip.cacheAsBitmap = true;
		}

		return clip;
	}

	private override function getTextClipMetrics(clip : Dynamic) : Dynamic {
		return clip.getTextDimensions();
	}

	public override function getTextMetrics() : Array<Float> {
		if (metrics == null) {
			return super.getTextMetrics();
		} else {
			// First value is baseline. See pixi-dfont.js for more details.
			return [(metrics.line_height + metrics.descender) * fontSize, metrics.descender * fontSize, 0.15 * fontSize];
		}
	}

	public override function getWidth() : Float {
		return (fieldWidth > 0.0 && isInput()) ? fieldWidth : clipWidth;
	}

	public override function getHeight() : Float {
		return (fieldHeight > 0.0 && isInput()) ? fieldHeight : clipHeight;
	}

	// Returns the object from DFontText.dfont_table
	public static function getDFontInfo(fontfamily : String) : Dynamic {
		return untyped __js__ ('DFontText.dfont_table[{0}]', fontfamily);
	}

	// Returns the object from DFontText.dfont_table
	public static function getFirstDFontFamily() : String {
		return untyped __js__ ("Object.keys(DFontText.dfont_table)[0]");
	}
}