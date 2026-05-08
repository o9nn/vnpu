/**
 * ast.h - vNPU Abstract Syntax Tree definitions
 */
#ifndef AST_H
#define AST_H

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

/* Global parse result */
extern AstNode *ast_root;

/* Construction helpers */
AstNode *make_node(AstNodeType type, const char *name);
AstNode *make_literal_int(int val);
AstNode *make_literal_float(double val);
AstNode *make_literal_str(const char *val);
void append_node(AstNode *list, AstNode *item);

/* Printing */
void print_expr(AstNode *n);
void print_ast(AstNode *n, int indent);

/* Cleanup */
void free_ast(AstNode *n);

#endif /* AST_H */
