-- OpenRouter.lean
-- OpenRouter API formal model for Gokujo

import Providers.Common

namespace Providers
namespace OpenRouter

-- ============================================
-- OpenRouter Configuration
-- ============================================

-- OpenRouter API base URL
def baseUrl : String := "https://openrouter.ai/api/v1"

-- OpenRouter API configuration
structure OpenRouterConfig where
  apiKey     : Option Common.APIKey
  baseUrl    : String
  timeout    : Nat
  userAgent  : String
  defaultModel : Option Common.ModelName
  siteUrl    : Option String  -- For OpenRouter rankings
  siteName   : Option String  -- For OpenRouter rankings
  
-- Default OpenRouter configuration
def defaultOpenRouterConfig : OpenRouterConfig :=
  { apiKey := none
  , baseUrl := baseUrl
  , timeout := 30
  , userAgent := "Gokujo/1.0"
  , defaultModel := some "openai/gpt-3.5-turbo"
  , siteUrl := none
  , siteName := none
  }

-- ============================================
-- OpenRouter Types
-- ============================================

-- OpenRouter Model
structure Model where
  id          : Common.ModelId
  name        : Common.ModelName
  created     : Common.ISO8601Timestamp
  description : Option String
  context_length : Nat
  pricing     : Option PricingInfo
  provider    : Option String
  
-- Pricing Information
structure PricingInfo where
  prompt_token_cost : Double
  completion_token_cost : Double
  request_cost : Option Double
  
-- Model List Response
structure ModelList where
  object : String  -- "list"
  data   : List Model
  
-- ============================================
-- Chat Completion Types
-- ============================================

-- OpenRouter Chat Message
structure ChatMessage where
  role    : Common.MessageRole
  content : Common.MessageContent
  name    : Option String
  
-- OpenRouter Chat Completion Request
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
  | json
  deriving Repr, DecidableEq

-- OpenRouter Chat Completion Choice
structure ChatCompletionChoice where
  index : Nat
  message : ChatMessage
  finish_reason : Option String
  
-- OpenRouter Chat Completion Usage
structure ChatCompletionUsage where
  prompt_tokens     : Nat
  completion_tokens : Nat
  total_tokens      : Nat
  
-- OpenRouter Chat Completion Response
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

-- OpenRouter Embedding Request
structure EmbeddingRequest where
  model  : Common.ModelName
  input  : String
  encoding_format : Option String
  
-- OpenRouter Embedding Data
structure EmbeddingData where
  object    : String  -- "embedding"
  embedding : List Double
  index     : Nat
  
-- OpenRouter Embedding Response
structure EmbeddingResponse where
  object : String  -- "list"
  data   : List EmbeddingData
  model  : Common.ModelName
  usage  : EmbeddingUsage
  
-- OpenRouter Embedding Usage
structure EmbeddingUsage where
  prompt_tokens : Nat
  total_tokens  : Nat
  
-- ============================================
-- API Endpoints
-- ============================================

-- HTTP Method
def HttpMethod : Type := Common.MessageRole  -- Reusing for simplicity, but should be separate

-- Actually, let's define it properly
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

-- ============================================
-- OpenRouter Provider Interface
-- ============================================

-- OpenRouter Provider Capabilities
def openRouterCapabilities : Common.ProviderCapabilities :=
  { supportsChat := true
  , supportsEmbeddings := true
  , supportsFineTuning := false
  , supportsStreaming := true
  , supportsTools := false
  , supportsMultiModal := true
  }

-- OpenRouter Provider Interface
def openRouterProvider : Common.ProviderInterface :=
  { config :=
      { providerName := .OpenRouter
      , apiKey := none
      , baseUrl := baseUrl
      , timeout := 30
      , userAgent := "Gokujo/1.0"
      , defaultModel := some "openai/gpt-3.5-turbo"
      }
  , capabilities := openRouterCapabilities
  }

-- ============================================
-- Gokujo Integration
-- ============================================

-- Gokujo OpenRouter Configuration
structure GokujoOpenRouterConfig where
  apiKey     : Option Common.APIKey
  baseUrl    : String
  timeout    : Nat
  userAgent  : String
  defaultModel : Option Common.ModelName
  siteUrl    : Option String
  siteName   : Option String
  
-- Default Gokujo OpenRouter configuration
def defaultGokujoOpenRouterConfig : GokujoOpenRouterConfig :=
  { apiKey := none
  , baseUrl := baseUrl
  , timeout := 30
  , userAgent := "Gokujo/1.0"
  , defaultModel := some "openai/gpt-3.5-turbo"
  , siteUrl := none
  , siteName := none
  }

-- Gokujo OpenRouter Client
structure GokujoOpenRouterClient where
  config : GokujoOpenRouterConfig
  
-- Create a Gokujo OpenRouter client
def createGokujoOpenRouterClient (config : GokujoOpenRouterConfig) : GokujoOpenRouterClient :=
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

-- Theorem: OpenRouter supports chat
theorem openrouter_supports_chat :
  openRouterCapabilities.supportsChat = true := by
  rfl

-- Theorem: OpenRouter supports embeddings
theorem openrouter_supports_embeddings :
  openRouterCapabilities.supportsEmbeddings = true := by
  rfl

-- Theorem: OpenRouter does not support fine-tuning
theorem openrouter_no_fine_tuning :
  openRouterCapabilities.supportsFineTuning = false := by
  rfl

end Providers
end OpenRouter
