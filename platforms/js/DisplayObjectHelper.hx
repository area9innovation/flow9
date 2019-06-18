import pixi.core.display.DisplayObject;
import pixi.core.display.Container;
import pixi.core.display.Bounds;

class DisplayObjectHelper {
	public static var Redraw : Bool = Util.getParameter("redraw") != null ? Util.getParameter("redraw") == "1" : false;

	public static inline function invalidateStage(clip : DisplayObject) : Void {
		if (getClipWorldVisible(clip)) {
			if (DisplayObjectHelper.Redraw && (untyped clip.updateGraphics == null || untyped clip.updateGraphics.parent == null)) {
				var updateGraphics = new FlowGraphics();

				if (untyped clip.updateGraphics == null) {
					untyped clip.updateGraphics = updateGraphics;
					updateGraphics.beginFill(0x0000FF, 0.2);
					updateGraphics.drawRect(0, 0, 100, 100);
				} else {
					updateGraphics = untyped clip.updateGraphics;
				}

				untyped updateGraphics._visible = true;
				untyped updateGraphics.visible = true;
				untyped updateGraphics.clipVisible = true;
				untyped updateGraphics.renderable = true;

				untyped __js__("PIXI.Container.prototype.addChild.call({0}, {1})", clip, updateGraphics);

				Native.timer(100, function () {
					untyped __js__("if ({0}.parent) PIXI.Container.prototype.removeChild.call({0}.parent, {0})", updateGraphics);
					RenderSupportJSPixi.InvalidateStage();
					RenderSupportJSPixi.InvalidateTransform();
				});
			}

			RenderSupportJSPixi.InvalidateStage();
			RenderSupportJSPixi.InvalidateTransform();
		}
	}

	public static inline function invalidateTransform(clip : DisplayObject) : Void {
		untyped clip.transformChanged = true;
		invalidateStage(clip);
	}

	public static inline function invalidateTransformByParent(clip : DisplayObject) : Void {
		untyped clip.transformChanged = true;
		if (clip.parent != null) {
			invalidateStage(clip.parent);
		}
	}

	public static inline function setClipX(clip : DisplayObject, x : Float) : Void {
		if (untyped clip.scrollRect != null) {
			x = x - untyped clip.scrollRect.x;
		}

		if (clip.x != x) {
			clip.x = x;
			invalidateTransform(clip);
		}
	}

	public static inline function setClipY(clip : DisplayObject, y : Float) : Void {
		if (untyped clip.scrollRect != null) {
			y = y - untyped clip.scrollRect.y;
		}

		if (clip.y != y) {
			clip.y = y;
			invalidateTransform(clip);
		}
	}

	public static inline function setClipScaleX(clip : DisplayObject, scale : Float) : Void {
		if (clip.scale.x != scale) {
			clip.scale.x = scale;
			invalidateTransform(clip);
		}
	}

	public static inline function setClipScaleY(clip : DisplayObject, scale : Float) : Void {
		if (clip.scale.y != scale) {
			clip.scale.y = scale;
			invalidateTransform(clip);
		}
	}

	public static inline function setClipRotation(clip : DisplayObject, rotation : Float) : Void {
		if (clip.rotation != rotation) {
			clip.rotation = rotation;
			invalidateTransform(clip);
		}
	}

	public static inline function setClipAlpha(clip : DisplayObject, alpha : Float) : Void {
		if (clip.alpha != alpha) {
			clip.alpha = alpha;
			invalidateTransform(clip);
		}
	}

	public static inline function setClipVisible(clip : DisplayObject, visible : Bool) : Void {
		if (untyped clip._visible != visible) {
			untyped clip._visible = visible;

			if (clip.parent != null && getClipVisible(clip.parent)) {
				updateClipWorldVisible(clip);
			}

			invalidateTransformByParent(clip);
		}
	}

	public static inline function updateClipWorldVisible(clip : DisplayObject, ?updateAccess : Bool = true) : Void {
		untyped clip.clipVisible = clip.parent != null && untyped clip._visible && getClipVisible(clip.parent);
		clip.visible = clip.parent != null && getClipWorldVisible(clip.parent) && (untyped clip.isMask || (getClipVisible(clip) && clip.renderable));

		if (clip.interactive && !getClipWorldVisible(clip)) {
			clip.emit("pointerout");
		}

		var updateAccessWidget = updateAccess && untyped clip.accessWidget != null;

		var children : Array<Dynamic> = untyped clip.children;
		if (children != null) {
			for (c in children) {
				if (getClipWorldVisible(c) != getClipWorldVisible(clip) || getClipVisible(c) != getClipVisible(clip)) {
					updateClipWorldVisible(c, updateAccess && !updateAccessWidget);
				}
			}
		}

		if (updateAccessWidget) {
			untyped clip.accessWidget.updateDisplay();
 		}
	}

	public static inline function getClipVisible(clip : DisplayObject) : Bool {
		return untyped clip.clipVisible;
	}

	public static inline function setClipRenderable(clip : DisplayObject, renderable : Bool) : Void {
		if (clip.renderable != renderable) {
			clip.renderable = renderable;

			if (clip.parent != null && getClipWorldVisible(clip.parent)) {
				updateClipWorldVisible(clip);
			}

			invalidateTransformByParent(clip);
		}
	}

	public static function setClipFocus(clip : DisplayObject, focus : Bool) : Bool {
		var accessWidget = untyped clip.accessWidget;

		if (untyped clip.setFocus != null && clip.setFocus(focus)) {
			return true;
		} else if (accessWidget != null && accessWidget.element != null && accessWidget.element.parentNode != null && accessWidget.element.tabIndex != null) {
			if (focus && accessWidget.element.focus != null) {
				accessWidget.element.focus();

				return true;
			} else if (!focus && accessWidget.element.blur != null) {
				accessWidget.element.blur();

				return true;
			}
		}

		var children : Array<Dynamic> = untyped clip.children;

		if (children != null) {
			for (c in children) {
				if (setClipFocus(c, focus)) {
					return true;
				}
			}
		}

		return false;
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
	public static inline function setScrollRect(clip : FlowContainer, left : Float, top : Float, width : Float, height : Float) : Void {
		var scrollRect : FlowGraphics = clip.scrollRect;

		if (scrollRect != null) {
			setClipX(clip, clip.x + scrollRect.x * 2 - left);
			setClipY(clip, clip.y + scrollRect.y * 2 - top);

			scrollRect.clear();
		} else {
			setClipX(clip, clip.x - left);
			setClipY(clip, clip.y - top);

			clip.scrollRect = new FlowGraphics();
			scrollRect = clip.scrollRect;
			clip.addChild(scrollRect);
			setClipMask(clip, scrollRect);
		}

		scrollRect.beginFill(0xFFFFFF);
		scrollRect.drawRect(0.0, 0.0, width, height);

		setClipX(scrollRect, left);
		setClipY(scrollRect, top);

		invalidateStage(clip);
	}

	public static inline function removeScrollRect(clip : FlowContainer) : Void {
		var scrollRect : FlowGraphics = clip.scrollRect;

		if (scrollRect != null) {
			setClipX(clip, clip.x + scrollRect.x);
			setClipY(clip, clip.y + scrollRect.y);

			clip.removeChild(scrollRect);

			if (clip.mask == scrollRect) {
				clip.mask = null;
			}

			clip.scrollRect = null;
		}

		invalidateStage(clip);
	}

	// setClipMask cancels setScrollRect and vice versa
	public static inline function setClipMask(clip : FlowContainer, maskContainer : Container) : Void {
		if (maskContainer != clip.scrollRect) {
			removeScrollRect(clip);
		}

		if (clip.mask != null) {
			untyped clip.mask.child = null;
			clip.mask = null;
		}

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
			untyped clip.mask.child = clip;

			clip.mask.once("removed", function () { clip.mask = null; });
		} else if (untyped clip.alphaMask != null) {
			untyped maskContainer.isMask = true;
			untyped maskContainer.child = clip;
		}

		maskContainer.once("childrenchanged", function () { setClipMask(clip, maskContainer); });
		clip.emit("graphicschanged");

		invalidateStage(clip);
	}

	public static function getMaskedBounds(clip : DisplayObject) : Bounds {
		var calculatedBounds = new Bounds();

		calculatedBounds.minX = Math.NEGATIVE_INFINITY;
		calculatedBounds.minY = Math.NEGATIVE_INFINITY;
		calculatedBounds.maxX = Math.POSITIVE_INFINITY;
		calculatedBounds.maxY = Math.POSITIVE_INFINITY;

		var parentBounds = clip.parent != null ? getMaskedBounds(clip.parent) : null;

		if (untyped clip._mask != null) {
			untyped clip._mask.renderable = true;
			var maskBounds = untyped clip._mask.getBounds(true);

			calculatedBounds.minX = maskBounds.x;
			calculatedBounds.minY = maskBounds.y;
			calculatedBounds.maxX = calculatedBounds.minX + maskBounds.width;
			calculatedBounds.maxY = calculatedBounds.minY + maskBounds.height;

			untyped clip._mask.renderable = false;
		}

		if (parentBounds != null) {
			calculatedBounds.minX = parentBounds.minX > calculatedBounds.minX ? parentBounds.minX : calculatedBounds.minX;
			calculatedBounds.minY = parentBounds.minY > calculatedBounds.minY ? parentBounds.minY : calculatedBounds.minY;
			calculatedBounds.maxX = parentBounds.maxX < calculatedBounds.maxX ? parentBounds.maxX : calculatedBounds.maxX;
			calculatedBounds.maxY = parentBounds.maxY < calculatedBounds.maxY ? parentBounds.maxY : calculatedBounds.maxY;
		}

		return calculatedBounds;
	}

	public static function getMaskedLocalBounds(clip : DisplayObject) : Bounds {
		if (untyped clip.viewBounds != null) {
			return untyped clip.viewBounds;
		}

		var bounds = getMaskedBounds(clip);
		var worldTransform = clip.worldTransform.clone().invert();

		bounds.minX = bounds.minX * worldTransform.a + bounds.minY * worldTransform.c + worldTransform.tx;
		bounds.minY = bounds.minX * worldTransform.b + bounds.minY * worldTransform.d + worldTransform.ty;
		bounds.maxX = bounds.maxX * worldTransform.a + bounds.maxY * worldTransform.c + worldTransform.tx;
		bounds.maxY = bounds.maxX * worldTransform.b + bounds.maxY * worldTransform.d + worldTransform.ty;

		return bounds;
	}

	public static function getClipTreePosition(clip : DisplayObject) : Array<Int> {
		if (clip.parent != null) {
			var clipTreePosition = getClipTreePosition(clip.parent);
			clipTreePosition.push(clip.parent.children.indexOf(clip));
			return clipTreePosition;
		} else {
			return [];
		}
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