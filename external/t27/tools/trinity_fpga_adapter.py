#!/usr/bin/env python3
"""The FPGA adapter contract of specs/fpga/adapter.t27: receipts held to the
contract, dry-run and device labelled apart, every negative with its own status.

WHY THIS EXISTS
---------------
S11 of gHashTag/trinity#988 (gHashTag/t27#3573, dmitrii-f-t27/trinity-memory#66):
the FPGA path needs versioned input, output, configuration, error and evidence
contracts, a bitstream path, a dry-run/flash boundary and an evidence receipt.
Two laws hold it all: no hardware run may be inferred from synthesis, and
physical acceptance is tied to a recorded device and transcript. This tool
checks every receipt in conformance/trinity/fpga_adapter.json against the
contract (schema/version, bitstream sha256, the full-IDCODE rule, distinct
error statuses, the dry-run/device boundary) and refuses the eight defect
classes by name. --self-check plants each defect once and asserts the refusal.

The first device receipts are the stage-2 runs of dmitrii-f-t27/trinity-memory:
the golden chunk (dense5 and baseline2, 320/320 Y lines bit-exact on the
AX7203) and the #65 measurements (12 runs each).

Usage:
  python3 tools/trinity_fpga_adapter.py check [--report conformance/trinity/fpga_adapter.json]
  python3 tools/trinity_fpga_adapter.py --self-check

Exit codes: 0 no finding; 1 findings; 2 could not run (no spec, no report).
"""
from __future__ import annotations

import argparse
import copy
import datetime
import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = ROOT / "specs/fpga/adapter.t27"
REPORT = ROOT / "conformance/trinity/fpga_adapter.json"
SCHEMA = "trinity.fpga-receipt.v1"
CONTRACT_VERSION = "1"
ERRORS = ["wrong_version", "hash_mismatch", "bitstream_absent", "bitstream_empty",
          "placeholder_command", "idcode_mismatch", "transcript_missing", "dry_run_as_device"]
IDCODE_FULL = "0x13636093"
IDCODE_PRINTED = "0x3636093"
CONST_RE = re.compile(r"^pub const (\w+)\s*:\s*([^=]+?)=\s*(.*);\s*$")


def utcnow() -> str:
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sha256_file(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parse_consts(text: str) -> dict:
    consts = {}
    for line in text.splitlines():
        m = CONST_RE.match(line.strip())
        if m:
            raw = m.group(3).strip()
            if raw.startswith("["):
                items = re.findall(r'"([^"]*)"', raw)
                consts[m.group(1)] = items
            elif raw.startswith('"'):
                consts[m.group(1)] = raw.strip('"')
            else:
                consts[m.group(1)] = raw
    return consts


def check_receipt(r: dict, consts: dict) -> list[str]:
    """One receipt against the contract -> a list of error statuses (empty = pass)."""
    findings = []
    if r.get("schema") != SCHEMA or r.get("contract_version") != CONTRACT_VERSION:
        findings.append("wrong_version")
    kind = r.get("kind")
    if kind not in ("dry_run", "device"):
        findings.append("wrong_version")
        return findings
    bs = r.get("bitstream", {})
    sha = bs.get("sha256", "")
    prov_sha = r.get("provenance", {}).get("bitstream_sha256")
    if not sha or not re.fullmatch(r"[0-9a-f]{64}", sha) or (prov_sha and prov_sha != sha):
        findings.append("hash_mismatch")
    if bs.get("path_resolved") is False:
        findings.append("bitstream_absent")
    if bs.get("bytes") == 0:
        findings.append("bitstream_empty")
    cfg = r.get("config", {})
    if cfg.get("flasher", "") in ("", "TBD", "PLACEHOLDER") or "<" in cfg.get("flasher", ""):
        findings.append("placeholder_command")
    if kind == "device":
        if r.get("board", {}).get("idcode_full") != IDCODE_FULL:
            findings.append("idcode_mismatch")
        tr = r.get("transcript_sha256", "")
        if not tr or not re.fullmatch(r"[0-9a-f]{64}", tr):
            findings.append("transcript_missing")
        if not r.get("result_line", "").startswith("HW RESULT"):
            findings.append("transcript_missing")
    else:
        if r.get("result_line") or r.get("hardware") is not False:
            findings.append("dry_run_as_device")
    return [e for e in ERRORS if e in findings]


def run_check(report_path: pathlib.Path) -> tuple[int, dict]:
    if not SPEC.is_file():
        return 2, {"error": f"no spec at {SPEC}"}
    consts = parse_consts(SPEC.read_text())
    if not report_path.is_file():
        return 2, {"error": f"no report at {report_path}"}
    report = json.loads(report_path.read_text())
    checked = []
    ok = True
    for r in report.get("receipts", []):
        findings = check_receipt(r, consts)
        checked.append({"id": r.get("id"), "kind": r.get("kind"),
                        "status": "pass" if not findings else "fail:" + ",".join(findings)})
        ok = ok and not findings
    negatives = []
    for n in report.get("negatives", []):
        planted = check_receipt(n["receipt"], consts)
        want = n["expects_status"]
        got = want in planted
        negatives.append({"id": n.get("id"), "expects": want,
                          "status": "pass" if got else "fail",
                          "raised": planted})
        ok = ok and got
    summary = {"schema": SCHEMA, "checked_at": utcnow(),
               "contract": {"version": CONTRACT_VERSION, "spec": "specs/fpga/adapter.t27",
                            "idcode_full": IDCODE_FULL, "errors": ERRORS},
               "receipts": checked, "negatives": negatives,
               "pass": ok}
    report_path.write_text(json.dumps({**report, "last_check": summary}, indent=1) + "\n")
    return (0 if ok else 1), summary


def plant_defects(base: dict) -> list[dict]:
    """One planted receipt per error status, each asserted refused."""
    out = []

    def plant(err: str, mutate) -> dict:
        r = copy.deepcopy(base)
        mutate(r)
        return {"id": f"negative-{err}", "receipt": r, "expects_status": err}

    out.append(plant("wrong_version", lambda r: r.update(schema="trinity.fpga-receipt.v0")))
    out.append(plant("hash_mismatch",
                     lambda r: (r["bitstream"].update(sha256="0" * 64),
                                r["provenance"].update(bitstream_sha256="a" * 64))))
    out.append(plant("bitstream_absent", lambda r: r["bitstream"].update(path_resolved=False)))
    out.append(plant("bitstream_empty", lambda r: r["bitstream"].update(bytes=0)))
    out.append(plant("placeholder_command", lambda r: r["config"].update(flasher="TBD")))
    out.append(plant("idcode_mismatch",
                     lambda r: r["board"].update(idcode_full=IDCODE_PRINTED)))
    out.append(plant("transcript_missing", lambda r: r.update(transcript_sha256="")))
    dry = copy.deepcopy(base)
    dry.update(kind="dry_run", hardware=False, id="dry-run-clean")
    dry.pop("transcript_sha256", None)
    dry.pop("result_line", None)
    # a build-only record that claims a hardware result line is the defect
    out.append({"id": "negative-dry_run_as_device", "receipt": dry,
                "expects_status": "dry_run_as_device",
                "note": "the plant mutates this dry receipt below"})
    out[-1]["receipt"] = {**dry, "result_line": "HW RESULT: 1/1 bit-exact"}
    return out


def self_check() -> int:
    if not SPEC.is_file():
        print(f"cannot run: no spec at {SPEC}")
        return 2
    base = {
        "id": "self-check-base", "schema": SCHEMA, "contract_version": CONTRACT_VERSION,
        "kind": "device", "hardware": True,
        "bitstream": {"path": "reports/fpga/x.bit", "sha256": "a" * 64, "bytes": 9730800,
                      "path_resolved": True},
        "provenance": {"bitstream_sha256": "a" * 64, "commit": "0000000",
                       "routed_fmax_mhz": 64.32, "verdict": "PASS"},
        "config": {"flasher": "openFPGALoader", "cable": "digilent_hs2", "target": "sram"},
        "board": {"idcode_full": IDCODE_FULL, "idcode_printed": IDCODE_PRINTED},
        "transcript_sha256": "b" * 64,
        "result_line": "HW RESULT: 320/320 bit-exact",
    }
    findings = check_receipt(base, {})
    if findings:
        print(f"self-check base receipt must pass, got {findings}")
        return 1
    planted = plant_defects(base)
    ok = True
    for n in planted:
        got = check_receipt(n["receipt"], {})
        good = n["expects_status"] in got
        print(f"  {n['id']:32s} {'ok' if good else 'NOT RAISED: ' + ','.join(got)}")
        ok = ok and good
    # the dry-run clean receipt must pass
    dry = copy.deepcopy(base)
    dry.update(kind="dry_run", hardware=False, id="dry-run-clean")
    dry.pop("transcript_sha256")
    dry.pop("result_line")
    dry_pass = not check_receipt(dry, {})
    print(f"  {'dry-run clean receipt':32s} {'ok' if dry_pass else 'FAIL'}")
    print("self-check:", "PASS" if ok and dry_pass else "FAIL")
    return 0 if ok and dry_pass else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("command", nargs="?", choices=("check", "self-check"), default="check")
    ap.add_argument("--report", default=str(REPORT))
    args = ap.parse_args()
    if args.command == "check":
        code, summary = run_check(pathlib.Path(args.report))
        print(json.dumps(summary, indent=1))
        return code
    return self_check()


if __name__ == "__main__":
    raise SystemExit(main())
