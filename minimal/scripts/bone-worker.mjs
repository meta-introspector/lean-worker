#!/usr/bin/env node
// bone-worker.mjs — a launchpad proof worker: claim bone obligations, run the knife.
//
// Loop (one poll per POLL_SECONDS):
//   1. Load offers.jsonl (emit-offers.mjs output). Skip jobIds already in state.
//   2. Pick the heaviest unclaimed offer (weight desc, jobId asc — same order
//      as emit-offers). Record it in state.json BEFORE work starts (claim
//      survives a crash), and announce the claim via control gossip if peers
//      are configured.
//   3. Work = the knife, in order:
//        a. gokujo check <file>   — scan+graph+build+sorry+axioms as one gate
//        b. record outcome in results.jsonl: proved | failed | check-failed
//   4. Sleep, repeat. SIGTERM/SIGINT set a flag; the worker exits cleanly
//      between jobs (systemd restarts are safe — state.json is the ledger).
//
// Offers shape (emit-offers.mjs):
//   { kind:'offer', jobId, job:{proveGoal:[module, decl, digestNat]},
//     sourceDigestHex, weight, project, path, declKind, line }
//
// Env:
//   BONES_ROOT       where offers.jsonl lives        (default /mnt/data1/aristotle-merge/bones)
//   STATE_DIR        where state.json/results go     (default /var/lib/bone-worker)
//   POLL_SECONDS     idle poll interval              (default 30)
//   JOB_TIMEOUT_SECONDS  per-job knife timeout       (default 3600)
//   CONTROL_PEERS    comma-separated peer base URLs  (optional; enables gossip)
//   CONTROL_TOKEN    shared x-control-token          (optional)
//   NODE_ID          this worker's peer id           (default hostname)
//
// The offer file is the local stand-in for the P2P offer channel; the job
// payload is byte-compatible with Protocol/Core.lean's Job.proveGoal, so the
// same record can be gossiped with lib/control.mjs's announce/claim when the
// mesh goes live.
import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync, existsSync, mkdirSync, appendFileSync, renameSync, statfsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { hostname } from 'node:os';

const GOKUJO = process.env.GOKUJO || join(import.meta.dirname, '..', 'gokujo');
const BONES_ROOT = process.env.BONES_ROOT || '/mnt/data1/aristotle-merge/bones';
const STATE_DIR = process.env.STATE_DIR || '/var/lib/bone-worker';
const POLL_SECONDS = Number(process.env.POLL_SECONDS || 30);
const JOB_TIMEOUT_MS = Number(process.env.JOB_TIMEOUT_SECONDS || 3600) * 1000;
const NODE_ID = process.env.NODE_ID || hostname();
const OFFERS = join(BONES_ROOT, 'offers.jsonl');
const STATE_FILE = join(STATE_DIR, 'state.json');
const RESULTS = join(STATE_DIR, 'results.jsonl');
// Refuse to start a job when the source filesystem is nearly full: the knife's
// build stage writes oleans for the whole import closure next to the source.
const MIN_FREE_BYTES = Number(process.env.MIN_FREE_GB || 5) * 1024 ** 3;

let stopping = false;
for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => { stopping = true; console.log(`${ts()} ${sig} — will stop after this job`); });
}

const ts = () => new Date().toISOString();

function loadState() {
  if (existsSync(STATE_FILE)) {
    try { return JSON.parse(readFileSync(STATE_FILE, 'utf8')); } catch { /* corrupt: restart ledger */ }
  }
  return { node: NODE_ID, claims: {}, startedAt: ts() };
}

function saveState(s) {
  const tmp = STATE_FILE + '.tmp';
  writeFileSync(tmp, JSON.stringify(s, null, 1));
  renameSync(tmp, STATE_FILE);
}

function loadOffers() {
  if (!existsSync(OFFERS)) return [];
  return readFileSync(OFFERS, 'utf8').split('\n').filter(Boolean)
    .map((l) => { try { return JSON.parse(l); } catch { return null; } })
    .filter(Boolean)
    .filter((o) => o.kind === 'offer');
}

function gossip(msg) {
  const peers = (process.env.CONTROL_PEERS || '').split(',').filter(Boolean);
  if (!peers.length) return;
  for (const base of peers) {
    try {
      spawnSync('curl', ['-sS', '-m', '5', '-X', 'POST', `${base}/control/sync`,
        '-H', 'content-type: application/json',
        ...(process.env.CONTROL_TOKEN ? ['-H', `x-control-token: ${process.env.CONTROL_TOKEN}`] : []),
        '-d', JSON.stringify(msg)], { stdio: 'ignore' });
    } catch { /* fire-and-forget, like control.mjs */ }
  }
}

function runKnife(path, cwd) {
  // `gokujo check` = scan + graph + build + sorry + axioms as one gate.
  // Exit 0: the file compiles, has no reachable sorry, and only allowed axioms.
  // cwd MUST be the source file's directory: the knife resolves job paths
  // against cwd at the build stage (an absolute path is catenated onto it) and
  // keeps its .gokujo build cache in cwd — empirically pinned, not documented.
  // A full check compiles the file's whole import closure (Mathlib projects
  // can take a long while — that IS the proof work).
  const r = spawnSync(GOKUJO, ['check', path],
    { encoding: 'utf8', timeout: JOB_TIMEOUT_MS, cwd });
  return { code: r.status ?? -1, out: (r.stdout || '') + (r.stderr || '') };
}

function work(offer, state) {
  const { jobId, path, sourceDigestHex, weight, declKind, line } = offer;
  console.log(`${ts()} claiming ${jobId} (weight ${weight}) ${path}:${line ?? ''}`);
  state.claims[jobId] = { claimedAt: ts(), node: NODE_ID, digest: sourceDigestHex };
  saveState(state);
  gossip({ kind: 'claim', action: `prove:${jobId}`, ts: Date.now(), actor: NODE_ID });

  let outcome;
  if (!path || !existsSync(path)) {
    outcome = { status: 'failed', reason: 'source file missing' };
  } else {
    // The knife writes its build cache beside the source, so guard the source
    // filesystem before burning minutes on a build that would die at 100%.
    const cwd = dirname(path);
    try {
      const st = statfsSync(cwd);
      if (st.bavail * st.bsize < MIN_FREE_BYTES) {
        console.log(`${ts()} FATAL ${jobId} — ${cwd}'s fs has < ${(MIN_FREE_BYTES / 1024 ** 3) | 0}G free; free space, then restart`);
        process.exit(2);
      }
    } catch { /* statfs failed: let the knife try and report */ }
    const { code, out } = runKnife(path, cwd);
    if (/no toolchain available/.test(out)) {
      // Infra failure, not a verdict on the proof: record nothing, so the
      // claim stays outcome-less and is retried on the next start.
      console.log(`${ts()} FATAL ${jobId} — knife has no toolchain; fix service env (PATH), then restart`);
      process.exit(2);
    }
    if (code === 0) outcome = { status: 'proved', note: 'gokujo check exit 0' };
    else if (code === 124) {
      // SCP: the knife blew the time budget — this source is contraband,
      // quarantined to phase 2, not a phase-1 failure.
      outcome = { status: 'quarantined', reason: `budget exceeded (${JOB_TIMEOUT_MS / 1000}s)` };
    }
    else outcome = { status: 'failed', reason: `gokujo check exit ${code}`, tail: out.split('\n').slice(-12).join('\n') };
  }
  const rec = { ...offer, node: NODE_ID, ...outcome, finishedAt: ts() };
  appendFileSync(RESULTS, JSON.stringify(rec) + '\n');
  state.claims[jobId].outcome = outcome.status;
  saveState(state);
  gossip({ kind: 'result', jobId, status: outcome.status, digest: sourceDigestHex, actor: NODE_ID });
  console.log(`${ts()} ${outcome.status.toUpperCase()} ${jobId}${outcome.reason ? ' — ' + outcome.reason : ''}`);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  mkdirSync(STATE_DIR, { recursive: true });
  const state = loadState();
  console.log(`${ts()} bone-worker ${NODE_ID} started; offers=${OFFERS} state=${STATE_FILE}`);
  while (!stopping) {
    const offers = loadOffers()
      // outcome-less claims (crash mid-job, infra exit) are retried:
      // the knife is idempotent, at-least-once beats silently losing jobs
      .filter((o) => !state.claims[o.jobId] || !state.claims[o.jobId].outcome)
      .sort((a, b) => (b.weight ?? 1) - (a.weight ?? 1) || String(a.jobId).localeCompare(String(b.jobId)));
    if (!offers.length) {
      if (existsSync(OFFERS)) {
        const total = loadOffers().length, done = Object.keys(state.claims).length;
        if (done >= total && total > 0) {
          console.log(`${ts()} all ${total} offers handled; idle`);
        } else {
          console.log(`${ts()} ${total - done}/${total} offers in flight elsewhere; idle`);
        }
      } else {
        console.log(`${ts()} no offers file yet at ${OFFERS}; idle`);
      }
      // sleep in 1s slices so SIGINT/SIGTERM stop us promptly
      for (let s = 0; s < POLL_SECONDS && !stopping; s++) await sleep(1000);
      continue;
    }
    work(offers[0], state);
  }
  console.log(`${ts()} bone-worker stopped cleanly`);
}

main();
