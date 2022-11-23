#if js
#if (flow_nodejs || nwjs)
import js.node.Http;
import js.node.Https;
import js.node.http.IncomingMessage;

import js.node.Url;
import js.node.Querystring;

import js.node.Fs;
#else
import js.html.XMLHttpRequest;
import HttpCustom;
#end
#if !flow_nodejs
import js.Browser;
#end
import JSBinflowBuffer;
import js.html.Uint8Array;
#end

class HttpSupport {
	static var TimeoutInterval = 1200000;	// twenty minutes in ms

	static var defaultResponseEncoding = null;

	#if (js && !flow_nodejs)
	private static var XMLHttpRequestOverriden : Bool = false;
	private static var CORSCredentialsEnabled = true;
	private static function overrideXMLHttpRequest() {
		XMLHttpRequestOverriden = true;

		untyped __js__("
			XMLHttpRequest.prototype.realSend = XMLHttpRequest.prototype.send;
			var newSend = function(vData) { this.withCredentials = HttpSupport.CORSCredentialsEnabled; this.realSend(vData); };
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
		Native.println("======= HTTP request details:");
		Native.println("URL: " + url);
		Native.println("Parameters: ");
		for (param in params) {
			Native.println(param[0] + ": "+ param[1]);
		}
		Native.println("=======");
	}

	#if (js && (flow_nodejs || nwjs))
	private static function parseUrlToNodeOptions(url : String, ?request : Dynamic = null) : HttpsRequestOptions {
		var options = Url.parse(url);

		var port 	 = Std.parseInt(options.port);
		var protocol = options.protocol;
		var hostname = options.hostname;
		if (port == null) {
			port = protocol == "https:" ? 443 : 80;
		}

		if (protocol == null && request != null) {
			protocol = request.protocol + ":";
		}

		if (hostname == null && request != null) {
			hostname = request.hostname;
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
		params : Array<Array<String>>, onDataFn : String -> Void, onErrorFn : String -> Void,
		onStatusFn : Int -> Void, ?request : Dynamic = null) : Void {
		#if flow_nodejs

		var options : HttpsRequestOptions = parseUrlToNodeOptions(url, request);

		options.method = post ? "POST" : "GET";
		options.headers = {};

		for (pair in headers) {
			options.headers[pair[0]] = pair[1];
		}

		if (options.headers["Content-Type"] == null) {
			options.headers["Content-Type"] = "application/x-www-form-urlencoded";
		}

		var queryString = "";
		for (pair in params) {
			var key = pair[0];
			var val = pair[1];

			queryString += key + "=" + Querystring.escape(val) + "&";
		}

		queryString = queryString.substr(0, queryString.length - 1);

		var responseHandler = function(response : IncomingMessage) {
			response.setEncoding('utf8');

			if (response.statusCode == 301) {
				// We have to redirect to the correct Location url
				httpRequest(untyped response.headers.location, post, headers, params, onDataFn, onErrorFn, onStatusFn, request);

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

#if js
		var http = new haxe.Http(url);
		// Set up timeout
		var checkTimeout = function() {
			if (!handled) {
				handled = true;
				onErrorFn(url + ": request timed out");
				http.cancel();
			}
		}
		var timeoutInspector = haxe.Timer.delay(checkTimeout, TimeoutInterval);
		var stopTimer = function () {
			timeoutInspector.stop();
		}
#else
		var http = new haxe.Http(url);
		http.cnxTimeout = TimeoutInterval / 1000.0 // ms to seconds;
		var stopTimer = function () {}
#end

		http.onData = function (res: String) {
			if (!handled) {
				handled = true;
				stopTimer();
				try {
					onDataFn(res);
				} catch (e : Dynamic) {
					Native.println("FATAL ERROR: http.onData reported: " + e);
					HttpSupport.printHttpRequestDetails(url, params);
					Assert.printExnStack("Trace: :");
					Native.callFlowCrashHandlers("[HTTP onData]: " + e);
				}
			} else {
				// Ignore result as the request most probably timed out and onError was called already
			}
		}

		http.onError = function (err: String) {
			if (!handled) {
				handled = true;
				stopTimer();
				try {
					onErrorFn(err);
				} catch (e : Dynamic) {
					Native.println("FATAL ERROR: http.onError reported: " + e);
					HttpSupport.printHttpRequestDetails(url, params);
					Assert.printExnStack("Trace: :");
					Native.callFlowCrashHandlers("[HTTP onError]: " + e);
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
					Native.println("FATAL ERROR: http.onStatus reported: " + e);
					HttpSupport.printHttpRequestDetails(url, params);
					Assert.printExnStack("Trace: :");
					Native.callFlowCrashHandlers("[HTTP onStatus]: " + e);
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

		#if (js && !nwjs)
		http.async = true;
		#end

		http.request(post);
		#end
	}

	public static function httpCustomRequestNative(url : String, method : String, headers : Array<Array<String>>,
		params: Array<Array<String>>, data : String, responseEncoding : String, onResponseFn : Int -> String -> Array<Array<String>> -> Void, async : Bool, ?request : Dynamic = null) : Void {

		if (defaultResponseEncoding != null && responseEncoding == "auto") {
			responseEncoding = defaultResponseEncoding;
		}

		if ((method == 'DELETE' || method == 'PATCH' || method == "PUT") && !Lambda.exists(headers, function(h) return h[0] == "If-Match")) {
			headers.push(["If-Match", "*"]);
		}

		#if (flow_nodejs || nwjs)

		if (StringTools.startsWith(url, "file://") && method == "GET") {
			Fs.readFile(url.substring(7, url.length), function(err, data) {
				var status = err != null ? 0 : 200;
				var data = err != null ? err.message : data.toString();
				onResponseFn(status, data, []);
			});
			return;
		}

		var options : HttpsRequestOptions = parseUrlToNodeOptions(url, request);

		options.method = method;
		options.headers = {};

		for (pair in headers) {
			options.headers[pair[0]] = pair[1];
		}

		if (options.headers["Content-Type"] == null) {
			options.headers["Content-Type"] = "application/x-www-form-urlencoded";
		}

		if (data == "") {
			var queryString = "";
			for (pair in params) {
				var key = pair[0];
				var val = pair[1];

				queryString += key + "=" + Querystring.escape(val) + "&";
			}

			queryString = queryString.substr(0, queryString.length - 1);

			data = queryString;
		}

		var responseHandler = function(response : IncomingMessage) {
			response.setEncoding('utf8');

			if (response.statusCode == 301) {
				// We have to redirect to the correct Location url
				httpCustomRequestNative(untyped response.headers.location, method, headers, params, data, responseEncoding, onResponseFn, async, request);

				return;
			}

			var responseHeaders : Array<Array<String>> = new Array();
			for (key in response.headers.keys()) {
				responseHeaders.push([key, response.headers[key]]);
			}

			var rawData = "";
			response.on('error', function(error) {
				onResponseFn(response.statusCode, error, responseHeaders);
			}).on('data', function(data) {
				rawData += data;
			}).on('end', function(error) {
				onResponseFn(response.statusCode, rawData, responseHeaders);
			});
		};

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

		#if (js && !nwjs)
		var http = new HttpCustom(url, method);
		#else
		var http = new HttpCustom(url);
		#end

		// Set up timeout
		var checkTimeout = function() {
			if (!handled) {
				handled = true;
				onResponseFn(408, url + ": request timed out", []);
				http.cancel();
			}
		}
		var timeoutInspector = haxe.Timer.delay(checkTimeout, TimeoutInterval);

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

		#if (js && !nwjs)
		http.onResponse = function (status: Int, data: String, headers: Array<Array<String>>) {
			if (!handled) {
				handled = true;

				try {
					timeoutInspector.stop();
					onResponseFn(status, data, headers);
				} catch (e : Dynamic) {
					Native.println("FATAL ERROR: http.onResponse reported: " + e);
					HttpSupport.printHttpRequestDetails(url, params);
					Assert.printExnStack("Trace: :");
					Native.callFlowCrashHandlers("[HTTP onResponse]: " + e);
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
					Native.println("FATAL ERROR: http.onData reported: " + e);
					HttpSupport.printHttpRequestDetails(url, params);
					Assert.printExnStack("Trace: :");
					Native.callFlowCrashHandlers("[HTTP onData]: " + e);
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
					Native.println("FATAL ERROR: http.onError reported: " + e);
					HttpSupport.printHttpRequestDetails(url, params);
					Assert.printExnStack("Trace: :");
					Native.callFlowCrashHandlers("[HTTP onError]: " + e);
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

		#if (js && !nwjs)
		http.async = async;
		http.requestExt(method == "POST", responseEncoding);
		#else
		http.request(method == "POST");
		#end
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
				Native.println("FATAL ERROR: download file reported: " + e);
				Assert.printExnStack("Trace: :");
				Native.callFlowCrashHandlers("[downloadFile onData]: " + e);
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

	public static function uploadNativeFile(
			file : Dynamic,
			url : String,
			params: Array<Array<String>>,
			headers: Array<Array<String>>,
			onOpenFn: Void -> Void,
			onDataFn: String -> Void,
			onErrorFn: String -> Void,
			onProgressFn: Float -> Float -> Void,
			onCancelFn: Void -> Void) : Void -> Void {

		var cancelFn = function() {};

		#if flash

		file.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function(e) {
			onErrorFn(e);
		});

		file.addEventListener(flash.events.Event.OPEN, function(e) {
			onOpenFn();
		});

		file.addEventListener(flash.events.DataEvent.UPLOAD_COMPLETE_DATA, function(e: flash.events.DataEvent) {
			onDataFn(e.data);
		});

		file.addEventListener(flash.events.ProgressEvent.PROGRESS, function(e: flash.events.ProgressEvent) {
			onProgressFn(e.bytesLoaded, e.bytesTotal);
		});

		file.addEventListener(flash.events.Event.CANCEL, function(e) {
			onCancelFn();
		});

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
			file.upload(request);
		} else {
			file.upload(request, payloadName);
		}

		#elseif (js && !flow_nodejs)


		var xhr : Dynamic = untyped __js__ ("new XMLHttpRequest()");

		xhr.open("POST", url, true);
		onOpenFn();

		xhr.onload = xhr.onerror = function() {
			if(xhr.status != 200) { onErrorFn("" + xhr.status); } else { onDataFn(xhr.responseText); }
		};

		xhr.upload.onprogress = function(event) {
			onProgressFn(event.loaded, event.total);
		};

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
		form_data.append(payloadName, file, file.name);

		for (header in headers) {
			xhr.setRequestHeader(header[0], header[1]);
		}

		cancelFn = function() {
			xhr.abort();
		}

		xhr.send(form_data);
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

	public static function setDefaultResponseEncoding (responseEncoding : String) : Void {
		defaultResponseEncoding = responseEncoding;

		var encodingName = "";
		if (responseEncoding == "auto") {
			encodingName = "auto";
		} else if (responseEncoding == "utf8_js") {
			encodingName = "utf8 with surrogate pairs";
		} else if (responseEncoding == "utf8") {
			encodingName = "utf8 without surrogate pairs";
		} else if (responseEncoding == "byte") {
			encodingName = "raw byte";
		} else {
			encodingName = "auto";
		}

		Native.println("Default response encoding switched to '" + encodingName + "'");
	}
}

