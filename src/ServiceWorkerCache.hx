import Flow;
import FlowArray;
import ServiceWorkerCacheHx;

class ServiceWorkerCache {
    public function new(interpreter : Interpreter) {
        this.interpreter = interpreter;
    }
    
    var interpreter : Interpreter;

    public function registerCacheServiceWorker(args : FlowArray<Flow>, pos : Position) : Flow {
        var cb_root = interpreter.registerRoot(args[0]);
        var cb_wrapper = function(success : Bool) {
            var r = interpreter.lookupRoot(cb_root);
            interpreter.releaseRoot(cb_root);
            interpreter.eval(Call(r, FlowArrayUtil.one(ConstantBool(success, pos)), pos));
        };
        ServiceWorkerCacheHx.registerCacheServiceWorker(cb_wrapper);

        return ConstantVoid(pos);
    }

    public function unregisterCacheServiceWorker(args : FlowArray<Flow>, pos : Position) : Flow {
        var cb_root = interpreter.registerRoot(args[0]);
        var cb_wrapper = function(success : Bool) {
            var r = interpreter.lookupRoot(cb_root);
            interpreter.releaseRoot(cb_root);
            interpreter.eval(Call(r, FlowArrayUtil.one(ConstantBool(success, pos)), pos));
        };
        ServiceWorkerCacheHx.unregisterCacheServiceWorker(cb_wrapper);

        return ConstantVoid(pos);
    }

    public function checkCacheServiceWorkerRegistered(args : FlowArray<Flow>, pos : Position) : Flow {
        var cb_root = interpreter.registerRoot(args[0]);
        var cb_wrapper = function(registered : Bool) {
            var r = interpreter.lookupRoot(cb_root);
            interpreter.releaseRoot(cb_root);
            interpreter.eval(Call(r, FlowArrayUtil.one(ConstantBool(registered, pos)), pos));
        };
        ServiceWorkerCacheHx.checkCacheServiceWorkerRegistered(cb_wrapper);

        return ConstantVoid(pos);
    }
}