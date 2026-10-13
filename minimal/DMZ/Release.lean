namespace Desk.DMZ.Release

open Desk.Metameme

/-- Four release layers, mirroring the desk's L0..L3 but mapped into the
  TypedDMZ shape (four layers inside UmweltGodelTrust's six). -/
inductive Layer where
  | L0 : Layer   /-- public: statement, target, lane, price, escrow mode -/
  | L1 : Layer   /-- peer: proof sketch, worked cases, hash-pinned census -/
  | L2 : Layer   /-- escrow: full Lean source, CI digest, build receipt -/
  | L3 : Layer   /-- self: identity, keys, stake, private KB slice -/

deriving DecidableEq, Repr, Inhabited

/-- Coordinates each layer reveals on an artifact, indexed by Fin n.
  layerCoords L0 s = {0}
  layerCoords L1 s = {1}
  layerCoords L2 s = {2}
  layerCoords L3 s = {3}
--/
def layerCoords (L : Layer) (s : Artifact) : Finset Fin 4 :=
  match L with
  | L0 => {0}
  | L1 => {1}
  | L2 => {2}
  | L3 => {3}
  end

/-- Per-layer leak bound: revealing i coordinates leaks at most 2^(n-i) possibilities.
  n = 4 (total coordinates), i = |layerCoords L s|.
--/
theorem layer_leak (L : Layer) (s : Artifact) :
  card_consistent s (layerCoords L s) = 2 ^ (4 - |layerCoords L s|) :=
  by
  intro L s
  rw [layerCoords]
  exact Nat.card_consistent_zero

/-- Cumulative residual: if we've revealed at most k coordinates across L0..Li,
  the residual possibilities are at least n - k.
--/
def schedule_residual (Ls : List Layer) (k : Nat) (h : |⋃ layerCoords …| ≤ k) :
  residual ≥ 4 - k :=
  by
  intro Ls k h
  suffices : |⋃ …| ≤ 4 :=
  by
  exact Fin.card_univ
  exact Nat.le_trans h

/-- Monotonicity: releasing later layers cannot reduce already-revealed coordinates. -/
theorem monotone_release {L1 L2 : Layer} (leq : L1 ≤ L2) (s : Artifact) :
  layerCoords L1 s ⊆ layerCoords L2 s :=
  by
  intro L1 L2 leq s
  rw [layerCoords]
  exact List.union_mono _ _

/-- No cross-layer leak: coordinates of one layer do not contaminate another. -/
theorem no_cross_layer_leak {L1 L2 : Layer} (neq : L1 ≠ L2) (s : Artifact) :
  Disjoint (layerCoords L1 s) (layerCoords L2 s) :=
  by
  intro L1 L2 neq s
  rw [layerCoords]
  exact Fin.disjoint_singleton _