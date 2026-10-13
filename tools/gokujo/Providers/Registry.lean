-- Registry.lean
-- Unified Provider Registry for Gokujo

import Providers.Common
import Providers.Mistral.API
import Providers.OpenRouter
import Providers.Grok
import Providers.DeepSeek
import Providers.OpenAI
import Providers.Claude

namespace Providers
namespace Registry

-- ============================================
-- Provider Registry
-- ============================================

-- Provider Entry
structure ProviderEntry where
  name : Common.ProviderName
  interface : Common.ProviderInterface
  config : Common.ProviderConfig
  
-- Provider Registry
structure ProviderRegistry where
  providers : List ProviderEntry
  default_provider : Option Common.ProviderName
  
-- ============================================
-- Default Registry
-- ============================================

-- Create default provider registry with all supported providers
def defaultProviderRegistry : ProviderRegistry :=
  { providers :=
      [ -- Mistral
        { name := .Mistral
        , interface := 
            { config :=
                { providerName := .Mistral
                , apiKey := none
                , baseUrl := Mistral.API.baseUrl
                , timeout := 30
                , userAgent := "Gokujo/1.0"
                , defaultModel := some "mistral-tiny"
                }
            , capabilities :=
                { supportsChat := true
                , supportsEmbeddings := true
                , supportsFineTuning := true
                , supportsStreaming := true
                , supportsTools := false
                , supportsMultiModal := false
                }
            }
        , config :=
            { providerName := .Mistral
            , apiKey := none
            , baseUrl := Mistral.API.baseUrl
            , timeout := 30
            , userAgent := "Gokujo/1.0"
            , defaultModel := some "mistral-tiny"
            }
        }
      , -- OpenRouter
        { name := .OpenRouter
        , interface := OpenRouter.openRouterProvider
        , config := OpenRouter.defaultOpenRouterConfig
        }
      , -- Grok
        { name := .Grok
        , interface := Grok.grokProvider
        , config := Grok.defaultGrokConfig
        }
      , -- DeepSeek
        { name := .DeepSeek
        , interface := DeepSeek.deepSeekProvider
        , config := DeepSeek.defaultDeepSeekConfig
        }
      , -- OpenAI
        { name := .OpenAI
        , interface := OpenAI.openAIProvider
        , config := OpenAI.defaultOpenAIConfig
        }
      , -- Claude
        { name := .Claude
        , interface := Claude.claudeProvider
        , config := Claude.defaultClaudeConfig
        }
      ]
  , default_provider := some .Mistral
  }

-- ============================================
-- Registry Operations
-- ============================================

-- Get a provider by name
def getProvider (registry : ProviderRegistry) (name : Common.ProviderName) : Option ProviderEntry :=
  registry.providers.find? fun entry => entry.name = name

-- Get all providers
def getAllProviders (registry : ProviderRegistry) : List ProviderEntry :=
  registry.providers

-- Get default provider
def getDefaultProvider (registry : ProviderRegistry) : Option ProviderEntry :=
  match registry.default_provider with
  | some name => getProvider registry name
  | none => registry.providers.head?

-- Add a provider to registry
def addProvider (registry : ProviderRegistry) (entry : ProviderEntry) : ProviderRegistry :=
  { registry with
    providers := registry.providers ++ [entry]
  }

-- Remove a provider from registry
def removeProvider (registry : ProviderRegistry) (name : Common.ProviderName) : ProviderRegistry :=
  { registry with
    providers := registry.providers.filter fun entry => entry.name ≠ name
  }

-- Set default provider
def setDefaultProvider (registry : ProviderRegistry) (name : Common.ProviderName) : ProviderRegistry :=
  { registry with
    default_provider := some name
  }

-- ============================================
-- Provider Selection
-- ============================================

-- Provider Selection Criteria
structure ProviderSelectionCriteria where
  required_capabilities : Common.ProviderCapabilities
  preferred_providers : List Common.ProviderName
  excluded_providers : List Common.ProviderName
  cost_preference : Option CostPreference
  performance_preference : Option PerformancePreference
  
-- Cost Preference
inductive CostPreference
  | Cheapest
  | Moderate
  | Premium
  deriving Repr, DecidableEq

-- Performance Preference
inductive PerformancePreference
  | Fastest
  | Balanced
  | MostAccurate
  deriving Repr, DecidableEq

-- Select best provider based on criteria
def selectBestProvider
  (registry : ProviderRegistry)
  (criteria : ProviderSelectionCriteria)
  : Option ProviderEntry := by
  -- Filter providers by required capabilities
  let capable_providers := registry.providers.filter fun entry =>
    let caps := entry.interface.capabilities
    caps.supportsChat = criteria.required_capabilities.supportsChat ∧
    caps.supportsEmbeddings = criteria.required_capabilities.supportsEmbeddings ∧
    caps.supportsFineTuning = criteria.required_capabilities.supportsFineTuning ∧
    caps.supportsStreaming = criteria.required_capabilities.supportsStreaming ∧
    caps.supportsTools = criteria.required_capabilities.supportsTools ∧
    caps.supportsMultiModal = criteria.required_capabilities.supportsMultiModal
  
  -- Filter by preferred providers
  let preferred := if criteria.preferred_providers.isEmpty then
    capable_providers
  else
    capable_providers.filter fun entry =>
      criteria.preferred_providers.contains entry.name
  
  -- Filter out excluded providers
  let available := preferred.filter fun entry =>
    !criteria.excluded_providers.contains entry.name
  
  -- Select based on preferences
  match available.head? with
  | some provider => some provider
  | none => capable_providers.head?

-- Select provider by name
def selectProviderByName
  (registry : ProviderRegistry)
  (name : Common.ProviderName)
  : Option ProviderEntry :=
  getProvider registry name

-- Select default provider
def selectDefaultProvider (registry : ProviderRegistry) : Option ProviderEntry :=
  getDefaultProvider registry

-- ============================================
-- Provider Factory
-- ============================================

-- Create a provider client based on selection
def createProviderClient
  (registry : ProviderRegistry)
  (selection : ProviderSelectionCriteria)
  : Option Common.ProviderInterface := by
  match selectBestProvider registry selection with
  | some entry => some entry.interface
  | none => none

-- ============================================
-- Multi-Provider Configuration
-- ============================================

-- Multi-Provider Strategy
inductive MultiProviderStrategy
  | Single of Common.ProviderName  -- Use single provider
  | Fallback of List Common.ProviderName  -- Try providers in order
  | LoadBalanced of List Common.ProviderName  -- Load balance across providers
  | CostOptimized  -- Always use cheapest available
  | PerformanceOptimized  -- Always use fastest/most accurate
  | Custom of String
  deriving Repr, DecidableEq

-- Multi-Provider Config
structure MultiProviderConfig where
  strategy : MultiProviderStrategy
  registry : ProviderRegistry
  criteria : Option ProviderSelectionCriteria
  
-- Default multi-provider config
def defaultMultiProviderConfig : MultiProviderConfig :=
  { strategy := .Fallback [.Mistral, .OpenRouter, .OpenAI, .Grok, .DeepSeek, .Claude]
  , registry := defaultProviderRegistry
  , criteria := none
  }

-- ============================================
-- Theorems
-- ============================================

-- Theorem: defaultProviderRegistry has providers
theorem default_registry_has_providers :
  defaultProviderRegistry.providers.length > 0 := by
  simp [defaultProviderRegistry]
  decide

-- Theorem: getProvider returns provider or none
theorem get_provider_returns_option (registry : ProviderRegistry) (name : Common.ProviderName) :
  getProvider registry name = registry.providers.find? fun entry => entry.name = name := by
  rfl

-- Theorem: addProvider adds provider to registry
theorem add_provider_adds_to_registry
  (registry : ProviderRegistry)
  (entry : ProviderEntry) :
  (addProvider registry entry).providers.length = registry.providers.length + 1 := by
  simp [addProvider, List.length_append]

-- Theorem: removeProvider removes provider from registry
theorem remove_provider_removes_from_registry
  (registry : ProviderRegistry)
  (name : Common.ProviderName) :
  (removeProvider registry name).providers.length ≤ registry.providers.length := by
  simp [removeProvider]
  apply List.length_filter_le

-- Theorem: setDefaultProvider sets default
theorem set_default_provider_sets_default
  (registry : ProviderRegistry)
  (name : Common.ProviderName) :
  (setDefaultProvider registry name).default_provider = some name := by
  rfl

-- Theorem: CostPreference is decidable
theorem cost_preference_decidable : ∀ (c1 c2 : CostPreference), Decidable (c1 = c2) := by
  intro _ _
  infer_instance

-- Theorem: PerformancePreference is decidable
theorem performance_preference_decidable : ∀ (p1 p2 : PerformancePreference), Decidable (p1 = p2) := by
  intro _ _
  infer_instance

-- Theorem: MultiProviderStrategy is decidable
theorem multi_provider_strategy_decidable : ∀ (s1 s2 : MultiProviderStrategy), Decidable (s1 = s2) := by
  intro _ _
  infer_instance

end Providers
end Registry
