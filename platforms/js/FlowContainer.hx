import js.Browser;
import js.html.CanvasElement;

import pixi.core.display.Container;
import pixi.core.display.DisplayObject;
import pixi.core.renderers.canvas.CanvasRenderer;

using DisplayObjectHelper;

class FlowContainer extends Container {
	public var scrollRect : FlowGraphics;
	private var _visible : Bool = true;
	private var clipVisible : Bool = false;
	public var transformChanged : Bool = true;
	public var stageChanged : Bool = true;
	private var childrenChanged : Bool = true;

	private var stage : FlowContainer;
	private var view : CanvasElement;
	private var context : Dynamic;

	public function new(?worldVisible : Bool = false) {
		super();

		visible = worldVisible;
		clipVisible = worldVisible;
		interactiveChildren = false;
	}

	public function createView(?zorder : Int) : Void {
		if (zorder == null) {
			zorder = parent.children.indexOf(this) + 1;
		}

		view = cast(Browser.document.createElement('canvas'), CanvasElement);

		view.style.zIndex = 100 * zorder + AccessWidget.zIndexValues.canvas;
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
				if (Browser.document.body.children[zorder] != view) {
					if (Browser.document.body.children.length > zorder + 1) {
						Browser.document.body.insertBefore(view, Browser.document.body.children[zorder + 1]);
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
		view.width = RenderSupportJSPixi.PixiView.width;
		view.height = RenderSupportJSPixi.PixiView.height;

		view.style.width = view.width / RenderSupportJSPixi.backingStoreRatio + "px";
		view.style.height = view.height / RenderSupportJSPixi.backingStoreRatio + "px";
	}

	public override function addChild<T:DisplayObject>(child : T) : T {
		var newChild = super.addChild(child);

		if (newChild != null) {
			newChild.updateStage();
			newChild.updateClipInteractive(interactiveChildren);

			if (getClipVisible()) {
				newChild.updateClipWorldVisible();
				newChild.invalidateStage(true);
			}

			childrenChanged = true;
			emitEvent("childrenchanged");
		}

		return newChild;
	}

	public override function addChildAt<T:DisplayObject>(child : T, index : Int) : T {
		var newChild = super.addChildAt(child, index > children.length ? children.length : index);

		if (newChild != null) {
			newChild.updateStage();
			newChild.updateClipInteractive(interactiveChildren);

			if (getClipVisible()) {
				newChild.updateClipWorldVisible();
				newChild.invalidateStage(true);
			}

			childrenChanged = true;
			emitEvent("childrenchanged");
		}

		return newChild;
	}

	public override function removeChild(child : DisplayObject) : DisplayObject {
		var oldChild = super.removeChild(child);

		if (oldChild != null) {
			if (untyped oldChild.stage == oldChild) {
				for (c in children) {
					c.invalidateStage(false);
				}
			}

			oldChild.updateStage();
			updateClipInteractive();

			invalidateStage(false);

			childrenChanged = true;
			emitEvent("childrenchanged");
		}

		return oldChild;
	}

	public function invalidateStage(?updateTransform : Bool = true) : Void {
		if (stage != null) {
			if (stage != this) {
				stage.invalidateStage(updateTransform);
			} else {
				stageChanged = true;
				RenderSupportJSPixi.InvalidateStage();

				if (updateTransform) {
					transformChanged = true;
					RenderSupportJSPixi.InvalidateTransform();
				}
			}
		}
	}

	public function render(renderer : CanvasRenderer) {
		if (stageChanged && view != null) {
			stageChanged = false;

			renderer.view = view;
			renderer.context = context;
			untyped renderer.rootContext = context;
			renderer.transparent = true;

			renderer.render(this, null, true, null, false);
		}
	}
}