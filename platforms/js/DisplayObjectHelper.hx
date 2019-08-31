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
	public static var RenderContainers : Bool = Util.getParameter("containers") == "1" || !RenderSupportJSPixi.DomRenderer;

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

	public static function invalidateWorldTransform(clip : DisplayObject, ?localTransformChanged : Bool = true) : Void {
		if (clip.parent != null && untyped (!clip.worldTransformChanged || (localTransformChanged && localTransformChanged != clip.localTransformChanged))) {
			untyped clip.worldTransformChanged = true;
			untyped clip.transformChanged = true;

			if (localTransformChanged) {
				untyped clip.localTransformChanged = true;
			}

			var children : Array<Dynamic> = untyped clip.children;
			if (children != null) {
				for (child in children) {
					if (child.visible) {
						invalidateWorldTransform(child, localTransformChanged && !isNativeWidget(clip));
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

	public static function invalidateVisible(clip : DisplayObject, ?updateAccess : Bool = true) : Void {
		var clipVisible = clip.parent != null && untyped clip._visible && getClipVisible(clip.parent);
		var visible = clip.parent != null && getClipRenderable(clip.parent) && (untyped clip.isMask || (clipVisible && clip.renderable));

		if (untyped clip.clipVisible != clipVisible || clip.visible != visible) {
			untyped clip.clipVisible = clipVisible;
			clip.visible = visible;

			clip.emit("visible");

			var updateAccessWidget = updateAccess && untyped clip.accessWidget != null;

			var children : Array<Dynamic> = untyped clip.children;
			if (children != null) {
				for (child in children) {
					invalidateVisible(child, updateAccess && !updateAccessWidget);
				}
			}

			if (clip.interactive && !clip.visible) {
				clip.emit("pointerout");
			}

			if (updateAccessWidget && !RenderSupportJSPixi.DomRenderer) {
				untyped clip.accessWidget.updateDisplay();
			}

			invalidateTransform(clip);
		}
	}

	public static function invalidateInteractive(clip : DisplayObject, ?interactiveChildren : Bool = false) : Void {
		clip.interactive = clip.listeners("pointerout").length > 0 || clip.listeners("pointerover").length > 0 || untyped clip.cursor != null || untyped clip.isInteractive;
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
			invalidateTransform(clip);
		} else {
			untyped clip.worldTransformChanged = false;
			untyped clip.transformChanged = false;
			untyped clip.localTransformChanged = false;

			deleteNativeWidget(clip);
		}
	}

	public static inline function setClipX(clip : DisplayObject, x : Float) : Void {
		if (untyped clip.scrollRect != null) {
			x = x - untyped clip.scrollRect.x;
		}

		if (clip.x != x) {
			if (clip.parent != null && untyped clip.localBounds.minX != Math.POSITIVE_INFINITY) {
				var currentBounds = applyLocalBoundsTransform(clip);

				clip.x = x;
				invalidateTransform(clip);

				var newBounds = applyLocalBoundsTransform(clip);
				var parentLocalBounds : Bounds = untyped clip.parent.localBounds;

				replaceLocalBounds(clip.parent, currentBounds, newBounds);
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
			if (clip.parent != null && untyped clip.localBounds.minX != Math.POSITIVE_INFINITY) {
				var currentBounds = applyLocalBoundsTransform(clip);

				clip.y = y;
				invalidateTransform(clip);

				var newBounds = applyLocalBoundsTransform(clip);
				replaceLocalBounds(clip.parent, currentBounds, newBounds);
			} else {
				clip.y = y;
				invalidateTransform(clip);
			}
		}
	}

	public static inline function setClipScaleX(clip : DisplayObject, scale : Float) : Void {
		if (clip.scale.x != scale) {
			if (clip.parent != null && untyped clip.localBounds.minX != Math.POSITIVE_INFINITY) {
				var currentBounds = applyLocalBoundsTransform(clip);

				clip.scale.x = scale;
				invalidateTransform(clip);

				var newBounds = applyLocalBoundsTransform(clip);
				replaceLocalBounds(clip.parent, currentBounds, newBounds);
			} else {
				clip.scale.x = scale;
				invalidateTransform(clip);
			}
		}
	}

	public static inline function setClipScaleY(clip : DisplayObject, scale : Float) : Void {
		if (clip.scale.y != scale) {
			if (clip.parent != null && untyped clip.localBounds.minX != Math.POSITIVE_INFINITY) {
				var currentBounds = applyLocalBoundsTransform(clip);

				clip.scale.y = scale;
				invalidateTransform(clip);

				var newBounds = applyLocalBoundsTransform(clip);
				replaceLocalBounds(clip.parent, currentBounds, newBounds);
			} else {
				clip.scale.y = scale;
				invalidateTransform(clip);
			}
		}
	}

	public static inline function setClipRotation(clip : DisplayObject, rotation : Float) : Void {
		if (clip.rotation != rotation) {
			if (clip.parent != null && untyped clip.localBounds.minX != Math.POSITIVE_INFINITY) {
				var currentBounds = applyLocalBoundsTransform(clip);

				clip.rotation = rotation;
				invalidateTransform(clip);

				var newBounds = applyLocalBoundsTransform(clip);
				replaceLocalBounds(clip.parent, currentBounds, newBounds);
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

	// setScrollRect cancels setClipMask and vice versa
	public static function setScrollRect(clip : FlowContainer, left : Float, top : Float, width : Float, height : Float) : Void {
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
		scrollRect.drawRect(0.0, 0.0, width, height);

		setClipX(scrollRect, left);
		setClipY(scrollRect, top);

		if (RenderSupportJSPixi.DomRenderer) {
			invalidateTransform(clip);
		} else {
			invalidateStage(clip);
		}

		untyped clip.calculateLocalBounds();
	}

	public static function removeScrollRect(clip : FlowContainer) : Void {
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

			untyped clip.calculateLocalBounds();
		}
	}

	// setClipMask cancels setScrollRect and vice versa
	public static function setClipMask(clip : FlowContainer, maskContainer : Container) : Void {
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

			clip.mask.once("removed", function () { clip.mask = null; });
		} else if (untyped clip.alphaMask != null) {
			untyped maskContainer.isMask = true;
		}

		maskContainer.once("childrenchanged", function () { setClipMask(clip, maskContainer); });

		if (RenderSupportJSPixi.DomRenderer) {
			if (clip.mask != null) {
				initNativeWidget(clip);
			}

			invalidateTransform(clip);
		} else {
			invalidateStage(clip);
		}

		untyped clip.calculateLocalBounds();
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

	public static function getClipUUID(clip : DisplayObject) : String {
		if (untyped clip.uuid == null) {
			untyped clip.uuid = untyped __js__("uuidv4()");
		}

		return untyped clip.uuid;
	}

	public static function getClipPath(clip : DisplayObject) : String {
		var graphicsData = untyped clip.graphicsData;

		if (graphicsData != null) {
			var data = graphicsData[0];

			if (data.shape.type == 0) {
				return untyped __js__("'polygon(' + data.shape.points.map(function(p, i) {
					return i % 2 == 0 ? (clip.x + p) + 'px ' : '' + (clip.y + p) + 'px' + (i != data.shape.points.length - 1 ? ',' : '');
				}).join('') + ')'");
			} else if (data.shape.type == 1) {
				return 'polygon(
					${clip.x + data.shape.x}px ${clip.y + data.shape.y}px,
					${clip.x + data.shape.x}px ${clip.y + data.shape.y + data.shape.height}px,
					${clip.x + data.shape.x + data.shape.width}px ${clip.y + data.shape.y + data.shape.height}px,
					${clip.x + data.shape.x + data.shape.width}px ${clip.y + data.shape.y}px
				)';
			} else if (data.shape.type == 2) {
				return 'circle(${data.shape.radius}px at ${data.shape.x}px ${data.shape.y}px)';
			} else if (data.shape.type == 4) {
				return 'polygon(
					${clip.x + data.shape.x}px ${clip.y + data.shape.y}px,
					${clip.x + data.shape.x}px ${clip.y + data.shape.y + data.shape.height}px,
					${clip.x + data.shape.x + data.shape.width}px ${clip.y + data.shape.y + data.shape.height}px,
					${clip.x + data.shape.x + data.shape.width}px ${clip.y + data.shape.y}px
				)';
			}  else {
				trace("getClipPath: Unknown shape type");
				trace(data);

				return "";
			}
		} else {
			return "";
		}
	}

	public static function updateNativeWidget(clip : DisplayObject) : Void {
		if (untyped clip.updateNativeWidget != null) {
			untyped clip.updateNativeWidget();
		} else {
			if (RenderSupportJSPixi.DomRenderer) {
				var nativeWidget : js.html.Element = untyped clip.nativeWidget;

				if (nativeWidget != null) {
					if (clip.visible && isNativeWidget(clip)) {
						updateNativeWidgetTransformMatrix(clip);
						updateNativeWidgetOpacity(clip);
						updateNativeWidgetMask(clip);

						if (untyped clip.isCanvas) {
							updateNativeWidgetCanvas(clip);
						}

						if (RenderSupportJSPixi.DomInteractions) {
							updateNativeWidgetInteractive(clip);
						}

						updateNativeWidgetShadow(clip);
					}

					updateNativeWidgetDisplay(clip);
				}
			} else {
				updateNativeWidgetTransformMatrix(clip);
				updateNativeWidgetOpacity(clip);
			}

			if (untyped clip.styleChanged) {
				untyped clip.updateNativeWidgetStyle();
			}
		}
	}

	public static function updateNativeWidgetTransformMatrix(clip : DisplayObject, ?worldTransform : Bool) {
		if (worldTransform == null) {
			worldTransform = !RenderContainers;
		}

		var nativeWidget = untyped clip.nativeWidget;

		if (nativeWidget != null) {
			if (untyped clip.getTransform == null && !worldTransform) {
				untyped clip.transform.updateLocalTransform();
			}

			var transform : Dynamic = untyped clip.getTransform != null ? untyped clip.getTransform(worldTransform) : worldTransform ?
				untyped clip.worldTransform : untyped clip.localTransform;

			if (!RenderContainers) {
				var parentNativeWidget = findParentNativeWidget(clip);

				if (parentNativeWidget != null) {
					transform = transform.copy(new Matrix()).prepend(parentNativeWidget.worldTransform.copy(new Matrix()).invert());
				}
			}

			var tx = Math.floor(transform.tx);
			var ty = Math.floor(transform.ty);

			if (untyped clip.scrollRect != null) {
				tx = Math.floor(transform.tx + untyped clip.scrollRect.x);
				ty = Math.floor(transform.ty + untyped clip.scrollRect.y);
			}

			nativeWidget.style.left = '${tx}px';
			nativeWidget.style.top = '${ty}px';

			if (transform.a != 1 || transform.b != 0 || transform.c != 0 || transform.d != 1) {
				nativeWidget.style.transform = 'matrix(${transform.a}, ${transform.b}, ${transform.c}, ${transform.d}, 0, 0)';
			} else {
				nativeWidget.style.transform = null;
			}
		}
	}

	public static function updateNativeWidgetOpacity(clip : DisplayObject, ?worldTransform : Bool) {
		if (worldTransform == null) {
			worldTransform = !RenderContainers;
		}

		var nativeWidget = untyped clip.nativeWidget;

		if (nativeWidget != null) {
			var alpha = worldTransform ? clip.worldAlpha : clip.alpha;

			if (!RenderContainers) {
				var parentNativeWidget = findParentNativeWidget(clip);

				if (parentNativeWidget != null) {
					if (parentNativeWidget.worldAlpha > 0) {
						alpha = alpha / parentNativeWidget.worldAlpha;
					} else {
						alpha = getNativeWidgetLocalAlpha(clip);
					}
				}
			}

			if (alpha != 1) {
				nativeWidget.style.opacity = alpha;
			} else {
				nativeWidget.style.opacity = null;
			}
		}
	}

	public static function updateNativeWidgetShadow(clip : DisplayObject) {
		var nativeWidget : js.html.Element = untyped clip.nativeWidget;

		if (nativeWidget != null) {
			var filters = clip.filters;

			if (filters != null) {
				for (filter in clip.filters) {
					var color : Array<Int> = pixi.core.utils.Utils.hex2rgb(untyped filter.color, []);

					if (untyped clip.mask == null && nativeWidget.children != null && nativeWidget.children.length == 1 && false) {
						for (childWidget in nativeWidget.children) {
							childWidget.style.boxShadow = '
								${Math.round(untyped Math.cos(filter.angle) * filter.distance)}px
								${Math.round(untyped Math.sin(filter.angle) * filter.distance)}px
								${Math.round(untyped filter.blur)}px
								rgba(${color[0] * 255}, ${color[1] * 255}, ${color[2] * 255}, ${untyped filter.alpha})
							';
						}
					} else {
						if (nativeWidget.children != null && false) {
							for (childWidget in nativeWidget.children) {
								childWidget.style.boxShadow = null;
							}
						}

						nativeWidget.style.filter = 'drop-shadow(
							${Math.round(untyped Math.cos(filter.angle) * filter.distance)}px
							${Math.round(untyped Math.sin(filter.angle) * filter.distance)}px
							${Math.round(untyped filter.blur)}px
							rgba(${color[0] * 255}, ${color[1] * 255}, ${color[2] * 255}, ${untyped filter.alpha})
						)';
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
		var nativeWidget = untyped clip.nativeWidget;

		if (placeholderWidget == null && nativeWidget != null) {
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

		if (nativeWidget != null && nativeWidget.style.overflow != '' || nativeWidget.style.clipPath != '') {
			nativeWidget.style.overflow = null;
			nativeWidget.style.clipPath = null;
			nativeWidget.onscroll = null;
			nativeWidget.style.width = null;
			nativeWidget.style.height = null;
			nativeWidget.style.borderRadius = null;
		}
	}

	public static function scrollNativeWidget(clip : DisplayObject, x : Int, y : Int) : Void {
		var nativeWidget : Dynamic = untyped clip.nativeWidget;

		if (nativeWidget != null) {
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
	}

	public static function updateNativeWidgetMask(clip : DisplayObject, ?worldTransform : Bool, ?attachScrollFn : Bool = false) {
		if (worldTransform == null) {
			worldTransform = !RenderContainers;
		}

		var nativeWidget = untyped clip.nativeWidget;

		if (nativeWidget != null) {
			var mask : FlowGraphics = clip.mask;
			var scrollRect = untyped clip.scrollRect || clip.viewBounds;
			var viewBounds = untyped clip.viewBounds;

			if (untyped scrollRect != null && clip.children != null && clip.children.length > 0) {
				nativeWidget.style.clipPath = null;
				nativeWidget.style.width = '${scrollRect.width}px';
				nativeWidget.style.height = '${scrollRect.height}px';
				nativeWidget.style.borderRadius = null;
				nativeWidget.style.overflow = "hidden";

				scrollNativeWidget(clip, Math.floor(scrollRect.x), Math.floor(scrollRect.y));
			} else if (mask != null) {
				var graphicsData = mask.graphicsData;

				if (graphicsData != null) {
					var transform = new Matrix();
					var data = graphicsData[0];

					if (data.shape.type == 0) {
						removePlaceholderWidget(clip);

						nativeWidget.style.overflow = null;
						nativeWidget.style.width = '${getWidth(clip)}px';
						nativeWidget.style.height = '${getHeight(clip)}px';
						nativeWidget.style.borderRadius = null;
						nativeWidget.style.clipPath = untyped __js__("'polygon(' + data.shape.points.map(function (p, i) {
							return i % 2 == 0 ? p + 'px ' : '' + p + 'px' + (i != data.shape.points.length - 1 ? ',' : '')
						}).join('') + ')'");
					} else if (data.shape.type == 1) {
						nativeWidget.style.clipPath = null;
						nativeWidget.style.width = '${getWidth(clip)}px';
						nativeWidget.style.height = '${getHeight(clip)}px';
						nativeWidget.style.overflow = "hidden";

						scrollNativeWidget(clip, Math.floor(data.shape.x), Math.floor(data.shape.y));
					} else if (data.shape.type == 2) {
						nativeWidget.style.clipPath = null;
						nativeWidget.style.width = '${getWidth(clip)}px';
						nativeWidget.style.height = '${getHeight(clip)}px';
						nativeWidget.style.borderRadius = '${data.shape.radius}px';
						nativeWidget.style.overflow = "hidden";

						scrollNativeWidget(clip, Math.floor(data.shape.x - data.shape.radius), Math.floor(data.shape.y - data.shape.radius));
					} else if (data.shape.type == 4) {
						nativeWidget.style.clipPath = null;
						nativeWidget.style.width = '${getWidth(clip)}px';
						nativeWidget.style.height = '${getHeight(clip)}px';
						nativeWidget.style.borderRadius = '${data.shape.radius}px';
						nativeWidget.style.overflow = "hidden";

						scrollNativeWidget(clip, Math.floor(data.shape.x), Math.floor(data.shape.y));
					}  else {
						removeNativeWidgetMask(clip);

						trace("updateNativeWidgetMask: Unknown shape type");
						trace(data);
					}
				}
			} else {
				removeNativeWidgetMask(clip);
			}
		}
	}

	public static function updateNativeWidgetMetrics(clip : DisplayObject) : Void {
		var nativeWidget = untyped clip.nativeWidget;
		var localBounds = untyped clip.localBounds;

		if (nativeWidget != null && localBounds.minX != Math.POSITIVE_INFINITY) {
			if (untyped clip.isCanvas) {
				nativeWidget.setAttribute('width', '${getWidth(clip)}');
				nativeWidget.setAttribute('height', '${getHeight(clip)}');
				nativeWidget.style.width = '${getWidth(clip)}px';
				nativeWidget.style.height = '${getHeight(clip)}px';
			} else {
				nativeWidget.style.width = '${localBounds.maxX}px';
				nativeWidget.style.height = '${localBounds.maxY}px';
			}

			nativeWidget.setAttribute('minX', Std.string(localBounds.minX));
			nativeWidget.setAttribute('minY', Std.string(localBounds.minY));
			nativeWidget.setAttribute('maxX', Std.string(localBounds.maxX));
			nativeWidget.setAttribute('maxY', Std.string(localBounds.maxY));
		}
	}

	public static function updateNativeWidgetInteractive(clip : DisplayObject) : Void {
		var nativeWidget = untyped clip.nativeWidget;

		if (nativeWidget != null) {
			if (untyped clip.cursor != null) {
				nativeWidget.style.cursor = untyped clip.cursor;
			} else {
				nativeWidget.style.cursor = null;
			}

			if (clip.interactive) {
				if (nativeWidget.style.onmouseover == null) {
					nativeWidget.onpointerover = function() {
						clip.emit("pointerover");
					}

					nativeWidget.onpointerout = function() {
						clip.emit("pointerout");
					}
				}

				nativeWidget.style.pointerEvents = 'auto';
				updateNativeWidgetMetrics(clip);
			} else {
				nativeWidget.onmouseover = null;
				nativeWidget.onmouseout = null;
				nativeWidget.style.pointerEvents = null;
			}
		}
	}

	public static function getParentNode(clip : DisplayObject) : Dynamic {
		var nativeWidget = untyped clip.nativeWidget;

		if (nativeWidget != null) {
			return nativeWidget.parentNode;
		}

		return null;
	}

	public static function updateNativeWidgetDisplay(clip : DisplayObject) : Void {
		if (untyped clip.updateNativeWidgetDisplay != null) {
			untyped clip.updateNativeWidgetDisplay();
		} else {
			var nativeWidget = untyped clip.nativeWidget;

			if (nativeWidget != null) {
				if (clip.visible) {
					if (Platform.isIE) {
						nativeWidget.style.display = "block";
					} else {
						nativeWidget.style.display = null;
					}

					if (getParentNode(clip) == null && isNativeWidget(clip) && clip.parent != null) {
						addNativeWidget(clip);
					}
				} else if (!RenderContainers || clip.parent == null || (clip.parent.visible && clip.parent.renderable)) {
					if (getParentNode(clip) != null && untyped !clip.keepNativeWidget) { // todo: questionable optimization
						nativeWidget.style.display = "none";
						RenderSupportJSPixi.once("freeframe", function() { if (!clip.visible || !clip.renderable) removeNativeWidget(clip); });
					}
				}
			} else {
				var children : Array<DisplayObject> = untyped clip.children;

				if (children != null) {
					for (child in children) {
						updateNativeWidgetDisplay(child);
					}
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
				appendNativeWidget(untyped clip.parent, clip);

				var children : Array<DisplayObject> = untyped clip.children;
				if (children != null) {
					for (child in children) {
						addNativeWidget(child);
					}
				}
			}
		} else {
			clip.once('removed', function() { deleteNativeWidget(clip); });
		}
	}

	public static function removeNativeWidget(clip : DisplayObject) : Void {
		if (untyped clip.removeNativeWidget != null) {
			untyped clip.removeNativeWidget();
		} else {
			var nativeWidget : Dynamic = untyped clip.nativeWidget;

			if (nativeWidget != null) {
				if (nativeWidget.parentNode != null) {
					nativeWidget.parentNode.removeChild(nativeWidget);
				}
			} else if (!RenderContainers) {
				var children : Array<DisplayObject> = untyped clip.children;
				if (children != null) {
					for (child in children) {
						removeNativeWidget(child);
					}
				}
			}
		}
	}

	public static function findParentNativeWidget(clip : DisplayObject) : DisplayObject {
		if (clip.parent == null) {
			return null;
		} else if (isNativeWidget(clip.parent)) {
			return clip.parent;
		} else {
			return findParentNativeWidget(clip.parent);
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

			return RenderContainers || isNativeWidget(clip.parent) ? null : findNextNativeWidget(clip.parent, parent);
		}

		return null;
	}

	public static function findNativeWidgetChild(clip : DisplayObject, parent : js.html.Element) : js.html.Element {
		if (isNativeWidget(clip) && getParentNode(clip) == parent) {
			return untyped clip.nativeWidget;
		} else if (!RenderContainers) {
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
		var nativeWidget : Dynamic = untyped clip.nativeWidget;
		var childWidget : Dynamic = untyped child.nativeWidget;

		if (nativeWidget != null && isNativeWidget(clip)) {
			if (childWidget.style.zIndex == null || childWidget.style.zIndex == "") {
				var localStage : FlowContainer = untyped clip.stage;

				if (localStage != null) {
					var zIndex = 1000 * localStage.parent.children.indexOf(localStage) + (childWidget.classList.contains("droparea") ? AccessWidget.zIndexValues.droparea : AccessWidget.zIndexValues.nativeWidget);
					childWidget.style.zIndex = Std.string(zIndex);
				}
			}

			nativeWidget.insertBefore(childWidget, findNextNativeWidget(child, nativeWidget));

			if (untyped clip.scrollFn != null) {
				untyped clip.scrollFn();
			}
		} else {
			appendNativeWidget(clip.parent, child);
		}
	}

	public static function deleteNativeWidget(clip : DisplayObject) : Void {
		removeNativeWidget(clip);

		if (untyped clip.accessWidget != null) {
			AccessWidget.removeAccessWidget(untyped clip.accessWidget);
		}

		untyped clip.nativeWidget = null;
		untyped clip.isNativeWidget = false;
	}

	public static function getWidth(clip : DisplayObject) : Float {
		if (untyped clip.getWidth != null) {
			return untyped clip.getWidth();
		} else {
			return untyped clip.getLocalBounds().width;
		}
	}

	public static function getHeight(clip : DisplayObject) : Float {
		if (untyped clip.getHeight != null) {
			return untyped clip.getHeight();
		} else {
			return untyped clip.getLocalBounds().height;
		}
	}

	public static function replaceLocalBounds(clip : DisplayObject, currentBounds : Bounds, newBounds : Bounds) : Void {
		if (untyped clip.mask != null || clip.alphaMask != null || clip.scrollRect != null || clip.calculateLocalBounds == null || newBounds.minX == Math.POSITIVE_INFINITY || isEqualBounds(currentBounds, newBounds)) {
			return;
		}

		var localBounds : Bounds = untyped clip.localBounds;

		if (currentBounds.minX != Math.POSITIVE_INFINITY && (localBounds.minX == currentBounds.minX || localBounds.minY == currentBounds.minY || localBounds.maxX == currentBounds.maxX || localBounds.maxY == currentBounds.maxY)) {
			untyped clip.calculateLocalBounds();
		} else {
			addLocalBounds(clip, newBounds);
		}
	}

	public static function addLocalBounds(clip : DisplayObject, bounds : Bounds) : Void {
		if (untyped clip.mask != null ||  clip.alphaMask != null || clip.scrollRect != null || clip.calculateLocalBounds == null) {
			return;
		}

		var localBounds : Bounds = untyped clip.localBounds;

		if (localBounds.minX > bounds.minX || localBounds.minY > bounds.minY || localBounds.maxX < bounds.maxX || localBounds.maxY < bounds.maxY) {
			var currentBounds = new Bounds();

			if (clip.parent != null && localBounds.minX != Math.POSITIVE_INFINITY) {
				applyLocalBoundsTransform(clip, currentBounds);
			}

			localBounds.minX = Math.min(localBounds.minX, bounds.minX);
			localBounds.minY = Math.min(localBounds.minY, bounds.minY);
			localBounds.maxX = Math.max(localBounds.maxX, bounds.maxX);
			localBounds.maxY = Math.max(localBounds.maxY, bounds.maxY);

			if (clip.parent != null) {
				var newBounds = applyLocalBoundsTransform(clip);
				if (!isEqualBounds(currentBounds, newBounds)) {
					replaceLocalBounds(clip.parent, currentBounds, newBounds);
				}
			}
		}
	}

	public static function removeLocalBounds(clip : DisplayObject, bounds : Bounds) : Void {
		if (untyped clip.mask != null || clip.alphaMask != null || clip.scrollRect != null || clip.calculateLocalBounds == null) {
			return;
		}

		var localBounds = untyped clip.localBounds;

		if (localBounds.minX == bounds.minX || localBounds.minY == bounds.minY || localBounds.maxX == bounds.maxX || localBounds.maxY == bounds.maxY) {
			untyped clip.calculateLocalBounds();
		}
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


			container.minX = Math.min(Math.min(x[0], x[1]), Math.min(x[2], x[3]));
			container.minY = Math.min(Math.min(y[0], y[1]), Math.min(y[2], y[3]));
			container.maxX = Math.max(Math.max(x[0], x[1]), Math.max(x[2], x[3]));
			container.maxY = Math.max(Math.max(y[0], y[1]), Math.max(y[2], y[3]));
		} else {
			var x = [
				bounds.minX + transform.tx,
				bounds.maxX + transform.tx
			];

			var y = [
				bounds.minY + transform.ty,
				bounds.maxY + transform.ty
			];

			container.minX = Math.min(x[0], x[1]);
			container.minY = Math.min(y[0], y[1]);
			container.maxX = Math.max(x[0], x[1]);
			container.maxY = Math.max(y[0], y[1]);
		}

		return container;
	}

	public static function applyInvertedTransform(bounds : Bounds, transform : Matrix, ?container : Bounds) : Bounds {
		if (container == null) {
			container = new Bounds();
		}

		if (transform.a != 1 || transform.b != 0 || transform.c != 0 || transform.d != 1) {
			var x = [
				(transform.a != 0 ? bounds.minX / transform.a : 0) + (transform.c != 0 ? bounds.minY / transform.c : 0) - transform.tx,
				(transform.a != 0 ? bounds.minX / transform.a : 0) + (transform.c != 0 ? bounds.maxY / transform.c : 0) - transform.tx,
				(transform.a != 0 ? bounds.maxX / transform.a : 0) + (transform.c != 0 ? bounds.maxY / transform.c : 0) - transform.tx,
				(transform.a != 0 ? bounds.maxX / transform.a : 0) + (transform.c != 0 ? bounds.minY / transform.c : 0) - transform.tx
			];

			var y = [
				(transform.b != 0 ? bounds.minX / transform.b : 0) + (transform.d != 0 ? bounds.minY / transform.d : 0) - transform.ty,
				(transform.b != 0 ? bounds.minX / transform.b : 0) + (transform.d != 0 ? bounds.maxY / transform.d : 0) - transform.ty,
				(transform.b != 0 ? bounds.maxX / transform.b : 0) + (transform.d != 0 ? bounds.maxY / transform.d : 0) - transform.ty,
				(transform.b != 0 ? bounds.maxX / transform.b : 0) + (transform.d != 0 ? bounds.minY / transform.d : 0) - transform.ty
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
		return bounds1.minX == bounds2.minX && bounds1.minY == bounds2.minY && bounds1.maxX == bounds2.maxX && bounds1.maxY == bounds2.maxY;
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

			newViewBounds.minX = Math.max(viewBounds.minX, Math.min(untyped clip.mask.localBounds.minX, untyped clip.mask.localBounds.maxX) + clip.mask.x);
			newViewBounds.minY = Math.max(viewBounds.minY, Math.min(untyped clip.mask.localBounds.minY, untyped clip.mask.localBounds.maxY) + clip.mask.y);
			newViewBounds.maxX = Math.min(viewBounds.maxX, Math.max(untyped clip.mask.localBounds.minX, untyped clip.mask.localBounds.maxX) + clip.mask.x);
			newViewBounds.maxY = Math.min(viewBounds.maxY, Math.max(untyped clip.mask.localBounds.minY, untyped clip.mask.localBounds.maxY) + clip.mask.y);

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

		if (!clip.visible && untyped !clip.transformChanged) {
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
		var nativeWidget : js.html.CanvasElement = untyped clip.nativeWidget;

		if (untyped clip.isCanvas && nativeWidget != null) {
			updateNativeWidgetMetrics(clip);

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