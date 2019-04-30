#if sys
import sys.io.File;
#end

class FilesCache {

	static var files  = new Map();
	static var hashes = new Map();

    public static function contentOpt(filename : String) : Null<String> {
	  return files.get(filename);
    }

    public static function setContent(filename : String, content : Null<String>): Null<String> 
    {
	  if (content.indexOf("\r") != -1 
	  	&& content.indexOf(String.fromCharCode(0)) == -1) {	// \x00 does not work in JS
	  	// If it is not binary, then we remove carriage returns
		content = StringTools.replace(content, "\r", "");
	  }
	  if (contentOpt(filename) != content) {
		files .set(filename, content);
		hashes.set(filename, null);
	  }
	  return content;
    }

    public static function tryContent(filename : String) : String {
	  var content = contentOpt(filename);
      #if sys
	  if (content == null) {
		try {
		  //Util.println ("Load " + filename);
		  content = setContent(filename, File.getContent(filename));
		} catch (e : Dynamic) {
		}
	  }
      #end
	  return content;
    }

    #if sys
    public static function content(filename : String) : String {
	  var content = contentOpt(filename);
	  if (content == null) {
		content = setContent(filename, File.getContent(filename));
	  }
	  return content;
    }
    #end

    public static function hash(filename : String) {
	  var md5 = hashes.get(filename);
	  if (md5 == null) {
		var content = tryContent(filename);
		if (content != null) {
		  md5 = Md5.encode(content);
		  hashes.set(filename, md5);
		}
	  }
	  return md5;
    }

}