#!/bin/bash
set -e

LOGFILE="/vivado/setup.log"
MARKER="/vivado/.installed"
VIVADO_BIN="/vivado/Vivado/2025.2/2025.2/Vivado/bin/vivado"

echo "=== Trinity FPGA Build Server ===" | tee $LOGFILE
echo "$(date)" | tee -a $LOGFILE

# Step 1: Restore auth token from volume (if exists)
if [ -d "/vivado/.xilinx_backup" ]; then
    echo ">>> Restoring auth token from volume..." | tee -a $LOGFILE
    mkdir -p /root/.Xilinx
    cp -r /vivado/.xilinx_backup/* /root/.Xilinx/
fi

# Step 2: If Vivado is already installed (on volume), go straight to synthesis
if [ -f "$VIVADO_BIN" ]; then
    touch $MARKER
    echo ">>> Vivado already installed on volume" | tee -a $LOGFILE
else
    # Need to install - extract installer if needed
    if [ ! -d "/vivado/installer" ] && [ -f "/opt/vivado_install.bin" ]; then
        echo ">>> Extracting Vivado installer..." | tee -a $LOGFILE
        /opt/vivado_install.bin --noexec --target /vivado/installer >> $LOGFILE 2>&1
        echo ">>> Extraction complete" | tee -a $LOGFILE
    fi

    # Generate auth token if needed
    if [ ! -f "/root/.Xilinx/wi_authentication_key" ]; then
        echo ">>> Generating auth token via expect..." | tee -a $LOGFILE
        /opt/setup_and_synth.exp >> $LOGFILE 2>&1
        mkdir -p /vivado/.xilinx_backup
        cp -r /root/.Xilinx/* /vivado/.xilinx_backup/
    fi

    # Install Vivado
    if [ -d "/vivado/installer" ]; then
        echo ">>> Starting Vivado installation..." | tee -a $LOGFILE
        /vivado/installer/xsetup \
            -a XilinxEULA,3rdPartyEULA \
            -b Install \
            -c /opt/install_config.txt \
            >> $LOGFILE 2>&1 || true

        if [ -f "$VIVADO_BIN" ]; then
            touch $MARKER
            echo ">>> Vivado installed successfully!" | tee -a $LOGFILE
        else
            echo ">>> Vivado install FAILED" | tee -a $LOGFILE
        fi
    fi
fi

# Step 3: Run synthesis
if [ -f "$VIVADO_BIN" ]; then
    echo ">>> Setting up Vivado environment..." | tee -a $LOGFILE
    source /vivado/Vivado/2025.2/2025.2/Vivado/settings64.sh

    echo ">>> Running synthesis... $(date)" | tee -a $LOGFILE
    # Use QMTECH synthesis script for XC7A100T
    vivado -mode batch -source /workspace/tcl/synth_qmtech.tcl >> $LOGFILE 2>&1
    echo ">>> Synthesis complete! $(date)" | tee -a $LOGFILE
    ls -lh /workspace/output/trinity_qmtech.bit >> $LOGFILE 2>&1 || true
fi

echo ">>> Entering idle mode. $(date)" | tee -a $LOGFILE

# Keep container alive
exec tail -f /dev/null
