/* Two drawings, and both of them are the paper rather than an illustration of it.
 *
 * The first is arXiv:2606.05017 — the field rule. It has no measurement in it at
 * all: you move the width and the split moves, because the split is a closed
 * form. Tag: выведено.
 *
 * The second is arXiv:2606.09686 — the catalogue put on the plane it is actually
 * judged on, area against frequency, with the numbers taken from the same table
 * the page already prints in the frontier section. No number is introduced here
 * that is not already on the page. Tag: измерено.
 *
 * Neither drawing invents a format name, and neither one claims an axis the
 * hardware has not closed.
 */
import { useMemo, useState } from 'react'
import { motion } from 'framer-motion'
import { useI18n } from '../../../i18n/context'
import { frontier, TAG_LABEL, type Tag } from '../../../content/tnf'

const PHI = 1.618033988749895
const PHI2 = PHI * PHI

function useL() {
  const { lang } = useI18n()
  return (lang === 'ru' ? 'ru' : 'en') as 'ru' | 'en'
}

function Tagged({ tag }: { tag: Tag }) {
  const key = useL()
  const t = TAG_LABEL[tag]
  return <span className="tnf-tag" style={{ color: t.color }}>{t[key]}</span>
}

/* ─────────────── 1. THE FIELD RULE, MOVING ─────────────── */

// e = round((N−1)/φ²), m = N−1−e, bias = 2^(e−1)−1.
// The whole of GoldenFloat's layout is this line. Drawing it as a strip of bits
// makes the one honest claim visible — φ picks where the boundary falls, and
// picks nothing else. The arithmetic downstream of the boundary is ordinary.
function fields(n: number) {
  const e = Math.round((n - 1) / PHI2)
  const m = n - 1 - e
  const bias = e >= 1 ? Math.pow(2, e - 1) - 1 : 0
  return { e, m, bias }
}

const NAMED: Record<number, string> = { 8: 'GF8', 16: 'GF16', 32: 'GF32' }

function FieldRule() {
  const key = useL()
  const [n, setN] = useState(16)
  const { e, m, bias } = fields(n)

  const curve = useMemo(() => {
    const pts: { n: number; exact: number; e: number }[] = []
    for (let i = 4; i <= 64; i++) pts.push({ n: i, exact: (i - 1) / PHI2, e: fields(i).e })
    return pts
  }, [])

  // chart box
  const W = 620, H = 236, pad = { l: 34, r: 12, t: 30, b: 26 }
  const x = (v: number) => pad.l + ((v - 4) / 60) * (W - pad.l - pad.r)
  const y = (v: number) => H - pad.b - (v / 25) * (H - pad.t - pad.b)

  const t = {
    ru: {
      h: 'Правило полей — подвиньте ширину',
      lede: 'Вся раскладка GoldenFloat — одна строка: e = round((N−1)/φ²), m = N−1−e, bias = 2^(e−1)−1. Здесь нет измерения: подвиньте N, и граница переедет сама. Это и есть ровно то, что делает φ на этом сайте — выбирает, где стоит граница полей, и больше ничего. Арифметика ниже границы обычная.',
      width: 'Ширина N, бит',
      sign: 'знак',
      exp: 'экспонента e',
      man: 'мантисса m',
      curve: 'e(N) — ступени округления против прямой (N−1)/φ²',
      exact: '(N−1)/φ², непрерывно',
      steps: 'e = round(...), целые биты',
      note: 'Контроль, который здесь важнее любой красивой картинки: GF16 с полями 6e/9m бит-в-бит совпадает с обычным float тех же полей — максимальная разница 0,0. φ — правило выбора полей, а не другая арифметика.',
    },
    en: {
      h: 'The field rule — move the width',
      lede: 'The whole of GoldenFloat\u2019s layout is one line: e = round((N−1)/φ²), m = N−1−e, bias = 2^(e−1)−1. Nothing here is measured: move N and the boundary moves with it. That is exactly what φ does on this site — it chooses where the field boundary falls, and nothing else. The arithmetic below the boundary is ordinary.',
      width: 'Width N, bits',
      sign: 'sign',
      exp: 'exponent e',
      man: 'mantissa m',
      curve: 'e(N) — the rounding steps against the line (N−1)/φ²',
      exact: '(N−1)/φ², continuous',
      steps: 'e = round(...), whole bits',
      note: 'The control that matters more here than any picture: GF16 with 6e/9m fields is bit-for-bit identical to an ordinary float of the same fields — maximum difference 0.0. φ is a field-selection rule, not a different arithmetic.',
    },
  }[key]

  return (
    <div className="tnf-cell" style={{ border: '1px solid var(--border)' }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 'var(--sp0)', flexWrap: 'wrap' }}>
        <h3 style={{ margin: 0, fontSize: 'var(--f1)', fontWeight: 500 }}>{t.h}</h3>
        <Tagged tag="derived" />
      </div>
      <p style={{ color: 'var(--muted)', fontSize: 'var(--f-1)', lineHeight: PHI, margin: 'var(--sp0) 0 var(--sp2)', maxWidth: '72ch' }}>
        {t.lede}
      </p>

      <label style={{ display: 'block', fontSize: 'var(--f-1)', color: 'var(--muted)', marginBottom: 'var(--sp0)' }}>
        {t.width}: <strong style={{ color: 'var(--text)' }}>{n}</strong>
        {NAMED[n] ? <span style={{ color: 'var(--accent)' }}> · {NAMED[n]}</span> : null}
      </label>
      <input
        type="range" min={4} max={64} step={1} value={n}
        onChange={(ev) => setN(Number(ev.target.value))}
        aria-label={t.width}
        style={{ width: '100%', maxWidth: 420, accentColor: 'var(--accent)', marginBottom: 'var(--sp2)' }}
      />

      {/* bit strip */}
      <div style={{ display: 'flex', gap: 2, height: 38, marginBottom: 'var(--sp0)' }}>
        <div style={{ flex: '0 0 auto', width: `${100 / n}%`, minWidth: 8, background: 'rgba(255,255,255,0.5)', borderRadius: 1 }} title={t.sign} />
        <div style={{ display: 'flex', gap: 2, flex: `${e} 0 0` }}>
          {Array.from({ length: e }).map((_, i) => (
            <div key={i} style={{ flex: 1, minWidth: 3, background: 'var(--accent)', opacity: 0.85, borderRadius: 1 }} />
          ))}
        </div>
        <div style={{ display: 'flex', gap: 2, flex: `${m} 0 0` }}>
          {Array.from({ length: m }).map((_, i) => (
            <div key={i} style={{ flex: 1, minWidth: 3, background: 'var(--golden)', opacity: 0.55, borderRadius: 1 }} />
          ))}
        </div>
      </div>
      <div style={{ display: 'flex', gap: 'var(--sp2)', flexWrap: 'wrap', fontSize: 'var(--f-2)', color: 'var(--muted)', letterSpacing: '0.06em', marginBottom: 'var(--sp3)' }}>
        <span>1 · {t.sign}</span>
        <span style={{ color: 'var(--accent)' }}>{e} · {t.exp}</span>
        <span style={{ color: 'var(--golden)' }}>{m} · {t.man}</span>
        <span>bias = {bias}</span>
      </div>

      {/* e(N) */}
      <div style={{ fontSize: 'var(--f-2)', color: 'var(--muted)', letterSpacing: '0.06em', marginBottom: 'var(--sp0)' }}>{t.curve}</div>
      <svg viewBox={`0 0 ${W} ${H}`} width="100%" role="img" aria-label={t.curve} style={{ display: 'block', overflow: 'visible' }}>
        {[0, 5, 10, 15, 20, 25].map((g) => (
          <g key={g}>
            <line x1={pad.l} x2={W - pad.r} y1={y(g)} y2={y(g)} stroke="rgba(255,255,255,0.07)" />
            <text x={pad.l - 6} y={y(g) + 3} fill="var(--muted)" fontSize="11" textAnchor="end">{g}</text>
          </g>
        ))}
        {[8, 16, 32, 64].map((g) => (
          <g key={g}>
            <line x1={x(g)} x2={x(g)} y1={pad.t} y2={H - pad.b} stroke="rgba(255,255,255,0.07)" />
            <text x={x(g)} y={H - pad.b + 13} fill="var(--muted)" fontSize="11" textAnchor="middle">{g}</text>
          </g>
        ))}
        <path
          d={curve.map((p, i) => `${i ? 'L' : 'M'}${x(p.n)},${y(p.exact)}`).join('')}
          fill="none" stroke="var(--golden)" strokeWidth="1" strokeDasharray="3 3" opacity="0.8"
        />
        <path
          d={curve.map((p, i) => `${i ? 'L' : 'M'}${x(p.n)},${y(p.e)}`).join('')}
          fill="none" stroke="var(--accent)" strokeWidth="1.4" strokeLinejoin="round"
        />
        <line x1={x(n)} x2={x(n)} y1={pad.t} y2={H - pad.b} stroke="rgba(255,255,255,0.35)" />
        <circle cx={x(n)} cy={y(e)} r="4.5" fill="var(--accent)" />
        {/* Значение стояло подписью у самой точки и ложилось прямо на кривую —
            читать было нельзя. Оно вынесено в постоянный угол над полем: место
            не меняется, наезжать не на что. */}
        <g transform={`translate(${pad.l + 2}, 4)`}>
          <rect x="0" y="0" width="136" height="20" rx="4" fill="rgba(0,0,0,0.72)" stroke="var(--border)" />
          <text x="8" y="14" fill="var(--text)" fontSize="12" fontWeight="500">
            N = {n} · e = {e} · m = {m}
          </text>
        </g>
      </svg>
      <div style={{ display: 'flex', gap: 'var(--sp2)', flexWrap: 'wrap', fontSize: 'var(--f-2)', color: 'var(--muted)', marginTop: 'var(--sp0)' }}>
        <span style={{ color: 'var(--accent)' }}>— {t.steps}</span>
        <span style={{ color: 'var(--golden)' }}>-- {t.exact}</span>
      </div>

      <p style={{ color: 'var(--muted)', fontSize: 'var(--f-2)', lineHeight: PHI, margin: 'var(--sp2) 0 0', maxWidth: '72ch' }}>
        {t.note}
      </p>
    </div>
  )
}

/* ─────────────── 2. THE PLANE THE CATALOGUE IS JUDGED ON ─────────────── */

// Area against frequency, isolated decoder, one device family. Every point is a
// row of the table this page already prints; the drawing adds no number. The
// bare wire — 112 LUT at 827.81 MHz — is drawn as the pair of dashed lines,
// because it is the only reference on the plane that is not a format.
const NUDGE: Record<string, { dx: number; dy: number }> = {
  TNF16: { dx: 4, dy: -8 },
  BNF16: { dx: 4, dy: 12 },
}

function CostPlane() {
  const key = useL()
  const [hover, setHover] = useState<string | null>(null)

  const pts = frontier.decoder
  // t раздвинут: подпись оси иначе садится на верхнюю риску 1000.
  const W = 640, H = 348, pad = { l: 46, r: 16, t: 34, b: 34 }
  const maxLut = 560, maxF = 1020
  const x = (v: number) => pad.l + (v / maxLut) * (W - pad.l - pad.r)
  const y = (v: number) => H - pad.b - (v / maxF) * (H - pad.t - pad.b)

  const t = {
    ru: {
      h: 'Плоскость, на которой каталог и судят',
      lede: 'Изолированный декодер: площадь по горизонтали, частота по вертикали, ниже и правее — хуже. Каждая точка — строка той же таблицы, что уже стоит на странице выше; ни одного нового числа здесь не появилось. Пунктир — голый провод, 112 LUT при 827,81 МГц: единственный ориентир на плоскости, который не является форматом.',
      xl: 'площадь, LUT →',
      yl: '↑ частота, МГц',
      wire: 'голый провод',
      ours: 'наши',
      other: 'сравнение',
      caveat: 'Границы: XC7A200T (ALINX AX7203), открытый поток Yosys 0.65 + nextpnr-xilinx, медиана 5 seed’ов, DSP-инференс выключен. Одна family устройств, не многоугловая характеризация; ASIC-маппинг будет другим. Кремния нет — всё разведено на бинарной FPGA.',
      read: 'Что читается с картинки: выигрыш идёт от фиксированных полей, а не от тернарности — форматы с regime-кодеком (posit, LNS) уезжают вправо и вниз сразу на порядок, а не на проценты.',
    },
    en: {
      h: 'The plane the catalogue is judged on',
      lede: 'Isolated decoder: area across, frequency up, so down-and-right is worse. Every point is a row of the same table already printed above; no new number appears here. The dashed pair is the bare wire, 112 LUT at 827.81 MHz — the only reference on this plane that is not a format.',
      xl: 'area, LUT →',
      yl: '↑ frequency, MHz',
      wire: 'bare wire',
      ours: 'ours',
      other: 'comparison',
      caveat: 'Bounds: XC7A200T (ALINX AX7203), open flow Yosys 0.65 + nextpnr-xilinx, median of 5 seeds, DSP inference off. One device family, not a multi-corner characterisation; an ASIC mapping will differ. There is no silicon — all of it is routed on a binary FPGA.',
      read: 'What the picture says: the advantage comes from fixed fields, not from ternarity — the formats carrying a regime codec (posit, LNS) fall right and down by an order of magnitude, not by percent.',
    },
  }[key]

  return (
    <div className="tnf-cell" style={{ border: '1px solid var(--border)' }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 'var(--sp0)', flexWrap: 'wrap' }}>
        <h3 style={{ margin: 0, fontSize: 'var(--f1)', fontWeight: 500 }}>{t.h}</h3>
        <Tagged tag="measured" />
      </div>
      <p style={{ color: 'var(--muted)', fontSize: 'var(--f-1)', lineHeight: PHI, margin: 'var(--sp0) 0 var(--sp2)', maxWidth: '72ch' }}>
        {t.lede}
      </p>

      <svg viewBox={`0 0 ${W} ${H}`} width="100%" role="img" aria-label={t.h} style={{ display: 'block', overflow: 'visible' }}>
        {[0, 200, 400, 600, 800, 1000].map((g) => (
          <g key={g}>
            <line x1={pad.l} x2={W - pad.r} y1={y(g)} y2={y(g)} stroke="rgba(255,255,255,0.07)" />
            <text x={pad.l - 6} y={y(g) + 3} fill="var(--muted)" fontSize="11" textAnchor="end">{g}</text>
          </g>
        ))}
        {[100, 200, 300, 400, 500].map((g) => (
          <g key={g}>
            <line x1={x(g)} x2={x(g)} y1={pad.t} y2={H - pad.b} stroke="rgba(255,255,255,0.07)" />
            <text x={x(g)} y={H - pad.b + 13} fill="var(--muted)" fontSize="11" textAnchor="middle">{g}</text>
          </g>
        ))}

        {/* the bare wire */}
        <line x1={pad.l} x2={W - pad.r} y1={y(827.81)} y2={y(827.81)} stroke="var(--golden)" strokeWidth="1" strokeDasharray="4 4" opacity="0.55" />
        <line x1={x(112)} x2={x(112)} y1={pad.t} y2={H - pad.b} stroke="var(--golden)" strokeWidth="1" strokeDasharray="4 4" opacity="0.55" />
        <text x={W - pad.r} y={y(827.81) - 6} fill="var(--golden)" fontSize="11" textAnchor="end" opacity="0.8">{t.wire} · 112 LUT · 827.81</text>

        {pts.map((p) => {
          const on = hover === p.name
          const flip = p.lut > 380
          // TNF16 (101 LUT, 407.66) и BNF16 (97, 388.35) стоят почти в одной
          // точке — подписи расходятся вручную, иначе они наезжают.
          const nudge = NUDGE[p.name] ?? { dx: 0, dy: 0 }
          return (
            <g key={p.name} onMouseEnter={() => setHover(p.name)} onMouseLeave={() => setHover(null)} style={{ cursor: 'default' }}>
              <circle cx={x(p.lut)} cy={y(p.fmax)} r={on ? 7 : 4.5}
                fill={p.ours ? 'var(--accent)' : 'rgba(255,255,255,0.55)'} />
              <circle cx={x(p.lut)} cy={y(p.fmax)} r="14" fill="transparent" />
              <text
                x={x(p.lut) + (flip ? -10 : 10) + nudge.dx}
                y={y(p.fmax) + 3.5 + nudge.dy}
                textAnchor={flip ? 'end' : 'start'}
                fill={p.ours ? 'var(--accent)' : 'var(--muted)'}
                fontSize={on ? 13 : 12}
                fontWeight={p.ours ? 600 : 400}
              >
                {p.name}{on ? ` · ${p.lut} LUT · ${p.fmax} MHz` : ''}
              </text>
            </g>
          )
        })}

        <text x={W - pad.r} y={H - 4} fill="var(--muted)" fontSize="11" textAnchor="end">{t.xl}</text>
        <text x={pad.l - 40} y={12} fill="var(--muted)" fontSize="11">{t.yl}</text>
      </svg>

      <div style={{ display: 'flex', gap: 'var(--sp2)', flexWrap: 'wrap', fontSize: 'var(--f-2)', color: 'var(--muted)', marginTop: 'var(--sp1)' }}>
        <span style={{ color: 'var(--accent)' }}>● {t.ours}</span>
        <span>● {t.other}</span>
      </div>
      <p style={{ fontSize: 'var(--f-1)', lineHeight: PHI, margin: 'var(--sp2) 0 var(--sp0)', maxWidth: '72ch' }}>{t.read}</p>
      <p style={{ color: 'var(--muted)', fontSize: 'var(--f-2)', lineHeight: PHI, margin: 0, maxWidth: '72ch' }}>{t.caveat}</p>
    </div>
  )
}

/* ─────────────── the section ─────────────── */

export function TnfVisuals() {
  const key = useL()
  const t = {
    ru: {
      badge: 'ДВЕ РАБОТЫ, ДВА ЧЕРТЕЖА',
      title: 'Правило полей и плоскость стоимости',
      lede: 'Первый чертёж — это arXiv:2606.05017, правило раскладки полей: в нём нет ни одного измерения, только замкнутая форма. Второй — arXiv:2606.09686, каталог на плоскости, где его и судят: площадь против частоты, числа те же, что в таблице выше.',
    },
    en: {
      badge: 'TWO PAPERS, TWO DRAWINGS',
      title: 'The field rule and the cost plane',
      lede: 'The first drawing is arXiv:2606.05017, the field-layout rule: it contains no measurement at all, only a closed form. The second is arXiv:2606.09686, the catalogue on the plane it is judged on — area against frequency, the same numbers as the table above.',
    },
  }[key]

  return (
    <section id="visuals" className="tnf-section">
      <div className="tnf-wrap">
        <motion.div
          initial={{ opacity: 0, y: 18 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-60px' }}
          transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
        >
          <span className="tnf-badge">{t.badge}</span>
          <h2 className="tnf-h2 wide">{t.title}</h2>
          <p className="tnf-lede">{t.lede}</p>
        </motion.div>

        <div style={{ display: 'grid', gap: 'var(--sp2)' }}>
          <FieldRule />
          <CostPlane />
        </div>
      </div>
    </section>
  )
}

export default TnfVisuals
