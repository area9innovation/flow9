import pixi.core.display.DisplayObject;
import pixi.core.display.Container;

class DisplayObjectHelper {
	public static inline function InvalidateStage(clip : DisplayObject) : Void {
		if (getClipWorldVisible(clip)) {
			RenderSupportJSPixi.InvalidateStage();
		}
	}

	public static inline function setClipX(clip : DisplayObject, x : Float) : Void {
		if (untyped clip.scrollRect != null) {
			x = x - untyped clip.scrollRect.x;
		}

		if (clip.x != x) {
			clip.x = x;

			InvalidateStage(clip);
		}
	}

	public static inline function setClipY(clip : DisplayObject, y : Float) : Void {
		if (untyped clip.scrollRect != null) {
			y = y - untyped clip.scrollRect.y;
		}

		if (clip.y != y) {
			clip.y = y;

			InvalidateStage(clip);
		}
	}

	public static inline function setClipScaleX(clip : DisplayObject, scale : Float) : Void {
		if (clip.scale.x != scale) {
			clip.scale.x = scale;

			InvalidateStage(clip);
		}
	}

	public static inline function setClipScaleY(clip : DisplayObject, scale : Float) : Void {
		if (clip.scale.y != scale) {
			clip.scale.y = scale;

			InvalidateStage(clip);
		}
	}

	public static inline function setClipRotation(clip : DisplayObject, rotation : Float) : Void {
		if (clip.rotation != rotation) {
			clip.rotation = rotation;

			InvalidateStage(clip);
		}
	}

	public static inline function setClipAlpha(clip : DisplayObject, alpha : Float) : Void {
		if (clip.alpha != alpha) {
			clip.alpha = alpha;

			InvalidateStage(clip);
		}
	}

	public static inline function setClipVisible(clip : DisplayObject, visible : Bool) : Void {
		if (untyped clip._visible != visible) {
			untyped clip._visible = visible;

			if (RenderSupportJSPixi.AccessibilityEnabled) {
				RenderSupportJSPixi.updateAccessDisplay(clip);
			}

			if (clip.parent != null && getClipVisible(clip.parent)) {
				updateClipWorldVisible(clip);
				RenderSupportJSPixi.InvalidateStage();
			}
		}
	}

	public static inline function updateClipWorldVisible(clip : DisplayObject) : Void {
		clip.visible = clip.parent != null && getClipWorldVisible(clip.parent) && (untyped clip.isMask || (untyped clip._visible && clip.renderable));

		if (clip.interactive && !getClipWorldVisible(clip)) {
			clip.emit("pointerout");
		}

		var children : Array<Dynamic> = untyped clip.children;
		if (children != null) {
			for (c in children) {
				if (getClipWorldVisible(c) != getClipWorldVisible(clip)) {
					updateClipWorldVisible(c);
				}
			}
		}
	}

	public static inline function getClipVisible(clip : DisplayObject) : Bool {
		return untyped clip._visible && (getClipWorldVisible(clip) || (clip.parent != null && getClipVisible(clip.parent)));
	}

	public static inline function setClipRenderable(clip : DisplayObject, renderable : Bool) : Void {
		if (clip.renderable != renderable) {
			clip.renderable = renderable;

			if (clip.parent != null && getClipWorldVisible(clip.parent)) {
				updateClipWorldVisible(clip);
				RenderSupportJSPixi.InvalidateStage();
			}
		}
	}

	public static inline function forceUpdateTransform(clip : DisplayObject) : Void {
		if (clip.parent != null && !clip.visible) {
			forceUpdateTransform(clip.parent);
			clip.updateTransform();
		}
	}

	public static inline function getClipWorldVisible(clip : DisplayObject) : Bool {
		return untyped clip.visible;
	}

	public static function updateClipInteractive(clip : DisplayObject, ?interactiveChildren : Bool = false) : Void {
		clip.interactive = clip.listeners("pointerout").length > 0 || clip.listeners("pointerover").length > 0;
		clip.interactiveChildren = clip.interactive || interactiveChildren;

		if (clip.interactive) {
			setChildrenInteractive(clip);
		} else {
			if (!clip.interactiveChildren) {
				var children : Array<Dynamic> = untyped clip.children;

				if (children != null) {
					for (c in children) {
						if (c.interactiveChildren) {
							clip.interactiveChildren = true;
						}
					}
				}
			}

			if (clip.interactiveChildren) {
				setChildrenInteractive(clip);
			}
		}

		if (clip.parent != null && clip.parent.interactiveChildren != clip.interactiveChildren) {
			updateClipInteractive(clip.parent, clip.interactiveChildren);
		}
	}

	public static function setChildrenInteractive(clip : DisplayObject) : Void {
		var children : Array<Dynamic> = untyped clip.children;

		if (children != null) {
			for (c in children) {
				if (!c.interactiveChildren) {
					c.interactiveChildren = true;

					setChildrenInteractive(c);
				}
			}
		}
	}

	// setScrollRect cancels setClipMask and vice versa
	public static inline function setScrollRect(clip : Container, left : Float, top : Float, width : Float, height : Float) : Void {
		var scrollRect : FlowGraphics = untyped clip.scrollRect;

		if (scrollRect != null) {
			setClipX(clip, clip.x + scrollRect.x * 2 - left);
			setClipY(clip, clip.y + scrollRect.y * 2 - top);

			scrollRect.clear();
		} else {
			setClipX(clip, clip.x - left);
			setClipY(clip, clip.y - top);

			untyped clip.scrollRect = new FlowGraphics();
			scrollRect = untyped clip.scrollRect;
			clip.addChild(scrollRect);
			setClipMask(clip, scrollRect);
		}

		scrollRect.beginFill(0xFFFFFF);
		scrollRect.drawRect(0.0, 0.0, width, height);

		setClipX(scrollRect, left);
		setClipY(scrollRect, top);

		InvalidateStage(clip);
	}

	public static inline function removeScrollRect(clip : Container) : Void {
		var scrollRect : FlowGraphics = untyped clip.scrollRect;

		if (scrollRect != null) {
			setClipX(clip, clip.x + scrollRect.x);
			setClipY(clip, clip.y + scrollRect.y);

			clip.removeChild(scrollRect);

			if (clip.mask == scrollRect) {
				clip.mask = null;
			}

			untyped clip.scrollRect = null;
		}

		InvalidateStage(clip);
	}

	// setClipMask cancels setScrollRect and vice versa
	public static inline function setClipMask(clip : Container, maskContainer : Container) : Void {
		if (maskContainer != untyped clip.scrollRect) {
			removeScrollRect(clip);
		}

		clip.mask = null;

		if (RenderSupportJSPixi.RendererType == "webgl") {
			clip.mask = getFirstGraphics(maskContainer);
		} else {
			untyped clip.alphaMask = null;

			// If it's one Graphics, use clip mask; otherwise use alpha mask
			var obj : Dynamic = maskContainer;
			while (obj.children != null && obj.children.length == 1)
				obj = obj.children[0];

			if (untyped __instanceof__(obj, FlowGraphics)) {
				clip.mask = obj;
			} else {
				untyped clip.alphaMask = maskContainer;
			}
		}

		if (clip.mask != null) {
			untyped maskContainer.isMask = true;
			untyped clip.mask.isMask = true;

			clip.mask.once("removed", function () { clip.mask = null; });
		} else if (untyped clip.alphaMask != null) {
			untyped maskContainer.isMask = true;
		}

		maskContainer.once("childrenchanged", function () { setClipMask(clip, maskContainer); });
		clip.emit("graphicschanged");

		InvalidateStage(clip);
	}

	// Get the first Graphics from the Pixi DisplayObjects tree
	public static function getFirstGraphicsOrSprite(clip : Container) : Container {
		if (untyped __instanceof__(clip, FlowGraphics) || untyped __instanceof__(clip, FlowSprite))
			return clip;

		for (c in clip.children) {
			var g = getFirstGraphicsOrSprite(untyped c);

			if (g != null) {
				return g;
			}
		}

		return null;
	}

	// Get the first Graphics from the Pixi DisplayObjects tree
	public static function getFirstGraphics(clip : Container) : Container {
		if (untyped __instanceof__(clip, FlowGraphics))
			return clip;

		for (c in clip.children) {
			var g = getFirstGraphics(untyped c);

			if (g != null) {
				return g;
			}
		}

		return null;
	}

	public static function emitEvent(parent : DisplayObject, event : String, ?value : Dynamic) : Void {
		parent.emit(event, value);

		if (parent.parent != null) {
			emitEvent(parent.parent, event, value);
		}
	}

	public static function broadcastEvent(parent : DisplayObject, event : String, ?value : Dynamic) : Void {
		parent.emit(event, value);

		var children : Array<Dynamic> = untyped parent.children;
		if (children != null) {
			for (c in children) {
				broadcastEvent(c, event, value);
			}
		}

		if (parent.mask != null) {
			broadcastEvent(parent.mask, event, value);
		}
	}

	public static function onAdded(clip : DisplayObject, fn : Void -> (Void -> Void)) : Void {
		var disp = function () {};

		if (clip.parent == null) {
			clip.once("added", function () {
				disp = fn();
			});
		} else {
			disp = fn();
		}

		clip.once("removed", function () {
			disp();
			onAdded(clip, fn);
		});
	}
}