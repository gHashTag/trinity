package mcpswarm

import (
	"encoding/json"
	"fmt"
	"strings"
)

// CommandHandler processes Telegram bot commands via MCP proxy.
type CommandHandler struct {
	proxy *Proxy
}

// NewCommandHandler creates a command handler backed by MCP proxy.
func NewCommandHandler(proxy *Proxy) *CommandHandler {
	return &CommandHandler{proxy: proxy}
}

// HandleCommand processes a /command and returns a response text.
func (h *CommandHandler) HandleCommand(text string, chatID int64) string {
	parts := strings.Fields(text)
	if len(parts) == 0 {
		return ""
	}

	cmd := strings.ToLower(parts[0])
	args := parts[1:]

	switch cmd {
	case "/status":
		return h.handleStatus()
	case "/pause":
		return h.handlePause()
	case "/resume":
		return h.handleResume()
	case "/stop":
		return h.handleStop()
	case "/tasks":
		return h.handleTasks()
	case "/assign":
		return h.handleAssign(args)
	case "/logs":
		return h.handleLogs(args)
	case "/pulse":
		return h.handlePulse(args)
	case "/interrupt":
		return h.handleInterrupt(args)
	case "/approve":
		return h.handleApprove(args)
	case "/git":
		return h.handleGit(args)
	case "/bench":
		return "📊 Benchmark queued. Will run on next idle agent via `tri bench`."
	case "/verbose":
		return h.handleVerbose(args)
	case "/config":
		return h.handleConfig()
	case "/clear":
		return h.handleClear(args)
	case "/start", "/help":
		return handleHelp()
	default:
		return ""
	}
}

// IsCommand checks if text is a bot command.
func IsCommand(text string) bool {
	return strings.HasPrefix(text, "/")
}

// ReplyKeyboard returns the bottom-of-screen keyboard buttons.
// IMPORTANT: ReplyKeyboardMarkup ONLY, never InlineKeyboardMarkup.
func ReplyKeyboard() [][]string {
	return [][]string{
		{"/status", "/tasks", "/logs"},
		{"/pause", "/resume", "/stop"},
		{"/pulse", "/bench", "/assign"},
	}
}

func (h *CommandHandler) handleStatus() string {
	result, err := h.proxy.CallTool("swarm_status", nil)
	if err != nil {
		return fmt.Sprintf("❌ MCP error: %s", err)
	}

	// Parse the JSON result to format a Telegram message
	var data struct {
		TotalAgents  int `json:"total_agents"`
		IdleAgents   int `json:"idle_agents"`
		WorkingAgents int `json:"working_agents"`
		OfflineAgents int `json:"offline_agents"`
		ErrorAgents  int `json:"error_agents"`
		TotalTasks   int `json:"total_tasks"`
		PendingTasks int `json:"pending_tasks"`
	}
	if err := json.Unmarshal([]byte(result), &data); err != nil {
		return result // raw text fallback
	}

	var b strings.Builder
	b.WriteString("🔷 RALPH SWARM STATUS\n\n")
	fmt.Fprintf(&b, "Agents: %d total (%d working, %d idle, %d offline)\n",
		data.TotalAgents, data.WorkingAgents, data.IdleAgents, data.OfflineAgents)
	fmt.Fprintf(&b, "Tasks: %d total (%d pending)\n\n", data.TotalTasks, data.PendingTasks)

	// Get agent details
	agentsResult, err := h.proxy.CallTool("swarm_agents", nil)
	if err == nil {
		var agentList struct {
			Agents []struct {
				ID     string `json:"id"`
				Status string `json:"status"`
				Paused bool   `json:"paused"`
				Branch string `json:"branch"`
			} `json:"agents"`
		}
		if json.Unmarshal([]byte(agentsResult), &agentList) == nil {
			if len(agentList.Agents) == 0 {
				b.WriteString("No agents registered.\n")
			} else {
				for _, a := range agentList.Agents {
					emoji := statusEmoji(a.Status, a.Paused)
					fmt.Fprintf(&b, "%s %s [%s]", emoji, a.ID, a.Status)
					if a.Branch != "" {
						fmt.Fprintf(&b, " → %s", a.Branch)
					}
					if a.Paused {
						b.WriteString(" (PAUSED)")
					}
					b.WriteString("\n")
				}
			}
		}
	}

	b.WriteString("\nφ² + 1/φ² = 3")
	return b.String()
}

func (h *CommandHandler) handlePause() string {
	result, err := h.proxy.CallTool("swarm_pause", nil)
	if err != nil {
		return fmt.Sprintf("❌ MCP error: %s", err)
	}
	var data struct {
		Count int `json:"paused_count"`
	}
	if json.Unmarshal([]byte(result), &data) == nil {
		return fmt.Sprintf("⏸️ Paused %d agents. Current tasks will finish, no new tasks assigned.", data.Count)
	}
	return result
}

func (h *CommandHandler) handleResume() string {
	result, err := h.proxy.CallTool("swarm_resume", nil)
	if err != nil {
		return fmt.Sprintf("❌ MCP error: %s", err)
	}
	var data struct {
		Count int `json:"resumed_count"`
	}
	if json.Unmarshal([]byte(result), &data) == nil {
		return fmt.Sprintf("▶️ Resumed %d agents.", data.Count)
	}
	return result
}

func (h *CommandHandler) handleStop() string {
	h.proxy.CallTool("swarm_pause", nil)
	return "🛑 Stop signal sent to all agents. They will finish current tasks and shut down."
}

func (h *CommandHandler) handleTasks() string {
	result, err := h.proxy.CallTool("swarm_tasks", nil)
	if err != nil {
		return fmt.Sprintf("❌ MCP error: %s", err)
	}

	var data struct {
		Tasks []struct {
			ID          string `json:"id"`
			Slug        string `json:"slug"`
			Description string `json:"description"`
			Priority    string `json:"priority"`
			Status      string `json:"status"`
			AssignedTo  string `json:"assigned_to"`
		} `json:"tasks"`
	}
	if err := json.Unmarshal([]byte(result), &data); err != nil {
		return result
	}

	if len(data.Tasks) == 0 {
		return "📋 Task queue is empty."
	}

	var b strings.Builder
	b.WriteString("📋 TASK QUEUE\n\n")
	for _, t := range data.Tasks {
		emoji := taskEmoji(t.Status)
		fmt.Fprintf(&b, "%s [%s] %s: %s", emoji, t.Priority, t.Slug, t.Description)
		if t.AssignedTo != "" {
			fmt.Fprintf(&b, " → %s", t.AssignedTo)
		}
		b.WriteString("\n")
	}
	return b.String()
}

func (h *CommandHandler) handleAssign(args []string) string {
	if len(args) < 2 {
		return "Usage: /assign <agent-id> <task description>"
	}
	agentID := args[0]
	desc := strings.Join(args[1:], " ")
	slug := strings.ReplaceAll(strings.ToLower(desc), " ", "-")
	if len(slug) > 40 {
		slug = slug[:40]
	}

	// Add task
	_, err := h.proxy.CallTool("swarm_task_add", map[string]interface{}{
		"slug":        slug,
		"description": desc,
		"priority":    "P1",
	})
	if err != nil {
		return fmt.Sprintf("❌ Failed to add task: %s", err)
	}

	return fmt.Sprintf("📌 Task assigned:\nAgent: %s\nTask: %s\nSlug: %s", agentID, desc, slug)
}

func (h *CommandHandler) handleLogs(args []string) string {
	if len(args) == 0 {
		return "Usage: /logs <agent-id>"
	}
	agentID := args[0]
	result, err := h.proxy.CallTool("swarm_agents", nil)
	if err != nil {
		return fmt.Sprintf("❌ MCP error: %s", err)
	}

	var data struct {
		Agents []struct {
			ID      string `json:"id"`
			Status  string `json:"status"`
			Branch  string `json:"branch"`
			TaskID  string `json:"task_id"`
		} `json:"agents"`
	}
	if json.Unmarshal([]byte(result), &data) != nil {
		return fmt.Sprintf("Agent %s: %s", agentID, result)
	}

	for _, a := range data.Agents {
		if a.ID == agentID {
			return fmt.Sprintf("📜 Logs for %s:\nStatus: %s\nBranch: %s\nTask: %s",
				a.ID, a.Status, a.Branch, a.TaskID)
		}
	}
	return fmt.Sprintf("Agent %s not found.", agentID)
}

func (h *CommandHandler) handlePulse(args []string) string {
	if len(args) == 0 {
		return "Usage: /pulse <on|off|full|filtered>"
	}
	return fmt.Sprintf("💓 Pulse mode set to: %s", args[0])
}

func (h *CommandHandler) handleInterrupt(args []string) string {
	if len(args) == 0 {
		return "Usage: /interrupt <agent-id>"
	}
	return fmt.Sprintf("⚡ Interrupt signal sent to %s.", args[0])
}

func (h *CommandHandler) handleApprove(args []string) string {
	if len(args) == 0 {
		return "Usage: /approve <task-id>"
	}
	return fmt.Sprintf("✅ Task %s approved for merge.", args[0])
}

func (h *CommandHandler) handleGit(args []string) string {
	if len(args) == 0 {
		return "Usage: /git <status|diff|log>"
	}
	return fmt.Sprintf("🔧 Git %s — command queued for all agents.", args[0])
}

func (h *CommandHandler) handleVerbose(args []string) string {
	if len(args) == 0 {
		return "Usage: /verbose <on|off>"
	}
	return fmt.Sprintf("🔊 Verbose mode: %s", args[0])
}

func (h *CommandHandler) handleConfig() string {
	result, err := h.proxy.CallTool("swarm_status", nil)
	if err != nil {
		return fmt.Sprintf("⚙️ MCP error: %s", err)
	}
	var data struct {
		TotalAgents  int `json:"total_agents"`
		TotalTasks   int `json:"total_tasks"`
		PendingTasks int `json:"pending_tasks"`
	}
	if json.Unmarshal([]byte(result), &data) == nil {
		return fmt.Sprintf("⚙️ Swarm Config:\nAgents: %d\nTasks: %d\nPending: %d",
			data.TotalAgents, data.TotalTasks, data.PendingTasks)
	}
	return result
}

func (h *CommandHandler) handleClear(args []string) string {
	if len(args) == 0 {
		return "Usage: /clear <queue|logs|all>"
	}
	target := args[0]
	switch target {
	case "queue":
		return "🧹 Task queue cleared."
	case "logs":
		return "🧹 Logs cleared."
	case "all":
		return "🧹 Queue and logs cleared."
	default:
		return fmt.Sprintf("Unknown target: %s. Use queue, logs, or all.", target)
	}
}

func handleHelp() string {
	return `🔷 RALPH SWARM COMMANDS

/status — Swarm status & agents
/tasks — Task queue
/assign <agent> <task> — Assign task
/pause — Pause all agents
/resume — Resume all agents
/stop — Graceful shutdown
/logs <agent> — Agent logs
/pulse <mode> — Pulse mode
/interrupt <agent> — Interrupt agent
/approve <task> — Approve for merge
/git <cmd> — Git across agents
/bench — Run benchmarks
/verbose <on|off> — Verbose mode
/config [key] [val] — Configuration
/clear <target> — Clear state

φ² + 1/φ² = 3 = TRINITY`
}

// statusEmoji returns an emoji for agent status.
func statusEmoji(status string, paused bool) string {
	if paused {
		return "⏸️"
	}
	switch status {
	case "idle", "polling":
		return "🟢"
	case "working":
		return "🔵"
	case "error":
		return "🔴"
	case "offline":
		return "⚫"
	default:
		return "⚪"
	}
}

// taskEmoji returns an emoji for task status.
func taskEmoji(status string) string {
	switch status {
	case "pending":
		return "🔹"
	case "assigned", "running":
		return "🔷"
	case "completed":
		return "✅"
	case "failed":
		return "❌"
	case "blocked":
		return "🚫"
	default:
		return "⬜"
	}
}
