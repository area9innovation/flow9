package nw.gui;

import js.node.events.EventEmitter;

/**
   (Shortcut API requires node-webkit >= 0.10.0)

   Shortcut represents a global keyboard shortcut, also known as system-wide hotkey. 

   If registered successfully, it works even if your app does not have focus. 

   Every time the user presses the registered shortcut, your app will receive an "active" event of the shortcut object.

   https://github.com/nwjs/nw.js/wiki/Shortcut
*/
@:jsRequire("nw.gui","Shortcut")
extern class Shortcut extends EventEmitter<Shortcut>{
	
  /**
     Get or Set the key of a Shortcut. It is a string to specify the shortcut key, like "Ctrl+Alt+A".

     Supported keys: A-Z, 0-9, Comma, Period, Home, End, PageUp, PageDown, Insert, Delete, Arrow keys (Up, Down, Left, Right) and the Media Keys (MediaNextTrack, MediaPlayPause, MediaPrevTrack, MediaStop). Note that Shortcut.key can have exactly one keycode.

     Modifiers: Ctrl (On Mac OS X, "Ctrl" correspond to the Command keys on the Macintosh keyboard), Alt, Shift. Note that Shortcut.key takes zero or more modifiers.

     Please use zero modifier only when you are knowing what your are doing. The API App.registerGlobalHotKey can support applications intercepting a single key (like { key: "A"}), 
	
     but please don't do this since users will not be able to use "A" normally any more until the app unregisters it. However, the API doesn't limit this usage, and it would be useful if the applications wants to listen Media Keys. 
  */
  var key:String;
	
  /**
     Get or Set the active callback of a Shortcut, the active must be a valid function, it will be called when user presses the shortcut. 
  */
  var active:Void->Void;
	
  /**
     Get or Set the failed callback of a Shortcut, the failed must be a valid function, it will be called when application passes an invalid Shortcut.key, or when the shortcut registration (App.registerGlobalHotKey) has failed. 
  */
  var failed:String->Void;
	
	
  function new(option:ShortcutOption);
	
}

@:enum abstract ShortcutEvent<T:haxe.Constraints.Function>(Event<T>) to Event<T> {
	
  /**
     Emitted when the users pressed the registered shortcut. 
  */
  var Active:ShortcutEvent<Void->Void> = "active";
	
  /**
     Emitted when the application passed an invalid Shortcut.key, or when the shortcut registration (App.registerGlobalHotKey) has failed. 
  */
  var Failed:ShortcutEvent<String->Void> = "failed";
}

private typedef ShortcutOption = {
 key:String,
	
 active:Void->Void,
	
 failed:String->Void
}