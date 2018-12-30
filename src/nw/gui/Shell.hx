package nw.gui;

/**
   Shell API requires node-webkit >= v0.3.0

   Shell is a collection of APIs that do desktop related jobs.

   https://github.com/nwjs/nw.js/wiki/Shell
*/
@:jsRequire("nw.gui","Shell")
extern class Shell {
  /**
     Open the given external protocol URI in the desktop's default manner. 
	
     (For example, mailto: URLs in the default mail user agent.)
  */
  function openExternal(uri:String):Void;
	
  /**
     Open the given file_path in the desktop's default manner.
  */
  function openItem(file_path:String):Void;
	
  /**
     Show the given file_path in a file manager. If possible, select the file.
  */
  function showItemInFolder(file_path:String):Void;	
}