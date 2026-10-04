import { useI18n } from '../i18n/context'
import { LAYERS, ceiling, flowAfter, flowBefore } from '../data/devkit'
import { CLUB, clubPrice } from '../data/club'
import './DevKitBlock.css'

// The newest measured work and the one paid offer, on the front door. Every
// figure is read from data/devkit.ts and data/club.ts, the same files #/devkit,
// #/foundry and the flow post read, so the homepage cannot quote a number the
// pages behind it have since changed.

const PNR = LAYERS.find((l) => l.id === 'L2')!
const FASM = LAYERS.find((l) => l.id === 'L3')!
const s = (x: number) => `${x.toFixed(1)} s`

const COPY = {
  en: {
    eyebrow: 'TRI DEV KIT · measured 2026-10-03',
    title: 'The FPGA flow, layer by layer',
    lede: `One openXC7 build, every layer timed. bitwalk replaces FASM to frames and frames to .bit, built from the specs: the same bytes out, and the whole flow from ${s(flowBefore)} to ${s(flowAfter)}.`,
    stats: [
      { n: `${s(flowBefore)} → ${s(flowAfter)}`, t: `the whole build, ${(flowBefore / flowAfter).toFixed(2)}× with byte-identical output` },
      { n: `${FASM.s.toFixed(1)} s → ${FASM.t27!.s.toFixed(2)} s`, t: 'FASM to frames: fasm2frames.py against bitwalk --fasm' },
      { n: `${((100 * PNR.s) / flowBefore).toFixed(0)} %`, t: `of the build is place and route; at 0 s it would cap the flow at ${ceiling(PNR).x.toFixed(2)}×, a bound rather than a result` },
    ],
    calc: 'Count your hours →',
    post: 'Read the post',
    note: 'tri devkit and bitwalk are not in a tri release yet:',
    clubEyebrow: 'Golden Foundry club',
    clubTitle: 'TRI DEV · developer agent',
    clubBody: 'An autonomous Claude Code agent bound to one of your GitHub issues. It works the tri pipeline — spec, generate, test, verdict — reports each step on the issue, and delivers a pull request you review and merge. With it: measurement teardowns and runs on live Artix-7 boards.',
    clubCta: 'Join the club',
  },
  ru: {
    eyebrow: 'TRI DEV KIT · замер 2026-10-03',
    title: 'Поток FPGA, слой за слоем',
    lede: `Одна сборка openXC7, каждый слой засечён. bitwalk, собранный из спек, заменяет FASM → кадры и кадры → .bit: на выходе те же байты, а весь поток — ${s(flowBefore)} → ${s(flowAfter)}.`,
    stats: [
      { n: `${s(flowBefore)} → ${s(flowAfter)}`, t: `вся сборка, ${(flowBefore / flowAfter).toFixed(2)}× при побайтно одинаковом выходе` },
      { n: `${FASM.s.toFixed(1)} s → ${FASM.t27!.s.toFixed(2)} s`, t: 'FASM → кадры: fasm2frames.py против bitwalk --fasm' },
      { n: `${((100 * PNR.s) / flowBefore).toFixed(0)} %`, t: `сборки — размещение и трассировка; при 0 с поток упёрся бы в ${ceiling(PNR).x.toFixed(2)}× — это граница, а не результат` },
    ],
    calc: 'Посчитать свои часы →',
    post: 'Читать пост',
    note: 'tri devkit и bitwalk ещё не вошли в релиз tri:',
    clubEyebrow: 'Клуб «Золотая Литейная»',
    clubTitle: 'TRI DEV · агент-разработчик',
    clubBody: 'Автономный агент Claude Code, привязанный к одной вашей задаче на GitHub. Он идёт по конвейеру tri — спека, генерация, тесты, вердикт — отчитывается в задаче и приносит pull request, который проверяете и сливаете вы. Вместе с ним — разборы замеров и прогоны на живых платах Artix-7.',
    clubCta: 'Вступить в клуб',
  },
} as const

export default function DevKitBlock() {
  const { lang } = useI18n()
  const ru = lang === 'ru'
  const t = COPY[ru ? 'ru' : 'en']

  return (
    <section className="devkit-block" aria-labelledby="devkit-block-title">
      <div className="devkit-block-inner">
        <header className="devkit-block-head">
          <span className="devkit-block-eyebrow">{t.eyebrow}</span>
          <h2 id="devkit-block-title">{t.title}</h2>
          <p>{t.lede}</p>
        </header>

        <ol className="site-card-row devkit-block-stats">
          {t.stats.map((x) => (
            <li className="site-card" key={x.n}>
              <strong>{x.n}</strong>
              <span>{x.t}</span>
            </li>
          ))}
        </ol>

        <div className="devkit-block-actions">
          <a className="devkit-block-primary" href="#/devkit">{t.calc}</a>
          <a className="devkit-block-secondary" href="#/blog/the-fpga-flow-layer-by-layer">{t.post}</a>
          <small>
            {t.note}{' '}
            <a href="https://github.com/gHashTag/trinity/issues/1272" target="_blank" rel="noopener noreferrer">trinity#1272</a>
          </small>
        </div>

        <a className="site-card devkit-block-club" href={CLUB.href}>
          <span className="devkit-block-eyebrow">{t.clubEyebrow}</span>
          <span className="devkit-block-club-row">
            <strong>{t.clubTitle}</strong>
            <b>{clubPrice(ru)}</b>
          </span>
          <span className="devkit-block-club-body">{t.clubBody}</span>
          <span className="devkit-block-club-cta">{t.clubCta} →</span>
        </a>
      </div>
    </section>
  )
}
