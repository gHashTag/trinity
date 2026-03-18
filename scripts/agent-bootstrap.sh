#!/bin/bash
# Trinity Agent Bootstrap — Git Worktree + TRI Pipeline
# Run INSIDE Railway "Agents Anywhere" container after SSH
# Usage: bash /data/trinity/scripts/agent-bootstrap.sh
set -euo pipefail

AGENT_ID="${AGENT_ID:-agent-$(hostname | cut -c1-8)}"
REPO_DIR="/data/trinity"
WORKTREE_BASE="/data/worktrees"
ORCHESTRATOR_URL="${ORCHESTRATOR_URL:-https://vibee-telegram-bridge.fly.dev}"

echo "=== Trinity Agent Bootstrap: $AGENT_ID ==="
echo "phi^2 + 1/phi^2 = 3"
echo ""

# ─── 1. Install Zig 0.15.2 ───────────────────────────────────
ZIG_VERSION="0.15.2"
ZIG_DIR="/data/zig-x86_64-linux-${ZIG_VERSION}"

if [ -x "${ZIG_DIR}/zig" ]; then
    echo "[1/6] Zig ${ZIG_VERSION} already installed"
else
    echo "[1/6] Installing Zig ${ZIG_VERSION}..."
    wget -q --show-progress -O /tmp/zig.tar.xz \
        "https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz"
    tar -xf /tmp/zig.tar.xz -C /data
    rm /tmp/zig.tar.xz
fi
sudo ln -sf "${ZIG_DIR}/zig" /usr/local/bin/zig 2>/dev/null || true
export PATH="${ZIG_DIR}:$PATH"
echo "    zig $(zig version)"

# ─── 2. Clone/Update Trinity Repo ────────────────────────────
echo "[2/6] Setting up Trinity repository..."
cd /data
if [ -d "$REPO_DIR" ]; then
    echo "    Repo exists, fetching latest..."
    cd "$REPO_DIR"
    git fetch origin main --depth 1
else
    echo "    Cloning (shallow, no submodules)..."
    git clone --depth 1 --no-recurse-submodules \
        https://github.com/gHashTag/trinity.git "$REPO_DIR"
fi

# ─── 3. Create Worktree Directory ────────────────────────────
echo "[3/6] Setting up Git Worktree structure..."
mkdir -p "$WORKTREE_BASE"
echo "    Worktree base: $WORKTREE_BASE"
echo "    Active worktrees:"
cd "$REPO_DIR"
git worktree prune
git worktree list

# ─── 4. Build TRI CLI + MCP ─────────────────────────────────
echo "[4/6] Building Trinity..."
cd "$REPO_DIR"
zig build 2>&1 | tail -5 || echo "    Build had warnings"

# ─── 5. Environment ─────────────────────────────────────────
echo "[5/6] Setting environment..."
ENV_FILE="/data/.env_agent_${AGENT_ID}"
cat > "${ENV_FILE}" << ENVEOF
export AGENT_ID="${AGENT_ID}"
export TRINITY_PROJECT_ROOT=${REPO_DIR}
export ZIG_VERSION=0.15
export TRINITY_MCP_PORT=8899
export ORCHESTRATOR_URL=${ORCHESTRATOR_URL}
export WORKTREE_BASE=${WORKTREE_BASE}
export PATH="${ZIG_DIR}:\$PATH"
ENVEOF

PROFILE="${HOME}/.bashrc"
if ! grep -q "env_agent_" "${PROFILE}" 2>/dev/null; then
    echo "source ${ENV_FILE}" >> "${PROFILE}"
fi
source "${ENV_FILE}"

# ─── 6. Register with Orchestrator ──────────────────────────
echo "[6/6] Registering agent with orchestrator..."
REGISTER_PAYLOAD=$(cat << JSON
{
    "agent_id": "${AGENT_ID}",
    "hostname": "$(hostname)",
    "capabilities": ["zig", "vibee", "tri-pipeline", "test", "bench"],
    "worktree_base": "${WORKTREE_BASE}",
    "status": "idle"
}
JSON
)

REGISTER_RESULT=$(curl -s -w "%{http_code}" -o /dev/null \
    -X POST "${ORCHESTRATOR_URL}/api/v1/swarm/agent/register" \
    -H "Content-Type: application/json" \
    -d "${REGISTER_PAYLOAD}" 2>/dev/null) || true

if [ "$REGISTER_RESULT" = "200" ] || [ "$REGISTER_RESULT" = "201" ]; then
    echo "    Registered with orchestrator: ${ORCHESTRATOR_URL}"
else
    echo "    WARNING: Could not register (HTTP ${REGISTER_RESULT}). Orchestrator may not be running yet."
    echo "    Agent will work in standalone mode."
fi

# ─── Verify ─────────────────────────────────────────────────
echo ""
echo "=== Agent Bootstrap Complete ==="
echo "    Agent ID:   ${AGENT_ID}"
echo "    Zig:        $(zig version)"
echo "    TRI CLI:    $(ls ${REPO_DIR}/zig-out/bin/tri 2>/dev/null && echo OK || echo 'NOT BUILT')"
echo "    MCP:        $(ls ${REPO_DIR}/zig-out/bin/trinity-mcp 2>/dev/null && echo OK || echo 'NOT BUILT')"
echo "    Worktrees:  ${WORKTREE_BASE}"
echo "    Orchestrator: ${ORCHESTRATOR_URL}"
echo ""
echo "To start agent loop:"
echo "  bash ${REPO_DIR}/scripts/agent-loop.sh"
echo ""
echo "To start Claude Code in a worktree:"
echo "  cd ${REPO_DIR}"
echo "  git worktree add -b ralph/${AGENT_ID}/my-task ${WORKTREE_BASE}/${AGENT_ID} origin/main"
echo "  cd ${WORKTREE_BASE}/${AGENT_ID}"
echo "  claude"
