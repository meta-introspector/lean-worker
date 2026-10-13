-- OpenAI.lean
-- OpenAI API formal model for Gokujo

import Providers.Common

namespace Providers
namespace OpenAI

-- ============================================
-- OpenAI Configuration
-- ============================================

-- OpenAI API base URL
def baseUrl : String := "https://api.openai.com/v1"

-- OpenAI API configuration
structure OpenAIConfig where
  apiKey     : Option Common.APIKey
  baseUrl    : String
  timeout    : Nat
  userAgent  : String
  defaultModel : Option Common.ModelName
  organization : Option String
  
-- Default OpenAI configuration
def defaultOpenAIConfig : OpenAIConfig :=
  { apiKey := none
  , baseUrl := baseUrl
  , timeout := 30
  , userAgent := "Gokujo/1.0"
  , defaultModel := some "gpt-3.5-turbo"
  , organization := none
  }

-- ============================================
-- OpenAI Types
-- ============================================

-- OpenAI Model
structure Model where
  id          : Common.ModelId
  object      : String  -- "model"
  created     : Common.ISO8601Timestamp
  owned_by    : String
  permission  : List Permission
  root        : Option String
  parent      : Option String
  
-- Permission
structure Permission where
  id : String
  object : String  -- "model_permission"
  created : Common.ISO8601Timestamp
  allow_create_engine : Bool
  allow_sampling : Bool
  allow_logprobs : Bool
  allow_search_indices : Bool
  allow_view : Bool
  allow_fine_tuning : Bool
  organization : String
  group : Option String
  is_blocking : Bool
  
-- Model List Response
structure ModelList where
  object : String  -- "list"
  data   : List Model
  
-- ============================================
-- Chat Completion Types
-- ============================================

-- OpenAI Chat Message
structure ChatMessage where
  role    : Common.MessageRole
  content : Common.MessageContent
  name    : Option String
  
-- OpenAI Chat Completion Request
structure ChatCompletionRequest where
  model       : Common.ModelName
  messages    : List ChatMessage
  temperature : Option Double
  top_p       : Option Double
  max_tokens  : Option Nat
  stream      : Option Bool
  stop        : Option (List String)
  presence_penalty : Option Double
  frequency_penalty : Option Double
  user        : Option String
  response_format : Option ResponseFormat
  
-- Response Format
inductive ResponseFormat
  | text
  | json_object
  deriving Repr, DecidableEq

-- OpenAI Chat Completion Choice
structure ChatCompletionChoice where
  index : Nat
  message : ChatMessage
  finish_reason : Option String
  
-- OpenAI Chat Completion Usage
structure ChatCompletionUsage where
  prompt_tokens     : Nat
  completion_tokens : Nat
  total_tokens      : Nat
  
-- OpenAI Chat Completion Response
structure ChatCompletionResponse where
  id          : Common.RequestId
  object      : String  -- "chat.completion"
  created     : Common.ISO8601Timestamp
  model       : Common.ModelName
  choices     : List ChatCompletionChoice
  usage       : ChatCompletionUsage
  
-- ============================================
-- Embedding Types
-- ============================================

-- OpenAI Embedding Request
structure EmbeddingRequest where
  model  : Common.ModelName
  input  : String
  user   : Option String
  encoding_format : Option String
  dimensions : Option Nat
  
-- OpenAI Embedding Data
structure EmbeddingData where
  object    : String  -- "embedding"
  embedding : List Double
  index     : Nat
  
-- OpenAI Embedding Response
structure EmbeddingResponse where
  object : String  -- "list"
  data   : List EmbeddingData
  model  : Common.ModelName
  usage  : EmbeddingUsage
  
-- OpenAI Embedding Usage
structure EmbeddingUsage where
  prompt_tokens : Nat
  total_tokens  : Nat
  
-- ============================================
-- Fine-tuning Types
-- ============================================

-- OpenAI Fine-tuning Job ID
def FineTuningJobId := String

-- OpenAI Fine-tuning Job
structure FineTuningJob where
  id        : FineTuningJobId
  object    : String  -- "fine_tuning.job"
  model     : Common.ModelName
  created   : Common.ISO8601Timestamp
  finished_at : Option Common.ISO8601Timestamp
  status    : String
  training_file : String
  validation_file : Option String
  result_files : List String
  hyperparameters : FineTuningHyperparameters
  
-- OpenAI Fine-tuning Hyperparameters
structure FineTuningHyperparameters where
  n_epochs : Option Nat
  batch_size : Option Nat
  learning_rate_multiplier : Option Double
  
-- ============================================
-- API Endpoints
-- ============================================

-- HTTP Method
inductive HttpMethod
  | GET
  | POST
  | PUT
  | DELETE
  | PATCH
  deriving Repr, DecidableEq

-- API Endpoint
def Endpoint where
  method : HttpMethod
  path   : String
  
-- List models endpoint
def listModelsEndpoint : Endpoint :=
  { method := .GET
  , path := "/models"
  }

-- Get model endpoint
def getModelEndpoint : Common.ModelId → Endpoint := fun modelId =>
  { method := .GET
  , path := "/models/" ++ modelId
  }

-- Create chat completion endpoint
def createChatCompletionEndpoint : Endpoint :=
  { method := .POST
  , path := "/chat/completions"
  }

-- Create embeddings endpoint
def createEmbeddingsEndpoint : Endpoint :=
  { method := .POST
  , path := "/embeddings"
  }

-- List fine-tuning jobs endpoint
def listFineTuningJobsEndpoint : Endpoint :=
  { method := .GET
  , path := "/fine_tuning/jobs"
  }

-- Get fine-tuning job endpoint
def getFineTuningJobEndpoint : FineTuningJobId → Endpoint := fun jobId =>
  { method := .GET
  , path := "/fine_tuning/jobs/" ++ jobId
  }

-- Create fine-tuning job endpoint
def createFineTuningJobEndpoint : Endpoint :=
  { method := .POST
  , path := "/fine_tuning/jobs"
  }

-- Cancel fine-tuning job endpoint
def cancelFineTuningJobEndpoint : FineTuningJobId → Endpoint := fun jobId =>
  { method := .POST
  , path := "/fine_tuning/jobs/" ++ jobId ++ "/cancel"
  }

-- ============================================
-- OpenAI Provider Interface
-- ============================================

-- OpenAI Provider Capabilities
def openAICapabilities : Common.ProviderCapabilities :=
  { supportsChat := true
  , supportsEmbeddings := true
  , supportsFineTuning := true
  , supportsStreaming := true
  , supportsTools := true
  , supportsMultiModal := true
  }

-- OpenAI Provider Interface
def openAIProvider : Common.ProviderInterface :=
  { config :=
      { providerName := .OpenAI
      , apiKey := none
      , baseUrl := baseUrl
      , timeout := 30
      , userAgent := "Gokujo/1.0"
      , defaultModel := some "gpt-3.5-turbo"
      }
  , capabilities := openAICapabilities
  }

-- ============================================
-- Gokujo Integration
-- ============================================

-- Gokujo OpenAI Configuration
structure GokujoOpenAIConfig where
  apiKey     : Option Common.APIKey
  baseUrl    : String
  timeout    : Nat
  userAgent  : String
  defaultModel : Option Common.ModelName
  organization : Option String
  
-- Default Gokujo OpenAI configuration
def defaultGokujoOpenAIConfig : GokujoOpenAIConfig :=
  { apiKey := none
  , baseUrl := baseUrl
  , timeout := 30
  , userAgent := "Gokujo/1.0"
  , defaultModel := some "gpt-3.5-turbo"
  , organization := none
  }

-- Gokujo OpenAI Client
structure GokujoOpenAIClient where
  config : GokujoOpenAIConfig
  
-- Create a Gokujo OpenAI client
def createGokujoOpenAIClient (config : GokujoOpenAIConfig) : GokujoOpenAIClient :=
  { config := config }

-- ============================================
-- Theorems
-- ============================================

-- Theorem: listModelsEndpoint is GET
theorem list_models_endpoint_is_get :
  listModelsEndpoint.method = .GET := by
  rfl

-- Theorem: createChatCompletionEndpoint is POST
theorem create_chat_completion_endpoint_is_post :
  createChatCompletionEndpoint.method = .POST := by
  rfl

-- Theorem: createEmbeddingsEndpoint is POST
theorem create_embeddings_endpoint_is_post :
  createEmbeddingsEndpoint.method = .POST := by
  rfl

-- Theorem: OpenAI supports chat
theorem openai_supports_chat :
  openAICapabilities.supportsChat = true := by
  rfl

-- Theorem: OpenAI supports embeddings
theorem openai_supports_embeddings :
  openAICapabilities.supportsEmbeddings = true := by
  rfl

-- Theorem: OpenAI supports fine-tuning
theorem openai_supports_fine_tuning :
  openAICapabilities.supportsFineTuning = true := by
  rfl

-- Theorem: OpenAI supports tools
theorem openai_supports_tools :
  openAICapabilities.supportsTools = true := by
  rfl

-- Theorem: OpenAI supports multi-modal
theorem openai_supports_multimodal :
  openAICapabilities.supportsMultiModal = true := by
  rfl

end Providers
end OpenAI
