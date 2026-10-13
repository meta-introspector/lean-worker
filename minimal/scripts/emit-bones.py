#!/usr/bin/env python3
"""emit-bones.py — carve cut projects into launchpad bones.

Single project:
    emit-bones.py PROJECT_DIR [--cache manifest.jsonl] [--out BONES_ROOT]

Whole corpus (one cache load, one lex pass, per-project bones + aggregate):
    emit-bones.py CORPUS_ROOT --all [--cache manifest.jsonl] [--out BONES_ROOT]

Output per project: <out>/<project>/ with
  specs.jsonl       one per UNIQUE file (content-addressed by sha256):
                    {id, digest, module, path, imports, decls, lines, bytes}
  twins.jsonl       one duplicate group (same digest, >1 file):
                    {id, digest, canonical, members, n}
  obligations.jsonl one hole per UNIQUE (digest, decl) — the theorems the
                    proof workers actually get handed:
                    {id, project, module, decl, kind, line, digest, path, weight}
  summary.json      counts + internal consistency check

In --all mode also writes <out>/ALL/summary.json with corpus totals.

Holes come from the knife itself (`gokujo scan --json`), the token-faithful
ground truth (a `sorry` in a comment is not a sorry). Twins collapse: an
obligation present in N twin files is one obligation with weight N.

Gotcha: gokujo's scan digest (16 hex) is NOT the cache's sha256 (64 hex).
Joins go through the canonical file's realpath, never across digest spaces.

Counts cross-check against `gokujo cut`:
  len(specs) == unique_files
  twin_members + singletons == files
  cut obligations / weight = corpus instances
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


def bone_id(prefix, *parts):
    h = hashlib.sha256("\x1f".join(parts).encode()).hexdigest()[:16]
    return f"{prefix}_{h}"


def load_cache(path):
    entries = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))
    return entries


def project_of(path, corpus_root):
    """Project name = first path component under corpus_root, else None."""
    try:
        rel = os.path.relpath(os.path.realpath(path), corpus_root)
    except ValueError:
        return None
    top = rel.split(os.sep, 1)[0]
    return None if top in (".", "..") else top


def group_by_digest(entries):
    by_digest = {}
    for e in sorted(entries, key=lambda e: e["path"]):
        by_digest.setdefault(e["sha256"], []).append(e)
    return by_digest


def lex_canonicals(paths, project_root):
    """realpath -> {holes, module, rel}, via gokujo scan --json.

    Keyed by path because gokujo's own digest (16 hex chars) is not the
    cache's sha256 (64 hex chars) — the two must not be joined.
    """
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
            by_path[p] = {"holes": f.get("holes", []),
                          "module": f["module"],
                          "rel": os.path.relpath(p, project_root)}
    return by_path


def write_bones(project, entries, corpus_root, outdir, lexed):
    """Write one project's bone files. `lexed` maps canonical realpath ->
    lexed info for every canonical in this project. Returns summary dict."""
    root = os.path.realpath(corpus_root).rstrip(os.sep) + os.sep
    os.makedirs(outdir, exist_ok=True)

    by_digest = group_by_digest(entries)
    digests = sorted(by_digest)

    def rel_module(e):
        return os.path.realpath(e["path"])[len(root):-5].replace(os.sep, ".")

    specs = 0
    with open(os.path.join(outdir, "specs.jsonl"), "w") as f:
        for dg in digests:
            e = by_digest[dg][0]
            f.write(json.dumps({
                "id": bone_id("spec", dg),
                "digest": dg,
                "module": rel_module(e),
                "path": e["path"],
                "imports": e.get("imports", []),
                "decls": e.get("decls", []),
                "lines": e.get("lines"),
                "bytes": e.get("bytes"),
            }) + "\n")
            specs += 1

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

    obligations = 0
    with open(os.path.join(outdir, "obligations.jsonl"), "w") as f:
        for dg in digests:
            lx = lexed.get(os.path.realpath(by_digest[dg][0]["path"]))
            if not lx:
                continue
            members = by_digest[dg]
            for h in lx["holes"]:
                f.write(json.dumps({
                    "id": bone_id("obl", dg, h["name"]),
                    "project": project,
                    "module": rel_module(members[0]),
                    "decl": h["name"],
                    "kind": h.get("kind"),
                    "line": h.get("line"),
                    "digest": dg,
                    "path": members[0]["path"],
                    "weight": len(members),
                }) + "\n")
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
    summary["consistent"] = (specs == len(digests)
                             and twin_members + singletons == len(entries))
    with open(os.path.join(outdir, "summary.json"), "w") as f:
        json.dump(summary, f, indent=1)
        f.write("\n")
    return summary


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", help="project dir, or corpus root with --all")
    ap.add_argument("--all", action="store_true",
                    help="carve every project under CORPUS_ROOT")
    ap.add_argument("--cache", default="/mnt/data1/aristotle-merge/manifest.jsonl")
    ap.add_argument("--out", default="/mnt/data1/aristotle-merge/bones")
    args = ap.parse_args()

    print("loading cache…", file=sys.stderr)
    cache = load_cache(args.cache)
    print(f"cache: {len(cache)} entries", file=sys.stderr)

    corpus_root = os.path.dirname(os.path.realpath(args.root).rstrip(os.sep)) \
        if not args.all else os.path.realpath(args.root)

    # group entries per project
    projects = {}
    for e in cache:
        if not os.path.exists(e["path"]):
            continue
        p = project_of(e["path"], corpus_root)
        if p is None:
            continue
        # single-project mode: only the named project
        if not args.all:
            name = os.path.basename(os.path.realpath(args.root).rstrip(os.sep))
            if p != name:
                continue
        projects.setdefault(p, []).append(e)

    if not args.all:
        name = os.path.basename(os.path.realpath(args.root).rstrip(os.sep))
        if name not in projects:
            print(f"no cache entries under {args.root}", file=sys.stderr)
            return 1
        projects = {name: projects[name]}

    print(f"{len(projects)} projects", file=sys.stderr)

    # one lex pass over all canonicals, batched per project (keeps memory sane)
    totals = {"projects": len(projects), "files": 0, "unique_files": 0,
              "specs": 0, "twin_groups": 0, "twin_members": 0,
              "singletons": 0, "obligations": 0}
    failures = []
    for n, (project, entries) in enumerate(sorted(projects.items()), 1):
        root = os.path.realpath(corpus_root).rstrip(os.sep) + os.sep
        by_digest = group_by_digest(entries)
        canonicals = [v[0]["path"] for v in by_digest.values()]
        lexed = lex_canonicals(canonicals, root)
        summary = write_bones(project, entries, corpus_root,
                              os.path.join(args.out, project), lexed)
        totals["files"] += summary["files"]
        totals["unique_files"] += summary["unique_files"]
        totals["specs"] += summary["specs"]
        totals["twin_groups"] += summary["twin_groups"]
        totals["twin_members"] += summary["twin_members"]
        totals["singletons"] += summary["singletons"]
        totals["obligations"] += summary["obligations"]
        if not summary["consistent"]:
            failures.append(project)
        print(f"[{n}/{len(projects)}] {project}: "
              f"{summary['files']} files, {summary['unique_files']} unique, "
              f"{summary['obligations']} obligations", flush=True)

    if args.all:
        os.makedirs(os.path.join(args.out, "ALL"), exist_ok=True)
        with open(os.path.join(args.out, "ALL", "summary.json"), "w") as f:
            json.dump(totals, f, indent=1)
            f.write("\n")

    print(json.dumps(totals, indent=1))
    if failures:
        print("INCONSISTENT:", ", ".join(failures[:10]), file=sys.stderr)
    print("PASS" if not failures else "FAIL", f"→ {args.out}")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
