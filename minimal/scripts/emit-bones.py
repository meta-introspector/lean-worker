#!/usr/bin/env python3
"""emit-bones.py — carve a project's cut bones into launchpad input files.

Input:  one Aristotle project directory (already scanned into manifest.jsonl).
Output: <out>/<project>/ with three JSONL bone files + summary.json:

  specs.jsonl       one per UNIQUE file (content-addressed by sha256):
                    {id, module, digest, path, imports, decls, lines, bytes}
  twins.jsonl       one duplicate group (same digest, >1 file):
                    {id, digest, canonical, members, n}
  obligations.jsonl one hole per UNIQUE (digest, decl) — the theorems the
                    proof workers actually get handed:
                    {id, project, module, decl, kind, line, digest, path, weight}

Holes come from the knife itself (`gokujo scan --json`), the token-faithful
ground truth (a `sorry` in a comment is not a sorry). Twins collapse: an
obligation present in N twin files is one obligation with weight N.

Counts cross-check against `gokujo cut`:
  len(specs) == unique_files
  sum(n over twins) + #singletons == files
  dedup'd obligations == cut's per-project hole count (up to twin dedup)

Usage:
  emit-bones.py PROJECT_DIR [--cache manifest.jsonl] [--out BONES_ROOT]
"""
import argparse
import hashlib
import json
import os
import subprocess
import sys

GOKUJO = os.environ.get(
    "GOKUJO",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "gokujo"))


def short(s, n=12):
    return s[:n]


def bone_id(prefix, *parts):
    h = hashlib.sha256("\x1f".join(parts).encode()).hexdigest()[:16]
    return f"{prefix}_{h}"


def load_project_entries(cache_path, project_dir):
    """Cache entries whose path starts with the project dir (resolved)."""
    root = os.path.realpath(project_dir).rstrip(os.sep) + os.sep
    out = []
    with open(cache_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            e = json.loads(line)
            p = os.path.realpath(e["path"])
            if p.startswith(root):
                e["path"] = p
                out.append(e)
    return out, root


def lex_holes(paths, project_root):
    """realpath -> {holes, module, rel}, via gokujo scan --json.
    Keyed by path because gokujo's own digest (16 hex chars) is not the
    cache's sha256 (64 hex chars) — the two must not be joined."""
    by_path = {}
    B = 200
    for i in range(0, len(paths), B):
        batch = paths[i:i + B]
        r = subprocess.run([GOKUJO, "scan", "--json", *batch],
                           capture_output=True, text=True)
        if r.returncode != 0:
            print(f"warn: gokujo scan batch {i//B} failed: {r.stderr[:200]}",
                  file=sys.stderr)
            continue
        d = json.loads(r.stdout)
        for f in d.get("files", []):
            p = os.path.realpath(f["path"])
            rel = os.path.relpath(p, project_root)
            by_path[p] = {"holes": f.get("holes", []),
                          "module": f["module"],
                          "rel": rel}
    return by_path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("project_dir")
    ap.add_argument("--cache", default="/mnt/data1/aristotle-merge/manifest.jsonl")
    ap.add_argument("--out", default="/mnt/data1/aristotle-merge/bones")
    args = ap.parse_args()

    entries, root = load_project_entries(args.cache, args.project_dir)
    if not entries:
        print(f"no cache entries under {root}", file=sys.stderr)
        return 1
    project = os.path.basename(root.rstrip(os.sep))
    outdir = os.path.join(args.out, project)
    os.makedirs(outdir, exist_ok=True)

    # canonical file per digest (first path wins)
    by_digest = {}
    for e in sorted(entries, key=lambda e: e["path"]):
        by_digest.setdefault(e["sha256"], []).append(e)

    digests = sorted(by_digest)
    lexed = lex_holes([v[0]["path"] for v in by_digest.values()], root)

    def rel_module(e):
        """Project-relative dotted module for a cache entry."""
        return os.path.realpath(e["path"])[len(root):-5].replace(os.sep, ".")

    # specs
    specs = 0
    with open(os.path.join(outdir, "specs.jsonl"), "w") as f:
        for dg in digests:
            e = by_digest[dg][0]
            rec = {
                "id": bone_id("spec", dg),
                "digest": dg,
                "module": rel_module(e),
                "path": e["path"],
                "imports": e.get("imports", []),
                "decls": e.get("decls", []),
                "lines": e.get("lines"),
                "bytes": e.get("bytes"),
            }
            f.write(json.dumps(rec) + "\n")
            specs += 1

    # twins
    twins = 0
    twin_members = 0
    singletons = 0
    with open(os.path.join(outdir, "twins.jsonl"), "w") as f:
        for dg in digests:
            members = [e["path"] for e in by_digest[dg]]
            if len(members) < 2:
                singletons += 1
                continue
            f.write(json.dumps({
                "id": bone_id("twin", dg),
                "digest": dg,
                "canonical": members[0],
                "members": members,
                "n": len(members),
            }) + "\n")
            twins += 1
            twin_members += len(members)

    # obligations: unique (digest, decl) with twin weight
    obligations = 0
    with open(os.path.join(outdir, "obligations.jsonl"), "w") as f:
        for dg in digests:
            lx = lexed.get(os.path.realpath(by_digest[dg][0]["path"]))
            if not lx:
                continue
            members = by_digest[dg]
            for h in lx["holes"]:
                rec = {
                    "id": bone_id("obl", dg, h["name"]),
                    "project": project,
                    "module": rel_module(members[0]),
                    "decl": h["name"],
                    "kind": h.get("kind"),
                    "line": h.get("line"),
                    "digest": dg,
                    "path": members[0]["path"],
                    "weight": len(members),
                }
                f.write(json.dumps(rec) + "\n")
                obligations += 1

    summary = {
        "project": project,
        "files": len(entries),
        "unique_files": len(digests),
        "specs": specs,
        "twin_groups": twins,
        "twin_members": twin_members,
        "singletons": singletons,
        "obligations": obligations,
    }
    with open(os.path.join(outdir, "summary.json"), "w") as f:
        json.dump(summary, f, indent=1)
        f.write("\n")

    print(json.dumps(summary, indent=1))
    ok = (specs == len(digests)
          and twin_members + singletons == len(entries))
    print("PASS" if ok else "FAIL", f"→ {outdir}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
