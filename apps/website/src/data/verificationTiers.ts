// Three tiers, named, with what each one actually delivers today.
//
// The page used to list bit-exact conformance, achieved frequency on a live
// Artix-7, and a bitstream as one undifferentiated set of promises, while the
// button on the same page started something that does none of them: it
// elaborates, checks latches and counts cells. A visitor could reasonably
// expect silicon numbers from a free automated run and get four structural
// facts instead.
//
// Splitting them is not a retreat. Each tier says what it delivers, how long it
// takes, and — the part that is usually missing — how much of it has actually
// been delivered to somebody who was not me.

export type Tier = {
  id: string
  name: { en: string; ru: string }
  price: { en: string; ru: string }
  turnaround: { en: string; ru: string }
  /** What the tier produces. No aspiration, only what runs today. */
  delivers: { en: string[]; ru: string[] }
  /** The honest record: what has been produced at this tier, and for whom. */
  track: { en: string; ru: string }
  automated: boolean
}

export const DELIVERY_TIERS: Tier[] = [
  {
    id: 'structural',
    automated: true,
    name: { en: 'Structural — automated', ru: 'Структурная — автоматическая' },
    price: { en: 'Free for a public repository', ru: 'Бесплатно для публичного репозитория' },
    turnaround: { en: 'Minutes', ru: 'Минуты' },
    delivers: {
      en: [
        'Every file your info.yaml declares is present, and the design elaborates from that list alone.',
        'No latch is inferred by the published flow.',
        'It synthesises, with the cell count including submodules and the breakdown by cell type.',
        'How many flip-flops the netlist holds — which says whether a clock frequency is a meaningful question, not what the answer is.',
        'The command that produced each line, so you can re-run any of them.',
      ],
      ru: [
        'Каждый файл, объявленный в вашем info.yaml, на месте, и дизайн собирается из этого списка.',
        'Опубликованный флоу не выводит ни одной защёлки.',
        'Синтезируется — со счётом ячеек по всему дизайну и разбивкой по типам.',
        'Сколько триггеров в нетлисте — это говорит, осмыслен ли вопрос о частоте, а не каков ответ.',
        'Команда под каждой строкой, чтобы вы могли перезапустить любую.',
      ],
    },
    track: {
      en: 'Delivered: eight designs, three of them other people’s, published with their commands. It found a shuttle-blocking defect in two of my own chips and none in the three that were not mine.',
      ru: 'Сделано: восемь дизайнов, три из них чужие, опубликованы вместе с командами. Нашла блокирующий шаттл дефект в двух моих чипах и ни одного в трёх чужих.',
    },
  },
  {
    id: 'conformance',
    automated: false,
    name: { en: 'Conformance against an independent model', ru: 'Соответствие независимой модели' },
    price: { en: 'From $300 per core, first module free', ru: 'От $300 за ядро, первый модуль бесплатно' },
    turnaround: { en: '3–5 working days', ru: '3–5 рабочих дней' },
    delivers: {
      en: [
        'A reference model written from your description of what the design should do — never from your RTL, because a model derived from the code agrees with the code including where it is wrong.',
        'Known-answer vectors, and the count of mismatches.',
        'The bound that count buys: N passing vectors put the per-vector failure probability below ln(1/(1−C))/N at confidence C. Stated as a bound, never as a zero.',
        'Every assumption taken where your specification was silent, listed.',
      ],
      ru: [
        'Эталонная модель, написанная из вашего описания того, что дизайн должен делать, — никогда из вашего RTL: модель, выведенная из кода, соглашается с кодом, включая места, где он неверен.',
        'Векторы с известными ответами и число расхождений.',
        'Граница, которую это число даёт: N прошедших векторов кладут вероятность отказа ниже ln(1/(1−C))/N при доверии C. Всегда как граница, никогда как ноль.',
        'Перечень всех допущений, взятых там, где ваша спецификация молчала.',
      ],
    },
    track: {
      en: 'Delivered: 170,068 vectors with zero mismatches on somebody else’s MAC. Run again on my own GF16 multiplier, where it surfaced 110 disagreements out of 994 — and the adjudication went against my own reference model, not the RTL.',
      ru: 'Сделано: 170 068 векторов и ноль расхождений на чужом MAC. Повторено на своём умножителе GF16, где всплыли 110 расхождений из 994 — и разбор оказался против моей же эталонной модели, а не против RTL.',
    },
  },
  {
    id: 'silicon',
    automated: false,
    name: { en: 'On the board', ru: 'На плате' },
    price: { en: 'Quoted per design', ru: 'Цена по дизайну' },
    turnaround: { en: 'Days — board time is queued', ru: 'Дни — время платы в очереди' },
    delivers: {
      en: [
        'Place-and-route on a named part, with the resource counters the router emits after routing completed.',
        'Achieved frequency where static timing analysis actually ran — and an explicit "no timing analysis ran" where the tool reported no clocks, rather than a number borrowed from a different configuration.',
        'The bitstream, its SHA-256, and the device log.',
      ],
      ru: [
        'Размещение и разводка на конкретном кристалле, со счётчиками ресурсов, которые выдаёт роутер после успешной разводки.',
        'Достигнутая частота там, где статический анализ действительно отработал, — и прямое «анализ не выполнялся» там, где инструмент не нашёл тактовых, вместо цифры, взятой из другой конфигурации.',
        'Битстрим, его SHA-256 и лог устройства.',
      ],
    },
    track: {
      en: 'Delivered on my own designs. The one third-party design taken this far reached a routed netlist and was never loaded onto a board, so its resource figures come from the router and are labelled as such. Three boards exist and they are queued, not parallel.',
      ru: 'Сделано на своих дизайнах. Единственный чужой дизайн, доведённый до этой ступени, дошёл до разведённого нетлиста и на плату не загружался — его цифры ресурсов взяты у роутера и подписаны именно так. Плат три, и они в очереди, а не параллельны.',
    },
  },
]

export const TIERS_LEDE = {
  en: 'Three tiers, and the button above starts the first one. They are separated because they establish different things: the free run is structural and concludes nothing about whether your design is correct, and saying so is the only way the other two mean anything.',
  ru: 'Три ступени, и кнопка выше запускает первую. Они разделены потому, что устанавливают разное: бесплатный прогон структурный и ничего не говорит о том, верен ли ваш дизайн, — и только прямо сказав это, две другие что-то значат.',
}
