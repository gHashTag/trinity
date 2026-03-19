// Package mcpswarm provides a thin proxy from Go HTTP/Telegram commands
// to the Zig MCP server's swarm tools (swarm_status, swarm_agents, etc).
//
// Architecture:
//   Go Bridge (this) → stdin/stdout JSON-RPC → trinity-mcp (Zig)
//
// The Zig MCP server owns ALL swarm orchestration state.
// Go just formats Telegram messages and forwards REST API requests.
package mcpswarm

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"strings"
	"sync"
	"sync/atomic"
)

// Proxy manages the trinity-mcp child process and sends JSON-RPC requests.
type Proxy struct {
	cmd    *exec.Cmd
	stdin  io.WriteCloser
	stdout *bufio.Reader
	mu     sync.Mutex // serialize JSON-RPC calls
	nextID atomic.Int64
	ready  bool
}

// jsonRPCRequest is a JSON-RPC 2.0 request.
type jsonRPCRequest struct {
	JSONRPC string      `json:"jsonrpc"`
	Method  string      `json:"method"`
	Params  interface{} `json:"params,omitempty"`
	ID      int64       `json:"id"`
}

// jsonRPCResponse is a JSON-RPC 2.0 response.
type jsonRPCResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *jsonRPCError   `json:"error,omitempty"`
	ID      int64           `json:"id"`
}

type jsonRPCError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// toolCallParams matches MCP tools/call request.
type toolCallParams struct {
	Name      string          `json:"name"`
	Arguments json.RawMessage `json:"arguments,omitempty"`
}

// mcpContent is one item in the MCP response content array.
type mcpContent struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

// mcpToolResult is the result from a tools/call response.
type mcpToolResult struct {
	Content []mcpContent `json:"content"`
	IsError bool         `json:"isError,omitempty"`
}

// NewProxy starts the trinity-mcp binary and initializes the MCP session.
func NewProxy(mcpBinaryPath string) (*Proxy, error) {
	if mcpBinaryPath == "" {
		mcpBinaryPath = findMCPBinary()
	}

	if _, err := os.Stat(mcpBinaryPath); err != nil {
		return nil, fmt.Errorf("trinity-mcp binary not found at %s: %w", mcpBinaryPath, err)
	}

	cmd := exec.Command(mcpBinaryPath)
	cmd.Stderr = os.Stderr // pass MCP server logs through

	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, fmt.Errorf("stdin pipe: %w", err)
	}

	stdoutPipe, err := cmd.StdoutPipe()
	if err != nil {
		return nil, fmt.Errorf("stdout pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("start trinity-mcp: %w", err)
	}

	p := &Proxy{
		cmd:    cmd,
		stdin:  stdin,
		stdout: bufio.NewReader(stdoutPipe),
	}

	// Send MCP initialize handshake
	if err := p.initialize(); err != nil {
		cmd.Process.Kill()
		return nil, fmt.Errorf("MCP initialize: %w", err)
	}

	p.ready = true
	log.Printf("[McpSwarm] Proxy started, pid=%d", cmd.Process.Pid)
	return p, nil
}

// Close shuts down the MCP server process.
func (p *Proxy) Close() {
	if p.cmd != nil && p.cmd.Process != nil {
		p.stdin.Close()
		p.cmd.Process.Kill()
		p.cmd.Wait()
	}
}

// CallTool sends a tools/call JSON-RPC request and returns the text result.
func (p *Proxy) CallTool(toolName string, args map[string]interface{}) (string, error) {
	if !p.ready {
		return "", fmt.Errorf("MCP proxy not ready")
	}

	argsJSON, _ := json.Marshal(args)
	if args == nil {
		argsJSON = []byte("{}")
	}

	params := struct {
		Name      string          `json:"name"`
		Arguments json.RawMessage `json:"arguments"`
	}{
		Name:      toolName,
		Arguments: json.RawMessage(argsJSON),
	}

	resp, err := p.call("tools/call", params)
	if err != nil {
		return "", err
	}

	var toolResult mcpToolResult
	if err := json.Unmarshal(resp.Result, &toolResult); err != nil {
		return "", fmt.Errorf("parse tool result: %w", err)
	}

	if toolResult.IsError {
		if len(toolResult.Content) > 0 {
			return "", fmt.Errorf("MCP tool error: %s", toolResult.Content[0].Text)
		}
		return "", fmt.Errorf("MCP tool error (no details)")
	}

	if len(toolResult.Content) > 0 {
		return toolResult.Content[0].Text, nil
	}
	return "", nil
}

// initialize sends the MCP initialize + initialized handshake.
func (p *Proxy) initialize() error {
	initParams := map[string]interface{}{
		"protocolVersion": "2024-11-05",
		"capabilities":    map[string]interface{}{},
		"clientInfo": map[string]interface{}{
			"name":    "telegram-bridge",
			"version": "1.0.0",
		},
	}

	resp, err := p.call("initialize", initParams)
	if err != nil {
		return fmt.Errorf("initialize request: %w", err)
	}
	if resp.Error != nil {
		return fmt.Errorf("initialize error: %s", resp.Error.Message)
	}

	// Send notifications/initialized (no response expected for notification)
	if err := p.notify("notifications/initialized", nil); err != nil {
		return fmt.Errorf("initialized notification: %w", err)
	}

	return nil
}

// call sends a JSON-RPC request with Content-Length framing and reads the response.
func (p *Proxy) call(method string, params interface{}) (*jsonRPCResponse, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	id := p.nextID.Add(1)
	req := jsonRPCRequest{
		JSONRPC: "2.0",
		Method:  method,
		Params:  params,
		ID:      id,
	}

	reqBytes, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	// Write with Content-Length framing
	header := fmt.Sprintf("Content-Length: %d\r\n\r\n", len(reqBytes))
	if _, err := io.WriteString(p.stdin, header); err != nil {
		return nil, fmt.Errorf("write header: %w", err)
	}
	if _, err := p.stdin.Write(reqBytes); err != nil {
		return nil, fmt.Errorf("write body: %w", err)
	}

	// Read response with Content-Length framing
	return p.readResponse()
}

// notify sends a JSON-RPC notification (no id, no response expected).
func (p *Proxy) notify(method string, params interface{}) error {
	p.mu.Lock()
	defer p.mu.Unlock()

	type notification struct {
		JSONRPC string      `json:"jsonrpc"`
		Method  string      `json:"method"`
		Params  interface{} `json:"params,omitempty"`
	}

	n := notification{
		JSONRPC: "2.0",
		Method:  method,
		Params:  params,
	}

	nBytes, err := json.Marshal(n)
	if err != nil {
		return fmt.Errorf("marshal notification: %w", err)
	}

	header := fmt.Sprintf("Content-Length: %d\r\n\r\n", len(nBytes))
	if _, err := io.WriteString(p.stdin, header); err != nil {
		return fmt.Errorf("write header: %w", err)
	}
	if _, err := p.stdin.Write(nBytes); err != nil {
		return fmt.Errorf("write body: %w", err)
	}

	return nil
}

// readResponse reads a Content-Length framed JSON-RPC response.
func (p *Proxy) readResponse() (*jsonRPCResponse, error) {
	// Read headers until empty line
	var contentLength int
	for {
		line, err := p.stdout.ReadString('\n')
		if err != nil {
			return nil, fmt.Errorf("read header: %w", err)
		}
		line = strings.TrimSpace(line)
		if line == "" {
			break
		}
		if strings.HasPrefix(line, "Content-Length:") {
			fmt.Sscanf(strings.TrimPrefix(line, "Content-Length:"), "%d", &contentLength)
		}
	}

	if contentLength == 0 {
		return nil, fmt.Errorf("missing Content-Length header")
	}

	// Read body
	body := make([]byte, contentLength)
	if _, err := io.ReadFull(p.stdout, body); err != nil {
		return nil, fmt.Errorf("read body: %w", err)
	}

	var resp jsonRPCResponse
	if err := json.Unmarshal(body, &resp); err != nil {
		return nil, fmt.Errorf("parse response: %w", err)
	}

	return &resp, nil
}

// findMCPBinary looks for trinity-mcp in common locations.
func findMCPBinary() string {
	// Check env var first
	if p := os.Getenv("TRINITY_MCP_BINARY"); p != "" {
		return p
	}

	candidates := []string{
		"./zig-out/bin/trinity-mcp",
		"/data/trinity/zig-out/bin/trinity-mcp",
		"trinity-mcp",
	}

	for _, c := range candidates {
		if _, err := exec.LookPath(c); err == nil {
			return c
		}
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}

	return "trinity-mcp" // fall through to PATH lookup
}
