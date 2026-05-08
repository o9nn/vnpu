/**
 * ast.c - vNPU AST construction, printing, and cleanup
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"

AstNode *ast_root = NULL;

/* ---- Construction ---- */

AstNode *make_node(AstNodeType type, const char *name) {
    AstNode *n = (AstNode *)malloc(sizeof(AstNode));
    n->type  = type;
    n->name  = name ? strdup(name) : NULL;
    n->value = NULL;
    n->ival  = 0;
    n->fval  = 0.0;
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

/* ---- Printing ---- */

static void print_literal_value(AstNode *n) {
    if (n->value)            printf("%s", n->value);
    else if (n->fval != 0.0) printf("%g", n->fval);
    else                     printf("%d", n->ival);
}

void print_expr(AstNode *n) {
    if (!n) {
        printf("<null>");
        return;
    }
    if (n->type == AST_LITERAL) {
        print_literal_value(n);
    } else if (n->value) {
        /* Operators stored in value field */
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
            /* Binary comparison operator */
            print_expr(n->left);
            printf("%s", n->value);
            print_expr(n->right);
        } else {
            printf("%s[no-children]", n->value);
        }
    } else if (n->name) {
        printf("%s", n->name);
    } else if (n->left && n->right) {
        /* Dotted identifier (qualid) */
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

static void print_ast_helper(AstNode *n, int indent) {
    if (!n) return;
    for (int i = 0; i < indent; i++) printf("  ");

    switch (n->type) {
        case AST_PROGRAM:
            printf("PROGRAM\n");
            if (n->child) print_ast_helper(n->child, indent + 1);
            return;
        case AST_DEVICE:
            printf("Device '%s'", n->name ? n->name : "?");
            if (n->child) {
                printf(" {");
                AstNode *prop = n->child;
                while (prop) {
                    printf(" %s=", prop->name ? prop->name : "?");
                    if (prop->child && prop->child->type == AST_LITERAL) {
                        print_literal_value(prop->child);
                    } else if (prop->child && prop->child->name) {
                        printf("%s", prop->child->name);
                    }
                    prop = prop->next;
                    if (prop) printf(",");
                }
                printf(" }");
            }
            printf("\n");
            if (n->next) print_ast_helper(n->next, indent);
            return;
        case AST_TENSOR:
            printf("Tensor '%s' : %s[", n->name ? n->name : "?",
                   n->value ? n->value : "?");
            if (n->left) {
                AstNode *dim = n->left;
                while (dim) {
                    if (dim->type == AST_LITERAL) printf("%d", dim->ival);
                    else if (dim->name)            printf("%s", dim->name);
                    dim = dim->next;
                    if (dim) printf(",");
                }
            }
            printf("]");
            if (n->right && n->right->name) printf(" @%s", n->right->name);
            printf("\n");
            if (n->next) print_ast_helper(n->next, indent);
            return;
        case AST_KERNEL:
            printf("Kernel '%s'", n->name ? n->name : "?");
            if (n->left && n->left->type == AST_CALL) {
                printf(" = ");
                if (n->left->left) {
                    AstNode *qn = n->left->left;
                    if (qn->left && qn->left->name)  printf("%s", qn->left->name);
                    if (qn->right && qn->right->name) printf(".%s", qn->right->name);
                    AstNode *p = qn->next;
                    while (p) {
                        if (p->name) printf(".%s", p->name);
                        p = p->next;
                    }
                }
                printf("(");
                if (n->left->right) {
                    AstNode *arg = n->left->right;
                    while (arg) {
                        if (arg->name) printf("%s", arg->name);
                        else if (arg->type == AST_LITERAL) {
                            if (arg->value) printf("%s", arg->value);
                            else            printf("%d", arg->ival);
                        }
                        arg = arg->next;
                        if (arg) printf(", ");
                    }
                }
                printf(")");
            }
            if (n->right && n->right->name) printf(" -> %s", n->right->name);
            printf("\n");
            if (n->next) print_ast_helper(n->next, indent);
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
            if (n->next) print_ast_helper(n->next, indent);
            return;
        case AST_ISOLATE:
            printf("Isolate '%s'\n", n->name ? n->name : "?");
            if (n->child) print_ast_helper(n->child, indent + 1);
            if (n->next)  print_ast_helper(n->next, indent);
            return;
        case AST_POLICY:
            printf("Policy '%s'\n", n->name ? n->name : "?");
            if (n->child) print_ast_helper(n->child, indent + 1);
            if (n->next)  print_ast_helper(n->next, indent);
            return;
        case AST_POLICY_STMT:
            printf("membrane ");
            if (n->left && n->left->name)   printf("%s ", n->left->name);
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
            if (n->next) print_ast_helper(n->next, indent);
            return;
        case AST_MEMBRANE:
            if (n->child && n->child->name)
                printf("membrane = %s\n", n->child->name);
            else
                printf("membrane\n");
            if (n->next) print_ast_helper(n->next, indent);
            return;
        case AST_PORT:
            printf("port %s: ", n->name ? n->name : "?");
            if (n->child && n->child->name) printf("%s", n->child->name);
            printf("\n");
            if (n->next) print_ast_helper(n->next, indent);
            return;
        case AST_EXPR:
            if (n->name && strcmp(n->name, "entry") == 0) {
                printf("entry ");
                if (n->child && n->child->name) printf("%s", n->child->name);
                printf("\n");
                if (n->next) print_ast_helper(n->next, indent);
                return;
            }
            if (n->next) print_ast_helper(n->next, indent);
            return;
        case AST_LITERAL:
            printf("LITERAL: ");
            print_literal_value(n);
            printf("\n");
            break;
        case AST_CALL:
            printf("CALL\n");
            break;
        case AST_LIST:
            printf("ports {\n");
            if (n->child) print_ast_helper(n->child, indent + 1);
            for (int i = 0; i < indent; i++) printf("  ");
            printf("}\n");
            if (n->next) print_ast_helper(n->next, indent);
            return;
        case AST_PROP:
            printf("PROP: %s = %s\n", n->name, n->value);
            break;
        default:
            printf("UNKNOWN\n");
            break;
    }

    if (n->next) print_ast_helper(n->next, indent);
}

void print_ast(AstNode *n, int indent) {
    print_ast_helper(n, indent);
}

/* ---- Cleanup ---- */

void free_ast(AstNode *n) {
    if (!n) return;
    free_ast(n->left);
    free_ast(n->right);
    free_ast(n->next);
    free_ast(n->child);
    if (n->name)  free(n->name);
    if (n->value) free(n->value);
    free(n);
}
