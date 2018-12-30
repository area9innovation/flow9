/* TODO: non-Haxe runtime goes here */
/* TODO: JS Structures goes here */
/* TODO: Flowc JS runtime goes here */

$0=NativeHx.strIndexOf;$1=NativeHx.strlen;$2=NativeHx.substring;function $3(_0,_1,_2){if((_0)._id==0){return _2;}else{var _3=_0.J;return _1(_3);}}function $4(_0,_1){var _2=$0(_0,_1);if((_2<0)){return {_id:0};}else{return {_id:1,J:_2};}}function $5(_0){return (function(_1){return $3($4(_1,"/"),(function(_2){return "";}),_1);})((function(_1){return $3($4(_1,"."),(function(_2){return $2(_1,((_2+1)|0),(((($1(_1)-_2)|0)-1)|0));}),"");})($3($4(_0,"?"),(function(_2){return "";}),_0)));}main();