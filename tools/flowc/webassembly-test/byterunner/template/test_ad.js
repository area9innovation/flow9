var IDHandler = {

    ids: [],
    free_ids: [],

    // get an integer ID for a JS object. this keeps a reference to it, preventing GC'ing
    createObjectId: function (obj) {
        var id = IDHandler.ids.length;

        if (IDHandler.free_ids.length > 0) {
            // reuse id from free_ids array
            id = IDHandler.free_ids.shift();
        }

        Module.print('createObjectId ' + obj + ' => ' + id);
        IDHandler.ids[id] = obj;
        return id;
    },

    // get a JS object from an integer ID
    getObjectFromID: function (id) {
        return IDHandler.ids[id];
    },

    // releases an object that has an ID. this allows it to be GD'd
    revokeObjectId: function (id) {
        IDHandler.ids[id] = null;
        IDHandler.free_ids.unshift(id);
        Module.print('revokeObjectId: ' + id + ' length: ' + IDHandler.ids.length + ' free_ids.length: ' + IDHandler.free_ids.length);
    },
};

var testApi = {
    // enc - bit per char
    encodeString: function (str) {
        var bufLen = str.length * 2 + 2;
        var strPtr = Module._malloc(bufLen);
        Module.stringToUTF16(str, strPtr, bufLen);
        return strPtr;
    },
    //encodeString: function (str, enc) {
    //    switch (enc) {
    //        case 2: // 16 
    //            var bufLen = str.length * 2 + 2;
    //            var strPtr = Module._malloc(bufLen);
    //            Module.stringToUTF16(str, strPtr, bufLen);
    //            return strPtr;
    //        case 4: // 32
    //            var bufLen = str.length * 4 + 4;
    //            var strPtr = Module._malloc(bufLen);
    //            Module.stringToUTF32(str, strPtr, bufLen);
    //            return strPtr;
    //    }

    //    // 8 by default
    //    var bufLen = str.length + 1;
    //    var strPtr = Module._malloc(bufLen);
    //    Module.stringToUTF8(str, strPtr, bufLen);
    //    return strPtr;
    //},

    executeCallback: function (func_id, revoke) {
        var f = IDHandler.getObjectFromID(func_id);
        if (f) {
            f();
            if (revoke == true) {
                IDHandler.revokeObjectId(func_id);
            }
        }
    },

    // type can be either 'i8', 'i16', 'i32', 'f32', 'f64'
    readArray: function (ptr, size, type) {
        f = function (i) { return HEAP8[ptr + i] }; // i8 by default
        switch (type) {
            case 'i16':
                f = function (i) { return HEAP16[(ptr + 2 * i) >> 1] };
                break;
            case 'i32':
                f = function (i) { return HEAP32[(ptr + 4 * i) >> 2] };
                break;
            case 'f32':
                f = function (i) { return HEAPF32[(ptr + 4 * i) >> 2] };
                break;
            case 'f64':
                f = function (i) { return HEAPF64[(ptr + 8 * i) >> 3] };
                break;
        }

        var a = [];
        for (i = 0; i < size; ++i) {
            a.push(f(i));
        }

        Module.print('readArray ptr: ' + ptr + ' size: ' + size + ' type: ' + type + ' array: ' + a);
        return a;
    }
};
