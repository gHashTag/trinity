// TOKEN: TRI, what it is right now, and who has earned it.
//
// Owner's word, 2026-10-02: a tab with the token and its leaderboard, ranked by
// GitHub account. Two live reads and nothing typed in by hand:
//
// - the minter's `get_tri_state` on TON testnet: minted, cap, epoch, quorum;
// - the Queen's `/queen/public-earnings`: every accepted spec, by the lender
//   whose lane carried it, at the rate the ledger itself states.
//
// The status line is not decoration. This is a testnet token under a signer
// quorum, and a page that showed balances without saying so would be making a
// claim about value that nothing here backs.
//
// Withdrawing is not done here: it needs the person's Telegram identity, a
// linked GitHub and their own TON wallet, and all three live in the app's
// profile, so this tab points there.

import { useEffect, useState } from 'react'
import {
  formatTri,
  MTRI_PER_TRI,
  rankByGithub,
  readEarnings,
  readMinterState,
  TRI_EXPLORER,
  TRI_MINTER,
  type MinterState,
  type TriEarnings,
} from '../lib/triToken'
import './QueenPeople.css'
import './QueenToken.css'

export interface TokenCopy {
  title: string
  lead: string
  status: string
  minted: string
  cap: string
  epoch: string
  quorum: (threshold: number, signers: number) => string
  minter: string
  chainFailed: string
  boardTitle: string
  boardLead: (triPerSpec: number) => string
  specs: string
  revoked: string
  unclaimed: (specs: number) => string
  noLedger: string
  ledgerFailed: string
  empty: string
  loading: string
  withdraw: string
  withdrawLink: string
  measured: string
}

export const TOKEN_COPY: Record<'en' | 'ru', TokenCopy> = {
  en: {
    title: 'TRI',
    lead: 'The token an accepted .t27 spec mints. There is no pre-mine and no sale: every TRI that exists was minted for a spec the Queen accepted and its pull request merged.',
    status: 'Testnet only — V1, signer quorum, NOT trustless. A TRI here has no market and no price.',
    minted: 'Minted',
    cap: 'Cap',
    epoch: 'Epoch',
    quorum: (threshold, signers) => `${threshold} of ${signers} signers`,
    minter: 'Minter',
    chainFailed: 'The minter could not be read from TON testnet.',
    boardTitle: 'WHO EARNED IT',
    boardLead: (triPerSpec) =>
      `${triPerSpec} TRI for every spec the Queen accepted, credited to the GitHub account of the lane that carried it. A revoked acceptance is shown and pays nothing.`,
    specs: 'specs',
    revoked: 'revoked',
    unclaimed: (specs) =>
      `${specs} accepted specs ran on lanes not yet tied to a GitHub account, so they are counted here and credited to nobody.`,
    noLedger: 'The Queen does not publish the earnings ledger yet. Until she does, this board stays empty rather than guessing.',
    ledgerFailed: 'The earnings ledger could not be read.',
    empty: 'No spec has been accepted yet.',
    loading: 'Reading the chain and the ledger…',
    withdraw: 'To withdraw what you earned: open your profile in the app, link GitHub and a TON wallet, and press Withdraw. Your own wallet signs the mint and pays the gas.',
    withdrawLink: 'Open my profile',
    measured: 'Measured',
  },
  ru: {
    title: 'TRI',
    lead: 'Токен, который выпускает принятая спека .t27. Ни предварительного выпуска, ни продажи: каждый существующий TRI выпущен за спеку, которую приняла Королева и чей пулл-реквест смержен.',
    status: 'Только testnet — V1, кворум подписантов, НЕ trustless. У TRI здесь нет рынка и нет цены.',
    minted: 'Выпущено',
    cap: 'Потолок',
    epoch: 'Эпоха',
    quorum: (threshold, signers) => `${threshold} из ${signers} подписантов`,
    minter: 'Минтер',
    chainFailed: 'Минтер в TON testnet прочитать не удалось.',
    boardTitle: 'КТО ЗАРАБОТАЛ',
    boardLead: (triPerSpec) =>
      `${triPerSpec} TRI за каждую спеку, принятую Королевой, — на GitHub-аккаунт полосы, которая её вынесла. Отозванная приёмка показана и ничего не платит.`,
    specs: 'спек',
    revoked: 'отозвано',
    unclaimed: (specs) =>
      `${specs} принятых спек прошли по полосам, ещё не привязанным к аккаунту GitHub, поэтому они посчитаны здесь и не приписаны никому.`,
    noLedger: 'Королева пока не публикует журнал заработка. До тех пор эта доска пуста, а не угадана.',
    ledgerFailed: 'Журнал заработка прочитать не удалось.',
    empty: 'Ни одна спека ещё не принята.',
    loading: 'Читаю цепочку и журнал…',
    withdraw: 'Чтобы вывести заработанное: откройте свой профиль в приложении, привяжите GitHub и TON-кошелёк и нажмите «Вывести». Минт подписывает ваш собственный кошелёк, он же платит газ.',
    withdrawLink: 'Открыть мой профиль',
    measured: 'Измерено',
  },
}

const fmt = (n: number) => n.toLocaleString('en-US')

type Read<T> = { state: 'loading' } | { state: 'ok'; value: T } | { state: 'failed' }

export default function QueenToken({ lang }: { lang: 'en' | 'ru' }) {
  const c = TOKEN_COPY[lang === 'ru' ? 'ru' : 'en']
  const [minter, setMinter] = useState<Read<MinterState>>({ state: 'loading' })
  const [ledger, setLedger] = useState<Read<TriEarnings | null>>({ state: 'loading' })

  useEffect(() => {
    const abort = new AbortController()
    readMinterState(abort.signal)
      .then((value) => setMinter({ state: 'ok', value }))
      .catch(() => !abort.signal.aborted && setMinter({ state: 'failed' }))
    readEarnings(abort.signal)
      .then((value) => setLedger({ state: 'ok', value }))
      .catch(() => !abort.signal.aborted && setLedger({ state: 'failed' }))
    return () => abort.abort()
  }, [])

  return (
    <div className="qt">
      <header className="qt-head">
        <h2>{c.title}</h2>
        <p>{c.lead}</p>
        <p className="qt-status" role="note">
          {c.status}
        </p>
      </header>

      {minter.state === 'loading' ? (
        <p className="qp-note">{c.loading}</p>
      ) : minter.state === 'failed' ? (
        <p className="qp-note" role="alert">
          {c.chainFailed}
        </p>
      ) : (
        <dl className="qt-facts">
          <div>
            <dt>{c.minted}</dt>
            <dd>{formatTri(minter.value.minted)} TRI</dd>
          </div>
          <div>
            <dt>{c.cap}</dt>
            <dd>{formatTri(minter.value.cap)} TRI</dd>
          </div>
          <div>
            <dt>{c.epoch}</dt>
            <dd>{minter.value.epoch}</dd>
          </div>
          <div>
            <dt>{c.minter}</dt>
            <dd>
              <a href={TRI_EXPLORER} target="_blank" rel="noreferrer noopener" title={TRI_MINTER}>
                {TRI_MINTER.slice(0, 6)}…{TRI_MINTER.slice(-4)}
              </a>{' '}
              <small>{c.quorum(minter.value.threshold, minter.value.signers)}</small>
            </dd>
          </div>
        </dl>
      )}

      <section className="qp" aria-label={c.boardTitle}>
        <h3 className="qp-title">{c.boardTitle}</h3>
        <TokenBoard c={c} ledger={ledger} />
      </section>

      <p className="qt-withdraw">
        {c.withdraw}{' '}
        <a href="#/queen?tab=tri&screen=profile">{c.withdrawLink} →</a>
      </p>
    </div>
  )
}

function TokenBoard({ c, ledger }: { c: TokenCopy; ledger: Read<TriEarnings | null> }) {
  if (ledger.state === 'loading') return <p className="qp-note">{c.loading}</p>
  if (ledger.state === 'failed')
    return (
      <p className="qp-note" role="alert">
        {c.ledgerFailed}
      </p>
    )
  if (ledger.value === null) return <p className="qp-note">{c.noLedger}</p>

  const { triPerSpec, earners, measuredAt } = ledger.value
  const { rows, unclaimed } = rankByGithub(earners)
  const tri = (specs: number) => formatTri(BigInt(specs * triPerSpec * MTRI_PER_TRI))

  return (
    <>
      <p className="qp-lead">{c.boardLead(triPerSpec)}</p>
      {rows.length === 0 && unclaimed.earned === 0 ? (
        <p className="qp-note">{c.empty}</p>
      ) : (
        <ol className="qp-rows">
          {rows.map((row, i) => (
            <li key={row.login} className="qp-row">
              <span className="qp-rank">{i + 1}</span>
              <img
                className="qp-face"
                src={`https://github.com/${row.login}.png?size=96`}
                alt=""
                loading="lazy"
                width={36}
                height={36}
              />
              <span className="qp-who">
                <a href={`https://github.com/${row.login}`} target="_blank" rel="noreferrer noopener">
                  {row.login}
                </a>
                <b className="qp-repos">
                  {fmt(row.earned)} {c.specs}
                  {row.revoked > 0 && ` · ${fmt(row.revoked)} ${c.revoked}`}
                </b>
              </span>
              <span className="qp-commits">
                <b>{tri(row.earned)}</b> TRI
              </span>
            </li>
          ))}
        </ol>
      )}
      {unclaimed.earned > 0 && <p className="qp-counted">{c.unclaimed(unclaimed.earned)}</p>}
      <p className="qp-counted">
        {c.measured}: {measuredAt.slice(0, 16).replace('T', ' ')} UTC
      </p>
    </>
  )
}
