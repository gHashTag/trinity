#!/usr/bin/env python3
"""Contract and untrusted-input regression tests for pr_blog_report.py."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import pr_blog_report as report


HEAD = "a" * 40
MERGE = "b" * 40


def valid_report():
    return {
        "version": 1,
        "head_sha": HEAD,
        "summary": "The compiler test root now imports the missing parser suite so CI can actually execute its cases.",
        "changes": ["Added the parser suite to the existing compiler test root."],
        "tests": [{"command": "python3 -m unittest discover -s scripts",
                   "result": "All twelve validation cases completed successfully.",
                   "status": "passed", "evidence": "CI run 123, validation job, step 4: 12 tests passed."}],
        "limitations": ["The change was tested locally and has not been deployed to the production runner."],
        "tags": ["Testing", "#CI"],
        "blog": {
            "title": "A test root made the missing cases reachable",
            "summary": "The compiler test graph now includes the parser cases, exposing failures that syntax checks alone did not cover.",
            "outline": [
                "The syntax checker accepted the source while the parser suite remained outside the executable test graph. This prevented CI from evaluating those assertions.",
                "The change imports the suite at its existing root and preserves the original test cases. The report records the exact command and its observed result.",
                "These results apply to the compiler tests only and do not establish production delivery. A separate deployment receipt is still needed before claiming the live runner changed.",
            ],
        },
    }


def valid_event(payload=None, state="open", merged=False):
    return {
        "repository": {"full_name": "gHashTag/trinity"},
        "number": 123,
        "pull_request": {
            "number": 123,
            "body": report.START + "\n```json\n" + json.dumps(payload or valid_report()) + "\n```\n" + report.END,
            "state": state,
            "merged": merged,
            "head": {"sha": HEAD},
            "created_at": "2026-09-13T04:00:00Z",
            "merged_at": "2026-09-14T04:00:00Z" if merged else None,
            "merge_commit_sha": MERGE if merged else None,
            "html_url": "https://github.com/gHashTag/trinity/pull/123",
            "base": {"repo": {"full_name": "gHashTag/trinity"}},
        },
    }


class ValidationTests(unittest.TestCase):
    def assert_invalid(self, event, contains):
        with self.assertRaisesRegex(report.ReportError, contains):
            report.validate_event(event)

    def test_valid_open_report_is_normalized(self):
        normalized = report.validate_event(valid_event())
        self.assertEqual(normalized["tags"], ["Testing", "CI"])
        self.assertEqual(normalized["slug"], "pr-123")
        self.assertEqual(normalized["state"], "open")
        self.assertFalse(normalized["merged"])
        self.assertEqual(normalized["head_sha"], HEAD)

    def test_lifecycle_stays_exact_and_all_artifacts_are_drafts(self):
        for state, merged, phrase, receipts in [
            ("open", False, "Open PR", 2),
            ("closed", False, "Closed without merge", 2),
            ("closed", True, "Merged PR", 3),
        ]:
            with self.subTest(state=state, merged=merged):
                normalized = report.validate_event(valid_event(state=state, merged=merged))
                post = report.make_post(normalized)
                self.assertEqual(normalized["state"], state)
                self.assertEqual(normalized["merged"], merged)
                self.assertFalse(post["published"])
                self.assertEqual(len(post["receipts"]), receipts)
                self.assertIn(phrase, report.make_markdown(normalized, post))
                self.assertIn("not independently rerun", post["body"][0]["text"])
                self.assertEqual(post["title"], valid_report()["blog"]["title"])

    def test_missing_malformed_and_duplicate_blocks(self):
        for body, error in [
            ("A summary with no work report", "exactly one"),
            (report.START + "\n{}\n" + report.END, "fenced JSON"),
            (report.START + "\n```json\n{]\n```\n" + report.END, "malformed JSON"),
            (valid_event()["pull_request"]["body"] * 2, "exactly one"),
            (report.END + "\n```json\n{}\n```\n" + report.START, "closing marker"),
        ]:
            with self.subTest(body=body):
                event = valid_event()
                event["pull_request"]["body"] = body
                self.assert_invalid(event, error)

    def test_duplicate_json_keys_and_nonfinite_json_are_rejected(self):
        for text, error in [('"version": 1, "version": 1', "duplicate JSON key"),
                            ('"value": NaN', "non-finite JSON")]:
            event = valid_event()
            event["pull_request"]["body"] = f'{report.START}\n```json\n{{{text}}}\n```\n{report.END}'
            self.assert_invalid(event, error)

    def test_stale_head_rejected_even_after_other_validations(self):
        payload = valid_report()
        payload["head_sha"] = "c" * 40
        self.assert_invalid(valid_event(payload), "stale")

    def test_placeholder_and_too_small_data(self):
        for field, value, error in [
            ("summary", "TODO: complete the detailed summary after running all of these tests.", "placeholder"),
            ("summary", "Replace this with a sufficiently detailed explanation of the code changes.", "placeholder"),
            ("summary", "Changed code", "40"),
            ("changes", ["none"], "20"),
            ("limitations", [], "list"),
            ("tests", [], "test records"),
            ("tags", ["Testing"], "2–5"),
            ("tags", ["CI", "ci"], "unique"),
            ("tags", ["Testing", "../../escape"], "topic hashtag"),
        ]:
            with self.subTest(field=field, value=value):
                payload = valid_report()
                payload[field] = value
                self.assert_invalid(valid_event(payload), error)
        payload = valid_report()
        payload["blog"]["outline"] = ["long sentence " * 20] * 3
        self.assert_invalid(valid_event(payload), "meaningful prose")
        payload = valid_report()
        payload["blog"]["outline"] = valid_report()["blog"]["outline"][:2]
        self.assert_invalid(valid_event(payload), "3–20")

    def test_statuses_include_honest_failure_and_not_run(self):
        for status in ["passed", "failed", "not_run"]:
            payload = valid_report()
            payload["tests"][0]["status"] = status
            self.assertEqual(report.validate_event(valid_event(payload))["tests"][0]["status"], status)
        payload["tests"][0]["status"] = "success"
        self.assert_invalid(valid_event(payload), "passed, failed, or not_run")

    def test_unknown_report_fields_rejected(self):
        for where, key in [("root", "slug"), ("blog", "published")]:
            payload = valid_report()
            (payload if where == "root" else payload["blog"])[key] = "../../outside"
            self.assert_invalid(valid_event(payload), "unsupported keys")

    def test_missing_nested_fields_and_wrong_types_rejected(self):
        for name in ("command", "result", "status", "evidence"):
            payload = valid_report()
            del payload["tests"][0][name]
            self.assert_invalid(valid_event(payload), "missing keys")
        for value in (True, "1", 2):
            payload = valid_report()
            payload["version"] = value
            self.assert_invalid(valid_event(payload), "version must be 1")
        payload = valid_report()
        payload["blog"] = []
        self.assert_invalid(valid_event(payload), "must be an object")

    def test_control_characters_and_invalid_unicode_rejected(self):
        for suffix in ("\x1b[2J", "\x7f", "\ud800"):
            payload = valid_report()
            payload["summary"] += suffix
            self.assert_invalid(valid_event(payload), "control character")

    def test_safe_identifiers_and_event_cross_checks(self):
        changes = [
            (("pull_request", "number"), "../../outside", "positive integer"),
            (("pull_request", "number"), True, "positive integer"),
            (("pull_request", "number"), 0, "positive integer"),
            (("number",), 124, "does not match"),
            (("repository", "full_name"), "owner/../../outside", "safe owner"),
            (("repository", "full_name"), "owner/repo?query=evil", "safe owner"),
            (("pull_request", "head", "sha"), "a" * 39, "40-character"),
            (("pull_request", "html_url"), "https://evil.example/pull/123", "does not match"),
            (("pull_request", "base", "repo", "full_name"), "another/repository", "does not match"),
        ]
        for keys, value, error in changes:
            with self.subTest(keys=keys, value=value):
                event = valid_event()
                node = event
                for key in keys[:-1]:
                    node = node[key]
                node[keys[-1]] = value
                self.assert_invalid(event, error)

    def test_invalid_state_and_dates_fail_closed(self):
        self.assert_invalid(valid_event(state="merged", merged=True), "state must")
        self.assert_invalid(valid_event(state="open", merged=True), "state closed")
        event = valid_event()
        event["pull_request"]["merged"] = "false"
        self.assert_invalid(event, "boolean")
        event = valid_event(state="closed", merged=True)
        event["pull_request"]["merge_commit_sha"] = None
        self.assert_invalid(event, "merge_commit_sha")
        event = valid_event()
        event["pull_request"]["created_at"] = "2026-09-13"
        self.assert_invalid(event, "timezone")
        event = valid_event()
        event["pull_request"]["merged_at"] = "2026-09-14T04:00:00Z"
        self.assert_invalid(event, "unmerged PR cannot")

    def test_markdown_html_and_fences_are_data_not_active_content(self):
        payload = valid_report()
        dangerous = '<script>alert(1)</script> ```sh echo boom ``` [click](javascript:alert(1)) ![img](https://evil.example)'
        payload["changes"] = ["Preserved the supplied text safely as a test fixture: " + dangerous]
        normalized = report.validate_event(valid_event(payload))
        post = report.make_post(normalized)
        markdown = report.make_markdown(normalized, post)
        self.assertNotIn("<script>", markdown)
        self.assertNotIn("```sh", markdown)
        self.assertNotIn("[click](", markdown)
        self.assertIn("&lt;script&gt;", markdown)
        self.assertNotIn("<script>", report.encode_json(post))
        self.assertEqual(json.loads(report.encode_json(post)), post)
        self.assertNotIn("figure", {block["kind"] for block in post["body"]})


class ArtifactTests(unittest.TestCase):
    def test_idempotent_fixed_artifacts_and_no_outside_writes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "artifacts"
            normalized = report.validate_event(valid_event())
            report.write_artifacts(normalized, output)
            files = {path.name: (path.read_bytes(), path.stat().st_mtime_ns) for path in output.iterdir()}
            report.write_artifacts(normalized, output)
            self.assertEqual(set(files), {"post.json", "draft.md", "report.json"})
            self.assertEqual(files, {path.name: (path.read_bytes(), path.stat().st_mtime_ns) for path in output.iterdir()})
            self.assertEqual(list(root.iterdir()), [output])

    def test_symlink_output_and_file_cannot_overwrite_outside(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            outside = root / "outside.txt"
            outside.write_text("preserve me")
            output = root / "artifacts"
            output.mkdir()
            (output / "post.json").symlink_to(outside)
            normalized = report.validate_event(valid_event())
            with self.assertRaisesRegex(report.ReportError, "non-regular"):
                report.write_artifacts(normalized, output)
            self.assertEqual(outside.read_text(), "preserve me")
            link = root / "link"
            link.symlink_to(output, target_is_directory=True)
            with self.assertRaisesRegex(report.ReportError, "symlink"):
                report.write_artifacts(normalized, link)

    def test_cli_does_not_execute_commands_and_fails_without_writes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            payload = valid_report()
            sentinel = root / "executed"
            payload["tests"][0]["command"] = f"touch {sentinel}; $(touch {sentinel})"
            event_file = root / "event.json"
            event_file.write_text(json.dumps(valid_event(payload)))
            output = root / "out"
            command = [sys.executable, str(Path(report.__file__)), "validate", "--event", str(event_file), "--output", str(output)]
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(sentinel.exists())
            self.assertFalse(json.loads((output / "post.json").read_text())["published"])
            bad_output = root / "bad-out"
            event_file.write_text('{"pull_request":')
            command[-1] = str(bad_output)
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("malformed JSON", result.stderr)
            self.assertFalse(bad_output.exists())

    def test_oversized_event_is_rejected_before_output_creation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            event_file = root / "event.json"
            event_file.write_bytes(b" " * (report.MAX_EVENT_BYTES + 1))
            output = root / "out"
            command = [sys.executable, str(Path(report.__file__)), "validate", "--event", str(event_file), "--output", str(output)]
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("2 MiB", result.stderr)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
