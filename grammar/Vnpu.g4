/**
 * vNPU Grammar - ANTLR4
 * 
 * A minimal core language for membrane-bound neural substrate (vNPU).
 * Defines: devices, tensors, kernels, graphs, isolates, and policies.
 *
 * NOTE: This grammar is the reference specification.  The canonical
 * implementation is the lex/yacc parser in src/parser/vnpu.l + vnpu.y.
 * Keep both in sync; run `make grammar-check` from src/parser to verify.
 */
grammar Vnpu;

program : 'vnpu' version ';' decl* EOF ;

/*
 * Version: the implementation tokenises the version string (e.g. "v1") as a
 * plain identifier, so we accept any ID here to stay in sync.
 */
version : ID ;

decl
  : deviceDecl
  | tensorDecl
  | kernelDecl
  | graphDecl
  | isolateDecl
  | policyDecl
  ;

deviceDecl : 'device' ID '{' devProp* '}' ;
devProp    : ID '=' literal ';' ;

tensorDecl : 'tensor' ID ':' dtype shape (location)? ';' ;
dtype      : 'f16' | 'f32' | 'i8' | 'i16' | 'i32' | 'i64' | 'u8' | 'bf16' ;
shape      : '[' dim (',' dim)* ']' ;
dim        : INT | ID ; // allow symbolic dims

location   : '@' ID ;

kernelDecl : 'kernel' ID '=' call '->' ID ';' ;
call       : qualID '(' (arg (',' arg)*)? ')' ;
arg        : ID | literal ;
qualID     : ID ('.' ID)+ ;

graphDecl  : 'graph' ID '{' graphStmt* '}' ;
graphStmt  : ID ';' ; // kernel id reference

isolateDecl : 'isolate' ID '{' isoProp* '}' ;
isoProp
  : 'membrane' '=' membrane ';'
  | 'entry' ID ';'
  | 'ports' '{' portDecl* '}'
  ;

portDecl : ID ':' portType ';' ;
portType : 'Intent' | 'Evidence' | 'Tensor' | 'Bytes' ;

policyDecl : 'policy' ID '{' polStmt* '}' ;
polStmt
  : 'membrane' membrane ('allows' | 'denies') ID ('when' expr)? ';'
  ;

membrane : 'inner' | 'trans' | 'outer' ;

/*
 * Expressions in policy conditions.  qualID is included so that dotted
 * references such as "budget.tokens" and "echo.complete" are accepted,
 * matching the lex/yacc implementation.
 */
expr
  : expr 'and' expr
  | expr 'or'  expr
  | qualID compOp literal
  | ID    compOp literal
  | '(' expr ')'
  ;

compOp : '>=' | '<=' | '>' | '<' | '==' | '!=' ;

literal : INT | FLOAT | STRING | BOOL ;

ID      : [a-zA-Z_][a-zA-Z0-9_]* ;
INT     : [0-9]+ ;
FLOAT   : [0-9]+ '.' [0-9]+ ;
STRING  : '"' (~["\\] | '\\' .)* '"' ;
BOOL    : 'true' | 'false' ;

WS      : [ \t\r\n]+ -> skip ;
COMMENT : '//' ~[\r\n]* -> skip ;
