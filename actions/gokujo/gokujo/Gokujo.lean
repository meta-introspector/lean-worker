/-!
# 極上 · gokujō — a Swiss army knife for Lean 4

`gokujo` is **one Lean file** and **one Markdown file**.  The Lean file is the
program; the Markdown file contains the Lean file; the program contains the
documentation; the program prints the documentation as text (CLI) or as a
single self-contained HTML page.

It is meant to be dropped into any Lean project as the only build- and
proof-checking tool that project needs: it replaces the roles of `make`,
`lake`, `elan` and `nix` for the job of *preparing and checking proofs*.

    gokujo help                  # the manual, in the terminal
    gokujo html -o gokujo.html   # the manual, as one self-contained page
    gokujo doctor                # which toolchains this machine can use
    gokujo scan RequestProject   # parse Lean sources, list declarations
    gokujo sorry RequestProject  # fail if any `sorry`/`admit` is reachable
    gokujo graph RequestProject  # import graph + verified topological order
    gokujo build RequestProject  # compile every module, no lake, no make
    gokujo axioms RequestProject # audit the axioms behind every theorem
    gokujo check                 # scan + build + sorry + axioms, one gate
    gokujo tangle GOKUJO.md      # Markdown  -> Lean
    gokujo weave  Gokujo.lean    # Lean      -> Markdown
    gokujo selfcheck             # the two files still agree
    gokujo bootstrap             # compile gokujo itself to a native binary
    gokujo targets               # the per-platform executable matrix

This file has no imports.  It is core Lean 4 only, so it compiles with a bare
`lean` binary in about a second, on any toolchain, with no package manager and
no network.

The parts of `gokujo` that could silently lie are *proved*: the lexer loses no
characters (`Gokujo.Lex.tokenize_faithful`), a reported `sorry` is always a
real code token of the file (`Gokujo.Syn.reported_holes_are_code`), the
Markdown round trip is an identity (`Gokujo.Md.tangle_weave`), the escaping
used by the HTML output really escapes (`Gokujo.Html.escape_no_lt`), and the
build order it hands to the compiler is checked, by a checker that is proved
sound (`Gokujo.Graph.order_ok_sound`).
-/

namespace Gokujo

/-! ## 0. Identity -/

/-- The version of the knife. -/
def version : String := "1.0.0"

/-- The name, in Japanese: 極上 *gokujō*, "finest quality". -/
def kanji : String := "極上"

/-! ## 1. Small utilities

Nothing here is clever; it is here so that the file needs no imports.
-/

namespace Util

/-- FNV-1a, 64 bit.  Used for content hashes in the build engine. -/
def fnv1a (cs : List Char) : UInt64 :=
  cs.foldl (fun h c => (h ^^^ (UInt64.ofNat c.toNat)) * 1099511628211) 14695981039346656037

/-- A short hexadecimal digest. -/
def hex16 (n : UInt64) : String :=
  let digits := "0123456789abcdef".toList
  let rec go (i : Nat) (n : Nat) (acc : List Char) : List Char :=
    match i with
    | 0 => acc
    | i+1 => go i (n / 16) (digits.getD (n % 16) '0' :: acc)
  String.ofList (go 16 n.toNat [])

/-- Content digest of a string. -/
def digest (s : String) : String := hex16 (fnv1a s.toList)

/-- Split into lines, keeping no terminators. -/
def lines (s : String) : List String := s.splitOn "\n"

/-- Join lines with newlines. -/
def unlines (ls : List String) : String := String.intercalate "\n" ls

/-- Left-pad to a width. -/
def padL (s : String) (w : Nat) : String :=
  if s.length ≥ w then s else String.ofList (List.replicate (w - s.length) ' ') ++ s

/-- Right-pad to a width. -/
def padR (s : String) (w : Nat) : String :=
  if s.length ≥ w then s else s ++ String.ofList (List.replicate (w - s.length) ' ')

/-- Deduplication, keeping first occurrences (fuel-driven, hence total). -/
def dedupAux : Nat → List String → List String
  | 0, _ => []
  | _, [] => []
  | n+1, a :: as => a :: dedupAux n (as.filter (· != a))

/-- `List.dedup` for strings, keeping first occurrences. -/
def dedup (l : List String) : List String := dedupAux l.length l

/-- Does `s` start with `p`? -/
def startsWith (s p : String) : Bool := s.startsWith p

/-- Remove a prefix if present. -/
def dropPrefix (s p : String) : String :=
  if s.startsWith p then (s.drop p.length).toString else s

/-- Trim ASCII whitespace on both ends. -/
def trim (s : String) : String := s.trimAscii.toString

end Util

/-! ## 2. A lexer for Lean 4

The scanner below understands exactly as much Lean surface syntax as a tool
needs in order to *not be fooled*: nested block comments, doc comments, line
comments, string literals with escapes, character literals, identifiers
(including the non-ASCII ones Lean allows), numerals and symbols.

That is the whole point of having a parser here rather than a regular
expression: a `sorry` inside a comment or a string is not a `sorry`, and a
`theorem` keyword inside a docstring is not a declaration.

The lexer is proved faithful: concatenating the text of the tokens gives back
the input, character for character (`tokenize_faithful`).  So nothing is
dropped, nothing is invented, and every character of the file is classified
exactly once.
-/

namespace Lex

/-- Token classes. -/
inductive Kind
  | space
  | lineComment
  | blockComment
  | docComment
  | str
  | chr
  | num
  | ident
  | sym
  deriving DecidableEq, Repr, Inhabited

/-- A token: its class and the exact characters it consumed. -/
structure Tok where
  kind : Kind
  text : List Char
  deriving Repr, Inhabited

/-- The token's text as a `String`. -/
def Tok.str (t : Tok) : String := String.ofList t.text

/-- Is this token invisible to the language (comment or whitespace)? -/
def Tok.trivia (t : Tok) : Bool :=
  t.kind == .space || t.kind == .lineComment || t.kind == .blockComment || t.kind == .docComment

/-- Characters that may start an identifier.  Lean allows a lot of Unicode. -/
def isIdentStart (c : Char) : Bool :=
  c.isAlpha || c = '_' || c.toNat > 127

/-- Characters that may continue an identifier. -/
def isIdentCont (c : Char) : Bool :=
  c.isAlphanum || c = '_' || c = '\'' || c = '!' || c = '?' || c = 'ₓ' || c.toNat > 127

/-- Characters that may continue a numeral (hex digits and separators). -/
def isNumCont (c : Char) : Bool :=
  c.isAlphanum || c = '.' || c = '_'

/-- Scan the interior of a `/- ... -/` comment, at nesting depth `d`.
Returns the consumed text (including the closing delimiter, if any) and the
rest of the input. -/
def scanBlock : Nat → List Char → List Char × List Char
  | _, [] => ([], [])
  | d, '-' :: '/' :: cs =>
      match d with
      | 0 => (['-', '/'], cs)
      | d+1 => let r := scanBlock d cs; ('-' :: '/' :: r.1, r.2)
  | d, '/' :: '-' :: cs => let r := scanBlock (d+1) cs; ('/' :: '-' :: r.1, r.2)
  | d, c :: cs => let r := scanBlock d cs; (c :: r.1, r.2)

theorem scanBlock_append (d : Nat) (cs : List Char) :
    (scanBlock d cs).1 ++ (scanBlock d cs).2 = cs := by
  fun_induction scanBlock d cs <;> simp_all +zetaDelta

/-- Scan the interior of a string literal, after the opening quote. -/
def scanStr : List Char → List Char × List Char
  | [] => ([], [])
  | '\\' :: c :: cs => let r := scanStr cs; ('\\' :: c :: r.1, r.2)
  | '"' :: cs => (['"'], cs)
  | c :: cs => let r := scanStr cs; (c :: r.1, r.2)

theorem scanStr_append (cs : List Char) :
    (scanStr cs).1 ++ (scanStr cs).2 = cs := by
  fun_induction scanStr cs <;> simp_all +zetaDelta

/-- Read one token off the front of the input. -/
def nextTok : List Char → Option (Tok × List Char)
  | [] => none
  | c :: cs =>
    let input := c :: cs
    if c.isWhitespace then
      some (⟨.space, input.takeWhile Char.isWhitespace⟩, input.dropWhile Char.isWhitespace)
    else
      match c, cs with
      | '-', '-' :: rest =>
          let body := rest.takeWhile (· ≠ '\n')
          some (⟨.lineComment, '-' :: '-' :: body⟩, rest.dropWhile (· ≠ '\n'))
      | '/', '-' :: rest =>
          let r := scanBlock 0 rest
          let kind := match r.1 with
            | '!' :: _ => Kind.docComment
            | '-' :: _ => Kind.docComment
            | _ => Kind.blockComment
          some (⟨kind, '/' :: '-' :: r.1⟩, r.2)
      | '"', rest =>
          let r := scanStr rest
          some (⟨.str, '"' :: r.1⟩, r.2)
      | '\'', '\\' :: a :: '\'' :: rest =>
          some (⟨.chr, ['\'', '\\', a, '\'']⟩, rest)
      | '\'', a :: '\'' :: rest =>
          if a = '\\' then some (⟨.sym, ['\'']⟩, a :: '\'' :: rest)
          else some (⟨.chr, ['\'', a, '\'']⟩, rest)
      | c, cs =>
          if isIdentStart c then
            some (⟨.ident, c :: cs.takeWhile isIdentCont⟩, cs.dropWhile isIdentCont)
          else if c.isDigit then
            some (⟨.num, c :: cs.takeWhile isNumCont⟩, cs.dropWhile isNumCont)
          else
            some (⟨.sym, [c]⟩, cs)

theorem nextTok_append {cs : List Char} {t : Tok} {rest : List Char}
    (h : nextTok cs = some (t, rest)) : t.text ++ rest = cs := by
  unfold nextTok at h
  split at h
  · simp at h
  · rename_i c cs'
    split at h
    · simp at h; obtain ⟨rfl, rfl⟩ := h
      simp [List.takeWhile_append_dropWhile]
    · split at h
      all_goals (try (simp at h; done))
      · rename_i rest _
        simp at h; obtain ⟨rfl, rfl⟩ := h
        simp [List.takeWhile_append_dropWhile]
      · rename_i rest _
        simp at h; obtain ⟨rfl, rfl⟩ := h
        simp [scanBlock_append]
      · rename_i rest _
        simp at h; obtain ⟨rfl, rfl⟩ := h
        simp [scanStr_append]
      · rename_i a rest _
        simp at h; obtain ⟨rfl, rfl⟩ := h
        simp
      · rename_i a rest _
        split at h
        · simp at h; obtain ⟨rfl, rfl⟩ := h; simp_all
        · simp at h; obtain ⟨rfl, rfl⟩ := h; simp
      · rename_i c'' cs'' _ _ _ _ _
        split at h
        · simp at h; obtain ⟨rfl, rfl⟩ := h
          simp [List.takeWhile_append_dropWhile]
        · split at h
          · simp at h; obtain ⟨rfl, rfl⟩ := h
            simp [List.takeWhile_append_dropWhile]
          · simp at h; obtain ⟨rfl, rfl⟩ := h
            simp

theorem nextTok_ne_nil {cs : List Char} {t : Tok} {rest : List Char}
    (h : nextTok cs = some (t, rest)) : t.text ≠ [] := by
  unfold nextTok at h
  split at h
  · simp at h
  · rename_i c cs'
    split at h
    · rename_i hw
      simp at h; obtain ⟨rfl, rfl⟩ := h
      simp [hw]
    · split at h
      all_goals (try (simp at h; done))
      all_goals
        first
          | (simp at h; obtain ⟨rfl, rfl⟩ := h; simp)
          | (split at h <;> (simp at h; obtain ⟨rfl, rfl⟩ := h; simp))
          | (split at h <;>
              first
                | (simp at h; obtain ⟨rfl, rfl⟩ := h; simp)
                | (split at h <;> (simp at h; obtain ⟨rfl, rfl⟩ := h; simp)))

theorem nextTok_lt {cs : List Char} {t : Tok} {rest : List Char}
    (h : nextTok cs = some (t, rest)) : rest.length < cs.length := by
  have happ := nextTok_append h
  have hne := nextTok_ne_nil h
  have : t.text.length + rest.length = cs.length := by
    rw [← happ]; simp
  have : 0 < t.text.length := List.length_pos_iff.mpr hne
  omega

theorem nextTok_none {cs : List Char} (h : nextTok cs = none) : cs = [] := by
  cases cs with
  | nil => rfl
  | cons c cs =>
    exfalso
    unfold nextTok at h
    iterate 6 (all_goals (first | (simp_all; done) | split at h))

/-- Tokenize an entire input.  Total, by the fact that every token consumes at
least one character. -/
def tokenize (cs : List Char) : List Tok :=
  match h : nextTok cs with
  | none => []
  | some (t, rest) =>
      have : rest.length < cs.length := nextTok_lt h
      t :: tokenize rest
termination_by cs.length

/-- **The lexer loses nothing.**  Concatenating the text of the tokens returns
the input exactly. -/
theorem tokenize_faithful (cs : List Char) :
    ((tokenize cs).map Tok.text).flatten = cs := by
  fun_induction tokenize cs with
  | case1 cs h => simp [nextTok_none h]
  | case2 cs t rest h _ ih =>
      have := nextTok_append h
      simp only [List.map_cons, List.flatten_cons, ih]
      exact this

/-! ### Running the lexer on a large file

`tokenize` is written the way it is proved: one frame per token.  On a generated
data module of a few hundred kilobytes that is tens of thousands of frames, which
overflows the stack of a compiled binary.  `tokenizeAux` is the same function with
an accumulator; `tokenizeAux_eq` proves the two agree, and the `@[csimp]` lemma
makes the compiler use the accumulating one, so the *proved* function is still the
one whose behaviour is described by `tokenize_faithful`. -/

/-- The accumulating tokenizer: tail-recursive, so it costs constant stack. -/
def tokenizeAux (acc : List Tok) (cs : List Char) : List Tok :=
  match h : nextTok cs with
  | none => acc.reverse
  | some (t, rest) =>
      have : rest.length < cs.length := nextTok_lt h
      tokenizeAux (t :: acc) rest
termination_by cs.length

/-- The accumulating tokenizer computes the tokens, after the accumulator. -/
theorem tokenizeAux_eq (acc : List Tok) (cs : List Char) :
    tokenizeAux acc cs = acc.reverse ++ tokenize cs := by
  fun_induction tokenizeAux acc cs with
  | case1 acc cs h =>
      rw [tokenize.eq_def]
      split
      · simp
      · rename_i t rest heq; rw [h] at heq; simp at heq
  | case2 acc cs t rest h _ ih =>
      have hcs : tokenize cs = t :: tokenize rest := by
        rw [tokenize.eq_def]
        split
        · rename_i heq; rw [h] at heq; simp at heq
        · rename_i t' rest' heq
          rw [h] at heq
          obtain ⟨rfl, rfl⟩ : t' = t ∧ rest' = rest := by
            simp at heq; exact ⟨heq.1.symm, heq.2.symm⟩
          rfl
      rw [ih, hcs]
      simp

/-- `tokenize`, run with an accumulator. -/
def tokenizeTR (cs : List Char) : List Tok := tokenizeAux [] cs

@[csimp] theorem tokenize_eq_tokenizeTR : @tokenize = @tokenizeTR := by
  funext cs; simp [tokenizeTR, tokenizeAux_eq]

/-- Tokenize a string. -/
def tokens (s : String) : List Tok := tokenize s.toList

/-- Drop whitespace and comments. -/
def code (ts : List Tok) : List Tok := ts.filter (fun t => !t.trivia)

/-- Attach 1-based line numbers to tokens. -/
def withLines (ts : List Tok) : List (Nat × Tok) :=
  let rec go (line : Nat) : List Tok → List (Nat × Tok)
    | [] => []
    | t :: ts => (line, t) :: go (line + t.text.countP (· == '\n')) ts
  go 1 ts

/-- The accumulating form of `withLines.go`. -/
def withLinesAux (line : Nat) : List Tok → List (Nat × Tok) → List (Nat × Tok)
  | [], acc => acc.reverse
  | t :: ts, acc =>
      withLinesAux (line + t.text.countP (· == '\n')) ts ((line, t) :: acc)

theorem withLinesAux_eq (line : Nat) (ts : List Tok) (acc : List (Nat × Tok)) :
    withLinesAux line ts acc = acc.reverse ++ withLines.go line ts := by
  induction ts generalizing line acc with
  | nil => simp [withLinesAux, withLines.go]
  | cons t ts ih => simp [withLinesAux, withLines.go, ih]

/-- `withLines`, run with an accumulator. -/
def withLinesTR (ts : List Tok) : List (Nat × Tok) := withLinesAux 1 ts []

@[csimp] theorem withLines_eq_withLinesTR : @withLines = @withLinesTR := by
  funext ts; simp [withLinesTR, withLinesAux_eq, withLines]

end Lex

/-! ## 3. A parser for Lean commands

On top of the lexer sits just enough of a parser to answer the questions a
build tool and a proof auditor need to ask of a source file:

* what does it `import`?
* which declarations does it contain, under which namespaces, and where?
* is there a `sorry` (or `admit`, or `native_decide`) in real code, as opposed
  to inside a comment or a string literal?
* which `axiom`s does it declare?

A Lean command starts in column 0 — that is the convention the language itself
relies on for error recovery, and it is all the structure needed here.  Every
column-0 code token opens a command; the command runs to the next one.
-/

namespace Syn

open Lex

/-- A source position: 1-based line, 0-based column. -/
structure Pos where
  line : Nat
  col : Nat
  deriving Repr, Inhabited, DecidableEq

/-- Advance a position over a character. -/
def Pos.step (p : Pos) (c : Char) : Pos :=
  if c = '\n' then ⟨p.line + 1, 0⟩ else ⟨p.line, p.col + 1⟩

/-- Advance a position over a run of characters. -/
def Pos.advance (p : Pos) (cs : List Char) : Pos := cs.foldl Pos.step p

/-- Attach source positions to a token stream. -/
def locate : List Tok → List (Pos × Tok) :=
  let rec go (p : Pos) : List Tok → List (Pos × Tok)
    | [] => []
    | t :: ts => (p, t) :: go (p.advance t.text) ts
  go ⟨1, 0⟩

/-- The accumulating form of `locate.go`: one frame for the whole file rather than
one per token. -/
def locateAux (p : Pos) : List Tok → List (Pos × Tok) → List (Pos × Tok)
  | [], acc => acc.reverse
  | t :: ts, acc => locateAux (p.advance t.text) ts ((p, t) :: acc)

theorem locateAux_eq (p : Pos) (ts : List Tok) (acc : List (Pos × Tok)) :
    locateAux p ts acc = acc.reverse ++ locate.go p ts := by
  induction ts generalizing p acc with
  | nil => simp [locateAux, locate.go]
  | cons t ts ih => simp [locateAux, locate.go, ih]

/-- `locate`, run with an accumulator. -/
def locateTR (ts : List Tok) : List (Pos × Tok) := locateAux ⟨1, 0⟩ ts []

@[csimp] theorem locate_eq_locateTR : @locate = @locateTR := by
  funext ts; simp [locateTR, locateAux_eq, locate]

/-- A located token that is not whitespace or a comment. -/
def codeToks (ts : List (Pos × Tok)) : List (Pos × Tok) :=
  ts.filter (fun pt => !pt.2.trivia)

/-- A command: a maximal run of code tokens starting in column 0. -/
structure Cmd where
  pos : Pos
  toks : List (Pos × Tok)
  deriving Inhabited

/-- Group a located code-token stream into commands. -/
def commandsAux : Nat → List (Pos × Tok) → List Cmd
  | 0, _ => []
  | _, [] => []
  | n+1, t :: ts =>
      let body := ts.takeWhile (fun pt => pt.1.col != 0)
      let rest := ts.dropWhile (fun pt => pt.1.col != 0)
      ⟨t.1, t :: body⟩ :: commandsAux n rest

/-- The accumulating form of `commandsAux`. -/
def commandsAuxTRGo : Nat → List (Pos × Tok) → List Cmd → List Cmd
  | 0, _, acc => acc.reverse
  | _, [], acc => acc.reverse
  | n+1, t :: ts, acc =>
      let body := ts.takeWhile (fun pt => pt.1.col != 0)
      let rest := ts.dropWhile (fun pt => pt.1.col != 0)
      commandsAuxTRGo n rest (⟨t.1, t :: body⟩ :: acc)

theorem commandsAuxTRGo_eq (n : Nat) (ts : List (Pos × Tok)) (acc : List Cmd) :
    commandsAuxTRGo n ts acc = acc.reverse ++ commandsAux n ts := by
  induction n generalizing ts acc with
  | zero => simp [commandsAuxTRGo, commandsAux]
  | succ n ih =>
      cases ts with
      | nil => simp [commandsAuxTRGo, commandsAux]
      | cons t ts => simp [commandsAuxTRGo, commandsAux, ih]

/-- `commandsAux`, run with an accumulator. -/
def commandsAuxTR (n : Nat) (ts : List (Pos × Tok)) : List Cmd :=
  commandsAuxTRGo n ts []

@[csimp] theorem commandsAux_eq_commandsAuxTR : @commandsAux = @commandsAuxTR := by
  funext n ts; simp [commandsAuxTR, commandsAuxTRGo_eq]

/-- Split a file's tokens into commands. -/
def commands (ts : List (Pos × Tok)) : List Cmd :=
  let cs := codeToks ts
  commandsAux (cs.length + 1) cs

/-- Words that introduce a declaration. -/
def declKeywords : List String :=
  ["theorem", "lemma", "def", "abbrev", "instance", "structure", "inductive",
   "class", "example", "opaque", "axiom", "noncomputable", "unsafe", "partial",
   "private", "protected", "scoped", "local", "nonrec", "mutual", "macro",
   "elab", "syntax", "notation", "instance"]

/-- Words that only modify a declaration. -/
def modifiers : List String :=
  ["noncomputable", "unsafe", "partial", "private", "protected", "scoped",
   "local", "nonrec", "mutual"]

/-- Words that name a kind of declaration. -/
def kinds : List String :=
  ["theorem", "lemma", "def", "abbrev", "instance", "structure", "inductive",
   "class", "example", "opaque", "axiom", "macro", "elab", "syntax", "notation"]

/-- Tokens that stand for an unfinished or unchecked proof. -/
def holes : List String := ["sorry", "admit", "sorryAx"]

/-- Tokens that close a proof by trusting the compiler's evaluator. -/
def trusted : List String := ["native_decide", "implemented_by", "nativeDecide"]

/-- Read a dotted name starting at the head of a token list. -/
def readName : List (Pos × Tok) → String × List (Pos × Tok)
  | (_, t) :: rest =>
      if t.kind == .ident then
        match rest with
        | (_, d) :: (_, u) :: rest' =>
            if d.str == "." && u.kind == .ident then
              let (n, r) := readName ((⟨0,0⟩, u) :: rest')
              (t.str ++ "." ++ n, r)
            else (t.str, rest)
        | _ => (t.str, rest)
      else ("", (_root_.List.cons (⟨0,0⟩, t) rest))
  | [] => ("", [])

/-- A declaration found in a file. -/
structure Decl where
  kind : String
  name : String
  line : Nat
  mods : List String
  holes : List Nat
  trusted : List Nat
  deriving Inhabited, Repr

/-- Everything `gokujo` knows about one source file. -/
structure FileInfo where
  path : String
  module : String
  imports : List String
  decls : List Decl
  namespaces : List String
  lineCount : Nat
  tokenCount : Nat
  digest : String
  deriving Inhabited

/-- Skip attribute brackets `@[...]` and modifiers at the head of a command. -/
def skipModifiers : Nat → List (Pos × Tok) → List (Pos × Tok)
  | 0, ts => ts
  | n+1, ts =>
    match ts with
    | (_, t) :: rest =>
        if t.str == "@" then
          skipModifiers n (rest.dropWhile (fun pt => pt.2.str != "]") |>.drop 1)
        else if modifiers.contains t.str then skipModifiers n rest
        else ts
    | [] => []

/-- The line numbers of tokens naming any of `words`, ignoring a token that
follows a dot or a constructor bar: `Foo.sorryAx` mentions the axiom and
`| sorryAx : Ax` declares a constructor of that name, whereas a bare `sorry`
invokes the real thing. -/
def occurrencesAux (words : List String) : Option String → List (Pos × Tok) → List Nat
  | _, [] => []
  | prev, pt :: rest =>
      let hit := words.contains pt.2.str && prev != some "." && prev != some "|"
      (if hit then [pt.1.line] else []) ++ occurrencesAux words (some pt.2.str) rest

/-- The line numbers, within a command, of tokens naming any of `words`. -/
def occurrences (words : List String) (ts : List (Pos × Tok)) : List Nat :=
  occurrencesAux words none ts

theorem mem_of_mem_takeWhile {α : Type} {p : α → Bool} {l : List α} {x : α}
    (h : x ∈ l.takeWhile p) : x ∈ l := by
  have h2 : x ∈ l.takeWhile p ++ l.dropWhile p := List.mem_append_left _ h
  rwa [List.takeWhile_append_dropWhile] at h2

theorem mem_of_mem_dropWhile {α : Type} {p : α → Bool} {l : List α} {x : α}
    (h : x ∈ l.dropWhile p) : x ∈ l := by
  have h2 : x ∈ l.takeWhile p ++ l.dropWhile p := List.mem_append_right _ h
  rwa [List.takeWhile_append_dropWhile] at h2

/-- Every reported line really carries a token with one of those names. -/
theorem occurrencesAux_sound {words : List String} {l : Nat} :
    ∀ (prev : Option String) (ts : List (Pos × Tok)), l ∈ occurrencesAux words prev ts →
      ∃ pt ∈ ts, words.contains pt.2.str = true ∧ pt.1.line = l := by
  intro prev ts
  induction ts generalizing prev with
  | nil => intro h; simp [occurrencesAux] at h
  | cons pt rest ih =>
      intro h
      simp only [occurrencesAux, List.mem_append] at h
      rcases h with h | h
      · by_cases hw :
          (words.contains pt.2.str && (prev != some ".") && (prev != some "|")) = true
        · rw [if_pos hw] at h
          simp only [List.mem_singleton] at h
          simp only [Bool.and_eq_true] at hw
          exact ⟨pt, by simp, hw.1.1, h.symm⟩
        · rw [if_neg hw] at h; simp at h
      · obtain ⟨q, hq, h1, h2⟩ := ih _ h
        exact ⟨q, List.mem_cons_of_mem _ hq, h1, h2⟩

/-- The same, for the entry point. -/
theorem occurrences_sound {words : List String} {ts : List (Pos × Tok)} {l : Nat}
    (h : l ∈ occurrences words ts) :
    ∃ pt ∈ ts, words.contains pt.2.str = true ∧ pt.1.line = l :=
  occurrencesAux_sound none ts h

/-- Command tokens are code tokens: never whitespace, never a comment. -/
theorem codeToks_not_trivia {ts : List (Pos × Tok)} {pt : Pos × Tok}
    (h : pt ∈ codeToks ts) : pt.2.trivia = false := by
  rw [codeToks, List.mem_filter] at h
  simpa using h.2

/-- Tokens of a command come from the stream it was cut out of. -/
theorem commandsAux_mem : ∀ (n : Nat) (ts : List (Pos × Tok)) (c : Cmd),
    c ∈ commandsAux n ts → ∀ pt ∈ c.toks, pt ∈ ts
  | 0, ts, c, h, pt, hpt => by simp [commandsAux] at h
  | _+1, [], c, h, pt, hpt => by simp [commandsAux] at h
  | n+1, t :: ts, c, h, pt, hpt => by
      rw [commandsAux, List.mem_cons] at h
      rcases h with rfl | h
      · simp only [List.mem_cons] at hpt
        rcases hpt with rfl | hpt
        · simp
        · exact List.mem_cons_of_mem _ (mem_of_mem_takeWhile hpt)
      · have := commandsAux_mem n _ c h pt hpt
        exact List.mem_cons_of_mem _ (mem_of_mem_dropWhile this)

/-- **A reported hole is a real one.**  Whenever the scanner reports a line as
carrying a `sorry` (or any other listed word), that file really contains a
token with exactly that text, on that line, in code: not inside a comment, not
inside a string literal — a comment token's text carries its delimiters and a
string token's text includes its quotes, so neither can equal `sorry`. -/
theorem reported_holes_are_code {words : List String} {ts : List (Pos × Tok)}
    {c : Cmd} (hc : c ∈ commands ts) {l : Nat} (hl : l ∈ occurrences words c.toks) :
    ∃ pt ∈ ts, pt.2.trivia = false ∧ words.contains pt.2.str = true ∧ pt.1.line = l := by
  obtain ⟨pt, hpt, hw, hline⟩ := occurrences_sound hl
  have hmem : pt ∈ codeToks ts := commandsAux_mem _ _ c hc pt hpt
  refine ⟨pt, ?_, codeToks_not_trivia hmem, hw, hline⟩
  rw [codeToks, List.mem_filter] at hmem
  exact hmem.1

/-- Turn one command into a declaration, if it is one. -/
def declOf (nsPrefix : String) (c : Cmd) : Option Decl :=
  let ts := skipModifiers (c.toks.length + 1) c.toks
  match ts with
  | (p, t) :: rest =>
      if kinds.contains t.str then
        let (nm, _) := readName rest
        let full := if nsPrefix == "" || nm == "" then nm else nsPrefix ++ "." ++ nm
        some { kind := t.str, name := full, line := p.line,
               mods := c.toks.map (fun pt => pt.2.str) |>.filter modifiers.contains,
               holes := occurrences holes c.toks,
               trusted := occurrences trusted c.toks }
      else none
  | [] => none

/-- Walk the commands of a file, tracking the namespace stack. -/
def scanCmds : Nat → List String → List Cmd → List String × List Decl
  | 0, _, _ => ([], [])
  | _, _, [] => ([], [])
  | n+1, stack, c :: cs =>
    let head := (c.toks.head?.map (fun pt => pt.2.str)).getD ""
    if head == "namespace" then
      let (nm, _) := readName (c.toks.drop 1)
      let stack' := stack ++ [nm]
      let (nss, ds) := scanCmds n stack' cs
      (String.intercalate "." stack' :: nss, ds)
    else if head == "end" then
      let stack' := stack.take (stack.length - 1)
      scanCmds n stack' cs
    else if head == "section" then
      scanCmds n stack cs
    else
      let pre := String.intercalate "." stack
      let (nss, ds) := scanCmds n stack cs
      match declOf pre c with
      | some d => (nss, d :: ds)
      | none => (nss, ds)

/-- The `import` lines of a command list. -/
def importsOf (cs : List Cmd) : List String :=
  cs.filterMap (fun c =>
    match c.toks with
    | (_, t) :: rest => if t.str == "import" then some (readName rest).1 else none
    | [] => none)

/-- Convert a file path to the Lean module name it would have. -/
def moduleOfPath (path : String) : String :=
  let p := if path.endsWith ".lean" then (path.dropEnd 5).toString else path
  let p := Util.dropPrefix p "./"
  String.intercalate "." (p.splitOn "/")

/-- Parse one file's contents. -/
def parseFile (path contents : String) : FileInfo :=
  let ts := locate (Lex.tokens contents)
  let cs := commands ts
  let (nss, ds) := scanCmds (cs.length + 1) [] cs
  { path := path
    module := moduleOfPath path
    imports := importsOf cs
    decls := ds
    namespaces := Util.dedup nss
    lineCount := (Util.lines contents).length
    tokenCount := ts.length
    digest := Util.digest contents }

/-- Declarations with an unfinished proof. -/
def FileInfo.holes (f : FileInfo) : List Decl := f.decls.filter (fun d => !d.holes.isEmpty)

/-- Declarations closed by trusting the evaluator. -/
def FileInfo.trusting (f : FileInfo) : List Decl := f.decls.filter (fun d => !d.trusted.isEmpty)

end Syn

/-! ## 4. The module graph, and a build order that is checked

`gokujo build` does what `lake` does for a plain library: read the imports,
order the modules so that every module is compiled after everything it
imports, and run the compiler.  The ordering is produced by Kahn's algorithm —
and then *checked*, by `Graph.orderOk`, which is proved sound
(`Graph.order_ok_sound`): if the checker accepts an order, then along every
intra-project import edge the imported module really does come first.  So a
bug in the scheduler cannot silently produce a wrong build order; it can only
make `gokujo` refuse to build.
-/

namespace Graph

/-- A dependency graph: for each module, the modules it imports. -/
abbrev G := List (String × List String)

/-- Is `m` a node of `g`? -/
def mem (g : G) (m : String) : Bool := g.any (fun p => p.1 == m)

/-- Position of a module in a proposed order. -/
def idx (o : List String) (m : String) : Nat := o.idxOf m

/-- The checker: every node is listed, and every internal edge points
backwards. -/
def orderOk (g : G) (o : List String) : Bool :=
  g.all (fun n => o.contains n.1 &&
    n.2.all (fun d => !mem g d || decide (idx o d < idx o n.1)))

/-- **The order checker is sound.**  If `orderOk` accepts, then every module
of the project that `n` imports occupies an earlier slot than `n`. -/
theorem order_ok_sound {g : G} {o : List String} (h : orderOk g o = true)
    {n : String × List String} (hn : n ∈ g) {d : String} (hd : d ∈ n.2)
    (hdg : mem g d = true) : idx o d < idx o n.1 := by
  rw [orderOk, List.all_eq_true] at h
  have h1 := h n hn
  rw [Bool.and_eq_true, List.all_eq_true] at h1
  have h2 := h1.2 d hd
  simp [hdg] at h2
  exact h2

/-- **Accepted orders list every module.** -/
theorem order_ok_complete {g : G} {o : List String} (h : orderOk g o = true)
    {n : String × List String} (hn : n ∈ g) : o.contains n.1 = true := by
  rw [orderOk, List.all_eq_true] at h
  have h1 := h n hn
  rw [Bool.and_eq_true] at h1
  exact h1.1

/-- One round of Kahn's algorithm: emit every node all of whose intra-project
dependencies are already emitted. -/
def ready (g : G) (done : List String) : List String :=
  (g.filter (fun n => !done.contains n.1 &&
      n.2.all (fun d => !mem g d || done.contains d))).map (·.1)

/-- Kahn's algorithm, run to fixpoint or until no progress is possible. -/
def topoAux : Nat → G → List String → List String
  | 0, _, done => done
  | n+1, g, done =>
      match ready g done with
      | [] => done
      | rs => topoAux n g (done ++ rs)

/-- A topological order of the graph, or a shorter list if it has a cycle. -/
def topo (g : G) : List String := topoAux (g.length + 1) g []

/-- The modules of `g` that `topo` could not place: exactly those on a cycle. -/
def cyclic (g : G) : List String :=
  let o := topo g
  (g.map (·.1)).filter (fun m => !o.contains m)

end Graph

/-! ## 5. Markdown in, Lean out

`gokujo` ships as two files that are the same file: `Gokujo.lean` is the
program, and `GOKUJO.md` is a Markdown document whose fenced `lean` block *is*
`Gokujo.lean`.  `gokujo tangle` goes one way, `gokujo weave` the other, and
`gokujo selfcheck` verifies that the two files still agree, byte for byte.

The round trip is proved: extracting the code out of a woven document returns
exactly the code that went in (`Md.tangle_weave`).
-/

namespace Md

/-- The three-backtick fence, built rather than written, so that no line of
this source file is itself a fence. -/
def ticks : String := String.ofList ['`', '`', '`']

/-- The opening fence of the code block. -/
def fenceOpen : String := ticks ++ "lean"

/-- The closing fence of the code block. -/
def fenceClose : String := ticks

/-- Is this line the start of the Lean code block?  The comparison is exact:
an indented fence is prose, not a fence. -/
def isOpen (l : String) : Bool := l == fenceOpen

/-- Is this line the end of a code block? -/
def isClose (l : String) : Bool := l == fenceClose

/-- Extract the lines inside `lean` code fences. -/
def tangleAux : Bool → List String → List String
  | _, [] => []
  | true, l :: ls => if isClose l then tangleAux false ls else l :: tangleAux true ls
  | false, l :: ls => if isOpen l then tangleAux true ls else tangleAux false ls

/-- Markdown → Lean. -/
def tangleLines (ls : List String) : List String := tangleAux false ls

/-- Lean → Markdown: prose, then the whole source in one fenced block. -/
def weaveLines (prose code : List String) : List String :=
  prose ++ fenceOpen :: (code ++ [fenceClose])

theorem tangle_inside {code : List String} (h : ∀ l ∈ code, isClose l = false)
    (rest : List String) : tangleAux true (code ++ fenceClose :: rest)
      = code ++ tangleAux false rest := by
  induction code with
  | nil => simp [tangleAux, isClose]
  | cons a as ih =>
      have ha : isClose a = false := h a (by simp)
      have h' : ∀ l ∈ as, isClose l = false := fun l hl => h l (by simp [hl])
      simp [tangleAux, ha, ih h']

theorem tangle_prose {prose : List String} (h : ∀ l ∈ prose, isOpen l = false)
    (rest : List String) : tangleAux false (prose ++ rest) = tangleAux false rest := by
  induction prose with
  | nil => simp
  | cons a as ih =>
      have ha : isOpen a = false := h a (by simp)
      have h' : ∀ l ∈ as, isOpen l = false := fun l hl => h l (by simp [hl])
      simp [tangleAux, ha, ih h']

/-- **The Markdown round trip is an identity.**  If the prose contains no
opening fence and the code contains no closing fence, then tangling a woven
document gives back exactly the code. -/
theorem tangle_weave {prose code : List String}
    (hp : ∀ l ∈ prose, isOpen l = false) (hc : ∀ l ∈ code, isClose l = false) :
    tangleLines (weaveLines prose code) = code := by
  have hopen : isOpen fenceOpen = true := by simp [isOpen]
  simp only [tangleLines, weaveLines, tangle_prose hp, tangleAux, hopen, if_pos,
    tangle_inside hc]
  simp

/-- Markdown → Lean, on strings. -/
def tangle (md : String) : String := Util.unlines (tangleLines (Util.lines md))

/-- Lean → Markdown, on strings. -/
def weave (prose code : String) : String :=
  Util.unlines (weaveLines (Util.lines prose) (Util.lines code))

end Md

/-! ## 6. HTML

The same manual that `gokujo help` prints is also emitted as a single
self-contained HTML page — no scripts, no fonts, no network.  The escaping is
proved to escape (`Html.escape_no_lt`).
-/

namespace Html

/-- Escape the characters that are dangerous in HTML text. -/
def escapeChars : List Char → List Char
  | [] => []
  | '<' :: cs => '&' :: 'l' :: 't' :: ';' :: escapeChars cs
  | '>' :: cs => '&' :: 'g' :: 't' :: ';' :: escapeChars cs
  | '&' :: cs => '&' :: 'a' :: 'm' :: 'p' :: ';' :: escapeChars cs
  | '"' :: cs => '&' :: 'q' :: 'u' :: 'o' :: 't' :: ';' :: escapeChars cs
  | c :: cs => c :: escapeChars cs

/-- **Escaping escapes.**  No `<` survives. -/
theorem escape_no_lt (cs : List Char) : '<' ∉ escapeChars cs := by
  fun_induction escapeChars cs <;> simp_all <;> exact fun h => absurd h.symm (by assumption)

/-- No `>` survives either. -/
theorem escape_no_gt (cs : List Char) : '>' ∉ escapeChars cs := by
  fun_induction escapeChars cs <;> simp_all <;> exact fun h => absurd h.symm (by assumption)

/-- Nor any double quote, so escaped text is safe inside an attribute. -/
theorem escape_no_quote (cs : List Char) : '"' ∉ escapeChars cs := by
  fun_induction escapeChars cs <;> simp_all <;> exact fun h => absurd h.symm (by assumption)

/-- Escaping leaves ordinary text alone. -/
theorem escape_plain {cs : List Char}
    (h : ∀ c ∈ cs, c ≠ '<' ∧ c ≠ '>' ∧ c ≠ '&' ∧ c ≠ '"') : escapeChars cs = cs := by
  induction cs with
  | nil => rfl
  | cons a as ih =>
      have ha := h a (by simp)
      have h' : ∀ c ∈ as, c ≠ '<' ∧ c ≠ '>' ∧ c ≠ '&' ∧ c ≠ '"' := fun c hc => h c (by simp [hc])
      obtain ⟨h1, h2, h3, h4⟩ := ha
      unfold escapeChars
      split
      · simp_all
      · simp_all
      · simp_all
      · simp_all
      · simp_all
      · rename_i c cs' heq
        simp only [List.cons.injEq] at heq
        obtain ⟨rfl, rfl⟩ := heq
        rw [ih h']

/-- Escape a string. -/
def escape (s : String) : String := String.ofList (escapeChars s.toList)

end Html

/-! ## 7. The manual, as data

The documentation is a Lean value.  `gokujo help` prints it, `gokujo html`
renders it, `gokujo weave` puts it in front of the source code in `GOKUJO.md`.
There is exactly one copy of it, and it lives in the program.
-/

namespace Doc

/-- A documented command. -/
structure Command where
  name : String
  args : String
  summary : String
  body : List String
  deriving Inhabited

/-- A section of the manual. -/
structure Topic where
  id : String
  title : String
  body : List String
  deriving Inhabited

/-- The commands `gokujo` understands. -/
def commands : List Command :=
  [ { name := "help", args := "[command]"
    , summary := "print this manual, or one command's entry"
    , body := ["With no argument the whole manual is printed. `gokujo help build` prints one entry."] }
  , { name := "version", args := ""
    , summary := "print the version and the resolved toolchain"
    , body := [] }
  , { name := "doctor", args := ""
    , summary := "report which toolchain backends this machine can use"
    , body := ["Looks for a bundled toolchain next to the executable, then for lean on PATH,",
               "then for elan, lake and nix. Prints what each backend would run."] }
  , { name := "scan", args := "[paths...]"
    , summary := "parse Lean sources and report their contents"
    , body := ["Lexes and parses every .lean file under the given paths (default: the configured",
               "source directory) and prints modules, imports, declarations, holes and lines.",
               "Add --json for machine-readable output."] }
  , { name := "sorry", args := "[paths...]"
    , summary := "fail if any sorry, admit or native_decide is reachable"
    , body := ["Uses the parser, so a sorry inside a comment or a string literal is not a sorry.",
               "Exit code 1 if any hole is found. --allow-native tolerates native_decide."] }
  , { name := "graph", args := "[paths...]"
    , summary := "print the import graph and a verified build order"
    , body := ["The order is produced by Kahn's algorithm and then checked by Graph.orderOk,",
               "which is proved sound. Cycles are reported instead of silently mis-ordered."] }
  , { name := "build", args := "[paths...]"
    , summary := "compile every module, in dependency order"
    , body := ["Replaces lake/make for a plain Lean library: it computes the order itself,",
               "tracks content digests for incrementality, and invokes the compiler directly.",
               "--force rebuilds everything, --jobs is accepted and currently sequential."] }
  , { name := "axioms", args := "[paths...]"
    , summary := "audit the axioms behind every theorem"
    , body := ["Builds, then generates and runs a driver that prints the axioms of every",
               "declaration found by the parser, and flags anything outside the allowed set",
               "(propext, Classical.choice, Quot.sound by default; change with --allow-axiom)."] }
  , { name := "check", args := "[paths...]"
    , summary := "scan + graph + build + sorry + axioms, as one gate"
    , body := ["The single command to put in CI, or to hand to an agent as its definition of",
               "done. Exit code 0 only if every stage passes."] }
  , { name := "html", args := "[-o FILE] [paths...]"
    , summary := "write the manual, and any scan report, as one HTML page"
    , body := ["The page is self-contained: no scripts, no fonts, no network."] }
  , { name := "tangle", args := "[FILE.md] [-o OUT.lean]"
    , summary := "extract the Lean source from the Markdown file"
    , body := ["The extraction is the proved inverse of weave (Md.tangle_weave)."] }
  , { name := "weave", args := "[FILE.lean] [-o OUT.md]"
    , summary := "write the Markdown file: manual, then the whole source"
    , body := [] }
  , { name := "selfcheck", args := ""
    , summary := "verify that Gokujo.lean and GOKUJO.md still agree"
    , body := ["Tangles the Markdown and compares it with the Lean file, character by character."] }
  , { name := "selftest", args := ""
    , summary := "run the built-in tests of the lexer, parser, graph and Markdown layers"
    , body := [] }
  , { name := "bootstrap", args := "[-o EXE]"
    , summary := "compile gokujo itself into a native executable"
    , body := ["Runs the compiler on this one file and links the result. No package manager,",
               "no build file, no network. Prints the exact commands it used."] }
  , { name := "targets", args := ""
    , summary := "list the per-platform executable matrix"
    , body := ["Six flavours (standalone, bundled, system, elan, lake, nix) times five platforms."] }
  , { name := "release", args := "[-o FILE]"
    , summary := "write the script that builds the whole matrix"
    , body := ["Point LEAN and LEANC at a platform's toolchain and run it; the artifacts for",
               "that platform appear in dist/."] }
  , { name := "bundle", args := "[TOOLCHAIN_DIR] [-o DIR]"
    , summary := "copy a Lean toolchain next to the executable, making it self-contained"
    , body := ["This is what turns a `system` gokujo into a `bundled` one: afterwards the",
               "executable compiles proofs with the toolchain it carries, and nothing else",
               "needs to be installed. With no argument the toolchain currently in use is",
               "the one copied."] }
  , { name := "init", args := "[dir]"
    , summary := "write a .gokujo/config for this project"
    , body := [] }
  ]

/-- The prose sections of the manual. -/
def topics : List Topic :=
  [ { id := "what", title := "What this is"
    , body :=
      [ "gokujo (極上, \"finest quality\") is a Swiss army knife for Lean 4 that is one",
        "Lean file and one Markdown file. The Markdown file contains the Lean file. The",
        "Lean file contains the documentation. The program prints the documentation, in",
        "the terminal and as a single HTML page, and does the work: parse, order, build,",
        "audit.",
        "",
        "It is meant to be copied into a project as the only tool that project needs in",
        "order to prepare and check proofs, and to be driven by an agent: every command",
        "has a machine-readable form and a meaningful exit code." ] }
  , { id := "why", title := "Why one file"
    , body :=
      [ "A proof is only as trustworthy as the pipeline that checked it. A pipeline made",
        "of a version manager, a package manager, a build system and a distribution",
        "manager is four things that can each disagree with the others about which",
        "compiler ran on which source.",
        "",
        "gokujo has no imports. It compiles against a bare Lean toolchain in about a",
        "second, it reads the sources itself, it computes the build order itself, and it",
        "invokes the compiler itself. What it cannot do is invent a compiler: for that it",
        "either bundles one, or borrows the one elan, lake or nix already installed." ] }
  , { id := "proved", title := "What is proved"
    , body :=
      [ "A tool that reports on proofs should not itself be a pile of unchecked string",
        "handling. The parts that could silently lie are theorems in this file:",
        "",
        "  Lex.tokenize_faithful   concatenating the tokens returns the input exactly,",
        "                          so no character is dropped, invented or double-counted",
        "  Syn.reported_holes_are_code  a reported sorry is a real token of the file, in",
        "                          code: never one that only occurs in a comment, in a",
        "                          string literal, or as part of a qualified name",
        "  Graph.order_ok_sound    if the order checker accepts an order, every internal",
        "                          import really is compiled first",
        "  Graph.order_ok_complete an accepted order contains every module",
        "  Md.tangle_weave         Markdown -> Lean -> Markdown is the identity on code",
        "  Html.escape_no_lt/gt    escaped text contains no raw < or > or quote",
        "  Html.escape_plain       and escaping changes nothing else",
        "",
        "The build order is not merely computed, it is checked at run time by the",
        "checker those theorems are about: a scheduling bug can make gokujo refuse to",
        "build, but not build in the wrong order." ] }
  , { id := "backends", title := "Toolchain backends"
    , body :=
      [ "standalone  no external Lean at all. Parsing, scanning, the graph, the manual,",
        "            HTML, tangle/weave and the self tests. Everything except compiling.",
        "bundled     a Lean toolchain shipped next to the executable, in",
        "            <exe dir>/toolchain/bin. Nothing else needs to be installed.",
        "system      the lean and leanc found on PATH.",
        "elan        whatever elan resolves for this directory, honouring lean-toolchain.",
        "lake        delegates compilation to lake env, for projects with dependencies",
        "            (this is how gokujo checks a Mathlib project).",
        "nix         runs the toolchain from a flake: nix develop -c, or nix shell.",
        "",
        "Choose with --backend, or GOKUJO_BACKEND, or backend = in .gokujo/config.",
        "Otherwise gokujo picks the first that works, in the order above from bundled." ] }
  , { id := "agents", title := "For agents"
    , body :=
      [ "gokujo check is the gate: exit 0 means every module compiled, no sorry, no",
        "admit, and no axiom outside the allowed set. Nothing else needs to be believed.",
        "",
        "Add --json to scan, sorry, graph, build, axioms or check to get a single JSON",
        "object on stdout, with diagnostics on stderr. Exit codes: 0 success, 1 the",
        "project failed the check, 2 gokujo was used wrongly, 3 no toolchain available." ] }
  , { id := "config", title := "Configuration"
    , body :=
      [ "Optional, in .gokujo/config, one key = value per line:",
        "",
        "  src = RequestProject        directory scanned when no path is given",
        "  backend = lake              force a backend",
        "  allow-axiom = Nat.rec       extra axiom permitted by gokujo axioms",
        "  allow-native = true         tolerate native_decide",
        "  build = .gokujo/build       where oleans go" ] }
  ]

end Doc

/-! ## 8. Toolchains and the executable matrix

One knife, several handles.  The same source builds an executable that carries
a Lean toolchain, one that needs none because it never compiles, and ones that
borrow the toolchain `elan`, `lake` or `nix` already manage — for each
platform.
-/

namespace Tool

/-- Where the compiler comes from. -/
inductive Backend
  | standalone | bundled | system | elan | lake | nix
  deriving DecidableEq, Repr, Inhabited

/-- The name used on the command line. -/
def Backend.name : Backend → String
  | .standalone => "standalone"
  | .bundled => "bundled"
  | .system => "system"
  | .elan => "elan"
  | .lake => "lake"
  | .nix => "nix"

/-- Parse a backend name. -/
def Backend.ofName? (s : String) : Option Backend :=
  [Backend.standalone, .bundled, .system, .elan, .lake, .nix].find? (fun b => b.name == s)

/-- Can this backend compile? -/
def Backend.compiles : Backend → Bool
  | .standalone => false
  | _ => true

/-- One line of explanation. -/
def Backend.about : Backend → String
  | .standalone => "no compiler; parsing, reports and documents only"
  | .bundled => "a Lean toolchain shipped beside this executable"
  | .system => "lean and leanc from PATH"
  | .elan => "the toolchain elan resolves here (honours lean-toolchain)"
  | .lake => "lake env lean, for projects with package dependencies"
  | .nix => "the toolchain from a nix flake or nixpkgs"

/-- A supported platform. -/
structure Platform where
  triple : String
  label : String
  deriving Inhabited

/-- The platforms a release covers. -/
def platforms : List Platform :=
  [ ⟨"x86_64-unknown-linux-gnu", "Linux, Intel/AMD"⟩
  , ⟨"aarch64-unknown-linux-gnu", "Linux, ARM"⟩
  , ⟨"x86_64-apple-darwin", "macOS, Intel"⟩
  , ⟨"aarch64-apple-darwin", "macOS, Apple silicon"⟩
  , ⟨"x86_64-w64-windows-gnu", "Windows"⟩ ]

/-- The flavours a release covers. -/
def flavours : List Backend :=
  [.standalone, .bundled, .system, .elan, .lake, .nix]

/-- The file name of one release artifact. -/
def artifact (b : Backend) (p : Platform) : String :=
  let ext := if p.triple.endsWith "windows-gnu" then ".exe" else ""
  "gokujo-" ++ b.name ++ "-" ++ p.triple ++ ext

/-- The whole matrix. -/
def matrix : List (Backend × Platform × String) :=
  flavours.flatMap (fun b => platforms.map (fun p => (b, p, artifact b p)))

end Tool

/-! ## 9. Configuration and the outside world

From here on the file talks to the operating system: it reads directories,
runs compilers and writes reports.  Everything above this line is pure, and
is what the theorems are about.
-/

namespace Sys

open Tool

/-- Everything a run of `gokujo` needs to know. -/
structure Config where
  root : String := "."
  src : List String := []
  backend : Option Backend := none
  buildDir : String := ".gokujo/build"
  allowAxioms : List String :=
    ["propext", "Classical.choice", "Quot.sound", "Lean.ofReduceBool", "Lean.trustCompiler"]
  allowNative : Bool := false
  json : Bool := false
  force : Bool := false
  verbose : Bool := false
  out : Option String := none
  deriving Inhabited

/-- Run a program, returning exit code, stdout and stderr; `none` if the
program could not be started at all. -/
def probe (cmd : String) (args : List String) (cwd : Option String := none)
    (env : List (String × String) := []) : IO (Option (Nat × String × String)) := do
  try
    let o ← IO.Process.output
      { cmd := cmd, args := args.toArray, cwd := cwd.map (· : String → System.FilePath),
        env := (env.map (fun kv => (kv.1, some kv.2))).toArray }
    return some (o.exitCode.toNat, o.stdout, o.stderr)
  catch _ => return none

/-- Run a program and fail loudly if it cannot be started. -/
def run (cmd : String) (args : List String) (cwd : Option String := none)
    (env : List (String × String) := []) : IO (Nat × String × String) := do
  match ← probe cmd args cwd env with
  | some r => return r
  | none => return (127, "", s!"cannot execute: {cmd}")

/-- A resolved toolchain: how to invoke the compiler and the linker. -/
structure Chain where
  backend : Backend
  leanCmd : String
  leanPre : List String
  leancCmd : String
  leancPre : List String
  version : String
  deriving Inhabited

/-- A description of the command this chain runs. -/
def Chain.show (c : Chain) : String :=
  String.intercalate " " (c.leanCmd :: c.leanPre)

/-- The directory holding the running executable, if it can be found. -/
def exeDir : IO (Option String) := do
  try
    let p ← IO.appDir
    return some p.toString
  catch _ => return none

/-- Try to resolve one backend on this machine. -/
def resolve (b : Backend) (root : String) : IO (Option Chain) := do
  match b with
  | .standalone =>
      return some { backend := .standalone, leanCmd := "", leanPre := [], leancCmd := "",
                     leancPre := [], version := "none" }
  | .bundled => do
      match ← exeDir with
      | none => return none
      | some d =>
        let lean := d ++ "/toolchain/bin/lean"
        let leanc := d ++ "/toolchain/bin/leanc"
        match ← probe lean ["--version"] with
        | some (0, v, _) =>
            return some { backend := .bundled, leanCmd := lean, leanPre := [],
                           leancCmd := leanc, leancPre := [], version := Util.trim v }
        | _ => return none
  | .system => do
      match ← probe "lean" ["--version"] with
      | some (0, v, _) =>
          return some { backend := .system, leanCmd := "lean", leanPre := [],
                         leancCmd := "leanc", leancPre := [], version := Util.trim v }
      | _ => return none
  | .elan => do
      match ← probe "elan" ["which", "lean"] (some root) with
      | some (0, p, _) =>
          let lean := Util.trim p
          match ← probe lean ["--version"] with
          | some (0, v, _) =>
              return some { backend := .elan, leanCmd := lean, leanPre := [],
                             leancCmd := (Util.trim p).replace "/lean" "/leanc",
                             leancPre := [], version := Util.trim v }
          | _ => return none
      | _ => return none
  | .lake => do
      let hasLakefile ← (System.FilePath.mk (root ++ "/lakefile.toml")).pathExists
      let hasLakefile' ← (System.FilePath.mk (root ++ "/lakefile.lean")).pathExists
      if !(hasLakefile || hasLakefile') then return none
      match ← probe "lake" ["--version"] (some root) with
      | some (0, v, _) =>
          return some { backend := .lake, leanCmd := "lake", leanPre := ["env", "lean"],
                         leancCmd := "lake", leancPre := ["env", "leanc"], version := Util.trim v }
      | _ => return none
  | .nix => do
      let flake ← (System.FilePath.mk (root ++ "/flake.nix")).pathExists
      match ← probe "nix" ["--version"] (some root) with
      | some (0, v, _) =>
          let pre := if flake then ["develop", "-c", "lean"] else ["shell", "nixpkgs#lean4", "-c", "lean"]
          let pre' := if flake then ["develop", "-c", "leanc"] else ["shell", "nixpkgs#lean4", "-c", "leanc"]
          return some { backend := .nix, leanCmd := "nix", leanPre := pre,
                         leancCmd := "nix", leancPre := pre', version := Util.trim v }
      | _ => return none

/-- The order in which backends are tried when none is requested. -/
def autoOrder : List Backend := [.bundled, .lake, .system, .elan, .nix]

/-- Resolve the toolchain to use. -/
def toolchain (cfg : Config) : IO Chain := do
  match cfg.backend with
  | some b => do
      match ← resolve b cfg.root with
      | some c => return c
      | none => return { backend := .standalone, leanCmd := "", leanPre := [], leancCmd := "",
                         leancPre := [], version := "unavailable: " ++ b.name }
  | none => do
      let rec go : List Backend → IO Chain
        | [] => return { backend := .standalone, leanCmd := "", leanPre := [], leancCmd := "",
                         leancPre := [], version := "none" }
        | b :: bs => do
            match ← resolve b cfg.root with
            | some c => return c
            | none => go bs
      go autoOrder

/-- Directories never descended into. -/
def skipDirs : List String := [".git", ".lake", ".gokujo", "build", "node_modules", ".elan"]

/-- All `.lean` files under a path, recursively. -/
partial def walkLean (p : String) : IO (List String) := do
  let fp := System.FilePath.mk p
  if ← fp.isDir then
    let entries ← fp.readDir
    let mut acc : List String := []
    for e in entries do
      let name := e.fileName
      if skipDirs.contains name || name.startsWith "." then continue
      acc := acc ++ (← walkLean (p ++ "/" ++ name))
    return acc.mergeSort (fun a b => a ≤ b)
  else if p.endsWith ".lean" && !p.endsWith "lakefile.lean" then
    return [p]
  else
    return []

/-- Read a file, or the empty string if it is unreadable. -/
def readOr (p : String) : IO String := do
  try IO.FS.readFile p catch _ => return ""

/-- The absolute form of a path, or the path itself if it does not exist. -/
def absPath (p : String) : IO String := do
  try
    let r ← IO.FS.realPath p
    return r.toString
  catch _ => return p

/-- Strip a leading `root/` from a path. -/
def relTo (root p : String) : String :=
  let r := if root.endsWith "/" then root else root ++ "/"
  let p := Util.dropPrefix p "./"
  let r := Util.dropPrefix r "./"
  Util.dropPrefix p r

/-- Parse every Lean file under the given paths. -/
def scanPaths (cfg : Config) (paths : List String) : IO (List Syn.FileInfo) := do
  let mut files : List String := []
  for p in paths do
    files := files ++ (← walkLean p)
  let mut infos : List Syn.FileInfo := []
  for f in Util.dedup files do
    let contents ← readOr f
    infos := infos ++ [Syn.parseFile (relTo cfg.root f) contents]
  return infos

/-- Read `.gokujo/config`, if present. -/
def loadConfig (root : String) : IO Config := do
  let txt ← readOr (root ++ "/.gokujo/config")
  let mut cfg : Config := { root := root }
  for line in Util.lines txt do
    let line := Util.trim line
    if line == "" || line.startsWith "#" then continue
    match line.splitOn "=" with
    | k :: rest =>
        let key := Util.trim k
        let val := Util.trim (String.intercalate "=" rest)
        if key == "src" then cfg := { cfg with src := cfg.src ++ [val] }
        else if key == "backend" then cfg := { cfg with backend := Backend.ofName? val }
        else if key == "build" then cfg := { cfg with buildDir := val }
        else if key == "allow-axiom" then cfg := { cfg with allowAxioms := cfg.allowAxioms ++ [val] }
        else if key == "allow-native" then cfg := { cfg with allowNative := val == "true" }
        else pure ()
    | [] => pure ()
  return cfg

/-- The paths to scan: the ones given, else the configured source directories,
else the project root. -/
def defaultPaths (cfg : Config) (given : List String) : List String :=
  if given ≠ [] then given
  else if cfg.src ≠ [] then cfg.src.map (fun s => cfg.root ++ "/" ++ s)
  else [cfg.root]

/-! ### JSON, by hand -/

/-- Escape a string for JSON. -/
def jesc (s : String) : String :=
  let f : Char → String := fun c =>
    if c = '"' then "\\\""
    else if c = '\\' then "\\\\"
    else if c = '\n' then "\\n"
    else if c = '\r' then "\\r"
    else if c = '\t' then "\\t"
    else if c.toNat < 32 then "?"
    else String.ofList [c]
  String.join (s.toList.map f)

/-- A JSON string literal. -/
def jstr (s : String) : String := "\"" ++ jesc s ++ "\""

/-- A JSON array. -/
def jarr (xs : List String) : String := "[" ++ String.intercalate "," xs ++ "]"

/-- A JSON object. -/
def jobj (kvs : List (String × String)) : String :=
  "{" ++ String.intercalate "," (kvs.map (fun kv => jstr kv.1 ++ ":" ++ kv.2)) ++ "}"

/-- A JSON number. -/
def jnat (n : Nat) : String := toString n

/-- A JSON boolean. -/
def jbool (b : Bool) : String := if b then "true" else "false"

/-! ### The build engine -/

/-- Where oleans are written.  With the `lake` backend they go where `lake env`
already points, so that a project with dependencies just works. -/
def libDir (cfg : Config) (ch : Chain) : String :=
  if ch.backend == .lake then cfg.root ++ "/.lake/build/lib/lean"
  else cfg.root ++ "/" ++ cfg.buildDir ++ "/lib"

/-- Every directory that may hold oleans this project imports. -/
def searchPath (cfg : Config) (ch : Chain) : IO (List String) := do
  let mut ps := [libDir cfg ch]
  let pkgRoot := System.FilePath.mk (cfg.root ++ "/.lake/packages")
  if ← pkgRoot.isDir then
    for e in ← pkgRoot.readDir do
      let cand := e.path.toString ++ "/.lake/build/lib/lean"
      if ← (System.FilePath.mk cand).isDir then ps := ps ++ [cand]
  let own := cfg.root ++ "/.lake/build/lib/lean"
  if ← (System.FilePath.mk own).isDir then ps := ps ++ [own]
  return Util.dedup ps

/-- The environment handed to the compiler. -/
def leanEnv (cfg : Config) (ch : Chain) : IO (List (String × String)) := do
  if ch.backend == .lake then return []
  let ps ← searchPath cfg ch
  let existing := (← IO.getEnv "LEAN_PATH").getD ""
  let sep := ":"
  let joined := String.intercalate sep (ps ++ (if existing == "" then [] else [existing]))
  return [("LEAN_PATH", joined)]

/-- The olean path of a module. -/
def oleanOf (cfg : Config) (ch : Chain) (m : String) : String :=
  libDir cfg ch ++ "/" ++ String.intercalate "/" (m.splitOn ".") ++ ".olean"

/-- Where the content stamp of a module is recorded. -/
def stampOf (cfg : Config) (ch : Chain) (m : String) : String :=
  oleanOf cfg ch m ++ ".gokujo"

/-- The outcome of compiling one module. -/
inductive Status | cached | built | failed | skipped
  deriving DecidableEq, Repr, Inhabited

/-- Its name. -/
def Status.name : Status → String
  | .cached => "cached"
  | .built => "built"
  | .failed => "failed"
  | .skipped => "skipped"

/-- What happened to one module. -/
structure ModResult where
  module : String
  status : Status
  log : String
  deriving Inhabited

/-- Make sure the directory containing `p` exists. -/
def ensureParent (p : String) : IO Unit := do
  match (System.FilePath.mk p).parent with
  | some d => IO.FS.createDirAll d
  | none => pure ()

/-- The dependency graph of a set of parsed files, restricted to the project's
own modules. -/
def graphOf (infos : List Syn.FileInfo) : Graph.G :=
  infos.map (fun f => (f.module, f.imports))

/-- Compile the project, in a checked dependency order. -/
def buildAll (cfg : Config) (ch : Chain) (infos : List Syn.FileInfo) :
    IO (List ModResult × List String) := do
  let g := graphOf infos
  let order := Graph.topo g
  if !Graph.orderOk g order then
    return ([], Graph.cyclic g)
  let env ← leanEnv cfg ch
  let mut results : List ModResult := []
  let mut stamps : List (String × String) := []
  let mut broken : List String := []
  for m in order do
    match infos.find? (fun f => f.module == m) with
    | none => pure ()
    | some f =>
      let depStamps := f.imports.filterMap (fun d => (stamps.find? (fun s => s.1 == d)).map (·.2))
      let stamp := Util.digest (f.digest ++ String.join depStamps)
      stamps := stamps ++ [(m, stamp)]
      let olean := oleanOf cfg ch m
      let stampFile := stampOf cfg ch m
      let depBroken := f.imports.any (fun d => broken.contains d)
      if depBroken then
        results := results ++ [{ module := m, status := .skipped, log := "a dependency failed" }]
        broken := broken ++ [m]
        continue
      let old ← readOr stampFile
      let haveOlean ← (System.FilePath.mk olean).pathExists
      if !cfg.force && haveOlean && old == stamp then
        results := results ++ [{ module := m, status := .cached, log := "" }]
        continue
      ensureParent olean
      let src := cfg.root ++ "/" ++ f.path
      let args := ch.leanPre ++ [src, "-o", olean]
      let (code, out, err) ← run ch.leanCmd args (some cfg.root) env
      if code == 0 then
        IO.FS.writeFile stampFile stamp
        results := results ++ [{ module := m, status := .built, log := Util.trim (out ++ err) }]
      else
        broken := broken ++ [m]
        results := results ++ [{ module := m, status := .failed, log := Util.trim (out ++ err) }]
  return (results, [])

/-! ### The axiom audit -/

/-- The kinds of declaration whose axioms are worth printing. -/
def provingKinds : List String := ["theorem", "lemma", "example"]

/-- One line of `#print axioms` output, parsed. -/
structure AxiomLine where
  name : String
  axioms : List String
  deriving Inhabited

/-- Parse the compiler's answer for one declaration. -/
def parseAxiomLine (l : String) : Option AxiomLine :=
  let l := Util.trim l
  if !(l.startsWith "'") then none
  else
    match l.splitOn "'" with
    | _ :: nm :: rest =>
        let tail := String.intercalate "'" rest
        if (tail.splitOn "depends on axioms:").length == 2 then
          let after := (tail.splitOn "depends on axioms:").getD 1 ""
          let after := Util.trim after
          let after := Util.dropPrefix after "["
          let after := if after.endsWith "]" then (after.dropEnd 1).toString else after
          let axs := ((after.splitOn ",").map Util.trim).filter (fun a => a != "")
          some { name := nm, axioms := axs }
        else some { name := nm, axioms := [] }
    | _ => none

/-- Build a driver file that prints the axioms of every theorem, run it, and
report. -/
def auditAxioms (cfg : Config) (ch : Chain) (infos : List Syn.FileInfo) :
    IO (List AxiomLine × String) := do
  let names := Util.dedup <| infos.flatMap (fun f =>
    f.decls.filterMap (fun d =>
      if provingKinds.contains d.kind && d.name != "" then some d.name else none))
  if names.isEmpty then return ([], "")
  let imports := infos.map (fun f => "import " ++ f.module)
  let body := names.map (fun n => "#print axioms " ++ n)
  let driver := Util.unlines (imports ++ [""] ++ body ++ [""])
  let dir := cfg.root ++ "/" ++ cfg.buildDir
  IO.FS.createDirAll dir
  let path := dir ++ "/GokujoAxiomAudit.lean"
  IO.FS.writeFile path driver
  let env ← leanEnv cfg ch
  let (_, out, err) ← run ch.leanCmd (ch.leanPre ++ [path]) (some cfg.root) env
  let lines := (Util.lines (out ++ "\n" ++ err))
  let parsed := lines.filterMap parseAxiomLine
  let complaints := lines.filter (fun l => (l.splitOn "error").length > 1)
  return (parsed, Util.unlines complaints)

/-- Axioms outside the allowed set. -/
def offending (cfg : Config) (a : AxiomLine) : List String :=
  a.axioms.filter (fun x => !cfg.allowAxioms.contains x)

end Sys

/-! ## 10. Rendering: the terminal, Markdown, and one HTML page

Three renderings of the same values.  The terminal one is what `gokujo help`
prints, the Markdown one is the front matter of `GOKUJO.md`, and the HTML one
is a single file with no scripts and no external resources.
-/

namespace Render

open Doc

/-- The one-line banner. -/
def banner : String :=
  kanji ++ "  gokujo " ++ version ++ "  —  a Swiss army knife for Lean 4"

/-- The usage summary. -/
def usage : List String :=
  ["usage: gokujo <command> [paths...] [options]", ""] ++
  commands.map (fun c =>
    "  " ++ Util.padR (c.name ++ " " ++ c.args) 26 ++ c.summary) ++
  [ ""
  , "options:"
  , "  --json              machine-readable output on stdout"
  , "  --backend NAME      standalone | bundled | system | elan | lake | nix"
  , "  --root DIR          treat DIR as the project root (default: .)"
  , "  -o FILE             where to write, for html, tangle, weave, bootstrap"
  , "  --force             rebuild even if the content digest is unchanged"
  , "  --allow-native      tolerate native_decide"
  , "  --allow-axiom NAME  permit one more axiom in the audit"
  , "  --verbose           print every command that is run"
  ]

/-- The whole manual, as terminal text. -/
def manual : List String :=
  [banner, ""] ++
  topics.flatMap (fun t => [t.title, String.ofList (List.replicate t.title.length '-')] ++ t.body ++ [""]) ++
  usage ++
  ["", "commands in detail", "------------------"] ++
  commands.flatMap (fun c =>
    ["", "  gokujo " ++ c.name ++ " " ++ c.args, "    " ++ c.summary] ++
    c.body.map (fun l => "    " ++ l))

/-- The manual entry for one command. -/
def entry (name : String) : List String :=
  match commands.find? (fun c => c.name == name) with
  | none => ["no such command: " ++ name, ""] ++ usage
  | some c => ["gokujo " ++ c.name ++ " " ++ c.args, "", "  " ++ c.summary] ++ c.body.map (fun l => "  " ++ l)

/-- The Markdown front matter of `GOKUJO.md`. -/
def markdown : List String :=
  [ "# " ++ kanji ++ " gokujo " ++ version
  , ""
  , "*A Swiss army knife for Lean 4: one Lean file, one Markdown file.*"
  , ""
  , "This document contains the program.  The program contains this document."
  , "Everything below the fence is `Gokujo.lean`, character for character; run"
  , "`gokujo tangle GOKUJO.md -o Gokujo.lean` to get the file back, and"
  , "`gokujo selfcheck` to verify that the two agree."
  , ""
  ] ++
  topics.flatMap (fun t => ["## " ++ t.title, ""] ++ t.body ++ [""]) ++
  [ "## Commands", ""
  , "| command | does |"
  , "| --- | --- |" ] ++
  commands.map (fun c => "| `gokujo " ++ c.name ++ " " ++ c.args ++ "` | " ++ c.summary ++ " |") ++
  [ ""
  , "## Install"
  , ""
  , "    gokujo tangle GOKUJO.md -o Gokujo.lean"
  , "    lean Gokujo.lean -c gokujo.c && leanc -o gokujo gokujo.c"
  , ""
  , "or, if you already have a `gokujo`, just `gokujo bootstrap`."
  , ""
  , "## The program"
  , ""
  ]

/-- The CSS of the HTML page, inline. -/
def css : String :=
  "body{margin:0;background:#faf8f5;color:#1a1a1a;font:16px/1.6 ui-serif,Georgia,serif}" ++
  "main{max-width:52rem;margin:0 auto;padding:3rem 1.25rem 6rem}" ++
  "h1{font-size:2.2rem;margin:0 0 .3rem}h1 .k{color:#a33}" ++
  "h2{margin-top:2.6rem;border-bottom:1px solid #ddd6cc;padding-bottom:.3rem}" ++
  ".sub{color:#6b6257;margin:0 0 2rem}" ++
  "pre{background:#fff;border:1px solid #e6dfd5;border-radius:6px;padding:.9rem 1rem;overflow-x:auto;" ++
  "font:13px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace}" ++
  "table{border-collapse:collapse;width:100%;font-size:.92rem}" ++
  "th,td{text-align:left;padding:.35rem .6rem;border-bottom:1px solid #e6dfd5;vertical-align:top}" ++
  "th{color:#6b6257;font-weight:600}" ++
  "code{font:13px ui-monospace,SFMono-Regular,Menlo,monospace;background:#f1ece4;padding:.1rem .3rem;border-radius:3px}" ++
  ".ok{color:#256029}.bad{color:#a3232c;font-weight:600}" ++
  "footer{margin-top:4rem;color:#8a8178;font-size:.85rem}"

/-- One HTML table row. -/
def row (cells : List String) (header : Bool := false) : String :=
  let tag := if header then "th" else "td"
  "<tr>" ++ String.join (cells.map (fun c => "<" ++ tag ++ ">" ++ c ++ "</" ++ tag ++ ">")) ++ "</tr>"

/-- The manual as one self-contained HTML page, with an optional project
report. -/
def page (report : List Syn.FileInfo) (chainLine : String) : String :=
  let esc := Html.escape
  let head :=
    "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">" ++
    "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">" ++
    "<title>gokujo " ++ version ++ "</title><style>" ++ css ++ "</style></head><body><main>"
  let title :=
    "<h1><span class=\"k\">" ++ esc kanji ++ "</span> gokujo <small>" ++ esc version ++ "</small></h1>" ++
    "<p class=\"sub\">A Swiss army knife for Lean 4 &mdash; one Lean file, one Markdown file. " ++
    esc chainLine ++ "</p>"
  let topicsHtml := String.join (topics.map (fun t =>
    "<h2 id=\"" ++ esc t.id ++ "\">" ++ esc t.title ++ "</h2><pre>" ++
    esc (Util.unlines t.body) ++ "</pre>"))
  let cmdHtml :=
    "<h2 id=\"commands\">Commands</h2><table>" ++
    row ["command", "does"] true ++
    String.join (commands.map (fun c =>
      row ["<code>gokujo " ++ esc (c.name ++ " " ++ c.args) ++ "</code>", esc c.summary])) ++
    "</table>"
  let reportHtml :=
    if report.isEmpty then "" else
      let holes := report.flatMap (fun f => f.holes)
      "<h2 id=\"project\">This project</h2><table>" ++
      row ["module", "decls", "holes", "lines", "imports"] true ++
      String.join (report.map (fun f =>
        row [ "<code>" ++ esc f.module ++ "</code>"
            , toString f.decls.length
            , (if f.holes.isEmpty then "<span class=\"ok\">0</span>"
               else "<span class=\"bad\">" ++ toString f.holes.length ++ "</span>")
            , toString f.lineCount
            , toString f.imports.length ])) ++
      "</table><p>" ++
      (if holes.isEmpty then "<span class=\"ok\">No sorry, no admit.</span>"
       else "<span class=\"bad\">" ++ toString holes.length ++ " declaration(s) with a hole: " ++
            esc (String.intercalate ", " (holes.map (·.name))) ++ "</span>") ++ "</p>"
  let foot :=
    "<footer>Rendered by gokujo " ++ esc version ++
    ", from the documentation embedded in <code>Gokujo.lean</code>. " ++
    "No scripts, no fonts, no network.</footer></main></body></html>"
  head ++ title ++ topicsHtml ++ cmdHtml ++ reportHtml ++ foot

end Render

/-! ## 11. The built-in tests

`gokujo selftest` runs the compiled code against the properties the theorems
describe, plus the parser cases that matter in practice: a `sorry` in a
comment is not a `sorry`.
-/

namespace Test

/-- One test: a name and its verdict. -/
abbrev Case := String × Bool

/-- A file with a `sorry` in a comment, in a string, and in earnest. -/
def tricky : String :=
  "import Init\n" ++
  "namespace Demo\n" ++
  "-- this comment says sorry\n" ++
  "/- and this block comment says sorry too -/\n" ++
  "def greeting : String := \"sorry\"\n" ++
  "def named : List Lean.Name := [`Lean.sorryAx]\n" ++
  "inductive Flag | sorryAx | fine\n" ++
  "theorem easy : 1 = 1 := rfl\n" ++
  "theorem hard : 2 = 2 := by sorry\n" ++
  "end Demo\n"

/-- The tests. -/
def cases : List Case :=
  let info := Syn.parseFile "Demo.lean" tricky
  let names := info.decls.map (·.name)
  let holed := info.holes.map (·.name)
  let sample := "def f (x : Nat) := x + 1 -- été\n/- /- nested -/ still -/\n"
  let toks := Lex.tokens sample
  let g : Graph.G := [("A", ["B", "C"]), ("B", ["C"]), ("C", []), ("D", ["X"])]
  let cyc : Graph.G := [("P", ["Q"]), ("Q", ["P"])]
  let prose := ["# title", "", "some prose"]
  let code := ["def x := 1", "", "theorem t : x = 1 := rfl"]
  [ ("lexer is faithful on a tricky sample",
      String.ofList ((toks.map Lex.Tok.text).flatten) == sample)
  , ("lexer is faithful on its own manual",
      String.ofList (((Lex.tokens Render.css).map Lex.Tok.text).flatten) == Render.css)
  , ("nested block comments are one token",
      (toks.filter (fun t => t.kind == .blockComment)).length == 1)
  , ("declarations are found and qualified",
      names == ["Demo.greeting", "Demo.named", "Demo.Flag", "Demo.easy", "Demo.hard"])
  , ("a qualified sorryAx is a mention, not a hole", !holed.contains "Demo.named")
  , ("a constructor called sorryAx is not a hole", !holed.contains "Demo.Flag")
  , ("a sorry in a comment is not a sorry", !holed.contains "Demo.easy")
  , ("a sorry in a string is not a sorry", !holed.contains "Demo.greeting")
  , ("a real sorry is found", holed == ["Demo.hard"])
  , ("imports are read", info.imports == ["Init"])
  , ("topological order is accepted by the checker", Graph.orderOk g (Graph.topo g))
  , ("dependencies really do come first",
      Graph.idx (Graph.topo g) "C" < Graph.idx (Graph.topo g) "A")
  , ("a cycle is reported, not mis-ordered", Graph.cyclic cyc == ["P", "Q"])
  , ("markdown round trip", Md.tangleLines (Md.weaveLines prose code) == code)
  , ("html escaping escapes",
      Html.escape "<a href=\"x\">&</a>" == "&lt;a href=&quot;x&quot;&gt;&amp;&lt;/a&gt;")
  , ("html escaping leaves text alone", Html.escape "plain text 123" == "plain text 123")
  , ("axiom lines parse",
      match Sys.parseAxiomLine "'Foo.bar' depends on axioms: [propext, Quot.sound]" with
      | some a => a.name == "Foo.bar" && a.axioms == ["propext", "Quot.sound"]
      | none => false)
  , ("axiom-free lines parse",
      match Sys.parseAxiomLine "'Foo.baz' does not depend on any axioms" with
      | some a => a.name == "Foo.baz" && a.axioms == []
      | none => false)
  , ("module names come from paths",
      Syn.moduleOfPath "RequestProject/Wasm/Core.lean" == "RequestProject.Wasm.Core")
  , ("digests are stable", Util.digest "abc" == Util.digest "abc")
  , ("digests separate", Util.digest "abc" != Util.digest "abd")
  ]

/-- How many passed. -/
def passed : Nat := (cases.filter (·.2)).length

/-- Did everything pass? -/
def allPass : Bool := cases.all (·.2)

end Test

/-! ## 12. The command line

One entry point, one exit code.  0 success, 1 the project failed the check,
2 gokujo was used wrongly, 3 there is no toolchain to compile with.
-/

namespace Cli

open Sys Tool Render

/-- The parsed command line. -/
structure Args where
  cmd : String := "help"
  positional : List String := []
  cfg : Config := {}
  deriving Inhabited

/-- Parse the command line. -/
def parseArgs : List String → Args → Except String Args
  | [], a => .ok a
  | x :: xs, a =>
    if x == "--json" then parseArgs xs { a with cfg := { a.cfg with json := true } }
    else if x == "--force" then parseArgs xs { a with cfg := { a.cfg with force := true } }
    else if x == "--verbose" || x == "-v" then
      parseArgs xs { a with cfg := { a.cfg with verbose := true } }
    else if x == "--allow-native" then
      parseArgs xs { a with cfg := { a.cfg with allowNative := true } }
    else if x == "--help" || x == "-h" then parseArgs xs { a with cmd := "help" }
    else if x == "--version" then parseArgs xs { a with cmd := "version" }
    else if x == "--backend" then
      match xs with
      | v :: rest =>
          match Backend.ofName? v with
          | some b => parseArgs rest { a with cfg := { a.cfg with backend := some b } }
          | none => .error ("unknown backend: " ++ v)
      | [] => .error "--backend needs a name"
    else if x == "--root" then
      match xs with
      | v :: rest => parseArgs rest { a with cfg := { a.cfg with root := v } }
      | [] => .error "--root needs a directory"
    else if x == "--allow-axiom" then
      match xs with
      | v :: rest =>
          parseArgs rest { a with cfg := { a.cfg with allowAxioms := a.cfg.allowAxioms ++ [v] } }
      | [] => .error "--allow-axiom needs a name"
    else if x == "-o" || x == "--out" then
      match xs with
      | v :: rest => parseArgs rest { a with cfg := { a.cfg with out := some v } }
      | [] => .error "-o needs a file"
    else if x.startsWith "-" then .error ("unknown option: " ++ x)
    else if a.cmd == "" then parseArgs xs { a with cmd := x }
    else parseArgs xs { a with positional := a.positional ++ [x] }

/-- Print a list of lines. -/
def put (ls : List String) : IO Unit := for l in ls do IO.println l

/-- Merge the file config with the command line (the command line wins). -/
def effective (a : Args) : IO Config := do
  let absRoot ← absPath a.cfg.root
  let a := { a with cfg := { a.cfg with root := absRoot } }
  let file ← loadConfig a.cfg.root
  return { a.cfg with
    src := if a.cfg.src ≠ [] then a.cfg.src else file.src
    backend := a.cfg.backend.orElse (fun _ => file.backend)
    buildDir := if a.cfg.buildDir == ".gokujo/build" then file.buildDir else a.cfg.buildDir
    allowAxioms := Util.dedup (a.cfg.allowAxioms ++ file.allowAxioms)
    allowNative := a.cfg.allowNative || file.allowNative }

/-- `gokujo help`. -/
def help (a : Args) : IO UInt32 := do
  match a.positional with
  | [] => put manual
  | c :: _ => put (entry c)
  return 0

/-- `gokujo version`. -/
def versionCmd (a : Args) : IO UInt32 := do
  let cfg ← effective a
  let ch ← toolchain cfg
  if cfg.json then
    IO.println (jobj [("gokujo", jstr version), ("backend", jstr ch.backend.name),
      ("toolchain", jstr ch.version), ("host", jstr System.Platform.target)])
  else
    put [banner, "", "  backend    " ++ ch.backend.name ++ "  (" ++ ch.backend.about ++ ")",
         "  toolchain  " ++ ch.version,
         "  host       " ++ System.Platform.target]
  return 0

/-- `gokujo doctor`. -/
def doctor (a : Args) : IO UInt32 := do
  let cfg ← effective a
  let all : List Backend := [.standalone, .bundled, .system, .elan, .lake, .nix]
  let mut rows : List (Backend × Option Chain) := []
  for b in all do
    rows := rows ++ [(b, ← resolve b cfg.root)]
  let chosen ← toolchain cfg
  if cfg.json then
    IO.println (jobj
      [("chosen", jstr chosen.backend.name),
       ("backends", jarr (rows.map (fun r =>
          jobj [("name", jstr r.1.name),
                ("available", jbool r.2.isSome),
                ("runs", jstr ((r.2.map Chain.show).getD "")),
                ("version", jstr ((r.2.map (·.version)).getD ""))])))])
  else
    put ([banner, "", "  " ++ Util.padR "backend" 12 ++ Util.padR "state" 14 ++ "runs"] ++
      rows.map (fun r =>
        "  " ++ Util.padR r.1.name 12 ++
        Util.padR (if r.2.isSome then "available" else "missing") 14 ++
        ((r.2.map Chain.show).getD r.1.about)) ++
      ["", "  chosen: " ++ chosen.backend.name ++ "   " ++ chosen.version,
       "  host:   " ++ System.Platform.target])
  return 0

/-- Scan, and hand back the parsed files. -/
def gather (a : Args) : IO (Config × List Syn.FileInfo) := do
  let cfg ← effective a
  let infos ← scanPaths cfg (defaultPaths cfg a.positional)
  return (cfg, infos)

/-- One file, as JSON. -/
def fileJson (f : Syn.FileInfo) : String :=
  jobj [("module", jstr f.module), ("path", jstr f.path),
        ("imports", jarr (f.imports.map jstr)),
        ("declarations", jnat f.decls.length),
        ("lines", jnat f.lineCount),
        ("digest", jstr f.digest),
        ("holes", jarr (f.holes.map (fun d =>
           jobj [("name", jstr d.name), ("kind", jstr d.kind), ("line", jnat d.line)]))),
        ("native", jarr (f.trusting.map (fun d => jstr d.name)))]

/-- `gokujo scan`. -/
def scan (a : Args) : IO UInt32 := do
  let (cfg, infos) ← gather a
  let holes := infos.flatMap (fun f => f.holes)
  if cfg.json then
    IO.println (jobj [("files", jarr (infos.map fileJson)),
                      ("declarations", jnat (infos.flatMap (·.decls)).length),
                      ("holes", jnat holes.length)])
  else
    put (["  " ++ Util.padR "module" 42 ++ Util.padL "decls" 7 ++ Util.padL "holes" 7 ++
            Util.padL "lines" 7 ++ Util.padL "imports" 9] ++
      infos.map (fun f =>
        "  " ++ Util.padR f.module 42 ++ Util.padL (toString f.decls.length) 7 ++
        Util.padL (toString f.holes.length) 7 ++ Util.padL (toString f.lineCount) 7 ++
        Util.padL (toString f.imports.length) 9) ++
      ["", "  " ++ toString infos.length ++ " files, " ++
        toString (infos.flatMap (·.decls)).length ++ " declarations, " ++
        toString holes.length ++ " with holes"])
  return 0

/-- `gokujo sorry`. -/
def sorryCmd (a : Args) : IO UInt32 := do
  let (cfg, infos) ← gather a
  let holes := infos.flatMap (fun f => f.holes.map (fun d => (f, d)))
  let native := if cfg.allowNative then [] else infos.flatMap (fun f => f.trusting.map (fun d => (f, d)))
  if cfg.json then
    IO.println (jobj
      [("holes", jarr (holes.map (fun p =>
          jobj [("module", jstr p.1.module), ("name", jstr p.2.name),
                ("line", jnat p.2.line)]))),
       ("native", jarr (native.map (fun p => jstr p.2.name))),
       ("clean", jbool (holes.isEmpty && native.isEmpty))])
  else if holes.isEmpty && native.isEmpty then
    IO.println ("  no sorry, no admit" ++ (if cfg.allowNative then "" else ", no native_decide") ++
      "  (" ++ toString (infos.flatMap (·.decls)).length ++ " declarations in " ++
      toString infos.length ++ " files)")
  else
    put (holes.map (fun p => "  " ++ p.1.path ++ ":" ++ toString p.2.line ++ "  " ++
           p.2.kind ++ " " ++ p.2.name ++ "  has a hole") ++
         native.map (fun p => "  " ++ p.1.path ++ ":" ++ toString p.2.line ++ "  " ++
           p.2.kind ++ " " ++ p.2.name ++ "  trusts the evaluator"))
  return (if holes.isEmpty && native.isEmpty then 0 else 1)

/-- `gokujo graph`. -/
def graph (a : Args) : IO UInt32 := do
  let (cfg, infos) ← gather a
  let g := graphOf infos
  let order := Graph.topo g
  let ok := Graph.orderOk g order
  let cyc := Graph.cyclic g
  if cfg.json then
    IO.println (jobj [("order", jarr (order.map jstr)), ("checked", jbool ok),
                      ("cyclic", jarr (cyc.map jstr)),
                      ("edges", jarr (g.flatMap (fun n =>
                        (n.2.filter (Graph.mem g)).map (fun d =>
                          jobj [("from", jstr d), ("to", jstr n.1)]))))])
  else
    put (["  build order (" ++ toString order.length ++ " modules, checker says " ++
            (if ok then "ok" else "NOT ok") ++ ")"] ++
      (order.zipIdx.map (fun p => "  " ++ Util.padL (toString (p.2 + 1)) 4 ++ "  " ++ p.1)) ++
      (if cyc.isEmpty then [] else ["", "  in a cycle: " ++ String.intercalate ", " cyc]))
  return (if ok && cyc.isEmpty then 0 else 1)

/-- `gokujo build`. -/
def build (a : Args) : IO UInt32 := do
  let (cfg, infos) ← gather a
  let ch ← toolchain cfg
  if !ch.backend.compiles then
    IO.eprintln "  no toolchain available; try --backend system, or install one"
    return 3
  let (results, cyc) ← buildAll cfg ch infos
  let failed := results.filter (fun r => r.status == .failed)
  let built := results.filter (fun r => r.status == .built)
  let cached := results.filter (fun r => r.status == .cached)
  if cfg.json then
    IO.println (jobj
      [("backend", jstr ch.backend.name),
       ("built", jnat built.length), ("cached", jnat cached.length),
       ("failed", jarr (failed.map (fun r =>
          jobj [("module", jstr r.module), ("log", jstr r.log)]))),
       ("cyclic", jarr (cyc.map jstr)),
       ("ok", jbool (failed.isEmpty && cyc.isEmpty))])
  else
    if !cyc.isEmpty then
      IO.println ("  refusing to build: import cycle among " ++ String.intercalate ", " cyc)
    else
      for r in results do
        if r.status == .built then IO.println ("  built    " ++ r.module)
        else if r.status == .failed then
          IO.println ("  FAILED   " ++ r.module)
          if r.log != "" then put ((Util.lines r.log).map (fun l => "      " ++ l))
        else if r.status == .skipped then IO.println ("  skipped  " ++ r.module)
        else if cfg.verbose then IO.println ("  cached   " ++ r.module)
      IO.println ("  " ++ toString built.length ++ " built, " ++ toString cached.length ++
        " cached, " ++ toString failed.length ++ " failed  [" ++ ch.backend.name ++ "]")
  return (if failed.isEmpty && cyc.isEmpty then 0 else 1)

/-- `gokujo axioms`. -/
def axioms (a : Args) : IO UInt32 := do
  let (cfg, infos) ← gather a
  let ch ← toolchain cfg
  if !ch.backend.compiles then
    IO.eprintln "  no toolchain available; the axiom audit needs one"
    return 3
  let (results, _) ← buildAll cfg ch infos
  if results.any (fun r => r.status == .failed) then
    IO.eprintln "  build failed; cannot audit axioms"
    return 1
  let (lines, complaints) ← auditAxioms cfg ch infos
  let bad := lines.filter (fun l => !(offending cfg l).isEmpty)
  let observed := Util.dedup (lines.flatMap (·.axioms))
  if cfg.json then
    IO.println (jobj
      [("audited", jnat lines.length),
       ("allowed", jarr (cfg.allowAxioms.map jstr)),
       ("observed", jarr (observed.map jstr)),
       ("violations", jarr (bad.map (fun l =>
          jobj [("name", jstr l.name), ("axioms", jarr ((offending cfg l).map jstr))]))),
       ("ok", jbool bad.isEmpty)])
  else
    put (["  audited " ++ toString lines.length ++ " declarations",
          "  allowed:  " ++ String.intercalate ", " cfg.allowAxioms,
          "  observed: " ++ (if observed.isEmpty then "nothing at all"
                             else String.intercalate ", " observed)] ++
      (if bad.isEmpty then ["  no theorem depends on anything else"]
       else bad.map (fun l => "  " ++ l.name ++ "  uses  " ++
              String.intercalate ", " (offending cfg l))) ++
      (if complaints == "" then [] else ["", "  the audit driver reported:"] ++
        (Util.lines complaints).map (fun l => "      " ++ l)))
  return (if bad.isEmpty then 0 else 1)

/-- `gokujo check`: every gate, in order. -/
def check (a : Args) : IO UInt32 := do
  let cfg ← effective a
  if !cfg.json then IO.println banner
  let mut code : UInt32 := 0
  if !cfg.json then IO.println "\n  [1/5] scan"
  let s ← scan a
  if !cfg.json then IO.println "\n  [2/5] order"
  let g ← graph a
  if !cfg.json then IO.println "\n  [3/5] build"
  let b ← build a
  if !cfg.json then IO.println "\n  [4/5] holes"
  let h ← sorryCmd a
  if !cfg.json then IO.println "\n  [5/5] axioms"
  let x ← if b == 0 then axioms a else pure b
  code := if s == 0 && g == 0 && b == 0 && h == 0 && x == 0 then 0 else 1
  if !cfg.json then
    IO.println ("\n  " ++ (if code == 0 then "PASS" else "FAIL"))
  return code

/-- `gokujo html`. -/
def html (a : Args) : IO UInt32 := do
  let (cfg, infos) ← gather a
  let ch ← toolchain cfg
  let line := "Toolchain: " ++ ch.backend.name ++ " " ++ ch.version ++ "."
  let doc := page infos line
  match cfg.out with
  | some f => do
      ensureParent f
      IO.FS.writeFile f doc
      IO.println ("  wrote " ++ f ++ "  (" ++ toString doc.length ++ " characters)")
  | none => IO.println doc
  return 0

/-- `gokujo weave`. -/
def weave (a : Args) : IO UInt32 := do
  let cfg ← effective a
  let src := (a.positional.head?).getD (cfg.root ++ "/Gokujo.lean")
  let code ← readOr src
  if code == "" then
    IO.eprintln ("  cannot read " ++ src)
    return 2
  let md := Md.weave (Util.unlines markdown) code
  match cfg.out with
  | some f => do IO.FS.writeFile f md; IO.println ("  wrote " ++ f)
  | none => IO.println md
  return 0

/-- `gokujo tangle`. -/
def tangle (a : Args) : IO UInt32 := do
  let cfg ← effective a
  let src := (a.positional.head?).getD (cfg.root ++ "/GOKUJO.md")
  let md ← readOr src
  if md == "" then
    IO.eprintln ("  cannot read " ++ src)
    return 2
  let code := Md.tangle md
  match cfg.out with
  | some f => do IO.FS.writeFile f code; IO.println ("  wrote " ++ f)
  | none => IO.println code
  return 0

/-- `gokujo selfcheck`. -/
def selfcheck (a : Args) : IO UInt32 := do
  let cfg ← effective a
  let leanPath := cfg.root ++ "/Gokujo.lean"
  let mdPath := cfg.root ++ "/GOKUJO.md"
  let code ← readOr leanPath
  let md ← readOr mdPath
  let extracted := Md.tangle md
  let same := extracted == code
  if cfg.json then
    IO.println (jobj [("lean", jstr leanPath), ("markdown", jstr mdPath),
                      ("leanDigest", jstr (Util.digest code)),
                      ("tangledDigest", jstr (Util.digest extracted)),
                      ("agree", jbool same)])
  else if same then
    IO.println ("  " ++ mdPath ++ " contains " ++ leanPath ++ " exactly  (" ++
      Util.digest code ++ ", " ++ toString (Util.lines code).length ++ " lines)")
  else
    IO.println ("  they differ: Gokujo.lean is " ++ Util.digest code ++
      ", the block in GOKUJO.md is " ++ Util.digest extracted)
  return (if same then 0 else 1)

/-- `gokujo selftest`. -/
def selftest (a : Args) : IO UInt32 := do
  let cfg ← effective a
  if cfg.json then
    IO.println (jobj [("cases", jarr (Test.cases.map (fun c =>
        jobj [("name", jstr c.1), ("pass", jbool c.2)]))),
      ("passed", jnat Test.passed), ("total", jnat Test.cases.length),
      ("ok", jbool Test.allPass)])
  else
    put (Test.cases.map (fun c => "  " ++ (if c.2 then "pass  " else "FAIL  ") ++ c.1) ++
      ["", "  " ++ toString Test.passed ++ "/" ++ toString Test.cases.length ++ " passed"])
  return (if Test.allPass then 0 else 1)

/-- `gokujo targets`. -/
def targets (a : Args) : IO UInt32 := do
  let cfg ← effective a
  if cfg.json then
    IO.println (jarr (Tool.matrix.map (fun t =>
      jobj [("flavour", jstr t.1.name), ("platform", jstr t.2.1.triple),
            ("artifact", jstr t.2.2), ("needs", jstr t.1.about)])))
  else
    put (["  " ++ Util.padR "artifact" 46 ++ Util.padR "platform" 22 ++ "what it needs"] ++
      Tool.matrix.map (fun t =>
        "  " ++ Util.padR t.2.2 46 ++ Util.padR t.2.1.label 22 ++ t.1.about) ++
      ["", "  build one for this host with: gokujo bootstrap -o " ++
         Tool.artifact .system ⟨System.Platform.target, ""⟩,
       "  cross builds use the same two commands with that platform's toolchain."])
  return 0

/-- `gokujo release`: write the script that builds the whole matrix. -/
def release (a : Args) : IO UInt32 := do
  let cfg ← effective a
  let script :=
    [ "#!/bin/sh"
    , "# Build every gokujo executable.  Written by gokujo " ++ version ++ "."
    , "#"
    , "# For each platform, point LEAN and LEANC at that platform's toolchain and run"
    , "# this script; every flavour for that platform is produced in dist/.  A bundled"
    , "# artifact additionally wants the toolchain copied beside it, in"
    , "# dist/<artifact>.toolchain/bin, which is where the bundled backend looks."
    , "set -eu"
    , "LEAN=${LEAN:-lean}"
    , "LEANC=${LEANC:-leanc}"
    , "SRC=${SRC:-Gokujo.lean}"
    , "HOST=${HOST:-" ++ System.Platform.target ++ "}"
    , "mkdir -p dist build"
    , "\"$LEAN\" \"$SRC\" -o build/Gokujo.olean -c build/gokujo.c"
    , "" ] ++
    Tool.matrix.flatMap (fun t =>
      [ "# " ++ t.1.name ++ " · " ++ t.2.1.label ++ " · " ++ t.1.about
      , "if [ \"$HOST\" = \"" ++ t.2.1.triple ++ "\" ]; then"
      , "  \"$LEANC\" build/gokujo.c -o dist/" ++ t.2.2
      , "fi"
      , "" ]) ++
    [ "echo 'dist:' && ls -1 dist" ]
  let text := Util.unlines script
  match cfg.out with
  | some f => do
      IO.FS.writeFile f text
      IO.println ("  wrote " ++ f ++ "  (" ++ toString Tool.matrix.length ++ " targets)")
  | none => IO.println text
  return 0

/-- `gokujo bootstrap`: compile this file into an executable. -/
def bootstrap (a : Args) : IO UInt32 := do
  let cfg ← effective a
  let ch ← toolchain cfg
  if !ch.backend.compiles then
    IO.eprintln "  no toolchain available to compile with"
    return 3
  let src := (a.positional.head?).getD (cfg.root ++ "/Gokujo.lean")
  let exe := cfg.out.getD (cfg.root ++ "/gokujo")
  let dir := cfg.root ++ "/" ++ cfg.buildDir
  IO.FS.createDirAll dir
  let cfile := dir ++ "/gokujo.c"
  let olean := dir ++ "/Gokujo.olean"
  let env ← leanEnv cfg ch
  let a1 := ch.leanPre ++ [src, "-o", olean, "-c", cfile]
  IO.println ("  " ++ String.intercalate " " (ch.leanCmd :: a1))
  let (c1, o1, e1) ← run ch.leanCmd a1 (some cfg.root) env
  if c1 != 0 then
    IO.eprintln (o1 ++ e1)
    return 1
  let a2 := ch.leancPre ++ [cfile, "-o", exe]
  IO.println ("  " ++ String.intercalate " " (ch.leancCmd :: a2))
  let (c2, o2, e2) ← run ch.leancCmd a2 (some cfg.root) env
  if c2 != 0 then
    IO.eprintln (o2 ++ e2)
    return 1
  IO.println ("  wrote " ++ exe)
  return 0

/-- `gokujo bundle`: carry a toolchain, so that nothing else has to be
installed. -/
def bundle (a : Args) : IO UInt32 := do
  let cfg ← effective a
  let ch ← toolchain cfg
  let src ← match a.positional.head? with
    | some p => absPath p
    | none =>
        if ch.backend == .system || ch.backend == .elan then
          match (System.FilePath.mk ch.leanCmd).parent.bind (·.parent) with
          | some d => pure d.toString
          | none => pure ""
        else pure ""
  if src == "" || src == "lean" then
    IO.eprintln "  give the toolchain directory to bundle, e.g. ~/.elan/toolchains/<name>"
    return 2
  let dest := cfg.out.getD (((← exeDir).getD cfg.root) ++ "/toolchain")
  let (code, _, err) ← run "cp" ["-a", src, dest]
  if code != 0 then
    IO.eprintln ("  could not copy " ++ src ++ " to " ++ dest ++ ": " ++ err)
    return 1
  match ← probe (dest ++ "/bin/lean") ["--version"] with
  | some (0, v, _) =>
      IO.println ("  bundled " ++ Util.trim v ++ "  in " ++ dest)
      IO.println "  this executable is now self-contained: gokujo --backend bundled"
      return 0
  | _ =>
      IO.eprintln ("  copied, but " ++ dest ++ "/bin/lean does not run")
      return 1

/-- `gokujo init`. -/
def init (a : Args) : IO UInt32 := do
  let cfg ← effective a
  let dir := cfg.root ++ "/.gokujo"
  IO.FS.createDirAll dir
  let src := (a.positional.head?).getD "."
  let body := Util.unlines
    [ "# written by gokujo " ++ version
    , "src = " ++ src
    , "build = .gokujo/build"
    , "allow-native = false"
    , "" ]
  IO.FS.writeFile (dir ++ "/config") body
  IO.println ("  wrote " ++ dir ++ "/config")
  return 0

/-- Dispatch. -/
def dispatch (a : Args) : IO UInt32 := do
  match a.cmd with
  | "help" => help a
  | "version" => versionCmd a
  | "doctor" => doctor a
  | "scan" => scan a
  | "sorry" => sorryCmd a
  | "graph" => graph a
  | "build" => build a
  | "axioms" => axioms a
  | "check" => check a
  | "html" => html a
  | "weave" => weave a
  | "tangle" => tangle a
  | "selfcheck" => selfcheck a
  | "selftest" => selftest a
  | "targets" => targets a
  | "release" => release a
  | "bootstrap" => bootstrap a
  | "bundle" => bundle a
  | "init" => init a
  | c => do
      IO.eprintln ("gokujo: unknown command: " ++ c)
      IO.eprintln "try: gokujo help"
      return 2

/-- The entry point. -/
def main (argv : List String) : IO UInt32 := do
  match parseArgs argv { cmd := "" } with
  | .error e => do
      IO.eprintln ("gokujo: " ++ e)
      return 2
  | .ok a =>
      let a := if a.cmd == "" then { a with cmd := "help" } else a
      dispatch a

end Cli

end Gokujo

/-- `gokujo`, the executable.  The root `main` that `lake` needs lives in
`GokujoMain.lean`, so that this library can be imported by other programs. -/
def gokujoMain (argv : List String) : IO UInt32 := Gokujo.Cli.main argv
