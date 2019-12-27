typedef FontStyle = {
	family : String,
	weight : String,
	size : Float,
	style : String, 		// normal, italic,
	doNotRemap : Bool
}

// Singleton used to map flow fonts to css styles
class FlowFontStyle {
	private static var flowFontStyles : Dynamic;

	public static function fromFlowFonts(names : String) : FontStyle {
		flowFontStyles = null;
		var styles : Dynamic = null;

		for (name in names.split(",")) {
			var style = fromFlowFont(StringTools.trim(name));

			if (style != null) {
				if (styles == null) {
					styles = style;
				} else {
					styles.family += "," + style.family;
					if (styles.weight == "") styles.weight = style.weight;
					if (styles.size == 0.0) styles.style = style.style;
					if (styles.style == "") styles.style = style.style;
				}
			}
		}

		return styles;
	}

	private static var flowFontStylesJSON = haxe.Json.parse(haxe.Resource.getString("fontstyles"));

	public static function fromFlowFont(name : String) : FontStyle {
		if (flowFontStyles == null) {
			// Convert all flow font names to lowercase in order avoid case inconsistencies
			flowFontStyles = {};

			for (fontname in Reflect.fields(flowFontStylesJSON)) {
				Reflect.setField(flowFontStyles, fontname.toLowerCase(), Reflect.field(flowFontStylesJSON, fontname));
			}
		}

		var style : FontStyle = Reflect.field(flowFontStyles, name.toLowerCase());
		return (style != null) ? style : {family: name, weight: "", size: 0.0, style: "normal", doNotRemap : false};
	}
}