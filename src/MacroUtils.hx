import haxe.macro.Context;

class MacroUtils {
  macro public static function parseDefine(key:String) {
    return Context.parse(Context.definedValue(key), Context.currentPos());
  }
}
