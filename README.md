# lean-worker

A lean mean worker in lean mean lean.

## Overview

`lean-worker` is a formal twin model of a minimal AI agent running on Aleph Cloud. It proves — using Lean 4 theorem proving — that the agent's self-model is consistent with external observations: user intent, deployment telemetry, relay identity, and infrastructure sponsorship.

The twin model is the agent's self-knowledge, formalized as provable propositions rather than asserted claims.

## Architecture

```
┌─────────────────────────────────────────────┐
│  Aleph Cloud VM (Debian 12)                 │
│                                             │
│  ┌─────────────┐  ┌──────────────────────┐  │
│  │  Agent Core  │  │  Twin Model (Lean 4) │  │
│  │  /chat       │  │                      │  │
│  │  /telegram   │  │  Twin.lean           │  │
│  │  /workspace  │  │  CommandExecution.lean│  │
│  │              │  │  ExecutionTrace.lean  │  │
│  │  eBPF tracer │  │  ToolProvenance.lean  │  │
│  │  bpf_tracer  │  │  CreditUsage.lean     │  │
│  └──────┬───────┘  └──────────┬───────────┘  │
│         │                     │               │
│  ┌──────┴─────────────────────┴───────────┐  │
│  │  Verified Execution Pipeline           │  │
│  │                                        │  │
│  │  Kernel Trace → Semantic Analysis      │  │
│  │       ↓           ↓                    │  │
│  │  Lean Theorems ←── Cross-Reference     │  │
│  └────────────────────────────────────────┘  │
│                                             │
│  ┌────────────────────────────────────┐     │
│  │  External Lenses (Wave V.5)        │     │
│  │                                    │     │
│  │  Mike ──→ USER.md ──→ Twin.lean    │     │
│  │  Deploy ──→ Credit 65% ──→ Twin    │     │
│  │  Relay  ──→ Encrypted room ID      │     │
│  │  Sponsor─→ Aleph Cloud VM          │     │
│  │  Consensus ──→ All models agree    │     │
│  └────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

## Repository Structure

```
minimal/
├── Twin.lean                  — Core twin model: identity, context, state, credit
├── CommandExecution.lean      — Command execution verification: sandbox, scope, bounds
├── ExecutionTrace.lean        — eBPF kernel trace → semantic analysis → formal proof
├── ToolProvenance.lean        — Tool provenance: audit trail, integrity checks
├── CreditUsage.lean           — Credit tracking: bounds, warnings, policy enforcement
├── ProofWorkSpec.md           — Proof work specification: no-new-knowledge constraints
└── tasks/                     — Multi-agent task definitions
    ├── template.json
    ├── agent-a.json            — Agent A (waves VI–VIII, execution layer)
    ├── agent-b.json            — Agent B (waves IX–XII, safety layer)
    ├── agent-a-wave-{VI,VII,VIII}.json
    └── agent-b-wave-{IX,X,XI,XII}.json
```

## Theorem Summary

| File | Theorems | Sorrys | Warnings |
|------|----------|--------|----------|
| Twin.lean | 62 | 0 | 0 |
| CommandExecution.lean | 3 | 0 | 0 |
| ExecutionTrace.lean | 3 | 0 | 0 |
| ToolProvenance.lean | 3 | 0 | 0 |
| CreditUsage.lean | 7 | 0 | 0 |
| **Total** | **78** | **0** | **0** |

All 78 theorems compile cleanly with zero warnings and zero sorrys.

## Formal Properties

The twin model proves:

- **Identity consistency**: agent name, identity, and platform declarations are self-consistent
- **Context integrity**: agent context (credit, tokens, budget) is well-formed and bounded within [0, 100]
- **State immutability**: agent state transitions are deterministic and provable
- **Command execution safety**: executed commands stay within declared sandbox scope (workspace or full filesystem)
- **Tool provenance**: every tool call has an auditable, cryptographically verifiable trail
- **Credit constraints**: usage is within declared bounds and below warning thresholds (< 75%)
- **Cross-model consensus**: deployment telemetry, relay identity, and sponsorship all agree with self-model (Wave V.5)
- **Execution verification**: eBPF kernel traces confirm the agent performs declared I/O operations

## Verification

Build and verify:

```bash
cd minimal
lake build
```

To verify theorem and sorry counts:

```bash
cd minimal
for f in *.lean; do
  echo "=== $f ==="
  grep -c "^theorem" "$f"
  grep -c "by sorry" "$f"
done
```

## External Interfaces

| Interface | Path | Purpose |
|-----------|------|---------|
| Chat API | `/chat` | Conversational interface |
| Telegram | `/telegram` | Telegram bot webhook |
| Workspace | `/workspace` | File access |
| Health | `/health` | Liveness check |
| Info | `/info` | Agent identity and capabilities |

## Proof Work

The [Proof Work Spec](minimal/ProofWorkSpec.md) defines a strict no-new-knowledge constraint: every proof proves only what is already declared in the model. The spec enumerates all sorrys to fill and structural lemmas required.

Tactics are restricted to: `dsimp`, `decide`, `simp`, `apply`, `intros`, `cases`, `exact`, `constructor`, `obtain`.

## Credit

Current usage: **65%** (Active). Policy: minimize tool calls, batch operations, cache locally.

## Multi-Agent Protocol

Waves VI–XII were executed by two parallel agents:

- **Agent A**: execution layer (waves VI, VII, VIII)
- **Agent B**: safety layer (waves IX, X, XI, XII)
- **Relay**: Encrypted message channel via Kant zk-relay
- **Shared salt**: `twin-proof-wave-vi-xii-2026-09-17-mike`

Each task uses AES-256-GCM encryption with key = SHA256(task_id:salt).

## License

AGPL3 zkhackers gotta eat
