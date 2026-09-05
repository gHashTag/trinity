// Contribute back: propose an edit, or report what the compiler measured.
//
// No backend and no GitHub App. This page is a static SPA on GitHub Pages --
// there is nowhere to keep a client secret or receive a webhook, so an OAuth
// app is not on the table here. What IS on the table is better than it sounds:
//
//   * GitHub's own edit URL already does the fork-and-PR dance. Open it as
//     someone without push access and GitHub forks the repo, commits to a
//     branch, and offers the pull request. That is the "auto PR" path, using
//     the visitor's own session, with no credentials passing through us.
//   * Issue URLs accept a prefilled title and body, so a bug report can carry
//     the numbers the page just measured instead of "it doesn't work".
//
// The editor's draft is deliberately NOT pushed into the URL: GitHub's `value`
// parameter only applies to NEW files, and a multi-kilobyte spec would blow
// past URL length limits well before it got there. The button opens the file
// for editing and the visitor pastes -- honest about what it can do.

import type { SpecEntry, T27Analysis } from '../lib/t27Compiler'
import { specUrl } from './SpecShare'

const MONO = "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace"

/**
 * Where a spec actually lives.
 *
 * t27 paths are repo-root-relative already; everything else was namespaced
 * `<repo>/<path>` at sync time and has to be split back apart, or the link
 * points at a file that does not exist.
 */
function origin(spec: SpecEntry): { repo: string; path: string } {
  if (spec.repo === 't27') return { repo: 't27', path: spec.path }
  const prefix = `${spec.repo}/`
  return {
    repo: spec.repo,
    path: spec.path.startsWith(prefix) ? spec.path.slice(prefix.length) : spec.path,
  }
}

export function SpecContribute({
  spec,
  result,
  edited,
  labels,
}: {
  spec: SpecEntry
  result: T27Analysis | null
  /** True when the draft differs from the shipped file. */
  edited: boolean
  labels: { contribute: string; propose: string; report: string }
}) {
  const { repo, path } = origin(spec)
  const editHref = `https://github.com/gHashTag/${repo}/edit/main/${path}`

  // A report is only worth filing if the compiler found something.
  const problems: string[] = []
  if (spec.failedBackends.length) problems.push(`\`${spec.failedBackends.join('`, `')}\` rejected the spec`)
  if (spec.loss > 0) problems.push(`${spec.loss} item(s) dropped by parser error recovery while still reporting a successful parse`)
  if (spec.tcErrors > 0) problems.push(`${spec.tcErrors} type error(s)`)

  const firstTcError = result?.typecheck?.errors?.[0]
  const firstBackendError = spec.failedBackends.length
    ? result?.targets?.[spec.failedBackends[0]]?.error
    : undefined

  const body = [
    `**Spec:** \`${path}\` (${repo})`,
    `**Seen at:** ${specUrl(spec.path)}`,
    '',
    '### What the compiler reports',
    '',
    '| | |',
    '|---|---|',
    `| tokens | ${spec.tokens.toLocaleString()} |`,
    `| AST nodes | ${spec.nodes.toLocaleString()} (depth ${spec.depth}) |`,
    `| type errors | ${spec.tcErrors} |`,
    `| dropped by recovery | ${spec.loss} |`,
    `| backends emitting | ${Object.values(spec.outBytes).filter((v) => v).length} of 5 |`,
    '',
    problems.length ? `### Problems\n\n- ${problems.join('\n- ')}` : '### Observation\n\nNothing failed; filing for discussion.',
    firstBackendError ? `\n\`\`\`\n${firstBackendError}\n\`\`\`` : '',
    firstTcError ? `\nFirst type error:\n\n\`\`\`\n${firstTcError}\n\`\`\`` : '',
    '',
    '---',
    '',
    'Filed from the Spec Explorer. Every number above came from running the real compiler (WebAssembly build of `bootstrap/src/compiler.rs`) in the browser, not from a reimplementation.',
  ].filter(Boolean).join('\n')

  const title = problems.length
    ? `${path}: ${problems[0].replace(/`/g, '')}`
    : `${path}: observation from the Spec Explorer`

  const issueHref =
    `https://github.com/gHashTag/${repo}/issues/new` +
    `?title=${encodeURIComponent(title)}&body=${encodeURIComponent(body)}`

  const pill: React.CSSProperties = {
    background: 'transparent',
    border: '1px solid rgba(0,255,136,0.18)',
    borderRadius: 999,
    color: '#8b9490',
    padding: '2px 10px',
    fontSize: 10.5,
    fontFamily: MONO,
    textDecoration: 'none',
    whiteSpace: 'nowrap',
  }

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 5, flexWrap: 'wrap' }}>
      <span style={{ fontSize: 10, color: '#8b9490', opacity: 0.7, fontFamily: MONO }}>{labels.contribute}</span>
      <a
        href={editHref}
        target="_blank"
        rel="noopener noreferrer"
        title="Opens GitHub's editor. Without push access GitHub forks the repo and opens a pull request for you."
        style={{ ...pill, ...(edited ? { color: '#FFD700', borderColor: '#FFD700' } : {}) }}
      >
        {labels.propose}
      </a>
      <a
        href={issueHref}
        target="_blank"
        rel="noopener noreferrer"
        style={{ ...pill, ...(problems.length ? { color: '#f0a020', borderColor: 'rgba(240,160,32,0.4)' } : {}) }}
      >
        {labels.report}
        {problems.length > 0 && ` (${problems.length})`}
      </a>
    </div>
  )
}
