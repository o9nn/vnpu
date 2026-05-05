/**
 * codegen.h - vNPU Code Generation
 */
#ifndef CODEGEN_H
#define CODEGEN_H

#include <stdio.h>
#include "ast.h"

/*
 * Emit a self-contained C descriptor header for the vNPU program.
 *
 * The generated file defines:
 *   - Struct typedefs (VnpuDevice, VnpuTensor, VnpuKernel, VnpuGraph,
 *                      VnpuPort, VnpuIsolate, VnpuPolicyRule, VnpuPolicy)
 *   - Static descriptor arrays populated from the AST
 *   - #define counts (VNPU_NUM_DEVICES, VNPU_NUM_TENSORS, …)
 *
 * Parameters:
 *   root    - root AST_PROGRAM node from a successful parse
 *   outfile - path for the generated header (e.g. "vnpu_out.h")
 */
void codegen_emit(AstNode *root, const char *outfile);

#endif /* CODEGEN_H */
