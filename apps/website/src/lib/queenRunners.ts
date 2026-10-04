/**
 * MY RUNNERS: the cabinet half of "lend a lane without lending a key".
 *
 * The swarm runs every bee on one provider key, and the honest way to add a
 * lane is the one where the key never moves: a runner on the lender's own
 * machine, under the lender's own account, takes a task and brings the work
 * back. This page never sees that key and has no field for one. What it hands
 * out is a RUNNER TOKEN — it lets a process speak as one of your runners and
 * can spend nobody's quota — minted by the Queen (trios-agent-server,
 * /queen/me/runners) for the person the app's own session names.
 *
 * WHERE THE CREDENTIAL COMES FROM. Only the app's own copy of the board
 * (https://app.t27.ai/queen/) holds the person's session, read through
 * appSessionIdentity.ts on the same terms as everywhere else: memory only,
 * `credentials: 'omit'`, exactly two headers. On t27.ai the panel says where to
 * go instead of reaching for the bridge's game token, which is scoped to
 * read-only tools and is not this page's to forward.
 *
 * Pure apart from `env`, so qa/queen-runners-contract.mjs drives the real code.
 * The Queen's address arrives in `env.base` (the component passes QUEEN_API)
 * rather than being imported here: queenApi.ts reads Vite's import.meta.env,
 * which a contract running under node does not have.
 */
export const CABINET_PATH = '/queen/me/runners'
/** Where a person on t27.ai is sent to manage runners: the app's board. */
export const CABINET_HOME = 'https://app.t27.ai/queen/#/queen?tab=leaderboard'

export interface RunnerView {
  id: number
  label: string
  lane: number
  tokenHint: string
  createdAt: string
  lastSeenAt: string | null
  state: 'never-seen' | 'online' | 'offline'
}

export interface Cabinet {
  runners: RunnerView[]
  limit: number
}

/** What the panel can be showing. A token appears only in `minted`, once. */
export type CabinetView =
  | { state: 'signin' }
  /**
   * The Queen answered, and the cabinet is not on her yet: a 404 on its path.
   * A server that has the cabinet answers that path 200, 401 or 503 and never
   * 404, so this is "not deployed", not "down" - and saying "she did not
   * answer" to someone she just answered is the one wrong thing to show.
   */
  | { state: 'pending' }
  | { state: 'unavailable' }
  | { state: 'ready'; cabinet: Cabinet }
  | { state: 'minted'; cabinet: Cabinet; token: string; runner: RunnerView }
  | { state: 'refused'; cabinet: Cabinet; reason: 'limit' | 'label' }

export interface RunnersEnv {
  fetch: (
    url: string,
    init: { method: string; credentials: 'omit'; headers: Record<string, string>; body?: string },
  ) => Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>
  /** The app session's access token, or null when nobody is signed in here. */
  token: () => string | null
  /** The Queen's origin, e.g. QUEEN_API. */
  base: string
}

const isRecord = (v: unknown): v is Record<string, unknown> =>
  !!v && typeof v === 'object' && !Array.isArray(v)

const STATES = new Set(['never-seen', 'online', 'offline'])

/** One runner from the wire, or null. Everything is DATA: rendered as text. */
export function runnerOf(raw: unknown): RunnerView | null {
  if (!isRecord(raw)) return null
  const { id, label, lane, tokenHint, createdAt, lastSeenAt, state } = raw
  if (!Number.isSafeInteger(id) || typeof label !== 'string' || !Number.isSafeInteger(lane)) return null
  if (typeof tokenHint !== 'string' || !/^[A-Za-z0-9_-]{4}$/.test(tokenHint)) return null
  if (typeof state !== 'string' || !STATES.has(state)) return null
  return {
    id: id as number,
    label: label.slice(0, 40),
    lane: lane as number,
    tokenHint,
    createdAt: typeof createdAt === 'string' ? createdAt : '',
    lastSeenAt: typeof lastSeenAt === 'string' ? lastSeenAt : null,
    state: state as RunnerView['state'],
  }
}

export function cabinetOf(raw: unknown): Cabinet {
  const body = isRecord(raw) ? raw : {}
  const runners = Array.isArray(body.runners)
    ? body.runners.map(runnerOf).filter((r): r is RunnerView => r !== null)
    : []
  const limit = Number.isSafeInteger(body.limit) && (body.limit as number) > 0 ? (body.limit as number) : 5
  return { runners, limit }
}

/** A runner token as the Queen mints it, and nothing that merely resembles one. */
export const RUNNER_TOKEN = /^qr_[A-Za-z0-9_-]{43}$/

export type RunnersCall =
  | { kind: 'list' }
  | { kind: 'create'; label: string }
  | { kind: 'revoke'; id: number }

/**
 * One call to the cabinet, and the view it leaves. `previous` is what the panel
 * showed, so a refused create keeps the list on screen instead of blanking it.
 */
export async function callRunners(env: RunnersEnv, call: RunnersCall, previous?: Cabinet): Promise<CabinetView> {
  const token = env.token()
  if (!token) return { state: 'signin' }
  const base = `${env.base.replace(/\/+$/, '')}${CABINET_PATH}`
  const headers = { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` }
  const list = async (): Promise<CabinetView> => {
    const res = await env.fetch(base, { method: 'GET', credentials: 'omit', headers })
    if (res.status === 401) return { state: 'signin' }
    if (res.status === 404) return { state: 'pending' }
    if (!res.ok) return { state: 'unavailable' }
    return { state: 'ready', cabinet: cabinetOf(await res.json().catch(() => ({}))) }
  }

  if (call.kind === 'list') return list()

  if (call.kind === 'revoke') {
    if (!Number.isSafeInteger(call.id) || call.id <= 0) return list()
    const res = await env.fetch(`${base}/${call.id}`, { method: 'DELETE', credentials: 'omit', headers })
    if (res.status === 401) return { state: 'signin' }
    if (!res.ok && res.status !== 404) return { state: 'unavailable' }
    return list()
  }

  const label = call.label.replace(/\s+/g, ' ').trim().slice(0, 40)
  const kept = previous ?? { runners: [], limit: 5 }
  if (!label) return { state: 'refused', cabinet: kept, reason: 'label' }
  const res = await env.fetch(base, {
    method: 'POST',
    credentials: 'omit',
    headers,
    body: JSON.stringify({ label }),
  })
  if (res.status === 401) return { state: 'signin' }
  if (res.status === 404) return { state: 'pending' }
  if (res.status === 409) return { state: 'refused', cabinet: kept, reason: 'limit' }
  if (res.status === 400) return { state: 'refused', cabinet: kept, reason: 'label' }
  if (!res.ok) return { state: 'unavailable' }
  const body = await res.json().catch(() => ({}))
  const runner = isRecord(body) ? runnerOf(body.runner) : null
  const minted = isRecord(body) && typeof body.token === 'string' && RUNNER_TOKEN.test(body.token) ? body.token : null
  if (!runner || !minted) return { state: 'unavailable' }
  const after = await list()
  const cabinet = after.state === 'ready' ? after.cabinet : { ...kept, runners: [...kept.runners, runner] }
  return { state: 'minted', cabinet, token: minted, runner }
}

/**
 * The branch the Queen's production service is built from, so the script a
 * person downloads is the one the server they connect to speaks.
 */
export const RUNNER_BRANCH = 'fix/queen-worker-provider-and-prompt-size'

/** The runner script and its instructions, in the Queen's own repository. */
export const RUNNER_SCRIPT_URL = `https://raw.githubusercontent.com/gHashTag/BrowserOS/${RUNNER_BRANCH}/trios/agent-server/tools/queen-runner/queen-runner.mjs`
export const RUNNER_README_URL = `https://github.com/gHashTag/BrowserOS/blob/${RUNNER_BRANCH}/trios/agent-server/tools/queen-runner/README.md`

/**
 * The lines a person pastes on their own machine. The provider key is never
 * part of anything this page writes, stores or sends: the runner's agent uses
 * whatever key the person already has set up there.
 */
export function setupLines(token: string, base: string): string[] {
  return [
    `export TRIOS_QUEEN_URL=${base}`,
    `export TRIOS_RUNNER_TOKEN=${token}`,
    'export TRIOS_RUNNER_REMOTE=https://github.com/<you>/<your-public-fork>.git',
    `curl -fsSLO ${RUNNER_SCRIPT_URL}`,
    'node queen-runner.mjs',
  ]
}
