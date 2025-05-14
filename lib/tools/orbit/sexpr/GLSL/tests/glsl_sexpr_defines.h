#ifndef GLSL_SEXPR_DEFINES_H
#define GLSL_SEXPR_DEFINES_H

// Type tags for AST nodes
#define TAG_SSINT 1
#define TAG_SSDOUBLE 2
#define TAG_SSBOOL 3
#define TAG_SSSTRING 4
#define TAG_SSVARIABLE 5
#define TAG_SSCONSTRUCTOR 6
#define TAG_SSOPERATOR 7
#define TAG_SSLIST 8
#define TAG_SSVECTOR 9
#define TAG_SSSPECIALFORM 10
#define TAG_SSBUILTINOP 11
#define TAG_CLOSURE 20
#define TAG_ERROR 21
#define TAG_NOP 0

// Built-in operator types - used with TAG_SSBUILTINOP
#define OP_ADD 1
#define OP_SUB 2
#define OP_MUL 3
#define OP_DIV 4
#define OP_EQ 5
#define OP_LT 6
#define OP_GT 7
#define OP_MOD 8

// Special form IDs
#define SFORM_AND 1
#define SFORM_BEGIN 2
#define SFORM_CLOSURE 3
#define SFORM_DEFINE 4
#define SFORM_EVAL 5
#define SFORM_IF 6
#define SFORM_IMPORT 7
#define SFORM_LAMBDA 8
#define SFORM_LET 9
#define SFORM_LETREC 10
#define SFORM_LIST 11
#define SFORM_MATCH 12
#define SFORM_OR 13
#define SFORM_QUASIQUOTE 14
#define SFORM_QUOTE 15
#define SFORM_SET 16
#define SFORM_UNQUOTE 17
#define SFORM_UNQUOTESPLICING 18

#endif // GLSL_SEXPR_DEFINES_H