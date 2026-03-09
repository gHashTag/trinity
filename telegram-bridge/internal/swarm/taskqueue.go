package swarm

import (
	"sort"
	"time"
)

// TaskStatus represents the state of a task
type TaskStatus string

const (
	TaskPending   TaskStatus = "pending"
	TaskAssigned  TaskStatus = "assigned"
	TaskRunning   TaskStatus = "running"
	TaskCompleted TaskStatus = "completed"
	TaskFailed    TaskStatus = "failed"
	TaskBlocked   TaskStatus = "blocked"
	TaskCancelled TaskStatus = "cancelled"
)

// TaskPriority levels
type TaskPriority string

const (
	PriorityP0 TaskPriority = "P0" // Critical
	PriorityP1 TaskPriority = "P1" // High
	PriorityP2 TaskPriority = "P2" // Medium
	PriorityP3 TaskPriority = "P3" // Low
)

// Task represents a unit of work for an agent
type Task struct {
	ID            string       `json:"id"`
	Slug          string       `json:"slug"`
	Description   string       `json:"description"`
	Priority      TaskPriority `json:"priority"`
	Status        TaskStatus   `json:"status"`
	AssignedTo    string       `json:"assigned_to,omitempty"`
	AffectedFiles []string     `json:"affected_files,omitempty"`
	Branch        string       `json:"branch,omitempty"`
	CreatedAt     time.Time    `json:"created_at"`
	AssignedAt    time.Time    `json:"assigned_at,omitempty"`
	CompletedAt   time.Time    `json:"completed_at,omitempty"`
	Result        string       `json:"result,omitempty"`
}

// TaskQueue is a priority-based task queue
type TaskQueue struct {
	tasks []*Task
}

// NewTaskQueue creates a new empty task queue
func NewTaskQueue() *TaskQueue {
	return &TaskQueue{
		tasks: make([]*Task, 0),
	}
}

// Add appends a task to the queue
func (q *TaskQueue) Add(t *Task) {
	q.tasks = append(q.tasks, t)
	q.sortByPriority()
}

// NextPending returns the highest-priority pending task
func (q *TaskQueue) NextPending() *Task {
	for _, t := range q.tasks {
		if t.Status == TaskPending {
			return t
		}
	}
	return nil
}

// Get returns a task by ID
func (q *TaskQueue) Get(id string) (*Task, bool) {
	for _, t := range q.tasks {
		if t.ID == id {
			return t, true
		}
	}
	return nil, false
}

// Remove deletes a task by ID
func (q *TaskQueue) Remove(id string) bool {
	for i, t := range q.tasks {
		if t.ID == id {
			q.tasks = append(q.tasks[:i], q.tasks[i+1:]...)
			return true
		}
	}
	return false
}

// All returns all tasks
func (q *TaskQueue) All() []*Task {
	result := make([]*Task, len(q.tasks))
	copy(result, q.tasks)
	return result
}

// Len returns total task count
func (q *TaskQueue) Len() int {
	return len(q.tasks)
}

// CountByStatus counts tasks with a given status
func (q *TaskQueue) CountByStatus(status TaskStatus) int {
	count := 0
	for _, t := range q.tasks {
		if t.Status == status {
			count++
		}
	}
	return count
}

// sortByPriority sorts tasks: P0 first, then by creation time
func (q *TaskQueue) sortByPriority() {
	sort.Slice(q.tasks, func(i, j int) bool {
		pi := priorityWeight(q.tasks[i].Priority)
		pj := priorityWeight(q.tasks[j].Priority)
		if pi != pj {
			return pi < pj // Lower weight = higher priority
		}
		return q.tasks[i].CreatedAt.Before(q.tasks[j].CreatedAt)
	})
}

func priorityWeight(p TaskPriority) int {
	switch p {
	case PriorityP0:
		return 0
	case PriorityP1:
		return 1
	case PriorityP2:
		return 2
	case PriorityP3:
		return 3
	default:
		return 9
	}
}
