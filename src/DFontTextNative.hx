import pixi.core.display.DisplayObject;

@:native("DFontText")
extern class DFontTextNative extends DisplayObject {
	public function new(text : String, style : Dynamic) : Void;
	public static var dfont_table : Array<Dynamic>;
	static public function initDFontData(fontfamily : String, metrics : Dynamic) : Void;
	static public function loadTextures(fontfamily : String, metrics : Dynamic, onDone : Void -> Void) : Void;
	static public function loadTexture(fontfamily : String, metrics : Dynamic, page : Int, onDone : Void -> Void) : Void;
	static public function addTexture2Loader(fontfamily : String, metrics : Dynamic, page : Int, onDone : Void -> Void, loader : Dynamic) : Void;
	static public function getNumPages(fontfamily : String) : Int;
	public var resolution : Float;
}