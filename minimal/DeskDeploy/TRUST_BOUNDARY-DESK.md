# Trust Boundary — OTC Proof Trading Desk

## Boundary Enforcement

The desk enforces isolation between three zones using systemd hardening, mirroring `kant-relay.service` (Section 3.4 of the plan):

```ini
[Service]
User=otc-desk
Group=otc-desk
StateDirectory=otc-desk
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictNamespaces=true
RestrictSUIDSGID=true
LockPersonality=true
MemoryMax=512M
ReadOnlyPaths=/mnt/data1/time-2026/09-september/18/lean-worker
ReadOnlyPaths=/mnt/data1/aristotle-builds
InaccessiblePaths=/home/mdupont/.ssh
SystemCallFilter=@system-service
SystemCallArchitectures=native
```

## Zones

| Zone | Path | Writable | Enforced By |
|------|------|----------|-------------|
| core | `lean-worker/minimal`, lake, mathlib, Aristotle corpus | No (read-only) | `ReadOnlyPaths` |
| DMZ | `/var/lib/otc-desk` | Yes | `ProtectSystem=strict` allows only StateDirectory |
| self | operator home, `~/.ssh` | No (inaccessible) | `InaccessiblePaths` |

## Trust Assumptions (Gödel, Section 6)

The Lean system cannot prove its own consistency. Trust is architectural:

1. **Minimal kernel** — the desk's Lean modules run under the same 4-layer TypedDMZ kernel (`TypedDMZ.lean`) that the formal prior art uses. No new axioms are introduced.

2. **External audit** — the formal prior art at `lean-split-tool/dasl-verification/RequestProject/` (`TypedDMZ.lean`, `UmweltGodelTrust.lean`, 7 modules, `sorry=0 axiom=0`) serves as the architectural audit reference. The desk does not fork these modules; it extends them.

3. **Architectural separation** — the desk runs as a dedicated systemd service under user `otc-desk` with no access to operator keys or the core corpus write paths. The boundary is mechanical (systemd hardening), not conventional.

## Why the L3 approval step is a human click

`UmweltGodelTrust.lean` proves that `bedrock_trust` (Layer 6 of the trust stack) has dimension 0 and is unmeasurable from inside the system. The desk's L3 layer is a `Capability` grant inside this stack. Because the system cannot prove its own consistency, the release gate cannot be a predicate — it must be a human click at `/desk/approve/promote`.

## What Trust Does Not Cover

- **Network-layer attacks on P2P.Tag**: `Tag` literally carries its signing key (idealised model). This is fine for a board that says "no funds exist." It stops being fine when the desk holds value worth stealing. Fix before first real trade.
- **Sybil resistance**: `cap_does_not_imply_sybil_resistance` is proved. The desk says so on the page.
- **Forged tickets**: the relay cannot forge (`relay_cannot_forge`, `Envelope.decode_encode`). Clients re-check.