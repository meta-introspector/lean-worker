# OTC Proof Trading Desk — Operator Guide

## Overview

The OTC Proof Trading Desk is a secure DMZ inside `lean-worker` where agents trade parts of Aristotle proofs bilaterally, off-book, under kernel-checked rules.

## Architecture

### Three Zones (enforced by systemd)

| Zone | Path | Access |
|------|------|--------|
| **core** | `lean-worker/minimal`, lake, mathlib, Aristotle corpus | read-only |
| **DMZ** | `/var/lib/otc-desk` — room logs, escrow blobs, KB cache, GUI | only writable zone |
| **self** | operator home — keys, L3 material | never exported |

The service runs as user `otc-desk` with hardened systemd settings mirroring `kant-relay.service`.

## Installation

```bash
# Run as root
cd /mnt/data1/time-2026/09-september/18/lean-worker/minimal/DeskDeploy
./install.sh
```

The install script:
1. Creates the `otc-desk` system user
2. Sets up `/var/lib/otc-desk` StateDirectory
3. Installs the systemd unit at `/etc/systemd/system/otc-desk.service`
4. Configures nginx vhost (if nginx is present)

## Starting the Desk

```bash
systemctl start otc-desk
systemctl status otc-desk
journalctl -u otc-desk -f
```

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check with room stats |
| POST | `/room/{room}` | Append lines to room log |
| GET | `/room/{room}?cursor=N[&wait=S]` | Poll room log (long-poll with wait) |
| WS | `/ws/{room}?cursor=N` | WebSocket stream |
| GET | `/desk/board` | 21-bounty board from BountyBoard |
| POST | `/desk/quote` | Request bilateral quote on a unit |
| POST | `/desk/ticket` | Post trade ticket (Envelope, tagTrade) |
| POST | `/desk/escrow` | Deposit into escrow |
| GET | `/desk/escrow/{id}` | Get escrow state |
| POST | `/desk/approve/promote` | Approve layer promotion (signed Receipt) |
| GET | `/desk/kb?q=` | Query witnessed KB |

## Layered Release

Four layers (L0–L3) with proved bit bounds from `RevealLeakage`:

| Layer | Contents | Audience | Reveal | Cumulative k |
|-------|----------|----------|--------|-------------|
| L0 | Statement, target, lane, price, escrow mode | anyone | coordinate | 0 |
| L1 | Proof sketch, worked cases, hash-pinned census | counterparty | coordinate | ≤ k1 |
| L2 | Full Lean source, CI digest, build receipt | counterparty in escrow | coordinate | ≤ k2 |
| L3 | Identity, keys, stake, private KB slice | operator only | never | — |

Promoting a layer requires a human approval click at `/desk/approve/promote`, which writes a signed `Receipt` into the hash chain.

## Settlement Rails

| Rail | Mechanism | Settles Today? |
|------|-----------|----------------|
| A — units | Board units 1:1 (`BountyBoard`) | Yes (default) |
| B — metameme | `PaymentMorphism` on artifact | Price only |
| C — credits | `Kant.Credits` — earn by serving, spend on checks | Yes (for checkers) |
| D — out-of-band | Opaque `settlementRef` | Reference only |

## Security Notes

- **No chain, no mint, no wallet keys** — all settlement is off-chain.
- **`P2P.Tag` carries its own signing key** — idealised model, not a real MAC.
- **Sybil-open by construction** — `cap_does_not_imply_sybil_resistance` is proved.
- **Acceptance checking is expensive** — 48.9 CPU-min cold corpus check. `Policy.byteBudget` and `fuelBudget` bound it.