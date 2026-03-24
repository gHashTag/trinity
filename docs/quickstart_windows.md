# Quick Start - Windows

Complete guide to get Trinity running on Windows.

---

## Supported Versions

- Windows 10 21H2 (build 19044) or later
- Windows 11 (all versions)
- Windows Server 2022 or later

---

## Prerequisites

### Required

- **PowerShell 7.0+** or **Windows Terminal**
- **Git for Windows** — https://git-scm.com/download/win

### Optional

- **Visual Studio Build Tools 2022** — for some native builds
- **Windows Terminal** — Recommended for better experience
- **Scoop** — Package manager

---

## Installation

### Option 1: Pre-built Binary (Recommended)

#### Using Scoop

```powershell
# Install Scoop if not installed
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# Install Trinity
scoop bucket add ghashtag https://github.com/gHashTag/scoop.git
scoop install trinity

# Verify
tri --version
```

#### Manual Download

1. Download from: https://github.com/gHashTag/trinity/releases
2. Extract to: `C:\trinity`
3. Add to PATH:
   ```powershell
   [System.Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\trinity\bin", "User")
   ```
4. Restart terminal

### Option 2: Build from Source

```powershell
# Clone repository
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Download Zig 0.15.x
# Visit: https://ziglang.org/download/
# Download: zig-windows-x86_64-0.15.0.zip
# Extract to: C:\zig

# Add to PATH (PowerShell)
$env:Path = "C:\zig;C:\zig\zig-windows-x86_64-0.15.0;" + $env:Path

# Build TRI CLI
.\zig\zig-windows-x86_64-0.15.0\zig.exe build tri

# Run
.\zig-out\bin\tri.exe --version
```

### Option 3: WSL2 (Linux on Windows)

Recommended for full compatibility with Linux tools.

```powershell
# Enable WSL2
wsl --install

# Download and build inside WSL Ubuntu
wsl
cd ~
git clone https://github.com/gHashTag/trinity.git
cd trinity
# Follow Linux quick start guide
```

### Option 4: Docker Desktop

```powershell
# Install Docker Desktop
# Download: https://www.docker.com/products/docker-desktop/

# Pull Trinity image
docker pull ghcr.io/ghashtag/trinity:latest

# Run
docker run -it --rm ghcr.io/ghashtag/trinity:latest --version
```

---

## Quick Test

```powershell
# Show sacred constants
tri constants

# Interactive REPL
tri

# Run tests (requires WSL or proper setup)
zig build test
```

---

## FPGA Setup (Windows)

### Hardware

- QMTech XC7A100T FPGA board
- FTDI JTAG cable
- USB drivers

### Install Drivers

1. Download FTDI drivers: https://ftdichip.com/Drivers/VCP.htm
2. Install "CDM" (virtual COM port) drivers
3. Install "D2XX" drivers for direct access

### Install Tools

```powershell
# Using Scoop
scoop install openfpgaloader fxload

# Or download from GitHub
# openFPGALoader: https://github.com/trabucay/openFPGALoader/releases
# fxload: Included with FTDI drivers
```

### Flash FPGA

**PowerShell:**
```powershell
# CRITICAL: Switch JTAG cable to JTAG mode first
fxload -t fx2 -I .\fpga\openxc7-synth\xc7a-xc7s-ftdi.hex -d 0x0013

# Now flash
tri fpga flash
```

**Or using openFPGALoader directly:**
```powershell
openFPGALoader.exe --cable ft232 --bitstream fpga\openxc7-synth\hslm_full_top.bit
```

---

## Common Issues on Windows

### "tri: command not found"

```powershell
# Add to PATH (user scope)
$env:Path = "C:\trinity\bin;" + $env:Path

# Set permanently
[System.Environment]::SetEnvironmentVariable("Path", $env:Path, "User")

# Restart terminal for changes to take effect
```

### "Cannot execute because of security policy"

```powershell
# Set execution policy for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Failed to build - MSVC not found"

```powershell
# Install Visual Studio Build Tools 2022
# Download: https://visualstudio.microsoft.com/downloads/
# Select "C++ build tools"
```

### "Build fails with path too long"

Windows has 260 character path limit. Use WSL2 or move repo to short path like `C:\tri`.

### FTDI Device Not Found

```powershell
# Check device manager for FTDI devices
# Ensure drivers are installed
# Try different USB port
```

---

## IDE Setup

### Visual Studio Code

1. Install VS Code: https://code.visualstudio.com/
2. Install Zig extension:
   ```powershell
   code --install-extension ziglang.vscode-zig
   ```
3. Configure `settings.json`:
   ```json
   {
     "zig.zigPath": "C:\\zig\\zig-windows-x86_64-0.15.0\\zig.exe",
     "zig.formattingProvider": "zls",
     "terminal.integrated.defaultProfile.windows": "PowerShell"
   }
   ```

### JetBrains CLion

1. Install CLion
2. Install Zig plugin from Marketplace
3. Configure Zig SDK path in Settings
4. Set up build configuration

---

## Windows Terminal Setup (Recommended)

1. Install Windows Terminal from Microsoft Store
2. Configure profiles:

```json
{
  "profiles": {
    "defaults": {
      "fontFace": "Cascadia Code",
      "fontSize": 12,
      "colorScheme": "One Half Dark"
    },
    "list": [
      {
        "guid": "{574e775e-4f2a-5b96-accd-aa8442612089}",
        "name": "Trinity",
        "commandline": "tri.exe",
        "icon": "C:\\trinity\\icon.ico",
        "startingDirectory": "%USERPROFILE%\\trinity"
      }
    ]
  }
}
```

---

## PowerShell Profile Setup

Customize PowerShell profile for Trinity:

```powershell
# Edit profile
notepad $PROFILE

# Add these lines
function tri { C:\tri\bin\tri.exe @args }
$env:Path = "C:\tri\bin;" + $env:Path

# Save and restart terminal
```

---

## Building Tests (Windows Specific)

Tests require WSL2 or MinGW due to Zig limitations on Windows.

### Using WSL2

```powershell
# Inside WSL Ubuntu
wsl
cd ~/trinity
zig build test
```

### Using MinGW

```powershell
# Install MinGW-w64
# Download: https://www.mingw-w64.org/
# Add to PATH

# Build tests
C:\mingw64\bin\zig.exe build tri
```

---

## Next Steps

- Read [README.md](../README.md) for all commands
- Check [CONTRIBUTING.md](../CONTRIBUTING.md) for development
- See [docs/troubleshooting.md](troubleshooting.md) for issues
- Consider using WSL2 for full Linux compatibility

---

*Last updated: 2026-03-24*
