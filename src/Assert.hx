import haxe.CallStack;

class Assert {
	public static inline function check (cond: Bool, ?message: String) {
		if (!cond)
			fail ("Assertion" + (if (message != null) ": " + message else ""));
	}

    macro public static function check1(cond: haxe.macro.Expr, ?msg : haxe.macro.Expr) {
        var pos  = haxe.macro.Context.currentPos();
	    if (msg == null) 
		  msg = { expr : haxe.macro.EConst({ 
			  expr : haxe.macro.EString (cond.toString().toString()), pos : pos}), pos : pos};
        return { expr : EIf(cond, 
							{ expr : EThrow (cond), pos : pos },  
							null
							), pos : pos };
    }

	public static inline function fail(message){
		printStack ("Failure: " + message);
		throw message;
	}

	public static function printStack (?message) {
		if (message != null) {
			println(message);
		}
		#if sys
			println("Editor=" + Options.EDITOR);
		#end
		println(callStackToString(haxe.CallStack.callStack()));
	}

	public static function printExnStack (?message) {
		if (message != null) {
			println(message);
		}
		#if sys
		  println("Editor=" + Options.EDITOR);
		#end
		println(callStackToString(haxe.CallStack.exceptionStack()));
	}

    static public function callStackToString(stack) {
		return 
			#if (neko)
	  		switch (Options.EDITOR) {
	  		case Options.EditorType.Other: 
	  			haxe.CallStack.toString(stack);
	  		case Options.EditorType.Emacs: {
			  var res = new StringBuf();
			  for(s in stack)
				switch (s) {
				case haxe.StackItem.FilePos(item, file, pos):
				  res.add(file + ": " + pos + ": called from\n");
				default: {}
				}
			  res.toString();
			  }
	  		}
	  		#else
	  			haxe.CallStack.toString(stack);
	  		#end
    }

	static public function trace(s : String) {
#if sys
		// Extracting the stack is a very expensive operation,
		// so don't do it if we won't print anything anyway.
		if (!Options.DEBUG)
			return;
#end
		var stack = haxe.CallStack.callStack();
		var loc = "<unknown>";
		var i = 2;
      #if !cpp
		for(s in stack)
			switch (s) {
				case haxe.StackItem.FilePos(item, file, pos):
					if (--i == 0) {
						loc = file + ": " + pos;
						break;
					}
				default: { }
			}
      #end
		println("TRACE: at " + loc + ": " + s);
		//println("TRACE:" + s);
	}

	public static function memStat(?message : String = null) {
		var msg = if (message != null) message + ": " else "";
		#if flash
		println(msg + "Flash: Memory used: " + flash.system.System.totalMemory);
		#elseif neko
		println(msg + "Neko: Memory heap: " + neko.vm.Gc.stats().heap + "  free: " + neko.vm.Gc.stats().free);
		#end
	}

	public static inline function println(message: String) {
#if sys
		if (Options.DEBUG)
#end
		{
#if (flash || js)
			Errors.print(message);
#else
			Sys.println(message);
#end
		}
	}
}
