/* TODO: non-Haxe runtime goes here */
/* TODO: JS Structures goes here */
/* TODO: Flowc JS runtime goes here */

function $0(_0,_1){if((_0)._id==0){return {_id:0};}else{var _2=_0.J;return {_id:1,J:_1(_2)};}}function $1(_0,_1){if((_0==0.0)){if((_1<=0)){return {_id:0};}else{return {_id:1,J:0.0};}}else{if((_1==0)){return {_id:1,J:1.0};}else{if((_1>0)){var _2=$1(_0,((_1/2)|0));if((((_1%2)|0)==0)){return $0(_2,(function(_3){return (_3*_3);}));}else{return $0(_2,(function(_3){return ((_3*_3)*_0);}));}}else{return $0($1(_0,(-(_1)|0)),(function(_3){return (1.0/_3);}));}}}}main();