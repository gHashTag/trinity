'use client'

// Главная страница t27.ai под статьёй «Trinity S³AI: Ternary Network Floats».
//
// Правило этого файла: ни одна цифра не живёт здесь. Все числа приходят из
// src/content/tnf.ts, где каждое несёт тег происхождения. Компонент отвечает
// только за то, как факт выглядит, и обязан показать его тег.

import { motion } from 'framer-motion'
import { useI18n } from '../../../i18n/context'
import { TrinityLogo } from '../../TrinityLogo'
import {
  TAG_LABEL, PAPER, hero, claim, formats, frontier, ladder,
  theorems, limits, landscape, findings, lineage, reproduce, author, invest, type Tag,
} from '../../../content/tnf'
import './tnf.css'

type Bi = { en: string; ru: string } | string

function useL() {
  const { lang } = useI18n()
  const key = (lang === 'ru' ? 'ru' : 'en') as 'ru' | 'en'
  return {
    key,
    L: (v: Bi | undefined): string => {
      if (v == null) return ''
      if (typeof v === 'string') return v
      return (v as any)[key] ?? (v as any).en ?? ''
    },
  }
}

const fade = {
  initial: { opacity: 0, y: 18 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, margin: '-60px' },
  transition: { duration: 0.5, ease: [0.22, 1, 0.36, 1] as [number, number, number, number] },
}

function TagChip({ tag }: { tag?: Tag }) {
  const { key } = useL()
  if (!tag) return null
  const t = TAG_LABEL[tag]
  return <span className="tnf-tag" style={{ color: t.color }}>{t[key]}</span>
}

function Head({ badge, title, lede, wide }: { badge: Bi; title: Bi; lede?: Bi; wide?: boolean }) {
  const { L } = useL()
  return (
    <motion.div {...fade}>
      <span className="tnf-badge">{L(badge)}</span>
      <h2 className={wide ? 'tnf-h2 wide' : 'tnf-h2'}>{L(title)}</h2>
      {lede ? <p className="tnf-lede">{L(lede)}</p> : null}
    </motion.div>
  )
}

/* ───────────────────────────── LOCKUP ───────────────────────────── */

// The mark, the house name above it, the format name below it — all three sized
// by one ratio rather than by eye. The symbol's height is the upper line times
// φ², the lower line is the upper line divided by φ, and the two gaps stand in
// the same relation to each other, so nothing in the group is an arbitrary
// number: the group is proportioned by the constant the formats are named for.
//
// Both lines are white and set in the page's own face. They were golden mono,
// which read as a third voice in a lockup that should have one.
//
// The lower line assembles letter by letter because it is the one name a visitor
// is asked to remember. Singular Network: the initials are the format's name in
// the paper and in every conformance vector, so a plural would unname it.
const TNF_WORDMARK = 'TERNARY NETWORK FLOATS'

function Lockup() {
  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.5 }}
      style={{
        display: 'flex', flexDirection: 'column', alignItems: 'center',
        margin: '0 auto var(--sp4)', textAlign: 'center',
      }}
    >
      <motion.div
        initial={{ opacity: 0, y: -8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.1 }}
        style={{
          fontSize: 'clamp(var(--f2), 3.4vw, var(--f4))',
          fontWeight: 300,
          letterSpacing: '0.146em', // 0.236 / φ
          color: 'var(--text)',
          lineHeight: 1,
          marginBottom: 'var(--sp1)',
        }}
      >
        Trinity S<sup style={{ fontSize: '0.618em', top: '-0.5em' }}>3</sup>AI
      </motion.div>

      {/* Знак — главный элемент связки, поэтому он и мерится от неё, а не
          подгоняется на глаз: визуальная высота знака = нижняя строка × φ⁴·⁵
          (полушаг той же шкалы, 8.72), то есть 26 px × 8.72 ≈ 227 px. Габарит
          SVG чуть больше визуальной высоты — внутренние поля viewBox дают
          коэффициент ≈0.9 (замерено), отсюда 227 / 0.9 ≈ 254 px. */}
      <TrinityLogo withLabel={false} height="clamp(128px, 21vw, 254px)" />

      <motion.div
        aria-label={TNF_WORDMARK}
        style={{
          display: 'flex', flexWrap: 'wrap', justifyContent: 'center',
          // φ⁻¹ от строки над знаком
          fontSize: 'clamp(var(--f0), 2.1vw, var(--f2))',
          fontWeight: 300,
          letterSpacing: 'clamp(0.146em, 0.618vw, 0.236em)',
          color: 'var(--text)',
          lineHeight: 1,
          marginTop: 'var(--sp0)', // the gap above the mark, divided by φ
        }}
      >
        {TNF_WORDMARK.split('').map((ch, i) => (
          <motion.span
            key={i}
            aria-hidden="true"
            initial={{ opacity: 0, y: 10, filter: 'blur(6px)' }}
            animate={{ opacity: ch === ' ' ? 1 : 0.92, y: 0, filter: 'blur(0px)' }}
            transition={{ duration: 0.45, delay: 0.5 + i * 0.035, ease: [0.22, 1, 0.36, 1] }}
            style={{ whiteSpace: 'pre' }}
          >
            {ch}
          </motion.span>
        ))}
      </motion.div>
    </motion.div>
  )
}

/* ───────────────────────────── HERO ───────────────────────────── */

export function TnfHero() {
  const { L, key } = useL()
  return (
    <section id="hero" className="tnf-section" style={{ borderTop: 'none', paddingTop: 'clamp(var(--sp4), 12vh, var(--sp5))' }}>
      <div className="tnf-wrap">
        <Lockup />

        {/* Слоган стоит там же, где стоял прежде — прямо под знаком, зелёным
            курсивным антиквой. Подпись под ним обязательна: без неё тождество
            читается как заявленная теорема, а это разные вещи. */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.35, duration: 0.7 }}
          style={{ margin: 'var(--sp1) 0 var(--sp2)' }}
        >
          <div style={{
            fontFamily: '"Times New Roman", Times, serif', fontStyle: 'italic', fontWeight: 400,
            fontSize: 'clamp(1.15rem, 4.2vw, 2rem)', color: 'var(--accent)', lineHeight: 1.1,
          }}>
            {hero.slogan.formula}
          </div>
          <div style={{ color: 'var(--muted)', fontSize: 'var(--f-1)', marginTop: '0.45rem', maxWidth: '46ch', textAlign: 'left', marginLeft: 0 }}>
            {L(hero.slogan.caption)}
          </div>
        </motion.div>

        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.6 }}>
          <span className="tnf-badge" style={{ color: 'var(--accent)' }}>{L(hero.eyebrow)}</span>

          <div
            className="tnf-mono"
            style={{
              /* Была clamp(--f4, 8vw, --f6) = до 110 px и перебивала знак:
                 формула читалась как заголовок страницы. Шаг вниз по шкале до
                 --f5 = 68 px даёт ровно φ к заголовку h1 (68 / 42 = 1.618) и
                 оставляет знак старшим по величине. */
              fontSize: 'clamp(var(--f3), 5.6vw, var(--f5))',
              fontWeight: 300,
              letterSpacing: '-0.03em',
              lineHeight: 1,
              margin: 'var(--sp0) 0 var(--sp2)',
              color: 'var(--golden)',
            }}
          >
            {hero.identity}
          </div>

          <h1 style={{ fontSize: 'clamp(var(--f2), 4.2vw, var(--f4))', fontWeight: 500, maxWidth: '30ch', letterSpacing: '-0.025em', lineHeight: 1.236 }}>
            {L(hero.headline)}
          </h1>
          <p className="tnf-lede" style={{ marginBottom: 'var(--sp3)' }}>{L(hero.sub)}</p>

          {/* Ступени 0.618 / 1.618 rem — то же отношение, что и во всей шкале. */}
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--sp0)', marginBottom: 'var(--sp3)' }}>
            <a href="#claim" style={{
              background: 'var(--accent)', color: '#000', padding: 'var(--sp0) var(--sp2)', borderRadius: '6px',
              fontWeight: 600, textDecoration: 'none', fontSize: 'var(--f-1)',
            }}>{L(hero.ctaPrimary)}</a>
            <a href="#limits" style={{
              border: '1px solid var(--border)', color: 'var(--text)', padding: 'var(--sp0) var(--sp2)',
              borderRadius: '6px', fontWeight: 600, textDecoration: 'none', fontSize: 'var(--f-1)',
            }}>{L(hero.ctaSecondary)}</a>
          </div>
        </motion.div>

        <motion.div {...fade} className="tnf-grid tnf-grid-2" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))' }}>
          {hero.metrics.map((m) => (
            <div className="tnf-cell" key={L(m.label)}>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: '0.5rem', flexWrap: 'wrap' }}>
                <span className="tnf-mono" style={{ fontSize: 'clamp(1.5rem, 3vw, 2rem)', fontWeight: 500 }}>{m.value}</span>
                <span className="tnf-mono" style={{ color: 'var(--muted)', fontSize: '0.85rem' }}>
                  {typeof m.unit === 'string' ? m.unit : (m.unit as any)[key]}
                </span>
              </div>
              <div style={{ fontSize: '0.88rem', margin: '0.5rem 0 0.6rem', lineHeight: 1.45 }}>{L(m.label)}</div>
              <div style={{ color: 'var(--muted)', fontSize: '0.78rem', lineHeight: 1.5, marginBottom: '0.7rem' }}>{L(m.note)}</div>
              <TagChip tag={m.tag} />
            </div>
          ))}
        </motion.div>

        <motion.div {...fade} style={{ marginTop: 'var(--sp2)', color: 'var(--muted)', fontSize: 'var(--f-1)' }}>
          {L(PAPER.title)} · {PAPER.author} · ORCID {PAPER.orcid} · {L(PAPER.date)} · {PAPER.theorems}{' '}
          {key === 'ru' ? 'теорем' : 'theorems'}
        </motion.div>

        {/* Две работы, на которых стоит эта: они были упомянуты в разделах ниже,
            но на первом экране их не было, а именно они дают читателю право
            проверять всё остальное. */}
        <motion.div {...fade} style={{ marginTop: 'var(--sp1)', display: 'flex', flexWrap: 'wrap', gap: 'var(--sp0) var(--sp2)', fontSize: 'var(--f-1)' }}>
          <span style={{ color: 'var(--muted)' }}>
            {key === 'ru' ? 'Работы, на которых это стоит:' : 'The work this stands on:'}
          </span>
          <a href="https://arxiv.org/abs/2606.05017" target="_blank" rel="noopener noreferrer"
             style={{ color: 'var(--text)', textDecoration: 'none', borderBottom: '1px solid var(--border)' }}>
            arXiv:2606.05017 — GoldenFloat{key === 'ru' ? ', правило полей' : ', the field rule'}
          </a>
          <a href="https://arxiv.org/abs/2606.09686" target="_blank" rel="noopener noreferrer"
             style={{ color: 'var(--text)', textDecoration: 'none', borderBottom: '1px solid var(--border)' }}>
            arXiv:2606.09686 — {key === 'ru' ? 'каталог 83 форматов' : 'the 83-format catalogue'}
          </a>
          <a href="#visuals" style={{ color: 'var(--accent)', textDecoration: 'none' }}>
            {key === 'ru' ? 'два чертежа по ним ↓' : 'two drawings from them ↓'}
          </a>
        </motion.div>
      </div>
    </section>
  )
}

/* ───────────────────────────── CLAIM ───────────────────────────── */

export function TnfClaim() {
  const { L } = useL()
  return (
    <section id="claim" className="tnf-section">
      <div className="tnf-wrap">
        <Head badge={claim.badge} title={claim.title} lede={claim.sub} wide />
        <motion.div {...fade} className="tnf-grid tnf-grid-3">
          {claim.legs.map((leg) => (
            <div className="tnf-cell" key={leg.n}>
              <div className="tnf-mono" style={{ color: 'var(--golden)', fontSize: '1.6rem', fontWeight: 300 }}>{leg.n}</div>
              <h3 style={{ fontSize: '1.1rem', fontWeight: 600, margin: '0.4rem 0 0.75rem' }}>{L(leg.name)}</h3>
              <p style={{ fontSize: '0.88rem', lineHeight: 1.6, margin: '0 0 1rem', maxWidth: 'none' }}>{L(leg.body)}</p>
              <TagChip tag={leg.tag} />
            </div>
          ))}
        </motion.div>
      </div>
    </section>
  )
}

/* ──────────────────────────── FORMATS ──────────────────────────── */

function FormatCard({ f }: { f: typeof formats.tnf }) {
  const { L } = useL()
  return (
    <div className="tnf-cell">
      <h3 className="tnf-mono" style={{ fontSize: '1.4rem', fontWeight: 500, marginBottom: '0.9rem' }}>{f.name}</h3>
      <div className="tnf-kbd tnf-mono" style={{ display: 'block', marginBottom: '0.5rem', whiteSpace: 'normal' }}>{L(f.layout)}</div>
      <div className="tnf-mono" style={{ color: 'var(--muted)', fontSize: '0.8rem', margin: '0.6rem 0' }}>{f.value}</div>
      <div style={{ color: 'var(--muted)', fontSize: '0.8rem', marginBottom: '1.5rem' }}>{L(f.rule)}</div>
      {f.props.map((p) => (
        <div key={L(p.h)} style={{ paddingTop: '1rem', marginTop: '1rem', borderTop: '1px solid var(--border)' }}>
          <div style={{ display: 'flex', gap: '0.6rem', alignItems: 'center', flexWrap: 'wrap', marginBottom: '0.45rem' }}>
            <strong style={{ fontSize: '0.92rem', fontWeight: 600 }}>{L(p.h)}</strong>
            <TagChip tag={p.tag} />
          </div>
          <p style={{ fontSize: '0.85rem', lineHeight: 1.6, margin: 0, maxWidth: 'none' }}>{L(p.b)}</p>
        </div>
      ))}
    </div>
  )
}

export function TnfFormats() {
  return (
    <section id="formats" className="tnf-section">
      <div className="tnf-wrap">
        <Head badge={formats.badge} title={formats.title} wide />
        <motion.div {...fade} className="tnf-grid tnf-grid-2">
          <FormatCard f={formats.tnf} />
          <FormatCard f={formats.gft as unknown as typeof formats.tnf} />
        </motion.div>
      </div>
    </section>
  )
}

/* ──────────────────────────── FRONTIER ──────────────────────────── */

export function TnfFrontier() {
  const { L, key } = useL()
  const maxLut = Math.max(...frontier.decoder.map((d) => d.lut))
  const maxTpa = Math.max(...frontier.neuron.map((d) => d.tpa))

  return (
    <section id="frontier" className="tnf-section">
      <div className="tnf-wrap">
        <Head badge={frontier.badge} title={frontier.title} lede={frontier.sub} wide />

        <motion.div {...fade} className="tnf-grid tnf-grid-2">
          <div className="tnf-cell">
            <div style={{ display: 'flex', gap: '0.6rem', alignItems: 'center', flexWrap: 'wrap', marginBottom: '1rem' }}>
              <strong style={{ fontSize: '0.9rem' }}>{L(frontier.decoderCaption)}</strong>
              <TagChip tag="measured" />
            </div>
            <div className="tnf-scroll">
              <table className="tnf-table">
                <thead>
                  <tr>
                    <th scope="col">#</th>
                    <th scope="col">{key === 'ru' ? 'формат' : 'format'}</th>
                    <th scope="col">{key === 'ru' ? 'вид' : 'kind'}</th>
                    <th scope="col">LUT</th>
                    <th scope="col">{key === 'ru' ? 'МГц' : 'MHz'}</th>
                    <th scope="col" style={{ width: '90px' }} />
                  </tr>
                </thead>
                <tbody>
                  {frontier.decoder.map((d) => (
                    <tr key={d.name} className={d.ours ? 'ours' : ''}>
                      <td className="tnf-mono" style={{ textAlign: 'left' }}>{d.rank}</td>
                      <td className="tnf-mono" style={{ textAlign: 'left' }}>{d.name}</td>
                      <td style={{ textAlign: 'left' }}>{L(d.kind)}</td>
                      <td className="tnf-mono">{d.lut}</td>
                      <td className="tnf-mono">{d.fmax.toFixed(2)}</td>
                      <td>
                        <div className="tnf-bar">
                          <i style={{ width: `${(d.lut / maxLut) * 100}%`, background: d.ours ? 'var(--accent)' : 'rgba(255,255,255,0.3)' }} />
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <p className="tnf-note">{L(frontier.decoderNote)}</p>
          </div>

          <div className="tnf-cell">
            <div style={{ display: 'flex', gap: '0.6rem', alignItems: 'center', flexWrap: 'wrap', marginBottom: '1rem' }}>
              <strong style={{ fontSize: '0.9rem' }}>{L(frontier.neuronCaption)}</strong>
              <TagChip tag="measured" />
            </div>
            <div className="tnf-scroll">
              <table className="tnf-table">
                <thead>
                  <tr>
                    <th scope="col">#</th>
                    <th scope="col">{key === 'ru' ? 'формат' : 'format'}</th>
                    <th scope="col">LUT</th>
                    <th scope="col">{key === 'ru' ? 'МГц/LUT' : 'MHz/LUT'}</th>
                    <th scope="col" style={{ width: '90px' }} />
                  </tr>
                </thead>
                <tbody>
                  {frontier.neuron.map((d) => (
                    <tr key={d.name} className={d.ours ? 'ours' : ''}>
                      <td className="tnf-mono" style={{ textAlign: 'left' }}>{d.rank}</td>
                      <td className="tnf-mono" style={{ textAlign: 'left' }}>{d.name}</td>
                      <td className="tnf-mono">{d.lut}</td>
                      <td className="tnf-mono">{d.tpa.toFixed(4)}</td>
                      <td>
                        <div className="tnf-bar">
                          <i style={{ width: `${(d.tpa / maxTpa) * 100}%`, background: d.ours ? 'var(--accent)' : 'rgba(255,255,255,0.3)' }} />
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <p className="tnf-note">{L(frontier.neuronNote)}</p>
          </div>
        </motion.div>

        <motion.div {...fade} className="tnf-grid" style={{ marginTop: '1.5rem', gridTemplateColumns: '1fr' }}>
          <div className="tnf-cell">
            <div style={{ display: 'flex', gap: '0.6rem', alignItems: 'center', flexWrap: 'wrap', marginBottom: '1rem' }}>
              <strong style={{ fontSize: '0.9rem' }}>{L(frontier.ops.title)}</strong>
              <TagChip tag={frontier.ops.tag} />
            </div>
            <div className="tnf-scroll">
              <table className="tnf-table">
                <thead>
                  <tr>
                    <th scope="col">{key === 'ru' ? 'семейство' : 'family'}</th>
                    <th scope="col" style={{ textAlign: 'left' }}>{key === 'ru' ? 'умножение' : 'multiply'}</th>
                    <th scope="col" style={{ textAlign: 'left' }}>{key === 'ru' ? 'сложение' : 'add'}</th>
                  </tr>
                </thead>
                <tbody>
                  {frontier.ops.rows.map((r) => (
                    <tr key={r.family} className={r.family === 'Z[φ]' ? 'ours' : ''}>
                      <td className="tnf-mono" style={{ textAlign: 'left' }}>{r.family}</td>
                      <td style={{ textAlign: 'left' }}>{L(r.mul)}</td>
                      <td style={{ textAlign: 'left' }}>{L(r.add)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  )
}

/* ───────────────────────────── LADDER ───────────────────────────── */

export function TnfLadder() {
  const { L, key } = useL()
  return (
    <section id="ladder" className="tnf-section">
      <div className="tnf-wrap">
        <Head badge={ladder.badge} title={ladder.title} lede={ladder.sub} wide />

        <motion.div {...fade} className="tnf-grid tnf-grid-2">
          <div className="tnf-cell">
            <div style={{ display: 'flex', gap: '0.6rem', alignItems: 'center', marginBottom: '1rem' }}>
              <strong style={{ fontSize: '0.9rem' }}>{key === 'ru' ? 'Perplexity по бюджету бит' : 'Perplexity by bit budget'}</strong>
              <TagChip tag="measured" />
            </div>
            <div className="tnf-scroll">
              <table className="tnf-table">
                <thead>
                  <tr>{ladder.header[key].map((h) => <th scope="col" key={h}>{h}</th>)}</tr>
                </thead>
                <tbody>
                  {ladder.rows.map((r) => (
                    <tr key={r.bits}>
                      <td className="tnf-mono" style={{ textAlign: 'left' }}>{r.bits}</td>
                      {r.vals.map((v, i) => (
                        <td key={i} className="tnf-mono" style={i === r.win ? { color: 'var(--accent)', fontWeight: 600 } : undefined}>{v}</td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <p className="tnf-note">
              {key === 'ru'
                ? 'На большей модели φ отделяется от supergolden на 10.7% против 2.7% на меньшей — двенадцать окон этого не разрешают. Единственное место, где замкнутая форма ошибается, — четырёхбитная пара, и исправляется она взвешиванием ошибки кривизной функции потерь, а не величиной веса.'
                : 'On the larger model φ separates from supergolden by 10.7% against 2.7% on the smaller — twelve windows do not resolve that. The single place the closed form errs is the four-bit pair, and it is fixed by weighting the error with loss curvature rather than with weight magnitude.'}
            </p>
          </div>

          <div className="tnf-cell">
            <div style={{ display: 'flex', gap: '0.6rem', alignItems: 'center', marginBottom: '1rem' }}>
              <strong style={{ fontSize: '0.9rem' }}>{L(ladder.hw.title)}</strong>
              <TagChip tag={ladder.hw.tag} />
            </div>
            <div className="tnf-scroll">
              <table className="tnf-table">
                <thead>
                  <tr>
                    <th scope="col">{key === 'ru' ? 'ступень' : 'rung'}</th>
                    <th scope="col">LUT</th>
                    <th scope="col">Fmax</th>
                    <th scope="col">ppl</th>
                    <th scope="col" style={{ textAlign: 'left' }}>vs fp32</th>
                  </tr>
                </thead>
                <tbody>
                  {ladder.hw.rows.map((r) => (
                    <tr key={r.rung} className="ours">
                      <td className="tnf-mono" style={{ textAlign: 'left' }}>{r.rung}</td>
                      <td className="tnf-mono">{r.lut}</td>
                      <td className="tnf-mono">{r.fmax}</td>
                      <td className="tnf-mono">{r.ppl}</td>
                      <td style={{ textAlign: 'left' }}>{L(r.vs)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <p className="tnf-note">
              {key === 'ru'
                ? 'Семейство r^d = r + 1 достигает любой гранулярности при одном сумматоре и d регистрах: тонкость стоит регистров, а не сумматоров.'
                : 'The family r^d = r + 1 reaches any granularity at one adder and d registers: fineness costs registers, not adders.'}
            </p>
          </div>
        </motion.div>

        <motion.div {...fade} className="tnf-grid" style={{ marginTop: '1.5rem', gridTemplateColumns: '1fr' }}>
          <div className="tnf-cell">
            <div style={{ display: 'flex', gap: '0.6rem', alignItems: 'center', flexWrap: 'wrap', marginBottom: '1rem' }}>
              <strong style={{ fontSize: '0.9rem' }}>{L(ladder.block.title)}</strong>
              <TagChip tag="competitor" />
            </div>
            <p style={{ fontSize: '0.88rem', lineHeight: 1.65, maxWidth: '76ch', margin: '0 0 1.5rem' }}>{L(ladder.block.closed)}</p>
            <strong style={{ fontSize: '0.9rem', display: 'block', marginBottom: '0.75rem' }}>{L(ladder.block.openTitle)}</strong>
            <div className="tnf-scroll">
              <table className="tnf-table">
                <thead>
                  <tr>
                    <th scope="col">{key === 'ru' ? 'схема' : 'scheme'}</th>
                    <th scope="col">{key === 'ru' ? 'бит масштаба/вес' : 'scale bits/weight'}</th>
                    <th scope="col">{key === 'ru' ? 'всего бит/вес' : 'total bits/weight'}</th>
                    <th scope="col">ppl A</th>
                    <th scope="col">ppl B</th>
                  </tr>
                </thead>
                <tbody>
                  {ladder.block.rows.map((r) => (
                    <tr key={r.scheme} className={r.ours ? 'ours' : ''}>
                      <td className="tnf-mono" style={{ textAlign: 'left' }}>{r.scheme}</td>
                      <td className="tnf-mono">{r.scaleBits}</td>
                      <td className="tnf-mono">{r.total}</td>
                      <td className="tnf-mono" style={r.ours ? { color: 'var(--accent)' } : undefined}>{r.a}</td>
                      <td className="tnf-mono" style={r.ours ? { color: 'var(--accent)' } : undefined}>{r.b}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <p className="tnf-note">{L(ladder.block.caveat)}</p>
          </div>
        </motion.div>
      </div>
    </section>
  )
}

/* ──────────────────────────── THEOREMS ──────────────────────────── */

export function TnfTheorems() {
  const { L } = useL()
  return (
    <section id="theorems" className="tnf-section">
      <div className="tnf-wrap">
        <Head badge={theorems.badge} title={theorems.title} wide />
        <motion.div {...fade} className="tnf-grid tnf-grid-2">
          {theorems.items.map((t) => (
            <div className="tnf-cell" key={t.id}>
              <div style={{ display: 'flex', gap: '0.6rem', alignItems: 'center', flexWrap: 'wrap', marginBottom: '0.6rem' }}>
                <span className="tnf-mono" style={{ color: 'var(--golden)', fontWeight: 600, fontSize: '0.95rem' }}>{t.id}</span>
                <strong style={{ fontSize: '0.98rem', fontWeight: 600 }}>{L(t.name)}</strong>
                <TagChip tag={t.tag} />
              </div>
              <p className="tnf-mono" style={{ fontSize: '0.82rem', lineHeight: 1.6, color: 'var(--text)', margin: '0 0 0.75rem', maxWidth: 'none', opacity: 0.85 }}>{L(t.stmt)}</p>
              <p style={{ fontSize: '0.85rem', lineHeight: 1.6, margin: 0, maxWidth: 'none' }}>{L(t.why)}</p>
            </div>
          ))}
        </motion.div>
      </div>
    </section>
  )
}

/* ───────────────────────────── LIMITS ───────────────────────────── */

export function TnfLimits() {
  const { L } = useL()
  return (
    <section id="limits" className="tnf-section" style={{ background: 'rgba(255,107,107,0.025)' }}>
      <div className="tnf-wrap">
        <Head badge={limits.badge} title={limits.title} lede={limits.sub} wide />
        <motion.div {...fade} className="tnf-grid tnf-grid-2">
          {limits.items.map((it) => (
            <div className="tnf-cell" key={L(it.h)}>
              <div style={{ display: 'flex', gap: '0.6rem', alignItems: 'center', flexWrap: 'wrap', marginBottom: '0.55rem' }}>
                <strong style={{ fontSize: '0.95rem', fontWeight: 600 }}>{L(it.h)}</strong>
                <TagChip tag={(it as any).tag} />
              </div>
              <p style={{ fontSize: '0.85rem', lineHeight: 1.65, margin: 0, maxWidth: 'none' }}>{L(it.b)}</p>
            </div>
          ))}
        </motion.div>
      </div>
    </section>
  )
}

/* ──────────────────────────── LANDSCAPE ──────────────────────────── */

const KIND_COLOR: Record<string, string> = {
  threat: '#FF6B6B', confirms: '#00FF88', context: '#9BA3AF', ours: '#FFD700',
}
const KIND_LABEL: Record<string, { en: string; ru: string }> = {
  threat: { en: 'competing ground', ru: 'конкурирующая земля' },
  confirms: { en: 'confirms the demand', ru: 'подтверждает спрос' },
  context: { en: 'context', ru: 'контекст' },
  ours: { en: 'our prior work', ru: 'наша предыдущая работа' },
}

export function TnfLandscape() {
  const { L, key } = useL()
  return (
    <section id="landscape" className="tnf-section">
      <div className="tnf-wrap">
        <Head badge={landscape.badge} title={landscape.title} lede={landscape.sub} wide />
        <motion.div {...fade} className="tnf-grid tnf-grid-2">
          {landscape.items.map((it) => (
            <div className="tnf-cell" key={typeof it.name === 'string' ? it.name : it.name.en}>
              <div style={{ display: 'flex', gap: '0.6rem', alignItems: 'center', flexWrap: 'wrap', marginBottom: '0.5rem' }}>
                {/* Часть имён — прозвища работ (takum, posit, MXFP4) и не переводятся;
                    те, что содержат английскую фразу, заданы парой языков. */}
                <strong style={{ fontSize: '0.98rem', fontWeight: 600 }}>{typeof it.name === 'string' ? it.name : L(it.name)}</strong>
                <span className="tnf-tag" style={{ color: KIND_COLOR[it.kind] }}>{KIND_LABEL[it.kind][key]}</span>
              </div>
              <div style={{ color: 'var(--muted)', fontSize: '0.78rem', marginBottom: '0.7rem' }}>
                {it.who} · <a className="tnf-link" href={it.url} target="_blank" rel="noopener noreferrer">{it.url.replace('https://', '')}</a>
              </div>
              <p style={{ fontSize: '0.85rem', lineHeight: 1.65, margin: 0, maxWidth: 'none' }}>{L(it.line)}</p>
            </div>
          ))}
        </motion.div>

        <motion.div {...fade} className="tnf-grid" style={{ marginTop: '1.5rem', gridTemplateColumns: '1fr' }}>
          <div className="tnf-cell">
            <strong style={{ fontSize: '0.9rem', display: 'block', marginBottom: '0.9rem' }}>{L(landscape.negatives.title)}</strong>
            <ul style={{ margin: 0, paddingLeft: '1.1rem', color: 'var(--muted)', fontSize: '0.85rem', lineHeight: 1.7 }}>
              {landscape.negatives.items.map((n) => <li key={L(n)}>{L(n)}</li>)}
            </ul>
            <p className="tnf-note">{L(landscape.negatives.caveat)}</p>
          </div>
        </motion.div>
      </div>
    </section>
  )
}

/* ───────────────────────────── FINDINGS ───────────────────────────── */

// Раздел «Выводы из исследования»: каждый пункт несёт тег происхождения и
// прямые ссылки на проверенные работы. Ни одна цифра не вписана здесь —
// весь текст и все ссылки приходят из content/tnf.ts.
export function TnfFindings() {
  const { L } = useL()
  return (
    <section id="findings" className="tnf-section" style={{ background: 'rgba(124,199,255,0.02)' }}>
      <div className="tnf-wrap">
        <Head badge={findings.badge} title={findings.title} lede={findings.sub} wide />
        <motion.div {...fade} className="tnf-grid tnf-grid-2">
          {findings.items.map((it) => (
            <div className="tnf-cell" key={it.n}>
              <div style={{ display: 'flex', gap: '0.6rem', alignItems: 'baseline', flexWrap: 'wrap', marginBottom: '0.55rem' }}>
                <span className="tnf-mono" style={{ color: 'var(--golden)', fontWeight: 600, fontSize: '0.9rem' }}>{it.n}</span>
                <strong style={{ fontSize: '0.98rem', fontWeight: 600 }}>{L(it.h)}</strong>
                <TagChip tag={it.tag} />
              </div>
              <p style={{ fontSize: '0.86rem', lineHeight: 1.68, margin: '0 0 0.85rem', maxWidth: 'none' }}>{L(it.b)}</p>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.45rem 1rem' }}>
                {it.refs.map((r) => (
                  <a className="tnf-link" key={r.url} href={r.url} target="_blank" rel="noopener noreferrer" style={{ fontSize: '0.76rem' }}>{r.label}</a>
                ))}
              </div>
            </div>
          ))}
        </motion.div>
        <motion.p {...fade} className="tnf-note" style={{ marginTop: '1.4rem' }}>{L(findings.footer)}</motion.p>
      </div>
    </section>
  )
}

/* ───────────────────────────── LINEAGE ───────────────────────────── */

export function TnfLineage() {
  const { L } = useL()
  return (
    <section id="lineage" className="tnf-section">
      <div className="tnf-wrap">
        <Head badge={lineage.badge} title={lineage.title} wide />
        <motion.div {...fade} style={{ borderLeft: '1px solid var(--border)', paddingLeft: 'clamp(1.25rem, 3vw, 2.5rem)', maxWidth: '80ch' }}>
          {lineage.items.map((it) => (
            <div key={it.year} style={{ position: 'relative', paddingBottom: '2rem' }}>
              <span style={{
                position: 'absolute', left: 'calc(-1 * clamp(1.25rem, 3vw, 2.5rem) - 4px)', top: '0.45rem',
                width: '7px', height: '7px', borderRadius: '50%', background: 'var(--golden)',
              }} />
              <div className="tnf-mono" style={{ color: 'var(--golden)', fontSize: '0.82rem', letterSpacing: '0.04em' }}>{it.year}</div>
              <strong style={{ display: 'block', fontSize: '1rem', fontWeight: 600, margin: '0.25rem 0 0.4rem' }}>{L(it.h)}</strong>
              <p style={{ fontSize: '0.87rem', lineHeight: 1.65, margin: 0, maxWidth: 'none' }}>{L(it.b)}</p>
            </div>
          ))}
        </motion.div>
      </div>
    </section>
  )
}

/* ──────────────────────────── REPRODUCE ──────────────────────────── */

/* Автор и сотрудничество. Место прежних секций «Команда» и «Инвестиции»:
   фотография, имя, ORCID и способ связи возвращаются, а числа берутся только
   те, что уже стоят на этой странице со своим происхождением. Оценка раунда и
   578× по энергии не возвращаются — они отозваны. */
export function TnfAuthor() {
  const { L, key } = useL()
  const a = author
  return (
    <section id="author" className="tnf-section">
      <div className="tnf-wrap">
        <Head badge={a.badge} title={a.title} lede={a.sub} wide />

        <motion.div
          {...fade}
          className="tnf-cell"
          style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--sp2)', alignItems: 'center', marginBottom: 'var(--sp2)' }}
        >
          <img
            src={a.photo}
            alt={key === 'ru' ? a.nameRu : a.name}
            loading="lazy"
            width={112}
            height={112}
            style={{ width: 112, height: 112, borderRadius: '50%', border: '1px solid var(--border)', flex: '0 0 auto' }}
          />
          <div style={{ flex: '1 1 300px' }}>
            <h3 style={{ fontSize: 'var(--f2)', fontWeight: 600, margin: '0 0 0.3rem' }}>
              {key === 'ru' ? a.nameRu : a.name}
            </h3>
            <p style={{ color: 'var(--muted)', fontSize: 'var(--f-1)', lineHeight: 1.6, margin: '0 0 0.7rem', maxWidth: '52ch' }}>
              {L(a.role)}
            </p>
            <p style={{ color: 'var(--muted)', fontSize: 'var(--f-2)', margin: 0 }}>
              ORCID {a.orcid} · <a className="tnf-link" href={`mailto:${a.email}`}>{a.email}</a>
            </p>
          </div>
        </motion.div>

        <motion.div {...fade} className="tnf-grid tnf-grid-4" style={{ marginBottom: 'var(--sp2)' }}>
          {a.facts.map((f) => (
            <div className="tnf-cell" key={f.v}>
              <strong style={{ display: 'block', fontSize: 'var(--f2)', fontWeight: 600, marginBottom: '0.3rem' }}>{f.v}</strong>
              <span style={{ color: 'var(--muted)', fontSize: 'var(--f-1)', lineHeight: 1.55, display: 'block', marginBottom: '0.5rem' }}>{L(f.l)}</span>
              <TagChip tag={f.tag as Tag} />
            </div>
          ))}
        </motion.div>

        {/* textAlign задан явно: секция центрирует свои прямые <p>, и абзац
            «здесь не заявляется» вставал по центру, ломая единую левую кромку. */}
        <motion.p {...fade} style={{ color: 'var(--muted)', fontSize: 'var(--f-1)', lineHeight: 1.7, maxWidth: '72ch', marginBottom: 'var(--sp3)', textAlign: 'left', marginLeft: 0 }}>
          {L(a.notClaimed)}
        </motion.p>

        <motion.div {...fade} className="tnf-grid tnf-grid-2">
          {a.links.map((l) => (
            <a
              className="tnf-cell"
              key={L(l.label)}
              href={l.href}
              style={{ textDecoration: 'none', color: 'inherit', display: 'block' }}
            >
              <strong style={{ fontSize: '0.93rem', fontWeight: 600, display: 'block', marginBottom: '0.4rem' }}>{L(l.label)} →</strong>
              <span style={{ color: 'var(--muted)', fontSize: '0.82rem', lineHeight: 1.55 }}>{L(l.note)}</span>
            </a>
          ))}
        </motion.div>
      </div>
    </section>
  )
}

/* Инвестиции. Блок стоял на прежнем лендинге, был снят вместе с ним и возвращён
   приведённым к остальной странице: условия раунда помечены как предложение,
   план — как план, а инженерные числа взяты те же, что измерены выше. Секция
   «что покупают, а что нет» стоит внутри блока, а не в сноске под ним, потому
   что в сноске её не читают. */
export function TnfInvest() {
  const { L } = useL()
  const v = invest
  const muted: React.CSSProperties = { color: 'var(--muted)', fontSize: 'var(--f-1)', lineHeight: 1.7, display: 'block' }
  /* Числа в блоке частично локализуемы: разделитель и суффикс порядка отличаются
     ($9.8B против $9,8 млрд), поэтому `v` — либо строка, либо пара языков. */
  const V = (x: string | { en: string; ru: string }) => (typeof x === 'string' ? x : L(x))
  const Src = ({ s }: { s?: { u: string; n: string } }) =>
    s ? (
      <a className="tnf-link" href={s.u} target="_blank" rel="noopener noreferrer" style={{ fontSize: 'var(--f-2)' }}>
        {s.n} ↗
      </a>
    ) : null
  return (
    <section id="invest" className="tnf-section">
      <div className="tnf-wrap">
        <Head badge={v.badge} title={v.title} lede={v.sub} wide />

        <motion.h3 {...fade} className="tnf-h3">{L(v.factsTitle)}</motion.h3>
        <motion.div {...fade} className="tnf-grid tnf-grid-3" style={{ marginBottom: 'var(--sp3)' }}>
          {v.facts.map((t) => (
            <div className="tnf-cell" key={V(t.v) + L(t.l)}>
              <strong style={{ display: 'block', fontSize: 'var(--f2)', fontWeight: 600, marginBottom: '0.3rem' }}>{V(t.v)}</strong>
              <span style={{ ...muted, marginBottom: '0.5rem' }}>{L(t.l)}</span>
              <TagChip tag={t.tag as Tag} />
            </div>
          ))}
        </motion.div>

        <motion.h3 {...fade} className="tnf-h3">{L(v.whyTitle)}</motion.h3>
        <motion.div {...fade} className="tnf-grid tnf-grid-2" style={{ marginBottom: 'var(--sp3)' }}>
          {v.why.map((w) => (
            <div className="tnf-cell" key={L(w.t)}>
              <strong style={{ display: 'block', fontSize: 'var(--f0)', fontWeight: 600, marginBottom: '0.4rem' }}>{L(w.t)}</strong>
              <span style={{ ...muted, marginBottom: '0.5rem' }}>{L(w.d)}</span>
              <span style={{ display: 'flex', gap: '0.6rem', alignItems: 'center', flexWrap: 'wrap' }}>
                <TagChip tag={w.tag as Tag} />
                <Src s={w.src} />
              </span>
            </div>
          ))}
        </motion.div>

        <motion.h3 {...fade} className="tnf-h3">{L(v.marketTitle)}</motion.h3>
        <motion.p {...fade} style={{ ...muted, maxWidth: '78ch', textAlign: 'left', marginLeft: 0, marginBottom: 'var(--sp1)' }}>{L(v.marketSub)}</motion.p>
        <motion.div {...fade} className="tnf-grid tnf-grid-4" style={{ marginBottom: 'var(--sp3)' }}>
          {v.market.map((m) => (
            <div className="tnf-cell" key={V(m.v) + L(m.l)}>
              <strong style={{ display: 'block', fontSize: 'var(--f1)', fontWeight: 600, marginBottom: '0.3rem' }}>{V(m.v)}</strong>
              <span style={{ ...muted, marginBottom: '0.5rem' }}>{L(m.l)}</span>
              <span style={{ display: 'flex', gap: '0.6rem', alignItems: 'center', flexWrap: 'wrap' }}>
                <TagChip tag={m.tag as Tag} />
                <Src s={m.src} />
              </span>
            </div>
          ))}
        </motion.div>

        <motion.h3 {...fade} className="tnf-h3">{L(v.modelTitle)}</motion.h3>
        <motion.div {...fade} className="tnf-grid tnf-grid-3" style={{ marginBottom: 'var(--sp3)' }}>
          {v.model.map((m) => (
            <div className="tnf-cell" key={L(m.t)}>
              <strong style={{ display: 'block', fontSize: 'var(--f0)', fontWeight: 600, marginBottom: '0.4rem' }}>{L(m.t)}</strong>
              <span style={{ ...muted, marginBottom: '0.5rem' }}>{L(m.d)}</span>
              <TagChip tag={m.tag as Tag} />
            </div>
          ))}
        </motion.div>

        <motion.h3 {...fade} className="tnf-h3">{L(v.doneTitle)}</motion.h3>
        <motion.div {...fade} className="tnf-grid tnf-grid-3" style={{ marginBottom: 'var(--sp3)' }}>
          {v.done.map((d) => (
            <div className="tnf-cell" key={d.v + L(d.l)}>
              <strong style={{ display: 'block', fontSize: 'var(--f1)', fontWeight: 600, marginBottom: '0.3rem' }}>{d.v}</strong>
              <span style={{ ...muted, marginBottom: '0.5rem' }}>{L(d.l)}</span>
              <TagChip tag={d.tag as Tag} />
            </div>
          ))}
        </motion.div>

        <motion.h3 {...fade} className="tnf-h3">{L(v.moatTitle)}</motion.h3>
        <motion.div {...fade} className="tnf-grid tnf-grid-3" style={{ marginBottom: 'var(--sp3)' }}>
          {v.moat.map((m) => (
            <div className="tnf-cell" key={L(m.t)}>
              <strong style={{ display: 'block', fontSize: 'var(--f0)', fontWeight: 600, marginBottom: '0.4rem' }}>{L(m.t)}</strong>
              <span style={{ ...muted, marginBottom: '0.5rem' }}>{L(m.d)}</span>
              <TagChip tag={m.tag as Tag} />
            </div>
          ))}
        </motion.div>

        <motion.h3 {...fade} className="tnf-h3">{L(v.useTitle)}</motion.h3>
        <motion.div {...fade} className="tnf-grid tnf-grid-3" style={{ marginBottom: 'var(--sp3)' }}>
          {v.uses.map((u) => (
            <div className="tnf-cell" key={u.p}>
              <strong style={{ display: 'block', fontSize: 'var(--f2)', fontWeight: 600, marginBottom: '0.2rem' }}>{u.p}</strong>
              <span style={{ display: 'block', fontSize: 'var(--f0)', fontWeight: 500, marginBottom: '0.4rem' }}>{L(u.t)}</span>
              <span style={{ ...muted, marginBottom: '0.5rem' }}>{L(u.d)}</span>
              <TagChip tag="plan" />
            </div>
          ))}
        </motion.div>

        <motion.h3 {...fade} className="tnf-h3">{L(v.milestonesTitle)}</motion.h3>
        <motion.p {...fade} style={{ ...muted, maxWidth: '78ch', textAlign: 'left', marginLeft: 0, marginBottom: 'var(--sp1)' }}>{L(v.milestonesSub)}</motion.p>
        <motion.div {...fade} className="tnf-grid tnf-grid-3" style={{ marginBottom: 'var(--sp3)' }}>
          {v.milestones.map((m) => (
            <div className="tnf-cell" key={L(m.n)}>
              <strong style={{ display: 'block', fontSize: 'var(--f0)', fontWeight: 600, marginBottom: '0.4rem' }}>{L(m.n)}</strong>
              <span style={{ ...muted, marginBottom: '0.5rem' }}>{L(m.g)}</span>
              <TagChip tag="plan" />
            </div>
          ))}
        </motion.div>

        <motion.h3 {...fade} className="tnf-h3">{L(v.riskTitle)}</motion.h3>
        <motion.div {...fade} className="tnf-grid tnf-grid-2" style={{ marginBottom: 'var(--sp3)' }}>
          {v.risks.map((r) => (
            <div className="tnf-cell" key={L(r)}>
              <span style={{ color: 'var(--muted)', fontSize: 'var(--f-1)', lineHeight: 1.7 }}>{L(r)}</span>
            </div>
          ))}
        </motion.div>

        <motion.h3 {...fade} className="tnf-h3">{L(v.takeawayTitle)}</motion.h3>
        <motion.ul {...fade} style={{ listStyle: 'none', padding: 0, margin: '0 0 var(--sp2)', maxWidth: '78ch', textAlign: 'left' }}>
          {v.takeaways.map((t) => (
            <li key={L(t)} style={{ display: 'flex', gap: '0.6rem', color: 'var(--muted)', fontSize: 'var(--f-1)', lineHeight: 1.7, marginBottom: '0.5rem' }}>
              <span style={{ color: 'var(--golden)', flex: '0 0 auto' }}>·</span>
              <span>{L(t)}</span>
            </li>
          ))}
        </motion.ul>

        <motion.p {...fade} style={{ color: 'var(--muted)', fontSize: 'var(--f-2)', lineHeight: 1.7, maxWidth: '78ch', textAlign: 'left', marginLeft: 0, marginBottom: 'var(--sp2)' }}>{L(v.note)}</motion.p>

        <motion.div {...fade} style={{ display: 'flex', flexWrap: 'wrap', gap: '0.7rem', justifyContent: 'center' }}>
          {v.ctas.map((c, i) => (
            <a
              key={L(c.label)}
              href={c.href}
              className="tnf-kbd"
              style={{
                textDecoration: 'none',
                padding: '11px 20px',
                fontSize: 'var(--f-1)',
                color: i === 0 ? '#000' : 'var(--text)',
                background: i === 0 ? 'var(--accent)' : 'transparent',
                borderColor: i === 0 ? 'var(--accent)' : 'var(--border)',
              }}
            >
              {L(c.label)} →
            </a>
          ))}
        </motion.div>

        <motion.div {...fade} style={{ marginTop: 'var(--sp2)', color: 'var(--muted)', fontSize: 'var(--f-2)', textAlign: 'center' }}>
          <a className="tnf-link" href={`mailto:${v.contact}`}>{v.contact}</a>
        </motion.div>
      </div>
    </section>
  )
}

export function TnfReproduce() {
  const { L } = useL()
  return (
    <section id="reproduce" className="tnf-section">
      <div className="tnf-wrap">
        <Head badge={reproduce.badge} title={reproduce.title} lede={reproduce.sub} wide />
        <motion.div {...fade} style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem', marginBottom: '2rem' }}>
          {reproduce.chain.map((c) => <span className="tnf-kbd" key={c}>{c}</span>)}
        </motion.div>
        <motion.div {...fade} className="tnf-grid tnf-grid-3">
          {reproduce.links.map((l) => (
            <a
              className="tnf-cell"
              key={L(l.label)}
              href={l.href}
              {...((l as any).external ? { target: '_blank', rel: 'noopener noreferrer' } : {})}
              style={{ textDecoration: 'none', color: 'inherit', display: 'block' }}
            >
              <strong style={{ fontSize: '0.93rem', fontWeight: 600, display: 'block', marginBottom: '0.4rem' }}>{L(l.label)} →</strong>
              <span style={{ color: 'var(--muted)', fontSize: '0.82rem', lineHeight: 1.55 }}>{L(l.note)}</span>
            </a>
          ))}
        </motion.div>
        <motion.div {...fade} style={{ marginTop: '2rem', color: 'var(--muted)', fontSize: '0.85rem' }}>
          {PAPER.author} · ORCID {PAPER.orcid} ·{' '}
          <a className="tnf-link" href={`mailto:${reproduce.contact}`}>{reproduce.contact}</a>
        </motion.div>
      </div>
    </section>
  )
}
