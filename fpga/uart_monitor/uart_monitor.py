#!/usr/bin/env python3
"""
Trinity UART Monitor - Professional Serial Port Analysis Tool
============================================================

Features:
- Real-time UART monitoring with timestamps
- HEX/ASCII display modes
- Data logging to file
- Protocol decoding (custom frames)
- Statistics (baud rate, packet count, errors)
- Cross-platform (Windows, Mac, Linux)
- Color-coded terminal output

Usage:
    python uart_monitor.py --list          # List available ports
    python uart_monitor.py /dev/ttyUSB0    # Linux
    python uart_monitor.py COM3            # Windows
    python uart_monitor.py /dev/cu.usbserial # macOS

Requirements:
    pip install pyserial pygments
"""

import serial
import serial.tools.list_ports
import argparse
import sys
import time
from datetime import datetime
from typing import Optional
from dataclasses import dataclass, field
from collections import deque
import struct
import re

try:
    from pygments import highlight
    from pygments.lexers import HexdumpLexer
    from pygments.formatters import Terminal256Formatter
    HAS_PYGMENTS = True
except ImportError:
    HAS_PYGMENTS = False

# ANSI Colors (fallback if pygments not available)
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

@dataclass
class UARTStats:
    """Статистика UART коммуникации"""
    packets_sent: int = 0
    packets_received: int = 0
    bytes_received: int = 0
    bytes_sent: int = 0
    errors: int = 0
    start_time: float = field(default_factory=time.time)
    last_packet_time: float = 0

    @property
    def uptime(self) -> float:
        return time.time() - self.start_time

    @property
    def packet_rate(self) -> float:
        """Packets per second"""
        if self.uptime > 0:
            return self.packets_received / self.uptime
        return 0

    @property
    def byte_rate(self) -> float:
        """Bytes per second"""
        if self.uptime > 0:
            return self.bytes_received / self.uptime
        return 0

class ProtocolDecoder:
    """Декодер пользовательских протоколов"""

    # Команды Trinity-FPGA
    COMMANDS = {
        0x03: "PING",
        0x10: "LED_ON",
        0x11: "LED_OFF",
        0x12: "LED_BLINK",
        0x20: "VSA_DOT",
    }

    RESPONSES = {
        0x83: "PONG",
        0xFF: "OK",
        0xAA: "ACK",
    }

    @classmethod
    def decode(cls, data: bytes) -> str:
        """Декодировать байт как команду/ответ"""
        if len(data) == 1:
            b = data[0]
            if b in cls.COMMANDS:
                return f"{Colors.OKCYAN}[CMD: {cls.COMMANDS[b]}]{Colors.ENDC}"
            elif b in cls.RESPONSES:
                return f"{Colors.OKGREEN}[RESP: {cls.RESPONSES[b]}]{Colors.ENDC}"
        return None

class HexdumpFormatter:
    """Форматирование данных в hexdump стиле"""

    @staticmethod
    def format(data: bytes, offset: int = 0) -> str:
        """Форматировать байты как hexdump"""
        lines = []
        for i in range(0, len(data), 16):
            chunk = data[i:i+16]
            hex_part = ' '.join(f'{b:02x}' for b in chunk)
            hex_part = hex_part.ljust(47)  # Pad for alignment
            ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
            lines.append(f'{offset+i:08x}  {hex_part}  |{ascii_part}|')
        return '\n'.join(lines)

class UARTMonitor:
    """Основной класс монитора UART"""

    def __init__(
        self,
        port: str,
        baudrate: int = 115200,
        timeout: float = 1.0,
        log_file: Optional[str] = None,
        show_hex: bool = True,
        show_ascii: bool = True,
        decode_protocol: bool = True,
        color: bool = True
    ):
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self.log_file = log_file
        self.show_hex = show_hex
        self.show_ascii = show_ascii
        self.decode_protocol = decode_protocol
        self.color = color and HAS_PYGMENTS

        self.stats = UARTStats()
        self.rx_buffer = deque(maxlen=4096)
        self.tx_buffer = deque(maxlen=4096)
        self.running = False

        # Файл лога
        self.log_handle = None
        if log_file:
            self.log_handle = open(log_file, 'a', encoding='utf-8')
            self._write_log_header()

    def _write_log_header(self):
        """Записать заголовок лог-файла"""
        if self.log_handle:
            self.log_handle.write(
                f"\n{'='*60}\n"
                f"UART Monitor Session Started\n"
                f"Port: {self.port}\n"
                f"Baudrate: {self.baudrate}\n"
                f"Time: {datetime.now().isoformat()}\n"
                f"{'='*60}\n"
            )
            self.log_handle.flush()

    def _write_log(self, direction: str, data: bytes):
        """Записать данные в лог-файл"""
        if self.log_handle:
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]
            self.log_handle.write(
                f"[{timestamp}] {direction} {len(data)} bytes: {data.hex(' ')}\n"
            )
            self.log_handle.flush()

    def connect(self) -> bool:
        """Подключиться к последовательному порту"""
        try:
            self.ser = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                timeout=self.timeout,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE
            )
            print(f"{Colors.OKGREEN}✓ Connected to {self.port} @ {self.baudrate} baud{Colors.ENDC}")
            return True
        except serial.SerialException as e:
            print(f"{Colors.FAIL}✗ Failed to connect: {e}{Colors.ENDC}")
            return False

    def disconnect(self):
        """Отключиться от порта"""
        if hasattr(self, 'ser') and self.ser.is_open:
            self.ser.close()
            print(f"\n{Colors.WARNING}Disconnected from {self.port}{Colors.ENDC}")
        if self.log_handle:
            self.log_handle.close()

    def print_header(self):
        """Вывести заголовок монитора"""
        print(f"""
╔════════════════════════════════════════════════════════════════════╗
║                    Trinity UART Monitor v1.0                       ║
║                    φ² + 1/φ² = 3 = TRINITY                         ║
╠════════════════════════════════════════════════════════════════════╣
║  Port:      {self.port:<50} ║
║  Baudrate:  {self.baudrate} bps{' '*43} ║
║  Timeout:   {self.timeout}s{' '*48} ║
║  Log:       {self.log_file if self.log_file else 'None':<50} ║
╠════════════════════════════════════════════════════════════════════╣
║  Commands:                                                        ║
║    Ctrl+C  - Exit                                                ║
║    s       - Show statistics                                     ║
║    h       - Toggle hex display                                  ║
║    a       - Toggle ASCII display                                ║
║    c       - Clear screen                                        ║
║    <data>  - Send data (hex: AA BB CC, or text)                  ║
╚════════════════════════════════════════════════════════════════════╝
""")

    def print_statistics(self):
        """Вывести статистику"""
        print(f"""
{Colors.BOLD}Statistics:{Colors.ENDC}
  Uptime:           {self.stats.uptime:.1f}s
  Packets RX:       {self.stats.packets_received}
  Bytes RX:         {self.stats.bytes_received}
  Packet Rate:      {self.stats.packet_rate:.1f} pps
  Byte Rate:        {self.stats.byte_rate:.1f} B/s
  Errors:           {self.stats.errors}
""")

    def format_packet(self, data: bytes, direction: str = "RX") -> str:
        """Форматировать пакет для вывода"""
        timestamp = datetime.now().strftime('%H:%M:%S.%f')[:-3]
        output = []

        # Заголовок пакета
        dir_color = Colors.OKGREEN if direction == "RX" else Colors.WARNING
        output.append(f"{dir_color}[{timestamp}] {direction} ({len(data)} bytes){Colors.ENDC}")

        # Декодирование протокола
        if self.decode_protocol:
            decoded = ProtocolDecoder.decode(data)
            if decoded:
                output.append(decoded)

        # HEX вывод
        if self.show_hex:
            hex_str = ' '.join(f'{b:02x}' for b in data)
            output.append(f"  HEX:   {hex_str}")

        # ASCII вывод
        if self.show_ascii:
            ascii_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in data)
            output.append(f"  ASCII: {ascii_str}")

        return '\n'.join(output)

    def send_data(self, data: bytes):
        """Отправить данные в порт"""
        try:
            self.ser.write(data)
            self.stats.packets_sent += 1
            self.stats.bytes_sent += len(data)
            self._write_log("TX", data)
            print(self.format_packet(data, "TX"))
        except serial.SerialException as e:
            print(f"{Colors.FAIL}TX Error: {e}{Colors.ENDC}")
            self.stats.errors += 1

    def parse_and_send(self, input_str: str):
        """Распарсить ввод пользователя и отправить"""
        # Проверка на hex формат (AA BB CC или AABBCC)
        hex_match = re.match(r'^([0-9A-Fa-f]{2}\s*)+$', input_str)
        if hex_match:
            hex_str = input_str.replace(' ', '')
            data = bytes.fromhex(hex_str)
        else:
            # Текстовый формат
            data = input_str.encode('utf-8')

        self.send_data(data)

    def run(self):
        """Главный цикл монитора"""
        import select
        import tty
        import termios
        import os

        self.running = True
        self.print_header()

        # Сохранить настройки терминала
        old_settings = None
        try:
            old_settings = termios.tcgetattr(sys.stdin)
        except:
            pass

        last_stats_update = time.time()

        try:
            while self.running:
                # Проверить входящие данные с таймаутом
                if self.ser.in_waiting > 0:
                    data = self.ser.read(self.ser.in_waiting)
                    if data:
                        self.stats.packets_received += 1
                        self.stats.bytes_received += len(data)
                        self.stats.last_packet_time = time.time()
                        self._write_log("RX", data)
                        print(self.format_packet(data))
                        self.rx_buffer.extend(data)

                # Обновить статистику каждую секунду
                if time.time() - last_stats_update > 1.0:
                    # Печатать uptime в заголовке (опционально)
                    last_stats_update = time.time()

                # Небольшая задержка
                time.sleep(0.01)

                # Проверить ввод пользователя (неблокирующий)
                if select.select([sys.stdin], [], [], 0)[0]:
                    cmd = sys.stdin.readline().strip()
                    if not cmd:
                        continue

                    if cmd == 's':
                        self.print_statistics()
                    elif cmd == 'h':
                        self.show_hex = not self.show_hex
                        print(f"{Colors.OKCYAN}Hex display: {self.show_hex}{Colors.ENDC}")
                    elif cmd == 'a':
                        self.show_ascii = not self.show_ascii
                        print(f"{Colors.OKCYAN}ASCII display: {self.show_ascii}{Colors.ENDC}")
                    elif cmd == 'c':
                        print('\033[2J\033[H', end='')
                        self.print_header()
                    elif cmd == 'q':
                        self.running = False
                    else:
                        self.parse_and_send(cmd)

        except KeyboardInterrupt:
            print(f"\n{Colors.WARNING}Exiting...{Colors.ENDC}")
        finally:
            if old_settings:
                termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)
            self.disconnect()
            self.print_statistics()

def list_ports():
    """Вывести список доступных портов"""
    print(f"\n{Colors.BOLD}Available Serial Ports:{Colors.ENDC}\n")
    ports = serial.tools.list_ports.comports()

    if not ports:
        print(f"{Colors.WARNING}No serial ports found{Colors.ENDC}")
        return

    for port in ports:
        print(f"  {Colors.OKCYAN}{port.device}{Colors.ENDC}")
        print(f"    Manufacturer: {port.manufacturer or 'N/A'}")
        print(f"    Product:      {port.product or 'N/A'}")
        print(f"    Serial:       {port.serial_number or 'N/A'}")
        print()

def main():
    parser = argparse.ArgumentParser(
        description='Trinity UART Monitor - Professional Serial Analysis Tool',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python uart_monitor.py --list
  python uart_monitor.py /dev/ttyUSB0
  python uart_monitor.py COM3 --baudrate 921600
  python uart_monitor.py /dev/cu.usbserial --log uart.log
        """
    )

    parser.add_argument('port', nargs='?', help='Serial port (use --list to find)')
    parser.add_argument('-b', '--baudrate', type=int, default=115200,
                       help='Baud rate (default: 115200)')
    parser.add_argument('-l', '--log', help='Log file path')
    parser.add_argument('--list', action='store_true', help='List available ports')
    parser.add_argument('--no-hex', action='store_true', help='Disable hex display')
    parser.add_argument('--no-ascii', action='store_true', help='Disable ASCII display')
    parser.add_argument('--no-decode', action='store_true', help='Disable protocol decoding')
    parser.add_argument('--no-color', action='store_true', help='Disable colored output')

    args = parser.parse_args()

    if args.list:
        list_ports()
        return

    if not args.port:
        parser.print_help()
        print(f"\n{Colors.WARNING}No port specified. Use --list to see available ports.{Colors.ENDC}")
        return

    monitor = UARTMonitor(
        port=args.port,
        baudrate=args.baudrate,
        log_file=args.log,
        show_hex=not args.no_hex,
        show_ascii=not args.no_ascii,
        decode_protocol=not args.no_decode,
        color=not args.no_color
    )

    if monitor.connect():
        try:
            monitor.run()
        except Exception as e:
            print(f"{Colors.FAIL}Error: {e}{Colors.ENDC}")
            monitor.disconnect()

if __name__ == '__main__':
    main()
