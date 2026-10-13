#!/usr/bin/env node
// offers-to-kant.mjs — push bone offers into a kant relay room (p2p job intake).
//
// Phase 1 step 1 of p2p-proving-bootstrap: bone offers (offers.jsonl from
// emit-offers.mjs) become append-only lines in the kant `jobs` room, so any
// agent on the mesh can subscribe and claim work without touching the
// filesystem where bone-worker runs.
//
// Usage:
//   node offers-to-kant.mjs OFFERS.jsonl [--relay URL] [--room jobs] [--batch N]
//
// Defaults: --relay http://localhost:8080  --room jobs  --batch 50
// Each line is one offer JSON (from emit-offers.mjs). Posts are batched to
// respect relay rate limits; each POST body is newline-joined offer lines.
import { readFileSync } from 'node:fs';

const argv = process.argv.slice(2);
const file = argv[0];
if (!file) { console.error('usage: node offers-to-kant.mjs OFFERS.jsonl [--relay URL] [--room jobs] [--batch N]'); process.exit(2); }
const opt = (n) => { const i = argv.indexOf(n); return i >= 0 ? argv[i + 1] : undefined; };
const relay = opt('--relay') ?? 'http://localhost:8080';
const room = opt('--room') ?? 'jobs';
const batch = Number(opt('--batch') ?? 50);
const pass = opt('--pass'); // optional x-kant-pass value

const offers = readFileSync(file, 'utf8').split('\n').filter(Boolean);
console.error(`offers-to-kant: ${offers.length} offers -> ${relay}/room/${room}`);

let posted = 0;
for (let i = 0; i < offers.length; i += batch) {
  const body = offers.slice(i, i + batch).join('\n');
  const headers = { 'content-type': 'text/plain' };
  if (pass) headers['x-kant-pass'] = pass;
  const res = await fetch(`${relay}/room/${encodeURIComponent(room)}`, {
    method: 'POST', headers, body,
  });
  const j = await res.json().catch(() => ({}));
  if (!res.ok || !j.ok) {
    console.error(`offers-to-kant: batch at ${i} failed: ${res.status} ${JSON.stringify(j)}`);
    process.exit(1);
  }
  posted += j.accepted ?? 0;
}
const status = await fetch(`${relay}/room/${encodeURIComponent(room)}?cursor=0`).then((r) => r.json()).catch(() => ({}));
console.error(`offers-to-kant: posted ${posted}/${offers.length} lines, room cursor now ${status.cursor ?? '?'}`);
console.log(JSON.stringify({ ok: true, posted, room, relay }));
