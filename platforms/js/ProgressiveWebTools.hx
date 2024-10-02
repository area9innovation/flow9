#if js
import js.Browser;
import js.html.MessageChannel;
import js.Lib;
#end

class ProgressiveWebTools {
	public function new() {}

	public static function __init__() {
		if (untyped __js__("typeof window !== 'undefined'") && (Browser.window.matchMedia("(display-mode: fullscreen)").matches || Browser.window.matchMedia("(display-mode: standalone)").matches || ~/CapacitorJS/i.match(Browser.window.navigator.userAgent))) {
			var viewport = Browser.document.querySelector('meta[name="viewport"]');

			if (viewport != null && viewport.getAttribute("content").indexOf("viewport-fit") < 0) {
				viewport.setAttribute("content", viewport.getAttribute("content") + ",viewport-fit=cover");
			}
		}
	}

	public static var globalRegistration : Dynamic = null;
	public static var globalInstallPrompt : Dynamic = null;

	public static function enableServiceWorkerCaching(swFilePath : String, callback : Bool -> Void) : Void {
		#if flash
		callback(false);
		#elseif js
		if (untyped navigator.serviceWorker) {
			untyped navigator.serviceWorker.register(swFilePath).then(function(registration) {
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
		} else {
			callback(false);
			trace('No ServiceWorker on this browser');
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

	public static function checkServiceWorkerEnabledOnly(callback : Bool -> Void) : Void {
		#if flash
		callback(false);
		#elseif js
		if (globalRegistration != null && untyped navigator.serviceWorker) {
			callback(true);
		} else {
			callback(false);
		}
		#end
	}

	public static function checkServiceWorkerCachingEnabled(swFileName : String, callback : Bool -> Void) : Void {
		#if !js
		callback(false);
		#else
		if (globalRegistration != null) {
			callback(true);
		} else if (untyped navigator.serviceWorker) {
			untyped navigator.serviceWorker.getRegistrations().then(function(registrations) {
				if (registrations.length == 0) {
					callback(false);
				} else if (untyped registrations.filter(function(registration) {
					if (untyped registration.active == null) {
						return false;
					}

					if (untyped registration.active.scriptURL == (registration.scope + swFileName)) {
						globalRegistration = registration;
						return true;
					} else {
						return false;
					}
				}).length > 0) {
					callback(true);
				} else {
					callback(false);
				}
			}, function(err) {
				callback(false);
			});
		} else {
			callback(false);
			trace('No ServiceWorker on this browser');
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
		} else {
			callback(false);
		}
		#end
	}

	public static function setServiceWorkerPreferCachedResources(prefer : Bool, callback : Bool -> Void) : Void {
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

			untyped navigator.serviceWorker.controller.postMessage({
					"action" : "set_prefer_cached_resources",
					"data" : {
						"value" : prefer
					}
				},
				[messageChannel.port2]
			);
		} else {
			callback(false);
		}
		#end
	}

	public static function setServiceWorkerCacheStaticResources(cache : Bool, callback : Bool -> Void) : Void {
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

			untyped navigator.serviceWorker.controller.postMessage({
					"action" : "set_cache_static_resources",
					"data" : {
						"value" : cache
					}
				},
				[messageChannel.port2]
			);
		} else {
			callback(false);
		}
		#end
	}

	public static function addServiceWorkerDynamicResourcesExtension(extension : String, callback : Bool -> Void) : Void {
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

			untyped navigator.serviceWorker.controller.postMessage({
					"action" : "add_dynamic_resource_extension",
					"data" : {
						"value" : extension
					}
				},
				[messageChannel.port2]
			);
		} else {
			callback(false);
		}
		#end
	}

	public static function removeServiceWorkerDynamicResourcesExtension(extension : String, callback : Bool -> Void) : Void {
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

			untyped navigator.serviceWorker.controller.postMessage({
					"action" : "remove_dynamic_resource_extension",
					"data" : {
						"value" : extension
					}
				},
				[messageChannel.port2]
			);
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

	public static function pdfViewerEnabled(onOK : Bool -> Void, onError : String -> Void) : Void {
		#if flash
		onError("Works only for JS target");
		#elseif js
		if (untyped navigator.serviceWorker && untyped navigator.serviceWorker.controller) {
			onOK(untyped navigator && untyped navigator.pdfViewerEnabled);
		} else {
			onError("ServiceWorker is not initialized");
		}
		#end
	}

	public static function addRequestSkipFilterN(
		skipIfUrlMatch : String,
		skipIfMethodMatch : String,
		skipIfHeaderMatch : Array<String>,
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
					"action" : "requests_skip_filter",
					"data" : {
						"url" : skipIfUrlMatch,
						"method" : skipIfMethodMatch,
						"header" : skipIfHeaderMatch
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
		return !Browser.window.matchMedia("(display-mode: browser)").matches || (Platform.isIOS && untyped Browser.window.navigator.standalone == true);
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

	public static function setUseOnlyCacheInOffline(enabled : Bool, onOK : Void -> Void, onError : String -> Void) : Void {
		#if flash
		onError("Works only for JS target");
		#elseif js
		if (untyped navigator.serviceWorker && untyped navigator.serviceWorker.controller) {
			var messageChannel = new MessageChannel();
			messageChannel.port1.onmessage = function(event) {
				if (event.data.error || event.data.status == null) {
					onError("ServiceWorker can't change the cache parameter");
				} else if (event.data.status == "OK") {
					onOK();
				} else {
					onError("ServiceWorker can't change the cache parameter");
				}
			};

			untyped navigator.serviceWorker.controller.postMessage({
					"action" : "set_use_cache_only_in_offline",
					"enabled" : enabled
				},
				[messageChannel.port2]
			);
		} else {
			onError("ServiceWorker is not initialized");
		}
		#end
	}

	public static function getServiceWorkerRequestsStatsN(onOK : Array<Int> -> Void, onError : String -> Void) : Void {
		#if flash
		onError("Works only for JS target");
		#elseif js
		if (untyped navigator.serviceWorker && untyped navigator.serviceWorker.controller) {
			var messageChannel = new MessageChannel();
			messageChannel.port1.onmessage = function(event) {
				if (event.data.error || event.data.data == null) {
					onError("ServiceWorker can't get requests stats");
				} else {
					onOK([
						event.data.data.fromNetwork,
						event.data.data.fromCache,
						event.data.data.skipped,
						event.data.data.failed
					]);
				}
			};

			untyped navigator.serviceWorker.controller.postMessage({
					"action" : "get_requests_stats"
				},
				[messageChannel.port2]
			);
		} else {
			onError("ServiceWorker is not initialized");
		}
		#end
	}

	public static function resetSwTimings(onOK : Void -> Void, onError : String -> Void) : Void {
		#if flash
		onError("Works only for JS target");
		#elseif js
		if (untyped navigator.serviceWorker && untyped navigator.serviceWorker.controller) {
			var messageChannel = new MessageChannel();
			messageChannel.port1.onmessage = function(event) {
				if (event.data.error || event.data.status == null) {
					onError("ServiceWorker can't reset the timmings");
				} else if (event.data.status == "OK") {
					onOK();
				} else {
					onError("ServiceWorker can't change the cache parameter");
				}
			};

			untyped navigator.serviceWorker.controller.postMessage({
					"action" : "reset_timings"
				},
				[messageChannel.port2]
			);
		} else {
			onError("ServiceWorker is not initialized");
		}
		#end
	}

	public static function getSwTimingsNative(onOK : Array<String> -> Void, onError : String -> Void) : Void {
		#if flash
		onError("Works only for JS target");
		#elseif js
		if (untyped navigator.serviceWorker && untyped navigator.serviceWorker.controller) {
			var messageChannel = new MessageChannel();
			messageChannel.port1.onmessage = function(event) {
				if (event.data.error || event.data.data == null) {
					onError("ServiceWorker can't get requests stats");
				} else {
					onOK(event.data.data.map(function(row) {
						if (row.name == Lib.undefined) row.name = "";
						if (row.operation == Lib.undefined) row.operation = "";
						if (row.startTimestamp == Lib.undefined) row.startTimestamp = "0";
						if (row.duration == Lib.undefined) row.duration = "-1";

						return row.name + "\t" + row.operation + "\t" + row.startTimestamp + "\t" + row.duration + "\t"
							+ row.steps.map(function(step) { return step.name + "\t" + step.time + "\t"; }).join("");
					}));
				}
			};

			untyped navigator.serviceWorker.controller.postMessage({
					"action" : "get_timings"
				},
				[messageChannel.port2]
			);
		} else {
			onError("ServiceWorker is not initialized");
		}
		#end
	}

	public static function getSwTimingsFilterConsoleNative(files : Array<String>, operations : Array<String>) : Void {
		#if flash
		trace("Works only for JS target");
		#elseif js
		if (untyped navigator.serviceWorker && untyped navigator.serviceWorker.controller) {
			var messageChannel = new MessageChannel();
			messageChannel.port1.onmessage = function(event) {
				if (event.data.error || event.data.data == null) {
					trace("ServiceWorker can't get requests stats");
				} else {
					trace("\nfilename - operation - timestamp (msec) - duration (msec):\n" +
						event.data.data
						.map(function(row) {
							if (row.name == Lib.undefined) row.name = "";
							if (row.operation == Lib.undefined) row.operation = "";
							if (row.startTimestamp == Lib.undefined) row.startTimestamp = "0";
							if (row.duration == Lib.undefined) row.duration = "-1";

							return row;
						})
						.filter(function(row) {
							return (files.length == 0 || untyped files.includes(row.name)) && (operations.length == 0 || untyped operations.includes(row.operation));
						})
						.map(function(row) {
							return
								"\"" + row.name + "\"" + " - " +
								"\"" + row.operation + "\"" + " - " +
								row.startTimestamp + " - " +
								row.duration + ":\n" +
									row.steps.map(function(step) { return "\t• \"" + step.name + "\"\t - " + step.time; }).join("\n");
						})
						.join("\n")
					);
				}
			};

			untyped navigator.serviceWorker.controller.postMessage({
					"action" : "get_timings"
				},
				[messageChannel.port2]
			);
		} else {
			trace("ServiceWorker is not initialized");
		}
		#end
	}
}