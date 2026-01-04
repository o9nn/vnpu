/**
 * vNPU Grammar - ANTLR4
 * 
 * A minimal core language for membrane-bound neural substrate (vNPU).
 * Defines: devices, tensors, kernels, graphs, isolates, and policies.
 */
grammar Vnpu;

program : 'vnpu' VERSION ';' decl* EOF ;

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

expr
  : expr 'and' expr
  | expr 'or'  expr
  | ID compOp literal
  | '(' expr ')'
  ;

compOp : '>=' | '<=' | '>' | '<' | '==' | '!=' ;

literal : INT | FLOAT | STRING | BOOL ;

VERSION : 'v' INT ('.' INT)* ;

ID      : [a-zA-Z_][a-zA-Z0-9_]* ;
INT     : [0-9]+ ;
FLOAT   : [0-9]+ '.' [0-9]+ ;
STRING  : '"' (~["\\] | '\\' .)* '"' ;
BOOL    : 'true' | 'false' ;

WS      : [ \t\r\n]+ -> skip ;
COMMENT : '//' ~[\r\n]* -> skip ;
