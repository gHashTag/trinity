#!/bin/bash
# Try with header instead of query param
echo "With X-Session-ID header:"
curl -s -H "X-Session-ID: sess_deukljn4q4mo" "http://localhost:8081/api/v1/history/777000?limit=5"
echo ""
echo "Try sess_deubhyi0p828:"
curl -s -H "X-Session-ID: sess_deubhyi0p828" "http://localhost:8081/api/v1/history/777000?limit=5"
