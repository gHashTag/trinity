#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY FPGA - ShAG 5: ka INSTANSA
# ═══════════════════════════════════════════════════════════════════════════════
# ⚠️ KRITIChESKI VAZhNO - andonche batdet withpandwithyinatwithya $1.65/chawith!
# φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Paboutlatchaem Instance ID
if [ -n "$1" ]; then
    INSTANCE_ID="$1"
elif [ -f /tmp/trinity_instance_id ]; then
    INSTANCE_ID=$(cat /tmp/trinity_instance_id)
else
    echo "❌ Utoazhand Instance ID: ./05_stop_instance.sh <INSTANCE_ID>"
    echo ""
    echo "Naytand ID:"
    echo "  aws ec2 describe-instances --filters 'Name=tag:Name,Values=trinity-fpga-v5' --query 'Reservations[].Instances[].InstanceId' --output text"
    exit 1
fi

REGION="us-east-1"

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    TRINITY FPGA - ka INSTANSA"
echo "                    φ² + 1/φ² = 3 | PHOENIX = 999"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Instance ID: $INSTANCE_ID"
echo ""

# Praboutineryaem withthattatwith
STATUS=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $REGION \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text 2>/dev/null || echo "not-found")

if [ "$STATUS" == "not-found" ]; then
    echo "❌ Inwiththatnwith ne onyden: $INSTANCE_ID"
    exit 1
fi

echo "Tetoatschandy withthattatwith: $STATUS"
echo ""

if [ "$STATUS" == "running" ]; then
    read -p "Owiththatnaboutinandt andnwiththatnwith? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "⏳ Owiththatoninlandinayu andnwiththatnwith..."
        aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $REGION
        
        echo "⏳ Ozhanddayu aboutwiththatnaboutintoand..."
        aws ec2 wait instance-stopped --instance-ids $INSTANCE_ID --region $REGION
        
        echo ""
        echo "✅ Inwiththatnwith aboutwiththatnaboutinlen!"
        echo ""
        echo "💰 Tarandfandtoatsandya pretorascheon."
        echo ""
        echo "Dlya atdalenandya andnwiththatnwitha (aboutwithinaboutaboutdandt EBS):"
        echo "  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION"
    else
        echo "Otmenenabout."
    fi
elif [ "$STATUS" == "stopped" ]; then
    echo "✅ Inwiththatnwith atzhe aboutwiththatnaboutinlen."
    echo ""
    echo "Dlya launcha:"
    echo "  aws ec2 start-instances --instance-ids $INSTANCE_ID --region $REGION"
    echo ""
    echo "Dlya atdalenandya:"
    echo "  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION"
else
    echo "Sthattatwith: $STATUS"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"

# Ochandschaem inremennye filey
rm -f /tmp/trinity_instance_id /tmp/trinity_public_ip /tmp/trinity_s3_bucket 2>/dev/null || true
