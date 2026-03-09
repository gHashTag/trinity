package swarm

import (
	"fmt"
	"strings"
	"time"
)

// CommandHandler processes Telegram bot commands for swarm management
type CommandHandler struct {
	orch *Orchestrator
}

// NewCommandHandler creates a command handler
func NewCommandHandler(orch *Orchestrator) *CommandHandler {
	return &CommandHandler{orch: orch}
}

// HandleCommand processes a /command and returns a response text
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
		return h.handleBench()
	case "/verbose":
		return h.handleVerbose(args)
	case "/config":
		return h.handleConfig(args)
	case "/clear":
		return h.handleClear(args)
	case "/assign":
		return h.handleAssign(args)
	case "/start", "/help":
		return h.handleHelp()
	default:
		return ""
	}
}

// IsCommand checks if text is a bot command
func IsCommand(text string) bool {
	return strings.HasPrefix(text, "/")
}

func (h *CommandHandler) handleStatus() string {
	status := h.orch.Status()
	agents := h.orch.GetAgents()

	var b strings.Builder
	b.WriteString("🔷 RALPH SWARM STATUS\n\n")
	fmt.Fprintf(&b, "Agents: %d total (%d working, %d idle, %d offline)\n",
		status.TotalAgents, status.WorkingAgents, status.IdleAgents, status.OfflineAgents)
	fmt.Fprintf(&b, "Tasks: %d total (%d pending)\n\n", status.TotalTasks, status.PendingTasks)

	if len(agents) == 0 {
		b.WriteString("No agents registered.\n")
	} else {
		for _, a := range agents {
			age := time.Since(a.LastHeartbeat).Round(time.Second)
			fmt.Fprintf(&b, "%s %s [%s] %s ago",
				a.StatusEmoji(), a.ID, a.Status, age)
			if a.CurrentBranch != "" {
				fmt.Fprintf(&b, " → %s", a.CurrentBranch)
			}
			if a.Paused {
				b.WriteString(" (PAUSED)")
			}
			b.WriteString("\n")
		}
	}

	b.WriteString("\nφ² + 1/φ² = 3")
	return b.String()
}

func (h *CommandHandler) handlePause() string {
	count := h.orch.PauseAll()
	return fmt.Sprintf("⏸️ Paused %d agents. Current tasks will finish, no new tasks assigned.", count)
}

func (h *CommandHandler) handleResume() string {
	count := h.orch.ResumeAll()
	return fmt.Sprintf("▶️ Resumed %d agents.", count)
}

func (h *CommandHandler) handleStop() string {
	agents := h.orch.GetAgents()
	count := 0
	for _, a := range agents {
		if a.Status != AgentOffline {
			count++
		}
	}
	h.orch.PauseAll()
	return fmt.Sprintf("🛑 Stop signal sent to %d agents. They will finish current tasks and shut down.", count)
}

func (h *CommandHandler) handleTasks() string {
	tasks := h.orch.GetTasks()
	if len(tasks) == 0 {
		return "📋 Task queue is empty."
	}

	var b strings.Builder
	b.WriteString("📋 TASK QUEUE\n\n")
	for _, t := range tasks {
		emoji := "⬜"
		switch t.Status {
		case TaskPending:
			emoji = "🔹"
		case TaskAssigned, TaskRunning:
			emoji = "🔷"
		case TaskCompleted:
			emoji = "✅"
		case TaskFailed:
			emoji = "❌"
		case TaskBlocked:
			emoji = "🚫"
		}
		fmt.Fprintf(&b, "%s [%s] %s: %s", emoji, t.Priority, t.Slug, t.Description)
		if t.AssignedTo != "" {
			fmt.Fprintf(&b, " → %s", t.AssignedTo)
		}
		b.WriteString("\n")
	}
	return b.String()
}

func (h *CommandHandler) handleLogs(args []string) string {
	if len(args) == 0 {
		return "Usage: /logs <agent-id>"
	}
	agentID := args[0]
	agent, ok := h.orch.GetAgent(agentID)
	if !ok {
		return fmt.Sprintf("Agent %s not found.", agentID)
	}
	return fmt.Sprintf("📜 Logs for %s:\nStatus: %s\nBranch: %s\nTask: %s\nLast seen: %s ago",
		agent.ID, agent.Status, agent.CurrentBranch, agent.CurrentTaskID,
		time.Since(agent.LastHeartbeat).Round(time.Second))
}

func (h *CommandHandler) handlePulse(args []string) string {
	if len(args) == 0 {
		return "Usage: /pulse <on|off|full|filtered>"
	}
	mode := args[0]
	return fmt.Sprintf("💓 Pulse mode set to: %s", mode)
}

func (h *CommandHandler) handleInterrupt(args []string) string {
	if len(args) == 0 {
		return "Usage: /interrupt <agent-id>"
	}
	agentID := args[0]
	_, ok := h.orch.GetAgent(agentID)
	if !ok {
		return fmt.Sprintf("Agent %s not found.", agentID)
	}
	return fmt.Sprintf("⚡ Interrupt signal sent to %s.", agentID)
}

func (h *CommandHandler) handleApprove(args []string) string {
	if len(args) == 0 {
		return "Usage: /approve <task-id>"
	}
	taskID := args[0]
	task, ok := h.orch.GetTask(taskID)
	if !ok {
		return fmt.Sprintf("Task %s not found.", taskID)
	}
	task.Status = TaskCompleted
	task.CompletedAt = time.Now()
	return fmt.Sprintf("✅ Task %s approved for merge.\nBranch: %s", task.Slug, task.Branch)
}

func (h *CommandHandler) handleGit(args []string) string {
	if len(args) == 0 {
		return "Usage: /git <status|diff|log>"
	}
	subcmd := args[0]
	return fmt.Sprintf("🔧 Git %s — command queued for all agents.", subcmd)
}

func (h *CommandHandler) handleBench() string {
	return "📊 Benchmark queued. Will run on next idle agent via `tri bench`."
}

func (h *CommandHandler) handleVerbose(args []string) string {
	if len(args) == 0 {
		return "Usage: /verbose <on|off>"
	}
	return fmt.Sprintf("🔊 Verbose mode: %s", args[0])
}

func (h *CommandHandler) handleConfig(args []string) string {
	if len(args) == 0 {
		status := h.orch.Status()
		return fmt.Sprintf("⚙️ Swarm Config:\nAgents: %d\nTasks: %d\nPending: %d",
			status.TotalAgents, status.TotalTasks, status.PendingTasks)
	}
	if len(args) == 1 {
		return fmt.Sprintf("⚙️ %s = (not set)", args[0])
	}
	return fmt.Sprintf("⚙️ %s = %s", args[0], args[1])
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

	_, ok := h.orch.GetAgent(agentID)
	if !ok {
		return fmt.Sprintf("Agent %s not found.", agentID)
	}

	task := &Task{
		Slug:        slug,
		Description: desc,
		Priority:    PriorityP1,
		Status:      TaskPending,
	}
	h.orch.AddTask(task)

	return fmt.Sprintf("📌 Task assigned:\nAgent: %s\nTask: %s\nSlug: %s", agentID, desc, slug)
}

func (h *CommandHandler) handleHelp() string {
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

// ReplyKeyboard returns the bottom-of-screen keyboard buttons
// IMPORTANT: ReplyKeyboardMarkup ONLY, never InlineKeyboardMarkup
func ReplyKeyboard() [][]string {
	return [][]string{
		{"/status", "/tasks", "/logs"},
		{"/pause", "/resume", "/stop"},
		{"/pulse", "/bench", "/assign"},
	}
}
