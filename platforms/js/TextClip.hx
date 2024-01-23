import js.Browser;
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
	public static var KeepTextClips = Util.getParameter("wcag") == "1";
	public static var EnsureInputIOS = Util.getParameter("ensure_input_ios") != "0";
	public static var useLetterSpacingFix = Util.getParameter("letter_spacing_fix") != "0";
	public static var useForcedUpdateTextWidth = Util.getParameter("forced_textwidth_update") != "0";
	public static var checkTextNodeWidth = Native.isNew && Util.getParameter("text_node_width") != "0";
	public static var IosOnSelectWorkaroundEnabled = Platform.isIOS && Platform.isSafari && Platform.browserMajorVersion < 15;

	public static inline var UPM : Float = 2048.0;  // Const.
	private var renderStage : FlowContainer;
	private var text : String = '';
	private static var dummyContentGlyphs : TextMappedModification = new TextMappedModification("", "", [], []);
	private var contentGlyphs : TextMappedModification = dummyContentGlyphs;
	private var contentGlyphsDirection : String = '';
	public var charIdx : Int = 0;
	private var backgroundColor : Int = 0;
	private var backgroundOpacity : Float = 0.0;
	private var cursorColor : Int = -1;
	private var cursorOpacity : Float = -1.0;
	private var cursorWidth : Float = 2;
	private var textDirection : String = '';
	private var escapeHTML : Bool = true;
	private var skipOrderCheck : Bool = false;
	private var style : Dynamic = new TextStyle();

	private var type : String = 'text';
	private var autocomplete : String = '';
	private var step : Float = 1.0;
	private var doNotInvalidateStage : Bool = false;
	private var cropWords : Bool = false;
	private var autoAlign : String = 'AutoAlignNone';
	private var readOnly : Bool = false;
	private var maxChars : Int = -1;

	private var cursorPosition : Int = 0;
	private var selectionStart : Int = 0;
	private var selectionEnd : Int = 0;

	private var background : FlowGraphics = null;

	private var metrics : Dynamic;
	private static var measureElement : Dynamic;
	private static var measureRange : Dynamic;
	private var multiline : Bool = false;

	private var TextInputFilters : Array<String -> String> = new Array();
	private var TextInputEventFilters : Array<String -> String -> String> = new Array();
	private var TextInputKeyDownFilters : Array<String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool> = new Array();
	private var TextInputKeyUpFilters : Array<String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool> = new Array();

	private var textClip : Text = null;
	private var textClipChanged : Bool = false;

	private var isInput : Bool = false;
	private var isFocused : Bool = false;
	public var isInteractive : Bool = false;
	public var preventContextMenu : Bool = false;

	private var textBackgroundWidget : Dynamic;
	private static var useTextBackgroundWidget : Bool = false;
	private var amiriItalicWorkaroundWidget : Dynamic;
	private var baselineWidget : Dynamic;
	private var needBaseline : Bool = true;

	private var doNotRemap : Bool = false;
	private var preventSelectEvent : Bool = false;
	private var preventMouseUpEvent : Bool = false;
	private var preventEnsureCurrentInputVisible : Bool = false;

	public function new(?worldVisible : Bool = false) {
		super(worldVisible);

		style.resolution = 1.0;
		style.wordWrap = false;
		style.wordWrapWidth = 2048.0;

		this.keepNativeWidget = KeepTextClips;
	}

	public static function recalculateUseTextBackgroundWidget() {
		useTextBackgroundWidget = RenderSupport.RendererType == "html" && Util.getParameter("textBackgroundWidget") != "0";
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
			|| (code >= 0xA1 && code < 0x590)     // Extended latin, diacritics, greeks, cyrillics, and other LTR alphabet letters, also symbols.
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

		var scriptingFixSuffix = "";  // Helps to keep substring ending letter form when measuring with Pixi.
		if (isRtlChar(tm.text.substr(eochi, 1))) scriptingFixSuffix = "ث";  // Any letter with 4 variants.
		var mtxb : Dynamic = pixi.core.text.TextMetrics.measureText(tm.text.substr(0, bochi)+scriptingFixSuffix, style);
		var mtxe : Dynamic = pixi.core.text.TextMetrics.measureText(tm.text.substr(0, eochi)+scriptingFixSuffix, style);

		return mtxe.width - mtxb.width;
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
		if (metrics == null && !isInput && escapeHTML) {
			return;
		}

		super.updateNativeWidgetStyle();
		var alpha = this.getNativeWidgetAlpha();

		if (isInput) {
			nativeWidget.setAttribute("inputMode", type == 'number' ? 'numeric' : type);
			if (!multiline) {
				nativeWidget.setAttribute("type", type);
			}
			nativeWidget.value = text;
			nativeWidget.style.whiteSpace = "pre-wrap";
			nativeWidget.style.pointerEvents = readOnly ? 'none' : 'auto';
			nativeWidget.readOnly = readOnly;

			if (cursorColor >= 0) {
				nativeWidget.style.caretColor = RenderSupport.makeCSSColor(cursorColor, cursorOpacity);
			}

			if (type == 'number') {
				nativeWidget.step = step;
				nativeWidget.addEventListener('wheel', function(e) {e.preventDefault();});
			}

			nativeWidget.autocomplete = autocomplete != '' ? autocomplete : 'off';

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
				nativeWidget.style.opacity = (RenderSupport.RendererType != "canvas" || isFocused) ? alpha : 0;
				nativeWidget.style.color = style.fill;
			}
		} else {
			if (escapeHTML) {
				if (Platform.isIE && isMaterialIconFont()) {
					nativeWidget.textContent = this.contentGlyphs.modified;
				} else {
					var textContent = calculateTextContent();
					nativeWidget.textContent = textContent;
					if (textBackgroundWidget != null) {
						textBackgroundWidget.textContent = textContent;
					}
				}

				nativeWidget.style.whiteSpace = isJapaneseFont(style) && style.wordWrap ? "pre-wrap" : "pre";
				baselineWidget.style.direction = nativeWidget.style.direction = switch (this.textDirection) {
					case 'RTL' : 'rtl';
					case 'rtl' : 'rtl';
					default : null;
				}
			} else {
				nativeWidget.innerHTML = this.contentGlyphs.modified;
				if (textBackgroundWidget != null) {
					textBackgroundWidget.innerHTML = this.contentGlyphs.modified;
				}
				nativeWidget.style.whiteSpace = (Native.isNew && !style.wordWrap) ? "pre" : "pre-wrap";

				var children : Array<Dynamic> = nativeWidget.getElementsByTagName("*");
				for (child in children) {
					if (child != baselineWidget) {
						child.className = "inlineWidget";
					}
				}

				baselineWidget.style.direction = nativeWidget.style.direction = switch (this.textDirection) {
					case 'RTL' : 'rtl';
					case 'rtl' : 'rtl';
					default : null;
				}
			}

			nativeWidget.style.opacity = alpha != 1 || Platform.isIE ? alpha : null;
			nativeWidget.style.color = style.fill;
		}

		nativeWidget.style.letterSpacing = !this.isHTMLRenderer() || style.letterSpacing != 0 ? '${style.letterSpacing}px' : null;
		nativeWidget.style.wordSpacing = !this.isHTMLRenderer() || style.wordSpacing != 0 ? '${style.wordSpacing}px' : null;
		nativeWidget.style.fontFamily = !this.isHTMLRenderer() || Platform.isIE || style.fontFamily != "Roboto" ? style.fontFamily : null;
		nativeWidget.style.fontWeight = !this.isHTMLRenderer() || style.fontWeight != 400 ? style.fontWeight : null;
		nativeWidget.style.fontStyle = !this.isHTMLRenderer() || style.fontStyle != 'normal' ? style.fontStyle : null;
		nativeWidget.style.fontSize = '${style.fontSize}px';
		var bg = !this.isHTMLRenderer() || backgroundOpacity > 0 ? RenderSupport.makeCSSColor(backgroundColor, backgroundOpacity) : null;
		if (textBackgroundWidget != null) {
			textBackgroundWidget.style.background = bg;
		} else {
			nativeWidget.style.background = bg;
		}
		nativeWidget.wrap = style.wordWrap ? 'soft' : 'off';
		nativeWidget.style.lineHeight = '${DisplayObjectHelper.round(!isMaterialIconFont() || metrics == null ? style.lineHeight + style.leading : metrics.height)}px';

		nativeWidget.style.textAlign = switch (autoAlign) {
			case 'AutoAlignLeft' : null;
			case 'AutoAlignRight' : 'right';
			case 'AutoAlignCenter' : 'center';
			case 'AutoAlignJustify' : 'justify';
			case 'AutoAlignNone' : 'none';
			default : null;
		}
		if (nativeWidget.style.textAlign == 'justify') {
			nativeWidget.style.whiteSpace = "normal";
		}

		updateTextBackgroundWidget();
		updateBaselineWidget();
	}

	public inline function updateBaselineWidget() : Void {
		if (this.isHTMLRenderer() && isNativeWidget && needBaseline) {
			if (!isInput && nativeWidget.firstChild != null && !isMaterialIconFont()) {
				// For some fonts italic form has a smaller height, so baseline becomes occasionally unsynchronised with normal-style glyphs on different zoom levels
				if (style.fontStyle == 'italic') {
					var lineHeightGap = getLineHeightGap();
					var transform = DisplayObjectHelper.getNativeWidgetTransform(this);
					var top = DisplayObjectHelper.round(transform.ty);
					baselineWidget.style.height = '${Math.round(style.fontProperties.fontSize + lineHeightGap + top)}px';
					textBackgroundWidget.style.top = '${Math.round(getTextMargin() + lineHeightGap + top)}px';
					nativeWidget.style.top = 0;
				} else {
					baselineWidget.style.height = '${Math.round(style.fontProperties.fontSize + getLineHeightGap())}px';
				}
				
				baselineWidget.style.direction = textDirection;
				nativeWidget.style.marginTop = '${-getTextMargin()}px';
				nativeWidget.insertBefore(baselineWidget, nativeWidget.firstChild);
				updateAmiriItalicWorkaroundWidget();
			} else if (baselineWidget.parentNode != null) {
				baselineWidget.parentNode.removeChild(baselineWidget);
			}
		}
	}

	private function updateAmiriItalicWorkaroundWidget() : Void {
		// For some reason, in most browsers Amiri italic text, which starts from digit/special symbol doesn't render italic, when baselineWidget is present.
		// Looks like a browser bug, so we need this workaround
		if ((Platform.isChrome || Platform.isEdge) && style.fontFamily == 'Amiri' && style.fontStyle == 'italic'
			&& nativeWidget.textContent[0] != '' && !isCharLetter(nativeWidget.textContent[0])
		) {
			if (amiriItalicWorkaroundWidget == null) {
				var txt = 't';
				var charMetrics = TextMetrics.measureText(txt, style);
				amiriItalicWorkaroundWidget = Browser.document.createElement('span');
				amiriItalicWorkaroundWidget.style.position = 'relative';
				amiriItalicWorkaroundWidget.style.marginRight = '${-charMetrics.width}px';
				amiriItalicWorkaroundWidget.style.opacity = '0';
				amiriItalicWorkaroundWidget.textContent = txt;
				nativeWidget.insertBefore(amiriItalicWorkaroundWidget, nativeWidget.firstChild);
			}
		}
	}

	private function isCharLetter(char : String) : Bool {
		return char.toLowerCase() != char.toUpperCase();
	}

	public inline function updateTextBackgroundWidget() : Void {
		if (useTextBackgroundWidget && nativeWidget.firstChild && textBackgroundWidget != null && textBackgroundWidget.style.background != '') {
			nativeWidget.insertBefore(textBackgroundWidget, nativeWidget.firstChild);
			textBackgroundWidget.style.top = '${getTextMargin()}px';
		}
	}

	public function getTextMargin() : Float {
		return DisplayObjectHelper.round(style.fontProperties.descent * this.getNativeWidgetTransform().d);
	}

	public function getLineHeightGap() : Float {
		return (style.lineHeight - Math.ceil(style.fontSize * 1.15)) / 2.0;
	}

	public function calculateTextContent() : String {
		var textContent = "";

		var textLines : Array<String> = metrics.lines;
		for (line in textLines) {
			textContent = textContent + line + "\n";
		}

		if (textLines.length > 0) {
			textContent = textContent.substring(0, textContent.length - 1);
		}
		return textContent;
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

	public static function isJapaneseFont(st) : Bool {
		return st.fontFamily == "Meiryo" || st.fontFamily == "MeiryoBold";
	}

	public static var isMeiryoAvailable = false;
	public static function useHTMLMeasurementJapaneseFont(st) : Bool {
		if (isMeiryoAvailable) return false;
		var checkMeyrioFont = function() {
			var res = false;
			untyped __js__('document.fonts.forEach(v => {
				if (!res) {
					res = v.family == "Meiryo";
				}
			})');
			if (res) isMeiryoAvailable = true;
			return res;
		}
		return isJapaneseFont(st) && !checkMeyrioFont();
	}

	private static var ffMap : Dynamic;

	public function setTextAndStyle(text : String, fontFamilies : String, fontSize : Float, fontWeight : Int, fontSlope : String, fillColor : Int,
		fillOpacity : Float, letterSpacing : Float, backgroundColor : Int, backgroundOpacity : Float) : Void {

		RenderSupport.emitUserStyleChanged();

		if (fontWeight > 0 || fontSlope != "") {
			untyped __js__("
			if (TextClip.ffMap === undefined) TextClip.ffMap = {}
			if (TextClip.ffMap[fontFamilies] === undefined) {
				TextClip.ffMap[fontFamilies] = fontFamilies.split(',').map(function(fontFamily){ return TextClip.recognizeBuiltinFont(fontFamily, fontWeight, fontSlope); }).join(',');
			}
			fontFamilies = TextClip.ffMap[fontFamilies];
			");
		}

		// In Firefox canvas ignores 'lang' attribute, so for arabic different fallback fonts are used for measuring and rendering.
		// To fix it let`s set fallback fonts explicitly
		if (Platform.isFirefox && RenderSupport.RendererType == "html" && Browser.document.documentElement.lang == "ar" && StringTools.startsWith(fontFamilies, "Roboto")) {
			if (Platform.isWindows) {
				fontFamilies += ", Segoe UI";
			} else if (Platform.isLinux) {
				fontFamilies += ", DejaVu Sans";
			} else if (Platform.isMacintosh) {
				fontFamilies += ", Geeza Pro";
			}
		}

		if (Platform.isSafari) {
			fontSize = Math.round(fontSize);
		}

		var fontStyle : FontStyle = FlowFontStyle.fromFlowFonts(fontFamilies);
		this.doNotRemap = fontStyle.doNotRemap;

		this.style.fontSize = Math.max(fontSize, 0.6);
		this.style.fill = RenderSupport.makeCSSColor(fillColor, fillOpacity);
		if (untyped Math.isFinite(RenderSupport.UserDefinedLetterSpacingPercent) && RenderSupport.UserDefinedLetterSpacingPercent != 0.0) {
			this.style.letterSpacing = untyped RenderSupport.UserDefinedLetterSpacingPercent * this.style.fontSize;
		} else if (untyped Math.isFinite(RenderSupport.UserDefinedLetterSpacing) && RenderSupport.UserDefinedLetterSpacing != 0.0) {
			this.style.letterSpacing = untyped RenderSupport.UserDefinedLetterSpacing;
		} else {
			this.style.letterSpacing = letterSpacing;
		}
		this.style.fontFamily = fontStyle.family;
		this.style.fontWeight = fontWeight != 400 ? '${fontWeight}' : fontStyle.weight;
		this.style.fontStyle = fontSlope != '' ? fontSlope : fontStyle.style;
		var lineHeightPercent = this.style.lineHeightPercent != null ? this.style.lineHeightPercent : untyped RenderSupport.UserDefinedLineHeightPercent;
		this.style.lineHeight = Math.ceil(lineHeightPercent * this.style.fontSize);
		this.style.align = autoAlign == 'AutoAlignRight' ? 'right' : autoAlign == 'AutoAlignCenter' ? 'center' : 'left';
		this.style.padding = Math.ceil(fontSize * 0.2);

		if (untyped Math.isFinite(RenderSupport.UserDefinedWordSpacingPercent) && RenderSupport.UserDefinedWordSpacingPercent != 0.0) {
			this.style.wordSpacing = untyped RenderSupport.UserDefinedWordSpacingPercent * this.style.fontSize;
		}

		measureFont();

		untyped __js__("this.text = (text !== '' && text.charAt(text.length-1) === '\\n') ? text.slice(0, text.length-1) : text");
		this.contentGlyphs = applyTextMappedModification(this.isHTMLRenderer() ? adaptWhitespaces(this.text) : this.text);
		this.contentGlyphsDirection = getStringDirection(this.contentGlyphs.text, this.textDirection);

		this.backgroundColor = backgroundColor;
		this.backgroundOpacity = backgroundOpacity;

		// Force text value right away
		if (nativeWidget != null && isInput) {
			var selectionStartPrev = nativeWidget.selectionStart;
			var selectionEndPrev = nativeWidget.selectionEnd;
			nativeWidget.value = text;
			setSelection(selectionStartPrev, selectionEndPrev);
		}

		if (this.isHTMLRenderer()) {
			this.initNativeWidget(isInput ? (multiline ? 'textarea' : 'input') : 'p');
		}

		invalidateMetrics();
	}

	public function setLineHeightPercent(lineHeightPercent : Float) : Void {
		this.style.lineHeightPercent = lineHeightPercent;
	}

	public function setEscapeHTML(escapeHTML : Bool) : Void {
		if (this.escapeHTML != escapeHTML) {
			this.escapeHTML = escapeHTML;
			invalidateMetrics();
		}
	}

	public function setTextWordSpacing(spacing : Float) : Void {
		if (this.style.wordSpacing != spacing) {
			this.style.wordSpacing = spacing;
			updateTextMetrics();
			this.emitEvent('textwidthchanged', metrics != null ? metrics.width : 0.0);
		}
	}

	public function setNeedBaseline(need : Bool) : Void {
		if (this.needBaseline != need) {
			this.needBaseline = need;
			updateBaselineWidget();
		}
	}

	private function measureFont() : Void {
		untyped __js__("this.style.fontProperties = PIXI.TextMetrics.measureFont(this.style.toFontString(), this.style.fontSize);");
	}

	private function layoutText() : Void {
		if (isFocused || text == '') {
			if (textClip != null) {
				textClip.setClipVisible(false);
			}
		} else if (textClipChanged) {
			var modification : TextMappedModification = this.contentGlyphs;
			var text = modification.modified;
			var chrIdx: Int = 0;
			var texts = style.wordWrap ? [[text]] : checkTextLength(text);

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

			if (isMaterialIconFont()) {
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
			if (!this.isHTMLRenderer()) {
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
		if (style.wordWrap != wordWrap) {
			style.wordWrap = wordWrap;

			invalidateMetrics();
		}
	}

	public  function setDoNotInvalidateStage(doNotInvalidateStage : Bool) : Void {
		if (this.doNotInvalidateStage != doNotInvalidateStage) {
			this.doNotInvalidateStage = doNotInvalidateStage;
		}
	}

	public override function setWidth(widgetWidth : Float) : Void {
		style.wordWrapWidth = widgetWidth > 0 ? isMaterialIconFont() ? widgetWidth : Math.ceil(widgetWidth) : 2048.0;
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
			this.contentGlyphsDirection = getStringDirection(this.contentGlyphs.text, this.textDirection);

			invalidateStyle();
			invalidateMetrics();
			layoutText();
		}
	}

	public function setTextSkipOrderCheck(skip : Bool) : Void {
		this.skipOrderCheck = skip;
	}

	public function getTextDirection() : String {
		return this.textDirection != '' ? this.textDirection : this.contentGlyphsDirection;
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

	public function setPreventContextMenu(preventContextMenu : Bool) {
		if (this.preventContextMenu != preventContextMenu) {
			this.preventContextMenu = preventContextMenu;

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

		if (!this.keepNativeWidget) {
			this.keepNativeWidget = true;
			this.updateKeepNativeWidgetChildren();
		}

		this.initNativeWidget(multiline ? 'textarea' : 'input');
		isInteractive = true;
		this.invalidateInteractive();

		this.renderStage = RenderSupport.PixiStage;

		if (Platform.isMobile) {
			if (Platform.isAndroid || (Platform.isSafari && Platform.browserMajorVersion >= 13)) {
				nativeWidget.onpointermove = onMouseMove;
				nativeWidget.onpointerdown = onMouseDown;
				nativeWidget.onpointerup = onMouseUp;
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
		nativeWidget.oninput = onInput;
		nativeWidget.addEventListener('compositionend', function() { emit("compositionend"); });
		nativeWidget.addEventListener('scroll', onScroll);
		nativeWidget.addEventListener('keydown', onKeyDown);
		nativeWidget.addEventListener('keyup', onKeyUp);
		nativeWidget.addEventListener('contextmenu', onContextMenu);
		if (IosOnSelectWorkaroundEnabled) {
			nativeWidget.addEventListener('select', onSelect);
		}

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
		var rootPos = RenderSupport.getRenderRootPos(this.renderStage);
		var mousePos = RenderSupport.getMouseEventPosition(e, rootPos);

		if (isFocused) {
			checkPositionSelection();
		}

		if (e.touches != null) {
			if (e.touches.length == 1) {
				var touchPos = RenderSupport.getMouseEventPosition(e.touches[0], rootPos);
				RenderSupport.setMousePosition(touchPos);
				this.renderStage.emit("mousemove");
			} else if (e.touches.length > 1) {
				var touchPos1 = RenderSupport.getMouseEventPosition(e.touches[0], rootPos);
				var touchPos2 = RenderSupport.getMouseEventPosition(e.touches[1], rootPos);
				GesturesDetector.processPinch(touchPos1, touchPos2);
			}
		} else if (!Platform.isMobile || e.pointerType == null || e.pointerType != 'touch' || !RenderSupport.isMousePositionEqual(mousePos)) {
			RenderSupport.setMousePosition(mousePos);
			this.renderStage.emit("mousemove");
		}

		nativeWidget.style.cursor = RenderSupport.PixiView.style.cursor;

		e.stopPropagation();
	}

	private function onMouseDown(e : Dynamic) {
		var rootPos = RenderSupport.getRenderRootPos(this.renderStage);
		var mousePos = RenderSupport.getMouseEventPosition(e, rootPos);

		if (isFocused) {
			checkPositionSelection();
		} else {
			var point = e.touches != null && e.touches.length > 0 ? RenderSupport.getMouseEventPosition(e.touches[0], rootPos) : mousePos;
			var pointScaled = new Point(point.x * RenderSupport.getViewportScale(), point.y * RenderSupport.getViewportScale());

			RenderSupport.setMousePosition(point);

			if (RenderSupport.getClipAt(this.renderStage, pointScaled, true, 0.16) != this) {
				e.preventDefault();
			}
		}

		if (e.touches != null) {
			RenderSupport.TouchPoints = e.touches;
			RenderSupport.emit("touchstart");

			if (e.touches.length == 1) {
				var touchPos = RenderSupport.getMouseEventPosition(e.touches[0], rootPos);
				RenderSupport.setMousePosition(touchPos);
				if (RenderSupport.MouseUpReceived) this.renderStage.emit("mousedown");
			} else if (e.touches.length > 1) {
				var touchPos1 = RenderSupport.getMouseEventPosition(e.touches[0], rootPos);
				var touchPos2 = RenderSupport.getMouseEventPosition(e.touches[1], rootPos);
				GesturesDetector.processPinch(touchPos1, touchPos2);
			}
		} else if (!Platform.isMobile || e.pointerType == null || e.pointerType != 'touch' || !RenderSupport.isMousePositionEqual(mousePos)) {
			RenderSupport.setMousePosition(mousePos);

			if (e.which == 3 || e.button == 2) {
				this.renderStage.emit("mouserightdown");
			} else if (e.which == 2 || e.button == 1) {
				this.renderStage.emit("mousemiddledown");
			} else if (e.which == 1 || e.button == 0) {
				if (RenderSupport.MouseUpReceived) this.renderStage.emit("mousedown");
			}
		}

		e.stopPropagation();
	}

	private function onMouseUp(e : Dynamic) {
		var rootPos = RenderSupport.getRenderRootPos(this.renderStage);
		var mousePos = RenderSupport.getMouseEventPosition(e, rootPos);

		if (isFocused) {
			checkPositionSelection();
		}

		if (e.touches != null) {
			RenderSupport.TouchPoints = e.touches;
			RenderSupport.emit("touchend");

			GesturesDetector.endPinch();

			if (e.touches.length == 0) {
				if (!RenderSupport.MouseUpReceived) this.renderStage.emit("mouseup");
			}
		} else if (!Platform.isMobile || e.pointerType == null || e.pointerType != 'touch' || !RenderSupport.isMousePositionEqual(mousePos)) {
			RenderSupport.setMousePosition(mousePos);

			if (e.which == 3 || e.button == 2) {
				this.renderStage.emit("mouserightup");
			} else if (e.which == 2 || e.button == 1) {
				this.renderStage.emit("mousemiddleup");
			} else if (e.which == 1 || e.button == 0) {
				if (!RenderSupport.MouseUpReceived) this.renderStage.emit("mouseup");
			}
		}

		e.stopPropagation();
		if (preventMouseUpEvent) {
			e.preventDefault();
			preventMouseUpEvent = false;
		}
	}

	private function onFocus(e : Event) : Void {
		isFocused = true;

		if (RenderSupport.Animating) {
			RenderSupport.once("stagechanged", function() { if (nativeWidget != null && isFocused) nativeWidget.focus(); });
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

		if (Platform.isIOS && (Platform.browserMajorVersion < 13 || EnsureInputIOS)) {
			if (!this.preventEnsureCurrentInputVisible) {
				RenderSupport.ensureCurrentInputVisible();
				// Intended for first focusing into wigi editor after page reload (for some reason, onFocus duplicates in this case).
				this.preventEnsureCurrentInputVisible = true;
			}
		}

		if (IosOnSelectWorkaroundEnabled) {
			Browser.document.addEventListener('selectionchange', onSelectionChange);
		}

		invalidateMetrics();
	}

	private function onBlur(e : Event) : Void {
		this.preventEnsureCurrentInputVisible = false;
		if (untyped RenderSupport.Animating || this.preventBlur) {
			RenderSupport.once("stagechanged", function() { if (nativeWidget != null && isFocused) nativeWidget.focus(); });
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

		if (IosOnSelectWorkaroundEnabled) {
			Browser.document.removeEventListener('selectionchange', onSelectionChange);
		}

		invalidateMetrics();
	}

	private function onInput(e : Dynamic) {
		// On iOS in numeric mode you can still input non-number characters. They will be shown visually but wrong characters will clear 'value'.
		// Here we are resetting visual representation to be consistent
		if (Platform.isIOS && type == 'number' && nativeWidget.value == '') {
			nativeWidget.value = '';
		}
		// Nothing changed, prevent from double handling
		if (nativeWidget.value == this.text) {
			return;
		}

		// Some browsers tend to return nativeWidget.value without decimal separator at the end, but still visually display it
		var decimalSeparatorFix = type == 'number' && (e.data == '.' || e.data == ',');
		var nativeWidgetValue = decimalSeparatorFix ? nativeWidget.value + e.data : nativeWidget.value;
		var newValue : String = nativeWidgetValue;

		if (maxChars > 0) {
			newValue = newValue.substr(0, maxChars);
		}

		for (f in TextInputFilters) {
			newValue = f(newValue);
		}

		// Hotfix for IE : inputType isn`t implemented for IE, so in this case we fake all the events to have "insertText" type
		if (e != null && (e.inputType != null || Platform.isIE)) {
			for (f in TextInputEventFilters) {
				newValue = f(newValue, Platform.isIE ? "insertText" : e.inputType);
			}
		}

		if (nativeWidget == null) {
			return;
		}

		var setNewValue = function(val) {
			if ((Platform.isChrome || Platform.isEdge) && decimalSeparatorFix) {
				nativeWidget.value = '';
			}
			nativeWidget.value = val;
		}

		if (newValue != nativeWidgetValue) {
			if (e != null && e.data != null && e.data.length != null) {
				var newCursorPosition : Int = untyped cursorPosition + newValue.length - nativeWidget.value.length + e.data.length;
				setNewValue(newValue);
				setSelection(newCursorPosition, newCursorPosition);
			} else {
				setNewValue(newValue);
			}
		} else {
			var selectionStart = getSelectionStart();
			var selectionEnd = getSelectionEnd();

			setSelection(selectionStart, selectionEnd);
		}

		this.text = newValue;
		this.contentGlyphs = applyTextMappedModification(adaptWhitespaces(this.text));
		this.contentGlyphsDirection = getStringDirection(this.contentGlyphs.text, this.textDirection);
		emit('input', newValue);

		if (Platform.isAndroid) {
			Native.timer(0, function() {
				RenderSupport.ensureCurrentInputVisible();
			});
		}
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
					e.stopPropagation();
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
					e.stopPropagation();
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

	public function onContextMenu(e) {
		if (this.preventContextMenu) e.preventDefault();
	}

	public function onSelect(e) {
		emit("selectall");
		preventSelectEvent = true;
	}

	public function onSelectionChange() {
		if (isFocused) {
			checkPositionSelection();

			if (!preventSelectEvent && getCursorPosition() != getSelectionEnd()) {
				emit("selectionchange");
			}
			preventSelectEvent = false;
		}
	}

	public function temporarilyPreventBlur() {
		if (this.isFocused) {
			untyped this.preventBlur = true;

			RenderSupport.once("stagechanged", function() {
				untyped this.preventBlur = false;
			});
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
		return (widgetWidth > 0 ? widgetWidth : getClipWidth());
	}

	public function getMaxWidth() : Float {
		updateTextMetrics();
		return metrics != null ? untyped metrics.maxWidth : 0;
	}

	public override function getHeight() : Float {
		return widgetHeight > 0 ? widgetHeight : getClipHeight();
	}

	private function getClipWidth() : Float {
		updateTextMetrics();
		return metrics != null ? (untyped Platform.isSafari && !isInput && !escapeHTML ? Math.ceil(metrics.width) : metrics.width) : 0;
	}

	private function getClipHeight() : Float {
		updateTextMetrics();
		return metrics != null ? untyped metrics.height : 0;
	}

	public function getContent() : String {
		return text;
	}

	public function getContentGlyphs() : TextMappedModification {
		return this.contentGlyphs;
	}

	private function applyTextMappedModification(text : String) : TextMappedModification {
		if (isInput && type == "password") {
			return getBulletsString(text);
		} else {
			//return getActualGlyphsString(this.text);  // Maybe worth to return this line for C++ target instead next one which is good for JS target.
			return TextMappedModification.createInvariantForString(text);
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

			var re : Dynamic = nativeWidget.createTextRange();
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
		// setSelectionRange triggers 'focusin' event in Safari
		if (Platform.isSafari && ((start == -1 || end == -1) || (start == nativeWidget.selectionStart && end == nativeWidget.selectionEnd))) {
			return;
		}
		// Chrome doesn't support this method for 'number' inputs
		try {
			nativeWidget.setSelectionRange(start, end);
			if (start == nativeWidget.value.length && end == nativeWidget.value.length) {
				nativeWidget.scrollLeft = nativeWidget.scrollWidth;
			}
			if (!(Platform.isIOS && Platform.isChrome)) {
				preventMouseUpEvent = true;
			}
		} catch (e : Dynamic) {
			return;
		}
	}

	public function addTextInputFilter(filter : String -> String) : Void -> Void {
		TextInputFilters.push(filter);
		return function() { TextInputFilters.remove(filter); }
	}

	public function addTextInputEventFilter(filter : String -> String -> String) : Void -> Void {
		TextInputEventFilters.push(filter);
		return function() { TextInputEventFilters.remove(filter); }
	}

	public function addTextInputKeyDownEventFilter(filter : String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool) : Void -> Void {
		TextInputKeyDownFilters.push(filter);
		return function() { TextInputKeyDownFilters.remove(filter); }
	}

	public function addTextInputKeyUpEventFilter(filter : String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool) : Void -> Void {
		TextInputKeyUpFilters.push(filter);
		return function() { TextInputKeyUpFilters.remove(filter); }
	}

	public function addOnCopyEventListener(fn : (String -> Void) -> Void) : Void -> Void {
		var onCopy = function(e) {
			var setClipboardData = function(newText) {
				e.preventDefault();
				untyped e.clipboardData.setData('text/plain', newText);
			}
			fn(setClipboardData);
		}
		if (nativeWidget) nativeWidget.addEventListener('copy', onCopy);
		return function() {
			if (nativeWidget) nativeWidget.removeEventListener('copy', onCopy);
		}
	}

	private function updateTextMetrics() : Void {
		if (metrics == null && untyped text != "" && style.fontSize > 1.0) {
			if (!escapeHTML) {
				var contentGlyphsModified = untyped __js__("this.contentGlyphs.modified.replace(/<\\/?[^>]+(>|$)/g, '')");
				metrics = TextMetrics.measureText(contentGlyphsModified, style);
				if (this.isHTMLRenderer()) {
					measureHTMLWidthAndHeight();
				}
			} else {
				metrics = TextMetrics.measureText(this.contentGlyphs.modified, style);
				if (this.isHTMLRenderer()) {
					if (useHTMLMeasurementJapaneseFont(style)) {
						measureHTMLSize();
					} else {
						if (checkTextNodeWidth && style.fontStyle == 'italic') measureHTMLWidth();
					}
				}
			}

			metrics.maxWidth = 0.0;
			var lineWidths : Array<Float> = metrics.lineWidths;

			for (lineWidth in lineWidths) {
				metrics.maxWidth += lineWidth;
			}

			metrics.maxWidth = Math.max(metrics.width, metrics.maxWidth);

			if (!this.cropWords && widgetWidth > 0 && metrics.width > widgetWidth) {
				super.setWidth(metrics.width);
			}
		}

		if (useForcedUpdateTextWidth) {
			try {
				if (Browser.document.fonts.status == LOADING) {
					Browser.document.fonts.addEventListener('loadingdone', function() {
						RenderSupport.defer(function() {
							updateTextWidth();
							if (style.wordWrap) {
								updateTextMetrics();
								this.emitEvent('textwidthchanged', metrics.width);
							}
						}, 600);
					});
				}
			} catch (e : Dynamic) {}
		}


		if (Platform.isSafari && Platform.isMacintosh && RenderSupport.getAccessibilityZoom() == 1.0 && untyped text != "" && !isMaterialIconFont()) {
			RenderSupport.defer(updateTextWidth, 0);
		}
	}

	private function updateTextWidth() : Void {
		if (nativeWidget != null && metrics != null) {
			var textNodeMetrics = getTextNodeMetrics(nativeWidget);
			var textNodeWidth0 = textNodeMetrics.width;
			var textNodeHeight = textNodeMetrics.height;
			if (textNodeWidth0 != null && textNodeWidth0 > 0 && textNodeHeight != null && textNodeHeight > 0) {
				var textNodeWidth = useLetterSpacingFix ? (textNodeWidth0 - style.letterSpacing) : textNodeWidth0;
				var textWidth =
					untyped this.transform
						? (
							(textNodeWidth * (1 - Math.pow(untyped this.transform.worldTransform.c, 2)) / untyped this.transform.worldTransform.a)
							+ Math.abs(textNodeHeight * untyped this.transform.worldTransform.c)
						)
						: textNodeWidth;
				if (textWidth > 0 && textWidth != metrics.width) {
					metrics.width = textWidth;
					this.emitEvent('textwidthchanged', textWidth);
				}
			}
		}
	}

	private static var metricsCache = new Map();
	private function measureHTMLSize() : Void {
		if (Browser.document.createRange == null && nativeWidget == null) return;

		if (TextClip.measureElement == null) {
			TextClip.measureElement = Browser.document.createElement('p');
			TextClip.measureElement.id = 'measureTextElement';
			TextClip.measureElement.classList.add('nativeWidget');
			TextClip.measureElement.classList.add('textWidget');
			TextClip.measureElement.setAttribute('aria-hidden', 'true');
			Browser.document.body.appendChild(TextClip.measureElement);
		}

		if (TextClip.measureRange == null) {
			TextClip.measureRange = Browser.document.createRange();
		}

		var measureElement = TextClip.measureElement;
		var measureRange = TextClip.measureRange;

		updateNativeWidgetStyle();

		var cacheKey = nativeWidget.textContent + '\n${nativeWidget.style.fontSize}\n${nativeWidget.style.fontWeight}';
		var cachedMetrics = metricsCache.get(cacheKey);
		if (cachedMetrics != null) {
			metrics.width = cachedMetrics.width;
			metrics.height = cachedMetrics.height;
			return;
		}

		measureElement.style.fontFamily = nativeWidget.style.fontFamily;
		measureElement.style.fontSize = nativeWidget.style.fontSize;
		measureElement.style.fontWeight = nativeWidget.style.fontWeight;
		measureElement.style.wrap = nativeWidget.style.wrap;
		measureElement.style.whiteSpace = nativeWidget.style.whiteSpace;
		measureElement.style.display = nativeWidget.style.display;

		var wordWrap = style.wordWrapWidth != null && style.wordWrap && style.wordWrapWidth > 0;
		if (wordWrap) {
			measureElement.style.width = '${style.wordWrapWidth}px';
		} else {
			measureElement.style.width = 'max-content';
		}

		measureElement.textContent = nativeWidget.textContent;

		measureRange.selectNodeContents(measureElement);
		if (measureRange.getBoundingClientRect != null) {
			var rect = measureRange.getBoundingClientRect();
			if (rect != null) {
				var viewportScale = RenderSupport.getViewportScale();
				var textNodeWidth = (rect.right - rect.left) * viewportScale;
				var textNodeHeight = (rect.bottom - rect.top) * viewportScale;

				if (textNodeWidth >= 0.) {
					metrics.width = textNodeWidth;
				}

				if (textNodeHeight >= 0. && metrics.lineHeight > 0) {
					var textNodeLines = Math.round(textNodeHeight / metrics.lineHeight);
					var currentLines = Math.round(metrics.height / metrics.lineHeight);

					if (currentLines > 0 && textNodeLines != currentLines) {
						metrics.height = metrics.height * textNodeLines / currentLines;
					}
				}

				if (textNodeWidth >= 0. && textNodeHeight >= 0.) {
					metricsCache.set(cacheKey, {width : textNodeWidth, height : textNodeHeight});
				}
			}
		}

		measureElement.style.display = 'none';
	}

	private function measureHTMLWidth() : Void {
		measureHTMLWidthAndHeight(false);
	}

	private function measureHTMLWidthAndHeight(?shouldUpdateHeight : Bool = true) : Void {
		if (nativeWidget == null) {
			isNativeWidget = true;
			createNativeWidget(isInput ? (multiline ? 'textarea' : 'input') : 'p');
		}

		var textNodeMetrics : Dynamic = null;
		var wordWrap = style.wordWrapWidth != null && style.wordWrap && style.wordWrapWidth > 0;
		var parentNode : Dynamic = nativeWidget.parentNode;
		var nextSibling : Dynamic = nativeWidget.nextSibling;

		updateNativeWidgetStyle();
		var tempDisplay = nativeWidget.style.display;
		if (!Platform.isIE) {
			nativeWidget.style.display = null;
		} else {
			nativeWidget.style.display = "block";
		}

		if (wordWrap) {
			nativeWidget.style.width = '${style.wordWrapWidth}px';
		} else {
			nativeWidget.style.width = 'max-content';
		}

		Browser.document.body.appendChild(nativeWidget);
		textNodeMetrics = getTextNodeMetrics(nativeWidget);

		if (parentNode != null) {
			if (nextSibling == null || nextSibling.parentNode != parentNode) {
				parentNode.appendChild(nativeWidget);
			} else {
				parentNode.insertBefore(nativeWidget, nextSibling);
			}
		} else {
			Browser.document.body.removeChild(nativeWidget);
		}

		nativeWidget.style.display = tempDisplay;

		if ((!wordWrap || isJapaneseFont(style)) && textNodeMetrics.width != null && textNodeMetrics.width >= 0) {
			var textNodeWidth = textNodeMetrics.width;
			metrics.width = textNodeWidth;
		}

		if (checkTextNodeWidth) {
			nativeWidget.style.paddingLeft = '${-textNodeMetrics.x}px';
		}

		if (shouldUpdateHeight && textNodeMetrics.height != null && textNodeMetrics.height >= 0 && metrics.lineHeight > 0) {
			var textNodeLines = Math.round(textNodeMetrics.height / metrics.lineHeight);
			var currentLines = Math.round(metrics.height / metrics.lineHeight);

			if (currentLines > 0 && textNodeLines != currentLines) {
				metrics.height = metrics.height * textNodeLines / currentLines;
			}
		}

		if (!this.isHTMLRenderer() && !isInput) {
			this.deleteNativeWidget();
		}
	}

	private static function getTextNodeMetrics(nativeWidget) : Dynamic {
		var textNodeMetrics : Dynamic = {};
		if (nativeWidget == null || nativeWidget.lastChild == null) {
			textNodeMetrics.width = 0;
			textNodeMetrics.height = 0;
			textNodeMetrics.x = 0;
		} else {
			var textNode = checkTextNodeWidth ? nativeWidget.lastChild : nativeWidget;
			if (checkTextNodeWidth) {
				updateTextNodesWidth(untyped nativeWidget.childNodes, textNodeMetrics);
			}
			updateTextNodeHeight(textNode, textNodeMetrics);
		}
		return textNodeMetrics;
	}

	private static function updateTextNodesWidth(children, textNodeMetrics) {
		textNodeMetrics.width = 0;
		textNodeMetrics.updateOffset = true;
		for (i in 0 ... children.length) {
			updateTextNodeWidth(children[i], textNodeMetrics);
		}
	}

	private static function updateTextNodeWidth(textNode, textNodeMetrics) {
		var svg = Browser.document.createElementNS("http://www.w3.org/2000/svg", "svg");
		var textElement = Browser.document.createElementNS("http://www.w3.org/2000/svg", "text");

		// Set font properties
		var computedStyle = Browser.window.getComputedStyle(untyped textNode.parentNode);
		textElement.setAttribute('font-family', computedStyle.fontFamily);
		textElement.setAttribute('font-size', computedStyle.fontSize);
		textElement.setAttribute('font-style', computedStyle.fontStyle);
		textElement.setAttribute('letter-spacing', computedStyle.letterSpacing);

		textElement.textContent = textNode.textContent;
		svg.appendChild(textElement);
		Browser.document.body.appendChild(svg);

		var bbox = untyped textElement.getBBox();

		Browser.document.body.removeChild(svg);

		textNodeMetrics.width += bbox.width;
		if (textNodeMetrics.updateOffset && (textNode.classList == null || !textNode.classList.contains('baselineWidget'))) {
			textNodeMetrics.x = bbox.x;
			textNodeMetrics.updateOffset = false;
		}
	}

	private static function updateTextNodeHeight(textNode, textNodeMetrics) {
		if (Browser.document.createRange != null) {
			var range = Browser.document.createRange();
			range.selectNodeContents(textNode);
			if (range.getBoundingClientRect != null) {
				var rect = range.getBoundingClientRect();
				if (rect != null) {
					var viewportScale = RenderSupport.getViewportScale();
					if (!checkTextNodeWidth) {
						textNodeMetrics.width = (rect.right - rect.left) * viewportScale;
					}
					textNodeMetrics.height = (rect.bottom - rect.top) * viewportScale;
				}
			}
		}
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

	private function isMaterialIconFont() : Bool {
		return style.fontFamily.startsWith('Material Icons');
	}

	private override function createNativeWidget(?tagName : String = "p") : Void {
		if (this.isHTMLRenderer()) {
			if (!isNativeWidget) {
				return;
			}
			var tagName2 = this.tagName != null && this.tagName != '' ? this.tagName : tagName; 

			this.deleteNativeWidget();

			nativeWidget = Browser.document.createElement(tagName2);
			if (tagName2 != 'span') {
				this.updateClipID();
			}
			nativeWidget.classList.add('nativeWidget');
			nativeWidget.classList.add('textWidget');
			if (this.className != null && this.className != '') {
				nativeWidget.classList.add(this.className);
			}

			baselineWidget = Browser.document.createElement('span');
			baselineWidget.classList.add('baselineWidget');
			baselineWidget.role = 'presentation';

			if (useTextBackgroundWidget && !isInput) {
				textBackgroundWidget = Browser.document.createElement('span');
				textBackgroundWidget.classList.add('textBackgroundWidget');
				textBackgroundWidget.classList.add('textBackgroundLayer');				
			}

			isNativeWidget = true;
		} else {
			super.createNativeWidget(tagName);
		}
	}
}
