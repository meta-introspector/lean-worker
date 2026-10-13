namespace LinguaLean

/- ========================================================-
   Linguistic classifiers for the Sigil-Style classification
- ======================================================== -

/--
`WordType` classifies identifiers by a subset of the *parts of speech*
(`LinguaLean.Pos`) focusing on four grammatical slots:

  • Type            (a ``noun`` that denotes a type)
  • Typeclass        (an ``adjective`` of type specifications)
  • Instance        (noun phrase or expression in type position)
  • Operator         (verb-like, binary or unary, that appears infix or prefix)
  • Constructive    (unary verb, “construction”, like ``Int.add``)
  • Connective      (logic connectives: ``∧``, ``∨``, ``¬``, ``↔``)
  • Quantifier       (``∀``, ``∃``, ``∃!``)
  • Attribute        (Lean keywords ``reducible``, ``simp``, ``norm_num``)
  • Tactic           (proof-construction verbs like ``rw``, ``simp``, ``apply``)
-/
inductive WordType
  | `Type`        -- type constructor (`Nat`, `Int`, `List`, `AddGroup`)
  | `Typeclass`    -- type class ``adjective`` (`AddGroup`, `CommRing`)
  | `Instance`     -- concrete instance (term in type position: ``To := 3``)
  | `Operator`     -- infix/ binary function (````add`` ``, ````mul`` ``)
  | `Constructive` -- unary verb of “construction`` (````to`` ``, ````coe`` ``)
  | `Connective`   -- logical operator (````and`` ``, ````or`` ``, ````iff`` ``)
  | `Quantifier`   -- quantifier (````forall`` ``, ````exists`` ``, ````existsUnique`` ``)
  | `Attribute`    -- Lean attribute (````reducible`` ``, ````simp`` ``, ````norm_num`` ``)
  | `Tactic`       -- tactic name (````rw`` ``, ````simp`` ``, ````apply`` ``)
  | `Keyword`      -- keyword (````def`` ``, ````theorem`` ``, ````namespace`` ``)
  | `Constructor`   -- data constructor (````list.nil`` ``, ````left`` ``)
  | `Eliminator`    -- eliminator (````cases`` ``, ````rec`` ``)
  | `Module`       -- module or namespace (````Mathlib`` ``, ````Lean`` ``)
  deriving BEq, Hashable, DecidableEq, Repr, Inhabited

/-- Heuristic mappings from POS to WordType. -/
def WordType.fromPos (pos : Pos) : WordType :=
  match pos with
  | .noun => .Type
  | .adjective => .Typeclass
  | .determiner => .Instance
  | .verb => .Operator
  | .verbPhrase => .Constructive
  | .conjunction => .Connective
  | .quantifier => .Quantifier
  | .attribute => .Attribute
  | .tactic => .Tactic
  | .keyword => .Keyword
  | .constructor => .Constructor
  | .eliminator => .Eliminator
  | .adverb || .pronoun || .determinerQuantifier || .adverb => .Instance
  | .numeral || .pronoun => .Type

/-- Composition of a multi-layer analysis.

A language description can be built bottom-up:
   • layer 0: positional syntax (``whitespace``, ``indentation``)
   • layer 1: lexical (token, ``Unicode``, ``Ascii``)
   • layer 2: morphological (camelCase, suffix ``_iff``, prefix ``to``)
   • layer 3: ``LinguaLean.Pos`` (part-of-speech)
   • layer 4: ``LinguaLean.SemanticCategory`` (domain)
   • layer 5: ``LinguaLean.ProofRole`` (proof-theoretic)
   • layer 6: ``LinguaLean.DependsOn`` (depends on other terms)
-/
/-- The comprehensive multi-layer analysis of an identifier. -/
structure TermAnalysis where
  /-- The raw lexical token. -/
  lexeme : Lexeme
  /-- Morphological decomposition (camelCase, prefixes, suffixes). -/
  morphemes : List Morpheme
  /-- The part-of-speech (Layer 3). -/
  pos : Pos
  /-- The semantic word type for domain classification (WordType). -/
  word_type : WordType
  /-- Optional comment for human readability. -/
  comment : String := ""

/-- Builder for convenience. -/
def TermAnalysis.ofPos (pos : Pos) : TermAnalysis :=
  { lexeme := ⟨"placeholder"⟩, morphemes := [], pos := pos, word_type := WordType.fromPos pos, comment := "" }

/-- Helper to show a TermAnalysis.
   Example: ``TermAnalysis.toString .pos.toString`` -/
def TermAnalysis.toString (ta : TermAnalysis) : String :=
  let pos_str := ta.pos.toString
  let word_str := ta.word_type.toString
  s!"[lex: {ta.lexeme.text} | pos: {pos_str} | word_type: {word_str}]"

/- ========================================================-
   Signature-based classification helpers for Lean code.
- ======================================================== -

/-- 
Return a ``WordType`` for an identifier based on heuristics applied to
Lean/Mathlib identifier naming conventions.

The heuristics focus on:
  • Upper-case starts: type / typeclass / adjective / numeral
  • CamelCase patterns: prefix ``to``, ``of``, ``of_`` → Verb; ``add``, ``mul`` → Operator; ``is_``, ``has_``, ``eq_of_`` → Adjective
  • Conjunctions: ``and``, ``or``, ``xor``, ``iff``, ``iff_``
  • Quantifiers: ``forall``, ``exists``, ``existsUnique``
  • Logic meta: ``by_contra``, ``by_cases``, ``by_refine``
  • Attributes: ``simp``, ``norm_num``, ``reducible``, ``irrecoverable``
  • Tactics: ``intro``, ``apply``, ``rw``, ``simp``, ``cases``
-/
def WordType.ofString (s : String) : WordType :=
  if s = "and" || s = "or" || s = "xor" || s = "iff" || s.endsWith "_iff" then
    .Connective
  else if s = "forall" || s = "exists" || s = "existsUnique" then
    .Quantifier
  else if s = "simp" || s = "norm_num" || s = "reducible" || s = "irreducible" || s = "norm_auto" then
    .Attribute
  else if s = "intro" || s = "apply" || s = "rw" || s = "simp" || s = "cases" || s = "induction" || s = "refine" || s = "calc" then
    .Tactic
  else if s = "by_contra" || s = "by_cases" || s = "by_refine" then
    .Tactic
  else if s = "def" || s = "theorem" || s = "lemma" || s = "example" || s = "namespace" || s = "import" || s = "open" || s = "section" || s = "variable" || s = "attribute" || s = "derive" || s = "structure" || s = "class" || s = "instance" || s = "mutual" || s = "reducible" || s = "irrecoverable" || s = "unsafe" || s = "synthetic" || s = "include" || s = "local" || s = "open" || s = "sorry" || s = "admit" then
    .Keyword
  else if s.startsWith "to" && !s.startsWith "transform" && !s.startsWith "transfer" then
    .Constructive
  else if s = "add" || s = "mul" || s = "sub" || s = "div" || s = "pow" || s = "rem" || s = "neg" || s = "neg_one" || s = "one" || s = "zero" || s = "nat" || s = "int" || s = "rat" || s = "real" || s = "complex" || s = "sqrt" || s = "abs" || s = "floor" || s = "ceil" || s = "log" || s = "exp" || s = "logarithm" || s = "exponential" || s = "trigonometric" then
    .Operator
  else if s = "eq" || s = "le" || s = "lt" || s = "ge" || s = "gt" || s = "decidable_eq" || s = "decidable_le" || s = "decidable_lt" || s = "decidable_ge" || s = "decidable_gt" || s = "neq" then
    .Operator
  else if s = "map" || s = "flatMap" || s = "foldl" || s = "foldr" || s = "mapM" || s = "traverse" then
    .Operator
  else if s.startsWith "is_" then
    .Typeclass
  else if s.startsWith "has_" then
    .Typeclass
  else if s = "nat" || s = "int" || s = "rat" || s = "real" || s = "complex" || s = "fin" || s = "nat_
              || s = "int" || s = "rat" || s = "real" || s = "complex" || s = "fin" || s = "nat_
              || s = "int" || s = "rat" || s = "real" || s = "complex" || s = "fin" then
    .Type
  else if s.startsWith "List" || s = "Array" || s = "Vector" || s = "Stream" || s = "Sequence" || s = "Tree" || s = "Graph" || s = "Map" || s = "Set" || s = "Matrix" || s = "Tuple" || s = "Product" || s = "Sum" || s = "Option" || s = "IO" || s = "Sum" then
    .Type
  else if s = "left" || s = "right" || s = "top" || s = "bottom" || s = "head" || s = "tail" || s = "first" || s = "second" || s = "third" || s = "fourth" || s = "fifth" || s = "sixth" || s = "seventh" || s = "eighth" || s = "ninth" || s = "tenth" then
    .Constructor
  else if s = "rec" || s = "cases" || s = "match" || s = "pattern" || s = "induction" || s = "match" || s = "match" || s = "match" || s = "match" || s = "match" || s = "match" then
    .Eliminator
  else if s = "Mathlib" || s = "Lean" || s = "Lean.Utils" || s = "Lean.Data" || s = "Lean.Logic" || s = "Mathlib.Tactic" || s = "Mathlib.Data" || s = "Mathlib.Algebra" || s = "Mathlib.Topology" || s = "Mathlib.Analysis" then
    .Module
  else
    .Type  -- default fallback

end LinguaLean