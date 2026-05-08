/**
 * sema.c - vNPU Semantic Analysis
 *
 * Two-pass analysis:
 *   Pass 1 - collect all top-level symbol declarations into the symbol table.
 *   Pass 2 - validate cross-references between declarations.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"
#include "sema.h"

/* ---- Symbol table ---- */

typedef enum {
    SYM_DEVICE,
    SYM_TENSOR,
    SYM_KERNEL,
    SYM_GRAPH,
    SYM_ISOLATE,
    SYM_POLICY
} SymKind;

static const char * const kind_names[] = {
    "device", "tensor", "kernel", "graph", "isolate", "policy"
};

#define MAX_SYMS 256

typedef struct {
    const char *name;
    SymKind     kind;
} SymEntry;

static SymEntry syms[MAX_SYMS];
static int      nsyms  = 0;
static int      errors = 0;

static void sema_error(const char *msg, const char *name) {
    fprintf(stderr, "semantic error: %s: '%s'\n", msg, name ? name : "(null)");
    errors++;
}

/* Returns index of matching symbol, or -1 if not found. */
static int find_sym(const char *name, SymKind kind) {
    for (int i = 0; i < nsyms; i++)
        if (syms[i].kind == kind && strcmp(syms[i].name, name) == 0)
            return i;
    return -1;
}

static void define_sym(const char *name, SymKind kind) {
    if (!name) return;
    if (find_sym(name, kind) >= 0) {
        char msg[64];
        snprintf(msg, sizeof(msg), "duplicate %s declaration", kind_names[kind]);
        sema_error(msg, name);
        return;
    }
    if (nsyms >= MAX_SYMS) {
        fprintf(stderr, "semantic error: symbol table full\n");
        errors++;
        return;
    }
    syms[nsyms].name = name;
    syms[nsyms].kind = kind;
    nsyms++;
}

/* ---- Pass 1: collect declarations ---- */

static void collect_decls(AstNode *node) {
    for (; node; node = node->next) {
        switch (node->type) {
            case AST_DEVICE:  define_sym(node->name, SYM_DEVICE);  break;
            case AST_TENSOR:  define_sym(node->name, SYM_TENSOR);  break;
            case AST_KERNEL:  define_sym(node->name, SYM_KERNEL);  break;
            case AST_GRAPH:   define_sym(node->name, SYM_GRAPH);   break;
            case AST_ISOLATE: define_sym(node->name, SYM_ISOLATE); break;
            case AST_POLICY:  define_sym(node->name, SYM_POLICY);  break;
            default: break;
        }
    }
}

/* ---- Pass 2: check cross-references ---- */

static void check_tensor(AstNode *node) {
    /* @device location must name a declared device */
    if (node->right && node->right->name) {
        if (find_sym(node->right->name, SYM_DEVICE) < 0)
            sema_error("undefined device in tensor location", node->right->name);
    }
}

static void check_kernel(AstNode *node) {
    /* output tensor must be declared */
    if (node->right && node->right->name) {
        if (find_sym(node->right->name, SYM_TENSOR) < 0)
            sema_error("undefined output tensor in kernel", node->right->name);
    }
    /* argument identifiers must reference declared tensors */
    if (node->left && node->left->type == AST_CALL) {
        for (AstNode *arg = node->left->right; arg; arg = arg->next) {
            if (arg->type == AST_EXPR && arg->name) {
                if (find_sym(arg->name, SYM_TENSOR) < 0)
                    sema_error("undefined tensor argument in kernel", arg->name);
            }
        }
    }
}

static void check_graph(AstNode *node) {
    /* every statement must name a declared kernel */
    for (AstNode *stmt = node->child; stmt; stmt = stmt->next) {
        if (stmt->name && find_sym(stmt->name, SYM_KERNEL) < 0)
            sema_error("undefined kernel referenced in graph", stmt->name);
    }
}

static void check_isolate(AstNode *node) {
    /* entry graph must be declared */
    for (AstNode *prop = node->child; prop; prop = prop->next) {
        if (prop->type == AST_EXPR &&
            prop->name && strcmp(prop->name, "entry") == 0) {
            if (prop->child && prop->child->name) {
                if (find_sym(prop->child->name, SYM_GRAPH) < 0)
                    sema_error("undefined entry graph in isolate",
                               prop->child->name);
            }
        }
    }
}

static void check_refs(AstNode *node) {
    for (; node; node = node->next) {
        switch (node->type) {
            case AST_TENSOR:  check_tensor(node);  break;
            case AST_KERNEL:  check_kernel(node);  break;
            case AST_GRAPH:   check_graph(node);   break;
            case AST_ISOLATE: check_isolate(node); break;
            default: break;
        }
    }
}

/* ---- Public entry point ---- */

int sema_check(AstNode *root) {
    if (!root || root->type != AST_PROGRAM)
        return 1;

    nsyms  = 0;
    errors = 0;

    collect_decls(root->child);
    check_refs(root->child);

    if (errors == 0)
        printf("Semantic analysis: OK (%d symbols)\n", nsyms);
    else
        fprintf(stderr, "Semantic analysis: %d error(s)\n", errors);

    return errors;
}
