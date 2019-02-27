// Functions from jscommon.js that are needed for custom.js
function mergePredefinedParams(result, predefined) {
	if (typeof predefined == "undefined") {
		return result;
	}
	return predefined.concat(result);

}

function getUrlParameter(n, s) {
	var predefined = "";
	if (typeof predefinedBundleParams != "undefined") {
		for (var i = 0; i < predefinedBundleParams.length; i++) {
			var item = predefinedBundleParams[i];
			if (i.length == 2 && item[0] == n) {
				predefined = item[1];
				break
			}
		}
	}

	//str is optional
	n = n.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]");
	var r = new RegExp("[\\?&]"+n+"=([^&#]*)").exec(s || window.location.href);
	return null == r ? predefined : r[1];
}
