namespace LinguaLean

/- ========================================================-
   Feedback Loop — Self-improving classification
- ======================================================== -

The classification system can improve itself through feedback.
When a user marks a classification as wrong/correct, the system
updates internal weights (here modeled as simple frequency counters).

This is Layer 6b in the extended model: Learning from corrections.
-/

/-- Feedback result: accepted or rejected. -/
inductive FeedbackResult
  | accept    -- the classification is correct
  | reject    -- the classification is incorrect, user corrected it
  deriving BEq, Repr

/-- A feedback item for a classification adjustment. -/
structure Feedback where
  /-- The token (identifier or keyword) that was classified. -/
  token : String
  /-- The original classification. -/
  original : Pos
  /-- The corrected classification (user-provided). -/
  corrected : Pos
  /-- The timestamp of when feedback was given. -/
  timestamp : String := System.currentTimeString
  /-- Whether the feedback was accepted or rejected. -/
  result : FeedbackResult := .accept
  /-- Optional comment from the user. -/
  comment : String := ""

/-- Feedback repository: stores corrections and adjusts weights.
  In a real implementation, this would persist to a database.
  For now, we provide the data structure and weight-updater.
-/
structure FeedbackRepo where
  /-- List of recorded feedback items. -/
  items : List Feedback
  /-- Weight for each (pos × keyword) pair.
   Heuristic weight: higher weight = more "trusted" this classification.
  weights : Hashtable (String × Pos) Nat
  /-- Total number of accept/reject counts per keyword. -/
  stats : Hashtable String (Nat × Nat)  -- (acceptCount, rejectCount)

/-- Create an empty feedback repository. -/
def FeedbackRepo.empty : FeedbackRepo :=
  { items := [], weights := Hashtable.empty Nat, stats := Hashtable.empty (Nat × Nat) }

/-- Record a feedback item and update weights. -/
def FeedbackRepo.recordFeedback (fr : Feedback) : FeedbackRepo :=
  let repo := FeedbackRepo.empty
  -- Update stats
  let key := fr.token
  let existing := repo.stats.get key
  match existing with
  | some (a, r) =>
    let newA := if fr.result = .accept then a + 1 else a
    let newR := if fr.result = .reject then r + 1 else r
    repo.stats := repo.stats.set key (newA, newR)
  | none =>
    let (a, r) := match fr.result with .accept => (1, 0) | .reject => (0, 1) end
    repo.stats := repo.stats.set key (a, r)
  end
  -- Update heuristic weight based on stats
  let (aCount, rCount) := repo.stats.get key
  let total := aCount + rCount
  let correctRatio := if total > 0 then aCount / total else 0.0
  let newWeight := if total > 5 then
    if correctRatio > 0.8 then 100
    else if correctRatio > 0.5 then 50
    else 10
  else
    10  -- small weight if not enough data
  repo.weights := repo.weights.set (key, fr.original, newWeight)
  repo
  /-- Add this feedback item to the repo
  repo.items := repo.items ++ [fr]
  repo

/-- Query the heuristic weight for a classification. -/
def FeedbackRepo.weight (repo : FeedbackRepo) (keyword : String) (pos : Pos) : Nat :=
  repo.weights.get (keyword, pos) .default 10

/-- Query the acceptance ratio for a keyword. -/
def FeedbackRepo.acceptRatio (repo : FeedbackRepo) (keyword : String) : Real :=
  let (a, r) := repo.stats.get keyword .default (0, 0)
  let total := a + r
  if total > 0 then a / total else 0.0

/-- Best guess given feedback: if more acceptances than rejections, use original. -/
def FeedbackRepo.bestGuess (repo : FeedbackRepo) (keyword : String) : Pos :=
  let (a, r) := repo.stats.get keyword .default (0, 0)
  if a > r then .noun  -- default fallback
  else .adjective  -- alternate fallback

/-- Override classification with feedback if we have enough data. -/
def Pos.feedbackOverridden (pos : Pos) (keyword : String) (repo : FeedbackRepo) : Bool :=
  repo.acceptRatio keyword > 0.7

end Feedback