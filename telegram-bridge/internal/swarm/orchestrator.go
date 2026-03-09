package swarm

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"sync"
	"time"
)

// Orchestrator manages the Ralph Agent Swarm
type Orchestrator struct {
	agents   map[string]*Agent
	tasks    *TaskQueue
	fileLock map[string]string // file path → agent_id (prevents conflicts)
	mu       sync.RWMutex
	dataPath string // path for persistent state
}

// NewOrchestrator creates a new swarm orchestrator
func NewOrchestrator(dataPath string) *Orchestrator {
	o := &Orchestrator{
		agents:   make(map[string]*Agent),
		tasks:    NewTaskQueue(),
		fileLock: make(map[string]string),
		dataPath: dataPath,
	}
	o.loadState()
	return o
}

// RegisterAgent adds or updates an agent in the registry
func (o *Orchestrator) RegisterAgent(a *Agent) {
	o.mu.Lock()
	defer o.mu.Unlock()
	a.LastHeartbeat = time.Now()
	a.RegisteredAt = time.Now()
	o.agents[a.ID] = a
	log.Printf("[Swarm] Agent registered: %s (capabilities: %v)", a.ID, a.Capabilities)
	o.saveState()
}

// Heartbeat updates agent status
func (o *Orchestrator) Heartbeat(agentID, status, branch, taskID string) error {
	o.mu.Lock()
	defer o.mu.Unlock()
	agent, ok := o.agents[agentID]
	if !ok {
		return fmt.Errorf("agent %s not registered", agentID)
	}
	agent.Status = AgentStatus(status)
	agent.LastHeartbeat = time.Now()
	if branch != "" && branch != "none" {
		agent.CurrentBranch = branch
	}
	if taskID != "" && taskID != "none" {
		agent.CurrentTaskID = taskID
	}
	if status == "completed" || status == "idle" {
		agent.CurrentTaskID = ""
		agent.CurrentBranch = ""
		// Release file locks for this agent
		for path, lockedBy := range o.fileLock {
			if lockedBy == agentID {
				delete(o.fileLock, path)
			}
		}
	}
	return nil
}

// GetAgents returns all registered agents
func (o *Orchestrator) GetAgents() []*Agent {
	o.mu.RLock()
	defer o.mu.RUnlock()
	result := make([]*Agent, 0, len(o.agents))
	for _, a := range o.agents {
		result = append(result, a)
	}
	return result
}

// GetAgent returns a specific agent
func (o *Orchestrator) GetAgent(id string) (*Agent, bool) {
	o.mu.RLock()
	defer o.mu.RUnlock()
	a, ok := o.agents[id]
	return a, ok
}

// AssignTask tries to assign a task to a specific or any idle agent
func (o *Orchestrator) AssignTask(agentID string) *Task {
	o.mu.Lock()
	defer o.mu.Unlock()

	task := o.tasks.NextPending()
	if task == nil {
		return nil
	}

	// Check file affinity — skip if files are locked
	for _, path := range task.AffectedFiles {
		if lockedBy, ok := o.fileLock[path]; ok && lockedBy != agentID {
			// Files locked by another agent, skip this task
			return nil
		}
	}

	// Assign
	task.Status = TaskAssigned
	task.AssignedTo = agentID
	task.AssignedAt = time.Now()

	// Lock affected files
	for _, path := range task.AffectedFiles {
		o.fileLock[path] = agentID
	}

	if agent, ok := o.agents[agentID]; ok {
		agent.CurrentTaskID = task.ID
		agent.Status = AgentWorking
	}

	o.saveState()
	return task
}

// AddTask adds a new task to the queue
func (o *Orchestrator) AddTask(t *Task) {
	o.mu.Lock()
	defer o.mu.Unlock()
	t.CreatedAt = time.Now()
	if t.ID == "" {
		t.ID = fmt.Sprintf("task-%d", time.Now().UnixMilli())
	}
	if t.Status == "" {
		t.Status = TaskPending
	}
	o.tasks.Add(t)
	o.saveState()
	log.Printf("[Swarm] Task added: %s (%s) priority=%s", t.ID, t.Slug, t.Priority)
}

// GetTasks returns all tasks
func (o *Orchestrator) GetTasks() []*Task {
	o.mu.RLock()
	defer o.mu.RUnlock()
	return o.tasks.All()
}

// GetTask returns a specific task
func (o *Orchestrator) GetTask(id string) (*Task, bool) {
	o.mu.RLock()
	defer o.mu.RUnlock()
	return o.tasks.Get(id)
}

// CancelTask removes a task
func (o *Orchestrator) CancelTask(id string) bool {
	o.mu.Lock()
	defer o.mu.Unlock()
	ok := o.tasks.Remove(id)
	if ok {
		o.saveState()
	}
	return ok
}

// PauseAll sets all agents to paused
func (o *Orchestrator) PauseAll() int {
	o.mu.Lock()
	defer o.mu.Unlock()
	count := 0
	for _, a := range o.agents {
		if a.Status != AgentOffline {
			a.Paused = true
			count++
		}
	}
	return count
}

// ResumeAll resumes all agents
func (o *Orchestrator) ResumeAll() int {
	o.mu.Lock()
	defer o.mu.Unlock()
	count := 0
	for _, a := range o.agents {
		if a.Paused {
			a.Paused = false
			count++
		}
	}
	return count
}

// Status returns swarm summary
func (o *Orchestrator) Status() SwarmStatus {
	o.mu.RLock()
	defer o.mu.RUnlock()

	s := SwarmStatus{
		TotalAgents:  len(o.agents),
		TotalTasks:   o.tasks.Len(),
		PendingTasks: o.tasks.CountByStatus(TaskPending),
	}

	for _, a := range o.agents {
		switch a.Status {
		case AgentIdle, AgentPolling:
			s.IdleAgents++
		case AgentWorking:
			s.WorkingAgents++
		case AgentOffline:
			s.OfflineAgents++
		case AgentError:
			s.ErrorAgents++
		}
		if time.Since(a.LastHeartbeat) > 2*time.Minute {
			s.UnhealthyAgents++
		}
	}
	return s
}

// saveState persists state to disk
func (o *Orchestrator) saveState() {
	if o.dataPath == "" {
		return
	}
	state := struct {
		Tasks []*Task  `json:"tasks"`
		Agents map[string]*Agent `json:"agents"`
	}{
		Tasks:  o.tasks.All(),
		Agents: o.agents,
	}
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		log.Printf("[Swarm] Failed to marshal state: %v", err)
		return
	}
	if err := os.WriteFile(o.dataPath, data, 0644); err != nil {
		log.Printf("[Swarm] Failed to save state: %v", err)
	}
}

// loadState restores state from disk
func (o *Orchestrator) loadState() {
	if o.dataPath == "" {
		return
	}
	data, err := os.ReadFile(o.dataPath)
	if err != nil {
		return // No state file yet
	}
	var state struct {
		Tasks  []*Task            `json:"tasks"`
		Agents map[string]*Agent  `json:"agents"`
	}
	if err := json.Unmarshal(data, &state); err != nil {
		log.Printf("[Swarm] Failed to parse state: %v", err)
		return
	}
	for _, t := range state.Tasks {
		o.tasks.Add(t)
	}
	if state.Agents != nil {
		o.agents = state.Agents
		// Mark all agents as offline on restart
		for _, a := range o.agents {
			a.Status = AgentOffline
		}
	}
	log.Printf("[Swarm] Loaded state: %d tasks, %d agents", len(state.Tasks), len(o.agents))
}

// SwarmStatus summary
type SwarmStatus struct {
	TotalAgents    int `json:"total_agents"`
	IdleAgents     int `json:"idle_agents"`
	WorkingAgents  int `json:"working_agents"`
	OfflineAgents  int `json:"offline_agents"`
	ErrorAgents    int `json:"error_agents"`
	UnhealthyAgents int `json:"unhealthy_agents"`
	TotalTasks     int `json:"total_tasks"`
	PendingTasks   int `json:"pending_tasks"`
}
