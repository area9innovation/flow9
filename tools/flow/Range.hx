class Range {
	public var st: Int;
	public var en: Int;
	public function new(st: Int, en: Int) { this.st = st; this.en = en; }
	public function iterator() { return st ... en; }
}

