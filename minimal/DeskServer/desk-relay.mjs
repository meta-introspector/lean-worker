#!/usr/bin/env node
// desk-relay.mjs — the OTC Proof Trading Desk relay, extending kant-zk rendezvous relay
//
// Zero dependencies: Node's own `http` module, plus a small RFC 6455
// server so the browser can hold a WebSocket open instead of polling.
//
// What it is: one append-only log per room (like the kant-zk relay)
// plus desk endpoints for the OTC proof trading desk.
//
// Two documented deviations from the proved model, both about running out
// of memory rather than about semantics:
//   * a line longer than --max-line bytes is rejected with 413;
//   * a room keeps at most --max-lines lines, and is forgotten after
//     --room-ttl of silence.  Cursors stay absolute; a poll from a cursor
//     that has been trimmed away gets `truncated: true` plus everything
//     still held.
//
// Usage:  node server/desk-relay.mjs [--port 8787] [--static web] [--origin '*']
//                                [--log relay.log] [--quiet]
//
// Every request is written to the log: the time, the method, the path with
// the room reduced to an eight-character handle, the status, the number of
// lines and how long it took.  Rooms are never printed in full, so a relay
// log can be shared the way `web/diag.html` shares a client run.

import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const args = new Map();
for (let i = 2; i < process.argv.length; i += 1) {
  const tok = process.argv[i];
  if (!tok.startsWith("--")) continue;
  const next = process.argv[i + 1];
  // `--flag` on its own is a flag; `--key value` is a setting.
  if (next === undefined || next.startsWith("--")) args.set(tok.slice(2), "1");
  else { args.set(tok.slice(2), next); i += 1; }
}

/** Are we the program being run, or a library inside somebody else's?
 *  A library keeps quiet unless it is given a log file. */
const isMain = process.argv[1] && import.meta.url === `file://${path.resolve(process.argv[1])}`;

const posInt = (raw, fallback) => {
  const n = Number(raw);
  return Number.isFinite(n) && n >= 1 ? Math.floor(n) : fallback;
};

export const CONFIG = {
  port: posInt(args.get("port") ?? process.env.PORT, 8787),
  host: args.get("host") ?? process.env.HOST ?? "0.0.0.0",
  staticDir: args.get("static") ?? process.env.KANT_STATIC ?? "",
  origin: args.get("origin") ?? process.env.KANT_ORIGIN ?? "*",
  maxLine: posInt(args.get("max-line"), 262144),
  maxLines: posInt(args.get("max-lines"), 4096),
  maxBody: posInt(args.get("max-body"), 1048576),
  maxRooms: posInt(args.get("max-rooms"), 128),
  maxTotalBytes: posInt(args.get("max-total-bytes"), 64 * 1024 * 1024),
  roomTtlMs: posInt(args.get("room-ttl"), 6 * 60 * 60 * 1000),
  logFile: args.get("log") ?? process.env.KANT_LOG ?? "",
  quiet: args.get("quiet") === "1" || process.env.KANT_QUIET === "1" || !isMain,
  version: "1.0.0",
};

// ------------------------------------------------------------- the log

/** An eight-character one-way handle, as `Kant.Diagnostics.ref`. */
export const roomRef = (room) =>
  crypto.createHash("sha256").update(String(room)).digest("hex").slice(0, 8);

/** One line per request: `time level area text | detail`.  Writes to the
 *  file named by `--log` (appending) and, unless `--quiet`, to stdout. */
export function makeLogger(cfg = CONFIG) {
  const stream = cfg.logFile ? fs.createWriteStream(cfg.logFile, { flags: "a" }) : null;
  const clean = (s) => String(s).replace(/[\r\n]+/g, " ");
  const write = (level, area, text, detail = "") => {
    const safeText = clean(text);
    const safeDetail = detail ? clean(detail) : "";
    const line = `${new Date().toISOString()} ${level.padEnd(5)} ${area.padEnd(6)} ${safeText}` +
      `${safeDetail ? `  |  ${safeDetail}` : ""}`;
    if (stream) stream.write(`${line}\n`);
    if (!cfg.quiet) console.log(line);
    return line;
  };
  return {
    info: (a, t, d) => write("info", a, t, d),
    warn: (a, t, d) => write("warn", a, t, d),
    error: (a, t, d) => write("error", a, t, d),
    close: () => stream?.end(),
  };
}

// ------------------------------------------------------------- the rooms

/** One append-only log per room (`Kant.Relay.Server`). */
export class Rooms {
  constructor(cfg = CONFIG) {
    this.cfg = cfg;
    this.map = new Map(); // room -> { base, bytes, lines, waiters, sockets, touched }
    this.totalBytes = 0;
  }

  deleteRoom(key) {
    const r = this.map.get(key);
    if (r) {
      this.totalBytes = Math.max(0, this.totalBytes - r.bytes);
      this.map.delete(key);
    }
  }

  room(name) {
    const key = String(name);
    let r = this.map.get(key);
    if (!r) {
      const maxRooms = this.cfg.maxRooms ?? 128;
      if (this.map.size >= maxRooms) {
        this.sweep();
      }
      if (this.map.size >= maxRooms) {
        for (const [k, candidate] of this.map) {
          if (candidate.sockets.size === 0 && candidate.waiters.size === 0) {
            this.deleteRoom(k);
            break;
          }
        }
      }
      if (this.map.size >= maxRooms) {
        throw new Error("room capacity reached");
      }
      const created = { base: 0, bytes: 0, lines: [], waiters: new Set(), sockets: new Set(), touched: Date.now() };
      this.map.set(key, created);
      r = created;
    }
    r.touched = Date.now();
    return r;
  }

  /** Absolute length of the log: the cursor the next line will get. */
  end(name) {
    const r = this.map.get(name);
    return r ? r.base + r.lines.length : 0;
  }

  post(name, lines) {
    const r = this.room(name);
    const maxBytes = this.cfg.maxBody ?? 1048576;
    const maxTotal = this.cfg.maxTotalBytes ?? 64 * 1024 * 1024;
    const batch = lines.length > this.cfg.maxLines
      ? lines.slice(lines.length - this.cfg.maxLines)
      : lines;
    const skipped = lines.length - batch.length;
    r.base += skipped;
    for (const l of batch) {
      const b = Buffer.byteLength(l, "utf8");
      r.lines.push(l);
      r.bytes += b;
      this.totalBytes += b;
    }
    let drop = Math.max(0, r.lines.length - this.cfg.maxLines);
    let droppedBytes = 0;
    for (let i = 0; i < drop; i++) {
      droppedBytes += Buffer.byteLength(r.lines[i], "utf8");
    }
    while (drop < r.lines.length && r.bytes - droppedBytes > maxBytes) {
      droppedBytes += Buffer.byteLength(r.lines[drop], "utf8");
      drop += 1;
    }
    if (drop > 0) {
      r.lines.splice(0, drop);
      r.bytes -= droppedBytes;
      this.totalBytes = Math.max(0, this.totalBytes - droppedBytes);
      r.base += drop;
    }
    if (this.totalBytes > maxTotal) {
      this.sweep();
    }
    for (const [k, candidate] of this.map) {
      if (this.totalBytes <= maxTotal) break;
      if (candidate !== r && candidate.sockets.size === 0 && candidate.waiters.size === 0) {
        this.deleteRoom(k);
      }
    }
    if (this.totalBytes > maxTotal && r.lines.length > 0) {
      let extraDrop = 0;
      let extraBytes = 0;
      while (extraDrop < r.lines.length && this.totalBytes - extraBytes > maxTotal) {
        extraBytes += Buffer.byteLength(r.lines[extraDrop], "utf8");
        extraDrop += 1;
      }
      if (extraDrop > 0) {
        r.lines.splice(0, extraDrop);
        r.bytes -= extraBytes;
        this.totalBytes = Math.max(0, this.totalBytes - extraBytes);
        r.base += extraDrop;
      }
    }
    const cursor = r.base + r.lines.length;
    for (const w of [...r.waiters]) { r.waiters.delete(w); w(); }
    for (const s of [...r.sockets]) s.push(this.fetch(name, s.cursor));
    return cursor;
  }

  /** Everything from `cursor` onwards, plus the new cursor. */
  fetch(name, cursor) {
    const r = this.map.get(name);
    if (!r) {
      return { cursor: 0, lines: [], truncated: false };
    }
    r.touched = Date.now();
    const end = r.base + r.lines.length;
    const from = Math.max(cursor, r.base);
    return {
      cursor: end,
      lines: r.lines.slice(from - r.base),
      truncated: cursor < r.base,
    };
  }

  /** Resolve when something is posted, after `ms`, or when `stream` closes. */
  wait(name, ms, stream = null) {
    const r = this.room(name);
    return new Promise((resolve) => {
      const done = () => {
        clearTimeout(timer);
        if (stream) stream.off?.("close", done);
        r.waiters.delete(done);
        if (r.lines.length === 0 && r.sockets.size === 0 && r.waiters.size === 0) {
          this.deleteRoom(String(name));
        }
        resolve();
      };
      if (stream?.destroyed || stream?.writableEnded) {
        if (r.lines.length === 0 && r.sockets.size === 0 && r.waiters.size === 0) {
          this.deleteRoom(String(name));
        }
        resolve();
        return;
      }
      const timer = setTimeout(done, ms);
      r.waiters.add(done);
      if (stream) stream.once?.("close", done);
    });
  }

  sweep() {
    const now = Date.now();
    for (const [name, r] of this.map) {
      if (r.sockets.size === 0 && r.waiters.size === 0 &&
          now - r.touched > this.cfg.roomTtlMs) this.deleteRoom(name);
    }
  }

  stats() {
    return {
      rooms: this.map.size,
      lines: [...this.map.values()].reduce((n, r) => n + r.lines.length, 0),
      sockets: [...this.map.values()].reduce((n, r) => n + r.sockets.size, 0),
    };
  }
}

// -------------------------------------------------------------- HTTP part

const MIME = {
  ".html": "text/html; charset=utf-8", ".mjs": "text/javascript; charset=utf-8",
  ".js": "text/javascript; charset=utf-8", ".css": "text/css; charset=utf-8",
  ".json": "application/json", ".wasm": "application/wasm",
  ".png": "image/png", ".svg": "image/svg+xml", ".gif": "image/gif",
  ".ico": "image/x-icon", ".txt": "text/plain; charset=utf-8",
};

const cors = (cfg) => ({
  "access-control-allow-origin": cfg.origin,
  "access-control-allow-methods": "GET, POST, OPTIONS",
  "access-control-allow-headers": "content-type",
  "access-control-max-age": "86400",
});

const sendJson = (res, cfg, code, obj) => {
  res.writeHead(code, { "content-type": "application/json", ...cors(cfg) });
  res.end(JSON.stringify(obj));
};

function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    let size = 0;
    let failed = false;
    const chunks = [];
    req.on("data", (c) => {
      if (failed) return;
      size += c.length;
      if (size > limit) {
        failed = true;
        req.resume();
        reject(new Error("too large"));
        return;
      }
      chunks.push(c);
    });
    req.on("end", () => {
      if (!failed) resolve(Buffer.concat(chunks).toString("utf8"));
    });
    req.on("error", reject);
  });
}

// Serving `web/` as the document root leaves the Lean-extracted kernel, which
// lives in the sibling `dist/`, outside the tree: `/dist/kant_kernel.wasm` used
// to 404, and the page reported that as a kernel validation failure. Requests
// under /dist/ therefore also look in the directory next to the static root.
function staticCandidates(cfg, rel) {
  const root = path.resolve(cfg.staticDir);
  const safe = path.normalize(rel).replace(/^(\.\.[/\\])+/, "");
  const inRoot = path.join(root, safe);
  const files = inRoot.startsWith(root) ? [inRoot] : [];
  const distRoot = path.resolve(root, "..", "dist");
  const under = /^[/\\]dist[/\\](.+)$/.exec(safe);
  if (under) {
    const sibling = path.join(distRoot, under[1]);
    if (sibling.startsWith(distRoot)) files.push(sibling);
  }
  return files;
}

function serveStatic(cfg, res, urlPath) {
  const rel = urlPath === "/" ? "/index.html" : urlPath;
  const files = staticCandidates(cfg, rel);
  const attempt = (i) => {
    if (i >= files.length) {
      res.writeHead(404, { "content-type": "text/plain" });
      res.end("not found");
      return;
    }
    fs.readFile(files[i], (err, data) => {
      if (err) { attempt(i + 1); return; }
      res.writeHead(200, {
        "content-type": MIME[path.extname(files[i])] ?? "application/octet-stream",
        "cache-control": "no-cache",
      });
      res.end(data);
    });
  };
  attempt(0);
}

// ========================= DESK ENDPOINTS (added to relay) =========================

// In-memory store for desk state (in production, use proper DB)
// TODO: In real implementation, use Proxy/Core.lean hash chain
const deskState = {
  bounties: new Map(),  // bountyId -> { lane, price, escrowMode, deposit }
  trades: new Map(),    // tradeId -> { bounty, layer, mode, rail, deposit }
  escrows: new Map(),   // escrowId -> { tradeId, receipts, current }
  kb: new Map(),        // witnessed KB records
  approvals: new Set(), // set of approved layer promotions
};

function handleDeskEndpoints(cfg, req, res, url, started, log) {
  const pathname = url.pathname;
  const method = req.method;
  
  // GET /desk/board - the 21-bounty board, rendered from BountyBoard
  if (pathname === "/desk/board" && method === "GET") {
    log.info("desk", "board request", `${method} ${pathname}`);
    if (deskState.bounties.size === 0) {
      sendJson(res, cfg, 501, {
        ok: false,
        error: "bounty board store not yet populated"
      });
      return true;
    }
    const bounties = [...deskState.bounties.values()];
    sendJson(res, cfg, 200, {
      ok: true,
      board: {
        totalUnits: bounties.reduce((sum, b) => sum + (Number(b.price) || 0), 0),
        bounties
      }
    });
    return true;
  }

  // POST /desk/quote - request a bilateral quote on a unit
  if (pathname === "/desk/quote" && method === "POST") {
    log.info("desk", "quote request", `${method} ${pathname}`);
    sendJson(res, cfg, 501, {
      ok: false,
      error: "quote computation not yet implemented"
    });
    return true;
  }

  // POST /desk/ticket - post a trade ticket (Envelope, tagTrade)
  if (pathname === "/desk/ticket" && method === "POST") {
    log.info("desk", "ticket posted", `${method} ${pathname}`);
    sendJson(res, cfg, 501, {
      ok: false,
      received: false,
      error: "trade ticket persistence not yet implemented"
    });
    return true;
  }

  // POST /desk/escrow - deposit into escrow
  if (pathname === "/desk/escrow" && method === "POST") {
    log.info("desk", "escrow deposit", `${method} ${pathname}`);
    sendJson(res, cfg, 501, {
      ok: false,
      deposited: false,
      error: "escrow deposit persistence not yet implemented"
    });
    return true;
  }

  // GET /desk/escrow/{id} - escrow state
  if (pathname.startsWith("/desk/escrow/") && method === "GET") {
    const id = pathname.substring("/desk/escrow/".length);
    log.info("desk", "escrow state request", `${method} /desk/escrow/${roomRef(id)}`);
    const escrow = deskState.escrows.get(id);
    if (!escrow) {
      sendJson(res, cfg, 404, {
        ok: false,
        error: "escrow not found"
      });
      return true;
    }
    sendJson(res, cfg, 200, {
      ok: true,
      escrow
    });
    return true;
  }

  // POST /desk/approve/promote - APPROVE: release the next layer (signed Receipt)
  if (pathname === "/desk/approve/promote" && method === "POST") {
    log.info("desk", "layer promotion approval", `${method} ${pathname}`);
    sendJson(res, cfg, 501, {
      ok: false,
      approved: false,
      error: "promotion approval signature verification not yet implemented"
    });
    return true;
  }

  // GET /desk/kb?q= - witnessed KB query
  if (pathname === "/desk/kb" && method === "GET") {
    const query = url.searchParams.get("q") || "";
    log.info("desk", "KB query", `${method} ${pathname} len=${query.length}`);
    const results = [...deskState.kb.values()].filter((r) =>
      !query || JSON.stringify(r).toLowerCase().includes(query.toLowerCase())
    );
    sendJson(res, cfg, 200, {
      ok: true,
      results,
      query,
      timestamp: Date.now()
    });
    return true;
  }

  return false; // Not a desk endpoint
}

// ------------------------------------------------------------- the server

function safeDecodeURIComponent(raw) {
  try {
    return decodeURIComponent(raw);
  } catch {
    return null;
  }
}

export function createServer(cfg = CONFIG, rooms = new Rooms(cfg), log = makeLogger(cfg)) {
  const server = http.createServer(async (req, res) => {
    const started = Date.now();
    const url = new URL(req.url, `http://${req.headers.host ?? "localhost"}`);
    const shown = url.pathname.replace(/^\/(room|ws)\/([^/]+)/,
      (_, kind, room) => {
        const decoded = safeDecodeURIComponent(room);
        return `/${kind}/${roomRef(decoded ?? room)}`;
      });
    
    // Check if this is a desk endpoint first
    if (handleDeskEndpoints(cfg, req, res, url, started, log)) {
      return;
    }
    
    res.on("finish", () => log.info("relay",
      `${req.method} ${shown} ${res.statusCode}`,
      `${Date.now() - started}ms from ${req.socket.remoteAddress ?? "?"}`));
    req.on("error", (e) => log.error("relay", `${req.method} ${shown} failed`, e.message));

    if (req.method === "OPTIONS") { res.writeHead(204, cors(cfg)); res.end(); return; }

    if (url.pathname === "/health") {
      sendJson(res, cfg, 200, {
        ok: true, name: "otc-desk-relay", version: cfg.version, ...rooms.stats(),
      });
      return;
    }

    const m = url.pathname.match(/^\/room\/([^/]+)$/);
    if (m) {
      const room = safeDecodeURIComponent(m[1]);
      if (room === null) {
        sendJson(res, cfg, 400, { ok: false, error: "malformed room URI encoding" });
        return;
      }
      log.info("relay", `route room ${roomRef(room)}`, `${req.method} ${shown}`);
      if (req.method === "POST") {
        let body;
        try { body = await readBody(req, cfg.maxBody); }
        catch (e) {
          log.warn("relay", "a body was refused", `${roomRef(room)}: ${e.message}`);
          res.writeHead(413, { "content-type": "application/json", connection: "close", ...cors(cfg) });
          res.end(JSON.stringify({ ok: false, error: "body too large" }));
          return;
        }
        const lines = body.split("\n").map((l) => l.trim()).filter((l) => l.length > 0);
        if (lines.some((l) => Buffer.byteLength(l, "utf8") > cfg.maxLine)) {
          log.warn("relay", "a line was too long", roomRef(room));
          sendJson(res, cfg, 413, { ok: false, error: "line too long" });
          return;
        }
        let cursor;
        try {
          cursor = rooms.post(room, lines);
        } catch (e) {
          log.warn("relay", "room capacity reached", `${roomRef(room)}: ${e.message}`);
          sendJson(res, cfg, 503, { ok: false, error: "room capacity reached" });
          return;
        }
        log.info("relay", `posted ${lines.length} lines`, `${roomRef(room)} cursor=${cursor}`);
        sendJson(res, cfg, 200, { ok: true, cursor, accepted: lines.length });
        return;
      }
      if (req.method === "GET") {
        const cursor = Number(url.searchParams.get("cursor") ?? 0) || 0;
        const wait = Math.min(Number(url.searchParams.get("wait") ?? 0) || 0, 60);
        log.info("relay", `fetch room`, `${roomRef(room)} cursor=${cursor} wait=${wait}s`);
        let out = rooms.fetch(room, cursor);
        if (wait > 0 && out.lines.length === 0) {
          log.info("relay", `waiting for room`, `${roomRef(room)} cursor=${cursor} wait=${wait}s`);
          try {
            await rooms.wait(room, wait * 1000, res);
          } catch (e) {
            log.warn("relay", "room capacity reached on wait", `${roomRef(room)}: ${e.message}`);
            sendJson(res, cfg, 503, { ok: false, error: "room capacity reached" });
            return;
          }
          if (res.destroyed || res.writableEnded) return;
          out = rooms.fetch(room, cursor);
        }
        log.info("relay", `fetched room`, `${roomRef(room)} cursor=${cursor} -> ${out.cursor} lines=${out.lines.length} truncated=${out.truncated}`);
        sendJson(res, cfg, 200, { ok: true, ...out });
        return;
      }
      log.warn("relay", "method not allowed", `${roomRef(room)} ${req.method}`);
      sendJson(res, cfg, 405, { ok: false, error: "method not allowed" });
      return;
    }

    if (cfg.staticDir) {
      log.info("relay", "static", shown);
      serveStatic(cfg, res, url.pathname);
      return;
    }
    log.warn("relay", "not found", shown);
    sendJson(res, cfg, 404, { ok: false, error: "not found" });
  });

  server.on("upgrade", (req, socket) => handleUpgrade(cfg, rooms, req, socket, log));
  server.on("clientError", (e, socket) => {
    log.error("relay", "a connection failed before any request", e.message);
    socket.destroy();
  });
  const sweeper = setInterval(() => rooms.sweep(), 60_000);
  sweeper.unref?.();
  server.rooms = rooms;
  server.log = log;
  return server;
}

// --------------------------------------------------------- WebSocket part
// A minimal RFC 6455 server: text frames, ping and close, which is all the
// protocol needs.  Client frames are masked; server frames are not.

const WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

const wsAccept = (key) => crypto.createHash("sha1").update(key + WS_GUID).digest("base64");

function wsFrame(text) {
  const payload = Buffer.from(text, "utf8");
  const n = payload.length;
  let header;
  if (n < 126) {
    header = Buffer.alloc(2);
    header[1] = n;
  } else if (n < 65536) {
    header = Buffer.alloc(4);
    header[1] = 126;
    header.writeUInt16BE(n, 2);
  } else {
    header = Buffer.alloc(10);
    header[1] = 127;
    header.writeBigUInt64BE(BigInt(n), 2);
  }
  header[0] = 0x81; // FIN + text
  return Buffer.concat([header, payload]);
}

/** Pull whole frames out of a buffer; returns how many bytes were used. */
function wsFrames(buf, maxPayload = 1024 * 1024) {
  const out = [];
  let off = 0;
  while (off + 2 <= buf.length) {
    const b0 = buf[off], b1 = buf[off + 1];
    const fin = (b0 & 0x80) !== 0;
    const opcode = b0 & 0x0f;
    const masked = (b1 & 0x80) !== 0;
    let len = b1 & 0x7f;
    let p = off + 2;
    if (len === 126) { if (p + 2 > buf.length) break; len = buf.readUInt16BE(p); p += 2; }
    else if (len === 127) {
      if (p + 8 > buf.length) break;
      const bigLen = buf.readBigUInt64BE(p);
      if (bigLen > BigInt(maxPayload)) return { frames: out, used: off, oversized: true };
      len = Number(bigLen); p += 8;
    }
    if (len > maxPayload) return { frames: out, used: off, oversized: true };
    let mask = null;
    if (masked) { if (p + 4 > buf.length) break; mask = buf.subarray(p, p + 4); p += 4; }
    if (p + len > buf.length) break;
    const data = Buffer.from(buf.subarray(p, p + len));
    if (mask) for (let i = 0; i < data.length; i++) data[i] ^= mask[i % 4];
    off = p + len;
    out.push({ fin, opcode, data });
  }
  return { frames: out, used: off, oversized: false };
}

function handleUpgrade(cfg, rooms, req, socket, log = { info() {}, warn() {}, error() {} }) {
  const url = new URL(req.url, `http://${req.headers.host ?? "localhost"}`);
  const m = url.pathname.match(/^\/ws\/([^/]+)$/);
  const key = req.headers["sec-websocket-key"];
  if (!m || !key) {
    log.warn("relay", "websocket upgrade rejected", "missing room or key");
    socket.destroy();
    return;
  }
  const room = safeDecodeURIComponent(m[1]);
  if (room === null) {
    log.warn("relay", "websocket upgrade rejected", "malformed room URI encoding");
    socket.destroy();
    return;
  }
  let r;
  try {
    r = rooms.room(room);
  } catch (e) {
    log.warn("relay", "websocket upgrade rejected", `${roomRef(room)}: ${e.message}`);
    socket.write("HTTP/1.1 503 Service Unavailable\r\nConnection: close\r\n\r\n");
    socket.destroy();
    return;
  }
  log.info("relay", "websocket upgrade", `${roomRef(room)} cursor=${url.searchParams.get("cursor") ?? 0}`);

  socket.write(
    "HTTP/1.1 101 Switching Protocols\r\n" +
    "Upgrade: websocket\r\nConnection: Upgrade\r\n" +
    `Sec-WebSocket-Accept: ${wsAccept(key)}\r\n\r\n`,
  );

  const state = {
    cursor: Number(url.searchParams.get("cursor") ?? 0) || 0,
    push(out) {
      if (out.lines.length === 0) { state.cursor = out.cursor; return; }
      const frame = wsFrame(JSON.stringify({ ok: true, ...out }));
      if (socket.writableLength + frame.length > cfg.maxBody) {
        log.warn("socket", "websocket outbound buffer exceeded maxBody", roomRef(room));
        socket.destroy();
        return;
      }
      state.cursor = out.cursor;
      socket.write(frame);
    },
  };

  r.sockets.add(state);
  state.push(rooms.fetch(room, state.cursor));

  const handleTextMessage = (payload) => {
    const lines = payload.toString("utf8").split("\n").map((l) => l.trim()).filter((l) => l.length > 0);
    if (lines.some((l) => Buffer.byteLength(l, "utf8") > cfg.maxLine)) {
      log.warn("socket", "a line was too long", roomRef(room));
      socket.write(wsFrame(JSON.stringify({ ok: false, error: "line too long" })));
      return;
    }
    if (lines.length) rooms.post(room, lines);
  };

  let pending = Buffer.alloc(0);
  let fragChunks = [];
  let fragBytes = 0;
  let inTextFrag = false;

  socket.on("data", (chunk) => {
    if (pending.length + chunk.length > cfg.maxBody) {
      log.warn("socket", "websocket buffer exceeded maxBody", roomRef(room));
      socket.destroy();
      return;
    }
    pending = Buffer.concat([pending, chunk]);
    const { frames, used, oversized } = wsFrames(pending, cfg.maxBody);
    if (oversized) {
      log.warn("socket", "websocket frame exceeded maxBody", roomRef(room));
      socket.destroy();
      return;
    }
    pending = pending.subarray(used);
    for (const { fin, opcode, data } of frames) {
      if (opcode === 0x8) { socket.end(); return; }
      if (opcode === 0x9 && data.length <= 125) {
        socket.write(Buffer.concat([Buffer.from([0x8a, data.length]), data]));
        continue;
      }
      if (opcode === 0x1) {
        if (inTextFrag) {
          socket.destroy();
          return;
        }
        if (fin) {
          handleTextMessage(data);
        } else {
          inTextFrag = true;
          fragChunks = [data];
          fragBytes = data.length;
        }
      } else if (opcode === 0x0) {
        if (!inTextFrag || fragBytes + data.length > cfg.maxBody) {
          socket.destroy();
          return;
        }
        fragChunks.push(data);
        fragBytes += data.length;
        if (fin) {
          const full = Buffer.concat(fragChunks);
          fragChunks = [];
          fragBytes = 0;
          inTextFrag = false;
          handleTextMessage(full);
        }
      }
    }
  });

  const drop = () => {
    r.sockets.delete(state);
    if (r.lines.length === 0 && r.sockets.size === 0 && r.waiters.size === 0) {
      rooms.deleteRoom(String(room));
    }
  };
  socket.on("close", () => { log.info("socket", `a stream closed`, roomRef(room)); drop(); });
  socket.on("error", (e) => { log.error("socket", "a stream failed", e.message); drop(); });
  log.info("socket", `a stream opened`, roomRef(room));
}

// ------------------------------------------------------------------- main

if (isMain) {
  const server = createServer(CONFIG);
  server.listen(CONFIG.port, CONFIG.host, () => {
    console.log(`otc-desk relay ${CONFIG.version} listening on http://${CONFIG.host}:${CONFIG.port}`);
    console.log("  POST /room/{room}                    append lines");
    console.log("  GET  /room/{room}?cursor=N[&wait=S]  poll (long poll with wait)");
    console.log("  WS   /ws/{room}?cursor=N             stream");
    console.log("  GET  /desk/board                     get bounty board");
    console.log("  POST /desk/quote                     request quote");
    console.log("  POST /desk/ticket                    post trade ticket");
    console.log("  POST /desk/escrow                    deposit into escrow");
    console.log("  GET  /desk/escrow/{id}               get escrow state");
    console.log("  POST /desk/approve/promote           approve layer promotion");
    console.log("  GET  /desk/kb?q=                     query witnessed KB");
    console.log("  GET  /health                         health check");
    if (CONFIG.staticDir) console.log(`  serving ${path.resolve(CONFIG.staticDir)} at /`);
    if (CONFIG.logFile) console.log(`  writing the log to ${path.resolve(CONFIG.logFile)}`);
  });
}