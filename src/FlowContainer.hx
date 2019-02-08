import pixi.core.display.Container;
import pixi.core.display.DisplayObject;

using DisplayObjectHelper;

class FlowContainer extends Container {
	private var scrollRect : FlowGraphics;
	private var _visible : Bool = true;
	private var clipVisible : Bool = false;

	public function new(?worldVisible : Bool = false) {
		super();

		visible = worldVisible;
		clipVisible = worldVisible;
		interactiveChildren = false;
	}

	public override function addChild<T:DisplayObject>(child : T) : T {
		var newChild = super.addChild(child);

		if (newChild != null) {
			newChild.updateClipInteractive(interactiveChildren);

			if (getClipVisible()) {
				newChild.updateClipWorldVisible();
				RenderSupportJSPixi.InvalidateStage();
			}

			emitEvent("childrenchanged");
		}

		return newChild;
	}

	public override function addChildAt<T:DisplayObject>(child : T, index : Int) : T {
		var newChild = super.addChildAt(child, index > children.length ? children.length : index);

		if (newChild != null) {
			newChild.updateClipInteractive(interactiveChildren);

			if (getClipVisible()) {
				newChild.updateClipWorldVisible();
				RenderSupportJSPixi.InvalidateStage();
			}

			emitEvent("childrenchanged");
		}

		return newChild;
	}

	public override function removeChild(child : DisplayObject) : DisplayObject {
		var oldChild = super.removeChild(child);

		if (oldChild != null) {
			updateClipInteractive();
			oldChild.updateClipWorldVisible();

			InvalidateStage();

			emitEvent("childrenchanged");
		}

		return oldChild;
	}
}