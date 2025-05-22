import js.lib.Promise;

class Mark {
	static var isLibraryLoaded : Bool = false;

	public function new() {}

	public static function loadMarkJsLibrary(cb : (loaded : Bool)  -> Void) : Void {
		if (isLibraryLoaded) {
			cb(isLibraryLoaded);
			return;
		};

		var loadLib = Util.loadJS("js/mark/mark.min.js");
		var loadUtils = Util.loadJS("js/mark/mark-utils.js");

		Promise.all([loadLib, loadUtils]).then(function(__) {
			Errors.print("[Haxe] Mark library loaded");
			isLibraryLoaded = true;
		}, function(e) {
			Errors.print("[Error] Can't load Mark libraries: " + e);
		});

		cb(isLibraryLoaded);
	}
}