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

	public function new(maxFilesCount : Int, mimeTypeRegExpFilter : String, onDone : Array<Dynamic> -> Void) {
		super();

		this.maxFilesCount = maxFilesCount;
		this.regExp = new EReg(mimeTypeRegExpFilter, "g");
		this.onDone = onDone;

		createNativeWidget("div");
	}

	public override function updateNativeWidget() : Void {
		styleChanged = true;

		super.updateNativeWidget();
	}

	private override function createNativeWidget(node_name : String) : Void {
		super.createNativeWidget(node_name);

		accessWidget.nodeindex = [-AccessWidget.tree.childrenSize];
		nativeWidget.className = "droparea";
		nativeWidget.oncontextmenu = onContextMenu;
		nativeWidget.ondragover = onDragOver;
		nativeWidget.ondrop = onDrop;
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

	private override function getWidth() : Float {
		if (parent != null) {
			var bounds = parent.getBounds(true);
			return bounds.width * parent.worldTransform.a + bounds.height * parent.worldTransform.c;
		} else {
			return widgetWidth;
		}
	}

	private override function getHeight() : Float {
		if (parent != null) {
			var bounds = parent.getBounds(true);
			return bounds.width * parent.worldTransform.b + bounds.height * parent.worldTransform.d;
		} else {
			return widgetWidth;
		}
	}
}