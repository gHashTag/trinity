import { useEffect, useState } from 'react'
import { COLLAB_ORIGIN } from '../components/queenRepositoryWorld'

// The GitHub side of the close-up.
//
// t27-github-collab is deployed and answers /health; what it answers with is the
// whole contract. QueenUniverse already reads one capability from it
// (queenRepositoryPicker) and hides its sign-in link when that flag is absent.
// The close-up reads the same document for a second one -- whether the service
// can write a comment on behalf of the signed-in owner -- and gates the write
// box on it.
//
// Measured 2026-09-20: the service returns {"status":"ok","service":"github-collab"}
// and nothing else, so neither capability is present and both surfaces fall back.
// The fallback is not a mock: it puts the text on the clipboard and names the
// issue, and the owner posts it from GitHub, where they are already signed in.
// A flag the service does not send is a flag that is off. Nothing here invents
// one, and no capability is assumed from the service merely being up.

export type CollabState = 'checking' | 'up' | 'down'

export interface CollabCapabilities {
  /** Choose your own repositories through the service's GitHub OAuth. */
  picker: boolean
  /** Post an issue comment as the signed-in owner. */
  comment: boolean
}

export const NO_CAPABILITIES: CollabCapabilities = { picker: false, comment: false }

export function readCapabilities(raw: unknown): CollabCapabilities {
  const body = raw !== null && typeof raw === 'object' ? (raw as Record<string, unknown>) : {}
  const caps = body.capabilities !== null && typeof body.capabilities === 'object' ? (body.capabilities as Record<string, unknown>) : {}
  return {
    picker: caps.queenRepositoryPicker === true,
    comment: caps.queenIssueComment === true,
  }
}

export function useCollab(): { state: CollabState; capabilities: CollabCapabilities } {
  const [state, setState] = useState<CollabState>('checking')
  const [capabilities, setCapabilities] = useState<CollabCapabilities>(NO_CAPABILITIES)

  useEffect(() => {
    const abort = new AbortController()
    fetch(`${COLLAB_ORIGIN}/health`, { signal: abort.signal, credentials: 'omit' })
      .then((response) => (response.ok ? response.json() : Promise.reject(new Error(`HTTP ${response.status}`))))
      .then((body: unknown) => { setState('up'); setCapabilities(readCapabilities(body)) })
      .catch((error: unknown) => { if (!(error instanceof DOMException && error.name === 'AbortError')) setState('down') })
    return () => abort.abort()
  }, [])

  return { state, capabilities }
}

/**
 * Post a comment through the collab service's session cookie. Only ever called
 * behind `capabilities.comment`, so a service that does not carry the route is
 * never asked for it.
 */
export async function postIssueComment(repo: string, number: number, body: string): Promise<void> {
  const response = await fetch(`${COLLAB_ORIGIN}/queen/issue-comment`, {
    method: 'POST',
    credentials: 'include',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({ repo, number, body }),
  })
  if (!response.ok) throw new Error(`HTTP ${response.status}`)
}
