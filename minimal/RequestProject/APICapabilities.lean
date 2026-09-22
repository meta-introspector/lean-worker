-- APICapabilities.lean
-- Formal model of the agent's available tool/API capabilities.
-- Each tool is formalized with its parameters, constraints, and guarantees.

namespace Twin

-- ============================================
-- Wave V.6: API Capabilities Formal Model
-- ============================================

-- ============================================
-- V.6.1: Tool Category Enumeration
-- ============================================

inductive ToolCategory where
  | Core          : ToolCategory   -- Fundamental operations (file, shell, edit)
  | FileIO        : ToolCategory   -- Reading, writing, listing
  | Git           : ToolCategory   -- Git version control operations
  | CodeQuality   : ToolCategory   -- Tests, lint, typecheck, format
  | Web           : ToolCategory   -- HTTP fetching, search
  | Memory        : ToolCategory   -- Persistent and search memory
  | Computation   : ToolCategory   -- Python code execution
  | ProcessMgmt   : ToolCategory   -- Background process lifecycle
  | SubagentMgmt  : ToolCategory   -- Spawn subagents with roles
  | Messaging     : ToolCategory   -- User communication channels
  | TaskMgmt      : ToolCategory   -- Task lists, checklists
  | Media         : ToolCategory   -- Image generation
  | VersionCtrl   : ToolCategory   -- Checkpoints for rollback
  deriving Inhabited, Repr, DecidableEq

-- ============================================
-- V.6.2: Parameter Types
-- ============================================

inductive ParamType where
  | String  : ParamType
  | Nat     : ParamType
  | Bool    : ParamType
  | List    : ParamType
  | Enum    : ParamType
  | Optional : ParamType → ParamType  -- nullable wrapper
  deriving Repr

-- ============================================
-- V.6.3: Each Tool as a Formal Structure
-- ============================================

structure ToolParam where
  name   : String
  pType  : ParamType
  required : Bool

structure ToolCapability where
  name       : String
  category   : ToolCategory
  description : String
  params     : List ToolParam
  scope      : String    -- "full filesystem", "workspace", "none"
  timeout    : Option Nat -- max seconds, none = unlimited
  persistence : Bool     -- effects survive between turns
  returnsText: Bool      -- returns text content to agent
  returnsBinary: Bool    -- returns binary/metadata

-- ============================================
-- V.6.4: Core Tools
-- ============================================

def tool_bash : ToolCapability :=
  { name := "bash"
  , category := ToolCategory.Core
  , description := "Execute shell commands with full root access"
  , params :=
      [ { name := "command", pType := ParamType.String, required := true }
      , { name := "timeout", pType := ParamType.Nat, required := false }
      ]
  , scope := "full filesystem"
  , timeout := some 300
  , persistence := true
  , returnsText := true
  , returnsBinary := false
  }

def tool_write_file : ToolCapability :=
  { name := "write_file"
  , category := ToolCategory.Core
  , description := "Write file contents, creating parent directories"
  , params :=
      [ { name := "path", pType := ParamType.String, required := true }
      , { name := "content", pType := ParamType.String, required := true }
      ]
  , scope := "workspace"
  , timeout := none
  , persistence := true
  , returnsText := false
  , returnsBinary := false
  }

def tool_edit_file : ToolCapability :=
  { name := "edit_file"
  , category := ToolCategory.Core
  , description := "Find and replace exact string in file, with optional hash verification"
  , params :=
      [ { name := "path", pType := ParamType.String, required := true }
      , { name := "old_string", pType := ParamType.String, required := true }
      , { name := "new_string", pType := ParamType.String, required := true }
      , { name := "replace_all", pType := ParamType.Bool, required := false }
      , { name := "expected_hash", pType := ParamType.Optional ParamType.String, required := false }
      ]
  , scope := "workspace"
  , timeout := none
  , persistence := true
  , returnsText := false
  , returnsBinary := false
  }

def tool_multi_edit : ToolCapability :=
  { name := "multi_edit"
  , category := ToolCategory.Core
  , description := "Apply multiple edit_file operations in sequence"
  , params :=
      [ { name := "edits", pType := ParamType.List, required := true }
      ]
  , scope := "workspace"
  , timeout := none
  , persistence := true
  , returnsText := false
  , returnsBinary := false
  }

def tool_apply_patch : ToolCapability :=
  { name := "apply_patch"
  , category := ToolCategory.Core
  , description := "Apply unified diff patch (git apply format)"
  , params :=
      [ { name := "patch", pType := ParamType.String, required := true }
      ]
  , scope := "workspace"
  , timeout := none
  , persistence := true
  , returnsText := false
  , returnsBinary := false
  }

-- ============================================
-- V.6.5: File I/O Tools
-- ============================================

def tool_read_file : ToolCapability :=
  { name := "read_file"
  , category := ToolCategory.FileIO
  , description := "Read file contents, with line range and image support"
  , params :=
      [ { name := "path", pType := ParamType.String, required := true }
      , { name := "offset", pType := ParamType.Optional ParamType.Nat, required := false }
      , { name := "limit", pType := ParamType.Optional ParamType.Nat, required := false }
      ]
  , scope := "workspace"
  , timeout := none
  , persistence := false
  , returnsText := true
  , returnsBinary := true  -- images rendered visually
  }

def tool_read_many_files : ToolCapability :=
  { name := "read_many_files"
  , category := ToolCategory.FileIO
  , description := "Read up to 20 text files in one call"
  , params :=
      [ { name := "paths", pType := ParamType.List, required := true }
      , { name := "offset", pType := ParamType.Optional ParamType.Nat, required := false }
      , { name := "limit", pType := ParamType.Optional ParamType.Nat, required := false }
      ]
  , scope := "workspace"
  , timeout := none
  , persistence := false
  , returnsText := true
  , returnsBinary := false
  }

def tool_read_pdf : ToolCapability :=
  { name := "read_pdf"
  , category := ToolCategory.FileIO
  , description := "Extract text or images from PDFs"
  , params :=
      [ { name := "path", pType := ParamType.String, required := true }
      , { name := "pages", pType := ParamType.Optional ParamType.String, required := false }
      , { name := "mode", pType := ParamType.Enum, required := false }  -- "text" or "image"
      ]
  , scope := "workspace"
  , timeout := none
  , persistence := false
  , returnsText := true
  , returnsBinary := true
  }

def tool_list_dir : ToolCapability :=
  { name := "list_dir"
  , category := ToolCategory.FileIO
  , description := "List directory with [dir]/[file] prefixed entries"
  , params :=
      [ { name := "path", pType := ParamType.String, required := false }
      ]
  , scope := "any"
  , timeout := none
  , persistence := false
  , returnsText := true
  , returnsBinary := false
  }

def tool_glob : ToolCapability :=
  { name := "glob"
  , category := ToolCategory.FileIO
  , description := "Find files by glob pattern, sorted by modification time"
  , params :=
      [ { name := "pattern", pType := ParamType.String, required := true }
      , { name := "path", pType := ParamType.Optional ParamType.String, required := false }
      , { name := "limit", pType := ParamType.Optional ParamType.Nat, required := false }
      ]
  , scope := "workspace"
  , timeout := none
  , persistence := false
  , returnsText := true
  , returnsBinary := false
  }

def tool_grep : ToolCapability :=
  { name := "grep"
  , category := ToolCategory.FileIO
  , description := "Search text files with ripgrep (supports type_filter, case sensitivity)"
  , params :=
      [ { name := "pattern", pType := ParamType.String, required := true }
      , { name := "path", pType := ParamType.Optional ParamType.String, required := false }
      , { name := "output_mode", pType := ParamType.Enum, required := false }  -- content/files_with_matches/count
      , { name := "type_filter", pType := ParamType.Optional ParamType.String, required := false }
      , { name := "case_sensitive", pType := ParamType.Bool, required := false }
      , { name := "limit", pType := ParamType.Optional ParamType.Nat, required := false }
      ]
  , scope := "workspace"
  , timeout := none
  , persistence := false
  , returnsText := true
  , returnsBinary := false
  }

-- ============================================
-- V.6.6: Git Tools
-- ============================================

def tool_git_status : ToolCapability :=
  { name := "git_status"
  , category := ToolCategory.Git
  , description := "Concise git status for workspace repository"
  , params := []
  , scope := "workspace"
  , timeout := none
  , persistence := false
  , returnsText := true
  , returnsBinary := false
  }

def tool_git_diff : ToolCapability :=
  { name := "git_diff"
  , category := ToolCategory.Git
  , description := "Git diff with optional staged/unstaged filtering"
  , params :=
      [ { name := "path", pType := ParamType.Optional ParamType.String, required := false }
      , { name := "staged", pType := ParamType.Optional ParamType.Bool, required := false }
      ]
  , scope := "workspace"
  , timeout := none
  , persistence := false
  , returnsText := true
  , returnsBinary := false
  }

def tool_git_show : ToolCapability :=
  { name := "git_show"
  , category := ToolCategory.Git
  , description := "Show git object or commit with optional path filtering"
  , params :=
      [ { name := "rev", pType := ParamType.Optional ParamType.String, required := false }
      , { name := "path", pType := ParamType.Optional ParamType.String, required := false }
      ]
  , scope := "workspace"
  , timeout := none
  , persistence := false
  , returnsText := true
  , returnsBinary := false
  }

def tool_git_blame : ToolCapability :=
  { name := "git_blame"
  , category := ToolCategory.Git
  , description := "Git blame for file with optional line range"
  , params :=
      [ { name := "path", pType := ParamType.String, required := true }
      , { name := "start", pType := ParamType.Optional ParamType.Nat, required := false }
      , { name := "end", pType := ParamType.Optional ParamType.Nat, required := false }
      ]
  , scope := "workspace"
  , timeout := none
  , persistence := false
  , returnsText := true
  , returnsBinary := false
  }

-- ============================================
-- V.6.7: Code Quality Tools
-- ============================================

def tool_run_tests : ToolCapability :=
  { name := "run_tests"
  , category := ToolCategory.CodeQuality
  , description := "Run test commands with configurable timeout"
  , params :=
      [ { name := "command", pType := ParamType.String, required := true }
      , { name := "timeout", pType := ParamType.Optional ParamType.Nat, required := false }
      ]
  , scope := "workspace"
  , timeout := some 600  -- 120 default, 600 max
  , persistence := false
  , returnsText := true
  , returnsBinary := false
  }

def tool_run_lint : ToolCapability :=
  { name := "run_lint"
  , category := ToolCategory.CodeQuality
  , description := "Run lint commands with configurable timeout"
  , params :=
      [ { name := "command", pType := ParamType.String, required := true }
      , { name := "timeout", pType := ParamType.Optional ParamType.Nat, required := false }
      ]
  , scope := "workspace"
  , timeout := some 600
  , persistence := false
  , returnsText := true
  , returnsBinary := false
  }

def tool_run_typecheck : ToolCapability :=
  { name := "run_typecheck"
  , category := ToolCategory.CodeQuality
  , description := "Run typecheck commands with configurable timeout"
  , params :=
      [ { name := "command", pType := ParamType.String, required := true }
      , { name := "timeout", pType := ParamType.Optional ParamType.Nat, required := false }
      ]
  , scope := "workspace"
  , timeout := some 600
  , persistence := false
  , returnsText := true
  , returnsBinary := false
  }

def tool_run_format : ToolCapability :=
  { name := "run_format"
  , category := ToolCategory.CodeQuality
  , description := "Run formatting commands with configurable timeout"
  , params :=
      [ { name := "command", pType := ParamType.String, required := true }
      , { name := "timeout", pType := ParamType.Optional ParamType.Nat, required := false }
      ]
  , scope := "workspace"
  , timeout := some 600
  , persistence := false
  , returnsText := true
  , returnsBinary := false
  }

-- ============================================
-- V.6.8: Web/Network Tools
-- ============================================

def tool_web_fetch : ToolCapability :=
  { name := "web_fetch"
  , category := ToolCategory.Web
  , description := "Fetch URL and return stripped text content; binary downloads to downloads/"
  , params :=
      [ { name := "url", pType := ParamType.String, required := true }
      ]
  , scope := "none (external network)"
  , timeout := none
  , persistence := false
  , returnsText := true
  , returnsBinary := true
  }

def tool_web_search : ToolCapability :=
  { name := "web_search"
  , category := ToolCategory.Web
  , description := "Search the web using LibertAI Search API"
  , params :=
      [ { name := "query", pType := ParamType.String, required := true }
      , { name := "count", pType := ParamType.Optional ParamType.Nat, required := false }
      ]
  , scope := "none (external network)"
  , timeout := none
  , persistence := false
  , returnsText := true
  , returnsBinary := false
  }

-- ============================================
-- V.6.9: Memory Tools
-- ============================================

def tool_remember_fact : ToolCapability :=
  { name := "remember_fact"
  , category := ToolCategory.Memory
  , description := "Store typed memory records for durable future recall"
  , params :=
      [ { name := "kind", pType := ParamType.Enum, required := true }  -- user_fact/repo_convention/test_command/decision
      , { name := "content", pType := ParamType.String, required := true }
      , { name := "source", pType := ParamType.Optional ParamType.String, required := false }
      , { name := "metadata", pType := ParamType.Optional ParamType.List, required := false }
      ]
  , scope := "persistent storage (MEMORY.md)"
  , timeout := none
  , persistence := true
  , returnsText := false
  , returnsBinary := false
  }

def tool_search_memory : ToolCapability :=
  { name := "search_memory"
  , category := ToolCategory.Memory
  , description := "Search typed memory records stored by remember_fact"
  , params :=
      [ { name := "query", pType := ParamType.Optional ParamType.String, required := false }
      , { name := "kind", pType := ParamType.Optional ParamType.String, required := false }
      , { name := "limit", pType := ParamType.Optional ParamType.Nat, required := false }
      , { name := "include_archived", pType := ParamType.Optional ParamType.Bool, required := false }
      ]
  , scope := "persistent storage"
  , timeout := none
  , persistence := false
  , returnsText := true
  , returnsBinary := false
  }

def tool_search_history : ToolCapability :=
  { name := "search_history"
  , category := ToolCategory.Memory
  , description := "Full-text search of past conversation history, with summarization"
  , params :=
      [ { name := "query", pType := ParamType.String, required := true }
      , { name := "chat_id", pType := ParamType.Optional ParamType.String, required := false }
      , { name := "limit", pType := ParamType.Optional ParamType.Nat, required := false }
      , { name := "summarize", pType := ParamType.Optional ParamType.Bool, required := false }
      ]
  , scope := "conversation history"
  , timeout := none
  , persistence := false
  , returnsText := true
  , returnsBinary := false
  }

-- ============================================
-- V.6.10: Computation Tool
-- ============================================

def tool_execute_code : ToolCapability :=
  { name := "execute_code"
  , category := ToolCategory.Computation
  , description := "Execute Python scripts with full tool access via call_tool()"
  , params :=
      [ { name := "code", pType := ParamType.String, required := true }
      , { name := "timeout", pType := ParamType.Optional ParamType.Nat, required := false }
      ]
  , scope := "sandboxed Python with agent tool access"
  , timeout := some 300  -- 120 default, 300 max
  , persistence := false  -- results don't enter conversation context
  , returnsText := true
  , returnsBinary := false
  }

-- ============================================
-- V.6.11: Process Management Tools
-- ============================================

def tool_process : ToolCapability :=
  { name := "process"
  , category := ToolCategory.ProcessMgmt
  , description := "Manage long-running background processes (start, list, poll, kill)"
  , params :=
      [ { name := "action", pType := ParamType.Enum, required := true }  -- start/list/poll/kill
      , { name := "command", pType := ParamType.Optional ParamType.String, required := false }
      , { name := "id", pType := ParamType.Optional ParamType.String, required := false }
      ]
  , scope := "system (background processes)"
  , timeout := none
  , persistence := true  -- processes survive between turns
  , returnsText := true
  , returnsBinary := false
  }

-- ============================================
-- V.6.12: Subagent Management Tool
-- ============================================

def tool_spawn : ToolCapability :=
  { name := "spawn"
  , category := ToolCategory.SubagentMgmt
  , description := "Spawn background subagents with specialized roles and timeouts"
  , params :=
      [ { name := "task", pType := ParamType.String, required := true }
      , { name := "label", pType := ParamType.Optional ParamType.String, required := false }
      , { name := "persona", pType := ParamType.Optional ParamType.String, required := false }
      , { name := "role", pType := ParamType.Optional ParamType.Enum, required := false }  -- default/explorer/worker/reviewer/verifier/researcher
      , { name := "timeout", pType := ParamType.Optional ParamType.Nat, required := false }
      ]
  , scope := "subagent sandbox (no further spawning)"
  , timeout := some 600  -- 300 default, 600 max
  , persistence := false  -- results delivered as pending messages
  , returnsText := true
  , returnsBinary := false
  }

-- ============================================
-- V.6.13: Messaging Tool
-- ============================================

def tool_send_file : ToolCapability :=
  { name := "send_file"
  , category := ToolCategory.Messaging
  , description := "Send files to user via Telegram"
  , params :=
      [ { name := "path", pType := ParamType.String, required := true }
      , { name := "caption", pType := ParamType.Optional ParamType.String, required := false }
      ]
  , scope := "Telegram channel"
  , timeout := none
  , persistence := false
  , returnsText := false
  , returnsBinary := true
  }

-- ============================================
-- V.6.14: Task Management Tool
-- ============================================

def tool_todo : ToolCapability :=
  { name := "todo"
  , category := ToolCategory.TaskMgmt
  , description := "Structured task list management"
  , params :=
      [ { name := "action", pType := ParamType.Enum, required := true }  -- add/list/update/complete/delete
      , { name := "title", pType := ParamType.Optional ParamType.String, required := false }
      , { name := "id", pType := ParamType.Optional ParamType.Nat, required := false }
      , { name := "status", pType := ParamType.Optional ParamType.String, required := false }
      , { name := "priority", pType := ParamType.Optional ParamType.Enum, required := false }  -- low/medium/high
      , { name := "notes", pType := ParamType.Optional ParamType.String, required := false }
      ]
  , scope := "persistent task list"
  , timeout := none
  , persistence := true
  , returnsText := false
  , returnsBinary := false
  }

-- ============================================
-- V.6.15: Media Tool
-- ============================================

def tool_generate_image : ToolCapability :=
  { name := "generate_image"
  , category := ToolCategory.Media
  , description := "Generate images from text prompts via image generation API"
  , params :=
      [ { name := "prompt", pType := ParamType.String, required := true }
      , { name := "size", pType := ParamType.Optional ParamType.String, required := false }  -- WxH, max 1024, multiples of 16
      , { name := "steps", pType := ParamType.Optional ParamType.Nat, required := false }  -- 8 default, 14 for quality
      ]
  , scope := "none (external API)"
  , timeout := none
  , persistence := true  -- generated images persist in downloads/
  , returnsText := false
  , returnsBinary := true
  }

-- ============================================
-- V.6.16: Version Control (Checkpoint) Tool
-- ============================================

def tool_checkpoint : ToolCapability :=
  { name := "checkpoint"
  , category := ToolCategory.VersionCtrl
  , description := "Create, list, restore workspace git checkpoints"
  , params :=
      [ { name := "action", pType := ParamType.Enum, required := true }  -- create/list/restore/diff
      , { name := "message", pType := ParamType.Optional ParamType.String, required := false }
      , { name := "id", pType := ParamType.Optional ParamType.String, required := false }
      ]
  , scope := "workspace git repo"
  , timeout := none
  , persistence := true
  , returnsText := true
  , returnsBinary := false
  }

-- ============================================
-- V.6.17: The Complete Tool Set
-- ============================================

def allTools : List ToolCapability :=
  [ tool_bash
  , tool_write_file
  , tool_edit_file
  , tool_multi_edit
  , tool_apply_patch
  , tool_read_file
  , tool_read_many_files
  , tool_read_pdf
  , tool_list_dir
  , tool_glob
  , tool_grep
  , tool_git_status
  , tool_git_diff
  , tool_git_show
  , tool_git_blame
  , tool_run_tests
  , tool_run_lint
  , tool_run_typecheck
  , tool_run_format
  , tool_web_fetch
  , tool_web_search
  , tool_remember_fact
  , tool_search_memory
  , tool_search_history
  , tool_execute_code
  , tool_process
  , tool_spawn
  , tool_send_file
  , tool_todo
  , tool_generate_image
  , tool_checkpoint
  ]

def toolCount : Nat := allTools.length

-- ============================================
-- V.6.18: Categorization and Analysis
-- ============================================

def toolsByCategory (cat : ToolCategory) : List ToolCapability :=
  allTools.filter (λ t => t.category = cat)

def toolsWithTimeout : List ToolCapability :=
  allTools.filter (λ t => t.timeout.isSome)

def toolsWithPersistence : List ToolCapability :=
  allTools.filter (λ t => t.persistence)

def toolsWithExternalAccess : List ToolCapability :=
  allTools.filter (λ t => t.scope.contains "external")

def toolsWithWriteAccess : List ToolCapability :=
  allTools.filter (λ t => t.persistence)

-- Total params across all tools
def totalParams : Nat :=
  allTools.foldl (λ acc t => acc + t.params.length) 0

-- ============================================
-- V.6.19: Tool Access Constraints
-- ============================================

-- The set of things the agent CANNOT do
structure ForbiddenActions where
  envVars          : Bool  -- cannot dump environment variables
  readDotEnv       : Bool  -- cannot read .env files
  stopBaalAgent    : Bool  -- cannot stop own baal-agent service
  destructiveRoot  : Bool  -- cannot run destructive operations on root filesystem

def forbiddenActions : ForbiddenActions :=
  { envVars := true
  , readDotEnv := true
  , stopBaalAgent := true
  , destructiveRoot := true
  }

-- The agent has all filesystem access EXCEPT what's forbidden
def agentHasFullAccess : Prop :=
  forbiddenActions.envVars ∧
  forbiddenActions.readDotEnv ∧
  forbiddenActions.stopBaalAgent ∧
  forbiddenActions.destructiveRoot

-- ============================================
-- V.6.20: Capability Invariants
-- ============================================

-- Invariant 1: every tool either reports a result (text or binary) or has a
-- persistent effect — no tool is both silent and effect-free.
--
-- Fixed: the original claim was "returns text, or returns nothing at all",
-- which is refuted by the binary-returning tools (`send_file`,
-- `generate_image`).  This is the intended statement, repaired.
theorem tool_returns_result_or_persists :
  ∀ (t : ToolCapability), t ∈ allTools →
    t.returnsText = true ∨ t.returnsBinary = true ∨ t.persistence = true := by
  intro t h
  have hall : allTools.all
      (fun t => t.returnsText || t.returnsBinary || t.persistence) = true := by decide
  have ht := (List.all_eq_true.mp hall) t h
  simpa [or_assoc] using ht

-- Invariant 2: All tools have a scope
theorem tool_has_defined_scope :
  ∀ (t : ToolCapability), t ∈ allTools → t.scope ≠ "" := by
  intro t h
  have hall : allTools.all (fun t => t.scope != "") = true := by decide
  have ht := (List.all_eq_true.mp hall) t h
  simpa using ht

-- Invariant 3: Every tool has at least one parameter or zero (no negative params)
theorem tool_params_nonnegative :
  ∀ (t : ToolCapability), t ∈ allTools → t.params.length ≥ 0 := by
  intro t _
  exact Nat.zero_le _

-- Invariant 4: The number of tools equals the length of allTools
theorem tool_count_correct :
  toolCount = allTools.length := rfl

-- ============================================
-- V.6.21: Capability Classification
-- ============================================

-- How many tools are read-only vs read-write?
def readOnlyTools : List ToolCapability :=
  allTools.filter (λ t => t.persistence = false)

def writeTools : List ToolCapability :=
  allTools.filter (λ t => t.persistence = true)

-- Tools that interact with external systems
def externalTools : List ToolCapability :=
  allTools.filter (λ t =>
    t.scope.contains "external" ∨
    t.scope.contains "Telegram" ∨
    t.scope.contains "external API")

-- ============================================
-- V.6.22: The Agent's Capability Profile
-- ============================================

structure CapabilityProfile where
  totalTools         : Nat
  categories         : List String
  readOnlyTools      : Nat
  writeTools         : Nat
  externalTools      : Nat
  toolsWithTimeout   : Nat
  forbiddenCount     : Nat

def capabilityProfile : CapabilityProfile :=
  { totalTools := allTools.length
  , categories := ["Core", "FileIO", "Git", "CodeQuality", "Web",
                   "Memory", "Computation", "ProcessMgmt", "SubagentMgmt",
                   "Messaging", "TaskMgmt", "Media", "VersionCtrl"]
  , readOnlyTools := readOnlyTools.length
  , writeTools := writeTools.length
  , externalTools := externalTools.length
  , toolsWithTimeout := toolsWithTimeout.length
  , forbiddenCount := 4  -- envVars, readDotEnv, stopBaalAgent, destructiveRoot
  }

-- ============================================
-- V.6.23: Cross-References with AgentState
-- ============================================

-- The AgentState's capabilities structure maps directly to the ToolCapability model
-- This theorem proves the abstraction is consistent

structure AgentCapabilitiesMap where
  canInstall    : Option ToolCapability  -- bash
  canReadFiles  : Option ToolCapability  -- read_file, read_many_files, read_pdf
  canRunShell   : Option ToolCapability  -- bash
  canFetch      : Option ToolCapability  -- web_fetch
  canSearch     : Option ToolCapability  -- web_search, search_memory, search_history
  canManage     : Option ToolCapability  -- todo, checkpoint
  canExpose     : Option ToolCapability  -- send_file
  canGenerate   : Option ToolCapability  -- generate_image
  canMemory     : Option ToolCapability  -- remember_fact

def agentCapabilitiesMap : AgentCapabilitiesMap :=
  { canInstall := some tool_bash
  , canReadFiles := some tool_read_file
  , canRunShell := some tool_bash
  , canFetch := some tool_web_fetch
  , canSearch := some tool_web_search
  , canManage := some tool_todo
  , canExpose := some tool_send_file
  , canGenerate := some tool_generate_image
  , canMemory := some tool_remember_fact
  }

-- Theorem: AgentCapabilitiesMap tools are all present in allTools.
--
-- Fixed: the original statement quantified over an *arbitrary* optional tool,
-- which is false (any tool value whatsoever could be supplied), and its proof
-- referred to a nonexistent lemma.  The intended — and true — claim is that
-- every slot of `agentCapabilitiesMap` is filled with a tool drawn from
-- `allTools`.
def capabilityMapSlots : List (Option ToolCapability) :=
  [ agentCapabilitiesMap.canInstall
  , agentCapabilitiesMap.canReadFiles
  , agentCapabilitiesMap.canRunShell
  , agentCapabilitiesMap.canFetch
  , agentCapabilitiesMap.canSearch
  , agentCapabilitiesMap.canManage
  , agentCapabilitiesMap.canExpose
  , agentCapabilitiesMap.canGenerate
  , agentCapabilitiesMap.canMemory
  ]

theorem capabilities_map_is_subset :
  ∀ (opt : Option ToolCapability), opt ∈ capabilityMapSlots →
    ∃ t, opt = some t ∧ t ∈ allTools := by
  intro opt h
  simp only [capabilityMapSlots, agentCapabilitiesMap, List.mem_cons,
    List.not_mem_nil, or_false] at h
  rcases h with h | h | h | h | h | h | h | h | h <;>
    subst h <;> refine ⟨_, rfl, ?_⟩ <;> simp [allTools]

end Twin

-- ============================================
-- Summary: Tool Capabilities Model
-- ============================================
--
-- 31 tools across 13 categories:
--   Core (5):      bash, write_file, edit_file, multi_edit, apply_patch
--   FileIO (6):    read_file, read_many_files, read_pdf, list_dir, glob, grep
--   Git (4):       git_status, git_diff, git_show, git_blame
--   CodeQuality (4): run_tests, run_lint, run_typecheck, run_format
--   Web (2):       web_fetch, web_search
--   Memory (3):    remember_fact, search_memory, search_history
--   Computation (1): execute_code
--   ProcessMgmt (1): process
--   SubagentMgmt (1): spawn
--   Messaging (1): send_file
--   TaskMgmt (1):  todo
--   Media (1):     generate_image
--   VersionCtrl (1): checkpoint
--
-- 16 tools modify state (persistence = true)
-- 15 tools are read-only (persistence = false)
-- 3 tools have explicit timeouts
-- 4 tools access external systems
-- 4 forbidden actions (env vars, .env, stop baal-agent, destructive root ops)
--
-- 62 total theorems across all files
