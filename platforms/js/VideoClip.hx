import js.Browser;
import js.html.Element;

import pixi.core.math.shapes.Rectangle;
import pixi.core.sprites.Sprite;
import pixi.core.textures.Texture;
import pixi.core.textures.BaseTexture;
import pixi.core.renderers.canvas.CanvasRenderer;

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

	private static var playingVideos : Array<VideoClip> = new Array<VideoClip>();

	public static var CanAutoPlay = false;

	public static inline function NeedsDrawing() : Bool {
		if (playingVideos.filter(function (v) { return v.getClipWorldVisible(); }).length > 0) {
			Browser.window.dispatchEvent(Platform.isIE ? untyped __js__("new CustomEvent('videoplaying')") : new js.html.Event('videoplaying'));
			return true;
		}

		return false;
	}

	public function new(metricsFn : Float -> Float -> Void, playFn : Bool -> Void, durationFn : Float -> Void, positionFn : Float -> Void) {
		super();

		isNativeWidget = RenderSupportJSPixi.DomRenderer;

		this.metricsFn = metricsFn;
		this.playFn = playFn;
		this.durationFn = durationFn;
		this.positionFn = positionFn;
	}

	public function updateNativeWidget() {
		if (nativeWidget != null) {
			if (visible) {
				updateNativeWidgetTransformMatrix();
				updateNativeWidgetOpacity();
				updateNativeWidgetMask();
			}

			updateNativeWidgetDisplay();
		}

		if (!nativeWidget.paused) {
			checkTimeRange(nativeWidget.currentTime, true);

			if (!RenderSupportJSPixi.DomRenderer) {
				if (nativeWidget.width != nativeWidget.videoWidth || nativeWidget.height != nativeWidget.videoHeight) {
					nativeWidget.dispatchEvent(new js.html.Event("resize"));
				}
			}
		}
	}

	private function checkTimeRange(currentTime : Float, videoResponse : Bool) : Void {
		try { // Crashes in IE sometimes
			if (currentTime < startTime && startTime < nativeWidget.duration) {
				nativeWidget.currentTime = startTime;
				positionFn(nativeWidget.currentTime);
			} else if (endTime > 0 && endTime > startTime && currentTime >= endTime) {
				if (nativeWidget.paused) {
					nativeWidget.currentTime = endTime;
				} else {
					nativeWidget.currentTime = startTime;
					if (!nativeWidget.loop) nativeWidget.pause();
				}
				positionFn(nativeWidget.currentTime);
			} else if (videoResponse) {
				positionFn(nativeWidget.currentTime);
			} else {
				nativeWidget.currentTime = currentTime;
			}
		} catch (e : Dynamic) {}
	}

	private function createVideoClip(filename : String, startPaused : Bool) : Void {
		deleteVideoClip();

		addVideoSource(filename, "");

		if (RenderSupportJSPixi.DomRenderer) {
			createNativeWidget();
		} else {
			nativeWidget = Browser.document.createElement("video");
		}

		nativeWidget.crossorigin = Util.determineCrossOrigin(filename);
		nativeWidget.autoplay = !startPaused;
		nativeWidget.setAttribute('playsinline', true);

		for (source in sources) {
			nativeWidget.appendChild(source);
		}

		if (nativeWidget.autoplay) {
			if (playingVideos.indexOf(this) < 0) playingVideos.push(this);
		}

		if (!RenderSupportJSPixi.DomRenderer) {
			videoTexture = Texture.fromVideo(nativeWidget);
			untyped videoTexture.baseTexture.autoPlay = !startPaused;
			untyped videoTexture.baseTexture.autoUpdate = false;
			videoSprite = new Sprite(videoTexture);
			untyped videoSprite._visible = true;
			addChild(videoSprite);

			RenderSupportJSPixi.on("drawframe", updateNativeWidget);
			once("removed", deleteVideoClip);
		}

		createStreamStatusListeners();
		createFullScreenListeners();

		if (!startPaused && !CanAutoPlay)
			playFn(false);
	}

	private function deleteVideoClip() : Void {
		if (nativeWidget != null) {
			nativeWidget.autoplay = false;
			pauseVideo();

			// Force video unload
			for (source in sources) {
				nativeWidget.removeChild(source);
			}
			nativeWidget.load();

			RenderSupportJSPixi.off("drawframe", updateNativeWidget);

			deleteVideoSprite();
			deleteSubtitlesClip();

			destroyStreamStatusListeners();
			destroyFullScreenListeners();

			if (nativeWidget != null) {
				var parentNode = nativeWidget.parentNode;

				if (parentNode != null) {
					parentNode.removeChild(nativeWidget);
				}

				nativeWidget = null;
			}
		}

		loaded = false;
	}

	public function getDescription() : String {
		return nativeWidget != null ? 'VideoClip (url = ${nativeWidget.url})' : '';
	}

	public function setVolume(volume : Float) : Void {
		if (nativeWidget != null) {
			nativeWidget.volume = volume;
		}
	}

	public function setLooping(loop : Bool) : Void {
		if (nativeWidget != null) {
			nativeWidget.loop = loop;
		}
	}

	public function playVideo(filename : String, startPaused : Bool) : Void {
		createVideoClip(filename, startPaused);
	}

	public function playVideoFromMediaStream(mediaStream : js.html.MediaStream, startPaused : Bool) : Void {
		createVideoClip("", startPaused);
		nativeWidget.srcObject = mediaStream;
	}

	public function setTimeRange(start : Float, end : Float) : Void {
		startTime = start >= 0 ? start : 0;
		endTime = end > startTime ? end : nativeWidget.duration;
		checkTimeRange(nativeWidget.currentTime, true);
	}

	public function setCurrentTime(time : Float) : Void {
		checkTimeRange(time, false);
	}

	public function setVideoSubtitle(text : String, fontfamily : String, fontsize : Float, fontweight : Int, fontslope : String, fillcolor : Int,
		fillopacity : Float, letterspacing : Float, backgroundcolour : Int, backgroundopacity : Float) : Void {
		if (text == '') {
			deleteSubtitlesClip();
		} else {
			setVideoSubtitleClip(text, fontfamily, fontsize, fontweight, fontslope, fillcolor, fillopacity, letterspacing, backgroundcolour, backgroundopacity);
		};
	}

	public function setPlaybackRate(rate : Float) : Void {
		if (nativeWidget != null) {
			nativeWidget.playbackRate = rate;
		}
	}

	private function setVideoSubtitleClip(text : String, fontfamily : String, fontsize : Float, fontweight : Int, fontslope : String, fillcolor : Int,
		fillopacity : Float, letterspacing : Float, backgroundcolour : Int, backgroundopacity : Float) : Void {
		if (fontFamily != fontfamily && fontfamily != '') {
			fontFamily = fontfamily;
			deleteSubtitlesClip();
		}

		createSubtitlesClip();
		textField.setTextAndStyle(' ' + text + ' ', fontFamily, fontsize, fontweight, fontslope, fillcolor, fillopacity, letterspacing, backgroundcolour, backgroundopacity);
		updateSubtitlesClip();
	}

	private function createSubtitlesClip() : Void {
		if (textField == null) {
			textField = new TextClip();
			addChild(textField);
		};
	}

	private function updateSubtitlesClip() : Void {
		if (nativeWidget != null) {
			textField.setClipX((nativeWidget.width - textField.getWidth()) / 2.0);
			textField.setClipY(nativeWidget.height - textField.getHeight() - 2.0);
		}
	}

	private function deleteSubtitlesClip() : Void {
		removeChild(textField);
		textField = null;
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

	public function getCurrentTime() : Float {
		return nativeWidget != null ? nativeWidget.currentTime : 0;
	}

	public function pauseVideo() : Void {
		if (loaded && !nativeWidget.paused) {
		 	nativeWidget.pause();
			if (playingVideos.indexOf(this) >= 0) playingVideos.remove(this);
		}
	}

	public function resumeVideo() : Void {
		if (loaded && nativeWidget.paused) {
			nativeWidget.play();
			if (playingVideos.indexOf(this) < 0) playingVideos.push(this);
		}
	}

	private function onMetadataLoaded() {
		durationFn(nativeWidget.duration);

		updateVideoMetrics();

		checkTimeRange(nativeWidget.currentTime, true);

		invalidateTransform(); // Update the widget

		if (!nativeWidget.autoplay) nativeWidget.pause();

		if (textField != null) {
			if (!RenderSupportJSPixi.DomRenderer && getChildIndex(videoSprite) > getChildIndex(textField)) {
				swapChildren(videoSprite, textField);
			}

			updateSubtitlesClip();
		};

		loaded = true;
	}

	private function updateVideoMetrics() {
		metricsFn(nativeWidget.videoWidth, nativeWidget.videoHeight);

		localBounds.minX = 0;
		localBounds.minY = 0;
		localBounds.maxX = nativeWidget.videoWidth;
		localBounds.maxY = nativeWidget.videoHeight;

		if (RenderSupportJSPixi.DomRenderer) {
			nativeWidget.style.width = '${untyped getWidth()}px';
			nativeWidget.style.height = '${untyped getHeight()}px';
		} else {
			nativeWidget.width = nativeWidget.videoWidth;
			nativeWidget.height = nativeWidget.videoHeight;
			videoTexture.update();
		}
	}

	private function onStreamLoaded() : Void {
		streamStatusListener.map(function (l) { l("NetStream.Play.Start"); });
	}

	private function onStreamEnded() : Void {
		if (!nativeWidget.autoplay) {
			if (playingVideos.indexOf(this) >= 0) playingVideos.remove(this);
		}

		streamStatusListener.map(function (l) { l("NetStream.Play.Stop"); });
	}

	private function onStreamError() : Void {
		streamStatusListener.map(function (l) { l("NetStream.Play.StreamNotFound"); });
	}

	private function onStreamPlay() : Void {
		if (nativeWidget != null && !nativeWidget.paused) {
			streamStatusListener.map(function (l) { l("FlowGL.User.Resume"); });

			playFn(true);
		}
	}

	private function onStreamPause() : Void {
		if (nativeWidget != null && nativeWidget.paused) {
			streamStatusListener.map(function (l) { l("FlowGL.User.Pause"); });

			playFn(false);
		}
	}

	private function onFullScreen() : Void {
		if (nativeWidget != null) {
			RenderSupportJSPixi.fullScreenTrigger();

			if (RenderSupportJSPixi.IsFullScreen) {
				Browser.document.body.appendChild(nativeWidget);
			} else {
				Browser.document.body.removeChild(nativeWidget);
			}

		}
	}


	public function addStreamStatusListener(fn : String -> Void) : Void -> Void {
		streamStatusListener.push(fn);
		return function () { streamStatusListener.remove(fn); };
	}

	public function addVideoSource(src : String, type : String) : Void {
		var source = Browser.document.createElement('source');

		untyped source.src = src;
		if (type != "") {
			untyped source.type = type;
		}

		sources.push(source);

		if (nativeWidget != null) {
			nativeWidget.appendChild(source);
		}
	}

	private function createStreamStatusListeners() {
		if (nativeWidget != null) {
			nativeWidget.addEventListener('loadedmetadata', onMetadataLoaded, false);
			nativeWidget.addEventListener('resize', updateVideoMetrics, false);
			nativeWidget.addEventListener("loadeddata", onStreamLoaded, false);
			nativeWidget.addEventListener("ended", onStreamEnded, false);
			nativeWidget.addEventListener("error", onStreamError, false);
			nativeWidget.addEventListener("play", onStreamPlay, false);
			nativeWidget.addEventListener("pause", onStreamPause, false);
		}
	}

	private function destroyStreamStatusListeners() {
		if (nativeWidget != null) {
			nativeWidget.removeEventListener('loadedmetadata', onMetadataLoaded);
			nativeWidget.removeEventListener('resize', updateVideoMetrics);
			nativeWidget.removeEventListener("loadeddata", onStreamLoaded);
			nativeWidget.removeEventListener("ended", onStreamEnded);
			nativeWidget.removeEventListener("error", onStreamError);
			nativeWidget.removeEventListener("play", onStreamPlay);
			nativeWidget.removeEventListener("pause", onStreamPause);
		}
	}

	private function createFullScreenListeners() {
		if (nativeWidget != null) {
			if (Platform.isIOS) {
				nativeWidget.addEventListener('webkitbeginfullscreen', onFullScreen, false);
				nativeWidget.addEventListener('webkitendfullscreen', onFullScreen, false);
			}

			nativeWidget.addEventListener('fullscreenchange', onFullScreen, false);
			nativeWidget.addEventListener('webkitfullscreenchange', onFullScreen, false);
			nativeWidget.addEventListener('mozfullscreenchange', onFullScreen, false);
		}
	}

	private function destroyFullScreenListeners() {
		if (nativeWidget != null) {
			if (Platform.isIOS) {
				nativeWidget.removeEventListener('webkitbeginfullscreen', onFullScreen);
				nativeWidget.removeEventListener('webkitendfullscreen', onFullScreen);
			}

			nativeWidget.removeEventListener('fullscreenchange', onFullScreen);
			nativeWidget.removeEventListener('webkitfullscreenchange', onFullScreen);
			nativeWidget.removeEventListener('mozfullscreenchange', onFullScreen);
		}
	}

	public function getCurrentFrame() : String {
		try {
			if (textField != null && textField.visible) {
				textField.visible = false;
				var data = RenderSupportJSPixi.PixiRenderer.plugins.extract.base64(this);
				textField.visible = true;

				return data;
			} else {
				var data = RenderSupportJSPixi.PixiRenderer.plugins.extract.base64(this);

				return data;
			}
		} catch (e : Dynamic) {
			return haxe.Serializer.run(e); //"error";
		}
	}

	public override function getLocalBounds(?rect : Rectangle) : Rectangle {
		return localBounds.getRectangle(rect);
	}

	private override function createNativeWidget(?node_name : String = "video") : Void {
		deleteNativeWidget();

		nativeWidget = Browser.document.createElement(node_name);
		nativeWidget.setAttribute('id', getClipUUID());
		nativeWidget.className = 'nativeWidget';

		updateNativeWidgetDisplay();

		onAdded(function() { addNativeWidget(); return removeNativeWidget; });
	}
}