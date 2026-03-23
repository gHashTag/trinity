#!/bin/bash
# Simple response viewer — tail -f the response file
RESPONSE_FILE=".ralph/queue/responses/current.resp"

echo "=== RESPONSES ==="
echo "Waiting for commands..."
tail -f "$RESPONSE_FILE" 2>/dev/null
