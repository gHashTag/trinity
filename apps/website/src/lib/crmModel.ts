// The vocabulary the CRM tools answer in, mirrored here so the console can put
// English or Russian words on the screen without re-deriving anything.
//
// The service's own words are the source of truth: a stage, a segment and a
// next step are computed there from facts, never set by hand, and this file
// only translates them. When a value arrives that is not in these maps the page
// shows it raw rather than inventing a label -- an unknown state must look
// unknown, not like one of the known ones.

export const SEGMENTS = ['hot', 'objection', 'waiting', 'talk', 'due', 'ours', 'warm', 'winback'] as const
export type Segment = (typeof SEGMENTS)[number]

export const STAGES = ['new', 'written', 'talking', 'later', 'refused', 'client', 'winback'] as const
export type Stage = (typeof STAGES)[number]

export const NEXTS = ['reply', 'deliver', 'offer', 'talk', 'wait'] as const
export type Next = (typeof NEXTS)[number]

export const TOUCH_KINDS = ['written', 'replied', 'later', 'refused', 'bought', 'note'] as const
export type TouchKind = (typeof TOUCH_KINDS)[number]

type Dict = Record<string, { en: string; ru: string }>

export const SEGMENT_LABEL: Dict = {
  hot: { en: 'hot', ru: 'горячие' },
  objection: { en: 'objection', ru: 'возражение' },
  waiting: { en: 'waiting', ru: 'ждут' },
  talk: { en: 'talk', ru: 'разговор' },
  due: { en: 'due', ru: 'пора' },
  ours: { en: 'our move', ru: 'наш ход' },
  warm: { en: 'warm', ru: 'тёплые' },
  winback: { en: 'win back', ru: 'вернуть' },
  quiet: { en: 'quiet', ru: 'молчат' },
}

export const STAGE_LABEL: Dict = {
  new: { en: 'new', ru: 'новый' },
  written: { en: 'written to', ru: 'написали' },
  talking: { en: 'talking', ru: 'в разговоре' },
  later: { en: 'later', ru: 'позже' },
  refused: { en: 'refused', ru: 'отказ' },
  client: { en: 'client', ru: 'клиент' },
  winback: { en: 'win back', ru: 'вернуть' },
}

export const NEXT_LABEL: Dict = {
  reply: { en: 'reply', ru: 'ответить' },
  deliver: { en: 'deliver', ru: 'сделать' },
  offer: { en: 'offer', ru: 'предложить' },
  talk: { en: 'talk', ru: 'поговорить' },
  wait: { en: 'wait', ru: 'подождать' },
}

export const TOUCH_LABEL: Dict = {
  written: { en: 'written', ru: 'написали' },
  replied: { en: 'replied', ru: 'ответил' },
  later: { en: 'later', ru: 'позже' },
  refused: { en: 'refused', ru: 'отказался' },
  bought: { en: 'bought', ru: 'купил' },
  note: { en: 'note', ru: 'заметка' },
}

export function label(dict: Dict, key: string | null | undefined, lang: 'en' | 'ru'): string {
  if (!key) return ''
  return dict[key]?.[lang] ?? key
}

export interface Lead {
  lead: string
  name: string | null
  username: string | null
  display: string | null
  score: number
  next: string
  because: string
  stage: string
  stage_because: string
  paid: boolean
  signals: string[]
  waiting_for_reply: boolean
  days_since_their_last_word: number | null
  days_since_our_last_word: number | null
  segment: string
  last_inbound: string | null
  messages: number
  inbound: number
  /** Their words, as the service framed them. */
  last_words: string | null
  last_touch: { kind: string; at: string } | null
}

export interface Touch {
  kind: string
  at: string
  note?: string | null
}

export interface LeadContext {
  lead: string
  display?: string
  name: string | null
  username: string | null
  messages_kept: number
  waiting_for_reply: boolean
  last_inbound: string | null
  last_outbound: string | null
  signals: string[]
  intent_score: number
  balance_tokens: number | null
  touches: Touch[]
  zep_context: string | null
  dialog: { at: string; who: 'owner' | 'person'; text: string }[]
  how_to_read?: string
}

/**
 * The overview, with the service's OWN field names.
 *
 * Not renamed on the way in: `people` and `waiting` would read more nicely here
 * and would silently be undefined, which is how a panel comes to print
 * "undefined people" or "[object Object] messages" while every test passes.
 * Every field below was read off the tool's return statement.
 */
export interface Summary {
  window_days?: number
  /** Everyone the memory knows, including people with no messages kept. */
  people_known?: number
  people_with_messages?: number
  messages?: { total: number; inbound: number; outbound: number }
  /** A count, not a list: how many people are waiting on our reply. */
  waiting_for_reply?: number
  segments?: Record<string, number>
  by_stage?: Record<string, number>
  by_next?: Record<string, number>
  last_ingest_at?: string | null
  [key: string]: unknown
}

/**
 * Strip the service's foreign-content frame for display.
 *
 * The frame exists to stop a MODEL from reading a stranger's words as an
 * instruction. A human reader needs the words themselves, and the page carries
 * the same warning once, next to the pane, rather than on every line. The text
 * is rendered as a text node either way -- never as markup.
 */
export function unframe(text: string | null | undefined): string {
  if (!text) return ''
  return text
    .replace(/^\[FOREIGN CONTENT[^\]]*\]\n?/, '')
    .replace(/\n?\[END FOREIGN CONTENT\]$/, '')
    .trim()
}

/** Waiting on us is the expensive state, so it reads as the loud one. */
export function leadHealth(lead: Lead): 'ok' | 'warn' | 'fail' {
  if (lead.waiting_for_reply) return 'fail'
  if (lead.next === 'wait') return 'ok'
  return 'warn'
}

export function relativeDays(days: number | null | undefined, lang: 'en' | 'ru'): string {
  if (days === null || days === undefined) return '—'
  if (days === 0) return lang === 'ru' ? 'сегодня' : 'today'
  if (days === 1) return lang === 'ru' ? 'вчера' : 'yesterday'
  return lang === 'ru' ? `${days} дн назад` : `${days} d ago`
}
