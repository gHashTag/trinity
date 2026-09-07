# Repository worlds — contract before implementation

2026-09-07, issue #890. Each world is keyed by canonical `owner/repo`, never an
issue number alone. Pinned worlds: gHashTag/trios (existing Queen runtime) and
gHashTag/t27 (its own public issue map). Added public repositories are remembered
on this device; this is not a global user account or a worker installation.

## Observable contract

- World switching unmounts the previous source/scene and aborts in-flight reads.
  No trios worker, review, module, FPGA or T27 coverage claim may appear in t27
  or another user's world. Same issue numbers stay isolated by repository.
- Public GitHub metadata must confirm repository identity and public visibility.
  Fetch issues in explicit pages of 100. Exclude pull requests; distinguish an
  empty complete map, a partial page, failed loading, and retained stale data.
  No 5-second anonymous GitHub polling. Manual refresh/load-more have a cooldown.
- Open issues begin red. Closed issues without proof remain red. No inference
  of running Bees, Queen approval or T27 coverage from labels/closure alone.
- Hash route `#/queen?repo=owner/repo` opens/share-links an independent world.
  URL parsing accepts only repository identifiers or exact https GitHub URLs.
  localStorage stores public repository names, never access tokens or claims.
- Existing Railway `t27-github-collab` is the OAuth authority. Reuse its
  public_repo scope, HttpOnly Secure Lax token cookie and fixed allowed origin.
  Add a top-level `/queen/connect` picker: identity and repository listing happen
  on the server's origin, not in cross-site fetches that lose Lax cookies.
  GitHub consent is performed by each user, never silently by an agent.
- OAuth return destination is an allowlisted enum (specs/queen), not a supplied
  URL. Escape all HTML, keep tokens out of markup/URLs/logs and clear state on
  callback. Picker returns only a validated public repo name to the game.
- No private scopes, new service, secrets, production deployment or background
  workers in this change. A newly implemented server route stays visibly gated
  until its health capability is present. Local unauthenticated route tests do
  not count as a successful live OAuth end-to-end test.

## Plan

1. Verify existing Railway/OAuth and source. OBSERVED: deployment
   4f364bdf-9eeb-49ba-9e51-38d1bd1c90cd is SUCCESS, not stopped.
2. TDD repository parsing, metadata/issue boundary, pagination and stale reads.
3. Add world selector, public-repository connection and T27 map with brand UI.
4. Extend the existing Zig OAuth service with the same-origin account picker.
5. Test/build both exact artifacts; desktop/mobile and source-isolation QA.

Primary references: [GitHub repository issues](https://docs.github.com/en/rest/issues/issues#list-repository-issues)
(issues API also returns PRs; pagination max100) and
[GitHub Apps](https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps/about-creating-github-apps).
The existing service uses an OAuth App, not a GitHub App; do not claim otherwise.
