import Flow;
import FlowArray;
import SoundSupportHx;

class SoundSupport {
	public function new(interpreter : Interpreter) {
		this.interpreter = interpreter;
	}
	
	var interpreter : Interpreter;
	private static var soundSupportHx : SoundSupportHx = new SoundSupportHx();

	// play : (string) -> void
	public function play(args : FlowArray<Flow>, pos : Position) : Flow  {
		var url = FlowUtil.getString(args[0]);
		SoundSupportHx.play(url);
		return ConstantVoid(pos);
	}

	// loadSound : (url : String, onFail : (message : string) -> {}) -> native
	public function loadSound(args : FlowArray<Flow>, pos : Position) : Flow  {
		var url = FlowUtil.getString(args[0]);
		var onFail = interpreter.registerRoot(args[1]);
		var onComplete = interpreter.registerRoot(args[2]);

		var me = this;
		
		var fail = function(message) {
			var r = me.interpreter.lookupRoot(onFail);
			me.interpreter.releaseRoot(onFail);
			me.interpreter.eval(Call(r, FlowArrayUtil.one(ConstantString(message, pos)), pos));
		};

		var complete = function() {
			var r = me.interpreter.lookupRoot(onComplete);
			me.interpreter.releaseRoot(onComplete);
			me.interpreter.eval(Call(r, new FlowArray(), pos));
		};

		return ConstantNative(SoundSupportHx.loadSound(url, fail, complete), pos);
	}

	
	//playSound : (native, loop : bool, onDone : () -> void) -> native (SoundChannel)
	public function playSound(args : FlowArray<Flow>, pos : Position) : Flow {
		var s  = FlowUtil.getNative(args[0]);
		var loop = FlowUtil.getBool(args[1]);
		var onDone = interpreter.registerRoot(args[2]);

		var me = this;

		var done = function() {
			var r = me.interpreter.lookupRoot(onDone);
			me.interpreter.releaseRoot(onDone);
			me.interpreter.eval(Call(r, new FlowArray(), pos));
		};
		
		return ConstantNative(SoundSupportHx.playSound(s, loop, done), pos);
	}

	//setVolume : (native, double) -> void
	public function setVolume(args : FlowArray<Flow>, pos : Position) : Flow {
		var soundChannel = FlowUtil.getNative(args[0]);
		var newVolume = FlowUtil.getDouble(args[1]);

		SoundSupportHx.setVolume(soundChannel, newVolume);
		return ConstantVoid(pos);
	}


	//stopSound : (native) -> void
	public function stopSound(args : FlowArray<Flow>, pos : Position) : Flow {
		var soundChannel = FlowUtil.getNative(args[0]);
		SoundSupportHx.stopSound(soundChannel);
		return ConstantVoid(pos);
	}

	public function noSound(args : FlowArray<Flow>, pos : Position) : Flow  {
		return ConstantNative(null, pos);
	}

	//native playSoundFrom : io (native, cue : double, onDone : () -> void) -> native /*SoundChannel*/ = SoundSupport.playSoundFrom;
	public function playSoundFrom(args : FlowArray<Flow>, pos : Position) : Flow {
			var s  = FlowUtil.getNative(args[0]);
			var cue = FlowUtil.getDouble(args[1]);
			var onDone = interpreter.registerRoot(args[2]);

			var me = this;

			var done = function() {
				var r = me.interpreter.lookupRoot(onDone);
				me.interpreter.releaseRoot(onDone);
				me.interpreter.eval(Call(r, new FlowArray(), pos));
			};
			return ConstantNative(SoundSupportHx.playSoundFrom(s, cue, done), pos);
	}

	//native getSoundLength : io (native /*Sound*/) -> double = SoundSupport.getSoundLength;
	public function getSoundLength(args : FlowArray<Flow>, pos : Position) : Flow {
		var sound = FlowUtil.getNative(args[0]);
		return ConstantDouble(SoundSupportHx.getSoundLength(sound), pos);
	}

	//native getSoundPosition : io (native /*SoundChannel*/) -> double = SoundSupport.getSoundPosition;
	public function getSoundPosition(args : FlowArray<Flow>, pos : Position) : Flow {
		var soundChannel = FlowUtil.getNative(args[0]);
		return ConstantDouble(SoundSupportHx.getSoundPosition(soundChannel), pos);
	}

	public function addDeviceVolumeEventListener(args : FlowArray<Flow>, pos : Position) : Flow {
		var fn = interpreter.registerRoot(args[0]);
		var me = this;
		var cb = function(volume : Float) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(fn), FlowArrayUtil.one(ConstantDouble(volume, pos)), pos));
		};

		var disp = SoundSupportHx.addDeviceVolumeEventListener(cb);
		return NativeClosure(0, function(flow, pos) {
			me.interpreter.releaseRoot(fn);
			disp();
			return ConstantVoid(pos);
		}, pos);
	}

	public function getAudioSessionCategory(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantString(SoundSupportHx.getAudioSessionCategory(), pos);
	}
	public function setAudioSessionCategory(args : FlowArray<Flow>, pos : Position) : Flow {
		var category = FlowUtil.getString(args[0]);

		SoundSupportHx.setAudioSessionCategory(category);

		return ConstantVoid(pos);
	}
}
