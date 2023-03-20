import js.Browser;
import js.html.Element;

import pixi.core.math.Matrix;
import pixi.core.display.DisplayObject;
import pixi.interaction.EventEmitter;
import pixi.core.math.Point;

using DisplayObjectHelper;

class AccessWidgetTree extends EventEmitter {
	@:isVar public var id(get, set) : Int;
	@:isVar public var accessWidget(get, set) : AccessWidget;
	@:isVar public var parent(get, set) : AccessWidgetTree;
	public var children : Map<Int, AccessWidgetTree> = new Map<Int, AccessWidgetTree>();
	public var childrenSize : Int = 0;
	public var nextId : Int = 0;
	@:isVar public var childrenChanged(get, set) : Bool;
	@:isVar public var changed(get, set) : Bool;
	public var zorder : Int = 0;
	public var childrenTabIndex : Int = 1;

	public function new(id : Int, ?accessWidget : AccessWidget, ?parent : AccessWidgetTree) {
		super();

		this.changed = false;
		this.childrenChanged = false;
		this.id = id;
		this.accessWidget = accessWidget;
		this.parent = parent;
	}

	public function get_id() : Int {
		return id;
	}

	public function set_id(id : Int) : Int {
		if (this.id != id) {
			var parent = parent;

			if (parent != null) {
				parent.removeChild(this, false);
			}

			this.id = id;
			changed = true;

			if (parent != null) {
				parent.addChild(this);
			}
		}

		return this.id;
	}

	public function get_accessWidget() : AccessWidget {
		return accessWidget;
	}

	public function set_accessWidget(accessWidget : AccessWidget) : AccessWidget {
		if (this.accessWidget != accessWidget) {
			this.accessWidget = accessWidget;

			if (this.accessWidget != null) {
				this.accessWidget.parent = this;
				this.changed = true;
			}
		}

		return this.accessWidget;
	}

	public function get_parent() : AccessWidgetTree {
		return parent;
	}

	public function set_parent(parent : AccessWidgetTree) : AccessWidgetTree {
		if (this.parent != parent) {
			this.parent = parent;

			if (this.parent != null) {
				this.parent.updateZorder();
			}
		}

		return this.parent;
	}

	public function get_changed() : Bool {
		return changed;
	}

	public function set_changed(changed : Bool) : Bool {
		if (this.changed != changed) {
			this.changed = changed;

			if (this.changed && parent != null) {
				parent.childrenChanged = true;
			}
		}

		return this.changed;
	}

	public function get_childrenChanged() : Bool {
		return childrenChanged;
	}

	public function set_childrenChanged(childrenChanged : Bool) : Bool {
		if (this.childrenChanged != childrenChanged) {
			this.childrenChanged = childrenChanged;

			if (this.childrenChanged && parent != null) {
				parent.childrenChanged = true;
			}
		}

		return this.childrenChanged;
	}

	private function getZorder() : Int {
		if (zorder != null) {
			return zorder;
		} else if (parent != null) {
			return parent.getZorder();
		} else {
			return AccessWidget.tree.zorder;
		}
	}

	public function updateZorder() : Bool {
		var previousZOrder = zorder;
		zorder = accessWidget != null && accessWidget.zorder != null ? accessWidget.zorder : null;

		for (child in children) {
			if (child.zorder > zorder || zorder == null) {
				zorder = child.zorder;
			}
		}

		if (zorder == null) {
			updateDisplay();

			return true;
		} else {
			if (previousZOrder != zorder) {
				if (parent == null || !parent.updateZorder()) {
					updateDisplay();
				}

				return true;
			} else {
				return false;
			}
		}
	}

	public function getAccessWidgetTransform(append : Bool = true) : Matrix {
		if (accessWidget != null && accessWidget.clip != null && accessWidget.clip.parent != null && untyped accessWidget.clip.nativeWidget != null) {
			if (append && parent != null) {
				var parentTransform = parent.getAccessWidgetTransform(false);
				return accessWidget.clip.worldTransform.clone().append(parentTransform.clone().invert());
			} else {
				return accessWidget.clip.worldTransform;
			}
		} else if (!append && parent != null) {
			return parent.getAccessWidgetTransform();
		} else {
			return new Matrix();
		}
	}

	private function getWidth() : Float {
		if (accessWidget != null) {
			var clip : DisplayObject = accessWidget.clip;

			if (untyped clip.getWidth == null) {
				var bounds = clip.getBounds(true);
				return bounds.width * clip.worldTransform.a + bounds.height * clip.worldTransform.c;
			} else {
				return untyped clip.getWidth();
			}
		} else {
			return 0;
		}
	}

	private function getHeight() : Float {
		if (accessWidget != null) {
			var clip : DisplayObject = accessWidget.clip;

			if (untyped clip.getHeight == null) {
				var bounds = clip.getBounds(true);
				return bounds.width * clip.worldTransform.b + bounds.height * clip.worldTransform.d;
			} else {
				return untyped clip.getHeight();
			}
		} else {
			return 0;
		}
	}

	public function updateDisplay() : Void {
		if (RenderSupport.RendererType != "html" &&
			(accessWidget == null || accessWidget.clip != null || !accessWidget.clip.isHTMLRenderer())) {
			updateTransform();

			for (child in children) {
				child.updateDisplay();
			}
		}
	}

	public function updateTransform() : Void {
		if (accessWidget != null && accessWidget.clip != null && !accessWidget.clip.isHTMLRenderer()) {
			var nativeWidget : Dynamic = accessWidget.element;
			var clip : DisplayObject = accessWidget.clip;

			if (nativeWidget != null) {
				if (nativeWidget.style.zIndex == null || nativeWidget.style.zIndex == "") {
					var localStage : FlowContainer = untyped clip.stage;

					if (localStage != null) {
						var zIndex = 1000 * localStage.parent.children.indexOf(localStage) +
							nativeWidget.className == "droparea" ? AccessWidget.zIndexValues.droparea : AccessWidget.zIndexValues.nativeWidget;
						nativeWidget.style.zIndex = Std.string(zIndex);
					}
				}

				if (DisplayObjectHelper.DebugAccessOrder) {
					nativeWidget.setAttribute("worldTransform", 'matrix(${clip.worldTransform.a}, ${clip.worldTransform.b}, ${clip.worldTransform.c}, ${clip.worldTransform.d}, ${clip.worldTransform.tx}, ${clip.worldTransform.ty})');
					nativeWidget.setAttribute("zorder", '${zorder}');
					nativeWidget.setAttribute("nodeindex", '${accessWidget.nodeindex}');
				}

				if (getZorder() >= AccessWidget.tree.zorder && clip.getClipVisible()) {
					nativeWidget.style.display = "block";
					nativeWidget.style.opacity = clip.worldAlpha;
				} else {
					nativeWidget.style.display = "none";
					return;
				}

				clip.updateNativeWidget();
			}
		}
	}

	public function isFocusable() : Bool {
		return accessWidget != null && accessWidget.enabled && accessWidget.element != null && accessWidget.clip != null
			&& accessWidget.clip.getClipVisible() && accessWidget.element.tabIndex >= 0;
	}

	public function getFirstAccessWidget() : AccessWidget {
		if (parent != null || this == AccessWidget.tree) {
			for (i in -1...nextId) {
				var child = children.get(i);

				if (child != null) {
					if (child.isFocusable()) {
						return child.accessWidget;
					} else {
						var accessWidget = child.getFirstAccessWidget();

						if (accessWidget != null) {
							return accessWidget;
						}
					}
				}
			}
		}

		return null;
	}

	public function getLastAccessWidget() : AccessWidget {
		if (parent != null || this == AccessWidget.tree) {
			for (i in 1...(nextId + 1)) {
				var child = children.get(nextId - i);

				if (child != null) {
					if (child.isFocusable()) {
						return child.accessWidget;
					} else {
						var accessWidget = child.getLastAccessWidget();

						if (accessWidget != null) {
							return accessWidget;
						}
					}
				}
			}
		}

		return null;
	}

	public function getPreviousAccessWidget() : AccessWidget {
		if (parent != null) {
			if (id != -1) {
				for (i in 1...(id + 2)) {
					var child = parent.children.get(id - i);

					if (child != null) {
						var accessWidget = child.getLastAccessWidget();

						if (accessWidget != null) {
							return accessWidget;
						}

						if (child.isFocusable()) {
							return child.accessWidget;
						}
					}
				}
			}

			return parent.getPreviousAccessWidget();
		}

		return null;
	}

	public function getNextAccessWidget() : AccessWidget {
		if (parent != null) {
			for (i in (id + 1)...parent.nextId) {
				var child = parent.children.get(i);

				if (child != null) {
					var accessWidget = child.getFirstAccessWidget();

					if (accessWidget != null) {
						return accessWidget;
					}

					if (child.isFocusable()) {
						return child.accessWidget;
					}
				}
			}

			return parent.getNextAccessWidget();
		}

		return null;
	}

	public function getChild(id : Int) : AccessWidgetTree {
		return children.get(id);
	}

	public function addChild(child : AccessWidgetTree) : Void {
		if (child.parent != null) {
			child.parent.removeChild(child, false);
		}

		var previousChild = getChild(child.id);

		if (previousChild == child) {
			return;
		}

		if (previousChild != null) {
			if (previousChild.accessWidget != null && previousChild.accessWidget != child.accessWidget) {
				previousChild.id = nextId;

				nextId++;
				childrenSize++;
				children.set(child.id, child);
				child.parent = this;
				child.emit("added");
			} else {
				previousChild.accessWidget = child.accessWidget;
			}
		} else {
			if (child.id >= nextId) {
				nextId = child.id + 1;
			}

			childrenSize++;
			children.set(child.id, child);
			child.parent = this;
			child.emit("added");
		}

		updateZorder();

		childrenChanged = true;
	}

	public function removeChild(child : AccessWidgetTree, ?destroy : Bool = true) : Void {
		if (destroy && child.accessWidget != null) {
			child.accessWidget.element = null;
			untyped child.accessWidget.clip.accessWidget = null;
		}

		if (children.get(child.id) == child) {
			children.remove(child.id);

			if (nextId == child.id + 1) {
				nextId--;
			}

			childrenSize--;
			child.parent = null;
			child.emit("removed");
		}

		if (destroy && childrenSize == 0 && accessWidget == null && parent != null) {
			parent.removeChild(this);
		} else {
			updateZorder();
		}

		childrenChanged = true;
	}
}

class AccessWidget extends EventEmitter {
	// ARIA-role to HTML tag map
	private static var accessRoleMap : Map<String, String> = [
		"button" => "button",
		"checkbox" => "button",
		"combobox" => "button",
		"slider" => "button",
		"alertdialog" => "dialog",
		"dialog" => "dialog",
		"radio" => "button",
		"tab" => "button",
		"link" => "button",
		"banner" => "header",
		"main" => "section",
		"navigation" => "nav",
		"contentinfo" => "footer",
		"form" => "form",
		"textbox" => "input",
		"switch" => "button",
		"menuitem" => "button",
		"option" => "button",
		"table" => "table",
		"row" => "tr",
		"columnheader" => "th",
		"cell" => "td"
	];

	public static var zIndexValues = {
		"canvas" : 0,
		"droparea" : 1,
		"nativeWidget" : 2
	};

	public static var tree : AccessWidgetTree = new AccessWidgetTree(0);

	public var clip : DisplayObject;
	public var tagName : String = "div";
	private var keepTagName : Bool = false;
	@:isVar public var element(get, set) : Element;

	@:isVar public var nodeindex(get, set) : Array<Int>;
	@:isVar public var zorder(get, set) : Int;

	@:isVar public var tabindex(get, set) : Int;
	public var role(get, set) : String;
	public var description(get, set) : String;
	public var id(get, set) : String;
	@:isVar public var enabled(get, set) : Bool;
	public var autocomplete(get, set) : String;
	public var focused : Bool = false;

	@:isVar public var parent(get, set) : AccessWidgetTree;

	public function new(clip : DisplayObject, element : Element, ?nodeindex : Array<Int>, ?zorder : Int) {
		super();

		this.clip = clip;
		this.tabindex = -1;
		this.element = element;
		this.nodeindex = nodeindex;
		this.zorder = zorder;
		this.enabled = true;

		clip.onAdded(function() {
			if (untyped clip.accessWidget == this) {
				addAccessWidget(this);
			}

			return function() {
				removeAccessWidget(this);
			}
		});
	}

	public static inline function createAccessWidget(clip : DisplayObject, attributes : Map<String, String>) : Void {
		if (clip.isHTMLRenderer()) {
			return;
		}

		if (untyped clip.accessWidget != null) {
			removeAccessWidget(untyped clip.accessWidget);
		}

		var tagName = attributes.get("tag");

		if (tagName == null) {
			tagName = accessRoleMap.get(attributes.get("role"));
		}

		if (tagName == null) {
			tagName = "div";
		}

		untyped clip.accessWidget = new AccessWidget(clip, Browser.document.createElement(tagName));
		untyped clip.accessWidget.addAccessAttributes(attributes);
	}

	public function get_element() : Element {
		return element;
	}

	public inline function hasTabIndex() : Bool {
		return this.tagName == "button" || this.tagName == "input" || this.tagName == "textarea" || this.role == "slider" || this.tagName == "iframe";
	}

	public function set_element(element : Element) : Element {
		if (this.element != element) {
			if (this.element != null && this.element.parentNode != null &&
				(element != null || (RenderSupport.RendererType != "html" && (this.clip == null || !this.clip.isHTMLRenderer())))) {
				this.element.parentNode.removeChild(this.element);

				untyped __js__("delete this.element;");
			}

			this.element = element;

			if (this.element != null) {
				this.tagName = element.tagName.toLowerCase();
				if (this.clip != null) {
					untyped this.clip.keepNativeWidget = hasTabIndex() || this.tagName == "iframe" || this.role == "iframe";
					this.clip.updateKeepNativeWidgetChildren();
				}

				var onFocus = function () {
					focused = true;
					if (RenderSupport.EnableFocusFrame) this.element.classList.add("focused");

					if (RenderSupport.Animating) {
						RenderSupport.once(
							"stagechanged",
							function() {
								if (focused) {
									if (this.element != null) this.element.focus();
									if (RenderSupport.EnableFocusFrame) this.element.classList.add("focused");
								}
							}
						);

						return;
					};

					clip.emit("focus");

					var parent : DisplayObject = clip.parent;

					if (parent != null) {
						parent.emitEvent("childfocused", clip);
					};
				};

				var onBlur = function () {
					if (untyped RenderSupport.Animating || clip.preventBlur) {
						RenderSupport.once(
							"stagechanged",
							function() {
								if (focused) {
									if (this.element != null) this.element.focus();
									if (RenderSupport.EnableFocusFrame) this.element.classList.add("focused");
								}
							}
						);

						return;
					};

					RenderSupport.once("drawframe", function() {
						focused = false;
						if (this.element != null) this.element.classList.remove("focused");
						clip.emit("blur");
					});
				};

				if (this.element.tagName.toLowerCase() == "iframe") {
					this.element.tabIndex = tabindex;
					var fn = function () {};

					fn = function () {
						RenderSupport.defer(function () {
							if (Browser.document.activeElement == this.element) {
								onFocus();
							} else {
								onBlur();

								Browser.window.removeEventListener("focus", fn);
								Browser.window.removeEventListener("blur", fn);
							}
						});
					}

					this.element.addEventListener("mouseenter", function () {
						if (Browser.document.activeElement == null || Browser.document.activeElement == Browser.document.body) {
							Browser.window.focus();
						}

						Browser.window.addEventListener("focus", fn);
						Browser.window.addEventListener("blur", fn);
					});

					this.element.addEventListener("mouseleave", function () {
						if (!focused) {
							Browser.window.removeEventListener("focus", fn);
							Browser.window.removeEventListener("blur", fn);
						}
					});
				};

				// Add focus notification. Used for focus control
				this.element.addEventListener("focus", onFocus);
				// Add blur notification. Used for focus control
				this.element.addEventListener("blur", onBlur);

				if (this.tagName == "button") {
					this.element.classList.remove("accessElement");
					this.element.classList.add("accessButton");
				} else if (this.tagName == "div") {
					this.element.classList.remove("accessButton");
					this.element.classList.add("accessElement");
				} else if (this.tagName == "form") {
					this.element.classList.remove("accessButton");
					this.element.classList.remove("accessElement");
					this.element.onsubmit = function() { return false; };
				}

				if (hasTabIndex() && tabindex < 0) {
					tabindex = 0;
				}

				if (parent != null) {
					parent.changed = true;
				}
			}
		}

		return this.element;
	}

	public function get_nodeindex() : Array<Int> {
		return nodeindex;
	}

	public function set_nodeindex(nodeindex : Array<Int>) : Array<Int> {
		if (this.nodeindex != nodeindex) {
			this.nodeindex = nodeindex;

			if (clip.parent != null) {
				addAccessWidget(this);
			}
		}

		return this.nodeindex;
	}

	public function get_zorder() : Int {
		return zorder;
	}

	public function set_zorder(zorder : Int) : Int {
		if (this.zorder != zorder) {
			this.zorder = zorder;

			updateZorder();
		}

		return this.zorder;
	}

	public function get_tabindex() : Int {
		return this.tabindex;
	}

	public function set_tabindex(tabindex : Int) : Int {
		if (this.tabindex != tabindex) {
			this.tabindex = tabindex;

			if (enabled && hasTabIndex()) {
				element.tabIndex = tabindex;
			}
		}

		return this.tabindex;
	}

	public function get_role() : String {
		return element.getAttribute("role");
	}

	public function set_role(role : String) : String {
		if (role != "" && role != "iframe") {
			element.setAttribute("role", role);
		} else {
			element.removeAttribute("role");
		}

		if (this.clip != null) {
			untyped this.clip.keepNativeWidget = hasTabIndex() || this.tagName == "iframe" || role == "iframe";
			this.clip.updateKeepNativeWidgetChildren();
		}

		if (RenderSupport.RendererType == "html" && !this.keepTagName && (this.clip == null || this.clip.isHTMLRenderer()) && accessRoleMap.get(role) != null &&
			accessRoleMap.get(role) != "input" && element.tagName.toLowerCase() != accessRoleMap.get(role)) {
			var newElement = Browser.document.createElement(accessRoleMap.get(role));

			for (attr in element.attributes) {
				newElement.setAttribute(attr.name, attr.value);
			}

			for (child in element.childNodes) {
				newElement.appendChild(child);
			}

			if (element.parentNode != null) {
				element.parentNode.insertBefore(newElement, element);
				element.parentNode.removeChild(element);
			}

			untyped clip.nativeWidget = newElement;
			element = newElement;
		}

		// Sets events
		if (accessRoleMap.get(role) == "button") {
			element.onclick = function(e : Dynamic) {
				if (e.target == element && (e.detail == 0 || e.detail == 1 && RenderSupport.IsFullScreen)) {
					if (untyped clip.accessCallback != null) {
						untyped clip.accessCallback();
					}
				}
			};

			var stage = RenderSupport.PixiStage;

			var onpointerdown = function(e : Dynamic) {
				// Prevent default drop focus on canvas
				// Works incorrectly in Edge
				e.preventDefault();

				var rootPos = RenderSupport.getRenderRootPos(stage);
				var mousePos = RenderSupport.getMouseEventPosition(e, rootPos);

				if (e.touches != null) {
					RenderSupport.TouchPoints = e.touches;
					RenderSupport.emit("touchstart");

					if (e.touches.length == 1) {
						var touchPos = RenderSupport.getMouseEventPosition(e.touches[0], rootPos);
						RenderSupport.setMousePosition(touchPos);
						if (RenderSupport.MouseUpReceived) stage.emit("mousedown");
					} else if (e.touches.length > 1) {
						var touchPos1 = RenderSupport.getMouseEventPosition(e.touches[0], rootPos);
						var touchPos2 = RenderSupport.getMouseEventPosition(e.touches[1], rootPos);
						GesturesDetector.processPinch(touchPos1, touchPos2);
					}
				} else if (!Platform.isMobile || e.pointerType == null || e.pointerType != 'touch' || !RenderSupport.isMousePositionEqual(mousePos)) {
					RenderSupport.setMousePosition(mousePos);

					if (e.which == 3 || e.button == 2) {
						stage.emit("mouserightdown");
					} else if (e.which == 2 || e.button == 1) {
						stage.emit("mousemiddledown");
					} else if (e.which == 1 || e.button == 0) {
						if (RenderSupport.MouseUpReceived) stage.emit("mousedown");
					}
				}

				e.preventDefault();
				e.stopPropagation();
			};

			var onpointerup = function(e : Dynamic) {
				var rootPos = RenderSupport.getRenderRootPos(stage);
				var mousePos = RenderSupport.getMouseEventPosition(e, rootPos);

				if (e.touches != null) {
					RenderSupport.TouchPoints = e.touches;
					RenderSupport.emit("touchend");

					GesturesDetector.endPinch();

					if (e.touches.length == 0) {
						if (!RenderSupport.MouseUpReceived) stage.emit("mouseup");
					}
				} else if (!Platform.isMobile || e.pointerType == null || e.pointerType != 'touch' || !RenderSupport.isMousePositionEqual(mousePos)) {
					RenderSupport.setMousePosition(mousePos);

					if (e.which == 3 || e.button == 2) {
						stage.emit("mouserightup");
					} else if (e.which == 2 || e.button == 1) {
						stage.emit("mousemiddleup");
					} else if (e.which == 1 || e.button == 0) {
						if (!RenderSupport.MouseUpReceived) stage.emit("mouseup");
					}
				}

				e.preventDefault();
				e.stopPropagation();
			};

			if (Platform.isMobile) {
				if (role == "button") {
					if (Platform.isAndroid || (Platform.isSafari && Platform.browserMajorVersion >= 13)) {
						element.onpointerdown = onpointerdown;
						element.onpointerup = onpointerup;
					}

					element.ontouchstart = onpointerdown;
					element.ontouchend = onpointerup;
				}
			} else if (Platform.isSafari) {
				element.onmousedown = onpointerdown;
				element.onmouseup = onpointerup;
			} else {
				element.onpointerdown = onpointerdown;
				element.onpointerup = onpointerup;
			}

			element.oncontextmenu = function (e) {
				var preventContextMenu = untyped clip.isInput != true;
				if (preventContextMenu) e.preventDefault();
				e.stopPropagation();
				return !preventContextMenu;
			};
		} else if (role == "textbox") {
			element.onkeyup = function(e) {
				if (e.keyCode == 13 && untyped clip.accessCallback != null) {
					untyped clip.accessCallback();
				}
			}
		}

		if (hasTabIndex() && tabindex < 0) {
			tabindex = 0;
		}

		return this.role;
	}

	public function get_description() : String {
		return element.getAttribute("aria-label");
	}

	public function set_description(description : String) : String {
		if (description != "") {
			element.setAttribute("aria-label", description);
		} else {
			element.removeAttribute("aria-label");
		}

		return this.description;
	}

	public function get_id() : String {
		return element.id;
	}

	public function set_id(id : String) : String {
		element.id = id;

		return this.id;
	}

	public function get_enabled() : Bool {
		return this.enabled;
	}

	public function set_enabled(enabled : Bool) : Bool {
		if (this.enabled != enabled) {
			this.enabled = enabled;

			if (enabled) {
				element.removeAttribute("disabled");
				if (hasTabIndex()) {
					element.tabIndex = tabindex;
				}
			} else {
				if (!Platform.isFirefox && !Platform.isSafari) {
					element.setAttribute("disabled", "disabled");
				}
				if (hasTabIndex()) {
					element.tabIndex = -1;
				}
			}
		}

		return this.enabled;
	}

	public function get_autocomplete() : String {
		return untyped element.autocomplete;
	}

	public function set_autocomplete(autocomplete : String) : String {
		untyped element.autocomplete = autocomplete;

		if (untyped clip.setReadOnly != null) {
			untyped clip.setReadOnly(untyped clip.readOnly);
		}

		return this.autocomplete;
	}

	public function get_parent() : AccessWidgetTree {
		return parent;
	}

	public function set_parent(parent : AccessWidgetTree) : AccessWidgetTree {
		if (this.parent != parent) {
			this.parent = parent;

			if (parent != null) {
				emit("added");
				updateZorder();
			}
		}

		return this.parent;
	}

	private static inline function parseNodeIndex(nodeindex : String) : Array<Int> {
		var nodeindexStrings = ~/ /g.split(nodeindex);
		var parsedNodeindex = new Array();

		for (i in 0...nodeindexStrings.length) {
			parsedNodeindex = parsedNodeindex.concat([Std.parseInt(nodeindexStrings[i])]);
		}

		return parsedNodeindex;
	}

	public function addAccessAttributes(attributes : Map<String, String>) : Void {
		for (key in attributes.keys()) {
			switch (key) {
				case "role" : role = attributes.get(key);
				case "keepableTagName" : {
					tagName = attributes.get(key);
					keepTagName = true;
				};
				case "description" : description = attributes.get(key);
				case "zorder" : {
					if (zorder != null) {
						zorder = Std.parseInt(attributes.get(key));
						updateZorder();
					} else {
						zorder = Std.parseInt(attributes.get(key));
					}
				}
				case "id" : id = attributes.get(key);
				case "enabled" : enabled = attributes.get(key) == "true";
				case "nodeindex" : nodeindex = parseNodeIndex(attributes.get(key));
				case "tabindex" : tabindex = Std.parseInt(attributes.get(key));
				case "autocomplete" : autocomplete = attributes.get(key);
				case "aria-hidden" : clip.updateIsAriaHidden(attributes.get(key) == "true");
				case "nextWidgetId" : {
					untyped clip.nextWidgetId = attributes.get(key);
					RenderSupport.once("stagechanged", function() {
						// To keep word order in wigi updated
						clip.addNativeWidget();
					});
				}
				default : {
					if (element != null) {
						if (key.indexOf("style:") == 0) {
							element.style.setProperty(key.substr(6, key.length), attributes.get(key));
						} else if (attributes.get(key) != "") {
							element.setAttribute(key, attributes.get(key));
						} else {
							element.removeAttribute(key);
						}
					}
				}
			}
		}
	}

	public function getAccessWidgetTransform() : Matrix {
		if (parent != null) {
			return parent.getAccessWidgetTransform();
		} else if (clip != null) {
			return clip.worldTransform;
		} else {
			return new Matrix();
		}
	}

	public function updateZorder() : Void {
		if (parent != null) {
			parent.updateZorder();
		}
	}

	public function updateDisplay() : Void {
		if (parent != null) {
			parent.updateDisplay();
		}
	}

	public function updateTransform() : Void {
		if (parent != null) {
			parent.updateTransform();
		}
	}

	public static function addAccessWidget(accessWidget : AccessWidget, ?nodeindexPosition : Int = 0, ?tree : AccessWidgetTree) : Void {
		if (accessWidget.nodeindex == null || accessWidget.nodeindex.length == 0) {
			addAccessWidgetWithoutNodeindex(accessWidget, accessWidget.clip.parent);

			return;
		}

		if (tree == null) {
			tree = AccessWidget.tree;
		}

		var id = accessWidget.nodeindex[nodeindexPosition];

		if (nodeindexPosition == accessWidget.nodeindex.length - 1) {
			if (accessWidget.parent != null) {
				accessWidget.parent.id = id;
				tree.addChild(accessWidget.parent);
			} else {
				tree.addChild(new AccessWidgetTree(id, accessWidget));
			}
		} else {
			if (tree.getChild(id) == null) {
				tree.addChild(new AccessWidgetTree(id, null));
			}

			addAccessWidget(accessWidget, nodeindexPosition + 1, tree.getChild(id));
		}
	}

	public static function addAccessWidgetWithoutNodeindex(accessWidget : AccessWidget, parent : DisplayObject) : Void {
		if (parent == null) {
			return;
		} else if (parent == RenderSupport.PixiStage || (untyped parent.accessWidget != null && untyped parent.accessWidget.parent != null)) {
			var id = parent == RenderSupport.PixiStage ? AccessWidget.tree.nextId : untyped parent.accessWidget.parent.nextId;
			var tree = parent == RenderSupport.PixiStage ? AccessWidget.tree : untyped parent.accessWidget.parent;

			if (accessWidget.parent != null) {
				accessWidget.parent.id = id;
				tree.addChild(accessWidget.parent);
			} else {
				tree.addChild(new AccessWidgetTree(id, accessWidget));
			}
		} else if (parent.parent == null) {
			parent.once("added", function() {
				if (parent != null && parent.parent != null && accessWidget != null && accessWidget.clip != null && accessWidget.clip.parent != null) {
					addAccessWidgetWithoutNodeindex(accessWidget, parent);
				}
			});
		} else if (untyped parent.accessWidget != null && untyped parent.accessWidget.parent == null) {
			untyped parent.accessWidget.once("added", function() {
				if (parent != null && parent.parent != null && parent.accessWidget != null && accessWidget.clip != null && accessWidget.clip.parent != null) {
					addAccessWidgetWithoutNodeindex(accessWidget, parent);
				}
			});
		} else {
			addAccessWidgetWithoutNodeindex(accessWidget, parent.parent);
		}
	}

	public static function removeAccessWidget(accessWidget : AccessWidget) : Void {
		if (accessWidget != null && accessWidget.parent != null) {
			removeAccessWidgetTree(accessWidget.parent);
			accessWidget.emit("removed");
		}
	}

	private static function removeAccessWidgetTree(tree : AccessWidgetTree) : Void {
		if (tree.parent != null) {
			tree.parent.removeChild(tree);
			tree.emit("removed");
		}
	}

	public static function printTree(?tree : AccessWidgetTree, ?id : String = "") : Void {
		if (tree == null) {
			tree = AccessWidget.tree;
		}

		for (key in tree.children.keys()) {
			var parent = tree.children.get(key);
			var accessWidget = parent.accessWidget;
			trace(id + key + " " + (accessWidget != null && accessWidget.element != null ? accessWidget.nodeindex + " " + accessWidget.element.getAttribute("role") : "null"));
			printTree(tree.children.get(key), id + key + " ");
		}
	}

	public static function updateAccessTree(?tree : AccessWidgetTree, ?parent : Element, ?previousElement : Element, ?childrenChanged : Bool = false) : Int {
		if (tree == null) {
			tree = AccessWidget.tree;

			if (DisplayObjectHelper.DebugAccessOrder && tree.childrenChanged) {
				printTree();
			}
		}

		if (!tree.childrenChanged && !childrenChanged) {
			return tree.childrenTabIndex;
		}

		tree.childrenTabIndex = tree.parent != null ? tree.parent.childrenTabIndex : 1;

		if (parent == null) {
			parent = Browser.document.body;
		}

		for (key in tree.children.keys()) {
			var child = tree.children.get(key);

			childrenChanged = childrenChanged || child.childrenChanged;

			if (!child.childrenChanged && !child.changed && !childrenChanged) {
				tree.childrenTabIndex = child.childrenTabIndex;
				continue;
			}

			var accessWidget = child.accessWidget;

			if (accessWidget != null && accessWidget.element != null) {
				if (RenderSupport.RendererType != "html" && (accessWidget.clip == null || !accessWidget.clip.isHTMLRenderer())) {
					if (child.changed) {
						try {
							if (previousElement != null && previousElement.nextSibling != null && previousElement.parentNode == parent) {
								parent.insertBefore(accessWidget.element, previousElement.nextSibling);
							} else {
								parent.appendChild(accessWidget.element);
							}

							child.changed = false;
						} catch (e : Dynamic) {}
					}

					previousElement = accessWidget.element;
				}

				if (accessWidget.hasTabIndex()) {
					tree.childrenTabIndex++;

					accessWidget.tabindex = tree.childrenTabIndex;
				}

				tree.childrenTabIndex = updateAccessTree(child, accessWidget.element, accessWidget.element.firstElementChild, childrenChanged);
			} else {
				tree.childrenTabIndex = updateAccessTree(child, parent, previousElement, childrenChanged);
			}
		}

		tree.childrenChanged = false;

		return tree.childrenTabIndex;
	}
}