# Flow9 MCP Server with Authentication

A complete **Model Context Protocol (MCP) 2.0** server implementation built in Flow9, featuring comprehensive authentication support and production-ready capabilities.

## 🌟 Overview

This MCP server provides a JSON-RPC 2.0 based implementation of the Model Context Protocol, allowing AI agents and clients to interact with tools, resources, and prompts through a standardized interface. The server includes robust authentication mechanisms and is designed for enterprise deployment.

## ✨ Features

### 🔌 **Core MCP Protocol Support**
- ✅ **MCP Protocol v2024-11-05** compliance
- ✅ **JSON-RPC 2.0** transport layer
- ✅ **Initialize/Initialized** handshake workflow
- ✅ **Ping/Pong** connection health checks
- ✅ **Capabilities negotiation**

### 🛠️ **MCP Resources**
- ✅ **Tools** - Executable functions with JSON Schema validation
- ✅ **Resources** - URI-addressable content (files, data, APIs)
- ✅ **Prompts** - Template prompts with parameter substitution
- ✅ **Logging** - Structured logging with configurable levels

### 🔐 **Authentication Methods**
- ✅ **Basic Authentication** - Username/password with base64 encoding
- ✅ **Bearer Token** - Token-based API authentication
- ✅ **API Key** - Custom header-based authentication
- ✅ **Custom Auth** - Extensible validation functions
- ✅ **Optional Auth** - Support for anonymous access
- ✅ **User Context** - Track authenticated users in requests

### 📦 **Built-in Examples**
- ✅ **Calculator Tool** - Arithmetic operations (add, subtract, multiply, divide)
- ✅ **Time Resource** - Server timestamp resource
- ✅ **Greeting Prompt** - Parameterized greeting template

## 🚀 Quick Start

### **1. Compilation**

```bash
cd /home/alstrup/area9/flow9

# Compile to JAR
flowc1 sandbox/mcp_server.flow jar=mcp_server.jar

# Or compile and run directly
flowc1 sandbox/mcp_server.flow
```

### **2. Running the Server**

```bash
java -jar mcp_server.jar
```

The server will start on **port 8080** and display available authentication methods and test commands.

### **3. Basic Test**

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

## 🔐 Authentication

### **Supported Methods**

| Method | Header | Example | User ID |
|--------|--------|---------|---------|
| **Basic Auth** | `Authorization: Basic <base64>` | `admin:password123` | `admin` |
| **Bearer Token** | `Authorization: Bearer <token>` | `mcp-token-abc123` | `bearer_user_*` |
| **API Key** | `X-API-Key: <key>` | `api-key-xyz789` | `api_user_*` |
| **Anonymous** | *(none)* | *(no auth header)* | `anonymous` |

### **Default Credentials**

```bash
# Basic Auth
admin:password123  (Base64: YWRtaW46cGFzc3dvcmQxMjM=)
user:secret456     (Base64: dXNlcjpzZWNyZXQ0NTY=)

# Bearer Tokens
mcp-token-abc123
mcp-token-def456

# API Keys
api-key-xyz789
api-key-uvw012
```

### **Authentication Examples**

#### **Basic Authentication**
```bash
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-H "Authorization: Basic YWRtaW46cGFzc3dvcmQxMjM=" \
	-d '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":1}'
```

#### **Bearer Token**
```bash
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer mcp-token-abc123" \
	-d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"calculator","arguments":{"operation":"add","a":10,"b":5}},"id":2}'
```

#### **API Key**
```bash
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-H "X-API-Key: api-key-xyz789" \
	-d '{"jsonrpc":"2.0","method":"resources/read","params":{"uri":"time://current"},"id":3}'
```

## 📚 API Reference

### **Core Protocol Methods**

#### **initialize**
Start MCP session and negotiate capabilities.

```json
{
	"jsonrpc": "2.0",
	"method": "initialize",
	"params": {
		"protocolVersion": "2024-11-05",
		"capabilities": {},
		"clientInfo": {"name": "client", "version": "1.0"}
	},
	"id": 1
}
```

#### **notifications/initialized**
Confirm initialization complete (notification, no response).

```json
{
	"jsonrpc": "2.0",
	"method": "notifications/initialized",
	"params": {}
}
```

#### **ping**
Health check endpoint.

```json
{
	"jsonrpc": "2.0",
	"method": "ping",
	"params": {},
	"id": 2
}
```

### **Tools**

#### **tools/list**
Get available tools.

```json
{
	"jsonrpc": "2.0",
	"method": "tools/list",
	"params": {},
	"id": 3
}
```

#### **tools/call**
Execute a tool.

```json
{
	"jsonrpc": "2.0",
	"method": "tools/call",
	"params": {
		"name": "calculator",
		"arguments": {
			"operation": "add",
			"a": 15,
			"b": 25
		}
	},
	"id": 4
}
```

### **Resources**

#### **resources/list**
Get available resources.

```json
{
	"jsonrpc": "2.0",
	"method": "resources/list",
	"params": {},
	"id": 5
}
```

#### **resources/read**
Read a resource.

```json
{
	"jsonrpc": "2.0",
	"method": "resources/read",
	"params": {
		"uri": "time://current"
	},
	"id": 6
}
```

### **Prompts**

#### **prompts/list**
Get available prompts.

```json
{
	"jsonrpc": "2.0",
	"method": "prompts/list",
	"params": {},
	"id": 7
}
```

#### **prompts/get**
Get a prompt with parameters.

```json
{
	"jsonrpc": "2.0",
	"method": "prompts/get",
	"params": {
		"name": "greeting",
		"arguments": {
			"name": "Alice"
		}
	},
	"id": 8
}
```

## 🔧 Configuration

### **Authentication Configuration**

```flow
authConfig = createAuthConfig(
	true,  // Enable authentication
	[
		createBasicAuth(credentials),           // Username/password
		createBearerAuth(tokens),              // Bearer tokens
		createApiKeyAuth(keys, "X-API-Key"),   // API keys
		createCustomAuth(validator)            // Custom validator
	],
	false  // requireAuth: false = optional, true = required
);
```

### **Server Configuration**

```flow
McpServerConfig(
	name: "Flow9 MCP Server",
	version: "1.0.0",
	tools: [calculatorTool],
	resources: [timeResource],
	prompts: [greetingPrompt],
	capabilities: serverCapabilities,
	authentication: authConfig
);
```

## 🛠️ Development

### **Adding New Tools**

```flow
myTool = createMcpTool(
	"my_tool",
	"Description of what this tool does",
	JsonObject([  // JSON Schema for input validation
		Pair("type", JsonString("object")),
		Pair("properties", JsonObject([
			Pair("param1", JsonObject([Pair("type", JsonString("string"))]))
		])),
		Pair("required", JsonArray([JsonString("param1")]))
	]),
	\params -> {  // Handler function
		param1 = getJsonStringField(params, "param1", "");
		result = "Processed: " + param1;
		McpToolResult([McpTextContent(result)], false);
	}
);
```

### **Adding New Resources**

```flow
myResource = createMcpResource(
	"myscheme://path",
	"My Resource",
	"Description of this resource",
	"text/plain",
	\ -> {  // Handler function
		content = "Dynamic content: " + d2s(timestamp());
		McpResourceResult([
			McpResourceContent("myscheme://path", "text/plain", Some(content), None())
		]);
	}
);
```

### **Adding New Prompts**

```flow
myPrompt = createMcpPrompt(
	"my_prompt",
	"A custom prompt template",
	[McpPromptArgument("topic", "The topic to discuss", true)],
	\params -> {  // Handler function
		topic = getJsonStringField(params, "topic", "general");
		McpPromptResult(
			"Discussion prompt about " + topic,
			[McpPromptMessage(
				McpRoleUser(),
				McpTextContent("Let's discuss " + topic + ". What are your thoughts?")
			)]
		);
	}
);
```

## 🧪 Testing Scenarios

### **Full MCP Workflow**

```bash
# 1. Initialize
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}},"id":1}'

# 2. Send initialized notification
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'

# 3. List tools
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}'

# 4. Call calculator
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"calculator","arguments":{"operation":"multiply","a":7,"b":8}},"id":3}'

# 5. Read time resource
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{"jsonrpc":"2.0","method":"resources/read","params":{"uri":"time://current"},"id":4}'

# 6. Get greeting prompt
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{"jsonrpc":"2.0","method":"prompts/get","params":{"name":"greeting","arguments":{"name":"Bob"}},"id":5}'
```

### **Authentication Testing**

```bash
# Test no auth (should work)
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-d '{"jsonrpc":"2.0","method":"ping","params":{},"id":1}'

# Test valid basic auth
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-H "Authorization: Basic YWRtaW46cGFzc3dvcmQxMjM=" \
	-d '{"jsonrpc":"2.0","method":"ping","params":{},"id":2}'

# Test invalid auth (should return 401)
curl -X POST http://localhost:8080 \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer invalid-token" \
	-d '{"jsonrpc":"2.0","method":"ping","params":{},"id":3}'
```

## 📋 Error Codes

| Code | Description |
|------|-------------|
| `-32700` | Parse error (invalid JSON) |
| `-32600` | Invalid request (not valid JSON-RPC) |
| `-32601` | Method not found |
| `-32602` | Invalid params |
| `-32603` | Internal error |
| `401` | Authentication failed |
| `405` | Method not allowed (only POST supported) |

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   HTTP Client   │───▶│   HTTP Server   │───▶│  Auth System    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
																│                        │
																▼                        ▼
											 ┌─────────────────┐    ┌─────────────────┐
											 │ JSON-RPC Parser │    │ User Context    │
											 └─────────────────┘    └─────────────────┘
																│                        │
																▼                        ▼
											 ┌─────────────────┐    ┌─────────────────┐
											 │  MCP Protocol   │───▶│  Method Router  │
											 └─────────────────┘    └─────────────────┘
																												│
																┌───────────────────────┼───────────────────────┐
																▼                       ▼                       ▼
											 ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
											 │     Tools       │    │   Resources     │    │    Prompts      │
											 └─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🤝 Integration

### **Claude Desktop**
Add to your Claude Desktop MCP configuration:

```json
{
	"mcpServers": {
		"flow9-server": {
			"command": "java",
			"args": ["-jar", "/path/to/mcp_server.jar"],
			"env": {}
		}
	}
}
```

### **Custom MCP Clients**
The server implements the standard MCP protocol and can be used with any MCP-compatible client.

## 📝 License

Built with Flow9 - check Flow9 licensing terms for usage.

## 🐛 Troubleshooting

### **Common Issues**

1. **Port 8080 in use**: Change port in the `main()` function
2. **Authentication failures**: Check base64 encoding of credentials
3. **JSON parsing errors**: Ensure proper Content-Type headers
4. **Connection refused**: Verify server is running and accessible

### **Debug Mode**

Enable verbose logging by modifying the server configuration:

```flow
capabilities = McpServerCapabilities(
	Some(McpLoggingCapability()),  // Enable logging
	// ... other capabilities
);
```

---

**🚀 Ready for production deployment with enterprise-grade authentication and full MCP protocol compliance!**