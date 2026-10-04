// The motto, in one place.
//
// Three verbs: what a player does here, in the order they do it. They are the
// caption under the mark, they open the headline, and they are the names of the
// three moves in AgiGameBlock -- one wording in three places, because a motto
// typed three times is a motto that will be typed differently once, and a site
// that says "Direct" in the hero and "Govern" in the body has no motto at all.
//
// `earn` is the word the page owes an answer for, and AgiGameBlock gives it:
// an accepted turn is a non-transferable integer against a name, there is no
// token, and that block says why there will not be one. The motto states the
// move; the block states its terms. Neither is allowed to state them alone.
// The name the mark carries, in every language: GameHero's wordmark, and the
// site name a link preview prints above the caption (index.html og:site_name,
// the tab title the i18n provider writes). qa/og-preview-contract.mjs holds
// index.html and og/og-image.svg to this file.
export const SITE_NAME = 'TRINITY S³AI'

export const MOTTO = {
  en: {
    verbs: ['Play', 'Direct', 'Earn'] as const,
    // The caption under the mark. Upper case is the caption's own styling in
    // GameHero.css, not baked into the string, so the same words can be read
    // aloud by a screen reader as words.
    caption: 'AGI game — play, direct, earn',
    // How the headline opens.
    headline: 'Play, direct, earn',
    // How it goes on, after a colon. The whole headline is also the page's
    // description, in the head and in a link preview, so it lives here rather
    // than in GameHero alone.
    clause: 'the core is a game, and the board is public',
  },
  ru: {
    verbs: ['Играй', 'Управляй', 'Зарабатывай'] as const,
    caption: 'AGI-игра — играй, управляй, зарабатывай',
    headline: 'Играй, управляй, зарабатывай',
    clause: 'ядро — это игра, и доска открыта',
  },
} as const

export type MottoLang = keyof typeof MOTTO
