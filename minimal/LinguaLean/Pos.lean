/-
# LinguaLean — Parts of Speech

Defines the **POS layer** (Layer 3) of the multi-layered classification model.

Lean 4 identifiers and keywords are classified into parts of speech analogous
to natural-language grammar, but adapted for mathematical/formal semantics.

This theory is imported by `LinguaLean.lean` and used by the `TermClassifier`.
-/
namespace LinguaLean

-----------------------------------------------------------------------
-- Layer 1: Lexical  — raw identifier
-----------------------------------------------------------------------
/-- A raw token from a Lean source file: a keyword or an identifier. -/
structure Lexeme where
  /-- The raw source text. -/
  text : String
  deriving Repr, BEq, Hashable, DecidableEq, Inhabited

-----------------------------------------------------------------------
-- Layer 2: Morphological — decomposition into meaningful morphemes
-----------------------------------------------------------------------
/-- Morphological analysis of an identifier.

  Lean/Mathlib follows Haskell-like camelCase, but also uses suffixes like
  `_iff`, `eq_of_`, `is_`, `has_`, and prefixes like `to`, `of`, `coerce`.
-/
inductive Morpheme
  /-- `prefix` + body, e.g. `IsPrime` → prefix "Is" + "Prime" -/
  | prefix (p : String) (body : String)
  /-- body + `suffix`, e.g. `_iff` suffix -/
  | suffix (body : String) (s : String)
  /-- infix modifier, e.g. `LeftMonoidal` = "Left" + "Monoidal" -/
  | infix (left : String) (right : String)
  /-- atomic — no meaningful decomposition -/
  | mono (body : String)
  deriving BEq, Hashable, Repr

/-- Split a camelCase identifier into words.

  For example `"isGroupHom"` → `#["is", "Group", "Hom"]`.
-/
def Morpheme.splitCamelCase (s : String) : List String :=
  let mut words : List String := []
  let mut current := ""
  let chars := s.toList
  for c in chars do
    if c.isUpper then
      if current.length > 0 then words := words.reverse ::: [current]
      current := String.singleton c
    else
      current := current ++ String.singleton c
  if current.length > 0 then words := words.reverse ::: [current]
  words.reverse.reverse

/-- Decompose an identifier into morphemes. -/
def Morpheme.decompose (tok : Lexeme) : List Morpheme :=
  let s := tok.text
  -- Heuristic: check for _iff, _of_, is_, has_ prefixes
  if s.endsWith "_iff" then
    [.suffix (s.dropRight 4) "_iff"]
  else if s.startsWith "Is" then
    [.prefix "Is" s[2:]]
  else if s.startsWith "Has" then
    [.prefix "Has" s[3:]]
  else if s.contains '_' then
    -- Split by underscores
    let parts := s.split (· == '_')
    parts.map fun p => .mono p
  else
    -- Try camelCase split
    let words := splitCamelCase s
    if words.length > 1 then
      [.infix words[0]! words[1]!  -- placeholder; real impl would be recursive
      ] else
      [.mono s]

instance : Coe Lexeme Morpheme where
  coe := .mono

-----------------------------------------------------------------------
-- Layer 3: Parts of Speech
-----------------------------------------------------------------------
/-- Parts of speech adapted for Lean 4 / Mathlib identifiers.

These categories determine how a term behaves in proof construction
(syntactic role) independent of its semantic category.
-/
inductive Pos
  -- Nominal forms
  | noun           -- type constructors, named constants: `Nat`, `AddGroup`, `Gcc`
  | adjective      -- predicates/properties: `IsPrime`, `Comm`, `Complete`
  | numeral        -- numeric type families: `Nat`, `Int`, `Rat`, `Real`, `Fin`
  | determiner     -- type indices: `True`, `False`, `Empty`, `Unit`, `Option`
  | pronoun        -- self-referential: `this`, `that`, `self`, `default`
  -- Verbal forms
  | verb           -- operations/functions: `add`, `mul`, `pow`, `coe`
  | verbPhrase     -- multi-word operations: `hasAdd` (has add)
  -- Connectives
  | conjunction    -- `and`, `or`, `xor`, `iff`
  | adverb         -- modifiers: `classically`, `constructively`
  | preposition    -- domain qualifiers: `within`, `at`, `on`, `over`, `under`
  | quantifier     -- `forall`, `exists`, `existsUnique`
  | determinerQuantifier  -- determiner-like quantifiers: `∀`, `∃`, `λ`
  -- Meta
  | keyword        -- language keywords: `import`, `def`, `theorem`, `match`
  | attribute      -- attributes: `reducible`, `unsafe`, `simp`, `norm_num`
  | tactic         -- tactic names: `intro`, `apply`, `rw`, `simp`
  | interjection   -- exclamations: `sorry`, `admit`, `by_cases`
  -- Special Lean
  | constructor    -- data constructors: `intro`, `left`, `right`, `cons`
  | eliminator     -- case-split / eliminators: `rec`, `cases`, `noConfusion`
  deriving Repr, BEq, DecidableEq, Hashable

/-- Pretty-print a `Pos` value. -/
def Pos.toString : Pos → String
  | .noun => "Noun"
  | .adjective => "Adjective"
  | .numeral => "Numeral"
  | .determiner => "Determiner"
  | .pronoun => "Pronoun"
  | .verb => "Verb"
  | .verbPhrase => "VerbPhrase"
  | .conjunction => "Conjunction"
  | .adverb => "Adverb"
  | .preposition => "Preposition"
  | .quantifier => "Quantifier"
  | .determinerQuantifier => "DetQuant"
  | .keyword => "Keyword"
  | .attribute => "Attribute"
  | .tactic => "Tactic"
  | .interjection => "Interjection"
  | .constructor => "Constructor"
  | .eliminator => "Eliminator"

instance : ToString Pos := ⟨Pos.toString⟩

/-- The grammatical category for a type (noun phrase) is always `noun`. -/
def Pos.ofType : Pos := .noun

/-- The grammatical category for a function is `verb`. -/
def Pos.ofFunction : Pos := .verb

/-- The grammatical category for a predicate is `adjective`. -/
def Pos.ofPredicate : Pos := .adjective

-----------------------------------------------------------------------
-- Layer 3 helpers: classify by structure
-----------------------------------------------------------------------

/-- Determine if a string looks like a predicate (starts with a capital letter
    and ends with a capital letter suffix) or a property marker
    (`Is`, `Has`, `Exists`, etc.).
-/
def Pos.isPredicateMarker (s : String) : Bool :=
  s.startsWith "Is" || s.startsWith "Has" || s.startsWith "Exists"

/-- Heuristics for part-of-speech assignment from an identifier. -/
def Pos.classify (tok : Lexeme) : Pos :=
  let s := tok.text
  if s = "True" || s = "False" || s = "Empty" || s = "Unit" || s = "Option" then
    .determiner
  else if s.startsWith "Is" || s.startsWith "Has" ||
         s = "Nat" || s = "Int" || s = "Rat" || s = "Real" || s = "Complex" then
    if Pos.isPredicateMarker s then .adjective else .numeral
  else if s = "and" || s = "or" || s = "xor" || s = "iff" then
    .conjunction
  else if s = "forall" || s = "exists" || s = "existsUnique" then
    .quantifier
  else if s.startsWith "_" then
    .keyword
  else
    .noun  -- default for identifiers

end LinguaLean
