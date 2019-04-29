import Position;

#if jsruntime
#error "Attempt to link Flow compiler code into JS runtime"
#end

enum Flow {
  SyntaxError(error : String, pos : Position);

  ConstantVoid(pos : Position);
  ConstantBool(value : Bool, pos : Position);
  ConstantI32(value : Int, pos : Position);
  ConstantDouble(value : Float, pos : Position);
  ConstantString(value : String, pos : Position);
  ConstantArray(value : FlowArray<Flow>, pos : Position);
  ConstantStruct(name : String, values : FlowArray<Flow>, pos : Position);
  ConstantNative(value : Dynamic, pos : Position);

  // Reference to a variable in the environment
  VarRef(name : String, pos : Position);
	
  // Reference to a parameter in a struct
  Field(call : Flow, name : String, pos : Position);
  // Set a mutable field
  SetMutable(call : Flow, name : String, value : Flow, pos : Position);
	
  // Construct a reference to a value
  RefTo(value : Flow, pos : Position);
  // Runtime representation of a reference
  Pointer(location : Int, pos : Position);

  // Get the value of a given pointer
  Deref(pointer : Flow, pos : Position);
  // Change the value of a given reference (pointer)
  SetRef(pointer : Flow, value : Flow, pos : Position);

  // Convert a value from one thing to another
  Cast(value : Flow, fromtype : FlowTypePos, totype : FlowTypePos, pos : Position);

  // sigma=null if the user gave no explicit type declaration
  Let(name : String, sigma : TypeScheme, value : Flow, scope : Flow, pos : Position);

  Lambda(arguments : FlowArray<String>, type : FlowTypePos, body : Flow, uniqNo: Int, pos : Position);
  Closure(body : Flow, environment : Environment, pos : Position);
	
  Call(closure : Flow, arguments : FlowArray<Flow>, pos : Position);
  Sequence(statements : FlowArray<Flow>, pos : Position);

  // Expression stuff
  If(condition : Flow, then : Flow, elseExp : Flow, pos : Position);
  Not(e : Flow, pos : Position);
  Negate(e : Flow, pos : Position);
  Multiply(e1 : Flow, e2 : Flow, pos : Position);
  Divide(e1 : Flow, e2 : Flow, pos : Position);
  Modulo(e1 : Flow, e2 : Flow, pos : Position);
  Plus(e1 : Flow, e2 : Flow, pos : Position);
  Minus(e1 : Flow, e2 : Flow, pos : Position);
  Equal(e1 : Flow, e2 : Flow, pos : Position);
  NotEqual(e1 : Flow, e2 : Flow, pos : Position);
  LessThan(e1 : Flow, e2 : Flow, pos : Position);
  LessEqual(e1 : Flow, e2 : Flow, pos : Position);
  GreaterThan(e1 : Flow, e2 : Flow, pos : Position);
  GreaterEqual(e1 : Flow, e2 : Flow, pos : Position);
  And(e1 : Flow, e2 : Flow, pos : Position);
  Or(e1 : Flow, e2 : Flow, pos : Position);

  Switch(value : Flow, type : FlowTypePos, cases : FlowArray<SwitchCase>, pos : Position);
  SimpleSwitch(value : Flow, cases : FlowArray<SimpleCase>, pos : Position);
	
  // Gets the value at the given place
  ArrayGet(array : Flow, index : Flow, pos : Position);

  // The definition of a native function
  Native(name : String, io: Bool, args : FlowArray<FlowTypePos>, result : FlowTypePos, default_body : Null<Flow>, pos : Position);

  // The runtime representation of a native function: It is a constructed function which converts between flow and native types
  NativeClosure(args : Int, fn : FlowArray<Flow> -> Position -> Flow, pos : Position);
	
  // Stack slot for use with the bytecode runner only. This is used to preserve values that are 
  // not easily convertible to other Flow when they are passed to native functions that treat them as opaque things
  StackSlot(q0 : Int, q1 : Int, q2 : Int);
}

#if typepos
typedef FlowTypePos = Pos<FlowType>;
#else
typedef FlowTypePos = FlowType;
#end

typedef FlowTyvar = {type: FlowType, id : Int}

enum FlowType {
  TVoid;
  TBool;
  TInt;
  TDouble;
  TString;
  TReference(type : FlowTypePos);
  TPointer(type : FlowTypePos);
  TArray(type : FlowTypePos);
  TFunction(args : FlowArray<FlowTypePos>, returns : FlowTypePos);
  TStruct(structname : String, args : FlowArray<MonoTypeDeclaration>, max : Bool);
  TUnion(min: Map<String,FlowType>, max: Map<String,FlowType>);
  // T ::= C1, C2 -> TUnion(...).  Only TNames & TStructs allowed in union.  Each
  // name can be looked up in the type environment like a TName.  Since the structname
  // alone must uniquely identify a struct, there cannot be 2 different structs with the
  // same structname.
  TTyvar(ref: FlowTyvar);		// used only during typechecking, never part of a final type.
  TBoundTyvar(id: Null<Int>);		// used only in TypeSchemes
  TFlow;
  TNative;
  TName(name : String, args : FlowArray<FlowTypePos>);
  // An occurrence of a type name (referring to a typedef (or a struct) of that name).
  // Can have type arguments (e.g., int in Maybe<int>) if the type is polymorphic.
  // Lookup of a type name in the environment causes an instantiation of a fresh tyvar,
  // e.g., Maybe is looked up to be "None|Some(value: TTyvar(FRESH!!))".  If the user
  // specifies a type: Maybe<int>, that is instantiated: "None|Some(value: int)"
}

// TypeScheme: for polymorphic types, e.g., triple(x) = [x, x, x] has type scheme triple :
// Forall tyvar1. tyvar1 -> [tyvar1], i.e.:
//
//   {tyvars: [1], type: TFunction(TBoundTyvar(1), TArray(TBoundTyvar(1)))}
//
// A TBoundTyvar() must not occur in a FlowType unless it is inside a TypeScheme (or will
// be really soon).

typedef TypeScheme = {tyvars: FlowArray<Int>, type: FlowTypePos};

typedef TypeDeclaration = {
 name : String,
 type : TypeScheme,
 position : Position
};

typedef MonoTypeDeclaration = {
 name : String,
 type : FlowTypePos,
 position : Position,
 is_mutable : Bool
};

typedef SwitchCase = {
 structname : String,
 args : FlowArray<String>,
 used_args : Null<FlowArray<Bool>>,
 body : Flow
};

typedef SimpleCase = {
 structname : String,
 body : Flow
};

// A flow program is a list of ordered topdecs (definitions of toplevel variables,
// including one main) & userTypeDeclarations (user declarations of types of (some) of the
// topdecs as well as struct & union definitions).
typedef
Program = {
 userTypeDeclarations : OrderedHash<TypeDeclaration>, // name -> {name, type, position}
 typeEnvironment: TypeEnvironment,
 modules : Modules,
 declsOrder : FlowArray<String>,
 topdecs : Map<String,Flow>
};
