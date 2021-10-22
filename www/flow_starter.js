const starterScriptName = "flow_starter";

const scripts = [
	"jsutils.js",
	"custom.js",
	// "splashscreen.js",
	"stackblur.min.js",
	"ua-parser.js",
	"jquery-3.4.1.min.js",
	"webfont.js",
	"pixi-4.8.2.min.js",
	"pixi.filters.js?10",
	"purify/purify.min.js?1",
	"jscommon.js?12"
];

function appendJsScript(url) {
	const node = document.createElement('script');
	node.setAttribute("type","text/javascript");
	node.setAttribute("src", url);
	node.async = false;
	document.head.appendChild(node);
}

scriptNode = document.head.querySelector("script[src*='" + starterScriptName + "']");

if (scriptNode) {
	const url = new URL(scriptNode.src);
	const prefix = scriptNode.src.split(starterScriptName)[0]

	if (prefix) {
		scripts.forEach(name => {
			appendJsScript(prefix + "js/" + name)	
		})

		const mainScriptName = url.searchParams.get('name')
		if (mainScriptName) appendJsScript(prefix + mainScriptName + ".js")
	}
}