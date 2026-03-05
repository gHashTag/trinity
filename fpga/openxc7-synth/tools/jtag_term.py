#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY FPGA — JTAG UART Terminal
# ═══════════════════════════════════════════════════════════════════════════════
#
# Interactive terminal for TRINITY FPGA via JTAG UART
#
# Usage: ./tools/jtag_term.py [--hex|--raw]
# ═══════════════════════════════════════════════════════════════════════════════

import sys
import os
import time
import threading
import subprocess
import argparse
from pathlib import Path
from select import select
from termios import tcflush, TCIFLUSH
import tty
import pty

#===============================================================================
# CONFIGURATION
#===============================================================================

PIPE_DIR = "/tmp/trinity_jtag"
PIPE_TX = f"{PIPE_DIR}/tx"
PIPE_RX = f"{PIPE_DIR}/rx"

# Colors
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    PURPLE = '\033[0;35m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'

#===============================================================================
# TRINITY COMMANDS
#===============================================================================

TRINITY_CMDS = {
    'PING': b'\xAA\xFF\x00',           # Ping command
    'MODE': b'\xAA\x01\x00',           # Set LED mode
    'BIND': b'\xAA\x02\x08',           # VSA bind
    'BUNDLE': b'\xAA\x03\x08',         # VSA bundle
    'SIMILARITY': b'\xAA\x04\x08',     # VSA similarity
    'BITNET': b'\xAA\x05\x01',         # BitNet inference
    'TQNN': b'\xAA\x06\x06',           # TQNN inference
}

#===============================================================================
# JTAG UART CLASS
#===============================================================================

class JTAGUART:
    def __init__(self, hex_mode=False, raw_mode=False):
        self.hex_mode = hex_mode
        self.raw_mode = raw_mode
        self.running = False
        self.tx_pipe = None
        self.rx_pipe = None
        self.openocd_proc = None

    def start(self):
        """Initialize pipes and OpenOCD"""
        print(f"{Colors.BLUE}{'='*60}{Colors.NC}")
        print(f"{Colors.BLUE}  TRINITY JTAG UART Terminal{Colors.NC}")
        print(f"{Colors.BLUE}{'='*60}{Colors.NC}")
        print()

        # Create pipe directory
        os.makedirs(PIPE_DIR, exist_ok=True)

        # Create named pipes
        if not os.path.exists(PIPE_TX):
            os.mkfifo(PIPE_TX)
        if not os.path.exists(PIPE_RX):
            os.mkfifo(PIPE_RX)

        print(f"{Colors.GREEN}✓ Pipes created{Colors.NC}")
        print(f"  TX: {PIPE_TX}")
        print(f"  RX: {PIPE_RX}")
        print()

        # Check for OpenOCD
        if not self._check_openocd():
            print(f"{Colors.RED}✗ OpenOCD not found!{Colors.NC}")
            print("  Install: brew install openocd")
            return False

        # Start OpenOCD
        return self._start_openocd()

    def _check_openocd(self):
        """Check if OpenOCD is installed"""
        try:
            result = subprocess.run(['openocd', '--version'],
                                    capture_output=True, text=True)
            if result.returncode == 0:
                version = result.stdout.split('\n')[0]
                print(f"{Colors.GREEN}✓ OpenOCD: {version}{Colors.NC}")
                return True
        except FileNotFoundError:
            return False
        return False

    def _start_openocd(self):
        """Start OpenOCD in background"""
        print()
        print(f"{Colors.CYAN}Starting OpenOCD...{Colors.NC}")

        # OpenOCD configuration
        config_path = "openocd/qmtech_jtag.cfg"
        if not os.path.exists(config_path):
            # Try relative path
            script_dir = Path(__file__).parent.parent
            config_path = script_dir / config_path

        if not os.path.exists(config_path):
            print(f"{Colors.YELLOW}⚠ Config not found, using defaults{Colors.NC}")
            config_path = None

        # Start OpenOCD
        cmd = ['openocd']
        if config_path:
            cmd.extend(['-f', str(config_path)])

        try:
            self.openocd_proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )

            time.sleep(2)

            if self.openocd_proc.poll() is None:
                print(f"{Colors.GREEN}✓ OpenOCD running (PID: {self.openocd_proc.pid}){Colors.NC}")
                self.running = True
                return True
            else:
                print(f"{Colors.RED}✗ OpenOCD failed to start!{Colors.NC}")
                return False

        except Exception as e:
            print(f"{Colors.RED}✗ Error starting OpenOCD: {e}{Colors.NC}")
            return False

    def send(self, data):
        """Send data to FPGA"""
        if not self.running:
            return False

        try:
            with open(PIPE_TX, 'w') as f:
                f.write(data)
                f.flush()
            return True
        except Exception as e:
            print(f"{Colors.RED}✗ TX error: {e}{Colors.NC}")
            return False

    def send_bytes(self, data):
        """Send raw bytes to FPGA"""
        if self.hex_mode:
            hex_str = data.hex().upper()
            return self.send(hex_str)
        else:
            try:
                text = data.decode('ascii', errors='replace')
                return self.send(text)
            except:
                return self.send(data.hex())

    def send_command(self, cmd_name, *args):
        """Send a TRINITY command"""
        if cmd_name not in TRINITY_CMDS:
            print(f"{Colors.RED}Unknown command: {cmd_name}{Colors.NC}")
            return False

        cmd_bytes = TRINITY_CMDS[cmd_name]

        # Add arguments
        for arg in args:
            if isinstance(arg, int):
                cmd_bytes += bytes([arg & 0xFF])
            elif isinstance(arg, str):
                cmd_bytes += arg.encode('ascii')

        return self.send_bytes(cmd_bytes)

    def receive(self, timeout=1.0):
        """Receive data from FPGA"""
        if not self.running:
            return None

        try:
            # Check if pipe has data
            if os.path.exists(PIPE_RX):
                # Non-blocking read using select
                fd = os.open(PIPE_RX, os.O_RDONLY | os.O_NONBLOCK)
                try:
                    ready, _, _ = select([fd], [], [], timeout)
                    if ready:
                        data = os.read(fd, 4096)
                        os.close(fd)
                        return data if data else None
                finally:
                    os.close(fd)
        except Exception as e:
            pass

        return None

    def stop(self):
        """Stop JTAG UART"""
        self.running = False

        if self.openocd_proc:
            self.openocd_proc.terminate()
            self.openocd_proc.wait()

        # Clean up pipes
        for pipe in [PIPE_TX, PIPE_RX]:
            try:
                os.remove(pipe)
            except:
                pass

        try:
            os.rmdir(PIPE_DIR)
        except:
            pass

#===============================================================================
# TERMINAL CLASS
#===============================================================================

class Terminal:
    def __init__(self, jtag, hex_mode=False, raw_mode=False):
        self.jtag = jtag
        self.hex_mode = hex_mode
        self.raw_mode = raw_mode
        self.running = False
        self.rx_thread = None

    def start(self):
        """Start terminal"""
        self.running = True

        # Start RX thread
        self.rx_thread = threading.Thread(target=self._rx_loop, daemon=True)
        self.rx_thread.start()

        # Print welcome
        self._print_welcome()

        # Main loop
        self._main_loop()

    def _print_welcome(self):
        print()
        print(f"{Colors.PURPLE}{'='*60}{Colors.NC}")
        print(f"{Colors.PURPLE}  TRINITY FPGA Terminal Ready{Colors.NC}")
        print(f"{Colors.PURPLE}{'='*60}{Colors.NC}")
        print()
        print(f"{Colors.CYAN}Commands:{Colors.NC}")
        print(f"  PING              - Ping FPGA")
        print(f"  MODE <0-7>        - Set LED mode")
        print(f"  BIND <vec> <vec>  - VSA bind (hex)")
        print(f"  SIMILARITY <vec>  - VSA similarity")
        print(f"  TQNN <data>       - TQNN inference")
        print(f"  hex on/off        - Toggle hex mode")
        print(f"  quit/exit         - Exit terminal")
        print()
        print(f"{Colors.YELLOW}Type command and press Enter{Colors.NC}")
        print()

    def _rx_loop(self):
        """RX loop (runs in thread)"""
        while self.running:
            data = self.jtag.receive(timeout=0.5)
            if data:
                self._display_rx(data)

    def _display_rx(self, data):
        """Display received data"""
        if self.hex_mode:
            print(f"{Colors.GREEN}RX: {data.hex().upper()}{Colors.NC}")
        elif self.raw_mode:
            print(f"{Colors.GREEN}RX: {repr(data)}{Colors.NC}")
        else:
            try:
                text = data.decode('ascii', errors='replace').rstrip('\n\r')
                print(f"{Colors.GREEN}RX: {text}{Colors.NC}")
            except:
                print(f"{Colors.GREEN}RX: {data.hex()}{Colors.NC}")

    def _main_loop(self):
        """Main input loop"""
        try:
            while self.running:
                try:
                    # Get input
                    cmd = input(f"{Colors.CYAN}TRINITY>{Colors.NC} ").strip()

                    if not cmd:
                        continue

                    # Process command
                    if cmd.lower() in ['quit', 'exit']:
                        break
                    elif cmd.lower() == 'hex on':
                        self.hex_mode = True
                        print(f"{Colors.YELLOW}Hex mode: ON{Colors.NC}")
                    elif cmd.lower() == 'hex off':
                        self.hex_mode = False
                        print(f"{Colors.YELLOW}Hex mode: OFF{Colors.NC}")
                    else:
                        # Send to FPGA
                        self._send_command(cmd)

                except EOFError:
                    break
                except KeyboardInterrupt:
                    continue

        finally:
            self.running = False

    def _send_command(self, cmd):
        """Parse and send command"""
        parts = cmd.split()
        cmd_name = parts[0].upper()
        args = parts[1:]

        if cmd_name == 'PING':
            self.jtag.send_command('PING')
            print(f"{Colors.YELLOW}TX: PING{Colors.NC}")

        elif cmd_name == 'MODE':
            if args:
                mode = int(args[0])
                self.jtag.send_command('MODE', mode)
                print(f"{Colors.YELLOW}TX: MODE {mode}{Colors.NC}")
            else:
                print(f"{Colors.RED}Usage: MODE <0-7>{Colors.NC}")

        elif cmd_name == 'BIND':
            print(f"{Colors.YELLOW}TX: BIND {args}{Colors.NC}")
            # Parse hex vectors
            for arg in args:
                try:
                    data = bytes.fromhex(arg)
                    self.jtag.send_bytes(data)
                except ValueError:
                    print(f"{Colors.RED}Invalid hex: {arg}{Colors.NC}")

        elif cmd_name == 'SIMILARITY':
            print(f"{Colors.YELLOW}TX: SIMILARITY{Colors.NC}")
            self.jtag.send_command('SIMILARITY')

        elif cmd_name == 'TQNN':
            print(f"{Colors.YELLOW}TX: TQNN{Colors.NC}")
            self.jtag.send_command('TQNN')

        else:
            # Send as raw text
            if self.jtag.send(cmd + '\n'):
                print(f"{Colors.YELLOW}TX: {cmd}{Colors.NC}")

#===============================================================================
# MAIN
#===============================================================================

def main():
    parser = argparse.ArgumentParser(description='TRINITY JTAG UART Terminal')
    parser.add_argument('--hex', action='store_true', help='Display data in hex')
    parser.add_argument('--raw', action='store_true', help='Raw data mode')
    args = parser.parse_args()

    # Create JTAG UART
    jtag = JTAGUART(hex_mode=args.hex, raw_mode=args.raw)

    # Start
    if not jtag.start():
        print(f"{Colors.RED}Failed to start JTAG UART{Colors.NC}")
        return 1

    # Create and start terminal
    terminal = Terminal(jtag, hex_mode=args.hex, raw_mode=args.raw)
    try:
        terminal.start()
    finally:
        jtag.stop()

    return 0

if __name__ == '__main__':
    sys.exit(main())
