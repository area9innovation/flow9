import js.Browser;
import pixi.core.display.Container;
import pixi.core.display.DisplayObject;

using DisplayObjectHelper;

class FlowContainer extends Container {
	public var scrollRect : FlowGraphics;
	private var _visible : Bool = true;
	private var clipVisible : Bool = false;
	public var transformChanged : Bool = true;
	public var stageChanged : Bool = true;
	private var childrenChanged : Bool = true;

	private var stage : FlowContainer = null;
	private var pixiStage : Bool = false;

	public function new(?pixiStage : Bool = false) {
		super();

		this.pixiStage = pixiStage;
		visible = pixiStage;
		clipVisible = pixiStage;
		interactiveChildren = false;
	}

	public override function addChild<T:DisplayObject>(child : T) : T {
		var newChild = super.addChild(child);

		if (newChild != null) {
			newChild.updateStage();
			newChild.updateClipInteractive(interactiveChildren);

			if (getClipVisible()) {
				newChild.updateClipWorldVisible();
				newChild.invalidateStage();
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
				newChild.invalidateStage();
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
}