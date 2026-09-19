/-
  RequestProject.Proxy.Monitor

  The logging proxy itself: the wrapper that every system, file and network call
  is routed through.

  A call never reaches the operating system directly.  It arrives as an
  authenticated request, passes (or fails) a single admission gate, and — in
  *either* case — produces a receipt appended to the hash chain of
  `Proxy.Core`.  The theorems below are the security story of the wrapper:

    * complete mediation: every request, allowed or denied, is logged;
    * no effect without permission: if the system was touched at all, the caller
      was admitted, authenticated, fresh and within policy and budget;
    * denial is inert: a denied request spends no bytes and records no nonce;
    * the journal is append-only and stays chain-valid and monitor-signed;
    * the byte budget is never exceeded, over any number of calls.
-/
import RequestProject.Proxy.Core

namespace Proxy

open P2P (Tag macTag verifyTag keyOf)

/-- What the sandboxed program is allowed to do. -/
structure Policy where
  /-- Principals allowed to use the proxy at all. -/
  admitted        : List Principal
  /-- Path prefixes that may be read. -/
  readable        : List String
  /-- Path prefixes that may be written. -/
  writable        : List String
  /-- `(host, port)` pairs that may be contacted. -/
  allowedHosts    : List (String × Nat)
  /-- Executables that may be spawned. -/
  allowedExes     : List String
  /-- Master switch for all network calls. -/
  allowNet        : Bool
  /-- Master switch for all process calls. -/
  allowProc       : Bool
  /-- Largest number of bytes one call may move. -/
  maxBytesPerCall : Nat
  /-- Total bytes this proxy will ever move. -/
  byteBudget      : Nat

/-- Does some allowed prefix cover this path?  (Spelled out on character lists
    so that concrete policy decisions reduce inside the Lean kernel.) -/
def underPrefix (prefixes : List String) (path : String) : Bool :=
  prefixes.any (fun p => List.isPrefixOf p.toList path.toList)

/-- The policy decision on one call.  Note the catch-all: an operation applied
    to the wrong kind of resource (a `connect` on a file, a `read` on a process)
    is never permitted. -/
def permits (p : Policy) (c : Syscall) : Bool :=
  match c.op, c.resource with
  | .read,  .file path    => underPrefix p.readable path
  | .write, .file path    => underPrefix p.writable path
  | .stat,  .file path    => underPrefix p.readable path || underPrefix p.writable path
  | .connect, .net h port => p.allowNet && p.allowedHosts.contains (h, port)
  | .send,    .net h port => p.allowNet && p.allowedHosts.contains (h, port)
  | .recv,    .net h port => p.allowNet && p.allowedHosts.contains (h, port)
  | .spawn,   .proc e     => p.allowProc && p.allowedExes.contains e
  | _, _                  => false

/-- The live state of the proxy. -/
structure Monitor where
  id         : Principal
  /-- Signing key for receipts. -/
  key        : Nat
  policy     : Policy
  /-- Keys shared with callers, used to authenticate requests. -/
  callerKeys : List (Principal × Nat)
  /-- `(caller, seq)` pairs already served, for replay protection. -/
  seen       : List (Principal × Nat)
  bytesUsed  : Nat
  genesis    : Nat
  log        : Log

/-- The real world behind the proxy: performing a call has an outcome. -/
structure System where
  perform : Syscall → Outcome

/-- Is the request authenticated under the caller's shared key? -/
def authenticated (m : Monitor) (r : Request) : Bool :=
  match keyOf m.callerKeys r.body.caller with
  | none   => false
  | some k => verifyTag r.body.caller k r.body r.auth

/-- Has this `(caller, seq)` pair been used before? -/
def fresh (m : Monitor) (b : RequestBody) : Bool :=
  !(m.seen.contains (b.caller, b.seq))

/-- The single admission gate.  Nothing reaches the system except through it. -/
def admits (m : Monitor) (r : Request) : Bool :=
  m.policy.admitted.contains r.body.caller &&
  authenticated m r &&
  fresh m r.body &&
  permits m.policy r.body.call &&
  (r.body.call.nbytes ≤ m.policy.maxBytesPerCall) &&
  (m.bytesUsed + r.body.call.nbytes ≤ m.policy.byteBudget)

/-- Why a request was turned away (recorded in the receipt). -/
def denyReason (m : Monitor) (r : Request) : String :=
  if !m.policy.admitted.contains r.body.caller then "caller not admitted"
  else if !authenticated m r then "bad authentication"
  else if !fresh m r.body then "replayed sequence number"
  else if !permits m.policy r.body.call then "forbidden by policy"
  else if !(r.body.call.nbytes ≤ m.policy.maxBytesPerCall) then "over per-call byte cap"
  else "over total byte budget"

/-- The receipt body the proxy writes for a request. -/
def receiptFor (m : Monitor) (r : Request) (d : Decision) (o : Option Outcome)
    (prev : Nat) : ReceiptBody :=
  { index    := m.log.length
  , monitor  := m.id
  , caller   := r.body.caller
  , seq      := r.body.seq
  , call     := r.body.call
  , decision := d
  , outcome  := o
  , prevHash := prev }

@[simp] theorem receiptFor_prevHash (m : Monitor) (r : Request) (d : Decision)
    (o : Option Outcome) (prev : Nat) : (receiptFor m r d o prev).prevHash = prev := rfl

/-- One trip through the proxy: gate, (maybe) perform, always log. -/
def step (H : Hasher) (sys : System) (m : Monitor) (r : Request) :
    Monitor × Option Outcome :=
  if admits m r then
    let o := sys.perform r.body.call
    ( { m with
          seen      := (r.body.caller, r.body.seq) :: m.seen
        , bytesUsed := m.bytesUsed + r.body.call.nbytes
        , log       := appendReceipt H m.genesis m.key m.log
                         (receiptFor m r .allowed (some o)) }
    , some o )
  else
    ( { m with
          log := appendReceipt H m.genesis m.key m.log
                   (receiptFor m r (.denied (denyReason m r)) none) }
    , none )

/-! ### Complete mediation and append-only logging -/

/-- Every request produces exactly one new receipt, at the front of the log,
    leaving the existing log untouched. -/
theorem step_append_only (H : Hasher) (sys : System) (m : Monitor) (r : Request) :
    ∃ rec, (step H sys m r).1.log = rec :: m.log := by
  unfold step
  by_cases h : admits m r <;> simp [h, appendReceipt]

/-- The log grows by exactly one entry per call: nothing is dropped, nothing is
    batched away. -/
theorem step_log_length (H : Hasher) (sys : System) (m : Monitor) (r : Request) :
    (step H sys m r).1.log.length = m.log.length + 1 := by
  obtain ⟨rec, h⟩ := step_append_only H sys m r
  simp [h]

/-- The receipt body the proxy writes for a request: allowed with the outcome,
    or denied with the reason. -/
def stepReceiptBody (sys : System) (m : Monitor) (r : Request) : ReceiptBody :=
  if admits m r then
    receiptFor m r .allowed (some (sys.perform r.body.call)) (tip m.genesis m.log)
  else
    receiptFor m r (.denied (denyReason m r)) none (tip m.genesis m.log)

/-- The shape of the log after a step: the step's receipt, then the old log. -/
theorem step_log_eq (H : Hasher) (sys : System) (m : Monitor) (r : Request) :
    ∃ sg, (step H sys m r).1.log =
      { body := stepReceiptBody sys m r
      , hash := H.hash (tip m.genesis m.log) (stepReceiptBody sys m r)
      , sig  := sg } :: m.log := by
  unfold step stepReceiptBody appendReceipt
  by_cases h : admits m r <;> simp [h, receiptFor]

/-- Complete mediation: whatever happens, the receipt of the step names this
    caller, this sequence number and this exact call. -/
theorem stepReceiptBody_describes_request (sys : System) (m : Monitor) (r : Request) :
    (stepReceiptBody sys m r).caller = r.body.caller ∧
    (stepReceiptBody sys m r).seq = r.body.seq ∧
    (stepReceiptBody sys m r).call = r.body.call ∧
    (stepReceiptBody sys m r).monitor = m.id ∧
    (stepReceiptBody sys m r).index = m.log.length := by
  unfold stepReceiptBody
  by_cases h : admits m r <;> simp [h, receiptFor]

/-- An allowed call is logged as allowed, with its outcome; the receipt is the
    evidence that the effect happened. -/
theorem stepReceiptBody_allowed {sys : System} {m : Monitor} {r : Request}
    (h : admits m r = true) :
    (stepReceiptBody sys m r).decision = .allowed ∧
    (stepReceiptBody sys m r).outcome = some (sys.perform r.body.call) := by
  simp [stepReceiptBody, h, receiptFor]

/-- A denied call is logged as denied, with no outcome at all. -/
theorem stepReceiptBody_denied {sys : System} {m : Monitor} {r : Request}
    (h : admits m r = false) :
    (stepReceiptBody sys m r).decision = .denied (denyReason m r) ∧
    (stepReceiptBody sys m r).outcome = none := by
  simp [stepReceiptBody, h, receiptFor]

/-- Stepping preserves chain validity. -/
theorem step_chainOk {H : Hasher} {sys : System} {m : Monitor} {r : Request}
    (h : chainOk H m.genesis m.log = true) :
    chainOk H (step H sys m r).1.genesis (step H sys m r).1.log = true := by
  unfold step
  by_cases ha : admits m r <;>
    simp only [ha, if_true] <;>
    exact appendReceipt_chainOk (fun _ => rfl) h

/-- Stepping preserves the fact that every receipt is signed by the monitor. -/
theorem step_signedOk {H : Hasher} {sys : System} {m : Monitor} {r : Request}
    (h : signedOk m.key m.log = true) :
    signedOk (step H sys m r).1.key (step H sys m r).1.log = true := by
  unfold step
  by_cases ha : admits m r <;>
    simp_all [signedOk, appendReceipt, receiptFor]

/-! ### No effect without permission -/

/-- Everything the gate guarantees, spelled out. -/
theorem admits_components {m : Monitor} {r : Request} (h : admits m r = true) :
    r.body.caller ∈ m.policy.admitted ∧
    authenticated m r = true ∧
    fresh m r.body = true ∧
    permits m.policy r.body.call = true ∧
    r.body.call.nbytes ≤ m.policy.maxBytesPerCall ∧
    m.bytesUsed + r.body.call.nbytes ≤ m.policy.byteBudget := by
  simp only [admits, Bool.and_eq_true, decide_eq_true_eq, List.contains_iff_mem] at h
  obtain ⟨⟨⟨⟨⟨h1, h2⟩, h3⟩, h4⟩, h5⟩, h6⟩ := h
  exact ⟨h1, h2, h3, h4, h5, h6⟩

/-- The central guarantee: if the system was touched, the call had passed the
    whole gate — admitted, authenticated, fresh, permitted, in budget. -/
theorem effect_implies_permitted {H : Hasher} {sys : System} {m : Monitor}
    {r : Request} {o : Outcome} (h : (step H sys m r).2 = some o) :
    r.body.caller ∈ m.policy.admitted ∧
    authenticated m r = true ∧
    fresh m r.body = true ∧
    permits m.policy r.body.call = true ∧
    r.body.call.nbytes ≤ m.policy.maxBytesPerCall ∧
    m.bytesUsed + r.body.call.nbytes ≤ m.policy.byteBudget := by
  refine admits_components ?_
  by_cases ha : admits m r
  · exact ha
  · simp [step, ha] at h

/-- Denial is inert: no outcome, no bytes spent, no sequence number burned, and
    the only change to the proxy is the receipt that records the denial. -/
theorem denied_no_effect {H : Hasher} {sys : System} {m : Monitor} {r : Request}
    (h : admits m r = false) :
    (step H sys m r).2 = none ∧
    (step H sys m r).1.bytesUsed = m.bytesUsed ∧
    (step H sys m r).1.seen = m.seen := by
  simp [step, h]

/-- An unauthenticated caller never reaches the system. -/
theorem unauthenticated_no_effect {H : Hasher} {sys : System} {m : Monitor}
    {r : Request} (h : authenticated m r = false) : (step H sys m r).2 = none := by
  refine (denied_no_effect (H := H) (sys := sys) ?_).1
  simp [admits, h]

/-- A write outside the writable prefixes never happens. -/
theorem forbidden_write_no_effect {H : Hasher} {sys : System} {m : Monitor}
    {r : Request} {path : String}
    (hcall : r.body.call.op = .write ∧ r.body.call.resource = .file path)
    (hpath : underPrefix m.policy.writable path = false) :
    (step H sys m r).2 = none := by
  refine (denied_no_effect (H := H) (sys := sys) ?_).1
  by_cases ha : admits m r
  · have hp := (admits_components ha).2.2.2.1
    simp [permits, hcall.1, hcall.2, hpath] at hp
  · simpa using ha

/-- With networking switched off, no network call ever happens. -/
theorem no_net_when_disabled {H : Hasher} {sys : System} {m : Monitor}
    {r : Request} {host : String} {port : Nat}
    (hres : r.body.call.resource = .net host port)
    (hoff : m.policy.allowNet = false) :
    (step H sys m r).2 = none := by
  refine (denied_no_effect (H := H) (sys := sys) ?_).1
  by_cases ha : admits m r
  · have hp := (admits_components ha).2.2.2.1
    cases hop : r.body.call.op <;>
      simp [permits, hres, hop, hoff] at hp
  · simpa using ha

/-- An executable outside the allow list is never spawned. -/
theorem unlisted_exe_no_effect {H : Hasher} {sys : System} {m : Monitor}
    {r : Request} {exe : String}
    (hcall : r.body.call.op = .spawn ∧ r.body.call.resource = .proc exe)
    (hlist : exe ∉ m.policy.allowedExes) :
    (step H sys m r).2 = none := by
  refine (denied_no_effect (H := H) (sys := sys) ?_).1
  by_cases ha : admits m r
  · have hp := (admits_components ha).2.2.2.1
    simp only [permits, hcall.1, hcall.2, Bool.and_eq_true,
      List.contains_iff_mem] at hp
    exact absurd hp.2 hlist
  · simpa using ha

/-- Replay protection: repeating a `(caller, seq)` pair that was already served
    has no effect on the system. -/
theorem replay_no_effect {H : Hasher} {sys : System} {m : Monitor} {r : Request}
    {o : Outcome} (h : (step H sys m r).2 = some o) :
    (step H sys (step H sys m r).1 r).2 = none := by
  have hseen : ((step H sys m r).1).seen = (r.body.caller, r.body.seq) :: m.seen := by
    by_cases ha : admits m r
    · simp [step, ha]
    · simp [step, ha] at h
  refine (denied_no_effect (H := H) (sys := sys) ?_).1
  by_cases ha : admits (step H sys m r).1 r
  · have := (admits_components ha).2.2.1
    rw [fresh, hseen] at this
    simp at this
  · simpa using ha

/-! ### Budget invariant, over one call and over many -/

/-- One call never pushes the proxy past its byte budget. -/
theorem step_budget {H : Hasher} {sys : System} {m : Monitor} {r : Request}
    (hinv : m.bytesUsed ≤ m.policy.byteBudget) :
    (step H sys m r).1.bytesUsed ≤ (step H sys m r).1.policy.byteBudget := by
  unfold step
  by_cases ha : admits m r
  · have := (admits_components ha).2.2.2.2.2
    simpa [ha] using this
  · simpa [ha] using hinv

/-- Run a whole sequence of intercepted calls. -/
def runAll (H : Hasher) (sys : System) (m : Monitor) : List Request → Monitor
  | []      => m
  | r :: rs => runAll H sys (step H sys m r).1 rs

/-- The budget invariant holds for every trace, of any length. -/
theorem runAll_budget (H : Hasher) (sys : System) :
    ∀ (rs : List Request) (m : Monitor), m.bytesUsed ≤ m.policy.byteBudget →
      (runAll H sys m rs).bytesUsed ≤ (runAll H sys m rs).policy.byteBudget
  | [],      _, h => h
  | _ :: rs, _, h => runAll_budget H sys rs _ (step_budget h)

/-- Every trace leaves a chain-valid log. -/
theorem runAll_chainOk (H : Hasher) (sys : System) :
    ∀ (rs : List Request) (m : Monitor), chainOk H m.genesis m.log = true →
      chainOk H (runAll H sys m rs).genesis (runAll H sys m rs).log = true
  | [],      _, h => h
  | _ :: rs, _, h => runAll_chainOk H sys rs _ (step_chainOk h)

/-- Every trace leaves a fully signed log. -/
theorem runAll_signedOk (H : Hasher) (sys : System) :
    ∀ (rs : List Request) (m : Monitor), signedOk m.key m.log = true →
      signedOk (runAll H sys m rs).key (runAll H sys m rs).log = true
  | [],      _, h => h
  | _ :: rs, _, h => runAll_signedOk H sys rs _ (step_signedOk h)

/-- Exactly one receipt per intercepted call — no call goes unlogged, and the
    log contains nothing else. -/
theorem runAll_log_length (H : Hasher) (sys : System) :
    ∀ (rs : List Request) (m : Monitor),
      (runAll H sys m rs).log.length = m.log.length + rs.length
  | [],      m => by simp [runAll]
  | r :: rs, m => by
      have := runAll_log_length H sys rs (step H sys m r).1
      simp [runAll, this, step_log_length, List.length_cons, Nat.add_right_comm,
        Nat.add_assoc]

end Proxy
