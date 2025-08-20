import js.lib.Promise;

class Mediabunny {
	static var mediabunnyModule : Dynamic = null;

	public function new() {}

	public static function loadMediabunnyJsLibrary(cb : (module : Dynamic) -> Void) : Void {
		if (mediabunnyModule != null) {
			cb(mediabunnyModule);
			return;
		};

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

	public static function getMediaDuration(cb : (duration : Int) -> Void) : Void {
		var duration = 0;
		var filePath = "./images/material_test/big_buck_bunny.mp4";
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
						console.log('[Debug] Fetching file from path:', filePath);

						// Fetch the file and convert to Blob
						const response = await fetch(filePath);
						if (!response.ok) {
							throw new Error('Failed to fetch file: ' + response.statusText);
						}

						const fileBlob = await response.blob();
						console.log('[Debug] File blob created, size:', fileBlob.size, 'type:', fileBlob.type);

						const input = new Input({
							formats: ALL_FORMATS, // Supporting all file formats
							source: new BlobSource(fileBlob), // Now using actual Blob
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