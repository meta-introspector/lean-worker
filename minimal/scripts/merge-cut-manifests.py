#!/usr/bin/env python3
"""merge-cut-manifests.py — combine per-project cut manifests into one.

Usage: merge-cut-manifests.py OUTDIR OUT.json

Reads every *.json in OUTDIR (except OUT.json and anything without
kind == 'cut-manifest'), concatenates the project lists, and recomputes
the totals. Output matches `gokujo cut` corpus format.
"""
import json
import os
import sys


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    outdir, outpath = sys.argv[1], sys.argv[2]
    projects = []
    gokujo = None
    for fn in sorted(os.listdir(outdir)):
        if not fn.endswith(".json") or os.path.abspath(fn and os.path.join(outdir, fn)) == os.path.abspath(outpath):
            continue
        try:
            m = json.load(open(os.path.join(outdir, fn)))
        except json.JSONDecodeError:
            continue
        if m.get("kind") != "cut-manifest":
            continue
        gokujo = gokujo or m.get("gokujo")
        projects.extend(m.get("projects", []))

    totals = {
        "projects": len(projects),
        "files": sum(p["files"] for p in projects),
        "unique_files": sum(p["unique_files"] for p in projects),
        "decls": sum(p["decls"] for p in projects),
        "holes": sum(p["holes"] for p in projects),
    }
    out = {"gokujo": gokujo or "1.0.0", "kind": "cut-manifest",
           "projects": projects, "total": totals}
    with open(outpath, "w") as f:
        json.dump(out, f)
        f.write("\n")
    print(f"merged {len(projects)} projects: {totals}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
