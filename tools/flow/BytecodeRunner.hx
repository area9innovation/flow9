import ByteMemory;
import Flow;
import FlowArray;
import GarbageCollector;

class BytecodeRunner implements Interpreter {
	public function new() {
		linecount = 0;
		refSerial = 0;
	}
	
	// Tags for runtime representations of data
	static inline public var TVoid = 0x00; // 
	static inline public var TBool = 0x01; // +4 : byte
	static inline public var TInt = 0x02; // +4 : int
	static inline public var TDouble = 0x03; // +4 : double
	static inline public var TString = 0x04; // +4: pointer. +8: length, Memory: utf8chars : byte[length]
	static inline public var TArray = 0x05; // +4: pointer. Memory: length : int, values : value[length]
	static inline public var TStruct = 0x06; // +4: pointer, +8: kind. Memory: values[length]
	static inline public var TCodePointer = 0x0c; // +4: pointer.
	static inline public var TNativeFn = 0x14; // +4: int. Index into natives
	static inline public var TRefTo = 0x1f; // +4: pointer. +8: serial for comparison. Memory: value
	static inline public var TNative = 0x20; // +4: int. Index into nativeValues
	static inline public var TClosurePointer = 0x22; // +4: pointer to closure + 8: pointer to code, closure memory: n: int, v1 ... vn
	
	/* Memory representation:
	 *			
	 * 			   0	----------------------------------------------------------------------
	 * 					bytecode
	 * callStackStart	----------------------------------------------------------------------
	 * 					CallStack : [return address and framepointers: int]
	 * 							....
	 * 
	 * 
	 * 							....
	 *		 			Closure stack : [address to free variables on the heap: int]
	 * dataStackStart	----------------------------------------------------------------------
	 * 					Data stack : [ tagged value ]
	 * 							.....
	 * 
	 * 
	 * heapStart		----------------------------------------------------------------------
	 * 					Heap 1 : length, data (except for references which are always stackslot)
	 * 						.....
	 * 
	 * 
	 * 					--- half heap
	 * 
	 * 
	 * 						.....
	 * 					Heap 2 : length, data
	 * heapEnd			----------------------------------------------------------------------
	*/
	
	public function init(codeBytes : BytesInput, d : DebugInfo) {
		this.debugInfo = d;
		infoByAddress = new Map();
		
		// Set up the different memory segments
		var codePosition = 0; //
		callStackStart = codeBytes.size;
		dataStackStart = callStackStart + callStackSize;
		heapStart = dataStackStart + dataStackSize;
		heapEnd = heapStart + heapSize;

		// We have one big piece of continuous memory
		memory = new ByteMemory(heapEnd);
		
		// Set up the runtime pointers
		d.setCodePosition(codePosition);
		this.code = new CodeMemory(codeBytes, memory, codePosition);
		
		cp = callStackStart;
		csp = dataStackStart;
		sp = dataStackStart;

		highHeap = true;
		var heap = heapLimits(highHeap);
		hp = heap.start;
		hplimit = heap.limit;
		hpbound = heap.bound;
		
		framepointer = sp;
		closurepointer = 0;
		natives = new FlowArray();
		nativeValues = new Map<Int, Dynamic>();
		nativeValueSerial = 0;
		#if profilecalls
		nativeid2name = new FlowArray();
		#end
		
		structDefs = new FlowArray();
		
		toplevel = new Map();
		
		debugFnInfo = new FlowArray();
		
		nativeRoots = new Map<Int,Flow>();
		nNativeRoots = 0;
		
		memoryToCode = new Map<Int,Int>();
		memoryExtent = new Map<Int,Int>();
		memoryUsage = new Map<Int,Int>();

		hasFailed = false;
		runcount = 0;
	}

	#if flash
	// run with timeout check
	private function run_tc() {
		try {
			run();
		} catch (e : flash.errors.ScriptTimeoutError) {
			if (!hasFailed) {
				trace("We've got Flash timeout: " + e + " at " + code.getPosition());
				printCallstack();
				hasFailed = true;
			}
			throw e;
		}
	}
	#end

	public function run() {
		var memory = memory;
		var code = code;
		var localruncount = 0;
		while (!code.eof()) {
			// TODO: If we want to implement code coverage, this is a good place to record all pcs
			var opcode = code.readByte();
//			var name = StringTools.hex(opcode, 2);
//			Profiler.get().profileStart(name);
//			print(StringTools.hex(code.getPosition() - 1, 4) + ": " + opcode2string(opcode));
			localruncount++;
			switch (opcode) {
			case Bytecode.CCall: 
				doCall();
			case Bytecode.CTailCall:
				var a = code.readInt31();
				doTailCall(a);
			case Bytecode.CLast:
//				Profiler.get().profileEnd(name);
				runcount += localruncount;
				return;
			case Bytecode.CUncaughtSwitch:
				printCallstack();
				throw "*Uncaught value in switch*";
			case Bytecode.CGetLocal:
				var local = code.readInt31();
				var a = framepointer + local * stackslot;
				pushFromMemory(a);
			case Bytecode.CVoid: 
				// ( --> void)
				memory.setByte(sp, TVoid);
				sp += stackslot;
			case Bytecode.CBool: 
				// value : byte ( --> byte)
				memory.setByte(sp, TBool);
				var v = code.readByte();
				memory.setByte(sp + 4, v);
				sp += stackslot;
			case Bytecode.CInt: 
				// value : int ( --> int)
				var v = code.readInt32();
				memory.setByte(sp, TInt);
				memory.setI32(sp + 4, v);
				sp += stackslot;
			case Bytecode.CDouble: 
				// value : double ( --> double)
				var v = code.readDouble();
				memory.setByte(sp, TDouble);
				memory.setDouble(sp + 4, v);
				sp += stackslot;
			case Bytecode.CString: 
				// length : int, utf8chars : char[length] ( --> string)
				var l = code.readInt31();
				
				// Experiment: Leave the string where it is, and just point to that in the code!
				var p = code.getPosition();
				push(TString, p);
				memory.setI32(sp - stackslot + 8, (l));
				code.setPosition(p + l);
			case Bytecode.CWString:
				// length : byte, utf16 chars : wchar[length] ( --> string)
				var l = code.readByte();
				pushstring(code.readWideString(l));
			case Bytecode.CArray:
				// length : int ( v1 ... vn --> constantarray )
				var length = code.readInt31();
				var bytes = length * stackslot;
				allocate(bytes + 4);
				memory.setI32(hp, (length));
				memory.copy(sp - bytes, hp + 4, bytes);
				sp -= bytes;
				push(TArray, hp);
			case Bytecode.CStruct:
				// kind : int ( v1 ... vn --> struct)
				var kind = code.readInt31();
				
				var structDef = structDefs[kind];
				var args = structDef.length - 1; // Do not count the name

				// Now make an array out of all of this
				var length = args;
				if (length > 0) {
					var bytes = length * stackslot;
					allocate(bytes);
					sp -= bytes;
					memory.copy(sp, hp, bytes);
					push(TStruct, hp);
				} else {
					push(TStruct, 0);
				}
				// Put the kind as part of the value
				memory.setI32(sp - stackslot + 8, (kind));

			case Bytecode.CArrayGet:
				// ( array index --> value )
				var a = I2i.toInt(memory.getI32(sp + 4 - 2 * stackslot));
				var i = I2i.toInt(memory.getI32(sp + 4 - stackslot));
				if (true) {
					if (memory.getByte(sp - 2 * stackslot) != TArray || memory.getByte(sp - stackslot) != TInt) {
						throw "Array expected array and int, but got  " + memoryToString(sp - 2 * stackslot) + " and " + memoryToString(sp - stackslot);
					}
					if (i < 0) {
						throw "Out of bounds indexing of array: Indexed " + i;
					}
					var al = I2i.toInt(memory.getI32(a));
					if (i >= al) {
						throw "Out of bounds indexing of array: Indexed " + i + " in array of " + al;
					}
				}
				memory.copy(a + 4 + i * stackslot, sp - 2 * stackslot, stackslot);
				sp -= stackslot;
			case Bytecode.CGoto:
				var offset = code.readInt31();
				code.setPosition(code.getPosition() + offset);
			case Bytecode.CCodePointer:
				var offset = code.readInt31();
				push(TCodePointer, code.getPosition() + offset);
			case Bytecode.CReturn:
				doReturn();
			case Bytecode.CNativeFn: 
				// Push a native pointer to code here on the stack
				var args = code.readInt31();
				var fn = readString();
				var nativeFn = makeNativeFn(fn, args);
				var id = natives.length;
				natives[id] = nativeFn;
				#if profilecalls
				nativeid2name[id] = fn;
				#end
				push(TNativeFn, id);
			case Bytecode.COptionalNativeFn:
				// Push a native pointer to code here on the stack
				var args = code.readInt31();
				var fn = readString();
				try {
					var nativeFn = makeNativeFn(fn, args);
					var id = natives.length;
					natives[id] = nativeFn;
					#if profilecalls
					nativeid2name[id] = fn;
					#end
					sp -= stackslot; // replace stack top
					push(TNativeFn, id);
				} catch (x : Dynamic) {
					// ignore
				}
			case Bytecode.CSetLocal:
				var slot = code.readInt31();
				memory.copy(sp - stackslot, framepointer + slot * stackslot, stackslot);
				sp -= stackslot;
			case Bytecode.CPlus:
				sp -= stackslot;
				var t = memory.getByte(sp);
				if (t == TInt) {
					if (memory.getByte(sp - stackslot) != TInt) {
						throw "Trying to add int with non-int " + memoryToString(sp - stackslot);
					}
					memory.setI32(sp - stackslot + 4, (memory.getI32(sp - stackslot + 4) + memory.getI32(sp + 4)));
				} else if (t == TDouble) {
					if (memory.getByte(sp - stackslot) != TDouble) {
						throw "Trying to add double with non-double " + memoryToString(sp - stackslot);
					}
					memory.setDouble(sp - stackslot + 4, memory.getDouble(sp - stackslot + 4) + memory.getDouble(sp + 4));
				} else if (t == TString) {
					if (memory.getByte(sp - stackslot) != TString) {
						throw "Trying to add string with non-string " + memoryToString(sp - stackslot);
					}
					var s1 = I2i.toInt(memory.getI32(sp - stackslot + 4));
					var l1 = I2i.toInt(memory.getI32(sp - stackslot + 8));
					var s2 = I2i.toInt(memory.getI32(sp + 4));
					var l2 = I2i.toInt(memory.getI32(sp + 8));
					if (s1 + l1 == s2 || l1 == 0 || l2 == 0) {
						// We can do this in constant time - just update the length!
						memory.setI32(sp - stackslot + 8, (l1 + l2));
						if (l1 == 0)
							memory.setI32(sp - stackslot + 4, (s2));
					} else {
						allocate(l1 + l2);
						memory.copy(s1, hp, l1);
						memory.copy(s2, hp + l1, l2);
						memory.setI32(sp - stackslot + 4, (hp));
						memory.setI32(sp - stackslot + 8, (l1 + l2));
					}
				} else {
					throw "Plus not implemented for " + t;
				}
			case Bytecode.CPlusInt:
				sp -= stackslot;
				var t = memory.getByte(sp);
				if (t != TInt || memory.getByte(sp - stackslot) != TInt) {
					throw "PlusInt only wants ints.";
				}
				memory.setI32(sp - stackslot + 4, (memory.getI32(sp - stackslot + 4) + memory.getI32(sp + 4)));

			case Bytecode.CPlusString:
				sp -= stackslot;
				var t = memory.getByte(sp);
				if (t != TString || memory.getByte(sp - stackslot) != TString) {
					throw "PlusString only wants strings." + memoryToString(sp) + ' ' + memoryToString(sp - stackslot);
				}
				var s1 = I2i.toInt(memory.getI32(sp - stackslot + 4));
				var l1 = I2i.toInt(memory.getI32(sp - stackslot + 8));
				var s2 = I2i.toInt(memory.getI32(sp + 4));
				var l2 = I2i.toInt(memory.getI32(sp + 8));
				if (s1 + l1 == s2 || l1 == 0 || l2 == 0) {
					// We can do this in constant time - just update the length!
					memory.setI32(sp - stackslot + 8, (l1 + l2));
					if (l1 == 0)
						memory.setI32(sp - stackslot + 4, (s2));
				} else {
					allocate(l1 + l2);
					memory.copy(s1, hp, l1);
					memory.copy(s2, hp + l1, l2);
					memory.setI32(sp - stackslot + 4, (hp));
					memory.setI32(sp - stackslot + 8, (l1 + l2));
				}
					
			case Bytecode.CMinus:
				sp -= stackslot;
				var t = memory.getByte(sp);
				if (t == TInt) {
					if (memory.getByte(sp - stackslot) != TInt) {
						throw "Trying to subtract int with non-int " + memoryToString(sp - stackslot);
					}
					memory.setI32(sp - stackslot + 4, (memory.getI32(sp - stackslot + 4) - memory.getI32(sp + 4)));
				} else if (t == TDouble) {
					if (memory.getByte(sp - stackslot) != TDouble) {
						throw "Trying to subtract double with non-double " + memoryToString(sp - stackslot);
					}
					memory.setDouble(sp - stackslot + 4, memory.getDouble(sp - stackslot + 4) - memory.getDouble(sp + 4));
				} else {
					throw "Minus not implemented for " + t;
				}
			case Bytecode.CMinusInt:
				sp -= stackslot;
				var t = memory.getByte(sp);
				if (t != TInt || memory.getByte(sp - stackslot) != TInt) {
					throw "MinusInt only wants ints.";
				}
				memory.setI32(sp - stackslot + 4, (memory.getI32(sp - stackslot + 4) - memory.getI32(sp + 4)));

			case Bytecode.CMultiply:
				sp -= stackslot;
				var t = memory.getByte(sp);
				if (t == TInt) {
					if (memory.getByte(sp - stackslot) != TInt) {
						throw "Trying to multiply int with non-int " + memoryToString(sp - stackslot);
					}
					memory.setI32(sp - stackslot + 4, (memory.getI32(sp - stackslot + 4) * memory.getI32(sp + 4)));
				} else if (t == TDouble) {
					if (memory.getByte(sp - stackslot) != TDouble) {
						throw "Trying to multiply double with non-double " + memoryToString(sp - stackslot);
					}
					memory.setDouble(sp - stackslot + 4, memory.getDouble(sp - stackslot + 4) * memory.getDouble(sp + 4));
				} else {
					throw "Multiply not implemented for " + t;
				}
			case Bytecode.CMultiplyInt:
				sp -= stackslot;
				var t = memory.getByte(sp);
				if (t != TInt || memory.getByte(sp - stackslot) != TInt) {
					throw "MultiplyInt only wants ints.";
				}
				memory.setI32(sp - stackslot + 4, (memory.getI32(sp - stackslot + 4) * memory.getI32(sp + 4)));
			case Bytecode.CDivide:
				sp -= stackslot;
				var t = memory.getByte(sp);
				if (t == TInt) {
					if (memory.getByte(sp - stackslot) != TInt) {
						throw "Trying to divide non-int " + memoryToString(sp - stackslot) + ' with int';
					}
					memory.setI32(sp - stackslot + 4, Std.int(memory.getI32(sp - stackslot + 4) / memory.getI32(sp + 4)));
				} else if (t == TDouble) {
					if (memory.getByte(sp - stackslot) != TDouble) {
						throw "Trying to divide non-double " + memoryToString(sp - stackslot) + ' with double';
					}
					memory.setDouble(sp - stackslot + 4, memory.getDouble(sp - stackslot + 4) / memory.getDouble(sp + 4));
				} else {
					throw "Divide not implemented for " + t;
				}
			case Bytecode.CDivideInt:
				sp -= stackslot;
				var t = memory.getByte(sp);
				if (t != TInt || memory.getByte(sp - stackslot) != TInt) {
					throw "DivideInt only wants ints.";
				}
				memory.setI32(sp - stackslot + 4, Std.int(memory.getI32(sp - stackslot + 4) / memory.getI32(sp + 4)));

			case Bytecode.CModulo:
				sp -= stackslot;
				var t = memory.getByte(sp);
				if (t == TInt) {
					memory.setI32(sp - stackslot + 4, (memory.getI32(sp - stackslot + 4) % memory.getI32(sp + 4)));
				} else if (t == TDouble) {
					memory.setDouble(sp - stackslot + 4, memory.getDouble(sp - stackslot + 4) % memory.getDouble(sp + 4));
				} else {
					throw "Modulo not implemented for " + t;
				}
			case Bytecode.CModuloInt:
				sp -= stackslot;
				var t = memory.getByte(sp);
				if (t != TInt || memory.getByte(sp - stackslot) != TInt) {
					throw "ModuloInt only wants ints.";
				}
				memory.setI32(sp - stackslot + 4, (memory.getI32(sp - stackslot + 4) % memory.getI32(sp + 4)));

			case Bytecode.CNegate:
				var t = memory.getByte(sp - stackslot);
				if (t == TInt) {
					memory.setI32(sp - stackslot + 4, -(memory.getI32(sp - stackslot + 4)));
				} else if (t == TDouble) {
					memory.setDouble(sp - stackslot + 4, -memory.getDouble(sp - stackslot + 4));
				} else {
					throw "Negate not implemented for " + t;
				}
			case Bytecode.CNegateInt:
				var t = memory.getByte(sp - stackslot);
				if (t == TInt) {
					memory.setI32(sp - stackslot + 4, -(memory.getI32(sp - stackslot + 4)));
				} else {
					throw "NegateInt does not want " + t;
				}
			case Bytecode.CEqual:
				sp -= stackslot;
				var c = compare(sp - stackslot, sp);
				memory.setByte(sp - stackslot, TBool);
				memory.setByte(sp - stackslot + 4, if (c == 0) 1 else 0);
			case Bytecode.CLessThan:
				sp -= stackslot;
				var c = compare(sp - stackslot, sp);
				memory.setByte(sp - stackslot, TBool);
				memory.setByte(sp - stackslot + 4, if (c < 0) 1 else 0);
			case Bytecode.CLessEqual:
				sp -= stackslot;
				var c = compare(sp - stackslot, sp);
				memory.setByte(sp - stackslot, TBool);
				memory.setByte(sp - stackslot + 4, if (c <= 0) 1 else 0);
			case Bytecode.CNot:
				memory.setByte(sp - stackslot + 4, 1 - memory.getByte(sp - stackslot + 4));
			case Bytecode.CIfFalse:
				var offset = code.readInt31();
				sp -= stackslot;
				if (memory.getByte(sp + 4) == 0) {
					code.setPosition(code.getPosition() + offset);
				}
			case Bytecode.CGetGlobal:
				var global = code.readInt31();
				var a = dataStackStart + global * stackslot;
				pushFromMemory(a);
			case Bytecode.CReserveLocals:
				var l = code.readInt31();
				sp += l * stackslot;
				var v = code.readInt31();
				framepointer -= v * stackslot;
			case Bytecode.CPop:
				sp -= stackslot;
			case Bytecode.CRefTo:
				allocate(stackslot);
				memory.copy(sp - stackslot, hp, stackslot);
				sp -= stackslot;
				push(TRefTo, hp);
				// In order for comparisons of references to be possible, and stable across
				// gc, they get a stable serial number
				memory.setI32(sp - stackslot + 8, refSerial);
				refSerial = (refSerial + 1);
			case Bytecode.CDeref:
				var a = I2i.toInt(memory.getI32(sp + 4 - stackslot));
				memory.copy(a, sp - stackslot, stackslot);
			case Bytecode.CSetRef:
				var a = I2i.toInt(memory.getI32(sp + 4 - 2 * stackslot));
				memory.copy(sp - stackslot, a, stackslot);
				sp -= stackslot;
				memory.setByte(sp - stackslot, TVoid);
			case Bytecode.CInt2Double: 
				var a = memory.getI32(sp + 4 - stackslot);
				memory.setByte(sp - stackslot, TDouble);
				memory.setDouble(sp + 4 - stackslot, I2i.floatFromInt(a));
			case Bytecode.CInt2String: 
				sp -= stackslot;
				var a = memory.getI32(sp + 4);
				pushstring('' + a);
			case Bytecode.CDouble2Int: 
				var a = memory.getDouble(sp + 4 - stackslot);
				memory.setByte(sp - stackslot, TInt);
				memory.setI32(sp + 4 - stackslot, I2i.intFromFloat(a));
			case Bytecode.CDouble2String:
				sp -= stackslot;
				var a = memory.getDouble(sp + 4);
				pushstring('' + a);
			case Bytecode.CField:
				var i = code.readInt31();
				var a = I2i.toInt(memory.getI32(sp - stackslot + 4));
				memory.copy(a + i * stackslot, sp - stackslot, stackslot);
			case Bytecode.CFieldName:
				var n = readString();
				var a = I2i.toInt(memory.getI32(sp - stackslot + 4));
				var i = findStructField(n, sp-stackslot, true);
				if (i >= 0)
					memory.copy(a + i * stackslot, sp - stackslot, stackslot);
			case Bytecode.CSetMutable:
				var i = code.readInt31();
				var a = I2i.toInt(memory.getI32(sp - 2*stackslot + 4));
				memory.copy(sp - stackslot, a + i * stackslot, stackslot);
				sp -= stackslot;
				memory.setByte(sp - stackslot, TVoid);
			case Bytecode.CSetMutableName:
				var n = readString();
				var a = I2i.toInt(memory.getI32(sp - 2*stackslot + 4));
				var i = findStructField(n, sp-2*stackslot, false);
				memory.copy(sp - stackslot, a + i * stackslot, stackslot);
				sp -= stackslot;
				memory.setByte(sp - stackslot, TVoid);
			case Bytecode.CStructDef:
				var id = code.readInt31();
				var name = readString();
				var args = new FlowArray();
				args.push(name);
				var n = code.readInt31();
				for (i in 0...n) {
					args.push(readString());
					// Skip type of field
					var eot = false;
					do { 
						var b = code.readByte();
						if ( b == Bytecode.CTypedStruct) readString();
						if ( b != Bytecode.CTypedArray && b != Bytecode.CTypedRefTo && b != Bytecode.CSetMutable) eot = true;
					} while (!eot);
				}
				structDefs[id] = args;
			case Bytecode.CGetFreeVar:
				var n = code.readInt31();
				var a = closurepointer + n * stackslot;
				pushFromMemory(a);
			case Bytecode.CDebugInfo:
				var name = readString();
				// Just record it
				var r = { pc: code.getPosition(), fn : name, slot : sp };
				/*
				// If top-level stuff does not produce the right amount of entries on the stack, this can find the problem:
				var a = (sp - dataStackStart) / stackslot;
				if (a != debugFnInfo.length) {
					trace(name + " at " + a + " " + debugFnInfo.length);
				}
				*/
				debugFnInfo.push( r );
				
			case Bytecode.CClosureReturn:
				closurepointer = closureStackPop();
				doReturn();
			case Bytecode.CClosurePointer:
				var n = code.readInt31();
				var offset = code.readInt31();
				// Move the variables to the heap
				var bytes = n * stackslot;
				allocate(bytes  + 4);
				memory.setI32(hp, (n));
				memory.copy(sp - bytes, hp  + 4, bytes);
				sp -= bytes;
				push(TClosurePointer, hp);
				memory.setI32(sp - stackslot + 8, (code.getPosition() + offset));
			case Bytecode.CSwitch:
				var codePos = code.getPosition();
				
				var t = memory.getByte(sp - stackslot);
				if (t != TStruct) {
					throw "Can not switch on " + memoryToString(sp - stackslot) + " at " + StringTools.hex (codePos - 1, 4);
				}
				var cases = code.readInt31();
				var end = code.readInt31();
				
				var pos = code.getPosition() + cases * 8;
				
				var add = I2i.toInt(memory.getI32(sp - stackslot + 4));
				var structId = I2i.toInt(memory.getI32(sp - stackslot + 8));
				
				// In the default case, we just eat the struct value
				sp -= stackslot;
				for (i in 0...cases) {
					var cn = code.readInt31();
					var offset = code.readInt31();
					if (cn == structId) {
						try {
							// We have a hit. Let's put the value of the structure on the struct as local variables
							var n = structDefs[structId].length - 1;
							memory.copy(add, sp, n * stackslot);
							sp += n * stackslot;
							code.setPosition(pos + offset);
						} catch (e : Dynamic) {
							throw "Crazy stuff with switch on " + structDefs[structId];
						}
						break;
					}
				}
			case Bytecode.CSimpleSwitch:
				// the same as CSwitch, except it does not push the fields of the struct
				var codePos = code.getPosition();
				
				var t = memory.getByte(sp - stackslot);
				if (t != TStruct) {
					throw "Can not switch on " + memoryToString(sp - stackslot);
				}
				var cases = code.readInt31();
				var end = code.readInt31();
				
				var pos = code.getPosition() + cases * 8;
				
				var add = I2i.toInt(memory.getI32(sp - stackslot + 4));
				var structId = I2i.toInt(memory.getI32(sp - stackslot + 8));
				
				// In the default case, we just eat the struct value
				sp -= stackslot;
				for (i in 0...cases) {
					var cn = code.readInt31();
					var offset = code.readInt31();
					if (cn == structId) {
							/*only difference to CSwitch: do not push these values, the code
							  for the cases must extract them manually:
								try {
							var n = structDefs[structId].length - 1;
							memory.copy(add, sp, n * stackslot);
							sp += n * stackslot;
							*/
						code.setPosition(pos + offset);
							/*
							  } catch (e : Dynamic) {
								throw "Crazy stuff with simple switch on " + structDefs[structId];
							}*/
						break;
					}
				}
			default:
				var m = "Opcode not implemented: " + opcode2string(opcode) + " at " + addressToFunction(code.getPosition() - 1);
				if (!hasFailed) {
					reportFailure(m, null);
					hasFailed = true;
				}
				throw m;
			}
			//Profiler.get().profileEnd(name);
		}
	}

	function findStructField(n : String, addr : Int, read : Bool) {
		var structId = I2i.toInt(memory.getI32(addr + 8));
		var structFields = structDefs[structId];
		if (structFields != null) {
			if (n == "structname") {
				if (!read)
					throw "Could not change the struct name";
				sp -= stackslot;
				pushstring(structFields[0]);
				return -1;
			}
			var found = false;
			var i = -1;
			for (v in structFields) {
				// Skip the name
				if (i > -1) {
					if (v == n)
						return i;
				}
				++i;
			}
			throw "Could not find field " + n + " in " + memoryToString(addr);
		} else {
			throw "Could not look up struct";
		}
	}
	
	function doCall() {
		// TODO: If we want to collect time profiling, this is a good place to record the start time.
		// Remember to rig up doReturn as well.
		
		sp -= stackslot;
		
		var op = memory.getByte(sp);
		if (op == TCodePointer) {
			callStackPush(code.getPosition());
			callStackPush(framepointer);
			framepointer = sp;
			var address = I2i.toInt(memory.getI32(sp + 4));
			code.setPosition(address);

			#if profilecalls
				// This is a rough profile counter of how frequent calls are made. It does not measure time spent, but only frequency
				var name = addressToFunction(address);
				Profiler.get().count(name, 0.000001);
			#end
		} else if (op == TClosurePointer) {
			callStackPush(code.getPosition());
			callStackPush(framepointer);
			closureStackPush(closurepointer);
			framepointer = sp;
			var closure = I2i.toInt(memory.getI32(sp + 4));
			closurepointer = closure + 4;
			var address = I2i.toInt(memory.getI32(sp + 8));
			code.setPosition(address);

			#if profilecalls
				// This is a rough profile counter of how frequent calls are made. It does not measure time spent, but only frequency
				var name = addressToFunction(address);
				Profiler.get().count(name, 0.000001);
			#end
		} else if (op == TNativeFn) {
			var id = I2i.toInt(memory.getI32(sp + 4));
			#if profilecalls
				var name = nativeid2name[id];
				Profiler.get().profileStart(name);
			#end
			natives[id]();
			#if profilecalls
				Profiler.get().profileEnd(name);
			#end
		} else {
			// Fix up the stack so we can see what element is at the top of the stack
			sp += stackslot;
			throw "Not callable 0x" + StringTools.hex(op, 2);
		}
	}
	
	function doTailCall(nargs : Int) {
		var op = memory.getByte(sp - stackslot);
		if (op == TCodePointer) {
			// First, find the code address
			sp -= stackslot;
			var address = I2i.toInt(memory.getI32(sp + 4));
			
			// OK, move the arguments down to the previous frame, which we are going to reuse
			memory.copy(sp - nargs * stackslot, framepointer, nargs * stackslot);
			
			// Fix the frame up so that Treservelocals in the function itself will make this the reuse
			framepointer += nargs * stackslot;
			sp = framepointer;
			// And then go!
			code.setPosition(address);
		} else {
			doCall();
		}
	}
	
	function doReturn() {
		// Copy the result to the right place
		memory.copy(sp - stackslot, framepointer, stackslot);
		sp = framepointer + stackslot;
		
		// restore framepointer
		framepointer = callStackPop();
		code.setPosition(callStackPop());
	}
	
	// This returns 0 is equal, something less than 0 if a1 is smaller than a2, and something higher than 0 if a1 is greater than a2
	function compare(a1 : Int, a2 : Int) : Int {
		if (a1 == a2) {
			return 0;
		}
		
		// print(memoryToString(a1) + " <=> " + memoryToString(a2) + "?");
		var t = memory.getByte(a1);
		
		if (t == TInt) {
			var i1 = memory.getI32(a1 + 4);
			var i2 = memory.getI32(a2 + 4);
			return I2i.compare(i1, i2);
		} else if (t == TDouble) {
			if (memory.getDouble(a1 + 4) < memory.getDouble(a2 + 4)) {
				return -1;
			} else if (memory.getDouble(a1 + 4) == memory.getDouble(a2 + 4)) {
				return 0;
			} else {
				return 1;
			}
		} else if (t == TBool) {
			if (memory.getByte(a1 + 4) < memory.getByte(a2 + 4)) {
				return -1;
			} else if (memory.getByte(a1 + 4) == memory.getByte(a2 + 4)) {
				return 0;
			} else {
				return 1;
			}
		} else if (t == TString) {
			// String comparison
			var s1 = I2i.toInt(memory.getI32(a1 + 4));
			var s2 = I2i.toInt(memory.getI32(a2 + 4));
			var l1 = I2i.toInt(memory.getI32(a1 + 8));
			var l2 = I2i.toInt(memory.getI32(a2 + 8));
			if ((s1 == s2) && (l1 == l2)) return 0;
			for (i in 0...Math.floor(Math.min(l1, l2))) {
				var c1 = memory.getByte(s1 + i);
				var c2 = memory.getByte(s2 + i);
				if (c1 < c2) {
					return -1;
				} else if (c1 > c2) {
					return 1;
				}
			}
			if (l1 < l2) {
				return -1;
			} else if (l1 == l2) {
				return 0;
			} else {
				return 1;
			} 
		} else if (t == TArray) {
			var ad1 = I2i.toInt(memory.getI32(a1 + 4));
			var ad2 = I2i.toInt(memory.getI32(a2 + 4));
			if (ad1 == ad2) return 0;
			var l1 = I2i.toInt(memory.getI32(ad1));
			var l2 = I2i.toInt(memory.getI32(ad2));
			for (i in 0...Math.floor(Math.min(l1, l2))) {
				var e1 = ad1 + i * stackslot + 4;
				var e2 = ad2 + i * stackslot + 4;
				var c1 = memory.getByte(e1);
				var c2 = memory.getByte(e2);
				if (c1 != c2) {
					throw "Not same kind: " + c1 + " and " + c2;
					return 0;
				}
				var c = compare(e1, e2);
				if (c != 0) {
					return c;
				}
			}
			if (l1 < l2) {
				return -1;
			} else if (l1 == l2) {
				return 0;
			} else {
				return 1;
			} 
		} else if (t == TStruct) {
			// +4: pointer, +8: kind, Memory: values[length]
			var kind1 = memory.getI32(a1 + 8);
			var kind2 = memory.getI32(a2 + 8);
			var kcompare = I2i.compare(kind1, kind2);
			if (kcompare != 0) {
				return kcompare;
			}

			var ad1 = I2i.toInt(memory.getI32(a1 + 4));
			var ad2 = I2i.toInt(memory.getI32(a2 + 4));
			if (ad1 == ad2) return 0;
			var l1 = structDefs[I2i.toInt(kind1)].length - 1;
			for (i in 0...l1) {
				var e1 = ad1 + i * stackslot;
				var e2 = ad2 + i * stackslot;
				var c1 = memory.getByte(e1);
				var c2 = memory.getByte(e2);
				if (c1 < c2) {
					return -1;
				} else if (c1 > c2) {
					return 1;
				}
				var c = compare(e1, e2);
				if (c != 0) {
					return c;
				}
			}
			return 0;
		} else if (t == TRefTo) {
			// At first, we compared the raw addresses of references, but those are not stable in
			// ordering across gc, so instead, we compare the reference serial numbers
			return I2i.compare(memory.getI32(a1 + 8), memory.getI32(a2 + 8));
		} else if (t == TVoid) {
			return 0;
		} else if (t == TClosurePointer) {
			return I2i.compare(memory.getI32(a1 + 4), memory.getI32(a2 + 4));
		} else if (t == TCodePointer) {
			return I2i.compare(memory.getI32(a1 + 4), memory.getI32(a2 + 4));
		} else if (t == TNativeFn) {
			return I2i.compare(memory.getI32(a1 + 4), memory.getI32(a2 + 4));
		} else {
			// TODO: Implement for union
			throw "Comparison not implemented: " + StringTools.hex(t, 2) + " " + memoryToString(a1) + " <=> " + memoryToString(a2);
		}		
	}

	// Interface to call named global functions
	
	public function call(global : Int, args : FlowArray<Flow>) {
		callStackPush(code.getPosition());
		// Try to return to the Last instruction
		code.setPosition(code.size - 1);
		for (a in args) {
			pushflow(a);
		}
		
		// Push the global name
		var a = dataStackStart + global * stackslot;
		pushFromMemory(a);
		
		doCall();
		run();
		code.setPosition(callStackPop());
	}
	
	public function toString(value : Flow) : String {
		pushflow(value);
		sp -= stackslot;
		return memoryToString(sp);
	}
	
	// Native function access

	public function eval(exp : Flow) : Flow {
		switch (exp) {
		case Call(c, args, p):
			callStackPush(code.getPosition());
			// Force it to return to the Last instruction to get "run" to stop evaluating
			code.setPosition(code.size - 1);
			for (a in args) {
				pushflow(a);
			}
			pushflow(c);
			doCall();
			#if flash
			run_tc();
			#else
			run();
			#end
			code.setPosition(callStackPop());
		default: throw "Can not eval " + exp;
		}
		try {
			return popflow();
		} catch (e : Dynamic) {
			trace("Could not evaluate " + Prettyprint.prettyprint(exp) + ": " + e);
			throw e;
		}
	}

	public function reportFailure(message : String, exception : Dynamic) {
		if (hasFailed) {
			// Avoid redundant failure reports
			return;
		}

		hasFailed = true;

		print(message + (exception != null ? ': '+exception : ''));
		printCallstack();

		// End execution brutally!
		code.setPosition(code.size - 1);
		cp = callStackStart;
	}

	public function printCallstack() : Void {
		var depth = Math.floor((cp - callStackStart) / 4);

		var count = 10;
		var n = count;

		print(addressToFunction(code.getPosition()));
		var codeEnd = code.size - 1;
		var i = cp - 4;
		while (n >= 0 && i >= callStackStart) {
			try {
				var address = I2i.toInt(memory.getI32(i));
				if (address == codeEnd) {
					// Nested native call, just skip it
					print("Call from some native");
					n--;
				} else {
					var t = addressToFunction(address);
					if (t.indexOf("Stack:") == -1) {
						print(t);
						n--;
					}
				}
				i -= 4;
			} catch (e : Dynamic) {
				print("<?>");
			}
		}
		if (false && i > callStackStart) {
			print("...");
			for (i in 0...count) {
				try {
					print(addressToFunction(I2i.toInt(memory.getI32(callStackStart + 4 * i))));
				} catch (e : Dynamic) {
					print("<?>");
				}
			}
		}
		print("");
//		dumpstack();
	}

	public function functionToAddress(fn: String) : Int {
		for (di in debugFnInfo) {
			if (fn == di.fn) return di.pc;
		}

		return -1; // means not found
	}
	
	function addressToFunction(pc : Int) : String {
		if (pc == code.size - 1) {
			return "<Native function>";
		} else if (pc >= code.size) {
			// It's a frame-pointer or closure pointer
			if (pc < dataStackStart) {
				return "  Frame: " + StringTools.hex(pc, 4)/* + ':' + memoryToString(pc)*/; 
			} else if (pc < sp) {
				return "  Stack: " + StringTools.hex(pc, 4)/* + ':' + memoryToString(pc)*/; 
			} else {
				return "  Closure: " + StringTools.hex(pc, 4);
			}
		}
		var p = "";
		if (debugInfo != null) {
			p = debugInfo.getPosition(pc);
		}

		var fn = findFnInfoByAddress(pc);
		if (fn != null)
			return p + fn.name;
		else
			return p + " Lambda at " + StringTools.hex(pc, 4);
	}

	public function findFnInfoByAddress(pc : Int) : Null<{name:String, start:Int, end:Int}> {
		var info = infoByAddress.get(pc);
		if (info != null) {
			return info;
		}
		for (i in 0...debugFnInfo.length - 1) {
			var start = debugFnInfo[i].pc;
			var end = debugFnInfo[i + 1].pc;
			if (start <= pc && pc < end) {
				info = {name:debugFnInfo[i].fn, start:start, end:end};
				// + " from " + StringTools.hex(debugFnInfo[i].pc, 4) + ' at ' + StringTools.hex(pc, 4);
				infoByAddress.set(pc, info);
				return info;
			}
		}
		return null;
	}
	var infoByAddress : Map<Int, {name:String, start:Int, end:Int} >;
	
	function makeNativeFn(name : String, numberargs : Int) : Void -> Void {
		if (name == "Native.mapi") {
			return nativeMapi;
		} else if (name == "Native.map") {
			return nativeMap;
		} else if (name == "Native.iteri") {
			return nativeIteri;
		} else if (name == "Native.iter") {
			return nativeIter;
		} else if (name == "Native.fold") {
			return nativeFold;
		} else if (name == "Native.length") {
			return nativeLength;
		} else if (name == "Native.replace") {
			return nativeReplace;
		} else if (name == "Native.strlen") {
			return nativeStrlen;
		} else if (name == "Native.substring") {
			return nativeSubstring;
		} else if (name == "Native.strIndexOf") {
			return nativeStrIndexOf;
		} else if (name == "Native.getCharCodeAt") {
			return nativeGetCharCodeAt;
		} else if (name == "Native.concat") {
			return nativeConcat;
		} else if (name == "Native.list2string") {
			return nativeList2string;
		} else if (name == "Native.list2array") {
			return nativeList2array;
		#if flash
		} else if (name == "RenderSupport.setTextAndStyle") {
			return renderSupportSetTextAndStyle;
		#end
		#if flash
		} else if (name == "RenderSupport.setAdvancedText") {
			return renderSupportSetAdvancedText;
		#end
		} else if (name == "Native.isArray") {
			return nativeIsArray;
		} else if (name == "Native.stringbytes2double") {
			return stringbytes2double;
		} else if (name == "Native.stringbytes2int") {
			return stringbytes2int;
		}
		
		var clas = null;
		var method = name;
		var lastDot = name.lastIndexOf(".");
		if (lastDot > 0) {
			clas = name.substr(0, lastDot);
			method = name.substr(lastDot + 1);
		}

		if (clas != null) {
			try {
				var cl = Type.resolveClass(clas);
				if (cl == null) {
					throw "Could not resolve native " + clas;
				}
				var obj = Type.createInstance(cl, [this]);
				var meth = Reflect.field(obj, method);

				return function() : Void {
					// Read numberargs from the stack and put them into args 
					var args = new FlowArray();
					for (i in 0...numberargs) {
						args.unshift(popflow());
					}
					
					var pos = { };
					var r : Flow = null;
					try {
						// To find out which natives could benefit from stack-based implementation, this can be used:
						// if (name.indexOf("profile") == -1) Profiler.get().profileStart(name);
						r = Reflect.callMethod(obj, meth, [args, pos]);
						// if (name.indexOf("profile") == -1) Profiler.get().profileEnd(name);
					} catch (e : Dynamic) {
						var error = "Exception " + e + " caught in native implementation of " + name;
						var sep = "(";
						for (a in args) {
							error += sep + Prettyprint.prettyprint(a);
							sep = ", ";
						}
						error += ")";
						reportFailure(error, e);
						throw error;
					}
					try {
						pushflow(r);
					} catch (e : Dynamic) {
						var error = "Too complicated result value from native implementation of " + name;
						var sep = "(";
						for (a in args) {
							error += sep + Prettyprint.prettyprint(a);
							sep = ", ";
						}
						error += ")";
						reportFailure(error, e);
						throw error 
							+ "):\n"
							+ Prettyprint.prettyprint(r)
							+ ":\n" + e;
					}
					return;
				}
			} catch (e : Dynamic) {
				throw "Could not make native " + name + ": " + e + ". Recompile flowflash.hxml, flowrunner.hxml";
			}
		}
		throw "Native " + name + " requires a class in this target";
	}


	//
	// Native implementations that use the stack for efficiency
	//
	private inline function writeBinaryInt32(value : Int, buf : Array<Int>) : Void {
		buf.push(value & 0xFFFF );
		buf.push(value >> 16);
	}
	
	var structIdxs : Map<Int,Int>; // struct id -> idx in the struct def table in the footer
	var binStructDefs : Array<Dynamic>;
	
	private function writeStructDefs(buf : Array<Int>) : Void {
		buf.push(0xFFF8);
		buf.push(binStructDefs.length);
		for (struct_def in binStructDefs) {
			buf.push(0xFFF8); buf.push(0x0002);
			buf.push(cast (struct_def.length - 1));
			buf.push(0xFFFA);
			var name = struct_def[0];
			buf.push(name.length);
			for (i in 0...name.length)
				buf.push(name.charCodeAt(i));
		}
	}

	private function writeBinaryValue(addr : Int, buf : Array<Int>) {
		var type = memory.getByte(addr);
		
		switch (type) {
			case TVoid:
				buf.push(0xFFFF);
			case TBool:
				buf.push( memory.getByte(addr + 4) == 1 ? 0xFFFE : 0xFFFD );
			case TInt:
				var int_value = memory.getI32(addr + 4);
				if ((int_value & 0xFFFF8000 ) != 0) {
					buf.push(0xFFF5);
					writeBinaryInt32(int_value, buf);
				} else {
					buf.push(I2i.toInt(int_value));
				}
			case TDouble:
				buf.push(0xFFFC);
				writeBinaryInt32(memory.getI32(addr + 4), buf);
				writeBinaryInt32(memory.getI32(addr + 8), buf);
			case TString:
				var str_addr : Int =  memory.getI32(addr + 4);
				var str_len : Int = memory.getI32(addr + 8);
				
				if ( (str_len & 0xFFFF0000 ) != 0 ) {
					buf.push(0xFFFB);
					writeBinaryInt32(str_len, buf);
				} else {
					buf.push(0xFFFA);
					buf.push( I2i.toInt(str_len) );
				}
				
				var str = memory.getString(I2i.toInt(str_addr), I2i.toInt(str_len) );
				for (i in 0...str.length)
					buf.push(str.charCodeAt(i));
			case TArray:
				var arr_addr = memory.getI32(addr + 4);
				var arr_len = memory.getI32(I2i.toInt(arr_addr));
				
				if (arr_len == 0) {
					buf.push(0xFFF7);
				} else {
					if ( (arr_len & 0xFFFF0000) != 0 ) {
						buf.push(0xFFF9);
						writeBinaryInt32(arr_len, buf);
					} else {
						buf.push(0xFFF8);
						buf.push(I2i.toInt(arr_len));
					}
					for (i in 0...I2i.toInt(arr_len) ) {
						writeBinaryValue(I2i.toInt(arr_addr) + 4 + i * stackslot, buf);
					}
				}
			case TStruct:
				var struct_addr = I2i.toInt(memory.getI32(addr + 4));
				var struct_id = I2i.toInt(memory.getI32(addr + 8));
				var struct_def = structDefs[struct_id];
				if (struct_def == null)
					throw "Struct Id not found";
				
				var struct_idx = 0;
				if ( structIdxs.exists(struct_id) ) {
					struct_idx = structIdxs.get(struct_id);
				} else {
					struct_idx = binStructDefs.length;
					structIdxs.set(struct_id, struct_idx);
					binStructDefs.push(struct_def);
				}
				
				var fields_count = struct_def.length - 1;
				buf.push(0xFFF4);
				buf.push(struct_idx);

				for (i in 0...fields_count) 
					writeBinaryValue(struct_addr + i * stackslot, buf);
			case TRefTo:
				buf.push(0xFFF6);
				writeBinaryValue( I2i.toInt(memory.getI32(addr + 4)), buf );
		}
	}

	private function bufToString(buf : Array<Int>) : String {
		var ret = new haxe.Utf8(buf.length);
		for (i in 0...buf.length)
			ret.addChar(buf[i]);
		return ret.toString();
	}
	
	private function toBinary() : Void {
		// This target has only one byte per one char for strings
		// so toBinary cannot work for now
		throw "toBinary: This operation is not supported on this target";

		structIdxs = new Map<Int,Int>();
		binStructDefs = new Array<Dynamic>();

		var addr = sp - stackslot;
		sp -= stackslot;
		
		var buf : Array<Int> = new Array<Int>();
		buf.push(0); buf.push(0); // Offset of struct defs
		writeBinaryValue(addr, buf);

		var structs_offset = buf.length;
		var struct_defs_buf = new Array<Int>(); 
		writeStructDefs(buf);

		buf[0] = structs_offset & 0xFFFF; buf[1] = structs_offset >> 16;

		pushstring(bufToString(buf));
	}
	
	private function stringbytes2double() : Void {
		sp -= stackslot;
		var str = memory.getString(I2i.toInt( memory.getI32(sp + 4)), I2i.toInt( memory.getI32(sp + 8)));
		var len : Int;
		#if sys
		len = haxe.Utf8.length(str);
		#else
		len = str.length;
		#end
		
		if (len != 4)
			throw "String length should be 2 in stringbytes2double";
		
		// Reuse topmost stackslot
		#if sys
		memory.setI32( sp + 4, (( haxe.Utf8.charCodeAt( str, 0) ) |
							((haxe.Utf8.charCodeAt( str, 1) ) >> 16) ) );
		memory.setI32( sp + 8, (( haxe.Utf8.charCodeAt( str, 2) ) |
							((haxe.Utf8.charCodeAt( str, 3) ) >> 16) ) );
		#else
		memory.setI32( sp + 4, ( str.charCodeAt(0) | (str.charCodeAt(1) << 16) ) );
		memory.setI32( sp + 8, ( str.charCodeAt(2) | (str.charCodeAt(3) << 16) ) );
		#end
		
		memory.setByte(sp, TDouble);
		sp += stackslot;
	}
	
	private function stringbytes2int() : Void {
		var str = memory.getString(I2i.toInt( memory.getI32(sp - stackslot + 4)), I2i.toInt( memory.getI32(sp - stackslot + 8)));
		var len : Int;
		#if sys
		len = haxe.Utf8.length(str);
		#else
		len = str.length;
		#end
		
		if (len != 2)
			throw "String length should be 2 in stringbytes2int";
			
		var value : Int;
		#if sys
		value = haxe.Utf8.charCodeAt(str, 0) | ( haxe.Utf8.charCodeAt(str, 1) << 16);
		#else
		value = str.charCodeAt(0) | (str.charCodeAt(1) << 16);
		#end
		
		sp -= stackslot;
		pushi32(value);
	}

	// input & output via data stack ( array closure --> mapi(closure, array) )
	private function nativeMapi() : Void {
		try {
			var a = I2i.toInt(memory.getI32(sp + 4 - 2 * stackslot));
			var cs = sp - stackslot;
			if (memory.getByte(sp - 2 * stackslot) != TArray) {
				throw "nativeMapi expected array and closure, but got  " + memoryToString(sp - 2 * stackslot)
					  + " and " + memoryToString(sp - stackslot);
			}
			var len = I2i.toInt(memory.getI32(a));
			allocate(len * stackslot + 4);
			var a2 = hp;
			memory.setI32(a2, (len));
			for (i in 0...len) {
				pushint(i);
				// Copy value
				pushFromMemory(a + 4 + i * stackslot);
				pushFromMemory(cs);

				doCallInNative();

				// Copy result from mapped function into result array
				sp -= stackslot;
				memory.copy(sp, a2 + 4 + i * stackslot, stackslot);
			}
			// Hack return value into place
			sp = cs;
			memory.setI32(sp - stackslot + 4, (a2));
		} catch (e : Dynamic) {
			reportFailure('nativeMapi exception', e);
		}
	}

	// input & output via data stack ( array closure --> mapi(closure, array) )
	private function nativeMap() : Void {
		try {
			var a = I2i.toInt(memory.getI32(sp + 4 - 2 * stackslot));
			var cs = sp - stackslot;
			if (memory.getByte(sp - 2 * stackslot) != TArray) {
				throw "nativeMap expected array and closure, but got  " + memoryToString(sp - 2 * stackslot)
					  + " and " + memoryToString(sp - stackslot);
			}
			var len = I2i.toInt(memory.getI32(a));
			allocate(len * stackslot + 4);
			var a2 = hp;
			memory.setI32(a2, (len));
			for (i in 0...len) {
				// Copy value
				pushFromMemory(a + 4 + i * stackslot);
				pushFromMemory(cs);

				doCallInNative();

				// Copy result from mapped function into result array
				sp -= stackslot;
				memory.copy(sp, a2 + 4 + i * stackslot, stackslot);
			}
			// Hack return value into place
			sp = cs;
			memory.setI32(sp - stackslot + 4, (a2));
		} catch (e : Dynamic) {
			reportFailure('nativeMap exception', e);
		}
	}

	// input via data stack ( array closure --> void )
	private function nativeIteri() : Void {
		try {
			var a = I2i.toInt(memory.getI32(sp + 4 - 2 * stackslot));
			var cs = sp - stackslot;
			if (memory.getByte(sp - 2 * stackslot) != TArray) {
				throw "nativeIteri expected array and closure, but got  " + memoryToString(sp - 2 * stackslot)
					  + " and " + memoryToString(sp - stackslot);
			}
			var len = I2i.toInt(memory.getI32(a));
			for (i in 0...len) {
				pushint(i);
				// Copy value
				pushFromMemory(a + 4 + i * stackslot);
				pushFromMemory(cs);

				doCallInNative();

				sp -= stackslot;
			}
			// Return void
			sp = cs;
			memory.setByte(sp - stackslot, TVoid);
		} catch (e : Dynamic) {
			reportFailure('nativeIteri exception', e);
		}
	}

	// input via data stack ( array closure --> void )
	private function nativeIter() : Void {
		try {
			var a = I2i.toInt(memory.getI32(sp + 4 - 2 * stackslot));
			var cs = sp - stackslot;
			if (memory.getByte(sp - 2 * stackslot) != TArray) {
				throw "nativeIter expected array and closure, but got  " + memoryToString(sp - 2 * stackslot)
					  + " and " + memoryToString(sp - stackslot);
			}
			var len = I2i.toInt(memory.getI32(a));
			for (i in 0...len) {
				// Copy value
				pushFromMemory(a + 4 + i * stackslot);
				pushFromMemory(cs);
				doCallInNative();
				sp -= stackslot;
			}
			// Return void
			sp = cs;
			memory.setByte(sp - stackslot, TVoid);
		} catch (e : Dynamic) {
			reportFailure('nativeIter exception', e);
		}
	}

	// input via data stack ( array init closure --> value )
	// native fold : ([flow], init : flow, fn : (flow, flow)->flow) -> flow = Native.fold;
	private function nativeFold() : Void {
		try {
			var a = I2i.toInt(memory.getI32(sp + 4 - 3 * stackslot));
			var cs = sp - 1 * stackslot;
			if (memory.getByte(sp - 3 * stackslot) != TArray) {
				throw "nativeFold expected array, init and closure, but got  " + memoryToString(sp - 3 * stackslot)
					  + " and " + memoryToString(sp - stackslot);
			}
			// Copy initial value on the stack
			pushFromMemory(sp - 2 * stackslot);
			var len = I2i.toInt(memory.getI32(a));
			for (i in 0...len) {
				// Push array value
				pushFromMemory(a + 4 + i * stackslot);
				
				// Push the closure
				pushFromMemory(cs);

				doCallInNative();
			}
			// Hack return value into place
			memory.copy(sp - stackslot, sp - 4 * stackslot, stackslot);
			sp -= 3 * stackslot;
		} catch (e : Dynamic) {
			reportFailure('nativeFold exception', e);
		}
	}

	// input via data stack ( array --> int )
	// native length : ([flow]) -> int = Native.length;
	private function nativeLength() : Void {
		var a = I2i.toInt(memory.getI32(sp + 4 - stackslot));
		if (memory.getByte(sp - stackslot) != TArray) {
			throw "nativeLength expected array, but got  " + memoryToString(sp - stackslot);
		}
		sp -= stackslot;
		var len = I2i.toInt(memory.getI32(a));
		pushint(len);
	}

	private function nativeIsArray() : Void {
		if (memory.getByte(sp - stackslot) == TArray) {
			sp -= stackslot;
			pushbool(1);
		} else { 
			sp -= stackslot; 
			pushbool(0);
		}
	}	

	// input via data stack ( array int value --> array )
	// native replace : ([flow], int, flow) -> [flow] = Native.replace;
	private function nativeReplace() : Void {
		var a = I2i.toInt(memory.getI32(sp + 4 - 3 * stackslot));
		if (memory.getByte(sp - 3 * stackslot) != TArray) {
			throw "nativeReplace expected array, but got  " + memoryToString(sp - 3 * stackslot);
		}
		var i = I2i.toInt(memory.getI32(sp - 2 * stackslot + 4));
		var origlen = I2i.toInt(memory.getI32(a));
		var newlen = origlen;
		if (i >= origlen) {
			// We support extending the array with one element
			newlen = i + 1;
		}
		var origbytes = origlen * stackslot;
		var newbytes = newlen * stackslot;
		allocate(newbytes + 4);
		memory.setI32(hp, (newlen));
		// Copy the old array
		memory.copy(a + 4, hp + 4, origbytes);
		
		// Put the new value in place
		memory.copy(sp - stackslot, hp + 4 + i * stackslot, stackslot);

		// And splice the result into the stack
		sp -= 2 * stackslot;
		memory.setI32(sp - stackslot + 4, (hp));
	}

	private function nativeConcat() : Void {
		sp -= stackslot;
		if (memory.getByte(sp) != TArray || memory.getByte(sp - stackslot) != TArray) {
			throw "nativeConcat expected 2 arrays, but got  " + memoryToString(sp - stackslot) + " and " + memoryToString(sp);
		}
		var a1 = I2i.toInt(memory.getI32(sp - stackslot + 4));
		var a2 = I2i.toInt(memory.getI32(sp + 4));
		var len1 = I2i.toInt(memory.getI32(a1));
		var len2 = I2i.toInt(memory.getI32(a2));
		if (len1 == 0) {
			// Take array 2 as it is
			memory.copy(sp, sp - stackslot, stackslot);
		} else if (len2 == 0) {
			// Take array 1 as it is
		} else {
			var newlen = len1 + len2;
			allocate(newlen * stackslot + 4);
			memory.setI32(hp, (newlen));
			memory.copy(a1 + 4, hp + 4, len1 * stackslot);
			memory.copy(a2 + 4, hp + 4 + len1 * stackslot, len2 * stackslot);
			memory.setI32(sp - stackslot + 4, (hp));
		}
	}

	private function nativeStrlen() : Void {
		if (memory.getByte(sp - stackslot) != TString) {
			printCallstack();
			throw "nativeStrlen expected string, but got " + memoryToString(sp - stackslot);
		}
		var len = I2i.toInt(memory.getI32(sp + 8 - stackslot));
		sp -= stackslot;
		pushint(len);
	}

	private function nativeSubstring() : Void {
		if (memory.getByte(sp - 3 * stackslot) != TString) {
			throw "nativeSubstring expected string, but got  " + memoryToString(sp - 3 * stackslot);
		}
		if (memory.getByte(sp - 2 * stackslot) != TInt) {
			throw "nativeSubstring expected int as second paramter, but got  " + memoryToString(sp - 2 * stackslot);
		}
		if (memory.getByte(sp - stackslot) != TInt) {
			throw "nativeSubstring expected int as third paramter, but got  " + memoryToString(sp - stackslot);
		}
		var s = I2i.toInt(memory.getI32(sp + 4 - 3 * stackslot));
		var slen = I2i.toInt(memory.getI32(sp + 8 - 3 * stackslot));
		var start = I2i.toInt(memory.getI32(sp + 4 - 2 * stackslot));
		var len = I2i.toInt(memory.getI32(sp + 4 - stackslot));
		sp -= 2 * stackslot;
		var newlen = Math.floor(Math.min(slen - start, len));
		if (newlen <= 0) {
			// Empty strings: We reset the pointer and length to 0! Otherwise, pointer comparison might break
			memory.setI32(sp - stackslot + 4, (0));
			memory.setI32(sp - stackslot + 8, (0));
		} else {
			// We reuse memory, and just point into the string!
			memory.setI32(sp - stackslot + 4, (s + start));
			memory.setI32(sp - stackslot + 8, (newlen));
		}
	}
	
	private function nativeStrIndexOf() : Void {
		if (memory.getByte(sp - 2 * stackslot) != TString) {
			throw "nativeStrIndexOf expected string, but got  " + memoryToString(sp - 2 * stackslot);
		}
		if (memory.getByte(sp - stackslot) != TString) {
			throw "nativeStrIndexOf expected string as second paramter, but got  " + memoryToString(sp - stackslot);
		}

		var s = I2i.toInt(memory.getI32(sp + 4 - 2 * stackslot));
		var slen = I2i.toInt(memory.getI32(sp + 8 - 2 * stackslot));

		var p = I2i.toInt(memory.getI32(sp + 4 - stackslot));
		var plen = I2i.toInt(memory.getI32(sp + 8 - stackslot));
		
		sp -= stackslot;
		memory.setByte(sp - stackslot, TInt);
		
		if (plen == 0) {
			memory.setI32(sp - stackslot + 4, (0));
			return;
		}
		
		if (plen > slen) {
			memory.setI32(sp - stackslot + 4, (-1));
			return;
		}
		
		// TODO: We can do Boyer-Moore or something fancy here
		for (i in 0...slen) {
			if (memory.getByte(s + i) == memory.getByte(p)) {
				var found = true;
				for (j in 1...plen) {
					if (memory.getByte(s + i + j) != memory.getByte(p + j)) {
						found = false;
						break;
					}
				}
				if (found) {
					memory.setI32(sp - stackslot + 4, (i));
					return;
				}
			}
		}
		memory.setI32(sp - stackslot + 4, ( -1));
	}

	private function nativeGetCharCodeAt() : Void {
		// TODO: Change this to return a UTF-32/UCS-4 number instead of a UTF-8 based value
		if (memory.getByte(sp - 2 * stackslot) != TString) {
			throw "nativeGetCharCodeAt expected string, but got  " + memoryToString(sp - 2 * stackslot);
		}
		if (memory.getByte(sp - stackslot) != TInt) {
			throw "nativeGetCharCodeAt expected int as second paramter, but got  " + memoryToString(sp - stackslot);
		}

		var s = I2i.toInt(memory.getI32(sp + 4 - 2 * stackslot));
		var slen = I2i.toInt(memory.getI32(sp + 8 - 2 * stackslot));

		var i = I2i.toInt(memory.getI32(sp + 4 - stackslot));
		
		sp -= stackslot;
		memory.setByte(sp - stackslot, TInt);
		if (0 <= i && i < slen) {
			memory.setI32(sp - stackslot + 4, (memory.getByte(s + i)));
		} else {
			memory.setI32(sp - stackslot + 4, (0));
		}
	}

	private function nativeList2string() : Void {
		sp -= stackslot;
		if (memory.getByte(sp) != TStruct) {
			throw "nativeList2string expected a struct, but got  " + memoryToString(sp);
		}
		
		// First, collect the strings to combine and calculate the total length
		var strings = new FlowArray();
		var length = 0;
		var cursor = sp;
		while (true) {
			var args = I2i.toInt(memory.getI32(cursor + 4));
			var kind = I2i.toInt(memory.getI32(cursor + 8));
			if (structDefs[kind][0] == "EmptyList") {
				break;
			} else if (structDefs[kind][0] == "Cons") {
				strings.unshift(args);
				var strlen = I2i.toInt(memory.getI32(args + 8));
				length += strlen;
				cursor = args + stackslot;
			} else {
				throw "nativeList2string expected a List struct, but got  " + memoryToString(sp);
			}
		}
		
		// Prepare the resulting string value
		memory.setByte(sp, TString);
		allocate(length);
		var resultstring = hp;
		memory.setI32(sp + 4, (resultstring));
		memory.setI32(sp + 8, (length));
		
		// Then copy the strings together
		for (a in strings) {
			var sa = I2i.toInt(memory.getI32(a + 4));
			var sl = I2i.toInt(memory.getI32(a + 8));
			memory.copy(sa, resultstring, sl);
			resultstring += sl;
		}
		
		sp += stackslot;
	}
	
	private function nativeList2array() : Void {
		sp -= stackslot;
		if (memory.getByte(sp) != TStruct) {
			throw "nativeList2array expected a struct, but got  " + memoryToString(sp);
		}
		
		// First, collect the values to combine and calculate the total length
		var values = new FlowArray();
		var cursor = sp;
		while (true) {
			var args = I2i.toInt(memory.getI32(cursor + 4));
			var kind = I2i.toInt(memory.getI32(cursor + 8));
			if (structDefs[kind][0] == "EmptyList") {
				break;
			} else if (structDefs[kind][0] == "Cons") {
				values.unshift(args);
				cursor = args + stackslot;
			} else {
				throw "nativeList2array expected a List struct, but got  " + memoryToString(sp);
			}
		}
		var length = values.length;
		// Prepare the resulting string value
		memory.setByte(sp, TArray);
		allocate(4 + length * stackslot);
		var resultarray = hp;
		memory.setI32(sp + 4, (resultarray));
		memory.setI32(resultarray, (length));
		resultarray += 4;
		
		// Then make the final array
		for (a in values) {
			memory.copy(a, resultarray, stackslot);
			resultarray += stackslot;
		}
		
		sp += stackslot;
	}
	
	#if flash
	private function renderSupportSetTextAndStyle() : Void {
		sp -= 9 * stackslot;
		
		var textfield : flash.text.TextField = nativeValues.get(I2i.toInt(memory.getI32(sp + 4)));
		var textlen = I2i.toInt(memory.getI32(sp + 1 * stackslot + 8));
		var text : String = memory.getString(I2i.toInt(memory.getI32(sp + 1 * stackslot + 4)), textlen);
		/* Other style properties to consider:
		FontStyle
		FontVariant
		FontWeight*/
		var fontfamilylen = I2i.toInt(memory.getI32(sp + 2 * stackslot + 8));
		var fontfamily = memory.getString(I2i.toInt(memory.getI32(sp + 2 * stackslot + 4)), fontfamilylen);
		var fontsize = memory.getDouble(sp + 3 * stackslot + 4);
		var fillcolour = I2i.toInt(memory.getI32(sp + 4 * stackslot + 4));
		var fillopacity = memory.getDouble(sp + 5 * stackslot + 4);
		
		var letterspacing = I2i.toInt(memory.getI32(sp + 6 * stackslot + 4));
		var letterspacingParameter : String = "";

		var backgroundcolour = I2i.toInt(memory.getI32(sp + 7 * stackslot + 4));
		var backgroundopacity = memory.getDouble(sp + 8 * stackslot + 4);

		// Special flash names for fonts
		if (fontfamily == "sans-serif") {
			fontfamily = "_sans";
		}
		// Special cases for a few universal fonts, which are not embedded
		if (fontfamily != "_sans" && fontfamily != "Courier") {
			textfield.embedFonts = true;
		}
		textfield.textColor = fillcolour;
		if (fillopacity != 1.0) {
			textfield.alpha = fillopacity;
		}
		if (letterspacing != 0) {
			letterspacingParameter = ' letterspacing="' + letterspacing + '"';
		}
		if (backgroundopacity != 0.0) {
			textfield.backgroundColor = backgroundcolour;
			textfield.background = true;
		}
		
		if (text == "") {  // trick for initialization by empty string:
			var html = '<font face="' + fontfamily + '" size="' + fontsize + '"' + letterspacingParameter + '>' + ' ' + '</font>';
			textfield.htmlText = html;
			textfield.setSelection(textfield.length, textfield.length);
			textfield.text = "";
		}
		else {
			var html = '<font face="' + fontfamily + '" size="' + fontsize + '"' + letterspacingParameter + '>' + text + '</font>';
			if (textfield.htmlText != html) { textfield.htmlText = html; }
		}

		sp += stackslot;
	}		
	#end
	
	#if flash
	private function renderSupportSetAdvancedText() : Void {
		sp -= 4 * stackslot;
		
		var textfield : flash.text.TextField = nativeValues.get(I2i.toInt(memory.getI32(sp + 4)));
		var sharpness = I2i.toInt(memory.getI32(sp + 1 * stackslot + 4));
		var antialiastype = I2i.toInt(memory.getI32(sp + 2 * stackslot + 4));
		var gridfittype = I2i.toInt(memory.getI32(sp + 3 * stackslot + 4));

		textfield.sharpness = sharpness;
		
		if (antialiastype == 0)
			textfield.antiAliasType = flash.text.AntiAliasType.NORMAL;
		else if (antialiastype == 1)
			textfield.antiAliasType = flash.text.AntiAliasType.ADVANCED;
			
		if (gridfittype == 0)
			textfield.gridFitType = flash.text.GridFitType.NONE;
		else if (gridfittype == 1)
			textfield.gridFitType = flash.text.GridFitType.PIXEL;
		else if (gridfittype == 2)
			textfield.gridFitType = flash.text.GridFitType.SUBPIXEL;

		sp += stackslot;
	}		
	#end	

	// Call the closure on the stack - for use in native implementations only
	function doCallInNative() {
		// Exit this function by forcing run() to execute a CLast.  CLast is the last
		// instruction in the code segment
		try {
			callStackPush(code.getPosition());
			code.setPosition(code.size - 1);
			doCall();
			try {
				run();
			} catch (e2 : Dynamic) {
				if (!hasFailed) {
					trace("Exception when running native nested call: " + e2 + " " + code.getPosition());
					printCallstack();
					hasFailed = true;
				}
			}
			code.setPosition(callStackPop());
		} catch (e : Dynamic) {
			reportFailure("Native nested call: " + code.getPosition(), e);
			throw e;
		}
	}
	
	//
	// Interfacing with the normal haXe native implementation
	//
	
	public function popflow() : Flow {
		sp -= stackslot;
		return memoryToFlow(sp);
	}
	
	function memoryToFlow(add : Int) : Flow {
		var t = memory.getByte(add);
		var p = { l:0, f:"", s:-1, e:-1, type: null, type2: null };
		if (t == TVoid) {
			return ConstantVoid(p);
		} else if (t == TBool) {
			return ConstantBool(memory.getByte(add + 4) == 1, p);
		} else if (t == TInt) {
			return ConstantI32(memory.getI32(add + 4), p);
		} else if (t == TDouble) {
			return ConstantDouble(memory.getDouble(add + 4), p);
		} else if (t == TString) {
			var a = I2i.toInt(memory.getI32(add + 4));
			var l = I2i.toInt(memory.getI32(add + 8));
			return ConstantString(memory.getString(a, l), p);
		} else if (t == TNative) {
			var n = I2i.toInt(memory.getI32(add + 4));
			return ConstantNative(nativeValues.get(n), p);
		} else if (t == TArray) {
			var arrayAddr = I2i.toInt(memory.getI32(add + 4));
			var length = I2i.toInt(memory.getI32(arrayAddr));
			var a = new FlowArray();
			for (i in 0...length) {
				a.push(memoryToFlow(arrayAddr + 4 + i * stackslot));
			}
			return ConstantArray(a, p);
		} else if (t == TCodePointer) {
			return StackSlot(memory.getI32(add), memory.getI32(add + 4), memory.getI32(add + 8));
		} else if (t == TClosurePointer) {
			return StackSlot(memory.getI32(add), memory.getI32(add + 4), memory.getI32(add + 8));
		} else if (t == TNativeFn) {
			return StackSlot(memory.getI32(add), memory.getI32(add + 4), memory.getI32(add + 8));
		} else if (t == TStruct) {
			return StackSlot(memory.getI32(add), memory.getI32(add + 4), memory.getI32(add + 8));
		} else if (t == TRefTo) {
			return StackSlot(memory.getI32(add), memory.getI32(add + 4), memory.getI32(add + 8));
		} else {
			throw "Can not make flow. Not supported yet: 0x" + StringTools.hex(t, 2);
		}
		return null;
	}
	
	public function pushflow(v : Flow) : Void {
		if (v == null) throw "Can not push null";
		switch (v) {
		case ConstantVoid(pos): 
			push(TVoid, 0);
		case ConstantBool(value, pos):
			pushbool(value ? 1 : 0);
		case ConstantI32(value, pos):
			pushi32(value);
		case ConstantDouble(value, pos):
			memory.setByte(sp, TDouble);
			memory.setDouble(sp + 4, value);
			sp += stackslot;
		case ConstantString(s, pos):
			pushstring(s);
		case ConstantNative(value, pos):
			var n = nativeValueSerial;
			nativeValues.set(n, value);
			nativeValueSerial++;
			memory.setByte(sp, TNative);
			memory.setI32(sp + 4, (n));
			sp += stackslot;
		case ConstantArray(values, pos):
			for (v in values) {
				pushflow(v);
			}
			var length = values.length;
			var bytes = length * stackslot;
			allocate(bytes + 4);
			memory.setI32(hp, (length));
			memory.copy(sp - bytes, hp + 4, bytes);
			sp -= bytes;
			push(TArray, hp);
		case NativeClosure(nargs, fn, pos):
			var nativeFn = function() {
				var args = new FlowArray();
				for (i in 0...nargs) {
					args.unshift(popflow());
				}
				var r = fn(args, pos);
				pushflow(r);
			}
			var id = natives.length;
			natives[id] = nativeFn;
			push(TNativeFn, id);
		case ConstantStruct(n, values, p):
			// This only happens if native methods produce Flow ASTs. But we are clever enough
			// to know how to convert that stuff to the bytecode representation.
			var i = 0;
			var found = false;
			for (sf in structDefs) {
				if (sf[0] == n) {
					found = true;
					break;
				}
				++i;
			}
			if (!found) {
				throw "Can not make this struct: " + Prettyprint.prettyprint(v) + "\nBe sure that this struct is defined in shape, or whatever host is running";
			}
			if (structDefs[i].length - 1 != cast(values.length)) {
				throw "Can not make this struct: " + Prettyprint.prettyprint(v) + "\nThe number of arguments is wrong";
			}
			for (v in values) {
				pushflow(v);
			}
			// Now make a struct out of all of this
			var length = values.length;
			if (length > 0) {
				var bytes = length * stackslot;
				allocate(bytes);
				sp -= bytes;
				memory.copy(sp, hp, bytes);
				push(TStruct, hp);
			} else {
				push(TStruct, 0);
			}
			memory.setI32(sp - stackslot + 8, (i));
		case StackSlot(q0, q1, q2):
			memory.setI32(sp, q0);
			memory.setI32(sp + 4, q1);
			memory.setI32(sp + 8, q2);
			sp += stackslot;
		default: throw "Not supported yet: " + v;
		}
	}
	
	// Code stack operations
	function callStackPush(a : Int) : Void {
		memory.setI32(cp, (a));
		cp += 4;
		if (cp >= csp) {
			throw "Callstack full!";
		}
	}
	function callStackPop() : Int {
		cp -= 4;
		return I2i.toInt(memory.getI32(cp));
	}
	
	function closureStackPush(a : Int) : Void {
		csp -= 4;
		if (csp < cp) {
			throw "Closurestack full!";
		}
		memory.setI32(csp, (a));
	}
	
	function closureStackPop() : Int {
		var a = I2i.toInt(memory.getI32(csp));
		csp += 4;
		return a;
	}
	
	
	// Data stack operations
	function push(c : Int, value : Int) {
		memory.setByte(sp, c);
		memory.setI32(sp + 4, (value));
		sp += stackslot;
	}
	
	inline function pushFromMemory(a : Int) {
		memory.copy(a, sp, stackslot);
		sp += stackslot;
	}
	
	inline function pushbool(i : Int) {
		push(TBool, i);
	}
	inline function pushint(i : Int) {
		push(TInt, i);
	}
	inline function pushi32(i : I32) {
		memory.setByte(sp, TInt);
		memory.setI32(sp + 4, i);
		sp += stackslot;
	}
	function pushstring(s : String) {
		var l = s.length;
		// Allocate on the heap
		allocate(l);
		// And copy the bytes there
		for (i in 0...l) {
			var a = hp + i;
			var b = s.charCodeAt(i);
			memory.setByte(a, b);
		}
		push(TString, hp);
		memory.setI32(sp - stackslot + 8, (l));
	}
	
	public function dumpstack() {
		print("Stack");
		
		var n = 5;
		var depth = Math.floor((sp - dataStackStart) / stackslot);
		for (s in Math.round(Math.max(0, depth - n))...depth) {
			var i = stackslot * s + dataStackStart;
			var v = memoryToString(i);
			if (i == framepointer) {
				print('fp-> ' + StringTools.hex(s) + ':' + v);
				
			} else {
				print('     ' + StringTools.hex(s) + ':' + v);
			}
		}
		//dumpframepointer();
		//dumpheap();
	}

	// Debugging

	static function opcode2string(c) {
		try {
			return "0x" + StringTools.hex(c, 2) + " " + BytecodeUtil.opname(c);
		} catch (Ex : Dynamic) {
			return "<could not print this opcode>";
		}
	}

	public function memoryToString(i : Int) : String {
		var origin = function(a : Int) : String {
			var o = memoryToCode.get(a);
			if (o != null) {
				return " (allocated by " + addressToFunction(o) + ")";
			}
			return "";
		}
		if (i < code.size) {
			return origin(i);
		}
		var t = memory.getByte(i);

		var r;
		try {
			r = switch (t) {
			case TVoid: "{}";
			case TBool: I2i.toInt(memory.getI32(i + 4)) == 0 ? "false" : "true";
			case TInt: { '' + memory.getI32(i + 4); }
			case TDouble: {
				var d = memory.getDouble(i + 4);
				var s = Std.string(d);
				if (s.indexOf(".") == -1) {
					s += ".0";
				}
				s;
			}
			case TString: {
				var a = I2i.toInt(memory.getI32(i + 4));
				var l = I2i.toInt(memory.getI32(i + 8));
				var r = "\"";
				// TODO: Consider to use memory.readString and then escape that instead.
				for (i in 0...l) {
					var c = Util.fromCharCode(memory.getByte(a + i));
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
				r + "\"";
			}
			case TArray: {
				var a = I2i.toInt(memory.getI32(i + 4));
				var l = I2i.toInt(memory.getI32(a));
				var r = origin(a) + "[";
				var sep = "";
				var wrap = 75;
				for (i in 0...l) {
					r += sep + memoryToString(a + 4 + i * stackslot);
					sep = ", ";
					if (r.length > wrap) {
						sep = ",\n";
						wrap = r.length + 75;
					}
				}
				r + "]";
			}
			case TStruct: {
				var a = I2i.toInt(memory.getI32(i + 4));
				var k = I2i.toInt(memory.getI32(i + 8));
				var l = structDefs[k].length - 1;
				
				var r = origin(a)
					+ structDefs[k][0]
					+ "(";
				var sep = "";
				for (i in 0...l) {
					r += sep + memoryToString(a + i * stackslot);
					sep = ", ";
				}
				r + ")";
			}
			case TCodePointer: "<" + addressToFunction(I2i.toInt(memory.getI32(i + 4))) + ">";
			case TRefTo: {
				// We could consider spitting out the serial here...
				var a = I2i.toInt(memory.getI32(i + 4));
				"ref " + memoryToString(a);
			};
			case TNative: {
				var id = I2i.toInt(memory.getI32(i + 4));
				"<native value " + StringTools.hex(id, 4) + " " + nativeValues.get(id) + ">";
			}
			case TNativeFn: {
				var id = I2i.toInt(memory.getI32(i + 4));
				"<native fn " + id + " " + natives[id] + ">";
			}
			case TClosurePointer: {
				var r = "<" + addressToFunction(I2i.toInt(memory.getI32(i + 8))) + " with closure ";
				var a = I2i.toInt(memory.getI32(i + 4)) ;
				r += origin(a);
				var l = I2i.toInt(memory.getI32(a));
				if (l < 1000) {
					var sep = "[";
					for (i in 0...l) {
						r += sep + StringTools.hex(memory.getByte(a + 4 + i * stackslot), 2);
						sep = ", ";
					}
					r += "]";
				}
				r + ">";
			}
			default: "Unknown: " + StringTools.hex(t, 2);
			} 
		} catch (e : Dynamic) {
			r = "could not make string for this value: " + e + "";
		}
		return r;
	}

	function dumpframepointer() {
		print("    Frame pointer: " + StringTools.hex(Math.floor((framepointer - dataStackStart) / stackslot))
			+ " Call stack pointer: " + StringTools.hex(cp)
			+ " Stack pointer: " + StringTools.hex(sp)
			+ " Closure stack pointer: " + StringTools.hex(csp)
			+ " Closure pointer: " + StringTools.hex(closurepointer)
			+ " Heap pointer: " + StringTools.hex(hp));

		var r = "";
		var closureStackDepth = Math.floor((BytecodeRunner.dataStackStart - csp) / 4);
		var sep = "";
		for (i in 0...closureStackDepth) {
			var a = csp + i * 4;
			r += sep + StringTools.hex(I2i.toInt(memory.getI32(a)), 4);
			sep = ", ";
		}
		print(r);
	}
	
	function dumpheap() {
		print("Heap:");
		var limits = heapLimits(highHeap);
		var i = hp;
		while (i < limits.start) {
			var s = StringTools.hex(i, 4) + ":";
			for (j in 0...16) {
				if (i + j >= heapEnd) {
					break;
				}
				s += " " + StringTools.hex(memory.getByte(i + j), 2);
			}
			i += 16;
			print(s);
		}
	}
	
	// Simple stuff
	inline function readString() : String {
		var l = code.readInt31();
		return code.readString(l);
	}
	
	// Heap management
	function allocate(bytes : Int) : Void {
		hp -= bytes;
		if (sp > heapStart) {
			throw "Data stack full!";
		}
		if (hp < hpbound) {
			reportFailure('Heap exhausted', null);
			throw 'Heap exhausted';
		}
		checkGc();
		
		#if profilememory
		// Top-entry on the stack
		var pos = code.getPosition();
		// To take from further up in the stack, do this
		// var pos = I2i.toInt(memory.getI32(cp - 8));
		
		var usage = memoryUsage.get(pos);
		if (usage == null) {
			usage = 0;
		}
		usage += bytes;
		
		memoryUsage.set(pos, usage);
		#end
		// TODO: If we want to do memory profiling, we can record the pc, and/or callstack here
		// memoryToCode.set(hp, code.getPosition());
		// memoryExtent.set(hp, bytes);
	}
	public var memoryToCode: Map<Int,Int>;
	public var memoryExtent : Map<Int,Int>;
	// From code position to number of bytes allocated
	public var memoryUsage : Map<Int,Int>;
	
	public static function heapLimits(high : Bool) : { start : Int, limit : Int, bound : Int } {
		var middle = Math.floor(heapStart + 0.5 * heapSize);
		var start = (high ? heapEnd : middle);
		return {start: start,
				limit: start - Math.floor(0.35 * heapSize),
				bound: (high ? middle : heapStart) };
	}

	inline function checkGc() {
		#if !sys
		if (gcTimer == null && hp < hplimit) {
			gc();
		}
		#end
	}

	public function gc() {
		#if !sys
		if (gcTimer == null) {
			gcTimer = new haxe.Timer(1);
			gcTimer.run = forceGC;
		}
		#end
	}
	
	#if ! sys
	var gcTimer : haxe.Timer;
	#end
	
	public function forceGC() {
		#if ! sys
		gcTimer.stop();
		gcTimer = null;
		#end

		#if profilememory
		dumpMemoryUsage();
		#end
		
		//trace("GC");
		if (hasFailed)
			return;
		var limits = heapLimits(highHeap);
		var useBefore = limits.start - hp;
		if (useBefore > 0) {

			try {
				var gc = new GarbageCollector(this, memory, csp, closurepointer, highHeap, nativeRoots);
				closurepointer = gc.closurepointer;
				hp = gc.hp;
				highHeap = !highHeap;
				var heap = heapLimits(highHeap);
				hplimit = heap.limit;
				hpbound = heap.bound;
				#if profilememory
				print("Use before: " + StringTools.hex(useBefore, 4) + " and now " + StringTools.hex(heap.start - hp, 4));
				#end
			} catch (e : Dynamic) {
				reportFailure('GC failed', e);
				return;
			}
			
			if (hp < hplimit) {
				// OK, we already need a new collection after compaction, so we have to get more memory
				if (highHeap) {
					// Shit! We are in the wrong end. OK, a hack to fix this: Just GC again, and we will go into the correct case
					forceGC();
				} else {
					// Now resize the heap to double size
					// trace("Doubling memory to " + StringTools.hex(heapSize, 4));
					heapSize *= 2;
					heapEnd = heapStart + heapSize;
					memory.resize(heapEnd);
					var heap = heapLimits(highHeap);
					hplimit = heap.limit;
					hpbound = heap.bound;
				}
			}
			
		}
	}

	function dumpMemoryUsage() {
		new MemoryProfiler(memoryUsage, addressToFunction);
		// Clear it out again
		memoryUsage = new Map<Int,Int>();
	}

	public function registerRoot(c : Flow) : Int {
		var n = nNativeRoots;
		nativeRoots.set(n, c);
		nNativeRoots++;
		return n;
	}
	public function lookupRoot(i : Int) : Flow {
		return nativeRoots.get(i);
	}
	
	public function releaseRoot(i : Int) : Void {
		nativeRoots.remove(i);
	}
	var nativeRoots : Map<Int,Flow>;
	var nNativeRoots : Int;
	var linecount : Int;
	
	function print(s : String) {
		if (linecount < 40) {
			linecount++;
			if (s.length > 100) {
				s = s.substr(0, 99);
			}
			#if (flash || js)
				//trace(s);
			#else
				Sys.println(s);
			#end
		}
		#if flash
			try {
				flash.external.ExternalInterface.call("console.log", s);
			} catch (e : Dynamic) {
				trace(s);
			}
		#end
	}

	var hasFailed : Bool;
	
	// The bytecode we run
	var code : CodeMemory;
	// The memory used at run time
	var memory : ByteMemory;
	// Call stack pointer.
	var cp : Int;
	// Stack of closure
	var csp : Int;
	// Stack pointer.
	public var sp : Int;
	// The current call frame
	var framepointer : Int;
	
	// Heap pointer. Points to last used address. The heap grows from end of memory down
	var hp : Int;
	
	// When to trigger a garbage collection
	var hplimit : Int;
	var hpbound : Int; // a hard bound
	
	// Which part of the memory is the current heap? Half the memory is reserved for garbage collection, so we track which
	// half is active here. If high is true, memory grows from the end down
	var highHeap : Bool;
	
	// The current closure pointer
	var closurepointer : Int;
	
	// Code-address of all top-level functions
	var toplevel : Map<String,Int>;

	// The native codes
	var natives : FlowArray<Void -> Void>;
	
	// Each reference gets a serial number to allow stable comparisons
	var refSerial : I32;
	
	#if profilecalls
	var nativeid2name : FlowArray<String>;
	#end

	// The native values we get are kept here
	public var nativeValues : Map<Int,Dynamic>;
	var nativeValueSerial : Int;

	public var structDefs : FlowArray< FlowArray<String> >;
	
	
	// The overall memory layout
	static var callStackStart = 0x0;
	static public var dataStackStart = 0x0;
	static public var heapStart = 0x0;
	static public var heapEnd = 0x0;

	// How much memory to use
	static public inline var callStackSize = 0x4000;
	static public inline var dataStackSize = 0x100000;
	#if sys
		static public var heapSize = 0x8000000;
	#elseif flash
		static public var heapSize = 0x8000000;
	#elseif js
		static public var heapSize = 0x0400000;
	#end
	
	var debugInfo : DebugInfo;
	var debugFnInfo : FlowArray< { pc : Int, fn : String, slot : Int }>;
	
	// The size in bytes of each slot in the stack
	#if sys
	// Since we represent memory as doubles anyways, we do not need any padding for alignment in the neko target
	static public inline var stackslot = 12;
	#else
	// For flash, however, 64 bit machines require 8 byte alignment, so we round up!
	// On a 32-bit machine, we might go for 12 as a good value. Experiments needs to confirm what is best.
	static public inline var stackslot = 12;
	#end

	public var runcount : Int;
}
