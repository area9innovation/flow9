import arctic.Arctic;
import arctic.ArcticBlock;
import arctic.ArcticView;
import arctic.ArcticMC;

class Splash {
	static private var request;
	
	static public function main() {
		Arctic.defaultFont = "Book";
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
						OnTop(
							Offset(15, -35, Picture(sURL, sWidth, sHeight, sPictureScale)),
							Offset(350, -15, getLogoBlock())
						),
						Offset(-15,progressOffset,Align(0.5, 1.0, ConstrainHeight(40, 40, Align(0.5, 1.0, Mutable(progressBlock)))))
					)
				)
			)
		));
		
		arcticViewSplash = new ArcticView( Mutable(splash), parent );
		arcticViewSplash.display(true);
	}
	
	static private function updateProgressBar(percent : Float) {
		//trace("updateProgressBar, " + percent);
		
		var prBlock = 
				Offset(0, #if innovation -50 #else 1 #end,
					OnTop(GradientBackground("linear", [0xd70424, 0xd80528], 0.0, 0.0,
						Arctic.fixSize( pbWidth * percent / 100, pbHeight, Filler),
						null, 10.0, 1.5707963267948966192313216916398, null
					),
					ConstrainWidth(pbWidth, pbWidth, Align(0.5, 0.5, Arctic.makeText( #if innovation "" #else "<b>LOADING</b>" #end, 18, false, false, false))))
					
					
		);
		
	
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

	static private function getLogoBlock() : ArcticBlock {
		if (flashParameter("name") == "smartbuilder") {
			return Offset(30, 40, LineStack([
				Arctic.makeText( "<b>SMARTBUILDER</b>", 30, "Book", false, false, false),
				Fixed(0, 30),
				ConstrainWidth(200, 250, Arctic.makeText("<b>" + tips[Math.floor(Math.random() * tips.length)] + "</b>", 18, "Book", false, true, false))
			]));
		} else {
			#if innovation
			return Fixed(0, 0);
			#elseif tm
			return Fixed(0, 0);
			#elseif customimage
			return Fixed(0, 0);
			#else
			return Picture(getLogoURL(), sWidth, sHeight, sScale);
			#end
		}
	}

	static private function getLogoURL() {
		logoPresent = true;
		if (flashParameter("name") == "learnsmart") {
			return "images/splash/Learnsmart.swf";
		} else if (flashParameter("name") == "smartbook"){
			return "images/splash/SmartBook_logo.swf";
		} else {
			return "images/splash/Gear_logo.swf";
		}
	}

	static private var tips = [
		"Tip: Use Ctrl-Z or Cmd-Z to undo a step of work. This works for multiple steps.",
		"Tip: Use Ctrl-C or Cmd-C for copy and Ctrl-V or Cmd-V for paste.",
		"Tip: Use double click to highlight a word and triple-click to highlight a sentence for editing.",
		"Tip: Use FastSave to save your work in the product as you continue to edit.",
		"Tip: There are often additional options for probes in the Style menu.",
		"Tip: The SlideStrip LR is great for historical timelines and explaining procedures.",
		"Tip: Less is more in the digital world. Use more slides or LRs rather than writing a textbook on one slide.",
		"Tip: Check out the Awesome SmartBuilder Showcase if you want to see creative probes and LRs.",
		"Tip: Choose \"Authoring Wiki\" from the FAQ dropdown for Smartbuilder documentation.",
		"Tip: Slide Templates can be used in Slides and Slidestrip for easy placement of text and images.",
		"You can upload a video file, audio file, or captioning file using the “Add Decorated Image” icon.",
		"Tip: You can add alternate text and copyright info right when you upload an image.",
		"Tip: Use ActiveArt to create fill-in-the-blanks on images, buttons, hotspot probes, and more.",
		"Tip: Use the DEMO tag on LOs that you want to show up in your product demos.",
		"Tip: Use Multitab in Multiprobe to give students access to multiple screens of reference information.",
		"Tip: Make sure your directions on Matching probes describe what each side of the matching represents.",
		"Tip: If the matching probe uses several repeated words, make sure that the repeated words are in the left column.",
		"Tip: Make sure your directions on Ranking probes clearly indicate what to rank at the top and bottom.",
		"Tip: Cloze probes, Hotspot probes, and Drag & Drop probes can all be created with Wiki Probes.",
		"Tip: Take the training to get up to speed with creating content in SmartBuilder - and experience how a course is delivered to the student!",
		"Tip: Generally LRs should be granular and cover only one LO. ",
		"Tip: Slidestrips and kaleidoscopes covering a broader topic can be shared between several LOs.",
		"Tip: When there is a lot of text on the slide, and the coach is also talking, this can be very confusing for students. Try to avoid this.",
		"Tip: Use the Icon Library to add an icon to the cells in a Slidestrip.",
		"Tip: If you are building a SlideStrip with repetitive elements, make one template cell and slide and then clone it multiple times.",
		"Tip: For Coordinate Systems, you can alter axes numbering, axes labels, arrows, grid appearance, and more. See Display Properties.",
		"Tip: Did you know you can add timed-release notes and comments to the right panel of a Video LR? Use the \"Transcript\" field.",
		"New: You can author alt text anywhere in the Wiki or Wigi editors. Read the documentation for directions.",
		"New: Statistical Boxplots are now available in SmartArt 2D Charts.",
		"New: You can plot a variety of statistical distributions on Coordinate Systems now.",
		"New: You can bulk copy probes and LRs from one product to another. Read the documentation for directions.",
		"New: Write wiki code inside of wigi using the \"Native Wiki\" tool.",
		"New: Basic Spreadsheet features are now available inside the Wigi editor.",
		"New: Test any probe or LR in the product using the \"Test as Student\" button.",
		"New: You can make parametric plots in Coordinate Systems.",
		"New: If a kaleidoscope is a video with some related interactions, you can label the LR as an \"Interactive Video\" in the Library Tab.",
		"New: Add a clickable calculator in Wiki or Wigi to give students quick access in probes where one is needed.",
		"New: In Wigi, use Ctrl-B for bold, Ctrl-U for underline, and Ctrl-I for italics. Change Ctrl to Cmd if using a Mac.",
		"New: Now you can copy a probe into a multiprobe.",
		"New: Several statistical functions are now available in the Math Standard Library, like Mean, Median, and Mode.",
		"Tip: You can add subtitles to video and audio clips in both the Wiki and Wigi editors.",
		"Tip: You can add rounded corner borders to images using the Decorated Images editor.",
		"Tip: Scatterplots are an easy way to add a lot of points to a graph in Coordinate Systems."
	];

	static private var logoPresent : Bool;
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
	static private var sPictureScale = sScale;
	static private var bgColor = 0xffffff;

	// options for progress bar
	static private var pbWidth = sWidth * sScale * 0.85;
	static private var pbHeight = 8;
	static private var progressOffset = 33;
	#elseif innovation
	static private var sURL = "images/splash/splash_innovation.png" + "?v=" + sVersion;

	static private var sWidth = 1050;
	static private var sHeight = 490;
	static private var sScale = 0.7;
	static private var sPictureScale = 0.99;
	static private var bgColor = 0xffffff;

	// options for progress bar
	static private var pbWidth = sWidth * sScale * 0.50;
	static private var pbHeight = 5;
	static private var progressOffset = 33;
	#elseif tm
	static private var sURL = "images/splash/tm_splash.jpg" + "?v=" + sVersion;

	static private var sWidth = 1050;
	static private var sHeight = 490;
	static private var sScale = 0.7;
	static private var sPictureScale = 0.99;
	static private var bgColor = 0x262626;

	// options for progress bar
	static private var pbWidth = sWidth * sScale * 0.73;
	static private var pbHeight = 35;
	static private var progressOffset = 33;
	#elseif customimage
	static private var sURL = (if (flashParameter("splashAbs") == "true") "" else "images/splash/") + flashParameter("custom_splash_image") + "?v=" + sVersion;

	static private var sWidth = 1050;
	static private var sHeight = 490;
	static private var sScale = 0.7;
	static private var sPictureScale = 0.99;
	static private var bgColor = 0x262626;

	// options for progress bar
	static private var pbWidth = sWidth * sScale * 0.73;
	static private var pbHeight = 35;
	static private var progressOffset = 33;
	#else
	static private var sURL = "images/splash/splash.swf" + "?v=" + sVersion;
	
	static private var sWidth = 1050;
	static private var sHeight = 490;
	static private var sScale = 0.7;
	static private var sPictureScale = sScale;
	static private var bgColor = 0x262626;

	// options for progress bar
	static private var pbWidth = sWidth * sScale * 0.73;
	static private var pbHeight = 35;
	static private var progressOffset = 30;
	#end

	// something strange :)
	static private var mc : ArcticMovieClip;
	static private var view : Dynamic;
	static private var loader;
	
	static private var arcticViewSplash;
}
