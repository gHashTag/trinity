"use client";
import { useState } from 'react'
import { useI18n } from '../i18n/context'
import data from '../data/coronaConformance.json'

// What the paid tier produced, on my own chip, published including the part
// that went against me.
//
// Two things make this stronger than the usual conformance claim, and both are
// visible in the numbers rather than asserted:
//
//   * The oracle is not mine. It is ml_dtypes from the JAX project — an
//     implementation neither derived from nor written alongside the RTL. T9 is
//     the reason that sentence is load-bearing.
//   * The input spaces are small enough to enumerate. Every code point of every
//     format was checked, so there is no sampling and no statistical bound:
//     "exhaustive" here means what it says, which it almost never does.

type Result = { module: string; codes?: number; oracle?: string; mismatches?: number; error?: string }

const SNIPPET = `# .github/workflows/conformance.yml
jobs:
  e5m2:
    uses: gHashTag/trinity/.github/workflows/conformance-check.yml@main
    with:
      module: fp8_e5m2_decode
      sources: src/rtl/fp8_e5m2_decode.v
      input_port: e5m2_in
      width: 8
      reference: float8_e5m2`

const RESULTS = (data.results ?? []) as Result[]
const TOTAL = data.totalCodePoints ?? 0
const PASSED = RESULTS.filter((r) => !r.error && (r.mismatches ?? 0) === 0).length

const T = {
  en: {
    h2: 'What the paid tier produced, including the part that went against me',
    lede: `Every code point of seven number formats in my own Corona design (RTL; no die was fabricated), decoded in simulation and compared against ml_dtypes — the float4/float6/float8/bfloat16 implementation from the JAX project. ${TOTAL.toLocaleString('en-US')} code points, ${PASSED} of ${RESULTS.length} formats agreeing on every single one.`,
    exhaustive: 'Exhaustive, not sampled',
    exhaustiveBody: 'A 6-bit format has 64 inputs and an 8-bit format has 256. Every one was checked, so there is no confidence level to quote and no bound to state — the failure rate over the input space is zero, measured, not bounded. That is a claim this service can almost never make, and it is only available because these input spaces are small.',
    independent: 'The oracle is not mine',
    independentBody: 'ml_dtypes was written by other people, years apart from this RTL, from the same OCP MX and IEEE 754 specifications. A reference model derived from the design agrees with the design including where it is wrong — which is not a worry, it is a theorem, and it is T9 below.',
    found: 'What it found',
    foundBody: 'fp6_e3m2_decode collapses its entire top binade to one value: 16, 20, 24 and 28 all decode as 14, and so do their negatives. Eight of sixty-four code points, including the format maximum. The comment names the right rule and applies it backwards — OCP MX saturates when converting INTO the format, which is a property of the encoder; a code point with the top exponent is just a number, and FP6 reserves no encodings at all. The convention borrowed here belongs to FP8, which does. Fixed, with the repository’s own 21 gates green afterwards.',
    reader: 'What was actually missing was a reader',
    readerBody: 'It would be a better advertisement to say an outside oracle saw what the inside one could not. That is false. Three tests in that repository already reported this defect — two exhaustive, one against a reference not derived from the RTL — printing the same eight code points every time, and CI ran all three. CI had been red for six weeks: four runs, four failures. A fifth red carried no information anyone could act on, which is T12 below and the reason this section leads with it rather than with the find.',
    against: 'And the part that went against me',
    againstBody: 'The same tool first reported fourteen mismatches in mxfp8_e4m3_decode. That was my error: I compared against the IEEE-style float8_e4m3, which has infinities, where OCP MX E4M3 is float8_e4m3fn. Against the right reference it passes all 256 codes. The adjudication going against the reference model rather than the RTL is the normal case, and a page that only showed the other kind would be advertising, not evidence.',
    tableFormat: 'Format',
    tableCodes: 'Code points',
    tableOracle: 'Reference',
    tableVerdict: 'Result',
    pass: 'exhaustive pass',
    fail: (n: number) => `${n} disagreements`,
    repro: 'Reproduce it',
    runIt: 'Run this tier on your own design',
    runItBody: 'The same shape as the free check — your runner, your checkout, nothing uploaded. Name the module, its input port, the width, and an ml_dtypes reference. Every code point is applied, so what comes back is a count over the whole format rather than a bound over a sample.',
    copy: 'Copy',
    copied: 'Copied',
  },
  ru: {
    h2: 'Что дала платная ступень — включая часть, которая оказалась против меня',
    lede: `Все кодовые точки семи числовых форматов в моём же дизайне Corona (RTL; кристалл не изготавливался): декодированы в симуляции и сверены с ml_dtypes — реализацией float4/float6/float8/bfloat16 из проекта JAX. ${TOTAL.toLocaleString('ru-RU')} кодовых точек, ${PASSED} формата из ${RESULTS.length} совпадают на каждой.`,
    exhaustive: 'Исчерпывающе, а не выборочно',
    exhaustiveBody: 'У 6-битного формата 64 входа, у 8-битного — 256. Проверены все, поэтому не нужно называть ни уровень доверия, ни границу: частота отказа по пространству входов равна нулю — измеренному, а не ограниченному. Такое этот сервис может заявить крайне редко, и только потому, что эти пространства малы.',
    independent: 'Оракул не мой',
    independentBody: 'ml_dtypes написан другими людьми, на годы раньше этого RTL, по тем же спецификациям OCP MX и IEEE 754. Эталонная модель, выведенная из дизайна, соглашается с дизайном — включая места, где он неверен. Это не опасение, а теорема: T9 ниже.',
    found: 'Что нашлось',
    foundBody: 'fp6_e3m2_decode схлопывает всю старшую бинаду в одно значение: 16, 20, 24 и 28 декодируются как 14, и так же — отрицательные. Восемь кодов из шестидесяти четырёх, включая максимум формата. Комментарий называет верное правило и применяет его наоборот: OCP MX насыщает при конвертации В формат — это свойство кодировщика; кодовая точка со старшей экспонентой это просто число, а FP6 вообще не резервирует кодировок. Заимствованное соглашение принадлежит FP8, который резервирует.',
    reader: 'На самом деле не хватало читателя',
    readerBody: 'Красивее было бы сказать, что внешний оракул увидел то, чего не видел внутренний. Это неправда. Три теста того же репозитория уже сообщали об этом дефекте — два исчерпывающих, один против эталона, не выведенного из RTL, — и каждый раз печатали те же восемь кодов, и CI запускал все три. CI был красным шесть недель: четыре прогона, четыре падения. Пятое красное не несло информации, на которую можно опереться, — это T12 ниже и причина, по которой раздел начинается с неё, а не с находки.',
    against: 'И часть, которая оказалась против меня',
    againstBody: 'Тот же инструмент сначала сообщил о четырнадцати расхождениях в mxfp8_e4m3_decode. Это была моя ошибка: я сверял с IEEE-подобным float8_e4m3, у которого есть бесконечности, тогда как OCP MX E4M3 — это float8_e4m3fn. С верным эталоном модуль проходит все 256 кодов. Разбор, оказавшийся против эталонной модели, а не против RTL, — обычный случай, и страница, показывающая только другой род, была бы рекламой, а не свидетельством.',
    tableFormat: 'Формат',
    tableCodes: 'Кодовых точек',
    tableOracle: 'Эталон',
    tableVerdict: 'Результат',
    pass: 'исчерпывающе сошлось',
    fail: (n: number) => `${n} расхождений`,
    repro: 'Воспроизвести',
    runIt: 'Запустите эту ступень на своём дизайне',
    runItBody: 'Та же форма, что у бесплатной проверки: ваш раннер, ваш checkout, ничего никуда не загружается. Укажите модуль, входной порт, ширину и эталон из ml_dtypes. Применяются все кодовые точки, поэтому в ответе — счёт по всему формату, а не граница по выборке.',
    copy: 'Скопировать',
    copied: 'Скопировано',
  },
}

export default function ConformanceEvidence() {
  const { lang } = useI18n()
  const t = lang === 'ru' ? T.ru : T.en
  const [copied, setCopied] = useState(false)

  return (
    <div className="premium-card" style={{ textAlign: 'left', marginBottom: '2rem' }}>
      <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '0.6rem' }}>{t.h2}</h2>
      <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.88, maxWidth: '68ch', margin: '0 0 1.3rem' }}>{t.lede}</p>

      <div style={{ overflowX: 'auto', marginBottom: '1.4rem' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.86rem', minWidth: '520px' }}>
          <thead>
            <tr style={{ borderBottom: '1px solid var(--border)' }}>
              <th style={{ textAlign: 'left', padding: '0.5rem 0.6rem', opacity: 0.7, fontWeight: 600 }}>{t.tableFormat}</th>
              <th style={{ textAlign: 'right', padding: '0.5rem 0.6rem', opacity: 0.7, fontWeight: 600 }}>{t.tableCodes}</th>
              <th style={{ textAlign: 'left', padding: '0.5rem 0.6rem', opacity: 0.7, fontWeight: 600 }}>{t.tableOracle}</th>
              <th style={{ textAlign: 'left', padding: '0.5rem 0.6rem', opacity: 0.7, fontWeight: 600 }}>{t.tableVerdict}</th>
            </tr>
          </thead>
          <tbody>
            {RESULTS.map((r) => {
              const ok = !r.error && (r.mismatches ?? 0) === 0
              return (
                <tr key={r.module} style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                  <td style={{ padding: '0.5rem 0.6rem', fontFamily: 'monospace' }}>{r.module.replace(/_decode$/, '')}</td>
                  <td style={{ padding: '0.5rem 0.6rem', textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>
                    {(r.codes ?? 0).toLocaleString(lang === 'ru' ? 'ru-RU' : 'en-US')}
                  </td>
                  <td style={{ padding: '0.5rem 0.6rem', fontFamily: 'monospace', opacity: 0.75, fontSize: '0.8rem' }}>
                    {(r.oracle ?? '—').replace('ml_dtypes.', '')}
                  </td>
                  <td style={{ padding: '0.5rem 0.6rem', color: ok ? 'var(--accent)' : '#ff8a6b', fontWeight: 600 }}>
                    {ok ? t.pass : t.fail(r.mismatches ?? 0)}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>

      {[[t.exhaustive, t.exhaustiveBody], [t.independent, t.independentBody], [t.found, t.foundBody], [t.reader, t.readerBody], [t.against, t.againstBody]].map(([head, body]) => (
        <div key={head as string} style={{ marginBottom: '0.9rem' }}>
          <strong style={{ display: 'block', marginBottom: '0.25rem', fontSize: '0.92rem' }}>{head}</strong>
          <span style={{ fontSize: '0.88rem', lineHeight: 1.6, opacity: 0.85 }}>{body}</span>
        </div>
      ))}

      <div style={{ marginTop: '1.4rem', marginBottom: '1.2rem' }}>
        <strong style={{ display: 'block', marginBottom: '0.3rem', fontSize: '0.92rem' }}>{t.runIt}</strong>
        <p style={{ margin: '0 0 0.7rem', fontSize: '0.88rem', lineHeight: 1.6, opacity: 0.85, maxWidth: '68ch' }}>{t.runItBody}</p>
        <div style={{ position: 'relative' }}>
          <button
            onClick={() => { navigator.clipboard?.writeText(SNIPPET).then(() => { setCopied(true); setTimeout(() => setCopied(false), 2000) }) }}
            className="btn secondary"
            style={{ position: 'absolute', top: '8px', right: '8px', padding: '6px 14px', fontSize: '0.75rem', zIndex: 2 }}
          >
            {copied ? t.copied : t.copy}
          </button>
          <pre style={{
            margin: 0, padding: '1rem 1rem 1rem 1.1rem', overflowX: 'auto',
            background: 'rgba(0,0,0,0.35)', border: '1px solid rgba(255,255,255,0.09)',
            borderRadius: '10px', fontSize: '0.8rem', lineHeight: 1.6,
          }}><code>{SNIPPET}</code></pre>
        </div>
      </div>

      <div style={{ marginTop: '1.1rem', display: 'flex', gap: '0.6rem', flexWrap: 'wrap' }}>
        <a href="https://github.com/gHashTag/trinity/blob/main/tools/corona_conformance.py" target="_blank" rel="noopener noreferrer"
           className="btn secondary" style={{ padding: '9px 20px', fontSize: '0.82rem' }}>
          {t.repro}
        </a>
        <a href="https://github.com/gHashTag/tt-trinity-corona/issues/8" target="_blank" rel="noopener noreferrer"
           className="btn secondary" style={{ padding: '9px 20px', fontSize: '0.82rem' }}>
          {lang === 'ru' ? 'Дефект и починка' : 'The defect and its fix'}
        </a>
      </div>
    </div>
  )
}
