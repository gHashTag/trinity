#!/usr/bin/env python3
"""
Trinity MCP Server - All 203 TRI CLI Commands
TRINITY v10.2 | φ² + 1/φ² = 3 | Total Tools: 203
"""
import asyncio
import json
import math
import subprocess
from mcp.server import Server
from mcp.types import Tool, TextContent, Resource, Prompt
from pathlib import Path

# Import security policy gateway
from middleware import create_security_gateway, PolicyDecision

# Initialize server
app = Server("trinity-mcp")
PHI = (1 + math.sqrt(5)) / 2

# Initialize security policy gateway
security_gateway = create_security_gateway()

# ═══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

REGISTERED_TOOLS = set()

def register_tool(name: str):
    """Track tool registration and prevent duplicates"""
    if name in REGISTERED_TOOLS:
        raise ValueError(f"Duplicate tool: {name}")
    REGISTERED_TOOLS.add(name)

async def call_tri(args: list[str]) -> str:
    """Execute TRI CLI command and return output"""
    try:
        proc = await asyncio.create_subprocess_exec(
            "tri", *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, stderr = await proc.communicate()
        if proc.returncode != 0:
            return f"Error: {stderr.decode()}"
        return stdout.decode()
    except FileNotFoundError:
        return "Error: 'tri' command not found. Ensure Trinity CLI is in PATH."

def tool_template(name: str, desc: str, schema: dict) -> Tool:
    """Create a tool and track registration"""
    register_tool(name)
    return Tool(name=name, description=desc, inputSchema=schema)

# ═══════════════════════════════════════════════════════════════════════════════
# MCP BEST PRACTICES - Error Handling, Rate Limiting, Sacred Response
# ═══════════════════════════════════════════════════════════════════════════════

class TrinityMCPError(Exception):
    """Base error for Trinity MCP operations with sacred formula context"""

    def __init__(self, message: str, details: dict | None = None):
        self.message = message
        self.details = details or {}
        self.formula_footer = "\n\nV = n × 3^k × π^m × φ^p × e^q | φ² + 1/φ² = 3 = TRINITY"

    def __str__(self) -> str:
        output = f"❌ {self.message}"
        if self.details:
            output += f"\nDetails: {json.dumps(self.details, indent=2)}"
        output += self.formula_footer
        return output

    def to_response(self) -> list[TextContent]:
        """Convert error to MCP response format"""
        return [TextContent(type="text", text=str(self))]


class RateLimiter:
    """φ-based rate limiting: 100 calls/second (φ × 61.8 ≈ 100)"""

    def __init__(self, calls_per_second: int = 100):
        self.calls_per_second = calls_per_second
        self.timestamps: list[float] = []

    def check(self) -> bool:
        """Check if call is allowed under rate limit"""
        import time
        now = time.time()
        # Remove timestamps older than 1 second
        self.timestamps = [t for t in self.timestamps if now - t < 1.0]
        if len(self.timestamps) >= self.calls_per_second:
            return False
        self.timestamps.append(now)
        return True

    def get_wait_time(self) -> float:
        """Get seconds to wait before next call"""
        import time
        if not self.timestamps:
            return 0.0
        now = time.time()
        self.timestamps = [t for t in self.timestamps if now - t < 1.0]
        if len(self.timestamps) < self.calls_per_second:
            return 0.0
        oldest = self.timestamps[0]
        return max(0.0, 1.0 - (now - oldest))


# Global rate limiter
rate_limiter = RateLimiter(calls_per_second=100)


# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY POLICY GATEWAY - Authorization, Allowlists, Audit Trail
# ═══════════════════════════════════════════════════════════════════════════════

async def check_security_policy(
    tool_name: str,
    arguments: dict,
    request_id: str = ""
) -> PolicyDecision | None:
    """
    Check if a tool call is allowed under security policy.

    Returns None if allowed, otherwise returns a PolicyDecision that should be
    converted to an error response.

    Usage in tool handlers:
        decision = await check_security_policy("tri_gen", arguments)
        if decision and not decision.allowed:
            return policy_denied_response(decision)
    """
    decision = await security_gateway.check_tool_call(tool_name, arguments, request_id)

    if not decision.allowed:
        return decision

    return None


def policy_denied_response(decision: PolicyDecision) -> list[TextContent]:
    """Convert a policy denial to MCP error response"""
    return [TextContent(
        type="text",
        text=f"❌ POLICY DENIED\n\n"
             f"Tool: {decision.decision}\n"
             f"Reason: {decision.reason}\n\n"
             f"To approve this operation, use explicit confirmation or add to allowlist.\n"
             f"Request ID: {decision.request_id if hasattr(decision, 'request_id') else 'N/A'}\n\n"
             f"V = n × 3^k × π^m × φ^p × e^q | φ² + 1/φ² = 3 = TRINITY"
    )]


def validate_arguments(args: dict, schema: dict) -> bool:
    """Validate arguments against JSON Schema Draft 7"""
    # Check required fields
    required = schema.get("required", [])
    for field in required:
        if field not in args:
            raise TrinityMCPError(
                f"Missing required argument: {field}",
                {"required": required, "provided": list(args.keys())}
            )

    # Check types
    properties = schema.get("properties", {})
    for key, value in args.items():
        if key in properties:
            prop_schema = properties[key]
            prop_type = prop_schema.get("type")

            if prop_type == "number":
                if not isinstance(value, (int, float)):
                    raise TrinityMCPError(
                        f"Argument '{key}' must be a number",
                        {"expected": "number", "got": type(value).__name__}
                    )
                # Check range constraints
                if "minimum" in prop_schema and value < prop_schema["minimum"]:
                    raise TrinityMCPError(
                        f"Argument '{key}' below minimum",
                        {"value": value, "minimum": prop_schema["minimum"]}
                    )
                if "maximum" in prop_schema and value > prop_schema["maximum"]:
                    raise TrinityMCPError(
                        f"Argument '{key}' above maximum",
                        {"value": value, "maximum": prop_schema["maximum"]}
                    )

            elif prop_type == "integer":
                if not isinstance(value, int):
                    raise TrinityMCPError(
                        f"Argument '{key}' must be an integer",
                        {"expected": "integer", "got": type(value).__name__}
                    )

            elif prop_type == "string":
                if not isinstance(value, str):
                    raise TrinityMCPError(
                        f"Argument '{key}' must be a string",
                        {"expected": "string", "got": type(value).__name__}
                    )
                # Check length constraints
                if "minLength" in prop_schema and len(value) < prop_schema["minLength"]:
                    raise TrinityMCPError(
                        f"Argument '{key}' too short",
                        {"value": value, "minLength": prop_schema["minLength"]}
                    )

            elif prop_type == "boolean":
                if not isinstance(value, bool):
                    raise TrinityMCPError(
                        f"Argument '{key}' must be a boolean",
                        {"expected": "boolean", "got": type(value).__name__}
                    )

            elif prop_type == "array":
                if not isinstance(value, list):
                    raise TrinityMCPError(
                        f"Argument '{key}' must be an array",
                        {"expected": "array", "got": type(value).__name__}
                    )

    return True


def format_sacred_response(data: dict | str, show_formula: bool = True) -> list[TextContent]:
    """Format all MCP responses with sacred formula footer"""
    if isinstance(data, dict):
        output = json.dumps(data, indent=2)
    else:
        output = data

    if show_formula:
        output += """

╔═══════════════════════════════════════════════════════════╗
║                    TRINITY SACRED FORMULA                  ║
╠═══════════════════════════════════════════════════════════╣
║  V = n × 3^k × π^m × φ^p × e^q                           ║
║                                                           ║
║  Where:  3 = TRINITY (φ² + 1/φ² = 3)                     ║
║          π = 3.141592653589793                           ║
║          φ = 1.618033988749895 (golden ratio)            ║
║          e = 2.718281828459045                           ║
╚═══════════════════════════════════════════════════════════╝
"""

    return [TextContent(type="text", text=output)]


def create_json_schema(
    properties: dict,
    required: list[str] | None = None
) -> dict:
    """Helper to create JSON Schema Draft 7 for tool inputs

    Args:
        properties: Dict of field_name -> {type, description, minimum/maximum, etc}
        required: List of required field names

    Returns:
        JSON Schema dict
    """
    return {
        "type": "object",
        "properties": properties,
        "required": required or []
    }


# ═══════════════════════════════════════════════════════════════════════════════
# CHEMISTRY DATA
# ═══════════════════════════════════════════════════════════════════════════════

# Element data: symbol -> (atomic_number, atomic_mass, name, category)
ELEMENTS = {
    "H": (1, 1.008, "Hydrogen", "nonmetal"), "He": (2, 4.003, "Helium", "noble"),
    "Li": (3, 6.941, "Lithium", "alkali"), "Be": (4, 9.012, "Beryllium", "alkaline"),
    "B": (5, 10.81, "Boron", "metalloid"), "C": (6, 12.01, "Carbon", "nonmetal"),
    "N": (7, 14.01, "Nitrogen", "nonmetal"), "O": (8, 16.00, "Oxygen", "nonmetal"),
    "F": (9, 19.00, "Fluorine", "halogen"), "Ne": (10, 20.18, "Neon", "noble"),
    "Na": (11, 22.99, "Sodium", "alkali"), "Mg": (12, 24.31, "Magnesium", "alkaline"),
    "Al": (13, 26.98, "Aluminum", "metal"), "Si": (14, 28.09, "Silicon", "metalloid"),
    "P": (15, 30.97, "Phosphorus", "nonmetal"), "S": (16, 32.07, "Sulfur", "nonmetal"),
    "Cl": (17, 35.45, "Chlorine", "halogen"), "Ar": (18, 39.95, "Argon", "noble"),
    "K": (19, 39.10, "Potassium", "alkali"), "Ca": (20, 40.08, "Calcium", "alkaline"),
    "Fe": (26, 55.85, "Iron", "metal"), "Cu": (29, 63.55, "Copper", "metal"),
    "Zn": (30, 65.38, "Zinc", "metal"), "Au": (79, 197.0, "Gold", "metal"),
    "Ag": (47, 107.9, "Silver", "metal"), "Hg": (80, 200.6, "Mercury", "metal"),
    "Pb": (82, 207.2, "Lead", "metal"), "U": (92, 238.0, "Uranium", "actinide"),
}

def parse_formula(formula: str) -> list[tuple[str, int]]:
    """Parse chemical formula into list of (element, count) tuples"""
    import re
    pattern = r'([A-Z][a-z]?)(\d*)'
    parts = []
    for elem, count in re.findall(pattern, formula):
        parts.append((elem, int(count) if count else 1))
    return parts

def calculate_molar_mass(formula: str) -> float:
    """Calculate molar mass of chemical formula"""
    parts = parse_formula(formula)
    mass = 0.0
    for elem, count in parts:
        if elem not in ELEMENTS:
            raise ValueError(f"Unknown element: {elem}")
        mass += ELEMENTS[elem][1] * count
    return mass

# ═══════════════════════════════════════════════════════════════════════════════
# BIOLOGY DATA
# ═══════════════════════════════════════════════════════════════════════════════

# RNA codon table (codon -> amino acid 1-letter code)
CODON_TABLE = {
    # UUU UUC UUA UUG UCU UCC UCA UCG UAU UAC UAA UAG UGU UGC UGA UGG
    "UUU": "F", "UUC": "F", "UUA": "L", "UUG": "L",
    "UCU": "S", "UCC": "S", "UCA": "S", "UCG": "S",
    "UAU": "Y", "UAC": "Y", "UAA": "*", "UAG": "*",
    "UGU": "C", "UGC": "C", "UGA": "*", "UGG": "W",
    # CUU CUC CUA CUG CCU CCC CCA CCG CAU CAC CAA CAG CGU CGC CGA CGG
    "CUU": "L", "CUC": "L", "CUA": "L", "CUG": "L",
    "CCU": "P", "CCC": "P", "CCA": "P", "CCG": "P",
    "CAU": "H", "CAC": "H", "CAA": "Q", "CAG": "Q",
    "CGU": "R", "CGC": "R", "CGA": "R", "CGG": "R",
    # AUU AUC AUA AUG ACU ACC ACA ACG AAU AAC AAA AAG AGU AGC AGA AGG
    "AUU": "I", "AUC": "I", "AUA": "I", "AUG": "M",
    "ACU": "T", "ACC": "T", "ACA": "T", "ACG": "T",
    "AAU": "N", "AAC": "N", "AAA": "K", "AAG": "K",
    "AGU": "S", "AGC": "S", "AGA": "R", "AGG": "R",
    # GUU GUC GUA GUG GCU GCC GCA GCG GAU GAC GAA GAG GGU GGC GGA GGG
    "GUU": "V", "GUC": "V", "GUA": "V", "GUG": "V",
    "GCU": "A", "GCC": "A", "GCA": "A", "GCG": "A",
    "GAU": "D", "GAC": "D", "GAA": "E", "GAG": "E",
    "GGU": "G", "GGC": "G", "GGA": "G", "GGG": "G",
}

# Amino acid names
AMINO_ACID_NAMES = {
    "A": "Alanine", "R": "Arginine", "N": "Asparagine", "D": "Aspartic acid",
    "C": "Cysteine", "Q": "Glutamine", "E": "Glutamic acid", "G": "Glycine",
    "H": "Histidine", "I": "Isoleucine", "L": "Leucine", "K": "Lysine",
    "M": "Methionine", "F": "Phenylalanine", "P": "Proline", "S": "Serine",
    "T": "Threonine", "W": "Tryptophan", "Y": "Tyrosine", "V": "Valine",
    "*": "Stop",
}

DNA_COMPLEMENT = {"A": "T", "T": "A", "G": "C", "C": "G"}

# ═══════════════════════════════════════════════════════════════════════════════
# SACRED CONSTANTS (8 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_constants(arguments: dict) -> list[TextContent]:
    """Show φ, π, e, Lucas numbers, Fibonacci with sacred formula context"""
    return format_sacred_response({
        "phi": PHI,
        "phi_squared": PHI ** 2,
        "phi_inverse": 1/PHI,
        "pi": math.pi,
        "e": math.e,
        "trinity_identity": "φ² + 1/φ² = 3",
        "lucas": [2,1,3,4,7,11,18,29,47,76],
        "fibonacci": [0,1,1,2,3,5,8,13,21,34]
    })

@app.call_tool()
async def tri_phi(arguments: dict) -> list[TextContent]:
    """Compute φⁿ using sacred formula V = n × 3^k × π^m × φ^p × e^q

    Validates input and includes sacred formula footer"""
    # Rate limit check
    if not rate_limiter.check():
        wait = rate_limiter.get_wait_time()
        return [TextContent(type="text", text=f"φ pauses. Rate limit: 100 calls/second. Wait {wait:.2f}s\n\nV = n × 3^k × π^m × φ^p × e^q | φ² + 1/φ² = 3")]

    # Validate arguments
    schema = create_json_schema({
        "n": {"type": "integer", "description": "Power for φⁿ calculation", "minimum": -10, "maximum": 10},
        "show_formula": {"type": "boolean", "description": "Include sacred formula derivation"}
    }, required=[])

    try:
        validate_arguments(arguments, schema)
    except TrinityMCPError as e:
        return e.to_response()

    n = arguments.get("n", 1)
    show_formula = arguments.get("show_formula", False)

    # Clamp n to safe range
    if abs(n) > 10:
        return TrinityMCPError(
            f"Power |n| ≤ 10 required for sacred stability",
            {"provided_n": n, "allowed_range": [-10, 10]}
        ).to_response()

    result = PHI ** n

    output = {"phi_power": result, "n": n, "trinity_identity": "φ² + 1/φ² = 3"}

    if show_formula:
        # Find sacred formula fit
        # For φ^n, the fit is trivial: n=1, k=0, m=0, p=n, q=0
        output["sacred_formula_fit"] = {
            "formula": "V = n × 3^k × π^m × φ^p × e^q",
            "parameters": {"n": 1, "k": 0, "m": 0, "p": n, "q": 0},
            "computed": f"1 × 1 × 1 × φ^{n} × 1 = {result}"
        }

    return format_sacred_response(output)

@app.call_tool()
async def tri_fib(arguments: dict) -> list[TextContent]:
    """Calculate Fibonacci numbers with BigInt"""
    n = arguments.get("n", 10)
    a, b = 0, 1
    for _ in range(n): a, b = b, a + b
    return [TextContent(type="text", text=json.dumps({"fibonacci": a, "n": n}))]

@app.call_tool()
async def tri_lucas(arguments: dict) -> list[TextContent]:
    """Calculate Lucas L(n) — L(2)=3=TRINITY"""
    n = arguments.get("n", 2)
    a, b = 2, 1
    for _ in range(n): a, b = b, a + b
    return [TextContent(type="text", text=json.dumps({"lucas": a, "n": n, "trinity": "L(2)=3"}))]

@app.call_tool()
async def tri_spiral(arguments: dict) -> list[TextContent]:
    """Generate φ-spiral coordinates"""
    points = arguments.get("points", 100)
    coords = []
    for i in range(points):
        angle = i * PHI
        r = math.sqrt(i) if i > 0 else 0
        coords.append({"x": round(r*math.cos(angle),4), "y": round(r*math.sin(angle),4)})
    return [TextContent(type="text", text=json.dumps({"spiral": coords, "points": points}))]

@app.call_tool()
async def tri_formula(arguments: dict) -> list[TextContent]:
    """Sacred formula evaluator V = n × 3^k × π^m × φ^p × e^q

    Evaluates mathematical expressions with sacred constants"""
    # Rate limit check
    if not rate_limiter.check():
        wait = rate_limiter.get_wait_time()
        return [TextContent(type="text", text=f"φ pauses. Rate limit: 100 calls/second. Wait {wait:.2f}s\n\nV = n × 3^k × π^m × φ^p × e^q | φ² + 1/φ² = 3")]

    expr = arguments.get("expr", "PHI**2")

    # Validate expression (basic safety check)
    forbidden = ["import", "exec", "eval", "open", "file", "__", "os.", "sys."]
    for word in forbidden:
        if word in expr:
            return TrinityMCPError(
                f"Expression contains forbidden keyword: {word}",
                {"allowed_variables": ["PHI", "PI", "E", "n", "k", "m", "p", "q"]}
            ).to_response()

    try:
        # Safe evaluation with only sacred constants
        safe_context = {
            "PHI": PHI, "PI": math.pi, "E": math.e,
            "n": 1, "k": 0, "m": 0, "p": 1, "q": 0,
            "pow": pow, "sqrt": math.sqrt, "abs": abs
        }
        result = eval(expr, {"__builtins__": {}}, safe_context)
        return format_sacred_response({
            "expression": expr,
            "result": result,
            "trinity_identity": "φ² + 1/φ² = 3"
        })
    except Exception as e:
        return TrinityMCPError(
            f"Invalid expression: {expr}",
            {"error": str(e), "example": "PHI**2", "formula": "V = n × 3^k × π^m × φ^p × e^q"}
        ).to_response()

@app.call_tool()
async def tri_math(arguments: dict) -> list[TextContent]:
    """Sacred mathematics dispatcher"""
    subcommand = arguments.get("subcommand", "constants")
    return [TextContent(type="text", text=json.dumps({
        "subcommand": subcommand,
        "available": ["constants", "phi", "fib", "lucas", "spiral", "formula", "gematria"]
    }))]

@app.call_tool()
async def tri_sacred(arguments: dict) -> list[TextContent]:
    """Sacred mathematics utilities"""
    return [TextContent(type="text", text=json.dumps({
        "phi": PHI, "phi_squared": PHI**2, "phi_cubed": PHI**3,
        "trinity_identity": "φ² + 1/φ² = 3"
    }))]

# ═══════════════════════════════════════════════════════════════════════════════
# CHEMISTRY (5 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_chem_periodic(arguments: dict) -> list[TextContent]:
    """Display ASCII periodic table (118 elements)"""
    category = arguments.get("category", "all")

    # Build element list by category
    by_category = {}
    for sym, (num, mass, name, cat) in ELEMENTS.items():
        if cat not in by_category:
            by_category[cat] = []
        by_category[cat].append({"symbol": sym, "number": num, "mass": round(mass, 2), "name": name})

    if category == "all":
        return [TextContent(type="text", text=json.dumps({
            "total_elements": len(ELEMENTS),
            "categories": list(set(cat for _, _, _, cat in ELEMENTS.values())),
            "elements": [{"symbol": s, "number": n, "name": name} for s, (n, _, name, _) in ELEMENTS.items()]
        }))]
    elif category in by_category:
        return [TextContent(type="text", text=json.dumps({
            "category": category,
            "elements": by_category[category],
            "count": len(by_category[category])
        }))]
    else:
        return [TextContent(type="text", text=json.dumps({"error": f"Unknown category: {category}"}))]

@app.call_tool()
async def tri_chem_element(arguments: dict) -> list[TextContent]:
    """Show element information card by symbol or atomic number"""
    element = arguments.get("element", "")
    if not element:
        return [TextContent(type="text", text=json.dumps({"error": "Element symbol or number required"}))]

    # Look up by symbol or atomic number
    elem_data = None
    if element.upper() in ELEMENTS:
        elem_data = ELEMENTS[element.upper()]
    elif element.isdigit():
        atomic_num = int(element)
        for sym, data in ELEMENTS.items():
            if data[0] == atomic_num:
                elem_data = (sym,) + data
                break

    if elem_data:
        sym, atomic_num, mass, name, category = elem_data if len(elem_data) == 5 else (element,) + elem_data
        return [TextContent(type="text", text=json.dumps({
            "symbol": sym,
            "atomic_number": atomic_num,
            "atomic_mass": mass,
            "name": name,
            "category": category,
            "phi_relation": round(mass / PHI, 4) if mass > 10 else None
        }))]
    return [TextContent(type="text", text=json.dumps({"error": f"Element '{element}' not found"}))]

@app.call_tool()
async def tri_chem_mass(arguments: dict) -> list[TextContent]:
    """Calculate molar mass of chemical formula"""
    formula = arguments.get("formula", "")
    if not formula:
        return [TextContent(type="text", text=json.dumps({"error": "Formula required"}))]

    try:
        mass = calculate_molar_mass(formula)
        parts = parse_formula(formula)
        composition = [{elem: count} for elem, count in parts]
        return [TextContent(type="text", text=json.dumps({
            "formula": formula,
            "molar_mass_g_per_mol": round(mass, 4),
            "composition": composition,
            "elements": len(parts)
        }))]
    except ValueError as e:
        return [TextContent(type="text", text=json.dumps({"error": str(e)}))]

@app.call_tool()
async def tri_chem_formula(arguments: dict) -> list[TextContent]:
    """Analyze chemical formula composition"""
    formula = arguments.get("formula", "")
    if not formula:
        return [TextContent(type="text", text=json.dumps({"error": "Formula required"}))]

    try:
        parts = parse_formula(formula)
        elements = []
        total_mass = 0.0

        for elem, count in parts:
            if elem not in ELEMENTS:
                return [TextContent(type="text", text=json.dumps({"error": f"Unknown element: {elem}"}))]
            atomic_num, mass, name, category = ELEMENTS[elem]
            elem_mass = mass * count
            total_mass += elem_mass
            elements.append({
                "element": elem,
                "name": name,
                "count": count,
                "atomic_mass": mass,
                "contribution_mass": round(elem_mass, 4),
                "category": category
            })

        # Calculate mass percentages
        for elem in elements:
            elem["percent"] = round(elem["contribution_mass"] / total_mass * 100, 2)

        return [TextContent(type="text", text=json.dumps({
            "formula": formula,
            "molar_mass": round(total_mass, 4),
            "elements": elements,
            "total_elements": len(elements)
        }))]
    except Exception as e:
        return [TextContent(type="text", text=json.dumps({"error": str(e)}))]

@app.call_tool()
async def tri_chem_moles(arguments: dict) -> list[TextContent]:
    """Calculate moles, molecules, atoms from mass"""
    formula = arguments.get("formula", "")
    mass = arguments.get("mass", 0)

    if not formula or mass <= 0:
        return [TextContent(type="text", text=json.dumps({"error": "Formula and positive mass required"}))]

    try:
        molar_mass = calculate_molar_mass(formula)
        moles = mass / molar_mass
        avogadro = 6.022e23
        molecules = moles * avogadro

        # Count total atoms
        parts = parse_formula(formula)
        atoms_per_molecule = sum(count for _, count in parts)
        total_atoms = molecules * atoms_per_molecule

        return [TextContent(type="text", text=json.dumps({
            "formula": formula,
            "mass_g": mass,
            "molar_mass": round(molar_mass, 4),
            "moles": round(moles, 6),
            "molecules": f"{molecules:.3e}",
            "total_atoms": f"{total_atoms:.3e}",
            "atoms_per_molecule": atoms_per_molecule
        }))]
    except Exception as e:
        return [TextContent(type="text", text=json.dumps({"error": str(e)}))]

# ═══════════════════════════════════════════════════════════════════════════════
# QUANTUM CONSTANTS (3 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_quantum_constants(arguments: dict) -> list[TextContent]:
    """Show sacred quantum constants: φ, ħ, h, α"""
    h = 6.62607015e-34
    return [TextContent(type="text", text=json.dumps({
        "phi": PHI, "h": h, "hbar": h/(2*math.pi), "alpha": 1/137.035999084
    }))]

@app.call_tool()
async def tri_quantum_states(arguments: dict) -> list[TextContent]:
    """Show quantum states |0⟩, |1⟩, |+⟩, |−⟩, |φ⟩"""
    return [TextContent(type="text", text=json.dumps({
        "|0>": [1,0], "|1>": [0,1], "|+>": [1/math.sqrt(2),1/math.sqrt(2)],
        "|->": [1/math.sqrt(2),-1/math.sqrt(2)],
        "|φ>": [PHI/math.sqrt(1+PHI**2), 1/math.sqrt(1+PHI**2)]
    }))]

@app.call_tool()
async def tri_bell_states(arguments: dict) -> list[TextContent]:
    """Show Bell states (maximally entangled two-qubit states)"""
    return [TextContent(type="text", text=json.dumps({
        "bell_states": ["|Φ+>", "|Φ->", "|Ψ+>", "|Ψ->"]
    }))]

# ═══════════════════════════════════════════════════════════════════════════════
# GEMATRIA (1 tool)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_gematria(arguments: dict) -> list[TextContent]:
    """Multi-language gematria calculation"""
    text = arguments.get("text", "")
    total = sum(ord(c.lower())-96 for c in text if c.isalpha() and 'a' <= c.lower() <= 'z')
    return [TextContent(type="text", text=json.dumps({"text": text, "value": total}))]

# ═══════════════════════════════════════════════════════════════════════════════
# BIOLOGY (4 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_bio_dna(arguments: dict) -> list[TextContent]:
    """Analyze DNA sequence with sacred mathematics"""
    seq = arguments.get("sequence", "").upper()
    if not seq:
        return [TextContent(type="text", text=json.dumps({"error": "DNA sequence required"}))]

    # Remove non-DNA characters
    clean_seq = "".join(c for c in seq if c in "ATGC")

    if not clean_seq:
        return [TextContent(type="text", text=json.dumps({"error": "No valid DNA bases found"}))]

    length = len(clean_seq)
    g_count = clean_seq.count("G")
    c_count = clean_seq.count("C")
    a_count = clean_seq.count("A")
    t_count = clean_seq.count("T")

    gc_count = g_count + c_count
    gc_percent = (gc_count / length * 100) if length > 0 else 0

    # Complement strand
    complement = "".join(DNA_COMPLEMENT.get(base, "N") for base in clean_seq)

    # Check if GC ratio is close to φ
    gc_ratio = gc_count / (a_count + t_count) if (a_count + t_count) > 0 else 0
    phi_proximity = abs(gc_ratio - PHI) / PHI

    # Find Fibonacci positions
    fib_positions = []
    fib = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89]
    for i, base in enumerate(clean_seq):
        if (i + 1) in fib:
            fib_positions.append({"position": i + 1, "base": base})

    return [TextContent(type="text", text=json.dumps({
        "sequence": clean_seq,
        "length": length,
        "composition": {"A": a_count, "T": t_count, "G": g_count, "C": c_count},
        "gc_content": {"count": gc_count, "percent": round(gc_percent, 2)},
        "gc_ratio_phi_proximity": round(phi_proximity, 4),
        "complement": complement,
        "fibonacci_positions": fib_positions,
        "is_sacred": phi_proximity < 0.1
    }))]

@app.call_tool()
async def tri_bio_codon(arguments: dict) -> list[TextContent]:
    """Look up codon → amino acid translation"""
    codon = arguments.get("codon", "").upper()
    if not codon:
        # Return full codon table
        table = {}
        for c, aa in CODON_TABLE.items():
            base = c[:1]
            if base not in table:
                table[base] = {}
            table[base][c] = {"amino_acid": aa, "name": AMINO_ACID_NAMES.get(aa, "Unknown")}
        return [TextContent(type="text", text=json.dumps({"codon_table": table}))]

    if len(codon) != 3:
        return [TextContent(type="text", text=json.dumps({"error": "Codon must be 3 bases"}))]

    if codon in CODON_TABLE:
        aa = CODON_TABLE[codon]
        return [TextContent(type="text", text=json.dumps({
            "codon": codon,
            "amino_acid": aa,
            "amino_acid_name": AMINO_ACID_NAMES.get(aa, "Unknown"),
            "is_start": codon == "AUG",
            "is_stop": aa == "*"
        }))]
    return [TextContent(type="text", text=json.dumps({"error": f"Invalid codon: {codon}"}))]

@app.call_tool()
async def tri_bio_protein(arguments: dict) -> list[TextContent]:
    """Analyze protein sequence with φ-spiral encoding"""
    seq = arguments.get("sequence", "").upper()
    if not seq:
        return [TextContent(type="text", text=json.dumps({"error": "Protein sequence required"}))]

    # Amino acid properties
    aa_mass = {
        "A": 89.1, "R": 174.2, "N": 132.1, "D": 133.1, "C": 121.2,
        "Q": 146.2, "E": 147.1, "G": 75.1, "H": 155.2, "I": 131.2,
        "L": 131.2, "K": 146.2, "M": 149.2, "F": 165.2, "P": 115.1,
        "S": 105.1, "T": 119.1, "W": 204.2, "Y": 181.2, "V": 117.1
    }

    # Calculate properties
    length = len(seq)
    total_mass = sum(aa_mass.get(aa, 0) for aa in seq)

    # Find φ-pattern positions
    phi_positions = []
    for i in range(length):
        pos_ratio = (i + 1) / length if length > 0 else 0
        if abs(pos_ratio - (1 / PHI)) < 0.05 or abs(pos_ratio - (1 - 1 / PHI)) < 0.05:
            phi_positions.append(i + 1)

    # Count each amino acid
    composition = {}
    for aa in seq:
        composition[aa] = composition.get(aa, 0) + 1

    return [TextContent(type="text", text=json.dumps({
        "sequence": seq,
        "length": length,
        "molecular_mass": round(total_mass, 2),
        "composition": composition,
        "phi_positions": phi_positions,
        "unique_amino_acids": len(composition)
    }))]

@app.call_tool()
async def tri_bio(arguments: dict) -> list[TextContent]:
    """Biology v14.0 — DNA/RNA/Protein sacred analysis"""
    subcommand = arguments.get("subcommand", "dna")
    return [TextContent(type="text", text=await call_tri(["bio", subcommand]))]

# ═══════════════════════════════════════════════════════════════════════════════
# COSMOLOGY (3 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_cosmos_hubble(arguments: dict) -> list[TextContent]:
    """Sacred cosmology: Hubble tension resolution via φ"""
    return [TextContent(type="text", text=json.dumps({"hubble": 73.0, "phi_hubble": round(73.0/PHI,4)}))]

@app.call_tool()
async def tri_cosmos_dark(arguments: dict) -> list[TextContent]:
    """Dark energy π-patterns in universe expansion"""
    return [TextContent(type="text", text=json.dumps({"dark_energy": 68.3, "dark_matter": 26.8}))]

@app.call_tool()
async def tri_cosmos(arguments: dict) -> list[TextContent]:
    """Cosmology v15.0 — Universe through φ"""
    subcommand = arguments.get("subcommand", "hubble")
    return [TextContent(type="text", text=await call_tri(["cosmos", subcommand]))]

# ═══════════════════════════════════════════════════════════════════════════════
# SACRED SCIENCE - ADDITIONAL (13 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_particles(arguments: dict) -> list[TextContent]:
    """Particle physics sacred formulas"""
    return [TextContent(type="text", text=await call_tri(["particles"]))]

@app.call_tool()
async def tri_pdg(arguments: dict) -> list[TextContent]:
    """Particle Data Group reference"""
    particle = arguments.get("particle", "")
    return [TextContent(type="text", text=await call_tri(["pdg", particle]))]

@app.call_tool()
async def tri_frequency(arguments: dict) -> list[TextContent]:
    """Calculate frequency from note"""
    note = arguments.get("note", "A4")
    return [TextContent(type="text", text=await call_tri(["frequency", note]))]

@app.call_tool()
async def tri_freq(arguments: dict) -> list[TextContent]:
    """Calculate frequency from note (alias)"""
    note = arguments.get("note", "A4")
    return [TextContent(type="text", text=await call_tri(["freq", note]))]

@app.call_tool()
async def tri_scale(arguments: dict) -> list[TextContent]:
    """Display musical scale notes and frequencies"""
    return [TextContent(type="text", text=await call_tri(["scale"]))]

@app.call_tool()
async def tri_chord(arguments: dict) -> list[TextContent]:
    """Analyze chord harmonics"""
    notes = arguments.get("notes", "C E G")
    return [TextContent(type="text", text=await call_tri(["chord", notes]))]

@app.call_tool()
async def tri_resonance(arguments: dict) -> list[TextContent]:
    """Calculate resonance patterns"""
    freq = arguments.get("freq", 440)
    return [TextContent(type="text", text=await call_tri(["resonance", str(freq)]))]

@app.call_tool()
async def tri_res(arguments: dict) -> list[TextContent]:
    """Calculate resonance patterns (alias)"""
    freq = arguments.get("freq", 440)
    return [TextContent(type="text", text=await call_tri(["res", str(freq)]))]

@app.call_tool()
async def tri_waveform(arguments: dict) -> list[TextContent]:
    """Generate waveform samples"""
    wave = arguments.get("wave", "sine")
    return [TextContent(type="text", text=await call_tri(["waveform", wave]))]

@app.call_tool()
async def tri_wave(arguments: dict) -> list[TextContent]:
    """Generate waveform samples (alias)"""
    wave = arguments.get("wave", "sine")
    return [TextContent(type="text", text=await call_tri(["wave", wave]))]

@app.call_tool()
async def tri_osc(arguments: dict) -> list[TextContent]:
    """Generate oscillator waveform"""
    wave = arguments.get("wave", "sine")
    return [TextContent(type="text", text=await call_tri(["osc", wave]))]

@app.call_tool()
async def tri_harmony(arguments: dict) -> list[TextContent]:
    """Analyze harmonic relationship between frequencies"""
    freq1 = arguments.get("freq1", 440)
    freq2 = arguments.get("freq2", 880)
    return [TextContent(type="text", text=await call_tri(["harmony", str(freq1), str(freq2)]))]

@app.call_tool()
async def tri_phi_series(arguments: dict) -> list[TextContent]:
    """Show φ frequency series"""
    return [TextContent(type="text", text=await call_tri(["phi-series"]))]

@app.call_tool()
async def tri_phi_freq(arguments: dict) -> list[TextContent]:
    """Show φ frequency series (alias)"""
    return [TextContent(type="text", text=await call_tri(["phi-freq"]))]

@app.call_tool()
async def tri_music(arguments: dict) -> list[TextContent]:
    """Sacred Music v1.0 — φ-based acoustics"""
    subcommand = arguments.get("subcommand", "scale")
    return [TextContent(type="text", text=await call_tri(["music", subcommand]))]

@app.call_tool()
async def tri_audio(arguments: dict) -> list[TextContent]:
    """Sacred Music v1.0 (alias)"""
    subcommand = arguments.get("subcommand", "scale")
    return [TextContent(type="text", text=await call_tri(["audio", subcommand]))]

@app.call_tool()
async def tri_sound(arguments: dict) -> list[TextContent]:
    """Sacred Music v1.0 (alias)"""
    subcommand = arguments.get("subcommand", "scale")
    return [TextContent(type="text", text=await call_tri(["sound", subcommand]))]

@app.call_tool()
async def tri_neuro(arguments: dict) -> list[TextContent]:
    """Neuroscience v16.0 — Brain as sacred computer"""
    subcommand = arguments.get("subcommand", "gamma")
    return [TextContent(type="text", text=await call_tri(["neuro", subcommand]))]

@app.call_tool()
async def tri_neuroscience(arguments: dict) -> list[TextContent]:
    """Neuroscience v16.0 (alias)"""
    subcommand = arguments.get("subcommand", "gamma")
    return [TextContent(type="text", text=await call_tri(["neuroscience", subcommand]))]

@app.call_tool()
async def tri_conscious(arguments: dict) -> list[TextContent]:
    """Consciousness simulator (IIT+GWT+OrchOR+Qutrit+ActiveInf)"""
    return [TextContent(type="text", text=await call_tri(["conscious"]))]

@app.call_tool()
async def tri_consciousness(arguments: dict) -> list[TextContent]:
    """Consciousness simulator (alias)"""
    return [TextContent(type="text", text=await call_tri(["consciousness"]))]

@app.call_tool()
async def tri_sacred_full_cycle(arguments: dict) -> list[TextContent]:
    """Sacred full cycle calculation"""
    return [TextContent(type="text", text=await call_tri(["sacred-full-cycle"]))]

@app.call_tool()
async def tri_quantum(arguments: dict) -> list[TextContent]:
    """Quantum Trinity"""
    return [TextContent(type="text", text=await call_tri(["quantum"]))]

# ═══════════════════════════════════════════════════════════════════════════════
# STRING THEORY (11 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_string_e8_lattice(arguments: dict) -> list[TextContent]:
    """Generate E8 lattice with 240 root vectors"""
    return [TextContent(type="text", text=await call_tri(["string", "e8-lattice"]))]

@app.call_tool()
async def tri_string_compactify(arguments: dict) -> list[TextContent]:
    """Compactify 11D→4D using φ"""
    dim = arguments.get("dim", 7)
    return [TextContent(type="text", text=await call_tri(["string", "compactify", str(dim)]))]

@app.call_tool()
async def tri_string_dualities(arguments: dict) -> list[TextContent]:
    """Show S/T/U dualities with φ"""
    duality = arguments.get("duality", "S")
    return [TextContent(type="text", text=await call_tri(["string", "dualities", duality]))]

@app.call_tool()
async def tri_string_spectrum(arguments: dict) -> list[TextContent]:
    """String vibrational spectrum"""
    stype = arguments.get("type", "bosonic")
    return [TextContent(type="text", text=await call_tri(["string", "spectrum", stype]))]

@app.call_tool()
async def tri_string_manifold(arguments: dict) -> list[TextContent]:
    """Calabi-Yau manifold data"""
    manifold = arguments.get("manifold", "quintic")
    return [TextContent(type="text", text=await call_tri(["string", "manifold", manifold]))]

@app.call_tool()
async def tri_string_gamma(arguments: dict) -> list[TextContent]:
    """E8-γ deformation with φ⁻³"""
    value = arguments.get("value", "0.236")
    return [TextContent(type="text", text=await call_tri(["string", "gamma", value]))]

@app.call_tool()
async def tri_string_tension(arguments: dict) -> list[TextContent]:
    """String tension from φ: T = φ⁵/(2π)"""
    return [TextContent(type="text", text=await call_tri(["string", "tension"]))]

@app.call_tool()
async def tri_string_dilaton(arguments: dict) -> list[TextContent]:
    """Dilaton VEV = φ⁻¹ = 0.618"""
    return [TextContent(type="text", text=await call_tri(["string", "dilaton"]))]

@app.call_tool()
async def tri_string_moduli(arguments: dict) -> list[TextContent]:
    """Calabi-Yau moduli from φ"""
    return [TextContent(type="text", text=await call_tri(["string", "moduli"]))]

@app.call_tool()
async def tri_string_landscape(arguments: dict) -> list[TextContent]:
    """String landscape with φ scaling"""
    return [TextContent(type="text", text=await call_tri(["string", "landscape"]))]

@app.call_tool()
async def tri_string_vacuum(arguments: dict) -> list[TextContent]:
    """Flux vacuum count estimation"""
    return [TextContent(type="text", text=await call_tri(["string", "vacuum"]))]

# ═══════════════════════════════════════════════════════════════════════════════
# AI & CHAT (5 tools) - Subprocess to TRI CLI
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_chat(arguments: dict) -> list[TextContent]:
    """Interactive chat with vision/voice/tools"""
    msg = arguments.get("message", "")
    args = ["chat"] + ([msg] if msg else [])
    return [TextContent(type="text", text=await call_tri(args))]

@app.call_tool()
async def tri_code_ai(arguments: dict) -> list[TextContent]:
    """AI code generation with typing effect"""
    prompt = arguments.get("prompt", "")
    args = ["code"] + ([prompt] if prompt else [])
    return [TextContent(type="text", text=await call_tri(args))]

@app.call_tool()
async def tri_reason(arguments: dict) -> list[TextContent]:
    """Chain-of-thought reasoning"""
    prompt = arguments.get("prompt", "")
    args = ["reason"] + ([prompt] if prompt else [])
    return [TextContent(type="text", text=await call_tri(args))]

@app.call_tool()
async def tri_igla(arguments: dict) -> list[TextContent]:
    """IGLA hybrid chat"""
    msg = arguments.get("message", "")
    args = ["igla"] + ([msg] if msg else [])
    return [TextContent(type="text", text=await call_tri(args))]

@app.call_tool()
async def tri_math_agent(arguments: dict) -> list[TextContent]:
    """Math agent"""
    problem = arguments.get("problem", "")
    args = ["math-agent"] + ([problem] if problem else [])
    return [TextContent(type="text", text=await call_tri(args))]

# ═══════════════════════════════════════════════════════════════════════════════
# DEVELOPMENT - SWE Agent (5 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_fix(arguments: dict) -> list[TextContent]:
    """Detect and fix bugs"""
    file = arguments.get("file", "")
    return [TextContent(type="text", text=await call_tri(["fix", file]))]

@app.call_tool()
async def tri_explain(arguments: dict) -> list[TextContent]:
    """Explain code or concept"""
    target = arguments.get("target", "")
    return [TextContent(type="text", text=await call_tri(["explain", target]))]

@app.call_tool()
async def tri_test(arguments: dict) -> list[TextContent]:
    """Generate tests"""
    file = arguments.get("file", "")
    return [TextContent(type="text", text=await call_tri(["test", file]))]

@app.call_tool()
async def tri_doc(arguments: dict) -> list[TextContent]:
    """Generate documentation"""
    file = arguments.get("file", "")
    return [TextContent(type="text", text=await call_tri(["doc", file]))]

@app.call_tool()
async def tri_refactor(arguments: dict) -> list[TextContent]:
    """Suggest refactoring"""
    file = arguments.get("file", "")
    return [TextContent(type="text", text=await call_tri(["refactor", file]))]

# ═══════════════════════════════════════════════════════════════════════════════
# DEVELOPMENT - VIBEE (5 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_gen(arguments: dict) -> list[TextContent]:
    """Compile VIBEE spec to Zig/Verilog - REQUIRES CONFIRMATION (writes files)"""
    # Security policy check - this tool writes to filesystem
    decision = await check_security_policy("tri_gen", arguments)
    if decision and not decision.allowed:
        return policy_denied_response(decision)

    spec = arguments.get("spec", "")
    args = ["gen"] + ([spec] if spec else [])
    return [TextContent(type="text", text=await call_tri(args))]

@app.call_tool()
async def tri_convert(arguments: dict) -> list[TextContent]:
    """Convert between formats"""
    args = ["convert"] + (arguments.get("args", "").split() if arguments.get("args") else [])
    return [TextContent(type="text", text=await call_tri(args))]

@app.call_tool()
async def tri_serve(arguments: dict) -> list[TextContent]:
    """Start HTTP server"""
    port = arguments.get("port", "8080")
    return [TextContent(type="text", text=await call_tri(["serve", "--port", str(port)]))]

@app.call_tool()
async def tri_bench_vibee(arguments: dict) -> list[TextContent]:
    """Run VIBEE benchmarks"""
    return [TextContent(type="text", text=await call_tri(["bench"]))]

@app.call_tool()
async def tri_evolve(arguments: dict) -> list[TextContent]:
    """Self-improvement cycle"""
    return [TextContent(type="text", text=await call_tri(["evolve"]))]

# ═══════════════════════════════════════════════════════════════════════════════
# DEVELOPMENT - Pipeline (6 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_pipeline(arguments: dict) -> list[TextContent]:
    """Run Golden Chain pipeline"""
    task = arguments.get("task", "")
    args = ["pipeline", "run"] + ([task] if task else [])
    return [TextContent(type="text", text=await call_tri(args))]

@app.call_tool()
async def tri_decompose(arguments: dict) -> list[TextContent]:
    """Break task into sub-tasks"""
    task = arguments.get("task", "")
    return [TextContent(type="text", text=await call_tri(["decompose", task]))]

@app.call_tool()
async def tri_plan_dev(arguments: dict) -> list[TextContent]:
    """Generate implementation plan"""
    task = arguments.get("task", "")
    return [TextContent(type="text", text=await call_tri(["plan", task]))]

@app.call_tool()
async def tri_verify(arguments: dict) -> list[TextContent]:
    """Run tests + benchmarks"""
    return [TextContent(type="text", text=await call_tri(["verify"]))]

@app.call_tool()
async def tri_verdict(arguments: dict) -> list[TextContent]:
    """Generate toxic verdict"""
    return [TextContent(type="text", text=await call_tri(["verdict"]))]

@app.call_tool()
async def tri_spec_create(arguments: dict) -> list[TextContent]:
    """Create .vibee spec template"""
    name = arguments.get("name", "")
    return [TextContent(type="text", text=await call_tri(["spec-create", name]))]

# ═══════════════════════════════════════════════════════════════════════════════
# DEVELOPMENT - Utilities (6 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_analyze(arguments: dict) -> list[TextContent]:
    """Analyze codebase structure"""
    return [TextContent(type="text", text=await call_tri(["analyze"]))]

@app.call_tool()
async def tri_search(arguments: dict) -> list[TextContent]:
    """Search codebase"""
    query = arguments.get("query", "")
    return [TextContent(type="text", text=await call_tri(["search", query]))]

@app.call_tool()
async def tri_fmt(arguments: dict) -> list[TextContent]:
    """Format code"""
    path = arguments.get("path", "")
    return [TextContent(type="text", text=await call_tri(["fmt", path]))]

@app.call_tool()
async def tri_research(arguments: dict) -> list[TextContent]:
    """Research mode"""
    topic = arguments.get("topic", "")
    return [TextContent(type="text", text=await call_tri(["research", topic]))]

@app.call_tool()
async def tri_build_dev(arguments: dict) -> list[TextContent]:
    """Build project"""
    target = arguments.get("target", "")
    return [TextContent(type="text", text=await call_tri(["build", target]))]

@app.call_tool()
async def tri_deck(arguments: dict) -> list[TextContent]:
    """Generate flash deck"""
    name = arguments.get("name", "")
    return [TextContent(type="text", text=await call_tri(["deck", name]))]

# ═══════════════════════════════════════════════════════════════════════════════
# GIT (5 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_status(arguments: dict) -> list[TextContent]:
    """Git status --short"""
    return [TextContent(type="text", text=await call_tri(["status"]))]

@app.call_tool()
async def tri_st(arguments: dict) -> list[TextContent]:
    """Git status --short (alias)"""
    return [TextContent(type="text", text=await call_tri(["st"]))]

@app.call_tool()
async def tri_diff(arguments: dict) -> list[TextContent]:
    """Git diff"""
    return [TextContent(type="text", text=await call_tri(["diff"]))]

@app.call_tool()
async def tri_log(arguments: dict) -> list[TextContent]:
    """Git log --oneline -10"""
    return [TextContent(type="text", text=await call_tri(["log"]))]

@app.call_tool()
async def tri_commit_git(arguments: dict) -> list[TextContent]:
    """Git add -A && commit - REQUIRES CONFIRMATION (modifies repo)"""
    # Security policy check - this tool modifies git repository
    decision = await check_security_policy("tri_commit_git", arguments)
    if decision and not decision.allowed:
        return policy_denied_response(decision)

    message = arguments.get("message", "Update")
    return [TextContent(type="text", text=await call_tri(["commit", message]))]

# ═══════════════════════════════════════════════════════════════════════════════
# SYSTEM (15 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_info(arguments: dict) -> list[TextContent]:
    """System information"""
    import platform
    return [TextContent(type="text", text=json.dumps({
        "system": platform.system(), "machine": platform.machine(),
        "python": platform.python_version(), "processor": platform.processor()
    }))]

@app.call_tool()
async def tri_version(arguments: dict) -> list[TextContent]:
    """Show version"""
    return [TextContent(type="text", text=await call_tri(["version"]))]

@app.call_tool()
async def tri_v(arguments: dict) -> list[TextContent]:
    """Show version (alias)"""
    return [TextContent(type="text", text=await call_tri(["v"]))]

@app.call_tool()
async def tri_deps(arguments: dict) -> list[TextContent]:
    """Show dependencies"""
    return [TextContent(type="text", text=await call_tri(["deps"]))]

@app.call_tool()
async def tri_clean(arguments: dict) -> list[TextContent]:
    """Clean build artifacts - REQUIRES CONFIRMATION (deletes files)"""
    # Security policy check - this tool deletes files
    decision = await check_security_policy("tri_clean", arguments)
    if decision and not decision.allowed:
        return policy_denied_response(decision)

    return [TextContent(type="text", text=await call_tri(["clean"]))]

@app.call_tool()
async def tri_stats(arguments: dict) -> list[TextContent]:
    """Code statistics"""
    return [TextContent(type="text", text=await call_tri(["stats"]))]

@app.call_tool()
async def tri_doctor(arguments: dict) -> list[TextContent]:
    """System health check"""
    return [TextContent(type="text", text=await call_tri(["doctor"]))]

@app.call_tool()
async def tri_install(arguments: dict) -> list[TextContent]:
    """Install dependencies"""
    return [TextContent(type="text", text=await call_tri(["install"]))]

@app.call_tool()
async def tri_completion(arguments: dict) -> list[TextContent]:
    """Shell completion scripts"""
    shell = arguments.get("shell", "bash")
    return [TextContent(type="text", text=await call_tri(["completion", shell]))]

@app.call_tool()
async def tri_help(arguments: dict) -> list[TextContent]:
    """Help system"""
    return [TextContent(type="text", text=await call_tri(["help"]))]

@app.call_tool()
async def tri_h(arguments: dict) -> list[TextContent]:
    """Help (alias)"""
    return [TextContent(type="text", text=await call_tri(["h"]))]

@app.call_tool()
async def tri_questionmark(arguments: dict) -> list[TextContent]:
    """Help (alias)"""
    return [TextContent(type="text", text=await call_tri(["?"]))]

@app.call_tool()
async def tri_env(arguments: dict) -> list[TextContent]:
    """Show environment variables"""
    return [TextContent(type="text", text=await call_tri(["env"]))]

# ═══════════════════════════════════════════════════════════════════════════════
# IDENTITY & GOVERNANCE (3 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_identity(arguments: dict) -> list[TextContent]:
    """Sacred identity system"""
    subcommand = arguments.get("subcommand", "show")
    return [TextContent(type="text", text=await call_tri(["identity", subcommand]))]

@app.call_tool()
async def tri_swarm(arguments: dict) -> list[TextContent]:
    """Sacred swarm intelligence"""
    subcommand = arguments.get("subcommand", "status")
    return [TextContent(type="text", text=await call_tri(["swarm", subcommand]))]

@app.call_tool()
async def tri_govern(arguments: dict) -> list[TextContent]:
    """Sacred governance"""
    subcommand = arguments.get("subcommand", "show")
    return [TextContent(type="text", text=await call_tri(["govern", subcommand]))]

# ═══════════════════════════════════════════════════════════════════════════════
# NEEDLE (3 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_needle(arguments: dict) -> list[TextContent]:
    """Structural editor core"""
    args = ["needle"]
    if file := arguments.get("file"):
        args.append(file)
    return [TextContent(type="text", text=await call_tri(args))]

@app.call_tool()
async def tri_needle_search(arguments: dict) -> list[TextContent]:
    """Needle search"""
    pattern = arguments.get("pattern", "")
    return [TextContent(type="text", text=await call_tri(["needle-search", pattern]))]

@app.call_tool()
async def tri_needle_check(arguments: dict) -> list[TextContent]:
    """Code quality check"""
    file = arguments.get("file", "")
    return [TextContent(type="text", text=await call_tri(["needle-check", file]))]

# ═══════════════════════════════════════════════════════════════════════════════
# MESH NETWORK (3 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_mesh_status(arguments: dict) -> list[TextContent]:
    """Mesh network status"""
    return [TextContent(type="text", text=await call_tri(["mesh", "status"]))]

@app.call_tool()
async def tri_mesh_topology(arguments: dict) -> list[TextContent]:
    """Mesh network topology"""
    return [TextContent(type="text", text=await call_tri(["mesh", "topology"]))]

@app.call_tool()
async def tri_mesh_regions(arguments: dict) -> list[TextContent]:
    """Mesh network regions"""
    return [TextContent(type="text", text=await call_tri(["mesh", "regions"]))]

# ═══════════════════════════════════════════════════════════════════════════════
# OMEGA ECONOMY (3 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_omega_status(arguments: dict) -> list[TextContent]:
    """Omega phase status"""
    return [TextContent(type="text", text=await call_tri(["omega", "status"]))]

@app.call_tool()
async def tri_omega_rewards(arguments: dict) -> list[TextContent]:
    """Rewards pool information"""
    return [TextContent(type="text", text=await call_tri(["omega", "rewards"]))]

@app.call_tool()
async def tri_omega_reputation(arguments: dict) -> list[TextContent]:
    """Reputation score"""
    return [TextContent(type="text", text=await call_tri(["omega", "reputation"]))]

# ═══════════════════════════════════════════════════════════════════════════════
# WALLET (3 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_wallet_balance(arguments: dict) -> list[TextContent]:
    """Wallet balance"""
    address = arguments.get("address", "")
    return [TextContent(type="text", text=await call_tri(["wallet", "balance", address]))]

@app.call_tool()
async def tri_wallet_claim(arguments: dict) -> list[TextContent]:
    """Claim rewards"""
    amount = arguments.get("amount", "")
    return [TextContent(type="text", text=await call_tri(["wallet", "claim", amount]))]

@app.call_tool()
async def tri_wallet_history(arguments: dict) -> list[TextContent]:
    """Claim history"""
    return [TextContent(type="text", text=await call_tri(["wallet", "history"]))]

# ═══════════════════════════════════════════════════════════════════════════════
# DASHBOARD (3 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_dashboard_serve(arguments: dict) -> list[TextContent]:
    """Start dashboard server"""
    port = arguments.get("port", "3000")
    return [TextContent(type="text", text=await call_tri(["dashboard", "serve", "--port", str(port)]))]

@app.call_tool()
async def tri_dashboard_metrics(arguments: dict) -> list[TextContent]:
    """Dashboard metrics"""
    return [TextContent(type="text", text=await call_tri(["dashboard", "metrics"]))]

@app.call_tool()
async def tri_dashboard_nodes(arguments: dict) -> list[TextContent]:
    """Connected nodes"""
    return [TextContent(type="text", text=await call_tri(["dashboard", "nodes"]))]

# ═══════════════════════════════════════════════════════════════════════════════
# HARDWARE (2 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_hardware_info(arguments: dict) -> list[TextContent]:
    """Hardware information"""
    return [TextContent(type="text", text=await call_tri(["hardware", "info"]))]

@app.call_tool()
async def tri_hardware_benchmark(arguments: dict) -> list[TextContent]:
    """Run hardware benchmark"""
    return [TextContent(type="text", text=await call_tri(["hardware", "benchmark"]))]

# ═══════════════════════════════════════════════════════════════════════════════
# DEMOS (35 tools) - Individual handlers
# ═══════════════════════════════════════════════════════════════════════════════

DEMO_TYPES = [
    "agents", "context", "rag", "voice", "sandbox", "stream", "vision",
    "finetune", "multimodal", "tooluse", "unified", "auto", "orch",
    "mmo", "memory", "persist", "spawn", "cluster", "worksteal",
    "plugin", "comms", "observe", "consensus", "specexec", "governor",
    "fedlearn", "eventsrc", "capsec", "dtxn", "cache", "contract", "workflow",
    "tvc", "pipeline"
]

# Create individual demo tool handlers
for demo_type in DEMO_TYPES:
    def make_demo_handler(d=demo_type):
        async def handler(arguments: dict) -> list[TextContent]:
            return [TextContent(type="text", text=await call_tri([f"{d}-demo"]))]
        return handler

    handler = make_demo_handler()
    handler.__name__ = f"tri_{demo_type}_demo"
    app.call_tool()(handler)

# ═══════════════════════════════════════════════════════════════════════════════
# BENCHMARKS (33 tools) - Individual handlers
# ═══════════════════════════════════════════════════════════════════════════════

BENCH_TYPES = [
    "agents", "context", "rag", "voice", "sandbox", "stream", "vision",
    "finetune", "multimodal", "tooluse", "unified", "auto", "orch",
    "mmo", "memory", "persist", "spawn", "cluster", "worksteal",
    "plugin", "comms", "observe", "consensus", "specexec", "governor",
    "fedlearn", "eventsrc", "capsec", "dtxn", "cache", "contract", "workflow"
]

# Create individual benchmark tool handlers
for bench_type in BENCH_TYPES:
    def make_bench_handler(b=bench_type):
        async def handler(arguments: dict) -> list[TextContent]:
            return [TextContent(type="text", text=await call_tri([f"{b}-bench"]))]
        return handler

    handler = make_bench_handler()
    handler.__name__ = f"tri_{bench_type}_bench"
    app.call_tool()(handler)

# ═══════════════════════════════════════════════════════════════════════════════
# ADVANCED (10 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_distributed(arguments: dict) -> list[TextContent]:
    """Distributed inference"""
    return [TextContent(type="text", text=await call_tri(["distributed"]))]

@app.call_tool()
async def tri_multi_cluster(arguments: dict) -> list[TextContent]:
    """Multi-cluster orchestration"""
    return [TextContent(type="text", text=await call_tri(["multi-cluster"]))]

@app.call_tool()
async def tri_launch(arguments: dict) -> list[TextContent]:
    """Launch TRINITY OS"""
    return [TextContent(type="text", text=await call_tri(["launch"]))]

@app.call_tool()
async def tri_time(arguments: dict) -> list[TextContent]:
    """Temporal engine"""
    return [TextContent(type="text", text=await call_tri(["time"]))]

@app.call_tool()
async def tri_deploy(arguments: dict) -> list[TextContent]:
    """Deploy to fly.io"""
    return [TextContent(type="text", text=await call_tri(["deploy"]))]

@app.call_tool()
async def tri_publish(arguments: dict) -> list[TextContent]:
    """Publish results"""
    return [TextContent(type="text", text=await call_tri(["publish"]))]

@app.call_tool()
async def tri_distributed_learn(arguments: dict) -> list[TextContent]:
    """Distributed learning"""
    return [TextContent(type="text", text=await call_tri(["distributed-learn"]))]

@app.call_tool()
async def tri_orchestrate(arguments: dict) -> list[TextContent]:
    """Advanced orchestration"""
    return [TextContent(type="text", text=await call_tri(["orchestrate"]))]

@app.call_tool()
async def tri_swarm_compute(arguments: dict) -> list[TextContent]:
    """Swarm computing"""
    nodes = arguments.get("nodes", "7")
    return [TextContent(type="text", text=await call_tri(["swarm-compute", nodes]))]

@app.call_tool()
async def tri_graceful_shutdown(arguments: dict) -> list[TextContent]:
    """Graceful shutdown"""
    return [TextContent(type="text", text=await call_tri(["graceful-shutdown"]))]

# ═══════════════════════════════════════════════════════════════════════════════
# DEPIN - Additional (4 tools)
# ═══════════════════════════════════════════════════════════════════════════════

@app.call_tool()
async def tri_reputation(arguments: dict) -> list[TextContent]:
    """Reputation system"""
    return [TextContent(type="text", text=await call_tri(["reputation"]))]

@app.call_tool()
async def tri_rep(arguments: dict) -> list[TextContent]:
    """Reputation system (alias)"""
    return [TextContent(type="text", text=await call_tri(["rep"]))]

@app.call_tool()
async def tri_hardware_deploy(arguments: dict) -> list[TextContent]:
    """Hardware deployment"""
    return [TextContent(type="text", text=await call_tri(["hardware-deploy"]))]

@app.call_tool()
async def tri_prove(arguments: dict) -> list[TextContent]:
    """Generate proof"""
    return [TextContent(type="text", text=await call_tri(["prove"]))]

# ═══════════════════════════════════════════════════════════════════════════════
# MISSING TRI CLI COMMANDS (11 tools) - 100% Coverage
# ═══════════════════════════════════════════════════════════════════════════════
# Note: tri_conscious, tri_sacred_full_cycle, tri_multi_cluster already exist in earlier sections

@app.call_tool()
async def tri_fpga(arguments: dict) -> list[TextContent]:
    """FPGA toolchain: synth, route, bitstream, flash for Xilinx 7-series - REQUIRES CONFIRMATION (hardware)"""
    # Security policy check - this tool interacts with hardware
    decision = await check_security_policy("tri_fpga", arguments)
    if decision and not decision.allowed:
        return policy_denied_response(decision)

    subcommand = arguments.get("subcommand", "")
    args = ["fpga"] + ([subcommand] if subcommand else [])
    return [TextContent(type="text", text=await call_tri(args))]

@app.call_tool()
async def tri_fpga_demo(arguments: dict) -> list[TextContent]:
    """FPGA demonstration - LED blink, ternary dot product on hardware"""
    return [TextContent(type="text", text=await call_tri(["fpga-demo"]))]

@app.call_tool()
async def tri_omega_evolve(arguments: dict) -> list[TextContent]:
    """Omega evolution - autonomous improvement cycle with φ-based metrics"""
    return [TextContent(type="text", text=await call_tri(["omega-evolve"]))]

@app.call_tool()
async def tri_holo_cmd(arguments: dict) -> list[TextContent]:
    """Holographic command interface - 3D visualization of sacred geometry"""
    return [TextContent(type="text", text=await call_tri(["holo-cmd"]))]

@app.call_tool()
async def tri_forge_bench(arguments: dict) -> list[TextContent]:
    """FORGE benchmarks - synthesis and routing performance metrics"""
    return [TextContent(type="text", text=await call_tri(["forge-bench"]))]

@app.call_tool()
async def tri_forge_verdict(arguments: dict) -> list[TextContent]:
    """FORGE verdict - quality assessment for FPGA toolchain output"""
    return [TextContent(type="text", text=await call_tri(["forge-verdict"]))]

@app.call_tool()
async def tri_test_repl(arguments: dict) -> list[TextContent]:
    """Interactive test REPL - run tests in read-eval-print loop"""
    return [TextContent(type="text", text=await call_tri(["test-repl"]))]

@app.call_tool()
async def tri_all_cmd(arguments: dict) -> list[TextContent]:
    """Execute all TRI CLI commands - comprehensive system test"""
    return [TextContent(type="text", text=await call_tri(["all-cmd"]))]

@app.call_tool()
async def tri_release_cosmic(arguments: dict) -> list[TextContent]:
    """Cosmic energy release - φ-based energy distribution"""
    return [TextContent(type="text", text=await call_tri(["release-cosmic"]))]

@app.call_tool()
async def tri_release_absolute(arguments: dict) -> list[TextContent]:
    """Absolute energy release - maximum sacred energy output"""
    return [TextContent(type="text", text=await call_tri(["release-absolute"]))]

@app.call_tool()
async def tri_omega_cmd(arguments: dict) -> list[TextContent]:
    """Omega phase commands - advanced economic and reward operations"""
    return [TextContent(type="text", text=await call_tri(["omega-cmd"]))]

# ═══════════════════════════════════════════════════════════════════════════════
# LIST ALL TOOLS
# ═══════════════════════════════════════════════════════════════════════════════

@app.list_tools()
async def list_tools() -> list[Tool]:
    """List all 203 TRI CLI tools with enhanced descriptions"""
    tools = []

    # Sacred Math (8)
    tools.extend([
        tool_template("tri_constants",
            "Display sacred mathematical constants: golden ratio φ, π, e, Lucas numbers, and Fibonacci sequence. Used in all sacred calculations.",
            {"type":"object","description":"Returns JSON with phi, pi, e, lucas, fibonacci arrays"}),
        tool_template("tri_phi",
            "Compute φⁿ (phi to the power of n) for any integer n. The golden ratio is fundamental to sacred mathematics.",
            {"type":"object","properties":{"n":{"type":"integer","description":"Exponent value (default: 1)"}},"description":"Returns phi^n as float"}),
        tool_template("tri_fib",
            "Calculate the n-th Fibonacci number using BigInt. The sequence 0,1,1,2,3,5,8... appears throughout sacred geometry.",
            {"type":"object","properties":{"n":{"type":"integer","description":"Position in Fibonacci sequence (default: 10)"}},"description":"Returns the n-th Fibonacci number"}),
        tool_template("tri_lucas",
            "Calculate Lucas L(n) where L(2)=3=TRINITY. Lucas numbers are closely related to Fibonacci: 2,1,3,4,7,11,18...",
            {"type":"object","properties":{"n":{"type":"integer","description":"Position in Lucas sequence (default: 2)"}},"description":"Returns the n-th Lucas number with trinity note"}),
        tool_template("tri_spiral",
            "Generate φ-spiral coordinates for visualization. The golden spiral appears in nature, art, and sacred architecture.",
            {"type":"object","properties":{"points":{"type":"integer","description":"Number of spiral points (default: 100)"}},"description":"Returns array of {x,y} coordinates"}),
        tool_template("tri_formula",
            "Sacred formula evaluator supporting PHI, PI, and E constants. Evaluate expressions like 'PHI**2 + 1/PHI**2'.",
            {"type":"object","properties":{"expr":{"type":"string","description":"Mathematical expression using PHI, PI, E (default: PHI**2)"}},"description":"Returns evaluated result"}),
        tool_template("tri_math",
            "Sacred mathematics dispatcher for accessing all math-related subcommands and constants.",
            {"type":"object","properties":{"subcommand":{"type":"string","description":"Math subcommand to run"}},"description":"Routes to specific math operations"}),
        tool_template("tri_sacred",
            "Display core sacred constants including φ², 1/φ², and the TRINITY identity (φ² + 1/φ² = 3).",
            {"type":"object","description":"Returns JSON with sacred constant values"}),
    ])

    # Quantum (3)
    tools.extend([
        tool_template("tri_quantum_constants",
            "Display sacred quantum constants: φ, Planck constant h, reduced hbar, and fine-structure constant α.",
            {"type":"object","description":"Returns JSON with quantum constant values"}),
        tool_template("tri_quantum_states",
            "Show quantum basis states including |0>, |1>, |+>, |->, and the sacred |φ> state defined using golden ratio.",
            {"type":"object","description":"Returns JSON array of quantum state vectors"}),
        tool_template("tri_bell_states",
            "Display the four Bell states (|Φ+>, |Φ->, |Ψ+>, |Ψ->) used in quantum entanglement and teleportation.",
            {"type":"object","description":"Returns JSON list of Bell state definitions"}),
    ])

    # Gematria (1)
    tools.append(tool_template("tri_gematria",
        "Calculate gematria (numerical value) of text using letter-to-number mapping. Used in sacred text analysis.",
        {"type":"object","properties":{"text":{"type":"string","description":"Text to calculate gematria value for"}},"description":"Returns total gematria value as integer"}))

    # Chemistry (5)
    tools.extend([
        tool_template("tri_chem_periodic",
            "Display ASCII periodic table of all 118 elements with atomic numbers and sacred properties.",
            {"type":"object","description":"Returns periodic table as formatted text"}),
        tool_template("tri_chem_element",
            "Show detailed element information card by symbol or atomic number including electron configuration.",
            {"type":"object","properties":{"element":{"type":"string","description":"Element symbol (e.g., 'Au') or atomic number"}},"description":"Returns element properties and sacred associations"}),
        tool_template("tri_chem_mass",
            "Calculate molar mass of a chemical formula. Essential for stoichiometry and sacred chemistry.",
            {"type":"object","properties":{"formula":{"type":"string","description":"Chemical formula (e.g., 'H2O', 'CO2')"}},"description":"Returns molar mass in g/mol"}),
        tool_template("tri_chem_formula",
            "Analyze chemical formula composition showing element counts and molecular structure.",
            {"type":"object","properties":{"formula":{"type":"string","description":"Chemical formula to analyze"}},"description":"Returns breakdown of elements and counts"}),
        tool_template("tri_chem_moles",
            "Calculate moles, molecules, or atoms from a given mass and formula using Avogadro's number.",
            {"type":"object","properties":{"mass":{"type":"number","description":"Mass in grams"},"formula":{"type":"string","description":"Chemical formula"}},"description":"Returns moles, molecules, atoms counts"}),
    ])

    # Biology (4)
    tools.extend([
        tool_template("tri_bio_dna",
            "Analyze DNA sequence with sacred mathematics: GC content, codon usage, φ-patterns in genetic code.",
            {"type":"object","properties":{"sequence":{"type":"string","description":"DNA sequence (A,C,G,T)"}},"description":"Returns GC content, length, and sacred analysis"}),
        tool_template("tri_bio_codon",
            "Look up codon to amino acid translation using standard genetic code with sacred interpretation.",
            {"type":"object","properties":{"codon":{"type":"string","description":"3-letter codon (e.g., 'ATG', 'GGC')"}},"description":"Returns amino acid and properties"}),
        tool_template("tri_bio_protein",
            "Analyze protein sequence with φ-spiral encoding and sacred structure prediction.",
            {"type":"object","properties":{"sequence":{"type":"string","description":"Protein sequence (amino acids)"}},"description":"Returns protein analysis with sacred patterns"}),
        tool_template("tri_bio",
            "Biology v14.0 dispatcher for DNA/RNA/Protein sacred analysis. Access all biological subcommands.",
            {"type":"object","properties":{"subcommand":{"type":"string","description":"Biology subcommand (dna, rna, protein, codon)"}},"description":"Routes to specific biology tools"}),
    ])

    # Cosmology (3)
    tools.extend([
        tool_template("tri_cosmos_hubble",
            "Sacred cosmology: Hubble tension resolution using φ. The expansion rate relates to golden ratio.",
            {"type":"object","description":"Returns Hubble constant with φ-based interpretation"}),
        tool_template("tri_cosmos_dark",
            "Dark energy π-patterns in universe expansion. Dark energy ratio ~ φ⁸×π⁴.",
            {"type":"object","description":"Returns dark energy and dark matter percentages"}),
        tool_template("tri_cosmos",
            "Cosmology v15.0 dispatcher: universe through φ - Hubble, dark energy, cosmic evolution.",
            {"type":"object","properties":{"subcommand":{"type":"string","description":"Cosmology subcommand"}},"description":"Routes to cosmology tools"}),
    ])

    # Physics/Particles (2)
    tools.extend([
        tool_template("tri_particles",
            "Particle physics sacred formulas: Standard Model particles with φ-based mass relationships.",
            {"type":"object","description":"Returns particle data with sacred interpretations"}),
        tool_template("tri_pdg",
            "Particle Data Group reference lookup for official particle properties and measurements.",
            {"type":"object","properties":{"particle":{"type":"string","description":"Particle name or PDG ID"}},"description":"Returns PDG data for the particle"}),
    ])

    # Music/Audio (15)
    tools.extend([
        tool_template("tri_frequency",
            "Calculate frequency (Hz) from musical note. A4 = 440Hz standard tuning with φ-harmonics.",
            {"type":"object","properties":{"note":{"type":"string","description":"Note (e.g., 'A4', 'C#5', 'Bb3')"}},"description":"Returns frequency in Hz"}),
        tool_template("tri_freq",
            "Alias for tri_frequency - calculate note frequency with φ-based harmonics.",
            {"type":"object","properties":{"note":{"type":"string","description":"Musical note"}},"description":"Returns frequency in Hz"}),
        tool_template("tri_scale",
            "Display musical scale notes and frequencies using φ-based temperament.",
            {"type":"object","description":"Returns scale notes with frequencies"}),
        tool_template("tri_chord",
            "Analyze chord harmonics and sacred ratios. Major chords relate to φ (3:2:1 ratios).",
            {"type":"object","properties":{"notes":{"type":"string","description":"Chord notes (e.g., 'C E G', 'A C# E')"}},"description":"Returns harmonic analysis"}),
        tool_template("tri_resonance",
            "Calculate resonance patterns between frequencies. Sacred resonance occurs at φ-ratios.",
            {"type":"object","properties":{"freq":{"type":"number","description":"Base frequency in Hz"}},"description":"Returns harmonic resonance points"}),
        tool_template("tri_res",
            "Alias for tri_resonance - calculate φ-based resonance patterns.",
            {"type":"object","properties":{"freq":{"type":"number","description":"Frequency in Hz"}},"description":"Returns resonance analysis"}),
        tool_template("tri_waveform",
            "Generate waveform samples (sine, square, sawtooth, triangle) for sacred sound synthesis.",
            {"type":"object","properties":{"wave":{"type":"string","description":"Waveform type: sine, square, sawtooth, triangle"}},"description":"Returns array of sample values"}),
        tool_template("tri_wave",
            "Alias for tri_waveform - generate audio waveform samples.",
            {"type":"object","properties":{"wave":{"type":"string","description":"Waveform type"}},"description":"Returns waveform samples"}),
        tool_template("tri_osc",
            "Generate oscillator waveform for sacred music and sound synthesis.",
            {"type":"object","properties":{"wave":{"type":"string","description":"Oscillator type"}},"description":"Returns oscillator output"}),
        tool_template("tri_harmony",
            "Analyze harmonic relationship between two frequencies using φ-based music theory.",
            {"type":"object","properties":{"freq1":{"type":"number","description":"First frequency (Hz)"},"freq2":{"type":"number","description":"Second frequency (Hz)"}},"description":"Returns harmonic ratio and consonance"}),
        tool_template("tri_phi_series",
            "Display φ frequency series - sacred scale based on golden ratio harmonics.",
            {"type":"object","description":"Returns φ-based frequency scale"}),
        tool_template("tri_phi_freq",
            "Alias for tri_phi_series - show golden ratio frequency progression.",
            {"type":"object","description":"Returns φ frequency scale"}),
        tool_template("tri_music",
            "Sacred Music v1.0 dispatcher - φ-based acoustics, scales, chords, resonance.",
            {"type":"object","properties":{"subcommand":{"type":"string","description":"Music subcommand"}},"description":"Routes to music tools"}),
        tool_template("tri_audio",
            "Alias for tri_music - access sacred music and audio analysis tools.",
            {"type":"object","properties":{"subcommand":{"type":"string","description":"Audio subcommand"}},"description":"Routes to audio tools"}),
        tool_template("tri_sound",
            "Alias for tri_music - sacred sound synthesis and analysis.",
            {"type":"object","properties":{"subcommand":{"type":"string","description":"Sound subcommand"}},"description":"Routes to sound tools"}),
    ])

    # Neuroscience/Consciousness (6)
    tools.extend([
        tool_template("tri_neuro",
            "Neuroscience v16.0 - brain as sacred computer. Neural 56Hz, consciousness threshold C_thr=φ⁻¹.",
            {"type":"object","properties":{"subcommand":{"type":"string","description":"Neuro subcommand (gamma, neural, waves)"}},"description":"Routes to neuroscience tools"}),
        tool_template("tri_neuroscience",
            "Alias for tri_neuro - sacred brain science and neural analysis.",
            {"type":"object","properties":{"subcommand":{"type":"string","description":"Neuroscience subcommand"}},"description":"Routes to neuro tools"}),
        tool_template("tri_conscious",
            "Consciousness simulator integrating IIT, GWT, OrchOR, qutrits, and Active Inference frameworks.",
            {"type":"object","description":"Returns consciousness model output"}),
        tool_template("tri_consciousness",
            "Alias for tri_conscious - run consciousness simulation and analysis.",
            {"type":"object","description":"Returns consciousness model results"}),
        tool_template("tri_sacred_full_cycle",
            "Calculate sacred full cycle - complete φ-based cycle analysis for patterns.",
            {"type":"object","description":"Returns full cycle analysis"}),
        tool_template("tri_quantum",
            "Quantum Trinity - unified quantum model with sacred mathematics integration.",
            {"type":"object","description":"Returns quantum Trinity model data"}),
    ])

    # String Theory (11)
    tools.extend([
        tool_template("tri_string_e8_lattice",
            "Generate E8 lattice with 240 root vectors - the most symmetric structure in string theory.",
            {"type":"object","description":"Returns E8 lattice root vectors"}),
        tool_template("tri_string_compactify",
            "Compactify 11D→4D using φ. String theory requires extra dimensions - we collapse them using golden ratio.",
            {"type":"object","properties":{"dim":{"type":"integer","description":"Dimensions to compactify (default: 7)"}},"description":"Returns compactified geometry"}),
        tool_template("tri_string_dualities",
            "Show S/T/U dualities with φ. Different string theories are mathematically equivalent.",
            {"type":"object","properties":{"duality":{"type":"string","description":"Duality type: S, T, or U"}},"description":"Returns duality mapping"}),
        tool_template("tri_string_spectrum",
            "String vibrational spectrum - different vibration modes create different particles.",
            {"type":"object","properties":{"type":{"type":"string","description":"String type: bosonic, fermionic, superstring"}},"description":"Returns vibrational spectrum"}),
        tool_template("tri_string_manifold",
            "Calabi-Yau manifold data - extra dimensions are curled up in these complex shapes.",
            {"type":"object","properties":{"manifold":{"type":"string","description":"Manifold: quintic, septic, etc."}},"description":"Returns manifold properties"}),
        tool_template("tri_string_gamma",
            "E8-γ deformation with φ⁻³. Break E8 symmetry using golden ratio parameter.",
            {"type":"object","properties":{"value":{"type":"string","description":"Deformation value (default: φ⁻³)"}},"description":"Returns deformed algebra data"}),
        tool_template("tri_string_tension",
            "String tension from φ: T = φ⁵/(2π) ≈ 2.089. Determines string energy scale.",
            {"type":"object","description":"Returns string tension value"}),
        tool_template("tri_string_dilaton",
            "Dilaton VEV = φ⁻¹ ≈ 0.618. Dilaton field determines string coupling strength.",
            {"type":"object","description":"Returns dilaton vacuum expectation"}),
        tool_template("tri_string_moduli",
            "Calabi-Yau moduli from φ - shape parameters of extra dimensions stabilized by sacred math.",
            {"type":"object","description":"Returns moduli stabilization data"}),
        tool_template("tri_string_landscape",
            "String landscape with φ scaling - vast number of possible universes.",
            {"type":"object","description":"Returns landscape analysis"}),
        tool_template("tri_string_vacuum",
            "Flux vacuum count estimation - how many stable configurations exist in string theory.",
            {"type":"object","description":"Returns vacuum count estimate"}),
    ])

    # AI & Chat (5)
    tools.extend([
        tool_template("tri_chat",
            "Interactive chat with vision, voice, and tools support. Claude-style AI assistant interface.",
            {"type":"object","properties":{"message":{"type":"string","description":"Message to send to chat"}},"description":"Returns AI response text"}),
        tool_template("tri_code_ai",
            "AI code generation with typing effect. Generates code from natural language prompts.",
            {"type":"object","properties":{"prompt":{"type":"string","description":"Code description in natural language"}},"description":"Returns generated code with typing animation"}),
        tool_template("tri_reason",
            "Chain-of-thought reasoning - step-by-step logical analysis for complex problems.",
            {"type":"object","properties":{"prompt":{"type":"string","description":"Problem or question to reason about"}},"description":"Returns reasoning process and conclusion"}),
        tool_template("tri_igla",
            "IGLA hybrid chat - combines multiple AI models for enhanced responses.",
            {"type":"object","properties":{"message":{"type":"string","description":"Message for IGLA chat"}},"description":"Returns IGLA response"}),
        tool_template("tri_math_agent",
            "Math agent - specializes in mathematical problem solving and symbolic computation.",
            {"type":"object","properties":{"problem":{"type":"string","description":"Math problem to solve"}},"description":"Returns solution with steps"}),
    ])

    # SWE Agent (5)
    tools.extend([
        tool_template("tri_fix",
            "Detect and fix bugs in code automatically. Uses AI to identify and repair issues.",
            {"type":"object","properties":{"file":{"type":"string","description":"Path to file to fix"}},"description":"Returns fixed code with diff"}),
        tool_template("tri_explain",
            "Explain code or concept in detail. Provides clear breakdown of functionality.",
            {"type":"object","properties":{"target":{"type":"string","description":"Code file or concept to explain"}},"description":"Returns detailed explanation"}),
        tool_template("tri_test",
            "Generate tests for code automatically. Creates unit tests with assertions.",
            {"type":"object","properties":{"file":{"type":"string","description":"Path to file to test"}},"description":"Returns generated test code"}),
        tool_template("tri_doc",
            "Generate documentation from code. Creates docstrings and comments.",
            {"type":"object","properties":{"file":{"type":"string","description":"Path to file to document"}},"description":"Returns generated documentation"}),
        tool_template("tri_refactor",
            "Suggest refactoring improvements for code quality and maintainability.",
            {"type":"object","properties":{"file":{"type":"string","description":"Path to file to refactor"}},"description":"Returns refactored code suggestions"}),
    ])

    # VIBEE (5)
    tools.extend([
        tool_template("tri_gen",
            "Compile VIBEE spec to Zig/Verilog code. Transforms .vibee specifications into working code.",
            {"type":"object","properties":{"spec":{"type":"string","description":"Path to .vibee specification file"}},"description":"Returns generated code file path"}),
        tool_template("tri_convert",
            "Convert between formats - transforms code, data, or specifications between languages.",
            {"type":"object","properties":{"args":{"type":"string","description":"Conversion arguments"}},"description":"Returns conversion result"}),
        tool_template("tri_serve",
            "Start HTTP server with OpenAI-compatible API. Supports GGUF models and embeddings.",
            {"type":"object","properties":{"port":{"type":"integer","description":"Port number (default: 8080)"}},"description":"Returns server info and starts HTTP listener"}),
        tool_template("tri_bench_vibee",
            "Run VIBEE compiler benchmarks to measure code generation performance.",
            {"type":"object","description":"Returns benchmark results"}),
        tool_template("tri_evolve",
            "Self-improvement cycle - VIBEE analyzes and improves its own code generation.",
            {"type":"object","description":"Returns improvement analysis"}),
    ])

    # Pipeline (6)
    tools.extend([
        tool_template("tri_pipeline",
            "Run Golden Chain pipeline - autonomous development cycle with 22 links from spec to deploy.",
            {"type":"object","properties":{"task":{"type":"string","description":"Task description for pipeline"}},"description":"Returns pipeline execution results"}),
        tool_template("tri_decompose",
            "Break task into sub-tasks using AI. Golden Chain Link 4 - task decomposition.",
            {"type":"object","properties":{"task":{"type":"string","description":"Complex task to break down"}},"description":"Returns list of sub-tasks"}),
        tool_template("tri_plan_dev",
            "Generate implementation plan for task. Golden Chain Link 5 - structured planning.",
            {"type":"object","properties":{"task":{"type":"string","description":"Task to plan"}},"description":"Returns implementation plan"}),
        tool_template("tri_verify",
            "Run tests + benchmarks. Golden Chain Links 7-11 - quality validation.",
            {"type":"object","description":"Returns test results and benchmarks"}),
        tool_template("tri_verdict",
            "Generate toxic verdict - Russian self-assessment. Golden Chain Link 14.",
            {"type":"object","description":"Returns critical assessment and tech tree options"}),
        tool_template("tri_spec_create",
            "Create .vibee spec template. Golden Chain Link 6 - spec generation.",
            {"type":"object","properties":{"name":{"type":"string","description":"Module name for spec"}},"description":"Returns created spec file path"}),
    ])

    # Dev utilities (6)
    tools.extend([
        tool_template("tri_analyze",
            "Analyze codebase structure - modules, dependencies, complexity metrics.",
            {"type":"object","description":"Returns codebase analysis report"}),
        tool_template("tri_search",
            "Search codebase using VSA semantic search - finds code by meaning, not just keywords.",
            {"type":"object","properties":{"query":{"type":"string","description":"Natural language query"}},"description":"Returns matching code locations"}),
        tool_template("tri_fmt",
            "Format code using project conventions. Applies auto-formatting to source files.",
            {"type":"object","properties":{"path":{"type":"string","description":"Path to file or directory to format"}},"description":"Returns formatted code status"}),
        tool_template("tri_research",
            "Research mode - idempotency audit, duplication check, and literature review.",
            {"type":"object","properties":{"topic":{"type":"string","description":"Research topic"}},"description":"Returns research findings"}),
        tool_template("tri_build_dev",
            "Build project with specified target. Compiles library and executables.",
            {"type":"object","properties":{"target":{"type":"string","description":"Build target (e.g., 'tri', 'vibee', 'release')"}},"description":"Returns build status"}),
        tool_template("tri_deck",
            "Generate flash deck - spaced repetition cards for learning and review.",
            {"type":"object","properties":{"name":{"type":"string","description":"Deck name/category"}},"description":"Returns generated deck"}),
    ])

    # Git (5)
    tools.extend([
        tool_template("tri_status",
            "Git status --short - show working tree status with abbreviated format.",
            {"type":"object","description":"Returns git status as text"}),
        tool_template("tri_st",
            "Alias for tri_status - show git working tree status.",
            {"type":"object","description":"Returns git status"}),
        tool_template("tri_diff",
            "Git diff - show changes between commits or working tree.",
            {"type":"object","description":"Returns diff output"}),
        tool_template("tri_log",
            "Git log --oneline -10 - show recent commit history.",
            {"type":"object","description":"Returns recent commits"}),
        tool_template("tri_commit_git",
            "Git add -A && commit - stage all changes and create commit with message.",
            {"type":"object","properties":{"message":{"type":"string","description":"Commit message"}},"description":"Returns commit status"}),
    ])

    # System (14)
    tools.extend([
        tool_template("tri_info",
            "System information - OS, architecture, Python version, processor details.",
            {"type":"object","description":"Returns system info as JSON"}),
        tool_template("tri_version",
            "Show version - display TRINITY version number and build info.",
            {"type":"object","description":"Returns version information"}),
        tool_template("tri_v",
            "Alias for tri_version - show version quickly.",
            {"type":"object","description":"Returns version info"}),
        tool_template("tri_deps",
            "Show dependencies - list required packages and their versions.",
            {"type":"object","description":"Returns dependency list"}),
        tool_template("tri_clean",
            "Clean build artifacts - remove zig-cache and compiled files.",
            {"type":"object","description":"Returns clean status"}),
        tool_template("tri_stats",
            "Code statistics - lines of code, file counts, test coverage metrics.",
            {"type":"object","description":"Returns code statistics"}),
        tool_template("tri_doctor",
            "Health check - verify installation and dependencies are correctly configured.",
            {"type":"object","description":"Returns health status and fixes"}),
        tool_template("tri_install",
            "Install dependencies - set up required packages for development.",
            {"type":"object","description":"Returns installation status"}),
        tool_template("tri_completion",
            "Shell completion scripts - generate completion for bash, zsh, fish.",
            {"type":"object","properties":{"shell":{"type":"string","description":"Shell type: bash, zsh, fish (default: bash)"}},"description":"Returns completion script"}),
        tool_template("tri_help",
            "Help system - show all commands by category with descriptions.",
            {"type":"object","description":"Returns help text"}),
        tool_template("tri_h",
            "Alias for tri_help - show command help.",
            {"type":"object","description":"Returns help information"}),
        tool_template("tri_questionmark",
            "Alias for tri_help - quick help access.",
            {"type":"object","description":"Returns help text"}),
        tool_template("tri_env",
            "Show environment variables - display TRINITY configuration and env vars.",
            {"type":"object","description":"Returns environment variables"}),
    ])

    # Identity & Governance (3)
    tools.extend([
        tool_template("tri_identity",
            "Sacred identity system - manage digital identity with cryptographic proofs.",
            {"type":"object","properties":{"subcommand":{"type":"string","description":"Identity subcommand"}},"description":"Returns identity operations"}),
        tool_template("tri_swarm",
            "Sacred swarm intelligence - distributed AI coordination with φ-based consensus.",
            {"type":"object","properties":{"subcommand":{"type":"string","description":"Swarm subcommand"}},"description":"Returns swarm status"}),
        tool_template("tri_govern",
            "Sacred governance - φ-based decision making and collective intelligence.",
            {"type":"object","properties":{"subcommand":{"type":"string","description":"Governance subcommand"}},"description":"Returns governance data"}),
    ])

    # Needle (3)
    tools.extend([
        tool_template("tri_needle",
            "Needle structural editor core - manipulate AST and code structure programmatically.",
            {"type":"object","properties":{"file":{"type":"string","description":"File to edit with Needle"}},"description":"Returns edited code"}),
        tool_template("tri_needle_search",
            "Needle AST search - find code patterns using structural matching, not text.",
            {"type":"object","properties":{"pattern":{"type":"string","description":"Structural pattern to search for"}},"description":"Returns matching code locations"}),
        tool_template("tri_needle_check",
            "Code quality check - analyze code for issues using structural analysis.",
            {"type":"object","properties":{"file":{"type":"string","description":"File to check"}},"description":"Returns quality report"}),
    ])

    # Mesh (3)
    tools.extend([
        tool_template("tri_mesh_status",
            "Mesh network status - show connected nodes, latency, and network health.",
            {"type":"object","description":"Returns mesh network status"}),
        tool_template("tri_mesh_topology",
            "Mesh network topology - display network structure and node relationships.",
            {"type":"object","description":"Returns topology information"}),
        tool_template("tri_mesh_regions",
            "Mesh network regions - show geographic distribution and routing.",
            {"type":"object","description":"Returns regional network data"}),
    ])

    # Omega (3)
    tools.extend([
        tool_template("tri_omega_status",
            "Omega phase status - show economic phase and rewards state.",
            {"type":"object","description":"Returns omega status data"}),
        tool_template("tri_omega_rewards",
            "Rewards pool information - show available rewards and distribution.",
            {"type":"object","description":"Returns rewards pool data"}),
        tool_template("tri_omega_reputation",
            "Reputation score - display node reputation in the network.",
            {"type":"object","description":"Returns reputation metrics"}),
    ])

    # Wallet (3)
    tools.extend([
        tool_template("tri_wallet_balance",
            "Wallet balance - check token balance for specified address.",
            {"type":"object","properties":{"address":{"type":"string","description":"Wallet address to check"}},"description":"Returns balance information"}),
        tool_template("tri_wallet_claim",
            "Claim rewards - withdraw earned rewards to wallet.",
            {"type":"object","properties":{"amount":{"type":"string","description":"Amount to claim"}},"description":"Returns claim transaction status"}),
        tool_template("tri_wallet_history",
            "Claim history - show past reward claims and transactions.",
            {"type":"object","description":"Returns transaction history"}),
    ])

    # Dashboard (3)
    tools.extend([
        tool_template("tri_dashboard_serve",
            "Start dashboard server - launch web interface for monitoring and control.",
            {"type":"object","properties":{"port":{"type":"integer","description":"Port for dashboard (default: 3000)"}},"description":"Starts HTTP dashboard server"}),
        tool_template("tri_dashboard_metrics",
            "Dashboard metrics - show system performance and operational metrics.",
            {"type":"object","description":"Returns metrics data"}),
        tool_template("tri_dashboard_nodes",
            "Connected nodes - list active nodes in the network.",
            {"type":"object","description":"Returns node list with status"}),
    ])

    # Hardware (2)
    tools.extend([
        tool_template("tri_hardware_info",
            "Hardware information - CPU, GPU, memory, and system capabilities.",
            {"type":"object","description":"Returns hardware details"}),
        tool_template("tri_hardware_benchmark",
            "Run hardware benchmark - measure CPU, memory, and inference performance.",
            {"type":"object","description":"Returns benchmark results"}),
    ])

    # Demos (35)
    for demo in DEMO_TYPES:
        tools.append(tool_template(f"tri_{demo}_demo",
            f"Interactive demonstration of {demo.replace('-',' ')} system capabilities.",
            {"type":"object","description":f"Runs {demo} demo and returns results"}))

    # Benchmarks (33)
    for bench in BENCH_TYPES:
        tools.append(tool_template(f"tri_{bench}_bench",
            f"Performance benchmark for {bench.replace('-',' ')} system - measures throughput and latency.",
            {"type":"object","description":f"Runs {bench} benchmark and returns metrics"}))

    # Advanced (10)
    tools.extend([
        tool_template("tri_distributed",
            "Distributed inference - run model inference across multiple nodes.",
            {"type":"object","description":"Returns distributed inference results"}),
        tool_template("tri_multi_cluster",
            "Multi-cluster orchestration - manage multiple compute clusters.",
            {"type":"object","description":"Returns cluster status"}),
        tool_template("tri_launch",
            "Launch TRINITY OS - start the complete operating system environment.",
            {"type":"object","description":"Launches TRINITY OS"}),
        tool_template("tri_time",
            "Temporal engine - manipulate and analyze temporal data streams.",
            {"type":"object","description":"Returns temporal analysis"}),
        tool_template("tri_deploy",
            "Deploy to fly.io - build and deploy application to production.",
            {"type":"object","description":"Returns deployment status"}),
        tool_template("tri_publish",
            "Publish results - share findings and artifacts to community.",
            {"type":"object","description":"Returns publication status"}),
        tool_template("tri_distributed_learn",
            "Distributed learning - train models across multiple nodes.",
            {"type":"object","description":"Returns training progress"}),
        tool_template("tri_orchestrate",
            "Advanced orchestration - coordinate complex multi-step workflows.",
            {"type":"object","description":"Returns orchestration status"}),
        tool_template("tri_swarm_compute",
            "Swarm computing - distribute computation across φ-organized swarm.",
            {"type":"object","properties":{"nodes":{"type":"string","description":"Number of nodes or 'phi'"}},"description":"Returns swarm computation results"}),
        tool_template("tri_graceful_shutdown",
            "Graceful shutdown - safely stop all services with cleanup.",
            {"type":"object","description":"Shuts down system gracefully"}),
    ])

    # DePIN additional (4)
    tools.extend([
        tool_template("tri_reputation",
            "Reputation system - display node reputation scores and history.",
            {"type":"object","description":"Returns reputation metrics"}),
        tool_template("tri_rep",
            "Alias for tri_reputation - quick reputation score lookup.",
            {"type":"object","description":"Returns reputation score"}),
        tool_template("tri_hardware_deploy",
            "Hardware deployment - deploy software to physical infrastructure.",
            {"type":"object","description":"Returns deployment status"}),
        tool_template("tri_prove",
            "Generate proof - create cryptographic proof of computation or storage.",
            {"type":"object","description":"Returns generated proof"}),
    ])

    # Missing TRI CLI Commands (11 tools) - 100% Coverage
    # Note: tri_conscious, tri_sacred_full_cycle, tri_multi_cluster already exist in their respective sections
    tools.extend([
        tool_template("tri_fpga",
            "FPGA toolchain - synth, route, bitstream, flash for Xilinx 7-series",
            {"type":"object","properties":{"subcommand":{"type":"string","description":"Subcommand: status, synth, route, bitstream, flash"}},"description":"Returns FPGA toolchain output"}),
        tool_template("tri_fpga_demo",
            "FPGA demo - LED blink, ternary dot product on hardware",
            {"type":"object","description":"Runs FPGA demonstration"}),
        tool_template("tri_omega_evolve",
            "Omega evolution - autonomous improvement cycle with φ-based metrics",
            {"type":"object","description":"Returns evolution progress"}),
        tool_template("tri_holo_cmd",
            "Holographic interface - 3D visualization of sacred geometry",
            {"type":"object","description":"Returns 3D visualization data"}),
        tool_template("tri_forge_bench",
            "FORGE benchmarks - FPGA toolchain synthesis performance",
            {"type":"object","description":"Returns benchmark metrics"}),
        tool_template("tri_forge_verdict",
            "FORGE verdict - quality assessment for toolchain output",
            {"type":"object","description":"Returns quality verdict"}),
        tool_template("tri_test_repl",
            "Test REPL - interactive test execution loop",
            {"type":"object","description":"Returns test results"}),
        tool_template("tri_all_cmd",
            "Execute all commands - comprehensive system test",
            {"type":"object","description":"Runs all TRI CLI commands"}),
        tool_template("tri_release_cosmic",
            "Cosmic energy release - φ-based energy distribution",
            {"type":"object","description":"Returns energy release data"}),
        tool_template("tri_release_absolute",
            "Absolute energy release - maximum sacred energy",
            {"type":"object","description":"Returns absolute energy output"}),
        tool_template("tri_omega_cmd",
            "Omega phase commands - economic and reward operations",
            {"type":"object","description":"Returns omega phase data"}),
    ])

    return tools

# ═══════════════════════════════════════════════════════════════════════════════
# RESOURCES - MCP v2024-11-05
# ═══════════════════════════════════════════════════════════════════════════════

@app.list_resources()
async def list_resources() -> list[Resource]:
    """List all available Trinity MCP resources"""
    return [
        Resource(
            uri="trinity://constants/all",
            name="All Sacred Constants",
            description="All sacred mathematical constants from V = n × 3^k × π^m × φ^p × e^q",
            mimeType="application/json"
        ),
        Resource(
            uri="trinity://constants/particle_physics",
            name="Particle Physics Constants",
            description="Fundamental particle physics constants with sacred formula fits",
            mimeType="application/json"
        ),
        Resource(
            uri="trinity://constants/cosmology",
            name="Cosmology Constants",
            description="Universal constants from sacred formula",
            mimeType="application/json"
        ),
        Resource(
            uri="trinity://constants/sacred",
            name="Sacred Mathematics",
            description="φ, π, e and their relationships",
            mimeType="application/json"
        ),
        Resource(
            uri="trinity://papers/temporal_phi",
            name="Time and the Golden Ratio",
            description="Research paper: temporal_phi.tex - Planck time, specious present",
            mimeType="text/plain"
        ),
        Resource(
            uri="trinity://papers/consciousness_trinity",
            name="Consciousness and TRINITY",
            description="Research paper: neural gamma, consciousness threshold",
            mimeType="text/plain"
        ),
        Resource(
            uri="trinity://papers/gravity_phi",
            name="Gravitational Constants from φ",
            description="Research paper: G, Ω_Λ, Ω_DM from golden ratio",
            mimeType="text/plain"
        ),
        Resource(
            uri="trinity://papers/unified",
            name="Unified Framework",
            description="Research paper: complete TRINITY unified theory",
            mimeType="text/plain"
        ),
        Resource(
            uri="file://CLAUDE.md",
            name="CLI Documentation",
            description="Complete Trinity CLI command reference (280+ commands)",
            mimeType="text/markdown"
        ),
        Resource(
            uri="trinity://docs/architecture",
            name="Architecture Overview",
            description="Trinity system architecture documentation",
            mimeType="text/markdown"
        ),
        Resource(
            uri="trinity://docs/api",
            name="API Reference",
            description="Trinity API documentation",
            mimeType="text/markdown"
        ),
        Resource(
            uri="trinity://docs/sacred",
            name="Sacred Intelligence",
            description="Sacred mathematics and intelligence documentation",
            mimeType="text/markdown"
        ),
    ]

@app.read_resource()
async def read_resource(uri: str) -> str:
    """Read a Trinity MCP resource"""
    import os

    # Sacred constants resources
    if uri.startswith("trinity://constants/"):
        category = uri.replace("trinity://constants/", "")
        constants_data = {
            "all": {
                "phi": PHI,
                "phi_inverse": 1/PHI,
                "pi": math.pi,
                "e": math.e,
                "trinity_identity": "φ² + 1/φ² = 3",
                "fine_structure": 137.036,
                "proton_electron_mass": 1836.152673,
                "cosmological_constant": 0.69,
            },
            "particle_physics": {
                "fine_structure_alpha": 137.036,
                "proton_electron_mass_ratio": 1836.152673,
                "electron_g_factor": 2.002319,
            },
            "cosmology": {
                "cosmological_constant_omega_lambda": 0.69,
                "dark_matter_omega_dm": 0.26,
                "hubble_constant_h0": 70.0,
            },
            "sacred": {
                "phi": PHI,
                "phi_squared": PHI**2,
                "phi_inverse": 1/PHI,
                "trinity": "φ² + 1/φ² = 3",
            }
        }
        result = constants_data.get(category, constants_data["all"])
        return json.dumps(result, indent=2)

    # Papers resources
    elif uri.startswith("trinity://papers/"):
        topic = uri.replace("trinity://papers/", "")
        project_root = os.environ.get("TRINITY_PROJECT_ROOT", "/Users/playra/trinity-w1")
        papers = {
            "temporal_phi": f"{project_root}/docs/papers/TEMPORAL_PHI.tex",
            "consciousness_trinity": f"{project_root}/docs/papers/CONSCIOUSNESS_TRINITY.tex",
            "gravity_phi": f"{project_root}/docs/papers/GRAVITY_PHI.tex",
            "unified": f"{project_root}/docs/papers/TRINITY_UNIFIED.tex"
        }
        paper_path = papers.get(topic)
        if paper_path and Path(paper_path).exists():
            return Path(paper_path).read_text()
        return f"# Paper not found: {topic}\n\nAvailable: {list(papers.keys())}"

    # File resources
    elif uri.startswith("file://"):
        project_root = os.environ.get("TRINITY_PROJECT_ROOT", "/Users/playra/trinity-w1")
        file_path = uri.replace("file://", "")
        full_path = Path(project_root) / file_path
        if full_path.exists():
            content = full_path.read_text()
            return f"{content}\n\n---\nV = n × 3^k × π^m × φ^p × e^q | φ² + 1/φ² = 3 = TRINITY"
        return f"# File not found: {file_path}"

    # Documentation resources
    elif uri.startswith("trinity://docs/"):
        page = uri.replace("trinity://docs/", "")
        project_root = os.environ.get("TRINITY_PROJECT_ROOT", "/Users/playra/trinity-w1")
        docs_map = {
            "architecture": f"{project_root}/docsite/docs/architecture/overview.md",
            "api": f"{project_root}/docsite/docs/api/index.md",
            "sacred": f"{project_root}/docsite/docs/research/index.md",
        }
        doc_path = docs_map.get(page)
        if doc_path and Path(doc_path).exists():
            return Path(doc_path).read_text()
        return f"# Documentation not found: {page}\n\nAvailable: {list(docs_map.keys())}"

    return f"# Unknown resource: {uri}"

# ═══════════════════════════════════════════════════════════════════════════════
# PROMPTS - MCP v2024-11-05
# ═══════════════════════════════════════════════════════════════════════════════

@app.list_prompts()
async def list_prompts() -> list[Prompt]:
    """List all available Trinity MCP prompts"""
    return [
        Prompt(
            name="sacred_formula_analysis",
            description="Analyze any value using Trinity's sacred formula V = n × 3^k × π^m × φ^p × e^q",
            arguments=[
                {"name": "value", "description": "Target value to analyze", "required": True},
                {"name": "extended", "description": "Use extended bounds for fitting", "required": False}
            ]
        ),
        Prompt(
            name="sacred_derivation",
            description="Generate step-by-step sacred formula derivation for a known constant",
            arguments=[
                {"name": "constant", "description": "Constant name (alpha, proton_electron_mass, etc.)", "required": True}
            ]
        ),
        Prompt(
            name="gematria_analysis",
            description="Analyze text using Coptic gematria with sacred formula fitting",
            arguments=[
                {"name": "text", "description": "Text to analyze", "required": True},
                {"name": "method", "description": "Gematria method (coptic, hebrew, english)", "required": False}
            ]
        ),
        Prompt(
            name="trinity_code_review",
            description="Review code using Trinity principles: sacred math, ternary logic, formula integration",
            arguments=[
                {"name": "file_path", "description": "Path to file to review", "required": True},
                {"name": "focus", "description": "Focus area (sacred, ternary, formula, quality)", "required": False}
            ]
        ),
        Prompt(
            name="sacred_exploration",
            description="Explore sacred mathematical patterns and their relationships",
            arguments=[
                {"name": "topic", "description": "Topic to explore (phi, fibonacci, lucas, trinity, consciousness)", "required": False}
            ]
        ),
    ]

@app.get_prompt()
async def get_prompt(name: str, arguments: dict | None = None) -> str:
    """Get a Trinity MCP prompt template"""
    args = arguments or {}

    if name == "sacred_formula_analysis":
        value = args.get("value", "137.036")
        extended = " with extended bounds" if args.get("extended") else ""

        return f"""Analyze the value {value} using Trinity's sacred formula:

V = n × 3^k × π^m × φ^p × e^q

Where:
- 3 = TRINITY (φ² + 1/φ² = 3)
- π = 3.141592653589793 (circle constant)
- φ = 1.618033988749895 (golden ratio)
- e = 2.718281828459045 (Euler's number)

Find integer exponents n, k, m, p, q such that:
V ≈ {value}{extended}

Show step-by-step derivation and include:
1. The fitted parameters (n, k, m, p, q)
2. Computed value vs target
3. Error percentage
4. Physical/sacred interpretation

Remember: φ² + 1/φ² = 3 = TRINITY"""

    elif name == "sacred_derivation":
        constant = args.get("constant", "alpha")

        return f"""Generate the sacred formula derivation for {constant}:

Show:
1. Target experimental value
2. Formula: V = n × 3^k × π^m × φ^p × e^q
3. Parameter fitting process
4. Step-by-step calculation:
   - Calculate 3^k
   - Calculate π^m
   - Calculate φ^p
   - Calculate e^q
   - Combine: n × 3^k × π^m × φ^p × e^q
5. Final comparison with error %

Output format:
┌─────────────────────────────────────┐
│ SACRED DERIVATION: {constant}      │
├─────────────────────────────────────┤
│ [detailed steps]                    │
└─────────────────────────────────────┘

Remember: φ² + 1/φ² = 3 = TRINITY"""

    elif name == "gematria_analysis":
        text = args.get("text", "TRINITY")
        method = args.get("method", "coptic")

        return f"""Perform gematria analysis on: "{text}"

Method: {method.capitalize()}

Calculate:
1. Gematria value (A=1, B=2, ..., Θ=9, I=10, ...)
2. Reduced value (sum of digits until single digit)
3. Sacred formula fit: V = n × 3^k × π^m × φ^p × e^q
4. Interpretation

Show glyph-by-glyph breakdown with character values:

┌─────────┬───────┬─────────┐
│ Glyph   │ Value │ Coptic  │
├─────────┼───────┼─────────┤
│ T       │ 400   │ Ⲧ       │
│ R       │ 100   │ Ⲣ       │
│ I       │ 10    │ ⲓ       │
│ N       │ 50    │ Ⲛ       │
│ I       │ 10    │ ⲓ       │
│ T       │ 400   │ Ⲧ       │
│ Y       │ 400   │ Ⲩ       │
├─────────┼───────┼─────────┤
│ Total   │ 1370  │         │
└─────────┴───────┴─────────┘

Remember: φ² + 1/φ² = 3 = TRINITY"""

    elif name == "trinity_code_review":
        file_path = args.get("file_path", "src/main.zig")
        focus = args.get("focus", "all")

        return f"""Review {file_path} using Trinity principles:

Focus: {focus}

Review Criteria:
1. Sacred Mathematics: Does it honor φ, π, e patterns?
2. Ternary Logic: Are {-1, 0, +1} patterns used appropriately?
3. Formula Integration: Can results fit V = n × 3^k × π^m × φ^p × e^q?
4. Code Quality: DRY, error handling, performance

Provide:
- Strengths (with φ rating: φ⁻³ to φ³)
- Issues (with severity -1/0/+1)
- Sacred formula optimization opportunities
- Specific improvements with code examples

Output format:
┌─────────────────────────────────────┐
│ TRINITY CODE REVIEW: {file_path}   │
├─────────────────────────────────────┤
│ RATING: φ² (Excellent)              │
├─────────────────────────────────────┤
│ [Strengths, Issues, Improvements]   │
└─────────────────────────────────────┘

Remember: φ² + 1/φ² = 3 = TRINITY"""

    elif name == "sacred_exploration":
        topic = args.get("topic", "phi")

        return f"""Explore sacred mathematics: {topic}

Guiding Questions:
1. What is the {topic} and its significance?
2. How does it relate to V = n × 3^k × π^m × φ^p × e^q?
3. What are the key numerical relationships?
4. How does it manifest in nature, physics, or consciousness?
5. What are the practical applications?

Include:
- Mathematical definitions
- Visual/geometric interpretations
- Real-world examples
- Connections to TRINITY (φ² + 1/φ² = 3)

Remember: The sacred formula connects all constants."""

    return f"# Unknown prompt: {name}\n\nAvailable prompts: sacred_formula_analysis, sacred_derivation, gematria_analysis, trinity_code_review, sacred_exploration"

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════════

async def main():
    from mcp.server.stdio import stdio_server
    async with stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())

if __name__ == "__main__":
    asyncio.run(main())
