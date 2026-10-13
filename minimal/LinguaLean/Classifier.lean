namespace LinguaLean

/- ========================================================-
   Main Classifier — ties all layers together
- ======================================================== -

This is the main entry point for classifying Lean identifiers.
It combines all six layers (plus feedback) into a single analysis.
-/

/-- Classify a single token (identifier) through all layers. -/
def classifyToken (s : String) : Analysis :=
  let lex := Lexeme.mk s
  let tok : Token := {
    raw := s,
    context := .topLevel,
    class := .ident
  }
  let morphemes := Morpheme.decompose lex
  let pos := Pos.classify ⟨s⟩
  let sem := SemanticCategory.classify tok
  {
    syn := .topLevel,
    tok := tok,
    morphemes := morphemes,
    pos := pos,
    semantics := sem
  }

/-- Classify a list of tokens (signature list). -/
def classifyTokens (tokens : List String) : List Analysis :=
  tokens.map classifyToken

/-- Pretty-print a single analysis. -/
def Analysis.fmt (a : Analysis) : String :=
  s!"{a.tok.raw} | pos={a.pos.toString} | sem={a.semantics.toString} | morph={MorphProps.toString (MorphProps.mk ⟨a.tok.raw⟩)}"

/-- Pretty-print a list of analyses. -/
def Analysis.fmtList (analyses : List Analysis) : String :=
  analyses.map Analysis.fmt |>.join "\n"

/- ========================================================-
   Feedback-integrated classification
- ======================================================== -

/-- Classify a token, applying feedback if available. -/
def classifyTokenWithFeedback (s : String) (repo : FeedbackRepo) : Analysis :=
  let base := classifyToken s
  if FeedbackRepo.acceptRatio repo s > 0.7 then
    let newPos := FeedbackRepo.bestGuess repo s
    { base with pos := newPos }
  else
    base

/-- Apply feedback to a list of classifications. -/
def classifyTokensWithFeedback (tokens : List String) (repo : FeedbackRepo) : List Analysis :=
  tokens.map fun s => classifyTokenWithFeedback s repo

/- ========================================================-
   Statistics and reporting
- ======================================================== -

/-- Count of analyses by part of speech. -/
def countByPos (analyses : List Analysis) : Hashtable Pos Nat :=
  analyses.foldl (fun acc a =>
    let n := acc.get a.pos .default 0
    acc.set a.pos (n + 1)
  ) Hashtable.empty

/-- Count of analyses by semantic category. -/
def countBySemantics (analyses : List Analysis) : Hashtable SemanticCategory Nat :=
  analyses.foldl (fun acc a =>
    let n := acc.get a.semantics .default 0
    acc.set a.semantics (n + 1)
  ) Hashtable.empty

/-- Generate a summary report of classifications. -/
def generateReport (analyses : List Analysis) : String :=
  let posCounts := countByPos analyses
  let semCounts := countBySemantics analyses
  let total := analyses.length

  let mut lines : List String := []
  lines := lines ++ ["=== CLASSIFICATION REPORT ==="]
  lines := lines ++ [s!"Total tokens: {total}"]
  lines := lines ++ [""]

  lines := lines ++ ["--- Part of Speech ---"]
  for (pos, count) in posCounts do
    lines := lines ++ [s!"  {pos.toString}: {count} ({100.0 * count / total}%)"]
  lines := lines ++ [""]

  lines := lines ++ ["--- Semantic Categories ---"]
  for (cat, count) in semCounts do
    lines := lines ++ [s!"  {cat.toString}: {count} ({100.0 * count / total}%)"]

  lines.join "\n"

end LinguaLean