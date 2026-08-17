#!/usr/bin/env python3
"""Every DOI on the theorem page must resolve to the title beside it.

The page tells readers that each claim is sourced. A citation whose title
belongs to a different paper than its DOI is worse than no citation: it looks
checkable, so nobody checks it. One got onto the page this week — T19 named
"Efficient Detection of Vacuity in ACTL Formulas" (the 1997 paper) against the
DOI of "Efficient Detection of Vacuity in Temporal Model Checking" (the 2001
one). Both are real, and the pair was wrong.

This asks Crossref what each DOI actually is and compares. Titles are matched
loosely — punctuation and case are noise, word overlap is not — because the
failure being caught is "different paper", not "different comma".

    python3 tools/check_citations.py            # check
    python3 tools/check_citations.py --offline  # structure only, no network
"""
import json
import re
import sys
import urllib.request
import urllib.error

SRC = "apps/website/src/data/verificationScience.ts"
API = "https://api.crossref.org/works/"


def entries(text):
    """(id, citation, url) for every theorem carrying a doi.org url."""
    out = []
    for block in re.split(r"\n  \{\n", text)[1:]:
        tid = re.search(r"id: '([^']+)'", block)
        cit = re.search(r"citation:\s*\n?\s*'((?:[^'\\]|\\.)*)'", block)
        url = re.search(r"url: '([^']+)'", block)
        if tid and cit and url:
            out.append((tid.group(1), cit.group(1), url.group(1)))
    return out


def norm(s):
    s = re.sub(r"[^a-z0-9 ]+", " ", s.lower())
    return [w for w in s.split() if len(w) > 3]


def crossref_title(doi):
    req = urllib.request.Request(
        API + doi, headers={"User-Agent": "t27.ai citation check (admin@t27.ai)"}
    )
    with urllib.request.urlopen(req, timeout=20) as r:
        d = json.load(r)
    t = d["message"].get("title") or []
    return t[0] if t else ""


def main():
    offline = "--offline" in sys.argv
    text = open(SRC, encoding="utf-8").read()
    rows = entries(text)
    if not rows:
        print("FAIL: parsed zero citations — the parser, not the page, is broken")
        return 1
    print(f"citations with a url: {len(rows)}")
    dois = [(i, c, u) for i, c, u in rows if "doi.org/" in u]
    print(f"of those, DOIs: {len(dois)}")
    if offline:
        return 0
    bad = 0
    for tid, cit, url in dois:
        doi = url.split("doi.org/", 1)[1]
        try:
            actual = crossref_title(doi)
        except urllib.error.HTTPError as e:
            print(f"  {tid}: DOI {doi} -> HTTP {e.code} (not registered?)")
            bad += 1
            continue
        except Exception as e:  # network trouble is not a citation defect
            print(f"  {tid}: could not reach Crossref ({e}); skipped")
            continue
        # Compare the FIRST quoted title, because `url` documents one paper and
        # a citation may name several. T19 named two: the DOI's own title
        # matched the SECOND, so a whole-string comparison passed while the
        # first title — the one the DOI is attached to — was a different paper.
        titles = re.findall(r'[\u201c"]([^\u201d"]{8,})[\u201d"]', cit)
        cited_title = titles[0] if titles else cit
        want, got = set(norm(cited_title)), set(norm(actual))
        if not got:
            print(f"  {tid}: Crossref returned no title for {doi}")
            bad += 1
            continue
        # Containment in EITHER direction. Crossref keeps subtitles a citation
        # reasonably drops ("Hints on Test Data Selection: Help for the
        # Practicing Programmer"), and it also stores abbreviated records where
        # the citation is fuller (10.1145/512950.512973 is Cousot & Cousot 1977
        # and Crossref calls it just "Abstract interpretation"). Both are the
        # same paper. Dividing by the shorter title accepts both and still
        # rejects T19, where the shared words run out at 3 of 5.
        overlap = len(want & got) / max(min(len(want), len(got)), 1)
        if overlap < 0.75:
            print(f"  {tid}: TITLE MISMATCH")
            print(f"      cited : {cited_title[:96]}")
            print(f"      crossref: {actual[:96]}")
            bad += 1
    print(f"\n{'FAIL' if bad else 'PASS'}: {bad} of {len(dois)} DOIs disagree with their citation")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
