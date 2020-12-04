import js.Browser;
import js.html.Element;
import js.html.CanvasElement;
import js.html.File;
import js.html.FileList;

import pixi.core.display.DisplayObject;
import pixi.core.display.Container;
import pixi.core.display.Bounds;
import pixi.core.math.Matrix;
import pixi.core.math.Point;

class DisplayObjectHelper {
	public static var Redraw : Bool = Util.getParameter("redraw") == "1";
	public static var DebugUpdate : Bool = Util.getParameter("debugupdate") == "1";
	public static var BoxShadow : Bool = ((Platform.isChrome || Platform.isFirefox) && !Platform.isMobile) ?
		Util.getParameter("boxshadow") != "0" : Util.getParameter("boxshadow") == "1";
	public static var InvalidateRenderable : Bool = Util.getParameter("renderable") != "0";
	public static var DebugAccessOrder : Bool = Util.getParameter("accessorder") == "1";

	private static var InvalidateStage : Bool = true;

	public static function log(s : Dynamic) : Void {
		untyped __js__("console.log(s)");
	}

	public static function debugger() : Void {
		untyped __js__('debugger');
	}

	public static inline function lockStage() {
		InvalidateStage = false;
	}

	public static inline function unlockStage() {
		InvalidateStage = true;
	}

	public static inline function round(n : Float) : Float {
		return RenderSupport.RoundPixels ? Math.round(n) : Math.round(n * 10.0 * RenderSupport.backingStoreRatio) / (10.0 * RenderSupport.backingStoreRatio);
	}

	public static inline function floor(n : Float) : Float {
		return RenderSupport.RoundPixels ? Math.floor(n) : Math.floor(n * 10.0 * RenderSupport.backingStoreRatio) / (10.0 * RenderSupport.backingStoreRatio);
	}

	public static inline function ceil(n : Float) : Float {
		return RenderSupport.RoundPixels ? Math.ceil(n) : Math.ceil(n * 10.0 * RenderSupport.backingStoreRatio) / (10.0 * RenderSupport.backingStoreRatio);
	}

	public static function invalidateStage(clip : DisplayObject) : Void {
		if (InvalidateStage && (clip.visible || (clip.parent != null && clip.parent.visible)) && untyped clip.stage != null) {
			if (untyped DisplayObjectHelper.Redraw && (clip.updateGraphics == null || clip.updateGraphics.parent == null)) {
				var updateGraphics = new FlowGraphics();

				if (untyped clip.updateGraphics == null) {
					untyped clip.updateGraphics = updateGraphics;
					updateGraphics.beginFill(0x0000FF, 0.2);
					var localBounds = clip.getLocalBounds();
					updateGraphics.drawRect(localBounds.x, localBounds.y, localBounds.width, localBounds.height);
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
				});
			}

			untyped clip.stage.invalidateStage();
		}
	}

	public static function updateStage(clip : DisplayObject, ?clear : Bool = false) : Void {
		if (untyped clip.stage != null) {
			return;
		}

		if (!clear && clip.parent != null) {
			if (untyped clip.parent.stage != null && untyped clip.parent.stage != untyped clip.stage) {
				untyped clip.stage = untyped clip.parent.stage;

				var children : Array<DisplayObject> = untyped clip.children;

				if (children != null) {
					for (c in children) {
						updateStage(c);
					}
				}
			} else if (clip.parent == RenderSupport.PixiStage) {
				untyped clip.stage = clip;
				if (RenderSupport.RendererType != "html") {
					untyped clip.createView(clip.parent.children.indexOf(clip) + 1);
				}

				var children : Array<DisplayObject> = untyped clip.children;

				if (children != null) {
					for (c in children) {
						updateStage(c);
					}
				}
			}
		} else {
			untyped clip.stage = null;
			var children : Array<DisplayObject> = untyped clip.children;

			if (children != null) {
				for (c in children) {
					updateStage(c, true);
				}
			}
		}
	}

	public static function invalidateTransform(clip : DisplayObject, ?from : String, ?force : Bool = false) : Void {
		if (InvalidateStage) {
			invalidateParentTransform(clip);
		}

		invalidateWorldTransform(clip, true, DebugUpdate ? from + ' ->\ninvalidateTransform' : null, force);
	}

	public static function invalidateWorldTransform(clip : DisplayObject, ?localTransformChanged : Bool, ?from : String, ?parentClip : DisplayObject, ?force : Bool = false) : Void {
		if (untyped clip.parent != null && (!clip.worldTransformChanged || (localTransformChanged && !clip.localTransformChanged) || force)) {
			untyped clip.worldTransformChanged = true;
			untyped clip.transformChanged = true;

			if (untyped !parentClip) {
				parentClip = untyped clip.parentClip != null ? clip.parentClip : findParentClip(clip);
			}

			untyped clip.parentClip = parentClip;

			if (isNativeWidget(clip)) {
				parentClip = clip;
			}

			if (localTransformChanged || force) {
				untyped clip.localTransformChanged = true;

				if (DebugUpdate) {
					if (untyped clip.from) {
						untyped clip.from = untyped clip.from + '\n---------\n' + from;
					} else {
						untyped clip.from = from;
					}
				}
			}

			if (RenderSupport.RendererType != "html") {
				untyped clip.rvlast = null;
			}

			if (untyped clip.child != null && clip.localTransformChanged) {
				invalidateTransform(untyped clip.child, DebugUpdate ? from + ' ->\ninvalidateWorldTransform -> mask child' : null);
			}

			for (child in getClipChildren(clip)) {
				if (child.visible) {
					invalidateWorldTransform(child, localTransformChanged && !isNativeWidget(clip), DebugUpdate ? from + ' ->\ninvalidateWorldTransform -> child' : null, parentClip, force);
				}
			}
		}
	}

	public static function invalidateParentTransform(clip : DisplayObject) : Void {
		if (clip.parent != null) {
			untyped clip.transformChanged = true;

			if (isCanvas(clip)) {
				untyped clip.localTransformChanged = true;
			}

			if (RenderSupport.RendererType != "html") {
				untyped clip.rvlast = null;
			}

			if (untyped clip.parent.parent != null && (!clip.parent.transformChanged || (isCanvas(clip.parent) && !clip.parent.localTransformChanged))) {
				invalidateParentTransform(clip.parent);
			} else {
				invalidateParentLocalBounds(clip);
				invalidateStage(clip);
			}
		}
	}

	public static function invalidateParentLocalBounds(clip : DisplayObject) : Void {
		if (untyped !clip.visible && clip.clipVisible && !clip.localBoundsChanged) {
			untyped clip.localBoundsChanged = true;

			if (untyped clip.parent != null && !clip.parent.transformChanged) {
				invalidateParentLocalBounds(clip.parent);
			}
		}
	}

	public static function invalidateVisible(clip : DisplayObject, ?updateAccess : Bool = true, ?parentClip : DisplayObject) : Void {
		var clipVisible = clip.parent != null && untyped clip._visible && getClipVisible(clip.parent);
		var visible = untyped clip.parent != null && (getClipRenderable(clip.parent) || clip.keepNativeWidgetChildren)
			&& (clip.isMask || (clipVisible && (clip.renderable || clip.keepNativeWidgetChildren)));

		if (untyped !parentClip) {
			parentClip = untyped clip.parentClip != null ? clip.parentClip : findParentClip(clip);
		}

		untyped clip.parentClip = parentClip;

		if (untyped clip.clipVisible != clipVisible || clip.visible != visible) {
			untyped clip.clipVisible = clipVisible;
			clip.visible = visible;

			clip.emit("visible");

			var updateAccessWidget = updateAccess && untyped clip.accessWidget != null;

			if (isNativeWidget(clip)) {
				parentClip = clip;
			}

			for (child in getClipChildren(clip)) {
				invalidateVisible(child, updateAccess && !updateAccessWidget, parentClip);
			}

			if (RenderSupport.RendererType != "html" && updateAccessWidget) {
				untyped clip.accessWidget.updateDisplay();
			}

			invalidateTransform(clip, 'invalidateVisible');
		}
	}

	public static function invalidateInteractive(clip : DisplayObject, ?interactiveChildren : Bool = false) : Void {
		clip.interactive = untyped clip.scrollRectListener != null || clip.listeners("pointerout").length > 0 || clip.listeners("pointerover").length > 0 || clip.cursor != null || clip.isInteractive;
		clip.interactiveChildren = clip.interactive || interactiveChildren;

		if (clip.interactive) {
			if (RenderSupport.RendererType == "html") {
				if (!isNativeWidget(clip)) {
					initNativeWidget(clip);
				} else {
					invalidateTransform(clip, 'invalidateInteractive');
				}
			}

			setChildrenInteractive(clip);
		} else {
			if (!clip.interactiveChildren) {
				var children : Array<Dynamic> = untyped clip.children;
				var i = 0;

				while (children.length > i && !clip.interactiveChildren) {
					if (children[i].interactiveChildren) {
						clip.interactiveChildren = true;
					}

					i++;
				}
			}

			if (clip.interactiveChildren) {
				setChildrenInteractive(clip);
			}
		}

		if (clip.parent != null && clip.parent.interactiveChildren != clip.interactiveChildren) {
			invalidateInteractive(clip.parent, clip.interactiveChildren);
		}
	}

	public static function setChildrenInteractive(clip : DisplayObject) : Void {
		if (RenderSupport.RendererType == "html") {
			return;
		}

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

	public static function invalidate(clip : DisplayObject) : Void {
		updateStage(clip);

		if (clip.parent != null) {
			invalidateParentClip(clip);
			invalidateVisible(clip);
			invalidateInteractive(clip, clip.parent.interactiveChildren);
			invalidateTransform(clip, 'invalidate');

			if (untyped clip.parent.hasMask) {
				updateHasMask(clip);
			}

			if (untyped clip.parent.isMask) {
				updateIsMask(clip);
			}

			if (isCanvas(clip.parent)) {
				updateIsCanvas(clip);
			}

			if (untyped clip.keepNativeWidgetChildren || clip.keepNativeWidget) {
				updateKeepNativeWidgetChildren(clip);
			}

			clip.once('removed', function() { invalidate(clip); });
		} else {
			untyped clip.worldTransformChanged = false;
			untyped clip.transformChanged = false;
			untyped clip.localTransformChanged = false;
			untyped clip.visible = false;

			if (isNativeWidget(clip)) {
				updateNativeWidgetDisplay(clip);
			}
		}
	}

	public static function invalidateParentClip(clip : DisplayObject, ?parentClip : DisplayObject) : Void {
		if (untyped !parentClip) {
			parentClip = findParentClip(clip);
		}

		untyped clip.parentClip = parentClip;

		if (isNativeWidget(clip)) {
			for (child in getClipChildren(clip)) {
				if (untyped child.parentClip != clip) {
					invalidateParentClip(child, clip);
				}
			}
		} else {
			for (child in getClipChildren(clip)) {
				invalidateParentClip(child, parentClip);
			}
		}
	}

	public static inline function setClipX(clip : DisplayObject, x : Float) : Void {
		if (untyped clip.scrollRect != null) {
			x = x - untyped clip.scrollRect.x;
		}

		if (untyped !clip.destroyed && clip.x != x) {
			var from = DebugUpdate ? 'setClipX ' + clip.x + ' : ' + x : null;

			clip.x = x;
			invalidateTransform(clip, from);
		}
	}

	public static inline function setClipY(clip : DisplayObject, y : Float) : Void {
		if (untyped clip.scrollRect != null) {
			y = y - untyped clip.scrollRect.y;
		}

		if (untyped !clip.destroyed && clip.y != y) {
			var from = DebugUpdate ? 'setClipY ' + clip.y + ' : ' + y : null;

			clip.y = y;
			invalidateTransform(clip, from);
		}
	}

	public static inline function setClipScaleX(clip : DisplayObject, scale : Float) : Void {
		if (untyped !clip.destroyed && clip.scale.x != scale) {
			var from = DebugUpdate ? 'setClipScaleX ' + clip.scale.x + ' : ' + scale : null;

			clip.scale.x = scale;

			if (RenderSupport.RendererType == "html" && scale != 0.0) {
				initNativeWidget(clip);
			}

			invalidateTransform(clip, from);
		}
	}

	public static inline function setClipScaleY(clip : DisplayObject, scale : Float) : Void {
		if (untyped !clip.destroyed && clip.scale.y != scale) {
			var from = DebugUpdate ? 'setClipScaleY ' + clip.scale.y + ' : ' + scale : null;

			clip.scale.y = scale;

			if (RenderSupport.RendererType == "html" && scale != 0.0) {
				initNativeWidget(clip);
			}

			invalidateTransform(clip, from);
		}
	}

	public static inline function setClipRotation(clip : DisplayObject, rotation : Float) : Void {
		if (untyped !clip.destroyed && clip.rotation != rotation) {
			var from = DebugUpdate ? 'setClipRotation ' + clip.rotation + ' : ' + rotation : null;

			clip.rotation = rotation;
			invalidateTransform(clip, from);
		}
	}

	public static inline function setClipOrigin(clip : DisplayObject, x : Float, y : Float) : Void {
		if (untyped !clip.destroyed && clip.origin == null || (clip.origin.x != x && clip.origin.y != y)) {
			var from = DebugUpdate ? 'setClipOrigin ' + untyped clip.origin + ' : ' + x + ' ' + y : null;

			untyped clip.origin = new Point(x, y);

			if (RenderSupport.RendererType == "html") {
				initNativeWidget(clip);

				if (untyped clip.nativeWidget != null) {
					untyped clip.nativeWidget.style.transformOrigin = clip.origin.x * 100 + "% " + (clip.origin.y * 100 + "%");

					untyped clip.transform.pivot.x = 0.0;
					untyped clip.transform.pivot.y = 0.0;
				} else {
					untyped clip.transform.pivot.x = getWidth(clip) * clip.origin.x;
					untyped clip.transform.pivot.y = getHeight(clip) * clip.origin.y;
				}
			} else {
				untyped clip.transform.pivot.x = getWidth(clip) * clip.origin.x;
				untyped clip.transform.pivot.y = getHeight(clip) * clip.origin.y;
			}

			invalidateTransform(clip, from);
		}
	}

	public static inline function setClipAlpha(clip : DisplayObject, alpha : Float) : Void {
		if (untyped !clip.destroyed && clip.alpha != alpha) {
			var from = DebugUpdate ? 'setClipAlpha ' + clip.alpha + ' : ' + alpha : null;

			clip.alpha = alpha;
			invalidateTransform(clip, from);
		}
	}

	public static inline function setClipVisible(clip : DisplayObject, visible : Bool) : Void {
		if (untyped clip._visible != visible) {
			untyped clip._visible = visible;
			invalidateVisible(clip);
		}
	}

	public static inline function setClipRenderable(clip : DisplayObject, renderable : Bool) : Void {
		if (clip.renderable != renderable) {
			clip.renderable = renderable;
			invalidateVisible(clip);

			if (untyped !clip.keepNativeWidget) {
				invalidateTransform(clip, 'setClipRenderable');
			}
		}
	}

	public static inline function forceClipRenderable(clip : DisplayObject, ?renderable : Bool = true) : Void {
		setClipRenderable(clip, renderable);

		for (child in getClipChildren(clip)) {
			if (untyped child.clipVisible && !child.isMask) {
				forceClipRenderable(child, renderable);
			}
		}
	}

	public static inline function getClipVisible(clip : DisplayObject) : Bool {
		return untyped clip.clipVisible;
	}

	public static inline function getClipRenderable(clip : DisplayObject) : Bool {
		return untyped clip.visible;
	}

	public static inline function setClipCursor(clip : DisplayObject, cursor : String) : Void {
		if (untyped clip.cursor != cursor) {
			untyped clip.cursor = cursor;

			if (RenderSupport.RendererType == "html" && !isNativeWidget(clip)) {
				initNativeWidget(clip);
			}

			invalidateTransform(clip, 'setClipCursor');
		}
	}

	public static function setClipFocus(clip : DisplayObject, focus : Bool) : Bool {
		var accessWidget = untyped clip.accessWidget;

		if (untyped clip.setFocus != null && clip.setFocus(focus)) {
			return true;
		} else if (accessWidget != null && accessWidget.element != null && accessWidget.element.parentNode != null && accessWidget.element.tabIndex != null) {
			if (focus && accessWidget.element.focus != null) {
				accessWidget.element.focus();
				if (RenderSupport.EnableFocusFrame) accessWidget.element.classList.add("focused");

				return true;
			} else if (!focus && accessWidget.element.blur != null) {
				accessWidget.element.blur();
				accessWidget.element.classList.remove("focused");

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

	// setScrollRect cancels setClipMask and vice versa
	public static function setScrollRect(clip : FlowContainer, left : Float, top : Float, width : Float, height : Float) : Void {
		var scrollRect : FlowGraphics = clip.scrollRect;

		left = round(left);
		top = round(top);
		width = round(width);
		height = round(height);

		if (scrollRect != null) {
			if (left == scrollRect.x && top == scrollRect.y && width == scrollRect.width && height == scrollRect.height) {
				return;
			}

			clip.x = clip.x + scrollRect.x - left;
			clip.y = clip.y + scrollRect.y - top;
			untyped clip.localTransformChanged = true;

			scrollRect.clear();
		} else {
			clip.x = clip.x - left;
			clip.y = clip.y - top;
			untyped clip.localTransformChanged = true;

			clip.scrollRect = new FlowGraphics();
			scrollRect = clip.scrollRect;

			setClipMask(clip, scrollRect);
			clip.addChild(scrollRect);
		}

		scrollRect.x = left;
		scrollRect.y = top;

		scrollRect.beginFill(0xFFFFFF);
		scrollRect.drawRect(0.0, 0.0, width, height);
	}

	public static inline function setContentRect(clip : FlowContainer, width : Float, height : Float) : Void {
		if (untyped clip.contentBounds == null) {
			untyped clip.contentBounds = new Bounds();
		}

		var contentBounds = untyped clip.contentBounds;

		contentBounds.minX = 0.0;
		contentBounds.minY = 0.0;
		contentBounds.maxX = width;
		contentBounds.maxY = height;

		invalidateTransform(clip, "setContentRect");
	}

	public static inline function listenScrollRect(clip : FlowContainer, cb : Float -> Float -> Void) : Void -> Void {
		untyped clip.scrollRectListener = cb;

		invalidateInteractive(clip);
		invalidateTransform(clip, "listenScrollRect");

		return function() {
			untyped clip.scrollRectListener = null;

			invalidateInteractive(clip);
			invalidateTransform(clip, "listenScrollRect disposer");
		}
	}

	public static inline function removeScrollRect(clip : FlowContainer) : Void {
		untyped clip.scrollRectListener = null;
		var scrollRect : FlowGraphics = clip.scrollRect;

		if (scrollRect != null) {
			setClipX(clip, clip.x + scrollRect.x);
			setClipY(clip, clip.y + scrollRect.y);

			clip.removeChild(scrollRect);

			if (clip.mask == scrollRect) {
				clip.mask = null;
			}

			clip.scrollRect = null;
			clip.mask = null;
			untyped clip.maskContainer = null;

			invalidateTransform(clip, 'removeScrollRect');
		}
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

		if (RenderSupport.RendererType == "webgl") {
			clip.mask = getFirstGraphics(maskContainer);
		} else {
			untyped clip.alphaMask = null;

			// If it's one Graphics, use clip mask; otherwise use alpha mask
			var obj : Dynamic = maskContainer;
			while (obj.children != null && obj.children.length == 1)
				obj = obj.children[0];

			if (untyped HaxeRuntime.instanceof(obj, FlowGraphics)) {
				clip.mask = obj;
			} else if (untyped HaxeRuntime.instanceof(obj, FlowSprite)) {
				untyped clip.alphaMask = obj;
			}
		}

		if (clip.mask != null) {
			untyped maskContainer.child = clip;
			untyped clip.mask.child = clip;
			untyped clip.maskContainer = maskContainer;

			if (RenderSupport.RendererType == "html" && (Platform.isIE || Platform.isEdge) && untyped clip.mask.isSvg) {
				updateHasMask(clip);
			}

			clip.mask.once("removed", function () { clip.mask = null; });
		} else if (untyped clip.alphaMask != null) {
			untyped maskContainer.child = clip;
			untyped maskContainer.url = clip.alphaMask.url;
			untyped clip.alphaMask.child = clip;
			untyped clip.maskContainer = maskContainer;

			updateHasMask(clip);

			untyped clip.alphaMask.once("removed", function () { untyped clip.alphaMask = null; });
		}


		updateIsMask(maskContainer);
		setClipRenderable(maskContainer, false);
		maskContainer.once("childrenchanged", function () { setClipMask(clip, maskContainer); });

		if (RenderSupport.RendererType == "html") {
			if (untyped clip.mask != null || clip.alphaMask != null) {
				initNativeWidget(clip);
			}
		}

		invalidateTransform(clip, 'setClipMask');
	}

	public static function updateHasMask(clip : DisplayObject) : Void {
		if (RenderSupport.RendererType == "html") {
			if (!untyped clip.hasMask) {
				untyped clip.hasMask = true;

				if (untyped clip.updateNativeWidgetGraphicsData != null) {
					untyped clip.updateNativeWidgetGraphicsData();
				}

				for (child in getClipChildren(clip)) {
					updateHasMask(child);
				}
			}
		}
	}

	public static function updateIsMask(clip : DisplayObject) : Void {
		if (!untyped clip.isMask) {
			untyped clip.isMask = true;
			untyped clip.emitChildrenChanged = true;

			for (child in getClipChildren(clip)) {
				updateIsMask(child);
			}
		}
	}

	public static function updateEmitChildrenChanged(clip : DisplayObject) : Void {
		if (!untyped clip.emitChildrenChanged) {
			untyped clip.emitChildrenChanged = true;

			for (child in getClipChildren(clip)) {
				updateEmitChildrenChanged(child);
			}
		}
	}

	public static function updateIsCanvas(clip : DisplayObject) : Void {
		if (clip.parent != null && isCanvas(clip.parent)) {
			untyped clip.isCanvas = true;

			deleteNativeWidget(clip);

			for (child in getClipChildren(clip)) {
				updateIsCanvas(child);
			}
		}
	}

	public static inline function isCanvas(clip : DisplayObject) : Bool {
		return untyped clip.isCanvas;
	}

	public static function updateKeepNativeWidgetChildren(clip : DisplayObject, keepNativeWidgetChildren : Bool = false) : Void {
		untyped clip.keepNativeWidgetChildren = keepNativeWidgetChildren || clip.keepNativeWidget;

		if (untyped !clip.keepNativeWidgetChildren) {
			for (child in getClipChildren(clip)) {
				untyped clip.keepNativeWidgetChildren = clip.keepNativeWidgetChildren || child.keepNativeWidgetChildren || child.keepNativeWidget;
			}
		}

		if (RenderSupport.RendererType == "html" && isNativeWidget(clip)) {
			untyped clip.nativeWidget.style.visibility = untyped clip.keepNativeWidget ? "visible" : clip.keepNativeWidgetChildren ? "inherit" : null;
		}

		if (untyped clip.parent != null && clip.parent.keepNativeWidgetChildren != clip.keepNativeWidgetChildren) {
			updateKeepNativeWidgetChildren(clip.parent, untyped clip.keepNativeWidgetChildren);
		}

		invalidateTransform(clip, 'updateKeepNativeWidgetChildren');
	}

	public static function updateIsAriaHidden(clip : DisplayObject, isAriaHidden : Bool = false) : Void {
		if (isNativeWidget(clip)) {
			if (isAriaHidden) {
				untyped clip.nativeWidget.setAttribute("aria-hidden", 'true');
			} else {
				untyped clip.nativeWidget.removeAttribute("aria-hidden");
			}
		}
		for (child in getClipChildren(clip)) {
			updateIsAriaHidden(child, isAriaHidden);
		}
	}

	public static function getViewBounds(clip : DisplayObject) : Bounds {
		return untyped clip.viewBounds;
	}

	public static function updateTreeIds(clip : DisplayObject, ?clean : Bool = false) : Void {
		if (clean) {
			untyped clip.id = [-1];
		} else if (clip.parent == null) {
			untyped clip.id = [0];
		} else {
			untyped clip.id = Array.from(clip.parent.id);
			untyped clip.id.push(clip.parent.children.indexOf(clip));
		}

		var children : Array<Dynamic> = untyped clip.children;
		if (children != null) {
			for (c in children) {
				updateTreeIds(c, clean);
			}
		}
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
	public static function getFirstGraphicsOrSprite(clip : DisplayObject) : DisplayObject {
		if (untyped clip.clipVisible && (untyped HaxeRuntime.instanceof(clip, FlowGraphics) || untyped HaxeRuntime.instanceof(clip, FlowSprite)))
			return clip;

		for (c in getClipChildren(clip)) {
			var g = getFirstGraphicsOrSprite(untyped c);

			if (g != null) {
				return g;
			}
		}

		return null;
	}

	// Get the first Graphics from the Pixi DisplayObjects tree
	public static function getFirstGraphics(clip : DisplayObject) : FlowGraphics {
		if (untyped HaxeRuntime.instanceof(clip, FlowGraphics))
			return cast(clip, FlowGraphics);

		for (c in getClipChildren(clip)) {
			var g = getFirstGraphics(untyped c);

			if (g != null) {
				return g;
			}
		}

		return null;
	}

	public static function getAllSprites(clip : DisplayObject) : Array<FlowSprite> {
		if (untyped HaxeRuntime.instanceof(clip, FlowSprite))
			return [cast(clip, FlowSprite)];

		var r = [];

		for (c in getClipChildren(clip)) {
			r = r.concat(getAllSprites(c));
		}

		return r;
	}

	public static function onImagesLoaded(clip : DisplayObject, cb : Void -> Void) : Void -> Void {
		var sprites = getAllSprites(clip);

		if (sprites.filter(function (sprite) { return !sprite.loaded && sprite.visible && !sprite.failed; }).length > 0) {
			var disp = null;
			var fn = function() { disp = onImagesLoaded(clip, cb); }
			RenderSupport.once("drawframe", fn);

			return function() {
				if (disp != null) { disp(); }
				RenderSupport.off("drawframe", fn);
			};
		} else {
			cb();

			return function() {}
		}
	}

	public static function emitEvent(parent : DisplayObject, event : String, ?value : Dynamic) : Void {
		if (untyped event == "childrenchanged" && !parent.emitChildrenChanged) {
			return;
		}

		parent.emit(event, value);

		if (parent.parent != null) {
			emitEvent(parent.parent, event, value);
		}
	}

	public static function broadcastEvent(parent : DisplayObject, event : String, ?value : Dynamic) : Void {
		parent.emit(event, value);

		for (c in getClipChildren(parent)) {
			broadcastEvent(c, event, value);
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

				clip.once("removed", function () {
					disp();
					onAdded(clip, fn);
				});
			});
		} else {
			disp = fn();

			clip.once("removed", function () {
				disp();
				onAdded(clip, fn);
			});
		}
	}

	public static function onAddedDisposable(clip : DisplayObject, fn0 : Void -> (Void -> Void)) : Void -> Void {
		var disp = function () {};
		var alive = true;
		var fn = function() {
			if (alive) {
				return fn0();
			} else {
				return function () {};
			}
		}

		if (clip.parent == null) {
			clip.once("added", function () {
				disp = fn();

				clip.once("removed", function () {
					disp();
					disp = onAddedDisposable(clip, fn);
				});
			});
		} else {
			disp = fn();

			clip.once("removed", function () {
				disp();
				disp = onAddedDisposable(clip, fn);
			});
		}

		return function() {
			alive = false;
			disp();
		}
	}

	public static function updateClipID(clip : DisplayObject) : Void {
		var nativeWidget = untyped clip.nativeWidget;

		if (nativeWidget != null && nativeWidget.getAttribute("id") == null) {
			nativeWidget.setAttribute('id', untyped __js__("'_' + Math.random().toString(36).substr(2, 9)"));
		}
	}

	public static function updateNativeWidget(clip : DisplayObject) : Void {
		if (untyped clip.updateNativeWidget != null) {
			untyped clip.updateNativeWidget();
		} else {
			if (RenderSupport.RendererType == "html") {
				if (isNativeWidget(clip)) {
					if (clip.visible) {
						if (DebugUpdate) {
							untyped clip.nativeWidget.setAttribute("update", Std.int(clip.nativeWidget.getAttribute("update")) + 1);
							if (untyped clip.from) {
								untyped clip.nativeWidget.setAttribute("from", clip.from);
								untyped clip.from = null;
							}

							if (untyped clip.info) {
								untyped clip.nativeWidget.setAttribute("info", clip.info);
							}
						}

						if (untyped DebugAccessOrder && clip.accessWidget != null) {
							untyped clip.nativeWidget.setAttribute("nodeindex", '${clip.accessWidget.nodeindex}');
						}

						updateNativeWidgetTransformMatrix(clip);
						updateNativeWidgetOpacity(clip);
						updateNativeWidgetMask(clip);

						updateNativeWidgetInteractive(clip);

						if (untyped clip.styleChanged) {
							untyped clip.updateNativeWidgetStyle();
						} else if (untyped clip.updateBaselineWidget != null) {
							untyped clip.updateBaselineWidget();
						}

						updateNativeWidgetFilters(clip);
					}

					updateNativeWidgetDisplay(clip);
				}
			} else if (untyped clip.nativeWidget) {
				updateNativeWidgetTransformMatrix(clip);
				updateNativeWidgetOpacity(clip);

				if (untyped clip.styleChanged) {
					untyped clip.updateNativeWidgetStyle();
				}

				if (untyped Platform.isIE && clip.isFocused) {
					untyped clip.preventBlur = true;

					RenderSupport.once("stagechanged", function() {
						untyped clip.preventBlur = false;
					});
				}
			}
		}
	}

	public static inline function getNativeWidgetTransform(clip : DisplayObject) : Matrix {
		if (RenderSupport.RendererType == "html") {
			if (untyped !clip.parentClip || RenderSupport.RenderContainers) {
				if (untyped clip.localTransformChanged) {
					untyped clip.transform.updateLocalTransform();
				}

				return clip.localTransform;
			} else {
				return prependInvertedMatrix(clip.worldTransform, untyped clip.parentClip.worldTransform);
			}
		} else if (untyped clip.accessWidget != null) {
			return untyped clip.accessWidget.getAccessWidgetTransform();
		} else {
			return clip.worldTransform;
		}
	}

	public static function updateNativeWidgetTransformMatrix(clip : DisplayObject) {
		var nativeWidget = untyped clip.nativeWidget;

		if (untyped clip.localTransformChanged) {
			untyped clip.transform.updateLocalTransform();
		}

		var transform = getNativeWidgetTransform(clip);

		var tx : Float = 0.0;
		var ty : Float = 0.0;

		if (clip.mask != null) {
			var maskWidth = getWidgetWidth(clip.mask);
			var maskHeight = getWidgetHeight(clip.mask);

			if (nativeWidget.firstChild == null) {
				var cont = Browser.document.createElement("div");
				cont.className = 'nativeWidget';
				nativeWidget.appendChild(cont);
			}

			if (nativeWidget.firstChild != null) {
				if (untyped clip.contentBounds != null) {
					nativeWidget.firstChild.style.width = '${untyped Math.max(clip.contentBounds.maxX, maskWidth)}px';
					nativeWidget.firstChild.style.height = '${untyped Math.max(clip.contentBounds.maxY, maskHeight)}px';
				} else if (untyped clip.maxLocalBounds != null) {
					nativeWidget.firstChild.style.width = '${untyped Math.max(clip.maxLocalBounds.maxX, maskWidth)}px';
					nativeWidget.firstChild.style.height = '${untyped Math.max(clip.maxLocalBounds.maxY, maskHeight)}px';
				}
			}

			if (untyped clip.scrollRect != null) {
				var point = applyTransformPoint(new Point(untyped clip.scrollRect.x, untyped clip.scrollRect.y), transform);

				tx = round(point.x);
				ty = round(point.y);
			} else {
				var graphicsData : Dynamic = clip.mask.graphicsData;

				if (graphicsData != null && graphicsData.length > 0) {
					var data = graphicsData[0];
					var transform2 = prependInvertedMatrix(clip.mask.worldTransform, clip.worldTransform);

					if (data.shape.type == 1) {
						var point = applyTransformPoint(applyTransformPoint(new Point(data.shape.x, data.shape.y), transform2), transform);

						tx = round(point.x);
						ty = round(point.y);
					} else if (data.shape.type == 2) {
						var point = applyTransformPoint(applyTransformPoint(new Point(round(data.shape.x - data.shape.radius), round(data.shape.y - data.shape.radius)), transform2), transform);

						tx = round(point.x);
						ty = round(point.y);
					} else if (data.shape.type == 4) {
						var point = applyTransformPoint(applyTransformPoint(new Point(data.shape.x, data.shape.y), transform2), transform);

						tx = round(point.x);
						ty = round(point.y);
					} else {
						tx = round(transform.tx);
						ty = round(transform.ty);
					}
				} else {
					tx = round(transform.tx);
					ty = round(transform.ty);
				}
			}
		} else {
			tx = round(transform.tx);
			ty = round(transform.ty);
		}

		if (untyped clip.left != null && clip.top != null) {
			tx += untyped clip.left * transform.a + clip.top * transform.c;
			ty += untyped clip.left * transform.b + clip.top * transform.d;
			untyped nativeWidget.style.transformOrigin = -clip.left + "px " + (-clip.top + "px");
		}

		var localBounds = untyped clip.localBounds;

		if (isCanvas(clip)) {
			tx -= Math.max(-localBounds.minX, 0.0);
			ty -= Math.max(-localBounds.minY, 0.0);
		}

		if (untyped Math.isFinite(localBounds.minX) && Math.isFinite(localBounds.minY) && clip.nativeWidgetBoundsChanged) {
			untyped clip.nativeWidgetBoundsChanged = false;

			if (isCanvas(clip)) {
				nativeWidget.setAttribute('width', '${Math.ceil(localBounds.maxX * transform.a * RenderSupport.PixiRenderer.resolution) + Math.max(Math.ceil(-localBounds.minX * transform.a * RenderSupport.PixiRenderer.resolution), 0.0)}');
				nativeWidget.setAttribute('height', '${Math.ceil(localBounds.maxY * transform.d * RenderSupport.PixiRenderer.resolution) + Math.max(Math.ceil(-localBounds.minY * transform.d * RenderSupport.PixiRenderer.resolution), 0.0)}');
				nativeWidget.style.width = '${Math.ceil(localBounds.maxX * transform.a * RenderSupport.PixiRenderer.resolution) + Math.max(Math.ceil(-localBounds.minX * transform.a * RenderSupport.PixiRenderer.resolution), 0.0)}px';
				nativeWidget.style.height = '${Math.ceil(localBounds.maxY * transform.d * RenderSupport.PixiRenderer.resolution) + Math.max(Math.ceil(-localBounds.minY * transform.d * RenderSupport.PixiRenderer.resolution), 0.0)}px';
			} else if (untyped clip.alphaMask != null) {
				nativeWidget.style.width = '${localBounds.maxX}px';
				nativeWidget.style.height = '${localBounds.maxY}px';
			} else {
				nativeWidget.style.width = '${getWidgetWidth(clip)}px';
				nativeWidget.style.height = '${getWidgetHeight(clip)}px';
			}

			// nativeWidget.setAttribute('minX', Std.string(localBounds.minX));
			// nativeWidget.setAttribute('minY', Std.string(localBounds.minY));
			// nativeWidget.setAttribute('maxX', Std.string(localBounds.maxX));
			// nativeWidget.setAttribute('maxY', Std.string(localBounds.maxY));

			// nativeWidget.setAttribute('viewMinX', Std.string(untyped clip.viewBounds.minX));
			// nativeWidget.setAttribute('viewMinY', Std.string(untyped clip.viewBounds.minY));
			// nativeWidget.setAttribute('viewMaxX', Std.string(untyped clip.viewBounds.maxX));
			// nativeWidget.setAttribute('viewMaxY', Std.string(untyped clip.viewBounds.maxY));

			// if (untyped clip.mask == null && untyped clip.alphaMask == null) {
			// 	tx = round(transform.tx + round(localBounds.minX));
			// 	ty = round(transform.ty + round(localBounds.minY));

			// 	nativeWidget.style.marginLeft = '${-round(localBounds.minX)}px';
			// 	nativeWidget.style.marginTop = '${-round(localBounds.minY)}px';
			// }

			// applyScrollFn(clip);
		}

		nativeWidget.style.left = tx != 0 ? '${tx}px' : (Platform.isIE ? "0" : null);
		nativeWidget.style.top = ty != 0 ? '${ty}px' : (Platform.isIE ? "0" : null);

		if (isCanvas(clip)) {
			nativeWidget.style.transform = 'matrix(${1.0 / RenderSupport.PixiRenderer.resolution}, 0, 0, ${1.0 / RenderSupport.PixiRenderer.resolution}, 0, 0)';
		} else {
			nativeWidget.style.transform = (transform.a != 1 || transform.b != 0 || transform.c != 0 || transform.d != 1) ?
				'matrix(${transform.a}, ${transform.b}, ${transform.c}, ${transform.d}, 0, 0)' : (Platform.isIE ? "none" : null);
		}

		if (transform.a == 0 || transform.d == 0) {
			invalidateTransform(clip, "updateNativeWidgetTransformMatrix", true);
		}
	}

	public static inline function getNativeWidgetAlpha(clip : DisplayObject) : Float {
		if (RenderSupport.RendererType == "html" && !RenderSupport.RenderContainers) {
			if (untyped clip.parentClip && clip.parentClip.worldAlpha > 0) {
				return clip.worldAlpha / untyped clip.parentClip.worldAlpha;
			} else if (clip.parent != null && !isNativeWidget(clip.parent)) {
				return clip.alpha * getNativeWidgetAlpha(clip.parent);
			} else {
				return clip.alpha;
			}
		} else {
			return clip.alpha;
		}
	}

	public static function updateNativeWidgetOpacity(clip : DisplayObject) {
		var nativeWidget = untyped clip.nativeWidget;
		var alpha = getNativeWidgetAlpha(clip);

		if (untyped clip.isInput) {
			if (Platform.isEdge || Platform.isIE) {
				var slicedColor : Array<String> = untyped clip.style.fill.split(",");
				var newColor = slicedColor.slice(0, 3).join(",") + "," + Std.parseFloat(slicedColor[3]) * (untyped clip.isFocused ? alpha : 0) + ")";

				nativeWidget.style.color = newColor;
			} else {
				nativeWidget.style.opacity = untyped clip.isFocused ? alpha : 0;
			}
		} else {
			nativeWidget.style.opacity = alpha != 1 || Platform.isIE ? alpha : null;
		}
	}

	public static function updateNativeWidgetFilters(clip : DisplayObject) {
		if (untyped clip.parentClip.filters != null && BoxShadow) {
			updateNativeWidgetFilters(untyped clip.parentClip);
		}

		if (untyped clip.filters != null) {
			var filters : Array<Dynamic> = untyped clip.filters;

			if (filters != null && filters.length > 0) {
				var filter = filters[0];

				if (untyped HaxeRuntime.instanceof(filter, DropShadowFilter)) {
					if (untyped BoxShadow || clip.isGraphics()) {
						applyNativeWidgetBoxShadow(clip, filter);
					} else {
						var color : Array<Int> = pixi.core.utils.Utils.hex2rgb(untyped filter.color, []);
						var nativeWidget : Element = untyped clip.nativeWidget;

						if (nativeWidget.children != null) {
							for (childWidget in nativeWidget.children) {
								childWidget.style.boxShadow = null;
							}
						}

						nativeWidget.style.filter = 'drop-shadow(
							${untyped Math.cos(filter.angle) * filter.distance}px
							${untyped Math.sin(filter.angle) * filter.distance}px
							${untyped filter.blur}px
							rgba(${color[0] * 255}, ${color[1] * 255}, ${color[2] * 255}, ${untyped filter.alpha})
						)';
					}
				} else if (untyped HaxeRuntime.instanceof(filter, BlurFilter)) {
					var nativeWidget : Element = untyped clip.nativeWidget;
					nativeWidget.style.filter = 'blur(${filter.blur}px)';
				} else if (untyped HaxeRuntime.instanceof(filter, BlurBackdropFilter)) {
					var nativeWidget : Element = untyped clip.nativeWidget;
					nativeWidget.style.setProperty('backdrop-filter', 'blur(${filter.spread}px)');
					nativeWidget.style.setProperty('-webkit-backdrop-filter', 'blur(${filter.spread}px)');
				}
			}
		}
	}

	private static function applyNativeWidgetBoxShadow(parent : DisplayObject, filter : Dynamic) : Void {
		var color : Array<Int> = pixi.core.utils.Utils.hex2rgb(untyped filter.color, []);
		var clip = getFirstGraphicsOrSprite(parent);

		if (clip == null) {
			return;
		}

		var nativeWidget = untyped clip.nativeWidget;

		if (untyped clip.filterPadding != parent.filterPadding) {
			untyped clip.filterPadding = parent.filterPadding;

			if (untyped clip.updateNativeWidgetGraphicsData != null) {
				untyped clip.updateNativeWidgetGraphicsData();
			}
		}

		if (nativeWidget != null) {
			var svgs : Array<Element> = nativeWidget.getElementsByTagName("svg");

			if (svgs.length > 0) {
				var svg = svgs[0];
				var elementId = untyped svg.parentNode.getAttribute('id');
				var clipFilter : Element = Browser.document.getElementById(elementId + "filter");

				if (clipFilter != null && clipFilter.parentNode != null) {
					clipFilter.parentNode.removeChild(clipFilter);
				}

				var defs = svg.firstElementChild != null && svg.firstElementChild.tagName.toLowerCase() == 'defs' ? svg.firstElementChild :
					Browser.document.createElementNS("http://www.w3.org/2000/svg", 'defs');
				clipFilter = defs.firstElementChild != null && defs.firstElementChild.tagName.toLowerCase() == 'mask' ? defs.firstElementChild :
					Browser.document.createElementNS("http://www.w3.org/2000/svg", 'filter');

				for (child in clipFilter.childNodes) {
					if (child.parentNode == clipFilter) {
						clipFilter.removeChild(child);
					}
				}

				var feColorMatrix = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'feColorMatrix');
				feColorMatrix.setAttribute("in", "SourceAlpha");
				feColorMatrix.setAttribute("result", "matrixOut");
				feColorMatrix.setAttribute("type", "matrix");
				feColorMatrix.setAttribute("values", '${color[0]} ${color[0]} ${color[0]} ${color[0]} 0
													${color[1]} ${color[1]} ${color[1]} ${color[1]} 0
													${color[2]} ${color[2]} ${color[2]} ${color[2]} 0
													0 0 0 ${filter.alpha} 0');

				var feOffset = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'feOffset');
				feOffset.setAttribute("result", "offOut");
				feOffset.setAttribute("in", "matrixOut");
				feOffset.setAttribute("dx", '${Math.cos(filter.angle) * filter.distance}');
				feOffset.setAttribute("dy", '${Math.sin(filter.angle) * filter.distance}');

				var feGaussianBlur = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'feGaussianBlur');
				if (!Platform.isSafari) {
					feGaussianBlur.setAttribute("result", "blurOut");
				}
				feGaussianBlur.setAttribute("in", "offOut");
				feGaussianBlur.setAttribute("stdDeviation", '${filter.blur}');

				clipFilter.setAttribute('id', elementId + "filter");
				clipFilter.setAttribute('x', '${untyped -clip.filterPadding}');
				clipFilter.setAttribute('y', '${untyped -clip.filterPadding}');
				clipFilter.setAttribute('width', '${untyped getWidgetWidth(clip) + clip.filterPadding}');
				clipFilter.setAttribute('height', '${untyped getWidgetHeight(clip) + clip.filterPadding}');

				clipFilter.appendChild(feColorMatrix);
				clipFilter.appendChild(feOffset);
				clipFilter.appendChild(feGaussianBlur);

				if (!Platform.isSafari) {
					var feBlend = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'feBlend');
					feBlend.setAttribute("in2", "blurOut");
					feBlend.setAttribute("in", "SourceGraphic");
					feBlend.setAttribute("mode", "normal");


					clipFilter.appendChild(feBlend);
				}

				defs.insertBefore(clipFilter, defs.firstChild);
				svg.insertBefore(defs, svg.firstChild);

				var blendGroup = Browser.document.getElementById(elementId + "blend");
				if (Platform.isSafari) {
					if (blendGroup == null) {
						blendGroup = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'g');
						blendGroup.setAttribute('id', elementId + "blend");
						svg.appendChild(blendGroup);
					}

					for (child in blendGroup.childNodes) {
						if (child.parentNode == blendGroup) {
							blendGroup.removeChild(child);
						}
					}
				}

				for (child in svg.childNodes) {
					if (untyped child.tagName.toLowerCase() != "defs" && child.getAttribute('id') != elementId + "blend") {
						if (Platform.isSafari) {
							untyped child.removeAttribute("filter");
							blendGroup.appendChild(child.cloneNode());
						}

						untyped child.setAttribute("filter", 'url(#' + elementId + "filter)");

						parent.once("clearfilter", function() { if (child != null) untyped child.removeAttribute("filter"); });
					}
				}
			} else {
				nativeWidget.style.boxShadow = '
					${Math.cos(filter.angle) * filter.distance}px
					${Math.sin(filter.angle) * filter.distance}px
					${filter.blur}px
					rgba(${color[0] * 255}, ${color[1] * 255}, ${color[2] * 255}, ${filter.alpha})
				';

				parent.once("clearfilter", function() { if (nativeWidget != null) nativeWidget.style.boxShadow = null; });
			}
		}
	}

	public static function removeNativeMask(clip : DisplayObject) : Void {
		var nativeWidget = untyped clip.nativeWidget;

		if ((nativeWidget.style.overflow != null && nativeWidget.style.overflow != '') ||
			(nativeWidget.style.clipPath != null && nativeWidget.style.clipPath != '')) {
			nativeWidget.style.overflow = null;
			untyped nativeWidget.style.webkitClipPath = null;
			nativeWidget.clipPath = null;
			nativeWidget.onscroll = null;
			nativeWidget.style.width = null;
			nativeWidget.style.height = null;
			nativeWidget.style.borderRadius = null;
		}
	}

	public static function scrollNativeWidget(clip : DisplayObject, x : Float, y : Float) : Void {
		var nativeWidget : Dynamic = untyped clip.nativeWidget;

		if (nativeWidget.firstChild != null) {
			if (untyped x < 0 || clip.scrollRect == null || x > getContentWidth(clip) - clip.scrollRect.width || RenderSupport.printMode) {
				nativeWidget.firstChild.style.left = '${-round(x)}px';

				x = 0;
			} else {
				nativeWidget.firstChild.style.left = null;
			}

			if (untyped y < 0 || clip.scrollRect == null || y > getContentHeight(clip) - clip.scrollRect.height || RenderSupport.printMode) {
				nativeWidget.firstChild.style.top = '${-round(y)}px';

				y = 0;
			} else {
				nativeWidget.firstChild.style.top = null;
			}
		}

		if (untyped clip.scrollRect != null) {
			var currentScrollLeft = round(nativeWidget.scrollLeft);
			var currentScrollTop = round(nativeWidget.scrollTop);

			var updateScrollRectFn = function() {
				if (untyped clip.scrollRect != null && clip.parent != null) {
					untyped clip.x = clip.x + clip.scrollRect.x - currentScrollLeft;
					untyped clip.y = clip.y + clip.scrollRect.y - currentScrollTop;

					untyped clip.scrollRect.x = currentScrollLeft;
					untyped clip.scrollRect.y = currentScrollTop;

					invalidateTransform(untyped clip.scrollRect, "scrollNativeWidget");

					untyped clip.scrollRectListener(currentScrollLeft, currentScrollTop);
				}
			}

			var scrollFn =
				if (untyped clip.scrollRectListener != null)
					function() {
						if (untyped clip.scrollRect != null && clip.parent != null) {
							if (nativeWidget.scrollLeft != untyped x != 0 ? clip.scrollRect.x : x) {
								nativeWidget.scrollLeft = untyped x != 0 ? clip.scrollRect.x : x;
							}

							if (nativeWidget.scrollTop != untyped y != 0 ? clip.scrollRect.y : y) {
								nativeWidget.scrollTop = untyped y != 0 ? clip.scrollRect.y : y;
							}
						}
					}
				else
					function() {
						if (untyped clip.scrollRect != null && clip.parent != null) {
							if (nativeWidget.scrollLeft != x) {
								nativeWidget.scrollLeft = x;
							}

							if (nativeWidget.scrollTop != y) {
								nativeWidget.scrollTop = y;
							}
						}
					}

			var onScrollFn =
				if (untyped clip.scrollRectListener != null)
					function() {
						if (untyped clip.scrollRect != null && clip.parent != null) {
							var nativeWidgetScrollLeft = round(nativeWidget.scrollLeft);
							var nativeWidgetScrollTop = round(nativeWidget.scrollTop);

							if (nativeWidgetScrollLeft == currentScrollLeft && nativeWidgetScrollTop == currentScrollTop) {
								return;
							} else {
								currentScrollLeft = nativeWidgetScrollLeft;
								currentScrollTop = nativeWidgetScrollTop;
							}

							RenderSupport.off("drawframe", updateScrollRectFn);

							if (RenderSupport.Animating) {
								RenderSupport.once("drawframe", updateScrollRectFn);
							} else {
								updateScrollRectFn();
							}
						}
					}
				else
					scrollFn;

			nativeWidget.onscroll = onScrollFn;
			scrollFn();
			untyped clip.scrollFn = scrollFn;
		}
	}

	public static function updateNativeWidgetMask(clip : DisplayObject, ?attachScrollFn : Bool = false) {
		var nativeWidget = untyped clip.nativeWidget;

		var mask : FlowGraphics = clip.mask;
		var scrollRect = untyped clip.scrollRect;
		var viewBounds = null;//untyped clip.viewBounds;
		var alphaMask = untyped clip.alphaMask;

		if (alphaMask != null) {
			untyped nativeWidget.style.webkitClipPath = null;
			untyped nativeWidget.style.clipPath = null;
			untyped nativeWidget.style.clip = null;
			nativeWidget.style.borderRadius = null;

			var svgs : Array<Element> = nativeWidget.getElementsByTagName("svg");

			for (svg in svgs) {
				var elementId = untyped svg.parentNode.getAttribute('id');
				var clipMask : Element = untyped svg.getElementById(elementId + "mask");

				if (clipMask != null && clipMask.parentNode != null) {
					clipMask.parentNode.removeChild(clipMask);
				}

				var defs = svg.firstElementChild != null && svg.firstElementChild.tagName.toLowerCase() == 'defs' ? svg.firstElementChild :
					Browser.document.createElementNS("http://www.w3.org/2000/svg", 'defs');
				clipMask = defs.firstElementChild != null && defs.firstElementChild.tagName.toLowerCase() == 'mask' ? defs.firstElementChild :
					Browser.document.createElementNS("http://www.w3.org/2000/svg", 'mask');

				for (child in clipMask.childNodes) {
					clipMask.removeChild(untyped child);
				}

				var image = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'image');
				image.setAttribute('href', alphaMask.url);
				var transform = prependInvertedMatrix(untyped clip.alphaMask.worldTransform, clip.worldTransform);
				image.setAttribute('transform', 'matrix(${transform.a} ${transform.b} ${transform.c} ${transform.d} ${transform.tx} ${transform.ty})');
				clipMask.setAttribute('id', elementId + "mask");
				clipMask.setAttribute('mask-type', 'alpha');

				clipMask.appendChild(image);
				defs.insertBefore(clipMask, defs.firstChild);
				svg.insertBefore(defs, svg.firstChild);

				for (child in svg.childNodes) {
					if (untyped child.tagName != null && child.tagName.toLowerCase() != "defs") {
						untyped child.setAttribute("mask", 'url(#' + elementId + "mask)");
					}
				}
			}
		} else if (viewBounds != null) {
			untyped nativeWidget.style.webkitClipPath = null;
			untyped nativeWidget.style.clipPath = null;
			nativeWidget.style.overflow = null;
			nativeWidget.style.clip = 'rect(
				${viewBounds.minY}px,
				${viewBounds.maxX}px,
				${viewBounds.maxY}px,
				${viewBounds.minX}px
			)';
		} else if (untyped scrollRect != null && clip.children != null && clip.children.length > 0) {
			untyped nativeWidget.style.webkitClipPath = null;
			untyped nativeWidget.style.clipPath = null;
			untyped nativeWidget.style.clip = null;
			nativeWidget.style.borderRadius = null;
			if (untyped clip.scrollRectListener != null) {
				nativeWidget.classList.add("nativeScroll");
				nativeWidget.style.overflow = untyped clip.isInput ? "auto" : "scroll";
			} else {
				nativeWidget.style.overflow = untyped clip.isInput ? "auto" : "hidden";
			}

			scrollNativeWidget(clip, round(scrollRect.x), round(scrollRect.y));
		} else if (mask != null) {
			var graphicsData = mask.graphicsData;

			if (graphicsData != null) {
				var data = graphicsData[0];

				if (data.shape.type == 0) {
					nativeWidget.style.overflow = null;
					nativeWidget.style.borderRadius = null;

					var svgChildren = getSVGChildren(clip);

					if (untyped mask.parent.localTransformChanged) {
						untyped mask.parent.transform.updateLocalTransform();
					}

					if (Platform.isIE || svgChildren.length == 1) {
						for (svgClip in svgChildren) {
							if (untyped svgClip.nativeWidget == null) {
								continue;
							}

							var svg : Element = untyped svgClip.nativeWidget.firstChild;

							if (untyped svg == null) {
								continue;
							}

							var elementId = untyped svg.parentNode.getAttribute('id');
							var clipMask : Element = untyped svg.getElementById(elementId + "mask");

							if (clipMask != null && clipMask.parentNode != null) {
								clipMask.parentNode.removeChild(clipMask);
							}

							var defs = svg.firstElementChild != null && svg.firstElementChild.tagName.toLowerCase() == 'defs' ? svg.firstElementChild :
								Browser.document.createElementNS("http://www.w3.org/2000/svg", 'defs');
							clipMask = defs.firstElementChild != null && defs.firstElementChild.tagName.toLowerCase() == 'mask' ? defs.firstElementChild :
								Browser.document.createElementNS("http://www.w3.org/2000/svg", 'mask');

							for (child in clipMask.childNodes) {
								clipMask.removeChild(untyped child);
							}

							var path = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'path');
							var d : String = untyped __js__("data.shape.points.map(function(p, i) {
								return i % 2 == 0 ? (i == 0 ? 'M' : 'L') + p + ' ' : '' + p + ' ';
							}).join('')");
							path.setAttribute("d", d);
							path.setAttribute("fill", "white");
							var transform = prependInvertedMatrix(mask.worldTransform, svgClip.worldTransform);
							path.setAttribute('transform', 'matrix(${transform.a} ${transform.b} ${transform.c} ${transform.d} ${transform.tx} ${transform.ty})');
							clipMask.setAttribute('id', elementId + "mask");

							clipMask.appendChild(path);
							defs.insertBefore(clipMask, defs.firstChild);
							svg.insertBefore(defs, svg.firstChild);

							for (child in svg.childNodes) {
								if (untyped child.tagName != null && child.tagName.toLowerCase() != "defs") {
									untyped child.setAttribute("mask", 'url(#' + elementId + "mask)");
								}
							}
						}
					} else {
						var maskTransform = prependInvertedMatrix(clip.worldTransform, mask.worldTransform);
						nativeWidget.style.clipPath = untyped __js__("'polygon(' + data.shape.points.map(function (p, i) {
							return i % 2 == 0 ? '' + p * maskTransform.a + 'px ' : '' + p * maskTransform.d + 'px' + (i != data.shape.points.length - 1 ? ',' : '')
						}).join('') + ')'");
						untyped nativeWidget.style.webkitClipPath = nativeWidget.style.clipPath;
					}
				} else if (data.shape.type == 1) {
					untyped nativeWidget.style.webkitClipPath = null;
					nativeWidget.style.clipPath = null;
					nativeWidget.style.borderRadius = null;
					nativeWidget.style.overflow = "hidden";

					var transform = prependInvertedMatrix(mask.worldTransform, clip.worldTransform);
					var point = applyTransformPoint(new Point(data.shape.x, data.shape.y), transform);

					scrollNativeWidget(clip, round(point.x), round(point.y));
				} else if (data.shape.type == 2) {
					untyped nativeWidget.style.webkitClipPath = null;
					nativeWidget.style.clipPath = null;
					nativeWidget.style.borderRadius = '${round(data.shape.radius)}px';
					nativeWidget.style.overflow = "hidden";

					var transform = prependInvertedMatrix(mask.worldTransform, clip.worldTransform);
					var point = applyTransformPoint(new Point(data.shape.x - data.shape.radius, data.shape.y - data.shape.radius), transform);

					scrollNativeWidget(clip, round(point.x), round(point.y));
				} else if (data.shape.type == 4) {
					untyped nativeWidget.style.webkitClipPath = null;
					nativeWidget.style.clipPath = null;
					nativeWidget.style.borderRadius = '${round(data.shape.radius)}px';
					nativeWidget.style.overflow = "hidden";

					var transform = prependInvertedMatrix(mask.worldTransform, clip.worldTransform);
					var point = applyTransformPoint(new Point(data.shape.x, data.shape.y), transform);

					scrollNativeWidget(clip, round(point.x), round(point.y));
				}  else {
					removeNativeMask(clip);

					trace("updateNativeWidgetMask: Unknown shape type");
					trace(data);
				}
			} else {
				removeNativeMask(clip);
			}
		}
	}

	public static function getSVGChildren(clip : DisplayObject) : Array<DisplayObject> {
		if (untyped clip.isSvg && clip.transform != null && clip.parent != null && clip.parent.transform != null) {
			untyped clip.transform.updateTransform(clip.parent.transform);
		}

		var result : Array<DisplayObject> = untyped clip.isSvg ? [clip] : [];

		for (child in getClipChildren(clip)) {
			result = result.concat(getSVGChildren(child));
		}

		return result;
	}

	public static function updateNativeWidgetInteractive(clip : DisplayObject) : Void {
		var nativeWidget = untyped clip.nativeWidget;

		if (untyped clip.cursor != null) {
			nativeWidget.style.cursor = untyped clip.cursor;
		} else {
			nativeWidget.style.cursor = null;
		}

		if (clip.interactive) {
			if (Platform.isSafari || Platform.isMobile) {
				if (nativeWidget.style.onmouseover == null) {
					nativeWidget.onmouseover = function() { clip.emit("pointerover"); }
					nativeWidget.onmouseout = function() { clip.emit("pointerout"); }
				}
			} else {
				if (nativeWidget.style.onpointerover == null) {
					nativeWidget.onpointerover = function() { clip.emit("pointerover"); }
					nativeWidget.onpointerout = function() { clip.emit("pointerout"); }
				}
			}

			nativeWidget.style.pointerEvents = 'auto';

			if (untyped clip.isFileDrop) {
				nativeWidget.ondragover = function(e) {
					e.dataTransfer.dropEffect = 'copy';
					return false;
				}

				nativeWidget.ondrop = function(e) {
					e.preventDefault();

					var files : FileList = e.dataTransfer.files;
					var fileArray : Array<File> = [];

					if (untyped clip.maxFilesCount < 0) {
						untyped clip.maxFilesCount = files.length;
					}

					for (idx in 0...Math.floor(Math.min(files.length, untyped clip.maxFilesCount))) {
						var file : File = files.item(idx);

						if (untyped !clip.regExp.match(file.type)) {
							untyped clip.maxFilesCount++;
							continue;
						}

						fileArray.push(file);
					}

					untyped clip.onDone(fileArray);
				}

				nativeWidget.oncontextmenu = function(e) {
					if (RenderSupport.PixiView.oncontextmenu != null) {
						return RenderSupport.PixiView.oncontextmenu(e);
					} else {
						return true;
					}
				};
			} else {
				nativeWidget.oncontextmenu = function (e) {
					e.stopPropagation();
					return untyped clip.isInput == true;
				};
			}
		} else {
			nativeWidget.onmouseover = null;
			nativeWidget.onmouseout = null;
			nativeWidget.onpointerover = null;
			nativeWidget.onpointerout = null;
			nativeWidget.style.pointerEvents = null;
			nativeWidget.ondragover = null;
			nativeWidget.ondrop = null;
		}
	}

	public static function getParentNode(clip : DisplayObject) : Dynamic {
		if (isNativeWidget(clip)) {
			return untyped clip.parentClip != null && clip.parentClip.mask != null && clip.nativeWidget.parentNode != null ?
				clip.nativeWidget.parentNode.parentNode :
				clip.nativeWidget.parentNode;
		}

		return null;
	}

	public static function updateNativeWidgetDisplay(clip : DisplayObject) : Void {
		if (untyped clip.updateNativeWidgetDisplay != null) {
			untyped clip.updateNativeWidgetDisplay();
		} else {
			if (untyped clip.visibilityChanged) {
				untyped clip.visibilityChanged = false;
				untyped clip.nativeWidget.style.visibility = clip.loaded ? (Platform.isIE ? "visible" : null) : "hidden";
			} else {
				untyped clip.nativeWidget.style.visibility = clip.renderable || clip.keepNativeWidget ? (Platform.isIE || clip.keepNativeWidget ? "visible" : null) : "hidden";
			}

			if (clip.visible) {
				if (untyped clip.child == null && (!clip.onStage || getParentNode(clip) != clip.parentClip.nativeWidget)) {
					untyped clip.onStage = true;

					if (!Platform.isIE) {
						untyped clip.nativeWidget.style.display = null;
					}

					addNativeWidget(clip);
				}
			} else if (untyped clip.onStage) {
				untyped clip.onStage = false;

				if (!Platform.isIE) {
					untyped clip.nativeWidget.style.display = 'none';
				}

				RenderSupport.once("drawframe", function() {
					if (untyped isNativeWidget(clip) && !clip.onStage && (!clip.visible || clip.parent == null)) {
						removeNativeWidget(clip);
					}
				});
			}
		}
	}

	public static inline function isNativeWidget(clip : DisplayObject) : Bool {
		return untyped clip.isNativeWidget;
	}

	public static function isClipOnStage(clip : DisplayObject) : Bool {
		return untyped clip.onStage && clip.tansform != null;
	}

	public static function addNativeWidget(clip : DisplayObject) : Void {
		if (untyped clip.addNativeWidget != null) {
			untyped clip.addNativeWidget();
		} else if (RenderSupport.RendererType == "html") {
			if (isNativeWidget(clip) && untyped clip.parent != null && clip.visible && (clip.renderable || clip.keepNativeWidgetChildren)) {
				appendNativeWidget(untyped clip.parentClip || findParentClip(clip), clip);
				RenderSupport.once("drawframe", function() { broadcastEvent(clip, "pointerout"); });
			}
		} else {
			clip.once('removed', function() { deleteNativeWidget(clip); });
		}
	}

	public static function removeNativeWidget(clip : DisplayObject) : Void {
		if (untyped clip.removeNativeWidget != null) {
			untyped clip.removeNativeWidget();
		} else {
			if (untyped isNativeWidget(clip)) {
				var nativeWidget : Dynamic = untyped clip.nativeWidget;

				if (untyped nativeWidget.parentNode != null) {
					nativeWidget.parentNode.removeChild(nativeWidget);

					if (untyped clip.parentClip != null) {
						applyScrollFn(untyped clip.parentClip);
						untyped clip.parentClip = null;
					}
				}
			}
		}
	}

	public static function findParentClip(clip : DisplayObject) : DisplayObject {
		if (clip.parent == null) {
			return null;
		} else if (isNativeWidget(clip.parent)) {
			return clip.parent;
		} else {
			return findParentClip(clip.parent);
		}
	}

	public static function findNextNativeWidget(clip : DisplayObject, parent : DisplayObject) : Element {
		if (clip.parent != null) {
			var children = clip.parent.children;

			if (children.indexOf(clip) >= 0) {
				for (child in children.slice(children.indexOf(clip) + 1)) {
					if (untyped child.visible && (!isNativeWidget(child) || (child.onStage && child.parentClip == parent))) {
						var nativeWidget = findNativeWidgetChild(child, parent);

						if (nativeWidget != null) {
							return nativeWidget;
						}
					}
				}
			}

			return RenderSupport.RenderContainers || isNativeWidget(clip.parent) ? null : findNextNativeWidget(clip.parent, parent);
		}

		return null;
	}

	public static function findNativeWidgetChild(clip : DisplayObject, parent : DisplayObject) : Element {
		if (untyped isNativeWidget(clip) && clip.parentClip == parent && getParentNode(clip) == parent.nativeWidget) {
			return untyped clip.nativeWidget;
		} else if (!RenderSupport.RenderContainers && RenderSupport.RendererType == "html") {
			for (child in getClipChildren(clip)) {
				if (untyped child.visible && (!isNativeWidget(child) || child.parentClip == parent)) {
					var nativeWidget = findNativeWidgetChild(child, parent);

					if (nativeWidget != null) {
						return nativeWidget;
					}
				}
			}
		}

		return null;
	}

	public static function appendNativeWidget(clip : DisplayObject, child : DisplayObject) { // add possible next nodes
		if (isNativeWidget(clip)) {
			var childWidget : Dynamic = untyped child.nativeWidget;

			if (untyped clip.nativeWidget == Browser.document.body && (childWidget.style.zIndex == null || childWidget.style.zIndex == "")) {
				var localStage : FlowContainer = untyped child.stage;

				if (localStage != null) {
					var zIndex = 1000 * localStage.parent.children.indexOf(localStage) + (childWidget.classList.contains("droparea") ? AccessWidget.zIndexValues.droparea : AccessWidget.zIndexValues.nativeWidget);
					childWidget.style.zIndex = Std.string(zIndex);
				}
			}

			var nextWidget = findNextNativeWidget(child, clip);
			if (untyped clip.mask != null) {
				if (untyped clip.nativeWidget.firstChild == null) {
					var cont = Browser.document.createElement("div");
					cont.className = 'nativeWidget';
					untyped clip.nativeWidget.appendChild(cont);
				}

				untyped clip.nativeWidget.firstChild.insertBefore(childWidget, nextWidget);
			} else {
				untyped clip.nativeWidget.insertBefore(childWidget, nextWidget);
			}

			applyScrollFnChildren(child);
		} else {
			appendNativeWidget(clip.parent, child);
		}
	}

	public static function applyScrollFn(clip : DisplayObject) : Void {
		if (untyped clip.visible && clip.scrollFn != null) {
			untyped clip.scrollFn();
		} else if (clip.parent != null && clip.mask == null) {
			applyScrollFn(clip.parent);
		}
	}

	public static function applyScrollFnChildren(clip : DisplayObject) : Void {
		if (clip.visible) {
			if (untyped clip.scrollFn != null) {
				untyped clip.scrollFn();
			}

			if (untyped clip.isFocused) {
				if (Platform.isIE) {
					untyped clip.nativeWidget.blur();
					RenderSupport.once("drawframe", function() {
						untyped clip.nativeWidget.focus();
					});
				} else {
					untyped clip.nativeWidget.focus();
				}
			}
		}

		for (child in getClipChildren(clip)) {
			applyScrollFnChildren(child);
		}
	}

	public static function deleteNativeWidget(clip : DisplayObject) : Void {
		if (untyped clip.nativeWidget != null) {
			removeNativeWidget(clip);

			untyped __js__("delete clip.nativeWidget");
			untyped clip.nativeWidget = null;
			untyped clip.isNativeWidget = false;
		}

		if (untyped clip.accessWidget != null) {
			AccessWidget.removeAccessWidget(untyped clip.accessWidget);

			untyped __js__("delete clip.accessWidget");
			untyped clip.accessWidget = null;
		}
	}

	public static inline function getWidth(clip : DisplayObject) : Float {
		if (untyped clip.getWidth != null) {
			return untyped clip.getWidth();
		} else {
			return untyped clip.getLocalBounds().width;
		}
	}

	public static inline function getContentWidth(clip : DisplayObject) : Float {
		if (untyped clip.maxLocalBounds != null) {
			return untyped clip.maxLocalBounds.maxX - clip.maxLocalBounds.minX;
		} else {
			return 0.0;
		}
	}

	public static inline function getBoundsWidth(bounds : Bounds) : Float {
		return Math.isFinite(bounds.minX) ? bounds.maxX - bounds.minX : -1;
	}

	public static inline function getWidgetWidth(clip : DisplayObject) : Float {
		var widgetBounds : Bounds = untyped clip.widgetBounds;
		var widgetWidth = widgetBounds != null && Math.isFinite(widgetBounds.minX) ? getBoundsWidth(widgetBounds) : getWidth(clip);

		return widgetWidth;
	}

	public static function getHeight(clip : DisplayObject) : Float {
		if (untyped clip.getHeight != null) {
			return untyped clip.getHeight();
		} else {
			return untyped clip.getLocalBounds().height;
		}
	}

	public static inline function getContentHeight(clip : DisplayObject) : Float {
		if (untyped clip.maxLocalBounds != null) {
			return untyped clip.maxLocalBounds.maxY - clip.maxLocalBounds.minY;
		} else {
			return 0.0;
		}
	}

	public static inline function getBoundsHeight(bounds : Bounds) : Float {
		return Math.isFinite(bounds.minY) ? bounds.maxY - bounds.minY : -1;
	}

	public static inline function getWidgetHeight(clip : DisplayObject) : Float {
		var widgetBounds : Bounds = untyped clip.widgetBounds;
		return (widgetBounds != null && Math.isFinite(widgetBounds.minY)) ? getBoundsHeight(widgetBounds) : getHeight(clip);
	}

	public static function invalidateLocalBounds(clip : DisplayObject, ?invalidateMask : Bool = false) : Void {
		if (untyped clip.transformChanged || clip.localBoundsChanged) {
			untyped clip.localBoundsChanged = false;

			if (untyped clip.graphicsBounds != null) {
				untyped clip.calculateGraphicsBounds();
				applyNewBounds(clip, untyped clip.graphicsBounds);
			} else if (untyped clip.widgetBounds != null) {
				untyped clip.calculateWidgetBounds();
				applyNewBounds(clip, untyped clip.widgetBounds);
			} else {
				untyped clip.maxLocalBounds = new Bounds();

				for (child in getClipChildren(clip)) {
					if (untyped (!child.isMask || invalidateMask) && child.clipVisible && child.localBounds != null) {
						invalidateLocalBounds(child, invalidateMask);
						applyMaxBounds(clip, untyped child.currentBounds);
					}
				}

				if (untyped clip.mask == null) {
					applyNewBounds(clip, untyped clip.maxLocalBounds);
				}
			}

			if (untyped clip.scrollRect != null) {
				invalidateLocalBounds(untyped clip.scrollRect, true);
				applyNewBounds(clip, untyped clip.scrollRect.currentBounds);
			} else if (untyped clip.maskContainer != null) {
				invalidateLocalBounds(untyped clip.maskContainer, true);

				if (untyped clip.localTransformChanged) {
					untyped clip.transform.updateLocalTransform();
				}

				applyNewBounds(clip, applyInvertedTransform(untyped clip.maskContainer.currentBounds, clip.localTransform));
			}

			if (untyped clip.nativeWidgetBoundsChanged || clip.localTransformChanged) {
				if (RenderSupport.RendererType != "html") {
					untyped clip.nativeWidgetBoundsChanged = false;
				}

				if (untyped clip.origin != null) {
					if (RenderSupport.RendererType == "html") {
						initNativeWidget(clip);

						if (untyped clip.nativeWidget != null) {
							untyped clip.nativeWidget.style.transformOrigin = clip.origin.x * 100 + "% " + (clip.origin.y * 100 + "%");

							untyped clip.transform.pivot.x = 0.0;
							untyped clip.transform.pivot.y = 0.0;
						} else {
							untyped clip.transform.pivot.x = getWidth(clip) * clip.origin.x;
							untyped clip.transform.pivot.y = getHeight(clip) * clip.origin.y;
						}
					} else {
						untyped clip.transform.pivot.x = getWidth(clip) * clip.origin.x;
						untyped clip.transform.pivot.y = getHeight(clip) * clip.origin.y;
					}
				}

				if (untyped clip.updateGraphics != null) {
					untyped clip.updateGraphics.drawRect(clip.localBounds.minX, clip.localBounds.minY, clip.localBounds.maxX, clip.localBounds.maxY);
				}

				untyped clip.currentBounds = applyLocalBoundsTransform(clip);
			}
		}
	}

	public static function applyMaxBounds(clip : DisplayObject, newBounds : Bounds) : Void {
		if (untyped clip.maxLocalBounds == null || newBounds == null || !Math.isFinite(newBounds.minX) || !Math.isFinite(newBounds.minY)) {
			return;
		}

		untyped clip.maxLocalBounds.minX = Math.min(untyped clip.maxLocalBounds.minX, newBounds.minX);
		untyped clip.maxLocalBounds.minY = Math.min(untyped clip.maxLocalBounds.minY, newBounds.minY);
		untyped clip.maxLocalBounds.maxX = Math.max(untyped clip.maxLocalBounds.maxX, newBounds.maxX);
		untyped clip.maxLocalBounds.maxY = Math.max(untyped clip.maxLocalBounds.maxY, newBounds.maxY);
	}

	public static function applyNewBounds(clip : DisplayObject, newBounds : Bounds) : Void {
		if (newBounds == null || !Math.isFinite(newBounds.minX) || !Math.isFinite(newBounds.minY)) {
			return;
		}

		if (!isEqualBounds(untyped clip.localBounds, newBounds)) {
			if (isNativeWidget(clip)) {
				if (RenderSupport.RendererType == "html") {
					invalidateTransform(clip);
				} else {
					invalidateParentTransform(clip);
				}
			}

			untyped clip.nativeWidgetBoundsChanged = true;
			if (RenderSupport.RendererType != "html") {
				untyped clip.rvlast = null;
			}

			untyped clip.localBounds.minX = newBounds.minX;
			untyped clip.localBounds.minY = newBounds.minY;
			untyped clip.localBounds.maxX = newBounds.maxX;
			untyped clip.localBounds.maxY = newBounds.maxY;
		}
	}

	public static function prependInvertedMatrix(a : Matrix, b : Matrix, ?c : Matrix) : Matrix {
		if (c == null) {
			c = new Matrix();
		}

		if (b.a != 1.0 || b.b != 0.0 || b.c != 0.0 || b.d != 1.0) {
			var id = 1.0 / (b.a * b.d - b.c * b.b);

			c.a = (a.a * b.d - a.b * b.c) * id;
			c.b = (a.b * b.a - a.a * b.b) * id;
			c.c = (a.c * b.d - a.d * b.c) * id;
			c.d = (a.d * b.a - a.c * b.b) * id;

			c.tx = (a.tx * b.d - a.ty * b.c + b.ty * b.c - b.tx * b.d) * id;
			c.ty = (a.ty * b.a - a.tx * b.b + b.tx * b.b - b.ty * b.a) * id;
		} else {
			c.a = a.a;
			c.b = a.b;
			c.c = a.c;
			c.d = a.d;

			c.tx = a.tx - b.tx;
			c.ty = a.ty - b.ty;
		}

		return c;
	}

	public static function applyLocalBoundsTransform(clip : DisplayObject, ?container : Bounds) : Bounds {
		if (container == null) {
			container = new Bounds();
		}

		if (untyped clip.localTransformChanged) {
			untyped clip.transform.updateLocalTransform();
		}

		var transform = clip.localTransform;

		if (untyped clip.children != null && clip.children.length == 1 && clip.children[0].graphicsData != null && clip.children[0].graphicsData.length > 0 && clip.children[0].graphicsData[0].shape.points != null) {
			var tempPoints = untyped clip.children[0].graphicsData[0].shape.points;

			untyped __js__("clip.children[0].graphicsData[0].shape.points = clip.children[0].graphicsData[0].shape.points.map(function(point, i) {
				if (i % 2 == 0) {
					return point * transform.a + clip.children[0].graphicsData[0].shape.points[i + 1] * transform.c + transform.tx;
				} else {
					return clip.children[0].graphicsData[0].shape.points[i - 1] * transform.b + point * transform.d + transform.ty;
				}
			})");
			untyped clip.children[0].calculateGraphicsBounds();

			var bounds = untyped clip.children[0].graphicsBounds;

			container.minX = bounds.minX;
			container.minY = bounds.minY;
			container.maxX = bounds.maxX;
			container.maxY = bounds.maxY;

			untyped clip.children[0].graphicsData[0].shape.points = tempPoints;
			untyped clip.children[0].calculateGraphicsBounds();
		} else {
			var bounds = untyped clip.localBounds;
			applyBoundsTransform(bounds, transform, container);
		}

		return container;
	}

	public static function applyBoundsTransform(bounds : Bounds, transform : Matrix, ?container : Bounds) : Bounds {
		if (container == null) {
			container = new Bounds();
		}

		if (transform.a != 1 || transform.b != 0 || transform.c != 0 || transform.d != 1) {
			var x = [
				bounds.minX * transform.a + bounds.minY * transform.c + transform.tx,
				bounds.minX * transform.a + bounds.maxY * transform.c + transform.tx,
				bounds.maxX * transform.a + bounds.maxY * transform.c + transform.tx,
				bounds.maxX * transform.a + bounds.minY * transform.c + transform.tx
			];

			var y = [
				bounds.minX * transform.b + bounds.minY * transform.d + transform.ty,
				bounds.minX * transform.b + bounds.maxY * transform.d + transform.ty,
				bounds.maxX * transform.b + bounds.maxY * transform.d + transform.ty,
				bounds.maxX * transform.b + bounds.minY * transform.d + transform.ty
			];


			container.minX = ceil(Math.min(Math.min(x[0], x[1]), Math.min(x[2], x[3])));
			container.minY = ceil(Math.min(Math.min(y[0], y[1]), Math.min(y[2], y[3])));
			container.maxX = ceil(Math.max(Math.max(x[0], x[1]), Math.max(x[2], x[3])));
			container.maxY = ceil(Math.max(Math.max(y[0], y[1]), Math.max(y[2], y[3])));
		} else {
			var x = [
				bounds.minX + transform.tx,
				bounds.maxX + transform.tx
			];

			var y = [
				bounds.minY + transform.ty,
				bounds.maxY + transform.ty
			];

			container.minX = ceil(Math.min(x[0], x[1]));
			container.minY = ceil(Math.min(y[0], y[1]));
			container.maxX = ceil(Math.max(x[0], x[1]));
			container.maxY = ceil(Math.max(y[0], y[1]));
		}

		return container;
	}

	public static function applyInvertedTransform(bounds : Bounds, transform : Matrix, ?container : Bounds) : Bounds {
		if (container == null) {
			container = new Bounds();
		}

		if (transform.a != 1 || transform.b != 0 || transform.c != 0 || transform.d != 1) {
			var id = 1.0 / (transform.a * transform.d - transform.c * transform.b);

			var x = [
				(transform.d * id * bounds.minX) + (-transform.c * id * bounds.minY) + (((transform.ty * transform.c) - (transform.tx * transform.d)) * id),
				(transform.d * id * bounds.minX) + (-transform.c * id * bounds.maxY) + (((transform.ty * transform.c) - (transform.tx * transform.d)) * id),
				(transform.d * id * bounds.maxX) + (-transform.c * id * bounds.maxY) + (((transform.ty * transform.c) - (transform.tx * transform.d)) * id),
				(transform.d * id * bounds.maxX) + (-transform.c * id * bounds.minY) + (((transform.ty * transform.c) - (transform.tx * transform.d)) * id)
			];

			var y = [
				(transform.a * id * bounds.minY) + (-transform.b * id * bounds.minX) + (((-transform.ty * transform.a) + (transform.tx * transform.b)) * id),
				(transform.a * id * bounds.minY) + (-transform.b * id * bounds.maxX) + (((-transform.ty * transform.a) + (transform.tx * transform.b)) * id),
				(transform.a * id * bounds.maxY) + (-transform.b * id * bounds.maxX) + (((-transform.ty * transform.a) + (transform.tx * transform.b)) * id),
				(transform.a * id * bounds.maxY) + (-transform.b * id * bounds.minX) + (((-transform.ty * transform.a) + (transform.tx * transform.b)) * id)
			];


			container.minX = Math.min(Math.min(x[0], x[1]), Math.min(x[2], x[3]));
			container.minY = Math.min(Math.min(y[0], y[1]), Math.min(y[2], y[3]));
			container.maxX = Math.max(Math.max(x[0], x[1]), Math.max(x[2], x[3]));
			container.maxY = Math.max(Math.max(y[0], y[1]), Math.max(y[2], y[3]));
		} else {
			var x = [
				bounds.minX - transform.tx,
				bounds.maxX - transform.tx
			];

			var y = [
				bounds.minY - transform.ty,
				bounds.maxY - transform.ty
			];

			container.minX = Math.min(x[0], x[1]);
			container.minY = Math.min(y[0], y[1]);
			container.maxX = Math.max(x[0], x[1]);
			container.maxY = Math.max(y[0], y[1]);
		}

		return container;
	}

	public static function applyTransformPoint(point : Point, transform : Matrix, ?container : Point) : Point {
		if (container == null) {
			container = new Point();
		}

		if (transform.a != 1 || transform.b != 0 || transform.c != 0 || transform.d != 1) {
			container.x = point.x * transform.a + point.y * transform.c + transform.tx;
			container.y =  point.x * transform.b + point.y * transform.d + transform.ty;
		} else {
			container.x = point.x + transform.tx;
			container.y = point.y + transform.ty;
		}

		return container;
	}

	public static function applyInvertedTransformPoint(point : Point, transform : Matrix, ?container : Point) : Point {
		if (container == null) {
			container = new Point();
		}

		if (transform.a != 1 || transform.b != 0 || transform.c != 0 || transform.d != 1) {
			container.x = (transform.a != 0 ? point.x / transform.a : 0) + (transform.c != 0 ? point.y / transform.c : 0) - transform.tx;
			container.y = (transform.b != 0 ? point.x / transform.b : 0) + (transform.d != 0 ? point.y / transform.d : 0) - transform.ty;
		} else {
			container.x = point.x - transform.tx;
			container.y = point.y - transform.ty;
		}

		return container;
	}

	public static function isEqualBounds(bounds1 : Bounds, bounds2 : Bounds) : Bool {
		return bounds1 != null && bounds2 != null && bounds1.minX == bounds2.minX && bounds1.minY == bounds2.minY && bounds1.maxX == bounds2.maxX && bounds1.maxY == bounds2.maxY;
	}

	public static function initNativeWidget(clip : DisplayObject, ?tagName : String) : Void {
		if (isCanvas(clip)) {
			return;
		}

		if (untyped !clip.isNativeWidget || (tagName != null && clip.nativeWidget.tagName.toLowerCase() != tagName)) {
			untyped clip.isNativeWidget = true;
			untyped clip.createNativeWidget(tagName);

			invalidateTransform(clip, 'initNativeWidget', untyped clip.parent != null);
		}
	}

	public static function invalidateRenderable(clip : DisplayObject, viewBounds : Bounds, ?hasAnimation : Bool = false) : Void {
		if (!InvalidateRenderable) {
			return;
		}

		var localBounds = untyped clip.localBounds;

		if (localBounds == null || untyped clip.isMask) {
			return;
		}

		if (!Math.isFinite(localBounds.minX) || !Math.isFinite(localBounds.minY) || localBounds.isEmpty()) {
			return;
		}

		if (untyped clip.localTransformChanged) {
			untyped clip.transform.updateLocalTransform();
		}

		viewBounds = applyInvertedTransform(viewBounds, untyped clip.localTransform);

		if (untyped clip.scrollRect != null) {
			viewBounds.minX = Math.max(viewBounds.minX, localBounds.minX);
			viewBounds.minY = Math.max(viewBounds.minY, localBounds.minY);
			viewBounds.maxX = Math.min(viewBounds.maxX, localBounds.maxX);
			viewBounds.maxY = Math.min(viewBounds.maxY, localBounds.maxY);
		}

		untyped clip.viewBounds = viewBounds;

		if ((RenderSupport.RendererType != "html" && untyped clip.styleChanged != null) || untyped HaxeRuntime.instanceof(clip, DropAreaClip)) {
			untyped clip.invalidateStyle();
			invalidateTransform(clip, 'invalidateRenderable');
		}

		if (!Math.isFinite(viewBounds.minX) || !Math.isFinite(viewBounds.minY) || viewBounds.isEmpty()) {
			setClipRenderable(clip, false);
		} else {
			setClipRenderable(clip, viewBounds.maxX >= localBounds.minX && viewBounds.minX <= localBounds.maxX && viewBounds.maxY >= localBounds.minY && viewBounds.minY <= localBounds.maxY);
		}

		if (untyped !clip.transformChanged || (!clip.visible && !clip.parent.visible)) {
			return;
		}

		for (child in getClipChildren(clip)) {
			if (untyped !child.isMask) {
				invalidateRenderable(child, viewBounds, untyped hasAnimation || clip.hasAnimation);
			}
		}
	}

	public static inline function getClipChildren(clip : DisplayObject) : Array<DisplayObject> {
		return untyped clip.children || [];
	}


	public static inline function addElementNS(parent : Element, tagName : String) : Element {
		var el = parent.getElementsByTagName(tagName);

		if (el.length > 0) {
			return el[0];
		} else {
			var element = Browser.document.createElementNS("http://www.w3.org/2000/svg", tagName);
			parent.appendChild(element);
			return element;
		}
	}

	public static inline function renderToCanvas(clip : DisplayObject, canvas : CanvasElement, ?context : Dynamic, ?transform : Matrix) : Void {
		if (!clip.visible || clip.worldAlpha <= 0 || !clip.renderable)
		{
			return;
		}

		var tempView : Dynamic = null;
		var tempRootContext : Dynamic = null;
		var tempContext : Dynamic = null;
		var tempRendererType : Dynamic = null;
		var tempTransparent : Dynamic = null;
		var tempRoundPixels : Dynamic = null;
		var tempMaskWorldTransform : Dynamic = null;
		var tempWorldTransform : Dynamic = null;
		var tempWorldAlpha : Dynamic =  null;

		var children = getClipChildren(clip);

		if (RenderSupport.PixiRenderer.view != canvas) {
			tempView = RenderSupport.PixiRenderer.view;
			tempRootContext = RenderSupport.PixiRenderer.rootContext;
			tempContext = RenderSupport.PixiRenderer.context;
			tempRendererType = RenderSupport.RendererType;
			tempTransparent = RenderSupport.PixiRenderer.transparent;
			tempRoundPixels = RenderSupport.PixiRenderer.roundPixels;

			RenderSupport.PixiRenderer.view = canvas;
			RenderSupport.PixiRenderer.rootContext = context != null ? context : canvas.getContext('2d', { alpha : true });
			RenderSupport.PixiRenderer.context = context != null ? context : canvas.getContext('2d', { alpha : true });
			RenderSupport.PixiRenderer.transparent = true;
			// RenderSupport.PixiRenderer.roundPixels = true;

			RenderSupport.PixiRenderer.context.setTransform(1, 0, 0, 1, 0, 0);
			RenderSupport.PixiRenderer.context.globalAlpha = 1;
			RenderSupport.PixiRenderer.context.clearRect(0, 0,
				untyped (clip.localBounds.maxX + Math.max(-clip.localBounds.minX, 0.0)) * RenderSupport.PixiRenderer.resolution,
				untyped (clip.localBounds.maxY + Math.max(-clip.localBounds.minY, 0.0)) * RenderSupport.PixiRenderer.resolution
			);

			RenderSupport.RendererType = 'canvas';

			if (transform != null) {
				untyped tempWorldAlpha = clip.worldAlpha;
				untyped clip.worldAlpha = clip.alpha;
			}
		}

		if (clip.mask != null)
		{
			if (transform != null) {
				untyped tempMaskWorldTransform = clip.mask.transform.worldTransform;
				untyped clip.mask.transform.worldTransform = clip.mask.transform.worldTransform.clone().prepend(transform);
			}

			RenderSupport.PixiRenderer.maskManager.pushMask(clip.mask);
		}

		if (children.length > 0) {
			for (child in children) {
				renderToCanvas(child, canvas, context, transform);
			}
		} else {
			if (transform != null) {
				untyped tempWorldTransform = clip.transform.worldTransform;
				untyped tempWorldAlpha = clip.worldAlpha;
				untyped clip.transform.worldTransform = clip.transform.worldTransform.clone().prepend(transform);
			}

			untyped clip.renderCanvas(RenderSupport.PixiRenderer);

			if (transform != null) {
				untyped clip.transform.worldTransform = tempWorldTransform;
				untyped clip.worldAlpha = tempWorldAlpha;
			}
		}

		if (clip.mask != null)
		{
			RenderSupport.PixiRenderer.maskManager.popMask(RenderSupport.PixiRenderer);

			if (transform != null) {
				untyped clip.mask.transform.worldTransform = tempMaskWorldTransform;
			}
		}

		if (tempView != null) {
			RenderSupport.PixiRenderer.view = tempView;
			RenderSupport.PixiRenderer.rootContext = tempRootContext;
			RenderSupport.PixiRenderer.context = tempContext;
			RenderSupport.PixiRenderer.transparent = tempTransparent;
			RenderSupport.PixiRenderer.roundPixels = tempRoundPixels;

			RenderSupport.RendererType = tempRendererType;
		}
	}

	public static function addFileDropListener(clip : DisplayObject, maxFilesCount : Int, mimeTypeRegExpFilter : String, onDone : Array<Dynamic> -> Void) : Void -> Void {
		untyped clip.isFileDrop = true;
		untyped clip.isInteractive = true;

		untyped clip.maxFilesCount = maxFilesCount;
		untyped clip.regExp = new EReg(mimeTypeRegExpFilter, "g");
		untyped clip.onDone = onDone;

		invalidateInteractive(clip);
		invalidateTransform(clip, "addFileDropListener");

		return function() {
			if (untyped !clip.destroyed) {
				untyped clip.isFileDrop = false;
				untyped clip.isInteractive = false;

				untyped clip.maxFilesCount = null;
				untyped clip.regExp = null;
				untyped clip.onDone = null;

				invalidateInteractive(clip);
				invalidateTransform(clip, "addFileDropListener");
			}
		}
	}

	public static function isParentOf(parent : DisplayObject, child : DisplayObject) : Bool {
		if (child.parent == parent) {
			return true;
		} else {
			return child.parent != null && isParentOf(parent, child.parent);
		}
	}
}