import js.Browser;
import js.html.File;
import js.html.FileList;

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

	private override function createNativeWidget(node_name : String) : Void {
		super.createNativeWidget(node_name);

		nativeWidget.className = "droparea";
		// nativeWidget.style.position = "absolute";
		nativeWidget.style.zIndex = AccessWidget.zIndexValues.droparea;
		nativeWidget.onmousemove = provideEvent;
		nativeWidget.onmousedown = provideEvent;
		nativeWidget.onmouseup = provideEvent;
		nativeWidget.oncontextmenu = onContextMenu;
		nativeWidget.ondragover = onDragOver;
		nativeWidget.ondrop = onDrop;
	}

	private function provideEvent(event : Dynamic) : Void {
		event.preventDefault();
		nativeWidget.style.cursor = RenderSupportJSPixi.PixiRenderer.view.style.cursor;
		RenderSupportJSPixi.provideEvent(event);
	}

	private static inline function onContextMenu(event : Dynamic) : Dynamic {
		return RenderSupportJSPixi.PixiView.oncontextmenu(event);
	}

	private static inline function onDragOver(event : Dynamic) : Bool {
		trace("drag over");
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
		return parent != null ? parent.getBounds(true).width : widgetWidth;
	}

	private override function getHeight() : Float {
		return parent != null ? parent.getBounds(true).height : widgetHeight;
	}
}