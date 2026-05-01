import haxe.crypto.Sha256;

class FlowCrypto {
	public static function sha256(input:String):String {
		return Sha256.encode(input);
	}
}