package swarm

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
)

// APIHandler handles REST API endpoints for swarm management
type APIHandler struct {
	orch *Orchestrator
}

// NewAPIHandler creates a new API handler
func NewAPIHandler(orch *Orchestrator) *APIHandler {
	return &APIHandler{orch: orch}
}

// RegisterRoutes registers all swarm API routes on the given mux
func (h *APIHandler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/api/v1/swarm/status", h.handleStatus)
	mux.HandleFunc("/api/v1/swarm/agents", h.handleAgents)
	mux.HandleFunc("/api/v1/swarm/agent/register", h.handleRegisterAgent)
	mux.HandleFunc("/api/v1/swarm/heartbeat", h.handleHeartbeat)
	mux.HandleFunc("/api/v1/swarm/task", h.handleTask)
	mux.HandleFunc("/api/v1/swarm/tasks", h.handleTasks)
	log.Println("[Swarm] API routes registered")
}

// handleStatus returns swarm summary
// GET /api/v1/swarm/status
func (h *APIHandler) handleStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		respondErr(w, http.StatusMethodNotAllowed, "GET required")
		return
	}
	status := h.orch.Status()
	respondOK(w, status)
}

// handleAgents returns all registered agents
// GET /api/v1/swarm/agents
func (h *APIHandler) handleAgents(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		respondErr(w, http.StatusMethodNotAllowed, "GET required")
		return
	}
	agents := h.orch.GetAgents()
	respondOK(w, map[string]interface{}{
		"agents": agents,
		"count":  len(agents),
	})
}

// handleRegisterAgent registers a new agent
// POST /api/v1/swarm/agent/register
func (h *APIHandler) handleRegisterAgent(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		respondErr(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	var agent Agent
	if err := json.NewDecoder(r.Body).Decode(&agent); err != nil {
		respondErr(w, http.StatusBadRequest, "invalid JSON: "+err.Error())
		return
	}

	if agent.ID == "" {
		respondErr(w, http.StatusBadRequest, "agent id is required")
		return
	}

	h.orch.RegisterAgent(&agent)
	respondOK(w, map[string]interface{}{
		"registered": true,
		"agent_id":   agent.ID,
	})
}

// HeartbeatRequest is the payload from an agent heartbeat
type HeartbeatRequest struct {
	AgentID   string `json:"agent_id"`
	Status    string `json:"status"`
	Branch    string `json:"branch"`
	TaskID    string `json:"task_id"`
	Timestamp string `json:"timestamp"`
}

// handleHeartbeat processes agent heartbeats
// POST /api/v1/swarm/heartbeat
func (h *APIHandler) handleHeartbeat(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		respondErr(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	var hb HeartbeatRequest
	if err := json.NewDecoder(r.Body).Decode(&hb); err != nil {
		respondErr(w, http.StatusBadRequest, "invalid JSON: "+err.Error())
		return
	}

	if hb.AgentID == "" {
		respondErr(w, http.StatusBadRequest, "agent_id is required")
		return
	}

	// Auto-register unknown agents on first heartbeat
	if _, ok := h.orch.GetAgent(hb.AgentID); !ok {
		h.orch.RegisterAgent(&Agent{
			ID:     hb.AgentID,
			Status: AgentStatus(hb.Status),
		})
	}

	if err := h.orch.Heartbeat(hb.AgentID, hb.Status, hb.Branch, hb.TaskID); err != nil {
		respondErr(w, http.StatusNotFound, err.Error())
		return
	}

	respondOK(w, map[string]interface{}{
		"ok":       true,
		"agent_id": hb.AgentID,
	})
}

// handleTask handles task operations
// GET  /api/v1/swarm/task?agent_id=X  — get next task for agent
// POST /api/v1/swarm/task             — add new task
// DELETE /api/v1/swarm/task?id=X      — cancel task
func (h *APIHandler) handleTask(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		h.getNextTask(w, r)
	case http.MethodPost:
		h.addTask(w, r)
	case http.MethodDelete:
		h.cancelTask(w, r)
	default:
		respondErr(w, http.StatusMethodNotAllowed, "GET, POST, or DELETE required")
	}
}

func (h *APIHandler) getNextTask(w http.ResponseWriter, r *http.Request) {
	agentID := r.URL.Query().Get("agent_id")
	if agentID == "" {
		respondErr(w, http.StatusBadRequest, "agent_id query parameter required")
		return
	}

	// Check if agent is paused
	agent, ok := h.orch.GetAgent(agentID)
	if ok && agent.Paused {
		respondOK(w, nil)
		return
	}

	task := h.orch.AssignTask(agentID)
	if task == nil {
		// No task available — return null (agent-loop.sh expects this)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "null")
		return
	}

	respondOK(w, task)
}

func (h *APIHandler) addTask(w http.ResponseWriter, r *http.Request) {
	var task Task
	if err := json.NewDecoder(r.Body).Decode(&task); err != nil {
		respondErr(w, http.StatusBadRequest, "invalid JSON: "+err.Error())
		return
	}

	if task.Slug == "" && task.Description != "" {
		task.Slug = strings.ReplaceAll(strings.ToLower(task.Description), " ", "-")
		if len(task.Slug) > 40 {
			task.Slug = task.Slug[:40]
		}
	}

	if task.Priority == "" {
		task.Priority = PriorityP1
	}

	h.orch.AddTask(&task)
	respondOK(w, map[string]interface{}{
		"created": true,
		"task_id": task.ID,
		"slug":    task.Slug,
	})
}

func (h *APIHandler) cancelTask(w http.ResponseWriter, r *http.Request) {
	taskID := r.URL.Query().Get("id")
	if taskID == "" {
		respondErr(w, http.StatusBadRequest, "id query parameter required")
		return
	}

	ok := h.orch.CancelTask(taskID)
	if !ok {
		respondErr(w, http.StatusNotFound, "task not found: "+taskID)
		return
	}

	respondOK(w, map[string]interface{}{
		"cancelled": true,
		"task_id":   taskID,
	})
}

// handleTasks returns all tasks
// GET /api/v1/swarm/tasks
func (h *APIHandler) handleTasks(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		respondErr(w, http.StatusMethodNotAllowed, "GET required")
		return
	}
	tasks := h.orch.GetTasks()
	respondOK(w, map[string]interface{}{
		"tasks": tasks,
		"count": len(tasks),
	})
}

// --- Response helpers (local to swarm package) ---

func respondOK(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(data); err != nil {
		log.Printf("[Swarm API] encode error: %v", err)
	}
}

func respondErr(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}
