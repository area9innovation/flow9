import js.Browser;
import pixi.core.display.Bounds;

using DisplayObjectHelper;

class NativeWidgetClip extends FlowContainer {
	private var nativeWidget : Dynamic;
	private var accessWidget : AccessWidget;
	private var parentNode : Dynamic;
	private var viewBounds : Bounds;

	private var widgetWidth : Float = 0.0;
	private var widgetHeight : Float = 0.0;

	// Returns metrics to set correct native widget size
	private function getWidth() : Float { return widgetWidth; }
	private function getHeight() : Float { return widgetHeight; }

	public function updateNativeWidget() {
		// Set actual HTML node metrics, opacity etc.
		if (getClipVisible()) {
			var transform = nativeWidget.parentNode != null && nativeWidget.parentNode.style.transform != "" && nativeWidget.parentNode.clip != null ?
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

			if (viewBounds != null) {
				if (Platform.isIE || Platform.isEdge) {
					nativeWidget.style.clip = 'rect(
						${viewBounds.minY}px,
						${viewBounds.maxX}px,
						${viewBounds.maxY}px,
						${viewBounds.minX}px
					)';
				} else {
					nativeWidget.style.clipPath = 'polygon(
						${viewBounds.minX}px ${viewBounds.minY}px,
						${viewBounds.minX}px ${viewBounds.maxY}px,
						${viewBounds.maxX}px ${viewBounds.maxY}px,
						${viewBounds.maxX}px ${viewBounds.minY}px
					)';
				}
			}

			nativeWidget.style.opacity = worldAlpha;
			nativeWidget.style.display = "block";
		} else {
			nativeWidget.style.display = "none";
		}
	}

	private function addNativeWidget() : Void {
		if (nativeWidget != null) {
			if (parentNode == null) {
				parentNode = RenderSupportJSPixi.findParentAccessibleWidget(parent);
			}

			if (parentNode != null) {
				nativeWidget.style.position = "fixed";
				nativeWidget.style.zIndex = RenderSupportJSPixi.zIndexValues.nativeWidget;

				if (accessWidget == null) {
					accessWidget = new AccessWidget(this, nativeWidget);
				}

				// RenderSupportJSPixi.PixiStage.on("stagechanged", updateNativeWidget);
				once("removed", deleteNativeWidget);
			} else {
				RenderSupportJSPixi.findTopParent(this).once("added", addNativeWidget);
			}
		}
	}

	private function createNativeWidget(node_name : String) : Void {
		deleteNativeWidget();

		nativeWidget = Browser.document.createElement(node_name);
		nativeWidget.style.transformOrigin = "top left";

		if (parent != null) {
			addNativeWidget();
		} else {
			once("added", addNativeWidget);
		}
	}

	private function deleteNativeWidget() : Void {
		// RenderSupportJSPixi.PixiStage.off("stagechanged", updateNativeWidget);

		if (accessWidget != null) {
			AccessWidget.removeAccessWidget(accessWidget);
		}

		nativeWidget = null;
	}

	static private var lastFocusedClip : Dynamic = null;
	public function setFocus(focus : Bool) if (nativeWidget != null) {
		if (focus) nativeWidget.focus() else nativeWidget.blur();
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

	public function setWidth(widgetWidth : Float) : Void {
		this.widgetWidth = widgetWidth;
		updateNativeWidget();
	}

	public function setHeight(widgetHeight : Float) : Void {
		this.widgetHeight = widgetHeight;
		updateNativeWidget();
	}
}