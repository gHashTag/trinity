#!/usr/bin/env python3
"""
Zenodo Upload Helper

Automates the process of uploading bundle metadata to Zenodo.
Usage: python3 zenodo_upload_helper.py [--bundle B001|B002|...|PARENT|ALL]

Requirements:
- pip install requests zenodo-get
- ZENODO_TOKEN environment variable
"""

import os
import sys
import json
import argparse
from pathlib import Path
from typing import Dict, List, Optional
import requests

# Zenodo API endpoints
ZENODO_SANDBOX_API = "https://sandbox.zenodo.org/api"
ZENODO_PRODUCTION_API = "https://zenodo.org/api"

# Bundle to DOI mapping
BUNDLE_DOIS = {
    "PARENT": "10.5281/zenodo.19227879",
    "B001": "10.5281/zenodo.19227733",
    "B002": "10.5281/zenodo.19227735",
    "B003": "10.5281/zenodo.19227737",
    "B004": "10.5281/zenodo.19227739",
    "B005": "10.5281/zenodo.19227741",
    "B006": "10.5281/zenodo.19227743",
    "B007": "10.5281/zenodo.19227745",
}

BUNDLE_FILES = {
    "PARENT": ["README.md", "CITATION.cff", ".zenodo.parent.json"],
    "B001": ["src/hslm/**/*.zig", "docs/research/zenodo_B001_enhanced_v5.2.md", "docs/research/CITATION_B001.cff", ".zenodo.B001.json"],
    "B002": ["fpga/**/*.v", "fpga/**/synth.sh", "docs/research/zenodo_B002_enhanced_v5.2.md", "docs/research/CITATION_B002.cff", ".zenodo.B002.json"],
    "B003": ["src/tri27/**/*.zig", "docs/research/tri27_platform.md", "docs/research/CITATION_B003.cff", ".zenodo.B003.json"],
    "B004": ["src/tri/queen/**/*.zig", "docs/research/queen_lotus_experiments.md", "docs/research/CITATION_B004.cff", ".zenodo.B004.json"],
    "B005": ["src/tri-lang/**/*.zig", "docs/research/zenodo_B005_enhanced_v5.2.md", "docs/research/CITATION_B005.cff", ".zenodo.B005.json"],
    "B006": ["src/hslm/f16_utils.zig", "docs/research/SACRED_ARITHMETIC_FRAMEWORK.md", "docs/research/CITATION_B006.cff", ".zenodo.B006.json"],
    "B007": ["src/vsa.zig", "docs/research/zenodo_B007_enhanced_v5.2.md", "docs/research/CITATION_B007.cff", ".zenodo.B007.json"],
}


class ZenodoUploader:
    def __init__(self, token: str, sandbox: bool = False):
        self.token = token
        self.api_base = ZENODO_SANDBOX_API if sandbox else ZENODO_PRODUCTION_API
        self.headers = {"Authorization": f"Bearer {token}"}
    
    def get_deposition(self, deposition_id: Optional[str] = None) -> Dict:
        """Get or create a deposition."""
        if deposition_id:
            response = requests.get(
                f"{self.api_base}/deposit/depositions/{deposition_id}",
                headers=self.headers
            )
            response.raise_for_status()
            return response.json()
        
        # Create new deposition
        response = requests.post(
            f"{self.api_base}/deposit/depositions",
            headers=self.headers,
            json={}
        )
        response.raise_for_status()
        return response.json()
    
    def upload_metadata(self, deposition_id: str, metadata: Dict) -> Dict:
        """Upload metadata to a deposition."""
        response = requests.put(
            f"{self.api_base}/deposit/depositions/{deposition_id}",
            headers=self.headers,
            json={"metadata": metadata}
        )
        response.raise_for_status()
        return response.json()
    
    def upload_file(self, deposition_id: str, filepath: Path) -> Dict:
        """Upload a file to a deposition."""
        filename = filepath.name
        
        # Initialize file upload
        response = requests.post(
            f"{self.api_base}/deposit/depositions/{deposition_id}/files",
            headers=self.headers,
            json={"filename": filename}
        )
        response.raise_for_status()
        bucket_url = response.json()["links"]["bucket"]
        
        # Upload file content
        with open(filepath, "rb") as f:
            response = requests.put(
                f"{bucket_url}/{filename}",
                data=f,
                headers=self.headers
            )
            response.raise_for_status()
        
        return response.json()
    
    def publish_deposition(self, deposition_id: str) -> Dict:
        """Publish a deposition."""
        response = requests.post(
            f"{self.api_base}/deposit/depositions/{deposition_id}/actions/publish",
            headers=self.headers
        )
        response.raise_for_status()
        return response.json()
    
    def get_deposition_doi(self, deposition_id: str) -> Optional[str]:
        """Get the DOI of a deposition."""
        deposition = self.get_deposition(deposition_id)
        return deposition.get("metadata", {}).get("doi")
    
    def new_version(self, concept_doi: str) -> Dict:
        """Create a new version of an existing deposition."""
        # Find the latest deposition with this concept DOI
        response = requests.get(
            f"{self.api_base}/deposit/depositions",
            headers=self.headers,
            params={"q": f"conceptdoi:{concept_doi}"}
        )
        response.raise_for_status()
        
        depositions = response.json()
        if not depositions:
            raise ValueError(f"No deposition found with concept DOI: {concept_doi}")
        
        latest = sorted(depositions, key=lambda d: d["submitted"], reverse=True)[0]
        latest_id = latest["id"]
        
        # Create new version
        response = requests.post(
            f"{self.api_base}/deposit/depositions/{latest_id}/actions/newversion",
            headers=self.headers
        )
        response.raise_for_status()
        
        # Get the new draft deposition
        new deposition_link = response.json()["links"]["latest_draft"]
        new_id = new_deposition_link.split("/")[-1]
        
        return self.get_deposition(new_id)


def load_metadata(bundle: str, research_dir: Path) -> Dict:
    """Load metadata for a bundle."""
    metadata_file = research_dir / f".zenodo.{bundle}.json"
    
    if not metadata_file.exists():
        raise FileNotFoundError(f"Metadata file not found: {metadata_file}")
    
    with open(metadata_file, 'r') as f:
        return json.load(f)


def generate_checksums(research_dir: Path) -> Dict[str, str]:
    """Generate checksums for all research files."""
    import hashlib
    
    checksums = {}
    
    for filepath in research_dir.rglob("*"):
        if filepath.is_file() and not filepath.name.startswith("."):
            sha256 = hashlib.sha256()
            with open(filepath, 'rb') as f:
                for chunk in iter(lambda: f.read(4096), b''):
                    sha256.update(chunk)
            checksums[str(filepath.relative_to(research_dir.parent))] = sha256.hexdigest()
    
    return checksums


def main():
    parser = argparse.ArgumentParser(description="Zenodo Upload Helper")
    parser.add_argument("--bundle", "-b", default="ALL", 
                       choices=["ALL", "PARENT", "B001", "B002", "B003", "B004", "B005", "B006", "B007"],
                       help="Bundle to upload")
    parser.add_argument("--sandbox", "-s", action="store_true",
                       help="Use Zenodo sandbox instead of production")
    parser.add_argument("--dry-run", "-n", action="store_true",
                       help="Validate without uploading")
    parser.add_argument("--new-version", "-v", action="store_true",
                       help="Create new version of existing deposition")
    parser.add_argument("--publish", "-p", action="store_true",
                       help="Publish the deposition after upload")
    
    args = parser.parse_args()
    
    # Get token
    token = os.environ.get("ZENODO_TOKEN")
    if not token:
        print("❌ ZENODO_TOKEN environment variable not set")
        print("   Get your token from: https://zenodo.org/account/settings/applications/tokens")
        sys.exit(1)
    
    # Initialize uploader
    uploader = ZenodoUploader(token, sandbox=args.sandbox)
    
    # Get research directory
    script_dir = Path(__file__).parent
    research_dir = script_dir
    
    # Determine bundles to process
    bundles = ["PARENT", "B001", "B002", "B003", "B004", "B005", "B006", "B007"]
    if args.bundle != "ALL":
        bundles = [args.bundle]
    
    print(f"📦 Processing {len(bundles)} bundle(s): {', '.join(bundles)}")
    print(f"   Target: {'SANDBOX' if args.sandbox else 'PRODUCTION'}")
    print(f"   Mode: {'DRY RUN' if args.dry_run else 'UPLOAD'}")
    print()
    
    # Process each bundle
    for bundle in bundles:
        print(f"🔧 Processing {bundle}...")
        
        try:
            # Load metadata
            metadata = load_metadata(bundle, research_dir)
            print(f"   ✅ Loaded metadata from .zenodo.{bundle}.json")
            
            if args.dry_run:
                print(f"   ⚠️  Dry run: skipping upload")
                print()
                continue
            
            # Get or create deposition
            if args.new_version and bundle != "PARENT":
                concept_doi = BUNDLE_DOIS[bundle]
                deposition = uploader.new_version(concept_doi)
                print(f"   ✅ Created new version of {concept_doi}")
            else:
                deposition = uploader.get_deposition()
                print(f"   ✅ Created new deposition")
            
            deposition_id = deposition["id"]
            
            # Upload metadata
            deposition = uploader.upload_metadata(deposition_id, metadata)
            print(f"   ✅ Uploaded metadata")
            
            # TODO: Upload files (implement glob expansion)
            # for pattern in BUNDLE_FILES.get(bundle, []):
            #     for filepath in glob(pattern):
            #         uploader.upload_file(deposition_id, filepath)
            
            # Publish if requested
            if args.publish:
                deposition = uploader.publish_deposition(deposition_id)
                print(f"   ✅ Published deposition")
                doi = deposition.get("metadata", {}).get("doi")
                if doi:
                    print(f"   📚 DOI: {doi}")
            
            print(f"   ✅ {bundle} processed successfully")
            print()
            
        except Exception as e:
            print(f"   ❌ Error processing {bundle}: {e}")
            print()
            continue
    
    print("✅ Done!")


if __name__ == "__main__":
    main()
