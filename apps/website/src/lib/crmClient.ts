// The owner's console talks to the farm through the AGENT'S OWN TOOLS.
//
// Not a new set of /api/crm/* routes. The tools on /mcp already carry the rule
// about who may see whom, in one place, measured and tested; a second path to
// the same data would be a second place for that rule to be forgotten, and the
// price of forgetting it is a stranger's correspondence on a stranger's screen.
//
// THREE RULES THIS FILE EXISTS TO KEEP:
//
//   1. A browser never holds the render service's own key. That key names the
//      SERVICE and can act for anybody; its header does not appear in this file
//      and must never appear anywhere under src/. Identity here is per-person: a
//      Telegram Login Widget session, or an agent key issued to one telegram_id.
//      The service-key header is not named anywhere in this tree on purpose:
//      the contract test asserts the literal string is absent from src/, which
//      is a rule with no judgement in it and therefore no way to erode.
//   2. EXACTLY ONE identity header per request. Two would let the server pick,
//      and "whichever the server prefers" is not an authorisation model.
//   3. The browser can only ask for things that READ, plus the one write that
//      changes nothing outside our own memory (crm_touch). Sending happens in
//      the bot, after a press on the card — never from a web page.
//
// credentials:'omit' throughout: the service answers CORS with origin '*', which
// is safe only while no cookie rides along. Never switch this to 'include'.

const RENDER_BASE = 'https://vibee-render-production.up.railway.app'

/**
 * Everything the console may call.
 *
 * crm_offer, crm_deliver_photo, crm_ingest_chats, tg_send and the feed writers
 * are deliberately absent: they mint invoices, spend money or reach a person.
 * The refusal happens HERE, before a request is made, so a bug in the page
 * cannot turn into a message somebody receives.
 */
const TOOL_ALLOWLIST = new Set([
  'whoami',
  'crm_summary',
  'crm_leads',
  'crm_waiting',
  'crm_lead_context',
  'crm_history',
  'crm_touch',
])

export type CredentialKind = 'session' | 'key'

export interface CrmFailure {
  /** Which of the four things went wrong, so the page can say it in the reader's words. */
  reason: 'rejected' | 'ownerOnly' | 'offline' | 'expired' | 'refused'
  detail?: string
}

export class CrmError extends Error implements CrmFailure {
  reason: CrmFailure['reason']
  detail?: string
  constructor(failure: CrmFailure) {
    super(failure.detail ?? failure.reason)
    this.reason = failure.reason
    this.detail = failure.detail
  }
}

const REFRESH_KEY = 't27.crm.refresh'
const AGENT_KEY = 't27.crm.key'

/** sessionStorage throws outright in some embeddings; a lost credential is not worth a broken page. */
const store = {
  get(key: string): string | null {
    try {
      return window.sessionStorage.getItem(key)
    } catch {
      return null
    }
  },
  set(key: string, value: string): void {
    try {
      window.sessionStorage.setItem(key, value)
    } catch {
      /* this tab simply will not remember */
    }
  },
  drop(key: string): void {
    try {
      window.sessionStorage.removeItem(key)
    } catch {
      /* nothing to forget */
    }
  },
}

// The access token stays in memory only: it is the thing that acts, it lives
// about ten minutes, and a page reload is a cheap price for not writing it down.
let access: { token: string; until: number } | null = null

export function credentialKind(): CredentialKind | null {
  if (access || store.get(REFRESH_KEY)) return 'session'
  if (store.get(AGENT_KEY)) return 'key'
  return null
}

export function forgetCredentials(): void {
  access = null
  store.drop(REFRESH_KEY)
  store.drop(AGENT_KEY)
}

export function rememberAgentKey(key: string): void {
  const trimmed = key.trim()
  if (!trimmed) return
  access = null
  store.drop(REFRESH_KEY)
  store.set(AGENT_KEY, trimmed)
}

async function post(path: string, body: unknown, headers: Record<string, string> = {}): Promise<Response> {
  try {
    return await fetch(`${RENDER_BASE}${path}`, {
      method: 'POST',
      credentials: 'omit',
      headers: { 'Content-Type': 'application/json', ...headers },
      body: JSON.stringify(body),
    })
  } catch {
    throw new CrmError({ reason: 'offline' })
  }
}

interface SessionPayload {
  access_token?: string
  refresh_token?: string
  expires_in?: number
  telegram_id?: string
}

function keepSession(payload: SessionPayload): void {
  if (!payload.access_token) throw new CrmError({ reason: 'rejected' })
  // A minute of slack: a token that expires while the request is in flight is
  // a 401 the reader would read as "signed out".
  access = { token: payload.access_token, until: Date.now() + Math.max(30, (payload.expires_in ?? 600) - 60) * 1000 }
  if (payload.refresh_token) store.set(REFRESH_KEY, payload.refresh_token)
  store.drop(AGENT_KEY)
}

/** The widget's signed user object, exchanged for an app session. Nothing is stored on the site. */
export async function signInWithWidget(user: Record<string, unknown>): Promise<void> {
  const res = await post('/api/auth/widget', user)
  if (!res.ok) throw new CrmError({ reason: 'rejected', detail: `HTTP ${res.status}` })
  keepSession((await res.json()) as SessionPayload)
}

async function refreshSession(): Promise<boolean> {
  const token = store.get(REFRESH_KEY)
  if (!token) return false
  const res = await post('/api/auth/refresh', { refresh_token: token })
  if (!res.ok) {
    forgetCredentials()
    return false
  }
  keepSession((await res.json()) as SessionPayload)
  return true
}

/** Exactly one header. Returns null when nothing identifies the reader. */
async function identityHeader(): Promise<Record<string, string> | null> {
  const key = store.get(AGENT_KEY)
  if (key) return { 'X-Agent-Key': key }
  if (access && access.until > Date.now()) return { Authorization: `Bearer ${access.token}` }
  if (await refreshSession()) return { Authorization: `Bearer ${access!.token}` }
  return null
}

/** The service's own refusal, recognised without echoing a stranger's text as an instruction. */
function classify(message: string): CrmFailure['reason'] {
  const m = message.toLowerCase()
  if (m.includes('владел') || m.includes('owner')) return 'ownerOnly'
  return 'rejected'
}

export async function callTool<T = unknown>(name: string, args: Record<string, unknown> = {}, retry = true): Promise<T> {
  if (!TOOL_ALLOWLIST.has(name)) throw new CrmError({ reason: 'refused', detail: name })
  const identity = await identityHeader()
  if (!identity) throw new CrmError({ reason: 'expired' })

  const res = await post('/mcp', { jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name, arguments: args } }, identity)
  if (res.status === 401) {
    if (retry && credentialKind() === 'session' && (await refreshSession())) return callTool<T>(name, args, false)
    forgetCredentials()
    throw new CrmError({ reason: 'expired' })
  }
  if (!res.ok && res.status >= 500) throw new CrmError({ reason: 'offline', detail: `HTTP ${res.status}` })

  let body: { error?: { code?: number; message?: string }; result?: { structuredContent?: unknown; content?: { type: string; text?: string }[] } }
  try {
    body = await res.json()
  } catch {
    throw new CrmError({ reason: 'offline' })
  }
  if (body.error) {
    if (body.error.code === -32001) {
      forgetCredentials()
      throw new CrmError({ reason: 'expired' })
    }
    const message = String(body.error.message ?? '')
    throw new CrmError({ reason: classify(message), detail: message })
  }
  const structured = body.result?.structuredContent
  if (structured !== undefined) return structured as T
  // Some servers send only the text block; parse it when it is JSON, hand it
  // back as text otherwise. Either way it is DATA, and the page renders it as
  // text nodes -- never as markup, never as an instruction.
  const text = body.result?.content?.find((c) => c.type === 'text')?.text
  if (text === undefined) return {} as T
  try {
    return JSON.parse(text) as T
  } catch {
    return text as unknown as T
  }
}

export { RENDER_BASE, TOOL_ALLOWLIST }
