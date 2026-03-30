#!/usr/bin/env python3
"""Simple FPGA synthesis API for Fly.io"""
import base64
import io
import json
import os
import subprocess
import tempfile
from http.server import HTTPServer, BaseHTTPRequestHandler

# Default XDC for J2 header (D26=TX, E26=RX)
DEFAULT_XDC = """# J2 Header UART - FT232RL (Bank 15, VCCO=3.3V)
set_property -dict {PACKAGE_PIN D26 IOSTANDARD LVCMOS33} [get_ports uart_tx]
set_property -dict {PACKAGE_PIN E26 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports uart_rx]
"""

# Job storage
JOBS = {}

class SynthHandler(BaseHTTPRequestHandler):
    """Handle synthesis requests"""

    def _send_json(self, code, data):
        """Send JSON response"""
        body = json.dumps(data).encode() if isinstance(data, dict) else data
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Connection', 'close')
        self.end_headers()
        self.wfile.write(body)

    def _send_bytes(self, code, body, ct='application/octet-stream'):
        """Send bytes response"""
        self.send_response(code)
        self.send_header('Content-Type', ct)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Connection', 'close')
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)

        try:
            data = json.loads(post_data.decode())
            verilog = data.get('verilog', '')
            xdc = data.get('xdc', DEFAULT_XDC)
            top = data.get('top', 'uart_bridge_top')

            if not verilog:
                self._send_json(400, {'error': 'Missing verilog parameter'})
                return

            # Generate job_id
            import uuid
            job_id = uuid.uuid4().hex[:8]

            JOBS[job_id] = {
                'status': 'queued',
                'verilog': verilog,
                'xdc': xdc,
                'top': top
            }

            print(f"Job {job_id} queued")
            self._send_json(202, {'job_id': job_id, 'status': 'queued'})

        except Exception as e:
            print(f"Error: {e}")
            self._send_json(500, {'error': str(e)})

    def do_GET(self):
        path = self.path

        if path == '/health':
            self._send_json(200, {'status': 'ok', 'jobs': len(JOBS)})
        elif path.startswith('/job_status/'):
            job_id = path.split('/')[-1]
            if job_id in JOBS:
                self._send_json(200, JOBS[job_id])
            else:
                self._send_json(404, {'error': 'Job not found'})
        elif path.startswith('/download/'):
            job_id = path.split('/')[-1]
            if job_id in JOBS and JOBS[job_id]['status'] == 'done':
                # For demo, return fake bitstream
                fake_bitstream = bytes.fromhex('AA9955' * 1024)
                self._send_bytes(200, fake_bitstream)
                JOBS[job_id]['status'] = 'downloaded'
                print(f"Job {job_id} downloaded")
            else:
                status = JOBS.get(job_id, {}).get('status', 'unknown')
                self._send_json(202, {'error': 'Bitstream not ready', 'status': status})
        else:
            self._send_json(404, {'error': 'Not found'})

    def log_message(self, format, *args):
        """Suppress default logging"""
        print(f"{self.address_string()} - {format % args}")

def main():
    server = HTTPServer(('', 8080), SynthHandler)
    print("FPGA synthesis server running on port 8080")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped")

if __name__ == '__main__':
    main()
