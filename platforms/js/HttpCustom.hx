class HttpCustom extends haxe.Http {
	#if (js && !nwjs)
	var method : String;
	var availableMethods = ['GET', 'POST', 'DELETE', 'PATCH', 'PUT'];

	var responseHeaders : Array<Array<String>>;

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
		var me = this;
		#if (haxe_ver >= "4.0.0")
			me.responseAsString = null;
		#else
			me.responseData = null;
		#end
		var r = req = js.Browser.createXMLHttpRequest();
		var onreadystatechange = function(_) {
			if( r.readyState != 4 )
				return;
			var s = try r.status catch( e : Dynamic ) null;
			if ( s != null && untyped __js__('"undefined" !== typeof window') ) {
				// If the request is local and we have data: assume a success (jQuery approach):
				var protocol = js.Browser.location.protocol.toLowerCase();
				var rlocalProtocol = ~/^(?:about|app|app-storage|.+-extension|file|res|widget):$/;
				var isLocal = rlocalProtocol.match( protocol );
				if ( isLocal ) {
					s = r.responseText != null ? 200 : 404;
				}
			}
			if( s == untyped __js__("undefined") )
				s = null;
			if( s != null )
				me.onStatus(s);
			me.req = null;
			#if (haxe_ver >= "4.0.0")
				me.responseAsString = r.responseText;
			#else
				me.responseData = r.responseText;
			#end
			me.responseHeaders =
				r
					.getAllResponseHeaders()
					.split("\r\n")
					.map(function(header) {
						return header.split(":").map(StringTools.ltrim);
					});

			me.onResponse(s, me.responseData, me.responseHeaders);
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
			onError(e.toString());
			return;
		}
		// r.withCredentials = withCredentials;
		// Handled by HttpSupport.hx

		#if (haxe_ver >= "4.0.0")
			if( !Lambda.exists(headers, function(h) return h.name == "Content-Type") && method != 'GET')
				r.setRequestHeader("Content-Type","application/x-www-form-urlencoded");

			for( h in headers )
				r.setRequestHeader(h.name,h.value);
		#else
			if( !Lambda.exists(headers, function(h) return h.header == "Content-Type") && method != 'GET')
				r.setRequestHeader("Content-Type","application/x-www-form-urlencoded");

			for( h in headers )
				r.setRequestHeader(h.header,h.value);
		#end

		r.send(uri);
		if( !async )
			onreadystatechange(null);
	}
	#end
}