// The agents the bot sells. Live source: GET /api/agents/packages on the bot
// (gHashTag/999-multibots-telegraf, generated from AGENT_PACKAGES); the list
// below is only the fallback the showcase renders while that call is pending
// or failing. The price is not here — every agent costs AGENT_PRICE
// (data/club.ts); agents differ by profile.
export type AgentProfile = {
  id: string
  icon: string
  name: { en: string; ru: string }
  promise: { en: string; ru: string }
}

export const AGENTS_ENDPOINT =
  'https://999-multibots-telegraf-production-2008.up.railway.app/api/agents/packages'

export const AGENT_PROFILES: readonly AgentProfile[] = [
  {
    id: 'manager',
    icon: '◎',
    name: { en: 'Manager Agent', ru: 'Менеджер агент' },
    promise: {
      en: 'Your own Telegram bot that answers clients around the clock in your voice and brings the leads to your CRM.',
      ru: 'Собственный Telegram-бот, который круглосуточно отвечает клиентам в вашем тоне и приносит заявки в CRM.',
    },
  },
  {
    id: 'blogger',
    icon: '✦',
    name: { en: 'Blogger Agent', ru: 'Блогер агент' },
    promise: {
      en: 'Reels with your face and voice, a content plan and publishing — the blogger agent working for your channel.',
      ru: 'Рилсы с вашим лицом и голосом, контент-план и публикации — агент-блогер работает на ваш канал.',
    },
  },
  {
    id: 'twin',
    icon: '◈',
    name: { en: 'Developer Agent', ru: 'Разработчик агент' },
    promise: {
      en: 'An agent the team develops for your task: your character, voice, face, skills and tools in a bot of its own.',
      ru: 'Агент, которого команда разрабатывает под вашу задачу: ваш характер, голос, лицо, навыки и инструменты в отдельном боте.',
    },
  },
  {
    id: 'tridev',
    icon: '▽',
    name: { en: 'TRI DEV', ru: 'TRI DEV' },
    promise: {
      en: 'Give it a GitHub issue: it works the tri pipeline remotely and sends back a pull request and a t27.ai/term recording of every command it ran.',
      ru: 'Дайте задачу на GitHub: агент решает её удалённо по конвейеру tri и присылает pull request и запись терминала t27.ai/term со всеми командами.',
    },
  },
]
