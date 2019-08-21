import js.Browser;

using DisplayObjectHelper;

class WebClip extends NativeWidgetClip {
	private var iframe : Dynamic = null;
	private var disableOverlay : Dynamic = null;
	private var htmlPageWidth : Dynamic = null;
	private var htmlPageHeight : Dynamic = null;
	private var shrinkToFit : Dynamic = null;

	private static function isUrl(str) : Bool {
		return ~/^(\S+[.?][^\/\s]+(\/\S+|\/|))$/g.match(str);
	}

	private function appendReloadBlock() : Void {
		var div = Browser.document.createElement("div");
		div.style.cssText= "z-index: 101; position: absolute; top: 0; left: 0; width: 100%; height: 20px; opacity: 0.6;";

		var img = Browser.document.createElement("img");
		img.style.cssText = "position: absolute; height: 20px; width: 20px; top: 0; right: 0; background: #BEBEBE;";
		untyped img.src = "images/realhtml_reload.png";
		div.appendChild(img);

		var span = Browser.document.createElement("span");
		span.style.cssText = "position: absolute; right: 25px; top: 0px; color: white; display: none;";
		span.innerHTML = "Reload the page";
		div.appendChild(span);

		img.onmouseover = function(e : Dynamic) {
			div.style.background = "linear-gradient(to bottom right, #36372F, #ACA9A4)";
			span.style.display = "block";
			img.style.background = "none";
		}

		untyped img.onmouseleave = function(e : Dynamic) {
			div.style.background = "none";
			span.style.display = "none";
			img.style.background = "#BEBEBE";
		}

		div.onclick = function(e : Dynamic) {
			iframe.src = iframe.src;
		}

		nativeWidget.appendChild(div);
	}

	public function new(url : String, domain : String, useCache : Bool, reloadBlock : Bool, cb : Array<String> -> String, ondone : String -> Void, shrinkToFit : Bool) {
		super();

		if (domain != "") {
			try { Browser.document.domain = domain; } catch(e : Dynamic) { Errors.report("Can not set RealHTML domain" + e); }
		}

		createNativeWidget("div");

		if (Platform.isIOS) {
			// To restrict size of iframe
			untyped nativeWidget.style.webkitOverflowScrolling = 'touch';
			nativeWidget.style.overflowY = "scroll";
		}

		this.shrinkToFit = shrinkToFit;

		iframe = Browser.document.createElement("iframe");
		iframe.style.visibility = "hidden";

		if (RenderSupportJSPixi.DomRenderer) {
			iframe.className = 'nativeWidget';
		}

		if (isUrl(url) || Platform.isIE || Platform.isEdge) {
			iframe.src = url;
		} else {
			iframe.srcdoc = url;
		}

		iframe.allowFullscreen = true;
		iframe.frameBorder = "no";
		iframe.callflow = cb; // Store for crossdomain calls

		nativeWidget.appendChild(iframe);

		if (reloadBlock) {
			appendReloadBlock();
		}

		iframe.onload = function() {
			try {
				var iframeDocument = iframe.contentWindow.document;
				iframeDocument.addEventListener('mousemove', onContentMouseMove, false);
				if (Native.isTouchScreen())
					iframeDocument.addEventListener('touchstart', onContentMouseMove, false);

				if (shrinkToFit) {
					try {
						this.htmlPageWidth = iframeDocument.body.scrollWidth;
						this.htmlPageHeight = iframeDocument.body.scrollHeight;
						applyShrinkToFit();
					} catch(e : Dynamic) {
						// if we can't get the size of the html page, we can't do shrink so disable it
						this.shrinkToFit = false;
						Errors.report(e);
						applyNativeWidgetSize();
					}
				}

				ondone("OK");

				if (Platform.isIOS && (url.indexOf("flowjs") >= 0 || url.indexOf("lslti_provider") >= 0)) {
					iframe.scrolling = "no";
				}
				iframe.contentWindow.callflow = cb;
				if (iframe.contentWindow.pushCallflowBuffer) {
					iframe.contentWindow.pushCallflowBuffer();
				}
				if (Platform.isIOS && iframe.contentWindow.setSplashScreen != null) {
					iframe.scrolling = "no"; // Obviousely it is flow page.
				}
			} catch(e : Dynamic) { Errors.report(e); }
		};
	}

	private function applyShrinkToFit() {
		if (getClipVisible() && nativeWidget != null && iframe != null && shrinkToFit && htmlPageHeight != null && htmlPageWidth != null) {
			var scaleH = nativeWidget.clientHeight / this.htmlPageHeight;
			var scaleW = nativeWidget.clientWidth / this.htmlPageWidth;
			var scaleWH = Math.min(1.0, Math.min(scaleH, scaleW));

			iframe.border = "0";
			iframe.style.position = "relative";
			untyped iframe.style["-ms-zoom"] = scaleWH;
			untyped iframe.style["-moz-transform"] = "scale(" + scaleWH + ")";
			untyped iframe.style["-moz-transform-origin"] = "0 0";
			untyped iframe.style["-o-transform"] = "scale(" + scaleWH + ")";
			untyped iframe.style["-o-transform-origin"] = "0 0";
			untyped iframe.style["-webkit-transform"] = "scale(" + scaleWH + ")";
			untyped iframe.style["-webkit-transform-origin"] = "0 0";
			untyped iframe.style["transform"] = "scale(" + scaleWH + ")";
			untyped iframe.style["transform-origin"] = "0 0";

			iframe.width = iframe.clientWidth = htmlPageWidth;
			iframe.height = iframe.clientHeight = htmlPageHeight;
			iframe.style.width = htmlPageWidth;
			iframe.style.height = htmlPageHeight;
			iframe.style.visibility = "visible";
		}
	}

	private function applyNativeWidgetSize() {
		if (getClipVisible() && nativeWidget != null && iframe != null) {
			// Explicitly set w/h (for iOS at least it does not work with "100%")
			iframe.style.width = nativeWidget.style.width;
			iframe.style.height = nativeWidget.style.height;
			iframe.style.visibility = "visible";
		}
	}

	private function onContentMouseMove(e : Dynamic) {
		var iframeZorder : Int = Math.floor(Std.parseInt(nativeWidget.style.zIndex) / 1000);
		var localStages = RenderSupportJSPixi.PixiStage.children;
		var i = localStages.length - 1;

		while (i > iframeZorder) {

			var pos = Util.getPointerEventPosition(e);

			if (RenderSupportJSPixi.getClipAt(localStages[i], pos, true, true) != null) {
				untyped localStages[i].view.style.pointerEvents = "all";
				untyped localStages[iframeZorder].view.style.pointerEvents = "none";

				untyped RenderSupportJSPixi.PixiRenderer.view = untyped localStages[i].view;

				if (e.type == "touchstart") {
					RenderSupportJSPixi.emitMouseEvent(RenderSupportJSPixi.PixiStage, "mousedown", pos.x, pos.y);
					RenderSupportJSPixi.emitMouseEvent(RenderSupportJSPixi.PixiStage, "mouseup", pos.x, pos.y);
				}

				return;
			}

			i--;
		}
	}

	public override function updateNativeWidgetStyle() {
		super.updateNativeWidgetStyle();

		if (nativeWidget.getAttribute("tabindex") != null) {
			iframe.setAttribute("tabindex", nativeWidget.getAttribute("tabindex")); // Needed to the correct tab order of iframe elements
			nativeWidget.removeAttribute("tabindex"); // FF set focus to div if it has tabindex
		}

		if (getClipVisible()) {
			if (this.shrinkToFit) {
				applyShrinkToFit();
			} else {
				applyNativeWidgetSize();
			}

			if (disableOverlay && disableOverlay.style.display == "block") {
				disableOverlay.style.width = nativeWidget.style.width;
				disableOverlay.style.height = nativeWidget.style.height;
			}
		}
	}

	public function getDescription() : String {
		return 'WebClip (url = ${iframe.src})';
	}

	public function hostCall(name : String, args : Array<String>) : String {
		try {
			return untyped iframe.contentWindow[name].apply(iframe.contentWindow, args);
		} catch (e : Dynamic) {
			Errors.report("Error in hostCall: " + name + ", arg: " + Std.string(args));
			Errors.report(e);
		}
		return "";
	}

	public function setDisableOverlay(disable : Bool) : Void {
		if (disableOverlay && !disable) {
			nativeWidget.removeChild(disableOverlay);
		} else if (disable) {
			if (!disableOverlay) {
				disableOverlay = Browser.document.createElement("div");
				disableOverlay.style.cssText= "z-index: 100; background-color: rgba(0, 0, 0, 0.15);";
			}

			disableOverlay.style.display = "block";
			nativeWidget.appendChild(disableOverlay);
		}
	}

	public function setSandBox(value : String) : Void {
		iframe.sandbox = value;
	}

	public function evalJS(code : String) : Void {
		if (iframe.contentWindow != null) {
			iframe.contentWindow.postMessage(code, '*');
		}
	}

}