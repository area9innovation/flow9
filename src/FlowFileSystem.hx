import Flow;
import FlowArray;
import Type;

class FlowFileSystem {
	public function new(interpreter : Interpreter) {
		this.interpreter = interpreter;
	}
	
	var interpreter : Interpreter;

	public function createDirectory(args : FlowArray<Flow>, pos : Position) : Flow  {
		var dir = FlowUtil.getString(args[0]);
		return ConstantString(FlowFileSystemHx.createDirectory(dir), pos);
	}

	public function deleteDirectory(args : FlowArray<Flow>, pos : Position) : Flow  {
		var dir = FlowUtil.getString(args[0]);
		return ConstantString(FlowFileSystemHx.deleteDirectory(dir), pos);
	}

	public function deleteFile(args : FlowArray<Flow>, pos : Position) : Flow  {
		var file = FlowUtil.getString(args[0]);
		return ConstantString(FlowFileSystemHx.deleteFile(file), pos);
	}

	public function renameFile(args : FlowArray<Flow>, pos : Position) : Flow {
		var old = FlowUtil.getString(args[0]);
		var newName = FlowUtil.getString(args[1]);
		return ConstantString(FlowFileSystemHx.renameFile(old, newName), pos);
	}

	public function fileExists(args : FlowArray<Flow>, pos : Position) : Flow {
		var file = FlowUtil.getString(args[0]);
		return ConstantBool(FlowFileSystemHx.fileExists(file), pos);
	}

	public function isDirectory(args : FlowArray<Flow>, pos : Position) : Flow {
		var dir = FlowUtil.getString(args[0]);
		return ConstantBool(FlowFileSystemHx.isDirectory(dir), pos);
	}

	public function readDirectory(args : FlowArray<Flow>, pos : Position) : Flow {
		var dir = FlowUtil.getString(args[0]);
		var files = FlowFileSystemHx.readDirectory(dir);

		var array = new FlowArray();
		for (f in files) {
			array.push(ConstantString(f, pos));
		}

		return ConstantArray(array, pos);
	}

	public function fileSize(args : FlowArray<Flow>, pos : Position) : Flow {
		var file = FlowUtil.getString(args[0]);
		return ConstantDouble(FlowFileSystemHx.fileSize(file), pos);
	}

	public function fileModified(args : FlowArray<Flow>, pos : Position) : Flow {
		var file = FlowUtil.getString(args[0]);
		return ConstantDouble(FlowFileSystemHx.fileModified(file), pos);
	}

	public function resolveRelativePath(args : FlowArray<Flow>, pos : Position) : Flow  {
		var path = FlowUtil.getString(args[0]);
		return ConstantString(FlowFileSystemHx.resolveRelativePath(path), pos);
	}

	public function getFileByPath(args : FlowArray<Flow>, pos : Position) : Flow {
		var path = FlowUtil.getString(args[0]);

		return ConstantNative(FlowFileSystemHx.getFileByPath(path), pos);
	}

	public function openFileDialog(args : FlowArray<Flow>, pos : Position) : Flow {
		var maxFiles = FlowUtil.getInt(args[0]);
		var fileTypes = FlowUtil.getArray(args[1]);
		var callback = interpreter.registerRoot(args[2]);

		var me = this;
		var fTypes : Array<String> = [];
		for (ft in fileTypes) {
			fTypes.push(FlowUtil.getString(ft));
		}


		FlowFileSystemHx.openFileDialog(maxFiles, fTypes, function (files : Array<Dynamic>) {
			var fls = new FlowArray();
			for (file in files) {
				fls.push(ConstantNative(file, pos));
			}

			me.interpreter.eval(Call(me.interpreter.lookupRoot(callback), FlowArrayUtil.one(ConstantArray(fls, pos)), pos));
		});

		return ConstantVoid(pos);
	}

	public function uploadNativeFile(args : FlowArray<Flow>, pos : Position) : Flow {
		var file = FlowUtil.getNative(args[0]);
		var url = FlowUtil.getString(args[1]);
		var params = FlowUtil.getArray(args[2]);
		var onOpenFn = interpreter.registerRoot(args[3]);
		var onDataFn = interpreter.registerRoot(args[4]);
		var onErrorFn = interpreter.registerRoot(args[5]);
		var onProgressFn = interpreter.registerRoot(args[6]);
		var onCancelFn = interpreter.registerRoot(args[7]);

		var me = this;

		var onOpen = function () {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(onOpenFn), new FlowArray(), pos));
		};

		var onData = function (data : String) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(onDataFn), FlowArrayUtil.one(
				ConstantString(data, pos)
			), pos));
		};

		var onError = function (err : String) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(onErrorFn), FlowArrayUtil.one(
				ConstantString(err, pos)
			), pos));
		};

		var onProgress = function (loaded : Float, total : Float) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(onProgressFn), FlowArrayUtil.two(
				ConstantDouble(loaded, pos),
				ConstantDouble(total, pos)
			), pos));
		};

		var onCancel = function () {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(onCancelFn), new FlowArray(), pos));
		};
		
		var me = this;
		var cancelFn = function(){};
		var release = function(){
			me.interpreter.releaseRoot(onOpenFn);
			me.interpreter.releaseRoot(onDataFn);
			me.interpreter.releaseRoot(onErrorFn);
			me.interpreter.releaseRoot(onProgressFn);
			me.interpreter.releaseRoot(onCancelFn);
		};

		var parameters : Array<Array<String>> = [];
		for (param in params) {
			var keyValueArrayFlow = FlowUtil.getArray(param);
			var keyValueArray : Array<String> = [];
			for (key in keyValueArrayFlow) {
				keyValueArray.push(FlowUtil.getString(key));
			}
			parameters.push(keyValueArray);
		}

		cancelFn = FlowFileSystemHx.uploadNativeFile(file, url, parameters, onOpen, onData, onError, onProgress, onCancel);

		return NativeClosure(0, function (flow, pos) {
			release();
			cancelFn();
			return ConstantVoid(pos);
		}, pos);
	}

	public function fileName(args : FlowArray<Flow>, pos : Position) : Flow {
		var file = FlowUtil.getNative(args[0]);

		return ConstantString(FlowFileSystemHx.fileName(file), pos);
	}

	public function fileType(args : FlowArray<Flow>, pos : Position) : Flow {
		var file = FlowUtil.getNative(args[0]);

		return ConstantString(FlowFileSystemHx.fileType(file), pos);
	}

	public function fileSizeNative(args : FlowArray<Flow>, pos : Position) : Flow {
		var file = FlowUtil.getNative(args[0]);

		return ConstantDouble(FlowFileSystemHx.fileSizeNative(file), pos);
	}

	public function fileModifiedNative(args : FlowArray<Flow>, pos : Position) : Flow {
		var file = FlowUtil.getNative(args[0]);

		return ConstantDouble(FlowFileSystemHx.fileModifiedNative(file), pos);
	}

	public function fileSlice(args : FlowArray<Flow>, pos : Position) : Flow {
		var file = FlowUtil.getNative(args[0]);
		var offset = FlowUtil.getInt(args[1]);
		var end = FlowUtil.getInt(args[2]);

		return ConstantNative(FlowFileSystemHx.fileSlice(file, offset, end), pos);
	}

	public function readFile(args : FlowArray<Flow>, pos : Position) : Flow {
		var file = FlowUtil.getNative(args[0]);
		var readAs = FlowUtil.getString(args[1]);
		var onDoneFn = interpreter.registerRoot(args[2]);
		var onErrorFn = interpreter.registerRoot(args[3]);

		var me = this;

		FlowFileSystemHx.readFile(file, readAs, function (data : String) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(onDoneFn), FlowArrayUtil.one(
				ConstantString(data, pos)
			), pos));
		}, function (error : String) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(onErrorFn), FlowArrayUtil.one(
				ConstantString(error, pos)
			), pos));
		});

		return ConstantVoid(pos);
	}
}
