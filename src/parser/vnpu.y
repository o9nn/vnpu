/**
 * vNPU Parser - Yacc/Bison
 *
 * Minimal parser for Plan9/Inferno C toolchain.
 */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"
#include "sema.h"
#include "codegen.h"

void yyerror(const char *s);
int yylex(void);
%}

%union {
  int i;
  double f;
  char *s;
  struct AstNode *node;
}

%token VNPU DEVICE TENSOR KERNEL GRAPH ISOLATE POLICY MEMBRANE ENTRY PORTS
%token INNER TRANS OUTER
%token ALLOWS DENIES WHEN AND OR
%token AT ARROW
%token INTENT EVIDENCE TENSORTYPE BYTES
%token <s> ID DTYPE STRING COP
%token <i> INT BOOL
%token <f> FLOAT

%type <node> program decls decl device_decl tensor_decl kernel_decl graph_decl isolate_decl policy_decl
%type <node> devprops literal call qualid optargs args arg
%type <node> shape dims dim optloc
%type <node> graphstmts isoprops isoprop portdecls portdecl porttype membrane
%type <node> polstmts polstmt action optcond expr
%type <s> version

/* Precedence for expression operators (lowest to highest) */
%left OR
%left AND

%%

program : VNPU version ';' decls
        { 
            ast_root = make_node(AST_PROGRAM, NULL);
            ast_root->child = $4;
            printf("Parse successful!\n");
        }
        ;

version : ID { $$ = $1; }
        ;

decls : /* empty */ { $$ = NULL; }
      | decls decl 
        { 
            if ($1) {
                append_node($1, $2);
                $$ = $1;
            } else {
                $$ = $2;
            }
        }
      ;

decl : device_decl { $$ = $1; }
     | tensor_decl { $$ = $1; }
     | kernel_decl { $$ = $1; }
     | graph_decl { $$ = $1; }
     | isolate_decl { $$ = $1; }
     | policy_decl { $$ = $1; }
     ;

device_decl : DEVICE ID '{' devprops '}' 
            { 
                $$ = make_node(AST_DEVICE, $2);
                $$->child = $4;
                free($2);
            }
            ;

devprops : /* empty */ { $$ = NULL; }
         | devprops ID '=' arg ';'
           { 
               AstNode *prop = make_node(AST_PROP, $2);
               prop->child = $4;
               if ($1) {
                   append_node($1, prop);
                   $$ = $1;
               } else {
                   $$ = prop;
               }
               free($2);
           }
         ;

tensor_decl : TENSOR ID ':' DTYPE shape optloc ';'
            { 
                $$ = make_node(AST_TENSOR, $2);
                $$->value = $4;
                $$->left = $5;
                $$->right = $6;
                free($2);
            }
            ;

shape : '[' dims ']' { $$ = $2; }
      ;

dims : dim { $$ = $1; }
     | dims ',' dim
       { 
           if ($1) {
               append_node($1, $3);
               $$ = $1;
           } else {
               $$ = $3;
           }
       }
     ;

dim : INT { $$ = make_literal_int($1); }
    | ID { $$ = make_node(AST_EXPR, $1); free($1); }
    ;

optloc : /* empty */ { $$ = NULL; }
       | AT ID { $$ = make_node(AST_EXPR, $2); free($2); }
       ;

kernel_decl : KERNEL ID '=' call ARROW ID ';'
            { 
                $$ = make_node(AST_KERNEL, $2);
                $$->left = $4;
                $$->right = make_node(AST_EXPR, $6);
                free($2);
                free($6);
            }
            ;

call : qualid '(' optargs ')'
     { 
         $$ = make_node(AST_CALL, NULL);
         $$->left = $1;
         $$->right = $3;
     }
     ;

qualid : ID '.' ID
       { 
           $$ = make_node(AST_EXPR, NULL);
           $$->left = make_node(AST_EXPR, $1);
           $$->right = make_node(AST_EXPR, $3);
           free($1);
           free($3);
       }
       | qualid '.' ID
       { 
           AstNode *newNode = make_node(AST_EXPR, $3);
           append_node($1, newNode);
           $$ = $1;
           free($3);
       }
       ;

optargs : /* empty */ { $$ = NULL; }
        | args { $$ = $1; }
        ;

args : arg { $$ = $1; }
     | args ',' arg
       { 
           if ($1) {
               append_node($1, $3);
               $$ = $1;
           } else {
               $$ = $3;
           }
       }
     ;

arg : ID { $$ = make_node(AST_EXPR, $1); free($1); }
    | literal { $$ = $1; }
    ;

graph_decl : GRAPH ID '{' graphstmts '}'
           { 
               $$ = make_node(AST_GRAPH, $2);
               $$->child = $4;
               free($2);
           }
           ;

graphstmts : /* empty */ { $$ = NULL; }
           | graphstmts ID ';'
             { 
                 AstNode *stmt = make_node(AST_EXPR, $2);
                 if ($1) {
                     append_node($1, stmt);
                     $$ = $1;
                 } else {
                     $$ = stmt;
                 }
                 free($2);
             }
           ;

isolate_decl : ISOLATE ID '{' isoprops '}'
             { 
                 $$ = make_node(AST_ISOLATE, $2);
                 $$->child = $4;
                 free($2);
             }
             ;

isoprops : /* empty */ { $$ = NULL; }
         | isoprops isoprop
           { 
               if ($1) {
                   append_node($1, $2);
                   $$ = $1;
               } else {
                   $$ = $2;
               }
           }
         ;

isoprop : MEMBRANE '=' membrane ';'
        { 
            $$ = make_node(AST_MEMBRANE, NULL);
            $$->child = $3;
        }
        | ENTRY ID ';'
        { 
            $$ = make_node(AST_EXPR, "entry");
            $$->child = make_node(AST_EXPR, $2);
            free($2);
        }
        | PORTS '{' portdecls '}'
        { 
            $$ = make_node(AST_LIST, "ports");
            $$->child = $3;
        }
        ;

portdecls : /* empty */ { $$ = NULL; }
          | portdecls portdecl
            { 
                if ($1) {
                    append_node($1, $2);
                    $$ = $1;
                } else {
                    $$ = $2;
                }
            }
          ;

portdecl : ID ':' porttype ';'
         { 
             $$ = make_node(AST_PORT, $1);
             $$->child = $3;
             free($1);
         }
         ;

porttype : INTENT { $$ = make_node(AST_EXPR, "Intent"); }
         | EVIDENCE { $$ = make_node(AST_EXPR, "Evidence"); }
         | TENSORTYPE { $$ = make_node(AST_EXPR, "Tensor"); }
         | BYTES { $$ = make_node(AST_EXPR, "Bytes"); }
         ;

membrane : INNER { $$ = make_node(AST_EXPR, "inner"); }
         | TRANS { $$ = make_node(AST_EXPR, "trans"); }
         | OUTER { $$ = make_node(AST_EXPR, "outer"); }
         ;

policy_decl : POLICY ID '{' polstmts '}'
            { 
                $$ = make_node(AST_POLICY, $2);
                $$->child = $4;
                free($2);
            }
            ;

polstmts : /* empty */ { $$ = NULL; }
         | polstmts polstmt
           { 
               if ($1) {
                   append_node($1, $2);
                   $$ = $1;
               } else {
                   $$ = $2;
               }
           }
         ;

polstmt : MEMBRANE membrane action ID optcond ';'
        { 
            $$ = make_node(AST_POLICY_STMT, NULL);
            $$->left = $2;
            $$->right = $3;
            $$->child = make_node(AST_EXPR, $4);
            if ($5) $$->child->next = $5;
            free($4);
        }
        ;

action : ALLOWS { $$ = make_node(AST_EXPR, "allows"); }
       | DENIES { $$ = make_node(AST_EXPR, "denies"); }
       ;

optcond : /* empty */ { $$ = NULL; }
        | WHEN expr { $$ = $2; }
        ;

expr : expr AND expr
     { 
         $$ = make_node(AST_EXPR, NULL);
         $$->value = strdup("and");
         $$->left = $1;
         $$->right = $3;
     }
     | expr OR expr
     { 
         $$ = make_node(AST_EXPR, NULL);
         $$->value = strdup("or");
         $$->left = $1;
         $$->right = $3;
     }
     | qualid COP literal
     { 
         $$ = make_node(AST_EXPR, NULL);
         $$->value = $2;  // $2 is already strdup'd from lexer
         $$->left = $1;
         $$->right = $3;
     }
     | ID COP literal
     { 
         $$ = make_node(AST_EXPR, NULL);
         $$->value = $2;  // $2 is already strdup'd from lexer
         $$->left = make_node(AST_EXPR, $1);
         $$->right = $3;
     }
     | '(' expr ')' { $$ = $2; }
     ;

literal : INT { $$ = make_literal_int($1); }
        | FLOAT { $$ = make_literal_float($1); }
        | STRING { $$ = make_literal_str($1); free($1); }
        | BOOL { $$ = make_literal_int($1); }
        ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "parse error: %s\n", s);
}

int main(int argc, char **argv) {
    int result = yyparse();
    if (result == 0 && ast_root) {
        printf("\n=== Abstract Syntax Tree ===\n");
        print_ast(ast_root, 0);

        printf("\n=== Semantic Analysis ===\n");
        int sema_errors = sema_check(ast_root);
        if (sema_errors == 0) {
            printf("\n=== Code Generation ===\n");
            const char *outfile = (argc > 1) ? argv[1] : "vnpu_out.h";
            codegen_emit(ast_root, outfile);
            printf("Generated: %s\n", outfile);
        } else {
            result = sema_errors;
        }

        free_ast(ast_root);
    }
    return result;
}
