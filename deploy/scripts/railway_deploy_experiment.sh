#!/bin/bash
# Deploy HSLM experiment to Railway service
# Usage: ./scripts/railway_deploy_experiment.sh <r4|r5|r6|r7> [--dry-run]
#
# Requires: RAILWAY_TOKEN in ~/.railway/config.json

set -e

EXPERIMENT="${1:-}"
DRY_RUN="${2:-}"

PROJECT_ID="aa0efa7f-95e6-4466-8de6-43945a031365"
ENV_ID="6748f1ad-9c2f-4b71-9a90-67f40ce34dc9"
SVC_TRAIN="51a3fe43-eafd-4440-b600-02654f569aec"  # hslm-train
SVC_V11="2b525c13-ab3d-4da0-8e86-fd1abe1ba76a"    # hslm-v11
IMAGE="ghcr.io/ghashtag/hslm-train:v10"

RAILWAY_TOKEN=$(python3 -c "import json; d=json.load(open('$HOME/.railway/config.json')); print(d.get('user',{}).get('token',''))")

if [ -z "$EXPERIMENT" ]; then
    echo "Usage: $0 <r4|r5|r6|r7> [--dry-run]"
    echo ""
    echo "Experiments:"
    echo "  r4 → hslm-train: AdamW + label_smoothing=0.1 + TWN + sacred LR"
    echo "  r5 → hslm-v11:   LAMB + context=27 (speed test)"
    echo "  r6 → hslm-train: AdamW + cosine-restarts LR + lr=5e-4"
    echo "  r7 → hslm-v11:   LAMB + eff_batch=1024 (grad_accum=8)"
    exit 1
fi

# Select service and vars based on experiment
case "$EXPERIMENT" in
    r4)
        SVC_ID="$SVC_TRAIN"
        SVC_NAME="hslm-train"
        VARS='{
            "HSLM_FRESH": "1",
            "HSLM_OPTIMIZER": "adamw",
            "HSLM_LR": "3e-4",
            "HSLM_LR_MIN": "1e-6",
            "HSLM_BATCH": "128",
            "HSLM_GRAD_ACCUM": "4",
            "HSLM_WARMUP": "4000",
            "HSLM_STEPS": "100000",
            "HSLM_STE": "twn",
            "HSLM_STE_WARMUP": "10000",
            "HSLM_LABEL_SMOOTHING": "0.1",
            "HSLM_LR_SCHEDULE": "sacred",
            "HSLM_CONTEXT": "81",
            "HSLM_RESTART_PERIOD": "25000",
            "HSLM_RESTART_MULT": "1.0",
            "HSLM_DROPOUT": "0.1",
            "HSLM_STE_THRESHOLD": "0.5",
            "HSLM_SEED": "4",
            "HSLM_WD": "0.1"
        }'
        ;;
    r5)
        SVC_ID="$SVC_V11"
        SVC_NAME="hslm-v11"
        VARS='{
            "HSLM_FRESH": "1",
            "HSLM_OPTIMIZER": "lamb",
            "HSLM_LR": "3e-4",
            "HSLM_LR_MIN": "1e-6",
            "HSLM_BATCH": "128",
            "HSLM_GRAD_ACCUM": "4",
            "HSLM_WARMUP": "4000",
            "HSLM_STEPS": "100000",
            "HSLM_STE": "twn",
            "HSLM_STE_WARMUP": "10000",
            "HSLM_CONTEXT": "27",
            "HSLM_LR_SCHEDULE": "sacred",
            "HSLM_LABEL_SMOOTHING": "0.1",
            "HSLM_RESTART_PERIOD": "25000",
            "HSLM_RESTART_MULT": "1.0",
            "HSLM_DROPOUT": "0.1",
            "HSLM_STE_THRESHOLD": "0.5",
            "HSLM_SEED": "5",
            "HSLM_WD": "0.1"
        }'
        ;;
    r6)
        SVC_ID="$SVC_TRAIN"
        SVC_NAME="hslm-train"
        VARS='{
            "HSLM_FRESH": "1",
            "HSLM_OPTIMIZER": "adamw",
            "HSLM_LR": "5e-4",
            "HSLM_LR_MIN": "1e-6",
            "HSLM_BATCH": "128",
            "HSLM_GRAD_ACCUM": "4",
            "HSLM_WARMUP": "4000",
            "HSLM_STEPS": "100000",
            "HSLM_STE": "twn",
            "HSLM_STE_WARMUP": "10000",
            "HSLM_LR_SCHEDULE": "cosine-restarts",
            "HSLM_RESTART_PERIOD": "25000",
            "HSLM_RESTART_MULT": "1.0",
            "HSLM_LABEL_SMOOTHING": "0.1",
            "HSLM_CONTEXT": "81",
            "HSLM_DROPOUT": "0.1",
            "HSLM_STE_THRESHOLD": "0.5",
            "HSLM_SEED": "6",
            "HSLM_WD": "0.1"
        }'
        ;;
    r7)
        SVC_ID="$SVC_V11"
        SVC_NAME="hslm-v11"
        VARS='{
            "HSLM_FRESH": "1",
            "HSLM_OPTIMIZER": "lamb",
            "HSLM_LR": "5e-3",
            "HSLM_LR_MIN": "1e-5",
            "HSLM_BATCH": "128",
            "HSLM_GRAD_ACCUM": "8",
            "HSLM_WARMUP": "2000",
            "HSLM_STEPS": "100000",
            "HSLM_STE": "twn",
            "HSLM_STE_WARMUP": "10000",
            "HSLM_CONTEXT": "81",
            "HSLM_LR_SCHEDULE": "sacred",
            "HSLM_LABEL_SMOOTHING": "0.1",
            "HSLM_RESTART_PERIOD": "25000",
            "HSLM_RESTART_MULT": "1.0",
            "HSLM_DROPOUT": "0.1",
            "HSLM_STE_THRESHOLD": "0.5",
            "HSLM_SEED": "7",
            "HSLM_WD": "0.1"
        }'
        ;;
    *)
        echo "Unknown experiment: $EXPERIMENT"
        exit 1
        ;;
esac

echo "═══════════════════════════════════════════════════"
echo " Deploying $EXPERIMENT → $SVC_NAME ($SVC_ID)"
echo "═══════════════════════════════════════════════════"
echo "$VARS" | python3 -c "import json,sys; v=json.load(sys.stdin); [print(f'  {k}={v}') for k,v in sorted(v.items())]"

if [ "$DRY_RUN" = "--dry-run" ]; then
    echo ""
    echo "[DRY RUN] Would upsert vars and redeploy"
    exit 0
fi

# Step 1: Upsert variables
echo ""
echo "[1/3] Upserting env vars..."
ESCAPED_VARS=$(echo "$VARS" | python3 -c "
import json, sys
v = json.load(sys.stdin)
# Build GraphQL input format
pairs = ', '.join(f'\"{k}\": \"{v}\"' for k,v in v.items())
print('{' + pairs + '}')
")

RESULT=$(curl -s 'https://railway.com/graphql/v2' \
  -H "Authorization: Bearer $RAILWAY_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
    \"query\": \"mutation { variableCollectionUpsert(input: { projectId: \\\"$PROJECT_ID\\\", serviceId: \\\"$SVC_ID\\\", environmentId: \\\"$ENV_ID\\\", variables: $ESCAPED_VARS }) }\"
  }")

echo "$RESULT" | python3 -c "
import json,sys
d = json.load(sys.stdin)
if d.get('data',{}).get('variableCollectionUpsert'):
    print('  OK: vars upserted')
else:
    print(f'  ERROR: {json.dumps(d)[:300]}')
    sys.exit(1)
"

# Step 2: Find latest deployment to redeploy
echo "[2/3] Finding latest deployment..."
DEPLOY_ID=$(curl -s 'https://railway.com/graphql/v2' \
  -H "Authorization: Bearer $RAILWAY_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
    \"query\": \"query { deployments(first: 1, input: { serviceId: \\\"$SVC_ID\\\", environmentId: \\\"$ENV_ID\\\" }) { edges { node { id status } } } }\"
  }" | python3 -c "
import json,sys
d = json.load(sys.stdin)
edges = d.get('data',{}).get('deployments',{}).get('edges',[])
if edges:
    print(edges[0]['node']['id'])
else:
    print('NONE')
")

if [ "$DEPLOY_ID" = "NONE" ]; then
    echo "  ERROR: No previous deployment found"
    exit 1
fi
echo "  Latest deployment: $DEPLOY_ID"

# Step 3: Redeploy with same image
echo "[3/3] Redeploying..."
RESULT=$(curl -s 'https://railway.com/graphql/v2' \
  -H "Authorization: Bearer $RAILWAY_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
    \"query\": \"mutation { deploymentRedeploy(id: \\\"$DEPLOY_ID\\\", usePreviousImageTag: true) { id status } }\"
  }")

echo "$RESULT" | python3 -c "
import json,sys
d = json.load(sys.stdin)
deploy = d.get('data',{}).get('deploymentRedeploy',{})
if deploy:
    print(f'  OK: new deployment {deploy[\"id\"]} → {deploy[\"status\"]}')
else:
    print(f'  ERROR: {json.dumps(d)[:300]}')
"

echo ""
echo "═══ $EXPERIMENT deployed to $SVC_NAME ═══"
