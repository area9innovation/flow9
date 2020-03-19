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
	public var modification : TextMappedModification;

	public function update(mod: TextMappedModification, style: TextStyle, textDirection: String) {
		this.text = TextClip.bidiDecorate(mod.text, textDirection);
		this.modification = mod;
		this.style = style;
	}
}

class TextMappedModification {
	public var text: String;
	public var modified: String;
	public var difPositionMapping : Array<Int>;
	public var variants : Array<Int>;
	public function new(text: String, modified: String, difPositionMapping: Array<Int>, variants: Array<Int>) {
		this.text = text;
		this.modified = modified;
		this.difPositionMapping = difPositionMapping;
		this.variants = variants;
	}

	public static function createInvariantForString(text : String) : TextMappedModification {
		var positionsDiff : Array<Int> = [];
		var vars : Array<Int> = [];
		for (i in 0...text.length) {
			positionsDiff.push(0);
			vars.push(TextClip.GV_ISOLATED);
		}
		return new TextMappedModification(text, text, positionsDiff, vars);
	}

	// Substr of text, works at glyph basis.
	public function substr(pos: Int, len: Int) : TextMappedModification {
		var ofsB: Int = 0;
		for (i in 0...pos) ofsB += difPositionMapping[i];
		var ofsE: Int = 0;
		for (i in pos...pos+len) ofsE += difPositionMapping[i];
		return new TextMappedModification(
			text.substr(pos+ofsB, len+ofsE),
			modified.substr(pos, len),
			difPositionMapping.slice(pos, pos+len),
			variants.slice(pos, pos+len)
		);
	}
}

class UnicodeTranslation {
	public var rangeStart : Int;
	public var rangeContentFlags : Int;
	static var map : Map<String, UnicodeTranslation> = new Map<String, UnicodeTranslation>();

	private static function initMap() {
		var found = "";
		for (found in map) break;
		if (found == "") {
			// Glyphs start here.
			var rangeStart : Int = 0xFE81;
			// Packed values, bit per character. How many glyphs
			// present for a character, 4 if bit is set, else 2.
			var flags : Int = 0x1FE1F50;
			for (i in 0x622...0x63B) {
				var is4range: Int = flags & 1;
				flags = flags >> 1;
				map[String.fromCharCode(i)] = new UnicodeTranslation(rangeStart, 3 + 12*is4range);
				rangeStart += 2 + is4range*2;
			}
			flags = 0x27F; // As above.
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
	}

	public function new(rangeStart, rangeContentFlags) {
		this.rangeStart = rangeStart;
		this.rangeContentFlags = rangeContentFlags;
	}

	static public function getCharAvailableVariants(chr: String): Int {
		initMap();
		var unit = map.get(chr);
		if (unit == null) return 1;
		return unit.rangeContentFlags;
	}

	static public function getCharVariant(chr: String, gv: Int): String {
		initMap();
		var unit = map[chr];
		if (unit == null) return chr;
		var tr_gv = unit.rangeContentFlags;
		if (0==((tr_gv >> gv) & 1)) gv &= -3;
		if (0==((tr_gv >> gv) & 1)) gv &= -2;
		return String.fromCharCode(unit.rangeStart + gv);
	}
}

class TextClip extends NativeWidgetClip {
	public static inline var UPM : Float = 2048.0;  // Const.
	private var text : String = '';
	public var charIdx : Int = 0;
	private var backgroundColor : Int = 0;
	private var backgroundOpacity : Float = 0.0;
	private var cursorColor : Int = -1;
	private var cursorOpacity : Float = -1.0;
	private var cursorWidth : Float = 2;
	private var textDirection : String = '';
	private var escapeHTML : Bool = true;
	private var style : Dynamic = new TextStyle();

	private var type : String = 'text';
	private var autocomplete : String = '';
	private var step : Float = 1.0;
	private var wordWrap : Bool = false;
	private var doNotInvalidateStage : Bool = false;
	private var cropWords : Bool = false;
	private var autoAlign : String = 'AutoAlignNone';
	private var readOnly : Bool = false;
	private var maxChars : Int = -1;

	private var cursorPosition : Int = -1;
	private var selectionStart : Int = -1;
	private var selectionEnd : Int = -1;

	private var background : FlowGraphics = null;

	private var metrics : Dynamic;
	private var multiline : Bool = false;

	private var TextInputFilters : Array<String -> String> = new Array();
	private var TextInputKeyDownFilters : Array<String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool> = new Array();
	private var TextInputKeyUpFilters : Array<String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool> = new Array();

	private var textClip : Text = null;
	private var textClipChanged : Bool = false;

	private var isInput : Bool = false;
	private var isFocused : Bool = false;
	public var isInteractive : Bool = false;

	private var baselineWidget : Dynamic;
	private var widthDelta : Float = 0.0;
	private var fontDelta : Float = 0.0;

	private var doNotRemap : Bool = false;

	public function new(?worldVisible : Bool = false) {
		super(worldVisible);

		style.resolution = 1.0;

		if (RenderSupport.RendererType == "html" && !Platform.isMobile && (Platform.isSafari || Platform.isChrome)) {
			this.onAdded(function() {
				RenderSupport.on("resize", updateWidthDelta);

				return function() {
					RenderSupport.off("resize", updateWidthDelta);
				}
			});
		}
	}

	public static function isRtlChar(ch: String) {
		var code = ch.charCodeAt(0);
		return (code >= 0x590 && code < 0x900)    // Hebrew, arabic and some other RTL.
			|| (code >= 0xFB1D && code < 0xFDD0)  // Hebrew, arabic and some other RTL (presentations).
			|| (code >= 0xFDF0 && code < 0xFE00)  // Arabic ideographics.
			|| (code >= 0xFE70 && code < 0xFF00)  // Arabic presentations.
			// TODO treat also UCS-2 misencoded characters
			/*|| (code >= 0x10800 && code < 0x11000)
			|| (code >= 0x1E800 && code < 0x1F000)*/;
	}

	public static function isLtrChar(ch: String) {
		var code = ch.charCodeAt(0);
		return (code >= 0x30 && code < 0x3A)      // Decimals.
			|| (code >= 0x41 && code < 0x5B)      // Capital basic latin.
			|| (code >= 0x61 && code < 0x7B)      // Small basic latin.
			|| (code >= 0xA0 && code < 0x590)     // Extended latin, diacritics, greeks, cyrillics, and other LTR alphabet letters, also symbols.
			|| (code >= 0x700 && code < 0x2000)   // Extended latin and greek, other LTR alphabet letters, also symbols.
			|| (code >= 0x2100 && code < 0x2190)  // Punctuation, subscripts and superscripts, letterlikes, numerics, diacritics.
			|| (code >= 0x2460 && code < 0x2500)  // Enclosed alphanums.
			|| (code >= 0x2800 && code < 0x2900)  // Braille's.
			|| (code >= 0x2E80 && code < 0x3000)  // Hieroglyphs: CJK, Kangxi, etc.
			|| (code >= 0x3040 && code < 0xD800)  // Hieroglyphs.
			|| (code >= 0xF900 && code < 0xFB1D)  // Hieroglyphs, some latin ligatures.
			|| (code >= 0xFE20 && code < 0xFE70)  // Combinings, CJK compats, small forms.
			|| (code >= 0xFF00 && code < 0xFFF0)  // Halfwidth and fullwidth forms.
			// TODO treat also UCS-2 misencoded characters
			/*|| (code >= 0x1D300 && code < 0x1D800)
			|| (code >= 0x20000 && code < 0x2FA20)*/;
	}

	public static function getStringDirection(s: String, dflt: String) {
		var flagsR = 0;
		for (i in 0...s.length) {
			var c = s.charAt(i);
			if (isRtlChar(c)) flagsR |= 2;
			if (isLtrChar(c)) flagsR |= 1;
		}
		if (flagsR == 2) return "rtl";
		if (flagsR == 1) return "ltr";
		return dflt;
	}

	public static function isStringRtl(s: String) : Bool {
		return getStringDirection(s, null) == "rtl";
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
 		var bullet = String.fromCharCode(8226);
		var i = 0;
		var ret = "";
		var positionsDiff : Array<Int> = [];
		var vars : Array<Int> = [];
		for (i in 0...t.length) {
			ret += bullet;
			positionsDiff.push(0);
			vars.push(GV_ISOLATED);
		}
		return new TextMappedModification(ret, ret, positionsDiff, vars);
	}

	private static var LIGATURES(default, never) : Map<String, String> = [
		"لآ" => "ﻵ", "لأ" => "ﻷ", "لإ" => "ﻹ", "لا" => "ﻻ",
	];

	private static var LIGA_LENGTHS(default, never) = [2];

	public static inline var GV_ISOLATED = 0;
	public static inline var GV_FINAL = 1;
	public static inline var GV_INITIAL = 2;
	public static inline var GV_MEDIAL = 3;

	private static function getActualGlyphsString(t : String) : TextMappedModification {
		var positionsDiff : Array<Int> = [];
		var vars : Array<Int> = [];
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
		i = -1;
		var ret = "";
		var rightConnect = false;  // Assume only RTL ones have connections.
		while (i<=lret.length) {
			var j = i+1;
			while (j<lret.length && isCharCombining(lret, j)) j += 1;
			var conMask = UnicodeTranslation.getCharAvailableVariants(j >= lret.length? "" : lret.substr(j, 1));
			if ((conMask & 3) != 3) gv &= 1;
			vars.push(gv);
			var chr = i >=0 ? UnicodeTranslation.getCharVariant(lret.substr(i, 1), gv) : "";
			if ((conMask & 12) != 0) {
				gv = rightConnect? GV_MEDIAL : GV_INITIAL;
				rightConnect = true;
			} else {
				gv = rightConnect? GV_FINAL : GV_ISOLATED;
				rightConnect = false;
			}
			ret += chr + lret.substr(i+1, j-i-1);
			i = j;
		}
		return new TextMappedModification(t, ret, positionsDiff, vars.slice(1, -1));
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

	private static function getAdvancedWidths(key: String, style: TextStyle) : Array<Array<Int>> {
		if (
			untyped RenderSupport.WebFontsConfig.custom.metrics.hasOwnProperty(style.fontFamily)
		&&
			untyped RenderSupport.WebFontsConfig.custom.metrics[style.fontFamily].advanceWidth.hasOwnProperty(key)
		)
			return untyped RenderSupport.WebFontsConfig.custom.metrics[style.fontFamily].advanceWidth[key];
		var mtxI : Dynamic = pixi.core.text.TextMetrics.measureText(key, style);
		var mtx3 : Dynamic = pixi.core.text.TextMetrics.measureText("ن"+key+"ن", style);
		var mtx2 : Dynamic = pixi.core.text.TextMetrics.measureText("نن", style);
		var iso : Array<Int> = [untyped Math.round(mtxI.width * UPM / style.fontSize / key.length)];
		var med : Array<Int> = [untyped Math.round((mtx3.width-mtx2.width) * UPM / style.fontSize / key.length)];

		// Function getCharAvailableVariants returns flags, so 15 means there are 4 variants.
		if (key.length!=1 || UnicodeTranslation.getCharAvailableVariants(key)!=15) {
			// Ligatures have only two variants, so initial=isolated and medial=final.
			while (iso.length < key.length) {
				iso.push(iso[0]);
				med.push(med[0]);
			}
			return [iso, med, iso, med];
		}
		// Further is approximation, because no metrics in config, and no way
		// to measure exact glyphs via pixijs. I discovered that final and isolated
		// are near in width, and initial and medial also near.
		return [iso, iso, med, med];
	}

	// Given len is supposed to be measured from the beginning.
	private static function getAdvancedWidthsCorrection(tm: TextMappedModification, style: TextStyle, textLen: Int, glyphsLen: Int, inGlyphBack: Int) : Int {
		if (textLen < 1 || glyphsLen < 1) return 0;
		var variant : Int = tm.variants[glyphsLen-1];
		if (variant <= 1 && inGlyphBack == 0) return 0;
		// Last char is initial or medial — will be mistakenly measured as
		// isolated or final — correction needed.
		var key : String = tm.text.substr(textLen-1, 1 + tm.difPositionMapping[glyphsLen-1]);
		var nMetrics : Array<Array<Int>> = getAdvancedWidths(key, style);
		if (key != tm.text.substr(textLen-1, 1)) {
			key = tm.text.substr(textLen-1, 1 + tm.difPositionMapping[glyphsLen-1] - inGlyphBack);
			var oMetrics : Array<Array<Int>> = getAdvancedWidths(key, style);
			return nMetrics[variant][0]-oMetrics[variant&1][0];
		}
		return nMetrics[variant][0]-nMetrics[variant&1][0];
	}

	public static function measureTextModFrag(tm: TextMappedModification, style: TextStyle, b: Int, e: Int) : Float {
		var bochi = -1;
		var bgchi = -1;
		var egchi = 0;
		var eochi = 0;
		var bgb = 0;
		var egb = 0;
		while (eochi < e) {
			eochi += 1 + tm.difPositionMapping[egchi];
			egchi += 1;
			if (eochi >= b && bochi < 0) {
				bochi = eochi;
				bgchi = egchi;
			}
		}
		if (bochi<0) { bochi = 0; bgchi = 0; }
		if (bochi>b) { --bochi; ++bgb; }
		if (eochi>e) { --eochi; ++egb; }
		if (bochi > eochi || bochi < 0) return -1.0;
		var advanceCorrection : Float = 0.0;

		advanceCorrection = untyped (getAdvancedWidthsCorrection(tm, style, eochi, egchi, egb)-getAdvancedWidthsCorrection(tm, style, bochi, bgchi, bgb)) / UPM * style.fontSize;

		var mtxb : Dynamic = pixi.core.text.TextMetrics.measureText(tm.text.substr(0, bochi), style);
		var mtxe : Dynamic = pixi.core.text.TextMetrics.measureText(tm.text.substr(0, eochi), style);

		return mtxe.width - mtxb.width + advanceCorrection;
	}

	public function getCharXPosition(charIdx: Int) : Float {
		layoutText();

		for (child in children) {
			var c : Dynamic = child;

			if (c.text == null) {
				continue;
			}

			if (c.orgCharIdxStart <= charIdx && c.orgCharIdxEnd >= charIdx) {
				var result : Float = measureTextModFrag(c.modification, c.style, 0, untyped charIdx-c.orgCharIdxStart);
				var ctext = bidiUndecorate(c.text);
				if (ctext[1] == 'rtl') return c.width - result;
				return result;
			}
		}
		return -1.0;
	}

	private static function adaptWhitespaces(textContent : String) : String {
		// Replacing leading space with non-breaking space and tabs with spaces.
		return StringTools.replace(StringTools.startsWith(textContent, ' ') ? ' ' + textContent.substring(1) : textContent, "\t", " ");
	}

	public override function updateNativeWidgetStyle() : Void {
		super.updateNativeWidgetStyle();
		var alpha = this.getNativeWidgetAlpha();

		if (isInput) {
			nativeWidget.setAttribute("type", type);
			nativeWidget.value = text;
			nativeWidget.style.pointerEvents = readOnly ? 'none' : 'auto';
			nativeWidget.readOnly = readOnly;

			if (cursorColor >= 0) {
				nativeWidget.style.caretColor = RenderSupport.makeCSSColor(cursorColor, cursorOpacity);
			}

			if (type == 'number') {
				nativeWidget.step = step;
			}

			nativeWidget.autocomplete = autocomplete;

			if (maxChars >= 0) {
				nativeWidget.maxLength = maxChars;
			}

			if (multiline) {
				nativeWidget.style.resize = 'none';
			}

			nativeWidget.style.cursor = isFocused ? 'text' : 'inherit';
			nativeWidget.style.direction = switch (textDirection) {
				case 'RTL' : 'rtl';
				case 'rtl' : 'rtl';
				default : null;
			}

			if (Platform.isEdge || Platform.isIE) {
				var slicedColor : Array<String> = style.fill.split(",");
				var newColor = slicedColor.slice(0, 3).join(",") + "," + Std.parseFloat(slicedColor[3]) * (isFocused ? alpha : 0) + ")";

				nativeWidget.style.color = newColor;
			} else {
				nativeWidget.style.opacity = isFocused ? alpha : 0;
				nativeWidget.style.color = style.fill;
			}
		} else {
			var textContent = getContentGlyphs().modified;
			var newTextContent = adaptWhitespaces(textContent);

			if (escapeHTML) {
				nativeWidget.textContent = newTextContent;
			} else {
				nativeWidget.innerHTML = newTextContent;

				var children : Array<Dynamic> = nativeWidget.getElementsByTagName("*");
				for (child in children) {
					if (child != baselineWidget) {
						child.className = "inlineWidget";
					}
				}
			}

			nativeWidget.style.direction = switch (getStringDirection(textContent, textDirection)) {
				case 'RTL' : 'rtl';
				case 'rtl' : 'rtl';
				default : null;
			}

			nativeWidget.style.opacity = alpha != 1 || Platform.isIE ? alpha : null;
			nativeWidget.style.color = style.fill;
		}

		nativeWidget.style.letterSpacing = RenderSupport.RendererType != "html" || style.letterSpacing != 0 ? '${style.letterSpacing}px' : null;
		nativeWidget.style.fontFamily = RenderSupport.RendererType != "html" || Platform.isIE || style.fontFamily != "Roboto" ? style.fontFamily : null;
		nativeWidget.style.fontWeight = RenderSupport.RendererType != "html" || style.fontWeight != 400 ? style.fontWeight : null;
		nativeWidget.style.fontStyle = RenderSupport.RendererType != "html" || style.fontStyle != 'normal' ? style.fontStyle : null;
		nativeWidget.style.fontSize = '${style.fontSize + fontDelta}px';
		nativeWidget.style.background = RenderSupport.RendererType != "html" || backgroundOpacity > 0 ? RenderSupport.makeCSSColor(backgroundColor, backgroundOpacity) : null;
		nativeWidget.wrap = wordWrap ? 'soft' : 'off';
		nativeWidget.style.lineHeight = '${DisplayObjectHelper.round(style.fontFamily != "Material Icons" || metrics == null ? style.lineHeight + style.leading : metrics.height)}px';

		nativeWidget.style.textAlign = switch (autoAlign) {
			case 'AutoAlignLeft' : null;
			case 'AutoAlignRight' : 'right';
			case 'AutoAlignCenter' : 'center';
			case 'AutoAlignNone' : 'none';
			default : null;
		}

		updateBaselineWidget();
	}

	public inline function updateBaselineWidget() : Void {
		if (RenderSupport.RendererType == "html" && isNativeWidget) {
			if (!isInput && nativeWidget.firstChild != null && style.fontFamily != "Material Icons") {
				baselineWidget.style.height = '${DisplayObjectHelper.round(style.fontProperties.fontSize)}px';
				nativeWidget.insertBefore(baselineWidget, nativeWidget.firstChild);
				nativeWidget.style.marginTop = '${-DisplayObjectHelper.round(style.fontProperties.descent * this.getNativeWidgetTransform().d)}px';
			} else if (baselineWidget.parentNode != null) {
				baselineWidget.parentNode.removeChild(baselineWidget);
			}
		}
	}

	public static function bidiDecorate(text : String, dir : String) : String {
		// I do not know how comes this workaround is needed.
		// But without it, paragraph has &lt; and &gt; displayed wrong.
		if (text == "<" || text == ">") return text;

		if (dir == 'ltr') {
			return String.fromCharCode(0x202A) + text + String.fromCharCode(0x202C);
		} else if (dir == 'rtl') {
			return String.fromCharCode(0x202B) + text + String.fromCharCode(0x202C);
		} else {
			return text;
		}
	}

	private static function bidiUndecorate(text : String) : Array<String> {
		if (text.charCodeAt(text.length-1) == 0x202C) {
			if (text.charCodeAt(0) == 0x202A) return [text.substr(1, text.length-2), 'ltr'];
			if (text.charCodeAt(0) == 0x202B) return [text.substr(1, text.length-2), 'rtl'];
		}
		return [text, ''];
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

	private function updateWidthDelta() {
		if (untyped RenderSupport.RendererType == "html" && !Platform.isMobile && (Platform.isSafari || Platform.isChrome) && !this.destroyed) {
			var zoomFactor = RenderSupport.browserZoom;

			updateTextMetrics();

			if (zoomFactor < 1.0 && metrics != null && metrics.lines != null && metrics.lines.length > 0) {
				var fontSize = style.fontSize;
				var wordWrapWidth = style.wordWrapWidth;
				widthDelta = 0.0;
				metrics = null;
				var wd = getClipWidth();
				var text = this.text;

				style.fontSize = Math.ceil(Math.max(fontSize * zoomFactor, Platform.isSafari ? 10.0 : 6.0));
				style.wordWrapWidth = 2048.0;
				var lines : Array<Dynamic> = metrics.lines;
				var newWidthDelta = Math.NEGATIVE_INFINITY;

				for (line in lines) {
					this.text = line;
					metrics = null;
					newWidthDelta = Math.max(Math.ceil(Math.ceil(getClipWidth() / zoomFactor) - wd), newWidthDelta);
				}

				widthDelta = newWidthDelta;
				fontDelta = -fontSize / 120.0 / zoomFactor;

				style.fontSize = fontSize;
				style.wordWrapWidth = wordWrapWidth;
				this.text = text;
			} else {
				widthDelta = 0.0;
				fontDelta = 0.0;
			}

			invalidateMetrics();
		}
	}

	public function setTextAndStyle(text : String, fontFamilies : String, fontSize : Float, fontWeight : Int, fontSlope : String, fillColor : Int,
		fillOpacity : Float, letterSpacing : Float, backgroundColor : Int, backgroundOpacity : Float) : Void {
		fontFamilies = fontWeight > 0 || fontSlope != ""
				? fontFamilies.split(",").map(function (fontFamily) { return recognizeBuiltinFont(fontFamily, fontWeight, fontSlope); }).join(",")
				: fontFamilies;
		if (Platform.isSafari) {
			fontSize = Math.round(fontSize);
		}

		var fontStyle : FontStyle = FlowFontStyle.fromFlowFonts(fontFamilies);
		this.doNotRemap = fontStyle.doNotRemap;

		style.fontSize = Math.max(fontSize, 0.6);
		style.fill = RenderSupport.makeCSSColor(fillColor, fillOpacity);
		style.letterSpacing = letterSpacing;
		style.fontFamily = fontStyle.family;
		style.fontWeight = fontWeight != 400 ? '${fontWeight}' : fontStyle.weight;
		style.fontStyle = fontSlope != '' ? fontSlope : fontStyle.style;
		style.lineHeight = Math.ceil(fontSize * 1.15);
		style.align = autoAlign == 'AutoAlignRight' ? 'right' : autoAlign == 'AutoAlignCenter' ? 'center' : 'left';
		style.padding = Math.ceil(fontSize * 0.2);

		measureFont();

		this.text = StringTools.endsWith(text, '\n') ? text.substring(0, text.length - 1) : text;
		if (this.textDirection == '') this.textDirection = getStringDirection(this.text, '');
		this.backgroundColor = backgroundColor;
		this.backgroundOpacity = backgroundOpacity;

		// Force text value right away
		if (nativeWidget != null && isInput) {
			nativeWidget.value = text;
		}

		if (RenderSupport.RendererType == "html") {
			this.initNativeWidget(isInput ? (multiline ? 'textarea' : 'input') : 'p');
		}

		invalidateMetrics();
	}

	public function setEscapeHTML(escapeHTML : Bool) : Void {
		if (this.escapeHTML != escapeHTML) {
			this.escapeHTML = escapeHTML;
			invalidateMetrics();
			updateWidthDelta();
		}
	}

	private function measureFont() : Void {
		style.fontProperties = TextMetrics.measureFont(style.toFontString());
	}

	private function layoutText() : Void {
		if (isFocused || text == '') {
			if (textClip != null) {
				textClip.setClipVisible(false);
			}
		} else if (textClipChanged) {
			var modification : TextMappedModification = getContentGlyphs();
			var text = modification.modified;
			var chrIdx: Int = 0;
			var texts = wordWrap ? [[text]] : checkTextLength(text);

			if (textClip == null) {
				textClip = createTextClip(
					modification.substr(0, texts[0][0].length),
					chrIdx, style
				);
				for (difPos in modification.difPositionMapping) textClip.orgCharIdxEnd += difPos;
				addChild(textClip);
			} else {
				textClip.update(modification.substr(0, texts[0][0].length), style, textDirection);
			}
			textClip.orgCharIdxStart = chrIdx;
			textClip.orgCharIdxEnd = chrIdx + texts[0][0].length;

			var child = textClip.children.length > 0 ? textClip.children[0] : null;

			while (child != null) {
				textClip.removeChild(child);
				child.destroy({ children: true, texture: true, baseTexture: true });

				child = textClip.children.length > 0 ? textClip.children[0] : null;
			}

			if (texts.length > 1 || texts[0].length > 1) {
				var currentHeight = 0.0;
				var firstTextClip = true;

				for (line in texts) {
					var currentWidth = 0.0;
					var lineHeight = 0.0;

					for (txt in line) {
						if (firstTextClip) {
							firstTextClip = false;

							currentWidth = textClip.getLocalBounds().width;
							lineHeight = textClip.getLocalBounds().height;
						} else {
							var newTextClip = createTextClip(
								modification.substr(chrIdx, txt.length),
								chrIdx, style
							);

							newTextClip.setClipX(currentWidth);
							newTextClip.setClipY(currentHeight);

							textClip.addChild(newTextClip);

							currentWidth += newTextClip.getLocalBounds().width;
							lineHeight = Math.max(lineHeight, newTextClip.getLocalBounds().height);
						}
						chrIdx += txt.length;
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

			textClip.setClipX(anchorX * Math.max(0, this.getWidgetWidth() - getClipWidth()));

			if (style.fontFamily == "Material Icons") {
				if (style.fontProperties == null) {
					measureFont();
				}

				textClip.setClipY(style.fontProperties.descent / (Platform.isIOS ? 2.0 : Platform.isMacintosh ? RenderSupport.backingStoreRatio : 1.0));
			}

			setTextBackground(new Rectangle(0, 0, getWidth(), getHeight()));

			textClip.setClipVisible(true);
			textClipChanged = false;
		}
	}

	private function createTextClip(textMod : TextMappedModification, chrIdx : Int, style : Dynamic) : Text {
		var textClip = new Text(bidiDecorate(textMod.text, getStringDirection(textMod.modified, textDirection)), style);
		textClip.charIdx = chrIdx;
		textClip.modification = textMod;
		textClip.setClipVisible(true);

		return textClip;
	}

	public override function invalidateStyle() : Void {
		if (!doNotInvalidateStage) {
			if (RenderSupport.RendererType != "html") {
				if (isInput) {
					this.setScrollRect(0, 0, getWidth(), getHeight());
				}
			}

			super.invalidateStyle();
		}
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
			updateWidthDelta();
		}
	}

	public  function setDoNotInvalidateStage(doNotInvalidateStage : Bool) : Void {
		if (this.doNotInvalidateStage != doNotInvalidateStage) {
			this.doNotInvalidateStage = doNotInvalidateStage;
		}
	}

	public override function setWidth(widgetWidth : Float) : Void {
		style.wordWrapWidth = widgetWidth > 0 ? widgetWidth + Browser.window.devicePixelRatio : 2048.0;
		super.setWidth(widgetWidth);
		invalidateMetrics();
		updateWidthDelta();
	}

	public function setCropWords(cropWords : Bool) : Void {
		if (this.cropWords != cropWords) {
			this.cropWords = cropWords;
			style.breakWords = cropWords;

			invalidateMetrics();
			updateWidthDelta();
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

	public function setEllipsis(lines : Int, cb : Bool -> Void) : Void {
		untyped this.style.truncate = lines;
		untyped this.style.truncateCallback = cb;

		invalidateMetrics();
	}

	public function setInterlineSpacing(interlineSpacing : Float) : Void {
		if (style.leading != interlineSpacing) {
			style.leading = interlineSpacing;

			invalidateMetrics();
		}
	}

	public function setTextDirection(textDirection : String) : Void {
		if (this.textDirection != textDirection) {
			this.textDirection = textDirection.toLowerCase();

			invalidateStyle();
			invalidateMetrics();
			layoutText();
		}
	}

	public function getTextDirection() : String {
		return this.textDirection;
	}

	public function setResolution(resolution : Float) : Void {
		if (style.resolution != resolution) {
			style.resolution = resolution;

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

		this.keepNativeWidget = true;
		this.updateKeepNativeWidgetChildren();
		this.initNativeWidget(multiline ? 'textarea' : 'input');
		isInteractive = true;
		this.invalidateInteractive();

		if (Platform.isMobile) {
			if (Platform.isAndroid || (Platform.isSafari && Platform.browserMajorVersion >= 13)) {
				nativeWidget.onpointermove = onMouseMove;
				nativeWidget.onpointerdown = onMouseDown;
				nativeWidget.onpointerup = onMouseUp;

				untyped __js__("this.nativeWidget.addEventListener('touchmove', function(e) { e.preventDefault(); }, { passive : false })");
			}

			nativeWidget.ontouchmove = onMouseMove;
			nativeWidget.ontouchstart = onMouseDown;
			nativeWidget.ontouchend = onMouseUp;
		} else if (Platform.isSafari) {
			nativeWidget.onmousemove = onMouseMove;
			nativeWidget.onmousedown = onMouseDown;
			nativeWidget.onmouseup = onMouseUp;
		} else {
			nativeWidget.onpointermove = onMouseMove;
			nativeWidget.onpointerdown = onMouseDown;
			nativeWidget.onpointerup = onMouseUp;
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

	private function onMouseMove(e : Dynamic) {
		if (isFocused) {
			checkPositionSelection();
		}

		if (e.touches != null) {
			if (e.touches.length == 1) {
				RenderSupport.MousePos.x = e.touches[0].pageX;
				RenderSupport.MousePos.y = e.touches[0].pageY;

				RenderSupport.PixiStage.emit("mousemove");
			} else if (e.touches.length > 1) {
				GesturesDetector.processPinch(new Point(e.touches[0].pageX, e.touches[0].pageY), new Point(e.touches[1].pageX, e.touches[1].pageY));
			}
		} else {
			RenderSupport.MousePos.x = e.pageX;
			RenderSupport.MousePos.y = e.pageY;

			RenderSupport.PixiStage.emit("mousemove");
		}

		nativeWidget.style.cursor = RenderSupport.PixiView.style.cursor;

		e.stopPropagation();
	}

	private function onMouseDown(e : Dynamic) {
		if (isFocused) {
			checkPositionSelection();
		} else {
			var point = e.touches != null && e.touches.length > 0 ? new Point(e.touches[0].pageX, e.touches[0].pageY) : new Point(e.pageX, e.pageY);

			RenderSupport.MousePos.x = point.x;
			RenderSupport.MousePos.y = point.y;

			if (RenderSupport.getClipAt(RenderSupport.PixiStage, RenderSupport.MousePos, true, true) != this) {
				e.preventDefault();
			}
		}

		if (e.touches != null) {
			if (e.touches.length == 1) {
				RenderSupport.MousePos.x = e.touches[0].pageX;
				RenderSupport.MousePos.y = e.touches[0].pageY;

				if (RenderSupport.MouseUpReceived) RenderSupport.PixiStage.emit("mousedown");
			} else if (e.touches.length > 1) {
				GesturesDetector.processPinch(new Point(e.touches[0].pageX, e.touches[0].pageY), new Point(e.touches[1].pageX, e.touches[1].pageY));
			}
		} else {
			RenderSupport.MousePos.x = e.pageX;
			RenderSupport.MousePos.y = e.pageY;

			if (e.which == 3 || e.button == 2) {
				RenderSupport.PixiStage.emit("mouserightdown");
			} else if (e.which == 2 || e.button == 1) {
				RenderSupport.PixiStage.emit("mousemiddledown");
			} else {
				if (RenderSupport.MouseUpReceived) RenderSupport.PixiStage.emit("mousedown");
			}
		}

		e.stopPropagation();
	}

	private function onMouseUp(e : Dynamic) {
		if (isFocused) {
			checkPositionSelection();
		}

		RenderSupport.MousePos.x = e.pageX;
		RenderSupport.MousePos.y = e.pageY;

		if (e.which == 3 || e.button == 2) {
			RenderSupport.PixiStage.emit("mouserightup");
		} else if (e.which == 2 || e.button == 1) {
			RenderSupport.PixiStage.emit("mousemiddleup");
		} else {
			if (!RenderSupport.MouseUpReceived) RenderSupport.PixiStage.emit("mouseup");
		}

		e.stopPropagation();
	}

	private function onFocus(e : Event) : Void {
		isFocused = true;

		if (RenderSupport.Animating) {
			RenderSupport.once("stagechanged", function() { if (isFocused) nativeWidget.focus(); });
			return;
		}

		if (Platform.isEdge || Platform.isIE) {
			var slicedColor : Array<String> = style.fill.split(",");
			var newColor = slicedColor.slice(0, 3).join(",") + "," + Std.parseFloat(slicedColor[3]) * (isFocused ? alpha : 0) + ")";

			nativeWidget.style.color = newColor;
		}

		emit('focus');

		if (parent != null) {
			parent.emitEvent('childfocused', this);
		}

		if (nativeWidget == null || parent == null) {
			return;
		}

		if (Platform.isIOS && Platform.browserMajorVersion < 13) {
			RenderSupport.ensureCurrentInputVisible();
		}

		invalidateMetrics();
	}

	private function onBlur(e : Event) : Void {
		if (untyped RenderSupport.Animating || this.preventBlur) {
			untyped this.preventBlur = false;
			RenderSupport.once("stagechanged", function() { if (isFocused) nativeWidget.focus(); });
			return;
		}

		isFocused = false;

		if (Platform.isEdge || Platform.isIE) {
			var slicedColor : Array<String> = style.fill.split(",");
			var newColor = slicedColor.slice(0, 3).join(",") + "," + Std.parseFloat(slicedColor[3]) * (isFocused ? alpha : 0) + ")";

			nativeWidget.style.color = newColor;
		}

		emit('blur');

		if (nativeWidget == null || parent == null) {
			return;
		}

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

		if (nativeWidget == null) {
			return;
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
			var ke : Dynamic = RenderSupport.parseKeyEvent(e);

			for (f in TextInputKeyDownFilters) {
				if (!f(ke.key, ke.ctrl, ke.shift, ke.alt, ke.meta, ke.keyCode)) {
					ke.preventDefault();
					RenderSupport.emit('keydown', ke);
					break;
				}
			}
		}

		if (isFocused) {
			checkPositionSelection();
		}
	}

	private function onKeyUp(e : Dynamic) {
		var ke : Dynamic = RenderSupport.parseKeyEvent(e);
		if (TextInputKeyUpFilters.length > 0) {

			for (f in TextInputKeyUpFilters) {
				if (!f(ke.key, ke.ctrl, ke.shift, ke.alt, ke.meta, ke.keyCode)) {
					ke.preventDefault();
					RenderSupport.emit('keyup', ke);
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
		return (widgetWidth > 0 ? widgetWidth : getClipWidth()) + widthDelta;
	}

	public override function getHeight() : Float {
		return widgetHeight > 0 ? widgetHeight : getClipHeight();
	}

	private function getClipWidth() : Float {
		updateTextMetrics();
		return metrics != null ? untyped metrics.width : 0;
	}

	private function getClipHeight() : Float {
		updateTextMetrics();
		return metrics != null ? untyped metrics.height : 0;
	}

	public function getContent() : String {
		return text;
	}

	public function getContentGlyphs() : TextMappedModification {
		if (isInput && type == "password") {
			return getBulletsString(this.text);
		} else  {
			//return getActualGlyphsString(this.text);  // Maybe worth to return this line for C++ target instead next one which is good for JS target.
			return TextMappedModification.createInvariantForString(this.text);
		}
	}

	public function getStyle() : TextStyle {
		return style;
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
		if (metrics == null && untyped text != "" && style.fontSize > 1.0) {
			if (!escapeHTML) {
				metrics = TextMetrics.measureText(untyped __js__("this.text.replace(/<\\/?[^>]+(>|$)/g, '')"), style);
				measureHTMLWidth();
			} else if (isStringRtl(text)) {
				metrics = TextMetrics.measureText(adaptWhitespaces(getContentGlyphs().text), style);
			} else {
				metrics = TextMetrics.measureText(text, style);
			}
		}
	}

	private function measureHTMLWidth() : Void {
		if (nativeWidget == null) {
			isNativeWidget = true;
			createNativeWidget(isInput ? (multiline ? 'textarea' : 'input') : 'p');
		}

		var textNodeMetrics : Dynamic = null;

		updateNativeWidgetStyle();

		if (nativeWidget.parentNode == null) {
			Browser.document.body.appendChild(nativeWidget);
			textNodeMetrics = getTextNodeMetrics(nativeWidget);
			Browser.document.body.removeChild(nativeWidget);
		} else {
			textNodeMetrics = getTextNodeMetrics(nativeWidget);
		}

		if (textNodeMetrics.width == null || textNodeMetrics.width <= 0) {
			return;
		}

		if (textNodeMetrics.width > metrics.width + DisplayObjectHelper.TextGap || textNodeMetrics.width < metrics.width - DisplayObjectHelper.TextGap) {
			metrics.width = textNodeMetrics.width;
		}

		if (RenderSupport.RendererType != "html" && !isInput) {
			this.deleteNativeWidget();
		}
	}

	private static function getTextNodeMetrics(textNode) : Dynamic {
		var textNodeMetrics : Dynamic = {};
		if (Browser.document.createRange != null) {
			var range = Browser.document.createRange();
			range.selectNodeContents(textNode);
			if (range.getBoundingClientRect != null) {
				var rect = range.getBoundingClientRect();
				if (rect != null) {
					textNodeMetrics.width = rect.right - rect.left;
					textNodeMetrics.height = rect.bottom - rect.top;
				}
			}
		}
		return textNodeMetrics;
	}

	public function getTextMetrics() : Array<Float> {
		if (style.fontProperties == null) {
			var ascent = 0.9 * style.fontSize;
			var descent = 0.1 * style.fontSize;
			var leading = 0.15 * style.fontSize;

			return [ascent, descent, leading];
		} else {
			return [
				style.fontProperties.ascent,
				style.fontProperties.descent,
				style.fontProperties.descent
			];
		}
	}

	private override function createNativeWidget(?tagName : String = "p") : Void {
		if (RenderSupport.RendererType == "html") {
			if (!isNativeWidget) {
				return;
			}

			this.deleteNativeWidget();

			nativeWidget = Browser.document.createElement(tagName);
			this.updateClipID();
			nativeWidget.classList.add('nativeWidget');
			nativeWidget.classList.add('textWidget');

			baselineWidget = Browser.document.createElement('span');
			baselineWidget.classList.add('baselineWidget');

			isNativeWidget = true;
		} else {
			super.createNativeWidget(tagName);
		}
	}
}