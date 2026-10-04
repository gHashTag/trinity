"use client";
import { motion } from 'framer-motion'
import { usePageMeta } from '../hooks/usePageMeta'
import { useI18n } from '../i18n/context'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import QuantumBackground from '../components/QuantumBackground'
import TerminalCast from '../components/TerminalCast'
import { X7_BOARD } from '../data/casts'
import { CLUB, clubPrice } from '../data/club'
import AgentShowcase from '../components/AgentShowcase'

/**
 * Golden Foundry — платный клуб разработчиков на кремнии.
 *
 * Визуально страница живёт в стиле ГЛАВНОЙ (index.css: Outfit, чёрный фон,
 * premium-card, .btn, акцент var(--accent), золото var(--golden) точечно) —
 * по прямому требованию владельца. Канон обложек остаётся идентикой РИЛСОВ
 * и обложек; здесь от него только одно правило: золото — только на имени
 * клуба (через var(--golden)).
 */

// Клубный бот — @t27ai_bot (выделен владельцем под клуб 2026-08-22)
const CONTACT = { email: 'admin@t27.ai', telegram: CLUB.telegram }

/**
 * Цена — владелец, 2026-10-03: все агенты по одной цене, подписка Telegram
 * Stars на максимуме (10000 ⭐ / 30 дней, data/club.ts); клуб — это профиль
 * агента-разработчика TRI DEV. Один уровень вместо трёх черновых.
 * Описание агента — только то, что делает `tri dev` (docs/docs/cli/dev.md):
 * одна задача GitHub — один сервис на Railway — один автономный агент
 * Claude Code. Ничего сверх этого не обещать.
 */
const INSIDE = [
  { ru: ['Агент TRI DEV', 'Автономный агент-разработчик на одной вашей задаче: от спеки до pull request, каждый шаг — комментарием в задаче.'], en: ['A TRI DEV agent', 'An autonomous developer agent on one of your issues: from spec to pull request, every step a comment on the issue.'] },
  { ru: ['Разбор чужих замеров', 'Каждую неделю берём один опубликованный бенчмарк и проверяем, выдерживает ли он собственную методику.'], en: ['Teardowns of published numbers', 'Each week we take one published benchmark and check whether it survives its own methodology.'] },
  { ru: ['Свой стенд', 'Удалённый доступ к живым платам: присылаете RTL — получаете измерение, а не симуляцию.'], en: ['A bench of your own', 'Remote access to live boards: send RTL, get a measurement rather than a simulation.'] },
  { ru: ['Право первым проверить', 'Методы и векторы попадают в клуб раньше блога — вместе с тем, что ещё не сошлось.'], en: ['First right to check', 'Methods and vectors reach the club before the blog — including the parts that do not yet agree.'] },
  { ru: ['Открытый поток', 'Vivado не нужен: yosys, nextpnr-xilinx, prjxray, openFPGALoader. Всё повторяемо.'], en: ['An open flow', 'No Vivado: yosys, nextpnr-xilinx, prjxray, openFPGALoader. Everything is repeatable.'] },
]

const NOT_THIS = {
  ru: [
    'Это не курс. Курс отдельно, на /course, и в клуб он не входит.',
    'Это не гарантия тейпаута: кремний зависит от шаттла, а не от подписки.',
    'Это не чат «вопрос — ответ»: работа идёт по замерам, которые вы приносите.',
    'Агент не сливает сам: каждое изменение приходит pull request’ом, решение за вами.',
  ],
  en: [
    'This is not the course. The course lives at /course and is not bundled here.',
    'This is not a tape-out guarantee: silicon depends on a shuttle, not a subscription.',
    'This is not a Q&A chat: the work is driven by measurements you bring.',
    'The agent does not merge on its own: every change arrives as a pull request, and the decision is yours.',
  ],
}

const WHO = [
  { ru: ['Инженеры ML', 'Знаете модели, но железо всё ещё чужая территория.'], en: ['ML engineers', 'You know the models; hardware still feels like foreign country.'] },
  { ru: ['Разработчики RTL', 'Хотите, чтобы ваши цифры атаковали, а не хвалили.'], en: ['RTL developers', 'You want your numbers attacked, not applauded.'] },
  { ru: ['Участники Tiny Tapeout', 'Нужен путь от спеки к проверенному RTL и шаттлу без угадывания.'], en: ['Tiny Tapeout participants', 'You want the path from spec to verified RTL to a shuttle, without guessing.'] },
]

const RU = {
  eyebrow: 'Закрытый клуб · набор волнами',
  h1pre: 'Клуб разработчиков на кремнии',
  lede: `Закрытый круг тех, кто проверяет свои числа на живом кремнии. ${clubPrice(true)}: свой агент-разработчик TRI DEV на вашей задаче, разбор замеров, доступ к стенду и право первым увидеть метод до публикации.`,
  cta: 'Вступить через Telegram',
  ctaAlt: 'Сначала блог',
  seatNote: 'Беру столько людей, скольким успеваю читать RTL лично. Оплата — в боте, картой или звёздами Telegram.',
  insideTitle: 'Что внутри',
  notTitle: 'Чем это не является',
  whoTitle: 'Кому подойдёт',
  join: 'Вступить',
}

const EN = {
  eyebrow: 'Private club · intake in waves',
  h1pre: 'A club for people who build on silicon',
  lede: `A closed circle of people who check their numbers on live silicon. ${clubPrice(false)}: your own TRI DEV developer agent on your issue, measurement teardowns, bench access, and first sight of methods before they are published.`,
  cta: 'Join via Telegram',
  ctaAlt: 'Read the blog first',
  seatNote: 'I take as many people as I can personally read RTL for. Payment in the bot — card or Telegram Stars.',
  insideTitle: 'What is inside',
  notTitle: 'What this is not',
  whoTitle: 'Who it fits',
  join: 'Join',
}

export default function Foundry() {
  const { lang } = useI18n()
  const ru = lang === 'ru'
  const c = ru ? RU : EN
  usePageMeta(
    ru ? 'Золотая Литейная — клуб разработчиков на кремнии' : 'Golden Foundry — a club for people who build on silicon',
    c.lede
  )

  return (
    <>
      <QuantumBackground />
      <Navigation />
      <main style={{ position: 'relative', zIndex: 1 }}>
        {/* HERO — как на главной: узкая колонка, eyebrow, крупный h1 */}
        <section className="section" style={{ paddingTop: '7rem' }}>
          <div className="section-inner narrow">
            <motion.div initial={{ opacity: 0, y: 24 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6 }}>
              <div style={{ fontSize: '0.8rem', letterSpacing: '0.25em', textTransform: 'uppercase', color: 'var(--muted)', marginBottom: '0.75rem' }}>
                {c.eyebrow}
              </div>
              <h1 style={{ fontSize: 'clamp(2.2rem, 7vw, 3.6rem)', lineHeight: 1.1, margin: 0 }}>
                {c.h1pre}
                <br />
                {/* Единственное золото страницы — имя клуба */}
                <span style={{ color: 'var(--golden)' }}>{ru ? 'Золотая Литейная' : 'Golden Foundry'}</span>
              </h1>
              <p style={{ fontSize: '1.05rem', lineHeight: 1.7, color: 'var(--muted)', maxWidth: 620, marginTop: '1.25rem' }}>
                {c.lede}
              </p>
              <div className="foundry-cta" style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap', justifyContent: 'center', marginTop: '1.75rem' }}>
                <a className="btn" href={CONTACT.telegram}>{c.cta}</a>
                <a className="btn secondary" href="#/blog">{c.ctaAlt}</a>
              </div>
              <p style={{ fontSize: '0.85rem', color: 'var(--muted)', marginTop: '1rem' }}>{c.seatNote}</p>
            </motion.div>
          </div>
        </section>

        {/* ЧТО ВНУТРИ — сетка premium-card, как секции главной */}
        <section className="section">
          <div className="section-inner">
            <h2 style={{ marginTop: 0 }}>{c.insideTitle}</h2>
            <div style={{ display: 'grid', gap: '1rem', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))' }}>
              {INSIDE.map(item => {
                const [t, b] = ru ? item.ru : item.en
                return (
                  <motion.div key={t} className="premium-card" initial={{ opacity: 0, y: 16 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ duration: 0.5 }}>
                    <h3 style={{ marginTop: 0, fontSize: '1.05rem' }}>{t}</h3>
                    <p style={{ margin: 0, color: 'var(--muted)', fontSize: '0.92rem', lineHeight: 1.6 }}>{b}</p>
                  </motion.div>
                )
              })}
            </div>
          </div>
        </section>

        {/* Как выглядит прогон на стенде: запись с платы, а не макет */}
        <section className="section">
          <div className="section-inner narrow">
            <h2 style={{ marginTop: 0 }}>{ru ? 'Как выглядит прогон на стенде' : 'What a bench run looks like'}</h2>
            <TerminalCast src={X7_BOARD.src} share={X7_BOARD.share} title={X7_BOARD.title} caption={ru ? X7_BOARD.caption.ru : X7_BOARD.caption.en} />
          </div>
        </section>

        <AgentShowcase ru={ru} featured="tridev" />

        {/* КОМУ ПОДОЙДЁТ */}
        <section className="section">
          <div className="section-inner">
            <h2 style={{ marginTop: 0 }}>{c.whoTitle}</h2>
            <div style={{ display: 'grid', gap: '1rem', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))' }}>
              {WHO.map(item => {
                const [t, b] = ru ? item.ru : item.en
                return (
                  <div key={t} className="premium-card compact">
                    <h3 style={{ marginTop: 0, fontSize: '1rem' }}>{t}</h3>
                    <p style={{ margin: 0, color: 'var(--muted)', fontSize: '0.9rem', lineHeight: 1.55 }}>{b}</p>
                  </div>
                )
              })}
            </div>
          </div>
        </section>

        {/* ЧЕМ ЭТО НЕ ЯВЛЯЕТСЯ — честность продаёт лучше обещаний */}
        <section className="section">
          <div className="section-inner narrow">
            <div className="premium-card">
              <h2 style={{ marginTop: 0, fontSize: '1.3rem' }}>{c.notTitle}</h2>
              <ul style={{ margin: 0, paddingLeft: '1.1rem', color: 'var(--muted)', lineHeight: 1.7, fontSize: '0.95rem' }}>
                {(ru ? NOT_THIS.ru : NOT_THIS.en).map(x => (
                  <li key={x} style={{ marginBottom: '0.4rem' }}>{x}</li>
                ))}
              </ul>
            </div>
            <p style={{ textAlign: 'center', marginTop: '2rem' }}>
              <a href={`mailto:${CONTACT.email}`} style={{ color: 'var(--muted)', fontSize: '0.9rem' }}>{CONTACT.email}</a>
            </p>
          </div>
        </section>
      </main>
      <Footer />
    </>
  )
}
