# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec for Offline Translator macOS app

a = Analysis(
    ['translator.py'],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=[
        'argostranslate',
        'argostranslate.package',
        'argostranslate.translate',
        'argostranslate.models',
        'ctranslate2',
        'sentencepiece',
        'stanza',
        'PIL',
        'pytesseract',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='Offline Translator',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=True,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='Offline Translator',
)

app = BUNDLE(
    coll,
    name='Offline Translator.app',
    icon=None,  # Add icon path here: 'assets/icon.icns'
    bundle_identifier='com.trinity.offline-translator',
    info_plist={
        'CFBundleName': 'Offline Translator',
        'CFBundleDisplayName': 'Offline Translator',
        'CFBundleVersion': '1.0.0',
        'CFBundleShortVersionString': '1.0.0',
        'NSHighResolutionCapable': True,
        'LSMinimumSystemVersion': '12.0',
    },
)
