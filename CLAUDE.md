# CLAUDE.md - vNPU Development Guide

## Project Overview

vNPU (Virtual Neural Processing Unit) is a membrane-bound neural substrate architecture for portable AI/ML execution across Plan9/Inferno/WorkerD/V8 environments.

## Quick Commands

```bash
# Build parser
cd src/parser && make

# Test parser with example
cd src/parser && make test

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
├── grammar/Vnpu.g4    # ANTLR4 grammar (IDE/tooling)
├── src/parser/
│   ├── vnpu.l         # Lex tokenizer (Plan9/Inferno)
│   ├── vnpu.y         # Yacc parser (Plan9/Inferno)
│   └── Makefile       # Build system
├── examples/
│   └── hello.vnpu     # Example program
├── docs/
│   └── vnpu_concepts.md
└── assets/            # Architecture diagrams
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
- [ ] AST data structures (TODO in vnpu.y:14)
- [ ] Semantic analysis
- [ ] Code generation

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
