-- Agent.lean
-- Formalization of "minimal agent" identity, capabilities, and constraints

namespace Agent

-- ============================================
-- Fundamental Identity
-- ============================================

opaque AgentId : Type
opaque AgentName : Type
opaque Platform : Type

-- ============================================
-- Capabilities
-- ============================================

structure Capabilities where
  canInstall    : Bool
  canReadFiles  : Bool
  canRunShell   : Bool
  canFetch      : Bool
  canSearch     : Bool
  canManage     : Bool
  canExpose     : Bool
  canGenerate   : Bool
  canMemory     : Bool

-- Helper: convert a Bool capability to a Prop
def capToProp (c : Bool) : Prop := c = true

-- Full root access
def hasFullRootAccess (c : Capabilities) : Prop :=
  capToProp c.canInstall ∧ capToProp c.canRunShell ∧ capToProp c.canReadFiles

-- All capabilities enabled
def hasAllCapabilities (c : Capabilities) : Prop :=
  capToProp c.canInstall ∧ capToProp c.canReadFiles ∧ capToProp c.canRunShell ∧
  capToProp c.canFetch ∧ capToProp c.canSearch ∧ capToProp c.canManage ∧
  capToProp c.canExpose ∧ capToProp c.canGenerate ∧ capToProp c.canMemory

-- ============================================
-- Constraints
-- ============================================

abbrev HasRestrictions := List String

-- ============================================
-- Operational Environment
-- ============================================

structure Environment where
  system       : String
  cloudProvider: String
  workspace    : String
  publicURL    : String
  date         : String

-- ============================================
-- Persistent Memory
-- ============================================

structure MemoryRecord where
  kind     : String
  content  : String
  source   : String

abbrev Memory := List MemoryRecord

-- ============================================
-- Skills
-- ============================================

structure Skill where
  name        : String
  description : String
  trigger     : String
  steps       : List String

abbrev Skills := List Skill

-- ============================================
-- The Agent State
-- ============================================

structure AgentState where
  id           : AgentId
  name         : AgentName
  capabilities : Capabilities
  environment  : Environment
  memory       : Memory
  skills       : Skills
  restrictions : HasRestrictions

-- ============================================
-- Core Theorems
-- ============================================

-- Theorem: An agent with all capabilities enabled has full root access.
-- The proof uses "obtain" to destruct the conjunctive hypothesis cleanly.
theorem hasAllCapabilities_impliesRoot :
  ∀ (a : AgentState), hasAllCapabilities a.capabilities → hasFullRootAccess a.capabilities := by
  intros a h
  obtain ⟨hInstall, hRead, hShell, _, _, _, _, _, _⟩ := h
  exact ⟨hInstall, hShell, hRead⟩

-- Theorem: memory persistence — an agent that has recorded anything keeps a
-- non-empty memory.
--
-- Fixed: the original `I_amPersistent` and `properAgent` both concluded `True`,
-- i.e. they asserted nothing.  They are restated here with content.
theorem memory_persists :
  ∀ (a : AgentState), a.memory ≠ [] → a.memory.length > 0 := by
  intro a h
  cases hm : a.memory with
  | nil => exact absurd hm h
  | cons _ _ => simp

-- Theorem: An agent with root access and restrictions is a proper agent:
-- it can act, and its acting is constrained.
def IsProperAgent (a : AgentState) : Prop :=
  hasFullRootAccess a.capabilities ∧ a.restrictions ≠ []

theorem properAgent :
  ∀ (a : AgentState),
    hasFullRootAccess a.capabilities →
    a.restrictions.length > 0 →
    IsProperAgent a := by
  intro a hroot hres
  refine ⟨hroot, ?_⟩
  intro h
  rw [h] at hres
  exact absurd hres (by simp)

end Agent
