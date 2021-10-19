#if js
import js.Browser;
import haxe.Timer;
import NativeTime;
import js.html.MessageChannel;

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

class NotificationsSupport {
    private static var messaging : Dynamic;
    private static var globalFBRegistration : Dynamic = null;
    private static var subscribedOnBackgroundMessage : Bool = false;

    private static var onNotificationFBListeners : Array<Dynamic> = [];
    private static var onTokenResreshFBListeners : Array<Dynamic> = [];


    public function new() {}

    public static function __init__() {
    }

    public static function hasPermissionLocalNotification() : Bool {
        var result = false;

        #if flash
        #elseif js
        result = untyped __js__("typeof Notification !== 'undefined'")
                && Notification.permission == GRANTED;
        #end

        return result;
    }

    public static function requestPermissionLocalNotification(cb : Bool -> Void) : Void {
        #if flash
        #elseif js
        if (untyped __js__("typeof Notification === 'undefined'")) {
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

    public static function scheduleLocalNotification(time : Float, notificationId : Int, notificationCallbackArgs : String, notificationTitle : String, notificationText : String, withSound : Bool, pinNotification : Bool, notificationIconUrl : String) : Void {
        #if flash
        #elseif js
        // TODO: Implement pin notification if possible
        // Notificaitons API is not available
        if (untyped __js__("typeof Notification === 'undefined'")) return;

        NotificationsSupport.cancelLocalNotification(notificationId);
        var timer = haxe.Timer.delay(
            function() {
                var strNotificationId : String = Std.string(notificationId);
                var notification : Notification = new Notification(
                    notificationTitle,
                    {
                        body : notificationText,
                        tag : strNotificationId,
                        icon : notificationIconUrl != "" ? notificationIconUrl : null
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

    public static function initializeFBApp(onReady : Void->Void) : Void {
    #if (js && !flow_nodejs)
        if (untyped window.firebase) {
            onReady();
        } else {
            var appPromise = Util.loadJS("js/firebase/firebase-app.js");
            var configPromise = Util.loadJS("js/firebase/firebase-config.js");
            Promise.all([appPromise, configPromise]).then(function(res) {
                untyped __js__("firebase.initializeApp(firebaseConfig)");
                Util.loadJS("js/firebase/firebase-messaging.js").then(function(res) {
                    messaging = untyped firebase.messaging();
                    messaging.usePublicVapidKey(untyped vapidKey);
                    if (untyped navigator.serviceWorker) {
                        untyped navigator.serviceWorker.register('js/firebase/firebase-messaging-sw.js').then(function(registration) {
                            messaging.useServiceWorker(registration);
                            globalFBRegistration = registration;

                            messaging.onMessage(function(payload) {
                                var data : Array<Array<String>> = [];
                                for(key in (Object.keys(payload.data) : Array<String>)) {
                                    data.push([key, payload.data[key]]);
                                }
                                var title = (payload.notification && payload.notification.title) ? payload.notification.title : (payload.data && payload.data.title ? payload.data.title : "Undefined");
                                var body = (payload.notification && payload.notification.body) ? payload.notification.body : (payload.data && payload.data.body ? payload.data.body : "Undefined");

                                for(listener in onNotificationFBListeners) {
                                    listener(payload.data["google.c.a.c_id"],
                                        title,
                                        body,
                                        payload.from,
                                        payload.data["google.c.a.ts"] * 1000,
                                        data
                                    );
                                }
                            });
                            messaging.onTokenRefresh(function() {
                                messaging.getToken().then(function(token){
                                    for(listener in onTokenResreshFBListeners) {
                                        listener(token);
                                    }
                                }, function(error) {});
                            });

                            messaging.requestPermission().then(function(){
                                onReady();
                            }, function(e) {});
                        }, function(e) {});
                    }
                }, function(e){});
            }, function(e) {});
        }
    #end
    }

    public static function addFBNotificationListener(
        listener : String->String->String->String->Int->Array<Array<String>>->Void
	) : (Void -> Void) {
        onNotificationFBListeners.push(listener);
        return function(){
            onNotificationFBListeners.remove(listener);
        };
    }

    public static function onRefreshFBToken(listener : String->Void) : Void->Void {
        onTokenResreshFBListeners.push(listener);
        return function() {
            onTokenResreshFBListeners.remove(listener);
        };
    }

    public static function getFBToken(callback : String->Void) : Void {
    #if (js && !flow_nodejs)
        messaging.getToken().then(callback, function(err){});
    #end
    }

    private static function callFirebaseServiceSubscription(doSubscribe : Bool, topic : String) : Void {
    #if (js && !flow_nodejs)
        untyped messaging.getToken().then(function(token) {
            HttpSupport.httpRequest("php/firebase/messaging.php", 
                true,
                [[]],
                [
                    ["doSubscribe", doSubscribe],
                    ["topic", topic],
                    ["token", token]
                ],
                function(data) {},
                function(err) {},
                function(status) {}
            );
        }, function(err) {});
    #end
    }

    public static function subscribeToFBTopic(name : String) : Void {
    #if (js && !flow_nodejs)
        callFirebaseServiceSubscription(true, name);
    #end
    }

    public static function unsubscribeFromFBTopic(name : String) : Void {
    #if (js && !flow_nodejs)
        callFirebaseServiceSubscription(false, name);
    #end
    }

    public static function subscribeOnBackgroundMessages(
        delay : Int,
        onOK : Void -> Void,
        onError : String -> Void
    ) : (Void -> Void) {
        #if flash
        onError("Works only for JS target");
        #elseif js
        if (globalFBRegistration && !subscribedOnBackgroundMessage) {
            var messageChannel = new MessageChannel();
            var registerResultEnt = false;
            
            messageChannel.port1.onmessage = function(event) {
                if (event.data.action != null) {
                    if (event.data.action == "subscribe_on_messages" || event.data.action == "unsubscribe_from_messages") {
                        if (registerResultEnt) {
                            /*skip onOK/onError callbacks*/
                        } else if (event.data.error || event.data.status == null) {
                            onError("ServiceWorker can't subscribe on messages");
                        } else if (event.data.status == "OK") {
                            subscribedOnBackgroundMessage = true;
                            onOK();
                        } else {
                            onError("ServiceWorker can't subscribe on messages");
                        }
                        registerResultEnt = true;
                    } else if (event.data.action == "notification") {
                        if (subscribedOnBackgroundMessage) {
                            for(listener in onNotificationFBListeners) {
                                listener(event.data.id,
                                    event.data.title,
                                    event.data.body,
                                    event.data.from,
                                    event.data.stamp * 1000,
                                    event.data.data
                                );
                            }
                        }
                    } else {
                        trace("Unsupported responce");
                    }
                }
            };

            globalFBRegistration.active.postMessage({
                    "action" : "subscribe_on_messages",
                    "delay" : delay
                },
                [messageChannel.port2]
            );

            return function() {
                subscribedOnBackgroundMessage = false;
                globalFBRegistration.active.postMessage({
                        "action" : "unsubscribe_from_messages"
                    },
                    [messageChannel.port2]
                );
            };
        } else {
            onError("ServiceWorker is not initialized");
            return function() { /*nothing*/ };
        }
        #end
    }

}
