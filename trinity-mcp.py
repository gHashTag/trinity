#!/usr/bin/env python3
"""Trinity MCP Server using FastMCP"""
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("Trinity")

@mcp.tool()
def echo(text: str) -> str:
    """Echo back the input text"""
    return f"Echo: {text}"

@mcp.tool()
def trinity_info() -> str:
    """Get information about Trinity"""
    return """Trinity is a ternary computing framework.

Key features:
- Ternary logic: {-1, 0, +1}
- VSA: Vector Symbolic Architecture
- 1.58 bits/trit information density
- Memory savings: 20x vs float32
"""

if __name__ == "__main__":
    mcp.run()
