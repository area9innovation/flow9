import pixi.core.display.DisplayObject;
import haxe.extern.EitherType;

using DisplayObjectHelper;

class FlowCanvas extends FlowContainer {
	public var isCanvasStage = true;
	public function new(?worldVisible : Bool = false) {
		isFlowContainer = false;
		super(worldVisible);

		if (this.isHTMLRenderer()) {
			this.initNativeWidget('canvas');
		}
	}

	public function updateNativeWidget() {
		if (visible && worldAlpha > 0 && renderable) {
			var tempResolution = RenderSupport.PixiRenderer.resolution;
			RenderSupport.PixiRenderer.resolution = Math.max(worldTransform.a, worldTransform.d) >= 1.0
				? Math.ceil(Math.max(worldTransform.a, worldTransform.d) * tempResolution)
				: Math.max(worldTransform.a, worldTransform.d) * tempResolution;

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

			this.updateNativeWidgetTransformMatrix();
			this.updateNativeWidgetOpacity();
			var transform = worldTransform.clone().invert();
			transform.tx += Math.max(-localBounds.minX, 0.0);
			transform.ty += Math.max(-localBounds.minY, 0.0);

			this.renderToCanvas(nativeWidget, context, transform, worldAlpha);

			RenderSupport.PixiRenderer.resolution = tempResolution;

			if (worldTransform.tx < 0 || worldTransform.ty < 0) {
				untyped this.localTransformChanged = true;
			}
		} else {
			untyped this.localTransformChanged = true;
		}

		this.updateNativeWidgetDisplay();
	}

	public override function createNativeWidget(?tagName : String = "canvas") : Void {
		super.createNativeWidget(tagName);

		RenderSupport.RendererType = 'canvas';
		PixiWorkarounds.workaroundGetContext();

		context = nativeWidget != null ? nativeWidget.getContext('2d', { alpha : true }) : null;

		if (nativeWidget != null) {
			nativeWidget.onpointermove = function(e) {
				RenderSupport.PixiRenderer.plugins.interaction.onPointerMove(e);
				nativeWidget.style.cursor = RenderSupport.PixiView.style.cursor;
			};
			nativeWidget.onpointerover = function(e) {
				RenderSupport.PixiRenderer.plugins.interaction.onPointerOver(e);
			};
			nativeWidget.onpointerout = function(e) {
				RenderSupport.PixiRenderer.plugins.interaction.onPointerOut(e);
			};
			nativeWidget.style.pointerEvents = 'auto';
		}

		RenderSupport.RendererType = 'html';
		PixiWorkarounds.workaroundGetContext();
	}

	public override function destroy(?options : EitherType<Bool, DestroyOptions>) : Void {
		super.destroy(options);

		if (context != null) {
			untyped __js__("delete this.context");
		}
	}
}