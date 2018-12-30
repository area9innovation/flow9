#if js
import js.Browser;
import js.html.Geolocation;
import js.html.PositionGeolocation;
import js.html.PositionError;
import haxe.Timer;
import NativeTime;
#end

class GeolocationSupportHx {
    public function new() {}

    public static function __init__() {
    }

    public static function geolocationGetCurrentPosition(onOK : Float -> Float -> Float -> Float -> Float -> Float -> Float -> Float -> Void,
            onError : Int -> String -> Void, enableHighAccuracy : Bool, timeout : Float, maximumAge : Float,
            turnOnGeolocationMessage : String, okButtonText : String, cancelButtonText : String) : Void {
        #if flash
        #elseif js
        // latitude : double, longitude : double, altitude : double, accuracy : double, altitudeAccuracy : double, heading : double, speed : double, time : double
        var successCallback = function(position : PositionGeolocation) {
            onOK(
                position.coords.latitude,
                position.coords.longitude,
                position.coords.altitude,
                position.coords.accuracy,
                position.coords.altitudeAccuracy,
                position.coords.heading,
                position.coords.speed,
                position.timestamp
            );
        };
        var errorCallback = function(positionError : PositionError) {
            onError(positionError.code, positionError.message);
        };
        Geolocation.getCurrentPosition(
            successCallback,
            errorCallback,
            {
                enableHighAccuracy : enableHighAccuracy,
                maximumAge : Std.int(maximumAge),
                timeout : Std.int(timeout)
            }
        );
        #end
    }

    public static function geolocationWatchPosition(onOK : Float -> Float -> Float -> Float -> Float -> Float -> Float -> Float -> Void,
            onError : Int -> String -> Void, enableHighAccuracy : Bool, timeout : Float, maximumAge : Float,
            turnOnGeolocationMessage : String, okButtonText : String, cancelButtonText : String) : Void -> Void {
        #if flash
        #elseif js
        // latitude : double, longitude : double, altitude : double, accuracy : double, altitudeAccuracy : double, heading : double, speed : double, time : double
        var successCallback = function(position : PositionGeolocation) {
            onOK(
                position.coords.latitude,
                position.coords.longitude,
                position.coords.altitude,
                position.coords.accuracy,
                position.coords.altitudeAccuracy,
                position.coords.heading,
                position.coords.speed,
                position.timestamp
            );
        };
        var errorCallback = function(positionError : PositionError) {
            onError(positionError.code, positionError.message);
        };
        var watchID = Geolocation.watchPosition(
            successCallback,
            errorCallback,
            {
                enableHighAccuracy : enableHighAccuracy,
                maximumAge : Std.int(maximumAge),
                timeout : Std.int(timeout)
            }
        );
        return function() { Geolocation.clearWatch(watchID); };
        #end
        return function() {};
    }
}