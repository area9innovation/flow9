import format.abc.Data;

class ABCOpWriter extends format.abc.OpWriter {

	public function new(o) {
	    super(o);
	}

	override function reg( v : Int ) {
		writeInt(v);
	}

}