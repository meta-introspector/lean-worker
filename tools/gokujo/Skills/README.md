# Gokujo Skills Framework

## Overview

The **Skills Framework** provides a formal, type-safe system for defining, executing, and composing AI-powered skills in Lean 4. It enables:

- **Interpretable AI**: Step-by-step execution with verification and explanations
- **Provider Agnostic**: Works with Mistral, OpenRouter, Grok, DeepSeek, OpenAI, Claude
- **Lean Integration**: Formal type checking and theorem proving for skills
- **Composable**: Combine skills into complex workflows
- **Auditable**: Full audit trails and provenance tracking

## Directory Structure

```
tools/gokujo/Skills/
├── Types.lean          # Core skill types and definitions
├── Adapter.lean        # Lean skill adapter framework
├── Interpretable.lean  # Interpretable skill execution with verification
└── README.md           # This documentation

tools/gokujo/Providers/
├── Common.lean         # Unified provider interface
├── Registry.lean       # Provider registry and selection
├── Mistral/           # Mistral provider (existing)
├── OpenRouter.lean    # OpenRouter provider
├── Grok.lean          # Grok provider
├── DeepSeek.lean      # DeepSeek provider
├── OpenAI.lean        # OpenAI provider
└── Claude.lean        # Claude provider
```

## Core Concepts

### 1. Skills (`Types.lean`)

A **Skill** is a reusable, parameterized AI capability with:

- **Identity**: `SkillId`, `SkillName`, `SkillVersion`
- **Classification**: `SkillCategory` (CodeGeneration, CodeReview, Documentation, etc.)
- **Priority**: `SkillSeverity` (Low, Medium, High, Critical)
- **Status**: `SkillStatus` (Draft, Testing, Active, Deprecated, Archived)
- **Configuration**: Input/Output types, schemas, parameters
- **Execution**: Mode (Synchronous, Asynchronous, Streaming, Batch)

### 2. Providers (`Providers/`)

**Providers** are the LLM services that power skills:

| Provider | Chat | Embeddings | Fine-Tuning | Streaming | Tools | Multi-Modal |
|----------|------|------------|-------------|-----------|-------|-------------|
| Mistral | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| OpenRouter | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ |
| Grok | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| DeepSeek | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| OpenAI | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Claude | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ |

### 3. Lean Skill Adapters (`Adapter.lean`)

**Lean Skill Adapters** bridge between skills and Lean 4 code:

- **Type Mapping**: Map skill inputs/outputs to Lean types
- **Function Binding**: Bind skills to Lean functions
- **Conversion**: Convert between JSON and Lean types
- **Validation**: Validate inputs using Lean type system

### 4. Interpretable Skills (`Interpretable.lean`)

**Interpretable Skills** provide transparency and verification:

- **Interpretation Modes**: Direct, StepByStep, Verified, Explained, Audited
- **Step Tracing**: Record each execution step with reasoning
- **Verification**: Type checking, theorem proving, property-based verification
- **Explanations**: Human-readable explanations for each step
- **Audit Trails**: Full provenance tracking

## Usage Examples

### Basic Skill Definition

```lean
import Skills.Types

open Skills

-- Define a code review skill
def codeReviewSkill : SkillDefinition :=
  { config :=
      { id := "code-review-v1"
      , name := "Code Review"
      , description := "Review code for quality and correctness"
      , version := "1.0.0"
      , category := .CodeReview
      , severity := .High
      , status := .Active
      , author := some "Gokujo Team"
      , license := some "MIT"
      , tags := ["code", "review", "quality"]
      , dependencies := []
      }
  , input_type := .Code
  , output_type := .Text
  , input_schema := none
  , output_schema := none
  , parameters :=
      [ { name := "strictness"
        , type := .Enum ["low", "medium", "high"]
        , description := some "Review strictness level"
        , required := false
        , default := some "medium"
        }
      , { name := "focus"
        , type := .Array
        , description := some "Areas to focus on"
        , required := false
        , default := none
        }
      ]
  , execution :=
      { mode := .Synchronous
      , timeout := some 60
      , retries := some 3
      , cacheable := true
      , idempotent := true
      }
  , provider :=
      { providers :=
          [ { providerName := .Mistral
            , model := some "mistral-small"
            , api_key := none
            , temperature := some 0.3
            , max_tokens := some 2048
            , top_p := some 0.9
            , stream := some false
            , timeout := some 30
            }
          , { providerName := .Claude
            , model := some "claude-3-sonnet"
            , api_key := none
            , temperature := some 0.3
            , max_tokens := some 2048
            , top_p := none
            , stream := some false
            , timeout := some 30
            }
          ]
      , strategy := .FallbackChain
      , fallback_on_error := true
      }
  }
```

### Lean Skill Adapter

```lean
import Skills.Adapter

open Skills
open Skills.Adapter

-- Define a Lean function to analyze code
def analyzeCode (code : String) (strictness : String) : String := by
  -- Actual implementation would go here
  "Code analysis complete"

-- Create a Lean skill adapter
def codeAnalysisAdapter : LeanSkillAdapter :=
  { config :=
      { id := "code-analysis-adapter"
      , name := "Code Analysis Adapter"
      , version := "1.0.0"
      , description := some "Lean-based code analysis"
      , author := some "Gokujo Team"
      , license := some "MIT"
      }
  , skill_definition := codeReviewSkill
  , signature :=
      { name := "analyzeCode"
      , description := some "Analyze code using Lean"
      , inputs :=
          [ { input_type := .Code
            , lean_type := { name := "String", kind := .Primitive "String", description := none, fields := [] }
            , description := some "Code to analyze"
            , required := true
            }
          ]
      , outputs :=
          [ { output_type := .Text
            , lean_type := { name := "String", kind := .Primitive "String", description := none, fields := [] }
            , description := some "Analysis results"
            }
          ]
      , parameters :=
          [ { name := "strictness"
            , parameter_type := .String
            , lean_type := { name := "String", kind := .Primitive "String", description := none, fields := [] }
            , description := some "Analysis strictness"
            , required := false
            , default_value := some "medium"
            }
          ]
      }
  , implementation :=
      { module_path := "Skills.CodeAnalysis"
      , function_name := "analyzeCode"
      , namespace := some "CodeAnalysis"
      , imports := ["Skills.Types", "Skills.Adapter"]
      }
  , input_mapping :=
      { skill_input_type := .Code
      , lean_type := { name := "String", kind := .Primitive "String", description := none, fields := [] }
      , converter := some "fun code => code"  -- Identity conversion
      , validator := some "fun code => if code.isEmpty then none else some code"
      }
  , output_mapping :=
      { lean_type := { name := "String", kind := .Primitive "String", description := none, fields := [] }
      , skill_output_type := .Text
      , converter := some "fun output => output"
      , formatter := some "fun output => \"Analysis: \" ++ output"
      }
  }
```

### Interpretable Skill Execution

```lean
import Skills.Interpretable

open Skills
open Skills.Interpretable

-- Create an interpretable skill config
def interpretableConfig : InterpretableSkillConfig :=
  { skill_id := "code-review-v1"
  , mode := .StepByStep
  , verbosity := 7
  , verify_each_step := true
  , generate_explanations := true
  , audit_trail := true
  , max_steps := some 10
  , timeout_per_step := some 30000
  }

-- Create an interpretation engine
def engine : InterpretationEngine :=
  createInterpretationEngine
    interpretableConfig
    (Providers.Registry.defaultProviderRegistry.providers.head?.getD default).interface

-- Execute with interpretation
def result : IO InterpretableExecutionResult :=
  -- Placeholder for actual execution
  sorry
```

### Provider Selection

```lean
import Providers.Registry

open Providers
open Providers.Registry

-- Select a provider for chat completion
def selectChatProvider : Option ProviderEntry :=
  selectProviderByName defaultProviderRegistry .Mistral

-- Select best provider with specific capabilities
def criteria : ProviderSelectionCriteria :=
  { required_capabilities :=
      { supportsChat := true
      , supportsEmbeddings := false
      , supportsFineTuning := false
      , supportsStreaming := true
      , supportsTools := false
      , supportsMultiModal := false
      }
  , preferred_providers := [.Mistral, .Claude, .OpenAI]
  , excluded_providers := [.Grok]
  , cost_preference := some .Moderate
  , performance_preference := some .Balanced
  }

def bestProvider : Option ProviderEntry :=
  selectBestProvider defaultProviderRegistry criteria
```

### Multi-Provider Configuration

```lean
import Providers.Registry

open Providers
open Providers.Registry

-- Create a multi-provider config with fallback
def multiConfig : MultiProviderConfig :=
  { strategy := .Fallback [.Mistral, .OpenRouter, .OpenAI]
  , registry := defaultProviderRegistry
  , criteria := some
      { required_capabilities :=
          { supportsChat := true
          , supportsEmbeddings := false
          , supportsFineTuning := false
          , supportsStreaming := false
          , supportsTools := false
          , supportsMultiModal := false
          }
      , preferred_providers := []
      , excluded_providers := []
      , cost_preference := some .Cheapest
      , performance_preference := some .Balanced
      }
  }
```

## Skill Composition

### Sequential Composition

```lean
import Skills.Interpretable

open Skills
open Skills.Interpretable

-- Define a composite skill for code review and improvement
def codeReviewAndImprove : CompositeSkill :=
  { id := "code-review-and-improve"
  , name := "Code Review and Improve"
  , description := some "Review code and suggest improvements"
  , sub_skills :=
      [ ("code-review-v1", [("strictness", "high")])
      , ("code-refactor-v1", [("aggressiveness", "medium")])
      , ("code-format-v1", [])
      ]
  , composition_mode := .Sequential
  }
```

### Parallel Composition

```lean
-- Define a composite skill for multi-aspect analysis
def comprehensiveAnalysis : CompositeSkill :=
  { id := "comprehensive-analysis"
  , name := "Comprehensive Analysis"
  , description := some "Analyze code from multiple perspectives"
  , sub_skills :=
      [ ("code-review-v1", [])
      , ("security-scan-v1", [])
      , ("performance-analysis-v1", [])
      ]
  , composition_mode := .Parallel
  }
```

## Type Safety

All types are formally modeled in Lean 4, providing:

1. **Compile-time validation** - Invalid operations caught at compile time
2. **Type safety** - No runtime type errors
3. **Exhaustive pattern matching** - All cases must be handled
4. **Theorems** - Mathematical proofs of system properties

## Building

Compile the Skills framework:

```bash
cd /workspace/github__meta-introspector__lean-worker
lean -R . tools/gokujo/Skills/Types.lean
lean -R . tools/gokujo/Skills/Adapter.lean
lean -R . tools/gokujo/Skills/Interpretable.lean
lean -R . tools/gokujo/Providers/Common.lean
lean -R . tools/gokujo/Providers/Registry.lean
```

## Integration with Existing Gokujo

The Skills framework integrates with existing Gokujo components:

- **Mistral Integration**: Full support for Mistral models
- **GitHub Integration**: Store skills in repositories, version control
- **AWS Integration**: Deploy skills as serverless functions
- **Cloudflare Integration**: Run skills at the edge

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Gokujo Skills                            │
├─────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────┐  │
│  │   Skills    │    │  Providers  │    │   Adapters       │  │
│  │             │    │             │    │                 │  │
│  │  - Types    │    │  - Common   │    │  - Lean         │  │
│  │  - Adapter  │    │  - Registry │    │  - Type Mapping │  │
│  │  - Inter-   │    │  - Mistral  │    │  - Execution     │  │
│  │    pretable │    │  - OpenAI   │    │                 │  │
│  │             │    │  - Claude   │    │                 │  │
│  └─────────────┘    └─────────────┘    └─────────────────┘  │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Interpretable Skills                     │  │
│  │  - Step-by-step execution with verification                 │  │
│  │  - Full audit trails and provenance                        │  │
│  │  - Formal type checking and theorem proving                 │  │
│  │  - Human-readable explanations                             │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────┘
```

## Next Steps

1. **Implement actual execution** - Replace `sorry` placeholders with real implementations
2. **Add more providers** - Support additional LLM providers
3. **Add built-in skills** - Pre-defined skills for common tasks
4. **Add skill marketplace** - Share and discover skills
5. **Add testing framework** - Test skills for correctness
6. **Add monitoring** - Track skill usage and performance
7. **Add CI/CD integration** - Automated skill deployment
8. **Add security** - Sandboxing and access control for skills

## License

This framework is part of the `lean-worker` repository and follows its licensing terms.

## Contributing

1. Add new provider integrations to `Providers/`
2. Add new skill types to `Skills/Types.lean`
3. Add new adapter utilities to `Skills/Adapter.lean`
4. Add new interpretation features to `Skills/Interpretable.lean`
5. Add theorems to prove properties
6. Update documentation

## Status

- ✅ Core skill types
- ✅ Provider common interface
- ✅ Provider registry and selection
- ✅ All major LLM providers (Mistral, OpenRouter, Grok, DeepSeek, OpenAI, Claude)
- ✅ Lean skill adapter framework
- ✅ Interpretable skill execution
- ⏳ Actual execution implementations
- ⏳ Built-in skill library
- ⏳ Testing framework
- ⏳ Monitoring and CI/CD
