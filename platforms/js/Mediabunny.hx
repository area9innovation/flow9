import js.lib.Promise;
import js.html.Blob;

class Mediabunny {
	static var mediabunnyModule : Dynamic = null;

	public function new() {}

	private static function loadMediabunnyJsLibrary(cb : (module : Dynamic) -> Void) : Void {
		if (mediabunnyModule != null) {
			cb(mediabunnyModule);
			return;
		};

		Errors.print("[Haxe] Importing ES6 module");

		// TODO: Maybe load mp3 encoder extension when needed (with the first usage).
		untyped __js__("
			(async function() {
				try {
					// Load the main mediabunny module
					console.log('[Debug] Loading mediabunny main module...');
					const module = await import('./js/mediabunny/mediabunny.min.mjs');

					// Try to load MP3 encoder extension
					try {
						console.log('[Debug] Loading MP3 encoder extension...');
						const mp3EncoderModule = await import('./js/mediabunny/mediabunny-mp3-encoder.mjs');

						// Register the MP3 encoder
						if (mp3EncoderModule.registerMp3Encoder) {
							console.log('[Debug] Registering MP3 encoder...');
							await mp3EncoderModule.registerMp3Encoder();
							// console.log('[Debug] ✓ MP3 encoder registered successfully');
						} else {
							console.warn('[Warning] MP3 encoder module loaded but registerMp3Encoder function not found');
						}
					} catch (mp3Error) {
						console.warn('[Warning] Failed to load or register MP3 encoder:', mp3Error);
						console.warn('[Info] Make sure mediabunny-mp3-encoder.mjs is in ./js/mediabunny/ directory');
					}

					Errors.print('[Haxe] Mediabunny ES6 module imported successfully');
					cb(module);
				} catch (error) {
					console.error('[Error] Failed to import Mediabunny module:', error);
					Errors.print('[Error] Failed to import Mediabunny module: ' + error.message);
					cb(null);
				}
			})();
		");
	}

	private static function withMediabunnyModule<T>(operation : String, onSuccess : (module : Dynamic) -> Void, onFailure : () -> Void) : Void {
		loadMediabunnyJsLibrary(function (loadedModule) {
			Errors.print("[Haxe] " + operation + " Mediabunny library loaded: " + (loadedModule != null ? "Success" : "Failed"));
			if (loadedModule == null) {
				Errors.print("[Error] Mediabunny library not loaded or module not available");
				onFailure();
				return;
			}
			// Store the loaded module in the static variable for caching
			mediabunnyModule = loadedModule;
			onSuccess(loadedModule);
		});
	}

	public static function getMediaDuration(file : Dynamic, cb : (duration : Int) -> Void) : Void {
		var duration = 0;
		withMediabunnyModule("getMediaDuration", function(mediabunnyModule) {
			untyped __js__("
				(async function() {
					try {
						// Use the stored module instead of importing again
						const { Input, BlobSource, ALL_FORMATS } = mediabunnyModule;

						console.log('[Debug] Using classes from stored module');

						const input = new Input({
							formats: ALL_FORMATS, // Supporting all file formats
							source: new BlobSource(file), // Now using actual Blob
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
		}, function() {
			cb(0);
		});
	}

	public static function conversion(file : Dynamic, format : String, sampleRate : Int, cb : (outputFile : Dynamic) -> Void, onError : (error : String) -> Void) : Void {
		withMediabunnyModule("conversion", function(mediabunnyModule) {
			untyped __js__("
				(async function() {
					try {
						// Use the stored module
						const {
							Input,
							ALL_FORMATS,
							BlobSource,
							Output,
							BufferTarget,
							WavOutputFormat,
							Mp3OutputFormat,
							WebMOutputFormat,
							Mp4OutputFormat,
							canEncodeAudio,
							Conversion,
						} = mediabunnyModule;

						console.log('[Debug] Mediabunny conversion - Format:', format, 'SampleRate:', sampleRate);

						const input = new Input({
	 						source: new BlobSource(file),
							formats: ALL_FORMATS,
						});

						let outputFormat;
						let finalFormat = format;
						if (format === 'wav') {
							outputFormat = new WavOutputFormat();
						} else if (format === 'mp3') {
							// Check if MP3 encoding is supported
							let mp3Supported = false;
							if (canEncodeAudio) {
								try {
									mp3Supported = await canEncodeAudio('mp3');
								} catch (e) {
									console.warn('[Warning] Could not check MP3 encoding support:', e);
								}
							}

							if (mp3Supported) {
								outputFormat = new Mp3OutputFormat();
							} else {
								console.log('[Debug] MP3 encoding NOT supported: fallback to wave format');
								finalFormat = 'wav';
								outputFormat = new WavOutputFormat();
							}
						} else if (format === 'webm') {
							outputFormat = new WebMOutputFormat();
						} else if (format === 'mp4') {
							outputFormat = new Mp4OutputFormat();
						} else {
							throw new Error('Unsupported audio format: ' + format);
						}

						const output = new Output({
							format: outputFormat,
							target: new BufferTarget(),
						});

						const conversion = await Conversion.init({
							input,
							output,
						});

						// Execute the conversion
						await conversion.execute();

						let mimeType;
						if (finalFormat === 'wav') {
							mimeType = 'audio/wav';
						} else if (finalFormat === 'mp3') {
							mimeType = 'audio/mpeg';
						} else if (finalFormat == 'webm') {
							mimeType = 'video/webm';
						} else if (finalFormat == 'mp4') {
							mimeType = 'video/mp4';
						} else {
							throw new Error('Wrong mimeType for extension: ' + finalFormat);
						}

						const outputFile = new Blob([output.target.buffer], { type: mimeType });
						console.log('[Debug] Created blob with MIME type:', mimeType, 'size:', outputFile.size);

						cb(outputFile);

					} catch (error) {
						console.error('[Error] Mediabunny conversion failed:', error);
						onError('Mediabunny conversion failed: ' + error.message);
					}
				})();
			");
		}, function() {
			onError("Mediabunny library not loaded");
		});
	}
}