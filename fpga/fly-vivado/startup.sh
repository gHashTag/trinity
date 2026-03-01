#!/bin/bash
set -e

LOGFILE="/vivado/setup.log"
MARKER="/vivado/.installed"

echo "=== Trinity FPGA Build Server ===" | tee $LOGFILE
echo "$(date)" | tee -a $LOGFILE

# Step 1: Extract installer (if not done)
if [ ! -d "/vivado/installer" ]; then
    echo ">>> Extracting Vivado installer..." | tee -a $LOGFILE
    /opt/vivado_install.bin --noexec --target /vivado/installer >> $LOGFILE 2>&1
    echo ">>> Extraction complete" | tee -a $LOGFILE
fi

# Step 2: Generate auth token + install (if not done)
if [ ! -f "$MARKER" ]; then
    echo ">>> Running auth + install via expect..." | tee -a $LOGFILE
    /opt/setup_and_synth.exp >> $LOGFILE 2>&1 || true

    # Check if Vivado was installed
    if [ -f "/vivado/Vivado/2025.2/bin/vivado" ]; then
        touch $MARKER
        echo ">>> Vivado installed successfully!" | tee -a $LOGFILE
    else
        echo ">>> Vivado install may have failed. Check $LOGFILE" | tee -a $LOGFILE
    fi
fi

# Step 3: If Vivado is installed, run synthesis
if [ -f "/vivado/Vivado/2025.2/bin/vivado" ]; then
    echo ">>> Running synthesis..." | tee -a $LOGFILE
    /vivado/Vivado/2025.2/bin/vivado -mode batch -source /workspace/tcl/synth_fly.tcl >> $LOGFILE 2>&1
    echo ">>> Synthesis complete!" | tee -a $LOGFILE
    ls -lh /workspace/output/trinity.bit >> $LOGFILE 2>&1
fi

echo ">>> Entering idle mode. Check logs: cat /vivado/setup.log" | tee -a $LOGFILE

# Keep container alive
exec tail -f /dev/null
