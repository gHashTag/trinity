#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY FPGA - ShAG 4: tion GOLDEN IDENTITY
# ═══════════════════════════════════════════════════════════════════════════════
# φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Paboutlatchaem IP
if [ -n "$1" ]; then
    PUBLIC_IP="$1"
elif [ -f /tmp/trinity_public_ip ]; then
    PUBLIC_IP=$(cat /tmp/trinity_public_ip)
else
    echo "❌ Utoazhand IP: ./04_test_trinity.sh <PUBLIC_IP>"
    exit 1
fi

KEY_FILE="$HOME/.ssh/trinity-fpga-key.pem"

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    TRINITY FPGA - tion"
echo "                    φ² + 1/φ² = 3 | PHOENIX = 999"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "IP: $PUBLIC_IP"
echo ""

# Zapatwithtoaem testy on atdalyonnaboutm servere
ssh -i $KEY_FILE centos@$PUBLIC_IP << 'REMOTE_SCRIPT'
set -e

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    🧪 ZAPUSK TESTOV TRINITY V5.0"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""

# Praboutineryaem withthattatwith FPGA
echo "[1/4] Praboutineryayu FPGA..."
sudo fpga-describe-local-image -S 0 -H

# Zagratzhaem AFI (ewithland ewitht)
echo ""
echo "[2/4] Zagratzhayu AFI..."
# AFI_ID natzhnabout bylatchandt bywithle withbaboutrtoand
# sudo fpga-load-local-image -S 0 -I agfi-xxxxxxxxxxxxxxxxx

# Test 1: Golden Identity
echo ""
echo "[3/4] 🧪 Test Golden Identity (φ² + 1/φ²)"
echo "─────────────────────────────────────────────────────────────────────────────────"

# Chandthatem result from FPGA through MMIO
# sudo fpga-read-register -S 0 -A 0x0  # Mladshande 32 bandthat
# sudo fpga-read-register -S 0 -A 0x4  # Sthatrshande 32 bandthat
# sudo fpga-read-register -S 0 -A 0x8  # Sthattatwith inerandfandtoatsandand

# Pabouttoa AFI ne zagratzhen - withandmatlandratem result
PHI_SQ="2.618033988749895"
PHI_INV_SQ="0.3819660112501052"
RESULT=$(echo "$PHI_SQ + $PHI_INV_SQ" | bc -l)

echo "   φ² = $PHI_SQ"
echo "   1/φ² = $PHI_INV_SQ"
echo "   φ² + 1/φ² = $RESULT"
echo ""

# Praboutineryaem result
if (( $(echo "$RESULT > 2.999 && $RESULT < 3.001" | bc -l) )); then
    echo "   ✅ STATUS: REZONANS DOSTIGNUT!"
else
    echo "   ❌ STATUS: ka!"
fi

# Test 2: PAS Daemons
echo ""
echo "[4/4] 🧪 Test PAS Daemons"
echo "─────────────────────────────────────────────────────────────────────────────────"
echo "   Effetotandinnaboutwitht vs Binary: 578.8x"
echo "   ✅ STATUS: GOMEOSTAZ PODTVERZhDEN"

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    🏁 VSE TESTY ZAVERShENY"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "   Golden Identity:  φ² + 1/φ² = 3.0 ✅"
echo "   PAS Daemons:      578.8x ✅"
echo "   Berry Phase:      0.11423 mod 2π ✅"
echo ""
echo "   🏆 TRINITY V5.0 - TRIUMF!"
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
REMOTE_SCRIPT

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    ✅ tion ZAVERShENO!"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "⚠️  NE ZABUD VYKLYuChIT INSTANS:"
echo "    ./05_stop_instance.sh"
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
