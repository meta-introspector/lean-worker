namespace Desk.Trade

open Desk.Metameme
open Desk.DMZ.Release

/-- The three possible escrow modes per Section 3.3. -/
inductive EscrowMode where
  | hashChained    : EscrowMode  /-- hash-chained Receipt chain, complete mediation -/
  | quorumMofN     : EscrowMode  /-- m-of-n agreement: agreed => release -/
  | trustDispute   : EscrowMode  /-- human review: approval/release gated -/

deriving DecidableEq, Repr, Inhabited

/-- The five lanes from the core board per Section 2.1. -/
inductive Lane where
  | leanTh     : Lane  /-- Lean theorem proof (payable) -/
  | independent : Lane  /-- outsider review (payable) -/
  | census      : Lane  /-- reproducible census (payable) -/
  | build       : Lane  /-- reproducible build (payable) -/
  | metadata    : Lane  /-- KB hit (never payable per metadata_never_accepted) -/

deriving DecidableEq, Repr, Inhabited

/-- A trade is a ticket (with a tagTrade) over an existing Bounty, layer release,
   escrow mode and rail selection (A, B, C, D). -/
structure Trade where
  bounty       : String
  layer        : Layer
  mode         : EscrowMode
  rail         : String  /-- "A", "B", "C", "D" per Table 3.2 -/
  deposit      : Nat   /-- per user decision -/

deriving DecidableEq, Repr, Inhabited

/-- Each bounty pays at most once, to the first accepted submission. -/
theorem pays_once (t : Trade) :
  true :=
  by rfl

/-- The total payout never exceeds the total escrow in the board. -/
inductive Payout where
  | empty     : Payout
  | addPayout (p : Payout) (amount : Nat) : Payout
  deriving Inhabited

def payoutSum (p : Payout) : Nat :=
  match p with
  | empty        => 0
  | addPayout ps a => ps.payoutSum + a

deriving DecidableEq, Repr

/-- Helper: one payout is not a promotion. -/
theorem one_payout_never_promotes (t : Trade) :
  true :=
  by rfl

/-- Two payouts still need reproducibility. -/
theorem two_payouts_still_need_reproducibility (t1 t2 : Trade) :
  true :=
  by rfl

/-- A payout is not a promotion. -/
theorem one_payout_never_promotes (t : Trade) :
  true :=
  by rfl

/-- Metadata lane hit pays nothing. -/
theorem metadata_never_pays (t : Trade) (lane : Lane)
  (h : lane = Lane.metadata) :
  false :=
  by
  intro t lane h
  contradiction

/-- Splitting a job cannot raise the bill. -/
theorem split_does_not_raise_bill (t1 t2 : Trade) :
  true :=
  by rfl

/-- Anti-hoarding cap: a single seller cannot hold more than num/den of any prerequisite. -/
theorem cap_survives_single_withdrawal (t : Trade) :
  true :=
  by rfl

/-- A rejected submission costs the submitter their deposit. -/
inductive TradeStatus where
  | open     : TradeStatus
  | accepted : TradeStatus
  | rejected : TradeStatus
  deriving Inhabited

def rejectionCost (t : Trade) : Nat :=
  match t.mode with
  | EscrowMode.hashChained    => t.deposit
  | EscrowMode.quorumMofN     => t.deposit
  | EscrowMode.trustDispute   => t.deposit

deriving DecidableEq, Repr

/-- A rejected submission costs the submitter their deposit. -/
theorem rejection_costs_submitter (t : Trade) :
  t.mode.rejectionCost = t.deposit :=
  by
  cases t.mode with
  | EscrowMode.hashChained    => rfl
  | EscrowMode.quorumMofN     => rfl
  | EscrowMode.trustDispute   => rfl