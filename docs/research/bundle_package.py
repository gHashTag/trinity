#!/usr/bin/env python3
"""
Trinity Zenodo Bundle Packager
Prepares defensive publication bundles for Zenodo upload
"""

import json
import hashlib
import tarfile
from pathlib import Path
from datetime import datetime
from typing import Dict, List

class BundlePackager:
    """Packages Trinity discoveries into Zenodo-ready bundles."""

    def __init__(self, base_dir: Path = Path("docs/research")):
        self.base_dir = base_dir
        self.discovery_dir = base_dir / "discovery"
        self.output_dir = base_dir / "bundles"

        # Create output directory
        self.output_dir.mkdir(exist_ok=True)

    # Bundle definitions from discovery/README.md
    BUNDLES = {
        "A": {
            "name": "Ternary Neural Networks",
            "discoveries": ["p1", "p8", "p9", "p10", "p11", "p12", "p28", "p55", "p56", "p57", "p58"],
            "description": "Complete framework for ternary neural networks including HSLM, T-JEPA, training techniques, and scientific metrics."
        },
        "B": {
            "name": "Zero-DSP FPGA",
            "discoveries": ["p3", "p17", "p18", "p19", "p20", "p21", "p22", "p23", "p24", "p25", "p26", "p27"],
            "description": "DSP-free FPGA computing using pure LUT logic for ternary inference."
        },
        "C": {
            "name": "TRI-27 ISA",
            "discoveries": ["p4", "p27", "p28", "p54", "p66"],
            "description": "TRI-27 ternary instruction set architecture with Coptic encoding."
        },
        "D": {
            "name": "Queen Orchestration",
            "discoveries": ["p5", "p29", "p30", "p31", "p51", "p58", "p59"],
            "description": "Autonomous orchestration system for AI agent swarms."
        },
        "E": {
            "name": "Tri Language",
            "discoveries": ["p6", "p42", "p43", "p44", "p45", "p46", "p47", "p48", "p49", "p50", "p62", "p63"],
            "description": "Tri language with linear types, effects, and pattern matching."
        },
        "F": {
            "name": "Sacred Math",
            "discoveries": ["p2", "p13", "p14", "p15", "p16", "p23", "p24", "p55", "p56"],
            "description": "φ-based arithmetic and sacred mathematical foundations."
        },
        "G": {
            "name": "VSA Operations",
            "discoveries": ["p7", "p52", "p53"],
            "description": "Vector Symbolic Architecture operations for ternary computing."
        }
    }

    def create_metadata(self, bundle_id: str, bundle_info: Dict) -> Dict:
        """Create Zenodo metadata for bundle."""
        return {
            "title": f"Trinity Bundle {bundle_id}: {bundle_info['name']} — Complete Scientific Framework",
            "upload_type": "publication",
            "publication_type": "article",
            "description": self._create_description(bundle_id, bundle_info),
            "creators": [
                {"name": "Vasilev, Dmitrii", "affiliation": "Trinity Project"},
                {"name": "Trinity Project", "affiliation": "Open Source"}
            ],
            "keywords": [
                "ternary computing",
                "trit-based",
                "balanced ternary",
                "FPGA",
                "neural networks",
                "Zenodo bundle"
            ],
            "license": {"id": "CC-BY-4.0"},
            "access_right": "open",
            "communities": [{"identifier": "trinity-project"}],
            "version": "1.0.0",
            "language": "eng",
            "dates": {
                "issued": datetime.now().strftime("%Y-%m-%d")
            }
        }

    def _create_description(self, bundle_id: str, bundle_info: Dict) -> str:
        """Create detailed description for Zenodo."""
        desc = f"""# Trinity Bundle {bundle_id}: {bundle_info['name']}

**Version:** 1.0.0
**Date:** {datetime.now().strftime("%Y-%m-%d")}
**License:** CC-BY-4.0
**DOI:** 10.5281/zenodo.XXXXXX

## Abstract

This bundle presents the complete scientific framework for {bundle_info['name']}. {bundle_info['description']}

## Contents

This bundle includes {len(bundle_info['discoveries'])} defensive publication discovery files:

"""

        for disc_id in bundle_info['discoveries']:
            # Find the discovery file
            for md_file in self.discovery_dir.glob(f"{disc_id}_*.md"):
                title = md_file.read_text().split('\n')[0].replace('#', '').strip()
                desc += f"- **{disc_id.upper()}**: {title}\n"
                break

        desc += """

## Reproducibility

All code is available at: https://github.com/gHashTag/trinity

Build instructions:
```bash
git clone https://github.com/gHashTag/trinity
cd trinity
zig build
zig build test
```

## Citation

```bibtex
@misc{{trinity2026bundle{bundle_id.lower()},
  title = {{Trinity Bundle {bundle_id}: {bundle_info['name']}}},
  author = {{{{Trinity Project}}}},
  year = {{2026}},
  doi = {{10.5281/zenodo.XXXXXX}},
  url = {{https://doi.org/10.5281/zenodo.XXXXXX}},
  note = {{Defensive Publication}}
}}
```

## Related Publications

See also: https://github.com/gHashTag/trinity/tree/main/docs/research/discovery

---

**φ² + 1/φ² = 3 | TRINITY**
"""
        return desc

    def create_citation_cff(self, bundle_id: str, bundle_info: Dict) -> str:
        """Create CITATION.cff file for bundle."""
        cff = f"""cff-version: 1.2.0
title: "Trinity Bundle {bundle_id}: {bundle_info['name']}"
message: "If you use this bundle, please cite it."
version: 1.0.0
date-released: {datetime.now().strftime("%Y-%m-%d")}

authors:
  - family-names: Vasilev
    given-names: Dmitrii
    affiliation: Trinity Project
    orcid: "https://orcid.org/0000-0000-0000-0000"

  - family-names: Trinity
    given-names: Project
    affiliation: Trinity Project

license: CC-BY-4.0
doi: 10.5281/zenodo.XXXXXX
url: "https://doi.org/10.5281/zenodo.XXXXXX"

keywords:
  - "ternary computing"
  - "trit-based"
  - "FPGA"
  - "neural networks"

abstract: >
  {bundle_info['description']}

references:
  - type: software
    title: "Trinity Project"
    url: "https://github.com/gHashTag/trinity"
    repository: "https://github.com/gHashTag/trinity"
"""
        return cff

    def create_readme(self, bundle_id: str, bundle_info: Dict) -> str:
        """Create README.md for bundle."""
        readme = f"""# Trinity Bundle {bundle_id}: {bundle_info['name']}

## Quick Start

1. Download this bundle from Zenodo
2. Extract: `tar xzf trinity_bundle_{bundle_id.lower()}_v1.0.0.tar.gz`
3. Review discovery files in `discovery/` directory
4. For code reproduction, visit: https://github.com/gHashTag/trinity

## Bundle Contents

```
bundle_{bundle_id.lower()}_v1.0.0/
├── README.md (this file)
├── CITATION.cff (citation metadata)
├── LICENSE (CC-BY-4.0)
├── discovery/
│   ├── {bundle_info['discoveries'][0]}_*.md
│   ├── ...
│   └── {bundle_info['discoveries'][-1]}_*.md
├── docs/
│   ├── ZENODO_PUBLICATION_BEST_PRACTICES.md
│   ├── REPRODUCIBILITY_GUIDE_V2.md
│   └── MATHEMATICAL_APPENDIX_V2.md
└── metadata/
    └── zenodo_metadata.json
```

## Citation

**BibTeX:**
```bibtex
@misc{{trinity2026bundle{bundle_id.lower()},
  title = {{Trinity Bundle {bundle_id}: {bundle_info['name']}}},
  author = {{{{Trinity Project}}}},
  year = {{2026}},
  doi = {{10.5281/zenodo.XXXXXX}},
  url = {{https://doi.org/10.5281/zenodo.XXXXXX}}
}}
```

**APA:**
Trinity Project. (2026). *Trinity Bundle {bundle_id}: {bundle_info['name']}* [Defensive Publication]. Zenodo. https://doi.org/10.5281/zenodo.XXXXXX

## License

This bundle is licensed under CC-BY-4.0. See LICENSE file for details.

## Contact

For questions about this bundle, please open an issue at:
https://github.com/gHashTag/trinity/issues

---

**φ² + 1/φ² = 3 | TRINITY**
"""
        return readme

    def calculate_checksums(self, bundle_dir: Path) -> Dict[str, str]:
        """Calculate SHA256 checksums for all files."""
        checksums = {}

        for file_path in bundle_dir.rglob("*"):
            if file_path.is_file() and file_path.name != "CHECKSUMS.sha256":
                sha256 = hashlib.sha256()
                sha256.update(file_path.read_bytes())
                rel_path = file_path.relative_to(bundle_dir)
                checksums[str(rel_path)] = sha256.hexdigest()

        return checksums

    def package_bundle(self, bundle_id: str) -> Path:
        """Package a single bundle into a tarball."""
        bundle_info = self.BUNDLES[bundle_id]
        bundle_name = f"trinity_bundle_{bundle_id.lower()}_v1.0.0"
        bundle_dir = self.output_dir / bundle_name

        # Create bundle directory
        bundle_dir.mkdir(exist_ok=True)

        # Create directories
        (bundle_dir / "discovery").mkdir(exist_ok=True)
        (bundle_dir / "docs").mkdir(exist_ok=True)
        (bundle_dir / "metadata").mkdir(exist_ok=True)

        # Copy discovery files
        for disc_id in bundle_info['discoveries']:
            for md_file in self.discovery_dir.glob(f"{disc_id}_*.md"):
                import shutil
                shutil.copy(md_file, bundle_dir / "discovery" / md_file.name)

        # Copy documentation
        for doc_file in ["ZENODO_PUBLICATION_BEST_PRACTICES.md",
                         "REPRODUCIBILITY_GUIDE_V2.md",
                         "MATHEMATICAL_APPENDIX_V2.md",
                         "DEFENSIVE_PUB_TEMPLATE.md"]:
            src = self.base_dir / doc_file
            if src.exists():
                import shutil
                shutil.copy(src, bundle_dir / "docs" / doc_file)

        # Create metadata files
        metadata = self.create_metadata(bundle_id, bundle_info)
        (bundle_dir / "metadata" / "zenodo_metadata.json").write_text(
            json.dumps(metadata, indent=2)
        )

        # Create CITATION.cff
        (bundle_dir / "CITATION.cff").write_text(
            self.create_citation_cff(bundle_id, bundle_info)
        )

        # Create README
        (bundle_dir / "README.md").write_text(
            self.create_readme(bundle_id, bundle_info)
        )

        # Create LICENSE
        (bundle_dir / "LICENSE").write_text("""Creative Commons Attribution 4.0 International

Copyright (c) 2026 Trinity Project

You are free to:
- Share — copy and redistribute the material in any medium or format
- Adapt — remix, transform, and build upon the material

Under the following terms:
- Attribution — You must give appropriate credit and indicate if changes were made

See: https://creativecommons.org/licenses/by/4.0/
""")

        # Create CHECKSUMS
        checksums = self.calculate_checksums(bundle_dir)
        checksums_text = "# SHA256 Checksums\n\n"
        for path, checksum in sorted(checksums.items()):
            checksums_text += f"{checksum}  {path}\n"
        (bundle_dir / "CHECKSUMS.sha256").write_text(checksums_text)

        # Create tarball
        tarball_path = self.output_dir / f"{bundle_name}.tar.gz"
        with tarfile.open(tarball_path, "w:gz") as tar:
            for file_path in bundle_dir.rglob("*"):
                if file_path.is_file():
                    arcname = file_path.relative_to(bundle_dir.parent)
                    tar.add(file_path, arcname)

        print(f"✓ Created {bundle_name}.tar.gz ({tarball_path.stat().st_size / 1024 / 1024:.1f} MB)")
        return tarball_path

    def package_all(self) -> List[Path]:
        """Package all bundles."""
        tarballs = []

        print("Packaging Trinity bundles for Zenodo...")
        print("=" * 60)

        for bundle_id in sorted(self.BUNDLES.keys()):
            name = self.BUNDLES[bundle_id]['name']
            print(f"\nBundle {bundle_id}: {name}")
            tarball = self.package_bundle(bundle_id)
            tarballs.append(tarball)

        print("\n" + "=" * 60)
        print(f"Created {len(tarballs)} bundles")
        return tarballs


def main():
    packager = BundlePackager()
    packager.package_all()


if __name__ == "__main__":
    main()
