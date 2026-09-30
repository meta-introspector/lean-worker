#!/usr/bin/env node
// put.mjs — encrypted payload publication for the p2p proving mesh.
//
// The mesh rooms (kant relay) carry only pointers; content rides on one of
// three payload backends, always age-encrypted first:
//
//   gist    — private GitHub gist (secret, unlisted). 5000 req/hr budget.
//   ipfs    — local ipfs add -q, CID is the pointer (public but ciphertext).
//   cf      — Cloudflare Pages/Worker blob via wrangler/publisher token.
//
// Usage:
//   node put.mjs FILE [--backend gist|ipfs|cf] [--room-note] [--key AGE_RECIPIENT]
//
// Output: one JSON line (the room pointer message):
//   { kind:'payload', backend, id, cid?, url?, size, sha256, ageTo, ts }
//
// The pointer line is what gets posted to a kant room; agents fetch the
// payload with get.mjs using the same pointer.
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const argv = process.argv.slice(2);
const file = argv[0];
if (!file) { console.error('usage: node put.mjs FILE [--backend gist|ipfs|cf] [--key AGE_PUBKEY]'); process.exit(2); }
const opt = (n) => { const i = argv.indexOf(n); return i >= 0 ? argv[i + 1] : undefined; };
const backend = opt('--backend') ?? 'gist';
const ageTo = opt('--key') ?? process.env.AGE_PUBKEY ?? 'age1default-local-recipient';
const sha256 = (b) => createHash('sha256').update(b).digest('hex');

// 1. encrypt with age (recipient from --key or AGE_PUBKEY env)
const plain = readFileSync(file);
const encPath = join(tmpdir(), `payload-${process.pid}.age`);
const enc = execFileSync('age', ['-r', ageTo, '-o', encPath], { input: plain });
const encData = readFileSync(encPath);

const pointer = {
  kind: 'payload',
  backend,
  size: plain.length,
  encSize: encData.length,
  sha256: sha256(plain),
  encSha256: sha256(encData),
  ageTo,
  ts: new Date().toISOString(),
};

if (backend === 'gist') {
  // gh gist rejects binary — base64 the ciphertext into a .b64.txt file.
  const b64Path = encPath + '.b64.txt';
  writeFileSync(b64Path, encData.toString('base64') + '\n');
  const url = execFileSync('gh', ['gist', 'create', b64Path, '--desc',
    `p2p payload ${pointer.sha256.slice(0, 8)}`], { encoding: 'utf8' }).trim();
  pointer.id = url.split('/').pop();
  pointer.url = url;
  pointer.encoding = 'base64';
} else if (backend === 'ipfs') {
  // local ipfs add; CIDv1 raw. Public network but content is ciphertext.
  const cid = execFileSync('ipfs', ['add', '-Q', '--cid-version=1', encPath],
    { encoding: 'utf8' }).trim();
  pointer.id = cid;
  pointer.cid = cid;
} else if (backend === 'cf') {
  // Cloudflare R2/Pages via wrangler. Token from ~/.cloudflare (publisher pattern).
  // TODO phase: r2 object put via wrangler r2 object put kant-payloads/<sha>
  console.error('put.mjs: cf backend not wired yet (needs wrangler r2 bucket)');
  process.exit(3);
} else {
  console.error(`put.mjs: unknown backend ${backend}`);
  process.exit(2);
}

console.log(JSON.stringify(pointer));
