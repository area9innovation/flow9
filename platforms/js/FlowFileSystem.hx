#if (flow_nodejs || nwjs)
import js.node.Fs;
#end

#if flash
typedef FlowFile = flash.net.FileReference;
#else
typedef FlowFile = Dynamic; // cannos use js.html.File, because can be sliced to js.html.Blob
#end

class FlowFileSystem {

	public static function createDirectory(dir : String) : String {
		try {
			#if sys
			sys.FileSystem.createDirectory(dir);
			#elseif (js && (flow_nodejs || nwjs))
			Fs.mkdirSync(dir);
			#end
			return "";
		} catch (e : Dynamic) {
			return Std.string(e);
		}
	}

	public static function deleteDirectory(dir : String) : String {
		try {
			#if sys
			sys.FileSystem.deleteDirectory(dir);
			#elseif (js && (flow_nodejs || nwjs))
			Fs.rmdirSync(dir);
			#end
			return "";
		} catch (e : Dynamic) {
			return Std.string(e);
		}
	}

	public static function deleteFile(file : String) : String {
		try {
			#if sys
			sys.FileSystem.deleteFile(file);
			#elseif (js && (flow_nodejs || nwjs))
			Fs.unlinkSync(file);
			#end
			return "";
		} catch (e : Dynamic) {
			return Std.string(e);
		}
	}

	public static function renameFile(old : String, newName : String) : String {
		try {
			#if sys
			sys.FileSystem.rename(old, newName);
			#elseif (js && (flow_nodejs || nwjs))
			Fs.renameSync(old, newName);
			#end
			return "";
		} catch (e : Dynamic) {
			return Std.string(e);
		}
	}

	public static function fileExists(file : String) : Bool {
		try {
			#if sys
			return sys.FileSystem.exists(file);
			#elseif (js && (flow_nodejs || nwjs))
			var stats = Fs.statSync(file);
			return stats != null;
			#else
			return false;
			#end
		} catch (e : Dynamic) {
			return false;
		}
	}

	public static function isDirectory(dir : String) : Bool {
		try {
			#if sys
			return sys.FileSystem.isDirectory(dir);
			#elseif (js && (flow_nodejs || nwjs))
			var stats = Fs.statSync(dir);
			if (stats != null)
			  return stats.isDirectory();
			else
			  return false;
			#else
			return false;
			#end
		} catch (e : Dynamic) {
			return false;
		}
	}

	public static function readDirectory(dir : String) : FlowArray<String> {
		var d = new FlowArray();
		try {
			#if sys
			d = sys.FileSystem.readDirectory(dir);
			#elseif (js && (flow_nodejs || nwjs))
			d = Fs.readdirSync(dir);
			#end
			return d;
		} catch (e : Dynamic) {
			return d;
		}
	}

	public static function fileSize(file : String) : Float {
		try {
			#if sys
			return sys.FileSystem.stat(file).size;
			#elseif (js && (flow_nodejs || nwjs))
			var stats = Fs.statSync(file);
			if (stats != null)
			  return stats.size;
			else
			  return 0.0;
			#else
			return 0.0;
			#end
		} catch (e : Dynamic) {
			return 0.0;
		}
	}

	public static function fileModified(file : String) : Float {
		try {
			#if sys
			return sys.FileSystem.stat(file).mtime.getTime();
			#elseif (js && (flow_nodejs || nwjs))
			var stats = Fs.statSync(file);
			if (stats != null)
			  return stats.mtime.getTime();
			else
			  return 0.0;
			#else
			return 0.0;
			#end
		} catch (e : Dynamic) {
			return 0.0;
		}
	}

	public static function resolveRelativePath(dir : String) : String {
		try {
			#if sys
			return sys.FileSystem.fullPath(dir);
			#elseif (js && (flow_nodejs || nwjs))
			return Fs.realpathSync(dir);
			#else
			return dir;
			#end
		} catch (e : Dynamic) {
			return dir;
		}
	}

	public static function getFileByPath(path : String) : Dynamic {
		var d : Dynamic = 1;
		return d;
	}

	#if js
	private static var JSFileInput : Dynamic = null;
	#end
	public static function openFileDialog(maxFiles : Int, fileTypes : Array<String>, callback : Array<Dynamic> -> Void) : Void {
		#if flash

		var fileReference = new flash.net.FileReferenceList();

		fileReference.addEventListener(flash.events.Event.SELECT, function(e) {
			var selectedFile : flash.net.FileReference = e.target;

			callback(fileReference.fileList.slice(0, maxFiles));
		});

		var fTypes = "";
		for(fType in fileTypes) {
			fTypes += fType + ";";
		}

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
			if (maxFiles != 1)
				JSFileInput.multiple = true;
		}


		var fTypes = "";
		for (fType in fileTypes) {
			// Accept property accepts only file extensions (not regular expression)
			fType = StringTools.replace(fType, "*.*", "*");
			fType = StringTools.replace(fType, "*.", ".");
			fTypes += fType + ",";
		}

		JSFileInput.accept = fTypes;
		JSFileInput.value = ""; // force onchange event for the same path

		JSFileInput.onchange = function(e : Dynamic) {
			JSFileInput.onchange = null;

			var files : js.html.FileList = JSFileInput.files;

			var fls : Array<js.html.File> = [];
			for (idx in 0...Math.floor(Math.min(files.length, maxFiles))) {
				fls.push(files[idx]);
			}

			callback(fls);
		};

		//workaround for case when cancel was pressed and onchange isn't fired
		var onFocus : Dynamic = null;
		onFocus = function(e : Dynamic) {			
			js.Browser.window.removeEventListener("focus", onFocus);

			//onfocus is fired before the change of JSFileInput value
			haxe.Timer.delay(function() {
				JSFileInput.dispatchEvent(new js.html.Event("change"));
			}, 500);
		}
		js.Browser.window.addEventListener("focus", onFocus);

		JSFileInput.click();
		#end
	}

	public static function uploadNativeFile(
			file : FlowFile, 
			url : String, 
			params: Array<Array<String>>, 
			onOpenFn: Void -> Void,
			onDataFn: String -> Void,
			onErrorFn: String -> Void,
			onProgressFn: Float -> Float -> Void,
			onCancelFn: Void -> Void) : Void -> Void {

		var cancelFn = function() {};

		#if flash

		cancelFn = function() {
			file.cancel();
		}

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

		onOpenFn();

		var xhr : Dynamic = untyped __js__ ("new XMLHttpRequest()");
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
		form_data.append(payloadName, file);

		xhr.open("POST", url, true);
		xhr.send(form_data);
		#end

		return cancelFn;
	}

	public static function fileName(file : FlowFile) : String {
		#if js
		if (untyped file.name == undefined) {
			return "blob";
		}
		#end
		return file.name;
	}

	public static function fileType(file : FlowFile) : String {
		#if js
		if (file.type == "") {
			return "application/octet-stream";
		}
		return file.type;
		#elseif flash
		return file.type;
		#else
		return "";
		#end
	}

	public static function fileSizeNative(file : FlowFile) : Float {
		return file.size;
	}

	public static function fileModifiedNative(file : FlowFile) : Float {
		#if (js && !flow_nodejs)
		return file.lastModified;
		#elseif flash
		return file.modificationDate.getTime();
		#else
		return 0.0;
		#end
	}

	public static function fileSlice(file : FlowFile, offset : Int, end : Int) : FlowFile {
		#if (js && !flow_nodejs)
		return file.slice(offset, end);
		#elseif flash
		// No ability to slice file for flash target
		return file;
		#else
		return file;
		#end
	}

	public static function readFile(file : FlowFile, readAs : String, onData : String -> Void, onError : String -> Void) : Void {
		#if flash
		file.load();

		file.addEventListener(flash.events.Event.COMPLETE, function (e : flash.events.Event) {
			switch (readAs : String) {
				case "data": onData(file.data.toString());
				case "uri":  onData(file.data.toString()); // Data URI building is not supported in flash
				default: onData(file.data.readUTF());
			}
		});

		#elseif (js && !flow_nodejs)
		var reader : js.html.FileReader = new js.html.FileReader();

		reader.onerror = function (e : js.html.ProgressEvent) {
			if (e.type == "error")
				onError("Cannot read given file: " + reader.error.name);
		}

		reader.onloadend = function () {
			if (reader.result != null) {
				onData(reader.result);
			}
		}

		switch (readAs : String) {
			case "data": reader.readAsBinaryString(file);
			case "uri":  reader.readAsDataURL(file);
			default: 	 reader.readAsText(file);
		}
		#end
	}

	public static function saveFileClient(filename : String, data : Dynamic, type : String) {
		#if (js && !flow_nodejs)
			untyped __js__("
				var file = new Blob([data], {type: type});

				if (window.navigator.msSaveOrOpenBlob) // IE10+
					window.navigator.msSaveOrOpenBlob(file, filename);
				else { // Others
					var a = document.createElement('a'),
							url = URL.createObjectURL(file);
					a.href = url;
					a.download = filename;
					document.body.appendChild(a);
					a.click();
					setTimeout(function() {
						document.body.removeChild(a);
						window.URL.revokeObjectURL(url);
					}, 0);
				}
			");
		#end
	}
}
