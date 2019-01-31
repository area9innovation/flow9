
	// functions for test 
	function test5_0(i) { 
		return function(s1, f, res) {
			var str = s1 + '; ' + f(s1 + " add");
			res(str);
		}; 
	}
	function test5_1(f) {
		var f2 = f("test5_1 1");
		f2("test5_1 2");
	}
	function test5_2(f, res) { f(function(s) { res(s); }); }	
	function test5_3(f, dbl) { f(dbl + 0.5); }

