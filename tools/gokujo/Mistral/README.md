# Gokujo Mistral AI Integration

## Overview

This directory contains the formal Lean 4 model of the **Mistral AI API** integrated with **Gokujo**. It provides complete type definitions, API endpoints, and integration types for working with Mistral AI services.

## Directory Structure

```
tools/gokujo/Mistral/
├── Types.lean          # Core Mistral API types
├── API.lean            # Mistral API endpoints and request/response types
├── Integration.lean    # Gokujo-Mistral integration (config, commands, results, workflows)
└── README.md           # This documentation
```

## Features

### 1. Core Types (`Types.lean`)

Complete formal model of Mistral AI data types:

- **Primitive Types**: `APIKey`, `ModelName`, `ModelId`, `ProjectId`, `OrganizationId`, `UserId`, `RequestId`, `ISO8601Timestamp`
- **Model Types**: `Model`, `ModelList`
- **Chat Completion Types**: `ChatMessageRole` (system/user/assistant), `ChatMessage`, `ChatCompletionRequest`, `ChatCompletionChoice`, `ChatCompletionUsage`, `ChatCompletionResponse`, streaming types (`ChatCompletionChunk`, `ChatCompletionChunkChoice`, `ChatMessageDelta`)
- **Embedding Types**: `EmbeddingInput`, `EmbeddingRequest`, `EmbeddingData`, `EmbeddingResponse`, `EmbeddingUsage`
- **Fine-tuning Types**: `FineTuningJobId`, `FineTuningDataset`, `FineTuningJob`, `FineTuningHyperparameters`, `FineTuningJobList`
- **Project Types**: `Project`, `ProjectList`
- **Organization Types**: `Organization`

### 2. API Endpoints (`API.lean`)

Complete REST API endpoint model for all Mistral services:

#### Model Endpoints
- `GET /v1/models` - List all available models
- `GET /v1/models/{model_id}` - Get a specific model

#### Chat Completion Endpoints
- `POST /v1/chat/completions` - Create chat completion

#### Embedding Endpoints
- `POST /v1/embeddings` - Create embeddings

#### Fine-tuning Endpoints
- `GET /v1/fine_tuning/jobs` - List fine-tuning jobs
- `GET /v1/fine_tuning/jobs/{job_id}` - Get a specific fine-tuning job
- `POST /v1/fine_tuning/jobs` - Create a fine-tuning job
- `POST /v1/fine_tuning/jobs/{job_id}/cancel` - Cancel a fine-tuning job

#### Project Endpoints
- `GET /v1/projects` - List projects
- `GET /v1/projects/{project_id}` - Get a specific project
- `POST /v1/projects` - Create a project
- `PATCH /v1/projects/{project_id}` - Update a project
- `DELETE /v1/projects/{project_id}` - Delete a project

#### Organization Endpoints
- `GET /v1/organizations` - List organizations
- `GET /v1/organizations/{organization_id}` - Get a specific organization

### 3. Gokujo Integration (`Integration.lean`)

Complete Gokujo integration for Mistral AI:

#### Configuration
- `GokujoMistralConfig` - Configuration with API key, base URL, timeout, defaults
- `defaultGokujoMistralConfig` - Default configuration

#### Operations
- `GokujoMistralOperation` - Operation type with config, endpoint, request, response

#### Workflows
- `GokujoMistralWorkflow` - Workflow with steps
- `GokujoMistralStep` - Individual workflow step

#### Projects
- `GokujoMistralProject` - Project configuration with workflows

#### Commands
- `GokujoMistralChatCommand` - Chat completion command
- `GokujoMistralEmbeddingCommand` - Embedding command
- `GokujoMistralFineTuningCommand` - Fine-tuning command
- `GokujoMistralListModelsCommand` - List models command
- `GokujoMistralGetModelCommand` - Get model command
- `GokujoMistralListProjectsCommand` - List projects command
- `GokujoMistralGetProjectCommand` - Get project command

#### Results
- `GokujoMistralResult` - Base result type
- `GokujoMistralChatResult` - Chat completion result
- `GokujoMistralEmbeddingResult` - Embedding result
- `GokujoMistralFineTuningResult` - Fine-tuning result
- `GokujoMistralModelResult` - Model result
- `GokujoMistralProjectResult` - Project result

#### Client
- `GokujoMistralClient` - Mistral API client
- `createGokujoMistralClient` - Client factory

#### Builders
- `createMistralWorkflow` - Create workflow from project
- `createChatCompletionCommand` - Create chat command
- `createEmbeddingCommand` - Create embedding command
- `createFineTuningCommand` - Create fine-tuning command
- `createGokujoMistralProject` - Create project
- `addWorkflow` - Add workflow to project
- `addChatCompletionStep` - Add step to workflow

#### Execution
- `executeChatCompletion` - Execute chat completion
- `executeEmbedding` - Execute embedding
- `executeFineTuning` - Execute fine-tuning
- `executeListModels` - List models
- `executeGetModel` - Get model
- `executeListProjects` - List projects
- `executeGetProject` - Get project
- `executeMistralWorkflow` - Execute workflow

## Usage Examples

### Basic Chat Completion

```lean
import Mistral.GokujoIntegration

open Mistral
open Mistral.GokujoIntegration

-- Create configuration
def config : GokujoMistralConfig :=
  { apiKey := some "your-api-key"
  , baseUrl := API.baseUrl
  , timeout := 30
  , userAgent := "Gokujo/1.0"
  , defaultModel := some "mistral-tiny"
  , defaultTemperature := some 0.7
  , defaultMaxTokens := some 1024
  }

-- Create client
def client : GokujoMistralClient :=
  createGokujoMistralClient config

-- Create chat messages
def messages : List Types.ChatMessage :=
  [ { role := .system, content := "You are a helpful assistant." }
  , { role := .user, content := "What is 2+2?" }
  ]

-- Create chat command
def chatCommand : GokujoMistralChatCommand :=
  createChatCompletionCommand "mistral-tiny" messages config

-- Execute chat completion (async)
#eval executeChatCompletion client chatCommand
```

### Creating a Workflow

```lean
import Mistral.GokujoIntegration

open Mistral
open Mistral.GokujoIntegration

-- Create a workflow
def workflow : GokujoMistralWorkflow :=
  { name := "code-review-workflow"
  , description := "Review code using Mistral"
  , model := "mistral-small"
  , steps :=
      [ { name := "analyze"
        , description := "Analyze code"
        , action := "gokujo analyze"
        , endpoint := API.createChatCompletionEndpoint
        , dependsOn := []
        , input := some "code.txt"
        , output := some "analysis.json"
        }
      , { name := "review"
        , description := "Generate review"
        , action := "gokujo review"
        , endpoint := API.createChatCompletionEndpoint
        , dependsOn := ["analyze"]
        , input := some "analysis.json"
        , output := some "review.md"
        }
      ]
  }

-- Create a project
def project : GokujoMistralProject :=
  createGokujoMistralProject
    "code-review-project"
    (some "Automated code review with Mistral")
    "mistral-small"
    [workflow]
```

### Fine-tuning

```lean
import Mistral.GokujoIntegration

open Mistral
open Mistral.GokujoIntegration

-- Create fine-tuning command
def fineTuningCommand : GokujoMistralFineTuningCommand :=
  { model := "mistral-tiny"
  , trainingFile := "training.jsonl"
  , validationFile := some "validation.jsonl"
  , hyperparameters :=
      { n_epochs := some 3
      , batch_size := some 32
      , learning_rate_multiplier := some 0.1
      }
  }

-- Execute fine-tuning
#eval executeFineTuning client fineTuningCommand
```

## Type Safety

All types are formally modeled in Lean 4, providing:

1. **Compile-time validation** - Invalid operations are caught at compile time
2. **Type safety** - No runtime type errors
3. **Exhaustive pattern matching** - All cases must be handled
4. **Theorems** - Mathematical proofs of type properties

## Integration with Other Gokujo Platforms

This Mistral integration is designed to work seamlessly with other Gokujo platforms:

- **Cloudflare** - Deploy Mistral-powered Workers
- **GitHub** - Automate Mistral workflows in CI/CD
- **AWS** - Run Mistral inference on AWS infrastructure
- **Agentaps** - Use Mistral with agent protocols

## Theorems

The integration includes formal theorems proving:

- Configuration validity
- Client creation correctness
- Workflow step ordering
- Command creation validity
- Project workflow management

## Building

Compile the Mistral integration:

```bash
cd /workspace/github__meta-introspector__lean-worker
lean -R . tools/gokujo/Mistral/Types.lean
lean -R . tools/gokujo/Mistral/API.lean
lean -R . tools/gokujo/Mistral/Integration.lean
```

## Dependencies

- Lean 4.28.0+
- Gokujo core (included in this repository)
- No external dependencies required

## License

This integration is part of the `lean-worker` repository and follows its licensing terms.

## Contributing

1. Add new types to `Types.lean`
2. Add new endpoints to `API.lean`
3. Add new commands/results to `Integration.lean`
4. Add theorems to prove properties
5. Update this documentation

## Status

- ✅ Core types complete
- ✅ API endpoints complete
- ✅ Integration types complete
- ✅ Documentation complete
- ⏳ Execution implementations (IO placeholders)
- ⏳ Additional theorems

## Next Steps

1. Implement actual HTTP client for Mistral API
2. Add more fine-tuning configuration options
3. Add support for streaming responses
4. Add rate limiting and retry logic
5. Add authentication helpers
6. Add more comprehensive error handling
7. Add integration tests
8. Add examples directory with runnable workflows
