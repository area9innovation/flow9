package js;

import js.BinaryBuffer;

class BinaryParser {
	private var bigEndian:  Bool;
	private var allowExceptions: Bool;

	public function new(bigEndian, allowExceptions) {
		this.bigEndian = bigEndian;
		this.allowExceptions = allowExceptions;
	}

	public function encodeFloat(number: Float, precisionBits: Int, exponentBits: Int): String{
		untyped __js__("
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
			    (exp != bias + 1 - len && exp < minUnnormExp && this.warn(\"encodeFloat::float underflow\"), i = bias + 1 - (exp = minExp - 1));
			(intPart || status !== 0) && (this.warn(intPart ? \"encodeFloat::float overflow\" : \"encodeFloat::\" + status),
			    exp = maxExp + 1, i = bias + 2, status == -Infinity ? signal = 1 : isNaN(status) && (bin[i] = 1));
			for(n = Math.abs(exp + bias), j = exponentBits + 1, result = \"\"; --j; result = (n % 2) + result, n = n >>= 1);
			for(var n = 0, j = 0, i = (result = (signal ? \"1\" : \"0\") + result + bin.slice(i, i + precisionBits).join(\"\")).length, r = [];
			    i; n += (1 << j) * result.charAt(--i), j == 7 && (r[r.length] = String.fromCharCode(n), n = 0), j = (j + 1) % 8);
			r[r.length] = n ? String.fromCharCode(n) : \"\";
			return (this.bigEndian ? r.reverse() : r).join(\"\");
		");

		return "";
	}

	public function decodeFloat(data, precisionBits, exponentBits): Float {
		untyped __js__ ("
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
		");

		return 0.0;
	}

	public function warn(msg){
		if(this.allowExceptions)
			untyped __js__("throw new Error(msg);");
		return 1;
	}

	public function toDouble(data: String): Float{
		return decodeFloat(data, 52, 11);
	}

	public function fromDouble(number: Float): String {
		return encodeFloat(number, 52, 11);
	}
}
