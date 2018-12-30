import Flow;
import FlowArray;
import GeolocationSupportHx;

class GeolocationSupport {
    public function new(interpreter : Interpreter) {
        this.interpreter = interpreter;
    }

    var interpreter : Interpreter;

    /*
        native geolocationGetCurrentPositionNative : (
            onOK : (latitude : double, longitude : double, altitude : double, accuracy : double, altitudeAccuracy : double, heading : double, speed : double, time : double) -> void,
            onError : (errorCode : int, message : string) -> void,
            enableHighAccuracy : bool, timeout : double, maximumAge : double,
            turnOnGeolocationMessage : string, okButtonText : string, cancelButtonText : string
        ) -> void = GeolocationSupport.geolocationGetCurrentPosition;
    */
    public function geolocationGetCurrentPosition(args : FlowArray<Flow>, pos : Position) : Flow {
        #if flash
        #elseif js
        var cb_onOKRoot = interpreter.registerRoot(args[0]);
        var cb_onErrorRoot = interpreter.registerRoot(args[1]);

        var cb_onOKWrapper = function(latitude, longitude, altitude, accuracy, altitudeAccuracy, heading, speed, time) {
            var r = interpreter.lookupRoot(cb_onOKRoot);
            interpreter.releaseRoot(cb_onOKRoot);
            interpreter.eval(Call(r, FlowArrayUtil.fromArray([
                ConstantDouble(latitude, pos),
                ConstantDouble(longitude, pos),
                ConstantDouble(altitude, pos),
                ConstantDouble(accuracy, pos),
                ConstantDouble(altitudeAccuracy, pos),
                ConstantDouble(heading, pos),
                ConstantDouble(speed, pos),
                ConstantDouble(time, pos)
            ]), pos));
        };

        var cb_onErrorWrapper = function(errorCode, message) {
            var r = interpreter.lookupRoot(cb_onErrorRoot);
            interpreter.releaseRoot(cb_onErrorRoot);
            interpreter.eval(Call(r, FlowArrayUtil.two(ConstantI32(errorCode, pos), ConstantString(message, pos)), pos));
        };

        var enableHighAccuracy = FlowUtil.getBool(args[2]);
        var timeout = FlowUtil.getDouble(args[3]);
        var maximumAge = FlowUtil.getDouble(args[4]);
        var turnOnGeolocationMessage = FlowUtil.getString(args[5]);
        var okButtonText = FlowUtil.getString(args[6]);
        var cancelButtonText = FlowUtil.getString(args[7]);
        GeolocationSupportHx.geolocationGetCurrentPosition(cb_onOKWrapper, cb_onErrorWrapper, enableHighAccuracy, timeout, maximumAge, turnOnGeolocationMessage, okButtonText, cancelButtonText);
        #end

        return ConstantVoid(pos);
    }

    /*
        native geolocationWatchPositionNative : (
            onOK : (latitude : double, longitude : double, altitude : double, accuracy : double, altitudeAccuracy : double, heading : double, speed : double, time : double) -> void,
            onError : (errorCode : int, message : string) -> void,
            enableHighAccuracy : bool, timeout : double, maximumAge : double,
            turnOnGeolocationMessage : string, okButtonText : string, cancelButtonText : string
        ) -> (() -> void) = GeolocationSupport.geolocationWatchPosition;
    */
    public function geolocationWatchPosition(args : FlowArray<Flow>, pos : Position) : Flow {
        #if flash
        #elseif js
        var cb_onOKRoot = interpreter.registerRoot(args[0]);
        var cb_onErrorRoot = interpreter.registerRoot(args[1]);

        var cb_onOKWrapper = function(latitude, longitude, altitude, accuracy, altitudeAccuracy, heading, speed, time) {
            var r = interpreter.lookupRoot(cb_onOKRoot);
            interpreter.eval(Call(r, FlowArrayUtil.fromArray([
                ConstantDouble(latitude, pos),
                ConstantDouble(longitude, pos),
                ConstantDouble(altitude, pos),
                ConstantDouble(accuracy, pos),
                ConstantDouble(altitudeAccuracy, pos),
                ConstantDouble(heading, pos),
                ConstantDouble(speed, pos),
                ConstantDouble(time, pos)
            ]), pos));
        };

        var cb_onErrorWrapper = function(errorCode, message) {
            var r = interpreter.lookupRoot(cb_onErrorRoot);
            interpreter.eval(Call(r, FlowArrayUtil.two(ConstantI32(errorCode, pos), ConstantString(message, pos)), pos));
        };

        var enableHighAccuracy = FlowUtil.getBool(args[2]);
        var timeout = FlowUtil.getDouble(args[3]);
        var maximumAge = FlowUtil.getDouble(args[4]);
        var turnOnGeolocationMessage = FlowUtil.getString(args[5]);
        var okButtonText = FlowUtil.getString(args[6]);
        var cancelButtonText = FlowUtil.getString(args[7]);
        var disposer = GeolocationSupportHx.geolocationWatchPosition(cb_onOKWrapper, cb_onErrorWrapper, enableHighAccuracy, timeout, maximumAge, turnOnGeolocationMessage, okButtonText, cancelButtonText);
        return NativeClosure(0, function(flow, pos) {
            interpreter.releaseRoot(cb_onOKRoot);
            interpreter.releaseRoot(cb_onErrorRoot);
            disposer();
            return ConstantVoid(pos);
        }, pos);
        #end

        //NOP
        return NativeClosure(0, function(flow, pos) {
            return ConstantVoid(pos);
        }, pos);
    }
}