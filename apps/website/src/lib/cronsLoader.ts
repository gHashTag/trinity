// The scheduled-jobs catalog: `public/crons/manifest.json` is written by
// scripts/sync-crons.mjs, which reads the three repositories on disk and the
// hand-kept Railway service list. The page reads only this committed file.

export type CronKind = 'railway-cron' | 'inngest' | 'timer' | 'github-actions'
export type Health = 'ok' | 'warn' | 'fail'

export interface CronSchedule {
  kind: 'cron' | 'interval'
  /** Five-field cron expression, for kind 'cron'. */
  expr?: string
  /** Period in milliseconds, for kind 'interval'. */
  everyMs?: number
  /** The source text the period was read from, e.g. `10 * 60 * 1000`. */
  raw?: string
  tz: string
}

export interface CronProbe {
  url: string
  dns: boolean
  http: number | null
  at: string
}

export interface CronEntry {
  /** `<kind>/<repo>/<slug>` */
  id: string
  kind: CronKind
  repo: string
  name: string
  schedule: CronSchedule
  where: { file: string | null; line: number | null; host: string; service: string | null }
  what: string
  note: string | null
  sourceUrl: string | null
  repoPrivate: boolean
  probe: CronProbe | null
  tags: string[]
  health: Health
}

/**
 * A live Railway service the sync probed while building the catalog.
 *
 * Not a schedule: these are the long-running services the scheduled jobs talk
 * to, recorded so the page can say whether the surroundings answered at the
 * moment the manifest was built.
 */
export interface CronHost {
  name: string
  role: string
  domain: string
  dns: boolean
  http: number | null
  at: string
}

export interface CronsManifest {
  version: number
  generatedAt: string
  generatedFrom: { repo: string; commit: string; shortCommit: string; branch: string; dirty: boolean; private: boolean }[]
  cronCount: number
  byKind: Record<string, number>
  byRepo: Record<string, number>
  byHost: Record<string, number>
  tags: Record<string, number>
  health: Record<Health, number>
  featured: string
  crons: CronEntry[]
  hosts?: CronHost[]
}

let manifestPromise: Promise<CronsManifest> | null = null

export function loadCronsManifest(): Promise<CronsManifest> {
  if (!manifestPromise) {
    manifestPromise = fetch('crons/manifest.json', { credentials: 'omit' }).then((r) => {
      if (!r.ok) throw new Error(`could not load crons manifest (${r.status})`)
      return r.json() as Promise<CronsManifest>
    })
    manifestPromise.catch(() => { manifestPromise = null })
  }
  return manifestPromise
}
