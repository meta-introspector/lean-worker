-- Common.lean
-- Unified interface for LLM providers in Gokujo

namespace Providers
namespace Common

-- ============================================
-- Provider Types
-- ============================================

-- Provider Name
inductive ProviderName
  | Mistral
  | OpenRouter
  | Grok
  | DeepSeek
  | OpenAI
  | Claude
  | Local  -- For local/self-hosted models
  deriving Repr, DecidableEq

-- API Key
def APIKey := String

-- Model Name
def ModelName := String

-- Model ID
def ModelId := String

-- ISO 8601 Timestamp
def ISO8601Timestamp := String

-- Request ID
def RequestId := String

-- ============================================
-- Common Message Types
-- ============================================

-- Message Role (unified across providers)
inductive MessageRole
  | system
  | user
  | assistant
  | tool
  | function
  deriving Repr, DecidableEq

-- Message Content
def MessageContent := String

-- Message
structure Message where
  role    : MessageRole
  content : MessageContent
  name    : Option String  -- Optional name for tool/function messages
  
-- ============================================
-- Common Request Types
-- ============================================

-- Chat Completion Request (unified)
structure ChatCompletionRequest where
  model       : ModelName
  messages    : List Message
  temperature : Option Double
  top_p       : Option Double
  max_tokens  : Option Nat
  stream      : Option Bool
  stop        : Option (List String)
  presence_penalty : Option Double
  frequency_penalty : Option Double
  
-- ============================================
-- Common Response Types
-- ============================================

-- Usage Information
structure Usage where
  prompt_tokens     : Nat
  completion_tokens : Nat
  total_tokens      : Nat
  
-- Completion Choice
structure CompletionChoice where
  index : Nat
  message : Message
  finish_reason : Option String
  
-- Chat Completion Response (unified)
structure ChatCompletionResponse where
  id          : RequestId
  object      : String
  created     : ISO8601Timestamp
  model       : ModelName
  choices     : List CompletionChoice
  usage       : Usage
  
-- ============================================
-- Common Configuration
-- ============================================

-- Provider Configuration
structure ProviderConfig where
  providerName : ProviderName
  apiKey       : Option APIKey
  baseUrl      : String
  timeout      : Nat
  userAgent    : String
  defaultModel : Option ModelName
  
-- ============================================
-- Provider Interface
-- ============================================

-- Provider Capabilities
structure ProviderCapabilities where
  supportsChat : Bool
  supportsEmbeddings : Bool
  supportsFineTuning : Bool
  supportsStreaming : Bool
  supportsTools : Bool
  supportsMultiModal : Bool
  
-- Provider Interface
structure ProviderInterface where
  config : ProviderConfig
  capabilities : ProviderCapabilities
  
-- ============================================
-- Provider Registry
-- ============================================

-- Provider Factory
def ProviderFactory := ProviderName → Option ProviderInterface

-- Registered Providers
def registeredProviders : List (ProviderName × ProviderInterface) := []

-- ============================================
-- Theorems
-- ============================================

-- Theorem: ProviderName is decidable
theorem provider_name_decidable : ∀ (p1 p2 : ProviderName), Decidable (p1 = p2) := by
  intro _ _
  infer_instance

-- Theorem: MessageRole is decidable
theorem message_role_decidable : ∀ (r1 r2 : MessageRole), Decidable (r1 = r2) := by
  intro _ _
  infer_instance

-- Theorem: Provider has capabilities
theorem provider_has_capabilities (provider : ProviderInterface) :
  provider.capabilities = provider.capabilities := by
  rfl

end Providers
end Common
