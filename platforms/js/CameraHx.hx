class Camera {
    private static var rawvideo : flash.media.Video; 
    private static var loaderBMD : flash.display.BitmapData;

// starting camera
	public static function getCamera() {
       	var mc : flash.display.MovieClip ;
       	var cam : flash.media.Camera = flash.media.Camera.getCamera();
       	cam.setMode(640, 480, 30);   // capture width, capture height, rate in frames per second  
       	cam.setQuality(0, 100);

       	mc = flash.Lib.current;
       	
       	rawvideo = new flash.media.Video(cam.width, cam.height);
       	rawvideo.attachCamera(cam);

       	if (cam != null) {
     		var videoContainer : flash.display.MovieClip = new flash.display.MovieClip();
     		videoContainer.addChild(rawvideo);
     		mc.addChild(videoContainer);
     		return rawvideo;     		
       	} else {
     		trace("No Camera") ;
     		return null;
    	}
	}

// getting current snapshot
	public static function getSnapshotCamera() {
		loaderBMD = new flash.display.BitmapData(640, 480);
		loaderBMD.draw(rawvideo);
		var bm = new flash.display.Bitmap(loaderBMD);
		bm.smoothing = true;
		var rec = new flash.display.Sprite();
		rec.addChild(bm);
  		return rec;
	}

/////////////////////////////////////////////////////////////////////////////////////
  public static function startCamera(id : Int, width : Int, height : Int, fps : Float) {  
    // get the default Flash camera
    var camera : flash.media.Camera = flash.media.Camera.getCamera(id+"");

    // here are all the quality and performance settings
    if(camera != null)
    {
      camera.setMode(width, height, fps, false);
      camera.setQuality(0, 100);
      camera.setKeyFrameInterval(30);
    }
    return camera;
  }
  public static function startMicrophone() {  
    // get the default Flash microphone
    var microphone : flash.media.Microphone = flash.media.Microphone.getMicrophone();

    // here are all the quality and performance settings
    if( microphone != null)
    {
      microphone.rate = 11;
      microphone.setSilenceLevel(0,-1); 
    }
    return microphone;    
  }

  public static function getNumberOfCameras() {
    return flash.media.Camera.names.length;
  }

}