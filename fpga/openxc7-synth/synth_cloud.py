#!/usr/bin/env python3
"""
synth_cloud.py — FPGA Synthesis HTTP API for fly.io

POST /synthesize
{
    "verilog": "module top...",
    "top": "top_module",
    "xdc": "set_property PACKAGE_PIN..."
}

Returns:
{
    "bitstream": "<base64 encoded .bit>",
    "status": "success|error",
    "logs": "..."
}
"""

import base64
import json
import os
import subprocess
import tempfile
import traceback
from flask import Flask, request, jsonify
from flask_cors import CORS
from pathlib import Path

app = Flask(__name__)
CORS(app)

WORK_DIR = Path("/app")
OUTPUT_DIR = WORK_DIR / "output"
OUTPUT_DIR.mkdir(exist_ok=True)

CHIPDB = WORK_DIR / "chipdb" / "xc7a100tfgg676.bin"


def run_command(cmd, description):
    """Run command and return output."""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=300  # 5 min timeout
        )
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", f"Timeout: {description}"
    except Exception as e:
        return False, "", str(e)


@app.route("/", methods=["GET"])
def index():
    """Health check."""
    return jsonify({
        "service": "trinity-fpga-synth",
        "status": "ready",
        "chipdb": str(CHIPDB.exists())
    })


@app.route("/synthesize", methods=["POST"])
def synthesize():
    """
    Synthesize Verilog to bitstream.

    Request:
    {
        "verilog": "module top...",
        "top": "uart_top",
        "xdc": "set_property..."  // optional, uses default if omitted
    }

    Response:
    {
        "bitstream": "<base64>",
        "status": "success",
        "steps": [...]
    }
    """
    data = request.get_json()
    if not data or "verilog" not in data:
        return jsonify({"error": "Missing verilog field"}), 400

    verilog = data["verilog"]
    top = data.get("top", "top")
    xdc = data.get("xdc", DEFAULT_XDC)

    logs = []
    steps = []

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        v_file = tmp / "design.v"
        xdc_file = tmp / "design.xdc"

        # Write input files
        v_file.write_text(verilog)
        xdc_file.write_text(xdc)

        base = "design"

        # Step 1: Yosys synthesis
        logs.append("[1/4] Yosys synthesis...")
        success, stdout, stderr = run_command(
            f"yosys -p 'synth_xilinx -flatten -abc9 -nobram -arch xc7 -top {top}; "
            f"write_json {base}.json' {v_file}",
            "Yosys"
        )
        logs.append(stdout or stderr)
        if not success:
            return jsonify({"error": "Yosys failed", "logs": logs}), 500
        steps.append("yosys")

        # Step 2: nextpnr-xilinx
        logs.append("[2/4] nextpnr-xilinx place & route...")
        success, stdout, stderr = run_command(
            f"nextpnr-xilinx --chipdb {CHIPDB} --xdc {xdc_file} "
            f"--json {base}.json --write {base}_routed.json --fasm {base}.fasm "
            f"--freq 50 --seed 1",
            "nextpnr"
        )
        logs.append(stdout or stderr)
        if not success:
            return jsonify({"error": "nextpnr failed", "logs": logs}), 500
        steps.append("nextpnr")

        # Step 3: fasm2frames
        logs.append("[3/4] FASM to frames...")
        success, stdout, stderr = run_command(
            f"fasm2frames --db-root /nextpnr-xilinx/xilinx/external/prjxray-db/artix7 "
            f"--part xc7a100tfgg676-1 {base}.fasm {base}.frames",
            "fasm2frames"
        )
        logs.append(stdout or stderr)
        if not success:
            return jsonify({"error": "fasm2frames failed", "logs": logs}), 500
        steps.append("fasm2frames")

        # Step 4: xc7frames2bit
        logs.append("[4/4] Frames to bitstream...")
        success, stdout, stderr = run_command(
            f"/prjxray/build/tools/xc7frames2bit "
            f"--part_file /nextpnr-xilinx/xilinx/external/prjxray-db/artix7/xc7a100tfgg676-1/part.yaml "
            f"--part_name xc7a100tfgg676-1 --frm_file {base}.frames "
            f"--output_file {base}.bit",
            "xc7frames2bit"
        )
        logs.append(stdout or stderr)
        if not success:
            return jsonify({"error": "xc7frames2bit failed", "logs": logs}), 500
        steps.append("xc7frames2bit")

        # Read and encode bitstream
        bit_file = tmp / f"{base}.bit"
        if not bit_file.exists():
            return jsonify({"error": "Bitstream not generated", "logs": logs}), 500

        bitstream = base64.b64encode(bit_file.read_bytes()).decode('utf-8')

        return jsonify({
            "bitstream": bitstream,
            "status": "success",
            "steps": steps,
            "size_bytes": bit_file.stat().st_size,
            "logs": "\n".join(logs)
        })


# Default XDC for QMTECH XC7A100T
DEFAULT_XDC = """
# QMTECH Artix-7 XC7A100T-1FGG676C
set_property PACKAGE_PIN U22 [get_ports clk]
set_property PACKAGE_PIN T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports led]
""".strip()


@app.route("/health", methods=["GET"])
def health():
    """Detailed health check."""
    return jsonify({
        "status": "healthy",
        "chipdb_exists": CHIPDB.exists(),
        "work_dir": str(WORK_DIR),
        "output_dir": str(OUTPUT_DIR)
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
