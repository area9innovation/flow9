#if js
import js.Browser;
import js.html.MessageChannel;
import js.html.Location;
import js.html.Window;
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
				if (registration.active) {
					callback(true);
				} else {
					navigator.serviceWorker.oncontrollerchange = function(e) {
						callback(true);
					};
				}
			}, function(err) {
				trace('ServiceWorker registration failed: ', err);
				callback(false);
			});
		}
		#end
	}

	public static function subscribeOnServiceWorkerUpdateFound(onUpdateFound : Void -> Void, onError : String -> Void) {
		#if flash
		callback(false);
		#elseif js
		if (globalRegistration != null) {
			globalRegistration.onupdatefound = function() {
				var installingWorker = globalRegistration.installing;
				installingWorker.onstatechange = function() {
					if (installingWorker.state == 'installed') {
						onUpdateFound();
					}
				};
			}
		} else {
			onError("ServiceWorker is not initialized");
		}
		#end
	}

	public static function disableServiceWorkerCaching(callback : Bool -> Void) : Void {
		#if flash
		callback(false);
		#elseif js
		if (globalRegistration != null) {
			untyped globalRegistration.unregister().then(function() {
				globalRegistration = null;
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
			var messageChannel = new MessageChannel();
			messageChannel.port1.onmessage = function(event) {
				if (event.data.error || event.data.status == null) {
					callback(false);
				} else if (event.data.status == "OK") {
					callback(true);
				} else {
					callback(false);
				}
			};

			untyped navigator.serviceWorker.controller.postMessage({"action" : "clean_cache_storage"}, [messageChannel.port2]);
			callback(true);
		} else {
			callback(false);
		}
		#end
	}

	public static function addRequestCacheFilterN(
		cacheIfUrlMatch : String,
		cacheIfMethodMatch : String,
		cacheIfParametersMatch : Array<Array<String>>,
		ignoreParameterKeysOnCache : Array<String>,
		onOK : Void -> Void,
		onError : String -> Void
	) : Void {
		#if flash
		onError("Works only for JS target");
		#elseif js
		if (untyped navigator.serviceWorker && untyped navigator.serviceWorker.controller) {
			var messageChannel = new MessageChannel();
			messageChannel.port1.onmessage = function(event) {
				if (event.data.error || event.data.status == null) {
					onError("ServiceWorker can't to add request filter");
				} else if (event.data.status == "OK") {
					onOK();
				} else {
					onError("ServiceWorker can't to add request filter");
				}
			};

			untyped navigator.serviceWorker.controller.postMessage({
					"action" : "requests_cache_filter",
					"data" : {
						"cacheIfUrlMatch" : cacheIfUrlMatch,
						"method" : cacheIfMethodMatch,
						"cacheIfParametersMatch" : cacheIfParametersMatch,
						"ignoreParameterKeysOnCache" : ignoreParameterKeysOnCache
					}
				},
				[messageChannel.port2]
			);
		} else {
			onError("ServiceWorker is not initialized");
		}
		#end
	}

	public static function loadAndCacheUrls(
		urls : Array<String>,
		ignoreParameterKeysOnCache : Array<String>,
		onOK : Void -> Void,
		onError : String -> Void
	) : Void {
		#if flash
		onError("Works only for JS target");
		#elseif js
		if (untyped navigator.serviceWorker && untyped navigator.serviceWorker.controller) {
			var messageChannel = new MessageChannel();
			messageChannel.port1.onmessage = function(event) {
				if (event.data.error || event.data.status == null) {
					onError("ServiceWorker can't execute one or more requests");
				} else if (event.data.status == "OK") {
					onOK();
				} else {
					onError("ServiceWorker can't execute one or more requests");
				}
			};

			untyped navigator.serviceWorker.controller.postMessage({
					"action" : "load_and_cache_urls",
					"data" : {
						"urls" : urls,
						"ignoreParameterKeysOnCache" : ignoreParameterKeysOnCache
					}
				},
				[messageChannel.port2]
			);
		} else {
			onError("ServiceWorker is not initialized");
		}
		#end
	}

	public static function checkUrlsInServiceWorkerCache(urls : Array<String>, onOK : Array<String> -> Void, onError : String -> Void) : Void {
		#if flash
		onError("Works only for JS target");
		#elseif js
		if (untyped navigator.serviceWorker && untyped navigator.serviceWorker.controller) {
			var messageChannel = new MessageChannel();
			messageChannel.port1.onmessage = function(event) {
				if (event.data.error || event.data.status == null || event.data.urls == null) {
					onError("ServiceWorker can't return the cache state");
				} else if (event.data.status == "OK") {
					onOK(event.data.urls);
				} else {
					onError("ServiceWorker can't return the cache state");
				}
			};

			untyped navigator.serviceWorker.controller.postMessage({
					"action" : "check_urls_in_cache",
					"data" : { "urls" : urls }
				},
				[messageChannel.port2]
			);
		} else {
			onError("ServiceWorker is not initialized");
		}
		#end
	}

	public static function isRunningPWA() : Bool {
		return !Browser.window.matchMedia("(display-mode: browser)").matches;
	}

	public static function getServiceWorkerJsVersion(
		onOK : Int -> Void,
		onError : String -> Void
	) : Void {
		#if flash
		onError("Works only for JS target");
		#elseif js
		if (untyped navigator.serviceWorker && untyped navigator.serviceWorker.controller) {
			var messageChannel = new MessageChannel();
			messageChannel.port1.onmessage = function(event) {
				if (event.data.error || event.data.data == null) {
					onError("ServiceWorker can't execute one or more requests");
				} else {
					onOK(event.data.data);
				}
			};

			untyped navigator.serviceWorker.controller.postMessage({
					"action" : "get_service_worker_version"
				},
				[messageChannel.port2]
			);
		} else {
			onError("ServiceWorker is not initialized");
		}
		#end
	}
}