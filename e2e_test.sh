#!/bin/bash
set -e

echo "🔗 STARTING E2E GOLDEN CHAIN TEST 🔗"
echo "========================================"

# 1. DECOMPOSE
echo -e "\n[1/7] TRI DECOMPOSE"
./zig-out/bin/tri decompose "Build a self-testing Golden Chain link"

# 2. PLAN
echo -e "\n[2/7] TRI PLAN"
./zig-out/bin/tri plan

# 3. SPEC CREATE (Manual simulation)
echo -e "\n[3/7] TRI SPEC CREATE (Simulated)"
cat > specs/tri/golden_chain_test.vibee <<EOL
// golden_chain_test v1.0.0
// Священная формула: V = n × 3^k × π^m × φ^p × e^q
// Золотая идентичность: φ² + 1/φ² = 3

behavior "SelfTest" {
    when "System initializes"
    then "Return TRINITY constant (3.0)"
    example "init() -> 3.0"
}

behavior "PhiIdentity" {
    when "Checking Golden Identity"
    then "Verify phi^2 + 1/phi^2 equals 3.0 within tolerance"
    example "check_identity() -> true"
}
EOL
echo "Created specs/tri/golden_chain_test.vibee"

# 4. GEN
echo -e "\n[4/7] TRI GEN"
./zig-out/bin/tri gen specs/tri/golden_chain_test.vibee

# 5. VERIFY (Tests + Bench)
echo -e "\n[5/7] TRI VERIFY"
./zig-out/bin/tri verify

# 6. VERDICT
echo -e "\n[6/7] TRI VERDICT"
./zig-out/bin/tri verdict

# 7. GIT INTEGRATION
echo -e "\n[7/7] TRI GIT STATUS"
./zig-out/bin/tri status

echo -e "\n✅ E2E GOLDEN CHAIN TEST COMPLETE"
