import js.Browser;
import js.html.Element;

import pixi.core.display.DisplayObject;

using DisplayObjectHelper;

class HTMLStage extends NativeWidgetClip {
	public var isHTMLStage = true;
	private var clips : Map<String, FlowContainer> = new Map<String, FlowContainer>();
	private var stageRect : Dynamic;
	public var isInteractive : Bool = true;
	public function new(width : Float, height : Float) {
		super();

		setWidth(width);
		setHeight(height);

		once("removed", function() {
			RenderSupport.PreventDefault = true;
		});

		this.initNativeWidget();

		nativeWidget.style.display = 'none';
		nativeWidget.classList.add("stage");

		nativeWidget.addEventListener("pointerenter", function() {
			RenderSupport.PreventDefault = false;
		});

		nativeWidget.addEventListener("pointerleave", function() {
			RenderSupport.PreventDefault = true;
		});

		Browser.document.body.appendChild(nativeWidget);
		stageRect = untyped this.nativeWidget.getBoundingClientRect();

		var config = { attributes: true, childList: true, subtree: true };
		var updating = false;
		var callback = function() {
			if (!updating) {
				updating = true;
				RenderSupport.once("drawframe", function() {
					if (!this.nativeWidget) {
						return;
					}

					stageRect = untyped this.nativeWidget.getBoundingClientRect();

					for (clip in clips) {
						if (clip.children != null && clip.children.length > 0) {
							var parentRect = untyped clip.children[0].forceParentNode.getBoundingClientRect();
							clip.setClipX(parentRect.x - stageRect.x);
							clip.setClipY(parentRect.y - stageRect.y);
						}
					}

					updating = false;
				});
			}
		};
		var observer = untyped __js__("new MutationObserver(callback)");
		observer.observe(nativeWidget, config);
	}

	public function appendChild(child : Element) : Void {
		nativeWidget.appendChild(child);
	}

	public function assignClip(className : String, clip : DisplayObject) : Void {
		if (clips.get(className) != null) {
			clips.get(className).removeChildren();
			this.removeChild(clips.get(className));
		}

		var container = new FlowContainer();
		untyped container.isHTMLStageContainer = true;
		var element = nativeWidget.getElementsByClassName(className)[0];

		if (element) {
			untyped clip.forceParentNode = element;
			clip.initNativeWidget();
			container.addChild(clip);
			this.addChild(container);

			clips.set(className, container);
		}
	}

	public function insertBefore(child : Element, reference : Element) : Void {
		nativeWidget.insertBefore(child, reference);
	}

	public function removeElementChild(child : Element) : Void {
		if (nativeWidget != null && child.parentElement == nativeWidget) {
			nativeWidget.removeChild(child);
		}
	}

	public function renderCanvas(renderer : pixi.core.renderers.canvas.CanvasRenderer) {
		return;
	}
}