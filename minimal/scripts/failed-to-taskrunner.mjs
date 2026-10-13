#!/usr/bin/env node
// failed-to-taskrunner.mjs — bridge bone-worker failures into dotagents task-runner tasks.
//
// The knife (gokujo check) proves what compiles clean mechanically. When it
// FAILS, the tail says why: "has a hole" (sorry) or "trusts the evaluator"
// (disallowed axiom). Those are exactly the jobs an LLM agent can do and the
// knife cannot — so this script converts them into task directories that
// `task-runner run` can pick up.
//
// Grouping: one task per source FILE (not per obligation — an agent works a
// file's holes together; they share imports and context). Each task's
// SYSTEM.md carries the obligation list with line numbers and digests.
//
// Usage:
//   node failed-to-taskrunner.mjs [--results FILE] [--manifest FILE]
//        [--tasks-dir DIR] [--max N] [--create] [--agent pi]
//
//   --results   bone-worker results.jsonl   (default /var/lib/bone-worker/results.jsonl)
//   --manifest   where to write the batch-create manifest
//               (default <results dir>/taskrunner-manifest.json)
//   --tasks-dir  passed to task-runner (default ~/dotagents/tasks)
//   --max        cap tasks per run (default 40; re-run to continue)
//   --create     actually invoke `task-runner batch-create` (default: manifest only)
//   --agent      agent for the tasks (default pi)
//
// Idempotent: task names are derived from project+file, so a second run
// skips already-created tasks (batch-create reports "already exists").
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { join, dirname, basename } from 'node:path';
import { homedir } from 'node:os';
import { spawnSync } from 'node:child_process';

const argv = process.argv.slice(2);
const opt = (n, d) => { const i = argv.indexOf(n); return i >= 0 ? argv[i + 1] : d; };

const RESULTS = opt('--results', '/var/lib/bone-worker/results.jsonl');
const MANIFEST = opt('--manifest', join(dirname(RESULTS), 'taskrunner-manifest.json'));
const TASKS_DIR = opt('--tasks-dir', join(homedir(), 'dotagents/tasks'));
const MAX = Number(opt('--max', 40));
const CREATE = argv.includes('--create');
const AGENT = opt('--agent', 'pi');

if (!existsSync(RESULTS)) { console.error(`no results file at ${RESULTS}`); process.exit(2); }

// ── 1. group failed obligations by source file ────────────────────────────
const byFile = new Map();
for (const line of readFileSync(RESULTS, 'utf8').split('\n').filter(Boolean)) {
  let r; try { r = JSON.parse(line); } catch { continue; }
  if (r.status !== 'failed') continue;
  if (!r.path) continue;
  if (!byFile.has(r.path)) byFile.set(r.path, []);
  byFile.get(r.path).push(r);
}

// heaviest files first (most obligations = most valuable to an agent session)
const files = [...byFile.entries()]
  .map(([path, rs]) => ({
    path,
    project: rs[0].project ?? 'unknown',
    obligations: rs.sort((a, b) => (a.line ?? 0) - (b.line ?? 0)),
    weight: rs.reduce((s, r) => s + (r.weight ?? 1), 0),
  }))
  .sort((a, b) => b.weight - a.weight);

console.log(`${files.length} files with failed obligations; taking up to ${MAX}`);

// ── 2. manifest entries ───────────────────────────────────────────────────
const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 30);
const proj6 = (p) => (p.match(/[0-9a-f]{6}/) ?? ['unknwn'])[0];

const entries = files.slice(0, MAX).map((f) => {
  const holes = f.obligations.map((o) => {
    const decl = o.job?.proveGoal?.[1] ?? basename(o.path);
    const kind = /has a hole/.test(o.tail ?? '') ? 'hole'
      : /trusts the evaluator/.test(o.tail ?? '') ? 'evaluator-axiom' : 'check-failed';
    return `  - L${o.line ?? '?'} \`${decl}\` — ${kind} (jobId ${o.jobId}, weight ${o.weight ?? 1})`;
  }).join('\n');
  const name = `bone-${proj6(f.project)}-${slug(basename(f.path, '.lean'))}`;
  const description = [
    `Prove the failed bone obligations in ${f.path} (project ${f.project}).`,
    `The gokujo knife failed this file with ${f.obligations.length} obligation(s):`,
    holes,
    ``,
    `Method: open the file, read each theorem with a hole, replace \`sorry\` with a real proof.`,
    `For "trusts the evaluator" obligations, remove the \`native_decide\`/\`decide\`-style axiom trust and prove the claim properly.`,
    `Verify with: cd ${dirname(f.path)} && ${join(homedir(), 'projects/lean-worker/minimal/gokujo')} check ${basename(f.path)}`,
    `Exit 0 discharges all obligations in the file.`,
  ].join('\n');
  return {
    name,
    description,
    goap_atom: 'has_bone_proof',
    agent: AGENT,
    tools: ['lean4', 'gokujo'],
  };
});

writeFileSync(MANIFEST, JSON.stringify(entries, null, 1));
console.log(`wrote ${entries.length} entries -> ${MANIFEST}`);

// ── 3. optional: hand to task-runner ───────────────────────────────────────
if (CREATE) {
  const r = spawnSync('task-runner', ['batch-create', '-m', MANIFEST, '--tasks-dir', TASKS_DIR],
    { stdio: 'inherit' });
  process.exit(r.status ?? 1);
} else {
  console.log(`dry run — pass --create to invoke: task-runner batch-create -m ${MANIFEST} --tasks-dir ${TASKS_DIR}`);
}
