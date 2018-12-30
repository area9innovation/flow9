#if js
import js.Browser;
import haxe.Timer;
import NativeTime;

// Notification class was removed somehow in the haxe 3.3
// DesktopNotificationCenter was introduced instead
// Although it is supported only in Mozilla
// So we are making those work in all browsers here:
import js.html.EventTarget;
import js.Promise;

// Missing classes from haxe 3.3

@:native("Notification")
extern class Notification extends EventTarget {
    static var permission(default,null) : NotificationPermission;
    
    /** @throws DOMError */
    static function requestPermission( ?permissionCallback : NotificationPermission -> Void ) : Void;
    /** @throws DOMError */
    static function get( ?filter : GetNotificationOptions ) : Promise<Array<Notification>>;
    var onclick : haxe.Constraints.Function;
    var onshow : haxe.Constraints.Function;
    var onerror : haxe.Constraints.Function;
    var onclose : haxe.Constraints.Function;
    var title(default,null) : String;
    var dir(default,null) : NotificationDirection;
    var lang(default,null) : String;
    var body(default,null) : String;
    var tag(default,null) : String;
    var icon(default,null) : String;
    var data(default,null) : Dynamic;
    
    /** @throws DOMError */
    function new( title : String, ?options : NotificationOptions ) : Void;
    function close() : Void;
}

@:enum abstract NotificationPermission(String) {
    var DEFAULT_ = "default";
    var DENIED = "denied";
    var GRANTED = "granted";
}

typedef GetNotificationOptions = {
    @:optional var tag : String;
}

@:enum abstract NotificationDirection(String) {
    var AUTO = "auto";
    var LTR = "ltr";
    var RTL = "rtl";
}

typedef NotificationOptions = {
    @:optional var body : String;
    @:optional var data : Dynamic;
    @:optional var dir : NotificationDirection;
    @:optional var icon : String;
    @:optional var lang : String;
    @:optional var tag : String;
}
#end

class NotificationsSupportHx {
    public function new() {}

    public static function __init__() {
    }

    public static function hasPermissionLocalNotification() : Bool {
        var result = false;

        #if flash
        #elseif js
        result = untyped __typeof__(Notification) != "undefined" 
                && Notification.permission == GRANTED;
        #end

        return result;
    }

    public static function requestPermissionLocalNotification(cb : Bool -> Void) : Void {
        #if flash
        #elseif js
        if (untyped __typeof__(Notification) == "undefined") {
            cb(false);
            return;
        }

        Notification.requestPermission(function(permission : NotificationPermission) {
            cb(permission == GRANTED);
        });
        #end
    }

    #if js
    private static var FlowLocalNotificationCallbacks : Array< Int-> String -> Void > = new Array< Int-> String -> Void >();
    private static var timersForScheduledNotifications : Map<String, Timer> = new Map<String, Timer>();
    private static var createdNotifications : Map<String, Notification> = new Map<String, Notification>();

    private static function executeNotificationCallbacks(notificationId : Int, notificationCallbackArgs : String) : Void {
        for (cb in FlowLocalNotificationCallbacks.slice(0, FlowLocalNotificationCallbacks.length)) cb(notificationId, notificationCallbackArgs);
    }
    #end

    public static function addOnClickListenerLocalNotification(cb : Int -> String -> Void) : Void -> Void {
        #if flash
        #elseif js
        FlowLocalNotificationCallbacks.push(cb);
        return function() { FlowLocalNotificationCallbacks.remove(cb); };
        #end

        // NOP
        return function() { };
    }

    public static function scheduleLocalNotification(time : Float, notificationId : Int, notificationCallbackArgs : String, notificationTitle : String, notificationText : String, withSound : Bool) : Void {
        #if flash
        #elseif js
        // Notificaitons API is not available
        if (untyped __typeof__(Notification) == "undefined") return;

        NotificationsSupportHx.cancelLocalNotification(notificationId);
        var timer = haxe.Timer.delay(
            function() {
                var strNotificationId : String = Std.string(notificationId);
                var notification : Notification = new Notification(
                    notificationTitle,
                    {
                        body : notificationText,
                        tag : strNotificationId
                    }
                );
                notification.onclick = function() {
                    executeNotificationCallbacks(notificationId, notificationCallbackArgs);
                };
                notification.onclose = function() {
                    createdNotifications.remove(strNotificationId);
                };
                notification.onshow = function() {
                    if (timersForScheduledNotifications.exists(strNotificationId)) {
                        timersForScheduledNotifications.remove(strNotificationId);
                    }
                };
                createdNotifications.set(strNotificationId, notification);
            },
            Std.int(time - NativeTime.timestamp())
        );
        timersForScheduledNotifications.set(Std.string(notificationId), timer);
        #end
    }

    public static function cancelLocalNotification(notificationId : Int) : Void {
        #if flash
        #elseif js
        var strNotificationId : String = Std.string(notificationId);
        if (timersForScheduledNotifications.exists(strNotificationId)) {
            timersForScheduledNotifications.get(strNotificationId).stop();
            timersForScheduledNotifications.remove(strNotificationId);
        } else if (createdNotifications.exists(strNotificationId)) {
            createdNotifications.get(strNotificationId).close();
            createdNotifications.remove(strNotificationId);
        }
        #end
    }

    public static function setBadgerCount(value : Int) : Void {
        // Not require to be implemented for these targets
    }

    public static function getBadgerCount() : Int {
        return 0;
    }
}