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
export const MOTTO = {
  en: {
    verbs: ['Play', 'Direct', 'Earn'] as const,
    // The caption under the mark. Upper case is the caption's own styling in
    // GameHero.css, not baked into the string, so the same words can be read
    // aloud by a screen reader as words.
    caption: 'AGI game — play, direct, earn',
    // How the headline opens. The rest of the headline follows it in GameHero.
    headline: 'Play, direct, earn',
  },
  ru: {
    verbs: ['Играй', 'Управляй', 'Зарабатывай'] as const,
    caption: 'AGI-игра — играй, управляй, зарабатывай',
    headline: 'Играй, управляй, зарабатывай',
  },
} as const

export type MottoLang = keyof typeof MOTTO
