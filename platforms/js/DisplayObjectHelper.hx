import js.Browser;

import pixi.core.display.DisplayObject;
import pixi.core.display.Container;
import pixi.core.display.Bounds;
import pixi.core.display.TransformBase;
import pixi.core.math.Matrix;

class DisplayObjectHelper {
	public static var Redraw : Bool = Util.getParameter("redraw") != null ? Util.getParameter("redraw") == "1" : false;
	public static var RenderContainers : Bool = false;

	private static var InvalidateStage : Bool = true;

	public static inline function lockStage() {
		InvalidateStage = false;
	}

	public static inline function unlockStage() {
		InvalidateStage = true;
	}

	public static function invalidateStage(clip : DisplayObject) : Void {
		if (InvalidateStage && getClipWorldVisible(clip) && untyped clip.stage != null) {
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

	public static function invalidateStageByParent(clip : DisplayObject) : Void {
		if (InvalidateStage && clip.parent != null && getClipWorldVisible(clip.parent)) {
			invalidateStage(clip.parent);
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
		if (clip.visible) {
			untyped clip.localTransformChanged = true;
			untyped clip.childrenTransformChanged = true;

			if (InvalidateStage) {
				invalidateParentTransform(clip);
			}

			invalidateWorldTransform(clip);
		}
	}

	public static function invalidateWorldTransform(clip : DisplayObject) : Void {
		if (clip.visible && !untyped clip.worldTransformChanged && clip.parent != null) {
			untyped clip.worldTransformChanged = true;
			untyped clip.transformChanged = true;

			var children : Array<Dynamic> = untyped clip.children;
			if (children != null) {
				for (child in children) {
					if (child.visible) {
						invalidateWorldTransform(child);
					}
				}
			}
		}
	}

	public static function invalidateParentTransform(clip : DisplayObject, ?invalidateBounds : Bool = true) : Void {
		if (clip.visible && !untyped clip.transformChanged) {
			untyped clip.transformChanged = true;
			untyped clip.childrenTransformChanged = true;

			if (clip.parent != null && !untyped clip.parent.transformChanged) {
				invalidateParentTransform(
					clip.parent,
					invalidateBounds && (untyped clip.mask != null || clip.alphaMask != null || untyped clip.scrollRect != null)
				);
			} else {
				invalidateStage(clip);
			}
		}
	}

	public static function invalidateVisible(clip : DisplayObject, ?updateAccess : Bool = true) : Void {
		var clipVisible = clip.parent != null && untyped clip._visible && getClipVisible(clip.parent);
		var visible = clip.parent != null && getClipWorldVisible(clip.parent) && (untyped clip.isMask || (clipVisible && clip.renderable));

		if (untyped clip.clipVisible != clipVisible || clip.visible != visible) {
			untyped clip.clipVisible = clipVisible;
			clip.visible = visible;

			var updateAccessWidget = updateAccess && untyped clip.accessWidget != null;

			var children : Array<Dynamic> = untyped clip.children;
			if (children != null) {
				for (child in children) {
					invalidateVisible(child, updateAccess && !updateAccessWidget);
				}
			}

			if (clip.interactive && !getClipWorldVisible(clip)) {
				clip.emit("pointerout");
			}

			if (updateAccessWidget) {
				untyped clip.accessWidget.updateDisplay();
			}

			if (clip.visible) {
				invalidateTransform(clip);
			} else {
				if (RenderSupportJSPixi.DomRenderer) {
					untyped updateNativeWidgetDisplay(clip);
				}

				if (clip.parent != null && clip.parent.visible) {
					invalidateStage(clip.parent);
				}
			}
		}
	}

	public static function invalidateInteractive(clip : DisplayObject, ?interactiveChildren : Bool = false) : Void {
		clip.interactive = clip.listeners("pointerout").length > 0 || clip.listeners("pointerover").length > 0;
		clip.interactiveChildren = clip.interactive || interactiveChildren;

		if (clip.interactive) {
			if (RenderSupportJSPixi.DomInteractions) {
				untyped clip.isNativeWidget = true;
				invalidateTransform(clip);

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

	public static inline function getClipWorldVisible(clip : DisplayObject) : Bool {
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

			clip.addChild(scrollRect);
			setClipMask(clip, scrollRect);
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
				untyped clip.isNativeWidget = true;
			}

			invalidateTransform(clip);
			removeNativeWidget(maskContainer);
		} else {
			invalidateStage(clip);
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
			});
		} else {
			disp = fn();
		}

		clip.once("removed", function () {
			disp();
			onAdded(clip, fn);
		});
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
				if (clip.visible) {
					updateNativeWidgetTransformMatrix(clip);
					updateNativeWidgetOpacity(clip);
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

				if (parentNativeWidget != null && parentNativeWidget.worldAlpha > 0) {
					alpha = alpha / parentNativeWidget.worldAlpha;
				}
			}

			if (alpha != 1) {
				nativeWidget.style.opacity = alpha;
			} else {
				nativeWidget.style.opacity = null;
			}
		}
	}

	public static function updateNativeWidgetMask(clip : DisplayObject, ?worldTransform : Bool) {
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
					nativeWidget.scrollTo(viewBounds.minX, viewBounds.minY);
				};
				nativeWidget.onscroll = function() { scrollFn(); Native.defer(scrollFn); };
				scrollFn();
			} else if (scrollRect != null) {
				nativeWidget.style.width = '${scrollRect.width}px';
				nativeWidget.style.height = '${scrollRect.height}px';

				nativeWidget.style.overflow = "hidden";
				var scrollFn = function() {
					nativeWidget.scrollTo(scrollRect.x, scrollRect.y);
				};
				nativeWidget.onscroll = function() { scrollFn(); Native.defer(scrollFn); };
				scrollFn();
			} else if (mask != null) {
				var graphicsData = mask.graphicsData;

				if (graphicsData != null) {
					// var transform : Dynamic = new TransformBase();

					// if (RenderContainers && false) {
					// 	mask.localTransform.copy(transform.localTransform);
					// 	mask.worldTransform.copy(transform.worldTransform);

					// 	transform.updateTransform(untyped clip.parent.transform);
					// 	transform = clip.worldTransform.copy(new Matrix()).prepend(transform.worldTransform.invert());
					// } else {
					// 	untyped mask.transform.updateLocalTransform();
					// 	transform = new Matrix();
					// }

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
							nativeWidget.scrollTo(
								untyped transform.tx + data.shape.x * transform.a + data.shape.y * transform.c,
								untyped transform.ty + data.shape.x * transform.b + data.shape.y * transform.d
							);
						};
						nativeWidget.onscroll = function() { scrollFn(); Native.defer(scrollFn); };
						scrollFn();
					} else if (data.shape.type == 2) {
						nativeWidget.style.clipPath = null;
						nativeWidget.style.width = '${data.shape.radius * 2.0 * (transform.a + transform.c)}px';
						nativeWidget.style.height = '${data.shape.radius * 2.0 * (transform.b + transform.d)}px';
						nativeWidget.style.borderRadius = '${data.shape.radius}px';

						nativeWidget.style.overflow = "hidden";
						var scrollFn = function() {
							nativeWidget.scrollTo(
								untyped transform.tx + (data.shape.x - data.shape.radius) * transform.a + (data.shape.y - data.shape.radius) * transform.c,
								untyped transform.ty + (data.shape.x - data.shape.radius) * transform.b + (data.shape.y - data.shape.radius) * transform.d
							);
						};
						nativeWidget.onscroll = function() { scrollFn(); Native.defer(scrollFn); };
						scrollFn();
					} else if (data.shape.type == 4) {
						nativeWidget.style.clipPath = null;
						nativeWidget.style.width = '${data.shape.width * transform.a + data.shape.height * transform.c}px';
						nativeWidget.style.height = '${data.shape.width * transform.b + data.shape.height * transform.d}px';
						nativeWidget.style.borderRadius = '${data.shape.radius * (transform.a + transform.c + transform.b + transform.d) / 2.0}px';

						nativeWidget.style.overflow = "hidden";
						var scrollFn = function() {
							nativeWidget.scrollTo(
								untyped transform.tx + data.shape.x * transform.a + data.shape.y * transform.c,
								untyped transform.ty + data.shape.x * transform.b + data.shape.y * transform.d
							);
						};
						nativeWidget.onscroll = function() { scrollFn(); Native.defer(scrollFn); };
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

	public static function isNativeWidget(clip : DisplayObject) : Bool {
		return untyped clip.isNativeWidget || clip.parent == null;
	}

	public static function updateNativeWidgetDisplay(clip : DisplayObject) : Void {
		if (untyped clip.updateNativeWidgetDisplay != null) {
			untyped clip.updateNativeWidgetDisplay();
		} else {
			var nativeWidget = untyped clip.nativeWidget;

			if (nativeWidget != null) {
				if (clip.visible && clip.renderable) {
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
			}
		}
	}

	public static function addNativeWidget(clip : DisplayObject) : Void {
		if (untyped clip.addNativeWidget != null) {
			untyped clip.addNativeWidget();
		} else if (RenderSupportJSPixi.DomRenderer) {
			var nativeWidget : Dynamic = untyped clip.nativeWidget;
			var parent : DisplayObject = untyped clip.parent;

			if (nativeWidget != null && parent != null && untyped parent.nativeWidget != null) {
				if (clip.visible && clip.renderable) {
					if (!isNativeWidget(clip)) {
						clip.once("graphicschanged", function() { addNativeWidget(clip); });
					} else {
						appendNativeWidget(parent, clip);

						if (!RenderContainers) {
							var children : Array<DisplayObject> = untyped clip.children;

							if (children != null) {
								for (child in children) {
									if (untyped child.nativeWidget != null && untyped child.nativeWidget.parentNode != null) {
										addNativeWidget(child);
									}
								}
							}
						}
					}
				} else {
					clip.once("transformchanged", function() { addNativeWidget(clip); });
				}
			}
		} else {
			clip.once('removed', untyped clip.deleteNativeWidget);
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
		} else if (!RenderContainers && clip.visible && clip.renderable) {
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

		if (nativeWidget != null) {
			if (isNativeWidget(clip)) {
				nativeWidget.insertBefore(childWidget, findNextNativeWidget(child, nativeWidget));
			} else {
				appendNativeWidget(clip.parent, child);
			}
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

	public static function updateLocalTransform(clip : DisplayObject) : Void {
		if (untyped !clip.childrenTransformChanged) {
			return;
		}

		if (untyped clip.localTransformChanged) {
			untyped clip.localTransformChanged = false;
			untyped clip.transform.updateLocalTransform();

			updateNativeWidget(clip);

			var children : Array<DisplayObject> = untyped clip.children;

			if (children != null) {
				for (child in children) {
					updateLocalTransform(child);
				}
			}
		}
	}

	public static function calculateLocalBounds(clip : DisplayObject) : Void {
		var localBounds : Bounds = untyped clip.localBounds;
		var children : Array<DisplayObject> = untyped clip.children;

		if (clip.mask || untyped clip.alphaMask || untyped clip.scrollRect) {
			var mask = clip.mask != null ? clip.mask : untyped clip.alphaMask ? untyped clip.alphaMask : clip.scrollRect;

			if (untyped mask.worldTransformChanged) {
				untyped mask.transform.updateLocalTransform();
			}

			var maskRect = mask.getLocalBounds();

			localBounds.minX = maskRect.x * mask.localTransform.a + maskRect.y * mask.localTransform.c + mask.localTransform.tx;
			localBounds.minY = maskRect.x * mask.localTransform.b + maskRect.y * mask.localTransform.d + mask.localTransform.ty;
			localBounds.maxX = (maskRect.x + maskRect.width) * mask.localTransform.a + (maskRect.y + maskRect.height) * mask.localTransform.c + mask.localTransform.tx;
			localBounds.maxY = (maskRect.x + maskRect.width) * mask.localTransform.b + (maskRect.y + maskRect.height) * mask.localTransform.d + mask.localTransform.ty;
		} else if (untyped clip.children != null && untyped clip.children.length > 0) {
			var firstChild = children[0];

			if (untyped firstChild.worldTransformChanged) {
				untyped firstChild.transform.updateLocalTransform();
			}

			var childRect = firstChild.getLocalBounds();

			localBounds.minX = childRect.x * firstChild.localTransform.a + childRect.y * firstChild.localTransform.c + firstChild.localTransform.tx;
			localBounds.minY = childRect.x * firstChild.localTransform.b + childRect.y * firstChild.localTransform.d + firstChild.localTransform.ty;
			localBounds.maxX = (childRect.x + childRect.width) * firstChild.localTransform.a + (childRect.y + childRect.height) * firstChild.localTransform.c + firstChild.localTransform.tx;
			localBounds.maxY = (childRect.x + childRect.width) * firstChild.localTransform.b + (childRect.y + childRect.height) * firstChild.localTransform.d + firstChild.localTransform.ty;

			for (child in children.slice(1)) {
				if (untyped child.worldTransformChanged) {
					untyped child.transform.updateLocalTransform();
				}

				childRect = child.getLocalBounds();

				localBounds.minX = Math.min(localBounds.minX, childRect.x * child.localTransform.a + childRect.y * child.localTransform.c + child.localTransform.tx);
				localBounds.minY = Math.min(localBounds.minY, childRect.x * child.localTransform.b + childRect.y * child.localTransform.d + child.localTransform.ty);
				localBounds.maxX = Math.max(localBounds.maxX, (childRect.x + childRect.width) * child.localTransform.a + (childRect.y + childRect.height) * child.localTransform.c + child.localTransform.tx);
				localBounds.maxY = Math.max(localBounds.maxY, (childRect.x + childRect.width) * child.localTransform.b + (childRect.y + childRect.height) * child.localTransform.d + child.localTransform.ty);
			}
		}
	}
}