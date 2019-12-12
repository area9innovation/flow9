import js.Browser;
import js.html.CanvasElement;
import js.Promise;

using DisplayObjectHelper;

class PdfClip extends FlowCanvas {
	private var page : Dynamic;
	private var pageScale : Float = 1.0;

	private var renderWidget : Dynamic;
	private var renderContext : Dynamic;
	private var renderTask : Dynamic;

	public function new() {
		super();

		renderWidget = cast(Browser.document.createElement('canvas'), CanvasElement);
		renderContext = renderWidget.getContext("2d");
	}

	public override function updateNativeWidget() {
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

			var pageChanged = untyped this.nativeWidgetBoundsChanged;

			updateNativeWidgetTransformMatrix();
			updateNativeWidgetOpacity();

			if (pageChanged) {
				renderView(nativeWidget.getContext("2d"), RenderSupportJSPixi.backingStoreRatio);
			}

			if (worldTransform.tx < 0 || worldTransform.ty < 0) {
				untyped this.localTransformChanged = true;
			}
		}

		updateNativeWidgetDisplay();
	}

	public function setRenderPage(page : Dynamic, scale : Float) {
		this.page = page;
		this.pageScale = scale * RenderSupportJSPixi.backingStoreRatio;

		var viewport = untyped page.getViewport({ scale: this.pageScale });
		localBounds.minX = 0;
		localBounds.minY = 0;
		localBounds.maxX = viewport.width;
		localBounds.maxY = viewport.height;

		renderWidget.setAttribute('width', '${localBounds.maxX}');
		renderWidget.setAttribute('height', '${localBounds.maxY}');
		renderWidget.style.width = '${localBounds.maxX}px';
		renderWidget.style.height = '${localBounds.maxY}px';

		renderPage();
	}

	private function renderPage() {
		if (page != null) {
			if (renderTask != null) {
				// if (untyped renderTask.cancelling) {
					renderTask.cancel();
				// }

				// untyped renderTask.cancelling = true;
			} else {
				renderTask = page.render({
					canvasContext: renderContext,
					viewport: page.getViewport({ scale: pageScale })
				});

				var taskPromise : Promise<Dynamic> = renderTask.promise;
				taskPromise.then(function(e : Dynamic) {
					renderTask = null;
					invalidateTransform();
					untyped this.nativeWidgetBoundsChanged = RenderSupportJSPixi.RendererType == "html";
				}).catchError(function(e : Dynamic) {
					renderTask = null;
					renderPage();
				});
			}
		}
	}

	private function renderView(ctx : Dynamic, resolution : Float) {
		if (RenderSupportJSPixi.RendererType != "html") {
			ctx.globalAlpha = this.worldAlpha;
			ctx.setTransform(worldTransform.a, worldTransform.b, worldTransform.c, worldTransform.d, worldTransform.tx * resolution, worldTransform.ty * resolution);
		}

		ctx.drawImage(this.renderWidget, 0, 0, getWidth() * RenderSupportJSPixi.backingStoreRatio, getHeight() * RenderSupportJSPixi.backingStoreRatio, 0, 0, getWidth() * resolution, getHeight() * resolution);
	}

	public function renderCanvas(renderer : pixi.core.renderers.canvas.CanvasRenderer) {
		if (!this.visible || this.worldAlpha <= 0 || !this.renderable || getWidth() <= 0 || getHeight() <= 0) {
			return;
		}

		var ctx : Dynamic = untyped renderer.context;
		var resolution = renderer.resolution;

		renderView(ctx, resolution);
	}
}