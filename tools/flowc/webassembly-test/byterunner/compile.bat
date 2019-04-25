cls
call emcc -s WASM=1 -std=c++1z -I "..\..\..\..\..\flow9\platforms\cpp\core" --pre-js template/pixi.min.js --pre-js template/pixi-dfont.js --pre-js template/rendersupportpixi.js --pre-js template/test_ad.js --pre-js template/decode.js -s EXTRA_EXPORTED_RUNTIME_METHODS=['ccall','stringToUTF16'] -g ..\..\..\..\..\flow9\platforms\cpp\core\Utf8.cpp byterunner.cpp -o out/byterunner.html


