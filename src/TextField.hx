import js.Browser;
import pixi.core.math.shapes.Rectangle;
import pixi.core.math.Point;

import FlowFontStyle;

using DisplayObjectHelper;

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

	private var preFocus : Bool = false;

	// Signalizes where we have changed any properties
	// influencing text width or height
	private var metricsChanged : Bool = false;

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
		super.updateNativeWidget();

		if (getClipVisible() && isInput() && (!shouldPreventFromFocus || !Platform.isEdge)) {
			nativeWidget.style.opacity = Platform.isEdge && preFocus && multiline ? 1 : isNativeWidgetShown() ? fillOpacity * worldAlpha : 0;
			nativeWidget.style.display = "block";
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
		} else {
			updateNativeWidget();
		}
	}

	private function layoutText() : Void {
		removeScrollRect();
		var i = children.length;
		while (i >= 0) {
			removeChild(children[i]);
			i--;
		}

		var lines = (isInput() && type == "password" ? getBulletsString(text.length) : text).split("\n");

		clipWidth = 0.0;
		clipHeight = 0.0;

		for (line in lines) {
			var line_width = 0.0;

			if (fieldWidth > 0.0 && wordWrap) {
				var words = line.split(" ");
				var x = 0.0;

				for (wordId in 0...words.length) {
					var word = wordId == words.length - 1 ? words[wordId] : words[wordId] + " ";

					var clip : Dynamic = makeTextClip(word, style);
					var textDimensions = getTextClipMetrics(clip);

					while (word.length > 0) {
						if (cropWords) {
							var currentLength = word.length;
							clip = makeTextClip(word, style);
							textDimensions = getTextClipMetrics(clip);

							while (textDimensions.width > fieldWidth) {
								--currentLength;
								clip = makeTextClip(word.substr(0, currentLength), style);
								textDimensions = getTextClipMetrics(clip);
							}

							word = word.substr(currentLength, word.length - currentLength);
							if (word == " ") word = "";
						} else {
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
				var clip : Dynamic = makeTextClip(line, style);
				var textDimensions = getTextClipMetrics(clip);

				var PART_SIZE = 2048;

				if (textDimensions.width > PART_SIZE) {
					var partLength = Math.floor(PART_SIZE * line.length / textDimensions.width);
					var partsAmount = Math.ceil(line.length / partLength);

					clipWidth = 0;

					for (partIndex in 0...partsAmount) {
						var partClip : Dynamic = makeTextClip(line.substr(partIndex * partLength, partLength), style);
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

	private function makeTextClip(text : String, style : Dynamic) : Dynamic {
		return {};
	}

	private function getTextClipMetrics(clip : Dynamic) : Dynamic {
		return {};
	}

	private function setTextBackground(?text_bounds : Rectangle) : Void {
		if (background != null) removeChild(background);

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
		this.type = type;
		updateNativeWidgetStyle();
	}

	public function setTextInputStep(step : Float) : Void {
		this.step = step;
		updateNativeWidgetStyle();
	}

	public  function setWordWrap(wordWrap : Bool) : Void {
		this.wordWrap = wordWrap;
		updateNativeWidgetStyle();
	}

	public override function setWidth(fieldWidth : Float) : Void {
		this.fieldWidth = fieldWidth;
		updateNativeWidgetStyle();
	}

	public override function setHeight(fieldHeight : Float) : Void {
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
			accessWidget.element = nativeWidget;
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
		if (nativeWidget != null) {
			if (RenderSupportJSPixi.AccessibilityEnabled && nativeWidget.parentNode == null) {
				AccessWidget.updateAccessTree();
			}

		 	if (nativeWidget.parentNode != null) {
				shouldPreventFromFocus = false;

				// Workaround for IE not updating readonly after textfield is focused
				if (focus) {
					if (Platform.isIE || Platform.isEdge) {
						preOnFocus();
					}
					nativeWidget.focus();
				} else {
					nativeWidget.blur();
				}
			};
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

	private static function getBulletsString(l : Int) : String {
		var bullet = String.fromCharCode(8226);
		var i = 0; var ret = "";
		for (i in 0...l) ret += bullet;
		return ret;
	}

	#if (pixijs < "4.7.0")
		public override function getLocalBounds() : Rectangle {
			if (isInput() && fieldHeight > 0.0 && fieldWidth > 0.0) {
				return new Rectangle(0.0, 0.0, fieldWidth, fieldHeight);
			} else if (clipWidth > 0.0 && clipHeight > 0.0) {
				return new Rectangle(0.0, 0.0, clipWidth, clipHeight)
			} else {
				return super.getLocalBounds();
			}
		}
	#else
		public override function getLocalBounds(?rect:Rectangle) : Rectangle {
			if (isInput() && fieldHeight > 0.0 && fieldWidth > 0.0) {
				if (rect != null) {
					rect = new Rectangle(0.0, 0.0, fieldWidth, fieldHeight);
					return rect;
				} else if (clipWidth > 0.0 && clipHeight > 0.0) {
					return new Rectangle(0.0, 0.0, clipWidth, clipHeight);
				} else {
					return new Rectangle(0.0, 0.0, fieldWidth, fieldHeight);
				}
			} else {
				return super.getLocalBounds(rect);
			}
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