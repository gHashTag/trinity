// The Golden Foundry club, in one place: #/foundry, #/devkit and the homepage
// read it from here. The owner set the price on 2026-10-03: $300 a month, and
// what it buys is a TRI DEV developer agent — `tri dev` (docs/docs/cli/dev.md),
// one GitHub issue to one service running one autonomous Claude Code agent.
export const CLUB = {
  usdPerMonth: 300,
  stars: 14999,
  href: '#/foundry',
  telegram: 'https://t.me/t27ai_bot?start=foundry',
}

export const clubPrice = (ru: boolean) => `$${CLUB.usdPerMonth} / ${ru ? 'мес' : 'mo'}`
