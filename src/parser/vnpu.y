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
    AST_POLICY_STMT,
    AST_MEMBRANE,
    AST_PORT,
    AST_EXPR,
    AST_LITERAL,
    AST_CALL,
    AST_LIST,
    AST_PROP
} AstNodeType;

typedef struct AstNode {
    AstNodeType type;
    char *name;
    char *value;           /* for literals, operators, etc */
    int ival;              /* for integer values */
    double fval;           /* for float values */
    struct AstNode *left;
    struct AstNode *right;
    struct AstNode *next;  /* for lists */
    struct AstNode *child; /* for nested structures */
} AstNode;

AstNode *ast_root = NULL;

AstNode *make_node(AstNodeType type, const char *name) {
    AstNode *n = (AstNode *)malloc(sizeof(AstNode));
    n->type = type;
    n->name = name ? strdup(name) : NULL;
    n->value = NULL;
    n->ival = 0;
    n->fval = 0.0;
    n->left = n->right = n->next = n->child = NULL;
    return n;
}

AstNode *make_literal_int(int val) {
    AstNode *n = make_node(AST_LITERAL, NULL);
    n->ival = val;
    return n;
}

AstNode *make_literal_float(double val) {
    AstNode *n = make_node(AST_LITERAL, NULL);
    n->fval = val;
    return n;
}

AstNode *make_literal_str(const char *val) {
    AstNode *n = make_node(AST_LITERAL, NULL);
    n->value = strdup(val);
    return n;
}

void append_node(AstNode *list, AstNode *item) {
    if (!list || !item) return;
    AstNode *curr = list;
    while (curr->next) curr = curr->next;
    curr->next = item;
}

void print_ast_helper(AstNode *n, int indent, const char *label) {
    if (!n) return;
    for (int i = 0; i < indent; i++) printf("  ");
    
    switch (n->type) {
        case AST_PROGRAM: 
            printf("PROGRAM\n");
            if (n->child) print_ast_helper(n->child, indent + 1, NULL);
            return;
        case AST_DEVICE: 
            printf("Device '%s'", n->name ? n->name : "?");
            if (n->child) {
                printf(" {");
                AstNode *prop = n->child;
                while (prop) {
                    printf(" %s=", prop->name ? prop->name : "?");
                    if (prop->child && prop->child->type == AST_LITERAL) {
                        if (prop->child->value) printf("%s", prop->child->value);
                        else if (prop->child->fval != 0.0) printf("%g", prop->child->fval);
                        else printf("%d", prop->child->ival);
                    } else if (prop->child && prop->child->name) {
                        printf("%s", prop->child->name);
                    }
                    prop = prop->next;
                    if (prop) printf(",");
                }
                printf(" }");
            }
            printf("\n");
            if (n->next) print_ast_helper(n->next, indent, NULL);
            return;
        case AST_TENSOR: 
            printf("Tensor '%s' : %s[", n->name ? n->name : "?", n->value ? n->value : "?");
            if (n->left) {
                AstNode *dim = n->left;
                while (dim) {
                    if (dim->type == AST_LITERAL) printf("%d", dim->ival);
                    else if (dim->name) printf("%s", dim->name);
                    dim = dim->next;
                    if (dim) printf(",");
                }
            }
            printf("]");
            if (n->right && n->right->name) printf(" @%s", n->right->name);
            printf("\n");
            if (n->next) print_ast_helper(n->next, indent, NULL);
            return;
        case AST_KERNEL: 
            printf("Kernel '%s'", n->name ? n->name : "?");
            if (n->left && n->left->type == AST_CALL) {
                printf(" = ");
                // Print qualified name
                if (n->left->left) {
                    AstNode *qn = n->left->left;
                    if (qn->left && qn->left->name) printf("%s", qn->left->name);
                    if (qn->right && qn->right->name) printf(".%s", qn->right->name);
                    // Print additional parts
                    if (qn->next) {
                        AstNode *p = qn->next;
                        while (p) {
                            if (p->name) printf(".%s", p->name);
                            p = p->next;
                        }
                    }
                }
                printf("(");
                // Print arguments
                if (n->left->right) {
                    AstNode *arg = n->left->right;
                    while (arg) {
                        if (arg->name) printf("%s", arg->name);
                        else if (arg->type == AST_LITERAL) {
                            if (arg->value) printf("%s", arg->value);
                            else printf("%d", arg->ival);
                        }
                        arg = arg->next;
                        if (arg) printf(", ");
                    }
                }
                printf(")");
            }
            if (n->right && n->right->name) printf(" -> %s", n->right->name);
            printf("\n");
            if (n->next) print_ast_helper(n->next, indent, NULL);
            return;
        case AST_GRAPH: 
            printf("Graph '%s' {", n->name ? n->name : "?");
            if (n->child) {
                AstNode *stmt = n->child;
                while (stmt) {
                    printf(" %s;", stmt->name ? stmt->name : "?");
                    stmt = stmt->next;
                }
            }
            printf(" }\n");
            if (n->next) print_ast_helper(n->next, indent, NULL);
            return;
        case AST_ISOLATE: 
            printf("Isolate '%s'\n", n->name ? n->name : "?");
            if (n->child) print_ast_helper(n->child, indent + 1, NULL);
            if (n->next) print_ast_helper(n->next, indent, NULL);
            return;
        case AST_POLICY: 
            printf("Policy '%s'\n", n->name ? n->name : "?");
            if (n->child) print_ast_helper(n->child, indent + 1, NULL);
            if (n->next) print_ast_helper(n->next, indent, NULL);
            return;
        case AST_POLICY_STMT: 
            printf("membrane ");
            if (n->left && n->left->name) printf("%s ", n->left->name);
            if (n->right) {
                if (n->right->value) printf("%s ", n->right->value);
                else if (n->right->name) printf("%s ", n->right->name);
            }
            if (n->child && n->child->name) printf("%s", n->child->name);
            if (n->child && n->child->next) {
                printf(" when ");
                print_expr(n->child->next);
            }
            printf("\n");
            if (n->next) print_ast_helper(n->next, indent, NULL);
            return;
        case AST_MEMBRANE: 
            if (n->child && n->child->name) 
                printf("membrane = %s\n", n->child->name);
            else 
                printf("membrane\n");
            if (n->next) print_ast_helper(n->next, indent, NULL);
            return;
        case AST_PORT: 
            printf("port %s: ", n->name ? n->name : "?");
            if (n->child && n->child->name) printf("%s", n->child->name);
            printf("\n");
            if (n->next) print_ast_helper(n->next, indent, NULL);
            return;
        case AST_EXPR: 
            if (n->name && strcmp(n->name, "entry") == 0) {
                printf("entry ");
                if (n->child && n->child->name) printf("%s", n->child->name);
                printf("\n");
                if (n->next) print_ast_helper(n->next, indent, NULL);
                return;
            }
            // Generic expression - should not appear at top level
            if (n->next) print_ast_helper(n->next, indent, NULL);
            return;
        case AST_LITERAL: 
            if (n->value) printf("LITERAL: %s\n", n->value);
            else if (n->fval != 0.0) printf("LITERAL: %g\n", n->fval);
            else printf("LITERAL: %d\n", n->ival);
            break;
        case AST_CALL: 
            printf("CALL\n"); 
            break;
        case AST_LIST: 
            printf("ports {\n");
            if (n->child) print_ast_helper(n->child, indent + 1, NULL);
            for (int i = 0; i < indent; i++) printf("  ");
            printf("}\n");
            if (n->next) print_ast_helper(n->next, indent, NULL);
            return;
        case AST_PROP: 
            printf("PROP: %s = %s\n", n->name, n->value); 
            break;
        default: 
            printf("UNKNOWN\n"); 
            break;
    }
    
    if (n->next) print_ast_helper(n->next, indent, NULL);
}

void print_expr(AstNode *n) {
    if (!n) {
        printf("<null>");
        return;
    }
    if (n->type == AST_LITERAL) {
        if (n->value) printf("%s", n->value);
        else if (n->fval != 0.0) printf("%g", n->fval);
        else printf("%d", n->ival);
    } else if (n->value) {
        // Operators stored in value field
        if (strcmp(n->value, "and") == 0 || strcmp(n->value, "or") == 0) {
            if (n->left && n->right) {
                printf("(");
                print_expr(n->left);
                printf(" %s ", n->value);
                print_expr(n->right);
                printf(")");
            } else {
                printf("%s[no-children]", n->value);
            }
        } else if (n->left && n->right) {
            // Binary comparison operator
            print_expr(n->left);
            printf("%s", n->value);
            print_expr(n->right);
        } else {
            printf("%s[no-children]", n->value);
        }
    } else if (n->name) {
        // Simple identifier
        printf("%s", n->name);
    } else if (n->left && n->right) {
        // Dotted identifier (qualid) - no name or value, just structure
        print_expr(n->left);
        printf(".");
        print_expr(n->right);
        if (n->next) {
            printf(".");
            print_expr(n->next);
        }
    } else {
        printf("<unknown>");
    }
}

void print_ast(AstNode *n, int indent) {
    print_ast_helper(n, indent, NULL);
}

void free_ast(AstNode *n) {
    if (!n) return;
    free_ast(n->left);
    free_ast(n->right);
    free_ast(n->next);
    free_ast(n->child);
    if (n->name) free(n->name);
    if (n->value) free(n->value);
    free(n);
}
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
        free_ast(ast_root);
    }
    return result;
}
