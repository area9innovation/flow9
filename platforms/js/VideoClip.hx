import js.Browser;
import js.html.Element;
import js.Promise;

import pixi.core.display.Bounds;
import pixi.core.math.shapes.Rectangle;
import pixi.core.sprites.Sprite;
import pixi.core.textures.Texture;

using DisplayObjectHelper;

class VideoClip extends FlowContainer {
	private var metricsFn : Float -> Float -> Void;
	private var playFn : Bool -> Void;
	private var durationFn : Float -> Void;
	private var positionFn : Float -> Void;
	private var streamStatusListener : Array<String -> Void> = new Array<String -> Void>();
	private var sources : Array<Element> = new Array<Element>();

	private var startTime : Float = 0;
	private var endTime : Float = 0;

	private var videoSprite : Sprite;
	private var videoTexture : Texture;
	private var fontFamily : String = '';
	private var textField : TextClip;
	private var loaded : Bool = false;
	private var subtitleAlignBottom : Bool = false;
	private var subtitleBottomBorder : Float = 2.0;
	private var subtitlesScaleMode : Bool = false;
	private var subtitlesScaleModeMin : Float = -1.0;
	private var subtitlesScaleModeMax : Float = -1.0;
	private var autoPlay : Bool = false;
	private var isAudio : Bool = false;

	private static var playingVideos : Array<VideoClip> = new Array<VideoClip>();

	public var videoWidget : Dynamic;
	private var widgetBounds = new Bounds();

	public static inline function NeedsDrawing() : Bool {
		var playingVideosFiltered =
			playingVideos.filter(function (v) {
				var videoWidget = v.videoWidget;
				if (videoWidget == null) {
					return false;
				}
				// On iPad video with time range can return currentTime, which is slightly ahead of the startTime. So let's be less strict in this case.
				var checkingGap = Platform.isIOS ? 0.5 : 0.0;
				v.checkTimeRange(videoWidget.currentTime, true, checkingGap);

				if (!v.isHTMLRenderer()) {
					if (videoWidget.width != videoWidget.videoWidth || videoWidget.height != videoWidget.videoHeight) {
						videoWidget.dispatchEvent(new js.html.Event("resize"));
					}
				}

				return v.getClipRenderable();
			});

		if (playingVideosFiltered.length > 0) {
			Browser.window.dispatchEvent(Platform.isIE ? untyped __js__("new CustomEvent('videoplaying')") : new js.html.Event('videoplaying'));
			for (v in playingVideosFiltered) {
				v.invalidateTransform();
			}
			return true;
		}

		return false;
	}

	public function new(metricsFn : Float -> Float -> Void, playFn : Bool -> Void, durationFn : Float -> Void, positionFn : Float -> Void) {
		isFlowContainer = false;
		super();

		this.keepNativeWidget = true;
		this.metricsFn = metricsFn;
		this.playFn = playFn;
		this.durationFn = durationFn;
		this.positionFn = positionFn;
	}

	private function checkTimeRange(currentTime : Float, videoResponse : Bool, gap : Float = 0) : Void {
		try { // Crashes in IE sometimes
			if (currentTime < startTime - gap && startTime < videoWidget.duration) {
				videoWidget.currentTime = startTime;
				positionFn(videoWidget.currentTime);
			} else if (endTime > 0 && endTime > startTime && currentTime >= endTime) {
				if (videoWidget.paused) {
					videoWidget.currentTime = endTime;
				} else {
					videoWidget.currentTime = startTime;
					if (!videoWidget.loop) {
						videoWidget.pause();
						onStreamEnded();
					}
				}
				positionFn(videoWidget.currentTime);
			} else if (videoResponse) {
				positionFn(videoWidget.currentTime);
			} else {
				videoWidget.currentTime = currentTime;
			}
		} catch (e : Dynamic) {}
	}

	private function createVideoClip(filename : String, startPaused : Bool, headers : Array<Array<String>>) : Void {
		deleteVideoClip();

		autoPlay = !startPaused;
		addVideoSource(filename, "", headers);
		videoWidget = Browser.document.createElement(this.isAudio ? "audio" : "video");

		if (this.isHTMLRenderer()) {
			this.initNativeWidget("div");
			nativeWidget.appendChild(videoWidget);
		}

		videoWidget.crossOrigin = Util.determineCrossOrigin(filename);
		videoWidget.className = 'nativeWidget';
		videoWidget.setAttribute('playsinline', true);
		videoWidget.setAttribute('autoplay', true);
		videoWidget.style.pointerEvents = 'none';

		for (source in sources) {
			videoWidget.appendChild(source);
		}

		if (!this.isHTMLRenderer()) {
			addVideoSprite();
		}

		createStreamStatusListeners();
		createFullScreenListeners();

		this.onAdded(function() {
			RenderSupport.on("enable_sprites", enableSprites);

			return function() {
				RenderSupport.off("enable_sprites", enableSprites);
				disableSprites();
			}
		});

		once("removed", deleteVideoClip);
	}

	private function deleteVideoClip() : Void {
		if (videoWidget != null) {
			pauseVideo();

			// Force video unload
			for (source in sources) {
				videoWidget.removeChild(source);
			}
			videoWidget.load();

			deleteVideoSprite();
			deleteSubtitlesClip();

			destroyStreamStatusListeners();
			destroyFullScreenListeners();

			if (videoWidget != null) {
				var parentNode = videoWidget.parentNode;

				if (parentNode != null) {
					parentNode.removeChild(videoWidget);
				}

				videoWidget = null;
			}
		}

		loaded = false;
	}

	public function updateNativeWidget() : Void {
		if (visible) {
			this.updateNativeWidgetTransformMatrix();
			this.updateNativeWidgetOpacity();
			this.updateNativeWidgetMask();
			nativeWidget.style.transform = 'none';

			var width0 = Math.round(this.getWidth() * untyped this.transform.scale.x);
			var height0 = Math.round(this.getHeight() * untyped this.transform.scale.y);

			var width = Math.isNaN(width0) ? 0 : width0;
			var height = Math.isNaN(height0) ? 0 : height0;

			videoWidget.width = width;
			videoWidget.height = height;

			videoWidget.setAttribute('width', '${width}');
			videoWidget.setAttribute('height', '${height}');
			videoWidget.style.width = '${width}px';
			videoWidget.style.height = '${height}px';
			if (untyped this.transform.scale.x == untyped this.transform.scale.y) {
				videoWidget.style.objectFit = '';
			} else {
				videoWidget.style.objectFit = 'fill';
			}

			updateSubtitlesClip();

			this.updateNativeWidgetInteractive();
		}

		this.updateNativeWidgetDisplay();
	}

	public function getDescription() : String {
		return videoWidget != null ? 'VideoClip (url = ${videoWidget.url})' : '';
	}

	public function setVolume(volume : Float) : Void {
		if (videoWidget != null) {
			videoWidget.volume = volume;
			if (Platform.isIOS) {
				videoWidget.muted = volume == 0.0;
			}
		}
	}

	public function setLooping(loop : Bool) : Void {
		if (videoWidget != null) {
			videoWidget.loop = loop;
		}
	}

	public function setIsAudio() : Void {
		this.isAudio = Util.getParameter("video2audio") != "0";
	}

	public function playVideo(filename : String, startPaused : Bool, headers : Array<Array<String>>) : Void {
		createVideoClip(filename, startPaused, headers);
	}

	public function playVideoFromMediaStream(mediaStream : FlowMediaStream, startPaused : Bool) : Void {
		createVideoClip("", startPaused, []);
		videoWidget.srcObject = mediaStream.mediaStream;
		mediaStream.videoClip = this;
		mediaStream.emit("attached");
	}

	public function setTimeRange(start : Float, end : Float) : Void {
		startTime = start >= 0 ? floorTime(start) : 0;
		endTime = end > startTime ? floorTime(end) : videoWidget.duration;
		checkTimeRange(videoWidget.currentTime, true);
	}

	public function setCurrentTime(time : Float) : Void {
		checkTimeRange(time, false);
	}

	public function setVideoSubtitle(text : String, fontfamily : String, fontsize : Float, fontweight : Int, fontslope : String, fillcolor : Int,
		fillopacity : Float, letterspacing : Float, backgroundcolour : Int, backgroundopacity : Float,
		alignBottom : Bool, bottomBorder : Float, scaleMode : Bool, scaleModeMin : Float, scaleModeMax : Float, escapeHTML : Bool) : Void {
		if (text == '') {
			deleteSubtitlesClip();
		} else {
			setVideoSubtitleClip(text, fontfamily, fontsize, fontweight, fontslope, fillcolor, fillopacity, letterspacing, backgroundcolour, backgroundopacity,
				alignBottom, bottomBorder, scaleMode, scaleModeMin, scaleModeMax, escapeHTML);
		};
	}

	public function setPlaybackRate(rate : Float) : Void {
		if (videoWidget != null) {
			videoWidget.playbackRate = rate;
		}
	}

	private function setVideoSubtitleClip(text : String, fontfamily : String, fontsize : Float, fontweight : Int, fontslope : String, fillcolor : Int,
		fillopacity : Float, letterspacing : Float, backgroundcolour : Int, backgroundopacity : Float,
		alignBottom : Bool, bottomBorder : Float, scaleMode : Bool, scaleModeMin : Float, scaleModeMax : Float, escapeHTML : Bool) : Void {
		if (fontFamily != fontfamily && fontfamily != '') {
			fontFamily = fontfamily;
			deleteSubtitlesClip();
		}

		createSubtitlesClip();

		textField.setAutoAlign('AutoAlignCenter');
		textField.setNeedBaseline(false);
		textField.setTextAndStyle(' ' + text + '\u00A0', fontFamily, fontsize, fontweight, fontslope, fillcolor, fillopacity, letterspacing, backgroundcolour, backgroundopacity);
		textField.setEscapeHTML(escapeHTML);
		subtitleAlignBottom = alignBottom;
		if (bottomBorder >= 0) subtitleBottomBorder = bottomBorder;
		subtitlesScaleMode = scaleMode;
		subtitlesScaleModeMin = scaleModeMin;
		subtitlesScaleModeMax = scaleModeMax;

		updateSubtitlesClip();
	}

	private function createSubtitlesClip() : Void {
		if (textField == null) {
			textField = new TextClip();
			textField.setWordWrap(true);
			addChild(textField);
		};
	}

	private function updateSubtitlesClip() : Void {
		if (videoWidget != null && textField != null) {
			if (videoWidget.width == 0) {
				textField.setClipVisible(false);
			} else {
				textField.setClipVisible(true);

				var xScale = if (subtitlesScaleMode) untyped this.transform.scale.x else 1.0;
				var yScale = if (subtitlesScaleMode) untyped this.transform.scale.y else 1.0;
				if (subtitlesScaleModeMin != -1.0) {
					xScale = Math.max(xScale, subtitlesScaleModeMin);
					yScale = Math.max(yScale, subtitlesScaleModeMin);
				}
				if (subtitlesScaleModeMax != -1.0) {
					xScale = Math.min(xScale, subtitlesScaleModeMax);
					yScale = Math.min(yScale, subtitlesScaleModeMax);
				}
				textField.setClipScaleX(xScale);
				textField.setClipScaleY(yScale);

				textField.setWidth(0.0);
				textField.setWidth(Math.min(textField.getWidth(), videoWidget.width / xScale));

				textField.setClipX((videoWidget.width - textField.getWidth() * xScale) / 2.0);
				textField.setClipY(videoWidget.height - textField.getHeight() * yScale - subtitleBottomBorder * yScale + (subtitleAlignBottom ? this.y : 0.0));

				textField.invalidateTransform("updateSubtitlesClip");
			}
		}
	}

	private function deleteSubtitlesClip() : Void {
		removeChild(textField);
		textField = null;
	}

	private function addVideoSprite() : Void {
		if (videoWidget != null) {
			videoTexture = Texture.fromVideo(videoWidget);
			untyped videoTexture.baseTexture.autoUpdate = false;
			videoSprite = new Sprite(videoTexture);
			untyped videoSprite._visible = true;
			addChild(videoSprite);
		}
	}

	private function deleteVideoSprite() : Void {
		if (videoSprite != null) {
			videoSprite.destroy({ children: true, texture: true, baseTexture: true });
			removeChild(videoSprite);
			videoSprite = null;
		}

		if (videoTexture != null) {
			videoTexture.destroy(true);
			videoTexture = null;
		}
	}

	private function enableSprites() : Void {
		if (untyped this.destroyed || parent == null || nativeWidget == null) {
			return;
		}

		addVideoSprite();
		RenderSupport.on("disable_sprites", disableSprites);
	}

	private function disableSprites() : Void {
		deleteVideoSprite();
		RenderSupport.off("disable_sprites", disableSprites);
	}

	public function getCurrentTime() : Float {
		return videoWidget != null ? videoWidget.currentTime : 0;
	}

	public function pauseVideo() : Void {
		if (loaded && !videoWidget.paused) {
			autoPlay = false;
			videoWidget.pause();
			playingVideos.remove(this);
		}
	}

	public function resumeVideo() : Void {
		if (loaded && videoWidget.paused) {
			autoPlay = true;
			var playPromise : Promise<Dynamic> = videoWidget.play();
			if (playPromise != null) {
				playPromise.then(
					function(arg : Dynamic) {
						playingVideos.push(this);
					},
					function(e) {
						playFn(false);
					}
				);
			} else {
				playingVideos.push(this);
			}
		}
	}

	private function onMetadataLoaded() {
		durationFn(videoWidget.duration);

		updateVideoMetrics();

		videoWidget.currentTime = 0;
		checkTimeRange(videoWidget.currentTime, true);

		this.invalidateTransform('onMetadataLoaded'); // Update the widget

		if (textField != null) {
			if (!this.isHTMLRenderer() && getChildIndex(videoSprite) > getChildIndex(textField)) {
				swapChildren(videoSprite, textField);
			}

			updateSubtitlesClip();
		};

		if (!this.isHTMLRenderer()) {
			videoTexture.update();
		}

		loaded = true;

		if (autoPlay) {
			resumeVideo();
		} else {
			videoWidget.pause();
		}
	}

	private function updateVideoMetrics() {
		metricsFn(videoWidget.videoWidth, videoWidget.videoHeight);

		calculateWidgetBounds();
		this.invalidateTransform('updateVideoMetrics');

		if (this.isHTMLRenderer()) {
			videoWidget.style.width = '${this.getWidth()}px';
			videoWidget.style.height = '${this.getHeight()}px';
		} else {
			videoWidget.width = videoWidget.videoWidth;
			videoWidget.height = videoWidget.videoHeight;
			videoTexture.update();
		}
	}

	private function onStreamLoaded() : Void {
		for (l in streamStatusListener) {
			l("NetStream.Play.Start");
		}
	}

	private function onStreamEnded() : Void {
		if (!videoWidget.loop) {
			playingVideos.remove(this);
		}

		for (l in streamStatusListener) {
			l("NetStream.Play.Stop");
		}
	}

	private function onStreamError() : Void {
		for (l in streamStatusListener) {
			l("NetStream.Play.StreamNotFound");
		}
	}

	private function onStreamPlay() : Void {
		if (videoWidget != null && !videoWidget.paused) {
			if (!autoPlay) {
				videoWidget.pause();
			} else {
				for (l in streamStatusListener) {
					l("FlowGL.User.Resume");
				}

				playFn(true);
			}
		}
	}

	private function onStreamPause() : Void {
		if (videoWidget != null && videoWidget.paused) {
			for (l in streamStatusListener) {
				l("FlowGL.User.Pause");
			}

			playFn(false);
		}
	}

	private function onStreamPlaying() : Void {
		if (videoWidget != null) {
			for (l in streamStatusListener) {
				l("FlowGL.User.Playing");
			}
		}
	}

	private function onStreamWaiting(e) : Void {
		if (videoWidget != null) {
			for (l in streamStatusListener) {
				l("FlowGL.User.Waiting");
			}
		}
	}

	private function onFullScreen() : Void {
		if (videoWidget != null) {
			RenderSupport.fullScreenTrigger();

			if (RenderSupport.IsFullScreen) {
				Browser.document.body.appendChild(videoWidget);
			} else {
				Browser.document.body.removeChild(videoWidget);
			}

		}
	}

	public function addStreamStatusListener(fn : String -> Void) : Void -> Void {
		streamStatusListener.push(fn);
		return function () { streamStatusListener.remove(fn); };
	}

	public function addVideoSource(src : String, type : String, headers : Array<Array<String>>) : Void {
		var source = Browser.document.createElement('source');
		var isAppended = false;

		if (headers.length == 0) {
			source.onerror = onStreamError;
			untyped source.src = src;

			if (type != "") {
				untyped source.type = type;
			}
		} else {
			var videoXhr = new js.html.XMLHttpRequest();
			videoXhr.open("GET", src, true);
			for (header in headers) {
				videoXhr.setRequestHeader(header[0], header[1]);
			}
			
			videoXhr.responseType = js.html.XMLHttpRequestResponseType.BLOB;
			videoXhr.onload = function (oEvent) {
				if (videoXhr.status == 200) {
					if (type == "") {
						type = videoXhr.getResponseHeader("content-type");
					}
					
					if (type != "") {
						untyped source.type = type;
					}
					
					untyped source.src = js.html.URL.createObjectURL(videoXhr.response);
					
					// Check and try add source here.
					if (!isAppended && videoWidget != null) {
						isAppended = true;
						videoWidget.appendChild(source);
					}
				} else if (videoXhr.status >= 400) {
					onStreamError();
				}
			};

			videoXhr.onerror = onStreamError;
			videoXhr.send(null);
		}

		sources.push(source);

		// Sometimes we do not have `videoWidget` initialized here. Will do it on source loaded.
		if (!isAppended && videoWidget != null) {
			isAppended = true;
			videoWidget.appendChild(source);
		}

		Native.defer(function() {
			js.html.URL.revokeObjectURL(untyped source.src);
		});
	}

	public function setVideoExternalSubtitle(src : String, kind : String) : Void -> Void {
		if (src == "") return function() {};

		var track = Browser.document.createElement('track');
		track.setAttribute('default', '');
		track.setAttribute('src', src);
		if (kind != "") {
			track.setAttribute('kind', kind);
		}

		sources.push(track);
		if (videoWidget != null) {
			videoWidget.appendChild(track);
		}

		return function() {
			sources.remove(track);
			if (videoWidget != null) {
				videoWidget.removeChild(track);
			}
		}
	}

	private function createStreamStatusListeners() {
		if (videoWidget != null) {
			videoWidget.addEventListener('loadedmetadata', onMetadataLoaded, false);
			videoWidget.addEventListener('resize', updateVideoMetrics, false);
			videoWidget.addEventListener("loadeddata", onStreamLoaded, false);
			videoWidget.addEventListener("ended", onStreamEnded, false);
			videoWidget.addEventListener("error", onStreamError, false);
			videoWidget.addEventListener("play", onStreamPlay, false);
			videoWidget.addEventListener("pause", onStreamPause, false);
			videoWidget.addEventListener("playing", onStreamPlaying, false);
			videoWidget.addEventListener("waiting", onStreamWaiting, false);
		}
	}

	private function destroyStreamStatusListeners() {
		if (videoWidget != null) {
			videoWidget.removeEventListener('loadedmetadata', onMetadataLoaded);
			videoWidget.removeEventListener('resize', updateVideoMetrics);
			videoWidget.removeEventListener("loadeddata", onStreamLoaded);
			videoWidget.removeEventListener("ended", onStreamEnded);
			videoWidget.removeEventListener("error", onStreamError);
			videoWidget.removeEventListener("play", onStreamPlay);
			videoWidget.removeEventListener("pause", onStreamPause);
			videoWidget.removeEventListener("playing", onStreamPlaying, false);
			videoWidget.removeEventListener("waiting", onStreamWaiting, false);
		}
	}

	private function createFullScreenListeners() {
		if (videoWidget != null) {
			if (Platform.isIOS) {
				videoWidget.addEventListener('webkitbeginfullscreen', onFullScreen, false);
				videoWidget.addEventListener('webkitendfullscreen', onFullScreen, false);
			}

			videoWidget.addEventListener('fullscreenchange', onFullScreen, false);
			videoWidget.addEventListener('webkitfullscreenchange', onFullScreen, false);
			videoWidget.addEventListener('mozfullscreenchange', onFullScreen, false);
		}
	}

	private function destroyFullScreenListeners() {
		if (videoWidget != null) {
			if (Platform.isIOS) {
				videoWidget.removeEventListener('webkitbeginfullscreen', onFullScreen);
				videoWidget.removeEventListener('webkitendfullscreen', onFullScreen);
			}

			videoWidget.removeEventListener('fullscreenchange', onFullScreen);
			videoWidget.removeEventListener('webkitfullscreenchange', onFullScreen);
			videoWidget.removeEventListener('mozfullscreenchange', onFullScreen);
		}
	}

	public function getCurrentFrame() : String {
		try {
			var canvas : Dynamic = Browser.document.createElement('canvas');
			var ctx = canvas.getContext('2d');

			canvas.width = videoWidget.videoWidth;
			canvas.height = videoWidget.videoHeight;

			ctx.drawImage(videoWidget, 0, 0);

			var data = canvas.toDataURL();
			return data;
		} catch (e : Dynamic) {
			return "error";
		}
	}

	public override function getLocalBounds(?rect : Rectangle) : Rectangle {
		return localBounds.getRectangle(rect);
	}

	private function floorTime(time : Float) : Float {
		return Math.floor(time * 100) / 100;
	}

	public function calculateWidgetBounds() : Void {
		widgetBounds.minX = 0;
		widgetBounds.minY = 0;
		widgetBounds.maxX = videoWidget.videoWidth;
		widgetBounds.maxY = videoWidget.videoHeight;
	}

	private override function createNativeWidget(?tagName : String = "video") : Void {
		if (!isNativeWidget) {
			return;
		}

		this.deleteNativeWidget();

		nativeWidget = Browser.document.createElement(tagName);
		this.updateClipID();
		nativeWidget.className = 'nativeWidget';

		isNativeWidget = true;
	}
}