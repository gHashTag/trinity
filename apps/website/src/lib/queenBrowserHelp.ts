/**
 * THE QUEEN, ON THE BROWSER TAB.
 *
 * On every other view the chat asks the Queen's own server, and queenHealth
 * says whether that server answers. On BROWSER the question goes somewhere
 * else: to the person's own agent on the render (services/queenModel.ts,
 * askQueenInBrowser), which holds the browser tools. So the Queen server's
 * health says nothing about whether a question asked here is answered -- and
 * the panel said exactly that anyway: an OFFLINE chip and "No Queen is
 * answering. Start one with tri serve --chat" over a view whose questions
 * never went to that server (found 2026-10-04). The chip now names who
 * answers on this view, and the empty conversation says what she can do here.
 *
 * An empty conversation over a live browser also gave the person nothing to
 * start from. The starters below are presses the person makes: each one is
 * sent as their own question and shows in the log as theirs. None asks for a
 * step that cannot be taken back -- paying, sending, deleting, posting -- and
 * the one about signing in asks her to POINT, because the password is typed
 * by the person, into the picture (the live bar says so too).
 *
 * Pure and driven through its arguments, so qa/queen-browser-help-contract.mjs
 * calls the decisions directly.
 */

/** Who answers a question asked on this view. */
export type ChatBackend = 'agent' | 'queen'

export const backendOf = (view: string): ChatBackend => (view === 'browser' ? 'agent' : 'queen')

/** The chip in the chat's head. 'agent' names who answers; it claims nothing about health. */
export type HeadState = 'agent' | 'checking' | 'live' | 'offline'

export function headState(view: string, queenLive: boolean | null): HeadState {
  if (backendOf(view) === 'agent') return 'agent'
  if (queenLive === null) return 'checking'
  return queenLive ? 'live' : 'offline'
}

/** Which sentence an empty conversation shows. */
export type EmptyNote = 'browserEmpty' | 'offlineNote' | 'empty'

export function emptyNote(view: string, queenLive: boolean | null): EmptyNote {
  if (backendOf(view) === 'agent') return 'browserEmpty'
  return queenLive === false ? 'offlineNote' : 'empty'
}

export const BROWSER_STARTERS: { readonly en: readonly string[]; readonly ru: readonly string[] } = {
  en: [
    'What is on this page? Three lines.',
    'What does this page want me to do? Point at it.',
    'Point at the sign-in field. I will type the password myself.',
    'Go back one page and tell me where we are.',
  ],
  ru: [
    'Что на этой странице? Три строки.',
    'Что эта страница от меня хочет? Покажи, где.',
    'Покажи поле входа. Пароль введу я.',
    'Вернись на страницу назад и скажи, где мы.',
  ],
}

/**
 * Words no starter may carry. Each names an act that cannot be taken back,
 * or a secret: a starter is one press, and the agent it reaches can act.
 */
export const NEVER_IN_A_STARTER: readonly string[] = [
  'pay',
  'buy',
  'order',
  'send',
  'delete',
  'post',
  'publish',
  'transfer',
  'card number',
  'оплат',
  'куп',
  'закаж',
  'отправ',
  'удал',
  'опубликуй',
  'перевед',
  'номер карты',
]

/**
 * The starters to show now: on the BROWSER view only, before the first
 * question, to a signed-in person, and not while an answer is coming.
 */
export function startersFor(
  view: string,
  state: { turns: number; signedIn: boolean; busy: boolean },
  lang: 'ru' | 'en',
): readonly string[] {
  if (backendOf(view) !== 'agent' || state.turns > 0 || !state.signedIn || state.busy) return []
  return BROWSER_STARTERS[lang]
}
