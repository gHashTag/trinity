# Quick Start - Linux

Complete guide to get Trinity running on Linux.

---

## Supported Distributions

- Ubuntu 22.04 LTS / 24.04 LTS
- Debian 12 (Bookworm)
- Fedora 39+
- Arch Linux
- Other Linux distributions with glibc 2.35+

---

## Prerequisites

### Required Packages

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install -y \
  build-essential \
  git \
  curl \
  xz-utils \
  libssl-dev
```

#### Fedora
```bash
sudo dnf install -y \
  git \
  curl \
  gcc \
  make \
  openssl-devel
```

#### Arch Linux
```bash
sudo pacman -S --needed \
  base-devel \
  git \
  curl
```

---

## Installation

### Option 1: Pre-built Binary (AUR)

```bash
# Arch Linux (AUR)
yay -S trinity-cli

# Verify
tri --version
```

### Option 2: Build from Source

```bash
# Clone repository
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Download Zig 0.15.x
wget https://ziglang.org/download/0.15.0/zig-linux-x86_64-0.15.0.tar.xz
tar -xf zig-linux-x86_64-0.15.0.tar.xz

# Add to PATH (or move to /usr/local)
export PATH="$PWD/zig-linux-x86_64-0.15.0:$PATH"

# Build TRI CLI
zig build tri

# Install globally (optional)
sudo cp ./zig-out/bin/tri /usr/local/bin/
```

### Option 3: Docker

```bash
docker pull ghcr.io/ghashtag/trinity:latest
docker run -it --rm ghcr.io/ghashtag/trinity:latest --version
```

---

## Quick Test

```bash
# Show sacred constants
tri constants

# Interactive REPL
tri

# Run tests
zig build test
```

---

## FPGA Setup (Linux)

### Hardware

- QMTech XC7A100T FPGA board
- FTDI JTAG cable
- USB permissions

### Install Tools

#### Ubuntu/Debian
```bash
sudo apt install -y openfpgaloader fxload
```

#### Fedora
```bash
sudo dnf install -y openfpgaloader fxload
```

#### Arch Linux
```bash
sudo pacman -S openfpgaloader fxload
```

### USB Permissions

Create udev rule for FTDI devices:

```bash
sudo nano /etc/udev/rules.d/99-ftdi.rules
```

Add:
```
# FTDI devices for FPGA programming
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6010", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6014", MODE="0666"
```

Reload rules:
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Flash FPGA

```bash
# CRITICAL: Switch JTAG cable to JTAG mode first
sudo fxload -t fx2 -I ./fpga/openxc7-synth/xc7a-xc7s-ftdi.hex -d 0x0013

# Now flash (may need sudo for USB access)
tri fpga flash
# OR
sudo openfpgaloader --cable ft232 --bitstream fpga/openxc7-synth/hslm_full_top.bit
```

---

## Common Issues on Linux

### "zig: command not found"

```bash
# Add Zig to PATH
export PATH="$PWD/zig-linux-x86_64-0.15.0:$PATH"

# Add to ~/.bashrc for persistence
echo 'export PATH="$HOME/zig-linux-x86_64-0.15.0:$PATH"' >> ~/.bashrc
```

### "Permission denied" for USB devices

```bash
# Add user to dialout group
sudo usermod -a -G dialout $USER

# Log out and back in for changes to take effect
```

### "Cannot open shared object file"

```bash
# Install missing libraries
sudo apt install -y libstdc++6 libssl3  # Ubuntu/Debian
```

### Build fails with "out of memory"

```bash
# Reduce parallel jobs
zig build tri -Dn=2
```

---

## IDE Setup

### VS Code

```bash
# Install Zig extension
code --install-extension ziglang.vscode-zig

# Configure settings
cat > ~/.config/Code/User/settings.json << EOF
{
  "zig.zigPath": "/usr/local/bin/zig",
  "zig.formattingProvider": "zls"
}
EOF
```

### NeoVim

```bash
# Install Zig LSP
:LspInstall zls

# Configure
lua << EOF
vim.g.zig_fmt_autosave = false
vim.g.zig_syntax_disable = false
EOF
```

---

## Systemd Service (Optional)

Create systemd service for Trinity node:

```bash
sudo nano /etc/systemd/system/trinity-node.service
```

```
[Unit]
Description=Trinity Node
After=network.target

[Service]
Type=simple
User=trinity
WorkingDirectory=/opt/trinity
ExecStart=/usr/local/bin/tri node serve
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable trinity-node
sudo systemctl start trinity-node
```

---

## Performance Tuning

### CPU Performance

```bash
# Set CPU governor to performance
sudo cpupower frequency-set -g performance
```

### Disable Swap (for large builds)

```bash
sudo swapoff -a
# Re-enable with: sudo swapon -a
```

---

## Next Steps

- Read [README.md](../README.md) for all commands
- Check [CONTRIBUTING.md](../CONTRIBUTING.md) for development
- See [docs/troubleshooting.md](troubleshooting.md) for issues

---

*Last updated: 2026-03-24*
