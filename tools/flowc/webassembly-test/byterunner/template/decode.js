var Module;
var UTF16Decoder;

var MisalignedDoubleF64, MisalignedDoubleI32;

/*
 * Decode plain data and arrays from flow heap at baseptr starting from slot at slotptr
 */
function decode_flow_data(baseptr, slotptr)
{
    var tag = HEAPU16[(slotptr+6)>>1];

    switch (tag)
    {
        case 0x7ffe: // int
        {
            return HEAP32[slotptr>>2];
        }
        case 0xfffe: // bool
        {
            return HEAP32[slotptr>>2] != 0;
        }
        case 0x7ff1: // short string
        {
            var ptr = baseptr + HEAP32[slotptr>>2];
            var len = HEAPU16[(slotptr+4)>>1];
            if (len == 0)
                return "";
            return UTF16Decoder.decode(HEAPU8.subarray(ptr, ptr+len*2));
        }
        case 0xfff1: // long string
        {
            var ptr = baseptr + HEAP32[slotptr>>2];
            var len = (HEAPU16[(slotptr+4)>>1] << 16) | HEAPU16[ptr>>1];
            var sptr = baseptr + HEAP32[(ptr+4)>>2];
            if (len == 0)
                return "";
            return UTF16Decoder.decode(HEAPU8.subarray(sptr, sptr+len*2));
        }
        case 0x7ff2: // short array
        {
            var ptr = baseptr + HEAP32[slotptr>>2];
            var len = HEAPU16[(slotptr+4)>>1];
            var arr = []
            for (var i = 0; i < len; i++)
                arr[i] = decode_flow_data(baseptr, ptr+4+8*i);
            return arr;
        }
        case 0xfff2: // long array
        {
            var ptr = baseptr + HEAP32[slotptr>>2];
            var len = (HEAPU16[(slotptr+4)>>1] << 16) | HEAPU16[ptr>>1];
            var arr = []
            for (var i = 0; i < len; i++)
                arr[i] = decode_flow_data(baseptr, ptr+4+8*i);
            return arr;
        }
        default: // assume double
        {
            // easy if aligned to 8
            if ((slotptr & 7) == 0)
                return HEAPF64[slotptr>>3];

            // if aligned only to 4 more work is required
            if (!MisalignedDoubleF64)
            {
                var buf = new ArrayBuffer(8);
                MisalignedDoubleF64 = new Float64Array(buf);
                MisalignedDoubleI32 = new Int32Array(buf);
            }

            MisalignedDoubleI32[0] = HEAP32[(slotptr>>2)];
            MisalignedDoubleI32[1] = HEAP32[(slotptr>>2)+1];
            return MisalignedDoubleF64[0];
        }
    }
}

function _arrayToHeap(typedArray) {
    var numBytes = typedArray.length * typedArray.BYTES_PER_ELEMENT;
    var ptr = Module._malloc(numBytes);
    var heapBytes = new Uint8Array(Module.HEAPU8.buffer, ptr, numBytes);
    heapBytes.set(new Uint8Array(typedArray.buffer));
    return heapBytes;
}

function _freeArray(heapBytes) {
    Module._free(heapBytes.byteOffset);
}

function loadData(filename, onload) {
    var oReq = new XMLHttpRequest();
    oReq.open("GET", filename, true);
    oReq.responseType = "arraybuffer";

    oReq.onload = function (oEvent) {
        var arrayBuffer = oReq.response; // Note: not oReq.responseText  
        if (arrayBuffer) {
            var byteArray = new Uint8Array(arrayBuffer);
            onload(byteArray);
            //for (var i = 0; i < byteArray.byteLength; i++) {
            //    // do something with each byte in the array  
            //}
        }
    };

    oReq.send(null);
}

function _do(code) {
    var len = code.length;

    heapBytes = _arrayToHeap(code);

    Module.print('code length: ' + len);
//    Module.print('heapBytes: ' + heapBytes);

    ret = Module.ccall("run_bytecode", 'number', ['number', 'number'], [len, heapBytes.byteOffset]);

    // have to free memory somehow. but if we do this too early we will get a problems with code execution
//    _freeArray(heapBytes);

    Module.print('Result: ' + ret);
}

function proxy_NativeHx_println(baseptr,slotptr)
{
    var args = decode_flow_data(baseptr, slotptr)
    NativeHx.println(args);

    Module.print('proxy_NativeHx_println: ' + args[0]);

    loadData(args[0], function (code) {
        _do(code);
    });

    //var code = bytecode_hello3;
    //_do(code);
}

function init_proxy() {
    
}
