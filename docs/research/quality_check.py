#!/usr/bin/env python3
"""
Trinity Discovery Quality Checker
Automated quality validation for defensive publications
"""

import re
import sys
from pathlib import Path
from typing import List, Tuple

# Colors for terminal output
class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'

def check(file_path: Path) -> List[Tuple[str, bool, str]]:
    """Run all quality checks on a single file."""
    content = file_path.read_text()
    checks = []

    # Check 1: Claim formatting (should use : not })
    if re.search(r'\*\*Claim\s+\d+\}:', content):
        checks.append(("Claim formatting", False, "Uses } instead of :"))
    else:
        checks.append(("Claim formatting", True, "OK"))

    # Check 2: Has Abstract section
    if "## 1. Abstract" in content or "## Abstract" in content:
        checks.append(("Has Abstract", True, "OK"))
    else:
        checks.append(("Has Abstract", False, "Missing"))

    # Check 3: Has Novelty Statement
    if "## 4. Novelty Statement" in content or "Novelty Statement" in content:
        checks.append(("Has Novelty Statement", True, "OK"))
    else:
        checks.append(("Has Novelty Statement", False, "Missing"))

    # Check 4: Has Implementation section
    if "## 5. Implementation" in content or "Implementation" in content:
        checks.append(("Has Implementation", True, "OK"))
    else:
        checks.append(("Has Implementation", False, "Missing"))

    # Check 5: Has How to Cite section
    if "## 12. How to Cite" in content or "How to Cite" in content:
        checks.append(("Has Citation", True, "OK"))
    else:
        checks.append(("Has Citation", False, "Missing"))

    # Check 6: Has code examples
    if "```zig" in content or "```verilog" in content or "```python" in content:
        checks.append(("Has Code Examples", True, "OK"))
    else:
        checks.append(("Has Code Examples", False, "Missing"))

    # Check 7: Has tables
    if "|" in content and "---" in content:
        checks.append(("Has Tables", True, "OK"))
    else:
        checks.append(("Has Tables", False, "Missing"))

    # Check 8: DOI status
    if 'doi: "TBD"' in content or "doi: TBD" in content:
        checks.append(("DOI Assigned", False, "Still TBD"))
    else:
        checks.append(("DOI Assigned", True, "OK"))

    # Check 9: Abstract length (should be < 300 words)
    abstract_match = re.search(
        r'## 1\. Abstract\s*(.+?)(?=##|\Z)',
        content,
        re.DOTALL
    )
    if abstract_match:
        abstract = abstract_match.group(1)
        word_count = len(abstract.split())
        if word_count < 300:
            checks.append(("Abstract Length", True, f"{word_count} words"))
        else:
            checks.append(("Abstract Length", False, f"{word_count} words (too long)"))
    else:
        checks.append(("Abstract Length", False, "Not found"))

    # Check 10: Has references/bibtex
    if "```bibtex" in content or "## 10. References" in content:
        checks.append(("Has References", True, "OK"))
    else:
        checks.append(("Has References", False, "Missing"))

    return checks

def main():
    discovery_dir = Path("docs/research/discovery")

    if not discovery_dir.exists():
        print(f"Error: {discovery_dir} not found")
        sys.exit(1)

    md_files = sorted(discovery_dir.glob("p*.md"))

    if not md_files:
        print("No discovery files found")
        sys.exit(1)

    print(f"{'='*70}")
    print(f"Trinity Discovery Quality Checker")
    print(f"Checking {len(md_files)} files")
    print(f"{'='*70}\n")

    total_checks = 0
    passed_checks = 0

    for md_file in md_files:
        checks = check(md_file)
        file_passed = sum(1 for _, passed, _ in checks if passed)
        file_total = len(checks)

        total_checks += file_total
        passed_checks += file_passed

        score = (file_passed / file_total * 100) if file_total > 0 else 0

        if score == 100:
            status = f"{Colors.GREEN}✓{Colors.RESET}"
        elif score >= 80:
            status = f"{Colors.YELLOW}≈{Colors.RESET}"
        else:
            status = f"{Colors.RED}✗{Colors.RESET}"

        print(f"{status} {md_file.name:40s} {file_passed}/{file_total} ({score:.0f}%)")

        # Show failures
        for name, passed, msg in checks:
            if not passed:
                print(f"    └─ {name}: {msg}")

    # Summary
    print(f"\n{'='*70}")
    overall_score = (passed_checks / total_checks * 100) if total_checks > 0 else 0
    print(f"Overall: {passed_checks}/{total_checks} checks passed ({overall_score:.1f}%)")

    if overall_score >= 95:
        verdict = f"{Colors.GREEN}EXCELLENT{Colors.RESET}"
    elif overall_score >= 80:
        verdict = f"{Colors.YELLOW}GOOD{Colors.RESET}"
    else:
        verdict = f"{Colors.RED}NEEDS IMPROVEMENT{Colors.RESET}"

    print(f"Verdict: {verdict}")
    print(f"{'='*70}")

    return 0 if overall_score >= 80 else 1

if __name__ == "__main__":
    sys.exit(main())
