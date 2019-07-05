#if js
import js.Browser;
#end

class ProgressiveWebTools {
	public function new() {}

	public static function __init__() {
	}

	public static var globalRegistration : Dynamic = null;
	public static var globalInstallPrompt : Dynamic = null;
	public static var serviceWorkerFilePath : String = "sw.min.js";

	public static function enableServiceWorkerCaching(callback : Bool -> Void) : Void {
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

	public static function disableServiceWorkerCaching(callback : Bool -> Void) : Void {
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

	public static function checkServiceWorkerCachingEnabled(callback : Bool -> Void) : Void {
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

	public static function addShortcutAvailableListener(callback : Void -> Void) : Void -> Void {
		#if js
		var event = 'beforeinstallprompt';
		var handler = function(e) {
			e.preventDefault();
			globalInstallPrompt = e;

			callback();
		};

		Browser.window.addEventListener(event, handler);

		return function() { Browser.window.removeEventListener(event, handler); }
		#else
		return function() {};
		#end
	}

	public static function installShortcut(callback : Bool -> Void) : Void {
		#if js
		if (globalInstallPrompt == null) {
			Errors.warning("Progressive shortcut: You are not allowed to show install prompt until progressiveShortcutInstallAvailable listener fires.");
			return;
		}

		untyped globalInstallPrompt.prompt();

		untyped globalInstallPrompt.userChoice.then(function(choiceResult) {
			callback(untyped choiceResult.outcome == "accepted");

			globalInstallPrompt = null;
		});
		#else
		#end
	}

	public static function cleanServiceWorkerCache(callback : Bool -> Void) : Void {
		#if flash
		callback(false);
		#elseif js
		if (untyped navigator.serviceWorker && untyped navigator.serviceWorker.controller) {
			untyped navigator.serviceWorker.controller.postMessage({"action" : "clean_cache_storage"});
			callback(true);
		} else {
			callback(false);
		}
		#end
	}

	public static function addRequestCacheFilterN(
		cacheIfUrlMatch : String,
		method : String,
		cacheIfParametersMatch : Array<Array<String>>,
		ignoreParameterKeysOnCache : Array<String>,
		onOK : Void -> Void,
		onError : String -> Void
	) : Void {
		#if flash
		onError("Works only for JS target");
		#elseif js
		if (untyped navigator.serviceWorker && untyped navigator.serviceWorker.controller) {
			untyped navigator.serviceWorker.controller.postMessage({
				"action" : "requests_cache_filter",
				"data" : {
					"cacheIfUrlMatch" : cacheIfUrlMatch,
					"method" : method,
					"cacheIfParametersMatch" : cacheIfParametersMatch,
					"ignoreParameterKeysOnCache" : ignoreParameterKeysOnCache
				}
			});
			onOK();
		} else {
			onError("ServiceWorker is not initialized");
		}
		#end
	}

	public static function isRunningPWA() : Bool {
		return !Browser.window.matchMedia("(display-mode: browser)").matches;
	}
}