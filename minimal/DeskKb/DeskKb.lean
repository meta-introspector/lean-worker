namespace Desk.DeskKb

/-- A witnessed KB record from the p2p relay network. -/
structure KbRecord where
  query       : String  -- the search query
  response    : String  -- the KB response content
  digest      : Nat     -- cryptographic digest (e.g. IPLD CID)
  fetcherPeer : String  -- peer identifier who fetched this record
  fetchedAt   : Nat     -- timestamp (epoch seconds)
  verified    : Bool    -- whether the witness integrity check passed
  deriving DecidableEq, Repr, Inhabited

/-- Overlap similarity predicates over term lists. -/
def matchedCount (a b : List Nat) : Nat :=
  (a.filter (fun x => b.contains x)).length

def totalCount (a b : List Nat) : Nat :=
  a.length + b.length

theorem matched_le_length (a b : List Nat) :
    matchedCount a b ≤ a.length := by
  unfold matchedCount
  exact List.length_filter_le _ _

/-- A KB metadata record alone does not trigger an escrow payout. -/
def recordPayable (_r : KbRecord) : Bool := false

theorem metadata_never_pays (r : KbRecord) :
    recordPayable r = false := rfl

end Desk.DeskKb