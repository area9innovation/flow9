import js.three.Texture;

using DisplayObjectHelper;

class Texture3DHelper {
	public static function emit(parent : Texture, event : String) : Void {
		parent.dispatchEvent({ type : event });
	}

	public static function on(parent : Texture, event : String, fn : Void -> Void) : Void {
		parent.addEventListener(event, untyped fn);
	}

	public static function off(parent : Texture, event : String, fn : Void -> Void) : Void {
		parent.removeEventListener(event, untyped fn);
	}

	public static function once(parent : Texture, event : String, fn : Void -> Void) : Void {
		var disp : Void -> Void = null;
		disp = function() {
			off(parent, event, fn);
			off(parent, event, disp);
		};

		on(parent, event, fn);
		on(parent, event, disp);
	}
}