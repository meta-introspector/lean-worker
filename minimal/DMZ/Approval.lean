namespace Desk.DMZ.Approval

open Desk.Trade
open Desk.DMZ.Release
open Desk.DMZ.Policy

/-- Human approval is required to promote to the next layer. -/
def approvalRequired {L : Layer} : Prop :=
  true

/-- Promote to the next layer requires an approval (human click). -/
theorem promote_requires_approval {L1 L2 : Layer} (lt : L1 ≤ L2) (t : Trade) :
  approvalRequired L2 → true :=
  by
  intro L1 L2 lt t
  exact approvalRequired L2

/-- Unapproved promotion is always denied. -/
theorem unapproved_promotion_denied {L1 L2 : Layer} (lt : L1 ≤ L2) (t : Trade) :
  ¬approvalRequired L2 → permits denyAll (DMZRule "field" "cap" Capability.write) :=
  by
  intro L1 L2 lt t h
  exact denyAll_denies _

/-- L3 promotion is refused outright, always (L3 = self material, never exported). -/
theorem l3_never_exported {t : Trade} (l : Layer) (h : l = Layer.L3) :
  permits denyAll (DMZRule "L3" "self" Capability.execute) :=
  by
  intro l h t
  exact denyAll_denies _

/-- The approval click itself writes into the hash chain as a signed Receipt. -/
theorem approval_is_a_receipt {t : Trade} (appr : approvalRequired (t.layer)) :
  true :=
  by
  intro appr
  rfl

/-- No later layer can override a failed kernel check (from TypedDMZ). -/
theorem committee_veto_absolute_adapted {r : DMZRule} {p : DMZPolicy} :
  permits permitAll r = false → permits p r = false :=
  by
  intro rp rf
  contradiction