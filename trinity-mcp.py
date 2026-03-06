#!/usr/bin/env python3
"""Trinity MCP Server using FastMCP"""
from mcp.server.fastmcp import FastMCP
import subprocess
import os

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
- Golden Ratio: φ = 1.6180339...
- Trinity Identity: φ² + 1/φ² = 3
"""

@mcp.tool()
def phi_power(n: int) -> str:
    """Compute φ^n (phi to the power of n) where φ = 1.618... (Golden Ratio)"""
    from math import sqrt
    phi = (1 + sqrt(5)) / 2
    result = phi ** n
    return f"φ^{n} = {result:.10f}"

@mcp.tool()
def fibonacci(n: int) -> str:
    """Compute the n-th Fibonacci number using φ (Binet's formula)"""
    from math import sqrt
    if n < 0:
        return "n must be >= 0"
    phi = (1 + sqrt(5)) / 2
    psi = (1 - sqrt(5)) / 2
    fib = (phi**n - psi**n) / sqrt(5)
    return f"Fibonacci({n}) = {int(round(fib))}"

@mcp.tool()
def lucas(n: int) -> str:
    """Compute the n-th Lucas number L(n) = φ^n + (-φ)^{-n}"""
    from math import sqrt
    if n < 0:
        return "n must be >= 0"
    phi = (1 + sqrt(5)) / 2
    result = phi**n + (-phi)**(-n)
    return f"Lucas({n}) = {int(round(result))}"

@mcp.tool()
def trinity_commands() -> str:
    """List available TRI (Trinity CLI) commands"""
    cmd = ["/Users/playra/trinity-w1/zig-out/bin/tri", "help"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10, cwd="/Users/playra/trinity-w1")
        return result.stdout if result.stdout else result.stderr[:500]
    except Exception as e:
        return f"Error: {e}"

@mcp.tool()
def run_vibee(spec_file: str) -> str:
    """Compile a .vibee specification to Zig code

    Args:
        spec_file: Path to .vibee file (e.g., specs/tri/feature.vibee)
    """
    cmd = ["/Users/playra/trinity-w1/zig-out/bin/tri", "gen", spec_file]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30, cwd="/Users/playra/trinity-w1")
        return result.stdout if result.stdout else result.stderr
    except Exception as e:
        return f"Error: {e}"

@mcp.tool()
def sacred_constants() -> str:
    """Display sacred mathematical constants"""
    return """
φ (phi)        = 1.618033988749...  (Golden Ratio)
φ²             = 2.618033988749...
1/φ            = 0.618033988749...
π (pi)         = 3.141592653589...
e (epsilon)    = 2.718281828459...
√2             = 1.414213562373...
√3             = 1.732050807568...
√5             = 2.236067977499...

Trinity Constants:
μ = φ^(-4)     = 0.0382...  (micro)
χ = 0.0618...              (chi)
σ = φ                       (sigma)
ε = 1/3                    (epsilon)

Trinity Identity: φ² + 1/φ² = 3 ✓
"""

@mcp.tool()
def trinity_status() -> str:
    """Get current Trinity project status"""
    try:
        result = subprocess.run(
            ["git", "status", "--short"],
            capture_output=True, text=True, timeout=5,
            cwd="/Users/playra/trinity-w1"
        )
        if result.returncode == 0:
            if result.stdout:
                return f"Modified files:\n{result.stdout}"
            return "Working directory clean ✓"
        return "Not a git repository or git error"
    except Exception as e:
        return f"Error: {e}"

if __name__ == "__main__":
    mcp.run()
