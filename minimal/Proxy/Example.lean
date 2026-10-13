/-
  RequestProject.Proxy.Example

  A concrete sandboxed agent behind the logging proxy.

  Nine intercepted calls — file reads and writes, network connects, process
  spawns, a replay, a forged request and a stranger — are run through the
  monitor of `Proxy.Monitor` with the concrete hasher of `Proxy.Concrete`.
  Everything the prose claims about the run is then *checked by computation*:
  which calls reached the system, which were stopped and why, that the journal
  verifies, that the dashboard shows exactly one row per call, and that a single
  edited byte in the journal makes the dashboard go dark.
-/
import Proxy.Concrete

set_option maxRecDepth 100000
set_option maxHeartbeats 2000000

namespace Proxy
namespace Demo

open P2P (macTag)

/-- The sandbox policy. -/
def policy : Policy :=
  { admitted        := ["agent-A"]
  , readable        := ["/workspace/", "/etc/ssl/"]
  , writable        := ["/workspace/out/"]
  , allowedHosts    := [("api.internal", 443)]
  , allowedExes     := ["lake"]
  , allowNet        := true
  , allowProc       := true
  , maxBytesPerCall := 4096
  , byteBudget      := 100000 }

/-- The proxy at start of day: empty journal, nothing spent. -/
def proxy0 : Monitor :=
  { id         := "sandbox-proxy"
  , key        := 424242
  , policy     := policy
  , callerKeys := [("agent-A", 1001), ("agent-X", 1002)]
  , seen       := []
  , bytesUsed  := 0
  , genesis    := genesis0
  , log        := [] }

/-- A deterministic stand-in for the operating system. -/
def sys : System :=
  { perform := fun c =>
      match c.op with
      | .write   => .ok c.nbytes (hashString (encodeCall c))
      | .connect => .ok 0 (hashString (encodeResource c.resource))
      | .spawn   => .ok 0 0
      | _        => .ok c.nbytes (hashString (encodeCall c)) }

/-- A request signed with the caller's real key. -/
def req (caller : Principal) (key seq : Nat) (c : Syscall) : Request :=
  let b : RequestBody := { caller := caller, seq := seq, call := c }
  { body := b, auth := macTag caller key b }

/-! ### The trace -/

/-- 1. Read a file inside the sandbox — allowed. -/
def r1 : Request := req "agent-A" 1001 1 ⟨.read, .file "/workspace/data.txt", 128⟩
/-- 2. Write outside the writable prefix — denied. -/
def r2 : Request := req "agent-A" 1001 2 ⟨.write, .file "/etc/passwd", 64⟩
/-- 3. Write inside the writable prefix — allowed. -/
def r3 : Request := req "agent-A" 1001 3 ⟨.write, .file "/workspace/out/report.md", 512⟩
/-- 4. Connect to the allow-listed service — allowed. -/
def r4 : Request := req "agent-A" 1001 4 ⟨.connect, .net "api.internal" 443, 0⟩
/-- 5. Connect somewhere else — denied. -/
def r5 : Request := req "agent-A" 1001 5 ⟨.connect, .net "evil.example" 80, 0⟩
/-- 6. Spawn an allow-listed executable — allowed. -/
def r6 : Request := req "agent-A" 1001 6 ⟨.spawn, .proc "lake", 0⟩
/-- 7. Spawn something else — denied. -/
def r7 : Request := req "agent-A" 1001 7 ⟨.spawn, .proc "curl", 0⟩
/-- 8. Replay of request 1 — denied. -/
def r8 : Request := r1
/-- 9. A request from a caller who is not admitted — denied. -/
def r9 : Request := req "agent-X" 1002 1 ⟨.read, .file "/workspace/data.txt", 8⟩
/-- 10. A forged request: the right caller, the wrong key — denied. -/
def r10 : Request := req "agent-A" 9999 10 ⟨.read, .file "/workspace/data.txt", 8⟩

def trace : List Request := [r1, r2, r3, r4, r5, r6, r7, r8, r9, r10]

/-- The proxy after the whole trace. -/
def proxyN : Monitor := runAll fnvHasher sys proxy0 trace

/-- The dashboard for that run. -/
def dash : View := monitorView fnvHasher proxyN

/-! ### What actually happened, checked by computation -/

/-- The three in-policy calls reached the system; nothing else did. -/
example : (step fnvHasher sys proxy0 r1).2.isSome = true := by decide +kernel
example : (step fnvHasher sys proxy0 r2).2 = none := by decide +kernel
example : (step fnvHasher sys proxy0 r5).2 = none := by decide +kernel
example : (step fnvHasher sys proxy0 r7).2 = none := by decide +kernel
example : (step fnvHasher sys proxy0 r9).2 = none := by decide +kernel
example : (step fnvHasher sys proxy0 r10).2 = none := by decide +kernel

/-- The denials are recorded with the reason the policy actually gave. -/
example : (stepReceiptBody sys proxy0 r2).decision = .denied "forbidden by policy" := by
  decide +kernel
example : (stepReceiptBody sys proxy0 r9).decision = .denied "caller not admitted" := by
  decide +kernel
example : (stepReceiptBody sys proxy0 r10).decision = .denied "bad authentication" := by
  decide +kernel

/-- Every one of the ten calls left a receipt. -/
example : proxyN.log.length = 10 := by decide +kernel

/-- Four allowed, six denied. -/
example : dash.allowedCount = 4 := by decide +kernel
example : dash.deniedCount = 6 := by decide +kernel

/-- The journal verifies, so the dashboard is live … -/
example : dash.verified = true := by decide +kernel

/-- … and shows one row per intercepted call. -/
example : dash.rows.length = 10 := by decide +kernel

/-- The byte counter on screen is the proxy's own accounting. -/
example : dash.bytesMoved = proxyN.bytesUsed := by decide +kernel
example : dash.bytesMoved = 640 := by decide +kernel

/-- The replay of request 1 was refused. -/
example : (stepReceiptBody sys (runAll fnvHasher sys proxy0 [r1, r2, r3, r4, r5, r6, r7]) r8).decision
    = .denied "replayed sequence number" := by decide +kernel

/-- Tamper with the journal — here, rewrite the newest receipt so that it claims
    a different path — and the dashboard shows nothing at all. -/
def tamperedLog : Log :=
  match proxyN.log with
  | []        => []
  | r :: rest =>
      { r with body := { r.body with call := ⟨.read, .file "/etc/shadow", 1⟩ } } :: rest

example : validated fnvHasher proxy0.genesis proxy0.key tamperedLog = false := by decide +kernel
example : (view fnvHasher proxy0.genesis proxy0.key tamperedLog).rows = [] := by decide +kernel
example : (view fnvHasher proxy0.genesis proxy0.key tamperedLog).verified = false := by decide +kernel

/-- Dropping a receipt to hide a call is equally visible: the remaining journal
    no longer matches the published tip. -/
example : tip genesis0 proxyN.log ≠ tip genesis0 proxyN.log.tail := by decide +kernel

end Demo
end Proxy
