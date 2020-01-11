import js.Browser;
import js.html.File;
import js.html.FileList;

import pixi.core.display.Bounds;
import pixi.core.display.TransformBase;
import pixi.core.math.Point;

using DisplayObjectHelper;

class DropAreaClip extends NativeWidgetClip {
	private var maxFilesCount : Int;
	private var regExp : EReg;
	private var onDone : Array<Dynamic> -> Void;

	public var keepNativeWidget = true;

	public var isInteractive : Bool = true;

	public function new(maxFilesCount : Int, mimeTypeRegExpFilter : String, onDone : Array<Dynamic> -> Void) {
		super();

		this.maxFilesCount = maxFilesCount;
		this.regExp = new EReg(mimeTypeRegExpFilter, "g");
		this.onDone = onDone;

		widgetBounds.minX = 0;
		widgetBounds.minY = 0;
		widgetBounds.maxX = 0;
		widgetBounds.maxY = 0;

		if (RenderSupportJSPixi.RendererType == "html") {
			styleChanged = false;
		}

		initNativeWidget();
	}

	public override function updateNativeWidgetStyle() : Void {
		calculateWidgetBounds();
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
		if (RenderSupportJSPixi.RendererType != "html") {
			nativeWidget.onmousemove = onMouseMove;

			nativeWidget.onpointerover = function(e) { RenderSupportJSPixi.PixiRenderer.plugins.interaction.onPointerOver(e); };
			nativeWidget.onpointerout = function(e) { RenderSupportJSPixi.PixiRenderer.plugins.interaction.onPointerOut(e); };
		}
		nativeWidget.style.pointerEvents = "auto";

		if (RenderSupportJSPixi.RendererType == "html") {
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

	private function onMouseDown(e : Dynamic) {
		e.preventDefault();
	}

	private function onMouseMove(e : Dynamic) {
		nativeWidget.style.cursor = RenderSupportJSPixi.PixiView.style.cursor;
	}

	public override function calculateWidgetBounds() : Void {
		if (untyped parent != null && parent.localBounds != null) {
			widgetBounds = untyped parent.localBounds;
		}
	}
}