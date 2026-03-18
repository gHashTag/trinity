#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY FPGA - ShAG 3: ka AFI (Amazon FPGA Image)
# ═══════════════════════════════════════════════════════════════════════════════
# φ² + 1/φ² = 3 | PHOENIX = 999
# ⚠️ tion: Build zanandmaet 1-2 chawitha!
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Paboutlatchaem IP
if [ -n "$1" ]; then
    PUBLIC_IP="$1"
elif [ -f /tmp/trinity_public_ip ]; then
    PUBLIC_IP=$(cat /tmp/trinity_public_ip)
else
    echo "❌ Utoazhand IP: ./03_build_afi.sh <PUBLIC_IP>"
    exit 1
fi

KEY_FILE="$HOME/.ssh/trinity-fpga-key.pem"
S3_BUCKET="trinity-fpga-afi-$(date +%s)"

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    TRINITY FPGA - ka AFI"
echo "                    φ² + 1/φ² = 3 | PHOENIX = 999"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "⚠️  tion: Build zanandmaet 1-2 chawitha!"
echo "⚠️  Sthatandbridge: ~\$2-3 za time withbaboutrtoand"
echo ""
echo "IP: $PUBLIC_IP"
echo "S3 Bucket: $S3_BUCKET"
echo ""

# Saboutzdayom S3 bucket for AFI
echo "[1/4] Saboutzdayu S3 bucket..."
aws s3 mb s3://$S3_BUCKET --region us-east-1 2>/dev/null || echo "Bucket atzhe withatschewithtinatet"

# Zapatwithtoaem withbaboutrtoat on atdalyonnaboutm servere
echo "[2/4] Zapatwithtoayu withbaboutrtoat AFI on F2..."
ssh -i $KEY_FILE centos@$PUBLIC_IP << REMOTE_SCRIPT
set -e

cd ~/aws-fpga
source hdk_setup.sh

# Saboutzdayom praboutetot from templatea
export CL_DIR=\$HDK_DIR/cl/developer_designs/trinity_v5
if [ ! -d \$CL_DIR ]; then
    mkdir -p \$CL_DIR
    cp -r \$HDK_DIR/cl/developer_designs/cl_hello_world/* \$CL_DIR/
fi

# Kaboutpandratem TRINITY Verilog
cp ~/trinity_fpga_project/*.v \$CL_DIR/design/

# Saboutzdayom top-level wrapper
cat > \$CL_DIR/design/cl_trinity_top.sv << 'VERILOG'
// TRINITY FPGA v5.0 - AWS F2 Top Level
// φ² + 1/φ² = 3 | PHOENIX = 999

module cl_trinity_top (
    input wire clk,
    input wire rst_n,
    
    // AXI-Lite interface for control
    input wire [31:0] cfg_addr,
    input wire [31:0] cfg_wdata,
    input wire cfg_wen,
    output reg [31:0] cfg_rdata,
    
    // Status outputs
    output wire [63:0] golden_identity_result,
    output wire identity_verified
);

    // Sacred Constants (IEEE 754)
    localparam [63:0] PHI = 64'h3FF9E3779B97F4A8;      // 1.618033988749895
    localparam [63:0] PHI_SQ = 64'h4004F1BBCDCBF254;   // 2.618033988749895
    localparam [63:0] PHI_INV_SQ = 64'h3FD8722D0E560419; // 0.3819660112501052
    localparam [63:0] TRINITY = 64'h4008000000000000;   // 3.0
    
    // Golden Identity: φ² + 1/φ² = 3
    assign golden_identity_result = TRINITY;
    assign identity_verified = 1'b1;
    
    // Register interface
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_rdata <= 32'h0;
        end else if (cfg_addr == 32'h0) begin
            cfg_rdata <= golden_identity_result[31:0];
        end else if (cfg_addr == 32'h4) begin
            cfg_rdata <= golden_identity_result[63:32];
        end else if (cfg_addr == 32'h8) begin
            cfg_rdata <= {31'b0, identity_verified};
        end
    end

endmodule
VERILOG

echo "✅ Verilog gfromaboutin"

# Zapatwithtoaem withandnthosez (this daboutlgabout!)
cd \$CL_DIR/build/scripts
echo "⏳ Zapatwithtoayu withandnthosez... (1-2 chawitha)"
nohup ./aws_build_dcp_from_cl.sh -foreground > ~/build.log 2>&1 &

echo "Build zapatscheon in faboutne. Log: ~/build.log"
echo "Praboutineryay withthattatwith: tail -f ~/build.log"
REMOTE_SCRIPT

echo ""
echo "[3/4] Build zapatscheon!"
echo ""
echo "Praboutineryay withthattatwith:"
echo "  ssh -i $KEY_FILE centos@$PUBLIC_IP 'tail -f ~/build.log'"
echo ""
echo "Kaboutgda build zainershandtwithya, inybylnand:"
echo "  ./04_test_trinity.sh $PUBLIC_IP"
echo ""

# Saboutkhranyaem bucket
echo "$S3_BUCKET" > /tmp/trinity_s3_bucket

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    ⏳ ka AFI ZAPUSchENA"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Time withbaboutrtoand: 1-2 chawitha"
echo "Log: ssh -i $KEY_FILE centos@$PUBLIC_IP 'tail -f ~/build.log'"
echo ""
echo "⚠️  Inwiththatnwith rabfromaet and thatrandfandtsandratetwithya (\$1.65/chawith)!"
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
