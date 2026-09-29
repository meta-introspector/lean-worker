#!/usr/bin/env python3
"""coverage-report.py — proof coverage report for the bone mesh.

Joins the workers' results.jsonl (bone-worker.mjs output) against the bones
(obligations.jsonl per project) and prints, per project and in total:

  obligations   unique (digest, decl) obligations the mesh has to discharge
  claimed       with a claim recorded (in state.json ledgers, if provided)
  proved        gokujo check exit 0 (file compiles, no reachable sorry)
  failed        attempted but the knife refused
  pending       not yet attempted
  twin_weight   corpus instances discharged by the proved obligations
  coverage      proved twin_weight / total twin_weight

Usage:
  coverage-report.py BONES_ROOT [--results RESULTS.jsonl]... [--json OUT]

Exit code 0 iff total coverage is 100%.
"""
import argparse
import glob
import json
import os
import sys
from collections import defaultdict


def load_results(paths):
    by_id = {}
    for p in paths:
        if not os.path.exists(p):
            continue
        with open(p) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    r = json.loads(line)
                except json.JSONDecodeError:
                    continue
                by_id[r["jobId"]] = r   # newest wins
    return by_id


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("bones_root")
    ap.add_argument("--results", action="append", default=[],
                    help="results.jsonl (repeatable; also accepts a directory)")
    ap.add_argument("--json", dest="json_out", help="also write the report as JSON")
    args = ap.parse_args()

    results = args.results or ["/var/lib/bone-worker/results.jsonl"]
    files = []
    for p in results:
        if os.path.isdir(p):
            files.extend(glob.glob(os.path.join(p, "**", "results.jsonl"), recursive=True))
        else:
            files.append(p)
    done = load_results(files)

    projects = sorted(d for d in os.listdir(args.bones_root)
                      if d != "ALL" and os.path.isfile(
                          os.path.join(args.bones_root, d, "obligations.jsonl")))

    rows = []
    total = dict(obligations=0, proved=0, failed=0, pending=0,
                 weight=0, proved_weight=0)
    for proj in projects:
        obls = [json.loads(l) for l in
                open(os.path.join(args.bones_root, proj, "obligations.jsonl")) if l.strip()]
        c = dict(obligations=len(obls), proved=0, failed=0, pending=0,
                 weight=0, proved_weight=0)
        for o in obls:
            c["weight"] += o.get("weight", 1)
            r = done.get(o["id"])
            if r is None:
                c["pending"] += 1
            elif r.get("status") == "proved":
                c["proved"] += 1
                c["proved_weight"] += o.get("weight", 1)
            else:
                c["failed"] += 1
        c["coverage"] = (c["proved_weight"] / c["weight"]) if c["weight"] else 1.0
        for k in total:
            total[k] += c[k]
        rows.append((proj, c))

    print(f"{'project':<44} {'obl':>5} {'ok':>5} {'fail':>5} {'pend':>5} "
          f"{'weight':>7} {'cov%':>6}")
    for proj, c in rows:
        print(f"{proj[:43]:<44} {c['obligations']:>5} {c['proved']:>5} "
              f"{c['failed']:>5} {c['pending']:>5} {c['weight']:>7} "
              f"{100 * c['coverage']:>5.1f}")
    tw = total["weight"] or 1
    print("-" * 84)
    print(f"{'TOTAL':<44} {total['obligations']:>5} {total['proved']:>5} "
          f"{total['failed']:>5} {total['pending']:>5} {total['weight']:>7} "
          f"{100 * total['proved_weight'] / tw:>5.1f}")

    if args.json_out:
        out = {
            "total": {**total, "coverage": total["proved_weight"] / tw},
            "projects": {p: c for p, c in rows},
        }
        with open(args.json_out, "w") as f:
            json.dump(out, f, indent=1)
            f.write("\n")
    return 0 if total["proved_weight"] == total["weight"] else 1


if __name__ == "__main__":
    sys.exit(main())
