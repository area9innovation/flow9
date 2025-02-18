const starterScriptName = "flow_starter";

const scripts = [
	"jsutils.js",
	"custom.js",
	// "splashscreen.js",
	"stackblur.min.js",
	"ua-parser.js",
	"jquery-3.4.1.min.js",
	"webfont.js",
	"pixi-4.8.2.min.js?2",
	"pixi.filters.js?10",
	"purify/purify.min.js?1",
	"jscommon.js?14"
];

function appendJsScript(url) {
	const node = document.createElement('script');
	node.setAttribute("type","text/javascript");
	node.setAttribute("src", url);
	node.async = false;
	document.head.appendChild(node);
}

function appendLink(url) {
	var link = document.createElement("link");
	link.setAttribute("rel", "preload");
	link.setAttribute("as", "style");
	link.setAttribute("type", "text/css");
	link.setAttribute("href", url);
	document.head.appendChild(link);
}

scriptNode = document.currentScript || document.head.querySelector("script[src*='" + starterScriptName + "']");

if (scriptNode) {
	let url;
	try {
		url = new URL(scriptNode.src);
	} catch(e) {}
	const prefix = scriptNode.src.split(starterScriptName)[0]

	if (prefix) {
		scripts.forEach(function(name) {
			appendJsScript(prefix + "js/" + name)	
		})

		appendLink(prefix + "fonts/fonts.css")
		appendLink(prefix + "flowjspixi.css")

		if (url) {
			const mainScriptName = url.searchParams.get('name')
			if (mainScriptName) appendJsScript(prefix + mainScriptName + ".js")
		} else {
			setTimeout(function() {
				if (typeof getUrlParameter != "undefined") {
					const mainScriptName = getUrlParameter("name", scriptNode.src)
					if (mainScriptName) appendJsScript(prefix + mainScriptName + ".js")
				}
			}, 100)
		}
	}
}