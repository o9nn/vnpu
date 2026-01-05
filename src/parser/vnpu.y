/**
 * vNPU Parser - Yacc/Bison
 *
 * Minimal parser for Plan9/Inferno C toolchain.
 */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void yyerror(const char *s);
int yylex(void);

/* AST Node Types */
typedef enum {
    AST_PROGRAM,
    AST_DEVICE,
    AST_TENSOR,
    AST_KERNEL,
    AST_GRAPH,
    AST_ISOLATE,
    AST_POLICY,
    AST_MEMBRANE,
    AST_PORT,
    AST_EXPR
} AstNodeType;

typedef struct AstNode {
    AstNodeType type;
    char *name;
    struct AstNode *left;
    struct AstNode *right;
    struct AstNode *next;  /* for lists */
} AstNode;

AstNode *ast_root = NULL;

AstNode *make_node(AstNodeType type, const char *name) {
    AstNode *n = (AstNode *)malloc(sizeof(AstNode));
    n->type = type;
    n->name = name ? strdup(name) : NULL;
    n->left = n->right = n->next = NULL;
    return n;
}
%}

%union {
  int i;
  double f;
  char *s;
}

%token VNPU DEVICE TENSOR KERNEL GRAPH ISOLATE POLICY MEMBRANE ENTRY PORTS
%token INNER TRANS OUTER
%token ALLOWS DENIES WHEN AND OR
%token AT ARROW
%token INTENT EVIDENCE TENSORTYPE BYTES
%token <s> ID DTYPE STRING COP
%token <i> INT BOOL
%token <f> FLOAT

/* Precedence for expression operators (lowest to highest) */
%left OR
%left AND

%%

program : VNPU version ';' decls
        ;

version : ID /* accept v1 etc as ID for simplicity */
        ;

decls : /* empty */
      | decls decl
      ;

decl : device_decl
     | tensor_decl
     | kernel_decl
     | graph_decl
     | isolate_decl
     | policy_decl
     ;

device_decl : DEVICE ID '{' devprops '}' ;
devprops : /* empty */
         | devprops ID '=' literal ';'
         ;

tensor_decl : TENSOR ID ':' DTYPE shape optloc ';' ;
shape : '[' dims ']' ;
dims : dim
     | dims ',' dim
     ;
dim : INT
    | ID
    ;
optloc : /* empty */
       | AT ID
       ;

kernel_decl : KERNEL ID '=' call ARROW ID ';' ;
call : qualid '(' optargs ')' ;
qualid : ID '.' ID
       | qualid '.' ID
       ;
optargs : /* empty */
        | args
        ;
args : arg
     | args ',' arg
     ;
arg : ID
    | literal
    ;

graph_decl : GRAPH ID '{' graphstmts '}' ;
graphstmts : /* empty */
           | graphstmts ID ';'
           ;

isolate_decl : ISOLATE ID '{' isoprops '}' ;
isoprops : /* empty */
         | isoprops isoprop
         ;
isoprop : MEMBRANE '=' membrane ';'
        | ENTRY ID ';'
        | PORTS '{' portdecls '}'
        ;

portdecls : /* empty */
          | portdecls portdecl
          ;

portdecl : ID ':' porttype ';' ;
porttype : INTENT | EVIDENCE | TENSORTYPE | BYTES ;

membrane : INNER | TRANS | OUTER ;

policy_decl : POLICY ID '{' polstmts '}' ;
polstmts : /* empty */
         | polstmts polstmt
         ;

polstmt : MEMBRANE membrane action ID optcond ';' ;
action : ALLOWS | DENIES ;
optcond : /* empty */
        | WHEN expr
        ;

expr : expr AND expr
     | expr OR expr
     | ID COP literal
     | '(' expr ')'
     ;

literal : INT
        | FLOAT
        | STRING
        | BOOL
        ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "parse error: %s\n", s);
}

int main(int argc, char **argv) {
    return yyparse();
}
