// The last real run of a scheduled job, read at runtime from the host that ran
// it — never from the build. A GitHub Actions job asks the public Actions API
// for its workflow's newest run; anything the browser cannot read live (a
// private repository, a Railway cron, a launchd job on the owner's Mac) says
// so instead of showing a date that was true when the site was built.

import type { CronEntry } from './cronsLoader'

export type LastRun =
  | { kind: 'run'; at: string; event: string; status: string; conclusion: string | null; url: string }
  | { kind: 'none' }
  | { kind: 'unavailable'; reason: 'private' | 'no-source' | 'error'; detail?: string }

const OWNER = 'gHashTag'

/** The Actions API URL for an entry, or null when there is no public live source. */
export function lastRunSource(c: CronEntry): string | null {
  if (c.kind !== 'github-actions' || c.repoPrivate || !c.where.file) return null
  const file = c.where.file.split('/').pop()
  if (!file) return null
  return `https://api.github.com/repos/${OWNER}/${encodeURIComponent(c.repo)}/actions/workflows/${encodeURIComponent(file)}/runs?per_page=1`
}

const cache = new Map<string, Promise<LastRun>>()

export function loadLastRun(c: CronEntry): Promise<LastRun> {
  const url = lastRunSource(c)
  if (!url) {
    return Promise.resolve({
      kind: 'unavailable',
      reason: c.kind === 'github-actions' && c.repoPrivate ? 'private' : 'no-source',
    })
  }
  let p = cache.get(url)
  if (!p) {
    p = fetch(url, { credentials: 'omit', headers: { Accept: 'application/vnd.github+json' } })
      .then(async (r): Promise<LastRun> => {
        if (!r.ok) return { kind: 'unavailable', reason: 'error', detail: `HTTP ${r.status}` }
        const body = (await r.json()) as { workflow_runs?: Array<Record<string, unknown>> }
        const run = body.workflow_runs?.[0]
        if (!run) return { kind: 'none' }
        return {
          kind: 'run',
          at: String(run.created_at),
          event: String(run.event),
          status: String(run.status),
          conclusion: (run.conclusion as string | null) ?? null,
          url: String(run.html_url),
        }
      })
      .catch((e): LastRun => ({ kind: 'unavailable', reason: 'error', detail: String(e) }))
    // A failure is not cached: the next open asks again.
    p.then((v) => { if (v.kind === 'unavailable') cache.delete(url) })
    cache.set(url, p)
  }
  return p
}
