	import neko.vm.Thread;
/*
 Acceptance test for the optimiser.  There are two kinds of test:

   (1) tests(): test the optimised code generates the right output, &

   (2) testOptimiserOutput():  test the optimiser generates some specific code.  Only
       useful for small test programs, otherwise there will be too many spurious diffs
       from unimportant changes in the optimiser.

 All test cases must be in tests/pe/.  All generated files are in tests/pe/output/:
 .bytecode, .expected, .actual.  .actual & .bytecode are generated when the test is run;
 .expected must be present in svn.
 
 This code is rape n paste from Build.hx to get runJobs(), the ability to run jobs in
 parallel.
*/

class TestOptimiser {
	static var incremental = false;
	static var performance = false; // testing performance rather than correctness
	static var generalOpts = "";
	static var bytecodeOpts = "";
	static var nJobs = 4;
	public static function main() {
		var args = neko.Sys.args ();
		var i = 0;
		while (i < args.length) {
			var a = args [i++];
			switch (a) {
				case "--jobs": nJobs = Std.parseInt(args[i++]); 
				case "--incremental": bytecodeOpts += " " + a; incremental = true;
				case "--rebuild": bytecodeOpts += " " + a;
				case "--fast": bytecodeOpts += " " + a;
				case "--time-phases": generalOpts += " " + a;
				case "--disassembly": generalOpts += " " + a;
				case "--performance": performance = true;
				default:
					Sys.println ("Build.hx: dont' know how to handle " + a + " option");
					neko.Sys.exit(1);
			}
		}

		if (performance) {
			performanceTests(['deser', 'md5s', /*'lingoeditor',*/ 'learning']);
		} else {
			tests(['md5s', 'namecrap3', 'dynamicoptimisations', 'inttreetest', 'bintreetest'/*,
				   'lingoeditor'*/]);
			testOptimiserOutput(['namecrap2', 'namecapture', 'closure',
								 'perfbug', 'perfbug2', 'perfbug4', 'perfbug5',
								 'perfbug6', 'perfbug7', 'perfbug8', 'perfbug9', 'perfbug10',
								 'driveswitches']);
			// Note, a test case cannot be in both tests & testOptimiserOutput, since I reuse
			// the .actual & .expected files for them
		}
		neko.Sys.exit(0);
	}

	static function tests(ts : Array<String>) : Void {
		var compiles = [];
		var runs = [];
		for (t in ts) {
			var flow = 'tests/pe/' + t + '.flow';
			compiles.push(command('neko flow.n --bytecode ' + bytecode(t) + ' --optimise ' + flow + ' > ' + actual(t)));
			//runs.push(command('neko flowrunner.n ' + bytecode(t)));
		}
		pr('\ncompile & optimise & run & compare results:');
		runJobs(compiles);
		//pr('run tests:');
		//runJobs(runs);
		diffs(ts, function (f) {return 'tests/pe/output/' + f + '.out';});
	}

	static function testOptimiserOutput(ts : Array<String>) : Void {
		var compiles = [];
		for (t in ts) {
			var flow = 'tests/pe/' + t + '.flow';
			compiles.push(command('neko flow.n --debug --compile ' + bytecode(t) + ' --optimise ' + flow + ' > ' + actual(t)));
		}
		pr('\ncompile & optimise & compare code:');
		runJobs(compiles);
		//pr('diffing:');
		diffs(ts, function (f) {return 'tests/pe/output/' + f + '.opt';});
	}

	// mostly cut and paste of tests()
	static function performanceTests(ts : Array<String>) : Void {
		var compiles = [];
		var runs = [];
		for (t in ts) {
			var flow = 'tests/pe/' + t + '.flow';
			compiles.push(command('neko flow.n --runcount --bytecode ' + bytecode(t) + ' --optimise ' + flow + ' > ' + actual(t)));
			//runs.push(command('neko flowrunner.n ' + bytecode(t)));
		}
		pr('\noptimiser performance:');
		runJobs(compiles);
		//pr('run tests:');
		//runJobs(runs);
		diffs(ts, function (f) {return 'tests/pe/output/' + f + '.time';});
	}

	static function bytecode(t) {return 'tests/pe/output/o' + t + '.bytecode';}
	static function actual(t) {return 'tests/pe/output/' + t + '.actual';}
	
	static function diffs(ts : Array<String>, expected) : Void {
		for (t in ts) {
			diff(t, expected);
		}
	}

	// diff the actual file with the expected.  The name of the actual file is f.actual,
	// the name of the expected file is defined by the expected argument
	static function diff(t : String, expected : String -> String) : Void {
		var s1 = sys.io.File.getContent(actual(t));
		var s2 = sys.io.File.getContent(expected(t));
		if (s1 == s2) {
			pr(t + ':\tok');
		} else {
			pr('\n\n' + t + ':  FAILED');
			command('diff ' + actual(t) + ' ' + expected(t)).run();
		}
	}

	// Prepare a normal shell command
	static function command(p) : Job {
		var args = p.split(" ");
		return new Job(args[0], args.slice(1));
	}
	
	// This runs the steve jobs in parallel in two threads
	static function runJobs(jobs : Array<Job>) {
		// Create deque for passing the jobs
		var deque = new neko.vm.Deque<Job>();
		for (j in jobs) {
			deque.push(j);
		}
		
		var n = (if (incremental) 1 else nJobs);
		var threads = [];
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
				neko.Sys.exit(r);
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
		if (r == 0) {
			return run(jobs);
		} else {
			// OK, clear the queue
			Sys.stderr().writeString("ERROR: " + job.description());
			while (jobs.pop(false) != null) { }
			return r;
		}
	}

	static function pr(s) {
		Sys.println(s);
	}
}

// A simple class to represent a command to be run
class Job {
	public function new(command : String, args : Array<String>) {
		this.command = command;
		this.args = args;
	}
	public function run() : Int {
		// Sys.println(description());
		return neko.Sys.command(command, args);
	}
	public function description() : String {
		return command + " " + args.join(" ");
	}
	var command : String;
	var args : Array<String>;
}
