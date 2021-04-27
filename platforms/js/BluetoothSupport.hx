import js.Promise;

class BluetoothSupport {
    public function new() {}

    public static function __init__() {
    }

    public static function checkBluetoothSupported() {
        return untyped __js__("typeof navigator.bluetooth !== 'undefined'");
    }

    public static function requestBluetoothDevice(filter : String, onDevice : Dynamic -> Bool -> String -> String -> Void, onError : String -> Void) : Void {
        var requestDevicePromise : Promise<Dynamic> = untyped navigator.bluetooth.requestDevice(haxe.Json.parse(filter));
        requestDevicePromise.then(function (device) {
            onDevice(device.gatt, device.gatt.connected, device.id, device.name);
        }).catchError(onError);
    }

    public static function connectGattServer(gattServerNative : Dynamic, onDone : Void -> Void, onError : String -> Void) : Void {
        var connectPromise : Promise<Dynamic> = untyped gattServerNative.connect();
        connectPromise.then(function (value) {
            onDone();
        }).catchError(onError);
    }

    public static function disconnectGattServer(gattServerNative : Dynamic) : Void {
        untyped gattServerNative.disconnect();
    }

    public static function getGattServerPrimaryService(gattServerNative : Dynamic, uuid : String, onService : Dynamic -> String -> Bool -> Void, onError : String -> Void) : Void {
        var servicePromise : Promise<Dynamic> = untyped gattServerNative.getPrimaryService(uuid);
        servicePromise.then(function (service) {
            onService(service, service.uuid, service.isPrimary);
        }).catchError(onError);
    }

    public static function getServiceCharacteristic(serviceNative : Dynamic, uuid : String, onCharacteristic : Dynamic -> String -> Array<Bool> -> Void, onError : String -> Void) : Void {
        var characteristicPromise : Promise<Dynamic> = untyped serviceNative.getCharacteristic(uuid);
        characteristicPromise.then(function (characteristic) {
            if (characteristic.properties.notify) {
                untyped characteristic.startNotifications();
            }
            onCharacteristic(
                characteristic,
                characteristic.uuid, [
                    characteristic.properties.authenticatedSignedWrites,
                    characteristic.properties.broadcast,
                    characteristic.properties.indicate,
                    characteristic.properties.notify,
                    characteristic.properties.read,
                    characteristic.properties.reliableWrite,
                    characteristic.properties.writableAuxiliaries,
                    characteristic.properties.write,
                    characteristic.properties.writeWithoutResponse
                ]
            );
        }).catchError(onError);
    }

    public static function getGattServiceIncludedService(gattServiceNative : Dynamic, uuid : String, onService : Dynamic -> String -> Bool -> Void, onError : String -> Void) : Void {
        var servicePromise : Promise<Dynamic> = untyped gattServiceNative.getIncludedService(uuid);
        servicePromise.then(function (service) {
            onService(service, service.uuid, service.isPrimary);
        }).catchError(onError);
    }

    public static function addGattCharacteristicValueListener(characteristicNative : Dynamic, callback : Array<Int> -> Void) : Void -> Void {
        var cb = function (event) {
            callback(untyped __js__("[].slice.call(new Uint8Array(event.target.value.buffer))"));
        }

        untyped characteristicNative.addEventListener("characteristicvaluechanged", cb);

        return function () {
            untyped characteristicNative.removeEventListener("characteristicvaluechanged", cb);
        }
    }

    public static function readGattCharacteristicValue(characteristicNative : Dynamic, onValue : Array<Int> -> Void, onError : String -> Void) : Void {
        var valuePromise : Promise<Dynamic> = untyped characteristicNative.readValue();
        valuePromise.then(function (value) {
            onValue(untyped __js__("[].slice.call(new Uint8Array(value.buffer))"));
        }).catchError(onError);
    }

    public static function writeGattCharacteristicValue(characteristicNative : Dynamic, value : Array<Int>, onDone : Void -> Void, onError : String -> Void) : Void {
        var bitArray = untyped __js__("new UInt8Array(value);");
        var valuePromise : Promise<Dynamic> = untyped characteristicNative.writeValue(untyped bitArray.buffer);
        valuePromise.then(function (value) {
            onDone();
        }).catchError(onError);
    }

}
