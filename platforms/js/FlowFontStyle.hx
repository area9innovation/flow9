typedef FontStyle = {
	family : String,
	weight : String,
	size : Float,
	style : String, 		// normal, italic,
	doNotRemap : Bool
}

// Singleton used to map flow fonts to css styles
class FlowFontStyle {
	private static var flowFontStyles : Map<String, Dynamic>;

	public static function fromFlowFonts(names : String) : FontStyle {
		var styles : Dynamic = null;

		for (name in names.split(",")) {
			var style = fromFlowFont(StringTools.replace(StringTools.trim(name), "'", ""));

			if (style != null) {
				if (styles == null) {
					styles = Reflect.copy(style);
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


	public static function fromFlowFont(name : String) : FontStyle {
		if (flowFontStyles == null) {
			// Convert all flow font names to lowercase in order avoid case inconsistencies
			flowFontStyles = new Map<String, Dynamic>();
			var styles = haxe.Json.parse(haxe.Resource.getString("fontstyles"));

			for (fontname in Reflect.fields(styles)) {
				flowFontStyles.set(fontname.toLowerCase(), Reflect.field(styles, fontname));
			}
		}

		var style : FontStyle = flowFontStyles.get(name.toLowerCase());
		return (style != null) ? style : {family: name, weight: "", size: 0.0, style: "normal", doNotRemap : false};
	}
}