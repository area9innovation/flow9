interface Interpreter {
	public function eval(code : Flow) : Flow;
	public function printCallstack() : Void;
	public function gc() : Void;
	public function toString(value : Flow) : String;
	/**
	 * An API for handling values that need to survive garbage collection.
	 * Native functions should call register with the values that need
	 * to withstand garbage collection, and use lookupRoot to get the
	 * current value before each use. When the value is not required
	 * anymore, it can be released.
	 * This is required in order to support copying garbage collectors that
	 * rewrite pointers.
	 */
	public function registerRoot(c : Flow) : Int;
	public function lookupRoot(i : Int) : Flow;
	public function releaseRoot(i : Int) : Void;
}
