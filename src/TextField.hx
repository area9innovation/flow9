import js.Browser;
import pixi.core.math.shapes.Rectangle;
import pixi.core.math.Point;

import FlowFontStyle;

using DisplayObjectHelper;

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

class TextField extends NativeWidgetClip {
	public static var cacheTextsAsBitmap : Bool = false; // Use cacheAsBitmap for all text clips

	private var text : String = "";
	private var fontFamily : String = "";
	private var fontSize : Float = 0.0;
	private var fontWeight : Int = 0;
	private var fontSlope : String = "";
	private var fillColor : Int = 0;
	private var fillOpacity : Float = 0.0;
	private var letterSpacing : Float = 0.0;
	private var backgroundColor : Int = 0;
	private var backgroundOpacity : Float = 0.0;
	private var cursorColor : Int = -1;
	private var cursorOpacity : Float = -1.0;
	private var cursorWidth : Float = 2;
	private var fontStyle : FontStyle = {weight : "", style : "", size : 0.0, family : ""};
	private var textDirection : String = "ltr";
	private var style : Dynamic = {};

	private var type : String = "text";
	private var step : Float = 1.0;
	private var wordWrap : Bool = false;
	private var fieldWidth : Float = -1.0;
	private var fieldHeight : Float = -1.0;
	private var cropWords : Bool = false;
	private var interlineSpacing : Float = 0.0;
	private var autoAlign : String = "AutoAlignNone";
	private var readOnly : Bool = false;
	private var maxChars : Int = -1;

	private var cursorPosition : Int = -1;
	private var selectionStart : Int = -1;
	private var selectionEnd : Int = -1;

	private var background : FlowGraphics = null;

	private var shouldPreventFromFocus : Bool = false;
	public var shouldPreventFromBlur : Bool = false;
	private var metrics : Dynamic;
	private var multiline : Bool = false;

	private var clipWidth : Float = 0.0;
	private var clipHeight : Float = 0.0;

	private var TextInputFilters : Array<String -> String> = new Array();
	private var TextInputKeyDownFilters : Array<String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool> = new Array();
	private var TextInputKeyUpFilters : Array<String -> Bool -> Bool -> Bool -> Bool -> Int -> Bool> = new Array();

	public var accessWidget : Dynamic = null;
	private var preFocus : Bool = false;

	private function preOnFocus() { // Workaround for IE inputs readonly attribute
		if (isInput()) {
			this.preFocus = true;
			updateNativeWidgetStyle();
			haxe.Timer.delay(function() {
				this.preFocus = false;
				updateNativeWidgetStyle();
			}, 10);
		}
	}

	private override function createNativeWidget(nodeName : String) : Void {
		super.createNativeWidget(nodeName);
		if (Platform.isIE || Platform.isEdge)
			RenderSupportJSPixi.PixiStage.on("preonfocus", preOnFocus);
	}

	private override function deleteNativeWidget() : Void {
		if (Platform.isIE || Platform.isEdge)
			RenderSupportJSPixi.PixiStage.off("preonfocus", preOnFocus);
		if (!shouldPreventFromBlur && Browser.document.activeElement == nativeWidget)
			nativeWidget.blur();
		super.deleteNativeWidget();
	}

	public override function updateNativeWidget() {
		if (getClipVisible()) {
			var transform = !Platform.isIE && nativeWidget.parentNode.style.transform != "" && nativeWidget.parentNode.clip != null ?
				worldTransform.clone().append(nativeWidget.parentNode.clip.worldTransform.clone().invert()) : worldTransform;

			var tx = getClipWorldVisible() ? transform.tx : RenderSupportJSPixi.PixiRenderer.width;
			var ty = getClipWorldVisible() ? transform.ty : RenderSupportJSPixi.PixiRenderer.height;

			if (Platform.isIE) {
				nativeWidget.style.transform = "matrix(" + transform.a + "," + transform.b + "," + transform.c + "," + transform.d + ","
					+ 0 + "," + 0 + ")";

				nativeWidget.style.left = untyped "" + tx + "px";
				nativeWidget.style.top = untyped "" + ty + "px";
			} else {
				nativeWidget.style.transform = "matrix(" + transform.a + "," + transform.b + "," + transform.c + "," + transform.d + ","
					+ tx + "," + ty + ")";
			}

			nativeWidget.style.width = untyped "" + getWidth() + "px";
			nativeWidget.style.height = untyped "" + getHeight() + "px";

			if (isInput() && (!shouldPreventFromFocus || !Platform.isEdge)) {
				nativeWidget.style.opacity = preFocus && multiline && Platform.isEdge ? 1 : isNativeWidgetShown() ? fillOpacity * worldAlpha : 0;
				nativeWidget.style.display = "block";
			} else {
				nativeWidget.style.display = "none";
			}
		} else {
			nativeWidget.style.display = "none";
		}
	}

	public function setTextAndStyle(
		text : String, fontFamily : String, fontSize : Float, fontWeight: Int, fontSlope: String, fillColor : Int, fillOpacity : Float, letterSpacing : Float,
		backgroundColor : Int, backgroundOpacity : Float
	) : Void {
		this.text = StringTools.endsWith(text, "\n") ? text.substring(0, text.length - 1) : text;
		this.fontFamily = fontFamily;
		this.fontSize = fontSize;
		this.fontWeight = fontWeight;
		this.fontSlope = fontSlope;
		this.fillColor = fillColor;
		this.fillOpacity = fillOpacity;
		this.letterSpacing = letterSpacing;
		this.backgroundColor = backgroundColor;
		this.backgroundOpacity = backgroundOpacity;
		this.fontStyle = FlowFontStyle.fromFlowFont(fontFamily);

		updateNativeWidgetStyle();
	}

	private function updateNativeWidgetStyle() {
		if (isInput()) {
			setScrollRect(0, 0, 0, 0);
			nativeWidget.type = type;
			if (type == "number") nativeWidget.step = step;
			if (accessWidget != null && accessWidget.autocomplete != null && accessWidget.autocomplete != "")
				nativeWidget.autocomplete = accessWidget.autocomplete
			else if (type == "password" && nativeWidget.autocomplete == "")
				nativeWidget.autocomplete = "new-password";
			nativeWidget.value = text;
			nativeWidget.style.color = RenderSupportJSPixi.makeCSSColor(fillColor, fillOpacity);
			nativeWidget.style.letterSpacing = (RenderSupportJSPixi.UseDFont ? letterSpacing + 0.022 : letterSpacing) + "px";
			nativeWidget.style.fontFamily = fontStyle.family;
			nativeWidget.style.fontWeight = fontWeight != 400 ? fontWeight : fontStyle.weight;
			nativeWidget.style.fontStyle = fontSlope != "" ? fontSlope : fontStyle.style;
			nativeWidget.style.fontSize = fontSize + "px";
			nativeWidget.style.lineHeight = (fontSize * 1.2 + interlineSpacing) + "px";
			nativeWidget.style.backgroundColor = RenderSupportJSPixi.makeCSSColor(backgroundColor, backgroundOpacity);
			nativeWidget.style.cursor = "text";
			nativeWidget.style.opacity = preFocus && multiline && Platform.isEdge ? 1 : fillOpacity * worldAlpha;
			if (cursorColor >= 0) {
				nativeWidget.style.caretColor = RenderSupportJSPixi.makeCSSColor(cursorColor, cursorOpacity);
			}
			nativeWidget.readOnly = readOnly;
			if (maxChars >= 0) nativeWidget.maxLength = maxChars;
			if (tabIndex >= 0) nativeWidget.tabIndex = tabIndex;
			nativeWidget.style.pointerEvents = readOnly ? "none" : "auto";
			if (multiline) {
				nativeWidget.style.resize = "none";
				nativeWidget.wrap = wordWrap ? "soft" : "off";
			}
			nativeWidget.style.direction = switch (textDirection) {
				case "RTL" : "rtl";
				case "rtl" : "rtl";
				default : "ltr";
			}
			nativeWidget.style.textAlign = switch (autoAlign) {
				case "AutoAlignLeft" : "left";
				case "AutoAlignRight" : "right";
				case "AutoAlignCenter" : "center";
				case "AutoAlignNone" : "none";
				default : "left";
			}
		}
		if (!isNativeWidgetShown()) {
			if (isInput()) {
				nativeWidget.style.cursor = "inherit";
				nativeWidget.style.opacity = preFocus && multiline && Platform.isEdge ? 1 : 0;
				nativeWidget.readOnly = readOnly || !preFocus;
			}

			layoutText();
		}
	}

	private function layoutText() : Void {
		removeScrollRect();
		var i = children.length;
		while (i >= 0) {
			removeChild(children[i]);
			i--;
		}

		var modification : TextMappedModification = (isInput() && type == "password" ? getBulletsString(text) : getActualGlyphsString(text));
		var lines = modification.modified.split("\n");

		clipWidth = 0.0;
		clipHeight = 0.0;
		var chrIdx : Int = 0;

		for (line in lines) {
			var line_width = 0.0;

			if (fieldWidth > 0.0 && wordWrap) {
				var words = line.split(" ");
				var x = 0.0;

				for (wordId in 0...words.length) {
					var word = wordId == words.length - 1 ? words[wordId] : words[wordId] + " ";

					var clip : Dynamic = makeTextClip(word, chrIdx, style);
					var textDimensions = getTextClipMetrics(clip);

					while (word.length > 0) {
						if (cropWords) {
							var currentLength = word.length;
							clip = makeTextClip(word, chrIdx, style);
							textDimensions = getTextClipMetrics(clip);

							while (textDimensions.width > fieldWidth) {
								--currentLength;
								clip = makeTextClip(word.substr(0, currentLength), chrIdx, style);
								textDimensions = getTextClipMetrics(clip);
							}

							word = word.substr(currentLength, word.length - currentLength);
							chrIdx += currentLength;
							if (word == " ") word = "";
						} else {
							chrIdx += word.length;
							word = "";
						}

						if (x > 0.0 && (x + textDimensions.width > fieldWidth)) {
							x = 0.0;
							clipHeight += textDimensions.line_height * textDimensions.line_count + interlineSpacing;
						}

						clip.x += x;
						clip.y += clipHeight;
						addChild(clip);

						x += textDimensions.width;
						line_width = Math.max(line_width, x);
					}

					if (wordId == words.length - 1) {
						clipHeight += textDimensions.line_height * textDimensions.line_count + interlineSpacing;
					}
				}

				clipWidth = Math.max(clipWidth, line_width);
			} else {
				var clip : Dynamic = makeTextClip(line, chrIdx, style);
				var textDimensions = getTextClipMetrics(clip);

				var PART_SIZE = 2048;

				if (textDimensions.width > PART_SIZE) {
					var partLength = Math.floor(PART_SIZE * line.length / textDimensions.width);
					var partsAmount = Math.ceil(line.length / partLength);

					clipWidth = 0;

					for (partIndex in 0...partsAmount) {
						var partClip : Dynamic = makeTextClip(
							line.substr(partIndex * partLength, partLength),
							chrIdx + partIndex * partLength,
							style
						);
						var partTextDimensions = getTextClipMetrics(partClip);

						partClip.x += clipWidth;
						partClip.y += clipHeight;
						addChild(partClip);

						clipWidth += partTextDimensions.width;

					}
				} else {
					clip.y += clipHeight;
					addChild(clip);
				}
				chrIdx += line.length;
				clipHeight += textDimensions.line_height * textDimensions.line_count + interlineSpacing;
				clipWidth = Math.max(clipWidth, textDimensions.width);
			}
		}

		if ((autoAlign == "AutoAlignRight" || autoAlign == "AutoAlignCenter") && fieldWidth > 0) {
			var textDimensions = 0;
			var newChildren = [];

			for (child in children) {
				if (child.x > 0) {
					textDimensions += getTextClipMetrics(child).width;
					newChildren.push(child);
				} else {
					if (newChildren.length > 0 && textDimensions < fieldWidth) {
						var widthDelta = fieldWidth - textDimensions;

						if (autoAlign == "AutoAlignCenter") {
							widthDelta = widthDelta / 2;
						}

						for (newChild in newChildren) {
							newChild.x = newChild.x + widthDelta;
						}
					}

					textDimensions = getTextClipMetrics(child).width;
					newChildren = [child];
				}
			}

			if (newChildren.length > 0 && textDimensions < fieldWidth) {
				var widthDelta = fieldWidth - textDimensions;

				if (autoAlign == "AutoAlignCenter") {
					widthDelta = widthDelta / 2;
				}

				for (newChild in newChildren) {
					newChild.x = newChild.x + widthDelta;
				}
			}

			clipWidth = Math.max(clipWidth, fieldWidth);
		}

		setTextBackground();
		setScrollRect(0, 0, getWidth(), getHeight());
	}

	public function getCharXPosition(charIdx: Int) : Float {
		return -1.0;
	}

	private function makeTextClip(text : String, charIdx : Int, style : Dynamic) : Dynamic {
		return {};
	}

	private function getTextClipMetrics(clip : Dynamic) : Dynamic {
		return {};
	}

	private function setTextBackground() : Void {
		if (background != null) removeChild(background);

		if (backgroundOpacity > 0.0) {
			var text_bounds = getLocalBounds();
			background = new FlowGraphics();
			background.beginFill(backgroundColor, backgroundOpacity);
			background.drawRect(0.0, 0.0, text_bounds.width, text_bounds.height);

			addChildAt(background, 0);
		} else {
			background = null;
		}
	}

	public function setTextInputType(type : String) : Void {
		this.type = type;
		updateNativeWidgetStyle();
	}

	public function setTextInputStep(step : Float) : Void {
		this.step = step;
		updateNativeWidgetStyle();
	}

	public function setWordWrap(wordWrap : Bool) : Void {
		this.wordWrap = wordWrap;
		updateNativeWidgetStyle();
	}

	public function setWidth(fieldWidth : Float) : Void {
		this.fieldWidth = fieldWidth;
		updateNativeWidgetStyle();
	}

	public function setHeight(fieldHeight : Float) : Void {
		this.fieldHeight = fieldHeight;
		updateNativeWidgetStyle();
	}

	public function setCropWords(cropWords : Bool) : Void {
		this.cropWords = cropWords;
		updateNativeWidgetStyle();
	}

	public function setCursorColor(color : Int, opacity : Float) : Void {
		this.cursorColor = color;
		this.cursorOpacity = opacity;
		updateNativeWidgetStyle();
	}

	public function setCursorWidth(width : Float) : Void {
		this.cursorWidth = width;
		updateNativeWidgetStyle();
	}

	public function setInterlineSpacing(interlineSpacing : Float) : Void {
		this.interlineSpacing = interlineSpacing;
		updateNativeWidgetStyle();
	}

	public function setTextDirection(direction : String) : Void {
		this.textDirection = direction;
		updateNativeWidgetStyle();
	}

	public function setAutoAlign(autoAlign : String) : Void {
		this.autoAlign = autoAlign;
		updateNativeWidgetStyle();
	}

	public function setTabIndex(tabIndex : Int) : Void {
		this.tabIndex = tabIndex;
		updateNativeWidgetStyle();
	}

	public function setReadOnly(readOnly : Bool) {
		this.readOnly = readOnly;
		updateNativeWidgetStyle();
	}

	public function setMaxChars(maxChars : Int) {
		this.maxChars = maxChars;
		updateNativeWidgetStyle();
	}

	public function setTextInput() {
		if (multiline) setWordWrap(true);
		createNativeWidget(multiline ? "textarea" : "input");
		shouldPreventFromFocus = false;

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

		if (accessWidget != null) {
			accessWidget = nativeWidget;
		}

		nativeWidget.addEventListener("input", onInput);
		nativeWidget.addEventListener("scroll", onScroll);
		nativeWidget.addEventListener("keydown", onKeyDown);
		nativeWidget.addEventListener("keyup", onKeyUp);
		updateNativeWidgetStyle();
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
			emit("input");
		}
	}

	private function onMouseMove(e : js.html.MouseEvent) {
		// if (isNativeWidgetShown()) {
		// 	checkPositionSelection();
		// }

		nativeWidget.style.cursor = RenderSupportJSPixi.PixiRenderer.view.style.cursor;

		RenderSupportJSPixi.provideEvent(e);
	}

	private function onMouseDown(e : Dynamic) {
		if (isNativeWidgetShown()) {
			checkPositionSelection();
			RenderSupportJSPixi.provideEvent(e);
		} else {
			var point = e.touches != null && e.touches.length > 0 ? new Point(e.touches[0].pageX, e.touches[0].pageY) : new Point(e.pageX, e.pageY);
			nativeWidget.readOnly = shouldPreventFromFocus = RenderSupportJSPixi.getClipAt(point) != this;

			if (shouldPreventFromFocus) {
				e.preventDefault();
				RenderSupportJSPixi.provideEvent(e);
			}
		}

		if ((Platform.isIE || Platform.isEdge) && !shouldPreventFromFocus) {
			// IE & Edge cannot handle onfocus completely
			// when we focus from another input
			preOnFocus();
			nativeWidget.focus();
		}
	}

	private function onMouseUp(e : js.html.MouseEvent) {
		if (isNativeWidgetShown()) {
			checkPositionSelection();
		}

		nativeWidget.readOnly = nativeWidget.readOnly && nativeWidget.autocomplete == "";

		RenderSupportJSPixi.provideEvent(e);
		shouldPreventFromFocus = false;
	}

	// focused - bring the widget to front
	private function onFocus(e : js.html.Event) : Void {
		if (isInput()) {
			if (shouldPreventFromFocus) {
				e.preventDefault();
				nativeWidget.blur();
				return;
			}

			emit("focus");
			if (parent != null) {
				parent.emitEvent("childfocused", this);
			}
			updateNativeWidgetStyle();
		}
	}

	// blured - hide the HTML widget
	private function onBlur(e : js.html.Event) : Void {
		if (isInput()) {
			if (shouldPreventFromBlur) {
				shouldPreventFromBlur = false;
				e.preventDefault();
				nativeWidget.focus();
				return;
			}

			if (Platform.isIE || Platform.isEdge || Browser.document.activeElement == nativeWidget) {
				nativeWidget.blur();

				if (Platform.isEdge) { // Workaround for blinking caret on inactive inputs
					shouldPreventFromFocus = true;
					updateNativeWidget();

					haxe.Timer.delay(function() {
						shouldPreventFromFocus = false;
						updateNativeWidget();
					}, 100);
				}
			}

			emit("blur");
			updateNativeWidgetStyle();
		}
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
		emit("input", newValue);
	}

	private function onScroll(e : Dynamic) {
		emit("scroll", e);
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
					RenderSupportJSPixi.PixiStage.emit("keydown", ke);
					break;
				}
			}
		}

		if (isNativeWidgetShown()) {
			checkPositionSelection();
		}
	}

	private function onKeyUp(e : Dynamic) {
		var ke : Dynamic = RenderSupportJSPixi.parseKeyEvent(e);
		if (TextInputKeyUpFilters.length > 0) {

			for (f in TextInputKeyUpFilters) {
				if (!f(ke.key, ke.ctrl, ke.shift, ke.alt, ke.meta, ke.keyCode)) {
					ke.preventDefault();
					RenderSupportJSPixi.PixiStage.emit("keyup", ke);
					break;
				}
			}
		}

		if (ke.keyCode == 13 && Platform.isMobile && !this.multiline) // Hide mobile keyboard on enter key press
			nativeWidget.blur();

		if (isNativeWidgetShown()) {
			checkPositionSelection();
		}
	}

	public function getDescription() : String {
		if (isInput()) {
			return 'TextField (text = "${nativeWidget.value}")';
		} else {
			return 'TextField (text = "${text}")';
		}
	}

	public function isInput() : Bool {
		return nativeWidget != null;
	}

	public override function setFocus(focus : Bool) : Void {
		shouldPreventFromFocus = false;

		if (nativeWidget != null && nativeWidget.parentNode != null) {
			// Workaround for IE not updating readonly after textfield is focused
			if (focus) {
				if (Platform.isIE || Platform.isEdge) {
					preOnFocus();
				}
				nativeWidget.focus();
			} else {
				nativeWidget.blur();
			}
		}
	}

	private function isNativeWidgetShown() {
		return isInput() && (Browser.document.activeElement == nativeWidget || (!readOnly && nativeWidget.autocomplete != ""));
	}

	public override function getWidth() : Float {
		return getBounds(true).width;
	}

	public override function getHeight() : Float {
		return getBounds(true).height;
	}

	public function getContent() : String {
		return text;
	}

	public function getCursorPosition() : Int {
		try {
			// Chrome doesn't support this method for "number" inputs
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
		try {
			// Chrome doesn't support this method for "number" inputs
			if (nativeWidget.selectionStart == null) {
				return nativeWidget.value.length;
			} else {
				return nativeWidget.selectionStart;
			}
		} catch(e : Dynamic) {
			return 0;
		}
	}

	public function getSelectionEnd() : Int {
		try {
			// Chrome doesn't support this method for "number" inputs
			if (nativeWidget.selectionEnd == null) {
				return nativeWidget.value.length;
			} else {
				return nativeWidget.selectionEnd;
			}
		} catch(e : Dynamic) {
			return 0;
		}
	}

	public function setSelection(start : Int, end : Int) : Void {
		// Chrome doesn't support this method for "number" inputs
		try {
			nativeWidget.setSelectionRange(start, end);
		} catch(e : Dynamic) {}
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

	public function getTextMetrics() : Array<Float> {
		var ascent = 0.9 * fontSize;
		var descent = 0.1 * fontSize;
		var leading = 0.15 * fontSize;
		return [ascent, descent, leading];
	}

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
		var bullet = String.fromCharCode(8226);
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

	#if (pixijs < "4.7.0")cd
		public override function getLocalBounds() : Rectangle {
			if (isInput() && fieldHeight > 0.0 && fieldWidth > 0.0)
				return new Rectangle(0.0, 0.0, fieldWidth, fieldHeight);
			else
				return super.getLocalBounds();
		}
	#else
		public override function getLocalBounds(?rect:Rectangle) : Rectangle {
			if (isInput() && fieldHeight > 0.0 && fieldWidth > 0.0) {
				if (rect != null) {
					rect = new Rectangle(0.0, 0.0, fieldWidth, fieldHeight);
					return rect;
				} else {
					return new Rectangle(0.0, 0.0, fieldWidth, fieldHeight);
				}
			}
			else
				return super.getLocalBounds(rect);
		}
	#end

	public override function getBounds(?skipUpdate: Bool, ?rect: Rectangle) : Rectangle {
		if (rect == null && isInput() && fieldHeight > 0.0 && fieldWidth > 0.0) {
			var lt = toGlobal(new Point(0.0, 0.0));
			var rb = toGlobal(new Point(fieldWidth, fieldHeight));
			return new Rectangle(lt.x, lt.y, rb.x - lt.x, rb.y - lt.y);
		} else {
			return super.getBounds(skipUpdate, rect);
		}
	}

	public function calculateBounds() : Void {
		untyped super.calculateBounds();
		if (isInput() && fieldHeight > 0.0 && fieldWidth > 0.0) {
			untyped this._bounds.addFrame(this.transform, 0.0, 0.0, fieldWidth, fieldHeight);
		}
	}
}