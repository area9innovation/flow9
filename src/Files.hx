class Files {
	public function new() {
		files = new Map<String,Dynamic>();
		pending = 0;
	}
	public function clearCache() {
		files = new Map<String,Dynamic>();
	}

	// true means the file was requested before before & in that case completeFn will not
	// be called.  Note you cannot assume the request has finished, so you cannot assume
	// the file has been loaded yet.  false=the file will load now (if possible) &, when
	// loaded, completeFn will be applied to the contents.  Use download() if you want
	// completeFn called only once for each file.  If you want completeFn called always,
	// use forceDownload().
	public function download(file : String, files : Array<String>, completeFn : String -> String -> Void) : Bool {
		return if (this.files.exists(file)) true else {
				forceDownload(file, files, completeFn);
				false;
			}
	}

	// send a request to load file, then return.  Once the request is done, completeFn
	// will be called on the result (the contents of the file).  completeFn will always be
	// called, unless the file/url could not be loaded.
#if (flash || js)
        private function makeUrl(file : String) {
                return file + "?v=" + Date.now().getTime();
        }
#end

	public function forceDownload(file : String, files : Array<String>, completeFn : String -> String -> Void) : Void {
		#if flash
	  return forceDownloadAny(flash.net.URLLoaderDataFormat.TEXT, file, files, function(name, data) { return completeFn (name, data); });
		#elseif js
			var filename = files.shift();  //"http://localhost:81/" + urls.shift();
			var url = makeUrl(filename);
			var u = url;
			try {
				pending++;
				this.files.set(filename, null);
				var request = new haxe.Http(u);
				request.onError = function(s) {
					files.remove(filename);
					if (files.length == 0) {
						Errors.report("IO error trying to find: " + file + ": "+ s + ". Did you misspell an import?");
					} else {
						--pending;
						download(file, files, completeFn);
					}
				}
				request.onData = function(d) {
					pending--;
					this.files.set(filename,d);
					completeFn(filename,d);
				}
				request.async = true;
				request.request(false);
			} catch (error : Dynamic) {
				Errors.report("Unable to request " + u);
			}
		#end
	}
	
	#if flash
	public function forceDownloadAny(
		format: flash.net.URLLoaderDataFormat,
		file : String, files : Array<String>,
		completeFn : String -> Dynamic -> Void,
		?errorFn : String -> Void = null
	) : Void {
		if (errorFn == null) errorFn = Errors.report;
		var filename = files.shift();  //"http://localhost:81/" + urls.shift();
		var url = makeUrl(filename);
		var loader = new flash.net.URLLoader();
		loader.dataFormat = format;
		loader.addEventListener(flash.events.Event.COMPLETE, completeHandlerAny.bind(filename, completeFn, errorFn));
		loader.addEventListener(flash.events.IOErrorEvent.IO_ERROR, 

			function (event : flash.events.IOErrorEvent) : Void {
				if (files.length == 0) {
					--pending;
					errorFn("IO error trying to find: " + file + ": "+ event.text + ". Did you misspell an import?");
				} else {
					--pending;
					forceDownloadAny(format, file, files, completeFn, errorFn);
				}
			}
		);
		
		var request = new flash.net.URLRequest(url);
		request.method = flash.net.URLRequestMethod.POST;
		try {
			pending++;
			this.files.set(file, null);
			loader.load(request);
		} catch (error : Dynamic) {
			Errors.report("Unable to complete the request for " + file);
		}
	}

	private function completeHandlerAny(
		filename : String,
		completeFn : String -> Dynamic -> Void,
		errorFn : String -> Void,
		event : flash.events.Event
	) : Void {
		var loader = cast(event.target, flash.net.URLLoader);
		if (StringTools.startsWith(loader.data, "Uncaught exception - load.c")) {
			// Request of unfound .n file
			errorFn(loader.data);
		} else {
			pending--;
			files.set(filename, loader.data);
			// Assert.trace("completeFn: " + filename + " " + (loader.data != null));
			completeFn(filename, loader.data);
		}
	}

	private function securityErrorHandler(event : flash.events.SecurityErrorEvent) : Void {
		Errors.report("Security error:" + event.text);
	}

	private function ioErrorHandler(
	    file : String, filename : String, files : Array<String>,
		completeFn : String -> Dynamic -> Void,
		errorFn : String -> Void,
		event : flash.events.IOErrorEvent
	) : Void {
		files.remove(filename);
		if (files.length == 0) {
			--pending;
			errorFn("IO error trying to find: " + file + ": "+ event.text + ". Did you misspell an import?");
		} else {
			--pending;
			download(file, files, completeFn);
		}
	}
	
	#end
	
	private var onComplete : String -> String -> Void;
	private var onFail : String -> Void;
	private var onProgress : Int -> Void;
	
	public var pending : Int;
	private var files : Map<String,Dynamic>;
}
