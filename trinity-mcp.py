#!/usr/bin/env python3
"""Trinity MCP Server using FastMCP

Supports both:
- stdio mode: Local development (mcp CLI)
- HTTP mode: Railway/cloud deployment (PORT env var)
"""
from mcp.server.fastmcp import FastMCP
import subprocess
import os
import sys
import glob

# Detect runtime environment
RAILWAY = os.environ.get("RAILWAY_ENVIRONMENT") == "production"
PORT = int(os.environ.get("PORT", "8899"))

# Project paths (adapt for Railway vs local)
if RAILWAY:
    PROJECT_DIR = "/app"
    TRI_BIN = "/usr/local/bin/tri"
    VIBEE_BIN = "/usr/local/bin/vibee"
else:
    PROJECT_DIR = "/Users/playra/trinity-w1"
    TRI_BIN = f"{PROJECT_DIR}/zig-out/bin/tri"
    VIBEE_BIN = f"{PROJECT_DIR}/zig-out/bin/vibee"

mcp = FastMCP("Trinity")

# HTTP health check endpoint (for Railway/cloud)
if RAILWAY or "--http" in sys.argv:
    from http.server import HTTPServer, BaseHTTPRequestHandler
    import threading
    import json
    from urllib.parse import urlparse, parse_qs

    class MCPServerHandler(BaseHTTPRequestHandler):
        """HTTP server that wraps MCP tools for Railway deployment"""

        def _set_headers(self, status=200, content_type="application/json"):
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()

        def do_GET(self):
            path = urlparse(self.path).path

            if path == "/health":
                self._set_headers()
                self.wfile.write(b'{"status": "healthy", "service": "trinity-mcp"}')

            elif path == "/" or path == "/tools":
                # List all available tools
                tools = []
                for name, func in mcp._mcp_tools.items():
                    tools.append({
                        "name": name,
                        "description": func.__doc__ or "No description"
                    })
                self._set_headers()
                self.wfile.write(json.dumps({"tools": tools}).encode())

            elif path.startswith("/tool/"):
                # Execute a tool: /tool/<tool_name>?arg1=val1&arg2=val2
                tool_name = path[6:]  # Remove "/tool/"
                query = parse_qs(urlparse(self.path).query)

                # Find the tool function
                tool_func = None
                for name, func in mcp._mcp_tools.items():
                    if name == tool_name:
                        tool_func = func
                        break

                if not tool_func:
                    self._set_headers(404)
                    self.wfile.write(b'{"error": "Tool not found"}')
                    return

                # Execute tool (simplified - assumes single string args)
                try:
                    result = tool_func(**{k: v[0] if v else "" for k, v in query.items()})
                    self._set_headers()
                    self.wfile.write(json.dumps({"result": result}).encode())
                except Exception as e:
                    self._set_headers(500)
                    self.wfile.write(json.dumps({"error": str(e)}).encode())

            else:
                self._set_headers(404)
                self.wfile.write(b'{"error": "Not found"}')

        def do_POST(self):
            path = urlparse(self.path).path
            if path == "/execute":
                content_length = int(self.headers.get("Content-Length", 0))
                post_data = self.rfile.read(content_length)
                try:
                    data = json.loads(post_data)
                    tool_name = data.get("tool")
                    args = data.get("args", {})

                    tool_func = None
                    for name, func in mcp._mcp_tools.items():
                        if name == tool_name:
                            tool_func = func
                            break

                    if not tool_func:
                        self._set_headers(404)
                        self.wfile.write(b'{"error": "Tool not found"}')
                        return

                    result = tool_func(**args)
                    self._set_headers()
                    self.wfile.write(json.dumps({"result": result}).encode())
                except Exception as e:
                    self._set_headers(500)
                    self.wfile.write(json.dumps({"error": str(e)}).encode())
            else:
                self._set_headers(404)
                self.wfile.write(b'{"error": "Not found"}')

        def log_message(self, format, *args):
            # Suppress default logging
            pass

    def run_http_server():
        """Run HTTP server in background thread"""
        server = HTTPServer(("0.0.0.0", PORT), MCPServerHandler)
        print(f"[Trinity MCP] HTTP server running on port {PORT}", file=sys.stderr)
        server.serve_forever()

    # Start HTTP server in background
    http_thread = threading.Thread(target=run_http_server, daemon=True)
    http_thread.start()

    # Keep main thread alive
    print(f"[Trinity MCP] Ready on port {PORT}", file=sys.stderr)
    try:
        while True:
            import time
            time.sleep(1)
    except KeyboardInterrupt:
        print("[Trinity MCP] Shutting down...", file=sys.stderr)

# ===== BASIC TOOLS =====

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

# ===== MATHEMATICS =====

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
    if n > 100:
        return "n must be <= 100 (to avoid overflow)"
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
    if n > 100:
        return "n must be <= 100"
    phi = (1 + sqrt(5)) / 2
    result = phi**n + (-phi)**(-n)
    return f"Lucas({n}) = {int(round(result))}"

@mcp.tool()
def sacred_constants() -> str:
    """Display sacred mathematical constants"""
    from math import sqrt, pi
    phi = (1 + sqrt(5)) / 2
    return f"""
φ (phi)        = {phi:.15f}  (Golden Ratio)
φ²             = {phi**2:.15f}
1/φ            = {1/phi:.15f}
π (pi)         = {pi:.15f}
e (epsilon)    = {2.718281828459045:.15f}
√2             = {sqrt(2):.15f}
√3             = {sqrt(3):.15f}
√5             = {sqrt(5):.15f}

Trinity Constants:
μ = φ^(-4)     = {phi**(-4):.4f}  (micro)
χ = 0.0618...              (chi)
σ = φ                       (sigma)
ε = 1/3                    (epsilon)

Trinity Identity: φ² + 1/φ² = 3 ✓
"""

# ===== TRI COMMANDS (static list to avoid timeout) =====

@mcp.tool()
def tri_commands() -> str:
    """List all available TRI (Trinity CLI) commands"""
    return """TRI Commands:

Core Commands:
  tri chat [--stream] <msg>     Interactive chat
  tri code [--stream] <prompt>  Generate code
  tri gen <spec.vibee>          Compile VIBEE spec
  tri pipeline run <task>       Execute Golden Chain

Verification:
  tri verify                    Run tests + benchmarks
  tri bench                     Run benchmarks
  tri verdict                   Generate toxic verdict

SWE Agent:
  tri fix <file>                Detect and fix bugs
  tri explain <file|prompt>     Explain code
  tri test <file>               Generate tests
  tri doc <file>                Generate documentation

Math:
  tri math                      Sacred math dispatcher
  tri constants                 Show φ, π, e, μ, χ, σ, ε
  tri phi <n>                   Compute φⁿ
  tri fib <n>                   Fibonacci number
  tri lucas <n>                 Lucas number

Chemistry:
  tri chem periodic             ASCII periodic table (118 elements)
  tri chem element <sym|num>    Element information
  tri chem mass <formula>       Molar mass
  tri chem formula <formula>    Analyze composition
  tri chem balance <eq>         Balance equation

Info:
  tri info                      System information
  tri version                   Show version
"""

# ===== VIBEE =====

@mcp.tool()
def list_vibee_specs() -> str:
    """List all available .vibee specification files"""
    specs = glob.glob(f"{PROJECT_DIR}/specs/**/*.vibee", recursive=True)
    specs += glob.glob(f"{PROJECT_DIR}/trinity-nexus/lang/specs/**/*.vibee", recursive=True)

    if not specs:
        return "No .vibee files found"

    result = "Available .vibee files:\n"
    for spec in sorted(set(specs)):
        rel_path = spec.replace(PROJECT_DIR + "/", "")
        result += f"  - {rel_path}\n"
    return result

@mcp.tool()
def run_vibee(spec_file: str) -> str:
    """Compile a .vibee specification to Zig code

    Args:
        spec_file: Path to .vibee file (e.g., specs/tri/feature.vibee)
    """
    # Check if tri binary is available
    if not os.path.exists(TRI_BIN):
        return "Note: tri binary not available in this deployment.\n\nThis is a lightweight Python-only MCP server.\nTo run VIBEE compilation, deploy locally or use the full Docker image."

    # Resolve path
    full_path = os.path.join(PROJECT_DIR, spec_file)
    if not os.path.exists(full_path):
        return f"File not found: {spec_file}\n\nRun list_vibee_specs to see available files."

    cmd = [TRI_BIN, "gen", spec_file]
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30,
            cwd=PROJECT_DIR
        )
        output = result.stdout or result.stderr
        return f"Command: tri gen {spec_file}\n\nOutput:\n{output}"
    except subprocess.TimeoutExpired:
        return "Error: Timeout after 30 seconds"
    except Exception as e:
        return f"Error: {e}"

@mcp.tool()
def vibee_help() -> str:
    """Show VIBEE compiler help and usage"""
    return """VIBEE Compiler Usage:

1. Create a .vibee specification:
   name: my_module
   version: "1.0.0"
   language: zig
   module: my_module

   types:
     MyType:
       fields:
         name: String

   behaviors:
     - name: my_func
       given: Input
       when: Action
       then: Result

2. Generate code:
   tri gen specs/tri/my_module.vibee

3. Output goes to: trinity/output/my_module.zig
"""

# ===== GIT STATUS =====

@mcp.tool()
def trinity_status() -> str:
    """Get current Trinity project status"""
    try:
        result = subprocess.run(
            ["git", "status", "--short", "--branch"],
            capture_output=True,
            text=True,
            timeout=5,
            cwd=PROJECT_DIR
        )
        if result.returncode == 0:
            if result.stdout:
                return f"Git Status:\n{result.stdout}"
            return "Working directory clean ✓"
        return "Not a git repository or git error"
    except Exception as e:
        return f"Error: {e}"

# ===== CHEMISTRY =====

PERIODIC_TABLE = {
    1: ("H", "Hydrogen", "1.008"),
    2: ("He", "Helium", "4.003"),
    3: ("Li", "Lithium", "6.941"),
    4: ("Be", "Beryllium", "9.012"),
    5: ("B", "Boron", "10.81"),
    6: ("C", "Carbon", "12.01"),
    7: ("N", "Nitrogen", "14.01"),
    8: ("O", "Oxygen", "16.00"),
    9: ("F", "Fluorine", "19.00"),
    10: ("Ne", "Neon", "20.18"),
    11: ("Na", "Sodium", "22.99"),
    12: ("Mg", "Magnesium", "24.31"),
    13: ("Al", "Aluminum", "26.98"),
    14: ("Si", "Silicon", "28.09"),
    15: ("P", "Phosphorus", "30.97"),
    16: ("S", "Sulfur", "32.07"),
    17: ("Cl", "Chlorine", "35.45"),
    18: ("Ar", "Argon", "39.95"),
    19: ("K", "Potassium", "39.10"),
    20: ("Ca", "Calcium", "40.08"),
    26: ("Fe", "Iron", "55.85"),
    29: ("Cu", "Copper", "63.55"),
    47: ("Ag", "Silver", "107.87"),
    79: ("Au", "Gold", "196.97"),
    80: ("Hg", "Mercury", "200.59"),
    82: ("Pb", "Lead", "207.2"),
    92: ("U", "Uranium", "238.03"),
}

@mcp.tool()
def element_info(symbol_or_number: str) -> str:
    """Get information about a chemical element

    Args:
        symbol_or_number: Element symbol (e.g., "Au") or atomic number (e.g., "79")
    """
    # Try as number
    try:
        num = int(symbol_or_number)
        if num in PERIODIC_TABLE:
            sym, name, mass = PERIODIC_TABLE[num]
            return f"Element {num}: {sym} - {name}\nAtomic mass: {mass} u"
    except ValueError:
        pass

    # Try as symbol
    for num, (sym, name, mass) in PERIODIC_TABLE.items():
        if sym.lower() == symbol_or_number.lower():
            return f"Element {num}: {sym} - {name}\nAtomic mass: {mass} u"

    return f"Element not found: {symbol_or_number}"

@mcp.tool()
def molar_mass(formula: str) -> str:
    """Calculate molar mass of a chemical formula

    Args:
        formula: Chemical formula (e.g., H2O, NaCl, C6H12O6)
    """
    import re
    masses = {sym: float(mass) for _, (sym, _, mass) in PERIODIC_TABLE.items()}

    # Parse formula
    pattern = r'([A-Z][a-z]*)(\d*)'
    matches = re.findall(pattern, formula)

    total_mass = 0
    details = []

    for elem, count in matches:
        if elem not in masses:
            return f"Unknown element: {elem}"
        n = int(count) if count else 1
        mass = masses[elem] * n
        total_mass += mass
        details.append(f"  {elem}{count}: {mass:.2f} g/mol")

    details.append(f"  Total: {total_mass:.2f} g/mol")
    return f"Molar mass of {formula}:\n" + "\n".join(details)

# ===== SYSTEM =====

@mcp.tool()
def trinity_version() -> str:
    """Get Trinity version information"""
    try:
        result = subprocess.run(
            [TRI_BIN, "version"],
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.stdout.strip()
    except Exception as e:
        # Read from CLAUDE.md
        try:
            with open(f"{PROJECT_DIR}/CLAUDE.md") as f:
                for line in f:
                    if "version" in line.lower():
                        return line.strip()
            return "Trinity v1.0"
        except:
            return "Trinity v1.0"

@mcp.tool()
def list_specs() -> str:
    """List all .vibee spec files in the project"""
    specs = []
    for root, dirs, files in os.walk(PROJECT_DIR):
        if "specs" in root or ".vibee" in " ".join(files):
            for f in files:
                if f.endswith(".vibee"):
                    full = os.path.join(root, f)
                    rel = full.replace(PROJECT_DIR + "/", "")
                    specs.append(rel)

    if not specs:
        return "No .vibee files found"

    return "Available .vibee specifications:\n" + "\n".join(f"  - {s}" for s in sorted(specs))

if __name__ == "__main__":
    mcp.run()
