import RenderSupport;
import SoundSupport;
import Database;
import HttpSupport;
import HtmlSupport;
import FlowFileSystem;
import NotificationsSupport;
import ServiceWorkerCache;
import GeolocationSupport;

class FlowJs {
	public static function main() {
		#if false

		#if (flash9 || flash10)
		haxe.Log.trace = function(v,?pos) { 			
			untyped __global__["trace"](pos.className+"#"+pos.methodName+"("+pos.lineNumber+"):",v); 
			//flash.Lib.trace(pos.className+"#"+pos.methodName+"("+pos.lineNumber+"): "+v);
		}
		#elseif flash
		haxe.Log.trace = function(v,?pos) { flash.Lib.trace(pos.className+"#"+pos.methodName+"("+pos.lineNumber+"): "+v); }
		#end
		//haxe.Log.trace = function(v,?pos) { flash.Lib.trace(pos.className+"#"+pos.methodName+"("+pos.lineNumber+"): "+v); }
		trace( " ----- Started at " + Date.now().toString() + " ------------ ");

		#end
		
		Simulator.simulate();
	}
}
