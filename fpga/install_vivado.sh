#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════
# TRINITY FPGA — Vivado Installation Guide for macOS
# ═════════════════════════════════════════════════════════════════════════

cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║  VIVADO WEBPACK — INSTALLATION GUIDE FOR MACOS                       ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  1. DOWNLOAD (15-30 min, ~40 GB)                                    ║
║                                                                      ║
║  Go to:                                                              ║
║  https://www.xilinx.com/member/forms/download/xef-vivado.html        ║
║                                                                      ║
║  Select:                                                             ║
║  • Vivado ML Standard                                                 ║
║  • Version: 2024.2 or 2025.1 (latest)                                ║
║  • OS: macOS                                                          ║
║  • File: Single File Download (SFD) or Web Installer                 ║
║                                                                      ║
║  2. INSTALLATION (20-40 min)                                         ║
║                                                                      ║
║  After downloading:                                                  ║
║                                                                      ║
║  # Extract (if .tar.gz or .tgz)                                     ║
║  tar -xzf Vivado-*.tar.gz                                            ║
║                                                                      ║
║  # Or open DMG                                                       ║
║  open Vivado-*.dmg                                                   ║
║                                                                      ║
║  Run installer and follow instructions:                             ║
║                                                                      ║
║  Make sure to select:                                               ║
║  ✓ Vivado                                                            ║
║  ✓ Cable Drivers (for JTAG/Platform Cable USB)                       ║
║                                                                      ║
║  Install to: /Applications/Xilinx/Vivado/2024.2/                    ║
║                                                                      ║
║  3. ADD TO PATH                                                      ║
║                                                                      ║
║  echo 'export PATH="/Applications/Xilinx/Vivado/2024.2/bin:$PATH"' \  ║
║      >> ~/.zshrc                                                     ║
║  source ~/.zshrc                                                      ║
║                                                                      ║
║  4. VERIFY                                                           ║
║                                                                      ║
║  vivado -version                                                      ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

Once Vivado is installed, run:

    bash fpga/generate_bitstream_vivado.sh

╔══════════════════════════════════════════════════════════════════════╗
║  ALTERNATIVE: Linux/Windows machine                                 ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  If you don't want to install 40GB on Mac:                          ║
║                                                                      ║
║  1. Create Linux VM (VirtualBox/VMware/UTM)                          ║
║  2. Or use cloud machine (AWS, Google Cloud)                         ║
║  3. Install Vivado there                                            ║
║  4. Generate .bit file                                               ║
║  5. Transfer to Mac and flash via OpenOCD                            ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF
