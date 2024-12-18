import js.html.WheelEvent;
import haxe.Json;
import js.Browser;
import pixi.core.math.Point;

using DisplayObjectHelper;

class WebClip extends NativeWidgetClip {
	private var iframe : Dynamic = null;
	private var htmlPageWidth : Dynamic = null;
	private var htmlPageHeight : Dynamic = null;
	private var shrinkToFit : Dynamic = null;
	private var noScroll : Bool = false;
	private var passEvents : Bool = false;

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

		this.keepNativeWidget = true;
		this.initNativeWidget();

		if (Platform.isIOS) {
			// To restrict size of iframe
			untyped nativeWidget.style.webkitOverflowScrolling = 'touch';
			nativeWidget.style.overflowY = "scroll";
		}

		this.shrinkToFit = shrinkToFit;

		iframe = Browser.document.createElement("iframe");
		iframe.style.visibility = "hidden";

		if (this.isHTMLRenderer()) {
			iframe.className = 'nativeWidget';
			iframe.style.pointerEvents = 'auto';
		}

		if (isUrl(url) || Platform.isIE || Platform.isEdge) {
			iframe.src = url;
		} else {
			iframe.srcdoc = url;
		}

		iframe.allowFullscreen = true;
		iframe.frameBorder = "no";
		iframe.callflow = cb; // Store for crossdomain calls

		iframe.id = nativeWidget.id + "_iframe";
		nativeWidget.appendChild(iframe);

		if (reloadBlock) {
			appendReloadBlock();
		}

		iframe.onload = function() {
			try {
				var iframeDocument = iframe.contentWindow.document;
				try {
					if (!this.isHTMLRenderer()) {
						iframeDocument.addEventListener('mousemove', onContentMouseMove, false);
						if (Native.isTouchScreen()) {
							iframeDocument.addEventListener('touchstart', onContentMouseMove, false);
						}
					} else if (this.passEvents) {
						var listenAndDispatch = function(eventName : String) {
							iframeDocument.addEventListener(eventName, function(e : Dynamic) {
								var pos0 = Util.getPointerEventPosition(e);
								var iframeBoundingRect = iframe.getBoundingClientRect();
								var pos = new Point(
									pos0.x * this.worldTransform.a + iframeBoundingRect.x,
									pos0.y * this.worldTransform.d + iframeBoundingRect.y
								);
								var emittedEventName = (Platform.isSafari && Platform.isMobile) ? switch (eventName) {
									case "pointerdown": "mousedown";
									case "pointerup": "mouseup";
									case "pointermove": "mousemove";
									default: eventName;
								} : eventName;

								RenderSupport.emitMouseEvent(RenderSupport.PixiStage, emittedEventName, pos.x, pos.y);
							}, false);
						}

						if (Platform.isSafari && !Platform.isMobile) {
							listenAndDispatch('mousedown');
							listenAndDispatch('mouseup');
							listenAndDispatch('mousemove');
						} else {
							listenAndDispatch('pointerdown');
							listenAndDispatch('pointerup');
							listenAndDispatch('pointermove');
						}
					}

					if (this.noScroll) {
						untyped iframeDocument.body.style["overflow"] = "hidden";
					}

					if (this.noScroll || this.passEvents) {
						iframeDocument.addEventListener('wheel', function (e) {
							RenderSupport.provideEvent(e);
						}, true);
					}

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
					iframe.contentWindow.is_callflow_defined = true;
					if (iframe.contentWindow.pushCallflowBuffer) {
						iframe.contentWindow.pushCallflowBuffer();
					}
					if (Platform.isIOS && iframe.contentWindow.setSplashScreen != null) {
						iframe.scrolling = "no"; // Obviousely it is flow page.
					}
				} catch(e : Dynamic) { Errors.report(e); ondone(e);}
			} catch(e : Dynamic) {
				// Keep working in case of CORS error
				function onCrossDomainMessage(e : Dynamic) {
					try {
						if (iframe.contentWindow == e.source) {
							var message = Json.parse(e.data);
							if (message.operation == "callflow") {
								cb(message.args);
							} else if (message.operation == "wheel" && message.args.length > 0) {
								RenderSupport.provideEvent(new WheelEvent("wheel", Json.parse(message.args[0])));
							}
						}
					} catch(e : Dynamic) { Errors.report(e); }
				}
				Browser.window.addEventListener('message', onCrossDomainMessage);
				once("removed", function() {
					Browser.window.removeEventListener('message', onCrossDomainMessage);
				});
				ondone("OK");
			}
		};
	}

	private function applyShrinkToFit() {
		if (this.getClipVisible() && nativeWidget != null && iframe != null && shrinkToFit && htmlPageHeight != null && htmlPageWidth != null) {
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
		if (this.getClipVisible() && nativeWidget != null && iframe != null) {
			// Explicitly set w/h (for iOS at least it does not work with "100%")
			iframe.style.width = nativeWidget.style.width;
			iframe.style.height = nativeWidget.style.height;
			iframe.style.visibility = "visible";
		}
	}

	private function onContentMouseMove(e : Dynamic) {
		var iframeZorder : Int = Math.floor(Std.parseInt(nativeWidget.style.zIndex) / 1000);
		var localStages = RenderSupport.PixiStage.children;
		var i = localStages.length - 1;

		while (i > iframeZorder) {
			var pos = Util.getPointerEventPosition(e);

			RenderSupport.setMousePosition(pos);

			if (RenderSupport.getClipAt(localStages[i], RenderSupport.MousePos, true, 0.0) != null) {
				untyped localStages[i].view.style.pointerEvents = "all";
				untyped localStages[iframeZorder].view.style.pointerEvents = "none";

				untyped RenderSupport.PixiRenderer.view = untyped localStages[i].view;

				if (e.type == "touchstart") {
					RenderSupport.emitMouseEvent(RenderSupport.PixiStage, "mousedown", pos.x, pos.y);
					RenderSupport.emitMouseEvent(RenderSupport.PixiStage, "mouseup", pos.x, pos.y);
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

		if (this.getClipVisible()) {
			if (this.shrinkToFit) {
				applyShrinkToFit();
			} else {
				applyNativeWidgetSize();
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

	public function setDisabled(disable : Bool) : Void {
		iframe.style.pointerEvents = disable ? 'none' : 'auto';
	}

	public function setNoScroll() : Void {
		this.noScroll = true;
	}

	public function setPassEvents() : Void {
		this.passEvents = true;
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