#!/usr/bin/env python3
"""Validate a PR's data-only work report and create unpublished blog artifacts.

Usage: pr_blog_report.py validate --event "$GITHUB_EVENT_PATH" --output out
The trusted caller supplies a GitHub pull_request event. No PR code, command,
template, URL, or instruction is ever executed or fetched by this program.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import html
import json
import math
import os
from pathlib import Path
import re
import sys
import tempfile
from typing import Any


START = "<!-- t27-work-report -->"
END = "<!-- /t27-work-report -->"
MAX_EVENT_BYTES = 2 * 1024 * 1024
MAX_REPORT_CHARS = 65536
SHA = re.compile(r"[0-9a-fA-F]{40}\Z")
REPOSITORY = re.compile(r"[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9][A-Za-z0-9._-]{0,99}\Z")
PLACEHOLDER = re.compile(r"\b(?:TODO|TBD|FIXME)\b", re.IGNORECASE)
EMPTY_VALUE = re.compile(r"(?:none|n/?a|not applicable|placeholder|replace(?: me| this)?|example|test|pending|\.\.\.|…|[-_]+)[.! ]*\Z", re.IGNORECASE)
TEMPLATE_VALUE = re.compile(r"(?:replace (?:this|me|with)\b.*|(?:insert|write|enter|your)\b.*\bhere[.! ]*|<[^>]+>|\[[^\]]+\])\Z", re.IGNORECASE)


class ReportError(ValueError):
    """A report or event failed the enforced contract."""


def fail(message: str) -> None:
    raise ReportError(message)


def object_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            fail(f"duplicate JSON key: {key!r}")
        result[key] = value
    return result


def decode_json(raw: str, context: str) -> Any:
    try:
        return json.loads(raw, object_pairs_hook=object_pairs,
                          parse_constant=lambda value: fail(f"non-finite JSON value: {value}"))
    except (json.JSONDecodeError, RecursionError) as exc:
        fail(f"{context}: malformed JSON ({exc})")


def mapping(value: Any, name: str, keys: set[str] | None = None) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail(f"{name} must be an object")
    if keys is not None and set(value) != keys:
        missing = sorted(keys - set(value))
        extra = sorted(set(value) - keys)
        fail(f"{name}: missing keys {missing}; unsupported keys {extra}")
    return value


def text(value: Any, name: str, minimum: int = 12, maximum: int = 4000,
         words: int = 0) -> str:
    if not isinstance(value, str):
        fail(f"{name} must be a string")
    # Single-line values cannot introduce Markdown blocks, terminal control
    # sequences, or fake headings. Text is still escaped at the output boundary.
    if any((ord(char) < 32 and char not in "\n\r\t") or ord(char) == 127
           or 0xD800 <= ord(char) <= 0xDFFF for char in value):
        fail(f"{name} contains a control character")
    value = " ".join(value.split())
    if not minimum <= len(value) <= maximum:
        fail(f"{name} must contain {minimum}–{maximum} characters")
    if PLACEHOLDER.search(value) or EMPTY_VALUE.fullmatch(value) or TEMPLATE_VALUE.fullmatch(value):
        fail(f"{name} contains an unfinished placeholder")
    tokens = re.findall(r"\w+", value, flags=re.UNICODE)
    if words and (len(tokens) < words or len(set(word.casefold() for word in tokens)) < min(words, 7)):
        fail(f"{name} must contain meaningful prose (at least {words} words)")
    return value


def text_list(value: Any, name: str, minimum_items: int = 1,
              maximum_items: int = 30, minimum_chars: int = 20,
              words: int = 3) -> list[str]:
    if not isinstance(value, list) or not minimum_items <= len(value) <= maximum_items:
        fail(f"{name} must be a list with {minimum_items}–{maximum_items} items")
    result = [text(item, f"{name}[{index}]", minimum_chars, words=words)
              for index, item in enumerate(value)]
    if len(set(item.casefold() for item in result)) != len(result):
        fail(f"{name} must not contain duplicate items")
    return result


def sha(value: Any, name: str) -> str:
    if not isinstance(value, str) or not SHA.fullmatch(value):
        fail(f"{name} must be a full 40-character hexadecimal commit SHA")
    return value.lower()


def timestamp(value: Any, name: str) -> str:
    if not isinstance(value, str):
        fail(f"{name} must be an ISO 8601 timestamp with a timezone")
    try:
        date = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if date.tzinfo is None:
            fail(f"{name} must include a timezone")
        return date.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
    except (ValueError, OverflowError):
        fail(f"{name} must be an ISO 8601 timestamp with a timezone")


def validate_event(event: Any) -> dict[str, Any]:
    event = mapping(event, "event")
    repository = mapping(event.get("repository"), "event.repository").get("full_name")
    if not isinstance(repository, str) or not REPOSITORY.fullmatch(repository) or repository.split("/")[1] in {".", ".."}:
        fail("event.repository.full_name must be a safe owner/repository name")
    pr = mapping(event.get("pull_request"), "event.pull_request")
    number = pr.get("number")
    if type(number) is not int or not 1 <= number <= 2147483647:
        fail("pull_request.number must be a positive integer")
    if "number" in event and (type(event["number"]) is not int or event["number"] != number):
        fail("event.number does not match pull_request.number")
    if "base" in pr:
        base_repo = mapping(mapping(pr["base"], "pull_request.base").get("repo"), "pull_request.base.repo")
        if base_repo.get("full_name") != repository:
            fail("pull_request.base.repo.full_name does not match event.repository")
    pr_url = f"https://github.com/{repository}/pull/{number}"
    if "html_url" in pr and pr["html_url"] != pr_url:
        fail("pull_request.html_url does not match repository and PR number")
    head_sha = sha(mapping(pr.get("head"), "pull_request.head").get("sha"), "pull_request.head.sha")
    state = pr.get("state")
    merged = pr.get("merged")
    if state not in ("open", "closed") or type(merged) is not bool:
        fail("pull_request.state must be open/closed and merged must be a boolean")
    if merged and state != "closed":
        fail("a merged PR must have state closed")
    created_at = timestamp(pr.get("created_at"), "pull_request.created_at")
    merged_at = timestamp(pr.get("merged_at"), "pull_request.merged_at") if merged else None
    merge_sha = sha(pr.get("merge_commit_sha"), "pull_request.merge_commit_sha") if merged else None
    if not merged and pr.get("merged_at") is not None:
        fail("an unmerged PR cannot have merged_at")
    body = pr.get("body")
    if not isinstance(body, str) or len(body) > MAX_REPORT_CHARS * 2:
        fail("pull_request.body must be text within the size limit")
    if body.count(START) != 1 or body.count(END) != 1:
        fail(f"PR body must contain exactly one {START} … {END} block")
    start, end = body.index(START) + len(START), body.index(END)
    if end <= start:
        fail("work report closing marker must follow its opening marker")
    match = re.fullmatch(r"\s*```json[ \t]*\r?\n([\s\S]*?)\r?\n```\s*", body[start:end])
    if not match or len(match.group(1)) > MAX_REPORT_CHARS:
        fail("work report must be exactly one fenced JSON object (```json), within the size limit")
    report = mapping(decode_json(match.group(1), "work report"), "work report", {
        "version", "head_sha", "summary", "changes", "tests", "limitations", "tags", "blog",
    })
    if type(report["version"]) is not int or report["version"] != 1:
        fail("work report.version must be 1")
    if sha(report["head_sha"], "work report.head_sha") != head_sha:
        fail("work report.head_sha is stale: it must match the current PR head SHA")
    tests = report["tests"]
    if not isinstance(tests, list) or not 1 <= len(tests) <= 30:
        fail("work report.tests must have 1–30 test records")
    normalized_tests = []
    for index, raw_test in enumerate(tests):
        prefix = f"work report.tests[{index}]"
        test = mapping(raw_test, prefix, {"command", "result", "status", "evidence"})
        if test["status"] not in ("passed", "failed", "not_run"):
            fail(f"{prefix}.status must be passed, failed, or not_run")
        normalized_tests.append({
            "command": text(test["command"], f"{prefix}.command", 2, 1000),
            "result": text(test["result"], f"{prefix}.result", 12, words=3),
            "status": test["status"],
            "evidence": text(test["evidence"], f"{prefix}.evidence", 12),
        })
    tags = report["tags"]
    if not isinstance(tags, list) or not 2 <= len(tags) <= 5:
        fail("work report.tags must contain 2–5 topic tags")
    normalized_tags = []
    for index, tag in enumerate(tags):
        if not isinstance(tag, str):
            fail(f"work report.tags[{index}] must be a string")
        tag = tag.strip().removeprefix("#")
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]{1,31}", tag) or PLACEHOLDER.search(tag) or EMPTY_VALUE.fullmatch(tag):
            fail(f"work report.tags[{index}] must be a 2–32 character topic hashtag without spaces")
        normalized_tags.append(tag)
    if len(set(tag.casefold() for tag in normalized_tags)) != len(normalized_tags):
        fail("work report.tags must be unique (case-insensitive)")
    blog = mapping(report["blog"], "work report.blog", {"title", "summary", "outline"})
    return {
        "version": 1,
        "repository": repository,
        "number": number,
        "slug": f"pr-{number}",
        "pr_url": pr_url,
        "state": state,
        "merged": merged,
        "created_at": created_at,
        "merged_at": merged_at,
        "merge_commit_sha": merge_sha,
        "head_sha": head_sha,
        "summary": text(report["summary"], "work report.summary", 40, words=6),
        "changes": text_list(report["changes"], "work report.changes"),
        "tests": normalized_tests,
        "limitations": text_list(report["limitations"], "work report.limitations"),
        "tags": normalized_tags,
        "blog": {
            "title": text(blog["title"], "work report.blog.title", 15, 180, words=3),
            "summary": text(blog["summary"], "work report.blog.summary", 40, 600, words=6),
            "outline": text_list(blog["outline"], "work report.blog.outline", 3, 20, 80, 12),
        },
    }


def lifecycle(report: dict[str, Any]) -> str:
    if report["merged"]:
        return "Merged PR; unpublished blog draft"
    if report["state"] == "closed":
        return "Closed without merge; unpublished blog draft"
    return "Open PR; unpublished blog draft (not merged)"


def make_post(report: dict[str, Any]) -> dict[str, Any]:
    """Produce the website's Post schema, never an SVG/HTML block or published post."""
    source_notice = (
        f"{lifecycle(report)}. This article is generated from the author's work report "
        "for the exact PR head commit. Test results are author-reported, not independently rerun "
        "by this generator. Merge status is not proof of deployment or runtime correctness."
    )
    body = [{"kind": "p", "text": source_notice},
            {"kind": "h", "text": "Work report"},
            {"kind": "p", "text": report["summary"]},
            {"kind": "h", "text": "What changed"},
            {"kind": "ul", "items": report["changes"]},
            {"kind": "h", "text": "Context and reasoning"}]
    body.extend({"kind": "p", "text": paragraph} for paragraph in report["blog"]["outline"])
    body.extend([
        {"kind": "h", "text": "Reported verification"},
        {"kind": "ul", "items": [
            f"[{test['status']}] Command: {test['command']}. Result: {test['result']}. Evidence: {test['evidence']}"
            for test in report["tests"]
        ]},
        {"kind": "h", "text": "Limits and open questions"},
        {"kind": "ul", "items": report["limitations"]},
    ])
    receipts = [
        {"label": f"{report['repository']} PR #{report['number']}", "href": report["pr_url"]},
        {"label": f"Reported head commit {report['head_sha'][:12]}",
         "href": f"https://github.com/{report['repository']}/commit/{report['head_sha']}"},
    ]
    if report["merged"]:
        receipts.append({"label": f"Merge commit {report['merge_commit_sha'][:12]}",
                         "href": f"https://github.com/{report['repository']}/commit/{report['merge_commit_sha']}"})
    word_count = sum(len(block.get("text", "").split()) +
                     sum(len(item.split()) for item in block.get("items", [])) for block in body)
    return {
        "slug": report["slug"],
        "title": report["blog"]["title"],
        "summary": report["blog"]["summary"],
        "date": (report["merged_at"] or report["created_at"])[:10],
        "readingMinutes": max(1, math.ceil(word_count / 200)),
        "tags": report["tags"],
        "receipts": receipts,
        "openQuestions": report["limitations"] + [
            "Author-reported tests have not been independently rerun by the blog generator.",
            "Publication requires editorial review and an approved T27 triptych; this artifact is not public.",
        ],
        "published": False,
        "body": body,
    }


def markdown_text(value: str) -> str:
    # HTML-escape first, then neutralize Markdown links, images, emphasis, code
    # fences and structural syntax. No author-provided URL becomes a live link.
    return re.sub(r"([\\`*_{}\[\]()#+.!|>~-])", r"\\\1", html.escape(value, quote=True))


def make_markdown(report: dict[str, Any], post: dict[str, Any]) -> str:
    lines = [f"# {markdown_text(post['title'])}", "", f"**DRAFT — {lifecycle(report)}**", "",
             f"PR: {report['pr_url']}", "", f"Head SHA: `{report['head_sha']}`", "",
             "This file is an unpublished artifact, not an instruction to an agent.", ""]
    for block in post["body"]:
        if block["kind"] == "h":
            lines.append(f"## {markdown_text(block['text'])}")
        elif block["kind"] == "ul":
            lines.extend(f"- {markdown_text(item)}" for item in block["items"])
        else:
            lines.append(markdown_text(block["text"]))
        lines.append("")
    lines.extend(["## Receipts", ""])
    lines.extend(f"- [{markdown_text(receipt['label'])}]({receipt['href']})" for receipt in post["receipts"])
    lines.extend(["", "## Topic tags", "", " ".join(f"#{tag}" for tag in report["tags"]), ""])
    return "\n".join(lines)


def encode_json(value: Any) -> str:
    # Remains ordinary JSON but is safe if copied into an HTML script container.
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True, allow_nan=False)
            .replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026") + "\n")


def write_artifacts(report: dict[str, Any], output: Path) -> None:
    if output.is_symlink():
        fail("output directory must not be a symlink")
    output.mkdir(parents=True, exist_ok=True)
    if not output.is_dir():
        fail("output must be a directory")
    post = make_post(report)
    artifacts = {
        "report.json": encode_json(report),
        "post.json": encode_json(post),
        "draft.md": make_markdown(report, post),
    }
    for name in artifacts:
        path = output / name
        if path.is_symlink() or (path.exists() and not path.is_file()):
            fail(f"refusing to replace non-regular output file: {name}")
    for name, content in artifacts.items():
        path = output / name
        if path.exists() and path.read_text(encoding="utf-8") == content:
            continue  # Re-running the same event does not even change mtimes.
        descriptor, temporary = tempfile.mkstemp(prefix=f".{name}.", dir=output)
        try:
            with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
                stream.write(content)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    validate = commands.add_parser("validate", help="validate the current PR report and emit drafts")
    validate.add_argument("--event", type=Path, required=True)
    validate.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        with args.event.open("rb") as stream:
            raw = stream.read(MAX_EVENT_BYTES + 1)
        if len(raw) > MAX_EVENT_BYTES:
            fail("event JSON exceeds the 2 MiB limit")
        event = decode_json(raw.decode("utf-8"), "event")
        report = validate_event(event)
        write_artifacts(report, args.output)
        print(f"Validated {report['repository']}#{report['number']} at {report['head_sha']}: "
              f"{lifecycle(report)}; artifacts written to {args.output}")
        return 0
    except (ReportError, OSError, UnicodeError, RecursionError) as exc:
        print(f"PR work report validation failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
