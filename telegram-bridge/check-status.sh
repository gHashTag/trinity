#!/bin/bash
echo "Local bridge status:"
curl -s "http://localhost:8081/api/v1/auth/status"
echo ""
echo "Fly.io bridge status:"
curl -s "https://vibee-telegram-bridge.fly.dev/api/v1/auth/status"
