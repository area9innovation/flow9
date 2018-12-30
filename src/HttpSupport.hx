import Flow;
import FlowArray;

class HttpSupport {
	public function new(interpreter : Interpreter) {
		this.interpreter = interpreter;
	}

	static var TimeoutInterval = 60000;	// One minute in ms
	
	var interpreter : Interpreter;

	/*
		native httpRequest(url : string, 
						postMethod : bool,
						headers : [[string]],
						params : [[string]],
						onData : (string) -> void, 
						onError : (string) -> void, 
						onStatus : (int) -> void, 
						) -> void = HttpSupport.httpRequest;
	*/
	public function httpRequest(args : FlowArray<Flow>, pos : Position) : Flow  {
		// passing structs was not working in flash as of 01.04.2011 (and that's not a joke)
		var url = FlowUtil.getString(args[0]);
		var post = FlowUtil.getBool(args[1]);
		var headers = FlowUtil.getArray(args[2]);
		var params = FlowUtil.getArray(args[3]);

		var onDataFn = interpreter.registerRoot(args[4]);
		var onErrorFn = interpreter.registerRoot(args[5]);
		var onStatusFn = interpreter.registerRoot(args[6]);

		var handled = false;	// Whether the request has already completed, failed or timed out
		var okReceived = false;

		var me = this;
		var http = new haxe.Http(url);
		
		http.onData = function(s) {
			if (!handled) {
				handled = true;

				me.interpreter.eval(Call(me.interpreter.lookupRoot(onDataFn), FlowArrayUtil.fromArray([
						ConstantString(s, pos),
					]), pos));
				me.interpreter.releaseRoot(onDataFn);
				if (okReceived) {
					me.interpreter.releaseRoot(onStatusFn);					
					me.interpreter.releaseRoot(onErrorFn);
				}
			} else {
				// Ignore result as the request most probably timed out and onError was called already
			}
		};

		http.onError = function(s) {
			if (!handled) {
				handled = true;

				me.interpreter.eval(Call(me.interpreter.lookupRoot(onErrorFn), FlowArrayUtil.fromArray([
						ConstantString(s, pos),
					]), pos));
				me.interpreter.releaseRoot(onDataFn);
				me.interpreter.releaseRoot(onStatusFn);
				me.interpreter.releaseRoot(onErrorFn);
			} else {
				// Ignore error as the request most probably timed out and onError was called already
			}
		};

		http.onStatus = function(status) {
			if (!handled) {
				me.interpreter.eval(Call(me.interpreter.lookupRoot(onStatusFn), FlowArrayUtil.fromArray([
						ConstantI32(status, pos),
					]), pos));

				if (status == 200) {
					okReceived = true;
				} else {
					// There was probably an error with the request
					trace("Http request to " + url + " returned status: " + status);
				}
			} else {
				// Nothing to do, we have handled the request already
			}
		};

		// setting parameters
		for (param in params) {
			var item = FlowUtil.getArray(param);
			var key = FlowUtil.getString(item[0]);
			var value = FlowUtil.getString(item[1]);
			http.setParameter(key, value);
		}

		// and headers
		for (header in headers) {
			var item = FlowUtil.getArray(header);
			var key = FlowUtil.getString(item[0]);
			var value = FlowUtil.getString(item[1]);
			http.setHeader(key, value);
		}

		// Set up timeout
		var checkTimeout = function() {
			if (!handled) {
				handled = true;
				http.onError(url + ": request timed out");
			}
		}

		#if !sys
		haxe.Timer.delay(checkTimeout, TimeoutInterval);
		#end

		http.request(post);

		return ConstantVoid(pos);
	}

	public function httpCustomRequestNative(args : FlowArray<Flow>, pos : Position) : Flow {
		// STUB; native only used in the C++ and JS targets
		return ConstantVoid(pos);
	}

	public function preloadMediaUrl(args : FlowArray<Flow>, pos : Position) : Flow  {
		// STUB; native only used in the C++ target
		return ConstantVoid(pos);
	}

	/*
	flow params
		url: string, 
		params: [[string]], 
		fileTypes: [string],
		onOpen: () -> void,
		onSelect: () -> void,
		onData: (string) -> void,
		onError: (string) -> void, 
		onProgress: (double, double) -> void,
		onCancel: () -> void
	*/
	public function uploadFile(args : FlowArray<Flow>, pos : Position) : Flow  {
		var url = FlowUtil.getString(args[0]);
		var params = FlowUtil.getArray(args[1]);
		var headers = FlowUtil.getArray(args[2]);
		var fileTypes = FlowUtil.getArray(args[3]);
		var onOpenFn = interpreter.registerRoot(args[4]);
		var onSelectFn = interpreter.registerRoot(args[5]);
		var onDataFn = interpreter.registerRoot(args[6]);
		var onErrorFn = interpreter.registerRoot(args[7]);
		var onProgressFn = interpreter.registerRoot(args[8]);
		var onCancelFn = interpreter.registerRoot(args[9]);
		
		var me = this;
		var cancelFn = function(){};
		var release = function(){
			me.interpreter.releaseRoot(onOpenFn);
			me.interpreter.releaseRoot(onSelectFn);
			me.interpreter.releaseRoot(onDataFn);
			me.interpreter.releaseRoot(onErrorFn);
			me.interpreter.releaseRoot(onProgressFn);
			me.interpreter.releaseRoot(onCancelFn);
		}
		
		#if flash
		var fileReference = new flash.net.FileReference();
		cancelFn = function() {
			fileReference.cancel();
		}
		fileReference.addEventListener(flash.events.Event.SELECT, function(e) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(onSelectFn), 
				FlowArrayUtil.fromArray([
					ConstantString(fileReference.name, pos),
					ConstantI32((Std.int(fileReference.size)), pos)
				]), 
				pos
			));
			me.interpreter.releaseRoot(onSelectFn);
			
			var selectedFile: flash.net.FileReference = e.target;
			cancelFn = function() {
				selectedFile.cancel();
			}
			
			selectedFile.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function(e) {
				me.interpreter.eval(Call(me.interpreter.lookupRoot(onErrorFn), FlowArrayUtil.fromArray([
					ConstantString(e, pos),
				]), pos));
				release();
			});
			
			selectedFile.addEventListener(flash.events.Event.OPEN, function(e) {
				me.interpreter.eval(Call(me.interpreter.lookupRoot(onOpenFn), FlowArrayUtil.fromArray([]), pos));
				me.interpreter.releaseRoot(onOpenFn);
			});
			
			selectedFile.addEventListener(flash.events.DataEvent.UPLOAD_COMPLETE_DATA, function(e: flash.events.DataEvent) {
				me.interpreter.eval(Call(me.interpreter.lookupRoot(onDataFn), FlowArrayUtil.fromArray([
					ConstantString(e.data, pos),
				]), pos));
				release();
			});
			
			selectedFile.addEventListener(flash.events.ProgressEvent.PROGRESS, function(e: flash.events.ProgressEvent) {
				me.interpreter.eval(Call(me.interpreter.lookupRoot(onProgressFn), FlowArrayUtil.fromArray([
					ConstantDouble(e.bytesLoaded, pos),
					ConstantDouble(e.bytesTotal, pos),
				]), pos));
			});
			
			var request = new flash.net.URLRequest(url);
			request.method = flash.net.URLRequestMethod.POST;
			var vars = new flash.net.URLVariables();

			for (param in params) {
				var item = FlowUtil.getArray(param);
				var key = FlowUtil.getString(item[0]);
				var value = FlowUtil.getString(item[1]);
				Reflect.setField(vars, key, value);
			}
			request.data = vars;
			selectedFile.upload(request);
		});
		
		fileReference.addEventListener(flash.events.Event.CANCEL, function(e) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(onCancelFn), FlowArrayUtil.fromArray([]), pos));
			release();
		});
		
		var fTypes = "";
		for(fType in fileTypes) {
			fTypes += FlowUtil.getString(fType) + ";";
		}
		
		fileReference.browse([new flash.net.FileFilter(fTypes, fTypes)]);
		#end
		
		return NativeClosure(0, function(flow, pos) {
				cancelFn();
				release();
				return ConstantVoid(pos);
			}, pos);
	}

	public function downloadFile(args : FlowArray<Flow>, pos : Position) : Flow  {
		// TODO: REPLACE STUB
		var onErrorFn = args[2];
		interpreter.eval(Call(onErrorFn, FlowArrayUtil.fromArray([
			ConstantString("Not implemented", pos),
		]), pos));
		return ConstantVoid(pos);
	}

	public function removeUrlFromCache(args : FlowArray<Flow>, pos : Position) : Flow {
		// NOP
		return ConstantVoid(pos);
	}

	public function clearUrlCache(args : FlowArray<Flow>, pos : Position) : Flow  {
		// NOP
		return ConstantVoid(pos);
	}

	public function sendHttpRequestWithAttachments(args : FlowArray<Flow>, pos : Position) : Flow {
		// NOP
		return ConstantVoid(pos);
	}
}
