import haxe.crypto.Sha256;

class Hash {
	public static function sha256(input:String):String {
		return Sha256.encode(input);
	}
}