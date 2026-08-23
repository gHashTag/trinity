import type { PostMeta } from './types'

/** Индекс блога: список и метаданные без тяжёлых тел публикаций. */
export const postsIndex: PostMeta[] = [
  {
    slug: 'nobodys-example',
    title: "Nobody's example",
    summary: 'A gate\'s negative control is written by someone who plants the fault it is meant to catch. That one sentence explains almost everything a boundary-mutation operator found in a suite three other operators had already scoured.',
    date: '2026-08-23',
    readingMinutes: 8,
    tags: ['CI', 'Mutation testing', 'Test design', 'Measurement'],
    receipts: [
      { label: 'gHashTag/t27 #2503 -- the boundary operator, and the first number that counted docstrings', href: 'https://github.com/gHashTag/t27/pull/2503' },
      { label: 'gHashTag/t27 #2504 -- three boundaries closed, one classification corrected', href: 'https://github.com/gHashTag/t27/pull/2504' },
      { label: 'gHashTag/t27 #2507 -- the last six, and what they had in common', href: 'https://github.com/gHashTag/t27/pull/2507' },
    ],
    openQuestions: [
      'Whether a fifth operator family finds more is not established. Four were tried, nothing enumerates the set, and three of the four found a defect in the tool asking the question rather than in the code asked about.',
      'The claim that degeneracy explains the yield is an argument from six cases in one repository, not a measurement across projects. It predicts that other suites have the same hole; that prediction is untested here.',
      'Two survivors are called proven equivalences on the strength of two enclosing guards. The proof is short and stated in the source, but it is a reading of the code, not an exhaustive check of the input space.',
      '"No mutant survives" is not "the gates are correct". Nothing here measures whether a gate checks the property anyone wanted it to check.',
    ],
    published: true,
    ru: {
      title: 'Ничьи примеры',
      summary: 'Негативный контроль гейта пишет тот, кто сажает дефект, который контроль должен поймать. Эта одна фраза объясняет почти всё, что граничный оператор мутаций нашёл в наборе, уже вычищенном тремя другими.',
      openQuestions: [
        'Найдёт ли что-нибудь пятое семейство операторов — не установлено. Испробованы четыре, множество ничем не перечислено, и три из четырёх нашли дефект в самом задающем вопрос инструменте, а не в коде, о котором спрашивали.',
        'Утверждение, что вырожденность объясняет урожай, — довод от шести случаев в одном репозитории, а не измерение по проектам. Оно предсказывает такую же дыру в других наборах; это предсказание здесь не проверено.',
        'Два выживших названы доказанными эквивалентностями на основании двух охранников. Доказательство коротко и записано в исходнике, но это чтение кода, а не исчерпывающая проверка пространства входов.',
        '«Ни один мутант не выживает» — не то же, что «гейты верны». Ничто здесь не измеряет, проверяет ли гейт то свойство, которое от него хотели.',
      ],
    },
  },
  {
    "slug": "the-silence-was-a-saturated-readout",
    "title": "A background loop broke for months, and no amount of watching could have caught it",
    "summary": "Seven timed loops logged nothing on an empty tick. That is not an oversight in monitoring — it is the same theorem that kills a sticky-OR readout: the observation is identically constant across the hypotheses, so it carries exactly zero bits.",
    "date": "2026-08-12",
    "readingMinutes": 6,
    "tags": [
      "information theory",
      "observability",
      "production",
      "measurement"
    ],
    "receipts": [
      {
        "label": "the fix, merged 2026-08-12",
        "href": "https://github.com/gHashTag/woody-weed-bot/pull/74"
      },
      {
        "label": "the earlier readout theorem",
        "href": "https://t27.ai/#/blog/readout-that-cannot-be-misread"
      }
    ],
    "openQuestions": [
      "The information argument is exact only where the readout is saturated. Near-saturation is answered below and was verified numerically; the closed form is second-order and already drifts 1.2% at a gap of 0.08, and for dependent observations the 1/d² cost is a lower bound rather than the value.",
      "Whether the deployed fix works is not yet established. It merged 2026-08-12 06:30 UTC; the loops it instruments tick every four and six hours, so the first evidence arrives after this was written.",
      "The unification is a claim about two failures I have in hand. Whether every silent-failure class has this shape is not shown, and I would expect counterexamples where the observation is noisy rather than constant.",
      "No claim is made about how common this is in other codebases. Seven of seven loops in one project is a fact about that project."
    ],
    "published": true,
    "ru": {
      "title": "Фоновый цикл ломался месяцами, и никакое наблюдение не могло его поймать",
      "summary": "Семь таймерных циклов ничего не писали при пустом тике. Это не упущение мониторинга — это та же теорема, что убивает показание sticky-OR: наблюдение тождественно постоянно по гипотезам и потому несёт ровно ноль бит.",
      "openQuestions": [
        "Информационный довод точен лишь там, где показание насыщено. Приближённое насыщение разобрано ниже и проверено численно; замкнутая форма — второго порядка и уже при зазоре 0.08 отклоняется на 1.2%, а для зависимых наблюдений 1/d² есть нижняя оценка, а не значение.",
        "Работает ли развёрнутая правка, пока не установлено. Она влита 2026-08-12 06:30 UTC, а циклы, которые она снабжает строкой, тикают раз в четыре и шесть часов — первое свидетельство появится после написания этого текста.",
        "Объединение — утверждение о двух отказах, которые у меня на руках. Что всякий класс тихих отказов имеет такую форму, не показано; контрпримеры ожидаемы там, где наблюдение шумное, а не постоянное.",
        "О распространённости в других кодовых базах не утверждается ничего. Семь циклов из семи в одном проекте — факт об этом проекте."
      ]
    }
  },
  {
    "slug": "twenty-merged-in-three-days",
    "title": "Twenty patches merged upstream in three days",
    "summary": "On 2026-08-09 my own notes said six patches were open and none had been merged. By 2026-08-11 openXC7 had merged twenty. The interesting part is not the number — it is that I did not know it until I ran the query.",
    "date": "2026-08-12",
    "readingMinutes": 4,
    "tags": [
      "openXC7",
      "upstream",
      "measurement"
    ],
    "receipts": [
      {
        "label": "openXC7/nextpnr-xilinx — merged PRs by gHashTag",
        "href": "https://github.com/openXC7/nextpnr-xilinx/pulls?q=is%3Apr+author%3AgHashTag+is%3Amerged"
      },
      {
        "label": "the three still open",
        "href": "https://github.com/openXC7/nextpnr-xilinx/pulls?q=is%3Apr+author%3AgHashTag+is%3Aopen"
      }
    ],
    "openQuestions": [
      "Counted by API on 2026-08-12 with is:merged over openXC7/nextpnr-xilinx. Merge dates are the repository’s, not mine.",
      "Twenty merges is a count of accepted patches, not of impact. Several are one-line diagnostics; the number does not weight them.",
      "Why the burst happened over exactly those three days is upstream’s business and not visible from the outside. I am reporting the dates, not explaining them.",
      "Three PRs remain open (#119, #120, #129). Whether they land is not predicted here."
    ],
    "published": true,
    "ru": {
      "title": "Двадцать патчей слито апстримом за три дня",
      "summary": "2026-08-09 в моих заметках стояло: шесть патчей открыты, ни один не слит. К 2026-08-11 openXC7 слил двадцать. Занятно не число, а то, что я не знал его, пока не запустил запрос.",
      "openQuestions": [
        "Посчитано по API 2026-08-12 запросом is:merged по openXC7/nextpnr-xilinx. Даты слияний — репозитория, не мои.",
        "Двадцать слияний — счёт принятых патчей, а не влияния. Некоторые из них однострочные диагностики; число их не взвешивает.",
        "Почему всплеск пришёлся ровно на эти три дня — дело апстрима и снаружи не видно. Я сообщаю даты, а не объясняю их.",
        "Три PR остаются открытыми (#119, #120, #129). Сядут ли они, здесь не предсказывается."
      ]
    }
  },
  {
    "slug": "energy-asymmetry-activations",
    "title": "Half of your activations are negative. They carry 1.8% of the energy",
    "summary": "Post-activation tensors are half negative by count and 1.8–6.2% by energy, while weights are symmetric on both measures — which decides how a 4-bit alphabet should spend its codes.",
    "date": "2026-08-11",
    "readingMinutes": 6,
    "tags": [
      "Quantisation",
      "Transformers",
      "Numeric formats",
      "4-bit"
    ],
    "receipts": [
      {
        "label": "The measurement, with the table",
        "href": "https://github.com/gHashTag/trinity-fpga/blob/main/research/block/ENERGY_ASYMMETRY_2026-08-09.md"
      },
      {
        "label": "The comparison it predicts (BlockDialect, DialectFP4)",
        "href": "https://github.com/gHashTag/trinity-fpga/blob/main/research/block/ASYM_VS_BLOCKDIALECT_2026-08-09.md"
      },
      {
        "label": "DialectFP4, the competitor — arXiv:2501.01144",
        "href": "https://arxiv.org/abs/2501.01144"
      }
    ],
    "openQuestions": [
      "Measured on SmolLM2-135M and Qwen2.5-0.5B only. Two small models is not a general result, and nothing here shows the ratio holds at 7B or beyond.",
      "The energy share is reported for GELU and SiLU/SwiGLU. Other activations were not measured, and ReLU is trivially 0% because it has no negative outputs at all.",
      "The advantage on activations (1.17×–1.46×) comes with a loss on weights (0.94×). Whether a mixed alphabet — asymmetric for activations, symmetric for weights — is worth its control cost in hardware has not been measured."
    ],
    "published": true,
    "ru": {
      "title": "Энергия активаций несимметрична, и это не свойство данных",
      "summary": "Стоимость положительной и отрицательной половины активаций различается устойчиво и в одну сторону. Асимметрия переживает смену данных, значит принадлежит представлению, а не входу.",
      "openQuestions": [
        "Измерено на прогонах серии HSLM, восстановленных 2026-04-20 обходом истории git; числа их, не перемеряны.",
        "Асимметрия наблюдалась на нескольких наборах данных. «Несколько» — не «любые»: класс входов, на котором она исчезает, не установлен.",
        "Механизм не предъявлен. Правдоподобны и несимметричное кодирование нуля, и поведение функции активации у нуля, и порядок округления — этими данными их не различить.",
        "Практический выигрыш от учёта асимметрии не измерен. Известно, что она есть, а не то, что на ней можно сэкономить."
      ]
    }
  },
  {
    "slug": "phi-identity-machine-checked",
    "title": "phi^2 + 1/phi^2 = 3, checked every way I could think of",
    "summary": "An exact identity, six proof steps machine-verified, and a search over 1,476,000 candidates that found no other root — plus what the identity does not license.",
    "date": "2026-08-11",
    "readingMinutes": 5,
    "tags": [
      "Mathematics",
      "Golden ratio",
      "Verification",
      "Ternary"
    ],
    "receipts": [
      {
        "label": "The proof, all six steps",
        "href": "https://github.com/gHashTag/trinity/blob/main/docs/docs/math-foundations/proofs.md"
      },
      {
        "label": "Lucas numbers L(2n) — the family this belongs to (OEIS A000032)",
        "href": "https://oeis.org/A000032"
      },
      {
        "label": "Euclid, Elements VI, Definition 3 — where the ratio is first defined",
        "href": "https://mathcs.clarku.edu/~djoyce/java/elements/bookVI/defVI3.html"
      }
    ],
    "openQuestions": [
      "Сhecked 2026-08-11 with sympy, mpmath at 60/210/1000 digits, and a 1,476,000-candidate numerical net. The identity itself is Euclid’s; only the verification is dated here.",
      "This is the n=1 case of the standard Lucas identity phi^(2n) + phi^(-2n) = L(2n). It is textbook mathematics, cited here rather than claimed — Euclid defined the ratio and the identity follows from its quadratic.",
      "Landing on a small integer is guaranteed, not surprising: every even power gives one. phi^2+phi^-2 through phi^16+phi^-16 are 3, 7, 18, 47, 123, 322, 843, 2207.",
      "That the result is 3 and that ternary arithmetic uses radix 3 is not a connection this identity establishes. No mechanism links L(2) to a radix, and treating the coincidence as evidence would be a separate claim needing separate support."
    ],
    "published": true,
    "ru": {
      "title": "Тождество золотого сечения, проверенное машиной",
      "summary": "φ² + 1/φ² = 3 — тождество, на котором стоит вся арифметика проекта. Доказательство проверено ассистентом, а не мной: там, где число лежит в основании, вера в него не считается.",
      "openQuestions": [
        "Проверено машиной 2026-08-11 в Lean; предмет проверки — доказательство, не реализация.",
        "Тождество точно в Z[φ] и приблизительно в любом формате с плавающей точкой. Насколько приблизительно — вопрос формата, а не тождества, и здесь он не отвечен.",
        "Машинная проверка исключает ошибку в выводе. Она не исключает того, что доказано не то утверждение, которое нужно; формулировку читал человек.",
        "Что из арифметики проекта опирается на это тождество, а что лишь соседствует с ним, отдельно не размечено."
      ]
    }
  },
  {
    "slug": "readout-that-cannot-be-misread",
    "title": "Four rules for a measurement rig whose readout cannot be misread",
    "summary": "A readout whose mapping to state is unestablished is not an instrument — four rules written after a week of hardware debugging where the rig lied and the design was fine.",
    "date": "2026-08-11",
    "readingMinutes": 6,
    "tags": [
      "FPGA",
      "Hardware",
      "Debugging",
      "Measurement"
    ],
    "receipts": [
      {
        "label": "The rules, with the failures that produced each",
        "href": "https://github.com/gHashTag/trinity-fpga/blob/main/docs/HW_CAMPAIGN_AX7203_2026_07_30.md"
      },
      {
        "label": "The Ethernet build these rules were written during",
        "href": "https://t27.ai/#/blog/open-gigabit-ethernet-artix7"
      }
    ],
    "openQuestions": [
      "The rules come from the AX7203 bring-up campaign of 2026-07-30, written down as each failure occurred. Published 2026-08-11.",
      "These come from one board (AX7203, Artix-7) and one week. They are habits that survived a specific set of mistakes, not a general methodology, and rules 1 and 3 in particular assume a readout with few indicators.",
      "Rule 4 (A/B/A) costs a third run every time. Whether that is worth it depends on how expensive a run is; on a fast build it obviously is, on a six-hour synthesis it is a judgement call not made here."
    ],
    "published": true,
    "ru": {
      "title": "Показание, которое нельзя прочесть неверно",
      "summary": "Sticky-OR по окну несёт ровно ноль бит, если окно заведомо содержит высокий отсчёт. Средство стоит одного регистра: AND рядом с OR даёт строку, которая не может случиться.",
      "openQuestions": [
        "Взято из наладки AX7203 2026-07-30, где показание уже было построено неверно. Опубликовано 2026-08-11.",
        "Результат про ноль информации точен там, где насыщение гарантировано. Где не гарантировано, взаимная информация мала, а не нулевая, и насколько мала — зависит от частоты события.",
        "Пара OR/AND различает три состояния и не различает, как часто происходит переключение. Для частоты нужен счётчик, а не флаг.",
        "Невозможная строка проверяет тракт чтения и синхронизацию домена. Она не проверяет, что окно выбрано верно."
      ]
    }
  },
  {
    "slug": "frame-length-margin-law",
    "title": "Timing margin grows as the square root of a logarithm, and nothing accumulates",
    "summary": "A frame-length margin law derived from extreme-value statistics, and the accumulation story it refutes — which would predict a 12.9x eye violation on frames that pass.",
    "date": "2026-08-11",
    "readingMinutes": 7,
    "tags": [
      "FPGA",
      "Ethernet",
      "RGMII",
      "Timing",
      "Statistics"
    ],
    "receipts": [
      {
        "label": "The derivation, with the source theorems it leans on",
        "href": "https://github.com/gHashTag/trinity-fpga/blob/main/docs/HW_CAMPAIGN_AX7203_2026_07_30.md"
      },
      {
        "label": "The build this was derived during",
        "href": "https://t27.ai/#/blog/open-gigabit-ethernet-artix7"
      }
    ],
    "openQuestions": [
      "The law was derived during the same 2026-07-30 bring-up campaign; the frame figures are from that campaign’s measurements. Published 2026-08-11.",
      "The law assumes per-edge phase errors are i.i.d. with a symmetric distribution. Real jitter has correlated components — supply noise, thermal drift — and the i.i.d. assumption is what makes the extreme-value argument work. Where correlation is strong the law is optimistic and by how much has not been measured here.",
      "The Gaussian form is an asymptotic approximation to the inverse CDF. It is accurate in the tail regime that matters for frame error rates, and it is not exact.",
      "This explains why long frames pass. It is not a design rule for closing timing, and using it as one would be reading a statistical bound as an engineering margin."
    ],
    "published": true,
    "ru": {
      "title": "Закон запаса по длине кадра",
      "summary": "Запас, при котором кадр ещё принимается, падает не с длиной, а с её логарифмом. Подгонка по четырём точкам, и она предсказала пятую до того, как её измерили.",
      "openQuestions": [
        "Четыре точки, пятая — предсказание, подтверждённое после. Четырёх точек мало для закона; это подгонка, названная подгонкой.",
        "Логарифмическая форма взята потому, что она прямая в полулогарифмических осях, а не потому, что выведена из механизма. Механизм остаётся открытым.",
        "Измерено на одном стенде AX7203 с одним коммутатором. Перенос на другое железо не проверялся.",
        "Закон говорит, где кадр перестаёт приниматься, и ничего не говорит о том, почему именно там."
      ]
    }
  },
  {
    "slug": "fifteen-merged-nine-credited",
    "title": "Fifteen merged, nine credited: what upstream contribution actually looks like",
    "summary": "I had written down five merged PRs and zero attributed commits. Re-measured through the API: fifteen merged, eight open, nine commits carrying my name — and the gap is worth naming precisely rather than as an absence.",
    "date": "2026-08-11",
    "readingMinutes": 5,
    "tags": [
      "Open source",
      "FPGA",
      "openXC7",
      "Attribution"
    ],
    "receipts": [
      {
        "label": "The merged PRs — run the query yourself",
        "href": "https://github.com/openXC7/nextpnr-xilinx/pulls?q=is%3Apr+author%3AgHashTag+is%3Amerged"
      },
      {
        "label": "PR #133 — say which pin is wrong when a diff pair is const",
        "href": "https://github.com/openXC7/nextpnr-xilinx/pull/133"
      },
      {
        "label": "PR #130 — emit OLOGIC IS_CLKDIV_INVERTED for OSERDESE2",
        "href": "https://github.com/openXC7/nextpnr-xilinx/pull/130"
      }
    ],
    "openQuestions": [
      "These counts are for openXC7/nextpnr-xilinx alone, measured 2026-08-11. Other repositories were not counted and the ratio there may differ.",
      "Commit attribution is measured by GitHub’s author field, which follows the email in the commit. A merged PR whose commits were squashed under a maintainer’s name will not appear, and that is one of the mechanisms this post is about — so the nine is a floor, not a ceiling.",
      "Nothing here measures whether the gap is deliberate, and no maintainer is doing anything unusual. Squash-merge is the default on most projects."
    ],
    "published": true,
    "ru": {
      "title": "Пятнадцать смержено, девять атрибутировано: как выглядит вклад в чужой проект",
      "summary": "У меня было записано: пять смерженных PR и ноль атрибутированных коммитов. Перемерил через API: пятнадцать смержено, восемь открыто, девять коммитов несут моё имя — и оставшийся зазор стоит называть точно, а не как отсутствие.",
      "openQuestions": [
        "Счёт только по openXC7/nextpnr-xilinx, измерено 2026-08-11. Другие репозитории не считались, и там соотношение может быть иным.",
        "Атрибуция мерится по полю author в GitHub, которое идёт за почтой коммита. Смерженный PR, чьи коммиты сжали под именем мейнтейнера, в этот счёт не попадёт — и это один из механизмов, о которых пост. Значит девять — это пол, а не потолок.",
        "Ничто здесь не мерит, намерен ли зазор, и ни один мейнтейнер не делает ничего необычного. Squash-merge — поведение по умолчанию у большинства проектов."
      ]
    }
  },
  {
    "slug": "context-length-resonance-not-power-law",
    "title": "Doubling the context made it worse: ternary scaling follows a resonance, not a power law",
    "summary": "ctx=18 gives PPL 5.58, ctx=27 gives 2.96, ctx=54 gives 6.05 — worse than the baseline. Powers of three are orbitals and the values between them are forbidden zones.",
    "date": "2026-08-11",
    "readingMinutes": 6,
    "tags": [
      "Training",
      "Ternary",
      "Scaling",
      "Transformers",
      "Negative result"
    ],
    "receipts": [
      {
        "label": "The experiment ledger — twenty runs with their parameters",
        "href": "https://github.com/gHashTag/trinity/blob/main/docs/experiments/FOUND_EXPERIMENTS_SUMMARY.md"
      },
      {
        "label": "The model catalogue, by family and branch",
        "href": "https://github.com/gHashTag/trinity/blob/main/docs/research/COMPLETE_MODEL_CATALOG.md"
      }
    ],
    "openQuestions": [
      "The runs are from the HSLM series recovered 2026-04-20 by walking git history; the perplexities are theirs, not re-measured. Published 2026-08-11.",
      "These are HSLM runs at small scale. Nothing here shows the effect survives at sizes where a context of 81 or 243 is practical, and the orbital spacing means the next test point is three times away rather than adjacent.",
      "The mechanism is asserted from the ratio structure, not derived. Why powers of three specifically — rather than powers of any base matching the weight alphabet — is not established here, and a binary-weight control at ctx=16/32/64 would test it directly.",
      "Perplexity ranges are reported per configuration (ctx=27 gives 2.96–5.55 across runs), so the ctx=27 advantage is larger than run-to-run variance but the exact margin depends on which runs are compared."
    ],
    "published": true,
    "ru": {
      "title": "Удвоение контекста ухудшило результат: троичное масштабирование это резонанс, а не степенной закон",
      "summary": "ctx=18 даёт PPL 5.58, ctx=27 даёт 2.96, ctx=54 даёт 6.05 — хуже базы. Степени тройки это орбитали, а значения между ними — запрещённые зоны.",
      "openQuestions": [
        "Это прогоны HSLM на малом масштабе. Ничто здесь не показывает, что эффект выживает на размерах, где контекст 81 или 243 практичен, а орбитальный шаг означает, что следующая точка проверки втрое дальше, а не рядом.",
        "Механизм заявлен из структуры отношений, а не выведен. Почему именно степени тройки — а не степени любого основания, совпадающего с алфавитом весов — здесь не установлено, и контроль на двоичных весах проверил бы это прямо.",
        "Перплексии приводятся диапазонами на конфигурацию (ctx=27 даёт 2.96–5.55 по прогонам), так что преимущество ctx=27 больше разброса между прогонами, но точная величина зависит от того, какие прогоны сравнивать."
      ]
    }
  },
  {
    "slug": "eight-theorems-audited",
    "title": "I checked my own eight theorems by machine. Four held, three headings were wrong",
    "summary": "Every proof verified step by step, every verdict attacked by a second pass, none disputed — and the defects were never in a measurement, always in what a heading claimed about it.",
    "date": "2026-08-11",
    "readingMinutes": 8,
    "tags": [
      "Mathematics",
      "Verification",
      "Ternary",
      "Golden ratio"
    ],
    "receipts": [
      {
        "label": "The proofs page, with the corrections dated in place",
        "href": "https://github.com/gHashTag/trinity/blob/main/docs/docs/math-foundations/proofs.md"
      },
      {
        "label": "Lucas numbers L(2n) — OEIS A000032",
        "href": "https://oeis.org/A000032"
      },
      {
        "label": "The phi identity in full, checked four ways",
        "href": "https://t27.ai/#/blog/phi-identity-machine-checked"
      }
    ],
    "openQuestions": [
      "The audit was run 2026-08-11. The theorems themselves date from the proofs page as it stood before that; the corrections are dated in place there.",
      "The audit checked arithmetic, derivation and prior art. It did not check whether the theorems are useful, and a correct standard result cited correctly can still be the wrong thing to build on.",
      "Theorem 6’s isolation search covered b <= 16, e in 2..8, k <= 20. A wider net might find a second decomposition and would weaken the [Empirical fit] label to [Risk].",
      "Observation 7 still has no stated domain. Naming it an observation removes the false uniqueness claim but does not supply the thing that would make it a theorem."
    ],
    "published": true,
    "ru": {
      "title": "Я проверил машиной восемь своих теорем. Четыре устояли, три заголовка были неверны",
      "summary": "Каждая теорема свода перепроверена против собственного доказательства. Четыре устояли. Одна сузилась, одна перестала быть теоремой, одна оказалась дубликатом другой.",
      "openQuestions": [
        "Ревизия прошла 2026-08-11 по документу math-foundations/proofs.md; правки внесены на месте и датированы там же.",
        "Проверялись доказательства, а не численные подтверждения. Теорема может быть верна и при этом не описывать ни одного реального прогона.",
        "Восемь — это то, что было записано как теоремы. Сколько утверждений следовало бы записать и не записано, ревизия не измеряет.",
        "Дубликат найден по совпадению формулировок. Два разных доказательства одного факта — не дефект; дефектом была нумерация их как независимых результатов."
      ]
    }
  },
  {
    "slug": "twenty-three-reference-models",
    "title": "Twenty-three reference models, because implementing a competitor from memory always flatters you",
    "summary": "Every format we compare against has its own reference implementation, written from its specification — after five bugs that all weakened the competitor and all pointed the same way.",
    "date": "2026-08-11",
    "readingMinutes": 6,
    "tags": [
      "Numeric formats",
      "Benchmarking",
      "Methodology",
      "Open source"
    ],
    "receipts": [
      {
        "label": "The reference models — all twenty-three",
        "href": "https://github.com/gHashTag/trinity-fpga/tree/main/conformance"
      },
      {
        "label": "The five bugs, section 1.1",
        "href": "https://github.com/gHashTag/trinity-fpga/blob/main/research/block/FINDINGS.md"
      }
    ],
    "openQuestions": [
      "The 23 models were counted 2026-08-11 through the GitHub API. The five bugs are from the block-quantisation campaign recorded in FINDINGS.md, earlier.",
      "Twenty-three models is not twenty-three formats: several cover multiple widths (posit8/16/32, fp8 as both E4M3 and E5M2), so the format count is higher and is not stated here because it has not been counted.",
      "A reference model written from a specification can still misread the specification. These are checked against published test vectors where those exist, and where they do not the model is only as good as the reading.",
      "Nothing here measures how the models perform — only that they exist and where they came from. A correct competitor implementation is a precondition for a fair comparison, not a result."
    ],
    "published": true,
    "ru": {
      "title": "Двадцать три эталонные модели, потому что реализация конкурента по памяти всегда льстит",
      "summary": "У каждого формата, с которым мы сравниваемся, своя эталонная реализация по его спецификации — после пяти ошибок, каждая из которых ослабляла конкурента и все в одну сторону.",
      "openQuestions": [
        "Двадцать три модели — не двадцать три формата: часть покрывает несколько разрядностей (posit8/16/32, fp8 как E4M3 и как E5M2), так что счёт форматов выше и здесь не приводится, потому что не считался.",
        "Эталонная модель, написанная по спецификации, всё равно может её неверно прочесть. Эти сверены с опубликованными тестовыми векторами там, где они есть; где их нет — модель хороша ровно настолько, насколько верно прочтение.",
        "Здесь ничего не измеряется о том, как модели работают — только что они есть и откуда взялись. Верная реализация конкурента это предусловие честного сравнения, а не результат."
      ]
    }
  },
  {
    "slug": "the-experiment-that-could-not-answer",
    "title": "Two theorems that tell you an experiment is worthless before you run it",
    "summary": "A detectability floor of n ≈ 3.92/Δ² said the sweep could not resolve the effect at any outcome, and a sticky-OR readout carried literally zero bits. Both knowable in advance.",
    "date": "2026-08-11",
    "readingMinutes": 6,
    "tags": [
      "Statistics",
      "Measurement",
      "FPGA",
      "Methodology"
    ],
    "receipts": [
      {
        "label": "The bring-up campaign these came out of",
        "href": "https://github.com/gHashTag/trinity-fpga/blob/main/docs/HW_CAMPAIGN_AX7203_2026_07_30.md"
      },
      {
        "label": "The four bench rules that follow from them",
        "href": "https://t27.ai/#/blog/readout-that-cannot-be-misread"
      }
    ],
    "openQuestions": [
      "Both theorems come from the AX7203 bring-up of 2026-07-30 and are recorded there as proven. Published 2026-08-11.",
      "The 3.92 constant is for two proportions at alpha = 0.05 and power 0.8. Different tests and different power give a different constant, and the shape — n scaling as 1/Δ² — is the part that transfers, not the number.",
      "The zero-information result is exact for a saturating aggregator over a window that is certain to contain a high sample. Where saturation is not certain the mutual information is small rather than zero, and how small depends on the rate.",
      "Both theorems say an experiment cannot answer. Neither says what experiment would, and designing that is the harder half."
    ],
    "published": true,
    "ru": {
      "title": "Две теоремы, осуждающие эксперимент до его запуска",
      "summary": "Порог обнаружимости n ≈ 3.92/Δ² сказал, что свип не разрешит эффект ни при каком исходе, а показание через sticky-OR несло ровно ноль бит. Оба известны заранее.",
      "openQuestions": [
        "Обе теоремы взяты из наладки AX7203 от 2026-07-30 и записаны там как доказанные. Опубликовано 2026-08-11.",
        "Константа 3.92 — для двух долей при α = 0.05 и мощности 0.8. Другой критерий и другая мощность дают другую константу; переносится форма — n растёт как 1/Δ² — а не число.",
        "Результат про ноль информации точен для насыщающегося агрегатора по окну, заведомо содержащему высокий отсчёт. Где насыщение не гарантировано, взаимная информация мала, а не равна нулю, и насколько мала — зависит от частоты.",
        "Обе теоремы говорят, что эксперимент не может ответить. Ни одна не говорит, какой эксперимент смог бы, и спроектировать его — половина потруднее."
      ]
    }
  },
  {
    slug: 'the-auditor-made-the-mistake-it-audits',
    title: 'The auditor made the mistake it audits',
    summary: 'A mutation tool took a gate suite from four gates with no negative control to none, and from twenty surviving mutants to zero. In the same week it made, three separate times, the exact mistake it exists to find.',
    date: '2026-08-23',
    readingMinutes: 9,
    tags: ['CI', 'Mutation testing', 'Measurement', 'Self-critique'],
    receipts: [
      { label: 'gHashTag/t27 #2500 -- the invert flag that printed its banner over a silent run', href: 'https://github.com/gHashTag/t27/pull/2500' },
      { label: 'gHashTag/t27 #2502 -- the last survivor: every clause true, conclusion false', href: 'https://github.com/gHashTag/t27/pull/2502' },
      { label: 'gHashTag/t27 #2503 -- the boundary operator, and the first number that counted docstrings', href: 'https://github.com/gHashTag/t27/pull/2503' },
      { label: 'gHashTag/t27 #2504 -- three boundaries closed, one classification corrected', href: 'https://github.com/gHashTag/t27/pull/2504' },
    ],
    openQuestions: [
      'Whether a fifth operator family would find more is not established. Four were tried; nothing enumerates the set, and three of the four found a defect in the tool asking the question.',
      'The classification of the remaining boundary survivors is done by hand and by one reader. Two are proven equivalences and say so in the source; the rest rest on judgement, not measurement.',
      'The counts cover the gate scripts under tools/ in one repository. Nothing here measures the workflows that invoke them, and a gate that is never triggered is not made honest by a passing control.',
      '"No mutant survives" is not "the gates are correct". The operators are narrow by construction, and whether the gates check the right properties is a different question that none of them asks.',
    ],
    published: true,
    ru: {
      title: 'Аудитор совершил ошибку, которую ищет',
      summary: 'Мутационный инструмент довёл набор гейтов от четырёх без негативного контроля до нуля таких и от двадцати выживших мутантов до нуля. За ту же неделю он трижды совершил ровно ту ошибку, ради поиска которой написан.',
      openQuestions: [
        'Найдёт ли что-нибудь пятое семейство операторов — не установлено. Испробованы четыре; множество ничем не перечислено, и три из четырёх нашли дефект в самом задающем вопрос инструменте.',
        'Классификация оставшихся граничных выживших сделана вручную и одним читателем. Две — доказанные эквивалентности и говорят об этом в исходнике; остальные держатся на суждении, а не на измерении.',
        'Счёт покрывает скрипты гейтов в tools/ одного репозитория. Ничто здесь не измеряет workflow, которые их вызывают, а гейт, который никогда не запускается, не становится честным от проходящего контроля.',
        '«Ни один мутант не выживает» — не то же, что «гейты верны». Операторы узки по построению, и проверяют ли гейты нужные свойства — другой вопрос, которого ни один из них не задаёт.',
      ],
    },
  },
  {
    slug: 'i-wrote-the-post-then-did-the-thing',
    title: 'I wrote the post, then did the thing',
    summary: 'Two posts in this series are about gates that fail without changing anyone behaviour. In the four days after writing them I merged four pull requests past a red gate without opening it once.',
    date: '2026-08-23',
    readingMinutes: 6,
    tags: ['CI', 'Attention', 'Self-critique'],
    receipts: [
      { label: 'gHashTag/t27 #2474 -- the measurement: same step, same six targets, four consecutive pull requests', href: 'https://github.com/gHashTag/t27/issues/2474' },
      { label: 'gHashTag/t27 #2455 -- the required check that was a shell command printing a sentence', href: 'https://github.com/gHashTag/t27/issues/2455' },
    ],
    openQuestions: [
      'Whether the gate failure is a code generation defect alone is not established here: six targets do not run, and what they would report if they did is unmeasured.',
      'The last master run of this gate failed at a DIFFERENT step, three days earlier. Whether that failure is also live today is not shown.',
      'The claim that no cost was incurred rests on the four pull requests being unable to affect a code generator. That is an argument from what they touched, not a measurement of what they changed.',
      'No remedy is proposed and none should be read in: making these gates required, or moving them to manual dispatch, is a repository-settings decision.',
    ],
    published: true,
    ru: {
      title: 'Написал пост — и сделал то, о чём он',
      summary: 'Два поста этой серии — про гейты, которые падают, ничьё поведение не меняя. За четверо суток после их написания я смержил четыре пул-реквеста мимо красного гейта, ни разу его не открыв.',
      openQuestions: [
        'Является ли отказ гейта дефектом одной лишь кодогенерации — здесь не установлено: шесть целей не запускаются, и что бы они сообщили, не измерено.',
        'Последний прогон этого гейта на master падал на ДРУГОМ шаге, тремя днями раньше. Жив ли тот отказ сегодня — не показано.',
        'Утверждение «это ничего не стоило» опирается на то, что четыре пул-реквеста не могли задеть кодогенератор. Это довод от того, что они трогали, а не измерение того, что они изменили.',
        'Никакого лекарства не предлагается и не следует вычитывать: сделать эти гейты обязательными или перевести на ручной запуск — решение по настройкам репозитория.',
      ],
    },
  },
  {
    slug: 'the-scanner-scored-what-it-could-not-see',
    title: 'The scanner scored what it could not see',
    summary: 'A mutation tool reported a gate as having no failure path. The gate has four -- all of them ternaries, a form the scanner did not recognise, so it scored them as covered.',
    date: '2026-08-23',
    readingMinutes: 7,
    tags: ['CI', 'Mutation testing', 'Measurement', 'Self-critique'],
    receipts: [
      { label: 'gHashTag/t27 #2470 -- the scanner fix, and the four unit tests including two negative directions', href: 'https://github.com/gHashTag/t27/pull/2470' },
      { label: 'gHashTag/t27 #2468 -- the survivor the tool invented, and the corrected numbers', href: 'https://github.com/gHashTag/t27/issues/2468' },
    ],
    openQuestions: [
      'Whether other syntactic forms of a failing exit are still invisible is not established: the scanner now knows three, and nothing enumerates the set.',
      'The twenty surviving mutants are not shown to be defects. A survivor means nothing proves the gate will stay right, not that it is wrong today.',
      'The mutation operator is a single one -- a verdict forced to zero. Inverting a condition is a different class this run does not cover.',
      'A survivor can mean an unreachable site rather than an uncovered one, and the tool still does not separate the two.',
    ],
    published: true,
    ru: {
      title: 'Сканер засчитал то, чего не видел',
      summary: 'Мутационный инструмент сообщил, что у гейта нет путей отказа. Их четыре — все тернарники, форма, которой сканер не знал, и потому засчитал их покрытыми.',
      openQuestions: [
        'Остались ли невидимыми другие синтаксические формы падающего выхода — не установлено: сканер знает три, и множество никем не перечислено.',
        'Двадцать выживших мутантов не показаны дефектами. Выживший значит «ничто не доказывает, что гейт останется верным», а не «он неверен сейчас».',
        'Мутационный оператор один — вердикт, принудительно обнулённый. Инвертирование условия это другой класс, и он здесь не покрыт.',
        'Выживший может означать недостижимый сайт, а не непокрытый, и инструмент их по-прежнему не разделяет.',
      ],
    },
  },
  {
    slug: 'the-control-that-could-not-fail',
    title: 'The control that could not fail',
    summary: 'Four gates had never been seen red. Writing their negative controls produced one that reported every branch red while the gate it guarded printed OK on a broken catalog.',
    date: '2026-08-23',
    readingMinutes: 9,
    tags: ['CI', 'Negative controls', 'Mutation testing', 'Self-critique'],
    receipts: [
      { label: 'gHashTag/t27 #2467 — the four controls, and the end-to-end layer the first draft lacked', href: 'https://github.com/gHashTag/t27/pull/2467' },
      { label: 'gHashTag/t27 #2465 — four gates with no negative control, and a claim that was not reproducible', href: 'https://github.com/gHashTag/t27/issues/2465' },
      { label: 'gHashTag/t27 #2468 — nine gates whose controls cover the verdict path but not the precondition path', href: 'https://github.com/gHashTag/t27/issues/2468' },
    ],
    openQuestions: [
      'Whether the nine gates with surviving mutants stay correct is not established here: the six baseline-backed ones were checked by hand and go red correctly today, and that is a dated observation, not a standing property.',
      'The shared control pattern for the precondition class is proposed and not written; whether one pattern really covers all six is untested.',
      'The mutation operator is a single one — a verdict-returning line forced to zero. A gate can be broken in ways this operator never produces, so "all killed" bounds one failure mode, not all of them.',
      'A surviving mutant can mean the site is unreachable rather than uncovered, and this run does not separate the two.',
    ],
    published: true,
    ru: {
      title: 'Контроль, который не мог упасть',
      summary: 'Четыре гейта никогда не видели красными. Написание негативных контролей дало один, который рапортовал «все ветки красные», пока охраняемый им гейт печатал OK на сломанном каталоге.',
      openQuestions: [
        'Останутся ли верными девять гейтов с выжившими мутантами — здесь не установлено: шесть baseline-гейтов проверены руками и краснеют корректно сегодня, а это датированное наблюдение, а не постоянное свойство.',
        'Общий образец контроля для класса предусловий предложен, но не написан; покроет ли один образец все шесть — не проверено.',
        'Мутационный оператор здесь один — строка вердикта, принудительно обнулённая. Гейт можно сломать способами, которых этот оператор не порождает: «все убиты» ограничивает одну форму отказа, а не все.',
        'Выживший мутант может означать недостижимый сайт, а не непокрытый, и этот прогон их не разделяет.',
      ],
    },
  },
  {
    slug: 'ternary-won-the-wire-not-the-gate',
    title: 'Ternary won the wire; it did not win the gate',
    summary: 'Base economy is a theorem, not a measurement: 5.66 percent in a 1950 vacuum-tube cost model, a win on the wire in USB4 v2 and GDDR7, and a loss at the gate on noise margin.',
    date: '2026-08-22',
    readingMinutes: 9,
    tags: ['Number formats', 'Arithmetic', 'Signalling', 'History', 'Self-critique'],
    receipts: [
      { label: 'ERA, High-Speed Computing Devices (McGraw-Hill, 1950) — the cost model and its own caveat, pp. 84–87', href: 'https://archive.org/details/HighSpeedComputingDevices' },
      { label: 'J. Steiner, Journal für die reine und angewandte Mathematik 40:208, 1850', href: 'https://www.digizeitschriften.de/download/PPN243919689_0040/PPN243919689_0040___log28.pdf' },
      { label: 'Optimal radix choice — Wikipedia (averaged E(b,N) table)', href: 'https://en.wikipedia.org/wiki/Optimal_radix_choice' },
      { label: 'Steve Weis — Revisiting Radix Economy', href: 'https://saweis.net/posts/Revisiting-Radix-Economy.html' },
      { label: 'Brian Hayes, Third Base, American Scientist 89(6):490, 2001 — ferrite-core pair per trit, 50 machines', href: 'https://web.williams.edu/Mathematics/sjmiller/public_html/105Sp10/addcomments/Hayes_ThirdBase.htm' },
      { label: 'МЦВМ «Сетунь» — Виртуальный компьютерный музей', href: 'https://www.computer-museum.ru/histussr/12-6.htm' },
      { label: 'USB-IF — USB 80G PHY background (PAM-3, 11b/7t, margin table)', href: 'https://www.usb.org/sites/default/files/USB%2080G%20PHY%20background.pdf' },
      { label: 'JEDEC JESD239 GDDR7 press release, 5 March 2024', href: 'https://www.jedec.org/news/pressreleases/jedec-publishes-gddr7-graphics-memory-standard' },
      { label: 'IEEE 802.3bz TF, Souvignier/Feyh, May 2015 — 2.5G/5GBASE-T is PAM-16 / 128-DSQ, not PAM-3', href: 'https://www.ieee802.org/3/bz/public/may15/Souvignier_3bz_01_0515.pdf' },
      { label: 'arXiv:2402.17764 — The Era of 1-bit LLMs (BitNet b1.58)', href: 'https://arxiv.org/abs/2402.17764' },
      { label: 'arXiv:2504.12285 — BitNet b1.58 2B4T Technical Report', href: 'https://arxiv.org/abs/2504.12285' },
      { label: 'arXiv:2207.04839 — Etiemble, ternary and quaternary CNTFET adders less efficient than binary for CPAs', href: 'https://arxiv.org/abs/2207.04839' },
      { label: 'Takbiri, Faghih Mirzaee, Navi, CSSP 38(9):4280–4301, 2019 — overstated noise margins in MVL', href: 'https://link.springer.com/article/10.1007/s00034-019-01063-8' },
      { label: 'The Register, 18 March 2026 — ternary CPU on FPGA (5500FP), two bits per trit', href: 'https://www.theregister.com/2026/03/18/ternary_cpu_on_fpga/' }
    ],
    openQuestions: [
      'Nothing in this post is our measurement: it is a reading of sources, not an experiment on the ALINX AX7203 board and not a silicon result.',
      'The circulating "8,487 values" count and the "40× transistors per trit" figure have no primary source and are not used.',
      'A 2019 Nature Electronics fabricated ternary CNTFET inverter was not found; whether 46 or 50 Setun machines were built stays unresolved.',
      'PAM-3 in mainstream FPGA transceivers is unconfirmed in the checked AMD Versal and Altera Agilex material.',
      'It does not establish any FPGA or silicon cost comparison between ternary and binary arithmetic; the proposed adder experiment has not been run.'
    ],
    published: true,
    ru: {
      title: 'Троичность выиграла провод, но не вентиль',
      summary: 'Экономичность основания — теорема, а не измерение: 5,66 процента в ламповой модели 1950 года, победа на проводе в USB4 v2 и GDDR7 и проигрыш на вентиле по запасу помехоустойчивости.',
      openQuestions: [
        'Ничего в посте не измерено нами: это чтение источников, а не эксперимент на плате ALINX AX7203 и не результат на кристалле.',
        'Ходячее число «8 487 значений» и цифра «40 крат транзисторов на трит» — без первоисточника и не используются.',
        'Публикация Nature Electronics 2019 с изготовленным троичным CNTFET-инвертором не найдена; 46 или 50 «Сетуней» — расхождение остаётся неразрешённым.',
        'PAM-3 в трансиверах mainstream-FPGA не подтверждён в проверенных материалах AMD Versal и Altera Agilex.',
        'Пост не устанавливает никакого сравнения стоимости троичной и двоичной арифметики на FPGA или в кремнии; предложенный замер сумматора не поставлен.'
      ]
    }
  },
  {
    slug: 'the-required-check-was-an-echo',
    title: 'The required check was an echo',
    summary: "One of four required status checks — the ones a branch ruleset will not let a merge past — was a shell command that prints a sentence. Twenty lines, no logic, green on every pull request, required for months. Meanwhile the test suite it was believed to be has never blocked a merge, and thirteen tests fail on the main branch indefinitely because nothing was waiting for them.",
    date: '2026-08-23',
    readingMinutes: 6,
    tags: ['CI', 'Process', 'Measurement', 'Self-critique'],
    receipts: [
      { label: 'The finding, with the three repair options and their costs', href: 'https://github.com/gHashTag/t27/issues/2455' },
      { label: 'The thirteen failing tests, filed long before this', href: 'https://github.com/gHashTag/t27/issues/2292' },
      { label: 'The companion case: a gate that fires, and is merged past anyway', href: 'https://github.com/gHashTag/t27/pull/2450' },
      { label: 'The audit that named the reach class this belongs to', href: 'https://github.com/gHashTag/t27/issues/2325' }
    ],
    openQuestions: [
      'Whether the thirteen failures reproduce on the CI platform is NOT established. They were measured on a different one, and at least one is recorded in older notes as platform-specific. That question has to be answered before pointing the required check at the suite.',
      'Both repairs are branch-ruleset changes, which are repository security settings. Filed with their costs; neither taken. Pointing `check` at the suite blocks every merge until the failures are resolved or ledgered; removing it from the required set costs nothing immediately and makes the list honest at three.',
      'How long the placeholder has been required is not measured here — only that it predates the run window the API returns. The workflow comment says the logic will be added later, and gives no date.'
    ],
    published: true,
    ru: {
      title: 'Обязательная проверка оказалась эхом',
      summary: 'Одна из четырёх обязательных проверок — тех, мимо которых правило ветки не пропустит мерж — оказалась командой оболочки, печатающей предложение. Двадцать строк, никакой логики, зелёная на каждом пул-реквесте, обязательна месяцами. При этом тестовый набор, за который её принимали, никогда не блокировал мерж, и тринадцать тестов падают на главной ветке бессрочно, потому что их никто не ждал.',
      openQuestions: [
        'Воспроизводятся ли те тринадцать падений на платформе CI — НЕ установлено. Мерились они на другой, и хотя бы одно записано в старых заметках как платформенно-специфичное. На этот вопрос нужно ответить прежде, чем направлять обязательную проверку на набор.',
        'Обе починки — правки правила ветки, то есть настройки безопасности репозитория. Заведены с ценой каждой; ни одна не сделана. Направить `check` на набор — заблокировать каждый мерж до устранения или занесения падений в реестр; убрать из обязательного набора — не стоит ничего немедленно и делает список честным на трёх.',
        'Как долго заглушка была обязательной — здесь не измерено; известно лишь, что дольше окна прогонов, которое отдаёт API. Комментарий в workflow обещает добавить логику позже и не называет даты.'
      ]
    }
  },
  {
    slug: 'the-gate-was-right-and-nothing-stopped',
    title: 'The gate was right and nothing stopped',
    summary: "A gate that guards against retracted numbers re-entering live documents caught a violation on the pull request that introduced it — right file, right lines, exit 1 — and the pull request merged anyway, because it is not a required check. It stayed red on main through two more merges. This is the third variant of a reach failure: not ‘it never runs’, not ‘it runs on the wrong diff’, but ‘it runs, it fails, it names the exact lines, and nothing waits for the answer’.",
    date: '2026-08-23',
    readingMinutes: 6,
    tags: ['CI', 'Measurement', 'Self-critique', 'Process'],
    receipts: [
      { label: 'The hardening the note was about — 6 of 7 registry rows could vanish silently', href: 'https://github.com/gHashTag/t27/pull/2447' },
      { label: 'The fix: figures removed from the prose, not added to the exemption list', href: 'https://github.com/gHashTag/t27/pull/2450' },
      { label: 'The audit that named the reach class, and the two variants before this one', href: 'https://github.com/gHashTag/t27/issues/2325' },
      { label: 'Variant one, closed: a self-test present in the tree and invoked by nothing', href: 'https://github.com/gHashTag/t27/pull/2451' }
    ],
    openQuestions: [
      'Whether this gate joins the required set is an owner decision, not an automated one: a branch ruleset is a repository security setting, and quietly widening what blocks other people\u2019s merges is not a repair. Filed, not done.',
      'Two other gates in the same repository are red on main permanently — one has no green run in the last hundred. Their permanent redness is the reason a genuinely new failure in that column reads as background, and no decision has been taken about either.',
      'The figure never reached a reader: no published post carries it and the document is repository-internal. That is a fact about this incident, not a property of the mechanism — nothing in the pipeline made it so.'
    ],
    published: true,
    ru: {
      title: 'Гейт был прав, и ничто не остановилось',
      summary: 'Гейт, охраняющий живые документы от отозванных чисел, поймал нарушение на том же пул-реквесте, который его и внёс — нужный файл, нужные строки, код 1 — и пул-реквест всё равно смержился, потому что он не обязателен. Третий вариант отказа по достижимости: не «не запускается» и не «запускается не на том диффе», а «запускается, падает, называет точные строки — и ответа никто не ждёт».',
      openQuestions: [
        'Войдёт ли этот гейт в обязательный набор — решение владельца, не автомата: правила ветки — это настройка безопасности, и тихо расширить то, что блокирует чужие мержи, — не починка. Заведено, не сделано.',
        'Два других гейта в том же репозитории красны на main постоянно — у одного нет зелёного прогона за последнюю сотню. Именно эта постоянная краснота делает новый отказ в той же колонке фоном, и ни по одному решения не принято.',
        'Число до читателя не дошло: ни один опубликованный пост его не несёт, документ внутренний. Это факт об инциденте, а не свойство механизма — ничто в конвейере его не обеспечило.'
      ]
    }
  },
  {
    slug: 'the-ratchet-counted-a-total-as-an-error',
    title: 'The ratchet counted a total as an error',
    summary: "A gate written to stop elaboration errors creeping back reported 186 of them; 25 were the compiler's own summary line saying how many errors it had found. The number had already reached commit messages and a status page. This is the proof that could not have come out any other way, the live emitter defect that was hiding inside the count, why fixing it made the number worse, and one fix that was built, measured, and thrown away.",
    date: '2026-08-23',
    readingMinutes: 8,
    tags: ['CI', 'Measurement', 'Self-critique', 'FPGA', 'Compilers'],
    receipts: [
      { label: 'The phantom count, with the three quantities that agree on 25', href: 'https://github.com/gHashTag/t27/pull/2435' },
      { label: 'The emitter defect that was hiding inside the number', href: 'https://github.com/gHashTag/t27/pull/2438' },
      { label: 'The full classification of all 161 errors', href: 'https://github.com/gHashTag/t27/issues/2325' },
      { label: 'The fix that was measured as a regression and discarded', href: 'https://github.com/gHashTag/t27/issues/2439' },
      { label: 'The three lessons, written into the gate skill', href: 'https://github.com/gHashTag/t27/pull/2437' }
    ],
    openQuestions: [
      'The count is instrument-relative: it is produced by one iverilog version, and an upgrade on the runner can move it without any compiler change. The baseline now records the version and names a mismatch instead of reporting it as a regression, but no cross-version measurement has been taken.',
      'Two design decisions still own 64 of the 161 errors: what a string field means in generated hardware, and whether unsized array parameters should be rejected at typecheck. Both are filed with costs and a recommendation; neither is decided.',
      'A separate seal-coverage gate has failed on master in every one of the last hundred runs, reporting 136 stale seals, while its own negative self-check passes. It is not a required check, so it blocks nothing — which is the more dangerous reading, not the milder one.'
    ],
    published: true,
    ru: {
      title: 'Храповик посчитал итог за ошибку',
      summary: 'Гейт, написанный чтобы ошибки элаборации не возвращались, сообщил про 186 штук; 25 из них были собственной итоговой строкой компилятора о том, сколько ошибок он нашёл. Число уже успело уехать в коммиты и на страницу статуса. Доказательство, которое не могло получиться иначе, живой дефект эмиттера, прятавшийся внутри счёта, почему от починки число стало хуже, и одна починка, которую построили, измерили и выбросили.',
      openQuestions: [
        'Число зависит от прибора: его выдаёт одна версия iverilog, и обновление на раннере сдвинет его без единой правки компилятора. Baseline теперь хранит версию и называет расхождение вместо того, чтобы читать его как регрессию, но межверсионного замера никто не делал.',
        'За 64 из 161 ошибки по-прежнему отвечают два решения: что значит строковое поле в сгенерированном железе и надо ли отвергать безразмерные массивы-параметры на typecheck. Оба заведены с ценой и рекомендацией; ни одно не принято.',
        'Отдельный гейт печатей падает на master во всех ста последних прогонах, сообщая про 136 устаревших печатей, при этом его собственный негативный самоконтроль проходит. Он не обязателен и ничего не блокирует — и это более опасное чтение, а не более мягкое.'
      ]
    }
  },
  {
    slug: 'four-hundred-and-twelve-tests-that-were-sentences',
    title: 'Four hundred and twelve tests that were sentences',
    summary: 'Thirty-four conformance vector files, 512 cases, zero ever executed — and when counted, 412 of those cases carried no inputs and no expected values at all. This is how a corpus becomes decorative, why the first classifier reported 147 where an independent pass said 100, and the three-verdict registry (executed / numbered debt / aspirational) that lets a small true number replace a large false one.',
    date: '2026-08-22',
    readingMinutes: 7,
    tags: ['Testing', 'CI', 'FPGA', 'Measurement', 'Self-critique'],
    receipts: [
      { label: 'The lane where the corpus was first executed at all', href: 'https://github.com/gHashTag/t27/issues/2241' },
      { label: 'The measurement, with the instrument contradiction disclosed', href: 'https://github.com/gHashTag/t27/pull/2421' },
      { label: 'The ratchet: a new prose-only vector file now fails CI', href: 'https://github.com/gHashTag/t27/pull/2423' },
      { label: 'Second module executed, and a self-correction on what was blocked', href: 'https://github.com/gHashTag/t27/pull/2422' }
    ],
    openQuestions: [
      'What happens to the 24 prose-only files is an owner decision: give them data, move them somewhere that does not read as coverage, or delete them. The gate only stops the 25th.',
      'Nine data-carrying files remain unexecuted; three of them are blocked by real elaboration errors, and the deepest blocker (slice parameters lowering to scalars) is a corpus-wide language decision affecting 2,313 occurrences across 237 specs.',
      'Executed coverage is 21 cases across two modules (18 + 3). The body of this post first said nineteen for the first module; the runner prints eighteen, and the correction is stated in place rather than made silently.'
    ],
    published: true,
    ru: {
      title: 'Четыреста двенадцать тестов, которые были предложениями',
      summary: 'Тридцать четыре файла conformance-векторов, 512 кейсов, ни один никогда не исполнялся — а когда посчитали, 412 из них не несли ни входов, ни ожидаемых значений. Как корпус становится декоративным, почему первый классификатор дал 147 там, где независимый проход дал 100, и трёхвердиктный реестр (исполняется / именованный долг / аспирационное), позволяющий заменить большое ложное число маленьким истинным.',
      openQuestions: [
        'Судьба 24 описательных файлов — решение владельца: дать им данные, перенести туда, где они не читаются как покрытие, или удалить. Гейт лишь останавливает двадцать пятый.',
        'Девять файлов с данными не исполняются; три заблокированы настоящими ошибками элаборации, а глубочайший блокер (слайс-параметры, опускающиеся в скаляры) — корпусное языковое решение: 2313 вхождений в 237 спеках.',
        'Исполняемое покрытие — 21 кейс в двух модулях (18 + 3). В теле поста сначала стояло «девятнадцать» для первого; раннер печатает восемнадцать, и поправка сделана на месте, а не молча.'
      ]
    }
  },
  {
    "slug": "equal-stored-width-removed-an-accuracy-lead",
    "title": "Equal stored width removed an accuracy lead",
    "summary": "A corrected equal-stored-width remeasurement withdrew an earlier 2.1×/2.6× lead over takum and records the oracle and budget defects that changed the reading.",
    "date": "2026-08-21",
    "readingMinutes": 6,
    "tags": [
      "Measurement",
      "Reproducibility",
      "Self-critique",
      "FPGA",
      "Accuracy"
    ],
    "receipts": [
      {
        "label": "gHashTag/trinity PR #857 — merged correction and retraction",
        "href": "https://github.com/gHashTag/trinity/pull/857"
      },
      {
        "label": "Merged commit 22cd9596 — the site correction",
        "href": "https://github.com/gHashTag/trinity/commit/22cd9596b2688ba7eda68711a2b5be32b004d418"
      },
      {
        "label": "Equal-stored-width measurement note",
        "href": "https://github.com/gHashTag/trinity-fpga/blob/main/research/TEKUM_VS_TNF_LINE_2026-08-19.md"
      }
    ],
    "openQuestions": [
      "This is an equal-stored-width software/oracle remeasurement, not a measurement on the binary ALINX AX7203 FPGA and not a custom-silicon result.",
      "It does not provide a head-to-head hardware comparison against takum.",
      "It does not establish downstream model accuracy, throughput, energy, or area.",
      "It does not establish a universal accuracy ranking for numerical formats; the corrected rows only replace one withdrawn claim."
    ],
    "published": true,
    "ru": {
      "title": "Равная ширина хранения сняла выигрыш по точности",
      "summary": "Повторное измерение при равной ширине хранения отозвало прежний выигрыш 2,1×/2,6× над takum и зафиксировало дефекты оракула и бюджета, изменившие интерпретацию.",
      "openQuestions": [
        "Это повторное измерение оракулов при равной ширине хранения, а не измерение на бинарной FPGA ALINX AX7203 и не результат на изготовленном кристалле.",
        "Оно не даёт прямого аппаратного сравнения с takum.",
        "Оно не устанавливает точность downstream-модели, пропускную способность, энергию или площадь.",
        "Оно не устанавливает универсальный рейтинг точности числовых форматов; исправленные строки только заменяют одно отозванное утверждение."
      ]
    }
  },
  {
    "slug": "thirty-epochs-exposed-a-failure-rate-blind-spot",
    "title": "Thirty epochs exposed a failure-rate blind spot",
    "summary": "A 30-epoch MNIST sweep showed why a failure-rate threshold needs the per-seed values beside it: a passing count can coexist with non-overlapping runs.",
    "date": "2026-08-20",
    "readingMinutes": 6,
    "tags": [
      "FPGA",
      "MNIST",
      "Measurement",
      "Reproducibility",
      "Self-critique"
    ],
    "receipts": [
      {
        "label": "gHashTag/trinity-fpga PR #660 — merged experiment and blind-spot correction",
        "href": "https://github.com/gHashTag/trinity-fpga/pull/660"
      },
      {
        "label": "Thirty-epoch report at the merged commit",
        "href": "https://github.com/gHashTag/trinity-fpga/blob/21c72a2bd066e3041f6577c35d3189f02041c30e/docs/THIRTY-EPOCHS.md"
      },
      {
        "label": "Five-seed MNIST measurement JSON",
        "href": "https://github.com/gHashTag/trinity-fpga/blob/21c72a2bd066e3041f6577c35d3189f02041c30e/research/arxiv_tnf/measurements/stability_mnist_30ep_2026-08-20.json"
      }
    ],
    "openQuestions": [
      "This is a measured MNIST training sweep, not a measurement on the ALINX AX7203 FPGA and not a silicon result.",
      "It does not establish a universal accuracy or failure-rate ranking for TNF4, fp6 e2m3, or fp6 e3m2.",
      "It does not show that a 60% threshold is the right threshold for another task, seed set, or training recipe.",
      "The experiment does not establish transfer beyond this MNIST configuration; the per-seed list improves the audit trail but does not remove that scope limit."
    ],
    "published": true,
    "ru": {
      "title": "Тридцать эпох выявили слепую зону доли отказов",
      "summary": "Тридцатиэпоховый sweep на MNIST показал, почему рядом с порогом по доле отказов нужны значения по каждому seed: счёт «прошёл» может сосуществовать с неперекрывающимися прогонами.",
      "openQuestions": [
        "Это измеренный обучающий sweep на MNIST, а не измерение на FPGA ALINX AX7203 и не результат на кремнии.",
        "Он не устанавливает универсальный рейтинг точности или доли отказов для TNF4, fp6 e2m3 или fp6 e3m2.",
        "Он не показывает, что порог 60% подходит для другой задачи, набора seed или рецепта обучения.",
        "Эксперимент не устанавливает переносимость за пределы этой конфигурации MNIST; список по seed улучшает аудит, но не снимает ограничение области."
      ]
    }
  },
  {
    slug: 'formal-was-green-and-had-never-run-a-solver',
    title: 'Formal was green and had never run a solver',
    summary: 'A formal verification job stayed green its whole life while three independent mechanisms each guaranteed it could never go red — pseudo-syntax configs, a pipe that tested tee instead of the tool, and continue-on-error over everything. Peeling it to the first genuine proof took seven named layers, including RTL four months older than the compiler under test and property files that never instantiated the DUT. It ends with the repository’s first real formal verdicts: fifo and mac, Status PASSED under z3.',
    date: '2026-08-20',
    readingMinutes: 8,
    tags: ['CI', 'Formal', 'FPGA', 'Debugging', 'Self-critique'],
    receipts: [
      { label: 'The audit issue: three vacuous greens, each confirmed by two refuters', href: 'https://github.com/gHashTag/t27/issues/2239' },
      { label: 'Layer 6 — formal tested April-vintage RTL shadowing the fresh artifact', href: 'https://github.com/gHashTag/t27/issues/2261' },
      { label: 'Layer 7 — props never instantiated the DUT', href: 'https://github.com/gHashTag/t27/issues/2265' },
      { label: 'The latch finding that parked the third module', href: 'https://github.com/gHashTag/t27/issues/2266' },
      { label: 'The master run with the first green formal carrying real verdicts', href: 'https://github.com/gHashTag/t27/actions/runs/32315356476' }
    ],
    openQuestions: [
      'The proven properties are thin: two of three modules currently expose no data ports, so their one provable invariant is a constant handshake line. The property sets are skeletons that grow with the ports — they are not a functional verification of FIFO or MAC semantics.',
      'The third module (uart) is parked on a real design defect: a latch with combinational feedback inferred by the code generator. Its invariant is simulation-checked (256/256), not proven.',
      'The conformance job remains honestly red: its vectors have never been executed against RTL, and its repair is a redesign, not a patch.'
    ],
    published: true,
    ru: {
      title: 'Формал был зелёным и ни разу не запускал солвер',
      summary: 'Задача формальной верификации оставалась зелёной всю жизнь, пока три независимых механизма гарантировали, что красной она стать не может: псевдо-синтаксис конфигов, пайп, проверявший tee вместо инструмента, и continue-on-error поверх всего. Путь до первого настоящего доказательства занял семь именованных слоёв — включая RTL на четыре месяца старше тестируемого компилятора и property-файлы, никогда не инстанцировавшие DUT. Финал — первые настоящие формальные вердикты репозитория: fifo и mac, Status PASSED под z3.',
      openQuestions: [
        'Доказанные свойства тонкие: два модуля из трёх пока не выставляют data-портов, и их единственный доказуемый инвариант — константная линия хендшейка. Наборы свойств — скелеты, растущие вместе с портами, а не функциональная верификация семантики FIFO или MAC.',
        'Третий модуль (uart) запаркован на настоящем дефекте дизайна: защёлка с комбинационной обратной связью, выведенная кодогенератором. Его инвариант проверен симуляцией (256/256), не доказан.',
        'Conformance-job остаётся честно красным: его векторы никогда не исполнялись против RTL, и ремонт — редизайн, а не патч.'
      ]
    }
  },
  {
    slug: 'fourteen-rows-agreed-one-did-not',
    title: 'Fourteen rows agreed; one did not',
    summary: 'A post-route CI run gives fifteen instrumented FPGA frequency rows a sourced comparison: fourteen fall inside the flow’s measured noise band, while LNS16 remains an explicit exception and one design is still uninstrumented.',
    date: '2026-08-19',
    readingMinutes: 6,
    tags: ['FPGA', 'CI', 'Measurement', 'Reproducibility', 'Self-critique'],
    receipts: [
      { label: 'gHashTag/trinity-fpga PR #624 — merged G8 verdict', href: 'https://github.com/gHashTag/trinity-fpga/pull/624' },
      { label: 'Public CI run 32263875250 — post-route measurement', href: 'https://github.com/gHashTag/trinity-fpga/actions/runs/32263875250' },
      { label: 'docs/G8-VERDICT.md at the merged commit', href: 'https://github.com/gHashTag/trinity-fpga/blob/6f0d1882efdad37f2af8cd415a50d2cd4ac45828/docs/G8-VERDICT.md' },
      { label: 'Merged commit 6f0d1882 — the published verdict', href: 'https://github.com/gHashTag/trinity-fpga/commit/6f0d1882efdad37f2af8cd415a50d2cd4ac45828' }
    ],
    openQuestions: [
      'This is post-route CI evidence for the target part, not a UART or physical-board measurement on the ALINX AX7203.',
      'The LNS16 mismatch has no diagnosed cause. An original log or an explicit supersession is still needed.',
      'The plastic-16bit row remains uninstrumented; its published frequency is not validated by this run.',
      'No throughput, energy, model-accuracy, or downstream-workload result is established by this audit.'
    ],
    published: true,
    ru: {
      title: 'Четырнадцать строк согласовались, одна — нет',
      summary: 'Post-route CI-прогон дал пятнадцати инструментированным строкам FPGA-частот сравнение с источником: четырнадцать попали внутрь измеренного шума потока, а LNS16 осталось явным исключением и один дизайн по-прежнему не инструментирован.',
      openQuestions: [
        'Это post-route-свидетельство CI для целевой детали, а не UART- или физическое измерение на плате ALINX AX7203.',
        'Причина расхождения LNS16 не установлена. Нужен исходный лог или явное указание, что опубликованная строка заменена.',
        'Строка plastic-16bit остаётся без инструментирования; её опубликованная частота этим прогоном не подтверждена.',
        'Этот аудит не устанавливает пропускную способность, энергию, точность модели или результат на downstream-нагрузке.'
      ]
    }
  },
  {
    slug: 'a-clean-merge-is-not-a-semantic-no-op',
    title: 'A clean merge is not a semantic no-op',
    summary: 'Two autonomous agents, one repository, a 643-commit wave merged mid-flight. The four textual conflicts were the safe part — three were comment-only and one was both sides fixing the same bug. The defect that reached master rode in on a hunk that merged cleanly: a device-default flip that a CI workflow relied on as an absence, which cannot conflict. It passed place-and-route on the wrong database and failed at the first step that looks a name up instead of trusting a path.',
    date: '2026-08-19',
    readingMinutes: 7,
    tags: ['CI', 'Git', 'Multi-agent', 'FPGA', 'Debugging'],
    receipts: [
      { label: 'The first master run after the merge — 7/8 green, fasm2frames red', href: 'https://github.com/gHashTag/t27/actions/runs/32255921048' },
      { label: 'Issue #2225 — the device-default regression, diagnosed', href: 'https://github.com/gHashTag/t27/issues/2225' },
      { label: 'PR #2226 — the one-flag fix: state the device explicitly', href: 'https://github.com/gHashTag/t27/pull/2226' },
      { label: 'PR #2216 — the fourteen-commit branch the wave merged against', href: 'https://github.com/gHashTag/t27/pull/2216' }
    ],
    openQuestions: [
      'The driver still does not assert that the chipdb filename and the requested device agree; the mismatch would then fail at place-and-route instead of two steps later. Filed as open work in #2225, not claimed as done.',
      'At the time of writing the first master run with the fix is queued, not finished — this post does not claim the green run it hopes for.',
      'The standing caveat is unchanged: no bitstream from this pipeline has ever been loaded onto a board.'
    ],
    published: true,
    ru: {
      title: 'Чистый merge — не семантический no-op',
      summary: 'Два автономных агента, один репозиторий, волна в 643 коммита, влитая посреди полёта. Четыре текстовых конфликта оказались безопасной частью — три были конфликтами комментариев, а в четвёртом обе стороны чинили один и тот же баг. Дефект, доехавший до master, приехал в чисто слившемся хабе: смена устройства по умолчанию, на которое CI-workflow опирался отсутствием флага, — а отсутствие конфликтовать не может. Он прошёл place-and-route по чужой базе и упал на первом шаге, который ищет имя, а не доверяет пути.',
      openQuestions: [
        'Драйвер по-прежнему не проверяет согласие имени файла базы кристалла с запрошенным устройством; тогда расхождение падало бы на place-and-route, а не двумя шагами позже. Записано открытой работой в #2225.',
        'На момент написания первый master-прогон с фиксом стоит в очереди, не завершён — пост не заявляет зелёного прогона, на который надеется.',
        'Постоянная оговорка неизменна: ни один битстрим этого конвейера не загружался в плату.'
      ]
    }
  },
  {
    slug: 'the-tail-that-had-never-run',
    title: 'The tail that had never run',
    summary: 'A bitstream-generating CI job was red for eleven days. Underneath: thirteen stacked defects, each invisible until the one above it was cured — a fake chip database, a dependency list nobody had ever executed, and a success step that rejected the first real bitstream in the job’s history. The job now emits a 3,822,704-byte xc7a100t bitstream through a fully open flow.',
    date: '2026-08-19',
    readingMinutes: 9,
    tags: ['CI', 'FPGA', 'openXC7', 'Debugging', 'Self-critique'],
    receipts: [
      { label: 'gHashTag/t27 PR #2216 — the pull request carrying all thirteen layers', href: 'https://github.com/gHashTag/t27/pull/2216' },
      { label: 'The first run to produce a real bitstream — fpga-bitstream job log', href: 'https://github.com/gHashTag/t27/actions/runs/32247529041' },
      { label: 'Issue #2214 — the red-since-birth diagnosis across jobs', href: 'https://github.com/gHashTag/t27/issues/2214' },
      { label: 'Issue #2215 — fpga-build: every job red, root causes enumerated', href: 'https://github.com/gHashTag/t27/issues/2215' },
      { label: 'openXC7/nextpnr-xilinx — the fork that actually contains the xilinx architecture', href: 'https://github.com/openXC7/nextpnr-xilinx' }
    ],
    openQuestions: [
      'The bitstream has never been loaded onto a board. The CI machine has no FPGA attached, so correctness beyond the toolchain’s own internal checks — including whether the design does anything at all on silicon — is unproven. Flashing on real hardware is the only test that counts, and it has not happened for this artifact.',
      'Timing comes from nextpnr’s model, not from measurement. No Fmax claim is made and none should be inferred.',
      'The flow builds the minimal profile only; the larger profiles have not been through the repaired pipeline.',
      'The apt-mirror hangs that burned whole timeout ceilings are bounded, not fixed — a retry-with-timeout patch for the install steps exists but has not landed.'
    ],
    published: true,
    ru: {
      title: 'Хвост, который никогда не исполнялся',
      summary: 'Собирающая битстрим CI-задача была красной одиннадцать дней. Под этим — тринадцать слоёв дефектов, каждый невидим, пока не вылечен верхний: фальшивая база кристалла, список зависимостей, который никто не исполнял, и шаг успеха, отвергнувший первый настоящий битстрим в истории задачи. Теперь задача выдаёт битстрим xc7a100t в 3 822 704 байта через полностью открытый поток.',
      openQuestions: [
        'Битстрим ни разу не загружался в плату: у CI-машины нет FPGA, и корректность за пределами внутренних проверок тулчейна не доказана. Единственный значимый тест — прошивка живого железа — для этого артефакта не проводился.',
        'Тайминг — из модели nextpnr, а не из измерения. Никакого заявления о Fmax не делается.',
        'Поток собирает только минимальный профиль; большие профили через починенный конвейер не проходили.',
        'Зависания apt-зеркала, сжигавшие целые потолки времени, ограничены, но не устранены — патч с timeout+retry готов, но не влит.'
      ]
    }
  },
  {
    slug: 'receipts-and-seals-over-radio',
    title: 'Receipts and coverage seals over a radio mesh',
    summary: 'Bytes crossed two radio hops between four boards and arrived byte-exact, with one coverage seal recomputed independently at three points and agreeing at all three. What that proves, what it does not, what the thing is built on, and where the commercial radios are plainly ahead.',
    date: '2026-08-19',
    readingMinutes: 21,
    tags: ['Mesh', 'DePIN', 'Verifiable compute', 'Zynq', 'openXC7'],
    receipts: [
      { label: 'smoke/DEPIN_2HOP_RELAY_2026-07-18.md \u2014 two radio hops, seal 0x9DBE2510 identical at three points', href: 'https://github.com/gHashTag/tri-net/blob/main/smoke/DEPIN_2HOP_RELAY_2026-07-18.md' },
      { label: 'smoke/DEPIN_STREAMING_4NODE_2026-07-18.md \u2014 four nodes, three independent witnesses, seal 0xCDB1F3B1', href: 'https://github.com/gHashTag/tri-net/blob/main/smoke/DEPIN_STREAMING_4NODE_2026-07-18.md' },
      { label: 'smoke/DEPIN_OTA_CLOSED_2026-07-18.md \u2014 8 bytes over the air, corr_peak 1.000, BER 0/64, twice', href: 'https://github.com/gHashTag/tri-net/blob/main/smoke/DEPIN_OTA_CLOSED_2026-07-18.md' },
      { label: 'docs/VERIFIABLE_COMPUTE.md \u2014 GF-T16 multiply 5/5 and dot2 3/3 bit-exact on Artix-7 over UART', href: 'https://github.com/gHashTag/tri-net/blob/main/docs/VERIFIABLE_COMPUTE.md' },
      { label: '26 patches merged into openXC7/nextpnr-xilinx \u2014 the largest single contribution to that project', href: 'https://github.com/openXC7/nextpnr-xilinx/pulls?q=is%3Apr+author%3AgHashTag+is%3Amerged' },
      { label: 'arXiv:2606.09686 \u2014 83-format numeric catalog with bit-exact conformance vectors', href: 'https://arxiv.org/abs/2606.09686' }
    ],
    openQuestions: [
      'No throughput figure exists. Mesh capacity per hop has never been measured, and neither has the falloff across two to four hops \u2014 the axis on which a buyer actually chooses. For scale, the NASA report on Doodle Labs gives 37.9, 5.6, 1.2 and 0.3 Mbit/s at one to four hops. There is nothing to put beside it.',
      'Demodulation is an offline batch, roughly three seconds per sixteen megabytes on the ARM core. The capture is continuous and loses no samples; the processing is not real time, and the four-node result should be read as provenance rather than as a live link.',
      'Self-healing convergence time has never been measured on hardware. The target is under five seconds for a link, and no field run exists.',
      'Power and SWaP are unmeasured; the budget is not finalised.',
      'No silicon of our own exists. The TTSKY26b tape-out was withdrawn and there is no fabrication route, so every claim that depends on a Trinity die is open. The bit-exact compute results are on a commodity Artix-7, not on a custom part.',
      'The band actually transmitted on is 2.4 GHz ISM, and the regulatory note in the repository covers 5.8 GHz only. That is a documentation gap rather than a measurement one, and it is being closed.'
    ],
    published: true,
    ru: {
      title: '\u041a\u0432\u0438\u0442\u0430\u043d\u0446\u0438\u0438 \u0438 \u043f\u0435\u0447\u0430\u0442\u0438 \u043f\u043e\u043a\u0440\u044b\u0442\u0438\u044f \u0447\u0435\u0440\u0435\u0437 \u0440\u0430\u0434\u0438\u043e\u0441\u0435\u0442\u044c',
      summary: '\u0411\u0430\u0439\u0442\u044b \u043f\u0440\u043e\u0448\u043b\u0438 \u0434\u0432\u0430 \u0440\u0430\u0434\u0438\u043e\u0441\u043a\u0430\u0447\u043a\u0430 \u043c\u0435\u0436\u0434\u0443 \u0447\u0435\u0442\u044b\u0440\u044c\u043c\u044f \u043f\u043b\u0430\u0442\u0430\u043c\u0438 \u0438 \u043f\u0440\u0438\u0448\u043b\u0438 \u0431\u0430\u0439\u0442-\u0432-\u0431\u0430\u0439\u0442, \u0430 \u043f\u0435\u0447\u0430\u0442\u044c \u043f\u043e\u043a\u0440\u044b\u0442\u0438\u044f, \u043f\u0435\u0440\u0435\u0441\u0447\u0438\u0442\u0430\u043d\u043d\u0430\u044f \u043d\u0435\u0437\u0430\u0432\u0438\u0441\u0438\u043c\u043e \u0432 \u0442\u0440\u0451\u0445 \u0442\u043e\u0447\u043a\u0430\u0445, \u0441\u043e\u0448\u043b\u0430\u0441\u044c \u0432\u043e \u0432\u0441\u0435\u0445 \u0442\u0440\u0451\u0445. \u0427\u0442\u043e \u044d\u0442\u043e \u0434\u043e\u043a\u0430\u0437\u044b\u0432\u0430\u0435\u0442, \u0447\u0435\u0433\u043e \u043d\u0435 \u0434\u043e\u043a\u0430\u0437\u044b\u0432\u0430\u0435\u0442, \u043d\u0430 \u0447\u0451\u043c \u0432\u0441\u0451 \u044d\u0442\u043e \u0441\u0434\u0435\u043b\u0430\u043d\u043e \u0438 \u0433\u0434\u0435 \u0441\u0435\u0440\u0438\u0439\u043d\u044b\u0435 \u0440\u0430\u0434\u0438\u043e\u0441\u0442\u0430\u043d\u0446\u0438\u0438 \u043e\u0442\u043a\u0440\u043e\u0432\u0435\u043d\u043d\u043e \u0432\u043f\u0435\u0440\u0435\u0434\u0438.',
      openQuestions: [
        '\u0427\u0438\u0441\u043b\u0430 \u043f\u0440\u043e\u043f\u0443\u0441\u043a\u043d\u043e\u0439 \u0441\u043f\u043e\u0441\u043e\u0431\u043d\u043e\u0441\u0442\u0438 \u043d\u0435 \u0441\u0443\u0449\u0435\u0441\u0442\u0432\u0443\u0435\u0442. \u0401\u043c\u043a\u043e\u0441\u0442\u044c \u043d\u0430 \u0441\u043a\u0430\u0447\u043e\u043a \u043d\u0435 \u0438\u0437\u043c\u0435\u0440\u044f\u043b\u0430\u0441\u044c \u043d\u0438 \u0440\u0430\u0437\u0443.',
        '\u0414\u0435\u043c\u043e\u0434\u0443\u043b\u044f\u0446\u0438\u044f \u2014 \u043e\u0444\u043b\u0430\u0439\u043d\u043e\u0432\u044b\u0439 \u0431\u0430\u0442\u0447, \u043e\u043a\u043e\u043b\u043e \u0442\u0440\u0451\u0445 \u0441\u0435\u043a\u0443\u043d\u0434 \u043d\u0430 \u0448\u0435\u0441\u0442\u043d\u0430\u0434\u0446\u0430\u0442\u044c \u043c\u0435\u0433\u0430\u0431\u0430\u0439\u0442.',
        '\u0412\u0440\u0435\u043c\u044f \u0441\u0430\u043c\u043e\u0432\u043e\u0441\u0441\u0442\u0430\u043d\u043e\u0432\u043b\u0435\u043d\u0438\u044f \u043d\u0430 \u0436\u0435\u043b\u0435\u0437\u0435 \u043d\u0435 \u0438\u0437\u043c\u0435\u0440\u044f\u043b\u043e\u0441\u044c.',
        '\u042d\u043d\u0435\u0440\u0433\u043e\u043f\u043e\u0442\u0440\u0435\u0431\u043b\u0435\u043d\u0438\u0435 \u0438 SWaP \u043d\u0435 \u0438\u0437\u043c\u0435\u0440\u044f\u043b\u0438\u0441\u044c.',
        '\u0421\u0432\u043e\u0435\u0433\u043e \u043a\u0440\u0438\u0441\u0442\u0430\u043b\u043b\u0430 \u043d\u0435 \u0441\u0443\u0449\u0435\u0441\u0442\u0432\u0443\u0435\u0442: \u0437\u0430\u044f\u0432\u043a\u0430 TTSKY26b \u043e\u0442\u043e\u0437\u0432\u0430\u043d\u0430.',
        '\u041f\u043e\u043b\u043e\u0441\u0430 \u043f\u0435\u0440\u0435\u0434\u0430\u0447\u0438 \u2014 2,4 \u0413\u0413\u0446 ISM, \u0430 \u0440\u0435\u0433\u0443\u043b\u044f\u0442\u043e\u0440\u043d\u0430\u044f \u0437\u0430\u043f\u0438\u0441\u043a\u0430 \u043d\u0430\u043f\u0438\u0441\u0430\u043d\u0430 \u043f\u0440\u043e 5,8 \u0413\u0413\u0446.'
      ]
    }
  },
  {
    slug: 'the-full-adder-made-the-cost-claim-comparable',
    title: 'The full adder made the cost claim comparable',
    summary: 'A merged FPGA-repository PR replaces a magnitude-only comparison with a full adder and reports 3000 oracle checks, 0 errors, and a 440-LUT post-synthesis result.',
    date: '2026-08-18',
    readingMinutes: 5,
    tags: ['FPGA', 'Measurement', 'Arithmetic', 'Self-critique'],
    receipts: [
      { label: 'gHashTag/trinity-fpga PR #605 — full adder and corrected cost comparison', href: 'https://github.com/gHashTag/trinity-fpga/pull/605' },
      { label: 'merged commit e25bf05 — implementation and audit record', href: 'https://github.com/gHashTag/trinity-fpga/commit/e25bf05a368296331b22a38caea610e4fdc4d46b' },
      { label: 'tef_add_full.v at the merged revision', href: 'https://github.com/gHashTag/trinity-fpga/blob/e25bf05a368296331b22a38caea610e4fdc4d46b/fpga/tef/tef_add_full.v' },
      { label: 'FULL_ADDER.md at the merged revision', href: 'https://github.com/gHashTag/trinity-fpga/blob/e25bf05a368296331b22a38caea610e4fdc4d46b/fpga/tef/FULL_ADDER.md' }
    ],
    openQuestions: [
      'The 1182-LUT opponent is an internal linear structural model, not the published takum format; the post does not claim a published-format comparison.',
      'The counts are from Yosys 0.65 post-synthesis with synth_xilinx, xc7 family and DSP disabled. Place-and-route and AX7203 board measurement were not performed.',
      'No throughput, energy, downstream workload, or accuracy result is established.',
      'The 3000-pair check validates this RTL against the oracle encode; it does not prove the oracle’s broader numerical semantics.'
    ],
    published: true,
    ru: {
      title: 'Полный сумматор сделал сравнение цены сопоставимым',
      summary: 'Смерженный PR в FPGA-репозитории заменяет сравнение только модулей полным сумматором и сообщает о 3000 проверках оракулом, 0 ошибках и результате 440 LUT после синтеза.',
      openQuestions: [
        'Оппонент на 1182 LUT — внутренняя линейная структурная модель, а не опубликованный формат takum; сравнение с опубликованным форматом не заявляется.',
        'Числа получены после синтеза Yosys 0.65 с synth_xilinx для xc7 и отключёнными DSP. Place-and-route и замер на AX7203 не выполнялись.',
        'Пропускная способность, энергия, реальная нагрузка и точность не измерялись.',
        'Проверка 3000 пар подтверждает этот RTL против encode оракула, но не доказывает всю числовую семантику оракула.'
      ]
    }
  },
  {
    slug: 'phi-is-a-scale-not-information',
    title: 'The golden ratio in this format is a scale factor, not information',
    summary: 'A format with phi in its name. Measured: in the two-bit digit alphabet phi is not observable at all, and a dot product of GFTernary vectors is exactly phi-squared times the same codes read as balanced ternary. The prior art put phi where it does carry information — in 2002.',
    date: '2026-08-18',
    readingMinutes: 8,
    tags: ['Number formats', 'Measurement', 'Self-critique', 'FPGA'],
    receipts: [
      { label: 'gHashTag/trinity-fpga #582 — the native phi check, mutation-tested', href: 'https://github.com/gHashTag/trinity-fpga/pull/582' },
      { label: 'gHashTag/trinity-fpga #584 — 1654 cells against 13, and 16/16 equivalent', href: 'https://github.com/gHashTag/trinity-fpga/pull/584' },
      { label: 'gHashTag/t27 #2177 — tri mutate, the command that found the third vacuous check', href: 'https://github.com/gHashTag/t27/pull/2177' },
      { label: 'Stakhov, The Computer Journal 45(2):221-236 (2002) — phi in the positional weights', href: 'https://doi.org/10.1093/comjnl/45.2.221' },
      { label: 'Bergman, Mathematics Magazine 31:98-110 (1957) — the base-phi system underneath it', href: 'https://doi.org/10.2307/3029218' }
    ],
    openQuestions: [
      'The area comparison is one multiplier on Yosys 0.65. Whether a board-level synthesis folds the fp32 path or pays for it has not been measured, and that is the number that decides whether this matters in practice.',
      'The RTL quantiser has an asymmetric dead zone (+0.25 against 0.5) where the oracle documents a pure sign rule. They agree on every reachable input today. Nothing checks that they still agree if the input set widens.',
      'The mirror-symmetric prior art was reproduced for N = 0..12 by exhaustive search. No claim is made about larger N, and no adder was built.',
      'Whether phi as an exponent base would beat base 2 on a real workload is untested. It is not used as a base anywhere in this codebase — the ladders are base 2, and one is base 3.'
    ],
    published: true,
    ru: {
      title: 'Золотое сечение в этом формате — масштаб, а не информация',
      summary: 'Формат, у которого φ в названии. Измерено: в двухбитном алфавите цифр φ вообще не наблюдаем, а скалярное произведение векторов GFTernary точно равно φ² на те же коды, прочитанные как сбалансированная троичная. Предшествующая работа поставила φ туда, где он несёт информацию, ещё в 2002-м.',
      openQuestions: [
        'Сравнение площади — один умножитель на Yosys 0.65. Свернёт ли fp32-путь синтез на уровне платы или заплатит за него, не измерено, а именно это решает, важно ли всё на практике.',
        'У квантователя RTL несимметричная мёртвая зона (+0.25 против 0.5), тогда как оракул документирует чистое правило знака. Сегодня они совпадают на всех достижимых входах. Ничто не проверяет, что они совпадут при расширении множества входов.',
        'Зеркально-симметричная предшествующая система воспроизведена для N = 0..12 полным перебором. Про большие N ничего не утверждается, сумматор не построен.',
        'Побьёт ли φ как основание экспоненты основание 2 на реальной нагрузке — не проверено. В этой кодовой базе φ основанием не используется нигде: лестницы на основании 2, одна на основании 3.'
      ]
    }
  },
  {
    slug: 'an-inert-filter-is-safest-until-it-works',
    title: 'An inert filter is safest until it works',
    summary: 'The first request this service ever served came back telling a clean design it had a silicon bug. Nine defects later the report is correct — and the one that mattered had been unreachable for as long as it was wrong.',
    date: '2026-08-17',
    readingMinutes: 9,
    tags: ['Verification', 'CI', 'Self-critique', 'Measurement'],
    receipts: [
      { label: 'gHashTag/trinity #796 — the request, its wrong report, and the nine fixes', href: 'https://github.com/gHashTag/trinity/issues/796' },
      { label: 'gHashTag/trinity #797 — SystemVerilog read as Verilog, blamed on the design', href: 'https://github.com/gHashTag/trinity/pull/797' },
      { label: 'gHashTag/trinity #807 — head closed the pipe and pipefail killed the step', href: 'https://github.com/gHashTag/trinity/pull/807' },
      { label: 'gHashTag/trinity #810 — eighteen workflows, 8182 runs, zero green', href: 'https://github.com/gHashTag/trinity/issues/810' }
    ],
    openQuestions: [
      'Nine defects were found on one submission. A design of a different shape — purely combinational, or multi-file without includes — has not been put through this path, and there is no reason to think the count would be zero.',
      'The eighteen never-green workflows are measured and published but not triaged. Deciding fix, dispatch-only or delete across three repositories is not done.',
      'The free tier still installs yosys unpinned, so its cell count depends on whichever version apt ships that week; wires and flip-flops were stable across the two tested.',
      'No third-party design has been through the repaired issue path. The one measurement here is my own press of my own button.'
    ],
    published: true,
    ru: {
      title: 'Инертный фильтр безопасен, пока не заработает',
      summary: 'Первый запрос, который этот сервис обслужил, сообщил чистому дизайну, что у него кремниевый баг. Девять дефектов спустя отчёт верен — а главный из них был недостижим ровно столько, сколько был неверен.',
      openQuestions: [
        'Девять дефектов найдены на одной заявке. Дизайн другой формы — чисто комбинационный или многофайловый без include — через этот путь не проходил, и нет оснований думать, что там ноль.',
        'Восемнадцать никогда не зеленевших воркфлоу измерены и опубликованы, но не разобраны. Решение «починить, только по кнопке или удалить» по трём репозиториям не принято.',
        'Бесплатный тир по-прежнему ставит yosys без закрепления версии, поэтому счёт ячеек зависит от того, что отгрузил apt; провода и триггеры на двух проверенных версиях совпадали.',
        'Ни один чужой дизайн через починенный путь не прогонялся. Единственное измерение здесь — моё собственное нажатие моей собственной кнопки.'
      ]
    }
  },
  {
    slug: 'a-gate-that-rejected-its-own-users',
    title: 'A gate that rejected its own users',
    summary: 'A floor I added asserted five report lines and failed three of the four normal design shapes; a workflow gated on a label that did not exist, so every "Start a run" button led nowhere. Both were correct about what they required and silent about whether it could be met.',
    date: '2026-08-17',
    readingMinutes: 7,
    tags: ['Verification', 'CI', 'Self-critique'],
    receipts: [
      { label: 'gHashTag/trinity PR #792 — count the checks that ran, not the lines that matched', href: 'https://github.com/gHashTag/trinity/pull/792' },
      { label: 'gHashTag/trinity PR #791 — the floor this corrects', href: 'https://github.com/gHashTag/trinity/pull/791' },
      { label: 'gHashTag/t27 issue #2176 — the CLI nothing built', href: 'https://github.com/gHashTag/t27/issues/2176' }
    ],
    openQuestions: [
      'How long the missing label had been breaking the request path is not bounded: nothing recorded an attempt, so the cost is unknown rather than small.',
      'The four fixtures cover the shapes I could think of. The failure this post describes is precisely that the author is badly placed to enumerate valid forms, so a fifth shape may still be rejected.',
      'The new floor counts checks, and a check that runs but measures nothing would still increment it. It removes one way to be wrong, not the class.',
      'No end-to-end request has yet been driven through the repaired issue path from a stranger\u2019s repository.'
    ],
    published: true,
    ru: {
      title: 'Гейт, который отверг собственных пользователей',
      summary: 'Порог, который я добавил, требовал пять строк отчёта и валил три из четырёх нормальных форм дизайна; воркфлоу открывался по метке, которой не существовало, поэтому каждая кнопка «Start a run» вела в никуда. Обе проверки были правы в том, что требовали, и молчали о том, выполнимо ли требование.',
      openQuestions: [
        'Сколько времени отсутствующая метка ломала путь запроса — не ограничено: ни одна попытка не записывалась, поэтому цена неизвестна, а не мала.',
        'Четыре образца покрывают те формы, которые я смог придумать. Ошибка, о которой пост, ровно в том, что автор плохо годится для перечисления допустимых форм, — пятая может отвергаться до сих пор.',
        'Новый порог считает проверки, и проверка, которая выполнилась, но ничего не измерила, всё равно его увеличит. Убран один способ ошибиться, а не класс.',
        'Сквозной запрос из чужого репозитория через починенный путь ещё не прогнан.'
      ]
    }
  },
  {
    slug: 'a-multiplicity-correction-changed-the-deployment-reading',
    title: 'A multiplicity correction changed the deployment reading',
    summary: 'A merged research note shows how a nine-placement selection by mean margin becomes a narrower claim after the selection family is included in the correction.',
    date: '2026-08-17',
    readingMinutes: 6,
    tags: ['Measurement', 'Reproducibility', 'Statistics', 'Quantization'],
    receipts: [
      { label: 'gHashTag/trinity-fpga PR #566 — merged research note', href: 'https://github.com/gHashTag/trinity-fpga/pull/566' },
      { label: 'merged commit 1900c36 — consistency and substrate notes', href: 'https://github.com/gHashTag/trinity-fpga/commit/1900c36a18c1b73560a94655c1a527f61d0a92d5' },
      { label: 'CONSISTENCY_BEATS_MAGNITUDE_2026-08-12.md at the merged revision', href: 'https://github.com/gHashTag/trinity-fpga/blob/1900c36a18c1b73560a94655c1a527f61d0a92d5/research/block/CONSISTENCY_BEATS_MAGNITUDE_2026-08-12.md' },
      { label: 'SUBSTRATE_IS_PERISHABLE_2026-08-12.md at the merged revision', href: 'https://github.com/gHashTag/trinity-fpga/blob/1900c36a18c1b73560a94655c1a527f61d0a92d5/research/block/SUBSTRATE_IS_PERISHABLE_2026-08-12.md' }
    ],
    openQuestions: [
      'The post does not establish that MID is better than NEAR0; their paired comparison is a tie with p = 0.157 at n = 5.',
      'Five checkpoints and one wikitext-2 evaluation do not establish how the placement behaves on unseen models, datasets, or training settings.',
      'The note reports model-level margins for block 32 with E8M0 and lm_head excluded; it is not a general result for every layer or format.',
      'No FPGA, speed, energy, or downstream deployment result is claimed by this post.'
    ],
    published: true,
    ru: {
      title: 'Поправка на множественные сравнения изменила чтение развёртывания',
      summary: 'Смерженная исследовательская заметка показывает, как выбор из девяти placements по среднему отступу становится более узким утверждением после учёта семейства сравнения.',
      openQuestions: [
        'Пост не доказывает, что MID лучше NEAR0: их парное сравнение даёт ничью и p = 0,157 при n = 5.',
        'Пять контрольных точек и одна проверка на wikitext-2 не доказывают поведение placement на новых моделях, датасетах или режимах обучения.',
        'Заметка сообщает метрики на уровне модели для блока 32 с E8M0 и без lm_head; это не общий результат для каждого слоя или формата.',
        'Пост не заявляет результата на FPGA, по скорости, энергии или в реальном развёртывании.'
      ]
    }
  },
  {
    "slug": "a-health-snapshot-changed-its-denominator",
    "title": "A health snapshot changed its numbers, not its contract",
    "summary": "A fresh repository commit updates the CI health snapshot from 156 to 143 failures in a 200-run window and records the denominator and exclusions that give those numbers meaning.",
    "date": "2026-08-16",
    "readingMinutes": 4,
    "tags": ["CI", "Measurement", "Reproducibility", "Dashboards"],
    "receipts": [
      { "label": "gHashTag/trinity commit 6227bed — signal health refresh", "href": "https://github.com/gHashTag/trinity/commit/6227bed26d3097e817455a5e5958deffd75b106c" },
      { "label": "signalHealth.json at the committed revision", "href": "https://github.com/gHashTag/trinity/blob/6227bed26d3097e817455a5e5958deffd75b106c/apps/website/src/data/signalHealth.json" }
    ],
    "openQuestions": [
      "The commit records a refreshed data file; this post does not independently re-run or audit the complete run history.",
      "The lower failure count is not attributed here to a particular code or workflow change.",
      "The snapshot describes the metric's classification of recorded outcomes; it does not establish that the CI jobs themselves are correct.",
      "No FPGA, silicon, speed, energy, or downstream-model result is claimed by this post."
    ],
    "published": true,
    "ru": {
      "title": "Снимок здоровья изменил числа, но не контракт",
      "summary": "Свежий коммит обновляет снимок здоровья CI: со 156 до 143 отказов в окне из 200 прогонов, одновременно фиксируя знаменатель и правила исключения.",
      "openQuestions": [
        "Коммит записывает обновлённый data-файл; отдельный полный аудит истории прогонов в этом посте не выполнялся.",
        "Меньшее число отказов здесь не приписывается конкретной правке кода или workflow.",
        "Снимок описывает классификацию записанных исходов этой метрикой, но не устанавливает корректность самих CI-задач.",
        "Этот пост не заявляет результата на FPGA, кремнии, по скорости, энергии или по downstream-модели."
      ]
    }
  },
  {
    "slug": "a-red-gate-was-missing-its-input",
    "title": "A red gate was missing its input",
    "summary": "A merged FPGA-repository audit shows how a missing checkout turned twelve unchecked disagreements into apparent fixes, while two other failures were ordinary runner plumbing.",
    "date": "2026-08-15",
    "readingMinutes": 6,
    "tags": [
      "CI",
      "FPGA",
      "Reproducibility",
      "Tooling"
    ],
    "receipts": [
      {
        "label": "gHashTag/trinity-fpga PR #564 — merged CI-gate repair",
        "href": "https://github.com/gHashTag/trinity-fpga/pull/564"
      },
      {
        "label": "gHashTag/trinity-fpga commit 45ad2347 — merged implementation",
        "href": "https://github.com/gHashTag/trinity-fpga/commit/45ad2347712e4d22d1edbae97c07ea9e758f4ae0"
      },
      {
        "label": "artefact-agreement workflow changed by the PR",
        "href": "https://github.com/gHashTag/trinity-fpga/blob/45ad2347712e4d22d1edbae97c07ea9e758f4ae0/.github/workflows/artefact-agreement.yml"
      }
    ],
    "openQuestions": [
      "The PR repairs the gate plumbing and reproduces the missing-input failure, but it does not establish that the underlying format discrepancies are correct or incorrect. The two content findings remain open.",
      "The checkout fix is shown on the repository workflow; a fresh public run after the merge is not used here as a separate receipt.",
      "The zsh installation keeps the repository shell scripts unchanged, but the workflow does not compare their output with a second shell implementation.",
      "Treating an unreadable absolute document path as absent avoids a runner exception; it does not prove that the referenced document should exist in this repository."
    ],
    "published": true,
    "ru": {
      "title": "У красного гейта не было входных данных",
      "summary": "Смерженный аудит FPGA-репозитория показывает, как отсутствующий checkout превратил двенадцать непроверенных расхождений в видимость исправлений, а ещё два отказа оказались обычной проблемой раннера.",
      "openQuestions": [
        "PR чинит инфраструктуру гейтов и воспроизводит отказ из-за отсутствующего входа, но не устанавливает, верны ли сами расхождения форматов. Два содержательных finding остаются открытыми.",
        "Правка checkout показана на workflow репозитория; отдельный свежий публичный прогон после мержа здесь не используется как самостоятельная квитанция.",
        "Установка zsh оставляет shell-скрипты репозитория без переписывания, но workflow не сравнивает их вывод с реализацией на другом shell.",
        "Обработка недоступного абсолютного пути документа как отсутствующего убирает исключение раннера, но не доказывает, что этот документ должен находиться в репозитории."
      ]
    }
  },
  {
    "slug": "a-broken-reference-looks-exactly-like-broken-code",
    "title": "Eight broken gates in one day, and not one of them was broken code",
    "summary": "A flag, a version, a runner, a module, a script, three specs, two format paths, five submodule links and a step that ran what it claimed to build. Every one reported \"failure\", which is also what a real defect reports.",
    "date": "2026-08-15",
    "readingMinutes": 9,
    "tags": [
      "CI",
      "Tooling",
      "Git",
      "Zig"
    ],
    "receipts": [
      {
        "label": "trinity #758 — format check pointed at paths that no longer exist · MERGED",
        "href": "https://github.com/gHashTag/trinity/pull/758"
      },
      {
        "label": "trinity #760 — test binary needs libc; five submodule gitlinks with no url · MERGED",
        "href": "https://github.com/gHashTag/trinity/pull/760"
      },
      {
        "label": "trinity c768953 — the merge that first turned the CLI build green",
        "href": "https://github.com/gHashTag/trinity/commit/c7689530274d706fb0876b41e3ec0671ae16960d"
      },
      {
        "label": "run 31827529498 — Build & Push Trinity CLI, first success after 30+ red runs",
        "href": "https://github.com/gHashTag/trinity/actions/runs/31827529498"
      }
    ],
    "openQuestions": [
      "The segfault found at the end is not fixed. `zig build tri` builds the CLI and runs it; with stdin closed it dies with SIGSEGV, while the same binary from the same commit runs cleanly with no arguments inside the published container. The workflow no longer runs the REPL, which removes the symptom from CI and leaves the defect.",
      "Two gates remain red on purpose. Implementation coverage is about 3% against a 95% target, and the gate that says so is the one thing in that job that was telling the truth all along. Lowering the threshold would be the failure it exists to catch.",
      "`deploy/Dockerfile.node` is still missing and its workflow still publishes an image from it. Restoring the file or retiring the image is a product decision, not a repair.",
      "Nothing here says the code is correct. Eight gates now measure what they claim to measure; what they measure has barely been examined.",
      "The count of eight is this repository on this day, found while looking for something else. It is not a survey, and no claim is made that the rate is representative."
    ],
    "published": true,
    "ru": {
      "title": "Восемь сломанных гейтов за день, и ни один — из-за сломанного кода",
      "summary": "Флаг, версия, раннер, модуль, скрипт, три спеки, два пути форматирования, пять ссылок на сабмодули и шаг, который запускал то, что называл сборкой. Каждый сообщал «failure» — ровно как сообщил бы настоящий дефект.",
      "openQuestions": [
        "Найденный под конец сегфолт не исправлен. `zig build tri` собирает CLI и запускает его; с закрытым stdin он падает по SIGSEGV, тогда как тот же бинарь из того же коммита в опубликованном контейнере без аргументов отрабатывает чисто. Воркфлоу больше не запускает REPL — это убирает симптом из CI и оставляет дефект.",
        "Два гейта остаются красными намеренно. Покрытие реализациями около 3% при цели 95%, и гейт, который об этом говорит, — единственное в той задаче, что всё это время не врало. Понизить порог значило бы совершить ошибку, ради поимки которой он существует.",
        "`deploy/Dockerfile.node` по-прежнему отсутствует, а его воркфлоу продолжает публиковать из него образ. Восстановить файл или закрыть публикацию — решение продуктовое, а не ремонтное.",
        "Ничто здесь не утверждает, что код корректен. Восемь гейтов теперь меряют то, что заявляют; что именно они меряют, почти не рассматривалось.",
        "Число восемь — это один репозиторий за один день, найденное попутно. Это не обследование, и утверждать, что такова типичная частота, я не берусь."
      ]
    }
  },
  {
    "slug": "five-reasons-the-build-was-red",
    "title": "Five reasons the build was red, and the fifth was mine",
    "summary": "Our CLI could not be installed by anyone, and the CI that should have said so had zero successes in thirty runs. Each cause hid the next; removing the fourth created the fifth.",
    "date": "2026-08-15",
    "readingMinutes": 7,
    "tags": [
      "CI",
      "Zig",
      "Build systems",
      "Tooling"
    ],
    "receipts": [
      {
        "label": "trinity c768953 — the merge that turned the CLI build green",
        "href": "https://github.com/gHashTag/trinity/commit/c7689530274d706fb0876b41e3ec0671ae16960d"
      },
      {
        "label": "run 31827529498 — Build & Push Trinity CLI, first success after 30+ red runs",
        "href": "https://github.com/gHashTag/trinity/actions/runs/31827529498"
      },
      {
        "label": "the image that run published, pinned by sha",
        "href": "https://github.com/gHashTag/trinity/pkgs/container/trinity"
      }
    ],
    "openQuestions": [
      "Only the container image was exercised end to end. npm shows @playra/tri exists and the Homebrew tap repository resolves; neither was installed and run, so neither is claimed to work.",
      "Three version numbers are in play for one tool: the README heading says v6.3.0, npm publishes 1.0.1, and the binary prints v5.1.0. Only the binary’s was measured. Which is authoritative is unresolved.",
      "The codegen workflow is still red, at a later step: it calls scripts/validate_codegen.sh, which no longer exists. That is a different problem and it is not fixed.",
      "The image is linux/amd64 only. It runs on Apple Silicon under emulation; no arm64 image is published and no timing on either was measured.",
      "The build works. Whether the CLI is correct is a separate question this says nothing about — a green compile is not a passing test suite, and the test suites remain red."
    ],
    "published": true,
    "ru": {
      "title": "Пять причин, по которым сборка была красной, и пятая — моя",
      "summary": "Наш CLI не мог поставить никто, а CI, который должен был об этом сказать, имел ноль успехов из тридцати прогонов. Каждая причина прятала следующую; удаление четвёртой породило пятую.",
      "openQuestions": [
        "От начала до конца проверен только контейнер. npm показывает, что пакет @playra/tri существует, и репозиторий Homebrew-тапа отвечает; ни то, ни другое не устанавливалось и не запускалось, поэтому работоспособность не заявляется.",
        "У одного инструмента три версии: заголовок README говорит v6.3.0, npm публикует 1.0.1, бинарь печатает v5.1.0. Измерена только последняя. Какая авторитетна — не решено.",
        "Воркфлоу codegen по-прежнему красный, но на более позднем шаге: он зовёт scripts/validate_codegen.sh, которого больше нет. Это другая задача, и она не решена.",
        "Образ собран только под linux/amd64. На Apple Silicon он идёт через эмуляцию; arm64-образа нет, и время работы ни там, ни там не измерялось.",
        "Сборка работает. Корректен ли CLI — отдельный вопрос, о котором здесь не сказано ничего: зелёная компиляция не равна проходящим тестам, а тесты остаются красными."
      ]
    }
  },
  {
    "slug": "the-generated-file-was-three-years-old",
    "title": "We hand-patched a generated file that upstream had fixed five months earlier",
    "summary": "A vendored Verilog artifact from April 2023 carried a defect its generator repaired in March 2026. The hand fix is correct and temporary; the next regeneration would undo it.",
    "date": "2026-08-15",
    "readingMinutes": 5,
    "tags": [
      "LiteX",
      "openXC7",
      "Vendoring",
      "yosys"
    ],
    "receipts": [
      {
        "label": "demo-projects fbf72fc — the hand patch on the vendored file, 2026-08-14",
        "href": "https://github.com/openXC7/demo-projects/commit/fbf72fc69db4971bd730a92667f27def30d6ba10"
      },
      {
        "label": "litex b3a4c270 — \"S7HDMIPHY: Fix build with Yosys\", 2026-03-05",
        "href": "https://github.com/enjoy-digital/litex/commit/b3a4c270"
      },
      {
        "label": "litex/soc/cores/video.py — the emission, Open() on lines 1398-1399 today",
        "href": "https://github.com/enjoy-digital/litex/blob/master/litex/soc/cores/video.py"
      },
      {
        "label": "the finding, posted to the commit it concerns",
        "href": "https://github.com/openXC7/demo-projects/commit/fbf72fc69db4971bd730a92667f27def30d6ba10#commitcomment-196278462"
      }
    ],
    "openQuestions": [
      "I did not regenerate the design. That the current LiteX emits a clean file for this board end to end is inferred from the diff and the blame, not demonstrated by a build.",
      "Whether the other vendored designs in demo-projects carry the same staleness is unchecked. This is one file.",
      "The slave’s SHIFTIN1/2 are still tied to 0 upstream, and that is fine — an unused input may take a constant. The hand patch normalised both, but only the output tie was ever the defect. I did not test whether yosys objects to anything else in this file.",
      "I have not established why the demo carried a 2023 artifact rather than a regeneration step. There may be a reason — a LiteX API change, a board file that no longer builds — and I did not look for one before writing this."
    ],
    "published": true,
    "ru": {
      "title": "Мы залатали руками сгенерированный файл, который апстрим починил пятью месяцами раньше",
      "summary": "Вендоренный Verilog от апреля 2023 нёс дефект, который его генератор исправил в марте 2026. Ручная правка верна и временна: следующая регенерация её снесёт.",
      "openQuestions": [
        "Я не регенерировал дизайн. То, что текущий LiteX выдаёт чистый файл для этой платы от начала до конца, выведено из диффа и blame, а не показано сборкой.",
        "Несут ли ту же залежалость другие вендоренные дизайны в demo-projects — не проверено. Это один файл.",
        "SHIFTIN1/2 у ведомого в апстриме по-прежнему привязаны к 0, и это нормально: неиспользуемый вход может принимать константу. Ручная правка нормализовала оба, но дефектом была только привязка выхода. Возражает ли yosys на что-то ещё в этом файле, я не проверял.",
        "Я не выяснил, почему демо несло артефакт 2023 года, а не шаг регенерации. Причина может быть — смена API LiteX, неработающий файл платы, — и я её не искал, прежде чем это написать."
      ]
    }
  },
  {
    "slug": "half-the-build-is-bitstream-generation",
    "title": "Half the build is bitstream generation, and the trivial design was the slow one",
    "summary": "Fifteen openXC7 builds with stated boundaries: for small designs more time goes to turning FASM into a bitstream than to place-and-route, a blinky beaten by a GF multiplier, and 25% spread on byte-identical work.",
    "date": "2026-08-15",
    "readingMinutes": 7,
    "tags": [
      "FPGA",
      "openXC7",
      "Benchmarking",
      "Measurement"
    ],
    "receipts": [
      {
        "label": "trinity-fpga — the workflow, with the boundaries stated in its header",
        "href": "https://github.com/gHashTag/trinity-fpga/blob/main/.github/workflows/openxc7-build-timing.yml"
      },
      {
        "label": "run 31822095102 — 17/17 green, the fifteen measurements below",
        "href": "https://github.com/gHashTag/trinity-fpga/actions/runs/31822095102"
      },
      {
        "label": "run 31820544225 — the first attempt, which lost five jobs to my error",
        "href": "https://github.com/gHashTag/trinity-fpga/actions/runs/31820544225"
      }
    ],
    "openQuestions": [
      "This is not a comparison. There is no Vivado column, because there is no Vivado here — no licence, no install. The three designs are plain Verilog + XDC on xc7a200tfbg484-2 so that anyone holding a licence can build the same three and put their numbers beside these.",
      "One machine: a shared GitHub `ubuntu-latest` runner, 4 cores. The absolute seconds do not transfer to your workstation. The proportions between phases might; that is a hypothesis, not a result.",
      "The seed is pinned at 1 in every run, so nothing here measures nextpnr’s seed sensitivity. Sweeping seeds would have mixed two sources of variance into one column.",
      "Three designs, all ours, all one part. That is not a representative corpus — enough to show the shape, not enough to generalise the numbers.",
      "n=5. The spread is reported raw, min to max. No confidence interval is claimed and none would be honest at that n.",
      "Bitstream generation here means prjxray’s fasm2frames plus xc7frames2bit. A different backend would move that column, so the finding is about this toolchain rather than about open toolchains in general."
    ],
    "published": true,
    "ru": {
      "title": "Половина сборки — это генерация битстрима, а самым медленным оказался тривиальный дизайн",
      "summary": "Пятнадцать сборок openXC7 с объявленными границами: у малых дизайнов на превращение FASM в битстрим уходит больше времени, чем на трассировку, blinky проиграл умножителю GF, а разброс на побайтово одинаковой работе — 25%.",
      "openQuestions": [
        "Это не сравнение. Колонки Vivado нет, потому что здесь нет Vivado — ни лицензии, ни установки. Все три дизайна это обычный Verilog + XDC под xc7a200tfbg484-2, так что любой, у кого лицензия есть, может собрать те же три и положить свои числа рядом.",
        "Одна машина: общий раннер GitHub ubuntu-latest, 4 ядра. Абсолютные секунды на вашу рабочую станцию не переносятся. Пропорции между фазами, возможно, переносятся — но это гипотеза, а не результат.",
        "Сид зафиксирован на 1 во всех прогонах, поэтому здесь ничто не измеряет чувствительность nextpnr к сиду. Перебор сидов смешал бы два источника разброса в одной колонке.",
        "Три дизайна, все наши, все на одном кристалле. Это не представительная выборка — её хватает, чтобы показать форму, и не хватает, чтобы обобщать числа.",
        "n=5. Разброс приведён как есть, от min до max. Доверительный интервал не заявляется — при таком n он был бы нечестен.",
        "Генерация битстрима здесь означает fasm2frames и xc7frames2bit из prjxray. Другой бэкенд сдвинул бы эту колонку, поэтому вывод касается этого тулчейна, а не открытых тулчейнов вообще."
      ]
    }
  },
  {
    "slug": "the-search-space-erased-a-significance-claim",
    "title": "The search space erased a significance claim",
    "summary": "A merged audit of 67 targets withdraws a roughly 10-sigma reading after enumerating the search family that made near-matches likely by chance.",
    "date": "2026-08-14",
    "readingMinutes": 7,
    "tags": [
      "research",
      "statistics",
      "reproducibility",
      "audit"
    ],
    "receipts": [
      {
        "label": "gHashTag/trinity PR #738 — merged statistical audit",
        "href": "https://github.com/gHashTag/trinity/pull/738"
      },
      {
        "label": "Merged commit da2916c — corrected source and scripts",
        "href": "https://github.com/gHashTag/trinity/commit/da2916cc1af1c35a6d9a356cc0f7ea35aefe4d56"
      },
      {
        "label": "sacred-formulas.md — audited document",
        "href": "https://github.com/gHashTag/trinity/blob/04430c0dc154ed3ec987704fe9b74bbcb40a3e9b/docs/docs/math-foundations/sacred-formulas.md"
      }
    ],
    "openQuestions": [
      "The Šidák threshold of 5.06σ assumes independent family members; the dependence created by shared factors was not estimated, so the actual threshold may be lower.",
      "The one-decade window used for local-density estimates was checked for stability, but it has no theoretical derivation in this audit.",
      "The document still records a mismatch between an announced standard search size of 20,412 and bounds that enumerate 54,756 combinations; the PR flags the discrepancy instead of silently choosing one.",
      "The corrected counts concern this document and its declared family of formulas; they do not establish a general statement about mathematical coincidences outside that family."
    ],
    "published": true,
    "ru": {
      "title": "Пространство поиска отменило заявление о значимости",
      "summary": "Смерженный аудит 67 целей снимает трактовку около 10σ после перечисления семейства поиска, в котором близкие совпадения часто возникают случайно.",
      "openQuestions": [
        "Порог Шидака 5,06σ предполагает независимость членов семейства; зависимость из-за общих множителей не оценивалась, поэтому настоящий порог может быть ниже.",
        "Однодекадное окно для оценки локальной плотности проверено на устойчивость, но теоретического вывода для него в этом аудите нет.",
        "В документе остаётся расхождение между заявленным размером стандартного перебора 20 412 и границами, которые дают 54 756 комбинаций; PR отмечает его, а не выбирает число молча.",
        "Исправленные счётчики относятся к этому документу и заявленному семейству формул; они не доказывают общего тезиса о математических совпадениях вне этого семейства."
      ]
    }
  },
  {
    "slug": "six-and-a-half-years-in-a-discarded-return-value",
    "title": "Six and a half years in one discarded return value",
    "summary": "Four merged fixes turned the openXC7 demo CI green. The oldest was a bool nobody read: since February 2020 the placer knew its own placement was invalid and threw the answer away, so the failure surfaced in the router instead.",
    "date": "2026-08-14",
    "readingMinutes": 9,
    "tags": [
      "FPGA",
      "openXC7",
      "nextpnr",
      "Place and route"
    ],
    "receipts": [
      {
        "label": "nextpnr-xilinx #145 — propagate placer1_refine failure out of placer_heap · MERGED 2026-08-13",
        "href": "https://github.com/openXC7/nextpnr-xilinx/pull/145"
      },
      {
        "label": "nextpnr-xilinx #146 — budget the per-position site exit in placement validity · MERGED 2026-08-14",
        "href": "https://github.com/openXC7/nextpnr-xilinx/pull/146"
      },
      {
        "label": "nextpnr-xilinx #142 — RAM256X1S mux tree belongs in its own slice half · MERGED 2026-08-13",
        "href": "https://github.com/openXC7/nextpnr-xilinx/pull/142"
      },
      {
        "label": "nextpnr-xilinx #144 — wire RAM128X1S scalar A0..A6 into the DRAM control set · MERGED 2026-08-13",
        "href": "https://github.com/openXC7/nextpnr-xilinx/pull/144"
      },
      {
        "label": "nextpnr-xilinx #134 — routed, timing-clean, dead on silicon · OPEN",
        "href": "https://github.com/openXC7/nextpnr-xilinx/issues/134"
      },
      {
        "label": "demo-projects CI — every project builds",
        "href": "https://github.com/openXC7/demo-projects/actions/runs/31778234320"
      },
      {
        "label": "nextpnr-xilinx #142 — Carlos Venegas Arrabé on the second blind spot, added to this post after publication · MERGED 2026-08-13",
        "href": "https://github.com/openXC7/nextpnr-xilinx/pull/142#issuecomment-5268596254"
      },
      {
        "label": "nextpnr-xilinx #146 — the same author confirming the attribution was ours to correct · MERGED 2026-08-14",
        "href": "https://github.com/openXC7/nextpnr-xilinx/pull/146#issuecomment-5284347345"
      }
    ],
    "openQuestions": [
      "A green CI proves the toolchain emits a bitstream without falling over. It does not prove the bitstream configures a chip. In the maintainer’s words: \"That does not mean that the bitstreams work.\"",
      "#134 is open. A design that places, routes and meets timing still does nothing on the board — the relocated carry pass-through lanes drove S from a constant net, which has no physical realisation on xc7. #146 does not fix it.",
      "The six-and-a-half-year figure is the age of the call site, dated by blame. It is not evidence that the discarded failure path was reachable for all of that time — the reverse is argued here: it became reachable when the LUTRAM packing work started producing placements that fail validity.",
      "BUFR/BUFIO support in the bitstream database is still unverified. prjxray-db#1 was closed pending a fuzzer that can mint the rows with provenance; the eight proposed segbits rows are not confirmed.",
      "litex-ddr-hdmi-stlv7325 still fails, and not on the toolchain: the generated Verilog ties SHIFTOUT1/2 of a slave OSERDESE2 to constants. Vivado warns and ignores; yosys refuses.",
      "No build-time comparison against Vivado is claimed here. We have not measured it."
    ],
    "published": true,
    "ru": {
      "title": "Шесть с половиной лет в одном отброшенном значении",
      "summary": "Четыре влитых исправления сделали CI демо-проектов openXC7 зелёным. Самое старое — bool, который никто не читал: с февраля 2020 плейсер знал, что размещение невалидно, и выбрасывал ответ.",
      "openQuestions": [
        "Зелёный CI доказывает, что тулчейн выдаёт битстрим, не падая. Он не доказывает, что битстрим сконфигурирует кристалл. Словами мейнтейнера: \"That does not mean that the bitstreams work.\"",
        "#134 открыт. Дизайн, который размещается, трассируется и укладывается в тайминги, на плате не работает: перенесённые сквозные полосы переноса получали S из константной цепи, чего на xc7 физически не существует. #146 его не закрывает.",
        "Шесть с половиной лет — возраст места вызова по blame, а не доказательство, что ветка отказа была достижима всё это время. Здесь утверждается обратное: она стала достижимой, когда работа над упаковкой LUTRAM начала давать невалидные размещения.",
        "Поддержка BUFR/BUFIO в базе битстримов не подтверждена. prjxray-db#1 закрыт в ожидании фаззера, который выведет эти строки с провенансом; восемь предложенных строк segbits не подтверждены.",
        "litex-ddr-hdmi-stlv7325 по-прежнему падает, и не из-за тулчейна: сгенерированный Verilog привязывает SHIFTOUT1/2 подчинённого OSERDESE2 к константам. Vivado предупреждает и игнорирует, yosys отказывается.",
        "Сравнение времени сборки с Vivado здесь не заявляется. Мы его не измеряли."
      ]
    }
  },
  {
    "slug": "a-correct-gate-with-a-manual-remedy",
    "title": "A correct gate with a manual remedy is an outage",
    "summary": "Twelve consecutive publisher runs failed on a check that was right every time, and six merged pull requests spent sixteen hours invisible to readers.",
    "date": "2026-08-14",
    "readingMinutes": 7,
    "tags": [
      "delivery",
      "ci",
      "publishing",
      "postmortem"
    ],
    "receipts": [
      {
        "label": "ghashtag.github.io run 31774839732 — the last of twelve failures",
        "href": "https://github.com/gHashTag/ghashtag.github.io/actions/runs/31774839732"
      },
      {
        "label": "ghashtag.github.io run 31780655887 — the first green run after the fix",
        "href": "https://github.com/gHashTag/ghashtag.github.io/actions/runs/31780655887"
      },
      {
        "label": "ghashtag.github.io cf8534f — the publisher now regenerates the blog itself",
        "href": "https://github.com/gHashTag/ghashtag.github.io/commit/cf8534f450ef344be36eda90bff7e79ac316279d"
      },
      {
        "label": "regen-blog.py — the script that owns the chain",
        "href": "https://github.com/gHashTag/ghashtag.github.io/blob/main/regen-blog.py"
      }
    ],
    "openQuestions": [
      "The drift gate compares two lists of slugs. Nothing fetches a published page as a reader without JavaScript would, so a post can pass the gate and still be unreadable for a reason the gate does not model.",
      "The workflow asks for a run every fifteen minutes; the observed spacing on 13-14 August was closer to an hour, because GitHub throttles scheduled workflows. The comment in the file claiming a fifteen-minute worst case is therefore wrong, and nothing on the site measures the real lag between a merge and a reader.",
      "Cards for new posts are now drawn with Pillow in DejaVu, while the hand-made ones are set in Inter. That difference is visible and unmeasured — no platform preview has been checked against a generated card.",
      "Only the blog was audited for this shape. Other generated surfaces in the same repository — the book under docs/, the result pages under r/ — have generators that are also invoked by hand, and nobody has checked whether any gate depends on them."
    ],
    "published": true,
    "ru": {
      "title": "Верный гейт с ручным лечением — это простой",
      "summary": "Двенадцать прогонов публикатора подряд упали на проверке, которая каждый раз была права, а шесть смерженных pull request просидели шестнадцать часов невидимыми для читателя.",
      "openQuestions": [
        "Гейт сравнивает два списка слагов. Ни одна проверка не запрашивает опубликованную страницу так, как её запросил бы читатель без JavaScript, — значит пост может пройти гейт и остаться нечитаемым по причине, которой в гейте нет.",
        "Воркфлоу просит прогон каждые пятнадцать минут; наблюдаемый интервал 13–14 августа был около часа, потому что GitHub придерживает расписанные воркфлоу. Комментарий в файле про «худший случай пятнадцать минут» из-за этого неверен, и ничто на сайте не измеряет настоящую задержку между мержем и читателем.",
        "Карточки новых постов теперь рисуются Pillow в DejaVu, а сделанные руками набраны в Inter. Разница видна и не измерена — ни один предпросмотр площадки на сгенерированной карточке не проверялся.",
        "На эту форму отказа проверен только блог. В том же репозитории есть другие генерируемые поверхности — книга в docs/, страницы результатов в r/ — их генераторы тоже запускаются руками, и никто не проверял, зависит ли от них какой-нибудь гейт."
      ]
    }
  },
  {
    "slug": "eleven-verdicts-were-windows-not-checkpoints",
    "title": "Eleven verdicts were windows, not checkpoints",
    "summary": "A merged research correction replaces 140 pooled windows with four model-level replicates and turns eleven apparent verdicts into ties.",
    "date": "2026-08-13",
    "readingMinutes": 8,
    "tags": [
      "research",
      "statistics",
      "quantization",
      "reproducibility"
    ],
    "receipts": [
      {
        "label": "trinity-fpga PR #563 — merged research correction",
        "href": "https://github.com/gHashTag/trinity-fpga/pull/563"
      },
      {
        "label": "POOLED_VERDICTS_RESTATED_2026-08-12.md — merged analysis note",
        "href": "https://github.com/gHashTag/trinity-fpga/blob/main/research/block/POOLED_VERDICTS_RESTATED_2026-08-12.md"
      }
    ],
    "openQuestions": [
      "This is a re-analysis of per-window NLL already on disk; no model was re-run and no new checkpoint was measured.",
      "The one verdict that survives the correction, JK-asym-NEAR0 versus JOINT-KL, is tagged 3/4 in-sample, so it is not evidence about a new checkpoint.",
      "The corrected rows do not establish a general advantage for any codebook; a model-level result on four checkpoints remains a narrow result, not a deployment claim."
    ],
    "published": true,
    "ru": {
      "title": "Одиннадцать вердиктов оказались окнами, а не чекпоинтами",
      "summary": "Смерженная исследовательская правка заменяет 140 объединённых окон четырьмя репликами уровня модели и превращает одиннадцать видимых вердиктов в ничьи.",
      "openQuestions": [
        "Это переанализ уже сохранённых значений NLL по окнам; ни одна модель не перезапускалась, новый чекпоинт не измерялся.",
        "Сохранившийся после исправления вердикт, JK-asym-NEAR0 против JOINT-KL, помечен как 3/4 in-sample, поэтому он не свидетельствует о новом чекпоинте.",
        "Исправленные строки не доказывают общего преимущества какого-либо кодбука; результат на уровне четырёх чекпоинтов остаётся узким и не является заявлением о применении."
      ]
    }
  },
  {
    "slug": "each-half-imported-the-other",
    "title": "Each half imported the other",
    "summary": "One directory was split across two repositories and both kept flat imports of the other. Neither compiled — and being uncompilable is exactly what kept either from reporting it.",
    "date": "2026-08-12",
    "readingMinutes": 8,
    "tags": [
      "verification",
      "zig",
      "dependencies"
    ],
    "receipts": [
      {
        "label": "zig-knowledge-graph #2 — the near half, merged",
        "href": "https://github.com/gHashTag/zig-knowledge-graph/pull/2"
      },
      {
        "label": "zig-knowledge-graph #1 — the split, open",
        "href": "https://github.com/gHashTag/zig-knowledge-graph/issues/1"
      },
      {
        "label": "zig-knowledge-graph #3 — the two binaries, open",
        "href": "https://github.com/gHashTag/zig-knowledge-graph/issues/3"
      },
      {
        "label": "zig-golden-float #99 — the far half, merged",
        "href": "https://github.com/gHashTag/zig-golden-float/pull/99"
      },
      {
        "label": "trinity-training #2 — the self-invalidating pin, merged",
        "href": "https://github.com/gHashTag/trinity-training/pull/2"
      }
    ],
    "openQuestions": [
      "Only the library was made to build. `kg_cli` and `kg_server` are a Zig 0.14 to 0.15 migration across roughly 1300 lines — filed as #3, not attempted here, and until it is done those two tools remain what they have always been: unrunnable.",
      "I do not know how many other pairs in this fleet have the same shape. The one I found, I found by accident, while fixing something else.",
      "The library builds and its seven tests pass. Seven is a small number for a graph store, and nothing here establishes that the seven cover anything in particular."
    ],
    "published": true,
    "ru": {
      "title": "Каждая половина импортировала другую",
      "summary": "Одну папку разделили на два репозитория, и обе сохранили плоские импорты друг друга. Не компилировалась ни одна — и именно невозможность собраться мешала любой из них сообщить о проблеме.",
      "openQuestions": [
        "Собрана только библиотека. `kg_cli` и `kg_server` — это миграция с Zig 0.14 на 0.15 примерно по 1300 строкам; заведена как #3, здесь не делалась, и до неё эти два инструмента остаются тем, чем были всегда: незапускаемыми.",
        "Сколько ещё пар во флоте имеют ту же форму — я не знаю. Найденную нашёл случайно, чиня совсем другое.",
        "Библиотека собирается, семь тестов проходят. Семь — немного для хранилища графа, и ничто здесь не говорит, что именно эти семь покрывают."
      ]
    }
  },
  {
    "slug": "a-suite-that-runs-nothing-exits-zero",
    "title": "Zero of six hundred and forty",
    "summary": "A package declared 640 tests and ran none of them, and the exit code was 0. The mechanism is ordinary, the fix is one line per import, and what it uncovered was a physical constant that no input could ever produce.",
    "date": "2026-08-12",
    "readingMinutes": 9,
    "tags": [
      "verification",
      "zig",
      "vacuity"
    ],
    "receipts": [
      {
        "label": "zig-golden-float #98 — the unresolvable import, merged",
        "href": "https://github.com/gHashTag/zig-golden-float/pull/98"
      },
      {
        "label": "zig-golden-float #99 — export packed_vsa, submitted",
        "href": "https://github.com/gHashTag/zig-golden-float/pull/99"
      },
      {
        "label": "zig-physics #4 — 0 tests were running out of 640, submitted",
        "href": "https://github.com/gHashTag/zig-physics/pull/4"
      },
      {
        "label": "zig-physics #3 — the Barbero–Immirzi range, open",
        "href": "https://github.com/gHashTag/zig-physics/issues/3"
      },
      {
        "label": "trinity-training #1 — no test step existed, submitted",
        "href": "https://github.com/gHashTag/trinity-training/pull/1"
      }
    ],
    "openQuestions": [
      "Coverage after the fix is partial and I have not measured how partial. In zig-physics 254 tests became reachable out of 640 declared; the remaining 386 live in files that no root reaches, and I have not established whether they would pass.",
      "The Barbero–Immirzi projection is refuted, not repaired. Choosing a different mapping from E8 coordinates to γ is a physics decision, and any mapping I picked would be fitted to the assertion it had to satisfy.",
      "trinity-training builds and its five module roots run tests on the target toolchain, but those roots do not reach all 104 files. I report the count CI produces, not the 672 declared.",
      "One package, zig-knowledge-graph, is still unusable: three files importing four that do not exist. The four exist upstream; the shim is not written yet."
    ],
    "published": true,
    "ru": {
      "title": "Ноль из шестисот сорока",
      "summary": "Пакет объявлял 640 тестов и не выполнил ни одного, а код возврата был 0. Механизм самый обыкновенный, починка — одна строка на импорт, а под ней обнаружилась физическая константа, которую не даёт ни один вход.",
      "openQuestions": [
        "Покрытие после починки частичное, и насколько — я не измерял. В zig-physics стали досягаемы 254 теста из 640 объявленных; оставшиеся 386 лежат в файлах, до которых не дотягивается ни один корень, и прошли бы они — неизвестно.",
        "Проекция Барберо–Иммирци опровергнута, а не исправлена. Выбор другого отображения координат E8 в γ — решение физическое, и любое, которое выбрал бы я, оказалось бы подогнано под то самое утверждение, которому обязано удовлетворять.",
        "trinity-training собирается, и пять корней его модулей выполняют тесты на целевом тулчейне, но эти корни не покрывают все 104 файла. Я привожу число, которое выдаёт CI, а не 672 объявленных.",
        "Один пакет, zig-knowledge-graph, по-прежнему непригоден: три файла импортируют четыре несуществующих. Все четыре есть в апстриме, прослойка ещё не написана."
      ]
    }
  },
  {
    "slug": "a-repair-reaches-only-the-copy-it-lands-in",
    "title": "Sixteen defects fixed, zero of them reached the consumer",
    "summary": "Two repositories carried the same six files under the same names. Repairing one changed nothing downstream, and no instrument in either could report why — because each copy compiles entirely on its own.",
    "date": "2026-08-12",
    "readingMinutes": 7,
    "tags": [
      "Zig",
      "Modularity",
      "CI",
      "Verification"
    ],
    "receipts": [
      {
        "label": "zig-golden-float #97 — 16 defects repaired · MERGED 2026-08-11",
        "href": "https://github.com/gHashTag/zig-golden-float/pull/97"
      },
      {
        "label": "zig-hdc #3 — one implementation, CI green · MERGED 2026-08-12",
        "href": "https://github.com/gHashTag/zig-hdc/pull/3"
      },
      {
        "label": "zig-hdc #2 — the earlier attempt, closed as superseded",
        "href": "https://github.com/gHashTag/zig-hdc/pull/2"
      }
    ],
    "openQuestions": [
      "gHashTag/trinity, the consumer that started this, is still red. Its pin predates the repair and its own build has other causes, so nothing here claims that chain is finished.",
      "Listing re-exported names one by one has a cost this post does not pretend away: a symbol added upstream does not appear downstream until somebody adds it. usingnamespace, which would have avoided that, was removed in Zig 0.15.",
      "Whether the eighteen files that stayed behind should also live upstream was not decided. They have no counterpart there today; that is a fact about today, not an argument."
    ],
    "published": true,
    "ru": {
      "title": "Шестнадцать дефектов исправлены, до потребителя не дошёл ни один",
      "summary": "Два репозитория несли одни и те же шесть файлов под одними именами. Починка одного не изменила ничего внизу по цепочке, и ни один прибор не мог сказать почему — потому что каждая копия компилируется сама по себе.",
      "openQuestions": [
        "gHashTag/trinity, потребитель, с которого всё началось, всё ещё красный. Его закрепление старше починки, и у его сборки есть другие причины, так что ничто здесь не утверждает, что цепочка завершена.",
        "Перечисление реэкспортируемых имён поимённо имеет цену, и этот пост её не прячет: символ, добавленный наверху, не появится внизу, пока его туда не добавят. usingnamespace, который избавил бы от этого, убран в Zig 0.15.",
        "Должны ли восемнадцать оставшихся файлов тоже жить наверху — не решено. Сегодня у них там нет соответствия; это факт о сегодня, а не аргумент."
      ]
    }
  },
  {
    "slug": "green-ci-does-not-mean-usable",
    "title": "A green CI does not mean the library builds for you",
    "summary": "A Zig package with passing CI could not be compiled by any consumer. Lazy analysis means a test run proves only what the tests happen to touch — one line exposed five hidden errors in one package, and sixteen in the package under it.",
    "date": "2026-08-11",
    "readingMinutes": 11,
    "tags": [
      "Zig",
      "CI",
      "Verification",
      "Static analysis"
    ],
    "receipts": [
      {
        "label": "zig-golden-float #97 — 16 defects, CI green on 0.15.2 · MERGED 2026-08-11",
        "href": "https://github.com/gHashTag/zig-golden-float/pull/97"
      },
      {
        "label": "zig-hdc #2 — full-surface analysis, 5 drift errors · OPEN",
        "href": "https://github.com/gHashTag/zig-hdc/pull/2"
      },
      {
        "label": "trinity #701 — the consumer that surfaced it · OPEN",
        "href": "https://github.com/gHashTag/trinity/pull/701"
      }
    ],
    "openQuestions": [
      "Which copy of src/vsa/* is canonical is undecided. The two packages carry their own and they have diverged, so repairing one does not repair the other.",
      "zig-hdc is still red. Its five errors are in its own copy of files that were repaired in the package below it.",
      "refAllDeclsRecursive forces analysis, not execution. It proves the surface compiles; it says nothing about whether any of it is correct.",
      "Whether the same gap exists in other lazily-analysed languages was not tested. The claim here is about Zig, measured on Zig."
    ],
    "published": true,
    "ru": {
      "title": "Зелёный CI не значит, что библиотека соберётся у вас",
      "summary": "Пакет на Zig с проходящими тестами не мог собрать ни один потребитель. Ленивый анализ означает, что тесты доказывают лишь то, до чего дотянулись: одна строка вскрыла пять скрытых ошибок в одном пакете и шестнадцать в том, что под ним.",
      "openQuestions": [
        "Какая из копий src/vsa/* каноническая — не решено. Оба пакета несут свою, и они разошлись, поэтому починка одной не чинит другую.",
        "zig-hdc всё ещё красный. Его пять ошибок — в собственных копиях файлов, исправленных в пакете уровнем ниже.",
        "refAllDeclsRecursive заставляет анализировать, а не исполнять. Он доказывает, что поверхность компилируется, и ничего не говорит о том, верна ли она.",
        "Есть ли тот же разрыв в других языках с ленивым анализом — не проверялось. Утверждение здесь про Zig и измерено на Zig."
      ]
    }
  },
  {
    "slug": "scale-field-width-already-published",
    "title": "The scale field does not need eight bits, and we were not the first to say so",
    "summary": "Four bits cover the shared scale on every checkpoint measured -- bit-identical to E8M0, zero blocks truncated out of 20,462,464. The observation was published first by someone else; what is ours is the proof around it, and the constant does not survive contact with activations.",
    "date": "2026-08-11",
    "readingMinutes": 9,
    "tags": [
      "Number formats",
      "MXFP4",
      "Quantisation",
      "Prior art"
    ],
    "receipts": [
      {
        "label": "Chhugani et al., Unveiling the Potential of Quantization with MXFP4 (arXiv:2603.08713), section 3.3 -- the prior publication of the 4-bit-suffices observation",
        "href": "https://arxiv.org/abs/2603.08713"
      },
      {
        "label": "Dettmers et al., QLoRA: Efficient Finetuning of Quantized LLMs (NeurIPS 2023) -- double quantisation, 0.5 to 0.127 bits per parameter",
        "href": "https://arxiv.org/abs/2305.14314"
      },
      {
        "label": "Rouhani et al., With Shared Microexponents, A Little Shifting Goes a Long Way (ISCA 2023) -- multi-level exponent splitting",
        "href": "https://arxiv.org/abs/2302.08007"
      },
      {
        "label": "OCP Microscaling Formats (MX) Specification v1.0 -- the E8M0 shared scale this measures against",
        "href": "https://www.opencompute.org/documents/ocp-microscaling-formats-mx-v1-0-spec-final-pdf"
      }
    ],
    "openQuestions": [
      "The observation that four bits suffice for the scale exponent is not ours: Chhugani et al. (arXiv:2603.08713, section 3.3) published it on larger models. What is presented here as new is the theory around it -- the sufficiency proof, the R < S < R+2 bound, and the separation of sufficiency from necessity.",
      "Necessity was NOT established per tensor, only in the worst case. A counterexample exists in which a truncated scale field returns the same dequantised weights, so 'b_min bits are required' is false as a per-tensor statement.",
      "Activation spans are sample-dependent and were still growing between measurement windows. The five-bit figure for activations is a lower bound on what a longer run would report, not a converged number.",
      "The binade-grid phase ambiguity is worth one code either way and has not been eliminated: Pythia's R = 7.33 gives S = 8 at one phase and S = 9 at another.",
      "The five checkpoints are small (SmolLM2, Qwen, Pythia, OPT, GPT-2). The prior work reports the same conclusion on Llama-3.1-8B and Qwen3-8B, so the direction agrees at scale, but nothing here was measured at that size."
    ],
    "published": true,
    "ru": {
      "title": "Полю масштаба не нужны восемь бит, и сказали это не мы первыми",
      "summary": "Четырёх бит хватает на общий масштаб во всех измеренных чекпоинтах — побитово идентично E8M0, ноль обрезанных блоков из 20 462 464. Наблюдение опубликовано раньше и не нами; нашим остаётся доказательство вокруг него, а константа не переживает встречи с активациями.",
      "openQuestions": [
        "Наблюдение, что четырёх бит достаточно для экспоненты масштаба, — не наше: Chhugani et al. (arXiv:2603.08713, раздел 3.3) опубликовали его на моделях крупнее. Новым здесь подаётся теория вокруг него — доказательство достаточности, граница R < S < R+2 и разделение достаточности и необходимости.",
        "Необходимость НЕ установлена по тензорам, только в худшем случае. Существует контрпример, где обрезанное поле масштаба возвращает те же деквантованные веса, поэтому «требуется b_min бит» ложно как утверждение о каждом тензоре.",
        "Спаны активаций зависят от выборки и продолжали расти между окнами измерения. Пятибитная цифра по активациям — нижняя оценка, а не сошедшееся значение.",
        "Фазовая неоднозначность бинадной сетки стоит одного кода в любую сторону и не устранена: у Pythia R = 7.33 даёт S = 8 при одной фазе и S = 9 при другой.",
        "Пять чекпоинтов невелики (SmolLM2, Qwen, Pythia, OPT, GPT-2). Предшествующая работа сообщает тот же вывод на Llama-3.1-8B и Qwen3-8B, то есть направление совпадает и на масштабе, но здесь на таком размере ничего не измерялось."
      ]
    }
  },
  {
    "slug": "open-gigabit-ethernet-artix7",
    "title": "Gigabit Ethernet on Artix-7 without a vendor toolchain",
    "summary": "RGMII at gigabit through Yosys, nextpnr-xilinx and Project X-Ray with no vendor tools — the six blockers that had to be patched, the one still open, and what the workaround costs.",
    "date": "2026-08-09",
    "readingMinutes": 12,
    "tags": [
      "FPGA",
      "Open source",
      "Ethernet",
      "Artix-7",
      "openXC7"
    ],
    "receipts": [
      {
        "label": "openXC7/nextpnr-xilinx #109 — set_multicycle_path · MERGED 2026-08-09",
        "href": "https://github.com/openXC7/nextpnr-xilinx/pull/109"
      },
      {
        "label": "#110 — clock-buffer preplace BFS cap · MERGED 2026-08-09",
        "href": "https://github.com/openXC7/nextpnr-xilinx/pull/110"
      },
      {
        "label": "#111 — fabric-driven global buffers · MERGED 2026-08-10",
        "href": "https://github.com/openXC7/nextpnr-xilinx/pull/111"
      },
      {
        "label": "#112 — SDP BRAM unused-port width bit · MERGED 2026-08-10",
        "href": "https://github.com/openXC7/nextpnr-xilinx/pull/112"
      },
      {
        "label": "#113 — single-site configuration primitives · MERGED 2026-08-10",
        "href": "https://github.com/openXC7/nextpnr-xilinx/pull/113"
      },
      {
        "label": "#115 — IDDR IFF flop initialisation · MERGED 2026-08-09",
        "href": "https://github.com/openXC7/nextpnr-xilinx/pull/115"
      },
      {
        "label": "openXC7/nextpnr-xilinx issue #114 — IDDR captures nothing on silicon (A/B/A/B bitstream measurement, ALINX AX7203)",
        "href": "https://github.com/openXC7/nextpnr-xilinx/issues/114"
      },
      {
        "label": "openXC7/nextpnr-xilinx issue #65 — SAME_EDGE_PIPELINED unsupported (janrinze, Mar 2025)",
        "href": "https://github.com/openXC7/nextpnr-xilinx/issues/65"
      },
      {
        "label": "Shah, Hung, Wolf, Bazanski, Gisselquist, Milanović — Yosys+nextpnr: an Open Source Framework from Verilog to Bitstream for Commercial FPGAs (FCCM 2019), arXiv:1903.10407",
        "href": "https://arxiv.org/abs/1903.10407"
      }
    ],
    "openQuestions": [
      "The link negotiates on 23 of 48 power-ups (48%, 95% interval 34-62%), independent of the RTL across four designs. Cause open: every hypothesis inside the FPGA is eliminated; the switch, the PHY strap resistors sampled at reset and the cabling remain. The cheapest untried experiment needs no code — two boards back-to-back with no switch.",
      "All six patches are OPEN on openXC7/nextpnr-xilinx — submitted upstream, none merged as of 2026-08-09.",
      "Hardware IDDR capture on Artix-7 is broken and the diagnosis is open, not just the fix: issue #114 withdraws its own first conclusion (\"Q1 dead, Q2 alive\") after the detector turned out to be one-sided. Both outputs are inert in every edge mode tried. The receive path uses fabric DDR capture as a workaround.",
      "Sigma ~= 470 ps was never measured. It is derived from the five-step skew span via the frame-length law, so it cannot then be used to corroborate that law. An independent jitter measurement is the one experiment that would settle it; near 50 ps would falsify the explanation.",
      "Frame-error rate was never measured directly, only inferred from whether the link came up. The three skew data points are right-censored at tap 31 and cannot discriminate between the candidate models."
    ],
    "published": true,
    "ru": {
      "title": "Gigabit Ethernet на Artix-7 без вендорского тулчейна",
      "summary": "RGMII на гигабите через Yosys, nextpnr-xilinx и Project X-Ray без вендорских инструментов — шесть блокеров, которые пришлось пропатчить, один оставшийся открытым, и во что обходится обходной путь.",
      "openQuestions": [
        "Линк поднимается на 23 включениях из 48 (48%, 95-процентный интервал 34-62%), независимо от RTL на четырёх разных дизайнах. Причина открыта: все гипотезы внутри FPGA исключены; остаются свитч, strap-резисторы PHY, читаемые в момент сброса, и кабель. Самый дешёвый непроведённый опыт не требует кода — две платы напрямую, без свитча.",
        "Все шесть патчей на openXC7/nextpnr-xilinx OPEN — отправлены наверх, ни один не влит по состоянию на 2026-08-09.",
        "Аппаратный захват IDDR на Artix-7 не работает, и открыт сам диагноз, а не только починка: issue #114 отзывает собственный первый вывод («Q1 мёртв, Q2 жив») после того, как детектор оказался односторонним. Оба выхода инертны во всех испробованных режимах фронта. Приёмный тракт использует захват DDR на фабрике как обходной путь.",
        "Sigma ~= 470 пс никогда не измерялась. Она выведена из размаха перекоса в пять шагов через закон длины кадра, а значит не может служить подтверждением этого же закона. Независимое измерение джиттера — тот единственный опыт, который закрыл бы вопрос; значение около 50 пс опровергло бы объяснение.",
        "Частота ошибок по кадрам не измерялась напрямую, а только выводилась из того, поднялся ли линк. Три точки по перекосу цензурированы справа на отсчёте 31 и не позволяют различить конкурирующие модели."
      ]
    }
  }
]

export const publishedPosts = () => postsIndex.filter((p) => p.published)

export const postBySlug = (slug: string) => postsIndex.find((p) => p.slug === slug)
