package com.area9innovation.flow;

class BluetoothSupport {
    /*public new {}

    public static __init__() {
    }*/

    public Boolean checkBluetoothSupported() {
        return false;
    }

    public Object requestBluetoothDevice(String filter, Func4<Object, Object, Boolean, String, String> onDevice, Func1<Object, String> onError)  {
        return null;
    }

    public Object connectGattServer(Object gattServerNative, Func0<Object> onDone, Func1<Object, String> onError) {
        return null;
    }

    public Object disconnectGattServer(Object gattServerNative) {
        return null;
    }

    public Object getGattServerPrimaryService(Object gattServerNative, String uuid, Func3<Object, Object, String, Boolean> onService, Func1<Object, String> onError) {
        return null;
    }

    public Object getServiceCharacteristic(Object serviceNative, String uuid, Func3<Object, Object, String, Boolean[]> onCharacteristic, Func1<Object, String> onError) {
        return null;
    }

    public Object getGattServiceIncludedService(Object gattServiceNative, String uuid, Func3<Object, Object, String, Boolean> onService, Func1<Object, String> onError) {
        return null;
    }

    private Func0<Object> no_op = new Func0<Object>() {
		public Object invoke() { return null; }
	};

    public Func0<Object> addGattCharacteristicValueListener(Object characteristicNative, Func1<Object, Integer[]> callback) {
        return no_op;
    }

    public Object readGattCharacteristicValue(Object characteristicNative, Func1<Object, Integer[]> onValue, Func1<Object, String> onError) {
        return null;
    }

    public Object writeGattCharacteristicValue(Object characteristicNative, Integer[] value, Func1<Object, Object> onDone, Func1<Object, String> onError) {
        return null;
    }

}
