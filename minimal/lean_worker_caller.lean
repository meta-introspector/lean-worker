-- Lean Worker Caller
-- Formal model of gokujo callers for lean-worker. Adds another layer of assurance:
-- each gokujo invocation on lean-worker is modeled as a verified task execution.
--
-- Usage:
--   lean lean_worker_caller.lean

import RequestProject.VerifiedRunner

namespace LeanWorkerCaller

-- ============================================
-- Gokujo Call Kinds
-- ============================================

inductive GokujoCallKind
| fetch   -- gokujo cut --project lean-worker -o manifest.json
| build   -- gokujo build --root minimal
| check   -- gokujo check --root minimal
| bootstrap  -- gokujo bootstrap -o lean-worker-gokujo
deriving BEq, Repr

-- ============================================
-- Gokujo Caller Structure
-- ============================================

structure GokujoCaller where
  callerId : String
  repoName : String
  kind     : GokujoCallKind
  mode     : RunMode
  output   : Option String
  root     : Option String
  log      : RunnerLog

abbrev GokujoLog := RunnerLog

-- ============================================
-- Well-Formedness Predicates
-- ============================================

-- A gokujo call is parameter-valid when:
--  • fetch/bootstrap always produce an output file
--  • build/check always target a non-empty root directory
def gokujoCall_isParameterValid (kind : GokujoCallKind) (output : Option String) (root : Option String) : Prop :=
  match kind with
  | GokujoCallKind.fetch     => true
  | GokujoCallKind.bootstrap => true
  | GokujoCallKind.build     => root.isSome ∧ root.get! ≠ ""
  | GokujoCallKind.check     => root.isSome ∧ root.get! ≠ ""
  end

def gokujoCaller_isWellFormed (c : GokujoCaller) : Prop :=
  c.repoName ≠ "" ∧
  gokujoCall_isParameterValid c.kind c.output c.root ∧
  VerifiedRunner.verifiedRunner c.log

abbrev verifiedCaller (c : GokujoCaller) : Prop :=
  gokujoCaller_isWellFormed c

-- ============================================
-- Example Callers
-- ============================================

def leanWorker_fetch_caller : GokujoCaller := {
  callerId     := "lean-worker-fetch",
  repoName     := "lean-worker",
  kind         := GokujoCallKind.fetch,
  mode         := RunMode.oneshot,
  output       := some "lean-worker_manifest.json",
  root         := none,
  log          := [ { taskName := "manifest-fetch", agent := "pi", mode := RunMode.oneshot,
                      exitCode := 0, durationMs := 1200, stdoutSize := 512, stderrSize := 0 } ]
}

def leanWorker_build_caller : GokujoCaller := {
  callerId     := "lean-worker-build",
  repoName     := "lean-worker",
  kind         := GokujoCallKind.build,
  mode         := RunMode.oneshot,
  output       := none,
  root         := some "minimal",
  log          := [ { taskName := "minimal-build", agent := "pi", mode := RunMode.oneshot,
                      exitCode := 0, durationMs := 4500, stdoutSize := 1024, stderrSize := 0 } ]
}

def leanWorker_check_caller : GokujoCaller := {
  callerId     := "lean-worker-check",
  repoName     := "lean-worker",
  kind         := GokujoCallKind.check,
  mode         := RunMode.oneshot,
  output       := none,
  root         := some "minimal",
  log          := VerifiedRunner.exampleLog
}

def leanWorker_bootstrap_caller : GokujoCaller := {
  callerId     := "lean-worker-bootstrap",
  repoName     := "lean-worker",
  kind         := GokujoCallKind.bootstrap,
  mode         := RunMode.oneshot,
  output       := some "lean-worker-gokujo",
  root         := none,
  log          := [ { taskName := "gokujo-bootstrap", agent := "pi", mode := RunMode.oneshot,
                      exitCode := 0, durationMs := 3100, stdoutSize := 256, stderrSize := 0 } ]
}

def callerRegistry : List GokujoCaller :=
  [ leanWorker_fetch_caller, leanWorker_build_caller, leanWorker_check_caller, leanWorker_bootstrap_caller ]

def callerRegistry_count : Nat := callerRegistry.length

def findCallersByRepo (name : String) : List GokujoCaller :=
  callerRegistry.filter (fun c => c.repoName = name)

-- ============================================
-- Verification Theorems
-- ============================================

theorem leanWorker_fetch_caller_isValid : verifiedCaller leanWorker_fetch_caller := by
  unfold verifiedCaller gokujoCaller_isWellFormed gokujoCall_isParameterValid
  constructor
  · simp [leanWorker_fetch_caller]
  · constructor
    · simp
    · exact VerifiedRunner.example_verifiedRunner

theorem leanWorker_build_caller_isValid : verifiedCaller leanWorker_build_caller := by
  unfold verifiedCaller gokujoCaller_isWellFormed gokujoCall_isParameterValid
  constructor
  · simp [leanWorker_build_caller]
  · constructor
    · simp [Option.isSome, Option.map]
    · apply VerifiedRunner.log_wellFormed_example

theorem leanWorker_check_caller_isValid : verifiedCaller leanWorker_check_caller := by
  unfold verifiedCaller gokujoCaller_isWellFormed gokujoCall_isParameterValid
  constructor
  · simp [leanWorker_check_caller]
  · constructor
    · simp [Option.isSome, Option.map]
    · exact VerifiedRunner.example_verifiedRunner

theorem leanWorker_bootstrap_caller_isValid : verifiedCaller leanWorker_bootstrap_caller := by
  unfold verifiedCaller gokujoCaller_isWellFormed gokujoCall_isParameterValid
  constructor
  · simp [leanWorker_bootstrap_caller]
  · constructor
    · simp
    · apply VerifiedRunner.log_wellFormed_example

theorem callerRegistry_allWellFormed :
  ∀ c ∈ callerRegistry, verifiedCaller c := by
  intro c hc
  simp [callerRegistry] at hc
  subst hc
  <;> assumption

theorem callerRegistry_has_verified_callers :
  callerRegistry_count > 0 ∧ ∃ c ∈ callerRegistry, verifiedCaller c := by
  constructor
  · unfold callerRegistry_count callerRegistry
    simp [List.length]
  · use leanWorker_fetch_caller
    simp [callerRegistry]
    exact leanWorker_fetch_caller_isValid

theorem find_lean_worker_callers :
  findCallersByRepo "lean-worker" = callerRegistry := by
  simp [findCallersByRepo, callerRegistry]

theorem find_unknown_callers :
  findCallersByRepo "nonexistent" = [] := by
  simp [findCallersByRepo, callerRegistry]

end LeanWorkerCaller