#!/usr/bin/env python3
"""
uart-bitstream.py — UART bitstream delivery service

Receives bitstream from cloud and prepares for FPGA flashing via JTAG.
This is the LOCAL component that runs on your Mac.

Usage:
    # Start server
    ./uart-bitstream.py start

    # Receive bitstream (called by cloud-synth.sh)
    ./uart-bitstream.py receive <base64_data>

    # Flash to FPGA
    ./uart-bitstream.py flash <bitstream.bit>
"""

import base64
import json
import os
import subprocess
import sys
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
import socket

BITSTREAM_DIR = Path("/tmp/fpga_uart_bitstreams")
BITSTREAM_DIR.mkdir(exist_ok=True)

JTAG_PROGRAM = Path(__file__).parent / "jtag_program"


class UARTHandler(BaseHTTPRequestHandler):
    """Handle bitstream delivery via UART tunnel."""

    def log_message(self, format, *args):
        """Quiet logging."""
        pass

    def do_POST(self):
        """Receive bitstream payload."""
        if self.path == "/deliver":
            content_length = int(self.headers.get('Content-Length', 0))
            data = self.rfile.read(content_length)

            try:
                payload = json.loads(data.decode('utf-8'))
                name = payload.get('name', 'design')
                b64_data = payload.get('bitstream', '')

                # Decode and save
                bit_data = base64.b64decode(b64_data)
                output_file = BITSTREAM_DIR / f"{name}.bit"
                output_file.write_bytes(bit_data)

                print(f"[UART] Received {name}.bit ({len(bit_data)} bytes)")

                # Auto-flash if requested
                if payload.get('auto_flash', False):
                    self.flash_bitstream(output_file)

                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({
                    "status": "ok",
                    "path": str(output_file)
                }).encode())

            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(json.dumps({"error": str(e)}).encode())

    def do_GET(self):
        """Health check."""
        if self.path == "/status":
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                "status": "ready",
                "bitstream_dir": str(BITSTREAM_DIR),
                "jtag_program": str(JTAG_PROGRAM),
                "bitstreams": [f.name for f in BITSTREAM_DIR.glob("*.bit")]
            }).encode())

    @staticmethod
    def flash_bitstream(bitstream_file: Path):
        """Flash bitstream to FPGA."""
        print(f"[UART] Flashing {bitstream_file.name}...")

        # Load firmware (if needed)
        # sudo fxload -v -t fx2 -d 03fd:0013 -i xusb_xp2.hex

        # Flash
        result = subprocess.run(
            ["sudo", str(JTAG_PROGRAM), str(bitstream_file)],
            capture_output=True,
            text=True
        )

        if result.returncode == 0:
            print(f"[UART] ✓ Flash complete: {bitstream_file.name}")
        else:
            print(f"[UART] ✗ Flash failed: {result.stderr}")


def find_free_port():
    """Find a free port for the server."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(('', 0))
        s.listen(1)
        port = s.getsockname()[1]
    return port


def start_server():
    """Start UART delivery server."""
    port = 7777  # Fixed port for consistency

    server = HTTPServer(('127.0.0.1', port), UARTHandler)
    print(f"[UART] Bitstream delivery server on http://127.0.0.1:{port}")
    print(f"[UART] Bitstreams saved to: {BITSTREAM_DIR}")
    print("[UART] Press Ctrl+C to stop")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[UART] Server stopped")
        server.shutdown()


def receive_bitstream(b64_data: str, name: str = "design"):
    """Receive and save bitstream directly."""
    bit_data = base64.b64decode(b64_data)
    output_file = BITSTREAM_DIR / f"{name}.bit"
    output_file.write_bytes(bit_data)
    print(f"[UART] Saved: {output_file} ({len(bit_data)} bytes)")
    return str(output_file)


def flash_bitstream(bitstream_file: str):
    """Flash bitstream to FPGA."""
    bit_file = Path(bitstream_file)
    if not bit_file.exists():
        # Try in BITSTREAM_DIR
        bit_file = BITSTREAM_DIR / bitstream_file

    if not bit_file.exists():
        print(f"[UART] Error: Bitstream not found: {bitstream_file}")
        sys.exit(1)

    UARTHandler.flash_bitstream(bit_file)


def main():
    """CLI entry point."""
    if len(sys.argv) < 2:
        print("Usage: uart-bitstream.py <start|receive|flash|list> [args]")
        sys.exit(1)

    command = sys.argv[1]

    if command == "start":
        start_server()

    elif command == "receive":
        if len(sys.argv) < 3:
            print("Usage: uart-bitstream.py receive <base64_data> [name]")
            sys.exit(1)
        b64_data = sys.argv[2]
        name = sys.argv[3] if len(sys.argv) > 3 else "design"
        receive_bitstream(b64_data, name)

    elif command == "flash":
        if len(sys.argv) < 3:
            # Flash latest
            bitstreams = list(BITSTREAM_DIR.glob("*.bit"))
            if not bitstreams:
                print("[UART] No bitstreams found")
                sys.exit(1)
            bit_file = max(bitstreams, key=lambda p: p.stat().st_mtime)
            print(f"[UART] Flashing latest: {bit_file.name}")
        else:
            bit_file = sys.argv[2]
        flash_bitstream(bit_file)

    elif command == "list":
        print("[UART] Available bitstreams:")
        for bf in sorted(BITSTREAM_DIR.glob("*.bit")):
            mtime = time.ctime(bf.stat().st_mtime)
            print(f"  {bf.name:30} {mtime}")

    else:
        print(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()
