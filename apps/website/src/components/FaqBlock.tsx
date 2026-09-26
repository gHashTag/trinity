import { useI18n } from '../i18n/context'
import { BOUNDARY_EXAMPLE_ISSUE } from '../lib/queenApi'
import './FaqBlock.css'

// The objections, answered where they are raised.
//
// The blocks above tell a reader what the game is and how a move is made. This
// one answers what they are actually thinking at that moment -- what it costs,
// whether they need the language first, what happens after they send, and how
// long they will wait. A landing that describes a process and leaves those
// unanswered loses the reader exactly here, and the answers are short.
//
// Every answer is a fact about this repository or this service, checkable
// today: the licence is MIT (LICENSE at the root), the supervisor refuses an
// issue that names no boundary, a spec match does not close an issue on its
// own, and there is no service level. Where there is no number we are prepared
// to defend -- how long a reply takes -- the answer says so and points at the
// board, which prints its own last round. An invented number here would be the
// one lie on a page whose whole argument is that its figures are readings.
//
// Answers are shown, not folded away. An objection is only handled if it is
// read, and a closed accordion is an objection left standing.
const COPY = {
  en: {
    eyebrow: 'BEFORE YOU START',
    title: 'What people ask before their first move',
    lede: 'Six questions, answered with what is true today rather than what would read well.',
    items: [
      {
        q: 'Do I need to know .t27 first?',
        a: 'No. The move the swarm is short of is a boundary: the list of paths an agent is allowed to touch, written in prose on an issue that already exists. It takes minutes and no compiler. The spec comes after, and the nearest existing one is the template.',
        cta: 'A boundary done right',
        link: BOUNDARY_EXAMPLE_ISSUE,
        external: true,
      },
      {
        q: 'What does it cost, and what do I get?',
        a: 'Nothing. The repository is MIT and public. What a turn buys is a matter of record rather than a promise: your spec in the corpus, compiled by the same compiler that compiles the rest of it, your name in the history that produced it, and an accepted turn counted against that name. There is no token, and the block above says why there will not be one.',
      },
      {
        q: 'What happens after I send something?',
        a: 'The supervisor dispatches the issue to a worker on its own schedule — nobody has to be asked. The round is public while it runs. A matching spec does not close an issue by itself: generation, tests and review are all required, and a rejection names which of them failed.',
        cta: 'Open the board',
        link: '#/queen?tab=kanban',
      },
      {
        q: 'How long until someone looks at it?',
        a: 'There is no service level here, and this page will not invent one. The board prints when the last round ran and what it did — a reading you can check beats a number we would have to defend.',
        cta: 'The last round',
        link: '#/queen',
      },
      {
        q: 'How is this different from a repository with issues?',
        a: 'An issue in an ordinary repository waits for a person to volunteer. Here a supervisor is already running, with workers it may not use until an issue states what can be touched. Your boundary is not a request for attention — it is the thing that lets a machine start without any.',
      },
      {
        q: 'Who owns what I write?',
        a: 'What you send arrives under the same MIT licence as everything already in the repository, and stays as public as the rest of it. The site asks for no account: the only identity the service uses is a Telegram profile you already have.',
      },
    ],
  },
  ru: {
    eyebrow: 'ПЕРЕД ПЕРВЫМ ХОДОМ',
    title: 'О чём спрашивают до первого хода',
    lede: 'Шесть вопросов, на которые отвечено тем, что верно сегодня, а не тем, что лучше читается.',
    items: [
      {
        q: 'Нужно ли сначала знать .t27?',
        a: 'Нет. Рою не хватает хода, который называется границей: списка путей, которые агенту разрешено трогать, написанного прозой в уже существующей задаче. Это занимает минуты и не требует компилятора. Спека идёт следом, а образцом служит ближайшая из уже написанных.',
        cta: 'Граница, написанная как надо',
        link: BOUNDARY_EXAMPLE_ISSUE,
        external: true,
      },
      {
        q: 'Сколько это стоит и что я получаю?',
        a: 'Нисколько. Репозиторий под MIT и открыт. То, что даёт ход, — это запись, а не обещание: ваша спека в корпусе, скомпилированная тем же компилятором, что и весь остальной корпус; ваше имя в истории, которая её породила; и принятый ход, засчитанный этому имени. Токена нет, а почему его и не будет — сказано в блоке выше.',
      },
      {
        q: 'Что происходит после того, как я отправил?',
        a: 'Супервизор сам, по своему расписанию, отправляет задачу рабочему — просить никого не нужно. Пока круг идёт, он виден всем. Совпавшая спека сама по себе задачу не закрывает: нужны генерация, тесты и ревью, а отказ называет, что именно из этого не прошло.',
        cta: 'Открыть доску',
        link: '#/queen?tab=kanban',
      },
      {
        q: 'Сколько ждать, пока кто-нибудь посмотрит?',
        a: 'Никакого SLA здесь нет, и выдумывать его эта страница не станет. Доска печатает, когда прошёл последний круг и что он сделал, — показание, которое можно проверить, лучше числа, которое пришлось бы защищать.',
        cta: 'Последний круг',
        link: '#/queen',
      },
      {
        q: 'Чем это отличается от репозитория с задачами?',
        a: 'Задача в обычном репозитории ждёт, пока вызовется человек. Здесь супервизор уже работает, и у него есть рабочие, которых ему нельзя занять, пока в задаче не сказано, что можно трогать. Ваша граница — не просьба обратить внимание, а то, что позволяет машине начать без всякого внимания.',
      },
      {
        q: 'Кому принадлежит то, что я напишу?',
        a: 'Отправленное приходит под той же лицензией MIT, что и всё уже лежащее в репозитории, и остаётся таким же открытым. Учётной записи сайт не просит: единственная личность, которой пользуется сервис, — это профиль Telegram, который у вас уже есть.',
      },
    ],
  },
} as const

export default function FaqBlock() {
  const { lang } = useI18n()
  const t = COPY[lang === 'ru' ? 'ru' : 'en']

  return (
    <section className="faq-block" id="faq" aria-labelledby="faq-block-title">
      <div className="faq-block-inner">
        <header className="faq-block-head">
          <span className="faq-block-eyebrow">{t.eyebrow}</span>
          <h2 id="faq-block-title">{t.title}</h2>
          <p>{t.lede}</p>
        </header>

        <dl className="faq-block-list site-card-row">
          {t.items.map((item) => (
            <div className="faq-block-item site-card" key={item.q}>
              <dt>{item.q}</dt>
              <dd>
                <p>{item.a}</p>
                {'link' in item && item.link ? (
                  <a
                    href={item.link}
                    {...('external' in item && item.external
                      ? { target: '_blank', rel: 'noopener noreferrer' }
                      : {})}
                  >
                    {item.cta} →
                  </a>
                ) : null}
              </dd>
            </div>
          ))}
        </dl>
      </div>
    </section>
  )
}
