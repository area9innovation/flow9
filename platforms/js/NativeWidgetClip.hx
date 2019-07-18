import js.Browser;

import pixi.core.math.Matrix;
import pixi.core.display.Bounds;
import pixi.core.math.shapes.Rectangle;
import pixi.core.math.Point;

using DisplayObjectHelper;

class NativeWidgetClip extends FlowContainer {
	private var nativeWidget : Dynamic;
	private var accessWidget : AccessWidget;
	private var viewBounds : Bounds;

	private var styleChanged : Bool = true;

	private var widgetWidth : Float = 0.0;
	private var widgetHeight : Float = 0.0;

	// Returns metrics to set correct native widget size
	private function getWidth() : Float { return widgetWidth; }
	private function getHeight() : Float { return widgetHeight; }
	private function getTransform() : Matrix {
		if (accessWidget != null) {
			return accessWidget.getTransform();
		} else {
			return worldTransform;
		}
	}

	public function updateNativeWidget() : Void {
		var transform = getTransform();

		var tx = getClipWorldVisible() ? transform.tx : -widgetWidth;
		var ty = getClipWorldVisible() ? transform.ty : -widgetHeight;

		if (Platform.isIE) {
			nativeWidget.style.transform = 'matrix(${transform.a}, ${transform.b}, ${transform.c}, ${transform.d}, 0, 0)';

			nativeWidget.style.left = '${tx}px';
			nativeWidget.style.top = '${ty}px';
		} else {
			nativeWidget.style.transform = 'matrix(${transform.a}, ${transform.b}, ${transform.c}, ${transform.d}, ${tx}, ${ty})';
		}
	}

	public function updateNativeWidgetStyle() : Void {
		nativeWidget.style.width = '${untyped getWidth()}px';
		nativeWidget.style.height = '${untyped getHeight()}px';

		var maskedBounds = getMaskedLocalBounds();

		if (Platform.isIE || Platform.isEdge) {
			nativeWidget.style.clip = 'rect(
				${maskedBounds.minY}px,
				${maskedBounds.maxX}px,
				${maskedBounds.maxY}px,
				${maskedBounds.minX}px
			)';
		} else {
			nativeWidget.style.clipPath = 'polygon(
				${maskedBounds.minX}px ${maskedBounds.minY}px,
				${maskedBounds.minX}px ${maskedBounds.maxY}px,
				${maskedBounds.maxX}px ${maskedBounds.maxY}px,
				${maskedBounds.maxX}px ${maskedBounds.minY}px
			)';
		}

		styleChanged = false;
	}

	private function addNativeWidget() : Void {
		once('removed', deleteNativeWidget);
	}

	private function createNativeWidget(node_name : String) : Void {
		deleteNativeWidget();

		nativeWidget = Browser.document.createElement(node_name);
		nativeWidget.style.transformOrigin = 'top left';
		nativeWidget.style.position = 'fixed';

		RenderSupportJSPixi.PixiStage.on("childrenchanged", function() {
			nativeWidget.style.zIndex = Std.parseInt(this.stage.view.style.zIndex) + AccessWidget.zIndexValues.nativeWidget + "";
		});

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

		if (!getClipWorldVisible() && parent != null) {
			updateNativeWidget();
		}
	}

	private function deleteNativeWidget() : Void {
		if (accessWidget != null) {
			AccessWidget.removeAccessWidget(accessWidget);
		}

		nativeWidget = null;
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
		invalidateTransform();
	}

	public function setWidth(widgetWidth : Float) : Void {
		if (this.widgetWidth != widgetWidth) {
			this.widgetWidth = widgetWidth;

			invalidateStyle();

			if (nativeWidget != null && !getClipWorldVisible() && parent != null) {
				updateNativeWidget();
			}
		}
	}

	public function setHeight(widgetHeight : Float) : Void {
		if (this.widgetHeight != widgetHeight) {
			this.widgetHeight = widgetHeight;

			invalidateStyle();

			if (nativeWidget != null && !getClipWorldVisible() && parent != null) {
				updateNativeWidget();
			}
		}
	}

	public function setViewBounds(viewBounds : Bounds) : Void {
		if (this.viewBounds != viewBounds) {
			this.viewBounds = viewBounds;

			invalidateStyle();
		}
	}

	#if (pixijs < "4.7.0")
		public override function getLocalBounds() : Rectangle {
			var rect = new Rectangle();

			rect.x = 0;
			rect.y = 0;
			rect.width = getWidth();
			rect.height = getHeight();

			return rect;
		}
	#else
		public override function getLocalBounds(?rect:Rectangle) : Rectangle {
			if (rect == null) {
				rect = new Rectangle();
			}

			rect.x = 0;
			rect.y = 0;
			rect.width = getWidth();
			rect.height = getHeight();

			return rect;
		}
	#end

	public override function getBounds(?skipUpdate: Bool, ?rect: Rectangle) : Rectangle {
		if (rect == null) {
			rect = new Rectangle();
		}

		var lt = toGlobal(new Point(0.0, 0.0));
		var rb = toGlobal(new Point(getWidth(), getHeight()));

		rect.x = lt.x;
		rect.y = lt.y;
		rect.width = rb.x - lt.x;
		rect.height = rb.y - lt.y;

		return rect;
	}
}