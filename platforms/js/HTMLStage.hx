import js.Browser;
import js.html.Element;

import pixi.core.display.DisplayObject;

using DisplayObjectHelper;

class HTMLStage extends NativeWidgetClip {
	public var isHTMLStage = true;
	private var clips : Map<String, FlowContainer> = new Map<String, FlowContainer>();
	private var stageRect : Dynamic;
	public function new(width : Float, height : Float) {
		super();

		setWidth(width);
		setHeight(height);

		this.initNativeWidget();

		untyped nativeWidget.style['pointer-events'] = 'auto';
		nativeWidget.style.display = 'none';
		nativeWidget.classList.add("stage");

		Browser.document.body.appendChild(nativeWidget);
		stageRect = untyped this.nativeWidget.getBoundingClientRect();

		var config = { attributes: true, childList: true, subtree: true };
		var updating = false;
		var callback = function() {
			if (!updating && untyped Array.from(clips.keys()).length > 0) {
				updating = true;
				RenderSupport.once("drawframe", function() {
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

	public function assignClip(id : String, clip : DisplayObject) : Void {
		if (clips.get(id) != null) {
			clips.get(id).removeChildren();
			this.removeChild(clips.get(id));
		}

		var container = new FlowContainer();
		untyped container.isHTMLStageContainer = true;
		untyped clip.forceParentNode = Browser.document.getElementById(id);

		clip.initNativeWidget();
		container.addChild(clip);
		this.addChild(container);

		clips.set(id, container);
	}

	public function insertBefore(child : Element, reference : Element) : Void {
		nativeWidget.insertBefore(child, reference);
	}

	public function removeElementChild(child : Element) : Void {
		if (child.parentElement == nativeWidget) {
			nativeWidget.removeChild(child);
		}
	}

	public function renderCanvas(renderer : pixi.core.renderers.canvas.CanvasRenderer) {
		return;
	}
}