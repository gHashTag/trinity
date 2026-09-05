"use client";
import { motion } from 'framer-motion'
import { usePageMeta } from '../hooks/usePageMeta'
import { useI18n } from '../i18n/context'
import Navigation from '../components/Navigation'
import SelfServeRun from '../components/SelfServeRun'
import ExampleReport from '../components/ExampleReport'
import CommunityRuns from '../components/CommunityRuns'
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


const RU = {
  eyebrow: 'Работы',
  h1: 'Что показали чужие дизайны.',
  lede: 'Каждый прогон заканчивается отчётом: что проверялось, что нашлось и какие цифры сняты с платы. Здесь они собраны — с разрешения клиента и без правок в его пользу.',
  ctaSample: 'Образец отчёта',
  found: 'Что нашлось',
  servicePointer: 'Запустить эту проверку у себя — шесть строк в вашем репозитории, на вашем раннере, без загрузки исходников куда-либо.',
  serviceCta: 'Все четыре проверки',
  runsTitle: 'Прогоны на моих собственных дизайнах',
  thirdTitle: 'Прогоны на чужих дизайнах',
  thirdLede: 'Те же проверки, тот же день, публичные заявки Tiny Tapeout под открытой лицензией.',
  scoreTitle: 'Счёт, который я искал против себя',
  scoreBody: 'Я специально искал среди чужих дизайнов провал — чтобы витрина не читалась как подбор удачных случаев. Не нашёл: все пять объявляют source_files и собираются из объявленного. Неудобный результат оказался на моей стороне: из пяти моих дизайнов у двух список неполон (phi, gamma), а ещё двое не объявляют его вовсе (mini, holo) — и шаттл собирается именно по нему. Счёт был 5:1 не в мою пользу; все четыре починены 11 августа, и это видно в истории коммитов, а не только здесь.',
  runsLede: 'Прежде чем предлагать это другим, я прогнал через ту же машину пять своих чипов. Это доказывает, что харнесс работает, а не что мне кто-то доверяет: ниже пять чужих дизайнов, и вот они уже кое-что доказывают.',
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
  ctaSample: 'Sample report',
  found: 'What it surfaced',
  servicePointer: 'Run this check yourself — six lines in your repository, on your runner, with nothing uploaded anywhere.',
  serviceCta: 'All four checks',
  runsTitle: 'Runs on my own designs',
  thirdTitle: "Runs on other people's designs",
  thirdLede: 'The same checks, the same day, on public Tiny Tapeout submissions under an open licence.',
  scoreTitle: 'The count I went looking for against myself',
  scoreBody: 'I went looking for a failure among other people\u2019s designs, so the gallery would not read as a selection of happy cases. I did not find one: all five declare source_files and elaborate from what they declare. The uncomfortable result is on my side — of my five chips, two declare an incomplete list (phi, gamma) and two declare none at all (mini, holo), and a shuttle builds from exactly that list. The count was 5 to 1 against me; all four were fixed on 11 August, and that is visible in the commit history rather than only here.',
  runsLede: 'Before offering this to anyone else I put five of my own designs through the same machine. That proves the harness runs, not that anyone trusts it: five designs that are not mine are below, and those prove a little more.',
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
        <code style={{ fontSize: '0.82rem', opacity: 0.75 }}>{run.top} · {run.tiles} · {run.date}</code>
      </div>
      <p style={{ fontSize: '0.9rem', opacity: 0.85, margin: '0.5rem 0 0.4rem', lineHeight: 1.6 }}>{lang === 'ru' ? (run.whatRu ?? run.what) : run.what}</p>
      <a href={run.repoUrl} target="_blank" rel="noopener noreferrer" style={{ fontSize: '0.85rem' }}>{run.repo}</a>

      <div style={{ margin: '1rem 0 0' }}>
        {run.checks.map((k) => (
          <div key={k.name} style={{ borderTop: '1px solid var(--border)', padding: '0.6rem 0' }}>
            <div style={{ display: 'flex', gap: '0.6rem', alignItems: 'baseline' }}>
              <span style={{ color: k.status === 'PASS' ? 'var(--accent)' : '#ff6b6b', fontSize: '0.82rem', fontWeight: 700, letterSpacing: '0.08em', minWidth: '3.2em' }}>
                {k.status}
              </span>
              <strong style={{ fontSize: '0.88rem' }}>{k.name}</strong>
            </div>
            <p style={{ fontSize: '0.85rem', opacity: 0.85, margin: '0.3rem 0 0.35rem', lineHeight: 1.55 }}>{lang === 'ru' ? (k.detailRu ?? k.detail) : k.detail}</p>
            <code style={{ fontSize: '0.82rem', opacity: 0.6, display: 'block', overflowX: 'auto', whiteSpace: 'pre' }}>{k.command}</code>
          </div>
        ))}
      </div>

      {run.note && (
        <p style={{ fontSize: '0.82rem', lineHeight: 1.6, margin: '0.8rem 0 0', opacity: 0.8, borderLeft: '2px solid var(--muted)', paddingLeft: '0.7rem' }}>
          {lang === 'ru' ? (run.noteRu ?? run.note) : run.note}
        </p>
      )}
      {/* The result page is the thing worth sending to a reviewer, so the card
          has to lead there. It existed and nothing linked to it. */}
      <p style={{ fontSize: '0.82rem', margin: '0.9rem 0 0' }}>
        <a href={`/r/${run.slug}/`}>{lang === 'ru' ? 'Открыть страницу результата' : 'Open the result page'} →</a>
      </p>
      {run.found && (
        <div style={{ borderLeft: '2px solid var(--accent)', paddingLeft: '0.9rem', marginTop: '1rem' }}>
          <div style={{ fontSize: '0.82rem', letterSpacing: '0.1em', textTransform: 'uppercase', opacity: 0.7, marginBottom: '0.35rem' }}>{foundLabel}</div>
          <p style={{ fontSize: '0.88rem', lineHeight: 1.6, margin: 0 }}>{run.found}</p>
        </div>
      )}
      {failed === 0 && !run.found && (
        <p style={{ fontSize: '0.85rem', opacity: 0.65, margin: '0.8rem 0 0' }}>
          {lang === 'ru' ? 'Ничего не всплыло. Это тоже результат.' : 'Nothing surfaced. That is a result too.'}
        </p>
      )}
      {/* The stamp, not a footnote: which commit, which tool build, which day.
          Without it a card is a claim; with it a reader can go and repeat it. */}
      <p style={{ fontSize: '0.82rem', opacity: 0.55, margin: '0.9rem 0 0', lineHeight: 1.6, borderTop: '1px solid var(--border)', paddingTop: '0.6rem' }}>
        {run.repo.split(' · ')[0]}{PROVENANCE.commits[run.origin] ? ` @ ${PROVENANCE.commits[run.origin]}` : ''} · {PROVENANCE.ranAt} ·{' '}
        {PROVENANCE.yosys} · {PROVENANCE.iverilog}
      </p>
    </div>
  )
}

export default function CaseStudies() {
  const { lang } = useI18n()
  const c = lang === 'ru' ? RU : EN
  const all = [...RUNS, ...THIRD_PARTY_RUNS]
  const checksTotal = all.reduce((n, r) => n + r.checks.length, 0)
  const checksFailed = all.reduce((n, r) => n + r.checks.filter((k) => k.status !== 'PASS').length, 0)
  const stats: [string, string][] = lang === 'ru'
    ? [[String(all.length), 'дизайнов прогнано'], [`${checksTotal - checksFailed}/${checksTotal}`, 'проверок прошло'], [PROVENANCE.ranAt, 'день прогона']]
    : [[String(all.length), 'designs run'], [`${checksTotal - checksFailed}/${checksTotal}`, 'checks passed'], [PROVENANCE.ranAt, 'run on']]
  usePageMeta(
    lang === 'ru' ? 'Работы' : 'Case studies',
    'Verification runs on other people’s RTL: what was checked, what it surfaced, and the numbers measured on a live Artix-7.',
  )

  return (
    <main>
      <QuantumBackground />
      <Navigation />

      <section id="cases" className="subpage-layout" style={{ maxWidth: '900px', alignItems: 'stretch' }}>
        <div className="radial-glow" style={{ opacity: 0.2, background: 'radial-gradient(circle at center, rgba(0, 255, 136, 0.08) 0%, transparent 60%)' }} />

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7 }}
          style={{ marginBottom: '2rem' }}
        >
          <p style={{ color: 'var(--accent)', letterSpacing: '0.14em', textTransform: 'uppercase', fontSize: '0.82rem', margin: '0 0 0.75rem' }}>
            {c.eyebrow}
          </p>
          <h1 style={{ fontSize: 'clamp(1.9rem, 5.5vw, 2.8rem)', margin: '0 0 1rem', lineHeight: 1.15 }}>
            {c.h1}
          </h1>
          <p style={{ fontSize: 'clamp(0.95rem, 2.5vw, 1.1rem)', lineHeight: 1.65, margin: 0, maxWidth: '62ch', marginLeft: 'auto', marginRight: 'auto' }}>
            {c.lede}
          </p>
        </motion.div>

        {/* Итог сверху: на странице тринадцать тысяч пикселей карточек, и до этой
            строки объём проделанного нельзя было увидеть, не прокрутив всё. */}
        <div
          className="premium-card"
          style={{ display: 'flex', flexDirection: 'row', flexWrap: 'wrap', gap: '1rem 2.5rem', padding: '1.2rem 1.5rem', marginBottom: '2rem' }}
        >
          {stats.map(([n, label]) => (
            <div key={label} style={{ textAlign: 'left' }}>
              <div style={{ fontSize: '1.7rem', fontWeight: 700, color: 'var(--accent)', lineHeight: 1.1, fontVariantNumeric: 'tabular-nums' }}>{n}</div>
              <div style={{ fontSize: '0.85rem', opacity: 0.75 }}>{label}</div>
            </div>
          ))}
        </div>

        {/* One line to the service, then the runs.

            This page is titled after what other people's designs showed, and it
            used to open with three blocks about how to run the check -- the
            snippet, an example report, and who is using it -- so the runs it
            promises began two thirds of the way down a page of twenty-six
            thousand characters. Asked twice where the runs were, and both times
            they were there and buried. The service has its own page now, so
            here it is a pointer and the runs come first. */}
        <div style={{
          display: 'flex', flexWrap: 'wrap', gap: '0.6rem 1rem', alignItems: 'center',
          padding: '0.8rem 1rem', borderRadius: '10px', marginBottom: '2rem',
          background: 'rgba(0,255,136,0.05)', border: '1px solid rgba(0,255,136,0.18)',
        }}>
          <span style={{ fontSize: '0.9rem', lineHeight: 1.55 }}>{c.servicePointer}</span>
          <a href="#/start" className="btn" style={{ padding: '9px 20px', fontSize: '0.84rem' }}>
            {c.serviceCta}
          </a>
        </div>

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

        {/* Moved below the runs, and the empty-state that used to live here is
            gone. It rendered when a legacy CASES array was empty -- and that
            array is an empty literal in this file that has never held anything,
            because the runs above replaced the idea of hand-written case
            studies. So the page ended with a heading saying "empty for now, and
            honestly so" printed underneath ten published runs. Anybody who
            scrolled to the bottom, or skimmed the headings, read that the page
            had nothing on it. Twice I was asked where the runs were. */}
        <SelfServeRun />

        {/* Paste that, get this. Extracted from a real run rather than written,
            so it cannot drift from what the tool actually says. */}
        <ExampleReport />

        {/* Discovered, not curated: whatever GitHub says is true. */}
        <CommunityRuns />
      </section>

      <Footer />
    </main>
  )
}
