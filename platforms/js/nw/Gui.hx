package nw;

/**
 * 
 **Don'ts**

 In summary, please DO NOT do following things:

 * Do not recreate UI elements, reuse them.

 * Do not reassign an element, such as `menu.items[0] = item or item = new gui.MenuItem({})`.

 * Do not delete an element, such `delete item`.

 * Do not change UI types' prototype.

 */
@:jsRequire("nw.gui")
extern class Gui {
	
  @:native("App") static var app:nw.gui.App;
	
  @:native("Shell") static var shell:nw.gui.Shell;
	
  @:native("Screen") static var screen:nw.gui.Screen;
	
}