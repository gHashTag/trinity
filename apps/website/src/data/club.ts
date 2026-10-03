// One price for every agent, in one place: #/foundry, #/devkit, the agents
// showcase and the homepage read it from here.
//
// Owner, 2026-10-03: every agent is sold at the same price — one Telegram
// Stars subscription at its maximum, 10000 Stars per 30 days — and agents
// differ by profile, not by price. USD is derived with the bot's own rate
// (STAR_PRICE_USD in gHashTag/999-multibots-telegraf), never typed twice.
export const STAR_PRICE_USD = 0.016

export const AGENT_PRICE = {
  stars: 10000,
  periodDays: 30,
}

export const agentPriceUsd = Math.round(AGENT_PRICE.stars * STAR_PRICE_USD)

const BOT = 'https://t.me/t27ai_bot'
export const orderUrl = (id: string) => `${BOT}?start=agentpkg_${id}`

// The Golden Foundry club is the TRI DEV profile — `tri dev`
// (docs/docs/cli/dev.md): one GitHub issue, one service, one autonomous
// Claude Code agent.
export const CLUB = {
  stars: AGENT_PRICE.stars,
  usdPerMonth: agentPriceUsd,
  href: '#/foundry',
  telegram: orderUrl('tridev'),
}

const stars = AGENT_PRICE.stars.toLocaleString('en-US').replace(/,/g, ' ')

export const clubPrice = (ru: boolean) => `${stars} ⭐ / ${ru ? 'мес' : 'mo'}`
export const clubPriceUsd = (ru: boolean) => `≈ $${agentPriceUsd} / ${ru ? 'мес' : 'mo'}`
