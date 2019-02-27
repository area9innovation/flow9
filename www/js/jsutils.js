// Functions from jscommon.js that are needed for custom.js
function mergePredefinedParams(result, predefined) {
	if (typeof predefined == "undefined") {
		return result;
	}
	var p = [];
	predefined.forEach(function(v, k, m) {
		p.push([k, v]);
	});

	var m1 = new Map(p.concat(result));
	p = [];
	m1.forEach(function(v, k, m) {
		p.push([k, v]);
	});
	return p;
}

function getUrlParameter(n, s) {
	var predefined = "";
	if (typeof predefinedBundleParams != "undefined") {
		if (predefinedBundleParams.has(n)) {
			predefined = predefinedBundleParams.get(n);
		}
	}

	//str is optional
	n = n.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]");
	var r = new RegExp("[\\?&]"+n+"=([^&#]*)").exec(s || window.location.href);
	return null == r ? predefined : r[1];
}
