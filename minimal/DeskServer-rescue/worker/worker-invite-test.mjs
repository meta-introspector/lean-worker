// PB-22 regression: the deployed worker accepted any 8-character string as a
// valid invite. Run with:  node worker-invite-test.mjs
//
// These are the tests the original package.json could not run — its "test"
// script was `echo 'Tests passed'`, which cannot fail.
//
// The state module is imported directly rather than sliced out of the source:
// slicing a class out of a module by string index silently double-declares
// when a boundary moves. The only globals it needs beyond node's are
// `addEventListener` (a Cloudflare runtime hook) and `crypto.subtle` (present
// on node 18+, stubbed just in case).

import assert from "node:assert/strict";

if (!globalThis.crypto?.subtle) globalThis.crypto = (await import("node:crypto")).webcrypto;
globalThis.addEventListener ??= () => {};

// RoomState now lives in room.mjs so the Durable Object can own one per room.
// worker.js is the router plus the DO class and no longer exports it.
const { RoomState } = await import("./room.mjs");

let pass = 0, fail = 0;
const t = async (name, fn) => {
  try { await fn(); console.log(`  ok    ${name}`); pass++; }
  catch (e) { console.log(`  FAIL  ${name}\n        ${e.message}`); fail++; }
};

console.log("invite verification");

await t("the old bypass is refused", async () => {
  const room = new RoomState();
  await room.verifyInvite("correct-horse");        // first joiner sets the invite
  assert.equal(await room.verifyInvite("aaaaaaaa"), false,
    "an unrelated 8-char string must NOT be accepted — this is the old bug");
});

await t("the correct invite is accepted", async () => {
  const room = new RoomState();
  await room.verifyInvite("correct-horse");
  assert.equal(await room.verifyInvite("correct-horse"), true);
});

await t("short invites are refused", async () => {
  const room = new RoomState();
  await room.verifyInvite("correct-horse");
  assert.equal(await room.verifyInvite("x"), false);
  assert.equal(await room.verifyInvite("1234567"), false);
});

await t("empty / missing invites are refused", async () => {
  const room = new RoomState();
  await room.verifyInvite("correct-horse");
  for (const bad of ["", null, undefined, 123, {}]) {
    assert.equal(await room.verifyInvite(bad), false, `accepted ${JSON.stringify(bad)}`);
  }
});

await t("no invite set yet: the first joiner defines it", async () => {
  const room = new RoomState();
  assert.equal(room.inviteHash, null);
  assert.equal(await room.verifyInvite("first-come"), true);
  assert.notEqual(room.inviteHash, null);
  assert.equal(await room.verifyInvite("someone-elses"), false);
});

await t("rooms do not share an invite", async () => {
  const a = new RoomState(), b = new RoomState();
  await a.verifyInvite("room-a-invite");
  await b.verifyInvite("room-b-invite");
  assert.equal(await a.verifyInvite("room-b-invite"), false);
  assert.equal(await b.verifyInvite("room-a-invite"), false);
});

await t("addPeer refuses a wrong invite", async () => {
  const room = new RoomState();
  await room.verifyInvite("correct-horse");
  await assert.rejects(() => room.addPeer("peer-1", "wrong-invite"),
    /Invalid or missing invite/);
  assert.equal(room.peers.has("peer-1"), false);
});

await t("addPeer accepts the right invite", async () => {
  const room = new RoomState();
  await room.addPeer("peer-1", "correct-horse");
  assert.ok(room.peers.has("peer-1"));
});

await t("inviteRequired=false disables the check", async () => {
  const room = new RoomState();
  room.inviteRequired = false;
  assert.equal(await room.verifyInvite(undefined), true);
});

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);