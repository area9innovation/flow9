///
// Functions for browser and system capabilities detection
///

var URL_RE = new RegExp(
	 // Match #0 — href
	"^" +

	 // Match #2 — proto
	"(([a-z]{3,}):)?" +

	// Match #3-#6 — domain and port:
	// #3 — host with heading double slash, #4 — without (origin),
	// #5 — host name, #6 — port.
	"(" +
		"//(([^:/\\?#]*)(?::([^/\\?#]*))?)" +
	")?" +

	// Match #7 — path at the site.
	"([^\\?#]*)" +

	// Match #9 — ampersand-separated parameters.
	"(\\?([^#]*))?" +

	// Match #11 — hash or search string, whatever term preferred.
	"(#(.*))?" + "$"
);
var SCRIPT_NAME_RE = new RegExp("^((?:[a-z](?:\\d|[a-z]|_)*)(?:\/[a-z](?:\\d|[a-z]|_)*)*)$");

function parseUrl(s) {
	s = s || this.href;
	var parts = URL_RE.exec(s);
	return {
		href: parts[0] || "",
		protocol: parts[2] || "",
		origin: parts[4] || "",
		hostname: parts[5] || "",
		port: parts[6] || "",
		path: parts[7] || "/",
		paramStr: parts[9] || "",
		hash: parts[11] || ""
	}
}

function PermissionDeniedError(message) {
	this.name = "PermissionDeniedError";
	this.message = message;
	var error = new Error(this.message);
	error.name = this.name;
	this.stack = error.stack;
}
PermissionDeniedError.prototype = Object.create(Error.prototype, {});

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
			subString: "Trident",
			identity: "Explorer",
			versionSearch: "rv"
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


///
// Load external CSS/JS dynamically
///
function loadJSFile(url) {
	var head = document.getElementsByTagName('head')[0];
	var node = document.createElement('script');
	node.setAttribute("type","text/javascript");
	node.setAttribute("src", url);
	head.appendChild(node);
}

function loadJSFileInternal(url) {
	var urlObj = parseUrl(url);
	if (urlObj.origin) throw new PermissionDeniedError("External script loading is not allowed.");
	var name=urlObj.path.slice(0,  urlObj.path.length-3);
	var ext=urlObj.path.slice(-3);
	if (ext != ".js" || !SCRIPT_NAME_RE.test(name)) throw new PermissionDeniedError("Invalid script path.");
	return loadJSFile(url);
}

function loadCSSFile(url) {
	var head = document.getElementsByTagName('head')[0];
	var node = document.createElement("link");
	node.setAttribute("rel", "stylesheet");
	node.setAttribute("type", "text/css");
	node.setAttribute("href", url);
	head.appendChild(node);
}

function loadCSSFileInternal(url) {
	var urlObj = parseUrl(url);
	if (urlObj.origin) throw new PermissionDeniedError("External style loading is not allowed.");
	return loadCSSFile(url);
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
	loadCSSFileInternal("flowjspixi.css");
}

var overlayLoadTimestamp = "";
function loadJSOverlay(name) {
	loadJSFileInternal(name + ".js" + overlayLoadTimestamp);
}

var scriptName;
if (scriptName == null) scriptName = getUrlParameter("name");
if (scriptName == "") scriptName = getUrlParameter("name", window.urlParameters);

var slave = getUrlParameter("slave");

if (scriptName == "ereader") {
	loadJSFileInternal("js/toflow.js");
	loadJSFileInternal("smartbook/js/container_helper.js");
} 

var scormParam = getUrlParameter("scormAPI");
if (scormParam != "") {
	loadJSFileInternal("js/scormapi.js")
}

if (scriptName.length > 4 && scriptName.substring(0, 4) == "http") {
	loadJSFileInternal("js/toflow.js");
	loadJSFileInternal("js/websoftware.js");
}

if (!window.location.pathname.endsWith(".html")) {
  if (scriptName != "") {
    if (slave != "") {
      loadJSFileInternal("js/toflow.js");
      window.addEventListener('message', function (e) {
	h = e.data;
	window.location.hash = (h[0] != '#') ? h : h.substring(1);
      });

      loadJSFileInternal(scriptName + ".js?" + slave);
      loadExternalResources();
    } else {
      var xmlhttp = new XMLHttpRequest();
      xmlhttp.onreadystatechange = function () {
	if (this.readyState == 4 && this.status == 200) {
	  try {
	    var timestamp = this.responseText;
	    overlayLoadTimestamp = "?" + timestamp;
	    loadFavicon("icons/" + scriptName + ".ico");
	    loadJSFileInternal(scriptName + ".js?" + timestamp);
	    loadExternalResources();
	  }
	  catch(exception) {
	    document.body.appendChild(document.createTextNode(exception.message));
	  }
	}
      }
      xmlhttp.open("GET", "php/stamp.php?t=" + Date.now() + "&file=" + scriptName + ".js", true);
      xmlhttp.send();
    }
  } else {
    document.body.appendChild(document.createTextNode("Use 'name' URI parameter to run corresponding flow app"));
  }
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
