'use client'

// Раздел «Проверить теорему руками»: три живых калькулятора по несущим теоремам
// работы «Trinity S³AI: Ternary Network Floats».
//
// Правило файла: калькулятор считает ТОЛЬКО замкнутые формы, выписанные в
// теоремах, и рядом показывает измеренную величину, если она есть. Ни одно
// число, полученное этими формулами, не выдаётся за измерение: у каждого блока
// собственный тег происхождения — «выведено» для формулы, «измерено» для
// сопоставления с прогоном.
//
// Т1  (закон точности):   E[|rel err|] = ½·E[1/s]·2^−(M+1)
// Т23 (оптимальный член): E_t* = ⌈log₃(b+1)⌉,  M* = N − 1 − E_t*
// Т49 (потеря упаковки):  3^{E_t} против 2^{ceil(E_t·log₂3)}

import { useMemo, useState } from 'react'
import { motion } from 'framer-motion'
import { useI18n } from '../../../i18n/context'
import { TAG_LABEL, type Tag } from '../../../content/tnf'
import './tnf.css'

type Bi = { en: string; ru: string }

const T = {
  badge: { en: 'CHECK A THEOREM BY HAND', ru: 'ПРОВЕРИТЬ ТЕОРЕМУ РУКАМИ' },
  title: {
    en: 'Three closed forms, computed in the page as you move the inputs',
    ru: 'Три замкнутые формы, вычисляемые в странице по мере движения входов',
  },
  sub: {
    en: 'These are the formulas from T1, T23 and T49, evaluated live. They are derivations, not measurements — where a measured value exists for the same point, it is shown next to the derived one so the two can disagree in public.',
    ru: 'Это формулы Т1, Т23 и Т49, вычисляемые на месте. Это выводы, а не измерения — там, где для той же точки есть измеренная величина, она показана рядом с выведенной, чтобы расхождение было видно публично.',
  },
  t1: {
    h: { en: 'T1 · Precision law', ru: 'Т1 · Закон точности' },
    stmt: { en: 'E[|rel err|] = ½ · E[1/s] · 2^−(M+1) — independent of the exponent.', ru: 'E[|отн. ошибка|] = ½ · E[1/s] · 2^−(M+1) — независимо от экспоненты.' },
    m: { en: 'significand bits M', ru: 'бит значащей M' },
    es: { en: 'E[1/s] of the workload', ru: 'E[1/s] нагрузки' },
    out: { en: 'predicted mean relative error', ru: 'предсказанная средняя относительная ошибка' },
    norm: { en: 'the same, in units of 2^−(M+1)', ru: 'то же, в единицах 2^−(M+1)' },
    note: {
      en: 'Presets: 0.7721 is our measured workload, ln2 = 0.6931 is a uniform significand on [1,2), (2ln2)⁻¹ = 0.7213 is Benford. At M = 9 and E[1/s] = 0.7721 the coefficient is 0.3861 derived against 0.3756 measured over eight rungs (spread 0.369–0.390).',
      ru: 'Преднастройки: 0.7721 — наша измеренная нагрузка, ln2 = 0.6931 — равномерная значащая на [1,2), (2ln2)⁻¹ = 0.7213 — Бенфорд. При M = 9 и E[1/s] = 0.7721 коэффициент 0.3861 выведен против 0.3756 измеренного на восьми ступенях (разброс 0.369–0.390).',
    },
  },
  t23: {
    h: { en: 'T23 · Optimal member for a named range', ru: 'Т23 · Оптимальный член для названного диапазона' },
    stmt: { en: 'E_t* = ⌈log₃(b+1)⌉ and M* = N − 1 − E_t*, a unique maximum — no free parameter once the workload is measured.', ru: 'E_t* = ⌈log₃(b+1)⌉ и M* = N − 1 − E_t*, единственный максимум — свободного параметра нет, как только нагрузка измерена.' },
    n: { en: 'format width N, bits', ru: 'ширина формата N, бит' },
    b: { en: 'workload range b, binades', ru: 'диапазон нагрузки b, бинад' },
    et: { en: 'E_t*, trits of exponent', ru: 'E_t*, тритов экспоненты' },
    ms: { en: 'M*, bits of significand', ru: 'M*, бит значащей' },
    err: { en: 'predicted error at M*, by T1', ru: 'предсказанная ошибка при M*, по Т1' },
    cover: { en: 'binades the field covers', ru: 'бинад покрывает поле' },
    bad: { en: 'The range does not fit this width: E_t* alone consumes N − 1. Widen N or measure a narrower range.', ru: 'Диапазон не помещается в эту ширину: один E_t* съедает N − 1. Расширьте N или измерьте более узкий диапазон.' },
    note: {
      en: 'By T24 the penalty is asymmetric — oversizing pays in precision at every value, undersizing pays in range on the tail only. Under uncertainty, round up. On 210 layers the measured range was 3.15 octaves, for which 2 bits suffice.',
      ru: 'По Т24 штраф асимметричен — пере-размер платит точностью в каждом значении, недо-размер платит диапазоном только на хвосте. При неопределённости округлять вверх. На 210 слоях измеренный диапазон составил 3.15 октавы, для которых достаточно 2 бита.',
    },
  },
  t49: {
    h: { en: 'T49 · Packing loss on a binary fabric', ru: 'Т49 · Потеря на упаковке в бинарную фабрику' },
    stmt: { en: 'A field of E_t trits holds 3^{E_t} values; the binary container holds 2^⌈E_t·log₂3⌉. The remainder is arithmetic, not engineering.', ru: 'Поле из E_t тритов держит 3^{E_t} значений; бинарный контейнер держит 2^⌈E_t·log₂3⌉. Остаток — арифметика, а не инженерия.' },
    et: { en: 'trits in the field E_t', ru: 'тритов в поле E_t' },
    used: { en: 'values used, 3^{E_t}', ru: 'значений использовано, 3^{E_t}' },
    box: { en: 'container, 2^⌈E_t·log₂3⌉', ru: 'контейнер, 2^⌈E_t·log₂3⌉' },
    loss: { en: 'loss', ru: 'потеря' },
    note: {
      en: 'The loss depends on E_t alone: adding mantissa bits multiplies both sides by the same 2^M, so a table row indexed by width N is this same ratio at N − 1 = ⌈E_t·log₂3⌉ + M. The published rows are E_t = 1 at 4 bits (6/8 = −25.0%), E_t = 3 at 6 bits (27/32 = −15.6%), E_t = 3 at 8 bits (108/128 = −15.6%) and E_t = 5 at 16 bits (31 104/32 768 = −5.1%). Even values of E_t are worse than their neighbours — at E_t = 4 the ratio is 81/128 — and this is the reason our own ternary claim is architectural rather than commercial.',
      ru: 'Потеря зависит только от E_t: добавленные биты мантиссы умножают обе части на одно и то же 2^M, так что строка таблицы, индексированная шириной N, есть то же самое отношение при N − 1 = ⌈E_t·log₂3⌉ + M. Опубликованные строки — это E_t = 1 на 4 битах (6/8 = −25.0%), E_t = 3 на 6 битах (27/32 = −15.6%), E_t = 3 на 8 битах (108/128 = −15.6%) и E_t = 5 на 16 битах (31 104/32 768 = −5.1%). Чётные E_t хуже соседей — при E_t = 4 отношение равно 81/128 — и именно это делает наше троичное заявление архитектурным, а не коммерческим.',
    },
  },
  footer: {
    en: 'The inputs are yours; the formulas are the paper’s. A disagreement between a value you compute here and a value we measured is a result, and the place to send it is the address at the bottom of this page.',
    ru: 'Входы — ваши; формулы — из статьи. Расхождение между значением, которое вы посчитали здесь, и значением, которое мы измерили, есть результат, и адрес для него — внизу этой страницы.',
  },
}

function useL() {
  const { lang } = useI18n()
  const key = (lang === 'ru' ? 'ru' : 'en') as 'ru' | 'en'
  return { key, L: (v: Bi) => v[key] }
}

function Chip({ tag }: { tag: Tag }) {
  const { key } = useL()
  const t = TAG_LABEL[tag]
  return <span className="tnf-tag" style={{ color: t.color }}>{t[key]}</span>
}

const fade = {
  initial: { opacity: 0, y: 18 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, margin: '-60px' },
  transition: { duration: 0.5, ease: [0.22, 1, 0.36, 1] as [number, number, number, number] },
}

const lbl: React.CSSProperties = {
  display: 'block', fontSize: '0.74rem', letterSpacing: '0.06em', textTransform: 'uppercase',
  color: 'var(--muted)', marginBottom: '0.4rem', fontWeight: 600,
}
const box: React.CSSProperties = { marginBottom: '1rem' }
const out: React.CSSProperties = {
  display: 'flex', justifyContent: 'space-between', gap: '1rem', padding: '0.5rem 0',
  borderTop: '1px solid var(--border)', fontSize: '0.84rem',
}
const val: React.CSSProperties = { color: 'var(--golden)', fontWeight: 600, whiteSpace: 'nowrap' }

function Range(p: { label: string; min: number; max: number; step: number; value: number; onChange: (n: number) => void; suffix?: string }) {
  return (
    <div style={box}>
      <label style={lbl}>
        {p.label} — <span className="tnf-mono" style={{ color: 'var(--golden)', textTransform: 'none', letterSpacing: 0 }}>{p.value}{p.suffix ?? ''}</span>
      </label>
      <input
        type="range" min={p.min} max={p.max} step={p.step} value={p.value}
        onChange={(e) => p.onChange(Number(e.target.value))}
        aria-label={p.label}
        aria-valuetext={`${p.value}${p.suffix ?? ''}`}
        style={{ width: '100%', accentColor: 'var(--golden)' }}
      />
    </div>
  )
}

export default function TnfCalculators() {
  const { L } = useL()

  const [M, setM] = useState(9)
  const [Es, setEs] = useState(0.7721)
  const [N, setN] = useState(16)
  const [b, setB] = useState(8)
  const [Et49, setEt49] = useState(4)

  const t1 = useMemo(() => {
    const coeff = 0.5 * Es
    return { coeff, err: coeff * Math.pow(2, -(M + 1)) }
  }, [M, Es])

  const t23 = useMemo(() => {
    const et = Math.ceil(Math.log(b + 1) / Math.log(3))
    const ms = N - 1 - et
    const cover = Math.pow(3, et)
    return { et, ms, ok: ms >= 0, err: ms >= 0 ? 0.5 * Es * Math.pow(2, -(ms + 1)) : NaN, cover }
  }, [N, b, Es])

  const t49 = useMemo(() => {
    const used = Math.pow(3, Et49)
    const bits = Math.ceil(Et49 * Math.log2(3))
    const boxN = Math.pow(2, bits)
    return { used, bits, boxN, loss: (used / boxN - 1) * 100 }
  }, [Et49])

  const fmt = (x: number) => x.toLocaleString('en-US', { maximumFractionDigits: 0 })

  return (
    <section id="calculators" className="tnf-section">
      <div className="tnf-wrap">
        <motion.div {...fade}>
          <span className="tnf-badge">{L(T.badge)}</span>
          <h2 className="tnf-h2 wide">{L(T.title)}</h2>
          <p className="tnf-lede">{L(T.sub)}</p>
        </motion.div>

        <motion.div {...fade} className="tnf-grid tnf-grid-3">
          {/* ── T1 ── */}
          <div className="tnf-cell">
            <div style={{ display: 'flex', gap: '0.6rem', alignItems: 'center', flexWrap: 'wrap', marginBottom: '0.5rem' }}>
              <strong style={{ fontSize: '0.96rem', fontWeight: 600 }}>{L(T.t1.h)}</strong>
              <Chip tag="derived" />
            </div>
            <p className="tnf-mono" style={{ fontSize: '0.82rem', lineHeight: 1.6, opacity: 0.85, margin: '0 0 1.1rem', maxWidth: 'none' }}>{L(T.t1.stmt)}</p>

            <Range label={L(T.t1.m)} min={1} max={23} step={1} value={M} onChange={setM} />
            <Range label={L(T.t1.es)} min={0.5} max={1} step={0.0001} value={Es} onChange={setEs} />

            <div style={out}><span>{L(T.t1.out)}</span><span className="tnf-mono" style={val}>{t1.err.toExponential(4)}</span></div>
            <div style={out}><span>{L(T.t1.norm)}</span><span className="tnf-mono" style={val}>{t1.coeff.toFixed(4)}</span></div>
            <p className="tnf-note">{L(T.t1.note)}</p>
          </div>

          {/* ── T23 ── */}
          <div className="tnf-cell">
            <div style={{ display: 'flex', gap: '0.6rem', alignItems: 'center', flexWrap: 'wrap', marginBottom: '0.5rem' }}>
              <strong style={{ fontSize: '0.96rem', fontWeight: 600 }}>{L(T.t23.h)}</strong>
              <Chip tag="proved" />
            </div>
            <p className="tnf-mono" style={{ fontSize: '0.82rem', lineHeight: 1.6, opacity: 0.85, margin: '0 0 1.1rem', maxWidth: 'none' }}>{L(T.t23.stmt)}</p>

            <Range label={L(T.t23.n)} min={4} max={32} step={1} value={N} onChange={setN} />
            <Range label={L(T.t23.b)} min={1} max={80} step={1} value={b} onChange={setB} />

            <div style={out}><span>{L(T.t23.et)}</span><span className="tnf-mono" style={val}>{t23.et}</span></div>
            <div style={out}><span>{L(T.t23.ms)}</span><span className="tnf-mono" style={val}>{t23.ok ? t23.ms : '—'}</span></div>
            <div style={out}><span>{L(T.t23.cover)}</span><span className="tnf-mono" style={val}>{fmt(t23.cover)}</span></div>
            <div style={out}><span>{L(T.t23.err)}</span><span className="tnf-mono" style={val}>{t23.ok ? t23.err.toExponential(3) : '—'}</span></div>
            {t23.ok ? null : <p className="tnf-note" style={{ color: '#FF6B6B' }}>{L(T.t23.bad)}</p>}
            <p className="tnf-note">{L(T.t23.note)}</p>
          </div>

          {/* ── T49 ── */}
          <div className="tnf-cell">
            <div style={{ display: 'flex', gap: '0.6rem', alignItems: 'center', flexWrap: 'wrap', marginBottom: '0.5rem' }}>
              <strong style={{ fontSize: '0.96rem', fontWeight: 600 }}>{L(T.t49.h)}</strong>
              <Chip tag="proved" />
            </div>
            <p className="tnf-mono" style={{ fontSize: '0.82rem', lineHeight: 1.6, opacity: 0.85, margin: '0 0 1.1rem', maxWidth: 'none' }}>{L(T.t49.stmt)}</p>

            <Range label={L(T.t49.et)} min={1} max={12} step={1} value={Et49} onChange={setEt49} />

            <div style={out}><span>{L(T.t49.used)}</span><span className="tnf-mono" style={val}>{fmt(t49.used)}</span></div>
            <div style={out}><span>{L(T.t49.box)}</span><span className="tnf-mono" style={val}>{fmt(t49.boxN)} ({t49.bits} bit)</span></div>
            <div style={out}><span>{L(T.t49.loss)}</span><span className="tnf-mono" style={{ ...val, color: '#FF6B6B' }}>{t49.loss.toFixed(1)}%</span></div>
            <p className="tnf-note">{L(T.t49.note)}</p>
          </div>
        </motion.div>

        <motion.p {...fade} className="tnf-note" style={{ marginTop: '1.4rem' }}>{L(T.footer)}</motion.p>
      </div>
    </section>
  )
}
