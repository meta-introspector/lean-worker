-- Types.lean
-- Formal model of Gokujo Skills framework

import Providers.Common

namespace Skills

-- ============================================
-- Skill Types
-- ============================================

-- Skill ID
def SkillId := String

-- Skill Name
def SkillName := String

-- Skill Description
def SkillDescription := String

-- Skill Version
def SkillVersion := String

-- Skill Category
inductive SkillCategory
  | CodeGeneration
  | CodeReview
  | Documentation
  | Testing
  | Refactoring
  | Analysis
  | Summarization
  | Translation
  | Creativity
  | Reasoning
  | Custom
  deriving Repr, DecidableEq

-- Skill Severity/Importance
inductive SkillSeverity
  | Low
  | Medium
  | High
  | Critical
  deriving Repr, DecidableEq, Ord

-- Skill Status
inductive SkillStatus
  | Draft
  | Testing
  | Active
  | Deprecated
  | Archived
  deriving Repr, DecidableEq

-- ============================================
-- Skill Configuration
-- ============================================

-- Skill Configuration
structure SkillConfig where
  id          : SkillId
  name        : SkillName
  description : SkillDescription
  version     : SkillVersion
  category    : SkillCategory
  severity    : SkillSeverity
  status      : SkillStatus
  author      : Option String
  license     : Option String
  tags        : List String
  dependencies : List SkillId
  
-- ============================================
-- Skill Input/Output Types
-- ============================================

-- Input Type
inductive InputType
  | Text
  | Code
  | File
  | Directory
  | JSON
  | YAML
  | XML
  | Image
  | Audio
  | Video
  | URL
  | Database
  | APIResponse
  | Custom of String
  deriving Repr, DecidableEq

-- Output Type
inductive OutputType
  | Text
  | Code
  | File
  | JSON
  | YAML
  | XML
  | Markdown
  | HTML
  | Image
  | StructuredData
  | Custom of String
  deriving Repr, DecidableEq

-- Input Schema
def InputSchema := String  -- JSON Schema for validation

-- Output Schema
def OutputSchema := String  -- JSON Schema for validation

-- ============================================
-- Skill Parameters
-- ============================================

-- Parameter Name
def ParameterName := String

-- Parameter Type
inductive ParameterType
  | String
  | Number
  | Boolean
  | Array
  | Object
  | Enum of List String
  deriving Repr, DecidableEq

-- Parameter Schema
structure ParameterSchema where
  name        : ParameterName
  type        : ParameterType
  description : Option String
  required    : Bool
  default     : Option String
  enum_values : Option (List String)
  min         : Option Number
  max         : Option Number
  pattern     : Option String
  
-- Skill Parameters
def SkillParameters := List ParameterSchema

-- ============================================
-- Skill Execution
-- ============================================

-- Execution Context
def ExecutionContext := String

-- Execution Mode
inductive ExecutionMode
  | Synchronous
  | Asynchronous
  | Streaming
  | Batch
  deriving Repr, DecidableEq

-- Execution Result
structure ExecutionResult where
  success     : Bool
  output      : Option String
  error       : Option String
  warnings    : List String
  metrics     : Option ExecutionMetrics
  exit_code   : Nat
  
-- Execution Metrics
structure ExecutionMetrics where
  tokens_used     : Nat
  time_elapsed_ms : Nat
  requests_made   : Nat
  cache_hits      : Nat
  
-- ============================================
-- Skill Provider Configuration
-- ============================================

-- Provider Selection Strategy
inductive ProviderSelectionStrategy
  | Default
  | RoundRobin
  | Random
  | CostOptimized
  | PerformanceOptimized
  | FallbackChain
  | Custom of String
  deriving Repr, DecidableEq

-- Skill Provider Config
structure SkillProviderConfig where
  provider       : Providers.Common.ProviderName
  model          : Option Providers.Common.ModelName
  api_key        : Option Providers.Common.APIKey
  temperature    : Option Double
  max_tokens     : Option Nat
  top_p          : Option Double
  stream         : Option Bool
  timeout        : Option Nat
  
-- Multi-Provider Config
structure MultiProviderConfig where
  providers      : List SkillProviderConfig
  strategy       : ProviderSelectionStrategy
  fallback_on_error : Bool
  
-- ============================================
-- Skill Definition
-- ============================================

-- Skill Definition
structure SkillDefinition where
  config      : SkillConfig
  input_type  : InputType
  output_type : OutputType
  input_schema : Option InputSchema
  output_schema : Option OutputSchema
  parameters  : SkillParameters
  execution   : SkillExecution
  provider    : MultiProviderConfig
  
-- Skill Execution Definition
structure SkillExecution where
  mode        : ExecutionMode
  timeout     : Option Nat
  retries     : Option Nat
  cacheable   : Bool
  idempotent  : Bool
  
-- ============================================
-- Skill Registry
-- ============================================

-- Skill Registry
def SkillRegistry := List SkillDefinition

-- Empty Skill Registry
def emptySkillRegistry : SkillRegistry := []

-- ============================================
-- Theorems
-- ============================================

-- Theorem: SkillCategory is decidable
theorem skill_category_decidable : ∀ (c1 c2 : SkillCategory), Decidable (c1 = c2) := by
  intro _ _
  infer_instance

-- Theorem: SkillSeverity is decidable
theorem skill_severity_decidable : ∀ (s1 s2 : SkillSeverity), Decidable (s1 = s2) := by
  intro _ _
  infer_instance

-- Theorem: SkillStatus is decidable
theorem skill_status_decidable : ∀ (st1 st2 : SkillStatus), Decidable (st1 = st2) := by
  intro _ _
  infer_instance

-- Theorem: InputType is decidable
theorem input_type_decidable : ∀ (t1 t2 : InputType), Decidable (t1 = t2) := by
  intro _ _
  infer_instance

-- Theorem: OutputType is decidable
theorem output_type_decidable : ∀ (t1 t2 : OutputType), Decidable (t1 = t2) := by
  intro _ _
  infer_instance

-- Theorem: ParameterType is decidable
theorem parameter_type_decidable : ∀ (t1 t2 : ParameterType), Decidable (t1 = t2) := by
  intro _ _
  infer_instance

-- Theorem: ExecutionMode is decidable
theorem execution_mode_decidable : ∀ (m1 m2 : ExecutionMode), Decidable (m1 = m2) := by
  intro _ _
  infer_instance

-- Theorem: ProviderSelectionStrategy is decidable
theorem provider_selection_strategy_decidable : ∀ (s1 s2 : ProviderSelectionStrategy), Decidable (s1 = s2) := by
  intro _ _
  infer_instance

-- Theorem: Empty registry has no skills
theorem empty_registry_has_no_skills :
  emptySkillRegistry.length = 0 := by
  rfl

end Skills
