var leaveWarningText = "";

function getNavigatorLanguage() {
	return navigator.language;
}

function loadJSFile(url) {
	var head = document.getElementsByTagName('head')[0];
	var node = document.createElement('script');
	node.setAttribute("type","text/javascript");
	node.setAttribute("src", url);
	head.appendChild(node);
}

function loadCSSFile(url) {
	var head = document.getElementsByTagName('head')[0];
	var node = document.createElement("link");
	node.setAttribute("rel", "stylesheet");
	node.setAttribute("type", "text/css");
	node.setAttribute("href", url);
	head.appendChild(node);
}

function loadFavicon(url) {
	var head = document.getElementsByTagName('head')[0];
	var node = document.createElement('link');
	node.setAttribute("rel", "shortcut icon");
	node.setAttribute("type", "image/ico");
	node.setAttribute("href", url);
	head.appendChild(node);
}

function loadExternalResources() {
	loadJSFile("https://use.typekit.com/hfz6ufz.js");
	loadCSSFile("flowjs.css");
}

var overlayLoadTimestamp = "";
function loadJSOverlay(name) {
	loadJSFile(name+".js"+overlayLoadTimestamp);
}

function setLeaveWarningText(text) {
	leaveWarningText = text;
}

function pausecomp(millis) {
	var date = new Date();
	var curDate = null;

	do { curDate = new Date(); }
	while(curDate-date < millis);
}

window.onbeforeunload = function () {
	if (leaveWarningText != "")
		return leaveWarningText;
}

function closeWindow() {
	close();
}

function setDocumentDomain(domain) {
    document.domain = domain;
}

function getOs() {
	if (navigator.appVersion.indexOf("Windows") != -1) {
		return "Windows,other";
	} else if ( (navigator.appVersion.indexOf("iPhone") != -1) || (navigator.appVersion.indexOf("iPad") != -1) ) {
		return "iOS,other";
	} else if (navigator.appVersion.indexOf("Android") != -1) {
		return "Android,other";
	} else if (navigator.appVersion.indexOf("Mac OS") != -1) {
		return "MacOSX,other";
	} else {
		return "other,other";
	}
}

function getUserAgent() {
	return navigator.userAgent;
}

function getBrowser() {
	BrowserDetect.init();
	return BrowserDetect.browser + " " + BrowserDetect.version;
}

function getResolution() {
	return screen.width + "x" + screen.height;
}

function getURLParameter(name, str) { // str is optional
    return decodeURIComponent((new RegExp('[?|&]' + name + '=' + '([^&;]+?)(&|#|;|$)').exec(str || location.search)||[,""])[1].replace(/\+/g, '%20'))||null;
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
	]
};
BrowserDetect.init();

function arrayContains(a, obj) {
    var i = a.length;
    while (i--) {
       if (a[i] === obj) {
           return true;
       }
    }
    return false;
}

function getLocationHash() { 
    return window.location.hash; 
} 
