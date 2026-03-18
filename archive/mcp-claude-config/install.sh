#!/bin/bash
# Trinity MCP Server — Auto-Discovery Setup Script
# φ² + 1/φ² = 3 = TRINITY

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BINARY_PATH="$PROJECT_ROOT/zig-out/bin/trinity-mcp"

echo "═══════════════════════════════════════════════════════════════"
echo "  TRINITY MCP SERVER v2.1 — Auto-Discovery Setup"
echo "  φ² + 1/φ² = 3 = TRINITY"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if binary exists
if [ ! -f "$BINARY_PATH" ]; then
    echo "⚠️  MCP server binary not found at: $BINARY_PATH"
    echo "Building now..."
    cd "$PROJECT_ROOT"
    zig build
fi

# Detect IDE
echo "Select your IDE/editor:"
echo "  1) Claude Desktop"
echo "  2) Cursor IDE"
echo "  3) VS Code + Claude extension"
echo "  4) All of the above"
echo ""
read -p "Enter choice [1-4]: " choice

case $choice in
    1|claude)
        IDE="claude"
        ;;
    2|cursor)
        IDE="cursor"
        ;;
    3|vscode)
        IDE="vscode"
        ;;
    4|all)
        IDE="all"
        ;;
    *)
        echo "Invalid choice. Defaulting to 'all'"
        IDE="all"
        ;;
esac

echo ""
echo "Setting up for: $IDE"
echo ""

# Claude Desktop setup
if [ "$IDE" = "claude" ] || [ "$IDE" = "all" ]; then
    echo "📦 Setting up Claude Desktop..."

    CONFIG_DIR="$HOME/Library/Application Support/Claude/claude-desktop-config"
    mkdir -p "$CONFIG_DIR"

    # Create config file
    cat > "$CONFIG_DIR/trinity-mcp.json" << EOF
{
  "mcpServers": {
    "trinity": {
      "command": "$BINARY_PATH",
      "args": [],
      "env": {
        "TRINITY_MCP_PORT": "8899",
        "TRINITY_LOG_LEVEL": "info"
      }
    }
  }
}
EOF

    echo "  ✓ Config installed to: $CONFIG_DIR"
    echo "  → Restart Claude Desktop to apply changes"
    echo ""
fi

# Cursor setup
if [ "$IDE" = "cursor" ] || [ "$IDE" = "all" ]; then
    echo "📦 Setting up Cursor IDE..."

    CURSOR_CONFIG="$HOME/.cursor/mcp-servers.json"
    mkdir -p "$(dirname "$CURSOR_CONFIG")"

    # Create or append to config
    if [ -f "$CURSOR_CONFIG" ]; then
        echo "  ⚠️  Existing config found. Please add manually:"
        echo "    {\"command\": \"$BINARY_PATH\", \"args\": []}"
    else
        cat > "$CURSOR_CONFIG" << EOF
{
  "trinity": {
    "command": "$BINARY_PATH",
    "args": []
  }
}
EOF
        echo "  ✓ Config installed to: $CURSOR_CONFIG"
        echo "  → Restart Cursor to apply changes"
    fi
    echo ""
fi

# VS Code setup
if [ "$IDE" = "vscode" ] || [ "$IDE" = "all" ]; then
    echo "📦 Setting up VS Code..."

    # Check if we're in a project
    if [ -d "$PROJECT_ROOT/.vscode" ]; then
        VSCODE_SETTINGS="$PROJECT_ROOT/.vscode/settings.json"

        if [ -f "$VSCODE_SETTINGS" ]; then
            echo "  ⚠️  Existing .vscode/settings.json found. Add manually:"
            echo "    \"mcp.mcpServers\": {\"trinity\": {\"command\": \"$BINARY_PATH\"}}"
        else
            mkdir -p "$PROJECT_ROOT/.vscode"
            cat > "$VSCODE_SETTINGS" << EOF
{
  "mcp.mcpServers": {
    "trinity": {
      "command": "$BINARY_PATH",
      "args": []
    }
  }
}
EOF
            echo "  ✓ Config installed to: $VSCODE_SETTINGS"
            echo "  → Reload VS Code window to apply changes"
        fi
    else
        echo "  ℹ️  Not in a VS Code project. Skipped."
    fi
    echo ""
fi

# Summary
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ Setup Complete!"
echo ""
echo "  Available Tools: 148+"
echo "  MCP Protocol: 2025-06-18"
echo "  Server Version: 2.1.0"
echo ""
echo "  Test the server:"
echo "    echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\"}' | $BINARY_PATH"
echo ""
echo "  φ² + 1/φ² = 3 = TRINITY"
echo "═══════════════════════════════════════════════════════════════"
