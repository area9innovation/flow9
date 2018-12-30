export var CMP = HaxeRuntime.compareByValue;
export function OTC (fn) {
	var stateStack = [];
	var wrapper = function() {};
	wrapper = function() {
		if (arguments.callee.caller != fn && arguments.callee.caller != wrapper) { // External call
			stateStack.push({active : false, nextArgs : null});
			return wrapper.apply(this, arguments);
		}
		var result;
		var state = stateStack[stateStack.length - 1];
		state.nextArgs = arguments;
		if (!state.active) {
			state.active = true;
			while (state.nextArgs) {
				var args = state.nextArgs;
				state.nextArgs = null;
				result = fn.apply(this, args);
			}
			state.active = false;
			stateStack.pop();
		}
		return result;
	};
	return wrapper;
}
