import { useI18n } from '../i18n/context'
import './PlayBlock.css'

// How a developer joins, in the four moves that actually exist.
//
// Nothing here is a mechanic waiting to be built: every step is a place on this
// site or in the repository, and the link goes to it. The board is where the
// work is named and its acceptance criteria are stated; the Explorer is where a
// spec is written and compiled by the real compiler; the pull request is the
// move; the review queue is where it lands. If a step is ever removed from the
// product, this block has to lose it too — a "how to play" that describes a
// game nobody can play is the worst thing a homepage can carry.
const REPO_ISSUES = 'https://github.com/gHashTag/trinity/issues'
const REPO_SPECS = 'https://github.com/gHashTag/trinity/tree/main/specs'

const COPY = {
  en: {
    eyebrow: 'HOW TO PLAY',
    title: 'The core is built by playing it',
    lede: 'Every cell on the map is a piece of the core, and the moves are the ordinary ones: take a task, write the spec that generates it, compile it, send it. There is no separate contribution process — this is the process.',
    steps: [
      {
        n: '01',
        name: 'Take a cell',
        body: 'Open the board and pick something in backlog. The card carries its issue number and how many acceptance criteria it states — that is the contract you are agreeing to.',
        link: '#/queen?tab=kanban',
        cta: 'Open the board',
      },
      {
        n: '02',
        name: 'Write the spec',
        body: 'The work is a .t27 spec, not the code it generates. Read a neighbouring one in the Explorer to see the shape: constants, a type, functions, a test and an invariant.',
        link: '#/specs',
        cta: 'Open the Explorer',
      },
      {
        n: '03',
        name: 'Compile it',
        body: 'The same Explorer runs the real compiler: tokens, an AST, types, HIR, then Zig, Verilog, C and Rust from the one source. If it does not compile, it is not a spec yet.',
        link: '#/queen?tab=specs',
        cta: 'Compile in the shell',
      },
      {
        n: '04',
        name: 'Send it',
        body: 'A pull request against the repository, referencing the issue. It lands in the review queue, where a spec match does not close an issue on its own — generation, tests and review are required.',
        link: REPO_ISSUES,
        cta: 'Open the issues',
        external: true,
      },
    ],
    closing: 'The corpus is public and so is every rule it is judged by.',
    closingCta: 'Read the specs on GitHub →',
  },
  ru: {
    eyebrow: 'КАК ИГРАТЬ',
    title: 'Ядро строится тем, что в него играют',
    lede: 'Каждая сота на карте — часть ядра, а ходы самые обычные: взять задачу, написать спеку, которая её порождает, скомпилировать, отправить. Отдельного процесса контрибуции нет — это и есть процесс.',
    steps: [
      {
        n: '01',
        name: 'Взять соту',
        body: 'Откройте доску и выберите что-нибудь из бэклога. На карточке номер задачи и число критериев приёмки — это и есть договор, на который вы соглашаетесь.',
        link: '#/queen?tab=kanban',
        cta: 'Открыть доску',
      },
      {
        n: '02',
        name: 'Написать спеку',
        body: 'Работа — это спека .t27, а не код, который из неё родится. Посмотрите соседнюю в Обозревателе, чтобы увидеть форму: константы, тип, функции, тест и инвариант.',
        link: '#/specs',
        cta: 'Открыть обозреватель',
      },
      {
        n: '03',
        name: 'Скомпилировать',
        body: 'Тот же обозреватель запускает настоящий компилятор: токены, AST, типы, HIR, затем Zig, Verilog, C и Rust из одного источника. Не компилируется — значит, это ещё не спека.',
        link: '#/queen?tab=specs',
        cta: 'Скомпилировать в шелле',
      },
      {
        n: '04',
        name: 'Отправить',
        body: 'Pull request в репозиторий со ссылкой на задачу. Он попадает в очередь ревью: совпадение со спекой само по себе задачу не закрывает — нужны генерация, тесты и ревью.',
        link: REPO_ISSUES,
        cta: 'Открыть задачи',
        external: true,
      },
    ],
    closing: 'Корпус открыт, и каждое правило, по которому его судят, — тоже.',
    closingCta: 'Спеки на GitHub →',
  },
} as const

export default function PlayBlock() {
  const { lang } = useI18n()
  const key = lang === 'ru' ? 'ru' : 'en'
  const t = COPY[key]

  return (
    <section className="play-block" id="play" aria-labelledby="play-title">
      <div className="play-block-inner">
        <header className="play-block-head">
          <span className="play-block-eyebrow">{t.eyebrow}</span>
          <h2 id="play-title">{t.title}</h2>
          <p>{t.lede}</p>
        </header>

        <ol className="play-block-steps">
          {t.steps.map((step) => (
            <li key={step.n}>
              <span className="play-step-n">{step.n}</span>
              <strong>{step.name}</strong>
              <p>{step.body}</p>
              <a
                href={step.link}
                {...('external' in step && step.external
                  ? { target: '_blank', rel: 'noopener noreferrer' }
                  : null)}
              >
                {step.cta} →
              </a>
            </li>
          ))}
        </ol>

        <p className="play-block-closing">
          {t.closing}{' '}
          <a href={REPO_SPECS} target="_blank" rel="noopener noreferrer">
            {t.closingCta}
          </a>
        </p>
      </div>
    </section>
  )
}
