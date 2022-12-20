#if (js && !flow_nodejs)
import js.Browser;
import js.html.SpeechSynthesisVoice;
import js.html.SpeechSynthesisUtterance;
#end

class SoundSupport {
	public function new() {}
	// play : (string) -> void
	#if (js && !flow_nodejs)
	// JoinedAudio : The way to play mp3's on Mobile Safari and others
	// from any place in the code
	// (not only the user action handler)
	private static var AudioStream : Dynamic;
	private static inline var AudioStreamUrl = "php/mp3stream/stream.php";
	private static var UseAudioStream : Bool;

	private static var hasSpeechSupport : Bool;
	//push utterance to global array, so chrome garbage collector won't remove it (https://bugs.chromium.org/p/chromium/issues/detail?id=509488)
	private static var utterancesArray = [];

	public static function __init__() {
		UseAudioStream = ("1" == Util.getParameter("mp3stream"));
		
		hasSpeechSupport = untyped __js__("'speechSynthesis' in window");

		if(hasSpeechSupport) {
			Browser.window.addEventListener("beforeunload", function(){
				clearSpeechSynthesisQueueNative();
			});
		}
	}
	#end

	public static function play(f : String) : Void {
		#if (js && !flow_nodejs)
			var s : Dynamic = Browser.document.createElement("AUDIO");
			// Workaround for browsers which cannot play mp3
			// Note : f is supposed to be mp3
			if (!(!!(s.canPlayType) && ("no" != s.canPlayType("audio/mpeg")) && ("" != s.canPlayType("audio/mpeg")))) {
				var e : Dynamic = Browser.document.createElement("EMBED");
				e.setAttribute("hidden", "true");
				e.setAttribute("src", f);
				e.setAttribute("autostart", "true");
				Browser.document.body.appendChild(e);
			} else {
				s.src = f;
				s.play();
			}
		#elseif flash
			var success = internal_play(f);
		#end
	}

	#if flash
	static function internal_play(url : String) : Bool {
		var s = new flash.media.Sound();

		try {
			var request = new flash.net.URLRequest(url);
			s.load(request);
			var soundChannel = s.play();

			if (soundChannel != null) {
				return true;
			} else {
				trace("Null soundchannel opening " + url);
			}
		} catch (e : flash.events.IOErrorEvent) {
			// Unfortunately, this does not catch our mistakes: It seems some errors are thrown asynchronously
			trace("IOErrorEvent opening " + url);
		} catch (e : flash.events.SecurityErrorEvent) {
			trace("IOErrorEvent opening " + url);
		} catch (e : flash.events.StatusEvent) {
			trace(e.toString());
		}
		return false;
	}
	#end

	// loadSound : (url : String, onFail : (message : string) -> {}) -> native
	public static function loadSound(url : String, onFail : String -> Void, onComplete : Void -> Void) : Dynamic {
		#if (js && !flow_nodejs)
			if (UseAudioStream) {
				haxe.Timer.delay(onComplete, 200);
				return url;
			}
			try {
				var audio = untyped __js__ ("new Audio()");
				audio.src = url;

				var remove_listeners : Dynamic = null;
				var oncanplay = function() {
					if (Util.getParameter("devtrace") == "1") Errors.print(url + " loaded");
					onComplete();
					remove_listeners();
				};
				var onerror = function() { Errors.print("Cannot load: " + url); onFail("" + audio.error); remove_listeners(); };
				remove_listeners = function() { audio.removeEventListener("canplay", oncanplay); audio.removeEventListener("error", onerror); };

				audio.addEventListener("canplay", oncanplay);
				audio.addEventListener("error",  onerror);
				audio.load();

				return audio;
			} catch (e : Dynamic) {
				Errors.print("Exception while loading audio: " + e);
				return null;
			}
		#elseif flash
			var fail = function(message) {
				onFail(message);
			};

			var complete = function() {
				onComplete();
			}

			var s = new flash.media.Sound();
			s.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function(e) {
				fail("Could not open sound " + url);
			} );
			s.addEventListener(flash.events.Event.COMPLETE, function(e) {
				complete();
			} );

			try {
				s.load(new flash.net.URLRequest(url));
			} catch (e : flash.events.IOErrorEvent) {
				// Unfortunately, this does not catch our mistakes: It seems some errors are thrown asynchronously
				fail("Could not open " + url);
			} catch (e : flash.events.SecurityErrorEvent) {
				fail(e.toString());
			} catch (e : flash.events.StatusEvent) {
				fail(e.toString());
			}

			return s;
		#end
		return null;
	}

	#if (js && !flow_nodejs)
	private static function createStreamPlayer() {
		haxe.Timer.delay( function() {
			AudioStream  = Browser.document.createElement("AUDIO");
			AudioStream.setAttribute("controls", "");
			AudioStream.style.position = "absolute";
			AudioStream.style.left = AudioStream.style.top = "30px";
			AudioStream.style.zIndex = 2000;
			AudioStream.src = AudioStreamUrl;
			Browser.document.body.appendChild(AudioStream);
		}, 200);
	}

	private static function pushSoundToLiveStream(url : String, onDone : Void -> Void) : Void {
		var loader = new js.html.XMLHttpRequest();
		loader.open("GET", AudioStreamUrl+ "?pushsnd=" + url, true);
		untyped loader.addEventListener("load", function(e : Dynamic) {
			if (loader.responseText != "") {
				if (AudioStream == null) createStreamPlayer();
				haxe.Timer.delay(onDone, 1000 * Std.int(Std.parseFloat(loader.responseText)));
			} else {
				onDone();
			}
		}, false);
		untyped loader.addEventListener("error", function(e : Dynamic) { onDone(); }, false);
		loader.send("");
	}
	#end
	//playSound : (native, loop : bool, onDone : () -> void) -> native (SoundChannel)
	public static function playSound(s : Dynamic, loop : Bool, onDone : Void -> Void) : Dynamic {
		#if (js && !flow_nodejs)
			if (UseAudioStream) {
				pushSoundToLiveStream(s, onDone);
				return s;
			}

			var audio = s;
			var url : String = audio.currentSrc;

			var remove_listeners : Dynamic = null;
			var onended = function() {
				if (Util.getParameter("devtrace") == "1") Errors.print(url + " ended");
				onDone();
				remove_listeners();
			};
			var onerror = function() { Errors.print("Cannot play: " + url); onDone(); remove_listeners(); };
			remove_listeners = function() { audio.removeEventListener("ended", onended); audio.removeEventListener("error", onerror); };

			audio.addEventListener("ended", onended);
			audio.addEventListener("error",  onerror);
			audio.play();

			return audio;
		#elseif flash
			var done = function() {
				onDone();
			};
			try {
				var soundChannel : flash.media.SoundChannel =
					if (loop) s.play(50, 10000);
					else  s.play();


				if (soundChannel != null) {
					soundChannel.addEventListener(flash.events.Event.SOUND_COMPLETE, function(d) { done(); } );
					return soundChannel;
				}
			} catch (e : flash.events.IOErrorEvent) {
				// Unfortunately, this does not catch our mistakes: It seems some errors are thrown asynchronously
				//trace("Could not open " + url);
				//fail();
			} catch (e : flash.events.SecurityErrorEvent) {
				//fail();
			} catch (e : flash.events.StatusEvent) {
				//trace(e.toString());
				//fail();
			}
			return null;
		#end
      return null;
	}

	//setVolume : (native, double) -> void
	public static function setVolume(s : Dynamic, newVolume : Float) : Void {
		#if (js && !flow_nodejs)
			if (s != null)
				s.volume = newVolume;
		#elseif flash
			var soundChannel : flash.media.SoundChannel = s;
			try {
				if (soundChannel != null) {
					soundChannel.soundTransform = new flash.media.SoundTransform(newVolume, 0.0);
				}
			} catch (e : flash.events.IOErrorEvent) {
				// Unfortunately, this does not catch our mistakes: It seems some errors are thrown asynchronously
				//trace("Could not open " + url);
				//fail();
			} catch (e : flash.events.SecurityErrorEvent) {
				//fail();
			} catch (e : flash.events.StatusEvent) {
				//trace(e.toString());
				//fail();
			}
		#end
	}

	//stopSound : (native) -> void
	public static function stopSound(s : Dynamic) : Dynamic {
		#if (js && !flow_nodejs)
			if (s != null && s.pause != null)
				s.pause();
		#elseif flash
			var soundChannel : flash.media.SoundChannel = s;
			if (soundChannel != null) {
				soundChannel.stop();
			}
		#end
		return null;
	}

	public static function noSound() : Dynamic {
		return null;
	}

	//native playSoundFrom : io (native, cue : double, onDone : () -> void) -> native /*SoundChannel*/ = SoundSupport.playSoundFrom;
	public static function playSoundFrom(s : Dynamic, cue : Float, onDone : Void -> Void) : Dynamic {
		var done = function() {
			onDone();
		};
		#if (js && !flow_nodejs)
			if (s == null) return null;
			s.addEventListener("ended", done, false);
			s.addEventListener("error", done, false);
			s.currentTime = cue / 1000.0;
			s.play();
			return s;
		#elseif flash
			try {
				var soundChannel : flash.media.SoundChannel =
					s.play(cue);

				if (soundChannel != null) {
					soundChannel.addEventListener(flash.events.Event.SOUND_COMPLETE, function(d) { done(); } );
					return soundChannel;
				}
			} catch (e : flash.events.IOErrorEvent) {
				// Unfortunately, this does not catch our mistakes: It seems some errors are thrown asynchronously
				//trace("Could not open " + url);
				//fail();
			} catch (e : flash.events.SecurityErrorEvent) {
				//fail();
			} catch (e : flash.events.StatusEvent) {
				//trace(e.toString());
				//fail();
			}
			return null;
		#end
      return null;
	}

	//native getSoundLength : io (native /*Sound*/) -> double = SoundSupport.getSoundLength;
	public static function getSoundLength(s : Dynamic) : Float {
		#if (js && !flow_nodejs)
			if (s != null)
				return s.duration * 1000.0;
			else
				return 0.0;
		#elseif flash
			var sound : flash.media.Sound = s;
			if (sound != null) {
				return sound.length;
			}
		#end
		return 0.0;
	}

	//native getSoundPosition : io (native /*SoundChannel*/) -> double = SoundSupport.getSoundPosition;
	public static function getSoundPosition(s : Dynamic) : Float {
		#if (js && !flow_nodejs)
			if (s != null)
				return s.currentTime * 1000.0;
			else
				return 0.0;
		#elseif flash
			var soundChannel : flash.media.SoundChannel = s;
			if (soundChannel != null) {
				return soundChannel.position;
			}
		#end
		return 0.0;
	}

	public static function addDeviceVolumeEventListener(callback : Float -> Void) : Void -> Void {
		return function () { };
	}

	public static function getAudioSessionCategory() : String {
		return "soloambient";
	}

	public static function setAudioSessionCategory(category : String) : Void {
		// Not require to be implemented
	}

	public static function removeUtteranceFromGlobalArray(utterThis : Dynamic) {
		#if (js && !flow_nodejs)
			if (hasSpeechSupport) {
				var utteranceIndex = utterancesArray.indexOf(utterThis);
				if (utteranceIndex > -1) {
					utterancesArray.splice(utteranceIndex, 1);
				}
			}
		#end
	}

	public static function resumeSpeechSynthesisNative() : Void {
		#if (js && !flow_nodejs)
			if (hasSpeechSupport) {
				Browser.window.speechSynthesis.resume();
			}
		#end
	}

	public static function pauseSpeechSynthesisNative() : Void {
		#if (js && !flow_nodejs)
			if (hasSpeechSupport) {
				Browser.window.speechSynthesis.pause();
			}
		#end
	}

	public static function clearSpeechSynthesisQueueNative() : Void {
		#if (js && !flow_nodejs)
			if (hasSpeechSupport) {
				Browser.window.speechSynthesis.cancel();
			}
		#end
	}

	public static function performSpeechSynthesis(speak : String, voiceUri : String, lang : String, pitch : Float,
			rate : Float, volume : Float, onReady : Void -> Void, onBoundary : Int -> Float -> Void, onEnd : Void -> Void, onError : Void -> Void) : Void {

	#if (js && !flow_nodejs)
		if (hasSpeechSupport) {
			var synth = Browser.window.speechSynthesis;
			var utterThis = new SpeechSynthesisUtterance(speak);
			utterancesArray.push(utterThis);
			if (voiceUri != "") {
				var voices = synth.getVoices();
				for (voice in voices) {
					if (voice.voiceURI == voiceUri) utterThis.voice = voice;
				}
			}
			if (lang != "") {
				utterThis.lang = lang;
			}
			utterThis.pitch = pitch;
			utterThis.rate = rate;
			utterThis.volume = volume;

			utterThis.addEventListener("start", function() {
				synth.pause();
				onReady();
			});

			utterThis.addEventListener("boundary", function(event) {
				onBoundary(event.charIndex, event.elapsedTime);
			});

			utterThis.addEventListener("error", function() {
				onError();
				removeUtteranceFromGlobalArray(utterThis);
			});

			utterThis.addEventListener("end", function() {
				onEnd();
				removeUtteranceFromGlobalArray(utterThis);
			});

			synth.speak(utterThis);

		}
	#end
	}

	public static function getAvailableVoices(callback : Array<Array<String>> -> Void) : Void {
	#if (js && !flow_nodejs)
		if (hasSpeechSupport) {
			var voices = Browser.window.speechSynthesis.getVoices();
			if (voices.length == 0) {
				waitForVoices(callback);
			} else {
				callback(mapSpeechSynthesisVoices(voices));
			}
		}
	#end
	}

	private static function waitForVoices(callback : Array<Array<String>> -> Void) : Void {
	#if (js && !flow_nodejs)
		if (hasSpeechSupport) {
			untyped Browser.window.speechSynthesis.addEventListener(
				"voiceschanged",
				function() { getAvailableVoices(callback); }
			);
		}
	#end
	}

	#if (js && !flow_nodejs)
	private static function mapSpeechSynthesisVoices(voices : Array<SpeechSynthesisVoice>) : Array<Array<String>> {
		var i = 0;
		var result : Array<Array<String>> = new Array<Array<String>>();
		for (voice in voices) {
			var res = new Array<String>();
			res[0] = voice.voiceURI;
			res[1] = voice.name;
			res[2] = voice.lang;
			result[i++] = res;
		}
		return result;
	}
	#end

	public static function makeSpeechRecognition(continuous : Bool, interimResults : Bool, maxAlternatives : Int, lang : String) : Dynamic {
	#if (js && !flow_nodejs)
		if (hasSpeechSupport) {
		  	untyped __js__("var SpeechRecognition = SpeechRecognition || webkitSpeechRecognition");
			var recognition = untyped __js__("new SpeechRecognition();");

			setSpeechRecognitionContinious(recognition, continuous);
	  		setSpeechRecognitionInterimResults(recognition, interimResults);
	  		setSpeechRecognitionMaxAlternatives(recognition, maxAlternatives);
	  		if (lang != "")
	  			setSpeechRecognitionLang(recognition, lang);

			return recognition;
		} else {
			return null;
		}
	#else
		return null;
	#end
	}

	public static function startSpeechRecognition(recognition : Dynamic) : Void -> Void {
		if (recognition != null) {
			recognition.stop();
			recognition.start();
			return function () { recognition.stop(); };
		} else {
			return function () {};
		}
	}

	public static function setSpeechRecognitionContinious(recognition : Dynamic, continuous : Bool) : Void {
		if (recognition != null) recognition.continuous = continuous;
	}

	public static function setSpeechRecognitionInterimResults(recognition : Dynamic, interimResults : Bool) : Void {
		if (recognition != null) recognition.interimResults = interimResults;
	}

	public static function setSpeechRecognitionMaxAlternatives(recognition : Dynamic, maxAlternatives : Int) : Void {
		if (recognition != null) recognition.maxAlternatives = maxAlternatives;
	}

	public static function setSpeechRecognitionLang(recognition : Dynamic, lang : String) : Void {
		if (recognition != null) recognition.lang = lang;
	}

	public static function setSpeechRecognitionServiceURI(recognition : Dynamic, uri : String) : Void {
		if (recognition != null) recognition.serviceURI = uri;
	}

	public static function addSpeechRecognitionGrammar(recognition : Dynamic, grammar : String) : Void {
		if (recognition != null) recognition.grammars.addFromString(grammar, 1);
	}

	public static function addSpeechRecognitionGrammarFromURI(recognition : Dynamic, uri : String) : Void {
		if (recognition != null) recognition.grammars.addFromURI(uri, 1);
	}

	public static function clearSpeechRecognitionGrammars(recognition : Dynamic) : Void {
	#if (js && !flow_nodejs)
		if (recognition != null) {
			untyped __js__("var SpeechGrammarList = SpeechGrammarList || webkitSpeechGrammarList;");
			recognition.grammars = untyped __js__("new SpeechGrammarList();");
		}
	#end
	}

	public static function addSpeechRecognitionEventListener(recognition : Dynamic, event : String, cb : String -> Void) : Void {
		if (recognition != null) {
			if (event == "onresult")
				recognition.onresult = function (e) {
					var i = e.resultIndex;
				  	while (i < e.results.length) {
				  		// trace(untyped e.results[i][0].transcript);
				  		cb(untyped e.results[i][0].transcript);
				  		++i;
						// if (e.results[i].isFinal) {
						// 	textarea.value += e.results[i][0].transcript;
						// }
					}
				}
			else if (event == "onerror")
				recognition.onerror = function (e) {
					cb("Error :");
				}
			else if (event == "onnomatch")
				recognition.onnomatch = function (e) {
					cb("No match :");
				}
			else if (event == "onstart")
				recognition.onstart = function (e) {
					cb("Started");
				}
			else if (event == "onend")
				recognition.onend = function (e) {
					cb("Ended");
				}
			else if (event == "onspeechstart")
				recognition.onspeechstart = function (e) {
					cb("Speech Started");
				}
			else if (event == "onspeechend")
				recognition.onspeechend = function (e) {
					cb("Speech Ended");
				}
			else if (event == "onsoundstart")
				recognition.onsoundstart = function (e) {
					cb("Sound Started");
				}
			else if (event == "onsoundend")
				recognition.onsoundend = function (e) {
					cb("Sound Ended");
				}
			else if (event == "onaudiostart")
				recognition.onaudiostart = function (e) {
					cb("Audio Started");
				}
			else if (event == "onaudioend")
				recognition.onaudioend = function (e) {
					cb("Audio Ended");
				}
		}
	}
}
