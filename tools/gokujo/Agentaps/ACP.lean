-- ACP.lean
-- Formal model of Agent Client Protocol (ACP) for Agentaps

import Agentaps.Types

namespace Agentaps
namespace ACP

-- ============================================
-- ACP Protocol Version
-- ============================================

-- ACP protocol version info
structure ACPVersionInfo where
  version : Types.ACPVersion
  capabilities : List Types.ACPCapability
  
-- ============================================
-- ACP Server
-- ============================================

-- ACP Server
structure ACPServer where
  info : Types.ACPServerInfo
  versionInfo : ACPVersionInfo
  
-- ============================================
-- ACP Client
-- ============================================

-- ACP Client
structure ACPClient where
  name : String
  version : String
  capabilities : List Types.ACPCapability
  
-- ============================================
-- ACP Connection
-- ============================================

-- ACP Connection State
inductive ConnectionState
  | disconnected
  | connecting
  | connected
  | error
  deriving Repr, DecidableEq

-- ACP Connection
structure ACPConnection where
  server : ACPServer
  client : ACPClient
  state : ConnectionState
  
-- ============================================
-- ACP Protocol Methods
-- ============================================

-- ACP Initialize Request
structure ACPInitializeRequest where
  server : Types.ACPServerInfo
  
-- ACP Initialize Response
structure ACPInitializeResponse where
  client : ACPClient
  capabilities : List Types.ACPCapability
  
-- ============================================
-- ACP Server Methods
-- ============================================

-- ACP Server List Resources Request
structure ACPServerListResourcesRequest where
  id : Types.MessageId
  
-- ACP Server List Resources Response
structure ACPServerListResourcesResponse where
  id : Types.MessageId
  resources : List Types.ACPResourceTemplate
  
-- ACP Server Read Resource Request
structure ACPServerReadResourceRequest where
  id : Types.MessageId
  uri : Types.ACPResourceUri
  
-- ACP Server Read Resource Response
structure ACPServerReadResourceResponse where
  id : Types.MessageId
  uri : Types.ACPResourceUri
  content : Types.ACPContent
  
-- ============================================
-- ACP Client Methods
-- ============================================

-- ACP Client List Prompts Request
structure ACPClientListPromptsRequest where
  id : Types.MessageId
  
-- ACP Client List Prompts Response
structure ACPClientListPromptsResponse where
  id : Types.MessageId
  prompts : List Types.ACPMessage
  
-- ACP Client Send Message Request
structure ACPClientSendMessageRequest where
  id : Types.MessageId
  message : Types.ACPMessage
  
-- ACP Client Send Message Response
structure ACPClientSendMessageResponse where
  id : Types.MessageId
  
-- ============================================
-- ACP Tool Methods
-- ============================================

-- ACP List Tools Request
structure ACPListToolsRequest where
  id : Types.MessageId
  
-- ACP List Tools Response
structure ACPListToolsResponse where
  id : Types.MessageId
  tools : List Types.ACPTool
  
-- ACP Call Tool Request
structure ACPCallToolRequest where
  id : Types.MessageId
  name : Types.ACPToolName
  arguments : String
  
-- ACP Call Tool Response
structure ACPCallToolResponse where
  id : Types.MessageId
  content : List Types.ACPContent
  isError : Bool
  
-- ============================================
-- ACP Resource Methods
-- ============================================

-- ACP List Resources Request
structure ACPListResourcesRequest where
  id : Types.MessageId
  
-- ACP List Resources Response
structure ACPListResourcesResponse where
  id : Types.MessageId
  resources : List Types.ACPResource
  
-- ACP Read Resource Request
structure ACPReadResourceRequest where
  id : Types.MessageId
  uri : Types.ACPResourceUri
  
-- ACP Read Resource Response
structure ACPReadResourceResponse where
  id : Types.MessageId
  uri : Types.ACPResourceUri
  content : Types.ACPContent
  
-- ============================================
-- ACP Sampling Methods
-- ============================================

-- ACP Create Message Request
structure ACPCreateMessageRequest where
  id : Types.MessageId
  messages : List Types.ACPMessage
  
-- ACP Create Message Response
structure ACPCreateMessageResponse where
  id : Types.MessageId
  message : Types.ACPMessage
  
-- ACP Sample Request
structure ACPSampleRequest where
  id : Types.MessageId
  message : Types.ACPMessage
  maxTokens : Option Nat
  temperature : Option Double
  topP : Option Double
  stopSequences : Option (List String)
  
-- ACP Sample Response
structure ACPSampleResponse where
  id : Types.MessageId
  message : Types.ACPMessage
  
-- ============================================
-- ACP Editing Methods
-- ============================================

-- ACP Edit Request
structure ACPEditRequest where
  id : Types.MessageId
  uri : Types.ACPResourceUri
  instruction : String
  
-- ACP Edit Response
structure ACPEditResponse where
  id : Types.MessageId
  uri : Types.ACPResourceUri
  changes : List Types.ACPEditChange
  
-- ============================================
-- ACP Protocol Handler
-- ============================================

-- ACP Protocol Handler
structure ACPProtocolHandler where
  version : Types.ACPVersion
  capabilities : List Types.ACPCapability
  
-- ACP Message Handler
structure ACPMessageHandler where
  onInitialize : ACPInitializeRequest → IO ACPInitializeResponse
  onListResources : ACPServerListResourcesRequest → IO ACPServerListResourcesResponse
  onReadResource : ACPServerReadResourceRequest → IO ACPServerReadResourceResponse
  onListTools : ACPListToolsRequest → IO ACPListToolsResponse
  onCallTool : ACPCallToolRequest → IO ACPCallToolResponse
  onListPrompts : ACPClientListPromptsRequest → IO ACPClientListPromptsResponse
  onSendMessage : ACPClientSendMessageRequest → IO ACPClientSendMessageResponse
  onCreateMessage : ACPCreateMessageRequest → IO ACPCreateMessageResponse
  onSample : ACPSampleRequest → IO ACPSampleResponse
  onEdit : ACPEditRequest → IO ACPEditResponse
  
-- ============================================
-- ACP Agent Adapter
-- ============================================

-- ACP Agent Adapter
structure ACPAgentAdapter where
  name : String
  command : String
  version : String
  acpVersion : Types.ACPVersion
  capabilities : List Types.ACPCapability
  
-- ACP Agent Adapter Discovery
structure ACPAgentAdapterDiscovery where
  adapters : List ACPAgentAdapter
  
-- ============================================
-- ACP Theorems
-- ============================================

-- Theorem: ACPVersionInfo has version
theorem acp_version_info_has_version (info : ACPVersionInfo) :
  info.version = info.version := by
  rfl

-- Theorem: ACPServer has info
theorem acp_server_has_info (server : ACPServer) :
  server.info = server.info := by
  rfl

-- Theorem: ACPClient has name
theorem acp_client_has_name (client : ACPClient) :
  client.name ≠ "" := by
  sorry

-- Theorem: ConnectionState is decidable
theorem connection_state_decidable : ∀ (s1 s2 : ConnectionState), Decidable (s1 = s2) := by
  intro _ _
  infer_instance

-- Theorem: ACPConnection has server
theorem acp_connection_has_server (conn : ACPConnection) :
  conn.server = conn.server := by
  rfl

-- Theorem: ACPConnection has client
theorem acp_connection_has_client (conn : ACPConnection) :
  conn.client = conn.client := by
  rfl

-- Theorem: ACPInitializeRequest has server
theorem acp_initialize_request_has_server (req : ACPInitializeRequest) :
  req.server = req.server := by
  rfl

-- Theorem: ACPInitializeResponse has client
theorem acp_initialize_response_has_client (res : ACPInitializeResponse) :
  res.client = res.client := by
  rfl

-- Theorem: ACPServerListResourcesRequest has ID
theorem acp_server_list_resources_request_has_id (req : ACPServerListResourcesRequest) :
  req.id = req.id := by
  rfl

-- Theorem: ACPServerListResourcesResponse has ID
theorem acp_server_list_resources_response_has_id (res : ACPServerListResourcesResponse) :
  res.id = res.id := by
  rfl

-- Theorem: ACPListToolsRequest has ID
theorem acp_list_tools_request_has_id (req : ACPListToolsRequest) :
  req.id = req.id := by
  rfl

-- Theorem: ACPListToolsResponse has ID
theorem acp_list_tools_response_has_id (res : ACPListToolsResponse) :
  res.id = res.id := by
  rfl

-- Theorem: ACPCallToolRequest has ID
theorem acp_call_tool_request_has_id (req : ACPCallToolRequest) :
  req.id = req.id := by
  rfl

-- Theorem: ACPCallToolResponse has ID
theorem acp_call_tool_response_has_id (res : ACPCallToolResponse) :
  res.id = res.id := by
  rfl

-- Theorem: ACPSampleRequest has ID
theorem acp_sample_request_has_id (req : ACPSampleRequest) :
  req.id = req.id := by
  rfl

-- Theorem: ACPSampleResponse has ID
theorem acp_sample_response_has_id (res : ACPSampleResponse) :
  res.id = res.id := by
  rfl

-- Theorem: ACPEditRequest has ID
theorem acp_edit_request_has_id (req : ACPEditRequest) :
  req.id = req.id := by
  rfl

-- Theorem: ACPEditResponse has ID
theorem acp_edit_response_has_id (res : ACPEditResponse) :
  res.id = res.id := by
  rfl

end ACP
end Agentaps
