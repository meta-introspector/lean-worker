/-!
# Product Catalog — lean-worker

This module catalogs all Lean products (modules) in the lean-worker project,
organized by function and dependency relationship.

Each product has:
- `name`: The Lean module name
- `path`: Source file path
- `category`: Functional category
- `description`: What it does
- `dependencies`: Required modules

Categories mirror the construction skill tree:
- S0 Raw Material: Core infrastructure
- S1 Tamahagane: Core modules
- S2 Shita-kitae: Specialized tools
- S3 Tsukuri-komi: Composition layers
- S4 Tsuchi-oki: Interface/adapters
- S5 Yaki-ire: Final products
- S6 Blade: Executable products
- S7 Tool: Agent tools
- S8 Assembly: Test & deployment
- S9 Swiss Army Knife: The complete system
-/

namespace Gokujo.Catalog

/-- A product entry in the catalog. -/
structure Product where
  name : String
  path : String
  category : String
  description : String
  dependencies : List String
  deriving Inhabited, Repr

/-- S0: Raw Material — core infrastructure products. -/
def rawMaterials : List Product :=
  [ { name := "Main", path := "Main.lean"
    , category := "S0-Raw"
    , description := "Entry point; bootstraps the entire system"
    , dependencies := [] }
  , { name := "GokujoMain", path := "GokujoMain.lean"
    , category := "S0-Raw"
    , description := "Gokujo main CLI entry point"
    , dependencies := ["Gokujo"] }
  ]

/-- S1: Tamahagane — core Lean modules that form the foundation. -/
def tamahagane : List Product :=
  [ { name := "Agent", path := "Agent.lean"
    , category := "S1-Tamahagane"
    , description := "Agent context and plugin generation (45 ZOS plugins)"
    , dependencies := [] }
  , { name := "APICapabilities", path := "APICapabilities.lean"
    , category := "S1-Tamahagane"
    , description := "API capabilities definition and plugin contexts"
    , dependencies := [] }
  , { name := "Twin", path := "Twin.lean"
    , category := "S1-Tamahagane"
    , description := "Twin protocol implementation"
    , dependencies := [] }
  , { name := "ExecutionTrace", path := "ExecutionTrace.lean"
    , category := "S1-Tamahagane"
    , description := "Execution tracing and provenance tracking"
    , dependencies := [] }
  , { name := "ToolProvenance", path := "ToolProvenance.lean"
    , category := "S1-Tamahagane"
    , description := "Tool provenance and audit trail"
    , dependencies := [] }
  , { name := "CreditUsage", path := "CreditUsage.lean"
    , category := "S1-Tamahagane"
    , description := "Credit usage tracking and accounting"
    , dependencies := [] }
  , { name := "CommandExecution", path := "CommandExecution.lean"
    , category := "S1-Tamahagane"
    , description := "Command execution infrastructure"
    , dependencies := [] }
  ]

/-- S2: Shita-kitae — specialized tools (folding/refinement). -/
def shitaKitae : List Product :=
  [ { name := "ProxyReport", path := "ProxyReport.lean"
    , category := "S2-ShitaKitae"
    , description := "Proxy report generation"
    , dependencies := ["Agent"] }
  , { name := "activity_profile", path := "activity_profile.lean"
    , category := "S2-ShitaKitae"
    , description := "Activity profiling tool"
    , dependencies := [] }
  , { name := "aristotle_manager", path := "aristotle_manager.lean"
    , category := "S2-ShitaKitae"
    , description := "Aristotle plugin manager"
    , dependencies := [] }
  , { name := "aristotle_tools", path := "aristotle_tools.lean"
    , category := "S2-ShitaKitae"
    , description := "Aristotle tooling"
    , dependencies := ["aristotle_manager"] }
  ]

/-- S3: Tsukuri-komi — composition layers. -/
def tsukuriKomi : List Product :=
  [ { name := "RequestProject", path := "RequestProject"
    , category := "S3-TsukuriKomi"
    , description := "Request project composition layer"
    , dependencies := ["Agent", "Twin", "ExecutionTrace"] }
  , { name := "RequestProject.Proxy", path := "Proxy"
    , category := "S3-TsukuriKomi"
    , description := "Proxy layer for request project"
    , dependencies := ["RequestProject"] }
  , { name := "RequestProject.Protocol", path := "Protocol"
    , category := "S3-TsukuriKomi"
    , description := "Protocol layer for request project"
    , dependencies := ["RequestProject"] }
  , { name := "RequestProject.PluginContexts", path := "RequestProject"
    , category := "S3-TsukuriKomi"
    , description := "Plugin contexts for request project"
    , dependencies := ["RequestProject"] }
  ]

/-- S4: Tsuchi-oki — interface/adapters. -/
def tsuchiOki : List Product :=
  [ { name := "AgentC", path := "AgentC/main.lean"
    , category := "S4-TsuchiOki"
    , description := "Agent C — plugin context generation (45 ZOS plugins)"
    , dependencies := ["Agent", "APICapabilities"] }
  , { name := "tests/run", path := "tests/run/main.lean"
    , category := "S4-TsuchiOki"
    , description := "Test suite runner"
    , dependencies := ["Gokujo"] }
  ]

/-- S5: Yaki-ire — final products (quenched/certified). -/
def yakiIre : List Product :=
  [ { name := "Gokujo", path := "Gokujo.lean"
    , category := "S5-YakiIre"
    , description := "The Swiss Army knife — main entry point, imports all modules"
    , dependencies := ["GokujoInfra", "GokujoTest", "GokujoExec", "GokujoCore"] }
  , { name := "GokujoCore", path := "GokujoCore.lean"
    , category := "S5-YakiIre"
    , description := "Construction skill tree — certified progression from raw material to Swiss Army knife"
    , dependencies := [] }
  , { name := "GokujoInfra", path := "GokujoInfra.lean"
    , category := "S5-YakiIre"
    , description := "Infrastructure generation — lakefile, flake.nix, CI, pipelight"
    , dependencies := [] }
  , { name := "GokujoTest", path := "GokujoTest.lean"
    , category := "S5-YakiIre"
    , description := "Test infrastructure validation"
    , dependencies := [] }
  , { name := "GokujoExec", path := "GokujoExec.lean"
    , category := "S5-YakiIre"
    , description := "Agent workflow execution"
    , dependencies := [] }
  ]

/-- S6: Blade — executable products. -/
def blade : List Product :=
  [ { name := "lean-worker", path := "lean-worker"
    , category := "S6-Blade"
    , description := "Compiled executable from gokujo bootstrap"
    , dependencies := ["Gokujo"] }
  ]

/-- S7: Tool — agent tools. -/
def tool : List Product :=
  [ { name := "AgentC", path := "AgentC/main.lean"
    , category := "S7-Tool"
    , description := "Agent C — plugin context generation"
    , dependencies := ["Agent", "APICapabilities"] }
  , { name := "tests/run", path := "tests/run/main.lean"
    , category := "S7-Tool"
    , description := "Test suite runner"
    , dependencies := ["Gokujo"] }
  ]

/-- S8: Assembly — test and deployment products. -/
def assembly : List Product :=
  [ { name := "tests/run", path := "tests/run"
    , category := "S8-Assembly"
    , description := "Test suite: scanPaths + buildAll verification"
    , dependencies := ["Gokujo"] }
  , { name := "Makefile", path := "Makefile"
    , category := "S8-Assembly"
    , description := "Build targets for infra, test, clean"
    , dependencies := ["Gokujo"] }
  , { name := "README.md", path := "README.md"
    , category := "S8-Assembly"
    , description := "Project documentation"
    , dependencies := ["Gokujo"] }
  ]

/-- S9: Swiss Army Knife — the complete system. -/
def swissArmyKnife : List Product :=
  [ { name := "Gokujo.lean", path := "Gokujo.lean"
    , category := "S9-SwissArmyKnife"
    , description := "The complete Swiss Army knife — single-file bootstrap"
    , dependencies := ["GokujoInfra", "GokujoTest", "GokujoExec", "GokujoCore"] }
  ]

/-- The full catalog, organized by skill tree level. -/
def fullCatalog : List (String × List Product) :=
  [ ("S0 Raw Material", rawMaterials)
  , ("S1 Tamahagane", tamahagane)
  , ("S2 Shita-kitae", shitaKitae)
  , ("S3 Tsukuri-komi", tsukuriKomi)
  , ("S4 Tsuchi-oki", tsuchiOki)
  , ("S5 Yaki-ire", yakiIre)
  , ("S6 Blade", blade)
  , ("S7 Tool", tool)
  , ("S8 Assembly", assembly)
  , ("S9 Swiss Army Knife", swissArmyKnife)
  ]

/-- Get all products as a flat list. -/
def allProducts : List Product :=
  fullCatalog.flatMap (·.2)

/-- Count products by category. -/
def countByCategory : Nat :=
  fullCatalog.length

/-- The total number of distinct products. -/
def totalProducts : Nat :=
  allProducts.length

end Gokujo.Catalog
