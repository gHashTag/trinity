#!/usr/bin/env python3
"""Minimal MCP server with proper Content-Length framing"""
import sys
import json
import traceback

LOG_FILE = "/tmp/trinity-mcp-debug.log"

def log(msg):
    with open(LOG_FILE, "a") as f:
        f.write(msg + "\n")

def read_message():
    """Read an MCP message with Content-Length framing"""
    try:
        # Read headers
        content_length = None
        while True:
            line = sys.stdin.readline()
            if not line:
                log("EOF while reading headers")
                return None  # EOF
            line = line.strip()
            if not line:
                break  # Empty line = end of headers
            if line.lower().startswith("content-length:"):
                content_length = int(line.split(":")[1].strip())
                log(f"Got Content-Length: {content_length}")

        if content_length is None:
            log("No Content-Length header, trying raw JSON")
            # Try to read raw JSON (fallback for testing)
            data = sys.stdin.read(1)
            if not data:
                return None
            brace_count = 0
            in_string = False
            while True:
                char = data[-1] if data else ''
                if char == '"' and (len(data) == 1 or data[-2] != '\\'):
                    in_string = not in_string
                elif not in_string:
                    if char == '{':
                        brace_count += 1
                    elif char == '}':
                        brace_count -= 1
                        if brace_count == 0:
                            log(f"Read raw JSON: {data[:50]}...")
                            return data
                char = sys.stdin.read(1)
                if not char:
                    return data
                data += char

        # Read exact content length
        body = sys.stdin.read(content_length)
        log(f"Read message: {body[:100]}...")
        return body
    except Exception as e:
        log(f"Error reading message: {e}")
        traceback.print_exc(file=open(LOG_FILE, "a"))
        return None

def main():
    log("=== Trinity MCP Server Started ===")
    try:
        while True:
            body = read_message()
            if body is None:
                log("read_message returned None, exiting")
                break

            try:
                msg = json.loads(body)
                msg_id = msg.get("id")
                method = msg.get("method", "")

                log(f"Method: {method}, ID: {msg_id}")

                # Skip notifications (no id field)
                if msg_id is None:
                    log("Notification, skipping response")
                    continue

                # Handle methods
                if method == "initialize":
                    result = {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "trinity", "version": "1.0"}
                    }
                elif method == "tools/list":
                    result = {
                        "tools": [{
                            "name": "echo",
                            "description": "Echo tool",
                            "inputSchema": {"type": "object", "properties": {"text": {"type": "string"}}}
                        }]
                    }
                else:
                    result = {}

                response = {"jsonrpc": "2.0", "id": msg_id, "result": result}
                resp_str = json.dumps(response, separators=(',', ':'))
                sys.stdout.write(f"Content-Length: {len(resp_str)}\r\n\r\n{resp_str}")
                sys.stdout.flush()
                log(f"Sent response: {resp_str[:100]}...")

            except json.JSONDecodeError as e:
                log(f"JSON decode error: {e}")
            except Exception as e:
                log(f"Error handling message: {e}")
                traceback.print_exc(file=open(LOG_FILE, "a"))
    except Exception as e:
        log(f"Fatal error: {e}")
        traceback.print_exc(file=open(LOG_FILE, "a"))
    log("=== Server Exiting ===")

if __name__ == "__main__":
    main()
