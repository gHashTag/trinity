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
import { sendMessage, checkHealth, type ChatResponse } from './chatApi'

const OLLAMA_URL = import.meta.env.VITE_QUEEN_OLLAMA_URL || 'http://localhost:11434'
const OLLAMA_MODEL = import.meta.env.VITE_QUEEN_OLLAMA_MODEL || ''

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

export function askQueen(message: string): Promise<ChatResponse> {
  return queenSource() === 'ollama' ? ollamaSend(message) : sendMessage({ message })
}
