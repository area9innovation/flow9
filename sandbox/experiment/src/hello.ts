/// <reference types="../@types/test" />

// /// <reference path="../www/hello.js" />
// import "../www/hello.js";

var load = function() {
    test.foo();
    var encodedStr = "Test";
    var encoded = document.getElementById("encoded");
    
    if (encoded != null) {
        encoded.innerHTML = encodedStr;
    }

	function bar(a : number) : number {
		return 2 * a;
	}
	
}

