
class Profiler {
	static private var instance : Profiler;
	inline static public function get() : Profiler {
		if (null == instance) {
			instance = new Profiler();
		}
		return instance;
	}
	private function new() {
		reset();
		stack = new Array();
	}
	public function reset() {
		buckets = new Map<String,Float>();
		counts = new Map<String,Int>();
	}
	
	public inline function time() : Float {
		#if sys
		return Sys.cpuTime();
		#else
		return haxe.Timer.stamp();
		#end
	}
	
	public function profileStart(bucket : String) {
		var nt = time();
		if (stack.length > 0) {
			// We already have something. Let's allocate the time until now to that
			var t = stack[stack.length - 1];
			accountTo(t.bucket, nt - t.start);
		}
		stack.push({bucket: bucket, start: nt});
		return nt;
	}

	public function profileEnd(bucket : String) {
		var current = stack.pop();
		if (current.bucket != bucket) {
			//trace("Invariant broken. Expected " + current.bucket + " but got " + bucket);
		}
		var nt = time();
		var spent = (nt - current.start);
		count(current.bucket, spent);
		if (stack.length > 0) {
			stack[stack.length - 1].start = nt;
		}
	}
	
	public function count(bucket : String, amount : Float) {
		if (buckets.exists(bucket)) {
			buckets.set(bucket, buckets.get(bucket) + amount);
			var count = counts.get(bucket);
			if (count == null) {
				count = 1;
			}
			counts.set(bucket, count + 1);
		} else {
			buckets.set(bucket, amount);
			counts.set(bucket, 1);
		}		
	}
	
	public function accountTo(bucket : String, amount : Float) {
		if (buckets.exists(bucket)) {
			buckets.set(bucket, buckets.get(bucket) + amount);
		} else {
			buckets.set(bucket, amount);
		}		
	}

	public function calcTimes(visitor: String -> Float -> Float -> Int -> Void ): Float {
		var limit = 5/1000;
		
		var sum = 0.0;
		for (k in buckets.keys()) {
			sum += buckets.get(k);
		}
		
		if (sum <= limit) {
			return 0;
		}
		for (k in buckets.keys()) {
			var p = buckets.get(k) / sum * 100.0;
			if (p > limit)
				visitor(k, buckets.get(k), Math.round(p * 10.0) / 10.0, counts.get(k));
		}
		return sum;
	}
	
	public function dump(s : String) {
		var ss : Array<Dynamic> = [];
		Errors.warning("Buckets: " + s + " took " +
			calcTimes(
				function(bucket, time, percentage, count) {
					#if profilecalls
						ss.push([count, ' ' + percentage + "% \t" + bucket + ": " + count + " calls took " + (Math.round(time * 100.0) / 100.0) + " s"]);
					#else
						if (percentage > 0.1) {
							ss.push([percentage, ' ' + percentage + "% \t" + bucket + ": " + count + " calls took " + (Math.round(time * 100.0) / 100.0) + " s"]);
						}
					#end
				}
			)
		);
		ss.sort(function (s2, s1) { return if (s1[0] < s2[0]) -1 else if (s1[0] > s2[0]) 1 else 0;});
		var i = 0;
		for (_s in ss) {
			Errors.warning(_s[1]);
			i++;
			if (i == 40) {
				return;
			}
		}
	}

	private var buckets : Map<String,Float>;
	private var counts : Map<String,Int>;
	private var stack : Array<{ bucket: String, start : Float}>;
}
