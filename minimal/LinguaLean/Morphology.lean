namespace LinguaLean

/- ========================================================-
   Layer 2: Morphology — decomposition of Lean identifiers
- ======================================================== -

The Lean/Mathlib naming convention follows Haskell-like conventions
combined with semantic suffixes/prefixes:

  Prefixes:   `Is`, `Has`, `Of`, `To`, `Coerc`, `With`, `No`
  Suffixes:   `_iff`, `_of`, `_eq`, `_ne`, `_le`, `_lt`, `_ge`, `_gt`, `_decidable_`
  Compound:   CamelCase / isCamelCase (`List.map`, `IsCompact`)

Morphemes are used to split identifiers and help the POS classifier
make better decisions.
-/

/-- A lexical identifier with its raw source text. -/
structure Lexeme where
  /-- The raw source text. -/
  text : String
  deriving Repr, BEq, Hashable, DecidableEq, Inhabited

/-- Morpheme decomposition of an identifier (Layer 2). -/
inductive Morpheme
  /-- prefix + body, e.g. `IsPrime` → `"Is"` + `"Prime"` -/
  | prefix (p : String) (body : String)
  /-- body + suffix, e.g. `foo_iff` → `"foo"` + `"_iff"` -/
  | suffix (body : String) (s : String)
  /-- infix modifier, e.g. `LeftMonoidal` → `"Left"` + `"Monoidal"` -/
  | infix (left : String) (right : String)
  /-- atomic — no meaningful decomposition -/
  | mono (body : String)
  deriving BEq, Hashable, Repr, DecidableEq, Inhabited

/-- Morpheme pretty printing. -/
def Morpheme.toString : Morpheme → String
  | .prefix p body => s!"{p}{body}"
  | .suffix body s => s!"{body}{s}"
  | .infix left right => s!"{left}{right}"
  | .mono body => body

instance : ToString Morpheme := ⟨Morpheme.toString⟩

/- ========================================================-
   Morphological Analysis
- ======================================================== -

Morphological analysis splits a raw identifier into morphemes.
This is used to:
  1. Extract semantic hints (prefix `Is`, suffix `_iff`)
  2. Generate human-readable annotations
  3. Enable fuzzy matching across camelCase/haskellCase variants
-/

/-- Split a string by an arbitrary predicate. -/
def String.splitBy (s : String) (pred : Char → Bool) : List String :=
  let words := s.toList.foldl (fun acc c =>
    if pred c then
      if acc.getLast?.getD "" != "" then acc ++ [""] else acc
    else acc ++ [String.singleton c]) []
  words

/--
Decompose a raw identifier into morphemes.

Heuristics:
  1. Trailing suffixes: `_iff`, `_eq`, `_ne`, `_of`, `_le`, `_lt`, `_ge`, `_gt`, `_decidable_`, `_decidableEq`, `_decidableLE`, etc.
  2. Leading prefixes: `Is`, `Has`, `Of`, `To`, `Coerce` (case sensitive)
  3. CamelCase: split on uppercase boundaries
  4. Underscore: split on underscores

For example:
  `isGroupHom`  →  prefix("is") + infix("Group","Hom")
  `AddGroup.lean` → mono("AddGroup")
  `IsCompact` → prefix("Is") + mono("Compact")
-/

-- camelCase splitter helper
def Morpheme.splitCamelCase (s : String) : List String :=
  let chars := s.toList
  let mut parts : List Char := []
  for c in chars do
    parts := parts ++ [c]
  parts.join

-- morpheme decomposition
def Morpheme.decompose (tok : Lexeme) : List Morpheme :=
  let s := tok.text

  -- 1. Check for underscore suffixes
  if s.endsWith "_iff" then
    [.suffix (s.dropRight 4) "_iff"]
  else if s.endsWith "_eq" then
    [.suffix (s.dropRight 3) "_eq"]
  else if s.endsWith "_ne" then
    [.suffix (s.dropRight 3) "_ne"]
  else if s.endsWith "_of" then
    [.suffix (s.dropRight 3) "_of"]
  else if s.endsWith "_le" then
    [.suffix (s.dropRight 2) "_le"]
  else if s.endsWith "_lt" then
    [.suffix (s.dropRight 2) "_lt"]
  else if s.endsWith "_ge" then
    [.suffix (s.dropRight 2) "_ge"]
  else if s.endsWith "_gt" then
    [.suffix (s.dropRight 2) "_gt"]
  else if s.endsWith "_decidable_eq" then
    [.suffix (s.dropRight 15) "_decidable_eq"]
  else if s.endsWith "_decidable_le" then
    [.suffix (s.dropRight 15) "_decidable_le"]
  else if s.endsWith "_decidable_lt" then
    [.suffix (s.dropRight 15) "_decidable_lt"]
  else if s.endsWith "_decidable_ge" then
    [.suffix (s.dropRight 15) "_decidable_ge"]
  else if s.endsWith "_decidable_gt" then
    [.suffix (s.dropRight 15) "_decidable_gt"]
  else if s.contains '_' then
    -- split by underscore
    s.split (· == '_').map fun p => .mono p
  else
    -- 2. Check for prefix
    if s.length >= 2 ∧ s[0] = 'I' ∧ s[1] = 's' ∧ s.length > 2 then
      [.prefix "Is" s[2:]]
    else if s.length >= 3 ∧ s[0] = 'H' ∧ s[1] = 'a' ∧ s[2] = 's' then
      [.prefix "Has" s[3:]]
    else if s.length >= 2 ∧ s[0] = 'O' ∧ s[1] = 'f' then
      [.prefix "Of" s[2:]]
    else if s.startsWith "To" || s.startsWith "Coerce" then
      let p := if s.startsWith "Coerce" then "Coerce" else "To"
      [.prefix p s[p.length:]]
    else
      -- 3. CamelCase split
      s.foldl (fun acc c =>
        if c.isUpper && !acc.getLast?.getD 'a'.isUpper then
          acc ++ [c]
        else
          acc) [""] |>.join |>.split (fun c => c.isUpper) |>.map fun part =>
          .mono part

-- convenience
instance : Coe Lexeme Morpheme where
  coe := .mono

/- ========================================================-
   Morphological properties for classification feedback
- ======================================================== -

Morphological properties are used to improve classification
decisions and provide feedback.
-/

/-- Morpheme properties for classification feedback. -/
structure MorphProps where
  /-- Does the identifier have any decomposition? -/
  decomposed : Bool
  /-- Prefixes (if any). -/
  prefixes : List String := []
  /-- Suffixes (if any). -/
  suffixes : List String := []
  /-- Number of parts after splitting. -/
  parts : Nat := 0
  /-- Is it a pure atom? -/
  isAtomic : Bool := false

/-- Extract morphological properties from an identifier. -/
def MorphProps.mk (tok : Lexeme) : MorphProps :=
  let ms := Morpheme.decompose tok
  let dec := !ms.contains .mono
  let prefixes := ms.map (fun m => match m with | .prefix p _ => p | _ => "") |>.filter fun p => !p.isEmpty
  let suffixes := ms.map (fun m => match m with | .suffix _ s => s | _ => "") |>.filter fun s => !s.isEmpty
  let parts := ms.length
  let isAtomic := ms.length = 1 ∧ ms[0]! = .mono tok.text
  { decomposed := dec, prefixes, suffixes, parts, isAtomic }

/-- Morphological properties pretty printing. -/
def MorphProps.toString (mp : MorphProps) : String :=
  s!"[decomposed={mp.decomposed} prefixes={mp.prefixes.join ", "} suffixes={mp.suffixes.join ", "} parts={mp.parts} atomic={mp.isAtomic}]"

instance : ToString MorphProps := ⟨MorphProps.toString⟩

end Morphology
