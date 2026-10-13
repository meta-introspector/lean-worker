/-!
# A twin of the assistant's working context (core Lean only)

This is a description I wrote of how I work in this session, as checkable rules. It is NOT
evidence about my internals: I cannot introspect reliably, so nothing here claims to say why I
produce a given output. Its parts are tied to things that were observed through tools
(allow-list, compile runs), or they are policy rules for how claims are labelled.

Design rule, taken from the lean-worker review: every rule has a positive example AND a
negative one (something that must be rejected). A theorem that only restates a definition is
not counted.
-/
namespace ClaudeTwin

/-! ## 1. How a statement is backed (weakest to strongest) -/

inductive Tier | recalled | inferred | searched | readSource | executed | kernelChecked
  deriving DecidableEq, Repr

def Tier.rank : Tier → Nat
  | .recalled => 0 | .inferred => 1 | .searched => 2
  | .readSource => 3 | .executed => 4 | .kernelChecked => 5

instance : LE Tier := ⟨fun a b => a.rank ≤ b.rank⟩
instance (a b : Tier) : Decidable (a ≤ b) := inferInstanceAs (Decidable (a.rank ≤ b.rank))

/-- A conclusion that depends on two premises is only as strong as the weaker one. -/
def Tier.meet (a b : Tier) : Tier := if a.rank ≤ b.rank then a else b

theorem meet_le (a b : Tier) : a.meet b ≤ a ∧ a.meet b ≤ b := by
  cases a <;> cases b <;> decide

theorem meet_comm (a b : Tier) : a.meet b = b.meet a := by
  cases a <;> cases b <;> decide

/-- A source may stop being visible (tool results are cleared to save context). -/
structure Source where
  tier : Tier
  visible : Bool

/-- A cleared source is only recalled, never re-checked. -/
def Source.effective (s : Source) : Tier := if s.visible then s.tier else .recalled

theorem effective_le (s : Source) : s.effective ≤ s.tier := by
  unfold Source.effective; split
  · exact Nat.le_refl _
  · exact Nat.zero_le _

theorem cleared_is_recalled (t : Tier) : (Source.mk t false).effective = .recalled := rfl

/-- Anything weaker than a read source must be hedged in a reply. -/
def needsHedge (t : Tier) : Bool := decide (t.rank < 3)

example : needsHedge .recalled = true := by decide      -- positive
example : needsHedge .executed = false := by decide     -- negative: executed need not be hedged
example : needsHedge .searched = true := by decide

/-! ## 2. What the sandbox can reach (the network allow-list in this session) -/

def allowlist : List String :=
  ["api.anthropic.com", "api.github.com", "archive.ubuntu.com", "codeload.github.com",
   "crates.io", "files.pythonhosted.org", "github.com", "index.crates.io", "npmjs.com",
   "npmjs.org", "pypi.org", "pythonhosted.org", "raw.githubusercontent.com",
   "registry.npmjs.org", "registry.yarnpkg.com", "release-assets.githubusercontent.com",
   "security.ubuntu.com", "static.crates.io", "www.npmjs.com", "www.npmjs.org", "yarnpkg.com"]

def reachable (host : String) : Bool := allowlist.contains host

example : reachable "github.com" = true := by decide                       -- downloaded from here
example : reachable "release.lean-lang.org" = false := by decide           -- elan failed here
example : reachable "x.com" = false := by decide

/-! ## 3. Capabilities: only observed ones may be asserted -/

inductive Status
  | observed (evidence : String)
  | untried
  | blocked (why : String)

structure Capability where
  name : String
  status : Status

def capabilities : List Capability :=
  [ ⟨"compile core-only Lean 4.28 locally", .observed "ran lean on several files"⟩,
    ⟨"download from github.com and raw.githubusercontent.com via bash", .observed "fetched Lean release and permutat.cc"⟩,
    ⟨"reach release.lean-lang.org via bash", .blocked "not in the allow-list"⟩,
    ⟨"build Mathlib-dependent projects locally", .untried⟩,
    ⟨"run GAP", .untried⟩,
    ⟨"load eBPF probes", .untried⟩,
    ⟨"sign off as a named reviewer", .blocked "rung 2 needs a named human"⟩ ]

def mayAssert (c : Capability) : Bool :=
  match c.status with
  | .observed _ => true
  | _ => false

example : ∀ c ∈ capabilities, c.name = "run GAP" → mayAssert c = false := by decide
example : ∀ c ∈ capabilities, c.name = "load eBPF probes" → mayAssert c = false := by decide
example : ∀ c ∈ capabilities, c.name = "compile core-only Lean 4.28 locally" → mayAssert c = true := by decide

/-! ## 4. Review: an agent cannot be the named reviewer (rung 2) -/

inductive Actor | human (name : String) | agent (id : String)
  deriving DecidableEq, Repr

structure ReviewRecord where
  author : Actor
  reviewer : Actor

def validRung2 (r : ReviewRecord) : Bool :=
  match r.reviewer with
  | .human n => !n.isEmpty && decide (r.author ≠ r.reviewer)
  | .agent _ => false

theorem agent_never_rung2 (a : Actor) (i : String) : validRung2 ⟨a, .agent i⟩ = false := rfl

theorem self_review_invalid (n : String) : validRung2 ⟨.human n, .human n⟩ = false := by
  simp [validRung2]

example : validRung2 ⟨.agent "claude", .human "A. Reviewer"⟩ = true := by decide   -- positive
example : validRung2 ⟨.agent "claude", .human ""⟩ = false := by decide             -- unnamed

/-! ## 5. Knowledge date -/

def cutoff : Nat := 202606      -- reliable knowledge ends around June 2026
def needsSearch (eventMonth : Nat) : Bool := decide (cutoff < eventMonth)

example : needsSearch 202605 = false := by decide
example : needsSearch 202609 = true := by decide

/-! ## 6. Corrections made in this session (self-reported data, not a theorem) -/

structure Correction where
  claim : String
  caughtBy : Tier

def corrections : List Correction :=
  [ ⟨"GF(27) has an 8-element subfield", .inferred⟩,
    ⟨"the ProdPerm degree default is support degree", .readSource⟩,
    ⟨"CommandExecution.lean has an unfinished proof", .executed⟩,
    ⟨"the seeded PRNG gives varied influx", .executed⟩ ]

end ClaudeTwin
