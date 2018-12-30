package nw.gui;


import js.node.events.EventEmitter;

/**
 * https://github.com/nwjs/nw.js/wiki/App
 */
@:jsRequire("nw.gui","App")
extern class App extends EventEmitter<App>{
	
  /**
     Get the command line arguments when starting the app
	 
     nw.exe app abc -Da=123 -D b=456 => ["abc", "-Da=123", "-D", "b=456"]
  */
  var argv:Array<String>;
	
  /**
     Get all the command line arguments when starting the app
	
     Because node-webkit itself used switches like --no-sandbox and --process-per-tab, 
     it would confuse the app when the switches were meant to be given to node-webkit, 
     so App.argv just filtered such switches (arguments' precedence were kept). 
     You can get the switches to be filtered with App.filteredArgv.
	
  */
  var fullArgv:Array<String>;
	
  /**
     since v0.6.1
	
     Get the application's data path in user's directory. 
	
     Windows: %LOCALAPPDATA%/<name>;  Linux: ~/.config/<name>;
	
     OSX: ~/Library/Application Support/<name> where <name> is the field in the manifest.
	
  */
  var dataPath:String;
	
  /**
     since v0.7.0

     Get the JSON object of the manifest file. 
  */
  var manifest:Manifest;
	
  /**
     Since v0.6.0

     Clear the HTTP cache in memory and the one on disk. This method call is synchronized.
  */
  function clearCache():Void;
	
  /**
     since v0.3.2

     Send the close event to all windows of current app, if no window is blocking the close event, 
	
     then the app will quit after all windows have done shutdown. 
	
     Use this method to quit an app will give windows a chance to save data. 
  */
  function closeAllWindows():Void;
	
	
  /**
     since v0.8.0

     crashes the browser process  respectively, to test the Crash dump feature.
	
     [Crash dump]: https://github.com/nwjs/nw.js/wiki/Crash-dump
  */
  function crashBrowser():Void;
	
  /**
     since v0.8.0
	
     crashes the renderer process respectively, to test the Crash dump feature.
  */
  function crashRenderer():Void;
	
  /**
     since v0.6.3
	
     Query the proxy to be used for loading url in DOM. 
	
     The return value is in the same format used in PAC (e.g. "DIRECT", "PROXY localhost:8080").
	
     PAC: https://en.wikipedia.org/wiki/Proxy_auto-config
  */
  function getProxyForURL(url:String):String;
	
  /**
     since v0.11.1
	
     Set the proxy config which the web engine will be used to request network resources.
	
     https://github.com/nwjs/nw.js/wiki/App#setproxyconfigconfig
  */
  function setProxyConfig(config:String):Array<Dynamic>; // Array<Unknown>
	
	
  /**
     Quit current app. This method will not send close event to windows and app will just quit quietly. 
  */
  function quit():Void;
	
  /**
     since v0.8.0

     Set the directory where the minidump file will be saved on crash. For more information, see [Crash dump]
  */
  function setCrashDumpDir(dir:String):Void;
	
	
  /**
     since v0.10.0-rc1
	
     Add an entry to the whitelist used for controlling cross-origin access. 
	
     Suppose you want to allow HTTP redirecting from github.com to the page of your app, 
	
     use something like this with the [App-protocol](https://github.com/nwjs/nw.js/wiki/App-protocol)
	
     ```
     App.addOriginAccessWhitelistEntry('http://github.com/', 'app', 'myapp', true);
     ```
	
     Use App.removeOriginAccessWhitelistEntry with exactly the same arguments to do the contrary.
	
     TODO: unknown return
  */
  function addOriginAccessWhitelistEntry(sourceOrigin:String, destinationProtocol:String, destinationHost:String, allowDestinationSubdomains:Bool):Void;
	
  /**
	
     TODO: unknown return
  */
  function removeOriginAccessWhitelistEntry(sourceOrigin:String, destinationProtocol:String, destinationHost:String, allowDestinationSubdomains:Bool):Void;
	
	
  /**
     (since v0.10.0)

     Register a global keyboard shortcut (also known as system-wide hot key) to the system.

     For more information, please see [Shortcut](https://github.com/nwjs/nw.js/wiki/Shortcut).
  */
  function registerGlobalHotKey(shortcut:Shortcut):Bool;
	
	
  /**
     (since v0.10.0) Unregisters a global keyboard shortcut.

     For more information, please see [Shortcut](https://github.com/nwjs/nw.js/wiki/Shortcut).
  */
  function unregisterGlobalHotKey(shortcut:Shortcut):Void;
}

@:enum abstract AppEvent<T:haxe.Constraints.Function>(Event<T>) to Event<T> {
  /**
     (Since v0.3.2) Emitted when users opened a file with your app. 
	
     There is a single parameter of this event callback: Since v0.7.0, it is the full command line of the program; 
	
     before that it's the argument in the command line and the event is sent multiple times for each of the arguments.
	
     For more on this, see [Handling files and arguments](https://github.com/nwjs/nw.js/wiki/Handling-files-and-arguments).
	
	
     Note: On Windows and Linux, if you don't want this behaviour.
	
     you can close it by setting single-instance to false in package.json, 
	
     however it has no effect on Mac since it's forced by the OS.
  */
  var Open:AppEvent<String->Void> = "open";
	
	
  /**
     (since v0.7.3) This is a Mac specific feature. 
	
     This event is sent when the user clicks the dock icon for an already running application.
	
     TODO: unknown arguments
  */
  var Reopen: AppEvent<Void->Void> = "reopen";
}