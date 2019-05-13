import Flow;
import FlowArray;
import ObjectInfo;

#if jsruntime
#error "Attempt to link Flow compiler code into JS runtime"
#end

#if sys
import sys.io.File;
#end

typedef DebugLocalVar = { type: Int, id: Int, name: String };

class DebugInfo {
	public function new(?parent : DebugInfo = null) {
		toplevel = (parent == null);
		positions = new FlowArray();
		topLevels = new FlowArray();
		lambdas = new FlowArray();
		codePosition = 0;
		lambdaIdx = 0;
		toplevelName = '';
		topStack = [''];
	}
	public function add(address : Int, position : Position) : Void {
		if (positions.length > 0) {
			var last = positions[positions.length - 1];
			if (last.pos.f == position.f && last.pos.l == position.l) {
				return;
			}
		}
		positions.push( { pc: address, pos: position } );
	}
	public function getPositionStruct(address : Int) : Position {
		if (address > codePosition) {
			address -= codePosition;
		}
		for (i in 0...positions.length - 1) {
			var p = positions[i];
			var start = p.pc;
			var end = positions[i + 1].pc;
			if (start <= address && address < end) {
				return p.pos;
			}
		}
		return null;
	}
	public function getPosition(address : Int) : String {
		var info = getPositionStruct(address);
		if (info != null)
			return info.f + ":" + info.l + ": ";
		else
			return "pc: " + StringTools.hex(address, 4) + ": ";
	}
	public function append(offset : Int, debugInfo : DebugInfo) {
		for (t in debugInfo.topLevels) {
			topLevels.push({pc : t.pc + offset, name : t.name, locals: t.locals});
		}
		for (p in debugInfo.lambdas) {
			if (p.start)
				beginLambda(offset + p.pc, p.locals);
			else
				endLambda(offset + p.pc);
		}
		for (p in debugInfo.positions) {
			add(offset + p.pc, p.pos);
		}
	}
	public function setCodePosition(o : Int) {
		codePosition = o;
	}
	
	public function addTopLevel(address : Int, top_name : String) {
		lambdaIdx = 0;
		toplevelName = top_name;
		top_name += "$init";
		topStack = [top_name];
		topLevels.push({pc: address, name: top_name, locals: null});
	}
	
	public function beginLambda(address : Int, ?locals: FlowArray<DebugLocalVar> = null) {
		if (toplevel) {
			var lname = toplevelName + (lambdaIdx > 0 ? '$'+lambdaIdx : '');
			topStack.push(lname);
			topLevels.push({pc: address, name: lname, locals:locals});
			lambdaIdx++;
		} else {
			lambdas.push({pc: address, start: true, locals:locals});
		}
	}
	public function endLambda(address : Int) {
		if (toplevel) {
			var name = topStack.pop();
			var oname = topStack[topStack.length-1];
			if (name != oname)
				topLevels.push({pc: address, name:oname, locals: null});
		} else {
			lambdas.push({pc: address, start: false, locals: null});
		}
	}
	
	public function DumpToFile(file : String) {
        #if sys
		var f = File.write(file, false);
		for (tl in topLevels) {
			f.writeString(tl.pc + " " + tl.name + "\n");
		}
		f.writeString("\n");
		for (p in positions) {
		    f.writeString(p.pc + " " + p.pos.f + " " + p.pos.l + " " + p.pos.s + "\n");
		}
		f.writeString("\n");
		for (tl in topLevels) {
			if (tl.locals != null) {
				for (lv in tl.locals) {
					f.writeString("L " + tl.pc + " " + lv.type + " " + lv.id + " " + lv.name + "\n");
				}
			}
		}
		f.close();
        #end
	}
	
	public function getRange(name : String) : { pc : Int, end : Int } {
		for (i in 0...topLevels.length - 1) {
			var e = topLevels[i];
			if (e.name == name) {
				return { pc: e.pc , end: topLevels[i +1].pc - 1 };
			}
		}
		return null;
	}

	public function write(writer : InfoWriter) {
		ObjectInfo.writeBool(writer, toplevel);
		ObjectInfo.writeUInt(writer, codePosition);
		ObjectInfo.writeArray(writer, function(writer, pos) {
			ObjectInfo.writeUInt(writer, pos.pc);
			ObjectInfo.writePos(writer, pos.pos, false);
		}, FlowArrayUtil.toArray(positions));
		var dummy = new FlowArray<DebugLocalVar>();
		ObjectInfo.writeArray(writer, function(writer, top) {
			ObjectInfo.writeUInt(writer, top.pc);
			ObjectInfo.writeString(writer, top.name);
			var locals = top.locals;
			if (locals == null)
				locals = dummy;
			ObjectInfo.writeArray(writer, function(writer, loc) {
				ObjectInfo.writeUInt(writer, loc.type);
				ObjectInfo.writeUInt(writer, loc.id);
				ObjectInfo.writeString(writer, loc.name);
			}, FlowArrayUtil.toArray(locals));
		}, FlowArrayUtil.toArray(topLevels));
		ObjectInfo.writeUInt(writer, lambdaIdx);
		ObjectInfo.writeString(writer, toplevelName);
		ObjectInfo.writeArray(writer, ObjectInfo.writeString, topStack);
	}
	
	public static function read(reader : InfoReader) : DebugInfo {
		var i = new DebugInfo();
		i.toplevel = ObjectInfo.readBool(reader);
		i.codePosition = ObjectInfo.readUInt(reader);
		i.positions = FlowArrayUtil.fromArray(ObjectInfo.readArray(reader, function(reader) {
			var pc = ObjectInfo.readUInt(reader);
			return {pc : pc, pos : ObjectInfo.readPos(reader)};
		}));
		i.topLevels = FlowArrayUtil.fromArray(ObjectInfo.readArray(reader, function(reader) {
			var pc = ObjectInfo.readUInt(reader);
			var name = ObjectInfo.readString(reader);
			var locals = FlowArrayUtil.fromArray(ObjectInfo.readArray(reader, function(reader) {
				var type = ObjectInfo.readUInt(reader);
				var id = ObjectInfo.readUInt(reader);
				return {type: type, id: id, name: ObjectInfo.readString(reader)};
			}));
			return {pc : pc, name : name, locals: locals};
 		}));
		i.lambdaIdx = ObjectInfo.readUInt(reader);
		i.toplevelName = ObjectInfo.readString(reader);
		i.topStack = ObjectInfo.readArray(reader, ObjectInfo.readString);
		return i;
	}
	
	var toplevel : Bool;
	var codePosition : Int;
	var positions : FlowArray< { pc : Int, pos : Position }>;
	var topLevels : FlowArray< { pc : Int, name : String, locals: FlowArray<DebugLocalVar> } >;
	var lambdas : FlowArray< { pc: Int, start: Bool, locals: FlowArray<DebugLocalVar> } >;
	var lambdaIdx : Int;
	var toplevelName : String;
	var topStack : Array<String>;

	static inline public var LOCAL_VAR = 0;
	static inline public var LOCAL_ARG = 1;
	static inline public var LOCAL_UPVAR = 2;
}

