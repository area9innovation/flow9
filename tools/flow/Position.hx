import Flow;

typedef Position = {
	// Filename
	f : String,
	// Line number
	l : Null<Int>,
	// Starting token index
	s : Int,
	// Number of tokens (extent)
	e : Int,
	// Type of the expression. Only set for certain abstract syntax tree nodes, e.g.,
	// whether a + is int, double or string
	type : FlowType,
	// Secondary type, used by comparison operators to store their common argument type
	type2 : FlowType,
};

typedef Pos<T> = {val:T, pos: Position};

class PositionUtil {
  static public var dummy = {f:"<none>", l:0, s:0, e:0, type: null, type2: null};
  static public function copy(p : Position) {
  	return {f: p.f, l: p.l, s: p.s, e: p.e, type: p.type, type2: p.type2};
  }
#if typepos
  static public function getPosition<T>(v: Pos<T>) { return v.pos; }
  static public function getValue   <T>(v: Pos<T>) { return v.val; }
#else
  static public function getPosition<T>(v: T) { return null; }
  static public function getValue   <T>(v: T) { return v; }
#end
}