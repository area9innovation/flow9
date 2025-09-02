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
						// Load the main mediabunny module
						console.log('[Debug] Loading mediabunny main module...');
						const module = await import('./js/mediabunny/mediabunny.min.mjs');
						console.log('[Debug] Mediabunny module loaded:', Object.keys(module));

						// Try to load MP3 encoder extension
						try {
							console.log('[Debug] Loading MP3 encoder extension...');
							const mp3EncoderModule = await import('./js/mediabunny/mediabunny-mp3-encoder.mjs');
							console.log('[Debug] MP3 encoder module loaded:', Object.keys(mp3EncoderModule));

							// Register the MP3 encoder
							if (mp3EncoderModule.registerMp3Encoder) {
								console.log('[Debug] Registering MP3 encoder...');
								await mp3EncoderModule.registerMp3Encoder();
								console.log('[Debug] ✓ MP3 encoder registered successfully');
							} else {
								console.warn('[Warning] MP3 encoder module loaded but registerMp3Encoder function not found');
							}
						} catch (mp3Error) {
							console.warn('[Warning] Failed to load or register MP3 encoder:', mp3Error);
							console.warn('[Info] MP3 encoding will fall back to WAV format');
							console.warn('[Info] Make sure mediabunny-mp3-encoder.mjs is in ./js/mediabunny/ directory');
						}

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
			Errors.print("[Haxe] mbGetMediaDuration Mediabunny library loaded: " + (mediabunnyModule != null ? "Success" : "Failed"));
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

	public static function ExtractAudio(file : Dynamic, format : String, sampleRate : Int, cb : (audioData : Dynamic) -> Void, onError : (error : String) -> Void) : Void {
		loadMediabunnyJsLibrary(function (mediabunnyModule) {
			Errors.print("[Haxe] ExtractAudio Mediabunny library loaded: " + (mediabunnyModule != null ? "Success" : "Failed"));
			if (mediabunnyModule == null) {
				Errors.print("[Error] Mediabunny library not loaded or module not available");
				onError("Mediabunny library not loaded");
				return;
			}
			untyped __js__("
				(async function() {
					try {
						// Use the stored module
						const {
							Input,
							Output,
							Conversion,
							BlobSource,
							BufferTarget,
							ALL_FORMATS,
							WavOutputFormat,
							Mp3OutputFormat,
							canEncodeAudio
						} = mediabunnyModule;

						// Debug: Check what's available in the module
						console.log('[Debug] Available classes:', {
							WavOutputFormat: !!WavOutputFormat,
							Mp3OutputFormat: !!Mp3OutputFormat,
							canEncodeAudio: !!canEncodeAudio
						});

						console.log('[Debug] ExtractAudio - Format:', format, 'SampleRate:', sampleRate);

						// Create a blob from the file
						var blob = new Blob([file], { type: 'video/mp4' });

						// Create input from the file
						const input = new Input({
							formats: ALL_FORMATS,
							source: new BlobSource(blob),
						});

						// Check if there are audio tracks available first
						const audioTrack = await input.getPrimaryAudioTrack();
						if (!audioTrack) {
							throw new Error('No audio track found in the input file');
						}

						console.log('[Debug] Primary audio track found:', audioTrack.numberOfChannels, 'channels,', audioTrack.sampleRate, 'Hz');

						// Check all tracks for debugging
						const allTracks = await input.getTracks();
						const audioTracks = allTracks.filter(track => track.type === 'audio');
						console.log('[Debug] Total tracks:', allTracks.length, 'Audio tracks:', audioTracks.length);

						// Choose the output format based on the format parameter
						let outputFormat;
						let finalFormat = format; // Track the actual format we'll use

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

							console.log('[Debug] MP3 encoding supported:', mp3Supported);

							// For MP3, check multiple conditions
							if (audioTracks.length > 1) {
								console.warn('[Warning] Multiple audio tracks detected (' + audioTracks.length + '), MP3 requires exactly 1. Falling back to WAV format.');
								outputFormat = new WavOutputFormat();
								finalFormat = 'wav';
							} else if (!mp3Supported) {
								console.warn('[Warning] MP3 encoding not supported by browser/environment. Falling back to WAV format.');
								console.warn('[Info] To enable MP3 support, include the @mediabunny/mp3-encoder extension.');
								outputFormat = new WavOutputFormat();
								finalFormat = 'wav';
							} else if (!Mp3OutputFormat) {
								console.warn('[Warning] Mp3OutputFormat class not available, using WAV instead');
								outputFormat = new WavOutputFormat();
								finalFormat = 'wav';
							} else {
								outputFormat = new Mp3OutputFormat();
							}
						} else {
							throw new Error('Unsupported audio format: ' + format);
						}

						console.log('[Debug] Using format:', finalFormat);

						// Create output to memory buffer
						const output = new Output({
							format: outputFormat,
							target: new BufferTarget(),
						});

						// Set up conversion with audio resampling
						const conversionConfig = {
							input,
							output,
							audio: {
								sampleRate: sampleRate, // Resample to specified rate
							},
						};

						const conversion = await Conversion.init(conversionConfig);

						// Check for discarded tracks (useful for debugging)
						if (conversion.discardedTracks && conversion.discardedTracks.length > 0) {
							console.log('[Debug] Discarded tracks:', conversion.discardedTracks.length);
							conversion.discardedTracks.forEach((track, index) => {
								console.log('[Debug] Discarded track', index, '- type:', track.type);
							});
						}

						// Execute the conversion
						await conversion.execute();

						// Get the result buffer
						const buffer = output.target.buffer; // ArrayBuffer containing the audio file

						console.log('[Debug] Audio extraction completed in', finalFormat, 'format, buffer size:', buffer.byteLength);

						// Create a proper Blob object for the audio data
						// Determine the MIME type based on the actual format used
						let mimeType;
						if (finalFormat === 'wav') {
							mimeType = 'audio/wav';
						} else if (finalFormat === 'mp3') {
							mimeType = 'audio/mpeg';
						} else {
							mimeType = 'audio/wav'; // fallback
						}

						const audioBlob = new Blob([buffer], { type: mimeType });
						console.log('[Debug] Created audio blob with MIME type:', mimeType, 'size:', audioBlob.size);

						cb(audioBlob);

					} catch (error) {
						console.error('[Error] ExtractAudio failed:', error);
						console.error('[Error] Details:', error.message, error.stack);
						onError('Audio extraction failed: ' + error.message);
					}
				})();
			");
		});
	}
}