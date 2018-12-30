import Flow;
import FlowArray;

class HtmlSupport {
	public function new(interpreter : Interpreter) {
		this.interpreter = interpreter;
	}
	
	var interpreter : Interpreter;

	//	native getElement : (id : string) -> native = HtmlSupport.getElement;
	public function getElement(args : FlowArray<Flow>, pos : Position) : Flow  {
		var id = FlowUtil.getString(args[0]);
		#if js
			var e = cast js.Browser.document.getElementById(id);
			return ConstantNative(e, pos);
		#else
			// TODO: Implement for flash and neko
			return ConstantNative(null, pos);
		#end
	}

	// native getElementProperty : (element : native, property : string) -> string = HtmlSupport.getElementProperty;
	public function getElementProperty(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if js
			var element : js.html.Element = FlowUtil.getNative(args[0]);
		#else
			// TODO: Implement for flash and neko
			var element = FlowUtil.getNative(args[0]);
		#end
		var property = FlowUtil.getString(args[1]);
		var value = Reflect.field(element, property);
		return ConstantString("" + value, pos);
	}

	// native setElementProperty : (element : native, property : string, value : string) -> void = HtmlSupport.setElementProperty;
	public function setElementProperty(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if js
			var element : js.html.Element = FlowUtil.getNative(args[0]);
		#else
			// TODO: Implement for flash and neko
			var element = FlowUtil.getNative(args[0]);
		#end
		var property = FlowUtil.getString(args[1]);
		var value = FlowUtil.getString(args[2]);
		if (Reflect.field(element, property) != value) {
			Reflect.setField(element, property, value);
		}
		return ConstantVoid(pos);
	}
	
	public function getElementChild(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if js
			var element : js.html.Element = FlowUtil.getNative(args[0]);
		#else
			// TODO: Implement for flash and neko
			var element = FlowUtil.getNative(args[0]);
		#end
		var child = FlowUtil.getInt(args[1]);
		var value = Reflect.field(element, "children")[child];
		return ConstantNative(value, pos);
	}
	
	// native getElementStyle : (element : native, property : string) -> string = HtmlSupport.getElementStyle;
	public function getElementStyle(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if js
			var element : js.html.Element = FlowUtil.getNative(args[0]);
		#else
			// TODO: Implement for flash and neko
			var element = FlowUtil.getNative(args[0]);
		#end
		var property = FlowUtil.getString(args[1]);
		var value = Reflect.field(element.style, property);
		return ConstantString("" + value, pos);
	}

	// native setElementStyle : (element : native, style : string, value : string) -> void = HtmlSupport.setElementStyle;
	public function setElementStyle(args : FlowArray<Flow>, pos : Position) : Flow {
		#if js
			var element : js.html.Element = FlowUtil.getNative(args[0]);
		#else
			var element = FlowUtil.getNative(args[0]);
		#end
		var property = FlowUtil.getString(args[1]);
		var value = FlowUtil.getString(args[2]);
		if (Reflect.field(element.style, property) != value) {
			Reflect.setField(element.style, property, value);
		}
		return ConstantVoid(pos);
	}
	
	
	public function createElement(args : FlowArray<Flow>, pos : Position) : Flow {
		#if js
			var kind = FlowUtil.getString(args[0]);
			return ConstantNative(cast js.Browser.document.createElement(kind), pos);
		#else
			// TODO: Implement for flash and neko
			return ConstantNative(null, pos);
		#end
	}

	public function appendElement(args : FlowArray<Flow>, pos : Position) : Flow {
		#if js
			var parent : js.html.Element = FlowUtil.getNative(args[0]);
			var element : js.html.Element = FlowUtil.getNative(args[1]);
			parent.appendChild(element);
		#else
			// TODO: Implement for flash and neko
		#end
		return ConstantVoid(pos);
	}

	public function removeElement(args : FlowArray<Flow>, pos : Position) : Flow {
		#if js
			var parent : js.html.Element = FlowUtil.getNative(args[0]);
			var element : js.html.Element = FlowUtil.getNative(args[1]);
			parent.removeChild(element);
		#else
			// TODO: Implement for flash and neko
		#end
		return ConstantVoid(pos);
	}
	
	public function addElementEventHandler(args : FlowArray<Flow>, pos : Position) : Flow {
		#if js
			var clip : js.html.Element = FlowUtil.getNative(args[0]);
			var event = FlowUtil.getString(args[1]);
			var fn = interpreter.registerRoot(args[2]);
			Reflect.setField(clip, event, function() {
				interpreter.eval(Call(interpreter.lookupRoot(fn), new FlowArray(), pos));
			});
			
			return NativeClosure(0, function(flow, pos) {
				Reflect.setField(clip, event, null);
				interpreter.releaseRoot(fn);
				return ConstantVoid(pos);
			}, pos);
		#else
			return NativeClosure(0, function(flow, pos) {
				return ConstantVoid(pos);
			}, pos);
		#end
		
	}
}
