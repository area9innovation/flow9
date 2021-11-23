import js.Browser;

import pixi.core.display.Bounds;

using DisplayObjectHelper;

class NativeWidgetClip extends FlowContainer {
	private var viewBounds : Bounds;
	private var widgetBounds = new Bounds();

	private var styleChanged : Bool = true;

	public var widgetWidth : Float = -1;
	public var widgetHeight : Float = -1;

	private var focusRetries : Int = 0;

	public function new(?worldVisible : Bool = false) {
		isFlowContainer = false;
		super(worldVisible);
	}

	private override function createNativeWidget(?tagName : String = "div") : Void {
		if (!isNativeWidget) {
			return;
		}

		this.deleteNativeWidget();

		nativeWidget = Browser.document.createElement(tagName);
		this.updateClipID();
		nativeWidget.className = 'nativeWidget';

		if (!this.isHTMLRenderer()) {
			if (accessWidget == null) {
				accessWidget = new AccessWidget(this, nativeWidget);
			} else {
				accessWidget.element = nativeWidget;
			}

			if (parent != null) {
				this.addNativeWidget();
			} else {
				once('added', this.addNativeWidget);
			}

			this.invalidateStyle();

			if (!this.getClipRenderable() && parent != null) {
				this.updateNativeWidget();
			}
		}

		isNativeWidget = true;
	}

	public function updateNativeWidgetStyle() : Void {
		nativeWidget.style.width = '${this.getWidgetWidth()}px';
		nativeWidget.style.height = '${this.getWidgetHeight()}px';

		if (!this.isHTMLRenderer()) {
			var viewBounds = this.getViewBounds();

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
			if (untyped nativeWidget.parentNode == null && !this.destroyed && this.focusRetries < 3 && focus) {
				focusRetries++;
				RenderSupport.once("drawframe", function() { setFocus(focus); });

				return true;
			}

			focusRetries = 0;

			if (focus && nativeWidget.focus != null && !getFocus()) {
				nativeWidget.focus();
				if (RenderSupport.EnableFocusFrame) nativeWidget.classList.add("focused");

				return true;
			} else if (!focus && nativeWidget.blur != null && getFocus()) {
				nativeWidget.blur();
				nativeWidget.classList.remove("focused");

				return true;
			}

			return false;
		} else {
			return false;
		}
	}

	public function getFocus() : Bool {
		return nativeWidget != null && (Browser.document.activeElement == nativeWidget || (
			untyped RenderSupport.FlowInstances.some(function(instance) {
				var shadowRoot = instance.stage.nativeWidget; 
				return shadowRoot.host == Browser.document.activeElement && shadowRoot.activeElement == nativeWidget;
			})
		));
	}

	public function requestFullScreen() : Void {
		if (nativeWidget != null) {
			RenderSupport.requestFullScreen(nativeWidget);
		}
	}

	public function exitFullScreen() : Void {
		if (nativeWidget != null) {
			RenderSupport.exitFullScreen(nativeWidget);
		}
	}

	public function invalidateStyle() : Void {
		styleChanged = true;

		this.invalidateTransform('invalidateStyle');
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