#!/bin/bash
cd /Users/playra/trinity-w1/telegram-bridge
echo "Building telegram-bridge..."
go build -o telegram-bridge ./cmd/server
echo "Done! Binary: telegram-bridge"
