/**
 * sema.h - vNPU Semantic Analysis
 */
#ifndef SEMA_H
#define SEMA_H

#include "ast.h"

/*
 * Run semantic analysis on a parsed vNPU program.
 * Returns 0 on success, or the number of errors detected.
 *
 * Checks performed:
 *   - Duplicate top-level declarations
 *   - Tensor @device references a declared device
 *   - Kernel argument identifiers reference declared tensors
 *   - Kernel output references a declared tensor
 *   - Graph statements reference declared kernels
 *   - Isolate entry references a declared graph
 */
int sema_check(AstNode *root);

#endif /* SEMA_H */
