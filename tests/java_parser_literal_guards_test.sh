#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Compile the test in the same module as the private generated rules. Calling
# them directly observes the cursor before SyntaxStar or backtracking resets it.
cat tools/flowc/backends/java/parser/java_parser.flow - > "$tmp/literal_guards.flow" <<'FLOW'

checkLiteralBody(name : string, parseBody : (SyntaxParseAcc) -> SyntaxTree) -> bool {
	// An actual NUL is in range; EOF immediately after it is not.
	source = "\u0000";
	acc = SyntaxParseAcc(source, strlen(source), 0, [], noExpectError);
	nul = parseBody(acc);
	if (nul.choice == -1 || acc.i != acc.length) {
		println(name + ": did not consume the literal character");
		false;
	} else {
		eof = parseBody(acc);
		if (eof.choice == -1 && acc.i == acc.length) true else {
			println(name + ": expected failure without advancing at EOF, got choice " + i2s(eof.choice) + ", cursor " + i2s(acc.i));
			false;
		}
	}
}

main() {
	c = checkLiteralBody("CharLiteral", do_parse_Compilation_CharLiteral__choice307);
	s = checkLiteralBody("StringLiteral", do_parse_Compilation_StringLiteral__choice309);
	// CLASS matches its literal, then !LetterOrDigit rejects X. A positive
	// 3*i+2 in place of the published -1 would still have choice == -1.
	keyword = do_parse_Compilation_CLASS(SyntaxParseAcc("classX", 6, 0, [], noExpectError));
	andOp = do_parse_Compilation_AND(SyntaxParseAcc("&&", 2, 0, [], noExpectError));
	legacy = keyword.choice == -1 && keyword.rule == -1 && keyword.end == 6
		&& andOp.choice == -1 && andOp.rule == -3;
	if (!legacy) println("Changed CLASS/AND negation results: " + toString([keyword, andOp]));
	quit(if (c && s && legacy) 0 else 1);
}
FLOW

bin/flowc1 server=0 incremental=0 "I=$tmp" "bytecode=$tmp/test.bytecode" literal_guards.flow
bin/flowcpp --batch "$tmp/test.bytecode"
