#if (flow_nodejs || nwjs)
import js.node.Fs;
#end

#if flash
typedef FlowFile = flash.net.FileReference;
#else
typedef FlowFile = Dynamic; // cannot use js.html.File, because can be sliced to js.html.Blob
#end


class FlowFileSystem {

	public static function createTempFile(name : String, content0 : String) : FlowFile {
		var content = content0;
		if (Platform.isSafari && content0.indexOf("å") != -1) {
			// https://trello.com/c/OM0aYCKj/9362-deploying-packages-in-safari-corrupts-the-content
			content = StringTools.replace(content0, "å",  "å\u200b");
		} else if (Platform.isIE || Platform.isEdge) {
			// https://trello.com/c/sbSCtJQD/10221-content-package-deployment-impossible-with-microsoft-edge
			var blob = new js.html.Blob([content], { });
			return blob2file(name, blob);
		}

		return new js.html.File([content], name);
	}

	public static function makeFileByBlobUrl(url : String, name : String, onFile : FlowFile -> Void, onError : String -> Void) : Void {
		var xhr = new js.html.XMLHttpRequest();
		xhr.open('GET', url, true);
		xhr.responseType = untyped 'blob';
		xhr.addEventListener("load", function(e : Dynamic) {
			if (xhr.status == 200) {
				onFile(new js.html.File([xhr.response], name));
			}
		}, false);
		xhr.addEventListener("error", function(e : Dynamic) { onError(xhr.responseText); }, false);
		xhr.send("");
	}

	// to change Blob to File
	private static function blob2file(name : String, jsBlob : js.html.Blob) : FlowFile {
		var file2 =
			untyped __js__("
				Object.assign(jsBlob, {
					lastModified: Date.now(),
					lastModifiedDate: Date.now(),
					name: name,
					webkitRelativePath: '',
					prototype: Object.getPrototypeOf(File),
					__proto__: File,
				})
			");

		return file2;
	}

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
			if (StringTools.startsWith(dir, "~"))
				return js.node.Os.homedir() + dir.substr(1);

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

	public static function checkFilesReady(jsFileInput : Dynamic, maxFiles : Int, fileTypes : Array<String>, callback : Array<Dynamic> -> Void, nAttempt : Int) : Void {
		var files : js.html.FileList = jsFileInput.files;
		if (files.length == 0 && nAttempt <= 10) {
			haxe.Timer.delay(function() {
				checkFilesReady(jsFileInput, maxFiles, fileTypes, callback, nAttempt + 1);
			}, 100);
		} else {
			fileTypes = fileTypes.map(function(fileType) {
				if (fileType.indexOf("*.") == 0) {
					return fileType.substring(2);
				} else if (fileType.indexOf(".") == 0) {
					return fileType.substring(1);
				}
				return fileType;
			});
			var fls : Array<js.html.File> = [];
			var allFilesAllowed : Bool = fileTypes.length == 0 || fileTypes.indexOf("*") != -1 || fileTypes.indexOf("") != -1;

			for (idx in 0...Math.floor(Math.min(files.length, maxFiles))) {
				var file = files[idx];
				var fileName = file.name;
				var fileExtension = fileName.split('.').pop();

				if (allFilesAllowed || fileTypes.indexOf(fileExtension) != -1) {
					fls.push(files[idx]);
				} else {
					trace('Invalid file selected: "' + fileName + '" with type "' + fileExtension + '"');
				}
			}
			callback(fls);
			js.Browser.document.body.removeChild(jsFileInput);
		}
	}

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

		// Appending JSFileInput element to the DOM need only for Safari 5.1.7 & IE11 browsers.
		// If we don't append it, calling function 'click()' failed on these browsers.
		var jsFileInput : Dynamic = js.Browser.document.body.appendChild(js.Browser.document.createElement("INPUT"));
		jsFileInput.type = "file";
		jsFileInput.style.visibility = "hidden";
		if (maxFiles != 1) {
			jsFileInput.multiple = true;
		}

		var fTypes = "";
		for (fType in fileTypes) {
			// Accept property accepts only file extensions (not regular expression)
			fType = StringTools.replace(fType, "*.*", "*");
			fType = StringTools.replace(fType, "*.", ".");
			fTypes += fType + ",";
		}

		// Remove trailing comma
		if (fTypes.length > 0) {
			fTypes = fTypes.substr(0, fTypes.length - 1);
		}

		jsFileInput.accept = fTypes;
		jsFileInput.value = ""; // force onchange event for the same path

		jsFileInput.onchange = function(e : Dynamic) {
			jsFileInput.onchange = null;
			checkFilesReady(jsFileInput, maxFiles, fileTypes, callback, 0);
		};

		// workaround for case when cancel was pressed and onchange isn't fired
		var onFocus : Dynamic = null;
		onFocus = function(e : Dynamic) {
			js.Browser.window.removeEventListener("focus", onFocus);
			if (Platform.isMobile) {
				js.Browser.window.removeEventListener("mousemove", onFocus);
				js.Browser.window.removeEventListener("pointermove", onFocus);
			}

			// onfocus is fired before the change of jsFileInput value
			haxe.Timer.delay(function() {
				jsFileInput.dispatchEvent(new js.html.Event("change"));
			}, 500);
		}
		js.Browser.window.addEventListener("focus", onFocus);
		if (Platform.isMobile) {
			js.Browser.window.addEventListener("mousemove", onFocus);
			js.Browser.window.addEventListener("pointermove", onFocus);
		}

		jsFileInput.click();
		#end
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
		readFileEnc(file, readAs, "UTF8", onData, onError);
	}

	public static function readFileEnc(file : FlowFile, readAs : String, encoding: String, onData : String -> Void, onError : String -> Void) : Void {
		if (readAs=="text" && encoding=="auto") {
			var ENCODINGS: Array<String> = ["UTF8", "CP1252"];
			var INVALID_CHARACTER: String = "�";
			var aggD: Array<Array<String>> = [];
			var aggE: Array<Array<String>> = [];
			for (enc in ENCODINGS) {
				function checkFinish() {
					if (aggD.length + aggE.length == ENCODINGS.length) {
						for (d in aggD) {
							if (d[1].indexOf(INVALID_CHARACTER)==-1) {
								onData(d[1]);
								return;
							}
						}
						if (aggE.length > 0) {
							onError(aggE[0][1]);
							return;
						}
						if (aggD.length > 0) {
							onData(aggD[0][1]);
							return;
						}
						onError("Something strange happened: no data nor error callbacks triggered.");
					}
				}
				function onD(d: String) {aggD.push([enc, d]); checkFinish();}
				function onE(e: String) {aggE.push([enc, e]); checkFinish();}
				readFileEnc(file, readAs, enc, onD, onE);
			}
		} else {
			#if flash
			file.load();

			file.addEventListener(flash.events.Event.COMPLETE, function (e : flash.events.Event) {
				switch (readAs : String) {
					case "data": onData(file.data.toString());
					case "uri":  onData(file.data.toString()); // Data URI building is not supported in flash

					// TODO add support for other encodings for flash target if needed.
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
				default:     reader.readAsText(file, encoding);
			}
			#end
		}
	}

	public static function saveFileClient(filename : String, data : Dynamic, type : String) {
		#if (js && !flow_nodejs)
			saveNativeFileClient(filename, new js.html.Blob(Std.isOfType(data, Array) ? data : [data], { type: type }));
		#end
	}

	public static function saveNativeFileClient(filename : String, file : Dynamic) {
		#if (js && !flow_nodejs)
			untyped __js__("
				if (window.navigator.msSaveOrOpenBlob) {
					// IE10+
					window.navigator.msSaveOrOpenBlob(file, filename);
				} else { // Others
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
