namespace LinguaLean

/- ========================================================-
   LinguaLean — Multi-Layered Classification
   Main entry point
- ======================================================== -

  L0  Syntax      — positional context
  L1  Lexical     — raw token extraction
  L2  Morphology  — morpheme decomposition
  L3  Pos         — part-of-speech
  L4  Semantics   — mathematical domain
  L5  ProofRole   — proof-theoretic role
  L6  Dependency  — reference graph
  L6b Feedback    — self-improving corrections

Import all layers:
-/

-- import LinguaLean.Morphology
-- import LinguaLean.Pos
-- import LinguaLean.Basic
-- import LinguaLean.Feedback
-- import LinguaLean.Classifier
-- import LinguaLean.Keywords

/-! ## Example Usage -/

-- Classify a token through all layers
#eval classifyToken "IsPrime"

-- Classify a list of tokens (signature batch)
#eval classifyTokens ["add", "mul", "IsGroup", "forall", "exists"]

-- Apply feedback to override a classification
#eval
  let repo := FeedbackRepo.empty
  let analyzed := classifyToken "foo_bar"
  let corrected := classifyTokenWithFeedback "foo_bar" repo
  (analyzed, corrected)

end LinguaLean
