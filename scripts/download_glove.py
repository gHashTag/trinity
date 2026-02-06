#!/usr/bin/env python3
"""Download and extract GloVe embeddings."""

import os
import urllib.request
import zipfile
import sys

def download_glove():
    url = "https://nlp.stanford.edu/data/glove.6B.zip"
    output_dir = "models/embeddings"
    zip_path = os.path.join(output_dir, "glove.6B.zip")

    os.makedirs(output_dir, exist_ok=True)

    if os.path.exists(os.path.join(output_dir, "glove.6B.300d.txt")):
        print("GloVe 300d already extracted!")
        return True

    if not os.path.exists(zip_path):
        print(f"Downloading GloVe 6B from {url}...")
        print("This is 822MB, please wait...")

        def progress(block_num, block_size, total_size):
            downloaded = block_num * block_size
            percent = min(100, downloaded * 100 / total_size)
            mb_down = downloaded / (1024 * 1024)
            mb_total = total_size / (1024 * 1024)
            print(f"\rProgress: {percent:.1f}% ({mb_down:.1f}/{mb_total:.1f} MB)", end='', flush=True)

        try:
            urllib.request.urlretrieve(url, zip_path, progress)
            print("\nDownload complete!")
        except Exception as e:
            print(f"\nDownload failed: {e}")
            return False

    print("Extracting glove.6B.300d.txt (for production accuracy)...")
    try:
        with zipfile.ZipFile(zip_path, 'r') as zf:
            # Extract 300d file for maximum semantic accuracy
            zf.extract("glove.6B.300d.txt", output_dir)
        print("Extraction complete!")
        return True
    except Exception as e:
        print(f"Extraction failed: {e}")
        return False

if __name__ == "__main__":
    success = download_glove()
    sys.exit(0 if success else 1)
