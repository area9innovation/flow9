import pixi.core.math.Point;

class GesturesDetector {
	private static var IsPinchInProgress : Bool = false;
	private static var PinchInitialDistance : Float = 1.0;
	public static var PinchListeners : Array< Int -> Float -> Float -> Float -> Float -> Void > = [];
	private static var CurrentPinchScaleFactor : Float = 1.0;
	private static var CurrentPinchFocus = { x : 0.0, y : 0.0 };

	public static function processPinch(p1 : Point, p2 : Point) {
		var distance = Math.sqrt( (p2.x - p1.x) * (p2.x - p1.x) + (p2.y - p1.y) * (p2.y - p1.y) );
		var state = 1;

		if (!IsPinchInProgress) {
			// Start gesture
			IsPinchInProgress = true;
			PinchInitialDistance = distance;
			state = 0;
		}

		CurrentPinchFocus.x = (p1.x + p2.x) / 2.0;
		CurrentPinchFocus.y = (p1.y + p2.y) / 2.0;
		CurrentPinchScaleFactor = distance / PinchInitialDistance;

		for (l in PinchListeners) l(state, CurrentPinchFocus.x, CurrentPinchFocus.y, CurrentPinchScaleFactor, 0.0);
	}

	public static function endPinch() {
		if (IsPinchInProgress) {
			IsPinchInProgress = false;
			for (l in PinchListeners) l(2, CurrentPinchFocus.x, CurrentPinchFocus.y, CurrentPinchScaleFactor, 0.0);
		}
	}

	public static function addPinchListener(cb : Int -> Float -> Float -> Float -> Float -> Bool) {
		PinchListeners.push(cb);
		return function() { PinchListeners.remove(cb); }
	}
}