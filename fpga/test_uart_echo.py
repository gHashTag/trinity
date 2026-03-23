#!/usr/bin/env python3
"""
UART Echo Test — Simple test for FPGA UART bridge
Sends bytes and expects them echoed back
"""

import serial
import serial.tools.list_ports
import time
import sys

def find_ft232_port():
    """Find FT232RL USB-Serial device"""
    ports = serial.tools.list_ports.comports()
    for port in ports:
        if 'FT232' in (port.product or '') or 'USB Serial' in (port.product or ''):
            print(f"[+] Found FT232RL: {port.device}")
            print(f"    Product: {port.product}")
            print(f"    Manufacturer: {port.manufacturer}")
            return port.device
    print("[!] FT232RL not found!")
    print("\nAvailable ports:")
    for p in ports:
        print(f"  {p.device} - {p.product}")
    return None

def test_echo(port, baud=115200, test_data=b'A'):
    """Test UART echo"""
    try:
        ser = serial.Serial(
            port=port,
            baudrate=baud,
            timeout=1.0,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE
        )
        print(f"\n[+] Connected to {port} @ {baud} baud")

        # Flush buffers
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        time.sleep(0.1)

        # Send test byte
        print(f"[→] Sending: {test_data!r} (0x{test_data.hex()})")
        ser.write(test_data)

        # Wait for response
        start = time.time()
        while time.time() - start < 2.0:
            if ser.in_waiting > 0:
                received = ser.read(ser.in_waiting)
                print(f"[←] Received: {received!r} (0x{received.hex()})")

                # Check echo
                if received == test_data:
                    print("[✓] ECHO SUCCESS!")
                else:
                    print(f"[✗] ECHO FAIL! Expected {test_data!r}, got {received!r}")
                return True
            time.sleep(0.01)

        print("[✗] TIMEOUT - No response from FPGA")
        return False

    except Exception as e:
        print(f"[✗] Error: {e}")
        return False
    finally:
        ser.close()
        print(f"\n[-] Closed port")

def test_sequence(port):
    """Test sequence of bytes"""
    test_bytes = [
        b'A',      # 0x41
        b'\x55',    # Alternating pattern (01010101)
        b'\xAA',    # Alternating pattern (10101010)
        b'Hello',   # String
        b'\x00',    # Zero byte
        b'\xFF',    # All ones
    ]

    results = []
    for data in test_bytes:
        result = test_echo(port, test_data=data)
        results.append((data, result))
        time.sleep(0.2)

    print("\n" + "="*50)
    print("SUMMARY:")
    print("="*50)
    for data, result in results:
        status = "✓" if result else "✗"
        print(f"{status} {data!r:12} -> {'PASS' if result else 'FAIL'}")

    passed = sum(1 for _, r in results if r)
    print(f"\nPassed: {passed}/{len(results)}")

def main():
    port = find_ft232_port()
    if not port:
        return 1

    print("\n" + "="*50)
    print("UART ECHO TEST")
    print("="*50)

    test_sequence(port)

if __name__ == '__main__':
    sys.exit(main())
