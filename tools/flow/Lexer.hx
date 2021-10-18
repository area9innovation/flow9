enum Token {
	LName(s : String);
	LInt(i : Int);
	LDouble(f : Float);
	LString(s : String);
	LStringInclude(path : String);
	LColon;
	LColonColonEqual;
	LPlus;
	LMinus;
	LMultiply;
	LDivide;
	LModulo;
	LPling;
	LBackslash;
	LLeftParenthesis;
	LRightParenthesis;
	LLeftBracket;
	LRightBracket;
	LLeftBrace;
	LRightBrace;
	LPipe;
	LPipeForward;
	LAssign;
	LRefAssign;
	LEqual;
	LArrow;
    LRulesArrow;
	LNotEqual;
	LLessThan;
	LGreaterThan;
	LLessEqual;
	LGreaterEqual;
	LDot;
	LComma;
	LAnd;
	LNot;
	LOr;
	LSemi;
	LHat;
	LComment(comment : String);
	LQuestion(i : Int);
	LIf;
	LElse;
	LRef;
	LRequire;
	LEOF;
	LWith;
	LSquiggly;
	LError(s : String);
}

class Lexer {

    private static var cache = new Map();
	
  public static function New(relativeFilename : String/* used as cache id */, s : String, noCache : Bool, rules : Bool) {
	  if (!noCache) {
		Assert.check(relativeFilename != null, "relativeFilename != null");
		Assert.check(!rules, "!rules");
		var lexer = cache.get(relativeFilename);
		if (lexer == null) {
		  lexer = new Lexer(relativeFilename, s, rules);
		  cache.set(relativeFilename, lexer);
		}
		return lexer;
	  } else 
		return new Lexer(relativeFilename, s, rules);
    }

    private function new(relativeFilename : String/* used as cache id */, s : String, rules : Bool) {
		linebreaks = new FlowArray();
		this.s = s;
		this.rules = rules;
		this.tokens = null;
	}

	var s : String;
    var rules : Bool;
  
	public function getLineNumber(i : Int) : Int {
		return linenumbers[i];
	}
	// Records which token is last on each line.
	var linebreaks : FlowArray<Int>;
	
	var i : Int;
	var tokens : FlowArray<Token>;
	// Offsets into the file for where tokens start
	var tokenStarts : FlowArray<Int>;
	// How long each token is in bytes
	var tokenLengths : FlowArray<Int>;

	private static var STR_0 = "0";
	private static var KEYWORD_TOKENS = new Map<String, Token>();

	public function lex() : FlowArray<Token> {
  	    if (tokens != null) {
		    return tokens;
	    }
		Profiler.get().profileStart("Lexing");
		tokens = new FlowArray<Token>();
		tokenStarts = new FlowArray<Int>();
		tokenLengths = new FlowArray<Int>();

		KEYWORD_TOKENS.set('if', LIf);
		KEYWORD_TOKENS.set('else', LElse);
		KEYWORD_TOKENS.set('ref', LRef);
		KEYWORD_TOKENS.set('require', LRequire);
		KEYWORD_TOKENS.set('with', LWith);

		i = 0;

		var line = 0;
		var newline = function() {
			// Skip, but record where the line break goes
			line++;
			linebreaks.push(tokens.length - 1);
			// trace('Line: ' + linebreaks.length + ' starts with: ' + me.s.substr(i, 20));
		}

		// Skip utf8 bom (byte order mark)
		if (s.length > 2 && charCodeAt(0) == 0xef && charCodeAt(1) == 0xbb && charCodeAt(2) == 0xbf) {
			i += 3;
		}
		
		while (i < s.length) {
			var c = charCodeAt(i++);
			
			if ("0".code <= c && c <= "9".code) {
				// Starts with a number
				//Profiler.get().profileStart("Number");
				var startIndex = i - 1;
				while (c <= "9".code && ("0".code <= c) || c == ".".code) {
					if (i == s.length) {
						++i;
						break;
					}
					c = charCodeAt(i++);
				}
				var token = s.substr(startIndex, i - startIndex - 1);
				if (c == "x".code && token == STR_0) {
					// hex
					var v : Int = 0x00;
					c = charCodeAt(i++);
					while (("0".code <= c && c <= "9".code) 
						|| ("a".code <= c && c <= "f".code) 
						|| ("A".code <= c && c <= "F".code)) {
						var digit = 0;
						if ("0".code <= c && c <= "9".code) {
							digit = c - "0".code;
						} else if ("a".code <= c && c <= "f".code) {
							digit = c - "a".code + 10;
						} else {
							digit = c - "A".code + 10;
						}
						v = (v << 4) | digit;

						if (i == s.length) {
							++i;
							break;
						}
						c = charCodeAt(i++);
					}
					--i;
					push(LInt(v), i - startIndex);
				} else if (token.length > 0) {
					--i;
					if (token.indexOf('.') != -1) {
						// TODO: If there are two .s in the string, this is a mistake
						push(LDouble(Std.parseFloat(token)), i - startIndex);
					} else {
						// On neko, Int is not 32 bit, so we parse as a float
						var v : Float = Std.parseFloat(token);
						push(LInt(I2i.intFromFloat(v)), i - startIndex);
					}
				}
				//Profiler.get().profileEnd("Number");
			} else if ( ("a".code <= c && c <= "z".code)
				|| ("A".code <= c && c <= "Z".code) 
				|| c == "_".code
				|| rules && c == "$".code) {
				// ID
				//Profiler.get().profileStart("ID");
				var startIndex = i - 1;
				// Does not start with a number - an id most likely
				while ( ("a".code <= c && c <= "z".code)
					|| ("A".code <= c && c <= "Z".code) 
					|| ("0".code <= c && c <= "9".code) 
					|| c == "_".code
				    || rules && c == "$".code) {
					if (i == s.length) {
						++i;
						break;
					}
					c = charCodeAt(i++);
				}
				var token = s.substr(startIndex, i - startIndex - 1);
				if (token.length == 0) {
					// i.e., none of the chars above
					push(LError("Illegal char '" + c + "'"), i - startIndex);
				} else {
					--i;
					var kwd = KEYWORD_TOKENS.get(token);
					push(kwd == null ? LName(token) : kwd, i - startIndex);
				}
				//Profiler.get().profileEnd("ID");
			} else {
				//Profiler.get().profileStart("Other" + c);
				switch (c) {
				case " ".code: // Skip
				case "\n".code: 
					newline();
				case "\r".code: // Skip
				case "\t".code: // Skip
				case ":".code: 
					if (charCodeAt(i) == "=".code) {
						++i;
						push(LRefAssign, 2);
					} else if (charCodeAt(i) == ":".code && charCodeAt(i + 1) == "=".code) {
						i += 2;
						push(LColonColonEqual, 3);
					} else {
						push(LColon, 1);
					}
				case ";".code: push(LSemi, 1);
				case "+".code: push(LPlus, 1);
				case "-".code: 
					if (charCodeAt(i) == ">".code) {
						++i;
						push(LArrow, 2);
					} else {
						push(LMinus, 1);
					}
				case "*".code: push(LMultiply, 1);
				case "\'".code: push(LPling, 1);
				case "/".code: 
					var n = charCodeAt(i);
					if (n == "/".code) {
						// Single line comment
						//var comment = '//';
						++i;
						while (i < s.length && charCodeAt(i) != "\n".code) {
							// comment += s.charAt(i);
							++i;
						}
						newline();
						++i;
						// push(LComment(comment));
					} else if (n == "*".code) {
						// Multi line comment
						//var comment = '/*';
						++i;
						while (!(charCodeAt(i) == "*".code && charCodeAt(i + 1) == "/".code)) {
							var c = charCodeAt(i);
							// comment += c;
							if (c == "\n".code) {
								newline();
							}
							++i;
							if (i == s.length) {
							  Errors.report("Unterminated '/*' comment");
							  break;
							}
						}
						i += 2;
						// push(LComment(comment + "*/"));
					} else {
						push(LDivide, 1);
					}

				case "%".code: push(LModulo, 1);
				case "^".code: push(LHat, 1);
				case "(".code: push(LLeftParenthesis, 1);
				case ")".code: push(LRightParenthesis, 1);
				case "[".code: push(LLeftBracket, 1);
				case "]".code: push(LRightBracket, 1);
				case "{".code: push(LLeftBrace, 1);
				case "}".code: push(LRightBrace, 1);
				case "\\".code: push(LBackslash, 1);
				case "|".code: 
					if (charCodeAt(i) == "|".code) {
						++i;
						push(LOr, 2);
					} else if (charCodeAt(i) == ">".code) {
						++i;
						push(LPipeForward, 2);
					} else {
						push(LPipe, 1);
					}
				case "=".code: 
					if (charCodeAt(i) == "=".code) {
						++i;
						push(LEqual, 2);
					}
					else if (rules && charCodeAt(i) == ">".code) {
						++i;
						push(LRulesArrow, 2);
				    } else {
						push(LAssign, 1);
					}
				case "<".code: 
					if (charCodeAt(i) == "=".code) {
						++i;
						push(LLessEqual, 2);
					} else {
						push(LLessThan, 1);
					}
				case ">".code: 
					if (charCodeAt(i) == "=".code) {
						++i;
						push(LGreaterEqual, 2);
					} else {
						push(LGreaterThan, 1);
					}
				case "!".code:
					if (charCodeAt(i) == "=".code) {
						++i;
						push(LNotEqual, 2);
					} else {
						push(LNot, 1);
					}
				case ".".code: push(LDot, 1);
				case ",".code: push(LComma, 1);
				case "&".code: 
					if (charCodeAt(i) == "&".code) {
						++i;
						push(LAnd, 2);
					} else {
						push(LError("Expected &"), 1);
					}
				case "?".code:
					var c = 0;
					while (charCodeAt(i) == 63) {
						++i;
						++c;
					}
					push(LQuestion(c), c);
				case "\"".code: 
					// String:
					var startIndex = i;
					var lastIndex = i;
					var endIndex = i;
					
					var token = new StringBuf();
					var addSoFar = function() {
						endIndex = i;
						token.addSub(s, lastIndex, endIndex - lastIndex - 1);
					}
					
					while (i < s.length) {
						c = charCodeAt(i++);
						if (c == "\"".code) {
							addSoFar();
							// eat whitespace until next doublequote & continue parsing the string then
							var reopen = false;
							while (i < s.length) {
								c = charCodeAt(i++);
								switch (c) {
									case " ".code: // Skip
									case "\n".code: 
										newline();
									case "\r".code: // Skip
									case "\t".code: // Skip
									case "\"".code:
										reopen = true; // reopen the string
										break;
									default:
										// no doublequote found, so end this string with 1 putback:
										--i;
										c = "\"".code;
										break;
								}
							}
							lastIndex = i;
							if (reopen) continue else break;
						}
						if (c == "\\".code) {
							addSoFar();
							if (i >= s.length) {
								push(LError("Expected more after \\"), i - startIndex);
								break; 
							}
							var n = charCodeAt(i++);
							if (n == "n".code) {
								c = "\n".code;
							} else if (n == "t".code) {
								c = "\t".code;
							} else if (n == "r".code) {
								c = "\r".code;
							} else if (n == "\\".code) {
								c = "\\".code;
							} else if (n == "\"".code) {
								c = "\"".code;
							} else if (n == "X".code || n == "u".code) {
								// \uHHHH or \XHHHH where H are hexadecimal digits
								var hexDigit1 = charCodeAt(i++);
								var hexDigit2 = charCodeAt(i++);
								var hexDigit3 = charCodeAt(i++);
								var hexDigit4 = charCodeAt(i++);
								var t = "0x" + String.fromCharCode(hexDigit1) + String.fromCharCode(hexDigit2)
										+ String.fromCharCode(hexDigit3) + String.fromCharCode(hexDigit4);
								c = Std.parseInt(t);
							} else if (n == "x".code) {
								// \xHH where H are hexadecimal digits
								var hexDigit1 = charCodeAt(i++);
								var hexDigit2 = charCodeAt(i++);
								var t = "0x" + String.fromCharCode(hexDigit1) + String.fromCharCode(hexDigit2);
								c = Std.parseInt(t);
							} else {
								push(LError("Unknown escape after \\: " + n), i - startIndex);
								c = n;
							}
							#if sys
								var str = new haxe.Utf8();
								str.addChar(c);
								token.add( str.toString() );
							#else
								token.add( String.fromCharCode(c) );
							#end
							lastIndex = i;
						} else if (c == 13) {
							// These we ignore!
							addSoFar();
							lastIndex = i;
						} else if (c == 10) {
							// Just to keep tracking line numbers correct
							newline();
						}
					}
					if (c != "\"".code) {
						push(LError("Expected end quote"), i - startIndex + 1);
					}
					var t = i;
					i = endIndex;
               		var tokens = token.toString();
					push(if (StringTools.startsWith(tokens, "#include")) LStringInclude(StringTools.trim(tokens.substr(8)))
							 else LString(tokens), endIndex - startIndex + 1);
					i = t;
					
				case "~".code: {
					if (charCodeAt(i) == ">".code) {
						++i;
						push(LSquiggly, 2);
					} else 
						push(LError("Expected > after ~"), i);
				}
				default:
					push(LError("Unexpected character: " + s.charAt(i)), 1);
				}
				//Profiler.get().profileEnd("Other" + c);
			}
		}
		push(LEOF, 0);
		newline();

		Profiler.get().profileEnd("Lexing");
		
		Profiler.get().profileStart("Calc line numbers");
		calcLinenumbers(tokens);
		Profiler.get().profileEnd("Calc line numbers");

		return tokens;
	}
	
	public function tokenToBytes(t : Int) : { start: Int, bytes : Int } {
		return  {
			start : tokenStarts[t],
			bytes : tokenLengths[t]
		};
	}

	inline function charCodeAt(i : Int) : Int {
		#if flash
		return untyped s.cca(i);
		#elseif neko
		// A trick found in Unserializer
		return untyped __dollar__sget(s.__s,i);
		#else
		return s.charCodeAt(i);
		#end
	}
	
	function push(t : Token, bytes : Int) : Void {
		tokens.push(t);
		var start = i - bytes;
		tokenStarts.push(start);
		tokenLengths.push(bytes);
		
		#if false
			if (s.length > bytes) {
				// To review the byte indexes, we lex the mini-string and compare with what we already got
				var substring = s.substr(start, bytes);
				var l = new Lexer(substring);
				var retokens = l.lex();
				if (!Type.enumEq(retokens[0], t)) {
					var intok =
						switch(t) {
						case LInt(i1):
							switch(retokens[0]) {
							case LInt(i2): (i1 != i2);
							default: false;
							}
						default: true;
						};
					if (!intok) {
						trace("Byte problem from " + start + "-" + bytes);
						trace(t);
						trace("/" + substring + "/");
						trace(retokens[0]);
					}
				}
			}
		#end
	}
	
	function calcLinenumbers(tokens : FlowArray<Token>) {
		var ntokens : Int = tokens.length;
		linenumbers = new FlowArray();
		var l = 0;
		var i = 0;
		
		var lastToken = linebreaks[0];
		var nbreaks : Int = linebreaks.length;
		do {
			while (i >= lastToken) {
				++l;
				if (l >= nbreaks) {
					break;
				}
				lastToken = linebreaks[l];
			}
			linenumbers.push(l + 1);
			++i;
		} while (i < ntokens);
	}
	
	public static function token2string(t : Token) : String {
		return switch(t) {
		case LName(s): s;
		case LInt(i): "" + i;
		case LDouble(f): "" + f;
		case LString(s): "\"" + s + "\"";
		case LStringInclude(path): "\"#include " + path + "\"";
		case LColon: ":";
		case LColonColonEqual: "::=";
		case LPlus: "+";
		case LMinus: "-";
		case LMultiply: "*";
		case LDivide: "/";
		case LModulo: "%";
		case LPling: "'";
		case LBackslash: "\\";
		case LLeftParenthesis: "(";
		case LRightParenthesis: ")";
		case LLeftBracket: "[";
		case LRightBracket: "]";
		case LLeftBrace: "{";
		case LRightBrace: "}";
		case LPipe: "|";
		case LPipeForward: "|>";
		case LAssign: "=";
		case LRefAssign: ":=";
		case LEqual: "==";
		case LArrow: "->";
		case LRulesArrow: "=>";
		case LNotEqual: "!=";
		case LLessThan: "<";
		case LGreaterThan: ">";
		case LLessEqual: "<=";
		case LGreaterEqual: ">=";
		case LDot: ".";
		case LComma: ",";
		case LAnd: "&&";
		case LNot: "!";
		case LOr: "||";
		case LSemi: ";";
		case LHat: "^";
		case LComment(comment): "/*" + comment + "*/";
		case LQuestion(i): "?" + i;
		case LIf: 'if';
		case LElse: 'else';
		case LRef: 'ref';
		case LRequire: 'require';
		case LWith: 'with';
		case LSquiggly: '~>';
		case LEOF: "<eof>";
		case LError(s): "Error: " + s;
		}
	}

    public function tokenAtPos(pos: Int): Int {
	  for (i in 0...tokens.length) {
		if (tokenStarts[i] <= pos && pos-tokenStarts[i] < tokenLengths[i]) {
		  return i;
		}
	  }
	  return -1;
    }
	
    public function tokenAtIndex(ind: Int): Token {
	  return tokens[ind];
    }
	
	// Look up from token index to line number
    public var linenumbers (default, null): FlowArray<Int>;
}
