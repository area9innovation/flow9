import Flow;
import FlowArray;

typedef VarSubst = {name: String, pos: Range};
typedef Rule<T> = {pattern: T, subst: T, text: String, vars : Array<VarSubst>};

class RulesProto {

  public var flowRules : Array<Rule<Flow    > >;
  public var typeRules : Array<Rule<FlowType> >;

  public function new() {
	flowRules = new Array();
	typeRules = new Array();
  }

  public static function isVar(name: String) { return name.length != 0 && name.substr(0,1) == "$"; }
  public static function isExprVar(name: String) { return name.indexOf("$exp") == 0; }
  public static function isTypeVar(name: String) { return name.indexOf("$type") == 0; }
  public static function isIdVar(name: String) { return name.indexOf("$id") == 0; }
}
