#if js
#if (flow_nodejs || nwjs)
import js.node.Crypto as NodeCrypto;
#end
#end

class Crypto {
	public static function encodeSHA256(input : String, callback : String -> Void) : Void {
		#if (js && (flow_nodejs || nwjs))
		// Node.js implementation using built-in crypto module
		try {
			var crypto = NodeCrypto;
			var hash = crypto.createHash('sha256');
			hash.update(input, 'utf8');
			var result = hash.digest('hex');
			callback(result);
		} catch (e : Dynamic) {
			callback("Error: " + Std.string(e));
		}
		#elseif js
		// Browser implementation using Web Crypto API
		try {
			// Check if crypto.subtle is available
			var crypto = untyped __js__("window.crypto");
			if (crypto == null || crypto.subtle == null) {
				callback("Error: Web Crypto API not available");
				return;
			}

			// Convert string to UTF-8 bytes
			var encoder = untyped __js__("new TextEncoder()");
			var data = encoder.encode(input);

			// Use Web Crypto API to compute SHA-256
			var promise = crypto.subtle.digest('SHA-256', data);

			untyped __js__("
				promise.then(function(hashBuffer) {
					// Convert ArrayBuffer to hex string
					var hashArray = new Uint8Array(hashBuffer);
					var hashHex = '';

					for (var i = 0; i < hashArray.length; i++) {
						var hex = hashArray[i].toString(16).padStart(2, '0');
						hashHex += hex;
					}

					callback(hashHex);
				}).catch(function(error) {
					callback('Error: ' + error.toString());
				});
			");
		} catch (e : Dynamic) {
			callback("Error: " + Std.string(e));
		}
		#else
		// Fallback for other platforms
		callback("Error: SHA256 not implemented for this platform");
		#end
	}
}