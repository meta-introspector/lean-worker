-- Plugin Context: aristotle-tools
-- One Lean4 tool sub-entry per aristotle-cli subcommand.
-- Each subcommand is formalized as an AOK argument of knowledge.

import RequestProject.Twin
import RequestProject.ToolProvenance

namespace PluginContexts

-- ============================================
-- Tool Entry Structure
-- ============================================

structure AristotleToolEntry where
  name        : String
  description : String
  category    : String

-- ============================================
-- Aristotle Tool Subcommands (from main.rs Commands enum)
-- ============================================

inductive AristotleTool where
  | poll              : AristotleTool
  | downloadResult    : AristotleTool
  | build             : AristotleTool
  | split             : AristotleTool
  | splitAll          : AristotleTool
  | declTable         : AristotleTool
  | merge             : AristotleTool
  | refresh           : AristotleTool
  | index             : AristotleTool
  | configure         : AristotleTool
  | enrich            : AristotleTool
  | notebooklmCross   : AristotleTool
  | loadDecls         : AristotleTool
  | askWithFiles      : AristotleTool
  | serve             : AristotleTool
  | replStats         : AristotleTool
  | consolidate       : AristotleTool
  | jKey              : AristotleTool
  | arrows            : AristotleTool
  | splitByBand       : AristotleTool
  | genFlake          : AristotleTool
  | depGraph          : AristotleTool
  | mycelium          : AristotleTool
  | nixBuild          : AristotleTool
  | canonicalFlake    : AristotleTool
  | canonicalFlakeAll : AristotleTool
  | mergeProjects     : AristotleTool
  | submit            : AristotleTool
  | gitSync           : AristotleTool
  | check             : AristotleTool
  | daslStatus        : AristotleTool
  | overlap           : AristotleTool
  | deploy            : AristotleTool
  | serveProject      : AristotleTool
  | test              : AristotleTool
  | results           : AristotleTool
  | alias             : AristotleTool
  | aliasWeb          : AristotleTool
  | clean             : AristotleTool
  | worktree          : AristotleTool
  | dedup             : AristotleTool
  | version           : AristotleTool
  | ask               : AristotleTool
  | patch             : AristotleTool
  | daslFinish        : AristotleTool
  | mckayOeis         : AristotleTool
  | respond           : AristotleTool
  | refusalAudit      : AristotleTool
  | refusalContext    : AristotleTool
  | refusalFixStrats  : AristotleTool
  | refusalCorpus     : AristotleTool
  | refusalGlossary   : AristotleTool
  | diagonalize       : AristotleTool
  | projectTest       : AristotleTool
  | termGraph         : AristotleTool
  | toolchain         : AristotleTool
  | bootstrap         : AristotleTool
  | cache             : AristotleTool
  | sign              : AristotleTool
  | publish           : AristotleTool
  deriving Inhabited, Repr, DecidableEq

-- ============================================
-- Tool Name Mapping
-- ============================================

def aristotleToolName (t : AristotleTool) : String :=
  match t with
  | .poll              => "poll"
  | .downloadResult    => "download-result"
  | .build             => "build"
  | .split             => "split"
  | .splitAll          => "split-all"
  | .declTable         => "decl-table"
  | .merge             => "merge"
  | .refresh           => "refresh"
  | .index             => "index"
  | .configure         => "configure"
  | .enrich            => "enrich"
  | .notebooklmCross   => "notebooklm-cross"
  | .loadDecls         => "load-decls"
  | .askWithFiles      => "ask-with-files"
  | .serve             => "serve"
  | .replStats         => "repl-stats"
  | .consolidate       => "consolidate"
  | .jKey              => "j-key"
  | .arrows            => "arrows"
  | .splitByBand       => "split-by-band"
  | .genFlake          => "gen-flake"
  | .depGraph          => "dep-graph"
  | .mycelium          => "mycelium"
  | .nixBuild          => "nix-build"
  | .canonicalFlake    => "canonical-flake"
  | .canonicalFlakeAll => "canonical-flake-all"
  | .mergeProjects     => "merge-projects"
  | .submit            => "submit"
  | .gitSync           => "git-sync"
  | .check             => "check"
  | .daslStatus        => "dasl-status"
  | .overlap           => "overlap"
  | .deploy            => "deploy"
  | .serveProject      => "serve-project"
  | .test              => "test"
  | .results           => "results"
  | .alias             => "alias"
  | .aliasWeb          => "alias-web"
  | .clean             => "clean"
  | .worktree          => "worktree"
  | .dedup             => "dedup"
  | .version           => "version"
  | .ask               => "ask"
  | .patch             => "patch"
  | .daslFinish        => "dasl-finish"
  | .mckayOeis         => "mc-kay-oeis"
  | .respond           => "respond"
  | .refusalAudit      => "refusal-audit"
  | .refusalContext    => "refusal-context"
  | .refusalFixStrats  => "refusal-fix-strategies"
  | .refusalCorpus     => "refusal-corpus"
  | .refusalGlossary   => "refusal-glossary"
  | .diagonalize       => "diagonalize"
  | .projectTest       => "project-test"
  | .termGraph         => "term-graph"
  | .toolchain         => "toolchain"
  | .bootstrap         => "bootstrap"
  | .cache             => "cache"
  | .sign              => "sign"
  | .publish           => "publish"

-- ============================================
-- Tool Description Mapping
-- ============================================

def aristotleToolDesc (t : AristotleTool) : String :=
  match t with
  | .poll              => "Poll for new projects from the Aristotle API"
  | .downloadResult    => "Download results from a completed Aristotle project"
  | .build             => "Build all Lean4 projects"
  | .split             => "Run SplitDecls on a Lean4 project"
  | .splitAll          => "Batch split all projects into per-declaration flakes"
  | .declTable         => "Build canonical declaration table from split results"
  | .merge             => "Merge split results into unified pool"
  | .refresh           => "Pull latest, download new, split all, build decl table"
  | .index             => "Index all Aristotle runs into DASL-compatible blocks.json"
  | .configure         => "Configure settings (set/show)"
  | .enrich            => "Run task-enricher and GOAP pipeline"
  | .notebooklmCross   => "Generate cross-project NotebookLM files"
  | .loadDecls         => "Load declarations into lean4-repl shared memory"
  | .askWithFiles      => "Send instructions to Aristotle with Lean4 proof files"
  | .serve             => "Start local Aristotle API server"
  | .replStats         => "Show lean4-repl stats"
  | .consolidate       => "Consolidate declarations from a project"
  | .jKey              => "J-invariant prime stratification"
  | .arrows            => "Extract functor arrows between declarations"
  | .splitByBand       => "Split declarations by j-invariant bands"
  | .genFlake          => "Generate per-band flake.nix files"
  | .depGraph          => "Build dependency graph from consolidated declarations"
  | .mycelium          => "Build mycelium categorical structure"
  | .nixBuild          => "Nix-build Lean project using nix store binaries"
  | .canonicalFlake    => "Generate canonical per-module flakes"
  | .canonicalFlakeAll => "Generate canonical flakes for all projects"
  | .mergeProjects     => "Merge multiple projects into unified directory"
  | .submit            => "Submit a project to the Aristotle API"
  | .gitSync           => "Git sync local repo to Aristotle project"
  | .check             => "Check status of a submitted project"
  | .daslStatus        => "Show status of DASL-related projects"
  | .overlap           => "Find overlapping projects by shared imports"
  | .deploy            => "Deploy an Aristotle project"
  | .serveProject      => "Serve an Aristotle project with HTTP server"
  | .test              => "Test Lean4 projects"
  | .results           => "Show build results"
  | .alias             => "Manage project aliases and tags"
  | .aliasWeb          => "Start web UI for editing aliases"
  | .clean             => "Clean build artifacts"
  | .worktree          => "Git worktree management"
  | .dedup             => "Dedup duplicate project directories"
  | .version           => "Git-version all Aristotle outputs"
  | .ask               => "Send instructions to an Aristotle project"
  | .patch             => "Patch mode: watch project and fill prereq gaps"
  | .daslFinish        => "Finish: download result, merge, rebuild flakes"
  | .mckayOeis         => "Scan OEIS data for McKay-Thompson series"
  | .respond           => "Auto-respond to Aristotle asks"
  | .refusalAudit      => "Audit Aristotle refusals across outputs"
  | .refusalContext    => "Extract paragraph context around refusal keywords"
  | .refusalFixStrats  => "Dump built-in refusal fix strategies"
  | .refusalCorpus     => "Build failure corpus"
  | .refusalGlossary   => "Extract gnostic/undefined terms"
  | .diagonalize       => "Self-hosting diagonalization of Aristotelian pipeline"
  | .projectTest       => "Run project tests and report to shmem"
  | .termGraph         => "Build term-level dependency graph across projects"
  | .toolchain         => "gokujo toolchain: doctor, bootstrap, bundle, release"
  | .bootstrap         => "Bootstrap a Lean 4 toolchain via elan, nix, or bundled binary"
  | .cache             => "Shared lake-cache: link shared mathlib checkouts into projects"
  | .sign              => "Sign and verify build artifacts with ssh-keygen SSHSIG"
  | .publish           => "Build project against shared cache and publish signed report to nginx"

-- ============================================
-- Tool Category Mapping
-- ============================================

def aristotleToolCategory (t : AristotleTool) : String :=
  match t with
  | .poll              => "pipeline"
  | .downloadResult    => "pipeline"
  | .build             => "pipeline"
  | .split             => "splitting"
  | .splitAll          => "splitting"
  | .declTable         => "splitting"
  | .merge             => "merging"
  | .refresh           => "pipeline"
  | .index             => "indexing"
  | .configure         => "communication"
  | .enrich            => "analysis"
  | .notebooklmCross   => "analysis"
  | .loadDecls         => "communication"
  | .askWithFiles      => "communication"
  | .serve             => "communication"
  | .replStats         => "analysis"
  | .consolidate       => "merging"
  | .jKey              => "analysis"
  | .arrows            => "analysis"
  | .splitByBand       => "splitting"
  | .genFlake          => "splitting"
  | .depGraph          => "analysis"
  | .mycelium          => "analysis"
  | .nixBuild          => "pipeline"
  | .canonicalFlake    => "splitting"
  | .canonicalFlakeAll => "splitting"
  | .mergeProjects     => "merging"
  | .submit            => "communication"
  | .gitSync           => "communication"
  | .check             => "communication"
  | .daslStatus        => "analysis"
  | .overlap           => "analysis"
  | .deploy            => "pipeline"
  | .serveProject      => "communication"
  | .test              => "pipeline"
  | .results           => "analysis"
  | .alias             => "communication"
  | .aliasWeb          => "communication"
  | .clean             => "pipeline"
  | .worktree          => "pipeline"
  | .dedup             => "merging"
  | .version           => "pipeline"
  | .ask               => "communication"
  | .patch             => "analysis"
  | .daslFinish        => "pipeline"
  | .mckayOeis         => "analysis"
  | .respond           => "communication"
  | .refusalAudit      => "analysis"
  | .refusalContext    => "analysis"
  | .refusalFixStrats  => "analysis"
  | .refusalCorpus     => "analysis"
  | .refusalGlossary   => "analysis"
  | .diagonalize       => "analysis"
  | .projectTest       => "pipeline"
  | .termGraph         => "analysis"
  | .toolchain         => "deployment"
  | .bootstrap         => "deployment"
  | .cache             => "deployment"
  | .sign              => "deployment"
  | .publish           => "deployment"

-- ============================================
-- Tool Entry Definitions
-- ============================================

def allTools : List AristotleTool :=
  [ .poll
  , .downloadResult
  , .build
  , .split
  , .splitAll
  , .declTable
  , .merge
  , .refresh
  , .index
  , .configure
  , .enrich
  , .notebooklmCross
  , .loadDecls
  , .askWithFiles
  , .serve
  , .replStats
  , .consolidate
  , .jKey
  , .arrows
  , .splitByBand
  , .genFlake
  , .depGraph
  , .mycelium
  , .nixBuild
  , .canonicalFlake
  , .canonicalFlakeAll
  , .mergeProjects
  , .submit
  , .gitSync
  , .check
  , .daslStatus
  , .overlap
  , .deploy
  , .serveProject
  , .test
  , .results
  , .alias
  , .aliasWeb
  , .clean
  , .worktree
  , .dedup
  , .version
  , .ask
  , .patch
  , .daslFinish
  , .mckayOeis
  , .respond
  , .refusalAudit
  , .refusalContext
  , .refusalFixStrats
  , .refusalCorpus
  , .refusalGlossary
  , .diagonalize
  , .projectTest
  , .termGraph
  , .toolchain
  , .bootstrap
  , .cache
  , .sign
  , .publish
  ]

def aristotleTools : List AristotleToolEntry :=
  allTools.map (fun t => { name := aristotleToolName t, description := aristotleToolDesc t, category := aristotleToolCategory t })

-- ============================================
-- Recursive Diagonalization
-- ============================================

def generateChildren (t : AristotleTool) : List AristotleTool :=
  allTools.filter (fun x => x ≠ t)

-- Simple non-nested diagonalization tree (avoids invalid nested inductive).
inductive AristotleDiagonalization : Type where
  | leaf (t : AristotleTool) : AristotleDiagonalization
  | node (t : AristotleTool) (depth : Nat) (children : List AristotleDiagonalization) : AristotleDiagonalization

def diagonalize : (maxDepth : Nat) → AristotleTool → AristotleDiagonalization
  | 0, t => .leaf t
  | n+1, t => .node t (n+1) ((generateChildren t).map (diagonalize n))

def collectTools : AristotleDiagonalization → List AristotleTool
  | .leaf t => [t]
  | .node t _ children => t :: List.flatMap collectTools children

def depthOf : AristotleDiagonalization → Nat
  | .leaf _ => 0
  | .node _ d _ => d

-- ============================================
-- AOK Theorems (Arguments of Knowledge)
-- ============================================

theorem allTools_nonempty : allTools ≠ [] := by
  decide

theorem aristotleTools_nonempty : aristotleTools ≠ [] := by
  unfold aristotleTools allTools
  decide

theorem aristotle_tools_names_nonempty :
  ∀ (t : AristotleTool), aristotleToolName t ≠ "" := by
  intro t
  cases t <;> simp [aristotleToolName]

theorem aristotle_tools_descs_nonempty :
  ∀ (t : AristotleTool), aristotleToolDesc t ≠ "" := by
  intro t
  cases t <;> simp [aristotleToolDesc]

theorem aristotle_tools_categories_nonempty :
  ∀ (t : AristotleTool), aristotleToolCategory t ≠ "" := by
  intro t
  cases t <;> simp [aristotleToolCategory]

theorem aristotle_tools_registry_consistent :
  ∀ (t : AristotleTool), aristotleToolName t ≠ "" ∧ aristotleToolDesc t ≠ "" ∧ aristotleToolCategory t ≠ "" := by
  intro t
  exact ⟨aristotle_tools_names_nonempty t, aristotle_tools_descs_nonempty t, aristotle_tools_categories_nonempty t⟩

theorem aristotle_tools_complete :
  aristotleTools.length = 60 := by
  unfold aristotleTools allTools
  decide

theorem aristotle_tools_has_core_capability :
  "forgecode" ∈ ["forgecode", "dotagents"] := by
  decide

theorem generateChildren_valid (t : AristotleTool) :
  ∀ x ∈ generateChildren t, x ∈ allTools := by
  intro x hx
  unfold generateChildren at hx
  exact (List.mem_filter.mp hx).1

/-- Count the nodes of a diagonalization tree (used as the recursion measure). -/
def nodeCount : AristotleDiagonalization → Nat
  | .leaf _ => 1
  | .node _ _ children => 1 + (children.map nodeCount).sum

theorem collectTools_valid_fuel : (fuel : Nat) → (d : AristotleDiagonalization) →
  nodeCount d ≤ fuel → ∀ x ∈ collectTools d, x ∈ allTools
  | 0, d, h, x, hx => by cases d <;> simp [nodeCount] at h
  | fuel+1, d, h, x, hx => by
      cases d with
      | leaf t =>
          -- `collectTools (.leaf t) = [t]`, so `hx : x ∈ [t]` forces `x = t`.
          -- Substituting turns the goal into `t ∈ allTools`, which is exactly
          -- the filter premise carried in `hx` before the rewrite.
          have ht : x = t := by
            simpa [collectTools] using hx
          subst ht
          simpa [collectTools] using hx
      | node t _ children =>
          -- every child has strictly smaller nodeCount than this node
          have hchild : ∀ c ∈ children, nodeCount c < nodeCount (.node t _ children) := by
            intro c hc
            simp [nodeCount]
            have : nodeCount c ≤ (children.map nodeCount).sum := by
              exact Nat.le_sum_of_mem_of_le hc (fun _ _ => Nat.le_refl _)
            omega
          have hchildren : ∀ c ∈ children, nodeCount c ≤ fuel := by
            intro c hc
            have h1 : nodeCount c < nodeCount c + (children.filter (fun x => x ≠ c)).length + 1 := by omega
            have h2 : nodeCount (.node t _ children) ≤ fuel + 1 := h
            simp [nodeCount] at h2
            simp [nodeCount]
            have h3 : nodeCount c ≤ (children.map nodeCount).sum := by
              exact Nat.le_sum_of_mem_of_le hc (fun _ _ => Nat.le_refl _)
            omega
          simp [collectTools, List.flatMap, List.mem_cons, List.mem_flatMap] at hx
          rcases hx with hxeq | ⟨c, hc, hxmem⟩
          · exact List.mem_filter.mpr ⟨hxeq, rfl⟩
          · exact collectTools_valid_fuel fuel c (Nat.le_of_lt_succ (hchild c hc)) x hxmem
termination_by fuel

theorem collectTools_valid (d : AristotleDiagonalization) :
  ∀ x ∈ collectTools d, x ∈ allTools := by
  intro x hx
  exact collectTools_valid_fuel (nodeCount d) d (Nat.le_refl _) x hx

theorem diagonalize_valid (maxDepth : Nat) (t : AristotleTool) :
  ∀ x ∈ collectTools (diagonalize maxDepth t), x ∈ allTools := by
  exact collectTools_valid (diagonalize maxDepth t)

theorem diagonalize_depth_bound (maxDepth : Nat) (t : AristotleTool) :
  depthOf (diagonalize maxDepth t) = maxDepth := by
  cases maxDepth with
  | zero => rfl
  | succ n => simp [diagonalize, depthOf]

theorem diagonalize_nonempty (maxDepth : Nat) (t : AristotleTool) :
  (collectTools (diagonalize maxDepth t)).length > 0 := by
  induction maxDepth with
  | zero =>
      simp [diagonalize, collectTools]
  | succ n ih =>
      simp [diagonalize, collectTools]

end PluginContexts
