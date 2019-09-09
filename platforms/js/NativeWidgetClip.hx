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

	public function new(?worldVisible : Bool = false) {
		super(worldVisible);
	}

	private function getTransform(?worldTransform : Bool) : Matrix {
		if (RenderSupportJSPixi.DomRenderer) {
			if (worldTransform == null) {
				worldTransform = !RenderSupportJSPixi.RenderContainers;
			}

			if (!worldTransform) {
				untyped this.transform.updateLocalTransform();
			}

			return worldTransform ? untyped this.worldTransform : untyped this.localTransform;
		} else if (accessWidget != null) {
			return accessWidget.getTransform();
		} else {
			return this.worldTransform;
		}
	}

	private override function createNativeWidget(?tagName : String = "div") : Void {
		if (!isNativeWidget) {
			return;
		}

		deleteNativeWidget();

		nativeWidget = Browser.document.createElement(tagName);
		nativeWidget.setAttribute('id', getClipUUID());
		nativeWidget.className = 'nativeWidget';

		if (!RenderSupportJSPixi.DomRenderer) {
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

		if (!RenderSupportJSPixi.DomRenderer) {
			var maskedBounds = getMaskedLocalBounds();

			nativeWidget.style.clip = 'rect(
				${maskedBounds.minY}px,
				${maskedBounds.maxX}px,
				${maskedBounds.maxY}px,
				${maskedBounds.minX}px
			)';
		}

		styleChanged = false;
	}

	public function setFocus(focus : Bool) : Bool {
		if (nativeWidget != null) {
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

		calculateWidgetBounds();
		calculateLocalBounds();

		invalidateTransform();
	}

	public function setWidth(widgetWidth : Float) : Void {
		if (widgetBounds.getBoundsWidth() != widgetWidth) {
			widgetBounds.minX = 0;
			widgetBounds.maxX = widgetWidth;

			invalidateStyle();
		}
	}

	public function setHeight(widgetHeight : Float) : Void {
		if (widgetBounds.getBoundsHeight() != widgetHeight) {
			widgetBounds.minY = 0;
			widgetBounds.maxY = widgetHeight;

			invalidateStyle();
		}
	}

	public function setViewBounds(viewBounds : Bounds) : Void {
		if (this.viewBounds != viewBounds) {
			this.viewBounds = viewBounds;

			invalidateStyle();
		}
	}

	public override function getLocalBounds(?rect : Rectangle) : Rectangle {
		return localBounds.getRectangle(rect);
	}

	public override function getBounds(?skipUpdate : Bool, ?rect : Rectangle) : Rectangle {
		if (!skipUpdate) {
			updateTransform();
			getLocalBounds();
		}

		if (untyped this._boundsID != untyped this._lastBoundsID)
		{
			calculateBounds();
		}

		return _bounds.getRectangle(rect);
	}

	public override function calculateBounds() : Void {
		_bounds.minX = localBounds.minX * worldTransform.a + localBounds.minY * worldTransform.c + worldTransform.tx;
		_bounds.minY = localBounds.minX * worldTransform.b + localBounds.minY * worldTransform.d + worldTransform.ty;
		_bounds.maxX = localBounds.maxX * worldTransform.a + localBounds.maxY * worldTransform.c + worldTransform.tx;
		_bounds.maxY = localBounds.maxX * worldTransform.b + localBounds.maxY * worldTransform.d + worldTransform.ty;
	}

	public function calculateWidgetBounds() : Void {
		widgetBounds.minX = 0;
		widgetBounds.minY = 0;
		widgetBounds.maxX = getWidth();
		widgetBounds.maxY = getHeight();
	}
}