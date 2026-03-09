# Trinity MCP Server — Windows Auto-Discovery Setup Script
# φ² + 1/φ² = 3 = TRINITY

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$BinaryPath = Join-Path $ProjectRoot "zig-out\bin\trinity-mcp.exe"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  TRINITY MCP SERVER v2.1 — Auto-Discovery Setup (Windows)" -ForegroundColor Cyan
Write-Host "  φ² + 1/φ² = 3 = TRINITY" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check if binary exists
if (-not (Test-Path $BinaryPath)) {
    Write-Host "⚠️  MCP server binary not found at: $BinaryPath" -ForegroundColor Yellow
    Write-Host "Building now..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
    zig build
    Pop-Location
}

# Convert path to Windows format
$BinaryPath = (Resolve-Path $BinaryPath).Path

Write-Host ""
Write-Host "Select your IDE/editor:" -ForegroundColor White
Write-Host "  1) Claude Desktop" -ForegroundColor White
Write-Host "  2) Cursor IDE" -ForegroundColor White
Write-Host "  3) VS Code + Claude extension" -ForegroundColor White
Write-Host "  4) All of the above" -ForegroundColor White
Write-Host ""
$choice = Read-Host "Enter choice [1-4]"

switch ($choice) {
    "1" { $IDE = "claude" }
    "2" { $IDE = "cursor" }
    "3" { $IDE = "vscode" }
    "4" { $IDE = "all" }
    default {
        $IDE = "all"
        Write-Host "Invalid choice. Defaulting to 'all'" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Setting up for: $IDE" -ForegroundColor Green
Write-Host ""

# Claude Desktop setup
if ($IDE -eq "claude" -or $IDE -eq "all") {
    Write-Host "📦 Setting up Claude Desktop..." -ForegroundColor Cyan

    $ConfigDir = Join-Path $env:APPDATA "Claude\claude-desktop-config"
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null

    $ConfigPath = Join-Path $ConfigDir "trinity-mcp.json"

    $Config = @{
        mcpServers = @{
            trinity = @{
                command = $BinaryPath
                args = @()
                env = @{
                    TRINITY_MCP_PORT = "8899"
                    TRINITY_LOG_LEVEL = "info"
                }
            }
        }
    } | ConvertTo-Json -Depth 10

    $Config | Out-File -FilePath $ConfigPath -Encoding utf8

    Write-Host "  ✓ Config installed to: $ConfigPath" -ForegroundColor Green
    Write-Host "  → Restart Claude Desktop to apply changes" -ForegroundColor Yellow
    Write-Host ""
}

# Cursor setup
if ($IDE -eq "cursor" -or $IDE -eq "all") {
    Write-Host "📦 Setting up Cursor IDE..." -ForegroundColor Cyan

    $CursorConfigDir = Join-Path $env:APPDATA "Cursor"
    $CursorConfigPath = Join-Path $CursorConfigDir "mcp-servers.json"

    New-Item -ItemType Directory -Force -Path $CursorConfigDir | Out-Null

    $Config = @{
        trinity = @{
            command = $BinaryPath
            args = @()
        }
    } | ConvertTo-Json -Depth 10

    if (Test-Path $CursorConfigPath) {
        Write-Host "  ⚠️  Existing config found. Please add manually:" -ForegroundColor Yellow
        Write-Host "    @{`"command`" = `"$BinaryPath`"; `"args`" = @()}" -ForegroundColor Gray
    } else {
        $Config | Out-File -FilePath $CursorConfigPath -Encoding utf8
        Write-Host "  ✓ Config installed to: $CursorConfigPath" -ForegroundColor Green
        Write-Host "  → Restart Cursor to apply changes" -ForegroundColor Yellow
    }
    Write-Host ""
}

# VS Code setup
if ($IDE -eq "vscode" -or $IDE -eq "all") {
    Write-Host "📦 Setting up VS Code..." -ForegroundColor Cyan

    $VscodeDir = Join-Path $ProjectRoot ".vscode"
    $VscodeSettings = Join-Path $VscodeDir "settings.json"

    if (Test-Path $VscodeSettings) {
        Write-Host "  ⚠️  Existing .vscode\settings.json found. Add manually:" -ForegroundColor Yellow
        Write-Host "    \`"mcp.mcpServers\`": @{\`"trinity\`": @{\`"command\`" = \`"$BinaryPath\`"}}" -ForegroundColor Gray
    } else {
        New-Item -ItemType Directory -Force -Path $VscodeDir | Out-Null

        $Config = @{
            "mcp.mcpServers" = @{
                trinity = @{
                    command = $BinaryPath
                    args = @()
                }
            }
        } | ConvertTo-Json -Depth 10

        $Config | Out-File -FilePath $VscodeSettings -Encoding utf8
        Write-Host "  ✓ Config installed to: $VscodeSettings" -ForegroundColor Green
        Write-Host "  → Reload VS Code window to apply changes" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Summary
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ✅ Setup Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Available Tools: 148+" -ForegroundColor White
Write-Host "  MCP Protocol: 2025-06-18" -ForegroundColor White
Write-Host "  Server Version: 2.1.0" -ForegroundColor White
Write-Host ""
Write-Host "  Test the server:" -ForegroundColor Yellow
Write-Host "    echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\"}' | $BinaryPath" -ForegroundColor Gray
Write-Host ""
Write-Host "  φ² + 1/φ² = 3 = TRINITY" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
