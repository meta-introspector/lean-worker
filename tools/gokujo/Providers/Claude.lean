-- Claude.lean
-- Anthropic Claude API formal model for Gokujo

import Providers.Common

namespace Providers
namespace Claude

-- ============================================
-- Claude Configuration
-- ============================================

-- Claude API base URL
def baseUrl : String := "https://api.anthropic.com/v1"

-- Claude API configuration
structure ClaudeConfig where
  apiKey     : Option Common.APIKey
  baseUrl    : String
  timeout    : Nat
  userAgent  : String
  defaultModel : Option Common.ModelName
  
-- Default Claude configuration
def defaultClaudeConfig : ClaudeConfig :=
  { apiKey := none
  , baseUrl := baseUrl
  , timeout := 30
  , userAgent := "Gokujo/1.0"
  , defaultModel := some "claude-3-sonnet-20240229"
  }

-- ============================================
-- Claude Types
-- ============================================

-- Claude Model
structure Model where
  id          : Common.ModelId
  name        : Common.ModelName
  created     : Common.ISO8601Timestamp
  description : Option String
  context_length : Nat
  input_price : Option Double
  output_price : Option Double
  
-- Model List Response
structure ModelList where
  object : String  -- "list"
  data   : List Model
  
-- ============================================
-- Messages API Types (Claude 3+)
-- ============================================

-- Content Block Type
inductive ContentBlockType
  | text
  | image
  deriving Repr, DecidableEq

-- Content Block
structure ContentBlock where
  type : ContentBlockType
  text : Option String
  image : Option ImageBlock
  
-- Image Block
structure ImageBlock where
  source : ImageSource
  
-- Image Source
inductive ImageSource
  | base64 of String  -- Base64 encoded image
  | url of String     -- URL to image
  deriving Repr, DecidableEq

-- Message
structure Message where
  role    : Common.MessageRole
  content : List ContentBlock
  
-- ============================================
-- Chat Completion Types
-- ============================================

-- Claude Chat Completion Request
structure ChatCompletionRequest where
  model       : Common.ModelName
  messages    : List Message
  max_tokens  : Nat
  temperature : Option Double
  top_p       : Option Double
  top_k       : Option Nat
  stream      : Option Bool
  stop_sequences : Option (List String)
  anthropic_version : Option String
  
-- Claude Chat Completion Choice
structure ChatCompletionChoice where
  index : Nat
  message : Message
  finish_reason : Option String
  
-- Claude Chat Completion Usage
structure ChatCompletionUsage where
  input_tokens     : Nat
  output_tokens    : Nat
  
-- Claude Chat Completion Response
structure ChatCompletionResponse where
  id          : Common.RequestId
  type        : String  -- "message"
  role        : Common.MessageRole
  content     : List ContentBlock
  model       : Common.ModelName
  stop_reason : Option String
  stop_sequence : Option String
  usage       : ChatCompletionUsage
  
-- ============================================
-- Legacy Text Completion Types
-- ============================================

-- Text Completion Request
structure TextCompletionRequest where
  prompt : String
  max_tokens_to_sample : Nat
  model : Common.ModelName
  temperature : Option Double
  top_p : Option Double
  top_k : Option Nat
  stream : Option Bool
  stop_sequences : Option (List String)
  anthropic_version : Option String
  
-- Text Completion Response
structure TextCompletionResponse where
  completion : String
  stop_reason : Option String
  stop_sequence : Option String
  
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
  
-- List models endpoint (hypothetical - Claude doesn't have public model listing)
def listModelsEndpoint : Endpoint :=
  { method := .GET
  , path := "/models"
  }

-- Get model endpoint
def getModelEndpoint : Common.ModelId → Endpoint := fun modelId =>
  { method := .GET
  , path := "/models/" ++ modelId
  }

-- Create chat completion endpoint (Messages API)
def createChatCompletionEndpoint : Endpoint :=
  { method := .POST
  , path := "/messages"
  }

-- Create text completion endpoint (Legacy)
def createTextCompletionEndpoint : Endpoint :=
  { method := .POST
  , path := "/complete"
  }

-- ============================================
-- Claude Provider Interface
-- ============================================

-- Claude Provider Capabilities
def claudeCapabilities : Common.ProviderCapabilities :=
  { supportsChat := true
  , supportsEmbeddings := false
  , supportsFineTuning := false
  , supportsStreaming := true
  , supportsTools := true
  , supportsMultiModal := true
  }

-- Claude Provider Interface
def claudeProvider : Common.ProviderInterface :=
  { config :=
      { providerName := .Claude
      , apiKey := none
      , baseUrl := baseUrl
      , timeout := 30
      , userAgent := "Gokujo/1.0"
      , defaultModel := some "claude-3-sonnet-20240229"
      }
  , capabilities := claudeCapabilities
  }

-- ============================================
-- Gokujo Integration
-- ============================================

-- Gokujo Claude Configuration
structure GokujoClaudeConfig where
  apiKey     : Option Common.APIKey
  baseUrl    : String
  timeout    : Nat
  userAgent  : String
  defaultModel : Option Common.ModelName
  
-- Default Gokujo Claude configuration
def defaultGokujoClaudeConfig : GokujoClaudeConfig :=
  { apiKey := none
  , baseUrl := baseUrl
  , timeout := 30
  , userAgent := "Gokujo/1.0"
  , defaultModel := some "claude-3-sonnet-20240229"
  }

-- Gokujo Claude Client
structure GokujoClaudeClient where
  config : GokujoClaudeConfig
  
-- Create a Gokujo Claude client
def createGokujoClaudeClient (config : GokujoClaudeConfig) : GokujoClaudeClient :=
  { config := config }

-- ============================================
-- Theorems
-- ============================================

-- Theorem: createChatCompletionEndpoint is POST
theorem create_chat_completion_endpoint_is_post :
  createChatCompletionEndpoint.method = .POST := by
  rfl

-- Theorem: createTextCompletionEndpoint is POST
theorem create_text_completion_endpoint_is_post :
  createTextCompletionEndpoint.method = .POST := by
  rfl

-- Theorem: Claude supports chat
theorem claude_supports_chat :
  claudeCapabilities.supportsChat = true := by
  rfl

-- Theorem: Claude supports multi-modal
theorem claude_supports_multimodal :
  claudeCapabilities.supportsMultiModal = true := by
  rfl

-- Theorem: Claude supports tools
theorem claude_supports_tools :
  claudeCapabilities.supportsTools = true := by
  rfl

-- Theorem: Claude does not support embeddings
theorem claude_no_embeddings :
  claudeCapabilities.supportsEmbeddings = false := by
  rfl

-- Theorem: Claude does not support fine-tuning
theorem claude_no_fine_tuning :
  claudeCapabilities.supportsFineTuning = false := by
  rfl

end Providers
end Claude
