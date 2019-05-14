


class MemoryProfiler {
	public function new(profile : Map<Int,Int>, position2string : Int -> String) {
		var sorted = [];
		for (k in profile.keys()) {
			sorted.push({pos : k, bytes : profile.get(k)});
		}
		sorted.sort(function(b,a) {
			return if (a.bytes < b.bytes) -1
			else if (a.bytes == b.bytes) 0
			else 1;
		});
		
		for (i in 0...Math.floor(Math.min(10, sorted.length))) {
			var entry = sorted[i];
			Errors.report(position2string(entry.pos) + ": " + Math.round(entry.bytes / 1024.0) + "k");
		}
	}
	
	var biggest : Map<Int,Int>;
}
