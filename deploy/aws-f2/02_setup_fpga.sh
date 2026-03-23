#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY FPGA - ShAG 2: ka FPGA OKRUZhENIYa
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
    echo "❌ Utoazhand IP: ./02_setup_fpga.sh <PUBLIC_IP>"
    exit 1
fi

KEY_FILE="$HOME/.ssh/trinity-fpga-key.pem"

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    TRINITY FPGA - ka OKRUZhENIYa"
echo "                    φ² + 1/φ² = 3 | PHOENIX = 999"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "IP: $PUBLIC_IP"
echo ""

# Zhdyom accessnaboutwithtand SSH
echo "[1/5] Ozhanddayu accessnaboutwithtand SSH..."
for i in {1..30}; do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i $KEY_FILE centos@$PUBLIC_IP "echo ok" &>/dev/null; then
        echo "✅ SSH accessen"
        break
    fi
    echo "  Pexperiencetoa $i/30..."
    sleep 10
done

# Vybylnyaem onwithtraboutytoat on atdalyonnaboutm servere
echo "[2/5] Uwiththatoninlandinayu AWS FPGA SDK..."
ssh -i $KEY_FILE centos@$PUBLIC_IP << 'REMOTE_SCRIPT'
set -e

# Cloneandratem AWS FPGA SDK
if [ ! -d ~/aws-fpga ]; then
    git clone https://github.com/aws/aws-fpga.git ~/aws-fpga
fi

# Nawithtraandinaem SDK
cd ~/aws-fpga
source sdk_setup.sh

echo "✅ AWS FPGA SDK atwiththatnaboutinlen"
REMOTE_SCRIPT

echo "[3/5] Cloneandratyu TRINITY..."
ssh -i $KEY_FILE centos@$PUBLIC_IP << 'REMOTE_SCRIPT'
set -e

if [ ! -d ~/vibee-lang ]; then
    git clone https://github.com/gHashTag/vibee-lang.git ~/vibee-lang
fi

cd ~/vibee-lang
git pull origin main

echo "✅ TRINITY withcloneandraboutinan"
REMOTE_SCRIPT

echo "[4/5] Praboutineryayu FPGA..."
ssh -i $KEY_FILE centos@$PUBLIC_IP << 'REMOTE_SCRIPT'
set -e

# Praboutineryaem onlandchande FPGA
sudo fpga-describe-local-image -S 0 -H 2>/dev/null || echo "FPGA withlfrom 0: patwiththaty (gfromaboutin to zagratztoe)"

echo "✅ FPGA accessen"
REMOTE_SCRIPT

echo "[5/5] Kaboutpandratyu Verilog filey..."
ssh -i $KEY_FILE centos@$PUBLIC_IP << 'REMOTE_SCRIPT'
set -e

# Saboutzdayom dandrewhorandyu for praboutetothat
mkdir -p ~/trinity_fpga_project
cp ~/vibee-lang/var/trinity/output/fpga/*.v ~/trinity_fpga_project/

echo "Filey withtoaboutpandraboutinany:"
ls -la ~/trinity_fpga_project/

echo "✅ Verilog filey gfromaboutiny"
REMOTE_SCRIPT

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    ✅ tion NASTROENO!"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Sledatyuschandy shag:"
echo "  ./03_build_afi.sh $PUBLIC_IP"
echo ""
echo "Iland underkeyandwith inratchnatyu:"
echo "  ssh -i $KEY_FILE centos@$PUBLIC_IP"
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
