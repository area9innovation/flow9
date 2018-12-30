// Functions from jscommon.js that are needed for custom.js
function getUrlParameter(n, s) {
	//str is optional
	n = n.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]");
	var r = new RegExp("[\\?&]"+n+"=([^&#]*)").exec(s || window.location.href);
	return null == r ? "" : r[1];
}
