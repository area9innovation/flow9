# Unified MCP + A2A Server in Flow9

A comprehensive server implementation that supports both **Model Context Protocol (MCP) 2.0** and **Google's Agent-to-Agent (A2A) Protocol**, built in Flow9 for seamless agent interoperability.

## 🌟 Overview

This unified server bridges two important protocols for AI agent communication:

- **MCP (Model Context Protocol)**: Connects agents to tools, APIs, and resources with structured inputs/outputs
- **A2A (Agent2Agent Protocol)**: Facilitates dynamic, multimodal communication between different agents as peers

## ✨ Features

### 🔌 **MCP Protocol Support**
- ✅ **MCP Protocol v2024-11-05** compliance
- ✅ **JSON-RPC 2.0** transport layer
- ✅ **Tools** - Executable functions with JSON Schema validation
- ✅ **Resources** - URI-addressable content (files, data, APIs)
- ✅ **Prompts** - Template prompts with parameter substitution
- ✅ **Logging** - Structured logging with configurable levels

### 🤖 **A2A Protocol Support**
- ✅ **Agent Discovery** - Published Agent Card at `/.well-known/agent.json`
- ✅ **Task Management** - Create, query, cancel stateful tasks
- ✅ **Message Exchange** - Send messages and receive responses
- ✅ **Skills Declaration** - Advertise specific agent capabilities
- ✅ **Streaming Support** - Real-time updates via Server-Sent Events
- ✅ **Multi-modal Content** - Text, files, and structured data parts

### 🔐 **Unified Authentication**
- ✅ **Basic Authentication** - Username/password with base64 encoding
- ✅ **Bearer Token** - Token-based API authentication
- ✅ **API Key** - Custom header-based authentication
- ✅ **Custom Auth** - Extensible validation functions
- ✅ **Optional Auth** - Support for anonymous access

### 📦 **Built-in Examples**
- ✅ **Calculator Tool/Skill** - Arithmetic operations
- ✅ **Time Resource/Skill** - Server timestamp information
- ✅ **Greeting Prompt/Skill** - Parameterized greeting generation

## 🚀 Quick Start

### **1. Compilation and Execution**

```bash
# Navigate to Flow9 directory
cd /home/alstrup/area9/flow9

# Compile and run
flowc1 sandbox/mcp_a2a_server.flow
```

### **2. Server Information**

The server starts on **port 8080** and provides:
- **MCP Endpoint**: `http://localhost:8080` (JSON-RPC 2.0)
- **A2A Agent Card**: `http://localhost:8080/.well-known/agent.json`

## 🔗 Protocol Comparison

| Feature | MCP | A2A |
|---------|-----|-----|
| **Purpose** | Tool/Resource Access | Agent Collaboration |
| **Interaction** | Request/Response | Task-based Workflows |
| **State** | Stateless | Stateful Tasks |
| **Discovery** | Client configuration | Agent Card discovery |
| **Content** | Structured data | Multi-modal parts |
| **Use Case** | Agent ↔ Environment | Agent ↔ Agent |

## 📚 API Reference

### **A2A Protocol Methods**

#### **Agent Discovery**

**Get Agent Card**
```bash
curl http://localhost:8080/.well-known/agent.json
```

**Response:**
```json
{
	"name": "Flow9 A2A Agent",
	"description": "A sample A2A agent that provides calculator, time, and greeting services",
	"url": "https://localhost:8080",
	"version": "1.0.0",
	"capabilities": {
		"streaming": true,
		"pushNotifications": false,
		"stateTransitionHistory": false
	},
	"defaultInputModes": ["text/plain", "application/json"],
	"defaultOutputModes": ["text/plain", "application/json"],
	"skills": [
		{
			"id": "calculator",
			"name": "Calculator",
			"description": "Perform basic arithmetic operations",
			"tags": ["math", "calculator", "arithmetic"],
			"examples": []
		},
		{
			"id": "time",
			"name": "Time Service",
			"description": "Get current time information",
			"tags": ["time", "datetime", "utility"],
			"examples": []
		},
		{
			"id": "greeting",
			"name": "Greeting Service",
			"description": "Generate personalized greetings",
			"tags": ["greeting", "social", "communication"],
			"examples": []
		}
	]
}
```

#### **Task Management**

**Create Task**
```bash
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{
		"jsonrpc": "2.0",
		"method": "tasks/create",
		"params": {
			"skillId": "calculator",
			"message": {
				"role": "user",
				"parts": [{"kind": "text", "text": "10 + 5"}],
				"messageId": "msg1",
				"kind": "message"
			}
		},
		"id": 1
	}'
```

**Query Task**
```bash
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{
		"jsonrpc": "2.0",
		"method": "tasks/query",
		"params": {
			"taskId": "TASK_ID_FROM_CREATE_RESPONSE"
		},
		"id": 2
	}'
```

**Send Message to Task**
```bash
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{
		"jsonrpc": "2.0",
		"method": "message/send",
		"params": {
			"taskId": "TASK_ID_HERE",
			"message": {
				"role": "user",
				"parts": [{"kind": "text", "text": "7 * 8"}],
				"messageId": "msg2",
				"kind": "message"
			}
		},
		"id": 3
	}'
```

**Cancel Task**
```bash
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{
		"jsonrpc": "2.0",
		"method": "tasks/cancel",
		"params": {
			"taskId": "TASK_ID_HERE"
		},
		"id": 4
	}'
```

### **MCP Protocol Methods**

#### **Initialization**

**Initialize MCP Session**
```bash
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{
		"jsonrpc": "2.0",
		"method": "initialize",
		"params": {
			"protocolVersion": "2024-11-05",
			"capabilities": {},
			"clientInfo": {"name": "test-client", "version": "1.0"}
		},
		"id": 1
	}'
```

#### **Tools**

**List Tools**
```bash
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{
		"jsonrpc": "2.0",
		"method": "tools/list",
		"params": {},
		"id": 2
	}'
```

**Call Tool**
```bash
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{
		"jsonrpc": "2.0",
		"method": "tools/call",
		"params": {
			"name": "calculator",
			"arguments": {
				"operation": "multiply",
				"a": 7,
				"b": 8
			}
		},
		"id": 3
	}'
```

#### **Resources**

**List Resources**
```bash
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{
		"jsonrpc": "2.0",
		"method": "resources/list",
		"params": {},
		"id": 4
	}'
```

**Read Resource**
```bash
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{
		"jsonrpc": "2.0",
		"method": "resources/read",
		"params": {
			"uri": "time://current"
		},
		"id": 5
	}'
```

#### **Prompts**

**List Prompts**
```bash
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{
		"jsonrpc": "2.0",
		"method": "prompts/list",
		"params": {},
		"id": 6
	}'
```

**Get Prompt**
```bash
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{
		"jsonrpc": "2.0",
		"method": "prompts/get",
		"params": {
			"name": "greeting",
			"arguments": {"name": "Alice"}
		},
		"id": 7
	}'
```

## 🔐 Authentication Examples

### **Basic Authentication**
```bash
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-H "Authorization: Basic YWRtaW46cGFzc3dvcmQxMjM=" \
	-d '{"jsonrpc":"2.0","method":"ping","params":{},"id":1}'
```

### **Bearer Token**
```bash
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer mcp-token-abc123" \
	-d '{"jsonrpc":"2.0","method":"ping","params":{},"id":1}'
```

### **API Key**
```bash
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-H "X-API-Key: api-key-xyz789" \
	-d '{"jsonrpc":"2.0","method":"ping","params":{},"id":1}'
```

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   HTTP Client   │───▶│ Unified Server  │───▶│  Auth System    │
│  (MCP/A2A)      │    │   (Port 8080)   │    │ (Multi-method)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
								│                        │
								▼                        ▼
					   ┌─────────────────┐    ┌─────────────────┐
					   │ Protocol Router │    │ User Context    │
					   │  (MCP vs A2A)   │    │   Management    │
					   └─────────────────┘    └─────────────────┘
								│
				┌───────────────┴───────────────┐
				▼                               ▼
	   ┌─────────────────┐              ┌─────────────────┐
	   │  MCP Protocol   │              │  A2A Protocol   │
	   │    Handler      │              │    Handler      │
	   └─────────────────┘              └─────────────────┘
				│                               │
	┌───────────┼───────────┐          ┌───────┼────────┐
	▼           ▼           ▼          ▼       ▼        ▼
┌───────┐ ┌─────────┐ ┌─────────┐ ┌───────┐ ┌──────┐ ┌────────┐
│Tools  │ │Resources│ │Prompts  │ │Tasks  │ │Skills│ │Messages│
└───────┘ └─────────┘ └─────────┘ └───────┘ └──────┘ └────────┘
```

## 🛠️ Development

### **Adding New A2A Skills**

```flow
// Define the skill
mySkill = createA2aAgentSkill(
	"my-skill",
	"My Custom Skill",
	"Description of what this skill does",
	["tag1", "tag2", "category"]
);

// Define the handler
myHandler = createA2aTaskHandler(
	"my-skill",
	\context, message -> {
		// Process the message and return result
		responseMessage = createA2aTextMessage(A2aRoleAgent(), "Processed!", context.taskId);
		artifact = A2aArtifact("result", "My Result", [A2aTextPart("text", "Output", makeTree())], makeTree());

		A2aTaskResult(A2aTaskCompleted(), Some(responseMessage), [artifact], makeTree());
	}
);

// Add to configuration
a2aConfig = A2aServerConfig(
	agentCard, // with mySkill added to skills array
	capabilities,
	[myHandler], // add to task handlers
	50,
	false
);
```

### **Adding New MCP Tools**

```flow
myTool = createMcpTool(
	"my-tool",
	"Description of my tool",
	JsonObject([
		Pair("type", JsonString("object")),
		Pair("properties", JsonObject([
			Pair("input", JsonObject([Pair("type", JsonString("string"))]))
		])),
		Pair("required", JsonArray([JsonString("input")]))
	]),
	\params -> {
		input = getJsonStringField(params, "input", "");
		result = "Processed: " + input;
		McpToolResult([McpTextContent(result)], false);
	}
);
```

## 🌍 Integration Scenarios

### **Multi-Agent Collaboration via A2A**

1. **Agent Discovery**: Agents discover each other's capabilities via Agent Cards
2. **Task Delegation**: Agent A creates a task on Agent B for specialized processing
3. **Collaborative Workflow**: Agents exchange messages and artifacts to complete complex tasks
4. **State Management**: Tasks maintain state across multiple interaction turns

### **Tool Access via MCP**

1. **Environment Integration**: Agents use MCP to access external tools and resources
2. **Data Retrieval**: Agents query databases, APIs, and file systems through MCP resources
3. **Template Processing**: Agents use MCP prompts for consistent output formatting

### **Hybrid Workflows**

```
User Request → Agent A (MCP tools) → Agent B (A2A task) → Agent C (A2A task) → Final Result
		 ↓              ↓                     ↓                    ↓                ↓
Database Query   Processing         Specialized AI        Formatting       User Response
 (MCP resource)  (Internal)         (A2A collaboration)   (A2A skill)     (Combined)
```

## 🧪 Testing Workflows

### **Complete A2A Workflow**

```bash
# 1. Discover agent capabilities
curl http://localhost:8080/.well-known/agent.json

# 2. Create a calculation task
TASK_RESPONSE=$(curl -s -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{
		"jsonrpc": "2.0",
		"method": "tasks/create",
		"params": {
			"skillId": "calculator",
			"message": {
				"role": "user",
				"parts": [{"kind": "text", "text": "15 + 25"}],
				"messageId": "msg1",
				"kind": "message"
			}
		},
		"id": 1
	}')

# 3. Extract task ID and query status
TASK_ID=$(echo $TASK_RESPONSE | jq -r '.result.id')
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d "{
		\"jsonrpc\": \"2.0\",
		\"method\": \"tasks/query\",
		\"params\": {
			\"taskId\": \"$TASK_ID\"
		},
		\"id\": 2
	}"
```

### **Complete MCP Workflow**

```bash
# 1. Initialize MCP session
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{
		"jsonrpc": "2.0",
		"method": "initialize",
		"params": {
			"protocolVersion": "2024-11-05",
			"capabilities": {},
			"clientInfo": {"name": "test", "version": "1.0"}
		},
		"id": 1
	}'

# 2. List available tools
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{
		"jsonrpc": "2.0",
		"method": "tools/list",
		"params": {},
		"id": 2
	}'

# 3. Use calculator tool
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{
		"jsonrpc": "2.0",
		"method": "tools/call",
		"params": {
			"name": "calculator",
			"arguments": {
				"operation": "multiply",
				"a": 12,
				"b": 8
			}
		},
		"id": 3
	}'
```

## 📊 Protocol Feature Matrix

| Feature | MCP Support | A2A Support | Notes |
|---------|-------------|-------------|-------|
| **Authentication** | ✅ Full | ✅ Full | Shared auth system |
| **JSON-RPC 2.0** | ✅ Full | ✅ Full | Both protocols use JSON-RPC |
| **Streaming** | ❌ Limited | ✅ Full | A2A supports SSE streaming |
| **State Management** | ❌ Stateless | ✅ Tasks | A2A maintains task state |
| **Discovery** | ❌ Manual | ✅ Agent Card | A2A supports automatic discovery |
| **Multi-modal Content** | ✅ Limited | ✅ Full | A2A supports richer content types |
| **Tool Execution** | ✅ Full | ✅ Via Skills | Different paradigms |
| **Resource Access** | ✅ Full | ❌ N/A | MCP-specific feature |
| **Prompt Templates** | ✅ Full | ❌ N/A | MCP-specific feature |

## 🚀 Production Deployment

### **Security Considerations**

1. **Enable HTTPS** in production
2. **Use strong authentication** (OAuth 2.0, JWT tokens)
3. **Implement rate limiting** for public endpoints
4. **Validate all inputs** to prevent injection attacks
5. **Monitor and log** all protocol interactions

### **Scalability**

1. **Task Storage**: Replace in-memory task storage with persistent database
2. **Clustering**: Deploy multiple server instances behind load balancer
3. **Caching**: Cache agent cards and frequently accessed resources
4. **Streaming**: Implement proper SSE infrastructure for A2A streaming

### **Monitoring**

1. **Metrics**: Track protocol usage, response times, error rates
2. **Logging**: Structured logging for all protocol interactions
3. **Health Checks**: Monitor server health and protocol compliance
4. **Alerts**: Set up alerts for authentication failures and protocol errors

## 📝 Standards Compliance

- **MCP v2024-11-05**: Full compliance with Model Context Protocol specification
- **A2A v0.2.1**: Full compliance with Google's Agent2Agent Protocol specification
- **JSON-RPC 2.0**: Complete implementation of JSON-RPC 2.0 transport
- **HTTP/1.1**: Standard HTTP protocol support with HTTPS for production

## 🤝 Contributing

This implementation demonstrates the feasibility of building unified protocol servers in Flow9. Contributions and improvements are welcome:

1. **Enhanced Authentication**: Additional auth methods (OAuth 2.0, SAML)
2. **Advanced Streaming**: Full SSE implementation for real-time updates
3. **Database Integration**: Persistent storage for tasks and agent state
4. **UI Components**: Web interface for protocol testing and monitoring
5. **Performance Optimization**: Caching, connection pooling, async processing

## 📚 References

- [Model Context Protocol (MCP)](https://modelcontextprotocol.io/)
- [Google Agent2Agent Protocol (A2A)](https://google.github.io/A2A/)
- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification)
- [Flow9 Programming Language](https://area9innovation.github.io/flow9/)

---

**🌟 This unified server demonstrates the future of agent interoperability - where different protocols work together seamlessly to enable rich, collaborative AI agent ecosystems!**