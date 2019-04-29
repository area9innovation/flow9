package nw.gui;

/**

   Menu represents a native menu, it can be used as window menu or context menu.

   https://github.com/nwjs/nw.js/wiki/Menu

   See also: [Example of cut/copy/paste context menu implementation](https://gist.github.com/b1rdex/7409406)
*/
@:jsRequire("nw.gui","Menu")
extern class Menu{
	
  /**
     Get an array that contains all items of a menu. 
  */
  var items(default, null):Array<MenuItem>;
	
	
  /**
     If no option is specified, a normal context menu will be created. 
	
     To create a menu to be used as window's menu, you need to explicitly specify 'type': 'menubar' in the option,
	
     e.g. new Menu({ 'type': 'menubar' }). 
  */
  function new(?option:MenuOptions);
	
  /**
     Append item of MenuItem type to the tail of the Menu. 
  */
  function append(it:MenuItem):Void;
	
  /**
     Insert `item` of `MenuItem` type to the ith position of the `Menu`, Menu is 0-indexed. 
  */
  function insert(it:MenuItem, index:Int):Void;
	
  /**
     Remove `item` from `Menu`. This method requires you to keep the `MenuItem` outside the `Menu`. 
  */
  function remove(it:MenuItem):Void;
	
	
  /**
     Remove the `i`th item form `Menu`. 
  */
  function removeAt(index:Int):Void;
	
  /**
     Popup the Menu at position (x, y) in current window. 
	
     Usually you would listen to contextmenu event of DOM elements and manually popup the menu:

     ```
     document.body.addEventListener('contextmenu', function(ev) { 
     ev.preventDefault();
     menu.popup(ev.x, ev.y);
     });
     ```
	
     In this way, you can precisely choose which menu to show for different elements, 
	
     and you can update menu elements just before popuping it.
  */
  function popup(x:Int, y:Int):Void;
	
	
  /**
     (since v0.10.0-rc1)OSX only. Creates the default menus (App, Edit and Window). 
	
     The items can be manipulated with the items property. The argument appname is used for the title of App menu.
  */
  function createMacBuiltin(appname:String):Void;
	
}

private typedef MenuOptions = {
  ?type:MenuTypes,
}

  @:enum abstract MenuTypes(String) to String{
    var MenuBar = "menubar";
    var Contextmenu = "contextmenu";
  }