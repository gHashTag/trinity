import type { CronEntry, CronsManifest } from './cronsLoader.ts'

const SEGMENT = /^[A-Za-z0-9_.-]+$/

/** `<kind>/<repo>/<slug>`: three safe segments, no traversal, no URL syntax. */
export function validCronId(id: string): boolean {
  const parts = id.split('/')
  if (parts.length !== 3) return false
  return parts.every((p) => SEGMENT.test(p) && p !== '.' && p !== '..')
}

export function cronExplorerHash(id: string, options: { embedded?: boolean } = {}): string {
  if (!validCronId(id)) throw new Error('Invalid catalog cron id')
  const params = new URLSearchParams({ cron: id })
  if (options.embedded) params.set('embed', '1')
  return `#/crons?${params}`
}

export function canonicalCronUrl(id: string): string {
  return `https://t27.ai/${cronExplorerHash(id)}`
}

/** An explicit broken link must never silently show a different job. */
export function resolveManifestCron(manifest: CronsManifest, id: string | null): CronEntry {
  if (id === null) {
    const first = manifest.crons.find((c) => c.id === manifest.featured) ?? manifest.crons[0]
    if (!first) throw new Error('Cron catalog is empty')
    return first
  }
  cronExplorerHash(id)
  const matches = manifest.crons.filter((c) => c.id === id)
  if (matches.length !== 1) throw new Error(`Cron catalog id is missing or ambiguous: ${id}`)
  return matches[0]
}

// ---------------------------------------------------------------- schedules

/** Five-field cron expression parsed into sets, or null when it is not one. */
export interface CronFields { minute: Set<number>; hour: Set<number>; dom: Set<number>; month: Set<number>; dow: Set<number>; domAny: boolean; dowAny: boolean }

function field(spec: string, min: number, max: number): Set<number> | null {
  const out = new Set<number>()
  for (const part of spec.split(',')) {
    const m = part.match(/^(\*|\d+)(?:-(\d+))?(?:\/(\d+))?$/)
    if (!m) return null
    const step = m[3] ? Number(m[3]) : 1
    let lo = m[1] === '*' ? min : Number(m[1])
    let hi = m[1] === '*' ? max : m[2] !== undefined ? Number(m[2]) : m[3] ? max : Number(m[1])
    if (step < 1 || lo < min || hi > max || lo > hi) return null
    for (let v = lo; v <= hi; v += step) out.add(v === 7 && max === 7 ? 0 : v)
  }
  return out
}

export function parseCron(expr: string): CronFields | null {
  const parts = expr.trim().split(/\s+/)
  if (parts.length !== 5) return null
  const minute = field(parts[0], 0, 59), hour = field(parts[1], 0, 23), dom = field(parts[2], 1, 31), month = field(parts[3], 1, 12), dow = field(parts[4], 0, 7)
  if (!minute || !hour || !dom || !month || !dow) return null
  return { minute, hour, dom, month, dow, domAny: parts[2] === '*', dowAny: parts[4] === '*' }
}

/** The next `count` firings after `from`, computed in UTC. Returns fewer if none within two years. */
export function nextRuns(expr: string, from: Date, count = 3): Date[] {
  const f = parseCron(expr)
  if (!f) return []
  const out: Date[] = []
  const t = new Date(Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), from.getUTCDate(), from.getUTCHours(), from.getUTCMinutes() + 1))
  const limit = from.getTime() + 2 * 366 * 24 * 3600 * 1000
  while (out.length < count && t.getTime() < limit) {
    const dayOk = f.domAny && f.dowAny ? true : f.domAny ? f.dow.has(t.getUTCDay()) : f.dowAny ? f.dom.has(t.getUTCDate()) : f.dom.has(t.getUTCDate()) || f.dow.has(t.getUTCDay())
    if (!f.month.has(t.getUTCMonth() + 1) || !dayOk) { t.setUTCDate(t.getUTCDate() + 1); t.setUTCHours(0, 0, 0, 0); continue }
    if (!f.hour.has(t.getUTCHours())) { t.setUTCHours(t.getUTCHours() + 1, 0, 0, 0); continue }
    if (!f.minute.has(t.getUTCMinutes())) { t.setUTCMinutes(t.getUTCMinutes() + 1, 0, 0); continue }
    out.push(new Date(t))
    t.setUTCMinutes(t.getUTCMinutes() + 1)
  }
  return out
}

/** A human reading of a cron expression in the two page languages. Falls back to the expression. */
export function describeCron(expr: string, lang: 'en' | 'ru'): string {
  const f = parseCron(expr)
  if (!f) return expr
  const parts = expr.trim().split(/\s+/)
  const [min, hr, dom, mon, dow] = parts
  const ru = lang === 'ru'
  const pad = (n: number) => String(n).padStart(2, '0')
  const stepOf = (s: string) => { const m = s.match(/^\*\/(\d+)$/); return m ? Number(m[1]) : null }
  const dayNames = ru ? ['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб'] : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
  if (min === '*' && hr === '*') return ru ? 'каждую минуту' : 'every minute'
  const ms = stepOf(min)
  if (ms && hr === '*' && dom === '*' && mon === '*' && dow === '*') return ru ? `каждые ${ms} мин` : `every ${ms} min`
  const hs = stepOf(hr)
  if (hs && dom === '*' && mon === '*' && dow === '*') return ru ? `каждые ${hs} ч в :${pad(Number(min) || 0)}` : `every ${hs} h at :${pad(Number(min) || 0)}`
  if (hr === '*' && /^\d+$/.test(min) && dom === '*' && mon === '*' && dow === '*') return ru ? `каждый час в :${pad(Number(min))}` : `hourly at :${pad(Number(min))}`
  if (/^\d+$/.test(min) && /^\d+$/.test(hr)) {
    const at = `${pad(Number(hr))}:${pad(Number(min))} UTC`
    if (dom === '*' && mon === '*' && dow === '*') return ru ? `ежедневно в ${at}` : `daily at ${at}`
    if (dom === '*' && mon === '*' && /^\d$/.test(dow)) return ru ? `по ${dayNames[Number(dow) % 7]} в ${at}` : `every ${dayNames[Number(dow) % 7]} at ${at}`
  }
  return expr
}

export function describeInterval(everyMs: number, lang: 'en' | 'ru'): string {
  const ru = lang === 'ru'
  const s = Math.round(everyMs / 1000)
  if (s < 60) return ru ? `каждые ${s} с` : `every ${s} s`
  const m = Math.round(s / 60)
  if (m < 60) return ru ? `каждые ${m} мин` : `every ${m} min`
  const h = m / 60
  if (Number.isInteger(h)) return ru ? (h === 1 ? 'каждый час' : `каждые ${h} ч`) : h === 1 ? 'hourly' : `every ${h} h`
  return ru ? `каждые ${m} мин` : `every ${m} min`
}
