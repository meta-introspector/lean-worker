// PB-22 regression: the deployed worker had no Durable Object, so it rebuilt a
// Map per request and every read came back empty. Run with:
//   node worker-room-test.mjs
//
// These drive the real `Room` Durable Object class against a fake DO binding,
// so they cover the code path Cloudflare runs: router → idFromName → DO →
// RoomState. The assertions are the ones the prototype failed live: two posts
// to one room must advance the cursor, and a read must return both lines.
//
// The room is in memory on purpose — the relay is a mailbox, not an archive.
// One test below pins that down so it cannot drift back into claiming
// durability it does not have.

import assert from "node:assert/strict";

if (!globalThis.crypto?.subtle) globalThis.crypto = (await import("node:crypto")).webcrypto;

const { Room } = await import("./worker.js");

let pass = 0, fail = 0;
const t = async (name, fn) => {
  try { await fn(); console.log(`  ok    ${name}`); pass++; }
  catch (e) { console.log(`  FAIL  ${name}\n        ${e.message}`); fail++; }
};

// ── a Durable Object, badly faked but faithfully ───────────────────────────

const fakeInstance = (env) => new Room({ storage: null }, env);

let names = 0;
const ids = new Map();
const env = {
  INVITE_REQUIRED: "true",
  GAS_LIMIT_PER_PEER_PER_HOUR: "1000000",
  MAX_LINE: "262144",
  MAX_LINES: "4096",
  ROOM_TTL_MS: "21600000",
  GAS_COST_PER_MESSAGE: "1000",
  GAS_COST_PER_BYTE: "1",
  ROOMS: {
    idFromName(name) {
      if (!ids.has(name)) ids.set(name, { name: `id-${++names}` });
      return ids.get(name);
    },
    get() { throw new Error("tests address the DO directly, not through the binding"); },
  },
};

const post = (room, body, { invite, peer } = {}) =>
  new Request(`https://room.internal/?room=${room}`, {
    method: "POST",
    body,
    headers: {
      ...(invite ? { "invite-token": invite } : {}),
      ...(peer ? { "peer-id": peer } : {}),
    },
  });

const get = (room, { invite, peer, query = "" } = {}) =>
  new Request(
    `https://room.internal/?room=${room}${query}`,
    { headers: { ...(invite ? { "invite-token": invite } : {}), ...(peer ? { "peer-id": peer } : {}) } },
  );

// ── the failure the prototype actually had ─────────────────────────────────

console.log("room state survives between requests");

await t("two posts to one room advance the cursor", async () => {
  const instance = fakeInstance(env);
  const first = await (await instance.fetch(post("cursor-room", "hello", { invite: "correct-horse", peer: "p1" }))).json();
  const second = await (await instance.fetch(post("cursor-room", "again", { invite: "correct-horse", peer: "p1" }))).json();
  assert.equal(first.cursor, 1, "first post must be cursor 1");
  assert.equal(second.cursor, 2, `second post must be cursor 2, got ${second.cursor} — the prototype returned 1`);
});

await t("a read returns what was posted", async () => {
  const instance = fakeInstance(env);
  await instance.fetch(post("read-room", "alpha", { invite: "correct-horse", peer: "p1" }));
  await instance.fetch(post("read-room", "beta", { invite: "correct-horse", peer: "p1" }));
  const body = await (await instance.fetch(get("read-room", { invite: "correct-horse", peer: "p1" }))).json();
  assert.deepEqual(body.lines, ["alpha", "beta"]);
  assert.equal(body.cursor, 2);
});

await t("a read from cursor 1 returns only the tail", async () => {
  const instance = fakeInstance(env);
  await instance.fetch(post("tail-room", "alpha", { invite: "correct-horse", peer: "p1" }));
  await instance.fetch(post("tail-room", "beta", { invite: "correct-horse", peer: "p1" }));
  const body = await (await instance.fetch(get("tail-room", { invite: "correct-horse", peer: "p1", query: "&cursor=1" }))).json();
  assert.deepEqual(body.lines, ["beta"]);
  assert.equal(body.cursor, 2);
});

await t("a peer not yet in the room must present the invite to read", async () => {
  const instance = fakeInstance(env);
  await instance.fetch(post("guard-room", "alpha", { invite: "correct-horse", peer: "p1" }));
  const denied = await instance.fetch(get("guard-room", { peer: "stranger" }));
  assert.equal(denied.status, 403, "a reader with no invite must be refused");
  assert.equal((await denied.json()).type, "invite_invalid");
  const allowed = await instance.fetch(get("guard-room", { invite: "correct-horse", peer: "stranger" }));
  assert.equal(allowed.status, 200);
  assert.deepEqual((await allowed.json()).lines, ["alpha"]);
});

await t("the relay keeps no archive: a fresh instance starts empty", async () => {
  // Pinned deliberately. The relay is a mailbox, not an archive — it holds a
  // room while the room is happening and forgets it on the TTL, exactly like
  // server/relay.mjs. Nothing is written to DO storage, so a fresh instance
  // (which is what an eviction produces) sees an empty room.
  //
  // The consequence is real and is the reason this assertion exists: history
  // lives only in the peers that synced it out. If someone later wants the
  // relay to be durable, this test is the thing that should fail, deliberately,
  // rather than the change landing unnoticed.
  const first = fakeInstance(env);
  await first.fetch(post("ephemeral-room", "alpha", { invite: "correct-horse", peer: "p1" }));

  const revived = fakeInstance(env);
  const body = await (await revived.fetch(get("ephemeral-room", { invite: "correct-horse", peer: "p1" }))).json();
  assert.deepEqual(body.lines, [], "the relay persisted something; it is supposed to be a mailbox");
  assert.equal(body.cursor, 0);
});

await t("gas is accounted per peer within an instance", async () => {
  const instance = fakeInstance(env);
  await instance.fetch(post("gas-room", "alpha", { invite: "correct-horse", peer: "p1" }));
  const second = await (await instance.fetch(post("gas-room", "beta", { invite: "correct-horse", peer: "p1" }))).json();
  const third = await (await instance.fetch(post("gas-room", "gamma", { invite: "correct-horse", peer: "p1" }))).json();
  assert.ok(second.gasUsed > 1000, `expected gas to accumulate, got ${second.gasUsed}`);
  assert.ok(third.gasUsed > second.gasUsed, "gas did not accumulate across posts");
});

await t("the gas limit is enforced and reported", async () => {
  const instance = fakeInstance({ ...env, GAS_LIMIT_PER_PEER_PER_HOUR: "5000" });
  await instance.fetch(post("thin-room", "x".repeat(4000), { invite: "correct-horse", peer: "p1" }));
  const res = await instance.fetch(post("thin-room", "y".repeat(4000), { invite: "correct-horse", peer: "p1" }));
  assert.equal(res.status, 429);
  assert.equal((await res.json()).type, "gas_limit_exceeded");
});

await t("a rejected post does not join the room or advance the cursor", async () => {
  const instance = fakeInstance(env);
  await instance.fetch(post("reject-room", "hello", { invite: "correct-horse", peer: "p1" }));
  const res = await instance.fetch(post("reject-room", "intruder", { invite: "bbbbbbbb", peer: "p2" }));
  assert.equal(res.status, 403);
  const after = await instance.fetch(get("reject-room", { invite: "correct-horse", peer: "p1" }));
  assert.deepEqual((await after.json()).lines, ["hello"], "a rejected post must leave nothing behind");
});

await t("an over-long line is refused with 413", async () => {
  const instance = fakeInstance({ ...env, MAX_LINE: "64" });
  const res = await instance.fetch(post("long-room", "z".repeat(65), { invite: "correct-horse", peer: "p1" }));
  assert.equal(res.status, 413);
});

await t("POST with no room is refused, not silently accepted", async () => {
  const instance = fakeInstance(env);
  const res = await instance.fetch(new Request("https://room.internal/", { method: "POST", body: "x" }));
  assert.equal(res.status, 400);
});

// ── invite enforcement end to end ──────────────────────────────────────────

console.log("invite enforcement over HTTP");

// The old live proof of the bypass: posts 1, 2, 3 with invites
// aaaaaaaa / bbbbbbbb / aaaaaaaa all returned ok:true. Two must now.
await t("a wrong invite is 403 and the right one still works", async () => {
  const instance = fakeInstance(env);
  const first = await instance.fetch(post("invite-room", "one", { invite: "aaaaaaaa", peer: "p1" }));
  assert.equal(first.status, 200);
  const wrong = await instance.fetch(post("invite-room", "intruder", { invite: "bbbbbbbb", peer: "p2" }));
  assert.equal(wrong.status, 403);
  assert.equal((await wrong.json()).type, "invite_invalid");
  const right = await instance.fetch(post("invite-room", "three", { invite: "aaaaaaaa", peer: "p1" }));
  assert.equal(right.status, 200);
});

await t("an empty room is claimable by whoever arrives first", async () => {
  // Documented trade-off, asserted so it cannot be quietly changed later:
  // the invite is trust-on-first-use. A room name that an attacker can guess
  // and a room they reach first is a room they own.
  const instance = fakeInstance(env);
  const claimed = await instance.fetch(post("claim-room", "mine now", { invite: "attacker-pick", peer: "p1" }));
  assert.equal(claimed.status, 200);
  const realOwner = await instance.fetch(post("claim-room", "hello", { invite: "the-real-invite", peer: "p2" }));
  assert.equal(realOwner.status, 403, "the first arrival defines the room invite — this is TOFU, by design");
});

await t("a missing invite is 403", async () => {
  const instance = fakeInstance(env);
  const res = await instance.fetch(post("noinvite-room", "hello", { peer: "p1" }));
  assert.equal(res.status, 403);
});

await t("the router's /health does not need a room", async () => {
  const { default: router } = await import("./worker.js");
  const res = await router.fetch(new Request("https://desk.example/health"), env);
  const body = await res.json();
  assert.equal(res.status, 200);
  assert.equal(body.ok, true);
  assert.equal(body.durable, false, "health must not imply the relay keeps an archive");
  assert.equal(body.features.inviteOnly, true);
  assert.equal(body.features.gasLimitPerPeerPerHour, 1000000);
  assert.equal(body.features.maxLines, 4096);
});

await t("the router forwards a room to the DO named by the room name", async () => {
  const { default: router } = await import("./worker.js");
  const seen = [];
  const routed = {
    ...env,
    ROOMS: {
      idFromName: (n) => { seen.push(["name", n]); return "id"; },
      get: (id) => ({ fetch: async (req) => { seen.push(["id", id, new URL(req.url).search]); return new Response("{}", { headers: { "content-type": "application/json" } }); } }),
    },
  };
  await router.fetch(new Request("https://desk.example/room/some%20room", { method: "POST", body: "x" }), routed);
  assert.deepEqual(seen, [["name", "some room"], ["id", "id", "?room=some+room"]]);
});

await t("the router carries the caller's query parameters through", async () => {
  // `new Request(url, request)` builds a new URL and silently drops the
  // caller's query string, so cursor/wait/peer never reached the room: reads
  // ignored `cursor` and every read-only peer got a random identity. Nothing
  // errored, which is why it went unnoticed.
  const { default: router } = await import("./worker.js");
  let forwarded = null;
  const routed = {
    ...env,
    ROOMS: {
      idFromName: () => "id",
      get: () => ({ fetch: async (req) => { forwarded = new URL(req.url).searchParams; return new Response("{}"); } }),
    },
  };
  await router.fetch(new Request("https://desk.example/room/r?cursor=1&wait=5&peer=p9&invite=aaaaaaaa"), routed);
  assert.equal(forwarded.get("room"), "r");
  assert.equal(forwarded.get("cursor"), "1");
  assert.equal(forwarded.get("wait"), "5");
  assert.equal(forwarded.get("peer"), "p9");
  assert.equal(forwarded.get("invite"), "aaaaaaaa");
});

await t("the router must not let a caller override the routed room name", async () => {
  const { default: router } = await import("./worker.js");
  let forwarded = null;
  const routed = {
    ...env,
    ROOMS: {
      idFromName: () => "id",
      get: () => ({ fetch: async (req) => { forwarded = new URL(req.url).searchParams.get("room"); return new Response("{}"); } }),
    },
  };
  await router.fetch(new Request("https://desk.example/room/real?room=other"), routed);
  assert.equal(forwarded, "real", "the path decides the room, not a query parameter");
});

await t("the router 404s an unknown path", async () => {
  const { default: router } = await import("./worker.js");
  const res = await router.fetch(new Request("https://desk.example/nope"), env);
  assert.equal(res.status, 404);
});

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);