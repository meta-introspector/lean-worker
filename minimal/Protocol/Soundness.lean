/-
  RequestProject.Protocol.Soundness

  Where the two halves meet: a protected prover node (`Protocol.Server`) and a
  checking caller (`Protocol.Client`) are *compatible*, and their composition is
  *sound*.

  Soundness is stated relative to a semantics `Valid : Job → Outcome → Prop`
  ("this outcome is the truth about this job") and one honesty assumption about
  the local back end:

      kernel soundness — whatever the Lean kernel accepts is valid.

  That assumption is carried explicitly as a hypothesis, never as an axiom.
  Everything else — authentication, admission, replay protection, binding of the
  answer to the question — is proved from the protocol definitions.

  The file closes with the peer-to-peer view: peers that are simultaneously
  callers and prover nodes, and the three-valued cross-check (`agreed`,
  `disagreed`, `unknown`) used when the same job is answered by two peers.
-/
import Protocol.Server
import Protocol.Client

namespace P2P

/-! ### Assumptions, stated explicitly -/

/-- The back end is kernel-sound for the semantics `Valid`: any result the Lean
    kernel accepted really is the truth about the job. -/
def KernelSound (rt : Runtime) (Valid : Job → Outcome → Prop) : Prop :=
  ∀ j f, rt.kernelChecked j f = true → Valid j (rt.run j f)

/-- Client and prover node are provisioned for each other: the caller signs with
    the key the node verifies, and checks certificates with the node's key. -/
structure Compatible (cl : Client) (s : Server) : Prop where
  verifyKey : keyOf cl.verifyKeys s.id = some s.key
  callKey   : ∃ k, keyOf cl.callKeys s.id = some k ∧ keyOf s.clientKeys cl.id = some k

/-! ### Soundness: an accepted answer is a true answer -/

/-- End-to-end soundness.  If the caller accepts the node's answer to its own
    call, then the certified outcome is the truth about the job that was asked,
    and it is bound to this caller, this node and this nonce. -/
theorem accepted_answer_is_valid
    {rt : Runtime} {Valid : Job → Outcome → Prop} (hsound : KernelSound rt Valid)
    {cl : Client} {s : Server} {c : Call}
    {cert : Certificate} {tag : Tag Certificate}
    (hresp : (handle rt s c).2 = .certified cert tag)
    (hacc : accepts cl c (.certified cert tag) = true) :
    Valid c.body.job cert.outcome ∧
    cert.job = c.body.job ∧ cert.client = cl.id ∧
    cert.server = c.body.server ∧ cert.nonce = c.body.nonce := by
  obtain ⟨hserver, hclient, hnonce, hjob, houtcome, hchecked, -⟩ :=
    certificate_binds_call hresp
  obtain ⟨hcl, hsrv, hnon, hjb⟩ := accepts_binds_call hacc
  have hk : cert.kernelChecked = true := accepts_kernel_checked hacc
  rw [hchecked] at hk
  have hv : Valid c.body.job (rt.run c.body.job c.body.fuelBudget) :=
    hsound c.body.job c.body.fuelBudget hk
  refine ⟨?_, hjb, hcl, hsrv, hnon⟩
  rw [houtcome]
  exact hv

/-- Nothing a rejecting node emits is ever accepted: an unavailable or refusing
    prover node can never be read as a positive answer. -/
theorem rejection_never_accepted (rt : Runtime) (s : Server) (c : Call)
    (cl : Client) (h : admits s c = false) :
    accepts cl c (handle rt s c).2 = false := by
  rw [rejected_state_unchanged (rt := rt) h]
  simp

/-- A peer that does not hold the node's key cannot get anything accepted in the
    node's name, whatever certificate it makes up. -/
theorem forged_answer_rejected {cl : Client} {c : Call} {cert : Certificate}
    {k k' : Nat} {forger : PeerId}
    (hk : keyOf cl.verifyKeys c.body.server = some k) (hne : k' ≠ k) :
    accepts cl c (.certified cert (macTag forger k' cert)) = false := by
  by_cases hacc : accepts cl c (.certified cert (macTag forger k' cert))
  · obtain ⟨hkey, -, -⟩ := accepts_requires_server_key hk hacc
    exact absurd hkey hne
  · simpa using hacc

/-! ### Completeness: an honest exchange always goes through -/

/-- The admission gate opens for a well-provisioned, in-policy call. -/
theorem admits_of {s : Server} {c : Call} {k : Nat}
    (hserver : c.body.server = s.id)
    (hpeer : c.body.client ∈ s.policy.admittedPeers)
    (hkey : keyOf s.clientKeys c.body.client = some k)
    (hauth : c.auth = macTag c.body.client k c.body)
    (hfresh : fresh s c.body = true)
    (hjob : jobAllowed s.policy c.body.job = true)
    (hcap : c.body.fuelBudget ≤ s.policy.maxFuelPerCall)
    (hbudget : s.fuelUsed + c.body.fuelBudget ≤ s.policy.fuelBudget) :
    admits s c = true := by
  have hauth' : authenticated s c = true := by
    unfold authenticated
    rw [hkey, hauth]
    exact verifyTag_macTag _ _ _
  simp only [admits, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq,
    List.contains_iff_mem]
  exact ⟨⟨⟨⟨⟨⟨hserver, hpeer⟩, hauth'⟩, hfresh⟩, hjob⟩, hcap⟩, hbudget⟩

/-- Honest round trip.  A compatible, admitted, in-policy call whose result the
    kernel accepts comes back with a certificate the caller accepts. -/
theorem honest_round_trip_accepted
    {rt : Runtime} {cl : Client} {s : Server} {job : Job} {fuel : Nat}
    {c : Call} {cl' : Client}
    (hcompat : Compatible cl s)
    (hmk : mkCall cl s.id job fuel = some (c, cl'))
    (hpeer : cl.id ∈ s.policy.admittedPeers)
    (hfresh : fresh s c.body = true)
    (hjob : jobAllowed s.policy job = true)
    (hcap : fuel ≤ s.policy.maxFuelPerCall)
    (hbudget : s.fuelUsed + fuel ≤ s.policy.fuelBudget)
    (hchecked : rt.kernelChecked job fuel = true) :
    accepts cl c (handle rt s c).2 = true := by
  obtain ⟨k, hck, hsk⟩ := hcompat.callKey
  obtain ⟨hbody, hauth, -⟩ := mkCall_body hck hmk
  have hserver : c.body.server = s.id := by rw [hbody]
  have hclient : c.body.client = cl.id := by rw [hbody]
  have hjobEq : c.body.job = job := by rw [hbody]
  have hfuelEq : c.body.fuelBudget = fuel := by rw [hbody]
  have hA : admits s c = true := by
    refine admits_of (k := k) hserver ?_ ?_ ?_ hfresh ?_ ?_ ?_
    · rw [hclient]; exact hpeer
    · rw [hclient]; exact hsk
    · rw [hauth, hclient]
    · rw [hjobEq]; exact hjob
    · rw [hfuelEq]; exact hcap
    · rw [hfuelEq]; exact hbudget
  have hhandle : (handle rt s c).2 =
      .certified
        { server := s.id, client := c.body.client, nonce := c.body.nonce
        , job := c.body.job, outcome := rt.run c.body.job c.body.fuelBudget
        , kernelChecked := rt.kernelChecked c.body.job c.body.fuelBudget
        , fuelUsed := c.body.fuelBudget }
        (macTag s.id s.key
          { server := s.id, client := c.body.client, nonce := c.body.nonce
          , job := c.body.job, outcome := rt.run c.body.job c.body.fuelBudget
          , kernelChecked := rt.kernelChecked c.body.job c.body.fuelBudget
          , fuelUsed := c.body.fuelBudget }) := by
    simp [handle, hA]
  rw [hhandle]
  have hkchk : rt.kernelChecked c.body.job c.body.fuelBudget = true := by
    rw [hjobEq, hfuelEq]; exact hchecked
  unfold accepts
  rw [hserver, hcompat.verifyKey]
  simp [hclient, hkchk]

/-- Putting the two together: an honest exchange both goes through *and* what
    comes back is true. -/
theorem honest_round_trip_sound
    {rt : Runtime} {Valid : Job → Outcome → Prop} (hsound : KernelSound rt Valid)
    {cl : Client} {s : Server} {job : Job} {fuel : Nat}
    {c : Call} {cl' : Client}
    (hcompat : Compatible cl s)
    (hmk : mkCall cl s.id job fuel = some (c, cl'))
    (hpeer : cl.id ∈ s.policy.admittedPeers)
    (hfresh : fresh s c.body = true)
    (hjob : jobAllowed s.policy job = true)
    (hcap : fuel ≤ s.policy.maxFuelPerCall)
    (hbudget : s.fuelUsed + fuel ≤ s.policy.fuelBudget)
    (hchecked : rt.kernelChecked job fuel = true) :
    ∃ cert tag, (handle rt s c).2 = .certified cert tag ∧
      accepts cl c (.certified cert tag) = true ∧
      Valid job cert.outcome := by
  have hacc := honest_round_trip_accepted hcompat hmk hpeer hfresh hjob hcap hbudget hchecked
  obtain ⟨k, hck, -⟩ := hcompat.callKey
  obtain ⟨hbody, -, -⟩ := mkCall_body hck hmk
  have hjobEq : c.body.job = job := by rw [hbody]
  cases hresp : (handle rt s c).2 with
  | rejected reason =>
    rw [hresp] at hacc
    simp at hacc
  | certified cert tag =>
    rw [hresp] at hacc
    obtain ⟨hv, -⟩ := accepted_answer_is_valid hsound hresp hacc
    exact ⟨cert, tag, rfl, hacc, hjobEq ▸ hv⟩

/-! ### The peer-to-peer view -/

/-- A peer is both a caller and a protected prover node, with its own local
    back end. -/
structure Peer where
  client  : Client
  server  : Server
  runtime : Runtime

/-- One directed call from `caller` to `callee`: build the call, let the callee's
    protected node serve it, and have the caller check the answer.  Returns the
    updated peers, whether the answer was accepted, and the answer itself. -/
def p2pCall (caller callee : Peer) (job : Job) (fuel : Nat) :
    Option (Peer × Peer × Bool × Response) :=
  match mkCall caller.client callee.server.id job fuel with
  | none => none
  | some (c, cl') =>
    let (s', resp) := handle callee.runtime callee.server c
    some ({ caller with client := cl' }, { callee with server := s' },
          accepts caller.client c resp, resp)

/-- Peer-to-peer soundness: whenever a peer accepts an answer from another
    peer whose back end is kernel-sound, the certified outcome is true of the
    job that was asked. -/
theorem p2pCall_sound {Valid : Job → Outcome → Prop}
    {caller callee : Peer} {job : Job} {fuel : Nat}
    {caller' callee' : Peer} {cert : Certificate} {tag : Tag Certificate}
    (hsound : KernelSound callee.runtime Valid)
    (hcall : p2pCall caller callee job fuel =
      some (caller', callee', true, .certified cert tag)) :
    Valid job cert.outcome := by
  unfold p2pCall at hcall
  cases hmk : mkCall caller.client callee.server.id job fuel with
  | none => rw [hmk] at hcall; simp at hcall
  | some p =>
    obtain ⟨c, cl'⟩ := p
    rw [hmk] at hcall
    simp only [Option.some.injEq, Prod.mk.injEq] at hcall
    obtain ⟨-, -, hacc, hresp⟩ := hcall
    have hjobEq : c.body.job = job := by
      cases hck : keyOf caller.client.callKeys callee.server.id with
      | none => unfold mkCall at hmk; rw [hck] at hmk; simp at hmk
      | some k =>
        obtain ⟨hbody, -, -⟩ := mkCall_body hck hmk
        rw [hbody]
    have hhandle : (handle callee.runtime callee.server c).2 = .certified cert tag := by
      rw [← hresp]
    have hacc' : accepts caller.client c (.certified cert tag) = true := by
      rw [hhandle] at hacc
      exact hacc
    obtain ⟨hv, -⟩ := accepted_answer_is_valid hsound hhandle hacc'
    exact hjobEq ▸ hv

/-! ### Cross-checking two peers: agreed / disagreed / unknown

    When the same job is sent to two peers, the answers are compared.  A missing
    answer (peer down, relay lost the message) is reported as `unknown` and is
    never silently folded into either agreement or disagreement. -/

inductive Gluing where
  | agreed    : Gluing
  | disagreed : Gluing
  | unknown   : Gluing
  deriving DecidableEq, Repr

/-- Compare two accepted certificates for the same job. -/
def glue (a b : Option Certificate) : Gluing :=
  match a, b with
  | some ca, some cb =>
    if ca.job = cb.job ∧ ca.outcome = cb.outcome then .agreed else .disagreed
  | _, _ => .unknown

/-- A missing answer is exactly what `unknown` reports. -/
theorem glue_unknown_iff (a b : Option Certificate) :
    glue a b = .unknown ↔ a = none ∨ b = none := by
  cases a <;> cases b <;> simp [glue] <;> split <;> simp

/-- `agreed` means the two peers really did return the same outcome. -/
theorem glue_agreed_same {ca cb : Certificate}
    (h : glue (some ca) (some cb) = .agreed) :
    ca.job = cb.job ∧ ca.outcome = cb.outcome := by
  simp only [glue] at h
  by_cases hc : ca.job = cb.job ∧ ca.outcome = cb.outcome
  · exact hc
  · rw [if_neg hc] at h
    simp at h

/-- Two kernel-sound peers that agree are both telling the truth. -/
theorem glue_agreed_valid {Valid : Job → Outcome → Prop}
    {ca cb : Certificate}
    (hva : Valid ca.job ca.outcome)
    (h : glue (some ca) (some cb) = .agreed) :
    Valid ca.job ca.outcome ∧ Valid cb.job cb.outcome := by
  obtain ⟨hjob, hout⟩ := glue_agreed_same h
  exact ⟨hva, by rw [← hjob, ← hout]; exact hva⟩

end P2P
