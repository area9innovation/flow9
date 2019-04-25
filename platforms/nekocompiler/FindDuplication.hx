import Flow;
import FlowArray;
import ByteMemory;

typedef TreeHash = {
	hash : I32,
	// How many nodes does this have?
	weight : Int,
	// How heavy are nodes that are different? Exact matches are 0
	differenceWeight : Int,
	// The AST
	code : Flow
}

// http://en.wikipedia.org/wiki/Fowler_Noll_Vo_hash
class Fnv1aHash {
	public function new() {
		fnvPrime = (16777619);
		fnvBasis = ((0x11c9dc5) | ((0x20000000) << 2)); // 2166136261, 0x811C9DC5
	}
	public function basis() : I32 {
		return fnvBasis;
	}
	public function hashI32(hash : I32, v : I32) {
		var t1 = hashI8(hash, v);
		var t2 = hashI8(t1, (v >> 8));
		var t3 = hashI8(t2, (v >> 16));
		var t4 = hashI8(t3, (v >> 24));
		return t4;
	}
	public function hashI8(hash : I32, b : I32) : I32 {
		var t = (hash ^ (b & (0xff)));
		return (t * fnvPrime);
	}
	var fnvPrime : I32;
	var fnvBasis : I32;
}

typedef Duplication = FlowArray<TreeHash>;

// Finds duplication of code using a hash of subtrees
class FindDuplication {
	public function new(i : FlowInterpreter, exactOnly : Bool) {
		hashes = new Map();
		
		// For converting doubles to int
		bytememory = new ByteMemory(8);
		
		hasher = new Fnv1aHash();
		this.exactOnly = exactOnly;
		
		// Calculate hashes for all declarations
		for (d in i.order) {
			var c = i.topdecs.get(d);
			var duplication = calcDuplication(c);
			insertDuplication(c, duplication);
		}
		
		// Find duplicates
		var duplicates = new FlowArray();
		for (d in hashes.keys()) {
			var dups = hashes.get(d);
			if (dups.length > 1) {
				var fitness = 0;
				var maxDifference = 0;
				for (th in dups) {
					fitness += th.weight;
					if (th.differenceWeight > maxDifference) {
						maxDifference = th.differenceWeight;
					}
				}
				fitness = 3 * fitness - maxDifference;
				duplicates.push({ d : dups, f : fitness });
			}
		}
		
		// Sort them by weight
		duplicates.sort(function(a : Null<{ d: Duplication, f : Int }>, b : Null<{ d: Duplication, f : Int }>) {
			return if (a.f < a.f) 1;
			else if (a.f == a.f) 0
			else -1;
		});
		
		// And print the ones with some meat on them
		for (d in duplicates) {
			if (d.d[0].weight > 20) {
				printDuplication(d.d);
			}
		}
	}
	
	// Used to convert doubles to an int hash
	var bytememory : ByteMemory;
	// Helper to calculate the hash values
	var hasher : Fnv1aHash;
	
	var hashes : Map<Int,Duplication>;
	
	var exactOnly : Bool;
	
	function insertDuplication(f : Flow, d : Duplication) {
		for (h in d) {
			insertHash(f, h);
		}
	}
	
	function printDuplication(d : Duplication) {
		var s = "";
		var sep = "";
		var maxWeight = 0;
		for (h in d) {
			var p = FlowUtil.getPosition(h.code);
			s += sep + p.f + ":" + p.l;
			if (h.differenceWeight != 0) {
				s += "~" + h.differenceWeight;
			}
			if (h.weight > maxWeight) {
				maxWeight = h.weight;
			}
			s += " ";
		}
		var code = Prettyprint.prettyprint(d[0].code, " ");
		s = maxWeight + ": " + s + "\n" + code + "\n";
		Sys.println(s);
	}
	
	function insertHash(f : Flow, h : TreeHash) {
		var hashint = I2i.toInt(h.hash);
		var d = hashes.get(hashint);
		if (d == null) {
			d = FlowArrayUtil.one(h);
		} else {
			if (h != d[0]) {
				d.push(h);
			}
		}
		hashes.set(hashint, d);
	}
	
	private function calcDuplication(f : Flow) : Duplication {
		return traverse(f);
	}
	
	function hashInt(i : I32, f : Flow) : TreeHash {
		var t = hasher.hashI32(hasher.basis(), i);
		return { hash: t, differenceWeight: 0, code : f, weight : 1 };
	}
	
	function hashString(s : String, f : Flow) : TreeHash {
		var h = hasher.basis();
		for (i in 0...s.length) {
			h = hasher.hashI8(h, (s.charCodeAt(i)));
		}
		return { hash: h, differenceWeight: 0, code : f, weight : 1 };
	}
	
	function join(h1 : TreeHash, h2 : TreeHash) : TreeHash {
		return { 
			hash : hasher.hashI32(h1.hash, h2.hash), 
			differenceWeight : h1.differenceWeight + h2.differenceWeight,
			code : h1.code == null ? h2.code : h1.code, 
			weight: h1.weight + h2.weight 
		};
	}
	
	function joinList(h : TreeHash, l : Duplication) : Duplication {
		var r = new FlowArray();
		for (h2 in l) {
			r.push(join(h, h2));
		}
		return r;
	}
	
	private function traverse(e : Flow) : Duplication {
		var h = switch (e) {
			case SyntaxError(s, pos): 
				new FlowArray();
			case ConstantVoid(pos):
				// Some nice and completely random numbers from random.org
				FlowArrayUtil.one(hashInt((928633), e));
			case ConstantBool(value, pos):
				// Some nice and completely random numbers from random.org
				FlowArrayUtil.one(hashInt((value ? 348471 : 1808826), e));
			case ConstantI32(value, pos): 
				FlowArrayUtil.one(hashInt(value, e));
			case ConstantDouble(value, pos):
				bytememory.setDouble(0, value);
				FlowArrayUtil.one(join(
					hashInt(bytememory.getI32(0), e),
					hashInt(bytememory.getI32(4), e)
				));
			case ConstantString(value, pos):
				FlowArrayUtil.one(hashString(value, e));
			case ConstantArray(value, pos):
				traverseList(value, e);
			case ConstantStruct(newname, values, pos):
				traverseList(values, e);
			case ConstantNative(value, pos):
				new FlowArray();
			case ArrayGet(array, index, pos):
				traverse(array).concat(traverse(index));
			case VarRef(name, pos):
				FlowArrayUtil.one(hashString(name, e));
			case Field(call, name, pos):
				joinList(hashString(name, e), traverse(call));
			case RefTo(value, pos):
				traverse(value);
			case Pointer(index, pos):
				new FlowArray();
			case Deref(pointer, pos):
				traverse(pointer);
			case SetRef(pointer, value, pos):
				traverseList([pointer, value], e);
			case SetMutable(pointer, field, value, pos):
				traverseList([pointer, value], e);
			case Cast(value, fromtype, totype, pos):
				traverse(value);
			case Let(name, sigma, value, scope, pos):
				joinList(hashString(name, e), traverseList([scope, value], e));
			case Lambda(arguments, type, body, _, pos):
				traverse(body);
			case Closure(body, environment, pos):
				traverse(body);
			case Call(closure, arguments, pos):
				traverseList([closure].concat(arguments), e);
			case Sequence(statements, pos):
				traverseList(statements, e);
			case If(condition, then, elseExp, pos):
				traverseList([condition, then, elseExp], e);
			case Not(e, pos): traverse(e);
			case Negate(e, pos): traverse(e);
			case Multiply(e1, e2, pos):
				traverseList([e1, e2], e);
			case Divide(e1, e2, pos):
				traverseList([e1, e2], e);
			case Modulo(e1, e2, pos):
				traverseList([e1, e2], e);
			case Plus(e1, e2, pos):
				traverseList([e1, e2], e);
			case Minus(e1, e2, pos):
				traverseList([e1, e2], e);
			case Equal(e1, e2, pos):
				traverseList([e1, e2], e);
			case NotEqual(e1, e2, pos):
				traverseList([e1, e2], e);
			case LessThan(e1, e2, pos):
				traverseList([e1, e2], e);
			case LessEqual(e1, e2, pos):
				traverseList([e1, e2], e);
			case GreaterThan(e1, e2, pos):
				traverseList([e1, e2], e);
			case GreaterEqual(e1, e2, pos):
				traverseList([e1, e2], e);
			case And(e1, e2, pos):
				traverseList([e1, e2], e);
			case Or(e1, e2, pos):
				traverseList([e1, e2], e);
			case Switch(value, type, cases, pos) :
				var a = [value];
				for (c in cases) {
					a.push(ConstantString(c.structname, pos));
					a.push(c.body);
				}
				traverseList(a, e);
			case SimpleSwitch(value, cases, pos) :
				var a = [value];
				for (c in cases) {
					a.push(ConstantString(c.structname, pos));
					a.push(c.body);
				}
				traverseList(a, e);
			case Native(name, io, args, result, defbody, pos):
				if (defbody == null) FlowArrayUtil.one(hashString(name, e));
				else joinList(hashString(name, e), traverse(defbody));
			case NativeClosure(nargs, fn, pos):
				new FlowArray();
			case StackSlot(q0, q1, q2):
				new FlowArray();
		}
		
		insertDuplication(e, h);
		return h;
	}

	private function traverseList(es : Array<Flow>, place : Flow) : Duplication {
		// Find the exact ones
		var exacts = new FlowArray();
		for (e in es) {
			var c = traverse(e);
			var exact = getExact(c);
			if (exact != null) {
				exacts.push(exact);
			}
		}
		
		var hashes = FlowArrayUtil.one(traverseListWithSkip(exacts, place, -1));
		if (!exactOnly) {
			for (i in 0...exacts.length) {
				var h = traverseListWithSkip(exacts, place, i);
				
				// Check if we already have this exact hash
				var found = false;
				for (eh in hashes) {
					if (eh.hash == h.hash) {
						found = true;
						break;
					}
				}
				if (!found) {
					hashes.push( h );
				}
			}
		}
		return hashes;
	}
	
	private function traverseListWithSkip(es : FlowArray<TreeHash>, place : Flow, skip : Int) : TreeHash {
		var hash = { hash : hasher.basis(), differenceWeight: 0, code : place, weight: 0 };
		var i = 0;
		for (e in es) {
			if (i != skip) {
				hash = join(hash, e);
			} else {
				// Those we skip, we add the weight to track how different they are
				hash.differenceWeight += e.weight;
			}
			++i;
		}
		return hash;
	}
	
	function getExact(d : Duplication) : TreeHash {
		for (hc in d) {
			if (hc.differenceWeight == 0) {
				return hc;
			}
		}
		return null;
	}
}
