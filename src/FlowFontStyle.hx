typedef FontStyle = {
	family : String,
	weight : String,
	size : Float,
	style : String 		// normal, italic
}

// Singleton used to map flow fonts to css styles
class FlowFontStyle {
	private static var flowFontStyles : Dynamic;

	public static function fromFlowFonts(names : String) : FontStyle {
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

	public static function fromFlowFont(name : String) : FontStyle {
		if (flowFontStyles == null) {
			// Convert all flow font names to lowercase in order avoid case inconsistencies
			var styles = haxe.Json.parse(haxe.Resource.getString("fontstyles"));
			flowFontStyles = {};

			for (fontname in Reflect.fields(styles)) {
				Reflect.setField(flowFontStyles, fontname.toLowerCase(), Reflect.field(styles, fontname));
			}
		}

		var style : FontStyle = Reflect.field(flowFontStyles, name.toLowerCase());
		return (style != null) ? style : {family: name, weight: "", size: 0.0, style: "normal"};
	}
}