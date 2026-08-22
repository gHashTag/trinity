"use client";
import { motion } from 'framer-motion'
import { usePageMeta } from '../hooks/usePageMeta'
import { useI18n } from '../i18n/context'
import Navigation from '../components/Navigation'
import Footer from '../components/Footer'
import QuantumBackground from '../components/QuantumBackground'

/**
 * Golden Foundry — платный клуб разработчиков на кремнии.
 *
 * Страница держит канон обложек корпуса: матовый чёрный, ЗОЛОТО только на
 * имени клуба, всё остальное кремово-серебряное, барочная антиква. Тот же код,
 * что в рилсах блога (TrinityBlogReel), — чтобы ролик, страница и обложка
 * читались как одно издание.
 */

const GOLD = '#C9A24B'
const CREAM = '#D8CDB0'

const CONTACT = { email: 'admin@t27.ai', telegram: 'https://t.me/neuro_blogger_bot' }

/**
 * УСЛОВИЯ НЕ ПРИДУМАНЫ И НЕ ПОДТВЕРЖДЕНЫ.
 *
 * Цены и наполнение ниже — ЧЕРНОВИК, согласованный по логике с курсом
 * (/course: $149 / $249 / $599). Пока владелец не подтвердил суммы, страница
 * не должна уходить в прод: продавать вход по выдуманной цене — ровно та же
 * ошибка, что писать в блоге неизмеренное число.
 */
const DRAFT_TERMS = true

const TIERS = [
  {
    name: 'Подмастерье',
    nameEn: 'Apprentice',
    price: '$29 / мес',
    priceEn: '$29 / mo',
    body: 'Закрытый канал, разборы замеров, доступ к KAT-векторам и репозиториям до публикации.',
    bodyEn: 'Private channel, measurement teardowns, KAT vector sets and repositories before they go public.',
  },
  {
    name: 'Мастер',
    nameEn: 'Journeyman',
    price: '$79 / мес',
    priceEn: '$79 / mo',
    body: 'Всё выше плюс удалённые прогоны на моих платах Artix-7 и разбор вашего RTL раз в месяц.',
    bodyEn: 'Everything above, plus remote runs on my Artix-7 boards and a monthly teardown of your own RTL.',
  },
  {
    name: 'Литейщик',
    nameEn: 'Founder',
    price: '$249 / мес',
    priceEn: '$249 / mo',
    body: 'Всё выше плюс сопровождение вашего дизайна до тейпаута и право на совместную публикацию замеров.',
    bodyEn: 'Everything above, plus your design walked to tape-out and the right to co-publish the measurements.',
  },
]

/** Двуязычно: смешанная страница читается как недоделка. */
const INSIDE = [
  {
    ru: ['Разбор чужих замеров', 'Каждую неделю берём один чужой бенчмарк и проверяем, выдерживает ли он собственную методику.'],
    en: ['Teardown of other people’s numbers', 'Each week we take one published benchmark and check whether it survives its own methodology.'],
  },
  {
    ru: ['Свой стенд', 'Удалённый доступ к живым платам: присылаете RTL — получаете измерение, а не симуляцию.'],
    en: ['A bench of your own', 'Remote access to live boards: send RTL, get a measurement rather than a simulation.'],
  },
  {
    ru: ['Право первым проверить', 'Метод и векторы попадают в клуб раньше публикации в блоге — вместе с тем, что ещё не сошлось.'],
    en: ['First right to check', 'Methods and vectors reach the club before the blog — including the parts that do not yet agree.'],
  },
  {
    ru: ['Открытый поток', 'Vivado не нужен: yosys, nextpnr-xilinx, prjxray, openFPGALoader. Всё, что делаем, вы можете повторить.'],
    en: ['An open flow', 'No Vivado: yosys, nextpnr-xilinx, prjxray, openFPGALoader. Everything we do, you can repeat.'],
  },
]

/** Названо прямо: покупатель всё равно спросит, а страница без этого читается как реклама. */
const NOT_THIS = {
  ru: [
    'Это не курс. Курс отдельно, на /course, и в клубе его не выдают.',
    'Это не гарантия тейпаута: кремний зависит от шаттла, а не от подписки.',
    'Это не чат «вопрос — ответ»: разбор идёт по замерам, которые вы приносите.',
  ],
  en: [
    'This is not the course. The course lives at /course and is not bundled here.',
    'This is not a tape-out guarantee: silicon depends on a shuttle, not a subscription.',
    'This is not a Q&A chat: the work is driven by measurements you bring.',
  ],
}

const RU = {
  eyebrow: 'Клуб разработчиков на кремнии',
  h1: 'Золотая Литейная',
  lede: 'Закрытый круг тех, кто проверяет свои числа на живом кремнии. Внутри — разбор замеров, доступ к стенду и право первым увидеть метод, который ещё не опубликован.',
  cta: 'Занять место',
  ctaAlt: 'Сначала посмотреть блог',
  seatNote: 'Набор идёт волнами: беру столько людей, скольким успеваю разобрать RTL лично.',
  insideTitle: 'Что внутри',
  tiersTitle: 'Уровни',
  notTitle: 'Чем это не является',
  whoTitle: 'Кому подойдёт',
  draftNote: 'Условия уточняются: суммы ниже — черновик, окончательные подтверждаются перед открытием набора.',
}

const EN = {
  eyebrow: 'A club for people who build on silicon',
  h1: 'Golden Foundry',
  lede: 'A closed circle of people who check their own numbers on live silicon. Inside: measurement teardowns, bench access, and first sight of methods before they are published.',
  cta: 'Take a seat',
  ctaAlt: 'Read the blog first',
  seatNote: 'Intake runs in waves: I take as many people as I can personally read RTL for.',
  insideTitle: 'What is inside',
  tiersTitle: 'Tiers',
  notTitle: 'What this is not',
  whoTitle: 'Who it fits',
  draftNote: 'Terms are being finalised: the figures below are a draft and will be confirmed before intake opens.',
}

const WHO = [
  {
    ru: ['Инженеры ML', 'Знаете модели, но железо до сих пор ощущается чужой территорией.'],
    en: ['ML engineers', 'You know the models; hardware still feels like someone else’s country.'],
  },
  {
    ru: ['Разработчики RTL', 'Хотите, чтобы ваши цифры кто-то проверил враждебно, а не похвалил.'],
    en: ['RTL developers', 'You want your numbers attacked, not applauded.'],
  },
  {
    ru: ['Участники Tiny Tapeout', 'Нужен путь от спецификации к проверенному RTL и шаттлу без угадывания.'],
    en: ['Tiny Tapeout participants', 'You want the path from spec to verified RTL to a shuttle, without guessing.'],
  },
]

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
      <main style={{ position: 'relative', zIndex: 1, maxWidth: 980, margin: '0 auto', padding: '7rem 1.25rem 4rem' }}>
        {/* Герой: имя клуба — единственное золото на странице */}
        <motion.div initial={{ opacity: 0, y: 24 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.7 }}>
          <div style={{ fontSize: '0.8rem', letterSpacing: '0.35em', textTransform: 'uppercase', color: CREAM, opacity: 0.75 }}>
            {c.eyebrow}
          </div>
          <h1
            style={{
              fontFamily: '"Playfair Display", Georgia, serif',
              fontStyle: 'italic',
              fontWeight: 900,
              fontSize: 'clamp(2.6rem, 9vw, 5rem)',
              lineHeight: 1.05,
              color: GOLD,
              margin: '0.5rem 0 0.25rem',
            }}
          >
            {c.h1}
          </h1>
          <div style={{ width: 180, height: 1, background: CREAM, opacity: 0.5, margin: '1.25rem 0' }} />
          <p style={{ fontSize: '1.05rem', lineHeight: 1.7, color: CREAM, opacity: 0.92, maxWidth: 680 }}>{c.lede}</p>

          <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap', marginTop: '1.75rem' }}>
            <motion.a
              whileHover={{ scale: 1.02 }}
              href={CONTACT.telegram}
              style={{
                border: `1px solid ${GOLD}`, color: GOLD, padding: '0.85rem 2rem',
                textDecoration: 'none', letterSpacing: '0.12em', textTransform: 'uppercase', fontSize: '0.9rem',
              }}
            >
              {c.cta}
            </motion.a>
            <motion.a
              whileHover={{ scale: 1.02 }}
              href="#/blog"
              style={{
                border: `1px solid ${CREAM}55`, color: CREAM, padding: '0.85rem 2rem',
                textDecoration: 'none', letterSpacing: '0.12em', textTransform: 'uppercase', fontSize: '0.9rem',
              }}
            >
              {c.ctaAlt}
            </motion.a>
          </div>
          <p style={{ fontSize: '0.85rem', opacity: 0.7, marginTop: '1rem', color: CREAM }}>{c.seatNote}</p>
        </motion.div>

        {/* Что внутри */}
        <Section title={c.insideTitle}>
          {INSIDE.map(item => {
            const [t, b] = ru ? item.ru : item.en
            return (
            <div key={t} style={{ borderTop: `1px solid ${CREAM}22`, padding: '1.1rem 0' }}>
              <div style={{ color: CREAM, fontWeight: 600, marginBottom: '0.3rem' }}>{t}</div>
              <div style={{ color: CREAM, opacity: 0.8, fontSize: '0.95rem', lineHeight: 1.6 }}>{b}</div>
            </div>
          )})}
        </Section>

        {/* Уровни */}
        <Section title={c.tiersTitle}>
          {DRAFT_TERMS ? (
            <p style={{ color: GOLD, opacity: 0.9, fontSize: '0.9rem', marginTop: 0 }}>{c.draftNote}</p>
          ) : null}
          <div style={{ display: 'grid', gap: '1rem', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))' }}>
            {TIERS.map(t => (
              <div key={t.name} style={{ border: `1px solid ${CREAM}33`, padding: '1.5rem' }}>
                <div style={{ color: CREAM, letterSpacing: '0.18em', textTransform: 'uppercase', fontSize: '0.75rem', opacity: 0.75 }}>
                  {ru ? t.name : t.nameEn}
                </div>
                <div style={{ fontFamily: '"Playfair Display", Georgia, serif', fontSize: '1.8rem', color: CREAM, margin: '0.5rem 0 0.75rem' }}>
                  {ru ? t.price : t.priceEn}
                </div>
                <div style={{ color: CREAM, opacity: 0.82, fontSize: '0.92rem', lineHeight: 1.6 }}>{ru ? t.body : t.bodyEn}</div>
              </div>
            ))}
          </div>
        </Section>

        {/* Кому подойдёт */}
        <Section title={c.whoTitle}>
          {WHO.map(item => {
            const [t, b] = ru ? item.ru : item.en
            return (
            <div key={t} style={{ borderTop: `1px solid ${CREAM}22`, padding: '1.1rem 0' }}>
              <div style={{ color: CREAM, fontWeight: 600, marginBottom: '0.3rem' }}>{t}</div>
              <div style={{ color: CREAM, opacity: 0.8, fontSize: '0.95rem', lineHeight: 1.6 }}>{b}</div>
            </div>
          )})}
        </Section>

        {/* Чем это не является — честность продаёт лучше обещаний */}
        <Section title={c.notTitle}>
          <ul style={{ margin: 0, paddingLeft: '1.1rem', color: CREAM, opacity: 0.85, lineHeight: 1.7 }}>
            {(ru ? NOT_THIS.ru : NOT_THIS.en).map(x => (
              <li key={x} style={{ marginBottom: '0.5rem' }}>{x}</li>
            ))}
          </ul>
        </Section>

        <div style={{ marginTop: '3rem', textAlign: 'center' }}>
          <a href={`mailto:${CONTACT.email}`} style={{ color: CREAM, opacity: 0.8, fontSize: '0.9rem' }}>
            {CONTACT.email}
          </a>
          <div style={{ marginTop: '1.5rem', letterSpacing: '0.3em', fontSize: '0.75rem', color: CREAM, opacity: 0.6 }}>
            TRINITY S3AI — {ru ? 'измерено, не заявлено' : 'measured, not claimed'}
          </div>
        </div>
      </main>
      <Footer />
    </>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <motion.section
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.6 }}
      style={{ marginTop: '3rem' }}
    >
      <h2
        style={{
          fontFamily: '"Playfair Display", Georgia, serif',
          fontSize: 'clamp(1.3rem, 3.5vw, 1.7rem)',
          color: CREAM,
          marginBottom: '1rem',
        }}
      >
        {title}
      </h2>
      {children}
    </motion.section>
  )
}
