package mcpswarm

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

// GitHubSync polls GitHub Issues API for issues labeled "assign:ralph"
// and syncs them as swarm tasks via MCP tools.
type GitHubSync struct {
	proxy    *Proxy
	owner    string
	repo     string
	token    string
	interval time.Duration
	stopCh   chan struct{}
}

// NewGitHubSync creates a GitHub sync poller. Returns nil if not configured.
func NewGitHubSync(proxy *Proxy) *GitHubSync {
	owner := os.Getenv("GITHUB_OWNER")
	repo := os.Getenv("GITHUB_REPO")
	token := os.Getenv("GITHUB_TOKEN")

	if owner == "" || repo == "" {
		log.Println("[GitHubSync] GITHUB_OWNER or GITHUB_REPO not set, sync disabled")
		return nil
	}

	return &GitHubSync{
		proxy:    proxy,
		owner:    owner,
		repo:     repo,
		token:    token,
		interval: 60 * time.Second,
		stopCh:   make(chan struct{}),
	}
}

// Start begins the polling loop in a goroutine.
func (g *GitHubSync) Start() {
	go g.pollLoop()
	log.Printf("[GitHubSync] Started polling %s/%s every %s", g.owner, g.repo, g.interval)
}

// Stop terminates the polling loop.
func (g *GitHubSync) Stop() {
	close(g.stopCh)
}

func (g *GitHubSync) pollLoop() {
	// Initial sync
	g.syncIssues()

	ticker := time.NewTicker(g.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			g.syncIssues()
		case <-g.stopCh:
			return
		}
	}
}

// ghIssue is a minimal GitHub issue from the API.
type ghIssue struct {
	Number int       `json:"number"`
	Title  string    `json:"title"`
	State  string    `json:"state"`
	Labels []ghLabel `json:"labels"`
}

type ghLabel struct {
	Name string `json:"name"`
}

func (g *GitHubSync) syncIssues() {
	issues, err := g.fetchIssues()
	if err != nil {
		log.Printf("[GitHubSync] Fetch error: %v", err)
		return
	}

	for _, issue := range issues {
		if issue.State != "open" {
			continue
		}
		if !hasLabel(issue.Labels, "assign:ralph") {
			continue
		}

		// Build labels CSV
		var labels []string
		for _, l := range issue.Labels {
			labels = append(labels, l.Name)
		}
		labelsCSV := strings.Join(labels, ",")

		// Call MCP tool
		result, err := g.proxy.CallTool("swarm_github_sync", map[string]interface{}{
			"issue_number": fmt.Sprintf("%d", issue.Number),
			"title":        issue.Title,
			"labels":       labelsCSV,
		})
		if err != nil {
			log.Printf("[GitHubSync] swarm_github_sync error for #%d: %v", issue.Number, err)
			continue
		}

		var syncResult struct {
			Created bool   `json:"created"`
			Exists  bool   `json:"exists"`
			TaskID  string `json:"task_id"`
		}
		if json.Unmarshal([]byte(result), &syncResult) == nil && syncResult.Created {
			log.Printf("[GitHubSync] Created task %s from issue #%d", syncResult.TaskID, issue.Number)

			// Apply label changes on GitHub
			g.removeLabel(issue.Number, "assign:ralph")
			g.addLabel(issue.Number, "status:pending")
		}
	}
}

// NotifyTaskStarted sends GitHub updates when an agent starts a task.
func (g *GitHubSync) NotifyTaskStarted(taskID, agentID, branch string) {
	result, err := g.proxy.CallTool("swarm_github_on_start", map[string]interface{}{
		"task_id":  taskID,
		"agent_id": agentID,
		"branch":   branch,
	})
	if err != nil {
		log.Printf("[GitHubSync] on_start error: %v", err)
		return
	}
	g.applyGitHubActions(result)
}

// NotifyTaskCompleted sends GitHub updates when a task completes.
func (g *GitHubSync) NotifyTaskCompleted(taskID, agentID, resultSummary string) {
	result, err := g.proxy.CallTool("swarm_github_on_complete", map[string]interface{}{
		"task_id":  taskID,
		"agent_id": agentID,
		"result":   resultSummary,
	})
	if err != nil {
		log.Printf("[GitHubSync] on_complete error: %v", err)
		return
	}
	g.applyGitHubActions(result)
}

// NotifyTaskFailed sends GitHub updates when a task fails.
func (g *GitHubSync) NotifyTaskFailed(taskID, agentID, errorMsg string) {
	result, err := g.proxy.CallTool("swarm_github_on_fail", map[string]interface{}{
		"task_id":  taskID,
		"agent_id": agentID,
		"error":    errorMsg,
	})
	if err != nil {
		log.Printf("[GitHubSync] on_fail error: %v", err)
		return
	}
	g.applyGitHubActions(result)
}

// ghAction is the parsed response from GitHub MCP tools.
type ghAction struct {
	Skip         bool     `json:"skip"`
	Issue        int      `json:"issue"`
	LabelsAdd    []string `json:"labels_add"`
	LabelsRemove []string `json:"labels_remove"`
	Comment      string   `json:"comment"`
	CloseIssue   bool     `json:"close_issue"`
}

func (g *GitHubSync) applyGitHubActions(resultJSON string) {
	var action ghAction
	if err := json.Unmarshal([]byte(resultJSON), &action); err != nil {
		return
	}
	if action.Skip || action.Issue == 0 {
		return
	}

	for _, label := range action.LabelsRemove {
		g.removeLabel(action.Issue, label)
	}
	for _, label := range action.LabelsAdd {
		g.addLabel(action.Issue, label)
	}
	if action.Comment != "" {
		g.postComment(action.Issue, action.Comment)
	}
	if action.CloseIssue {
		g.closeIssue(action.Issue)
	}
}

// --- GitHub API helpers ---

func (g *GitHubSync) fetchIssues() ([]ghIssue, error) {
	url := fmt.Sprintf("https://api.github.com/repos/%s/%s/issues?labels=assign:ralph&state=open&per_page=20",
		g.owner, g.repo)
	req, _ := http.NewRequest("GET", url, nil)
	g.setHeaders(req)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("GitHub API %d", resp.StatusCode)
	}

	var issues []ghIssue
	if err := json.NewDecoder(resp.Body).Decode(&issues); err != nil {
		return nil, err
	}
	return issues, nil
}

func (g *GitHubSync) addLabel(issue int, label string) {
	url := fmt.Sprintf("https://api.github.com/repos/%s/%s/issues/%d/labels", g.owner, g.repo, issue)
	body := fmt.Sprintf(`{"labels":[%q]}`, label)
	req, _ := http.NewRequest("POST", url, strings.NewReader(body))
	g.setHeaders(req)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Printf("[GitHubSync] addLabel error: %v", err)
		return
	}
	resp.Body.Close()
}

func (g *GitHubSync) removeLabel(issue int, label string) {
	url := fmt.Sprintf("https://api.github.com/repos/%s/%s/issues/%d/labels/%s", g.owner, g.repo, issue, label)
	req, _ := http.NewRequest("DELETE", url, nil)
	g.setHeaders(req)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Printf("[GitHubSync] removeLabel error: %v", err)
		return
	}
	resp.Body.Close()
}

func (g *GitHubSync) postComment(issue int, body string) {
	url := fmt.Sprintf("https://api.github.com/repos/%s/%s/issues/%d/comments", g.owner, g.repo, issue)
	payload := fmt.Sprintf(`{"body":%q}`, body)
	req, _ := http.NewRequest("POST", url, strings.NewReader(payload))
	g.setHeaders(req)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Printf("[GitHubSync] postComment error: %v", err)
		return
	}
	resp.Body.Close()
}

func (g *GitHubSync) closeIssue(issue int) {
	url := fmt.Sprintf("https://api.github.com/repos/%s/%s/issues/%d", g.owner, g.repo, issue)
	req, _ := http.NewRequest("PATCH", url, strings.NewReader(`{"state":"closed"}`))
	g.setHeaders(req)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Printf("[GitHubSync] closeIssue error: %v", err)
		return
	}
	resp.Body.Close()
}

func (g *GitHubSync) setHeaders(req *http.Request) {
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	if g.token != "" {
		req.Header.Set("Authorization", "Bearer "+g.token)
	}
}

func hasLabel(labels []ghLabel, name string) bool {
	for _, l := range labels {
		if l.Name == name {
			return true
		}
	}
	return false
}
