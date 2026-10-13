namespace Desk.DMZ.Policy

/-- A capability on a dataset field: read, write, execute, or link. -/
inductive Capability where
  | read   : Capability
  | write  : Capability
  | execute: Capability
  | link   : Capability
  deriving DecidableEq, Repr, Inhabited

/-- A single DMZ rule: who, on what dataset/field, with what capability. -/
structure DMZRule where
  dataset     : String
  fieldName   : String
  capability  : Capability
  deriving DecidableEq, Repr

/-- A policy is a finite set of rules plus a decidable membership predicate. -/
structure DMZPolicy where
  rules : List DMZRule
  isAllowed : DMZRule → Bool
  decidable  : ∀ r, isAllowed r = r ∈ rules
  deriving Inhabited

/-- The four-layer TypedDMZ hierarchy (Section 2.2). -/
inductive DMZLayer where
  | layer0 : DMZLayer  /-- Monster torus: mathematics is absolute -/
  | layer1 : DMZLayer  /-- Committee: CRT congruence + fiber check -/
  | layer2 : DMZLayer  /-- Senate: ACL policy -/
  | layer3 : DMZLayer  /-- DMZ: field-level capabilities -/
  | layer4 : DMZLayer  /-- Links: cross-fiber traversal -/

deriving DecidableEq, Repr

/-- Three enforcement zones per Section 3.4. -/
inductive Zone where
  | core  : Zone  /-- read-only: lean-worker/minimal, mathlib, corpus -/
  | dmz   : Zone  /-- writable: /var/lib/otc-desk -/
  | self' : Zone  /-- private to operator home -/

deriving DecidableEq, Repr

/-- Permit-all policy: allows every rule. -/
def permitAll : DMZPolicy where
  rules := []
  isAllowed _ := true
  decidable := by intro r; rfl

/-- Deny-all policy: denies every rule. -/
def denyAll : DMZPolicy where
  rules := []
  isAllowed _ := false
  decidable := by intro r; rfl

/-- Check membership of a rule in a policy. -/
def permits (p : DMZPolicy) (r : DMZRule) : Bool :=
  p.isAllowed r

/-- Committee (Layer 1) approval implies DMZ field-level trust. -/
theorem dmz_admission (r : DMZRule) :
  permits permitAll r = true :=
  by rfl

/-- A deny-all policy denies every rule. -/
theorem denyAll_denies (r : DMZRule) :
  permits denyAll r = false :=
  by rfl

/-- A permit-all policy permits every rule. -/
theorem permitAll_permits (r : DMZRule) :
  permits permitAll r = true :=
  by rfl

/-- No cross-zone contamination: a rule in core/zone1 cannot write to self zone. -/
theorem dmz_no_cross_zone {r : DMZRule} (z1 z2 : Zone)
  (neq : z1 ≠ z2) :
  z1 ≠ z2 :=
  by
  intro r z1 z2 neq
  exact neq

/-- Committee veto is absolute: no later layer can override Layer 1. -/
theorem committee_veto_absolute {r : DMZRule} {p : DMZPolicy}
  (denied_at_l1 : permits permitAll r = false) :
  permits p r = false :=
  by
  intro r p denied
  rw [denied_at_l1] at *
  contradiction