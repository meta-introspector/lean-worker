/-
  RequestProject.Protocol.Client

  The caller side of a certified peer-to-peer prover call.

  A client keeps its own nonce counter, the key it shares with each prover node
  it is allowed to call, and the key it uses to verify that node's certificates.
  It emits an authenticated call, and it accepts an answer only if the answer

    * carries a tag that verifies under the callee's key,
    * names this client, this callee and this nonce,
    * is about exactly the job that was asked for, and
    * says the Lean kernel accepted the result.

  Every one of those checks is load-bearing; the theorems below show that each
  failure mode is rejected.
-/
import RequestProject.Protocol.Core

namespace P2P

/-- The caller's local state. -/
structure Client where
  id         : PeerId
  /-- Keys shared with prover nodes, used to authenticate outgoing calls. -/
  callKeys   : List (PeerId × Nat)
  /-- Keys used to verify certificates coming back from prover nodes. -/
  verifyKeys : List (PeerId × Nat)
  nextNonce  : Nonce

/-- Build an authenticated call and advance the nonce counter.  `none` when the
    client holds no key for that node, i.e. it may not call it. -/
def mkCall (cl : Client) (server : PeerId) (job : Job) (fuel : Nat) :
    Option (Call × Client) :=
  match keyOf cl.callKeys server with
  | none => none
  | some k =>
    let body : CallBody :=
      { client := cl.id, server := server, nonce := cl.nextNonce
      , job := job, fuelBudget := fuel }
    some ({ body := body, auth := macTag cl.id k body },
          { cl with nextNonce := cl.nextNonce + 1 })

/-- The client's acceptance predicate for an answer to one of its own calls. -/
def accepts (cl : Client) (c : Call) (r : Response) : Bool :=
  match r with
  | .rejected _ => false
  | .certified cert tag =>
    match keyOf cl.verifyKeys c.body.server with
    | none => false
    | some k =>
      verifyTag c.body.server k cert tag &&
      (cert.client == cl.id) &&
      (cert.server == c.body.server) &&
      (cert.nonce == c.body.nonce) &&
      (cert.job == c.body.job) &&
      cert.kernelChecked

/-! ### What acceptance entails -/

/-- A rejection is never accepted: an unavailable prover node cannot be mistaken
    for a positive answer. -/
@[simp] theorem not_accepts_rejected (cl : Client) (c : Call) (reason : String) :
    accepts cl c (.rejected reason) = false := rfl

/-- Everything the client has checked, spelled out. -/
theorem accepts_components {cl : Client} {c : Call}
    {cert : Certificate} {tag : Tag Certificate}
    (h : accepts cl c (.certified cert tag) = true) :
    ∃ k, keyOf cl.verifyKeys c.body.server = some k ∧
      verifyTag c.body.server k cert tag = true ∧
      cert.client = cl.id ∧ cert.server = c.body.server ∧
      cert.nonce = c.body.nonce ∧ cert.job = c.body.job ∧
      cert.kernelChecked = true := by
  unfold accepts at h
  cases hk : keyOf cl.verifyKeys c.body.server with
  | none => rw [hk] at h; simp at h
  | some k =>
    rw [hk] at h
    simp only [Bool.and_eq_true, beq_iff_eq] at h
    obtain ⟨⟨⟨⟨⟨h1, h2⟩, h3⟩, h4⟩, h5⟩, h6⟩ := h
    exact ⟨k, rfl, h1, h2, h3, h4, h5, h6⟩

/-- An accepted certificate answers exactly the call that was made. -/
theorem accepts_binds_call {cl : Client} {c : Call}
    {cert : Certificate} {tag : Tag Certificate}
    (h : accepts cl c (.certified cert tag) = true) :
    cert.client = cl.id ∧ cert.server = c.body.server ∧
    cert.nonce = c.body.nonce ∧ cert.job = c.body.job := by
  obtain ⟨_, _, _, h2, h3, h4, h5, _⟩ := accepts_components h
  exact ⟨h2, h3, h4, h5⟩

/-- An accepted result was checked by the Lean kernel. -/
theorem accepts_kernel_checked {cl : Client} {c : Call}
    {cert : Certificate} {tag : Tag Certificate}
    (h : accepts cl c (.certified cert tag) = true) : cert.kernelChecked = true := by
  obtain ⟨_, _, _, _, _, _, _, h7⟩ := accepts_components h
  exact h7

/-- Unforgeability: whoever produced an accepted answer held the prover node's
    key.  A relay that does not hold it cannot get an answer accepted. -/
theorem accepts_requires_server_key {cl : Client} {c : Call}
    {cert : Certificate} {tag : Tag Certificate} {k : Nat}
    (hk : keyOf cl.verifyKeys c.body.server = some k)
    (h : accepts cl c (.certified cert tag) = true) :
    tag.key = k ∧ tag.signer = c.body.server ∧ tag.payload = cert := by
  obtain ⟨k', hk', hv, _⟩ := accepts_components h
  rw [hk] at hk'
  cases hk'
  exact ⟨verifyTag_key hv, verifyTag_signer hv, verifyTag_payload hv⟩

/-- Tamper resistance: if a relay changes any field of the certificate, the
    altered certificate is not accepted under the same tag. -/
theorem tampered_certificate_rejected {cl : Client} {c : Call}
    {cert cert' : Certificate} {tag : Tag Certificate} {k : Nat}
    (hk : keyOf cl.verifyKeys c.body.server = some k)
    (horig : tag.payload = cert) (hne : cert' ≠ cert) :
    accepts cl c (.certified cert' tag) = false := by
  by_cases h : accepts cl c (.certified cert' tag)
  · obtain ⟨-, -, hpay⟩ := accepts_requires_server_key hk h
    have hcc : cert' = cert := by rw [← hpay, horig]
    exact absurd hcc hne
  · simpa using h

/-- Replay across calls is refused: an answer bound to a different nonce is not
    accepted for this call. -/
theorem stale_nonce_rejected (cl : Client) (c : Call)
    (cert : Certificate) (tag : Tag Certificate)
    (h : cert.nonce ≠ c.body.nonce) :
    accepts cl c (.certified cert tag) = false := by
  by_cases hacc : accepts cl c (.certified cert tag)
  · exact absurd (accepts_binds_call hacc).2.2.1 h
  · simpa using hacc

/-- An answer about a different job is not accepted. -/
theorem wrong_job_rejected (cl : Client) (c : Call)
    (cert : Certificate) (tag : Tag Certificate)
    (h : cert.job ≠ c.body.job) :
    accepts cl c (.certified cert tag) = false := by
  by_cases hacc : accepts cl c (.certified cert tag)
  · exact absurd (accepts_binds_call hacc).2.2.2 h
  · simpa using hacc

/-- A result the kernel did not check is not accepted, however well signed. -/
theorem unchecked_result_rejected (cl : Client) (c : Call)
    (cert : Certificate) (tag : Tag Certificate)
    (h : cert.kernelChecked = false) :
    accepts cl c (.certified cert tag) = false := by
  by_cases hacc : accepts cl c (.certified cert tag)
  · rw [accepts_kernel_checked hacc] at h; exact absurd h (by simp)
  · simpa using hacc

/-! ### Well-formedness of outgoing calls -/

/-- A call the client builds is addressed as intended and authenticated with the
    key the client shares with that node. -/
theorem mkCall_body {cl : Client} {server : PeerId} {job : Job} {fuel : Nat}
    {c : Call} {cl' : Client} {k : Nat}
    (hk : keyOf cl.callKeys server = some k)
    (h : mkCall cl server job fuel = some (c, cl')) :
    c.body = { client := cl.id, server := server, nonce := cl.nextNonce
             , job := job, fuelBudget := fuel } ∧
    c.auth = macTag cl.id k c.body ∧
    cl'.nextNonce = cl.nextNonce + 1 := by
  unfold mkCall at h
  rw [hk] at h
  simp only [Option.some.injEq, Prod.mk.injEq] at h
  obtain ⟨hc, hcl⟩ := h
  subst hc
  subst hcl
  exact ⟨rfl, rfl, rfl⟩

/-- Successive calls from one client never reuse a nonce. -/
theorem mkCall_nonce_advances {cl : Client} {server : PeerId} {job : Job}
    {fuel : Nat} {c : Call} {cl' : Client}
    (h : mkCall cl server job fuel = some (c, cl')) :
    cl'.nextNonce = c.body.nonce + 1 := by
  unfold mkCall at h
  cases hk : keyOf cl.callKeys server with
  | none => rw [hk] at h; simp at h
  | some k =>
    rw [hk] at h
    simp only [Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨hc, hcl⟩ := h
    subst hc
    subst hcl
    rfl

end P2P
