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
	private var offscreenCanvas : Dynamic = untyped __js__("typeof OffscreenCanvas !== 'undefined' ? new OffscreenCanvas(RenderSupportJSPixi.PixiView.width, RenderSupportJSPixi.PixiView.height) : document.createElement('canvas')");
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

			var minX = Math.max(Math.ceil(-localBounds.minX * worldTransform.a), 0.0) * RenderSupportJSPixi.PixiRenderer.resolution;
			var minY =  Math.max(Math.ceil(-localBounds.minY * worldTransform.d), 0.0) * RenderSupportJSPixi.PixiRenderer.resolution;

			var width = Math.ceil(localBounds.maxX * worldTransform.a) * RenderSupportJSPixi.PixiRenderer.resolution + minX;
			var height = Math.ceil(localBounds.maxY * worldTransform.d) * RenderSupportJSPixi.PixiRenderer.resolution + minY;

			var transform = getNativeWidgetTransform();

			var canvasWidth = Math.ceil(localBounds.maxX * transform.a) + Math.max(Math.ceil(-localBounds.minX * transform.a), 0.0);
			var canvasHeight = Math.ceil(localBounds.maxY * transform.d) + Math.max(Math.ceil(-localBounds.minY * transform.d), 0.0);

			offscreenCanvas.width = width + Math.round(worldTransform.tx) * RenderSupportJSPixi.PixiRenderer.resolution;
			offscreenCanvas.height = height + Math.round(worldTransform.ty) * RenderSupportJSPixi.PixiRenderer.resolution;

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
				canvasWidth,
				canvasHeight
			);

			context.drawImage(
				offscreenCanvas,
				Math.ceil(worldTransform.tx) * RenderSupportJSPixi.PixiRenderer.resolution - minX,
				Math.ceil(worldTransform.ty) * RenderSupportJSPixi.PixiRenderer.resolution - minY,
				width,
				height,
				0.0,
				0.0,
				canvasWidth,
				canvasHeight
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