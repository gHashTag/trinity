// TASKS SIDE BY SIDE, under the BROWSER view's picture. Decisions live in
// lib/queenBrowserLanes.ts; this file only draws them. A card's conversation lives in
// this component's state and nowhere else: closing the card forgets it.
import { useCallback, useState } from 'react'
import { AgentSignedOut, askBrowserAgent, type AgentEnv, type ChatTurn } from '../lib/queenBrowser'
import {
  AgentLaneRefused,
  canAddLane,
  cardStateAfter,
  laneNameFor,
  supportAfter,
  type CardState,
  type LaneSupport,
} from '../lib/queenBrowserLanes'

export interface BrowserLanesCopy {
  add: string
  addTitle: string
  region: string
  placeholder: string
  send: string
  working: string
  limit: string
  old: string
  signedout: string
  failed: string
  close: string
  closeTitle: string
}

interface Card {
  lane: string
  turns: ChatTurn[]
  draft: string
  state: CardState
  tools: string[]
  partial: string
}

export function QueenBrowserLanes({ c, lang, env, live }: { c: BrowserLanesCopy; lang: 'ru' | 'en'; env: AgentEnv; live: boolean }) {
  const [cards, setCards] = useState<Card[]>([])
  const [support, setSupport] = useState<LaneSupport>('unknown')
  const [full, setFull] = useState(false)

  const update = useCallback((lane: string, patch: Partial<Card>) => {
    setCards(all => all.map(card => (card.lane === lane ? { ...card, ...patch } : card)))
  }, [])

  const add = () => {
    const lane = laneNameFor(cards.map(card => card.lane))
    if (!lane) return
    setCards(all => [...all, { lane, turns: [], draft: '', state: 'idle', tools: [], partial: '' }])
  }

  // The window stays on the render until a new card takes its name or it has
  // been idle long enough (lib/queenBrowserLanes.ts): closing forgets the card only.
  const close = (lane: string) => {
    setCards(all => all.filter(card => card.lane !== lane))
    setFull(false)
  }

  const send = async (card: Card) => {
    const question = card.draft.trim()
    if (!question || card.state === 'working') return
    update(card.lane, { state: 'working', draft: '', tools: [], partial: '' })
    try {
      const a = await askBrowserAgent(
        env,
        card.turns,
        question,
        lang,
        soFar => update(card.lane, { tools: soFar.tools, partial: soFar.text }),
        null,
        card.lane,
      )
      setSupport(prev => supportAfter(prev, card.lane, a.lane))
      update(card.lane, {
        state: cardStateAfter({ lane: card.lane, confirmed: a.lane }),
        turns: [...card.turns, { role: 'user', content: question }, { role: 'assistant', content: a.text }],
        tools: a.tools,
        partial: '',
      })
    } catch (error) {
      if (error instanceof AgentLaneRefused) {
        if (error.refusal === 'limit') setFull(true)
        update(card.lane, { state: cardStateAfter({ refusal: error.refusal }), draft: question, partial: '' })
      } else {
        update(card.lane, { state: cardStateAfter(error instanceof AgentSignedOut ? 'signedout' : 'failed'), draft: question, partial: '' })
      }
    }
  }

  const signedIn = env.token() !== null
  const offer = canAddLane({ live, signedIn, support, cards: cards.length, full })
  if (!offer && cards.length === 0) return null

  const note: Partial<Record<CardState, string>> = {
    limit: c.limit,
    old: c.old,
    signedout: c.signedout,
    failed: c.failed,
  }

  return (
    <section className="queen27-browser-lanes" aria-label={c.region}>
      {cards.map(card => (
        <article key={card.lane} className={`queen27-browser-task is-${card.state}`}>
          <header className="queen27-browser-task-head">
            <b>{card.lane}</b>
            <span className="queen27-browser-task-state">{card.state === 'working' ? c.working : ''}</span>
            <button
              type="button"
              className="queen27-browser-btn is-quiet"
              title={c.closeTitle}
              aria-label={`${c.close}: ${card.lane}`}
              onClick={() => close(card.lane)}
            >
              ×
            </button>
          </header>
          {card.turns.length > 0 || card.partial ? (
            <ol className="queen27-browser-task-log">
              {card.turns.map((turn, i) => (
                <li key={i} className={turn.role === 'user' ? 'is-person' : 'is-agent'}>
                  {turn.content}
                </li>
              ))}
              {card.state === 'working' && card.partial ? <li className="is-agent">{card.partial}</li> : null}
            </ol>
          ) : null}
          {card.tools.length > 0 ? <p className="queen27-browser-task-tools">{[...new Set(card.tools)].join(', ')}</p> : null}
          {note[card.state] ? <p className={`queen27-browser-task-note is-${card.state}`}>{note[card.state]}</p> : null}
          {support === 'no' ? null : (
            <form
              className="queen27-browser-task-form"
              onSubmit={e => {
                e.preventDefault()
                void send(card)
              }}
            >
              <textarea
                rows={2}
                value={card.draft}
                placeholder={c.placeholder}
                disabled={card.state === 'working'}
                onChange={e => update(card.lane, { draft: e.target.value })}
                onKeyDown={e => {
                  if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault()
                    void send(card)
                  }
                }}
              />
              <button type="submit" className="queen27-browser-btn" disabled={card.state === 'working' || !card.draft.trim()}>
                {c.send}
              </button>
            </form>
          )}
        </article>
      ))}
      {offer ? (
        <button type="button" className="queen27-browser-btn is-quiet queen27-browser-lanes-add" title={c.addTitle} onClick={add}>
          {c.add}
        </button>
      ) : null}
    </section>
  )
}
