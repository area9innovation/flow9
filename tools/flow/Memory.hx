
class Memory {
	public function new() {
		cells = new FlowArray();
	}
	public function serialize() : String {
		var r = '';
		var i = 0;
		for (m in cells) {
			r += i + ':' + Prettyprint.prettyprint(m, '  ') + '\n';
			++i;
		}
		return r;
	}
	// Here we store all references
	public var cells : FlowArray<Flow>;
}
