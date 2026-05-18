import haxe.crypto.Sha256;
import haxe.crypto.Hmac;
import haxe.io.Bytes;

class FlowCrypto {
	public static function sha256(input : String) : String {
		return Sha256.encode(input);
	}
	public static function hmacSha256(input : String, key : String) : String {
		var hmac = new Hmac(SHA256);
		var keyBytes = Bytes.ofString(key);
		var inputBytes = Bytes.ofString(input);
		var hmacBytes = hmac.make(keyBytes, inputBytes);
		return hmacBytes.toHex();
	}
}
