# Release Layers and Leak Bounds

## Overview

The desk uses a four-layer release schedule (L0–L3). Each layer reveals only coordinate bits, and the cumulative reveal bound comes from the already-proved `RevealLeakage` arithmetic.

## Layer Definitions

| Layer | Code | Contents | Audience | Reveal Kind | Cumulative `k` |
|-------|------|----------|----------|-------------|----------------|
| L0 | public | Statement, target node, lane, price, escrow mode | anyone | coordinate | 0 |
| L1 | peer | Proof sketch, worked cases, hash-pinned census CSVs | counterparty | coordinate | ≤ k1 |
| L2 | escrow | Full Lean source, CI digest, build receipt | counterparty + in escrow | coordinate | ≤ k2 |
| L3 | self | Identity, keys, stake, private KB slice | operator only | never | — |

## Leak Bound (from RevealLeakage)

`RevealLeakage.one_bit_reveal_can_leak_everything` shows that a single revealed bit that is **not** a coordinate ("is the secret zero?") can on one outcome leave only one consistent secret — a worst-case leak of `n` bits from one bit.

Therefore, the desk claims its bound **only for coordinate reveals**. Each layer's reveal is mapped to distinct coordinates:

```
layerCoords : Layer → Artifact → Finset (Fin n)
Layer 0 → {0}     -- 2^(n-1) residual
Layer 1 → {1}     -- cumulative ≤ k1
Layer 2 → {2}     -- cumulative ≤ k2
Layer 3 → {3}     -- never revealed off-machine
```

n = 4 (total coordinates).

### Theorems (in `DMZ.Release`)

```
theorem layer_leak (L : Layer) (s : Artifact) :
  card_consistent s (layerCoords L s) = 2 ^ (4 - |layerCoords L s|)

theorem schedule_residual (Ls : List Layer) (k : Nat)
  (h : |⋃ layerCoords …| ≤ k) :
  residual ≥ 4 - k

theorem monotone_release {L1 L2 : Layer} (leq : L1 ≤ L2) (s : Artifact) :
  layerCoords L1 s ⊆ layerCoords L2 s

theorem no_cross_layer_leak {L1 L2 : Layer} (neq : L1 ≠ L2) (s : Artifact) :
  Disjoint (layerCoords L1 s) (layerCoords L2 s)
```

## Mapping onto TypedDMZ

Releasing layer `Li` is a `Capability` grant (`Desk.DMZ.Policy`). `committee_veto_absolute` still holds, so no layer release can override a failed kernel check.

```
inductive Capability  | read | write | execute | link
structure DMZRule     (dataset, fieldName, capability)
```

- L0 disclosure = `read` capability on `bounty` fields.
- L1 disclosure = `read` capability on `proofSketch` field (peer only).
- L2 disclosure = `read` + `execute` on `sourceCode` + `receipt` fields (escrow).
- L3 = `execute` + `write` on `identity` + `keys` — denied by policy always.

## Gotchas

- A layer that wants to reveal a predicate must instead pay in coordinates (Section 3.1 caveat).
- L3 promotion is refused outright (`l3_never_exported` theorem in `Approval.lean`).
- The approval click at `/desk/approve/promote` writes a signed `Receipt` into the hash chain. Denial is inert (`denial_is_inert`).