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

printf '%s\n' 'old' 'Start=-1' 'Stop=-1' > tiny.lingo.mnemonics
if generate file=tiny.lingo flowparser=duplicate_parser flowparserast=duplicate_ast.flow > duplicate.log 2>&1; then
	echo 'Two rules with the same negative ID were accepted' >&2
	exit 1
fi
grep -F 'Invalid mnemonic table tiny.lingo.mnemonics' duplicate.log > /dev/null

# Use the real module paths so cmp also checks imports, exports and every ID.
j=tools/flowc/backends/java/parser
mkdir -p "$j"
cp "$root/$j/java.lingo" "$j/"
# Repeat the generation with a CRLF copy of the published table next to its grammar.
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$root/$j/java.lingo.mnemonics" > "$j/java.lingo.mnemonics"
for grammar in "$root/$j/java.lingo" "$j/java.lingo"; do
	generate "file=$grammar" "flowparser=$j/java_parser" "flowparserast=$j/java_ast.flow"
	for f in java_parser.flow java_ast.flow java_ast_mnemonics.flow; do
		cmp "$j/$f" "$root/$j/$f"
	done
done

cat > consumer.flow <<'FLOW'
import tiny_parser;
import tiny_ast;
import tools/flowc/backends/java/parser/java_parser;
import tools/flowc/backends/java/parser/java_ast;

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
		quit(if (ok) 0 else 1);
	}
}
FLOW
"$root/bin/flowc1" server=0 incremental=0 "I=$tmp" bytecode=consumer.bytecode consumer.flow
"$root/bin/flowcpp" --batch consumer.bytecode
