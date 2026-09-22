/-
  RequestProject.Proxy.Core

  Vocabulary for the **logging proxy**: a wrapper that every system call, file
  call and network call of a sandboxed program must go through.

  The proxy is a reference monitor with a tamper-evident journal:

    * a *request* names the calling principal, a per-caller sequence number and
      the syscall it wants to make, authenticated with a tag under the caller's
      key (the same idealised MAC used by `RequestProject.Protocol`);
    * every request — allowed or denied — produces a *receipt*;
    * receipts are chained: each one commits to the hash of the previous one, so
      the hash of the newest receipt commits to the entire history.

  This file fixes the data and proves the properties of the chain itself.
  `Proxy.Monitor` adds the admission gate and the effects, `Proxy.Dashboard`
  the validated view.
-/
import Protocol.Core

namespace Proxy

open P2P (Tag macTag verifyTag keyOf)

/-- Who is making the call (a program, an agent, a tool). -/
abbrev Principal := String

/-- The resource a syscall touches. -/
inductive Resource where
  | file (path : String)              : Resource
  | net  (host : String) (port : Nat) : Resource
  | proc (exe : String)               : Resource
  deriving DecidableEq, Repr, Inhabited

/-- The operation requested.  `read`/`write`/`stat` are file operations,
    `connect`/`send`/`recv` network operations, `spawn` a process operation. -/
inductive Op where
  | read | write | stat | connect | send | recv | spawn
  deriving DecidableEq, Repr, Inhabited

/-- One intercepted call: an operation on a resource, with the number of bytes
    it wants to move (`0` for calls that move no data). -/
structure Syscall where
  op       : Op
  resource : Resource
  nbytes   : Nat
  deriving DecidableEq, Repr, Inhabited

/-- What the underlying system returned, if the call was let through. -/
inductive Outcome where
  /-- Succeeded, moving `bytes` bytes, with the given digest of the payload. -/
  | ok (bytes : Nat) (digest : Nat) : Outcome
  /-- The system refused (errno-style code). -/
  | error (code : Nat)              : Outcome
  deriving DecidableEq, Repr, Inhabited

/-- The proxy's ruling on a request. -/
inductive Decision where
  | allowed                  : Decision
  | denied (reason : String) : Decision
  deriving DecidableEq, Repr, Inhabited

/-- The body of a request. -/
structure RequestBody where
  caller : Principal
  seq    : Nat
  call   : Syscall
  deriving DecidableEq, Repr, Inhabited

/-- An authenticated request arriving at the proxy. -/
structure Request where
  body : RequestBody
  auth : Tag RequestBody
  deriving DecidableEq, Repr

/-! ### Receipts and the hash chain -/

/-- What a receipt records.  `prevHash` links it to the receipt before it. -/
structure ReceiptBody where
  index    : Nat
  monitor  : Principal
  caller   : Principal
  seq      : Nat
  call     : Syscall
  decision : Decision
  /-- `none` exactly when the call was never performed. -/
  outcome  : Option Outcome
  prevHash : Nat
  deriving DecidableEq, Repr, Inhabited

/-- A signed, chained log entry. -/
structure Receipt where
  body : ReceiptBody
  /-- Always `H.hash body.prevHash body` for the log's hasher `H`. -/
  hash : Nat
  sig  : Tag ReceiptBody
  deriving DecidableEq, Repr

/-- The hash function used to chain receipts, kept abstract. -/
structure Hasher where
  hash : Nat → ReceiptBody → Nat

/-- Collision freedom: the hash of `(prev, body)` determines both.  This is the
    standard idealisation of a cryptographic hash; it is never assumed silently,
    only taken as an explicit hypothesis where it is needed. -/
def Hasher.CollisionFree (H : Hasher) : Prop :=
  ∀ p b p' b', H.hash p b = H.hash p' b' → p = p' ∧ b = b'

/-- The genesis value of a chain is not in the range of the hash (it is a
    distinguished constant, not a digest). -/
def Hasher.GenesisFresh (H : Hasher) (genesis : Nat) : Prop :=
  ∀ p b, H.hash p b ≠ genesis

/-- The log is kept newest-first. -/
abbrev Log := List Receipt

/-- Hash of the newest receipt, or the genesis value for an empty log.  This
    single number is the commitment to the whole history. -/
def tip (genesis : Nat) : Log → Nat
  | []     => genesis
  | r :: _ => r.hash

/-- A log is well formed when every entry links to the one below it and carries
    the hash the hasher assigns to it. -/
def chainOk (H : Hasher) (genesis : Nat) : Log → Bool
  | []        => true
  | r :: rest =>
      (r.body.prevHash == tip genesis rest) &&
      (r.hash == H.hash r.body.prevHash r.body) &&
      chainOk H genesis rest

@[simp] theorem chainOk_nil (H : Hasher) (genesis : Nat) :
    chainOk H genesis [] = true := rfl

theorem chainOk_cons {H : Hasher} {genesis : Nat} {r : Receipt} {rest : Log}
    (h : chainOk H genesis (r :: rest) = true) :
    r.body.prevHash = tip genesis rest ∧
    r.hash = H.hash r.body.prevHash r.body ∧
    chainOk H genesis rest = true := by
  simp only [chainOk, Bool.and_eq_true, beq_iff_eq] at h
  exact ⟨h.1.1, h.1.2, h.2⟩

/-- The tail of a valid chain is a valid chain. -/
theorem chainOk_tail {H : Hasher} {genesis : Nat} {r : Receipt} {rest : Log}
    (h : chainOk H genesis (r :: rest) = true) : chainOk H genesis rest = true :=
  (chainOk_cons h).2.2

/-- Append a new entry, computed against the current tip. -/
def appendReceipt (H : Hasher) (genesis : Nat) (monitorKey : Nat)
    (l : Log) (mk : Nat → ReceiptBody) : Log :=
  let b := mk (tip genesis l)
  { body := b, hash := H.hash b.prevHash b,
    sig := macTag b.monitor monitorKey b } :: l

/-- Appending preserves chain validity, provided the builder really does put the
    supplied tip into `prevHash`. -/
theorem appendReceipt_chainOk {H : Hasher} {genesis monitorKey : Nat} {l : Log}
    {mk : Nat → ReceiptBody} (hmk : ∀ p, (mk p).prevHash = p)
    (h : chainOk H genesis l = true) :
    chainOk H genesis (appendReceipt H genesis monitorKey l mk) = true := by
  simp [appendReceipt, chainOk, hmk, h]

/-- Appending only ever adds at the front: the previous log is untouched and is
    a suffix of the new one.  Nothing is rewritten and nothing is dropped. -/
theorem appendReceipt_append_only (H : Hasher) (genesis monitorKey : Nat)
    (l : Log) (mk : Nat → ReceiptBody) :
    ∃ r, appendReceipt H genesis monitorKey l mk = r :: l := ⟨_, rfl⟩

/-- Every appended receipt is signed by the monitor named in it. -/
theorem appendReceipt_signed (H : Hasher) (genesis monitorKey : Nat)
    (l : Log) (mk : Nat → ReceiptBody) :
    ∀ r ∈ (appendReceipt H genesis monitorKey l mk).head?,
      verifyTag r.body.monitor monitorKey r.body r.sig = true := by
  intro r hr
  simp only [appendReceipt, List.head?_cons, Option.mem_def, Option.some.injEq] at hr
  subst hr
  simp

/-! ### Tamper evidence

The point of the chain: publishing the tip hash publishes the whole history.
Two well-formed logs that agree on the tip are equal, so no entry can be
removed, reordered or edited without changing the number everyone sees. -/

/-- Publishing the tip publishes the history: two well-formed logs with the
    same tip record exactly the same receipts, in the same order. -/
theorem tip_determines_history {H : Hasher} {genesis : Nat}
    (hcf : H.CollisionFree) (hgen : H.GenesisFresh genesis) :
    ∀ {l l' : Log}, chainOk H genesis l = true → chainOk H genesis l' = true →
      tip genesis l = tip genesis l' → l.map Receipt.body = l'.map Receipt.body
  | [], [], _, _, _ => rfl
  | [], r' :: rest', _, h', heq => by
      obtain ⟨_, hh', _⟩ := chainOk_cons h'
      exact absurd (by simpa [tip, hh'] using heq.symm)
        (hgen r'.body.prevHash r'.body)
  | r :: rest, [], h, _, heq => by
      obtain ⟨_, hh, _⟩ := chainOk_cons h
      exact absurd (by simpa [tip, hh] using heq)
        (hgen r.body.prevHash r.body)
  | r :: rest, r' :: rest', h, h', heq => by
      obtain ⟨hp, hh, hrest⟩ := chainOk_cons h
      obtain ⟨hp', hh', hrest'⟩ := chainOk_cons h'
      have hhash : H.hash r.body.prevHash r.body
          = H.hash r'.body.prevHash r'.body := by
        simpa [tip, hh, hh'] using heq
      obtain ⟨hprev, hbody⟩ := hcf _ _ _ _ hhash
      have htail : rest.map Receipt.body = rest'.map Receipt.body :=
        tip_determines_history hcf hgen hrest hrest' (by rw [← hp, ← hp', hprev])
      simp [hbody, htail]

/-- Every receipt in the log is signed by its monitor under `key`. -/
def signedOk (key : Nat) (l : Log) : Bool :=
  l.all (fun r => verifyTag r.body.monitor key r.body r.sig)

theorem signedOk_cons {key : Nat} {r : Receipt} {rest : Log}
    (h : signedOk key (r :: rest) = true) :
    verifyTag r.body.monitor key r.body r.sig = true ∧ signedOk key rest = true := by
  simpa [signedOk] using h

/-- Strengthened tamper evidence: among logs whose receipts are all signed by
    the monitor, the tip determines the log outright — signatures included. -/
theorem tip_determines_log {H : Hasher} {genesis key : Nat}
    (hcf : H.CollisionFree) (hgen : H.GenesisFresh genesis) :
    ∀ {l l' : Log}, chainOk H genesis l = true → chainOk H genesis l' = true →
      signedOk key l = true → signedOk key l' = true →
      tip genesis l = tip genesis l' → l = l' := by
  intro l l' h h' hs hs' heq
  have hbodies := tip_determines_history hcf hgen h h' heq
  clear heq
  induction l generalizing l' with
  | nil => cases l' <;> simp_all
  | cons r rest ih =>
    cases l' with
    | nil => simp at hbodies
    | cons r' rest' =>
      simp only [List.map_cons, List.cons.injEq] at hbodies
      obtain ⟨hb, hrest⟩ := hbodies
      obtain ⟨_, hh, hct⟩ := chainOk_cons h
      obtain ⟨_, hh', hct'⟩ := chainOk_cons h'
      obtain ⟨hsig, hstail⟩ := signedOk_cons hs
      obtain ⟨hsig', hstail'⟩ := signedOk_cons hs'
      have hreq : r = r' := by
        cases r with
        | mk b hx sg =>
          cases r' with
          | mk b' hx' sg' =>
            simp only at hb
            subst hb
            simp only [P2P.verifyTag, Bool.and_eq_true, beq_iff_eq] at hsig hsig'
            cases sg; cases sg'
            simp_all
      simp [hreq, ih hct hct' hstail hstail' hrest]

/-- Deleting the newest receipt is always detectable: it changes the tip. -/
theorem drop_newest_changes_tip {H : Hasher} {genesis : Nat}
    (hcf : H.CollisionFree) (hgen : H.GenesisFresh genesis)
    {r : Receipt} {rest : Log} (h : chainOk H genesis (r :: rest) = true) :
    tip genesis (r :: rest) ≠ tip genesis rest := by
  intro heq
  have := tip_determines_history hcf hgen h (chainOk_tail h) heq
  simp at this

end Proxy
