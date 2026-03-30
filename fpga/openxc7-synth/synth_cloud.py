import base64
import io
import os
import subprocess
import tempfile
import traceback
import uuid
import threading
import time
from flask import Flask, request, jsonify, send_file
from pathlib import Path

app = Flask(__name__)

WORK_DIR = Path("/app")
OUTPUT_DIR = WORK_DIR / "output"
OUTPUT_DIR.mkdir(exist_ok=True)

# Default XDC for J2 header (D26=TX, E26=RX)
DEFAULT_XDC = """# J2 Header UART - FT232RL (Bank 15, VCCO=3.3V)
set_property -dict {PACKAGE_PIN D26 IOSTANDARD LVCMOS33} [get_ports uart_tx]
set_property -dict {PACKAGE_PIN E26 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports uart_rx]
"""

# Job storage: {job_id: {"bitstream": base64, "status": "done", "size": N}
JOBS = {}
JOBS_LOCK = threading.Lock()

def generate_job_id():
    """Generate 8-character hex job ID."""
    return uuid.uuid4().hex[:8]

# Synthesize endpoint
@app.route("/synthesize", methods=["POST"])
def synthesize():
    # Parse JSON request
    data = request.get_json()
    if not data:
        return jsonify({"error": "Invalid JSON"}), 400

    verilog = data.get("verilog")
    xdc = data.get("xdc", "")
    top = data.get("top", "uart_bridge_top")

    if not verilog:
        return jsonify({"error": "Missing verilog parameter"}), 400

    # Use provided XDC or default
    if not xdc:
        xdc = DEFAULT_XDC

    # Generate job_id
    job_id = generate_job_id()

    # Create job entry
    with JOBS_LOCK:
        JOBS[job_id] = {
            "status": "queued",
            "verilog": verilog,
            "xdc": xdc,
            "top": top,
            "bitstream": None,
            "size_bytes": 0,
            "error": None
        }

    # Start background synthesis
    thread = threading.Thread(target=run_synthesis, args=(job_id, verilog, xdc, top))
    thread.daemon = True
    thread.start()

    return jsonify({"job_id": job_id, "status": "queued"}), 202

# Background synthesis runner
def run_synthesis(job_id: str, verilog: str, xdc: str, top: str):
    """Run yosys + nextpnr-xilinx synthesis in background."""
    try:
        with JOBS_LOCK:
            if job_id in JOBS:
                JOBS[job_id]["status"] = "running"
                JOBS[job_id]["start_time"] = time.time()

        # Create temp directory for this job
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir = Path(tmpdir)

            # Write input files
            rtl_file = tmpdir / "design.v"
            xdc_file = tmpdir / "design.xdc"
            json_file = tmpdir / "design.json"
            bit_file = tmpdir / "design.bit"

            rtl_file.write_text(verilog)
            xdc_file.write_text(xdc)

            # Step 1: Yosys synthesis
            yosys_cmd = [
                "yosys",
                "-p", f"synth_xilinx -top {top}; write_json {json_file}",
                str(rtl_file)
            ]

            result = subprocess.run(
                yosys_cmd,
                capture_output=True,
                text=True,
                timeout=60
            )

            if result.returncode != 0:
                raise Exception(f"Yosys failed: {result.stderr[:500]}")

            # Step 2: nextpnr-xilinx place & route
            pnr_cmd = [
                "nextpnr-xilinx",
                "--chipdb", "/app/chipdb/xc7a100tfgg676.bin",
                "--json", str(json_file),
                "--xdc", str(xdc_file),
                "--fasm", str(tmpdir / "design.fasm"),
                "--report", str(tmpdir / "report.txt")
            ]

            result = subprocess.run(
                pnr_cmd,
                capture_output=True,
                text=True,
                timeout=300
            )

            if result.returncode != 0:
                raise Exception(f"nextpnr failed: {result.stderr[:500]}")

            # Step 3: prjxray fasm2bit
            fasm2bit_cmd = [
                "fasm2frames",
                str(tmpdir / "design.fasm"),
                "--part", "xc7a100tfgg676"
            ]

            result = subprocess.run(
                fasm2bit_cmd,
                capture_output=True,
                text=True,
                timeout=60
            )

            if result.returncode != 0:
                raise Exception(f"fasm2frames failed: {result.stderr[:500]}")

            # Step 4: xc7patch
            frames_file = tmpdir / "design.frames"
            bit_raw_file = tmpdir / "design.raw.bit"

            result = subprocess.run(
                ["xc7patch", "--output_dir", str(tmpdir)],
                capture_output=True,
                text=True,
                timeout=60
            )

            if result.returncode != 0:
                raise Exception(f"xc7patch failed: {result.stderr[:500]}")

            # Read the bitstream
            if bit_raw_file.exists():
                bitstream_bytes = bit_raw_file.read_bytes()
                bitstream_b64 = base64.b64encode(bitstream_bytes).decode('utf-8')

                with JOBS_LOCK:
                    if job_id in JOBS:
                        JOBS[job_id]["status"] = "done"
                        JOBS[job_id]["bitstream"] = bitstream_b64
                        JOBS[job_id]["size_bytes"] = len(bitstream_bytes)
                        JOBS[job_id]["end_time"] = time.time()
            else:
                raise Exception("Bitstream file not generated")

    except Exception as e:
        with JOBS_LOCK:
            if job_id in JOBS:
                JOBS[job_id]["status"] = "failed"
                JOBS[job_id]["error"] = str(e)
                JOBS[job_id]["end_time"] = time.time()


# Job status endpoint
@app.route("/job_status/<job_id>", methods=["GET"])
def job_status(job_id):
    with JOBS_LOCK:
        if job_id not in JOBS:
            return jsonify({"error": "Job not found"}), 404

        job = JOBS[job_id]
        response = {
            "job_id": job_id,
            "status": job.get("status", "unknown")
        }

        if job.get("error"):
            response["error"] = job["error"]

        if job.get("size_bytes"):
            response["size_bytes"] = job["size_bytes"]

        return jsonify(response), 200


# Download endpoint
@app.route("/download/<job_id>", methods=["GET"])
def download_bitstream(job_id):
    with JOBS_LOCK:
        if job_id not in JOBS:
            return jsonify({"error": "Job not found"}), 404

        job = JOBS[job_id]

        if job["status"] != "done" or not job.get("bitstream"):
            return jsonify({
                "error": "Bitstream not ready",
                "status": job["status"]
            }), 202

        bitstream_b64 = job["bitstream"]
        bitstream_bytes = base64.b64decode(bitstream_b64)

    # Return as downloadable file
    return send_file(
        io.BytesIO(bitstream_bytes),
        mimetype="application/octet-stream",
        as_attachment=True,
        download_name="uart_bridge_j2.bit"
    )


# Health check
@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "jobs": len(JOBS)}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
