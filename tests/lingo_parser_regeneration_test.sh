#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export FLOW="$root"
cd "$root"
bin/flowc1 server=0 incremental=0 "bytecode=$tmp/pegcompiler.bytecode" lib/lingo/pegcode/pegcompiler.flow
cd "$tmp"
generate() {
	"$root/bin/flowcpp" --batch pegcompiler.bytecode -- types=0 "$@"
}

# No checked-in modules exist for this grammar. !Stop must carry the mnemonic
# for Stop, and the AST module must compile even though it needs no accessors.
cat > tiny.lingo <<'LINGO'
Start = !Stop "a";
Stop = "b";
LINGO
generate file=tiny.lingo flowparser=tiny_parser flowparserast=tiny_ast.flow

# Rejected inputs must leave all three previously generated files intact.
outputs='tiny_parser.flow tiny_ast.flow tiny_ast_mnemonics.flow'
for f in $outputs; do cp "$f" "$f.good"; done
reject() {
	if generate "file=$1" flowparser=tiny_parser flowparserast=tiny_ast.flow > rejected.log 2>&1; then
		echo "Expected generation to fail: $2" >&2
		exit 1
	fi
	grep -F "$2" rejected.log || { cat rejected.log >&2; exit 1; }
	for f in $outputs; do cmp "$f" "$f.good"; done
}
printf '%s\n' 'old' 'Start=-7' 'Stop=-7' > tiny.lingo.mnemonics
reject tiny.lingo 'Duplicate legacy mnemonic ID: -7'
# Tabs on a nonblank row still aren't valid padding for a number.
printf 'old\nStop=\t-1\n' > tiny.lingo.mnemonics
reject tiny.lingo 'Invalid mnemonic table'
printf '%s\n' 'Expr = !Token_End End;' 'Token_End = "b";' 'End = "a";' > expr.lingo
printf '%s\n' 'Expr_Token' 'Token_End=-1' > expr.lingo.mnemonics
reject expr.lingo 'Duplicate mnemonic export: st_DidNotExpectExpr_Token_End'
printf '%s\n' 'Start = Expected_Start;' 'Expected_Start = "a";' > regular.lingo
reject regular.lingo 'Duplicate mnemonic export: st_Expected_Start'

# Use the real module paths so cmp also checks imports, exports and every ID.
j=tools/flowc/backends/java/parser
mkdir -p "$j"
cp "$root/$j/java.lingo" "$j/"
# Exercise tab-only and mixed horizontal whitespace lines with both line endings.
for eol in lf crlf; do
	awk -v eol="$eol" 'BEGIN { end = (eol == "crlf" ? "\r\n" : "\n"); printf "\t%s \t %s", end, end }
		{ sub(/\r$/, ""); printf "%s%s", $0, end }' "$root/$j/java.lingo.mnemonics" > "$j/java.lingo.mnemonics"
	generate "file=$j/java.lingo" "flowparser=$j/java_parser" "flowparserast=$j/java_ast.flow"
	for f in java_parser.flow java_ast.flow java_ast_mnemonics.flow; do
		cmp "$j/$f" "$root/$j/$f"
	done
done

cat > consumer.flow <<'FLOW'
import tiny_parser;
import tiny_ast;
import lingo/compiler/compile_lingo;
import tools/flowc/backends/java/parser/java_parser;
import tools/flowc/backends/java/parser/java_ast;

// Exercise the public compiler without the CLI reader or an AST output path.
checkDirectCompiler() -> bool {
	r = compileSyntaxWithGrammar("direct.lingo", "Start = !Stop !Reserved; Stop = 'b'; Reserved = 'c';",
		[CswgoLegacyMnemonics("old", [Pair("Stop", -7), Pair("Reserved", -7)])]);
	if (r.second == "" && strContains(r.first, "Duplicate legacy mnemonic ID: -7")) true else {
		println("Direct compiler did not reject duplicate ID -7: " + r.first);
		false;
	}
}

main() {
	stop = parse_Start("b").first;
	start = parse_Start("a").first;
	if (stop.choice != -1 || stop.rule != st_DidNotExpectStart_Stop || stop.rule != 5 || start.rule != st_Start || start.end != 1) {
		println("Incorrect rule or negation ID in generated Start parser");
		quit(1);
	} else {
		s = "package p; class A {}";
		r = parse_Compilation(s).first;
		u = get_Compilation_CompilationUnit(r);
		ok = r.rule == st_Compilation && r.end == strlen(s) && u.rule == st_CompilationUnit
			&& st_DidNotExpectflow_LetterOrDigit == 17 && st_DidNotExpectCompilation_LetterOrDigit == -1
			&& st_DidNotExpectCompilation_Keyword == -5 && st_DidNotExpectCompilation_COMMA == -12;
		if (!ok) println("Java parser/AST mnemonic contract changed");
		quit(if (ok && checkDirectCompiler()) 0 else 1);
	}
}
FLOW
"$root/bin/flowc1" server=0 incremental=0 "I=$tmp" bytecode=consumer.bytecode consumer.flow
"$root/bin/flowcpp" --batch consumer.bytecode
