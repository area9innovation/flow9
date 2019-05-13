// override some errors in format.abc:
import format.abc.Data;

class ABCWriter extends format.abc.Writer {

	public function new(o) {
	    super(o);
		opw = new ABCOpWriter(o);
	}
}