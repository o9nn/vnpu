# vNPU Key Concepts and Relationships

## Core Concepts

### 1. Membranes
- Three types: `inner`, `trans`, `outer`
- Act as security/isolation boundaries
- Control what can pass between layers
- Policies define what each membrane allows/denies
- Example: "membrane inner denies toolcall"
- Example: "membrane trans allows evidence when provenance>=0.7"

### 2. Isolates
- Actor/process with private heap/state
- Each isolate is bound to a membrane type
- Has an entry point (graph to execute)
- Contains ports for communication
- Example:
  ```
  isolate core {
    membrane=inner;
    entry g_main;
  }
  ```

### 3. Ports
- Typed channels/files for communication
- Types: `in/out/ctl/stat`
- Port types: `Intent`, `Evidence`, `Tensor`, `Bytes`
- Allow isolates to communicate across membrane boundaries
- Declared within isolates

### 4. Packets
- Two main types: `IntentPacket`, `EvidencePacket`
- Flow through ports
- Subject to membrane policies (provenance, budget checks)
- Carry data/commands between isolates

## Relationships

```
                    ┌─────────────────────────────────────────────┐
                    │              OUTER MEMBRANE                  │
                    │  ┌───────────────────────────────────────┐  │
                    │  │          TRANS MEMBRANE                │  │
                    │  │  ┌─────────────────────────────────┐  │  │
                    │  │  │       INNER MEMBRANE             │  │  │
                    │  │  │                                  │  │  │
                    │  │  │    ┌──────────────┐              │  │  │
                    │  │  │    │   ISOLATE    │              │  │  │
                    │  │  │    │  ┌────────┐  │              │  │  │
                    │  │  │    │  │ PORTS  │──┼──► Packets   │  │  │
                    │  │  │    │  └────────┘  │              │  │  │
                    │  │  │    └──────────────┘              │  │  │
                    │  │  │                                  │  │  │
                    │  │  └─────────────────────────────────┘  │  │
                    │  └───────────────────────────────────────┘  │
                    └─────────────────────────────────────────────┘
```

## Key Relationships:
1. **Membranes contain Isolates**: Each isolate is assigned to a membrane layer
2. **Isolates have Ports**: Ports are declared within isolates for I/O
3. **Packets flow through Ports**: IntentPacket and EvidencePacket are the data units
4. **Membranes filter Packets**: Policies on membranes control packet flow
5. **Nested membrane structure**: inner → trans → outer (like cell membranes)
