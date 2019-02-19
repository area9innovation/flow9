///
// Functions for browser and system capabilities detection
///

function getNavigatorLanguage() {
	return navigator.language;
}

function getOs() {
	if (navigator.appVersion.indexOf("Windows") != -1) {
		return "Windows,other";
	} else if ( (navigator.appVersion.indexOf("iPhone") != -1) || (navigator.appVersion.indexOf("iPad") != -1) ) {
		return "iOS,other";
	} else if (navigator.appVersion.indexOf("Android") != -1) {
		return "Android,other";
	} else if (navigator.platform.indexOf("Mac") != -1) {
		return "MacOSX,other";
	} else {
		return "other,other";
	}
}

function getUserAgent() {
	return navigator.userAgent;
}

function getBrowser() {
	return BrowserDetect.browser + " " + BrowserDetect.version;
}

function getVersion() {
	return ""; // Stub for getVersion from js/flowswf.js
}

function getResolution() {
	return screen.width + "x" + screen.height;
}

var BrowserDetect = {
	init: function () {
		this.browser = this.searchString(this.dataBrowser) || "An unknown browser";
		this.version = this.searchVersion(navigator.userAgent)
			|| this.searchVersion(navigator.appVersion)
			|| "an unknown version";
		this.OS = this.searchString(this.dataOS) || "an unknown OS";
	},
	searchString: function (data) {
		for (var i=0;i<data.length;i++) {
			var dataString = data[i].string;
			var dataProp = data[i].prop;
			this.versionSearchString = data[i].versionSearch || data[i].identity;
			if (dataString) {
				if (dataString.indexOf(data[i].subString) != -1)
					return data[i].identity;
			}
			else if (dataProp)
				return data[i].identity;
		}
	},
	searchVersion: function (dataString) {
		var index = dataString.indexOf(this.versionSearchString);
		if (index == -1) return;
		return parseFloat(dataString.substring(index+this.versionSearchString.length+1));
	},
	dataBrowser: [
		{
			string: navigator.userAgent,
			subString: "Chrome",
			identity: "Chrome"
		},
		{   string: navigator.userAgent,
			subString: "OmniWeb",
			versionSearch: "OmniWeb/",
			identity: "OmniWeb"
		},
		{
			string: navigator.vendor,
			subString: "Apple",
			identity: "Safari",
			versionSearch: "Version"
		},
		{
			prop: window.opera,
			identity: "Opera",
			versionSearch: "Version"
		},
		{
			string: navigator.vendor,
			subString: "iCab",
			identity: "iCab"
		},
		{
			string: navigator.vendor,
			subString: "KDE",
			identity: "Konqueror"
		},
		{
			string: navigator.userAgent,
			subString: "Firefox",
			identity: "Firefox"
		},
		{
			string: navigator.vendor,
			subString: "Camino",
			identity: "Camino"
		},
		{       // for newer Netscapes (6+)
			string: navigator.userAgent,
			subString: "Netscape",
			identity: "Netscape"
		},
		{
			string: navigator.userAgent,
			subString: "MSIE",
			identity: "Explorer",
			versionSearch: "MSIE"
		},
		{
			string: navigator.userAgent,
			subString: "Gecko",
			identity: "Mozilla",
			versionSearch: "rv"
		},
		{       // for older Netscapes (4-)
			string: navigator.userAgent,
			subString: "Mozilla",
			identity: "Netscape",
			versionSearch: "Mozilla"
		}
	],
	dataOS : [
		{
			string: navigator.platform,
			subString: "Win",
			identity: "Windows"
		},
		{
			string: navigator.platform,
			subString: "Mac",
			identity: "Mac"
		},
		{
			string: navigator.userAgent,
			subString: "iPhone",
			identity: "iPhone/iPod"
		},
		{
			string: navigator.platform,
			subString: "Linux",
			identity: "Linux"
		}
	],
};
BrowserDetect.init();


function getUrlParameter(name, str) { //str is optional
  name = name.replace(/[\[]/,"\\\[").replace(/[\]]/,"\\\]");
  var regexS = "[\\?&]"+name+"=([^&#]*)";
  var regex = new RegExp( regexS );
  var results = regex.exec( str || window.location.href );
  if( results == null )
    return "";
  else
    return results[1];
}

var leaveWarningText = undefined;
window.onbeforeunload = function() {
	try {
		var newWarningText = flow_onbeforeunload();
		leaveWarningText = (newWarningText && newWarningText != "") ? newWarningText : undefined;
	} catch(e) {
		console.log("no flow_onbeforeunload() callback installed");
	}
	return leaveWarningText;
}

window.setLeaveWarningText = function(message) {
	// null, undefined -> undefined
	leaveWarningText = (message == null) ? undefined : message;
}
