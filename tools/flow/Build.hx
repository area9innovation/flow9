import neko.vm.Thread;
import Sys;
import sys.io.File;

typedef Task = {dst:String, src:String, opt:String};


class Build {
	static var incremental = true;
	static var generalOpts = "";
	static var bytecodeOpts = "";
	static var swfOpts = "";
	static var jsOpts = "";
	static var nJobs = 3;
	static var noNice = false;
	static var batchCompilation = true;
	static var swfBatchCompilation = false;
	static var quick = false;
	public static var noStop = false;
	public static var dry = false;
	// A list of targets to compile, or empty to compile all
	static var filter = [];
	static var filterTypes = [];

	static var windows = false;
	static var flow = "flow";

	public static function main() {

		windows = Sys.systemName() == "Windows";
		if (windows) {
			flow = "flow.bat";
		}

		var args = Sys.args ();
		var i = 0;
		while (i < args.length) {
			var a = args [i++];
			switch (a) {
			case "--jobs": nJobs = Std.parseInt(args[i++]);
			case "--incremental": incremental = true;
			case "--no-incremental": incremental = false;
			case "--batch": batchCompilation = true;
			case "--no-batch": batchCompilation = false;
			case "--batch-swf": swfBatchCompilation = true;
			case "--no-batch-swf": swfBatchCompilation = false;
			case "--rebuild": bytecodeOpts += " " + a;
			case "--quick": quick = true;
			case "--optimise":
				bytecodeOpts += " " + a;
				swfOpts += " " + a;
				jsOpts += " " + a;
			case "--inline-limit"	 :
				if (i < args.length) {
					var n = '	--inline-limit ' + args [i++];
					bytecodeOpts += n;
					swfOpts += n;
					jsOpts += n;
				}
			case "--time-phases": generalOpts += " " + a;
			case "--disassembly": generalOpts += " " + a;
			case "--dce": generalOpts += " " + a;
			case "--deps": generalOpts += a;
			case "--no-deps":	generalOpts += a;
			case "--dry-run":	dry = true;
			case "--no-stop":	noStop = true; generalOpts += " " + a;
			case "--no-nice":	noNice = true;
			case "--help"	 : printHelp(); Sys.exit(0);
			default:
				if (StringTools.startsWith(a, "-")) {
					Sys.println("Build.hx: don't know how to handle " + a + " option: to get list options use --help ");
					Sys.exit(1);
				} else {
					var split = a.split(".");
					if (split.length > 1) {
						filterTypes.push("." + split[1]);
					}
					filter.push(split[0]);
				}
			}
		}

		if (!windows && !noNice) {
			var load = getLoad();
			if (load > 5.0) {
				Sys.stderr().writeString("Build.hx: Load is too high: " + load + "\n");
				Sys.exit(1);
			}
		}

		if (incremental) {
			bytecodeOpts += " --incremental";
		}

		if (filter.length == 0) {
			Sys.setCwd("src");
			runJobs([ // [command("haxe FlowFlash.hxml", true)],
					  [command("haxe FlowNeko.hxml", true)],
					  // [command("haxe FlowJs.hxml", true)],
					  //  [command("haxe FlowCpp.hxml", true)   broken as of 25 Aug 2014
					  // [command("haxe FlowRunner.hxml", true)]
			]);
			Sys.setCwd("..");
		}

		var jobs = [];
		var bytes = [];
		var batch = [];

		var swfBatches = [];
		for (i in 0 ... 8) {
			swfBatches.push([]);
		}
		var swfInd = 0;
		var getSwfBatch = function() {
			var res = swfBatches[swfInd];
			swfInd = (swfInd + 1) % swfBatches.length;
			return res;
		}

		var compile = function (target : String, path : String, server : Bool) {
			var suffix = (if (server) ".serverbc" else ".bytecode");
			if (filteredOut(target, suffix)) return;
			if (incremental && batchCompilation)
				batch.push({dst:target + suffix + " ", src:endWith(path, ".flow"), opt:""});
			else if (incremental)
				bytes.push(compile2bytecode(target, path, server));
			else
				jobs.push([compile2bytecode(target, path, server)]);
		}

		{
			// The unit tests
			var files = [ "flowunit/flowunit_flash.flow" ];
			files.reverse();
			for (f in files) {
				// The directory
				var dir = f.substr(0, f.lastIndexOf("/"));
				// And the last one is the name of the bytecode
				var lastdir = dir.substr(dir.lastIndexOf("/") + 1);
				compile(lastdir, f, false);
			}
		}

		var compileJs = function (target : String, path : String) {
			if (!filteredOut(target, ".js")) {
				jobs.push([compile2js(target, path)]);
			}
		}

		var compileCpp = function (target : String, path : String) {
			if (!filteredOut(target, ".cpp")) {
				jobs.push([compile2cpp(target, path)]);
			}
		}


		compile("mushroom", "sandbox/mushroom/mushroom", false);
		compile("formdesigner", "lib/formdesigner/formdesigner", false);
		compile("tropify", "tools/tropify/tropify", false);
		compile("test_wigi", "lib/wigi/test_wigi", false);

		if (filter.length == 0) {
			jobs.push([unittest("flowunit_test", "flowunit/flowunit_test")]);
		}

		var makeBatch = function(batch: Array<Task>) {
			var files = new StringBuf();
			for (tgt in batch) {
				if (sys.FileSystem.exists(tgt.src)) {
					files.add(tgt.dst);
					files.add(tgt.src);
					files.add(" ");
				} else {
					Sys.println("--- Skipping " + tgt.dst);
				}

			}
			return files.toString();
		};
		if (swfBatchCompilation) {
			var i = 1;
			for (swfBatch in swfBatches) {
				if (swfBatch.length != 0) {
					var cmd = command(flow + " --prefix \"SWF" + (if (swfBatches.length == 1) "" else ("#" + i++)) + ": \" --share-strings "
														+ swfOpts + generalOpts + " "
														+ "--batch-compile-swf " + makeBatch(swfBatch));
					jobs.push([cmd]);
				}
			}
		}
		if (incremental) {
			if (batchCompilation) {
				if (batch.length != 0) {
					batch.reverse();
					var n = 15; // Split into bundles to avoid memory overflow
					var batches = Math.ceil(batch.length / n);
					for (i in 0...batches) {
						var b = batch.slice(i * n, i * n + n);
						var cmd = command(flow + " --prefix \"Bc: \" "
															//+ (if (sharedStrings != null) "--share-strings " else "")
															+ "--share-strings "
															+ bytecodeOpts + " " + generalOpts + " "
															+ "--batch-compile " + makeBatch(b));
						jobs.push([cmd]);
					}
				}
			} else {
				bytes.reverse();
				jobs.push(bytes);
			}
		}

		// Run them in parallel
		runJobs(jobs);
		Sys.exit(0);
	}

	static function filteredOut(target : String, targetType : String) : Bool {
		if (filter.length != 0) {
			for (f in filter) {
				if (target == f) {
					if (filterTypes.length != 0) {
						for (ft in filterTypes) {
							if (ft == targetType) {
								return false;
							}
						}
					} else {
						return false;
					}
				}
			}
			return true;
		} else {
			return false;
		}
	}

	public static function printHelp () {
		Sys.println("Usage: build.n [options] <target> ... <target>

If one or more targets are listed, only those targets are compiled.

Options:
--help           Print this help
--time-phases    Print info about how long the compiler phases take
--quick          Only compile to bytecode. Useful to check for compile errors
--optimise            Aggressively optimise the code to bloat.
  --inline-limit N    When is a function too big to inline? Default is 42
--incremental   Turn on separate compilation mechanism. For bytecode compilation only: default is 'on'
--no-incremental   Turn off separate compilation mechanism. For bytecode compilation only
--batch-compile  bytecode-file flow-source-file ....
--disassembly   Disassembly bytecode
--jobs n        Maximum # of parallel jobs, default is 4
--no-stop       Keep build running after error
--dry-run       Don't actually run jobs, print commands only
--no-nice       Run at default system priority
");
	}

	public static function getLoad() : Float {
		// Get the 1 minute average load
		var avg = getProcessOutput("cat /proc/loadavg | awk '{print $1}'");
		if (avg != null) {
			return Std.parseFloat(avg);
		} else {
			return 0.0;
		}
	}

	public static function getProcessOutput(cmd) : String {
		try {
			var p = new sys.io.Process('bash', ['-c', cmd]);
			if (p.exitCode() == 0) {
				return p.stdout.readLine();
			} else {
				return null;
			}
		} catch (e: Dynamic) {
			//can't create process
			return null;
		}
	}

	// Prepare a normal shell command
	static function command(p, ?trace = false) : Cmd {
		if (!windows && !noNice) {
			p = "nice " + p;
		}
		var args = p.split(" ");
		return new Cmd(args[0], args.slice(1), trace);
	}

	// Prepare a compilation of a flow program to flow bytecode
	static function compile2bytecode(target : String, path : String, server : Bool) : Cmd {
		return command(flow + " --share-strings "
									 + bytecodeOpts + " " + generalOpts + " "
									 + "--compile " + target +
									 (if (server) ".serverbc " else ".bytecode ")
									 + endWith(path, ".flow")
									 );
	}

	// Prepare a compilation of a flow program to JS
	static function compile2js(target : String, path : String) : Cmd {
		return command(flow + " "
			 + "--js " + target + ".js " + jsOpts + " "
			 + endWith(path, ".flow")
			 );
	}

	static function compile2cpp(target : String, path : String) : Cmd {
		return command(flow + " "
			 + "--cpp " + target + " --dontrun " + endWith(path, ".flow")
			);
	}

	// Prepare a compilation of a flow program to a SWF file
	static function compile2swf(target : String, path : String, batch : Array<Task>) : Array<Cmd> {
		if (filteredOut(target, ".swf")) return [];
		if (swfBatchCompilation) {
			batch.push({dst:target + ".swf ", src:endWith(path, ".flow"), opt:("")});
			return [];
		}
		return [command(flow + " "
						+ swfOpts + " " + generalOpts + " "
						+ "--swf " + target + ".swf "
						+ endWith(path, ".flow")
		)];
	}

	static function unittest(target : String, path : String) : Cmd {
		return command("flowcpp --batch " + endWith(path, ".flow") + " -- test=true");
	}

	// Find all files matching a given pattern
	static function findFiles(path : String, pattern : String, files : Array<String>) : Void {
		try {
			var filesAndDirs = sys.FileSystem.readDirectory(path);
			for (f in filesAndDirs) {
				try {
					var file = path + "/" + f;
					if (StringTools.startsWith(f, ".")) {
						// Ignore these
					} else if (sys.FileSystem.isDirectory(file)) {
						findFiles(file, pattern, files);
					} else {
						if (f == pattern) {
							files.push(file);
						}
					}
				} catch (e : Dynamic) {
				}
			}
		}
		catch (e : Dynamic) {
		}
	}

	static function endWith(path : String, suffix : String) : String {
		return if (StringTools.endsWith(path, suffix)) path else path + suffix;
	}

	// This runs the given jobs in parallel in two threads
	static function runJobs(vcmds : Array<Array<Cmd>>) {
		// Create deque for passing the jobs
		var deque = new neko.vm.Deque<Job>();
		for (cmds in vcmds) {
			if (cmds.length != 0) {
				deque.push(new Job (cmds));
			}
		}

		var threads = [];
		var n = nJobs;
		for (i in 0...n) {
			threads.push(Thread.create(waitForWork));
		}
		for (t in threads) {
			t.sendMessage(Thread.current());
			t.sendMessage(deque);
		}

		for (t in threads) {
			var r = Thread.readMessage(true);
			if (r != 0) {
				Sys.exit(r);
			}
		}
	}

	// Start a thread, and let it wait for the id of the main thread and a job list
	static function waitForWork() {
		var main : Thread = Thread.readMessage(true);
		var deque = Thread.readMessage(true);
		main.sendMessage(run(deque));
	}

	// Do the first item in a job list
	static function run(jobs : neko.vm.Deque<Job>) : Int {
		var job = jobs.pop(false);
		if (job == null) {
			return 0;
		}
		var r = job.run();
		if (noStop || r == 0) {
			return run(jobs);
		} else {
			// OK, clear the queue
			Sys.stderr().writeString("ERROR: " + job.description() + "\n");
			while (jobs.pop(false) != null) { }
			return r;
		}
	}
}

// A simple class to represent a command to be run
class Job {
	public function new(commands : Array<Cmd>) {
		this.commands = commands;
		this.errCommand = "";
	}
	public function run() : Int {
		var res = 0;
		for (c in commands) {
			var ret = c.run();
			if (ret != 0) {
				errCommand = c.description();
				if (!Build.noStop)
					return ret;
				if (res <= ret)
					res = ret;
			}
		}
		return res;
	}
	public function description() : String { return errCommand; }
	var commands : Array<Cmd>;
	var errCommand : String;
}

class Cmd {
	public function new(command : String, args : Array<String>, ?needTrace : Bool = false) {
		this.command = command;
		this.args = args;
		this.needTrace = needTrace;
	}
	public function run() : Int {
		if (Build.dry || needTrace) Sys.println(description());
		return if (Build.dry) 0 else Sys.command(command, args);
	}
	public function description() : String {
		return command + " " + args.join(" ");
	}
	var command : String;
	var args : Array<String>;
	var needTrace : Bool;
}
