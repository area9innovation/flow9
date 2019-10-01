import js.Browser;
import js.html.Element;

import pixi.core.display.Bounds;
import pixi.core.display.DisplayObject;
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

	public var keepNativeWidget : Bool = true;

	private static var playingVideos : Array<VideoClip> = new Array<VideoClip>();

	public static var CanAutoPlay = false;

	private var videoWidget : Dynamic;
	private var widgetBounds = new Bounds();

	public static inline function NeedsDrawing() : Bool {
		var playingVideosFiltered =
			playingVideos.filter(function (v) {
				var videoWidget = v.videoWidget;
				if (videoWidget == null) {
					return false;
				}
				v.checkTimeRange(videoWidget.currentTime, true);

				if (!RenderSupportJSPixi.DomRenderer) {
					if (videoWidget.width != videoWidget.videoWidth || videoWidget.height != videoWidget.videoHeight) {
						videoWidget.dispatchEvent(new js.html.Event("resize"));
					}
				}

				return v.getClipRenderable();
			});

		if (playingVideosFiltered.length > 0) {
			Browser.window.dispatchEvent(Platform.isIE ? untyped __js__("new CustomEvent('videoplaying')") : new js.html.Event('videoplaying'));
			return true;
		}

		return false;
	}

	public function new(metricsFn : Float -> Float -> Void, playFn : Bool -> Void, durationFn : Float -> Void, positionFn : Float -> Void) {
		super();

		this.metricsFn = metricsFn;
		this.playFn = playFn;
		this.durationFn = durationFn;
		this.positionFn = positionFn;
	}

	private function checkTimeRange(currentTime : Float, videoResponse : Bool) : Void {
		try { // Crashes in IE sometimes
			if (currentTime < startTime && startTime < videoWidget.duration) {
				videoWidget.currentTime = startTime;
				positionFn(videoWidget.currentTime);
			} else if (endTime > 0 && endTime > startTime && currentTime >= endTime) {
				if (videoWidget.paused) {
					videoWidget.currentTime = endTime;
				} else {
					videoWidget.currentTime = startTime;
					if (!videoWidget.loop) videoWidget.pause();
				}
				positionFn(videoWidget.currentTime);
			} else if (videoResponse) {
				positionFn(videoWidget.currentTime);
			} else {
				videoWidget.currentTime = currentTime;
			}
		} catch (e : Dynamic) {}
	}

	private function createVideoClip(filename : String, startPaused : Bool) : Void {
		deleteVideoClip();

		addVideoSource(filename, "");
		videoWidget = Browser.document.createElement("video");

		if (RenderSupportJSPixi.DomRenderer) {
			initNativeWidget("div");
			nativeWidget.appendChild(videoWidget);
		}

		videoWidget.crossorigin = Util.determineCrossOrigin(filename);
		videoWidget.autoplay = !startPaused;
		videoWidget.className = 'nativeWidget';
		videoWidget.setAttribute('playsinline', true);
		videoWidget.style.pointerEvents = 'none';

		for (source in sources) {
			videoWidget.appendChild(source);
		}

		if (videoWidget.autoplay) {
			if (playingVideos.indexOf(this) < 0) playingVideos.push(this);
		}

		if (!RenderSupportJSPixi.DomRenderer) {
			videoTexture = Texture.fromVideo(videoWidget);
			untyped videoTexture.baseTexture.autoPlay = !startPaused;
			untyped videoTexture.baseTexture.autoUpdate = false;
			videoSprite = new Sprite(videoTexture);
			untyped videoSprite._visible = true;
			addChild(videoSprite);
		}

		createStreamStatusListeners();
		createFullScreenListeners();

		once("removed", deleteVideoClip);

		if (!startPaused && !CanAutoPlay) {
			playFn(false);
		}
	}

	private function deleteVideoClip() : Void {
		if (videoWidget != null) {
			videoWidget.autoplay = false;
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
			updateNativeWidgetTransformMatrix();
			updateNativeWidgetOpacity();
			updateNativeWidgetMask();
			nativeWidget.style.transform = 'none';

			var width = Math.round(getWidth() * untyped this.transform.scale.x);
			var height = Math.round(getHeight() * untyped this.transform.scale.y);

			videoWidget.width = width;
			videoWidget.height = height;

			videoWidget.setAttribute('width', '${width}');
			videoWidget.setAttribute('height', '${height}');
			videoWidget.style.width = '${width}px';
			videoWidget.style.height = '${height}px';

			updateSubtitlesClip();

			if (RenderSupportJSPixi.DomInteractions) {
				updateNativeWidgetInteractive();
			}
		}

		updateNativeWidgetDisplay();
	}

	public function getDescription() : String {
		return videoWidget != null ? 'VideoClip (url = ${videoWidget.url})' : '';
	}

	public function setVolume(volume : Float) : Void {
		if (videoWidget != null) {
			videoWidget.volume = volume;
		}
	}

	public function setLooping(loop : Bool) : Void {
		if (videoWidget != null) {
			videoWidget.loop = loop;
		}
	}

	public function playVideo(filename : String, startPaused : Bool) : Void {
		createVideoClip(filename, startPaused);
	}

	public function playVideoFromMediaStream(mediaStream : js.html.MediaStream, startPaused : Bool) : Void {
		createVideoClip("", startPaused);
		videoWidget.srcObject = mediaStream;
	}

	public function setTimeRange(start : Float, end : Float) : Void {
		startTime = start >= 0 ? start : 0;
		endTime = end > startTime ? end : videoWidget.duration;
		checkTimeRange(videoWidget.currentTime, true);
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
		if (videoWidget != null) {
			videoWidget.playbackRate = rate;
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
		if (videoWidget != null && textField != null) {
			if (videoWidget.width == 0) {
				textField.setClipVisible(false);
			} else {
				textField.setClipVisible(true);
				textField.setClipX((videoWidget.width - textField.getWidth()) / 2.0);
				textField.setClipY(videoWidget.height - textField.getHeight() - 2.0);

				textField.invalidateTransform("updateSubtitlesClip");
			}
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
		return videoWidget != null ? videoWidget.currentTime : 0;
	}

	public function pauseVideo() : Void {
		if (loaded && !videoWidget.paused) {
			videoWidget.pause();
			if (playingVideos.indexOf(this) >= 0) playingVideos.remove(this);
		}
	}

	public function resumeVideo() : Void {
		if (loaded && videoWidget.paused) {
			videoWidget.play();
			if (playingVideos.indexOf(this) < 0) playingVideos.push(this);
		}
	}

	private function onMetadataLoaded() {
		durationFn(videoWidget.duration);

		updateVideoMetrics();

		videoWidget.currentTime = 0;
		checkTimeRange(videoWidget.currentTime, true);

		invalidateTransform('onMetadataLoaded'); // Update the widget

		if (!videoWidget.autoplay) videoWidget.pause();

		if (textField != null) {
			if (!RenderSupportJSPixi.DomRenderer && getChildIndex(videoSprite) > getChildIndex(textField)) {
				swapChildren(videoSprite, textField);
			}

			updateSubtitlesClip();
		};

		if (!RenderSupportJSPixi.DomRenderer) {
			videoTexture.update();
		}

		loaded = true;
	}

	private function updateVideoMetrics() {
		metricsFn(videoWidget.videoWidth, videoWidget.videoHeight);

		calculateWidgetBounds();
		invalidateTransform('updateVideoMetrics');

		if (RenderSupportJSPixi.DomRenderer) {
			videoWidget.style.width = '${untyped getWidth()}px';
			videoWidget.style.height = '${untyped getHeight()}px';
		} else {
			videoWidget.width = videoWidget.videoWidth;
			videoWidget.height = videoWidget.videoHeight;
			videoTexture.update();
		}
	}

	private function onStreamLoaded() : Void {
		streamStatusListener.map(function (l) { l("NetStream.Play.Start"); });
	}

	private function onStreamEnded() : Void {
		if (!videoWidget.autoplay) {
			if (playingVideos.indexOf(this) >= 0) playingVideos.remove(this);
		}

		streamStatusListener.map(function (l) { l("NetStream.Play.Stop"); });
	}

	private function onStreamError() : Void {
		streamStatusListener.map(function (l) { l("NetStream.Play.StreamNotFound"); });
	}

	private function onStreamPlay() : Void {
		if (videoWidget != null && !videoWidget.paused) {
			streamStatusListener.map(function (l) { l("FlowGL.User.Resume"); });

			playFn(true);
		}
	}

	private function onStreamPause() : Void {
		if (videoWidget != null && videoWidget.paused) {
			streamStatusListener.map(function (l) { l("FlowGL.User.Pause"); });

			playFn(false);
		}
	}

	private function onFullScreen() : Void {
		if (videoWidget != null) {
			RenderSupportJSPixi.fullScreenTrigger();

			if (RenderSupportJSPixi.IsFullScreen) {
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

	public function addVideoSource(src : String, type : String) : Void {
		var source = Browser.document.createElement('source');

		untyped source.src = src;
		if (type != "") {
			untyped source.type = type;
		}

		sources.push(source);

		if (videoWidget != null) {
			videoWidget.appendChild(source);
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

		deleteNativeWidget();

		nativeWidget = Browser.document.createElement(tagName);
		updateClipID();
		nativeWidget.className = 'nativeWidget';

		isNativeWidget = true;
	}
}