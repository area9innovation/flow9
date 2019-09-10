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
	public static var Round : Bool = Util.getParameter("roundpixels") == "1";

	private static var InvalidateStage : Bool = true;

	public static function log(s : Dynamic) : Void {
		untyped __js__("console.log(s)");
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
					untyped clip.stage.invalidateTransform();
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

	public static function invalidateTransform(clip : DisplayObject) : Void {
		if (InvalidateStage) {
			invalidateParentTransform(clip);
		}

		invalidateWorldTransform(clip);
	}

	public static function invalidateBounds(clip : DisplayObject) : Void {
		untyped clip.boundsChanged = true;
	}

	public static function invalidateWorldTransform(clip : DisplayObject, ?localTransformChanged : Bool) : Void {
		if (untyped clip.parent != null && (!clip.worldTransformChanged || ((localTransformChanged == null || localTransformChanged) && !clip.localTransformChanged))) {
			untyped clip.worldTransformChanged = true;
			untyped clip.transformChanged = true;

			if (localTransformChanged == null || localTransformChanged) {
				untyped clip.localTransformChanged = true;
			}

			if (untyped clip.child != null && clip.localTransformChanged) {
				invalidateTransform(untyped clip.child);
			}

			var children : Array<Dynamic> = untyped clip.children;
			if (children != null) {
				for (child in children) {
					if (child.visible) {
						invalidateWorldTransform(child, localTransformChanged != null ? localTransformChanged :
							(untyped clip.worldTransform.a == 0.0 ? true : (!isNativeWidget(clip) ? null : false)));
					}
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

			if (clip.parent.visible && clip.parent.parent != null && untyped !clip.parent.transformChanged) {
				invalidateParentTransform(clip.parent);
			} else {
				invalidateStage(clip);
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

			var children : Array<Dynamic> = untyped clip.children;
			if (children != null) {
				for (child in children) {
					invalidateVisible(child, updateAccess && !updateAccessWidget, parentClip);
				}
			}

			if (untyped clip.interactive && clip.pointerOver) {
				untyped clip.pointerOver = false;
				clip.emit("pointerout");
			}

			if (!RenderSupportJSPixi.DomRenderer && updateAccessWidget) {
				untyped clip.accessWidget.updateDisplay();
			}

			invalidateTransform(clip);
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
					invalidateTransform(clip);
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
			invalidateBounds(clip);
			invalidateTransform(clip);

			if (untyped clip.parent.hasMask) {
				updateHasMask(clip);
			}

			clip.once('removed', function() { invalidate(clip); });
		} else {
			untyped clip.worldTransformChanged = false;
			untyped clip.transformChanged = false;
			untyped clip.localTransformChanged = false;

			if (Platform.isIE) {
				RenderSupportJSPixi.once("drawframe", function() {
					if (clip.parent == null) {
						removeNativeWidget(clip);
					}
				});
			} else {
				removeNativeWidget(clip);
			}
		}
	}

	public static inline function setClipX(clip : DisplayObject, x : Float) : Void {
		if (untyped clip.scrollRect != null) {
			x = x - untyped clip.scrollRect.x;
		}

		if (clip.x != x) {
			if (untyped clip.parent != null && clip.localBounds != null && clip.localBounds.minX != Math.POSITIVE_INFINITY) {
				clip.x = x;
				invalidateTransform(clip);
				invalidateLocalBounds(clip);
			} else {
				clip.x = x;
				invalidateTransform(clip);
			}
		}
	}

	public static inline function setClipY(clip : DisplayObject, y : Float) : Void {
		if (untyped clip.scrollRect != null) {
			y = y - untyped clip.scrollRect.y;
		}

		if (clip.y != y) {
			if (untyped clip.parent != null && clip.localBounds != null && clip.localBounds.minX != Math.POSITIVE_INFINITY) {
				clip.y = y;
				invalidateTransform(clip);
				invalidateLocalBounds(clip);
			} else {
				clip.y = y;
				invalidateTransform(clip);
			}
		}
	}

	public static inline function setClipScaleX(clip : DisplayObject, scale : Float) : Void {
		if (clip.scale.x != scale) {
			if (untyped clip.parent != null && clip.localBounds != null && clip.localBounds.minX != Math.POSITIVE_INFINITY) {
				clip.scale.x = scale;
				invalidateTransform(clip);
				invalidateLocalBounds(clip);
			} else {
				clip.scale.x = scale;
				invalidateTransform(clip);
			}
		}
	}

	public static inline function setClipScaleY(clip : DisplayObject, scale : Float) : Void {
		if (clip.scale.y != scale) {
			if (untyped clip.parent != null && clip.localBounds != null && clip.localBounds.minX != Math.POSITIVE_INFINITY) {
				clip.scale.y = scale;
				invalidateTransform(clip);
				invalidateLocalBounds(clip);
			} else {
				clip.scale.y = scale;
				invalidateTransform(clip);
			}
		}
	}

	public static inline function setClipRotation(clip : DisplayObject, rotation : Float) : Void {
		if (clip.rotation != rotation) {
			if (untyped clip.parent != null && clip.localBounds != null && clip.localBounds.minX != Math.POSITIVE_INFINITY) {
				clip.rotation = rotation;
				invalidateTransform(clip);
				invalidateLocalBounds(clip);
			} else {
				clip.rotation = rotation;
				invalidateTransform(clip);
			}
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

			invalidateTransform(clip);
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
		return Round ? Math.round(n) : n;
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

			setClipMask(clip, scrollRect);
			clip.addChild(scrollRect);
		}

		scrollRect.beginFill(0xFFFFFF);
		scrollRect.drawRect(0.0, 0.0, round(width), round(height));

		setClipX(scrollRect, left);
		setClipY(scrollRect, top);
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

			if (RenderSupportJSPixi.DomRenderer) {
				invalidateTransform(clip);
			} else {
				invalidateStage(clip);
			}

			calculateLocalBounds(clip);
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

		maskContainer.once("childrenchanged", function () { setClipMask(clip, maskContainer); });

		if (RenderSupportJSPixi.DomRenderer) {
			if (untyped clip.mask != null || clip.alphaMask != null) {
				initNativeWidget(clip);
			}

			invalidateTransform(clip);
		} else {
			invalidateStage(clip);
		}

		calculateLocalBounds(clip);
	}

	public static function updateHasMask(clip : DisplayObject) : Void {
		if (RenderSupportJSPixi.DomRenderer) {
			untyped clip.hasMask = true;

			if (untyped clip.updateNativeWidgetGraphicsData != null) {
				untyped clip.updateNativeWidgetGraphicsData();
			}

			var children : Array<Dynamic> = untyped clip.children;
			if (children != null) {
				for (child in children) {
					updateHasMask(child);
				}
			}
		}
	}

	public static function getMaskedBounds(clip : DisplayObject) : Bounds {
		var calculatedBounds = new Bounds();

		calculatedBounds.minX = Math.NEGATIVE_INFINITY;
		calculatedBounds.minY = Math.NEGATIVE_INFINITY;
		calculatedBounds.maxX = Math.POSITIVE_INFINITY;
		calculatedBounds.maxY = Math.POSITIVE_INFINITY;

		var parentBounds = clip.parent != null ? getMaskedBounds(clip.parent) : null;

		if (untyped clip._mask != null) {
			if (untyped clip._mask != untyped clip.scrollRect) {
				untyped clip._mask.child = clip;
			}

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
		var worldTransform = clip.worldTransform;

		applyBoundsTransform(bounds, worldTransform, bounds);

		return bounds;
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

		var children : Array<DisplayObject> = untyped parent.children;
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

	public static function updateClipUUID(clip : DisplayObject) : Void {
		if (untyped clip.uuid == null) {
			untyped clip.uuid = untyped __js__("uuidv4()");
		}

		var nativeWidget = untyped clip.nativeWidget;

		if (nativeWidget != null) {
			nativeWidget.setAttribute('id', untyped clip.uuid);
		}
	}

	public static function updateNativeWidget(clip : DisplayObject) : Void {
		if (untyped clip.updateNativeWidget != null) {
			untyped clip.updateNativeWidget();
		} else {
			if (RenderSupportJSPixi.DomRenderer) {
				if (isNativeWidget(clip)) {
					if (clip.visible) {
						// untyped clip.nativeWidget.setAttribute("update", Std.int(clip.nativeWidget.getAttribute("update")) + 1);
						// untyped clip.nativeWidget.setAttribute("info", clip.info);

						updateNativeWidgetTransformMatrix(clip);
						updateNativeWidgetOpacity(clip);
						updateNativeWidgetMask(clip);

						if (untyped clip.isCanvas) {
							updateNativeWidgetCanvas(clip);
						}

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

		if (localBounds.minX != Math.POSITIVE_INFINITY && untyped clip.boundsChanged) {
			untyped clip.boundsChanged = false;
			var nativeWidget = untyped clip.nativeWidget;

			nativeWidget.setAttribute('width', '${round(getWidgetWidth(clip))}');
			nativeWidget.setAttribute('height', '${round(getWidgetHeight(clip))}');
			nativeWidget.style.width = '${round(getWidgetWidth(clip))}px';
			nativeWidget.style.height = '${round(getWidgetHeight(clip))}px';

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
		if (untyped clip.parentClip.filters != null && Platform.isIE) {
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
						if (Platform.isIE) {
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
						if (Platform.isIE) {
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

	public static function removeNativeWidgetMask(clip : DisplayObject) : Void {
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
		var viewBounds = untyped clip.viewBounds;
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
				image.setAttribute('width', '${round(getWidgetWidth(clip))}');
				image.setAttribute('height', '${round(getWidgetHeight(clip))}');
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

			nativeWidget.style.overflow = 'hidden';

			if (untyped clip.localBounds != null) {
				nativeWidget.style.marginLeft = '${untyped clip.alphaMask.localBounds.minX}px';
				nativeWidget.style.marginTop = '${untyped clip.alphaMask.localBounds.minY}px';
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
					removeNativeWidgetMask(clip);

					trace("updateNativeWidgetMask: Unknown shape type");
					trace(data);
				}
			} else {
				removeNativeWidgetMask(clip);
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
					nativeWidget.onmouseover = function() {
						if (untyped !clip.pointerOver) {
							untyped clip.pointerOver = true;
							clip.emit("pointerover");
						}
					}

					nativeWidget.onmouseout = function() {
						if (untyped clip.pointerOver) {
							untyped clip.pointerOver = false;
							clip.emit("pointerout");
						}
					}
				}
			} else {
				if (nativeWidget.style.onpointerover == null) {
					nativeWidget.onpointerover = function() {
						if (untyped !clip.pointerOver) {
							untyped clip.pointerOver = true;
							clip.emit("pointerover");
						}
					}

					nativeWidget.onpointerout = function() {
						if (untyped clip.pointerOver) {
							untyped clip.pointerOver = false;
							clip.emit("pointerout");
						}
					}
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
				var nativeWidget = untyped clip.nativeWidget;

				if (Platform.isIE) {
					nativeWidget.style.display = "block";
				} else {
					nativeWidget.style.display = null;
				}

				if (getParentNode(clip) == null && isNativeWidget(clip) && clip.parent != null && clip.child == null) {
					addNativeWidget(clip);
				}
			} else if (!RenderSupportJSPixi.RenderContainers || clip.parent == null || (clip.parent.visible && clip.parent.renderable)) {
				if (getParentNode(clip) != null && untyped !clip.keepNativeWidget) { // todo: questionable optimization
					var nativeWidget = untyped clip.nativeWidget;

					nativeWidget.style.display = "none";
					RenderSupportJSPixi.once("stagechanged", function() {
						if (!clip.visible) {
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
			}
		} else {
			clip.once('removed', function() { deleteNativeWidget(clip); });
		}
	}

	public static function removeNativeWidget(clip : DisplayObject) : Void {
		if (untyped clip.removeNativeWidget != null) {
			untyped clip.removeNativeWidget();
		} else {
			if (isNativeWidget(clip)) {
				var nativeWidget : Dynamic = untyped clip.nativeWidget;

				if (nativeWidget.parentNode != null) {
					nativeWidget.parentNode.removeChild(nativeWidget);
					applyScrollFn(untyped clip.parentClip);
					untyped clip.parentClip = null;
				}
			} else if (!RenderSupportJSPixi.RenderContainers && RenderSupportJSPixi.DomRenderer) {
				var children : Array<DisplayObject> = untyped clip.children;
				if (children != null) {
					for (child in children) {
						removeNativeWidget(child);
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

	public static function findNextNativeWidget(clip : DisplayObject, parent : js.html.Element) : js.html.Element {
		if (clip.parent != null) {
			var children = clip.parent.children;

			if (children.indexOf(clip) >= 0) {
				for (child in children.slice(children.indexOf(clip) + 1)) {
					var nativeWidget = findNativeWidgetChild(child, parent);
					if (nativeWidget != null) {
						return nativeWidget;
					}
				}
			}

			return RenderSupportJSPixi.RenderContainers || isNativeWidget(clip.parent) ? null : findNextNativeWidget(clip.parent, parent);
		}

		return null;
	}

	public static function findNativeWidgetChild(clip : DisplayObject, parent : js.html.Element) : js.html.Element {
		if (isNativeWidget(clip) && getParentNode(clip) == parent) {
			return untyped clip.nativeWidget;
		} else if (!RenderSupportJSPixi.RenderContainers && RenderSupportJSPixi.DomRenderer) {
			var children : Array<DisplayObject> = untyped clip.children;
			if (children != null) {
				for (child in children) {
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
			var nativeWidget : Dynamic = untyped clip.nativeWidget;
			var childWidget : Dynamic = untyped child.nativeWidget;

			if (childWidget.style.zIndex == null || childWidget.style.zIndex == "") {
				var localStage : FlowContainer = untyped child.stage;

				if (localStage != null) {
					var zIndex = 1000 * localStage.parent.children.indexOf(localStage) + (childWidget.classList.contains("droparea") ? AccessWidget.zIndexValues.droparea : AccessWidget.zIndexValues.nativeWidget);
					childWidget.style.zIndex = Std.string(zIndex);
				}
			}

			nativeWidget.insertBefore(childWidget, findNextNativeWidget(child, nativeWidget));

			applyScrollFn(clip);
			applyScrollFnChildren(child);

			untyped child.parentClip = clip;
		} else {
			appendNativeWidget(clip.parent, child);
		}
	}

	public static function applyScrollFn(clip : DisplayObject) : Void {
		if (untyped clip.scrollFn != null) {
			untyped clip.scrollFn();
		} else if (clip.parent != null) {
			applyScrollFn(clip.parent);
		}
	}

	public static function applyScrollFnChildren(clip : DisplayObject) : Void {
		if (untyped clip.scrollFn != null) {
			untyped clip.scrollFn();
		}

		var children : Array<DisplayObject> = untyped clip.children;

		if (children != null) {
			for (child in children) {
				applyScrollFnChildren(child);
			}
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

	public static function getWidth(clip : DisplayObject) : Float {
		if (untyped clip.getWidth != null) {
			return untyped clip.getWidth();
		} else {
			return untyped clip.getLocalBounds().width;
		}
	}

	public static inline function getBoundsWidth(bounds : Bounds) : Float {
		return bounds.minX != Math.POSITIVE_INFINITY ? bounds.maxX - bounds.minX : 0;
	}

	public static inline function getWidgetWidth(clip : DisplayObject) : Float {
		var widgetBounds : Bounds = untyped clip.widgetBounds;
		return ((widgetBounds != null && widgetBounds.minX != Math.POSITIVE_INFINITY) ? getBoundsWidth(widgetBounds) : getWidth(clip)) +
			(untyped clip.style != null && untyped clip.style.letterSpacing != null ? untyped clip.style.letterSpacing + 1.0 : 0.0);
	}

	public static function getHeight(clip : DisplayObject) : Float {
		if (untyped clip.getHeight != null) {
			return untyped clip.getHeight();
		} else {
			return untyped clip.getLocalBounds().height;
		}
	}

	public static inline function getBoundsHeight(bounds : Bounds) : Float {
		return bounds.minY != Math.POSITIVE_INFINITY ? bounds.maxY - bounds.minY : 0;
	}

	public static inline function getWidgetHeight(clip : DisplayObject) : Float {
		var widgetBounds : Bounds = untyped clip.widgetBounds;
		return (widgetBounds != null && widgetBounds.minY != Math.POSITIVE_INFINITY) ? getBoundsHeight(widgetBounds) : getHeight(clip);
	}

	public static function replaceLocalBounds(clip : DisplayObject, currentBounds : Bounds, newBounds : Bounds) : Void {
		if (untyped clip.mask != null || clip.alphaMask != null || clip.scrollRect != null  || newBounds.minX == Math.POSITIVE_INFINITY || isEqualBounds(currentBounds, newBounds)) {
			return;
		}

		var localBounds : Bounds = untyped clip.localBounds;

		// if (currentBounds.minX != Math.POSITIVE_INFINITY && (localBounds.minX == currentBounds.minX || localBounds.minY == currentBounds.minY || localBounds.maxX == currentBounds.maxX || localBounds.maxY == currentBounds.maxY)) {
			calculateLocalBounds(clip);
			invalidateTransform(clip);
		// } else {
		// 	addLocalBounds(clip, newBounds);
		// }
	}

	public static function addLocalBounds(clip : DisplayObject, bounds : Bounds) : Void {
		if (untyped clip.mask != null || clip.alphaMask != null || clip.scrollRect != null) {
			return;
		}

		var localBounds : Bounds = untyped clip.localBounds;

		if (localBounds.minX > bounds.minX || localBounds.minY > bounds.minY || localBounds.maxX < bounds.maxX || localBounds.maxY < bounds.maxY) {
			localBounds.minX = Math.min(localBounds.minX, bounds.minX);
			localBounds.minY = Math.min(localBounds.minY, bounds.minY);
			localBounds.maxX = Math.max(localBounds.maxX, bounds.maxX);
			localBounds.maxY = Math.max(localBounds.maxY, bounds.maxY);

			invalidateLocalBounds(clip);
		}
	}

	public static function removeLocalBounds(clip : DisplayObject, bounds : Bounds) : Void {
		if (untyped clip.mask != null || clip.alphaMask != null || clip.scrollRect != null) {
			return;
		}

		var localBounds = untyped clip.localBounds;

		if (localBounds.minX == bounds.minX || localBounds.minY == bounds.minY || localBounds.maxX == bounds.maxX || localBounds.maxY == bounds.maxY) {
			calculateLocalBounds(clip);
		}
	}

	public static function calculateLocalBounds(clip : DisplayObject) : Void {
		var localBounds : Bounds = untyped clip.localBounds;
		var mask : Dynamic = untyped clip.mask || clip.alphaMask || clip.scrollRect;
		// var maskContainer : Dynamic = untyped clip.maskContainer;

		localBounds.clear();

		if (mask != null) {
			if (mask.localBounds != null && mask.localBounds.minX != Math.POSITIVE_INFINITY) {
				if (untyped clip.scrollRect == null && mask.parent != clip && mask.parent.localTransformChanged) {
					mask.transform.updateLocalTransform();
				}

				DisplayObjectHelper.applyBoundsTransform(mask.localBounds, untyped clip.scrollRect != null || mask.parent == clip ? mask.localTransform : mask.parent.localTransform, localBounds);
			}
		/*} else if (maskContainer != null) {
			if (maskContainer.localBounds != null && maskContainer.localBounds.minX != Math.POSITIVE_INFINITY) {
				if (maskContainer.localTransformChanged) {
					maskContainer.transform.updateLocalTransform();
				}

				DisplayObjectHelper.applyBoundsTransform(maskContainer.localBounds, maskContainer.localTransform, localBounds);
			}*/
		} else if (untyped clip.graphicsBounds != null) {
			var graphicsBounds = untyped clip.graphicsBounds;

			localBounds.minX = graphicsBounds.minX;
			localBounds.minY = graphicsBounds.minY;
			localBounds.maxX = graphicsBounds.maxX;
			localBounds.maxY = graphicsBounds.maxY;
		} else if (untyped clip.widgetBounds != null) {
			var widgetBounds = untyped clip.widgetBounds;

			localBounds.minX = widgetBounds.minX;
			localBounds.minY = widgetBounds.minY;
			localBounds.maxX = widgetBounds.maxX;
			localBounds.maxY = widgetBounds.maxY;
		} else if (untyped clip.children != null) {
			var children : Array<DisplayObject> = untyped clip.children;

			for (child in children) {
				if (untyped child.localBounds != null && child.localBounds.minX != Math.POSITIVE_INFINITY) {
					if (localBounds.minX == Math.POSITIVE_INFINITY) {
						applyLocalBoundsTransform(child, localBounds);
					} else {
						var childBounds = applyLocalBoundsTransform(child);

						localBounds.minX = Math.min(localBounds.minX, childBounds.minX);
						localBounds.minY = Math.min(localBounds.minY, childBounds.minY);
						localBounds.maxX = Math.max(localBounds.maxX, childBounds.maxX);
						localBounds.maxY = Math.max(localBounds.maxY, childBounds.maxY);
					}
				}
			}
		}

		invalidateLocalBounds(clip);
	}

	public static function invalidateLocalBounds(clip : DisplayObject) : Void {
		if (clip.parent != null) {
			var currentBounds = untyped clip.currentBounds;
			var newBounds = applyLocalBoundsTransform(clip);
			if (!isEqualBounds(currentBounds, newBounds)) {
				untyped clip.currentBounds = newBounds;
				if (RenderSupportJSPixi.DomRenderer) {
					invalidateBounds(clip);
				} else {
					invalidateTransform(clip);
					clip.emit("childrenchanged");
				}

				if (untyped clip.child != null) {
					calculateLocalBounds(untyped clip.child);
				}

				replaceLocalBounds(clip.parent, currentBounds, newBounds);
			}
		}
	}

	public static function prependInvertedMatrix(a : Matrix, b : Matrix, ?c : Matrix) : Matrix {
		if (c == null) {
			c = new Matrix();
		}

		if (b.a != 1.0 || b.b != 0.0 || b.c != 0.0 || b.d != 1.0) {
			c.a = (b.a != 0.0 ? a.a / b.a : 0.0) + (b.c != 0.0 ? a.b / b.c : 0.0);
			c.b = (b.b != 0.0 ? a.a / b.b : 0.0) + (b.d != 0.0 ? a.b / b.d : 0.0);
			c.c = (b.a != 0.0 ? a.c / b.a : 0.0) + (b.c != 0.0 ? a.d / b.c : 0.0);
			c.d = (b.b != 0.0 ? a.c / b.b : 0.0) + (b.d != 0.0 ? a.d / b.d : 0.0);

			c.tx = (b.a != 0.0 ? (a.tx - b.tx) / b.a : 0.0) + (b.c != 0.0 ? (a.ty - b.ty) / b.c : 0.0);
			c.ty = (b.b != 0.0 ? (a.tx - b.tx) / b.b : 0.0) + (b.d != 0.0 ? (a.ty - b.ty) / b.d : 0.0);
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


			container.minX = Math.round(Math.min(Math.min(x[0], x[1]), Math.min(x[2], x[3])));
			container.minY = Math.round(Math.min(Math.min(y[0], y[1]), Math.min(y[2], y[3])));
			container.maxX = Math.round(Math.max(Math.max(x[0], x[1]), Math.max(x[2], x[3])));
			container.maxY = Math.round(Math.max(Math.max(y[0], y[1]), Math.max(y[2], y[3])));
		} else {
			var x = [
				bounds.minX + transform.tx,
				bounds.maxX + transform.tx
			];

			var y = [
				bounds.minY + transform.ty,
				bounds.maxY + transform.ty
			];

			container.minX = Math.round(Math.min(x[0], x[1]));
			container.minY = Math.round(Math.min(y[0], y[1]));
			container.maxX = Math.round(Math.max(x[0], x[1]));
			container.maxY = Math.round(Math.max(y[0], y[1]));
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

			invalidateTransform(clip);
		}
	}

	public static function invalidateRenderable(clip : DisplayObject, viewBounds : Bounds) : Void {
		var localBounds = untyped clip.localBounds;

		if (localBounds == null || localBounds.minX == Math.POSITIVE_INFINITY || untyped clip.isMask) {
			return;
		}

		if (untyped clip.scrollRect != null) {
			var newViewBounds = new Bounds();

			newViewBounds.minX = Math.max(viewBounds.minX, untyped clip.localBounds.minX);
			newViewBounds.minY = Math.max(viewBounds.minY, untyped clip.localBounds.minY);
			newViewBounds.maxX = Math.min(viewBounds.maxX, untyped clip.localBounds.maxX);
			newViewBounds.maxY = Math.min(viewBounds.maxY, untyped clip.localBounds.maxY);

			viewBounds = newViewBounds;
		}

		if (!RenderSupportJSPixi.DomRenderer) {
			untyped clip.viewBounds = viewBounds;

			if (untyped clip.styleChanged != null) {
				untyped clip.invalidateStyle();
				invalidateTransform(clip);
			}
		}

		setClipRenderable(
			clip,
			!viewBounds.isEmpty() && viewBounds.maxX >= localBounds.minX && viewBounds.minX <= localBounds.maxX && viewBounds.maxY >= localBounds.minY && viewBounds.minY <= localBounds.maxY
		);

		if ((!clip.visible && untyped !clip.transformChanged) || (untyped RenderSupportJSPixi.DomRenderer && clip.keepNativeWidget)) {
			return;
		}

		var children : Array<DisplayObject> = untyped clip.children;
		if (children != null) {
			for (child in children) {
				if (untyped child.localTransformChanged) {
					untyped child.transform.updateLocalTransform();
				}

				var transform = untyped child.localTransform;
				var newViewBounds = new Bounds();

				applyInvertedTransform(viewBounds, transform, newViewBounds);

				invalidateRenderable(child, newViewBounds);
			}
		}
	}

	public static function replaceWithCanvas(clip : DisplayObject) : Void {
		if (RenderSupportJSPixi.DomRenderer) {
			initNativeWidget(clip, "canvas");

			var nativeWidget : js.html.CanvasElement = untyped clip.nativeWidget;

			if (untyped nativeWidget.context == null) {
				untyped nativeWidget.context = nativeWidget.getContext("2d", { alpha: true });
			}

			untyped clip.isCanvas = true;
		}
	}

	private static function updateNativeWidgetCanvas(clip : DisplayObject) {
		if (untyped clip.isCanvas) {
			var nativeWidget : js.html.CanvasElement = untyped clip.nativeWidget;

			var prevWorldAlpha = clip.worldAlpha;
			var prevVisible = clip.visible;
			var prevParent = clip.parent;
			var prevTransform = untyped clip.transform;
			var prevView = untyped RenderSupportJSPixi.PixiRenderer.view;

			clip.worldAlpha = 1.0;
			clip.visible = true;
			clip.parent = null;
			untyped clip.transform = new Transform();

			RenderSupportJSPixi.PixiRenderer.view = nativeWidget;
			untyped RenderSupportJSPixi.PixiRenderer.context = nativeWidget.context;
			untyped RenderSupportJSPixi.PixiRenderer.rootContext = nativeWidget.context;
			untyped RenderSupportJSPixi.PixiRenderer.context.clearRect(0, 0, nativeWidget.width, nativeWidget.height);

			forceUpdateTransform(clip);
			untyped clip.renderCanvas(RenderSupportJSPixi.PixiRenderer);

			clip.worldAlpha = prevWorldAlpha;
			clip.visible = prevVisible;
			clip.parent = prevParent;
			untyped clip.transform = prevTransform;
			untyped RenderSupportJSPixi.PixiRenderer.view = prevView;

			forceUpdateTransform(clip);

			untyped RenderSupportJSPixi.PixiRenderer._lastObjectRendered = RenderSupportJSPixi.PixiStage;
		}
	}

	private static function forceUpdateTransform(clip : DisplayObject) {
		// clip.cacheAsBitmap = false;

		if (clip.parent != null) {
			if (untyped clip.isMask) {
				clip.parent.removeChild(clip);
			} else {
				if (untyped clip.nativeWidget != null && untyped !clip.isCanvas) {
					deleteNativeWidget(clip);
				}

				untyped clip._boundsId++;
				untyped clip.transform.updateTransform(untyped clip.parent.transform);
				clip.worldAlpha = clip.alpha * clip.parent.worldAlpha;

				// if (untyped clip.layoutText != null) {
				// 	untyped clip.textChanged = true;
				// 	untyped clip.layoutText();
				// }
			}
		}

		var children : Array<DisplayObject> = untyped clip.children;
		if (children != null) {
			for (child in children) {
				forceUpdateTransform(child);
			}
		}
	}
}