package nw;


@:enum abstract WindowPosition(Null<String>) to Null<String> {	
  var PNull = null;
	
  var PCenter = "center";
	
  var PMouse = "mouse";
}

/**
   https://github.com/nwjs/nw.js/wiki/Manifest-format#window-subfields
*/
typedef WindowSubFields = {
  /**
     the default title of window created by node-webkit, it's very useful if you want to show your own title when the app is starting.
  */
  ?title:String,
	
  /**
     the initial width/height of the main window.
  */
  ?width:Int,
  ?height:Int,
	
  /**
     should the navigation toolbar be showed.
  */
  ?toolbal:Bool,
		
  /**
     path to window's icon
  */
  ?icon:String,
	
  /**
     be null or center or mouse, controls where window will be put 
  */
  ?position:WindowPosition,//
	
  /**
     minimum width of window 
  */
  ?min_width:Int,
  ?min_height:Int,
	
  /**
     maxmum width of window 
  */
  ?max_width:Int,			//
  ?max_height:Int,		//
	
  /**
     show as desktop background window under X11 environment 
  */
  ?as_desktop:Bool,
	
  /**
     (since v0.3.4) whether the window should always stay on top of other windows. 
  */
  ?resizable:Bool,
	
  /**
     whether the window should be visible on all workspaces simultaneously 
	
     (on platforms that support multiple workspaces, currently Mac OS X and Linux).
	
     TODO: haxe is not supported `-`
  */
  //?visible-on-all-workspaces
	
	
  /**
     (since v0.3.0) whether window is fullscreen
	
     Beware, if frame is also set to false in fullscreen it will prevent the mouse from being captured on the very edges of the screen. 
	
     You should avoid activate it if fullscreen is also set to true.
  */
  ?fullscreen:Bool,
	
  /**
     (since v0.9.2) whether the window is shown in taskbar or dock. 
	
     The default is `true`.
  */
  ?show_in_taskbar:Bool,
	
	
  /**
     (since v0.3.0) specify it to false to make the window frameless
	
     Beware, if frame is set to false in fullscreen it will prevent the mouse from being captured on the very edges of the screen. 
	
     You should avoid activate it if fullscreen is also set to true.
	
     frameless: https://github.com/nwjs/nw.js/wiki/Frameless-window
  */
  ?frame:Bool,
	
	
  /**
     (since v0.3.0) specify it to false if you want your app to be hidden on startup
  */
  ?show:Bool,
	
  /**
     (since v0.3.1) whether to use Kiosk mode. In `Kiosk` mode, the app will be fullscreen and try to prevent users from leaving the app,
	
     so you should remember to provide a way in app to leave `Kiosk` mode. This mode is mainly used for presentation on public displays
  */
  ?kiosk:Bool,
	
  /**
     (since v0.11.2) whether to turn on transparent window mode. The default is `false`.
	
     control the transparency with rgba background value in CSS. 
	
     Use command line argument `--disable-transparency` to disable this feature completely. 
	
     There is experimental support for "click-through" on the transparent region: 
	
     add `--disable-gpu` argument to the command line. 
	
     See the discussion here: https://github.com/rogerwang/node-webkit/issues/132 _
  */
  ?transparent:Bool,
	
  /**
     (Since v0.7.3) the opened window(sub window) is not focused by default. 
	
     It's a result of unifying behavior across platforms. 
	
     If you want it to be focused by default, you can set focus to true in options. 
  */
  ?focus:Bool,
}

/**
 * require node-webkit >= v0.3.0. 
 */
  typedef WebKitSubFields = {
    /**
       whether to load external browser plugins like Flash, default to `false`. 
    */
    ?plugin:Bool,
	
    /**
       whether to load Java applets, default to `false`. 
    */
    ?java:Bool,
	
    /**
       whether to enable page cache, default to `false`. 
       TODO: haxe is not supported `-`
    */
    //?page-cache:Bool,
  }

  /** 
      https://github.com/nwjs/nw.js/wiki/Manifest-format
  */
    typedef Manifest = {
	
      /**
	 (string) the name of the package. 
	
	 This must be a unique, lowercase alpha-numeric name without spaces. It may include "." or "_" or "-" characters. It is otherwise opaque.
	
	 name should be globally unique since node-webkit will store app's data under the directory named name.
      */
    name:String,
	
    /**
       which page should be opened when node-webkit starts.
	 
       You can specify a URL here. You can also specify just a filename (such as index.html) 
	 
       or a path (relative to the directory where your package.json resides).
	
       Note that you should not use parameters after a filename (such as index.html?foo=bar) because they'll be treated as parts of the file's path 
	 
       (for example, index.html?foo=bar/baz is a file baz in a directory named index.html?foo=bar) 
	 
       and that's probably not what you expect. When you need to pass some parameters to a local application, use a URL with the App protocol.
    */
    main:String,
	
    /**
       set nodejs to false will disable Node support in WebKit.
    */
    ?nodejs:Bool,
	
    /**
       since v0.3.1
	 
       specify the path to a node.js script file, it will be executed on startup in Node context. 
	 
       This script will have same runtime environment with normal node.js binary. 
	 
       The script is ensured to run before the first DOM window load starting from v0.3.3. 
	 
       See (https://github.com/nwjs/nw.js/wiki/node-main) for more information.
	 
       TODO: haxe is not supported `-`
    */
    //?node-main:String,
	
    /**
       by default node-webkit only allows one instance of your app if your app is a standalone package 
	
       (packaged with instructions of [How to package and distribute your apps](https://github.com/nwjs/nw.js/wiki/How-to-package-and-distribute-your-apps)), 
	
       if you want to allow multiple instances of your app running at the same time, specify this to false.

       Starting from v0.10.0-rc1, it's also effective if your application is started from unpacked folders.
	
       TODO: haxe is not supported `-`
    */
    //?single-instance:Bool,
	
    ?window:WindowSubFields,

    ?webkit:WebKitSubFields,
	
    /**
       (since v0.3.7) Override the User-Agent header in HTTP requests made from the application. 
	
       The following placeholders are available: 
	
       - `%name`: replaced by the `name` field in the manifest.

       - `%ver`: replaced by the `version` field in the manifest, if available.

       - `%nwver`: replaced by the version of node-webkit.
	 
       - `%webkit_ver`: replaced by the version of WebKit engine.

       - `%osinfo`: replaced by the OS and CPU information you would see in browser's user agent string.
	 
       TODO: haxe is not supported `-`
    */
    //?user-agent:String,
	
    /**
       (since v0.3.7) Enable calling Node in remote pages.
	
       The value controls for which sites this feature should be turned on.
	
       The format is the same with the "proxy bypass rules" of the browser:
	
       More Info: https://github.com/nwjs/nw.js/wiki/Manifest-format#node-remote
    */
    //?node-remote:String,
	
	
    /**
       (since v0.4.0) Specify chromium (content shell) command line arguments. 
	
       It will be useful if you want to distribute the app with some custom chromium args. For example, 
	
       if you want to disable the GPU accelerated video display, just add "chromium-args" : "--disable-accelerated-video". 
	
       If you want to add multiple arguments, separate each two arguments by space. This field can take a number of flags in one argument as well, via enclosing them in single quotation marks.
	
       A list of Chromium's command line arguments is available at http://peter.sh/experiments/chromium-command-line-switches/
    */
    //?chromium-args:String,
	
	
    /**
       (since v0.4.1) Specify the flags passed to JS engine(v8). e.g. turn on Harmony Proxies and Collections feature:
	
       `"js-flags": "--harmony_proxies --harmony_collections"`
    */
    //?js-flags:String,
	
    /**
       (since v0.9.0 and v0.8.5)
	
       a local filename, relative to the application path, used to specify a JavaScript file to inject to the window. 
	
       `inject-js-start`: The injecting JavaScript code is to be executed after any files from css, 
	
       but before any other DOM is constructed or any other script is run;
	
       `inject-js-end`: The injecting JavaScript code is to be executed after the document object is loaded, 
	
       before onload event is fired. This is mainly to be used as an option of Window.open() to inject JS in a new window.
    */
    //?inject-js-start:String,
    //?inject-js-end:String,
	
	
    /**
       (since v0.11.1) containing a list of PEM-encoded certificates
	
       (i.e. "-----BEGIN CERTIFICATE-----\n...certificate data...\n-----END CERTIFICATE-----\n").

       These certificates are used as additional root certificates for validation, to allow connecting to services using a self-signed certificate or certificates issued by custom CAs.
    */
    ?additional_trust_anchors:String,
	
    /**
       (since v0.4.2) Specify the path to the snapshot file to be loaded with the application.
	
       The snapshot file contains compiled code of your application.
	
       See [Protect JavaScript source code with v8 snapshot](https://github.com/nwjs/nw.js/wiki/Protect-JavaScript-source-code-with-v8-snapshot).
    */
    ?snapshot:String,
	
	
    /**
       (since v0.6.1) Number of mega bytes for the quota of the DOM storage. 
	
       The suggestion is to put double the value you want.
    */
    ?dom_storage_quota:Int,
	
	
    /**
       (since v0.7.3) whether the default Edit menu should be disabled on Mac OS X. 
	
       The default value is false. Only effective on Mac OS X. 
	
       **This is a workaround for a feature request and is expected to be replaced by something else soon**
       */
    //?no-edit-menu:Bool,
	
    /**
       a brief description of the package. By convention, 
	
       the first sentence (up to the first ". ") should be usable as a package title in listings. 
    */
    ?description:String,
	
    /**
       a version string conforming to the [Semantic Versioning requirements](http://semver.org/). 
    */
    ?version:String,
	
    /**
       an Array of string keywords to assist users searching for the package in catalogs. 
    */
    ?keywords:Array<String>,
	
    /**
       Array of maintainers of the package. 
	
       Each maintainer is a hash which must have a "name" property and may optionally provide "email" and "web" properties. 
	
       For example: 
	
       ```
       "maintainers":[ {
       "name": "Bill Bloggs",
       "email": "billblogs@bblogmedia.com",
       "web": "http://www.bblogmedia.com"
       }]
       ```
    */
    ?maintainers:Array<{name:String,?email:String,?web:String}>,
	
	
    /**
       an Array of hashes each containing the details of a contributor. 
	
       Format is the same as for author. By convention, the first contributor is the original author of the package.
    */
    ?contributors:Array<String>,
	
	
    /**
       URL for submitting bugs. Can be mailto or http. 
    */
    ?bugs:String,
	
    /**
       array of licenses under which the package is provided. 
	
       Each license is a hash with a "type" property specifying the type of license and a url property linking to the actual text. 
	
       If the license is one of the official open source licenses the official license name or its abbreviation may be explicated with the "type" property. 
	
       If an abbreviation is provided (in parentheses), the abbreviation must be used. 
    */
    ?licenses:Array<{type:String,?url:String}>,
	
	
	
    ?repositories:Array<{type:String,url:String,?path:String}>
    }