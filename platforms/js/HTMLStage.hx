import js.Browser;
import js.html.Element;

import pixi.core.display.DisplayObject;

using DisplayObjectHelper;

class HTMLStage extends NativeWidgetClip {
	private var isHTMLStage = true;
	private var clips : Map<String, DisplayObject> = new Map<String, DisplayObject>();
	public function new(width : Float, height : Float) {
		super();

		setWidth(width);
		setHeight(height);

		this.initNativeWidget();

		untyped nativeWidget.style['pointer-events'] = 'auto';
		nativeWidget.style.display = 'none';
		nativeWidget.classList.add("stage");

		Browser.document.body.appendChild(nativeWidget);
	}

	public function appendChild(child : Element) : Void {
		nativeWidget.appendChild(child);
	}

	public function assignClip(id : String, clip : DisplayObject) : Void {
		if (clips.get(id) != null) {
			this.removeChild(clips.get(id));
		}

		untyped clip.forceParentNode = Browser.document.getElementById(id);
		clip.initNativeWidget();
		this.addChild(clip);

		clips.set(id, clip);
	}

	public function insertBefore(child : Element, reference : Element) : Void {
		nativeWidget.insertBefore(child, reference);
	}

	public function removeElementChild(child : Element) : Void {
		if (child.parentElement == nativeWidget) {
			nativeWidget.removeChild(child);
		}
	}
}