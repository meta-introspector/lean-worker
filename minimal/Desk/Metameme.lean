namespace Desk.Metameme

/-- An artifact is any Lean object that can be traded as a proof part.
  For the desk, an artifact is a work unit identifier + its statement.
--/
structure Artifact where
  pid   : String   /-- proof identifier (work unit id) -/
  stmt  : String   /-- the exact statement to prove -/

deriving DecidableEq, Repr, Inhabited

/-- The monetary unit of the metameme price function.
  It is an off-chain priced amount, not a chain token.
--/
inductive MetamemeAmount where
  | zero  : MetamemeAmount
  | units : Nat → MetamemeAmount
  deriving DecidableEq, Repr, Inhabited

/-- Price of an artifact: a function of the artifact alone.
  Ported from the Rust `PaymentMorphism`.  No claim can influence the price.
--/
def price (a : Artifact) : MetamemeAmount :=
  match a.pid with
  | "seed"    => MetamemeAmount.units 100
  | "small"   => MetamemeAmount.units 300
  | "medium"  => MetamemeAmount.units 500
  | "large"   => MetamemeAmount.units 800
  | "grand"   => MetamemeAmount.units 2000
  | _         => MetamemeAmount.zero
  end

-- Theorems

/-- Price is deterministic: same artifact always same price. -/
def price_deterministic {a : Artifact} : price a = price a :=
  by rfl

/-- Price is independent of the claim: a seller cannot inflate its own baseline. -/
def price_independent_of_claim {a a' : Artifact} (hp : a.pid = a'.pid) : price a = price a' :=
  by rfl

/-- Check cost is charged: a proof that costs more to check than it saves is rejected. -/
def check_cost_charged {a : Artifact} (cost : Nat) (h : cost > (price a).units) :
  false :=
  by
  intro h
  cases (price a) with
  | MetamemeAmount.zero => exact Nat.zero_lt_succ
  | MetamemeAmount.units n => exact Nat.succ_lt_succ n h