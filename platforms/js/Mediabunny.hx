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
						var videoOptions = {}
						// Crop values must be integer greater than 0.
						if (crop[0] > 0 && crop[1] > 0 && crop[2] > 0 && crop[3] > 0 ) {
							videoOptions['crop'] = { left: crop[0], top: crop[1], width: crop[2], height: crop[3] };
						}
						const conversion = await Conversion.init({
							input,
							output,
							audio : audioOptions,
							video : videoOptions,
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
						Object.assign(outputFile, {
							name: file.name,
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

	public static function calculateMD5(file : Dynamic, callback : (md5 : String) -> Void) : Void {
		untyped __js__("
			(async function() {
				try {
					// Read file as ArrayBuffer
					const arrayBuffer = await file.arrayBuffer();
					const uint8Array = new Uint8Array(arrayBuffer);

					// Calculate MD5 using JavaScript implementation
					const md5 = calculateMD5Hash(uint8Array);

					callback(md5);
				} catch (error) {
					console.error('[Error] MD5 calculation failed:', error);
					callback('error_calculating_md5');
				}
			})();

			// MD5 implementation based on RFC 1321
			function calculateMD5Hash(data) {
				// MD5 constants
				const T = new Array(64);
				for (let i = 0; i < 64; i++) {
					T[i] = Math.floor(Math.abs(Math.sin(i + 1)) * 0x100000000);
				}

				// Helper functions
				function F(x, y, z) { return (x & y) | ((~x) & z); }
				function G(x, y, z) { return (x & z) | (y & (~z)); }
				function H(x, y, z) { return x ^ y ^ z; }
				function I(x, y, z) { return y ^ (x | (~z)); }

				function rotateLeft(value, shift) {
					return (value << shift) | (value >>> (32 - shift));
				}

				function addUnsigned(x, y) {
					const lsw = (x & 0xFFFF) + (y & 0xFFFF);
					const msw = (x >> 16) + (y >> 16) + (lsw >> 16);
					return (msw << 16) | (lsw & 0xFFFF);
				}

				// Convert data to message with padding
				const msgLength = data.length;
				const numBlocks = Math.ceil((msgLength + 9) / 64);
				const totalLength = numBlocks * 64;
				const msg = new Array(totalLength);

				// Copy original data
				for (let i = 0; i < msgLength; i++) {
					msg[i] = data[i];
				}

				// Append padding
				msg[msgLength] = 0x80;
				for (let i = msgLength + 1; i < totalLength - 8; i++) {
					msg[i] = 0;
				}

				// Append length in bits as 64-bit little-endian
				const bitLength = msgLength * 8;
				msg[totalLength - 8] = bitLength & 0xFF;
				msg[totalLength - 7] = (bitLength >> 8) & 0xFF;
				msg[totalLength - 6] = (bitLength >> 16) & 0xFF;
				msg[totalLength - 5] = (bitLength >> 24) & 0xFF;
				msg[totalLength - 4] = 0;
				msg[totalLength - 3] = 0;
				msg[totalLength - 2] = 0;
				msg[totalLength - 1] = 0;

				// Initialize MD5 state
				let h0 = 0x67452301;
				let h1 = 0xEFCDAB89;
				let h2 = 0x98BADCFE;
				let h3 = 0x10325476;

				// Process message in 64-byte blocks
				for (let i = 0; i < numBlocks; i++) {
					const offset = i * 64;
					const w = new Array(16);

					// Convert bytes to 32-bit words (little-endian)
					for (let j = 0; j < 16; j++) {
						const byteOffset = offset + j * 4;
						w[j] = msg[byteOffset] | (msg[byteOffset + 1] << 8) |
							   (msg[byteOffset + 2] << 16) | (msg[byteOffset + 3] << 24);
					}

					// Initialize round variables
					let a = h0, b = h1, c = h2, d = h3;

					// Round 1
					for (let j = 0; j < 16; j++) {
						const k = j;
						const s = [7, 12, 17, 22][j % 4];
						const temp = addUnsigned(a, addUnsigned(addUnsigned(F(b, c, d), w[k]), T[j]));
						a = d; d = c; c = b;
						b = addUnsigned(b, rotateLeft(temp, s));
					}

					// Round 2
					for (let j = 16; j < 32; j++) {
						const k = (j * 5 + 1) % 16;
						const s = [5, 9, 14, 20][j % 4];
						const temp = addUnsigned(a, addUnsigned(addUnsigned(G(b, c, d), w[k]), T[j]));
						a = d; d = c; c = b;
						b = addUnsigned(b, rotateLeft(temp, s));
					}

					// Round 3
					for (let j = 32; j < 48; j++) {
						const k = (j * 3 + 5) % 16;
						const s = [4, 11, 16, 23][j % 4];
						const temp = addUnsigned(a, addUnsigned(addUnsigned(H(b, c, d), w[k]), T[j]));
						a = d; d = c; c = b;
						b = addUnsigned(b, rotateLeft(temp, s));
					}

					// Round 4
					for (let j = 48; j < 64; j++) {
						const k = (j * 7) % 16;
						const s = [6, 10, 15, 21][j % 4];
						const temp = addUnsigned(a, addUnsigned(addUnsigned(I(b, c, d), w[k]), T[j]));
						a = d; d = c; c = b;
						b = addUnsigned(b, rotateLeft(temp, s));
					}

					// Update hash values
					h0 = addUnsigned(h0, a);
					h1 = addUnsigned(h1, b);
					h2 = addUnsigned(h2, c);
					h3 = addUnsigned(h3, d);
				}

				// Convert hash to hex string (little-endian)
				function toHex(n) {
					let hex = '';
					for (let i = 0; i < 4; i++) {
						hex += ((n >> (i * 8)) & 0xFF).toString(16).padStart(2, '0');
					}
					return hex;
				}

				return toHex(h0) + toHex(h1) + toHex(h2) + toHex(h3);
			}
		");
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