// Functions from jscommon.js that are needed for custom.js
function mergePredefinedParams(result, predefined) {
	if (typeof predefined == "undefined") {
		return result;
	}
	return Array.from(new Map([...Array.from(predefined), ...result]));
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
