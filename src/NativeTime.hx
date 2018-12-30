
// helper functions for working with time used in Native.hx, NativeO.hx and NativeHx.hx
class NativeTime {
	public static function timestamp() : Float {
		var t = Date.now().getTime();
		return t;
	}

	public static function utc2local(stamp : Float) : Float {
		#if (js || flash)
		var date = Date.fromTime(stamp);
		var offset = untyped date.getTimezoneOffset() * DateTools.minutes(1);

		#else
		var offset = NativeTime.getTimeOffset();
		#end

		return stamp - offset;
	}

	public static function local2utc(stamp : Float) : Float {
		#if (js || flash)
		var date = Date.fromTime(stamp);
		var offset = untyped date.getTimezoneOffset() * DateTools.minutes(1);

		date = DateTools.delta(date, offset);
		offset = untyped date.getTimezoneOffset() * DateTools.minutes(1);

		#else
		var offset = NativeTime.getTimeOffset();
		#end

		return stamp + offset;
	}

	// Used only for all targets except js and flash
	private static function getTimeOffset() {
	    var now = Date.now();
	    now = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
	    return now.getTime() - 24. * 3600 * 1000 * Math.round(now.getTime() / 24 / 3600 / 1000);
	}

	// Converts string time representation to time in milliseconds since epoch 1970 in UTC treating the string as local time
	public static function string2time(date : String) : Float {
		return Date.fromString(date).getTime();
	}

	// Returns a string representation for the time (time is given in milliseconds since epoch 1970 UTC)
	public static function time2string(date : Float) : String {
		return Date.fromTime(date).toString();
	}

	public static function dayOfWeek(year: Int, month: Int, day: Int) : Int {
		var d = new Date(year, month - 1,  day, 0, 0, 0);
		// in Date 0 is for Sunday and we're expecting 0 to be Monday
		return (d.getDay() + 6) % 7;
	}

}