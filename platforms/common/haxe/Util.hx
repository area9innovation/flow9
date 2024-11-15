#if sys
import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;
import Sys;
#end

#if (flow_nodejs || nwjs)
import js.Node.process;
#end

#if (nwjs)
import nw.Gui;
#end

#if (js && !flow_nodejs)
import js.Browser;
import js.Promise;
#if pixijs
import pixi.core.math.Point;
#end
#end

class Util
{
	static public function getParameter(name : String) : String {
		#if flash
			return Reflect.field(flash.Lib.current.loaderInfo.parameters, name);
		#elseif js
			#if (flow_nodejs)
			var href = process.argv.slice(2).join(" ");
			var href2 = "";
			var regexS = "[\\?&]?" + name + "=([^&# ]*)";
			#elseif (nwjs)
			var href = nw.Gui.app.argv.join(" ");
			var href2 = js.Browser.window.location.href;
			var regexS = "[\\?&]?" + name + "=([^&# ]*)";
			#else
			var href = js.Browser.window.location.href;
			var href2 = untyped js.Browser.window.urlParameters ? untyped js.Browser.window.urlParameters : "";
			var regexS = "[\\?&]" + name + "=([^&#]*)";
			#end
			var regex = new EReg(regexS, "");

			if (regex.match(href)) {
				return StringTools.urlDecode(regex.matched(1));
			} else if (regex.match(href2)) {
				return StringTools.urlDecode(regex.matched(1));
			} else {
				return null;
			}
		#else
			return null;
		#end
	}

	public static function makePath(dir: String, name: String): String {
		if (StringTools.endsWith(dir, "/")) {
			return dir + name;
		} else {
			return dir + "/" + name;
		}
	}

	public static function openFile(path: String, ?mode : Bool = true) {
#if sys
		var p = new Path(path);
		var sl = (if (p.backslash) "\\" else "/");
		var dirs = if (p.dir == null) [] else p.dir.split(sl);
		var pref = ".";
		for (dir in dirs) {
			pref = pref + sl + dir;
			createDir(pref);
		}
		return File.write(path, mode);
#else
		return null;
#end
	}

	static function createDir(dir : String) {
#if sys
		try {
			FileSystem.createDirectory(dir);
		} catch (e : Dynamic) {
			// if (! neko.FileSystem.isDirectory(dir)) & neko.FileSystem.exists() do not
			// work, so it just throws always if the dir exists already, which is good
			// enough
		}
#end
	}

	public static function println(s) {
	#if sys
		Sys.println(s);
	#elseif (js && (flow_nodejs || nwjs))
		process.stdout.write(s + "\n");
		#if nwjs
			untyped console.log(s);
		#end
	#end
	}


	static var filesCache = new Map();
	static var filesHashCache = new Map();

	public static function clearCache() {
		filesCache     = new Map();
		filesHashCache = new Map();
	}

	public static function readFile (file : String) : String {
		var content = filesCache.get(file);
		if (content == null) {
#if sys
			content = File.getContent(file);
			setFileContent(file, content);
#end
		}
		return content;
	}

	public static function setFileContent(file : String, content : String) {
		filesCache.set(file, content);
		filesHashCache.set(file,null);
	}

	public static function getFileContent(file : String, content : String) {
		filesCache.get(file);
	}

	public static function fileMd5 (file : String) : String {
		var hash = filesHashCache.get(file);
		if (hash == null) {
			var content = readFile(file);
			if (content != null) {
			filesHashCache.set(file, Md5.encode(content));
			}
		}
		return hash;
	}

	public static function writeFile(file : String, content : String) : Void {
#if sys
		if (file == "stdout") {
			println(content);
			return;
		}
		var output = openFile(file, false);
		output.writeString(content);
		output.close();
#end
	}

	public static function compareStrings(a : String, b : String) {
		if (a < b) return -1;
		if (a > b) return  1;
		return 0;
	}

	public static inline function fromCharCode(code : Int) : String {
		#if neko
			// nekos String.fromCharcode() takes utf8, so we have to manually convert to that.
			return if (code >= 128) {
				if (code >= 0x7ff) {
					var lo = code & 0x3f | 0x80;
					var mi = (code >> 6) & 0x3f | 0x80;
					var hi = (code >> 12) & 0x0f | 0xe0;
					String.fromCharCode(hi) + String.fromCharCode(mi) + String.fromCharCode(lo);
				} else {
					var lo = code & 0x3f | 0x80;
					var hi = (code >> 6) & 0x01f | 0xc0;
					String.fromCharCode(hi) + String.fromCharCode(lo);
				}
			} else {
				String.fromCharCode(code);
			}
		#else
			return String.fromCharCode(code);
		#end
	}

#if (js && !flow_nodejs)
	public static inline function determineCrossOrigin(url : String) {
		// data: and javascript: urls are considered same-origin
		if (url.indexOf('data:') == 0)
			return '';

		// default is window.location
		var loc = Browser.window.location;

		var tempAnchor : Dynamic = Browser.document.createElement('a');

		tempAnchor.href = url;

		var samePort = (!tempAnchor.port && loc.port == '') || (tempAnchor.port == loc.port);

		// if cross origin
		if (tempAnchor.hostname != loc.hostname || !samePort || tempAnchor.protocol != loc.protocol) {
			return 'anonymous';
		}

		return '';
	}

	public static function isMouseEventName(event : String) : Bool {
		return event == "pointerdown" || event == "pointerup" || event == "pointermove" ||
			   event == "pointerover" || event == "pointerout" ||
			   event == "mouseout" || event == "mousedown" || event == "mousemove" ||
			   event == "mouseup" || event == "mousemiddledown" || event == "mousemiddleup" ||
			   event == "mousemiddledown" || event == "mousemiddleup" ||
			   event == "touchstart" || event == "touchmove" || event == "touchend";
	}

#if pixijs
	public static function getPointerEventPosition(e : Dynamic) : Point {
		if (e.type == "touchstart" || e.type == "touchend" || e.type == "touchmove")
			return new Point(e.touches[0].pageX, e.touches[0].pageY);
		else if (isMouseEventName(e.type))
			return new Point(e.clientX, e.clientY);
		else
			return new Point(null, null);
	}
#end
#end

#if (js && !flow_nodejs)
	public static function loadJS(url : String, ?id : String = "") : Promise<Dynamic> {
		return new Promise<Dynamic>(function(resolve, reject) {
			var script : Dynamic = Browser.document.createElement('script');
			script.addEventListener('load', resolve);
			script.addEventListener('error', reject);
			script.addEventListener('abort', reject);
			script.src = url;
			if (id != "") {
				script.id = id;
			}
			Browser.document.head.appendChild(script);
		});
	}
#end
}
