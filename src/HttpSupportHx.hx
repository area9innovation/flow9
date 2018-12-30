#if js
#if flow_nodejs
import js.node.Http;
import js.node.Https;
import js.node.http.IncomingMessage;

import js.node.Url;
import js.node.Querystring;
#else
import js.Browser;
import js.html.XMLHttpRequest;
import HttpCustom;
#end
import JSBinflowBuffer;
import js.html.Uint8Array;
#end

class HttpSupportHx
{
	static var TimeoutInterval = 600000;	// Ten minutes in ms

	#if (js && !flow_nodejs)
	private static var XMLHttpRequestOverriden : Bool = false;
	private static var CORSCredentialsEnabled = true;
	private static function overrideXMLHttpRequest() {
		XMLHttpRequestOverriden = true;

		untyped __js__("
			XMLHttpRequest.prototype.realSend = XMLHttpRequest.prototype.send;
			var newSend = function(vData) { this.withCredentials = HttpSupportHx.CORSCredentialsEnabled; this.realSend(vData); };
			XMLHttpRequest.prototype.send = newSend;
		");
	}

	private static function isBinflow(url : String) : Bool {
		var binflow_pos  = url.indexOf(".binflow");
		var q_pos = url.indexOf("?");
		return  binflow_pos > 0 && (q_pos > 0 ? binflow_pos < q_pos : true);
	}

	private static function doBinflowHttpRequest(url : String, onDataFn : String -> Void, onErrorFn : String -> Void, onProgressFn : Float -> Float -> Void, onStatusFn : Int -> Void) : Void {
		var xhr = untyped __js__ ('new XMLHttpRequest();');
		xhr.open("GET", url, true);
		xhr.responseType = "arraybuffer";
		xhr.onload = function (oEvent) {
			if (onStatusFn != null) onStatusFn(xhr.status);
			if (xhr.status != 200)  { onErrorFn("HTTP error : " + xhr.status); return; }
			var arr = new Uint8Array(xhr.response);
			if (xhr.response.byteLength >= 2) {// BOM should present
				onDataFn(untyped new JSBinflowBuffer(xhr.response, 2, cast (xhr.response.byteLength - 2), arr[0] == 0xFF));
			} else {
				onDataFn(untyped new JSBinflowBuffer(xhr.response, 0, 0, true));
			}
		};
		xhr.addEventListener("error", function(e : Dynamic) { onErrorFn("IO error"); }, false);
		if (onProgressFn != null) xhr.addEventListener("progress", function(e : Dynamic) { if (e.lengthComputable) onProgressFn(e.loaded, e.total); }, false);
		xhr.send(null);
	}

	private static function doBinaryHttpRequest(url : String, onDataFn : String -> Void, onErrorFn : String -> Void, onProgressFn : Float -> Float -> Void, onStatusFn : Int -> Void) : Void {
		var xhr = untyped __js__ ('new XMLHttpRequest();');
		xhr.open("GET", url, true);
		xhr.responseType = "arraybuffer";
		xhr.onload = function (oEvent) {
			if (onStatusFn != null) onStatusFn(xhr.status);
			if (xhr.status != 200)  { onErrorFn("HTTP error : " + xhr.status); return; }
			var arr = new Uint8Array(xhr.response);
			onDataFn(untyped arr);
		};
		xhr.addEventListener("error", function(e : Dynamic) { onErrorFn("IO error"); }, false);
		if (onProgressFn != null) xhr.addEventListener("progress", function(e : Dynamic) { if (e.lengthComputable) onProgressFn(e.loaded, e.total); }, false);
		xhr.send(null);
	}

	public static function enableCORSCredentials(enabled : Bool) : Void {
		CORSCredentialsEnabled = enabled;
	}
	#end

	public static function printHttpRequestDetails(url : String, params : Array<Array<String>>) : Void {
		NativeHx.println("======= HTTP request details:");
		NativeHx.println("URL: " + url);
		NativeHx.println("Parameters: ");
		for (param in params) {
			NativeHx.println(param[0] + ": "+ param[1]);
		}
		NativeHx.println("=======");
	}

	#if (js && flow_nodejs)
	private static function parseUrlToNodeOptions(url : String) : HttpsRequestOptions {
		var options = Url.parse(url);

		var port 	 = Std.parseInt(options.port);
		var protocol = options.protocol;
		var hostname = options.hostname;
		if (port == null) {
			port = protocol == "https:" ? 443 : 80;
		}

		if (protocol == null) {
			protocol = untyped request.protocol + ":";
		}

		if (hostname == null) {
			hostname = untyped request.hostname;
		}

		return {
			protocol: protocol,
			host: hostname + ":" + port,
			hostname: hostname,
			port: port,
			path: options.path,
			auth: options.auth
		};
	}
	#end

	public static function httpRequest(url : String, post : Bool, headers : Array<Array<String>>,
		params : Array<Array<String>>, onDataFn : String -> Void, onErrorFn : String -> Void, onStatusFn : Int -> Void) : Void {
		#if flow_nodejs

		var options : HttpsRequestOptions = parseUrlToNodeOptions(url);

		options.method = post ? "POST" : "GET";
		options.headers = {};

		headers.map(function(pair) {
			options.headers[pair[0]] = pair[1];
		});

		if (options.headers["Content-Type"] == null) {
			options.headers["Content-Type"] = "application/x-www-form-urlencoded";
		}

		var queryString = "";
		params.map(function(pair) {
			var key = pair[0];
			var val = pair[1];

			queryString += key + "=" + Querystring.escape(val) + "&";
		});

		queryString = queryString.substr(0, queryString.length - 1);

		var responseHandler = function(response : IncomingMessage) {
			response.setEncoding('utf8');

			if (response.statusCode == 301) {
				// We have to redirect to the correct Location url
				httpRequest(untyped response.headers.location, post, headers, params, onDataFn, onErrorFn, onStatusFn);

				return;
			}

			onStatusFn(response.statusCode);

			var rawData = "";
			response.on('error', function(error) {
				onErrorFn(error);
			}).on('data', function(data) {
				rawData += data;
			}).on('end', function(error) {
				if (response.statusCode >= 200 && response.statusCode < 400)
					onDataFn(rawData);
				else
					onErrorFn(rawData);
			});
		};

		var request = null;
		if (options.protocol == "https:") {
			request = Https.request(options, responseHandler);
		} else {
			request = Http.request(options, responseHandler);
		}

		request.on('error', function(error) {
			onStatusFn(0);
			onErrorFn(error.message);
		});

		request.write(queryString);
		request.end();
		#else
		#if js
		if (!XMLHttpRequestOverriden) overrideXMLHttpRequest();

		if (isBinflow(url) && Util.getParameter("arraybuffer") != "0") {
			var query = Lambda.fold(params, function(kv, query) {
    			return query + "&" + kv[0] + "=" + kv[1];
    		}, "");

			if (url.indexOf("?") < 0) query = "?" + query;
			else query = "&" + query;

			doBinflowHttpRequest(url + query, onDataFn, onErrorFn, null, onStatusFn);
			return;
		}
		#end

		var handled = false;	// Whether the request has already completed, failed or timed out

		// Set up timeout
		var checkTimeout = function() {
			if (!handled) {
				handled = true;
				onErrorFn(url + ": request timed out");
			}
		}
		var timeoutInspector = haxe.Timer.delay(checkTimeout, TimeoutInterval);

		var http = new haxe.Http(url);

		http.onData = function (res: String) {
			if (!handled) {
				handled = true;
				timeoutInspector.stop();
				try {
					onDataFn(res);
				} catch (e : Dynamic) {
					NativeHx.println("FATAL ERROR: http.onData reported: " + e);
					HttpSupportHx.printHttpRequestDetails(url, params);
					Assert.printExnStack("Trace: :");
					NativeHx.callFlowCrashHandlers("[HTTP onData]: " + e);
				}
			} else {
				// Ignore result as the request most probably timed out and onError was called already
			}
		}

		http.onError = function (err: String) {
			if (!handled) {
				handled = true;
				timeoutInspector.stop();
				try {
					onErrorFn(err);
				} catch (e : Dynamic) {
					NativeHx.println("FATAL ERROR: http.onError reported: " + e);
					HttpSupportHx.printHttpRequestDetails(url, params);
					Assert.printExnStack("Trace: :");
					NativeHx.callFlowCrashHandlers("[HTTP onError]: " + e);
				}
			} else {
				// Ignore error as the request most probably timed out and onError was called already
			}
		}

		http.onStatus = function(status: Int) {
			if (!handled) {
				try {
					onStatusFn(status);
				} catch (e : Dynamic) {
					NativeHx.println("FATAL ERROR: http.onStatus reported: " + e);
					HttpSupportHx.printHttpRequestDetails(url, params);
					Assert.printExnStack("Trace: :");
					NativeHx.callFlowCrashHandlers("[HTTP onStatus]: " + e);
				}

				if (status < 200 || status >= 400) {
					// There was probably an error with the request
					Errors.report("Http request to " + url + " returned status: " + status);
				}
			} else {
				// Nothing to do, we have handled the request already
			}
		}

		// setting parameters
		for (param in params) {
			http.setParameter(param[0], param[1]);
		}

		// and headers
		for (header in headers) {
			http.setHeader(header[0], header[1]);
		}

		#if js
		http.async = true;
		#end

		http.request(post);
		#end
	}

	public static function httpCustomRequestNative(url : String, method : String, headers : Array<Array<String>>,
		params: Array<Array<String>>, data : String, onResponseFn : Int -> String -> Array<Array<String>> -> Void, async : Bool) : Void {

		if ((method == 'DELETE' || method == 'PATCH' || method == "PUT") && !Lambda.exists(headers, function(h) return h[0] == "If-Match")) {
			headers.push(["If-Match", "*"]);
		}

		#if flow_nodejs
		var options : HttpsRequestOptions = parseUrlToNodeOptions(url);

		options.method = method;
		options.headers = {};

		headers.map(function(pair) {
			options.headers[pair[0]] = pair[1];
		});

		if (options.headers["Content-Type"] == null) {
			options.headers["Content-Type"] = "application/x-www-form-urlencoded";
		}

		if (data == "") {
			var queryString = "";
			params.map(function(pair) {
				var key = pair[0];
				var val = pair[1];

				queryString += key + "=" + Querystring.escape(val) + "&";
			});

			queryString = queryString.substr(0, queryString.length - 1);

			data = queryString;
		}

		var responseHandler = function(response : IncomingMessage) {
			response.setEncoding('utf8');

			if (response.statusCode == 301) {
				// We have to redirect to the correct Location url
				httpCustomRequestNative(untyped response.headers.location, method, headers, params, data, onResponseFn, async);

				return;
			}

			var responseHeaders : Array<Array<String>> = new Array();
			response.headers.keys().map(function (key) {
				responseHeaders.push([key, response.headers[key]]);
			});

			var rawData = "";
			response.on('error', function(error) {
				onResponseFn(response.statusCode, error, responseHeaders);
			}).on('data', function(data) {
				rawData += data;
			}).on('end', function(error) {
				onResponseFn(response.statusCode, rawData, responseHeaders);
			});
		};

		var request = null;
		if (options.protocol == "https:") {
			request = Https.request(options, responseHandler);
		} else {
			request = Http.request(options, responseHandler);
		}

		request.on('error', function(error) {
			onResponseFn(0, error.message, []);
		});

		request.write(data);
		request.end();
		#else
		var handled = false;	// Whether the request has already completed, failed or timed out

		// Set up timeout
		var checkTimeout = function() {
			if (!handled) {
				handled = true;
				onResponseFn(408, url + ": request timed out", []);
			}
		}
		var timeoutInspector = haxe.Timer.delay(checkTimeout, TimeoutInterval);

		#if js
		var http = new HttpCustom(url, method);
		#else
		var http = new HttpCustom(url);
		#end

		if (data != "") {
			http.setPostData(data);
		}

		#if js

		if (!XMLHttpRequestOverriden) overrideXMLHttpRequest();

		if (isBinflow(url) && Util.getParameter("arraybuffer") != "0") {
			var query = Lambda.fold(params, function(kv, query) {
    			return query + "&" + kv[0] + "=" + kv[1];
    		}, "");

			if (url.indexOf("?") < 0) query = "?" + query;
			else query = "&" + query;

			var responseStatus = 0;
			var onStatusFn = function (status) {
				responseStatus = status;
			}

			var onDataFn = function (data) {
				onResponseFn(responseStatus, data, []);
			}

			doBinflowHttpRequest(url + query, onDataFn, onDataFn, null, onStatusFn);
			return;
		}
		#end

		#if js
		http.onResponse = function (status: Int, data: String, headers: Array<Array<String>>) {
			if (!handled) {
				handled = true;

				try {
					timeoutInspector.stop();
					onResponseFn(status, data, headers);
				} catch (e : Dynamic) {
					NativeHx.println("FATAL ERROR: http.onResponse reported: " + e);
					HttpSupportHx.printHttpRequestDetails(url, params);
					Assert.printExnStack("Trace: :");
					NativeHx.callFlowCrashHandlers("[HTTP onResponse]: " + e);
				}

				if (status < 200 || status >= 400) {
					// There was probably an error with the request
					Errors.report("Http request to " + url + " returned status: " + status);
				}
			} else {
				// Ignore error as the request most probably timed out and onError was called already
			}
		}
		#else
		var status = 0;

		http.onData = function (res: String) {
			if (!handled) {
				handled = true;
				timeoutInspector.stop();
				try {
					onResponseFn(status, res, []);
				} catch (e : Dynamic) {
					NativeHx.println("FATAL ERROR: http.onData reported: " + e);
					HttpSupportHx.printHttpRequestDetails(url, params);
					Assert.printExnStack("Trace: :");
					NativeHx.callFlowCrashHandlers("[HTTP onData]: " + e);
				}
			} else {
				// Ignore result as the request most probably timed out and onError was called already
			}
		}

		http.onError = function (err: String) {
			if (!handled) {
				handled = true;
				timeoutInspector.stop();
				try {
					onResponseFn(status, err, []);
				} catch (e : Dynamic) {
					NativeHx.println("FATAL ERROR: http.onError reported: " + e);
					HttpSupportHx.printHttpRequestDetails(url, params);
					Assert.printExnStack("Trace: :");
					NativeHx.callFlowCrashHandlers("[HTTP onError]: " + e);
				}
			} else {
				// Ignore error as the request most probably timed out and onError was called already
			}
		}

		http.onStatus = function(_status: Int) {
			if (!handled) {
				status = _status;

				if (status < 200 || status >= 400) {
					// There was probably an error with the request
					Errors.report("Http request to " + url + " returned status: " + status);
				}
			} else {
				// Nothing to do, we have handled the request already
			}
		}
		#end

		// setting parameters
		for (param in params) {
			http.setParameter(param[0], param[1]);
		}

		// and headers
		for (header in headers) {
			http.setHeader(header[0], header[1]);
		}

		#if js
		http.async = async;
		#end

		http.request(method == "POST");
		#end
	}

	public static function preloadMediaUrl(url : String, onSuccessFn : Void -> Void, onErrorFn : String -> Void) : Void {
		// STUB; native only used in the C++ target
	}

	public static function downloadFile(url : String, onDataFn : String -> Void, onErrorFn : String -> Void, onProgressFn : Float -> Float -> Void) : Void {
		#if flash
		var loader = new flash.net.URLLoader();
		loader.addEventListener(flash.events.Event.COMPLETE, function(e : Dynamic) {
			try {
				onDataFn(loader.data);
			} catch (e : Dynamic) {
				NativeHx.println("FATAL ERROR: download file reported: " + e);
				Assert.printExnStack("Trace: :");
				NativeHx.callFlowCrashHandlers("[downloadFile onData]: " + e);
			}
		});
		loader.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function(e : Dynamic) { onErrorFn(e.text); } );
		loader.addEventListener(flash.events.ProgressEvent.PROGRESS, function(e : Dynamic) {
			if (e.bytesTotal > 0)
				onProgressFn(e.bytesLoaded, e.bytesTotal);
			else
				onProgressFn(e.bytesLoaded, Math.max(2*1024*1024, e.bytesLoaded)); // bytesLoaded = 0 for gzipped content for example.
		} );
		loader.load(new flash.net.URLRequest(url));

		#elseif (js && nwjs)
			if (isBinflow(url) && Util.getParameter("arraybuffer") != "0") {
				doBinflowHttpRequest(url, onDataFn, onErrorFn, onProgressFn, null);
			} else {
				doBinaryHttpRequest(url, onDataFn, onErrorFn, onProgressFn, null);
			}
		#elseif (js && flow_nodejs)
		// TO DO: Implement

		#elseif js

		if (isBinflow(url) && Util.getParameter("arraybuffer") != "0") {
			doBinflowHttpRequest(url, onDataFn, onErrorFn, onProgressFn, null);
		} else {
			var loader = new js.html.XMLHttpRequest();
			loader.addEventListener("load", function(e : Dynamic) { if (loader.status == 200) onDataFn(loader.responseText); else onErrorFn("HTTP error : " + loader.status); }, false);
			loader.addEventListener("error", function(e : Dynamic) { onErrorFn("IO error"); }, false);
			loader.addEventListener("progress", function(e : Dynamic) { if (e.lengthComputable) onProgressFn(e.loaded, e.total); }, false);
			loader.open("GET", url, true);
			loader.send("");
		}
		#end
	}

	#if js
	private static var JSFileInput : Dynamic = null;
	private static var CurrentOnCancel : Void -> Void = null;
	#end
	public static function uploadFile(url: String, params: Array<Array<String>>, headers: Array<Array<String>>,
			fileTypes: Array<String>,
			onOpenFn: Void -> Void,
			onSelectFn: String -> Int -> Bool,
			onDataFn: String -> Void,
			onErrorFn: String -> Void,
			onProgressFn: Float -> Float -> Void,
			onCancelFn: Void -> Void
	) : Void -> Void {
		var cancelFn = function() {};

		#if flash

		var fileReference = new flash.net.FileReference();
		cancelFn = function() {
			fileReference.cancel();
		}

		fileReference.addEventListener(flash.events.Event.SELECT, function(e) {
			var continueUploading : Bool = onSelectFn(fileReference.name, Std.int(fileReference.size));

			var selectedFile : flash.net.FileReference = e.target;

			cancelFn = function() {
				selectedFile.cancel();
			}

			selectedFile.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function(e) {
				onErrorFn(e);
			});

			selectedFile.addEventListener(flash.events.Event.OPEN, function(e) {
				onOpenFn();
			});

			selectedFile.addEventListener(flash.events.DataEvent.UPLOAD_COMPLETE_DATA, function(e: flash.events.DataEvent) {
				onDataFn(e.data);
			});

			selectedFile.addEventListener(flash.events.ProgressEvent.PROGRESS, function(e: flash.events.ProgressEvent) {
				onProgressFn(e.bytesLoaded, e.bytesTotal);
			});

			if (continueUploading) {
				var request = new flash.net.URLRequest(url);
				request.method = flash.net.URLRequestMethod.POST;
				var vars = new flash.net.URLVariables();

				var payloadName = "";

				for (param in params) {
					var key = param[0];
					var value = param[1];
					if (key != "uploadDataFieldName") {
						Reflect.setField(vars, key, value);
					} else {
						payloadName = value;
					}
				}

				request.data = vars;

				if (payloadName == "") {
					selectedFile.upload(request);
				} else {
					selectedFile.upload(request, payloadName);
				}
			}
		});

		var fTypes = "";
		for(fType in fileTypes) {
			fTypes += fType + ";";
		}

		fileReference.addEventListener(flash.events.Event.CANCEL, function(e) {
			onCancelFn();
		});

		fileReference.browse([new flash.net.FileFilter(fTypes, fTypes)]);

		#elseif (js && !flow_nodejs)

		// Remove element before trying to create.
		// If we don't do that, file open dialog opens only first time.
		if (JSFileInput) {
			js.Browser.document.body.removeChild(JSFileInput);
			JSFileInput = null;
		}
		// Appending JSFileInput element to the DOM need only for Safari 5.1.7 & IE11 browsers.
		// If we don't append it, calling function 'click()' failed on these browsers.
		if (!JSFileInput) {
			JSFileInput = js.Browser.document.body.appendChild(js.Browser.document.createElement("INPUT"));
 			JSFileInput.type = "file";
			JSFileInput.style.visibility = "hidden";
			Browser.window.addEventListener("focus", function() {
				haxe.Timer.delay(function() {
					if (CurrentOnCancel != null && JSFileInput.value.length == 0 && Browser.document.hasFocus()) {
						CurrentOnCancel(); CurrentOnCancel = null;
					}
				}, 1000); // Wait for input node is ready
			});
		}

		JSFileInput.value = ""; // force onchange event for the same path
		CurrentOnCancel = onCancelFn;

		var fTypes = "";
		for(fType in fileTypes) {
			fTypes += fType + ",";
		}
		if (fTypes != "")
			JSFileInput.accept = StringTools.replace(fTypes, "*", "");


		JSFileInput.onchange = function(e : Dynamic) {
			CurrentOnCancel = null;

			var file : Dynamic = JSFileInput.files[0];

			if ( !onSelectFn(file.name, file.size) ) return;

			var xhr : Dynamic = untyped __js__ ("new XMLHttpRequest()");
			xhr.onload = xhr.onerror = function() {
				if (xhr.status < 200 || xhr.status >= 400) {
					onErrorFn(xhr.responseText);
				} else {
					onDataFn(xhr.responseText);
				}
			};

			xhr.upload.onprogress = function(event) {
				onProgressFn(event.loaded, event.total);
			};

			xhr.open("POST", url, true);
			onOpenFn();

			var form_data : Dynamic = untyped __js__ ("new FormData()");
			form_data.append("Filename", file.name);

			var payloadName = "Filedata";
			for (p in params) {
				if (p[0] != "uploadDataFieldName") {
					form_data.append(p[0], p[1]);
				} else {
					payloadName = p[1];
				}
			};
			form_data.append(payloadName, file);

			for (header in headers) {
				xhr.setRequestHeader(header[0], header[1]);
			}

			xhr.send(form_data);
		};

		JSFileInput.click();
		#end

		return cancelFn;
	}

	public static function removeUrlFromCache(url: String) : Void {
		// NOP
	}

	public static function clearUrlCache() : Void  {
		// NOP
	}

	public static function sendHttpRequestWithAttachments(url : String, headers : Array<Array<String>>, params : Array<Array<String>>,
			attachments : Array<Array<String>>, onDataFn : String -> Void, onErrorFn : String -> Void) : Void {
		// NOP
	}
}

