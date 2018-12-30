import arctic.Arctic;
import arctic.ArcticBlock;
import arctic.ArcticView;
import arctic.ArcticMC;

class LabsSplash {
	static private var request;
	
	static public function main() {
		flash.Lib.current.stage.scaleMode = flash.display.StageScaleMode.NO_SCALE;
		var parent = flash.Lib.current;
		drawSplash(parent);
		targetURL = flashParameter("name") + ".swf";
		var target = flashParameter("_target");
		if (target != null && target != "") {
			targetURL = target;
		}
		var noStamp = flashParameter("_nostamp");
		if (noStamp != null && noStamp == "true") {
			load(Date.now().getTime());
		} else {
			checkFileStamp(targetURL);
		}
	}

	static private function checkFileStamp(targetURL) {
		var stampUrl = "php/stamp.php";
		var stampRequest = new flash.net.URLRequest(stampUrl);
		var stampLoader = new flash.net.URLLoader();
		var vars = new flash.net.URLVariables();
		vars.file = targetURL;
		vars.t = Date.now().getTime();
		stampRequest.data = vars;

		var onBadStamp = function(e){
			load(Date.now().getTime());
		}

		stampLoader.addEventListener(flash.events.Event.COMPLETE, 
			function(e) {
				var l: flash.net.URLLoader = e.target;
				load(l.data);
			}
		);
		stampLoader.addEventListener(flash.events.IOErrorEvent.IO_ERROR, onBadStamp);
		stampLoader.addEventListener(flash.events.ErrorEvent.ERROR, onBadStamp);

		stampLoader.load(stampRequest);
	}

	static private function load(stamp = 0.0) {
		request = new flash.net.URLRequest(targetURL);
		var parameters = flash.Lib.current.loaderInfo.parameters;

		var vars = new flash.net.URLVariables();
		// Make sure we request the latest SWF
		vars.t = "" + stamp;

		var paramsArray = new Array();
		paramsArray = Reflect.fields(parameters);

		for(i in paramsArray){
			var value = Reflect.field(parameters, i);
			// name is passed anyway so that swf itself knows what is started
			Reflect.setField(vars, i, value);
		}

		request.data = vars;

		var context = new flash.system.LoaderContext(false, new flash.system.ApplicationDomain());
		loader = new flash.display.Loader();
		var cli = loader.contentLoaderInfo;
		cli.addEventListener(flash.events.Event.COMPLETE, completeHandler);
		cli.addEventListener(flash.events.IOErrorEvent.IO_ERROR, ioErrorHandler);
		cli.addEventListener(flash.events.SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
		cli.addEventListener(flash.events.ProgressEvent.PROGRESS, progressHandler);
		try {
			loader.load(request, context);
		} catch (error : Dynamic) {
			trace("Unable to complete the request.");
		}
	}
	
	static private function drawSplash(parent) {
		//trace("drawSplash");
		
		updateProgressBar(0);
		
		splash = new MutableBlock(OnTop(
			Background(bgColor, Filler),
			Align(0.5, 0.5,
				Arctic.fixSize(sWidth * sScale, sHeight * sScale, 
					OnTop(
						Offset(15, -35, Picture(sURL, sWidth, sHeight, sScale)),
						Offset(0, 0, Align(0.5, 1.0, ConstrainHeight(32, 32, Align(0.5, 1.0, Mutable(progressBlock)))))
					)
				)
			)
		));
		
		arcticViewSplash = new ArcticView( Mutable(splash), parent );
		arcticViewSplash.display(true);
	}
	
	static private function updateProgressBar(percent : Float) {
		//trace("updateProgressBar, " + percent);

		var prBlock = OnTop(
			Filter(
				Glow(0x000000, 0.9, 5.0, 5.0, 1.0, 1),
				GradientBackground("linear", [0x868583, 0x4e4e4e], 0.0, 0.0,
					Arctic.fixSize( pbWidth, pbHeight+2, Filler),
					null, pbHeight, 1.5707963267948966192313216916398
				)
			),
			Offset(0, 1,
				Filter(
					Glow(0x000000, 0.9, 5.0, 5.0, 1.0, 1),
					GradientBackground("linear", [0xd85042, 0xd22d1d], 0.0, 0.0,
						Arctic.fixSize( pbWidth * percent / 100, pbHeight, Filler),
						null, pbHeight, 1.5707963267948966192313216916398
					)
				)
			)
		);
		
		prBlock = Filter(Bevel(2.0, 45.0, 0x000000, 0.5, 0xffffff, 0.5, 1.0, 1.0, 1, 1, 'inner', false), prBlock);
	
	#if nejm
	#else		
		if (flashParameter("name") == "smartbuilder") {
			prBlock = Offset(13, -98, OnTop(
				Background(0xffffff, Arctic.fixSize(pbWidth + 10, pbHeight + 10, Filler), null, 10),
				Offset(5, 5,
					Background(0xed5152, Arctic.fixSize( pbWidth * percent / 100, pbHeight, Filler), null, 10)
				)
			));
		}
	#end
		if (null == progressBlock) {
			progressBlock = new MutableBlock(prBlock);
		} else {
			progressBlock.block = prBlock;
		}
	}
	
	static private function build(payload : Dynamic, buildMode : BuildMode, parentMc : ArcticMovieClip, availableWidth : Float, availableHeight : Float, existingMc : ArcticMovieClip) : Metrics {
		switch (buildMode) {
			case Metrics:
				return {clip: existingMc, width: availableWidth, height: availableHeight, growHeight: true, growWidth: true};
			case Reuse:
				create();
				return {clip: existingMc, width: availableWidth, height: availableHeight, growHeight: true, growWidth: true};
			case Create:
				mc = ArcticMC.create(parentMc);
				create();
				return {clip: mc, width: availableWidth, height: availableHeight, growHeight: true, growWidth: true};
			case Destroy:
				return null;
		}
	}
	
	static private function create() {
		if (view != null) {
			mc.addChild(view);
		}
	}
	
	static private function completeHandler(event : flash.events.Event) : Void {
		//trace("completeHandler");
		updateProgressBar(100);
		
		try {
			view = loader.content;
			view = event.currentTarget.content;
			arcticViewSplash.destroy();
			arcticView = new ArcticView(CustomBlock(null, build), flash.Lib.current);
			arcticView.display(true);
		} catch ( e : Dynamic) {
			trace(e);
		}
	}
	
	static private function progressHandler(event : flash.events.ProgressEvent) : Void {
		//trace("progressHandler");
		var progressCount = Math.round(event.bytesLoaded / event.bytesTotal * 100);
		updateProgressBar(progressCount);
	}
	
	static private function securityErrorHandler(event : flash.events.SecurityErrorEvent) : Void {
		trace("Security error:" + event.text);
	}

	static private function ioErrorHandler(event : flash.events.IOErrorEvent) : Void {
		trace("IO error: " + event.text);
	}
	
	static private function flashParameter(name : String) : String {
		#if flash9
			var parameters = flash.Lib.current.loaderInfo.parameters;
			return Reflect.field(parameters, name);
		#elseif flash
			return
				Reflect.field(if (flash.Lib._root._parent != null) flash.Lib._root._parent else flash.Lib._root, name);
		#end
	}
	
	static private var targetURL : String;
	static private var arcticView : ArcticView;
	static private var progressBlock : MutableBlock;
	static private var splash : MutableBlock;
	
	// splash parameters
	static private var sVersion = "4";
	#if nejm
	static private var sURL = "images/NEJM/logonejm.png" + "?v=" + sVersion;
	static private var sWidth = 360;
	static private var sHeight = 70;
	static private var sScale = 0.7;
	static private var bgColor = 0xffffff;

	// options for progress bar
	static private var pbWidth = sWidth * sScale * 0.85;
	static private var pbHeight = 8;
	#else
	static private var sURL = if (flashParameter("name") == "smartbuilder") "images/splash/labs_new_splash.jpg?v=" else "images/splash/splashNoLogo.swf?v=" + sVersion+ sVersion;
	static private var sWidth = if (flashParameter("name") == "smartbuilder") 632 else 1050;
	static private var sHeight = if (flashParameter("name") == "smartbuilder") 445else 490;
	static private var sScale = if (flashParameter("name") == "smartbuilder") 1else 0.7;
	static private var bgColor = if (flashParameter("name") == "smartbuilder") 0xffffff else 0x262626;

	// options for progress bar
	static private var pbWidth = sWidth * sScale * if (flashParameter("name") == "smartbuilder") 0.82 else 0.85;
	static private var pbHeight = if (flashParameter("name") == "smartbuilder") 35 else 10;
	#end

	// something strange :)
	static private var mc : ArcticMovieClip;
	static private var view : Dynamic;
	static private var loader;
	
	static private var arcticViewSplash;
}
