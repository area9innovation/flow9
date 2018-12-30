
import Bytecode;
import CodeWriter;
import Flow;
import DebugInfo;

typedef NamesMark = {};
enum NameResolution {
	TopLevel(n : Int);
	Local(slot : Int);
	Closure(slot : Int);
	Struct(id : Int, structname : String, args : Int);
}

typedef LocalInfo = { old : Null<NameResolution>, slot : Int };

class Names {
	public function new() {
		toplevelAndOuter = new OrderedHash();
		freeVariablesFound = new OrderedHash();
		locals = new Map();
		nlocals = 0;
		structs = new OrderedHash();
		local_names = new FlowArray();
		local_reuse_table = new Map();
	}

	public function pushLocal(name : String) : LocalInfo {
		var oldVal = locals.get(name);

		if (oldVal == null) {
			var slot = local_reuse_table.get(name);
			if (slot == null) {
				slot = nlocals++;
				local_names.push(name);
				local_reuse_table.set(name, slot);
			}
			var slot : Int = slot;

			locals.set(name, Local(slot));
			return { old: oldVal, slot: slot };
		} else {
			var slot = nlocals++;
			local_names.push(name);

			locals.set(name, Local(slot));
			return { old: oldVal, slot: slot };
		}
	}

	public function popLocal(name : String, info : LocalInfo) {
		if (info.old == null)
			locals.remove(name);
		else
			locals.set(name, info.old);
	}

	public var toplevelAndOuter : OrderedHash<NameResolution>;
	public var freeVariablesFound : OrderedHash<NameResolution>;
	public var locals : Map<String,NameResolution>;
	public var nlocals : Int;
	public var structs : OrderedHash<NameResolution>;
	public var local_names : FlowArray<String>;

	private var local_reuse_table : Map<String,Int>;
}

class BytecodeWriter {
	private var extStructDefs : Bool;

	public function new(?ext_struct_defs : Bool = false) {
		namesSoFar = null;
		extStructDefs = ext_struct_defs;
	}

	public var toplevelNames : Names; // for object modules loading
	var namesSoFar : OrderedHash<NameResolution>;

	public function compile(p : Program, debug_info : DebugInfo, names : Names) : haxe.io.Bytes {
		program = p;
		toplevelNames = names;
		namesSoFar = new OrderedHash();

		var b = null;
		if (p.modules != null) {
			var order = p.modules.objectModulesOrder();
			if (order != null) {
			  for (m in order) {
					m.bytes = m.compileRange(toplevelNames, p, function () {
						return compileRange(p, names, debug_info, m.bounds);
					});
					}
			  b = new BytesOutput(debug_info);
			  b.prepare(2*1024*1024);
			  for (m in order) {
					var bytes = m.bytes.extractBytes();
					b.writeBytes(bytes, m.bytes.getDebugInfo());
					m.postprocessBytecodeAndWrite(p.modules, toplevelNames, bytes);
					}
			} else {
				var fullBounds = {decls:new Range(0, p.declsOrder.length),
								  types:p.userTypeDeclarations.range()};
				b = compileRange(p, names, debug_info, fullBounds);
			}
		} else {
			var fullBounds = {decls: new Range(0, p.declsOrder.length),
							  types: p.userTypeDeclarations.range()};
			b = compileRange(p, names, debug_info, fullBounds);
		}

		writeOpcode(b, Bytecode.CDebugInfo);
		writeString(b, "--end--");

		// Now, we run main
		var main = names.toplevelAndOuter.get("main");
		if (main == null) {
			// OK, we are done.
		} else {
			switch (main) {
				case TopLevel(n):
					// We have our stub runner at the end
					writeOpcode(b, Bytecode.CGetGlobal);
					b.writeInt31_16(n, 'globals');
					writeOpcode(b, Bytecode.CCall);
				default:
			}
		}
		writeOpcode(b, Bytecode.CLast);

		b.addDebug({ f:"--end--", l: 0, s:-1, e:-1, type: null, type2: null });
		toplevelNames = null;
		return b.extractBytes();
	}

	public function compileRange(
		p : Program, names : Names, globalDebugInfo : DebugInfo, bounds: ObjectModule.TablesBounds
	) : BytesOutput  {
		var debug_info = new DebugInfo();
		var b = new BytesOutput(debug_info);
		// splitting bytecode to 'segs' is important for performance reasons
		// don't try to "simplify" this
		var segs = new Array();
		for (di in bounds.decls) {
			var n = names.toplevelAndOuter.length;
			names.toplevelAndOuter.set(p.declsOrder[di], TopLevel(n));
		}

		// First, spit out all structs so we know their fields
		// We do this in alphabetical order in order to avoid random changes in the code just because of hash ordering differences
		compileStructDefs(b, bounds, p, names);

		var isIncremental = p.modules != null && p.modules.isIncremental();
		if (!isIncremental) {
			segs.push(b);
		}

		// We simply evaluate all top-level declarations and leave their results on the stack
		for (di in bounds.decls) {
			if (!isIncremental) {
				debug_info = new DebugInfo();
				b = new BytesOutput(debug_info);
			}
			var d = p.declsOrder[di];
			var decl = p.topdecs.get(d);
			if (decl == null) {
				throw 'null code for ' + d;
			}
			namesSoFar.set(d, names.toplevelAndOuter.get(d));

			debug_info.addTopLevel(b.getPc(), d);
			b.addDebug(FlowUtil.getPosition(decl));

			writeOpcode(b, Bytecode.CDebugInfo);
			writeString(b, d);

			switch (decl) {
			case Lambda(arguments, type, body, _, pos):
				b.addDebug(FlowUtil.getPosition(decl));
				writeFunction(b, arguments, body, pos, names, true);
			case Native(name, io, args, result, defbody, pos):
				if (defbody == null)
					encode(b, decl, names, false, true);
				else {
					b.addDebug(FlowUtil.getPosition(decl));

					switch (defbody) {
					case Lambda(_, _, _, _, _):
						encode(b, decl, names, false, true);
					default:
						throw 'invalid defbody for native '+name;
					}

					//encodeWithClosure(p, b, di, decl, names, debug_info);
				}
			case ConstantBool(value, pos):
				encode(b, decl, names, false, true);
			case ConstantI32(value, pos):
				encode(b, decl, names, false, true);
			case ConstantDouble(value, pos):
				encode(b, decl, names, false, true);
			case ConstantString(value, pos):
				encode(b, decl, names, false, true);
			default:
				encodeWithClosure(p, b, di, decl, names, debug_info);
			}
			if (!isIncremental) {
				segs.push(b);
			}
		}
		if (isIncremental) {
			return b;
		} else {
			var b = new BytesOutput(globalDebugInfo);
			b.writeBytesVector(segs);
			return b;
		}
	}

	private function encodeWithClosure(p : Program, b : BytesOutput, index : Int, decl : Flow, names : Names, debug_info : DebugInfo) {
		// If the top level uses local variables, we have to make stack slots for those,
		// i.e., code like
		// 		z = { f = \x -> x + 1; a = 2; f(a) }
		// at the top level needs stack slots to work.
		// So we need to know whether we need that or not. To do that, we just compile
		// into a buffer, and then check afterwards whether there is a need for
		// the stack slot or not.
		var newNames = new Names();
		newNames.toplevelAndOuter = namesSoFar;
		newNames.structs = names.structs;
		var debug = new DebugInfo(debug_info);
		var code = encodeToBuffer(decl, debug, newNames, false);
		if (newNames.nlocals == 0 && newNames.freeVariablesFound.empty()) {
			// It is safe to just spit out the code, because there are no free or locals
			b.writeBytes(code, debug);
		} else {
			for (n in newNames.freeVariablesFound.keys()) {
				var lo = names.toplevelAndOuter.get(n);
				if (lo != null) {
					switch (lo) {
						case TopLevel(no): {
							if (no > index) {
								var d = p.declsOrder[no];
								var decl = p.topdecs.get(d);
								switch (decl) {
								case Lambda(arguments, type, body, _, pos):
								case Native(name, io, args, result, defbody, pos):
								default:
									var error = FlowUtil.error("Referencing " + n + " before it is defined", decl);
									Errors.report(error);
									throw error;
								}
							}
						}
						default:
					}
				}
			}
			// OK, we have to reserve space for local variables here.
			// We force this by wrapping this stuff in a fake lambda to reuse that code.
			// trace("Need top level stack for " + decl);
			var p = FlowUtil.getPosition(decl);
			var fakeCall = Call(FlowUtil.lambda(new FlowArray(), TFlow, decl, p), new FlowArray(), p);
			encode(b, fakeCall, names, false, true);
			//Assert.trace(">>> #After: in fake " + d + "  FreeVars=" + names.freeVariablesFound.length);
		}
	}

	private function compileStructDefs(b : BytesOutput, bounds: ObjectModule.TablesBounds, p : Program, names : Names) {
		var structsOrder = [];
		for (di in bounds.types) {
			var d = p.userTypeDeclarations.geti(di);
			switch (d.type.type) {
			case TStruct(structname, cargs, max):
				structsOrder.push({ name: structname, declaration : d});
			default:
			}
		}
		structsOrder.sort(function(s1, s2) {
			return if (s1.name < s2.name) -1 else if (s1.name == s2.name) 0 else 1;
		});

		for (s in structsOrder) {
			var d = s.declaration;
			switch (d.type.type) {
			case TStruct(structname, cargs, max): {
				b.addDebug(d.position);
				var pc = b.getPc();
				writeOpcode(b, Bytecode.CStructDef);
				var id = names.structs.length;
				b.writeInt31(id);
				names.structs.set(structname, Struct(id, structname, cargs.length));

				writeString(b, structname);
				b.writeInt31(cargs.length);

							/*
							#if typepos
								b.writeByte(Bytecode.CArray); writeFlowTypeCode(type.val);
							#else
								b.writeByte(Bytecode.CArray); writeFlowTypeCode(type);
							#end
							*/

				var writeFlowTypeCode = function(t : FlowType) {};
				if (extStructDefs) { // Ext info about complex types
					writeFlowTypeCode = function(t : FlowType) {
						switch(t) {
							case TVoid: b.writeByte( Bytecode.CVoid );
							case TBool: b.writeByte( Bytecode.CBool );
							case TInt: b.writeByte( Bytecode.CInt );
							case TDouble: b.writeByte( Bytecode.CDouble );
							case TString: b.writeByte( Bytecode.CString );
							case TArray(type): {
								#if typepos
									b.writeByte( Bytecode.CTypedArray ); writeFlowTypeCode(type.val);
								#else
									b.writeByte( Bytecode.CTypedArray ); writeFlowTypeCode(type);
								#end
							}
							case TStruct(name, args, max): {
								b.writeByte( Bytecode.CTypedStruct ); b.writeString(name);
							}
							case TReference(type): {
								b.writeByte( Bytecode.CTypedRefTo ); writeFlowTypeCode(type);
							}
							case TName(n, args): b.writeByte( Bytecode.CStruct );
							default: b.writeByte(0xFF); // Flow
						}
					};
				} else { // No additional info about complex types
					writeFlowTypeCode = function(t : FlowType) {
						b.writeByte( switch(t) {
							case TVoid: Bytecode.CVoid;
							case TBool: Bytecode.CBool;
							case TInt: Bytecode.CInt;
							case TDouble: Bytecode.CDouble;
							case TString: Bytecode.CString;
							case TArray(type): Bytecode.CArray;
							case TStruct(name, args, max): Bytecode.CStruct;
							case TReference(type): Bytecode.CRefTo;
							case TName(n, args): Bytecode.CStruct;
							default: 0xFF; // Flow
						} );
					}
				}

				for (c in cargs) {
					writeString(b, c.name);
					if (c.is_mutable)
						b.writeByte( Bytecode.CSetMutable );
					writeFlowTypeCode(c.type);
				}
			}
			default:
			}
		}
	}

	var program : Program;

	public function encodeToBuffer(v : Flow, debug : DebugInfo, names : Names, tailcall : Bool) : haxe.io.Bytes {
		var b = new BytesOutput(debug);
		encode(b, v, names, tailcall, true);
		return b.extractBytes();
	}

	function encode(output : BytesOutput, v : Flow, names : Names, tailcall : Bool, debug : Bool) : Void {
		if (debug) {
			output.addDebug(FlowUtil.getPosition(v));
		}
		switch (v) {
		case SyntaxError(s, p): throw "Can not serialize syntax errors";
		case ConstantVoid(pos): writeOpcode(output, Bytecode.CVoid);
		case ConstantBool(value, pos): writeOpcode(output, Bytecode.CBool); output.writeByte(value ? 1 : 0);
		case ConstantI32(value, pos): writeOpcode(output, Bytecode.CInt); output.writeInt32(value);
		case ConstantDouble(value, pos):
			writeOpcode(output, Bytecode.CDouble); output.writeDouble(value);
		case ConstantString(value, pos):
			try {
				if (value.length < 40 && HaxeRuntime.wideStringSafe(value)) {
					writeOpcode(output, Bytecode.CWString);
					output.writeWideString(value);
				} else {
					writeOpcode(output, Bytecode.CString);
					writeString(output, value);
				}
			} catch (e : Dynamic) {
				Errors.report(Prettyprint.position(pos) + ': Error producing bytecode for string constant.');
				throw e;
			}
		case ConstantArray(values, pos):
			writeValues(output, values, names);
			writeOpcode(output, Bytecode.CArray);
			output.writeInt31_16(values.length, 'items in array constant');
		case ConstantStruct(name, values, pos):
			writeValues(output, values, names);
			writeOpcode(output, Bytecode.CStruct);
			var n = names.structs.get(name);
			switch (n) {
			case Struct(id, name, args):
				output.writeInt31_16(id, 'struct names');
			default:
				throw "Not a struct";
			}
		case ConstantNative(val, pos):
			throw "Can not serialize native values";
		case ArrayGet(array, index, pos):
			encode(output, array, names, false, debug);
			encode(output, index, names, false, debug);
			writeOpcode(output, Bytecode.CArrayGet);
		case VarRef(name, pos):
			var local = names.locals.get(name);
			if (local != null) {
				// Local variable
				//Assert.trace("VarRef: " + name + " Local");
				switch (local) {
				case Local(slot):
					writeOpcode(output, Bytecode.CGetLocal);
					output.writeInt31_16(slot, 'locals in a function');
				default:
					throw "Not implemented varref 1";
				}
			} else {
				var free = names.freeVariablesFound.get(name);
				if (free != null) {
					// Closure
					//Assert.trace("VarRef: " + name + " Free");
					switch (free) {
					case Closure(n):
						writeOpcode(output, Bytecode.CGetFreeVar);
						output.writeInt31_8(n, 'closed-over variables');
					default:
						throw "Not implemented varref 2";
					}
				} else {
					var outer = names.toplevelAndOuter.get(name);
					if (outer == null) {
						var struct = names.structs.get(name);
						if (struct == null) {
							//Assert.trace("VarRef: " + name + " New Free");
							// This is a free variable
							var freen = names.freeVariablesFound.length;
							names.freeVariablesFound.set(name, Closure(freen));
							//Assert.trace("## Add Free: " + name + " #" + freen);
							writeOpcode(output, Bytecode.CGetFreeVar);
							output.writeInt31_8(freen, 'closed-over variables');
						} else {
							// Construction of a Struct without a call
							//Assert.trace("VarRef: " + name + " Struct");
							writeOpcode(output, Bytecode.CStruct);
							switch (struct) {
							case Struct(id, name, args):
								output.writeInt31_16(id, 'struct names');
							default:
								throw "Not a struct";
							}
						}
					} else {
						switch (outer) {
						case TopLevel(n): // Top-level code.
							//Assert.trace("VarRef: " + name + " Toplevel");
							writeOpcode(output, Bytecode.CGetGlobal);
							output.writeInt31_16(n, 'globals');
						case Local(slot):
							// TODO: Reference to closure
							// Insert in free variables found
							trace(name + " is stack, but should be closure " + outer);
						case Closure(slot):
							// TODO: Reference to closure
							// Insert in free variables found
							trace(name + " is closure, but should be local closure " + outer);
						case Struct(id, name, n):
							throw "Not implemented varref 3";
						}
					}
				}
			}

//			writeOpcode(output, Bytecode.CVarRef);
//			output.writeInt31(0);
//			writeString(output, name);
		case Field(call, name, pos):
			var fields = null;
			if (name != "structname")
				fields = FlowUtil.untyvar(FlowUtil.getPosition(call).type);
			encode(output, call, names, false, debug);
			encodeFieldRef(output, pos, fields, name, Bytecode.CField, Bytecode.CFieldName);
		case RefTo(value, pos):
			encode(output, value, names, false, debug);
			writeOpcode(output, Bytecode.CRefTo);
		case Pointer(index, pos):
			throw "Not implemented: " + Prettyprint.print(v);
		case Deref(pointer, pos):
			encode(output, pointer, names, false, debug);
			writeOpcode(output, Bytecode.CDeref);
		case SetRef(pointer, value, pos):
			encode(output, pointer, names, false, debug);
			encode(output, value, names, false, debug);
			writeOpcode(output, Bytecode.CSetRef);
		case SetMutable(pointer, name, value, pos):
			var fields = FlowUtil.untyvar(FlowUtil.getPosition(pointer).type);
			encode(output, pointer, names, false, debug);
			encode(output, value, names, false, debug);
			encodeFieldRef(output, pos, fields, name, Bytecode.CSetMutable, Bytecode.CSetMutableName);
		case Cast(value, fromtype, totype, pos):
			encode(output, value, names, false, debug);
			switch (fromtype) {
			case TInt:
				switch (totype) {
				case TInt: // NOP
				case TDouble: writeOpcode(output, Bytecode.CInt2Double);
				case TString: writeOpcode(output, Bytecode.CInt2String);
				default: throw "Not implemented: " + Prettyprint.print(v);
				}
			case TDouble:
				switch (totype) {
				case TInt: writeOpcode(output, Bytecode.CDouble2Int);
				case TDouble: // NOP
				case TString: writeOpcode(output, Bytecode.CDouble2String);
				default: throw "Not implemented: " + Prettyprint.print(v);
				}
			case TName(n1, args1):
				switch (totype) {
				case TName(n2, args2): // NOP
				default: throw "Not implemented: " + Prettyprint.print(v);
				}
			case TFlow: {
				// NOP
			}
			case TBoundTyvar(__): {
				switch (totype) {
					case TFlow: {
						// NOP
					}
					default: throw "Not implemented: " + Prettyprint.print(v);
				}
			}
			default: throw "Not implemented: " + Prettyprint.print(v);
			}
		case Let(name, sigma, value, scope, pos):
			encode(output, value, names, false, debug);

			var local = names.pushLocal(name);

			writeOpcode(output, Bytecode.CSetLocal);
			output.writeInt31_16(local.slot, 'locals in a function');

			if (scope != null) {
				encode(output, scope, names, tailcall, debug);
			} else {
				writeOpcode(output, Bytecode.CVoid);
			}

			names.popLocal(name, local);

		case Lambda(arguments, type, body, _, pos):
			writeFunction(output, arguments, body, pos, names, false);

		case Flow.Closure(body, environment, pos):
			throw "Not implemented: " + Prettyprint.print(v);

		case Call(closure, arguments, pos):
			writeValues(output, arguments, names);

			var name = null;
			var struct = false;
			switch (closure) {
			case VarRef(n, p):
				name = n;
				var typeDecl = program.userTypeDeclarations.get(n);
				if (typeDecl != null) {
					switch (typeDecl.type.type) {
					case TStruct(structname, args, max):
						struct = true;
					default:
					}
				}
			default:
			}
			if (struct) {
				writeOpcode(output, Bytecode.CStruct);
				var n = names.structs.get(name);
				//Assert.trace('names=' + names.structs.keys());
				Assert.check(n != null, "n != null: " + name + " is not known in " + Prettyprint.position(pos));
				switch (n) {
				case Struct(id, name, args):
					output.writeInt31_16(id, 'struct names 2');
				default:
					throw "Not a struct";
				}
			} else {
				// Unconditionally add debug info for real calls
				output.addDebug(FlowUtil.getPosition(v));

				encode(output, closure, names, false, debug);

				var free = false;
				for (n in names.freeVariablesFound.keys()) {
					free = true;
					break;
				}
				if (tailcall && !free) {
					writeOpcode(output, Bytecode.CTailCall);
					output.writeInt31_8(arguments.length, 'locals in tail call');
				} else {
					writeOpcode(output, Bytecode.CCall);
				}
			}
		case Sequence(statements, pos):
			for (i in 0...statements.length) {
				var s = statements[i];
				var last = i == statements.length - 1;
				encode(output, s, names, tailcall && last, debug);
				if (!last) {
					writeOpcode(output, Bytecode.CPop);
				}
			}
		case If(condition, then, elseExp, pos):
			encode(output, condition, names, false, debug);
			var debugThen = new DebugInfo(output.getDebugInfo());
			var thencode = encodeToBuffer(then, debugThen, names, tailcall);
			var debugElse = new DebugInfo(output.getDebugInfo());
			var elsecode = encodeToBuffer(if (elseExp == null) {
				ConstantVoid(pos);
			} else {
				elseExp;
			}, debugElse, names, tailcall);
			writeOpcode(output, Bytecode.CIfFalse);
			var thenPC = output.getPc();
			output.writeInt31(thencode.length + 5); // 5 for the jump at the end
			output.writeBytes(thencode, debugThen);
			writeOpcode(output, Bytecode.CGoto);
			var elsePC = output.getPc();
			output.writeInt31(elsecode.length);
			output.writeBytes(elsecode, debugElse);
		case Not(e, pos):
			encode(output, e, names, false, debug);
			writeOpcode(output, Bytecode.CNot);
		case Negate(e, pos):
			encode(output, e, names, false, debug);
			writeOpcode(output, intOrDouble(pos, Bytecode.CNegateInt, Bytecode.CNegate, v));
		case Multiply(e1, e2, pos):
			encode(output, e1, names, false, debug);
			encode(output, e2, names, false, debug);
			writeOpcode(output, intOrDouble(pos, Bytecode.CMultiplyInt, Bytecode.CMultiply, v));
		case Divide(e1, e2, pos):
			encode(output, e1, names, false, debug);
			encode(output, e2, names, false, debug);
			writeOpcode(output, intOrDouble(pos, Bytecode.CDivideInt, Bytecode.CDivide, v));
		case Modulo(e1, e2, pos):
			encode(output, e1, names, false, debug);
			encode(output, e2, names, false, debug);
			writeOpcode(output, intOrDouble(pos, Bytecode.CModuloInt, Bytecode.CModulo, v));
		case Plus(e1, e2, pos):
			encode(output, e1, names, false, debug);
			encode(output, e2, names, false, debug);
			writeOpcode(output, intDoubleOrString(pos, Bytecode.CPlusInt, Bytecode.CPlus, Bytecode.CPlusString, v));
		case Minus(e1, e2, pos):
			encode(output, e1, names, false, debug);
			encode(output, e2, names, false, debug);
			writeOpcode(output, intOrDouble(pos, Bytecode.CMinusInt, Bytecode.CMinus, v));
		case Equal(e1, e2, pos):
			encode(output, e1, names, false, debug);
			encode(output, e2, names, false, debug);
			writeOpcode(output, Bytecode.CEqual);
		case NotEqual(e1, e2, pos):
			encode(output, e1, names, false, debug);
			encode(output, e2, names, false, debug);
			writeOpcode(output, Bytecode.CEqual);
			writeOpcode(output, Bytecode.CNot);
		case LessThan(e1, e2, pos):
			encode(output, e1, names, false, debug);
			encode(output, e2, names, false, debug);
			writeOpcode(output, Bytecode.CLessThan);
		case LessEqual(e1, e2, pos):
			encode(output, e1, names, false, debug);
			encode(output, e2, names, false, debug);
			writeOpcode(output, Bytecode.CLessEqual);
		case GreaterThan(e1, e2, pos):
			encode(output, e1, names, false, debug);
			encode(output, e2, names, false, debug);
			writeOpcode(output, Bytecode.CLessEqual);
			writeOpcode(output, Bytecode.CNot);
		case GreaterEqual(e1, e2, pos):
			encode(output, e1, names, false, debug);
			encode(output, e2, names, false, debug);
			writeOpcode(output, Bytecode.CLessThan);
			writeOpcode(output, Bytecode.CNot);
		case And(e1, e2, pos):
			// false
			writeOpcode(output, Bytecode.CBool);
			output.writeByte(0);
			// e1
			encode(output, e1, names, false, debug);
			// iffalse end
			var e2debug = new DebugInfo(output.getDebugInfo());
			var e2code = encodeToBuffer(e2, e2debug, names, false);
			writeOpcode(output, Bytecode.CIfFalse);
			output.writeInt31(e2code.length + 1); // 1 for the pop
			// pop
			writeOpcode(output, Bytecode.CPop);
			// e2
			output.writeBytes(e2code, e2debug);
		case Or(e1, e2, pos):
			// true
			writeOpcode(output, Bytecode.CBool);
			output.writeByte(1);
			// e1
			encode(output, e1, names, false, debug);
			// not
			writeOpcode(output, Bytecode.CNot);
			// iffalse end
			var e2debug = new DebugInfo(output.getDebugInfo());
			var e2code = encodeToBuffer(e2, e2debug, names, false);
			writeOpcode(output, Bytecode.CIfFalse);
			output.writeInt31(e2code.length + 1); // 1 for the pop
			// pop
			writeOpcode(output, Bytecode.CPop);
			// e2
			output.writeBytes(e2code, e2debug);
		case Switch(e0, type, cases, pos): encodeSwitch(output, names, e0, cases, pos, tailcall, true);
		case SimpleSwitch(e0, cases, pos): encodeSwitch(output, names, e0, cases, pos, tailcall, false);

		case Native(name, io, args, result, defbody, pos):
			if (defbody != null) {
				encode(output, defbody, names, false, debug);
				writeOpcode(output, Bytecode.COptionalNativeFn);
			} else {
				writeOpcode(output, Bytecode.CNativeFn);
			}
			output.writeInt31(args.length);
			writeString(output, name);
		case NativeClosure(nargs, fn, pos):
			throw "Not implemented: " + Prettyprint.print(v);
 		case StackSlot(q0, q1, q2):
			throw "Not implemented: " + Prettyprint.print(v);
		}
	}

	private static var FIELDS_IN_A_STRUCT = 'fields in a struct';
	private static var FIELDS_IN_A_UNION = 'fields in a struct union';

	function encodeFieldRef(output : BytesOutput, pos : Position, fields : FlowType, name : String, opcode_id : Int, opcode_name : Int) {
		if (fields != null) {
			var done = false;
			switch (fields) {
			case TStruct(structname, cargs, max):
				var index = fieldIndex(fields, name);
				writeOpcode(output, opcode_id);
				output.writeInt31_8(index, FIELDS_IN_A_STRUCT);
				return;
			case TUnion(min, max): {
				if (max != null) {
					// If all in the union have the same int index, we are fine
					// even if it is polymorphic
					var same = true;
					var i = -1;
					for (m in max) {
						var i2 = fieldIndex(m, name);
						if (i == -1 || i2 == i) {
							i = i2;
						} else {
							same = false;
							break;
						}
					}
					if (same) {
						writeOpcode(output, opcode_id);
						output.writeInt31_8(i, FIELDS_IN_A_UNION + " " + Prettyprint.position(pos));
						return;
					}
				}
			}
			default:
			}
		}

		// We have to be dynamic
		writeOpcode(output, opcode_name);
		if (name.length >= 256)
			throw "Field name too long: '"+name+"'";
		writeString(output, name);
	}

	// encodeSwitch is polymorphic on the cases: they can be either FlowArray<SimpleCase>
	// (if fields=false) & FlowArray<SwitchCase> (iff fields=true)
	function encodeSwitch(output : BytesOutput, names : Names, value : Flow,
	cases : FlowArray<Dynamic>, pos : Position, tailcall : Bool, fields : Bool) {
		// What value are we dispatching from?
		encode(output, value, names, false, true);

		var localsRequired = 0;
		if (fields) {
			// We model the variables in the cases as let variables, so find out how many locals
			// we need in the biggest case
			for (c in cases) {
				var l : Int = c.args.length;
				if (l > localsRequired) {
					localsRequired = l;
				}
			}
		}

		// Before we can produce the code, we need to produce each case
		var values = new Map<Int,SwitchCase>();
		var codes = new Map<Int,haxe.io.Bytes>();
		var debugs = new Map<Int,DebugInfo>();
		var defaultCase = null;
		var defaultDebug = null;
		for (c in cases) {
			// Build the code
			var debug = new DebugInfo(output.getDebugInfo());
			var b = new BytesOutput(debug);

			// Now place
			var sn = c.structname;
			var n = names.structs.get(sn);
			if (n == null) {
				// Default?
				if (sn == "default") {
					encode(b, c.body, names, tailcall, true);
					defaultCase = b.extractBytes();
					defaultDebug = debug;
				} else {
					throw "Unknown case: " + sn;
				}
			} else {
				switch (n) {
					case Struct(id, name, args):
						var locals = new FlowArray();
						if (fields) {
							var args : FlowArray<String> = c.args;
							for (a in args) {
								locals.push(names.pushLocal(a));
							}
							// We set the locals in reverse
							var n = locals.length-1;
							for (i in 0...locals.length) {
								writeOpcode(b, Bytecode.CSetLocal);
								b.writeInt31_16(locals[n-i].slot, 'locals in a function');
							}
						}
						encode(b, c.body, names, tailcall, true);
						if (fields) {
							var args : FlowArray<String> = c.args;
							var n = locals.length-1;
							for (i in 0...locals.length) {
								names.popLocal(args[n-i], locals[n-i]);
							}
						}
						var code = b.extractBytes();
						values.set(id, c);
						codes.set(id, code);
						debugs.set(id, debug);
					default: throw "Not a switch";
				}
			}
		}

		// Sort the cases in numeric order
		var indices = new FlowArray();
		for (k in values.keys()) {
			indices.push(k);
		}
		indices.sort(function(a, b) { return if (a < b) -1 else if (a == b) 0 else 1; } );

		// Calculate the positions of each case, as well as the length of the entire thing
		var positions = new FlowArray();
		var pos = 1; // Default is Halt per default
		if (defaultCase != null) {
			// Jump at the end
			pos = defaultCase.length + 5;
		}
		for (i in indices) {
			var c = codes.get(i);
			positions.push(pos);
			pos += c.length + 5;
		}
		var end = pos;

		// And finally, we are ready to spit out the code. First the header
		writeOpcode(output, if (fields) Bytecode.CSwitch else Bytecode.CSimpleSwitch);
		output.writeInt31_8(indices.length, 'cases in switch');
		output.writeInt31(end);

		var n = 0;
		for (i in indices) {
			output.writeInt31_16(i, 'structure types');
			output.writeInt31(positions[n]);
			++n;
		}

		// And now the code to handle each case
		var current = 0;
		if (defaultCase != null) {
			output.writeBytes(defaultCase, defaultDebug);
			// Goto at the end
			writeOpcode(output, Bytecode.CGoto);
			current += defaultCase.length + 5;
			output.writeInt31(end - current);
		} else {
			// We just halt
			writeOpcode(output, Bytecode.CUncaughtSwitch);
			current += 1;
		}
		for (i in indices) {
			var code = codes.get(i);
			var debug = debugs.get(i);
			output.writeBytes(code, debug);
			// Goto at the end
			writeOpcode(output, Bytecode.CGoto);
			current += code.length + 1;
			current += 4;
			output.writeInt31(end - current);
		}
 	}

	function writeFunction(output : BytesOutput, arguments : FlowArray<String>, body : Flow, pos : Position, names : Names, toplevel : Bool) : Void {
		var newNames = new Names();
		newNames.toplevelAndOuter = names.toplevelAndOuter;
		newNames.structs = names.structs;

		// If we have local variables that shadow globals, we have to
		// take those out so they become local closures correctly.
		var hiddenGlobals = new Map<String,NameResolution>();
		for (l in names.locals.keys()) {
			var hiddenTop = newNames.toplevelAndOuter.get(l);
			if (hiddenTop != null) {
				hiddenGlobals.set(l, hiddenTop);
				newNames.toplevelAndOuter.remove(l);
			}
		}

		for (a in arguments) {
			newNames.pushLocal(a);
		}
		if (newNames.nlocals != cast(arguments.length))
			throw "Argument count inconsistency";

		var debug = new DebugInfo(output.getDebugInfo());
		// Since we do not support tail calls with closures, we do not request tail calls in "inner" lambdas
		var code = encodeToBuffer(body, debug, newNames, toplevel);

		// Restore any hidden globals
		for (n in hiddenGlobals.keys()) {
			var v = hiddenGlobals.get(n);
			names.toplevelAndOuter.set(n, v);
		}

		var local_dbg = new FlowArray<DebugLocalVar>();

		var hasClosure = false;
		if (!newNames.freeVariablesFound.empty()) {
			// Now we know about free variables in the new Names
			var freeVars = new FlowArray();
			for (n in newNames.freeVariablesFound.keys()) {
				var d = newNames.freeVariablesFound.get(n);
				switch (d) {
				case Closure(s):
					local_dbg.push({ type: DebugInfo.LOCAL_UPVAR, id: s, name: n });
					while (cast(freeVars.length, Int) < s) {
						freeVars.push(null);
					}
					freeVars[s] = n;
				default: "Not supposed to happen";
				}
			}
			// Now, in numeric order, spit out references to these closure variables
			for (n in freeVars) {
				encode(output, VarRef(n, pos), names, false, false);
			}
			hasClosure = true;
		}

		for (i in 0...newNames.local_names.length) {
			var type = (i < cast(arguments.length)) ? DebugInfo.LOCAL_ARG : DebugInfo.LOCAL_VAR;
			local_dbg.push({ type: type, id: i, name: newNames.local_names[i] });
		}

		writeOpcode(output, Bytecode.CGoto);

		var argsAndLocals = newNames.nlocals;
		var locals = argsAndLocals - arguments.length;

		var l = if (argsAndLocals > 0) 9 else 0;
		output.writeInt31(code.length + 1 + l);

		output.addDebug(FlowUtil.getPosition(body));
		output.getDebugInfo().beginLambda(output.getPc(), local_dbg);

		if (l > 0) {
			// Here, if we have local variables, we have to reserve stack slots for them
/*			for (i in 0...locals) {
				writeOpcode(output, Bytecode.CVoid);
			}*/
			writeOpcode(output, Bytecode.CReserveLocals);
			output.writeInt31_16(locals, 'locals');
			output.writeInt31_8(arguments.length, 'function arguments');
		}

 		output.writeBytes(code, debug);

		if (hasClosure) {
			writeOpcode(output, Bytecode.CClosureReturn);
			output.getDebugInfo().endLambda(output.getPc());
			writeOpcode(output, Bytecode.CClosurePointer);
			output.writeInt31_8(newNames.freeVariablesFound.length, 'free variables in closure');
			var offset = -(code.length + 1 + 5 + 4 + l);
			output.writeInt31(offset);
		} else {
			writeOpcode(output, Bytecode.CReturn);
			output.getDebugInfo().endLambda(output.getPc());
			writeOpcode(output, Bytecode.CCodePointer);
			var offset = -(code.length + 1 + 5 + l);
			output.writeInt31(offset);
		}
	}

	inline function writeOpcode(output : BytesOutput, o : Int) {
		output.writeByte(o);
	}
	function writeValues(output : BytesOutput, values : FlowArray<Flow>, names : Names) {
		for (v in values) {
			encode(output, v, names, false, false);
		}
	}

	function writeString(output : BytesOutput, s : String) {
		Assert.check(s != null, "writeString: s != null");
		#if (js || flash)
			// Find the length in bytes, rather than characters
			var i = 0;
			var l = 0;
			var sl = s.length;
			while (i < sl) {
				var c = s.charCodeAt(i);
				if (c < 128) {
					l++;
				} else if (c < 2048) {
					l += 2;
				} else {
					l += 3;
				}
				++i;
			}
			output.writeInt31(l);
			for (i in 0...s.length) {
				var code = s.charCodeAt(i);
				if (code >= 128) {
					if (code >= 0x7ff) {
					  var lo = code & 0x3f | 0x80;
					  var mi = (code >> 6) & 0x3f | 0x80;
					  var hi = (code >> 12) & 0x0f | 0xe0;
					  output.writeByte(hi);
					  output.writeByte(mi);
					  output.writeByte(lo);
					} else {
					  var lo = code & 0x3f | 0x80;
					  var hi = (code >> 6) & 0x01f | 0xc0;
					  output.writeByte(hi);
					  output.writeByte(lo);
					}
				} else {
					output.writeByte(code);
				}
			}
		#else
			// Neko is already UTF-8
			output.writeInt31(s.length);
			// In UTF-8 encoding
			output.writeString(s);
		#end
	}

	function intOrDouble(pos : Position, o1 : Int, o2 : Int, v : Flow) : Int {
		return intDoubleOrString(pos, o1, o2, null, v);
	}

	function intDoubleOrString(pos : Position, o1 : Int, o2 : Int, o3 : Null<Int>, v : Flow) : Int {
		var t = FlowUtil.untyvar(pos.type);
		if (t == null) throw 'math op without a type: ' + pp(v);
		return switch (t) {
			case TInt: o1;
			case TDouble: o2;
			case TString: if (o3 == null) throw 'op must have int or double type, not ' + pt(t) + ': ' + pp(v); else o3;
			default: throw 'op must have int or double or string, not ' + pt(t) + ': ' + pp(v);
		}
	}

	function fieldIndex(struct : FlowType, name : String) : Int {
		switch (struct) {
			case TStruct(structname, cargs, max): {
				var index = 0;
				for (c in cargs) {
					if (c.name == name) {
						return index;
					}
					++index;
				}
			}
			default:
		}
		throw "Can not find the field " + name + " in " + Prettyprint.prettyprintType(struct);
		return 0;
	}

	static function pt(t : FlowType) : String {
		return Prettyprint.prettyprintType(t);
	}

	static function pp(code : Flow) : String {
		return Prettyprint.prettyprint(code, '');
	}
}
