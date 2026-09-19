/-
  RequestProject.Protocol.Core

  Shared vocabulary for *certified peer-to-peer calls to a Lean 4 prover or to
  executables it produced*.

  A peer asks another peer to run a job: check a proof obligation with the
  kernel, re-check a compiled proof artifact, or run an executable that the
  prover emitted.  The answer never travels alone: it travels as a
  **certificate** — a record naming the caller, the callee, the nonce, the job,
  the outcome and whether the Lean kernel accepted the result — authenticated
  with a message tag under the callee's key.

  Cryptography is modelled idealised: a tag literally carries the signing key
  and the exact payload it covers, so
    * a peer that does not hold the key cannot produce a verifying tag, and
    * a verifying tag pins down the payload exactly (no collisions).
  Everything downstream is then proved, not assumed.
-/

namespace P2P

/-- Peer names (prover nodes, clients, relays). -/
abbrev PeerId := String

/-- Per-call anti-replay counter, chosen by the caller. -/
abbrev Nonce := Nat

/-- Content digest of a source file, argv vector or output blob. -/
abbrev Digest := Nat

/-- The work a peer can ask a prover node to do. -/
inductive Job where
  /-- Elaborate `declName` in `moduleName` from source with the given digest and
      have the Lean kernel check it. -/
  | proveGoal (moduleName declName : String) (sourceDigest : Digest) : Job
  /-- Re-check an already produced proof artifact. -/
  | checkProof (artifactDigest : Digest) : Job
  /-- Run an executable produced by the prover on the given arguments. -/
  | runExe (exeName : String) (argvDigest : Digest) : Job
  deriving DecidableEq, Repr, Inhabited

/-- What came back from running a job. -/
inductive Outcome where
  /-- The declaration was proved; the list records the axioms it depends on. -/
  | proved (axioms : List String) : Outcome
  /-- The job was run but did not succeed. -/
  | failed (reason : String) : Outcome
  /-- An executable terminated with this exit code and output digest. -/
  | exited (code : Nat) (outDigest : Digest) : Outcome
  deriving DecidableEq, Repr, Inhabited

/-- An idealised message authentication tag over a payload of type `α`.
    Holding a verifying tag is exactly the ability to exhibit the signer's key
    together with the covered payload. -/
structure Tag (α : Type) where
  signer  : PeerId
  key     : Nat
  payload : α
  deriving DecidableEq, Repr

/-- Produce a tag (only a key holder can do this honestly). -/
def macTag {α : Type} (signer : PeerId) (key : Nat) (payload : α) : Tag α :=
  { signer := signer, key := key, payload := payload }

/-- Check a tag against an expected signer, key and payload. -/
def verifyTag {α : Type} [DecidableEq α]
    (signer : PeerId) (key : Nat) (payload : α) (t : Tag α) : Bool :=
  (t.signer == signer) && (t.key == key) && (t.payload == payload)

@[simp] theorem verifyTag_macTag {α : Type} [DecidableEq α]
    (signer : PeerId) (key : Nat) (payload : α) :
    verifyTag signer key payload (macTag signer key payload) = true := by
  simp [verifyTag, macTag]

/-- A verifying tag can only be held by someone who knows the key: forging
    without the key is impossible in this model. -/
theorem verifyTag_key {α : Type} [DecidableEq α]
    {signer : PeerId} {key : Nat} {payload : α} {t : Tag α}
    (h : verifyTag signer key payload t = true) : t.key = key := by
  simp [verifyTag] at h
  exact h.1.2

/-- A verifying tag pins down the payload exactly: no substitution by a relay. -/
theorem verifyTag_payload {α : Type} [DecidableEq α]
    {signer : PeerId} {key : Nat} {payload : α} {t : Tag α}
    (h : verifyTag signer key payload t = true) : t.payload = payload := by
  simp [verifyTag] at h
  exact h.2

/-- A verifying tag names the expected signer. -/
theorem verifyTag_signer {α : Type} [DecidableEq α]
    {signer : PeerId} {key : Nat} {payload : α} {t : Tag α}
    (h : verifyTag signer key payload t = true) : t.signer = signer := by
  simp [verifyTag] at h
  exact h.1.1

/-- The body of a call: who calls whom, with which nonce, for which job, under
    which fuel (resource) budget. -/
structure CallBody where
  client     : PeerId
  server     : PeerId
  nonce      : Nonce
  job        : Job
  fuelBudget : Nat
  deriving DecidableEq, Repr

/-- An authenticated call. -/
structure Call where
  body : CallBody
  auth : Tag CallBody
  deriving DecidableEq, Repr

/-- The certified answer to a call. -/
structure Certificate where
  server        : PeerId
  client        : PeerId
  nonce         : Nonce
  job           : Job
  outcome       : Outcome
  /-- `true` exactly when the Lean kernel accepted the result. -/
  kernelChecked : Bool
  fuelUsed      : Nat
  deriving DecidableEq, Repr

/-- What a prover node sends back. -/
inductive Response where
  | rejected (reason : String) : Response
  | certified (cert : Certificate) (tag : Tag Certificate) : Response
  deriving DecidableEq, Repr

/-- Key lookup in an association list of peer keys. -/
def keyOf (keys : List (PeerId × Nat)) (p : PeerId) : Option Nat :=
  (keys.find? (fun kv => kv.1 == p)).map Prod.snd

end P2P
