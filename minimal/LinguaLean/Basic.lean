namespace LinguaLean

/- ========================================================-
   Multi-Layered Classification of Lean 4 Keywords and Terms
- ======================================================== -

We model Lean identifiers and keywords as *lexical items* that pass through a
pipeline of six layers of analysis:

  L0  Syntax      — positional context (whitespace, indentation, nesting)
  L1  Lexical     — raw token extraction (identifier, keyword, operator, binder)
  L2  Morphology  — decomposition into morphemes (camelCase, underscores, prefixes)
  L3  Pos         — grammatical part-of-speech (noun, verb, adjective, …)
  L4  Semantics   — mathematical domain (arithmetic, logic, algebra, …)
  L5  ProofRole   — proof-theoretic role (axiom, def, lemma, theorem, …)
  L6  Dependency  — import and reference graph

This file defines the data structures and the classification functions at
each layer.  Separate files populate the concrete keyword tables and run
the classifier over signature data.
-/

-----------------------------------------------------------------------
-- LAYER 0: Syntactic context
-----------------------------------------------------------------------

/-- Syntactic context for an identifier occurrence (Layer 0). -/
inductive SyntacticContext
  | topLevel     -- declaration header or module level
  | withinBinder -- inside `∀`, `∃`, `fun`, `match`, `λ`
  | withinApp    -- as an argument in a function application
  | withinHead   -- as the head of a function application
  | withinBinderName -- as a bound variable name
  | withinFieldAccessor -- as a structure field accessor (e.g. `.field`)
  | withinNotation  -- part of custom notation or macro
  deriving BEq, Repr

-----------------------------------------------------------------------
-- LAYER 1: Lexical token
-----------------------------------------------------------------------

/-- Raw token classes extracted from Lean source (Layer 1). -/
inductive TokenClass
  | ident       -- `foo`, `IsGroupHom`, `Nat.add`
  | keyword     -- `def`, `theorem`, `namespace`
  | operator    -- `+`, `*`, `→`, `∀`, `∃`
  | literal     -- `42`, `"hello"`
  | binder      -- `fun`, `have`, `show`, `assume`
  | delimiter   -- `(`, `)`, `{`, `}`, `[`, `]`
  | comment     -- `--`, `/- -/`
  deriving BEq, Repr

/-- A fully resolved token with its class. -/
structure Token where
  /-- The raw source representation. -/
  raw : String
  /-- Its syntactic context. -/
  context : SyntacticContext
  /-- Its lexical class. -/
  class : TokenClass
  deriving Repr, BEq

-----------------------------------------------------------------------
-- LAYER 2: Morpheme (import from LinguaLean.Morphology)
-----------------------------------------------------------------------

-- Already defined in Morphology.lean; we provide aliases.

-- `Lexeme`, `Morpheme` are defined in `LinguaLean.Pos`

-----------------------------------------------------------------------
-- LAYER 3: Part of Speech (already in Pos.lean)
-----------------------------------------------------------------------

-- `Pos` is defined in `LinguaLean.Pos`

-----------------------------------------------------------------------
-- LAYER 4: Semantic Category
-----------------------------------------------------------------------

/-- Semantic categories for the domain classification layer. -/
inductive SemanticCategory
  | arithmetic          -- `+, -, *, /, pow, sqrt, log, exp, trig`
  | logic               -- `and, or, not, iff, forall, exists, by_contra`
  | algebra             -- `group, ring, field, module, linear_map`
  | analysis            -- `limit, continuous, differentiable, integral, measure`
  | categoryTheory      -- `functor, monad, natural_transformation, iso`
  | dataStructures      -- `List, Array, Tree, Graph, Map, Set, Matrix`
  | typeTheory          -- `Sigma, Pi, subtype, quotient, equivalence`
  | topology            -- `open, closed, compact, connected, continuous`
  | combinatorics       -- `partition, coloring, graph, euler`
  | numberTheory        -- `prime, mod, dvd, gcd, lcm, zeta`
  | computation         -- `turing, complexity, decidable, reduction`
  | algebraistSpecific  -- `Aristotle, Godel, Quine`
  | systemStack         -- `Nix, LLVM, GCC, Linux, CompCert, TinyC`
  | languageMeta        -- `Mojo, Elixir, Node, Python`
  | fileSystem          -- `IPFS, WASM, FileDrop`
  | hypertext           -- HTML, Web, GUI
  | zkp                 -- Zero-knowledge proofs, Solana, BPF
  | misc                -- uncategorized
  deriving BEq, DecidableEq, Repr, Hashable, Inhabited

/-- String alias for each semantic category. -/
def SemanticCategory.toString : SemanticCategory → String
  | .arithmetic => "Arithmetic"
  | .logic => "Logic"
  | .algebra => "Algebra"
  | .analysis => "Analysis"
  | .categoryTheory => "CategoryTheory"
  | .dataStructures => "DataStructures"
  | .typeTheory => "TypeTheory"
  | .topology => "Topology"
  | .combinatorics => "Combinatorics"
  | .numberTheory => "NumberTheory"
  | .computation => "Computation"
  | .algebraistSpecific => "AristotleSpecific"
  | .systemStack => "SystemStack"
  | .languageMeta => "LanguageMeta"
  | .fileSystem => "FileSystem"
  | .hypertext => "Hypertext"
  | .zkp => "ZeroKnowledge"
  | .misc => "Miscellaneous"

instance : ToString SemanticCategory := ⟨SemanticCategory.toString⟩

/-- Heuristic keyword mapping for semantic categories. -/
def SemanticCategory.classify (token : Token) : SemanticCategory :=
  let s := token.raw.toLower
  let checks : List (String × SemanticCategory) := [
    ("add", .arithmetic), ("mul", .arithmetic), ("sub", .arithmetic),
    ("div", .arithmetic), ("pow", .arithmetic), ("zpow", .arithmetic),
    ("sqrt", .arithmetic), ("log", .arithmetic), ("exp", .arithmetic),
    ("and", .logic), ("or", .logic), ("not", .logic), ("iff", .logic),
    ("forall", .logic), ("exists", .logic), ("by_contra", .logic),
    ("group", .algebra), ("ring", .algebra), ("field", .algebra),
    ("module", .algebra), ("algebra", .algebra),
    ("continuous", .analysis), ("differentiable", .analysis),
    ("integral", .analysis), ("limit", .analysis), ("measure", .analysis),
    ("functor", .categoryTheory), ("monad", .categoryTheory),
    ("natural", .categoryTheory), ("morphism", .categoryTheory),
    ("list", .dataStructures), ("array", .dataStructures),
    ("tree", .dataStructures), ("graph", .dataStructures),
    ("map", .dataStructures), ("set", .dataStructures),
    ("vector", .dataStructures), ("matrix", .dataStructures),
    ("sigma", .typeTheory), ("subtype", .typeTheory),
    ("quotient", .typeTheory), ("equivalence", .typeTheory),
    ("open", .topology), ("closed", .topology), ("compact", .topology),
    ("connected", .topology), ("hausdorff", .topology),
    ("prime", .numberTheory), ("gcd", .numberTheory), ("lcm", .numberTheory),
    ("zeta", .numberTheory), ("modular", .numberTheory),
    ("turing", .computation), ("decidable", .computation),
    ("aristotle", .algebraistSpecific), ("godel", .algebraistSpecific),
    ("quine", .algebraistSpecific), ("nix", .systemStack),
    ("llvm", .systemStack), ("gcc", .systemStack), ("linux", .systemStack),
    ("compcert", .systemStack), ("tinyc", .systemStack),
    ("mojo", .languageMeta), ("elixir", .languageMeta),
    ("nodejs", .languageMeta), ("python", .languageMeta),
    ("wasm", .fileSystem), ("ipfs", .fileSystem),
    ("html", .hypertext), ("web", .hypertext),
    ("zk", .zkp), ("zkp", .zkp), ("solana", .zkp), ("proof", .zkp)
  ]

  -- try each keyword; return first match
  for (kw, cat) in checks do
    if s.containsSubstr kw then
      return cat
  .misc

-----------------------------------------------------------------------
-- LAYER 5: Proof Role
-----------------------------------------------------------------------

/-- Proof-theoretic roles of Lean declarations (Layer 5). -/
inductive ProofRole
  | axiom        -- assumed without proof
  | definition   -- `def foo := ...`
  | theorem      -- proven statement
  | lemma        -- intermediate proven statement
  | corollary    -- consequence of a theorem
  | instance     -- typeclass instance
  | structure    -- `structure Foo where ...`
  | typeclass    -- `class Foo where ...`
  | inductive    -- `inductive Foo where ...`
  | constructor  -- data constructor
  | elimRule     -- elimination principle generated by `inductive`
  | recursor     -- `rec` / `recOn`
  | notation     -- custom notation / syntax declaration
  | meta         -- meta-level declaration
  | variable     -- `variable` declaration
  deriving BEq, Repr, DecidableEq

/-
  The ProofRole is not always determinable from the identifier name; it is
  assigned by the parser or a semantic analysis pass.  However, we can use
  naming conventions as a heuristic.
-/

-----------------------------------------------------------------------
-- LAYER 6: Dependency
-----------------------------------------------------------------------

/-- A directed reference from one declaration to another (Layer 6).

  Used to build a dependency graph for cross-repo impact analysis.
-/
structure DependencyEdge where
  /-- The identifier that depends on something. -/
  dependent : String
  /-- The identifier it depends on (e.g. definition, axiom, import). -/
  dependsOn : String
  /-- The kind of dependency. -/
  kind : DependencyKind
  deriving Repr, BEq

inductive DependencyKind
  | imports   -- `import` or structural import
  | references -- identifier used in a term
  | typechecks  -- typeclass inference / instance resolution
  | tacticDep   -- tactic that relies on a lemma/theorem
  deriving BEq, Repr

-----------------------------------------------------------------------
-- The full multi-layered Analysis
-----------------------------------------------------------------------

/-- The complete 6-layer analysis of a single identifier. -/
structure Analysis where
  /-- L0: Syntactic position. -/
  syn : SyntacticContext
  /-- L1: Token class. -/
  tok : Token
  /-- L2: Morpheme decomposition. -/
  morphemes : List Morpheme
  /-- L3: Part of speech. -/
  pos : Pos
  /-- L4: Semantic domain. -/
  semantics : SemanticCategory
  /-- L5: Proof-theoretic role (optional). -/
  proofRole : Option ProofRole := none
  /-- L6: Dependencies (optional). -/
  dependencies : List DependencyEdge := []
  deriving Repr

/-- Project the `WordType` from an `Analysis`. -/
def Analysis.wordType (a : Analysis) : WordType :=
  WordType.fromPos a.pos

/-- Convenience constructor from a token string. -/
def Analysis.fromToken (s : String) : Analysis :=
  let tok : Token := {
    raw := s,
    context := .topLevel,
    class := .ident
  }
  let pos := Pos.classify ⟨s⟩
  let sem := SemanticCategory.classify tok
  {
    syn := .topLevel,
    tok := tok,
    morphemes := [],
    pos := pos,
    semantics := sem
  }

end LinguaLean
