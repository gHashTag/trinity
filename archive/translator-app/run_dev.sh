#!/bin/bash
# Quick run for development/testing (no packaging)
# Run this on your Mac to test the app before building .dmg

set -e

# Install Tesseract if not present
if ! command -v tesseract &> /dev/null; then
    echo "Installing Tesseract OCR..."
    brew install tesseract tesseract-lang
fi

# Create venv if needed
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi

source .venv/bin/activate
pip install -q -r requirements.txt

echo "Starting Offline Translator..."
python3 translator.py
