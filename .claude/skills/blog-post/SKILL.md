---
name: blog-post
description: Write and publish a post to the t27.ai blog. Covers where the site actually is, the provenance rules a post must meet before it ships, the build gate, and the traps that have already cost a session. Use for any blog writing, editing, or publishing on t27.ai.
---

# Writing for the t27.ai blog

The blog exists to publish things that are **true and checkable**. A post that
overstates is worse than no post, because the people who would catch it are the
people we work with — the openXC7 maintainers read this.

## Where the site is

**`gHashTag/trinity` at `/Users/playom/trinity`.** Not `trinity-fpga`.

`trinity-fpga/docs` is a copy carrying the same `docusaurus.config.ts` (same
`url: 'https://t27.ai'`), so it looks authoritative and is not deployed. Editing
it changes nothing live. A whole article was once written into it before anyone
noticed.

- Posts: `docs/blog/YYYY-MM-DD-<slug>.md`
- Authors: `docs/blog/authors.yml` — every `authors:` key a post references must
  exist here or the build fails
- Live at `https://t27.ai/docs/blog/<slug>/`
- Deploy: `.github/workflows/deploy-docs.yml`, **triggers only on push to
  `main`**. Pushing a branch publishes nothing.

## Before you write a sentence: the provenance rules

Every load-bearing claim needs a source you actually queried in this session.

**Ages come from `git blame` of the specific line, never from the file's date.**
A file with 59 commits tells you nothing about when one line was written. Use
GitHub's GraphQL blame against the commit *before* the fix:

```bash
gh api graphql -f query='
{ repository(owner:"OWNER", name:"REPO") {
    object(expression:"<parent-sha>") { ... on Commit {
      blame(path:"path/to/file.cc") { ranges {
        startingLine endingLine
        commit { oid committedDate messageHeadline author { name } }
      } } } } } }' --jq '.data.repository.object.blame.ranges[]
        | select(.startingLine <= LINE and .endingLine >= LINE)'
```

**Check the state of every issue and PR you mention.** "We fixed X" is false if
X is still open. Confirm with `gh api repos/OWNER/REPO/issues/N --jq '{state}'`
before writing that anything was closed, and read the body — an issue may say
explicitly that the merged fix does *not* resolve it.

**Quote maintainers, don't improve them.** When someone else's caveat bounds
your claim, reproduce their words verbatim in a blockquote.

**Name what is still broken.** Every post about a fix should say what the fix
does not cover. This is the difference between a report and a press release.

**Include the mistake.** The most valuable paragraph is usually the one about
what we got wrong and how we found out. Write it.

## Publishing

The blog is enabled in `docs/docusaurus.config.ts` under the classic preset
(`blog: { path: 'blog', routeBasePath: 'blog', ... }`). With
`docs.routeBasePath: '/'`, posts land under `/docs/blog/`.

**Use npm. Never yarn.** The repo has `package-lock.json` only; running yarn
creates a second lockfile that drifts. **Node ≥ 20** is required — the shell
default here is 18 and npm refuses:

```bash
export PATH="$HOME/.nvm/versions/node/v20.19.0/bin:$PATH"
cd /Users/playom/trinity/docs && npm install && npm run build
```

**The build is the gate.** It must exit 0 and generate
`docs/build/blog/<slug>/index.html`. Then grep that HTML for the specific facts
you claimed — if a fact was dropped, you want to know before it ships. Beware
markdown emphasis when grepping: `does *not* fix it` renders as
`does <em>not</em> fix it`, so a plain-string grep reports a false miss.

**Branch off `origin/main`, never off whatever is checked out.** A branch cut
from a feature branch drags that feature's commits into `main` on merge. Check
before merging:

```bash
git rev-list --count origin/main..HEAD   # should equal your commit count
git log --oneline origin/main..HEAD
```

If it is wrong, cherry-pick your commit onto a fresh branch from `origin/main`.

Merging to `main` **is** the publication. It triggers the deploy and force-pushes
`gh-pages`. Treat it as an outward-facing action and confirm with the operator
unless they have already said to publish.

## Traps already paid for

- **`.gitignore` has a global `*.md`.** `main` now carries `!docs/**`, which
  re-includes posts. If you ever see a post silently missing from `git status`,
  this is why — check with `git check-ignore -v <file>`.
- **`git push` succeeding does not mean the post is live.** Deploy is main-only.
  Verify with `curl -o /dev/null -w '%{http_code}' https://t27.ai/docs/blog/<slug>/`.
- **Exit codes lie when you pipe through `tail`.** `cmd | tail -5` reports
  `tail`'s status. Capture the build log to a file and grep it, or check
  `${PIPESTATUS[0]}`.
- **A green build is not a correct post.** It only proves the markdown parsed.

## Russian versions

Docusaurus i18n is not configured, and turning it on restructures the whole
site. Ship a Russian post as its own file with a `-ru` slug
(`2026-08-14-<slug>-ru.md`, `slug: <slug>-ru`) and translate for sense, not
word-for-word. Keep the same verified numbers — a translation must not soften a
claim or drop a caveat.
