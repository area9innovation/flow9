import js.Browser;
import js.html.CanvasElement;

import pixi.core.display.Bounds;
import pixi.core.math.shapes.Rectangle;
import pixi.core.display.Container;
import pixi.core.display.DisplayObject;
import pixi.core.renderers.canvas.CanvasRenderer;

using DisplayObjectHelper;

class FlowContainer extends Container {
	public var scrollRect : FlowGraphics;
	private var _visible : Bool = true;
	private var clipVisible : Bool = false;

	private var stage : FlowContainer;
	private var view : CanvasElement;
	private var context : Dynamic;

	public var transformChanged : Bool = false;
	public var stageChanged : Bool = false;
	private var worldTransformChanged : Bool = false;
	private var localTransformChanged : Bool = true;

	private var localBounds = new Bounds();
	private var _bounds = new Bounds();

	public var nativeWidget : Dynamic;
	public var accessWidget : AccessWidget;

	public var isNativeWidget : Bool = false;

	public function new(?worldVisible : Bool = false) {
		super();

		visible = worldVisible;
		clipVisible = worldVisible;
		interactiveChildren = false;
		isNativeWidget = (RenderSupportJSPixi.RendererType == "html" && RenderSupportJSPixi.RenderContainers) || worldVisible;

		if (worldVisible) {
			nativeWidget = Browser.document.body;
		} else if (RenderSupportJSPixi.RendererType == "html") {
			createNativeWidget();
		}
	}

	public function createView(?zorder : Int) : Void {
		if (zorder == null) {
			zorder = parent.children.indexOf(this) + 1;
		}

		if (zorder == 1) {
			view = RenderSupportJSPixi.PixiView;
			context = view.getContext("2d", { alpha: false });
			return;
		}

		view = cast(Browser.document.createElement('canvas'), CanvasElement);

		view.style.zIndex = 1000 * (zorder - 1) + AccessWidget.zIndexValues.canvas + "";
		untyped view.style.pointerEvents = "none";

		context = view.getContext("2d", { alpha : true });

		updateView(zorder);
		onResize();

		RenderSupportJSPixi.on("resize", onResize);
		on("removed", destroyView);
	}

	private function updateView(?zorder : Int) : Void {
		if (zorder == null) {
			zorder = parent.children.indexOf(this) + 1;
		}

		if (zorder > 0) {
			if (Browser.document.body.children.length > zorder) {
				if (Browser.document.body.children[zorder - 1] != view) { // - 1 because first layer renders to PixiView
					if (Browser.document.body.children.length > zorder) {
						Browser.document.body.insertBefore(view, Browser.document.body.children[zorder]);
					} else {
						Browser.document.body.appendChild(view);
					}
				}
			} else {
				Browser.document.body.appendChild(view);
			}
		}
	}

	private function destroyView() : Void {
		RenderSupportJSPixi.off("resize", onResize);

		if (view.parentNode == Browser.document.body) {
			Browser.document.body.removeChild(view);
		}

		view = null;
		context = null;
	}

	private function onResize() : Void {
		if (view == RenderSupportJSPixi.PixiRenderer.view) {
			return;
		}

		view.width = RenderSupportJSPixi.PixiView.width;
		view.height = RenderSupportJSPixi.PixiView.height;

		view.style.width = view.width / RenderSupportJSPixi.backingStoreRatio + "px";
		view.style.height = view.height / RenderSupportJSPixi.backingStoreRatio + "px";
	}

	public override function addChild<T:DisplayObject>(child : T) : T {
		if (child.parent != null) {
			untyped child.parent.removeChild(child);
		}

		var newChild = super.addChild(child);

		if (newChild != null) {
			newChild.invalidate();
			emitEvent("childrenchanged");
		}

		return newChild;
	}

	public override function addChildAt<T:DisplayObject>(child : T, index : Int) : T {
		if (child.parent != null) {
			untyped child.parent.removeChild(child);
		}

		var newChild = super.addChildAt(child, index > children.length ? children.length : index);

		if (newChild != null) {
			newChild.invalidate();
			emitEvent("childrenchanged");
		}

		return newChild;
	}

	public override function removeChild(child : DisplayObject) : DisplayObject {
		var oldChild = super.removeChild(child);

		if (oldChild != null) {
			invalidateInteractive();
			invalidateTransform('removeChild');
			if (untyped this.keepNativeWidgetChildren) {
				updateKeepNativeWidgetChildren();
			}

			emitEvent("childrenchanged");
		}

		return oldChild;
	}

	public function invalidateStage() : Void {
		if (stage != null) {
			if (stage != this) {
				stage.invalidateStage();
			} else {
				stageChanged = true;
				RenderSupportJSPixi.PixiStageChanged = true;
			}
		}
	}

	public function render(renderer : CanvasRenderer) {
		if (RenderSupportJSPixi.RendererType == "html") {
			if (stageChanged) {
				stageChanged = false;

				setClipScaleX(RenderSupportJSPixi.getAccessibilityZoom());
				setClipScaleY(RenderSupportJSPixi.getAccessibilityZoom());

				if (transformChanged) {
					var bounds = new Bounds();
					untyped RenderSupportJSPixi.PixiStage.localBounds = bounds;
					bounds.minX = 0;
					bounds.minY = 0;
					bounds.maxX = renderer.width;
					bounds.maxY = renderer.height;
					invalidateLocalBounds();
					invalidateRenderable(bounds);

					DisplayObjectHelper.lockStage();
					updateTransform();
					DisplayObjectHelper.unlockStage();
				}
			}
		} else if (stageChanged) {
			stageChanged = false;

			if (view != null) {
				renderer.view = view;
				renderer.context = context;
				untyped renderer.rootContext = context;
				renderer.transparent = parent.children.indexOf(this) != 0;
			}

			if (transformChanged) {
				var bounds = new Bounds();
				untyped RenderSupportJSPixi.PixiStage.localBounds = bounds;
				bounds.minX = 0;
				bounds.minY = 0;
				bounds.maxX = renderer.width;
				bounds.maxY = renderer.height;
				invalidateLocalBounds();
				invalidateRenderable(bounds);
			}

			DisplayObjectHelper.lockStage();
			renderer.render(this, null, true, null, false);
			DisplayObjectHelper.unlockStage();
		}
	}

	public override function getLocalBounds(?rect : Rectangle) : Rectangle {
		rect = localBounds.getRectangle(rect);

		var filterPadding = untyped this.filterPadding;

		if (filterPadding != null) {
			rect.x -= filterPadding;
			rect.y -= filterPadding;
			rect.width += filterPadding * 2.0;
			rect.height += filterPadding * 2.0;
		}

		return rect;
	}

	public override function getBounds(?skipUpdate : Bool, ?rect : Rectangle) : Rectangle {
		if (!skipUpdate) {
			updateTransform();
		}

		getLocalBounds();
		calculateBounds();

		return _bounds.getRectangle(rect);
	}

	public function calculateBounds() : Void {
		_bounds.minX = localBounds.minX * worldTransform.a + localBounds.minY * worldTransform.c + worldTransform.tx;
		_bounds.minY = localBounds.minX * worldTransform.b + localBounds.minY * worldTransform.d + worldTransform.ty;
		_bounds.maxX = localBounds.maxX * worldTransform.a + localBounds.maxY * worldTransform.c + worldTransform.tx;
		_bounds.maxY = localBounds.maxX * worldTransform.b + localBounds.maxY * worldTransform.d + worldTransform.ty;
	}

	private function createNativeWidget(?tagName : String = "div") : Void {
		if (!isNativeWidget) {
			return;
		}

		deleteNativeWidget();

		nativeWidget = Browser.document.createElement(tagName);
		updateClipID();
		nativeWidget.className = 'nativeWidget';

		isNativeWidget = true;

		invalidateParentClip();
	}
}