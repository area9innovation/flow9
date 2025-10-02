import js.lib.Promise;
import js.html.Blob;

class Mediabunny {
	static var mediabunnyModule : Dynamic = null;

	public function new() {}

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
		initOutputFormatHelper();
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
							Conversion,
						} = mediabunnyModule;

						console.log('[Debug] Mediabunny conversion - Format:', format, 'Params:', params);

						const input = new Input({
	 						source: new BlobSource(file),
							formats: ALL_FORMATS,
						});

						const { outputFormat, finalFormat } = await Mediabunny.createOutputFormat(format, mediabunnyModule);

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

						const mimeType = Mediabunny.getMimeTypeForFormat(finalFormat);
						const outputFile = new Blob([output.target.buffer], { type: mimeType });

						// Generate output filename with correct extension
						const originalName = file.name || 'converted_file';
						const outputFileName = Mediabunny.generateOutputFileName(originalName, finalFormat);

						Object.assign(outputFile, {
							name: outputFileName,
						});
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

	public static function concatMedia(files : Array<Dynamic>, outputName : String, cb : (outputFile : Dynamic) -> Void, onError : (error : String) -> Void) : Void {
		initOutputFormatHelper();
		withMediabunnyModule("concatMedia", function(mediabunnyModule) {
			untyped __js__("
				(async function() {
					try {
						const {
							Input,
							Output,
							BufferTarget,
							BlobSource,
							ALL_FORMATS,
							EncodedVideoPacketSource,
							EncodedAudioPacketSource,
							EncodedPacketSink
						} = mediabunnyModule;

						console.log('[Debug] Starting video concatenation for', files.length, 'files');

						if (!files || files.length === 0) {
							throw new Error('No files provided for concatenation');
						}

						if (files.length === 1) {
							console.log('[Debug] Only one file provided, returning as-is');
							cb(files[0]);
							return;
						}

						var format = files[0].name.substring(files[0].name.lastIndexOf('.') + 1);
						var sameExtension = files.every(file => {
							return file.name.substring(file.name.lastIndexOf('.') + 1) == format
						});

						if (!sameExtension) {
							throw new Error('Media to concatenate must have same extension');
						}

						const { outputFormat, finalFormat } = await Mediabunny.createOutputFormat(format, mediabunnyModule);

						const output = new Output({
							format: outputFormat,
							target: new BufferTarget(),
						});

						let videoTrack = null;
						let audioTrack = null;
						let totalDuration = 0;

						for (let i = 0; i < files.length; i++) {
							const file = files[i];
							console.log('[Debug] Processing file', i + 1, 'of', files.length, ':', file.name);

							const input = new Input({
								formats: ALL_FORMATS,
								source: new BlobSource(file),
							});

							// Get tracks from input
							const videoInputTrack = await input.getPrimaryVideoTrack();
							const audioInputTrack = await input.getPrimaryAudioTrack();

							// For the first file, create output tracks
							if (i === 0) {
								const videoCodec = videoInputTrack ? videoInputTrack.codec : null;
								const audioCodec = audioInputTrack ? audioInputTrack.codec : null;

								console.log('[Debug] Setting up tracks - Video codec:', videoCodec, 'Audio codec:', audioCodec);

								// Add video track if present
								if (videoInputTrack && videoCodec) {
									videoTrack = new EncodedVideoPacketSource(videoCodec);
									output.addVideoTrack(videoTrack, {
										rotation: videoInputTrack.rotation || 0,
										languageCode: videoInputTrack.languageCode || 'und',
									});
								}

								// Add audio track if present
								if (audioInputTrack && audioCodec) {
									audioTrack = new EncodedAudioPacketSource(audioCodec);
									output.addAudioTrack(audioTrack, {
										languageCode: audioInputTrack.languageCode || 'und',
									});
								}

								// Start the output
								await output.start();
							}

							// Get decoder config for metadata
							const videoConfig = videoInputTrack ? await videoInputTrack.getDecoderConfig() : null;
							const audioConfig = audioInputTrack ? await audioInputTrack.getDecoderConfig() : null;

							// Create packet sinks
							const videoPacketSink = videoInputTrack ? new EncodedPacketSink(videoInputTrack) : null;
							const audioPacketSink = audioInputTrack ? new EncodedPacketSink(audioInputTrack) : null;

							// Process video packets
							if (videoPacketSink && videoTrack && videoConfig) {
								let lastVideoTimestamp = 0;
								for await (const packet of videoPacketSink.packets()) {
									// Adjust timestamp to account for previous videos
									const adjustedPacket = packet.clone({
										timestamp: packet.timestamp + totalDuration
									});

									await videoTrack.add(adjustedPacket, { decoderConfig: videoConfig });
									lastVideoTimestamp = adjustedPacket.timestamp + adjustedPacket.duration;
								}
							}

							// Process audio packets if present
							if (audioPacketSink && audioTrack && audioConfig) {
								for await (const packet of audioPacketSink.packets()) {
									const adjustedPacket = packet.clone({
										timestamp: packet.timestamp + totalDuration
									});

									await audioTrack.add(adjustedPacket, { decoderConfig: audioConfig });
								}
							}
							// Update total duration for next file
							const fileDuration = await input.computeDuration();
							totalDuration += fileDuration;
						}

						// Close tracks
						if (videoTrack) videoTrack.close();
						if (audioTrack) audioTrack.close();

						// Finalize output
						console.log('[Debug] Finalizing concatenated video...');
						await output.finalize();

						const mimeType = Mediabunny.getMimeTypeForFormat(finalFormat);

						// Create output blob
						const outputBlob = new Blob([output.target.buffer], { type: mimeType });

						const outputFileName = Mediabunny.generateOutputFileName(outputName, finalFormat);
						Object.assign(outputBlob, {
							name: outputFileName,
						});

						console.log('[Debug] Concatenation complete. Output size:', outputBlob.size, 'bytes');
						cb(outputBlob);

					} catch (error) {
						console.error('[Error] Video concatenation failed:', error);
						console.error('[Error] Stack:', error.stack);
						onError('Video concatenation failed: ' + error.message);
					}
				})();
			");
		}, function() {
			onError("Mediabunny library not loaded");
		});
	}

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

	private static function getMimeTypeForFormat(format : String) : String {
		return switch (format) {
			case 'wav': 'audio/wav';
			case 'mp3': 'audio/mpeg';
			case 'webm': 'video/webm';
			case 'mp4': 'video/mp4';
			default: throw 'Wrong mimeType for extension: ' + format;
		}
	}

	private static function generateOutputFileName(inputName : String, format : String) : String {
		var lastDotIndex = inputName.lastIndexOf('.');
		var baseName = lastDotIndex > 0 ? inputName.substring(0, lastDotIndex) : inputName;
		return baseName + '.' + format;
	}

	private static var outputFormatHelperInitialized : Bool = false;

	private static function initOutputFormatHelper() : Void {
		if (!outputFormatHelperInitialized) {
			untyped __js__("
				Mediabunny.createOutputFormat = async function(format, mediabunnyModule) {
					const { WavOutputFormat, Mp3OutputFormat, WebMOutputFormat, Mp4OutputFormat, canEncodeAudio } = mediabunnyModule;

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

					return { outputFormat, finalFormat };
				};
			");
			outputFormatHelperInitialized = true;
		}
	}
}