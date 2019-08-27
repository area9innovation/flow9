import js.Browser;

import pixi.core.display.DisplayObject;
import pixi.core.display.Container;
import pixi.core.display.Bounds;
import pixi.core.display.TransformBase;
import pixi.core.math.Matrix;

class DisplayObjectHelper {
	public static var Redraw : Bool = Util.getParameter("redraw") == "1";
	public static var RenderContainers : Bool = Util.getParameter("containers") == "1" || !RenderSupportJSPixi.DomRenderer;

	private static var InvalidateStage : Bool = true;

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
		if (InvalidateStage || true) {
			invalidateParentTransform(clip);
		}

		invalidateWorldTransform(clip);
	}

	public static function invalidateWorldTransform(clip : DisplayObject, ?localTransformChanged : Bool = true) : Void {
		if (clip.parent != null) {
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
		clip.interactive = clip.listeners("pointerout").length > 0 || clip.listeners("pointerover").length > 0;
		clip.interactiveChildren = clip.interactive || interactiveChildren;

		if (clip.interactive) {
			if (RenderSupportJSPixi.DomInteractions) {
				initNativeWidget(clip);

				untyped clip.nativeWidget.onmouseover = function() {
					clip.emit("pointerover");
				}

				untyped clip.nativeWidget.onmouseout = function() {
					clip.emit("pointerout");
				}

				untyped clip.nativeWidget.style.pointerEvents = 'auto';

				untyped clip.nativeWidget.style.width = '${getWidth(clip)}px'; //todo:
				untyped clip.nativeWidget.style.height = '${getHeight(clip)}px';
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

		if (RenderSupportJSPixi.DomRenderer) {
			invalidateTransform(clip);
		} else {
			invalidateStage(clip);
		}

		untyped clip.calculateLocalBounds();
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

			clip.mask.once("removed", function () { clip.mask = null; });
		} else if (untyped clip.alphaMask != null) {
			untyped maskContainer.isMask = true;
		}

		maskContainer.once("childrenchanged", function () { setClipMask(clip, maskContainer); });
		clip.emit("graphicschanged");

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
		var worldTransform = clip.worldTransform.clone().invert();

		bounds.minX = bounds.minX * worldTransform.a + bounds.minY * worldTransform.c + worldTransform.tx;
		bounds.minY = bounds.minX * worldTransform.b + bounds.minY * worldTransform.d + worldTransform.ty;
		bounds.maxX = bounds.maxX * worldTransform.a + bounds.maxY * worldTransform.c + worldTransform.tx;
		bounds.maxY = bounds.maxX * worldTransform.b + bounds.maxY * worldTransform.d + worldTransform.ty;

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
			var nativeWidget : js.html.Element = untyped clip.nativeWidget;

			if (nativeWidget != null) {
				if (clip.visible && isNativeWidget(clip)) {
					updateNativeWidgetTransformMatrix(clip);
					updateNativeWidgetOpacity(clip);
					// updateNativeWidgetMetrics(clip);
					updateNativeWidgetMask(clip);
				}

				updateNativeWidgetDisplay(clip);
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
						alpha = 1;
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

	public static function updateNativeWidgetMask(clip : DisplayObject, ?worldTransform : Bool, ?attachScrollFn : Bool = true) {
		if (worldTransform == null) {
			worldTransform = !RenderContainers;
		}

		var nativeWidget = untyped clip.nativeWidget;

		if (nativeWidget != null) {
			var mask : FlowGraphics = clip.mask;
			var scrollRect = untyped clip.scrollRect;
			var viewBounds = untyped clip.viewBounds;

			if (viewBounds != null ) {
				nativeWidget.style.width = '${viewBounds.maxX - viewBounds.minX}px';
				nativeWidget.style.height = '${viewBounds.maxY - viewBounds.minY}px';

				nativeWidget.style.overflow = "hidden";
				var scrollFn = function() {
					if (viewBounds != null) nativeWidget.scrollTo(viewBounds.minX, viewBounds.minY);
				};
				if (attachScrollFn) nativeWidget.onscroll = function() { scrollFn(); Native.defer(scrollFn); };
				scrollFn();
			} else if (scrollRect != null) {
				nativeWidget.style.width = '${scrollRect.width}px';
				nativeWidget.style.height = '${scrollRect.height}px';

				nativeWidget.style.overflow = "hidden";
				var scrollFn = function() {
					if (scrollRect != null) nativeWidget.scrollTo(scrollRect.x, scrollRect.y);
				};
				if (attachScrollFn) nativeWidget.onscroll = function() { scrollFn(); Native.defer(scrollFn); };
				scrollFn();
			} else if (mask != null) {
				var graphicsData = mask.graphicsData;

				if (graphicsData != null) {
					var transform = new Matrix();
					var data = graphicsData[0];

					if (data.shape.type == 0) {
						nativeWidget.style.overflow = null;
						nativeWidget.onscroll = null;
						var width = getWidth(clip);
						var height = getHeight(clip);
						nativeWidget.style.width = '${width * transform.a + height * transform.c}px';
						nativeWidget.style.height = '${width * transform.b + height * transform.d}px';

						nativeWidget.style.clipPath = untyped __js__("'polygon(' + data.shape.points.map(function (p, i) {
							return i % 2 == 0 ?
								(transform.tx + p * transform.a) + 'px ' :
								'' + (transform.ty + p * transform.d) + 'px' + (i != data.shape.points.length - 1 ? ',' : '')
						}).join('') + ')'");
					} else if (data.shape.type == 1) {
						nativeWidget.style.clipPath = null;
						nativeWidget.style.width = '${data.shape.width * transform.a + data.shape.height * transform.c}px';
						nativeWidget.style.height = '${data.shape.width * transform.b + data.shape.height * transform.d}px';

						nativeWidget.style.overflow = "hidden";
						var scrollFn = function() {
							if (data != null && data.shape != null && transform != null)
								nativeWidget.scrollTo(
									untyped transform.tx + data.shape.x * transform.a + data.shape.y * transform.c,
									untyped transform.ty + data.shape.x * transform.b + data.shape.y * transform.d
								);
						};
						if (attachScrollFn) nativeWidget.onscroll = function() { scrollFn(); Native.defer(scrollFn); };
						scrollFn();
					} else if (data.shape.type == 2) {
						nativeWidget.style.clipPath = null;
						nativeWidget.style.width = '${data.shape.radius * 2.0 * (transform.a + transform.c)}px';
						nativeWidget.style.height = '${data.shape.radius * 2.0 * (transform.b + transform.d)}px';
						nativeWidget.style.borderRadius = '${data.shape.radius}px';

						nativeWidget.style.overflow = "hidden";
						var scrollFn = function() {
							if (data != null && data.shape != null && transform != null)
								nativeWidget.scrollTo(
									untyped transform.tx + (data.shape.x - data.shape.radius) * transform.a + (data.shape.y - data.shape.radius) * transform.c,
									untyped transform.ty + (data.shape.x - data.shape.radius) * transform.b + (data.shape.y - data.shape.radius) * transform.d
								);
						};
						if (attachScrollFn) nativeWidget.onscroll = function() { scrollFn(); Native.defer(scrollFn); };
						scrollFn();
					} else if (data.shape.type == 4) {
						nativeWidget.style.clipPath = null;
						nativeWidget.style.width = '${data.shape.width * transform.a + data.shape.height * transform.c}px';
						nativeWidget.style.height = '${data.shape.width * transform.b + data.shape.height * transform.d}px';
						nativeWidget.style.borderRadius = '${data.shape.radius * (transform.a + transform.c + transform.b + transform.d) / 2.0}px';

						nativeWidget.style.overflow = "hidden";
						var scrollFn = function() {
							if (data != null && data.shape != null && transform != null)
								nativeWidget.scrollTo(
									untyped transform.tx + data.shape.x * transform.a + data.shape.y * transform.c,
									untyped transform.ty + data.shape.x * transform.b + data.shape.y * transform.d
								);
						};
						if (attachScrollFn) nativeWidget.onscroll = function() { scrollFn(); Native.defer(scrollFn); };
						scrollFn();
					}  else {
						nativeWidget.style.clipPath = null;
						nativeWidget.style.overflow = null;
						nativeWidget.onscroll = null;

						trace("updateNativeWidgetMask: Unknown shape type");
						trace(data);
					}
				}
			} else {
				nativeWidget.style.clipPath = null;
				nativeWidget.style.overflow = null;
				nativeWidget.onscroll = null;
			}
		}
	}

	public static function updateNativeWidgetMetrics(clip : DisplayObject) : Void {
		var nativeWidget = untyped clip.nativeWidget;
		var localBounds = untyped clip.localBounds;

		if (nativeWidget != null && localBounds.minX != Math.POSITIVE_INFINITY) {
			nativeWidget.style.width = '${localBounds.maxX}px';
			nativeWidget.style.height = '${localBounds.maxY}px';
			nativeWidget.style.overflow = 'hidden';

			nativeWidget.setAttribute('minX', Std.string(localBounds.minX));
			nativeWidget.setAttribute('minY', Std.string(localBounds.minY));
			nativeWidget.setAttribute('maxX', Std.string(localBounds.maxX));
			nativeWidget.setAttribute('maxY', Std.string(localBounds.maxY));
		}
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

					if (nativeWidget.parentNode == null && isNativeWidget(clip) && clip.parent != null) {
						addNativeWidget(clip);
					}
				} else if (!RenderContainers || clip.parent == null || (clip.parent.visible && clip.parent.renderable)) {
					nativeWidget.style.display = "none";

					if (nativeWidget.parentNode != null && untyped clip.accessWidget == null) { // todo: questionable optimization
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
		if (isNativeWidget(clip) && untyped clip.nativeWidget.parentNode == parent) {
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
			nativeWidget.insertBefore(childWidget, findNextNativeWidget(child, nativeWidget));
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
		if (clip.mask != null || untyped clip.alphaMask != null || clip.scrollRect != null || newBounds.minX == Math.POSITIVE_INFINITY || isEqualBounds(currentBounds, newBounds)) {
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
		if (clip.mask != null || untyped clip.alphaMask != null || clip.scrollRect != null) {
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
					invalidateTransform(clip);
				}
			}
		}
	}

	public static function removeLocalBounds(clip : DisplayObject, bounds : Bounds) : Void {
		if (clip.mask != null || untyped clip.alphaMask != null || clip.scrollRect != null) {
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

		untyped clip.transform.updateLocalTransform();
		var transform = clip.localTransform;
		var bounds = untyped clip.localBounds;

		container.minX = bounds.minX * transform.a + bounds.minY * transform.c + transform.tx;
		container.minY = bounds.minX * transform.b + bounds.minY * transform.d + transform.ty;
		container.maxX = bounds.maxX * transform.a + bounds.maxY * transform.c + transform.tx;
		container.maxY = bounds.maxX * transform.b + bounds.maxY * transform.d + transform.ty;

		if (container.minX > container.maxX) {
			var tempX = container.minX;
			container.minX = container.maxX;
			container.maxX = tempX;
		}

		if (container.minY > container.maxY) {
			var tempY = container.minY;
			container.minY = container.maxY;
			container.maxY = tempY;
		}

		return container;
	}

	public static function isEqualBounds(bounds1 : Bounds, bounds2 : Bounds) : Bool {
		return bounds1.minX == bounds2.minX && bounds1.minY == bounds2.minY && bounds1.maxX == bounds2.maxX && bounds1.maxY == bounds2.maxY;
	}

	public static function initNativeWidget(clip : DisplayObject) : Void {
		if (RenderSupportJSPixi.DomRenderer && untyped !clip.isNativeWidget) {
			untyped clip.isNativeWidget = true;
			if (untyped clip.nativeWidget == null) {
				untyped clip.createNativeWidget();
			}

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
			newViewBounds.minX = Math.max(viewBounds.minX, untyped clip.scrollRect.x);
			newViewBounds.minY = Math.max(viewBounds.minY, untyped clip.scrollRect.y);
			newViewBounds.maxX = Math.min(viewBounds.maxX, untyped clip.scrollRect.width + untyped clip.scrollRect.x);
			newViewBounds.maxY = Math.min(viewBounds.maxY, untyped clip.scrollRect.height + untyped clip.scrollRect.y);

			viewBounds = newViewBounds;
		}

		setClipRenderable(
			clip,
			!viewBounds.isEmpty() && viewBounds.maxX > localBounds.minX && viewBounds.minX < localBounds.maxX && viewBounds.maxY > localBounds.minY && viewBounds.minY < localBounds.maxY
		);

		if (!clip.visible && untyped !clip.transformChanged) {
			return;
		}

		var children : Array<DisplayObject> = untyped clip.children;
		if (children != null) {
			for (child in children) {
				untyped child.transform.updateLocalTransform();
				var transform = untyped child.localTransform.clone().invert();

				var newViewBounds = new Bounds();
				newViewBounds.minX = viewBounds.minX * transform.a + viewBounds.minY * transform.c + transform.tx;
				newViewBounds.minY = viewBounds.minX * transform.b + viewBounds.minY * transform.d + transform.ty;
				newViewBounds.maxX = viewBounds.maxX * transform.a + viewBounds.maxY * transform.c + transform.tx;
				newViewBounds.maxY = viewBounds.maxX * transform.b + viewBounds.maxY * transform.d + transform.ty;

				if (newViewBounds.minX > newViewBounds.maxX) {
					var tempX = newViewBounds.minX;
					newViewBounds.minX = newViewBounds.maxX;
					newViewBounds.maxX = tempX;
				}

				if (newViewBounds.minY > newViewBounds.maxY) {
					var tempY = newViewBounds.minY;
					newViewBounds.minY = newViewBounds.maxY;
					newViewBounds.maxY = tempY;
				}

				invalidateRenderable(child, newViewBounds);
			}
		}
	}
}