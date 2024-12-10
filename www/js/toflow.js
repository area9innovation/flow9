//
// Tools to communicate with flow code is here
// It should be included to HTMLs which embedded in a flow stage
//
function getURLParameter(name, str) { // str is optional
    return decodeURIComponent((new RegExp('[?|&]' + name + '=' + '([^&;]+?)(&|#|;|$)').exec(str || location.search)||[,""])[1].replace(/\+/g, '%20'))||null;
}

var is_cross_domain = is_cross_domain || document.readyState == 'complete' && is_flow_crossdomain();
var callflowBuffer = [];
var callflow = callflow || function (args){
    callflowBuffer.push(args);
	//alert("JS");
}
function pushCallflowBuffer(fn) {
	var call = fn || callflow;
    for (var i = 0; i < callflowBuffer.length; ++i) {
        call(callflowBuffer[i]);
    }
    callflowBuffer = [];
}

function define_cross_domain_once() {
	is_cross_domain = is_flow_crossdomain();
	 
	if (is_cross_domain) {
		for (var i = 0; i < callflowBuffer.length; ++i) {
			parent.postMessage(callflowBuffer[i][1], "*");
		}

		callflowBuffer = [];
	}
}

// native app on iOS devices
function callflow_ios_native(args) {
	var fake_href = "flow:::";
	// iOS WebView encodes some symbols, callFromFlowJS decodes it so we need to encode it here too for such strings to remain encoded: "mail%40domain.com"
	for (var i = 0; i < args.length; i++)  fake_href += encodeURI(args[i]) + (i + 1 == args.length ? "" : ":::");
	var iframe = document.createElement("iframe");
	iframe.setAttribute("src", fake_href);
	document.documentElement.appendChild(iframe);
	iframe.parentNode.removeChild(iframe);
	iframe = null;
}
function callflow_winapp(args) {
	var message = "";
	for (var i = 0; i < args.length; i++) message += (i>0?"\t":"") + args[i];
	window.external.notify(message);
}

function is_flow_ios_native() {
	return (navigator.userAgent.match(/(iPad|iPhone|iPod)/g) ||
			navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1 &&
			!window.MSStream) &&
		window.webkit && window.webkit.messageHandlers && window.parent == window;
}

function is_flow_qt() {
	return navigator.userAgent.indexOf("QtWebEngine") != -1 && window.parent == window;
}

function is_flow_android() {
	return navigator.userAgent.indexOf("Android") != -1 && window.parent == window;
}

function is_flow_winapp() {
	return navigator.userAgent.indexOf("Windows NT") != -1 &&
		navigator.userAgent.indexOf(".NET") != -1 &&
		navigator.userAgent.indexOf("WebView") != -1;
}

function callflow_platform(args) {
	if (is_flow_ios_native()) {
		callflow_ios_native(args);
	} else if ( (is_flow_qt() || is_flow_android()) && typeof flow !== 'undefined' && parent == window) {
		flow.callflow(args);
	} else if (is_flow_winapp()) {
		callflow_winapp(args);
	} else if (is_cross_domain) {
		parent.postMessage(JSON.stringify({ operation: "callflow", args }), "*");
	} else {
		callflow(args);
	}
}

function is_flow_crossdomain() {
	if (parent == null) return false;

	try {
		var top_href = parent.location.href;
		if (top_href == null) return true;
	} catch(e) {
		return true;
	}

	return false;
}

// Using postMessage to send an object to flow - will be serilized in JSON format if it not mentioned to avoid
function postToFlow(panel, avoidStringify) {
	avoidStringify = avoidStringify || false;
	var messageString = avoidStringify? panel : JSON.stringify(panel);
	if (is_cross_domain) {
		parent.postMessage(messageString, "*");
	} else {
		callflow_platform(["postMessage", messageString]);
	}
}

function openVideo(v1, v2) {
	console.log("openVideo: " + v1 + "; " + v2);
	callflow_platform(["openVideo"].concat([v1, v2]));
}

function registerLinkHandler(home_domains) {
	if ( home_domains != null ) {
		var args = ["setInnerDomainsWhiteList"].concat(home_domains);
		callflow_platform(args);
	}

	var args = ["setExternalDocuments"].concat([
		//documents
		"doc", "docx", "pdf", "rtf", 
		"odf", "odt", "ods", "odp", "odg",
		"dot", "pages", "xls", "xlsx", "xlsm", "sheets", "ppt", "pptx", "keynote", "txt"
	]);
	callflow_platform(args);

	document.addEventListener("click", function (e) {
		e = e || window.event;
		var element = e.target || e.srcElement;
		if (element.tagName == 'A') {
			//if link redirects on another domain that not contains in home_domain or by external_browser=1 or external_browser=2 URL parameter of link it should be opened in new tab in browser
			if (element.search.indexOf("external_browser") >= 0) {
				if (element.search.indexOf("external_browser=1") >= 0 || element.search.indexOf("external_browser=2") >= 0)
					element.target="_blank";
			}
			else if (element.hostname != document.domain && (home_domains == undefined ? true : home_domains.indexOf(element.hostname) < 0)) {
				element.target="_blank";
				if (is_flow_android() || is_flow_ios_native())
					if (element.search != "")
						element.search += "&external_browser=2";
					else
						element.search = "?external_browser=2";
			}
		}	
	});
}

function receiveMessageTest(e) {
	if (!e.data) return;
	try {
		var v = JSON.parse(e.data);
		if ((typeof(v) == "object") && (typeof(v.changeURL) == "object") && (typeof(v.changeURL.url) == "string")) {
			console.info("got command to change url : " + v.changeURL.url);
			document.location.href = v.changeURL.url;
		}
	} catch (e) {}
}

//to define if iframe.contentWindow.callflow was setted up correctly
window.addEventListener('load', define_cross_domain_once);
window.addEventListener('message', receiveMessageTest);
var toFlowInterval = setInterval(function(){ clearInterval(toFlowInterval); postToFlow({toFlowLoaded: {src: document.location.href}}) }, 300);


// SETTING UP QT STUFF

if (is_flow_qt()) {
	setQtChannel();
}

function setQtChannel() {
	loadScript("qrc:///qtwebchannel/qwebchannel.js", function() {
		new QWebChannel(qt.webChannelTransport, function (channel) {
			window.flow = channel.objects.flow;

			pushCallflowBuffer(callflow_platform);
		});
	});
}

function loadScript(url, callback) {
	var script = document.createElement("script")
	script.type = "text/javascript";
	if (script.readyState) {  //IE
		script.onreadystatechange = function() {
			if (script.readyState === "loaded" || script.readyState === "complete") {
				script.onreadystatechange = null;
				callback();
			}
		};
	} else {
		script.onload = function() {
			callback();
		};
	}

	script.src = url;
	document.getElementsByTagName("head")[0].appendChild(script);
}
