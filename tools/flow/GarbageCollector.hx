import ByteMemory;

class GarbageCollector {
	public function new(runner : BytecodeRunner, memory : ByteMemory, csp : Int, closurepointer : Int, currentIsHigh : Bool, roots : Map<Int,Flow>) {
		this.runner = runner;
		this.memory = memory;
		this.closurepointer = closurepointer;
		
		#if profilememory
		memoryProfile = new Map();
		#end

		var limits = BytecodeRunner.heapLimits(!currentIsHigh);
		hp = limits.start;
		
		if (currentIsHigh) {
			oldLimits = { 
				start : BytecodeRunner.heapStart + Math.floor(BytecodeRunner.heapSize / 2),
				end : BytecodeRunner.heapEnd
			};
			newLimits = {
				start : BytecodeRunner.heapStart,
				end : BytecodeRunner.heapStart + Math.floor(BytecodeRunner.heapSize / 2)
			};
		} else {
			newLimits = { 
				start : BytecodeRunner.heapStart + Math.floor(BytecodeRunner.heapSize / 2),
				end : BytecodeRunner.heapEnd
			};
			oldLimits = {
				start : BytecodeRunner.heapStart,
				end : BytecodeRunner.heapStart + Math.floor(BytecodeRunner.heapSize / 2)
			};
		}

		addressMap = new Map();
		// The zero pointer is special and does not change
		addressMap.set(0, 0);
		stringSizeMap = new Map();
		nativeValuesAlive = new Map();
		nativeFunctionsAlive = new Map();

		var rootNumbers = new FlowArray();
		for (i in roots.keys()) {
			var f = roots.get(i);
			rootNumbers.unshift(i);
			runner.pushflow(f);
//			trace(i + ":" + runner.memoryToString(runner.sp - BytecodeRunner.stackslot) + " " + f);
		}
		gcStack();
		
		if (closurepointer != 0) {
			this.closurepointer = collectArray(closurepointer - 4) + 4;
		} else {
			this.closurepointer = 0;
		}
		
		// Collect closures on the closure stack
		var closureStackDepth = Math.floor((BytecodeRunner.dataStackStart - csp) / 4);
		for (i in 0...closureStackDepth) {
			var sa = csp + i * 4;
			var a = I2i.toInt(memory.getI32(sa) );
			if (a != 0) {
				var p = collectArray(a - 4) + 4;
				memory.setI32(sa, (p));
			}
		}
		
		// And now, patch back the native roots again with the updated pointers!
		for (i in rootNumbers) {
//			trace(i + ":" + runner.memoryToString(runner.sp  - BytecodeRunner.stackslot));
			var f = runner.popflow();
			roots.remove(i);
			roots.set(i, f);
		}
		
		if (false) {
			// For debugging, it can be useful to clear out the old memory
			for (i in oldLimits.start...oldLimits.end) {
				memory.setByte(i, 0xff);
			}
		}

		// Now, clear out the unused native values
		for (i in runner.nativeValues.keys()) {
			if (!nativeValuesAlive.exists(i)) {
				runner.nativeValues.remove(i);
			}
		}
		#if profilememory
		dumpMemoryUsageProfile();
		#end
	}
	
	function limitAsString(t) {
		return StringTools.hex(t.start, 5) + " - " + StringTools.hex(t.end, 5);
	}
	
	function gcStack() { 
		var sp = runner.sp;
		var depth = Math.floor((sp - BytecodeRunner.dataStackStart) / BytecodeRunner.stackslot);
		for (i in 0...depth) {
			var s = BytecodeRunner.dataStackStart + i * BytecodeRunner.stackslot;
			// trace(runner.memoryToString(s));
			collect(s, s);
		}
	}

	function heapPtr(i) : Bool {
		return i >= BytecodeRunner.heapStart;
	}
	
	// Copy a value (always stackslot size)
	function collect(i : Int, target : Int) {
		if (false) {
			if (heapPtr(i)) {
				if (!(oldLimits.start <= i && i < oldLimits.end)) {
					throw "Old pointer pointing to new heap!";
				}
			}
			if (heapPtr(target)) {
				if (!(newLimits.start <= target && target < newLimits.end)) {
					throw "New pointer pointing to old heap!";
				}
				if (target < hp) {
					throw "Target is above the heap!";
				}
			}
		}
		copy(i, target, BytecodeRunner.stackslot);
		var t = memory.getByte(i);
		switch (t) {
		case BytecodeRunner.TVoid:
		case BytecodeRunner.TBool:
		case BytecodeRunner.TInt:
		case BytecodeRunner.TDouble:
		case BytecodeRunner.TString: {
			var a = I2i.toInt(memory.getI32(i + 4));
			if (a < BytecodeRunner.heapStart) {
				// It is a pointer to code, so it is fine.
			} else {
				var l = I2i.toInt(memory.getI32(i + 8));
				// Empty string: prevent allocating 0-byte buffers
				if (l == 0) {
					memory.setI32(target + 4, (0));
					return;
				}
				// Lookup in the address cache
				var na = addressMap.get(a);
				if (na != null) {
					var ssz = stringSizeMap.get(na);
					// If this really points to a string of appropriate size
					if (ssz != null && ssz >= l) {
						// Update to the new address
						memory.setI32(target + 4, (na));
						return;
					}
				}
				// Copy the string:
				{
					#if profilememory
					recordMemoryUsage("string", l);
					#end
					allocate(l, a);
					copy(a, hp, l);
					stringSizeMap.set(hp, l);
					addressMap.set(a, hp);
					memory.setI32(target + 4, (hp));
				}
			}
		}
		case BytecodeRunner.TArray: {
			var a = I2i.toInt(memory.getI32(i + 4));
			memory.setI32(target + 4, (collectArray(a)));

			#if profilememory
			var l = I2i.toInt(memory.getI32(a));
			recordMemoryUsage("array", l * BytecodeRunner.stackslot + 4);
			#end
		}
		case BytecodeRunner.TStruct: {
			var a = I2i.toInt(memory.getI32(i + 4));
			var k = I2i.toInt(memory.getI32(i + 8));
			var l = runner.structDefs[k].length - 1;
			memory.setI32(target + 4, (collectStruct(a, l)));

			#if profilememory
			recordMemoryUsage("struct" /*+ l*/, l * BytecodeRunner.stackslot);
			#end
		}
		case BytecodeRunner.TCodePointer: 
		case BytecodeRunner.TRefTo: 
			var a = I2i.toInt(memory.getI32(i + 4));
			var na = addressMap.get(a);
			if (na != null) {
				// Update to the new address
				memory.setI32(target + 4, (na));
			} else {
				allocate(BytecodeRunner.stackslot, i);
				var na = hp;
				addressMap.set(a, na);
				memory.setI32(target + 4, (na));
				collect(a, na);

				#if profilememory
				recordMemoryUsage("reference", BytecodeRunner.stackslot);
				#end
			}
		case BytecodeRunner.TNative: {
			var id = I2i.toInt(memory.getI32(i + 4));
			nativeValuesAlive.set(id, 1);
		}
		case BytecodeRunner.TNativeFn: {
			var id = I2i.toInt(memory.getI32(i + 4));
			nativeFunctionsAlive.set(id, 1);
		}
		case BytecodeRunner.TClosurePointer: 
			var a = I2i.toInt(memory.getI32(i + 4));
			var na = collectArray(a);
			memory.setI32(target + 4, (na));

			#if profilememory
			if (a != na) {
				var l = I2i.toInt(memory.getI32(a));
				recordMemoryUsage("closure", l * BytecodeRunner.stackslot + 4);
			}
			#end
		default: 
			throw "Can not collect unknown: " + StringTools.hex(t, 2) + " at " + i;
		}
	}

	function collectArray(a : Int) : Int {
		var na = addressMap.get(a);
		if (na != null) {
			// Update to the new address
			return na;
		} else {
			var l = I2i.toInt(memory.getI32(a));
			allocate(l * BytecodeRunner.stackslot + 4, a);
			var na = hp;
			memory.setI32(na, (l));
			addressMap.set(a, na);
			for (i in 0...l) {
				var o = 4 + i * BytecodeRunner.stackslot;
				collect(a + o, na + o);
			}
			return na;
		}
	}

	function collectStruct(a : Int, l : Int) : Int {	
		if (l == 0) {
			return 0;
		}
		var na = addressMap.get(a);
		if (na != null) {
			// Update to the new address
			return na;
		} else {
			allocate(l * BytecodeRunner.stackslot, a);
			var na = hp;
			addressMap.set(a, na);
			for (i in 0...l) {
				var o = i * BytecodeRunner.stackslot;
				collect(a + o, na + o);
			}
			return na;
		}
	}
	
	
	
	inline function copy(from : Int, to : Int, bytes : Int) {
		memory.copy(from, to, bytes);
	}
	inline function allocate(bytes : Int, ptr : Int) : Void {
		hp -= bytes;
		if (hp < newLimits.start) {
			hp += bytes;
			throw "Out of memory collecting at "+ptr+"! " +
				bytes + " bytes needed, " + (hp - newLimits.start) + " available.";
		}
	}
	
	#if profilememory
	function recordMemoryUsage(kind : String, usage : Int) {
		var bytes = memoryProfile.get(kind);
		if (bytes == null) {
			bytes = 0;
		} 
		bytes += usage;
		memoryProfile.set(kind, bytes);
	}
	
	function dumpMemoryUsageProfile() {
		for (k in memoryProfile.keys()) {
			Errors.report(k + ": " + Math.round(memoryProfile.get(k) / 1024) + "k");
		}
	}
	#end
	
	// The memory
	var memory : ByteMemory;
	// The heap pointer in the new heap half
	public var hp : Int;
	
	var oldLimits : { start : Int, end : Int };
	var newLimits : { start : Int, end : Int };

	// The original closure pointer
	public var closurepointer : Int;
	
	// How old addresses are mapped to new addresses
	var addressMap : Map<Int,Int>;
	var stringSizeMap : Map<Int,Int>;
	
	// Which native values are alive?
	var nativeValuesAlive : Map<Int,Int>;
	
	// Which native functions are alive?
	var nativeFunctionsAlive : Map<Int,Int>;
	
	var runner : BytecodeRunner;
	
	#if profilememory
	// For debugging, this maps from memory type to number of bytes used
	var memoryProfile : Map<String,Int>;
	#end
}
