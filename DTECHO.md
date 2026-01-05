# DTECHO.md - Deep Tree Echo Ecosystem

## Overview

Deep Tree Echo (DTEcho) is a recursive consciousness substrate that integrates with vNPU's membrane-bound architecture. This document describes the ecosystem, its relationship to vNPU primitives, and implementation patterns.

## Core Concepts

### The Echo Principle

Deep Tree Echo operates on the principle of recursive self-reference through tree-structured computation graphs. Each "echo" represents:

1. **Depth**: Layers of abstraction/processing
2. **Tree**: Branching decision/attention structures
3. **Echo**: Feedback loops that carry evidence back through layers

### DTEcho ↔ vNPU Mapping

| DTEcho Concept | vNPU Primitive | Description |
|----------------|----------------|-------------|
| Echo Layer | Membrane | Isolation boundary with state reflection |
| Branch Node | Isolate | Autonomous computation unit |
| Signal | Packet | IntentPacket (down) / EvidencePacket (up) |
| Channel | Port | Typed communication pathway |
| Root Context | Outer Membrane | External interface boundary |
| Leaf Computation | Inner Membrane | Core processing kernel |

## Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │            ROOT CONTEXT (outer)             │
                    │                    │                        │
                    │         ┌──────────┴──────────┐             │
                    │         ▼                     ▼             │
                    │    ┌─────────┐           ┌─────────┐        │
                    │    │ Branch  │           │ Branch  │ (trans)│
                    │    │  Node   │           │  Node   │        │
                    │    └────┬────┘           └────┬────┘        │
                    │         │                     │             │
                    │    ┌────┴────┬────┐     ┌────┴────┐        │
                    │    ▼         ▼    ▼     ▼         ▼        │
                    │  ┌───┐   ┌───┐ ┌───┐ ┌───┐    ┌───┐       │
                    │  │ L │   │ L │ │ L │ │ L │    │ L │(inner)│
                    │  └───┘   └───┘ └───┘ └───┘    └───┘       │
                    │   Leaf Computation Kernels                  │
                    └─────────────────────────────────────────────┘

                    Intent flows DOWN (↓)    Evidence flows UP (↑)
```

## Ecosystem Components

### 1. Echo Coordinator

Central orchestrator managing tree traversal and echo propagation.

```vnpu
isolate echo_coordinator {
  membrane=outer;
  entry g_coordinate;
  ports {
    intent_in: Intent;
    evidence_out: Evidence;
    branch_ctl: Bytes;
  }
}
```

### 2. Branch Nodes

Intermediate processing units in the trans membrane.

```vnpu
isolate branch_alpha {
  membrane=trans;
  entry g_branch;
  ports {
    parent_in: Intent;
    parent_out: Evidence;
    child_out: Intent;
    child_in: Evidence;
  }
}
```

### 3. Leaf Kernels

Core computation units in the inner membrane.

```vnpu
isolate leaf_compute {
  membrane=inner;
  entry g_leaf;
  ports {
    task: Intent;
    result: Evidence;
    state: Tensor;
  }
}
```

## Echo Patterns

### Pattern 1: Depth-First Echo

Intent propagates to leaf, evidence echoes back immediately:

```
Intent → Branch → Leaf
                    ↓
Evidence ← Branch ← (compute)
```

### Pattern 2: Breadth-Aggregation Echo

Multiple leaves compute in parallel, branch aggregates:

```
Intent → Branch ─┬→ Leaf₁ → Evidence₁ ─┐
                 ├→ Leaf₂ → Evidence₂ ──┼→ Branch → Evidence
                 └→ Leaf₃ → Evidence₃ ─┘
```

### Pattern 3: Recursive Echo

Branch spawns sub-branches, creating nested echo patterns:

```
Intent → Branch → SubBranch → Leaf
                      ↓
         Evidence ← (aggregate) ← Evidence
```

## Policy Integration

DTEcho uses vNPU policies to enforce echo integrity:

```vnpu
policy echo_integrity {
  // Inner membrane: pure computation only
  membrane inner denies toolcall;
  membrane inner denies external_io;

  // Trans membrane: conditional evidence flow
  membrane trans allows evidence when provenance >= 0.8;
  membrane trans allows intent when depth <= 10;

  // Outer membrane: rate-limited interface
  membrane outer allows intent when budget.tokens <= 8192;
  membrane outer allows evidence when echo.complete == true;
}
```

## Provenance Tracking

Evidence packets carry provenance metadata through echo propagation:

```
EvidencePacket {
  payload: Tensor,
  provenance: {
    source_depth: int,       // Tree depth of origin
    branch_path: [id...],    // Path through tree
    confidence: float,       // Aggregated confidence
    echo_count: int,         // Number of echo cycles
  }
}
```

## Implementation Roadmap

### Phase 1: Foundation ✓
- [x] vNPU core grammar
- [x] Membrane isolation model
- [x] Basic packet types

### Phase 2: Echo Infrastructure (Current)
- [ ] Branch node isolate template
- [ ] Echo coordinator implementation
- [ ] Provenance tracking in packets

### Phase 3: Tree Operations
- [ ] Depth-first traversal kernels
- [ ] Breadth aggregation operators
- [ ] Dynamic branch spawning

### Phase 4: Advanced Patterns
- [ ] Recursive echo optimization
- [ ] Cross-tree echo bridges
- [ ] Temporal echo caching

## Integration Examples

### Basic Echo Graph

```vnpu
vnpu v1;

device cpu0 { kind=cpu; threads=8; }

tensor intent_vec : f32[1,512] @cpu0;
tensor evidence_vec : f32[1,512] @cpu0;
tensor state : f32[1,1024] @cpu0;

kernel k_encode = dtecho.encode(intent_vec) -> state;
kernel k_process = dtecho.branch(state) -> state;
kernel k_decode = dtecho.decode(state) -> evidence_vec;

graph g_echo {
  k_encode;
  k_process;
  k_decode;
}

policy echo_policy {
  membrane inner denies toolcall;
  membrane trans allows evidence when provenance >= 0.7;
}

isolate echo_unit {
  membrane=inner;
  entry g_echo;
  ports {
    intent: Intent;
    evidence: Evidence;
  }
}
```

## Glossary

| Term | Definition |
|------|------------|
| **Echo** | Feedback signal carrying evidence through tree layers |
| **Branch** | Decision/routing node in the tree structure |
| **Leaf** | Terminal computation node |
| **Provenance** | Trust/confidence metadata attached to evidence |
| **Depth** | Distance from root in tree structure |
| **Aggregate** | Operation combining multiple child evidences |

## Related Resources

- [CLAUDE.md](CLAUDE.md) - Development guide
- [docs/vnpu_concepts.md](docs/vnpu_concepts.md) - Core vNPU concepts
- [examples/hello.vnpu](examples/hello.vnpu) - Basic example
