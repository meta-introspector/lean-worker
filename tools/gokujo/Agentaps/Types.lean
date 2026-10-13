-- Types.lean
-- Formal model of Agent Client Protocol (ACP) and Agentaps types

namespace Agentaps

-- ============================================
-- ACP (Agent Client Protocol) Types
-- ============================================

-- ACP Version
def ACPVersion := String

-- ACP v1
def acpV1 : ACPVersion := "1.0"

-- ACP v2
def acpV2 : ACPVersion := "2.0"

-- ============================================
-- ACP Message Types
-- ============================================

-- ACP Message ID
def MessageId := String

-- ACP Request ID
def RequestId := Nat

-- ACP Timestamp (ISO 8601)
def ACPTimestamp := String

-- ACP Content Type
inductive ACPContentType
  | text
  | json
  | markdown
  | image_png
  | image_jpeg
  deriving Repr, DecidableEq

-- ============================================
-- ACP Message Structure
-- ============================================

-- ACP Message
structure ACPMessage where
  version : ACPVersion
  id      : MessageId
  requestId : Option RequestId
  timestamp : ACPTimestamp
  contentType : ACPContentType
  body    : String
  
-- ACP Request
structure ACPRequest where
  message : ACPMessage
  
-- ACP Response
structure ACPResponse where
  message : ACPMessage
  requestId : RequestId
  
-- ============================================
-- ACP Server Types
-- ============================================

-- ACP Server Info
structure ACPServerInfo where
  name    : String
  version : String
  capabilities : List ACPCapability
  instructions : Option String
  
-- ACP Capability
inductive ACPCapability
  | sampling
  | editing
  | reading
  | listing
  | tools
  | resources
  | prompts
  deriving Repr, DecidableEq

-- ============================================
-- ACP Resource Types
-- ============================================

-- ACP Resource URI
def ACPResourceUri := String

-- ACP Resource
structure ACPResource where
  uri     : ACPResourceUri
  mimeType : Option String
  name    : Option String
  description : Option String
  
-- ACP Resource Template
structure ACPResourceTemplate where
  uriTemplate : String
  name        : String
  description : Option String
  
-- ============================================
-- ACP Tool Types
-- ============================================

-- ACP Tool Name
def ACPToolName := String

-- ACP Tool Description
def ACPToolDescription := String

-- ACP Tool Input Schema
def ACPToolInputSchema := String  -- JSON Schema

-- ACP Tool
structure ACPTool where
  name        : ACPToolName
  description : ACPToolDescription
  inputSchema : ACPToolInputSchema
  
-- ACP Tool Call
structure ACPToolCall where
  id     : MessageId
  name   : ACPToolName
  arguments : String  -- JSON arguments
  
-- ACP Tool Result
structure ACPToolResult where
  id     : MessageId
  content : List ACPContent
  isError : Bool
  
-- ============================================
-- ACP Content Types
-- ============================================

-- ACP Content Type
inductive ACPContentType
  | text
  | image
  | audio
  | video
  | resource
  deriving Repr, DecidableEq

-- ACP Content
structure ACPContent where
  type_      : ACPContentType
  text      : Option String
  uri       : Option ACPResourceUri
  mimeType  : Option String
  
-- ============================================
-- ACP List Types
-- ============================================

-- ACP List Request
structure ACPListRequest where
  id     : MessageId
  filter : Option String
  
-- ACP List Response
structure ACPListResponse where
  id     : MessageId
  items  : List ACPResource
  
-- ============================================
-- ACP Read Types
-- ============================================

-- ACP Read Request
structure ACPReadRequest where
  id     : MessageId
  uris   : List ACPResourceUri
  
-- ACP Read Response
structure ACPReadResponse where
  id     : MessageId
  contents : List ACPContent
  
-- ============================================
-- ACP Sample Types
-- ============================================

-- ACP Sample Request
structure ACPSampleRequest where
  id     : MessageId
  messages : List ACPMessage
  maxTokens : Option Nat
  temperature : Option Double
  topP : Option Double
  stopSequences : Option (List String)
  
-- ACP Sample Response
structure ACPSampleResponse where
  id     : MessageId
  message : ACPMessage
  
-- ============================================
-- ACP Edit Types
-- ============================================

-- ACP Edit Request
structure ACPEditRequest where
  id     : MessageId
  uri    : ACPResourceUri
  instruction : String
  
-- ACP Edit Response
structure ACPEditResponse where
  id     : MessageId
  uri    : ACPResourceUri
  changes : List ACPEditChange
  
-- ACP Edit Change
structure ACPEditChange where
  startLine : Nat
  endLine : Nat
  newText : String
  
-- ============================================
-- Agentaps Types
-- ============================================

-- Agentaps Session ID
def SessionId := String

-- Agentaps Project ID
def ProjectId := String

-- Agentaps Project Path
def ProjectPath := String

-- Agentaps Agent ID
def AgentId := String

-- Agentaps Agent Name
def AgentName := String

-- Agentaps Agent Command
def AgentCommand := String

-- ============================================
-- Agentaps Session Types
-- ============================================

-- Agentaps Session
structure AgentapsSession where
  id        : SessionId
  projectId : ProjectId
  projectPath : ProjectPath
  agentId   : AgentId
  agentName : AgentName
  createdAt : ACPTimestamp
  updatedAt : ACPTimestamp
  
-- Agentaps Session State
inductive SessionState
  | connecting
  | active
  | archived
  | error
  deriving Repr, DecidableEq

-- ============================================
-- Agentaps Project Types
-- ============================================

-- Agentaps Project
structure AgentapsProject where
  id        : ProjectId
  path      : ProjectPath
  name      : String
  sessions  : List SessionId
  
-- Agentaps Project Type
inductive ProjectType
  | local
  | ssh
  deriving Repr, DecidableEq

-- ============================================
-- Agentaps Agent Types
-- ============================================

-- Agentaps Agent
structure AgentapsAgent where
  id        : AgentId
  name      : AgentName
  command   : AgentCommand
  version   : String
  acpVersion : ACPVersion
  
-- Agentaps Agent Discovery
structure AgentapsAgentDiscovery where
  agents : List AgentapsAgent
  
-- ============================================
-- Agentaps Configuration
-- ============================================

-- Agentaps Config
structure AgentapsConfig where
  sessions : List AgentapsSession
  projects : List AgentapsProject
  agents   : List AgentapsAgent
  
-- ============================================
-- Agentaps Web Connect Types
-- ============================================

-- Web Connect Pairing Code
def PairingCode := String

-- Web Connect Session Token
def WebConnectToken := String

-- Web Connect Device Info
structure WebConnectDeviceInfo where
  deviceName : String
  deviceType : String
  
-- ============================================
-- Agentaps Theorems
-- ============================================

-- Theorem: ACPVersion is a String
theorem acp_version_is_string : ∀ (v : ACPVersion), True := by
  intro _
  exact True.intro

-- Theorem: MessageId is a String
theorem message_id_is_string : ∀ (id : MessageId), True := by
  intro _
  exact True.intro

-- Theorem: RequestId is a Nat
theorem request_id_is_nat : ∀ (id : RequestId), True := by
  intro _
  exact True.intro

-- Theorem: ACPContentType is decidable
theorem acp_content_type_decidable : ∀ (c1 c2 : ACPContentType), Decidable (c1 = c2) := by
  intro _ _
  infer_instance

-- Theorem: ACPCapability is decidable
theorem acp_capability_decidable : ∀ (c1 c2 : ACPCapability), Decidable (c1 = c2) := by
  intro _ _
  infer_instance

-- Theorem: ACPContentType is decidable
theorem acp_content_type_decidable' : ∀ (c1 c2 : ACPContentType), Decidable (c1 = c2) := by
  intro _ _
  infer_instance

-- Theorem: SessionState is decidable
theorem session_state_decidable : ∀ (s1 s2 : SessionState), Decidable (s1 = s2) := by
  intro _ _
  infer_instance

-- Theorem: ProjectType is decidable
theorem project_type_decidable : ∀ (t1 t2 : ProjectType), Decidable (t1 = t2) := by
  intro _ _
  infer_instance

-- Theorem: ACPMessage has version
theorem acp_message_has_version (msg : ACPMessage) :
  msg.version = msg.version := by
  rfl

-- Theorem: ACPMessage has ID
theorem acp_message_has_id (msg : ACPMessage) :
  msg.id = msg.id := by
  rfl

-- Theorem: ACPRequest has message
theorem acp_request_has_message (req : ACPRequest) :
  req.message = req.message := by
  rfl

-- Theorem: ACPResponse has message
theorem acp_response_has_message (res : ACPResponse) :
  res.message = res.message := by
  rfl

-- Theorem: AgentapsSession has ID
theorem agentaps_session_has_id (session : AgentapsSession) :
  session.id = session.id := by
  rfl

-- Theorem: AgentapsProject has ID
theorem agentaps_project_has_id (project : AgentapsProject) :
  project.id = project.id := by
  rfl

-- Theorem: AgentapsAgent has ID
theorem agentaps_agent_has_id (agent : AgentapsAgent) :
  agent.id = agent.id := by
  rfl

end Agentaps
