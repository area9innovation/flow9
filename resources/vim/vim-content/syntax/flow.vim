" Vim syntax file
" Language: Flow
" Maintainer: Anton Kozlov
" Last Change:  2014 Nov 26 - Initial implementation derived from haskell,
" ocaml, and example: http://vim.wikia.com/wiki/Creating_your_own_syntax_files

if exists("b:current_syntax") && b:current_syntax == "flow"
  finish
endif

syn keyword flowBoolean true false
syn keyword flowKeyword if else switch default native import export unittest

syn keyword flowType bool double int void string io ref flow
syn match flowGenType '?\+'

syn match flowOperator "+\|*\|-\|!\|%\|:\|/\|:=\|==\|=\|'\|\\\|!=\|<=\|>=\|<\|>\|&&\|||\|::=\||>\|->\|\.\|\^"

syn case ignore
syn match	flowNumber		"\<\d\+\>"
"hex
syn match	flowNumber		"\<0x\x\+\>"
"floating point number, with dot, optional exponent
syn match	flowFloat		"\<\d\+\.\d*\(e[-+]\=\d\+\)\=\>"
"floating point number, without dot, with exponent
syn match	flowFloat		"\<\d\+e[-+]\=\d\+\>"
syn case match

syn region flowString start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=@Spell

syn keyword flowTodo contained TODO FIXME XXX NOTE
syn match flowComment "\/\/.*$" contains=flowTodo
syn region flowComment start="/\*" end="\*/" contains=flowTodo

syn match flowDelimeter ";"
syn region flowList transparent matchgroup=flowDelimeter start="\[" end="\]" 
syn region flowBlock fold transparent matchgroup=flowDelimeter start="{" end="}" 


let b:current_syntax = "flow"
hi def link flowKeyword	Keyword
hi def link flowGenType	flowType
hi def link flowType	Type
hi def link flowNumber	Number
hi def link flowFloat	Number
hi def link flowList	Keyword
hi def link flowString	String
hi def link flowComment	Comment
hi def link flowDelimeter	Delimiter
hi def link flowOperator Operator



