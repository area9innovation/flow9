

class ProfileInfo {
	public function new(debugInfo : DebugInfo) {
		liveAddresses = new Map();
		hot = new Map<String,Float>();
		this.debugInfo = debugInfo;
		allAlive = true;
	}
	public function parse(info : String) {
		allAlive = false;
		var counts = new Map();
		var lines = info.split("\n");
		var totalCount = 0;
		for (l in lines) {
			var fields = l.split("\t");
			var name = fields[0];
			if (name != null && fields[1] != null) {
				var count = Std.parseInt(fields[1]);
				counts.set(name, count);
				totalCount += count;
			}
		}
		
		// Convert to percentages
		
		for (n in counts.keys()) {
			var count = counts.get(n);
			var percent = count / totalCount;
			if (percent > 0.01) {
				hot.set(n, percent);
				var range = debugInfo.getRange(n);
				if (range != null) {
					for (a in range.pc...range.end + 1) {
						liveAddresses.set(a, true);
					}
				}
			}
		}
	}
	
	public function alive(a : Int) : Bool {
		if (allAlive) return true;
		return liveAddresses.get(a);
	}
	
	var debugInfo : DebugInfo;
	// What functions are hot?
	public var hot : Map<String,Float>;
	// Which addresses are alive?
	var liveAddresses : Map<Int,Bool>;
	var allAlive : Bool;
}
