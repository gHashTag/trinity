// MINE TRI: the words a visitor hands to their own agent.
//
// Owner's word, 2026-10-03: the landing says what the token is right now, and
// a "Copy to agent" button gives a person's agent everything it needs to mine
// TRI on that person's behalf. Mining here is not hashing: a TRI is minted for
// a .t27 spec the Queen accepted and whose pull request merged, or earned by a
// lane that ran on the person's own machine. So the prompt is the work order
// for exactly that, and nothing a chain does not back.
//
// Every number the prompt carries is read live by the block that renders it
// (the minter's `get_tri_state`, the token tab's counts). When a read fails the
// prompt says where to read it rather than printing a number this file would
// have to keep true by hand.
//
// Nothing here restates a rule another file owns (owner, 2026-10-03: "DRY"):
// who earns is TOKEN_COPY.rule, the token's status is TOKEN_COPY.status
// (lib/triTokenCopy.ts), and what counts as a rate is validRate
// (lib/triBoard.ts). The guard rails are the agent's own: never a provider key
// in a pull request or a chat, and a human reads the diff before it is sent.
//
// Imports only import-free files, with explicit extensions, so plain node runs
// it in qa/tri-mine-contract.mjs without Vite's import.meta.env; the ledger
// address and the minter come in from the block.

import { validRate } from './triBoard.ts'
import { TOKEN_COPY } from './triTokenCopy.ts'

export const MINE_LINKS = {
  board: 'https://t27.ai/#/queen?tab=kanban',
  explorer: 'https://t27.ai/#/specs',
  token: 'https://t27.ai/#/queen?tab=token',
  runners: 'https://t27.ai/#/queen?tab=leaderboard',
  howToJoin: 'https://t27.ai/blog/how-to-join-the-swarm/',
  minedNotSold: 'https://t27.ai/blog/tri-mined-not-sold/',
  issues: 'https://github.com/gHashTag/t27/issues',
} as const

/** Where the live figures are read; the block passes the real ones. */
export interface MineRoads {
  /** `${QUEEN_API}/queen/public-earnings`: only its rate, triPerSpec. */
  ledger: string
  /** TRI_EXPLORER: the minter on the explorer. */
  minter: string
  /** TRI_NETWORK */
  network: string
}

/** What the block managed to read; every field may be missing. */
export interface MineFacts {
  /** TRI per spec, as the ledger states it. */
  triPerSpec?: number
  /** Already formatted, e.g. "377". */
  minted?: string
  cap?: string
}

type Lang = 'en' | 'ru'

const rate = (lang: Lang, f: MineFacts, r: MineRoads) =>
  validRate(f.triPerSpec)
    ? TOKEN_COPY[lang].rate(f.triPerSpec)
    : lang === 'ru'
      ? `ставку за спеку прочитай в журнале: ${r.ledger} (поле triPerSpec).`
      : `read the rate per spec from the ledger: ${r.ledger} (field triPerSpec).`

const supply = (lang: Lang, f: MineFacts, r: MineRoads) =>
  f.minted && f.cap
    ? lang === 'ru'
      ? `Выпущено ${f.minted} TRI из потолка ${f.cap}.`
      : `${f.minted} TRI minted of a ${f.cap} cap.`
    : lang === 'ru'
      ? `Выпуск и потолок читай у минтера: ${r.minter}`
      : `Read minted and cap from the minter: ${r.minter}`

/**
 * The prompt the "Copy to agent" button puts on the clipboard.
 *
 * Plain text, one instruction per line, so it survives any chat box. It names
 * the person's GitHub account as the one that earns, because the leaderboard
 * credits the login, not the agent.
 */
export function minePrompt(lang: Lang, roads: MineRoads, facts: MineFacts = {}): string {
  if (lang === 'ru') {
    return [
      'Помоги мне майнить TRI на t27.ai. Майнинг здесь — не хеширование: TRI выпускается за спеку .t27, которую приняла Королева и чей pull request смержен.',
      '',
      `Факты: сеть TON ${roads.network}. ${TOKEN_COPY.ru.status} ${supply(lang, facts, roads)} Ставка: ${rate(lang, facts, roads)} Предварительного выпуска нет, продажи нет.`,
      '',
      `Кто зарабатывает: ${TOKEN_COPY.ru.rule} Значит, всё делается из МОЕГО аккаунта GitHub.`,
      '',
      'Шаги:',
      `1. Найди открытую задачу, у которой в разделе "## Boundary" назван файл .t27: доска ${MINE_LINKS.board} или ${MINE_LINKS.issues}. Прочитай её критерии приёмки — это договор.`,
      `2. Напиши спеку .t27 (не код, который из неё родится). Форму возьми у соседней спеки в обозревателе ${MINE_LINKS.explorer}: константы, тип, функции, test, invariant.`,
      '3. Скомпилируй её настоящим компилятором (обозреватель или t27c). Не компилируется — значит, это ещё не спека.',
      '4. Покажи мне дифф. Только после моего «да» открой pull request из моего аккаунта GitHub со ссылкой на задачу; он должен менять объявленный файл .t27.',
      `5. Когда Королева примет работу и PR смержат, заработок появится на вкладке ${MINE_LINKS.token} под моим логином GitHub.`,
      `6. Второй путь — своё железо: запусти раннер на моей машине под моим аккаунтом провайдера (${MINE_LINKS.runners}, «Мои раннеры»; руководство: ${MINE_LINKS.howToJoin}). Ключ провайдера остаётся на моей машине.`,
      '7. Вывод: профиль в приложении → привязать GitHub и TON-кошелёк (testnet) → «Вывести». Минт подписывает мой кошелёк, он же платит газ.',
      '',
      'Правила:',
      '- Никогда не вставляй ключ провайдера, токен или пароль в PR, задачу, коммит или чат.',
      '- Не покупай и не продавай TRI и не обещай мне его цену: её нет. Mainnet TRI не существует.',
      `- Не выдумывай приёмку: заработок — только то, что считает лидерборд (${MINE_LINKS.runners}).`,
      '- Одна задача — один PR, маленький и понятный для ревью.',
      `Подробно о том, почему TRI добывается, а не продаётся: ${MINE_LINKS.minedNotSold}`,
    ].join('\n')
  }
  return [
    'Help me mine TRI on t27.ai. Mining here is not hashing: a TRI is minted for a .t27 spec the Queen accepted and whose pull request merged.',
    '',
    `Facts: TON ${roads.network}. ${TOKEN_COPY.en.status} ${supply(lang, facts, roads)} Rate: ${rate(lang, facts, roads)} No pre-mine, no sale.`,
    '',
    `Who earns: ${TOKEN_COPY.en.rule} So everything is done from MY GitHub account.`,
    '',
    'Steps:',
    `1. Find an open issue whose "## Boundary" section names a .t27 file: the board ${MINE_LINKS.board} or ${MINE_LINKS.issues}. Read its acceptance criteria; they are the contract.`,
    `2. Write the .t27 spec (not the code it generates). Take the shape from a neighbouring spec in the Explorer ${MINE_LINKS.explorer}: constants, a type, functions, a test, an invariant.`,
    '3. Compile it with the real compiler (the Explorer or t27c). If it does not compile, it is not a spec yet.',
    '4. Show me the diff. Only after my "yes", open a pull request from my GitHub account that references the issue and changes the declared .t27 file.',
    `5. Once the Queen accepts the work and the PR merges, the earning appears on ${MINE_LINKS.token} under my GitHub login.`,
    `6. The second road is your own hardware: run a runner on my machine under my own provider account (${MINE_LINKS.runners}, "My runners"; guide: ${MINE_LINKS.howToJoin}). The provider key stays on my machine.`,
    '7. To withdraw: the app profile -> link GitHub and a TON (testnet) wallet -> Withdraw. My own wallet signs the mint and pays the gas.',
    '',
    'Rules:',
    '- Never put a provider key, token or password in a PR, issue, commit or chat.',
    '- Do not buy or sell TRI and do not promise me a price: there is none. No mainnet TRI exists.',
    `- Do not invent an acceptance: an earning is only what the leaderboard counts (${MINE_LINKS.runners}).`,
    '- One issue, one small pull request a reviewer can read.',
    `Why TRI is mined and not sold: ${MINE_LINKS.minedNotSold}`,
  ].join('\n')
}
