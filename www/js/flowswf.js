// This files checks for Flash version, launches JS version if swf is not present
// parses and adds some URL parameters

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

window.onload = function() {
	// flash.focus() breakes textboxes for FF on Mac OS X
	if (swfobject.ua.mac && navigator.userAgent.toLowerCase().indexOf('firefox') > -1) return;

	var flash = document.getElementById("flowFlash");
	if (typeof(flash) != "undefined" && typeof(flash) != null && flash != null) {
		flash.tabIndex = 1234;  // This was needed on Chrome 23
		flash.focus();
	}
}

window.onbeforeunload = function () {
	try {
		var flash = getFlash();
			var param = flash.onbeforeunload();
	        if ( typeof param == "string" ) {
				setLeaveWarningText(param);
		} else if (param)
			pausecomp(3000);

	} catch(err) { }

	if (leaveWarningText != "")
		return leaveWarningText;
}

function getFlash() {
	return document.getElementById("flowFlash");
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

function getVersion() {
	var playerVersion = swfobject.getFlashPlayerVersion(); 
	return playerVersion.major + "." + playerVersion.minor + "." + playerVersion.release;
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

function startJSversion() {
	if (window.location.href.indexOf("flowswf.html") > 0)
 		window.location.href = window.location.href.replace("flowswf.html", "flowjs.html");
	else if ( window.location.href.indexOf("ereaderlti_provider.php") > 0)		
		window.location.href = window.location.href.replace("ereaderlti_provider.php", "flowjs.html");
}
var splashName = "splash.swf?v=8";

function replaceSwfWithEmptyDiv(targetID){
   var el = document.getElementById(targetID);
   if(el){
      var div = document.createElement("div");
      el.parentNode.insertBefore(div, el);
      swfobject.removeSWF(targetID);
      div.setAttribute("id", "myAlternativeContent");
   }
}

function switchToSB(skip) {
    replaceSwfWithEmptyDiv("flowFlash");
	var url = window.location.href;
	url = url.replace("?name=learnsmart", "?name=smartbook");
	if (skip == "true") url = url.concat("&skipredirect=once");
	window.history.replaceState("","", url);
	startSWFversion()
}

function switchToLS(skip) {
    replaceSwfWithEmptyDiv("flowFlash");
	var url = window.location.href;
	url = url.replace("?name=smartbook", "?name=learnsmart");
	if (skip == "true") url = url.concat("&skipredirect=once");
	window.history.replaceState("","", url);
	startSWFversion()
}

function arrayContains(a, obj) {
    var i = a.length;
    while (i--) {
       if (a[i] === obj) {
           return true;
       }
    }
    return false;
}

function startSWFversion() {
	var flashvars = {};
	startSWFversionWithPreParams(flashvars)
}

function startSWFversionWithPreParams(flashvars) {
	var strHref = window.location.href;
	var prod = getURLParameter("prod");
	var source = getURLParameter("source");
	if (strHref.indexOf("?") > -1) {
		var qIndex = strHref.indexOf("?") + 1;
		var hIndex = strHref.lastIndexOf("#");
		var strQueryString = (hIndex != -1)
			? strHref.substr(qIndex, hIndex - qIndex)
			: strHref.substr(qIndex);
		var aQueryString = strQueryString.split("&");
		for ( var iParam = 0; iParam < aQueryString.length; iParam++ ) {
			var aParam = aQueryString[iParam].split("=");
			flashvars[aParam[0]] = aParam[1];
		}
	}

	flashvars["originalHtmlUrl"] = encodeURIComponent(window.location.href);
	var swf = flashvars["name"];
	var params = {"allowFullScreen":"true", "allowscriptaccess" : "always", "wmode": "opaque"};
	if (strHref.toLowerCase().indexOf("directwmode") > -1) {
		params = {"allowFullScreen":"true", "allowscriptaccess" : "always", "wmode": "direct"};
	}
	var attributes = {};
	attributes.id = "flowFlash";

	if (getURLParameter("custom_splash") != null) splashName = getURLParameter("custom_splash") + ".swf";
	if (getURLParameter("custom_splash_image") != null) splashName = "splash_ci.swf";
	var nejmProducts = ['IM', 'IMTEST', 'FM', 'FMTEST', 'PD', 'PDTEST'];

	if (prod != null && arrayContains(nejmProducts, prod.toUpperCase())) splashName = "images/NEJM/nejmsplash.swf";	
	var splashAbs = "false";
	var runProduct = function() {
		flashvars["splashAbs"] = splashAbs;
		if (swfobject.hasFlashPlayerVersion("9.0.18")) { // Flash 9 or above
			swfobject.embedSWF(splashName, "myAlternativeContent", "100%", "100%", "11.0.0", "expressInstall.swf", flashvars, params, attributes);
			var flash = null;
			$(document).mousewheel(function(event, delta, dx, dy) {
				//console.log(dx, dy);
				if (flash == null) {
					if (navigator.appName.indexOf("Microsoft") != -1) {
						flash = window[attributes.id];
					} else {
						flash = document[attributes.id];
					}
				}
				if (flash != null) {
					flash.onJsScroll(-dx, dy);
				}
			});
		} else if (prod != null && arrayContains(nejmProducts, prod.toUpperCase())) {
			// window.location.hostname == "myknowledgeplus.nejm.org"
			var suffix = "_" + prod.substring(0, 2).toLowerCase();
			if (arrayContains(['iPad', 'iPhone', 'iPod'], navigator.platform)) 
				if (window.location.search.indexOf("testmobileredirect=1") > -1) {
					var mobStr = navigator.platform == 'iPad' ? "" : "&mobile=1";
					window.location.href = window.location.origin + "/flow/flowjspixi.html" + window.location.search + mobStr;
				} else window.location.replace("nejm_getFromAppstore" + suffix + ".html");
			else if (navigator.userAgent.toLowerCase().indexOf("android") > -1)
				startJSversion();
			else
				window.location.replace("nejm_noflash.html");
		} else if (source == "ramboll_csr_t") {
			window.location.replace("ramboll_noflash.html");
		} else {
			// No flash. Use native JS
			startJSversion();
		}
	}
	// var findCustomSplash = getURLParameter("source") != null && getURLParameter("name") == "binrunner";
	var nameParam = getURLParameter("name");
	var sourceParam = getURLParameter("source");
	var isbnParam = getURLParameter("isbn");
	var isBinrunner = nameParam == "binrunner";
	var isLmsHardcoded = getURLParameter("lms");
	var isLms = (nameParam != null) && ((nameParam.substr(0, 3) == "lms") || (nameParam == "proficiency_graph" && isLmsHardcoded == "1"));
	var challengetoken = getURLParameter("challengetoken");

	var checkBinrunnerCustomSplash = isBinrunner && (sourceParam != null || challengetoken != null);
	var checkLmsCustomSplash = isLms && isbnParam != null;
	
	var checkCustomSplash = checkBinrunnerCustomSplash || checkLmsCustomSplash;
	if (checkCustomSplash) {
		params.operation = "get_custom_splash_screen"; //#41434 - do not reset allowFullScreen
		if (checkBinrunnerCustomSplash) {
			params.source = sourceParam;
		} else if (checkLmsCustomSplash) {
			params.isbn = isbnParam;
		}
		params.challenge_token = challengetoken;
		$.post('smartbuilder/php/db.php', params, function(data) {
			if (data.length >= 3 && data.substr(0, 3) == "OK\n") {
				splashName = "splash_ci.swf";
				splashImageName = data.substr(3, data.length - 3);
				splashAbs = "true";
				flashvars["custom_splash_image"] = splashImageName;
				runProduct();
			} else {
				runProduct();
			}
		})
		.fail(function() {
			runProduct();
		});
	} else {
		runProduct();
	}
}

function getLocationHash() { 
    return window.location.hash; 
} 
