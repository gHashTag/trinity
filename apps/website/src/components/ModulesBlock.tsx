import { useI18n } from '../i18n/context'
import { MODULES } from '../lib/queenModules'
import { SPEC_LAYERS, isSpecLayer } from './queenHud'
import './ModulesBlock.css'

// A compact index of the modules: one card each, linking to its tab. Not on the
// homepage any more — every module has a block of its own there — but kept
// because the data it reads now lives in lib/queenModules and this is the one
// place that shows all of them at a glance.
//
// It is drawn in the shell's own shape, which is no longer a flat list of
// fourteen. Nine are buttons on the rail; the other five — SKILLS, CRONS,
// AGENTS, TOOLS, FUNCTIONS — are rungs of the ladder inside SPECS, because each
// is a catalogue generated from .t27 specs and each names the one below it. A
// reader who scrolled past fourteen equal cards and then opened a rail of nine
// was reading a map of a shell that no longer existed.
//
// The two groups are `MODULES.filter` of a predicate and of its negation, so
// they are a partition by construction: every module is on exactly one, and a
// new one lands in its group without a second list to remember.

/** A module that is now reached inside SPECS rather than from the rail. */
const isLadderRung = (tab: string) => isSpecLayer(tab) && tab !== 'specs'

const RAIL_MODULES = MODULES.filter((m) => !isLadderRung(m.tab))
// Sorted into the ladder's own order, which is not the order of their keys:
// TOOLS is the fifth layer and FUNCTIONS the sixth, while t comes after 0.
const rung = (tab: string) => (SPEC_LAYERS as readonly string[]).indexOf(tab)
const LADDER_MODULES = MODULES.filter((m) => isLadderRung(m.tab)).sort((a, b) => rung(a.tab) - rung(b.tab))

// Every count is read, never a word typed here: the eyebrow once said "EIGHT"
// while the title said "ten" and the rail showed ten.
const N = MODULES.length
const RAIL_N = RAIL_MODULES.length
const LADDER_N = LADDER_MODULES.length
const COPY = {
  en: {
    eyebrow: `QUEEN / ${N} MODULES`,
    title: `One screen, ${N} ways to read it`,
    lede: `The Queen is a single-page module: the 3D map is the ground and every panel floats on it. These ${N} are what that ground can be read as — each one opens on the same map, in the same shell, from the key beside it. ${RAIL_N} are buttons down the left edge; the other ${LADDER_N} are rungs of one ladder inside SPECS, where every catalogue generated from a spec now lives together.`,
    railHead: `On the rail · ${RAIL_N}`,
    ladderHead: `Inside SPECS, on the ladder · ${LADDER_N}`,
    ladderNote:
      'Specs, skills, crons, agents, tools and functions are six layers of one thing: each is generated from .t27 and each names the one below it. They open on the same keys as before, one step inside SPECS.',
    open: 'Open',
    all: 'Open the shell →',
  },
  ru: {
    eyebrow: `КОРОЛЕВА / ${N} МОДУЛЕЙ`,
    title: `Один экран и ${N} способов его прочитать`,
    lede: `Королева — одностраничный модуль: 3D-карта здесь основание, а каждая панель плавает над ним. Эти ${N} — то, чем это основание можно прочитать; любой открывается на той же карте, в том же шелле, по клавише рядом с ним. ${RAIL_N} — кнопки вдоль левого края, остальные ${LADDER_N} — ступени одной лестницы внутри СПЕК, где теперь лежат вместе все каталоги, порождённые из спек.`,
    railHead: `На панели · ${RAIL_N}`,
    ladderHead: `Внутри СПЕК, на лестнице · ${LADDER_N}`,
    ladderNote:
      'Спеки, скиллы, кроны, агенты, инструменты и функции — шесть слоёв одного: каждый порождается из .t27 и каждый называет следующий. Клавиши прежние, просто на шаг внутрь СПЕК.',
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

        <a className="modules-block-all" href="#/queen">
          {t.all}
        </a>
      </div>
    </section>
  )
}
