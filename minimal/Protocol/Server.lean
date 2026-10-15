/-
  RequestProject.Protocol.Server

  The *protected* side of a certified peer-to-peer prover call.

  A prover node exposes the Lean kernel (and executables the prover produced) to
  the network.  Every incoming call passes an admission gate before any work is
  done.  The gate checks, in one place:

    * the call is addressed to this node,
    * the caller is on the admission list,
    * the call is authenticated under the caller's key,
    * the nonce has not been seen before (no replay),
    * the job itself is permitted by policy (in particular, running executables
      can be switched off entirely, and only allow-listed executables ever run),
    * the requested fuel fits both the per-call cap and the node's remaining
      budget.

  The theorems below say the gate is the only way in: no admission, no
  execution, no certificate, and no state change.
-/
import Protocol.Core

namespace P2P

/-- The prover node's protection policy. -/
structure Policy where
  /-- Peers allowed to call this node at all. -/
  admittedPeers  : List PeerId
  /-- Executables this node is willing to run. -/
  allowedExes    : List String
  /-- Master switch for running executables (proof checking is unaffected). -/
  allowExeCalls  : Bool
  /-- Largest fuel budget a single call may request. -/
  maxFuelPerCall : Nat
  /-- Total fuel the node will ever spend. -/
  fuelBudget     : Nat

/-- The mutable state of a prover node. -/
structure Server where
  id         : PeerId
  /-- The node's own signing key; certificates are tagged with it. -/
  key        : Nat
  policy     : Policy
  /-- Keys shared with admitted callers, used to authenticate calls. -/
  clientKeys : List (PeerId × Nat)
  /-- Caller/nonce pairs already served. -/
  seen       : List (PeerId × Nonce)
  fuelUsed   : Nat

/-- The local prover/execution back end: running a job with a fuel budget
    produces an outcome, and reports whether the Lean kernel accepted it. -/
structure Runtime where
  run           : Job → Nat → Outcome
  kernelChecked : Job → Nat → Bool

/-- Is this job permitted by policy? -/
def jobAllowed (p : Policy) : Job → Bool
  | .proveGoal _ _ _ => true
  | .checkProof _    => true
  | .runExe e _      => p.allowExeCalls && p.allowedExes.contains e

/-- Is the call authenticated under the caller's shared key? -/
def authenticated (s : Server) (c : Call) : Bool :=
  match keyOf s.clientKeys c.body.client with
  | none   => false
  | some k => verifyTag c.body.client k c.body c.auth

/-- Has this caller/nonce pair been served already? -/
def fresh (s : Server) (b : CallBody) : Bool :=
  !(s.seen.contains (b.client, b.nonce))

/-- The admission gate. -/
def admits (s : Server) (c : Call) : Bool :=
  (c.body.server == s.id) &&
  s.policy.admittedPeers.contains c.body.client &&
  authenticated s c &&
  fresh s c.body &&
  jobAllowed s.policy c.body.job &&
  (c.body.fuelBudget ≤ s.policy.maxFuelPerCall) &&
  (s.fuelUsed + c.body.fuelBudget ≤ s.policy.fuelBudget)

/-- Serve one call.  Work happens only behind the gate. -/
def handle (rt : Runtime) (s : Server) (c : Call) : Server × Response :=
  if admits s c then
    let outcome := rt.run c.body.job c.body.fuelBudget
    let cert : Certificate :=
      { server        := s.id
      , client        := c.body.client
      , nonce         := c.body.nonce
      , job           := c.body.job
      , outcome       := outcome
      , kernelChecked := rt.kernelChecked c.body.job c.body.fuelBudget
      , fuelUsed      := c.body.fuelBudget }
    ( { s with seen := (c.body.client, c.body.nonce) :: s.seen
             , fuelUsed := s.fuelUsed + c.body.fuelBudget }
    , .certified cert (macTag s.id s.key cert) )
  else
    (s, .rejected "not admitted")

/-! ### Protection theorems -/

/-- Everything the admission gate guarantees, spelled out. -/
theorem admits_components {s : Server} {c : Call} (h : admits s c = true) :
    c.body.server = s.id ∧
    c.body.client ∈ s.policy.admittedPeers ∧
    authenticated s c = true ∧
    fresh s c.body = true ∧
    jobAllowed s.policy c.body.job = true ∧
    c.body.fuelBudget ≤ s.policy.maxFuelPerCall ∧
    s.fuelUsed + c.body.fuelBudget ≤ s.policy.fuelBudget := by
  simp only [admits, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq,
    List.contains_iff_mem] at h
  obtain ⟨⟨⟨⟨⟨⟨h1, h2⟩, h3⟩, h4⟩, h5⟩, h6⟩, h7⟩ := h
  exact ⟨h1, h2, h3, h4, h5, h6, h7⟩

/-- Nothing is certified unless the gate admitted the call. -/
theorem certified_implies_admitted {rt : Runtime} {s : Server} {c : Call}
    {cert : Certificate} {tag : Tag Certificate}
    (h : (handle rt s c).2 = .certified cert tag) : admits s c = true := by
  unfold handle at h
  by_cases hA : admits s c
  · exact hA
  · simp [hA] at h

/-- A rejected call leaves the node's state completely untouched: no fuel is
    spent and no nonce is recorded. -/
theorem rejected_state_unchanged {rt : Runtime} {s : Server} {c : Call}
    (h : admits s c = false) : handle rt s c = (s, .rejected "not admitted") := by
  simp [handle, h]

/-- An unauthenticated call is always rejected. -/
theorem unauthenticated_rejected {rt : Runtime} {s : Server} {c : Call}
    (h : authenticated s c = false) :
    handle rt s c = (s, .rejected "not admitted") := by
  refine rejected_state_unchanged ?_
  simp [admits, h]

/-- A caller who is not on the admission list is always rejected. -/
theorem unlisted_peer_rejected {rt : Runtime} {s : Server} {c : Call}
    (h : c.body.client ∉ s.policy.admittedPeers) :
    handle rt s c = (s, .rejected "not admitted") := by
  refine rejected_state_unchanged ?_
  by_cases hA : admits s c
  · exact absurd (admits_components hA).2.1 h
  · simpa using hA

/-- With executable calls switched off, only proof work is ever served. -/
theorem no_exe_when_disabled {rt : Runtime} {s : Server} {c : Call}
    {e : String} {argv : Digest}
    (hjob : c.body.job = .runExe e argv)
    (hoff : s.policy.allowExeCalls = false) :
    handle rt s c = (s, .rejected "not admitted") := by
  refine rejected_state_unchanged ?_
  by_cases hA : admits s c
  · have hj := (admits_components hA).2.2.2.2.1
    rw [hjob] at hj
    simp [jobAllowed, hoff] at hj
  · simpa using hA

/-- Executables outside the allow list never run. -/
theorem unlisted_exe_rejected {rt : Runtime} {s : Server} {c : Call}
    {e : String} {argv : Digest}
    (hjob : c.body.job = .runExe e argv)
    (hlist : e ∉ s.policy.allowedExes) :
    handle rt s c = (s, .rejected "not admitted") := by
  refine rejected_state_unchanged ?_
  by_cases hA : admits s c
  · have hj := (admits_components hA).2.2.2.2.1
    rw [hjob] at hj
    simp [jobAllowed] at hj
    exact absurd hj.2 hlist
  · simpa using hA

/-- Anything that *is* executed is an allow-listed executable, or pure proof
    work.  This is the positive form of the two theorems above. -/
theorem executed_exe_is_allowed {rt : Runtime} {s : Server} {c : Call}
    {cert : Certificate} {tag : Tag Certificate}
    {e : String} {argv : Digest}
    (h : (handle rt s c).2 = .certified cert tag)
    (hjob : c.body.job = .runExe e argv) :
    s.policy.allowExeCalls = true ∧ e ∈ s.policy.allowedExes := by
  have hj := (admits_components (certified_implies_admitted h)).2.2.2.2.1
  rw [hjob] at hj
  simpa [jobAllowed, List.contains_iff_mem] using hj

/-- A served call is never over the per-call fuel cap, and never pushes the node
    past its total budget. -/
theorem certified_respects_fuel {rt : Runtime} {s : Server} {c : Call}
    {cert : Certificate} {tag : Tag Certificate}
    (h : (handle rt s c).2 = .certified cert tag) :
    c.body.fuelBudget ≤ s.policy.maxFuelPerCall ∧
    s.fuelUsed + c.body.fuelBudget ≤ s.policy.fuelBudget := by
  have hA := admits_components (certified_implies_admitted h)
  exact ⟨hA.2.2.2.2.2.1, hA.2.2.2.2.2.2⟩

/-- The node's total spend never exceeds its budget. -/
theorem fuel_invariant (rt : Runtime) (s : Server) (c : Call)
    (hinv : s.fuelUsed ≤ s.policy.fuelBudget) :
    (handle rt s c).1.fuelUsed ≤ (handle rt s c).1.policy.fuelBudget := by
  unfold handle
  by_cases hA : admits s c
  · have hfuel : s.fuelUsed + c.body.fuelBudget ≤ s.policy.fuelBudget :=
      (admits_components hA).2.2.2.2.2.2
    simpa [hA] using hfuel
  · simpa [hA] using hinv

/-- Serving a call records its nonce. -/
theorem handle_records_nonce {rt : Runtime} {s : Server} {c : Call}
    {cert : Certificate} {tag : Tag Certificate}
    (h : (handle rt s c).2 = .certified cert tag) :
    (c.body.client, c.body.nonce) ∈ (handle rt s c).1.seen := by
  have hA := certified_implies_admitted h
  simp [handle, hA]

/-- Replay protection: the very same call, presented a second time, is rejected
    and changes nothing. -/
theorem replay_rejected (rt : Runtime) (s : Server) (c : Call)
    {cert : Certificate} {tag : Tag Certificate}
    (h : (handle rt s c).2 = .certified cert tag) :
    (handle rt (handle rt s c).1 c).2 = .rejected "not admitted" := by
  have hA := certified_implies_admitted h
  have hmem : (c.body.client, c.body.nonce) ∈ (handle rt s c).1.seen :=
    handle_records_nonce h
  have hfresh : fresh (handle rt s c).1 c.body = false := by
    simp [fresh, hmem]
  have hno : admits (handle rt s c).1 c = false := by
    by_cases hA2 : admits (handle rt s c).1 c
    · have := (admits_components hA2).2.2.2.1
      rw [hfresh] at this
      exact absurd this (by simp)
    · simpa using hA2
  rw [rejected_state_unchanged (rt := rt) hno]

/-- The certificate a node emits always describes the call it answered. -/
theorem certificate_binds_call {rt : Runtime} {s : Server} {c : Call}
    {cert : Certificate} {tag : Tag Certificate}
    (h : (handle rt s c).2 = .certified cert tag) :
    cert.server = s.id ∧ cert.client = c.body.client ∧
    cert.nonce = c.body.nonce ∧ cert.job = c.body.job ∧
    cert.outcome = rt.run c.body.job c.body.fuelBudget ∧
    cert.kernelChecked = rt.kernelChecked c.body.job c.body.fuelBudget ∧
    tag = macTag s.id s.key cert := by
  have hA := certified_implies_admitted h
  unfold handle at h
  simp only [hA, if_true] at h
  injection h with hcert htag
  subst hcert
  subst htag
  exact ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

end P2P
