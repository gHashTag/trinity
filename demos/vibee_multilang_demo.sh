#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE Multi-Language Codegen Demo
# ═══════════════════════════════════════════════════════════════════════════════
# Demonstrates VIBEE's ability to generate code for multiple languages from a
# single .vibee specification with custom implementations.
# ═══════════════════════════════════════════════════════════════════════════════

set -e

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║  VIBEE Multi-Language Codegen Demo                                         ║"
echo "║  φ² + 1/φ² = 3                                                             ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================================================
# Demo 1: Zig Generation (default)
# ============================================================================
echo -e "${BLUE}━━━ Demo 1: Zig Code Generation ━━━${NC}"
echo "Spec: vsa_swarm_cluster_16.vibee (24 behaviors, 27 tests)"
echo ""

zig build vibee -- gen specs/tri/vsa_swarm_cluster_16.vibee 2>&1 | grep -E "(Input|Output)"

echo ""
echo "Generated code preview:"
head -20 generated/vsa_swarm_cluster_16.zig
echo "..."
echo ""

# ============================================================================
# Demo 2: Python Generation
# ============================================================================
echo -e "${BLUE}━━━ Demo 2: Python Code Generation ━━━${NC}"
echo "Spec: vsa_multilang_python_native.vibee"
echo ""

cat > /tmp/demo_python.vibee << 'YAML'
name: demo_python
version: "1.0.0"
language: python
module: demo_python

types:
  Vector:
    fields:
      x: Float
      y: Float

behaviors:
  - name: add
    given: two vectors
    when: adding them
    then: return sum
    implementation: |
        def add(a: Vector, b: Vector) -> Vector:
            return Vector(x=a.x + b.x, y=a.y + b.y)

  - name: magnitude
    given: a vector
    when: computing length
    then: return scalar magnitude
    implementation: |
        import math
        def magnitude(v: Vector) -> float:
            return math.sqrt(v.x**2 + v.y**2)
YAML

zig build vibee -- gen /tmp/demo_python.vibee 2>&1 | grep -E "(Input|Output)"
echo ""
echo "Generated Python:"
cat generated/demo_python.py
echo ""

# ============================================================================
# Demo 3: TypeScript Generation
# ============================================================================
echo -e "${BLUE}━━━ Demo 3: TypeScript Code Generation ━━━${NC}"
echo "Spec: vsa_multilang_typescript.vibee"
echo ""

cat > /tmp/demo_typescript.vibee << 'YAML'
name: demo_ts
version: "1.0.0"
language: typescript
module: demo_ts

types:
  Vector:
    fields:
      x: number
      y: number

behaviors:
  - name: add
    given: two vectors
    when: adding them
    then: return sum
    implementation: |
        export function add(a: Vector, b: Vector): Vector {
            return { x: a.x + b.x, y: a.y + b.y };
        }

  - name: magnitude
    given: a vector
    when: computing length
    then: return scalar magnitude
    implementation: |
        export function magnitude(v: Vector): number {
            return Math.sqrt(v.x ** 2 + v.y ** 2);
        }
YAML

zig build vibee -- gen /tmp/demo_typescript.vibee 2>&1 | grep -E "(Input|Output)"
echo ""
echo "Generated TypeScript:"
cat generated/demo_ts.ts
echo ""

# ============================================================================
# Demo 4: Rust Generation
# ============================================================================
echo -e "${BLUE}━━━ Demo 4: Rust Code Generation ━━━${NC}"
echo "Spec: vsa_multilang_rust.vibee"
echo ""

cat > /tmp/demo_rust.vibee << 'YAML'
name: demo_rust
version: "1.0.0"
language: rust
module: demo_rust

types:
  Vector:
    fields:
      x: Float
      y: Float

behaviors:
  - name: add
    given: two vectors
    when: adding them
    then: return sum
    implementation: |
        pub fn add(a: &Vector, b: &Vector) -> Vector {
            Vector { x: a.x + b.x, y: a.y + b.y }
        }

  - name: magnitude
    given: a vector
    when: computing length
    then: return scalar magnitude
    implementation: |
        pub fn magnitude(v: &Vector) -> f64 {
            (v.x * v.x + v.y * v.y).sqrt()
        }
YAML

zig build vibee -- gen /tmp/demo_rust.vibee 2>&1 | grep -E "(Input|Output)"
echo ""
echo "Generated Rust:"
cat generated/demo_rust.rs
echo ""

# ============================================================================
# Demo 5: Production Swarm Cluster
# ============================================================================
echo -e "${BLUE}━━━ Demo 5: Production 16-Agent Swarm Cluster ━━━${NC}"
echo "Spec: vsa_swarm_cluster_16.vibee"
echo ""
echo "Features:"
echo "  • 24 behaviors (agent discovery, consensus, self-healing)"
echo "  • 27 test cases (all passing)"
echo "  • Phi-spiral consensus algorithm"
echo "  • Task distribution and load balancing"
echo ""

echo "Running tests:"
zig test generated/vsa_swarm_cluster_16.zig 2>&1 | tail -5

echo ""
echo -e "${GREEN}━━━ Demo Complete ━━━${NC}"
echo ""
echo "Supported Languages: Zig, Python, TypeScript, Rust, Go, Swift, Kotlin, Java, C"
echo ""
echo "Usage:"
echo "  zig build vibee -- gen <spec.vibee>"
echo ""
