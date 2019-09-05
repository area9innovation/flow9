import js.Browser;
import js.html.File;
import js.html.FileList;

import pixi.core.display.Bounds;
import pixi.core.display.TransformBase;

using DisplayObjectHelper;

class DropAreaClip extends NativeWidgetClip {
	private var maxFilesCount : Int;
	private var regExp : EReg;
	private var onDone : Array<Dynamic> -> Void;

	public var isInteractive : Bool = true;

	public function new(maxFilesCount : Int, mimeTypeRegExpFilter : String, onDone : Array<Dynamic> -> Void) {
		super();

		this.maxFilesCount = maxFilesCount;
		this.regExp = new EReg(mimeTypeRegExpFilter, "g");
		this.onDone = onDone;

		if (RenderSupportJSPixi.DomRenderer) {
			styleChanged = false;
		}

		initNativeWidget();
	}

	public override function updateNativeWidgetStyle() : Void {
		super.updateNativeWidgetStyle();

		styleChanged = true;
	}

	private override function createNativeWidget(?tagName : String = "div") : Void {
		if (!isNativeWidget) {
			return;
		}

		super.createNativeWidget(tagName);

		if (accessWidget != null) {
			accessWidget.nodeindex = [-AccessWidget.tree.childrenSize];
		}

		nativeWidget.classList.add("nativeWidget");
		nativeWidget.classList.add("droparea");
		nativeWidget.oncontextmenu = onContextMenu;
		nativeWidget.ondragover = onDragOver;
		nativeWidget.ondrop = onDrop;
		nativeWidget.onmousedown = onMouseDown;
		if (!RenderSupportJSPixi.DomRenderer) {
			nativeWidget.onmousemove = onMouseMove;
		}
		nativeWidget.style.pointerEvents = "auto";

		if (RenderSupportJSPixi.DomRenderer) {
			nativeWidget.style.height = "inherit";
			nativeWidget.style.width = "inherit";
		}
	}

	private static inline function onContextMenu(event : Dynamic) : Dynamic {
		if (RenderSupportJSPixi.PixiView.oncontextmenu != null) {
			return RenderSupportJSPixi.PixiView.oncontextmenu(event);
		} else {
			return true;
		}
	}

	private static inline function onDragOver(event : Dynamic) : Bool {
		event.dataTransfer.dropEffect = 'copy';
		return false;
	}

	private function onDrop(event : Dynamic) : Void {
		event.preventDefault();

		var files : FileList = event.dataTransfer.files;
		var fileArray : Array<File> = [];

		if (maxFilesCount < 0)
			maxFilesCount = files.length;

		for (idx in 0...Math.floor(Math.min(files.length, maxFilesCount))) {
			var file : File = files.item(idx);

			if (!regExp.match(file.type)) {
				maxFilesCount++;
				continue;
			}

			fileArray.push(file);
		}

		onDone(fileArray);
	}

	private function getWidth() : Float {
		if (parent != null) {
			var bounds = parent.getBounds(true);
			return bounds.width * parent.worldTransform.a + bounds.height * parent.worldTransform.c;
		} else {
			return getWidgetWidth();
		}
	}

	private function getHeight() : Float {
		if (parent != null) {
			var bounds = parent.getBounds(true);
			return bounds.width * parent.worldTransform.b + bounds.height * parent.worldTransform.d;
		} else {
			return getWidgetHeight();
		}
	}

	private function onMouseDown(e : Dynamic) {
		e.preventDefault();
	}

	private function onMouseMove(e : Dynamic) {
		nativeWidget.style.cursor = RenderSupportJSPixi.PixiView.style.cursor;
	}
}