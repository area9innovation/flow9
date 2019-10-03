import js.Browser;

import pixi.core.display.DisplayObject;
import pixi.core.display.Container;
import pixi.core.display.Bounds;
import pixi.core.display.TransformBase;
import pixi.core.math.Matrix;
import pixi.core.display.Transform;
import pixi.core.math.Point;

class DisplayObjectHelper {
	public static var Redraw : Bool = Util.getParameter("redraw") == "1";
	public static var DebugUpdate : Bool = Util.getParameter("debugupdate") == "1";
	public static var BoxShadow : Bool = ((Platform.isChrome || Platform.isFirefox) && !Platform.isMobile) ?
		Util.getParameter("boxshadow") != "0" : Util.getParameter("boxshadow") == "1";
	public static var InvalidateRenderable : Bool = Util.getParameter("renderable") != "0" ;

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
		return RenderSupportJSPixi.RoundPixels ? Math.round(n) : n;
	}

	public static inline function floor(n : Float) : Float {
		return RenderSupportJSPixi.RoundPixels ? Math.floor(n) : n;
	}

	public static inline function ceil(n : Float) : Float {
		return RenderSupportJSPixi.RoundPixels ? Math.ceil(n) : n;
	}

	public static function invalidateStage(clip : DisplayObject) : Void {
		if (InvalidateStage && (clip.visible || (clip.parent != null && clip.parent.visible)) && untyped clip.stage != null) {
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
					untyped clip.stage.invalidateStage();
					untyped clip.stage.invalidateTransform('invalidateStage');
				});
			}

			untyped clip.stage.invalidateStage();
		}
	}

	public static function updateStage(clip : DisplayObject, ?clear : Bool = false) : Void {
		if (!clear && clip.parent != null) {
			if (untyped clip.parent.stage != null && untyped clip.parent.stage != untyped clip.stage) {
				untyped clip.stage = untyped clip.parent.stage;

				var children : Array<DisplayObject> = untyped clip.children;

				if (children != null) {
					for (c in children) {
						updateStage(c);
					}
				}
			} else if (clip.parent == RenderSupportJSPixi.PixiStage) {
				untyped clip.stage = clip;
				if (RenderSupportJSPixi.RendererType != "html") {
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

	public static function invalidateTransform(clip : DisplayObject, ?from : String) : Void {
		if (InvalidateStage) {
			invalidateParentTransform(clip);
		}

		invalidateWorldTransform(clip, true, DebugUpdate ? from + ' ->\ninvalidateTransform' : null);
	}

	public static function invalidateWorldTransform(clip : DisplayObject, ?localTransformChanged : Bool, ?from : String, ?parentClip : DisplayObject) : Void {
		if (untyped clip.parent != null && (!clip.worldTransformChanged || (localTransformChanged && !clip.localTransformChanged))) {
			untyped clip.worldTransformChanged = true;
			untyped clip.transformChanged = true;

			if (untyped !parentClip) {
				parentClip = findParentClip(clip);
			}

			untyped clip.parentClip = parentClip;

			if (isNativeWidget(clip)) {
				parentClip = clip;
			}

			if (localTransformChanged) {
				untyped clip.localTransformChanged = true;

				if (DebugUpdate) {
					if (untyped clip.from) {
						untyped clip.from = untyped clip.from + '\n---------\n' + from;
					} else {
						untyped clip.from = from;
					}
				}
			}

			if (RenderSupportJSPixi.RendererType != "html") {
				untyped clip.rvlast = null;
			}

			if (untyped clip.child != null && clip.localTransformChanged) {
				invalidateTransform(untyped clip.child, DebugUpdate ? from + ' ->\ninvalidateWorldTransform -> mask child' : null);
			}

			for (child in getClipChildren(clip)) {
				if (child.visible) {
					invalidateWorldTransform(child, localTransformChanged && !isNativeWidget(clip), DebugUpdate ? from + ' ->\ninvalidateWorldTransform -> child' : null, parentClip);
				}
			}
		}
	}

	public static function invalidateParentTransform(clip : DisplayObject) : Void {
		if (clip.parent != null) {
			untyped clip.transformChanged = true;

			if (RenderSupportJSPixi.RendererType != "html") {
				untyped clip.rvlast = null;
			}

			if (untyped clip.isCanvas) {
				untyped clip.worldTransformChanged = true;
				untyped clip.localTransformChanged = true;
			}

			if (untyped clip.parent.parent != null && !clip.parent.transformChanged) {
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
		var visible = clip.parent != null && getClipRenderable(clip.parent) && (untyped clip.isMask || (clipVisible && clip.renderable));

		if (untyped !parentClip) {
			parentClip = findParentClip(clip);
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

			if (RenderSupportJSPixi.RendererType != "html" && updateAccessWidget) {
				untyped clip.accessWidget.updateDisplay();
			}

			invalidateTransform(clip, 'invalidateVisible');
		}
	}

	public static function invalidateInteractive(clip : DisplayObject, ?interactiveChildren : Bool = false) : Void {
		clip.interactive = untyped clip.listeners("pointerout").length > 0 || clip.listeners("pointerover").length > 0 || clip.cursor != null || clip.isInteractive;
		clip.interactiveChildren = clip.interactive || interactiveChildren;

		if (clip.interactive) {
			if (RenderSupportJSPixi.RendererType == "html") {
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
			invalidateInteractive(clip.parent, clip.interactiveChildren);
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

	public static function invalidate(clip : DisplayObject) : Void {
		updateStage(clip);

		if (clip.parent != null) {
			invalidateVisible(clip);
			invalidateInteractive(clip, clip.parent.interactiveChildren);
			invalidateTransform(clip, 'invalidate');

			if (untyped clip.parent.hasMask) {
				updateHasMask(clip);
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

	public static inline function setClipX(clip : DisplayObject, x : Float) : Void {
		if (untyped clip.scrollRect != null) {
			x = x - untyped clip.scrollRect.x;
		}

		if (clip.x != x) {
			var from = DebugUpdate ? 'setClipX ' + clip.x + ' : ' + x : null;

			clip.x = x;
			invalidateTransform(clip, from);
		}
	}

	public static inline function setClipY(clip : DisplayObject, y : Float) : Void {
		if (untyped clip.scrollRect != null) {
			y = y - untyped clip.scrollRect.y;
		}

		if (clip.y != y) {
			var from = DebugUpdate ? 'setClipY ' + clip.y + ' : ' + y : null;

			clip.y = y;
			invalidateTransform(clip, from);
		}
	}

	public static inline function setClipScaleX(clip : DisplayObject, scale : Float) : Void {
		if (clip.scale.x != scale) {
			var from = DebugUpdate ? 'setClipScaleX ' + clip.scale.x + ' : ' + scale : null;

			clip.scale.x = scale;
			invalidateTransform(clip, from);
		}
	}

	public static inline function setClipScaleY(clip : DisplayObject, scale : Float) : Void {
		if (clip.scale.y != scale) {
			var from = DebugUpdate ? 'setClipScaleY ' + clip.scale.y + ' : ' + scale : null;

			clip.scale.y = scale;
			invalidateTransform(clip, from);
		}
	}

	public static inline function setClipRotation(clip : DisplayObject, rotation : Float) : Void {
		if (clip.rotation != rotation) {
			var from = DebugUpdate ? 'setClipRotation ' + clip.rotation + ' : ' + rotation : null;

			clip.rotation = rotation;
			invalidateTransform(clip, from);
		}
	}

	public static inline function setClipAlpha(clip : DisplayObject, alpha : Float) : Void {
		if (clip.alpha != alpha) {
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

			if (RenderSupportJSPixi.RendererType == "html" && !isNativeWidget(clip)) {
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
			} else if (untyped __instanceof__(obj, FlowSprite)) {
				untyped clip.alphaMask = obj;
			}
		}

		if (clip.mask != null) {
			untyped maskContainer.isMask = true;
			untyped maskContainer.child = clip;
			untyped clip.mask.isMask = true;
			untyped clip.mask.child = clip;
			untyped clip.maskContainer = maskContainer;

			if (RenderSupportJSPixi.RendererType == "html" && (Platform.isIE || Platform.isEdge) && untyped clip.mask.isSvg) {
				updateHasMask(clip);
			}

			clip.mask.once("removed", function () { clip.mask = null; });
		} else if (untyped clip.alphaMask != null) {
			untyped maskContainer.isMask = true;
			untyped maskContainer.child = clip;
			untyped maskContainer.url = clip.alphaMask.url;

			untyped clip.alphaMask.isMask = true;
			untyped clip.alphaMask.child = clip;
			untyped clip.maskContainer = maskContainer;

			updateHasMask(clip);

			untyped clip.alphaMask.once("removed", function () { untyped clip.alphaMask = null; });
		}

		setClipRenderable(maskContainer, false);
		maskContainer.once("childrenchanged", function () { setClipMask(clip, maskContainer); });

		if (RenderSupportJSPixi.RendererType == "html") {
			if (untyped clip.mask != null || clip.alphaMask != null) {
				initNativeWidget(clip);
			}
		}

		invalidateTransform(clip, 'setClipMask');
	}

	public static function updateHasMask(clip : DisplayObject) : Void {
		if (RenderSupportJSPixi.RendererType == "html") {
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

	public static function updateKeepNativeWidgetChildren(clip : DisplayObject, keepNativeWidgetChildren : Bool = false) : Void {
		untyped clip.keepNativeWidgetChildren = keepNativeWidgetChildren || clip.keepNativeWidget;

		if (untyped !clip.keepNativeWidgetChildren) {
			for (child in getClipChildren(clip)) {
				untyped clip.keepNativeWidgetChildren = clip.keepNativeWidgetChildren || child.keepNativeWidgetChildren || child.keepNativeWidget;
			}
		}

		if (untyped clip.parent != null && clip.parent.keepNativeWidgetChildren != clip.keepNativeWidgetChildren) {
			updateKeepNativeWidgetChildren(clip.parent, untyped clip.keepNativeWidgetChildren);
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
		if (untyped clip.clipVisible && (untyped __instanceof__(clip, FlowGraphics) || untyped __instanceof__(clip, FlowSprite)))
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
	public static function getFirstGraphics(clip : DisplayObject) : DisplayObject {
		if (untyped __instanceof__(clip, FlowGraphics))
			return clip;

		for (c in getClipChildren(clip)) {
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

	public static function updateClipID(clip : DisplayObject) : Void {
		var nativeWidget = untyped clip.nativeWidget;

		if (nativeWidget != null) {
			nativeWidget.setAttribute('id', Std.string(Std.int(Math.random() * 100000.0)));
		}
	}

	public static function updateNativeWidget(clip : DisplayObject) : Void {
		if (untyped clip.updateNativeWidget != null) {
			untyped clip.updateNativeWidget();
		} else {
			if (RenderSupportJSPixi.RendererType == "html") {
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

						updateNativeWidgetTransformMatrix(clip);
						updateNativeWidgetOpacity(clip);
						updateNativeWidgetMask(clip);

						updateNativeWidgetInteractive(clip);

						if (untyped clip.styleChanged) {
							untyped clip.updateNativeWidgetStyle();
						}

						updateNativeWidgetShadow(clip);
					}

					updateNativeWidgetDisplay(clip);
				}
			} else if (untyped clip.nativeWidget) {
				updateNativeWidgetTransformMatrix(clip);
				updateNativeWidgetOpacity(clip);

				if (untyped clip.styleChanged) {
					untyped clip.updateNativeWidgetStyle();
				}
			}
		}
	}

	public static inline function getNativeWidgetTransform(clip : DisplayObject) : Matrix {
		if (RenderSupportJSPixi.RendererType == "html") {
			if (RenderSupportJSPixi.RenderContainers) {
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

		var tx = round(transform.tx);
		var ty = round(transform.ty);

		if (untyped clip.scrollRect != null) {
			var point = applyTransformPoint(new Point(untyped clip.scrollRect.x, untyped clip.scrollRect.y), transform);

			tx = round(point.x);
			ty = round(point.y);
		}

		var localBounds = untyped clip.localBounds;

		if (untyped Math.isFinite(localBounds.minX) && Math.isFinite(localBounds.minY) && clip.nativeWidgetBoundsChanged) {
			untyped clip.nativeWidgetBoundsChanged = false;
			var nativeWidget = untyped clip.nativeWidget;

			if (untyped clip.alphaMask != null) {
				nativeWidget.style.width = '${localBounds.maxX}px';
				nativeWidget.style.height = '${localBounds.maxY}px';
			} else if (untyped clip.scrollRect != null) {
				nativeWidget.style.width = '${getWidgetWidth(clip) + 1}px';
				nativeWidget.style.height = '${getWidgetHeight(clip) + 1}px';
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

		nativeWidget.style.left = tx != 0 ? '${tx}px' : null;
		nativeWidget.style.top = ty != 0 ? '${ty}px' : null;
		nativeWidget.style.transform = (transform.a != 1 || transform.b != 0 || transform.c != 0 || transform.d != 1) ?
			'matrix(${transform.a}, ${transform.b}, ${transform.c}, ${transform.d}, 0, 0)' : null;
	}

	public static inline function getNativeWidgetAlpha(clip : DisplayObject) : Float {
		if (RenderSupportJSPixi.RendererType == "html" && !RenderSupportJSPixi.RenderContainers) {
			if (untyped clip.parentClip.worldAlpha > 0) {
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

		if (untyped RenderSupportJSPixi.RendererType != "html" && clip.isInput) {
			if (Platform.isEdge || Platform.isIE) {
				nativeWidget.style.opacity = 1.0;
				var slicedColor : Array<String> = untyped clip.style.fill.split(",");
				var newColor = slicedColor.slice(0, 3).join(",") + "," + Std.parseFloat(slicedColor[3]) * (untyped clip.isFocused ? alpha : 0) + ")";

				nativeWidget.style.color = newColor;
			} else {
				nativeWidget.style.opacity = untyped clip.isFocused ? alpha : 0;
			}
		} else {
			nativeWidget.style.opacity = alpha != 1 ? alpha : null;
		}
	}

	public static function updateNativeWidgetShadow(clip : DisplayObject) {
		if (untyped clip.parentClip.filters != null && BoxShadow) {
			updateNativeWidgetShadow(untyped clip.parentClip);
		}

		if (untyped clip.filters != null) {
			var filters : Array<Dynamic> = untyped clip.filters;

			if (filters != null && filters.length > 0) {
				var filter = filters[0];

				if (untyped BoxShadow || clip.isGraphics()) {
					applyNativeWidgetBoxShadow(clip, filter);
				} else {
					var color : Array<Int> = pixi.core.utils.Utils.hex2rgb(untyped filter.color, []);
					var nativeWidget : js.html.Element = untyped clip.nativeWidget;

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
			}
		}
	}

	private static function applyNativeWidgetBoxShadow(parent : DisplayObject, filter : Dynamic) : Void {
		var color : Array<Int> = pixi.core.utils.Utils.hex2rgb(untyped filter.color, []);
		var clip = getFirstGraphicsOrSprite(parent);
		var nativeWidget = untyped clip.nativeWidget;

		if (untyped clip.filterPadding != parent.filterPadding) {
			untyped clip.filterPadding = parent.filterPadding;

			if (untyped clip.updateNativeWidgetGraphicsData != null) {
				untyped clip.updateNativeWidgetGraphicsData();
			}
		}

		if (nativeWidget != null) {
			var svgs : Array<js.html.Element> = untyped nativeWidget.getElementsByTagName("svg");

			if (svgs.length > 0) {
				var svg = svgs[0];
				var clipFilter : js.html.Element = untyped svg.getElementById(untyped svg.parentNode.getAttribute('id') + "filter");

				if (clipFilter != null && clipFilter.parentNode != null) {
					clipFilter.parentNode.removeChild(clipFilter);
				}

				var defs = svg.firstElementChild != null && svg.firstElementChild.tagName.toLowerCase() == 'defs' ? svg.firstElementChild :
					Browser.document.createElementNS("http://www.w3.org/2000/svg", 'defs');
				clipFilter = defs.firstElementChild != null && defs.firstElementChild.tagName.toLowerCase() == 'mask' ? defs.firstElementChild :
					Browser.document.createElementNS("http://www.w3.org/2000/svg", 'filter');

				for (child in clipFilter.childNodes) {
					clipFilter.removeChild(untyped child);
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
				feOffset.setAttribute("dx", '${untyped Math.cos(filter.angle) * filter.distance}');
				feOffset.setAttribute("dy", '${untyped Math.sin(filter.angle) * filter.distance}');

				var feGaussianBlur = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'feGaussianBlur');
				feGaussianBlur.setAttribute("result", "blurOut");
				feGaussianBlur.setAttribute("in", "offOut");
				feGaussianBlur.setAttribute("stdDeviation", '${untyped filter.blur}');

				var feBlend = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'feBlend');
				feBlend.setAttribute("in2", "blurOut");
				feBlend.setAttribute("in", "SourceGraphic");
				feBlend.setAttribute("mode", "normal");

				clipFilter.setAttribute('id', untyped svg.parentNode.getAttribute('id') + "filter");
				clipFilter.setAttribute('x', '${untyped -clip.filterPadding}');
				clipFilter.setAttribute('y', '${untyped -clip.filterPadding}');
				clipFilter.setAttribute('width', '${untyped getWidgetWidth(clip) + clip.filterPadding}');
				clipFilter.setAttribute('height', '${untyped getWidgetHeight(clip) + clip.filterPadding}');

				clipFilter.appendChild(feColorMatrix);
				clipFilter.appendChild(feOffset);
				clipFilter.appendChild(feGaussianBlur);
				clipFilter.appendChild(feBlend);

				defs.insertBefore(clipFilter, defs.firstChild);
				svg.insertBefore(defs, svg.firstChild);

				for (child in svg.childNodes) {
					if (untyped child.tagName.toLowerCase() != "defs") {
						untyped child.setAttribute("filter", 'url(#' + untyped svg.parentNode.getAttribute('id') + "filter)");

						parent.once("clearfilter", function() { if (untyped child != null) untyped child.removeAttribute("filter"); });
					}
				}
			} else {
				nativeWidget.style.boxShadow = '
					${untyped Math.cos(filter.angle) * filter.distance}px
					${untyped Math.sin(filter.angle) * filter.distance}px
					${untyped filter.blur}px
					rgba(${color[0] * 255}, ${color[1] * 255}, ${color[2] * 255}, ${untyped filter.alpha})
				';

				parent.once("clearfilter", function() { if (nativeWidget != null) nativeWidget.style.boxShadow = null; });
			}
		}
	}

	public static function createPlaceholderWidget(clip : DisplayObject) : Void {
		var placeholderWidget = untyped clip.placeholderWidget;

		if (placeholderWidget == null) {
			var nativeWidget = untyped clip.nativeWidget;

			placeholderWidget = Browser.document.createElement('div');
			untyped clip.placeholderWidget = placeholderWidget;

			placeholderWidget.style.height = '10000px';
			placeholderWidget.style.width = '10000px';
			placeholderWidget.className = 'nativeWidget';
			placeholderWidget.style.visibility = 'hidden';

			nativeWidget.insertBefore(placeholderWidget, nativeWidget.firstChild);
		}
	}

	public static function removePlaceholderWidget(clip : DisplayObject) : Void {
		var placeholderWidget : Dynamic = untyped clip.placeholderWidget;

		if (placeholderWidget != null) {
			if (placeholderWidget.parentNode != null) {
				placeholderWidget.parentNode.removeChild(placeholderWidget);
			}

			placeholderWidget = null;
		}
	}

	public static function removeNativeMask(clip : DisplayObject) : Void {
		removePlaceholderWidget(clip);

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

		if (y < 0 || x < 0) {
			nativeWidget.style.marginLeft = '${-x}px';
			nativeWidget.style.marginTop = '${-y}px';

			nativeWidget.style.width = '${getWidgetWidth(clip) + x}px';
			nativeWidget.style.height = '${getWidgetHeight(clip) + y}px';

			y = 0;
			x = 0;
		} else {
			nativeWidget.style.marginLeft = null;
			nativeWidget.style.marginTop = null;
			nativeWidget.style.clip = null;
		}

		if (x != 0 || y != 0) {
			createPlaceholderWidget(clip);
		}

		if (x > 10000) {
			untyped clip.placeholderWidget.style.width = '${getWidgetWidth(clip) + x}px';
		}

		if (y > 10000) {
			untyped clip.placeholderWidget.style.height = '${getWidgetHeight(clip) + y}px';
		}

		var scrollFn = function() {
			if (nativeWidget.scrollLeft != x) {
				nativeWidget.scrollLeft = x;
			}

			if (nativeWidget.scrollTop != y) {
				nativeWidget.scrollTop = y;
			}
		}
		nativeWidget.onscroll = scrollFn;
		scrollFn();
		untyped clip.scrollFn = scrollFn;
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
			removePlaceholderWidget(clip);

			var svgs : Array<js.html.Element> = nativeWidget.getElementsByTagName("svg");

			for (svg in svgs) {
				var clipMask : js.html.Element = untyped svg.getElementById(untyped svg.parentNode.getAttribute('id') + "mask");

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
				clipMask.setAttribute('id', untyped svg.parentNode.getAttribute('id') + "mask");
				clipMask.setAttribute('mask-type', 'alpha');

				clipMask.appendChild(image);
				defs.insertBefore(clipMask, defs.firstChild);
				svg.insertBefore(defs, svg.firstChild);

				for (child in svg.childNodes) {
					untyped child.setAttribute("mask", 'url(#' + untyped svg.parentNode.getAttribute('id') + "mask)");
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
			nativeWidget.style.overflow = untyped clip.isInput ? "auto" : "hidden";

			scrollNativeWidget(clip, round(scrollRect.x), round(scrollRect.y));
		} else if (mask != null) {
			var graphicsData = mask.graphicsData;

			if (graphicsData != null) {
				var data = graphicsData[0];

				if (data.shape.type == 0) {
					removePlaceholderWidget(clip);

					nativeWidget.style.overflow = null;
					nativeWidget.style.borderRadius = null;

					var svgs : Array<js.html.Element> = nativeWidget.getElementsByTagName("svg");

					if (untyped mask.parent.localTransformChanged) {
						untyped mask.parent.transform.updateLocalTransform();
					}

					if (Platform.isIE || svgs.length == 1) {
						for (svg in svgs) {
							var clipMask : js.html.Element = untyped svg.getElementById(untyped svg.parentNode.getAttribute('id') + "mask");

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
								return i % 2 == 0 ? (i == 0 ? 'M' : 'L') + p * mask.parent.localTransform.a + ' ' : '' + p * mask.parent.localTransform.d + ' ';
							}).join('')");
							path.setAttribute("d", d);
							path.setAttribute("fill", "white");
							path.setAttribute('transform', 'matrix(1 0 0 1
								${untyped -Std.int(svg.parentNode.style.marginLeft.substring(0, svg.parentNode.style.marginLeft.length - 2)) - Std.int(svg.parentNode.style.left.substring(0, svg.parentNode.style.left.length - 2))}
								${untyped -Std.int(svg.parentNode.style.marginTop.substring(0, svg.parentNode.style.marginTop.length - 2)) - Std.int(svg.parentNode.style.top.substring(0, svg.parentNode.style.top.length - 2))})');
							clipMask.setAttribute('id', untyped svg.parentNode.getAttribute('id') + "mask");

							clipMask.appendChild(path);
							defs.insertBefore(clipMask, defs.firstChild);
							svg.insertBefore(defs, svg.firstChild);

							for (child in svg.childNodes) {
								untyped child.setAttribute("mask", 'url(#' + untyped svg.parentNode.getAttribute('id') + "mask)");
							}
						}
					} else {
						var transform = prependInvertedMatrix(clip.worldTransform, untyped clip.mask.worldTransform);
						nativeWidget.style.clipPath = untyped __js__("'polygon(' + data.shape.points.map(function (p, i) {
							return i % 2 == 0 ? '' + p * transform1.a + 'px ' : '' + p * transform1.d + 'px' + (i != data.shape.points.length - 1 ? ',' : '')
						}).join('') + ')'");
						untyped nativeWidget.style.webkitClipPath = nativeWidget.style.clipPath;
					}
				} else if (data.shape.type == 1) {
					untyped nativeWidget.style.webkitClipPath = null;
					nativeWidget.style.clipPath = null;
					nativeWidget.style.borderRadius = null;
					nativeWidget.style.overflow = "hidden";

					scrollNativeWidget(clip, round(data.shape.x), round(data.shape.y));
				} else if (data.shape.type == 2) {
					untyped nativeWidget.style.webkitClipPath = null;
					nativeWidget.style.clipPath = null;
					nativeWidget.style.borderRadius = '${round(data.shape.radius)}px';
					nativeWidget.style.overflow = "hidden";

					scrollNativeWidget(clip, round(data.shape.x - data.shape.radius), round(data.shape.y - data.shape.radius));
				} else if (data.shape.type == 4) {
					untyped nativeWidget.style.webkitClipPath = null;
					nativeWidget.style.clipPath = null;
					nativeWidget.style.borderRadius = '${round(data.shape.radius)}px';
					nativeWidget.style.overflow = "hidden";

					scrollNativeWidget(clip, round(data.shape.x), round(data.shape.y));
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

			nativeWidget.oncontextmenu = function (e) { e.stopPropagation(); return untyped clip.isInput == true; };
			nativeWidget.style.pointerEvents = 'auto';
		} else {
			nativeWidget.onmouseover = null;
			nativeWidget.onmouseout = null;
			nativeWidget.onpointerover = null;
			nativeWidget.onpointerout = null;
			nativeWidget.style.pointerEvents = null;
		}
	}

	public static function getParentNode(clip : DisplayObject) : Dynamic {
		if (isNativeWidget(clip)) {
			return untyped clip.nativeWidget.parentNode;
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
			}

			if (clip.visible) {
				if (untyped clip.child == null && (!clip.onStage || getParentNode(clip) != clip.parentClip.nativeWidget)) {
					untyped clip.onStage = true;

					if (!Platform.isIE && !Platform.isSafari && !Platform.isIOS) {
						untyped clip.nativeWidget.style.display = null;
					}

					addNativeWidget(clip);
				}
			} else if (untyped clip.onStage) {
				untyped clip.onStage = false;

				if (!Platform.isIE && !Platform.isSafari && !Platform.isIOS) {
					untyped clip.nativeWidget.style.display = 'none';
				}

				RenderSupportJSPixi.once("drawframe", function() {
					if (untyped !clip.onStage && (!clip.visible || clip.parent == null)) {
						removeNativeWidget(clip);
					}
				});
			}
		}
	}

	public static function isNativeWidget(clip : DisplayObject) : Bool {
		return untyped clip.isNativeWidget;
	}

	public static function addNativeWidget(clip : DisplayObject) : Void {
		if (untyped clip.addNativeWidget != null) {
			untyped clip.addNativeWidget();
		} else if (RenderSupportJSPixi.RendererType == "html") {
			if (isNativeWidget(clip) && untyped clip.parent != null && clip.visible && clip.renderable) {
				appendNativeWidget(findParentClip(clip), clip);
				RenderSupportJSPixi.once("drawframe", function() { broadcastEvent(clip, "pointerout"); });
			}
		} else {
			clip.once('removed', function() { deleteNativeWidget(clip); });
		}
	}

	public static function removeNativeWidget(clip : DisplayObject) : Void {
		if (untyped clip.removeNativeWidget != null) {
			untyped clip.removeNativeWidget();
		} else {
			if (untyped isNativeWidget(clip) && clip.parentClip != null) {
				var nativeWidget : Dynamic = untyped clip.nativeWidget;

				if (untyped nativeWidget.parentNode != null && (clip.parentClip.parent != null || clip.parentClip == RenderSupportJSPixi.PixiStage)) {
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

	public static function findNextNativeWidget(clip : DisplayObject, parent : DisplayObject) : js.html.Element {
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

			return RenderSupportJSPixi.RenderContainers || isNativeWidget(clip.parent) ? null : findNextNativeWidget(clip.parent, parent);
		}

		return null;
	}

	public static function findNativeWidgetChild(clip : DisplayObject, parent : DisplayObject) : js.html.Element {
		if (untyped isNativeWidget(clip) && clip.parentClip == parent && getParentNode(clip) == parent.nativeWidget) {
			return untyped clip.nativeWidget;
		} else if (!RenderSupportJSPixi.RenderContainers && RenderSupportJSPixi.RendererType == "html") {
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

			untyped clip.nativeWidget.insertBefore(childWidget, nextWidget);

			applyScrollFnChildren(child);

			untyped child.parentClip = clip;
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
		if (untyped clip.visible && clip.scrollFn != null) {
			untyped clip.scrollFn();
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

	public static inline function getBoundsWidth(bounds : Bounds) : Float {
		return Math.isFinite(bounds.minX) ? bounds.maxX - bounds.minX : -1;
	}

	public static inline function getWidgetWidth(clip : DisplayObject) : Float {
		var widgetBounds : Bounds = untyped clip.widgetBounds;
		return ((widgetBounds != null && Math.isFinite(widgetBounds.minX)) ? getBoundsWidth(widgetBounds) : getWidth(clip)) +
			(untyped clip.style != null ? (untyped untyped clip.style.letterSpacing != null ? clip.style.letterSpacing : 0.0) + 1.0 : 0.0);
	}

	public static function getHeight(clip : DisplayObject) : Float {
		if (untyped clip.getHeight != null) {
			return untyped clip.getHeight();
		} else {
			return untyped clip.getLocalBounds().height;
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
						if (untyped clip.mask == null) {
							applyMaxBounds(clip, untyped child.currentBounds);
						}
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
				if (RenderSupportJSPixi.RendererType != "html") {
					untyped clip.nativeWidgetBoundsChanged = false;
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
				invalidateParentTransform(clip);
			}

			untyped clip.nativeWidgetBoundsChanged = true;
			if (RenderSupportJSPixi.RendererType != "html") {
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
		var bounds = untyped clip.localBounds;

		applyBoundsTransform(bounds, transform, container);

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
		if (untyped !clip.isNativeWidget || (tagName != null && clip.nativeWidget.tagName.toLowerCase() != tagName)) {
			untyped clip.isNativeWidget = true;
			untyped clip.createNativeWidget(tagName);

			invalidateTransform(clip, 'initNativeWidget');
		}
	}

	public static function invalidateRenderable(clip : DisplayObject, viewBounds : Bounds) : Void {
		if (!InvalidateRenderable) {
			return;
		}

		var localBounds = untyped clip.localBounds;

		if (localBounds == null || untyped clip.isMask) {
			return;
		}

		if (!Math.isFinite(localBounds.minX) || !Math.isFinite(localBounds.minY) || localBounds.isEmpty()) {
			// setClipRenderable(clip, untyped RenderSupportJSPixi.RendererType == "html" && clip.updateKeepNativeWidgetChildren);
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

		if ((RenderSupportJSPixi.RendererType != "html" && untyped clip.styleChanged != null) || untyped __instanceof__(clip, DropAreaClip)) {
			untyped clip.invalidateStyle();
			invalidateTransform(clip, 'invalidateRenderable');
		}

		if (!Math.isFinite(viewBounds.minX) || !Math.isFinite(viewBounds.minY) || viewBounds.isEmpty()) {
			setClipRenderable(clip, untyped clip.keepNativeWidgetChildren);
			return;
		}

		if (RenderSupportJSPixi.RendererType != "html" || isNativeWidget(clip) || !clip.renderable) {
			var renderable = viewBounds.maxX >= localBounds.minX && viewBounds.minX <= localBounds.maxX && viewBounds.maxY >= localBounds.minY && viewBounds.minY <= localBounds.maxY;

			if (untyped clip.keepNativeWidgetChildren && isNativeWidget(clip)) {
				untyped clip.nativeWidget.style.visibility = clip.nativeWidget.tabIndex > 0 ? "visible" : (renderable ? "inherit" : "hidden");
			}

			setClipRenderable(clip, untyped clip.keepNativeWidgetChildren || renderable);
		}

		if (untyped !clip.transformChanged || (!clip.visible && !clip.parent.visible)) {
			return;
		}

		for (child in getClipChildren(clip)) {
			if (untyped !child.isMask) {
				invalidateRenderable(child, viewBounds);
			}
		}
	}

	public static inline function getClipChildren(clip : DisplayObject) : Array<DisplayObject> {
		return untyped clip.children || [];
	}
}