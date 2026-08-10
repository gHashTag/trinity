"use client";
import { useState } from 'react'
import { useI18n } from '../i18n/context'

// The page used to answer "where is the service?" with a link to an issue form,
// which is not a service — it is a queue with me at the end of it. The thing
// that actually runs is six lines of YAML the customer puts in their own
// repository, and it has now been called across the repo boundary and reported
// 17 and 66 flip-flops for two designs that hold exactly that many.
//
// So it goes first, above the intake, with the snippet visible rather than
// described. Nothing to sign up for, no sources sent anywhere: it runs on the
// customer's runner, against the customer's checkout.

const SNIPPET = `# .github/workflows/rtl-check.yml
name: RTL check
on: [push, pull_request]

jobs:
  check:
    uses: gHashTag/trinity/.github/workflows/rtl-check.yml@main
    with:
      top: my_top_module`

const T = {
  en: {
    eyebrow: 'Run it yourself, now',
    h2: 'Six lines in your repository. No account, no upload, no waiting for me.',
    lede: 'The check runs on your runner against your checkout. Your RTL is never sent anywhere — which is not a courtesy but the only shape that works, because the closest comparable service moved off hosted CI for exactly this reason.',
    steps: [
      ['1', 'Paste this into .github/workflows/rtl-check.yml', 'Change my_top_module to your top module name. If your repo has a Tiny Tapeout info.yaml, the source list is read from it.'],
      ['2', 'Push', 'It installs yosys and iverilog and runs in about a minute.'],
      ['3', 'Read the job summary', 'Four structural facts, each with the command that produced it — and a list of what the run does not establish.'],
    ],
    copy: 'Copy',
    copied: 'Copied',
    proof: 'Proven across the repo boundary',
    proofBody: 'Called from gHashTag/trinity-fpga on two chips awaiting a Tiny Tapeout shuttle. It reported 17 and 66 flip-flops — the counts those netlists hold. The first cross-repo run called both "purely combinational"; the parser assumed yosys prints the cell histogram count-first, and on ubuntu-latest it prints name-first. That is now asserted by value in the self-test, and the self-test has a job that deliberately asserts a wrong count to prove the assertion can fail.',
    not: 'A pass is not a proof of correctness. Nothing in this run compares your design against a specification — that is the paid tier below, and it is worth what it costs only because this one says plainly that it is not it.',
    src: 'Read the workflow',
  },
  ru: {
    eyebrow: 'Запустите сами, прямо сейчас',
    h2: 'Шесть строк в вашем репозитории. Без регистрации, без загрузки, без ожидания меня.',
    lede: 'Проверка идёт на вашем раннере и по вашему checkout. Ваш RTL никуда не отправляется — и это не любезность, а единственная работающая форма: ближайший сопоставимый сервис ушёл с хостед-CI ровно по этой причине.',
    steps: [
      ['1', 'Вставьте это в .github/workflows/rtl-check.yml', 'Замените my_top_module на имя вашего верхнего модуля. Если в репозитории есть info.yaml от Tiny Tapeout, список файлов берётся из него.'],
      ['2', 'Запушьте', 'Ставит yosys и iverilog, отрабатывает примерно за минуту.'],
      ['3', 'Прочитайте сводку задания', 'Четыре структурных факта, под каждым — команда, которая его дала, и перечень того, чего прогон НЕ устанавливает.'],
    ],
    copy: 'Скопировать',
    copied: 'Скопировано',
    proof: 'Доказано через границу репозиториев',
    proofBody: 'Вызвано из gHashTag/trinity-fpga на двух чипах, ждущих шаттл Tiny Tapeout. Ответ — 17 и 66 триггеров, ровно столько в этих нетлистах. Первый кросс-репо прогон назвал оба «чисто комбинационными»: разбор предполагал, что yosys печатает гистограмму числом вперёд, а на ubuntu-latest она печатается именем вперёд. Теперь число проверяется в селф-тесте по значению, и там есть работа, которая заведомо заявляет неверный счёт — чтобы доказать, что проверка умеет падать.',
    not: 'Пройденная проверка не есть доказательство корректности. Ничто в этом прогоне не сверяет ваш дизайн со спецификацией — это платная ступень ниже, и она стоит своих денег только потому, что здесь прямо сказано, что это не она.',
    src: 'Посмотреть воркфлоу',
  },
}

export default function SelfServeRun() {
  const { lang } = useI18n()
  const t = lang === 'ru' ? T.ru : T.en
  const [copied, setCopied] = useState(false)

  const copy = () => {
    navigator.clipboard?.writeText(SNIPPET).then(() => {
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    })
  }

  return (
    <div id="self-serve" className="premium-card" style={{ scrollMarginTop: '90px', marginBottom: '2rem', textAlign: 'left' }}>
      <p style={{ color: 'var(--accent)', letterSpacing: '0.14em', textTransform: 'uppercase', fontSize: '0.75rem', margin: '0 0 0.6rem' }}>
        {t.eyebrow}
      </p>
      <h2 style={{ fontSize: 'clamp(1.25rem, 3.4vw, 1.65rem)', margin: '0 0 0.7rem', lineHeight: 1.25 }}>{t.h2}</h2>
      <p style={{ margin: '0 0 1.25rem', lineHeight: 1.65, opacity: 0.85, maxWidth: '68ch' }}>{t.lede}</p>

      <div style={{ position: 'relative', marginBottom: '1.25rem' }}>
        <button
          onClick={copy}
          className="btn secondary"
          style={{ position: 'absolute', top: '8px', right: '8px', padding: '6px 14px', fontSize: '0.75rem', zIndex: 2 }}
        >
          {copied ? t.copied : t.copy}
        </button>
        <pre style={{
          margin: 0, padding: '1rem 1rem 1rem 1.1rem', overflowX: 'auto',
          background: 'rgba(0,0,0,0.35)', border: '1px solid rgba(255,255,255,0.09)',
          borderRadius: '10px', fontSize: '0.82rem', lineHeight: 1.6,
        }}>
          <code>{SNIPPET}</code>
        </pre>
      </div>

      <ol style={{ listStyle: 'none', padding: 0, margin: '0 0 1.25rem', display: 'grid', gap: '0.7rem' }}>
        {t.steps.map(([n, head, body]) => (
          <li key={n} style={{ display: 'flex', gap: '0.75rem', alignItems: 'flex-start' }}>
            <span style={{
              flex: '0 0 auto', width: '22px', height: '22px', borderRadius: '50%',
              border: '1px solid var(--accent)', color: 'var(--accent)',
              display: 'grid', placeItems: 'center', fontSize: '0.72rem', marginTop: '2px',
            }}>{n}</span>
            <span style={{ lineHeight: 1.6 }}>
              <strong style={{ fontWeight: 600 }}>{head}</strong>
              <span style={{ display: 'block', opacity: 0.8, fontSize: '0.92rem' }}>{body}</span>
            </span>
          </li>
        ))}
      </ol>

      <div style={{
        padding: '0.9rem 1rem', borderRadius: '10px',
        background: 'rgba(0,255,136,0.05)', border: '1px solid rgba(0,255,136,0.18)',
        marginBottom: '1rem',
      }}>
        <strong style={{ display: 'block', marginBottom: '0.35rem', fontSize: '0.9rem' }}>{t.proof}</strong>
        <span style={{ fontSize: '0.88rem', lineHeight: 1.6, opacity: 0.85 }}>{t.proofBody}</span>
      </div>

      <p style={{ margin: '0 0 1rem', fontSize: '0.88rem', lineHeight: 1.6, opacity: 0.75 }}>{t.not}</p>

      <a
        href="https://github.com/gHashTag/trinity/blob/main/.github/workflows/rtl-check.yml"
        target="_blank"
        rel="noopener noreferrer"
        className="btn secondary"
        style={{ padding: '10px 22px', fontSize: '0.85rem' }}
      >
        {t.src}
      </a>
    </div>
  )
}
