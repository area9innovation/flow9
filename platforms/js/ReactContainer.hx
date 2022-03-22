import js.Browser;
import haxe.Json;

using DisplayObjectHelper;

class ReactContainer extends NativeWidgetClip {
	private var isReady : Bool = false;
	private var component : Dynamic;
	private var props : Dynamic;
	private var mutationObserver : Dynamic;

	public function new(element : String, propsStr : String) {
		super();

		this.initNativeWidget();
		nativeWidget.classList.add("reactContainer");

		props = Json.parse(propsStr);
		untyped console.log("props : ", props);

		var reactBundleUrl = './js/react_bundle.js';
		untyped __js__("import(reactBundleUrl).then(module => {
			this.init(element);
		})");
	}

	public function init(element : String) {
		this.isReady = true;
		this.detectReactComponent(element);
		this.renderReact();
	}

	public function renderReact() {
		if (this.isReady && this.component != null) {
			untyped __js__("ReactDOM.render(React.createElement(this.component, this.props), this.nativeWidget)");
		}
	}

	public function detectReactComponent(element : String) {
		if (element.charAt(0) != element.charAt(0).toUpperCase()) {
			// it is a HTML tag, not a library
			component = element;
		} else {
			component = extractReactComponent(element);
		}
	}

	public function extractReactComponent(element : String) : Dynamic {
		var parts = element.split('.');
		if (parts.length == 0) return null;
		var component = extractReactComponentRec(parts, Browser.window);
		return component;
	}

	private function extractReactComponentRec(parts : Array<String>, from : Dynamic) : Dynamic {
		if (parts.length > 0) {
			var firstString : String = parts[0]; 
			var extracted : Dynamic = null;
			untyped __js__("extracted = from[firstString]");

			if (extracted != null) {
				return extractReactComponentRec(parts.splice(1, parts.length - 1), extracted);
			} else {
				return null;
			}
		}

		return from;
	}

	public function updateReactState(key : String, valueStr : String) : Void {
		var value = Json.parse(valueStr);
		untyped __js__("this.props[key] = value");

		renderReact();
	}

	public function addNativeWidget() : Void {
		addNativeWidgetDefault();
		observeSize();
	}

	public function removeNativeWidget() : Void {
		if (this.mutationObserver != null) {
			untyped console.log('DISCONNECT OBSERVER');
			this.mutationObserver.disconnect();
			this.mutationObserver = null;
		}
		removeNativeWidgetDefault();
	}

	public function observeSize() : Void {
		untyped console.log('START OBSERVING');
		var bRect = untyped this.nativeWidget.getBoundingClientRect();

		var config = { attributes: true, childList: true, subtree: true };
		var updating = false;
		var callback = function() {
			if (!updating) {
				updating = true;
				RenderSupport.once("drawframe", function() {
					if (!this.nativeWidget || !this.mutationObserver) {
						return;
					}

					bRect = untyped this.nativeWidget.getBoundingClientRect();

					if (this.width != bRect.width || this.height != bRect.height) {
						this.width = bRect.width;
						this.height = bRect.height;
						this.emitEvent("resize");
					}

					updating = false;
				});
			}
		};
		callback();
		this.mutationObserver = untyped __js__("new MutationObserver(callback)");
		this.mutationObserver.observe(nativeWidget, config);
	}
}