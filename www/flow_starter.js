class CustomFlowBox extends HTMLElement {
	static scripts = [
		"jsutils.js",
		"custom.js",
		"splashscreen.js",
		"stackblur.min.js",
		"ua-parser.js",
		"jquery-3.4.1.min.js",
		"webfont.js",
		"pixi-4.8.2.min.js",
		"pixi.filters.js?10",
		"purify/purify.min.js?1",
		"jscommon.js?12"
	];
	static starterScriptName = "flow_starter";

	constructor() {
		super()
		this.style.position = 'relative';
		this.style.display = 'block';
		this.attachShadow({mode : 'open'})
		let scriptNode = document.head.querySelector("script[src*='" + CustomFlowBox.starterScriptName + "']");
		if (scriptNode) {
			this.urlPrefix = scriptNode.src.split(CustomFlowBox.starterScriptName)[0] || ""
		}

		let mainScriptName = this.getAttribute('script')
		if (mainScriptName) {
			window.renderRoot = this;
			CustomFlowBox.scripts.forEach(name => {
				this.appendJsScript("js/" + name)
			})
			this.appendJsScript(mainScriptName)
			this.appendLink("fonts/fonts.css")
			this.appendLink("flowjspixi.css")
		}
	}

	appendJsScript(url) {
		const node = document.createElement('script');
		node.setAttribute("type","text/javascript");
		node.setAttribute("src", this.urlPrefix + url);
		node.async = false;
		this.shadowRoot.appendChild(node);
	}

	appendLink(url) {
		var link = document.createElement("link");
		link.setAttribute("rel", "stylesheet");
		link.setAttribute("type", "text/css");
		link.setAttribute("href", this.urlPrefix + url);
		this.shadowRoot.appendChild(link);
	}
}

customElements.define('flow-box', CustomFlowBox)