import js.Browser;
import haxe.Json;

using DisplayObjectHelper;

class ReactContainer extends NativeWidgetClip {
	private var isReady : Bool = false;
	private var onStateChangeEnabled : Bool = true;
	private var component : Dynamic;
	private var props : Dynamic;
	private var stateInit : Dynamic;
	private var mutationObserver : Dynamic;

	public function new(element : String, propsStr : String, stateInitStr : String, onStateChange : String -> Void) {
		super();

		this.initNativeWidget();
		nativeWidget.classList.add("reactContainer");
		nativeWidget.addEventListener("pointerenter", function() {
			RenderSupport.PreventDefault = false;
		});

		nativeWidget.addEventListener("pointerleave", function() {
			RenderSupport.PreventDefault = true;
		});

		props = Json.parse(propsStr);
		stateInit = Json.parse(stateInitStr);
		untyped this.onStateChange = onStateChange;

		var reactBundleUrl = './js/react_bundle.js';
		untyped __js__("import(reactBundleUrl).then(module => {
			this.init(element);
		})");
	}

	private function init(element : String) {
		this.isReady = true;
		this.detectReactComponent(element);
		this.initRootContainer();
		this.renderReact();
	}

	private function detectReactComponent(element : String) {
		if (element == "") return;
		
		var parts = element.split('.');
		if (parts.length == 0) {
			component = null;
		} else if (parts.length == 1 && element.charAt(0) != element.charAt(0).toUpperCase()) {
			// it is a HTML tag, not a library
			component = element;
		} else {
			component = extractReactComponent(parts, Browser.window);
		}

		if (component == null) {
			untyped console.warn("ReactContainer : Didn't find " + element + " component");
		}
	}

	private function extractReactComponent(parts : Array<String>, from : Dynamic) : Dynamic {
		if (parts.length > 0) {
			var firstString : String = parts[0]; 
			var extracted : Dynamic = null;
			untyped __js__("extracted = from[firstString]");

			if (extracted != null) {
				return extractReactComponent(parts.splice(1, parts.length - 1), extracted);
			} else {
				return null;
			}
		}

		return from;
	}

	private function initRootContainer() {
		untyped this.rootContainer = untyped __js__("
			() => {
				const [rootContainerState, setRootContainerState] = React.useState(this.stateInit);
				const [setStates, setSetStates] = React.useState({});

				React.useEffect(() => {
					this.setRootContainerState = setRootContainerState;
					let setStatesAcc = {};
					Object.keys(rootContainerState).forEach(k => {
						setStatesAcc['set' + this.capitalizeFirstLetter(k)] = (val) => setRootContainerState(prev => ({...prev, [k] : val}))
					});
					setSetStates(setStatesAcc);
				}, []);

				React.useEffect(() => {
					if (this.onStateChangeEnabled) {
						this.onStateChange(JSON.stringify(rootContainerState))
					};
				}, [rootContainerState]);

				return React.createElement(this.component, {
					...this.props,
					...rootContainerState,
					...setStates
				});
			}
		");
	}

	private function renderReact() {
		if (this.isReady && this.component != null) {
			var app = untyped __js__("React.createElement(this.rootContainer)");
			untyped __js__("ReactDOM.render(app, this.nativeWidget)");
		}
	}

	public function updateReactState(key : String, valueStr : String) : Void {
		var value = Json.parse(valueStr);

		if (untyped this.setRootContainerState != null) {
			onStateChangeEnabled = false;
			untyped this.setRootContainerState(function (prev) {
				return __js__("{...prev, [key] : value}");
			});
			// Shedule to call after state will update
			Native.timer(0, function() {
				onStateChangeEnabled = true;
			});
		}
	}

	public function setReactListener(name : String, fn : Dynamic -> Void) : Void {
		untyped __js__("this.props[name] = fn");
	}

	public function addNativeWidget() : Void {
		addNativeWidgetDefault();
		observeSize();
	}

	public function removeNativeWidget() : Void {
		if (this.mutationObserver != null) {
			this.mutationObserver.disconnect();
			this.mutationObserver = null;
		}
		removeNativeWidgetDefault();
	}

	private function observeSize() : Void {
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

					if (untyped this._width != bRect.width || untyped this._height != bRect.height) {
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

	private function capitalizeFirstLetter(str : String) : String {
	  return str.charAt(0).toUpperCase() + str.substring(1);
	}
}