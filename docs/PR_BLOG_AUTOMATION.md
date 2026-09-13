# Every PR has a work report and a blog outcome

## Contract

The author/agent owns an honest report for the current head commit. Put exactly
one JSON block between these markers in the PR description, retaining the rest
of the existing PR template:

<!-- Example only: replace all example claims with actual evidence. -->
````markdown
<!-- t27-work-report -->
```json
{
  "version": 1,
  "head_sha": "REPLACE_WITH_GIT_REV_PARSE_HEAD",
  "summary": "Describe the concrete user-visible problem and the implemented outcome.",
  "changes": ["Describe each substantive change and where it was made."],
  "tests": [{
    "command": "Exact command actually run, or the intended check if not run",
    "status": "not_run",
    "result": "Explain the real result or specific reason it could not run.",
    "evidence": "CI run URL, repository log/artifact path, or precise reproducible observation"
  }],
  "limitations": ["State what this PR does not establish, and remaining failures or risks."],
  "tags": ["Engineering", "Verification"],
  "blog": {
    "title": "A factual engineering lesson from this change",
    "summary": "One sentence explaining what was learned, without claiming unmeasured results.",
    "outline": [
      "The concrete problem, prior behavior and why a reader should care.",
      "The implementation and the evidence supporting its observed result.",
      "The unresolved boundary, what was not tested and what comes next."
    ]
  }
}
```
<!-- /t27-work-report -->
````

Example/placeholder text is not a passing report. `head_sha` must equal the PR's
current head. Tests may honestly be `passed`, `failed` or `not_run`; passing this
report check does **not** replace engineering CI or assert that tests passed.
Report measured results as measured, simulation as simulation, and PR-author
claims as reported unless independently reproduced. Do not include secrets,
customer data, private URLs or unpublished security details in public reports.

## Automation and safety

`pr-blog-report.yml` uses `pull_request_target` and checks out only trusted
`main`. It retrieves the latest PR metadata via GitHub API and parses the body
as JSON. It never executes reported test commands or PR source with secrets.
The `T27 work report` status is written to the PR's **head SHA**, not the base
commit. Opening, editing, synchronizing or reopening a PR regenerates the draft.

The workflow stores `report.json`, `post.json` and a readable `draft.md` as an
artifact. A generated `post.json` remains `published:false`: this is real draft
content, not a claim that an article or illustration is live.

Only merged PRs get a durable, PR-number-keyed blog publication issue. Retries
reuse the issue, including after 24 hours; event deduplication alone is not a
durable ledger. Closed-unmerged PRs never enter the publication queue. A failed
dispatch fails visibly and keeps the draft/task recoverable. Re-run the workflow
with its PR number after resolving a failure.

The exact PR/outbox numbers are sent to `pr-blog-author.yml` by explicit GitHub
workflow dispatch. This uses the repository's existing Claude Code OAuth runtime
and `AGENT_GH_TOKEN` for publication PRs (no repository-wide PR approval setting
is enabled);
missing/expired authorization is a visible failure, never a fake publication.
It does not use the generic Inngest skill event: the inspected consumer ignored
PR payloads and its Queen worker watched `gHashTag/t27`, not this repository.
The daily Inngest schedule and other repositories are left unchanged.

After an acknowledged author dispatch that later fails, rerun the **author**
workflow with the same PR/outbox numbers. The report workflow will not blindly
redispatch an already acknowledged task. The author's per-PR concurrency and
source-receipt search prevent duplicate article creation on a deliberate retry.
GitHub-token-created PRs need explicit report and website CI workflow dispatches;
ordinary PR events may be suppressed by GitHub's recursion protection.

The publication worker must read the exact source PR, merge commit, work report,
diff and CI. It writes a useful article through `.claude/skills/blog-post/SKILL.md`
in the existing `apps/website/src/data/blog/` schema, with receipts,
`openQuestions`, complete body, meaningful tags and a relevant existing service
offer. EN/RU versions must preserve the same factual limits. No title-only posts.

Use the intact 1200 × 630 engraved three-panel img2img artwork with the established
references. Honor GPT Image 2 preference; never invent a model ID the runtime
does not expose. If generation is unavailable, keep the draft/task pending:
do not substitute a generic title card or silently ship without a picture.

Before creating an article, find an existing article by **source PR receipt and
topic**, not just slug. If the PR already publishes a blog article, its outcome
is that article: verify it and link it, without recursively creating a new
article/PR about publishing an article. Close the publication task only after
the canonical live article, body, image, hashtags and offer are verified.

Social promotion belongs to the existing paced queue, not one instant blast per
PR: X `@t27_dev`, personal LinkedIn `neurocoder`, Telegram `@t27_lang` only. Use
English X/LinkedIn and Russian Telegram when translated; one X hashtag and two
or three LinkedIn/Telegram hashtags, derived from article tags. Deduplicate
published and scheduled topics and use the complete triptych with ALT.

## Required merge gate

The repository setting must require `T27 work report` from GitHub Actions on
`main`. Merely adding YAML or this document does not enforce merging. Configure
the rule only after the workflow is installed and its real status has been
observed. Preserve unrelated protection/review rules. Administrators should not
bypass the report; emergency changes still need an honest report.

Validation commands (no network/publication):

```sh
python3 -m unittest discover -s scripts -p 'test_pr_blog*.py' -v
python3 scripts/pr_blog_report.py validate --event /path/to/github-event.json --output /tmp/pr-blog-draft
```

References: [GitHub required statuses](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks),
[trusted pull_request_target execution](https://github.com/github/docs/blob/main/content/actions/reference/security/securely-using-pull_request_target.md),
[Inngest's 24-hour event deduplication](https://www.inngest.com/docs/guides/handling-idempotency).
