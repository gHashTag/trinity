// The PASSPORT's figures.
//
// Every figure here is inline SVG drawn from src/content/passport.ts,
// src/content/passportExamples.ts and src/content/passportRecords.ts — the same
// objects the prose renders from. No figure carries a number of its own: if a
// quantity appears in a drawing it was read out of a content module that names
// where it came from, and the frame prints that source line under every caption.
// A document arguing that a result must travel with its provenance cannot ship a
// chart whose provenance is the chart.
//
// Status is encoded by SHAPE as well as colour — the house rule in
// lib/explorerTheme, where HEALTH_GLYPH gives every state a glyph so colour is
// never the only carrier. Here the states are degrees of disclosure rather than
// health, so the shapes are degrees of fill (● ◐ ○) instead of ✓ ⚠ ✕: the
// coverage matrix has to survive a colour-blind reader and a greyscale print,
// and 98 ticks of one hue would defeat both.

import type { ReactNode } from 'react'
import { C } from '../lib/explorerTheme'
import { meta, record, standing, type Bi } from '../content/passport'
import { axes, plotted, area } from '../content/passportExamples'
import { systems, coverage, tally, blindSpots, type Cell } from '../content/passportRecords'

const UI = {
  en: { figure: 'Figure', source: 'Data source' },
  ru: { figure: 'Рисунок', source: 'Источник данных' },
}

/** The page is gold; explorerTheme's green would read as a second, unrelated signal. */
const GOLD = '#d4af37'
const INK = 'rgba(255,255,255,0.86)'
const DIM = 'rgba(255,255,255,0.46)'
const FAINT = 'rgba(255,255,255,0.28)'
const GRID = 'rgba(255,255,255,0.13)'

type Lang = 'en' | 'ru'
const pick = (v: Bi, lang: Lang) => v[lang] ?? v.en

/** The band FigureStamp occupies at the foot of every plate, in viewBox units. */
const STAMP_H = 46

/**
 * A plate leaves the page. It is dragged into a slide, screenshotted into a
 * thread, pasted into a review — and the caption under it does not come along.
 * Stripped of its caption, figure 4 reads as a survey of the field and figure 2
 * as a hardware result, and neither is what it is. So the two facts that change
 * the meaning of every drawing here — that this is a proposal nobody has agreed
 * to, and that the cases are not neuromorphic — are burned into the SVG, where
 * they travel with the pixels.
 *
 * Both are interpolated from content/passport.ts and neither is retyped: if the
 * standing of the document changes, the plates say so without being redrawn.
 */
function FigureStamp({ lang, y }: { lang: Lang; y: number }) {
  return (
    <g>
      <line x1={8} y1={y + 12} x2={692} y2={y + 12} stroke={GRID} strokeWidth={1} />
      <text x={8} y={y + 28} fontSize="9.5" fill={GOLD} opacity={0.7} fontFamily={C.mono}>
        {pick(meta.status, lang)}
      </text>
      <text x={8} y={y + 41} fontSize="9.5" fill={DIM} fontFamily={C.mono}>
        {pick(standing[0].h, lang)} · {meta.submitted}
      </text>
    </g>
  )
}

/** The frame every passport figure sits in: number, caption, and the line that says where the numbers came from. */
export function PassportFigure({
  n,
  caption,
  source,
  lang,
  children,
}: {
  n: number
  caption: string
  source: string
  lang: string
  children: ReactNode
}) {
  const ui = UI[lang === 'ru' ? 'ru' : 'en']
  return (
    <figure className="pp-fig">
      <div className="pp-fig-plate">{children}</div>
      <figcaption className="pp-fig-cap">
        <b>
          {ui.figure} {n}.
        </b>{' '}
        {caption}
        <span className="pp-fig-src" style={{ fontFamily: C.mono }}>
          {ui.source}: {source}
        </span>
      </figcaption>
    </figure>
  )
}

const F1 = {
  en: {
    cap: 'The two axes a reader collapses into one. The dashed diagonal is the assumption — that a gap in the metric tracks a gap in the artifact. Both measured cases sit off it, in opposite corners.',
    src: 'content/passportExamples.ts, plotting cases 1 and 2 of content/passport.ts',
    assumed: 'what the reader assumes',
    thresh: '2 SE — conventionally read as a real difference',
    identical: 'identical to the byte',
  },
  ru: {
    cap: 'Две оси, которые читатель схлопывает в одну. Пунктирная диагональ — это допущение: будто разрыв в метрике идёт вслед за разрывом в артефакте. Оба измеренных случая лежат в стороне от неё, в противоположных углах.',
    src: 'content/passportExamples.ts, по случаям 1 и 2 из content/passport.ts',
    assumed: 'то, что предполагает читатель',
    thresh: '2 СО — обычно читается как настоящее различие',
    identical: 'совпадают побайтово',
  },
}

/** Figure 1: metric separation against artifact separation, for the two cases that were measured both ways. */
export function FigureSeparation({ lang }: { lang: Lang }) {
  const t = F1[lang]
  const X0 = 96, X1 = 660, Y0 = 44, Y1 = 318
  // The box is taller than the plot: the axis title sits at Y1+40 and the two
  // glosses below it need a band of their own, or they land on the same line.
  const H = 424
  const px = (v: number) => X0 + (v / axes.metric.max) * (X1 - X0)
  const py = (v: number) => Y1 - (v / axes.artifact.max) * (Y1 - Y0)

  return (
    <PassportFigure n={1} lang={lang} caption={t.cap} source={t.src}>
      <svg viewBox={`0 0 700 ${H + STAMP_H}`} role="img" xmlns="http://www.w3.org/2000/svg">
        <title>{t.cap}</title>

        {/* Gridlines every standard error, so 4.44 and 0.084 are countable and not just placed. */}
        {[0, 1, 2, 3, 4, 5].map((v) => (
          <line key={`gx${v}`} x1={px(v)} y1={Y0} x2={px(v)} y2={Y1} stroke={GRID} strokeWidth={1} />
        ))}
        {[0, 10, 20, 30, 40, 50].map((v) => (
          <line key={`gy${v}`} x1={X0} y1={py(v)} x2={X1} y2={py(v)} stroke={GRID} strokeWidth={1} />
        ))}

        <line x1={X0} y1={Y1} x2={X1} y2={Y1} stroke={FAINT} strokeWidth={1.4} />
        <line x1={X0} y1={Y0} x2={X0} y2={Y1} stroke={FAINT} strokeWidth={1.4} />

        {/* The assumption, drawn so the reader can see what the data does not do. */}
        <line x1={X0} y1={Y1} x2={X1} y2={Y0} stroke={DIM} strokeWidth={1.3} strokeDasharray="7 6" />
        <text x={X1 - 8} y={Y0 + 30} textAnchor="end" fontSize="11.5" fill={DIM} fontStyle="italic">
          {t.assumed}
        </text>

        {/* The threshold the separation in case 1 clears twice over, and case 2 does not approach. */}
        <line x1={px(2)} y1={Y0} x2={px(2)} y2={Y1} stroke={GOLD} strokeWidth={1} strokeDasharray="3 5" opacity={0.5} />
        <text x={px(2) + 7} y={Y0 + 14} fontSize="10.5" fill={GOLD} opacity={0.72}>
          {t.thresh}
        </text>

        {[0, 1, 2, 3, 4, 5].map((v) => (
          <text key={`lx${v}`} x={px(v)} y={Y1 + 18} textAnchor="middle" fontSize="11" fill={DIM} fontFamily={C.mono}>
            {v}
          </text>
        ))}
        {[0, 10, 20, 30, 40, 50].map((v) => (
          <text key={`ly${v}`} x={X0 - 9} y={py(v) + 4} textAnchor="end" fontSize="11" fill={DIM} fontFamily={C.mono}>
            {v}%
          </text>
        ))}

        <text x={(X0 + X1) / 2} y={Y1 + 40} textAnchor="middle" fontSize="12" fill={INK}>
          {pick(axes.metric.label, lang)}
        </text>
        <text x={18} y={(Y0 + Y1) / 2} textAnchor="middle" fontSize="12" fill={INK} transform={`rotate(-90 18 ${(Y0 + Y1) / 2})`}>
          {pick(axes.artifact.label, lang)}
        </text>

        {plotted.map((p) => {
          const cx = px(p.metricSE.value)
          const cy = py(p.artifactPct.value)
          // Case 1 sits on the floor of the plot; its label has to go up, not down.
          const up = p.artifactPct.value < axes.artifact.max / 2
          return (
            <g key={p.case}>
              <line x1={cx} y1={cy} x2={cx} y2={Y1} stroke={GOLD} strokeWidth={1} opacity={0.3} />
              <line x1={X0} y1={cy} x2={cx} y2={cy} stroke={GOLD} strokeWidth={1} opacity={0.3} />
              <circle cx={cx} cy={cy} r={8} fill={GOLD} />
              <circle cx={cx} cy={cy} r={15} fill="none" stroke={GOLD} strokeWidth={1} opacity={0.4} />
              <text
                x={cx + (p.metricSE.value > axes.metric.max / 2 ? -22 : 22)}
                y={cy + (up ? -30 : 6)}
                textAnchor={p.metricSE.value > axes.metric.max / 2 ? 'end' : 'start'}
                fontSize="12.5"
                fill={GOLD}
                fontWeight={600}
              >
                {pick(p.kind, lang)}
              </text>
              <text
                x={cx + (p.metricSE.value > axes.metric.max / 2 ? -22 : 22)}
                y={cy + (up ? -14 : 22)}
                textAnchor={p.metricSE.value > axes.metric.max / 2 ? 'end' : 'start'}
                fontSize="11"
                fill={INK}
                fontFamily={C.mono}
              >
                {p.metricSE.print} · {p.artifactPct.value === 0 ? t.identical : `${lang === 'ru' ? (p.artifactPct.printRu ?? p.artifactPct.print) : p.artifactPct.print}%`}
              </text>
            </g>
          )
        })}

        {plotted.map((p, i) => (
          <text key={`g${p.case}`} x={X0} y={386 + i * 19} fontSize="11.5" fill={DIM}>
            <tspan fill={GOLD} fontFamily={C.mono}>{p.case}. </tspan>
            {pick(p.gloss, lang)}
          </text>
        ))}

        <FigureStamp lang={lang} y={H} />
      </svg>
    </PassportFigure>
  )
}

const F2 = {
  en: {
    cap: 'One function, one part, one toolchain, two implementations. The DSP48 column is drawn behind a fence on purpose: it is additional to the LUT count and not commensurable with it, so stacking the two into a single bar would assert a comparison the numbers do not support.',
    src: 'content/passportExamples.ts, plotting case 3 of content/passport.ts — post-route utilization, not silicon',
    ratio: 'LUT ratio',
    lutAxis: 'LUTs, post-route',
    fence: 'not commensurable',
  },
  ru: {
    cap: 'Одна функция, одна микросхема, один тулчейн, две реализации. Колонка DSP48 нарисована за оградой намеренно: она добавочна к счёту LUT и с ним несоизмерима, так что сложить их в один столбик значило бы утверждать сравнение, которого числа не выдерживают.',
    src: 'content/passportExamples.ts, по случаю 3 из content/passport.ts — post-route утилизация, не кремний',
    ratio: 'отношение по LUT',
    lutAxis: 'LUT, post-route',
    fence: 'несоизмеримо',
  },
}

/** Figure 2: the 5.4× that was a representation, not an algorithm. */
export function FigureArea({ lang }: { lang: Lang }) {
  const t = F2[lang]
  const BASE = 300, TOP = 60, BARH = BASE - TOP
  // The caveat under the DSP48 column runs to BASE+100; the plot ends where it does.
  const H = 400
  const bars = [
    { q: area.lut.a, impl: area.implementations[0], dsp: area.dsp.a, x: 150 },
    { q: area.lut.b, impl: area.implementations[1], dsp: area.dsp.b, x: 300 },
  ]
  const hOf = (v: number) => (v / area.lut.a.value) * BARH
  const num = (q: { print: string; printRu?: string }) => (lang === 'ru' ? (q.printRu ?? q.print) : q.print)

  return (
    <PassportFigure n={2} lang={lang} caption={t.cap} source={t.src}>
      <svg viewBox={`0 0 700 ${H + STAMP_H}`} role="img" xmlns="http://www.w3.org/2000/svg">
        <title>{t.cap}</title>

        <text x={40} y={34} fontSize="12" fill={INK}>{pick(area.lut.label, lang)}</text>
        <text x={40} y={52} fontSize="11" fill={DIM} fontFamily={C.mono}>{area.target}</text>
        <line x1={40} y1={BASE} x2={420} y2={BASE} stroke={FAINT} strokeWidth={1.4} />

        {bars.map((b, i) => (
          <g key={i}>
            <rect x={b.x} y={BASE - hOf(b.q.value)} width={72} height={hOf(b.q.value)} fill={GOLD} opacity={i === 0 ? 0.9 : 0.55} rx={2} />
            <text x={b.x + 36} y={BASE - hOf(b.q.value) - 10} textAnchor="middle" fontSize="15" fill={GOLD} fontFamily={C.mono} fontWeight={600}>
              {num(b.q)}
            </text>
            <text x={b.x + 36} y={BASE + 20} textAnchor="middle" fontSize="11.5" fill={DIM} fontFamily={C.mono}>
              {lang === 'ru' ? `реализация ${i + 1}` : `implementation ${i + 1}`}
            </text>
            <foreignObject x={b.x - 30} y={BASE + 30} width={132} height={70}>
              <div style={{ fontSize: '10.5px', lineHeight: 1.45, color: INK, textAlign: 'center' }}>
                {pick(b.impl, lang)}
              </div>
            </foreignObject>
          </g>
        ))}

        {/* The ratio, spanning the two bar tops so it reads as a relation and not a third quantity. */}
        <line x1={186} y1={BASE - hOf(area.lut.a.value) - 34} x2={336} y2={BASE - hOf(area.lut.a.value) - 34} stroke={GOLD} strokeWidth={1} opacity={0.45} />
        <line x1={186} y1={BASE - hOf(area.lut.a.value) - 34} x2={186} y2={BASE - hOf(area.lut.a.value) - 26} stroke={GOLD} strokeWidth={1} opacity={0.45} />
        <line x1={336} y1={BASE - hOf(area.lut.a.value) - 34} x2={336} y2={BASE - hOf(area.lut.b.value) - 26} stroke={GOLD} strokeWidth={1} opacity={0.45} />
        <text x={261} y={BASE - hOf(area.lut.a.value) - 42} textAnchor="middle" fontSize="13" fill={GOLD} fontFamily={C.mono}>
          {num(area.lut.ratio)}× {t.ratio}
        </text>

        {/* The fence. Everything right of it is a different unit. */}
        <line x1={455} y1={30} x2={455} y2={370} stroke={FAINT} strokeWidth={1.2} strokeDasharray="5 6" />
        <text x={465} y={34} fontSize="10.5" fill={DIM} fontStyle="italic">{t.fence}</text>

        <text x={500} y={62} fontSize="12" fill={INK}>{pick(area.dsp.label, lang)}</text>
        <line x1={500} y1={BASE} x2={660} y2={BASE} stroke={FAINT} strokeWidth={1.4} />
        {bars.map((b, i) => {
          const dspH = b.dsp.value === 0 ? 0 : 66
          return (
            <g key={`d${i}`}>
              {dspH > 0 ? (
                <rect x={510 + i * 80} y={BASE - dspH} width={56} height={dspH} fill="none" stroke={GOLD} strokeWidth={1.4} opacity={0.75} rx={2} />
              ) : (
                <line x1={510 + i * 80} y1={BASE} x2={566 + i * 80} y2={BASE} stroke={GOLD} strokeWidth={2.5} opacity={0.75} />
              )}
              <text x={538 + i * 80} y={BASE - dspH - 10} textAnchor="middle" fontSize="13" fill={GOLD} fontFamily={C.mono}>
                {num(b.dsp)}
              </text>
              <text x={538 + i * 80} y={BASE + 20} textAnchor="middle" fontSize="11.5" fill={DIM} fontFamily={C.mono}>
                {i + 1}
              </text>
            </g>
          )
        })}
        <foreignObject x={490} y={BASE + 30} width={180} height={70}>
          <div style={{ fontSize: '10.5px', lineHeight: 1.45, color: DIM }}>{pick(area.dsp.caveat, lang)}</div>
        </foreignObject>

        <FigureStamp lang={lang} y={H} />
      </svg>
    </PassportFigure>
  )
}

const F3 = {
  en: {
    cap: 'What each row of the table above rests on, in the table’s own order. Five fields are paid for by a case that still stands; one is anchored only to the vector-set count this document withdrew, and is counted apart rather than quietly with the rest; the remaining eight follow from the argument and are not backed here by any measurement.',
    src: 'content/passport.ts — read off record[].anchoredTo, the same array the † marks render from',
    legend: { m: 'rests on a surviving case', w: 'rests only on a withdrawn one', a: 'argument only, unmeasured' },
  },
  ru: {
    cap: 'На чём стоит каждая строка таблицы выше, в её же порядке. Пять полей оплачены случаем, который ещё держится; одно опирается только на число векторов, отозванное этим же документом, и считается отдельно, а не тихо вместе со всеми; оставшиеся восемь следуют из рассуждения и здесь ничем не измерены.',
    src: 'content/passport.ts — читается из record[].anchoredTo, того же массива, из которого рисуются пометки †',
    legend: { m: 'стоит на уцелевшем случае', w: 'стоит только на отозванном', a: 'только рассуждение, не измерено' },
  },
}

/** Figure 3: the table's own footing, one strip per field, in the table's order. */
export function FigureFooting({ lang }: { lang: Lang }) {
  const t = F3[lang]
  const kindOf = (a: readonly string[]) =>
    a.length === 0 ? 'a' : a.every((x) => x === 'withdrawn') ? 'w' : 'm'
  const rows = record.map((r) => ({ field: pick(r.field, lang), kind: kindOf(r.anchoredTo), refs: r.anchoredTo }))
  const Y0 = 58, PITCH = 25
  const H = Y0 + rows.length * PITCH + 52

  return (
    <PassportFigure n={3} lang={lang} caption={t.cap} source={t.src}>
      <svg viewBox={`0 0 700 ${H + STAMP_H}`} role="img" xmlns="http://www.w3.org/2000/svg">
        <title>{t.cap}</title>

        {(['m', 'w', 'a'] as const).map((k, i) => (
          <g key={k} transform={`translate(${16 + i * 224} 22)`}>
            <rect x={0} y={-9} width={12} height={12} rx={2}
              fill={k === 'm' ? GOLD : 'none'}
              stroke={k === 'a' ? GRID : GOLD}
              strokeWidth={1.3}
              strokeDasharray={k === 'w' ? '3 2' : undefined}
              opacity={k === 'a' ? 1 : 0.9} />
            <text x={20} y={1} fontSize="11" fill={DIM}>{t.legend[k]}</text>
          </g>
        ))}

        {rows.map((r, i) => {
          const y = Y0 + i * PITCH
          return (
            <g key={r.field}>
              <text x={16} y={y + 4} fontSize="11" fill={DIM} fontFamily={C.mono}>{String(i + 1).padStart(2, '0')}</text>
              <text x={42} y={y + 4} fontSize="11.5" fill={r.kind === 'a' ? DIM : INK}>{r.field}</text>
              <rect x={330} y={y - 8} width={r.kind === 'a' ? 60 : r.kind === 'w' ? 150 : 250} height={12} rx={2}
                fill={r.kind === 'm' ? GOLD : 'none'}
                stroke={r.kind === 'a' ? GRID : GOLD}
                strokeWidth={1.3}
                strokeDasharray={r.kind === 'w' ? '3 2' : undefined}
                opacity={r.kind === 'm' ? 0.85 : 1} />
              {r.refs.length > 0 && (
                <text x={r.kind === 'w' ? 488 : 588} y={y + 4} fontSize="10.5" fill={r.kind === 'w' ? DIM : GOLD} fontFamily={C.mono}>
                  {r.kind === 'w' ? (lang === 'ru' ? 'отозван' : 'withdrawn') : `${lang === 'ru' ? 'случай' : 'case'} ${r.refs.join(', ')}`}
                </text>
              )}
            </g>
          )
        })}

        <FigureStamp lang={lang} y={H} />
      </svg>
    </PassportFigure>
  )
}

const F4 = {
  en: {
    cap: 'The test the document had not had, run against seven results other people published. Fourteen fields by seven records is 98 cells; none was left unchecked, and each was read from a primary source and then re-read by a second reader instructed to find a wrong verdict. Four rows — banded — are empty or near-empty across every column including the control. That is the finding, and it is narrower than it first reads: the control is one body, and a later sweep found a requirement for all four of those rows outside it.',
    src: 'content/passportRecords.ts — one primary source per column, listed beneath the page',
    control: 'control',
    legend: { stated: 'stated', partial: 'partial', absent: 'absent' },
    absentRow: 'absent',
    of: 'of 98 cells',
  },
  ru: {
    cap: 'Проверка, которой документ не проходил, — проведена на семи результатах, опубликованных другими. Четырнадцать полей на семь записей — это 98 клеток; ни одна не осталась непроверенной, каждая прочитана по первоисточнику и затем перечитана вторым читателем, которому велели найти неверный вердикт. Четыре строки — с подложкой — пусты или почти пусты во всех колонках, включая контрольную. В этом и находка, но она уже, чем кажется: контроль — это одна организация, а более поздний обход нашёл требование по всем четырём строкам за её пределами.',
    src: 'content/passportRecords.ts — по одному первоисточнику на колонку, перечислены под страницей',
    control: 'контроль',
    legend: { stated: 'раскрыто', partial: 'частично', absent: 'отсутствует' },
    absentRow: 'нет',
    of: 'из 98 клеток',
  },
}

/** One cell: fill is the quantity, shape carries it too so greyscale and colour-blind readers keep the signal. */
function CoverageCell({ x, y, kind }: { x: number; y: number; kind: Cell }) {
  const r = 7
  if (kind === 'stated') return <circle cx={x} cy={y} r={r} fill={GOLD} />
  if (kind === 'absent') return <circle cx={x} cy={y} r={r} fill="none" stroke={GRID} strokeWidth={1.2} />
  return (
    <g>
      <circle cx={x} cy={y} r={r} fill="none" stroke={GOLD} strokeWidth={1.3} opacity={0.8} />
      <path d={`M ${x} ${y - r} A ${r} ${r} 0 0 0 ${x} ${y + r} Z`} fill={GOLD} opacity={0.55} />
    </g>
  )
}

/** Figure 4: fourteen fields against seven published results, the control set apart. */
export function FigureCoverage({ lang }: { lang: Lang }) {
  const t = F4[lang]
  const LX = 296, CX0 = 316, PITCH = 40, GAP = 30
  const Y0 = 128, RP = 26
  const research = systems.filter((s) => !s.control)
  const cx = (i: number) => (i < research.length ? CX0 + i * PITCH : CX0 + research.length * PITCH + GAP + (i - research.length) * PITCH)
  const lastY = Y0 + (coverage.length - 1) * RP
  const totalsY = lastY + 36
  const barY = totalsY + 42
  const H = barY + 46
  const seg = (n: number) => (n / tally.cells) * (660 - 40)

  return (
    <PassportFigure n={4} lang={lang} caption={t.cap} source={t.src}>
      <svg viewBox={`0 0 700 ${H + STAMP_H}`} role="img" xmlns="http://www.w3.org/2000/svg">
        <title>{t.cap}</title>

        {(['stated', 'partial', 'absent'] as const).map((k, i) => (
          <g key={k} transform={`translate(${16 + i * 130} 20)`}>
            <CoverageCell x={7} y={-3} kind={k} />
            <text x={22} y={1} fontSize="11" fill={DIM}>{t.legend[k]}</text>
          </g>
        ))}

        {/* The four rows that are blank everywhere, banded so the shape reads before the cells do. */}
        {blindSpots.map((i) => (
          <rect key={`b${i}`} x={8} y={Y0 + i * RP - 12} width={684} height={24} fill={GOLD} opacity={0.055} rx={3} />
        ))}

        {systems.map((s, i) => (
          <text
            key={s.label}
            x={cx(i)}
            y={116}
            fontSize="11"
            fill={s.control ? GOLD : INK}
            fontFamily={C.mono}
            transform={`rotate(-52 ${cx(i)} 116)`}
          >
            {s.label}
            {s.control ? ` (${t.control})` : ''}
          </text>
        ))}

        {/* The control is a different kind of thing; the rule says so before the caption does. */}
        <line
          x1={CX0 + research.length * PITCH + GAP / 2 - PITCH / 2}
          y1={62}
          x2={CX0 + research.length * PITCH + GAP / 2 - PITCH / 2}
          y2={totalsY + 8}
          stroke={FAINT}
          strokeWidth={1}
          strokeDasharray="4 5"
        />

        {coverage.map((row, ri) => (
          <g key={record[ri].field.en}>
            <text x={16} y={Y0 + ri * RP + 4} fontSize="10.5" fill={DIM} fontFamily={C.mono}>{String(ri + 1).padStart(2, '0')}</text>
            <text x={LX} y={Y0 + ri * RP + 4} textAnchor="end" fontSize="11" fill={blindSpots.includes(ri) ? GOLD : INK}>
              {pick(record[ri].field, lang)}
            </text>
            {row.map((c, ci) => (
              <CoverageCell key={ci} x={cx(ci)} y={Y0 + ri * RP} kind={c} />
            ))}
          </g>
        ))}

        <line x1={8} y1={totalsY - 18} x2={692} y2={totalsY - 18} stroke={GRID} strokeWidth={1} />
        <text x={LX} y={totalsY + 4} textAnchor="end" fontSize="11" fill={DIM}>{t.absentRow}</text>
        {systems.map((s, i) => {
          const n = coverage.filter((row) => row[i] === 'absent').length
          return (
            <text key={`t${s.label}`} x={cx(i)} y={totalsY + 5} textAnchor="middle" fontSize="13" fill={n === 0 ? GOLD : INK} fontFamily={C.mono}>
              {n}
            </text>
          )
        })}

        {/* The tally, as one bar, because 5 / 65 / 28 is the whole answer to the question that was asked. */}
        <rect x={40} y={barY} width={seg(tally.stated)} height={18} fill={GOLD} rx={2} />
        <rect x={40 + seg(tally.stated)} y={barY} width={seg(tally.partial)} height={18} fill={GOLD} opacity={0.4} />
        <rect x={40 + seg(tally.stated) + seg(tally.partial)} y={barY} width={seg(tally.absent)} height={18} fill="none" stroke={GRID} strokeWidth={1.2} />
        <text x={40} y={barY + 36} fontSize="11.5" fill={DIM} fontFamily={C.mono}>
          <tspan fill={GOLD}>{tally.stated} {t.legend.stated}</tspan>
          {'  ·  '}
          {tally.partial} {t.legend.partial}
          {'  ·  '}
          {tally.absent} {t.legend.absent}
          {'  ·  '}
          {t.of}
        </text>

        <FigureStamp lang={lang} y={H} />
      </svg>
    </PassportFigure>
  )
}
