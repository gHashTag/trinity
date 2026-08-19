import type { PostMeta } from './types'

/** Индекс блога: список и метаданные без тяжёлых тел публикаций. */
export const postsIndex: PostMeta[] = [
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
