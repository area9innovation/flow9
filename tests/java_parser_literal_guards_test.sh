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
	quit(if (c && s) 0 else 1);
}
FLOW

bin/flowc1 server=0 incremental=0 "I=$tmp" "bytecode=$tmp/test.bytecode" literal_guards.flow
bin/flowcpp --batch "$tmp/test.bytecode"
