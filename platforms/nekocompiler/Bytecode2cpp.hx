import sys.io.FileOutput;


class Bytecode2cpp {
	public function new(code : CodeMemory, output : FileOutput, profileInfo : ProfileInfo) {
		this.code = code;
		this.output = output;
		bytecode2code = new FlowArray();
		line2pc = new FlowArray();
		labels = new Map();
		// We need address 0
		labels.set(0, true);
		needpc = new Map();
		while (!code.eof()) {
			compileInstruction();
		}

		output.writeString("#if COMPILED
#include \"ByteCodeRunner.h\"

#define RUNNER_RefArgs1(arg0) \\
    const StackSlot &arg0 = GetStackSlotRef(0);
#define RUNNER_RefArgs2(arg1, arg0) \\
    const StackSlot &arg1 = GetStackSlotRef(1); \\
    const StackSlot &arg0 = GetStackSlotRef(0);
#define RUNNER_RefArgsRet1(rv_arg0) \\
    StackSlot &rv_arg0 = *GetStackSlotPtr(0);
#define RUNNER_RefArgsRet2(rv_arg1, arg0) \\
    StackSlot &rv_arg1 = *GetStackSlotPtr(1); \\
    const StackSlot &arg0 = GetStackSlotRef(0);
#define RUNNER_CheckTag(tag, slot) \\
    if (unlikely(slot.Type != tag)) { \\
        ReportTagError(slot, tag, #slot, NULL); \\
    }
");
		
		output.writeString("void ByteCodeRunner::run() {\n");
				// Convert from pc to code position
		output.writeString("static void * targets [ " + code.size + " ]= {\n");
		for (i in 0...code.size) {
			var l = labels.get(i);
			if (l == null || !profileInfo.alive(i)) {
				output.writeString("0,");
			} else {
				output.writeString("&&pc" + i + ",");
			}
			if ((i % 64) == 63) {
				output.writeString("\n");
			}
		}
		output.writeString("};\n");
		
		output.writeString("dispatch: FlowPtr p = Code.GetPosition(); void * target = targets[FlowPtrToInt(p)];\n");
		output.writeString("if (unlikely(target == NULL)) { printf(\"Missing jump target for address %d\", FlowPtrToInt(p)); return; }");
		output.writeString("\ngoto *target;\n");
		
		for (l in 0...bytecode2code.length) {
			var code = bytecode2code[l];
			var pc = line2pc[l];
			if (profileInfo.alive(pc)) {
				var label = labels.get(pc);
				if (label != null) {
					output.writeString("pc" + pc + ": ");
				}
				var npc = needpc.get(pc);
				if (npc != null) {
					output.writeString("LastInstructionPtr = MakeFlowPtr(" + (pc) + ");\n");
					output.writeString("Code.SetPosition(MakeFlowPtr(" + (npc) + "));\n");
				}
				output.writeString(code);
				output.writeString("\n");
			}
		}
		output.writeString("pc" + code.size + ": ;");
		output.writeString("}\n");
		output.writeString("FlowPtr ByteCodeRunner::getLastCodeAddress() { return MakeFlowPtr(" + code.size + "); }\n");
		output.writeString("#endif\n");
	}
	var code : CodeMemory;
	var output : FileOutput;
	var bytecode2code : FlowArray<String>;
	var line2pc : FlowArray<Int>;
	var labels : Map<Int,Bool>;
	var needpc : Map<Int,Int>;

	function compileInstruction() : Void {
		var pc = code.getPosition();
		var opcode = code.readByte();
		var s = switch (opcode) {
			case Bytecode.CVoid: "PushVoid();";
			case Bytecode.CBool: "Push(TBool, " + code.readByte() + ");";
			case Bytecode.CInt: {
				var v = code.readInt32();
				'Push(TInt, int(' + v + '));';
			}
			case Bytecode.CDouble: 'PushDouble(' + code.readDouble() + ');';
			case Bytecode.CString: {
				var s = readString();
				var r = "";
				for (i in 0...s.length) {
					var c = s.charAt(i);
					if (c == "\\") {
						c = "\\\\";
					} else if (c == "\"") {
						c = "\\\"";
					} else if (c == "\n") {
						c = "\\n";
					} else if (c == "\t") {
						c = "\\t";
					}
					r += c;
				}
				"Push(\"" + r + "\");";
			}
			case Bytecode.CArray: {
				var len = code.readInt31();
				"Push(TArray, MoveStackToHeap(" + len + ")); // ALLOC";
			}
			case Bytecode.CStruct: {
				var id = code.readInt31();
		        "Push(StackSlot::Make(TStruct, MoveStackToHeap(StructDefs->GetObjectAtIndex(" + id + ")->FieldsCount), " + id + "));";
			}			
			case Bytecode.CSetLocal: {
				var slot = code.readInt32();	
		        "Memory.SetStackSlot(framepointer + " + slot + "* STACK_SLOT_SIZE, PopStackSlot());";
			}
			case Bytecode.CGetLocal: {
				var slot = code.readInt32();
		        "DoGetLocal(" + slot + ");";
			};
			case Bytecode.CGetGlobal: {
				var global = code.readInt32();
		        "PushFromMemory(DataStackStart + " + global + " * STACK_SLOT_SIZE);";
			};
			case Bytecode.CReturn: {
				needpc.set(pc, pc + 1);
				"DoReturn(); goto dispatch;";
			}
			case Bytecode.CGoto: {
				var offset = code.readInt31();
				var target = pc + offset + 5;
				labels.set(target, true);
				"goto pc" + target + ";";
			}
			case Bytecode.CCodePointer: {
				var offset = code.readInt31();
				var target = pc + offset + 5;
				labels.set(target, true);
		        "Push(TCodePointer, " + target + ");";
			}
			case Bytecode.CCall: {
				needpc.set(pc, pc + 1);
				labels.set(pc, true);
				labels.set(pc + 1, true);
				"DoCall(); goto dispatch;";
			}
			case Bytecode.CNotImplemented: "// " + readString();
			case Bytecode.CIfFalse: {
				var offset = code.readInt31();
				var target = pc + offset + 5;
				labels.set(target, true);
				
				"{RUNNER_RefArgs1(flag);
		        RUNNER_CheckTag(TBool, flag);
				DiscardStackSlots(1);
		        if (flag.IntValue == 0)
		            goto pc" + target + ";
		        }";
			}
			case Bytecode.CNot: "DoNot();";
			case Bytecode.CNegate: "DoNegate();";
			case Bytecode.CMultiply: "DoMultiply();";
			case Bytecode.CDivide: "DoDivide();";
			case Bytecode.CModulo: "DoModulo();";
			case Bytecode.CPlus: "DoPlus();";
			case Bytecode.CMinus: "DoMinus();";
			case Bytecode.CEqual: "DoEqual();";
			case Bytecode.CLessThan: "DoLessThan();";
			case Bytecode.CLessEqual: "DoLessEqual();";
			case Bytecode.CNativeFn: {
				var args = code.readInt31();
			 	var fn = readString();
                "Push(AllocNativeFn(MakeNativeFunction(\"" + fn + "\", " + args + "), MakeFlowPtr("  + pc + ")));";
			}
			case Bytecode.CPop: {
		       	"DiscardStackSlots(1);";
			}
			case Bytecode.CArrayGet: {
				"DoArrayGet();";
		    }
			case Bytecode.CReserveLocals: {
				var l = code.readInt32();
				var v = code.readInt32();
				// TODO: Not sure this is correct
				"sp += " + l + " * STACK_SLOT_SIZE;" + 
				"framepointer -= " + v + " * STACK_SLOT_SIZE;";
			}
			case Bytecode.CRefTo: "DoRefTo();";
			case Bytecode.CDeref: "DoDeref();";
			case Bytecode.CSetRef: "DoSetRef();";
			case Bytecode.CInt2Double: "DoInt2Double();";
			case Bytecode.CInt2String: "DoInt2String();";
			case Bytecode.CDouble2Int: "DoDouble2Int();";
			case Bytecode.CDouble2String: "DoDouble2String();";
			case Bytecode.CField: {
				var f = code.readInt31();
				"DoField(" + f + ");";
			}
			case Bytecode.CFieldName: {
				var name = readString();
				"DoFieldName(\"" + name + "\");";
			}
			case Bytecode.CStructDef: {
				var id = code.readInt31();
				var name = readString();
				var n = code.readInt31();
				var sdid = "sd" + id;
				
				var r = "StructDef " + sdid + ";";
				r += sdid + ".Name = \"" + name + "\";";
				r += sdid + ".FieldsCount = " + n + ";";
                r += sdid + ".FieldNames = new PCHAR[" + n + "];";
				for (i in 0...n) {
					var field = readString();
					r += sdid + ".FieldNames[" + i + "] = \"" + field + "\";";
				}
				r += "StructDefs->SetObjectAtIndex(" + id + ", " + sdid + ");";
                r += "StructNameIds.insert(\"" + name + "\", " + id + ");";
				r;
			}
			case Bytecode.CGetFreeVar: {
				var n = code.readInt31();
				"PushFromMemory(closurepointer + " + n + " * STACK_SLOT_SIZE);";
			}
			case Bytecode.CDebugInfo: "// " + readString();
			case Bytecode.CClosureReturn: {
				needpc.set(pc, pc + 1);
		        "closurepointer = ClosureStackPop(); DoReturn(); goto dispatch;";
		    }
			case Bytecode.CClosurePointer: {
				var n = code.readInt31();
				var offset = code.readInt31();
				var target = pc + 9 + offset;
				labels.set(target, true);
		    	"Push(StackSlot::Make(TClosurePointer, MoveStackToHeap(" + n + "), " + target + "));";
		    }
			case Bytecode.CSwitch: {
				var n = code.readInt31();
				var end = code.readInt31();
				
				var pos = pc + 9 + n * 8;

                var r = "{RUNNER_RefArgsRet1(struct_ref);
                RUNNER_CheckTag(TStruct, struct_ref);
                int structId = struct_ref.IntValue2;

                // In the default case, we just eat the struct value
                DiscardStackSlots(1);";

				for (i in 0...n) {
					var c = code.readInt31();
					var offset = code.readInt31();
					var add = pos + offset;
					labels.set(add, true);
					r += "if (structId == " + c + ") {
                        int len = Memory.GetInt32(struct_ref.PtrValue);
                        MoveHeapToStack(struct_ref.PtrValue+4, len); // struct_ref overwritten
                        goto pc" + add + ";
					}";
				}
				r + "}";
			}
			
			case Bytecode.CSimpleSwitch: {
				// TODO: implement similar to CSwitch, but without any copying of fields in a case.  Ask Tommy.
				"Bytecode.CSimpleSwitch unimplemented";
			}
			
			case Bytecode.CUncaughtSwitch: {
				"ReportError(UncaughtSwitch, \"Unexpected case in switch.\");";
			}
			case Bytecode.CTailCall: {
				needpc.set(pc, pc + 5);
				var locals = code.readInt32();
				labels.set(pc, true);
				labels.set(pc + 5, true);
				"DoTailCall(" + locals + "); goto dispatch;";
			}
			case Bytecode.CLast: {
				needpc.set(pc, pc + 1);
				labels.set(pc + 1, true);
				"return;";
			}
			#if cpp
         	default: "?";
         	#end
		}
		bytecode2code.push(s);
		line2pc.push(pc);
	}

	function readString() : String {
		var l = code.readInt31();
		return code.readString(l);
	}

}
