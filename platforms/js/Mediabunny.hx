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

	public static function conversion(file : Dynamic, format : String, params : Array<Dynamic>, cb : (outputFile : Dynamic) -> Void, onError : (error : String) -> Void) : Void {
		withMediabunnyModule("conversion", function(mediabunnyModule) {
			var sampleRate = HaxeRuntime.extractStructArguments(params[0])[0];
			var crop = HaxeRuntime.extractStructArguments(params[1]);
			var trim = HaxeRuntime.extractStructArguments(params[2]);
			var numberOfChannels = HaxeRuntime.extractStructArguments(params[3])[0];
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

						console.log('[Debug] Mediabunny conversion - Format:', format, 'Params:', params);

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

						var audioOptions = {
							'sampleRate' : sampleRate
						}
						if (numberOfChannels > 0) {
							Object.assign(audioOptions, {
								numberOfChannels : numberOfChannels
							})
						}
						var videoOptions = {};
						// Crop values must be integer greater than 0.
						if (crop[0] > 0 && crop[1] > 0 && crop[2] > 0 && crop[3] > 0 ) {
							videoOptions['crop'] = { left: crop[0], top: crop[1], width: crop[2], height: crop[3] };
						}

						// Trim
						var trimOption = {};
						if (trim[0] != 0) Object.assign(trimOption, {
							start: trim[0],
						});
						if (trim[1] != 0) Object.assign(trimOption, {
							end: trim[1],
						});

						const conversion = await Conversion.init({
							input,
							output,
							audio : audioOptions,
							video : videoOptions,
							trim : trimOption
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

						// Generate output filename with correct extension
						const originalName = file.name || 'converted_file';
						const lastDotIndex = originalName.lastIndexOf('.');
						const baseName = lastDotIndex > 0 ? originalName.substring(0, lastDotIndex) : originalName;
						const outputFileName = baseName + '.' + finalFormat;

						Object.assign(outputFile, {
							name: outputFileName,
						})
						console.log('[Debug] Created blob' , outputFile.name, 'with MIME type:', mimeType, 'size:', outputFile.size);

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

	public static function getVideoInfo(file : Dynamic, callback : (width : Int, height : Int, bitrate : Int) -> Void) : Void {
		withMediabunnyModule("getVideoInfo", function(mediabunnyModule) {
			untyped __js__("
				(async function() {
					try {
						// Use the stored module
						const { Input, BlobSource, ALL_FORMATS } = mediabunnyModule;

						console.log('[Debug] Getting video info for file:', file.name);

						const input = new Input({
							formats: ALL_FORMATS,
							source: new BlobSource(file),
						});

						// Get video track information
						const videoTrack = await input.getPrimaryVideoTrack();

						let bitrate = 0;
						let width = 0;
						let height = 0;

						if (videoTrack) {
							// Get display dimensions
							width = videoTrack.displayWidth || 0;
							height = videoTrack.displayHeight || 0;

							// Compute packet statistics to estimate bitrate
							try {
								const stats = await videoTrack.computePacketStats(100);
								bitrate = Math.round(stats.averageBitrate || 0);
							} catch (statsError) {
								console.warn('[Warning] Could not compute packet stats:', statsError);
								bitrate = 0;
							}
						}

						console.log('[Debug] Video info - Width:', width, 'Height:', height, 'Bitrate:', bitrate);
						callback(width, height, bitrate);
					} catch (error) {
						console.error('[Error] getVideoInfo failed:', error);
						console.error('[Error] Details:', error.message, error.stack);
						callback(0, 0, 0);
					}
				})();
			");
		}, function() {
			callback(0, 0, 0);
		});
	}

	public static function getFileInfo(file : Dynamic, callback : (size : Int, type : String, lastModified : Float) -> Void) : Void {
		untyped __js__("
			try {
				const size = file.size || 0;
				const type = file.type || 'unknown';
				const lastModified = file.lastModified || 0;

				console.log('[Debug] File info - Size:', size, 'Type:', type, 'LastModified:', lastModified);
				callback(size, type, lastModified);
			} catch (error) {
				console.error('[Error] getFileInfo failed:', error);
				callback(0, 'error', 0);
			}
		");
	}
}