import js.Browser;
import js.html.Element;

import pixi.core.display.Container;
import pixi.core.display.DisplayObject;

using DisplayObjectHelper;

class AccessWidgetTree {
	@:isVar public var id : Int;
	@:isVar public var accessWidget(get, set) : AccessWidget;
	@:isVar public var parent(get, set) : AccessWidgetTree;
	public var children : Map<Int, AccessWidgetTree> = new Map<Int, AccessWidgetTree>();
	public var childrenSize : Int = 0;
	@:isVar public var childrenChanged(get, set) : Bool;
	@:isVar public var changed(get, set) : Bool;
	public var zorder : Int = -9999;

	public function new(id : Int, ?accessWidget : AccessWidget, ?parent : AccessWidgetTree) {
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
			if (parent != null) {
				parent.removeChild(this);
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

	public function updateZorder() : Bool {
		var previousZOrder = zorder;
		zorder = accessWidget != null ? accessWidget.zorder : -9999;

		for (child in children) {
			if (child.zorder > zorder) {
				zorder = child.zorder;
			}
		}

		if (zorder == -9999) {
			return false;
		}

		if (previousZOrder != zorder) {
			if (parent == null) {
				updateDisplay();
			} else if (!parent.updateZorder()) {
				updateDisplay();
			}

			return true;
		} else {
			return false;
		}
	}

	public function updateDisplay() : Void {
		if (accessWidget != null) {
			if (accessWidget.clip.parent == null) {
				return;
			}

			if (accessWidget.element != null) {
				if (RenderSupportJSPixi.DebugAccessOrder) {
					accessWidget.element.setAttribute("zorder", Std.string(zorder));
					accessWidget.element.setAttribute("nodeindex", Std.string(accessWidget.nodeindex));
				}

				accessWidget.element.style.display = zorder >= AccessWidget.tree.zorder && accessWidget.clip.getClipVisible() ? "block" : "none";
			}
		}

		for (child in children) {
			child.updateDisplay();
		}
	}

	public function getChild(id : Int) : AccessWidgetTree {
		return children.get(id);
	}

	public function addChild(child : AccessWidgetTree) : Void {
		var previousChild = getChild(child.id);

		if (previousChild != null) {
			if (previousChild.accessWidget != null) {
				if (child.accessWidget != null && child.accessWidget.nodeindex != null) {
					children.remove(previousChild.id);
					previousChild.id = childrenSize;
					children.set(previousChild.id, previousChild);

					childrenSize++;
					children.set(child.id, child);
					child.parent = this;
				} else {
					child.id = childrenSize;

					childrenSize++;
					children.set(child.id, child);
					child.parent = this;
				}
			} else {
				previousChild.accessWidget = child.accessWidget;
			}
		} else {
			childrenSize++;
			children.set(child.id, child);
			child.parent = this;
		}

		childrenChanged = true;
	}

	public function removeChild(child : AccessWidgetTree) : Void {
		if (child.accessWidget != null) {
			child.accessWidget.element = null;
			untyped child.accessWidget.clip.accessWidget = null;
		}

		if (children.get(child.id) == child) {
			children.remove(child.id);
			childrenSize--;
		}

		child.parent = null;

		if (childrenSize == 0 && accessWidget == null && parent != null) {
			parent.removeChild(this);
		} else {
			updateZorder();
		}
	}
}

class AccessWidget {
	// ARIA-role to HTML tag map
	private static var accessRoleMap : Map<String, String> = [
		"button" => "button",
		"checkbox" => "button",
		"radio" => "button",
		"menu" => "button",
		"listitem" => "button",
		"menuitem" => "button",
		"tab" => "button",
		"banner" => "header",
		"main" => "section",
		"navigation" => "nav",
		"contentinfo" => "footer",
		"form" => "form",
		"textbox" => "input",
	];

	public static var tree : AccessWidgetTree = new AccessWidgetTree(0);

	public var clip : DisplayObject;
	@:isVar public var element(get, set) : Element;

	@:isVar public var nodeindex(get, set) : Array<Int>;
	@:isVar public var zorder(get, set) : Int;

	public var tabindex(get, set) : Int;
	public var role(get, set) : String;
	public var description(get, set) : String;
	public var id(get, set) : String;
	public var enabled(get, set) : Bool;
	public var autocomplete(get, set) : String;

	@:isVar public var parent(get, set) : AccessWidgetTree;

	public function new(clip : DisplayObject, element : Element, ?nodeindex : Array<Int>, ?zorder : Int = 0) {
		this.clip = clip;
		this.element = element;
		this.nodeindex = nodeindex;
		this.zorder = zorder;

		clip.onAdded(function() {
			addAccessWidget(this);

			return function() {
				removeAccessWidget(this);
			}
		});
	}

	public static inline function createAccessWidget(clip : DisplayObject, attributes : Array<Array<String>>) : Void {
		var attributesMap = new Map<String, String>();

		for (kv in attributes) {
			attributesMap.set(kv[0], kv[1]);
		}

		var tagName = attributesMap.get("tag");

		if (tagName == null) {
			tagName = accessRoleMap.get(attributesMap.get("role"));
		}

		if (tagName == null) {
			tagName = "div";
		}

		untyped clip.accessWidget = new AccessWidget(clip, Browser.document.createElement(tagName));
		untyped clip.accessWidget.addAccessAttributes(attributesMap);
	}

	public function get_element() : Element {
		return element;
	}

	public function set_element(element : Element) : Element {
		if (this.element != element) {
			if (this.element != null && this.element.parentNode != null) {
				this.element.parentNode.removeChild(this.element);

				untyped __js__("delete element;");
			}

			this.element = element;

			if (this.element != null) {
				var tagName = this.element.tagName.toLowerCase();

				// Add focus notification. Used for focus control
				this.element.addEventListener("focus", function () {
					clip.emit("focus");

					var parent : DisplayObject = clip.parent;

					if (parent != null) {
						parent.emitEvent("childfocused", clip);
					}
				});

				// Add blur notification. Used for focus control
				this.element.addEventListener("blur", function () {
					clip.emit("blur");
				});

				this.element.setAttribute("aria-disabled", "false");
				this.element.style.zIndex = RenderSupportJSPixi.zIndexValues.accessButton;

				if (tagName == "button") {
					// setting temp. value so it will be easier to read in DOM
					if (this.element.getAttribute("aria-label") == null) {
						this.element.setAttribute("aria-label", "");
					}

					this.element.classList.add("accessButton");
				} else if (tagName == "input") {
					this.element.style.position = "fixed";
					this.element.style.cursor = "inherit";
					this.element.style.opacity = "0";
					this.element.setAttribute("readonly", "");
				} else if (tagName == "form") {
					this.element.onsubmit = function() {
						return false;
					}
				} else {
					this.element.classList.add("accessElement");
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
		return element.tabIndex;
	}

	public function set_tabindex(tabindex : Int) : Int {
		element.tabIndex = tabindex;

		return this.tabindex;
	}

	public function get_role() : String {
		return element.getAttribute("role");
	}

	public function set_role(role : String) : String {
		element.setAttribute("role", role);

		// Sets events
		if (accessRoleMap.get(role) == "button") {
			element.onclick = function(e) {
				if (e.target == element) {
					if (untyped clip.accessCallback != null) {
						untyped clip.accessCallback();
					} else {
						RenderSupportJSPixi.emulateMouseClickOnClip(clip);
					}
				}
			};

			var onFocus = element.onfocus;
			var onBlur = element.onblur;

			element.onfocus = function(e) {
				if (onFocus != null) {
					onFocus(e);
				}

				element.classList.add('focused');
			};

			element.onblur = function(e) {
				if (onBlur != null) {
					onBlur(e);
				}

				element.classList.remove('focused');
			};

			if (element.tabIndex == null) {
				element.tabIndex = 0;
			}
		} else if (role == "textbox") {
			element.onkeyup = function(e) {
				if (e.keyCode == 13 && untyped clip.accessCallback != null) {
					untyped clip.accessCallback();
				}
			}

			if (element.tabIndex == null) {
				element.tabIndex = 0;
			}
		} else if (role == "iframe") {
			if (element.tabIndex == null) {
				element.tabIndex = 0;
			}
		}

		return this.role;
	}

	public function get_description() : String {
		return element.getAttribute("aria-label");
	}

	public function set_description(description : String) : String {
		if (description != "") {
			element.setAttribute("aria-label", description);
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
		return element.getAttribute("aria-disabled") != "true";
	}

	public function set_enabled(enabled : Bool) : Bool {
		if (enabled) {
			element.removeAttribute("disabled");
			element.setAttribute("aria-disabled", "false");
		} else {
			element.setAttribute("disabled", "disabled");
			element.setAttribute("aria-disabled", "true");
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

			updateZorder();
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
				case "description" : description = attributes.get(key);
				case "zorder" : zorder = Std.parseInt(attributes.get(key));
				case "id" : id = attributes.get(key);
				case "enabled" : enabled = attributes.get(key) == "true";
				case "nodeindex" : nodeindex = parseNodeIndex(attributes.get(key));
				case "tabindex" : tabindex = Std.parseInt(attributes.get(key));
				case "autocomplete" : autocomplete = attributes.get(key);
			}
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

	private static function addAccessWidget(accessWidget : AccessWidget, ?nodeindexPosition : Int = 0, ?tree : AccessWidgetTree) : Void {
		if (accessWidget.nodeindex == null || accessWidget.nodeindex.length == 0) {
			addAccessWidgetWithoutNodeindex(accessWidget, accessWidget.clip.parent);

			return;
		}

		if (tree == null) {
			tree = AccessWidget.tree;
		}

		var id = accessWidget.nodeindex[nodeindexPosition];

		if (nodeindexPosition == accessWidget.nodeindex.length - 1) {
			tree.addChild(new AccessWidgetTree(id, accessWidget));
		} else {
			if (tree.getChild(id) == null) {
				tree.addChild(new AccessWidgetTree(id, null));
			}

			addAccessWidget(accessWidget, nodeindexPosition + 1, tree.getChild(id));
		}
	}

	private static function addAccessWidgetWithoutNodeindex(accessWidget : AccessWidget, parent : DisplayObject) : Void {
		if (parent != null) {
			if (untyped parent.accessWidget != null) {
				if (untyped parent.accessWidget.parent == null) {
					addAccessWidget(untyped parent.accessWidget);
				}

				untyped parent.accessWidget.parent.addChild(new AccessWidgetTree(untyped parent.accessWidget.parent.childrenSize, accessWidget));
			} else {
				addAccessWidgetWithoutNodeindex(accessWidget, parent.parent);
			}
		} else {
			tree.addChild(new AccessWidgetTree(tree.childrenSize, accessWidget));
		}
	}

	public static function removeAccessWidget(accessWidget : AccessWidget) : Void {
		if (accessWidget != null && accessWidget.parent != null) {
			removeAccessWidgetTree(accessWidget.parent);
		}
	}

	private static function removeAccessWidgetTree(tree : AccessWidgetTree) : Void {
		if (tree.parent != null) {
			tree.parent.removeChild(tree);
		}
	}

	public static function printTree(?tree : AccessWidgetTree, ?id : String = "") : Void {
		if (tree == null) {
			tree = AccessWidget.tree;
		}

		for (key in tree.children.keys()) {
			var accessWidget = tree.children.get(key).accessWidget;
			trace(id + key + " " + (accessWidget != null ? accessWidget.element.getAttribute("role") : "null"));
			printTree(tree.children.get(key), id + key + " ");
		}
	}

	public static function updateAccessTree(?tree : AccessWidgetTree, ?parent : Element) : Bool {
		if (tree == null) {
			tree = AccessWidget.tree;
		}

		if (!tree.childrenChanged) {
			return false;
		}

		if (parent == null) {
			parent = Browser.document.body;
		}

		for (key in tree.children.keys()) {
			var child = tree.children.get(key);

			if (!child.childrenChanged && !child.changed) {
				continue;
			}

			var accessWidget = child.accessWidget;

			if (accessWidget != null && accessWidget.element != null) {
				if (child.changed) {
					var nextChild = tree.children.get(key + 1);

					if (nextChild != null && nextChild.accessWidget != null && nextChild.accessWidget.element != null && nextChild.accessWidget.element.parentNode == parent) {
						// TODO: Improve
						parent.insertBefore(accessWidget.element, nextChild.accessWidget.element);
					} else {
						parent.appendChild(accessWidget.element);
					}

					child.changed = false;
				}

				updateAccessTree(child, accessWidget.element);
			} else {
				updateAccessTree(child, parent);
			}
		}

		tree.childrenChanged = false;

		return true;
	}
}