#!/usr/bin/env node
// get.mjs — fetch + decrypt a payload published by put.mjs.
//
// Usage: node get.mjs POINTER.json --out FILE
//   POINTER.json — one pointer line from a kant room (kind:'payload')
// Reads the encrypted blob from the backend, verifies encSha256, decrypts
// with age (identity from --identity or AGE_IDENTITY env), verifies sha256.
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const argv = process.argv.slice(2);
const pointerPath = argv[0];
const outPath = opt('--out') ?? argv[1];
function opt(n) { const i = argv.indexOf(n); return i >= 0 ? argv[i + 1] : undefined; }
if (!pointerPath || !outPath) { console.error('usage: node get.mjs POINTER.json --out FILE'); process.exit(2); }
const p = JSON.parse(readFileSync(pointerPath, 'utf8').trim());
const sha256 = (b) => createHash('sha256').update(b).digest('hex');

const encPath = join(tmpdir(), `payload-get-${process.pid}.age`);
let encData;
if (p.backend === 'gist') {
  // gist raw content: https://gist.githubusercontent.com/<user>/<id>/raw
  const url = `https://gist.githubusercontent.com/jmikedupont2/${p.id}/raw`;
  const raw = Buffer.from(await (await fetch(url)).arrayBuffer());
  encData = p.encoding === 'base64' ? Buffer.from(raw.toString('utf8').trim(), 'base64') : raw;
} else if (p.backend === 'ipfs') {
  // local gateway first; public gateways as fallback
  try {
    encData = Buffer.from(execFileSync('ipfs', ['cat', p.cid]));
  } catch {
    encData = Buffer.from(await (await fetch(`https://ipfs.io/ipfs/${p.cid}`)).arrayBuffer());
  }
} else {
  console.error(`get.mjs: backend ${p.backend} not wired`);
  process.exit(3);
}

if (sha256(encData) !== p.encSha256) { console.error('get.mjs: encSha256 mismatch'); process.exit(1); }
writeFileSync(encPath, encData);

const identity = opt('--identity') ?? process.env.AGE_IDENTITY ?? join(process.env.HOME, '.config/sops/age/keys.txt');
const plain = execFileSync('age', ['--decrypt', '-i', identity, '-o', outPath], { input: encData });
const plainData = readFileSync(outPath);
if (sha256(plainData) !== p.sha256) { console.error('get.mjs: sha256 mismatch'); process.exit(1); }
console.log(JSON.stringify({ ok: true, out: outPath, size: plainData.length }));
