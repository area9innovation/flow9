import Flow;
import FlowArray;

import sys.FileSystem;
import sys.io.File;

class Rules extends RulesProto {

  public function parse (content : String) {
	Assert.trace("Rules:\n" + content);
	var parser = new Parser();
	var module = new Module("<rules>", "");
	return parser.parseRules(this, content, module);
  }

  public function parseFromFile (filename : String) {
	return parse (File.getContent(filename));
  }
}
