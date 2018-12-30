import Flow;
import FlowArray;
import NotificationsSupportHx;

class NotificationsSupport {
    public function new(interpreter : Interpreter) {
        this.interpreter = interpreter;
    }
    
    var interpreter : Interpreter;
    //private static var notificationsSupportHx : NotificationsSupportHx = new NotificationsSupportHx();

    public function hasPermissionLocalNotification(args : FlowArray<Flow>, pos : Position) : Bool {
        var result = false;

        #if flash
        #elseif js
        result = NotificationsSupportHx.hasPermissionLocalNotification();
        #end

        return result;
    }

    public function requestPermissionLocalNotification(args : FlowArray<Flow>, pos : Position) : Flow {
        #if flash
        #elseif js
        var cb_root = interpreter.registerRoot(args[0]);
        var cb_wrapper = function(hasPermission : Bool) {
            var r = interpreter.lookupRoot(cb_root);
            interpreter.releaseRoot(cb_root);
            interpreter.eval(Call(r, FlowArrayUtil.one(ConstantBool(hasPermission, pos)), pos));
        };
        NotificationsSupportHx.requestPermissionLocalNotification(cb_wrapper);
        #end

        return ConstantVoid(pos);
    }

    public function addOnClickListenerLocalNotification(args : FlowArray<Flow>, pos : Position) : Flow {
        #if flash
        #elseif js
        var cb_root = interpreter.registerRoot(args[0]);
        var cb_wrapper = function(notificationId : Int, notificationCallbackArgs : String) {
            var r = interpreter.lookupRoot(cb_root);
            interpreter.eval(Call(r, FlowArrayUtil.two(ConstantI32(notificationId, pos), ConstantString(notificationCallbackArgs, pos)), pos));
        };
        var disposer = NotificationsSupportHx.addOnClickListenerLocalNotification(cb_wrapper);
        return NativeClosure(0, function(flow, pos) {
            interpreter.releaseRoot(cb_root);
            disposer();
            return ConstantVoid(pos);
        }, pos);
        #end

        //NOP
        return NativeClosure(0, function(flow, pos) {
            return ConstantVoid(pos);
        }, pos);
    }

    public function scheduleLocalNotification(args : FlowArray<Flow>, pos : Position) : Flow {
        #if flash
        #elseif js
        var time = FlowUtil.getDouble(args[0]);
        var notificationId = FlowUtil.getInt(args[1]);
        var notificationCallbackArgs = FlowUtil.getString(args[2]);
        var notificationTitle = FlowUtil.getString(args[3]);
        var notificationText = FlowUtil.getString(args[4]);
        var withSound = FlowUtil.getBool(args[5]);
        NotificationsSupportHx.scheduleLocalNotification(time, notificationId, notificationCallbackArgs, notificationTitle, notificationText, withSound);
        #end

        return ConstantVoid(pos);
    }

    public function cancelLocalNotification(args : FlowArray<Flow>, pos : Position) : Flow {
        #if flash
        #elseif js
        var notificationId = FlowUtil.getInt(args[0]);
        NotificationsSupportHx.cancelLocalNotification(notificationId);
        #end

        return ConstantVoid(pos);
    }

    public function setBadgerCount(args : FlowArray<Flow>, pos : Position) : Flow {
        var count = FlowUtil.getInt(args[0]);
        NotificationsSupportHx.setBadgerCount(count);

        return ConstantVoid(pos);
    }

    public function getBadgerCount(args : FlowArray<Flow>, pos : Position) : Flow {
        return ConstantI32(NotificationsSupportHx.getBadgerCount(), pos);
    }
}