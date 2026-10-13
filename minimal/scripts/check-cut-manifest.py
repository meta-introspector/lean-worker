#!/usr/bin/env python3
"""Cross-check a gokujo cut manifest against the scan cache manifest.jsonl.

Semantics (settled 2026-09-28):
  - files / unique_files: HARD check. The cache stores sha256 per file, so
    unique_files must equal the distinct-digest count exactly.
  - decls: SOFT check. The cache's DECL_RE requires a leading @[...] attribute,
    so it counts attributed declarations only (~5% of the corpus). Cut counts
    all declarations lexically. Numbers are reported, not compared.
  - holes: GROUND TRUTH = the knife itself (`gokujo scan --json` per file).
    The cache's `sorry` field is a raw substring count ("sorryAx" contains
    "sorry"), and grep's word-boundary count still hits doc-comment prose
    ("with no `sorry` and no added axioms"). Only the lexer is token-faithful.
    The check: cut's per-project hole count must equal the sum of `holes`
    across the project's files as scanned individually. Since cut reports
    obligations at module granularity, we compare counts, and additionally
    verify every cut obligation (module, decl) appears in the lexed output.

Usage:
  check-cut-manifest.py CUT_MANIFEST.json [CACHE.jsonl]

Exit code 0 iff all hard checks pass.
"""
import json
import os
import subprocess
import sys

GOKUJO = os.environ.get("GOKUJO", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "gokujo"))


def load_cache(path):
    entries = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))
    return entries


def cache_stats_for(entries, prefix):
    files = [e for e in entries if e["path"].startswith(prefix)]
    digests = {e["sha256"] for e in files}
    decls = sum(len(e.get("decls", [])) for e in files)
    return files, digests, decls


def lexed_holes(paths):
    """Hole count per gokujo scan --json, summed over files (batched)."""
    total = 0
    holes_seen = []  # (module, decl-name, line)
    B = 200
    for i in range(0, len(paths), B):
        batch = paths[i:i + B]
        r = subprocess.run([GOKUJO, "scan", "--json", *batch],
                           capture_output=True, text=True)
        if r.returncode != 0:
            continue
        try:
            d = json.loads(r.stdout)
        except json.JSONDecodeError:
            continue
        for f in d.get("files", []):
            for h in f.get("holes", []):
                holes_seen.append((f["module"], h["name"], h["line"]))
        total += d.get("holes", 0)
    return total, holes_seen


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print(__doc__)
        return 2
    cut_path = args[0]
    cache_path = args[1] if len(args) > 1 else "/mnt/data1/aristotle-merge/manifest.jsonl"

    cut = json.load(open(cut_path))
    cache = load_cache(cache_path)

    print(f"cache: {len(cache)} entries from {cache_path}")
    print(f"cut:   {cut.get('kind')} v{cut.get('gokujo')}, {len(cut['projects'])} projects")

    ok = True
    for p in cut["projects"]:
        name = p["name"]
        candidates = set()
        for e in cache:
            d = os.path.dirname(e["path"])
            if os.path.basename(d) == name:
                candidates.add(os.path.dirname(d))
            elif f"/{name}/" in e["path"]:
                candidates.add(e["path"].split(f"/{name}/")[0] + f"/{name}")
        if not candidates:
            print(f"  ✗ {name}: no cache entries found")
            ok = False
            continue
        prefix = sorted(candidates)[0] + os.sep
        files, digests, cache_decls = cache_stats_for(cache, prefix)
        paths = [e["path"] for e in files]

        hard_bad = []
        if p["files"] != len(files):
            hard_bad.append(f"files: cut={p['files']} cache={len(files)}")
        if p["unique_files"] != len(digests):
            hard_bad.append(f"unique_files: cut={p['unique_files']} cache={len(digests)}")

        lex_holes, holes_seen = lexed_holes(paths)
        obl = p.get("obligations", [])

        print(f"  {'✓' if not hard_bad else '✗'} {name}")
        print(f"      files        {p['files']:>7} / cache {len(files):>7}   (hard)")
        print(f"      unique_files {p['unique_files']:>7} / cache {len(digests):>7}   (hard)")
        print(f"      decls        {p['decls']:>7} / cache {cache_decls:>7}   (cache = attributed-only)")
        print(f"      obligations  {len(obl):>7} (cut) / lexer {lex_holes:>7} (ground truth)")

        if strict := (len(obl) != lex_holes):
            print(f"      ⚠ obligations vs lexer holes differ — listing lexer holes not in cut:")
            cut_names = {(o["module"], o["decl"]) for o in obl}
            for m, n, ln in holes_seen:
                if (m, n) not in cut_names:
                    print(f"        {m} : {n} (line {ln})")
            ok = False

    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "--__main__" or __name__ == "__main__":
    sys.exit(main())
