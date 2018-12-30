module Struct;
import std.algorithm;
import std.format;

enum RuntimeType {rtINT, rtBOOL, rtSTRING, rtDOUBLE, rtREF, rtARRAY, rtSTRUCT, rtPARAMETER, rtVOID}

class FlowObject : Object {

}

class FlowVoid : FlowObject {
  override string toString() {
    return "void";
  }
}

class FlowArray : FlowObject {
  FlowObject[] value;
  this() {
    value = [];
  }
  this(FlowObject[] v) {
    value = v;
  }
  FlowObject opIndex(int i) {
    return value[i];
  }
  FlowObject opIndex(FlowInteger i) {
    return value[i.value];
  }
  void opIndexAssign(FlowObject v, int i) {
    value[i] = v;
  }

  int length() {
    return cast(int)value.length;
  }

  int opApply(scope int delegate(ref FlowObject) dg) {
    for (int i = 0; i < value.length; i++) {
      dg(value[i]);
    }
    return 0;
  }
  override public string toString() {
    string res = "[";
    foreach(int i, FlowObject item; value) {
      res ~= item.toString();
      if (i < value.length-1)
	res ~= ", ";
    }
    return res ~ "]";
  }
}

class FlowInteger : FlowObject {
  int value;

  this() {
    value = 0;
  }

  this(int v){
    value = v;
  }

  FlowInteger opBinary(string op)(FlowInteger a) {
    static if (op == "+") {
      return new FlowInteger(value + a.value);
    } else static if (op == "-") {
      return new FlowInteger(value - a.value);      
    } else static if (op == "/") {
      return new FlowInteger(value / a.value);
    } else static if (op == "*") {
      return new FlowInteger(value * a.value);
    } else static if (op == "%") {
      return new FlowInteger(value % a.value);
    } else static if (op == "&") {
      return new FlowInteger(value & a.value);
    } else static if (op == "|") {
      return new FlowInteger(value | a.value);
    } else static if (op == "^") {
      return new FlowInteger(value ^ a.value);
    } else return assert(false, "Unknown binary op for FlowInteger ("~op~")");
  }
  
  FlowInteger opUnary(string op)() {
    static if (op == "~") {
      return new FlowInteger(~value);
    } static if (op == "-") {
      return new FlowInteger(-value);
    } else assert(false, "Unknown unary op for FlowInteger ("~op~")");
  }

  override bool opEquals(Object a) {
    FlowInteger b = cast(FlowInteger)a;
    assert(b !is null);
    return value == b.value;
  }
  
  override int opCmp(Object a) {
    FlowInteger b = cast(FlowInteger)a;
    assert(b !is null);
    if (value < b.value) {
      return -1;
    } else if (value > b.value) {
      return 1;
    } else {
      return 0;
    }
  }

  override public string toString() {
    return format("%d", value);
  }  

}

class FlowDouble : FlowObject {
  double value;
  
  this() {
    value = 0;
  }

  this(double v){
    value = v;
  }

  FlowDouble opBinary(string op)(FlowDouble a) {
    static if (op == "+") {
      return new FlowDouble(value + a.value);
    } else static if (op == "-") {
      return new FlowDouble(value - a.value);      
    } else static if (op == "/") {
      return new FlowDouble(value / a.value);
    } else static if (op == "*") {
      return new FlowDouble(value * a.value);
    } else return assert(false, "Unknown binary op for FlowDouble ("~op~")");
  }

  FlowDouble opUnary(string op)() {
    static if (op == "-") {
      return new FlowDouble(-value);
    } else return assert(false, "Unknown unary op for FlowDouble ("~op~")");
  }
  
  override bool opEquals(Object a) {
    FlowDouble b = cast(FlowDouble)a;
    assert(b !is null);
    return value == b.value;
  }
  
  override int opCmp(Object a) {
    FlowDouble b = cast(FlowDouble)a;
    assert(b !is null);
    if (value < b.value) {
      return -1;
    } else if (value > b.value) {
      return 1;
    } else {
      return 0;
    }
  }

  override public string toString() {
    return format("%f", value);
  }  

}

class FlowBool : FlowObject {
  bool value;

  this() {
    value = false;
  }

  this(bool v) {
    value = v;
  }

  FlowBool opBinary(string op)(FlowBool a) {
    static if (op == "&&") {
      return new FlowBool(value && a.value);
    } else static if (op == "||") {
      return new FlowBool(value || a.value);
    } else static if (op == "^") {
      return new FlowBool(value ^ a.value);
    } else return assert(false, "Unknown binary op for FlowBool ("~op~")");
  }

  FlowBool opUnary(string op)() {
    static if (op == "!") {
      return FlowBool(!value);
    } else return assert(false, "Unknown unary op for FlowBool ("~op~")");
  }
  
  override bool opEquals(Object a) {
    FlowBool b = cast(FlowBool)a;
    assert(b !is null);
    return value == b.value;
  }

  override public string toString() {
    return format("%s", value);
  }  

}

class FlowString : FlowObject {
  string value;

  this() {
    value = "";
  }

  this (string v) {
    value = v;
  }

  FlowInteger length() {
    return new FlowInteger(cast(int)value.length);
  }
  
  FlowString opBinary(string op)(FlowString a) {
    static if (op == "+" || op == "~") {
      return new FlowString(value ~ a.value);
    } else assert(false, "Unknown binary op for FlowString ("~op~")");
  }
  override bool opEquals(Object a) {
    FlowString b = cast(FlowString)a;
    assert(b !is null);
    return value == b.value;
  }
  
  override int opCmp(Object a) {
    FlowString b = cast(FlowString)a;
    assert(b !is null);
    return cmp(value, b.value);
  }

  override public string toString() {
    return "\"" ~ value ~ "\"";
  }  
}

class FlowReference : FlowObject {
  FlowObject value;
  this(FlowObject a_value) {
    value = a_value;
  }
}

abstract class FlowStruct : FlowObject {

  public int getTypeId() {return -1;};

  public string[] getFieldNames() {return new string[0];};

  public RuntimeType[] getFieldTypes() {return new RuntimeType[0];};

  public string getTypeName() {return "Struct";};

  public FlowObject[] getFields(){return [];};

  public void setFields(FlowObject[] val){};
  
  override public string toString(){
    string res = getTypeName() ~ "(";
    FlowObject[] fields = getFields();
    RuntimeType[] fieldTypes = getFieldTypes();
    foreach(int i, FlowObject field; fields) {
      string fv = field.toString();
      res ~= fv;
      if (i < fields.length-1) {
	 res ~= ", ";
      }	  
    }
    return res ~ ")";
  };

  override bool opEquals(Object a) {
    auto b = (cast(FlowStruct)a);
     if (b !is null) {
       if (getTypeId() != b.getTypeId()) {
	 return false;
       } else {
	 auto f = getFields();
	 auto bf = b.getFields();
	 if (f.length != bf.length) return false;
	 bool res = true;
	 foreach(int i, FlowObject v; f) {
	   res &= v == bf[i];
	 }
	 return res;
       }
     } else {
       return false;
     }
  };

  override int opCmp(Object a) {
    auto b = (cast(FlowStruct)a);
     if (b !is null) {
       if (getTypeId() != b.getTypeId()) {
	 return -1;
       } else {
	 auto f = getFields();
	 auto bf = b.getFields();
	 if (f.length != bf.length) return -1;
	 int res = 0;
	 foreach(int i, FlowObject v; f) {
	   res = v.opCmp(bf[i]);
	   if (res != 0) return res;
	 }
	 return res;
       }
     } else {
       return -1;
     }
  }

};
class FlowFunction0 : FlowObject {
  FlowObject delegate() fn;
  this() {

  }
  this(FlowObject delegate () v) {
    fn = v;
  }
  FlowObject opCall() {
    return fn();
  }
}

class FlowFunction1 : FlowObject {
  FlowObject delegate(FlowObject p1) fn;
  this() {

  }
  this(FlowObject delegate (FlowObject p1) v) {
    fn = v;
  }
  FlowObject opCall(FlowObject p1) {
    return fn(p1);
  }
}

class FlowFunction2 : FlowObject {
  FlowObject delegate(FlowObject p1, FlowObject p2) fn;
  this() {

  }
  this(FlowObject delegate (FlowObject p1, FlowObject p2) v) {
    fn = v;
  }
  FlowObject opCall(FlowObject p1, FlowObject p2) {
    return fn(p1, p2);
  }
}

class FlowFunction3 : FlowObject {
  FlowObject delegate(FlowObject p1, FlowObject p2, FlowObject p3) fn;
  this() {

  }
  this(FlowObject delegate (FlowObject p1, FlowObject p2, FlowObject p3) v) {
    fn = v;
  }
  FlowObject opCall(FlowObject p1, FlowObject p2, FlowObject p3) {
    return fn(p1, p2, p3);
  }
}

class FlowFunction4 : FlowObject {
  FlowObject delegate(FlowObject p1, FlowObject p2, FlowObject p3, FlowObject p4) fn;
  this() {

  }
  this(FlowObject delegate (FlowObject p1, FlowObject p2, FlowObject p3, FlowObject p4) v) {
    fn = v;
  }
  FlowObject opCall(FlowObject p1, FlowObject p2, FlowObject p3, FlowObject p4) {
    return fn(p1, p2, p3, p4);
  }
}

class FlowFunction5 : FlowObject {
  FlowObject delegate(FlowObject p1, FlowObject p2, FlowObject p3, FlowObject p4, FlowObject p5) fn;
  this() {

  }
  this(FlowObject delegate (FlowObject p1, FlowObject p2, FlowObject p3, FlowObject p4, FlowObject p5) v) {
    fn = v;
  }
  FlowObject opCall(FlowObject p1, FlowObject p2, FlowObject p3, FlowObject p4, FlowObject p5) {
    return fn(p1, p2, p3, p4, p5);
  }
}

class FlowFunction6 : FlowObject {
  FlowObject delegate(FlowObject p1, FlowObject p2, FlowObject p3, FlowObject p4, FlowObject p5, FlowObject p6) fn;
  this() {

  }
  this(FlowObject delegate (FlowObject p1, FlowObject p2, FlowObject p3, FlowObject p4, FlowObject p5, FlowObject p6) v) {
    fn = v;
  }
  FlowObject opCall(FlowObject p1, FlowObject p2, FlowObject p3, FlowObject p4, FlowObject p5, FlowObject p6) {
    return fn(p1, p2, p3, p4, p5, p6);
  }
}
