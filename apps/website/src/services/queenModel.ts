// The Queen's model, and where she is allowed to come from.
//
// Two shapes answer the same question. The Trinity backend speaks the contract
// in chatApi (POST /chat, GET /health) and is what a deployed proxy should
// serve. Ollama speaks its own, runs on the machine, needs no key at all, and
// is why a local Queen can answer without anything being published.
//
// A key never appears here. VITE_ values are compiled into the bundle and are
// readable by anyone who opens the site, so a hosted model is reached through a
// proxy that holds the key, never from this file.
import { sendMessage, checkHealth, NotSignedIn, type ChatResponse } from './chatApi.ts'
import { AgentSignedOut, askBrowserAgent, type ChatTurn } from '../lib/queenBrowser.ts'
import { appSessionFromWindow, type AppSessionVerdict } from '../lib/appSessionIdentity.ts'

const OLLAMA_URL = import.meta.env?.VITE_QUEEN_OLLAMA_URL || 'http://localhost:11434'
const OLLAMA_MODEL = import.meta.env?.VITE_QUEEN_OLLAMA_MODEL || ''

export type QueenSource = 'trinity' | 'ollama'

export function queenSource(): QueenSource {
  return OLLAMA_MODEL ? 'ollama' : 'trinity'
}

export function queenModelName(): string {
  return OLLAMA_MODEL || 'trinity'
}

async function ollamaHealth(): Promise<boolean> {
  try {
    const res = await fetch(`${OLLAMA_URL}/api/tags`, { signal: AbortSignal.timeout(3000) })
    if (!res.ok) return false
    // Present is not enough: the named model has to be pulled, or every send
    // fails with a 404 while the panel claims to be live.
    const body = (await res.json()) as { models?: { name?: string }[] }
    return (body.models ?? []).some((m) => m.name === OLLAMA_MODEL || m.name?.split(':')[0] === OLLAMA_MODEL.split(':')[0])
  } catch {
    return false
  }
}

async function ollamaSend(message: string): Promise<ChatResponse> {
  const started = performance.now()
  const res = await fetch(`${OLLAMA_URL}/api/chat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: OLLAMA_MODEL,
      stream: false,
      messages: [
        {
          role: 'system',
          content:
            'You are the Queen of the Trinity hive. You answer about .t27 specs, the repositories on the map and the GitHub issues the board is working through. The bracketed prefix of a message is the context the operator is looking at. Answer briefly and concretely; say plainly when you do not know.',
        },
        { role: 'user', content: message },
      ],
    }),
  })
  if (!res.ok) throw new Error(`Ollama error: ${res.status}`)
  const body = (await res.json()) as { message?: { content?: string } }
  const text = body.message?.content ?? ''
  if (!text) throw new Error('Ollama returned nothing')
  return {
    response: text,
    source: OLLAMA_MODEL,
    // Not a measurement: the runtime reports no confidence, and inventing one
    // would be the sample problem in another costume.
    confidence: 0,
    latency_us: Math.round((performance.now() - started) * 1000),
  }
}

export function queenHealth(): Promise<boolean> {
  return queenSource() === 'ollama' ? ollamaHealth() : checkHealth()
}

/**
 * WHO IS ASKING.
 *
 * The owner's rule, 2026-09-20: only registered people write in this chat.
 * The gate that enforces it is the proxy's (apps/queen-proxy/caller.mjs) --
 * anything in a public bundle is a suggestion, and this file is compiled into
 * one. What happens here is the other half: the panel knows before it asks, so
 * a signed-out visitor reads a sentence with somewhere to go instead of typing
 * a question and being refused by a server.
 *
 * `bridge` means this document is not the app's own copy of the board. Off
 * app.t27.ai the session token is deliberately unreadable -- that is the whole
 * design of triIdentity.ts, where the token acts and never travels -- so there
 * is no bearer to send and the honest answer is the same sentence. In practice
 * the board's live home IS app.t27.ai/queen/ and t27.ai/#/queen redirects
 * there; what this costs is the chat on a localhost dev build, which is a price
 * the rule is worth.
 */
export type QueenCaller =
  | { signedIn: true; authorization: string }
  | { signedIn: false; why: 'no_session' | 'expired' | 'no_storage' | 'elsewhere' }

export function queenCaller(verdict: AppSessionVerdict = appSessionFromWindow()): QueenCaller {
  if (verdict.source === 'bridge') return { signedIn: false, why: 'elsewhere' }
  if (verdict.state === 'signed-out') return { signedIn: false, why: verdict.code }
  // The token is carried, not kept: it is read at the moment of the question
  // and handed straight to the one call that needs it. Nothing here stores it,
  // and no component ever receives it.
  return { signedIn: true, authorization: `Bearer ${verdict.token}` }
}

export function askQueen(message: string): Promise<ChatResponse> {
  if (queenSource() === 'ollama') return ollamaSend(message)
  const caller = queenCaller()
  if (!caller.signedIn) return Promise.reject(new NotSignedIn())
  return sendMessage({ message }, caller.authorization)
}

/**
 * On the BROWSER tab: the question goes to the person's own agent, which
 * holds the browser tools (lib/queenBrowser.ts says why). The token is read
 * here, at the moment of the question, exactly as askQueen reads it -- the
 * panel is handed an answer, never the credential.
 */
export async function askQueenInBrowser(
  history: readonly ChatTurn[],
  question: string,
  lang: 'ru' | 'en',
): Promise<ChatResponse> {
  const caller = queenCaller()
  if (!caller.signedIn) throw new NotSignedIn()
  const bearer = caller.authorization.replace(/^Bearer /, '')
  const started = Date.now()
  try {
    const a = await askBrowserAgent(
      { fetch: (url, init) => fetch(url, init), token: () => bearer },
      history,
      question,
      lang,
    )
    return {
      response: a.text,
      // The tools she used ride under the answer: the person watched the
      // clicks happen, and this names them.
      source: [a.model ?? 'agent', ...(a.tools.length > 0 ? [[...new Set(a.tools)].join(', ')] : [])].join(' · '),
      confidence: 0,
      latency_us: Math.round((Date.now() - started) * 1000),
    }
  } catch (error) {
    if (error instanceof AgentSignedOut) throw new NotSignedIn()
    throw error
  }
}
