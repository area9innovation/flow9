import js.Browser;
import js.html.MouseEvent;
import js.html.Event;
import pixi.core.text.Text in PixiCoreText;
import pixi.core.text.TextMetrics;
import pixi.core.text.TextStyle;
import pixi.core.math.shapes.Rectangle;
import pixi.core.math.Point;

import FlowFontStyle;

using DisplayObjectHelper;

class Text extends PixiCoreText {
	public var charIdx : Int = 0;
	public var orgCharIdxStart : Int = 0;
	public var orgCharIdxEnd : Int = 0;
	public var difPositionMapping : Array<Int>;
}

class TextMappedModification {
	public var modified: String;
	public var difPositionMapping : Array<Int>;
	public function new(modified: String, difPositionMapping: Array<Int>) {
		this.modified = modified;
		this.difPositionMapping = difPositionMapping;
	}
}

class UnicodeTranslation {
	public var rangeStart : Int;
	public var rangeContentFlags : Int;
	static var map : Map<String, UnicodeTranslation> = new Map<String, UnicodeTranslation>();

	public function new(rangeStart, rangeContentFlags) {
		this.rangeStart = rangeStart;
		this.rangeContentFlags = rangeContentFlags;
	}

	static public function getCharAvailableVariants(chr: String): Int {
		var unit = map.get(chr);
		if (unit == null) return 1;
		return unit.rangeContentFlags;
	}

	static public function getCharVariant(chr: String, gv: Int): String {
		var found = "";
		for (found in map) break;
		if (found != "") {
			var rangeStart : Int = 0xFE81;
			var flags : Int = 0x1FE1F50;
			for (i in 0x622...0x63B) {
				var is4range: Int = flags & 1;
				flags = flags >> 1;
				map[String.fromCharCode(i)] = new UnicodeTranslation(rangeStart, 3 + 12*is4range);
				rangeStart += 2 + is4range*2;
			}
			flags = 0x27F;
			for (i in 0x641...0x64B) {
				var is4range: Int = flags & 1;
				flags = flags >> 1;
				map[String.fromCharCode(i)] = new UnicodeTranslation(rangeStart, 3 + 12*is4range);
				rangeStart += 2 + is4range*2;
			}
			for (i in 0...4) {
				map[String.fromCharCode(rangeStart)] = new UnicodeTranslation(rangeStart, 3);
				rangeStart += 2;
			}
		}
		var unit = map[chr];
		if (unit == null) return chr;
		var tr_gv = unit.rangeContentFlags;
		if (0==((tr_gv >> gv) & 1)) gv &= -3;
		if (0==((tr_gv >> gv) & 1)) gv &= -2;
		return String.fromCharCode(unit.rangeStart + gv);
	}
}

class TextClip extends NativeWidgetClip {
	private var text : String = '';
	private var backgroundColor : Int = 0;
	private var backgroundOpacity : Float = 0.0;
	private var cursorColor : Int = -1;
	private var cursorOpacity : Float = -1.0;
	private var cursorWidth : Float = 2;
	private var textDirection : String = 'ltr';
	private var style : TextStyle = new TextStyle();

	private var type : String = 'text';
	private var autocomplete : String = '';
	private var step : Float = 1.0;
	private var wordWrap : Bool = false;
	private var cropWords : Bool = false;
	private var interlineSpacing : Float = 0.0;
	private var autoAlign : String = 'AutoAlignNone';
	private var readOnly : Bool = false;
	private var maxChars : Int = -1;

	private var cursorPosition : Int = -1;
	private var selectionStart : Int = -1;
	private var selectionEnd : Int = -1;

	private var background : FlowGraphics = null;

	private var metrics : TextMetrics;
	private var fontMetrics : Dynamic;
	private var multiline : Bool = false;

	private var TextInputFilters : Array<String -> String> = new Array();
	private var TextInputKeyDownFilters : Array<String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool> = new Array();
	private var TextInputKeyUpFilters : Array<String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool> = new Array();

	private var textClip : Text = null;
	private var textClipChanged : Bool = false;

	private var isInput : Bool = false;
	private var isFocused : Bool = false;

	public static function isRtlChar(ch: String) {
		var code = ch.charCodeAt(0);
		return (code >= 0x590 && code < 0x900)
			|| (code >= 0xFB1D && code < 0xFDD0)
			|| (code >= 0xFDF0 && code < 0xFE00)
			|| (code >= 0xFE70 && code < 0xFF00)
			// TODO treat also UCS-2 misencoded characters
			/*|| (code >= 0x10800 && code < 0x11000)
			|| (code >= 0x1E800 && code < 0x1F000)*/;
	}

	public static function isLtrChar(ch: String) {
		var code = ch.charCodeAt(0);
		return (code >= 0x30 && code < 0x3A)
			|| (code >= 0x41 && code < 0x5B)
			|| (code >= 0x61 && code < 0x7B)
			|| (code >= 0xA0 && code < 0x590)
			|| (code >= 0x700 && code < 0x2000)
			|| (code >= 0x2100 && code < 0x2190)
			|| (code >= 0x2460 && code < 0x2500)
			|| (code >= 0x2800 && code < 0x2900)
			|| (code >= 0x2E80 && code < 0x3000)
			|| (code >= 0x3040 && code < 0xD800)
			|| (code >= 0xF900 && code < 0xFB1D)
			|| (code >= 0xFE20 && code < 0xFE70)
			|| (code >= 0xFF00 && code < 0xFFF0)
			// TODO treat also UCS-2 misencoded characters
			/*|| (code >= 0x1D300 && code < 0x1D800)
			|| (code >= 0x20000 && code < 0x2FA20)*/;
	}

	public static function getStringDirection(s: String) {
		for (i in 0...s.length) {
			var c = s.charAt(i);
			if (isRtlChar(c)) return "RTL";
			if (isLtrChar(c)) return "LTR";
		}
		return "";
	}

	private static function isCharCombining(testChr : String, pos: Int) : Bool {
		var chr = testChr.charCodeAt(pos);
		return
			(chr >= 0x300 && chr < 0x370) || (chr >= 0x483 && chr < 0x488) || (chr >= 0x591 && chr < 0x5C8) ||
			(chr >= 0x610 && chr < 0x61B) || (chr >= 0x64B && chr < 0x660) || (chr == 0x670) ||
			(chr >= 0x6D6 && chr < 0x6EE) || (chr == 0x711) || (chr >= 0x730 && chr < 0x7F4) ||
			(chr >= 0x816 && chr < 0x82E) || (chr >= 0x859 && chr < 0x85C) || (chr >= 0x8D4 && chr < 0x903) ||
			(chr >= 0x93A && chr < 0x93D) || (chr >= 0x941 && chr < 0x94E) || (chr >= 0x951 && chr < 0x958) ||
			(chr >= 0x962 && chr < 0x964) || (chr == 0x981) || (chr == 0x9BC) || (chr >= 0x9C1 && chr < 0x9C5) ||
			(chr == 0x9BC) || (chr >= 0x9E2 && chr < 0x9E3) || (chr >= 0xA01 && chr < 0xA03) || (chr == 0xA3C) ||
			(chr >= 0xA41 && chr < 0xA43) || (chr >= 0xA47 && chr < 0xA49) || (chr >= 0xA4B && chr < 0xA4E) ||
			(chr == 0xA51) || (chr >= 0xA70 && chr < 0xA72) || (chr == 0xA75) || (chr >= 0xA81 && chr < 0xA83) ||
			(chr == 0xABC) || (chr >= 0xAC1 && chr < 0xACE) || (chr >= 0xAE2 && chr < 0xAE4) ||
			(chr >= 0xAFA && chr < 0xB00) || (chr == 0xB01) || (chr == 0xB3C) || (chr == 0xB3F) ||
			(chr >= 0xB41 && chr < 0xB45) || (chr == 0xB4D) || (chr == 0xB56) || (chr >= 0xB62 && chr < 0xB64) ||
			(chr == 0xB82) || (chr == 0xBC0) || (chr == 0xBCD) || (chr == 0xC00) ||
			(chr >= 0xC3E && chr < 0xC41) || (chr >= 0xC46 && chr < 0xC4E && chr != 0xC49) ||
			(chr >= 0xC55 && chr < 0xC57) || (chr >= 0xC62 && chr < 0xC64) || (chr == 0xC81) || (chr == 0xCBC) ||
			(chr == 0xCBF) || (chr == 0xCC6) || (chr >= 0xCCC && chr < 0xCCE) || (chr >= 0xCE2 && chr < 0xCE4) ||
			// TODO add ranges from 0xD00..0x1AB0 from http://www.fileformat.info/info/unicode/category/Mn/list.htm
			(chr >= 0x1AB0 && chr < 0x1B00);
	}

	private static function getBulletsString(t : String) : TextMappedModification {
		// TODO analyze string for UTF-16 sequences to represent them with a single bullet instead of two.
		var i = 0;
		var ret = "";
		var positionsDiff : Array<Int> = [];
		for (i in 0...t.length) {
			ret += bullet;
			positionsDiff.push(0);
		}
		return new TextMappedModification(ret, positionsDiff);
	}

	private static var LIGATURES(default, never) : Map<String, String> = [
		"لآ" => "ﻵ", "لأ" => "ﻷ", "لإ" => "ﻹ", "لا" => "ﻻ",
	];

	private static var LIGA_LENGTHS(default, never) = [2];

	private static inline var GV_ISOLATED = 0;
	private static inline var GV_FINAL = 1;
	private static inline var GV_INITIAL = 2;
	private static inline var GV_MEDIAL = 3;

	private static function getActualGlyphsString(t : String) : TextMappedModification {
		var positionsDiff : Array<Int> = [];
		var lret = "";
		var i : Int = 0;
		while (i<t.length) {
			var subst : String = null;
			for (ll in LIGA_LENGTHS) {
				var cand = t.substr(i, ll);
				subst = LIGATURES.get(cand);
				if (subst != null) {
					positionsDiff.push(ll-1);
					lret += subst;
					i += ll;
					break;
				}
			}
			if (subst == null) {
				lret += t.substr(i, 1);
				positionsDiff.push(0);
				i += 1;
			}
		}
		var gv = GV_ISOLATED;
		i = 0;
		var ret = "";
		var rightConnect = false;  // Assume only RTL ones have connections.
		while (i<=lret.length) {
			var j = i+1;
			while (j<lret.length && isCharCombining(lret, j)) j += 1;
			var conMask = UnicodeTranslation.getCharAvailableVariants(j >= lret.length? "" : lret.substr(j, 1));

			// Simplified implementation due seems following character, if RTL, always support connection.
			if ((conMask & 3) == 3) {
				gv = rightConnect? GV_MEDIAL : GV_INITIAL;
				rightConnect = true;
			} else {
				gv = rightConnect? GV_FINAL : GV_ISOLATED;
				rightConnect = false;
			}
			if (i>0) ret += UnicodeTranslation.getCharVariant(lret.substr(i-1, 1), gv);
			ret += lret.substr(i, j-i-1);
			i = j;
		}
		return new TextMappedModification(ret, positionsDiff);
	}

	private static function checkTextLength(text : String) : Array<Array<String>> {
		var textSplit = text.split('\n');

		if (textSplit.filter(function (t) { return t.length > 1000; }).length > 0) {
			return textSplit.map(function (t) { return t.length > 1000 ? splitString(t) : [t]; });
		} else {
			return [[text]];
		}
	}

	private static function splitString(text : String) : Array<String> {
		return text.length > 1000 ? [text.substr(0, 1000)].concat(splitString(text.substr(1000))) :
			text.length > 0 ? [text] : [];
	}

	public override function updateNativeWidgetStyle() : Void {
		super.updateNativeWidgetStyle();

		nativeWidget.setAttribute("type", type);
		nativeWidget.value = text;
		nativeWidget.style.color = style.fill;
		nativeWidget.style.letterSpacing = '${style.letterSpacing}px';
		nativeWidget.style.fontFamily = style.fontFamily;
		nativeWidget.style.fontWeight = style.fontWeight;
		nativeWidget.style.fontStyle = style.fontStyle;
		nativeWidget.style.fontSize =  '${style.fontSize}px';
		nativeWidget.style.lineHeight = '${cast(style.fontSize, Float) * 1.15 + interlineSpacing}px';
		nativeWidget.style.pointerEvents = readOnly ? 'none' : 'auto';
		nativeWidget.readOnly = readOnly;
		nativeWidget.style.backgroundColor = RenderSupportJSPixi.makeCSSColor(backgroundColor, backgroundOpacity);

		nativeWidget.style.direction = switch (textDirection) {
			case 'RTL' : 'rtl';
			case 'rtl' : 'rtl';
			default : 'ltr';
		}

		nativeWidget.style.textAlign = switch (autoAlign) {
			case 'AutoAlignLeft' : 'left';
			case 'AutoAlignRight' : 'right';
			case 'AutoAlignCenter' : 'center';
			case 'AutoAlignNone' : 'none';
			default : 'left';
		}

		if (cursorColor >= 0) {
			nativeWidget.style.caretColor = RenderSupportJSPixi.makeCSSColor(cursorColor, cursorOpacity);
		}

		if (type == 'number') {
			nativeWidget.step = step;
		}

		nativeWidget.autocomplete = autocomplete;

		if (maxChars >= 0) {
			nativeWidget.maxLength = maxChars;
		}

		if (tabIndex >= 0) {
			nativeWidget.tabIndex = tabIndex;
		}

		if (multiline) {
			nativeWidget.style.resize = 'none';
			nativeWidget.wrap = wordWrap ? 'soft' : 'off';
		}

		nativeWidget.style.cursor = isFocused ? 'text' : 'inherit';

		if (Platform.isEdge || Platform.isIE) {
			nativeWidget.style.opacity = 1;
			var slicedColor : Array<String> = style.fill.split(",");
			var newColor = slicedColor.slice(0, 3).join(",") + "," + Std.parseFloat(slicedColor[3]) * (isFocused ? worldAlpha : 0) + ")";

			nativeWidget.style.color = newColor;
		} else {
			nativeWidget.style.opacity = isFocused ? worldAlpha : 0;
		}
	}

	private function bidiDecorate(text : String) : String {
		if (textDirection == 'ltr') {
			return String.fromCharCode(0x202A) + text + String.fromCharCode(0x202C);
		} else if (textDirection == 'rtl') {
			return String.fromCharCode(0x202B) + text + String.fromCharCode(0x202C);
		} else {
			return text;
		}
	}

	private static inline function capitalize(s : String) : String {
		return s.substr(0, 1).toUpperCase() + s.substr(1, s.length - 1);
	}

	// HACK due to unable remake builtin fonts
	private static inline function recognizeBuiltinFont(fontFamily : String, fontWeight : Int, fontSlope : String) : String {
		if (StringTools.startsWith(fontFamily, "'Material Icons")) {
			return "MaterialIcons";
		} else if (StringTools.startsWith(fontFamily, "'DejaVu Sans")) {
			return "DejaVuSans";
		} else if (StringTools.startsWith(fontFamily, "'Franklin Gothic")) {
			return fontSlope == "italic" ? "Italic" : fontWeight == 700 ? "Bold" : "Book";
		} else if (StringTools.startsWith(fontFamily, "'Roboto")) {
			return fontFamily + fontWeightToString(fontWeight) + fontSlope == "normal" ? "" : capitalize(fontSlope);
		} else {
			return fontFamily;
		}
	}

	private static inline function fontWeightToString(fontWeight : Int) : String {
		if (fontWeight <= 100)
			return "Thin"
		else if (fontWeight <= 200)
			return "Ultra Light"
		else if (fontWeight <= 300)
			return "Light"
		else if (fontWeight <= 400)
			return "Book"
		else if (fontWeight <= 500)
			return "Medium"
		else if (fontWeight <= 600)
			return "Semi Bold"
		else if (fontWeight <= 700)
			return "Bold"
		else if (fontWeight <= 800)
			return "Extra Bold"
		else
			return "Black";
	}

	public function setTextAndStyle(text : String, fontFamilies : String, fontSize : Float, fontWeight : Int, fontSlope : String, fillColor : Int,
		fillOpacity : Float, letterSpacing : Float, backgroundColor : Int, backgroundOpacity : Float) : Void {
		fontFamilies = fontWeight > 0 || fontSlope != ""
				? fontFamilies.split(",").map(function (fontFamily) { return recognizeBuiltinFont(fontFamily, fontWeight, fontSlope); }).join(",")
				: fontFamilies;

		var fontStyle : FontStyle = FlowFontStyle.fromFlowFonts(fontFamilies);

		style.fontSize = Math.max(fontSize, 0.6);
		style.fill = RenderSupportJSPixi.makeCSSColor(fillColor, fillOpacity);
		style.letterSpacing = letterSpacing;
		style.fontFamily = fontStyle.family;
		style.fontWeight = fontWeight != 400 ? '${fontWeight}' : fontStyle.weight;
		style.fontStyle = fontSlope != '' ? fontSlope : fontStyle.style;
		style.lineHeight = fontSize * 1.15 + interlineSpacing;
		style.wordWrap = wordWrap;
		style.wordWrapWidth = widgetWidth > 0 ? widgetWidth : 2048;
		style.breakWords = cropWords;
		style.align = autoAlign == 'AutoAlignRight' ? 'right' : autoAlign == 'AutoAlignCenter' ? 'center' : 'left';

		fontMetrics = TextMetrics.measureFont(untyped style.toFontString());

		this.text = StringTools.endsWith(text, '\n') ? text.substring(0, text.length - 1) : text;
		this.backgroundColor = backgroundColor;
		this.backgroundOpacity = backgroundOpacity;

		// Force text value right away
		if (nativeWidget != null) {
			nativeWidget.value = text;
		}

		invalidateMetrics();
	}

	private function layoutText() : Void {
		if (isFocused || text == '') {
			if (textClip != null) {
				textClip.setClipRenderable(false);
			}
		} else if (textClipChanged) {
			var modification : TextMappedModification = (isInput() && type == "password" ? getBulletsString(text) :
			var text = modificaiton.modified;
			var texts = wordWrap || true ? [[text]] : checkTextLength(text);

			if (textClip == null) {
				textClip = createTextClip(texts[0][0], style);
				addChild(textClip);
			}

			text = bidiDecorate(texts[0][0]);

			textClip.text = text;
			textClip.style = style;

			var child = textClip.children.length > 0 ? textClip.children[0] : null;

			while (child != null) {
				textClip.removeChild(child);
				child.destroy({ children: true, texture: true, baseTexture: true });

				child = textClip.children.length > 0 ? textClip.children[0] : null;
			}

			if (texts.length > 1 || texts[0].length > 1) {
				var currentHeight = 0.0;

				for (line in texts) {
					var currentWidth = 0.0;
					var lineHeight = 0.0;

					for (txt in line) {
						text = bidiDecorate(txt);

						if (txt == texts[0][0]) {
							currentWidth = textClip.getLocalBounds().width;
							lineHeight = textClip.getLocalBounds().height;
						} else {
							var newTextClip = createTextClip(text, style);

							newTextClip.setClipX(currentWidth);
							newTextClip.setClipY(currentHeight);

							textClip.addChild(newTextClip);

							currentWidth += newTextClip.getLocalBounds().width;
							lineHeight = Math.max(lineHeight, newTextClip.getLocalBounds().height);
						}
					}

					currentHeight += lineHeight;
				}
			}

			var anchorX = switch (autoAlign) {
				case 'AutoAlignLeft' : 0;
				case 'AutoAlignRight' : 1;
				case 'AutoAlignCenter' : 0.5;
				default : textDirection == 'rtl' ? 1 : 0;
			};

			textClip.setClipX(anchorX * Math.max(0, widgetWidth - getClipWidth()));

			setTextBackground(new Rectangle(0, 0, getWidth(), getHeight()));

			if (isInput) {
				setScrollRect(0, 0, getWidth(), getHeight());
			}

			textClip.setClipRenderable(true);
			textClipChanged = false;
		}
	}

	private function createTextClip(textMod : TextMappedModification, chrIdx : Int, style : Dynamic) : Text {
		textClip = new Text(textMod.modified, style);
		textClip.charIdx = chrIdx;
		textClip.difPositionMapping = textMod.difPositionMapping;
		textClip.setClipVisible(true);

		return textClip;
	}

	public function invalidateMetrics() : Void {
		metrics = null;
		textClipChanged = true;
		invalidateStyle();
	}

	private function setTextBackground(?text_bounds : Rectangle) : Void {
		if (background != null) {
			removeChild(background);
		}

		if (backgroundOpacity > 0.0) {
			var text_bounds = text_bounds != null ? text_bounds : getLocalBounds();
			background = new FlowGraphics();
			background.beginFill(backgroundColor, backgroundOpacity);
			background.drawRect(0.0, 0.0, text_bounds.width, text_bounds.height);

			addChildAt(background, 0);
		} else {
			background = null;
		}
	}

	public function setTextInputType(type : String) : Void {
		if (this.type != type) {
			this.type = type;

			invalidateStyle();
		}
	}

	public function setTextInputAutoCompleteType(type : String) : Void {
		if (this.autocomplete != type) {
			this.autocomplete = type;

			invalidateStyle();
		}
	}

	public function setTextInputStep(step : Float) : Void {
		if (this.step != step) {
			this.step = step;

			invalidateStyle();
		}
	}

	public  function setWordWrap(wordWrap : Bool) : Void {
		if (this.wordWrap != wordWrap) {
			this.wordWrap = wordWrap;
			style.wordWrap = wordWrap;

			invalidateMetrics();
		}
	}

	public override function setWidth(widgetWidth : Float) : Void {
		style.wordWrapWidth = widgetWidth > 0 ? widgetWidth : 2048;
		super.setWidth(widgetWidth);
		invalidateMetrics();
	}

	public function setCropWords(cropWords : Bool) : Void {
		if (this.cropWords != cropWords) {
			this.cropWords = cropWords;
			style.breakWords = cropWords;

			invalidateMetrics();
		}
	}

	public function setCursorColor(cursorColor : Int, cursorOpacity : Float) : Void {
		if (this.cursorColor != cursorColor || this.cursorOpacity != cursorOpacity) {
			this.cursorColor = cursorColor;
			this.cursorOpacity = cursorOpacity;

			invalidateStyle();
		}
	}

	public function setCursorWidth(cursorWidth : Float) : Void {
		if (this.cursorWidth != cursorWidth) {
			this.cursorWidth = cursorWidth;

			invalidateStyle();
		}
	}

	public function setInterlineSpacing(interlineSpacing : Float) : Void {
		if (this.interlineSpacing != interlineSpacing) {
			this.interlineSpacing = interlineSpacing;
			style.lineHeight = cast(style.fontSize, Float) * 1.15 + interlineSpacing;

			invalidateMetrics();
		}
	}

	public function setTextDirection(textDirection : String) : Void {
		if (this.textDirection != textDirection) {
			this.textDirection = textDirection.toLowerCase();

			invalidateStyle();
		}
	}

	public function setAutoAlign(autoAlign : String) : Void {
		if (this.autoAlign != autoAlign) {
			this.autoAlign = autoAlign;
			if (autoAlign == 'AutoAlignRight')
				style.align = 'right';
			else if (autoAlign == 'AutoAlignCenter')
				style.align = 'center';
			else
				style.align = 'left';

			invalidateMetrics();
		}
	}

	public function setTabIndex(tabIndex : Int) : Void {
		if (this.tabIndex != tabIndex) {
			this.tabIndex = tabIndex;

			invalidateStyle();
		}
	}

	public function setReadOnly(readOnly : Bool) {
		if (this.readOnly != readOnly) {
			this.readOnly = readOnly;

			invalidateStyle();
		}
	}

	public function setMaxChars(maxChars : Int) {
		if (this.maxChars != maxChars) {
			this.maxChars = maxChars;

			invalidateStyle();
		}
	}

	public function setTextInput() {
		isInput = true;

		if (multiline) {
			setWordWrap(true);
		}

		createNativeWidget(multiline ? 'textarea' : 'input');

		nativeWidget.onmousemove = onMouseMove;
		nativeWidget.onmousedown = onMouseDown;
		nativeWidget.onmouseup = onMouseUp;

		if (Native.isTouchScreen()) {
			nativeWidget.ontouchstart = onMouseDown;
			nativeWidget.ontouchend = onMouseUp;
			nativeWidget.ontouchmove = onMouseMove;
		}

		nativeWidget.onfocus = onFocus;
		nativeWidget.onblur = onBlur;

		nativeWidget.addEventListener('input', onInput);
		nativeWidget.addEventListener('scroll', onScroll);
		nativeWidget.addEventListener('keydown', onKeyDown);
		nativeWidget.addEventListener('keyup', onKeyUp);

		invalidateStyle();
	}

	private function checkPositionSelection() : Void {
		var hasChanges = false;

		var cursorPosition = getCursorPosition();
		var selectionStart = getSelectionStart();
		var selectionEnd = getSelectionEnd();

		if (this.cursorPosition != cursorPosition) {
			this.cursorPosition = cursorPosition;
			hasChanges = true;
		}

		if (this.selectionStart != selectionStart) {
			this.selectionStart = selectionStart;
			hasChanges = true;
		}

		if (this.selectionEnd != selectionEnd) {
			this.selectionEnd = selectionEnd;
			hasChanges = true;
		}

		if (hasChanges) {
			emit('input');
		}
	}

	private function onMouseMove(e : MouseEvent) {
		if (isFocused) {
			checkPositionSelection();
		}

		nativeWidget.style.cursor = RenderSupportJSPixi.PixiRenderer.view.style.cursor;

		RenderSupportJSPixi.provideEvent(e);
	}

	private function onMouseDown(e : Dynamic) {
		if (isFocused) {
			checkPositionSelection();
		} else {
			var point = e.touches != null && e.touches.length > 0 ? new Point(e.touches[0].pageX, e.touches[0].pageY) : new Point(e.pageX, e.pageY);

			if (RenderSupportJSPixi.getClipAt(RenderSupportJSPixi.PixiStage, point, true, true) != this) {
				e.preventDefault();
			}
		}

		RenderSupportJSPixi.provideEvent(e);
	}

	private function onMouseUp(e : MouseEvent) {
		if (isFocused) {
			checkPositionSelection();
		}

		RenderSupportJSPixi.provideEvent(e);
	}

	private function onFocus(e : Event) : Void {
		isFocused = true;
		emit('focus');

		if (parent != null) {
			parent.emitEvent('childfocused', this);
		}

		invalidateMetrics();
	}

	private function onBlur(e : Event) : Void {
		isFocused = false;
		emit('blur');

		invalidateMetrics();
	}

	private function onInput(e : Dynamic) {
		var newValue : String = nativeWidget.value;

		if (maxChars > 0) {
			newValue = newValue.substr(0, maxChars);
		}

		for (f in TextInputFilters) {
			newValue = f(newValue);
		}

		if (newValue != nativeWidget.value) {
			if (e != null && e.data != null && e.data.length != null) {
				var newCursorPosition : Int = untyped cursorPosition + newValue.length - nativeWidget.value.length + e.data.length;

				nativeWidget.value = newValue;
				setSelection(newCursorPosition, newCursorPosition);
			} else {
				nativeWidget.value = newValue;
			}
		} else {
			var selectionStart = getSelectionStart();
			var selectionEnd = getSelectionEnd();

			setSelection(selectionStart, selectionEnd);
		}

		this.text = newValue;
		emit('input', newValue);
	}

	private function onScroll(e : Dynamic) {
		emit('scroll', e);
	}

	public function setMultiline(multiline : Bool) : Void {
		if (this.multiline != multiline) {
			this.multiline = multiline;
			setTextInput();
		}
	}

	private function onKeyDown(e : Dynamic) {
		if (TextInputKeyDownFilters.length > 0) {
			var ke : Dynamic = RenderSupportJSPixi.parseKeyEvent(e);

			for (f in TextInputKeyDownFilters) {
				if (!f(ke.key, ke.ctrl, ke.shift, ke.alt, ke.meta, ke.keyCode)) {
					ke.preventDefault();
					RenderSupportJSPixi.emit('keydown', ke);
					break;
				}
			}
		}

		if (isFocused) {
			checkPositionSelection();
		}
	}

	private function onKeyUp(e : Dynamic) {
		var ke : Dynamic = RenderSupportJSPixi.parseKeyEvent(e);
		if (TextInputKeyUpFilters.length > 0) {

			for (f in TextInputKeyUpFilters) {
				if (!f(ke.key, ke.ctrl, ke.shift, ke.alt, ke.meta, ke.keyCode)) {
					ke.preventDefault();
					RenderSupportJSPixi.emit('keyup', ke);
					break;
				}
			}
		}

		 // Hide mobile keyboard on enter key press
		if (ke.keyCode == 13 && Platform.isMobile && !this.multiline) {
			nativeWidget.blur();
		}

		if (isFocused) {
			checkPositionSelection();
		}
	}

	public function getDescription() : String {
		if (isInput) {
			return 'TextClip (text = "${nativeWidget.value}")';
		} else {
			return 'TextClip (text = "${text}")';
		}
	}

	public override function getWidth() : Float {
		return widgetWidth > 0.0 && isInput ? widgetWidth : getClipWidth();
	}

	private function getClipWidth() : Float {
		updateTextMetrics();
		return metrics != null ? untyped metrics.width : 0;
	}

	public override function getHeight() : Float {
		return widgetHeight > 0.0 && isInput ? widgetHeight : getClipHeight();
	}

	private function getClipHeight() : Float {
		updateTextMetrics();
		return metrics != null ? untyped metrics.height : 0;
	}

	public function getContent() : String {
		return text;
	}

	public function getCursorPosition() : Int {
		try {
			// Chrome doesn't support this method for 'number' inputs
			if (nativeWidget.selectionStart != null) {
				return nativeWidget.selectionStart;
			}
		} catch (e : Dynamic) {}

		if (untyped Browser.document.selection != null) {
			nativeWidget.focus();
			var r : Dynamic = untyped Browser.document.selection.createRange();
			if (r == null) return 0;

			var re = nativeWidget.createTextRange();
			var rc = re.duplicate();
			re.moveToBookmark(r.getBookmark());
			untyped rc.setEndPoint('EndToStart', re);
			return rc.text.length;
		}

		return 0;
	}

	public function getSelectionStart() : Int {
		// Chrome doesn't support this method for 'number' inputs
		try {
			if (nativeWidget.selectionStart == null) {
				return nativeWidget.value.length;
			} else {
				return nativeWidget.selectionStart;
			}
		} catch (e : Dynamic) {
			return 0;
		}
	}

	public function getSelectionEnd() : Int {
		// Chrome doesn't support this method for 'number' inputs
		try {
			if (nativeWidget.selectionEnd == null) {
				return nativeWidget.value.length;
			} else {
				return nativeWidget.selectionEnd;
			}
		} catch (e : Dynamic) {
			return 0;
		}
	}

	public function setSelection(start : Int, end : Int) : Void {
		// Chrome doesn't support this method for 'number' inputs
		try {
			nativeWidget.setSelectionRange(start, end);
		} catch (e : Dynamic) {
			return;
		}
	}

	public function addTextInputFilter(filter : String -> String) : Void -> Void {
		TextInputFilters.push(filter);
		return function() { TextInputFilters.remove(filter); }
	}

	public function addTextInputKeyDownEventFilter(filter : String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool) : Void -> Void {
		TextInputKeyDownFilters.push(filter);
		return function() { TextInputKeyDownFilters.remove(filter); }
	}

	public function addTextInputKeyUpEventFilter(filter : String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool) : Void -> Void {
		TextInputKeyUpFilters.push(filter);
		return function() { TextInputKeyUpFilters.remove(filter); }
	}

	private function updateTextMetrics() : Void {
		if (text != "" && cast(style.fontSize, Float) > 1.0 && (metrics == null || untyped metrics.text != text || untyped metrics.style != style)) {
			metrics = TextMetrics.measureText(text, style);
		}
	}

	public function getTextMetrics() : Array<Float> {
		if (fontMetrics == null) {
			var ascent = 0.9 * cast(style.fontSize, Float);
			var descent = 0.1 * cast(style.fontSize, Float);
			var leading = 0.15 * cast(style.fontSize, Float);

			return [ascent, descent, leading];
		} else {
			return [fontMetrics.ascent, fontMetrics.descent, fontMetrics.descent];
		}
	}
}