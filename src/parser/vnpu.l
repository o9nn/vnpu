/**
 * vNPU Lexer - Lex/Flex
 * 
 * Minimal lexer for Plan9/Inferno C toolchain.
 */
%{
#include "vnpu.tab.h"
#include <string.h>
%}

%%
"vnpu"          return VNPU;
"device"        return DEVICE;
"tensor"        return TENSOR;
"kernel"        return KERNEL;
"graph"         return GRAPH;
"isolate"       return ISOLATE;
"policy"        return POLICY;
"membrane"      return MEMBRANE;
"inner"         return INNER;
"trans"         return TRANS;
"outer"         return OUTER;
"entry"         return ENTRY;
"ports"         return PORTS;
"allows"        return ALLOWS;
"denies"        return DENIES;
"when"          return WHEN;
"and"           return AND;
"or"            return OR;
"@"             return AT;

"Intent"        return INTENT;
"Evidence"      return EVIDENCE;
"Tensor"        return TENSORTYPE;
"Bytes"         return BYTES;

"f16"|"f32"|"i8"|"i16"|"i32"|"i64"|"u8"|"bf16"  { yylval.s=strdup(yytext); return DTYPE; }

"->"            return ARROW;
"=="|"!="|">="|"<="|">"|"<" { yylval.s=strdup(yytext); return COP; }

\"([^\"\\]|\\.)*\" { yylval.s=strdup(yytext); return STRING; }

[0-9]+"."[0-9]+ { yylval.f=atof(yytext); return FLOAT; }
[0-9]+          { yylval.i=atoi(yytext); return INT; }

"true"|"false"  { yylval.i=(strcmp(yytext,"true")==0); return BOOL; }

[a-zA-Z_][a-zA-Z0-9_]* { yylval.s=strdup(yytext); return ID; }

"//".*          /* skip comment */;
[ \t\r\n]+      /* skip ws */;

.               return yytext[0];
%%

int yywrap(void) {
    return 1;
}
