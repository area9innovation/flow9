all : test.html

pre.js : js/pixi.min.js js/pixi.filters.js pre-orig.js pre-my.js
	cat $^ > $@

test.html : test.cpp pre.js post.js
	emcc test.cpp --pre-js pre.js --post-js post.js -s WASM=1 -o test.html
