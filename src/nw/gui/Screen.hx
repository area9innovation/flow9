package nw.gui;

import js.node.events.EventEmitter;

/**
   Screen API requires node-webkit >= v0.10.2

   Screen is an instance of [EventEmitter](http://nodejs.org/api/events.html#events_class_events_eventemitter) object, 

   and you're able to use Screen.on(...) to respond to native screen's events.

   Screen is a singleton object, need to be initiated once by calling gui.Screen.Init() 

   https://github.com/nwjs/nw.js/wiki/Screen

   ```	
   var screen = Gui.Screen.Init();	
	
   trace(screen == Gui.Screen); // output: true 
   ```
*/
@:jsRequire("nw.gui","Screen")
extern class Screen extends EventEmitter<Screen>{
	

  //var id(default, null):Int;
	
	
  /**
     Get the array of screen (number of screen connected to the computer)
	
     https://github.com/nwjs/nw.js/wiki/Screen#screenscreens
  */
  var screens(default, null):Array<ScreenDetails>;
	
	
  /**
     Screen.chooseDesktopMedia requires nwjs >= v0.12.0
	
     Screen sharing by selection; Currently only working in Windows and OSX and some linux distribution.

     DesktopCaptureSourceType: "window" or "screen"
	
     The callback parameter should be a function that looks like this: function(streamId:String) {...};
	
     returns false if the function fails to execute or existing chooseDesktopMedia is still active 
	
     [More infos](https://github.com/nwjs/nw.js/issues/3077)
	
  */
  function chooseDesktopMedia (desktopCaptureSourceType:Array<DesktopCaptureSourceType>, callback:String->Void):Bool;
	
  /**
     Init the Screen singleton object, you only need to call this once 
  */
  /* static */function Init():Screen;
}

@:enum abstract DesktopCaptureSourceType(String) to String{
	
  var DCWindow = "window";
	
  var DCScreen = "screen";
}

@:enum abstract ScreenEvent<T:haxe.Constraints.Function>(Event<T>) to Event<T> {
	
  /**
     emitted when the screen resolution, arrangement is changed, the callback is called with 1 argument `screen'
  */
  var DisplayBoundsChanged:ScreenEvent<ScreenDetails->Void> = "displayBoundsChanged";
	
  /**
     emitted when a new screen added, the callback is called with 1 argument `screen' 
  */
  var DisplayAdded:ScreenEvent<ScreenDetails->Void> = "displayAdded";
	
	
  /**
     emitted when existing screen removed, the callback is called with 1 argument `screen'
  */
  var DisplayRemoved:ScreenEvent<ScreenDetails->Void> = "displayRemoved";
}

private typedef ScreenDetails = {
  /**
     unique id for a screen 
  */ 
 id:Int,	
	
 /**
    physical screen resolution, can be negative, not necessarily start from 0,
	
    depending on screen arrangement 
 */
 bounds:ScreenRect,
	
 /**
    useable area within the screen bound
 */
 work_area:ScreenRect,
	
 scaleFactor:Float,
	
 isBuiltIn : Bool,
	
 rotation : Int,
	
 touchSupport : Int	
}

  private typedef ScreenRect = {
  x:Int,
  y:Int,
  width:Int,
  height:Int
  }