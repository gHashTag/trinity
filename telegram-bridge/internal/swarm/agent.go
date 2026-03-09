package swarm

import "time"

// AgentStatus represents the current state of an agent
type AgentStatus string

const (
	AgentIdle     AgentStatus = "idle"
	AgentPolling  AgentStatus = "polling"
	AgentWorking  AgentStatus = "working"
	AgentError    AgentStatus = "error"
	AgentOffline  AgentStatus = "offline"
	AgentShutdown AgentStatus = "shutdown"
)

// Agent represents a cloud coding agent (Railway Agents Anywhere)
type Agent struct {
	ID             string      `json:"id"`
	Hostname       string      `json:"hostname"`
	Status         AgentStatus `json:"status"`
	Paused         bool        `json:"paused"`
	Capabilities   []string    `json:"capabilities"`
	WorktreeBase   string      `json:"worktree_base"`
	CurrentTaskID  string      `json:"current_task_id,omitempty"`
	CurrentBranch  string      `json:"current_branch,omitempty"`
	LastHeartbeat  time.Time   `json:"last_heartbeat"`
	RegisteredAt   time.Time   `json:"registered_at"`
	TasksCompleted int         `json:"tasks_completed"`
	TasksFailed    int         `json:"tasks_failed"`
	NoProgressCount int        `json:"no_progress_count"` // Circuit breaker
}

// IsHealthy returns true if agent heartbeat is recent
func (a *Agent) IsHealthy() bool {
	return time.Since(a.LastHeartbeat) < 2*time.Minute
}

// IsAvailable returns true if agent can accept a task
func (a *Agent) IsAvailable() bool {
	return a.Status == AgentIdle || a.Status == AgentPolling
}

// StatusEmoji returns a status indicator
func (a *Agent) StatusEmoji() string {
	if a.Paused {
		return "⏸️"
	}
	switch a.Status {
	case AgentIdle, AgentPolling:
		return "🟢"
	case AgentWorking:
		return "🔵"
	case AgentError:
		return "🔴"
	case AgentOffline:
		return "⚫"
	default:
		return "⚪"
	}
}
