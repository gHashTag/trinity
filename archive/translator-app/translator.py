"""
Offline Translator App
Translates text (paste) and images (OCR) between languages.
Uses argos-translate for offline neural translation and Tesseract for OCR.
"""

import sys
import os
import argostranslate.package
import argostranslate.translate
from PIL import Image

# OCR import — pytesseract requires Tesseract binary installed on the system
try:
    import pytesseract
    HAS_TESSERACT = True
except ImportError:
    HAS_TESSERACT = False

from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QTextEdit, QPushButton, QComboBox, QLabel, QFileDialog,
    QSplitter, QMessageBox, QProgressDialog
)
from PyQt6.QtCore import Qt, QThread, pyqtSignal, QMimeData
from PyQt6.QtGui import QFont, QDragEnterEvent, QDropEvent, QPixmap, QAction


# ---------------------------------------------------------------------------
# Language management
# ---------------------------------------------------------------------------

# Map of display names to argos language codes
LANGUAGES = {
    "English": "en",
    "Russian": "ru",
    "Spanish": "es",
    "French": "fr",
    "German": "de",
    "Chinese": "zh",
    "Japanese": "ja",
    "Korean": "ko",
    "Portuguese": "pt",
    "Italian": "it",
    "Arabic": "ar",
    "Turkish": "tr",
    "Hindi": "hi",
    "Ukrainian": "uk",
}


def get_installed_languages():
    """Return set of installed argos language codes."""
    installed = argostranslate.translate.get_installed_languages()
    return {lang.code for lang in installed}


def install_language_pair(from_code: str, to_code: str) -> bool:
    """Download and install a translation package if not already present."""
    argostranslate.package.update_package_index()
    available = argostranslate.package.get_available_packages()
    for pkg in available:
        if pkg.from_code == from_code and pkg.to_code == to_code:
            pkg.install()
            return True
    return False


def translate_text(text: str, from_code: str, to_code: str) -> str:
    """Translate text using argos-translate. Returns translated string."""
    installed = argostranslate.translate.get_installed_languages()
    from_lang = next((l for l in installed if l.code == from_code), None)
    to_lang = next((l for l in installed if l.code == to_code), None)
    if from_lang is None or to_lang is None:
        return f"[Error] Language pair {from_code}->{to_code} not installed."
    translation = from_lang.get_translation(to_lang)
    if translation is None:
        return f"[Error] No translation available for {from_code}->{to_code}."
    return translation.translate(text)


def ocr_image(image_path: str, lang: str = "eng") -> str:
    """Extract text from image using Tesseract OCR."""
    if not HAS_TESSERACT:
        return "[Error] pytesseract not installed."
    try:
        img = Image.open(image_path)
        text = pytesseract.image_to_string(img, lang=lang)
        return text.strip()
    except Exception as e:
        return f"[OCR Error] {e}"


# Tesseract language code mapping (subset)
TESSERACT_LANG_MAP = {
    "en": "eng", "ru": "rus", "es": "spa", "fr": "fra", "de": "deu",
    "zh": "chi_sim", "ja": "jpn", "ko": "kor", "pt": "por", "it": "ita",
    "ar": "ara", "tr": "tur", "hi": "hin", "uk": "ukr",
}


# ---------------------------------------------------------------------------
# Background worker for translation / package install
# ---------------------------------------------------------------------------

class TranslateWorker(QThread):
    finished = pyqtSignal(str)
    error = pyqtSignal(str)
    status = pyqtSignal(str)

    def __init__(self, text, from_code, to_code):
        super().__init__()
        self.text = text
        self.from_code = from_code
        self.to_code = to_code

    def run(self):
        try:
            # Check if pair is installed, if not — install
            installed = argostranslate.translate.get_installed_languages()
            from_lang = next((l for l in installed if l.code == self.from_code), None)
            to_lang = next((l for l in installed if l.code == self.to_code), None)

            if from_lang is None or to_lang is None or from_lang.get_translation(to_lang) is None:
                self.status.emit(f"Downloading {self.from_code} -> {self.to_code} package...")
                ok = install_language_pair(self.from_code, self.to_code)
                if not ok:
                    # Try via English pivot
                    self.status.emit(f"Direct pair unavailable. Trying via English pivot...")
                    if self.from_code != "en":
                        install_language_pair(self.from_code, "en")
                    if self.to_code != "en":
                        install_language_pair("en", self.to_code)

            self.status.emit("Translating...")

            # Try direct translation first
            result = translate_text(self.text, self.from_code, self.to_code)
            if result.startswith("[Error]") and self.from_code != "en" and self.to_code != "en":
                # Pivot through English
                intermediate = translate_text(self.text, self.from_code, "en")
                if not intermediate.startswith("[Error]"):
                    result = translate_text(intermediate, "en", self.to_code)

            self.finished.emit(result)
        except Exception as e:
            self.error.emit(str(e))


# ---------------------------------------------------------------------------
# Main Window
# ---------------------------------------------------------------------------

class ImageDropArea(QLabel):
    """Label that accepts drag-and-drop images."""
    image_dropped = pyqtSignal(str)

    def __init__(self):
        super().__init__()
        self.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.setText("Drop image here\nor click 'Open Image'")
        self.setStyleSheet("""
            QLabel {
                border: 2px dashed #888;
                border-radius: 12px;
                padding: 20px;
                color: #888;
                font-size: 14px;
                background-color: #2a2a2a;
            }
        """)
        self.setAcceptDrops(True)
        self.setMinimumHeight(120)

    def dragEnterEvent(self, event: QDragEnterEvent):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()

    def dropEvent(self, event: QDropEvent):
        urls = event.mimeData().urls()
        if urls:
            path = urls[0].toLocalFile()
            if path.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp', '.tiff', '.webp')):
                self.image_dropped.emit(path)
                pixmap = QPixmap(path).scaled(
                    self.width() - 20, 200,
                    Qt.AspectRatioMode.KeepAspectRatio,
                    Qt.TransformationMode.SmoothTransformation
                )
                self.setPixmap(pixmap)


class TranslatorWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Offline Translator")
        self.setMinimumSize(800, 600)
        self.worker = None
        self._setup_ui()
        self._apply_dark_theme()

    def _apply_dark_theme(self):
        self.setStyleSheet("""
            QMainWindow { background-color: #1e1e1e; }
            QWidget { background-color: #1e1e1e; color: #e0e0e0; }
            QTextEdit {
                background-color: #2d2d2d;
                color: #e0e0e0;
                border: 1px solid #444;
                border-radius: 8px;
                padding: 8px;
                font-size: 14px;
            }
            QComboBox {
                background-color: #333;
                color: #e0e0e0;
                border: 1px solid #555;
                border-radius: 6px;
                padding: 6px 12px;
                font-size: 13px;
            }
            QComboBox::drop-down { border: none; }
            QComboBox QAbstractItemView {
                background-color: #333;
                color: #e0e0e0;
                selection-background-color: #0078d4;
            }
            QPushButton {
                background-color: #0078d4;
                color: white;
                border: none;
                border-radius: 8px;
                padding: 10px 20px;
                font-size: 14px;
                font-weight: bold;
            }
            QPushButton:hover { background-color: #1a8ae8; }
            QPushButton:pressed { background-color: #005a9e; }
            QPushButton:disabled { background-color: #555; color: #888; }
            QLabel { color: #ccc; font-size: 13px; }
            QStatusBar { background-color: #252525; color: #aaa; }
        """)

    def _setup_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        layout = QVBoxLayout(central)
        layout.setSpacing(12)
        layout.setContentsMargins(16, 16, 16, 16)

        # --- Language selectors ---
        lang_layout = QHBoxLayout()

        self.from_combo = QComboBox()
        self.to_combo = QComboBox()
        for name in LANGUAGES:
            self.from_combo.addItem(name, LANGUAGES[name])
            self.to_combo.addItem(name, LANGUAGES[name])

        self.from_combo.setCurrentText("English")
        self.to_combo.setCurrentText("Russian")

        swap_btn = QPushButton("⇄")
        swap_btn.setFixedWidth(50)
        swap_btn.clicked.connect(self._swap_languages)

        lang_layout.addWidget(QLabel("From:"))
        lang_layout.addWidget(self.from_combo, 1)
        lang_layout.addWidget(swap_btn)
        lang_layout.addWidget(QLabel("To:"))
        lang_layout.addWidget(self.to_combo, 1)
        layout.addLayout(lang_layout)

        # --- Text areas ---
        splitter = QSplitter(Qt.Orientation.Horizontal)

        # Source
        source_widget = QWidget()
        source_layout = QVBoxLayout(source_widget)
        source_layout.setContentsMargins(0, 0, 0, 0)
        source_label = QLabel("Source text:")
        self.source_text = QTextEdit()
        self.source_text.setPlaceholderText("Paste or type text here...")
        source_layout.addWidget(source_label)
        source_layout.addWidget(self.source_text)
        splitter.addWidget(source_widget)

        # Result
        result_widget = QWidget()
        result_layout = QVBoxLayout(result_widget)
        result_layout.setContentsMargins(0, 0, 0, 0)
        result_label = QLabel("Translation:")
        self.result_text = QTextEdit()
        self.result_text.setReadOnly(True)
        self.result_text.setPlaceholderText("Translation will appear here...")
        result_layout.addWidget(result_label)
        result_layout.addWidget(self.result_text)
        splitter.addWidget(result_widget)

        layout.addWidget(splitter, 1)

        # --- Image area ---
        self.image_drop = ImageDropArea()
        self.image_drop.image_dropped.connect(self._on_image_dropped)
        layout.addWidget(self.image_drop)

        # --- Buttons ---
        btn_layout = QHBoxLayout()

        self.translate_btn = QPushButton("Translate")
        self.translate_btn.clicked.connect(self._on_translate)

        open_img_btn = QPushButton("Open Image")
        open_img_btn.setStyleSheet(
            open_img_btn.styleSheet() + "QPushButton { background-color: #444; }"
        )
        open_img_btn.clicked.connect(self._on_open_image)

        clear_btn = QPushButton("Clear")
        clear_btn.setStyleSheet(
            clear_btn.styleSheet() + "QPushButton { background-color: #555; }"
        )
        clear_btn.clicked.connect(self._on_clear)

        btn_layout.addWidget(open_img_btn)
        btn_layout.addStretch()
        btn_layout.addWidget(clear_btn)
        btn_layout.addWidget(self.translate_btn)
        layout.addLayout(btn_layout)

        # Status bar
        self.statusBar().showMessage("Ready — paste text or drop an image")

    def _swap_languages(self):
        fi = self.from_combo.currentIndex()
        ti = self.to_combo.currentIndex()
        self.from_combo.setCurrentIndex(ti)
        self.to_combo.setCurrentIndex(fi)

    def _on_translate(self):
        text = self.source_text.toPlainText().strip()
        if not text:
            self.statusBar().showMessage("Nothing to translate.")
            return

        from_code = self.from_combo.currentData()
        to_code = self.to_combo.currentData()

        if from_code == to_code:
            self.result_text.setPlainText(text)
            return

        self.translate_btn.setEnabled(False)
        self.statusBar().showMessage("Preparing translation...")

        self.worker = TranslateWorker(text, from_code, to_code)
        self.worker.finished.connect(self._on_translate_done)
        self.worker.error.connect(self._on_translate_error)
        self.worker.status.connect(lambda msg: self.statusBar().showMessage(msg))
        self.worker.start()

    def _on_translate_done(self, result):
        self.result_text.setPlainText(result)
        self.translate_btn.setEnabled(True)
        self.statusBar().showMessage("Translation complete.")

    def _on_translate_error(self, err):
        self.result_text.setPlainText(f"[Error] {err}")
        self.translate_btn.setEnabled(True)
        self.statusBar().showMessage(f"Error: {err}")

    def _on_open_image(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "Open Image", "",
            "Images (*.png *.jpg *.jpeg *.bmp *.tiff *.webp)"
        )
        if path:
            self._on_image_dropped(path)

    def _on_image_dropped(self, path):
        if not HAS_TESSERACT:
            QMessageBox.warning(
                self, "Tesseract not found",
                "Install Tesseract OCR:\n  brew install tesseract\n\n"
                "Then install language data:\n  brew install tesseract-lang"
            )
            return

        self.statusBar().showMessage("Extracting text from image (OCR)...")
        from_code = self.from_combo.currentData()
        tess_lang = TESSERACT_LANG_MAP.get(from_code, "eng")

        text = ocr_image(path, lang=tess_lang)
        if text:
            self.source_text.setPlainText(text)
            self.statusBar().showMessage(f"OCR complete — extracted {len(text)} characters.")
        else:
            self.statusBar().showMessage("OCR found no text in the image.")

    def _on_clear(self):
        self.source_text.clear()
        self.result_text.clear()
        self.image_drop.clear()
        self.image_drop.setText("Drop image here\nor click 'Open Image'")
        self.statusBar().showMessage("Cleared.")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Offline Translator")
    app.setOrganizationName("Trinity")

    window = TranslatorWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
