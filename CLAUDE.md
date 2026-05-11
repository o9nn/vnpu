# CLAUDE.md - vNPU Development Guide

## Project Overview

vNPU (Virtual Neural Processing Unit) is a membrane-bound neural substrate architecture for portable AI/ML execution across Plan9/Inferno/WorkerD/V8 environments.

## Quick Commands

```bash
# Build parser
cd src/parser && make build

# Smoke test (parse hello.vnpu)
cd src/parser && make test

# Full end-to-end test suite (all fixtures + golden comparison)
cd src/parser && make e2e          # or: bash tests/run_e2e.sh src/parser/vnpu_parser

# Grammar parity check (ANTLR ↔ lex/yacc)
cd src/parser && make grammar-check

# Validate every example compiles
cd src/parser && make validate-examples

# Regenerate golden files after compiler changes
cd src/parser && make update-goldens

# Clean build artifacts
cd src/parser && make clean
```

## Architecture Summary

### Core Abstractions

| Concept | Description | File(s) |
|---------|-------------|---------|
| **Membranes** | Three-layer isolation (inner/trans/outer) | grammar/Vnpu.g4:53 |
| **Isolates** | Actor/process units with private state | grammar/Vnpu.g4:38-46 |
| **Ports** | Typed channels (Intent/Evidence/Tensor/Bytes) | grammar/Vnpu.g4:45-46 |
| **Packets** | IntentPacket/EvidencePacket message units | docs/vnpu_concepts.md |
| **Policies** | Membrane permission rules | grammar/Vnpu.g4:48-51 |

### Directory Structure

```
vnpu/
├── CLAUDE.md          # This file - AI development guide
├── DTECHO.md          # Deep Tree Echo ecosystem integration
├── grammar/Vnpu.g4    # ANTLR4 reference grammar (IDE/tooling)
├── src/parser/
│   ├── ast.h          # AST type definitions and declarations
│   ├── ast.c          # AST construction, printing, cleanup
│   ├── sema.h         # Semantic analysis interface
│   ├── sema.c         # Symbol table + reference validation
│   ├── codegen.h      # Code generation interface
│   ├── codegen.c      # C descriptor header emitter
│   ├── vnpu.l         # Lex tokenizer (Plan9/Inferno)
│   ├── vnpu.y         # Yacc parser (Plan9/Inferno)
│   └── Makefile       # Build system (build/test/e2e/grammar-check/…)
├── tests/
│   ├── run_e2e.sh           # Full fixture + golden test runner
│   ├── run_grammar_check.sh # ANTLR ↔ lex/yacc parity checker
│   ├── validate_examples.sh # Compile all examples/
│   ├── update_goldens.sh    # Regenerate golden files
│   ├── fixtures/
│   │   ├── valid/           # Programs that must parse + sema-check OK
│   │   └── invalid/         # Programs that must be rejected
│   └── goldens/             # Expected compiler output for valid fixtures
├── examples/
│   ├── hello.vnpu           # Canonical hello-world example
│   ├── dtecho_basic.vnpu    # DTEcho basic echo pattern
│   ├── dtecho_provenance.vnpu  # DTEcho provenance tracking (Phase 2)
│   ├── dtecho_depth_first.vnpu # DTEcho depth-first traversal (Phase 3)
│   └── dtecho_breadth_agg.vnpu # DTEcho breadth aggregation (Phase 3)
├── .github/workflows/
│   ├── ci.yml               # Main build+test CI (OS × compiler matrix)
│   ├── grammar-check.yml    # Grammar parity on grammar/src/parser changes
│   ├── examples.yml         # Compile all examples on push
│   └── release.yml          # Build + publish binary on version tags
├── docs/
│   └── vnpu_concepts.md
└── assets/                  # Architecture diagrams
```

## Language Syntax (vNPU IDL)

```vnpu
vnpu v1;

// Device: execution target
device <name> { <prop>=<value>; ... }

// Tensor: typed memory with shape and location
tensor <name> : <dtype>[<dims>] @<device>;

// Kernel: operation binding
kernel <name> = <namespace>.<op>(<args>) -> <output>;

// Policy: membrane rules
policy <name> {
  membrane <layer> allows|denies <action> when <condition>;
}

// Graph: execution sequence
graph <name> { <kernel>; ... }

// Isolate: sandboxed execution unit
isolate <name> {
  membrane=<layer>;
  entry <graph>;
  ports { <name>: <type>; ... }
}
```

## Data Types

- **dtype**: `f16`, `f32`, `bf16`, `i8`, `i16`, `i32`, `i64`, `u8`
- **port types**: `Intent`, `Evidence`, `Tensor`, `Bytes`
- **membranes**: `inner`, `trans`, `outer`

## Key Design Patterns

### Membrane Security Model

```
outer  ─── 9P/Styx interface (external world)
  │
trans  ─── Conditional gateway (provenance/budget checks)
  │
inner  ─── Core computation (denies external toolcalls)
```

### Packet Flow

```
IntentPacket  → [outer] → [trans] → [inner] → Computation
                                              ↓
EvidencePacket ← [outer] ← [trans] ← [inner] ← Results
```

## Development Notes

### Parser Implementation Status

- [x] ANTLR4 grammar complete (grammar/Vnpu.g4)
- [x] Lex/Yacc parser scaffolding (src/parser/)
- [x] AST data structures (ast.h / ast.c)
- [x] Parser actions for AST construction (all grammar rules build AST)
- [x] AST pretty-printer for debugging (print_ast function)
- [x] Semantic analysis (sema.h / sema.c)
- [x] Code generation (codegen.h / codegen.c)
- [x] Correct exit codes (sema failures return non-zero)
- [x] Basename in generated header comment (portable golden comparison)

### Semantic Analysis Coverage

`sema.c` performs a two-pass analysis:

| Check | Rule |
|-------|------|
| Duplicate declarations | All top-level names must be unique per kind |
| Tensor @device reference | Named device must be declared |
| Kernel argument tensors | Every ID argument must name a declared tensor |
| Kernel output tensor | Output ID must name a declared tensor |
| Graph kernel references | Every graph statement must name a declared kernel |
| Isolate entry graph | Entry ID must name a declared graph |
| Isolate `membrane` required | Every isolate must declare a membrane |
| Isolate `entry` required | Every isolate must declare an entry graph |
| Port name uniqueness | Port names must be unique within each isolate |

### Test Pyramid

```
tests/fixtures/valid/        # 9 fixtures — must parse + sema-check (exit 0)
tests/fixtures/invalid/      # 15 fixtures — must be rejected (exit non-zero)
tests/goldens/               # Expected compiler output for valid fixtures
```

Run with `make e2e` (24 tests, all pass by default).

### CI / GitHub Actions

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `ci.yml` | push/PR to main | Build + test on Ubuntu 22.04/24.04 × gcc/clang |
| `grammar-check.yml` | grammar/parser file changes | ANTLR ↔ lex/yacc parity |
| `examples.yml` | examples/ or parser changes | Compile all examples; upload headers |
| `release.yml` | `v*.*.*` tag | Build + publish binary tarball release |

### Recent Changes

**Semantic Analysis + Code Generation (completed)**
- Extracted AST definitions into `ast.h` / `ast.c` for reuse across modules
- Implemented `sema.c`: two-pass analysis (collect symbols → validate references)
  - Checks for duplicate declarations, undefined devices/tensors/kernels/graphs
- Implemented `codegen.c`: emits `vnpu_out.h` — a self-contained C descriptor
  header with `static` tables for devices, tensors, kernels, graphs, isolates,
  and policies; suitable for direct inclusion in a C runtime
- Updated `main()` in `vnpu.y` to run all three phases: parse → sema → codegen
- Output file defaults to `vnpu_out.h`; override with `./vnpu_parser out.h < prog.vnpu`

**AST Construction Phase (completed)**
- Enhanced AST node structure with support for all vNPU constructs
- Implemented semantic actions in parser to build AST during parsing
- Added comprehensive AST pretty-printer showing:
  - Device declarations with properties
  - Tensor declarations with shapes and locations
  - Kernel declarations with qualified calls
  - Policy statements with complex conditions
  - Graph and isolate definitions
- Parser successfully builds and prints AST for complete vNPU programs

### Parser Example Output

```bash
cd src/parser && make test
```

Output shows structured AST, semantic results, and generated file:
```
Parse successful!

=== Abstract Syntax Tree ===
PROGRAM
  Device 'cpu0' { kind=cpu, threads=4 }
  ...
  Kernel 'k0' = aten.matmul(x, w) -> y
  Policy 'mem'
    membrane inner denies toolcall
    membrane trans allows evidence when (provenance>=0.7 and budget.tokens<=4096)
  Graph 'g_main' { k0; k1; }
  Isolate 'core'
    membrane = inner
    entry g_main
    ports { ... }

=== Semantic Analysis ===
Semantic analysis: OK (10 symbols)

=== Code Generation ===
Generated: vnpu_out.h
```

The generated `vnpu_out.h` contains static C descriptor tables ready for runtime use.

### Adding New Language Features

1. Update `grammar/Vnpu.g4` (ANTLR4 grammar)
2. Update `src/parser/vnpu.l` (lexer tokens)
3. Update `src/parser/vnpu.y` (parser rules)
4. Add tests in `examples/`

### Integration Points

- **Plan 9/Inferno**: `/dev/vnpu/*` device files, Styx/9P services
- **PyTorch/ATen**: Kernel operation namespace (`aten.matmul`, etc.)
- **RWKV**: Custom kernel namespace (`rwkv.step`, etc.)

## Common Tasks

### Validate Grammar Changes
```bash
# Install ANTLR4 if needed
# antlr4 -Dlanguage=Python3 grammar/Vnpu.g4

# Test with lex/yacc
cd src/parser && make clean && make test
```

### Add New Port Type
1. Add token to `vnpu.l` (e.g., `"NewType" return NEWTYPE;`)
2. Add token declaration to `vnpu.y`
3. Extend `porttype` rule in `vnpu.y`
4. Update `portType` rule in `Vnpu.g4`

## Deep Tree Echo Integration

See [DTECHO.md](DTECHO.md) for ecosystem integration with:
- Recursive consciousness substrate
- Multi-layer membrane synchronization
- Evidence provenance tracking
