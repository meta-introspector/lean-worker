# Agentaps Integration for Gokujo

This directory contains formal Lean 4 models of **Agentaps** and the **Agent Client Protocol (ACP)** for integration with the Gokujo build system.

## Structure

```
tools/gokujo/Agentaps/
├── Types.lean          # Core Agentaps and ACP types
├── ACP.lean            # Agent Client Protocol formal model
├── Integration.lean    # Gokujo-Agentaps integration
└── README.md           # This file
```

## What is Agentaps?

[Agentaps](https://github.com/domenkozar/agentaps) is a **desktop workspace for coding agents** that speak the **Agent Client Protocol (ACP)**. It allows you to:

- Run agents in local projects or over SSH
- Keep conversations together
- Continue from a phone browser when you step away
- Review local changes with diff view
- Use agent controls (models, reasoning effort, slash commands)
- Work with ACP-compatible agents (Codex, Claude, Gemini CLI, OpenCode, etc.)

## Types Modeled

### ACP Types (`Types.lean`)

#### Primitive Types
- `ACPVersion`, `MessageId`, `RequestId`, `ACPTimestamp`
- `ACPContentType` (text, json, markdown, image_png, image_jpeg)

#### Message Types
- `ACPMessage`, `ACPRequest`, `ACPResponse`

#### Server Types
- `ACPServerInfo`, `ACPCapability` (sampling, editing, reading, listing, tools, resources, prompts)

#### Resource Types
- `ACPResourceUri`, `ACPResource`, `ACPResourceTemplate`

#### Tool Types
- `ACPToolName`, `ACPToolDescription`, `ACPToolInputSchema`
- `ACPTool`, `ACPToolCall`, `ACPToolResult`

#### Content Types
- `ACPContentType`, `ACPContent`

#### List Types
- `ACPListRequest`, `ACPListResponse`

#### Read Types
- `ACPReadRequest`, `ACPReadResponse`

#### Sample Types
- `ACPSampleRequest`, `ACPSampleResponse`

#### Edit Types
- `ACPEditRequest`, `ACPEditResponse`, `ACPEditChange`

### Agentaps Types (`Types.lean`)

#### Primitive Types
- `SessionId`, `ProjectId`, `ProjectPath`, `AgentId`, `AgentName`, `AgentCommand`

#### Session Types
- `AgentapsSession`, `SessionState` (connecting, active, archived, error)

#### Project Types
- `AgentapsProject`, `ProjectType` (local, ssh)

#### Agent Types
- `AgentapsAgent`, `AgentapsAgentDiscovery`

#### Configuration Types
- `AgentapsConfig`

#### Web Connect Types
- `PairingCode`, `WebConnectToken`, `WebConnectDeviceInfo`

### ACP Protocol Types (`ACP.lean`)

#### Protocol Types
- `ACPVersionInfo`, `ACPServer`, `ACPClient`
- `ConnectionState`, `ACPConnection`

#### Protocol Methods
- `ACPInitializeRequest`, `ACPInitializeResponse`

#### Server Methods
- `ACPServerListResourcesRequest`, `ACPServerListResourcesResponse`
- `ACPServerReadResourceRequest`, `ACPServerReadResourceResponse`

#### Client Methods
- `ACPClientListPromptsRequest`, `ACPClientListPromptsResponse`
- `ACPClientSendMessageRequest`, `ACPClientSendMessageResponse`

#### Tool Methods
- `ACPListToolsRequest`, `ACPListToolsResponse`
- `ACPCallToolRequest`, `ACPCallToolResponse`

#### Resource Methods
- `ACPListResourcesRequest`, `ACPListResourcesResponse`
- `ACPReadResourceRequest`, `ACPReadResourceResponse`

#### Sampling Methods
- `ACPCreateMessageRequest`, `ACPCreateMessageResponse`
- `ACPSampleRequest`, `ACPSampleResponse`

#### Editing Methods
- `ACPEditRequest`, `ACPEditResponse`

#### Protocol Handler
- `ACPProtocolHandler`, `ACPMessageHandler`

#### Agent Adapter
- `ACPAgentAdapter`, `ACPAgentAdapterDiscovery`

### Integration Types (`Integration.lean`)

#### Configuration
- `GokujoAgentapsConfig`

#### Session
- `GokujoAgentapsSession`

#### Project
- `GokujoAgentapsProject`

#### Agent
- `GokujoAgentapsAgent`

#### Commands
- `GokujoAgentapsStartSessionCommand`
- `GokujoAgentapsSendMessageCommand`
- `GokujoAgentapsStopSessionCommand`
- `GokujoAgentapsArchiveSessionCommand`
- `GokujoAgentapsListSessionsCommand`
- `GokujoAgentapsListProjectsCommand`
- `GokujoAgentapsListAgentsCommand`

#### Results
- `GokujoAgentapsResult`
- `GokujoAgentapsSessionResult`
- `GokujoAgentapsMessageResult`
- `GokujoAgentapsListResult`

#### ACP Integration
- `GokujoACPProtocolHandler`, `GokujoACPClient`

#### Workflow
- `GokujoAgentapsWorkflowStep`, `GokujoAgentapsAction`, `GokujoAgentapsWorkflow`

## Usage

### Import the Agentaps module

```lean
import Agentaps.Types
import Agentaps.ACP
import Agentaps.GokujoIntegration
```

### Create an Agentaps session

```lean
open Agentaps

def mySession : GokujoIntegration.GokujoAgentapsSession :=
  { sessionId := "session-123"
  , projectId := "project-456"
  , projectPath := "/path/to/project"
  , agentId := "codex"
  , agentName := "Codex"
  , acpVersion := Types.acpV2
  , createdAt := "2024-01-01T00:00:00Z"
  , updatedAt := "2024-01-01T00:00:00Z"
  , state := Types.SessionState.active
  }
```

### Create an Agentaps project

```lean
open Agentaps GokujoIntegration

def myProject := createGokujoAgentapsProject 
  "/path/to/project" Types.ProjectType.local
```

### Create an Agentaps agent

```lean
open Agentaps GokujoIntegration

def myAgent := createGokujoAgentapsAgent 
  "codex" "Codex" "codex --acp"
```

### Create commands

```lean
open Agentaps GokujoIntegration

-- Start session
def startCmd := createStartSessionCommand 
  "/path/to/project" "codex"

-- Send message
def sendCmd := createSendMessageCommand 
  "session-123" "Hello, Codex!"
```

### Create a workflow

```lean
open Agentaps GokujoIntegration

def myWorkflow := createAgentapsWorkflow "codex-workflow"
```

## ACP Version Support

The model supports both **ACP v1** and **ACP v2**:

```lean
open Agentaps Types

-- ACP v1
#eval acpV1  -- "1.0"

-- ACP v2
#eval acpV2  -- "2.0"
```

## ACP Capabilities

The following ACP capabilities are modeled:
- `sampling` - Generate text responses
- `editing` - Edit resources
- `reading` - Read resources
- `listing` - List resources
- `tools` - Use tools
- `resources` - Resource management
- `prompts` - Prompt management

## Integration with Gokujo

The Agentaps integration allows Gokujo to:

1. **Start Agentaps sessions** - Launch agents in projects
2. **Send messages** - Communicate with agents
3. **Stop/Archive sessions** - Manage session lifecycle
4. **List sessions/projects/agents** - Discover available resources
5. **Handle ACP protocol** - Implement ACP v1 and v2
6. **Use ACP tools** - Call agent tools
7. **Process ACP responses** - Handle agent outputs

## ACP Protocol Flow

```
Client (Gokujo)              Server (Agentaps/Agent)
     |                           |
     |-- Initialize -->----------|  (ACPInitializeRequest)
     |<-- Initialize -----------|  (ACPInitializeResponse)
     |                           |
     |-- ListResources -->-----|  (ACPListResourcesRequest)
     |<-- ListResources -------|  (ACPListResourcesResponse)
     |                           |
     |-- ListTools -->---------|  (ACPListToolsRequest)
     |<-- ListTools -----------|  (ACPListToolsResponse)
     |                           |
     |-- CallTool -->----------|  (ACPCallToolRequest)
     |<-- CallTool ------------|  (ACPCallToolResponse)
     |                           |
     |-- Sample -->------------|  (ACPSampleRequest)
     |<-- Sample ---------------|  (ACPSampleResponse)
     |                           |
```

## Compilation

```bash
# Compile the Agentaps module
cd /workspace/github__meta-introspector__lean-worker
. ~/.elan/env
LEAN_PATH=tools/gokujo/Agentaps lean -R tools/gokujo/Agentaps Types.lean
LEAN_PATH=tools/gokujo/Agentaps lean -R tools/gokujo/Agentaps ACP.lean
LEAN_PATH=tools/gokujo/Agentaps lean -R tools/gokujo/Agentaps Integration.lean
```

## Next Steps

1. Fill in the `sorry` placeholders with actual proofs
2. Add more detailed ACP protocol handling
3. Add Agentaps-specific features (diff view, SSH projects, Web Connect)
4. Add examples of complete Agentaps workflows
5. Add validation theorems for Agentaps configurations
6. Integrate with actual Agentaps via FFI or subprocess

## References

- [Agentaps GitHub](https://github.com/domenkozar/agentaps)
- [Agent Client Protocol](https://agentclientprotocol.com/get-started/introduction)
- [ACP Specification](https://github.com/modelcontextprotocol/agent-client-protocol)
