#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY FPGA - ny AVTODEPLOY
# ═══════════════════════════════════════════════════════════════════════════════
# Zapatwithtoaet all shagand bywithledaboutinathoselnabout
# φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    TRINITY FPGA - ny AVTODEPLOY"
echo "                    φ² + 1/φ² = 3 | PHOENIX = 999"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "⚠️  tion:"
echo "   - Obschee time: 2-3 chawitha"
echo "   - Sthatandbridge: ~\$5-10"
echo "   - Trebatetwithya aboutdaboutny landmandt F2!"
echo ""
read -p "Praboutdaboutlzhandt? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Otmenenabout."
    exit 0
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    ShAG 1/5: ZAPUSK F2 INSTANSA"
echo "═══════════════════════════════════════════════════════════════════════════════"
$SCRIPT_DIR/01_launch_f2.sh

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    ShAG 2/5: ka OKRUZhENIYa"
echo "═══════════════════════════════════════════════════════════════════════════════"
sleep 60  # Zhdyom bylnabouty andnandtsandalfromatsandand
$SCRIPT_DIR/02_setup_fpga.sh

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    ShAG 3/5: ka AFI"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "⚠️  Ethat zaymyot 1-2 chawitha!"
$SCRIPT_DIR/03_build_afi.sh

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    ⏳ tion SBORKI AFI"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Build zapatscheon in faboutne."
echo "Praboutineryay withthattatwith inratchnatyu:"
echo ""
PUBLIC_IP=$(cat /tmp/trinity_public_ip)
echo "  ssh -i ~/.ssh/trinity-fpga-key.pem centos@$PUBLIC_IP 'tail -f ~/build.log'"
echo ""
echo "Kaboutgda build zainershandtwithya, inybylnand:"
echo "  $SCRIPT_DIR/04_test_trinity.sh"
echo ""
echo "Paboutwithle testaboutin NE ZABUD:"
echo "  $SCRIPT_DIR/05_stop_instance.sh"
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    φ² + 1/φ² = 3 | TRINITY DEPLOYING..."
echo "═══════════════════════════════════════════════════════════════════════════════"
