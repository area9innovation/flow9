package nw.gui;

import nw.Manifest;
import js.node.events.EventEmitter;


private typedef Frame = haxe.extern.EitherType<js.html.FrameElement,js.html.IFrameElement>;
/**
   Window API requires node-webkit >= v0.3.0

   Window is a wrapper of the DOM's window object. It has extended operations and can receive various window events.

   Every Window is an instance of the EventEmitter class, and you're able to use Window.on(...) to respond to native window's events.

   https://github.com/nwjs/nw.js/wiki/Window
*/
@:jsRequire("nw.gui","Window")
extern class Window extends EventEmitter<Window>{

  var window : #if (haxe_ver >= 3.2) js.html.Window #else js.html.DOMWindow #end;

  var x : Int;
  var y : Int;
  var width : Int;
  var height : Int;
  var title:String;

  /**
     Get or Set window's menubar. Set with a Menu with type menubar.
  */
  var menu:Menu;

  /**
     (since v0.3.5) Get or Set whether we're in fullscreen mode.
  */
  var isFullscreen:Bool;

  /**
     (since v0.11.2) Get whether transparency is turned on
  */
  var isTransparent:Bool;

  /**
     (since v0.3.5) Get or Set whether we're in kiosk mode.
  */
  var isKioskMode:Bool;

  /**
     (since v0.4.1) Get or Set the page zoom. 0 for normal size; positive value for zooming in; negative value for zooming out.
  */
  var zoomLevel:Float;

  /**
     (since v0.8.1) This includes multiple functions to manipulate the cookies. 

     The API is defined in the same way as Chrome Extensions'. node-webkit supports the get, getAll, remove and set methods;

     onChanged event (supporting both addListener and removeListener function on this event).

     And anything related to CookieStore in the Chrome extension API is not supported, 
        
     because there is only one global cookie store in node-webkit apps. 
        
     ```
     cookies.set({name:"foo",value:"123",domain:example.com, url:"http://www.exmaple.com/path/file"},function(d){});
     ```
  */
  var cookies(default, null):Cookie;
        
  /**
     Moves a window's left and top edge to the specified coordinates. 
  */
  function moveTo(x:Int, y:Int):Void;
        
  /**
     Moves a window a specified number of pixels relative to its current coordinates. 
  */
  function moveBy(x:Int, y:Int):Void;
        
  /**
     Focus on the window.
  */
  function focus():Void;
        
  /**
     Move focus away. Usually it will move focus to other windows of your app, since on some platforms there is no concept of blur. 
  */
  function blur():Void;
        
        
  /**
     Show the window if it's not shown, show will not focus on the window on some platforms,
        
     so you need to call focus if you want to. `show(false)` has the same effect with `hide()`.
  */
  function show(t:Bool = true):Void;
        
  function hide() : Void;
        
  /**
     Close current window, you can catch the close event to prevent the closing. 
        
     If force is specified and equals to true, then the close event will be ignored.
        
     Usually you would like to listen to the close event and do some shutdown work and then do a `close(true)` to really close the window.
        
     ```
     // Javascript
     win.on('close', function() {
     this.hide(); // Pretend to be closed already
     console.log("We're closing...");
     this.close(true);
     });
     win.close();
     ```
  */
  function close(?f:Bool) : Void;
        
        
  /**
     (Requires node-webkit >= v0.3.5) Reloads the current window. 
  */
  function reload():Void;
        
  /**
     (since version 0.4.0) Reloads the current page by starting a new renderer process from scratch.
        
     This is the same as pressing the "reload" button in the right side of the toolbar. 
  */
  function reloadDev():Void;
        
  /**
     (Requires node-webkit >= v0.3.5) Like reload(), but don't use caches (aka "shift-reload"). 
  */
  function reloadIgnoringCache():Void;
        
  /**
     Maximize the window on GTK and Windows, zoom the window on Mac OS X. 
  */
  function maximize():Void;
        
  /**
     Unmaximize the window, e.g. the reverse of maximize().
  */
  function unmaximize():Void;
        
  /**
     Minimize the window to task bar on Windows, iconify the window on GTK, and miniaturize the window on Mac OS X. 
  */
  function minimize():Void;
        
  /**
     Restore window to previous state after the window is minimized, 
        
     e.g. the reverse of minimize(). It's not named unminimize since restore is already used commonly on Window. 
  */
  function restore():Void;
        
        
  /**
     Make the window fullscreen. This function is different with HTML5 FullScreen API,
        
     which can make part of the page fullscreen, Window.enterFullscreen() will only fullscreen the whole window. 
  */
  function enterFullscreen():Void;
        
        
  function leaveFullscreen():Void;
        
  /**
     (Requires node-webkit >= v0.3.5) Toggle the fullscreen mode.
  */
  function toggleFullscreen(fs:Bool):Void;
        
  /**
     (Requires node-webkit >= v0.3.1) Enter the Kiosk mode. 
        
     In Kiosk mode, the app will be fullscreen and try to prevent users from leaving the app,
        
     so you should remember to provide a way in app to leave Kiosk mode.
        
     This mode is mainly used for presentation on public displays. 
  */
  function enterKioskMode():Void;
        
  /**
     (Requires node-webkit >= v0.3.1) Leave the Kiosk mode.
  */
  function leaveKioskMode():Void;
        
  /**
     (Requires node-webkit >= v0.3.5) Toggle the kiosk mode.
  */
  function toggleKioskMode():Void;
        
  /**
     (since v0.11.2) turn on/off the transparency support, 
        
     more info https://github.com/rogerwang/node-webkit/wiki/Transparency
  */
  function setTransparent(t:Bool):Void;
        
  /**
     Open the devtools to inspect the window.
        
     The optional id argument is supported since v0.6.0. It should be the value of id attribute of any iframe element in the window.
        
     It can be used to limit the devtools window to inspect only the iframe. If id is empty string, this feature is not effective.
        
        
     The optional headless argument is supported since v0.6.0. When it is true, 
        
     the Devtools window will not be opened. Instead, a devtools-opened will be sent to the Window object after [Devtools is ready](https://github.com/nwjs/nw.js/wiki/Devtools-jail-feature).
        
     The optional iframe argument is supported since v0.7.2. It should be the iframe object. And it serves the same purpose with the id argument.

     For more information, please read Devtools Jail Feature.


     Since v0.8.1, this function returns a Window object when headless is false, so the devtools Window can be manipulated.
        
     Note that the events on this object is not working yet.
  */    
  function showDevTools(?fra:Frame, ?headless : Bool ) : Window;
        
  /**
     (since v0.7.3) Close the devtools window.
  */
  function closeDevTools():Void;
        
  /**
     (since v0.8.0) Query the status of devtools window. Note: This will always return false if the headless option was true when calling showDevTools() 
  */
  function isDevToolsOpen():Bool;
        
  /**
     Set window's maximum size. 
  */
  function setMaximumSize(width:Int, height:Int):Void;
        
  /**
     Set window's minimum size. 
  */
  function setMinimumSize(width:Int, height:Int):Void;
        
  /**
     Set whether window is resizable. 
  */
  function setResizable(resizable:Bool):Void;
        
  /**
     (Requires node-webkit >= v0.3.4)

     Sets the widget to be on top of all other windows in the windowing system.
  */
  function setAlwaysOnTop(top:Bool):Void;
        
  /**
     (since v0.11.3)

     For platforms that support multiple workspaces (currently Mac OS X and Linux), 
        
     this allows node-webkit windows to be visible on all workspaces simultaneously.

     For example usage see visible_on_all_workspaces manual test.

     For further information see https://github.com/rogerwang/node-webkit/issues/2523. 
  */
  function setVisibleOnAllWorkspaces(v:Bool):Void;
        
  /**
     (since v0.11.3)

     Returns a a boolean indicating if the platform (currently Mac OS X and Linux) support Window API object method setVisibleOnAllWorkspace(Boolean). 
  */
  function canSetVisibleOnAllWorkspaces():Bool;
        
  /**
     Shortcut to move window to specified position. 
        
     Currently only center is supported on all platforms, which will put window in the middle of the screen. 
  */
  function setPosition(pos:WindowPosition):Bool;
        
        
  /**
     (since v0.9.2)
        
     Control whether to show window in taskbar or dock. See also show_in_taskbar in Manifest-format. 
  */
  function setShowInTaskbar(show:Bool):Void;
        
        
  /**
     (since v0.10.2) Similar with the boolean version, on Windows platform you can specify number of times the frame flash(es)

     on OSX value < 0 will trigger NSInformationalRequest while value > 0 will trigger NSCriticalRequest

     on Linux the Integer value will be casted to Boolean
  */
  @:overload(function(count:Int):Void { } )
    /**
       Pass true to indicate that the window needs user's action, pass false to cancel it. 
        
       The final behaviour depends on the platform. 
    */  
  function requestAttention(attention:Bool):Void;
        
  /**
        
     https://github.com/nwjs/nw.js/wiki/Window#windowcapturepagecallback--image_format-config_object-
        
     ```
     // png as base64string
     win.capturePage(function(base64string){
     // do something with the base64string
     }, { format : 'png', datatype : 'raw'} );

     // png as node buffer
     win.capturePage(function(buffer){
     // do something with the buffer
     }, { format : 'png', datatype : 'buffer'} );
        
        
     format default is jpeg
     datatype default is `datauri`
     ```
  */
  @:overload(function(callback:Dynamic->Void, ?options: { ?foramt:FormatImage, datatype:DataType } ):Void { } )
    /**
       e.g win.capturePage(function(url){},"png");
    */
  function capturePage(callback:String->Void, ?format:FormatImage):Void;
        
        
  /**
     (since v0.10.2) valid values are 0 to 1,
        
     val < 0 means remove the progress bar 

     val > 1 means indeterminate 

     on linux, only Ubuntu is supported, you'll need to specify the application .desktop file through NW_DESKTOP env.
        
     if NW_DESKTOP env variable is not found, it will assume nw.desktop 
  */
  function setProgressBar(progress:Float):Void;
        
        
  /**
     (since v0.10.0-rc1) Windows and OSX only. Set the badge label on the window icon in taskbar or dock.

     since v0.10.2 the linux Ubuntu is supported, however the label is restricted to a string number only. 
        
     You'll also need to specify the .desktop file for your application (see the note on setProgressBar) 
  */
  function setBadgeLabel(label:String):Void;
        
        
  /**
     (Since v0.9.0 and v0.8.5) Execute a piece of JavaScript in the window,
        
     if frame argument is null, or in the context of an iframe, if frame is an iframe object. 
        
     The script argument is the content of the JavaScript source code.
  */

  function eval(frame:Frame, script:String):Dynamic;
        
        
        
  /**
     (Since v0.12.0-rc1) Load compiled JavaScript binary in the window, 
        
     if frame argument is null; or in the context of an iframe, if frame is an iframe object. 
        
     The path argument is the path of the JS binary compiled with nwjc, 
        
     see https://github.com/nwjs/nw.js/wiki/Protect-JavaScript-source-code-with-v8-snapshot. 
        
     __NOTE: this method has no effect and will not load the binary when devtools window is opening.__ 
        
     See https://github.com/nwjs/nw.js/issues/3388 
  */
  function evalNWBin(frame:Frame, path:String):Dynamic;
        
        
        
  /**
     If `window_object` is not specifed, then return current window's Window object, 
        
     otherwise return window_object's Window object.
        
     TODO: Unknown Arguent Type
  */
  static function get(?window_object:Dynamic):Window;
        
  /**
     Open a new window and load url in it, you can specify extra options with the window. 
        
     All window subfields in Manifest format can be used. 
        
     Since v0.4.0, a boolean field new-instance can be used to start a new Node instance (webkit process). 
        
     Since v0.9.0 and 0.8.5, `inject-js-start` and `inject-js-end` field can be used to inject a javascript file, 
        
     see [Manifest format](https://github.com/nwjs/nw.js/wiki/Manifest-format). 
        
        
     Since v0.7.3 the opened window is not focused by default. 
        
     It's a result of unifying behavior across platforms. 
        
     If you want it to be focused by default, you can set focus to true in options.
  */
  static function open(url:String, ?options:WindowSubFields):Window;
}

/**
   Following events can be listened by using Window.on() function, for more information on how to receive events, 

   you can visit [EventEmitter](http://nodejs.org/api/events.html#events_class_events_eventemitter). 
*/
@:enum abstract WindowEvent<T:haxe.Constraints.Function>(Event<T>) to Event<T> {
        
  /**
     The close event is a special event that will affect the result of the `Window.close()` function. If developer is listening to the close event of a window, the `Window.close()` call to that window will not close the window but send the close event.
        
     Usually you would do some shutdown work in the callback of close event, and then call `this.close(true)` to really close the window, which will not be caught again. Forgetting to add true when calling `this.close()` in the callback will result in infinite loop.

     And if the shutdown work takes some time, users may feel that the app is exiting slowly, which is bad experience, so you could just hide the window in the close event before really closing it to make a smooth user experience.

     For use case you can see demo code of `Window.close()` above.

     Since v0.8.4 on OSX, there is a parameter on the callback of this event. Its value will be set to 'quit' if the window is being closed by pressing 'Cmd-Q' (intent to quit application). Otherwise the value is undefined. See https://github.com/rogerwang/node-webkit/issues/430 
  */
  var Close:WindowEvent<Void->Void> = "close";
        
  /**
     The closed event is emitted __after__ corresponding window is closed. Normally you'll not be able to get this event since after the window is closed all js objects will be released.
        
     But it's useful if you're listening this window's events in another window, whose objects will not be released. 
        
     ```
     // Javascript
     var win = gui.Window.open('popup.html');
        
     // Release the 'win' object here after the new window is closed.
     win.on('closed', function() {
     win = null;
     });
        
     // Listen to main window's close event
     gui.Window.get().on('close', function() {
     // Hide the window to give user the feeling of closing immediately
     this.hide();

     // If the new window is still open then close it.
     if (win != null)
     win.close(true);

     // After closing the new window, close the main window.
     this.close(true);
     });
     ```
  */
  var Closed:WindowEvent<Void->Void> = "closed";
        
  /**
     Requires node-webkit >= v0.3.5, Emitted when the window starts to reload, 
        
     normally you cannot catch this event because usually it's emitted before you actually setup the callback.

     The only situation that you can catch this event is when you refresh the window and listen to this event in another window. 
  */
  var Loading:WindowEvent<Void->Void> = "loading";
        
  /**
     Requires node-webkit >= v0.3.5, Emitted when the window is fully loaded,
        
     this event behaves the same with window.onload, but doesn't rely on the DOM. 
  */
  var Loaded:WindowEvent<Void->Void> = "loaded";
        
        
  /**
     since v0.9.0 and v0.8.5, function (frame) {}

        
        
     Emitted when the document object in this window or a child iframe is available, after any files from css, but before any other DOM is constructed or any other script is run;

     - frame is the iframe object, or null if the event is for the window.
        
     See also: inject-js-start in [Manifest-format](https://github.com/nwjs/nw.js/wiki/Manifest-format)
  */
  var Document_start:WindowEvent<Frame->Void> = "document-start";
        
  /**
     since v0.9.0 and v0.8.5, function (frame) {}
        
     Emitted when the document object in this window or a child iframe is loaded, before the onload event is emitted.
        
     See also: inject-js-end in [Manifest-format](https://github.com/nwjs/nw.js/wiki/Manifest-format)
  */
  var Document_end:WindowEvent<Frame->Void> = "document-end";
        
        
  var Focus:WindowEvent<Void->Void> = "focus";
        
  var Blur:WindowEvent<Void->Void> = "blur";
        
  var Minimize:WindowEvent<Void->Void> = "minimize";
        
  var Restore:WindowEvent<Void->Void> = "restore";
        
  var Maximize:WindowEvent<Void->Void> = "maximize";
        
  var Unmaximize:WindowEvent<Void->Void> = "unmaximize";
        
  /**
     since v0.8.2 Emitted after window is moved. 
        
     The callback is called with 2 arguments: (x, y) for the new location of the upper-left corner of the window. 
  */
  var Move:WindowEvent<Int->Int->Void> = "move";
        
  /**
     since v0.8.2 Emitted after window is resized. 
        
     The callback is called with 2 arguments: (width, height) for the new size of the window. 
  */
  var Resize:WindowEvent<Int->Int->Void> = "resize";
        
        
  var Enter_fullscreen:WindowEvent<Void->Void> = "enter-fullscreen";
        
  var Leave_fullscreen:WindowEvent<Void->Void> = "leave-fullscreen";
        
  /**
     Emitted when window zooming changed. It has a parameter indicating the new zoom level. 
        
     See Window.zoom for the parameter's value definition. 
  */
  var Zoom:WindowEvent<Float->Void> = "zoom";
        
  /**
     Emitted after the capturePage method is called and image data is ready. 
        
     See Window.capturePage's callback function for the parameter's value definition. 
  */
  var Capturepagedone:WindowEvent<DataType->Void> = "capturepagedone";
        
        
  /**
     Emitted after Devtools is opened by any means (since v0.8.0),
        
     or ready after calling Window.showDevTools(id, headless) with headless = true. 
        
     The event callback has an url argument, which is the URL to load Devtools UI. 
        
     See [Devtools jail feature](https://github.com/nwjs/nw.js/wiki/Devtools-jail-feature) and Window for more information. 
  */
  var Devtools_opened:WindowEvent<String->Void> = "devtools-opened";
        
  var Devtools_closed:WindowEvent<Void->Void> = "devtools-closed";
        
  /**
     (since v0.9.0 and v0.8.5) function (frame, url, policy) {}
        
     Emitted when a new window is requested from this window or a child iframe, 
        
     e.g. user clicks a link with _blank target.
        
     - **frame** : is the object of the child iframe where the request is from, or null if it's from the top window.
        
     - **url** : is the address of the requested link
         
     - **policy** : is an object with the following methods:

     - ignore() : ignore the request, navigation won't happen.
          
     - forceCurrent() : force the link to be opened in the same frame
        
     - forceDownload() : force the link to be a downloadable, or open by external program
        
     - forceNewWindow() : force the link to be opened in a new window
        
     - forceNewPopup() : force the link to be opened in a new popup window
        
     - setNewWindowManifest(m) : control the options for the new popup window. The object m is in the same format as the window subfield in Manifest format (e.g. {"frame" : false}). since v0.11.3
  */
  var New_win_policy:WindowEvent<Frame->String->Dynamic->Void> = "new-win-policy";
}


@:enum abstract FormatImage(String) to String{
        
  var Jpeg = "jpeg";
        
  var Png = "png";
}

@:enum abstract DataType(String) to String{
        
  var Raw = "raw";
        
  var Buffer = "buffer";
        
  var Datauri = "datauri";
}

/**
   https://developer.chrome.com/extensions/cookies

   TEST: https://github.com/nwjs/nw.js/pull/1361/files
*/
extern class Cookie {
        
  var onChanged: {
                
    function addListener(callback:CookieChangeInfo->Void):Void;
                
    function removeListener(callback:CookieChangeInfo->Void):Void;
  };
        
  function get(details:CookieDTGet, callback:CookieDTOut->Void):Void;
        
  function getAll(details:CookieDT, callback:Array<CookieDTOut>->Void):Void;
        
  /**
     e.g: set({ name:"foo", value:"123",domain:"",url:"file:///G:/pathto/bin/index.html"},function(d){});
        
     e.g: set({ name:"bar", value:"456",domain:"example.com",url:"http://www.example.com"},function(d){});
  */
  function set(details:CookieDTSet, callback:Array<CookieDTOut>->Void):Void;
        
  function remove(details:CookieDTGet, callback:CookieDTGet->Void):Void;
}

private typedef CookieChangeInfo = {
  /**
     True if a cookie was removed. 
  */
 removed:Bool,
        
 /**
    Information about the cookie that was set or removed. 
 */
 cookie:CookieDTOut,
        
 /**
    (Since Chrome 12.)The underlying reason behind the cookie's change. 
 */
 cause:CookieOnChangedCause
}

/**
   The underlying reason behind the cookie's change.

   If a cookie was inserted, or removed via an explicit call to "chrome.cookies.remove", "cause" will be "explicit". 

   If a cookie was automatically removed due to expiry, "cause" will be "expired". 

   If a cookie was removed due to being overwritten with an already-expired expiration date, "cause" will be set to "expired_overwrite". 

   If a cookie was automatically removed due to garbage collection, "cause" will be "evicted". 

   If a cookie was automatically removed due to a "set" call that overwrote it, "cause" will be "overwrite". Plan your response accordingly.
*/
  @:enum abstract CookieOnChangedCause(String) to String{
        
    var Evicted = "evicted";
        
    var Expired = "expired";
        
    var Explicit = "explicit";
        
    var Overwrite = "overwrite";
  }


/**
   for cookies.remove and cookies.get
*/
private typedef CookieDTGet = {
 name:String,
        
 /**
    e.g: `http://exmaple.com` or `file:///C:/path/to/file`
 */
 url:String     
}

/**
   for cookies.getAll
*/
  private typedef CookieDT = {
        
    ?url:String,
        
    ?name:String,
        
    /**
       The domain of the cookie (e.g. "www.google.com", "example.com"). 
    */
    ?domain:String,
        
    /**
       The path of the cookie. 
    */
    ?path:String,
        
    /**
       True if the cookie is marked as Secure (i.e. its scope is limited to secure channels, typically HTTPS). 
    */
    ?secure:Bool,
        
    /**
       True if the cookie is a session cookie, as opposed to a persistent cookie with an expiration date. 
    */
    ?session:Bool,
  }

  /**
     for callback param 
  */
    private typedef CookieDTOut = { > CookieDT,
                                    host_only:Bool,
                                    
                                    http_only:Bool,
                                    
                                    expiration_date:Float,
                                    
                                    value:String,
    }

    /**
       for cookies.set 
    */
      private typedef CookieDTSet = { > CookieDT,

                                      name:String,

        
                                      value:String,
        
        
                                      url:String,
        
                                      /**
                                         True if the cookie is a host-only cookie (i.e. a request's host must exactly match the domain of the cookie). 
                                      */
                                      ?hostOnly:Bool,
        
                                      /**
                                         True if the cookie is marked as HttpOnly (i.e. the cookie is inaccessible to client-side scripts). 
                                      */
                                      ?httpOnly:Bool,
        
                                      /**
                                         The expiration date of the cookie as the number of seconds since the UNIX epoch. Not provided for session cookies. 
                                      */ 
                                      ?expirationDate:Float
      }