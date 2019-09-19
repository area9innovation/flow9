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
	public static var BoxShadow : Bool = Util.getParameter("boxshadow") != "0";

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
				if (!RenderSupportJSPixi.DomRenderer) {
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

	public static function invalidateWorldTransform(clip : DisplayObject, ?localTransformChanged : Bool, ?from : String) : Void {
		if (untyped clip.parent != null && (!clip.worldTransformChanged || (localTransformChanged && !clip.localTransformChanged))) {
			untyped clip.worldTransformChanged = true;
			untyped clip.transformChanged = true;

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

			if (untyped clip.child != null && clip.localTransformChanged) {
				invalidateTransform(untyped clip.child, DebugUpdate ? from + ' ->\ninvalidateWorldTransform -> mask child' : null);
			}

			for (child in getClipChildren(clip)) {
				if (child.visible) {
					invalidateWorldTransform(child, localTransformChanged && !isNativeWidget(clip), DebugUpdate ? from + ' ->\ninvalidateWorldTransform -> child' : null);
				}
			}
		}
	}

	public static function invalidateParentTransform(clip : DisplayObject) : Void {
		if (clip.parent != null) {
			untyped clip.transformChanged = true;

			if (untyped clip.isCanvas) {
				untyped clip.worldTransformChanged = true;
				untyped clip.localTransformChanged = true;
			}

			if (untyped clip.parent.parent != null && (clip.parent.visible || clip.parent.parent.visible) && !clip.parent.transformChanged) {
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

			if (untyped clip.interactive) {
				clip.emit("pointerout");
			}

			if (!RenderSupportJSPixi.DomRenderer && updateAccessWidget) {
				untyped clip.accessWidget.updateDisplay();
			}

			invalidateTransform(clip, 'invalidateVisible');
		}
	}

	public static function invalidateInteractive(clip : DisplayObject, ?interactiveChildren : Bool = false) : Void {
		clip.interactive = untyped clip.listeners("pointerout").length > 0 || clip.listeners("pointerover").length > 0 || clip.cursor != null || clip.isInteractive;
		clip.interactiveChildren = clip.interactive || interactiveChildren;

		if (clip.interactive) {
			if (RenderSupportJSPixi.DomInteractions) {
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

			if (RenderSupportJSPixi.DomInteractions && !isNativeWidget(clip)) {
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

	public static inline function round(n : Float) : Float {
		return RenderSupportJSPixi.RoundPixels ? Math.round(n) : n;
	}

	// setScrollRect cancels setClipMask and vice versa
	public static inline function setScrollRect(clip : FlowContainer, left : Float, top : Float, width : Float, height : Float) : Void {
		var scrollRect : FlowGraphics = clip.scrollRect;

		if (scrollRect != null) {
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
		scrollRect.drawRect(0.0, 0.0, round(width), round(height));
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

			if (RenderSupportJSPixi.DomRenderer && (Platform.isIE || Platform.isEdge) && untyped clip.mask.isSvg) {
				updateHasMask(clip);
			}

			clip.mask.once("removed", function () { clip.mask = null; });
		} else if (untyped clip.alphaMask != null) {
			untyped maskContainer.isMask = true;
			untyped maskContainer.child = clip;
			untyped maskContainer.url = clip.alphaMask.url;

			untyped clip.alphaMask.isMask = true;
			untyped clip.alphaMask.child = clip;

			if (RenderSupportJSPixi.DomRenderer) {
				untyped clip.alphaMask = untyped maskContainer;
			}

			updateHasMask(clip);

			untyped clip.alphaMask.once("removed", function () { untyped clip.alphaMask = null; });
		}

		setClipRenderable(maskContainer, false);
		maskContainer.once("childrenchanged", function () { setClipMask(clip, maskContainer); });

		if (RenderSupportJSPixi.DomRenderer) {
			if (untyped clip.mask != null || clip.alphaMask != null) {
				initNativeWidget(clip);
			}
		}

		invalidateTransform(clip, 'setClipMask');
	}

	public static function updateHasMask(clip : DisplayObject) : Void {
		if (RenderSupportJSPixi.DomRenderer) {
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
			if (RenderSupportJSPixi.DomRenderer) {
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

						if (RenderSupportJSPixi.DomInteractions) {
							updateNativeWidgetInteractive(clip);
						}

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

	public static function updateNativeWidgetTransformMatrix(clip : DisplayObject, ?worldTransform : Bool) {
		if (worldTransform == null) {
			worldTransform = !RenderSupportJSPixi.RenderContainers && RenderSupportJSPixi.DomRenderer;
		}

		var nativeWidget = untyped clip.nativeWidget;

		if (untyped clip.getTransform == null && !worldTransform) {
			untyped clip.transform.updateLocalTransform();
		}

		var transform : Dynamic = untyped clip.getTransform != null ? untyped clip.getTransform(worldTransform) : worldTransform ?
			untyped clip.worldTransform : untyped clip.localTransform;

		if (!RenderSupportJSPixi.RenderContainers && RenderSupportJSPixi.DomRenderer) {
			var parentClip = untyped clip.parentClip;

			transform = prependInvertedMatrix(transform, parentClip.worldTransform);
		}

		var tx = round(transform.tx);
		var ty = round(transform.ty);

		if (untyped clip.scrollRect != null) {
			tx = round(transform.tx + round(untyped clip.scrollRect.x));
			ty = round(transform.ty + round(untyped clip.scrollRect.y));
		}

		var localBounds = untyped clip.localBounds;

		if (untyped Math.isFinite(localBounds.minX) && Math.isFinite(localBounds.minY) && clip.nativeWidgetBoundsChanged) {
			untyped clip.nativeWidgetBoundsChanged = false;
			var nativeWidget = untyped clip.nativeWidget;

			if (untyped clip.alphaMask != null) {
				nativeWidget.setAttribute('width', '${round(localBounds.maxX)}');
				nativeWidget.setAttribute('height', '${round(localBounds.maxY)}');
				nativeWidget.style.width = '${round(localBounds.maxX)}px';
				nativeWidget.style.height = '${round(localBounds.maxY)}px';
			} else {
				nativeWidget.setAttribute('width', '${round(getWidgetWidth(clip))}');
				nativeWidget.setAttribute('height', '${round(getWidgetHeight(clip))}');
				nativeWidget.style.width = '${round(getWidgetWidth(clip))}px';
				nativeWidget.style.height = '${round(getWidgetHeight(clip))}px';
			}
			// nativeWidget.setAttribute('minX', Std.string(localBounds.minX));
			// nativeWidget.setAttribute('minY', Std.string(localBounds.minY));
			// nativeWidget.setAttribute('maxX', Std.string(localBounds.maxX));
			// nativeWidget.setAttribute('maxY', Std.string(localBounds.maxY));

			// if (untyped clip.mask == null && untyped clip.alphaMask == null) {
			// 	tx = round(transform.tx + round(localBounds.minX));
			// 	ty = round(transform.ty + round(localBounds.minY));

			// 	nativeWidget.style.marginLeft = '${-round(localBounds.minX)}px';
			// 	nativeWidget.style.marginTop = '${-round(localBounds.minY)}px';
			// }

			// applyScrollFn(clip);
		}

		nativeWidget.style.left = '${tx}px';
		nativeWidget.style.top = '${ty}px';

		if (transform.a != 1 || transform.b != 0 || transform.c != 0 || transform.d != 1) {
			nativeWidget.style.transform = 'matrix(${transform.a}, ${transform.b}, ${transform.c}, ${transform.d}, 0, 0)';
		} else {
			nativeWidget.style.transform = 'none';
		}
	}

	public static function updateNativeWidgetOpacity(clip : DisplayObject, ?worldTransform : Bool) {
		if (worldTransform == null) {
			worldTransform = !RenderSupportJSPixi.RenderContainers && RenderSupportJSPixi.DomRenderer;
		}

		var nativeWidget = untyped clip.nativeWidget;

		var alpha = worldTransform ? clip.worldAlpha : clip.alpha;

		if (!RenderSupportJSPixi.RenderContainers && RenderSupportJSPixi.DomRenderer) {
			var parentClip = untyped clip.parentClip;

			if (parentClip.worldAlpha > 0) {
				alpha = alpha / parentClip.worldAlpha;
			} else {
				alpha = getNativeWidgetLocalAlpha(clip);
			}
		}

		if (alpha != 1) {
			nativeWidget.style.opacity = alpha;
		} else {
			nativeWidget.style.opacity = null;
		}
	}

	public static function updateNativeWidgetShadow(clip : DisplayObject) {
		if (untyped clip.parentClip.filters != null && BoxShadow) {
			var filters : Array<Dynamic> = untyped clip.parentClip.filters;

			if (filters != null) {
				for (filter in filters) {
					var color : Array<Int> = pixi.core.utils.Utils.hex2rgb(untyped filter.color, []);

					var nativeWidget : js.html.Element = untyped clip.nativeWidget;

					nativeWidget.style.boxShadow = '
						${round(untyped Math.cos(filter.angle) * filter.distance)}px
						${round(untyped Math.sin(filter.angle) * filter.distance)}px
						${round(untyped filter.blur)}px
						rgba(${color[0] * 255}, ${color[1] * 255}, ${color[2] * 255}, ${untyped filter.alpha})
					';
				}
			}
		}

		if (untyped clip.filters != null) {
			var filters : Array<Dynamic> = untyped clip.filters;

			if (filters != null) {
				for (filter in filters) {
					var color : Array<Int> = pixi.core.utils.Utils.hex2rgb(untyped filter.color, []);

					var nativeWidget : js.html.Element = untyped clip.nativeWidget;

					if (untyped clip.children != null && clip.children.filter(function(c) { return c.filters != null && c.filters.length > 0; }).length > 0) {
						if (BoxShadow) {
							nativeWidget.style.boxShadow = '
								${round(untyped Math.cos(filter.angle) * filter.distance)}px
								${round(untyped Math.sin(filter.angle) * filter.distance)}px
								${round(untyped filter.blur)}px
								rgba(${color[0] * 255}, ${color[1] * 255}, ${color[2] * 255}, ${untyped filter.alpha})
							';
						} else {
							nativeWidget.style.boxShadow = '
								${round(untyped Math.cos(filter.angle) * filter.distance)}px
								${round(untyped Math.sin(filter.angle) * filter.distance)}px
								${round(untyped filter.blur)}px
								rgba(${color[0] * 255}, ${color[1] * 255}, ${color[2] * 255}, ${untyped filter.alpha})
							';
						}
					} else {
						if (BoxShadow) {
							for (childWidget in nativeWidget.children) {
								childWidget.style.boxShadow = '
									${round(untyped Math.cos(filter.angle) * filter.distance)}px
									${round(untyped Math.sin(filter.angle) * filter.distance)}px
									${round(untyped filter.blur)}px
									rgba(${color[0] * 255}, ${color[1] * 255}, ${color[2] * 255}, ${untyped filter.alpha})
								';
							}
						} else {
							if (nativeWidget.children != null) {
								for (childWidget in nativeWidget.children) {
									childWidget.style.boxShadow = null;
								}
							}

							nativeWidget.style.filter = 'drop-shadow(
								${round(untyped Math.cos(filter.angle) * filter.distance)}px
								${round(untyped Math.sin(filter.angle) * filter.distance)}px
								${round(untyped filter.blur)}px
								rgba(${color[0] * 255}, ${color[1] * 255}, ${color[2] * 255}, ${untyped filter.alpha})
							)';
						}
					}
				}
			}
		}
	}

	public static function getNativeWidgetLocalAlpha(clip : DisplayObject) : Float {
		if (clip.parent != null && !isNativeWidget(clip.parent)) {
			return clip.alpha * getNativeWidgetLocalAlpha(clip.parent);
		} else {
			return clip.alpha;
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

			nativeWidget.style.width = '${round(getWidgetWidth(clip) + x)}px';
			nativeWidget.style.height = '${round(getWidgetHeight(clip) + y)}px';

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

	public static function updateNativeWidgetMask(clip : DisplayObject, ?worldTransform : Bool, ?attachScrollFn : Bool = false) {
		if (worldTransform == null) {
			worldTransform = !RenderSupportJSPixi.RenderContainers && RenderSupportJSPixi.DomRenderer;
		}

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
				var clipMask = Browser.document.getElementById(untyped svg.parentNode.getAttribute('id') + "mask");

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
				if (untyped Math.isFinite(clip.alphaMask.localBounds.minX) && Math.isFinite(clip.alphaMask.localBounds.minY)) {
					image.setAttribute('width', '${round(getWidgetWidth(untyped clip.alphaMask))}');
					image.setAttribute('height', '${round(getWidgetHeight(untyped clip.alphaMask))}');
					image.setAttribute('x', '${untyped clip.alphaMask.localBounds.minX}');
					image.setAttribute('y', '${untyped clip.alphaMask.localBounds.minY}');
				}
				image.setAttribute('href', alphaMask.url);
				image.setAttribute('transform', 'matrix(1 0 0 1
					${untyped -Std.int(svg.parentNode.style.marginLeft.substring(0, svg.parentNode.style.marginLeft.length - 2)) - Std.int(svg.parentNode.style.left.substring(0, svg.parentNode.style.left.length - 2))}
					${untyped -Std.int(svg.parentNode.style.marginTop.substring(0, svg.parentNode.style.marginTop.length - 2)) - Std.int(svg.parentNode.style.top.substring(0, svg.parentNode.style.top.length - 2))})');
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
				var transform = new Matrix();
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
							var clipMask = Browser.document.getElementById(untyped svg.parentNode.getAttribute('id') + "mask");

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
						nativeWidget.style.clipPath = untyped __js__("'polygon(' + data.shape.points.map(function (p, i) {
							return i % 2 == 0 ? '' + p * mask.parent.localTransform.a + 'px ' : '' + p * mask.parent.localTransform.d + 'px' + (i != data.shape.points.length - 1 ? ',' : '')
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
			if (clip.visible) {
				if (untyped clip.child == null && (!clip.onStage || getParentNode(clip) != clip.parentClip.nativeWidget)) {
					untyped clip.onStage = true;

					if (!Platform.isIE && !Platform.isSafari && !Platform.isIOS) {
						untyped clip.nativeWidget.style.display = null;
					}

					addNativeWidget(clip);
				}
			} else {
				if (untyped clip.onStage && !clip.keepNativeWidgetChildren) {
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
	}

	public static function isNativeWidget(clip : DisplayObject) : Bool {
		return untyped clip.isNativeWidget;
	}

	public static function addNativeWidget(clip : DisplayObject) : Void {
		if (untyped clip.addNativeWidget != null) {
			untyped clip.addNativeWidget();
		} else if (RenderSupportJSPixi.DomRenderer) {
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
		} else if (!RenderSupportJSPixi.RenderContainers && RenderSupportJSPixi.DomRenderer) {
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

			if (childWidget.style.zIndex == null || childWidget.style.zIndex == "") {
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

			untyped clip.nativeWidget = null;
			untyped clip.isNativeWidget = false;
		}

		if (untyped clip.accessWidget != null) {
			AccessWidget.removeAccessWidget(untyped clip.accessWidget);
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
			(untyped clip.style != null && untyped clip.style.letterSpacing != null ? untyped clip.style.letterSpacing + 1.0 : 1.0);
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

	public static function invalidateLocalBounds(clip : DisplayObject) : Void {
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
					if (untyped !child.isMask && child.clipVisible && child.localBounds != null) {
						invalidateLocalBounds(child);
						if (untyped clip.mask == null) {
							applyMaxBounds(clip, untyped child.currentBounds);
						}
					}
				}

				if (untyped clip.mask == null) {
					applyNewBounds(clip, untyped clip.maxLocalBounds);
				}
			}

			if (untyped clip.mask != null) {
				invalidateLocalBounds(untyped clip.mask);
				applyNewBounds(clip, untyped clip.mask.currentBounds);
			}

			if (untyped clip.nativeWidgetBoundsChanged || clip.localTransformChanged) {
				if (!RenderSupportJSPixi.DomRenderer) {
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
				invalidateTransform(clip);
			}

			untyped clip.nativeWidgetBoundsChanged = true;
			if (!RenderSupportJSPixi.DomRenderer) {
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


			container.minX = round(Math.min(Math.min(x[0], x[1]), Math.min(x[2], x[3])));
			container.minY = round(Math.min(Math.min(y[0], y[1]), Math.min(y[2], y[3])));
			container.maxX = round(Math.max(Math.max(x[0], x[1]), Math.max(x[2], x[3])));
			container.maxY = round(Math.max(Math.max(y[0], y[1]), Math.max(y[2], y[3])));
		} else {
			var x = [
				bounds.minX + transform.tx,
				bounds.maxX + transform.tx
			];

			var y = [
				bounds.minY + transform.ty,
				bounds.maxY + transform.ty
			];

			container.minX = round(Math.min(x[0], x[1]));
			container.minY = round(Math.min(y[0], y[1]));
			container.maxX = round(Math.max(x[0], x[1]));
			container.maxY = round(Math.max(y[0], y[1]));
		}

		return container;
	}

	public static function applyInvertedTransform(bounds : Bounds, transform : Matrix, ?container : Bounds) : Bounds {
		if (container == null) {
			container = new Bounds();
		}

		if (transform.a != 1 || transform.b != 0 || transform.c != 0 || transform.d != 1) {
			var id = 1.0 / ((transform.a * transform.d) + (transform.c * -transform.b));

			var x = [
				(transform.d * id * bounds.minX) + (-transform.c * id * bounds.minY) + (((transform.ty * transform.c) - (transform.tx * transform.d)) * id),
				(transform.d * id * bounds.minX) + (-transform.c * id * bounds.maxY) + (((transform.ty * transform.c) - (transform.tx * transform.d)) * id),
				(transform.d * id * bounds.maxX) + (-transform.c * id * bounds.maxY) + (((transform.ty * transform.c) - (transform.tx * transform.d)) * id),
				(transform.d * id * bounds.maxX) + (-transform.c * id * bounds.minY) + (((transform.ty * transform.c) - (transform.tx * transform.d)) * id)
			];

			var y = [
				(transform.a * id * bounds.minX) + (-transform.b * id * bounds.minY) + (((-transform.ty * transform.a) + (transform.tx * transform.b)) * id),
				(transform.a * id * bounds.minX) + (-transform.b * id * bounds.maxY) + (((-transform.ty * transform.a) + (transform.tx * transform.b)) * id),
				(transform.a * id * bounds.maxX) + (-transform.b * id * bounds.maxY) + (((-transform.ty * transform.a) + (transform.tx * transform.b)) * id),
				(transform.a * id * bounds.maxX) + (-transform.b * id * bounds.minY) + (((-transform.ty * transform.a) + (transform.tx * transform.b)) * id)
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
		var localBounds = untyped clip.localBounds;

		if (localBounds == null || untyped clip.isMask) {
			return;
		}

		if (!Math.isFinite(localBounds.minX) || !Math.isFinite(localBounds.minY) || localBounds.isEmpty()) {
			// setClipRenderable(clip, untyped RenderSupportJSPixi.DomRenderer && clip.updateKeepNativeWidgetChildren);
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

		if ((!RenderSupportJSPixi.DomRenderer && untyped clip.styleChanged != null) || untyped __instanceof__(clip, DropAreaClip)) {
			untyped clip.invalidateStyle();
			invalidateTransform(clip, 'invalidateRenderable');
		}

		if (!Math.isFinite(viewBounds.minX) || !Math.isFinite(viewBounds.minY) || viewBounds.isEmpty()) {
			setClipRenderable(clip, untyped clip.keepNativeWidgetChildren);
			return;
		}

		if (!RenderSupportJSPixi.DomRenderer || isNativeWidget(clip) || !clip.renderable) {
			setClipRenderable(
				clip,
				untyped clip.keepNativeWidgetChildren || (viewBounds.maxX >= localBounds.minX && viewBounds.minX <= localBounds.maxX && viewBounds.maxY >= localBounds.minY && viewBounds.minY <= localBounds.maxY)
			);
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