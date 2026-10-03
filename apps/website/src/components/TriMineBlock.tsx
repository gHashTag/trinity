import { useEffect, useState } from 'react'
import { useI18n } from '../i18n/context'
import { QUEEN_API } from '../lib/queenApi'
import { MINE_LINKS, minePrompt, type MineFacts, type MineRoads } from '../lib/triMine'
import { formatTri, readEarnings, readMinterState, TRI_EXPLORER, TRI_NETWORK } from '../lib/triToken'

// MINE TRI, on the front door. Owner's word, 2026-10-03: the landing says what
// the token is right now, and one button hands a visitor's agent the work order
// for mining it.
//
// The numbers are the token tab's two live reads, nothing typed in here: the
// minter's `get_tri_state` (minted, cap) and the Queen's ledger (TRI per spec,
// how many earned). A read that fails shows a dash, and the copied prompt then
// tells the agent where to read the number instead of carrying a stale one.
//
// The status line stays next to the numbers on purpose: a testnet token under a
// signer quorum, shown without saying so, would be a claim about value that
// nothing here backs.

const COPY = {
  en: {
    eyebrow: 'MINE TRI',
    title: 'TRI is mined by accepted work, not sold',
    lede: 'A TRI is minted for a .t27 spec the Queen accepted and whose pull request merged, credited to its author by GitHub login — or earned by a lane that ran on your own CPU, FPGA or GPU. There was no pre-mine and there is no sale.',
    status: 'TON testnet only — V1, signer quorum, NOT trustless. No market, no price.',
    minted: 'Minted',
    cap: 'Cap',
    perSpec: 'TRI per accepted spec',
    earners: 'Earners on the ledger',
    copy: 'Copy to agent',
    copied: 'Copied — paste it to your agent',
    copyFailed: 'This page cannot reach the clipboard here. Select the text below and copy it.',
    copyHint: 'Paste it into Claude Code, Codex, Cursor or any agent with GitHub access. It works from your account, and asks you before it sends anything.',
    show: 'Read what it copies',
    token: 'Open the token tab',
    minter: 'Minter on testnet',
  },
  ru: {
    eyebrow: 'МАЙНИТЬ TRI',
    title: 'TRI добывается принятой работой, а не продаётся',
    lede: 'TRI выпускается за спеку .t27, которую приняла Королева и чей pull request смержен, — автору по логину GitHub; или зарабатывается полосой, которая работала на ваших CPU, FPGA или GPU. Предварительного выпуска не было, продажи нет.',
    status: 'Только TON testnet — V1, кворум подписантов, НЕ trustless. Рынка и цены нет.',
    minted: 'Выпущено',
    cap: 'Потолок',
    perSpec: 'TRI за принятую спеку',
    earners: 'Заработавших в журнале',
    copy: 'Скопировать агенту',
    copied: 'Скопировано — вставьте агенту',
    copyFailed: 'Здесь страница не может достать буфер обмена. Выделите текст ниже и скопируйте.',
    copyHint: 'Вставьте в Claude Code, Codex, Cursor или любого агента с доступом к GitHub. Он работает из вашего аккаунта и спрашивает вас, прежде чем что-то отправить.',
    show: 'Что именно копируется',
    token: 'Открыть вкладку токена',
    minter: 'Минтер в testnet',
  },
} as const

type CopyState = 'idle' | 'copied' | 'failed'

const ROADS: MineRoads = {
  ledger: `${QUEEN_API}/queen/public-earnings`,
  minter: TRI_EXPLORER,
  network: TRI_NETWORK,
}

export default function TriMineBlock() {
  const { lang } = useI18n()
  const key = lang === 'ru' ? 'ru' : 'en'
  const t = COPY[key]
  const [facts, setFacts] = useState<MineFacts>({})
  const [earners, setEarners] = useState<number | null>(null)
  const [copyState, setCopyState] = useState<CopyState>('idle')
  const [open, setOpen] = useState(false)

  useEffect(() => {
    const abort = new AbortController()
    readMinterState(abort.signal)
      .then((s) => setFacts((f) => ({ ...f, minted: formatTri(s.minted), cap: formatTri(s.cap) })))
      .catch(() => { /* a dash, and the prompt points at the minter */ })
    readEarnings(abort.signal)
      .then((e) => {
        if (!e) return
        setFacts((f) => ({ ...f, triPerSpec: e.triPerSpec }))
        setEarners(e.earners.filter((x) => x.claimed && x.earned > 0).length)
      })
      .catch(() => { /* a dash, and the prompt points at the ledger */ })
    return () => abort.abort()
  }, [])

  const prompt = minePrompt(key, ROADS, facts)

  const copy = () => {
    // A sandboxed frame has the API and refuses the write; say so and open the
    // text, rather than leave a button that reported nothing either way.
    const fail = () => { setCopyState('failed'); setOpen(true) }
    if (!navigator.clipboard?.writeText) return fail()
    navigator.clipboard.writeText(prompt).then(() => {
      setCopyState('copied')
      setTimeout(() => setCopyState('idle'), 2500)
    }, fail)
  }

  const dash = (v: string | number | null | undefined) => (v === undefined || v === null ? '—' : String(v))

  return (
    <section className="play-block tri-mine" id="mine" aria-labelledby="mine-title">
      <div className="play-block-inner">
        <header className="play-block-head">
          <span className="play-block-eyebrow">{t.eyebrow}</span>
          <h2 id="mine-title">{t.title}</h2>
          <p>{t.lede}</p>
          <p className="tri-mine-status">{t.status}</p>
        </header>

        <dl className="tri-mine-stats site-card-row">
          <div className="site-card"><dt>{t.minted}</dt><dd>{dash(facts.minted)}</dd></div>
          <div className="site-card"><dt>{t.cap}</dt><dd>{dash(facts.cap)}</dd></div>
          <div className="site-card"><dt>{t.perSpec}</dt><dd>{dash(facts.triPerSpec)}</dd></div>
          <div className="site-card"><dt>{t.earners}</dt><dd>{dash(earners)}</dd></div>
        </dl>

        <div className="tri-mine-actions">
          <button type="button" className="tri-mine-copy" onClick={copy} aria-describedby="mine-hint">
            {copyState === 'copied' ? t.copied : t.copy}
          </button>
          <a href={MINE_LINKS.token.replace('https://t27.ai/', '')}>{t.token} →</a>
          <a href={TRI_EXPLORER} target="_blank" rel="noopener noreferrer">{t.minter} →</a>
        </div>
        <p id="mine-hint" className="tri-mine-hint" role="status">
          {copyState === 'failed' ? t.copyFailed : t.copyHint}
        </p>

        <details className="tri-mine-prompt" open={open} onToggle={(e) => setOpen(e.currentTarget.open)}>
          <summary>{t.show}</summary>
          <pre>{prompt}</pre>
        </details>
      </div>
    </section>
  )
}
