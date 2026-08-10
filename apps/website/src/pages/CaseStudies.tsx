"use client";
import { motion } from 'framer-motion'
import { usePageMeta } from '../hooks/usePageMeta'
import { useI18n } from '../i18n/context'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import QuantumBackground from '../components/QuantumBackground'
import { RUNS, THIRD_PARTY_RUNS, LIMITS_EN, LIMITS_RU, PROVENANCE } from '../data/verificationRuns'
import type { Run } from '../data/verificationRuns'

const CONTACT = {
  email: 'admin@t27.ai',
  // The intake needs no backend: the visitor opens a pre-filled issue, and the
  // workflow in that repo clones, elaborates, checks latches and synthesises,
  // then posts the report back into the issue. A static site cannot hold a
  // secret, so anything requiring one (private repositories) is handled by hand.
  requestUrl: 'https://github.com/gHashTag/trinity/issues/new?template=verification-request.yml',
  sampleReport: 'https://github.com/gHashTag/trinity/blob/main/docs/verification/SAMPLE-REPORT.md',
}

/**
 * Client work, newest first.
 *
 * Empty on purpose until a real run finishes — an invented case study is worth
 * less than an honest empty page, because the whole offer rests on measured
 * claims. To add one, append an entry here; the page switches out of its empty
 * state on its own.
 *
 * Every field must come from the run itself:
 *   design    what was verified, in the client's words where possible
 *   found     what the check surfaced (including "nothing" — that is a result)
 *   measured  the numbers, from the board
 *   quote     verbatim, with permission, or omitted entirely
 */
type CaseStudy = {
  client: string
  anonymous?: boolean
  design: string
  found: string
  measured: { label: string; value: string }[]
  turnaround: string
  quote?: { text: string; who: string }
  reportUrl?: string
}

const CASES: CaseStudy[] = []

const RU = {
  eyebrow: 'Работы',
  h1: 'Что показали чужие дизайны.',
  lede: 'Каждый прогон заканчивается отчётом: что проверялось, что нашлось и какие цифры сняты с платы. Здесь они собраны — с разрешения клиента и без правок в его пользу.',
  emptyTitle: 'Пока пусто — и это честно',
  emptyBody: 'Первые прогоны идут бесплатно, и до тех пор, пока хотя бы один не закончится, здесь ничего не будет. Выдуманный кейс стоил бы дешевле пустой страницы: всё предложение держится на том, что цифры измерены.',
  emptyCta: 'Пока смотрите образец отчёта — на моём собственном дизайне, с теми же разделами, которые получит ваш.',
  ctaSample: 'Образец отчёта',
  ctaRequest: 'Запросить прогон',
  found: 'Что нашлось',
  turnaround: 'Срок',
  design: 'Что проверялось',
  runsTitle: 'Прогоны на моих собственных дизайнах',
  thirdTitle: 'Прогоны на чужих дизайнах',
  thirdLede: 'Те же проверки, тот же день, публичные заявки Tiny Tapeout под открытой лицензией.',
  scoreTitle: 'Счёт, который я искал против себя',
  scoreBody: 'Я специально искал среди чужих дизайнов провал — чтобы витрина не читалась как подбор удачных случаев. Не нашёл: все пять объявляют source_files и собираются из объявленного. Неудобный результат оказался на моей стороне: из пяти моих чипов у двух список неполон (phi, gamma), а ещё двое не объявляют его вовсе (mini, holo) — и шаттл собирается именно по нему. Счёт 5:1 не в мою пользу.',
  runsLede: 'Прежде чем предлагать это другим, я прогнал через ту же машину пять своих чипов. Это доказывает, что харнесс работает, а не что мне кто-то доверяет, — клиентские работы ниже и они пока пусты.',
  limitsTitle: 'Чего эти прогоны НЕ устанавливают',
  svcTitle: 'Как прогнать свой репозиторий',
  svcOpen: 'Открытый код — бесплатно',
  svcOpenBody: 'Публичный репозиторий проверяется бесплатно, а отчёт публикуется здесь целиком: и то, что прошло, и то, что нет. Это цена бесплатного — результат виден всем.',
  svcPrivate: 'Закрытый репозиторий — платно',
  svcPrivateBody: 'Приватный код требует доступа, который статический сайт держать не может, поэтому такие прогоны заводятся вручную и оплачиваются. Отчёт остаётся у вас; публикуется только с вашего разрешения.',
  svcHow: 'Что нужно от вас: ссылка на репозиторий, имя верхнего модуля и одна фраза о том, что значит «правильно» для этого дизайна.',
  svcCta: 'Открыть заявку на GitHub',
}

const EN = {
  eyebrow: 'Case studies',
  h1: 'What other people’s designs turned out to be.',
  lede: 'Every run ends in a report: what was checked, what it surfaced, and the numbers taken off the board. They are collected here, with the client’s permission and without edits in my favour.',
  emptyTitle: 'Empty for now, and honestly so',
  emptyBody: 'The first runs are free, and until one of them finishes there will be nothing here. An invented case study would be worth less than an empty page: the whole offer rests on the numbers being measured.',
  emptyCta: 'In the meantime, read the sample report — my own design, with the same sections yours would get.',
  ctaSample: 'Sample report',
  ctaRequest: 'Request a run',
  found: 'What it surfaced',
  turnaround: 'Turnaround',
  design: 'What was checked',
  runsTitle: 'Runs on my own designs',
  thirdTitle: "Runs on other people's designs",
  thirdLede: 'The same checks, the same day, on public Tiny Tapeout submissions under an open licence.',
  scoreTitle: 'The count I went looking for against myself',
  scoreBody: 'I went looking for a failure among other people\u2019s designs, so the gallery would not read as a selection of happy cases. I did not find one: all five declare source_files and elaborate from what they declare. The uncomfortable result is on my side — of my five chips, two declare an incomplete list (phi, gamma) and two declare none at all (mini, holo), and a shuttle builds from exactly that list. The count is 5 to 1 against me.',
  runsLede: 'Before offering this to anyone else I put five of my own chips through the same machine. That proves the harness runs, not that anyone trusts it — client work is below, and it is still empty.',
  limitsTitle: 'What these runs do NOT establish',
  svcTitle: 'Run your own repository',
  svcOpen: 'Open source — free',
  svcOpenBody: 'A public repository is checked for free and the report is published here in full, whether it passed or not. That is the price of free: the result is visible to everyone.',
  svcPrivate: 'Private repository — paid',
  svcPrivateBody: 'Private code needs access a static site cannot hold, so those runs are set up by hand and invoiced. The report stays yours; it is published only with your permission.',
  svcHow: 'What I need from you: the repository URL, the top module name, and one sentence on what "correct" means for this design.',
  svcCta: 'Open a request on GitHub',
}

function mailto(subject: string) {
  return `mailto:${CONTACT.email}?subject=${encodeURIComponent(subject)}`
}


function RunCard({ run, foundLabel, lang }: { run: Run; foundLabel: string; lang: string }) {
  const failed = run.checks.filter((k) => k.status !== 'PASS').length
  return (
    <div className="premium-card" style={{ textAlign: 'left', marginBottom: '1rem' }}>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem', alignItems: 'baseline', justifyContent: 'space-between' }}>
        <h3 style={{ margin: 0, fontSize: 'clamp(1.05rem, 3vw, 1.3rem)' }}>{run.design}</h3>
        <code style={{ fontSize: '0.75rem', opacity: 0.75 }}>{run.top} · {run.tiles} · {run.date}</code>
      </div>
      <p style={{ fontSize: '0.9rem', opacity: 0.85, margin: '0.5rem 0 0.4rem', lineHeight: 1.6 }}>{run.what}</p>
      <a href={run.repoUrl} target="_blank" rel="noopener noreferrer" style={{ fontSize: '0.8rem' }}>{run.repo}</a>

      <div style={{ margin: '1rem 0 0' }}>
        {run.checks.map((k) => (
          <div key={k.name} style={{ borderTop: '1px solid var(--border)', padding: '0.6rem 0' }}>
            <div style={{ display: 'flex', gap: '0.6rem', alignItems: 'baseline' }}>
              <span style={{ color: k.status === 'PASS' ? 'var(--accent)' : '#ff6b6b', fontSize: '0.72rem', fontWeight: 700, letterSpacing: '0.08em', minWidth: '3.2em' }}>
                {k.status}
              </span>
              <strong style={{ fontSize: '0.88rem' }}>{k.name}</strong>
            </div>
            <p style={{ fontSize: '0.85rem', opacity: 0.85, margin: '0.3rem 0 0.35rem', lineHeight: 1.55 }}>{k.detail}</p>
            <code style={{ fontSize: '0.72rem', opacity: 0.6, display: 'block', overflowX: 'auto', whiteSpace: 'pre' }}>{k.command}</code>
          </div>
        ))}
      </div>

      {/* The result page is the thing worth sending to a reviewer, so the card
          has to lead there. It existed and nothing linked to it. */}
      <p style={{ fontSize: '0.82rem', margin: '0.9rem 0 0' }}>
        <a href={`/r/${run.slug}/`}>{lang === 'ru' ? 'Открыть страницу результата' : 'Open the result page'} →</a>
      </p>
      {run.found && (
        <div style={{ borderLeft: '2px solid var(--accent)', paddingLeft: '0.9rem', marginTop: '1rem' }}>
          <div style={{ fontSize: '0.72rem', letterSpacing: '0.1em', textTransform: 'uppercase', opacity: 0.7, marginBottom: '0.35rem' }}>{foundLabel}</div>
          <p style={{ fontSize: '0.88rem', lineHeight: 1.6, margin: 0 }}>{run.found}</p>
        </div>
      )}
      {failed === 0 && !run.found && (
        <p style={{ fontSize: '0.82rem', opacity: 0.6, margin: '0.8rem 0 0' }}>Nothing surfaced. That is a result too.</p>
      )}
      {/* The stamp, not a footnote: which commit, which tool build, which day.
          Without it a card is a claim; with it a reader can go and repeat it. */}
      <p style={{ fontSize: '0.72rem', opacity: 0.55, margin: '0.9rem 0 0', lineHeight: 1.6, borderTop: '1px solid var(--border)', paddingTop: '0.6rem' }}>
        {run.repo.split(' · ')[0]}{PROVENANCE.commits[run.origin] ? ` @ ${PROVENANCE.commits[run.origin]}` : ''} · {PROVENANCE.ranAt} ·{' '}
        {PROVENANCE.yosys} · {PROVENANCE.iverilog}
      </p>
    </div>
  )
}

export default function CaseStudies() {
  const { lang } = useI18n()
  const c = lang === 'ru' ? RU : EN
  usePageMeta(
    lang === 'ru' ? 'Работы' : 'Case studies',
    'Verification runs on other people’s RTL: what was checked, what it surfaced, and the numbers measured on a live Artix-7.',
  )

  return (
    <main>
      <QuantumBackground />
      <Navigation />

      <section id="cases" style={{ maxWidth: '900px', alignItems: 'stretch' }}>
        <div className="radial-glow" style={{ opacity: 0.2, background: 'radial-gradient(circle at center, rgba(0, 255, 136, 0.08) 0%, transparent 60%)' }} />

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7 }}
          style={{ marginBottom: '2rem' }}
        >
          <p style={{ color: 'var(--accent)', letterSpacing: '0.14em', textTransform: 'uppercase', fontSize: '0.75rem', margin: '0 0 0.75rem' }}>
            {c.eyebrow}
          </p>
          <h1 style={{ fontSize: 'clamp(1.9rem, 5.5vw, 2.8rem)', margin: '0 0 1rem', lineHeight: 1.15 }}>
            {c.h1}
          </h1>
          <p style={{ fontSize: 'clamp(0.95rem, 2.5vw, 1.1rem)', lineHeight: 1.65, margin: 0, maxWidth: '62ch', marginLeft: 'auto', marginRight: 'auto' }}>
            {c.lede}
          </p>
        </motion.div>

        <div style={{ width: '100%', marginBottom: '2.5rem' }}>
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '0.6rem' }}>{c.runsTitle}</h2>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.88, maxWidth: '62ch', margin: '0 auto 1.4rem' }}>{c.runsLede}</p>
          {RUNS.map((r) => (
            <RunCard key={r.id} run={r} foundLabel={c.found} lang={lang} />
          ))}

          <div className="premium-card" style={{ textAlign: 'left' }}>
            <h3 style={{ marginTop: 0, fontSize: 'clamp(1rem, 3vw, 1.25rem)' }}>{c.limitsTitle}</h3>
            <ul style={{ textAlign: 'left', paddingLeft: '1.1rem', margin: 0 }}>
              {(lang === 'ru' ? LIMITS_RU : LIMITS_EN).map((l) => (
                <li key={l} style={{ fontSize: '0.88rem', lineHeight: 1.6, marginBottom: '0.5rem', opacity: 0.9 }}>{l}</li>
              ))}
            </ul>
          </div>
        </div>

        <div style={{ width: '100%', marginBottom: '2.5rem' }}>
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '0.6rem' }}>{c.thirdTitle}</h2>
          <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.88, maxWidth: '64ch', margin: '0 auto 1.4rem' }}>{c.thirdLede}</p>
          <div className="premium-card" style={{ textAlign: 'left', marginBottom: '1.2rem', borderLeft: '2px solid var(--accent)' }}>
            <h3 style={{ marginTop: 0, fontSize: 'clamp(1rem, 2.8vw, 1.2rem)' }}>{c.scoreTitle}</h3>
            <p style={{ fontSize: '0.9rem', lineHeight: 1.62, margin: 0 }}>{c.scoreBody}</p>
          </div>
          {THIRD_PARTY_RUNS.map((r) => (
            <RunCard key={r.id} run={r} foundLabel={c.found} lang={lang} />
          ))}
        </div>

        <div className="premium-card" style={{ textAlign: 'left', width: '100%', marginBottom: '2.5rem' }}>
          <h2 style={{ fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)', marginTop: 0, marginBottom: '0.9rem' }}>{c.svcTitle}</h2>
          <div style={{ display: 'grid', gap: '1rem', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))' }}>
            <div>
              <h3 style={{ fontSize: '0.95rem', margin: '0 0 0.4rem', color: 'var(--accent)' }}>{c.svcOpen}</h3>
              <p style={{ fontSize: '0.87rem', lineHeight: 1.6, margin: 0, opacity: 0.9 }}>{c.svcOpenBody}</p>
            </div>
            <div>
              <h3 style={{ fontSize: '0.95rem', margin: '0 0 0.4rem' }}>{c.svcPrivate}</h3>
              <p style={{ fontSize: '0.87rem', lineHeight: 1.6, margin: 0, opacity: 0.9 }}>{c.svcPrivateBody}</p>
            </div>
          </div>
          <p style={{ fontSize: '0.87rem', lineHeight: 1.6, opacity: 0.85, margin: '1rem 0 1.2rem' }}>{c.svcHow}</p>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.7rem' }}>
            <a href={CONTACT.requestUrl} target="_blank" rel="noopener noreferrer" className="btn" style={{ padding: '12px 26px', fontSize: '0.88rem' }}>
              {c.svcCta}
            </a>
            <a href={CONTACT.sampleReport} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '12px 26px', fontSize: '0.88rem' }}>
              {c.ctaSample}
            </a>
          </div>
        </div>

        {CASES.length === 0 ? (
          <motion.div
            className="premium-card"
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6 }}
          >
            <h2 style={{ fontSize: 'clamp(1.2rem, 3.5vw, 1.6rem)', marginTop: 0, marginBottom: '0.8rem' }}>{c.emptyTitle}</h2>
            <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.9, maxWidth: '58ch', margin: '0 auto 0.9rem' }}>
              {c.emptyBody}
            </p>
            <p style={{ fontSize: '0.95rem', lineHeight: 1.65, opacity: 0.9, maxWidth: '58ch', margin: '0 auto 1.4rem' }}>
              {c.emptyCta}
            </p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.75rem', justifyContent: 'center' }}>
              <a href={CONTACT.sampleReport} target="_blank" rel="noopener noreferrer" className="btn" style={{ padding: '12px 28px', fontSize: '0.9rem' }}>
                {c.ctaSample}
              </a>
              <a href={mailto('Hardware verification request')} className="btn secondary" style={{ padding: '12px 28px', fontSize: '0.9rem' }}>
                {c.ctaRequest}
              </a>
            </div>
          </motion.div>
        ) : (
          <div style={{ display: 'grid', gap: '1.25rem' }}>
            {CASES.map((s) => (
              <motion.article
                key={s.client}
                className="premium-card"
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.6 }}
                style={{ padding: '1.75rem', textAlign: 'left' }}
              >
                <h2 style={{ fontSize: '1.2rem', margin: '0 0 0.9rem', color: 'var(--accent)' }}>{s.client}</h2>

                <p style={{ fontSize: '0.78rem', letterSpacing: '0.12em', textTransform: 'uppercase', opacity: 0.6, margin: '0 0 0.25rem' }}>{c.design}</p>
                <p style={{ fontSize: '0.94rem', lineHeight: 1.6, margin: '0 0 1rem', opacity: 0.9 }}>{s.design}</p>

                <p style={{ fontSize: '0.78rem', letterSpacing: '0.12em', textTransform: 'uppercase', opacity: 0.6, margin: '0 0 0.25rem' }}>{c.found}</p>
                <p style={{ fontSize: '0.94rem', lineHeight: 1.6, margin: '0 0 1rem', opacity: 0.9 }}>{s.found}</p>

                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: '0.9rem', margin: '0 0 1rem' }}>
                  {s.measured.map((m) => (
                    <div key={m.label}>
                      <p style={{ fontSize: '1.15rem', fontWeight: 700, color: 'var(--accent)', margin: 0, fontVariantNumeric: 'tabular-nums' }}>{m.value}</p>
                      <p style={{ fontSize: '0.82rem', margin: 0, opacity: 0.7 }}>{m.label}</p>
                    </div>
                  ))}
                  <div>
                    <p style={{ fontSize: '1.15rem', fontWeight: 700, color: 'var(--accent)', margin: 0 }}>{s.turnaround}</p>
                    <p style={{ fontSize: '0.82rem', margin: 0, opacity: 0.7 }}>{c.turnaround}</p>
                  </div>
                </div>

                {s.quote && (
                  <blockquote style={{ borderLeft: '2px solid var(--accent)', paddingLeft: '1rem', margin: '0 0 1rem' }}>
                    <p style={{ fontSize: '0.96rem', lineHeight: 1.6, margin: '0 0 0.35rem', fontStyle: 'italic' }}>{s.quote.text}</p>
                    <footer style={{ fontSize: '0.85rem', opacity: 0.7 }}>{s.quote.who}</footer>
                  </blockquote>
                )}

                {s.reportUrl && (
                  <a href={s.reportUrl} target="_blank" rel="noopener noreferrer" className="btn secondary" style={{ padding: '9px 20px', fontSize: '0.8rem' }}>
                    {c.ctaSample}
                  </a>
                )}
              </motion.article>
            ))}
          </div>
        )}
      </section>

      <Footer />
    </main>
  )
}
