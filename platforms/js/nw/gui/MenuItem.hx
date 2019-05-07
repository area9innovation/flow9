package nw.gui;
import js.node.events.EventEmitter;

/**
   (MenuItem API requires node-webkit >= 0.3.0)

   MenuItem represents an item in a menu. 

   A `MenuItem` can be a separator or a normal item which has label and icon. MenuItem is usually used with Menu together.

   https://github.com/nwjs/nw.js/wiki/MenuItem
*/
@:jsRequire("nw.gui","MenuItem")
extern class MenuItem extends EventEmitter<MenuItem>{

  var type(default, null):MenuItemType;
	
  var label:String;
	
  var icon:String;
	
  /**
     (since v0.11.3 - Mac OS X Only.)
  */
  var iconIsTemplate:Bool;
	
  var tooltip:String;
	
  var enabled:Bool;
	
  var submenu:Menu;
	
  var click:Void->Void;
	
  /**
     (since v0.10.0-rc1)

     A single character string to specify the shortcut key for the menu item. 
	
     Note: Some non alphanumeric keys can be used with their corresponding char codes:
		
     ```
     key = String.fromCharCode(28); // arrow left
     key = String.fromCharCode(29); // arrow right
     key = String.fromCharCode(30); // arrow up
     key = String.fromCharCode(31); // arrow down
     key = String.fromCharCode(27); // escape
     key = String.fromCharCode(11); // Page up
     key = String.fromCharCode(12); // Page down
     ```
	
  */
  var key:String;
	
  /**
     (since v0.10.0-rc1)
	
     A string to specify the modifier keys for the shortcut of the menu item. 
	
     e.g. "cmd-shift". It should be the concatenation of the following strings: cmd, shift, ctrl, alt. 
  */
  var modifiers:String;
	
	
  function new(option:MenuItemOption);
}

@:enum abstract MenuItemEvent<T:haxe.Constraints.Function>(Event<T>) to Event<T> {
  var Click:MenuItemEvent<Void->Void> = "click";
}

@:enum abstract MenuItemType(String) to String {
  var Normal = "normal";
  var Separator = "separator";
  var Checkbox = "checkbox";
}

private typedef MenuItemOption = {
	
  ?label:String,
	
  ?type:MenuItemType,		// default: Normal
	
  ?icon:String,			// path
	
  ?checked:Bool,			// check box
	
  ?tooltip:String,
	
  ?enabled:Bool,
	
  ?submenu:Menu,			// sub Menu
	
  ?key:String,			// shortcut key
	
  ?modifiers:String,		// ctrl,shift,alt, ctrl-alt, ctrl-alt-shift
	
  ?click:Void->Void,		// on click
	
  ?iconIsTemplate:Bool	// default: true, TOTO: unkonwn, 
}