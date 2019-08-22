/*
 * Copyright (C)2005-2017 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
import haxe.ds.Vector;
/**
	Creates a MD5 of a String.
**/
class JsMd5 {
	public static function encode(s : String) : String {
		var m = new JsMd5();
		var h = m.doEncode(str2blks(s));
		return m.hex(h);
	}

/*
 * A JavaScript implementation of the RSA Data Security, Inc. MD5 Message
 * Digest Algorithm, as defined in RFC 1321.
 * Copyright (C) Paul Johnston 1999 - 2000.
 * Updated by Greg Holt 2000 - 2001.
 * See http://pajhome.org.uk/site/legal.html for details.
 */

	function new() {
	}

	function bitOR(a, b) {
		var lsb = (a & 0x1) | (b & 0x1);
		var msb31 = (a >>> 1) | (b >>> 1);
		return (msb31 << 1) | lsb;
	}

	function bitXOR(a, b) {
		var lsb = (a & 0x1) ^ (b & 0x1);
		var msb31 = (a >>> 1) ^ (b >>> 1);
		return (msb31 << 1) | lsb;
	}

	function bitAND(a, b) {
		var lsb = (a & 0x1) & (b & 0x1);
		var msb31 = (a >>> 1) & (b >>> 1);
		return (msb31 << 1) | lsb;
	}

	function addme(x, y) {
		var lsw = (x & 0xFFFF)+(y & 0xFFFF);
		var msw = (x >> 16)+(y >> 16)+(lsw >> 16);
		return (msw << 16) | (lsw & 0xFFFF);
	}

	function hex(a : Array<Int>) {
		var str = "";
		var hex_chr = "0123456789abcdef";
		for( num in a )
			for( j in 0...4 )
				str += hex_chr.charAt((num >> (j * 8 + 4)) & 0x0F) +
							 hex_chr.charAt((num >> (j * 8)) & 0x0F);
		return str;
	}

	static function str2blks(s : String) : Vector<Int> {
		// utf16-decode and utf8-encode
		var i = 0;
		var count = 0;
		
		// Compute number of bytes first
		while (i < s.length) {
			var c : Int = StringTools.fastCodeAt(s, i++);
			// surrogate pair
			if (0xD800 <= c && c <= 0xDBFF) {
				c = (c - 0xD7C0 << 10) | (StringTools.fastCodeAt(s, i++) & 0x3FF);
			}
			if (c <= 0x7F) {
				count++;
			} else if (c <= 0x7FF) {
				count += 2;
			} else if (c <= 0xFFFF) {
				count += 3;
			} else {
				count += 4;
			}
		}
		// Allocate array of required length
		var a = new Vector<Int>(count);
		i = 0;
		count = 0;
		// Fill array with bytes
		while (i < s.length) {
			var c : Int = StringTools.fastCodeAt(s, i++);
			// surrogate pair
			if (0xD800 <= c && c <= 0xDBFF ) {
				c = (c - 0xD7C0 << 10) | (StringTools.fastCodeAt(s, i++) & 0x3FF);
			}
			if (c <= 0x7F) {
				a[count++] = c;
			} else if (c <= 0x7FF) {
				a[count++] = 0xC0 | (c >> 6);
				a[count++] = 0x80 | (c & 63);
			} else if (c <= 0xFFFF) {
				a[count++] = 0xE0 | (c >> 12);
				a[count++] = 0x80 | ((c >> 6) & 63);
				a[count++] = 0x80 | (c & 63);
			} else {
				a[count++] = 0xF0 | (c >> 18);
				a[count++] = 0x80 | ((c >> 12) & 63);
				a[count++] = 0x80 | ((c >> 6) & 63);
				a[count++] = 0x80 | (c & 63);
			}
		}
		return a;
	}

	function rol(num, cnt) {
		return (num << cnt) | (num >>> (32 - cnt));
	}

	function cmn(q, a, b, x, s, t) {
		return addme(rol((addme(addme(a, q), addme(x, t))), s), b);
	}

	function ff(a, b, c, d, x, s, t) {
		return cmn(bitOR(bitAND(b, c), bitAND((~b), d)), a, b, x, s, t);
	}

	function gg(a, b, c, d, x, s, t) {
		return cmn(bitOR(bitAND(b, d), bitAND(c, (~d))), a, b, x, s, t);
	}

	function hh(a, b, c, d, x, s, t) {
		return cmn(bitXOR(bitXOR(b, c), d), a, b, x, s, t);
	}

	function ii(a, b, c, d, x, s, t) {
		return cmn(bitXOR(c, bitOR(b, (~d))), a, b, x, s, t);
	}

	function setBlockData(b : Vector<Int>, x : Vector<Int>, blockNumber : Int, numberOfBlocks : Int) : Void {
		var i = 0;
		var byteOffset = blockNumber << 6;

		var getByte = function (idx) {
			if (idx < b.length) {
				return b.get(idx);
			} else if (idx == b.length) {
				return 0x80;
			} else {
				return 0;
			}
		};

		for (i in 0...16) {
			if ((blockNumber + 1) == numberOfBlocks && i == 14) {
				x[i] = b.length << 3;
			} else {
				x[i] = getByte(byteOffset) 
					| (getByte(byteOffset + 1) << 8)
					| (getByte(byteOffset + 2) << 16)
					| (getByte(byteOffset + 3) << 24);
			}
			byteOffset += 4;
		}
	}

	function doEncode(bytes : Vector<Int>) : Array<Int> {

		var a =  1732584193;
		var b = -271733879;
		var c = -1732584194;
		var d =  271733878;

		var step;

		var numberOfBlocks = ((bytes.length + 8) >> 6) + 1;
		var x = new Vector<Int>(16);

		var blockNumber = 0;
		while (blockNumber < numberOfBlocks)  {
			var olda = a;
			var oldb = b;
			var oldc = c;
			var oldd = d;

			setBlockData(bytes, x, blockNumber, numberOfBlocks);

			step = 0;
			a = ff(a, b, c, d, x[0], 7 , -680876936);
			d = ff(d, a, b, c, x[1], 12, -389564586);
			c = ff(c, d, a, b, x[2], 17,  606105819);
			b = ff(b, c, d, a, x[3], 22, -1044525330);
			a = ff(a, b, c, d, x[4], 7 , -176418897);
			d = ff(d, a, b, c, x[5], 12,  1200080426);
			c = ff(c, d, a, b, x[6], 17, -1473231341);
			b = ff(b, c, d, a, x[7], 22, -45705983);
			a = ff(a, b, c, d, x[8], 7 ,  1770035416);
			d = ff(d, a, b, c, x[9], 12, -1958414417);
			c = ff(c, d, a, b, x[10], 17, -42063);
			b = ff(b, c, d, a, x[11], 22, -1990404162);
			a = ff(a, b, c, d, x[12], 7 ,  1804603682);
			d = ff(d, a, b, c, x[13], 12, -40341101);
			c = ff(c, d, a, b, x[14], 17, -1502002290);
			b = ff(b, c, d, a, x[15], 22,  1236535329);
			a = gg(a, b, c, d, x[1], 5 , -165796510);
			d = gg(d, a, b, c, x[6], 9 , -1069501632);
			c = gg(c, d, a, b, x[11], 14,  643717713);
			b = gg(b, c, d, a, x[0], 20, -373897302);
			a = gg(a, b, c, d, x[5], 5 , -701558691);
			d = gg(d, a, b, c, x[10], 9 ,  38016083);
			c = gg(c, d, a, b, x[15], 14, -660478335);
			b = gg(b, c, d, a, x[4], 20, -405537848);
			a = gg(a, b, c, d, x[9], 5 ,  568446438);
			d = gg(d, a, b, c, x[14], 9 , -1019803690);
			c = gg(c, d, a, b, x[3], 14, -187363961);
			b = gg(b, c, d, a, x[8], 20,  1163531501);
			a = gg(a, b, c, d, x[13], 5 , -1444681467);
			d = gg(d, a, b, c, x[2], 9 , -51403784);
			c = gg(c, d, a, b, x[7], 14,  1735328473);
			b = gg(b, c, d, a, x[12], 20, -1926607734);
			a = hh(a, b, c, d, x[5], 4 , -378558);
			d = hh(d, a, b, c, x[8], 11, -2022574463);
			c = hh(c, d, a, b, x[11], 16,  1839030562);
			b = hh(b, c, d, a, x[14], 23, -35309556);
			a = hh(a, b, c, d, x[1], 4 , -1530992060);
			d = hh(d, a, b, c, x[4], 11,  1272893353);
			c = hh(c, d, a, b, x[7], 16, -155497632);
			b = hh(b, c, d, a, x[10], 23, -1094730640);
			a = hh(a, b, c, d, x[13], 4 ,  681279174);
			d = hh(d, a, b, c, x[0], 11, -358537222);
			c = hh(c, d, a, b, x[3], 16, -722521979);
			b = hh(b, c, d, a, x[6], 23,  76029189);
			a = hh(a, b, c, d, x[9], 4 , -640364487);
			d = hh(d, a, b, c, x[12], 11, -421815835);
			c = hh(c, d, a, b, x[15], 16,  530742520);
			b = hh(b, c, d, a, x[2], 23, -995338651);
			a = ii(a, b, c, d, x[0], 6 , -198630844);
			d = ii(d, a, b, c, x[7], 10,  1126891415);
			c = ii(c, d, a, b, x[14], 15, -1416354905);
			b = ii(b, c, d, a, x[5], 21, -57434055);
			a = ii(a, b, c, d, x[12], 6 ,  1700485571);
			d = ii(d, a, b, c, x[3], 10, -1894986606);
			c = ii(c, d, a, b, x[10], 15, -1051523);
			b = ii(b, c, d, a, x[1], 21, -2054922799);
			a = ii(a, b, c, d, x[8], 6 ,  1873313359);
			d = ii(d, a, b, c, x[15], 10, -30611744);
			c = ii(c, d, a, b, x[6], 15, -1560198380);
			b = ii(b, c, d, a, x[13], 21,  1309151649);
			a = ii(a, b, c, d, x[4], 6 , -145523070);
			d = ii(d, a, b, c, x[11], 10, -1120210379);
			c = ii(c, d, a, b, x[2], 15,  718787259);
			b = ii(b, c, d, a, x[9], 21, -343485551);

			a = addme(a, olda);
			b = addme(b, oldb);
			c = addme(c, oldc);
			d = addme(d, oldd);

			blockNumber++;
		}
		return [a,b,c,d];
	}
}
