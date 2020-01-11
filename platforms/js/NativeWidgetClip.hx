import js.Browser;

import pixi.core.math.Matrix;
import pixi.core.display.Bounds;
import pixi.core.display.DisplayObject;
import pixi.core.math.shapes.Rectangle;
import pixi.core.math.Point;

using DisplayObjectHelper;

class NativeWidgetClip extends FlowContainer {
	private var viewBounds : Bounds;
	private var widgetBounds = new Bounds();

	private var styleChanged : Bool = true;

	public var widgetWidth : Float = -1;
	public var widgetHeight : Float = -1;

	private var focusRetries : Int = 0;

	public function new(?worldVisible : Bool = false) {
		super(worldVisible);
	}

	private override function createNativeWidget(?tagName : String = "div") : Void {
		if (!isNativeWidget) {
			return;
		}

		deleteNativeWidget();

		nativeWidget = Browser.document.createElement(tagName);
		updateClipID();
		nativeWidget.className = 'nativeWidget';

		if (RenderSupportJSPixi.RendererType != "html") {
			if (accessWidget == null) {
				accessWidget = new AccessWidget(this, nativeWidget);
			} else {
				accessWidget.element = nativeWidget;
			}

			if (parent != null) {
				addNativeWidget();
			} else {
				once('added', addNativeWidget);
			}

			invalidateStyle();

			if (!getClipRenderable() && parent != null) {
				updateNativeWidget();
			}
		}

		isNativeWidget = true;
	}

	public function updateNativeWidgetStyle() : Void {
		nativeWidget.style.width = '${untyped getWidgetWidth()}px';
		nativeWidget.style.height = '${untyped getWidgetHeight()}px';

		if (RenderSupportJSPixi.RendererType != "html") {
			var viewBounds = getViewBounds();

			if (viewBounds != null) {
				nativeWidget.style.clip = 'rect(
					${viewBounds.minY}px,
					${viewBounds.maxX}px,
					${viewBounds.maxY}px,
					${viewBounds.minX}px
				)';
			}
		}

		styleChanged = false;
	}

	public function setFocus(focus : Bool) : Bool {
		if (nativeWidget != null) {
			if (untyped nativeWidget.parentNode == null && !this.destroyed && this.focusRetries < 3) {
				focusRetries++;
				RenderSupportJSPixi.once("drawframe", function() { setFocus(focus); });

				return true;
			}

			focusRetries = 0;

			if (focus && nativeWidget.focus != null && !getFocus()) {
				nativeWidget.focus();

				return true;
			} else if (!focus && nativeWidget.blur != null && getFocus()) {
				nativeWidget.blur();

				return true;
			}

			return false;
		} else {
			return false;
		}
	}

	public function getFocus() : Bool {
		return nativeWidget != null && Browser.document.activeElement == nativeWidget;
	}

	public function requestFullScreen() : Void {
		if (nativeWidget != null) {
			RenderSupportJSPixi.requestFullScreen(nativeWidget);
		}
	}

	public function exitFullScreen() : Void {
		if (nativeWidget != null) {
			RenderSupportJSPixi.exitFullScreen(nativeWidget);
		}
	}

	public function invalidateStyle() : Void {
		styleChanged = true;

		invalidateTransform('invalidateStyle');
	}

	public function setWidth(widgetWidth : Float) : Void {
		if (this.widgetWidth != widgetWidth) {
			this.widgetWidth = widgetWidth;

			invalidateStyle();
		}
	}

	public function setHeight(widgetHeight : Float) : Void {
		if (this.widgetHeight != widgetHeight) {
			this.widgetHeight = widgetHeight;

			invalidateStyle();
		}
	}

	public function setViewBounds(viewBounds : Bounds) : Void {
		if (this.viewBounds != viewBounds) {
			this.viewBounds = viewBounds;

			invalidateStyle();
		}
	}

	public function calculateWidgetBounds() : Void {
		widgetBounds.minX = 0.0;
		widgetBounds.minY = 0.0;
		widgetBounds.maxX = DisplayObjectHelper.ceil(getWidth());
		widgetBounds.maxY = DisplayObjectHelper.ceil(getHeight());
	}

	public function getWidth() : Float {
		return widgetWidth;
	}

	public function getHeight() : Float {
		return widgetHeight;
	}
}