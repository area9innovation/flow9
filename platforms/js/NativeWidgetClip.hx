import js.Browser;

import pixi.core.math.Matrix;
import pixi.core.display.Bounds;
import pixi.core.display.DisplayObject;
import pixi.core.math.shapes.Rectangle;
import pixi.core.math.Point;

using DisplayObjectHelper;

class NativeWidgetClip extends FlowContainer {
	private var viewBounds : Bounds;

	private var styleChanged : Bool = true;

	private var widgetWidth : Float = 0.0;
	private var widgetHeight : Float = 0.0;

	// Returns metrics to set correct native widget size
	private function getWidth() : Float { return widgetWidth; }
	private function getHeight() : Float { return widgetHeight; }
	private function getTransform() : Matrix {
		if (RenderSupportJSPixi.DomRenderer) {
			return untyped this.transform.localTransform;
		} else if (accessWidget != null) {
			return accessWidget.getTransform();
		} else {
			return worldTransform;
		}
	}

	private override function createNativeWidget(?node_name : String = "div") : Void {
		deleteNativeWidget();

		nativeWidget = Browser.document.createElement(node_name);
		nativeWidget.setAttribute('id', getClipUUID());
		nativeWidget.style.transformOrigin = 'top left';
		nativeWidget.style.position = 'fixed';

		if (RenderSupportJSPixi.DomRenderer) {
			// nativeWidget.style.willChange = 'transform, display, opacity';
			nativeWidget.style.pointerEvents = 'none';

			updateNativeWidgetDisplay();

			onAdded(function() { addNativeWidget(); return removeNativeWidget; });
		} else {
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
	}

	private override function deleteNativeWidget() : Void {
		removeNativeWidget();

		if (accessWidget != null) {
			AccessWidget.removeAccessWidget(accessWidget);
		}

		nativeWidget = null;
	}

	public override function updateNativeWidget() : Void {
		var transform = getTransform();

		var tx = Math.floor(getClipWorldVisible() ? transform.tx : -widgetWidth);
		var ty = Math.floor(getClipWorldVisible() ? transform.ty : -widgetHeight);

		if (Platform.isIE) {
			nativeWidget.style.transform = 'matrix(${transform.a}, ${transform.b}, ${transform.c}, ${transform.d}, 0, 0)';

			nativeWidget.style.left = '${tx}px';
			nativeWidget.style.top = '${ty}px';
		} else {
			nativeWidget.style.transform = 'matrix(${transform.a}, ${transform.b}, ${transform.c}, ${transform.d}, ${tx}, ${ty})';
		}

		if (RenderSupportJSPixi.DomRenderer) {
			if (alpha != 1) {
				nativeWidget.style.opacity = alpha;
			} else {
				nativeWidget.style.opacity = null;
			}
		} else {
			if (worldAlpha != 1) {
				nativeWidget.style.opacity = worldAlpha;
			} else {
				nativeWidget.style.opacity = null;
			}
		}

		if (RenderSupportJSPixi.DomRenderer) {
			if (scrollRect != null) {
				if (Platform.isIE || Platform.isEdge) {
					nativeWidget.style.clip = 'rect(
						${scrollRect.y}px,
						${scrollRect.x + scrollRect.width}px,
						${scrollRect.y + scrollRect.height}px,
						${scrollRect.x}px
					)';
				} else {
					nativeWidget.style.clipPath = 'polygon(
						${scrollRect.x}px ${scrollRect.y}px,
						${scrollRect.x}px ${scrollRect.y + scrollRect.height}px,
						${scrollRect.x + scrollRect.width}px ${scrollRect.y + scrollRect.height}px,
						${scrollRect.x + scrollRect.width}px ${scrollRect.y}px
					)';
				}
			} else if (mask != null) {
				if (Platform.isIE || Platform.isEdge) {
					nativeWidget.style.clip = 'rect(
						${mask.y}px,
						${mask.x + mask.getWidth()}px,
						${mask.y + mask.getHeight()}px,
						${mask.x}px
					)';
				} else {
					nativeWidget.style.clipPath = cast(mask, DisplayObject).getClipPath();
				}
			} else {
				nativeWidget.style.clipPath = null;
			}
		}

		if (styleChanged || (!RenderSupportJSPixi.DomRenderer && viewBounds == null)) {
			updateNativeWidgetStyle();
		}
	}

	public function updateNativeWidgetStyle() : Void {
		nativeWidget.style.width = '${untyped getWidth()}px';
		nativeWidget.style.height = '${untyped getHeight()}px';

		if (!RenderSupportJSPixi.DomRenderer) {
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
		}

		styleChanged = false;
	}

	private override function addNativeWidget() : Void {
		if (RenderSupportJSPixi.DomRenderer) {
			if (nativeWidget != null && parent != null && untyped parent.nativeWidget != null) {
				untyped parent.nativeWidget.appendChild(nativeWidget);
			}
		} else {
			once('removed', deleteNativeWidget);
		}
	}

	private override function removeNativeWidget() : Void {
		if (nativeWidget != null && nativeWidget.parentNode != null) {
			nativeWidget.parentNode.removeChild(nativeWidget);
		}
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

	public override function getLocalBounds(?rect : Rectangle) : Rectangle {
		localBounds.minX = 0;
		localBounds.minY = 0;
		localBounds.maxX = getWidth();
		localBounds.maxY = getHeight();

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
}