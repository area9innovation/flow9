import js.Browser;
import pixi.core.text.Text;
import pixi.core.math.shapes.Rectangle;

import FlowFontStyle;

using DisplayObjectHelper;

class PixiText extends TextField {
	private var textClip : Text = null;

	// Signalizes where we have changed any properties
	// influencing text width or height
	private var metricsChanged : Bool = false;

	// Use the property to set up custom antialias factor
	// Implemented by enlarging font size and decreasing scale of text clip
	private var textScaleFactor : Int = Platform.isMacintosh ? 2 : 1;

	public function new() {
		super();

		on("removed", function () {
			if (textClip != null) {
				destroyTextClipChildren();

				if (textClip.canvas != null && Browser.document.body.contains(textClip.canvas)) {
					Browser.document.body.removeChild(textClip.canvas);
				}

				removeChild(textClip);
				textClip.destroy({ children: true, texture: true, baseTexture: true });
				textClip = null;
			}
		});
	}

	private inline function destroyTextClipChildren() {
		var clip = textClip.children.length > 0 ? textClip.children[0] : null;

		while (clip != null) {
			if (untyped clip.canvas != null && Browser.document.body.contains(untyped clip.canvas)) {
				Browser.document.body.removeChild(untyped clip.canvas);
			}

			textClip.removeChild(clip);
			clip.destroy({ children: true, texture: true, baseTexture: true });

			clip = textClip.children.length > 0 ? textClip.children[0] : null;
		}
	}

	private inline function invalidateMetrics() {
		this.metricsChanged = true;
	}

	private function bidiDecorate(text : String) : String {
		var mark : String = "";
		if (textDirection == "ltr") mark = String.fromCharCode(0x202A) else if (textDirection == "rtl") mark = String.fromCharCode(0x202B);
		if (mark != "") return mark + text + String.fromCharCode(0x202C);
		return text;
	}

	public override function setTextAndStyle(
		text : String, fontfamily : String,
		fontsize : Float, fontweight : Int, fontslope : String,
		fillcolor : Int, fillopacity : Float, letterspacing : Float,
		backgroundcolour : Int, backgroundopacity : Float
	) : Void {

		if (this.text != text || this.fontFamily != fontfamily ||
			this.fontSize != fontsize || this.fontWeight != fontweight ||
			this.fontSlope != fontslope || this.letterSpacing != letterspacing) {

			this.invalidateMetrics();
		}

		var from_flow_style : FontStyle = FlowFontStyle.fromFlowFont(fontfamily);
		var fontStyle = fontslope != "" ? fontslope : from_flow_style.style;

		style =
			{
				fontSize : textScaleFactor * (fontsize < 0.6 ? 0.6 : fontsize), // pixi crashes when size < 0.6
				fill : "#" + StringTools.hex(RenderSupportJSPixi.removeAlphaChannel(fillcolor), 6),
				letterSpacing : letterspacing,
				fontFamily : from_flow_style.family,
				fontWeight : fontweight != 400 ? "" + fontweight : from_flow_style.weight,
				fontStyle : fontStyle
			};

		metrics = untyped pixi.core.text.TextMetrics.measureFont(new pixi.core.text.TextStyle(style).toFontString());

		if (interlineSpacing != 0) {
			style.lineHeight = style.fontSize * 1.1 + interlineSpacing;
		}

		super.setTextAndStyle(text, fontfamily, fontsize, fontweight, fontslope, fillcolor, fillopacity, letterspacing, backgroundcolour, backgroundopacity);
	}

	private override function layoutText() : Void {
		if (isInput())
			removeScrollRect();
		var widthDelta = 0.0;

		makeTextClip(text, style);

		textClip.x = -letterSpacing;

		if ((style.align == "center" || style.align == "right") && fieldWidth > 0) {
			if (clipWidth < fieldWidth) {
				widthDelta = fieldWidth - clipWidth;

				if (style.align == "center") {
					widthDelta = widthDelta / 2;
				}

				textClip.x += widthDelta;
			}

			clipWidth = Math.max(clipWidth, fieldWidth);
		}

		setTextBackground();
		if (isInput())
			setScrollRect(0, 0, getWidth() + widthDelta, getHeight());
	}

	private override function onInput(e : Dynamic) {
		super.onInput(e);
		invalidateMetrics();
	}

	public override function getWidth() : Float {
		return fieldWidth > 0.0 && isInput() ? fieldWidth : clipWidth;
	}

	public override function getHeight() : Float {
		return fieldHeight > 0.0 && isInput() ? fieldHeight : clipHeight;
	}

	public override function setCropWords(cropWords : Bool) : Void {
		if (this.cropWords != cropWords)
			this.invalidateMetrics();

		this.cropWords = cropWords;
		style.breakWords = cropWords;
		updateNativeWidgetStyle();
	}

	public override function setWordWrap(wordWrap : Bool) : Void {
		if (this.wordWrap != wordWrap)
			this.invalidateMetrics();

		this.wordWrap = wordWrap;
		style.wordWrap = wordWrap;
		updateNativeWidgetStyle();
	}

	public override function setTextInputType(type : String) : Void {
		super.setTextInputType(type);
		invalidateMetrics();
	}

	public override function setWidth(fieldWidth : Float) : Void {
		if (this.fieldWidth != fieldWidth)
			this.invalidateMetrics();

		this.fieldWidth = fieldWidth;
		style.wordWrapWidth = textScaleFactor * (fieldWidth > 0 ? fieldWidth : 2048);
		updateNativeWidgetStyle();
	}

	public override function setInterlineSpacing(interlineSpacing : Float) : Void {
		if (this.interlineSpacing != interlineSpacing)
			this.invalidateMetrics();

		this.interlineSpacing = interlineSpacing;
		style.lineHeight = style.fontSize * 1.15 + interlineSpacing;
		updateNativeWidgetStyle();
	}

	public override function setTextDirection(direction : String) : Void {
		this.textDirection = direction;
		if (direction == "RTL" || direction == "rtl")
			style.direction = "rtl";
		else
			style.direction = "ltr";
		updateNativeWidgetStyle();
	}

	public override function setAutoAlign(autoAlign : String) : Void {
		this.autoAlign = autoAlign;
		if (autoAlign == "AutoAlignRight")
			style.align = "right";
		else if (autoAlign == "AutoAlignCenter")
			style.align = "center";
		else
			style.align = "left";
		updateNativeWidgetStyle();
	}

	private function updateClipMetrics() {
		var metrics = textClip.children.length > 0 ? textClip.getLocalBounds() : getTextClipMetrics(textClip);

		clipWidth = Math.max(metrics.width - letterSpacing * 2, 0) / textScaleFactor;
		clipHeight = metrics.height / textScaleFactor;

		hitArea = new Rectangle(letterSpacing, 0, clipWidth + letterSpacing, clipHeight);
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

	private override function makeTextClip(text : String, style : Dynamic) : Dynamic {
		if (isInput() && type == "password")
			text = TextField.getBulletsString(text.length);
		var texts = wordWrap ? [[text]] : checkTextLength(text);

		if (textClip == null) {
			textClip = createTextClip(texts[0][0], style);
		}

		if (metricsChanged) {
			textClip.text = bidiDecorate(texts[0][0]);
			textClip.style = style;

			if (text == "") {
				removeChild(textClip);
			} else {
				addChild(textClip);
			}

			destroyTextClipChildren();

			if (texts.length > 1 || texts[0].length > 1) {
				var currentHeight = 0.0;

				for (line in texts) {
					var currentWidth = 0.0;
					var lineHeight = 0.0;

					for (txt in line) {
						if (txt == texts[0][0]) {
							currentWidth = textClip.getLocalBounds().width;
							lineHeight = textClip.getLocalBounds().height;
						} else {
							var newTextClip = createTextClip(txt, style);

							newTextClip.x = currentWidth;
							newTextClip.y = currentHeight;

							textClip.addChild(newTextClip);

							currentWidth += newTextClip.getLocalBounds().width;
							lineHeight = Math.max(lineHeight, newTextClip.getLocalBounds().height);
						}
					}

					currentHeight += lineHeight;
				}
			}

			updateClipMetrics();
		}

		var anchorX = switch (autoAlign) {
			case "AutoAlignLeft" : 0;
			case "AutoAlignRight" : 1;
			case "AutoAlignCenter" : 0.5;
			default : textDirection == "rtl"? 1 : 0;
		};
		textClip.x = anchorX * (getWidth() - this.clipWidth);

		textClip.alpha = fillOpacity;

		metricsChanged = false;

		if (TextField.cacheTextsAsBitmap) {
			textClip.cacheAsBitmap = true;
		}

		return textClip;
	}

	private function createTextClip(text : String, style : Dynamic) : Text {
		var textClip = new Text(text, style);
		untyped textClip._visible = true;

		textClip.scale.x = 1 / textScaleFactor;
		textClip.scale.y = 1 / textScaleFactor;

		// The default font smoothing on webkit (-webkit-font-smoothing = subpixel-antialiased),
		// makes the text bolder when light text is placed on a dark background.
		// "antialised" produces a lighter text, which is what we want.
		// Moreover, the css style only has any effect when the canvas element
		// is part of the DOM, so we attach the underlying PIXI canvas backend
		// and make it invisible.
		// On Firefox, the equivalent css property (-moz-osx-font-smoothing = grayscale) seems to
		// have no effect on the canvas element.
		if (RenderSupportJSPixi.AntialiasFont && (Platform.isChrome || Platform.isSafari)) {
			untyped textClip.canvas.style.webkitFontSmoothing = "antialiased";
			textClip.canvas.style.display = "none";
			Browser.document.body.appendChild(textClip.canvas);
		}

		return textClip;
	}

	private override function getTextClipMetrics(clip : Dynamic) : Dynamic {
		return pixi.core.text.TextMetrics.measureText(clip.text, clip.style);
	}

	public override function getTextMetrics() : Array<Float> {
		if (metrics == null) {
			return super.getTextMetrics();
		} else {
			return [metrics.ascent / textScaleFactor, metrics.descent / textScaleFactor, metrics.descent / textScaleFactor];
		}
	}
}