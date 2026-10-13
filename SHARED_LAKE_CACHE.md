# Shared Lake Cache — How To (aristotle-manager tooling)

How the shared lake-cache works, and how to build/deploy Lean projects without
ever recompiling mathlib. Everything here is driven by the `aristotle-manager`
binary (`aristo`), repo: `~/projects/aristotle-manager`.

## Why

Every Aristotle result project pins the same mathlib (e.g. v4.28.0 +
`8f9d9cff6bd7`). Without a shared cache each project would clone mathlib and
rebuild thousands of modules. With the shared store, mathlib and the other
managed packages (batteries, aeson, proofwidgets, Qq, std, importGraph) exist
**once** on disk and every project symlinks to them.

## Layout

```
/mnt/data1/lake-cache/            # LEAN_SHARED_CACHE_ROOT
├── env.sh                        # source me: exports LEAN_SHARED_CACHE_ROOT
├── README.md
└── lean-shared/
    ├── mathlib/<toolchain>-<rev12>/          # shared mathlib checkouts
    │   └── .lake/build/lib/lean/…            # 7k+ prebuilt oleans after `cache get!`
    └── lake-packages/<name>/<toolchain>-<rev12>/   # shared deps
```

- `rev12` = first 12 hex chars of the manifest-pinned git rev.
- A project's `.lake/packages/<name>` is a **symlink** into the store.
- Toolchain must match: store paths embed the toolchain, so v4.28.0 projects
  never pick up a v4.29.0 checkout.

## The commands

```bash
source /mnt/data1/lake-cache/env.sh        # or let `deploy` set it for you

aristotle-manager cache init               # once per machine: dirs + env.sh + elan check
aristotle-manager cache status <PROJECT>   # what's in the store, is the project linked?
aristotle-manager cache link <PROJECT>     # link shared mathlib+pkgs (adopts real checkouts)
aristotle-manager cache link-all /mnt/data1/aristotle-results
aristotle-manager cache dedup              # DRY-RUN: find duplicated .lake/packages copies
aristotle-manager cache dedup --execute    # actually adopt/remove them
aristotle-manager cache prune --execute    # drop stale build workspaces (>2d old, UUID dirs)
aristotle-manager cache gc                 # remove store revs no project links to anymore
```

`Makefile` shortcuts (in aristotle-manager):

| target | does |
|---|---|
| `make cache-init` | `cache init` |
| `make publish-n N=10` | build+publish N newest projects |
| `make publish-one PROJ=<uuid>` | one explicit project |
| `make tile-deploy` | nginx system-manager activation for the tile |
| `make cache-status PROJ=<uuid>` | debug linkage for one project |
| `make worker-debug PROJ=<uuid>` | gokujo debug report |

## Build + deploy (the important one)

`aristotle-manager publish <PROJECT…> --web-root W --limit N [--no-cache-exe] [--no-nix]`

Per project it runs a fixed pipeline in a **build workspace** under
`/mnt/data1/aristotle-builds/<uuid>/` (sources hardlinked in, fresh `.lake`):

1. **cache link** — `link_project()`: every managed package pinned in
   `lake-manifest.json` gets symlinked to the shared store. A real checkout
   whose `git rev-parse HEAD` equals the manifest rev is *adopted* — moved
   into the store and symlinked back — so repeated builds never duplicate.
   Store HEAD drift is auto-corrected (`git checkout <rev>`) and origin URLs
   are normalized so lake never deletes/reclones the shared checkout.
2. **`lake exe cache get!`** — downloads mathlib's cloud oleans for the pinned
   rev into the shared checkout. `!` = fail if anything is missing (mathlib is
   NEVER rebuilt from source).
3. **`lake build`** — replays the project's own modules only
   (~8k modules in minutes, mathlib free). Env: `LEAN_SHARED_CACHE_ROOT` (+nix
   `LEAN_SYS_ROOT` when configured) so every lake shares one lakedir.
4. **proof gate** — gokujo scan counts theorems/sorries.
5. **nix packaging** — `nix store add-path` of the shared mathlib
   `.lake/build/lib/lean` (content-addressed, no rebuild); path saved to
   `mathlib-nix-store.txt` in the published dir.
6. **sign + publish** — report signed with ssh-keygen SSHSIG (namespace
   `aristotle-manager`), written to
   `/mnt/data1/lake-cache/www/aristotle-builds/<uuid>/`
   (`build-report.json`, `.sig`, `build.log`, `index.html`).

Build failure in a project is NOT a deploy failure: the report is still
published with `ok: false` (reports are for agents auditing proofs).

## 10-newest batch (2026-09-25 run)

```bash
# select newest project dirs that have output-final_aristotle/lakefile.*
ls -t /mnt/data1/aristotle-results | head -60   # filter for lakefile
```

**Use the sequential wrapper** — `scripts/publish-recent-seq.sh` (in
`~/projects/arist`): publishes one project at a time, deletes the ~700M build
workspace after each report lands in the web root, skips already-published
projects, aborts if /mnt/data1 has <2G free, and verifies every signature at
the end. /mnt/data1 runs near-full, so parallel batch runs fill the disk and
die; sequential + cleanup is the only safe mode.

Two result layouts exist and the deploy code handles both (see
`deploy_one` id extraction):
- `<uuid>_aristotle/output-final_aristotle` — id from the `_aristotle` suffix
- `<uuid>/output-final_aristotle` (bare uuid dir) — id falls back to the
  nearest bare-UUID ancestor; without that fix every project shared ONE
  workspace named `output-final`, mixing stale sources across projects.

## Deploy to the web tile (systemd/system-manager)

```bash
./scripts/deploy-build-tile.sh   # in aristotle-manager repo
```

Does: verify web-root content exists → `chmod -R a+rX` → commit
`nginx/static.conf` in `~/projects/system-manager` → `nix build` the
system-manager flake → sudo `<store-path>/bin/activate`. nginx then serves
the tile at `/aristotle-builds/`. Check with:

```bash
systemctl status nginx
curl -sI localhost/aristotle-builds/ | head -3
```

## Gotchas (learned the hard way)

- **Stale `.sig`**: `ssh-keygen -Y sign` prompts when the signature file
  exists; with no stdin it aborts and leaves the OLD sig — which then fails
  verification against the rewritten report. Fixed in `signing.rs::cmd_sign`
  (removes the sig before signing). If you sign files by hand, `rm -f` the
  `.sig` first.
- **Don't `find` the results tree**: nested project dirs contain multi-GB
  `.lake`/git trees. The rust walkers in `cache.rs` (dedup/gc) skip dot-dirs
  and never follow symlinks — 2,336 projects scan in ~1s.
- **gc is safe now**: it compares *revision dirs* (leaf paths) against active
  symlink targets, canonicalized on both sides. Older versions compared the
  wrong depth and would delete live shared checkouts.
- **Disk**: /mnt/data1 runs near-full (results trees ~6.9T). A single build
  workspace costs ~700M — always clean it after the report is published
  (`publish-recent-seq.sh` does this). `cache prune --dry-run` first,
  `--execute` after reviewing.
- **Detached jobs**: run long batches with
  `setsid nohup CMD > log 2>&1 < /dev/null & disown` — plain `&` dies when
  the launching shell exits.
- **elan required on PATH** for `lake`; the gokujo binary is the
  zero-package-manager fallback path (signed, bundled toolchain).

## Where the code lives (aristotle-manager)

- `src/cache.rs` — link_project/adopt/dedup/prune/gc/init
- `src/deploy.rs` — the publish pipeline (link → cache get! → build → gate → nix → sign)
- `src/signing.rs` — SSHSIG sign/verify, `allowed_signers` in
  `~/.config/aristotle-manager/signing/`
- `src/toolchain.rs` — gokujo bootstrap/bundle, `run_cmd`
- `Makefile` — publish-n / tile-deploy / cache-status targets
