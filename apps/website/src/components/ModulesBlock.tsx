import { useI18n } from '../i18n/context'
import { MODULES } from '../lib/queenModules'
import { BOARD_VIEWS, RAIL_VIEWS, SPEC_LAYERS, isBoardView, isSpecLayer } from './queenHud'
import './ModulesBlock.css'

// A compact index of the modules: one card each, linking to its tab. Not on the
// homepage any more — every module has a block of its own there — but kept
// because the data it reads now lives in lib/queenModules and this is the one
// place that shows all of them at a glance.
//
// It is drawn in the shell's own shape, which is no longer a flat list of
// fourteen. Seven are buttons on the rail. Five — SKILLS, CRONS, AGENTS, TOOLS,
// FUNCTIONS — are rungs of the ladder inside SPECS, because each is a catalogue
// generated from .t27 specs and each names the one below it. Two — MISSION MAP
// and FACTORY — sit under KANBAN, because the three are three readings of the
// one board. A reader who scrolled past fourteen equal cards and then opened a
// rail of seven was reading a map of a shell that no longer existed.
//
// Which group a module is in is asked of the shell's own lists rather than
// restated here: RAIL_VIEWS already is HUD_VIEWS less whatever has been folded,
// so folding a view under another moves its card by itself. The three groups
// are `MODULES.filter` of predicates that partition by construction -- every
// module is in exactly one, and a new one lands in its group with no second
// list to remember.

/** On the rail: the shell's own list, so this cannot drift from the buttons. */
const isRailModule = (tab: string) => (RAIL_VIEWS as readonly string[]).includes(tab)
/** Folded into SPECS, and folded into KANBAN: the two families less their heads. */
const isLadderRung = (tab: string) => isSpecLayer(tab) && !isRailModule(tab)
const isBoardReading = (tab: string) => isBoardView(tab) && !isRailModule(tab)

const RAIL_MODULES = MODULES.filter((m) => isRailModule(m.tab))
// Sorted into each family's own order, which is not the order of their keys:
// TOOLS is the fifth layer and FUNCTIONS the sixth, while t comes after 0.
const order = (list: readonly string[]) => (tab: string) => list.indexOf(tab)
const rung = order(SPEC_LAYERS)
const seat = order(BOARD_VIEWS)
const LADDER_MODULES = MODULES.filter((m) => isLadderRung(m.tab)).sort((a, b) => rung(a.tab) - rung(b.tab))
const BOARD_MODULES = MODULES.filter((m) => isBoardReading(m.tab)).sort((a, b) => seat(a.tab) - seat(b.tab))

// Every count is read, never a word typed here: the eyebrow once said "EIGHT"
// while the title said "ten" and the rail showed ten.
const N = MODULES.length
const RAIL_N = RAIL_MODULES.length
const LADDER_N = LADDER_MODULES.length
const BOARD_N = BOARD_MODULES.length
const COPY = {
  en: {
    eyebrow: `QUEEN / ${N} MODULES`,
    title: `One screen, ${N} ways to read it`,
    lede: `The Queen is a single-page module: the 3D map is the ground and every panel floats on it. These ${N} are what that ground can be read as — each one opens on the same map, in the same shell, from the key beside it. ${RAIL_N} are buttons down the left edge; ${LADDER_N} are rungs of one ladder inside SPECS, where every catalogue generated from a spec lives together; the last ${BOARD_N} are the board's other two readings, under KANBAN.`,
    railHead: `On the rail · ${RAIL_N}`,
    ladderHead: `Inside SPECS, on the ladder · ${LADDER_N}`,
    ladderNote:
      'Specs, skills, crons, agents, tools and functions are six layers of one thing: each is generated from .t27 and each names the one below it. They open on the same keys as before, one step inside SPECS.',
    boardHead: `Inside KANBAN, on the board · ${BOARD_N}`,
    boardNote:
      'The kanban, the mission map and the factory read one board: the same issues as columns, as a map, and as what the swarm is building from them. Same keys, one step inside KANBAN.',
    open: 'Open',
    all: 'Open the shell →',
  },
  ru: {
    eyebrow: `КОРОЛЕВА / ${N} МОДУЛЕЙ`,
    title: `Один экран и ${N} способов его прочитать`,
    lede: `Королева — одностраничный модуль: 3D-карта здесь основание, а каждая панель плавает над ним. Эти ${N} — то, чем это основание можно прочитать; любой открывается на той же карте, в том же шелле, по клавише рядом с ним. ${RAIL_N} — кнопки вдоль левого края, ${LADDER_N} — ступени одной лестницы внутри СПЕК, где лежат вместе все каталоги, порождённые из спек, а последние ${BOARD_N} — два других прочтения доски, внутри КАНБАНА.`,
    railHead: `На панели · ${RAIL_N}`,
    ladderHead: `Внутри СПЕК, на лестнице · ${LADDER_N}`,
    ladderNote:
      'Спеки, скиллы, кроны, агенты, инструменты и функции — шесть слоёв одного: каждый порождается из .t27 и каждый называет следующий. Клавиши прежние, просто на шаг внутрь СПЕК.',
    boardHead: `Внутри КАНБАНА, на доске · ${BOARD_N}`,
    boardNote:
      'Канбан, карта миссий и фабрика читают одну доску: те же задачи — колонками, картой и тем, что рой из них строит. Клавиши прежние, просто на шаг внутрь КАНБАНА.',
    open: 'Открыть',
    all: 'Открыть шелл →',
  },
} as const

export default function ModulesBlock() {
  const { lang } = useI18n()
  const key = lang === 'ru' ? 'ru' : 'en'
  const t = COPY[key]

  // A list of modules, not MODULES itself: `as const` makes that a tuple of
  // fourteen, and a filtered group is never that tuple.
  const cards = (modules: readonly (typeof MODULES)[number][]) => (
    <ol className="modules-block-grid site-card-row">
      {modules.map((module) => {
        const m = module[key]
        return (
          <li key={module.tab}>
            <a className="modules-card site-card" href={`#/queen?tab=${module.tab}`}>
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
  )

  return (
    <section className="modules-block" id="modules" aria-labelledby="modules-title">
      <div className="modules-block-inner">
        <header className="modules-block-head">
          <span className="modules-block-eyebrow">{t.eyebrow}</span>
          <h2 id="modules-title">{t.title}</h2>
          <p>{t.lede}</p>
        </header>

        <h3 className="modules-block-group" id="modules-rail">
          {t.railHead}
        </h3>
        {cards(RAIL_MODULES)}

        <h3 className="modules-block-group" id="modules-ladder">
          {t.ladderHead}
        </h3>
        <p className="modules-block-group-note">{t.ladderNote}</p>
        {cards(LADDER_MODULES)}

        <h3 className="modules-block-group" id="modules-board">
          {t.boardHead}
        </h3>
        <p className="modules-block-group-note">{t.boardNote}</p>
        {cards(BOARD_MODULES)}

        <a className="modules-block-all" href="#/queen">
          {t.all}
        </a>
      </div>
    </section>
  )
}
