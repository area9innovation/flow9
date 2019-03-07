import js.Browser;
import js.html.MouseEvent;
import js.html.Event;
import pixi.core.text.Text;
import pixi.core.text.TextMetrics;
import pixi.core.text.TextStyle;
import pixi.core.math.shapes.Rectangle;
import pixi.core.math.Point;

import FlowFontStyle;

using DisplayObjectHelper;

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
	private var textScaleFactor : Int = Platform.isMacintosh ? 2 : 1;

	private var isInput : Bool = false;
	private var isFocused : Bool = false;

	private static function getBulletsString(l : Int) : String {
		var bullet = String.fromCharCode(8226);
		var i = 0; var ret = '';
		for (i in 0...l) ret += bullet;
		return ret;
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

	public override function onUpdateStyle() : Void {
		super.onUpdateStyle();

		if (isInput) {
			nativeWidget.type = type;
			nativeWidget.value = text;
			nativeWidget.style.color = style.fill;
			nativeWidget.style.letterSpacing = '${cast(style.letterSpacing, Float) / textScaleFactor}px';
			nativeWidget.style.fontFamily = style.fontFamily;
			nativeWidget.style.fontWeight = style.fontWeight;
			nativeWidget.style.fontStyle = style.fontStyle;
			nativeWidget.style.fontSize =  '${cast(style.fontSize, Float) / textScaleFactor}px';
			nativeWidget.style.lineHeight = '${cast(style.fontSize, Float) / textScaleFactor * 1.15 + interlineSpacing}px';
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

			if (accessWidget != null && accessWidget.autocomplete != null && accessWidget.autocomplete != '') {
				nativeWidget.autocomplete = accessWidget.autocomplete;
			} else if (type == 'password' && nativeWidget.autocomplete == '') {
				nativeWidget.autocomplete = 'new-password';
			}

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

			onUpdateAlpha();
		}

		if (isFocused || text == '') {
			if (textClip != null) {
				textClip.renderable = false;
			}
		} else {
			var text = isInput && type == 'password' ? TextClip.getBulletsString(text.length) : this.text;
			var texts = wordWrap || true ? [[text]] : checkTextLength(text);

			if (textClip == null) {
				textClip = createTextClip(texts[0][0], style);
				addChild(textClip);
			}

			textClip.renderable = true;

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
		}
	}

	public override function onUpdateAlpha() : Void {
		super.onUpdateAlpha();

		if (isInput) {
			if (Platform.isEdge || Platform.isIE) {
				nativeWidget.style.opacity = 1;
				var slicedColor : Array<String> = style.fill.split(",");
				var newColor = slicedColor.slice(0, 3).join(",") + "," + Std.parseFloat(slicedColor[3]) * (isFocused ? worldAlpha : 0) + ")";

				nativeWidget.style.color = newColor;
			} else {
				nativeWidget.style.opacity = isFocused ? worldAlpha : 0;
			}
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

		style.fontSize = textScaleFactor * fontSize;
		style.fill = RenderSupportJSPixi.makeCSSColor(fillColor, fillOpacity);
		style.letterSpacing = textScaleFactor * letterSpacing;
		style.fontFamily = fontStyle.family;
		style.fontWeight = fontWeight != 400 ? '${fontWeight}' : fontStyle.weight;
		style.fontStyle = fontSlope != '' ? fontSlope : fontStyle.style;
		style.lineHeight = textScaleFactor * (fontSize * 1.15 + interlineSpacing);
		style.wordWrap = wordWrap;
		style.wordWrapWidth = textScaleFactor * (widgetWidth > 0 ? widgetWidth : 2048);
		style.breakWords = cropWords;
		style.align = autoAlign == 'AutoAlignRight' ? 'right' : autoAlign == 'AutoAlignCenter' ? 'center' : 'left';

		fontMetrics = TextMetrics.measureFont(untyped style.toFontString());

		this.text = StringTools.endsWith(text, '\n') ? text.substring(0, text.length - 1) : text;
		this.backgroundColor = backgroundColor;
		this.backgroundOpacity = backgroundOpacity;

		invalidateStyle();
	}

	private function createTextClip(text : String, style : Dynamic) : Text {
		textClip = new Text(text, style);

		textClip.setClipVisible(true);
		textClip.setClipScaleX(1 / textScaleFactor);
		textClip.setClipScaleY(1 / textScaleFactor);

		return textClip;
	}

	public override function invalidateStyle() : Void {
		metrics = null;
		super.invalidateStyle();
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

			invalidateStyle();
		}
	}

	public override function setWidth(widgetWidth : Float) : Void {
		style.wordWrapWidth = textScaleFactor * (widgetWidth > 0 ? widgetWidth : 2048);
		super.setWidth(widgetWidth);
	}

	public function setCropWords(cropWords : Bool) : Void {
		if (this.cropWords != cropWords) {
			this.cropWords = cropWords;
			style.breakWords = cropWords;

			invalidateStyle();
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
			style.lineHeight = cast(style.fontSize, Float) * 1.15 + textScaleFactor * interlineSpacing;

			invalidateStyle();
		}
	}

	public function setTextDirection(textDirection : String) : Void {
		if (this.textDirection != textDirection) {
			this.textDirection = textDirection.toLowerCase();
			// if (textDirection == 'RTL' || textDirection == 'rtl')
			// 	style.textDirection = 'rtl';
			// else
			// 	style.textDirection = 'ltr';

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

			invalidateStyle();
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

		if (NativeHx.isTouchScreen()) {
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
			if (RenderSupportJSPixi.getClipAt(point) != this) {
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

		invalidateStyle();
	}

	private function onBlur(e : Event) : Void {
		isFocused = false;
		emit('blur');

		invalidateStyle();
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
		return metrics != null ? untyped metrics.width / textScaleFactor : 0;
	}

	public override function getHeight() : Float {
		return widgetHeight > 0.0 && isInput ? widgetHeight : getClipHeight();
	}

	private function getClipHeight() : Float {
		updateTextMetrics();
		return metrics != null ? untyped metrics.height / textScaleFactor : 0;
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
		if (text != "" && cast(style.fontSize, Float) > 1 && (metrics == null || untyped metrics.text != text || untyped metrics.style != style)) {
			metrics = TextMetrics.measureText(text, style);
		}
	}

	public function getTextMetrics() : Array<Float> {
		if (fontMetrics == null) {
			var ascent = 0.9 * cast(style.fontSize, Float) / textScaleFactor;
			var descent = 0.1 * cast(style.fontSize, Float) / textScaleFactor;
			var leading = 0.15 * cast(style.fontSize, Float) / textScaleFactor;

			return [ascent, descent, leading];
		} else {
			return [fontMetrics.ascent / textScaleFactor, fontMetrics.descent / textScaleFactor, fontMetrics.descent / textScaleFactor];
		}
	}
}