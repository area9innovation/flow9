/* TODO: non-Haxe runtime goes here */
/* TODO: JS Structures goes here */
/* TODO: Flowc JS runtime goes here */

$0=NativeHx.concat;$1=NativeHx.length__;function $2(_0,_1,_2){if(($1(_0)<$1(_2))){return $0($0(_0,_1),_2);}else{return $0(_0,$0(_1,_2));}}function $3(_0){return $4(_0,0,$1(_0));}function $4(_0,_1,_2){if((_2<=3)){if((_2==1)){return _0[_1];}else{if((_2==2)){return $0(_0[_1],_0[((_1+1)|0)]);}else{if((_2==3)){return $2(_0[_1],_0[((_1+1)|0)],_0[((_1+2)|0)]);}else{return [];}}}}else{var _3=((_2/2)|0);return $0($4(_0,_1,_3),$4(_0,((_1+_3)|0),((_2-_3)|0)));}}main();