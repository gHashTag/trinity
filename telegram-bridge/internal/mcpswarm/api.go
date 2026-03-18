package mcpswarm

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"
)

// APIHandler handles REST API endpoints by proxying to MCP swarm tools.
type APIHandler struct {
	proxy *Proxy
}

// NewAPIHandler creates a new API handler.
func NewAPIHandler(proxy *Proxy) *APIHandler {
	return &APIHandler{proxy: proxy}
}

// RegisterRoutes registers all swarm API routes on the given mux.
func (h *APIHandler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/api/v1/swarm/status", h.handleStatus)
	mux.HandleFunc("/api/v1/swarm/agents", h.handleAgents)
	mux.HandleFunc("/api/v1/swarm/agent/register", h.handleRegisterAgent)
	mux.HandleFunc("/api/v1/swarm/heartbeat", h.handleHeartbeat)
	mux.HandleFunc("/api/v1/swarm/task", h.handleTask)
	mux.HandleFunc("/api/v1/swarm/tasks", h.handleTasks)
	log.Println("[Swarm] API routes registered (MCP proxy)")
}

func (h *APIHandler) handleStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		respondErr(w, http.StatusMethodNotAllowed, "GET required")
		return
	}
	result, err := h.proxy.CallTool("swarm_status", nil)
	if err != nil {
		respondErr(w, http.StatusInternalServerError, err.Error())
		return
	}
	respondRaw(w, result)
}

func (h *APIHandler) handleAgents(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		respondErr(w, http.StatusMethodNotAllowed, "GET required")
		return
	}
	result, err := h.proxy.CallTool("swarm_agents", nil)
	if err != nil {
		respondErr(w, http.StatusInternalServerError, err.Error())
		return
	}
	respondRaw(w, result)
}

func (h *APIHandler) handleRegisterAgent(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		respondErr(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	var body struct {
		ID       string `json:"id"`
		Hostname string `json:"hostname"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		respondErr(w, http.StatusBadRequest, "invalid JSON: "+err.Error())
		return
	}
	if body.ID == "" {
		respondErr(w, http.StatusBadRequest, "agent id is required")
		return
	}

	result, err := h.proxy.CallTool("swarm_register", map[string]interface{}{
		"agent_id": body.ID,
		"hostname": body.Hostname,
	})
	if err != nil {
		respondErr(w, http.StatusInternalServerError, err.Error())
		return
	}
	respondRaw(w, result)
}

func (h *APIHandler) handleHeartbeat(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		respondErr(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	var body struct {
		AgentID string `json:"agent_id"`
		Status  string `json:"status"`
		Branch  string `json:"branch"`
		TaskID  string `json:"task_id"`
		SHA     string `json:"sha"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		respondErr(w, http.StatusBadRequest, "invalid JSON: "+err.Error())
		return
	}
	if body.AgentID == "" {
		respondErr(w, http.StatusBadRequest, "agent_id is required")
		return
	}

	result, err := h.proxy.CallTool("swarm_heartbeat", map[string]interface{}{
		"agent_id": body.AgentID,
		"status":   body.Status,
		"branch":   body.Branch,
		"task_id":  body.TaskID,
		"sha":      body.SHA,
	})
	if err != nil {
		respondErr(w, http.StatusInternalServerError, err.Error())
		return
	}
	respondRaw(w, result)
}

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

	result, err := h.proxy.CallTool("swarm_task_get", map[string]interface{}{
		"agent_id": agentID,
	})
	if err != nil {
		respondErr(w, http.StatusInternalServerError, err.Error())
		return
	}

	// Check if result indicates no task
	if result == "" || result == "null" || strings.Contains(result, "\"no_task\"") {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("null"))
		return
	}

	respondRaw(w, result)
}

func (h *APIHandler) addTask(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Slug        string `json:"slug"`
		Description string `json:"description"`
		Priority    string `json:"priority"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		respondErr(w, http.StatusBadRequest, "invalid JSON: "+err.Error())
		return
	}

	if body.Slug == "" && body.Description != "" {
		body.Slug = strings.ReplaceAll(strings.ToLower(body.Description), " ", "-")
		if len(body.Slug) > 40 {
			body.Slug = body.Slug[:40]
		}
	}
	if body.Priority == "" {
		body.Priority = "P1"
	}

	result, err := h.proxy.CallTool("swarm_task_add", map[string]interface{}{
		"slug":        body.Slug,
		"description": body.Description,
		"priority":    body.Priority,
	})
	if err != nil {
		respondErr(w, http.StatusInternalServerError, err.Error())
		return
	}
	respondRaw(w, result)
}

func (h *APIHandler) cancelTask(w http.ResponseWriter, r *http.Request) {
	taskID := r.URL.Query().Get("id")
	if taskID == "" {
		respondErr(w, http.StatusBadRequest, "id query parameter required")
		return
	}

	result, err := h.proxy.CallTool("swarm_task_cancel", map[string]interface{}{
		"task_id": taskID,
	})
	if err != nil {
		respondErr(w, http.StatusNotFound, err.Error())
		return
	}
	respondRaw(w, result)
}

func (h *APIHandler) handleTasks(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		respondErr(w, http.StatusMethodNotAllowed, "GET required")
		return
	}
	result, err := h.proxy.CallTool("swarm_tasks", nil)
	if err != nil {
		respondErr(w, http.StatusInternalServerError, err.Error())
		return
	}
	respondRaw(w, result)
}

// respondRaw writes a pre-formatted JSON string as response.
func respondRaw(w http.ResponseWriter, jsonStr string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(jsonStr))
}

func respondErr(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}
