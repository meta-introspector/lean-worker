-- CommandExecution.lean
-- Lean 4 execution harness: runs shell commands and returns compact results.
-- Acts as a context minimizer — captures command output and returns
-- a structured, bounded result suitable for token-constrained contexts.

import Std

namespace CommandExecution

-- ============================================
-- Result Type: Compact, Bounded Output
-- ============================================

structure ExecResult where
  command   : String
  exitCode  : Nat
  stdout    : String
  stderr    : String
  duration  : Nat
  truncated : Bool

abbrev ExecResultBounded : Nat := 5000

-- Helper: take first N characters of a String.
-- Fixed: `String.take` returns a `String.Slice` in current Lean, and slices
-- have no constant-time `length`; we go through the character list instead,
-- which keeps the length reasoning below available.
def stringTake (s : String) (n : Nat) : String :=
  String.ofList (s.toList.take n)

-- The truncation helper never returns more than `n` characters.
theorem stringTake_length_le (s : String) (n : Nat) :
    (stringTake s n).length ≤ n := by
  unfold stringTake
  simp only [String.length_ofList, List.length_take, String.length_toList]
  omega

-- Truncate a string to max bytes, return (result, wasTruncated).
def truncateString (maxBytes : Nat) (s : String) : String × Bool :=
  if s.length > maxBytes then
    (stringTake s maxBytes ++ "...", true)
  else
    (s, false)

-- ============================================
-- Execution Interface
-- ============================================

def makeResult (cmd : String) (code : Nat) (out : String) (err : String)
    (dur : Nat) : ExecResult :=
  let (tOut, t1) := truncateString ExecResultBounded out
  let (tErr, t2) := truncateString ExecResultBounded err
  { command := cmd
  , exitCode := code
  , stdout := tOut
  , stderr := tErr
  , duration := dur
  , truncated := t1 || t2
  }

-- ============================================
-- Context Minimization
-- ============================================

-- One-line summary for token-efficient reporting.
def resultSummary (r : ExecResult) : String :=
  if r.exitCode ≠ 0 then
    "ERR " ++ r.command ++ " code=" ++ toString r.exitCode ++ ": " ++ stringTake r.stdout 80
  else
    "OK " ++ r.command ++ " lines=" ++ toString (r.stdout.splitOn "\n").length ++ " duration=" ++ toString r.duration ++ "ms"

-- Maximum budget for command output in context per turn.
abbrev contextBudget : Nat := 1500

-- Check if result fits within context budget.
def resultFitsBudget (r : ExecResult) : Bool :=
  r.stdout.length + r.stderr.length ≤ contextBudget

-- Summarize result when over budget.
def resultSummarized (r : ExecResult) : String :=
  if resultFitsBudget r then
    r.stdout
  else
    "TRUNCATED[" ++ toString r.stdout.length ++ " chars]" ++ stringTake r.stdout 200 ++ "..."

-- ============================================
-- Formal Invariants
-- ============================================

-- Invariant 1: Exit code is always a natural number (non-negative).
theorem exitCode_valid : ∀ (r : ExecResult), r.exitCode ≥ 0 := by
  intro r
  cases r
  exact Nat.zero_le _

-- Invariant 2: Command string length is positive when non-empty.
--
-- Fixed: the original concluded `True`, i.e. asserted nothing.
theorem command_length_pos :
    ∀ (r : ExecResult), r.command.toList ≠ [] → r.command.length > 0 := by
  intro r h
  have h2 : r.command.toList.length > 0 := by
    cases hl : r.command.toList with
    | nil => exact absurd hl h
    | cons _ _ => simp
  simpa [String.length_toList] using h2

-- Invariant 2b: the harness reports back exactly the command it was given.
theorem makeResult_command (cmd : String) (code : Nat) (out err : String)
    (dur : Nat) : (makeResult cmd code out err dur).command = cmd := rfl

-- Invariant 3: Output is bounded by construction.
--
-- Fixed: the original statement quantified over *arbitrary* `ExecResult`
-- values, which is false — nothing stops a hand-built record from carrying
-- unbounded output.  The honest invariant is about results produced by the
-- harness entry point `makeResult`, which truncates.  Truncated output carries
-- the three-character "..." marker, hence the `+ 3`.
--
-- theorem output_bounded : ∀ (r : ExecResult),
--   r.stdout.length ≤ ExecResultBounded ∧ r.stderr.length ≤ ExecResultBounded := by
--   intro r
--   sorry

theorem truncateString_length_le (maxBytes : Nat) (s : String) :
    (truncateString maxBytes s).1.length ≤ maxBytes + 3 := by
  unfold truncateString
  split
  · rename_i h
    simp only [String.length_append]
    have h1 : (stringTake s maxBytes).length ≤ maxBytes := stringTake_length_le s maxBytes
    have h2 : "...".length = 3 := rfl
    omega
  · rename_i h
    simp only [Nat.not_lt] at h
    show s.length ≤ maxBytes + 3
    omega

theorem makeResult_output_bounded (cmd : String) (code : Nat) (out err : String)
    (dur : Nat) :
    (makeResult cmd code out err dur).stdout.length ≤ ExecResultBounded + 3 ∧
    (makeResult cmd code out err dur).stderr.length ≤ ExecResultBounded + 3 :=
  ⟨truncateString_length_le ExecResultBounded out,
   truncateString_length_le ExecResultBounded err⟩

-- ============================================
-- Example: Command Log
-- ============================================

structure CommandLogEntry where
  seqNum    : Nat
  command   : String
  result    : ExecResult
  verified  : Bool

abbrev CommandLog := List CommandLogEntry

def exampleLog : List CommandLogEntry :=
  [ { seqNum := 1, command := "ls /opt/baal-agent/workspace",
      result := makeResult "ls /opt/baal-agent/workspace" 0
        "MEMORY.md
Twin.lean
CommandExecution.lean" "" 5,
      verified := true },
    { seqNum := 2, command := "git status --short",
      result := makeResult "git status --short" 0 "M Twin.lean
A CommandExecution.lean" "" 3,
      verified := true }
  ]

end CommandExecution
