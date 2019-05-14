import Flow;
import FlowArray;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import Sys;

class Extractor {
	public function new(modules0 : Modules, interpreter0 : FlowInterpreter, voices0 : Map<String, Bool>) {
		modules = modules0;
		interpreter = interpreter0;
		voices = voices0;
		texts = new Map();
		sequence = new Map();
		hashes = new Map();
		illegalMp3 = [];
		unneededMp3 = [];
		missingDirs = new Map();
		xliff = false;
		xliffpath = null;
		extractRawFormat = false;
	}
	
	// extract all strings in function calls to names in voices and save them in the
	// relevant csv files.  Used to extract strings from flow code so they can be recorded
	// for voice over
	public function extract() : Void {
		if (xliff) {
			voices.set("_", true);
			voices.set("_1", true);
			voices.set("_2", true);
			voices.set("_3", true);
			voices.set("coach", true);
		}

		//Sys.println('Extract strings for: ');
		for (f in voices.keys()) {
		//	Sys.println('    ' + f);

			for (s in interpreter.order) {
				var e = interpreter.topdecs.get(s);
				traverse(e, f);
			}
		}

		if (xliff) {
			writeXlfFile();
		} else {
			writeExtractionFile();
		}
	}
	
	public function extractAllStrings() : Array<{ text : String, positions : Array<Position>}> {
		strictMatchMode = false;
	
		var invalidVoice = "!invalid!";
		for (s in interpreter.order) {
			var e = interpreter.topdecs.get(s);
			traverse(e, invalidVoice);
		}
		
		var result = [];
		var v = texts.get(invalidVoice);
		var seq = sequence.get(invalidVoice);
		for (text in seq) {
			var positions = v.get(text);
			if (positions != null) {
				var p : Array<Position> = positions;
				result.push( { text : text, positions: p } );
			}
		}
		return result;
	}
	
	static var strictMatch = false;
	static var strictMatchMode = true;

	// if voice == null, we are searching for applications of strings in voices.  When
	// one is found, voice is set to it, & traverse then records all occurrences of
	// strings as belonging to that voice.
	private function traverse(e : Flow, voice : String) : Void {
		if (e == null) {
			return;
		}

		switch (e) {
			case SyntaxError(s, pos): 
			case ConstantVoid(pos):
			case ConstantBool(value, pos):
			case ConstantI32(value, pos): 
			case ConstantDouble(value, pos):
			case ConstantString(value, pos):
				if (voice != null && (strictMatch || !strictMatchMode)) {
					// collect string constants related to voice
					var v = texts.get(voice);
					var seq = sequence.get(voice);
					if (v == null) {
						v = new Map();
						texts.set(voice, v);
						seq = [];
						sequence.set(voice, seq);
					}
					var positions = v.get(value);
					if (positions == null) {
						positions = new FlowArray();
						v.set(value, positions);
						seq.push(value);
					}
					positions.push(pos);
				}
			case ConstantArray(value, pos):
				traverseList(value, voice);
			case ConstantStruct(newname, values, pos):
				traverseList(values, if (voices.exists(newname)) newname else voice);
			case ConstantNative(value, pos):
			case ArrayGet(array, index, pos):
				traverse(array, voice);
				traverse(index, voice);
			case VarRef(name, pos):
				if (voices.exists(name)) {
					report('I cannot extract strings from ' + name + ' if it occurs un-applied', e);
				}
			case Field(call, name, pos):
				traverse(call, voice);
			case RefTo(value, pos):
				traverse(value, voice);
			case Pointer(index, pos):
			case Deref(pointer, pos):
				traverse(pointer, voice);
			case SetRef(pointer, value, pos):
				traverse(pointer, voice);
				traverse(value, voice);
			case SetMutable(pointer, field, value, pos):
				traverse(pointer, voice);
				traverse(value, voice);
			case Cast(value, fromtype, totype, pos):
				traverse(value, voice);
			case Let(name, sigma, value, scope, pos):
				traverse(scope, voice);
				traverse(value, voice);
			case Lambda(arguments, type, body, _, pos):
				traverse(body, voice);
			case Closure(body, environment, pos):
				traverse(body, voice);
			case Call(closure, arguments, pos):
				switch (closure) {
					case VarRef(newname, pos): {
						if (newname == voice) {
							strictMatch = true;
						}
						
						traverseList(arguments, if (voices.exists(newname)) 
							// this is an application of one of the names we are looking
							// to extract so we want to extract string constant arguments
							// with respect to that name now, i.e., newname, not voice:
							 newname else voice);
							 
						strictMatch = false;
					}
					default:
						// not a VarRef, so traverse for relevant sub-expressions
						traverse(closure, voice);
						traverseList(arguments, voice);
				}
			case Sequence(statements, pos):
				traverseList(statements, voice);
			case If(condition, then, elseExp, pos):
				traverseList([condition, then, elseExp], voice);
			case Not(e, pos): traverse(e, voice);
			case Negate(e, pos): traverse(e, voice);
			case Multiply(e1, e2, pos):
				traverse(e1, voice);
				traverse(e2, voice);
			case Divide(e1, e2, pos):
				traverse(e1, voice);
				traverse(e2, voice);
			case Modulo(e1, e2, pos):
				traverse(e1, voice);
				traverse(e2, voice);
			case Plus(e1, e2, pos):
				traverse(e1, voice);
				traverse(e2, voice);
			case Minus(e1, e2, pos):
				traverse(e1, voice);
				traverse(e2, voice);
			case Equal(e1, e2, pos):
				traverse(e1, voice);
				traverse(e2, voice);
			case NotEqual(e1, e2, pos):
				traverse(e1, voice);
				traverse(e2, voice);
			case LessThan(e1, e2, pos):
				traverse(e1, voice);
				traverse(e2, voice);
			case LessEqual(e1, e2, pos):
				traverse(e1, voice);
				traverse(e2, voice);
			case GreaterThan(e1, e2, pos):
				traverse(e1, voice);
				traverse(e2, voice);
			case GreaterEqual(e1, e2, pos):
				traverse(e1, voice);
				traverse(e2, voice);
			case And(e1, e2, pos):
				traverse(e1, voice);
				traverse(e2, voice);
			case Or(e1, e2, pos):
				traverse(e1, voice);
				traverse(e2, voice);
			case Switch(value, type, cases, pos) :
				traverse(value, voice);
				for (c in cases) {
					//TODO: This is wrong with
					// x = something;
					// switch() {
					// S1(x): x refers to local variable
					// S2(): x should refer to closure, not local variable from S1
					// S3(x): x refers to local variable
					// }
					traverse(c.body, voice);
					// The names in a constructor should not
					// be traversed into the environment
				}
			case SimpleSwitch(value, cases, pos) :
				traverse(value, voice);
				for (c in cases) {
					traverse(c.body, voice);
				}
			case Native(name, io, args, result, defbody, pos):
				if (defbody != null) traverse(defbody, voice);
			case NativeClosure(nargs, fn, pos):
			case StackSlot(q0, q1, q2):
		}
	}

	private function traverseList(es : Array<Flow>, voice : String) : Void {
		for (e in es) {
			traverse(e, voice);
		}
	}
	
	// Removes wiki mark-up, leaving only audio things
	private function extractAudioParts(text: String): Array<String> {
		var removeInBetweenTags = function(str, openTag, closeTag) {
			var res: String = str;
		
			do {
				var startIndex = res.indexOf(openTag);
				if (startIndex < 0)
					return res;
					
				var endIndex = res.indexOf(closeTag, startIndex + 1);
				if (endIndex >= 0) {
					res = res.substr(0, startIndex) + res.substr(endIndex + closeTag.length);
				} else {
					return res;
				}
			} while (true);

			return "Wow! We can't be here!";
		};
		
		// Remove ==Headers==
		var res = removeInBetweenTags(text, "==", "==");
		
		// Remove [Media]
		res = removeInBetweenTags(res, "[", "]");
		res = StringTools.replace(res, "\\small", "");
		
		return res.split("##");
	}

	private function texts2xliff(name : String) : String {
		var p = {f: '', l: 0, s: -1, e: -1, type: null, type2: null};
		var units = new Array<Flow>();
		for (tagname in texts.keys()) {
			var seq = sequence.get(tagname);						
			for (text in seq) {
				// Disable wiki variables processing due to crash during eval
				text = StringTools.replace(text, "}", "&#x007d;");
				text = StringTools.replace(text, "{", "&#x007b;");
				var tripple : FlowArray<Flow> = FlowArrayUtil.three(ConstantI32(0, p), ConstantString(tagname, p), ConstantString(text, p));
				units.push(ConstantStruct("ContentUnit", tripple, p)); // ContentUnit is defined in translationutils.flow
			}
		}
		// Calls flow functions to set translation api and make xliff content
		interpreter.eval(Call(VarRef('setTranslationSimpleStringsApi', p), [], p));
		interpreter.eval(Call(VarRef('setTranslationWikiApi', p), [], p));
		switch(interpreter.eval(Call(VarRef('texts2XliffContent', p), [ConstantArray(FlowArrayUtil.fromArray(units), p), ConstantString(name, p)], p))) {
			case ConstantString(s, pos): return s;
			default: return "";
		}
	}

	private function writeXlfFile() {
		//trace("in writeXlfFile: xliffpath = " + xliffpath);
		var name = Path.withoutExtension(Path.withoutDirectory(modules.topmodule.name));
		var xlf = {
			if (xliffpath == null) name + ".xlf";
			else xliffpath;
		}
		
		try {
			trace("writing file " + xlf);

			var recordFile = File.write(xlf, false);
			var xliffContent = texts2xliff(name);
			recordFile.writeString(xliffContent);
			recordFile.close();
		} catch (e : Dynamic) {
			trace("I couldn't write " + xlf + " : " + e);
		}
	}
	
	// Creates either ready-to-use CSV file (if extractRawFormat == false) or a file with all vo lines joined through "@@" to be processed by votranslate.flow later
	private function writeExtractionFile() {
		for (voice in texts.keys()) {
			if (xliff && voice != "coach")
				continue;
			var name = 'record-' + voice + "-" + 
				(if (xliff) Path.withoutExtension(Path.withoutDirectory(modules.topmodule.name)) else "")
				 + ".csv";
			var v = texts.get(voice);
			var seq = sequence.get(voice);

			var outString = "";
			
			try {
				var recordFile = File.write(name, false);
				for (text in seq) {
					var audioTexts = extractAudioParts(text);
					var validString : EReg = ~/[a-zA-Z]/;

					for (audioText in audioTexts) {
						if (!validString.match(audioText) || audioText == "") {
							continue;
						}

						if (extractRawFormat) {
							if (outString != "") outString += "@@";	// votranslate.flow parses this format
							outString += audioText;
						} else {
							var hash = vofilename(audioText);
							var positions = v.get(text);
							
							var p = "";
							var sep = "";
							for (po in positions) {
								p += sep + modules.positionToString(po);
								sep = ";";
							}
							
							if (!recorded(hash, voice, positions[0])) {
								hashes.set(hash, {text: text, voice: voice, positions: positions});						
								recordFile.writeString('"' + hash + '","' + csvescape(audioText) + '", "' + p + '"\n');
							}							
						}
					}
				}

				if (extractRawFormat) {
					recordFile.writeString(outString);
				} 

				recordFile.close();
				//trace('Look in ' + name);
			} catch (e : Dynamic) {
				trace('I could not write ' + name + '.  Maybe you have it open in Excel?');
				trace('Exception: ' + e);
			}
		}
	}

	private function recorded(hash : String, voice: String, p : Position) : Bool {
		var oldFileName = 'sounds2/' + voice + "/default/" + hash + '.mp3';
		var newFileName = 'sounds2/' + voice + "/default/" + hash.substr(0, 2) + "/" + hash.substr(2) + '.mp3';
		
		var recorded = FileSystem.exists(newFileName) || FileSystem.exists(oldFileName);

		if (!xliff) {
			trace(newFileName);
			if (recorded) {
				trace("  + already recorded");
			} else {
				trace("  - needs recording");
			}
		}
		
		return recorded;
	}

	static private function dirname(path : String) : String {
		var r : EReg = ~/(.*)\/([^\/]+)$/;
		if (r.match(path))
			return r.matched(1);
		
		return "";
	}
	
	// Calculate hash for the string.  Call flow code to do this.  This code is needed
	// both in flow (when playing the sample) & here (when generating the list of sample
	// files to record).
	private function vofilename(text : String) : String {
		var p = {f: '', l: 0, s: -1, e: -1, type: null, type2: null};
		switch (interpreter.eval(Call(VarRef('vofilename', p), [ConstantString(text, p)], p))) {
			case ConstantString(s, pos): return s;
			default:
		}
		trace('interpreter:');
		//trace(interpreter.topdecs);
		throw 'I could not call vofilename() in speak.flow';
	}

	static private function csvescape(s : String) : String {
		s = StringTools.replace(s, '##', '');
		s = StringTools.replace(s, '"', '""');
		s = StringTools.replace(s, '\n', '\r\n');
		return s;
		/*
		.#
		  stx
          lda  #0a
		  sty
		  sti  #\r
		  esk
          imo
         #.
		*/
	}
	
	static private function error(error : String, code : Flow) : String {
		return Prettyprint.getLocation(code) + ": " + error;
	}

	static private function report(s : String, code : Flow) : Void {
		Errors.report(error(s, code));
	}

	public function insertvo(file : String) : Void {
		trace('unzipping ' + file);
		var z = unzip(file);
		var m = mp3s(z);
		for (hash in m.keys()) {
			var tp = hashes.get(hash);
			if (tp == null) {
				(if (hash.length != 6) illegalMp3 else unneededMp3).push(hash);
			} else {
				insertMp3(hash, tp, m, z);
				//trace(hash + '.mp3 found in zip & needed in ' + tp.positions + '\t\t for text: ' + tp.text);
			}
		}
		trace('\n\n');
		if (illegalMp3.length > 0) {
			trace('');
			trace('mp3s with illegal names:');
			for (s in illegalMp3) {
				trace('\t\t' + s);
			}
		}
		if (unneededMp3.length > 0) {
			trace('');
			trace('mp3s in the zip that are not used in the code:');
			for (s in unneededMp3) {
				trace('\t\t' + s);
			}
		}
		var missingdirs = missingDirs.keys();
		if (missingdirs.hasNext()) {
			trace('');
			trace('I made the following sound directories; please check they are correct:');
			for (s in missingdirs) {
				trace('\t\t' + s);
			}
		}	
	}

	private function insertMp3(hash : String,
							   tp : {text: String, voice: String, positions : Array<Position>},
							   m : Map<String,String>, dir : String) : Void {
		// convert the positions to paths, e.g., "labsmart/biology/enzymes/CatalaseC.flow"
		// means the path for the mp3 should be "labsmart/biology/enzymes/sounds2/".  If
		// an mp3 is used in more than one lab, then it should be copied to each of those
		// labs.  If an mp3 is used more than once in the same lab, copy only once.
		var paths = new Map();	// set of paths
		for (p1 in tp.positions) {
			var p2 = Path.directory(p1.f);
			if (! paths.exists(p2)) {
				paths.set(p2, true);
			}
		}
		for (p3 in paths.keys()) {
			var p4 = p3 + '/sounds2';
			var p5 = p4 + '/' + tp.voice;
			if (! isDir(p5)) {
				missingDirs.set(p5, true);
				// Make these dirs
				createDir(p4);
				createDir(p5);
			}
			copyMp3(dir + '/' + m.get(hash), p5);
			//trace('copy ' + hash + ':  copy ' + dir + '/' + m.get(hash) + ' ' + p5);
		}
	}

	// convert the mp3 to a more compressed format (speex or resampled mp3) & copy it to the right dir.
	private function copyMp3(mp3 : String, dest : String) : Void {
		/*
		// make a speex file:
		var base = Path.withoutExtension(mp3);
		var wav = base + '.wav';
		exec9('mpg123 -w ' + wav + ' ' + mp3);
		var spx = base + '.spx';
		exec9('speexenc ' + wav + ' ' + spx);
		trace('copy ' + spx + ' ' + dest + '/' + Path.withoutDirectory(spx));
		File.copy(spx, dest + '/' + Path.withoutDirectory(spx));
		*/
		// make a more compressed mp3
		var to = dest + '/' + Path.withoutDirectory(mp3);
		exec9('lame -b 24 -m m -h -V 6 -B 64 --resample 22.05 --lowpass 11 --lowpass-width 0 ' + mp3 + ' ' + to);
	}
	
	static private function unzip(file : String) : String {
		var i = exec9('7z e -y -o"vo" "' + file + '"');
		if (i == 0) {
			trace('I unzipped ' + file + ' into dir vo');
		} else {
			trace('I could not unzip ' + file);
		}		
		return 'vo';
	}

	// map mp3 name to path to that mp3 found in dir
	static private function mp3s(dir : String) : Map<String,String> {
		var h = new Map();
		var files = FileSystem.readDirectory(dir);
		for (f in files) {
			if (StringTools.endsWith(f, '.mp3') && ! StringTools.startsWith(f, '.')) {
				var base = Path.withoutExtension(f);
				h.set(base, f);
			}
		}
		return h;
	}

	static private function exec9(c : String) : Int {
		return exec('c:/area9/executables/' + c);
	}
	
	static private function exec(c : String) : Int {
		trace(c);
		return Sys.command(c);
	}

	static public function isDir(path : String) : Bool {
		return FileSystem.exists(path) && FileSystem.isDirectory(path);
	}
	
	static private function createDir(dir : String) {
		try {
			FileSystem.createDirectory(dir);
		} catch (e : Dynamic) {
			// if (! FileSystem.isDirectory(dir)) & FileSystem.exists() do not
			// work, so it just throws always if the dir exists already, which is good
			// enough
		}
	}
	
	static public var soundPath : String;

	public var xliff : Bool; // export texts to xliff format for translation
	public var xliffpath : String; // output xliff file path. If null, save xliff in current dir
	public var extractRawFormat : Bool;

	private var modules : Modules;
	private var interpreter : FlowInterpreter; // the flow code from which to extract texts
	private var voices : Map<String,Bool>; // voices for which we should extract texts
	private var texts : Map<String,Map<String,Array<Position>>>; // voice -> text -> list of positions where this voice speaking this text occurs
	private var sequence : Map<String,Array<String>>; // voice -> order of texts in the code for that voice, so we can emit them in that same order
	private var hashes : Map<String,{text: String, voice: String, positions: Array<Position>}>; // hash -> text & positions this mp3 is used for

	// The following variables collect errors found during vo insertion
	private var illegalMp3 : Array<String>;
	private var unneededMp3 : Array<String>;
	private var missingDirs : Map<String,Bool>;
}

