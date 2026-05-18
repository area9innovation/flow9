import js.html.Uint8Array;

class HttpCustom extends haxe.Http {
	#if (js && !nwjs)
	var method : String;
	var availableMethods = ['GET', 'POST', 'DELETE', 'PATCH', 'PUT'];
	var arrayBufferEncodings = ['wtf8', 'byte'];
	var defaultEncodings = ['auto', 'utf8'];
	var loadedLength = 0;
	var trackId : Int = 0;

	var responseHeaders2 : Array<Array<String>>;

	public var onResponse : Int -> String -> Array<Array<String>> -> Void;

	// Passive connection quality monitoring via global JS objects read by Flow's checking_network.flow.
	// Zero overhead when disabled: all methods check window.__flowPendingRequests existence first.
	// Flow enables tracking by initializing globals via hostCall("eval", ...) when monitoring starts.
	//
	// __flowPendingRequests: {id: {startTime, url}} — currently in-flight requests.
	//   Memory/performance safe: each entry ~80 bytes, deleted on completion/error/timeout.
	//   Typical size 1-5 entries. O(1) operations.
	//
	// __flowBwSamples: [{kbps, ms}] — per-request bandwidth and delay samples.
	//   Sampled at readyState=4 (Content-Length with fallback) and during onprogress (event.loaded).
	//   Only requests with size >= 2048 bytes and elapsed > 100ms are recorded —
	//   small responses produce meaningless bandwidth (20 bytes / 200ms = 0.8 kbps on fast network).
	//   Polled and cleared by Flow every 2s. Median resists outliers. Capped at 20 entries.

	private function trackStart(url : String) : Void {
		untyped __js__("
			var p = window.__flowPendingRequests;
			if (p) {
				var id = ++window.__flowPendingRequestId;
				p[id] = {startTime: performance.now(), url: {0}};
				{1} = id;
			}
		", url, trackId);
	}

	private function trackProgress(loaded : Int) : Void {
		untyped __js__("
			var p = window.__flowPendingRequests;
			if (p) {
				var r = p[{0}];
				if (r && {1} >= 2048) {
					var elapsed = performance.now() - r.startTime;
					if (elapsed > 100) {
						var a = window.__flowBwSamples;
						if (a) { a.push({kbps: {1} * 8 / elapsed, ms: elapsed}); if (a.length > 20) a.shift(); }
					}
				}
			}
		", trackId, loaded);
	}

	private function trackEnd() : Void {
		untyped __js__("
			var p = window.__flowPendingRequests;
			if (p && p[{0}]) {
				var r = p[{0}];
				var elapsed = performance.now() - r.startTime;
				try {
					var x = {1};
					if (x) {
						var cl = x.getResponseHeader('Content-Length');
						var size = cl ? parseInt(cl, 10) : 0;
						if (!size) {
							var rt = x.responseType;
							if (!rt || rt === 'text' || rt === '') size = (x.responseText || '').length;
							else if (rt === 'arraybuffer' && x.response) size = x.response.byteLength;
							else if (x.response) size = x.response.length || 0;
						}
						if (size >= 2048 && elapsed > 100) {
							var a = window.__flowBwSamples;
							if (a) { a.push({kbps: size * 8 / elapsed, ms: elapsed}); if (a.length > 20) a.shift(); }
						}
					}
				} catch(e) {}
				delete p[{0}];
			}
		", trackId, req);
	}

	public override function new( url : String, method : String ) {
		super(url);
		if(this.availableMethods.lastIndexOf(method) != -1) {
			this.method = method;
		} else {
			this.method = 'GET';
		}
	}

	public override function request(?post : Bool) {
		return this.requestExt(post, 'auto');
	}

	public function requestExt(post : Bool, responseEncoding : String) {
		var me = this;
		#if (haxe_ver >= "4.0.0")
			me.responseAsString = null;
		#else
			me.responseData = null;
		#end
		var r = me.req = js.Browser.createXMLHttpRequest();
		me.trackStart(url);

		var wtf8Flag = Util.getParameter("use_wtf8");
		// Url parameter takes precedence.
		if (wtf8Flag != null && wtf8Flag != "0") {
			responseEncoding = "wtf8";
		} else if (responseEncoding == "utf8") {
			responseEncoding = "auto";
		} else if (this.arrayBufferEncodings.indexOf(responseEncoding) == -1 && this.defaultEncodings.indexOf(responseEncoding) == -1) {
			responseEncoding = "auto";
		}

		if (!Platform.isIE) {
			if (this.arrayBufferEncodings.indexOf(responseEncoding) != -1) {
				r.responseType = ARRAYBUFFER;
			} else {
				r.responseType = NONE;
			}
		}

		var encodedResponse = "";

		var onprogress = function(event) {
			me.loadedLength = event.loaded;
			me.trackProgress(event.loaded);
		}

		var onreadystatechange = function(v) {
			if( r.readyState != 4 )
				return;
			var s = try r.status catch( e : Dynamic ) null;
			if ( s != null && untyped __js__('"undefined" !== typeof window') ) {
				// If the request is local and we have data: assume a success (jQuery approach):
				var protocol = js.Browser.location.protocol.toLowerCase();
				var rlocalProtocol = ~/^(?:about|app|app-storage|.+-extension|file|res|widget):$/;
				var isLocal = rlocalProtocol.match( protocol );
				if ( isLocal ) {
					if (r.responseType == ARRAYBUFFER) s = encodedResponse != null ? 200 : 404;
					else s = r.responseText != null ? 200 : 404;
				}
			}
			if( s == untyped __js__("undefined") )
				s = null;
			if( s != null )
				me.onStatus(s);

			me.trackEnd();
			me.req = null;

			if (responseEncoding == "wtf8") {
				try {
					encodedResponse = this.parseUtf8Real(
						new Uint8Array(r.response),
						r.response.byteLength
					);
				} catch (e : Dynamic) {
					encodedResponse = null;
					Native.println("ERROR: parseUtf8Full reported: " + e);
				}
			} else if (responseEncoding == "byte") {
				try {
					encodedResponse = this.respone2bytesString(
						new Uint8Array(r.response),
						r.response.byteLength
					);
				} catch (e : Dynamic) {
					encodedResponse = null;
					Native.println("ERROR: parseBinary reported: " + e);
				}
			} else {
				// Ignore, we need no to decode content
			}

			#if (haxe_ver >= "4.0.0")
			if (r.responseType == ARRAYBUFFER) me.responseAsString = encodedResponse;
			else me.responseAsString = r.responseText;
			if (me.responseAsString == "" && me.loadedLength != 0) {
				Native.println("ERROR: JS cannot make string from response of length " + me.loadedLength);
			}
			#else
			if (r.responseType == ARRAYBUFFER) me.responseData = encodedResponse;
			else me.responseData = r.responseText;
			#end

			me.responseHeaders2 =
				r
					.getAllResponseHeaders()
					.split("\r\n")
					.map(function(header) {
						return header.split(":").map(StringTools.ltrim);
					});

			me.onResponse(s, me.responseData, me.responseHeaders2);
		};
		if( async ) {
			r.onreadystatechange = onreadystatechange;
			r.onprogress = onprogress;
		}
		var uri = postData;
		if( uri != null && method == 'GET' )
			method = 'POST';
		else for( p in params ) {
			if( uri == null )
				uri = "";
			else
				uri += "&";
			#if (haxe_ver >= "4.0.0")
				uri += StringTools.urlEncode(p.name)+"="+StringTools.urlEncode(p.value);
			#else
				uri += StringTools.urlEncode(p.param)+"="+StringTools.urlEncode(p.value);
			#end
		}
		try {
			if( method != 'GET')
				r.open(method, url, async);
			else if( uri != null ) {
				var question = url.split("?").length <= 1;
				r.open("GET",url+(if( question ) "?" else "&")+uri,async);
				uri = null;
			} else
				r.open("GET",url,async);
		} catch( e : Dynamic ) {
			me.trackEnd();
			me.req = null;
			me.onError(e.toString());
			return;
		}

		if (Platform.isIE) {
			try {
				if (this.arrayBufferEncodings.indexOf(responseEncoding) != -1) {
					r.responseType = ARRAYBUFFER;
				} else {
					r.responseType = NONE;
				}
			} catch (e : Dynamic) {
				untyped console.log(e);
			}
		}

		// r.withCredentials = withCredentials;
		// Handled by HttpSupport.hx

		#if (haxe_ver >= "4.0.0")
			if( !Lambda.exists(headers, function(h) return h.name == "Content-Type") && method != 'GET')
				r.setRequestHeader("Content-Type","application/x-www-form-urlencoded");

			for( h in headers ) {
				try {
					r.setRequestHeader(h.name,h.value);
				} catch (e : Dynamic) {
					me.trackEnd();
					me.req = null;
					me.onResponse(0, e.toString(), []);
					return;
				}
			}
		#else
			if( !Lambda.exists(headers, function(h) return h.header == "Content-Type") && method != 'GET')
				r.setRequestHeader("Content-Type","application/x-www-form-urlencoded");

			for( h in headers ) {
				try {
					r.setRequestHeader(h.header,h.value);
				} catch (e : Dynamic) {
					me.trackEnd();
					me.req = null;
					me.onResponse(0, e.toString(), []);
					return;
				}
			}
		#end

		r.send(uri);
		if( !async )
			onreadystatechange(null);
	}

	public override function cancel() {
		if (this.req != null) {
			this.trackEnd();
			this.req.abort();
			this.req = null;
		}
	}

	private function parseUtf8Real(str : Uint8Array, size : Int) : String {
		var out = "";
		var bytes = 0;
		var decode_error = String.fromCharCode(0xfffd);

		//second/third/fourth bytes should starts with 10xxxxxx
		var is_sequence_correct = function(i : Int, bytes : Int) : Bool {
			var is_correct = true;
			if (size - i >= bytes) {
				var mask = 0xc0; // xx000000
				var next_octet_mask = 0x80; // 10xxxxxx

				for (j in 1...bytes) {
					var c = str[i + j];
					is_correct = is_correct && ((c&mask) == next_octet_mask);
				}
			}
			else {
				is_correct = false;
			}

			return is_correct;
		};

		var push_sequence = function(mask : Int, c : Int, i : Int, bytes : Int) {
			if (is_sequence_correct(i, bytes)) {
				var w = (c & mask);

				//second/third/fourth bytes
				for (j in 1...bytes) {
					c = str[i + j];
					w = ((w << 6)|(c & 0x3f)); // 0x3f = 0011 1111
				}

				out += String.fromCharCode(w);
			}
			else {
				out += decode_error;
			}

			return;
		};

		var i = 0;
		while (i < size) {
			var c = str[i];

			if (c <= 0x7f) { // 1 byte sequence, 0x7f = 0111 1111
				out += String.fromCharCode(c);
				i++;
			}
			else if (c <= 0xdf) { //2 bytes sequence, 0xdf = 1101 1111
				bytes = 2;
				push_sequence(0x1f, c, i, bytes); // 0x1f = 0001 1111
				i += bytes;
			}
			else if (c <= 0xef) { // 3 bytes sequence, 0xef = 1110 1111
				bytes = 3;
				push_sequence(0x0f, c, i, bytes); // 0x0f = 0000 1111
				i += bytes;
			}
			else if (c <= 0xf7) { // 4 bytes sequence, 0xf7 = 1111 0111
				bytes = 4;
				push_sequence(0x07, c, i, bytes); // 0x07 = 0000 0111
				i += bytes;
			}
			else { //error, UTF-8 accept only max 4 octets
				out += decode_error;
				i++;
			}
		}

		return out;
	}

	private function respone2bytesString (str : Uint8Array, size : Int) : String {
		var out = "";

		for (i in 0...size) {
			out += String.fromCharCode(str[i]);
		}

		return out;
	}

	#end
}