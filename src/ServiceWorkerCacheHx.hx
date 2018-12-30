#if js
import js.Browser;
#end

class ServiceWorkerCacheHx {
    public function new() {}

    public static function __init__() {
    }

    public static var globalRegistration : Dynamic = null;
    public static var serviceWorkerFilePath : String = "sw.min.js";

    public static function registerCacheServiceWorker(callback : Bool -> Void) : Void {
        #if flash
        callback(false);
        #elseif js
        if (untyped navigator.serviceWorker) {
            untyped navigator.serviceWorker.register(serviceWorkerFilePath).then(function(registration) {
                trace('ServiceWorker registration successful with scope: ', registration.scope);

                globalRegistration = registration;
                callback(true);
            }, function(err) {
                trace('ServiceWorker registration failed: ', err);
                callback(false);
            });
        }
        #end
    }

    public static function unregisterCacheServiceWorker(callback : Bool -> Void) : Void {
        #if flash
        callback(false);
        #elseif js
        if (globalRegistration != null) {
            untyped globalRegistration.unregister().then(function() {
                callback(true);
            }, function(err) {
                callback(false);
            });
        }
        #end
    }

    public static function checkCacheServiceWorkerRegistered(callback : Bool -> Void) : Void {
        #if flash
        callback(false);
        #elseif js
        if (globalRegistration != null) {
            callback(true);
            return;
        }

        if (untyped navigator.serviceWorker) {
            untyped navigator.serviceWorker.getRegistrations().then(function(registrations) {
                if (registrations.length == 0) {
                    callback(false);
                }

                untyped Promise.race(untyped registrations.map(function(registration) {
                    if (untyped registration.active == null) {
                        return Promise.reject();
                    }

                    if (untyped registration.active.scriptURL == (registration.scope + serviceWorkerFilePath)) {
                        globalRegistration = registration;
                        return Promise.resolve();
                    } else {
                        return Promise.reject();
                    }
                })).then(function() {
                    callback(true);
                }, function() {
                    callback(false);
                });
            }, function(err) {
                callback(false);
            });
        }
        #end
    }
}