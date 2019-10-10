import js.Browser;
import js.html.CanvasElement;

import pixi.core.display.Bounds;
import pixi.core.math.shapes.Rectangle;
import pixi.core.display.Container;
import pixi.core.display.DisplayObject;
import pixi.core.math.Matrix;
import pixi.core.renderers.canvas.CanvasRenderer;
import haxe.extern.EitherType;

using DisplayObjectHelper;

class FlowCanvas extends FlowContainer {
	private var offscreenCanvas : Dynamic = untyped __js__("new OffscreenCanvas(RenderSupportJSPixi.PixiView.width, RenderSupportJSPixi.PixiView.height)");
	private var offscreenContext : Dynamic = null;

	public function new(?worldVisible : Bool = false) {
		super(worldVisible);

		if (RenderSupportJSPixi.RendererType == "html") {
			initNativeWidget('canvas');
			untyped this.isCanvas = true;
		}
	}

	public function updateNativeWidget() {
		if (visible) {
			if (DisplayObjectHelper.DebugUpdate) {
				nativeWidget.setAttribute("update", Std.int(nativeWidget.getAttribute("update")) + 1);
				if (untyped this.from) {
					nativeWidget.setAttribute("from", untyped this.from);
					untyped this.from = null;
				}

				if (untyped this.info) {
					nativeWidget.setAttribute("info", untyped this.info);
				}
			}

			updateNativeWidgetTransformMatrix();
			updateNativeWidgetOpacity();

			offscreenCanvas.width = Math.ceil(localBounds.maxX) + Math.max(Math.ceil(-localBounds.minX), 0.0) + Math.ceil(worldTransform.tx);
			offscreenCanvas.height = Math.ceil(localBounds.maxY) + Math.max(Math.ceil(-localBounds.minY), 0.0) + Math.ceil(worldTransform.ty);

			RenderSupportJSPixi.PixiRenderer.context = offscreenContext;
			RenderSupportJSPixi.PixiRenderer.rootContext = offscreenContext;

			RenderSupportJSPixi.PixiRenderer.view = offscreenCanvas;
			RenderSupportJSPixi.PixiRenderer.transparent = true;
			RenderSupportJSPixi.PixiRenderer.roundPixels = true;

			RenderSupportJSPixi.RendererType = 'canvas';
			RenderSupportJSPixi.PixiRenderer.render(this, null, true, null, false);
			RenderSupportJSPixi.RendererType = 'html';

			context.clearRect(
				0,
				0,
				Math.ceil(localBounds.maxX) + Math.max(Math.ceil(-localBounds.minX), 0.0),
				Math.ceil(localBounds.maxY) + Math.max(Math.ceil(-localBounds.minY), 0.0)
			);

			context.drawImage(
				offscreenCanvas,
				Math.max(Math.ceil(-localBounds.minX), 0.0) - Math.ceil(worldTransform.tx),
				Math.max(Math.ceil(-localBounds.minY), 0.0) - Math.ceil(worldTransform.ty)
			);

			RenderSupportJSPixi.PixiRenderer.view = RenderSupportJSPixi.PixiView;
		}

		updateNativeWidgetDisplay();
	}

	public override function createNativeWidget(?tagName : String = "canvas") : Void {
		super.createNativeWidget(tagName);

		RenderSupportJSPixi.RendererType = 'canvas';
		PixiWorkarounds.workaroundGetContext();

		context = nativeWidget != null ? nativeWidget.getContext('2d', { alpha : true }) : null;
		offscreenContext = offscreenCanvas != null ? offscreenCanvas.getContext('2d', { alpha : true }) : null;

		RenderSupportJSPixi.RendererType = 'html';
		PixiWorkarounds.workaroundGetContext();
	}

	public override function destroy(?options : EitherType<Bool, DestroyOptions>) : Void {
		super.destroy(options);

		if (offscreenCanvas != null) {
			untyped __js__("delete this.offscreenCanvas");
		}

		if (offscreenContext != null) {
			untyped __js__("delete this.offscreenContext");
		}

		if (context != null) {
			untyped __js__("delete this.context");
		}
	}
}