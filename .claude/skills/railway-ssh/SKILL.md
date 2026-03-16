---
name: railway-ssh
description: Execute commands on Railway cloud server via SSH. Handles auth, connection, tmux sessions. Use for deploying, updating code, managing ORACLE dashboard remotely.
argument-hint: [pull|oracle-restart|status|logs|agent-logs|exec <command>]
allowed-tools: Bash(ssh *), Bash(cat *), Bash(tri *), Bash(grep *), Read
---

# Railway SSH — Remote Server Management

## Connection Details

- **Host:** `interchange.proxy.rlwy.net`
- **Port:** `34920`
- **User:** `user`
- **Key:** `~/.ssh/id_ed25519`
- **Volume:** `/data/trinity` (persists across redeploys)

## SSH Command Template

ALWAYS use this pattern (disables ssh-agent to avoid "Too many authentication failures"):

```bash
SSH_AUTH_SOCK="" ssh -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 user@interchange.proxy.rlwy.net -p 34920 '<COMMAND>'
```

## Commands

### `$ARGUMENTS` = "pull" or empty
Pull latest code on Railway:
```bash
SSH_AUTH_SOCK="" ssh -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 user@interchange.proxy.rlwy.net -p 34920 'cd /data/trinity && git fetch origin && git pull --ff-only && echo "---DONE---"'
```
If pull fails (diverged branches), show the error and suggest resolution.

### `$ARGUMENTS` = "oracle-restart"
Restart ORACLE v2 dashboard (2 panes: admin + live logs):
```bash
# Kill old session
SSH_AUTH_SOCK="" ssh -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 user@interchange.proxy.rlwy.net -p 34920 'tmux kill-session -t oracle 2>/dev/null; cd /data/trinity; tmux new-session -d -s oracle -x 160 -y 50; tmux send-keys -t oracle "bash .ralph/scripts/god_mode_oracle.sh" C-m; sleep 0.5; TERM=xterm-256color tmux split-window -h -l 64 -t oracle:0.0 "cd /data/trinity && bash .ralph/scripts/god_mode_livelog.sh"; tmux select-pane -t oracle:0.0; echo "ORACLE v2 restarted"'
```

### `$ARGUMENTS` = "status"
Check server status:
```bash
SSH_AUTH_SOCK="" ssh -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 user@interchange.proxy.rlwy.net -p 34920 'echo "=== TMUX ==="; tmux list-sessions 2>/dev/null; echo "=== BRANCH ==="; cd /data/trinity && git branch --show-current; echo "=== HEAD ==="; git log --oneline -3; echo "=== ORACLE ==="; tmux list-panes -t oracle 2>/dev/null || echo "not running"'
```

### `$ARGUMENTS` = "logs"
Get Railway deploy/infra logs via MCP (SSH connections, deploys, errors):
```bash
railway logs --deployment --lines 30 --service "Agents Anywhere"
```
This shows sshd logs (connections/disconnections). For filtering use:
```bash
railway logs --deployment --lines 50 --service "Agents Anywhere" --filter "error"
```

### `$ARGUMENTS` = "agent-logs"
Get real-time agent activity logs from inside the container (stream events, tool_use, GOD MODE):
```bash
SSH_AUTH_SOCK="" ssh -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 user@interchange.proxy.rlwy.net -p 34920 'cd /data/trinity && echo "=== LAST STREAM ===" && STREAM=$(ls -t .ralph/logs/*_stream.log 2>/dev/null | head -1) && [ -n "$STREAM" ] && tail -20 "$STREAM" | jq -r "select(.type==\"assistant\") | .message.content[0] | select(.type==\"tool_use\") | \"\(.name): \(.input | to_entries | .[0] | .value)\"" 2>/dev/null | tail -10 || echo "(no stream logs)"; echo "=== GOD MODE ===" && tail -10 .ralph/god_mode_log.jsonl 2>/dev/null || echo "(no events)"; echo "=== MCP AUDIT ===" && tail -10 .trinity/mcp_audit.log 2>/dev/null || echo "(no audit)"'
```

### `$ARGUMENTS` starts with "exec"
Run arbitrary command on Railway (strip "exec " prefix):
```bash
SSH_AUTH_SOCK="" ssh -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 user@interchange.proxy.rlwy.net -p 34920 '<remaining arguments after exec>'
```

## Important Notes

- **tmux split-window over SSH:** Use `-l <cols>` (absolute) not `-p <percent>` — percent doesn't work without a terminal
- **tmux attach:** Cannot be done from Claude Code (no TTY). Tell user: `SSH_AUTH_SOCK="" ssh -i ~/.ssh/id_ed25519 user@interchange.proxy.rlwy.net -p 34920` then `tmux attach -t oracle`
- **Timeout:** Set 30s timeout on SSH commands to avoid hanging
- After running the command, show the output to the user with a brief summary in Russian
