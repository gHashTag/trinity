import { useI18n } from '../i18n/context'
import './ModulesBlock.css'

// The six modules of the Queen's HUD, presented on the homepage.
//
// Each card is the module's own glyph, its own number (the key that opens it in
// the shell) and its own one-line hint — the same words the rail uses, so the
// landing and the HUD do not describe the same thing differently. The paragraph
// under each says what the view actually shows, checked against the view; the
// link opens that tab, which is why the shell reads `?tab=` on mount.
const MODULES = [
  {
    tab: 'comb',
    key: '1',
    glyph: '▽',
    en: {
      name: 'COMB',
      hint: 'The board as a field of marks',
      body: 'The shared map. Every gold cell is a .t27 spec, every red one a GitHub issue that pays for it, and the gold line between two cells is the same spec in the shared core and in the repository it came from. Click a cell to read the spec itself over the map.',
    },
    ru: {
      name: 'СОТЫ',
      hint: 'Доска как поле меток',
      body: 'Общая карта. Каждая золотая сота — спека .t27, каждая красная — GitHub issue, которая за неё платит, а золотая линия между сотами — одна и та же спека в общем ядре и в репозитории-источнике. Клик по соте открывает саму спеку поверх карты.',
    },
  },
  {
    tab: 'specs',
    key: '2',
    glyph: '⬡',
    en: {
      name: 'SPECS',
      hint: 'The corpus she is generated from',
      body: 'The Spec Explorer, embedded whole: search the corpus, read a spec, and watch it become tokens, an AST, types, HIR, and five target languages — Zig, Verilog, C, Rust and a chip. Editing here is a draft, not an accepted spec.',
    },
    ru: {
      name: 'СПЕКИ',
      hint: 'Корпус, из которого она порождена',
      body: 'Обозреватель спек целиком: поиск по корпусу, чтение спеки и её превращение в токены, AST, типы, HIR и пять целевых языков — Zig, Verilog, C, Rust и чип. Правка здесь — черновик, а не принятая спека.',
    },
  },
  {
    tab: 'kanban',
    key: '3',
    glyph: '▦',
    en: {
      name: 'KANBAN',
      hint: 'Operational columns',
      body: 'The board as six columns — backlog, blocked, running, in review, done, dropped — with the issue cards themselves, each carrying its number and how many acceptance criteria it states.',
    },
    ru: {
      name: 'КАНБАН',
      hint: 'Операционные колонки',
      body: 'Доска шестью колонками — бэклог, заблокировано, в работе, на ревью, готово, отложено — с самими карточками задач: номер и сколько критериев приёмки в ней заявлено.',
    },
  },
  {
    tab: 'map',
    key: '4',
    glyph: '⌘',
    en: {
      name: 'MISSION MAP',
      hint: 'Strategic lifecycle sectors',
      body: 'The same six sectors read as territory rather than as a queue: what each holds, what share of the board it is, and which of them the bees are working in now.',
    },
    ru: {
      name: 'КАРТА МИССИЙ',
      hint: 'Стратегические секторы жизненного цикла',
      body: 'Те же шесть секторов, прочитанные как территория, а не как очередь: что в каждом, какую долю доски он занимает и в каком из них сейчас работают пчёлы.',
    },
  },
  {
    tab: 'factory',
    key: '5',
    glyph: '⚙',
    en: {
      name: 'FACTORY',
      hint: 'Live engineering production',
      body: 'What is being built: the bee hangars and which are idle, the construction partials a spec has produced, the research detail behind them, and the hardware foundry with what it has actually programmed.',
    },
    ru: {
      name: 'ФАБРИКА',
      hint: 'Живое инженерное производство',
      body: 'Что строится: ангары пчёл и кто из них простаивает, частичные сборки, порождённые спекой, исследовательская деталь за ними и аппаратная литейная с тем, что она действительно прошила.',
    },
  },
  {
    tab: 'research',
    key: '6',
    glyph: '◈',
    en: {
      name: 'TECHNOLOGY TREE',
      hint: 'Canonical evidence graph',
      body: 'Research as a graph with prerequisites: what is seeded, what is locked behind what, and what is being researched now — with the evidence each node rests on, and nothing claimed that has none.',
    },
    ru: {
      name: 'ДЕРЕВО ТЕХНОЛОГИЙ',
      hint: 'Канонический граф свидетельств',
      body: 'Исследования как граф с предпосылками: что засеяно, что за чем закрыто и что исследуется сейчас — со свидетельством под каждым узлом, и без утверждений, под которыми его нет.',
    },
  },
] as const

const COPY = {
  en: {
    eyebrow: 'QUEEN / SIX MODULES',
    title: 'One screen, six ways to read it',
    lede: 'The Queen is a single-page module: the 3D map is the ground and every panel floats on it. These six are what that ground can be read as — each one opens on the same map, in the same shell, from the number beside it.',
    open: 'Open',
    all: 'Open the shell →',
  },
  ru: {
    eyebrow: 'КОРОЛЕВА / ШЕСТЬ МОДУЛЕЙ',
    title: 'Один экран и шесть способов его прочитать',
    lede: 'Королева — одностраничный модуль: 3D-карта здесь основание, а каждая панель плавает над ним. Эти шесть — то, чем это основание можно прочитать; любой открывается на той же карте, в том же шелле, по цифре рядом с ним.',
    open: 'Открыть',
    all: 'Открыть шелл →',
  },
} as const

export default function ModulesBlock() {
  const { lang } = useI18n()
  const key = lang === 'ru' ? 'ru' : 'en'
  const t = COPY[key]

  return (
    <section className="modules-block" id="modules" aria-labelledby="modules-title">
      <div className="modules-block-inner">
        <header className="modules-block-head">
          <span className="modules-block-eyebrow">{t.eyebrow}</span>
          <h2 id="modules-title">{t.title}</h2>
          <p>{t.lede}</p>
        </header>

        <ol className="modules-block-grid">
          {MODULES.map((module) => {
            const m = module[key]
            return (
              <li key={module.tab}>
                <a className="modules-card" href={`#/queen?tab=${module.tab}`}>
                  <span className="modules-card-mark">
                    <i aria-hidden="true">{module.glyph}</i>
                    <b aria-hidden="true">{module.key}</b>
                  </span>
                  <strong>{m.name}</strong>
                  <small>{m.hint}</small>
                  <p>{m.body}</p>
                  <span className="modules-card-open">{t.open} →</span>
                </a>
              </li>
            )
          })}
        </ol>

        <a className="modules-block-all" href="#/queen">
          {t.all}
        </a>
      </div>
    </section>
  )
}
