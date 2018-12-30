
	// functions for test 
	function test5_0(i) { 
		return function(s1, s2, i1) {
			console.log(s1 + '; ' + s2 + '; ' + i1);
		}; 
	}
	function test5_1(i) { 
		return function(s1, f) {
			console.log(s1 + '; ' + f(s1 + " add"));
		}; 
	}
	function test5_2(cb) {
		console.log(cb("fromjs ")); 
	}
	function test5_3(f) { f(function(s) { console.log(s); }); }
	function test5_4(f, dbl) { f(dbl + 0.5); }
	function test5_5(f) {
		f2 = f("test5_5 1");
		f2("test5_5 2");
	}
