/**
 * THE PERSON'S OWN BROWSER, AS A VIEW OF THE QUEEN.
 *
 * Owner, 2026-09-21: the browser from the app goes into its own tab here,
 * beside KANBAN. It is the SAME browser -- one pod per person, the one the
 * app's Browser tab shows and the agent drives (gHashTag/999-multibots-telegraf,
 * docs/architecture/remote-browser-per-user.md). Not a copy, not a second pod.
 *
 * WHY THIS CAN WORK HERE AT ALL. The board is served at app.t27.ai/queen/, the
 * same origin as the app (see appSessionIdentity.ts). That gives two things
 * nothing else could:
 *
 *   - the app's access token, read from the tab's own sessionStorage, so the
 *     broker knows whose browser this is without a bridge or a game token;
 *   - the viewer's cookie. The broker answers a PATH, `/live/<id>?t=...`, and
 *     the app's nginx proxies /live/ under this same origin, so the cookie the
 *     window sets is first-party. A cross-site frame would load and then be
 *     refused (SameSite=Lax; WKWebView drops third-party cookies outright).
 *     So a view address that resolves anywhere but our own origin is never
 *     framed -- `frameSrcOf` returns null for it.
 *
 * WHAT THIS VIEW NEVER DOES ON ITS OWN.
 *
 *   - It never STARTS a browser. Opening one wakes a pod and costs a person a
 *     machine; reading the status is free. Only a press of Open posts.
 *   - It never asks for, types or holds a password. Passwords are typed by the
 *     person inside the stream and go straight into the pod.
 *   - It never talks to the pod. Everything it knows is what the broker chose
 *     to say: a state, a session id and a path.
 *
 * Pure and driven through its arguments, so qa/queen-browser-contract.mjs
 * calls the decisions instead of reading this file for reassuring lines.
 */

import type { AppSessionVerdict } from './appSessionIdentity.ts'

/** The broker lives on the render server, like /mcp (triIdentity.RENDER_BASE). */
export const BROKER_BASE = 'https://vibee-render-production.up.railway.app'

/** The only path prefix the broker hands out for a viewer window. */
export const LIVE_PREFIX = '/live/'

/** The app's own Browser tab, for the one place this view cannot frame it. */
export const APP_BROWSER_URL = 'https://app.t27.ai/browser'

export type BrowserState = 'none' | 'starting' | 'live' | 'unavailable' | 'signin'

export interface BrowserView {
  state: BrowserState
  sessionId?: string
  viewUrl?: string
}

/**
 * What the panel is, before any network:
 *
 *   preview  -- a homepage block (?embed=1). Many previews on one page; none
 *               of them may touch a person's browser, not even to read it.
 *   nested   -- the board is itself inside the app (the Hive tab). The app
 *               already has a Browser tab; a pod window inside a board inside
 *               the app is a stamp, so this points there instead.
 *   signin   -- no app session in this tab. Not an error: the ordinary visit.
 *   ready    -- signed in, on the app's own copy of the board.
 */
export type PanelMode = 'preview' | 'nested' | 'signin' | 'ready'

export function panelMode(input: { embedded: boolean; nested: boolean; session: AppSessionVerdict }): PanelMode {
  if (input.embedded) return 'preview'
  if (input.nested) return 'nested'
  // `bridge` means this is not the app's copy of the board (t27.ai, a local
  // build). There is no first-party /live/ there, so nothing to show but the
  // way to the app.
  if (input.session.source !== 'app-session') return 'signin'
  return input.session.state === 'signed-in' ? 'ready' : 'signin'
}

const STATES: readonly BrowserState[] = ['none', 'starting', 'live', 'unavailable', 'signin']

/**
 * The broker's answer, narrowed. An unknown state is `none` rather than passed
 * through: the panel renders one of five states, and a sixth word from a newer
 * server must not reach the screen as a blank.
 */
export function viewOf(answer: unknown): BrowserView {
  const a = (answer && typeof answer === 'object' ? answer : {}) as Record<string, unknown>
  const state = STATES.includes(a.state as BrowserState) ? (a.state as BrowserState) : 'none'
  const view: BrowserView = { state }
  if (typeof a.sessionId === 'string') view.sessionId = a.sessionId
  if (typeof a.viewUrl === 'string') view.viewUrl = a.viewUrl
  return view
}

/**
 * The address to frame, or null when it must not be framed here.
 *
 * Framed only when it resolves to OUR OWN origin under /live/: anywhere else
 * the viewer's cookie is third-party and the window would open and then
 * forget the person. The broker is expected to return a path; an absolute URL
 * is honoured only if it happens to be ours.
 */
export function frameSrcOf(viewUrl: string | undefined, ownOrigin: string): string | null {
  if (!viewUrl) return null
  let url: URL
  try {
    url = new URL(viewUrl, ownOrigin)
  } catch {
    return null
  }
  if (url.origin !== ownOrigin) return null
  if (!url.pathname.startsWith(LIVE_PREFIX)) return null
  return url.toString()
}

export type BrokerCall = 'read' | 'open' | 'close'

const METHOD: Record<BrokerCall, 'GET' | 'POST' | 'DELETE'> = { read: 'GET', open: 'POST', close: 'DELETE' }

export interface BrokerEnv {
  fetch(
    url: string,
    init: { method: string; credentials: 'omit'; headers: Record<string, string> },
  ): Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>
  /** Read at call time: the token may expire while the tab stays open. */
  token(): string | null
}

/**
 * One call to the broker, with the two refusals it answers by design turned
 * into states: 401 is "sign in" (no session, or one that just expired) and 503
 * is "not on this server" (no pod driver). Anything else is a real failure and
 * is thrown for the panel to say so.
 *
 * The token goes out in exactly one header, with credentials omitted: the same
 * rule appSessionIdentity.ts sets for this credential -- never a URL, never a
 * cookie of ours, never a log.
 */
export async function callBroker(env: BrokerEnv, call: BrokerCall): Promise<BrowserView> {
  const token = env.token()
  if (!token) return { state: 'signin' }
  const res = await env.fetch(`${BROKER_BASE}/api/browser/session`, {
    method: METHOD[call],
    credentials: 'omit',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
  })
  if (res.status === 401) return { state: 'signin' }
  if (res.status === 503) return { state: 'unavailable' }
  if (!res.ok) throw new Error(`broker ${res.status}`)
  return viewOf(await res.json().catch(() => ({})))
}

/** How long a `starting` answer waits before it is asked again. */
export const STARTING_POLL_MS = 2000

/* ────────────────────────────────────────────────────────────────────────
 * THE QUEEN, DRIVING THE BROWSER ON SCREEN.
 *
 * Owner, 2026-09-21: "I want to talk to the Queen and have her drive the
 * browser", and "she must know which tab I am talking to her from".
 *
 * The Queen's own chat (queen-proxy -> trios-agent-server) has no browser
 * tools, and cannot have the person's: those live in the render's agent,
 * bound to the person the token names. So on the BROWSER tab the question
 * goes to that agent -- the same one the app's chat uses, with all nine
 * browser_* tools -- and the tab is told to it in words, so it acts in the
 * window the person is watching instead of asking what they mean.
 *
 * Measured before this was written: asked "which tabs are open, just look",
 * that agent called browser_status and listed the three open tabs.
 * ──────────────────────────────────────────────────────────────────────── */

export interface ChatTurn {
  role: 'user' | 'assistant'
  content: string
}

/** How many earlier turns ride along, so "and now click it" has an "it". */
export const HISTORY_TURNS = 8

/**
 * What the agent is told about where it is. Every rule in it is one the
 * server enforces anyway (the guard, the password rule); saying it saves a
 * turn of the model finding out.
 */
export function browserContext(lang: 'ru' | 'en'): string {
  return lang === 'ru'
    ? '[Контекст: человек пишет из вкладки BROWSER доски Королевы на app.t27.ai. Прямо сейчас у него на экране его собственный браузер — тот же, которым ты управляешь инструментами browser_*. Всё, что ты делаешь, он видит. Действуй в этом браузере, не спрашивай, о каком браузере речь. Пароли и коды человек вводит сам, в окне: не проси их и не набирай. На банке, почте и оплате сначала browser_ask_permission.]'
    : "[Context: the person is writing from the BROWSER tab of the Queen's board on app.t27.ai. Their own browser is on their screen right now -- the same one you drive with the browser_* tools -- and they see everything you do. Act in that browser; do not ask which browser is meant. Passwords and codes the person types themselves, in the window: never ask for them or type them. On a bank, mail or payment page, browser_ask_permission first.]"
}

/** The messages sent: earlier turns, then this question with the context. */
export function agentMessages(history: readonly ChatTurn[], question: string, lang: 'ru' | 'en'): ChatTurn[] {
  const earlier = history.filter((t) => t.content.trim() !== '').slice(-HISTORY_TURNS)
  return [...earlier, { role: 'user', content: `${browserContext(lang)}\n\n${question}` }]
}

export interface AgentAnswer {
  text: string
  tools: string[]
  model: string | null
  error: string | null
}

/**
 * The agent answers in NDJSON, one event per line: `текст` pieces are the
 * answer, `инструмент` names a tool it called, `провайдер` names the model,
 * `ошибка` is a failure in words. Thinking is not shown. A line that does not
 * parse is skipped rather than failing the answer that surrounds it.
 */
export function readAgentStream(raw: string): AgentAnswer {
  const answer: AgentAnswer = { text: '', tools: [], model: null, error: null }
  for (const line of raw.split('\n')) readAgentLine(answer, line)
  answer.text = answer.text.trim()
  return answer
}

/** One NDJSON line into the answer so far. Returns true when it changed. */
export function readAgentLine(answer: AgentAnswer, line: string): boolean {
  if (!line.trim()) return false
  let e: Record<string, unknown>
  try {
    e = JSON.parse(line)
  } catch {
    return false
  }
  const kind = e['тип']
  if (kind === 'текст' && typeof e['текст'] === 'string') answer.text += e['текст']
  else if (kind === 'инструмент' && typeof e['имя'] === 'string') answer.tools.push(e['имя'])
  else if (kind === 'провайдер' && typeof e.id === 'string') answer.model = typeof e.model === 'string' ? `${e.id}/${e.model}` : e.id
  else if (kind === 'ошибка' && typeof e['текст'] === 'string') answer.error = e['текст']
  else return false
  return true
}

/**
 * The same reading, as the bytes arrive. The owner, 2026-09-21: the steps
 * should be seen while she works -- "opening...", "clicking..." -- not only
 * the answer at the end. `onProgress` gets a copy after every event that
 * changed something; a line split across two chunks waits for its end.
 */
export async function readAgentBody(
  body: ReadableStream<Uint8Array>,
  onProgress?: (soFar: AgentAnswer) => void,
): Promise<AgentAnswer> {
  const answer: AgentAnswer = { text: '', tools: [], model: null, error: null }
  const reader = body.getReader()
  const decoder = new TextDecoder()
  let rest = ''
  const take = (line: string) => {
    if (readAgentLine(answer, line) && onProgress) onProgress({ ...answer, tools: [...answer.tools] })
  }
  for (;;) {
    const { value, done } = await reader.read()
    if (done) break
    rest += decoder.decode(value, { stream: true })
    const lines = rest.split('\n')
    rest = lines.pop() ?? ''
    for (const line of lines) take(line)
  }
  rest += decoder.decode()
  take(rest)
  answer.text = answer.text.trim()
  return answer
}

export class AgentSignedOut extends Error {}

export interface AgentEnv {
  fetch(
    url: string,
    init: { method: 'POST'; credentials: 'omit'; headers: Record<string, string>; body: string },
  ): Promise<{ ok: boolean; status: number; text(): Promise<string>; body?: ReadableStream<Uint8Array> | null }>
  token(): string | null
}

/**
 * One question to the person's agent. The token goes in one header with
 * credentials omitted, as everywhere in this file. 401 is "signed out", not
 * a failure; any other refusal is thrown with the server's own words.
 */
export async function askBrowserAgent(
  env: AgentEnv,
  history: readonly ChatTurn[],
  question: string,
  lang: 'ru' | 'en',
  onProgress?: (soFar: AgentAnswer) => void,
): Promise<AgentAnswer> {
  const token = env.token()
  if (!token) throw new AgentSignedOut()
  const res = await env.fetch(`${BROKER_BASE}/api/agent/chat`, {
    method: 'POST',
    credentials: 'omit',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ messages: agentMessages(history, question, lang) }),
  })
  if (res.status === 401) throw new AgentSignedOut()
  if (!res.ok) {
    const raw = await res.text().catch(() => '')
    throw new Error(`agent ${res.status}${raw ? `: ${raw.slice(0, 300)}` : ''}`)
  }
  const answer = res.body
    ? await readAgentBody(res.body, onProgress)
    : readAgentStream(await res.text().catch(() => ''))
  if (!answer.text && answer.error) throw new Error(answer.error)
  return answer
}

/* ────────────────────────────────────────────────────────────────────────
 * THE WINDOW SAYS WHEN ITS CONNECTION IS LOST.
 *
 * The viewer at /live/<id> posts { source: 't27-browser', state } to its
 * parent: reconnecting, stuck, connected (999-multibots-telegraf,
 * render/src/browser/skin.ts WINDOW_EVENT). A lost connection may be a
 * session that ended, so the panel reads the state again instead of keeping
 * a frozen frame. Accepted only from our own origin and our own frame.
 * ──────────────────────────────────────────────────────────────────────── */
export const WINDOW_EVENT = 't27-browser'
export type FrameState = 'reconnecting' | 'stuck' | 'connected'
const FRAME_STATES: readonly FrameState[] = ['reconnecting', 'stuck', 'connected']

export function frameStateOf(
  event: { origin: string; source: unknown; data: unknown },
  frameWindow: unknown,
  ownOrigin: string,
): FrameState | null {
  if (event.origin !== ownOrigin) return null
  if (!frameWindow || event.source !== frameWindow) return null
  const d = event.data as { source?: unknown; state?: unknown } | null
  if (!d || typeof d !== 'object' || d.source !== WINDOW_EVENT) return null
  return FRAME_STATES.includes(d.state as FrameState) ? (d.state as FrameState) : null
}

export const shouldReread = (state: FrameState | null): boolean => state === 'reconnecting' || state === 'stuck'

/* ────────────────────────────────────────────────────────────────────────
 * WHAT THE AGENT DID HERE, UNDER THE WINDOW.
 *
 * The render keeps a journal of every browser tool call (999-multibots-
 * telegraf, render/src/browser/journal.ts): tool, ok, how long, and facts
 * already stripped of anything private -- typed text by length, addresses
 * without their query. The panel shows the last few, so the person sees not
 * only the page but what the agent did to it and what it saw. Browserbase
 * shows the same beside its live view.
 * ──────────────────────────────────────────────────────────────────────── */
export const JOURNAL_SHOWN = 6
export const JOURNAL_POLL_MS = 5000

export interface JournalStep {
  at: string
  tool: string
  ok: boolean
  ms: number
  detail: Record<string, unknown>
}

/** The journal, newest first; null when it cannot be read (never throws). */
export async function readJournal(env: BrokerEnv, limit = JOURNAL_SHOWN): Promise<JournalStep[] | null> {
  const token = env.token()
  if (!token) return null
  try {
    const res = await env.fetch(`${BROKER_BASE}/api/browser/journal?limit=${limit}`, {
      method: 'GET',
      credentials: 'omit',
      headers: { Authorization: `Bearer ${token}` },
    })
    if (!res.ok) return null
    const body = (await res.json()) as { ok?: boolean; steps?: unknown }
    return Array.isArray(body?.steps) ? (body.steps as JournalStep[]) : null
  } catch {
    return null
  }
}

const VERB: Record<string, { ru: string; en: string }> = {
  browser_open: { ru: 'открыл', en: 'opened' },
  browser_read: { ru: 'прочитал', en: 'read' },
  browser_screenshot: { ru: 'посмотрел', en: 'looked' },
  browser_click: { ru: 'нажал', en: 'clicked' },
  browser_type: { ru: 'напечатал', en: 'typed' },
  browser_evaluate: { ru: 'выполнил код', en: 'ran code' },
  browser_status: { ru: 'проверил вкладки', en: 'checked tabs' },
  browser_close_tab: { ru: 'закрыл вкладку', en: 'closed a tab' },
  browser_ask_permission: { ru: 'спросил разрешения', en: 'asked permission' },
}

/**
 * One line for a step, in the person's language. Pure. What it can say is
 * only what the journal kept -- never typed text, which it does not have.
 */
export function journalLine(step: JournalStep, lang: 'ru' | 'en'): { time: string; verb: string; text: string; ok: boolean } {
  const d = step.detail ?? {}
  const verb = VERB[step.tool]?.[lang] ?? step.tool
  const chars = lang === 'ru' ? 'симв.' : 'chars'
  let text = ''
  if (typeof d.error === 'string') text = d.error
  else if (typeof d.seen === 'string') text = d.seen
  else if (d.seenPending === true) text = lang === 'ru' ? 'описание готовится' : 'description on its way'
  else if (typeof d.url === 'string') text = d.url
  else if (typeof d.title === 'string') text = d.title
  else if (typeof d.what === 'string') text = d.what
  else if (typeof d.chars === 'number') text = `${d.chars} ${chars}`
  else if (typeof d.x === 'number' && typeof d.y === 'number') text = `${d.x}, ${d.y}`
  else if (typeof d.pages === 'number') text = String(d.pages)
  const t = new Date(step.at)
  const time = Number.isNaN(t.getTime())
    ? ''
    : `${String(t.getHours()).padStart(2, '0')}:${String(t.getMinutes()).padStart(2, '0')}:${String(t.getSeconds()).padStart(2, '0')}`
  return { time, verb, text: text.slice(0, 140), ok: step.ok !== false }
}
