package nw.gui;

/**
   Clipboard API requires node-webkit >= v0.3.0

   Clipboard is an abstraction of clipboard(Windows and GTK) and pasteboard(Mac), 

   currently it only supports reading and writing plain text in the system clipboard.

   https://github.com/nwjs/nw.js/wiki/Clipboard
*/
@:jsRequire("nw.gui","Clipboard")
extern class Clipboard {
	
  /**
     Write data to the clipboard. type specifies the mime type of the data, only text (plain text data) is supported now. 
  */
  function set(data:String, ?type:String):Void;
	
  /**
     Clear the clipboard. 
  */
  function clear():Void;
	
  /**
     Returns the data of type from clipboard. Only text (plain text data) is supported now. 
  */
  function get(?Type:String):String;
	
	
  /**
     Returns the system clipboard.

     It's not possible to create a new clipboard, 
	
     you can only get it from OS. And also note that the Selection Clipboard in X11 is not supported.
  */
  @:native("get") static function getInstance():Clipboard;
}