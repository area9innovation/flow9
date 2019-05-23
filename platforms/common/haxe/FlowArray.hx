#if flash
typedef FlowArray<T> = flash.Vector<T>;
#else
typedef FlowArray<T> = Array<T>;
#end

class FlowArrayUtil {
	static public inline function fromArray<T>(a : Array<T>) : FlowArray<T> {
		#if flash
			//var v = new flash.Vector(a.length);
			var v = new flash.Vector();
			for (e in a) {
				v.push(e);
			}
			return v;
		#else
			return a;
		#end
	}
	
	static public inline function toArray<T>(a : FlowArray<T>) : Array<T> {
		#if (flash || js)
			var v : Array<T> = new Array();
			for (e in a) {
				v.push(e);
			}
			return v;
		#else
			return a;
		#end
	}
	
	static public inline function one<T>(e : T) : FlowArray<T> {
		#if flash
			//var v = new flash.Vector(1);
			var v = new flash.Vector();
			v.push(e);
			return v;
		#else
			return [e];
		#end
	}

	static public inline function two<T>(e1 : T, e2 : T) : FlowArray<T> {
		#if flash
			//var v = new flash.Vector(2);
			var v = new flash.Vector();
			v.push(e1);
			v.push(e2);
			return v;
		#else
			return [e1, e2];
		#end
	}

	static public inline function three<T>(e1 : T, e2 : T, e3 : T) : FlowArray<T> {
		#if flash
			//var v = new flash.Vector(3);
			var v = new flash.Vector();
			v.push(e1);
			v.push(e2);
			v.push(e3);
			return v;
		#else
			return [e1, e2, e3];
		#end
	}
}
