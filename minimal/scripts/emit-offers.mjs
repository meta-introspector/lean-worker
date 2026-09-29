#!/usr/bin/env node
// emit-offers.mjs — map bones obligations.jsonl onto P2P mesh offer messages.
//
// Each obligations.jsonl line becomes one offer job shaped exactly like
// Protocol/Core.lean's `P2P.Job.proveGoal (moduleName declName) (sourceDigest)`:
//
//   { kind: 'offer',
//     jobId,                                  // the obligation's bone id
//     job: { proveGoal: [module, decl, sourceDigest] },
//     sourceDigestHex,                        // sha256, for humans + checkProof
//     weight,                                 // twin count: prove once, discharge N
//     project, path, kind, line }
//
// Digest → Nat: Lean's `Digest := Nat`; we take the first 16 hex chars of the
// sha256 as a Nat (fits far below 2^64, keeps message payloads small).
//
// Usage:
//   node emit-offers.mjs BONES_ROOT [--out offers.jsonl] [--project NAME] [--min-weight N]
//
// Output: JSONL, one offer per line, heaviest obligations first.
import { readFileSync, writeFileSync, mkdirSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const argv = process.argv.slice(2);
const root = argv[0];
if (!root) { console.error('usage: node emit-offers.mjs BONES_ROOT [--out f] [--project NAME] [--min-weight N]'); process.exit(2); }
const opt = (name) => { const i = argv.indexOf(name); return i >= 0 ? argv[i + 1] : undefined; };
const onlyProject = opt('--project');
const minWeight = Number(opt('--min-weight') ?? 1);
const out = opt('--out') ?? join(root, 'offers.jsonl');

function listProjectDirs(r) {
  return readdirSync(r).filter((d) => {
    if (d === 'ALL') return false;
    const p = join(r, d);
    return statSync(p).isDirectory() && statSync(join(p, 'obligations.jsonl')).isFile();
  });
}

const hexToNat = (h) => BigInt('0x' + h.slice(0, 16));   // ≤ 2^64
const projects = onlyProject ? [onlyProject] : listProjectDirs(root);

const offers = [];
for (const project of projects) {
  const lines = readFileSync(join(root, project, 'obligations.jsonl'), 'utf8')
    .split('\n').filter(Boolean);
  for (const line of lines) {
    const o = JSON.parse(line);
    if (o.weight < minWeight) continue;
    offers.push({
      kind: 'offer',
      jobId: o.id,
      job: { proveGoal: [o.module, o.decl, hexToNat(o.digest).toString()] },
      sourceDigestHex: o.digest,
      weight: o.weight,
      project: o.project,
      path: o.path,
      declKind: o.kind,
      line: o.line,
    });
  }
}
offers.sort((a, b) => b.weight - a.weight || a.jobId.localeCompare(b.jobId));

mkdirSync(join(out, '..'), { recursive: true });
writeFileSync(out, offers.map((o) => JSON.stringify(o)).join('\n') + (offers.length ? '\n' : ''));

console.log(`projects:    ${projects.length}`);
console.log(`offers:      ${offers.length}`);
console.log(`total weight:${offers.reduce((s, o) => s + o.weight, 0)}`);
console.log(`wrote ${out}`);
