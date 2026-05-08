/**
 * codegen.c - vNPU Code Generation
 *
 * Walks the AST and emits a self-contained C header with static descriptor
 * tables that can be embedded in a vNPU runtime.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"
#include "codegen.h"

/* ---- String helpers ---- */

/* Write a property value node to buf. */
static void prop_val_str(AstNode *val, char *buf, size_t bufsz) {
    if (!val) { buf[0] = '\0'; return; }
    if (val->type == AST_EXPR && val->name) {
        snprintf(buf, bufsz, "%s", val->name);
    } else if (val->type == AST_LITERAL) {
        if (val->value)          snprintf(buf, bufsz, "%s", val->value);
        else if (val->fval != 0.0) snprintf(buf, bufsz, "%g", val->fval);
        else                     snprintf(buf, bufsz, "%d", val->ival);
    } else {
        buf[0] = '\0';
    }
}

/* Serialise a qualid (namespace.op) node to buf. */
static void qualid_str(AstNode *q, char *buf, size_t bufsz) {
    if (!q) { buf[0] = '\0'; return; }
    if (q->left && q->left->name && q->right && q->right->name) {
        snprintf(buf, bufsz, "%s.%s", q->left->name, q->right->name);
        for (AstNode *p = q->next; p && p->name; p = p->next) {
            size_t len = strlen(buf);
            snprintf(buf + len, bufsz - len, ".%s", p->name);
        }
    } else if (q->name) {
        strncpy(buf, q->name, bufsz - 1);
        buf[bufsz - 1] = '\0';
    } else {
        buf[0] = '\0';
    }
}

/* Serialise a kernel argument list to buf as "arg1,arg2,..." */
static void args_str(AstNode *arg, char *buf, size_t bufsz) {
    buf[0] = '\0';
    for (; arg; arg = arg->next) {
        if (buf[0]) strncat(buf, ",", bufsz - strlen(buf) - 1);
        if (arg->type == AST_EXPR && arg->name) {
            strncat(buf, arg->name, bufsz - strlen(buf) - 1);
        } else if (arg->type == AST_LITERAL) {
            char tmp[64];
            if (arg->value)          snprintf(tmp, sizeof(tmp), "%s", arg->value);
            else if (arg->fval != 0.0) snprintf(tmp, sizeof(tmp), "%g", arg->fval);
            else                     snprintf(tmp, sizeof(tmp), "%d", arg->ival);
            strncat(buf, tmp, bufsz - strlen(buf) - 1);
        }
    }
}

/* Serialise an expression tree to buf (for policy conditions). */
static void expr_str(AstNode *n, char *buf, size_t bufsz) {
    if (!n || bufsz == 0) return;
    buf[0] = '\0';
    if (n->type == AST_LITERAL) {
        if (n->value)          snprintf(buf, bufsz, "%s", n->value);
        else if (n->fval != 0.0) snprintf(buf, bufsz, "%g", n->fval);
        else                   snprintf(buf, bufsz, "%d", n->ival);
    } else if (n->value) {
        char left[256] = {0}, right[256] = {0};
        if (n->left)  expr_str(n->left,  left,  sizeof(left));
        if (n->right) expr_str(n->right, right, sizeof(right));
        if (strcmp(n->value, "and") == 0 || strcmp(n->value, "or") == 0)
            snprintf(buf, bufsz, "(%s %s %s)", left, n->value, right);
        else
            snprintf(buf, bufsz, "%s%s%s", left, n->value, right);
    } else if (n->name) {
        snprintf(buf, bufsz, "%s", n->name);
    } else if (n->left && n->right) {
        /* qualid in expression */
        char left[128] = {0}, right[128] = {0};
        expr_str(n->left,  left,  sizeof(left));
        expr_str(n->right, right, sizeof(right));
        snprintf(buf, bufsz, "%s.%s", left, right);
        if (n->next) {
            char more[128] = {0};
            expr_str(n->next, more, sizeof(more));
            size_t len = strlen(buf);
            snprintf(buf + len, bufsz - len, ".%s", more);
        }
    }
}

/* Escape a string for use as a C string literal (handle backslash/quote). */
static void c_escape(const char *src, char *dst, size_t dstsz) {
    size_t j = 0;
    for (size_t i = 0; src[i]; i++) {
        if (src[i] == '"' || src[i] == '\\') {
            if (j + 2 >= dstsz) break;  /* need room for backslash + char + NUL */
            dst[j++] = '\\';
        } else {
            if (j + 1 >= dstsz) break;  /* need room for char + NUL */
        }
        dst[j++] = src[i];
    }
    dst[j] = '\0';
}

/* ---- Section emitters ---- */

static void emit_typedefs(FILE *f) {
    fprintf(f,
        "typedef struct { const char *name; const char *props; } VnpuDevice;\n"
        "\n"
        "typedef struct {\n"
        "    const char *name, *dtype, *device;\n"
        "    int dims[8]; int ndims;\n"
        "} VnpuTensor;\n"
        "\n"
        "typedef struct {\n"
        "    const char *name, *qualop, *args, *output;\n"
        "} VnpuKernel;\n"
        "\n"
        "typedef struct {\n"
        "    const char *name;\n"
        "    const char *stmts[32]; int nstmts;\n"
        "} VnpuGraph;\n"
        "\n"
        "typedef struct { const char *name, *porttype; } VnpuPort;\n"
        "\n"
        "typedef struct {\n"
        "    const char *name, *membrane, *entry;\n"
        "    VnpuPort ports[8]; int nports;\n"
        "} VnpuIsolate;\n"
        "\n"
        "typedef struct {\n"
        "    const char *membrane, *action, *subject, *condition;\n"
        "} VnpuPolicyRule;\n"
        "\n"
        "typedef struct {\n"
        "    const char *name;\n"
        "    VnpuPolicyRule rules[8]; int nrules;\n"
        "} VnpuPolicy;\n"
    );
}

/* Collect top-level nodes of a given type into arr[]; returns count. */
static int collect_nodes(AstNode *list, AstNodeType t,
                         AstNode **arr, int maxn) {
    int n = 0;
    for (AstNode *nd = list; nd && n < maxn; nd = nd->next)
        if (nd->type == t) arr[n++] = nd;
    return n;
}

static void emit_devices(FILE *f, AstNode *list) {
    AstNode *devs[256]; int n = collect_nodes(list, AST_DEVICE, devs, 256);
    fprintf(f, "\n/* --- Device Declarations --- */\n");
    fprintf(f, "#define VNPU_NUM_DEVICES %d\n", n);
    if (n == 0) return;
    fprintf(f, "static VnpuDevice vnpu_devices[VNPU_NUM_DEVICES] = {\n");
    for (int i = 0; i < n; i++) {
        AstNode *d = devs[i];
        char props[512] = {0};
        for (AstNode *p = d->child; p; p = p->next) {
            if (props[0]) strncat(props, ",", sizeof(props) - strlen(props) - 1);
            char val[64]; prop_val_str(p->child, val, sizeof(val));
            char kv[128];
            snprintf(kv, sizeof(kv), "%s=%s", p->name ? p->name : "", val);
            strncat(props, kv, sizeof(props) - strlen(props) - 1);
        }
        char esc_name[128], esc_props[512];
        c_escape(d->name ? d->name : "", esc_name, sizeof(esc_name));
        c_escape(props, esc_props, sizeof(esc_props));
        fprintf(f, "    {\"%s\", \"%s\"}%s\n",
                esc_name, esc_props, i < n - 1 ? "," : "");
    }
    fprintf(f, "};\n");
}

static void emit_tensors(FILE *f, AstNode *list) {
    AstNode *ts[256]; int n = collect_nodes(list, AST_TENSOR, ts, 256);
    fprintf(f, "\n/* --- Tensor Declarations --- */\n");
    fprintf(f, "#define VNPU_NUM_TENSORS %d\n", n);
    if (n == 0) return;
    fprintf(f, "static VnpuTensor vnpu_tensors[VNPU_NUM_TENSORS] = {\n");
    for (int i = 0; i < n; i++) {
        AstNode *t = ts[i];
        /* build dims string and count */
        char dims[128] = {0}; int ndims = 0;
        for (AstNode *d = t->left; d; d = d->next, ndims++) {
            char tmp[32];
            if (d->type == AST_LITERAL) snprintf(tmp, sizeof(tmp), "%d", d->ival);
            else if (d->name)           snprintf(tmp, sizeof(tmp), "0/*%s*/", d->name);
            else                        snprintf(tmp, sizeof(tmp), "0");
            if (dims[0]) strncat(dims, ",", sizeof(dims) - strlen(dims) - 1);
            strncat(dims, tmp, sizeof(dims) - strlen(dims) - 1);
        }
        const char *dev = (t->right && t->right->name) ? t->right->name : "";
        char esc_name[128], esc_dtype[32], esc_dev[128];
        c_escape(t->name  ? t->name  : "", esc_name,  sizeof(esc_name));
        c_escape(t->value ? t->value : "", esc_dtype, sizeof(esc_dtype));
        c_escape(dev,                       esc_dev,   sizeof(esc_dev));
        fprintf(f, "    {\"%s\", \"%s\", \"%s\", {%s}, %d}%s\n",
                esc_name, esc_dtype, esc_dev, dims, ndims,
                i < n - 1 ? "," : "");
    }
    fprintf(f, "};\n");
}

static void emit_kernels(FILE *f, AstNode *list) {
    AstNode *ks[256]; int n = collect_nodes(list, AST_KERNEL, ks, 256);
    fprintf(f, "\n/* --- Kernel Declarations --- */\n");
    fprintf(f, "#define VNPU_NUM_KERNELS %d\n", n);
    if (n == 0) return;
    fprintf(f, "static VnpuKernel vnpu_kernels[VNPU_NUM_KERNELS] = {\n");
    for (int i = 0; i < n; i++) {
        AstNode *k = ks[i];
        char qualop[256] = {0}, args[256] = {0};
        if (k->left && k->left->type == AST_CALL) {
            qualid_str(k->left->left, qualop, sizeof(qualop));
            args_str(k->left->right,  args,   sizeof(args));
        }
        const char *out = (k->right && k->right->name) ? k->right->name : "";
        char esc_name[128], esc_op[256], esc_args[256], esc_out[128];
        c_escape(k->name ? k->name : "", esc_name, sizeof(esc_name));
        c_escape(qualop,                  esc_op,   sizeof(esc_op));
        c_escape(args,                    esc_args, sizeof(esc_args));
        c_escape(out,                     esc_out,  sizeof(esc_out));
        fprintf(f, "    {\"%s\", \"%s\", \"%s\", \"%s\"}%s\n",
                esc_name, esc_op, esc_args, esc_out,
                i < n - 1 ? "," : "");
    }
    fprintf(f, "};\n");
}

static void emit_graphs(FILE *f, AstNode *list) {
    AstNode *gs[256]; int n = collect_nodes(list, AST_GRAPH, gs, 256);
    fprintf(f, "\n/* --- Graph Declarations --- */\n");
    fprintf(f, "#define VNPU_NUM_GRAPHS %d\n", n);
    if (n == 0) return;
    fprintf(f, "static VnpuGraph vnpu_graphs[VNPU_NUM_GRAPHS] = {\n");
    for (int i = 0; i < n; i++) {
        AstNode *g = gs[i];
        /* collect stmt names */
        char stmts_buf[512] = {0}; int nstmts = 0;
        for (AstNode *s = g->child; s; s = s->next, nstmts++) {
            char tmp[128];
            snprintf(tmp, sizeof(tmp), "\"%s\"", s->name ? s->name : "");
            if (stmts_buf[0])
                strncat(stmts_buf, ",", sizeof(stmts_buf) - strlen(stmts_buf) - 1);
            strncat(stmts_buf, tmp, sizeof(stmts_buf) - strlen(stmts_buf) - 1);
        }
        char esc_name[128];
        c_escape(g->name ? g->name : "", esc_name, sizeof(esc_name));
        fprintf(f, "    {\"%s\", {%s}, %d}%s\n",
                esc_name, stmts_buf, nstmts, i < n - 1 ? "," : "");
    }
    fprintf(f, "};\n");
}

static void emit_isolates(FILE *f, AstNode *list) {
    AstNode *iso[256]; int n = collect_nodes(list, AST_ISOLATE, iso, 256);
    fprintf(f, "\n/* --- Isolate Declarations --- */\n");
    fprintf(f, "#define VNPU_NUM_ISOLATES %d\n", n);
    if (n == 0) return;
    fprintf(f, "static VnpuIsolate vnpu_isolates[VNPU_NUM_ISOLATES] = {\n");
    for (int i = 0; i < n; i++) {
        AstNode *s = iso[i];
        const char *membrane = "";
        const char *entry    = "";
        char ports_buf[512] = {0};
        int  nports = 0;

        for (AstNode *prop = s->child; prop; prop = prop->next) {
            if (prop->type == AST_MEMBRANE) {
                if (prop->child && prop->child->name) membrane = prop->child->name;
            } else if (prop->type == AST_EXPR &&
                       prop->name && strcmp(prop->name, "entry") == 0) {
                if (prop->child && prop->child->name) entry = prop->child->name;
            } else if (prop->type == AST_LIST) {
                for (AstNode *pt = prop->child; pt; pt = pt->next, nports++) {
                    char tmp[128];
                    const char *ptype =
                        (pt->child && pt->child->name) ? pt->child->name : "";
                    snprintf(tmp, sizeof(tmp), "{\"%s\",\"%s\"}",
                             pt->name ? pt->name : "", ptype);
                    if (ports_buf[0])
                        strncat(ports_buf, ",",
                                sizeof(ports_buf) - strlen(ports_buf) - 1);
                    strncat(ports_buf, tmp,
                            sizeof(ports_buf) - strlen(ports_buf) - 1);
                }
            }
        }

        char esc_name[128], esc_mem[32], esc_entry[128];
        c_escape(s->name ? s->name : "", esc_name,  sizeof(esc_name));
        c_escape(membrane,                esc_mem,   sizeof(esc_mem));
        c_escape(entry,                   esc_entry, sizeof(esc_entry));
        fprintf(f, "    {\"%s\", \"%s\", \"%s\", {%s}, %d}%s\n",
                esc_name, esc_mem, esc_entry, ports_buf, nports,
                i < n - 1 ? "," : "");
    }
    fprintf(f, "};\n");
}

static void emit_policies(FILE *f, AstNode *list) {
    AstNode *ps[256]; int n = collect_nodes(list, AST_POLICY, ps, 256);
    fprintf(f, "\n/* --- Policy Declarations --- */\n");
    fprintf(f, "#define VNPU_NUM_POLICIES %d\n", n);
    if (n == 0) return;
    fprintf(f, "static VnpuPolicy vnpu_policies[VNPU_NUM_POLICIES] = {\n");
    for (int i = 0; i < n; i++) {
        AstNode *pol = ps[i];
        char rules_buf[1024] = {0};
        int  nrules = 0;

        for (AstNode *r = pol->child; r; r = r->next, nrules++) {
            const char *mem    = (r->left  && r->left->name)  ? r->left->name  : "";
            const char *action = "";
            if (r->right) {
                action = r->right->name  ? r->right->name  :
                         r->right->value ? r->right->value : "";
            }
            const char *subj = (r->child && r->child->name) ? r->child->name : "";
            char cond[256] = {0};
            if (r->child && r->child->next)
                expr_str(r->child->next, cond, sizeof(cond));

            char esc_mem[32], esc_act[32], esc_subj[64], esc_cond[256];
            c_escape(mem,    esc_mem,  sizeof(esc_mem));
            c_escape(action, esc_act,  sizeof(esc_act));
            c_escape(subj,   esc_subj, sizeof(esc_subj));
            c_escape(cond,   esc_cond, sizeof(esc_cond));

            char rule[512];
            if (cond[0])
                snprintf(rule, sizeof(rule),
                         "{\"%s\",\"%s\",\"%s\",\"%s\"}",
                         esc_mem, esc_act, esc_subj, esc_cond);
            else
                snprintf(rule, sizeof(rule),
                         "{\"%s\",\"%s\",\"%s\",NULL}",
                         esc_mem, esc_act, esc_subj);

            if (rules_buf[0])
                strncat(rules_buf, ",",
                        sizeof(rules_buf) - strlen(rules_buf) - 1);
            strncat(rules_buf, rule,
                    sizeof(rules_buf) - strlen(rules_buf) - 1);
        }

        char esc_name[128];
        c_escape(pol->name ? pol->name : "", esc_name, sizeof(esc_name));
        fprintf(f, "    {\"%s\", {%s}, %d}%s\n",
                esc_name, rules_buf, nrules, i < n - 1 ? "," : "");
    }
    fprintf(f, "};\n");
}

/* ---- Public entry point ---- */

void codegen_emit(AstNode *root, const char *outfile) {
    if (!root || root->type != AST_PROGRAM) return;

    FILE *f = fopen(outfile, "w");
    if (!f) {
        perror(outfile);
        return;
    }

    fprintf(f, "/* %s - generated by vnpu compiler */\n", outfile);
    fprintf(f, "/* DO NOT EDIT */\n");
    fprintf(f, "#pragma once\n");
    fprintf(f, "#include <stdint.h>\n");
    fprintf(f, "\n/* ---- Type Definitions ---- */\n");
    emit_typedefs(f);

    AstNode *list = root->child;
    emit_devices(f,  list);
    emit_tensors(f,  list);
    emit_kernels(f,  list);
    emit_graphs(f,   list);
    emit_isolates(f, list);
    emit_policies(f, list);

    fclose(f);
}
