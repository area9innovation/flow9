import js.lib.Promise;
import js.html.Blob;

class Mediabunny {
	static var mediabunnyModule : Dynamic = null;

	public function new() {}

	public static function loadMediabunnyJsLibrary(cb : (module : Dynamic) -> Void) : Void {
		if (mediabunnyModule != null) {
			cb(mediabunnyModule);
			return;
		};

		// TODO: Remove if nothing in there.
		var loadUtils = Util.loadJS("js/mediabunny/mediabunny-utils.js");

		loadUtils.then(function(__) {
			Errors.print("[Haxe] Mediabunny utils loaded, now importing ES6 module");

			untyped __js__("
				(async function() {
					try {
						// Use dynamic import to load the ES6 module
						const module = await import('./js/mediabunny/mediabunny.min.mjs');
						console.log('[Debug] Mediabunny module loaded:', Object.keys(module));

						// Store the module for later use
						mediabunnyModule = module;

						Errors.print('[Haxe] Mediabunny ES6 module imported successfully');
						cb(module);
					} catch (error) {
						console.error('[Error] Failed to import Mediabunny module:', error);
						Errors.print('[Error] Failed to import Mediabunny module: ' + error.message);
						cb(null);
					}
				})();
			");
		}, function(e) {
			Errors.print("[Error] Can't load Mediabunny utils: " + e);
			cb(null);
		});
	}

	public static function getMediaDuration(file : Dynamic, cb : (duration : Int) -> Void) : Void {
		var duration = 0;
		loadMediabunnyJsLibrary(function (mediabunnyModule) {
			Errors.print("[Haxe] getMediaDuration Mediabunny library loaded: " + (mediabunnyModule != null ? "Success" : "Failed"));
			if (mediabunnyModule == null) {
				Errors.print("[Error] Mediabunny library not loaded or module not available");
				cb(0);
				return;
			}
			untyped __js__("
				(async function() {
					try {
						// Use the stored module instead of importing again
						const { Input, BlobSource, ALL_FORMATS } = mediabunnyModule;

						console.log('[Debug] Using classes from stored module');

						var blob = new Blob([file], { type: 'video/mp4' });
						console.log(blob);

						const input = new Input({
							formats: ALL_FORMATS, // Supporting all file formats
							source: new BlobSource(blob), // Now using actual Blob
						});
						duration = await input.computeDuration(); // in seconds
						console.log('[Debug] Duration computed:', duration);
						cb(duration);
					} catch (error) {
						console.error('[Error] getMediaDuration failed:', error);
						console.error('[Error] Details:', error.message, error.stack);
						cb(0);
					}
				})();
			");
		});
	}
}