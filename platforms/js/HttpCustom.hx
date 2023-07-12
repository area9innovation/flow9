import js.html.Uint8Array;

class HttpCustom extends haxe.Http {
	#if (js && !nwjs)
	var method : String;
	var availableMethods = ['GET', 'POST', 'DELETE', 'PATCH', 'PUT'];
	var arrayBufferEncodings = ['utf8', 'byte'];
	var defaultEncodings = ['auto', 'utf8_js'];

	var responseHeaders2 : Array<Array<String>>;

	public var onResponse : Int -> String -> Array<Array<String>> -> Void;

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

		var utf8NoSurrogatesFlag = Util.getParameter("utf8_no_surrogates");
		// Url parameter takes precedence.
		if (utf8NoSurrogatesFlag != null && utf8NoSurrogatesFlag != "0") {
			responseEncoding = "utf8";
		} else if (responseEncoding == "utf8_js") {
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
			me.req = null;

			if (responseEncoding == "utf8") {
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
		if( async )
			r.onreadystatechange = onreadystatechange;
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