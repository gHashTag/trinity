# Offline Translator

Desktop translator app that works completely offline. Supports text translation and OCR from images.

## Features

- **Offline text translation** between 14 languages (argos-translate / OpenNMT)
- **OCR from images** — drag-and-drop or open image files (Tesseract)
- **Dark theme** UI
- **Auto-download** of language models on first use (~50MB per pair)
- Pivot translation through English for unsupported direct pairs

## Supported Languages

English, Russian, Spanish, French, German, Chinese, Japanese, Korean, Portuguese, Italian, Arabic, Turkish, Hindi, Ukrainian

## Requirements (macOS)

- macOS 12+
- Python 3.10+
- Homebrew

## Quick Start (Development)

```bash
cd translator-app
chmod +x run_dev.sh
./run_dev.sh
```

## Build .dmg

```bash
cd translator-app
chmod +x build_dmg.sh
./build_dmg.sh
```

Output: `dist/OfflineTranslator-1.0.0.dmg`

## Install

1. Open the `.dmg` file
2. Drag "Offline Translator" to Applications
3. Launch from Applications
4. First translation will download the language model (~50MB)

## How It Works

1. **Text**: Paste text in the left panel, select languages, click Translate
2. **Image**: Drag an image onto the drop area (or click "Open Image") — OCR extracts text, then translate
3. Language models download automatically on first use and are cached locally

## Tech Stack

| Component | Library |
|-----------|---------|
| Translation | argos-translate (OpenNMT) |
| OCR | Tesseract via pytesseract |
| GUI | PyQt6 |
| Packaging | PyInstaller |
