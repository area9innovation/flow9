/*!
 * pixi.js - v4.2.2
 * Compiled Thu, 17 Nov 2016 14:05:52 UTC
 *
 * pixi.js is licensed under the MIT License.
 * http://www.opensource.org/licenses/mit-license
 */
!function(t){if("object"==typeof exports&&"undefined"!=typeof module)module.exports=t();else if("function"==typeof define&&define.amd)define([],t);else{var e;e="undefined"!=typeof window?window:"undefined"!=typeof global?global:"undefined"!=typeof self?self:this,e.PIXI=t()}}(function(){var t;return function t(e,r,n){function i(s,a){if(!r[s]){if(!e[s]){var u="function"==typeof require&&require;if(!a&&u)return u(s,!0);if(o)return o(s,!0);var h=new Error("Cannot find module '"+s+"'");throw h.code="MODULE_NOT_FOUND",h}var l=r[s]={exports:{}};e[s][0].call(l.exports,function(t){var r=e[s][1][t];return i(r?r:t)},l,l.exports,t,e,r,n)}return r[s].exports}for(var o="function"==typeof require&&require,s=0;s<n.length;s++)i(n[s]);return i}({1:[function(t,e,r){"use strict";"use restrict";function n(t){var e=32;return t&=-t,t&&e--,65535&t&&(e-=16),16711935&t&&(e-=8),252645135&t&&(e-=4),858993459&t&&(e-=2),1431655765&t&&(e-=1),e}var i=32;r.INT_BITS=i,r.INT_MAX=2147483647,r.INT_MIN=-1<<i-1,r.sign=function(t){return(t>0)-(t<0)},r.abs=function(t){var e=t>>i-1;return(t^e)-e},r.min=function(t,e){return e^(t^e)&-(t<e)},r.max=function(t,e){return t^(t^e)&-(t<e)},r.isPow2=function(t){return!(t&t-1||!t)},r.log2=function(t){var e,r;return e=(t>65535)<<4,t>>>=e,r=(t>255)<<3,t>>>=r,e|=r,r=(t>15)<<2,t>>>=r,e|=r,r=(t>3)<<1,t>>>=r,e|=r,e|t>>1},r.log10=function(t){return t>=1e9?9:t>=1e8?8:t>=1e7?7:t>=1e6?6:t>=1e5?5:t>=1e4?4:t>=1e3?3:t>=100?2:t>=10?1:0},r.popCount=function(t){return t-=t>>>1&1431655765,t=(858993459&t)+(t>>>2&858993459),16843009*(t+(t>>>4)&252645135)>>>24},r.countTrailingZeros=n,r.nextPow2=function(t){return t+=0===t,--t,t|=t>>>1,t|=t>>>2,t|=t>>>4,t|=t>>>8,t|=t>>>16,t+1},r.prevPow2=function(t){return t|=t>>>1,t|=t>>>2,t|=t>>>4,t|=t>>>8,t|=t>>>16,t-(t>>>1)},r.parity=function(t){return t^=t>>>16,t^=t>>>8,t^=t>>>4,t&=15,27030>>>t&1};var o=new Array(256);!function(t){for(var e=0;e<256;++e){var r=e,n=e,i=7;for(r>>>=1;r;r>>>=1)n<<=1,n|=1&r,--i;t[e]=n<<i&255}}(o),r.reverse=function(t){return o[255&t]<<24|o[t>>>8&255]<<16|o[t>>>16&255]<<8|o[t>>>24&255]},r.interleave2=function(t,e){return t&=65535,t=16711935&(t|t<<8),t=252645135&(t|t<<4),t=858993459&(t|t<<2),t=1431655765&(t|t<<1),e&=65535,e=16711935&(e|e<<8),e=252645135&(e|e<<4),e=858993459&(e|e<<2),e=1431655765&(e|e<<1),t|e<<1},r.deinterleave2=function(t,e){return t=t>>>e&1431655765,t=858993459&(t|t>>>1),t=252645135&(t|t>>>2),t=16711935&(t|t>>>4),t=65535&(t|t>>>16),t<<16>>16},r.interleave3=function(t,e,r){return t&=1023,t=4278190335&(t|t<<16),t=251719695&(t|t<<8),t=3272356035&(t|t<<4),t=1227133513&(t|t<<2),e&=1023,e=4278190335&(e|e<<16),e=251719695&(e|e<<8),e=3272356035&(e|e<<4),e=1227133513&(e|e<<2),t|=e<<1,r&=1023,r=4278190335&(r|r<<16),r=251719695&(r|r<<8),r=3272356035&(r|r<<4),r=1227133513&(r|r<<2),t|r<<2},r.deinterleave3=function(t,e){return t=t>>>e&1227133513,t=3272356035&(t|t>>>2),t=251719695&(t|t>>>4),t=4278190335&(t|t>>>8),t=1023&(t|t>>>16),t<<22>>22},r.nextCombination=function(t){var e=t|t-1;return e+1|(~e&-~e)-1>>>n(t)+1}},{}],2:[function(t,e,r){"use strict";function n(t,e,r){r=r||2;var n=e&&e.length,o=n?e[0]*r:t.length,a=i(t,0,o,r,!0),u=[];if(!a)return u;var h,l,d,f,p,v,y;if(n&&(a=c(t,e,a,r)),t.length>80*r){h=d=t[0],l=f=t[1];for(var g=r;g<o;g+=r)p=t[g],v=t[g+1],p<h&&(h=p),v<l&&(l=v),p>d&&(d=p),v>f&&(f=v);y=Math.max(d-h,f-l)}return s(a,u,r,h,l,y),u}function i(t,e,r,n,i){var o,s;if(i===D(t,e,r,n)>0)for(o=e;o<r;o+=n)s=P(o,t[o],t[o+1],s);else for(o=r-n;o>=e;o-=n)s=P(o,t[o],t[o+1],s);return s&&T(s,s.next)&&(C(s),s=s.next),s}function o(t,e){if(!t)return t;e||(e=t);var r,n=t;do if(r=!1,n.steiner||!T(n,n.next)&&0!==x(n.prev,n,n.next))n=n.next;else{if(C(n),n=e=n.prev,n===n.next)return null;r=!0}while(r||n!==e);return e}function s(t,e,r,n,i,c,d){if(t){!d&&c&&v(t,n,i,c);for(var f,p,y=t;t.prev!==t.next;)if(f=t.prev,p=t.next,c?u(t,n,i,c):a(t))e.push(f.i/r),e.push(t.i/r),e.push(p.i/r),C(t),t=p.next,y=p.next;else if(t=p,t===y){d?1===d?(t=h(t,e,r),s(t,e,r,n,i,c,2)):2===d&&l(t,e,r,n,i,c):s(o(t),e,r,n,i,c,1);break}}}function a(t){var e=t.prev,r=t,n=t.next;if(x(e,r,n)>=0)return!1;for(var i=t.next.next;i!==t.prev;){if(_(e.x,e.y,r.x,r.y,n.x,n.y,i.x,i.y)&&x(i.prev,i,i.next)>=0)return!1;i=i.next}return!0}function u(t,e,r,n){var i=t.prev,o=t,s=t.next;if(x(i,o,s)>=0)return!1;for(var a=i.x<o.x?i.x<s.x?i.x:s.x:o.x<s.x?o.x:s.x,u=i.y<o.y?i.y<s.y?i.y:s.y:o.y<s.y?o.y:s.y,h=i.x>o.x?i.x>s.x?i.x:s.x:o.x>s.x?o.x:s.x,l=i.y>o.y?i.y>s.y?i.y:s.y:o.y>s.y?o.y:s.y,c=g(a,u,e,r,n),d=g(h,l,e,r,n),f=t.nextZ;f&&f.z<=d;){if(f!==t.prev&&f!==t.next&&_(i.x,i.y,o.x,o.y,s.x,s.y,f.x,f.y)&&x(f.prev,f,f.next)>=0)return!1;f=f.nextZ}for(f=t.prevZ;f&&f.z>=c;){if(f!==t.prev&&f!==t.next&&_(i.x,i.y,o.x,o.y,s.x,s.y,f.x,f.y)&&x(f.prev,f,f.next)>=0)return!1;f=f.prevZ}return!0}function h(t,e,r){var n=t;do{var i=n.prev,o=n.next.next;!T(i,o)&&w(i,n,n.next,o)&&O(i,o)&&O(o,i)&&(e.push(i.i/r),e.push(n.i/r),e.push(o.i/r),C(n),C(n.next),n=t=o),n=n.next}while(n!==t);return n}function l(t,e,r,n,i,a){var u=t;do{for(var h=u.next.next;h!==u.prev;){if(u.i!==h.i&&b(u,h)){var l=M(u,h);return u=o(u,u.next),l=o(l,l.next),s(u,e,r,n,i,a),void s(l,e,r,n,i,a)}h=h.next}u=u.next}while(u!==t)}function c(t,e,r,n){var s,a,u,h,l,c=[];for(s=0,a=e.length;s<a;s++)u=e[s]*n,h=s<a-1?e[s+1]*n:t.length,l=i(t,u,h,n,!1),l===l.next&&(l.steiner=!0),c.push(m(l));for(c.sort(d),s=0;s<c.length;s++)f(c[s],r),r=o(r,r.next);return r}function d(t,e){return t.x-e.x}function f(t,e){if(e=p(t,e)){var r=M(e,t);o(r,r.next)}}function p(t,e){var r,n=e,i=t.x,o=t.y,s=-(1/0);do{if(o<=n.y&&o>=n.next.y){var a=n.x+(o-n.y)*(n.next.x-n.x)/(n.next.y-n.y);if(a<=i&&a>s){if(s=a,a===i){if(o===n.y)return n;if(o===n.next.y)return n.next}r=n.x<n.next.x?n:n.next}}n=n.next}while(n!==e);if(!r)return null;if(i===s)return r.prev;var u,h=r,l=r.x,c=r.y,d=1/0;for(n=r.next;n!==h;)i>=n.x&&n.x>=l&&_(o<c?i:s,o,l,c,o<c?s:i,o,n.x,n.y)&&(u=Math.abs(o-n.y)/(i-n.x),(u<d||u===d&&n.x>r.x)&&O(n,t)&&(r=n,d=u)),n=n.next;return r}function v(t,e,r,n){var i=t;do null===i.z&&(i.z=g(i.x,i.y,e,r,n)),i.prevZ=i.prev,i.nextZ=i.next,i=i.next;while(i!==t);i.prevZ.nextZ=null,i.prevZ=null,y(i)}function y(t){var e,r,n,i,o,s,a,u,h=1;do{for(r=t,t=null,o=null,s=0;r;){for(s++,n=r,a=0,e=0;e<h&&(a++,n=n.nextZ,n);e++);for(u=h;a>0||u>0&&n;)0===a?(i=n,n=n.nextZ,u--):0!==u&&n?r.z<=n.z?(i=r,r=r.nextZ,a--):(i=n,n=n.nextZ,u--):(i=r,r=r.nextZ,a--),o?o.nextZ=i:t=i,i.prevZ=o,o=i;r=n}o.nextZ=null,h*=2}while(s>1);return t}function g(t,e,r,n,i){return t=32767*(t-r)/i,e=32767*(e-n)/i,t=16711935&(t|t<<8),t=252645135&(t|t<<4),t=858993459&(t|t<<2),t=1431655765&(t|t<<1),e=16711935&(e|e<<8),e=252645135&(e|e<<4),e=858993459&(e|e<<2),e=1431655765&(e|e<<1),t|e<<1}function m(t){var e=t,r=t;do e.x<r.x&&(r=e),e=e.next;while(e!==t);return r}function _(t,e,r,n,i,o,s,a){return(i-s)*(e-a)-(t-s)*(o-a)>=0&&(t-s)*(n-a)-(r-s)*(e-a)>=0&&(r-s)*(o-a)-(i-s)*(n-a)>=0}function b(t,e){return t.next.i!==e.i&&t.prev.i!==e.i&&!E(t,e)&&O(t,e)&&O(e,t)&&S(t,e)}function x(t,e,r){return(e.y-t.y)*(r.x-e.x)-(e.x-t.x)*(r.y-e.y)}function T(t,e){return t.x===e.x&&t.y===e.y}function w(t,e,r,n){return!!(T(t,e)&&T(r,n)||T(t,n)&&T(r,e))||x(t,e,r)>0!=x(t,e,n)>0&&x(r,n,t)>0!=x(r,n,e)>0}function E(t,e){var r=t;do{if(r.i!==t.i&&r.next.i!==t.i&&r.i!==e.i&&r.next.i!==e.i&&w(r,r.next,t,e))return!0;r=r.next}while(r!==t);return!1}function O(t,e){return x(t.prev,t,t.next)<0?x(t,e,t.next)>=0&&x(t,t.prev,e)>=0:x(t,e,t.prev)<0||x(t,t.next,e)<0}function S(t,e){var r=t,n=!1,i=(t.x+e.x)/2,o=(t.y+e.y)/2;do r.y>o!=r.next.y>o&&i<(r.next.x-r.x)*(o-r.y)/(r.next.y-r.y)+r.x&&(n=!n),r=r.next;while(r!==t);return n}function M(t,e){var r=new R(t.i,t.x,t.y),n=new R(e.i,e.x,e.y),i=t.next,o=e.prev;return t.next=e,e.prev=t,r.next=i,i.prev=r,n.next=r,r.prev=n,o.next=n,n.prev=o,n}function P(t,e,r,n){var i=new R(t,e,r);return n?(i.next=n.next,i.prev=n,n.next.prev=i,n.next=i):(i.prev=i,i.next=i),i}function C(t){t.next.prev=t.prev,t.prev.next=t.next,t.prevZ&&(t.prevZ.nextZ=t.nextZ),t.nextZ&&(t.nextZ.prevZ=t.prevZ)}function R(t,e,r){this.i=t,this.x=e,this.y=r,this.prev=null,this.next=null,this.z=null,this.prevZ=null,this.nextZ=null,this.steiner=!1}function D(t,e,r,n){for(var i=0,o=e,s=r-n;o<r;o+=n)i+=(t[s]-t[o])*(t[o+1]+t[s+1]),s=o;return i}e.exports=n,n.deviation=function(t,e,r,n){var i=e&&e.length,o=i?e[0]*r:t.length,s=Math.abs(D(t,0,o,r));if(i)for(var a=0,u=e.length;a<u;a++){var h=e[a]*r,l=a<u-1?e[a+1]*r:t.length;s-=Math.abs(D(t,h,l,r))}var c=0;for(a=0;a<n.length;a+=3){var d=n[a]*r,f=n[a+1]*r,p=n[a+2]*r;c+=Math.abs((t[d]-t[p])*(t[f+1]-t[d+1])-(t[d]-t[f])*(t[p+1]-t[d+1]))}return 0===s&&0===c?0:Math.abs((c-s)/s)},n.flatten=function(t){for(var e=t[0][0].length,r={vertices:[],holes:[],dimensions:e},n=0,i=0;i<t.length;i++){for(var o=0;o<t[i].length;o++)for(var s=0;s<e;s++)r.vertices.push(t[i][o][s]);i>0&&(n+=t[i-1].length,r.holes.push(n))}return r}},{}],3:[function(t,e,r){"use strict";function n(){}function i(t,e,r){this.fn=t,this.context=e,this.once=r||!1}function o(){this._events=new n,this._eventsCount=0}var s=Object.prototype.hasOwnProperty,a="~";Object.create&&(n.prototype=Object.create(null),(new n).__proto__||(a=!1)),o.prototype.eventNames=function(){var t,e,r=[];if(0===this._eventsCount)return r;for(e in t=this._events)s.call(t,e)&&r.push(a?e.slice(1):e);return Object.getOwnPropertySymbols?r.concat(Object.getOwnPropertySymbols(t)):r},o.prototype.listeners=function(t,e){var r=a?a+t:t,n=this._events[r];if(e)return!!n;if(!n)return[];if(n.fn)return[n.fn];for(var i=0,o=n.length,s=new Array(o);i<o;i++)s[i]=n[i].fn;return s},o.prototype.emit=function(t,e,r,n,i,o){var s=a?a+t:t;if(!this._events[s])return!1;var u,h,l=this._events[s],c=arguments.length;if(l.fn){switch(l.once&&this.removeListener(t,l.fn,void 0,!0),c){case 1:return l.fn.call(l.context),!0;case 2:return l.fn.call(l.context,e),!0;case 3:return l.fn.call(l.context,e,r),!0;case 4:return l.fn.call(l.context,e,r,n),!0;case 5:return l.fn.call(l.context,e,r,n,i),!0;case 6:return l.fn.call(l.context,e,r,n,i,o),!0}for(h=1,u=new Array(c-1);h<c;h++)u[h-1]=arguments[h];l.fn.apply(l.context,u)}else{var d,f=l.length;for(h=0;h<f;h++)switch(l[h].once&&this.removeListener(t,l[h].fn,void 0,!0),c){case 1:l[h].fn.call(l[h].context);break;case 2:l[h].fn.call(l[h].context,e);break;case 3:l[h].fn.call(l[h].context,e,r);break;case 4:l[h].fn.call(l[h].context,e,r,n);break;default:if(!u)for(d=1,u=new Array(c-1);d<c;d++)u[d-1]=arguments[d];l[h].fn.apply(l[h].context,u)}}return!0},o.prototype.on=function(t,e,r){var n=new i(e,r||this),o=a?a+t:t;return this._events[o]?this._events[o].fn?this._events[o]=[this._events[o],n]:this._events[o].push(n):(this._events[o]=n,this._eventsCount++),this},o.prototype.once=function(t,e,r){var n=new i(e,r||this,(!0)),o=a?a+t:t;return this._events[o]?this._events[o].fn?this._events[o]=[this._events[o],n]:this._events[o].push(n):(this._events[o]=n,this._eventsCount++),this},o.prototype.removeListener=function(t,e,r,i){var o=a?a+t:t;if(!this._events[o])return this;if(!e)return 0===--this._eventsCount?this._events=new n:delete this._events[o],this;var s=this._events[o];if(s.fn)s.fn!==e||i&&!s.once||r&&s.context!==r||(0===--this._eventsCount?this._events=new n:delete this._events[o]);else{for(var u=0,h=[],l=s.length;u<l;u++)(s[u].fn!==e||i&&!s[u].once||r&&s[u].context!==r)&&h.push(s[u]);h.length?this._events[o]=1===h.length?h[0]:h:0===--this._eventsCount?this._events=new n:delete this._events[o]}return this},o.prototype.removeAllListeners=function(t){var e;return t?(e=a?a+t:t,this._events[e]&&(0===--this._eventsCount?this._events=new n:delete this._events[e])):(this._events=new n,this._eventsCount=0),this},o.prototype.off=o.prototype.removeListener,o.prototype.addListener=o.prototype.on,o.prototype.setMaxListeners=function(){return this},o.prefixed=a,o.EventEmitter=o,"undefined"!=typeof e&&(e.exports=o)},{}],4:[function(e,r,n){!function(e){var n=/iPhone/i,i=/iPod/i,o=/iPad/i,s=/(?=.*\bAndroid\b)(?=.*\bMobile\b)/i,a=/Android/i,u=/(?=.*\bAndroid\b)(?=.*\bSD4930UR\b)/i,h=/(?=.*\bAndroid\b)(?=.*\b(?:KFOT|KFTT|KFJWI|KFJWA|KFSOWI|KFTHWI|KFTHWA|KFAPWI|KFAPWA|KFARWI|KFASWI|KFSAWI|KFSAWA)\b)/i,l=/IEMobile/i,c=/(?=.*\bWindows\b)(?=.*\bARM\b)/i,d=/BlackBerry/i,f=/BB10/i,p=/Opera Mini/i,v=/(CriOS|Chrome)(?=.*\bMobile\b)/i,y=/(?=.*\bFirefox\b)(?=.*\bMobile\b)/i,g=new RegExp("(?:Nexus 7|BNTV250|Kindle Fire|Silk|GT-P1000)","i"),m=function(t,e){return t.test(e)},_=function(t){var e=t||navigator.userAgent,r=e.split("[FBAN");if("undefined"!=typeof r[1]&&(e=r[0]),r=e.split("Twitter"),"undefined"!=typeof r[1]&&(e=r[0]),this.apple={phone:m(n,e),ipod:m(i,e),tablet:!m(n,e)&&m(o,e),device:m(n,e)||m(i,e)||m(o,e)},this.amazon={phone:m(u,e),tablet:!m(u,e)&&m(h,e),device:m(u,e)||m(h,e)},this.android={phone:m(u,e)||m(s,e),tablet:!m(u,e)&&!m(s,e)&&(m(h,e)||m(a,e)),device:m(u,e)||m(h,e)||m(s,e)||m(a,e)},this.windows={phone:m(l,e),tablet:m(c,e),device:m(l,e)||m(c,e)},this.other={blackberry:m(d,e),blackberry10:m(f,e),opera:m(p,e),firefox:m(y,e),chrome:m(v,e),device:m(d,e)||m(f,e)||m(p,e)||m(y,e)||m(v,e)},this.seven_inch=m(g,e),this.any=this.apple.device||this.android.device||this.windows.device||this.other.device||this.seven_inch,this.phone=this.apple.phone||this.android.phone||this.windows.phone,this.tablet=this.apple.tablet||this.android.tablet||this.windows.tablet,"undefined"==typeof window)return this},b=function(){var t=new _;return t.Class=_,t};"undefined"!=typeof r&&r.exports&&"undefined"==typeof window?r.exports=_:"undefined"!=typeof r&&r.exports&&"undefined"!=typeof window?r.exports=b():"function"==typeof t&&t.amd?t("isMobile",[],e.isMobile=b()):e.isMobile=b()}(this)},{}],5:[function(t,e,r){"use strict";function n(t){if(null===t||void 0===t)throw new TypeError("Object.assign cannot be called with null or undefined");return Object(t)}function i(){try{if(!Object.assign)return!1;var t=new String("abc");if(t[5]="de","5"===Object.getOwnPropertyNames(t)[0])return!1;for(var e={},r=0;r<10;r++)e["_"+String.fromCharCode(r)]=r;var n=Object.getOwnPropertyNames(e).map(function(t){return e[t]});if("0123456789"!==n.join(""))return!1;var i={};return"abcdefghijklmnopqrst".split("").forEach(function(t){i[t]=t}),"abcdefghijklmnopqrst"===Object.keys(Object.assign({},i)).join("")}catch(t){return!1}}var o=Object.prototype.hasOwnProperty,s=Object.prototype.propertyIsEnumerable;e.exports=i()?Object.assign:function(t,e){for(var r,i,a=n(t),u=1;u<arguments.length;u++){r=Object(arguments[u]);for(var h in r)o.call(r,h)&&(a[h]=r[h]);if(Object.getOwnPropertySymbols){i=Object.getOwnPropertySymbols(r);for(var l=0;l<i.length;l++)s.call(r,i[l])&&(a[i[l]]=r[i[l]])}}return a}},{}],6:[function(t,e,r){var n=new ArrayBuffer(0),i=function(t,e,r,i){this.gl=t,this.buffer=t.createBuffer(),this.type=e||t.ARRAY_BUFFER,this.drawType=i||t.STATIC_DRAW,this.data=n,r&&this.upload(r)};i.prototype.upload=function(t,e,r){r||this.bind();var n=this.gl;t=t||this.data,e=e||0,this.data.byteLength>=t.byteLength?n.bufferSubData(this.type,e,t):n.bufferData(this.type,t,this.drawType),this.data=t},i.prototype.bind=function(){var t=this.gl;t.bindBuffer(this.type,this.buffer)},i.createVertexBuffer=function(t,e,r){return new i(t,t.ARRAY_BUFFER,e,r)},i.createIndexBuffer=function(t,e,r){return new i(t,t.ELEMENT_ARRAY_BUFFER,e,r)},i.create=function(t,e,r,n){return new i(t,e,r,n)},i.prototype.destroy=function(){this.gl.deleteBuffer(this.buffer)},e.exports=i},{}],7:[function(t,e,r){var n=t("./GLTexture"),i=function(t,e,r){this.gl=t,this.framebuffer=t.createFramebuffer(),this.stencil=null,this.texture=null,this.width=e||100,this.height=r||100};i.prototype.enableTexture=function(t){var e=this.gl;this.texture=t||new n(e),this.texture.bind(),this.bind(),e.framebufferTexture2D(e.FRAMEBUFFER,e.COLOR_ATTACHMENT0,e.TEXTURE_2D,this.texture.texture,0)},i.prototype.enableStencil=function(){if(!this.stencil){var t=this.gl;this.stencil=t.createRenderbuffer(),t.bindRenderbuffer(t.RENDERBUFFER,this.stencil),t.framebufferRenderbuffer(t.FRAMEBUFFER,t.DEPTH_STENCIL_ATTACHMENT,t.RENDERBUFFER,this.stencil),t.renderbufferStorage(t.RENDERBUFFER,t.DEPTH_STENCIL,this.width,this.height)}},i.prototype.clear=function(t,e,r,n){this.bind();var i=this.gl;i.clearColor(t,e,r,n),i.clear(i.COLOR_BUFFER_BIT)},i.prototype.bind=function(){var t=this.gl;t.bindFramebuffer(t.FRAMEBUFFER,this.framebuffer)},i.prototype.unbind=function(){var t=this.gl;t.bindFramebuffer(t.FRAMEBUFFER,null)},i.prototype.resize=function(t,e){var r=this.gl;this.width=t,this.height=e,this.texture&&this.texture.uploadData(null,t,e),this.stencil&&(r.bindRenderbuffer(r.RENDERBUFFER,this.stencil),r.renderbufferStorage(r.RENDERBUFFER,r.DEPTH_STENCIL,t,e))},i.prototype.destroy=function(){var t=this.gl;this.texture&&this.texture.destroy(),t.deleteFramebuffer(this.framebuffer),this.gl=null,this.stencil=null,this.texture=null},i.createRGBA=function(t,e,r,o){var s=n.fromData(t,null,e,r);s.enableNearestScaling(),s.enableWrapClamp();var a=new i(t,e,r);return a.enableTexture(s),a.unbind(),a},i.createFloat32=function(t,e,r,o){var s=new n.fromData(t,o,e,r);s.enableNearestScaling(),s.enableWrapClamp();var a=new i(t,e,r);return a.enableTexture(s),a.unbind(),a},e.exports=i},{"./GLTexture":9}],8:[function(t,e,r){var n=t("./shader/compileProgram"),i=t("./shader/extractAttributes"),o=t("./shader/extractUniforms"),s=t("./shader/generateUniformAccessObject"),a=function(t,e,r){this.gl=t,this.program=n(t,e,r),this.attributes=i(t,this.program);var a=o(t,this.program);this.uniforms=s(t,a)};a.prototype.bind=function(){this.gl.useProgram(this.program)},a.prototype.destroy=function(){},e.exports=a},{"./shader/compileProgram":14,"./shader/extractAttributes":16,"./shader/extractUniforms":17,"./shader/generateUniformAccessObject":18}],9:[function(t,e,r){var n=function(t,e,r,n,i){this.gl=t,this.texture=t.createTexture(),this.mipmap=!1,this.premultiplyAlpha=!1,this.width=e||-1,this.height=r||-1,this.format=n||t.RGBA,this.type=i||t.UNSIGNED_BYTE};n.prototype.upload=function(t){this.bind();var e=this.gl;e.pixelStorei(e.UNPACK_PREMULTIPLY_ALPHA_WEBGL,this.premultiplyAlpha);var r=t.videoWidth||t.width,n=t.videoHeight||t.height;n!==this.height||r!==this.width?e.texImage2D(e.TEXTURE_2D,0,this.format,this.format,this.type,t):e.texSubImage2D(e.TEXTURE_2D,0,0,0,this.format,this.type,t),this.width=r,this.height=n};var i=!1;n.prototype.uploadData=function(t,e,r){this.bind();var n=this.gl;if(t instanceof Float32Array){if(!i){var o=n.getExtension("OES_texture_float");if(!o)throw new Error("floating point textures not available");i=!0}this.type=n.FLOAT}else this.type=n.UNSIGNED_BYTE;n.pixelStorei(n.UNPACK_PREMULTIPLY_ALPHA_WEBGL,this.premultiplyAlpha),e!==this.width||r!==this.height?n.texImage2D(n.TEXTURE_2D,0,this.format,e,r,0,this.format,this.type,t||null):n.texSubImage2D(n.TEXTURE_2D,0,0,0,e,r,this.format,this.type,t||null),this.width=e,this.height=r},n.prototype.bind=function(t){var e=this.gl;void 0!==t&&e.activeTexture(e.TEXTURE0+t),e.bindTexture(e.TEXTURE_2D,this.texture)},n.prototype.unbind=function(){var t=this.gl;t.bindTexture(t.TEXTURE_2D,null)},n.prototype.minFilter=function(t){var e=this.gl;this.bind(),this.mipmap?e.texParameteri(e.TEXTURE_2D,e.TEXTURE_MIN_FILTER,t?e.LINEAR_MIPMAP_LINEAR:e.NEAREST_MIPMAP_NEAREST):e.texParameteri(e.TEXTURE_2D,e.TEXTURE_MIN_FILTER,t?e.LINEAR:e.NEAREST)},n.prototype.magFilter=function(t){var e=this.gl;this.bind(),e.texParameteri(e.TEXTURE_2D,e.TEXTURE_MAG_FILTER,t?e.LINEAR:e.NEAREST)},n.prototype.enableMipmap=function(){var t=this.gl;this.bind(),this.mipmap=!0,t.generateMipmap(t.TEXTURE_2D)},n.prototype.enableLinearScaling=function(){this.minFilter(!0),this.magFilter(!0)},n.prototype.enableNearestScaling=function(){this.minFilter(!1),this.magFilter(!1)},n.prototype.enableWrapClamp=function(){var t=this.gl;this.bind(),t.texParameteri(t.TEXTURE_2D,t.TEXTURE_WRAP_S,t.CLAMP_TO_EDGE),t.texParameteri(t.TEXTURE_2D,t.TEXTURE_WRAP_T,t.CLAMP_TO_EDGE)},n.prototype.enableWrapRepeat=function(){var t=this.gl;this.bind(),t.texParameteri(t.TEXTURE_2D,t.TEXTURE_WRAP_S,t.REPEAT),t.texParameteri(t.TEXTURE_2D,t.TEXTURE_WRAP_T,t.REPEAT)},n.prototype.enableWrapMirrorRepeat=function(){var t=this.gl;this.bind(),t.texParameteri(t.TEXTURE_2D,t.TEXTURE_WRAP_S,t.MIRRORED_REPEAT),t.texParameteri(t.TEXTURE_2D,t.TEXTURE_WRAP_T,t.MIRRORED_REPEAT)},n.prototype.destroy=function(){var t=this.gl;t.deleteTexture(this.texture)},n.fromSource=function(t,e,r){var i=new n(t);return i.premultiplyAlpha=r||!1,i.upload(e),i},n.fromData=function(t,e,r,i){var o=new n(t);return o.uploadData(e,r,i),o},e.exports=n},{}],10:[function(t,e,r){function n(t,e){if(this.nativeVaoExtension=null,n.FORCE_NATIVE||(this.nativeVaoExtension=t.getExtension("OES_vertex_array_object")||t.getExtension("MOZ_OES_vertex_array_object")||t.getExtension("WEBKIT_OES_vertex_array_object")),this.nativeState=e,this.nativeVaoExtension){this.nativeVao=this.nativeVaoExtension.createVertexArrayOES();var r=t.getParameter(t.MAX_VERTEX_ATTRIBS);this.nativeState={tempAttribState:new Array(r),attribState:new Array(r)}}this.gl=t,this.attributes=[],this.indexBuffer=null,this.dirty=!1}var i=t("./setVertexAttribArrays");n.prototype.constructor=n,e.exports=n,n.FORCE_NATIVE=!1,n.prototype.bind=function(){return this.nativeVao?(this.nativeVaoExtension.bindVertexArrayOES(this.nativeVao),this.dirty&&(this.dirty=!1,this.activate())):this.activate(),this},n.prototype.unbind=function(){return this.nativeVao&&this.nativeVaoExtension.bindVertexArrayOES(null),this},n.prototype.activate=function(){for(var t=this.gl,e=null,r=0;r<this.attributes.length;r++){var n=this.attributes[r];e!==n.buffer&&(n.buffer.bind(),e=n.buffer),t.vertexAttribPointer(n.attribute.location,n.attribute.size,n.type||t.FLOAT,n.normalized||!1,n.stride||0,n.start||0)}return i(t,this.attributes,this.nativeState),this.indexBuffer.bind(),this},n.prototype.addAttribute=function(t,e,r,n,i,o){return this.attributes.push({buffer:t,attribute:e,location:e.location,type:r||this.gl.FLOAT,normalized:n||!1,stride:i||0,start:o||0}),this.dirty=!0,this},n.prototype.addIndex=function(t){return this.indexBuffer=t,this.dirty=!0,this},n.prototype.clear=function(){return this.nativeVao&&this.nativeVaoExtension.bindVertexArrayOES(this.nativeVao),this.attributes.length=0,this.indexBuffer=null,this},n.prototype.draw=function(t,e,r){var n=this.gl;return n.drawElements(t,e,n.UNSIGNED_SHORT,r||0),this},n.prototype.destroy=function(){this.gl=null,this.indexBuffer=null,this.attributes=null,this.nativeState=null,this.nativeVao&&this.nativeVaoExtension.deleteVertexArrayOES(this.nativeVao),this.nativeVaoExtension=null,this.nativeVao=null}},{"./setVertexAttribArrays":13}],11:[function(t,e,r){var n=function(t,e){var r=t.getContext("webgl",e)||t.getContext("experimental-webgl",e);if(!r)throw new Error("This browser does not support webGL. Try using the canvas renderer");return r};e.exports=n},{}],12:[function(t,e,r){var n={createContext:t("./createContext"),setVertexAttribArrays:t("./setVertexAttribArrays"),GLBuffer:t("./GLBuffer"),GLFramebuffer:t("./GLFramebuffer"),GLShader:t("./GLShader"),GLTexture:t("./GLTexture"),VertexArrayObject:t("./VertexArrayObject"),shader:t("./shader")};"undefined"!=typeof e&&e.exports&&(e.exports=n),"undefined"!=typeof window&&(window.PIXI=window.PIXI||{},window.PIXI.glCore=n)},{"./GLBuffer":6,"./GLFramebuffer":7,"./GLShader":8,"./GLTexture":9,"./VertexArrayObject":10,"./createContext":11,"./setVertexAttribArrays":13,"./shader":19}],13:[function(t,e,r){var n=function(t,e,r){var n;if(r){var i=r.tempAttribState,o=r.attribState;for(n=0;n<i.length;n++)i[n]=!1;for(n=0;n<e.length;n++)i[e[n].attribute.location]=!0;for(n=0;n<o.length;n++)o[n]!==i[n]&&(o[n]=i[n],r.attribState[n]?t.enableVertexAttribArray(n):t.disableVertexAttribArray(n))}else for(n=0;n<e.length;n++){var s=e[n];t.enableVertexAttribArray(s.attribute.location)}};e.exports=n},{}],14:[function(t,e,r){var n=function(t,e,r){var n=i(t,t.VERTEX_SHADER,e),o=i(t,t.FRAGMENT_SHADER,r),s=t.createProgram();return t.attachShader(s,n),t.attachShader(s,o),t.linkProgram(s),t.getProgramParameter(s,t.LINK_STATUS)||(console.error("Pixi.js Error: Could not initialize shader."),console.error("gl.VALIDATE_STATUS",t.getProgramParameter(s,t.VALIDATE_STATUS)),console.error("gl.getError()",t.getError()),""!==t.getProgramInfoLog(s)&&console.warn("Pixi.js Warning: gl.getProgramInfoLog()",t.getProgramInfoLog(s)),t.deleteProgram(s),s=null),t.deleteShader(n),t.deleteShader(o),s},i=function(t,e,r){var n=t.createShader(e);return t.shaderSource(n,r),t.compileShader(n),t.getShaderParameter(n,t.COMPILE_STATUS)?n:(console.log(t.getShaderInfoLog(n)),null)};e.exports=n},{}],15:[function(t,e,r){var n=function(t,e){switch(t){case"float":return 0;case"vec2":return new Float32Array(2*e);case"vec3":return new Float32Array(3*e);case"vec4":return new Float32Array(4*e);case"int":case"sampler2D":return 0;case"ivec2":return new Int32Array(2*e);case"ivec3":return new Int32Array(3*e);case"ivec4":return new Int32Array(4*e);case"bool":return!1;case"bvec2":return i(2*e);case"bvec3":return i(3*e);case"bvec4":return i(4*e);case"mat2":return new Float32Array([1,0,0,1]);case"mat3":return new Float32Array([1,0,0,0,1,0,0,0,1]);case"mat4":return new Float32Array([1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1])}},i=function(t){for(var e=new Array(t),r=0;r<e.length;r++)e[r]=!1;return e};e.exports=n},{}],16:[function(t,e,r){var n=t("./mapType"),i=t("./mapSize"),o=function(t,e){for(var r={},o=t.getProgramParameter(e,t.ACTIVE_ATTRIBUTES),a=0;a<o;a++){var u=t.getActiveAttrib(e,a),h=n(t,u.type);r[u.name]={type:h,size:i(h),location:t.getAttribLocation(e,u.name),pointer:s}}return r},s=function(t,e,r,n){gl.vertexAttribPointer(this.location,this.size,t||gl.FLOAT,e||!1,r||0,n||0)};e.exports=o},{"./mapSize":20,"./mapType":21}],17:[function(t,e,r){var n=t("./mapType"),i=t("./defaultValue"),o=function(t,e){for(var r={},o=t.getProgramParameter(e,t.ACTIVE_UNIFORMS),s=0;s<o;s++){var a=t.getActiveUniform(e,s),u=a.name.replace(/\[.*?\]/,""),h=n(t,a.type);r[u]={type:h,size:a.size,location:t.getUniformLocation(e,u),value:i(h,a.size)}}return r};e.exports=o},{"./defaultValue":15,"./mapType":21}],18:[function(t,e,r){var n=function(t,e){var r={data:{}};r.gl=t;for(var n=Object.keys(e),a=0;a<n.length;a++){var u=n[a],h=u.split("."),l=h[h.length-1],c=s(h,r),d=e[u];c.data[l]=d,c.gl=t,Object.defineProperty(c,l,{get:i(l),set:o(l,d)})}return r},i=function(t){var e=a.replace("%%",t);return new Function(e)},o=function(t,e){var r,n=u.replace(/%%/g,t);return r=1===e.size?h[e.type]:l[e.type],r&&(n+="\nthis.gl."+r+";"),new Function("value",n)},s=function(t,e){for(var r=e,n=0;n<t.length-1;n++){var i=r[t[n]]||{data:{}};r[t[n]]=i,r=i}return r},a=["return this.data.%%.value;"].join("\n"),u=["this.data.%%.value = value;","var location = this.data.%%.location;"].join("\n"),h={float:"uniform1f(location, value)",vec2:"uniform2f(location, value[0], value[1])",vec3:"uniform3f(location, value[0], value[1], value[2])",vec4:"uniform4f(location, value[0], value[1], value[2], value[3])",int:"uniform1i(location, value)",ivec2:"uniform2i(location, value[0], value[1])",ivec3:"uniform3i(location, value[0], value[1], value[2])",ivec4:"uniform4i(location, value[0], value[1], value[2], value[3])",bool:"uniform1i(location, value)",bvec2:"uniform2i(location, value[0], value[1])",bvec3:"uniform3i(location, value[0], value[1], value[2])",bvec4:"uniform4i(location, value[0], value[1], value[2], value[3])",mat2:"uniformMatrix2fv(location, false, value)",mat3:"uniformMatrix3fv(location, false, value)",mat4:"uniformMatrix4fv(location, false, value)",sampler2D:"uniform1i(location, value)"},l={float:"uniform1fv(location, value)",vec2:"uniform2fv(location, value)",vec3:"uniform3fv(location, value)",vec4:"uniform4fv(location, value)",int:"uniform1iv(location, value)",ivec2:"uniform2iv(location, value)",ivec3:"uniform3iv(location, value)",ivec4:"uniform4iv(location, value)",bool:"uniform1iv(location, value)",bvec2:"uniform2iv(location, value)",bvec3:"uniform3iv(location, value)",bvec4:"uniform4iv(location, value)",sampler2D:"uniform1iv(location, value)"};e.exports=n},{}],19:[function(t,e,r){e.exports={compileProgram:t("./compileProgram"),defaultValue:t("./defaultValue"),extractAttributes:t("./extractAttributes"),extractUniforms:t("./extractUniforms"),generateUniformAccessObject:t("./generateUniformAccessObject"),mapSize:t("./mapSize"),mapType:t("./mapType")}},{"./compileProgram":14,"./defaultValue":15,"./extractAttributes":16,"./extractUniforms":17,"./generateUniformAccessObject":18,"./mapSize":20,"./mapType":21}],20:[function(t,e,r){var n=function(t){return i[t]},i={float:1,vec2:2,vec3:3,vec4:4,int:1,ivec2:2,ivec3:3,ivec4:4,bool:1,bvec2:2,bvec3:3,bvec4:4,mat2:4,mat3:9,mat4:16,sampler2D:1};e.exports=n},{}],21:[function(t,e,r){var n=function(t,e){if(!i){var r=Object.keys(o);i={};for(var n=0;n<r.length;++n){var s=r[n];i[t[s]]=o[s]}}return i[e]},i=null,o={FLOAT:"float",FLOAT_VEC2:"vec2",FLOAT_VEC3:"vec3",FLOAT_VEC4:"vec4",INT:"int",INT_VEC2:"ivec2",INT_VEC3:"ivec3",INT_VEC4:"ivec4",BOOL:"bool",BOOL_VEC2:"bvec2",BOOL_VEC3:"bvec3",BOOL_VEC4:"bvec4",FLOAT_MAT2:"mat2",FLOAT_MAT3:"mat3",FLOAT_MAT4:"mat4",SAMPLER_2D:"sampler2D"};e.exports=n},{}],22:[function(t,e,r){(function(t){function e(t,e){for(var r=0,n=t.length-1;n>=0;n--){var i=t[n];"."===i?t.splice(n,1):".."===i?(t.splice(n,1),r++):r&&(t.splice(n,1),r--)}if(e)for(;r--;r)t.unshift("..");return t}function n(t,e){if(t.filter)return t.filter(e);for(var r=[],n=0;n<t.length;n++)e(t[n],n,t)&&r.push(t[n]);return r}var i=/^(\/?|)([\s\S]*?)((?:\.{1,2}|[^\/]+?|)(\.[^.\/]*|))(?:[\/]*)$/,o=function(t){return i.exec(t).slice(1)};r.resolve=function(){for(var r="",i=!1,o=arguments.length-1;o>=-1&&!i;o--){var s=o>=0?arguments[o]:t.cwd();if("string"!=typeof s)throw new TypeError("Arguments to path.resolve must be strings");s&&(r=s+"/"+r,i="/"===s.charAt(0))}return r=e(n(r.split("/"),function(t){return!!t}),!i).join("/"),(i?"/":"")+r||"."},r.normalize=function(t){var i=r.isAbsolute(t),o="/"===s(t,-1);return t=e(n(t.split("/"),function(t){return!!t}),!i).join("/"),t||i||(t="."),t&&o&&(t+="/"),(i?"/":"")+t},r.isAbsolute=function(t){return"/"===t.charAt(0)},r.join=function(){var t=Array.prototype.slice.call(arguments,0);return r.normalize(n(t,function(t,e){if("string"!=typeof t)throw new TypeError("Arguments to path.join must be strings");return t}).join("/"))},r.relative=function(t,e){function n(t){for(var e=0;e<t.length&&""===t[e];e++);for(var r=t.length-1;r>=0&&""===t[r];r--);return e>r?[]:t.slice(e,r-e+1)}t=r.resolve(t).substr(1),e=r.resolve(e).substr(1);for(var i=n(t.split("/")),o=n(e.split("/")),s=Math.min(i.length,o.length),a=s,u=0;u<s;u++)if(i[u]!==o[u]){a=u;break}for(var h=[],u=a;u<i.length;u++)h.push("..");return h=h.concat(o.slice(a)),h.join("/")},r.sep="/",r.delimiter=":",r.dirname=function(t){var e=o(t),r=e[0],n=e[1];return r||n?(n&&(n=n.substr(0,n.length-1)),r+n):"."},r.basename=function(t,e){var r=o(t)[2];return e&&r.substr(-1*e.length)===e&&(r=r.substr(0,r.length-e.length)),r},r.extname=function(t){return o(t)[3]};var s="b"==="ab".substr(-1)?function(t,e,r){return t.substr(e,r)}:function(t,e,r){return e<0&&(e=t.length+e),t.substr(e,r)}}).call(this,t("_process"))},{_process:23}],23:[function(t,e,r){function n(){throw new Error("setTimeout has not been defined")}function i(){throw new Error("clearTimeout has not been defined")}function o(t){if(c===setTimeout)return setTimeout(t,0);if((c===n||!c)&&setTimeout)return c=setTimeout,setTimeout(t,0);try{return c(t,0)}catch(e){try{return c.call(null,t,0)}catch(e){return c.call(this,t,0)}}}function s(t){if(d===clearTimeout)return clearTimeout(t);if((d===i||!d)&&clearTimeout)return d=clearTimeout,clearTimeout(t);try{return d(t)}catch(e){try{return d.call(null,t)}catch(e){return d.call(this,t)}}}function a(){y&&p&&(y=!1,p.length?v=p.concat(v):g=-1,v.length&&u())}function u(){if(!y){var t=o(a);y=!0;for(var e=v.length;e;){for(p=v,v=[];++g<e;)p&&p[g].run();g=-1,e=v.length}p=null,y=!1,s(t)}}function h(t,e){this.fun=t,this.array=e}function l(){}var c,d,f=e.exports={};!function(){try{c="function"==typeof setTimeout?setTimeout:n}catch(t){c=n}try{d="function"==typeof clearTimeout?clearTimeout:i;
}catch(t){d=i}}();var p,v=[],y=!1,g=-1;f.nextTick=function(t){var e=new Array(arguments.length-1);if(arguments.length>1)for(var r=1;r<arguments.length;r++)e[r-1]=arguments[r];v.push(new h(t,e)),1!==v.length||y||o(u)},h.prototype.run=function(){this.fun.apply(null,this.array)},f.title="browser",f.browser=!0,f.env={},f.argv=[],f.version="",f.versions={},f.on=l,f.addListener=l,f.once=l,f.off=l,f.removeListener=l,f.removeAllListeners=l,f.emit=l,f.binding=function(t){throw new Error("process.binding is not supported")},f.cwd=function(){return"/"},f.chdir=function(t){throw new Error("process.chdir is not supported")},f.umask=function(){return 0}},{}],24:[function(e,r,n){(function(e){!function(i){function o(t){throw new RangeError(L[t])}function s(t,e){for(var r=t.length,n=[];r--;)n[r]=e(t[r]);return n}function a(t,e){var r=t.split("@"),n="";r.length>1&&(n=r[0]+"@",t=r[1]),t=t.replace(I,".");var i=t.split("."),o=s(i,e).join(".");return n+o}function u(t){for(var e,r,n=[],i=0,o=t.length;i<o;)e=t.charCodeAt(i++),e>=55296&&e<=56319&&i<o?(r=t.charCodeAt(i++),56320==(64512&r)?n.push(((1023&e)<<10)+(1023&r)+65536):(n.push(e),i--)):n.push(e);return n}function h(t){return s(t,function(t){var e="";return t>65535&&(t-=65536,e+=F(t>>>10&1023|55296),t=56320|1023&t),e+=F(t)}).join("")}function l(t){return t-48<10?t-22:t-65<26?t-65:t-97<26?t-97:w}function c(t,e){return t+22+75*(t<26)-((0!=e)<<5)}function d(t,e,r){var n=0;for(t=r?B(t/M):t>>1,t+=B(t/e);t>j*O>>1;n+=w)t=B(t/j);return B(n+(j+1)*t/(t+S))}function f(t){var e,r,n,i,s,a,u,c,f,p,v=[],y=t.length,g=0,m=C,_=P;for(r=t.lastIndexOf(R),r<0&&(r=0),n=0;n<r;++n)t.charCodeAt(n)>=128&&o("not-basic"),v.push(t.charCodeAt(n));for(i=r>0?r+1:0;i<y;){for(s=g,a=1,u=w;i>=y&&o("invalid-input"),c=l(t.charCodeAt(i++)),(c>=w||c>B((T-g)/a))&&o("overflow"),g+=c*a,f=u<=_?E:u>=_+O?O:u-_,!(c<f);u+=w)p=w-f,a>B(T/p)&&o("overflow"),a*=p;e=v.length+1,_=d(g-s,e,0==s),B(g/e)>T-m&&o("overflow"),m+=B(g/e),g%=e,v.splice(g++,0,m)}return h(v)}function p(t){var e,r,n,i,s,a,h,l,f,p,v,y,g,m,_,b=[];for(t=u(t),y=t.length,e=C,r=0,s=P,a=0;a<y;++a)v=t[a],v<128&&b.push(F(v));for(n=i=b.length,i&&b.push(R);n<y;){for(h=T,a=0;a<y;++a)v=t[a],v>=e&&v<h&&(h=v);for(g=n+1,h-e>B((T-r)/g)&&o("overflow"),r+=(h-e)*g,e=h,a=0;a<y;++a)if(v=t[a],v<e&&++r>T&&o("overflow"),v==e){for(l=r,f=w;p=f<=s?E:f>=s+O?O:f-s,!(l<p);f+=w)_=l-p,m=w-p,b.push(F(c(p+_%m,0))),l=B(_/m);b.push(F(c(l,0))),s=d(r,g,n==i),r=0,++n}++r,++e}return b.join("")}function v(t){return a(t,function(t){return D.test(t)?f(t.slice(4).toLowerCase()):t})}function y(t){return a(t,function(t){return A.test(t)?"xn--"+p(t):t})}var g="object"==typeof n&&n&&!n.nodeType&&n,m="object"==typeof r&&r&&!r.nodeType&&r,_="object"==typeof e&&e;_.global!==_&&_.window!==_&&_.self!==_||(i=_);var b,x,T=2147483647,w=36,E=1,O=26,S=38,M=700,P=72,C=128,R="-",D=/^xn--/,A=/[^\x20-\x7E]/,I=/[\x2E\u3002\uFF0E\uFF61]/g,L={overflow:"Overflow: input needs wider integers to process","not-basic":"Illegal input >= 0x80 (not a basic code point)","invalid-input":"Invalid input"},j=w-E,B=Math.floor,F=String.fromCharCode;if(b={version:"1.4.1",ucs2:{decode:u,encode:h},decode:f,encode:p,toASCII:y,toUnicode:v},"function"==typeof t&&"object"==typeof t.amd&&t.amd)t("punycode",function(){return b});else if(g&&m)if(r.exports==g)m.exports=b;else for(x in b)b.hasOwnProperty(x)&&(g[x]=b[x]);else i.punycode=b}(this)}).call(this,"undefined"!=typeof global?global:"undefined"!=typeof self?self:"undefined"!=typeof window?window:{})},{}],25:[function(t,e,r){"use strict";function n(t,e){return Object.prototype.hasOwnProperty.call(t,e)}e.exports=function(t,e,r,o){e=e||"&",r=r||"=";var s={};if("string"!=typeof t||0===t.length)return s;var a=/\+/g;t=t.split(e);var u=1e3;o&&"number"==typeof o.maxKeys&&(u=o.maxKeys);var h=t.length;u>0&&h>u&&(h=u);for(var l=0;l<h;++l){var c,d,f,p,v=t[l].replace(a,"%20"),y=v.indexOf(r);y>=0?(c=v.substr(0,y),d=v.substr(y+1)):(c=v,d=""),f=decodeURIComponent(c),p=decodeURIComponent(d),n(s,f)?i(s[f])?s[f].push(p):s[f]=[s[f],p]:s[f]=p}return s};var i=Array.isArray||function(t){return"[object Array]"===Object.prototype.toString.call(t)}},{}],26:[function(t,e,r){"use strict";function n(t,e){if(t.map)return t.map(e);for(var r=[],n=0;n<t.length;n++)r.push(e(t[n],n));return r}var i=function(t){switch(typeof t){case"string":return t;case"boolean":return t?"true":"false";case"number":return isFinite(t)?t:"";default:return""}};e.exports=function(t,e,r,a){return e=e||"&",r=r||"=",null===t&&(t=void 0),"object"==typeof t?n(s(t),function(s){var a=encodeURIComponent(i(s))+r;return o(t[s])?n(t[s],function(t){return a+encodeURIComponent(i(t))}).join(e):a+encodeURIComponent(i(t[s]))}).join(e):a?encodeURIComponent(i(a))+r+encodeURIComponent(i(t)):""};var o=Array.isArray||function(t){return"[object Array]"===Object.prototype.toString.call(t)},s=Object.keys||function(t){var e=[];for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&e.push(r);return e}},{}],27:[function(t,e,r){"use strict";r.decode=r.parse=t("./decode"),r.encode=r.stringify=t("./encode")},{"./decode":25,"./encode":26}],28:[function(t,e,r){"use strict";function n(){this.protocol=null,this.slashes=null,this.auth=null,this.host=null,this.port=null,this.hostname=null,this.hash=null,this.search=null,this.query=null,this.pathname=null,this.path=null,this.href=null}function i(t,e,r){if(t&&h.isObject(t)&&t instanceof n)return t;var i=new n;return i.parse(t,e,r),i}function o(t){return h.isString(t)&&(t=i(t)),t instanceof n?t.format():n.prototype.format.call(t)}function s(t,e){return i(t,!1,!0).resolve(e)}function a(t,e){return t?i(t,!1,!0).resolveObject(e):e}var u=t("punycode"),h=t("./util");r.parse=i,r.resolve=s,r.resolveObject=a,r.format=o,r.Url=n;var l=/^([a-z0-9.+-]+:)/i,c=/:[0-9]*$/,d=/^(\/\/?(?!\/)[^\?\s]*)(\?[^\s]*)?$/,f=["<",">",'"',"`"," ","\r","\n","\t"],p=["{","}","|","\\","^","`"].concat(f),v=["'"].concat(p),y=["%","/","?",";","#"].concat(v),g=["/","?","#"],m=255,_=/^[+a-z0-9A-Z_-]{0,63}$/,b=/^([+a-z0-9A-Z_-]{0,63})(.*)$/,x={javascript:!0,"javascript:":!0},T={javascript:!0,"javascript:":!0},w={http:!0,https:!0,ftp:!0,gopher:!0,file:!0,"http:":!0,"https:":!0,"ftp:":!0,"gopher:":!0,"file:":!0},E=t("querystring");n.prototype.parse=function(t,e,r){if(!h.isString(t))throw new TypeError("Parameter 'url' must be a string, not "+typeof t);var n=t.indexOf("?"),i=n!==-1&&n<t.indexOf("#")?"?":"#",o=t.split(i),s=/\\/g;o[0]=o[0].replace(s,"/"),t=o.join(i);var a=t;if(a=a.trim(),!r&&1===t.split("#").length){var c=d.exec(a);if(c)return this.path=a,this.href=a,this.pathname=c[1],c[2]?(this.search=c[2],e?this.query=E.parse(this.search.substr(1)):this.query=this.search.substr(1)):e&&(this.search="",this.query={}),this}var f=l.exec(a);if(f){f=f[0];var p=f.toLowerCase();this.protocol=p,a=a.substr(f.length)}if(r||f||a.match(/^\/\/[^@\/]+@[^@\/]+/)){var O="//"===a.substr(0,2);!O||f&&T[f]||(a=a.substr(2),this.slashes=!0)}if(!T[f]&&(O||f&&!w[f])){for(var S=-1,M=0;M<g.length;M++){var P=a.indexOf(g[M]);P!==-1&&(S===-1||P<S)&&(S=P)}var C,R;R=S===-1?a.lastIndexOf("@"):a.lastIndexOf("@",S),R!==-1&&(C=a.slice(0,R),a=a.slice(R+1),this.auth=decodeURIComponent(C)),S=-1;for(var M=0;M<y.length;M++){var P=a.indexOf(y[M]);P!==-1&&(S===-1||P<S)&&(S=P)}S===-1&&(S=a.length),this.host=a.slice(0,S),a=a.slice(S),this.parseHost(),this.hostname=this.hostname||"";var D="["===this.hostname[0]&&"]"===this.hostname[this.hostname.length-1];if(!D)for(var A=this.hostname.split(/\./),M=0,I=A.length;M<I;M++){var L=A[M];if(L&&!L.match(_)){for(var j="",B=0,F=L.length;B<F;B++)j+=L.charCodeAt(B)>127?"x":L[B];if(!j.match(_)){var N=A.slice(0,M),k=A.slice(M+1),U=L.match(b);U&&(N.push(U[1]),k.unshift(U[2])),k.length&&(a="/"+k.join(".")+a),this.hostname=N.join(".");break}}}this.hostname.length>m?this.hostname="":this.hostname=this.hostname.toLowerCase(),D||(this.hostname=u.toASCII(this.hostname));var X=this.port?":"+this.port:"",W=this.hostname||"";this.host=W+X,this.href+=this.host,D&&(this.hostname=this.hostname.substr(1,this.hostname.length-2),"/"!==a[0]&&(a="/"+a))}if(!x[p])for(var M=0,I=v.length;M<I;M++){var G=v[M];if(a.indexOf(G)!==-1){var H=encodeURIComponent(G);H===G&&(H=escape(G)),a=a.split(G).join(H)}}var V=a.indexOf("#");V!==-1&&(this.hash=a.substr(V),a=a.slice(0,V));var Y=a.indexOf("?");if(Y!==-1?(this.search=a.substr(Y),this.query=a.substr(Y+1),e&&(this.query=E.parse(this.query)),a=a.slice(0,Y)):e&&(this.search="",this.query={}),a&&(this.pathname=a),w[p]&&this.hostname&&!this.pathname&&(this.pathname="/"),this.pathname||this.search){var X=this.pathname||"",z=this.search||"";this.path=X+z}return this.href=this.format(),this},n.prototype.format=function(){var t=this.auth||"";t&&(t=encodeURIComponent(t),t=t.replace(/%3A/i,":"),t+="@");var e=this.protocol||"",r=this.pathname||"",n=this.hash||"",i=!1,o="";this.host?i=t+this.host:this.hostname&&(i=t+(this.hostname.indexOf(":")===-1?this.hostname:"["+this.hostname+"]"),this.port&&(i+=":"+this.port)),this.query&&h.isObject(this.query)&&Object.keys(this.query).length&&(o=E.stringify(this.query));var s=this.search||o&&"?"+o||"";return e&&":"!==e.substr(-1)&&(e+=":"),this.slashes||(!e||w[e])&&i!==!1?(i="//"+(i||""),r&&"/"!==r.charAt(0)&&(r="/"+r)):i||(i=""),n&&"#"!==n.charAt(0)&&(n="#"+n),s&&"?"!==s.charAt(0)&&(s="?"+s),r=r.replace(/[?#]/g,function(t){return encodeURIComponent(t)}),s=s.replace("#","%23"),e+i+r+s+n},n.prototype.resolve=function(t){return this.resolveObject(i(t,!1,!0)).format()},n.prototype.resolveObject=function(t){if(h.isString(t)){var e=new n;e.parse(t,!1,!0),t=e}for(var r=new n,i=Object.keys(this),o=0;o<i.length;o++){var s=i[o];r[s]=this[s]}if(r.hash=t.hash,""===t.href)return r.href=r.format(),r;if(t.slashes&&!t.protocol){for(var a=Object.keys(t),u=0;u<a.length;u++){var l=a[u];"protocol"!==l&&(r[l]=t[l])}return w[r.protocol]&&r.hostname&&!r.pathname&&(r.path=r.pathname="/"),r.href=r.format(),r}if(t.protocol&&t.protocol!==r.protocol){if(!w[t.protocol]){for(var c=Object.keys(t),d=0;d<c.length;d++){var f=c[d];r[f]=t[f]}return r.href=r.format(),r}if(r.protocol=t.protocol,t.host||T[t.protocol])r.pathname=t.pathname;else{for(var p=(t.pathname||"").split("/");p.length&&!(t.host=p.shift()););t.host||(t.host=""),t.hostname||(t.hostname=""),""!==p[0]&&p.unshift(""),p.length<2&&p.unshift(""),r.pathname=p.join("/")}if(r.search=t.search,r.query=t.query,r.host=t.host||"",r.auth=t.auth,r.hostname=t.hostname||t.host,r.port=t.port,r.pathname||r.search){var v=r.pathname||"",y=r.search||"";r.path=v+y}return r.slashes=r.slashes||t.slashes,r.href=r.format(),r}var g=r.pathname&&"/"===r.pathname.charAt(0),m=t.host||t.pathname&&"/"===t.pathname.charAt(0),_=m||g||r.host&&t.pathname,b=_,x=r.pathname&&r.pathname.split("/")||[],p=t.pathname&&t.pathname.split("/")||[],E=r.protocol&&!w[r.protocol];if(E&&(r.hostname="",r.port=null,r.host&&(""===x[0]?x[0]=r.host:x.unshift(r.host)),r.host="",t.protocol&&(t.hostname=null,t.port=null,t.host&&(""===p[0]?p[0]=t.host:p.unshift(t.host)),t.host=null),_=_&&(""===p[0]||""===x[0])),m)r.host=t.host||""===t.host?t.host:r.host,r.hostname=t.hostname||""===t.hostname?t.hostname:r.hostname,r.search=t.search,r.query=t.query,x=p;else if(p.length)x||(x=[]),x.pop(),x=x.concat(p),r.search=t.search,r.query=t.query;else if(!h.isNullOrUndefined(t.search)){if(E){r.hostname=r.host=x.shift();var O=!!(r.host&&r.host.indexOf("@")>0)&&r.host.split("@");O&&(r.auth=O.shift(),r.host=r.hostname=O.shift())}return r.search=t.search,r.query=t.query,h.isNull(r.pathname)&&h.isNull(r.search)||(r.path=(r.pathname?r.pathname:"")+(r.search?r.search:"")),r.href=r.format(),r}if(!x.length)return r.pathname=null,r.search?r.path="/"+r.search:r.path=null,r.href=r.format(),r;for(var S=x.slice(-1)[0],M=(r.host||t.host||x.length>1)&&("."===S||".."===S)||""===S,P=0,C=x.length;C>=0;C--)S=x[C],"."===S?x.splice(C,1):".."===S?(x.splice(C,1),P++):P&&(x.splice(C,1),P--);if(!_&&!b)for(;P--;P)x.unshift("..");!_||""===x[0]||x[0]&&"/"===x[0].charAt(0)||x.unshift(""),M&&"/"!==x.join("/").substr(-1)&&x.push("");var R=""===x[0]||x[0]&&"/"===x[0].charAt(0);if(E){r.hostname=r.host=R?"":x.length?x.shift():"";var O=!!(r.host&&r.host.indexOf("@")>0)&&r.host.split("@");O&&(r.auth=O.shift(),r.host=r.hostname=O.shift())}return _=_||r.host&&x.length,_&&!R&&x.unshift(""),x.length?r.pathname=x.join("/"):(r.pathname=null,r.path=null),h.isNull(r.pathname)&&h.isNull(r.search)||(r.path=(r.pathname?r.pathname:"")+(r.search?r.search:"")),r.auth=t.auth||r.auth,r.slashes=r.slashes||t.slashes,r.href=r.format(),r},n.prototype.parseHost=function(){var t=this.host,e=c.exec(t);e&&(e=e[0],":"!==e&&(this.port=e.substr(1)),t=t.substr(0,t.length-e.length)),t&&(this.hostname=t)}},{"./util":29,punycode:24,querystring:27}],29:[function(t,e,r){"use strict";e.exports={isString:function(t){return"string"==typeof t},isObject:function(t){return"object"==typeof t&&null!==t},isNull:function(t){return null===t},isNullOrUndefined:function(t){return null==t}}},{}],30:[function(t,e,r){"use strict";e.exports=function(t,e){e=e||{};for(var r={key:["source","protocol","authority","userInfo","user","password","host","port","relative","path","directory","file","query","anchor"],q:{name:"queryKey",parser:/(?:^|&)([^&=]*)=?([^&]*)/g},parser:{strict:/^(?:([^:\/?#]+):)?(?:\/\/((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?))?((((?:[^?#\/]*\/)*)([^?#]*))(?:\?([^#]*))?(?:#(.*))?)/,loose:/^(?:(?![^:@]+:[^:@\/]*@)([^:\/?#.]+):)?(?:\/\/)?((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?)(((\/(?:[^?#](?![^?#\/]*\.[^?#\/.]+(?:[?#]|$)))*\/?)?([^?#\/]*))(?:\?([^#]*))?(?:#(.*))?)/}},n=r.parser[e.strictMode?"strict":"loose"].exec(t),i={},o=14;o--;)i[r.key[o]]=n[o]||"";return i[r.q.name]={},i[r.key[12]].replace(r.q.parser,function(t,e,n){e&&(i[r.q.name][e]=n)}),i}},{}],31:[function(t,e,r){"use strict";function n(t,e){a.call(this),e=e||u,this.baseUrl=t||"",this.progress=0,this.loading=!1,this._progressChunk=0,this._beforeMiddleware=[],this._afterMiddleware=[],this._boundLoadResource=this._loadResource.bind(this),this._buffer=[],this._numToLoad=0,this._queue=o.queue(this._boundLoadResource,e),this.resources={}}var i=t("parse-uri"),o=t("./async"),s=t("./Resource"),a=t("eventemitter3"),u=10,h=100;n.prototype=Object.create(a.prototype),n.prototype.constructor=n,e.exports=n,n.prototype.add=n.prototype.enqueue=function(t,e,r,n){if(Array.isArray(t)){for(var i=0;i<t.length;++i)this.add(t[i]);return this}if("object"==typeof t&&(n=e||t.callback||t.onComplete,r=t,e=t.url,t=t.name||t.key||t.url),"string"!=typeof e&&(n=r,r=e,e=t),"string"!=typeof e)throw new Error("No url passed to add resource to loader.");if("function"==typeof r&&(n=r,r=null),this.resources[t])throw new Error('Resource with name "'+t+'" already exists.');return e=this._prepareUrl(e),this.resources[t]=new s(t,e,r),"function"==typeof n&&this.resources[t].once("afterMiddleware",n),this._numToLoad++,this._queue.started?(this._queue.push(this.resources[t]),this._progressChunk=(h-this.progress)/(this._queue.length()+this._queue.running())):(this._buffer.push(this.resources[t]),this._progressChunk=h/this._buffer.length),this},n.prototype.before=n.prototype.pre=function(t){return this._beforeMiddleware.push(t),this},n.prototype.after=n.prototype.use=function(t){return this._afterMiddleware.push(t),this},n.prototype.reset=function(){this.progress=0,this.loading=!1,this._progressChunk=0,this._buffer.length=0,this._numToLoad=0,this._queue.kill(),this._queue.started=!1;for(var t in this.resources){var e=this.resources[t];e.off("complete",this._onLoad,this),e.isLoading&&e.abort()}return this.resources={},this},n.prototype.load=function(t){if("function"==typeof t&&this.once("complete",t),this._queue.started)return this;this.emit("start",this),this.loading=!0;for(var e=0;e<this._buffer.length;++e)this._queue.push(this._buffer[e]);return this._buffer.length=0,this},n.prototype._prepareUrl=function(t){var e=i(t,{strictMode:!0});return e.protocol||!e.path||0===e.path.indexOf("//")?t:this.baseUrl.length&&this.baseUrl.lastIndexOf("/")!==this.baseUrl.length-1&&"/"!==t.charAt(0)?this.baseUrl+"/"+t:this.baseUrl+t},n.prototype._loadResource=function(t,e){var r=this;t._dequeue=e,o.eachSeries(this._beforeMiddleware,function(e,n){e.call(r,t,function(){n(t.isComplete?{}:null)})},function(){t.isComplete?r._onLoad(t):(t.once("complete",r._onLoad,r),t.load())})},n.prototype._onComplete=function(){this.loading=!1,this.emit("complete",this,this.resources)},n.prototype._onLoad=function(t){var e=this;o.eachSeries(this._afterMiddleware,function(r,n){r.call(e,t,n)},function(){t.emit("afterMiddleware",t),e._numToLoad--,e.progress+=e._progressChunk,e.emit("progress",e,t),t.error?e.emit("error",t.error,e,t):e.emit("load",e,t),0===e._numToLoad&&(e.progress=100,e._onComplete())}),t._dequeue()},n.LOAD_TYPE=s.LOAD_TYPE,n.XHR_RESPONSE_TYPE=s.XHR_RESPONSE_TYPE},{"./Resource":32,"./async":33,eventemitter3:3,"parse-uri":30}],32:[function(t,e,r){"use strict";function n(t,e,r){if(s.call(this),r=r||{},"string"!=typeof t||"string"!=typeof e)throw new Error("Both name and url are required for constructing a resource.");this.name=t,this.url=e,this.isDataUrl=0===this.url.indexOf("data:"),this.data=null,this.crossOrigin=r.crossOrigin===!0?"anonymous":r.crossOrigin,this.loadType=r.loadType||this._determineLoadType(),this.xhrType=r.xhrType,this.metadata=r.metadata||{},this.error=null,this.xhr=null,this.isJson=!1,this.isXml=!1,this.isImage=!1,this.isAudio=!1,this.isVideo=!1,this.isComplete=!1,this.isLoading=!1,this._dequeue=null,this._boundComplete=this.complete.bind(this),this._boundOnError=this._onError.bind(this),this._boundOnProgress=this._onProgress.bind(this),this._boundXhrOnError=this._xhrOnError.bind(this),this._boundXhrOnAbort=this._xhrOnAbort.bind(this),this._boundXhrOnLoad=this._xhrOnLoad.bind(this),this._boundXdrOnTimeout=this._xdrOnTimeout.bind(this)}function i(t){return t.toString().replace("object ","")}function o(t,e,r){e&&0===e.indexOf(".")&&(e=e.substring(1)),e&&(t[e]=r)}var s=t("eventemitter3"),a=t("parse-uri"),u=!(!window.XDomainRequest||"withCredentials"in new XMLHttpRequest),h=null,l=0,c=200,d=204;n.prototype=Object.create(s.prototype),n.prototype.constructor=n,e.exports=n,n.prototype.complete=function(){if(this.data&&this.data.removeEventListener&&(this.data.removeEventListener("error",this._boundOnError,!1),this.data.removeEventListener("load",this._boundComplete,!1),this.data.removeEventListener("progress",this._boundOnProgress,!1),this.data.removeEventListener("canplaythrough",this._boundComplete,!1)),this.xhr&&(this.xhr.removeEventListener?(this.xhr.removeEventListener("error",this._boundXhrOnError,!1),this.xhr.removeEventListener("abort",this._boundXhrOnAbort,!1),this.xhr.removeEventListener("progress",this._boundOnProgress,!1),this.xhr.removeEventListener("load",this._boundXhrOnLoad,!1)):(this.xhr.onerror=null,this.xhr.ontimeout=null,this.xhr.onprogress=null,this.xhr.onload=null)),this.isComplete)throw new Error("Complete called again for an already completed resource.");this.isComplete=!0,this.isLoading=!1,this.emit("complete",this)},n.prototype.abort=function(t){if(!this.error){if(this.error=new Error(t),this.xhr)this.xhr.abort();else if(this.xdr)this.xdr.abort();else if(this.data)if("undefined"!=typeof this.data.src)this.data.src="";else for(;this.data.firstChild;)this.data.removeChild(this.data.firstChild);this.complete()}},n.prototype.load=function(t){if(!this.isLoading)if(this.isComplete){if(t){var e=this;setTimeout(function(){t(e)},1)}}else switch(t&&this.once("complete",t),this.isLoading=!0,this.emit("start",this),this.crossOrigin!==!1&&"string"==typeof this.crossOrigin||(this.crossOrigin=this._determineCrossOrigin(this.url)),this.loadType){case n.LOAD_TYPE.IMAGE:this._loadElement("image");break;case n.LOAD_TYPE.AUDIO:this._loadSourceElement("audio");break;case n.LOAD_TYPE.VIDEO:this._loadSourceElement("video");break;case n.LOAD_TYPE.XHR:default:u&&this.crossOrigin?this._loadXdr():this._loadXhr()}},n.prototype._loadElement=function(t){this.metadata.loadElement?this.data=this.metadata.loadElement:"image"===t&&"undefined"!=typeof window.Image?this.data=new Image:this.data=document.createElement(t),this.crossOrigin&&(this.data.crossOrigin=this.crossOrigin),this.metadata.skipSource||(this.data.src=this.url);var e="is"+t[0].toUpperCase()+t.substring(1);this[e]===!1&&(this[e]=!0),this.data.addEventListener("error",this._boundOnError,!1),this.data.addEventListener("load",this._boundComplete,!1),this.data.addEventListener("progress",this._boundOnProgress,!1)},n.prototype._loadSourceElement=function(t){if(this.metadata.loadElement?this.data=this.metadata.loadElement:"audio"===t&&"undefined"!=typeof window.Audio?this.data=new Audio:this.data=document.createElement(t),null===this.data)return void this.abort("Unsupported element "+t);if(!this.metadata.skipSource)if(navigator.isCocoonJS)this.data.src=Array.isArray(this.url)?this.url[0]:this.url;else if(Array.isArray(this.url))for(var e=0;e<this.url.length;++e)this.data.appendChild(this._createSource(t,this.url[e]));else this.data.appendChild(this._createSource(t,this.url));this["is"+t[0].toUpperCase()+t.substring(1)]=!0,this.data.addEventListener("error",this._boundOnError,!1),this.data.addEventListener("load",this._boundComplete,!1),this.data.addEventListener("progress",this._boundOnProgress,!1),this.data.addEventListener("canplaythrough",this._boundComplete,!1),this.data.load()},n.prototype._loadXhr=function(){"string"!=typeof this.xhrType&&(this.xhrType=this._determineXhrType());var t=this.xhr=new XMLHttpRequest;t.open("GET",this.url,!0),this.xhrType===n.XHR_RESPONSE_TYPE.JSON||this.xhrType===n.XHR_RESPONSE_TYPE.DOCUMENT?t.responseType=n.XHR_RESPONSE_TYPE.TEXT:t.responseType=this.xhrType,t.addEventListener("error",this._boundXhrOnError,!1),t.addEventListener("abort",this._boundXhrOnAbort,!1),t.addEventListener("progress",this._boundOnProgress,!1),t.addEventListener("load",this._boundXhrOnLoad,!1),t.send()},n.prototype._loadXdr=function(){"string"!=typeof this.xhrType&&(this.xhrType=this._determineXhrType());var t=this.xhr=new XDomainRequest;t.timeout=5e3,t.onerror=this._boundXhrOnError,t.ontimeout=this._boundXdrOnTimeout,t.onprogress=this._boundOnProgress,t.onload=this._boundXhrOnLoad,t.open("GET",this.url,!0),setTimeout(function(){t.send()},0)},n.prototype._createSource=function(t,e,r){r||(r=t+"/"+e.substr(e.lastIndexOf(".")+1));var n=document.createElement("source");return n.src=e,n.type=r,n},n.prototype._onError=function(t){this.abort("Failed to load element using "+t.target.nodeName)},n.prototype._onProgress=function(t){t&&t.lengthComputable&&this.emit("progress",this,t.loaded/t.total)},n.prototype._xhrOnError=function(){var t=this.xhr;this.abort(i(t)+" Request failed. Status: "+t.status+', text: "'+t.statusText+'"')},n.prototype._xhrOnAbort=function(){this.abort(i(this.xhr)+" Request was aborted by the user.")},n.prototype._xdrOnTimeout=function(){this.abort(i(this.xhr)+" Request timed out.")},n.prototype._xhrOnLoad=function(){var t=this.xhr,e="undefined"==typeof t.status?t.status:c;if(!(e===c||e===d||e===l&&t.responseText.length>0))return void this.abort("["+t.status+"]"+t.statusText+":"+t.responseURL);if(this.xhrType===n.XHR_RESPONSE_TYPE.TEXT)this.data=t.responseText;else if(this.xhrType===n.XHR_RESPONSE_TYPE.JSON)try{this.data=JSON.parse(t.responseText),this.isJson=!0}catch(t){return void this.abort("Error trying to parse loaded json:",t)}else if(this.xhrType===n.XHR_RESPONSE_TYPE.DOCUMENT)try{if(window.DOMParser){var r=new DOMParser;this.data=r.parseFromString(t.responseText,"text/xml")}else{var i=document.createElement("div");i.innerHTML=t.responseText,this.data=i}this.isXml=!0}catch(t){return void this.abort("Error trying to parse loaded xml:",t)}else this.data=t.response||t.responseText;this.complete()},n.prototype._determineCrossOrigin=function(t,e){if(0===t.indexOf("data:"))return"";e=e||window.location,h||(h=document.createElement("a")),h.href=t,t=a(h.href,{strictMode:!0});var r=!t.port&&""===e.port||t.port===e.port,n=t.protocol?t.protocol+":":"";return t.host===e.hostname&&r&&n===e.protocol?"":"anonymous"},n.prototype._determineXhrType=function(){return n._xhrTypeMap[this._getExtension()]||n.XHR_RESPONSE_TYPE.TEXT},n.prototype._determineLoadType=function(){return n._loadTypeMap[this._getExtension()]||n.LOAD_TYPE.XHR},n.prototype._getExtension=function(){var t=this.url,e="";if(this.isDataUrl){var r=t.indexOf("/");e=t.substring(r+1,t.indexOf(";",r))}else{var n=t.indexOf("?");n!==-1&&(t=t.substring(0,n)),e=t.substring(t.lastIndexOf(".")+1)}return e.toLowerCase()},n.prototype._getMimeFromXhrType=function(t){switch(t){case n.XHR_RESPONSE_TYPE.BUFFER:return"application/octet-binary";case n.XHR_RESPONSE_TYPE.BLOB:return"application/blob";case n.XHR_RESPONSE_TYPE.DOCUMENT:return"application/xml";case n.XHR_RESPONSE_TYPE.JSON:return"application/json";case n.XHR_RESPONSE_TYPE.DEFAULT:case n.XHR_RESPONSE_TYPE.TEXT:default:return"text/plain"}},n.LOAD_TYPE={XHR:1,IMAGE:2,AUDIO:3,VIDEO:4},n.XHR_RESPONSE_TYPE={DEFAULT:"text",BUFFER:"arraybuffer",BLOB:"blob",DOCUMENT:"document",JSON:"json",TEXT:"text"},n._loadTypeMap={gif:n.LOAD_TYPE.IMAGE,png:n.LOAD_TYPE.IMAGE,bmp:n.LOAD_TYPE.IMAGE,jpg:n.LOAD_TYPE.IMAGE,jpeg:n.LOAD_TYPE.IMAGE,tif:n.LOAD_TYPE.IMAGE,tiff:n.LOAD_TYPE.IMAGE,webp:n.LOAD_TYPE.IMAGE,tga:n.LOAD_TYPE.IMAGE,"svg+xml":n.LOAD_TYPE.IMAGE},n._xhrTypeMap={xhtml:n.XHR_RESPONSE_TYPE.DOCUMENT,html:n.XHR_RESPONSE_TYPE.DOCUMENT,htm:n.XHR_RESPONSE_TYPE.DOCUMENT,xml:n.XHR_RESPONSE_TYPE.DOCUMENT,tmx:n.XHR_RESPONSE_TYPE.DOCUMENT,tsx:n.XHR_RESPONSE_TYPE.DOCUMENT,svg:n.XHR_RESPONSE_TYPE.DOCUMENT,gif:n.XHR_RESPONSE_TYPE.BLOB,png:n.XHR_RESPONSE_TYPE.BLOB,bmp:n.XHR_RESPONSE_TYPE.BLOB,jpg:n.XHR_RESPONSE_TYPE.BLOB,jpeg:n.XHR_RESPONSE_TYPE.BLOB,tif:n.XHR_RESPONSE_TYPE.BLOB,tiff:n.XHR_RESPONSE_TYPE.BLOB,webp:n.XHR_RESPONSE_TYPE.BLOB,tga:n.XHR_RESPONSE_TYPE.BLOB,json:n.XHR_RESPONSE_TYPE.JSON,text:n.XHR_RESPONSE_TYPE.TEXT,txt:n.XHR_RESPONSE_TYPE.TEXT},n.setExtensionLoadType=function(t,e){o(n._loadTypeMap,t,e)},n.setExtensionXhrType=function(t,e){o(n._xhrTypeMap,t,e)}},{eventemitter3:3,"parse-uri":30}],33:[function(t,e,r){"use strict";function n(){}function i(t,e,r){var n=0,i=t.length;!function o(s){return s||n===i?void(r&&r(s)):void e(t[n++],o)}()}function o(t){return function(){if(null===t)throw new Error("Callback was already called.");var e=t;t=null,e.apply(this,arguments)}}function s(t,e){function r(t,e,r){if(null!=r&&"function"!=typeof r)throw new Error("task callback must be a function");if(a.started=!0,null==t&&a.idle())return void setTimeout(function(){a.drain()},1);var i={data:t,callback:"function"==typeof r?r:n};e?a._tasks.unshift(i):a._tasks.push(i),setTimeout(function(){a.process()},1)}function i(t){return function(){s-=1,t.callback.apply(t,arguments),null!=arguments[0]&&a.error(arguments[0],t.data),s<=a.concurrency-a.buffer&&a.unsaturated(),a.idle()&&a.drain(),a.process()}}if(null==e)e=1;else if(0===e)throw new Error("Concurrency must not be zero");var s=0,a={_tasks:[],concurrency:e,saturated:n,unsaturated:n,buffer:e/4,empty:n,drain:n,error:n,started:!1,paused:!1,push:function(t,e){r(t,!1,e)},kill:function(){a.drain=n,a._tasks=[]},unshift:function(t,e){r(t,!0,e)},process:function(){for(;!a.paused&&s<a.concurrency&&a._tasks.length;){var e=a._tasks.shift();0===a._tasks.length&&a.empty(),s+=1,s===a.concurrency&&a.saturated(),t(e.data,o(i(e)))}},length:function(){return a._tasks.length},running:function(){return s},idle:function(){return a._tasks.length+s===0},pause:function(){a.paused!==!0&&(a.paused=!0)},resume:function(){if(a.paused!==!1){a.paused=!1;for(var t=1;t<=a.concurrency;t++)a.process()}}};return a}e.exports={eachSeries:i,queue:s}},{}],34:[function(t,e,r){"use strict";e.exports={_keyStr:"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=",encodeBinary:function(t){for(var e,r="",n=new Array(4),i=0,o=0,s=0;i<t.length;){for(e=new Array(3),o=0;o<e.length;o++)i<t.length?e[o]=255&t.charCodeAt(i++):e[o]=0;switch(n[0]=e[0]>>2,n[1]=(3&e[0])<<4|e[1]>>4,n[2]=(15&e[1])<<2|e[2]>>6,n[3]=63&e[2],s=i-(t.length-1)){case 2:n[3]=64,n[2]=64;break;case 1:n[3]=64}for(o=0;o<n.length;o++)r+=this._keyStr.charAt(n[o])}return r}}},{}],35:[function(t,e,r){"use strict";e.exports=t("./Loader"),e.exports.Resource=t("./Resource"),e.exports.middleware={caching:{memory:t("./middlewares/caching/memory")},parsing:{blob:t("./middlewares/parsing/blob")}},e.exports.async=t("./async")},{"./Loader":31,"./Resource":32,"./async":33,"./middlewares/caching/memory":36,"./middlewares/parsing/blob":37}],36:[function(t,e,r){"use strict";var n={};e.exports=function(){return function(t,e){n[t.url]?(t.data=n[t.url],t.complete()):t.once("complete",function(){n[this.url]=this.data}),e()}}},{}],37:[function(t,e,r){"use strict";var n=t("../../Resource"),i=t("../../b64"),o=window.URL||window.webkitURL;e.exports=function(){return function(t,e){if(!t.data)return void e();if(t.xhr&&t.xhrType===n.XHR_RESPONSE_TYPE.BLOB)if(window.Blob&&"string"!=typeof t.data){if(0===t.data.type.indexOf("image")){var r=o.createObjectURL(t.data);return t.blob=t.data,t.data=new Image,t.data.src=r,t.isImage=!0,void(t.data.onload=function(){o.revokeObjectURL(r),t.data.onload=null,e()})}}else{var s=t.xhr.getResponseHeader("content-type");if(s&&0===s.indexOf("image"))return t.data=new Image,t.data.src="data:"+s+";base64,"+i.encodeBinary(t.xhr.responseText),t.isImage=!0,void(t.data.onload=function(){t.data.onload=null,e()})}e()}}},{"../../Resource":32,"../../b64":34}],38:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function o(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var s=t("../core"),a=i(s),u=t("ismobilejs"),h=n(u),l=t("./accessibleTarget"),c=n(l);Object.assign(a.DisplayObject.prototype,c.default);var d=9,f=100,p=0,v=0,y=2,g=1,m=-1e3,_=-1e3,b=2,x=function(){function t(e){o(this,t),!h.default.tablet&&!h.default.phone||navigator.isCocoonJS||this.createTouchHook();var r=document.createElement("div");r.style.width=f+"px",r.style.height=f+"px",r.style.position="absolute",r.style.top=p+"px",r.style.left=v+"px",r.style.zIndex=y,this.div=r,this.pool=[],this.renderId=0,this.debug=!1,this.renderer=e,this.children=[],this._onKeyDown=this._onKeyDown.bind(this),this._onMouseMove=this._onMouseMove.bind(this),this.isActive=!1,this.isMobileAccessabillity=!1,window.addEventListener("keydown",this._onKeyDown,!1)}return t.prototype.createTouchHook=function(){var t=this,e=document.createElement("button");e.style.width=g+"px",e.style.height=g+"px",e.style.position="absolute",e.style.top=m+"px",e.style.left=_+"px",e.style.zIndex=b,e.style.backgroundColor="#FF0000",e.title="HOOK DIV",e.addEventListener("focus",function(){t.isMobileAccessabillity=!0,t.activate(),document.body.removeChild(e)}),document.body.appendChild(e)},t.prototype.activate=function(){this.isActive||(this.isActive=!0,window.document.addEventListener("mousemove",this._onMouseMove,!0),window.removeEventListener("keydown",this._onKeyDown,!1),this.renderer.on("postrender",this.update,this),this.renderer.view.parentNode&&this.renderer.view.parentNode.appendChild(this.div))},t.prototype.deactivate=function(){this.isActive&&!this.isMobileAccessabillity&&(this.isActive=!1,window.document.removeEventListener("mousemove",this._onMouseMove),window.addEventListener("keydown",this._onKeyDown,!1),this.renderer.off("postrender",this.update),this.div.parentNode&&this.div.parentNode.removeChild(this.div))},t.prototype.updateAccessibleObjects=function(t){if(t.visible){t.accessible&&t.interactive&&(t._accessibleActive||this.addChild(t),t.renderId=this.renderId);for(var e=t.children,r=e.length-1;r>=0;r--)this.updateAccessibleObjects(e[r])}},t.prototype.update=function(){if(this.renderer.renderingToScreen){this.updateAccessibleObjects(this.renderer._lastObjectRendered);var t=this.renderer.view.getBoundingClientRect(),e=t.width/this.renderer.width,r=t.height/this.renderer.height,n=this.div;
n.style.left=t.left+"px",n.style.top=t.top+"px",n.style.width=this.renderer.width+"px",n.style.height=this.renderer.height+"px";for(var i=0;i<this.children.length;i++){var o=this.children[i];if(o.renderId!==this.renderId)o._accessibleActive=!1,a.utils.removeItems(this.children,i,1),this.div.removeChild(o._accessibleDiv),this.pool.push(o._accessibleDiv),o._accessibleDiv=null,i--,0===this.children.length&&this.deactivate();else{n=o._accessibleDiv;var s=o.hitArea,u=o.worldTransform;o.hitArea?(n.style.left=(u.tx+s.x*u.a)*e+"px",n.style.top=(u.ty+s.y*u.d)*r+"px",n.style.width=s.width*u.a*e+"px",n.style.height=s.height*u.d*r+"px"):(s=o.getBounds(),this.capHitArea(s),n.style.left=s.x*e+"px",n.style.top=s.y*r+"px",n.style.width=s.width*e+"px",n.style.height=s.height*r+"px")}}this.renderId++}},t.prototype.capHitArea=function(t){t.x<0&&(t.width+=t.x,t.x=0),t.y<0&&(t.height+=t.y,t.y=0),t.x+t.width>this.renderer.width&&(t.width=this.renderer.width-t.x),t.y+t.height>this.renderer.height&&(t.height=this.renderer.height-t.y)},t.prototype.addChild=function(t){var e=this.pool.pop();e||(e=document.createElement("button"),e.style.width=f+"px",e.style.height=f+"px",e.style.backgroundColor=this.debug?"rgba(255,0,0,0.5)":"transparent",e.style.position="absolute",e.style.zIndex=y,e.style.borderStyle="none",e.addEventListener("click",this._onClick.bind(this)),e.addEventListener("focus",this._onFocus.bind(this)),e.addEventListener("focusout",this._onFocusOut.bind(this))),t.accessibleTitle?e.title=t.accessibleTitle:t.accessibleTitle||t.accessibleHint||(e.title="displayObject "+this.tabIndex),t.accessibleHint&&e.setAttribute("aria-label",t.accessibleHint),t._accessibleActive=!0,t._accessibleDiv=e,e.displayObject=t,this.children.push(t),this.div.appendChild(t._accessibleDiv),t._accessibleDiv.tabIndex=t.tabIndex},t.prototype._onClick=function(t){var e=this.renderer.plugins.interaction;e.dispatchEvent(t.target.displayObject,"click",e.eventData)},t.prototype._onFocus=function(t){var e=this.renderer.plugins.interaction;e.dispatchEvent(t.target.displayObject,"mouseover",e.eventData)},t.prototype._onFocusOut=function(t){var e=this.renderer.plugins.interaction;e.dispatchEvent(t.target.displayObject,"mouseout",e.eventData)},t.prototype._onKeyDown=function(t){t.keyCode===d&&this.activate()},t.prototype._onMouseMove=function(){this.deactivate()},t.prototype.destroy=function(){this.div=null;for(var t=0;t<this.children.length;t++)this.children[t].div=null;window.document.removeEventListener("mousemove",this._onMouseMove),window.removeEventListener("keydown",this._onKeyDown),this.pool=null,this.children=null,this.renderer=null},t}();r.default=x,a.WebGLRenderer.registerPlugin("accessibility",x),a.CanvasRenderer.registerPlugin("accessibility",x)},{"../core":61,"./accessibleTarget":39,ismobilejs:4}],39:[function(t,e,r){"use strict";r.__esModule=!0,r.default={accessible:!1,accessibleTitle:null,accessibleHint:null,tabIndex:0,_accessibleActive:!1,_accessibleDiv:!1}},{}],40:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}r.__esModule=!0;var i=t("./accessibleTarget");Object.defineProperty(r,"accessibleTarget",{enumerable:!0,get:function(){return n(i).default}});var o=t("./AccessibilityManager");Object.defineProperty(r,"AccessibilityManager",{enumerable:!0,get:function(){return n(o).default}})},{"./AccessibilityManager":38,"./accessibleTarget":39}],41:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}function a(t){if(t instanceof Array){if("precision"!==t[0].substring(0,9)){var e=t.slice(0);return e.unshift("precision "+c+" float;"),e}}else if("precision"!==t.substring(0,9))return"precision "+c+" float;\n"+t;return t}r.__esModule=!0;var u=t("pixi-gl-core"),h=t("./settings"),l=n(h),c=l.default.PRECISION,d=function(t){function e(r,n,s){return i(this,e),o(this,t.call(this,r,a(n),a(s)))}return s(e,t),e}(u.GLShader);r.default=d},{"./settings":97,"pixi-gl-core":12}],42:[function(t,e,r){"use strict";r.__esModule=!0;r.VERSION="4.2.2",r.PI_2=2*Math.PI,r.RAD_TO_DEG=180/Math.PI,r.DEG_TO_RAD=Math.PI/180,r.RENDERER_TYPE={UNKNOWN:0,WEBGL:1,CANVAS:2},r.BLEND_MODES={NORMAL:0,ADD:1,MULTIPLY:2,SCREEN:3,OVERLAY:4,DARKEN:5,LIGHTEN:6,COLOR_DODGE:7,COLOR_BURN:8,HARD_LIGHT:9,SOFT_LIGHT:10,DIFFERENCE:11,EXCLUSION:12,HUE:13,SATURATION:14,COLOR:15,LUMINOSITY:16},r.DRAW_MODES={POINTS:0,LINES:1,LINE_LOOP:2,LINE_STRIP:3,TRIANGLES:4,TRIANGLE_STRIP:5,TRIANGLE_FAN:6},r.SCALE_MODES={LINEAR:0,NEAREST:1},r.WRAP_MODES={CLAMP:0,REPEAT:1,MIRRORED_REPEAT:2},r.GC_MODES={AUTO:0,MANUAL:1},r.URL_FILE_EXTENSION=/\.(\w{3,4})(?:$|\?|#)/i,r.DATA_URI=/^\s*data:(?:([\w-]+)\/([\w+.-]+))?(?:;(charset=[\w-]+|base64))?,(.*)/i,r.SVG_SIZE=/<svg[^>]*(?:\s(width|height)=('|")(\d*(?:\.\d+)?)(?:px)?('|"))[^>]*(?:\s(width|height)=('|")(\d*(?:\.\d+)?)(?:px)?('|"))[^>]*>/i,r.SHAPES={POLY:0,RECT:1,CIRC:2,ELIP:3,RREC:4},r.PRECISION={LOW:"lowp",MEDIUM:"mediump",HIGH:"highp"},r.TRANSFORM_MODE={STATIC:0,DYNAMIC:1},r.TEXT_GRADIENT={LINEAR_VERTICAL:0,LINEAR_HORIZONTAL:1}},{}],43:[function(t,e,r){"use strict";function n(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var i=t("../math"),o=function(){function t(){n(this,t),this.minX=1/0,this.minY=1/0,this.maxX=-(1/0),this.maxY=-(1/0),this.rect=null}return t.prototype.isEmpty=function(){return this.minX>this.maxX||this.minY>this.maxY},t.prototype.clear=function(){this.updateID++,this.minX=1/0,this.minY=1/0,this.maxX=-(1/0),this.maxY=-(1/0)},t.prototype.getRectangle=function(t){return this.minX>this.maxX||this.minY>this.maxY?i.Rectangle.EMPTY:(t=t||new i.Rectangle(0,0,1,1),t.x=this.minX,t.y=this.minY,t.width=this.maxX-this.minX,t.height=this.maxY-this.minY,t)},t.prototype.addPoint=function(t){this.minX=Math.min(this.minX,t.x),this.maxX=Math.max(this.maxX,t.x),this.minY=Math.min(this.minY,t.y),this.maxY=Math.max(this.maxY,t.y)},t.prototype.addQuad=function(t){var e=this.minX,r=this.minY,n=this.maxX,i=this.maxY,o=t[0],s=t[1];e=o<e?o:e,r=s<r?s:r,n=o>n?o:n,i=s>i?s:i,o=t[2],s=t[3],e=o<e?o:e,r=s<r?s:r,n=o>n?o:n,i=s>i?s:i,o=t[4],s=t[5],e=o<e?o:e,r=s<r?s:r,n=o>n?o:n,i=s>i?s:i,o=t[6],s=t[7],e=o<e?o:e,r=s<r?s:r,n=o>n?o:n,i=s>i?s:i,this.minX=e,this.minY=r,this.maxX=n,this.maxY=i},t.prototype.addFrame=function(t,e,r,n,i){var o=t.worldTransform,s=o.a,a=o.b,u=o.c,h=o.d,l=o.tx,c=o.ty,d=this.minX,f=this.minY,p=this.maxX,v=this.maxY,y=s*e+u*r+l,g=a*e+h*r+c;d=y<d?y:d,f=g<f?g:f,p=y>p?y:p,v=g>v?g:v,y=s*n+u*r+l,g=a*n+h*r+c,d=y<d?y:d,f=g<f?g:f,p=y>p?y:p,v=g>v?g:v,y=s*e+u*i+l,g=a*e+h*i+c,d=y<d?y:d,f=g<f?g:f,p=y>p?y:p,v=g>v?g:v,y=s*n+u*i+l,g=a*n+h*i+c,d=y<d?y:d,f=g<f?g:f,p=y>p?y:p,v=g>v?g:v,this.minX=d,this.minY=f,this.maxX=p,this.maxY=v},t.prototype.addVertices=function(t,e,r,n){for(var i=t.worldTransform,o=i.a,s=i.b,a=i.c,u=i.d,h=i.tx,l=i.ty,c=this.minX,d=this.minY,f=this.maxX,p=this.maxY,v=r;v<n;v+=2){var y=e[v],g=e[v+1],m=o*y+a*g+h,_=u*g+s*y+l;c=m<c?m:c,d=_<d?_:d,f=m>f?m:f,p=_>p?_:p}this.minX=c,this.minY=d,this.maxX=f,this.maxY=p},t.prototype.addBounds=function(t){var e=this.minX,r=this.minY,n=this.maxX,i=this.maxY;this.minX=t.minX<e?t.minX:e,this.minY=t.minY<r?t.minY:r,this.maxX=t.maxX>n?t.maxX:n,this.maxY=t.maxY>i?t.maxY:i},t.prototype.addBoundsMask=function(t,e){var r=t.minX>e.minX?t.minX:e.minX,n=t.minY>e.minY?t.minY:e.minY,i=t.maxX<e.maxX?t.maxX:e.maxX,o=t.maxY<e.maxY?t.maxY:e.maxY;if(r<=i&&n<=o){var s=this.minX,a=this.minY,u=this.maxX,h=this.maxY;this.minX=r<s?r:s,this.minY=n<a?n:a,this.maxX=i>u?i:u,this.maxY=o>h?o:h}},t.prototype.addBoundsArea=function(t,e){var r=t.minX>e.x?t.minX:e.x,n=t.minY>e.y?t.minY:e.y,i=t.maxX<e.x+e.width?t.maxX:e.x+e.width,o=t.maxY<e.y+e.height?t.maxY:e.y+e.height;if(r<=i&&n<=o){var s=this.minX,a=this.minY,u=this.maxX,h=this.maxY;this.minX=r<s?r:s,this.minY=n<a?n:a,this.maxX=i>u?i:u,this.maxY=o>h?o:h}},t}();r.default=o},{"../math":66}],44:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),u=t("../utils"),h=t("./DisplayObject"),l=n(h),c=function(t){function e(){i(this,e);var r=o(this,t.call(this));return r.children=[],r}return s(e,t),e.prototype.onChildrenChange=function(){},e.prototype.addChild=function(t){var e=arguments.length;if(e>1)for(var r=0;r<e;r++)this.addChild(arguments[r]);else t.parent&&t.parent.removeChild(t),t.parent=this,this.transform._parentID=-1,this._boundsID++,this.children.push(t),this.onChildrenChange(this.children.length-1),t.emit("added",this);return t},e.prototype.addChildAt=function(t,e){if(e<0||e>this.children.length)throw new Error(t+"addChildAt: The index "+e+" supplied is out of bounds "+this.children.length);return t.parent&&t.parent.removeChild(t),t.parent=this,this.children.splice(e,0,t),this.onChildrenChange(e),t.emit("added",this),t},e.prototype.swapChildren=function(t,e){if(t!==e){var r=this.getChildIndex(t),n=this.getChildIndex(e);this.children[r]=e,this.children[n]=t,this.onChildrenChange(r<n?r:n)}},e.prototype.getChildIndex=function(t){var e=this.children.indexOf(t);if(e===-1)throw new Error("The supplied DisplayObject must be a child of the caller");return e},e.prototype.setChildIndex=function(t,e){if(e<0||e>=this.children.length)throw new Error("The supplied index is out of bounds");var r=this.getChildIndex(t);(0,u.removeItems)(this.children,r,1),this.children.splice(e,0,t),this.onChildrenChange(e)},e.prototype.getChildAt=function(t){if(t<0||t>=this.children.length)throw new Error("getChildAt: Index ("+t+") does not exist.");return this.children[t]},e.prototype.removeChild=function(t){var e=arguments.length;if(e>1)for(var r=0;r<e;r++)this.removeChild(arguments[r]);else{var n=this.children.indexOf(t);if(n===-1)return null;t.parent=null,(0,u.removeItems)(this.children,n,1),this.transform._parentID=-1,this._boundsID++,this.onChildrenChange(n),t.emit("removed",this)}return t},e.prototype.removeChildAt=function(t){var e=this.getChildAt(t);return e.parent=null,(0,u.removeItems)(this.children,t,1),this.onChildrenChange(t),e.emit("removed",this),e},e.prototype.removeChildren=function(){var t=arguments.length<=0||void 0===arguments[0]?0:arguments[0],e=arguments[1],r=t,n="number"==typeof e?e:this.children.length,i=n-r,o=void 0;if(i>0&&i<=n){o=this.children.splice(r,i);for(var s=0;s<o.length;++s)o[s].parent=null;this.onChildrenChange(t);for(var a=0;a<o.length;++a)o[a].emit("removed",this);return o}if(0===i&&0===this.children.length)return[];throw new RangeError("removeChildren: numeric values are outside the acceptable range.")},e.prototype.updateTransform=function(){this._boundsID++,this.transform.updateTransform(this.parent.transform),this.worldAlpha=this.alpha*this.parent.worldAlpha;for(var t=0,e=this.children.length;t<e;++t){var r=this.children[t];r.visible&&r.updateTransform()}},e.prototype.calculateBounds=function(){this._bounds.clear(),this._calculateBounds();for(var t=0;t<this.children.length;t++){var e=this.children[t];e.visible&&e.renderable&&(e.calculateBounds(),e._mask?(e._mask.calculateBounds(),this._bounds.addBoundsMask(e._bounds,e._mask._bounds)):e.filterArea?this._bounds.addBoundsArea(e._bounds,e.filterArea):this._bounds.addBounds(e._bounds))}this._lastBoundsID=this._boundsID},e.prototype._calculateBounds=function(){},e.prototype.renderWebGL=function(t){if(this.visible&&!(this.worldAlpha<=0)&&this.renderable)if(this._mask||this._filters)this.renderAdvancedWebGL(t);else{this._renderWebGL(t);for(var e=0,r=this.children.length;e<r;++e)this.children[e].renderWebGL(t)}},e.prototype.renderAdvancedWebGL=function(t){t.flush();var e=this._filters,r=this._mask;if(e){this._enabledFilters||(this._enabledFilters=[]),this._enabledFilters.length=0;for(var n=0;n<e.length;n++)e[n].enabled&&this._enabledFilters.push(e[n]);this._enabledFilters.length&&t.filterManager.pushFilter(this,this._enabledFilters)}r&&t.maskManager.pushMask(this,this._mask),this._renderWebGL(t);for(var i=0,o=this.children.length;i<o;i++)this.children[i].renderWebGL(t);t.flush(),r&&t.maskManager.popMask(this,this._mask),e&&this._enabledFilters&&this._enabledFilters.length&&t.filterManager.popFilter()},e.prototype._renderWebGL=function(t){},e.prototype._renderCanvas=function(t){},e.prototype.renderCanvas=function(t){if(this.visible&&!(this.worldAlpha<=0)&&this.renderable){this._mask&&t.maskManager.pushMask(this._mask),this._renderCanvas(t);for(var e=0,r=this.children.length;e<r;++e)this.children[e].renderCanvas(t);this._mask&&t.maskManager.popMask(t)}},e.prototype.destroy=function(e){t.prototype.destroy.call(this);var r="boolean"==typeof e?e:e&&e.children,n=this.removeChildren(0,this.children.length);if(r)for(var i=0;i<n.length;++i)n[i].destroy(e)},a(e,[{key:"width",get:function(){return this.scale.x*this.getLocalBounds().width},set:function(t){var e=this.getLocalBounds().width;0!==e?this.scale.x=t/e:this.scale.x=1,this._width=t}},{key:"height",get:function(){return this.scale.y*this.getLocalBounds().height},set:function(t){var e=this.getLocalBounds().height;0!==e?this.scale.y=t/e:this.scale.y=1,this._height=t}}]),e}(l.default);r.default=c,c.prototype.containerUpdateTransform=c.prototype.updateTransform},{"../utils":117,"./DisplayObject":45}],45:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),u=t("eventemitter3"),h=n(u),l=t("../const"),c=t("../settings"),d=n(c),f=t("./TransformStatic"),p=n(f),v=t("./Transform"),y=n(v),g=t("./Bounds"),m=n(g),_=t("../math"),b=function(t){function e(){i(this,e);var r=o(this,t.call(this)),n=d.default.TRANSFORM_MODE===l.TRANSFORM_MODE.STATIC?p.default:y.default;return r.tempDisplayObjectParent=null,r.transform=new n,r.alpha=1,r.visible=!0,r.renderable=!0,r.parent=null,r.worldAlpha=1,r.filterArea=null,r._filters=null,r._enabledFilters=null,r._bounds=new m.default,r._boundsID=0,r._lastBoundsID=-1,r._boundsRect=null,r._localBoundsRect=null,r._mask=null,r}return s(e,t),e.prototype.updateTransform=function(){this.transform.updateTransform(this.parent.transform),this.worldAlpha=this.alpha*this.parent.worldAlpha,this._bounds.updateID++},e.prototype._recursivePostUpdateTransform=function(){this.parent?(this.parent._recursivePostUpdateTransform(),this.transform.updateTransform(this.parent.transform)):this.transform.updateTransform(this._tempDisplayObjectParent.transform)},e.prototype.getBounds=function(t,e){return t||(this.parent?(this._recursivePostUpdateTransform(),this.updateTransform()):(this.parent=this._tempDisplayObjectParent,this.updateTransform(),this.parent=null)),this._boundsID!==this._lastBoundsID&&this.calculateBounds(),e||(this._boundsRect||(this._boundsRect=new _.Rectangle),e=this._boundsRect),this._bounds.getRectangle(e)},e.prototype.getLocalBounds=function(t){var e=this.transform,r=this.parent;this.parent=null,this.transform=this._tempDisplayObjectParent.transform,t||(this._localBoundsRect||(this._localBoundsRect=new _.Rectangle),t=this._localBoundsRect);var n=this.getBounds(!1,t);return this.parent=r,this.transform=e,n},e.prototype.toGlobal=function(t,e){var r=!(arguments.length<=2||void 0===arguments[2])&&arguments[2];return r||(this._recursivePostUpdateTransform(),this.parent?this.displayObjectUpdateTransform():(this.parent=this._tempDisplayObjectParent,this.displayObjectUpdateTransform(),this.parent=null)),this.worldTransform.apply(t,e)},e.prototype.toLocal=function(t,e,r,n){return e&&(t=e.toGlobal(t,r,n)),n||(this._recursivePostUpdateTransform(),this.parent?this.displayObjectUpdateTransform():(this.parent=this._tempDisplayObjectParent,this.displayObjectUpdateTransform(),this.parent=null)),this.worldTransform.applyInverse(t,r)},e.prototype.renderWebGL=function(t){},e.prototype.renderCanvas=function(t){},e.prototype.setParent=function(t){if(!t||!t.addChild)throw new Error("setParent: Argument must be a Container");return t.addChild(this),t},e.prototype.setTransform=function(){var t=arguments.length<=0||void 0===arguments[0]?0:arguments[0],e=arguments.length<=1||void 0===arguments[1]?0:arguments[1],r=arguments.length<=2||void 0===arguments[2]?1:arguments[2],n=arguments.length<=3||void 0===arguments[3]?1:arguments[3],i=arguments.length<=4||void 0===arguments[4]?0:arguments[4],o=arguments.length<=5||void 0===arguments[5]?0:arguments[5],s=arguments.length<=6||void 0===arguments[6]?0:arguments[6],a=arguments.length<=7||void 0===arguments[7]?0:arguments[7],u=arguments.length<=8||void 0===arguments[8]?0:arguments[8];return this.position.x=t,this.position.y=e,this.scale.x=r?r:1,this.scale.y=n?n:1,this.rotation=i,this.skew.x=o,this.skew.y=s,this.pivot.x=a,this.pivot.y=u,this},e.prototype.destroy=function(){this.removeAllListeners(),this.parent&&this.parent.removeChild(this),this.transform=null,this.parent=null,this._bounds=null,this._currentBounds=null,this._mask=null,this.filterArea=null,this.interactive=!1,this.interactiveChildren=!1},a(e,[{key:"_tempDisplayObjectParent",get:function(){return null===this.tempDisplayObjectParent&&(this.tempDisplayObjectParent=new e),this.tempDisplayObjectParent}},{key:"x",get:function(){return this.position.x},set:function(t){this.transform.position.x=t}},{key:"y",get:function(){return this.position.y},set:function(t){this.transform.position.y=t}},{key:"worldTransform",get:function(){return this.transform.worldTransform}},{key:"localTransform",get:function(){return this.transform.localTransform}},{key:"position",get:function(){return this.transform.position},set:function(t){this.transform.position.copy(t)}},{key:"scale",get:function(){return this.transform.scale},set:function(t){this.transform.scale.copy(t)}},{key:"pivot",get:function(){return this.transform.pivot},set:function(t){this.transform.pivot.copy(t)}},{key:"skew",get:function(){return this.transform.skew},set:function(t){this.transform.skew.copy(t)}},{key:"rotation",get:function(){return this.transform.rotation},set:function(t){this.transform.rotation=t}},{key:"worldVisible",get:function(){var t=this;do{if(!t.visible)return!1;t=t.parent}while(t);return!0}},{key:"mask",get:function(){return this._mask},set:function(t){this._mask&&(this._mask.renderable=!0),this._mask=t,this._mask&&(this._mask.renderable=!1)}},{key:"filters",get:function(){return this._filters&&this._filters.slice()},set:function(t){this._filters=t&&t.slice()}}]),e}(h.default);r.default=b,b.prototype.displayObjectUpdateTransform=b.prototype.updateTransform},{"../const":42,"../math":66,"../settings":97,"./Bounds":43,"./Transform":46,"./TransformStatic":48,eventemitter3:3}],46:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),u=t("../math"),h=t("./TransformBase"),l=n(h),c=function(t){function e(){i(this,e);var r=o(this,t.call(this));return r.position=new u.Point(0,0),r.scale=new u.Point(1,1),r.skew=new u.ObservablePoint(r.updateSkew,r,0,0),r.pivot=new u.Point(0,0),r._rotation=0,r._sr=Math.sin(0),r._cr=Math.cos(0),r._cy=Math.cos(0),r._sy=Math.sin(0),r._nsx=Math.sin(0),r._cx=Math.cos(0),r}return s(e,t),e.prototype.updateSkew=function(){this._cy=Math.cos(this.skew.y),this._sy=Math.sin(this.skew.y),this._nsx=Math.sin(this.skew.x),this._cx=Math.cos(this.skew.x)},e.prototype.updateLocalTransform=function(){var t=this.localTransform,e=this._cr*this.scale.x,r=this._sr*this.scale.x,n=-this._sr*this.scale.y,i=this._cr*this.scale.y;t.a=this._cy*e+this._sy*n,t.b=this._cy*r+this._sy*i,t.c=this._nsx*e+this._cx*n,t.d=this._nsx*r+this._cx*i},e.prototype.updateTransform=function(t){var e=t.worldTransform,r=this.worldTransform,n=this.localTransform,i=this._cr*this.scale.x,o=this._sr*this.scale.x,s=-this._sr*this.scale.y,a=this._cr*this.scale.y;n.a=this._cy*i+this._sy*s,n.b=this._cy*o+this._sy*a,n.c=this._nsx*i+this._cx*s,n.d=this._nsx*o+this._cx*a,n.tx=this.position.x-(this.pivot.x*n.a+this.pivot.y*n.c),n.ty=this.position.y-(this.pivot.x*n.b+this.pivot.y*n.d),r.a=n.a*e.a+n.b*e.c,r.b=n.a*e.b+n.b*e.d,r.c=n.c*e.a+n.d*e.c,r.d=n.c*e.b+n.d*e.d,r.tx=n.tx*e.a+n.ty*e.c+e.tx,r.ty=n.tx*e.b+n.ty*e.d+e.ty,this._worldID++},e.prototype.setFromMatrix=function(t){t.decompose(this)},a(e,[{key:"rotation",get:function(){return this._rotation},set:function(t){this._rotation=t,this._sr=Math.sin(t),this._cr=Math.cos(t)}}]),e}(l.default);r.default=c},{"../math":66,"./TransformBase":47}],47:[function(t,e,r){"use strict";function n(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var i=t("../math"),o=function(){function t(){n(this,t),this.worldTransform=new i.Matrix,this.localTransform=new i.Matrix,this._worldID=0,this._parentID=0}return t.prototype.updateLocalTransform=function(){},t.prototype.updateTransform=function(t){var e=t.worldTransform,r=this.worldTransform,n=this.localTransform;r.a=n.a*e.a+n.b*e.c,r.b=n.a*e.b+n.b*e.d,r.c=n.c*e.a+n.d*e.c,r.d=n.c*e.b+n.d*e.d,r.tx=n.tx*e.a+n.ty*e.c+e.tx,r.ty=n.tx*e.b+n.ty*e.d+e.ty,this._worldID++},t}();r.default=o,o.prototype.updateWorldTransform=o.prototype.updateTransform,o.IDENTITY=new o},{"../math":66}],48:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),u=t("../math"),h=t("./TransformBase"),l=n(h),c=function(t){function e(){i(this,e);var r=o(this,t.call(this));return r.position=new u.ObservablePoint(r.onChange,r,0,0),r.scale=new u.ObservablePoint(r.onChange,r,1,1),r.pivot=new u.ObservablePoint(r.onChange,r,0,0),r.skew=new u.ObservablePoint(r.updateSkew,r,0,0),r._rotation=0,r._sr=Math.sin(0),r._cr=Math.cos(0),r._cy=Math.cos(0),r._sy=Math.sin(0),r._nsx=Math.sin(0),r._cx=Math.cos(0),r._localID=0,r._currentLocalID=0,r}return s(e,t),e.prototype.onChange=function(){this._localID++},e.prototype.updateSkew=function(){this._cy=Math.cos(this.skew._y),this._sy=Math.sin(this.skew._y),this._nsx=Math.sin(this.skew._x),this._cx=Math.cos(this.skew._x),this._localID++},e.prototype.updateLocalTransform=function(){var t=this.localTransform;if(this._localID!==this._currentLocalID){var e=this._cr*this.scale._x,r=this._sr*this.scale._x,n=-this._sr*this.scale._y,i=this._cr*this.scale._y;t.a=this._cy*e+this._sy*n,t.b=this._cy*r+this._sy*i,t.c=this._nsx*e+this._cx*n,t.d=this._nsx*r+this._cx*i,t.tx=this.position._x-(this.pivot._x*t.a+this.pivot._y*t.c),t.ty=this.position._y-(this.pivot._x*t.b+this.pivot._y*t.d),this._currentLocalID=this._localID,this._parentID=-1}},e.prototype.updateTransform=function(t){var e=t.worldTransform,r=this.worldTransform,n=this.localTransform;if(this._localID!==this._currentLocalID){var i=this._cr*this.scale._x,o=this._sr*this.scale._x,s=-this._sr*this.scale._y,a=this._cr*this.scale._y;n.a=this._cy*i+this._sy*s,n.b=this._cy*o+this._sy*a,n.c=this._nsx*i+this._cx*s,n.d=this._nsx*o+this._cx*a,n.tx=this.position._x-(this.pivot._x*n.a+this.pivot._y*n.c),n.ty=this.position._y-(this.pivot._x*n.b+this.pivot._y*n.d),this._currentLocalID=this._localID,this._parentID=-1}this._parentID!==t._worldID&&(r.a=n.a*e.a+n.b*e.c,r.b=n.a*e.b+n.b*e.d,r.c=n.c*e.a+n.d*e.c,r.d=n.c*e.b+n.d*e.d,r.tx=n.tx*e.a+n.ty*e.c+e.tx,r.ty=n.tx*e.b+n.ty*e.d+e.ty,this._parentID=t._worldID,this._worldID++)},e.prototype.setFromMatrix=function(t){t.decompose(this),this._localID++},a(e,[{key:"rotation",get:function(){return this._rotation},set:function(t){this._rotation=t,this._sr=Math.sin(t),this._cr=Math.cos(t),this._localID++}}]),e}(l.default);r.default=c},{"../math":66,"./TransformBase":47}],49:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("../display/Container"),u=n(a),h=t("../textures/RenderTexture"),l=n(h),c=t("../textures/Texture"),d=n(c),f=t("./GraphicsData"),p=n(f),v=t("../sprites/Sprite"),y=n(v),g=t("../math"),m=t("../utils"),_=t("../const"),b=t("../display/Bounds"),x=n(b),T=t("./utils/bezierCurveTo"),w=n(T),E=t("../renderers/canvas/CanvasRenderer"),O=n(E),S=void 0,M=new g.Matrix,P=new g.Point,C=new Float32Array(4),R=new Float32Array(4),D=function(t){function e(){i(this,e);var r=o(this,t.call(this));return r.fillAlpha=1,r.lineWidth=0,r.lineColor=0,r.graphicsData=[],r.tint=16777215,r._prevTint=16777215,r.blendMode=_.BLEND_MODES.NORMAL,r.currentPath=null,r._webGL={},r.isMask=!1,r.boundsPadding=0,r._localBounds=new x.default,r.dirty=0,r.fastRectDirty=-1,r.clearDirty=0,r.boundsDirty=-1,r.cachedSpriteDirty=!1,r._spriteRect=null,r._fastRect=!1,r}return s(e,t),e.prototype.clone=function t(){var t=new e;t.renderable=this.renderable,t.fillAlpha=this.fillAlpha,t.lineWidth=this.lineWidth,t.lineColor=this.lineColor,t.tint=this.tint,t.blendMode=this.blendMode,t.isMask=this.isMask,t.boundsPadding=this.boundsPadding,t.dirty=0,t.cachedSpriteDirty=this.cachedSpriteDirty;for(var r=0;r<this.graphicsData.length;++r)t.graphicsData.push(this.graphicsData[r].clone());return t.currentPath=t.graphicsData[t.graphicsData.length-1],t.updateLocalBounds(),t},e.prototype.lineStyle=function(){var t=arguments.length<=0||void 0===arguments[0]?0:arguments[0],e=arguments.length<=1||void 0===arguments[1]?0:arguments[1],r=arguments.length<=2||void 0===arguments[2]?1:arguments[2];if(this.lineWidth=t,this.lineColor=e,this.lineAlpha=r,this.currentPath)if(this.currentPath.shape.points.length){var n=new g.Polygon(this.currentPath.shape.points.slice(-2));n.closed=!1,this.drawShape(n)}else this.currentPath.lineWidth=this.lineWidth,this.currentPath.lineColor=this.lineColor,this.currentPath.lineAlpha=this.lineAlpha;return this},e.prototype.moveTo=function(t,e){var r=new g.Polygon([t,e]);return r.closed=!1,this.drawShape(r),this},e.prototype.lineTo=function(t,e){return this.currentPath.shape.points.push(t,e),this.dirty++,this},e.prototype.quadraticCurveTo=function(t,e,r,n){this.currentPath?0===this.currentPath.shape.points.length&&(this.currentPath.shape.points=[0,0]):this.moveTo(0,0);var i=20,o=this.currentPath.shape.points,s=0,a=0;0===o.length&&this.moveTo(0,0);for(var u=o[o.length-2],h=o[o.length-1],l=1;l<=i;++l){var c=l/i;s=u+(t-u)*c,a=h+(e-h)*c,o.push(s+(t+(r-t)*c-s)*c,a+(e+(n-e)*c-a)*c)}return this.dirty++,this},e.prototype.bezierCurveTo=function(t,e,r,n,i,o){this.currentPath?0===this.currentPath.shape.points.length&&(this.currentPath.shape.points=[0,0]):this.moveTo(0,0);var s=this.currentPath.shape.points,a=s[s.length-2],u=s[s.length-1];return s.length-=2,(0,w.default)(a,u,t,e,r,n,i,o,s),this.dirty++,this},e.prototype.arcTo=function(t,e,r,n,i){this.currentPath?0===this.currentPath.shape.points.length&&this.currentPath.shape.points.push(t,e):this.moveTo(t,e);var o=this.currentPath.shape.points,s=o[o.length-2],a=o[o.length-1],u=a-e,h=s-t,l=n-e,c=r-t,d=Math.abs(u*c-h*l);if(d<1e-8||0===i)o[o.length-2]===t&&o[o.length-1]===e||o.push(t,e);else{var f=u*u+h*h,p=l*l+c*c,v=u*l+h*c,y=i*Math.sqrt(f)/d,g=i*Math.sqrt(p)/d,m=y*v/f,_=g*v/p,b=y*c+g*h,x=y*l+g*u,T=h*(g+m),w=u*(g+m),E=c*(y+_),O=l*(y+_),S=Math.atan2(w-x,T-b),M=Math.atan2(O-x,E-b);this.arc(b+t,x+e,i,S,M,h*l>c*u)}return this.dirty++,this},e.prototype.arc=function(t,e,r,n,i){var o=!(arguments.length<=5||void 0===arguments[5])&&arguments[5];if(n===i)return this;!o&&i<=n?i+=2*Math.PI:o&&n<=i&&(n+=2*Math.PI);var s=i-n,a=40*Math.ceil(Math.abs(s)/(2*Math.PI));if(0===s)return this;var u=t+Math.cos(n)*r,h=e+Math.sin(n)*r,l=this.currentPath.shape.points;this.currentPath?l[l.length-2]===u&&l[l.length-1]===h||l.push(u,h):this.moveTo(u,h);for(var c=s/(2*a),d=2*c,f=Math.cos(c),p=Math.sin(c),v=a-1,y=v%1/v,g=0;g<=v;++g){var m=g+y*g,_=c+n+d*m,b=Math.cos(_),x=-Math.sin(_);l.push((f*b+p*x)*r+t,(f*-x+p*b)*r+e)}return this.dirty++,this},e.prototype.beginFill=function(){var t=arguments.length<=0||void 0===arguments[0]?0:arguments[0],e=arguments.length<=1||void 0===arguments[1]?1:arguments[1];return this.filling=!0,this.fillColor=t,this.fillAlpha=e,this.currentPath&&this.currentPath.shape.points.length<=2&&(this.currentPath.fill=this.filling,this.currentPath.fillColor=this.fillColor,
this.currentPath.fillAlpha=this.fillAlpha),this},e.prototype.endFill=function(){return this.filling=!1,this.fillColor=null,this.fillAlpha=1,this},e.prototype.drawRect=function(t,e,r,n){return this.drawShape(new g.Rectangle(t,e,r,n)),this},e.prototype.drawRoundedRect=function(t,e,r,n,i){return this.drawShape(new g.RoundedRectangle(t,e,r,n,i)),this},e.prototype.drawCircle=function(t,e,r){return this.drawShape(new g.Circle(t,e,r)),this},e.prototype.drawEllipse=function(t,e,r,n){return this.drawShape(new g.Ellipse(t,e,r,n)),this},e.prototype.drawPolygon=function(t){var e=t,r=!0;if(e instanceof g.Polygon&&(r=e.closed,e=e.points),!Array.isArray(e)){e=new Array(arguments.length);for(var n=0;n<e.length;++n)e[n]=arguments[n]}var i=new g.Polygon(e);return i.closed=r,this.drawShape(i),this},e.prototype.clear=function(){return(this.lineWidth||this.filling||this.graphicsData.length>0)&&(this.lineWidth=0,this.filling=!1,this.dirty++,this.clearDirty++,this.graphicsData.length=0),this},e.prototype.isFastRect=function(){return 1===this.graphicsData.length&&this.graphicsData[0].shape.type===_.SHAPES.RECT&&!this.graphicsData[0].lineWidth},e.prototype._renderWebGL=function(t){this.dirty!==this.fastRectDirty&&(this.fastRectDirty=this.dirty,this._fastRect=this.isFastRect()),this._fastRect?this._renderSpriteRect(t):(t.setObjectRenderer(t.plugins.graphics),t.plugins.graphics.render(this))},e.prototype._renderSpriteRect=function(t){var r=this.graphicsData[0].shape;if(!this._spriteRect){if(!e._SPRITE_TEXTURE){e._SPRITE_TEXTURE=l.default.create(10,10);var n=document.createElement("canvas");n.width=10,n.height=10;var i=n.getContext("2d");i.fillStyle="white",i.fillRect(0,0,10,10),e._SPRITE_TEXTURE=d.default.fromCanvas(n)}this._spriteRect=new y.default(e._SPRITE_TEXTURE)}if(16777215===this.tint)this._spriteRect.tint=this.graphicsData[0].fillColor;else{var o=C,s=R;(0,m.hex2rgb)(this.graphicsData[0].fillColor,o),(0,m.hex2rgb)(this.tint,s),o[0]*=s[0],o[1]*=s[1],o[2]*=s[2],this._spriteRect.tint=(0,m.rgb2hex)(o)}this._spriteRect.alpha=this.graphicsData[0].fillAlpha,this._spriteRect.worldAlpha=this.worldAlpha*this._spriteRect.alpha,e._SPRITE_TEXTURE._frame.width=r.width,e._SPRITE_TEXTURE._frame.height=r.height,this._spriteRect.transform.worldTransform=this.transform.worldTransform,this._spriteRect.anchor.set(-r.x/r.width,-r.y/r.height),this._spriteRect._onAnchorUpdate(),this._spriteRect._renderWebGL(t)},e.prototype._renderCanvas=function(t){this.isMask!==!0&&t.plugins.graphics.render(this)},e.prototype._calculateBounds=function(){this.boundsDirty!==this.dirty&&(this.boundsDirty=this.dirty,this.updateLocalBounds(),this.dirty++,this.cachedSpriteDirty=!0);var t=this._localBounds;this._bounds.addFrame(this.transform,t.minX,t.minY,t.maxX,t.maxY)},e.prototype.containsPoint=function(t){this.worldTransform.applyInverse(t,P);for(var e=this.graphicsData,r=0;r<e.length;++r){var n=e[r];if(n.fill&&n.shape&&n.shape.contains(P.x,P.y))return!0}return!1},e.prototype.updateLocalBounds=function(){var t=1/0,e=-(1/0),r=1/0,n=-(1/0);if(this.graphicsData.length)for(var i=0,o=0,s=0,a=0,u=0,h=0;h<this.graphicsData.length;h++){var l=this.graphicsData[h],c=l.type,d=l.lineWidth;if(i=l.shape,c===_.SHAPES.RECT||c===_.SHAPES.RREC)o=i.x-d/2,s=i.y-d/2,a=i.width+d,u=i.height+d,t=o<t?o:t,e=o+a>e?o+a:e,r=s<r?s:r,n=s+u>n?s+u:n;else if(c===_.SHAPES.CIRC)o=i.x,s=i.y,a=i.radius+d/2,u=i.radius+d/2,t=o-a<t?o-a:t,e=o+a>e?o+a:e,r=s-u<r?s-u:r,n=s+u>n?s+u:n;else if(c===_.SHAPES.ELIP)o=i.x,s=i.y,a=i.width+d/2,u=i.height+d/2,t=o-a<t?o-a:t,e=o+a>e?o+a:e,r=s-u<r?s-u:r,n=s+u>n?s+u:n;else for(var f=i.points,p=0,v=0,y=0,g=0,m=0,b=0,x=0,T=0,w=0;w+2<f.length;w+=2)o=f[w],s=f[w+1],p=f[w+2],v=f[w+3],y=Math.abs(p-o),g=Math.abs(v-s),u=d,a=Math.sqrt(y*y+g*g),a<1e-9||(m=(u/a*g+y)/2,b=(u/a*y+g)/2,x=(p+o)/2,T=(v+s)/2,t=x-m<t?x-m:t,e=x+m>e?x+m:e,r=T-b<r?T-b:r,n=T+b>n?T+b:n)}else t=0,e=0,r=0,n=0;var E=this.boundsPadding;this._localBounds.minX=t-E,this._localBounds.maxX=e+2*E,this._localBounds.minY=r-E,this._localBounds.maxY=n+2*E},e.prototype.drawShape=function(t){this.currentPath&&this.currentPath.shape.points.length<=2&&this.graphicsData.pop(),this.currentPath=null;var e=new p.default(this.lineWidth,this.lineColor,this.lineAlpha,this.fillColor,this.fillAlpha,this.filling,t);return this.graphicsData.push(e),e.type===_.SHAPES.POLY&&(e.shape.closed=e.shape.closed||this.filling,this.currentPath=e),this.dirty++,e},e.prototype.generateCanvasTexture=function(t){var e=arguments.length<=1||void 0===arguments[1]?1:arguments[1],r=this.getLocalBounds(),n=l.default.create(r.width,r.height,t,e);S||(S=new O.default),M.tx=-r.x,M.ty=-r.y,S.render(this,n,!1,M);var i=d.default.fromCanvas(n.baseTexture._canvasRenderTarget.canvas,t);return i.baseTexture.resolution=e,i.baseTexture.update(),i},e.prototype.closePath=function(){var t=this.currentPath;return t&&t.shape&&t.shape.close(),this},e.prototype.addHole=function(){var t=this.graphicsData.pop();return this.currentPath=this.graphicsData[this.graphicsData.length-1],this.currentPath.addHole(t.shape),this.currentPath=null,this},e.prototype.destroy=function(e){t.prototype.destroy.call(this,e);for(var r=0;r<this.graphicsData.length;++r)this.graphicsData[r].destroy();for(var n in this._webgl)for(var i=0;i<this._webgl[n].data.length;++i)this._webgl[n].data[i].destroy();this._spriteRect&&this._spriteRect.destroy(),this.graphicsData=null,this.currentPath=null,this._webgl=null,this._localBounds=null},e}(u.default);r.default=D,D._SPRITE_TEXTURE=null},{"../const":42,"../display/Bounds":43,"../display/Container":44,"../math":66,"../renderers/canvas/CanvasRenderer":73,"../sprites/Sprite":98,"../textures/RenderTexture":108,"../textures/Texture":109,"../utils":117,"./GraphicsData":50,"./utils/bezierCurveTo":52}],50:[function(t,e,r){"use strict";function n(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var i=function(){function t(e,r,i,o,s,a,u){n(this,t),this.lineWidth=e,this.lineColor=r,this.lineAlpha=i,this._lineTint=r,this.fillColor=o,this.fillAlpha=s,this._fillTint=o,this.fill=a,this.holes=[],this.shape=u,this.type=u.type}return t.prototype.clone=function(){return new t(this.lineWidth,this.lineColor,this.lineAlpha,this.fillColor,this.fillAlpha,this.fill,this.shape)},t.prototype.addHole=function(t){this.holes.push(t)},t.prototype.destroy=function(){this.shape=null,this.holes=null},t}();r.default=i},{}],51:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=t("../../renderers/canvas/CanvasRenderer"),s=n(o),a=t("../../const"),u=function(){function t(e){i(this,t),this.renderer=e}return t.prototype.render=function(t){var e=this.renderer,r=e.context,n=t.worldAlpha,i=t.transform.worldTransform,o=e.resolution;this._prevTint!==this.tint&&(this.dirty=!0),r.setTransform(i.a*o,i.b*o,i.c*o,i.d*o,i.tx*o,i.ty*o),t.dirty&&(this.updateGraphicsTint(t),t.dirty=!1),e.setBlendMode(t.blendMode);for(var s=0;s<t.graphicsData.length;s++){var u=t.graphicsData[s],h=u.shape,l=u._fillTint,c=u._lineTint;if(r.lineWidth=u.lineWidth,u.type===a.SHAPES.POLY){r.beginPath(),this.renderPolygon(h.points,h.closed,r);for(var d=0;d<u.holes.length;d++)this.renderPolygon(u.holes[d].points,!0,r);u.fill&&(r.globalAlpha=u.fillAlpha*n,r.fillStyle="#"+("00000"+(0|l).toString(16)).substr(-6),r.fill()),u.lineWidth&&(r.globalAlpha=u.lineAlpha*n,r.strokeStyle="#"+("00000"+(0|c).toString(16)).substr(-6),r.stroke())}else if(u.type===a.SHAPES.RECT)(u.fillColor||0===u.fillColor)&&(r.globalAlpha=u.fillAlpha*n,r.fillStyle="#"+("00000"+(0|l).toString(16)).substr(-6),r.fillRect(h.x,h.y,h.width,h.height)),u.lineWidth&&(r.globalAlpha=u.lineAlpha*n,r.strokeStyle="#"+("00000"+(0|c).toString(16)).substr(-6),r.strokeRect(h.x,h.y,h.width,h.height));else if(u.type===a.SHAPES.CIRC)r.beginPath(),r.arc(h.x,h.y,h.radius,0,2*Math.PI),r.closePath(),u.fill&&(r.globalAlpha=u.fillAlpha*n,r.fillStyle="#"+("00000"+(0|l).toString(16)).substr(-6),r.fill()),u.lineWidth&&(r.globalAlpha=u.lineAlpha*n,r.strokeStyle="#"+("00000"+(0|c).toString(16)).substr(-6),r.stroke());else if(u.type===a.SHAPES.ELIP){var f=2*h.width,p=2*h.height,v=h.x-f/2,y=h.y-p/2;r.beginPath();var g=.5522848,m=f/2*g,_=p/2*g,b=v+f,x=y+p,T=v+f/2,w=y+p/2;r.moveTo(v,w),r.bezierCurveTo(v,w-_,T-m,y,T,y),r.bezierCurveTo(T+m,y,b,w-_,b,w),r.bezierCurveTo(b,w+_,T+m,x,T,x),r.bezierCurveTo(T-m,x,v,w+_,v,w),r.closePath(),u.fill&&(r.globalAlpha=u.fillAlpha*n,r.fillStyle="#"+("00000"+(0|l).toString(16)).substr(-6),r.fill()),u.lineWidth&&(r.globalAlpha=u.lineAlpha*n,r.strokeStyle="#"+("00000"+(0|c).toString(16)).substr(-6),r.stroke())}else if(u.type===a.SHAPES.RREC){var E=h.x,O=h.y,S=h.width,M=h.height,P=h.radius,C=Math.min(S,M)/2|0;P=P>C?C:P,r.beginPath(),r.moveTo(E,O+P),r.lineTo(E,O+M-P),r.quadraticCurveTo(E,O+M,E+P,O+M),r.lineTo(E+S-P,O+M),r.quadraticCurveTo(E+S,O+M,E+S,O+M-P),r.lineTo(E+S,O+P),r.quadraticCurveTo(E+S,O,E+S-P,O),r.lineTo(E+P,O),r.quadraticCurveTo(E,O,E,O+P),r.closePath(),(u.fillColor||0===u.fillColor)&&(r.globalAlpha=u.fillAlpha*n,r.fillStyle="#"+("00000"+(0|l).toString(16)).substr(-6),r.fill()),u.lineWidth&&(r.globalAlpha=u.lineAlpha*n,r.strokeStyle="#"+("00000"+(0|c).toString(16)).substr(-6),r.stroke())}}},t.prototype.updateGraphicsTint=function(t){t._prevTint=t.tint;for(var e=(t.tint>>16&255)/255,r=(t.tint>>8&255)/255,n=(255&t.tint)/255,i=0;i<t.graphicsData.length;++i){var o=t.graphicsData[i],s=0|o.fillColor,a=0|o.lineColor;o._fillTint=((s>>16&255)/255*e*255<<16)+((s>>8&255)/255*r*255<<8)+(255&s)/255*n*255,o._lineTint=((a>>16&255)/255*e*255<<16)+((a>>8&255)/255*r*255<<8)+(255&a)/255*n*255}},t.prototype.renderPolygon=function(t,e,r){r.moveTo(t[0],t[1]);for(var n=1;n<t.length/2;++n)r.lineTo(t[2*n],t[2*n+1]);e&&r.closePath()},t.prototype.destroy=function(){this.renderer=null},t}();r.default=u,s.default.registerPlugin("graphics",u)},{"../../const":42,"../../renderers/canvas/CanvasRenderer":73}],52:[function(t,e,r){"use strict";function n(t,e,r,n,i,o,s,a){var u=arguments.length<=8||void 0===arguments[8]?[]:arguments[8],h=20,l=0,c=0,d=0,f=0,p=0;u.push(t,e);for(var v=1,y=0;v<=h;++v)y=v/h,l=1-y,c=l*l,d=c*l,f=y*y,p=f*y,u.push(d*t+3*c*y*r+3*l*f*i+p*s,d*e+3*c*y*n+3*l*f*o+p*a);return u}r.__esModule=!0,r.default=n},{}],53:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("../../utils"),u=t("../../const"),h=t("../../renderers/webgl/utils/ObjectRenderer"),l=n(h),c=t("../../renderers/webgl/WebGLRenderer"),d=n(c),f=t("./WebGLGraphicsData"),p=n(f),v=t("./shaders/PrimitiveShader"),y=n(v),g=t("./utils/buildPoly"),m=n(g),_=t("./utils/buildRectangle"),b=n(_),x=t("./utils/buildRoundedRectangle"),T=n(x),w=t("./utils/buildCircle"),E=n(w),O=function(t){function e(r){i(this,e);var n=o(this,t.call(this,r));return n.graphicsDataPool=[],n.primitiveShader=null,n.gl=r.gl,n.CONTEXT_UID=0,n}return s(e,t),e.prototype.onContextChange=function(){this.gl=this.renderer.gl,this.CONTEXT_UID=this.renderer.CONTEXT_UID,this.primitiveShader=new y.default(this.gl)},e.prototype.destroy=function(){l.default.prototype.destroy.call(this);for(var t=0;t<this.graphicsDataPool.length;++t)this.graphicsDataPool[t].destroy();this.graphicsDataPool=null},e.prototype.render=function(t){var e=this.renderer,r=e.gl,n=void 0,i=t._webGL[this.CONTEXT_UID];i&&t.dirty===i.dirty||(this.updateGraphics(t),i=t._webGL[this.CONTEXT_UID]);var o=this.primitiveShader;e.bindShader(o),e.state.setBlendMode(t.blendMode);for(var s=0,u=i.data.length;s<u;s++){n=i.data[s];var h=n.shader;e.bindShader(h),h.uniforms.translationMatrix=t.transform.worldTransform.toArray(!0),h.uniforms.tint=(0,a.hex2rgb)(t.tint),h.uniforms.alpha=t.worldAlpha,e.bindVao(n.vao),n.vao.draw(r.TRIANGLE_STRIP,n.indices.length)}},e.prototype.updateGraphics=function(t){var e=this.renderer.gl,r=t._webGL[this.CONTEXT_UID];if(r||(r=t._webGL[this.CONTEXT_UID]={lastIndex:0,data:[],gl:e,clearDirty:-1,dirty:-1}),r.dirty=t.dirty,t.clearDirty!==r.clearDirty){r.clearDirty=t.clearDirty;for(var n=0;n<r.data.length;n++)this.graphicsDataPool.push(r.data[n]);r.data.length=0,r.lastIndex=0}for(var i=void 0,o=r.lastIndex;o<t.graphicsData.length;o++){var s=t.graphicsData[o];i=this.getWebGLData(r,0),s.type===u.SHAPES.POLY&&(0,m.default)(s,i),s.type===u.SHAPES.RECT?(0,b.default)(s,i):s.type===u.SHAPES.CIRC||s.type===u.SHAPES.ELIP?(0,E.default)(s,i):s.type===u.SHAPES.RREC&&(0,T.default)(s,i),r.lastIndex++}this.renderer.bindVao(null);for(var a=0;a<r.data.length;a++)i=r.data[a],i.dirty&&i.upload()},e.prototype.getWebGLData=function(t,e){var r=t.data[t.data.length-1];return(!r||r.points.length>32e4)&&(r=this.graphicsDataPool.pop()||new p.default(this.renderer.gl,this.primitiveShader,this.renderer.state.attribsState),r.reset(e),t.data.push(r)),r.dirty=!0,r},e}(l.default);r.default=O,d.default.registerPlugin("graphics",O)},{"../../const":42,"../../renderers/webgl/WebGLRenderer":80,"../../renderers/webgl/utils/ObjectRenderer":90,"../../utils":117,"./WebGLGraphicsData":54,"./shaders/PrimitiveShader":55,"./utils/buildCircle":56,"./utils/buildPoly":58,"./utils/buildRectangle":59,"./utils/buildRoundedRectangle":60}],54:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=t("pixi-gl-core"),s=n(o),a=function(){function t(e,r,n){i(this,t),this.gl=e,this.color=[0,0,0],this.points=[],this.indices=[],this.buffer=s.default.GLBuffer.createVertexBuffer(e),this.indexBuffer=s.default.GLBuffer.createIndexBuffer(e),this.dirty=!0,this.glPoints=null,this.glIndices=null,this.shader=r,this.vao=new s.default.VertexArrayObject(e,n).addIndex(this.indexBuffer).addAttribute(this.buffer,r.attributes.aVertexPosition,e.FLOAT,!1,24,0).addAttribute(this.buffer,r.attributes.aColor,e.FLOAT,!1,24,8)}return t.prototype.reset=function(){this.points.length=0,this.indices.length=0},t.prototype.upload=function(){this.glPoints=new Float32Array(this.points),this.buffer.upload(this.glPoints),this.glIndices=new Uint16Array(this.indices),this.indexBuffer.upload(this.glIndices),this.dirty=!1},t.prototype.destroy=function(){this.color=null,this.points=null,this.indices=null,this.vao.destroy(),this.buffer.destroy(),this.indexBuffer.destroy(),this.gl=null,this.buffer=null,this.indexBuffer=null,this.glPoints=null,this.glIndices=null},t}();r.default=a},{"pixi-gl-core":12}],55:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("../../../Shader"),u=n(a),h=function(t){function e(r){return i(this,e),o(this,t.call(this,r,["attribute vec2 aVertexPosition;","attribute vec4 aColor;","uniform mat3 translationMatrix;","uniform mat3 projectionMatrix;","uniform float alpha;","uniform vec3 tint;","varying vec4 vColor;","void main(void){","   gl_Position = vec4((projectionMatrix * translationMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);","   vColor = aColor * vec4(tint * alpha, alpha);","}"].join("\n"),["varying vec4 vColor;","void main(void){","   gl_FragColor = vColor;","}"].join("\n")))}return s(e,t),e}(u.default);r.default=h},{"../../../Shader":41}],56:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){var r=t.shape,n=r.x,i=r.y,o=void 0,h=void 0;t.type===a.SHAPES.CIRC?(o=r.radius,h=r.radius):(o=r.width,h=r.height);var l=Math.floor(30*Math.sqrt(r.radius))||Math.floor(15*Math.sqrt(r.width+r.height)),c=2*Math.PI/l;if(t.fill){var d=(0,u.hex2rgb)(t.fillColor),f=t.fillAlpha,p=d[0]*f,v=d[1]*f,y=d[2]*f,g=e.points,m=e.indices,_=g.length/6;m.push(_);for(var b=0;b<l+1;b++)g.push(n,i,p,v,y,f),g.push(n+Math.sin(c*b)*o,i+Math.cos(c*b)*h,p,v,y,f),m.push(_++,_++);m.push(_-1)}if(t.lineWidth){var x=t.points;t.points=[];for(var T=0;T<l+1;T++)t.points.push(n+Math.sin(c*T)*o,i+Math.cos(c*T)*h);(0,s.default)(t,e),t.points=x}}r.__esModule=!0,r.default=i;var o=t("./buildLine"),s=n(o),a=t("../../../const"),u=t("../../../utils")},{"../../../const":42,"../../../utils":117,"./buildLine":57}],57:[function(t,e,r){"use strict";function n(t,e){var r=t.points;if(0!==r.length){var n=new i.Point(r[0],r[1]),s=new i.Point(r[r.length-2],r[r.length-1]);if(n.x===s.x&&n.y===s.y){r=r.slice(),r.pop(),r.pop(),s=new i.Point(r[r.length-2],r[r.length-1]);var a=s.x+.5*(n.x-s.x),u=s.y+.5*(n.y-s.y);r.unshift(a,u),r.push(a,u)}var h=e.points,l=e.indices,c=r.length/2,d=r.length,f=h.length/6,p=t.lineWidth/2,v=(0,o.hex2rgb)(t.lineColor),y=t.lineAlpha,g=v[0]*y,m=v[1]*y,_=v[2]*y,b=r[0],x=r[1],T=r[2],w=r[3],E=0,O=0,S=-(x-w),M=b-T,P=0,C=0,R=0,D=0,A=Math.sqrt(S*S+M*M);S/=A,M/=A,S*=p,M*=p,h.push(b-S,x-M,g,m,_,y),h.push(b+S,x+M,g,m,_,y);for(var I=1;I<c-1;++I){b=r[2*(I-1)],x=r[2*(I-1)+1],T=r[2*I],w=r[2*I+1],E=r[2*(I+1)],O=r[2*(I+1)+1],S=-(x-w),M=b-T,A=Math.sqrt(S*S+M*M),S/=A,M/=A,S*=p,M*=p,P=-(w-O),C=T-E,A=Math.sqrt(P*P+C*C),P/=A,C/=A,P*=p,C*=p;var L=-M+x-(-M+w),j=-S+T-(-S+b),B=(-S+b)*(-M+w)-(-S+T)*(-M+x),F=-C+O-(-C+w),N=-P+T-(-P+E),k=(-P+E)*(-C+w)-(-P+T)*(-C+O),U=L*N-F*j;if(Math.abs(U)<.1)U+=10.1,h.push(T-S,w-M,g,m,_,y),h.push(T+S,w+M,g,m,_,y);else{var X=(j*k-N*B)/U,W=(F*B-L*k)/U,G=(X-T)*(X-T)+(W-w)*(W-w);G>196*p*p?(R=S-P,D=M-C,A=Math.sqrt(R*R+D*D),R/=A,D/=A,R*=p,D*=p,h.push(T-R,w-D),h.push(g,m,_,y),h.push(T+R,w+D),h.push(g,m,_,y),h.push(T-R,w-D),h.push(g,m,_,y),d++):(h.push(X,W),h.push(g,m,_,y),h.push(T-(X-T),w-(W-w)),h.push(g,m,_,y))}}b=r[2*(c-2)],x=r[2*(c-2)+1],T=r[2*(c-1)],w=r[2*(c-1)+1],S=-(x-w),M=b-T,A=Math.sqrt(S*S+M*M),S/=A,M/=A,S*=p,M*=p,h.push(T-S,w-M),h.push(g,m,_,y),h.push(T+S,w+M),h.push(g,m,_,y),l.push(f);for(var H=0;H<d;++H)l.push(f++);l.push(f-1)}}r.__esModule=!0,r.default=n;var i=t("../../../math"),o=t("../../../utils")},{"../../../math":66,"../../../utils":117}],58:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){t.points=t.shape.points.slice();var r=t.points;if(t.fill&&r.length>=6){for(var n=[],i=t.holes,o=0;o<i.length;o++){var u=i[o];n.push(r.length/2),r=r.concat(u.points)}var l=e.points,c=e.indices,d=r.length/2,f=(0,a.hex2rgb)(t.fillColor),p=t.fillAlpha,v=f[0]*p,y=f[1]*p,g=f[2]*p,m=(0,h.default)(r,n,2);if(!m)return;for(var _=l.length/6,b=0;b<m.length;b+=3)c.push(m[b]+_),c.push(m[b]+_),c.push(m[b+1]+_),c.push(m[b+2]+_),c.push(m[b+2]+_);for(var x=0;x<d;x++)l.push(r[2*x],r[2*x+1],v,y,g,p)}t.lineWidth>0&&(0,s.default)(t,e)}r.__esModule=!0,r.default=i;var o=t("./buildLine"),s=n(o),a=t("../../../utils"),u=t("earcut"),h=n(u)},{"../../../utils":117,"./buildLine":57,earcut:2}],59:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){var r=t.shape,n=r.x,i=r.y,o=r.width,u=r.height;if(t.fill){var h=(0,a.hex2rgb)(t.fillColor),l=t.fillAlpha,c=h[0]*l,d=h[1]*l,f=h[2]*l,p=e.points,v=e.indices,y=p.length/6;p.push(n,i),p.push(c,d,f,l),p.push(n+o,i),p.push(c,d,f,l),p.push(n,i+u),p.push(c,d,f,l),p.push(n+o,i+u),p.push(c,d,f,l),v.push(y,y,y+1,y+2,y+3,y+3)}if(t.lineWidth){var g=t.points;t.points=[n,i,n+o,i,n+o,i+u,n,i+u,n,i],(0,s.default)(t,e),t.points=g}}r.__esModule=!0,r.default=i;var o=t("./buildLine"),s=n(o),a=t("../../../utils")},{"../../../utils":117,"./buildLine":57}],60:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){var r=t.shape,n=r.x,i=r.y,s=r.width,u=r.height,c=r.radius,d=[];if(d.push(n,i+c),o(n,i+u-c,n,i+u,n+c,i+u,d),o(n+s-c,i+u,n+s,i+u,n+s,i+u-c,d),o(n+s,i+c,n+s,i,n+s-c,i,d),o(n+c,i,n,i,n,i+c+1e-10,d),t.fill){for(var f=(0,l.hex2rgb)(t.fillColor),p=t.fillAlpha,v=f[0]*p,y=f[1]*p,g=f[2]*p,m=e.points,_=e.indices,b=m.length/6,x=(0,a.default)(d,null,2),T=0,w=x.length;T<w;T+=3)_.push(x[T]+b),_.push(x[T]+b),_.push(x[T+1]+b),_.push(x[T+2]+b),_.push(x[T+2]+b);for(var E=0,O=d.length;E<O;E++)m.push(d[E],d[++E],v,y,g,p)}if(t.lineWidth){var S=t.points;t.points=d,(0,h.default)(t,e),t.points=S}}function o(t,e,r,n,i,o){function s(t,e,r){var n=e-t;return t+n*r}for(var a=arguments.length<=6||void 0===arguments[6]?[]:arguments[6],u=20,h=a,l=0,c=0,d=0,f=0,p=0,v=0,y=0,g=0;y<=u;++y)g=y/u,l=s(t,r,g),c=s(e,n,g),d=s(r,i,g),f=s(n,o,g),p=s(l,d,g),v=s(c,f,g),h.push(p,v);return h}r.__esModule=!0,r.default=i;var s=t("earcut"),a=n(s),u=t("./buildLine"),h=n(u),l=t("../../../utils")},{"../../../utils":117,"./buildLine":57,earcut:2}],61:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t){return t&&t.__esModule?t:{default:t}}function o(){var t=arguments.length<=0||void 0===arguments[0]?800:arguments[0],e=arguments.length<=1||void 0===arguments[1]?600:arguments[1],r=arguments[2],n=arguments[3];return!n&&k.isWebGLSupported()?new z.default(t,e,r):new V.default(t,e,r)}r.__esModule=!0,r.Filter=r.SpriteMaskFilter=r.Quad=r.RenderTarget=r.ObjectRenderer=r.WebGLManager=r.Shader=r.CanvasRenderTarget=r.TextureUvs=r.VideoBaseTexture=r.BaseRenderTexture=r.RenderTexture=r.BaseTexture=r.Texture=r.CanvasGraphicsRenderer=r.GraphicsRenderer=r.GraphicsData=r.Graphics=r.TextStyle=r.Text=r.SpriteRenderer=r.CanvasTinter=r.CanvasSpriteRenderer=r.Sprite=r.TransformBase=r.TransformStatic=r.Transform=r.Container=r.DisplayObject=r.glCore=r.WebGLRenderer=r.CanvasRenderer=r.ticker=r.utils=r.settings=void 0;var s=t("./const");Object.keys(s).forEach(function(t){"default"!==t&&"__esModule"!==t&&Object.defineProperty(r,t,{enumerable:!0,get:function(){return s[t]}})});var a=t("./math");Object.keys(a).forEach(function(t){"default"!==t&&"__esModule"!==t&&Object.defineProperty(r,t,{enumerable:!0,get:function(){return a[t]}})});var u=t("pixi-gl-core");Object.defineProperty(r,"glCore",{enumerable:!0,get:function(){return i(u).default}});var h=t("./display/DisplayObject");Object.defineProperty(r,"DisplayObject",{enumerable:!0,get:function(){return i(h).default}});var l=t("./display/Container");Object.defineProperty(r,"Container",{enumerable:!0,get:function(){return i(l).default}});var c=t("./display/Transform");Object.defineProperty(r,"Transform",{enumerable:!0,get:function(){return i(c).default}});var d=t("./display/TransformStatic");Object.defineProperty(r,"TransformStatic",{enumerable:!0,get:function(){return i(d).default}});var f=t("./display/TransformBase");Object.defineProperty(r,"TransformBase",{enumerable:!0,get:function(){return i(f).default}});var p=t("./sprites/Sprite");Object.defineProperty(r,"Sprite",{enumerable:!0,get:function(){return i(p).default}});var v=t("./sprites/canvas/CanvasSpriteRenderer");Object.defineProperty(r,"CanvasSpriteRenderer",{enumerable:!0,get:function(){return i(v).default}});var y=t("./sprites/canvas/CanvasTinter");Object.defineProperty(r,"CanvasTinter",{enumerable:!0,get:function(){return i(y).default}});var g=t("./sprites/webgl/SpriteRenderer");Object.defineProperty(r,"SpriteRenderer",{enumerable:!0,get:function(){return i(g).default}});var m=t("./text/Text");Object.defineProperty(r,"Text",{enumerable:!0,get:function(){return i(m).default}});var _=t("./text/TextStyle");Object.defineProperty(r,"TextStyle",{enumerable:!0,get:function(){return i(_).default}});var b=t("./graphics/Graphics");Object.defineProperty(r,"Graphics",{enumerable:!0,get:function(){return i(b).default}});var x=t("./graphics/GraphicsData");Object.defineProperty(r,"GraphicsData",{enumerable:!0,get:function(){return i(x).default}});var T=t("./graphics/webgl/GraphicsRenderer");Object.defineProperty(r,"GraphicsRenderer",{enumerable:!0,get:function(){return i(T).default}});var w=t("./graphics/canvas/CanvasGraphicsRenderer");Object.defineProperty(r,"CanvasGraphicsRenderer",{enumerable:!0,get:function(){return i(w).default}});var E=t("./textures/Texture");Object.defineProperty(r,"Texture",{enumerable:!0,get:function(){return i(E).default}});var O=t("./textures/BaseTexture");Object.defineProperty(r,"BaseTexture",{enumerable:!0,get:function(){return i(O).default}});var S=t("./textures/RenderTexture");Object.defineProperty(r,"RenderTexture",{enumerable:!0,get:function(){return i(S).default}});var M=t("./textures/BaseRenderTexture");Object.defineProperty(r,"BaseRenderTexture",{enumerable:!0,get:function(){return i(M).default}});var P=t("./textures/VideoBaseTexture");Object.defineProperty(r,"VideoBaseTexture",{enumerable:!0,get:function(){return i(P).default}});var C=t("./textures/TextureUvs");Object.defineProperty(r,"TextureUvs",{enumerable:!0,get:function(){return i(C).default}});var R=t("./renderers/canvas/utils/CanvasRenderTarget");Object.defineProperty(r,"CanvasRenderTarget",{enumerable:!0,get:function(){return i(R).default}});var D=t("./Shader");Object.defineProperty(r,"Shader",{enumerable:!0,get:function(){return i(D).default}});var A=t("./renderers/webgl/managers/WebGLManager");Object.defineProperty(r,"WebGLManager",{enumerable:!0,get:function(){return i(A).default}});var I=t("./renderers/webgl/utils/ObjectRenderer");Object.defineProperty(r,"ObjectRenderer",{enumerable:!0,get:function(){return i(I).default}});var L=t("./renderers/webgl/utils/RenderTarget");Object.defineProperty(r,"RenderTarget",{enumerable:!0,get:function(){return i(L).default}});var j=t("./renderers/webgl/utils/Quad");Object.defineProperty(r,"Quad",{enumerable:!0,get:function(){return i(j).default}});var B=t("./renderers/webgl/filters/spriteMask/SpriteMaskFilter");Object.defineProperty(r,"SpriteMaskFilter",{enumerable:!0,get:function(){return i(B).default}});var F=t("./renderers/webgl/filters/Filter");Object.defineProperty(r,"Filter",{enumerable:!0,get:function(){return i(F).default}}),r.autoDetectRenderer=o;var N=t("./utils"),k=n(N),U=t("./ticker"),X=n(U),W=t("./settings"),G=i(W),H=t("./renderers/canvas/CanvasRenderer"),V=i(H),Y=t("./renderers/webgl/WebGLRenderer"),z=i(Y);r.settings=G.default,r.utils=k,r.ticker=X,r.CanvasRenderer=V.default,r.WebGLRenderer=z.default},{"./Shader":41,"./const":42,"./display/Container":44,"./display/DisplayObject":45,"./display/Transform":46,"./display/TransformBase":47,"./display/TransformStatic":48,"./graphics/Graphics":49,"./graphics/GraphicsData":50,"./graphics/canvas/CanvasGraphicsRenderer":51,"./graphics/webgl/GraphicsRenderer":53,"./math":66,"./renderers/canvas/CanvasRenderer":73,"./renderers/canvas/utils/CanvasRenderTarget":75,"./renderers/webgl/WebGLRenderer":80,"./renderers/webgl/filters/Filter":82,"./renderers/webgl/filters/spriteMask/SpriteMaskFilter":85,"./renderers/webgl/managers/WebGLManager":89,"./renderers/webgl/utils/ObjectRenderer":90,"./renderers/webgl/utils/Quad":91,"./renderers/webgl/utils/RenderTarget":92,"./settings":97,"./sprites/Sprite":98,"./sprites/canvas/CanvasSpriteRenderer":99,"./sprites/canvas/CanvasTinter":100,"./sprites/webgl/SpriteRenderer":102,"./text/Text":104,"./text/TextStyle":105,"./textures/BaseRenderTexture":106,"./textures/BaseTexture":107,"./textures/RenderTexture":108,"./textures/Texture":109,"./textures/TextureUvs":110,"./textures/VideoBaseTexture":111,"./ticker":113,"./utils":117,"pixi-gl-core":12}],62:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t){return t<0?-1:t>0?1:0}function o(){for(var t=0;t<16;t++){var e=[];f.push(e);for(var r=0;r<16;r++)for(var n=i(u[t]*u[r]+l[t]*h[r]),o=i(h[t]*u[r]+c[t]*h[r]),s=i(u[t]*l[r]+l[t]*c[r]),p=i(h[t]*l[r]+c[t]*c[r]),v=0;v<16;v++)if(u[v]===n&&h[v]===o&&l[v]===s&&c[v]===p){e.push(v);break}}for(var y=0;y<16;y++){var g=new a.default;g.set(u[y],h[y],l[y],c[y],0,0),d.push(g)}}r.__esModule=!0;var s=t("./Matrix"),a=n(s),u=[1,1,0,-1,-1,-1,0,1,1,1,0,-1,-1,-1,0,1],h=[0,1,1,1,0,-1,-1,-1,0,1,1,1,0,-1,-1,-1],l=[0,-1,-1,-1,0,1,1,1,0,1,1,1,0,-1,-1,-1],c=[1,1,0,-1,-1,-1,0,1,-1,-1,0,1,1,1,0,-1],d=[],f=[];o();var p={E:0,SE:1,S:2,SW:3,W:4,NW:5,N:6,NE:7,MIRROR_VERTICAL:8,MIRROR_HORIZONTAL:12,uX:function(t){return u[t]},uY:function(t){return h[t]},vX:function(t){return l[t]},vY:function(t){return c[t]},inv:function(t){return 8&t?15&t:7&-t},add:function(t,e){return f[t][e]},sub:function(t,e){return f[t][p.inv(e)]},rotate180:function(t){return 4^t},isSwapWidthHeight:function(t){return 2===(3&t)},byDirection:function(t,e){return 2*Math.abs(t)<=Math.abs(e)?e>=0?p.S:p.N:2*Math.abs(e)<=Math.abs(t)?t>0?p.E:p.W:e>0?t>0?p.SE:p.SW:t>0?p.NE:p.NW},matrixAppendRotationInv:function(t,e){var r=arguments.length<=2||void 0===arguments[2]?0:arguments[2],n=arguments.length<=3||void 0===arguments[3]?0:arguments[3],i=d[p.inv(e)];i.tx=r,i.ty=n,t.append(i)}};r.default=p},{"./Matrix":63}],63:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),s=t("./Point"),a=n(s),u=function(){function t(){i(this,t),this.a=1,this.b=0,this.c=0,this.d=1,this.tx=0,this.ty=0,this.array=null}return t.prototype.fromArray=function(t){this.a=t[0],this.b=t[1],this.c=t[3],this.d=t[4],this.tx=t[2],this.ty=t[5]},t.prototype.set=function(t,e,r,n,i,o){return this.a=t,this.b=e,this.c=r,this.d=n,this.tx=i,this.ty=o,this},t.prototype.toArray=function(t,e){this.array||(this.array=new Float32Array(9));var r=e||this.array;return t?(r[0]=this.a,r[1]=this.b,r[2]=0,r[3]=this.c,r[4]=this.d,r[5]=0,r[6]=this.tx,r[7]=this.ty,r[8]=1):(r[0]=this.a,r[1]=this.c,r[2]=this.tx,r[3]=this.b,r[4]=this.d,r[5]=this.ty,r[6]=0,r[7]=0,r[8]=1),r},t.prototype.apply=function(t,e){e=e||new a.default;var r=t.x,n=t.y;return e.x=this.a*r+this.c*n+this.tx,e.y=this.b*r+this.d*n+this.ty,e},t.prototype.applyInverse=function(t,e){e=e||new a.default;var r=1/(this.a*this.d+this.c*-this.b),n=t.x,i=t.y;return e.x=this.d*r*n+-this.c*r*i+(this.ty*this.c-this.tx*this.d)*r,e.y=this.a*r*i+-this.b*r*n+(-this.ty*this.a+this.tx*this.b)*r,e},t.prototype.translate=function(t,e){return this.tx+=t,this.ty+=e,this},t.prototype.scale=function(t,e){return this.a*=t,this.d*=e,this.c*=t,this.b*=e,this.tx*=t,this.ty*=e,this},t.prototype.rotate=function(t){var e=Math.cos(t),r=Math.sin(t),n=this.a,i=this.c,o=this.tx;return this.a=n*e-this.b*r,this.b=n*r+this.b*e,this.c=i*e-this.d*r,this.d=i*r+this.d*e,this.tx=o*e-this.ty*r,this.ty=o*r+this.ty*e,this},t.prototype.append=function(t){var e=this.a,r=this.b,n=this.c,i=this.d;return this.a=t.a*e+t.b*n,this.b=t.a*r+t.b*i,this.c=t.c*e+t.d*n,this.d=t.c*r+t.d*i,this.tx=t.tx*e+t.ty*n+this.tx,this.ty=t.tx*r+t.ty*i+this.ty,this},t.prototype.setTransform=function(t,e,r,n,i,o,s,a,u){var h=Math.sin(s),l=Math.cos(s),c=Math.cos(u),d=Math.sin(u),f=-Math.sin(a),p=Math.cos(a),v=l*i,y=h*i,g=-h*o,m=l*o;return this.a=c*v+d*g,this.b=c*y+d*m,this.c=f*v+p*g,this.d=f*y+p*m,this.tx=t+(r*v+n*g),this.ty=e+(r*y+n*m),this},t.prototype.prepend=function(t){var e=this.tx;if(1!==t.a||0!==t.b||0!==t.c||1!==t.d){var r=this.a,n=this.c;
this.a=r*t.a+this.b*t.c,this.b=r*t.b+this.b*t.d,this.c=n*t.a+this.d*t.c,this.d=n*t.b+this.d*t.d}return this.tx=e*t.a+this.ty*t.c+t.tx,this.ty=e*t.b+this.ty*t.d+t.ty,this},t.prototype.decompose=function(t){var e=this.a,r=this.b,n=this.c,i=this.d,o=Math.atan2(-n,i),s=Math.atan2(r,e),a=Math.abs(1-o/s);return a<1e-5?(t.rotation=s,e<0&&i>=0&&(t.rotation+=t.rotation<=0?Math.PI:-Math.PI),t.skew.x=t.skew.y=0):(t.skew.x=o,t.skew.y=s),t.scale.x=Math.sqrt(e*e+r*r),t.scale.y=Math.sqrt(n*n+i*i),t.position.x=this.tx,t.position.y=this.ty,t},t.prototype.invert=function(){var t=this.a,e=this.b,r=this.c,n=this.d,i=this.tx,o=t*n-e*r;return this.a=n/o,this.b=-e/o,this.c=-r/o,this.d=t/o,this.tx=(r*this.ty-n*i)/o,this.ty=-(t*this.ty-e*i)/o,this},t.prototype.identity=function(){return this.a=1,this.b=0,this.c=0,this.d=1,this.tx=0,this.ty=0,this},t.prototype.clone=function(){var e=new t;return e.a=this.a,e.b=this.b,e.c=this.c,e.d=this.d,e.tx=this.tx,e.ty=this.ty,e},t.prototype.copy=function(t){return t.a=this.a,t.b=this.b,t.c=this.c,t.d=this.d,t.tx=this.tx,t.ty=this.ty,t},o(t,null,[{key:"IDENTITY",get:function(){return new t}},{key:"TEMP_MATRIX",get:function(){return new t}}]),t}();r.default=u},{"./Point":65}],64:[function(t,e,r){"use strict";function n(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var i=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),o=function(){function t(e,r){var i=arguments.length<=2||void 0===arguments[2]?0:arguments[2],o=arguments.length<=3||void 0===arguments[3]?0:arguments[3];n(this,t),this._x=i,this._y=o,this.cb=e,this.scope=r}return t.prototype.set=function(t,e){var r=t||0,n=e||(0!==e?r:0);this._x===r&&this._y===n||(this._x=r,this._y=n,this.cb.call(this.scope))},t.prototype.copy=function(t){this._x===t.x&&this._y===t.y||(this._x=t.x,this._y=t.y,this.cb.call(this.scope))},i(t,[{key:"x",get:function(){return this._x},set:function(t){this._x!==t&&(this._x=t,this.cb.call(this.scope))}},{key:"y",get:function(){return this._y},set:function(t){this._y!==t&&(this._y=t,this.cb.call(this.scope))}}]),t}();r.default=o},{}],65:[function(t,e,r){"use strict";function n(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var i=function(){function t(){var e=arguments.length<=0||void 0===arguments[0]?0:arguments[0],r=arguments.length<=1||void 0===arguments[1]?0:arguments[1];n(this,t),this.x=e,this.y=r}return t.prototype.clone=function(){return new t(this.x,this.y)},t.prototype.copy=function(t){this.set(t.x,t.y)},t.prototype.equals=function(t){return t.x===this.x&&t.y===this.y},t.prototype.set=function(t,e){this.x=t||0,this.y=e||(0!==e?this.x:0)},t}();r.default=i},{}],66:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}r.__esModule=!0;var i=t("./Point");Object.defineProperty(r,"Point",{enumerable:!0,get:function(){return n(i).default}});var o=t("./ObservablePoint");Object.defineProperty(r,"ObservablePoint",{enumerable:!0,get:function(){return n(o).default}});var s=t("./Matrix");Object.defineProperty(r,"Matrix",{enumerable:!0,get:function(){return n(s).default}});var a=t("./GroupD8");Object.defineProperty(r,"GroupD8",{enumerable:!0,get:function(){return n(a).default}});var u=t("./shapes/Circle");Object.defineProperty(r,"Circle",{enumerable:!0,get:function(){return n(u).default}});var h=t("./shapes/Ellipse");Object.defineProperty(r,"Ellipse",{enumerable:!0,get:function(){return n(h).default}});var l=t("./shapes/Polygon");Object.defineProperty(r,"Polygon",{enumerable:!0,get:function(){return n(l).default}});var c=t("./shapes/Rectangle");Object.defineProperty(r,"Rectangle",{enumerable:!0,get:function(){return n(c).default}});var d=t("./shapes/RoundedRectangle");Object.defineProperty(r,"RoundedRectangle",{enumerable:!0,get:function(){return n(d).default}})},{"./GroupD8":62,"./Matrix":63,"./ObservablePoint":64,"./Point":65,"./shapes/Circle":67,"./shapes/Ellipse":68,"./shapes/Polygon":69,"./shapes/Rectangle":70,"./shapes/RoundedRectangle":71}],67:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=t("./Rectangle"),s=n(o),a=t("../../const"),u=function(){function t(){var e=arguments.length<=0||void 0===arguments[0]?0:arguments[0],r=arguments.length<=1||void 0===arguments[1]?0:arguments[1],n=arguments.length<=2||void 0===arguments[2]?0:arguments[2];i(this,t),this.x=e,this.y=r,this.radius=n,this.type=a.SHAPES.CIRC}return t.prototype.clone=function(){return new t(this.x,this.y,this.radius)},t.prototype.contains=function(t,e){if(this.radius<=0)return!1;var r=this.radius*this.radius,n=this.x-t,i=this.y-e;return n*=n,i*=i,n+i<=r},t.prototype.getBounds=function(){return new s.default(this.x-this.radius,this.y-this.radius,2*this.radius,2*this.radius)},t}();r.default=u},{"../../const":42,"./Rectangle":70}],68:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=t("./Rectangle"),s=n(o),a=t("../../const"),u=function(){function t(){var e=arguments.length<=0||void 0===arguments[0]?0:arguments[0],r=arguments.length<=1||void 0===arguments[1]?0:arguments[1],n=arguments.length<=2||void 0===arguments[2]?0:arguments[2],o=arguments.length<=3||void 0===arguments[3]?0:arguments[3];i(this,t),this.x=e,this.y=r,this.width=n,this.height=o,this.type=a.SHAPES.ELIP}return t.prototype.clone=function(){return new t(this.x,this.y,this.width,this.height)},t.prototype.contains=function(t,e){if(this.width<=0||this.height<=0)return!1;var r=(t-this.x)/this.width,n=(e-this.y)/this.height;return r*=r,n*=n,r+n<=1},t.prototype.getBounds=function(){return new s.default(this.x-this.width,this.y-this.height,this.width,this.height)},t}();r.default=u},{"../../const":42,"./Rectangle":70}],69:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=t("../Point"),s=n(o),a=t("../../const"),u=function(){function t(){for(var e=arguments.length,r=Array(e),n=0;n<e;n++)r[n]=arguments[n];if(i(this,t),Array.isArray(r[0])&&(r=r[0]),r[0]instanceof s.default){for(var o=[],u=0,h=r.length;u<h;u++)o.push(r[u].x,r[u].y);r=o}this.closed=!0,this.points=r,this.type=a.SHAPES.POLY}return t.prototype.clone=function(){return new t(this.points.slice())},t.prototype.close=function(){var t=this.points;t[0]===t[t.length-2]&&t[1]===t[t.length-1]||t.push(t[0],t[1])},t.prototype.contains=function(t,e){for(var r=!1,n=this.points.length/2,i=0,o=n-1;i<n;o=i++){var s=this.points[2*i],a=this.points[2*i+1],u=this.points[2*o],h=this.points[2*o+1],l=a>e!=h>e&&t<(u-s)*((e-a)/(h-a))+s;l&&(r=!r)}return r},t}();r.default=u},{"../../const":42,"../Point":65}],70:[function(t,e,r){"use strict";function n(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var i=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),o=t("../../const"),s=function(){function t(){var e=arguments.length<=0||void 0===arguments[0]?0:arguments[0],r=arguments.length<=1||void 0===arguments[1]?0:arguments[1],i=arguments.length<=2||void 0===arguments[2]?0:arguments[2],s=arguments.length<=3||void 0===arguments[3]?0:arguments[3];n(this,t),this.x=e,this.y=r,this.width=i,this.height=s,this.type=o.SHAPES.RECT}return t.prototype.clone=function(){return new t(this.x,this.y,this.width,this.height)},t.prototype.copy=function(t){return this.x=t.x,this.y=t.y,this.width=t.width,this.height=t.height,this},t.prototype.contains=function(t,e){return!(this.width<=0||this.height<=0)&&(t>=this.x&&t<this.x+this.width&&e>=this.y&&e<this.y+this.height)},t.prototype.pad=function(t,e){t=t||0,e=e||(0!==e?t:0),this.x-=t,this.y-=e,this.width+=2*t,this.height+=2*e},t.prototype.fit=function(t){this.x<t.x&&(this.width+=this.x,this.width<0&&(this.width=0),this.x=t.x),this.y<t.y&&(this.height+=this.y,this.height<0&&(this.height=0),this.y=t.y),this.x+this.width>t.x+t.width&&(this.width=t.width-this.x,this.width<0&&(this.width=0)),this.y+this.height>t.y+t.height&&(this.height=t.height-this.y,this.height<0&&(this.height=0))},t.prototype.enlarge=function(e){if(e!==t.EMPTY){var r=Math.min(this.x,e.x),n=Math.max(this.x+this.width,e.x+e.width),i=Math.min(this.y,e.y),o=Math.max(this.y+this.height,e.y+e.height);this.x=r,this.width=n-r,this.y=i,this.height=o-i}},i(t,[{key:"left",get:function(){return this.x}},{key:"right",get:function(){return this.x+this.width}},{key:"top",get:function(){return this.y}},{key:"bottom",get:function(){return this.y+this.height}}],[{key:"EMPTY",get:function(){return new t(0,0,0,0)}}]),t}();r.default=s},{"../../const":42}],71:[function(t,e,r){"use strict";function n(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var i=t("../../const"),o=function(){function t(){var e=arguments.length<=0||void 0===arguments[0]?0:arguments[0],r=arguments.length<=1||void 0===arguments[1]?0:arguments[1],o=arguments.length<=2||void 0===arguments[2]?0:arguments[2],s=arguments.length<=3||void 0===arguments[3]?0:arguments[3],a=arguments.length<=4||void 0===arguments[4]?20:arguments[4];n(this,t),this.x=e,this.y=r,this.width=o,this.height=s,this.radius=a,this.type=i.SHAPES.RREC}return t.prototype.clone=function(){return new t(this.x,this.y,this.width,this.height,this.radius)},t.prototype.contains=function(t,e){if(this.width<=0||this.height<=0)return!1;if(t>=this.x&&t<=this.x+this.width&&e>=this.y&&e<=this.y+this.height){if(e>=this.y+this.radius&&e<=this.y+this.height-this.radius||t>=this.x+this.radius&&t<=this.x+this.width-this.radius)return!0;var r=t-(this.x+this.radius),n=e-(this.y+this.radius),i=this.radius*this.radius;if(r*r+n*n<=i)return!0;if(r=t-(this.x+this.width-this.radius),r*r+n*n<=i)return!0;if(n=e-(this.y+this.height-this.radius),r*r+n*n<=i)return!0;if(r=t-(this.x+this.radius),r*r+n*n<=i)return!0}return!1},t}();r.default=o},{"../../const":42}],72:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),u=t("../utils"),h=t("../math"),l=t("../const"),c=t("../settings"),d=n(c),f=t("../display/Container"),p=n(f),v=t("../textures/RenderTexture"),y=n(v),g=t("eventemitter3"),m=n(g),_=new h.Matrix,b=d.default.RESOLUTION,x=d.default.RENDER_OPTIONS,T=function(t){function e(r,n,s,a){i(this,e);var h=o(this,t.call(this));if((0,u.sayHello)(r),a)for(var c in x)"undefined"==typeof a[c]&&(a[c]=x[c]);else a=x;return h.type=l.RENDERER_TYPE.UNKNOWN,h.width=n||800,h.height=s||600,h.view=a.view||document.createElement("canvas"),h.resolution=a.resolution||b,h.transparent=a.transparent,h.autoResize=a.autoResize||!1,h.blendModes=null,h.preserveDrawingBuffer=a.preserveDrawingBuffer,h.clearBeforeRender=a.clearBeforeRender,h.roundPixels=a.roundPixels,h._backgroundColor=0,h._backgroundColorRgba=[0,0,0,0],h._backgroundColorString="#000000",h.backgroundColor=a.backgroundColor||h._backgroundColor,h._tempDisplayObjectParent=new p.default,h._lastObjectRendered=h._tempDisplayObjectParent,h}return s(e,t),e.prototype.resize=function(t,e){this.width=t*this.resolution,this.height=e*this.resolution,this.view.width=this.width,this.view.height=this.height,this.autoResize&&(this.view.style.width=this.width/this.resolution+"px",this.view.style.height=this.height/this.resolution+"px")},e.prototype.generateTexture=function(t,e,r){var n=t.getLocalBounds(),i=y.default.create(0|n.width,0|n.height,e,r);return _.tx=-n.x,_.ty=-n.y,this.render(t,i,!1,_,!0),i},e.prototype.destroy=function(t){t&&this.view.parentNode&&this.view.parentNode.removeChild(this.view),this.type=l.RENDERER_TYPE.UNKNOWN,this.width=0,this.height=0,this.view=null,this.resolution=0,this.transparent=!1,this.autoResize=!1,this.blendModes=null,this.preserveDrawingBuffer=!1,this.clearBeforeRender=!1,this.roundPixels=!1,this._backgroundColor=0,this._backgroundColorRgba=null,this._backgroundColorString=null,this.backgroundColor=0,this._tempDisplayObjectParent=null,this._lastObjectRendered=null},a(e,[{key:"backgroundColor",get:function(){return this._backgroundColor},set:function(t){this._backgroundColor=t,this._backgroundColorString=(0,u.hex2string)(t),(0,u.hex2rgb)(t,this._backgroundColorRgba)}}]),e}(m.default);r.default=T},{"../const":42,"../display/Container":44,"../math":66,"../settings":97,"../textures/RenderTexture":108,"../utils":117,eventemitter3:3}],73:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("../SystemRenderer"),u=n(a),h=t("./utils/CanvasMaskManager"),l=n(h),c=t("./utils/CanvasRenderTarget"),d=n(c),f=t("./utils/mapCanvasBlendModesToPixi"),p=n(f),v=t("../../utils"),y=t("../../const"),g=t("../../settings"),m=n(g),_=function(t){function e(r,n){var s=arguments.length<=2||void 0===arguments[2]?{}:arguments[2];i(this,e);var a=o(this,t.call(this,"Canvas",r,n,s));return a.type=y.RENDERER_TYPE.CANVAS,a.rootContext=a.view.getContext("2d",{alpha:a.transparent}),a.refresh=!0,a.maskManager=new l.default(a),a.smoothProperty="imageSmoothingEnabled",a.rootContext.imageSmoothingEnabled||(a.rootContext.webkitImageSmoothingEnabled?a.smoothProperty="webkitImageSmoothingEnabled":a.rootContext.mozImageSmoothingEnabled?a.smoothProperty="mozImageSmoothingEnabled":a.rootContext.oImageSmoothingEnabled?a.smoothProperty="oImageSmoothingEnabled":a.rootContext.msImageSmoothingEnabled&&(a.smoothProperty="msImageSmoothingEnabled")),a.initPlugins(),a.blendModes=(0,p.default)(),a._activeBlendMode=null,a.context=null,a.renderingToScreen=!1,a.resize(r,n),a}return s(e,t),e.prototype.render=function(t,e,r,n,i){if(this.view){this.renderingToScreen=!e,this.emit("prerender"),e?(e=e.baseTexture||e,e._canvasRenderTarget||(e._canvasRenderTarget=new d.default(e.width,e.height,e.resolution),e.source=e._canvasRenderTarget.canvas,e.valid=!0),this.context=e._canvasRenderTarget.context,this.resolution=e._canvasRenderTarget.resolution):this.context=this.rootContext;var o=this.context;if(e||(this._lastObjectRendered=t),!i){var s=t.parent,a=this._tempDisplayObjectParent.transform.worldTransform;n?n.copy(a):a.identity(),t.parent=this._tempDisplayObjectParent,t.updateTransform(),t.parent=s}o.setTransform(1,0,0,1,0,0),o.globalAlpha=1,o.globalCompositeOperation=this.blendModes[y.BLEND_MODES.NORMAL],navigator.isCocoonJS&&this.view.screencanvas&&(o.fillStyle="black",o.clear()),(void 0!==r?r:this.clearBeforeRender)&&this.renderingToScreen&&(this.transparent?o.clearRect(0,0,this.width,this.height):(o.fillStyle=this._backgroundColorString,o.fillRect(0,0,this.width,this.height)));var u=this.context;this.context=o,t.renderCanvas(this),this.context=u,this.emit("postrender")}},e.prototype.setBlendMode=function(t){this._activeBlendMode!==t&&(this._activeBlendMode=t,this.context.globalCompositeOperation=this.blendModes[t])},e.prototype.destroy=function(e){this.destroyPlugins(),t.prototype.destroy.call(this,e),this.context=null,this.refresh=!0,this.maskManager.destroy(),this.maskManager=null,this.smoothProperty=null},e.prototype.resize=function(e,r){t.prototype.resize.call(this,e,r),this.smoothProperty&&(this.rootContext[this.smoothProperty]=m.default.SCALE_MODE===y.SCALE_MODES.LINEAR)},e}(u.default);r.default=_,v.pluginTarget.mixin(_)},{"../../const":42,"../../settings":97,"../../utils":117,"../SystemRenderer":72,"./utils/CanvasMaskManager":74,"./utils/CanvasRenderTarget":75,"./utils/mapCanvasBlendModesToPixi":77}],74:[function(t,e,r){"use strict";function n(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var i=t("../../../const"),o=function(){function t(e){n(this,t),this.renderer=e}return t.prototype.pushMask=function(t){var e=this.renderer;e.context.save();var r=t.alpha,n=t.transform.worldTransform,i=e.resolution;e.context.setTransform(n.a*i,n.b*i,n.c*i,n.d*i,n.tx*i,n.ty*i),t._texture||(this.renderGraphicsShape(t),e.context.clip()),t.worldAlpha=r},t.prototype.renderGraphicsShape=function(t){var e=this.renderer.context,r=t.graphicsData.length;if(0!==r){e.beginPath();for(var n=0;n<r;n++){var o=t.graphicsData[n],s=o.shape;if(o.type===i.SHAPES.POLY){var a=s.points;e.moveTo(a[0],a[1]);for(var u=1;u<a.length/2;u++)e.lineTo(a[2*u],a[2*u+1]);a[0]===a[a.length-2]&&a[1]===a[a.length-1]&&e.closePath()}else if(o.type===i.SHAPES.RECT)e.rect(s.x,s.y,s.width,s.height),e.closePath();else if(o.type===i.SHAPES.CIRC)e.arc(s.x,s.y,s.radius,0,2*Math.PI),e.closePath();else if(o.type===i.SHAPES.ELIP){var h=2*s.width,l=2*s.height,c=s.x-h/2,d=s.y-l/2,f=.5522848,p=h/2*f,v=l/2*f,y=c+h,g=d+l,m=c+h/2,_=d+l/2;e.moveTo(c,_),e.bezierCurveTo(c,_-v,m-p,d,m,d),e.bezierCurveTo(m+p,d,y,_-v,y,_),e.bezierCurveTo(y,_+v,m+p,g,m,g),e.bezierCurveTo(m-p,g,c,_+v,c,_),e.closePath()}else if(o.type===i.SHAPES.RREC){var b=s.x,x=s.y,T=s.width,w=s.height,E=s.radius,O=Math.min(T,w)/2|0;E=E>O?O:E,e.moveTo(b,x+E),e.lineTo(b,x+w-E),e.quadraticCurveTo(b,x+w,b+E,x+w),e.lineTo(b+T-E,x+w),e.quadraticCurveTo(b+T,x+w,b+T,x+w-E),e.lineTo(b+T,x+E),e.quadraticCurveTo(b+T,x,b+T-E,x),e.lineTo(b+E,x),e.quadraticCurveTo(b,x,b,x+E),e.closePath()}}}},t.prototype.popMask=function(t){t.context.restore()},t.prototype.destroy=function(){},t}();r.default=o},{"../../../const":42}],75:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),s=t("../../../settings"),a=n(s),u=a.default.RESOLUTION,h=function(){function t(e,r,n){i(this,t),this.canvas=document.createElement("canvas"),this.context=this.canvas.getContext("2d"),this.resolution=n||u,this.resize(e,r)}return t.prototype.clear=function(){this.context.setTransform(1,0,0,1,0,0),this.context.clearRect(0,0,this.canvas.width,this.canvas.height)},t.prototype.resize=function(t,e){this.canvas.width=t*this.resolution,this.canvas.height=e*this.resolution},t.prototype.destroy=function(){this.context=null,this.canvas=null},o(t,[{key:"width",get:function(){return this.canvas.width},set:function(t){this.canvas.width=t}},{key:"height",get:function(){return this.canvas.height},set:function(t){this.canvas.height=t}}]),t}();r.default=h},{"../../../settings":97}],76:[function(t,e,r){"use strict";function n(t){var e=document.createElement("canvas");e.width=6,e.height=1;var r=e.getContext("2d");return r.fillStyle=t,r.fillRect(0,0,6,1),e}function i(){if("undefined"==typeof document)return!1;var t=n("#ff00ff"),e=n("#ffff00"),r=document.createElement("canvas");r.width=6,r.height=1;var i=r.getContext("2d");i.globalCompositeOperation="multiply",i.drawImage(t,0,0),i.drawImage(e,2,0);var o=i.getImageData(2,0,1,1);if(!o)return!1;var s=o.data;return 255===s[0]&&0===s[1]&&0===s[2]}r.__esModule=!0,r.default=i},{}],77:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(){var t=arguments.length<=0||void 0===arguments[0]?[]:arguments[0];return(0,a.default)()?(t[o.BLEND_MODES.NORMAL]="source-over",t[o.BLEND_MODES.ADD]="lighter",t[o.BLEND_MODES.MULTIPLY]="multiply",t[o.BLEND_MODES.SCREEN]="screen",t[o.BLEND_MODES.OVERLAY]="overlay",t[o.BLEND_MODES.DARKEN]="darken",t[o.BLEND_MODES.LIGHTEN]="lighten",t[o.BLEND_MODES.COLOR_DODGE]="color-dodge",t[o.BLEND_MODES.COLOR_BURN]="color-burn",t[o.BLEND_MODES.HARD_LIGHT]="hard-light",t[o.BLEND_MODES.SOFT_LIGHT]="soft-light",t[o.BLEND_MODES.DIFFERENCE]="difference",t[o.BLEND_MODES.EXCLUSION]="exclusion",t[o.BLEND_MODES.HUE]="hue",t[o.BLEND_MODES.SATURATION]="saturate",t[o.BLEND_MODES.COLOR]="color",t[o.BLEND_MODES.LUMINOSITY]="luminosity"):(t[o.BLEND_MODES.NORMAL]="source-over",t[o.BLEND_MODES.ADD]="lighter",t[o.BLEND_MODES.MULTIPLY]="source-over",t[o.BLEND_MODES.SCREEN]="source-over",t[o.BLEND_MODES.OVERLAY]="source-over",t[o.BLEND_MODES.DARKEN]="source-over",t[o.BLEND_MODES.LIGHTEN]="source-over",t[o.BLEND_MODES.COLOR_DODGE]="source-over",t[o.BLEND_MODES.COLOR_BURN]="source-over",t[o.BLEND_MODES.HARD_LIGHT]="source-over",t[o.BLEND_MODES.SOFT_LIGHT]="source-over",t[o.BLEND_MODES.DIFFERENCE]="source-over",t[o.BLEND_MODES.EXCLUSION]="source-over",t[o.BLEND_MODES.HUE]="source-over",t[o.BLEND_MODES.SATURATION]="source-over",t[o.BLEND_MODES.COLOR]="source-over",t[o.BLEND_MODES.LUMINOSITY]="source-over"),t}r.__esModule=!0,r.default=i;var o=t("../../../const"),s=t("./canUseNewCanvasBlendModes"),a=n(s)},{"../../../const":42,"./canUseNewCanvasBlendModes":76}],78:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=t("../../const"),s=t("../../settings"),a=n(s),u=a.default.GC_MODE,h=a.default.GC_MAX_IDLE,l=a.default.GC_MAX_CHECK_COUNT,c=function(){function t(e){i(this,t),this.renderer=e,this.count=0,this.checkCount=0,this.maxIdle=h,this.checkCountMax=l,this.mode=u}return t.prototype.update=function(){this.count++,this.mode!==o.GC_MODES.MANUAL&&(this.checkCount++,this.checkCount>this.checkCountMax&&(this.checkCount=0,this.run()))},t.prototype.run=function(){for(var t=this.renderer.textureManager,e=t._managedTextures,r=!1,n=0;n<e.length;n++){var i=e[n];!i._glRenderTargets&&this.count-i.touched>this.maxIdle&&(t.destroyTexture(i,!0),e[n]=null,r=!0)}if(r){for(var o=0,s=0;s<e.length;s++)null!==e[s]&&(e[o++]=e[s]);e.length=o}},t.prototype.unload=function(t){var e=this.renderer.textureManager;t._texture&&e.destroyTexture(t._texture,!0);for(var r=t.children.length-1;r>=0;r--)this.unload(t.children[r])},t}();r.default=c},{"../../const":42,"../../settings":97}],79:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=t("pixi-gl-core"),s=t("../../const"),a=t("./utils/RenderTarget"),u=n(a),h=t("../../utils"),l=function(){function t(e){i(this,t),this.renderer=e,this.gl=e.gl,this._managedTextures=[]}return t.prototype.bindTexture=function(){},t.prototype.getTexture=function(){},t.prototype.updateTexture=function(t,e){e=e||0;var r=this.gl,n=!!t._glRenderTargets;if(!t.hasLoaded)return null;r.activeTexture(r.TEXTURE0+e);var i=t._glTextures[this.renderer.CONTEXT_UID];if(i)n?t._glRenderTargets[this.renderer.CONTEXT_UID].resize(t.width,t.height):i.upload(t.source);else{if(n){var a=new u.default(this.gl,t.width,t.height,t.scaleMode,t.resolution);a.resize(t.width,t.height),t._glRenderTargets[this.renderer.CONTEXT_UID]=a,i=a.texture}else i=new o.GLTexture(this.gl,null,null,null,null),i.bind(e),i.premultiplyAlpha=!0,i.upload(t.source);t._glTextures[this.renderer.CONTEXT_UID]=i,t.on("update",this.updateTexture,this),t.on("dispose",this.destroyTexture,this),this._managedTextures.push(t),t.isPowerOfTwo?(t.mipmap&&i.enableMipmap(),t.wrapMode===s.WRAP_MODES.CLAMP?i.enableWrapClamp():t.wrapMode===s.WRAP_MODES.REPEAT?i.enableWrapRepeat():i.enableWrapMirrorRepeat()):i.enableWrapClamp(),t.scaleMode===s.SCALE_MODES.NEAREST?i.enableNearestScaling():i.enableLinearScaling()}return this.renderer.boundTextures[e]=t,i},t.prototype.destroyTexture=function(t,e){if(t=t.baseTexture||t,t.hasLoaded&&t._glTextures[this.renderer.CONTEXT_UID]&&(this.renderer.unbindTexture(t),t._glTextures[this.renderer.CONTEXT_UID].destroy(),t.off("update",this.updateTexture,this),t.off("dispose",this.destroyTexture,this),delete t._glTextures[this.renderer.CONTEXT_UID],!e)){var r=this._managedTextures.indexOf(t);r!==-1&&(0,h.removeItems)(this._managedTextures,r,1)}},t.prototype.removeAll=function(){for(var t=0;t<this._managedTextures.length;++t){var e=this._managedTextures[t];e._glTextures[this.renderer.CONTEXT_UID]&&delete e._glTextures[this.renderer.CONTEXT_UID]}},t.prototype.destroy=function(){for(var t=0;t<this._managedTextures.length;++t){var e=this._managedTextures[t];this.destroyTexture(e,!0),e.off("update",this.updateTexture,this),e.off("dispose",this.destroyTexture,this)}this._managedTextures=null},t}();r.default=l},{"../../const":42,"../../utils":117,"./utils/RenderTarget":92,"pixi-gl-core":12}],80:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("../SystemRenderer"),u=n(a),h=t("./managers/MaskManager"),l=n(h),c=t("./managers/StencilManager"),d=n(c),f=t("./managers/FilterManager"),p=n(f),v=t("./utils/RenderTarget"),y=n(v),g=t("./utils/ObjectRenderer"),m=n(g),_=t("./TextureManager"),b=n(_),x=t("../../textures/BaseTexture"),T=n(x),w=t("./TextureGarbageCollector"),E=n(w),O=t("./WebGLState"),S=n(O),M=t("./utils/mapWebGLDrawModesToPixi"),P=n(M),C=t("./utils/validateContext"),R=n(C),D=t("../../utils"),A=t("pixi-gl-core"),I=n(A),L=t("../../const"),j=0,B=function(t){function e(r,n){var s=arguments.length<=2||void 0===arguments[2]?{}:arguments[2];i(this,e);var a=o(this,t.call(this,"WebGL",r,n,s));return a.type=L.RENDERER_TYPE.WEBGL,a.handleContextLost=a.handleContextLost.bind(a),a.handleContextRestored=a.handleContextRestored.bind(a),a.view.addEventListener("webglcontextlost",a.handleContextLost,!1),a.view.addEventListener("webglcontextrestored",a.handleContextRestored,!1),a._contextOptions={alpha:a.transparent,antialias:s.antialias,premultipliedAlpha:a.transparent&&"notMultiplied"!==a.transparent,stencil:!0,preserveDrawingBuffer:s.preserveDrawingBuffer},a._backgroundColorRgba[3]=a.transparent?0:1,a.maskManager=new l.default(a),a.stencilManager=new d.default(a),a.emptyRenderer=new m.default(a),a.currentRenderer=a.emptyRenderer,a.initPlugins(),s.context&&(0,R.default)(s.context),a.gl=s.context||I.default.createContext(a.view,a._contextOptions),a.CONTEXT_UID=j++,a.state=new S.default(a.gl),a.renderingToScreen=!0,a.boundTextures=null,a._initContext(),a.filterManager=new p.default(a),a.drawModes=(0,P.default)(a.gl),a._activeShader=null,a._activeVao=null,a._activeRenderTarget=null,a._nextTextureLocation=0,a.setBlendMode(0),a}return s(e,t),e.prototype._initContext=function(){var t=this.gl;t.isContextLost()&&t.getExtension("WEBGL_lose_context")&&t.getExtension("WEBGL_lose_context").restoreContext();var e=t.getParameter(t.MAX_TEXTURE_IMAGE_UNITS);this.boundTextures=new Array(e),this.emptyTextures=new Array(e),this.textureManager=new b.default(this),this.textureGC=new E.default(this),this.state.resetToDefault(),this.rootRenderTarget=new y.default(t,this.width,this.height,null,this.resolution,(!0)),this.rootRenderTarget.clearColor=this._backgroundColorRgba,this.bindRenderTarget(this.rootRenderTarget);var r=new I.default.GLTexture.fromData(t,null,1,1),n={_glTextures:{}};n._glTextures[this.CONTEXT_UID]={};for(var i=0;i<e;i++){var o=new T.default;o._glTextures[this.CONTEXT_UID]=r,this.boundTextures[i]=n,this.emptyTextures[i]=o,this.bindTexture(null,i)}this.emit("context",t),this.resize(this.width,this.height)},e.prototype.render=function(t,e,r,n,i){if(this.renderingToScreen=!e,this.emit("prerender"),this.gl&&!this.gl.isContextLost()){if(this._nextTextureLocation=0,e||(this._lastObjectRendered=t),!i){var o=t.parent;t.parent=this._tempDisplayObjectParent,t.updateTransform(),t.parent=o}this.bindRenderTexture(e,n),this.currentRenderer.start(),(void 0!==r?r:this.clearBeforeRender)&&this._activeRenderTarget.clear(),t.renderWebGL(this),this.currentRenderer.flush(),this.textureGC.update(),this.emit("postrender")}},e.prototype.setObjectRenderer=function(t){this.currentRenderer!==t&&(this.currentRenderer.stop(),this.currentRenderer=t,this.currentRenderer.start())},e.prototype.flush=function(){this.setObjectRenderer(this.emptyRenderer)},e.prototype.resize=function(t,e){u.default.prototype.resize.call(this,t,e),this.rootRenderTarget.resize(t,e),this._activeRenderTarget===this.rootRenderTarget&&(this.rootRenderTarget.activate(),this._activeShader&&(this._activeShader.uniforms.projectionMatrix=this.rootRenderTarget.projectionMatrix.toArray(!0)))},e.prototype.setBlendMode=function(t){this.state.setBlendMode(t)},e.prototype.clear=function(t){this._activeRenderTarget.clear(t)},e.prototype.setTransform=function(t){this._activeRenderTarget.transform=t},e.prototype.bindRenderTexture=function(t,e){var r=void 0;if(t){var n=t.baseTexture;n._glRenderTargets[this.CONTEXT_UID]||this.textureManager.updateTexture(n,0),this.unbindTexture(n),r=n._glRenderTargets[this.CONTEXT_UID],r.setFrame(t.frame)}else r=this.rootRenderTarget;return r.transform=e,this.bindRenderTarget(r),this},e.prototype.bindRenderTarget=function(t){return t!==this._activeRenderTarget&&(this._activeRenderTarget=t,t.activate(),this._activeShader&&(this._activeShader.uniforms.projectionMatrix=t.projectionMatrix.toArray(!0)),this.stencilManager.setMaskStack(t.stencilMaskStack)),this},e.prototype.bindShader=function(t){return this._activeShader!==t&&(this._activeShader=t,t.bind(),t.uniforms.projectionMatrix=this._activeRenderTarget.projectionMatrix.toArray(!0)),this},e.prototype.bindTexture=function(t,e,r){if(t=t||this.emptyTextures[e],t=t.baseTexture||t,t.touched=this.textureGC.count,r)e=e||0;else{for(var n=0;n<this.boundTextures.length;n++)if(this.boundTextures[n]===t)return n;void 0===e&&(this._nextTextureLocation++,this._nextTextureLocation%=this.boundTextures.length,e=this.boundTextures.length-this._nextTextureLocation-1)}var i=this.gl,o=t._glTextures[this.CONTEXT_UID];return o?(this.boundTextures[e]=t,i.activeTexture(i.TEXTURE0+e),i.bindTexture(i.TEXTURE_2D,o.texture)):this.textureManager.updateTexture(t,e),
e},e.prototype.unbindTexture=function(t){var e=this.gl;t=t.baseTexture||t;for(var r=0;r<this.boundTextures.length;r++)this.boundTextures[r]===t&&(this.boundTextures[r]=this.emptyTextures[r],e.activeTexture(e.TEXTURE0+r),e.bindTexture(e.TEXTURE_2D,this.emptyTextures[r]._glTextures[this.CONTEXT_UID].texture));return this},e.prototype.createVao=function(){return new I.default.VertexArrayObject(this.gl,this.state.attribState)},e.prototype.bindVao=function(t){return this._activeVao===t?this:(t?t.bind():this._activeVao&&this._activeVao.unbind(),this._activeVao=t,this)},e.prototype.reset=function(){return this.setObjectRenderer(this.emptyRenderer),this._activeShader=null,this._activeRenderTarget=this.rootRenderTarget,this.rootRenderTarget.activate(),this.state.resetToDefault(),this},e.prototype.handleContextLost=function(t){t.preventDefault()},e.prototype.handleContextRestored=function(){this._initContext(),this.textureManager.removeAll()},e.prototype.destroy=function(e){this.destroyPlugins(),this.view.removeEventListener("webglcontextlost",this.handleContextLost),this.view.removeEventListener("webglcontextrestored",this.handleContextRestored),this.textureManager.destroy(),t.prototype.destroy.call(this,e),this.uid=0,this.maskManager.destroy(),this.stencilManager.destroy(),this.filterManager.destroy(),this.maskManager=null,this.filterManager=null,this.textureManager=null,this.currentRenderer=null,this.handleContextLost=null,this.handleContextRestored=null,this._contextOptions=null,this.gl.useProgram(null),this.gl.getExtension("WEBGL_lose_context")&&this.gl.getExtension("WEBGL_lose_context").loseContext(),this.gl=null},e}(u.default);r.default=B,D.pluginTarget.mixin(B)},{"../../const":42,"../../textures/BaseTexture":107,"../../utils":117,"../SystemRenderer":72,"./TextureGarbageCollector":78,"./TextureManager":79,"./WebGLState":81,"./managers/FilterManager":86,"./managers/MaskManager":87,"./managers/StencilManager":88,"./utils/ObjectRenderer":90,"./utils/RenderTarget":92,"./utils/mapWebGLDrawModesToPixi":95,"./utils/validateContext":96,"pixi-gl-core":12}],81:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=t("./utils/mapWebGLBlendModesToPixi"),s=n(o),a=0,u=1,h=2,l=3,c=4,d=function(){function t(e){i(this,t),this.activeState=new Uint8Array(16),this.defaultState=new Uint8Array(16),this.defaultState[0]=1,this.stackIndex=0,this.stack=[],this.gl=e,this.maxAttribs=e.getParameter(e.MAX_VERTEX_ATTRIBS),this.attribState={tempAttribState:new Array(this.maxAttribs),attribState:new Array(this.maxAttribs)},this.blendModes=(0,s.default)(e),this.nativeVaoExtension=e.getExtension("OES_vertex_array_object")||e.getExtension("MOZ_OES_vertex_array_object")||e.getExtension("WEBKIT_OES_vertex_array_object")}return t.prototype.push=function(){var t=this.stack[++this.stackIndex];t||(t=this.stack[this.stackIndex]=new Uint8Array(16));for(var e=0;e<this.activeState.length;e++)this.activeState[e]=t[e]},t.prototype.pop=function(){var t=this.stack[--this.stackIndex];this.setState(t)},t.prototype.setState=function(t){this.setBlend(t[a]),this.setDepthTest(t[u]),this.setFrontFace(t[h]),this.setCullFace(t[l]),this.setBlendMode(t[c])},t.prototype.setBlend=function(t){t=t?1:0,this.activeState[a]!==t&&(this.activeState[a]=t,this.gl[t?"enable":"disable"](this.gl.BLEND))},t.prototype.setBlendMode=function(t){t!==this.activeState[c]&&(this.activeState[c]=t,this.gl.blendFunc(this.blendModes[t][0],this.blendModes[t][1]))},t.prototype.setDepthTest=function(t){t=t?1:0,this.activeState[u]!==t&&(this.activeState[u]=t,this.gl[t?"enable":"disable"](this.gl.DEPTH_TEST))},t.prototype.setCullFace=function(t){t=t?1:0,this.activeState[l]!==t&&(this.activeState[l]=t,this.gl[t?"enable":"disable"](this.gl.CULL_FACE))},t.prototype.setFrontFace=function(t){t=t?1:0,this.activeState[h]!==t&&(this.activeState[h]=t,this.gl.frontFace(this.gl[t?"CW":"CCW"]))},t.prototype.resetAttributes=function(){for(var t=0;t<this.attribState.tempAttribState.length;t++)this.attribState.tempAttribState[t]=0;for(var e=0;e<this.attribState.attribState.length;e++)this.attribState.attribState[e]=0;for(var r=1;r<this.maxAttribs;r++)this.gl.disableVertexAttribArray(r)},t.prototype.resetToDefault=function(){this.nativeVaoExtension&&this.nativeVaoExtension.bindVertexArrayOES(null),this.resetAttributes();for(var t=0;t<this.activeState.length;++t)this.activeState[t]=32;this.gl.pixelStorei(this.gl.UNPACK_FLIP_Y_WEBGL,!1),this.setState(this.defaultState)},t}();r.default=d},{"./utils/mapWebGLBlendModesToPixi":94}],82:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),s=t("./extractUniformsFromSrc"),a=n(s),u=t("../../../utils"),h=t("../../../const"),l={},c=function(){function t(e,r,n){i(this,t),this.vertexSrc=e||t.defaultVertexSrc,this.fragmentSrc=r||t.defaultFragmentSrc,this.blendMode=h.BLEND_MODES.NORMAL,this.uniformData=n||(0,a.default)(this.vertexSrc,this.fragmentSrc,"projectionMatrix|uSampler"),this.uniforms={};for(var o in this.uniformData)this.uniforms[o]=this.uniformData[o].value;this.glShaders={},l[this.vertexSrc+this.fragmentSrc]||(l[this.vertexSrc+this.fragmentSrc]=(0,u.uid)()),this.glShaderKey=l[this.vertexSrc+this.fragmentSrc],this.padding=4,this.resolution=1,this.enabled=!0}return t.prototype.apply=function(t,e,r,n){t.applyFilter(this,e,r,n)},o(t,null,[{key:"defaultVertexSrc",get:function(){return["attribute vec2 aVertexPosition;","attribute vec2 aTextureCoord;","uniform mat3 projectionMatrix;","uniform mat3 filterMatrix;","varying vec2 vTextureCoord;","varying vec2 vFilterCoord;","void main(void){","   gl_Position = vec4((projectionMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);","   vFilterCoord = ( filterMatrix * vec3( aTextureCoord, 1.0)  ).xy;","   vTextureCoord = aTextureCoord ;","}"].join("\n")}},{key:"defaultFragmentSrc",get:function(){return["varying vec2 vTextureCoord;","varying vec2 vFilterCoord;","uniform sampler2D uSampler;","uniform sampler2D filterSampler;","void main(void){","   vec4 masky = texture2D(filterSampler, vFilterCoord);","   vec4 sample = texture2D(uSampler, vTextureCoord);","   vec4 color;","   if(mod(vFilterCoord.x, 1.0) > 0.5)","   {","     color = vec4(1.0, 0.0, 0.0, 1.0);","   }","   else","   {","     color = vec4(0.0, 1.0, 0.0, 1.0);","   }","   gl_FragColor = mix(sample, masky, 0.5);","   gl_FragColor *= sample.a;","}"].join("\n")}}]),t}();r.default=c},{"../../../const":42,"../../../utils":117,"./extractUniformsFromSrc":83}],83:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e,r){var n=o(t,r),i=o(e,r);return Object.assign(n,i)}function o(t){for(var e=new RegExp("^(projectionMatrix|uSampler|filterArea)$"),r={},n=void 0,i=t.replace(/\s+/g," ").split(/\s*;\s*/),o=0;o<i.length;o++){var s=i[o].trim();if(s.indexOf("uniform")>-1){var a=s.split(" "),h=a[1],l=a[2],c=1;l.indexOf("[")>-1&&(n=l.split(/\[|]/),l=n[0],c*=Number(n[1])),l.match(e)||(r[l]={value:u(h,c),name:l,type:h})}}return r}r.__esModule=!0,r.default=i;var s=t("pixi-gl-core"),a=n(s),u=a.default.shader.defaultValue},{"pixi-gl-core":12}],84:[function(t,e,r){"use strict";function n(t,e,r){var n=t.identity();return n.translate(e.x/r.width,e.y/r.height),n.scale(r.width,r.height),n}function i(t,e,r){var n=t.identity();n.translate(e.x/r.width,e.y/r.height);var i=r.width/e.width,o=r.height/e.height;return n.scale(i,o),n}function o(t,e,r,n){var i=n.worldTransform.copy(s.Matrix.TEMP_MATRIX),o=n._texture.baseTexture,a=t.identity(),u=r.height/r.width;a.translate(e.x/r.width,e.y/r.height),a.scale(1,u);var h=r.width/o.width,l=r.height/o.height;return i.tx/=o.width*h,i.ty/=o.width*h,i.invert(),a.prepend(i),a.scale(1,1/u),a.scale(h,l),a.translate(n.anchor.x,n.anchor.y),a}r.__esModule=!0,r.calculateScreenSpaceMatrix=n,r.calculateNormalizedScreenSpaceMatrix=i,r.calculateSpriteMatrix=o;var s=t("../../../math")},{"../../../math":66}],85:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("../Filter"),u=n(a),h=t("../../../../math"),l=(t("path"),function(t){function e(r){i(this,e);var n=new h.Matrix,s=o(this,t.call(this,"attribute vec2 aVertexPosition;\nattribute vec2 aTextureCoord;\n\nuniform mat3 projectionMatrix;\nuniform mat3 otherMatrix;\n\nvarying vec2 vMaskCoord;\nvarying vec2 vTextureCoord;\n\nvoid main(void)\n{\n    gl_Position = vec4((projectionMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);\n\n    vTextureCoord = aTextureCoord;\n    vMaskCoord = ( otherMatrix * vec3( aTextureCoord, 1.0)  ).xy;\n}\n","varying vec2 vMaskCoord;\nvarying vec2 vTextureCoord;\n\nuniform sampler2D uSampler;\nuniform float alpha;\nuniform sampler2D mask;\n\nvoid main(void)\n{\n    // check clip! this will stop the mask bleeding out from the edges\n    vec2 text = abs( vMaskCoord - 0.5 );\n    text = step(0.5, text);\n\n    float clip = 1.0 - max(text.y, text.x);\n    vec4 original = texture2D(uSampler, vTextureCoord);\n    vec4 masky = texture2D(mask, vMaskCoord);\n\n    original *= (masky.r * masky.a * alpha * clip);\n\n    gl_FragColor = original;\n}\n"));return r.renderable=!1,s.maskSprite=r,s.maskMatrix=n,s}return s(e,t),e.prototype.apply=function(t,e,r){var n=this.maskSprite;this.uniforms.mask=n._texture,this.uniforms.otherMatrix=t.calculateSpriteMatrix(this.maskMatrix,n),this.uniforms.alpha=n.worldAlpha,t.applyFilter(this,e,r)},e}(u.default));r.default=l},{"../../../../math":66,"../Filter":82,path:22}],86:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t){return t&&t.__esModule?t:{default:t}}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}function a(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var u=t("./WebGLManager"),h=i(u),l=t("../utils/RenderTarget"),c=i(l),d=t("../utils/Quad"),f=i(d),p=t("../../../math"),v=t("../../../Shader"),y=i(v),g=t("../filters/filterTransforms"),m=n(g),_=t("bit-twiddle"),b=i(_),x=function t(){a(this,t),this.renderTarget=null,this.sourceFrame=new p.Rectangle,this.destinationFrame=new p.Rectangle,this.filters=[],this.target=null,this.resolution=1},T=function(t){function e(r){a(this,e);var n=o(this,t.call(this,r));return n.gl=n.renderer.gl,n.quad=new f.default(n.gl,r.state.attribState),n.shaderCache={},n.pool={},n.filterData=null,n}return s(e,t),e.prototype.pushFilter=function(t,e){var r=this.renderer,n=this.filterData;if(!n){n=this.renderer._activeRenderTarget.filterStack;var i=new x;i.sourceFrame=i.destinationFrame=this.renderer._activeRenderTarget.size,i.renderTarget=r._activeRenderTarget,this.renderer._activeRenderTarget.filterData=n={index:0,stack:[i]},this.filterData=n}var o=n.stack[++n.index];o||(o=n.stack[n.index]=new x);var s=e[0].resolution,a=0|e[0].padding,u=t.filterArea||t.getBounds(!0),h=o.sourceFrame,l=o.destinationFrame;h.x=(u.x*s|0)/s,h.y=(u.y*s|0)/s,h.width=(u.width*s|0)/s,h.height=(u.height*s|0)/s,n.stack[0].renderTarget.transform||h.fit(n.stack[0].destinationFrame),h.pad(a),l.width=h.width,l.height=h.height;var c=this.getPotRenderTarget(r.gl,h.width,h.height,s);o.target=t,o.filters=e,o.resolution=s,o.renderTarget=c,c.setFrame(l,h),r.bindRenderTarget(c),r.clear()},e.prototype.popFilter=function(){var t=this.filterData,e=t.stack[t.index-1],r=t.stack[t.index];this.quad.map(r.renderTarget.size,r.sourceFrame).upload();var n=r.filters;if(1===n.length)n[0].apply(this,r.renderTarget,e.renderTarget,!1),this.freePotRenderTarget(r.renderTarget);else{var i=r.renderTarget,o=this.getPotRenderTarget(this.renderer.gl,r.sourceFrame.width,r.sourceFrame.height,r.resolution);o.setFrame(r.destinationFrame,r.sourceFrame);var s=0;for(s=0;s<n.length-1;++s){n[s].apply(this,i,o,!0);var a=i;i=o,o=a}n[s].apply(this,i,e.renderTarget,!1),this.freePotRenderTarget(i),this.freePotRenderTarget(o)}t.index--,0===t.index&&(this.filterData=null)},e.prototype.applyFilter=function(t,e,r,n){var i=this.renderer,o=i.gl,s=t.glShaders[i.CONTEXT_UID];s||(t.glShaderKey?(s=this.shaderCache[t.glShaderKey],s||(s=new y.default(this.gl,t.vertexSrc,t.fragmentSrc),t.glShaders[i.CONTEXT_UID]=this.shaderCache[t.glShaderKey]=s)):s=t.glShaders[i.CONTEXT_UID]=new y.default(this.gl,t.vertexSrc,t.fragmentSrc),i.bindVao(null),this.quad.initVao(s)),i.bindVao(this.quad.vao),i.bindRenderTarget(r),n&&(o.disable(o.SCISSOR_TEST),i.clear(),o.enable(o.SCISSOR_TEST)),r===i.maskManager.scissorRenderTarget&&i.maskManager.pushScissorMask(null,i.maskManager.scissorData),i.bindShader(s),this.syncUniforms(s,t),i.state.setBlendMode(t.blendMode);var a=this.renderer.boundTextures[0];o.activeTexture(o.TEXTURE0),o.bindTexture(o.TEXTURE_2D,e.texture.texture),this.quad.vao.draw(this.renderer.gl.TRIANGLES,6,0),o.bindTexture(o.TEXTURE_2D,a._glTextures[this.renderer.CONTEXT_UID].texture)},e.prototype.syncUniforms=function(t,e){var r=e.uniformData,n=e.uniforms,i=1,o=void 0;if(t.uniforms.data.filterArea){o=this.filterData.stack[this.filterData.index];var s=t.uniforms.filterArea;s[0]=o.renderTarget.size.width,s[1]=o.renderTarget.size.height,s[2]=o.sourceFrame.x,s[3]=o.sourceFrame.y,t.uniforms.filterArea=s}if(t.uniforms.data.filterClamp){o=this.filterData.stack[this.filterData.index];var a=t.uniforms.filterClamp;a[0]=0,a[1]=0,a[2]=(o.sourceFrame.width-1)/o.renderTarget.size.width,a[3]=(o.sourceFrame.height-1)/o.renderTarget.size.height,t.uniforms.filterClamp=a}for(var u in r)if("sampler2D"===r[u].type&&0!==n[u]){if(n[u].baseTexture)t.uniforms[u]=this.renderer.bindTexture(n[u].baseTexture,i);else{t.uniforms[u]=i;var h=this.renderer.gl;h.activeTexture(h.TEXTURE0+i),n[u].texture.bind()}i++}else if("mat3"===r[u].type)void 0!==n[u].a?t.uniforms[u]=n[u].toArray(!0):t.uniforms[u]=n[u];else if("vec2"===r[u].type)if(void 0!==n[u].x){var l=t.uniforms[u]||new Float32Array(2);l[0]=n[u].x,l[1]=n[u].y,t.uniforms[u]=l}else t.uniforms[u]=n[u];else"float"===r[u].type?t.uniforms.data[u].value!==r[u]&&(t.uniforms[u]=n[u]):t.uniforms[u]=n[u]},e.prototype.getRenderTarget=function(t,e){var r=this.filterData.stack[this.filterData.index],n=this.getPotRenderTarget(this.renderer.gl,r.sourceFrame.width,r.sourceFrame.height,e||r.resolution);return n.setFrame(r.destinationFrame,r.sourceFrame),n},e.prototype.returnRenderTarget=function(t){this.freePotRenderTarget(t)},e.prototype.calculateScreenSpaceMatrix=function(t){var e=this.filterData.stack[this.filterData.index];return m.calculateScreenSpaceMatrix(t,e.sourceFrame,e.renderTarget.size)},e.prototype.calculateNormalizedScreenSpaceMatrix=function(t){var e=this.filterData.stack[this.filterData.index];return m.calculateNormalizedScreenSpaceMatrix(t,e.sourceFrame,e.renderTarget.size,e.destinationFrame)},e.prototype.calculateSpriteMatrix=function(t,e){var r=this.filterData.stack[this.filterData.index];return m.calculateSpriteMatrix(t,r.sourceFrame,r.renderTarget.size,e)},e.prototype.destroy=function(){this.shaderCache=[],this.emptyPool()},e.prototype.getPotRenderTarget=function(t,e,r,n){e=b.default.nextPow2(e*n),r=b.default.nextPow2(r*n);var i=(65535&e)<<16|65535&r;this.pool[i]||(this.pool[i]=[]);var o=this.pool[i].pop();if(!o){var s=this.renderer.boundTextures[0];t.activeTexture(t.TEXTURE0),o=new c.default(t,e,r,null,1),t.bindTexture(t.TEXTURE_2D,s._glTextures[this.renderer.CONTEXT_UID].texture)}return o.resolution=n,o.defaultFrame.width=o.size.width=e/n,o.defaultFrame.height=o.size.height=r/n,o},e.prototype.emptyPool=function(){for(var t in this.pool){var e=this.pool[t];if(e)for(var r=0;r<e.length;r++)e[r].destroy(!0)}this.pool={}},e.prototype.freePotRenderTarget=function(t){var e=t.size.width*t.resolution,r=t.size.height*t.resolution,n=(65535&e)<<16|65535&r;this.pool[n].push(t)},e}(h.default);r.default=T},{"../../../Shader":41,"../../../math":66,"../filters/filterTransforms":84,"../utils/Quad":91,"../utils/RenderTarget":92,"./WebGLManager":89,"bit-twiddle":1}],87:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("./WebGLManager"),u=n(a),h=t("../filters/spriteMask/SpriteMaskFilter"),l=n(h),c=function(t){function e(r){i(this,e);var n=o(this,t.call(this,r));return n.scissor=!1,n.scissorData=null,n.scissorRenderTarget=null,n.enableScissor=!0,n.alphaMaskPool=[],n.alphaMaskIndex=0,n}return s(e,t),e.prototype.pushMask=function(t,e){if(e.texture)this.pushSpriteMask(t,e);else if(this.enableScissor&&!this.scissor&&!this.renderer.stencilManager.stencilMaskStack.length&&e.isFastRect()){var r=e.worldTransform,n=Math.atan2(r.b,r.a);n=Math.round(n*(180/Math.PI)),n%90?this.pushStencilMask(e):this.pushScissorMask(t,e)}else this.pushStencilMask(e)},e.prototype.popMask=function(t,e){e.texture?this.popSpriteMask(t,e):this.enableScissor&&!this.renderer.stencilManager.stencilMaskStack.length?this.popScissorMask(t,e):this.popStencilMask(t,e)},e.prototype.pushSpriteMask=function(t,e){var r=this.alphaMaskPool[this.alphaMaskIndex];r||(r=this.alphaMaskPool[this.alphaMaskIndex]=[new l.default(e)]),r[0].resolution=this.renderer.resolution,r[0].maskSprite=e,t.filterArea=e.getBounds(!0),this.renderer.filterManager.pushFilter(t,r),this.alphaMaskIndex++},e.prototype.popSpriteMask=function(){this.renderer.filterManager.popFilter(),this.alphaMaskIndex--},e.prototype.pushStencilMask=function(t){this.renderer.currentRenderer.stop(),this.renderer.stencilManager.pushStencil(t)},e.prototype.popStencilMask=function(){this.renderer.currentRenderer.stop(),this.renderer.stencilManager.popStencil()},e.prototype.pushScissorMask=function(t,e){e.renderable=!0;var r=this.renderer._activeRenderTarget,n=e.getBounds();n.fit(r.size),e.renderable=!1,this.renderer.gl.enable(this.renderer.gl.SCISSOR_TEST);var i=this.renderer.resolution;this.renderer.gl.scissor(n.x*i,(r.root?r.size.height-n.y-n.height:n.y)*i,n.width*i,n.height*i),this.scissorRenderTarget=r,this.scissorData=e,this.scissor=!0},e.prototype.popScissorMask=function(){this.scissorRenderTarget=null,this.scissorData=null,this.scissor=!1;var t=this.renderer.gl;t.disable(t.SCISSOR_TEST)},e}(u.default);r.default=c},{"../filters/spriteMask/SpriteMaskFilter":85,"./WebGLManager":89}],88:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("./WebGLManager"),u=n(a),h=function(t){function e(r){i(this,e);var n=o(this,t.call(this,r));return n.stencilMaskStack=null,n}return s(e,t),e.prototype.setMaskStack=function(t){this.stencilMaskStack=t;var e=this.renderer.gl;0===t.length?e.disable(e.STENCIL_TEST):e.enable(e.STENCIL_TEST)},e.prototype.pushStencil=function(t){this.renderer.setObjectRenderer(this.renderer.plugins.graphics),this.renderer._activeRenderTarget.attachStencilBuffer();var e=this.renderer.gl,r=this.stencilMaskStack;0===r.length&&(e.enable(e.STENCIL_TEST),e.clear(e.STENCIL_BUFFER_BIT),e.stencilFunc(e.ALWAYS,1,1)),r.push(t),e.colorMask(!1,!1,!1,!1),e.stencilOp(e.KEEP,e.KEEP,e.INCR),this.renderer.plugins.graphics.render(t),e.colorMask(!0,!0,!0,!0),e.stencilFunc(e.NOTEQUAL,0,r.length),e.stencilOp(e.KEEP,e.KEEP,e.KEEP)},e.prototype.popStencil=function(){this.renderer.setObjectRenderer(this.renderer.plugins.graphics);var t=this.renderer.gl,e=this.stencilMaskStack,r=e.pop();0===e.length?t.disable(t.STENCIL_TEST):(t.colorMask(!1,!1,!1,!1),t.stencilOp(t.KEEP,t.KEEP,t.DECR),this.renderer.plugins.graphics.render(r),t.colorMask(!0,!0,!0,!0),t.stencilFunc(t.NOTEQUAL,0,e.length),t.stencilOp(t.KEEP,t.KEEP,t.KEEP))},e.prototype.destroy=function(){u.default.prototype.destroy.call(this),this.stencilMaskStack.stencilStack=null},e}(u.default);r.default=h},{"./WebGLManager":89}],89:[function(t,e,r){"use strict";function n(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var i=function(){function t(e){n(this,t),this.renderer=e,this.renderer.on("context",this.onContextChange,this)}return t.prototype.onContextChange=function(){},t.prototype.destroy=function(){this.renderer.off("context",this.onContextChange,this),this.renderer=null},t}();r.default=i},{}],90:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("../managers/WebGLManager"),u=n(a),h=function(t){function e(){return i(this,e),o(this,t.apply(this,arguments))}return s(e,t),e.prototype.start=function(){},e.prototype.stop=function(){this.flush()},e.prototype.flush=function(){},e.prototype.render=function(t){},e}(u.default);r.default=h},{"../managers/WebGLManager":89}],91:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=t("pixi-gl-core"),s=n(o),a=t("../../../utils/createIndicesForQuads"),u=n(a),h=function(){function t(e,r){i(this,t),this.gl=e,this.vertices=new Float32Array([-1,-1,1,-1,1,1,-1,1]),this.uvs=new Float32Array([0,0,1,0,1,1,0,1]),this.interleaved=new Float32Array(16);for(var n=0;n<4;n++)this.interleaved[4*n]=this.vertices[2*n],this.interleaved[4*n+1]=this.vertices[2*n+1],this.interleaved[4*n+2]=this.uvs[2*n],this.interleaved[4*n+3]=this.uvs[2*n+1];this.indices=(0,u.default)(1),this.vertexBuffer=s.default.GLBuffer.createVertexBuffer(e,this.interleaved,e.STATIC_DRAW),this.indexBuffer=s.default.GLBuffer.createIndexBuffer(e,this.indices,e.STATIC_DRAW),this.vao=new s.default.VertexArrayObject(e,r)}return t.prototype.initVao=function(t){this.vao.clear().addIndex(this.indexBuffer).addAttribute(this.vertexBuffer,t.attributes.aVertexPosition,this.gl.FLOAT,!1,16,0).addAttribute(this.vertexBuffer,t.attributes.aTextureCoord,this.gl.FLOAT,!1,16,8)},t.prototype.map=function(t,e){var r=0,n=0;return this.uvs[0]=r,this.uvs[1]=n,this.uvs[2]=r+e.width/t.width,this.uvs[3]=n,this.uvs[4]=r+e.width/t.width,this.uvs[5]=n+e.height/t.height,this.uvs[6]=r,this.uvs[7]=n+e.height/t.height,r=e.x,n=e.y,this.vertices[0]=r,this.vertices[1]=n,this.vertices[2]=r+e.width,this.vertices[3]=n,this.vertices[4]=r+e.width,this.vertices[5]=n+e.height,this.vertices[6]=r,this.vertices[7]=n+e.height,this},t.prototype.upload=function(){for(var t=0;t<4;t++)this.interleaved[4*t]=this.vertices[2*t],this.interleaved[4*t+1]=this.vertices[2*t+1],this.interleaved[4*t+2]=this.uvs[2*t],this.interleaved[4*t+3]=this.uvs[2*t+1];return this.vertexBuffer.upload(this.interleaved),this},t.prototype.destroy=function(){var t=this.gl;t.deleteBuffer(this.vertexBuffer),t.deleteBuffer(this.indexBuffer)},t}();r.default=h},{"../../../utils/createIndicesForQuads":115,"pixi-gl-core":12}],92:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=t("../../../math"),s=t("../../../const"),a=t("../../../settings"),u=n(a),h=t("pixi-gl-core"),l=u.default.RESOLUTION,c=u.default.SCALE_MODE,d=function(){function t(e,r,n,a,u,d){i(this,t),this.gl=e,this.frameBuffer=null,this.texture=null,this.clearColor=[0,0,0,0],this.size=new o.Rectangle(0,0,1,1),this.resolution=u||l,this.projectionMatrix=new o.Matrix,this.transform=null,this.frame=null,this.defaultFrame=new o.Rectangle,this.destinationFrame=null,this.sourceFrame=null,this.stencilBuffer=null,this.stencilMaskStack=[],this.filterData=null,this.scaleMode=a||c,this.root=d,this.root?(this.frameBuffer=new h.GLFramebuffer(e,100,100),this.frameBuffer.framebuffer=null):(this.frameBuffer=h.GLFramebuffer.createRGBA(e,100,100),this.scaleMode===s.SCALE_MODES.NEAREST?this.frameBuffer.texture.enableNearestScaling():this.frameBuffer.texture.enableLinearScaling(),this.texture=this.frameBuffer.texture),this.setFrame(),this.resize(r,n)}return t.prototype.clear=function(t){var e=t||this.clearColor;this.frameBuffer.clear(e[0],e[1],e[2],e[3])},t.prototype.attachStencilBuffer=function(){this.root||this.frameBuffer.enableStencil()},t.prototype.setFrame=function(t,e){this.destinationFrame=t||this.destinationFrame||this.defaultFrame,this.sourceFrame=e||this.sourceFrame||t},t.prototype.activate=function(){var t=this.gl;this.frameBuffer.bind(),this.calculateProjection(this.destinationFrame,this.sourceFrame),this.transform&&this.projectionMatrix.append(this.transform),this.destinationFrame!==this.sourceFrame?(t.enable(t.SCISSOR_TEST),t.scissor(0|this.destinationFrame.x,0|this.destinationFrame.y,this.destinationFrame.width*this.resolution|0,this.destinationFrame.height*this.resolution|0)):t.disable(t.SCISSOR_TEST),t.viewport(0|this.destinationFrame.x,0|this.destinationFrame.y,this.destinationFrame.width*this.resolution|0,this.destinationFrame.height*this.resolution|0)},t.prototype.calculateProjection=function(t,e){var r=this.projectionMatrix;e=e||t,r.identity(),this.root?(r.a=1/t.width*2,r.d=-1/t.height*2,r.tx=-1-e.x*r.a,r.ty=1-e.y*r.d):(r.a=1/t.width*2,r.d=1/t.height*2,r.tx=-1-e.x*r.a,r.ty=-1-e.y*r.d)},t.prototype.resize=function(t,e){if(t=0|t,e=0|e,this.size.width!==t||this.size.height!==e){this.size.width=t,this.size.height=e,this.defaultFrame.width=t,this.defaultFrame.height=e,this.frameBuffer.resize(t*this.resolution,e*this.resolution);var r=this.frame||this.size;this.calculateProjection(r)}},t.prototype.destroy=function(){this.frameBuffer.destroy(),this.frameBuffer=null,this.texture=null},t}();r.default=d},{"../../../const":42,"../../../math":66,"../../../settings":97,"pixi-gl-core":12}],93:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){var r=!e;if(r){var n=document.createElement("canvas");n.width=1,n.height=1,e=a.default.createContext(n)}for(var i=e.createShader(e.FRAGMENT_SHADER);;){var s=u.replace(/%forloop%/gi,o(t));if(e.shaderSource(i,s),e.compileShader(i),e.getShaderParameter(i,e.COMPILE_STATUS))break;t=t/2|0}return r&&e.getExtension("WEBGL_lose_context")&&e.getExtension("WEBGL_lose_context").loseContext(),t}function o(t){for(var e="",r=0;r<t;++r)r>0&&(e+="\nelse "),r<t-1&&(e+="if(test == "+r+".0){}");return e}r.__esModule=!0,r.default=i;var s=t("pixi-gl-core"),a=n(s),u=["precision mediump float;","void main(void){","float test = 0.1;","%forloop%","gl_FragColor = vec4(0.0);","}"].join("\n")},{"pixi-gl-core":12}],94:[function(t,e,r){"use strict";function n(t){var e=arguments.length<=1||void 0===arguments[1]?[]:arguments[1];return e[i.BLEND_MODES.NORMAL]=[t.ONE,t.ONE_MINUS_SRC_ALPHA],e[i.BLEND_MODES.ADD]=[t.ONE,t.DST_ALPHA],e[i.BLEND_MODES.MULTIPLY]=[t.DST_COLOR,t.ONE_MINUS_SRC_ALPHA],e[i.BLEND_MODES.SCREEN]=[t.ONE,t.ONE_MINUS_SRC_COLOR],e[i.BLEND_MODES.OVERLAY]=[t.ONE,t.ONE_MINUS_SRC_ALPHA],e[i.BLEND_MODES.DARKEN]=[t.ONE,t.ONE_MINUS_SRC_ALPHA],e[i.BLEND_MODES.LIGHTEN]=[t.ONE,t.ONE_MINUS_SRC_ALPHA],e[i.BLEND_MODES.COLOR_DODGE]=[t.ONE,t.ONE_MINUS_SRC_ALPHA],e[i.BLEND_MODES.COLOR_BURN]=[t.ONE,t.ONE_MINUS_SRC_ALPHA],e[i.BLEND_MODES.HARD_LIGHT]=[t.ONE,t.ONE_MINUS_SRC_ALPHA],e[i.BLEND_MODES.SOFT_LIGHT]=[t.ONE,t.ONE_MINUS_SRC_ALPHA],e[i.BLEND_MODES.DIFFERENCE]=[t.ONE,t.ONE_MINUS_SRC_ALPHA],e[i.BLEND_MODES.EXCLUSION]=[t.ONE,t.ONE_MINUS_SRC_ALPHA],e[i.BLEND_MODES.HUE]=[t.ONE,t.ONE_MINUS_SRC_ALPHA],e[i.BLEND_MODES.SATURATION]=[t.ONE,t.ONE_MINUS_SRC_ALPHA],e[i.BLEND_MODES.COLOR]=[t.ONE,t.ONE_MINUS_SRC_ALPHA],e[i.BLEND_MODES.LUMINOSITY]=[t.ONE,t.ONE_MINUS_SRC_ALPHA],e}r.__esModule=!0,r.default=n;var i=t("../../../const")},{"../../../const":42}],95:[function(t,e,r){"use strict";function n(t){var e=arguments.length<=1||void 0===arguments[1]?{}:arguments[1];return e[i.DRAW_MODES.POINTS]=t.POINTS,e[i.DRAW_MODES.LINES]=t.LINES,e[i.DRAW_MODES.LINE_LOOP]=t.LINE_LOOP,e[i.DRAW_MODES.LINE_STRIP]=t.LINE_STRIP,e[i.DRAW_MODES.TRIANGLES]=t.TRIANGLES,e[i.DRAW_MODES.TRIANGLE_STRIP]=t.TRIANGLE_STRIP,e[i.DRAW_MODES.TRIANGLE_FAN]=t.TRIANGLE_FAN,e}r.__esModule=!0,r.default=n;var i=t("../../../const")},{"../../../const":42}],96:[function(t,e,r){"use strict";function n(t){var e=t.getContextAttributes();e.stencil||console.warn("Provided WebGL context does not have a stencil buffer, masks may not render correctly")}r.__esModule=!0,r.default=n},{}],97:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}r.__esModule=!0;var i=t("./utils/maxRecommendedTextures"),o=n(i),s=t("./utils/canUploadSameBuffer"),a=n(s);r.default={TARGET_FPMS:.06,MIPMAP_TEXTURES:!0,RESOLUTION:1,FILTER_RESOLUTION:1,SPRITE_MAX_TEXTURES:(0,o.default)(32),SPRITE_BATCH_SIZE:4096,RETINA_PREFIX:/@(.+)x/,RENDER_OPTIONS:{view:null,antialias:!1,forceFXAA:!1,autoResize:!1,transparent:!1,backgroundColor:0,clearBeforeRender:!0,preserveDrawingBuffer:!1,roundPixels:!1},TRANSFORM_MODE:0,GC_MODE:0,GC_MAX_IDLE:3600,GC_MAX_CHECK_COUNT:600,WRAP_MODE:0,SCALE_MODE:0,PRECISION:"mediump",CAN_UPLOAD_SAME_BUFFER:(0,a.default)()}},{"./utils/canUploadSameBuffer":114,"./utils/maxRecommendedTextures":118}],98:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}
function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),u=t("../math"),h=t("../utils"),l=t("../const"),c=t("../textures/Texture"),d=n(c),f=t("../display/Container"),p=n(f),v=new u.Point,y=function(t){function e(r){i(this,e);var n=o(this,t.call(this));return n._anchor=new u.ObservablePoint(n._onAnchorUpdate,n),n._texture=null,n._width=0,n._height=0,n._tint=null,n._tintRGB=null,n.tint=16777215,n.blendMode=l.BLEND_MODES.NORMAL,n.shader=null,n.cachedTint=16777215,n.texture=r||d.default.EMPTY,n.vertexData=new Float32Array(8),n.vertexTrimmedData=null,n._transformID=-1,n._textureID=-1,n}return s(e,t),e.prototype._onTextureUpdate=function(){this._textureID=-1,this._width&&(this.scale.x=(0,h.sign)(this.scale.x)*this._width/this.texture.orig.width),this._height&&(this.scale.y=(0,h.sign)(this.scale.y)*this._height/this.texture.orig.height)},e.prototype._onAnchorUpdate=function(){this._transformID=-1},e.prototype.calculateVertices=function(){if(this._transformID!==this.transform._worldID||this._textureID!==this._texture._updateID){this._transformID=this.transform._worldID,this._textureID=this._texture._updateID;var t=this._texture,e=this.transform.worldTransform,r=e.a,n=e.b,i=e.c,o=e.d,s=e.tx,a=e.ty,u=this.vertexData,h=t.trim,l=t.orig,c=this._anchor,d=0,f=0,p=0,v=0;h?(f=h.x-c._x*l.width,d=f+h.width,v=h.y-c._y*l.height,p=v+h.height):(d=l.width*(1-c._x),f=l.width*-c._x,p=l.height*(1-c._y),v=l.height*-c._y),u[0]=r*f+i*v+s,u[1]=o*v+n*f+a,u[2]=r*d+i*v+s,u[3]=o*v+n*d+a,u[4]=r*d+i*p+s,u[5]=o*p+n*d+a,u[6]=r*f+i*p+s,u[7]=o*p+n*f+a}},e.prototype.calculateTrimmedVertices=function(){this.vertexTrimmedData||(this.vertexTrimmedData=new Float32Array(8));var t=this._texture,e=this.vertexTrimmedData,r=t.orig,n=this._anchor,i=this.transform.worldTransform,o=i.a,s=i.b,a=i.c,u=i.d,h=i.tx,l=i.ty,c=r.width*(1-n._x),d=r.width*-n._x,f=r.height*(1-n._y),p=r.height*-n._y;e[0]=o*d+a*p+h,e[1]=u*p+s*d+l,e[2]=o*c+a*p+h,e[3]=u*p+s*c+l,e[4]=o*c+a*f+h,e[5]=u*f+s*c+l,e[6]=o*d+a*f+h,e[7]=u*f+s*d+l},e.prototype._renderWebGL=function(t){this.calculateVertices(),t.setObjectRenderer(t.plugins.sprite),t.plugins.sprite.render(this)},e.prototype._renderCanvas=function(t){t.plugins.sprite.render(this)},e.prototype._calculateBounds=function(){var t=this._texture.trim,e=this._texture.orig;!t||t.width===e.width&&t.height===e.height?(this.calculateVertices(),this._bounds.addQuad(this.vertexData)):(this.calculateTrimmedVertices(),this._bounds.addQuad(this.vertexTrimmedData))},e.prototype.getLocalBounds=function(e){return 0===this.children.length?(this._bounds.minX=this._texture.orig.width*-this._anchor._x,this._bounds.minY=this._texture.orig.height*-this._anchor._y,this._bounds.maxX=this._texture.orig.width*(1-this._anchor._x),this._bounds.maxY=this._texture.orig.height*(1-this._anchor._x),e||(this._localBoundsRect||(this._localBoundsRect=new u.Rectangle),e=this._localBoundsRect),this._bounds.getRectangle(e)):t.prototype.getLocalBounds.call(this,e)},e.prototype.containsPoint=function(t){this.worldTransform.applyInverse(t,v);var e=this._texture.orig.width,r=this._texture.orig.height,n=-e*this.anchor.x,i=0;return v.x>n&&v.x<n+e&&(i=-r*this.anchor.y,v.y>i&&v.y<i+r)},e.prototype.destroy=function(e){t.prototype.destroy.call(this,e),this._anchor=null;var r="boolean"==typeof e?e:e&&e.texture;if(r){var n="boolean"==typeof e?e:e&&e.baseTexture;this._texture.destroy(!!n)}this._texture=null,this.shader=null},e.from=function(t){return new e(d.default.from(t))},e.fromFrame=function(t){var r=h.TextureCache[t];if(!r)throw new Error('The frameId "'+t+'" does not exist in the texture cache');return new e(r)},e.fromImage=function(t,r,n){return new e(d.default.fromImage(t,r,n))},a(e,[{key:"width",get:function(){return Math.abs(this.scale.x)*this.texture.orig.width},set:function(t){var e=(0,h.sign)(this.scale.x)||1;this.scale.x=e*t/this.texture.orig.width,this._width=t}},{key:"height",get:function(){return Math.abs(this.scale.y)*this.texture.orig.height},set:function(t){var e=(0,h.sign)(this.scale.y)||1;this.scale.y=e*t/this.texture.orig.height,this._height=t}},{key:"anchor",get:function(){return this._anchor},set:function(t){this._anchor.copy(t)}},{key:"tint",get:function(){return this._tint},set:function(t){this._tint=t,this._tintRGB=(t>>16)+(65280&t)+((255&t)<<16)}},{key:"texture",get:function(){return this._texture},set:function(t){this._texture!==t&&(this._texture=t,this.cachedTint=16777215,this._textureID=-1,t&&(t.baseTexture.hasLoaded?this._onTextureUpdate():t.once("update",this._onTextureUpdate,this)))}}]),e}(p.default);r.default=y},{"../const":42,"../display/Container":44,"../math":66,"../textures/Texture":109,"../utils":117}],99:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=t("../../renderers/canvas/CanvasRenderer"),s=n(o),a=t("../../const"),u=t("../../math"),h=t("./CanvasTinter"),l=n(h),c=new u.Matrix,d=function(){function t(e){i(this,t),this.renderer=e}return t.prototype.render=function(t){var e=t._texture,r=this.renderer,n=e._frame.width,i=e._frame.height,o=t.transform.worldTransform,s=0,h=0;if(!(e.orig.width<=0||e.orig.height<=0)&&e.baseTexture.source&&(r.setBlendMode(t.blendMode),e.valid)){r.context.globalAlpha=t.worldAlpha;var d=e.baseTexture.scaleMode===a.SCALE_MODES.LINEAR;r.smoothProperty&&r.context[r.smoothProperty]!==d&&(r.context[r.smoothProperty]=d),e.trim?(s=e.trim.width/2+e.trim.x-t.anchor.x*e.orig.width,h=e.trim.height/2+e.trim.y-t.anchor.y*e.orig.height):(s=(.5-t.anchor.x)*e.orig.width,h=(.5-t.anchor.y)*e.orig.height),e.rotate&&(o.copy(c),o=c,u.GroupD8.matrixAppendRotationInv(o,e.rotate,s,h),s=0,h=0),s-=n/2,h-=i/2,r.roundPixels?(r.context.setTransform(o.a,o.b,o.c,o.d,o.tx*r.resolution|0,o.ty*r.resolution|0),s=0|s,h=0|h):r.context.setTransform(o.a,o.b,o.c,o.d,o.tx*r.resolution,o.ty*r.resolution);var f=e.baseTexture.resolution;16777215!==t.tint?(t.cachedTint!==t.tint&&(t.cachedTint=t.tint,t.tintedTexture=l.default.getTintedTexture(t,t.tint)),r.context.drawImage(t.tintedTexture,0,0,n*f,i*f,s*r.resolution,h*r.resolution,n*r.resolution,i*r.resolution)):r.context.drawImage(e.baseTexture.source,e._frame.x*f,e._frame.y*f,n*f,i*f,s*r.resolution,h*r.resolution,n*r.resolution,i*r.resolution)}},t.prototype.destroy=function(){this.renderer=null},t}();r.default=d,s.default.registerPlugin("sprite",d)},{"../../const":42,"../../math":66,"../../renderers/canvas/CanvasRenderer":73,"./CanvasTinter":100}],100:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}r.__esModule=!0;var i=t("../../utils"),o=t("../../renderers/canvas/utils/canUseNewCanvasBlendModes"),s=n(o),a={getTintedTexture:function(t,e){var r=t.texture;e=a.roundColor(e);var n="#"+("00000"+(0|e).toString(16)).substr(-6);if(r.tintCache=r.tintCache||{},r.tintCache[n])return r.tintCache[n];var i=a.canvas||document.createElement("canvas");if(a.tintMethod(r,e,i),a.convertTintToImage){var o=new Image;o.src=i.toDataURL(),r.tintCache[n]=o}else r.tintCache[n]=i,a.canvas=null;return i},tintWithMultiply:function(t,e,r){var n=r.getContext("2d"),i=t._frame.clone(),o=t.baseTexture.resolution;i.x*=o,i.y*=o,i.width*=o,i.height*=o,r.width=i.width,r.height=i.height,n.fillStyle="#"+("00000"+(0|e).toString(16)).substr(-6),n.fillRect(0,0,i.width,i.height),n.globalCompositeOperation="multiply",n.drawImage(t.baseTexture.source,i.x,i.y,i.width,i.height,0,0,i.width,i.height),n.globalCompositeOperation="destination-atop",n.drawImage(t.baseTexture.source,i.x,i.y,i.width,i.height,0,0,i.width,i.height)},tintWithOverlay:function(t,e,r){var n=r.getContext("2d"),i=t._frame.clone(),o=t.baseTexture.resolution;i.x*=o,i.y*=o,i.width*=o,i.height*=o,r.width=i.width,r.height=i.height,n.globalCompositeOperation="copy",n.fillStyle="#"+("00000"+(0|e).toString(16)).substr(-6),n.fillRect(0,0,i.width,i.height),n.globalCompositeOperation="destination-atop",n.drawImage(t.baseTexture.source,i.x,i.y,i.width,i.height,0,0,i.width,i.height)},tintWithPerPixel:function(t,e,r){var n=r.getContext("2d"),o=t._frame.clone(),s=t.baseTexture.resolution;o.x*=s,o.y*=s,o.width*=s,o.height*=s,r.width=o.width,r.height=o.height,n.globalCompositeOperation="copy",n.drawImage(t.baseTexture.source,o.x,o.y,o.width,o.height,0,0,o.width,o.height);for(var a=(0,i.hex2rgb)(e),u=a[0],h=a[1],l=a[2],c=n.getImageData(0,0,o.width,o.height),d=c.data,f=0;f<d.length;f+=4)d[f+0]*=u,d[f+1]*=h,d[f+2]*=l;n.putImageData(c,0,0)},roundColor:function(t){var e=a.cacheStepsPerColorChannel,r=(0,i.hex2rgb)(t);return r[0]=Math.min(255,r[0]/e*e),r[1]=Math.min(255,r[1]/e*e),r[2]=Math.min(255,r[2]/e*e),(0,i.rgb2hex)(r)},cacheStepsPerColorChannel:8,convertTintToImage:!1,canUseMultiply:(0,s.default)(),tintMethod:0};a.tintMethod=a.canUseMultiply?a.tintWithMultiply:a.tintWithPerPixel,r.default=a},{"../../renderers/canvas/utils/canUseNewCanvasBlendModes":76,"../../utils":117}],101:[function(t,e,r){"use strict";function n(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var i=function(){function t(e){n(this,t),this.vertices=new ArrayBuffer(e),this.float32View=new Float32Array(this.vertices),this.uint32View=new Uint32Array(this.vertices)}return t.prototype.destroy=function(){this.vertices=null,this.positions=null,this.uvs=null,this.colors=null},t}();r.default=i},{}],102:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("../../renderers/webgl/utils/ObjectRenderer"),u=n(a),h=t("../../renderers/webgl/WebGLRenderer"),l=n(h),c=t("../../utils/createIndicesForQuads"),d=n(c),f=t("./generateMultiTextureShader"),p=n(f),v=t("../../renderers/webgl/utils/checkMaxIfStatmentsInShader"),y=n(v),g=t("./BatchBuffer"),m=n(g),_=t("../../settings"),b=n(_),x=t("pixi-gl-core"),T=n(x),w=t("bit-twiddle"),E=n(w),O=b.default.SPRITE_BATCH_SIZE,S=b.default.SPRITE_MAX_TEXTURES,M=b.default.CAN_UPLOAD_SAME_BUFFER,P=0,C=0,R=function(t){function e(r){i(this,e);var n=o(this,t.call(this,r));n.vertSize=5,n.vertByteSize=4*n.vertSize,n.size=O,n.buffers=[];for(var s=1;s<=E.default.nextPow2(n.size);s*=2)n.buffers.push(new m.default(4*s*n.vertByteSize));n.indices=(0,d.default)(n.size),n.shader=null,n.currentIndex=0,P=0,n.groups=[];for(var a=0;a<n.size;a++)n.groups[a]={textures:[],textureCount:0,ids:[],size:0,start:0,blend:0};return n.sprites=[],n.vertexBuffers=[],n.vaos=[],n.vaoMax=2,n.vertexCount=0,n.renderer.on("prerender",n.onPrerender,n),n}return s(e,t),e.prototype.onContextChange=function(){var t=this.renderer.gl;this.MAX_TEXTURES=Math.min(t.getParameter(t.MAX_TEXTURE_IMAGE_UNITS),S),this.MAX_TEXTURES=(0,y.default)(this.MAX_TEXTURES,t);var e=this.shader=(0,p.default)(t,this.MAX_TEXTURES);this.indexBuffer=T.default.GLBuffer.createIndexBuffer(t,this.indices,t.STATIC_DRAW),this.renderer.bindVao(null);for(var r=0;r<this.vaoMax;r++)this.vertexBuffers[r]=T.default.GLBuffer.createVertexBuffer(t,null,t.STREAM_DRAW),this.vaos[r]=this.renderer.createVao().addIndex(this.indexBuffer).addAttribute(this.vertexBuffers[r],e.attributes.aVertexPosition,t.FLOAT,!1,this.vertByteSize,0).addAttribute(this.vertexBuffers[r],e.attributes.aTextureCoord,t.UNSIGNED_SHORT,!0,this.vertByteSize,8).addAttribute(this.vertexBuffers[r],e.attributes.aColor,t.UNSIGNED_BYTE,!0,this.vertByteSize,12).addAttribute(this.vertexBuffers[r],e.attributes.aTextureId,t.FLOAT,!1,this.vertByteSize,16);this.vao=this.vaos[0],this.currentBlendMode=99999,this.boundTextures=new Array(this.MAX_TEXTURES)},e.prototype.onPrerender=function(){this.vertexCount=0},e.prototype.render=function(t){this.currentIndex>=this.size&&this.flush(),t.texture._uvs&&(this.sprites[this.currentIndex++]=t)},e.prototype.flush=function(){if(0!==this.currentIndex){var t=this.renderer.gl,e=this.MAX_TEXTURES,r=E.default.nextPow2(this.currentIndex),n=E.default.log2(r),i=this.buffers[n],o=this.sprites,s=this.groups,a=i.float32View,u=i.uint32View,h=this.boundTextures,l=this.renderer.boundTextures,c=this.renderer.textureGC.count,d=0,f=void 0,p=void 0,v=1,y=0,g=s[0],m=void 0,_=void 0,b=o[0].blendMode;g.textureCount=0,g.start=0,g.blend=b,P++;var x=void 0;for(x=0;x<e;++x)h[x]=l[x],h[x]._virtalBoundId=x;for(x=0;x<this.currentIndex;++x){var w=o[x];if(f=w._texture.baseTexture,b!==w.blendMode&&(b=w.blendMode,p=null,y=e,P++),p!==f&&(p=f,f._enabled!==P)){if(y===e&&(P++,g.size=x-g.start,y=0,g=s[v++],g.blend=b,g.textureCount=0,g.start=x),f.touched=c,f._virtalBoundId===-1)for(var O=0;O<e;++O){var S=(O+C)%e,R=h[S];if(R._enabled!==P){C++,R._virtalBoundId=-1,f._virtalBoundId=S,h[S]=f;break}}f._enabled=P,g.textureCount++,g.ids[y]=f._virtalBoundId,g.textures[y++]=f}if(m=w.vertexData,_=w._texture._uvs.uvsUint32,this.renderer.roundPixels){var D=this.renderer.resolution;a[d]=(m[0]*D|0)/D,a[d+1]=(m[1]*D|0)/D,a[d+5]=(m[2]*D|0)/D,a[d+6]=(m[3]*D|0)/D,a[d+10]=(m[4]*D|0)/D,a[d+11]=(m[5]*D|0)/D,a[d+15]=(m[6]*D|0)/D,a[d+16]=(m[7]*D|0)/D}else a[d]=m[0],a[d+1]=m[1],a[d+5]=m[2],a[d+6]=m[3],a[d+10]=m[4],a[d+11]=m[5],a[d+15]=m[6],a[d+16]=m[7];u[d+2]=_[0],u[d+7]=_[1],u[d+12]=_[2],u[d+17]=_[3],u[d+3]=u[d+8]=u[d+13]=u[d+18]=w._tintRGB+(255*w.worldAlpha<<24),a[d+4]=a[d+9]=a[d+14]=a[d+19]=f._virtalBoundId,d+=20}for(g.size=x-g.start,M?this.vertexBuffers[this.vertexCount].upload(i.vertices,0,!0):(this.vaoMax<=this.vertexCount&&(this.vaoMax++,this.vertexBuffers[this.vertexCount]=T.default.GLBuffer.createVertexBuffer(t,null,t.STREAM_DRAW),this.vaos[this.vertexCount]=this.renderer.createVao().addIndex(this.indexBuffer).addAttribute(this.vertexBuffers[this.vertexCount],this.shader.attributes.aVertexPosition,t.FLOAT,!1,this.vertByteSize,0).addAttribute(this.vertexBuffers[this.vertexCount],this.shader.attributes.aTextureCoord,t.UNSIGNED_SHORT,!0,this.vertByteSize,8).addAttribute(this.vertexBuffers[this.vertexCount],this.shader.attributes.aColor,t.UNSIGNED_BYTE,!0,this.vertByteSize,12).addAttribute(this.vertexBuffers[this.vertexCount],this.shader.attributes.aTextureId,t.FLOAT,!1,this.vertByteSize,16)),this.renderer.bindVao(this.vaos[this.vertexCount]),this.vertexBuffers[this.vertexCount].upload(i.vertices,0,!1),this.vertexCount++),x=0;x<e;++x)l[x]._virtalBoundId=-1;for(x=0;x<v;++x){for(var A=s[x],I=A.textureCount,L=0;L<I;L++)p=A.textures[L],l[A.ids[L]]!==p&&this.renderer.bindTexture(p,A.ids[L],!0),p._virtalBoundId=-1;this.renderer.state.setBlendMode(A.blend),t.drawElements(t.TRIANGLES,6*A.size,t.UNSIGNED_SHORT,6*A.start*2)}this.currentIndex=0}},e.prototype.start=function(){this.renderer.bindShader(this.shader),M&&(this.renderer.bindVao(this.vaos[this.vertexCount]),this.vertexBuffers[this.vertexCount].bind())},e.prototype.stop=function(){this.flush()},e.prototype.destroy=function(){for(var e=0;e<this.vaoMax;e++)this.vertexBuffers[e]&&this.vertexBuffers[e].destroy(),this.vaos[e]&&this.vaos[e].destroy();this.indexBuffer&&this.indexBuffer.destroy(),this.renderer.off("prerender",this.onPrerender,this),t.prototype.destroy.call(this),this.shader&&(this.shader.destroy(),this.shader=null),this.vertexBuffers=null,this.vaos=null,this.indexBuffer=null,this.indices=null,this.sprites=null;for(var r=0;r<this.buffers.length;++r)this.buffers[r].destroy()},e}(u.default);r.default=R,l.default.registerPlugin("sprite",R)},{"../../renderers/webgl/WebGLRenderer":80,"../../renderers/webgl/utils/ObjectRenderer":90,"../../renderers/webgl/utils/checkMaxIfStatmentsInShader":93,"../../settings":97,"../../utils/createIndicesForQuads":115,"./BatchBuffer":101,"./generateMultiTextureShader":103,"bit-twiddle":1,"pixi-gl-core":12}],103:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){var r="attribute vec2 aVertexPosition;\nattribute vec2 aTextureCoord;\nattribute vec4 aColor;\nattribute float aTextureId;\n\nuniform mat3 projectionMatrix;\n\nvarying vec2 vTextureCoord;\nvarying vec4 vColor;\nvarying float vTextureId;\n\nvoid main(void){\n    gl_Position = vec4((projectionMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);\n\n    vTextureCoord = aTextureCoord;\n    vTextureId = aTextureId;\n    vColor = vec4(aColor.rgb * aColor.a, aColor.a);\n}\n",n=u;n=n.replace(/%count%/gi,e),n=n.replace(/%forloop%/gi,o(e));for(var i=new a.default(t,r,n),s=[],h=0;h<e;h++)s[h]=h;return i.bind(),i.uniforms.uSamplers=s,i}function o(t){var e="";e+="\n",e+="\n";for(var r=0;r<t;r++)r>0&&(e+="\nelse "),r<t-1&&(e+="if(textureId == "+r+".0)"),e+="\n{",e+="\n\tcolor = texture2D(uSamplers["+r+"], vTextureCoord);",e+="\n}";return e+="\n",e+="\n"}r.__esModule=!0,r.default=i;var s=t("../../Shader"),a=n(s),u=(t("path"),["varying vec2 vTextureCoord;","varying vec4 vColor;","varying float vTextureId;","uniform sampler2D uSamplers[%count%];","void main(void){","vec4 color;","float textureId = floor(vTextureId+0.5);","%forloop%","gl_FragColor = color * vColor;","}"].join("\n"))},{"../../Shader":41,path:22}],104:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),u=t("../sprites/Sprite"),h=n(u),l=t("../textures/Texture"),c=n(l),d=t("../math"),f=t("../utils"),p=t("../const"),v=t("../settings"),y=n(v),g=t("./TextStyle"),m=n(g),_=y.default.RESOLUTION,b={texture:!0,children:!1,baseTexture:!0},x=function(t){function e(r,n){i(this,e);var s=document.createElement("canvas");s.width=3,s.height=3;var a=c.default.fromCanvas(s);a.orig=new d.Rectangle,a.trim=new d.Rectangle;var u=o(this,t.call(this,a));return u.canvas=s,u.context=u.canvas.getContext("2d"),u.resolution=_,u._text=null,u._style=null,u._styleListener=null,u._font="",u.text=r,u.style=n,u.localStyleID=-1,u}return s(e,t),e.prototype.updateText=function(t){var r=this._style;if(this.localStyleID!==r.styleID&&(this.dirty=!0,this.localStyleID=r.styleID),this.dirty||!t){this._font=e.getFontStyle(r),this.context.font=this._font;for(var n=r.wordWrap?this.wordWrap(this._text):this._text,i=n.split(/(?:\r\n|\r|\n)/),o=new Array(i.length),s=0,a=e.calculateFontProperties(this._font),u=0;u<i.length;u++){var h=this.context.measureText(i[u]).width+(i[u].length-1)*r.letterSpacing;o[u]=h,s=Math.max(s,h)}var l=s+r.strokeThickness;r.dropShadow&&(l+=r.dropShadowDistance),l+=2*r.padding,this.canvas.width=Math.ceil((l+this.context.lineWidth)*this.resolution);var c=this.style.lineHeight||a.fontSize+r.strokeThickness,d=Math.max(c,a.fontSize+r.strokeThickness)+(i.length-1)*c;r.dropShadow&&(d+=r.dropShadowDistance),this.canvas.height=Math.ceil((d+2*this._style.padding)*this.resolution),this.context.scale(this.resolution,this.resolution),this.context.clearRect(0,0,this.canvas.width,this.canvas.height),this.context.font=this._font,this.context.strokeStyle=r.stroke,this.context.lineWidth=r.strokeThickness,this.context.textBaseline=r.textBaseline,this.context.lineJoin=r.lineJoin,this.context.miterLimit=r.miterLimit;var f=void 0,p=void 0;if(r.dropShadow){r.dropShadowBlur>0?(this.context.shadowColor=r.dropShadowColor,this.context.shadowBlur=r.dropShadowBlur):this.context.fillStyle=r.dropShadowColor;for(var v=Math.cos(r.dropShadowAngle)*r.dropShadowDistance,y=Math.sin(r.dropShadowAngle)*r.dropShadowDistance,g=0;g<i.length;g++)f=r.strokeThickness/2,p=r.strokeThickness/2+g*c+a.ascent,"right"===r.align?f+=s-o[g]:"center"===r.align&&(f+=(s-o[g])/2),r.fill&&(this.drawLetterSpacing(i[g],f+v+r.padding,p+y+r.padding),r.stroke&&r.strokeThickness&&(this.context.strokeStyle=r.dropShadowColor,this.drawLetterSpacing(i[g],f+v+r.padding,p+y+r.padding,!0),this.context.strokeStyle=r.stroke))}this.context.fillStyle=this._generateFillStyle(r,i);for(var m=0;m<i.length;m++)f=r.strokeThickness/2,p=r.strokeThickness/2+m*c+a.ascent,"right"===r.align?f+=s-o[m]:"center"===r.align&&(f+=(s-o[m])/2),r.stroke&&r.strokeThickness&&this.drawLetterSpacing(i[m],f+r.padding,p+r.padding,!0),r.fill&&this.drawLetterSpacing(i[m],f+r.padding,p+r.padding);this.updateTexture()}},e.prototype.drawLetterSpacing=function(t,e,r){var n=!(arguments.length<=3||void 0===arguments[3])&&arguments[3],i=this._style,o=i.letterSpacing;if(0===o)return void(n?this.context.strokeText(t,e,r):this.context.fillText(t,e,r));for(var s=String.prototype.split.call(t,""),a=e,u=0,h="";u<t.length;)h=s[u++],n?this.context.strokeText(h,a,r):this.context.fillText(h,a,r),a+=this.context.measureText(h).width+o},e.prototype.updateTexture=function(){var t=this._texture,e=this._style;t.baseTexture.hasLoaded=!0,t.baseTexture.resolution=this.resolution,t.baseTexture.realWidth=this.canvas.width,t.baseTexture.realHeight=this.canvas.height,t.baseTexture.width=this.canvas.width/this.resolution,t.baseTexture.height=this.canvas.height/this.resolution,t.trim.width=t._frame.width=this.canvas.width/this.resolution,t.trim.height=t._frame.height=this.canvas.height/this.resolution,t.trim.x=-e.padding,t.trim.y=-e.padding,t.orig.width=t._frame.width-2*e.padding,t.orig.height=t._frame.height-2*e.padding,this._onTextureUpdate(),t.baseTexture.emit("update",t.baseTexture),this.dirty=!1},e.prototype.renderWebGL=function(e){this.resolution!==e.resolution&&(this.resolution=e.resolution,this.dirty=!0),this.updateText(!0),t.prototype.renderWebGL.call(this,e)},e.prototype._renderCanvas=function(e){this.resolution!==e.resolution&&(this.resolution=e.resolution,this.dirty=!0),this.updateText(!0),t.prototype._renderCanvas.call(this,e)},e.prototype.wordWrap=function(t){for(var e="",r=t.split("\n"),n=this._style.wordWrapWidth,i=0;i<r.length;i++){for(var o=n,s=r[i].split(" "),a=0;a<s.length;a++){var u=this.context.measureText(s[a]).width;if(this._style.breakWords&&u>n)for(var h=s[a].split(""),l=0;l<h.length;l++){var c=this.context.measureText(h[l]).width;c>o?(e+="\n"+h[l],o=n-c):(0===l&&(e+=" "),e+=h[l],o-=c)}else{var d=u+this.context.measureText(" ").width;0===a||d>o?(a>0&&(e+="\n"),e+=s[a],o=n-u):(o-=d,e+=" "+s[a])}}i<r.length-1&&(e+="\n")}return e},e.prototype._calculateBounds=function(){this.updateText(!0),this.calculateVertices(),this._bounds.addQuad(this.vertexData)},e.prototype._onStyleChange=function(){this.dirty=!0},e.prototype._generateFillStyle=function(t,e){if(!Array.isArray(t.fill))return t.fill;if(navigator.isCocoonJS)return t.fill[0];var r=void 0,n=void 0,i=void 0,o=void 0,s=this.canvas.width/this.resolution,a=this.canvas.height/this.resolution;if(t.fillGradientType===p.TEXT_GRADIENT.LINEAR_VERTICAL){r=this.context.createLinearGradient(s/2,0,s/2,a),n=(t.fill.length+1)*e.length,i=0;for(var u=0;u<e.length;u++){i+=1;for(var h=0;h<t.fill.length;h++)o=i/n,r.addColorStop(o,t.fill[h]),i++}}else{r=this.context.createLinearGradient(0,a/2,s,a/2),n=t.fill.length+1,i=1;for(var l=0;l<t.fill.length;l++)o=i/n,r.addColorStop(o,t.fill[l]),i++}return r},e.prototype.destroy=function(e){"boolean"==typeof e&&(e={children:e}),e=Object.assign({},b,e),t.prototype.destroy.call(this,e),this.context=null,this.canvas=null,this._style=null},e.getFontStyle=function(t){t=t||{},t instanceof m.default||(t=new m.default(t));var e="number"==typeof t.fontSize?t.fontSize+"px":t.fontSize;return t.fontStyle+" "+t.fontVariant+" "+t.fontWeight+" "+e+" "+t.fontFamily},e.calculateFontProperties=function(t){if(e.fontPropertiesCache[t])return e.fontPropertiesCache[t];var r={},n=e.fontPropertiesCanvas,i=e.fontPropertiesContext;i.font=t;var o=Math.ceil(i.measureText("|MÉq").width),s=Math.ceil(i.measureText("M").width),a=2*s;s=1.4*s|0,n.width=o,n.height=a,i.fillStyle="#f00",i.fillRect(0,0,o,a),i.font=t,i.textBaseline="alphabetic",i.fillStyle="#000",i.fillText("|MÉq",0,s);var u=i.getImageData(0,0,o,a).data,h=u.length,l=4*o,c=0,d=0,f=!1;for(c=0;c<s;++c){for(var p=0;p<l;p+=4)if(255!==u[d+p]){f=!0;break}if(f)break;d+=l}for(r.ascent=s-c,d=h-l,f=!1,c=a;c>s;--c){for(var v=0;v<l;v+=4)if(255!==u[d+v]){f=!0;break}if(f)break;d-=l}return r.descent=c-s,r.fontSize=r.ascent+r.descent,e.fontPropertiesCache[t]=r,r},a(e,[{key:"width",get:function(){return this.updateText(!0),Math.abs(this.scale.x)*this.texture.orig.width},set:function(t){this.updateText(!0);var e=(0,f.sign)(this.scale.x)||1;this.scale.x=e*t/this.texture.orig.width,this._width=t}},{key:"height",get:function(){return this.updateText(!0),Math.abs(this.scale.y)*this._texture.orig.height},set:function(t){this.updateText(!0);var e=(0,f.sign)(this.scale.y)||1;this.scale.y=e*t/this.texture.orig.height,this._height=t}},{key:"style",get:function(){return this._style},set:function(t){t=t||{},t instanceof m.default?this._style=t:this._style=new m.default(t),this.localStyleID=-1,this.dirty=!0}},{key:"text",get:function(){return this._text},set:function(t){t=t||" ",t=t.toString(),this._text!==t&&(this._text=t,this.dirty=!0)}}]),e}(h.default);r.default=x,x.fontPropertiesCache={},x.fontPropertiesCanvas=document.createElement("canvas"),x.fontPropertiesContext=x.fontPropertiesCanvas.getContext("2d")},{"../const":42,"../math":66,"../settings":97,"../sprites/Sprite":98,"../textures/Texture":109,"../utils":117,"./TextStyle":105}],105:[function(t,e,r){"use strict";function n(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function i(t){if("number"==typeof t)return(0,a.hex2string)(t);if(Array.isArray(t))for(var e=0;e<t.length;++e)"number"==typeof t[e]&&(t[e]=(0,a.hex2string)(t[e]));return t}r.__esModule=!0;var o=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),s=t("../const"),a=t("../utils"),u={align:"left",breakWords:!1,dropShadow:!1,dropShadowAngle:Math.PI/6,dropShadowBlur:0,dropShadowColor:"#000000",dropShadowDistance:5,fill:"black",fillGradientType:s.TEXT_GRADIENT.LINEAR_VERTICAL,fontFamily:"Arial",fontSize:26,fontStyle:"normal",fontVariant:"normal",fontWeight:"normal",letterSpacing:0,lineHeight:0,lineJoin:"miter",miterLimit:10,padding:0,stroke:"black",strokeThickness:0,textBaseline:"alphabetic",wordWrap:!1,wordWrapWidth:100},h=function(){function t(e){n(this,t),this.styleID=0,Object.assign(this,u,e)}return t.prototype.clone=function(){var e={};for(var r in this._defaults)e[r]=this[r];return new t(e)},t.prototype.reset=function(){Object.assign(this,this._defaults)},o(t,[{key:"align",get:function(){return this._align},set:function(t){this._align!==t&&(this._align=t,this.styleID++)}},{key:"breakWords",get:function(){return this._breakWords},set:function(t){this._breakWords!==t&&(this._breakWords=t,this.styleID++)}},{key:"dropShadow",get:function(){return this._dropShadow},set:function(t){this._dropShadow!==t&&(this._dropShadow=t,this.styleID++)}},{key:"dropShadowAngle",get:function(){return this._dropShadowAngle},set:function(t){this._dropShadowAngle!==t&&(this._dropShadowAngle=t,this.styleID++)}},{key:"dropShadowBlur",get:function(){return this._dropShadowBlur},set:function(t){this._dropShadowBlur!==t&&(this._dropShadowBlur=t,this.styleID++)}},{key:"dropShadowColor",get:function(){return this._dropShadowColor},set:function(t){var e=i(t);this._dropShadowColor!==e&&(this._dropShadowColor=e,this.styleID++)}},{key:"dropShadowDistance",get:function(){return this._dropShadowDistance},set:function(t){this._dropShadowDistance!==t&&(this._dropShadowDistance=t,this.styleID++)}},{key:"fill",get:function(){return this._fill},set:function(t){var e=i(t);this._fill!==e&&(this._fill=e,this.styleID++)}},{key:"fillGradientType",get:function(){return this._fillGradientType},set:function(t){this._fillGradientType!==t&&(this._fillGradientType=t,this.styleID++)}},{key:"fontFamily",get:function(){return this._fontFamily},set:function(t){this.fontFamily!==t&&(this._fontFamily=t,this.styleID++)}},{key:"fontSize",get:function(){return this._fontSize},set:function(t){this._fontSize!==t&&(this._fontSize=t,this.styleID++)}},{key:"fontStyle",get:function(){return this._fontStyle},set:function(t){this._fontStyle!==t&&(this._fontStyle=t,this.styleID++)}},{key:"fontVariant",get:function(){return this._fontVariant},set:function(t){this._fontVariant!==t&&(this._fontVariant=t,this.styleID++)}},{key:"fontWeight",get:function(){return this._fontWeight},set:function(t){this._fontWeight!==t&&(this._fontWeight=t,this.styleID++)}},{key:"letterSpacing",get:function(){return this._letterSpacing},set:function(t){this._letterSpacing!==t&&(this._letterSpacing=t,this.styleID++)}},{key:"lineHeight",get:function(){return this._lineHeight},set:function(t){this._lineHeight!==t&&(this._lineHeight=t,this.styleID++)}},{key:"lineJoin",get:function(){return this._lineJoin},set:function(t){this._lineJoin!==t&&(this._lineJoin=t,this.styleID++)}},{key:"miterLimit",get:function(){return this._miterLimit},set:function(t){this._miterLimit!==t&&(this._miterLimit=t,this.styleID++)}},{key:"padding",get:function(){return this._padding},set:function(t){this._padding!==t&&(this._padding=t,this.styleID++)}},{key:"stroke",get:function(){return this._stroke},set:function(t){var e=i(t);this._stroke!==e&&(this._stroke=e,this.styleID++)}},{key:"strokeThickness",get:function(){return this._strokeThickness},set:function(t){this._strokeThickness!==t&&(this._strokeThickness=t,this.styleID++)}},{key:"textBaseline",get:function(){return this._textBaseline},set:function(t){this._textBaseline!==t&&(this._textBaseline=t,this.styleID++)}},{key:"wordWrap",get:function(){return this._wordWrap},set:function(t){this._wordWrap!==t&&(this._wordWrap=t,this.styleID++)}},{key:"wordWrapWidth",get:function(){return this._wordWrapWidth},set:function(t){this._wordWrapWidth!==t&&(this._wordWrapWidth=t,this.styleID++)}}]),t}();r.default=h},{"../const":42,"../utils":117}],106:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,
enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("./BaseTexture"),u=n(a),h=t("../settings"),l=n(h),c=l.default.RESOLUTION,d=l.default.SCALE_MODE,f=function(t){function e(){var r=arguments.length<=0||void 0===arguments[0]?100:arguments[0],n=arguments.length<=1||void 0===arguments[1]?100:arguments[1],s=arguments[2],a=arguments[3];i(this,e);var u=o(this,t.call(this,null,s));return u.resolution=a||c,u.width=r,u.height=n,u.realWidth=u.width*u.resolution,u.realHeight=u.height*u.resolution,u.scaleMode=s||d,u.hasLoaded=!0,u._glRenderTargets={},u._canvasRenderTarget=null,u.valid=!1,u}return s(e,t),e.prototype.resize=function(t,e){t===this.width&&e===this.height||(this.valid=t>0&&e>0,this.width=t,this.height=e,this.realWidth=this.width*this.resolution,this.realHeight=this.height*this.resolution,this.valid&&this.emit("update",this))},e.prototype.destroy=function(){t.prototype.destroy.call(this,!0),this.renderer=null},e}(u.default);r.default=f},{"../settings":97,"./BaseTexture":107}],107:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a="function"==typeof Symbol&&"symbol"==typeof Symbol.iterator?function(t){return typeof t}:function(t){return t&&"function"==typeof Symbol&&t.constructor===Symbol?"symbol":typeof t},u=t("../utils"),h=t("../settings"),l=n(h),c=t("eventemitter3"),d=n(c),f=t("../utils/determineCrossOrigin"),p=n(f),v=t("bit-twiddle"),y=n(v),g=l.default.RESOLUTION,m=l.default.MIPMAP_TEXTURES,_=l.default.SCALE_MODE,b=l.default.WRAP_MODE,x=function(t){function e(r,n,s){i(this,e);var a=o(this,t.call(this));return a.uid=(0,u.uid)(),a.touched=0,a.resolution=s||g,a.width=100,a.height=100,a.realWidth=100,a.realHeight=100,a.scaleMode=n||_,a.hasLoaded=!1,a.isLoading=!1,a.source=null,a.origSource=null,a.imageType=null,a.sourceScale=1,a.premultipliedAlpha=!0,a.imageUrl=null,a.isPowerOfTwo=!1,a.mipmap=m,a.wrapMode=b,a._glTextures={},a._enabled=0,a._virtalBoundId=-1,r&&a.loadSource(r),a}return s(e,t),e.prototype.update=function(){"svg"!==this.imageType&&(this.realWidth=this.source.naturalWidth||this.source.videoWidth||this.source.width,this.realHeight=this.source.naturalHeight||this.source.videoHeight||this.source.height,this.width=this.realWidth/this.resolution,this.height=this.realHeight/this.resolution,this.isPowerOfTwo=y.default.isPow2(this.realWidth)&&y.default.isPow2(this.realHeight)),this.emit("update",this)},e.prototype.loadSource=function(t){var e=this,r=this.isLoading;this.hasLoaded=!1,this.isLoading=!1,r&&this.source&&(this.source.onload=null,this.source.onerror=null);var n=!this.source;if(this.source=t,(t.src&&t.complete||t.getContext)&&t.width&&t.height)this._updateImageType(),"svg"===this.imageType?this._loadSvgSource():this._sourceLoaded(),n&&this.emit("loaded",this);else if(!t.getContext){var i=function(){e.isLoading=!0;var n=e;if(t.onload=function(){if(n._updateImageType(),t.onload=null,t.onerror=null,n.isLoading)return n.isLoading=!1,n._sourceLoaded(),"svg"===n.imageType?void n._loadSvgSource():void n.emit("loaded",n)},t.onerror=function(){t.onload=null,t.onerror=null,n.isLoading&&(n.isLoading=!1,n.emit("error",n))},t.complete&&t.src){if(t.onload=null,t.onerror=null,"svg"===n.imageType)return n._loadSvgSource(),{v:void 0};e.isLoading=!1,t.width&&t.height?(e._sourceLoaded(),r&&e.emit("loaded",e)):r&&e.emit("error",e)}}();if("object"===("undefined"==typeof i?"undefined":a(i)))return i.v}},e.prototype._updateImageType=function(){if(this.imageUrl){var t=(0,u.decomposeDataUri)(this.imageUrl),e=void 0;if(t&&"image"===t.mediaType){var r=t.subType.split("+")[0];if(e=(0,u.getUrlFileExtension)("."+r),!e)throw new Error("Invalid image type in data URI.")}else e=(0,u.getUrlFileExtension)(this.imageUrl),e||(e="png");this.imageType=e}},e.prototype._loadSvgSource=function(){if("svg"===this.imageType){var t=(0,u.decomposeDataUri)(this.imageUrl);t?this._loadSvgSourceUsingDataUri(t):this._loadSvgSourceUsingXhr()}},e.prototype._loadSvgSourceUsingDataUri=function(t){var e=void 0;if("base64"===t.encoding){if(!atob)throw new Error("Your browser doesn't support base64 conversions.");e=atob(t.data)}else e=t.data;this._loadSvgSourceUsingString(e)},e.prototype._loadSvgSourceUsingXhr=function(){var t=this,e=new XMLHttpRequest;e.onload=function(){if(e.readyState!==e.DONE||200!==e.status)throw new Error("Failed to load SVG using XHR.");t._loadSvgSourceUsingString(e.response)},e.onerror=function(){return t.emit("error",t)},e.open("GET",this.imageUrl,!0),e.send()},e.prototype._loadSvgSourceUsingString=function(t){var e=(0,u.getSvgSize)(t),r=e.width,n=e.height;if(!r||!n)throw new Error("The SVG image must have width and height defined (in pixels), canvas API needs them.");this.realWidth=Math.round(r*this.sourceScale),this.realHeight=Math.round(n*this.sourceScale),this.width=this.realWidth/this.resolution,this.height=this.realHeight/this.resolution,this.isPowerOfTwo=y.default.isPow2(this.realWidth)&&y.default.isPow2(this.realHeight);var i=document.createElement("canvas");i.width=this.realWidth,i.height=this.realHeight,i._pixiId="canvas_"+(0,u.uid)(),i.getContext("2d").drawImage(this.source,0,0,r,n,0,0,this.realWidth,this.realHeight),this.origSource=this.source,this.source=i,u.BaseTextureCache[i._pixiId]=this,this.isLoading=!1,this._sourceLoaded(),this.emit("loaded",this)},e.prototype._sourceLoaded=function(){this.hasLoaded=!0,this.update()},e.prototype.destroy=function(){this.imageUrl&&(delete u.BaseTextureCache[this.imageUrl],delete u.TextureCache[this.imageUrl],this.imageUrl=null,navigator.isCocoonJS||(this.source.src="")),this.source&&this.source._pixiId&&delete u.BaseTextureCache[this.source._pixiId],this.source=null,this.dispose()},e.prototype.dispose=function(){this.emit("dispose",this)},e.prototype.updateSourceImage=function(t){this.source.src=t,this.loadSource(this.source)},e.fromImage=function(t,r,n,i){var o=u.BaseTextureCache[t];if(!o){var s=new Image;void 0===r&&0!==t.indexOf("data:")&&(s.crossOrigin=(0,p.default)(t)),o=new e(s,n),o.imageUrl=t,i&&(o.sourceScale=i),o.resolution=(0,u.getResolutionOfUrl)(t),s.src=t,u.BaseTextureCache[t]=o}return o},e.fromCanvas=function(t,r){t._pixiId||(t._pixiId="canvas_"+(0,u.uid)());var n=u.BaseTextureCache[t._pixiId];return n||(n=new e(t,r),u.BaseTextureCache[t._pixiId]=n),n},e}(d.default);r.default=x},{"../settings":97,"../utils":117,"../utils/determineCrossOrigin":116,"bit-twiddle":1,eventemitter3:3}],108:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("./BaseRenderTexture"),u=n(a),h=t("./Texture"),l=n(h),c=function(t){function e(r,n){i(this,e);var s=null;if(!(r instanceof u.default)){var a=arguments[1],h=arguments[2],l=arguments[3]||0,c=arguments[4]||1;console.warn("Please use RenderTexture.create("+a+", "+h+") instead of the ctor directly."),s=arguments[0],n=null,r=new u.default(a,h,l,c)}var d=o(this,t.call(this,r,n));return d.legacyRenderer=s,d.valid=!0,d._updateUvs(),d}return s(e,t),e.prototype.resize=function(t,e,r){this.valid=t>0&&e>0,this._frame.width=this.orig.width=t,this._frame.height=this.orig.height=e,r||this.baseTexture.resize(t,e),this._updateUvs()},e.create=function(t,r,n,i){return new e(new u.default(t,r,n,i))},e}(l.default);r.default=c},{"./BaseRenderTexture":106,"./Texture":109}],109:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),u=t("./BaseTexture"),h=n(u),l=t("./VideoBaseTexture"),c=n(l),d=t("./TextureUvs"),f=n(d),p=t("eventemitter3"),v=n(p),y=t("../math"),g=t("../utils"),m=function(t){function e(r,n,s,a,u){i(this,e);var h=o(this,t.call(this));if(h.noFrame=!1,n||(h.noFrame=!0,n=new y.Rectangle(0,0,1,1)),r instanceof e&&(r=r.baseTexture),h.baseTexture=r,h._frame=n,h.trim=a,h.valid=!1,h.requiresUpdate=!1,h._uvs=null,h.orig=s||n,h._rotate=Number(u||0),u===!0)h._rotate=2;else if(h._rotate%2!==0)throw new Error("attempt to use diamond-shaped UVs. If you are sure, set rotation manually");return r.hasLoaded?(h.noFrame&&(n=new y.Rectangle(0,0,r.width,r.height),r.on("update",h.onBaseTextureUpdated,h)),h.frame=n):r.once("loaded",h.onBaseTextureLoaded,h),h._updateID=0,h.transform=null,h}return s(e,t),e.prototype.update=function(){this.baseTexture.update()},e.prototype.onBaseTextureLoaded=function(t){this._updateID++,this.noFrame?this.frame=new y.Rectangle(0,0,t.width,t.height):this.frame=this._frame,this.baseTexture.on("update",this.onBaseTextureUpdated,this),this.emit("update",this)},e.prototype.onBaseTextureUpdated=function(t){this._updateID++,this._frame.width=t.width,this._frame.height=t.height,this.emit("update",this)},e.prototype.destroy=function(t){this.baseTexture&&(t&&(g.TextureCache[this.baseTexture.imageUrl]&&delete g.TextureCache[this.baseTexture.imageUrl],this.baseTexture.destroy()),this.baseTexture.off("update",this.onBaseTextureUpdated,this),this.baseTexture.off("loaded",this.onBaseTextureLoaded,this),this.baseTexture=null),this._frame=null,this._uvs=null,this.trim=null,this.orig=null,this.valid=!1,this.off("dispose",this.dispose,this),this.off("update",this.update,this)},e.prototype.clone=function(){return new e(this.baseTexture,this.frame,this.orig,this.trim,this.rotate)},e.prototype._updateUvs=function(){this._uvs||(this._uvs=new f.default),this._uvs.set(this._frame,this.baseTexture,this.rotate),this._updateID++},e.fromImage=function(t,r,n,i){var o=g.TextureCache[t];return o||(o=new e(h.default.fromImage(t,r,n,i)),g.TextureCache[t]=o),o},e.fromFrame=function(t){var e=g.TextureCache[t];if(!e)throw new Error('The frameId "'+t+'" does not exist in the texture cache');return e},e.fromCanvas=function(t,r){return new e(h.default.fromCanvas(t,r))},e.fromVideo=function(t,r){return"string"==typeof t?e.fromVideoUrl(t,r):new e(c.default.fromVideo(t,r))},e.fromVideoUrl=function(t,r){return new e(c.default.fromUrl(t,r))},e.from=function(t){if("string"==typeof t){var r=g.TextureCache[t];if(!r){var n=null!==t.match(/\.(mp4|webm|ogg|h264|avi|mov)$/);return n?e.fromVideoUrl(t):e.fromImage(t)}return r}return t instanceof HTMLImageElement?new e(new h.default(t)):t instanceof HTMLCanvasElement?e.fromCanvas(t):t instanceof HTMLVideoElement?e.fromVideo(t):t instanceof h.default?new e(t):t},e.addTextureToCache=function(t,e){g.TextureCache[e]=t},e.removeTextureFromCache=function(t){var e=g.TextureCache[t];return delete g.TextureCache[t],delete g.BaseTextureCache[t],e},a(e,[{key:"frame",get:function(){return this._frame},set:function(t){if(this._frame=t,this.noFrame=!1,t.x+t.width>this.baseTexture.width||t.y+t.height>this.baseTexture.height)throw new Error("Texture Error: frame does not fit inside the base Texture dimensions "+this);this.valid=t&&t.width&&t.height&&this.baseTexture.hasLoaded,this.trim||this.rotate||(this.orig=t),this.valid&&this._updateUvs()}},{key:"rotate",get:function(){return this._rotate},set:function(t){this._rotate=t,this.valid&&this._updateUvs()}},{key:"width",get:function(){return this.orig?this.orig.width:0}},{key:"height",get:function(){return this.orig?this.orig.height:0}}]),e}(v.default);r.default=m,m.EMPTY=new m(new h.default),m.EMPTY.destroy=function(){},m.EMPTY.on=function(){},m.EMPTY.once=function(){},m.EMPTY.emit=function(){}},{"../math":66,"../utils":117,"./BaseTexture":107,"./TextureUvs":110,"./VideoBaseTexture":111,eventemitter3:3}],110:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=t("../math/GroupD8"),s=n(o),a=function(){function t(){i(this,t),this.x0=0,this.y0=0,this.x1=1,this.y1=0,this.x2=1,this.y2=1,this.x3=0,this.y3=1,this.uvsUint32=new Uint32Array(4)}return t.prototype.set=function(t,e,r){var n=e.width,i=e.height;if(r){var o=t.width/2/n,a=t.height/2/i,u=t.x/n+o,h=t.y/i+a;r=s.default.add(r,s.default.NW),this.x0=u+o*s.default.uX(r),this.y0=h+a*s.default.uY(r),r=s.default.add(r,2),this.x1=u+o*s.default.uX(r),this.y1=h+a*s.default.uY(r),r=s.default.add(r,2),this.x2=u+o*s.default.uX(r),this.y2=h+a*s.default.uY(r),r=s.default.add(r,2),this.x3=u+o*s.default.uX(r),this.y3=h+a*s.default.uY(r)}else this.x0=t.x/n,this.y0=t.y/i,this.x1=(t.x+t.width)/n,this.y1=t.y/i,this.x2=(t.x+t.width)/n,this.y2=(t.y+t.height)/i,this.x3=t.x/n,this.y3=(t.y+t.height)/i;this.uvsUint32[0]=(65535*this.y0&65535)<<16|65535*this.x0&65535,this.uvsUint32[1]=(65535*this.y1&65535)<<16|65535*this.x1&65535,this.uvsUint32[2]=(65535*this.y2&65535)<<16|65535*this.x2&65535,this.uvsUint32[3]=(65535*this.y3&65535)<<16|65535*this.x3&65535},t}();r.default=a},{"../math/GroupD8":62}],111:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t){return t&&t.__esModule?t:{default:t}}function o(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function s(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function a(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}function u(t,e){e||(e="video/"+t.substr(t.lastIndexOf(".")+1));var r=document.createElement("source");return r.src=t,r.type=e,r}r.__esModule=!0;var h=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),l=t("./BaseTexture"),c=i(l),d=t("../utils"),f=t("../ticker"),p=n(f),v=function(t){function e(r,n){if(o(this,e),!r)throw new Error("No video source element specified.");(r.readyState===r.HAVE_ENOUGH_DATA||r.readyState===r.HAVE_FUTURE_DATA)&&r.width&&r.height&&(r.complete=!0);var i=s(this,t.call(this,r,n));return i.width=r.videoWidth,i.height=r.videoHeight,i._autoUpdate=!0,i._isAutoUpdating=!1,i.autoPlay=!0,i.update=i.update.bind(i),i._onCanPlay=i._onCanPlay.bind(i),r.addEventListener("play",i._onPlayStart.bind(i)),r.addEventListener("pause",i._onPlayStop.bind(i)),i.hasLoaded=!1,i.__loaded=!1,i._isSourceReady()?i._onCanPlay():(r.addEventListener("canplay",i._onCanPlay),r.addEventListener("canplaythrough",i._onCanPlay)),i}return a(e,t),e.prototype._isSourcePlaying=function(){var t=this.source;return t.currentTime>0&&t.paused===!1&&t.ended===!1&&t.readyState>2},e.prototype._isSourceReady=function(){return 3===this.source.readyState||4===this.source.readyState},e.prototype._onPlayStart=function(){this.hasLoaded||this._onCanPlay(),!this._isAutoUpdating&&this.autoUpdate&&(p.shared.add(this.update,this),this._isAutoUpdating=!0)},e.prototype._onPlayStop=function(){this._isAutoUpdating&&(p.shared.remove(this.update,this),this._isAutoUpdating=!1)},e.prototype._onCanPlay=function(){this.hasLoaded=!0,this.source&&(this.source.removeEventListener("canplay",this._onCanPlay),this.source.removeEventListener("canplaythrough",this._onCanPlay),this.width=this.source.videoWidth,this.height=this.source.videoHeight,this.__loaded||(this.__loaded=!0,this.emit("loaded",this)),this._isSourcePlaying()?this._onPlayStart():this.autoPlay&&this.source.play())},e.prototype.destroy=function(){this._isAutoUpdating&&p.shared.remove(this.update,this),this.source&&this.source._pixiId&&(delete d.BaseTextureCache[this.source._pixiId],delete this.source._pixiId),t.prototype.destroy.call(this)},e.fromVideo=function(t,r){t._pixiId||(t._pixiId="video_"+(0,d.uid)());var n=d.BaseTextureCache[t._pixiId];return n||(n=new e(t,r),d.BaseTextureCache[t._pixiId]=n),n},e.fromUrl=function(t,r){var n=document.createElement("video");if(n.setAttribute("webkit-playsinline",""),n.setAttribute("playsinline",""),Array.isArray(t))for(var i=0;i<t.length;++i)n.appendChild(u(t[i].src||t[i],t[i].mime));else n.appendChild(u(t.src||t,t.mime));return n.load(),e.fromVideo(n,r)},h(e,[{key:"autoUpdate",get:function(){return this._autoUpdate},set:function(t){t!==this._autoUpdate&&(this._autoUpdate=t,!this._autoUpdate&&this._isAutoUpdating?(p.shared.remove(this.update,this),this._isAutoUpdating=!1):this._autoUpdate&&!this._isAutoUpdating&&(p.shared.add(this.update,this),this._isAutoUpdating=!0))}}]),e}(c.default);r.default=v,v.fromUrls=v.fromUrl},{"../ticker":113,"../utils":117,"./BaseTexture":107}],112:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),s=t("../settings"),a=n(s),u=t("eventemitter3"),h=n(u),l="tick",c=a.default.TARGET_FPMS,d=function(){function t(){var e=this;i(this,t),this._emitter=new h.default,this._requestId=null,this._maxElapsedMS=100,this.autoStart=!1,this.deltaTime=1,this.elapsedMS=1/c,this.lastTime=0,this.speed=1,this.started=!1,this._tick=function(t){e._requestId=null,e.started&&(e.update(t),e.started&&null===e._requestId&&e._emitter.listeners(l,!0)&&(e._requestId=requestAnimationFrame(e._tick)))}}return t.prototype._requestIfNeeded=function(){null===this._requestId&&this._emitter.listeners(l,!0)&&(this.lastTime=performance.now(),this._requestId=requestAnimationFrame(this._tick))},t.prototype._cancelIfNeeded=function(){null!==this._requestId&&(cancelAnimationFrame(this._requestId),this._requestId=null)},t.prototype._startIfPossible=function(){this.started?this._requestIfNeeded():this.autoStart&&this.start()},t.prototype.add=function(t,e){return this._emitter.on(l,t,e),this._startIfPossible(),this},t.prototype.addOnce=function(t,e){return this._emitter.once(l,t,e),this._startIfPossible(),this},t.prototype.remove=function(t,e){return this._emitter.off(l,t,e),this._emitter.listeners(l,!0)||this._cancelIfNeeded(),this},t.prototype.start=function(){this.started||(this.started=!0,this._requestIfNeeded())},t.prototype.stop=function(){this.started&&(this.started=!1,this._cancelIfNeeded())},t.prototype.update=function(){var t=arguments.length<=0||void 0===arguments[0]?performance.now():arguments[0],e=void 0;t>this.lastTime?(e=this.elapsedMS=t-this.lastTime,e>this._maxElapsedMS&&(e=this._maxElapsedMS),this.deltaTime=e*c*this.speed,this._emitter.emit(l,this.deltaTime)):this.deltaTime=this.elapsedMS=0,this.lastTime=t},o(t,[{key:"FPS",get:function(){return 1e3/this.elapsedMS}},{key:"minFPS",get:function(){return 1e3/this._maxElapsedMS},set:function(t){var e=Math.min(Math.max(0,t)/1e3,c);this._maxElapsedMS=1/e}}]),t}();r.default=d},{"../settings":97,eventemitter3:3}],113:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}r.__esModule=!0,r.Ticker=r.shared=void 0;var i=t("./Ticker"),o=n(i),s=new o.default;s.autoStart=!0,r.shared=s,r.Ticker=o.default},{"./Ticker":112}],114:[function(t,e,r){"use strict";function n(){var t=!!navigator.platform&&/iPad|iPhone|iPod/.test(navigator.platform);return!t}r.__esModule=!0,r.default=n},{}],115:[function(t,e,r){"use strict";function n(t){for(var e=6*t,r=new Uint16Array(e),n=0,i=0;n<e;n+=6,i+=4)r[n+0]=i+0,r[n+1]=i+1,r[n+2]=i+2,r[n+3]=i+0,r[n+4]=i+2,r[n+5]=i+3;return r}r.__esModule=!0,r.default=n},{}],116:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t){var e=arguments.length<=1||void 0===arguments[1]?window.location:arguments[1];if(0===t.indexOf("data:"))return"";e=e||window.location,a||(a=document.createElement("a")),a.href=t,t=s.default.parse(a.href);var r=!t.port&&""===e.port||t.port===e.port;return t.hostname===e.hostname&&r&&t.protocol===e.protocol?"":"anonymous"}r.__esModule=!0,r.default=i;var o=t("url"),s=n(o),a=void 0},{url:28}],117:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t){return t&&t.__esModule?t:{default:t}}function o(){return++M}function s(t,e){return e=e||[],e[0]=(t>>16&255)/255,e[1]=(t>>8&255)/255,e[2]=(255&t)/255,e}function a(t){return t=t.toString(16),t="000000".substr(0,6-t.length)+t,"#"+t}function u(t){return(255*t[0]<<16)+(255*t[1]<<8)+255*t[2]}function h(t){var e=b.default.RETINA_PREFIX.exec(t);return e?parseFloat(e[1]):1}function l(t){var e=m.DATA_URI.exec(t);if(e)return{mediaType:e[1]?e[1].toLowerCase():void 0,subType:e[2]?e[2].toLowerCase():void 0,encoding:e[3]?e[3].toLowerCase():void 0,data:e[4]}}function c(t){var e=m.URL_FILE_EXTENSION.exec(t);if(e)return e[1].toLowerCase()}function d(t){var e=m.SVG_SIZE.exec(t),r={};return e&&(r[e[1]]=Math.round(parseFloat(e[3])),r[e[5]]=Math.round(parseFloat(e[7]))),r}function f(){P=!0}function p(t){if(!P){if(navigator.userAgent.toLowerCase().indexOf("chrome")>-1){var e=["\n %c %c %c Pixi.js "+m.VERSION+" - ✰ "+t+" ✰  %c  %c  http://www.pixijs.com/  %c %c ♥%c♥%c♥ \n\n","background: #ff66a5; padding:5px 0;","background: #ff66a5; padding:5px 0;","color: #ff66a5; background: #030307; padding:5px 0;","background: #ff66a5; padding:5px 0;","background: #ffc3dc; padding:5px 0;","background: #ff66a5; padding:5px 0;","color: #ff2424; background: #fff; padding:5px 0;","color: #ff2424; background: #fff; padding:5px 0;","color: #ff2424; background: #fff; padding:5px 0;"];window.console.log.apply(console,e)}else window.console&&window.console.log("Pixi.js "+m.VERSION+" - "+t+" - http://www.pixijs.com/");P=!0}}function v(){var t={stencil:!0,failIfMajorPerformanceCaveat:!0};try{if(!window.WebGLRenderingContext)return!1;var e=document.createElement("canvas"),r=e.getContext("webgl",t)||e.getContext("experimental-webgl",t),n=!(!r||!r.getContextAttributes().stencil);if(r){var i=r.getExtension("WEBGL_lose_context");i&&i.loseContext()}return r=null,n}catch(t){return!1}}function y(t){return 0===t?0:t<0?-1:1}function g(t,e,r){var n=t.length;if(!(e>=n||0===r)){r=e+r>n?n-e:r;for(var i=n-r,o=e;o<i;++o)t[o]=t[o+r];t.length=i}}r.__esModule=!0,r.BaseTextureCache=r.TextureCache=r.pluginTarget=r.EventEmitter=r.isMobile=void 0,r.uid=o,r.hex2rgb=s,r.hex2string=a,r.rgb2hex=u,r.getResolutionOfUrl=h,r.decomposeDataUri=l,r.getUrlFileExtension=c,r.getSvgSize=d,r.skipHello=f,r.sayHello=p,r.isWebGLSupported=v,r.sign=y,r.removeItems=g;var m=t("../const"),_=t("../settings"),b=i(_),x=t("eventemitter3"),T=i(x),w=t("./pluginTarget"),E=i(w),O=t("ismobilejs"),S=n(O),M=0,P=!1;r.isMobile=S,r.EventEmitter=T.default,r.pluginTarget=E.default;r.TextureCache={},r.BaseTextureCache={}},{"../const":42,"../settings":97,"./pluginTarget":119,eventemitter3:3,ismobilejs:4}],118:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t){return s.default.tablet||s.default.phone?4:t}r.__esModule=!0,r.default=i;var o=t("ismobilejs"),s=n(o)},{ismobilejs:4}],119:[function(t,e,r){"use strict";function n(t){t.__plugins={},t.registerPlugin=function(e,r){t.__plugins[e]=r},t.prototype.initPlugins=function(){this.plugins=this.plugins||{};for(var e in t.__plugins)this.plugins[e]=new t.__plugins[e](this)},t.prototype.destroyPlugins=function(){for(var t in this.plugins)this.plugins[t].destroy(),this.plugins[t]=null;this.plugins=null}}r.__esModule=!0,r.default={mixin:function(t){n(t)}}},{}],120:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t){}var o=t("./core"),s=n(o),a=t("./mesh"),u=n(a),h=t("./particles"),l=n(h),c=t("./extras"),d=n(c),f=t("./filters"),p=n(f),v=t("./prepare"),y=n(v);s.SpriteBatch=function(){throw new ReferenceError("SpriteBatch does not exist any more, please use the new ParticleContainer instead.")},s.AssetLoader=function(){throw new ReferenceError("The loader system was overhauled in pixi v3, please see the new PIXI.loaders.Loader class.")},Object.defineProperties(s,{Stage:{enumerable:!0,get:function(){return i("You do not need to use a PIXI Stage any more, you can simply render any container."),s.Container}},DisplayObjectContainer:{enumerable:!0,get:function(){return i("DisplayObjectContainer has been shortened to Container, please use Container from now on."),s.Container}},Strip:{enumerable:!0,get:function(){return i("The Strip class has been renamed to Mesh and moved to mesh.Mesh, please use mesh.Mesh from now on."),u.Mesh}},Rope:{enumerable:!0,get:function(){return i("The Rope class has been moved to mesh.Rope, please use mesh.Rope from now on."),u.Rope}},ParticleContainer:{enumerable:!0,get:function(){return i("The ParticleContainer class has been moved to particles.ParticleContainer, please use particles.ParticleContainer from now on."),l.ParticleContainer}},MovieClip:{enumerable:!0,get:function(){return i("The MovieClip class has been moved to extras.AnimatedSprite, please use extras.AnimatedSprite."),d.AnimatedSprite}},TilingSprite:{enumerable:!0,get:function(){return i("The TilingSprite class has been moved to extras.TilingSprite, please use extras.TilingSprite from now on."),d.TilingSprite}},BitmapText:{enumerable:!0,get:function(){return i("The BitmapText class has been moved to extras.BitmapText, please use extras.BitmapText from now on."),d.BitmapText}},blendModes:{enumerable:!0,get:function(){return i("The blendModes has been moved to BLEND_MODES, please use BLEND_MODES from now on."),s.BLEND_MODES}},scaleModes:{enumerable:!0,get:function(){return i("The scaleModes has been moved to SCALE_MODES, please use SCALE_MODES from now on."),s.SCALE_MODES}},BaseTextureCache:{enumerable:!0,get:function(){return i("The BaseTextureCache class has been moved to utils.BaseTextureCache, please use utils.BaseTextureCache from now on."),s.utils.BaseTextureCache}},TextureCache:{enumerable:!0,get:function(){return i("The TextureCache class has been moved to utils.TextureCache, please use utils.TextureCache from now on."),s.utils.TextureCache}},math:{enumerable:!0,get:function(){return i("The math namespace is deprecated, please access members already accessible on PIXI."),s}},AbstractFilter:{enumerable:!0,get:function(){return i("AstractFilter has been renamed to Filter, please use PIXI.Filter"),s.Filter}},TransformManual:{enumerable:!0,get:function(){return i("TransformManual has been renamed to TransformBase, please update your pixi-spine"),s.TransformBase}},TARGET_FPMS:{enumerable:!0,get:function(){return i("PIXI.TARGET_FPMS has been deprecated, please use PIXI.settings.TARGET_FPMS"),s.settings.TARGET_FPMS},set:function(t){i("PIXI.TARGET_FPMS has been deprecated, please use PIXI.settings.TARGET_FPMS"),s.settings.TARGET_FPMS=t}},FILTER_RESOLUTION:{enumerable:!0,get:function(){return i("PIXI.FILTER_RESOLUTION has been deprecated, please use PIXI.settings.FILTER_RESOLUTION"),s.settings.FILTER_RESOLUTION},set:function(t){i("PIXI.FILTER_RESOLUTION has been deprecated, please use PIXI.settings.FILTER_RESOLUTION"),s.settings.FILTER_RESOLUTION=t}},RESOLUTION:{enumerable:!0,get:function(){return i("PIXI.RESOLUTION has been deprecated, please use PIXI.settings.RESOLUTION"),s.settings.RESOLUTION},set:function(t){i("PIXI.RESOLUTION has been deprecated, please use PIXI.settings.RESOLUTION"),s.settings.RESOLUTION=t}},MIPMAP_TEXTURES:{enumerable:!0,get:function(){return i("PIXI.MIPMAP_TEXTURES has been deprecated, please use PIXI.settings.MIPMAP_TEXTURES"),s.settings.MIPMAP_TEXTURES},set:function(t){i("PIXI.MIPMAP_TEXTURES has been deprecated, please use PIXI.settings.MIPMAP_TEXTURES"),s.settings.MIPMAP_TEXTURES=t}},SPRITE_BATCH_SIZE:{enumerable:!0,get:function(){return i("PIXI.SPRITE_BATCH_SIZE has been deprecated, please use PIXI.settings.SPRITE_BATCH_SIZE"),s.settings.SPRITE_BATCH_SIZE},set:function(t){i("PIXI.SPRITE_BATCH_SIZE has been deprecated, please use PIXI.settings.SPRITE_BATCH_SIZE"),s.settings.SPRITE_BATCH_SIZE=t}},SPRITE_MAX_TEXTURES:{enumerable:!0,get:function(){return i("PIXI.SPRITE_MAX_TEXTURES has been deprecated, please use PIXI.settings.SPRITE_MAX_TEXTURES"),s.settings.SPRITE_MAX_TEXTURES},set:function(t){i("PIXI.SPRITE_MAX_TEXTURES has been deprecated, please use PIXI.settings.SPRITE_MAX_TEXTURES"),s.settings.SPRITE_MAX_TEXTURES=t}},RETINA_PREFIX:{enumerable:!0,get:function(){return i("PIXI.RETINA_PREFIX has been deprecated, please use PIXI.settings.RETINA_PREFIX"),s.settings.RETINA_PREFIX},set:function(t){i("PIXI.RETINA_PREFIX has been deprecated, please use PIXI.settings.RETINA_PREFIX"),s.settings.RETINA_PREFIX=t}},DEFAULT_RENDER_OPTIONS:{enumerable:!0,get:function(){return i("PIXI.DEFAULT_RENDER_OPTIONS has been deprecated, please use PIXI.settings.DEFAULT_RENDER_OPTIONS"),s.settings.RENDER_OPTIONS}}});for(var g=[{parent:"TRANSFORM_MODE",target:"TRANSFORM_MODE"},{parent:"GC_MODES",target:"GC_MODE"},{parent:"WRAP_MODES",target:"WRAP_MODE"},{parent:"SCALE_MODES",target:"SCALE_MODE"},{parent:"PRECISION",target:"PRECISION"}],m=function(t){var e=g[t];Object.defineProperty(s[e.parent],"DEFAULT",{enumerable:!0,get:function(){return i("PIXI."+e.parent+".DEFAULT has been deprecated, please use PIXI.settings."+e.target),s.settings[e.target]},set:function(t){i("PIXI."+e.parent+".DEFAULT has been deprecated, please use PIXI.settings."+e.target),s.settings[e.target]=t}})},_=0;_<g.length;_++)m(_);Object.defineProperties(d,{MovieClip:{enumerable:!0,get:function(){return i("The MovieClip class has been renamed to AnimatedSprite, please use AnimatedSprite from now on."),d.AnimatedSprite}}}),s.DisplayObject.prototype.generateTexture=function(t,e,r){return i("generateTexture has moved to the renderer, please use renderer.generateTexture(displayObject)"),t.generateTexture(this,e,r)},s.Graphics.prototype.generateTexture=function(t,e){return i("graphics generate texture has moved to the renderer. Or to render a graphics to a texture using canvas please use generateCanvasTexture"),
this.generateCanvasTexture(t,e)},s.RenderTexture.prototype.render=function(t,e,r,n){this.legacyRenderer.render(t,this,r,e,!n),i("RenderTexture.render is now deprecated, please use renderer.render(displayObject, renderTexture)")},s.RenderTexture.prototype.getImage=function(t){return i("RenderTexture.getImage is now deprecated, please use renderer.extract.image(target)"),this.legacyRenderer.extract.image(t)},s.RenderTexture.prototype.getBase64=function(t){return i("RenderTexture.getBase64 is now deprecated, please use renderer.extract.base64(target)"),this.legacyRenderer.extract.base64(t)},s.RenderTexture.prototype.getCanvas=function(t){return i("RenderTexture.getCanvas is now deprecated, please use renderer.extract.canvas(target)"),this.legacyRenderer.extract.canvas(t)},s.RenderTexture.prototype.getPixels=function(t){return i("RenderTexture.getPixels is now deprecated, please use renderer.extract.pixels(target)"),this.legacyRenderer.pixels(t)},s.Sprite.prototype.setTexture=function(t){this.texture=t,i("setTexture is now deprecated, please use the texture property, e.g : sprite.texture = texture;")},d.BitmapText.prototype.setText=function(t){this.text=t,i("setText is now deprecated, please use the text property, e.g : myBitmapText.text = 'my text';")},s.Text.prototype.setText=function(t){this.text=t,i("setText is now deprecated, please use the text property, e.g : myText.text = 'my text';")},s.Text.prototype.setStyle=function(t){this.style=t,i("setStyle is now deprecated, please use the style property, e.g : myText.style = style;")},s.Text.prototype.determineFontProperties=function(t){return i("determineFontProperties is now deprecated, please use the static calculateFontProperties method, e.g : Text.calculateFontProperties(fontStyle);"),Text.calculateFontProperties(t)},Object.defineProperties(s.TextStyle.prototype,{font:{get:function(){i("text style property 'font' is now deprecated, please use the 'fontFamily', 'fontSize', 'fontStyle', 'fontVariant' and 'fontWeight' properties from now on");var t="number"==typeof this._fontSize?this._fontSize+"px":this._fontSize;return this._fontStyle+" "+this._fontVariant+" "+this._fontWeight+" "+t+" "+this._fontFamily},set:function(t){i("text style property 'font' is now deprecated, please use the 'fontFamily','fontSize',fontStyle','fontVariant' and 'fontWeight' properties from now on"),t.indexOf("italic")>1?this._fontStyle="italic":t.indexOf("oblique")>-1?this._fontStyle="oblique":this._fontStyle="normal",t.indexOf("small-caps")>-1?this._fontVariant="small-caps":this._fontVariant="normal";var e=t.split(" "),r=-1;this._fontSize=26;for(var n=0;n<e.length;++n)if(e[n].match(/(px|pt|em|%)/)){r=n,this._fontSize=e[n];break}this._fontWeight="normal";for(var o=0;o<r;++o)if(e[o].match(/(bold|bolder|lighter|100|200|300|400|500|600|700|800|900)/)){this._fontWeight=e[o];break}if(r>-1&&r<e.length-1){this._fontFamily="";for(var s=r+1;s<e.length;++s)this._fontFamily+=e[s]+" ";this._fontFamily=this._fontFamily.slice(0,-1)}else this._fontFamily="Arial";this.styleID++}}}),s.Texture.prototype.setFrame=function(t){this.frame=t,i("setFrame is now deprecated, please use the frame property, e.g: myTexture.frame = frame;")},Object.defineProperties(p,{AbstractFilter:{get:function(){return i("AstractFilter has been renamed to Filter, please use PIXI.Filter"),s.AbstractFilter}},SpriteMaskFilter:{get:function(){return i("filters.SpriteMaskFilter is an undocumented alias, please use SpriteMaskFilter from now on."),s.SpriteMaskFilter}}}),s.utils.uuid=function(){return i("utils.uuid() is deprecated, please use utils.uid() from now on."),s.utils.uid()},s.utils.canUseNewCanvasBlendModes=function(){return i("utils.canUseNewCanvasBlendModes() is deprecated, please use CanvasTinter.canUseMultiply from now on"),s.CanvasTinter.canUseMultiply};var b=!0;Object.defineProperty(s.utils,"_saidHello",{set:function(t){t&&(i("PIXI.utils._saidHello is deprecated, please use PIXI.utils.skipHello()"),this.skipHello()),b=t},get:function(){return b}}),Object.defineProperty(y.canvas,"UPLOADS_PER_FRAME",{set:function(){i("PIXI.CanvasPrepare.UPLOADS_PER_FRAME has been removed. Please set renderer.plugins.prepare.limiter.maxItemsPerFrame on your renderer")},get:function(){return i("PIXI.CanvasPrepare.UPLOADS_PER_FRAME has been removed. Please use renderer.plugins.prepare.limiter"),NaN}}),Object.defineProperty(y.webgl,"UPLOADS_PER_FRAME",{set:function(){i("PIXI.WebGLPrepare.UPLOADS_PER_FRAME has been removed. Please set renderer.plugins.prepare.limiter.maxItemsPerFrame on your renderer")},get:function(){return i("PIXI.WebGLPrepare.UPLOADS_PER_FRAME has been removed. Please use renderer.plugins.prepare.limiter"),NaN}})},{"./core":61,"./extras":131,"./filters":142,"./mesh":160,"./particles":163,"./prepare":173}],121:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=t("../../core"),s=n(o),a=new s.Rectangle,u=function(){function t(e){i(this,t),this.renderer=e,e.extract=this}return t.prototype.image=function t(e){var t=new Image;return t.src=this.base64(e),t},t.prototype.base64=function(t){return this.canvas(t).toDataURL()},t.prototype.canvas=function(t){var e=this.renderer,r=void 0,n=void 0,i=void 0,o=void 0;t&&(o=t instanceof s.RenderTexture?t:e.generateTexture(t)),o?(r=o.baseTexture._canvasRenderTarget.context,n=o.baseTexture._canvasRenderTarget.resolution,i=o.frame):(r=e.rootContext,i=a,i.width=this.renderer.width,i.height=this.renderer.height);var u=i.width*n,h=i.height*n,l=new s.CanvasRenderTarget(u,h),c=r.getImageData(i.x*n,i.y*n,u,h);return l.context.putImageData(c,0,0),l.canvas},t.prototype.pixels=function(t){var e=this.renderer,r=void 0,n=void 0,i=void 0,o=void 0;return t&&(o=t instanceof s.RenderTexture?t:e.generateTexture(t)),o?(r=o.baseTexture._canvasRenderTarget.context,n=o.baseTexture._canvasRenderTarget.resolution,i=o.frame):(r=e.rootContext,i=a,i.width=e.width,i.height=e.height),r.getImageData(0,0,i.width*n,i.height*n).data},t.prototype.destroy=function(){this.renderer.extract=null,this.renderer=null},t}();r.default=u,s.CanvasRenderer.registerPlugin("extract",u)},{"../../core":61}],122:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}r.__esModule=!0;var i=t("./webgl/WebGLExtract");Object.defineProperty(r,"webgl",{enumerable:!0,get:function(){return n(i).default}});var o=t("./canvas/CanvasExtract");Object.defineProperty(r,"canvas",{enumerable:!0,get:function(){return n(o).default}})},{"./canvas/CanvasExtract":121,"./webgl/WebGLExtract":123}],123:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=t("../../core"),s=n(o),a=new s.Rectangle,u=4,h=function(){function t(e){i(this,t),this.renderer=e,e.extract=this}return t.prototype.image=function t(e){var t=new Image;return t.src=this.base64(e),t},t.prototype.base64=function(t){return this.canvas(t).toDataURL()},t.prototype.canvas=function(t){var e=this.renderer,r=void 0,n=void 0,i=void 0,o=!1,h=void 0;t&&(h=t instanceof s.RenderTexture?t:this.renderer.generateTexture(t)),h?(r=h.baseTexture._glRenderTargets[this.renderer.CONTEXT_UID],n=r.resolution,i=h.frame,o=!1):(r=this.renderer.rootRenderTarget,n=r.resolution,o=!0,i=a,i.width=r.size.width,i.height=r.size.height);var l=i.width*n,c=i.height*n,d=new s.CanvasRenderTarget(l,c);if(r){e.bindRenderTarget(r);var f=new Uint8Array(u*l*c),p=e.gl;p.readPixels(i.x*n,i.y*n,l,c,p.RGBA,p.UNSIGNED_BYTE,f);var v=d.context.getImageData(0,0,l,c);v.data.set(f),d.context.putImageData(v,0,0),o&&(d.context.scale(1,-1),d.context.drawImage(d.canvas,0,-c))}return d.canvas},t.prototype.pixels=function(t){var e=this.renderer,r=void 0,n=void 0,i=void 0,o=void 0;t&&(o=t instanceof s.RenderTexture?t:this.renderer.generateTexture(t)),o?(r=o.baseTexture._glRenderTargets[this.renderer.CONTEXT_UID],n=r.resolution,i=o.frame):(r=this.renderer.rootRenderTarget,n=r.resolution,i=a,i.width=r.size.width,i.height=r.size.height);var h=i.width*n,l=i.height*n,c=new Uint8Array(u*h*l);if(r){e.bindRenderTarget(r);var d=e.gl;d.readPixels(i.x*n,i.y*n,h,l,d.RGBA,d.UNSIGNED_BYTE,c)}return c},t.prototype.destroy=function(){this.renderer.extract=null,this.renderer=null},t}();r.default=h,s.WebGLRenderer.registerPlugin("extract",h)},{"../../core":61}],124:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),u=t("../core"),h=n(u),l=function(t){function e(r){i(this,e);var n=o(this,t.call(this,r[0]instanceof h.Texture?r[0]:r[0].texture));return n._textures=null,n._durations=null,n.textures=r,n.animationSpeed=1,n.loop=!0,n.onComplete=null,n.onFrameChange=null,n._currentTime=0,n.playing=!1,n}return s(e,t),e.prototype.stop=function(){this.playing&&(this.playing=!1,h.ticker.shared.remove(this.update,this))},e.prototype.play=function(){this.playing||(this.playing=!0,h.ticker.shared.add(this.update,this))},e.prototype.gotoAndStop=function(t){this.stop();var e=this.currentFrame;this._currentTime=t,e!==this.currentFrame&&this.updateTexture()},e.prototype.gotoAndPlay=function(t){var e=this.currentFrame;this._currentTime=t,e!==this.currentFrame&&this.updateTexture(),this.play()},e.prototype.update=function(t){var e=this.animationSpeed*t,r=this.currentFrame;if(null!==this._durations){var n=this._currentTime%1*this._durations[this.currentFrame];for(n+=e/60*1e3;n<0;)this._currentTime--,n+=this._durations[this.currentFrame];var i=Math.sign(this.animationSpeed*t);for(this._currentTime=Math.floor(this._currentTime);n>=this._durations[this.currentFrame];)n-=this._durations[this.currentFrame]*i,this._currentTime+=i;this._currentTime+=n/this._durations[this.currentFrame]}else this._currentTime+=e;this._currentTime<0&&!this.loop?(this.gotoAndStop(0),this.onComplete&&this.onComplete()):this._currentTime>=this._textures.length&&!this.loop?(this.gotoAndStop(this._textures.length-1),this.onComplete&&this.onComplete()):r!==this.currentFrame&&this.updateTexture()},e.prototype.updateTexture=function(){this._texture=this._textures[this.currentFrame],this._textureID=-1,this.onFrameChange&&this.onFrameChange(this.currentFrame)},e.prototype.destroy=function(){this.stop(),t.prototype.destroy.call(this)},e.fromFrames=function(t){for(var r=[],n=0;n<t.length;++n)r.push(h.Texture.fromFrame(t[n]));return new e(r)},e.fromImages=function(t){for(var r=[],n=0;n<t.length;++n)r.push(h.Texture.fromImage(t[n]));return new e(r)},a(e,[{key:"totalFrames",get:function(){return this._textures.length}},{key:"textures",get:function(){return this._textures},set:function(t){if(t[0]instanceof h.Texture)this._textures=t,this._durations=null;else{this._textures=[],this._durations=[];for(var e=0;e<t.length;e++)this._textures.push(t[e].texture),this._durations.push(t[e].time)}}},{key:"currentFrame",get:function(){var t=Math.floor(this._currentTime)%this._textures.length;return t<0&&(t+=this._textures.length),t}}]),e}(h.Sprite);r.default=l},{"../core":61}],125:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function o(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function s(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function a(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var u=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),h=t("../core"),l=i(h),c=t("../core/math/ObservablePoint"),d=n(c),f=function(t){function e(r){var n=arguments.length<=1||void 0===arguments[1]?{}:arguments[1];o(this,e);var i=s(this,t.call(this));return i.textWidth=0,i.textHeight=0,i._glyphs=[],i._font={tint:void 0!==n.tint?n.tint:16777215,align:n.align||"left",name:null,size:0},i.font=n.font,i._text=r,i.maxWidth=0,i.maxLineHeight=0,i._anchor=new d.default(function(){i.dirty=!0},i,0,0),i.dirty=!1,i.updateText(),i}return a(e,t),e.prototype.updateText=function(){for(var t=e.fonts[this._font.name],r=this._font.size/t.size,n=new l.Point,i=[],o=[],s=null,a=0,u=0,h=0,c=-1,d=0,f=0,p=0;p<this.text.length;p++){var v=this.text.charCodeAt(p);if(/(\s)/.test(this.text.charAt(p))&&(c=p,d=a),/(?:\r\n|\r|\n)/.test(this.text.charAt(p)))o.push(a),u=Math.max(u,a),h++,n.x=0,n.y+=t.lineHeight,s=null;else if(c!==-1&&this.maxWidth>0&&n.x*r>this.maxWidth)l.utils.removeItems(i,c,p-c),p=c,c=-1,o.push(d),u=Math.max(u,d),h++,n.x=0,n.y+=t.lineHeight,s=null;else{var y=t.chars[v];y&&(s&&y.kerning[s]&&(n.x+=y.kerning[s]),i.push({texture:y.texture,line:h,charCode:v,position:new l.Point(n.x+y.xOffset,n.y+y.yOffset)}),a=n.x+(y.texture.width+y.xOffset),n.x+=y.xAdvance,f=Math.max(f,y.yOffset+y.texture.height),s=v)}}o.push(a),u=Math.max(u,a);for(var g=[],m=0;m<=h;m++){var _=0;"right"===this._font.align?_=u-o[m]:"center"===this._font.align&&(_=(u-o[m])/2),g.push(_)}for(var b=i.length,x=this.tint,T=0;T<b;T++){var w=this._glyphs[T];w?w.texture=i[T].texture:(w=new l.Sprite(i[T].texture),this._glyphs.push(w)),w.position.x=(i[T].position.x+g[i[T].line])*r,w.position.y=i[T].position.y*r,w.scale.x=w.scale.y=r,w.tint=x,w.parent||this.addChild(w)}for(var E=b;E<this._glyphs.length;++E)this.removeChild(this._glyphs[E]);if(this.textWidth=u*r,this.textHeight=(n.y+t.lineHeight)*r,0!==this.anchor.x||0!==this.anchor.y)for(var O=0;O<b;O++)this._glyphs[O].x-=this.textWidth*this.anchor.x,this._glyphs[O].y-=this.textHeight*this.anchor.y;this.maxLineHeight=f*r},e.prototype.updateTransform=function(){this.validate(),this.containerUpdateTransform()},e.prototype.getLocalBounds=function(){return this.validate(),t.prototype.getLocalBounds.call(this)},e.prototype.validate=function(){this.dirty&&(this.updateText(),this.dirty=!1)},u(e,[{key:"tint",get:function(){return this._font.tint},set:function(t){this._font.tint="number"==typeof t&&t>=0?t:16777215,this.dirty=!0}},{key:"align",get:function(){return this._font.align},set:function(t){this._font.align=t||"left",this.dirty=!0}},{key:"anchor",get:function(){return this._anchor},set:function(t){"number"==typeof t?this._anchor.set(t):this._anchor.copy(t)}},{key:"font",get:function(){return this._font},set:function(t){t&&("string"==typeof t?(t=t.split(" "),this._font.name=1===t.length?t[0]:t.slice(1).join(" "),this._font.size=t.length>=2?parseInt(t[0],10):e.fonts[this._font.name].size):(this._font.name=t.name,this._font.size="number"==typeof t.size?t.size:parseInt(t.size,10)),this.dirty=!0)}},{key:"text",get:function(){return this._text},set:function(t){t=t.toString()||" ",this._text!==t&&(this._text=t,this.dirty=!0)}}]),e}(l.Container);r.default=f,f.fonts={}},{"../core":61,"../core/math/ObservablePoint":64}],126:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),s=t("../core/math/Matrix"),a=n(s),u=new a.default,h=function(){function t(e,r){i(this,t),this._texture=e,this.mapCoord=new a.default,this.uClampFrame=new Float32Array(4),this.uClampOffset=new Float32Array(2),this._lastTextureID=-1,this.clampOffset=0,this.clampMargin="undefined"==typeof r?.5:r}return t.prototype.update=function(t){var e=this.texture;if(e&&e.valid&&(t||this._lastTextureID!==this.texture._updateID)){this._lastTextureID=this.texture._updateID;var r=this.texture._uvs;this.mapCoord.set(r.x1-r.x0,r.y1-r.y0,r.x3-r.x0,r.y3-r.y0,r.x0,r.y0);var n=e.orig,i=e.trim;i&&(u.set(n.width/i.width,0,0,n.height/i.height,-i.x/i.width,-i.y/i.height),this.mapCoord.append(u));var o=e.baseTexture,s=this.uClampFrame,a=this.clampMargin/o.resolution,h=this.clampOffset;s[0]=(e._frame.x+a+h)/o.width,s[1]=(e._frame.y+a+h)/o.height,s[2]=(e._frame.x+e._frame.width-a+h)/o.width,s[3]=(e._frame.y+e._frame.height-a+h)/o.height,this.uClampOffset[0]=h/o.realWidth,this.uClampOffset[1]=h/o.realHeight}},o(t,[{key:"texture",get:function(){return this._texture},set:function(t){this._texture=t,this._lastTextureID=-1}}]),t}();r.default=h},{"../core/math/Matrix":63}],127:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function o(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function s(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function a(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var u=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),h=t("../core"),l=i(h),c=t("../core/sprites/canvas/CanvasTinter"),d=n(c),f=t("./TextureTransform"),p=n(f),v=new l.Point,y=function(t){function e(r){var n=arguments.length<=1||void 0===arguments[1]?100:arguments[1],i=arguments.length<=2||void 0===arguments[2]?100:arguments[2];o(this,e);var a=s(this,t.call(this,r));return a.tileTransform=new l.TransformStatic,a._width=n,a._height=i,a._canvasPattern=null,a.uvTransform=r.transform||new p.default(r),a}return a(e,t),e.prototype._onTextureUpdate=function(){this.uvTransform&&(this.uvTransform.texture=this._texture)},e.prototype._renderWebGL=function(t){var e=this._texture;e&&e.valid&&(this.tileTransform.updateLocalTransform(),this.uvTransform.update(),t.setObjectRenderer(t.plugins.tilingSprite),t.plugins.tilingSprite.render(this))},e.prototype._renderCanvas=function(t){var e=this._texture;if(e.baseTexture.hasLoaded){var r=t.context,n=this.worldTransform,i=t.resolution,o=e.baseTexture,s=e.baseTexture.resolution,a=this.tilePosition.x/this.tileScale.x%e._frame.width,u=this.tilePosition.y/this.tileScale.y%e._frame.height;if(!this._canvasPattern){var h=new l.CanvasRenderTarget(e._frame.width,e._frame.height,s);16777215!==this.tint?(this.cachedTint!==this.tint&&(this.cachedTint=this.tint,this.tintedTexture=d.default.getTintedTexture(this,this.tint)),h.context.drawImage(this.tintedTexture,0,0)):h.context.drawImage(o.source,-e._frame.x,-e._frame.y),this._canvasPattern=h.context.createPattern(h.canvas,"repeat")}r.globalAlpha=this.worldAlpha,r.setTransform(n.a*i,n.b*i,n.c*i,n.d*i,n.tx*i,n.ty*i),r.scale(this.tileScale.x/s,this.tileScale.y/s),r.translate(a+this.anchor.x*-this._width,u+this.anchor.y*-this._height),t.setBlendMode(this.blendMode),r.fillStyle=this._canvasPattern,r.fillRect(-a,-u,this._width/this.tileScale.x*s,this._height/this.tileScale.y*s)}},e.prototype._calculateBounds=function(){var t=this._width*-this._anchor._x,e=this._height*-this._anchor._y,r=this._width*(1-this._anchor._x),n=this._height*(1-this._anchor._y);this._bounds.addFrame(this.transform,t,e,r,n)},e.prototype.getLocalBounds=function(e){return 0===this.children.length?(this._bounds.minX=this._width*-this._anchor._x,this._bounds.minY=this._height*-this._anchor._y,this._bounds.maxX=this._width*(1-this._anchor._x),this._bounds.maxY=this._height*(1-this._anchor._x),e||(this._localBoundsRect||(this._localBoundsRect=new l.Rectangle),e=this._localBoundsRect),this._bounds.getRectangle(e)):t.prototype.getLocalBounds.call(this,e)},e.prototype.containsPoint=function(t){this.worldTransform.applyInverse(t,v);var e=this._width,r=this._height,n=-e*this.anchor._x;if(v.x>n&&v.x<n+e){var i=-r*this.anchor._y;if(v.y>i&&v.y<i+r)return!0}return!1},e.prototype.destroy=function(){t.prototype.destroy.call(this),this.tileTransform=null,this.uvTransform=null},e.from=function(t,r,n){return new e(l.Texture.from(t),r,n)},e.fromFrame=function(t,r,n){var i=l.utils.TextureCache[t];if(!i)throw new Error('The frameId "'+t+'" does not exist in the texture cache '+this);return new e(i,r,n)},e.fromImage=function(t,r,n,i,o){return new e(l.Texture.fromImage(t,i,o),r,n)},u(e,[{key:"clampMargin",get:function(){return this.uvTransform.clampMargin},set:function(t){this.uvTransform.clampMargin=t,this.uvTransform.update(!0)}},{key:"tileScale",get:function(){return this.tileTransform.scale},set:function(t){this.tileTransform.scale.copy(t)}},{key:"tilePosition",get:function(){return this.tileTransform.position},set:function(t){this.tileTransform.position.copy(t)}},{key:"width",get:function(){return this._width},set:function(t){this._width=t}},{key:"height",get:function(){return this._height},set:function(t){this._height=t}}]),e}(l.Sprite);r.default=y},{"../core":61,"../core/sprites/canvas/CanvasTinter":100,"./TextureTransform":126}],128:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}var o=t("../core"),s=n(o),a=s.DisplayObject,u=new s.Matrix;a.prototype._cacheAsBitmap=!1,a.prototype._cacheData=!1;var h=function t(){i(this,t),this.originalRenderWebGL=null,this.originalRenderCanvas=null,this.originalCalculateBounds=null,this.originalGetLocalBounds=null,this.originalUpdateTransform=null,this.originalHitTest=null,this.originalDestroy=null,this.originalMask=null,this.originalFilterArea=null,this.sprite=null};Object.defineProperties(a.prototype,{cacheAsBitmap:{get:function(){return this._cacheAsBitmap},set:function(t){if(this._cacheAsBitmap!==t){this._cacheAsBitmap=t;var e=void 0;t?(this._cacheData||(this._cacheData=new h),e=this._cacheData,e.originalRenderWebGL=this.renderWebGL,e.originalRenderCanvas=this.renderCanvas,e.originalUpdateTransform=this.updateTransform,e.originalCalculateBounds=this._calculateBounds,e.originalGetLocalBounds=this.getLocalBounds,e.originalDestroy=this.destroy,e.originalContainsPoint=this.containsPoint,e.originalMask=this._mask,e.originalFilterArea=this.filterArea,this.renderWebGL=this._renderCachedWebGL,this.renderCanvas=this._renderCachedCanvas,this.destroy=this._cacheAsBitmapDestroy):(e=this._cacheData,e.sprite&&this._destroyCachedDisplayObject(),this.renderWebGL=e.originalRenderWebGL,this.renderCanvas=e.originalRenderCanvas,this._calculateBounds=e.originalCalculateBounds,this.getLocalBounds=e.originalGetLocalBounds,this.destroy=e.originalDestroy,this.updateTransform=e.originalUpdateTransform,this.containsPoint=e.originalContainsPoint,this._mask=e.originalMask,this.filterArea=e.originalFilterArea)}}}}),a.prototype._renderCachedWebGL=function(t){!this.visible||this.worldAlpha<=0||!this.renderable||(this._initCachedDisplayObject(t),this._cacheData.sprite._transformID=-1,this._cacheData.sprite.worldAlpha=this.worldAlpha,this._cacheData.sprite._renderWebGL(t))},a.prototype._initCachedDisplayObject=function(t){if(!this._cacheData||!this._cacheData.sprite){var e=this.alpha;this.alpha=1,t.currentRenderer.flush();var r=this.getLocalBounds().clone();if(this._filters){var n=this._filters[0].padding;r.pad(n)}var i=t._activeRenderTarget,o=t.filterManager.filterStack,a=s.RenderTexture.create(0|r.width,0|r.height),h=u;h.tx=-r.x,h.ty=-r.y,this.transform.worldTransform.identity(),this.renderWebGL=this._cacheData.originalRenderWebGL,t.render(this,a,!0,h,!0),t.bindRenderTarget(i),t.filterManager.filterStack=o,this.renderWebGL=this._renderCachedWebGL,this.updateTransform=this.displayObjectUpdateTransform,this._mask=null,this.filterArea=null;var l=new s.Sprite(a);l.transform.worldTransform=this.transform.worldTransform,l.anchor.x=-(r.x/r.width),l.anchor.y=-(r.y/r.height),l.alpha=e,l._bounds=this._bounds,this._calculateBounds=this._calculateCachedBounds,this.getLocalBounds=this._getCachedLocalBounds,this._cacheData.sprite=l,this.transform._parentID=-1,this.updateTransform(),this.containsPoint=l.containsPoint.bind(l)}},a.prototype._renderCachedCanvas=function(t){!this.visible||this.worldAlpha<=0||!this.renderable||(this._initCachedDisplayObjectCanvas(t),this._cacheData.sprite.worldAlpha=this.worldAlpha,this._cacheData.sprite.renderCanvas(t))},a.prototype._initCachedDisplayObjectCanvas=function(t){if(!this._cacheData||!this._cacheData.sprite){var e=this.getLocalBounds(),r=this.alpha;this.alpha=1;var n=t.context,i=s.RenderTexture.create(0|e.width,0|e.height),o=u;this.transform.worldTransform.copy(o),o.invert(),o.tx-=e.x,o.ty-=e.y,this.renderCanvas=this._cacheData.originalRenderCanvas,t.render(this,i,!0,o,!1),t.context=n,this.renderCanvas=this._renderCachedCanvas,this._calculateBounds=this._calculateCachedBounds,this._mask=null,this.filterArea=null;var a=new s.Sprite(i);a.transform.worldTransform=this.transform.worldTransform,a.anchor.x=-(e.x/e.width),a.anchor.y=-(e.y/e.height),a._bounds=this._bounds,a.alpha=r,this.updateTransform(),this.updateTransform=this.displayObjectUpdateTransform,this._cacheData.sprite=a,this.containsPoint=a.containsPoint.bind(a)}},a.prototype._calculateCachedBounds=function(){this._cacheData.sprite._calculateBounds()},a.prototype._getCachedLocalBounds=function(){return this._cacheData.sprite.getLocalBounds()},a.prototype._destroyCachedDisplayObject=function(){this._cacheData.sprite._texture.destroy(!0),this._cacheData.sprite=null},a.prototype._cacheAsBitmapDestroy=function(){this.cacheAsBitmap=!1,this.destroy()}},{"../core":61}],129:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}var i=t("../core"),o=n(i);o.DisplayObject.prototype.name=null,o.Container.prototype.getChildByName=function(t){for(var e=0;e<this.children.length;e++)if(this.children[e].name===t)return this.children[e];return null}},{"../core":61}],130:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}var i=t("../core"),o=n(i);o.DisplayObject.prototype.getGlobalPosition=function(){var t=arguments.length<=0||void 0===arguments[0]?new o.Point:arguments[0],e=!(arguments.length<=1||void 0===arguments[1])&&arguments[1];return this.parent?this.parent.toGlobal(this.position,t,e):(t.x=this.position.x,t.y=this.position.y),t}},{"../core":61}],131:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}r.__esModule=!0,r.BitmapText=r.TilingSpriteRenderer=r.TilingSprite=r.AnimatedSprite=r.TextureTransform=void 0;var i=t("./TextureTransform");Object.defineProperty(r,"TextureTransform",{enumerable:!0,get:function(){return n(i).default}});var o=t("./AnimatedSprite");Object.defineProperty(r,"AnimatedSprite",{enumerable:!0,get:function(){return n(o).default}});var s=t("./TilingSprite");Object.defineProperty(r,"TilingSprite",{enumerable:!0,get:function(){return n(s).default}});var a=t("./webgl/TilingSpriteRenderer");Object.defineProperty(r,"TilingSpriteRenderer",{enumerable:!0,get:function(){return n(a).default}});var u=t("./BitmapText");Object.defineProperty(r,"BitmapText",{enumerable:!0,get:function(){return n(u).default}}),t("./cacheAsBitmap"),t("./getChildByName"),t("./getGlobalPosition")},{"./AnimatedSprite":124,"./BitmapText":125,"./TextureTransform":126,"./TilingSprite":127,"./cacheAsBitmap":128,"./getChildByName":129,"./getGlobalPosition":130,"./webgl/TilingSpriteRenderer":132}],132:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("../../core"),u=n(a),h=t("../../core/const"),l=(t("path"),new u.Matrix),c=new Float32Array(4),d=function(t){function e(r){i(this,e);var n=o(this,t.call(this,r));return n.shader=null,n.simpleShader=null,n.quad=null,n}return s(e,t),e.prototype.onContextChange=function(){var t=this.renderer.gl;this.shader=new u.Shader(t,"attribute vec2 aVertexPosition;\nattribute vec2 aTextureCoord;\n\nuniform mat3 projectionMatrix;\nuniform mat3 translationMatrix;\nuniform mat3 uTransform;\n\nvarying vec2 vTextureCoord;\n\nvoid main(void)\n{\n    gl_Position = vec4((projectionMatrix * translationMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);\n\n    vTextureCoord = (uTransform * vec3(aTextureCoord, 1.0)).xy;\n}\n","varying vec2 vTextureCoord;\n\nuniform sampler2D uSampler;\nuniform vec4 uColor;\nuniform mat3 uMapCoord;\nuniform vec4 uClampFrame;\nuniform vec2 uClampOffset;\n\nvoid main(void)\n{\n    vec2 coord = mod(vTextureCoord - uClampOffset, vec2(1.0, 1.0)) + uClampOffset;\n    coord = (uMapCoord * vec3(coord, 1.0)).xy;\n    coord = clamp(coord, uClampFrame.xy, uClampFrame.zw);\n\n    vec4 sample = texture2D(uSampler, coord);\n    vec4 color = vec4(uColor.rgb * uColor.a, uColor.a);\n\n    gl_FragColor = sample * color ;\n}\n"),this.simpleShader=new u.Shader(t,"attribute vec2 aVertexPosition;\nattribute vec2 aTextureCoord;\n\nuniform mat3 projectionMatrix;\nuniform mat3 translationMatrix;\nuniform mat3 uTransform;\n\nvarying vec2 vTextureCoord;\n\nvoid main(void)\n{\n    gl_Position = vec4((projectionMatrix * translationMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);\n\n    vTextureCoord = (uTransform * vec3(aTextureCoord, 1.0)).xy;\n}\n","varying vec2 vTextureCoord;\n\nuniform sampler2D uSampler;\nuniform vec4 uColor;\n\nvoid main(void)\n{\n    vec4 sample = texture2D(uSampler, vTextureCoord);\n    vec4 color = vec4(uColor.rgb * uColor.a, uColor.a);\n    gl_FragColor = sample * color;\n}\n"),
this.renderer.bindVao(null),this.quad=new u.Quad(t,this.renderer.state.attribState),this.quad.initVao(this.shader)},e.prototype.render=function(t){var e=this.renderer,r=this.quad;e.bindVao(r.vao);var n=r.vertices;n[0]=n[6]=t._width*-t.anchor.x,n[1]=n[3]=t._height*-t.anchor.y,n[2]=n[4]=t._width*(1-t.anchor.x),n[5]=n[7]=t._height*(1-t.anchor.y),n=r.uvs,n[0]=n[6]=-t.anchor.x,n[1]=n[3]=-t.anchor.y,n[2]=n[4]=1-t.anchor.x,n[5]=n[7]=1-t.anchor.y,r.upload();var i=t._texture,o=i.baseTexture,s=t.tileTransform.localTransform,a=t.uvTransform,d=o.isPowerOfTwo&&i.frame.width===o.width&&i.frame.height===o.height;d&&(o._glTextures[e.CONTEXT_UID]?d=o.wrapMode!==h.WRAP_MODES.CLAMP:o.wrapMode===h.WRAP_MODES.CLAMP&&(o.wrapMode=h.WRAP_MODES.REPEAT));var f=d?this.simpleShader:this.shader;e.bindShader(f);var p=i.width,v=i.height,y=t._width,g=t._height;l.set(s.a*p/y,s.b*p/g,s.c*v/y,s.d*v/g,s.tx/y,s.ty/g),l.invert(),d?l.append(a.mapCoord):(f.uniforms.uMapCoord=a.mapCoord.toArray(!0),f.uniforms.uClampFrame=a.uClampFrame,f.uniforms.uClampOffset=a.uClampOffset),f.uniforms.uTransform=l.toArray(!0);var m=c;u.utils.hex2rgb(t.tint,m),m[3]=t.worldAlpha,f.uniforms.uColor=m,f.uniforms.translationMatrix=t.transform.worldTransform.toArray(!0),f.uniforms.uSampler=e.bindTexture(i),e.setBlendMode(t.blendMode),r.vao.draw(this.renderer.gl.TRIANGLES,6,0)},e}(u.ObjectRenderer);r.default=d,u.WebGLRenderer.registerPlugin("tilingSprite",d)},{"../../core":61,"../../core/const":42,path:22}],133:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function o(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function s(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function a(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var u=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),h=t("../../core"),l=i(h),c=t("./BlurXFilter"),d=n(c),f=t("./BlurYFilter"),p=n(f),v=function(t){function e(r,n,i){o(this,e);var a=s(this,t.call(this));return a.blurXFilter=new d.default,a.blurYFilter=new p.default,a.resolution=1,a.padding=0,a.resolution=i||1,a.quality=n||4,a.blur=r||8,a}return a(e,t),e.prototype.apply=function(t,e,r){var n=t.getRenderTarget(!0);this.blurXFilter.apply(t,e,n,!0),this.blurYFilter.apply(t,n,r,!1),t.returnRenderTarget(n)},u(e,[{key:"blur",get:function(){return this.blurXFilter.blur},set:function(t){this.blurXFilter.blur=this.blurYFilter.blur=t,this.padding=2*Math.max(Math.abs(this.blurXFilter.strength),Math.abs(this.blurYFilter.strength))}},{key:"quality",get:function(){return this.blurXFilter.quality},set:function(t){this.blurXFilter.quality=this.blurYFilter.quality=t}},{key:"blurX",get:function(){return this.blurXFilter.blur},set:function(t){this.blurXFilter.blur=t,this.padding=2*Math.max(Math.abs(this.blurXFilter.strength),Math.abs(this.blurYFilter.strength))}},{key:"blurY",get:function(){return this.blurYFilter.blur},set:function(t){this.blurYFilter.blur=t,this.padding=2*Math.max(Math.abs(this.blurXFilter.strength),Math.abs(this.blurYFilter.strength))}}]),e}(l.Filter);r.default=v},{"../../core":61,"./BlurXFilter":134,"./BlurYFilter":135}],134:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function o(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function s(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function a(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var u=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),h=t("../../core"),l=i(h),c=t("./generateBlurVertSource"),d=n(c),f=t("./generateBlurFragSource"),p=n(f),v=t("./getMaxBlurKernelSize"),y=n(v),g=function(t){function e(r,n,i){o(this,e);var a=(0,d.default)(5,!0),u=(0,p.default)(5),h=s(this,t.call(this,a,u));return h.resolution=i||1,h._quality=0,h.quality=n||4,h.strength=r||8,h.firstRun=!0,h}return a(e,t),e.prototype.apply=function(t,e,r,n){if(this.firstRun){var i=t.renderer.gl,o=(0,y.default)(i);this.vertexSrc=(0,d.default)(o,!0),this.fragmentSrc=(0,p.default)(o),this.firstRun=!1}if(this.uniforms.strength=1/r.size.width*(r.size.width/e.size.width),this.uniforms.strength*=this.strength,this.uniforms.strength/=this.passes,1===this.passes)t.applyFilter(this,e,r,n);else{for(var s=t.getRenderTarget(!0),a=e,u=s,h=0;h<this.passes-1;h++){t.applyFilter(this,a,u,!0);var l=u;u=a,a=l}t.applyFilter(this,a,r,n),t.returnRenderTarget(s)}},u(e,[{key:"blur",get:function(){return this.strength},set:function(t){this.padding=2*Math.abs(t),this.strength=t}},{key:"quality",get:function(){return this._quality},set:function(t){this._quality=t,this.passes=t}}]),e}(l.Filter);r.default=g},{"../../core":61,"./generateBlurFragSource":136,"./generateBlurVertSource":137,"./getMaxBlurKernelSize":138}],135:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function o(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function s(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function a(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var u=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),h=t("../../core"),l=i(h),c=t("./generateBlurVertSource"),d=n(c),f=t("./generateBlurFragSource"),p=n(f),v=t("./getMaxBlurKernelSize"),y=n(v),g=function(t){function e(r,n,i){o(this,e);var a=(0,d.default)(5,!1),u=(0,p.default)(5),h=s(this,t.call(this,a,u));return h.resolution=i||1,h._quality=0,h.quality=n||4,h.strength=r||8,h.firstRun=!0,h}return a(e,t),e.prototype.apply=function(t,e,r,n){if(this.firstRun){var i=t.renderer.gl,o=(0,y.default)(i);this.vertexSrc=(0,d.default)(o,!1),this.fragmentSrc=(0,p.default)(o),this.firstRun=!1}if(this.uniforms.strength=1/r.size.height*(r.size.height/e.size.height),this.uniforms.strength*=this.strength,this.uniforms.strength/=this.passes,1===this.passes)t.applyFilter(this,e,r,n);else{for(var s=t.getRenderTarget(!0),a=e,u=s,h=0;h<this.passes-1;h++){t.applyFilter(this,a,u,!0);var l=u;u=a,a=l}t.applyFilter(this,a,r,n),t.returnRenderTarget(s)}},u(e,[{key:"blur",get:function(){return this.strength},set:function(t){this.padding=2*Math.abs(t),this.strength=t}},{key:"quality",get:function(){return this._quality},set:function(t){this._quality=t,this.passes=t}}]),e}(l.Filter);r.default=g},{"../../core":61,"./generateBlurFragSource":136,"./generateBlurVertSource":137,"./getMaxBlurKernelSize":138}],136:[function(t,e,r){"use strict";function n(t){for(var e=i[t],r=e.length,n=o,s="",a="gl_FragColor += texture2D(uSampler, vBlurTexCoords[%index%]) * %value%;",u=void 0,h=0;h<t;h++){var l=a.replace("%index%",h);u=h,h>=r&&(u=t-h-1),l=l.replace("%value%",e[u]),s+=l,s+="\n"}return n=n.replace("%blur%",s),n=n.replace("%size%",t)}r.__esModule=!0,r.default=n;var i={5:[.153388,.221461,.250301],7:[.071303,.131514,.189879,.214607],9:[.028532,.067234,.124009,.179044,.20236],11:[.0093,.028002,.065984,.121703,.175713,.198596],13:[.002406,.009255,.027867,.065666,.121117,.174868,.197641],15:[489e-6,.002403,.009246,.02784,.065602,.120999,.174697,.197448]},o=["varying vec2 vBlurTexCoords[%size%];","uniform sampler2D uSampler;","void main(void)","{","    gl_FragColor = vec4(0.0);","    %blur%","}"].join("\n")},{}],137:[function(t,e,r){"use strict";function n(t,e){var r=Math.ceil(t/2),n=i,o="",s=void 0;s=e?"vBlurTexCoords[%index%] = aTextureCoord + vec2(%sampleIndex% * strength, 0.0);":"vBlurTexCoords[%index%] = aTextureCoord + vec2(0.0, %sampleIndex% * strength);";for(var a=0;a<t;a++){var u=s.replace("%index%",a);u=u.replace("%sampleIndex%",a-(r-1)+".0"),o+=u,o+="\n"}return n=n.replace("%blur%",o),n=n.replace("%size%",t)}r.__esModule=!0,r.default=n;var i=["attribute vec2 aVertexPosition;","attribute vec2 aTextureCoord;","uniform float strength;","uniform mat3 projectionMatrix;","varying vec2 vBlurTexCoords[%size%];","void main(void)","{","gl_Position = vec4((projectionMatrix * vec3((aVertexPosition), 1.0)).xy, 0.0, 1.0);","%blur%","}"].join("\n")},{}],138:[function(t,e,r){"use strict";function n(t){for(var e=t.getParameter(t.MAX_VARYING_VECTORS),r=15;r>e;)r-=2;return r}r.__esModule=!0,r.default=n},{}],139:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),u=t("../../core"),h=n(u),l=(t("path"),function(t){function e(){i(this,e);var r=o(this,t.call(this,"attribute vec2 aVertexPosition;\nattribute vec2 aTextureCoord;\n\nuniform mat3 projectionMatrix;\n\nvarying vec2 vTextureCoord;\n\nvoid main(void)\n{\n    gl_Position = vec4((projectionMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);\n    vTextureCoord = aTextureCoord;\n}","varying vec2 vTextureCoord;\nuniform sampler2D uSampler;\nuniform float m[20];\n\nvoid main(void)\n{\n\n    vec4 c = texture2D(uSampler, vTextureCoord);\n\n    gl_FragColor.r = (m[0] * c.r);\n        gl_FragColor.r += (m[1] * c.g);\n        gl_FragColor.r += (m[2] * c.b);\n        gl_FragColor.r += (m[3] * c.a);\n        gl_FragColor.r += m[4] * c.a;\n\n    gl_FragColor.g = (m[5] * c.r);\n        gl_FragColor.g += (m[6] * c.g);\n        gl_FragColor.g += (m[7] * c.b);\n        gl_FragColor.g += (m[8] * c.a);\n        gl_FragColor.g += m[9] * c.a;\n\n     gl_FragColor.b = (m[10] * c.r);\n        gl_FragColor.b += (m[11] * c.g);\n        gl_FragColor.b += (m[12] * c.b);\n        gl_FragColor.b += (m[13] * c.a);\n        gl_FragColor.b += m[14] * c.a;\n\n     gl_FragColor.a = (m[15] * c.r);\n        gl_FragColor.a += (m[16] * c.g);\n        gl_FragColor.a += (m[17] * c.b);\n        gl_FragColor.a += (m[18] * c.a);\n        gl_FragColor.a += m[19] * c.a;\n\n//    gl_FragColor = vec4(m[0]);\n}\n"));return r.uniforms.m=[1,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,1,0],r}return s(e,t),e.prototype._loadMatrix=function(t){var e=!(arguments.length<=1||void 0===arguments[1])&&arguments[1],r=t;e&&(this._multiply(r,this.uniforms.m,t),r=this._colorMatrix(r)),this.uniforms.m=r},e.prototype._multiply=function(t,e,r){return t[0]=e[0]*r[0]+e[1]*r[5]+e[2]*r[10]+e[3]*r[15],t[1]=e[0]*r[1]+e[1]*r[6]+e[2]*r[11]+e[3]*r[16],t[2]=e[0]*r[2]+e[1]*r[7]+e[2]*r[12]+e[3]*r[17],t[3]=e[0]*r[3]+e[1]*r[8]+e[2]*r[13]+e[3]*r[18],t[4]=e[0]*r[4]+e[1]*r[9]+e[2]*r[14]+e[3]*r[19],t[5]=e[5]*r[0]+e[6]*r[5]+e[7]*r[10]+e[8]*r[15],t[6]=e[5]*r[1]+e[6]*r[6]+e[7]*r[11]+e[8]*r[16],t[7]=e[5]*r[2]+e[6]*r[7]+e[7]*r[12]+e[8]*r[17],t[8]=e[5]*r[3]+e[6]*r[8]+e[7]*r[13]+e[8]*r[18],t[9]=e[5]*r[4]+e[6]*r[9]+e[7]*r[14]+e[8]*r[19],t[10]=e[10]*r[0]+e[11]*r[5]+e[12]*r[10]+e[13]*r[15],t[11]=e[10]*r[1]+e[11]*r[6]+e[12]*r[11]+e[13]*r[16],t[12]=e[10]*r[2]+e[11]*r[7]+e[12]*r[12]+e[13]*r[17],t[13]=e[10]*r[3]+e[11]*r[8]+e[12]*r[13]+e[13]*r[18],t[14]=e[10]*r[4]+e[11]*r[9]+e[12]*r[14]+e[13]*r[19],t[15]=e[15]*r[0]+e[16]*r[5]+e[17]*r[10]+e[18]*r[15],t[16]=e[15]*r[1]+e[16]*r[6]+e[17]*r[11]+e[18]*r[16],t[17]=e[15]*r[2]+e[16]*r[7]+e[17]*r[12]+e[18]*r[17],t[18]=e[15]*r[3]+e[16]*r[8]+e[17]*r[13]+e[18]*r[18],t[19]=e[15]*r[4]+e[16]*r[9]+e[17]*r[14]+e[18]*r[19],t},e.prototype._colorMatrix=function(t){var e=new Float32Array(t);return e[4]/=255,e[9]/=255,e[14]/=255,e[19]/=255,e},e.prototype.brightness=function(t,e){var r=[t,0,0,0,0,0,t,0,0,0,0,0,t,0,0,0,0,0,1,0];this._loadMatrix(r,e)},e.prototype.greyscale=function(t,e){var r=[t,t,t,0,0,t,t,t,0,0,t,t,t,0,0,0,0,0,1,0];this._loadMatrix(r,e)},e.prototype.blackAndWhite=function(t){var e=[.3,.6,.1,0,0,.3,.6,.1,0,0,.3,.6,.1,0,0,0,0,0,1,0];this._loadMatrix(e,t)},e.prototype.hue=function(t,e){t=(t||0)/180*Math.PI;var r=Math.cos(t),n=Math.sin(t),i=Math.sqrt,o=1/3,s=i(o),a=r+(1-r)*o,u=o*(1-r)-s*n,h=o*(1-r)+s*n,l=o*(1-r)+s*n,c=r+o*(1-r),d=o*(1-r)-s*n,f=o*(1-r)-s*n,p=o*(1-r)+s*n,v=r+o*(1-r),y=[a,u,h,0,0,l,c,d,0,0,f,p,v,0,0,0,0,0,1,0];this._loadMatrix(y,e)},e.prototype.contrast=function(t,e){var r=(t||0)+1,n=-128*(r-1),i=[r,0,0,0,n,0,r,0,0,n,0,0,r,0,n,0,0,0,1,0];this._loadMatrix(i,e)},e.prototype.saturate=function(){var t=arguments.length<=0||void 0===arguments[0]?0:arguments[0],e=arguments[1],r=2*t/3+1,n=(r-1)*-.5,i=[r,n,n,0,0,n,r,n,0,0,n,n,r,0,0,0,0,0,1,0];this._loadMatrix(i,e)},e.prototype.desaturate=function(){this.saturate(-1)},e.prototype.negative=function(t){var e=[0,1,1,0,0,1,0,1,0,0,1,1,0,0,0,0,0,0,1,0];this._loadMatrix(e,t)},e.prototype.sepia=function(t){var e=[.393,.7689999,.18899999,0,0,.349,.6859999,.16799999,0,0,.272,.5339999,.13099999,0,0,0,0,0,1,0];this._loadMatrix(e,t)},e.prototype.technicolor=function(t){var e=[1.9125277891456083,-.8545344976951645,-.09155508482755585,0,11.793603434377337,-.3087833385928097,1.7658908555458428,-.10601743074722245,0,-70.35205161461398,-.231103377548616,-.7501899197440212,1.847597816108189,0,30.950940869491138,0,0,0,1,0];this._loadMatrix(e,t)},e.prototype.polaroid=function(t){var e=[1.438,-.062,-.062,0,0,-.122,1.378,-.122,0,0,-.016,-.016,1.483,0,0,0,0,0,1,0];this._loadMatrix(e,t)},e.prototype.toBGR=function(t){var e=[0,0,1,0,0,0,1,0,0,0,1,0,0,0,0,0,0,0,1,0];this._loadMatrix(e,t)},e.prototype.kodachrome=function(t){var e=[1.1285582396593525,-.3967382283601348,-.03992559172921793,0,63.72958762196502,-.16404339962244616,1.0835251566291304,-.05498805115633132,0,24.732407896706203,-.16786010706155763,-.5603416277695248,1.6014850761964943,0,35.62982807460946,0,0,0,1,0];this._loadMatrix(e,t)},e.prototype.browni=function(t){var e=[.5997023498159715,.34553243048391263,-.2708298674538042,0,47.43192855600873,-.037703249837783157,.8609577587992641,.15059552388459913,0,-36.96841498319127,.24113635128153335,-.07441037908422492,.44972182064877153,0,-7.562075277591283,0,0,0,1,0];this._loadMatrix(e,t)},e.prototype.vintage=function(t){var e=[.6279345635605994,.3202183420819367,-.03965408211312453,0,9.651285835294123,.02578397704808868,.6441188644374771,.03259127616149294,0,7.462829176470591,.0466055556782719,-.0851232987247891,.5241648018700465,0,5.159190588235296,0,0,0,1,0];this._loadMatrix(e,t)},e.prototype.colorTone=function(t,e,r,n,i){t=t||.2,e=e||.15,r=r||16770432,n=n||3375104;var o=(r>>16&255)/255,s=(r>>8&255)/255,a=(255&r)/255,u=(n>>16&255)/255,h=(n>>8&255)/255,l=(255&n)/255,c=[.3,.59,.11,0,0,o,s,a,t,0,u,h,l,e,0,o-u,s-h,a-l,0,0];this._loadMatrix(c,i)},e.prototype.night=function(t,e){t=t||.1;var r=[t*-2,-t,0,0,0,-t,0,t,0,0,0,t,2*t,0,0,0,0,0,1,0];this._loadMatrix(r,e)},e.prototype.predator=function(t,e){var r=[11.224130630493164*t,-4.794486999511719*t,-2.8746118545532227*t,0*t,.40342438220977783*t,-3.6330697536468506*t,9.193157196044922*t,-2.951810836791992*t,0*t,-1.316135048866272*t,-3.2184197902679443*t,-4.2375030517578125*t,7.476448059082031*t,0*t,.8044459223747253*t,0,0,0,1,0];this._loadMatrix(r,e)},e.prototype.lsd=function(t){var e=[2,-.4,.5,0,0,-.5,2,-.4,0,0,-.4,-.5,3,0,0,0,0,0,1,0];this._loadMatrix(e,t)},e.prototype.reset=function(){var t=[1,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,1,0];this._loadMatrix(t,!1)},a(e,[{key:"matrix",get:function(){return this.uniforms.m},set:function(t){this.uniforms.m=t}}]),e}(h.Filter));r.default=l,l.prototype.grayscale=l.prototype.greyscale},{"../../core":61,path:22}],140:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),u=t("../../core"),h=n(u),l=(t("path"),function(t){function e(r,n){i(this,e);var s=new h.Matrix;r.renderable=!1;var a=o(this,t.call(this,"attribute vec2 aVertexPosition;\nattribute vec2 aTextureCoord;\n\nuniform mat3 projectionMatrix;\nuniform mat3 filterMatrix;\n\nvarying vec2 vTextureCoord;\nvarying vec2 vFilterCoord;\n\nvoid main(void)\n{\n   gl_Position = vec4((projectionMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);\n   vFilterCoord = ( filterMatrix * vec3( aTextureCoord, 1.0)  ).xy;\n   vTextureCoord = aTextureCoord;\n}","varying vec2 vFilterCoord;\nvarying vec2 vTextureCoord;\n\nuniform vec2 scale;\n\nuniform sampler2D uSampler;\nuniform sampler2D mapSampler;\n\nuniform vec4 filterClamp;\n\nvoid main(void)\n{\n   vec4 map =  texture2D(mapSampler, vFilterCoord);\n\n   map -= 0.5;\n   map.xy *= scale;\n\n   gl_FragColor = texture2D(uSampler, clamp(vec2(vTextureCoord.x + map.x, vTextureCoord.y + map.y), filterClamp.xy, filterClamp.zw));\n}\n"));return a.maskSprite=r,a.maskMatrix=s,a.uniforms.mapSampler=r.texture,a.uniforms.filterMatrix=s.toArray(!0),a.uniforms.scale={x:1,y:1},null!==n&&void 0!==n||(n=20),a.scale=new h.Point(n,n),a}return s(e,t),e.prototype.apply=function(t,e,r){var n=1/r.destinationFrame.width*(r.size.width/e.size.width);this.uniforms.filterMatrix=t.calculateSpriteMatrix(this.maskMatrix,this.maskSprite),this.uniforms.scale.x=this.scale.x*n,this.uniforms.scale.y=this.scale.y*n,t.applyFilter(this,e,r)},a(e,[{key:"map",get:function(){return this.uniforms.mapSampler},set:function(t){this.uniforms.mapSampler=t}}]),e}(h.Filter));r.default=l},{"../../core":61,path:22}],141:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("../../core"),u=n(a),h=(t("path"),function(t){function e(){return i(this,e),o(this,t.call(this,"\nattribute vec2 aVertexPosition;\nattribute vec2 aTextureCoord;\n\nuniform mat3 projectionMatrix;\n\nvarying vec2 v_rgbNW;\nvarying vec2 v_rgbNE;\nvarying vec2 v_rgbSW;\nvarying vec2 v_rgbSE;\nvarying vec2 v_rgbM;\n\nuniform vec4 filterArea;\n\nvarying vec2 vTextureCoord;\n\nvec2 mapCoord( vec2 coord )\n{\n    coord *= filterArea.xy;\n    coord += filterArea.zw;\n\n    return coord;\n}\n\nvec2 unmapCoord( vec2 coord )\n{\n    coord -= filterArea.zw;\n    coord /= filterArea.xy;\n\n    return coord;\n}\n\nvoid texcoords(vec2 fragCoord, vec2 resolution,\n               out vec2 v_rgbNW, out vec2 v_rgbNE,\n               out vec2 v_rgbSW, out vec2 v_rgbSE,\n               out vec2 v_rgbM) {\n    vec2 inverseVP = 1.0 / resolution.xy;\n    v_rgbNW = (fragCoord + vec2(-1.0, -1.0)) * inverseVP;\n    v_rgbNE = (fragCoord + vec2(1.0, -1.0)) * inverseVP;\n    v_rgbSW = (fragCoord + vec2(-1.0, 1.0)) * inverseVP;\n    v_rgbSE = (fragCoord + vec2(1.0, 1.0)) * inverseVP;\n    v_rgbM = vec2(fragCoord * inverseVP);\n}\n\nvoid main(void) {\n\n   gl_Position = vec4((projectionMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);\n\n   vTextureCoord = aTextureCoord;\n\n   vec2 fragCoord = vTextureCoord * filterArea.xy;\n\n   texcoords(fragCoord, filterArea.xy, v_rgbNW, v_rgbNE, v_rgbSW, v_rgbSE, v_rgbM);\n}",'varying vec2 v_rgbNW;\nvarying vec2 v_rgbNE;\nvarying vec2 v_rgbSW;\nvarying vec2 v_rgbSE;\nvarying vec2 v_rgbM;\n\nvarying vec2 vTextureCoord;\nuniform sampler2D uSampler;\nuniform vec4 filterArea;\n\n/**\n Basic FXAA implementation based on the code on geeks3d.com with the\n modification that the texture2DLod stuff was removed since it\'s\n unsupported by WebGL.\n \n --\n \n From:\n https://github.com/mitsuhiko/webgl-meincraft\n \n Copyright (c) 2011 by Armin Ronacher.\n \n Some rights reserved.\n \n Redistribution and use in source and binary forms, with or without\n modification, are permitted provided that the following conditions are\n met:\n \n * Redistributions of source code must retain the above copyright\n notice, this list of conditions and the following disclaimer.\n \n * Redistributions in binary form must reproduce the above\n copyright notice, this list of conditions and the following\n disclaimer in the documentation and/or other materials provided\n with the distribution.\n \n * The names of the contributors may not be used to endorse or\n promote products derived from this software without specific\n prior written permission.\n \n THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS\n "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT\n LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR\n A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT\n OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,\n SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT\n LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,\n DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY\n THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT\n (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE\n OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.\n */\n\n#ifndef FXAA_REDUCE_MIN\n#define FXAA_REDUCE_MIN   (1.0/ 128.0)\n#endif\n#ifndef FXAA_REDUCE_MUL\n#define FXAA_REDUCE_MUL   (1.0 / 8.0)\n#endif\n#ifndef FXAA_SPAN_MAX\n#define FXAA_SPAN_MAX     8.0\n#endif\n\n//optimized version for mobile, where dependent\n//texture reads can be a bottleneck\nvec4 fxaa(sampler2D tex, vec2 fragCoord, vec2 resolution,\n          vec2 v_rgbNW, vec2 v_rgbNE,\n          vec2 v_rgbSW, vec2 v_rgbSE,\n          vec2 v_rgbM) {\n    vec4 color;\n    mediump vec2 inverseVP = vec2(1.0 / resolution.x, 1.0 / resolution.y);\n    vec3 rgbNW = texture2D(tex, v_rgbNW).xyz;\n    vec3 rgbNE = texture2D(tex, v_rgbNE).xyz;\n    vec3 rgbSW = texture2D(tex, v_rgbSW).xyz;\n    vec3 rgbSE = texture2D(tex, v_rgbSE).xyz;\n    vec4 texColor = texture2D(tex, v_rgbM);\n    vec3 rgbM  = texColor.xyz;\n    vec3 luma = vec3(0.299, 0.587, 0.114);\n    float lumaNW = dot(rgbNW, luma);\n    float lumaNE = dot(rgbNE, luma);\n    float lumaSW = dot(rgbSW, luma);\n    float lumaSE = dot(rgbSE, luma);\n    float lumaM  = dot(rgbM,  luma);\n    float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));\n    float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));\n    \n    mediump vec2 dir;\n    dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));\n    dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));\n    \n    float dirReduce = max((lumaNW + lumaNE + lumaSW + lumaSE) *\n                          (0.25 * FXAA_REDUCE_MUL), FXAA_REDUCE_MIN);\n    \n    float rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);\n    dir = min(vec2(FXAA_SPAN_MAX, FXAA_SPAN_MAX),\n              max(vec2(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX),\n                  dir * rcpDirMin)) * inverseVP;\n    \n    vec3 rgbA = 0.5 * (\n                       texture2D(tex, fragCoord * inverseVP + dir * (1.0 / 3.0 - 0.5)).xyz +\n                       texture2D(tex, fragCoord * inverseVP + dir * (2.0 / 3.0 - 0.5)).xyz);\n    vec3 rgbB = rgbA * 0.5 + 0.25 * (\n                                     texture2D(tex, fragCoord * inverseVP + dir * -0.5).xyz +\n                                     texture2D(tex, fragCoord * inverseVP + dir * 0.5).xyz);\n    \n    float lumaB = dot(rgbB, luma);\n    if ((lumaB < lumaMin) || (lumaB > lumaMax))\n        color = vec4(rgbA, texColor.a);\n    else\n        color = vec4(rgbB, texColor.a);\n    return color;\n}\n\nvoid main() {\n\n      vec2 fragCoord = vTextureCoord * filterArea.xy;\n\n      vec4 color;\n\n    color = fxaa(uSampler, fragCoord, filterArea.xy, v_rgbNW, v_rgbNE, v_rgbSW, v_rgbSE, v_rgbM);\n\n      gl_FragColor = color;\n}\n'))}return s(e,t),e}(u.Filter));r.default=h},{"../../core":61,path:22}],142:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}r.__esModule=!0;var i=t("./fxaa/FXAAFilter");Object.defineProperty(r,"FXAAFilter",{enumerable:!0,get:function(){return n(i).default}});var o=t("./noise/NoiseFilter");Object.defineProperty(r,"NoiseFilter",{enumerable:!0,get:function(){return n(o).default}});var s=t("./displacement/DisplacementFilter");Object.defineProperty(r,"DisplacementFilter",{enumerable:!0,get:function(){return n(s).default}});var a=t("./blur/BlurFilter");Object.defineProperty(r,"BlurFilter",{enumerable:!0,get:function(){return n(a).default}});var u=t("./blur/BlurXFilter");Object.defineProperty(r,"BlurXFilter",{enumerable:!0,get:function(){return n(u).default}});var h=t("./blur/BlurYFilter");Object.defineProperty(r,"BlurYFilter",{enumerable:!0,get:function(){return n(h).default}});var l=t("./colormatrix/ColorMatrixFilter");Object.defineProperty(r,"ColorMatrixFilter",{enumerable:!0,get:function(){return n(l).default}});var c=t("./void/VoidFilter");Object.defineProperty(r,"VoidFilter",{enumerable:!0,get:function(){return n(c).default}})},{"./blur/BlurFilter":133,"./blur/BlurXFilter":134,"./blur/BlurYFilter":135,"./colormatrix/ColorMatrixFilter":139,"./displacement/DisplacementFilter":140,"./fxaa/FXAAFilter":141,"./noise/NoiseFilter":143,"./void/VoidFilter":144}],143:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),u=t("../../core"),h=n(u),l=(t("path"),function(t){function e(){i(this,e);var r=o(this,t.call(this,"attribute vec2 aVertexPosition;\nattribute vec2 aTextureCoord;\n\nuniform mat3 projectionMatrix;\n\nvarying vec2 vTextureCoord;\n\nvoid main(void)\n{\n    gl_Position = vec4((projectionMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);\n    vTextureCoord = aTextureCoord;\n}","precision highp float;\n\nvarying vec2 vTextureCoord;\nvarying vec4 vColor;\n\nuniform float noise;\nuniform sampler2D uSampler;\n\nfloat rand(vec2 co)\n{\n    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);\n}\n\nvoid main()\n{\n    vec4 color = texture2D(uSampler, vTextureCoord);\n\n    float diff = (rand(gl_FragCoord.xy) - 0.5) * noise;\n\n    color.r += diff;\n    color.g += diff;\n    color.b += diff;\n\n    gl_FragColor = color;\n}\n"));return r.noise=.5,r}return s(e,t),a(e,[{key:"noise",get:function(){return this.uniforms.noise},set:function(t){this.uniforms.noise=t}}]),e}(h.Filter));r.default=l},{"../../core":61,path:22}],144:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("../../core"),u=n(a),h=(t("path"),function(t){function e(){i(this,e);var r=o(this,t.call(this,"attribute vec2 aVertexPosition;\nattribute vec2 aTextureCoord;\n\nuniform mat3 projectionMatrix;\n\nvarying vec2 vTextureCoord;\n\nvoid main(void)\n{\n    gl_Position = vec4((projectionMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);\n    vTextureCoord = aTextureCoord;\n}","varying vec2 vTextureCoord;\n\nuniform sampler2D uSampler;\n\nvoid main(void)\n{\n   gl_FragColor = texture2D(uSampler, vTextureCoord);\n}\n"));
return r.glShaderKey="void",r}return s(e,t),e}(u.Filter));r.default=h},{"../../core":61,path:22}],145:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=t("../core"),s=n(o),a=function(){function t(){i(this,t),this.global=new s.Point,this.target=null,this.originalEvent=null}return t.prototype.getLocalPosition=function(t,e,r){return t.worldTransform.applyInverse(r||this.global,e)},t}();r.default=a},{"../core":61}],146:[function(t,e,r){"use strict";function n(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var i=function(){function t(){n(this,t),this.stopped=!1,this.target=null,this.currentTarget=null,this.type=null,this.data=null}return t.prototype.stopPropagation=function(){this.stopped=!0},t.prototype._reset=function(){this.stopped=!1,this.currentTarget=null,this.target=null},t}();r.default=i},{}],147:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function o(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function s(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function a(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var u=t("../core"),h=i(u),l=t("./InteractionData"),c=n(l),d=t("./InteractionEvent"),f=n(d),p=t("eventemitter3"),v=n(p),y=t("./interactiveTarget"),g=n(y),m=t("ismobilejs"),_=n(m);Object.assign(h.DisplayObject.prototype,g.default);var b=function(t){function e(r,n){o(this,e);var i=s(this,t.call(this));return n=n||{},i.renderer=r,i.autoPreventDefault=void 0===n.autoPreventDefault||n.autoPreventDefault,i.interactionFrequency=n.interactionFrequency||10,i.mouse=new c.default,i.mouse.global.set(-999999),i.pointer=new c.default,i.pointer.global.set(-999999),i.eventData=new f.default,i.interactiveDataPool=[],i.interactionDOMElement=null,i.moveWhenInside=!1,i.eventsAdded=!1,i.mouseOverRenderer=!1,i.supportsTouchEvents="ontouchstart"in window,i.supportsPointerEvents=!!window.PointerEvent,i.normalizeTouchEvents=!i.supportsPointerEvents&&i.supportsTouchEvents,i.normalizeMouseEvents=!i.supportsPointerEvents&&!_.default.any,i.onMouseUp=i.onMouseUp.bind(i),i.processMouseUp=i.processMouseUp.bind(i),i.onMouseDown=i.onMouseDown.bind(i),i.processMouseDown=i.processMouseDown.bind(i),i.onMouseMove=i.onMouseMove.bind(i),i.processMouseMove=i.processMouseMove.bind(i),i.onMouseOut=i.onMouseOut.bind(i),i.processMouseOverOut=i.processMouseOverOut.bind(i),i.onMouseOver=i.onMouseOver.bind(i),i.onPointerUp=i.onPointerUp.bind(i),i.processPointerUp=i.processPointerUp.bind(i),i.onPointerDown=i.onPointerDown.bind(i),i.processPointerDown=i.processPointerDown.bind(i),i.onPointerMove=i.onPointerMove.bind(i),i.processPointerMove=i.processPointerMove.bind(i),i.onPointerOut=i.onPointerOut.bind(i),i.processPointerOverOut=i.processPointerOverOut.bind(i),i.onPointerOver=i.onPointerOver.bind(i),i.onTouchStart=i.onTouchStart.bind(i),i.processTouchStart=i.processTouchStart.bind(i),i.onTouchEnd=i.onTouchEnd.bind(i),i.processTouchEnd=i.processTouchEnd.bind(i),i.onTouchMove=i.onTouchMove.bind(i),i.processTouchMove=i.processTouchMove.bind(i),i.defaultCursorStyle="inherit",i.currentCursorStyle="inherit",i._tempPoint=new h.Point,i.resolution=1,i.setTargetElement(i.renderer.view,i.renderer.resolution),i}return a(e,t),e.prototype.setTargetElement=function(t){var e=arguments.length<=1||void 0===arguments[1]?1:arguments[1];this.removeEvents(),this.interactionDOMElement=t,this.resolution=e,this.addEvents()},e.prototype.addEvents=function(){this.interactionDOMElement&&(h.ticker.shared.add(this.update,this),window.navigator.msPointerEnabled?(this.interactionDOMElement.style["-ms-content-zooming"]="none",this.interactionDOMElement.style["-ms-touch-action"]="none"):this.supportsPointerEvents&&(this.interactionDOMElement.style["touch-action"]="none"),this.supportsPointerEvents?(window.document.addEventListener("pointermove",this.onPointerMove,!0),this.interactionDOMElement.addEventListener("pointerdown",this.onPointerDown,!0),this.interactionDOMElement.addEventListener("pointerout",this.onPointerOut,!0),this.interactionDOMElement.addEventListener("pointerover",this.onPointerOver,!0),window.addEventListener("pointerup",this.onPointerUp,!0)):(this.normalizeTouchEvents&&(this.interactionDOMElement.addEventListener("touchstart",this.onPointerDown,!0),this.interactionDOMElement.addEventListener("touchend",this.onPointerUp,!0),this.interactionDOMElement.addEventListener("touchmove",this.onPointerMove,!0)),this.normalizeMouseEvents&&(window.document.addEventListener("mousemove",this.onPointerMove,!0),this.interactionDOMElement.addEventListener("mousedown",this.onPointerDown,!0),this.interactionDOMElement.addEventListener("mouseout",this.onPointerOut,!0),this.interactionDOMElement.addEventListener("mouseover",this.onPointerOver,!0),window.addEventListener("mouseup",this.onPointerUp,!0))),window.document.addEventListener("mousemove",this.onMouseMove,!0),this.interactionDOMElement.addEventListener("mousedown",this.onMouseDown,!0),this.interactionDOMElement.addEventListener("mouseout",this.onMouseOut,!0),this.interactionDOMElement.addEventListener("mouseover",this.onMouseOver,!0),window.addEventListener("mouseup",this.onMouseUp,!0),this.supportsTouchEvents&&(this.interactionDOMElement.addEventListener("touchstart",this.onTouchStart,!0),this.interactionDOMElement.addEventListener("touchend",this.onTouchEnd,!0),this.interactionDOMElement.addEventListener("touchmove",this.onTouchMove,!0)),this.eventsAdded=!0)},e.prototype.removeEvents=function(){this.interactionDOMElement&&(h.ticker.shared.remove(this.update,this),window.navigator.msPointerEnabled?(this.interactionDOMElement.style["-ms-content-zooming"]="",this.interactionDOMElement.style["-ms-touch-action"]=""):this.supportsPointerEvents&&(this.interactionDOMElement.style["touch-action"]=""),this.supportsPointerEvents?(window.document.removeEventListener("pointermove",this.onPointerMove,!0),this.interactionDOMElement.removeEventListener("pointerdown",this.onPointerDown,!0),this.interactionDOMElement.removeEventListener("pointerout",this.onPointerOut,!0),this.interactionDOMElement.removeEventListener("pointerover",this.onPointerOver,!0),window.removeEventListener("pointerup",this.onPointerUp,!0)):(this.normalizeTouchEvents&&(this.interactionDOMElement.removeEventListener("touchstart",this.onPointerDown,!0),this.interactionDOMElement.removeEventListener("touchend",this.onPointerUp,!0),this.interactionDOMElement.removeEventListener("touchmove",this.onPointerMove,!0)),this.normalizeMouseEvents&&(window.document.removeEventListener("mousemove",this.onPointerMove,!0),this.interactionDOMElement.removeEventListener("mousedown",this.onPointerDown,!0),this.interactionDOMElement.removeEventListener("mouseout",this.onPointerOut,!0),this.interactionDOMElement.removeEventListener("mouseover",this.onPointerOver,!0),window.removeEventListener("mouseup",this.onPointerUp,!0))),window.document.removeEventListener("mousemove",this.onMouseMove,!0),this.interactionDOMElement.removeEventListener("mousedown",this.onMouseDown,!0),this.interactionDOMElement.removeEventListener("mouseout",this.onMouseOut,!0),this.interactionDOMElement.removeEventListener("mouseover",this.onMouseOver,!0),window.removeEventListener("mouseup",this.onMouseUp,!0),this.supportsTouchEvents&&(this.interactionDOMElement.removeEventListener("touchstart",this.onTouchStart,!0),this.interactionDOMElement.removeEventListener("touchend",this.onTouchEnd,!0),this.interactionDOMElement.removeEventListener("touchmove",this.onTouchMove,!0)),this.interactionDOMElement=null,this.eventsAdded=!1)},e.prototype.update=function(t){if(this._deltaTime+=t,!(this._deltaTime<this.interactionFrequency)&&(this._deltaTime=0,this.interactionDOMElement)){if(this.didMove)return void(this.didMove=!1);this.cursor=this.defaultCursorStyle,this.eventData._reset(),this.processInteractive(this.mouse.global,this.renderer._lastObjectRendered,this.processMouseOverOut,!0),this.currentCursorStyle!==this.cursor&&(this.currentCursorStyle=this.cursor,this.interactionDOMElement.style.cursor=this.cursor)}},e.prototype.dispatchEvent=function(t,e,r){r.stopped||(r.currentTarget=t,r.type=e,t.emit(e,r),t[e]&&t[e](r))},e.prototype.mapPositionToPoint=function(t,e,r){var n=void 0;n=this.interactionDOMElement.parentElement?this.interactionDOMElement.getBoundingClientRect():{x:0,y:0,width:0,height:0},t.x=(e-n.left)*(this.interactionDOMElement.width/n.width)/this.resolution,t.y=(r-n.top)*(this.interactionDOMElement.height/n.height)/this.resolution},e.prototype.processInteractive=function(t,e,r,n,i){if(!e||!e.visible)return!1;i=e.interactive||i;var o=!1,s=i;if(e.hitArea&&(s=!1),n&&e._mask&&(e._mask.containsPoint(t)||(n=!1)),n&&e.filterArea&&(e.filterArea.contains(t.x,t.y)||(n=!1)),e.interactiveChildren&&e.children)for(var a=e.children,u=a.length-1;u>=0;u--){var h=a[u];if(this.processInteractive(t,h,r,n,s)){if(!h.parent)continue;o=!0,s=!1,n=!1}}return i&&(n&&!o&&(e.hitArea?(e.worldTransform.applyInverse(t,this._tempPoint),o=e.hitArea.contains(this._tempPoint.x,this._tempPoint.y)):e.containsPoint&&(o=e.containsPoint(t))),e.interactive&&(o&&!this.eventData.target&&(this.eventData.target=e,this.mouse.target=e,this.pointer.target=e),r(e,o))),o},e.prototype.onMouseDown=function(t){this.mouse.originalEvent=t,this.eventData.data=this.mouse,this.eventData._reset(),this.mapPositionToPoint(this.mouse.global,t.clientX,t.clientY),this.autoPreventDefault&&this.mouse.originalEvent.preventDefault(),this.processInteractive(this.mouse.global,this.renderer._lastObjectRendered,this.processMouseDown,!0);var e=2===t.button||3===t.which;this.emit(e?"rightdown":"mousedown",this.eventData)},e.prototype.processMouseDown=function(t,e){var r=this.mouse.originalEvent,n=2===r.button||3===r.which;e&&(t[n?"_isRightDown":"_isLeftDown"]=!0,this.dispatchEvent(t,n?"rightdown":"mousedown",this.eventData))},e.prototype.onMouseUp=function(t){this.mouse.originalEvent=t,this.eventData.data=this.mouse,this.eventData._reset(),this.mapPositionToPoint(this.mouse.global,t.clientX,t.clientY),this.processInteractive(this.mouse.global,this.renderer._lastObjectRendered,this.processMouseUp,!0);var e=2===t.button||3===t.which;this.emit(e?"rightup":"mouseup",this.eventData)},e.prototype.processMouseUp=function(t,e){var r=this.mouse.originalEvent,n=2===r.button||3===r.which,i=n?"_isRightDown":"_isLeftDown";e?(this.dispatchEvent(t,n?"rightup":"mouseup",this.eventData),t[i]&&(t[i]=!1,this.dispatchEvent(t,n?"rightclick":"click",this.eventData))):t[i]&&(t[i]=!1,this.dispatchEvent(t,n?"rightupoutside":"mouseupoutside",this.eventData))},e.prototype.onMouseMove=function(t){this.mouse.originalEvent=t,this.eventData.data=this.mouse,this.eventData._reset(),this.mapPositionToPoint(this.mouse.global,t.clientX,t.clientY),this.didMove=!0,this.cursor=this.defaultCursorStyle,this.processInteractive(this.mouse.global,this.renderer._lastObjectRendered,this.processMouseMove,!0),this.emit("mousemove",this.eventData),this.currentCursorStyle!==this.cursor&&(this.currentCursorStyle=this.cursor,this.interactionDOMElement.style.cursor=this.cursor)},e.prototype.processMouseMove=function(t,e){this.processMouseOverOut(t,e),this.moveWhenInside&&!e||this.dispatchEvent(t,"mousemove",this.eventData)},e.prototype.onMouseOut=function(t){this.mouseOverRenderer=!1,this.mouse.originalEvent=t,this.eventData.data=this.mouse,this.eventData._reset(),this.mapPositionToPoint(this.mouse.global,t.clientX,t.clientY),this.interactionDOMElement.style.cursor=this.defaultCursorStyle,this.mapPositionToPoint(this.mouse.global,t.clientX,t.clientY),this.processInteractive(this.mouse.global,this.renderer._lastObjectRendered,this.processMouseOverOut,!1),this.emit("mouseout",this.eventData)},e.prototype.processMouseOverOut=function(t,e){e&&this.mouseOverRenderer?(t._mouseOver||(t._mouseOver=!0,this.dispatchEvent(t,"mouseover",this.eventData)),t.buttonMode&&(this.cursor=t.defaultCursor)):t._mouseOver&&(t._mouseOver=!1,this.dispatchEvent(t,"mouseout",this.eventData))},e.prototype.onMouseOver=function(t){this.mouseOverRenderer=!0,this.mouse.originalEvent=t,this.eventData.data=this.mouse,this.eventData._reset(),this.emit("mouseover",this.eventData)},e.prototype.onPointerDown=function(t){this.normalizeToPointerData(t),this.pointer.originalEvent=t,this.eventData.data=this.pointer,this.eventData._reset(),this.mapPositionToPoint(this.pointer.global,t.clientX,t.clientY),this.autoPreventDefault&&(this.normalizeMouseEvents||this.normalizeTouchEvents)&&this.pointer.originalEvent.preventDefault(),this.processInteractive(this.pointer.global,this.renderer._lastObjectRendered,this.processPointerDown,!0),this.emit("pointerdown",this.eventData)},e.prototype.processPointerDown=function(t,e){e&&(t._pointerDown=!0,this.dispatchEvent(t,"pointerdown",this.eventData))},e.prototype.onPointerUp=function(t){this.normalizeToPointerData(t),this.pointer.originalEvent=t,this.eventData.data=this.pointer,this.eventData._reset(),this.mapPositionToPoint(this.pointer.global,t.clientX,t.clientY),this.processInteractive(this.pointer.global,this.renderer._lastObjectRendered,this.processPointerUp,!0),this.emit("pointerup",this.eventData)},e.prototype.processPointerUp=function(t,e){e?(this.dispatchEvent(t,"pointerup",this.eventData),t._pointerDown&&(t._pointerDown=!1,this.dispatchEvent(t,"pointertap",this.eventData))):t._pointerDown&&(t._pointerDown=!1,this.dispatchEvent(t,"pointerupoutside",this.eventData))},e.prototype.onPointerMove=function(t){this.normalizeToPointerData(t),this.pointer.originalEvent=t,this.eventData.data=this.pointer,this.eventData._reset(),this.mapPositionToPoint(this.pointer.global,t.clientX,t.clientY),this.processInteractive(this.pointer.global,this.renderer._lastObjectRendered,this.processPointerMove,!0),this.emit("pointermove",this.eventData)},e.prototype.processPointerMove=function(t,e){this.pointer.originalEvent.changedTouches||this.processPointerOverOut(t,e),this.moveWhenInside&&!e||this.dispatchEvent(t,"pointermove",this.eventData)},e.prototype.onPointerOut=function(t){this.normalizeToPointerData(t),this.pointer.originalEvent=t,this.eventData.data=this.pointer,this.eventData._reset(),this.mapPositionToPoint(this.pointer.global,t.clientX,t.clientY),this.processInteractive(this.pointer.global,this.renderer._lastObjectRendered,this.processPointerOverOut,!1),this.emit("pointerout",this.eventData)},e.prototype.processPointerOverOut=function(t,e){e&&this.mouseOverRenderer?t._pointerOver||(t._pointerOver=!0,this.dispatchEvent(t,"pointerover",this.eventData)):t._pointerOver&&(t._pointerOver=!1,this.dispatchEvent(t,"pointerout",this.eventData))},e.prototype.onPointerOver=function(t){this.pointer.originalEvent=t,this.eventData.data=this.pointer,this.eventData._reset(),this.emit("pointerover",this.eventData)},e.prototype.onTouchStart=function(t){this.autoPreventDefault&&t.preventDefault();for(var e=t.changedTouches,r=e.length,n=0;n<r;n++){var i=e[n],o=this.getTouchData(i);o.originalEvent=t,this.eventData.data=o,this.eventData._reset(),this.processInteractive(o.global,this.renderer._lastObjectRendered,this.processTouchStart,!0),this.emit("touchstart",this.eventData),this.returnTouchData(o)}},e.prototype.processTouchStart=function(t,e){e&&(t._touchDown=!0,this.dispatchEvent(t,"touchstart",this.eventData))},e.prototype.onTouchEnd=function(t){this.autoPreventDefault&&t.preventDefault();for(var e=t.changedTouches,r=e.length,n=0;n<r;n++){var i=e[n],o=this.getTouchData(i);o.originalEvent=t,this.eventData.data=o,this.eventData._reset(),this.processInteractive(o.global,this.renderer._lastObjectRendered,this.processTouchEnd,!0),this.emit("touchend",this.eventData),this.returnTouchData(o)}},e.prototype.processTouchEnd=function(t,e){e?(this.dispatchEvent(t,"touchend",this.eventData),t._touchDown&&(t._touchDown=!1,this.dispatchEvent(t,"tap",this.eventData))):t._touchDown&&(t._touchDown=!1,this.dispatchEvent(t,"touchendoutside",this.eventData))},e.prototype.onTouchMove=function(t){this.autoPreventDefault&&t.preventDefault();for(var e=t.changedTouches,r=e.length,n=0;n<r;n++){var i=e[n],o=this.getTouchData(i);o.originalEvent=t,this.eventData.data=o,this.eventData._reset(),this.processInteractive(o.global,this.renderer._lastObjectRendered,this.processTouchMove,this.moveWhenInside),this.emit("touchmove",this.eventData),this.returnTouchData(o)}},e.prototype.processTouchMove=function(t,e){this.moveWhenInside&&!e||this.dispatchEvent(t,"touchmove",this.eventData)},e.prototype.getTouchData=function(t){var e=this.interactiveDataPool.pop()||new c.default;return e.identifier=t.identifier,this.mapPositionToPoint(e.global,t.clientX,t.clientY),navigator.isCocoonJS&&(e.global.x=e.global.x/this.resolution,e.global.y=e.global.y/this.resolution),t.globalX=e.global.x,t.globalY=e.global.y,e},e.prototype.returnTouchData=function(t){this.interactiveDataPool.push(t)},e.prototype.normalizeToPointerData=function(t){this.normalizeTouchEvents&&t.changedTouches?("undefined"==typeof t.button&&(t.button=t.touches.length?1:0),"undefined"==typeof t.buttons&&(t.buttons=t.touches.length?1:0),"undefined"==typeof t.isPrimary&&(t.isPrimary=1===t.touches.length),"undefined"==typeof t.width&&(t.width=t.changedTouches[0].radiusX||1),"undefined"==typeof t.height&&(t.height=t.changedTouches[0].radiusY||1),"undefined"==typeof t.tiltX&&(t.tiltX=0),"undefined"==typeof t.tiltY&&(t.tiltY=0),"undefined"==typeof t.pointerType&&(t.pointerType="touch"),"undefined"==typeof t.pointerId&&(t.pointerId=t.changedTouches[0].identifier||0),"undefined"==typeof t.pressure&&(t.pressure=t.changedTouches[0].force||.5),"undefined"==typeof t.rotation&&(t.rotation=t.changedTouches[0].rotationAngle||0),"undefined"==typeof t.clientX&&(t.clientX=t.changedTouches[0].clientX),"undefined"==typeof t.clientY&&(t.clientY=t.changedTouches[0].clientY),"undefined"==typeof t.pageX&&(t.pageX=t.changedTouches[0].pageX),"undefined"==typeof t.pageY&&(t.pageY=t.changedTouches[0].pageY),"undefined"==typeof t.screenX&&(t.screenX=t.changedTouches[0].screenX),"undefined"==typeof t.screenY&&(t.screenY=t.changedTouches[0].screenY),"undefined"==typeof t.layerX&&(t.layerX=t.offsetX=t.clientX),"undefined"==typeof t.layerY&&(t.layerY=t.offsetY=t.clientY)):this.normalizeMouseEvents&&("undefined"==typeof t.isPrimary&&(t.isPrimary=!0),"undefined"==typeof t.width&&(t.width=1),"undefined"==typeof t.height&&(t.height=1),"undefined"==typeof t.tiltX&&(t.tiltX=0),"undefined"==typeof t.tiltY&&(t.tiltY=0),"undefined"==typeof t.pointerType&&(t.pointerType="mouse"),"undefined"==typeof t.pointerId&&(t.pointerId=1),"undefined"==typeof t.pressure&&(t.pressure=.5),"undefined"==typeof t.rotation&&(t.rotation=0))},e.prototype.destroy=function(){this.removeEvents(),this.removeAllListeners(),this.renderer=null,this.mouse=null,this.eventData=null,this.interactiveDataPool=null,this.interactionDOMElement=null,this.onMouseDown=null,this.processMouseDown=null,this.onMouseUp=null,this.processMouseUp=null,this.onMouseMove=null,this.processMouseMove=null,this.onMouseOut=null,this.processMouseOverOut=null,this.onMouseOver=null,this.onPointerDown=null,this.processPointerDown=null,this.onPointerUp=null,this.processPointerUp=null,this.onPointerMove=null,this.processPointerMove=null,this.onPointerOut=null,this.processPointerOverOut=null,this.onPointerOver=null,this.onTouchStart=null,this.processTouchStart=null,this.onTouchEnd=null,this.processTouchEnd=null,this.onTouchMove=null,this.processTouchMove=null,this._tempPoint=null},e}(v.default);r.default=b,h.WebGLRenderer.registerPlugin("interaction",b),h.CanvasRenderer.registerPlugin("interaction",b)},{"../core":61,"./InteractionData":145,"./InteractionEvent":146,"./interactiveTarget":149,eventemitter3:3,ismobilejs:4}],148:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}r.__esModule=!0;var i=t("./InteractionData");Object.defineProperty(r,"InteractionData",{enumerable:!0,get:function(){return n(i).default}});var o=t("./InteractionManager");Object.defineProperty(r,"InteractionManager",{enumerable:!0,get:function(){return n(o).default}});var s=t("./interactiveTarget");Object.defineProperty(r,"interactiveTarget",{enumerable:!0,get:function(){return n(s).default}})},{"./InteractionData":145,"./InteractionManager":147,"./interactiveTarget":149}],149:[function(t,e,r){"use strict";r.__esModule=!0,r.default={interactive:!1,interactiveChildren:!0,hitArea:null,buttonMode:!1,defaultCursor:"pointer",_over:!1,_isLeftDown:!1,_isRightDown:!1,_pointerOver:!1,_pointerDown:!1,_touchDown:!1}},{}],150:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t,e){var r={},n=t.data.getElementsByTagName("info")[0],i=t.data.getElementsByTagName("common")[0];r.font=n.getAttribute("face"),r.size=parseInt(n.getAttribute("size"),10),r.lineHeight=parseInt(i.getAttribute("lineHeight"),10),r.chars={};for(var o=t.data.getElementsByTagName("char"),s=0;s<o.length;s++){var u=parseInt(o[s].getAttribute("id"),10),l=new a.Rectangle(parseInt(o[s].getAttribute("x"),10)+e.frame.x,parseInt(o[s].getAttribute("y"),10)+e.frame.y,parseInt(o[s].getAttribute("width"),10),parseInt(o[s].getAttribute("height"),10));r.chars[u]={xOffset:parseInt(o[s].getAttribute("xoffset"),10),yOffset:parseInt(o[s].getAttribute("yoffset"),10),xAdvance:parseInt(o[s].getAttribute("xadvance"),10),kerning:{},texture:new a.Texture(e.baseTexture,l)}}for(var c=t.data.getElementsByTagName("kerning"),d=0;d<c.length;d++){var f=parseInt(c[d].getAttribute("first"),10),p=parseInt(c[d].getAttribute("second"),10),v=parseInt(c[d].getAttribute("amount"),10);r.chars[p]&&(r.chars[p].kerning[f]=v)}t.bitmapFont=r,h.BitmapText.fonts[r.font]=r}r.__esModule=!0,r.parse=i,r.default=function(){return function(t,e){if(!t.data||!t.isXml)return void e();if(0===t.data.getElementsByTagName("page").length||0===t.data.getElementsByTagName("info").length||null===t.data.getElementsByTagName("info")[0].getAttribute("face"))return void e();var r=t.isDataUrl?"":s.dirname(t.url);t.isDataUrl&&("."===r&&(r=""),this.baseUrl&&r&&("/"===this.baseUrl.charAt(this.baseUrl.length-1)&&(r+="/"),r=r.replace(this.baseUrl,""))),r&&"/"!==r.charAt(r.length-1)&&(r+="/");var n=r+t.data.getElementsByTagName("page")[0].getAttribute("file");if(a.utils.TextureCache[n])i(t,a.utils.TextureCache[n]),e();else{var o={crossOrigin:t.crossOrigin,loadType:u.Resource.LOAD_TYPE.IMAGE,metadata:t.metadata.imageMetadata};this.add(t.name+"_image",n,o,function(r){i(t,r.texture),e()})}}};var o=t("path"),s=n(o),a=t("../core"),u=t("resource-loader"),h=t("../extras")},{"../core":61,"../extras":131,path:22,"resource-loader":35}],151:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}r.__esModule=!0;var i=t("./loader");Object.defineProperty(r,"Loader",{enumerable:!0,get:function(){return n(i).default}});var o=t("./bitmapFontParser");Object.defineProperty(r,"bitmapFontParser",{enumerable:!0,get:function(){return n(o).default}}),Object.defineProperty(r,"parseBitmapFontData",{enumerable:!0,get:function(){return o.parse}});var s=t("./spritesheetParser");Object.defineProperty(r,"spritesheetParser",{enumerable:!0,get:function(){return n(s).default}});var a=t("./textureParser");Object.defineProperty(r,"textureParser",{enumerable:!0,get:function(){return n(a).default}});var u=t("resource-loader");Object.defineProperty(r,"Resource",{enumerable:!0,get:function(){return u.Resource}})},{"./bitmapFontParser":150,"./loader":152,"./spritesheetParser":153,"./textureParser":154,"resource-loader":35}],152:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("resource-loader"),u=n(a),h=t("./textureParser"),l=n(h),c=t("./spritesheetParser"),d=n(c),f=t("./bitmapFontParser"),p=n(f),v=function(t){function e(r,n){i(this,e);for(var s=o(this,t.call(this,r,n)),a=0;a<e._pixiMiddleware.length;++a)s.use(e._pixiMiddleware[a]());return s}return s(e,t),e.addPixiMiddleware=function(t){e._pixiMiddleware.push(t)},e}(u.default);r.default=v,v._pixiMiddleware=[u.default.middleware.parsing.blob,l.default,d.default,p.default];var y=u.default.Resource;y.setExtensionXhrType("fnt",y.XHR_RESPONSE_TYPE.DOCUMENT)},{"./bitmapFontParser":150,"./spritesheetParser":153,"./textureParser":154,"resource-loader":35}],153:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t){return t&&t.__esModule?t:{default:t}}r.__esModule=!0,r.default=function(){return function(t,e){var r=void 0,n=t.name+"_image";if(!t.data||!t.isJson||!t.data.frames||this.resources[n])return void e();var i={crossOrigin:t.crossOrigin,loadType:o.Resource.LOAD_TYPE.IMAGE,metadata:t.metadata.imageMetadata};r=t.isDataUrl?t.data.meta.image:a.default.dirname(t.url.replace(this.baseUrl,""))+"/"+t.data.meta.image,this.add(n,r,i,function(r){function n(e,r){for(var n=e;n-e<r&&n<u.length;){var i=u[n],o=a[i].frame;if(o){var s=null,l=null,f=new h.Rectangle(0,0,a[i].sourceSize.w/d,a[i].sourceSize.h/d);s=a[i].rotated?new h.Rectangle(o.x/d,o.y/d,o.h/d,o.w/d):new h.Rectangle(o.x/d,o.y/d,o.w/d,o.h/d),a[i].trimmed&&(l=new h.Rectangle(a[i].spriteSourceSize.x/d,a[i].spriteSourceSize.y/d,o.w/d,o.h/d)),t.textures[i]=new h.Texture(c,s,f,l,a[i].rotated?2:0),h.utils.TextureCache[i]=t.textures[i]}n++}}function i(){return p*l<u.length}function o(t){n(p*l,l),p++,setTimeout(t,0)}function s(){o(function(){i()?s():e()})}t.textures={};var a=t.data.frames,u=Object.keys(a),c=r.texture.baseTexture,d=h.utils.getResolutionOfUrl(t.url),f=t.data.meta.scale;1===d&&void 0!==f&&1!==f&&(c.resolution=d=f,c.update());var p=0;u.length<=l?(n(0,l),e()):s()})}};var o=t("resource-loader"),s=t("path"),a=i(s),u=t("../core"),h=n(u),l=1e3},{"../core":61,path:22,"resource-loader":35}],154:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}r.__esModule=!0,r.default=function(){return function(t,e){if(t.data&&t.isImage){var r=new o.BaseTexture(t.data,null,o.utils.getResolutionOfUrl(t.url));r.imageUrl=t.url,t.texture=new o.Texture(r),o.utils.BaseTextureCache[t.name]=r,o.utils.TextureCache[t.name]=t.texture,t.name!==t.url&&(o.utils.BaseTextureCache[t.url]=r,o.utils.TextureCache[t.url]=t.texture)}e()}};var i=t("../core"),o=n(i)},{"../core":61}],155:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),u=t("../core"),h=n(u),l=new h.Point,c=new h.Polygon,d=function(t){function e(r,n,s,a,u){i(this,e);var l=o(this,t.call(this));return l._texture=null,l.uvs=s||new Float32Array([0,0,1,0,1,1,0,1]),l.vertices=n||new Float32Array([0,0,100,0,100,100,0,100]),l.indices=a||new Uint16Array([0,1,3,2]),l.dirty=0,l.indexDirty=0,l.blendMode=h.BLEND_MODES.NORMAL,l.canvasPadding=0,l.drawMode=u||e.DRAW_MODES.TRIANGLE_MESH,l.texture=r,l.shader=null,l.tintRgb=new Float32Array([1,1,1]),l._glDatas={},l}return s(e,t),e.prototype._renderWebGL=function(t){t.setObjectRenderer(t.plugins.mesh),t.plugins.mesh.render(this)},e.prototype._renderCanvas=function(t){t.plugins.mesh.render(this)},e.prototype._onTextureUpdate=function(){},e.prototype._calculateBounds=function(){this._bounds.addVertices(this.transform,this.vertices,0,this.vertices.length)},e.prototype.containsPoint=function(t){if(!this.getBounds().contains(t.x,t.y))return!1;this.worldTransform.applyInverse(t,l);for(var r=this.vertices,n=c.points,i=this.indices,o=this.indices.length,s=this.drawMode===e.DRAW_MODES.TRIANGLES?3:1,a=0;a+2<o;a+=s){var u=2*i[a],h=2*i[a+1],d=2*i[a+2];if(n[0]=r[u],n[1]=r[u+1],n[2]=r[h],n[3]=r[h+1],n[4]=r[d],n[5]=r[d+1],c.contains(l.x,l.y))return!0}return!1},a(e,[{key:"texture",get:function(){return this._texture},set:function(t){this._texture!==t&&(this._texture=t,t&&(t.baseTexture.hasLoaded?this._onTextureUpdate():t.once("update",this._onTextureUpdate,this)))}},{key:"tint",get:function(){return h.utils.rgb2hex(this.tintRgb)},set:function(t){this.tintRgb=h.utils.hex2rgb(t,this.tintRgb)}}]),e}(h.Container);r.default=d,d.DRAW_MODES={TRIANGLE_MESH:0,TRIANGLES:1}},{"../core":61}],156:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=function(){function t(t,e){for(var r=0;r<e.length;r++){var n=e[r];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(t,n.key,n)}}return function(e,r,n){return r&&t(e.prototype,r),n&&t(e,n),e}}(),u=t("./Plane"),h=n(u),l=10,c=function(t){function e(r,n,s,a,u){i(this,e);var h=o(this,t.call(this,r,4,4)),c=h.uvs;return c[6]=c[14]=c[22]=c[30]=1,c[25]=c[27]=c[29]=c[31]=1,h._origWidth=r.width,h._origHeight=r.height,h._uvw=1/h._origWidth,h._uvh=1/h._origHeight,h.width=r.width,h.height=r.height,c[2]=c[10]=c[18]=c[26]=h._uvw*n,c[4]=c[12]=c[20]=c[28]=1-h._uvw*a,c[9]=c[11]=c[13]=c[15]=h._uvh*s,c[17]=c[19]=c[21]=c[23]=1-h._uvh*u,h.leftWidth="undefined"!=typeof n?n:l,h.rightWidth="undefined"!=typeof a?a:l,h.topHeight="undefined"!=typeof s?s:l,h.bottomHeight="undefined"!=typeof u?u:l,h}return s(e,t),
e.prototype.updateHorizontalVertices=function(){var t=this.vertices;t[9]=t[11]=t[13]=t[15]=this._topHeight,t[17]=t[19]=t[21]=t[23]=this._height-this._bottomHeight,t[25]=t[27]=t[29]=t[31]=this._height},e.prototype.updateVerticalVertices=function(){var t=this.vertices;t[2]=t[10]=t[18]=t[26]=this._leftWidth,t[4]=t[12]=t[20]=t[28]=this._width-this._rightWidth,t[6]=t[14]=t[22]=t[30]=this._width},e.prototype._renderCanvas=function(t){var e=t.context;e.globalAlpha=this.worldAlpha;var r=this.worldTransform,n=t.resolution;t.roundPixels?e.setTransform(r.a*n,r.b*n,r.c*n,r.d*n,r.tx*n|0,r.ty*n|0):e.setTransform(r.a*n,r.b*n,r.c*n,r.d*n,r.tx*n,r.ty*n);var i=this._texture.baseTexture,o=i.source,s=i.width,a=i.height;this.drawSegment(e,o,s,a,0,1,10,11),this.drawSegment(e,o,s,a,2,3,12,13),this.drawSegment(e,o,s,a,4,5,14,15),this.drawSegment(e,o,s,a,8,9,18,19),this.drawSegment(e,o,s,a,10,11,20,21),this.drawSegment(e,o,s,a,12,13,22,23),this.drawSegment(e,o,s,a,16,17,26,27),this.drawSegment(e,o,s,a,18,19,28,29),this.drawSegment(e,o,s,a,20,21,30,31)},e.prototype.drawSegment=function(t,e,r,n,i,o,s,a){var u=this.uvs,h=this.vertices,l=(u[s]-u[i])*r,c=(u[a]-u[o])*n,d=h[s]-h[i],f=h[a]-h[o];l<1&&(l=1),c<1&&(c=1),d<1&&(d=1),f<1&&(f=1),t.drawImage(e,u[i]*r,u[o]*n,l,c,h[i],h[o],d,f)},a(e,[{key:"width",get:function(){return this._width},set:function(t){this._width=t,this.updateVerticalVertices()}},{key:"height",get:function(){return this._height},set:function(t){this._height=t,this.updateHorizontalVertices()}},{key:"leftWidth",get:function(){return this._leftWidth},set:function(t){this._leftWidth=t;var e=this.uvs,r=this.vertices;e[2]=e[10]=e[18]=e[26]=this._uvw*t,r[2]=r[10]=r[18]=r[26]=t,this.dirty=!0}},{key:"rightWidth",get:function(){return this._rightWidth},set:function(t){this._rightWidth=t;var e=this.uvs,r=this.vertices;e[4]=e[12]=e[20]=e[28]=1-this._uvw*t,r[4]=r[12]=r[20]=r[28]=this._width-t,this.dirty=!0}},{key:"topHeight",get:function(){return this._topHeight},set:function(t){this._topHeight=t;var e=this.uvs,r=this.vertices;e[9]=e[11]=e[13]=e[15]=this._uvh*t,r[9]=r[11]=r[13]=r[15]=t,this.dirty=!0}},{key:"bottomHeight",get:function(){return this._bottomHeight},set:function(t){this._bottomHeight=t;var e=this.uvs,r=this.vertices;e[17]=e[19]=e[21]=e[23]=1-this._uvh*t,r[17]=r[19]=r[21]=r[23]=this._height-t,this.dirty=!0}}]),e}(h.default);r.default=c},{"./Plane":157}],157:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("./Mesh"),u=n(a),h=function(t){function e(r,n,s){i(this,e);var a=o(this,t.call(this,r));return a._ready=!0,a.verticesX=n||10,a.verticesY=s||10,a.drawMode=u.default.DRAW_MODES.TRIANGLES,a.refresh(),a}return s(e,t),e.prototype.refresh=function(){for(var t=this.verticesX*this.verticesY,e=[],r=[],n=[],i=[],o=this.texture,s=this.verticesX-1,a=this.verticesY-1,u=o.width/s,h=o.height/a,l=0;l<t;l++)if(o._uvs){var c=l%this.verticesX,d=l/this.verticesX|0;e.push(c*u,d*h),n.push(o._uvs.x0+(o._uvs.x1-o._uvs.x0)*(c/(this.verticesX-1)),o._uvs.y0+(o._uvs.y3-o._uvs.y0)*(d/(this.verticesY-1)))}else n.push(0);for(var f=s*a,p=0;p<f;p++){var v=p%s,y=p/s|0,g=y*this.verticesX+v,m=y*this.verticesX+v+1,_=(y+1)*this.verticesX+v,b=(y+1)*this.verticesX+v+1;i.push(g,m,_),i.push(m,b,_)}this.vertices=new Float32Array(e),this.uvs=new Float32Array(n),this.colors=new Float32Array(r),this.indices=new Uint16Array(i),this.indexDirty=!0},e.prototype._onTextureUpdate=function(){u.default.prototype._onTextureUpdate.call(this),this._ready&&this.refresh()},e}(u.default);r.default=h},{"./Mesh":155}],158:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t){return t&&t.__esModule?t:{default:t}}function o(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function s(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function a(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var u=t("./Mesh"),h=i(u),l=t("../core"),c=n(l),d=function(t){function e(r,n){o(this,e);var i=s(this,t.call(this,r));return i.points=n,i.vertices=new Float32Array(4*n.length),i.uvs=new Float32Array(4*n.length),i.colors=new Float32Array(2*n.length),i.indices=new Uint16Array(2*n.length),i._ready=!0,i.refresh(),i}return a(e,t),e.prototype.refresh=function(){var t=this.points;if(!(t.length<1)&&this._texture._uvs){this.vertices.length/4!==t.length&&(this.vertices=new Float32Array(4*t.length),this.uvs=new Float32Array(4*t.length),this.colors=new Float32Array(2*t.length),this.indices=new Uint16Array(2*t.length));var e=this.uvs,r=this.indices,n=this.colors,i=this._texture._uvs,o=new c.Point(i.x0,i.y0),s=new c.Point(i.x2-i.x0,i.y2-i.y0);e[0]=0+o.x,e[1]=0+o.y,e[2]=0+o.x,e[3]=Number(s.y)+o.y,n[0]=1,n[1]=1,r[0]=0,r[1]=1;for(var a=t.length,u=1;u<a;u++){var h=4*u,l=u/(a-1);e[h]=l*s.x+o.x,e[h+1]=0+o.y,e[h+2]=l*s.x+o.x,e[h+3]=Number(s.y)+o.y,h=2*u,n[h]=1,n[h+1]=1,h=2*u,r[h]=h,r[h+1]=h+1}this.dirty++,this.indexDirty++}},e.prototype._onTextureUpdate=function(){t.prototype._onTextureUpdate.call(this),this._ready&&this.refresh()},e.prototype.updateTransform=function(){var t=this.points;if(!(t.length<1)){for(var e=t[0],r=void 0,n=0,i=0,o=this.vertices,s=t.length,a=0;a<s;a++){var u=t[a],h=4*a;r=a<t.length-1?t[a+1]:u,i=-(r.x-e.x),n=r.y-e.y;var l=10*(1-a/(s-1));l>1&&(l=1);var c=Math.sqrt(n*n+i*i),d=this._texture.height/2;n/=c,i/=c,n*=d,i*=d,o[h]=u.x+n,o[h+1]=u.y+i,o[h+2]=u.x-n,o[h+3]=u.y-i,e=u}this.containerUpdateTransform()}},e}(h.default);r.default=d},{"../core":61,"./Mesh":155}],159:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function o(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var s=t("../../core"),a=i(s),u=t("../Mesh"),h=n(u),l=function(){function t(e){o(this,t),this.renderer=e}return t.prototype.render=function(t){var e=this.renderer,r=e.context,n=t.worldTransform,i=e.resolution;e.roundPixels?r.setTransform(n.a*i,n.b*i,n.c*i,n.d*i,n.tx*i|0,n.ty*i|0):r.setTransform(n.a*i,n.b*i,n.c*i,n.d*i,n.tx*i,n.ty*i),e.setBlendMode(t.blendMode),t.drawMode===h.default.DRAW_MODES.TRIANGLE_MESH?this._renderTriangleMesh(t):this._renderTriangles(t)},t.prototype._renderTriangleMesh=function(t){for(var e=t.vertices.length/2,r=0;r<e-2;r++){var n=2*r;this._renderDrawTriangle(t,n,n+2,n+4)}},t.prototype._renderTriangles=function(t){for(var e=t.indices,r=e.length,n=0;n<r;n+=3){var i=2*e[n],o=2*e[n+1],s=2*e[n+2];this._renderDrawTriangle(t,i,o,s)}},t.prototype._renderDrawTriangle=function(t,e,r,n){var i=this.renderer.context,o=t.uvs,s=t.vertices,a=t._texture;if(a.valid){var u=a.baseTexture,h=u.source,l=u.width,c=u.height,d=o[e]*u.width,f=o[r]*u.width,p=o[n]*u.width,v=o[e+1]*u.height,y=o[r+1]*u.height,g=o[n+1]*u.height,m=s[e],_=s[r],b=s[n],x=s[e+1],T=s[r+1],w=s[n+1];if(t.canvasPadding>0){var E=t.canvasPadding/t.worldTransform.a,O=t.canvasPadding/t.worldTransform.d,S=(m+_+b)/3,M=(x+T+w)/3,P=m-S,C=x-M,R=Math.sqrt(P*P+C*C);m=S+P/R*(R+E),x=M+C/R*(R+O),P=_-S,C=T-M,R=Math.sqrt(P*P+C*C),_=S+P/R*(R+E),T=M+C/R*(R+O),P=b-S,C=w-M,R=Math.sqrt(P*P+C*C),b=S+P/R*(R+E),w=M+C/R*(R+O)}i.save(),i.beginPath(),i.moveTo(m,x),i.lineTo(_,T),i.lineTo(b,w),i.closePath(),i.clip();var D=d*y+v*p+f*g-y*p-v*f-d*g,A=m*y+v*b+_*g-y*b-v*_-m*g,I=d*_+m*p+f*b-_*p-m*f-d*b,L=d*y*b+v*_*p+m*f*g-m*y*p-v*f*b-d*_*g,j=x*y+v*w+T*g-y*w-v*T-x*g,B=d*T+x*p+f*w-T*p-x*f-d*w,F=d*y*w+v*T*p+x*f*g-x*y*p-v*f*w-d*T*g;i.transform(A/D,j/D,I/D,B/D,L/D,F/D),i.drawImage(h,0,0,l*u.resolution,c*u.resolution,0,0,l,c),i.restore()}},t.prototype.renderMeshFlat=function(t){var e=this.renderer.context,r=t.vertices,n=r.length/2;e.beginPath();for(var i=1;i<n-2;++i){var o=2*i,s=r[o],a=r[o+1],u=r[o+2],h=r[o+3],l=r[o+4],c=r[o+5];e.moveTo(s,a),e.lineTo(u,h),e.lineTo(l,c)}e.fillStyle="#FF0000",e.fill(),e.closePath()},t.prototype.destroy=function(){this.renderer=null},t}();r.default=l,a.CanvasRenderer.registerPlugin("mesh",l)},{"../../core":61,"../Mesh":155}],160:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}r.__esModule=!0;var i=t("./Mesh");Object.defineProperty(r,"Mesh",{enumerable:!0,get:function(){return n(i).default}});var o=t("./webgl/MeshRenderer");Object.defineProperty(r,"MeshRenderer",{enumerable:!0,get:function(){return n(o).default}});var s=t("./canvas/CanvasMeshRenderer");Object.defineProperty(r,"CanvasMeshRenderer",{enumerable:!0,get:function(){return n(s).default}});var a=t("./Plane");Object.defineProperty(r,"Plane",{enumerable:!0,get:function(){return n(a).default}});var u=t("./NineSlicePlane");Object.defineProperty(r,"NineSlicePlane",{enumerable:!0,get:function(){return n(u).default}});var h=t("./Rope");Object.defineProperty(r,"Rope",{enumerable:!0,get:function(){return n(h).default}})},{"./Mesh":155,"./NineSlicePlane":156,"./Plane":157,"./Rope":158,"./canvas/CanvasMeshRenderer":159,"./webgl/MeshRenderer":161}],161:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function o(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function s(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function a(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var u=t("../../core"),h=i(u),l=t("pixi-gl-core"),c=n(l),d=t("../Mesh"),f=n(d),p=(t("path"),function(t){function e(r){o(this,e);var n=s(this,t.call(this,r));return n.shader=null,n}return a(e,t),e.prototype.onContextChange=function(){var t=this.renderer.gl;this.shader=new h.Shader(t,"attribute vec2 aVertexPosition;\nattribute vec2 aTextureCoord;\n\nuniform mat3 translationMatrix;\nuniform mat3 projectionMatrix;\n\nvarying vec2 vTextureCoord;\n\nvoid main(void)\n{\n    gl_Position = vec4((projectionMatrix * translationMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);\n\n    vTextureCoord = aTextureCoord;\n}\n","varying vec2 vTextureCoord;\nuniform float alpha;\nuniform vec3 tint;\n\nuniform sampler2D uSampler;\n\nvoid main(void)\n{\n    gl_FragColor = texture2D(uSampler, vTextureCoord) * vec4(tint * alpha, alpha);\n}\n")},e.prototype.render=function(t){var e=this.renderer,r=e.gl,n=t._texture;if(n.valid){var i=t._glDatas[e.CONTEXT_UID];i||(e.bindVao(null),i={shader:this.shader,vertexBuffer:c.default.GLBuffer.createVertexBuffer(r,t.vertices,r.STREAM_DRAW),uvBuffer:c.default.GLBuffer.createVertexBuffer(r,t.uvs,r.STREAM_DRAW),indexBuffer:c.default.GLBuffer.createIndexBuffer(r,t.indices,r.STATIC_DRAW),vao:null,dirty:t.dirty,indexDirty:t.indexDirty},i.vao=new c.default.VertexArrayObject(r).addIndex(i.indexBuffer).addAttribute(i.vertexBuffer,i.shader.attributes.aVertexPosition,r.FLOAT,!1,8,0).addAttribute(i.uvBuffer,i.shader.attributes.aTextureCoord,r.FLOAT,!1,8,0),t._glDatas[e.CONTEXT_UID]=i),t.dirty!==i.dirty&&(i.dirty=t.dirty,i.uvBuffer.upload(t.uvs)),t.indexDirty!==i.indexDirty&&(i.indexDirty=t.indexDirty,i.indexBuffer.upload(t.indices)),i.vertexBuffer.upload(t.vertices),e.bindShader(i.shader),i.shader.uniforms.uSampler=e.bindTexture(n),e.state.setBlendMode(t.blendMode),i.shader.uniforms.translationMatrix=t.worldTransform.toArray(!0),i.shader.uniforms.alpha=t.worldAlpha,i.shader.uniforms.tint=t.tintRgb;var o=t.drawMode===f.default.DRAW_MODES.TRIANGLE_MESH?r.TRIANGLE_STRIP:r.TRIANGLES;e.bindVao(i.vao),i.vao.draw(o,t.indices.length,0)}},e}(h.ObjectRenderer));r.default=p,h.WebGLRenderer.registerPlugin("mesh",p)},{"../../core":61,"../Mesh":155,path:22,"pixi-gl-core":12}],162:[function(t,e,r){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("../core"),u=n(a),h=function(t){function e(){var r=arguments.length<=0||void 0===arguments[0]?1500:arguments[0],n=arguments[1],s=arguments.length<=2||void 0===arguments[2]?16384:arguments[2];i(this,e);var a=o(this,t.call(this)),h=16384;return s>h&&(s=h),s>r&&(s=r),a._properties=[!1,!0,!1,!1,!1],a._maxSize=r,a._batchSize=s,a._glBuffers={},a._bufferToUpdate=0,a.interactiveChildren=!1,a.blendMode=u.BLEND_MODES.NORMAL,a.roundPixels=!0,a.baseTexture=null,a.setProperties(n),a}return s(e,t),e.prototype.setProperties=function(t){t&&(this._properties[0]="scale"in t?!!t.scale:this._properties[0],this._properties[1]="position"in t?!!t.position:this._properties[1],this._properties[2]="rotation"in t?!!t.rotation:this._properties[2],this._properties[3]="uvs"in t?!!t.uvs:this._properties[3],this._properties[4]="alpha"in t?!!t.alpha:this._properties[4])},e.prototype.updateTransform=function(){this.displayObjectUpdateTransform()},e.prototype.renderWebGL=function(t){var e=this;this.visible&&!(this.worldAlpha<=0)&&this.children.length&&this.renderable&&(this.baseTexture||(this.baseTexture=this.children[0]._texture.baseTexture,this.baseTexture.hasLoaded||this.baseTexture.once("update",function(){return e.onChildrenChange(0)})),t.setObjectRenderer(t.plugins.particle),t.plugins.particle.render(this))},e.prototype.onChildrenChange=function(t){var e=Math.floor(t/this._batchSize);e<this._bufferToUpdate&&(this._bufferToUpdate=e)},e.prototype.renderCanvas=function(t){if(this.visible&&!(this.worldAlpha<=0)&&this.children.length&&this.renderable){var e=t.context,r=this.worldTransform,n=!0,i=0,o=0,s=0,a=0,u=t.blendModes[this.blendMode];u!==e.globalCompositeOperation&&(e.globalCompositeOperation=u),e.globalAlpha=this.worldAlpha,this.displayObjectUpdateTransform();for(var h=0;h<this.children.length;++h){var l=this.children[h];if(l.visible){var c=l.texture.frame;if(e.globalAlpha=this.worldAlpha*l.alpha,l.rotation%(2*Math.PI)===0)n&&(e.setTransform(r.a,r.b,r.c,r.d,r.tx*t.resolution,r.ty*t.resolution),n=!1),i=l.anchor.x*(-c.width*l.scale.x)+l.position.x+.5,o=l.anchor.y*(-c.height*l.scale.y)+l.position.y+.5,s=c.width*l.scale.x,a=c.height*l.scale.y;else{n||(n=!0),l.displayObjectUpdateTransform();var d=l.worldTransform;t.roundPixels?e.setTransform(d.a,d.b,d.c,d.d,d.tx*t.resolution|0,d.ty*t.resolution|0):e.setTransform(d.a,d.b,d.c,d.d,d.tx*t.resolution,d.ty*t.resolution),i=l.anchor.x*-c.width+.5,o=l.anchor.y*-c.height+.5,s=c.width,a=c.height}var f=l.texture.baseTexture.resolution;e.drawImage(l.texture.baseTexture.source,c.x*f,c.y*f,c.width*f,c.height*f,i*f,o*f,s*f,a*f)}}}},e.prototype.destroy=function(e){if(t.prototype.destroy.call(this,e),this._buffers)for(var r=0;r<this._buffers.length;++r)this._buffers[r].destroy();this._properties=null,this._buffers=null},e}(u.Container);r.default=h},{"../core":61}],163:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}r.__esModule=!0;var i=t("./ParticleContainer");Object.defineProperty(r,"ParticleContainer",{enumerable:!0,get:function(){return n(i).default}});var o=t("./webgl/ParticleRenderer");Object.defineProperty(r,"ParticleRenderer",{enumerable:!0,get:function(){return n(o).default}})},{"./ParticleContainer":162,"./webgl/ParticleRenderer":165}],164:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var o=t("pixi-gl-core"),s=n(o),a=t("../../core/utils/createIndicesForQuads"),u=n(a),h=function(){function t(e,r,n,o){i(this,t),this.gl=e,this.vertSize=2,this.vertByteSize=4*this.vertSize,this.size=o,this.dynamicProperties=[],this.staticProperties=[];for(var s=0;s<r.length;++s){var a=r[s];a={attribute:a.attribute,size:a.size,uploadFunction:a.uploadFunction,offset:a.offset},n[s]?this.dynamicProperties.push(a):this.staticProperties.push(a)}this.staticStride=0,this.staticBuffer=null,this.staticData=null,this.dynamicStride=0,this.dynamicBuffer=null,this.dynamicData=null,this.initBuffers()}return t.prototype.initBuffers=function(){var t=this.gl,e=0;this.indices=(0,u.default)(this.size),this.indexBuffer=s.default.GLBuffer.createIndexBuffer(t,this.indices,t.STATIC_DRAW),this.dynamicStride=0;for(var r=0;r<this.dynamicProperties.length;++r){var n=this.dynamicProperties[r];n.offset=e,e+=n.size,this.dynamicStride+=n.size}this.dynamicData=new Float32Array(this.size*this.dynamicStride*4),this.dynamicBuffer=s.default.GLBuffer.createVertexBuffer(t,this.dynamicData,t.STREAM_DRAW);var i=0;this.staticStride=0;for(var o=0;o<this.staticProperties.length;++o){var a=this.staticProperties[o];a.offset=i,i+=a.size,this.staticStride+=a.size}this.staticData=new Float32Array(this.size*this.staticStride*4),this.staticBuffer=s.default.GLBuffer.createVertexBuffer(t,this.staticData,t.STATIC_DRAW),this.vao=new s.default.VertexArrayObject(t).addIndex(this.indexBuffer);for(var h=0;h<this.dynamicProperties.length;++h){var l=this.dynamicProperties[h];this.vao.addAttribute(this.dynamicBuffer,l.attribute,t.FLOAT,!1,4*this.dynamicStride,4*l.offset)}for(var c=0;c<this.staticProperties.length;++c){var d=this.staticProperties[c];this.vao.addAttribute(this.staticBuffer,d.attribute,t.FLOAT,!1,4*this.staticStride,4*d.offset)}},t.prototype.uploadDynamic=function(t,e,r){for(var n=0;n<this.dynamicProperties.length;n++){var i=this.dynamicProperties[n];i.uploadFunction(t,e,r,this.dynamicData,this.dynamicStride,i.offset)}this.dynamicBuffer.upload()},t.prototype.uploadStatic=function(t,e,r){for(var n=0;n<this.staticProperties.length;n++){var i=this.staticProperties[n];i.uploadFunction(t,e,r,this.staticData,this.staticStride,i.offset)}this.staticBuffer.upload()},t.prototype.destroy=function(){this.dynamicProperties=null,this.dynamicData=null,this.dynamicBuffer.destroy(),this.staticProperties=null,this.staticData=null,this.staticBuffer.destroy()},t}();r.default=h},{"../../core/utils/createIndicesForQuads":115,"pixi-gl-core":12}],165:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function o(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function s(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function a(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var u=t("../../core"),h=i(u),l=t("./ParticleShader"),c=n(l),d=t("./ParticleBuffer"),f=n(d),p=function(t){function e(r){o(this,e);var n=s(this,t.call(this,r));return n.shader=null,n.indexBuffer=null,n.properties=null,n.tempMatrix=new h.Matrix,n.CONTEXT_UID=0,n}return a(e,t),e.prototype.onContextChange=function(){var t=this.renderer.gl;this.CONTEXT_UID=this.renderer.CONTEXT_UID,this.shader=new c.default(t),this.properties=[{attribute:this.shader.attributes.aVertexPosition,size:2,uploadFunction:this.uploadVertices,offset:0},{attribute:this.shader.attributes.aPositionCoord,size:2,uploadFunction:this.uploadPosition,offset:0},{attribute:this.shader.attributes.aRotation,size:1,uploadFunction:this.uploadRotation,offset:0},{attribute:this.shader.attributes.aTextureCoord,size:2,uploadFunction:this.uploadUvs,offset:0},{attribute:this.shader.attributes.aColor,size:1,uploadFunction:this.uploadAlpha,offset:0}]},e.prototype.start=function(){this.renderer.bindShader(this.shader)},e.prototype.render=function(t){var e=t.children,r=t._maxSize,n=t._batchSize,i=this.renderer,o=e.length;if(0!==o){o>r&&(o=r);var s=t._glBuffers[i.CONTEXT_UID];s||(s=t._glBuffers[i.CONTEXT_UID]=this.generateBuffers(t)),this.renderer.setBlendMode(t.blendMode);var a=i.gl,u=t.worldTransform.copy(this.tempMatrix);u.prepend(i._activeRenderTarget.projectionMatrix),this.shader.uniforms.projectionMatrix=u.toArray(!0),this.shader.uniforms.uAlpha=t.worldAlpha;var h=e[0]._texture.baseTexture;this.shader.uniforms.uSampler=i.bindTexture(h);for(var l=0,c=0;l<o;l+=n,c+=1){var d=o-l;d>n&&(d=n);var f=s[c];f.uploadDynamic(e,l,d),t._bufferToUpdate===c&&(f.uploadStatic(e,l,d),t._bufferToUpdate=c+1),i.bindVao(f.vao),f.vao.draw(a.TRIANGLES,6*d)}}},e.prototype.generateBuffers=function(t){for(var e=this.renderer.gl,r=[],n=t._maxSize,i=t._batchSize,o=t._properties,s=0;s<n;s+=i)r.push(new f.default(e,this.properties,o,i));return r},e.prototype.uploadVertices=function(t,e,r,n,i,o){for(var s=0,a=0,u=0,h=0,l=0;l<r;++l){var c=t[e+l],d=c._texture,f=c.scale.x,p=c.scale.y,v=d.trim,y=d.orig;v?(a=v.x-c.anchor.x*y.width,s=a+v.width,h=v.y-c.anchor.y*y.height,u=h+v.height):(s=y.width*(1-c.anchor.x),a=y.width*-c.anchor.x,u=y.height*(1-c.anchor.y),h=y.height*-c.anchor.y),n[o]=a*f,n[o+1]=h*p,n[o+i]=s*f,n[o+i+1]=h*p,n[o+2*i]=s*f,n[o+2*i+1]=u*p,n[o+3*i]=a*f,n[o+3*i+1]=u*p,o+=4*i}},e.prototype.uploadPosition=function(t,e,r,n,i,o){for(var s=0;s<r;s++){var a=t[e+s].position;n[o]=a.x,n[o+1]=a.y,n[o+i]=a.x,n[o+i+1]=a.y,n[o+2*i]=a.x,n[o+2*i+1]=a.y,n[o+3*i]=a.x,n[o+3*i+1]=a.y,o+=4*i}},e.prototype.uploadRotation=function(t,e,r,n,i,o){for(var s=0;s<r;s++){var a=t[e+s].rotation;n[o]=a,n[o+i]=a,n[o+2*i]=a,n[o+3*i]=a,o+=4*i}},e.prototype.uploadUvs=function(t,e,r,n,i,o){for(var s=0;s<r;++s){var a=t[e+s]._texture._uvs;a?(n[o]=a.x0,n[o+1]=a.y0,n[o+i]=a.x1,n[o+i+1]=a.y1,n[o+2*i]=a.x2,n[o+2*i+1]=a.y2,n[o+3*i]=a.x3,n[o+3*i+1]=a.y3,o+=4*i):(n[o]=0,n[o+1]=0,n[o+i]=0,n[o+i+1]=0,n[o+2*i]=0,n[o+2*i+1]=0,n[o+3*i]=0,n[o+3*i+1]=0,o+=4*i)}},e.prototype.uploadAlpha=function(t,e,r,n,i,o){for(var s=0;s<r;s++){var a=t[e+s].alpha;n[o]=a,n[o+i]=a,n[o+2*i]=a,n[o+3*i]=a,o+=4*i}},e.prototype.destroy=function(){this.renderer.gl&&this.renderer.gl.deleteBuffer(this.indexBuffer),t.prototype.destroy.call(this),this.shader.destroy(),this.indices=null,this.tempMatrix=null},e}(h.ObjectRenderer);r.default=p,h.WebGLRenderer.registerPlugin("particle",p)},{"../../core":61,"./ParticleBuffer":164,"./ParticleShader":166}],166:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function o(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function s(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}r.__esModule=!0;var a=t("../../core/Shader"),u=n(a),h=function(t){function e(r){return i(this,e),o(this,t.call(this,r,["attribute vec2 aVertexPosition;","attribute vec2 aTextureCoord;","attribute float aColor;","attribute vec2 aPositionCoord;","attribute vec2 aScale;","attribute float aRotation;","uniform mat3 projectionMatrix;","varying vec2 vTextureCoord;","varying float vColor;","void main(void){","   vec2 v = aVertexPosition;","   v.x = (aVertexPosition.x) * cos(aRotation) - (aVertexPosition.y) * sin(aRotation);","   v.y = (aVertexPosition.x) * sin(aRotation) + (aVertexPosition.y) * cos(aRotation);","   v = v + aPositionCoord;","   gl_Position = vec4((projectionMatrix * vec3(v, 1.0)).xy, 0.0, 1.0);","   vTextureCoord = aTextureCoord;","   vColor = aColor;","}"].join("\n"),["varying vec2 vTextureCoord;","varying float vColor;","uniform sampler2D uSampler;","uniform float uAlpha;","void main(void){","  vec4 color = texture2D(uSampler, vTextureCoord) * vColor * uAlpha;","  if (color.a == 0.0) discard;","  gl_FragColor = color;","}"].join("\n")))}return s(e,t),e}(u.default);r.default=h},{"../../core/Shader":41}],167:[function(t,e,r){"use strict";Math.sign||(Math.sign=function(t){return t=Number(t),0===t||isNaN(t)?t:t>0?1:-1})},{}],168:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}var i=t("object-assign"),o=n(i);Object.assign||(Object.assign=o.default)},{"object-assign":5}],169:[function(t,e,r){"use strict";t("./Object.assign"),t("./requestAnimationFrame"),t("./Math.sign"),window.ArrayBuffer||(window.ArrayBuffer=Array),window.Float32Array||(window.Float32Array=Array),window.Uint32Array||(window.Uint32Array=Array),window.Uint16Array||(window.Uint16Array=Array)},{"./Math.sign":167,"./Object.assign":168,"./requestAnimationFrame":170}],170:[function(t,e,r){(function(t){"use strict";var e=16;Date.now&&Date.prototype.getTime||(Date.now=function(){return(new Date).getTime()}),t.performance&&t.performance.now||!function(){var e=Date.now();t.performance||(t.performance={}),t.performance.now=function(){return Date.now()-e}}();for(var r=Date.now(),n=["ms","moz","webkit","o"],i=0;i<n.length&&!t.requestAnimationFrame;++i){var o=n[i];t.requestAnimationFrame=t[o+"RequestAnimationFrame"],t.cancelAnimationFrame=t[o+"CancelAnimationFrame"]||t[o+"CancelRequestAnimationFrame"]}t.requestAnimationFrame||(t.requestAnimationFrame=function(t){if("function"!=typeof t)throw new TypeError(t+"is not a function");var n=Date.now(),i=e+r-n;return i<0&&(i=0),r=n,setTimeout(function(){r=Date.now(),t(performance.now())},i)}),t.cancelAnimationFrame||(t.cancelAnimationFrame=function(t){return clearTimeout(t)})}).call(this,"undefined"!=typeof global?global:"undefined"!=typeof self?self:"undefined"!=typeof window?window:{})},{}],171:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function o(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function s(t,e){return e instanceof c.Text&&(e.updateText(!0),!0)}function a(t,e){if(e instanceof c.TextStyle){var r=c.Text.getFontStyle(e);return c.Text.fontPropertiesCache[r]||c.Text.calculateFontProperties(r),!0}return!1}function u(t,e){if(t instanceof c.Text){e.indexOf(t.style)===-1&&e.push(t.style),e.indexOf(t)===-1&&e.push(t);var r=t._texture.baseTexture;return e.indexOf(r)===-1&&e.push(r),!0}return!1}function h(t,e){return t instanceof c.TextStyle&&(e.indexOf(t)===-1&&e.push(t),!0)}r.__esModule=!0;var l=t("../core"),c=i(l),d=t("./limiters/CountLimiter"),f=n(d),p=c.ticker.shared;c.settings.UPLOADS_PER_FRAME=4;var v=function(){function t(e){var r=this;o(this,t),this.limiter=new f.default(c.settings.UPLOADS_PER_FRAME),this.renderer=e,this.uploadHookHelper=null,this.queue=[],this.addHooks=[],this.uploadHooks=[],this.completes=[],this.ticking=!1,this.delayedTick=function(){r.queue&&r.prepareItems()},this.register(u,s),this.register(h,a)}return t.prototype.upload=function(t,e){"function"==typeof t&&(e=t,t=null),t&&this.add(t),this.queue.length?(e&&this.completes.push(e),this.ticking||(this.ticking=!0,p.addOnce(this.tick,this))):e&&e()},t.prototype.tick=function(){setTimeout(this.delayedTick,0)},t.prototype.prepareItems=function(){for(this.limiter.beginFrame();this.queue.length&&this.limiter.allowedToUpload();){for(var t=this.queue[0],e=!1,r=0,n=this.uploadHooks.length;r<n;r++)if(this.uploadHooks[r](this.uploadHookHelper,t)){this.queue.shift(),e=!0;break}e||this.queue.shift()}if(this.queue.length)p.addOnce(this.tick,this);else{this.ticking=!1;var i=this.completes.slice(0);this.completes.length=0;for(var o=0,s=i.length;o<s;o++)i[o]()}},t.prototype.register=function(t,e){return t&&this.addHooks.push(t),e&&this.uploadHooks.push(e),this},t.prototype.add=function(t){for(var e=0,r=this.addHooks.length;e<r&&!this.addHooks[e](t,this.queue);e++);if(t instanceof c.Container)for(var n=t.children.length-1;n>=0;n--)this.add(t.children[n]);return this},t.prototype.destroy=function(){this.ticking&&p.remove(this.tick,this),this.ticking=!1,this.addHooks=null,this.uploadHooks=null,this.renderer=null,this.completes=null,this.queue=null,this.limiter=null,this.uploadHookHelper=null},t}();r.default=v},{"../core":61,"./limiters/CountLimiter":174}],172:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function o(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function s(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function a(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}function u(t,e){if(e instanceof c.BaseTexture){var r=e.source,n=0===r.width?t.canvas.width:Math.min(t.canvas.width,r.width),i=0===r.height?t.canvas.height:Math.min(t.canvas.height,r.height);return t.ctx.drawImage(r,0,0,n,i,0,0,t.canvas.width,t.canvas.height),!0}return!1}function h(t,e){if(t instanceof c.BaseTexture)return e.indexOf(t)===-1&&e.push(t),!0;if(t._texture&&t._texture instanceof c.Texture){var r=t._texture.baseTexture;return e.indexOf(r)===-1&&e.push(r),!0}return!1}r.__esModule=!0;var l=t("../../core"),c=i(l),d=t("../BasePrepare"),f=n(d),p=16,v=function(t){function e(r){o(this,e);var n=s(this,t.call(this,r));return n.uploadHookHelper=n,n.canvas=document.createElement("canvas"),n.canvas.width=p,n.canvas.height=p,n.ctx=n.canvas.getContext("2d"),n.register(h,u),n}return a(e,t),e.prototype.destroy=function(){t.prototype.destroy.call(this),this.ctx=null,this.canvas=null},e}(f.default);r.default=v,c.CanvasRenderer.registerPlugin("prepare",v)},{"../../core":61,"../BasePrepare":171}],173:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}r.__esModule=!0;
var i=t("./webgl/WebGLPrepare");Object.defineProperty(r,"webgl",{enumerable:!0,get:function(){return n(i).default}});var o=t("./canvas/CanvasPrepare");Object.defineProperty(r,"canvas",{enumerable:!0,get:function(){return n(o).default}});var s=t("./BasePrepare");Object.defineProperty(r,"BasePrepare",{enumerable:!0,get:function(){return n(s).default}});var a=t("./limiters/CountLimiter");Object.defineProperty(r,"CountLimiter",{enumerable:!0,get:function(){return n(a).default}});var u=t("./limiters/TimeLimiter");Object.defineProperty(r,"TimeLimiter",{enumerable:!0,get:function(){return n(u).default}})},{"./BasePrepare":171,"./canvas/CanvasPrepare":172,"./limiters/CountLimiter":174,"./limiters/TimeLimiter":175,"./webgl/WebGLPrepare":176}],174:[function(t,e,r){"use strict";function n(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var i=function(){function t(e){n(this,t),this.maxItemsPerFrame=e,this.itemsLeft=0}return t.prototype.beginFrame=function(){this.itemsLeft=this.maxItemsPerFrame},t.prototype.allowedToUpload=function(){return this.itemsLeft-- >0},t}();r.default=i},{}],175:[function(t,e,r){"use strict";function n(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}r.__esModule=!0;var i=function(){function t(e){n(this,t),this.maxMilliseconds=e,this.frameStart=0}return t.prototype.beginFrame=function(){this.frameStart=Date.now()},t.prototype.allowedToUpload=function(){return Date.now()-this.frameStart<this.maxMilliseconds},t}();r.default=i},{}],176:[function(t,e,r){"use strict";function n(t){return t&&t.__esModule?t:{default:t}}function i(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}function o(t,e){if(!(t instanceof e))throw new TypeError("Cannot call a class as a function")}function s(t,e){if(!t)throw new ReferenceError("this hasn't been initialised - super() hasn't been called");return!e||"object"!=typeof e&&"function"!=typeof e?t:e}function a(t,e){if("function"!=typeof e&&null!==e)throw new TypeError("Super expression must either be null or a function, not "+typeof e);t.prototype=Object.create(e&&e.prototype,{constructor:{value:t,enumerable:!1,writable:!0,configurable:!0}}),e&&(Object.setPrototypeOf?Object.setPrototypeOf(t,e):t.__proto__=e)}function u(t,e){return e instanceof f.BaseTexture&&(e._glTextures[t.CONTEXT_UID]||t.textureManager.updateTexture(e),!0)}function h(t,e){return e instanceof f.Graphics&&((e.dirty||e.clearDirty||!e._webGL[t.plugins.graphics.CONTEXT_UID])&&t.plugins.graphics.updateGraphics(e),!0)}function l(t,e){if(t instanceof f.BaseTexture)return e.indexOf(t)===-1&&e.push(t),!0;if(t._texture&&t._texture instanceof f.Texture){var r=t._texture.baseTexture;return e.indexOf(r)===-1&&e.push(r),!0}return!1}function c(t,e){return t instanceof f.Graphics&&(e.push(t),!0)}r.__esModule=!0;var d=t("../../core"),f=i(d),p=t("../BasePrepare"),v=n(p),y=function(t){function e(r){o(this,e);var n=s(this,t.call(this,r));return n.uploadHookHelper=n.renderer,n.register(l,u).register(c,h),n}return a(e,t),e}(v.default);r.default=y,f.WebGLRenderer.registerPlugin("prepare",y)},{"../../core":61,"../BasePrepare":171}],177:[function(t,e,r){(function(e){"use strict";function n(t){if(t&&t.__esModule)return t;var e={};if(null!=t)for(var r in t)Object.prototype.hasOwnProperty.call(t,r)&&(e[r]=t[r]);return e.default=t,e}r.__esModule=!0,r.loader=r.prepare=r.particles=r.mesh=r.loaders=r.interaction=r.filters=r.extras=r.extract=r.accessibility=void 0;var i=t("./deprecation");Object.keys(i).forEach(function(t){"default"!==t&&"__esModule"!==t&&Object.defineProperty(r,t,{enumerable:!0,get:function(){return i[t]}})});var o=t("./core");Object.keys(o).forEach(function(t){"default"!==t&&"__esModule"!==t&&Object.defineProperty(r,t,{enumerable:!0,get:function(){return o[t]}})}),t("./polyfill");var s=t("./accessibility"),a=n(s),u=t("./extract"),h=n(u),l=t("./extras"),c=n(l),d=t("./filters"),f=n(d),p=t("./interaction"),v=n(p),y=t("./loaders"),g=n(y),m=t("./mesh"),_=n(m),b=t("./particles"),x=n(b),T=t("./prepare"),w=n(T);r.accessibility=a,r.extract=h,r.extras=c,r.filters=f,r.interaction=v,r.loaders=g,r.mesh=_,r.particles=x,r.prepare=w;var E=g&&g.Loader?new g.Loader:null;r.loader=E,e.PIXI=r}).call(this,"undefined"!=typeof global?global:"undefined"!=typeof self?self:"undefined"!=typeof window?window:{})},{"./accessibility":40,"./core":61,"./deprecation":120,"./extract":122,"./extras":131,"./filters":142,"./interaction":148,"./loaders":151,"./mesh":160,"./particles":163,"./polyfill":169,"./prepare":173}]},{},[177])(177)});
//# sourceMappingURL=pixi.min.js.map
DropShadowFilter.sharedCopyFilter = new PIXI.Filter();    

function DropShadowFilter(angle, distance, blur, color, alpha) {
    PIXI.Filter.call(this);

    angle *= Math.PI / 180;
    this.angle = angle;
    this.distance = distance;
    this.color = color;
    this.padding = distance < 10 ? 10 : distance;
    this.blur = blur * 2.0;
    this.alpha = alpha;

    this.tintFilter = new PIXI.Filter(
        PIXI.Filter.defaultVertexSrc,
        ['varying vec2 vTextureCoord;',
        'uniform sampler2D uSampler;',
        'uniform float alpha;',
        'uniform vec3 color;',
        'void main(void){',
        '   vec4 sample = texture2D(uSampler, vTextureCoord);',
        '   gl_FragColor = vec4(color, sample.a > 0.0 ? alpha : 0.0);',
      '}'].join("\n")
    );
    this.tintFilter.uniforms.alpha = alpha;
    this.tintFilter.uniforms.color = PIXI.utils.hex2rgb(color);

    this.blurFilter = new PIXI.filters.BlurFilter();
    this.blurFilter.blur = blur;
}

DropShadowFilter.prototype = Object.create(PIXI.Filter.prototype);
DropShadowFilter.prototype.constructor = DropShadowFilter;
DropShadowFilter.prototype.apply = function (filterManager, input, output) {
    var rt = filterManager.getRenderTarget();
    rt.clear();
    if (!output.root) output.clear();

    rt.transform = new PIXI.Matrix();
    rt.transform.translate(this.distance * Math.cos(this.angle), this.distance * Math.sin(this.angle));
    this.tintFilter.apply(filterManager, input, rt);
    this.blurFilter.apply(filterManager, rt, output);
    DropShadowFilter.sharedCopyFilter.apply(filterManager, input, output);

    rt.transform = null;
    filterManager.returnRenderTarget(rt);
};

PIXI.filters.DropShadowFilter = DropShadowFilter;

///////////////////////////////
// Canvas Alpha Mask support //
///////////////////////////////

var AlphaMask_use_getImageData = !PIXI.CanvasTinter.canUseMultiply;

function apply_alpha_mask(main_ctx, mask_ctx, w, h, res)
{
    var img = main_ctx.getImageData(0, 0, w * res, h * res);
    var mask = mask_ctx.getImageData(0, 0, w * res, h * res);

    var imgdata = img.data;
    var maskdata = mask.data;
    var bufsize = imgdata.length|0;

    for (var i = 3; i < bufsize; i += 4)
        imgdata[i] = ((imgdata[i] * maskdata[i])/255)|0;

    main_ctx.putImageData(img, 0, 0);
}

function allocate_render_texture(texture, renderer, w, h)
{
    if (texture == null)
    {
        return PIXI.RenderTexture.create(w|0, h|0, PIXI.settings.SCALE_MODE.DEFAULT, renderer.resolution);
    }

    if (texture.width != w || texture.height != h)
    {
        // resize broken with resolution != 1
        //texture.resize(w|0, h|0, true);

        texture.destroy();
        return PIXI.RenderTexture.create(w|0, h|0, PIXI.settings.SCALE_MODE.DEFAULT, renderer.resolution);
    }
    return texture;
}

PIXI.Container.prototype._alphaMask = null;
PIXI.Container.prototype._canvasFilters = null;

Object.defineProperties(PIXI.Container.prototype, {
    alphaMask: {
        get: function ()
        {
            return this._alphaMask;
        },
        set: function (value)
        {
            if (this._alphaMask === value)
            {
                return;
            }

            if (this._alphaMask)
            {
                this._alphaMask.renderable = true;
            }

            this._alphaMask = value;

            if (value)
            {
                this._alphaMask.renderable = false;
            }

            this._updateFilterHooks();
        }
    },
    canvasFilters: {
        get: function ()
        {
            return this._canvasFilters && this._canvasFilters.slice();
        },
        set: function (value)
        {
            this._canvasFilters = value && value.slice();
            this._updateFilterHooks();
        }
    }
});

PIXI.Container.prototype._updateFilterHooks = function ()
{
    if (this._alphaMask || (this._canvasFilters && this._canvasFilters.length > 0))
    {
        if (this._CF_originalCalculateBounds == null)
        {
            this._CF_originalRenderCanvas = this.renderCanvas;
            this._CF_originalCalculateBounds = this.calculateBounds;
            this.renderCanvas = this._renderFilterCanvas;
            this.calculateBounds = this._calculateFilterBounds;
        }
    }
    else if (this._CF_originalCalculateBounds != null)
    {
        this.renderCanvas = this._CF_originalRenderCanvas;
        this.calculateBounds = this._CF_originalCalculateBounds;
        this._CF_originalCalculateBounds = null;
    }
}

PIXI.Filter.prototype.expandCanvasBounds = function (bounds)
{
    // nop
}

PIXI.Filter.prototype.drawToCanvas = function (input_tex, aux_tex, out_ctx, x, y)
{
    return input_tex;
}


PIXI.filters.DropShadowFilter.prototype.expandCanvasBounds = function (bounds)
{
    var dist = this.distance;
    var angle = this.angle;
    var radius = this.blur / 3;

    var dx = Math.sin(angle) * dist;
    var dy = Math.cos(angle) * dist;

    bounds.minX += Math.min(dx, 0) - radius;
    bounds.minY += Math.min(dy, 0) - radius;
    bounds.maxX += Math.max(dx, 0) + radius;
    bounds.maxY += Math.max(dy, 0) + radius;
}

function create_canvas_render_target(texture)
{
    var renderTexture = texture.baseTexture;
    renderTexture._canvasRenderTarget = new PIXI.CanvasRenderTarget(renderTexture.width, renderTexture.height, renderTexture.resolution);
    renderTexture.source = renderTexture._canvasRenderTarget.canvas;
    renderTexture.valid = true;
}

PIXI.filters.DropShadowFilter.prototype.drawToCanvas = function (input_tex, aux_tex, out_ctx, x, y)
{
    var outtex = null;

    if (out_ctx == null) {
        outtex = aux_tex;
        if (!aux_tex.baseTexture._canvasRenderTarget) {
            create_canvas_render_target(aux_tex);
        }

        out_ctx = aux_tex.baseTexture._canvasRenderTarget.context;
        x = y = 0;

        outtex.baseTexture._canvasRenderTarget.clear();
    }

    var dist = this.distance;
    var angle = this.angle;
    var color = PIXI.utils.hex2rgb(this.color);
    var res = input_tex.baseTexture.resolution;

    out_ctx.save();
    out_ctx.shadowColor = "rgba("+color[0]*255+","+color[1]*255+","+color[2]*255+","+this.alpha+")";
    out_ctx.shadowBlur = this.blur/3 * res;
    out_ctx.shadowOffsetX = Math.sin(angle) * dist * res;
    out_ctx.shadowOffsetY = Math.cos(angle) * dist * res;

    out_ctx.setTransform(1, 0, 0, 1, 0, 0);
    out_ctx.drawImage(input_tex.baseTexture._canvasRenderTarget.canvas, x * res, y * res);
    out_ctx.restore();

    return outtex;
}

PIXI.filters.BlurFilter.prototype.expandCanvasBounds = function (bounds)
{
    var radius = this.blur / 3;

    bounds.minX -= radius;
    bounds.minY -= radius;
    bounds.maxX += radius;
    bounds.maxY += radius;
}

PIXI.filters.BlurFilter.prototype.drawToCanvas = function (input_tex, aux_tex, out_ctx, x, y)
{
    var radius = this.blur / 3;
    var res = input_tex.baseTexture.resolution;

    StackBlur.canvasRGBA(
        input_tex.baseTexture._canvasRenderTarget.canvas,
        0, 0, input_tex.width * res, input_tex.height * res,
        radius * res
    );

    return input_tex;
}

PIXI.Container.prototype._calculateFilterBounds = function ()
{
    this._CF_originalCalculateBounds();

    var bounds = this._bounds;
    var filters = this._canvasFilters;

    if (filters != null) {
        for (var i = 0; i < filters.length; i++) {
            filters[i].expandCanvasBounds(bounds);
        }
    }
}

PIXI.Container.prototype._renderFilterCanvas = function (renderer)
{
    if (!this.visible || this.alpha <= 0 || !this.renderable)
    {
        return;
    }

    var filters = this._canvasFilters;

    if ((filters == null || filters.length == 0) && this._alphaMask == null)
    {
        return this._CF_originalRenderCanvas(renderer);
    }

    var bounds = this.getBounds(true);
    var wt = this.worldTransform;

    var x = Math.floor(bounds.x);
    var y = Math.floor(bounds.y);
    var w = Math.ceil(bounds.width + bounds.x - x);
    var h = Math.ceil(bounds.height + bounds.y - y);

    // Expand area to increments of 32 to minimize reallocations
    w = (w+31) & ~31;
    h = (h+31) & ~31;

    if (w < 1 || h < 1)
        return;

    var cachedRenderTarget = renderer.context;

    var m = this._filterMatrix;
    if (m == null)
        m = this._filterMatrix = wt.clone();

    this._filterTexMain = allocate_render_texture(this._filterTexMain, renderer, w, h);
    this._filterTexAux = allocate_render_texture(this._filterTexAux, renderer, w, h);

    // render
    var originalRenderCanvas = this.renderCanvas;
    this.renderCanvas = this._CF_originalRenderCanvas;

    this.localTransform.copy(m).invert().prepend(wt).translate(-x, -y);

    if (!this._filterTexMain.baseTexture._canvasRenderTarget) {
        create_canvas_render_target(this._filterTexMain);
    }
    this._filterTexMain.baseTexture._canvasRenderTarget.clear();

    renderer.render(this, this._filterTexMain, true, m, false);

    this.renderCanvas = originalRenderCanvas;

    // mask
    if (this._alphaMask != null)
    {
        var main_ctx = this._filterTexMain.baseTexture._canvasRenderTarget.context;
        
        if (!this._filterTexAux.baseTexture._canvasRenderTarget) {
            create_canvas_render_target(this._filterTexAux);
        }

        this._filterTexAux.baseTexture._canvasRenderTarget.clear();

        this._alphaMask.renderable = true;
        //this._alphaMask.worldTransform.copy(m).translate(-x, -y);
        renderer.render(this._alphaMask, this._filterTexAux, true, m, false);
        this._alphaMask.renderable = false;

        var mask_ctx = this._filterTexAux.baseTexture._canvasRenderTarget.context;

        if (AlphaMask_use_getImageData)
        {
            apply_alpha_mask(main_ctx, mask_ctx, w, h, renderer.resolution);
        }
        else
        {
            main_ctx.globalCompositeOperation = 'destination-in';
            main_ctx.setTransform(1, 0, 0, 1, 0, 0);
            main_ctx.drawImage(this._filterTexAux.baseTexture._canvasRenderTarget.canvas, 0, 0);
            main_ctx.globalCompositeOperation = 'source-over';
        }
    }

    // restore context
    renderer.context = cachedRenderTarget;

    // evaluate filters
    var ctx = renderer.context;

    ctx.globalAlpha = this.worldAlpha;

    var curtex = this._filterTexMain;
    var auxtex = this._filterTexAux;
    var rvlast = curtex;

    if (filters != null && filters.length > 0)
    {
        for (var i = 0; i < filters.length-1; i++)
        {
            var rv = filters[i].drawToCanvas(curtex, auxtex, null, 0, 0);

            if (rv == auxtex)
            {
                var tmp = auxtex;
                auxtex = curtex;
                curtex = tmp;
            }
        }

        // evaluate last filter and render
        rvlast = filters[filters.length-1].drawToCanvas(curtex, auxtex, ctx, x, y);
    }

    if (rvlast != null)
    {
        var res = renderer.resolution;

        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.drawImage(rvlast.baseTexture._canvasRenderTarget.canvas, x * res, y * res);
    }

    this.updateTransform();
}

var $global = typeof window != "undefined" ? window : typeof global != "undefined" ? global : typeof self != "undefined" ? self : this;
var console = $global.console || {log:function(){}};
var $estr = function() { return js_Boot.__string_rec(this,''); };
function $extend(from, fields) {
	function Inherit() {} Inherit.prototype = from; var proto = new Inherit();
	for (var name in fields) proto[name] = fields[name];
	if( fields.toString !== Object.prototype.toString ) proto.toString = fields.toString;
	return proto;
}
var Assert = function() { };
Assert.__name__ = true;
Assert.check = function(cond,message) {
	if(!cond) Assert.fail("Assertion" + (message != null?": " + message:""));
};
Assert.fail = function(message) {
	Assert.printStack("Failure: " + message);
	throw new js__$Boot_HaxeError(message);
};
Assert.printStack = function(message) {
	if(message != null) Errors.print(message);
	Assert.println(Assert.callStackToString(haxe_CallStack.callStack()));
};
Assert.printExnStack = function(message) {
	if(message != null) Errors.print(message);
	Assert.println(Assert.callStackToString(haxe_CallStack.exceptionStack()));
};
Assert.callStackToString = function(stack) {
	return haxe_CallStack.toString(stack);
};
Assert.trace = function(s) {
	var stack = haxe_CallStack.callStack();
	var loc = "<unknown>";
	var i = 2;
	var _g = 0;
	try {
		while(_g < stack.length) {
			var s1 = stack[_g];
			++_g;
			switch(s1[1]) {
			case 2:
				var pos = s1[4];
				var file = s1[3];
				var item = s1[2];
				if(--i == 0) {
					loc = file + ": " + pos;
					throw "__break__";
				}
				break;
			default:
			}
		}
	} catch( e ) { if( e != "__break__" ) throw e; }
	Errors.print("TRACE: at " + loc + ": " + s);
};
Assert.memStat = function(message) {
	var msg;
	if(message != null) msg = message + ": "; else msg = "";
};
Assert.println = function(message) {
	Errors.print(message);
};
var EReg = function(r,opt) {
	opt = opt.split("u").join("");
	this.r = new RegExp(r,opt);
};
EReg.__name__ = true;
EReg.prototype = {
	match: function(s) {
		if(this.r.global) this.r.lastIndex = 0;
		this.r.m = this.r.exec(s);
		this.r.s = s;
		return this.r.m != null;
	}
	,matched: function(n) {
		if(this.r.m != null && n >= 0 && n < this.r.m.length) return this.r.m[n]; else throw new js__$Boot_HaxeError("EReg::matched");
	}
	,__class__: EReg
};
var Errors = function() {
	this.callBack = null;
	this.doTrace = true;
	this.count = 0;
};
Errors.__name__ = true;
Errors.get = function() {
	if(Errors.instance == null) Errors.instance = new Errors();
	return Errors.instance;
};
Errors.report = function(text) {
	Errors.get().add(text);
	Errors.get().count++;
	Errors.print(text);
	Errors.addToLog(text);
};
Errors.warning = function(text) {
	Errors.get().add(text);
	Errors.print(text);
};
Errors.print = function(text) {
	if(!Errors.get().doTrace) return;
	console.log(text);
};
Errors.getCount = function() {
	return Errors.get().count;
};
Errors.resetCount = function() {
	Errors.get().count = 0;
};
Errors.addToLog = function(m) {
	if(Errors.dontlog) return;
};
Errors.closeErrorLog = function() {
};
Errors.prototype = {
	add: function(text) {
		if(this.callBack != null) this.callBack(text);
	}
	,__class__: Errors
};
var FlowArrayUtil = function() { };
FlowArrayUtil.__name__ = true;
FlowArrayUtil.fromArray = function(a) {
	return a;
};
FlowArrayUtil.toArray = function(a) {
	var v = [];
	var _g = 0;
	while(_g < a.length) {
		var e = a[_g];
		++_g;
		v.push(e);
	}
	return v;
};
FlowArrayUtil.one = function(e) {
	return [e];
};
FlowArrayUtil.two = function(e1,e2) {
	return [e1,e2];
};
FlowArrayUtil.three = function(e1,e2,e3) {
	return [e1,e2,e3];
};
var FlowFileSystemHx = function() { };
FlowFileSystemHx.__name__ = true;
FlowFileSystemHx.createDirectory = function(dir) {
	try {
		return "";
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return Std.string(e);
	}
};
FlowFileSystemHx.deleteDirectory = function(dir) {
	try {
		return "";
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return Std.string(e);
	}
};
FlowFileSystemHx.deleteFile = function(file) {
	try {
		return "";
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return Std.string(e);
	}
};
FlowFileSystemHx.renameFile = function(old,newName) {
	try {
		return "";
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return Std.string(e);
	}
};
FlowFileSystemHx.fileExists = function(file) {
	try {
		return false;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return false;
	}
};
FlowFileSystemHx.isDirectory = function(dir) {
	try {
		return false;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return false;
	}
};
FlowFileSystemHx.readDirectory = function(dir) {
	var d = [];
	try {
		return d;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return d;
	}
};
FlowFileSystemHx.fileSize = function(file) {
	try {
		return 0.0;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return 0.0;
	}
};
FlowFileSystemHx.fileModified = function(file) {
	try {
		return 0.0;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return 0.0;
	}
};
FlowFileSystemHx.resolveRelativePath = function(dir) {
	try {
		return dir;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return dir;
	}
};
var RuntimeType = { __ename__ : true, __constructs__ : ["RTVoid","RTBool","RTInt","RTDouble","RTString","RTArray","RTStruct","RTRefTo","RTUnknown"] };
RuntimeType.RTVoid = ["RTVoid",0];
RuntimeType.RTVoid.toString = $estr;
RuntimeType.RTVoid.__enum__ = RuntimeType;
RuntimeType.RTBool = ["RTBool",1];
RuntimeType.RTBool.toString = $estr;
RuntimeType.RTBool.__enum__ = RuntimeType;
RuntimeType.RTInt = ["RTInt",2];
RuntimeType.RTInt.toString = $estr;
RuntimeType.RTInt.__enum__ = RuntimeType;
RuntimeType.RTDouble = ["RTDouble",3];
RuntimeType.RTDouble.toString = $estr;
RuntimeType.RTDouble.__enum__ = RuntimeType;
RuntimeType.RTString = ["RTString",4];
RuntimeType.RTString.toString = $estr;
RuntimeType.RTString.__enum__ = RuntimeType;
RuntimeType.RTArray = function(type) { var $x = ["RTArray",5,type]; $x.__enum__ = RuntimeType; $x.toString = $estr; return $x; };
RuntimeType.RTStruct = function(name) { var $x = ["RTStruct",6,name]; $x.__enum__ = RuntimeType; $x.toString = $estr; return $x; };
RuntimeType.RTRefTo = function(type) { var $x = ["RTRefTo",7,type]; $x.__enum__ = RuntimeType; $x.toString = $estr; return $x; };
RuntimeType.RTUnknown = ["RTUnknown",8];
RuntimeType.RTUnknown.toString = $estr;
RuntimeType.RTUnknown.__enum__ = RuntimeType;
var FlowRefObject = function(v) {
	this.__v = v;
};
FlowRefObject.__name__ = true;
FlowRefObject.prototype = {
	__class__: FlowRefObject
};
var HaxeRuntime = function() { };
HaxeRuntime.__name__ = true;
HaxeRuntime.ref__ = function(val) {
	return new FlowRefObject(val);
};
HaxeRuntime.deref__ = function(val) {
	return val.__v;
};
HaxeRuntime.setref__ = function(r,v) {
	r.__v = v;
};
HaxeRuntime._s_ = function(v) {
	return v;
};
HaxeRuntime.initStruct = function(id,name,args,atypes) {
	HaxeRuntime._structnames_.h[id] = name;
	HaxeRuntime._structids_.set(name,id);
	HaxeRuntime._structargs_.h[id] = args;
	HaxeRuntime._structargtypes_.h[id] = atypes;
};
HaxeRuntime.compareByValue = function(o1,o2) {
	if(o1 == o2) return 0;
	if(o1 == null || o2 == null) return 1;
	if(HaxeRuntime.isArray(o1)) {
		if(!HaxeRuntime.isArray(o2)) return 1;
		var l1 = o1.length;
		var l2 = o2.length;
		var l;
		if(l1 < l2) l = l1; else l = l2;
		var _g = 0;
		while(_g < l) {
			var i = _g++;
			var c = HaxeRuntime.compareByValue(o1[i],o2[i]);
			if(c != 0) return c;
		}
		if(l1 == l2) return 0; else if(l1 < l2) return -1; else return 1;
	}
	if(Object.prototype.hasOwnProperty.call(o1,"_id")) {
		if(!Object.prototype.hasOwnProperty.call(o2,"_id")) return 1;
		var i1 = o1._id;
		var i2 = o2._id;
		if(i1 < i2) return -1;
		if(i1 > i2) return 1;
		var args = HaxeRuntime._structargs_.h[i1];
		var _g1 = 0;
		while(_g1 < args.length) {
			var f = args[_g1];
			++_g1;
			var c1 = HaxeRuntime.compareByValue(Reflect.field(o1,f),Reflect.field(o2,f));
			if(c1 != 0) return c1;
		}
		return 0;
	}
	if(o1 < o2) return -1; else return 1;
};
HaxeRuntime.isArray = function(o1) {
	return Array.isArray(o1);
};
HaxeRuntime.nop___ = function() {
};
HaxeRuntime.isSameStructType = function(o1,o2) {
	return !HaxeRuntime.isArray(o1) && !HaxeRuntime.isArray(o2) && Object.prototype.hasOwnProperty.call(o1,"_id") && Object.prototype.hasOwnProperty.call(o2,"_id") && o1._id == o2._id;
};
HaxeRuntime.toString = function(value) {
	if(value == null) return "{}";
	if(!Reflect.isObject(value)) return Std.string(value);
	if(HaxeRuntime.isArray(value)) {
		var a = value;
		var r = "[";
		var s1 = "";
		var _g = 0;
		while(_g < a.length) {
			var v = a[_g];
			++_g;
			var vc = HaxeRuntime.toString(v);
			r += s1 + vc;
			s1 = ", ";
		}
		return r + "]";
	}
	if(Object.prototype.hasOwnProperty.call(value,"__v")) return "ref " + HaxeRuntime.toString(value.__v);
	if(Object.prototype.hasOwnProperty.call(value,"_id")) {
		var id = value._id;
		var structname = HaxeRuntime._structnames_.h[id];
		var r1 = structname + "(";
		var s2 = "";
		var args = HaxeRuntime._structargs_.h[id];
		var argTypes = HaxeRuntime._structargtypes_.h[id];
		var _g1 = 0;
		var _g2 = args.length;
		while(_g1 < _g2) {
			var i = _g1++;
			var f = args[i];
			var t = argTypes[i];
			var v1 = Reflect.field(value,f);
			if(t == RuntimeType.RTDouble) r1 += s2 + Std.string(v1) + (Std["int"](v1) == v1?".0":""); else r1 += s2 + HaxeRuntime.toString(v1);
			s2 = ", ";
		}
		r1 += ")";
		return r1;
	}
	if(Reflect.isFunction(value)) return "<function>";
	var s = value;
	s = StringTools.replace(s,"\\","\\\\");
	s = StringTools.replace(s,"\"","\\\"");
	s = StringTools.replace(s,"\n","\\n");
	s = StringTools.replace(s,"\t","\\t");
	return "\"" + s + "\"";
};
HaxeRuntime.isValueFitInType = function(type,value) {
	switch(type[1]) {
	case 5:
		var arrtype = type[2];
		if(!HaxeRuntime.isArray(value)) return false;
		if(arrtype != RuntimeType.RTUnknown) {
			var _g1 = 0;
			var _g = value.length;
			while(_g1 < _g) {
				var i = _g1++;
				if(!HaxeRuntime.isValueFitInType(arrtype,value[i])) return false;
			}
		}
		return true;
	case 2:
		return HaxeRuntime.typeOf(value) == RuntimeType.RTDouble;
	case 7:
		var reftype = type[2];
		{
			var _g2 = HaxeRuntime.typeOf(value);
			switch(_g2[1]) {
			case 7:
				var t = _g2[2];
				return HaxeRuntime.isValueFitInType(reftype,value.__v);
			default:
				return false;
			}
		}
		break;
	case 8:
		return true;
	case 6:
		var name = type[2];
		{
			var _g3 = HaxeRuntime.typeOf(value);
			switch(_g3[1]) {
			case 6:
				var n = _g3[2];
				return name == "" || n == name;
			default:
				return false;
			}
		}
		break;
	default:
		return HaxeRuntime.typeOf(value) == type;
	}
};
HaxeRuntime.makeStructValue = function(name,args,default_value) {
	try {
		var sid = HaxeRuntime._structids_.get(name);
		if(sid == null) return default_value;
		var types = HaxeRuntime._structargtypes_.h[sid];
		if(types.length != args.length) return default_value;
		var _g1 = 0;
		var _g = args.length;
		while(_g1 < _g) {
			var i = _g1++;
			if(!HaxeRuntime.isValueFitInType(types[i],args[i])) return default_value;
		}
		var sargs = HaxeRuntime._structargs_.h[sid];
		var o = HaxeRuntime.makeEmptyStruct(sid);
		var _g11 = 0;
		var _g2 = args.length;
		while(_g11 < _g2) {
			var i1 = _g11++;
			o[sargs[i1]] = args[i1];
		}
		return o;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return default_value;
	}
};
HaxeRuntime.makeEmptyStruct = function(sid) {
	if(HaxeRuntime._structtemplates_ != null) {
		var ff = HaxeRuntime._structtemplates_.h[sid];
		if(ff != null) return ff._copy();
	}
	return { _id : sid};
};
HaxeRuntime.typeOf = function(value) {
	if(value == null) return RuntimeType.RTVoid;
	var t;
	t = typeof(value);
	switch(t) {
	case "string":
		return RuntimeType.RTString;
	case "number":
		return RuntimeType.RTDouble;
	case "boolean":
		return RuntimeType.RTBool;
	case "object":
		if(HaxeRuntime.isArray(value)) return RuntimeType.RTArray(RuntimeType.RTUnknown);
		if(Object.prototype.hasOwnProperty.call(value,"_id")) return RuntimeType.RTStruct(HaxeRuntime._structnames_.get(value._id));
		if(Object.prototype.hasOwnProperty.call(value,"__v")) return RuntimeType.RTRefTo(HaxeRuntime.typeOf(value.__v));
		break;
	default:
	}
	return RuntimeType.RTUnknown;
};
HaxeRuntime.mul_32 = function(a,b) {
	var ah = a >> 16 & 65535;
	var al = a & 65535;
	var bh = b >> 16 & 65535;
	var bl = b & 65535;
	var high = ah * bl + al * bh & 65535;
	return (high << 16) + al * bl;
};
HaxeRuntime.wideStringSafe = function(str) {
	var _g1 = 0;
	var _g = str.length;
	while(_g1 < _g) {
		var i = _g1++;
		var c = HxOverrides.cca(str,i);
		if(55296 <= c && c < 57344) return false;
	}
	return true;
};
var HxOverrides = function() { };
HxOverrides.__name__ = true;
HxOverrides.dateStr = function(date) {
	var m = date.getMonth() + 1;
	var d = date.getDate();
	var h = date.getHours();
	var mi = date.getMinutes();
	var s = date.getSeconds();
	return date.getFullYear() + "-" + (m < 10?"0" + m:"" + m) + "-" + (d < 10?"0" + d:"" + d) + " " + (h < 10?"0" + h:"" + h) + ":" + (mi < 10?"0" + mi:"" + mi) + ":" + (s < 10?"0" + s:"" + s);
};
HxOverrides.strDate = function(s) {
	var _g = s.length;
	switch(_g) {
	case 8:
		var k = s.split(":");
		var d = new Date();
		d.setTime(0);
		d.setUTCHours(k[0]);
		d.setUTCMinutes(k[1]);
		d.setUTCSeconds(k[2]);
		return d;
	case 10:
		var k1 = s.split("-");
		return new Date(k1[0],k1[1] - 1,k1[2],0,0,0);
	case 19:
		var k2 = s.split(" ");
		var y = k2[0].split("-");
		var t = k2[1].split(":");
		return new Date(y[0],y[1] - 1,y[2],t[0],t[1],t[2]);
	default:
		throw new js__$Boot_HaxeError("Invalid date format : " + s);
	}
};
HxOverrides.cca = function(s,index) {
	var x = s.charCodeAt(index);
	if(x != x) return undefined;
	return x;
};
HxOverrides.substr = function(s,pos,len) {
	if(pos != null && pos != 0 && len != null && len < 0) return "";
	if(len == null) len = s.length;
	if(pos < 0) {
		pos = s.length + pos;
		if(pos < 0) pos = 0;
	} else if(len < 0) len = s.length + len - pos;
	return s.substr(pos,len);
};
HxOverrides.indexOf = function(a,obj,i) {
	var len = a.length;
	if(i < 0) {
		i += len;
		if(i < 0) i = 0;
	}
	while(i < len) {
		if(a[i] === obj) return i;
		i++;
	}
	return -1;
};
HxOverrides.remove = function(a,obj) {
	var i = HxOverrides.indexOf(a,obj,0);
	if(i == -1) return false;
	a.splice(i,1);
	return true;
};
HxOverrides.iter = function(a) {
	return { cur : 0, arr : a, hasNext : function() {
		return this.cur < this.arr.length;
	}, next : function() {
		return this.arr[this.cur++];
	}};
};
Math.__name__ = true;
var Md5 = function() {
};
Md5.__name__ = true;
Md5.encode = function(s) {
	return Md5.inst.doEncode(s);
};
Md5.bitOR = function(a,b) {
	var lsb = a & 1 | b & 1;
	var msb31 = a >>> 1 | b >>> 1;
	return msb31 << 1 | lsb;
};
Md5.bitXOR = function(a,b) {
	var lsb = a & 1 ^ b & 1;
	var msb31 = a >>> 1 ^ b >>> 1;
	return msb31 << 1 | lsb;
};
Md5.bitAND = function(a,b) {
	var lsb = a & 1 & (b & 1);
	var msb31 = a >>> 1 & b >>> 1;
	return msb31 << 1 | lsb;
};
Md5.addme = function(x,y) {
	var lsw = (x & 65535) + (y & 65535);
	var msw = (x >> 16) + (y >> 16) + (lsw >> 16);
	return msw << 16 | lsw & 65535;
};
Md5.rhex = function(num) {
	var str = "";
	var hex_chr = "0123456789abcdef";
	var _g = 0;
	while(_g < 4) {
		var j = _g++;
		str += hex_chr.charAt(num >> j * 8 + 4 & 15) + hex_chr.charAt(num >> j * 8 & 15);
	}
	return str;
};
Md5.rol = function(num,cnt) {
	return num << cnt | num >>> 32 - cnt;
};
Md5.cmn = function(q,a,b,x,s,t) {
	return Md5.addme(Md5.rol(Md5.addme(Md5.addme(a,q),Md5.addme(x,t)),s),b);
};
Md5.ff = function(a,b,c,d,x,s,t) {
	return Md5.cmn(Md5.bitOR(Md5.bitAND(b,c),Md5.bitAND(~b,d)),a,b,x,s,t);
};
Md5.gg = function(a,b,c,d,x,s,t) {
	return Md5.cmn(Md5.bitOR(Md5.bitAND(b,d),Md5.bitAND(c,~d)),a,b,x,s,t);
};
Md5.hh = function(a,b,c,d,x,s,t) {
	return Md5.cmn(Md5.bitXOR(Md5.bitXOR(b,c),d),a,b,x,s,t);
};
Md5.ii = function(a,b,c,d,x,s,t) {
	return Md5.cmn(Md5.bitXOR(c,Md5.bitOR(b,~d)),a,b,x,s,t);
};
Md5.prototype = {
	str2blks: function(str) {
		var nblk = (str.length + 8 >> 6) + 1;
		var blks = [];
		var _g1 = 0;
		var _g = nblk * 16;
		while(_g1 < _g) {
			var i1 = _g1++;
			blks[i1] = 0;
		}
		var i = 0;
		while(i < str.length) {
			blks[i >> 2] |= HxOverrides.cca(str,i) << (str.length * 8 + i) % 4 * 8;
			i++;
		}
		blks[i >> 2] |= 128 << (str.length * 8 + i) % 4 * 8;
		var l = str.length * 8;
		var k = nblk * 16 - 2;
		blks[k] = l & 255;
		blks[k] |= (l >>> 8 & 255) << 8;
		blks[k] |= (l >>> 16 & 255) << 16;
		blks[k] |= (l >>> 24 & 255) << 24;
		return blks;
	}
	,charCodeAt: function(str,i) {
		return HxOverrides.cca(str,i);
	}
	,doEncode: function(str) {
		var x = this.str2blks(str);
		var a = 1732584193;
		var b = -271733879;
		var c = -1732584194;
		var d = 271733878;
		var step;
		var i = 0;
		while(i < x.length) {
			var olda = a;
			var oldb = b;
			var oldc = c;
			var oldd = d;
			step = 0;
			a = Md5.cmn(Md5.bitOR(Md5.bitAND(b,c),Md5.bitAND(~b,d)),a,b,x[i],7,-680876936);
			d = Md5.cmn(Md5.bitOR(Md5.bitAND(a,b),Md5.bitAND(~a,c)),d,a,x[i + 1],12,-389564586);
			c = Md5.cmn(Md5.bitOR(Md5.bitAND(d,a),Md5.bitAND(~d,b)),c,d,x[i + 2],17,606105819);
			b = Md5.cmn(Md5.bitOR(Md5.bitAND(c,d),Md5.bitAND(~c,a)),b,c,x[i + 3],22,-1044525330);
			a = Md5.cmn(Md5.bitOR(Md5.bitAND(b,c),Md5.bitAND(~b,d)),a,b,x[i + 4],7,-176418897);
			d = Md5.cmn(Md5.bitOR(Md5.bitAND(a,b),Md5.bitAND(~a,c)),d,a,x[i + 5],12,1200080426);
			c = Md5.cmn(Md5.bitOR(Md5.bitAND(d,a),Md5.bitAND(~d,b)),c,d,x[i + 6],17,-1473231341);
			b = Md5.cmn(Md5.bitOR(Md5.bitAND(c,d),Md5.bitAND(~c,a)),b,c,x[i + 7],22,-45705983);
			a = Md5.cmn(Md5.bitOR(Md5.bitAND(b,c),Md5.bitAND(~b,d)),a,b,x[i + 8],7,1770035416);
			d = Md5.cmn(Md5.bitOR(Md5.bitAND(a,b),Md5.bitAND(~a,c)),d,a,x[i + 9],12,-1958414417);
			c = Md5.cmn(Md5.bitOR(Md5.bitAND(d,a),Md5.bitAND(~d,b)),c,d,x[i + 10],17,-42063);
			b = Md5.cmn(Md5.bitOR(Md5.bitAND(c,d),Md5.bitAND(~c,a)),b,c,x[i + 11],22,-1990404162);
			a = Md5.cmn(Md5.bitOR(Md5.bitAND(b,c),Md5.bitAND(~b,d)),a,b,x[i + 12],7,1804603682);
			d = Md5.cmn(Md5.bitOR(Md5.bitAND(a,b),Md5.bitAND(~a,c)),d,a,x[i + 13],12,-40341101);
			c = Md5.cmn(Md5.bitOR(Md5.bitAND(d,a),Md5.bitAND(~d,b)),c,d,x[i + 14],17,-1502002290);
			b = Md5.cmn(Md5.bitOR(Md5.bitAND(c,d),Md5.bitAND(~c,a)),b,c,x[i + 15],22,1236535329);
			a = Md5.cmn(Md5.bitOR(Md5.bitAND(b,d),Md5.bitAND(c,~d)),a,b,x[i + 1],5,-165796510);
			d = Md5.cmn(Md5.bitOR(Md5.bitAND(a,c),Md5.bitAND(b,~c)),d,a,x[i + 6],9,-1069501632);
			c = Md5.cmn(Md5.bitOR(Md5.bitAND(d,b),Md5.bitAND(a,~b)),c,d,x[i + 11],14,643717713);
			b = Md5.cmn(Md5.bitOR(Md5.bitAND(c,a),Md5.bitAND(d,~a)),b,c,x[i],20,-373897302);
			a = Md5.cmn(Md5.bitOR(Md5.bitAND(b,d),Md5.bitAND(c,~d)),a,b,x[i + 5],5,-701558691);
			d = Md5.cmn(Md5.bitOR(Md5.bitAND(a,c),Md5.bitAND(b,~c)),d,a,x[i + 10],9,38016083);
			c = Md5.cmn(Md5.bitOR(Md5.bitAND(d,b),Md5.bitAND(a,~b)),c,d,x[i + 15],14,-660478335);
			b = Md5.cmn(Md5.bitOR(Md5.bitAND(c,a),Md5.bitAND(d,~a)),b,c,x[i + 4],20,-405537848);
			a = Md5.cmn(Md5.bitOR(Md5.bitAND(b,d),Md5.bitAND(c,~d)),a,b,x[i + 9],5,568446438);
			d = Md5.cmn(Md5.bitOR(Md5.bitAND(a,c),Md5.bitAND(b,~c)),d,a,x[i + 14],9,-1019803690);
			c = Md5.cmn(Md5.bitOR(Md5.bitAND(d,b),Md5.bitAND(a,~b)),c,d,x[i + 3],14,-187363961);
			b = Md5.cmn(Md5.bitOR(Md5.bitAND(c,a),Md5.bitAND(d,~a)),b,c,x[i + 8],20,1163531501);
			a = Md5.cmn(Md5.bitOR(Md5.bitAND(b,d),Md5.bitAND(c,~d)),a,b,x[i + 13],5,-1444681467);
			d = Md5.cmn(Md5.bitOR(Md5.bitAND(a,c),Md5.bitAND(b,~c)),d,a,x[i + 2],9,-51403784);
			c = Md5.cmn(Md5.bitOR(Md5.bitAND(d,b),Md5.bitAND(a,~b)),c,d,x[i + 7],14,1735328473);
			b = Md5.cmn(Md5.bitOR(Md5.bitAND(c,a),Md5.bitAND(d,~a)),b,c,x[i + 12],20,-1926607734);
			a = Md5.cmn(Md5.bitXOR(Md5.bitXOR(b,c),d),a,b,x[i + 5],4,-378558);
			d = Md5.cmn(Md5.bitXOR(Md5.bitXOR(a,b),c),d,a,x[i + 8],11,-2022574463);
			c = Md5.cmn(Md5.bitXOR(Md5.bitXOR(d,a),b),c,d,x[i + 11],16,1839030562);
			b = Md5.cmn(Md5.bitXOR(Md5.bitXOR(c,d),a),b,c,x[i + 14],23,-35309556);
			a = Md5.cmn(Md5.bitXOR(Md5.bitXOR(b,c),d),a,b,x[i + 1],4,-1530992060);
			d = Md5.cmn(Md5.bitXOR(Md5.bitXOR(a,b),c),d,a,x[i + 4],11,1272893353);
			c = Md5.cmn(Md5.bitXOR(Md5.bitXOR(d,a),b),c,d,x[i + 7],16,-155497632);
			b = Md5.cmn(Md5.bitXOR(Md5.bitXOR(c,d),a),b,c,x[i + 10],23,-1094730640);
			a = Md5.cmn(Md5.bitXOR(Md5.bitXOR(b,c),d),a,b,x[i + 13],4,681279174);
			d = Md5.cmn(Md5.bitXOR(Md5.bitXOR(a,b),c),d,a,x[i],11,-358537222);
			c = Md5.cmn(Md5.bitXOR(Md5.bitXOR(d,a),b),c,d,x[i + 3],16,-722521979);
			b = Md5.cmn(Md5.bitXOR(Md5.bitXOR(c,d),a),b,c,x[i + 6],23,76029189);
			a = Md5.cmn(Md5.bitXOR(Md5.bitXOR(b,c),d),a,b,x[i + 9],4,-640364487);
			d = Md5.cmn(Md5.bitXOR(Md5.bitXOR(a,b),c),d,a,x[i + 12],11,-421815835);
			c = Md5.cmn(Md5.bitXOR(Md5.bitXOR(d,a),b),c,d,x[i + 15],16,530742520);
			b = Md5.cmn(Md5.bitXOR(Md5.bitXOR(c,d),a),b,c,x[i + 2],23,-995338651);
			a = Md5.cmn(Md5.bitXOR(c,Md5.bitOR(b,~d)),a,b,x[i],6,-198630844);
			d = Md5.cmn(Md5.bitXOR(b,Md5.bitOR(a,~c)),d,a,x[i + 7],10,1126891415);
			c = Md5.cmn(Md5.bitXOR(a,Md5.bitOR(d,~b)),c,d,x[i + 14],15,-1416354905);
			b = Md5.cmn(Md5.bitXOR(d,Md5.bitOR(c,~a)),b,c,x[i + 5],21,-57434055);
			a = Md5.cmn(Md5.bitXOR(c,Md5.bitOR(b,~d)),a,b,x[i + 12],6,1700485571);
			d = Md5.cmn(Md5.bitXOR(b,Md5.bitOR(a,~c)),d,a,x[i + 3],10,-1894986606);
			c = Md5.cmn(Md5.bitXOR(a,Md5.bitOR(d,~b)),c,d,x[i + 10],15,-1051523);
			b = Md5.cmn(Md5.bitXOR(d,Md5.bitOR(c,~a)),b,c,x[i + 1],21,-2054922799);
			a = Md5.cmn(Md5.bitXOR(c,Md5.bitOR(b,~d)),a,b,x[i + 8],6,1873313359);
			d = Md5.cmn(Md5.bitXOR(b,Md5.bitOR(a,~c)),d,a,x[i + 15],10,-30611744);
			c = Md5.cmn(Md5.bitXOR(a,Md5.bitOR(d,~b)),c,d,x[i + 6],15,-1560198380);
			b = Md5.cmn(Md5.bitXOR(d,Md5.bitOR(c,~a)),b,c,x[i + 13],21,1309151649);
			a = Md5.cmn(Md5.bitXOR(c,Md5.bitOR(b,~d)),a,b,x[i + 4],6,-145523070);
			d = Md5.cmn(Md5.bitXOR(b,Md5.bitOR(a,~c)),d,a,x[i + 11],10,-1120210379);
			c = Md5.cmn(Md5.bitXOR(a,Md5.bitOR(d,~b)),c,d,x[i + 2],15,718787259);
			b = Md5.cmn(Md5.bitXOR(d,Md5.bitOR(c,~a)),b,c,x[i + 9],21,-343485551);
			a = Md5.addme(a,olda);
			b = Md5.addme(b,oldb);
			c = Md5.addme(c,oldc);
			d = Md5.addme(d,oldd);
			i += 16;
		}
		return Md5.rhex(a) + Md5.rhex(b) + Md5.rhex(c) + Md5.rhex(d);
	}
	,__class__: Md5
};
var js_BinaryParser = function(bigEndian,allowExceptions) {
	this.bigEndian = bigEndian;
	this.allowExceptions = allowExceptions;
};
js_BinaryParser.__name__ = true;
js_BinaryParser.prototype = {
	encodeFloat: function(number,precisionBits,exponentBits) {
		
			var bias = Math.pow(2, exponentBits - 1) - 1, minExp = -bias + 1, maxExp = bias, minUnnormExp = minExp - precisionBits,
			status = isNaN(n = parseFloat(number)) || n == -Infinity || n == +Infinity ? n : 0,
			exp = 0, len = 2 * bias + 1 + precisionBits + 3, bin = new Array(len),
			signal = (n = status !== 0 ? 0 : n) < 0, n = Math.abs(n), intPart = Math.floor(n), floatPart = n - intPart,
			i, lastBit, rounded, j, result;
			for(i = len; i; bin[--i] = 0);
			for(i = bias + 2; intPart && i; bin[--i] = intPart % 2, intPart = Math.floor(intPart / 2));
			for(i = bias + 1; floatPart > 0 && i; (bin[++i] = ((floatPart *= 2) >= 1) - 0) && --floatPart);
			for(i = -1; ++i < len && !bin[i];);
			if(bin[(lastBit = precisionBits - 1 + (i = (exp = bias + 1 - i) >= minExp && exp <= maxExp ? i + 1 : bias + 1 - (exp = minExp - 1))) + 1]){
			    if(!(rounded = bin[lastBit]))
				for(j = lastBit + 2; !rounded && j < len; rounded = bin[j++]);
			    for(j = lastBit + 1; rounded && --j >= 0; (bin[j] = !bin[j] - 0) && (rounded = 0));
			}
			for(i = i - 2 < 0 ? -1 : i - 3; ++i < len && !bin[i];);

			(exp = bias + 1 - i) >= minExp && exp <= maxExp ? ++i : exp < minExp &&
			    (exp != bias + 1 - len && exp < minUnnormExp && this.warn("encodeFloat::float underflow"), i = bias + 1 - (exp = minExp - 1));
			(intPart || status !== 0) && (this.warn(intPart ? "encodeFloat::float overflow" : "encodeFloat::" + status),
			    exp = maxExp + 1, i = bias + 2, status == -Infinity ? signal = 1 : isNaN(status) && (bin[i] = 1));
			for(n = Math.abs(exp + bias), j = exponentBits + 1, result = ""; --j; result = (n % 2) + result, n = n >>= 1);
			for(var n = 0, j = 0, i = (result = (signal ? "1" : "0") + result + bin.slice(i, i + precisionBits).join("")).length, r = [];
			    i; n += (1 << j) * result.charAt(--i), j == 7 && (r[r.length] = String.fromCharCode(n), n = 0), j = (j + 1) % 8);
			r[r.length] = n ? String.fromCharCode(n) : "";
			return (this.bigEndian ? r.reverse() : r).join("");
		;
		return "";
	}
	,decodeFloat: function(data,precisionBits,exponentBits) {
		
			var b = (((typeof js !== 'undefined' && js) ?
                                (b = new js.BinaryBuffer(this.bigEndian, data)) :
                                (b = new js_BinaryBuffer(this.bigEndian, data))).checkBuffer(precisionBits + exponentBits + 1), b),
			    bias = Math.pow(2, exponentBits - 1) - 1, signal = b.readBits(precisionBits + exponentBits, 1),
			    exponent = b.readBits(precisionBits, exponentBits), significand = 0,
			    divisor = 2, curByte = b.buffer.length + (-precisionBits >> 3) - 1,
			    byteValue, startBit, mask;
			do
			    for(byteValue = b.buffer[ ++curByte ], startBit = precisionBits % 8 || 8, mask = 1 << startBit;
				mask >>= 1; (byteValue & mask) && (significand += 1 / divisor), divisor *= 2);
			while(precisionBits -= startBit);
			return exponent == (bias << 1) + 1 ? significand ? NaN : signal ? -Infinity : +Infinity
			    : (1 + signal * -2) * (exponent || significand ? !exponent ? Math.pow(2, -bias + 1) * significand
			    : Math.pow(2, exponent - bias) * (1 + significand) : 0);
		;
		return 0.0;
	}
	,warn: function(msg) {
		if(this.allowExceptions) {
			throw new Error(msg);;
		}
		return 1;
	}
	,toDouble: function(data) {
		return this.decodeFloat(data,52,11);
	}
	,fromDouble: function(number) {
		return this.encodeFloat(number,52,11);
	}
	,__class__: js_BinaryParser
};
var StringBuf = function() {
	this.b = "";
};
StringBuf.__name__ = true;
StringBuf.prototype = {
	add: function(x) {
		this.b += Std.string(x);
	}
	,addChar: function(c) {
		this.b += String.fromCharCode(c);
	}
	,addSub: function(s,pos,len) {
		if(len == null) this.b += HxOverrides.substr(s,pos,null); else this.b += HxOverrides.substr(s,pos,len);
	}
	,__class__: StringBuf
};
var NativeHx = function() { };
NativeHx.__name__ = true;
NativeHx.println = function(arg) {
	var s = HaxeRuntime.toString(arg);
	Errors.report(s);
	return null;
};
NativeHx.hostCall = function(name,args) {
	var result = null;
	try {
		var name_parts = name.split(".");
		var fun = window[name_parts[0]];
		var _g1 = 1;
		var _g = name_parts.length;
		while(_g1 < _g) {
			var i = _g1++;
			fun = fun[name_parts[i]];
		}
		result = fun(args[0],args[1],args[2],args[3],args[4]);
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		Errors.report(e);
	}
	return result;
};
NativeHx.hostAddCallback = function(name,cb) {
	window[name] = cb;
	return null;
};
NativeHx.setClipboard = function(text) {
};
NativeHx.getClipboard = function() {
	return NativeHx.clipboardData;
};
NativeHx.toString = function(value) {
	return HaxeRuntime.toString(value);
};
NativeHx.gc = function() {
};
NativeHx.addHttpHeader = function(data) {
};
NativeHx.subrange = function(arr,start,len) {
	if(start < 0 || len < 1) return []; else return arr.slice(start,start + len);
};
NativeHx.isArray = function(a) {
	return HaxeRuntime.isArray(a);
};
NativeHx.isSameStructType = function(a,b) {
	return !HaxeRuntime.isArray(a) && !HaxeRuntime.isArray(b) && Object.prototype.hasOwnProperty.call(a,"_id") && Object.prototype.hasOwnProperty.call(b,"_id") && a._id == b._id;
};
NativeHx.isSameObj = function(a,b) {
	if(a == b) return true;
	if(a != null && b != null && Object.prototype.hasOwnProperty.call(a,"_id") && a._id == b._id && HaxeRuntime._structargs_.get(a._id).length == 0) return true;
	return false;
};
NativeHx.length__ = function(arr) {
	return arr.length;
};
NativeHx.strlen = function(s) {
	return s.length;
};
NativeHx.strIndexOf = function(str,substr) {
	return str.indexOf(substr,0);
};
NativeHx.strRangeIndexOf = function(str,substr,start,end) {
	if(end >= str.length) return str.indexOf(substr,start);
	var rv = HxOverrides.substr(str,start,end - start).indexOf(substr,0);
	if(rv < 0) return rv; else return start + rv;
};
NativeHx.substring = function(str,start,end) {
	return HxOverrides.substr(str,start,end);
};
NativeHx.toLowerCase = function(str) {
	return str.toLowerCase();
};
NativeHx.toUpperCase = function(str) {
	return str.toUpperCase();
};
NativeHx.string2utf8 = function(str) {
	var a = [];
	var buf = new haxe_io_BytesOutput();
	buf.writeString(str);
	var bytes = buf.getBytes();
	var _g1 = 0;
	var _g = bytes.length;
	while(_g1 < _g) {
		var i = _g1++;
		a.push(bytes.b[i]);
	}
	return a;
};
NativeHx.s2a = function(str) {
	var arr = [];
	var _g1 = 0;
	var _g = str.length;
	while(_g1 < _g) {
		var i = _g1++;
		arr.push(HxOverrides.cca(str,i));
	}
	return arr;
};
NativeHx.list2string = function(h) {
	var result = new StringBuf();
	while(Object.prototype.hasOwnProperty.call(h,"head")) {
		var s = Std.string(h.head);
		var a1 = s.split("");
		a1.reverse();
		result.add(a1.join(""));
		h = h.tail;
	}
	var a = result.b.split("");
	a.reverse();
	return a.join("");
};
NativeHx.list2array = function(h) {
	var result = [];
	while(Object.prototype.hasOwnProperty.call(h,"head")) {
		result.unshift(h.head);
		h = h.tail;
	}
	return result;
};
NativeHx.bitXor = function(a,b) {
	return a ^ b;
};
NativeHx.bitAnd = function(a,b) {
	return a & b;
};
NativeHx.bitOr = function(a,b) {
	return a | b;
};
NativeHx.bitUshr = function(a,b) {
	return a >>> b;
};
NativeHx.bitShl = function(a,b) {
	return a << b;
};
NativeHx.bitNot = function(a) {
	return ~a;
};
NativeHx.concat = function(arr1,arr2) {
	return arr1.concat(arr2);
};
NativeHx.replace = function(arr,i,v) {
	if(arr == null || i < 0) return [];
	var new_arr = arr.slice(0,arr.length);
	new_arr[i] = v;
	return new_arr;
};
NativeHx.map = function(values,clos) {
	var n = values.length;
	var result = Array(n);
	var _g = 0;
	while(_g < n) {
		var i = _g++;
		result[i] = clos(values[i]);
	}
	return result;
};
NativeHx.iter = function(values,clos) {
	var _g = 0;
	while(_g < values.length) {
		var v = values[_g];
		++_g;
		clos(v);
	}
};
NativeHx.mapi = function(values,clos) {
	var n = values.length;
	var result = Array(n);
	var _g = 0;
	while(_g < n) {
		var i = _g++;
		result[i] = clos(i,values[i]);
	}
	return result;
};
NativeHx.iteri = function(values,clos) {
	var i = 0;
	var _g = 0;
	while(_g < values.length) {
		var v = values[_g];
		++_g;
		clos(i,v);
		i++;
	}
};
NativeHx.iteriUntil = function(values,clos) {
	var i = 0;
	var _g = 0;
	while(_g < values.length) {
		var v = values[_g];
		++_g;
		if(clos(i,v)) return i;
		i++;
	}
	return i;
};
NativeHx.fold = function(values,init,fn) {
	var _g = 0;
	while(_g < values.length) {
		var v = values[_g];
		++_g;
		init = fn(init,v);
	}
	return init;
};
NativeHx.foldi = function(values,init,fn) {
	var i = 0;
	var _g = 0;
	while(_g < values.length) {
		var v = values[_g];
		++_g;
		init = fn(i,init,v);
		i++;
	}
	return init;
};
NativeHx.filter = function(values,clos) {
	var result = [];
	var _g = 0;
	while(_g < values.length) {
		var v = values[_g];
		++_g;
		if(clos(v)) result.push(v);
	}
	return result;
};
NativeHx.random = function() {
	return Math.random();
};
NativeHx.timestamp = function() {
	return NativeTime.timestamp();
};
NativeHx.getCurrentDate = function() {
	var date = new Date();
	return NativeHx.makeStructValue("Date",[date.getFullYear(),date.getMonth() + 1,date.getDate()],HaxeRuntime.makeStructValue("IllegalStruct",[],null));
};
NativeHx.timer = function(ms,cb) {
	haxe_Timer.delay(function() {
		try {
			cb();
		} catch( e ) {
			haxe_CallStack.lastException = e;
			if (e instanceof js__$Boot_HaxeError) e = e.val;
			NativeHx.println("FATAL ERROR: timer callback: " + Std.string(e));
			NativeHx.callFlowCrashHandlers("[Timer Handler]: " + Std.string(e));
		}
	},ms);
};
NativeHx.sin = function(a) {
	return Math.sin(a);
};
NativeHx.asin = function(a) {
	return Math.asin(a);
};
NativeHx.acos = function(a) {
	return Math.acos(a);
};
NativeHx.atan = function(a) {
	return Math.atan(a);
};
NativeHx.atan2 = function(a,b) {
	return Math.atan2(a,b);
};
NativeHx.exp = function(a) {
	return Math.exp(a);
};
NativeHx.log = function(a) {
	return Math.log(a);
};
NativeHx.enumFromTo = function(from,to) {
	var newArray = [];
	var _g1 = from;
	var _g = to + 1;
	while(_g1 < _g) {
		var i = _g1++;
		newArray.push(i);
	}
	return newArray;
};
NativeHx.getUrlParameter = function(name) {
	var value = Util.getParameter(name);
	if(value != null) return value; else return "";
};
NativeHx.isTouchScreen = function() {
	return ((('ontouchstart' in window) || window.DocumentTouch && document instanceof DocumentTouch) && window.matchMedia('(pointer: coarse)').matches) || navigator.userAgent.match(/iPad/i) || navigator.userAgent.match(/iPhone/i) || navigator.userAgent.match(/Android/i);
};
NativeHx.getTargetName = function() {
	if(!NativeHx.isTouchScreen()) return "js,pixi"; else return "js,pixi,mobile";
};
NativeHx.isIE = function() {
	return window.navigator.userAgent.indexOf("MSIE") >= 0;
};
NativeHx.setKeyValue = function(k,v) {
	return NativeHx.setKeyValueJS(k,v,false);
};
NativeHx.getKeyValue = function(key,def) {
	return NativeHx.getKeyValueJS(key,def,false);
};
NativeHx.removeKeyValue = function(key) {
	var useMask = StringTools.endsWith(key,"*");
	var mask = "";
	if(useMask) mask = HxOverrides.substr(key,0,key.length - 1);
	NativeHx.removeKeyValueJS(key,false);
};
NativeHx.setSessionKeyValue = function(k,v) {
	return NativeHx.setKeyValueJS(k,v,true);
};
NativeHx.getSessionKeyValue = function(key,def) {
	return NativeHx.getKeyValueJS(key,def,true);
};
NativeHx.removeSessionKeyValue = function(key) {
	NativeHx.removeKeyValueJS(key,true);
};
NativeHx.setKeyValueJS = function(k,v,session) {
	try {
		var storage;
		if(session) storage = sessionStorage; else storage = localStorage;
		if(NativeHx.isIE()) storage.setItem(k,encodeURIComponent(v)); else storage.setItem(k,v);
		return true;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		Errors.report("Cannot set value for key \"" + k + "\": " + Std.string(e));
		return false;
	}
};
NativeHx.getKeyValueJS = function(key,def,session) {
	try {
		var storage;
		if(session) storage = sessionStorage; else storage = localStorage;
		var value = storage.getItem(key);
		if(null == value) return def;
		if(NativeHx.isIE()) return decodeURIComponent(value.split("+").join(" ")); else return value;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		Errors.report("Cannot get value for key \"" + key + "\": " + Std.string(e));
		return def;
	}
};
NativeHx.removeKeyValueJS = function(key,session) {
	var useMask = StringTools.endsWith(key,"*");
	var mask = "";
	if(useMask) mask = HxOverrides.substr(key,0,key.length - 1);
	try {
		var storage;
		if(session) storage = sessionStorage; else storage = localStorage;
		if(storage.length == 0) return;
		if(useMask) {
			var nextKey;
			var _g1 = 0;
			var _g = storage.length;
			while(_g1 < _g) {
				var i = _g1++;
				nextKey = storage.key(i);
				if(StringTools.startsWith(nextKey,mask)) storage.removeItem(nextKey);
			}
		} else storage.removeItem(key);
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		Errors.report("Cannot remove key \"" + key + "\": " + Std.string(e));
	}
};
NativeHx.profileStart = function(n) {
};
NativeHx.profileEnd = function(n) {
};
NativeHx.profileCount = function(n,c) {
};
NativeHx.profileDump = function(n) {
};
NativeHx.profileReset = function() {
};
NativeHx.clearTrace = function() {
};
NativeHx.printCallstack = function() {
	NativeHx.println(Assert.callStackToString(haxe_CallStack.callStack()));
};
NativeHx.captureCallstack = function() {
	return null;
};
NativeHx.captureCallstackItem = function(index) {
	return null;
};
NativeHx.impersonateCallstackItem = function(item,index) {
};
NativeHx.failWithError = function(e) {
	throw new js__$Boot_HaxeError("Runtime failure: " + e);
};
NativeHx.makeStructValue = function(name,args,default_value) {
	return HaxeRuntime.makeStructValue(name,args,default_value);
};
NativeHx.quit = function(c) {
	window.open("","_top").close();
};
NativeHx.getFileContent = function(file) {
	return "";
};
NativeHx.getFileContentBinary = function(file) {
	throw new js__$Boot_HaxeError("Not implemented for this target: getFileContentBinary");
	return "";
};
NativeHx.setFileContent = function(file,content) {
	return false;
};
NativeHx.setFileContentUTF16 = function(file,content) {
	return false;
};
NativeHx.setFileContentBinary = function(file,content) {
	return false;
};
NativeHx.startProcess = function(command,args,cwd,stdIn,onExit) {
	return false;
};
NativeHx.fromCharCode = function(c) {
	return String.fromCharCode(c);
};
NativeHx.string2time = function(date) {
	return NativeTime.string2time(date);
};
NativeHx.dayOfWeek = function(year,month,day) {
	return NativeTime.dayOfWeek(year,month,day);
};
NativeHx.time2string = function(date) {
	return NativeTime.time2string(date);
};
NativeHx.getUrl = function(u,t) {
	try {
		window.open(u,t);
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		if(e != null && e.number != -2147467259) throw new js__$Boot_HaxeError(e);
	}
};
NativeHx.getUrl2 = function(u,t) {
	try {
		return window.open(u,t) != null;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		if(e != null && e.number != -2147467259) throw new js__$Boot_HaxeError(e); else Errors.report(e);
		return false;
	}
};
NativeHx.getCharCodeAt = function(s,i) {
	return HxOverrides.cca(s,i);
};
NativeHx.loaderUrl = function() {
	return window.location.href;
};
NativeHx.number2double = function(n) {
	return n;
};
NativeHx.stringbytes2double = function(s) {
	return NativeHx.stringToDouble(s);
};
NativeHx.stringbytes2int = function(s) {
	return HxOverrides.cca(s,0) | HxOverrides.cca(s,1) << 16;
};
NativeHx.initBinarySerialization = function() {
	if(typeof(ArrayBuffer) == "undefined" || typeof(Float64Array) == "undefined") {
		var binaryParser = new js_BinaryParser(false,false);
		NativeHx.doubleToString = function(value) {
			return NativeHx.packDoubleBytes(binaryParser.fromDouble(value));
		};
		NativeHx.stringToDouble = function(str) {
			return binaryParser.toDouble(NativeHx.unpackDoubleBytes(str));
		};
	} else {
		var arrayBuffer = new ArrayBuffer(16);
		var uint16Array = new Uint16Array(arrayBuffer);
		var float64Array = new Float64Array(arrayBuffer);
		NativeHx.doubleToString = function(value1) {
			float64Array[0] = value1;
			var ret_b = "";
			ret_b += String.fromCharCode(uint16Array[0]);
			ret_b += String.fromCharCode(uint16Array[1]);
			ret_b += String.fromCharCode(uint16Array[2]);
			ret_b += String.fromCharCode(uint16Array[3]);
			return ret_b;
		};
		NativeHx.stringToDouble = function(str1) {
			uint16Array[0] = HxOverrides.cca(str1,0);
			uint16Array[1] = HxOverrides.cca(str1,1);
			uint16Array[2] = HxOverrides.cca(str1,2);
			uint16Array[3] = HxOverrides.cca(str1,3);
			return float64Array[0];
		};
	}
};
NativeHx.packDoubleBytes = function(s) {
	var ret = new StringBuf();
	var _g1 = 0;
	var _g = s.length / 2;
	while(_g1 < _g) {
		var i = _g1++;
		ret.addChar(HxOverrides.cca(s,i * 2) | HxOverrides.cca(s,i * 2 + 1) << 8);
	}
	return ret.b;
};
NativeHx.unpackDoubleBytes = function(s) {
	var ret = new StringBuf();
	var _g1 = 0;
	var _g = s.length;
	while(_g1 < _g) {
		var i = _g1++;
		ret.addChar(HxOverrides.cca(s,i) & 255);
		ret.addChar(HxOverrides.cca(s,i) >> 8);
	}
	return ret.b;
};
NativeHx.writeBinaryInt32 = function(value,buf) {
	buf.b += String.fromCharCode(value & 65535);
	buf.b += String.fromCharCode(value >> 16);
};
NativeHx.writeInt = function(value,buf) {
	if((value & -32768) != 0) {
		buf.b += String.fromCharCode(65525);
		buf.b += String.fromCharCode(value & 65535);
		buf.b += String.fromCharCode(value >> 16);
	} else buf.b += String.fromCharCode(value);
};
NativeHx.writeStructDefs = function(buf) {
	NativeHx.writeArrayLength(NativeHx.structDefs.length,buf);
	var _g = 0;
	var _g1 = NativeHx.structDefs;
	while(_g < _g1.length) {
		var struct_def = _g1[_g];
		++_g;
		buf.b += String.fromCharCode(65528);
		buf.b += "\x02";
		buf.addChar(struct_def[0]);
		buf.b += String.fromCharCode(65530);
		buf.addChar(struct_def[1].length);
		buf.addSub(struct_def[1],0,null);
	}
};
NativeHx.writeArrayLength = function(arr_len,buf) {
	if(arr_len == 0) buf.b += String.fromCharCode(65527); else if(arr_len > 65535) {
		buf.b += String.fromCharCode(65529);
		buf.b += String.fromCharCode(arr_len & 65535);
		buf.b += String.fromCharCode(arr_len >> 16);
	} else {
		buf.b += String.fromCharCode(65528);
		buf.b += String.fromCharCode(arr_len);
	}
};
NativeHx.writeBinaryValue = function(value,buf) {
	{
		var _g = HaxeRuntime.typeOf(value);
		switch(_g[1]) {
		case 0:
			buf.b += String.fromCharCode(65535);
			break;
		case 1:
			buf.b += String.fromCharCode(value?65534:65533);
			break;
		case 3:
			buf.b += String.fromCharCode(65532);
			buf.addSub(NativeHx.doubleToString(value),0,null);
			break;
		case 4:
			var str_len = value.length;
			if(value.length > 65535) {
				buf.b += String.fromCharCode(65531);
				buf.b += String.fromCharCode(str_len & 65535);
				buf.b += String.fromCharCode(str_len >> 16);
			} else {
				buf.b += String.fromCharCode(65530);
				buf.b += String.fromCharCode(str_len);
			}
			buf.addSub(value,0,null);
			break;
		case 5:
			var t = _g[2];
			var arr_len = value.length;
			NativeHx.writeArrayLength(arr_len,buf);
			var _g1 = 0;
			while(_g1 < arr_len) {
				var i = _g1++;
				NativeHx.writeBinaryValue(value[i],buf);
			}
			break;
		case 6:
			var n = _g[2];
			var struct_id = value._id;
			var struct_fields = HaxeRuntime._structargs_.h[struct_id];
			var field_types = HaxeRuntime._structargtypes_.h[struct_id];
			var fields_count = struct_fields.length;
			var struct_idx = 0;
			if(NativeHx.structIdxs.h.hasOwnProperty(struct_id)) struct_idx = NativeHx.structIdxs.h[struct_id]; else {
				struct_idx = NativeHx.structDefs.length;
				NativeHx.structIdxs.h[struct_id] = struct_idx;
				NativeHx.structDefs.push([fields_count,HaxeRuntime._structnames_.h[struct_id]]);
			}
			buf.b += String.fromCharCode(65524);
			buf.b += String.fromCharCode(struct_idx);
			var _g11 = 0;
			while(_g11 < fields_count) {
				var i1 = _g11++;
				var field = Reflect.field(value,struct_fields[i1]);
				if(field_types[i1] == RuntimeType.RTInt) NativeHx.writeInt(field,buf); else NativeHx.writeBinaryValue(field,buf);
			}
			break;
		case 7:
			var t1 = _g[2];
			buf.b += String.fromCharCode(65526);
			NativeHx.writeBinaryValue(value.__v,buf);
			break;
		default:
			throw new js__$Boot_HaxeError("Cannot serialize " + Std.string(value));
		}
	}
};
NativeHx.toBinary = function(value) {
	var buf = new StringBuf();
	NativeHx.structIdxs = new haxe_ds_IntMap();
	NativeHx.structDefs = [];
	NativeHx.writeBinaryValue(value,buf);
	var str = buf.b;
	var struct_defs_buf = new StringBuf();
	NativeHx.writeStructDefs(struct_defs_buf);
	var ret = String.fromCharCode(str.length + 2 & 65535) + String.fromCharCode(str.length + 2 >> 16) + str + struct_defs_buf.b;
	return ret;
};
NativeHx.fromBinary = function(string,defvalue,fixups) {
	return string;
};
NativeHx.getTotalMemoryUsed = function() {
	return 0.0;
};
NativeHx.addCrashHandler = function(cb) {
	NativeHx.FlowCrashHandlers.push(cb);
	return function() {
		HxOverrides.remove(NativeHx.FlowCrashHandlers,cb);
	};
};
NativeHx.callFlowCrashHandlers = function(msg) {
	msg += "Call stack: " + Assert.callStackToString(haxe_CallStack.exceptionStack());
	var _g = 0;
	var _g1 = NativeHx.FlowCrashHandlers.slice(0,NativeHx.FlowCrashHandlers.length);
	while(_g < _g1.length) {
		var hdlr = _g1[_g];
		++_g;
		hdlr(msg);
	}
};
NativeHx.addPlatformEventListener = function(event,cb) {
	if(!NativeHx.PlatformEventListeners.exists(event)) {
		var value = [];
		NativeHx.PlatformEventListeners.set(event,value);
	}
	NativeHx.PlatformEventListeners.get(event).push(cb);
	return function() {
		var _this = NativeHx.PlatformEventListeners.get(event);
		HxOverrides.remove(_this,cb);
	};
};
NativeHx.notifyPlatformEvent = function(event) {
	var cancelled = false;
	if(NativeHx.PlatformEventListeners.exists(event)) {
		var _g = 0;
		var _g1 = NativeHx.PlatformEventListeners.get(event);
		while(_g < _g1.length) {
			var cb = _g1[_g];
			++_g;
			cancelled = cb() || cancelled;
		}
	}
	return cancelled;
};
NativeHx.addCameraPhotoEventListener = function(cb) {
	return function() {
	};
};
var NativeTime = function() { };
NativeTime.__name__ = true;
NativeTime.timestamp = function() {
	var t = new Date().getTime();
	return t;
};
NativeTime.string2time = function(date) {
	return HxOverrides.strDate(date).getTime();
};
NativeTime.time2string = function(date) {
	var _this;
	var d = new Date();
	d.setTime(date);
	_this = d;
	return HxOverrides.dateStr(_this);
};
NativeTime.dayOfWeek = function(year,month,day) {
	var d = new Date(year,month - 1,day,0,0,0);
	return (d.getDay() + 6) % 7;
};
var Reflect = function() { };
Reflect.__name__ = true;
Reflect.field = function(o,field) {
	try {
		return o[field];
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return null;
	}
};
Reflect.isFunction = function(f) {
	return typeof(f) == "function" && !(f.__name__ || f.__ename__);
};
Reflect.isObject = function(v) {
	if(v == null) return false;
	var t = typeof(v);
	return t == "string" || t == "object" && v.__enum__ == null || t == "function" && (v.__name__ || v.__ename__) != null;
};
var GraphOp = { __ename__ : true, __constructs__ : ["MoveTo","LineTo","CurveTo"] };
GraphOp.MoveTo = function(x,y) { var $x = ["MoveTo",0,x,y]; $x.__enum__ = GraphOp; $x.toString = $estr; return $x; };
GraphOp.LineTo = function(x,y) { var $x = ["LineTo",1,x,y]; $x.__enum__ = GraphOp; $x.toString = $estr; return $x; };
GraphOp.CurveTo = function(x,y,cx,cy) { var $x = ["CurveTo",2,x,y,cx,cy]; $x.__enum__ = GraphOp; $x.toString = $estr; return $x; };
var Util = function() { };
Util.__name__ = true;
Util.getParameter = function(name) {
	var href = window.location.href;
	var regexS = "[\\?&]" + name + "=([^&#]*)";
	var regex = new EReg(regexS,"");
	if(regex.match(href)) return StringTools.urlDecode(regex.matched(1)); else return null;
};
Util.makePath = function(dir,name) {
	if(StringTools.endsWith(dir,"/")) return dir + name; else return dir + "/" + name;
};
Util.openFile = function(path,mode) {
	if(mode == null) mode = true;
	return null;
};
Util.createDir = function(dir) {
};
Util.println = function(s) {
};
Util.clearCache = function() {
	Util.filesCache = new haxe_ds_StringMap();
	Util.filesHashCache = new haxe_ds_StringMap();
};
Util.readFile = function(file) {
	var content = Util.filesCache.get(file);
	if(content == null) {
	}
	return content;
};
Util.setFileContent = function(file,content) {
	Util.filesCache.set(file,content);
	Util.filesHashCache.set(file,null);
};
Util.getFileContent = function(file,content) {
	Util.filesCache.get(file);
};
Util.fileMd5 = function(file) {
	var hash = Util.filesHashCache.get(file);
	if(hash == null) {
		var content = Util.readFile(file);
		if(content != null) {
			var value = Md5.encode(content);
			Util.filesHashCache.set(file,value);
		}
	}
	return hash;
};
Util.writeFile = function(file,content) {
};
Util.compareStrings = function(a,b) {
	if(a < b) return -1;
	if(a > b) return 1;
	return 0;
};
Util.fromCharCode = function(code) {
	return String.fromCharCode(code);
};
var StringTools = function() { };
StringTools.__name__ = true;
StringTools.urlDecode = function(s) {
	return decodeURIComponent(s.split("+").join(" "));
};
StringTools.htmlEscape = function(s,quotes) {
	s = s.split("&").join("&amp;").split("<").join("&lt;").split(">").join("&gt;");
	if(quotes) return s.split("\"").join("&quot;").split("'").join("&#039;"); else return s;
};
StringTools.startsWith = function(s,start) {
	return s.length >= start.length && HxOverrides.substr(s,0,start.length) == start;
};
StringTools.endsWith = function(s,end) {
	var elen = end.length;
	var slen = s.length;
	return slen >= elen && HxOverrides.substr(s,slen - elen,elen) == end;
};
StringTools.isSpace = function(s,pos) {
	var c = HxOverrides.cca(s,pos);
	return c > 8 && c < 14 || c == 32;
};
StringTools.ltrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,r)) r++;
	if(r > 0) return HxOverrides.substr(s,r,l - r); else return s;
};
StringTools.rtrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,l - r - 1)) r++;
	if(r > 0) return HxOverrides.substr(s,0,l - r); else return s;
};
StringTools.trim = function(s) {
	return StringTools.ltrim(StringTools.rtrim(s));
};
StringTools.replace = function(s,sub,by) {
	return s.split(sub).join(by);
};
StringTools.hex = function(n,digits) {
	var s = "";
	var hexChars = "0123456789ABCDEF";
	do {
		s = hexChars.charAt(n & 15) + s;
		n >>>= 4;
	} while(n > 0);
	if(digits != null) while(s.length < digits) s = "0" + s;
	return s;
};
StringTools.fastCodeAt = function(s,index) {
	return s.charCodeAt(index);
};
var haxe_Timer = function(time_ms) {
	var me = this;
	this.id = setInterval(function() {
		me.run();
	},time_ms);
};
haxe_Timer.__name__ = true;
haxe_Timer.delay = function(f,time_ms) {
	var t = new haxe_Timer(time_ms);
	t.run = function() {
		t.stop();
		f();
	};
	return t;
};
haxe_Timer.prototype = {
	stop: function() {
		if(this.id == null) return;
		clearInterval(this.id);
		this.id = null;
	}
	,run: function() {
	}
	,__class__: haxe_Timer
};
var _$RenderSupportHx_Graphics = function(clip) {
	this.owner = clip;
	this.graphOps = [];
	this.strokeOpacity = this.fillOpacity = 0.0;
	this.strokeWidth = 0.0;
};
_$RenderSupportHx_Graphics.__name__ = true;
_$RenderSupportHx_Graphics.prototype = {
	addGraphOp: function(op) {
		this.graphOps.push(op);
	}
	,setLineStyle: function(width,color,opacity) {
		this.strokeWidth = width;
		this.strokeColor = color;
		this.strokeOpacity = opacity;
	}
	,setSolidFill: function(color,opacity) {
		this.fillColor = color;
		this.fillOpacity = opacity;
	}
	,setGradientFill: function(colors,alphas,offsets,matrix,type) {
		this.fillGradientColors = colors;
		this.fillGradientAlphas = alphas;
		this.fillGradientOffsets = offsets;
		this.fillGradientMatrix = matrix;
		this.fillGradientType = type;
	}
	,measure: function() {
		var max_x = -Infinity;
		var max_y = -Infinity;
		var min_x = Infinity;
		var min_y = Infinity;
		var _g1 = 0;
		var _g = this.graphOps.length;
		while(_g1 < _g) {
			var i = _g1++;
			var op = this.graphOps[i];
			switch(op[1]) {
			case 0:
				var y = op[3];
				var x = op[2];
				if(x > max_x) max_x = x;
				if(x < min_x) min_x = x;
				if(y > max_y) max_y = y;
				if(y < min_y) min_y = y;
				break;
			case 1:
				var y1 = op[3];
				var x1 = op[2];
				if(i == 0) max_x = max_y = min_x = min_y = 0.0;
				if(x1 > max_x) max_x = x1;
				if(x1 < min_x) min_x = x1;
				if(y1 > max_y) max_y = y1;
				if(y1 < min_y) min_y = y1;
				break;
			case 2:
				var cy = op[5];
				var cx = op[4];
				var y2 = op[3];
				var x2 = op[2];
				if(i == 0) max_x = max_y = min_x = min_y = 0.0;
				if(x2 > max_x) max_x = x2;
				if(x2 < min_x) min_x = x2;
				if(y2 > max_y) max_y = y2;
				if(y2 < min_y) min_y = y2;
				if(cx > max_x) max_x = cx;
				if(cx < min_x) min_x = cx;
				if(cy > max_y) max_y = cy;
				if(cy < min_y) min_y = cy;
				break;
			}
		}
		return { x0 : min_x, y0 : min_y, x1 : max_x + this.strokeWidth, y1 : max_y + this.strokeWidth};
	}
	,createSVGElement: function(name,attrs) {
		var element = window.document.createElementNS("http://www.w3.org/2000/svg",name);
		var _g = 0;
		while(_g < attrs.length) {
			var a = attrs[_g];
			++_g;
			element.setAttribute(a.n,a.v);
		}
		return element;
	}
	,addSVGGradient: function(svg,id) {
		var defs = this.createSVGElement("defs",[]);
		svg.appendChild(defs);
		var width = this.fillGradientMatrix[0];
		var height = this.fillGradientMatrix[1];
		var rotation = this.fillGradientMatrix[2];
		var xOffset = this.fillGradientMatrix[3];
		var yOffset = this.fillGradientMatrix[4];
		var grad = this.createSVGElement("linearGradient",[{ n : "id", v : id},{ n : "x1", v : xOffset},{ n : "y1", v : yOffset},{ n : "x2", v : width * Math.cos(rotation / 180.0 * Math.PI)},{ n : "y2", v : height * Math.sin(rotation / 180.0 * Math.PI)}]);
		defs.appendChild(grad);
		var _g1 = 0;
		var _g = this.fillGradientColors.length;
		while(_g1 < _g) {
			var i = _g1++;
			var stop_pt = this.createSVGElement("stop",[{ n : "offset", v : "" + this.fillGradientOffsets[i] * 100.0 + "%"},{ n : "stop-color", v : RenderSupportHx.makeCSSColor(this.fillGradientColors[i],this.fillGradientAlphas[i])}]);
			grad.appendChild(stop_pt);
		}
	}
	,renderSVG: function() {
		var wh = this.measure();
		var svg = this.createSVGElement("svg",[{ n : "xmlns", v : "http://www.w3.org/2000/svg"},{ n : "version", v : "1.1"}]);
		var path_data = "";
		var _g = 0;
		var _g1 = this.graphOps;
		while(_g < _g1.length) {
			var op = _g1[_g];
			++_g;
			switch(op[1]) {
			case 0:
				var y = op[3];
				var x = op[2];
				path_data += "M " + x + " " + y + " ";
				break;
			case 1:
				var y1 = op[3];
				var x1 = op[2];
				path_data += "L " + x1 + " " + y1 + " ";
				break;
			case 2:
				var cy = op[5];
				var cx = op[4];
				var y2 = op[3];
				var x2 = op[2];
				path_data += "S " + cx + " " + cy + " " + x2 + " " + y2 + " ";
				break;
			}
		}
		var svgpath_attr = [{ n : "d", v : path_data}];
		if(this.strokeOpacity != 0.0) svgpath_attr.push({ n : "stroke", v : RenderSupportHx.makeCSSColor(this.strokeColor,this.strokeOpacity)});
		if(this.fillOpacity != 0.0) svgpath_attr.push({ n : "fill", v : RenderSupportHx.makeCSSColor(this.fillColor,this.fillOpacity)}); else if(this.fillGradientColors != null) {
			var id = "grad" + new Date().getTime();
			this.addSVGGradient(svg,id);
			svgpath_attr.push({ n : "fill", v : "url(#" + id + ")"});
		} else svgpath_attr.push({ n : "fill", v : RenderSupportHx.makeCSSColor(16777215,0.0)});
		svgpath_attr.push({ n : "transform", v : "translate(" + -wh.x0 + "," + -wh.y0 + ")"});
		var svgpath = this.createSVGElement("path",svgpath_attr);
		svg.setAttribute("width",wh.x1 - wh.x0);
		svg.setAttribute("height",wh.y1 - wh.y0);
		svg.appendChild(svgpath);
		svg.style.left = "" + wh.x0 + "px";
		svg.style.top = "" + wh.y0 + "px";
		this.owner.appendChild(svg);
	}
	,renderCanvas: function() {
		var wh = this.measure();
		var canvas = window.document.createElement("CANVAS");
		var ctx = canvas.getContext("2d");
		this.owner.appendChild(canvas);
		canvas.height = wh.y1 - wh.y0;
		canvas.width = wh.x1 - wh.x0;
		canvas.style.top = "" + wh.y0 + "px";
		canvas.style.left = "" + wh.x0 + "px";
		canvas.x0 = wh.x0;
		canvas.y0 = wh.y0;
		canvas.style.width = "" + (wh.x1 - wh.x0) + "px";
		canvas.style.height = "" + (wh.y1 - wh.y0) + "px";
		if(this.strokeOpacity != 0.0) {
			ctx.lineWidth = this.strokeWidth;
			ctx.strokeStyle = RenderSupportHx.makeCSSColor(this.strokeColor,this.strokeOpacity);
		}
		if(this.fillOpacity != 0.0) ctx.fillStyle = RenderSupportHx.makeCSSColor(this.fillColor,this.fillOpacity);
		if(this.fillGradientColors != null) {
			var width = this.fillGradientMatrix[0];
			var height = this.fillGradientMatrix[1];
			var rotation = this.fillGradientMatrix[2];
			var xOffset = this.fillGradientMatrix[3];
			var yOffset = this.fillGradientMatrix[4];
			var gradient = ctx.createLinearGradient(xOffset,yOffset,width * Math.cos(rotation / 180.0 * Math.PI),height * Math.sin(rotation / 180.0 * Math.PI));
			var _g1 = 0;
			var _g = this.fillGradientColors.length;
			while(_g1 < _g) {
				var i = _g1++;
				gradient.addColorStop(this.fillGradientOffsets[i],RenderSupportHx.makeCSSColor(this.fillGradientColors[i],this.fillGradientAlphas[i]));
			}
			ctx.fillStyle = gradient;
		}
		ctx.translate(-wh.x0,-wh.y0);
		ctx.beginPath();
		ctx.moveTo(0.0,0.0);
		var _g2 = 0;
		var _g11 = this.graphOps;
		while(_g2 < _g11.length) {
			var op = _g11[_g2];
			++_g2;
			switch(op[1]) {
			case 0:
				var y = op[3];
				var x = op[2];
				ctx.moveTo(x,y);
				break;
			case 1:
				var y1 = op[3];
				var x1 = op[2];
				ctx.lineTo(x1,y1);
				break;
			case 2:
				var cy = op[5];
				var cx = op[4];
				var y2 = op[3];
				var x2 = op[2];
				ctx.quadraticCurveTo(cx,cy,x2,y2);
				break;
			}
		}
		if(this.fillOpacity != 0.0 || this.fillGradientColors != null) {
			ctx.closePath();
			ctx.fill();
		}
		if(this.strokeOpacity != 0.0) ctx.stroke();
	}
	,render: function() {
		if(_$RenderSupportHx_Graphics.svg) this.renderSVG(); else this.renderCanvas();
	}
	,__class__: _$RenderSupportHx_Graphics
};
var haxe_Resource = function() { };
haxe_Resource.__name__ = true;
haxe_Resource.getString = function(name) {
	var _g = 0;
	var _g1 = haxe_Resource.content;
	while(_g < _g1.length) {
		var x = _g1[_g];
		++_g;
		if(x.name == name) {
			if(x.str != null) return x.str;
			var b = haxe_crypto_Base64.decode(x.data);
			return b.toString();
		}
	}
	return null;
};
var haxe_io_Bytes = function(data) {
	this.length = data.byteLength;
	this.b = new Uint8Array(data);
	this.b.bufferValue = data;
	data.hxBytes = this;
	data.bytes = this.b;
};
haxe_io_Bytes.__name__ = true;
haxe_io_Bytes.alloc = function(length) {
	return new haxe_io_Bytes(new ArrayBuffer(length));
};
haxe_io_Bytes.ofString = function(s) {
	var a = [];
	var i = 0;
	while(i < s.length) {
		var c = StringTools.fastCodeAt(s,i++);
		if(55296 <= c && c <= 56319) c = c - 55232 << 10 | StringTools.fastCodeAt(s,i++) & 1023;
		if(c <= 127) a.push(c); else if(c <= 2047) {
			a.push(192 | c >> 6);
			a.push(128 | c & 63);
		} else if(c <= 65535) {
			a.push(224 | c >> 12);
			a.push(128 | c >> 6 & 63);
			a.push(128 | c & 63);
		} else {
			a.push(240 | c >> 18);
			a.push(128 | c >> 12 & 63);
			a.push(128 | c >> 6 & 63);
			a.push(128 | c & 63);
		}
	}
	return new haxe_io_Bytes(new Uint8Array(a).buffer);
};
haxe_io_Bytes.prototype = {
	get: function(pos) {
		return this.b[pos];
	}
	,set: function(pos,v) {
		this.b[pos] = v & 255;
	}
	,getString: function(pos,len) {
		if(pos < 0 || len < 0 || pos + len > this.length) throw new js__$Boot_HaxeError(haxe_io_Error.OutsideBounds);
		var s = "";
		var b = this.b;
		var fcc = String.fromCharCode;
		var i = pos;
		var max = pos + len;
		while(i < max) {
			var c = b[i++];
			if(c < 128) {
				if(c == 0) break;
				s += fcc(c);
			} else if(c < 224) s += fcc((c & 63) << 6 | b[i++] & 127); else if(c < 240) {
				var c2 = b[i++];
				s += fcc((c & 31) << 12 | (c2 & 127) << 6 | b[i++] & 127);
			} else {
				var c21 = b[i++];
				var c3 = b[i++];
				var u = (c & 15) << 18 | (c21 & 127) << 12 | (c3 & 127) << 6 | b[i++] & 127;
				s += fcc((u >> 10) + 55232);
				s += fcc(u & 1023 | 56320);
			}
		}
		return s;
	}
	,toString: function() {
		return this.getString(0,this.length);
	}
	,__class__: haxe_io_Bytes
};
var haxe_crypto_Base64 = function() { };
haxe_crypto_Base64.__name__ = true;
haxe_crypto_Base64.decode = function(str,complement) {
	if(complement == null) complement = true;
	if(complement) while(HxOverrides.cca(str,str.length - 1) == 61) str = HxOverrides.substr(str,0,-1);
	return new haxe_crypto_BaseCode(haxe_crypto_Base64.BYTES).decodeBytes(haxe_io_Bytes.ofString(str));
};
var haxe_crypto_BaseCode = function(base) {
	var len = base.length;
	var nbits = 1;
	while(len > 1 << nbits) nbits++;
	if(nbits > 8 || len != 1 << nbits) throw new js__$Boot_HaxeError("BaseCode : base length must be a power of two.");
	this.base = base;
	this.nbits = nbits;
};
haxe_crypto_BaseCode.__name__ = true;
haxe_crypto_BaseCode.prototype = {
	initTable: function() {
		var tbl = [];
		var _g = 0;
		while(_g < 256) {
			var i = _g++;
			tbl[i] = -1;
		}
		var _g1 = 0;
		var _g2 = this.base.length;
		while(_g1 < _g2) {
			var i1 = _g1++;
			tbl[this.base.b[i1]] = i1;
		}
		this.tbl = tbl;
	}
	,decodeBytes: function(b) {
		var nbits = this.nbits;
		var base = this.base;
		if(this.tbl == null) this.initTable();
		var tbl = this.tbl;
		var size = b.length * nbits >> 3;
		var out = haxe_io_Bytes.alloc(size);
		var buf = 0;
		var curbits = 0;
		var pin = 0;
		var pout = 0;
		while(pout < size) {
			while(curbits < 8) {
				curbits += nbits;
				buf <<= nbits;
				var i = tbl[b.get(pin++)];
				if(i == -1) throw new js__$Boot_HaxeError("BaseCode : invalid encoded char");
				buf |= i;
			}
			curbits -= 8;
			out.set(pout++,buf >> curbits & 255);
		}
		return out;
	}
	,__class__: haxe_crypto_BaseCode
};
var Std = function() { };
Std.__name__ = true;
Std.string = function(s) {
	return js_Boot.__string_rec(s,"");
};
Std["int"] = function(x) {
	return x | 0;
};
Std.parseInt = function(x) {
	var v = parseInt(x,10);
	if(v == 0 && (HxOverrides.cca(x,1) == 120 || HxOverrides.cca(x,1) == 88)) v = parseInt(x);
	if(isNaN(v)) return null;
	return v;
};
var js_Boot = function() { };
js_Boot.__name__ = true;
js_Boot.getClass = function(o) {
	if((o instanceof Array) && o.__enum__ == null) return Array; else {
		var cl = o.__class__;
		if(cl != null) return cl;
		var name = js_Boot.__nativeClassName(o);
		if(name != null) return js_Boot.__resolveNativeClass(name);
		return null;
	}
};
js_Boot.__string_rec = function(o,s) {
	if(o == null) return "null";
	if(s.length >= 5) return "<...>";
	var t = typeof(o);
	if(t == "function" && (o.__name__ || o.__ename__)) t = "object";
	switch(t) {
	case "object":
		if(o instanceof Array) {
			if(o.__enum__) {
				if(o.length == 2) return o[0];
				var str2 = o[0] + "(";
				s += "\t";
				var _g1 = 2;
				var _g = o.length;
				while(_g1 < _g) {
					var i1 = _g1++;
					if(i1 != 2) str2 += "," + js_Boot.__string_rec(o[i1],s); else str2 += js_Boot.__string_rec(o[i1],s);
				}
				return str2 + ")";
			}
			var l = o.length;
			var i;
			var str1 = "[";
			s += "\t";
			var _g2 = 0;
			while(_g2 < l) {
				var i2 = _g2++;
				str1 += (i2 > 0?",":"") + js_Boot.__string_rec(o[i2],s);
			}
			str1 += "]";
			return str1;
		}
		var tostr;
		try {
			tostr = o.toString;
		} catch( e ) {
			haxe_CallStack.lastException = e;
			if (e instanceof js__$Boot_HaxeError) e = e.val;
			return "???";
		}
		if(tostr != null && tostr != Object.toString && typeof(tostr) == "function") {
			var s2 = o.toString();
			if(s2 != "[object Object]") return s2;
		}
		var k = null;
		var str = "{\n";
		s += "\t";
		var hasp = o.hasOwnProperty != null;
		for( var k in o ) {
		if(hasp && !o.hasOwnProperty(k)) {
			continue;
		}
		if(k == "prototype" || k == "__class__" || k == "__super__" || k == "__interfaces__" || k == "__properties__") {
			continue;
		}
		if(str.length != 2) str += ", \n";
		str += s + k + " : " + js_Boot.__string_rec(o[k],s);
		}
		s = s.substring(1);
		str += "\n" + s + "}";
		return str;
	case "function":
		return "<function>";
	case "string":
		return o;
	default:
		return String(o);
	}
};
js_Boot.__interfLoop = function(cc,cl) {
	if(cc == null) return false;
	if(cc == cl) return true;
	var intf = cc.__interfaces__;
	if(intf != null) {
		var _g1 = 0;
		var _g = intf.length;
		while(_g1 < _g) {
			var i = _g1++;
			var i1 = intf[i];
			if(i1 == cl || js_Boot.__interfLoop(i1,cl)) return true;
		}
	}
	return js_Boot.__interfLoop(cc.__super__,cl);
};
js_Boot.__instanceof = function(o,cl) {
	if(cl == null) return false;
	switch(cl) {
	case Int:
		return (o|0) === o;
	case Float:
		return typeof(o) == "number";
	case Bool:
		return typeof(o) == "boolean";
	case String:
		return typeof(o) == "string";
	case Array:
		return (o instanceof Array) && o.__enum__ == null;
	case Dynamic:
		return true;
	default:
		if(o != null) {
			if(typeof(cl) == "function") {
				if(o instanceof cl) return true;
				if(js_Boot.__interfLoop(js_Boot.getClass(o),cl)) return true;
			} else if(typeof(cl) == "object" && js_Boot.__isNativeObj(cl)) {
				if(o instanceof cl) return true;
			}
		} else return false;
		if(cl == Class && o.__name__ != null) return true;
		if(cl == Enum && o.__ename__ != null) return true;
		return o.__enum__ == cl;
	}
};
js_Boot.__nativeClassName = function(o) {
	var name = js_Boot.__toStr.call(o).slice(8,-1);
	if(name == "Object" || name == "Function" || name == "Math" || name == "JSON") return null;
	return name;
};
js_Boot.__isNativeObj = function(o) {
	return js_Boot.__nativeClassName(o) != null;
};
js_Boot.__resolveNativeClass = function(name) {
	return $global[name];
};
var RenderSupportHx = function() {
};
RenderSupportHx.__name__ = true;
RenderSupportHx.loadWebFonts = function() {
	var webfontconfig = JSON.parse(haxe_Resource.getString("webfontconfig"));
	webfontconfig.active = function() {
		Errors.print("Web fonts are loaded");
	};
	webfontconfig.loading = function() {
		Errors.print("Loading web fonts...");
	};
	WebFont.load(webfontconfig);
};
RenderSupportHx.oldinit = function() {
	haxe_Timer.delay(function() {
		window.document.body.style.backgroundImage = "none";
	},100);
	var indicator = window.document.getElementById("loading_js_indicator");
	if(null != indicator) indicator.style.display = "none";
	RenderSupportHx.prepareCurrentClip();
	RenderSupportHx.makeTempClip();
	RenderSupportHx.startMouseListening();
	RenderSupportHx.ImageCache = new haxe_ds_StringMap();
	RenderSupportHx.PendingImages = new haxe_ds_StringMap();
	RenderSupportHx.StageScale = 1.0;
	if("1" == Util.getParameter("svg")) {
		Errors.print("Using SVG rendering");
		_$RenderSupportHx_Graphics.svg = true;
	} else {
		Errors.print("Using HTML 5 rendering");
		_$RenderSupportHx_Graphics.svg = false;
	}
	RenderSupportHx.loadWebFonts();
	RenderSupportHx.AriaClips = [];
	RenderSupportHx.AriaDialogsStack = [];
	RenderSupportHx.addGlobalKeyHandlers();
	RenderSupportHx.attachEventListener(RenderSupportHx.getStage(),"focusin",function() {
		var selected = window.document.activeElement;
		if(selected != null && selected.getAttribute("role") != null) {
			var h = RenderSupportHx.getElementHeight(selected);
			var w = RenderSupportHx.getElementWidth(selected);
			var global_scale = RenderSupportHx.getGlobalScale(selected);
			h = h / global_scale.scale_y;
			w = w / global_scale.scale_x;
			selected.style.height = "" + h + "px";
			selected.style.width = "" + w + "px";
		}
	});
	var receiveMessage = function(e) {
		var hasNestedWindow = null;
		hasNestedWindow = function(iframe,win) {
			try {
				if(iframe.contentWindow == win) return true;
				var iframes = iframe.contentWindow.document.getElementsByTagName("iframe");
				var _g1 = 0;
				var _g = iframes.length;
				while(_g1 < _g) {
					var i = _g1++;
					if(hasNestedWindow(iframes[i],win)) return true;
				}
			} catch( e1 ) {
				haxe_CallStack.lastException = e1;
				if (e1 instanceof js__$Boot_HaxeError) e1 = e1.val;
				Errors.print(e1);
			}
			return false;
		};
		var content_win = e.source;
		var all_iframes = window.document.getElementsByTagName("iframe");
		var _g11 = 0;
		var _g2 = all_iframes.length;
		while(_g11 < _g2) {
			var i1 = _g11++;
			var f = all_iframes[i1];
			if(hasNestedWindow(f,content_win)) {
				f.callflow(["postMessage",e.data]);
				return;
			}
		}
		Errors.report("Warning: unknow message source");
	};
	window.addEventListener("message",receiveMessage);
};
RenderSupportHx.getPixelsPerCm = function() {
	return 37.795275590551178;
};
RenderSupportHx.setHitboxRadius = function(radius) {
	return false;
};
RenderSupportHx.hideWaitMessage = function() {
	try {
		window.document.getElementById("wait_message").style.display = "none";
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
	}
};
RenderSupportHx.updateCSSTransform = function(clip) {
	var transform = "translate(" + Std.string(clip.x) + "px," + Std.string(clip.y) + "px) scale(" + Std.string(clip.scale_x) + "," + Std.string(clip.scale_y) + ") rotate(" + Std.string(clip.rot) + "deg)";
	clip.style.WebkitTransform = transform;
	clip.style.msTransform = transform;
	clip.style.transform = transform;
};
RenderSupportHx.isFirefox = function() {
	var useragent = window.navigator.userAgent;
	return useragent.indexOf("Firefox") >= 0;
};
RenderSupportHx.isWinFirefox = function() {
	var useragent = window.navigator.userAgent;
	return useragent.indexOf("Firefox") >= 0 && useragent.indexOf("Windows") >= 0;
};
RenderSupportHx.isTouchScreen = function() {
	return NativeHx.isTouchScreen();
};
RenderSupportHx.addGlobalKeyHandlers = function() {
	RenderSupportHx.attachEventListener(RenderSupportHx.getStage(),"keydown",function(e) {
		if(e.which == 13 || e.which == 32 || e.which == 113) {
			var active = window.document.activeElement;
			if(active != null && RenderSupportHx.isAriaClip(active)) RenderSupportHx.simulateClickForClip(active);
		} else if(e.ctrlKey && e.which == 38) {
			if(RenderSupportHx.StageScale < 2.0) {
				RenderSupportHx.StageScale = 2.0;
				window.document.body.style.overflow = "auto";
				RenderSupportHx.setClipScaleX(RenderSupportHx.CurrentClip,RenderSupportHx.StageScale);
				RenderSupportHx.setClipScaleY(RenderSupportHx.CurrentClip,RenderSupportHx.StageScale);
			}
		} else if(e.ctrlKey && e.which == 40) {
			if(RenderSupportHx.StageScale > 1.0) {
				RenderSupportHx.StageScale = 1.0;
				window.document.body.scrollLeft = window.document.body.scrollTop = 0;
				window.document.body.style.overflow = "hidden";
				RenderSupportHx.setClipScaleX(RenderSupportHx.CurrentClip,RenderSupportHx.StageScale);
				RenderSupportHx.setClipScaleY(RenderSupportHx.CurrentClip,RenderSupportHx.StageScale);
			}
		}
	});
};
RenderSupportHx.isAriaClip = function(clip) {
	var role = clip.getAttribute("role");
	return role == "button" || role == "checkbox" || role == "dialog";
};
RenderSupportHx.addAriaClip = function(clip) {
	var role = clip.getAttribute("role");
	if(role == "dialog") RenderSupportHx.AriaDialogsStack.push(clip); else RenderSupportHx.AriaClips.push(clip);
};
RenderSupportHx.removeAriaClip = function(clip) {
	var role = clip.getAttribute("role");
	if(role == "dialog") {
		var x = clip;
		HxOverrides.remove(RenderSupportHx.AriaDialogsStack,x);
	} else {
		var x1 = clip;
		HxOverrides.remove(RenderSupportHx.AriaClips,x1);
	}
};
RenderSupportHx.simulateClickForClip = function(clip) {
	RenderSupportHx.MouseX = RenderSupportHx.getElementX(clip) + 2.0;
	RenderSupportHx.MouseY = RenderSupportHx.getElementY(clip) + 2.0;
	var stage = RenderSupportHx.getStage();
	if(stage.flowmousedown != null) stage.flowmousedown();
	if(stage.flowmouseup != null) stage.flowmouseup();
};
RenderSupportHx.prepareCurrentClip = function() {
	RenderSupportHx.CurrentClip = window.document.getElementById("flow");
	RenderSupportHx.CurrentClip.x = RenderSupportHx.CurrentClip.y = RenderSupportHx.CurrentClip.rot = 0;
	RenderSupportHx.CurrentClip.scale_x = RenderSupportHx.CurrentClip.scale_y = 1.0;
	var stage = RenderSupportHx.getStage();
	stage.x = stage.y = stage.rot = 0;
	stage.scale_x = stage.scale_y = 1.0;
	if("1" == Util.getParameter("forceredraw")) {
		Errors.report("Turning on workaround for Chrome & FF rendering issue");
		var needs_redraw = false;
		var redraw_timer = new haxe_Timer(500);
		redraw_timer.run = function() {
			if(needs_redraw) {
				RenderSupportHx.CurrentClip.style.display = "none";
				RenderSupportHx.CurrentClip.offsetHeight;
				RenderSupportHx.CurrentClip.style.display = "block";
				needs_redraw = false;
			}
		};
		RenderSupportHx.CurrentClip.addEventListener("DOMNodeInserted",function() {
			needs_redraw = true;
		},true);
	}
};
RenderSupportHx.makeTempClip = function() {
	RenderSupportHx.TempClip = RenderSupportHx.makeClip();
	RenderSupportHx.TempClip.setAttribute("aria-hidden","true");
	RenderSupportHx.TempClip.style.opacity = 0.0;
	RenderSupportHx.TempClip.style.zIndex = -1000;
	window.document.body.appendChild(RenderSupportHx.TempClip);
};
RenderSupportHx.attachEventListener = function(item,event,cb) {
	if(RenderSupportHx.isFirefox() && event == "mousewheel") item.addEventListener("DOMMouseScroll",cb,true); else if(item.addEventListener) item.addEventListener(event,cb,true); else if(item.attachEvent) {
		if(item == window) window.document.attachEvent("on" + event,cb); else item.attachEvent("on" + event,cb);
	}
};
RenderSupportHx.detachEventListener = function(item,event,cb) {
	item.removeEventListener(event,cb,false);
};
RenderSupportHx.startMouseListening = function() {
	if(!RenderSupportHx.isTouchScreen()) RenderSupportHx.attachEventListener(window,"mousemove",function(e) {
		RenderSupportHx.MouseX = e.clientX + window.pageXOffset;
		RenderSupportHx.MouseY = e.clientY + window.pageYOffset;
	}); else {
		RenderSupportHx.attachEventListener(window,"touchmove",function(e1) {
			if(e1.touches.length != 1) return;
			RenderSupportHx.MouseX = e1.touches[0].clientX + window.pageXOffset;
			RenderSupportHx.MouseY = e1.touches[0].clientY + window.pageYOffset;
		});
		RenderSupportHx.attachEventListener(window,"touchstart",function(e2) {
			if(e2.touches.length != 1) return;
			RenderSupportHx.MouseX = e2.touches[0].clientX + window.pageXOffset;
			RenderSupportHx.MouseY = e2.touches[0].clientY + window.pageYOffset;
		});
	}
};
RenderSupportHx.setSelectable = function(element,selectable) {
	if(selectable) {
		element.style.WebkitUserSelect = "text";
		element.style.MozUserSelect = "text";
		element.style.MsUserSelect = "text";
	} else {
		element.style.WebkitUserSelect = "none";
		element.style.MozUserSelect = "none";
		element.style.MsUserSelect = "none";
	}
};
RenderSupportHx.getElementWidth = function(el) {
	var width = el.getBoundingClientRect().width;
	var childs = el.children;
	if(childs == null) return width;
	var _g = 0;
	while(_g < childs.length) {
		var c = childs[_g];
		++_g;
		var cw;
		cw = RenderSupportHx.getElementWidth(c) + (c.x != null?c.x:0.0);
		if(cw > width) width = cw;
	}
	return width;
};
RenderSupportHx.getElementHeight = function(el) {
	var height = el.getBoundingClientRect().height;
	var childs = el.children;
	if(childs == null) return height;
	var _g = 0;
	while(_g < childs.length) {
		var c = childs[_g];
		++_g;
		var ch;
		ch = RenderSupportHx.getElementHeight(c) + (c.y != null?c.y:0.0);
		if(ch > height) height = ch;
	}
	return height;
};
RenderSupportHx.getElementX = function(el) {
	if(el == window) return 0;
	var rect = el.getBoundingClientRect();
	return rect.left;
};
RenderSupportHx.getElementY = function(el) {
	if(el == window) return 0;
	var rect = el.getBoundingClientRect();
	return rect.top;
};
RenderSupportHx.getGlobalScale = function(el) {
	var scale = { scale_x : 1.0, scale_y : 1.0};
	while(el != null && el.scale_x != null && el.scale_y != null) {
		scale.scale_x *= el.scale_x;
		scale.scale_y *= el.scale_y;
		el = el.parentNode;
	}
	return scale;
};
RenderSupportHx.makeCanvasWH = function(w,h) {
	var canvas = window.document.createElement("canvas");
	canvas.height = h;
	canvas.width = w;
	canvas.x0 = canvas.y0 = 0.0;
	return canvas;
};
RenderSupportHx.makeCSSColor = function(color,alpha) {
	return "rgba(" + (color >> 16 & 255) + "," + (color >> 8 & 255) + "," + (color & 255) + "," + alpha + ")";
};
RenderSupportHx.loadImage = function(clip,url,error_cb,metricsFn) {
	var image_loaded = function(cl,mFn,img) {
		mFn(img.width,img.height);
		cl.appendChild(img.cloneNode(false));
	};
	if(RenderSupportHx.ImageCache.exists(url)) image_loaded(clip,metricsFn,RenderSupportHx.ImageCache.get(url)); else if(RenderSupportHx.PendingImages.exists(url)) RenderSupportHx.PendingImages.get(url).push({ c : clip, m : metricsFn, e : error_cb}); else {
		RenderSupportHx.PendingImages.set(url,[{ c : clip, m : metricsFn, e : error_cb}]);
		var img1 = new Image();
		img1.onload = function() {
			RenderSupportHx.ImageCache.set(url,img1);
			var listeners = RenderSupportHx.PendingImages.get(url);
			var _g1 = 0;
			var _g = listeners.length;
			while(_g1 < _g) {
				var i = _g1++;
				var listener = listeners[i];
				image_loaded(listener.c,listener.m,img1);
			}
			RenderSupportHx.PendingImages.remove(url);
		};
		img1.onerror = function() {
			var listeners1 = RenderSupportHx.PendingImages.get(url);
			var _g11 = 0;
			var _g2 = listeners1.length;
			while(_g11 < _g2) {
				var i1 = _g11++;
				listeners1[i1].e();
			}
			RenderSupportHx.PendingImages.remove(url);
		};
		img1.src = url + "?" + StringTools.htmlEscape("" + new Date().getTime());
	}
};
RenderSupportHx.loadSWF = function(clip,url,error_cb,metricsFn) {
	if(StringTools.startsWith(url,"http://www")) {
		var domain_and_path = HxOverrides.substr(url,7,null);
		var pos = domain_and_path.indexOf("/");
		url = HxOverrides.substr(domain_and_path,pos,null);
	}
	var swf = window.document.createElement("OBJECT");
	swf.type = "application/x-shockwave-flash";
	swf.data = url + "?" + StringTools.htmlEscape("" + new Date().getTime());
	clip.appendChild(swf);
	var load_time = new Date().getTime();
	var try_swf_access = null;
	try_swf_access = function() {
		if(new Date().getTime() - load_time > 5000) {
			error_cb();
			return;
		}
		if(swf == null || swf.TGetProperty == null) {
			haxe_Timer.delay(try_swf_access,450);
			return;
		}
		var width = 1.3333333333333333 * swf.TGetProperty("/",8);
		var height = 1.3333333333333333 * swf.TGetProperty("/",9);
		swf.style.width = "" + width + "px";
		swf.style.height = "" + height + "px";
		metricsFn(width,height);
	};
	haxe_Timer.delay(try_swf_access,450);
};
RenderSupportHx.setAccessAttributes = function(clip,properties) {
	var setClipRole = function(role) {
		if(role == "live") {
			clip.setAttribute("aria-live","polite");
			clip.setAttribute("relevant","additions");
			clip.setAttribute("role","aria-live");
		} else clip.setAttribute("role",role);
	};
	var _g = 0;
	while(_g < properties.length) {
		var p = properties[_g];
		++_g;
		var key = p[0];
		var value = p[1];
		if(key == "role") setClipRole(value); else if(key == "tooltip") clip.setAttribute("title",value); else if(key == "tabindex" && value >= 0) {
			if(clip.input) clip.children[0].setAttribute("tabindex",value); else clip.setAttribute("tabindex",value);
		} else if(key == "description") clip.setAttribute("aria-label",value); else if(key == "state") {
			if(value == "checked") clip.setAttribute("aria-checked","true"); else if(value == "unchecked") clip.setAttribute("aria-checked","false");
		} else if(key == "selectable") RenderSupportHx.setSelectable(clip,"true" == value);
	}
};
RenderSupportHx.currentClip = function() {
	return RenderSupportHx.CurrentClip;
};
RenderSupportHx.enableResize = function() {
	RenderSupportHx.hideWaitMessage();
};
RenderSupportHx.getStageWidth = function() {
	return window.innerWidth;
};
RenderSupportHx.getStageHeight = function() {
	return window.innerHeight;
};
RenderSupportHx.makeTextField = function() {
	var field = RenderSupportHx.makeClip();
	RenderSupportHx.TempClip.appendChild(field);
	return field;
};
RenderSupportHx.setStyleByFlowFont = function(style,fontfamily) {
	var fs = FlowFontStyle.fromFlowFont(fontfamily);
	if(fs != null) {
		style.fontFamily = fs.family;
		style.fontWeight = fs.weight;
		style.fontStyle = fs.style;
	} else style.fontFamily = fontfamily;
};
RenderSupportHx.setTextAndStyle = function(textfield,text,fontfamily,fontsize,fillcolour,fillopacity,letterspacing,backgroundcolour,backgroundopacity,forTextinput) {
	fontsize = fontsize * 0.97;
	var style;
	if(textfield.input) style = textfield.children[0].style; else style = textfield.style;
	RenderSupportHx.setStyleByFlowFont(style,fontfamily);
	style.fontSize = "" + Math.floor(fontsize) + "px";
	style.opacity = "" + fillopacity;
	style.color = "#" + StringTools.hex(fillcolour,6);
	if(letterspacing != 0) style.letterSpacing = "" + letterspacing + "px";
	if(backgroundopacity != 0.0) style.backgroundColor = "#" + StringTools.hex(backgroundcolour,6);
	textfield.font_size = fontsize;
	if(textfield.input) {
		if(textfield.children[0].value != text) textfield.children[0].value = text;
	} else {
		if(textfield.innerHTML != text) textfield.innerHTML = text;
		RenderSupportHx.patchTextFormatting(textfield);
	}
	return null;
};
RenderSupportHx.patchTextFormatting = function(node) {
	if(node.tagName == "FONT") {
		node.style.fontSize = Std.string(node.size) + "px";
		node.size = "";
		RenderSupportHx.setStyleByFlowFont(node.style,node.face);
		node.face = "";
	}
	var childs = node.children;
	if(childs.length == 0) {
		node.innerHTML = StringTools.replace(node.innerHTML," ","&nbsp;");
		node.innerHTML = StringTools.replace(node.innerHTML,"\n","<br>");
	} else {
		var _g = 0;
		while(_g < childs.length) {
			var c = childs[_g];
			++_g;
			RenderSupportHx.patchTextFormatting(c);
		}
	}
};
RenderSupportHx.setAdvancedText = function(textfield,sharpness,antialiastype,gridfittype) {
};
RenderSupportHx.makeVideo = function(width,height,metricsFn,durationFn) {
	var ve = window.document.createElement("VIDEO");
	if(width > 0.0) ve.width = width;
	if(height > 0.0) ve.height = height;
	ve.addEventListener("loadedmetadata",function(e) {
		durationFn(ve.duration);
		metricsFn(ve.videoWidth,ve.videoHeight);
	},false);
	return [ve,ve];
};
RenderSupportHx.setVideoVolume = function(str,volume) {
	str.volume = volume;
};
RenderSupportHx.setVideoLooping = function(str,loop) {
};
RenderSupportHx.setVideoControls = function(str,controls) {
};
RenderSupportHx.setVideoSubtitle = function(str,text,size,color) {
};
RenderSupportHx.playVideo = function(str,filename,startPaused) {
	str.src = filename;
	if(!startPaused) str.play();
};
RenderSupportHx.seekVideo = function(str,seek) {
	str.currentTime = seek;
};
RenderSupportHx.getVideoPosition = function(str) {
	return str.currentTime;
};
RenderSupportHx.pauseVideo = function(str) {
	str.pause();
};
RenderSupportHx.resumeVideo = function(str) {
	str.play();
};
RenderSupportHx.closeVideo = function(str) {
};
RenderSupportHx.getTextFieldWidth = function(textfield) {
	if(textfield.input == true) return textfield.width; else return textfield.offsetWidth;
};
RenderSupportHx.setTextFieldWidth = function(textfield,width) {
	if(textfield.input) {
		textfield.width = width;
		textfield.children[0].style.width = "" + width + "px";
	}
};
RenderSupportHx.getTextFieldHeight = function(textfield) {
	if(textfield.input == true) return textfield.height; else return textfield.offsetHeight;
};
RenderSupportHx.setTextFieldHeight = function(textfield,height) {
	if(textfield.input) {
		textfield.height = height;
		textfield.children[0].style.height = "" + height + "px";
	}
};
RenderSupportHx.setAutoAlign = function(textfield,autoalign) {
	var input_;
	if(textfield.input) input_ = textfield.children[0]; else input_ = textfield;
	switch(autoalign) {
	case "AutoAlignLeft":
		input_.style.textAlign = "left";
		break;
	case "AutoAlignRight":
		input_.style.textAlign = "right";
		break;
	case "AutoAlignCenter":
		input_.style.textAlign = "center";
		break;
	case "AutoAlignNone":
		input_.style.textAlign = "none";
		break;
	default:
		input_.style.textAlign = "left";
	}
};
RenderSupportHx.setTextInput = function(textfield) {
	var input = window.document.createElement("INPUT");
	input.type = "text";
	textfield.input = true;
	textfield.appendChild(input);
};
RenderSupportHx.setTextInputType = function(textfield,type) {
	if(textfield.input) textfield.children[0].type = type;
};
RenderSupportHx.setTabIndex = function(textfield,index) {
	if(index >= 0) {
		if(textfield.input) textfield.children[0].setAttribute("tabindex",index); else textfield.setAttribute("tabindex",index);
	}
};
RenderSupportHx.getContent = function(textfield) {
	if(textfield.input) return textfield.children[0].value; else return textfield.innerHTML;
};
RenderSupportHx.getCursorPosition = function(textfield) {
	return RenderSupportHx.getCaret(textfield.children[0]);
};
RenderSupportHx.getCaret = function(el) {
	if(el.selectionStart) return el.selectionStart; else if(window.document.selection) {
		el.focus();
		var r = window.document.selection.createRange();
		if(r == null) return 0;
		var re = el.createTextRange();
		var rc = re.duplicate();
		re.moveToBookmark(r.getBookmark());
		rc.setEndPoint("EndToStart",re);
		return rc.text.length;
	}
	return 0;
};
RenderSupportHx.getFocus = function(clip) {
	var item;
	if(clip.input) item = clip.children[0]; else item = clip.focus();
	return window.document.activeElement == item;
};
RenderSupportHx.getScrollV = function(textfield) {
	return 0;
};
RenderSupportHx.setScrollV = function(textfield,suggestedPosition) {
};
RenderSupportHx.getBottomScrollV = function(textfield) {
	return 0;
};
RenderSupportHx.getNumLines = function(textfield) {
	return 0;
};
RenderSupportHx.setFocus = function(clip,focus) {
	haxe_Timer.delay(function() {
		var item;
		if(clip.input) item = clip.children[0]; else item = clip;
		if(focus) item.focus(); else item.blur();
	},10);
};
RenderSupportHx.setMultiline = function(clip,multiline) {
	if(clip.input && multiline && !clip.multiline) {
		clip.removeChild(clip.children[0]);
		var textarea = window.document.createElement("TEXTAREA");
		if(clip.width) textarea.style.width = "" + Std.string(clip.width) + "px";
		if(clip.height) textarea.style.height = "" + Std.string(clip.height) + "px";
		clip.appendChild(textarea);
		clip.multiline = true;
	}
};
RenderSupportHx.setWordWrap = function(clip,wordWrap) {
};
RenderSupportHx.getSelectionStart = function(textfield) {
	if(textfield.input == true) return textfield.children[0].selectionStart; else return 0;
};
RenderSupportHx.getSelectionEnd = function(textfield) {
	if(textfield.input == true) return textfield.children[0].selectionEnd; else return 0;
};
RenderSupportHx.setSelection = function(textfield,start,end) {
	if(textfield.input == true) haxe_Timer.delay(function() {
		if(window.document.activeElement == textfield.children[0]) textfield.children[0].setSelectionRange(start,end);
	},120);
};
RenderSupportHx.setReadOnly = function(textfield,readOnly) {
	if(textfield.input == true) textfield.children[0].disabled = readOnly;
};
RenderSupportHx.setMaxChars = function(textfield,maxChars) {
	if(textfield.input) textfield.children[0].maxLength = maxChars;
};
RenderSupportHx.addChild = function(parent,child) {
	if(child == null || parent == null) return;
	parent.appendChild(child);
	if(RenderSupportHx.isAriaClip(child)) RenderSupportHx.addAriaClip(child);
};
RenderSupportHx.removeChild = function(parent,child) {
	try {
		if(RenderSupportHx.isAriaClip(child)) RenderSupportHx.removeAriaClip(child);
		parent.removeChild(child);
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
	}
};
RenderSupportHx.makeClip = function() {
	var clip = window.document.createElement("div");
	clip.x = 0.0;
	clip.y = 0.0;
	clip.scale_x = 1.0;
	clip.scale_y = 1.0;
	clip.rot = 0.0;
	return clip;
};
RenderSupportHx.setClipCallstack = function(clip,callstack) {
};
RenderSupportHx.setClipX = function(clip,x) {
	if(clip.x != x) {
		clip.x = x;
		RenderSupportHx.updateCSSTransform(clip);
	}
};
RenderSupportHx.setClipY = function(clip,y) {
	if(clip.y != y) {
		clip.y = y;
		RenderSupportHx.updateCSSTransform(clip);
	}
};
RenderSupportHx.setClipScaleX = function(clip,scale_x) {
	if(clip.iframe != null) {
		if(RenderSupportHx.isIOS()) clip.style.width = scale_x * 100.0 + "px";
		clip.iframe.width = scale_x * 100.0;
	} else if(clip.scale_x != scale_x) {
		clip.scale_x = scale_x;
		RenderSupportHx.updateCSSTransform(clip);
	}
};
RenderSupportHx.setClipScaleY = function(clip,scale_y) {
	if(clip.iframe != null) {
		if(RenderSupportHx.isIOS()) clip.style.height = scale_y * 100.0 + "px";
		clip.iframe.height = scale_y * 100.0;
	} else if(clip.scale_y != scale_y) {
		clip.scale_y = scale_y;
		RenderSupportHx.updateCSSTransform(clip);
	}
};
RenderSupportHx.setClipRotation = function(clip,r) {
	if(r != clip.rot) {
		clip.rot = r;
		RenderSupportHx.updateCSSTransform(clip);
	}
};
RenderSupportHx.setClipAlpha = function(clip,a) {
	clip.style.opacity = a;
	if(a <= 0.01) clip.className = "hiddenByAlpha"; else if(clip.className == "hiddenByAlpha") clip.className = "";
};
RenderSupportHx.setClipMask = function(clip,mask) {
	mask.style.display = "none";
};
RenderSupportHx.getStage = function() {
	return window;
};
RenderSupportHx.addKeyEventListener = function(clip,event,fn) {
	var keycb = function(e) {
		var shift = e.shiftKey;
		var alt = e.altKey;
		var ctrl = e.ctrlKey;
		var s = "";
		if(e.which == 13) {
			var active = window.document.activeElement;
			if(active != null && RenderSupportHx.isAriaClip(active)) return;
			s = "enter";
		} else if(e.which == 27) s = "esc"; else if(e.which == 9) s = "tab"; else if(e.which == 16) s = "shift"; else if(e.which == 17) s = "ctrl"; else if(e.which == 18) s = "alt"; else if(e.which == 37) s = "left"; else if(e.which == 38) s = "up"; else if(e.which == 39) s = "right"; else if(e.which == 40) s = "down"; else if(e.which >= 112 && e.which <= 123) s = "F" + (e.which - 111); else s = String.fromCharCode(e.which);
		fn(s,ctrl,shift,alt,e.keyCode);
	};
	if(RenderSupportHx.isFirefox() && event == "mousewheel") clip.addEventListener("DOMMouseScroll",keycb,true); else if(clip.addEventListener) clip.addEventListener(event,keycb,true); else if(clip.attachEvent) {
		if(clip == window) window.document.attachEvent("on" + event,keycb); else clip.attachEvent("on" + event,keycb);
	}
	return function() {
		clip.removeEventListener(event,keycb,false);
	};
};
RenderSupportHx.addStreamStatusListener = function(clip,fn) {
	var on_start = function() {
		fn("NetStream.Play.Start");
	};
	var on_stop = function() {
		fn("NetStream.Play.Stop");
	};
	var on_not_found = function() {
		fn("NetStream.Play.StreamNotFound");
	};
	clip.addEventListener("loadeddata",on_start);
	clip.addEventListener("ended",on_stop);
	clip.addEventListener("error",on_not_found);
	return function() {
		clip.removeEventListener("loadeddata",on_start);
		clip.removeEventListener("ended",on_stop);
		clip.removeEventListener("error",on_not_found);
	};
};
RenderSupportHx.addEventListener = function(clip,event,fn) {
	var eventname = "";
	if(event == "click") eventname = "click"; else if(event == "mousedown") eventname = "mousedown"; else if(event == "mouseup") eventname = "mouseup"; else if(event == "mousemove") eventname = "mousemove"; else if(event == "mouseenter") eventname = "mouseover"; else if(event == "mouseleave") eventname = "mouseout"; else if(event == "rollover") eventname = "mouseover"; else if(event == "rollout") eventname = "mouseout"; else if(event == "change") eventname = "input"; else if(event == "focusin") eventname = "focus"; else if(event == "focusout") eventname = "blur"; else if(event == "resize") {
		RenderSupportHx.attachEventListener(window,"resize",fn);
		return function() {
			RenderSupportHx.detachEventListener(window,"resize",fn);
		};
	} else if(event == "scroll") eventname = "scroll"; else {
		Errors.report("Unknown event");
		return function() {
		};
	}
	if(RenderSupportHx.isTouchScreen() && (eventname == "mousedown" || eventname == "mouseup")) {
		if(eventname == "mousedown") {
			var touchstartWrapper = function(e) {
				if(e.touches.length != 1) return;
				fn();
			};
			if(RenderSupportHx.isFirefox() && false) clip.addEventListener("DOMMouseScroll",touchstartWrapper,true); else if(clip.addEventListener) clip.addEventListener("touchstart",touchstartWrapper,true); else if(clip.attachEvent) {
				if(clip == window) window.document.attachEvent("on" + "touchstart",touchstartWrapper); else clip.attachEvent("on" + "touchstart",touchstartWrapper);
			}
			return function() {
				clip.removeEventListener(eventname,touchstartWrapper,false);
			};
		} else {
			var touchendWrapper = function(e1) {
				if(e1.touches.length != 0) return;
				fn();
			};
			if(RenderSupportHx.isFirefox() && false) clip.addEventListener("DOMMouseScroll",touchendWrapper,true); else if(clip.addEventListener) clip.addEventListener("touchend",touchendWrapper,true); else if(clip.attachEvent) {
				if(clip == window) window.document.attachEvent("on" + "touchend",touchendWrapper); else clip.attachEvent("on" + "touchend",touchendWrapper);
			}
			return function() {
				clip.removeEventListener(eventname,touchendWrapper,false);
			};
		}
	} else {
		if(RenderSupportHx.isFirefox() && eventname == "mousewheel") clip.addEventListener("DOMMouseScroll",fn,true); else if(clip.addEventListener) clip.addEventListener(eventname,fn,true); else if(clip.attachEvent) {
			if(clip == window) window.document.attachEvent("on" + eventname,fn); else clip.attachEvent("on" + eventname,fn);
		}
		if(clip == window) {
			if(eventname == "mousedown") clip.flowmousedown = fn; else if(eventname == "mouseup") clip.flowmouseup = fn;
		}
		return function() {
			clip.removeEventListener(eventname,fn,false);
		};
	}
};
RenderSupportHx.addMouseWheelEventListener = function(clip,fn) {
	var wheel_cb = function(event) {
		var delta = 0.0;
		if(event.wheelDelta != null) delta = event.wheelDelta / 120; else if(event.detail != null) delta = -event.detail / 3;
		if(event.preventDefault != null) event.preventDefault();
		fn(delta);
	};
	RenderSupportHx.attachEventListener(window,"mousewheel",wheel_cb);
	return function() {
		RenderSupportHx.detachEventListener(window,"mousewheel",wheel_cb);
	};
};
RenderSupportHx.addFinegrainMouseWheelEventListener = function(clip,f) {
	return RenderSupportHx.addMouseWheelEventListener(clip,function(delta) {
		f(delta,0);
	});
};
RenderSupportHx.hasChild = function(clip,child) {
	var childs = clip.children;
	if(childs != null) {
		var _g = 0;
		while(_g < childs.length) {
			var c = childs[_g];
			++_g;
			if(c == child) return true;
			if(RenderSupportHx.hasChild(c,child)) return true;
		}
	}
	return false;
};
RenderSupportHx.isIOS = function() {
	return window.navigator.userAgent.indexOf("iPhone") != -1 || window.navigator.userAgent.indexOf("iPad") != -1 || window.navigator.userAgent.indexOf("iPod") != -1;
};
RenderSupportHx.getMouseX = function(clip) {
	var gs = RenderSupportHx.getGlobalScale(clip);
	return (RenderSupportHx.MouseX - RenderSupportHx.getElementX(clip)) / gs.scale_x;
};
RenderSupportHx.getMouseY = function(clip) {
	var gs = RenderSupportHx.getGlobalScale(clip);
	return (RenderSupportHx.MouseY - RenderSupportHx.getElementY(clip)) / gs.scale_y;
};
RenderSupportHx.hittest = function(clip,x,y) {
	var hitted = window.document.elementFromPoint(Math.round(x),Math.round(y));
	return hitted == clip || RenderSupportHx.hasChild(clip,hitted);
};
RenderSupportHx.getGraphics = function(clip) {
	return new _$RenderSupportHx_Graphics(clip);
};
RenderSupportHx.setLineStyle = function(graphics,width,color,opacity) {
	graphics.setLineStyle(width,color,opacity);
};
RenderSupportHx.setLineStyle2 = function(graphics,width,color,opacity,pixelHinting) {
	graphics.setLineStyle(width,color,opacity);
};
RenderSupportHx.beginFill = function(graphics,color,opacity) {
	graphics.setSolidFill(color,opacity);
};
RenderSupportHx.beginGradientFill = function(graphics,colors,alphas,offsets,matrix,type) {
	graphics.setGradientFill(colors,alphas,offsets,matrix);
};
RenderSupportHx.setLineGradientStroke = function(graphics,colours,alphas,offsets,matrix) {
};
RenderSupportHx.makeMatrix = function(width,height,rotation,xOffset,yOffset) {
	return [width,height,rotation,xOffset,yOffset];
};
RenderSupportHx.moveTo = function(graphics,x,y) {
	graphics.addGraphOp(GraphOp.MoveTo(x,y));
};
RenderSupportHx.lineTo = function(graphics,x,y) {
	graphics.addGraphOp(GraphOp.LineTo(x,y));
};
RenderSupportHx.curveTo = function(graphics,cx,cy,x,y) {
	graphics.addGraphOp(GraphOp.CurveTo(x,y,cx,cy));
};
RenderSupportHx.endFill = function(graphics) {
	graphics.render();
};
RenderSupportHx.makePicture = function(url,cache,metricsFn,errorFn,onlyDownload) {
	var error_cb = function() {
		errorFn("Error while loading image " + url);
	};
	var clip = RenderSupportHx.makeClip();
	clip.setAttribute("role","img");
	if(HxOverrides.substr(url,url.length - 3,3).toLowerCase() == "swf") {
		var loaad_swf_if_no_png = function() {
			RenderSupportHx.loadSWF(clip,url,error_cb,metricsFn);
		};
		RenderSupportHx.loadImage(clip,StringTools.replace(url,".swf",".png"),loaad_swf_if_no_png,metricsFn);
	} else RenderSupportHx.loadImage(clip,url,error_cb,metricsFn);
	return clip;
};
RenderSupportHx.setCursor = function(clip,cursor) {
	var css_cursor;
	switch(cursor) {
	case "arrow":
		css_cursor = "default";
		break;
	case "auto":
		css_cursor = "auto";
		break;
	case "finger":
		css_cursor = "pointer";
		break;
	case "move":
		css_cursor = "move";
		break;
	case "text":
		css_cursor = "text";
		break;
	default:
		css_cursor = "default";
	}
	window.document.body.style.cursor = css_cursor;
};
RenderSupportHx.getCursor = function(clip) {
	var _g = window.document.body.style.cursor;
	switch(_g) {
	case "default":
		return "arrow";
	case "auto":
		return "auto";
	case "pointer":
		return "finger";
	case "move":
		return "move";
	case "text":
		return "text";
	default:
		return "default";
	}
};
RenderSupportHx.addFilters = function(clip,filters) {
	var filters_value = filters.join(" ");
	clip.style.WebkitFilter = filters_value;
};
RenderSupportHx.makeBevel = function(angle,distance,radius,spread,color1,alpha1,color2,alpha2,inside) {
	return "drop-shadow(-1px -1px #888888)";
	return null;
};
RenderSupportHx.makeBlur = function(radius,spread) {
	return "blur(" + radius + "px)";
	return null;
};
RenderSupportHx.makeDropShadow = function(angle,distance,radius,spread,color,alpha,inside) {
	return "drop-shadow(" + Math.cos(angle) * distance + "px " + Math.sin(angle) * distance + "px " + radius + "px " + spread + "px " + Std.string(RenderSupportHx.makeCSSColor(color,alpha)) + ")";
	return null;
};
RenderSupportHx.makeGlow = function(radius,spread,color,alpha,inside) {
	return "";
	return null;
};
RenderSupportHx.setScrollRect = function(clip,left,top,width,height) {
	clip.style.top = "" + -top + "px";
	clip.style.left = "" + -left + "px";
	clip.rect_top = top;
	clip.rect_left = left;
	clip.rect_right = left + width;
	clip.rect_bottom = top + height;
	clip.style.clip = "rect(" + Std.string(clip.rect_top) + "px," + Std.string(clip.rect_right) + "px," + Std.string(clip.rect_bottom) + "px," + Std.string(clip.rect_left) + "px)";
	return null;
};
RenderSupportHx.getTextMetrics = function(textfield) {
	var font_size = 16.0;
	if(textfield.font_size != null) font_size = textfield.font_size;
	var ascent = 0.9 * font_size;
	var descent = 0.1 * font_size;
	var leading = 0.15 * font_size;
	return [ascent,descent,leading];
};
RenderSupportHx.makeBitmap = function() {
	return null;
	return null;
};
RenderSupportHx.bitmapDraw = function(bitmap,clip,width,height) {
};
RenderSupportHx.getClipVisible = function(clip) {
	if(clip == null) return false;
	var p = clip;
	var stage = RenderSupportHx.getStage();
	while(p != null && p != stage) {
		if(p.style != null && p.style.display == "none") return false;
		p = p.parentNode;
	}
	return true;
};
RenderSupportHx.setClipVisible = function(clip,vis) {
	if(vis) clip.style.display = ""; else clip.style.display = "none";
};
RenderSupportHx.setFullScreenTarget = function(clip) {
};
RenderSupportHx.setFullScreenRectangle = function(x,y,w,h) {
	null;
	return;
};
RenderSupportHx.resetFullScreenTarget = function() {
};
RenderSupportHx.toggleFullScreen = function() {
};
RenderSupportHx.onFullScreen = function(fn) {
	return function() {
	};
};
RenderSupportHx.isFullScreen = function() {
	return false;
};
RenderSupportHx.setWindowTitle = function(title) {
	window.document.title = title;
};
RenderSupportHx.takeSnapshot = function(path) {
};
RenderSupportHx.getScreenPixelColor = function(x,y) {
	return 0;
};
RenderSupportHx.makeWebClip = function(url,domain,useCache,reloadBlock,cb,ondone) {
	var clip = RenderSupportHx.makeClip();
	if(RenderSupportHx.isIOS()) {
		clip.style.webkitOverflowScrolling = "touch";
		clip.style.overflowY = "scroll";
	}
	try {
		window.document.domain = domain;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		Errors.report(e);
	}
	var iframe = window.document.createElement("iframe");
	iframe.width = iframe.height = 100.0;
	iframe.src = url;
	iframe.allowFullscreen = true;
	iframe.frameBorder = "no";
	clip.appendChild(iframe);
	clip.iframe = iframe;
	iframe.callflow = cb;
	iframe.onload = function() {
		try {
			ondone("OK");
			iframe.contentWindow.callflow = cb;
			if(iframe.contentWindow.pushCallflowBuffer) iframe.contentWindow.pushCallflowBuffer();
		} catch( e1 ) {
			haxe_CallStack.lastException = e1;
			if (e1 instanceof js__$Boot_HaxeError) e1 = e1.val;
			Errors.report(e1);
		}
	};
	return clip;
	return null;
};
RenderSupportHx.webClipHostCall = function(clip,name,args) {
	return clip.iframe.contentWindow[name].apply(clip.iframe.contentWindow,args);
	return null;
};
RenderSupportHx.setWebClipZoomable = function(clip,zoomable) {
};
RenderSupportHx.getNumberOfCameras = function() {
	return 0;
};
RenderSupportHx.getCameraInfo = function(id) {
	return "";
};
RenderSupportHx.makeCamera = function(uri,camID,camWidth,camHeight,camFps,vidWidth,vidHeight,recordMode,cbOnReadyForRecording,cbOnFailed) {
	return [null,null];
};
RenderSupportHx.startRecord = function(str,filename,mode) {
};
RenderSupportHx.stopRecord = function(str) {
};
RenderSupportHx.cameraTakePhoto = function(cameraId,additionalInfo,desiredWidth,desiredHeight,compressQuality,fileName) {
};
RenderSupportHx.addGestureListener = function(event,cb) {
	return function() {
	};
};
RenderSupportHx.setInterfaceOrientation = function(orientation) {
};
RenderSupportHx.setUrlHash = function(hash) {
	window.location.hash = hash;
};
RenderSupportHx.getUrlHash = function() {
	return window.location.hash;
	return "";
};
RenderSupportHx.addUrlHashListener = function(cb) {
	var wrapper = function(e) {
		cb(window.location.hash);
	};
	window.addEventListener("hashchange",wrapper);
	return function() {
		window.removeEventListener("hashchanged",wrapper);
	};
	return function() {
	};
};
RenderSupportHx.setGlobalZoomEnabled = function(enabled) {
};
RenderSupportHx.prototype = {
	__class__: RenderSupportHx
};
var FontLoader = function() { };
FontLoader.__name__ = true;
FontLoader.LoadFonts = function(use_dfont,on_done) {
	if(use_dfont) FontLoader.loadDFonts(function() {
		FontLoader.loadWebFonts(on_done);
	}); else FontLoader.loadWebFonts(on_done);
};
FontLoader.loadWebFonts = function(onDone) {
	if(typeof(WebFont) != "undefined") {
		var webfontconfig = JSON.parse(haxe_Resource.getString("webfontconfig"));
		if(webfontconfig != null) {
			webfontconfig.active = onDone;
			webfontconfig.inactive = onDone;
			webfontconfig.loading = function() {
				Errors.print("Loading web fonts...");
			};
			WebFont.load(webfontconfig);
		}
	} else {
		Errors.print("WebFont is not defined");
		onDone();
	}
};
FontLoader.loadDFonts = function(onDone) {
	var dfonts = [];
	var uniqueDFonts = [];
	var dfontsResource = haxe_Resource.getString("dfonts");
	if(dfontsResource != null) {
		dfonts = JSON.parse(dfontsResource);
		var _g = 0;
		while(_g < dfonts.length) {
			var dfont = dfonts[_g];
			++_g;
			if(dfont.url == null) dfont.url = "dfontjs/" + Std.string(dfont.name) + "/index.json";
		}
	} else if(dfonts.length == 0) Errors.print("Warning: No dfonts resource!");
	var fontnamesStr = window.dfontnames;
	if(fontnamesStr != null) {
		var fontnames;
		var _g1 = [];
		var _g11 = 0;
		var _g2 = fontnamesStr.split("\n");
		while(_g11 < _g2.length) {
			var fn = _g2[_g11];
			++_g11;
			_g1.push(StringTools.trim(fn));
		}
		fontnames = _g1;
		fontnames = fontnames.filter(function(s) {
			return s != "";
		});
		var extraDFonts;
		var _g12 = [];
		var _g21 = 0;
		while(_g21 < fontnames.length) {
			var fn1 = fontnames[_g21];
			++_g21;
			_g12.push({ name : fn1, url : "dfontjs/" + fn1 + "/index.json"});
		}
		extraDFonts = _g12;
		if(window.dfonts_override != null) dfonts = extraDFonts; else dfonts = dfonts.concat(extraDFonts);
	}
	var fontURLs;
	var _g3 = new haxe_ds_StringMap();
	var _g13 = 0;
	while(_g13 < dfonts.length) {
		var f = dfonts[_g13];
		++_g13;
		var key = f.name;
		var value = f.url;
		if(__map_reserved[key] != null) _g3.setReserved(key,value); else _g3.h[key] = value;
	}
	fontURLs = _g3;
	Errors.print("Loading dfield fonts...");
	var loader = new PIXI.loaders.Loader();
	var $it0 = fontURLs.keys();
	while( $it0.hasNext() ) {
		var name = $it0.next();
		loader.add(name,__map_reserved[name] != null?fontURLs.getReserved(name):fontURLs.h[name]);
	}
	loader.once("complete",onDone);
	loader.load();
};
var _$RenderSupportJSPixi_NativeWidgetClip = function() {
	PIXI.Container.call(this);
};
_$RenderSupportJSPixi_NativeWidgetClip.__name__ = true;
_$RenderSupportJSPixi_NativeWidgetClip.__super__ = PIXI.Container;
_$RenderSupportJSPixi_NativeWidgetClip.prototype = $extend(PIXI.Container.prototype,{
	getWidth: function() {
		return 0.0;
	}
	,getHeight: function() {
		return 0.0;
	}
	,onStageMouseDown: function(global_mouse_pos) {
	}
	,updateNativeWidget: function() {
		if(this.parent == null && this.nativeWidget.parentNode != null) this.deleteNativeWidget(); else {
			if(this.worldVisible) {
				var lt = this.toGlobal(new PIXI.Point(0.0,0.0));
				this.nativeWidget.style.left = "" + lt.x + "px";
				this.nativeWidget.style.top = "" + lt.y + "px";
				var rb = this.toGlobal(new PIXI.Point(this.getWidth(),this.getHeight()));
				this.nativeWidget.style.width = "" + (rb.x - lt.x) + "px";
				this.nativeWidget.style.height = "" + (rb.y - lt.y) + "px";
				this.nativeWidget.style.opacity = this.worldAlpha;
			}
			if(this.worldVisible) this.nativeWidget.style.display = ""; else this.nativeWidget.style.display = "none";
		}
	}
	,createNativeWidget: function(node_name) {
		this.nativeWidget = window.document.createElement(node_name);
		window.document.body.appendChild(this.nativeWidget);
		this.nativeWidget.style.position = "fixed";
		RenderSupportJSPixi.registerNativeWidgetClip(this);
	}
	,deleteNativeWidget: function() {
		window.document.body.removeChild(this.nativeWidget);
		RenderSupportJSPixi.unregisterNativeWidgetClip(this);
		this.nativeWidget = null;
	}
	,addNativeEventListener: function(event,fn) {
		var _g = this;
		this.nativeWidget.addEventListener(event,fn);
		return function() {
			_g.nativeWidget.removeEventListener(event,fn);
		};
	}
	,setFocus: function(focus) {
		var _g = this;
		haxe_Timer.delay(function() {
			if(_g.nativeWidget != null) {
				if(focus) _g.nativeWidget.focus(); else _g.nativeWidget.blur();
			}
		},500);
	}
	,getFocus: function() {
		return this.nativeWidget != null && window.document.activeElement == this.nativeWidget;
	}
	,requestFullScreen: function() {
		if(this.nativeWidget != null) {
			if(this.nativeWidget.requestFullscreen != null) this.nativeWidget.requestFullscreen(); else if(this.nativeWidget.mozRequestFullScreen != null) this.nativeWidget.mozRequestFullScreen(); else if(this.nativeWidget.webkitRequestFullscreen != null) this.nativeWidget.webkitRequestFullscreen();
		}
	}
	,exitFullScreen: function() {
		if(this.nativeWidget != null) {
			if(this.nativeWidget.exitFullScreen != null) this.nativeWidget.exitFullScreen(); else if(this.nativeWidget.mozExitFullScreen != null) this.nativeWidget.mozExitFullScreen(); else if(this.nativeWidget.webkitExitFullScreen != null) this.nativeWidget.webkitExitFullScreen();
		}
	}
	,__class__: _$RenderSupportJSPixi_NativeWidgetClip
});
var _$RenderSupportJSPixi_TextField = function() {
	this.TextInputFiltersInitialized = false;
	this.TextInputFilters = [];
	this.background = null;
	this.init_text = null;
	this.type = "text";
	this.multiline = false;
	this.fillOpacity = 1.0;
	this.backgroundOpacity = 0.0;
	this.backgroundColor = 0;
	this.fontSize = 16.0;
	this.fieldWidth = null;
	this.fieldHeight = null;
	_$RenderSupportJSPixi_NativeWidgetClip.call(this);
};
_$RenderSupportJSPixi_TextField.__name__ = true;
_$RenderSupportJSPixi_TextField.__super__ = _$RenderSupportJSPixi_NativeWidgetClip;
_$RenderSupportJSPixi_TextField.prototype = $extend(_$RenderSupportJSPixi_NativeWidgetClip.prototype,{
	updateNativeWidget: function() {
		_$RenderSupportJSPixi_NativeWidgetClip.prototype.updateNativeWidget.call(this);
		if(this.nativeWidget != null && this.worldVisible) {
			var one = this.toGlobal(_$RenderSupportJSPixi_TextField.One);
			var zerro = this.toGlobal(_$RenderSupportJSPixi_TextField.Zerro);
			var scale_y = one.y - zerro.y;
			this.nativeWidget.style.fontSize = "" + this.fontSize * scale_y + "px";
		}
	}
	,getDescription: function() {
		if(this.nativeWidget != null) return "TextField (text = \"" + Std.string(this.nativeWidget.value) + "\")"; else return "TextField (text = \"" + this.init_text + "\")";
	}
	,isInput: function() {
		return this.nativeWidget != null;
	}
	,onStageMouseDown: function(global_mouse_pos) {
		var local = this.toLocal(global_mouse_pos);
		if(local.x > 0.0 && local.y > 0.0 && local.x < this.getWidth() && local.y < this.getHeight()) this.setFocus(true);
	}
	,setTextAndStyle: function(text,fontfamily,fontsize,fillcolor,fillopacity,backgroundcolour,backgroundopacity) {
		this.fontSize = fontsize;
		this.init_text = text;
		this.backgroundColor = backgroundcolour;
		this.backgroundOpacity = backgroundopacity;
		this.fillOpacity = fillopacity;
		if(this.nativeWidget != null) {
			this.nativeWidget.value = text;
			this.nativeWidget.style.fontSize = "" + fontsize + "px";
			var style = FlowFontStyle.fromFlowFont(fontfamily);
			this.nativeWidget.style.fontFamily = style.family;
			this.nativeWidget.style.fontWeight = style.weight;
			this.nativeWidget.style.fontStyle = style.style;
			if(backgroundopacity > 0.0) this.nativeWidget.style.backgroundColor = "#" + StringTools.hex(backgroundcolour,6);
		}
	}
	,setGLText: function(text) {
	}
	,hideGLText: function() {
		this.setRectMask(0.0,0.0);
	}
	,showGLText: function() {
		this.setRectMask(this.getWidth(),this.getHeight());
	}
	,setRectMask: function(width,height) {
		if(this.mask != null) this.removeChild(this.mask);
		this.mask = new PIXI.Graphics();
		this.mask.beginFill(16777215);
		this.mask.drawRect(0.0,0.0,width,height);
		this.mask.endFill();
		this.addChild(this.mask);
	}
	,setTextInput: function() {
		var _g = this;
		this.createNativeWidget("input");
		this.nativeWidget.style.zIndex = -1;
		this.nativeWidget.onfocus = function(e) {
			RenderSupportJSPixi.PixiStageChanged = true;
			_g.hideGLText();
			_g.nativeWidget.style.zIndex = 1;
		};
		this.nativeWidget.onblur = function(e1) {
			RenderSupportJSPixi.PixiStageChanged = true;
			if(_g.nativeWidget.type == "password") _g.setGLText(_g.getBulletsString(_g.nativeWidget.value.length)); else _g.setGLText(_g.nativeWidget.value);
			_g.showGLText();
			_g.nativeWidget.style.zIndex = -1;
		};
		var old_cursor = "auto";
		this.on("mouseover",function() {
			old_cursor = window.document.body.style.cursor;
			window.document.body.style.cursor = "text";
		});
		this.on("mouseout",function() {
			window.document.body.style.cursor = old_cursor;
		});
	}
	,setTextInputType: function(type) {
		this.nativeWidget.type = type;
	}
	,setMultiline: function() {
		if(this.multiline) return;
		this.multiline = true;
		var textarea = window.document.createElement("textarea");
		textarea.style.zIndex = -1;
		textarea.style.resize = "none";
		textarea.style.wordWrap = "normal";
		textarea.style.lineHeight = this.fontSize + "px";
		textarea.style.fontSize = this.nativeWidget.style.fontSize;
		textarea.value = this.nativeWidget.value;
		textarea.onfocus = this.nativeWidget.onfocus;
		textarea.onblur = this.nativeWidget.onblur;
		this.setWordWrap();
		window.document.body.removeChild(this.nativeWidget);
		this.nativeWidget = textarea;
		window.document.body.appendChild(this.nativeWidget);
	}
	,setWordWrap: function() {
	}
	,setWordWrapWidth: function(width) {
	}
	,getWidth: function() {
		if(this.fieldWidth != null) return this.fieldWidth;
		return this.getLocalBounds().width;
	}
	,getHeight: function() {
		if(this.fieldHeight != null) return this.fieldHeight;
		return this.getLocalBounds().height;
	}
	,setWidth: function(w) {
		this.fieldWidth = w;
		if(this.fieldHeight != null && this.nativeWidget != null) this.setRectMask(this.fieldWidth,this.fieldHeight);
		this.setWordWrapWidth(this.fieldWidth);
	}
	,setHeight: function(h) {
		this.fieldHeight = h;
		if(this.fieldWidth != null && this.nativeWidget != null) this.setRectMask(this.fieldWidth,this.fieldHeight);
	}
	,setAutoAlign: function(align) {
		switch(align) {
		case "AutoAlignLeft":
			this.nativeWidget.style.textAlign = "left";
			break;
		case "AutoAlignRight":
			this.nativeWidget.style.textAlign = "right";
			break;
		case "AutoAlignCenter":
			this.nativeWidget.style.textAlign = "center";
			break;
		case "AutoAlignNone":
			this.nativeWidget.style.textAlign = "none";
			break;
		default:
			this.nativeWidget.style.textAlign = "left";
		}
	}
	,setTabIndex: function(index) {
		this.nativeWidget.tabIndex = index;
	}
	,getContent: function() {
		if(this.nativeWidget != null) return this.nativeWidget.value; else return this.init_text;
	}
	,getCursorPosition: function() {
		try {
			if(this.nativeWidget.selectionStart != null) return this.nativeWidget.selectionStart;
		} catch( e ) {
			haxe_CallStack.lastException = e;
			if (e instanceof js__$Boot_HaxeError) e = e.val;
		}
		if(window.document.selection != null) {
			this.nativeWidget.focus();
			var r = window.document.selection.createRange();
			if(r == null) return 0;
			var re = this.nativeWidget.createTextRange();
			var rc = re.duplicate();
			re.moveToBookmark(r.getBookmark());
			rc.setEndPoint("EndToStart",re);
			return rc.text.length;
		}
		return 0;
	}
	,getSelectionStart: function() {
		try {
			return this.nativeWidget.selectionStart;
		} catch( e ) {
			haxe_CallStack.lastException = e;
			if (e instanceof js__$Boot_HaxeError) e = e.val;
			return 0;
		}
	}
	,getSelectionEnd: function() {
		try {
			return this.nativeWidget.selectionEnd;
		} catch( e ) {
			haxe_CallStack.lastException = e;
			if (e instanceof js__$Boot_HaxeError) e = e.val;
			return 0;
		}
	}
	,setSelection: function(start,end) {
		var _g = this;
		haxe_Timer.delay(function() {
			if(window.document.activeElement == _g.nativeWidget) try {
				_g.nativeWidget.setSelectionRange(start,end);
			} catch( e ) {
				haxe_CallStack.lastException = e;
				if (e instanceof js__$Boot_HaxeError) e = e.val;
			}
		},120);
	}
	,setReadOnly: function(read_only) {
		this.nativeWidget.disabled = read_only;
	}
	,setMaxChars: function(max_charts) {
		this.nativeWidget.maxLength = max_charts;
	}
	,addTextInputFilter: function(filter) {
		var _g = this;
		this.TextInputFilters.push(filter);
		this.initTextInputFilters();
		return function() {
			HxOverrides.remove(_g.TextInputFilters,filter);
		};
	}
	,initTextInputFilters: function() {
		var _g = this;
		if(this.TextInputFiltersInitialized) return;
		this.TextInputFiltersInitialized = true;
		var old_value = this.nativeWidget.value;
		var oninput = function(e) {
			var new_value = _g.nativeWidget.value;
			var _g1 = 0;
			var _g2 = _g.TextInputFilters;
			while(_g1 < _g2.length) {
				var f = _g2[_g1];
				++_g1;
				if(!f(new_value)) {
					_g.nativeWidget.value = old_value;
					return;
				}
			}
			old_value = new_value;
		};
		this.nativeWidget.addEventListener("input",oninput);
	}
	,getTextMetrics: function() {
		var ascent = 0.9 * this.fontSize;
		var descent = 0.1 * this.fontSize;
		var leading = 0.15 * this.fontSize;
		return [ascent,descent,leading];
	}
	,getBulletsString: function(l) {
		var bullet = String.fromCharCode(8226);
		var i = 0;
		var ret = "";
		var _g = 0;
		while(_g < l) {
			var i1 = _g++;
			ret += bullet;
		}
		return ret;
	}
	,setTextBackground: function() {
		if(this.background != null) {
			this.removeChild(this.background);
			this.background = null;
		}
		if(this.backgroundOpacity > 0.0) {
			var rect = new PIXI.Graphics();
			var text_bounds = this.getLocalBounds();
			rect.beginFill(this.backgroundColor,this.backgroundOpacity);
			rect.drawRect(0.0,0.0,text_bounds.width,text_bounds.height);
			rect.endFill();
			this.addChildAt(rect,0);
			this.background = rect;
		}
	}
	,__class__: _$RenderSupportJSPixi_TextField
});
var _$RenderSupportJSPixi_VideoClip = function(width,height,metricsFn,durationFn) {
	this.StartPaused = false;
	this.SpriteCreated = false;
	this.videoHeight = 0;
	this.videoWidth = 0;
	var _g = this;
	_$RenderSupportJSPixi_NativeWidgetClip.call(this);
	this.createNativeWidget("video");
	var strict_size = width > 0.0 && height > 0.0;
	if(strict_size) {
		this.videoWidth = width;
		this.nativeWidget.width = this.videoWidth;
		this.videoHeight = height;
		this.nativeWidget.height = this.videoHeight;
		metricsFn(this.videoWidth,this.videoHeight);
	}
	this.nativeWidget.addEventListener("loadedmetadata",function(e) {
		durationFn(_g.nativeWidget.duration);
		if(!strict_size) {
			_g.videoWidth = _g.nativeWidget.videoWidth;
			_g.videoHeight = _g.nativeWidget.videoHeight;
			metricsFn(_g.videoWidth,_g.videoHeight);
			_g.updateNativeWidget();
		}
		if(_$RenderSupportJSPixi_VideoClip.UsePixiTextures && !_g.SpriteCreated) {
			var video_texture = PIXI.Texture.fromVideo(_g.nativeWidget);
			var video_sprite = new PIXI.Sprite(video_texture);
			video_sprite.width = _g.videoWidth;
			video_sprite.height = _g.videoHeight;
			_g.addChild(video_sprite);
			_g.SpriteCreated = true;
			if(_g.StartPaused) video_texture.baseTexture.on("loaded",function() {
				_g.pauseVideo();
			});
		}
	},false);
};
_$RenderSupportJSPixi_VideoClip.__name__ = true;
_$RenderSupportJSPixi_VideoClip.NeedsDrawing = function() {
	return _$RenderSupportJSPixi_VideoClip.UsePixiTextures && _$RenderSupportJSPixi_VideoClip.VideosOnStage > 0;
};
_$RenderSupportJSPixi_VideoClip.__super__ = _$RenderSupportJSPixi_NativeWidgetClip;
_$RenderSupportJSPixi_VideoClip.prototype = $extend(_$RenderSupportJSPixi_NativeWidgetClip.prototype,{
	updateNativeWidget: function() {
		if(!_$RenderSupportJSPixi_VideoClip.UsePixiTextures) _$RenderSupportJSPixi_NativeWidgetClip.prototype.updateNativeWidget.call(this); else if(this.parent == null && this.nativeWidget.parentNode != null) this.deleteNativeWidget();
	}
	,createNativeWidget: function(node) {
		_$RenderSupportJSPixi_NativeWidgetClip.prototype.createNativeWidget.call(this,node);
		if(_$RenderSupportJSPixi_VideoClip.UsePixiTextures) this.nativeWidget.style.display = "none";
		++_$RenderSupportJSPixi_VideoClip.VideosOnStage;
	}
	,deleteNativeWidget: function() {
		_$RenderSupportJSPixi_NativeWidgetClip.prototype.deleteNativeWidget.call(this);
		--_$RenderSupportJSPixi_VideoClip.VideosOnStage;
	}
	,getDescription: function() {
		return "VideoClip (url = " + Std.string(this.nativeWidget.url) + ")";
	}
	,setVolume: function(volume) {
		this.nativeWidget.volume = volume;
	}
	,playVideo: function(filename,startPaused) {
		this.nativeWidget.src = filename;
		this.StartPaused = startPaused;
		if(!this.StartPaused) this.nativeWidget.play();
	}
	,setCurrentTime: function(time) {
		this.nativeWidget.currentTime = time;
	}
	,getCurrentTime: function() {
		return this.nativeWidget.currentTime;
	}
	,pauseVideo: function() {
		this.nativeWidget.pause();
	}
	,resumeVideo: function() {
		this.nativeWidget.play();
	}
	,addStreamStatusListener: function(fn) {
		var _g = this;
		var on_start = function() {
			fn("NetStream.Play.Start");
		};
		var on_stop = function() {
			fn("NetStream.Play.Stop");
		};
		var on_not_found = function() {
			fn("NetStream.Play.StreamNotFound");
		};
		this.nativeWidget.addEventListener("loadeddata",on_start);
		this.nativeWidget.addEventListener("ended",on_stop);
		this.nativeWidget.addEventListener("error",on_not_found);
		return function() {
			_g.nativeWidget.removeEventListener("loadeddata",on_start);
			_g.nativeWidget.removeEventListener("ended",on_stop);
			_g.nativeWidget.removeEventListener("error",on_not_found);
		};
	}
	,getWidth: function() {
		return this.videoWidth;
	}
	,getHeight: function() {
		return this.videoHeight;
	}
	,__class__: _$RenderSupportJSPixi_VideoClip
});
var _$RenderSupportJSPixi_DebugClipsTree = function() {
	this.UpdateTimer = null;
	this.ClipBoundsRect = null;
	this.DebugWin = null;
	this.TreeDiv = null;
	var _g = this;
	this.DebugWin = window.open("","","width=800,height=500");
	var expandall_button = window.document.createElement("button");
	expandall_button.innerHTML = "Expand All";
	expandall_button.onclick = function(e) {
		_g.expandAll(_g.TreeDiv.firstChild);
	};
	this.DebugWin.document.body.appendChild(expandall_button);
	var collapseall_button = window.document.createElement("button");
	collapseall_button.innerHTML = "Collapse All";
	collapseall_button.onclick = function(e1) {
		_g.collapseAll(_g.TreeDiv.firstChild);
	};
	this.DebugWin.document.body.appendChild(collapseall_button);
	this.TreeDiv = window.document.createElement("div");
	this.DebugWin.document.body.appendChild(this.TreeDiv);
	this.ClipBoundsRect = window.document.createElement("div");
	this.ClipBoundsRect.style.position = "fixed";
	this.ClipBoundsRect.style.backgroundColor = "rgba(255, 0, 0, 0.5)";
	window.document.body.appendChild(this.ClipBoundsRect);
};
_$RenderSupportJSPixi_DebugClipsTree.__name__ = true;
_$RenderSupportJSPixi_DebugClipsTree.getInstance = function() {
	if(_$RenderSupportJSPixi_DebugClipsTree.instance == null) _$RenderSupportJSPixi_DebugClipsTree.instance = new _$RenderSupportJSPixi_DebugClipsTree();
	return _$RenderSupportJSPixi_DebugClipsTree.instance;
};
_$RenderSupportJSPixi_DebugClipsTree.prototype = {
	setClipBoundsRect: function(bounds) {
		this.ClipBoundsRect.style.left = bounds.x;
		this.ClipBoundsRect.style.top = bounds.y;
		this.ClipBoundsRect.style.width = bounds.width;
		this.ClipBoundsRect.style.height = bounds.height;
	}
	,clearTree: function() {
		this.TreeDiv.innerHTML = "";
	}
	,updateTree: function(stage) {
		var _g = this;
		if(this.UpdateTimer != null) this.UpdateTimer.stop();
		this.UpdateTimer = haxe_Timer.delay(function() {
			_g.doUpdateTree(stage);
		},1000);
	}
	,doUpdateTree: function(stage) {
		this.clearTree();
		this.addItem(this.TreeDiv,stage);
	}
	,expandNode: function(node) {
		if(node.list != null) node.list.style.display = "block";
		node.arrow.innerHTML = StringTools.replace(node.arrow.innerHTML,"▶","▼");
	}
	,collapseNode: function(node) {
		if(node.list != null) node.list.style.display = "none";
		node.arrow.innerHTML = StringTools.replace(node.arrow.innerHTML,"▼","▶");
	}
	,expandAll: function(node) {
		this.expandNode(node);
		if(node.list != null && node.list.children != null) {
			var childs = node.list.children;
			var _g = 0;
			while(_g < childs.length) {
				var c = childs[_g];
				++_g;
				this.expandAll(c);
			}
		}
	}
	,collapseAll: function(node) {
		this.collapseNode(node);
		if(node.list != null && node.list.children != null) {
			var childs = node.list.children;
			var _g = 0;
			while(_g < childs.length) {
				var c = childs[_g];
				++_g;
				this.collapseAll(c);
			}
		}
	}
	,addItem: function(root,item) {
		var _g = this;
		var li = window.document.createElement("li");
		li.style.color = "rgba(0,0,0,0)";
		root.appendChild(li);
		var arrow = window.document.createElement("div");
		li.appendChild(arrow);
		arrow.style.color = "black";
		arrow.style.fontSize = "10px";
		arrow.style.display = "inline";
		li.arrow = arrow;
		var description = window.document.createElement("div");
		description.style.display = "inline";
		if(item.getDescription) description.innerHTML = item.getDescription(); else if(item.graphicsData) description.innerHTML = "Graphics"; else description.innerHTML = "Clip";
		if(item.worldVisible) description.style.color = "#303030"; else {
			description.style.color = "#DDDDDD";
			description.innerHTML += " invisible";
		}
		description.style.fontSize = "10px";
		if(item.isMask) description.innerHTML += " mask";
		description.addEventListener("mouseover",function(e) {
			description.style.backgroundColor = "#DDDDDD";
		});
		description.addEventListener("mouseout",function(e1) {
			description.style.backgroundColor = "";
		});
		description.addEventListener("mousedown",function(e2) {
			_g.setClipBoundsRect(item.getBounds());
		});
		li.appendChild(description);
		li.description = description;
		if(item.children != null && item.children.length > 0) {
			arrow.innerHTML = "▶";
			var ul = window.document.createElement("ul");
			li.appendChild(ul);
			li.list = ul;
			var childs = item.children;
			var _g1 = 0;
			while(_g1 < childs.length) {
				var c = childs[_g1];
				++_g1;
				this.addItem(ul,c);
			}
			arrow.addEventListener("click",function(e3) {
				if(ul.style.display == "none") _g.expandNode(li); else _g.collapseNode(li);
			});
			ul.style.display = "none";
		}
	}
	,__class__: _$RenderSupportJSPixi_DebugClipsTree
};
var RenderSupportJSPixi = function() { };
RenderSupportJSPixi.__name__ = true;
RenderSupportJSPixi.isFirefox = function() {
	var useragent = window.navigator.userAgent.toLowerCase();
	return useragent.indexOf("firefox") >= 0;
};
RenderSupportJSPixi.defer = function(fn,time) {
	if(time == null) time = 10;
	haxe_Timer.delay(fn,time);
};
RenderSupportJSPixi.registerNativeWidgetClip = function(clip) {
	RenderSupportJSPixi.NativeWidgetClips.push(clip);
};
RenderSupportJSPixi.unregisterNativeWidgetClip = function(clip) {
	HxOverrides.remove(RenderSupportJSPixi.NativeWidgetClips,clip);
};
RenderSupportJSPixi.registerAccessWidgetClip = function(clip) {
	RenderSupportJSPixi.AccessWidgetClips.push(clip);
};
RenderSupportJSPixi.unregisterAccessWidgetClip = function(clip) {
	HxOverrides.remove(RenderSupportJSPixi.AccessWidgetClips,clip);
};
RenderSupportJSPixi.init = function() {
	if(Util.getParameter("oldjs") != "1") RenderSupportJSPixi.initPixiRenderer(); else RenderSupportJSPixi.defer(RenderSupportJSPixi.StartFlowMain);
	return true;
};
RenderSupportJSPixi.printOptionValues = function() {
	if(RenderSupportJSPixi.DebugMode) Errors.print("Flow Pixi renderer DEBUG mode is turned on");
	if(RenderSupportJSPixi.CacheTextsAsBitmap) Errors.print("Caches all textclips as bitmap is turned on");
};
RenderSupportJSPixi.initPixiRenderer = function() {
	var options = { antialias : RenderSupportJSPixi.Antialias, transparent : false, backgroundColor : 16777215, preserveDrawingBuffer : false};
	if(RenderSupportJSPixi.RendererType == "auto") RenderSupportJSPixi.PixiRenderer = PIXI.autoDetectRenderer(window.innerWidth,window.innerHeight,options); else if(RenderSupportJSPixi.RendererType == "webgl") RenderSupportJSPixi.PixiRenderer = new PIXI.WebGLRenderer(window.innerWidth,window.innerHeight,options); else RenderSupportJSPixi.PixiRenderer = new PIXI.CanvasRenderer(window.innerWidth,window.innerHeight,options);
	window.document.body.appendChild(RenderSupportJSPixi.PixiRenderer.view);
	RenderSupportJSPixi.initPixiStageEventListeners();
	RenderSupportJSPixi.initBrowserWindowEventListeners();
	FontLoader.LoadFonts(RenderSupportJSPixi.UseDFont,RenderSupportJSPixi.StartFlowMain);
	RenderSupportJSPixi.initClipboardListeners();
	_$RenderSupportJSPixi_TextField.cacheTextsAsBitmap = RenderSupportJSPixi.CacheTextsAsBitmap;
	_$RenderSupportJSPixi_VideoClip.UsePixiTextures = RenderSupportJSPixi.UseVideoTextures;
	RenderSupportJSPixi.printOptionValues();
	if(RenderSupportJSPixi.PixiRenderer.plugins != null && RenderSupportJSPixi.PixiRenderer.plugins.accessibility != null) {
		RenderSupportJSPixi.PixiRenderer.plugins.accessibility.destroy();
		RenderSupportJSPixi.PixiRenderer.plugins.accessibility = null;
	}
	window.requestAnimationFrame(RenderSupportJSPixi.animate);
};
RenderSupportJSPixi.initBrowserWindowEventListeners = function() {
	RenderSupportJSPixi.WindowTopHeight = window.screen.height - window.innerHeight;
	window.addEventListener("resize",RenderSupportJSPixi.onBrowserWindowResize);
	window.addEventListener("message",RenderSupportJSPixi.receiveWindowMessage);
};
RenderSupportJSPixi.initClipboardListeners = function() {
	var handler;
	var handlePaste = function(e) {
		if(window.clipboardData && window.clipboardData.getData) NativeHx.clipboardData = window.clipboardData.getData("Text"); else if(e.clipboardData && e.clipboardData.getData) NativeHx.clipboardData = e.clipboardData.getData("text/plain"); else NativeHx.clipboardData = "";
	};
	handler = handlePaste;
	window.document.addEventListener("paste",handler,false);
};
RenderSupportJSPixi.receiveWindowMessage = function(e) {
	var hasNestedWindow = null;
	hasNestedWindow = function(iframe,win) {
		try {
			if(iframe.contentWindow == win) return true;
			var iframes = iframe.contentWindow.document.getElementsByTagName("iframe");
			var _g1 = 0;
			var _g = iframes.length;
			while(_g1 < _g) {
				var i = _g1++;
				if(hasNestedWindow(iframes[i],win)) return true;
			}
		} catch( e1 ) {
			haxe_CallStack.lastException = e1;
			if (e1 instanceof js__$Boot_HaxeError) e1 = e1.val;
			Errors.print(e1);
		}
		return false;
	};
	var content_win = e.source;
	var all_iframes = window.document.getElementsByTagName("iframe");
	var _g11 = 0;
	var _g2 = all_iframes.length;
	while(_g11 < _g2) {
		var i1 = _g11++;
		var f = all_iframes[i1];
		if(hasNestedWindow(f,content_win)) {
			f.callflow(["postMessage",e.data]);
			return;
		}
	}
	Errors.report("Warning: unknow message source");
};
RenderSupportJSPixi.onBrowserWindowResize = function(e) {
	RenderSupportJSPixi.PixiStageChanged = true;
	RenderSupportJSPixi.PixiStageSizeChanged = true;
	if(RenderSupportJSPixi.isAndroid) RenderSupportJSPixi.PixiRenderer.resize(window.screen.width,window.screen.height - RenderSupportJSPixi.WindowTopHeight); else RenderSupportJSPixi.PixiRenderer.resize(window.innerWidth,window.innerHeight);
	var _g = 0;
	var _g1 = RenderSupportJSPixi.PixiStageEventListeners.get("resize");
	while(_g < _g1.length) {
		var l = _g1[_g];
		++_g;
		l();
	}
};
RenderSupportJSPixi.dropCurrentFocus = function() {
	if(window.document.activeElement != null) window.document.activeElement.blur();
};
RenderSupportJSPixi.nativeWidgetsOnMouseDown = function() {
	var _g = 0;
	var _g1 = RenderSupportJSPixi.NativeWidgetClips;
	while(_g < _g1.length) {
		var c = _g1[_g];
		++_g;
		c.onStageMouseDown(RenderSupportJSPixi.MousePos);
	}
};
RenderSupportJSPixi.initPixiStageEventListeners = function() {
	RenderSupportJSPixi.PixiStageEventListeners = new haxe_ds_StringMap();
	var mdl = [];
	RenderSupportJSPixi.PixiStageEventListeners.set("mousedown",mdl);
	var mml = [];
	RenderSupportJSPixi.PixiStageEventListeners.set("mousemove",mml);
	var mul = [];
	RenderSupportJSPixi.PixiStageEventListeners.set("mouseup",mul);
	var value = [];
	RenderSupportJSPixi.PixiStageEventListeners.set("resize",value);
	if(NativeHx.isTouchScreen()) {
		RenderSupportJSPixi.setStagePointerHandler("touchstart",mdl);
		RenderSupportJSPixi.setStagePointerHandler("touchmove",mml);
		RenderSupportJSPixi.setStagePointerHandler("touchend",mul);
	} else {
		RenderSupportJSPixi.setStagePointerHandler("mousedown",mdl);
		RenderSupportJSPixi.setStagePointerHandler("mousemove",mml);
		RenderSupportJSPixi.setStagePointerHandler("mouseup",mul);
		RenderSupportJSPixi.setStagePointerHandler("mouseout",mul);
	}
	mdl.push(function() {
		RenderSupportJSPixi.MouseUpReceived = false;
	});
	mul.push(function() {
		RenderSupportJSPixi.MouseUpReceived = true;
	});
	mdl.push(RenderSupportJSPixi.nativeWidgetsOnMouseDown);
	mdl.push(RenderSupportJSPixi.dropCurrentFocus);
};
RenderSupportJSPixi.setStagePointerHandler = function(event,listeners) {
	var cb;
	switch(event) {
	case "touchstart":case "touchmove":
		cb = function(e) {
			if(e.touches.length == 1) {
				RenderSupportJSPixi.MousePos.x = e.touches[0].pageX;
				RenderSupportJSPixi.MousePos.y = e.touches[0].pageY;
				var _g = 0;
				while(_g < listeners.length) {
					var l = listeners[_g];
					++_g;
					l();
				}
			}
		};
		break;
	case "touchend":
		cb = function(e1) {
			if(e1.touches.length == 0) {
				var _g1 = 0;
				while(_g1 < listeners.length) {
					var l1 = listeners[_g1];
					++_g1;
					l1();
				}
			}
		};
		break;
	case "mouseout":
		cb = function(e2) {
			if(RenderSupportJSPixi.MouseUpReceived) return;
			var _g2 = 0;
			while(_g2 < listeners.length) {
				var l2 = listeners[_g2];
				++_g2;
				l2();
			}
		};
		break;
	default:
		cb = function(e3) {
			RenderSupportJSPixi.MousePos.x = e3.pageX;
			RenderSupportJSPixi.MousePos.y = e3.pageY;
			var _g3 = 0;
			while(_g3 < listeners.length) {
				var l3 = listeners[_g3];
				++_g3;
				l3();
			}
		};
	}
	RenderSupportJSPixi.PixiRenderer.view.addEventListener(event,cb);
};
RenderSupportJSPixi.emitForInteractives = function(clip,event) {
	if(clip.interactive) clip.emit(event);
	if(clip.children != null) {
		var childs = clip.children;
		var _g = 0;
		while(_g < childs.length) {
			var c = childs[_g];
			++_g;
			RenderSupportJSPixi.emitForInteractives(c,event);
		}
	}
};
RenderSupportJSPixi.emulateMouseClickOnClip = function(clip) {
	var b = clip.getBounds();
	RenderSupportJSPixi.MousePos = clip.toGlobal(new PIXI.Point(b.width / 2.0,b.height / 2.0));
	RenderSupportJSPixi.defer(function() {
		var _g = 0;
		var _g1 = RenderSupportJSPixi.PixiStageEventListeners.get("mousemove");
		while(_g < _g1.length) {
			var l = _g1[_g];
			++_g;
			l();
		}
	});
	RenderSupportJSPixi.defer(function() {
		RenderSupportJSPixi.emitForInteractives(clip,"mouseover");
	},100);
	RenderSupportJSPixi.defer(function() {
		var _g2 = 0;
		var _g11 = RenderSupportJSPixi.PixiStageEventListeners.get("mousedown");
		while(_g2 < _g11.length) {
			var l1 = _g11[_g2];
			++_g2;
			l1();
		}
	},400);
	RenderSupportJSPixi.defer(function() {
		var _g3 = 0;
		var _g12 = RenderSupportJSPixi.PixiStageEventListeners.get("mouseup");
		while(_g3 < _g12.length) {
			var l2 = _g12[_g3];
			++_g3;
			l2();
		}
	},500);
	RenderSupportJSPixi.defer(function() {
		RenderSupportJSPixi.emitForInteractives(clip,"mouseout");
	},600);
};
RenderSupportJSPixi.ensureCurrentInputVisible = function() {
	var focused_node = window.document.activeElement;
	if(focused_node != null) {
		var node_name = focused_node.nodeName;
		node_name = node_name.toLowerCase();
		if(node_name == "input" || node_name == "textarea") {
			var rect = focused_node.getBoundingClientRect();
			if(rect.bottom > window.innerHeight) {
				RenderSupportJSPixi.PixiStage.y = window.innerHeight - rect.bottom;
				RenderSupportJSPixi.PixiStageChanged = true;
			}
		}
	}
};
RenderSupportJSPixi.StartFlowMain = function() {
	Errors.print("Starting flow main.");
	window.flow_main();
};
RenderSupportJSPixi.animate = function(timestamp) {
	window.requestAnimationFrame(RenderSupportJSPixi.animate);
	if(RenderSupportJSPixi.PixiStageChanged && RenderSupportJSPixi.StageChangedTimestamp < 0) RenderSupportJSPixi.StageChangedTimestamp = timestamp;
	if(RenderSupportJSPixi.PixiStageChanged && timestamp - RenderSupportJSPixi.StageChangedTimestamp >= 40.0 || _$RenderSupportJSPixi_VideoClip.UsePixiTextures && _$RenderSupportJSPixi_VideoClip.VideosOnStage > 0 || RenderSupportJSPixi.PixiStageSizeChanged) {
		RenderSupportJSPixi.PixiStageChanged = false;
		RenderSupportJSPixi.StageChangedTimestamp = -1.0;
		if(RenderSupportJSPixi.isAndroid && RenderSupportJSPixi.PixiStageSizeChanged) RenderSupportJSPixi.PixiStage.y = 0.0;
		RenderSupportJSPixi.PixiRenderer.render(RenderSupportJSPixi.PixiStage);
		RenderSupportJSPixi.updateNativeWidgets();
		if(RenderSupportJSPixi.DebugMode) {
			RenderSupportJSPixi.updateAccessWidgets();
			RenderSupportJSPixi.updatePixiCanvasAccessElements();
		}
		if(RenderSupportJSPixi.isAndroid && RenderSupportJSPixi.PixiStageSizeChanged) RenderSupportJSPixi.ensureCurrentInputVisible();
		RenderSupportJSPixi.PixiStageSizeChanged = false;
		if(RenderSupportJSPixi.ShowDebugClipsTree) _$RenderSupportJSPixi_DebugClipsTree.getInstance().updateTree(RenderSupportJSPixi.PixiStage);
	}
};
RenderSupportJSPixi.updateNativeWidgets = function() {
	var len = RenderSupportJSPixi.NativeWidgetClips.length;
	var _g = 0;
	while(_g < len) {
		var i = _g++;
		RenderSupportJSPixi.NativeWidgetClips[len - 1 - i].updateNativeWidget();
	}
};
RenderSupportJSPixi.updateAccessWidgets = function() {
	var len = RenderSupportJSPixi.AccessWidgetClips.length;
	var _g = 0;
	while(_g < len) {
		var i = _g++;
		RenderSupportJSPixi.AccessWidgetClips[len - 1 - i].updateAccessWidget();
	}
};
RenderSupportJSPixi.updatePixiCanvasAccessElements = function() {
	RenderSupportJSPixi.PixiRenderer.view.innerHTML = "";
	if(RenderSupportJSPixi.UpdatePixiCanvasAccessElementsTimer != null) RenderSupportJSPixi.UpdatePixiCanvasAccessElementsTimer.stop();
	RenderSupportJSPixi.UpdatePixiCanvasAccessElementsTimer = haxe_Timer.delay(function() {
		RenderSupportJSPixi.doUpdatePixiCanvasAccessElements(RenderSupportJSPixi.PixiStage);
	},1000);
};
RenderSupportJSPixi.doUpdatePixiCanvasAccessElements = function(clip) {
	if(clip.isInput != null && clip.isInput() == false) {
		var p = window.document.createElement("p");
		p.innerHTML = clip.getContent();
		RenderSupportJSPixi.PixiRenderer.view.appendChild(p);
		return;
	}
	if(clip.children != null && clip.children.length > 0) {
		var childs = clip.children;
		var _g = 0;
		while(_g < childs.length) {
			var c = childs[_g];
			++_g;
			RenderSupportJSPixi.doUpdatePixiCanvasAccessElements(c);
		}
	}
};
RenderSupportJSPixi.InvalidateStage = function() {
	RenderSupportJSPixi.PixiStageChanged = true;
};
RenderSupportJSPixi.getPixelsPerCm = function() {
	return 37.795275590551178;
};
RenderSupportJSPixi.setHitboxRadius = function(radius) {
	return false;
};
RenderSupportJSPixi.addAccessAttributes = function(clip,attributes) {
	var _g = 0;
	while(_g < attributes.length) {
		var kv = attributes[_g];
		++_g;
		var key = kv[0];
		var val = kv[1];
		switch(key) {
		case "role":
			if(val == "button" || val == "checkbox") {
				window.document.body.removeChild(clip.accessWidget);
				var old_access_widget = clip.accessWidget;
				clip.accessWidget = window.document.createElement("button");
				clip.accessWidget.style.backgroundColor = "transparent";
				clip.accessWidget.style.position = "fixed";
				clip.accessWidget.style.borderStyle = "none";
				clip.accessWidget.style.pointerEvents = "none";
				clip.accessWidget.onclick = function() {
					if(clip.accessCallback != null) clip.accessCallback(); else RenderSupportJSPixi.emulateMouseClickOnClip(clip);
				};
				clip.accessWidget.onfocus = function() {
					clip.accessWidget.style.borderStyle = "solid";
				};
				clip.accessWidget.onblur = function() {
					clip.accessWidget.style.borderStyle = "none";
				};
				window.document.body.appendChild(clip.accessWidget);
				clip.accessWidget.tabIndex = old_access_widget.tabIndex;
				var old_label = old_access_widget.getAttribute("aria-label");
				if(old_label != "" && old_label != null) clip.setAttribute("aria-label",old_label);
			}
			clip.accessWidget.setAttribute("role",val);
			break;
		case "description":
			if(val != "") clip.accessWidget.setAttribute("aria-label",val);
			break;
		case "tabindex":
			if(clip.accessWidget.tabIndex != val) clip.accessWidget.tabIndex = val;
			break;
		case "callback":
			clip.accessCallback = val;
			break;
		}
	}
};
RenderSupportJSPixi.setAccessAttributes = function(clip,attributes) {
	if(!RenderSupportJSPixi.DebugMode) return;
	if(clip.accessWidget == null) {
		RenderSupportJSPixi.PixiStageChanged = true;
		var accessWidget = window.document.createElement("div");
		accessWidget.style.pointerEvents = "none";
		accessWidget.style.position = "fixed";
		clip.accessWidget = accessWidget;
		window.document.body.appendChild(accessWidget);
		clip.updateAccessWidget = function() {
			if(clip.parent == null) {
				window.document.body.removeChild(clip.accessWidget);
				RenderSupportJSPixi.unregisterAccessWidgetClip(clip);
			} else if(clip.worldVisible) {
				var bounds = clip.getBounds();
				clip.accessWidget.style.display = "block";
				clip.accessWidget.style.left = "" + bounds.x + "px";
				clip.accessWidget.style.top = "" + bounds.y + "px";
				clip.accessWidget.style.width = "" + bounds.width + "px";
				clip.accessWidget.style.height = "" + bounds.height + "px";
			} else clip.accessWidget.style.display = "none";
		};
		RenderSupportJSPixi.registerAccessWidgetClip(clip);
	}
	RenderSupportJSPixi.addAccessAttributes(clip,attributes);
};
RenderSupportJSPixi.currentClip = function() {
	return RenderSupportJSPixi.PixiStage;
};
RenderSupportJSPixi.hideFlowJSLoadingIndicator = function() {
	window.document.body.style.backgroundImage = "none";
	var indicator = window.document.getElementById("loading_js_indicator");
	if(null != indicator) indicator.style.display = "none";
};
RenderSupportJSPixi.enableResize = function() {
	RenderSupportJSPixi.hideFlowJSLoadingIndicator();
};
RenderSupportJSPixi.getStageWidth = function() {
	return RenderSupportJSPixi.PixiRenderer.width;
};
RenderSupportJSPixi.getStageHeight = function() {
	return RenderSupportJSPixi.PixiRenderer.height;
};
RenderSupportJSPixi.makeTextField = function() {
	if(RenderSupportJSPixi.UseDFont) return new _$RenderSupportJSPixi_DFontText(); else return new _$RenderSupportJSPixi_PixiText();
};
RenderSupportJSPixi.setTextAndStyle = function(textfield,text,fontfamily,fontsize,fillcolor,fillopacity,letterspacing,backgroundcolour,backgroundopacity,forTextinput) {
	RenderSupportJSPixi.PixiStageChanged = true;
	textfield.setTextAndStyle(text,fontfamily,fontsize,fillcolor,fillopacity,backgroundcolour,backgroundopacity);
};
RenderSupportJSPixi.setAdvancedText = function(textfield,sharpness,antialiastype,gridfittype) {
};
RenderSupportJSPixi.makeVideo = function(width,height,metricsFn,durationFn) {
	var vc = new _$RenderSupportJSPixi_VideoClip(width,height,metricsFn,durationFn);
	return [vc,vc];
};
RenderSupportJSPixi.setVideoVolume = function(str,volume) {
	str.setVolume(volume);
};
RenderSupportJSPixi.setVideoLooping = function(str,loop) {
};
RenderSupportJSPixi.setVideoControls = function(str,controls) {
};
RenderSupportJSPixi.setVideoSubtitle = function(str,text,size,color) {
};
RenderSupportJSPixi.playVideo = function(vc,filename,startPaused) {
	vc.playVideo(filename,startPaused);
};
RenderSupportJSPixi.seekVideo = function(str,seek) {
	str.setCurrentTime(seek);
};
RenderSupportJSPixi.getVideoPosition = function(str) {
	return str.getCurrentTime();
};
RenderSupportJSPixi.pauseVideo = function(str) {
	str.pauseVideo();
};
RenderSupportJSPixi.resumeVideo = function(str) {
	str.resumeVideo();
};
RenderSupportJSPixi.closeVideo = function(str) {
};
RenderSupportJSPixi.getTextFieldWidth = function(textfield) {
	return textfield.getWidth();
};
RenderSupportJSPixi.setTextFieldWidth = function(textfield,width) {
	RenderSupportJSPixi.PixiStageChanged = true;
	textfield.setWidth(width);
};
RenderSupportJSPixi.getTextFieldHeight = function(textfield) {
	return textfield.getHeight();
};
RenderSupportJSPixi.setTextFieldHeight = function(textfield,height) {
	RenderSupportJSPixi.PixiStageChanged = true;
	if(height > 0.0) textfield.setHeight(height);
};
RenderSupportJSPixi.setAutoAlign = function(textfield,autoalign) {
	RenderSupportJSPixi.PixiStageChanged = true;
	textfield.setAutoAlign(autoalign);
};
RenderSupportJSPixi.setTextInput = function(textfield) {
	RenderSupportJSPixi.PixiStageChanged = true;
	textfield.setTextInput();
};
RenderSupportJSPixi.setTextInputType = function(textfield,type) {
	textfield.setTextInputType(type);
};
RenderSupportJSPixi.setTabIndex = function(textfield,index) {
	textfield.setTabIndex(index);
};
RenderSupportJSPixi.getContent = function(textfield) {
	return textfield.getContent();
};
RenderSupportJSPixi.getCursorPosition = function(textfield) {
	return textfield.getCursorPosition();
};
RenderSupportJSPixi.getFocus = function(clip) {
	return clip.getFocus();
};
RenderSupportJSPixi.getScrollV = function(textfield) {
	return 0;
};
RenderSupportJSPixi.setScrollV = function(textfield,suggestedPosition) {
};
RenderSupportJSPixi.getBottomScrollV = function(textfield) {
	return 0;
};
RenderSupportJSPixi.getNumLines = function(textfield) {
	return 0;
};
RenderSupportJSPixi.setFocus = function(textfield,focus) {
	textfield.setFocus(focus);
};
RenderSupportJSPixi.setMultiline = function(textfield,multiline) {
	if(multiline) {
		RenderSupportJSPixi.PixiStageChanged = true;
		textfield.setMultiline();
	}
};
RenderSupportJSPixi.setWordWrap = function(textfield,wordWrap) {
	textfield.setWordWrap();
};
RenderSupportJSPixi.getSelectionStart = function(textfield) {
	return textfield.getSelectionStart();
};
RenderSupportJSPixi.getSelectionEnd = function(textfield) {
	return textfield.getSelectionEnd();
};
RenderSupportJSPixi.setSelection = function(textfield,start,end) {
	textfield.setSelection(start,end);
};
RenderSupportJSPixi.setReadOnly = function(textfield,readOnly) {
	textfield.setReadOnly(readOnly);
};
RenderSupportJSPixi.setMaxChars = function(textfield,maxChars) {
	textfield.setMaxChars(maxChars);
};
RenderSupportJSPixi.addTextInputFilter = function(textfield,filter) {
	return textfield.addTextInputFilter(filter);
};
RenderSupportJSPixi.addChild = function(parent,child) {
	RenderSupportJSPixi.PixiStageChanged = true;
	parent.addChild(child);
};
RenderSupportJSPixi.removeChild = function(parent,child) {
	RenderSupportJSPixi.PixiStageChanged = true;
	parent.removeChild(child);
};
RenderSupportJSPixi.makeClip = function() {
	return new PIXI.Container();
};
RenderSupportJSPixi.setClipCallstack = function(clip,callstack) {
};
RenderSupportJSPixi.setClipX = function(clip,x) {
	RenderSupportJSPixi.PixiStageChanged = true;
	clip.x = x;
};
RenderSupportJSPixi.setClipY = function(clip,y) {
	RenderSupportJSPixi.PixiStageChanged = true;
	clip.y = y;
};
RenderSupportJSPixi.setClipScaleX = function(clip,scale_x) {
	RenderSupportJSPixi.PixiStageChanged = true;
	clip.scale.x = scale_x;
};
RenderSupportJSPixi.setClipScaleY = function(clip,scale_y) {
	RenderSupportJSPixi.PixiStageChanged = true;
	clip.scale.y = scale_y;
};
RenderSupportJSPixi.setClipRotation = function(clip,r) {
	RenderSupportJSPixi.PixiStageChanged = true;
	clip.rotation = r * 0.0174532925;
};
RenderSupportJSPixi.setClipAlpha = function(clip,a) {
	RenderSupportJSPixi.PixiStageChanged = true;
	clip.alpha = a;
};
RenderSupportJSPixi.getDisplayObjectGraphics = function(clip) {
	if(clip.graphics != null) return clip.graphics;
	if(clip.children == null) return null;
	var _g = 0;
	var _g1 = clip.children;
	while(_g < _g1.length) {
		var c = _g1[_g];
		++_g;
		var g = RenderSupportJSPixi.getDisplayObjectGraphics(c);
		if(g != null) return g;
	}
	return null;
};
RenderSupportJSPixi.setClipMask = function(clip,mask) {
	RenderSupportJSPixi.PixiStageChanged = true;
	clip.mask = RenderSupportJSPixi.getDisplayObjectGraphics(mask);
	if(clip.mask == null) mask.visible = false;
};
RenderSupportJSPixi.getStage = function() {
	return RenderSupportJSPixi.PixiStage;
};
RenderSupportJSPixi.addKeyEventListener = function(clip,event,fn) {
	var keycb = function(e) {
		var shift = e.shiftKey;
		var alt = e.altKey;
		var ctrl = e.ctrlKey;
		var s = "";
		if(e.which >= 112 && e.which <= 123) s = "F" + (e.which - 111); else {
			var _g = e.which;
			switch(_g) {
			case 13:
				s = "enter";
				break;
			case 27:
				s = "esc";
				break;
			case 9:
				s = "tab";
				break;
			case 16:
				s = "shift";
				break;
			case 17:
				s = "ctrl";
				break;
			case 18:
				s = "alt";
				break;
			case 37:
				s = "left";
				break;
			case 38:
				s = "up";
				break;
			case 39:
				s = "right";
				break;
			case 40:
				s = "down";
				break;
			default:
				s = String.fromCharCode(e.which);
			}
		}
		fn(s,ctrl,shift,alt,e.keyCode);
	};
	window.addEventListener(event,keycb);
	return function() {
		window.removeEventListener(event,keycb);
	};
};
RenderSupportJSPixi.addStreamStatusListener = function(clip,fn) {
	return clip.addStreamStatusListener(fn);
};
RenderSupportJSPixi.addEventListener = function(clip,event,fn) {
	if(event == "resize" || event == "mousedown" || event == "mousemove" || event == "mouseup") {
		RenderSupportJSPixi.PixiStageEventListeners.get(event).push(fn);
		return function() {
			var _this = RenderSupportJSPixi.PixiStageEventListeners.get(event);
			HxOverrides.remove(_this,fn);
		};
	} else if(event == "rollover") {
		clip.interactive = true;
		var on_mouseover = function(d) {
			fn();
		};
		clip.on("mouseover",on_mouseover);
		return function() {
			clip.off("mouseover",on_mouseover);
		};
	} else if(event == "rollout") {
		clip.interactive = true;
		var on_mouseout = function(d1) {
			fn();
		};
		clip.on("mouseout",on_mouseout);
		return function() {
			clip.off("mouseout",on_mouseout);
		};
	} else if(event == "scroll") return clip.addNativeEventListener("scroll",fn); else if(event == "change") return clip.addNativeEventListener("input",fn); else if(event == "focusin") return clip.addNativeEventListener("focus",fn); else if(event == "focusout") return clip.addNativeEventListener("blur",fn); else {
		Errors.report("Unknown event: " + event);
		return function() {
		};
	}
};
RenderSupportJSPixi.addMouseWheelEventListener = function(clip,fn) {
	var wheel_cb = function(event) {
		var delta = 0.0;
		if(event.wheelDelta != null) delta = event.wheelDelta / 120; else if(event.detail != null) delta = -event.detail / 3;
		if(event.preventDefault != null) event.preventDefault();
		fn(delta);
	};
	if(!RenderSupportJSPixi.isFirefox()) {
		window.addEventListener("mousewheel",wheel_cb);
		return function() {
			window.removeEventListener("mousewheel",wheel_cb);
		};
	} else {
		window.addEventListener("DOMMouseScroll",wheel_cb);
		return function() {
			window.removeEventListener("DOMMouseScroll",wheel_cb);
		};
	}
};
RenderSupportJSPixi.addFinegrainMouseWheelEventListener = function(clip,f) {
	return RenderSupportJSPixi.addMouseWheelEventListener(clip,function(delta) {
		f(delta,0);
	});
};
RenderSupportJSPixi.getMouseX = function(clip) {
	if(clip == RenderSupportJSPixi.PixiStage) return RenderSupportJSPixi.MousePos.x; else return clip.toLocal(RenderSupportJSPixi.MousePos).x;
};
RenderSupportJSPixi.getMouseY = function(clip) {
	if(clip == RenderSupportJSPixi.PixiStage) return RenderSupportJSPixi.MousePos.y; else return clip.toLocal(RenderSupportJSPixi.MousePos).y;
};
RenderSupportJSPixi.hittestGraphics = function(g,global) {
	var graphicsData = g.graphicsData;
	var local = g.toLocal(global);
	var _g = 0;
	while(_g < graphicsData.length) {
		var data = graphicsData[_g];
		++_g;
		if(data.fill && data.shape != null && data.shape.contains(local.x,local.y)) return true;
	}
	return false;
};
RenderSupportJSPixi.dohittest = function(clip,global) {
	if(!clip.worldVisible || clip.isMask) return false;
	if(clip.mask != null && !RenderSupportJSPixi.hittestGraphics(clip.mask,global)) return false;
	if(clip.graphicsData != null) {
		if(RenderSupportJSPixi.hittestGraphics(clip,global)) return true;
	} else if(clip.texture != null) {
		var w = clip.texture.frame.width;
		var h = clip.texture.frame.height;
		var local = clip.toLocal(global);
		if(local.x > 0.0 && local.y > 0.0 && local.x < w && local.y < h) return true;
	} else if(clip.tint != null) {
		var b = clip.getLocalBounds();
		var local1 = clip.toLocal(global);
		local1.y += clip.y;
		if(local1.x > 0.0 && local1.y > 0.0 && local1.x < b.width && local1.y < b.height) return true;
	}
	if(clip.children != null) {
		var childs = clip.children;
		var _g = 0;
		while(_g < childs.length) {
			var c = childs[_g];
			++_g;
			if(RenderSupportJSPixi.dohittest(c,global)) return true;
		}
	}
	return false;
};
RenderSupportJSPixi.clipOnTheStage = function(clip) {
	return clip == RenderSupportJSPixi.PixiStage || clip.parent != null;
};
RenderSupportJSPixi.hittest = function(clip,x,y) {
	if(!(clip == RenderSupportJSPixi.PixiStage || clip.parent != null)) return false;
	var global = new PIXI.Point(x,y);
	clip.updateTransform();
	var parent = clip.parent;
	while(parent != null) {
		if(parent.mask != null && !RenderSupportJSPixi.hittestGraphics(parent.mask,global)) return false;
		parent = parent.parent;
	}
	return RenderSupportJSPixi.dohittest(clip,global);
};
RenderSupportJSPixi.getGraphics = function(clip) {
	var g = new PIXI.Graphics();
	RenderSupportJSPixi.moveTo(g,0.0,0.0);
	clip.addChild(g);
	clip.graphics = g;
	return g;
};
RenderSupportJSPixi.setLineStyle = function(graphics,width,color,opacity) {
	graphics.lineStyle(width,color,opacity);
};
RenderSupportJSPixi.setLineStyle2 = function(graphics,width,color,opacity,pixelHinting) {
	RenderSupportJSPixi.setLineStyle(graphics,width,color,opacity);
};
RenderSupportJSPixi.beginFill = function(graphics,color,opacity) {
	graphics.beginFill(color,opacity);
};
RenderSupportJSPixi.beginGradientFill = function(graphics,colors,alphas,offsets,matrix,type) {
	RenderSupportJSPixi.beginFill(graphics,colors[0],alphas[0]);
};
RenderSupportJSPixi.setLineGradientStroke = function(graphics,colours,alphas,offsets,matrix) {
	RenderSupportJSPixi.setLineStyle(graphics,1.0,colours[0],alphas[0]);
};
RenderSupportJSPixi.makeMatrix = function(width,height,rotation,xOffset,yOffset) {
	return null;
};
RenderSupportJSPixi.moveTo = function(graphics,x,y) {
	graphics.moveTo(x,y);
	graphics.pen_x = x;
	graphics.pen_y = y;
};
RenderSupportJSPixi.lineTo = function(graphics,x,y) {
	graphics.lineTo(x,y);
	graphics.pen_x = x;
	graphics.pen_y = y;
};
RenderSupportJSPixi.curveTo = function(graphics,cx,cy,x,y) {
	x += 0.01;
	y += 0.01;
	var qcx1 = graphics.pen_x + 0.66666666666666663 * (cx - graphics.pen_x);
	var qcy1 = graphics.pen_y + 0.66666666666666663 * (cy - graphics.pen_y);
	var qcx2 = x + 0.66666666666666663 * (cx - x);
	var qcy2 = y + 0.66666666666666663 * (cy - y);
	graphics.bezierCurveTo(qcx1,qcy1,qcx2,qcy2,x,y);
	graphics.pen_x = x;
	graphics.pen_y = y;
};
RenderSupportJSPixi.endFill = function(graphics) {
	graphics.endFill();
};
RenderSupportJSPixi.makePicture = function(url,cache,metricsFn,errorFn,onlyDownload) {
	if(StringTools.endsWith(url,".swf")) url = StringTools.replace(url,".swf",".png");
	var texture = PIXI.Texture.fromImage(url);
	var sprite = new PIXI.Sprite(texture);
	var report_metrics = function() {
		var bounds = sprite.getLocalBounds();
		metricsFn(bounds.width,bounds.height);
	};
	if(texture.baseTexture.hasLoaded) report_metrics(); else texture.on("update",report_metrics);
	return sprite;
};
RenderSupportJSPixi.setCursor = function(clip,cursor) {
	var css_cursor;
	switch(cursor) {
	case "arrow":
		css_cursor = "default";
		break;
	case "auto":
		css_cursor = "auto";
		break;
	case "finger":
		css_cursor = "pointer";
		break;
	case "move":
		css_cursor = "move";
		break;
	case "text":
		css_cursor = "text";
		break;
	default:
		css_cursor = "default";
	}
	window.document.body.style.cursor = css_cursor;
};
RenderSupportJSPixi.getCursor = function(clip) {
	var _g = window.document.body.style.cursor;
	switch(_g) {
	case "default":
		return "arrow";
	case "auto":
		return "auto";
	case "pointer":
		return "finger";
	case "move":
		return "move";
	case "text":
		return "text";
	default:
		return "default";
	}
};
RenderSupportJSPixi.addFilters = function(clip,filters) {
	RenderSupportJSPixi.PixiStageChanged = true;
	filters = filters.filter(function(f) {
		return f != null;
	});
	if(filters.length > 0) clip.filters = filters; else clip.filters = null;
};
RenderSupportJSPixi.makeBevel = function(angle,distance,radius,spread,color1,alpha1,color2,alpha2,inside) {
	return null;
};
RenderSupportJSPixi.makeBlur = function(radius,spread) {
	var b = new PIXI.filters.BlurFilter();
	b.blur = spread;
	return b;
};
RenderSupportJSPixi.makeDropShadow = function(angle,distance,radius,spread,color,alpha,inside) {
	var ds = new PIXI.filters.DropShadowFilter();
	ds.angle = angle;
	ds.distance = distance;
	ds.color = color;
	ds.alpha = alpha;
	ds.blur = spread;
	return ds;
};
RenderSupportJSPixi.makeGlow = function(radius,spread,color,alpha,inside) {
	var glow = new PIXI.AbstractFilter(_$RenderSupportJSPixi_Shaders.VertexSrc.join("\n"),_$RenderSupportJSPixi_Shaders.GlowFragmentSrc.join("\n"),{ });
	return glow;
};
RenderSupportJSPixi.setScrollRect = function(clip,left,top,width,height) {
};
RenderSupportJSPixi.makeGraphicsRect = function(width,height) {
	var g = new PIXI.Graphics();
	g.beginFill(16777215);
	g.drawRect(0.0,0.0,width,height);
	g.endFill();
	return g;
};
RenderSupportJSPixi.getTextMetrics = function(textfield) {
	return textfield.getTextMetrics();
};
RenderSupportJSPixi.makeBitmap = function() {
	return null;
};
RenderSupportJSPixi.bitmapDraw = function(bitmap,clip,width,height) {
};
RenderSupportJSPixi.getClipVisible = function(clip) {
	return clip.worldVisible;
};
RenderSupportJSPixi.setClipVisible = function(clip,vis) {
	RenderSupportJSPixi.PixiStageChanged = true;
	clip.visible = vis;
};
RenderSupportJSPixi.setFullScreenTarget = function(clip) {
	if(js_Boot.__instanceof(clip,_$RenderSupportJSPixi_VideoClip)) RenderSupportJSPixi.FullScreenTargetClip = clip;
};
RenderSupportJSPixi.setFullScreenRectangle = function(x,y,w,h) {
};
RenderSupportJSPixi.resetFullScreenTarget = function() {
	RenderSupportJSPixi.FullScreenTargetClip = null;
};
RenderSupportJSPixi.toggleFullScreen = function() {
	if(RenderSupportJSPixi.FullScreenTargetClip != null) {
		if(RenderSupportJSPixi.IsFullScreen) RenderSupportJSPixi.FullScreenTargetClip.exitFullScreen(); else RenderSupportJSPixi.FullScreenTargetClip.requestFullScreen();
		RenderSupportJSPixi.IsFullScreen = !RenderSupportJSPixi.IsFullScreen;
	}
};
RenderSupportJSPixi.onFullScreen = function(fn) {
	return function() {
	};
};
RenderSupportJSPixi.isFullScreen = function() {
	return RenderSupportJSPixi.IsFullScreen;
};
RenderSupportJSPixi.setWindowTitle = function(title) {
	window.document.title = title;
};
RenderSupportJSPixi.takeSnapshot = function(path) {
};
RenderSupportJSPixi.getScreenPixelColor = function(x,y) {
	return 0;
};
RenderSupportJSPixi.makeWebClip = function(url,domain,useCache,reloadBlock,cb,ondone) {
	return new _$RenderSupportJSPixi_WebClip(url,domain,useCache,reloadBlock,cb,ondone);
};
RenderSupportJSPixi.webClipHostCall = function(clip,name,args) {
	return clip.hostCall(name,args);
};
RenderSupportJSPixi.getNumberOfCameras = function() {
	return 0;
};
RenderSupportJSPixi.getCameraInfo = function(id) {
	return "";
};
RenderSupportJSPixi.makeCamera = function(uri,camID,camWidth,camHeight,camFps,vidWidth,vidHeight,recordMode,cbOnReadyForRecording,cbOnFailed) {
	return [null,null];
};
RenderSupportJSPixi.startRecord = function(str,filename,mode) {
};
RenderSupportJSPixi.stopRecord = function(str) {
};
RenderSupportJSPixi.cameraTakePhoto = function(cameraId,additionalInfo,desiredWidth,desiredHeight,compressQuality,fileName) {
};
RenderSupportJSPixi.addGestureListener = function(event,cb) {
	return function() {
	};
};
RenderSupportJSPixi.setWebClipZoomable = function(clip,zoomable) {
};
RenderSupportJSPixi.setInterfaceOrientation = function(orientation) {
};
RenderSupportJSPixi.setUrlHash = function(hash) {
	window.location.hash = hash;
};
RenderSupportJSPixi.getUrlHash = function() {
	return window.location.hash;
};
RenderSupportJSPixi.addUrlHashListener = function(cb) {
	var wrapper = function(e) {
		cb(window.location.hash);
	};
	window.addEventListener("hashchange",wrapper);
	return function() {
		window.removeEventListener("hashchanged",wrapper);
	};
};
RenderSupportJSPixi.setGlobalZoomEnabled = function(enabled) {
};
var _$RenderSupportJSPixi_WebClip = function(url,domain,useCache,reloadBlock,cb,ondone) {
	this.iframe = null;
	var _g = this;
	_$RenderSupportJSPixi_NativeWidgetClip.call(this);
	if(domain != "") try {
		window.document.domain = domain;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		Errors.report("Can not set RealHTML domain" + Std.string(e));
	}
	this.createNativeWidget("div");
	if(_$RenderSupportJSPixi_WebClip.isIOS()) {
		this.nativeWidget.style.webkitOverflowScrolling = "touch";
		this.nativeWidget.style.overflowY = "scroll";
	}
	this.iframe = window.document.createElement("iframe");
	this.iframe.src = url;
	this.iframe.allowFullscreen = true;
	this.iframe.frameBorder = "no";
	this.iframe.callflow = cb;
	this.nativeWidget.appendChild(this.iframe);
	if(reloadBlock) this.appendReloadBlock();
	this.iframe.onload = function() {
		try {
			ondone("OK");
			if(_$RenderSupportJSPixi_WebClip.isIOS() && (url.indexOf("flowjs") >= 0 || url.indexOf("lslti_provider") >= 0)) _g.iframe.scrolling = "no";
			_g.iframe.contentWindow.callflow = cb;
			if(_g.iframe.contentWindow.pushCallflowBuffer) _g.iframe.contentWindow.pushCallflowBuffer();
			if(_$RenderSupportJSPixi_WebClip.isIOS() && _g.iframe.contentWindow.setSplashScreen != null) _g.iframe.scrolling = "no";
		} catch( e1 ) {
			haxe_CallStack.lastException = e1;
			if (e1 instanceof js__$Boot_HaxeError) e1 = e1.val;
			Errors.report(e1);
		}
	};
};
_$RenderSupportJSPixi_WebClip.__name__ = true;
_$RenderSupportJSPixi_WebClip.isIOS = function() {
	var ua = window.navigator.userAgent;
	return ua.indexOf("iPhone") != -1 || ua.indexOf("iPad") != -1 || ua.indexOf("iPod") != -1;
};
_$RenderSupportJSPixi_WebClip.__super__ = _$RenderSupportJSPixi_NativeWidgetClip;
_$RenderSupportJSPixi_WebClip.prototype = $extend(_$RenderSupportJSPixi_NativeWidgetClip.prototype,{
	appendReloadBlock: function() {
		var _g = this;
		var div = window.document.createElement("div");
		div.style.cssText = "z-index: 101; position: absolute; top: 0; left: 0; width: 100%; height: 20px; opacity: 0.6;";
		var img = window.document.createElement("img");
		img.style.cssText = "position: absolute; height: 20px; width: 20px; top: 0; right: 0; background: #BEBEBE;";
		img.src = "http://cloud1.area9.dk/flow/images/lms_reload.png";
		div.appendChild(img);
		var span = window.document.createElement("span");
		span.style.cssText = "position: absolute; right: 25px; top: 0px; color: white; display: none;";
		span.innerHTML = "Reload the page";
		div.appendChild(span);
		img.onmouseover = function(e) {
			div.style.background = "linear-gradient(to bottom right, #36372F, #ACA9A4)";
			span.style.display = "block";
			img.style.background = "none";
		};
		img.onmouseleave = function(e1) {
			div.style.background = "none";
			span.style.display = "nonde";
			img.style.background = "#BEBEBE";
		};
		div.onclick = function(e2) {
			_g.iframe.src = _g.iframe.src;
		};
		this.nativeWidget.appendChild(div);
	}
	,updateNativeWidget: function() {
		_$RenderSupportJSPixi_NativeWidgetClip.prototype.updateNativeWidget.call(this);
		if(this.worldVisible && this.nativeWidget != null) {
			this.iframe.style.width = this.nativeWidget.style.width;
			this.iframe.style.height = this.nativeWidget.style.height;
		}
	}
	,getDescription: function() {
		return "WebClip (url = " + Std.string(this.iframe.src) + ")";
	}
	,getWidth: function() {
		return 100.0;
	}
	,getHeight: function() {
		return 100.0;
	}
	,hostCall: function(name,args) {
		try {
			return this.iframe.contentWindow[name].apply(this.iframe.contentWindow,args);
		} catch( e ) {
			haxe_CallStack.lastException = e;
			if (e instanceof js__$Boot_HaxeError) e = e.val;
			Errors.report("Error in hostCall: " + name + ", arg: " + Std.string(args));
			Errors.report(e);
		}
		return null;
	}
	,__class__: _$RenderSupportJSPixi_WebClip
});
var FlowFontStyle = function() { };
FlowFontStyle.__name__ = true;
FlowFontStyle.fromFlowFont = function(name) {
	if(FlowFontStyle.flowFontStyles == null) FlowFontStyle.flowFontStyles = JSON.parse(haxe_Resource.getString("fontstyles"));
	var style = Reflect.field(FlowFontStyle.flowFontStyles,name.toLowerCase());
	if(style != null) return style; else return { family : name, weight : "", size : 0.0, style : "normal"};
};
var _$RenderSupportJSPixi_PixiText = function() {
	this.pixi_text = null;
	_$RenderSupportJSPixi_TextField.call(this);
	this.pixi_text = new PIXI.Text("");
	if(_$RenderSupportJSPixi_TextField.cacheTextsAsBitmap) this.pixi_text.cacheAsBitmap = true;
	this.addChild(this.pixi_text);
};
_$RenderSupportJSPixi_PixiText.__name__ = true;
_$RenderSupportJSPixi_PixiText.__super__ = _$RenderSupportJSPixi_TextField;
_$RenderSupportJSPixi_PixiText.prototype = $extend(_$RenderSupportJSPixi_TextField.prototype,{
	setTextAndStyle: function(text,fontfamily,fontsize,fillcolor,fillopacity,backgroundcolour,backgroundopacity) {
		_$RenderSupportJSPixi_TextField.prototype.setTextAndStyle.call(this,text,fontfamily,fontsize,fillcolor,fillopacity,backgroundcolour,backgroundopacity);
		var style = { font : this.getFontString(fontfamily,fontsize < 0.6?0.6:fontsize), fill : "#" + StringTools.hex(fillcolor,6)};
		this.pixi_text.text = text;
		this.pixi_text.style = style;
		this.pixi_text.alpha = this.fillOpacity;
		this.setTextBackground();
	}
	,setGLText: function(t) {
		this.pixi_text.text = t;
	}
	,getFontString: function(fontfamily,fontsize) {
		var style = FlowFontStyle.fromFlowFont(fontfamily);
		style.size = fontsize;
		return "" + style.weight + " " + style.style + " " + style.size + "px " + style.family;
	}
	,setWordWrap: function() {
		this.pixi_text.style.wordWrap = true;
	}
	,setWordWrapWidth: function(wrap_width) {
		this.pixi_text.style.wordWrapWidth = wrap_width;
	}
	,__class__: _$RenderSupportJSPixi_PixiText
});
var _$RenderSupportJSPixi_DFontText = function() {
	this.fontfamily = "Book";
	this.clipWidth = 0.0;
	this.baseline = 14.4;
	this.style = { font : "16px Book", tint : 65793};
	this.text = "";
	this.wordWrapWidth = -1.0;
	this.wordWrap = false;
	_$RenderSupportJSPixi_TextField.call(this);
};
_$RenderSupportJSPixi_DFontText.__name__ = true;
_$RenderSupportJSPixi_DFontText.getDFontInfo = function(fontfamily) {
	return DFontText.dfont_table[fontfamily];
};
_$RenderSupportJSPixi_DFontText.__super__ = _$RenderSupportJSPixi_TextField;
_$RenderSupportJSPixi_DFontText.prototype = $extend(_$RenderSupportJSPixi_TextField.prototype,{
	setTextAndStyle: function(text,fontfamily,fontsize,fillcolor,fillopacity,backgroundcolour,backgroundopacity) {
		_$RenderSupportJSPixi_TextField.prototype.setTextAndStyle.call(this,text,fontfamily,fontsize,fillcolor,fillopacity,backgroundcolour,backgroundopacity);
		if(_$RenderSupportJSPixi_DFontText.getDFontInfo(fontfamily) == null) {
			var met = _$RenderSupportJSPixi_DFontText.getDFontInfo("Book");
			if(met != null) {
				Errors.print("Trying to render DFont " + fontfamily + " which is not loaded. Will use default font");
				DFontText.dfont_table[fontfamily] = met;
				fontfamily = "Book";
			} else {
				Errors.print("Trying to render DFont " + fontfamily + " which is not loaded yet. Default font is not loaded yet too");
				return;
			}
		}
		var metrics = _$RenderSupportJSPixi_DFontText.getDFontInfo(fontfamily);
		this.style.font = this.getFontString(fontfamily,fontsize);
		if(fillcolor != 0) this.style.tint = fillcolor; else this.style.tint = 65793;
		if(this.nativeWidget != null && this.nativeWidget.type == "password") this.text = this.getBulletsString(text.length); else this.text = text;
		this.baseline = metrics.ascender * fontsize;
		this.fontfamily = fontfamily;
		this.layoutText();
	}
	,getFontString: function(fontfamily,fontsize) {
		return fontsize + "px " + fontfamily;
	}
	,getTextMetrics: function() {
		var metrics = _$RenderSupportJSPixi_DFontText.getDFontInfo(this.fontfamily);
		if(metrics == null) return _$RenderSupportJSPixi_TextField.prototype.getTextMetrics.call(this);
		return [metrics.ascender * this.fontSize,metrics.descender * this.fontSize,0.15 * this.fontSize];
	}
	,getWidth: function() {
		if(this.fieldWidth != null) return this.fieldWidth;
		return this.clipWidth;
	}
	,setGLText: function(t) {
		this.text = t;
		this.layoutText();
	}
	,setWordWrap: function() {
		this.wordWrap = true;
		if(this.wordWrap && this.wordWrapWidth > 0.0) this.layoutText();
	}
	,setWordWrapWidth: function(wrap_width) {
		this.wordWrapWidth = wrap_width;
		if(this.wordWrap && this.wordWrapWidth > 0.0) this.layoutText();
	}
	,layoutText: function() {
		if(this.nativeWidget != null && this.mask != null) this.children = [this.mask]; else this.children = [];
		if(this.wordWrapWidth > 0.0 && this.wordWrap) {
			var x = 0.0;
			var y = 0.0;
			this.clipWidth = 0.0;
			var _g = 0;
			var _g1 = this.text.split("\n");
			while(_g < _g1.length) {
				var para = _g1[_g];
				++_g;
				var line_width = 0.0;
				var _g2 = 0;
				var _g3 = para.split(" ");
				while(_g2 < _g3.length) {
					var word = _g3[_g2];
					++_g2;
					var clip = new DFontText(word,this.style);
					if(_$RenderSupportJSPixi_TextField.cacheTextsAsBitmap) {
						clip.cacheAsBitmap = true;
						clip.children = _$RenderSupportJSPixi_DFontText.emptyChilds;
					}
					var word_width = clip.getTextDimensions().width;
					if(x > 0.0 && x + word_width > this.wordWrapWidth) {
						y += this.fontSize;
						x = 0.0;
					}
					clip.y = y + this.baseline;
					clip.x = x;
					clip.alpha = this.fillOpacity;
					this.addChild(clip);
					x += word_width + 0.2 * this.fontSize;
					line_width += word_width + 0.2 * this.fontSize;
				}
				y += this.fontSize;
				x = 0.0;
				this.clipWidth = Math.max(this.clipWidth,line_width - 0.2 * this.fontSize);
			}
		} else {
			var c = new DFontText(this.text,this.style);
			if(_$RenderSupportJSPixi_TextField.cacheTextsAsBitmap) {
				c.cacheAsBitmap = true;
				c.children = _$RenderSupportJSPixi_DFontText.emptyChilds;
			}
			c.y = this.baseline;
			c.alpha = this.fillOpacity;
			this.clipWidth = c.getTextDimensions().width;
			this.addChild(c);
		}
		this.setTextBackground();
	}
	,__class__: _$RenderSupportJSPixi_DFontText
});
var _$RenderSupportJSPixi_Shaders = function() { };
_$RenderSupportJSPixi_Shaders.__name__ = true;
var haxe_IMap = function() { };
haxe_IMap.__name__ = true;
var haxe_ds_IntMap = function() {
	this.h = { };
};
haxe_ds_IntMap.__name__ = true;
haxe_ds_IntMap.__interfaces__ = [haxe_IMap];
haxe_ds_IntMap.prototype = {
	get: function(key) {
		return this.h[key];
	}
	,__class__: haxe_ds_IntMap
};
var haxe_ds_StringMap = function() {
	this.h = { };
};
haxe_ds_StringMap.__name__ = true;
haxe_ds_StringMap.__interfaces__ = [haxe_IMap];
haxe_ds_StringMap.prototype = {
	set: function(key,value) {
		if(__map_reserved[key] != null) this.setReserved(key,value); else this.h[key] = value;
	}
	,get: function(key) {
		if(__map_reserved[key] != null) return this.getReserved(key);
		return this.h[key];
	}
	,exists: function(key) {
		if(__map_reserved[key] != null) return this.existsReserved(key);
		return this.h.hasOwnProperty(key);
	}
	,setReserved: function(key,value) {
		if(this.rh == null) this.rh = { };
		this.rh["$" + key] = value;
	}
	,getReserved: function(key) {
		if(this.rh == null) return null; else return this.rh["$" + key];
	}
	,existsReserved: function(key) {
		if(this.rh == null) return false;
		return this.rh.hasOwnProperty("$" + key);
	}
	,remove: function(key) {
		if(__map_reserved[key] != null) {
			key = "$" + key;
			if(this.rh == null || !this.rh.hasOwnProperty(key)) return false;
			delete(this.rh[key]);
			return true;
		} else {
			if(!this.h.hasOwnProperty(key)) return false;
			delete(this.h[key]);
			return true;
		}
	}
	,keys: function() {
		var _this = this.arrayKeys();
		return HxOverrides.iter(_this);
	}
	,arrayKeys: function() {
		var out = [];
		for( var key in this.h ) {
		if(this.h.hasOwnProperty(key)) out.push(key);
		}
		if(this.rh != null) {
			for( var key in this.rh ) {
			if(key.charCodeAt(0) == 36) out.push(key.substr(1));
			}
		}
		return out;
	}
	,__class__: haxe_ds_StringMap
};
var Test40602FlowJsProgram = function() { };
Test40602FlowJsProgram.__name__ = true;
var haxe_StackItem = { __ename__ : true, __constructs__ : ["CFunction","Module","FilePos","Method","LocalFunction"] };
haxe_StackItem.CFunction = ["CFunction",0];
haxe_StackItem.CFunction.toString = $estr;
haxe_StackItem.CFunction.__enum__ = haxe_StackItem;
haxe_StackItem.Module = function(m) { var $x = ["Module",1,m]; $x.__enum__ = haxe_StackItem; $x.toString = $estr; return $x; };
haxe_StackItem.FilePos = function(s,file,line) { var $x = ["FilePos",2,s,file,line]; $x.__enum__ = haxe_StackItem; $x.toString = $estr; return $x; };
haxe_StackItem.Method = function(classname,method) { var $x = ["Method",3,classname,method]; $x.__enum__ = haxe_StackItem; $x.toString = $estr; return $x; };
haxe_StackItem.LocalFunction = function(v) { var $x = ["LocalFunction",4,v]; $x.__enum__ = haxe_StackItem; $x.toString = $estr; return $x; };
var haxe_CallStack = function() { };
haxe_CallStack.__name__ = true;
haxe_CallStack.getStack = function(e) {
	if(e == null) return [];
	var oldValue = Error.prepareStackTrace;
	Error.prepareStackTrace = function(error,callsites) {
		var stack = [];
		var _g = 0;
		while(_g < callsites.length) {
			var site = callsites[_g];
			++_g;
			if(haxe_CallStack.wrapCallSite != null) site = haxe_CallStack.wrapCallSite(site);
			var method = null;
			var fullName = site.getFunctionName();
			if(fullName != null) {
				var idx = fullName.lastIndexOf(".");
				if(idx >= 0) {
					var className = HxOverrides.substr(fullName,0,idx);
					var methodName = HxOverrides.substr(fullName,idx + 1,null);
					method = haxe_StackItem.Method(className,methodName);
				}
			}
			stack.push(haxe_StackItem.FilePos(method,site.getFileName(),site.getLineNumber()));
		}
		return stack;
	};
	var a = haxe_CallStack.makeStack(e.stack);
	Error.prepareStackTrace = oldValue;
	return a;
};
haxe_CallStack.callStack = function() {
	try {
		throw new Error();
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		var a = haxe_CallStack.getStack(e);
		a.shift();
		return a;
	}
};
haxe_CallStack.exceptionStack = function() {
	return haxe_CallStack.getStack(haxe_CallStack.lastException);
};
haxe_CallStack.toString = function(stack) {
	var b = new StringBuf();
	var _g = 0;
	while(_g < stack.length) {
		var s = stack[_g];
		++_g;
		b.b += "\nCalled from ";
		haxe_CallStack.itemToString(b,s);
	}
	return b.b;
};
haxe_CallStack.itemToString = function(b,s) {
	switch(s[1]) {
	case 0:
		b.b += "a C function";
		break;
	case 1:
		var m = s[2];
		b.b += "module ";
		if(m == null) b.b += "null"; else b.b += "" + m;
		break;
	case 2:
		var line = s[4];
		var file = s[3];
		var s1 = s[2];
		if(s1 != null) {
			haxe_CallStack.itemToString(b,s1);
			b.b += " (";
		}
		if(file == null) b.b += "null"; else b.b += "" + file;
		b.b += " line ";
		if(line == null) b.b += "null"; else b.b += "" + line;
		if(s1 != null) b.b += ")";
		break;
	case 3:
		var meth = s[3];
		var cname = s[2];
		if(cname == null) b.b += "null"; else b.b += "" + cname;
		b.b += ".";
		if(meth == null) b.b += "null"; else b.b += "" + meth;
		break;
	case 4:
		var n = s[2];
		b.b += "local function #";
		if(n == null) b.b += "null"; else b.b += "" + n;
		break;
	}
};
haxe_CallStack.makeStack = function(s) {
	if(s == null) return []; else if(typeof(s) == "string") {
		var stack = s.split("\n");
		if(stack[0] == "Error") stack.shift();
		var m = [];
		var rie10 = new EReg("^   at ([A-Za-z0-9_. ]+) \\(([^)]+):([0-9]+):([0-9]+)\\)$","");
		var _g = 0;
		while(_g < stack.length) {
			var line = stack[_g];
			++_g;
			if(rie10.match(line)) {
				var path = rie10.matched(1).split(".");
				var meth = path.pop();
				var file = rie10.matched(2);
				var line1 = Std.parseInt(rie10.matched(3));
				m.push(haxe_StackItem.FilePos(meth == "Anonymous function"?haxe_StackItem.LocalFunction():meth == "Global code"?null:haxe_StackItem.Method(path.join("."),meth),file,line1));
			} else m.push(haxe_StackItem.Module(StringTools.trim(line)));
		}
		return m;
	} else return s;
};
var haxe__$Int64__$_$_$Int64 = function(high,low) {
	this.high = high;
	this.low = low;
};
haxe__$Int64__$_$_$Int64.__name__ = true;
haxe__$Int64__$_$_$Int64.prototype = {
	__class__: haxe__$Int64__$_$_$Int64
};
var haxe_io_BytesBuffer = function() {
	this.b = [];
};
haxe_io_BytesBuffer.__name__ = true;
haxe_io_BytesBuffer.prototype = {
	addBytes: function(src,pos,len) {
		if(pos < 0 || len < 0 || pos + len > src.length) throw new js__$Boot_HaxeError(haxe_io_Error.OutsideBounds);
		var b1 = this.b;
		var b2 = src.b;
		var _g1 = pos;
		var _g = pos + len;
		while(_g1 < _g) {
			var i = _g1++;
			this.b.push(b2[i]);
		}
	}
	,getBytes: function() {
		var bytes = new haxe_io_Bytes(new Uint8Array(this.b).buffer);
		this.b = null;
		return bytes;
	}
	,__class__: haxe_io_BytesBuffer
};
var haxe_io_Output = function() { };
haxe_io_Output.__name__ = true;
haxe_io_Output.prototype = {
	writeByte: function(c) {
		throw new js__$Boot_HaxeError("Not implemented");
	}
	,writeBytes: function(s,pos,len) {
		var k = len;
		var b = s.b.bufferValue;
		if(pos < 0 || len < 0 || pos + len > s.length) throw new js__$Boot_HaxeError(haxe_io_Error.OutsideBounds);
		while(k > 0) {
			this.writeByte(b[pos]);
			pos++;
			k--;
		}
		return len;
	}
	,writeFullBytes: function(s,pos,len) {
		while(len > 0) {
			var k = this.writeBytes(s,pos,len);
			pos += k;
			len -= k;
		}
	}
	,writeString: function(s) {
		var b = haxe_io_Bytes.ofString(s);
		this.writeFullBytes(b,0,b.length);
	}
	,__class__: haxe_io_Output
};
var haxe_io_BytesOutput = function() {
	this.b = new haxe_io_BytesBuffer();
};
haxe_io_BytesOutput.__name__ = true;
haxe_io_BytesOutput.__super__ = haxe_io_Output;
haxe_io_BytesOutput.prototype = $extend(haxe_io_Output.prototype,{
	writeByte: function(c) {
		this.b.b.push(c);
	}
	,writeBytes: function(buf,pos,len) {
		this.b.addBytes(buf,pos,len);
		return len;
	}
	,getBytes: function() {
		return this.b.getBytes();
	}
	,__class__: haxe_io_BytesOutput
});
var haxe_io_Eof = function() { };
haxe_io_Eof.__name__ = true;
haxe_io_Eof.prototype = {
	toString: function() {
		return "Eof";
	}
	,__class__: haxe_io_Eof
};
var haxe_io_Error = { __ename__ : true, __constructs__ : ["Blocked","Overflow","OutsideBounds","Custom"] };
haxe_io_Error.Blocked = ["Blocked",0];
haxe_io_Error.Blocked.toString = $estr;
haxe_io_Error.Blocked.__enum__ = haxe_io_Error;
haxe_io_Error.Overflow = ["Overflow",1];
haxe_io_Error.Overflow.toString = $estr;
haxe_io_Error.Overflow.__enum__ = haxe_io_Error;
haxe_io_Error.OutsideBounds = ["OutsideBounds",2];
haxe_io_Error.OutsideBounds.toString = $estr;
haxe_io_Error.OutsideBounds.__enum__ = haxe_io_Error;
haxe_io_Error.Custom = function(e) { var $x = ["Custom",3,e]; $x.__enum__ = haxe_io_Error; $x.toString = $estr; return $x; };
var haxe_io_FPHelper = function() { };
haxe_io_FPHelper.__name__ = true;
haxe_io_FPHelper.i32ToFloat = function(i) {
	var sign = 1 - (i >>> 31 << 1);
	var exp = i >>> 23 & 255;
	var sig = i & 8388607;
	if(sig == 0 && exp == 0) return 0.0;
	return sign * (1 + Math.pow(2,-23) * sig) * Math.pow(2,exp - 127);
};
haxe_io_FPHelper.floatToI32 = function(f) {
	if(f == 0) return 0;
	var af;
	if(f < 0) af = -f; else af = f;
	var exp = Math.floor(Math.log(af) / 0.6931471805599453);
	if(exp < -127) exp = -127; else if(exp > 128) exp = 128;
	var sig = Math.round((af / Math.pow(2,exp) - 1) * 8388608) & 8388607;
	return (f < 0?-2147483648:0) | exp + 127 << 23 | sig;
};
haxe_io_FPHelper.i64ToDouble = function(low,high) {
	var sign = 1 - (high >>> 31 << 1);
	var exp = (high >> 20 & 2047) - 1023;
	var sig = (high & 1048575) * 4294967296. + (low >>> 31) * 2147483648. + (low & 2147483647);
	if(sig == 0 && exp == -1023) return 0.0;
	return sign * (1.0 + Math.pow(2,-52) * sig) * Math.pow(2,exp);
};
haxe_io_FPHelper.doubleToI64 = function(v) {
	var i64 = haxe_io_FPHelper.i64tmp;
	if(v == 0) {
		i64.low = 0;
		i64.high = 0;
	} else {
		var av;
		if(v < 0) av = -v; else av = v;
		var exp = Math.floor(Math.log(av) / 0.6931471805599453);
		var sig;
		var v1 = (av / Math.pow(2,exp) - 1) * 4503599627370496.;
		sig = Math.round(v1);
		var sig_l = sig | 0;
		var sig_h = sig / 4294967296.0 | 0;
		i64.low = sig_l;
		i64.high = (v < 0?-2147483648:0) | exp + 1023 << 20 | sig_h;
	}
	return i64;
};
var js_BinaryBuffer = function(bigEndian,buffer) {
	this.bigEndian = bigEndian;
	this.buffer = [];
	this.setBuffer(buffer);
};
js_BinaryBuffer.__name__ = true;
js_BinaryBuffer.prototype = {
	readBits: function(start,length) {
		//shl fix: Henri Torgemane ~1996 (compressed by Jonas Raoni)
			    function shl(a, b){
				for(++b; --b; a = ((a %= 0x7fffffff + 1) & 0x40000000) == 0x40000000 ? a * 2 : (a - 0x40000000) * 2 + 0x7fffffff + 1);
				return a;
			    }
			    if(start < 0 || length <= 0)
				return 0;
			    this.checkBuffer(start + length);
			    for(var offsetLeft, offsetRight = start % 8, curByte = this.buffer.length - (start >> 3) - 1,
				lastByte = this.buffer.length + (-(start + length) >> 3), diff = curByte - lastByte,
				sum = ((this.buffer[ curByte ] >> offsetRight) & ((1 << (diff ? 8 - offsetRight : length)) - 1))
				+ (diff && (offsetLeft = (start + length) % 8) ? (this.buffer[ lastByte++ ] & ((1 << offsetLeft) - 1))
				<< (diff-- << 3) - offsetRight : 0); diff; sum += shl(this.buffer[ lastByte++ ], (diff-- << 3) - offsetRight)
			    );
			    return sum;
		;
	}
	,setBuffer: function(data) {
		if(data){
			for(var l, i = l = data.length, b = this.buffer = new Array(l); i; b[l - i] = data.charCodeAt(--i));
			this.bigEndian && b.reverse();
		    }
	}
	,hasNeededBits: function(neededBits) {
		return this.buffer.length >= -(-neededBits >> 3);
	}
	,checkBuffer: function(neededBits) {
		if(!this.hasNeededBits(neededBits)) {
			throw new Error("checkBuffer::missing bytes");;
		}
	}
	,__class__: js_BinaryBuffer
};
var js__$Boot_HaxeError = function(val) {
	Error.call(this);
	this.val = val;
	this.message = String(val);
	if(Error.captureStackTrace) Error.captureStackTrace(this,js__$Boot_HaxeError);
};
js__$Boot_HaxeError.__name__ = true;
js__$Boot_HaxeError.__super__ = Error;
js__$Boot_HaxeError.prototype = $extend(Error.prototype,{
	__class__: js__$Boot_HaxeError
});
var js_html_compat_ArrayBuffer = function(a) {
	if((a instanceof Array) && a.__enum__ == null) {
		this.a = a;
		this.byteLength = a.length;
	} else {
		var len = a;
		this.a = [];
		var _g = 0;
		while(_g < len) {
			var i = _g++;
			this.a[i] = 0;
		}
		this.byteLength = len;
	}
};
js_html_compat_ArrayBuffer.__name__ = true;
js_html_compat_ArrayBuffer.sliceImpl = function(begin,end) {
	var u = new Uint8Array(this,begin,end == null?null:end - begin);
	var result = new ArrayBuffer(u.byteLength);
	var resultArray = new Uint8Array(result);
	resultArray.set(u);
	return result;
};
js_html_compat_ArrayBuffer.prototype = {
	slice: function(begin,end) {
		return new js_html_compat_ArrayBuffer(this.a.slice(begin,end));
	}
	,__class__: js_html_compat_ArrayBuffer
};
var js_html_compat_DataView = function(buffer,byteOffset,byteLength) {
	this.buf = buffer;
	if(byteOffset == null) this.offset = 0; else this.offset = byteOffset;
	if(byteLength == null) this.length = buffer.byteLength - this.offset; else this.length = byteLength;
	if(this.offset < 0 || this.length < 0 || this.offset + this.length > buffer.byteLength) throw new js__$Boot_HaxeError(haxe_io_Error.OutsideBounds);
};
js_html_compat_DataView.__name__ = true;
js_html_compat_DataView.prototype = {
	getInt8: function(byteOffset) {
		var v = this.buf.a[this.offset + byteOffset];
		if(v >= 128) return v - 256; else return v;
	}
	,getUint8: function(byteOffset) {
		return this.buf.a[this.offset + byteOffset];
	}
	,getInt16: function(byteOffset,littleEndian) {
		var v = this.getUint16(byteOffset,littleEndian);
		if(v >= 32768) return v - 65536; else return v;
	}
	,getUint16: function(byteOffset,littleEndian) {
		if(littleEndian) return this.buf.a[this.offset + byteOffset] | this.buf.a[this.offset + byteOffset + 1] << 8; else return this.buf.a[this.offset + byteOffset] << 8 | this.buf.a[this.offset + byteOffset + 1];
	}
	,getInt32: function(byteOffset,littleEndian) {
		var p = this.offset + byteOffset;
		var a = this.buf.a[p++];
		var b = this.buf.a[p++];
		var c = this.buf.a[p++];
		var d = this.buf.a[p++];
		if(littleEndian) return a | b << 8 | c << 16 | d << 24; else return d | c << 8 | b << 16 | a << 24;
	}
	,getUint32: function(byteOffset,littleEndian) {
		var v = this.getInt32(byteOffset,littleEndian);
		if(v < 0) return v + 4294967296.; else return v;
	}
	,getFloat32: function(byteOffset,littleEndian) {
		return haxe_io_FPHelper.i32ToFloat(this.getInt32(byteOffset,littleEndian));
	}
	,getFloat64: function(byteOffset,littleEndian) {
		var a = this.getInt32(byteOffset,littleEndian);
		var b = this.getInt32(byteOffset + 4,littleEndian);
		return haxe_io_FPHelper.i64ToDouble(littleEndian?a:b,littleEndian?b:a);
	}
	,setInt8: function(byteOffset,value) {
		if(value < 0) this.buf.a[byteOffset + this.offset] = value + 128 & 255; else this.buf.a[byteOffset + this.offset] = value & 255;
	}
	,setUint8: function(byteOffset,value) {
		this.buf.a[byteOffset + this.offset] = value & 255;
	}
	,setInt16: function(byteOffset,value,littleEndian) {
		this.setUint16(byteOffset,value < 0?value + 65536:value,littleEndian);
	}
	,setUint16: function(byteOffset,value,littleEndian) {
		var p = byteOffset + this.offset;
		if(littleEndian) {
			this.buf.a[p] = value & 255;
			this.buf.a[p++] = value >> 8 & 255;
		} else {
			this.buf.a[p++] = value >> 8 & 255;
			this.buf.a[p] = value & 255;
		}
	}
	,setInt32: function(byteOffset,value,littleEndian) {
		this.setUint32(byteOffset,value,littleEndian);
	}
	,setUint32: function(byteOffset,value,littleEndian) {
		var p = byteOffset + this.offset;
		if(littleEndian) {
			this.buf.a[p++] = value & 255;
			this.buf.a[p++] = value >> 8 & 255;
			this.buf.a[p++] = value >> 16 & 255;
			this.buf.a[p++] = value >>> 24;
		} else {
			this.buf.a[p++] = value >>> 24;
			this.buf.a[p++] = value >> 16 & 255;
			this.buf.a[p++] = value >> 8 & 255;
			this.buf.a[p++] = value & 255;
		}
	}
	,setFloat32: function(byteOffset,value,littleEndian) {
		this.setUint32(byteOffset,haxe_io_FPHelper.floatToI32(value),littleEndian);
	}
	,setFloat64: function(byteOffset,value,littleEndian) {
		var i64 = haxe_io_FPHelper.doubleToI64(value);
		if(littleEndian) {
			this.setUint32(byteOffset,i64.low);
			this.setUint32(byteOffset,i64.high);
		} else {
			this.setUint32(byteOffset,i64.high);
			this.setUint32(byteOffset,i64.low);
		}
	}
	,__class__: js_html_compat_DataView
};
var js_html_compat_Uint8Array = function() { };
js_html_compat_Uint8Array.__name__ = true;
js_html_compat_Uint8Array._new = function(arg1,offset,length) {
	var arr;
	if(typeof(arg1) == "number") {
		arr = [];
		var _g = 0;
		while(_g < arg1) {
			var i = _g++;
			arr[i] = 0;
		}
		arr.byteLength = arr.length;
		arr.byteOffset = 0;
		arr.buffer = new js_html_compat_ArrayBuffer(arr);
	} else if(js_Boot.__instanceof(arg1,js_html_compat_ArrayBuffer)) {
		var buffer = arg1;
		if(offset == null) offset = 0;
		if(length == null) length = buffer.byteLength - offset;
		if(offset == 0) arr = buffer.a; else arr = buffer.a.slice(offset,offset + length);
		arr.byteLength = arr.length;
		arr.byteOffset = offset;
		arr.buffer = buffer;
	} else if((arg1 instanceof Array) && arg1.__enum__ == null) {
		arr = arg1.slice();
		arr.byteLength = arr.length;
		arr.byteOffset = 0;
		arr.buffer = new js_html_compat_ArrayBuffer(arr);
	} else throw new js__$Boot_HaxeError("TODO " + Std.string(arg1));
	arr.subarray = js_html_compat_Uint8Array._subarray;
	arr.set = js_html_compat_Uint8Array._set;
	return arr;
};
js_html_compat_Uint8Array._set = function(arg,offset) {
	var t = this;
	if(js_Boot.__instanceof(arg.buffer,js_html_compat_ArrayBuffer)) {
		var a = arg;
		if(arg.byteLength + offset > t.byteLength) throw new js__$Boot_HaxeError("set() outside of range");
		var _g1 = 0;
		var _g = arg.byteLength;
		while(_g1 < _g) {
			var i = _g1++;
			t[i + offset] = a[i];
		}
	} else if((arg instanceof Array) && arg.__enum__ == null) {
		var a1 = arg;
		if(a1.length + offset > t.byteLength) throw new js__$Boot_HaxeError("set() outside of range");
		var _g11 = 0;
		var _g2 = a1.length;
		while(_g11 < _g2) {
			var i1 = _g11++;
			t[i1 + offset] = a1[i1];
		}
	} else throw new js__$Boot_HaxeError("TODO");
};
js_html_compat_Uint8Array._subarray = function(start,end) {
	var t = this;
	var a = js_html_compat_Uint8Array._new(t.slice(start,end));
	a.byteOffset = start;
	return a;
};
if(Array.prototype.indexOf) HxOverrides.indexOf = function(a,o,i) {
	return Array.prototype.indexOf.call(a,o,i);
};
NativeHx.initBinarySerialization();
haxe_Resource.content = [{ name : "dfonts", data : "W3sibmFtZSI6IkJvb2sifSx7Im5hbWUiOiJJdGFsaWMifSx7Im5hbWUiOiJEZW1pIn0seyJuYW1lIjoiTWVkaXVtIn0seyJuYW1lIjoiTWVkaXVtSXRhbGljIn0seyJuYW1lIjoiQ29uZGVuc2VkIn0seyJuYW1lIjoiRGVqYVZ1U2FucyJ9LHsibmFtZSI6IkRlamFWdVNhbnNPYmxpcXVlIn0seyJuYW1lIjoiRGVqYVZ1U2VyaWYifSx7Im5hbWUiOiJGZWx0VGlwUm9tYW4ifSx7Im5hbWUiOiJNaW5pb24ifSx7Im5hbWUiOiJNaW5pb25JdGFsaWNzIn0seyJuYW1lIjoiTUhFZWxlbXNhbnNSZWd1bGFyIn0seyJuYW1lIjoiTm90b1NhbnMifSx7Im5hbWUiOiJQcm94aW1hU2VtaUJvbGQifSx7Im5hbWUiOiJQcm94aW1hRXh0cmFCb2xkIn0seyJuYW1lIjoiUHJveGltYVNlbWlJdGFsaWMifSx7Im5hbWUiOiJQcm94aW1hRXh0cmFJdGFsaWMifSx7Im5hbWUiOiJHb3RoYW1Cb2xkIn0seyJuYW1lIjoiR290aGFtQm9vayJ9LHsibmFtZSI6IkdvdGhhbUJvb2tJdGFsaWMifSx7Im5hbWUiOiJHb3RoYW1IVEZCb29rIn1d"},{ name : "fontstyles", data : "eyJib29rIjp7ImZhbWlseSI6ImZyYW5rbGluLWdvdGhpYy11cnciLCJ3ZWlnaHQiOjQwMCwic3R5bGUiOiJub3JtYWwifSwiZGVtaSI6eyJmYW1pbHkiOiJmcmFua2xpbi1nb3RoaWMtdXJ3Iiwid2VpZ2h0Ijo3MDAsInN0eWxlIjoibm9ybWFsIn0sInByb3hpbWFleHRyYWJvbGQiOnsiZmFtaWx5IjoicHJveGltYS1ub3ZhIiwid2VpZ2h0Ijo3MDAsInN0eWxlIjoibm9ybWFsIn0sInByb3hpbWFzZW1pYm9sZCI6eyJmYW1pbHkiOiJwcm94aW1hLW5vdmEiLCJ3ZWlnaHQiOjYwMCwic3R5bGUiOiJub3JtYWwifSwibWVkaXVtIjp7ImZhbWlseSI6ImZyYW5rbGluLWdvdGhpYy11cnciLCJ3ZWlnaHQiOjUwMCwic3R5bGUiOiJub3JtYWwifSwibWluaW9uaXRhbGljcyI6eyJmYW1pbHkiOiJtaW5pb24tcHJvIiwid2VpZ2h0Ijo0MDAsInN0eWxlIjoiaXRhbGljIn0sIml0YWxpYyI6eyJmYW1pbHkiOiJmcmFua2xpbi1nb3RoaWMtdXJ3Iiwid2VpZ2h0Ijo0MDAsInN0eWxlIjoibm9ybWFsIn0sImRlamF2dXNhbnMiOnsiZmFtaWx5IjoidmVyYS1zYW5zIiwic3R5bGUiOiJub3JtYWwifSwiY29uZGVuc2VkIjp7ImZhbWlseSI6ImZyYW5rbGluLWdvdGhpYy1leHQtY29tcC11cnciLCJ3ZWlnaHQiOjcwMCwic3R5bGUiOiJub3JtYWwifX0"},{ name : "webfontconfig", data : "eyJ0eXBla2l0Ijp7ImlkIjoiaGZ6NnVmeiJ9fQ"}];
String.prototype.__class__ = String;
String.__name__ = true;
Array.__name__ = true;
Date.prototype.__class__ = Date;
Date.__name__ = ["Date"];
var Int = { __name__ : ["Int"]};
var Dynamic = { __name__ : ["Dynamic"]};
var Float = Number;
Float.__name__ = ["Float"];
var Bool = Boolean;
Bool.__ename__ = ["Bool"];
var Class = { __name__ : ["Class"]};
var Enum = { };
if(Array.prototype.filter == null) Array.prototype.filter = function(f1) {
	var a1 = [];
	var _g11 = 0;
	var _g2 = this.length;
	while(_g11 < _g2) {
		var i1 = _g11++;
		var e = this[i1];
		if(f1(e)) a1.push(e);
	}
	return a1;
};
if(Util.getParameter("oldjs") == "1") RenderSupportHx.oldinit(); else {
	window.RenderSupportHx = window.RenderSupportJSPixi;
}
var __map_reserved = {}
var ArrayBuffer = $global.ArrayBuffer || js_html_compat_ArrayBuffer;
if(ArrayBuffer.prototype.slice == null) ArrayBuffer.prototype.slice = js_html_compat_ArrayBuffer.sliceImpl;
var DataView = $global.DataView || js_html_compat_DataView;
var Uint8Array = $global.Uint8Array || js_html_compat_Uint8Array._new;
Md5.inst = new Md5();
NativeHx.clipboardData = "";
NativeHx.FlowCrashHandlers = [];
NativeHx.PlatformEventListeners = new haxe_ds_StringMap();
Util.filesCache = new haxe_ds_StringMap();
Util.filesHashCache = new haxe_ds_StringMap();
_$RenderSupportHx_Graphics.svgns = "http://www.w3.org/2000/svg";
haxe_crypto_Base64.CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
haxe_crypto_Base64.BYTES = haxe_io_Bytes.ofString(haxe_crypto_Base64.CHARS);
js_Boot.__toStr = {}.toString;
RenderSupportHx.typekitTryCount = 0;
RenderSupportHx.WebClipInitSize = 100.0;
_$RenderSupportJSPixi_TextField.cacheTextsAsBitmap = false;
_$RenderSupportJSPixi_TextField.Zerro = new PIXI.Point(0.0,0.0);
_$RenderSupportJSPixi_TextField.One = new PIXI.Point(1.0,1.0);
_$RenderSupportJSPixi_VideoClip.UsePixiTextures = false;
_$RenderSupportJSPixi_VideoClip.VideosOnStage = 0;
RenderSupportJSPixi.PixiStage = new PIXI.Container();
RenderSupportJSPixi.NativeWidgetClips = [];
RenderSupportJSPixi.AccessWidgetClips = [];
RenderSupportJSPixi.MousePos = new PIXI.Point(0.0,0.0);
RenderSupportJSPixi.PixiStageChanged = true;
RenderSupportJSPixi.PixiStageSizeChanged = false;
RenderSupportJSPixi.DebugMode = Util.getParameter("rendebug") == "1" && !NativeHx.isTouchScreen() || Util.getParameter("rendebug") == "2";
RenderSupportJSPixi.UseDFont = Util.getParameter("dfont") != "0" && Util.getParameter("lang") != "zh";
RenderSupportJSPixi.ShowDebugClipsTree = Util.getParameter("clipstree") == "1";
RenderSupportJSPixi.CacheTextsAsBitmap = Util.getParameter("cachetext") == "1";
RenderSupportJSPixi.Antialias = Util.getParameter("antialias") != null?Util.getParameter("antialias") == "1":!NativeHx.isTouchScreen();
RenderSupportJSPixi.RendererType = Util.getParameter("renderer") != null?Util.getParameter("renderer"):window.useRenderer;
RenderSupportJSPixi.UseVideoTextures = Util.getParameter("videotexture") != "0";
RenderSupportJSPixi.isAndroid = window.navigator.userAgent.toLowerCase().indexOf("android") >= 0;
RenderSupportJSPixi.RenderSupportJSPixiInitialised = RenderSupportJSPixi.init();
RenderSupportJSPixi.MouseUpReceived = false;
RenderSupportJSPixi.FlowMainFunction = "flow_main";
RenderSupportJSPixi.StageChangedTimestamp = -1.0;
RenderSupportJSPixi.sharedText = new PIXI.Text("");
RenderSupportJSPixi.IsFullScreen = false;
_$RenderSupportJSPixi_DFontText.defaultFontFamily = "Book";
_$RenderSupportJSPixi_DFontText.emptyChilds = [];
_$RenderSupportJSPixi_Shaders.GlowFragmentSrc = ["precision lowp float;","varying vec2 vTextureCoord;","varying vec4 vColor;","uniform sampler2D uSampler;","void main() {","vec4 sum = vec4(0);","vec2 texcoord = vTextureCoord;","for(int xx = -4; xx <= 4; xx++) {","for(int yy = -3; yy <= 3; yy++) {","float dist = sqrt(float(xx*xx) + float(yy*yy));","float factor = 0.0;","if (dist == 0.0) {","factor = 2.0;","} else {","factor = 2.0/abs(float(dist));","}","sum += texture2D(uSampler, texcoord + vec2(xx, yy) * 0.002) * factor;","}","}","gl_FragColor = sum * 0.025 + texture2D(uSampler, texcoord);","}"];
_$RenderSupportJSPixi_Shaders.VertexSrc = ["attribute vec2 aVertexPosition;","attribute vec2 aTextureCoord;","attribute vec4 aColor;","uniform mat3 projectionMatrix;","varying vec2 vTextureCoord;","varying vec4 vColor;","void main(void)","{","gl_Position = vec4((projectionMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);","vTextureCoord = aTextureCoord;","vColor = vec4(aColor.rgb * aColor.a, aColor.a);","}"];
Test40602FlowJsProgram.globals__ = (function($this) {
	var $r;
	HaxeRuntime._structnames_ = new haxe_ds_IntMap();
	HaxeRuntime._structids_ = new haxe_ds_StringMap();
	HaxeRuntime._structargs_ = new haxe_ds_IntMap();
	HaxeRuntime._structargtypes_ = new haxe_ds_IntMap();
	$r = new RenderSupportHx();
	return $r;
}(this));
haxe_io_FPHelper.i64tmp = (function($this) {
	var $r;
	var x = new haxe__$Int64__$_$_$Int64(0,0);
	$r = x;
	return $r;
}(this));
js_html_compat_Uint8Array.BYTES_PER_ELEMENT = 1;
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


function proxy_NativeHx_println(baseptr,slotptr)
{
    NativeHx.println(decode_flow_data(baseptr, slotptr));

    Module.ccall("test_call", 'number', ['number', 'string'], [123, "blah"]);
}

function init_proxy() {
    
}

// The Module object: Our interface to the outside world. We import
// and export values on it, and do the work to get that through
// closure compiler if necessary. There are various ways Module can be used:
// 1. Not defined. We create it here
// 2. A function parameter, function(Module) { ..generated code.. }
// 3. pre-run appended it, var Module = {}; ..generated code..
// 4. External script tag defines var Module.
// We need to do an eval in order to handle the closure compiler
// case, where this code here is minified but Module was defined
// elsewhere (e.g. case 4 above). We also need to check if Module
// already exists (e.g. case 3 above).
// Note that if you want to run closure, and also to use Module
// after the generated code, you will need to define   var Module = {};
// before the code. Then that object will be used in the code, and you
// can continue to use Module afterwards as well.
var Module;
if (!Module) Module = (typeof Module !== 'undefined' ? Module : null) || {};

// Sometimes an existing Module object exists with properties
// meant to overwrite the default module functionality. Here
// we collect those properties and reapply _after_ we configure
// the current environment's defaults to avoid having to be so
// defensive during initialization.
var moduleOverrides = {};
for (var key in Module) {
  if (Module.hasOwnProperty(key)) {
    moduleOverrides[key] = Module[key];
  }
}

// The environment setup code below is customized to use Module.
// *** Environment setup code ***
var ENVIRONMENT_IS_WEB = false;
var ENVIRONMENT_IS_WORKER = false;
var ENVIRONMENT_IS_NODE = false;
var ENVIRONMENT_IS_SHELL = false;

// Three configurations we can be running in:
// 1) We could be the application main() thread running in the main JS UI thread. (ENVIRONMENT_IS_WORKER == false and ENVIRONMENT_IS_PTHREAD == false)
// 2) We could be the application main() thread proxied to worker. (with Emscripten -s PROXY_TO_WORKER=1) (ENVIRONMENT_IS_WORKER == true, ENVIRONMENT_IS_PTHREAD == false)
// 3) We could be an application pthread running in a worker. (ENVIRONMENT_IS_WORKER == true and ENVIRONMENT_IS_PTHREAD == true)

if (Module['ENVIRONMENT']) {
  if (Module['ENVIRONMENT'] === 'WEB') {
    ENVIRONMENT_IS_WEB = true;
  } else if (Module['ENVIRONMENT'] === 'WORKER') {
    ENVIRONMENT_IS_WORKER = true;
  } else if (Module['ENVIRONMENT'] === 'NODE') {
    ENVIRONMENT_IS_NODE = true;
  } else if (Module['ENVIRONMENT'] === 'SHELL') {
    ENVIRONMENT_IS_SHELL = true;
  } else {
    throw new Error('The provided Module[\'ENVIRONMENT\'] value is not valid. It must be one of: WEB|WORKER|NODE|SHELL.');
  }
} else {
  ENVIRONMENT_IS_WEB = typeof window === 'object';
  ENVIRONMENT_IS_WORKER = typeof importScripts === 'function';
  ENVIRONMENT_IS_NODE = typeof process === 'object' && typeof require === 'function' && !ENVIRONMENT_IS_WEB && !ENVIRONMENT_IS_WORKER;
  ENVIRONMENT_IS_SHELL = !ENVIRONMENT_IS_WEB && !ENVIRONMENT_IS_NODE && !ENVIRONMENT_IS_WORKER;
}


if (ENVIRONMENT_IS_NODE) {
  // Expose functionality in the same simple way that the shells work
  // Note that we pollute the global namespace here, otherwise we break in node
  if (!Module['print']) Module['print'] = console.log;
  if (!Module['printErr']) Module['printErr'] = console.warn;

  var nodeFS;
  var nodePath;

  Module['read'] = function read(filename, binary) {
    if (!nodeFS) nodeFS = require('fs');
    if (!nodePath) nodePath = require('path');
    filename = nodePath['normalize'](filename);
    var ret = nodeFS['readFileSync'](filename);
    return binary ? ret : ret.toString();
  };

  Module['readBinary'] = function readBinary(filename) {
    var ret = Module['read'](filename, true);
    if (!ret.buffer) {
      ret = new Uint8Array(ret);
    }
    assert(ret.buffer);
    return ret;
  };

  Module['load'] = function load(f) {
    globalEval(read(f));
  };

  if (!Module['thisProgram']) {
    if (process['argv'].length > 1) {
      Module['thisProgram'] = process['argv'][1].replace(/\\/g, '/');
    } else {
      Module['thisProgram'] = 'unknown-program';
    }
  }

  Module['arguments'] = process['argv'].slice(2);

  if (typeof module !== 'undefined') {
    module['exports'] = Module;
  }

  process['on']('uncaughtException', function(ex) {
    // suppress ExitStatus exceptions from showing an error
    if (!(ex instanceof ExitStatus)) {
      throw ex;
    }
  });

  Module['inspect'] = function () { return '[Emscripten Module object]'; };
}
else if (ENVIRONMENT_IS_SHELL) {
  if (!Module['print']) Module['print'] = print;
  if (typeof printErr != 'undefined') Module['printErr'] = printErr; // not present in v8 or older sm

  if (typeof read != 'undefined') {
    Module['read'] = read;
  } else {
    Module['read'] = function read() { throw 'no read() available' };
  }

  Module['readBinary'] = function readBinary(f) {
    if (typeof readbuffer === 'function') {
      return new Uint8Array(readbuffer(f));
    }
    var data = read(f, 'binary');
    assert(typeof data === 'object');
    return data;
  };

  if (typeof scriptArgs != 'undefined') {
    Module['arguments'] = scriptArgs;
  } else if (typeof arguments != 'undefined') {
    Module['arguments'] = arguments;
  }

}
else if (ENVIRONMENT_IS_WEB || ENVIRONMENT_IS_WORKER) {
  Module['read'] = function read(url) {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', url, false);
    xhr.send(null);
    return xhr.responseText;
  };

  Module['readAsync'] = function readAsync(url, onload, onerror) {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', url, true);
    xhr.responseType = 'arraybuffer';
    xhr.onload = function xhr_onload() {
      if (xhr.status == 200 || (xhr.status == 0 && xhr.response)) { // file URLs can return 0
        onload(xhr.response);
      } else {
        onerror();
      }
    };
    xhr.onerror = onerror;
    xhr.send(null);
  };

  if (typeof arguments != 'undefined') {
    Module['arguments'] = arguments;
  }

  if (typeof console !== 'undefined') {
    if (!Module['print']) Module['print'] = function print(x) {
      console.log(x);
    };
    if (!Module['printErr']) Module['printErr'] = function printErr(x) {
      console.warn(x);
    };
  } else {
    // Probably a worker, and without console.log. We can do very little here...
    var TRY_USE_DUMP = false;
    if (!Module['print']) Module['print'] = (TRY_USE_DUMP && (typeof(dump) !== "undefined") ? (function(x) {
      dump(x);
    }) : (function(x) {
      // self.postMessage(x); // enable this if you want stdout to be sent as messages
    }));
  }

  if (ENVIRONMENT_IS_WORKER) {
    Module['load'] = importScripts;
  }

  if (typeof Module['setWindowTitle'] === 'undefined') {
    Module['setWindowTitle'] = function(title) { document.title = title };
  }
}
else {
  // Unreachable because SHELL is dependant on the others
  throw 'Unknown runtime environment. Where are we?';
}

function globalEval(x) {
  eval.call(null, x);
}
if (!Module['load'] && Module['read']) {
  Module['load'] = function load(f) {
    globalEval(Module['read'](f));
  };
}
if (!Module['print']) {
  Module['print'] = function(){};
}
if (!Module['printErr']) {
  Module['printErr'] = Module['print'];
}
if (!Module['arguments']) {
  Module['arguments'] = [];
}
if (!Module['thisProgram']) {
  Module['thisProgram'] = './this.program';
}

// *** Environment setup code ***

// Closure helpers
Module.print = Module['print'];
Module.printErr = Module['printErr'];

// Callbacks
Module['preRun'] = [];
Module['postRun'] = [];

// Merge back in the overrides
for (var key in moduleOverrides) {
  if (moduleOverrides.hasOwnProperty(key)) {
    Module[key] = moduleOverrides[key];
  }
}
// Free the object hierarchy contained in the overrides, this lets the GC
// reclaim data used e.g. in memoryInitializerRequest, which is a large typed array.
moduleOverrides = undefined;



// {{PREAMBLE_ADDITIONS}}

// === Preamble library stuff ===

// Documentation for the public APIs defined in this file must be updated in:
//    site/source/docs/api_reference/preamble.js.rst
// A prebuilt local version of the documentation is available at:
//    site/build/text/docs/api_reference/preamble.js.txt
// You can also build docs locally as HTML or other formats in site/
// An online HTML version (which may be of a different version of Emscripten)
//    is up at http://kripken.github.io/emscripten-site/docs/api_reference/preamble.js.html

//========================================
// Runtime code shared with compiler
//========================================

var Runtime = {
  setTempRet0: function (value) {
    tempRet0 = value;
    return value;
  },
  getTempRet0: function () {
    return tempRet0;
  },
  stackSave: function () {
    return STACKTOP;
  },
  stackRestore: function (stackTop) {
    STACKTOP = stackTop;
  },
  getNativeTypeSize: function (type) {
    switch (type) {
      case 'i1': case 'i8': return 1;
      case 'i16': return 2;
      case 'i32': return 4;
      case 'i64': return 8;
      case 'float': return 4;
      case 'double': return 8;
      default: {
        if (type[type.length-1] === '*') {
          return Runtime.QUANTUM_SIZE; // A pointer
        } else if (type[0] === 'i') {
          var bits = parseInt(type.substr(1));
          assert(bits % 8 === 0);
          return bits/8;
        } else {
          return 0;
        }
      }
    }
  },
  getNativeFieldSize: function (type) {
    return Math.max(Runtime.getNativeTypeSize(type), Runtime.QUANTUM_SIZE);
  },
  STACK_ALIGN: 16,
  prepVararg: function (ptr, type) {
    if (type === 'double' || type === 'i64') {
      // move so the load is aligned
      if (ptr & 7) {
        assert((ptr & 7) === 4);
        ptr += 4;
      }
    } else {
      assert((ptr & 3) === 0);
    }
    return ptr;
  },
  getAlignSize: function (type, size, vararg) {
    // we align i64s and doubles on 64-bit boundaries, unlike x86
    if (!vararg && (type == 'i64' || type == 'double')) return 8;
    if (!type) return Math.min(size, 8); // align structures internally to 64 bits
    return Math.min(size || (type ? Runtime.getNativeFieldSize(type) : 0), Runtime.QUANTUM_SIZE);
  },
  dynCall: function (sig, ptr, args) {
    if (args && args.length) {
      assert(args.length == sig.length-1);
      assert(('dynCall_' + sig) in Module, 'bad function pointer type - no table for sig \'' + sig + '\'');
      return Module['dynCall_' + sig].apply(null, [ptr].concat(args));
    } else {
      assert(sig.length == 1);
      assert(('dynCall_' + sig) in Module, 'bad function pointer type - no table for sig \'' + sig + '\'');
      return Module['dynCall_' + sig].call(null, ptr);
    }
  },
  functionPointers: [],
  addFunction: function (func) {
    for (var i = 0; i < Runtime.functionPointers.length; i++) {
      if (!Runtime.functionPointers[i]) {
        Runtime.functionPointers[i] = func;
        return 2*(1 + i);
      }
    }
    throw 'Finished up all reserved function pointers. Use a higher value for RESERVED_FUNCTION_POINTERS.';
  },
  removeFunction: function (index) {
    Runtime.functionPointers[(index-2)/2] = null;
  },
  warnOnce: function (text) {
    if (!Runtime.warnOnce.shown) Runtime.warnOnce.shown = {};
    if (!Runtime.warnOnce.shown[text]) {
      Runtime.warnOnce.shown[text] = 1;
      Module.printErr(text);
    }
  },
  funcWrappers: {},
  getFuncWrapper: function (func, sig) {
    assert(sig);
    if (!Runtime.funcWrappers[sig]) {
      Runtime.funcWrappers[sig] = {};
    }
    var sigCache = Runtime.funcWrappers[sig];
    if (!sigCache[func]) {
      // optimize away arguments usage in common cases
      if (sig.length === 1) {
        sigCache[func] = function dynCall_wrapper() {
          return Runtime.dynCall(sig, func);
        };
      } else if (sig.length === 2) {
        sigCache[func] = function dynCall_wrapper(arg) {
          return Runtime.dynCall(sig, func, [arg]);
        };
      } else {
        // general case
        sigCache[func] = function dynCall_wrapper() {
          return Runtime.dynCall(sig, func, Array.prototype.slice.call(arguments));
        };
      }
    }
    return sigCache[func];
  },
  getCompilerSetting: function (name) {
    throw 'You must build with -s RETAIN_COMPILER_SETTINGS=1 for Runtime.getCompilerSetting or emscripten_get_compiler_setting to work';
  },
  stackAlloc: function (size) { var ret = STACKTOP;STACKTOP = (STACKTOP + size)|0;STACKTOP = (((STACKTOP)+15)&-16);(assert((((STACKTOP|0) < (STACK_MAX|0))|0))|0); return ret; },
  staticAlloc: function (size) { var ret = STATICTOP;STATICTOP = (STATICTOP + (assert(!staticSealed),size))|0;STATICTOP = (((STATICTOP)+15)&-16); return ret; },
  dynamicAlloc: function (size) { assert(DYNAMICTOP_PTR);var ret = HEAP32[DYNAMICTOP_PTR>>2];var end = (((ret + size + 15)|0) & -16);HEAP32[DYNAMICTOP_PTR>>2] = end;if (end >= TOTAL_MEMORY) {var success = enlargeMemory();if (!success) {HEAP32[DYNAMICTOP_PTR>>2] = ret;return 0;}}return ret;},
  alignMemory: function (size,quantum) { var ret = size = Math.ceil((size)/(quantum ? quantum : 16))*(quantum ? quantum : 16); return ret; },
  makeBigInt: function (low,high,unsigned) { var ret = (unsigned ? ((+((low>>>0)))+((+((high>>>0)))*4294967296.0)) : ((+((low>>>0)))+((+((high|0)))*4294967296.0))); return ret; },
  GLOBAL_BASE: 1024,
  QUANTUM_SIZE: 4,
  __dummy__: 0
}



Module["Runtime"] = Runtime;



//========================================
// Runtime essentials
//========================================

var ABORT = 0; // whether we are quitting the application. no code should run after this. set in exit() and abort()
var EXITSTATUS = 0;

function assert(condition, text) {
  if (!condition) {
    abort('Assertion failed: ' + text);
  }
}

var globalScope = this;

// Returns the C function with a specified identifier (for C++, you need to do manual name mangling)
function getCFunc(ident) {
  var func = Module['_' + ident]; // closure exported function
  if (!func) {
    try { func = eval('_' + ident); } catch(e) {}
  }
  assert(func, 'Cannot call unknown function ' + ident + ' (perhaps LLVM optimizations or closure removed it?)');
  return func;
}

var cwrap, ccall;
(function(){
  var JSfuncs = {
    // Helpers for cwrap -- it can't refer to Runtime directly because it might
    // be renamed by closure, instead it calls JSfuncs['stackSave'].body to find
    // out what the minified function name is.
    'stackSave': function() {
      Runtime.stackSave()
    },
    'stackRestore': function() {
      Runtime.stackRestore()
    },
    // type conversion from js to c
    'arrayToC' : function(arr) {
      var ret = Runtime.stackAlloc(arr.length);
      writeArrayToMemory(arr, ret);
      return ret;
    },
    'stringToC' : function(str) {
      var ret = 0;
      if (str !== null && str !== undefined && str !== 0) { // null string
        // at most 4 bytes per UTF-8 code point, +1 for the trailing '\0'
        var len = (str.length << 2) + 1;
        ret = Runtime.stackAlloc(len);
        stringToUTF8(str, ret, len);
      }
      return ret;
    }
  };
  // For fast lookup of conversion functions
  var toC = {'string' : JSfuncs['stringToC'], 'array' : JSfuncs['arrayToC']};

  // C calling interface.
  ccall = function ccallFunc(ident, returnType, argTypes, args, opts) {
    var func = getCFunc(ident);
    var cArgs = [];
    var stack = 0;
    assert(returnType !== 'array', 'Return type should not be "array".');
    if (args) {
      for (var i = 0; i < args.length; i++) {
        var converter = toC[argTypes[i]];
        if (converter) {
          if (stack === 0) stack = Runtime.stackSave();
          cArgs[i] = converter(args[i]);
        } else {
          cArgs[i] = args[i];
        }
      }
    }
    var ret = func.apply(null, cArgs);
    if ((!opts || !opts.async) && typeof EmterpreterAsync === 'object') {
      assert(!EmterpreterAsync.state, 'cannot start async op with normal JS calling ccall');
    }
    if (opts && opts.async) assert(!returnType, 'async ccalls cannot return values');
    if (returnType === 'string') ret = Pointer_stringify(ret);
    if (stack !== 0) {
      if (opts && opts.async) {
        EmterpreterAsync.asyncFinalizers.push(function() {
          Runtime.stackRestore(stack);
        });
        return;
      }
      Runtime.stackRestore(stack);
    }
    return ret;
  }

  var sourceRegex = /^function\s*[a-zA-Z$_0-9]*\s*\(([^)]*)\)\s*{\s*([^*]*?)[\s;]*(?:return\s*(.*?)[;\s]*)?}$/;
  function parseJSFunc(jsfunc) {
    // Match the body and the return value of a javascript function source
    var parsed = jsfunc.toString().match(sourceRegex).slice(1);
    return {arguments : parsed[0], body : parsed[1], returnValue: parsed[2]}
  }

  // sources of useful functions. we create this lazily as it can trigger a source decompression on this entire file
  var JSsource = null;
  function ensureJSsource() {
    if (!JSsource) {
      JSsource = {};
      for (var fun in JSfuncs) {
        if (JSfuncs.hasOwnProperty(fun)) {
          // Elements of toCsource are arrays of three items:
          // the code, and the return value
          JSsource[fun] = parseJSFunc(JSfuncs[fun]);
        }
      }
    }
  }

  cwrap = function cwrap(ident, returnType, argTypes) {
    argTypes = argTypes || [];
    var cfunc = getCFunc(ident);
    // When the function takes numbers and returns a number, we can just return
    // the original function
    var numericArgs = argTypes.every(function(type){ return type === 'number'});
    var numericRet = (returnType !== 'string');
    if ( numericRet && numericArgs) {
      return cfunc;
    }
    // Creation of the arguments list (["$1","$2",...,"$nargs"])
    var argNames = argTypes.map(function(x,i){return '$'+i});
    var funcstr = "(function(" + argNames.join(',') + ") {";
    var nargs = argTypes.length;
    if (!numericArgs) {
      // Generate the code needed to convert the arguments from javascript
      // values to pointers
      ensureJSsource();
      funcstr += 'var stack = ' + JSsource['stackSave'].body + ';';
      for (var i = 0; i < nargs; i++) {
        var arg = argNames[i], type = argTypes[i];
        if (type === 'number') continue;
        var convertCode = JSsource[type + 'ToC']; // [code, return]
        funcstr += 'var ' + convertCode.arguments + ' = ' + arg + ';';
        funcstr += convertCode.body + ';';
        funcstr += arg + '=(' + convertCode.returnValue + ');';
      }
    }

    // When the code is compressed, the name of cfunc is not literally 'cfunc' anymore
    var cfuncname = parseJSFunc(function(){return cfunc}).returnValue;
    // Call the function
    funcstr += 'var ret = ' + cfuncname + '(' + argNames.join(',') + ');';
    if (!numericRet) { // Return type can only by 'string' or 'number'
      // Convert the result to a string
      var strgfy = parseJSFunc(function(){return Pointer_stringify}).returnValue;
      funcstr += 'ret = ' + strgfy + '(ret);';
    }
    funcstr += "if (typeof EmterpreterAsync === 'object') { assert(!EmterpreterAsync.state, 'cannot start async op with normal JS calling cwrap') }";
    if (!numericArgs) {
      // If we had a stack, restore it
      ensureJSsource();
      funcstr += JSsource['stackRestore'].body.replace('()', '(stack)') + ';';
    }
    funcstr += 'return ret})';
    return eval(funcstr);
  };
})();
Module["ccall"] = ccall;
Module["cwrap"] = cwrap;

function setValue(ptr, value, type, noSafe) {
  type = type || 'i8';
  if (type.charAt(type.length-1) === '*') type = 'i32'; // pointers are 32-bit
    switch(type) {
      case 'i1': HEAP8[((ptr)>>0)]=value; break;
      case 'i8': HEAP8[((ptr)>>0)]=value; break;
      case 'i16': HEAP16[((ptr)>>1)]=value; break;
      case 'i32': HEAP32[((ptr)>>2)]=value; break;
      case 'i64': (tempI64 = [value>>>0,(tempDouble=value,(+(Math_abs(tempDouble))) >= 1.0 ? (tempDouble > 0.0 ? ((Math_min((+(Math_floor((tempDouble)/4294967296.0))), 4294967295.0))|0)>>>0 : (~~((+(Math_ceil((tempDouble - +(((~~(tempDouble)))>>>0))/4294967296.0)))))>>>0) : 0)],HEAP32[((ptr)>>2)]=tempI64[0],HEAP32[(((ptr)+(4))>>2)]=tempI64[1]); break;
      case 'float': HEAPF32[((ptr)>>2)]=value; break;
      case 'double': HEAPF64[((ptr)>>3)]=value; break;
      default: abort('invalid type for setValue: ' + type);
    }
}
Module["setValue"] = setValue;


function getValue(ptr, type, noSafe) {
  type = type || 'i8';
  if (type.charAt(type.length-1) === '*') type = 'i32'; // pointers are 32-bit
    switch(type) {
      case 'i1': return HEAP8[((ptr)>>0)];
      case 'i8': return HEAP8[((ptr)>>0)];
      case 'i16': return HEAP16[((ptr)>>1)];
      case 'i32': return HEAP32[((ptr)>>2)];
      case 'i64': return HEAP32[((ptr)>>2)];
      case 'float': return HEAPF32[((ptr)>>2)];
      case 'double': return HEAPF64[((ptr)>>3)];
      default: abort('invalid type for setValue: ' + type);
    }
  return null;
}
Module["getValue"] = getValue;

var ALLOC_NORMAL = 0; // Tries to use _malloc()
var ALLOC_STACK = 1; // Lives for the duration of the current function call
var ALLOC_STATIC = 2; // Cannot be freed
var ALLOC_DYNAMIC = 3; // Cannot be freed except through sbrk
var ALLOC_NONE = 4; // Do not allocate
Module["ALLOC_NORMAL"] = ALLOC_NORMAL;
Module["ALLOC_STACK"] = ALLOC_STACK;
Module["ALLOC_STATIC"] = ALLOC_STATIC;
Module["ALLOC_DYNAMIC"] = ALLOC_DYNAMIC;
Module["ALLOC_NONE"] = ALLOC_NONE;

// allocate(): This is for internal use. You can use it yourself as well, but the interface
//             is a little tricky (see docs right below). The reason is that it is optimized
//             for multiple syntaxes to save space in generated code. So you should
//             normally not use allocate(), and instead allocate memory using _malloc(),
//             initialize it with setValue(), and so forth.
// @slab: An array of data, or a number. If a number, then the size of the block to allocate,
//        in *bytes* (note that this is sometimes confusing: the next parameter does not
//        affect this!)
// @types: Either an array of types, one for each byte (or 0 if no type at that position),
//         or a single type which is used for the entire block. This only matters if there
//         is initial data - if @slab is a number, then this does not matter at all and is
//         ignored.
// @allocator: How to allocate memory, see ALLOC_*
function allocate(slab, types, allocator, ptr) {
  var zeroinit, size;
  if (typeof slab === 'number') {
    zeroinit = true;
    size = slab;
  } else {
    zeroinit = false;
    size = slab.length;
  }

  var singleType = typeof types === 'string' ? types : null;

  var ret;
  if (allocator == ALLOC_NONE) {
    ret = ptr;
  } else {
    ret = [typeof _malloc === 'function' ? _malloc : Runtime.staticAlloc, Runtime.stackAlloc, Runtime.staticAlloc, Runtime.dynamicAlloc][allocator === undefined ? ALLOC_STATIC : allocator](Math.max(size, singleType ? 1 : types.length));
  }

  if (zeroinit) {
    var ptr = ret, stop;
    assert((ret & 3) == 0);
    stop = ret + (size & ~3);
    for (; ptr < stop; ptr += 4) {
      HEAP32[((ptr)>>2)]=0;
    }
    stop = ret + size;
    while (ptr < stop) {
      HEAP8[((ptr++)>>0)]=0;
    }
    return ret;
  }

  if (singleType === 'i8') {
    if (slab.subarray || slab.slice) {
      HEAPU8.set(slab, ret);
    } else {
      HEAPU8.set(new Uint8Array(slab), ret);
    }
    return ret;
  }

  var i = 0, type, typeSize, previousType;
  while (i < size) {
    var curr = slab[i];

    if (typeof curr === 'function') {
      curr = Runtime.getFunctionIndex(curr);
    }

    type = singleType || types[i];
    if (type === 0) {
      i++;
      continue;
    }
    assert(type, 'Must know what type to store in allocate!');

    if (type == 'i64') type = 'i32'; // special case: we have one i32 here, and one i32 later

    setValue(ret+i, curr, type);

    // no need to look up size unless type changes, so cache it
    if (previousType !== type) {
      typeSize = Runtime.getNativeTypeSize(type);
      previousType = type;
    }
    i += typeSize;
  }

  return ret;
}
Module["allocate"] = allocate;

// Allocate memory during any stage of startup - static memory early on, dynamic memory later, malloc when ready
function getMemory(size) {
  if (!staticSealed) return Runtime.staticAlloc(size);
  if (!runtimeInitialized) return Runtime.dynamicAlloc(size);
  return _malloc(size);
}
Module["getMemory"] = getMemory;

function Pointer_stringify(ptr, /* optional */ length) {
  if (length === 0 || !ptr) return '';
  // TODO: use TextDecoder
  // Find the length, and check for UTF while doing so
  var hasUtf = 0;
  var t;
  var i = 0;
  while (1) {
    assert(ptr + i < TOTAL_MEMORY);
    t = HEAPU8[(((ptr)+(i))>>0)];
    hasUtf |= t;
    if (t == 0 && !length) break;
    i++;
    if (length && i == length) break;
  }
  if (!length) length = i;

  var ret = '';

  if (hasUtf < 128) {
    var MAX_CHUNK = 1024; // split up into chunks, because .apply on a huge string can overflow the stack
    var curr;
    while (length > 0) {
      curr = String.fromCharCode.apply(String, HEAPU8.subarray(ptr, ptr + Math.min(length, MAX_CHUNK)));
      ret = ret ? ret + curr : curr;
      ptr += MAX_CHUNK;
      length -= MAX_CHUNK;
    }
    return ret;
  }
  return Module['UTF8ToString'](ptr);
}
Module["Pointer_stringify"] = Pointer_stringify;

// Given a pointer 'ptr' to a null-terminated ASCII-encoded string in the emscripten HEAP, returns
// a copy of that string as a Javascript String object.

function AsciiToString(ptr) {
  var str = '';
  while (1) {
    var ch = HEAP8[((ptr++)>>0)];
    if (!ch) return str;
    str += String.fromCharCode(ch);
  }
}
Module["AsciiToString"] = AsciiToString;

// Copies the given Javascript String object 'str' to the emscripten HEAP at address 'outPtr',
// null-terminated and encoded in ASCII form. The copy will require at most str.length+1 bytes of space in the HEAP.

function stringToAscii(str, outPtr) {
  return writeAsciiToMemory(str, outPtr, false);
}
Module["stringToAscii"] = stringToAscii;

// Given a pointer 'ptr' to a null-terminated UTF8-encoded string in the given array that contains uint8 values, returns
// a copy of that string as a Javascript String object.

var UTF8Decoder = typeof TextDecoder !== 'undefined' ? new TextDecoder('utf8') : undefined;
function UTF8ArrayToString(u8Array, idx) {
  var endPtr = idx;
  // TextDecoder needs to know the byte length in advance, it doesn't stop on null terminator by itself.
  // Also, use the length info to avoid running tiny strings through TextDecoder, since .subarray() allocates garbage.
  while (u8Array[endPtr]) ++endPtr;

  if (endPtr - idx > 16 && u8Array.subarray && UTF8Decoder) {
    return UTF8Decoder.decode(u8Array.subarray(idx, endPtr));
  } else {
    var u0, u1, u2, u3, u4, u5;

    var str = '';
    while (1) {
      // For UTF8 byte structure, see http://en.wikipedia.org/wiki/UTF-8#Description and https://www.ietf.org/rfc/rfc2279.txt and https://tools.ietf.org/html/rfc3629
      u0 = u8Array[idx++];
      if (!u0) return str;
      if (!(u0 & 0x80)) { str += String.fromCharCode(u0); continue; }
      u1 = u8Array[idx++] & 63;
      if ((u0 & 0xE0) == 0xC0) { str += String.fromCharCode(((u0 & 31) << 6) | u1); continue; }
      u2 = u8Array[idx++] & 63;
      if ((u0 & 0xF0) == 0xE0) {
        u0 = ((u0 & 15) << 12) | (u1 << 6) | u2;
      } else {
        u3 = u8Array[idx++] & 63;
        if ((u0 & 0xF8) == 0xF0) {
          u0 = ((u0 & 7) << 18) | (u1 << 12) | (u2 << 6) | u3;
        } else {
          u4 = u8Array[idx++] & 63;
          if ((u0 & 0xFC) == 0xF8) {
            u0 = ((u0 & 3) << 24) | (u1 << 18) | (u2 << 12) | (u3 << 6) | u4;
          } else {
            u5 = u8Array[idx++] & 63;
            u0 = ((u0 & 1) << 30) | (u1 << 24) | (u2 << 18) | (u3 << 12) | (u4 << 6) | u5;
          }
        }
      }
      if (u0 < 0x10000) {
        str += String.fromCharCode(u0);
      } else {
        var ch = u0 - 0x10000;
        str += String.fromCharCode(0xD800 | (ch >> 10), 0xDC00 | (ch & 0x3FF));
      }
    }
  }
}
Module["UTF8ArrayToString"] = UTF8ArrayToString;

// Given a pointer 'ptr' to a null-terminated UTF8-encoded string in the emscripten HEAP, returns
// a copy of that string as a Javascript String object.

function UTF8ToString(ptr) {
  return UTF8ArrayToString(HEAPU8,ptr);
}
Module["UTF8ToString"] = UTF8ToString;

// Copies the given Javascript String object 'str' to the given byte array at address 'outIdx',
// encoded in UTF8 form and null-terminated. The copy will require at most str.length*4+1 bytes of space in the HEAP.
// Use the function lengthBytesUTF8 to compute the exact number of bytes (excluding null terminator) that this function will write.
// Parameters:
//   str: the Javascript string to copy.
//   outU8Array: the array to copy to. Each index in this array is assumed to be one 8-byte element.
//   outIdx: The starting offset in the array to begin the copying.
//   maxBytesToWrite: The maximum number of bytes this function can write to the array. This count should include the null
//                    terminator, i.e. if maxBytesToWrite=1, only the null terminator will be written and nothing else.
//                    maxBytesToWrite=0 does not write any bytes to the output, not even the null terminator.
// Returns the number of bytes written, EXCLUDING the null terminator.

function stringToUTF8Array(str, outU8Array, outIdx, maxBytesToWrite) {
  if (!(maxBytesToWrite > 0)) // Parameter maxBytesToWrite is not optional. Negative values, 0, null, undefined and false each don't write out any bytes.
    return 0;

  var startIdx = outIdx;
  var endIdx = outIdx + maxBytesToWrite - 1; // -1 for string null terminator.
  for (var i = 0; i < str.length; ++i) {
    // Gotcha: charCodeAt returns a 16-bit word that is a UTF-16 encoded code unit, not a Unicode code point of the character! So decode UTF16->UTF32->UTF8.
    // See http://unicode.org/faq/utf_bom.html#utf16-3
    // For UTF8 byte structure, see http://en.wikipedia.org/wiki/UTF-8#Description and https://www.ietf.org/rfc/rfc2279.txt and https://tools.ietf.org/html/rfc3629
    var u = str.charCodeAt(i); // possibly a lead surrogate
    if (u >= 0xD800 && u <= 0xDFFF) u = 0x10000 + ((u & 0x3FF) << 10) | (str.charCodeAt(++i) & 0x3FF);
    if (u <= 0x7F) {
      if (outIdx >= endIdx) break;
      outU8Array[outIdx++] = u;
    } else if (u <= 0x7FF) {
      if (outIdx + 1 >= endIdx) break;
      outU8Array[outIdx++] = 0xC0 | (u >> 6);
      outU8Array[outIdx++] = 0x80 | (u & 63);
    } else if (u <= 0xFFFF) {
      if (outIdx + 2 >= endIdx) break;
      outU8Array[outIdx++] = 0xE0 | (u >> 12);
      outU8Array[outIdx++] = 0x80 | ((u >> 6) & 63);
      outU8Array[outIdx++] = 0x80 | (u & 63);
    } else if (u <= 0x1FFFFF) {
      if (outIdx + 3 >= endIdx) break;
      outU8Array[outIdx++] = 0xF0 | (u >> 18);
      outU8Array[outIdx++] = 0x80 | ((u >> 12) & 63);
      outU8Array[outIdx++] = 0x80 | ((u >> 6) & 63);
      outU8Array[outIdx++] = 0x80 | (u & 63);
    } else if (u <= 0x3FFFFFF) {
      if (outIdx + 4 >= endIdx) break;
      outU8Array[outIdx++] = 0xF8 | (u >> 24);
      outU8Array[outIdx++] = 0x80 | ((u >> 18) & 63);
      outU8Array[outIdx++] = 0x80 | ((u >> 12) & 63);
      outU8Array[outIdx++] = 0x80 | ((u >> 6) & 63);
      outU8Array[outIdx++] = 0x80 | (u & 63);
    } else {
      if (outIdx + 5 >= endIdx) break;
      outU8Array[outIdx++] = 0xFC | (u >> 30);
      outU8Array[outIdx++] = 0x80 | ((u >> 24) & 63);
      outU8Array[outIdx++] = 0x80 | ((u >> 18) & 63);
      outU8Array[outIdx++] = 0x80 | ((u >> 12) & 63);
      outU8Array[outIdx++] = 0x80 | ((u >> 6) & 63);
      outU8Array[outIdx++] = 0x80 | (u & 63);
    }
  }
  // Null-terminate the pointer to the buffer.
  outU8Array[outIdx] = 0;
  return outIdx - startIdx;
}
Module["stringToUTF8Array"] = stringToUTF8Array;

// Copies the given Javascript String object 'str' to the emscripten HEAP at address 'outPtr',
// null-terminated and encoded in UTF8 form. The copy will require at most str.length*4+1 bytes of space in the HEAP.
// Use the function lengthBytesUTF8 to compute the exact number of bytes (excluding null terminator) that this function will write.
// Returns the number of bytes written, EXCLUDING the null terminator.

function stringToUTF8(str, outPtr, maxBytesToWrite) {
  assert(typeof maxBytesToWrite == 'number', 'stringToUTF8(str, outPtr, maxBytesToWrite) is missing the third parameter that specifies the length of the output buffer!');
  return stringToUTF8Array(str, HEAPU8,outPtr, maxBytesToWrite);
}
Module["stringToUTF8"] = stringToUTF8;

// Returns the number of bytes the given Javascript string takes if encoded as a UTF8 byte array, EXCLUDING the null terminator byte.

function lengthBytesUTF8(str) {
  var len = 0;
  for (var i = 0; i < str.length; ++i) {
    // Gotcha: charCodeAt returns a 16-bit word that is a UTF-16 encoded code unit, not a Unicode code point of the character! So decode UTF16->UTF32->UTF8.
    // See http://unicode.org/faq/utf_bom.html#utf16-3
    var u = str.charCodeAt(i); // possibly a lead surrogate
    if (u >= 0xD800 && u <= 0xDFFF) u = 0x10000 + ((u & 0x3FF) << 10) | (str.charCodeAt(++i) & 0x3FF);
    if (u <= 0x7F) {
      ++len;
    } else if (u <= 0x7FF) {
      len += 2;
    } else if (u <= 0xFFFF) {
      len += 3;
    } else if (u <= 0x1FFFFF) {
      len += 4;
    } else if (u <= 0x3FFFFFF) {
      len += 5;
    } else {
      len += 6;
    }
  }
  return len;
}
Module["lengthBytesUTF8"] = lengthBytesUTF8;

// Given a pointer 'ptr' to a null-terminated UTF16LE-encoded string in the emscripten HEAP, returns
// a copy of that string as a Javascript String object.

var UTF16Decoder = typeof TextDecoder !== 'undefined' ? new TextDecoder('utf-16le') : undefined;
function UTF16ToString(ptr) {
  assert(ptr % 2 == 0, 'Pointer passed to UTF16ToString must be aligned to two bytes!');
  var endPtr = ptr;
  // TextDecoder needs to know the byte length in advance, it doesn't stop on null terminator by itself.
  // Also, use the length info to avoid running tiny strings through TextDecoder, since .subarray() allocates garbage.
  var idx = endPtr >> 1;
  while (HEAP16[idx]) ++idx;
  endPtr = idx << 1;

  if (endPtr - ptr > 32 && UTF16Decoder) {
    return UTF16Decoder.decode(HEAPU8.subarray(ptr, endPtr));
  } else {
    var i = 0;

    var str = '';
    while (1) {
      var codeUnit = HEAP16[(((ptr)+(i*2))>>1)];
      if (codeUnit == 0) return str;
      ++i;
      // fromCharCode constructs a character from a UTF-16 code unit, so we can pass the UTF16 string right through.
      str += String.fromCharCode(codeUnit);
    }
  }
}


// Copies the given Javascript String object 'str' to the emscripten HEAP at address 'outPtr',
// null-terminated and encoded in UTF16 form. The copy will require at most str.length*4+2 bytes of space in the HEAP.
// Use the function lengthBytesUTF16() to compute the exact number of bytes (excluding null terminator) that this function will write.
// Parameters:
//   str: the Javascript string to copy.
//   outPtr: Byte address in Emscripten HEAP where to write the string to.
//   maxBytesToWrite: The maximum number of bytes this function can write to the array. This count should include the null
//                    terminator, i.e. if maxBytesToWrite=2, only the null terminator will be written and nothing else.
//                    maxBytesToWrite<2 does not write any bytes to the output, not even the null terminator.
// Returns the number of bytes written, EXCLUDING the null terminator.

function stringToUTF16(str, outPtr, maxBytesToWrite) {
  assert(outPtr % 2 == 0, 'Pointer passed to stringToUTF16 must be aligned to two bytes!');
  assert(typeof maxBytesToWrite == 'number', 'stringToUTF16(str, outPtr, maxBytesToWrite) is missing the third parameter that specifies the length of the output buffer!');
  // Backwards compatibility: if max bytes is not specified, assume unsafe unbounded write is allowed.
  if (maxBytesToWrite === undefined) {
    maxBytesToWrite = 0x7FFFFFFF;
  }
  if (maxBytesToWrite < 2) return 0;
  maxBytesToWrite -= 2; // Null terminator.
  var startPtr = outPtr;
  var numCharsToWrite = (maxBytesToWrite < str.length*2) ? (maxBytesToWrite / 2) : str.length;
  for (var i = 0; i < numCharsToWrite; ++i) {
    // charCodeAt returns a UTF-16 encoded code unit, so it can be directly written to the HEAP.
    var codeUnit = str.charCodeAt(i); // possibly a lead surrogate
    HEAP16[((outPtr)>>1)]=codeUnit;
    outPtr += 2;
  }
  // Null-terminate the pointer to the HEAP.
  HEAP16[((outPtr)>>1)]=0;
  return outPtr - startPtr;
}


// Returns the number of bytes the given Javascript string takes if encoded as a UTF16 byte array, EXCLUDING the null terminator byte.

function lengthBytesUTF16(str) {
  return str.length*2;
}


function UTF32ToString(ptr) {
  assert(ptr % 4 == 0, 'Pointer passed to UTF32ToString must be aligned to four bytes!');
  var i = 0;

  var str = '';
  while (1) {
    var utf32 = HEAP32[(((ptr)+(i*4))>>2)];
    if (utf32 == 0)
      return str;
    ++i;
    // Gotcha: fromCharCode constructs a character from a UTF-16 encoded code (pair), not from a Unicode code point! So encode the code point to UTF-16 for constructing.
    // See http://unicode.org/faq/utf_bom.html#utf16-3
    if (utf32 >= 0x10000) {
      var ch = utf32 - 0x10000;
      str += String.fromCharCode(0xD800 | (ch >> 10), 0xDC00 | (ch & 0x3FF));
    } else {
      str += String.fromCharCode(utf32);
    }
  }
}


// Copies the given Javascript String object 'str' to the emscripten HEAP at address 'outPtr',
// null-terminated and encoded in UTF32 form. The copy will require at most str.length*4+4 bytes of space in the HEAP.
// Use the function lengthBytesUTF32() to compute the exact number of bytes (excluding null terminator) that this function will write.
// Parameters:
//   str: the Javascript string to copy.
//   outPtr: Byte address in Emscripten HEAP where to write the string to.
//   maxBytesToWrite: The maximum number of bytes this function can write to the array. This count should include the null
//                    terminator, i.e. if maxBytesToWrite=4, only the null terminator will be written and nothing else.
//                    maxBytesToWrite<4 does not write any bytes to the output, not even the null terminator.
// Returns the number of bytes written, EXCLUDING the null terminator.

function stringToUTF32(str, outPtr, maxBytesToWrite) {
  assert(outPtr % 4 == 0, 'Pointer passed to stringToUTF32 must be aligned to four bytes!');
  assert(typeof maxBytesToWrite == 'number', 'stringToUTF32(str, outPtr, maxBytesToWrite) is missing the third parameter that specifies the length of the output buffer!');
  // Backwards compatibility: if max bytes is not specified, assume unsafe unbounded write is allowed.
  if (maxBytesToWrite === undefined) {
    maxBytesToWrite = 0x7FFFFFFF;
  }
  if (maxBytesToWrite < 4) return 0;
  var startPtr = outPtr;
  var endPtr = startPtr + maxBytesToWrite - 4;
  for (var i = 0; i < str.length; ++i) {
    // Gotcha: charCodeAt returns a 16-bit word that is a UTF-16 encoded code unit, not a Unicode code point of the character! We must decode the string to UTF-32 to the heap.
    // See http://unicode.org/faq/utf_bom.html#utf16-3
    var codeUnit = str.charCodeAt(i); // possibly a lead surrogate
    if (codeUnit >= 0xD800 && codeUnit <= 0xDFFF) {
      var trailSurrogate = str.charCodeAt(++i);
      codeUnit = 0x10000 + ((codeUnit & 0x3FF) << 10) | (trailSurrogate & 0x3FF);
    }
    HEAP32[((outPtr)>>2)]=codeUnit;
    outPtr += 4;
    if (outPtr + 4 > endPtr) break;
  }
  // Null-terminate the pointer to the HEAP.
  HEAP32[((outPtr)>>2)]=0;
  return outPtr - startPtr;
}


// Returns the number of bytes the given Javascript string takes if encoded as a UTF16 byte array, EXCLUDING the null terminator byte.

function lengthBytesUTF32(str) {
  var len = 0;
  for (var i = 0; i < str.length; ++i) {
    // Gotcha: charCodeAt returns a 16-bit word that is a UTF-16 encoded code unit, not a Unicode code point of the character! We must decode the string to UTF-32 to the heap.
    // See http://unicode.org/faq/utf_bom.html#utf16-3
    var codeUnit = str.charCodeAt(i);
    if (codeUnit >= 0xD800 && codeUnit <= 0xDFFF) ++i; // possibly a lead surrogate, so skip over the tail surrogate.
    len += 4;
  }

  return len;
}


function demangle(func) {
  var __cxa_demangle_func = Module['___cxa_demangle'] || Module['__cxa_demangle'];
  if (__cxa_demangle_func) {
    try {
      var s =
        func.substr(1);
      var len = lengthBytesUTF8(s)+1;
      var buf = _malloc(len);
      stringToUTF8(s, buf, len);
      var status = _malloc(4);
      var ret = __cxa_demangle_func(buf, 0, 0, status);
      if (getValue(status, 'i32') === 0 && ret) {
        return Pointer_stringify(ret);
      }
      // otherwise, libcxxabi failed
    } catch(e) {
      // ignore problems here
    } finally {
      if (buf) _free(buf);
      if (status) _free(status);
      if (ret) _free(ret);
    }
    // failure when using libcxxabi, don't demangle
    return func;
  }
  Runtime.warnOnce('warning: build with  -s DEMANGLE_SUPPORT=1  to link in libcxxabi demangling');
  return func;
}

function demangleAll(text) {
  var regex =
    /__Z[\w\d_]+/g;
  return text.replace(regex,
    function(x) {
      var y = demangle(x);
      return x === y ? x : (x + ' [' + y + ']');
    });
}

function jsStackTrace() {
  var err = new Error();
  if (!err.stack) {
    // IE10+ special cases: It does have callstack info, but it is only populated if an Error object is thrown,
    // so try that as a special-case.
    try {
      throw new Error(0);
    } catch(e) {
      err = e;
    }
    if (!err.stack) {
      return '(no stack trace available)';
    }
  }
  return err.stack.toString();
}

function stackTrace() {
  var js = jsStackTrace();
  if (Module['extraStackTrace']) js += '\n' + Module['extraStackTrace']();
  return demangleAll(js);
}
Module["stackTrace"] = stackTrace;

// Memory management

var PAGE_SIZE = 16384;
var WASM_PAGE_SIZE = 65536;
var ASMJS_PAGE_SIZE = 16777216;
var MIN_TOTAL_MEMORY = 16777216;

function alignUp(x, multiple) {
  if (x % multiple > 0) {
    x += multiple - (x % multiple);
  }
  return x;
}

var HEAP;
var buffer;
var HEAP8, HEAPU8, HEAP16, HEAPU16, HEAP32, HEAPU32, HEAPF32, HEAPF64;

function updateGlobalBuffer(buf) {
  Module['buffer'] = buffer = buf;
}

function updateGlobalBufferViews() {
  Module['HEAP8'] = HEAP8 = new Int8Array(buffer);
  Module['HEAP16'] = HEAP16 = new Int16Array(buffer);
  Module['HEAP32'] = HEAP32 = new Int32Array(buffer);
  Module['HEAPU8'] = HEAPU8 = new Uint8Array(buffer);
  Module['HEAPU16'] = HEAPU16 = new Uint16Array(buffer);
  Module['HEAPU32'] = HEAPU32 = new Uint32Array(buffer);
  Module['HEAPF32'] = HEAPF32 = new Float32Array(buffer);
  Module['HEAPF64'] = HEAPF64 = new Float64Array(buffer);
}

var STATIC_BASE, STATICTOP, staticSealed; // static area
var STACK_BASE, STACKTOP, STACK_MAX; // stack area
var DYNAMIC_BASE, DYNAMICTOP_PTR; // dynamic area handled by sbrk

  STATIC_BASE = STATICTOP = STACK_BASE = STACKTOP = STACK_MAX = DYNAMIC_BASE = DYNAMICTOP_PTR = 0;
  staticSealed = false;


// Initializes the stack cookie. Called at the startup of main and at the startup of each thread in pthreads mode.
function writeStackCookie() {
  assert((STACK_MAX & 3) == 0);
  HEAPU32[(STACK_MAX >> 2)-1] = 0x02135467;
  HEAPU32[(STACK_MAX >> 2)-2] = 0x89BACDFE;
}

function checkStackCookie() {
  if (HEAPU32[(STACK_MAX >> 2)-1] != 0x02135467 || HEAPU32[(STACK_MAX >> 2)-2] != 0x89BACDFE) {
    abort('Stack overflow! Stack cookie has been overwritten, expected hex dwords 0x89BACDFE and 0x02135467, but received 0x' + HEAPU32[(STACK_MAX >> 2)-2].toString(16) + ' ' + HEAPU32[(STACK_MAX >> 2)-1].toString(16));
  }
  // Also test the global address 0 for integrity. This check is not compatible with SAFE_SPLIT_MEMORY though, since that mode already tests all address 0 accesses on its own.
  if (HEAP32[0] !== 0x63736d65 /* 'emsc' */) throw 'Runtime error: The application has corrupted its heap memory area (address zero)!';
}

function abortStackOverflow(allocSize) {
  abort('Stack overflow! Attempted to allocate ' + allocSize + ' bytes on the stack, but stack has only ' + (STACK_MAX - asm.stackSave() + allocSize) + ' bytes available!');
}

function abortOnCannotGrowMemory() {
  abort('Cannot enlarge memory arrays. Either (1) compile with  -s TOTAL_MEMORY=X  with X higher than the current value ' + TOTAL_MEMORY + ', (2) compile with  -s ALLOW_MEMORY_GROWTH=1  which adjusts the size at runtime but prevents some optimizations, (3) set Module.TOTAL_MEMORY to a higher value before the program runs, or if you want malloc to return NULL (0) instead of this abort, compile with  -s ABORTING_MALLOC=0 ');
}


function enlargeMemory() {
  abortOnCannotGrowMemory();
}


var TOTAL_STACK = Module['TOTAL_STACK'] || 5242880;
var TOTAL_MEMORY = Module['TOTAL_MEMORY'] || 16777216;
if (TOTAL_MEMORY < TOTAL_STACK) Module.printErr('TOTAL_MEMORY should be larger than TOTAL_STACK, was ' + TOTAL_MEMORY + '! (TOTAL_STACK=' + TOTAL_STACK + ')');

// Initialize the runtime's memory
// check for full engine support (use string 'subarray' to avoid closure compiler confusion)
assert(typeof Int32Array !== 'undefined' && typeof Float64Array !== 'undefined' && !!(new Int32Array(1)['subarray']) && !!(new Int32Array(1)['set']),
       'JS engine does not provide full typed array support');



// Use a provided buffer, if there is one, or else allocate a new one
if (Module['buffer']) {
  buffer = Module['buffer'];
  assert(buffer.byteLength === TOTAL_MEMORY, 'provided buffer should be ' + TOTAL_MEMORY + ' bytes, but it is ' + buffer.byteLength);
} else {
  // Use a WebAssembly memory where available
  if (typeof WebAssembly === 'object' && typeof WebAssembly.Memory === 'function') {
    assert(TOTAL_MEMORY % WASM_PAGE_SIZE === 0);
    Module['wasmMemory'] = new WebAssembly.Memory({ initial: TOTAL_MEMORY / WASM_PAGE_SIZE, maximum: TOTAL_MEMORY / WASM_PAGE_SIZE });
    buffer = Module['wasmMemory'].buffer;
  } else
  {
    buffer = new ArrayBuffer(TOTAL_MEMORY);
  }
  assert(buffer.byteLength === TOTAL_MEMORY);
}
updateGlobalBufferViews();


function getTotalMemory() {
  return TOTAL_MEMORY;
}

// Endianness check (note: assumes compiler arch was little-endian)
  HEAP32[0] = 0x63736d65; /* 'emsc' */
HEAP16[1] = 0x6373;
if (HEAPU8[2] !== 0x73 || HEAPU8[3] !== 0x63) throw 'Runtime error: expected the system to be little-endian!';

Module['HEAP'] = HEAP;
Module['buffer'] = buffer;
Module['HEAP8'] = HEAP8;
Module['HEAP16'] = HEAP16;
Module['HEAP32'] = HEAP32;
Module['HEAPU8'] = HEAPU8;
Module['HEAPU16'] = HEAPU16;
Module['HEAPU32'] = HEAPU32;
Module['HEAPF32'] = HEAPF32;
Module['HEAPF64'] = HEAPF64;

function callRuntimeCallbacks(callbacks) {
  while(callbacks.length > 0) {
    var callback = callbacks.shift();
    if (typeof callback == 'function') {
      callback();
      continue;
    }
    var func = callback.func;
    if (typeof func === 'number') {
      if (callback.arg === undefined) {
        Module['dynCall_v'](func);
      } else {
        Module['dynCall_vi'](func, callback.arg);
      }
    } else {
      func(callback.arg === undefined ? null : callback.arg);
    }
  }
}

var __ATPRERUN__  = []; // functions called before the runtime is initialized
var __ATINIT__    = []; // functions called during startup
var __ATMAIN__    = []; // functions called when main() is to be run
var __ATEXIT__    = []; // functions called during shutdown
var __ATPOSTRUN__ = []; // functions called after the runtime has exited

var runtimeInitialized = false;
var runtimeExited = false;


function preRun() {
  // compatibility - merge in anything from Module['preRun'] at this time
  if (Module['preRun']) {
    if (typeof Module['preRun'] == 'function') Module['preRun'] = [Module['preRun']];
    while (Module['preRun'].length) {
      addOnPreRun(Module['preRun'].shift());
    }
  }
  callRuntimeCallbacks(__ATPRERUN__);
}

function ensureInitRuntime() {
  checkStackCookie();
  if (runtimeInitialized) return;
  runtimeInitialized = true;
  callRuntimeCallbacks(__ATINIT__);
}

function preMain() {
  checkStackCookie();
  callRuntimeCallbacks(__ATMAIN__);
}

function exitRuntime() {
  checkStackCookie();
  callRuntimeCallbacks(__ATEXIT__);
  runtimeExited = true;
}

function postRun() {
  checkStackCookie();
  // compatibility - merge in anything from Module['postRun'] at this time
  if (Module['postRun']) {
    if (typeof Module['postRun'] == 'function') Module['postRun'] = [Module['postRun']];
    while (Module['postRun'].length) {
      addOnPostRun(Module['postRun'].shift());
    }
  }
  callRuntimeCallbacks(__ATPOSTRUN__);
}

function addOnPreRun(cb) {
  __ATPRERUN__.unshift(cb);
}
Module["addOnPreRun"] = addOnPreRun;

function addOnInit(cb) {
  __ATINIT__.unshift(cb);
}
Module["addOnInit"] = addOnInit;

function addOnPreMain(cb) {
  __ATMAIN__.unshift(cb);
}
Module["addOnPreMain"] = addOnPreMain;

function addOnExit(cb) {
  __ATEXIT__.unshift(cb);
}
Module["addOnExit"] = addOnExit;

function addOnPostRun(cb) {
  __ATPOSTRUN__.unshift(cb);
}
Module["addOnPostRun"] = addOnPostRun;

// Tools


function intArrayFromString(stringy, dontAddNull, length /* optional */) {
  var len = length > 0 ? length : lengthBytesUTF8(stringy)+1;
  var u8array = new Array(len);
  var numBytesWritten = stringToUTF8Array(stringy, u8array, 0, u8array.length);
  if (dontAddNull) u8array.length = numBytesWritten;
  return u8array;
}
Module["intArrayFromString"] = intArrayFromString;

function intArrayToString(array) {
  var ret = [];
  for (var i = 0; i < array.length; i++) {
    var chr = array[i];
    if (chr > 0xFF) {
      assert(false, 'Character code ' + chr + ' (' + String.fromCharCode(chr) + ')  at offset ' + i + ' not in 0x00-0xFF.');
      chr &= 0xFF;
    }
    ret.push(String.fromCharCode(chr));
  }
  return ret.join('');
}
Module["intArrayToString"] = intArrayToString;

// Deprecated: This function should not be called because it is unsafe and does not provide
// a maximum length limit of how many bytes it is allowed to write. Prefer calling the
// function stringToUTF8Array() instead, which takes in a maximum length that can be used
// to be secure from out of bounds writes.
function writeStringToMemory(string, buffer, dontAddNull) {
  Runtime.warnOnce('writeStringToMemory is deprecated and should not be called! Use stringToUTF8() instead!');

  var lastChar, end;
  if (dontAddNull) {
    // stringToUTF8Array always appends null. If we don't want to do that, remember the
    // character that existed at the location where the null will be placed, and restore
    // that after the write (below).
    end = buffer + lengthBytesUTF8(string);
    lastChar = HEAP8[end];
  }
  stringToUTF8(string, buffer, Infinity);
  if (dontAddNull) HEAP8[end] = lastChar; // Restore the value under the null character.
}
Module["writeStringToMemory"] = writeStringToMemory;

function writeArrayToMemory(array, buffer) {
  assert(array.length >= 0, 'writeArrayToMemory array must have a length (should be an array or typed array)')
  HEAP8.set(array, buffer);
}
Module["writeArrayToMemory"] = writeArrayToMemory;

function writeAsciiToMemory(str, buffer, dontAddNull) {
  for (var i = 0; i < str.length; ++i) {
    assert(str.charCodeAt(i) === str.charCodeAt(i)&0xff);
    HEAP8[((buffer++)>>0)]=str.charCodeAt(i);
  }
  // Null-terminate the pointer to the HEAP.
  if (!dontAddNull) HEAP8[((buffer)>>0)]=0;
}
Module["writeAsciiToMemory"] = writeAsciiToMemory;

function unSign(value, bits, ignore) {
  if (value >= 0) {
    return value;
  }
  return bits <= 32 ? 2*Math.abs(1 << (bits-1)) + value // Need some trickery, since if bits == 32, we are right at the limit of the bits JS uses in bitshifts
                    : Math.pow(2, bits)         + value;
}
function reSign(value, bits, ignore) {
  if (value <= 0) {
    return value;
  }
  var half = bits <= 32 ? Math.abs(1 << (bits-1)) // abs is needed if bits == 32
                        : Math.pow(2, bits-1);
  if (value >= half && (bits <= 32 || value > half)) { // for huge values, we can hit the precision limit and always get true here. so don't do that
                                                       // but, in general there is no perfect solution here. With 64-bit ints, we get rounding and errors
                                                       // TODO: In i64 mode 1, resign the two parts separately and safely
    value = -2*half + value; // Cannot bitshift half, as it may be at the limit of the bits JS uses in bitshifts
  }
  return value;
}


// check for imul support, and also for correctness ( https://bugs.webkit.org/show_bug.cgi?id=126345 )
if (!Math['imul'] || Math['imul'](0xffffffff, 5) !== -5) Math['imul'] = function imul(a, b) {
  var ah  = a >>> 16;
  var al = a & 0xffff;
  var bh  = b >>> 16;
  var bl = b & 0xffff;
  return (al*bl + ((ah*bl + al*bh) << 16))|0;
};
Math.imul = Math['imul'];

if (!Math['fround']) {
  var froundBuffer = new Float32Array(1);
  Math['fround'] = function(x) { froundBuffer[0] = x; return froundBuffer[0] };
}
Math.fround = Math['fround'];

if (!Math['clz32']) Math['clz32'] = function(x) {
  x = x >>> 0;
  for (var i = 0; i < 32; i++) {
    if (x & (1 << (31 - i))) return i;
  }
  return 32;
};
Math.clz32 = Math['clz32']

if (!Math['trunc']) Math['trunc'] = function(x) {
  return x < 0 ? Math.ceil(x) : Math.floor(x);
};
Math.trunc = Math['trunc'];

var Math_abs = Math.abs;
var Math_cos = Math.cos;
var Math_sin = Math.sin;
var Math_tan = Math.tan;
var Math_acos = Math.acos;
var Math_asin = Math.asin;
var Math_atan = Math.atan;
var Math_atan2 = Math.atan2;
var Math_exp = Math.exp;
var Math_log = Math.log;
var Math_sqrt = Math.sqrt;
var Math_ceil = Math.ceil;
var Math_floor = Math.floor;
var Math_pow = Math.pow;
var Math_imul = Math.imul;
var Math_fround = Math.fround;
var Math_round = Math.round;
var Math_min = Math.min;
var Math_clz32 = Math.clz32;
var Math_trunc = Math.trunc;

// A counter of dependencies for calling run(). If we need to
// do asynchronous work before running, increment this and
// decrement it. Incrementing must happen in a place like
// PRE_RUN_ADDITIONS (used by emcc to add file preloading).
// Note that you can add dependencies in preRun, even though
// it happens right before run - run will be postponed until
// the dependencies are met.
var runDependencies = 0;
var runDependencyWatcher = null;
var dependenciesFulfilled = null; // overridden to take different actions when all run dependencies are fulfilled
var runDependencyTracking = {};

function getUniqueRunDependency(id) {
  var orig = id;
  while (1) {
    if (!runDependencyTracking[id]) return id;
    id = orig + Math.random();
  }
  return id;
}

function addRunDependency(id) {
  runDependencies++;
  if (Module['monitorRunDependencies']) {
    Module['monitorRunDependencies'](runDependencies);
  }
  if (id) {
    assert(!runDependencyTracking[id]);
    runDependencyTracking[id] = 1;
    if (runDependencyWatcher === null && typeof setInterval !== 'undefined') {
      // Check for missing dependencies every few seconds
      runDependencyWatcher = setInterval(function() {
        if (ABORT) {
          clearInterval(runDependencyWatcher);
          runDependencyWatcher = null;
          return;
        }
        var shown = false;
        for (var dep in runDependencyTracking) {
          if (!shown) {
            shown = true;
            Module.printErr('still waiting on run dependencies:');
          }
          Module.printErr('dependency: ' + dep);
        }
        if (shown) {
          Module.printErr('(end of list)');
        }
      }, 10000);
    }
  } else {
    Module.printErr('warning: run dependency added without ID');
  }
}
Module["addRunDependency"] = addRunDependency;

function removeRunDependency(id) {
  runDependencies--;
  if (Module['monitorRunDependencies']) {
    Module['monitorRunDependencies'](runDependencies);
  }
  if (id) {
    assert(runDependencyTracking[id]);
    delete runDependencyTracking[id];
  } else {
    Module.printErr('warning: run dependency removed without ID');
  }
  if (runDependencies == 0) {
    if (runDependencyWatcher !== null) {
      clearInterval(runDependencyWatcher);
      runDependencyWatcher = null;
    }
    if (dependenciesFulfilled) {
      var callback = dependenciesFulfilled;
      dependenciesFulfilled = null;
      callback(); // can add another dependenciesFulfilled
    }
  }
}
Module["removeRunDependency"] = removeRunDependency;

Module["preloadedImages"] = {}; // maps url to image data
Module["preloadedAudios"] = {}; // maps url to audio data



var memoryInitializer = null;



var /* show errors on likely calls to FS when it was not included */ FS = {
  error: function() {
    abort('Filesystem support (FS) was not included. The problem is that you are using files from JS, but files were not used from C/C++, so filesystem support was not auto-included. You can force-include filesystem support with  -s FORCE_FILESYSTEM=1');
  },
  init: function() { FS.error() },
  createDataFile: function() { FS.error() },
  createPreloadedFile: function() { FS.error() },
  createLazyFile: function() { FS.error() },
  open: function() { FS.error() },
  mkdev: function() { FS.error() },
  registerDevice: function() { FS.error() },
  analyzePath: function() { FS.error() },
  loadFilesFromDB: function() { FS.error() },

  ErrnoError: function ErrnoError() { FS.error() },
};
Module['FS_createDataFile'] = FS.createDataFile;
Module['FS_createPreloadedFile'] = FS.createPreloadedFile;


function integrateWasmJS(Module) {
  // wasm.js has several methods for creating the compiled code module here:
  //  * 'native-wasm' : use native WebAssembly support in the browser
  //  * 'interpret-s-expr': load s-expression code from a .wast and interpret
  //  * 'interpret-binary': load binary wasm and interpret
  //  * 'interpret-asm2wasm': load asm.js code, translate to wasm, and interpret
  //  * 'asmjs': no wasm, just load the asm.js code and use that (good for testing)
  // The method can be set at compile time (BINARYEN_METHOD), or runtime by setting Module['wasmJSMethod'].
  // The method can be a comma-separated list, in which case, we will try the
  // options one by one. Some of them can fail gracefully, and then we can try
  // the next.

  // inputs

  var method = Module['wasmJSMethod'] || 'native-wasm';
  Module['wasmJSMethod'] = method;

  var wasmTextFile = Module['wasmTextFile'] || 'test.wast';
  var wasmBinaryFile = Module['wasmBinaryFile'] || 'test.wasm';
  var asmjsCodeFile = Module['asmjsCodeFile'] || 'test.temp.asm.js';

  // utilities

  var wasmPageSize = 64*1024;

  var asm2wasmImports = { // special asm2wasm imports
    "f64-rem": function(x, y) {
      return x % y;
    },
    "f64-to-int": function(x) {
      return x | 0;
    },
    "i32s-div": function(x, y) {
      return ((x | 0) / (y | 0)) | 0;
    },
    "i32u-div": function(x, y) {
      return ((x >>> 0) / (y >>> 0)) >>> 0;
    },
    "i32s-rem": function(x, y) {
      return ((x | 0) % (y | 0)) | 0;
    },
    "i32u-rem": function(x, y) {
      return ((x >>> 0) % (y >>> 0)) >>> 0;
    },
    "debugger": function() {
      debugger;
    },
  };

  var info = {
    'global': null,
    'env': null,
    'asm2wasm': asm2wasmImports,
    'parent': Module // Module inside wasm-js.cpp refers to wasm-js.cpp; this allows access to the outside program.
  };

  var exports = null;

  function lookupImport(mod, base) {
    var lookup = info;
    if (mod.indexOf('.') < 0) {
      lookup = (lookup || {})[mod];
    } else {
      var parts = mod.split('.');
      lookup = (lookup || {})[parts[0]];
      lookup = (lookup || {})[parts[1]];
    }
    if (base) {
      lookup = (lookup || {})[base];
    }
    if (lookup === undefined) {
      abort('bad lookupImport to (' + mod + ').' + base);
    }
    return lookup;
  }

  function mergeMemory(newBuffer) {
    // The wasm instance creates its memory. But static init code might have written to
    // buffer already, including the mem init file, and we must copy it over in a proper merge.
    // TODO: avoid this copy, by avoiding such static init writes
    // TODO: in shorter term, just copy up to the last static init write
    var oldBuffer = Module['buffer'];
    if (newBuffer.byteLength < oldBuffer.byteLength) {
      Module['printErr']('the new buffer in mergeMemory is smaller than the previous one. in native wasm, we should grow memory here');
    }
    var oldView = new Int8Array(oldBuffer);
    var newView = new Int8Array(newBuffer);

    // If we have a mem init file, do not trample it
    if (!memoryInitializer) {
      oldView.set(newView.subarray(Module['STATIC_BASE'], Module['STATIC_BASE'] + Module['STATIC_BUMP']), Module['STATIC_BASE']);
    }

    newView.set(oldView);
    updateGlobalBuffer(newBuffer);
    updateGlobalBufferViews();
  }

  var WasmTypes = {
    none: 0,
    i32: 1,
    i64: 2,
    f32: 3,
    f64: 4
  };

  function fixImports(imports) {
    if (!0) return imports;
    var ret = {};
    for (var i in imports) {
      var fixed = i;
      if (fixed[0] == '_') fixed = fixed.substr(1);
      ret[fixed] = imports[i];
    }
    return ret;
  }

  function getBinary() {
    var binary;
    if (ENVIRONMENT_IS_WEB || ENVIRONMENT_IS_WORKER) {
      binary = Module['wasmBinary'];
      assert(binary, "on the web, we need the wasm binary to be preloaded and set on Module['wasmBinary']. emcc.py will do that for you when generating HTML (but not JS)");
      binary = new Uint8Array(binary);
    } else {
      binary = Module['readBinary'](wasmBinaryFile);
    }
    return binary;
  }

  // do-method functions

  function doJustAsm(global, env, providedBuffer) {
    // if no Module.asm, or it's the method handler helper (see below), then apply
    // the asmjs
    if (typeof Module['asm'] !== 'function' || Module['asm'] === methodHandler) {
      if (!Module['asmPreload']) {
        // you can load the .asm.js file before this, to avoid this sync xhr and eval
        eval(Module['read'](asmjsCodeFile)); // set Module.asm
      } else {
        Module['asm'] = Module['asmPreload'];
      }
    }
    if (typeof Module['asm'] !== 'function') {
      Module['printErr']('asm evalling did not set the module properly');
      return false;
    }
    return Module['asm'](global, env, providedBuffer);
  }

  function doNativeWasm(global, env, providedBuffer) {
    if (typeof WebAssembly !== 'object') {
      Module['printErr']('no native wasm support detected');
      return false;
    }
    // prepare memory import
    if (!(Module['wasmMemory'] instanceof WebAssembly.Memory)) {
      Module['printErr']('no native wasm Memory in use');
      return false;
    }
    env['memory'] = Module['wasmMemory'];
    // Load the wasm module and create an instance of using native support in the JS engine.
    info['global'] = {
      'NaN': NaN,
      'Infinity': Infinity
    };
    info['global.Math'] = global.Math;
    info['env'] = env;
    // handle a generated wasm instance, receiving its exports and
    // performing other necessary setup
    function receiveInstance(instance) {
      exports = instance.exports;
      if (exports.memory) mergeMemory(exports.memory);
      Module['asm'] = exports;
      Module["usingWasm"] = true;
    }
    Module['printErr']('asynchronously preparing wasm');
    addRunDependency('wasm-instantiate'); // we can't run yet
    WebAssembly.instantiate(getBinary(), info).then(function(output) {
      // receiveInstance() will swap in the exports (to Module.asm) so they can be called
      receiveInstance(output.instance);
      removeRunDependency('wasm-instantiate');
    }).catch(function(reason) {
      Module['printErr']('failed to asynchronously prepare wasm:\n  ' + reason);
    });
    return {}; // no exports yet; we'll fill them in later
    var instance;
    try {
      instance = new WebAssembly.Instance(new WebAssembly.Module(getBinary()), info)
    } catch (e) {
      Module['printErr']('failed to compile wasm module: ' + e);
      if (e.toString().indexOf('imported Memory with incompatible size') >= 0) {
        Module['printErr']('Memory size incompatibility issues may be due to changing TOTAL_MEMORY at runtime to something too large. Use ALLOW_MEMORY_GROWTH to allow any size memory (and also make sure not to set TOTAL_MEMORY at runtime to something smaller than it was at compile time).');
      }
      return false;
    }
    receiveInstance(instance);
    return exports;
  }

  function doWasmPolyfill(global, env, providedBuffer, method) {
    if (typeof WasmJS !== 'function') {
      Module['printErr']('WasmJS not detected - polyfill not bundled?');
      return false;
    }

    // Use wasm.js to polyfill and execute code in a wasm interpreter.
    var wasmJS = WasmJS({});

    // XXX don't be confused. Module here is in the outside program. wasmJS is the inner wasm-js.cpp.
    wasmJS['outside'] = Module; // Inside wasm-js.cpp, Module['outside'] reaches the outside module.

    // Information for the instance of the module.
    wasmJS['info'] = info;

    wasmJS['lookupImport'] = lookupImport;

    assert(providedBuffer === Module['buffer']); // we should not even need to pass it as a 3rd arg for wasm, but that's the asm.js way.

    info.global = global;
    info.env = env;

    // polyfill interpreter expects an ArrayBuffer
    assert(providedBuffer === Module['buffer']);
    env['memory'] = providedBuffer;
    assert(env['memory'] instanceof ArrayBuffer);

    wasmJS['providedTotalMemory'] = Module['buffer'].byteLength;

    // Prepare to generate wasm, using either asm2wasm or s-exprs
    var code;
    if (method === 'interpret-binary') {
      code = getBinary();
    } else {
      code = Module['read'](method == 'interpret-asm2wasm' ? asmjsCodeFile : wasmTextFile);
    }
    var temp;
    if (method == 'interpret-asm2wasm') {
      temp = wasmJS['_malloc'](code.length + 1);
      wasmJS['writeAsciiToMemory'](code, temp);
      wasmJS['_load_asm2wasm'](temp);
    } else if (method === 'interpret-s-expr') {
      temp = wasmJS['_malloc'](code.length + 1);
      wasmJS['writeAsciiToMemory'](code, temp);
      wasmJS['_load_s_expr2wasm'](temp);
    } else if (method === 'interpret-binary') {
      temp = wasmJS['_malloc'](code.length);
      wasmJS['HEAPU8'].set(code, temp);
      wasmJS['_load_binary2wasm'](temp, code.length);
    } else {
      throw 'what? ' + method;
    }
    wasmJS['_free'](temp);

    wasmJS['_instantiate'](temp);

    if (Module['newBuffer']) {
      mergeMemory(Module['newBuffer']);
      Module['newBuffer'] = null;
    }

    exports = wasmJS['asmExports'];

    return exports;
  }

  // We may have a preloaded value in Module.asm, save it
  Module['asmPreload'] = Module['asm'];

  // Memory growth integration code
  Module['reallocBuffer'] = function(size) {
    var PAGE_MULTIPLE = Module["usingWasm"] ? WASM_PAGE_SIZE : ASMJS_PAGE_SIZE; // In wasm, heap size must be a multiple of 64KB. In asm.js, they need to be multiples of 16MB.
    size = alignUp(size, PAGE_MULTIPLE); // round up to wasm page size
    var old = Module['buffer'];
    var oldSize = old.byteLength;
    if (Module["usingWasm"]) {
      try {
        var result = Module['wasmMemory'].grow((size - oldSize) / wasmPageSize); // .grow() takes a delta compared to the previous size
        if (result !== (-1 | 0)) {
          // success in native wasm memory growth, get the buffer from the memory
          return Module['buffer'] = Module['wasmMemory'].buffer;
        } else {
          return null;
        }
      } catch(e) {
        console.error('Module.reallocBuffer: Attempted to grow from ' + oldSize  + ' bytes to ' + size + ' bytes, but got error: ' + e);
        return null;
      }
    } else {
      exports['__growWasmMemory']((size - oldSize) / wasmPageSize); // tiny wasm method that just does grow_memory
      // in interpreter, we replace Module.buffer if we allocate
      return Module['buffer'] !== old ? Module['buffer'] : null; // if it was reallocated, it changed
    }
  };

  // Provide an "asm.js function" for the application, called to "link" the asm.js module. We instantiate
  // the wasm module at that time, and it receives imports and provides exports and so forth, the app
  // doesn't need to care that it is wasm or olyfilled wasm or asm.js.

  Module['asm'] = function(global, env, providedBuffer) {
    global = fixImports(global);
    env = fixImports(env);

    // import table
    if (!env['table']) {
      var TABLE_SIZE = Module['wasmTableSize'];
      if (TABLE_SIZE === undefined) TABLE_SIZE = 1024; // works in binaryen interpreter at least
      var MAX_TABLE_SIZE = Module['wasmMaxTableSize'];
      if (typeof WebAssembly === 'object' && typeof WebAssembly.Table === 'function') {
        if (MAX_TABLE_SIZE !== undefined) {
          env['table'] = new WebAssembly.Table({ initial: TABLE_SIZE, maximum: MAX_TABLE_SIZE, element: 'anyfunc' });
        } else {
          env['table'] = new WebAssembly.Table({ initial: TABLE_SIZE, element: 'anyfunc' });
        }
      } else {
        env['table'] = new Array(TABLE_SIZE); // works in binaryen interpreter at least
      }
      Module['wasmTable'] = env['table'];
    }

    if (!env['memoryBase']) {
      env['memoryBase'] = Module['STATIC_BASE']; // tell the memory segments where to place themselves
    }
    if (!env['tableBase']) {
      env['tableBase'] = 0; // table starts at 0 by default, in dynamic linking this will change
    }

    // try the methods. each should return the exports if it succeeded

    var exports;
    var methods = method.split(',');

    for (var i = 0; i < methods.length; i++) {
      var curr = methods[i];

      Module['printErr']('trying binaryen method: ' + curr);

      if (curr === 'native-wasm') {
        if (exports = doNativeWasm(global, env, providedBuffer)) break;
      } else if (curr === 'asmjs') {
        if (exports = doJustAsm(global, env, providedBuffer)) break;
      } else if (curr === 'interpret-asm2wasm' || curr === 'interpret-s-expr' || curr === 'interpret-binary') {
        if (exports = doWasmPolyfill(global, env, providedBuffer, curr)) break;
      } else {
        throw 'bad method: ' + curr;
      }
    }

    if (!exports) throw 'no binaryen method succeeded. consider enabling more options, like interpreting, if you want that: https://github.com/kripken/emscripten/wiki/WebAssembly#binaryen-methods';

    Module['printErr']('binaryen method succeeded.');

    return exports;
  };

  var methodHandler = Module['asm']; // note our method handler, as we may modify Module['asm'] later
}

integrateWasmJS(Module);

// === Body ===

var ASM_CONSTS = [function($0, $1) { proxy_NativeHx_println($0,$1) }];

function _emscripten_asm_const_iii(code, a0, a1) {
 return ASM_CONSTS[code](a0, a1);
}



STATIC_BASE = 1024;

STATICTOP = STATIC_BASE + 70768;
  /* global initializers */  __ATINIT__.push();
  

memoryInitializer = Module["wasmJSMethod"].indexOf("asmjs") >= 0 || Module["wasmJSMethod"].indexOf("interpret-asm2wasm") >= 0 ? "test.html.mem" : null;




var STATIC_BUMP = 70768;
Module["STATIC_BASE"] = STATIC_BASE;
Module["STATIC_BUMP"] = STATIC_BUMP;

/* no memory initializer */
var tempDoublePtr = STATICTOP; STATICTOP += 16;

assert(tempDoublePtr % 8 == 0);

function copyTempFloat(ptr) { // functions, because inlining this code increases code size too much

  HEAP8[tempDoublePtr] = HEAP8[ptr];

  HEAP8[tempDoublePtr+1] = HEAP8[ptr+1];

  HEAP8[tempDoublePtr+2] = HEAP8[ptr+2];

  HEAP8[tempDoublePtr+3] = HEAP8[ptr+3];

}

function copyTempDouble(ptr) {

  HEAP8[tempDoublePtr] = HEAP8[ptr];

  HEAP8[tempDoublePtr+1] = HEAP8[ptr+1];

  HEAP8[tempDoublePtr+2] = HEAP8[ptr+2];

  HEAP8[tempDoublePtr+3] = HEAP8[ptr+3];

  HEAP8[tempDoublePtr+4] = HEAP8[ptr+4];

  HEAP8[tempDoublePtr+5] = HEAP8[ptr+5];

  HEAP8[tempDoublePtr+6] = HEAP8[ptr+6];

  HEAP8[tempDoublePtr+7] = HEAP8[ptr+7];

}

// {{PRE_LIBRARY}}


   
  Module["_memset"] = _memset;

  function _pthread_cleanup_push(routine, arg) {
      __ATEXIT__.push(function() { Module['dynCall_vi'](routine, arg) })
      _pthread_cleanup_push.level = __ATEXIT__.length;
    }

  function _pthread_cleanup_pop() {
      assert(_pthread_cleanup_push.level == __ATEXIT__.length, 'cannot pop if something else added meanwhile!');
      __ATEXIT__.pop();
      _pthread_cleanup_push.level = __ATEXIT__.length;
    }

  function _abort() {
      Module['abort']();
    }

  function ___lock() {}

  function ___unlock() {}

  
  var SYSCALLS={varargs:0,get:function (varargs) {
        SYSCALLS.varargs += 4;
        var ret = HEAP32[(((SYSCALLS.varargs)-(4))>>2)];
        return ret;
      },getStr:function () {
        var ret = Pointer_stringify(SYSCALLS.get());
        return ret;
      },get64:function () {
        var low = SYSCALLS.get(), high = SYSCALLS.get();
        if (low >= 0) assert(high === 0);
        else assert(high === -1);
        return low;
      },getZero:function () {
        assert(SYSCALLS.get() === 0);
      }};function ___syscall6(which, varargs) {SYSCALLS.varargs = varargs;
  try {
   // close
      var stream = SYSCALLS.getStreamFromFD();
      FS.close(stream);
      return 0;
    } catch (e) {
    if (typeof FS === 'undefined' || !(e instanceof FS.ErrnoError)) abort(e);
    return -e.errno;
  }
  }

  
  function ___setErrNo(value) {
      if (Module['___errno_location']) HEAP32[((Module['___errno_location']())>>2)]=value;
      else Module.printErr('failed to set errno from JS');
      return value;
    } 
  Module["_sbrk"] = _sbrk;

  
  function _emscripten_memcpy_big(dest, src, num) {
      HEAPU8.set(HEAPU8.subarray(src, src+num), dest);
      return dest;
    } 
  Module["_memcpy"] = _memcpy;

  var _emscripten_asm_const_int=true;

   
  Module["_pthread_self"] = _pthread_self;

  function ___syscall140(which, varargs) {SYSCALLS.varargs = varargs;
  try {
   // llseek
      var stream = SYSCALLS.getStreamFromFD(), offset_high = SYSCALLS.get(), offset_low = SYSCALLS.get(), result = SYSCALLS.get(), whence = SYSCALLS.get();
      var offset = offset_low;
      assert(offset_high === 0);
      FS.llseek(stream, offset, whence);
      HEAP32[((result)>>2)]=stream.position;
      if (stream.getdents && offset === 0 && whence === 0) stream.getdents = null; // reset readdir state
      return 0;
    } catch (e) {
    if (typeof FS === 'undefined' || !(e instanceof FS.ErrnoError)) abort(e);
    return -e.errno;
  }
  }

  function ___syscall146(which, varargs) {SYSCALLS.varargs = varargs;
  try {
   // writev
      // hack to support printf in NO_FILESYSTEM
      var stream = SYSCALLS.get(), iov = SYSCALLS.get(), iovcnt = SYSCALLS.get();
      var ret = 0;
      if (!___syscall146.buffer) {
        ___syscall146.buffers = [null, [], []]; // 1 => stdout, 2 => stderr
        ___syscall146.printChar = function(stream, curr) {
          var buffer = ___syscall146.buffers[stream];
          assert(buffer);
          if (curr === 0 || curr === 10) {
            (stream === 1 ? Module['print'] : Module['printErr'])(UTF8ArrayToString(buffer, 0));
            buffer.length = 0;
          } else {
            buffer.push(curr);
          }
        };
      }
      for (var i = 0; i < iovcnt; i++) {
        var ptr = HEAP32[(((iov)+(i*8))>>2)];
        var len = HEAP32[(((iov)+(i*8 + 4))>>2)];
        for (var j = 0; j < len; j++) {
          ___syscall146.printChar(stream, HEAPU8[ptr+j]);
        }
        ret += len;
      }
      return ret;
    } catch (e) {
    if (typeof FS === 'undefined' || !(e instanceof FS.ErrnoError)) abort(e);
    return -e.errno;
  }
  }

  function ___syscall54(which, varargs) {SYSCALLS.varargs = varargs;
  try {
   // ioctl
      return 0;
    } catch (e) {
    if (typeof FS === 'undefined' || !(e instanceof FS.ErrnoError)) abort(e);
    return -e.errno;
  }
  }
/* flush anything remaining in the buffer during shutdown */ __ATEXIT__.push(function() { var fflush = Module["_fflush"]; if (fflush) fflush(0); var printChar = ___syscall146.printChar; if (!printChar) return; var buffers = ___syscall146.buffers; if (buffers[1].length) printChar(1, 10); if (buffers[2].length) printChar(2, 10); });;
DYNAMICTOP_PTR = allocate(1, "i32", ALLOC_STATIC);

STACK_BASE = STACKTOP = Runtime.alignMemory(STATICTOP);

STACK_MAX = STACK_BASE + TOTAL_STACK;

DYNAMIC_BASE = Runtime.alignMemory(STACK_MAX);

HEAP32[DYNAMICTOP_PTR>>2] = DYNAMIC_BASE;

staticSealed = true; // seal the static portion of memory

assert(DYNAMIC_BASE < TOTAL_MEMORY, "TOTAL_MEMORY not big enough for stack");



function nullFunc_ii(x) { Module["printErr"]("Invalid function pointer called with signature 'ii'. Perhaps this is an invalid value (e.g. caused by calling a virtual method on a NULL pointer)? Or calling a function with an incorrect type, which will fail? (it is worth building your source files with -Werror (warnings are errors), as warnings can indicate undefined behavior which can cause this)");  Module["printErr"]("Build with ASSERTIONS=2 for more info.");abort(x) }

function nullFunc_iiii(x) { Module["printErr"]("Invalid function pointer called with signature 'iiii'. Perhaps this is an invalid value (e.g. caused by calling a virtual method on a NULL pointer)? Or calling a function with an incorrect type, which will fail? (it is worth building your source files with -Werror (warnings are errors), as warnings can indicate undefined behavior which can cause this)");  Module["printErr"]("Build with ASSERTIONS=2 for more info.");abort(x) }

function nullFunc_vi(x) { Module["printErr"]("Invalid function pointer called with signature 'vi'. Perhaps this is an invalid value (e.g. caused by calling a virtual method on a NULL pointer)? Or calling a function with an incorrect type, which will fail? (it is worth building your source files with -Werror (warnings are errors), as warnings can indicate undefined behavior which can cause this)");  Module["printErr"]("Build with ASSERTIONS=2 for more info.");abort(x) }

Module['wasmTableSize'] = 18;

Module['wasmMaxTableSize'] = 18;

function invoke_ii(index,a1) {
  try {
    return Module["dynCall_ii"](index,a1);
  } catch(e) {
    if (typeof e !== 'number' && e !== 'longjmp') throw e;
    Module["setThrew"](1, 0);
  }
}

function invoke_iiii(index,a1,a2,a3) {
  try {
    return Module["dynCall_iiii"](index,a1,a2,a3);
  } catch(e) {
    if (typeof e !== 'number' && e !== 'longjmp') throw e;
    Module["setThrew"](1, 0);
  }
}

function invoke_vi(index,a1) {
  try {
    Module["dynCall_vi"](index,a1);
  } catch(e) {
    if (typeof e !== 'number' && e !== 'longjmp') throw e;
    Module["setThrew"](1, 0);
  }
}

Module.asmGlobalArg = { "Math": Math, "Int8Array": Int8Array, "Int16Array": Int16Array, "Int32Array": Int32Array, "Uint8Array": Uint8Array, "Uint16Array": Uint16Array, "Uint32Array": Uint32Array, "Float32Array": Float32Array, "Float64Array": Float64Array, "NaN": NaN, "Infinity": Infinity };

Module.asmLibraryArg = { "abort": abort, "assert": assert, "enlargeMemory": enlargeMemory, "getTotalMemory": getTotalMemory, "abortOnCannotGrowMemory": abortOnCannotGrowMemory, "abortStackOverflow": abortStackOverflow, "nullFunc_ii": nullFunc_ii, "nullFunc_iiii": nullFunc_iiii, "nullFunc_vi": nullFunc_vi, "invoke_ii": invoke_ii, "invoke_iiii": invoke_iiii, "invoke_vi": invoke_vi, "_pthread_cleanup_pop": _pthread_cleanup_pop, "___lock": ___lock, "_abort": _abort, "_pthread_cleanup_push": _pthread_cleanup_push, "___syscall6": ___syscall6, "___unlock": ___unlock, "___syscall146": ___syscall146, "_emscripten_memcpy_big": _emscripten_memcpy_big, "___syscall54": ___syscall54, "___syscall140": ___syscall140, "_emscripten_asm_const_iii": _emscripten_asm_const_iii, "___setErrNo": ___setErrNo, "DYNAMICTOP_PTR": DYNAMICTOP_PTR, "tempDoublePtr": tempDoublePtr, "ABORT": ABORT, "STACKTOP": STACKTOP, "STACK_MAX": STACK_MAX };
// EMSCRIPTEN_START_ASM
var asm =Module["asm"]// EMSCRIPTEN_END_ASM
(Module.asmGlobalArg, Module.asmLibraryArg, buffer);

var real__malloc = asm["_malloc"]; asm["_malloc"] = function() {
assert(runtimeInitialized, 'you need to wait for the runtime to be ready (e.g. wait for main() to be called)');
assert(!runtimeExited, 'the runtime was exited (use NO_EXIT_RUNTIME to keep it alive after main() exits)');
return real__malloc.apply(null, arguments);
};

var real_getTempRet0 = asm["getTempRet0"]; asm["getTempRet0"] = function() {
assert(runtimeInitialized, 'you need to wait for the runtime to be ready (e.g. wait for main() to be called)');
assert(!runtimeExited, 'the runtime was exited (use NO_EXIT_RUNTIME to keep it alive after main() exits)');
return real_getTempRet0.apply(null, arguments);
};

var real__fflush = asm["_fflush"]; asm["_fflush"] = function() {
assert(runtimeInitialized, 'you need to wait for the runtime to be ready (e.g. wait for main() to be called)');
assert(!runtimeExited, 'the runtime was exited (use NO_EXIT_RUNTIME to keep it alive after main() exits)');
return real__fflush.apply(null, arguments);
};

var real__main = asm["_main"]; asm["_main"] = function() {
assert(runtimeInitialized, 'you need to wait for the runtime to be ready (e.g. wait for main() to be called)');
assert(!runtimeExited, 'the runtime was exited (use NO_EXIT_RUNTIME to keep it alive after main() exits)');
return real__main.apply(null, arguments);
};

var real_setTempRet0 = asm["setTempRet0"]; asm["setTempRet0"] = function() {
assert(runtimeInitialized, 'you need to wait for the runtime to be ready (e.g. wait for main() to be called)');
assert(!runtimeExited, 'the runtime was exited (use NO_EXIT_RUNTIME to keep it alive after main() exits)');
return real_setTempRet0.apply(null, arguments);
};

var real_establishStackSpace = asm["establishStackSpace"]; asm["establishStackSpace"] = function() {
assert(runtimeInitialized, 'you need to wait for the runtime to be ready (e.g. wait for main() to be called)');
assert(!runtimeExited, 'the runtime was exited (use NO_EXIT_RUNTIME to keep it alive after main() exits)');
return real_establishStackSpace.apply(null, arguments);
};

var real__pthread_self = asm["_pthread_self"]; asm["_pthread_self"] = function() {
assert(runtimeInitialized, 'you need to wait for the runtime to be ready (e.g. wait for main() to be called)');
assert(!runtimeExited, 'the runtime was exited (use NO_EXIT_RUNTIME to keep it alive after main() exits)');
return real__pthread_self.apply(null, arguments);
};

var real_stackSave = asm["stackSave"]; asm["stackSave"] = function() {
assert(runtimeInitialized, 'you need to wait for the runtime to be ready (e.g. wait for main() to be called)');
assert(!runtimeExited, 'the runtime was exited (use NO_EXIT_RUNTIME to keep it alive after main() exits)');
return real_stackSave.apply(null, arguments);
};

var real__sbrk = asm["_sbrk"]; asm["_sbrk"] = function() {
assert(runtimeInitialized, 'you need to wait for the runtime to be ready (e.g. wait for main() to be called)');
assert(!runtimeExited, 'the runtime was exited (use NO_EXIT_RUNTIME to keep it alive after main() exits)');
return real__sbrk.apply(null, arguments);
};

var real_stackRestore = asm["stackRestore"]; asm["stackRestore"] = function() {
assert(runtimeInitialized, 'you need to wait for the runtime to be ready (e.g. wait for main() to be called)');
assert(!runtimeExited, 'the runtime was exited (use NO_EXIT_RUNTIME to keep it alive after main() exits)');
return real_stackRestore.apply(null, arguments);
};

var real_stackAlloc = asm["stackAlloc"]; asm["stackAlloc"] = function() {
assert(runtimeInitialized, 'you need to wait for the runtime to be ready (e.g. wait for main() to be called)');
assert(!runtimeExited, 'the runtime was exited (use NO_EXIT_RUNTIME to keep it alive after main() exits)');
return real_stackAlloc.apply(null, arguments);
};

var real_setThrew = asm["setThrew"]; asm["setThrew"] = function() {
assert(runtimeInitialized, 'you need to wait for the runtime to be ready (e.g. wait for main() to be called)');
assert(!runtimeExited, 'the runtime was exited (use NO_EXIT_RUNTIME to keep it alive after main() exits)');
return real_setThrew.apply(null, arguments);
};

var real__test_call = asm["_test_call"]; asm["_test_call"] = function() {
assert(runtimeInitialized, 'you need to wait for the runtime to be ready (e.g. wait for main() to be called)');
assert(!runtimeExited, 'the runtime was exited (use NO_EXIT_RUNTIME to keep it alive after main() exits)');
return real__test_call.apply(null, arguments);
};

var real__free = asm["_free"]; asm["_free"] = function() {
assert(runtimeInitialized, 'you need to wait for the runtime to be ready (e.g. wait for main() to be called)');
assert(!runtimeExited, 'the runtime was exited (use NO_EXIT_RUNTIME to keep it alive after main() exits)');
return real__free.apply(null, arguments);
};

var real____errno_location = asm["___errno_location"]; asm["___errno_location"] = function() {
assert(runtimeInitialized, 'you need to wait for the runtime to be ready (e.g. wait for main() to be called)');
assert(!runtimeExited, 'the runtime was exited (use NO_EXIT_RUNTIME to keep it alive after main() exits)');
return real____errno_location.apply(null, arguments);
};
Module["asm"] = asm;
var _malloc = Module["_malloc"] = function() { return Module["asm"]["_malloc"].apply(null, arguments) };
var getTempRet0 = Module["getTempRet0"] = function() { return Module["asm"]["getTempRet0"].apply(null, arguments) };
var _fflush = Module["_fflush"] = function() { return Module["asm"]["_fflush"].apply(null, arguments) };
var _main = Module["_main"] = function() { return Module["asm"]["_main"].apply(null, arguments) };
var setTempRet0 = Module["setTempRet0"] = function() { return Module["asm"]["setTempRet0"].apply(null, arguments) };
var establishStackSpace = Module["establishStackSpace"] = function() { return Module["asm"]["establishStackSpace"].apply(null, arguments) };
var _pthread_self = Module["_pthread_self"] = function() { return Module["asm"]["_pthread_self"].apply(null, arguments) };
var stackSave = Module["stackSave"] = function() { return Module["asm"]["stackSave"].apply(null, arguments) };
var _memset = Module["_memset"] = function() { return Module["asm"]["_memset"].apply(null, arguments) };
var _sbrk = Module["_sbrk"] = function() { return Module["asm"]["_sbrk"].apply(null, arguments) };
var stackRestore = Module["stackRestore"] = function() { return Module["asm"]["stackRestore"].apply(null, arguments) };
var _memcpy = Module["_memcpy"] = function() { return Module["asm"]["_memcpy"].apply(null, arguments) };
var stackAlloc = Module["stackAlloc"] = function() { return Module["asm"]["stackAlloc"].apply(null, arguments) };
var setThrew = Module["setThrew"] = function() { return Module["asm"]["setThrew"].apply(null, arguments) };
var _test_call = Module["_test_call"] = function() { return Module["asm"]["_test_call"].apply(null, arguments) };
var _free = Module["_free"] = function() { return Module["asm"]["_free"].apply(null, arguments) };
var ___errno_location = Module["___errno_location"] = function() { return Module["asm"]["___errno_location"].apply(null, arguments) };
var runPostSets = Module["runPostSets"] = function() { return Module["asm"]["runPostSets"].apply(null, arguments) };
var dynCall_ii = Module["dynCall_ii"] = function() { return Module["asm"]["dynCall_ii"].apply(null, arguments) };
var dynCall_iiii = Module["dynCall_iiii"] = function() { return Module["asm"]["dynCall_iiii"].apply(null, arguments) };
var dynCall_vi = Module["dynCall_vi"] = function() { return Module["asm"]["dynCall_vi"].apply(null, arguments) };
;

Runtime.stackAlloc = Module['stackAlloc'];
Runtime.stackSave = Module['stackSave'];
Runtime.stackRestore = Module['stackRestore'];
Runtime.establishStackSpace = Module['establishStackSpace'];

Runtime.setTempRet0 = Module['setTempRet0'];
Runtime.getTempRet0 = Module['getTempRet0'];



// === Auto-generated postamble setup entry stuff ===

Module['asm'] = asm;



if (memoryInitializer) {
  if (typeof Module['locateFile'] === 'function') {
    memoryInitializer = Module['locateFile'](memoryInitializer);
  } else if (Module['memoryInitializerPrefixURL']) {
    memoryInitializer = Module['memoryInitializerPrefixURL'] + memoryInitializer;
  }
  if (ENVIRONMENT_IS_NODE || ENVIRONMENT_IS_SHELL) {
    var data = Module['readBinary'](memoryInitializer);
    HEAPU8.set(data, Runtime.GLOBAL_BASE);
  } else {
    addRunDependency('memory initializer');
    var applyMemoryInitializer = function(data) {
      if (data.byteLength) data = new Uint8Array(data);
      for (var i = 0; i < data.length; i++) {
        assert(HEAPU8[Runtime.GLOBAL_BASE + i] === 0, "area for memory initializer should not have been touched before it's loaded");
      }
      HEAPU8.set(data, Runtime.GLOBAL_BASE);
      // Delete the typed array that contains the large blob of the memory initializer request response so that
      // we won't keep unnecessary memory lying around. However, keep the XHR object itself alive so that e.g.
      // its .status field can still be accessed later.
      if (Module['memoryInitializerRequest']) delete Module['memoryInitializerRequest'].response;
      removeRunDependency('memory initializer');
    }
    function doBrowserLoad() {
      Module['readAsync'](memoryInitializer, applyMemoryInitializer, function() {
        throw 'could not load memory initializer ' + memoryInitializer;
      });
    }
    if (Module['memoryInitializerRequest']) {
      // a network request has already been created, just use that
      function useRequest() {
        var request = Module['memoryInitializerRequest'];
        if (request.status !== 200 && request.status !== 0) {
          // If you see this warning, the issue may be that you are using locateFile or memoryInitializerPrefixURL, and defining them in JS. That
          // means that the HTML file doesn't know about them, and when it tries to create the mem init request early, does it to the wrong place.
          // Look in your browser's devtools network console to see what's going on.
          console.warn('a problem seems to have happened with Module.memoryInitializerRequest, status: ' + request.status + ', retrying ' + memoryInitializer);
          doBrowserLoad();
          return;
        }
        applyMemoryInitializer(request.response);
      }
      if (Module['memoryInitializerRequest'].response) {
        setTimeout(useRequest, 0); // it's already here; but, apply it asynchronously
      } else {
        Module['memoryInitializerRequest'].addEventListener('load', useRequest); // wait for it
      }
    } else {
      // fetch it from the network ourselves
      doBrowserLoad();
    }
  }
}


function ExitStatus(status) {
  this.name = "ExitStatus";
  this.message = "Program terminated with exit(" + status + ")";
  this.status = status;
};
ExitStatus.prototype = new Error();
ExitStatus.prototype.constructor = ExitStatus;

var initialStackTop;
var preloadStartTime = null;
var calledMain = false;

dependenciesFulfilled = function runCaller() {
  // If run has never been called, and we should call run (INVOKE_RUN is true, and Module.noInitialRun is not false)
  if (!Module['calledRun']) run();
  if (!Module['calledRun']) dependenciesFulfilled = runCaller; // try this again later, after new deps are fulfilled
}

Module['callMain'] = Module.callMain = function callMain(args) {
  assert(runDependencies == 0, 'cannot call main when async dependencies remain! (listen on __ATMAIN__)');
  assert(__ATPRERUN__.length == 0, 'cannot call main when preRun functions remain to be called');

  args = args || [];

  ensureInitRuntime();

  var argc = args.length+1;
  function pad() {
    for (var i = 0; i < 4-1; i++) {
      argv.push(0);
    }
  }
  var argv = [allocate(intArrayFromString(Module['thisProgram']), 'i8', ALLOC_NORMAL) ];
  pad();
  for (var i = 0; i < argc-1; i = i + 1) {
    argv.push(allocate(intArrayFromString(args[i]), 'i8', ALLOC_NORMAL));
    pad();
  }
  argv.push(0);
  argv = allocate(argv, 'i32', ALLOC_NORMAL);


  try {

    var ret = Module['_main'](argc, argv, 0);


    // if we're not running an evented main loop, it's time to exit
    exit(ret, /* implicit = */ true);
  }
  catch(e) {
    if (e instanceof ExitStatus) {
      // exit() throws this once it's done to make sure execution
      // has been stopped completely
      return;
    } else if (e == 'SimulateInfiniteLoop') {
      // running an evented main loop, don't immediately exit
      Module['noExitRuntime'] = true;
      return;
    } else {
      if (e && typeof e === 'object' && e.stack) Module.printErr('exception thrown: ' + [e, e.stack]);
      throw e;
    }
  } finally {
    calledMain = true;
  }
}




function run(args) {
  args = args || Module['arguments'];

  if (preloadStartTime === null) preloadStartTime = Date.now();

  if (runDependencies > 0) {
    Module.printErr('run() called, but dependencies remain, so not running');
    return;
  }

  writeStackCookie();

  preRun();

  if (runDependencies > 0) return; // a preRun added a dependency, run will be called later
  if (Module['calledRun']) return; // run may have just been called through dependencies being fulfilled just in this very frame

  function doRun() {
    if (Module['calledRun']) return; // run may have just been called while the async setStatus time below was happening
    Module['calledRun'] = true;

    if (ABORT) return;

    ensureInitRuntime();

    preMain();

    if (ENVIRONMENT_IS_WEB && preloadStartTime !== null) {
      Module.printErr('pre-main prep time: ' + (Date.now() - preloadStartTime) + ' ms');
    }

    if (Module['onRuntimeInitialized']) Module['onRuntimeInitialized']();

    if (Module['_main'] && shouldRunNow) Module['callMain'](args);

    postRun();
  }

  if (Module['setStatus']) {
    Module['setStatus']('Running...');
    setTimeout(function() {
      setTimeout(function() {
        Module['setStatus']('');
      }, 1);
      doRun();
    }, 1);
  } else {
    doRun();
  }
  checkStackCookie();
}
Module['run'] = Module.run = run;

function exit(status, implicit) {
  if (implicit && Module['noExitRuntime']) {
    Module.printErr('exit(' + status + ') implicitly called by end of main(), but noExitRuntime, so not exiting the runtime (you can use emscripten_force_exit, if you want to force a true shutdown)');
    return;
  }

  if (Module['noExitRuntime']) {
    Module.printErr('exit(' + status + ') called, but noExitRuntime, so halting execution but not exiting the runtime or preventing further async execution (you can use emscripten_force_exit, if you want to force a true shutdown)');
  } else {

    ABORT = true;
    EXITSTATUS = status;
    STACKTOP = initialStackTop;

    exitRuntime();

    if (Module['onExit']) Module['onExit'](status);
  }

  if (ENVIRONMENT_IS_NODE) {
    process['exit'](status);
  } else if (ENVIRONMENT_IS_SHELL && typeof quit === 'function') {
    quit(status);
  }
  // if we reach here, we must throw an exception to halt the current execution
  throw new ExitStatus(status);
}
Module['exit'] = Module.exit = exit;

var abortDecorators = [];

function abort(what) {
  if (what !== undefined) {
    Module.print(what);
    Module.printErr(what);
    what = JSON.stringify(what)
  } else {
    what = '';
  }

  ABORT = true;
  EXITSTATUS = 1;

  var extra = '';

  var output = 'abort(' + what + ') at ' + stackTrace() + extra;
  if (abortDecorators) {
    abortDecorators.forEach(function(decorator) {
      output = decorator(output, what);
    });
  }
  throw output;
}
Module['abort'] = Module.abort = abort;

// {{PRE_RUN_ADDITIONS}}

if (Module['preInit']) {
  if (typeof Module['preInit'] == 'function') Module['preInit'] = [Module['preInit']];
  while (Module['preInit'].length > 0) {
    Module['preInit'].pop()();
  }
}

// shouldRunNow refers to calling main(), not run().
var shouldRunNow = true;
if (Module['noInitialRun']) {
  shouldRunNow = false;
}


run();

// {{POST_RUN_ADDITIONS}}





// {{MODULE_ADDITIONS}}



// POST

