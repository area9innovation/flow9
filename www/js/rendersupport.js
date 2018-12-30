//
// This file contains some proxy functions to control DOM

//
// These functions are used by flash RenderSupport to get access to DOM

function setWindowTitle(t) { document.title = t; }

function setFavIcon(url) {
		var head = document.getElementsByTagName('head')[0];
		var oldNode = document.getElementById('dynamic-favicon');
		var node = document.createElement('link');
		node.setAttribute("id", "dynamic-favicon");
		node.setAttribute("rel", "shortcut icon");
		node.setAttribute("href", url);
		node.setAttribute("type", "image/ico");
		if (oldNode != null) {
			head.removeChild(oldNode);
		}
		head.appendChild(node);
}

function randomString(length) {
	var letters = "abcdefghijklmnopqrstuvwxyz0123456789";
	var n = letters.length;
	var build = "";
	for (var i = 0; i < length; ++i) {
		build += letters.charAt(Math.floor(Math.random() * n));
	}
	return build;
}

 function getReloadBlockId(id) {
 	return id + "_reload";
 }

 function makeReloadBlock(iframeRoot, iframe, url) {
 	try {

 		var div = document.createElement("div");
 		div.style.position = "absolute";
 		div.style.zIndex = 101;
 		div.style.top = "0px";
 		div.style.right = "0px";
 		div.style.width = "30px" 
 		div.style.height = "30px"
 		//div.style.border = "1px solid #FF0000";
 		div.style.opacity = "0.6";

 		var img = document.createElement("img");
 		img.src = "images/lms_reload.png";
 		img.style.height = "20px"
 		img.style.width = "20px"
 		img.style.padding = "5px"
 		img.style.background = "#BEBEBE";

 		div.appendChild(img);

 		var div2 = document.createElement("div");
 		div2.style.position = "absolute";
 		div2.style.zIndex = 102;
 		div2.style.top = "0px";
 		div2.style.left = "0px"; 	
 		div2.style.width = "100%";
 		div2.style.height = "30px"
 		//div2.style.border = "1px solid #0000FF";
 		div2.style.background = "linear-gradient(to bottom right, #36372F, #ACA9A4)";
 		div2.style.opacity = "0.6";
 		div2.style.display = "none"; 		

 		var img2 = document.createElement("img");
 		img2.src = "images/lms_reload.png"; 		
 		img2.style.height = "20px"
 		img2.style.width = "20px"
 		img2.style.padding = "5px"
 		img2.style.position = "absolute";
 		img2.style.top = "0px";
 		img2.style.right = "0px";

 		div2.appendChild(img2);

 		var span = document.createElement("span");
 		span.style.position = "absolute";
 		span.style.top = "5px";
 		span.style.right = "30px";
 		span.style.color = "white";
 		span.innerHTML = "Reload the page";

 		div2.appendChild(span);

 		div.onmouseover = function() {
 			div.style.display = "none";
 			div2.style.display = "block";
 		}

 		div2.onmouseleave = function() {
 			div.style.display = "block";
 			div2.style.display = "none";
 		}

 		div.onclick = function() { 			
 			iframe.src = url;
 		}

 		div2.onclick = function() { 			
 			iframe.src = url;
 		}
 		iframeRoot.appendChild(div);
 		iframeRoot.appendChild(div2);
 	} catch (e) {
 		console.log("Exception while adding reload block:");
 		console.log(e);
 	}	
}

function makeWebClip(url, d, reloadBlock) {
	try {
		if (d != "") {
			document.domain = d;
		}
	} catch (e) {
		console.log("Exception while setting document domain:");
		console.log(e);
	}

	var id = "iframe_" + randomString(10);

	var iframe = document.createElement("iframe");
	iframe.src = url;
	iframe.setAttribute("allowfullscreen", "");
	iframe.width = "100px"; iframe.height = "100px";
	iframe.style.zIndex = 100;
	iframe.frameBorder = 0;
	iframe.style.display = "block";

	iframe.onload = function() {
		try {
			iframe.contentWindow.callflow = function(args) {
				return document.getElementById('flowFlash')['callFlowForIframe_' + iframe.id](args);
			}
			if(iframe.contentWindow.pushCallflowBuffer) iframe.contentWindow.pushCallflowBuffer();
		} catch (e) {
			console.log("Exception when setting iframe:");
			console.log(e);
		}	
	}

	var iframeRoot = reloadBlock ? document.createElement("div") : iframe;
	
	iframeRoot.style.position = "absolute";
	iframeRoot.id = id;
	iframeRoot.style.display = "none";

	if (reloadBlock) {		
		iframe.style.width = "100%";
		iframe.style.height = "100%";
		iframeRoot.appendChild(iframe);		
		makeReloadBlock(iframeRoot, iframe, url);	 	
	}
	
	document.body.appendChild(iframeRoot);		
	return id;
}

function setWebClipMetrics(id, x, y, width, height) {
	var iframe = document.getElementById(id);
	iframe.style.left = "" + x + "px";
	iframe.style.top =""  + y + "px";
	iframe.style.width = "" + width + "px";
	iframe.style.height = "" + height + "px";
	iframe.style.display = "block";
}

function webClipHostCall(id, name, args) {
	var frame_win = document.getElementById(id).contentWindow;
	frame_win[name].apply(frame_win, args);
}

function removeWebClip(id) {
	document.body.removeChild(document.getElementById(id));
}

function setLocationHash(hash) {
	window.location.hash = hash;
}

window.addEventListener("hashchange", function() { 
	var ff = document.getElementById('flowFlash');
	if (ff != null) ff["onhashchanged"](window.location.hash);
} );

// A listener for crossdomain messages from iframes
// It is used by RealHTMLCrossDomain form
function receiveMessage(e) {
	var content_win = e.source;
	var all_iframes = document.getElementsByTagName("iframe");
	for (i = 0; i < all_iframes.length; ++i) {
		var f = all_iframes[i];
		if (f.contentWindow == content_win) {
			var element = document.getElementById('flowFlash');
			if (element) {
				element['callFlowForIframe_' + f.id](["postMessage", e.data]);
			} else {
				console.log("Warning: flowFlash not ready for postMessage");
			}
			return;
		}
	}
	console.log("Warning: unknow message source");
}

window.addEventListener('message', receiveMessage);
