// The test the document had not had.
//
// `questions` asks whether anyone would try filling this record for one real
// published result. This module is the answer: the fourteen fields of `record`
// filled against seven results that other people published — five neuromorphic
// parts, one benchmark framework, and one control drawn from a benchmark body
// that already operates formal disclosure rules.
//
// Every cell was filled from a primary source and then checked a second time by
// a reader whose instruction was to find a wrong verdict, which moved 51 of
// them. No cell is a guess: `unchecked` is zero, and the absences were
// established by running the searches, not by failing to notice the material.
//
// It did not come back clean for us. The control has no absent field at all,
// which refutes the framing that this is a neuromorphic problem — see `premise`.
// That sentence stays on the page because a document about honest records that
// buried its own negative result would be the joke it is trying to describe.

import type { Bi } from './passport'

/** How completely one published result states one field. */
export type Cell = 'stated' | 'partial' | 'absent'

export interface SurveyedSystem {
  /** Column label in the matrix; short enough to set vertically. */
  label: string
  full: Bi
  /** The published number this record was filled against. */
  headline: Bi
  source: Bi
  url: string
  /** The control: a result published under a benchmark body's disclosure rules. */
  control?: boolean
}

export const systems: SurveyedSystem[] = [
  {
    label: 'Hala Point',
    full: { en: 'Intel Loihi 2 / Hala Point', ru: 'Intel Loihi 2 / Hala Point' },
    headline: {
      en: '15 TOPS/W at up to 20 petaops, unbatched, on a synthetic MLP stimulated with random noise.',
      ru: '15 TOPS/W при до 20 петаопс, без батчинга, на синтетическом MLP, возбуждённом случайным шумом.',
    },
    source: {
      en: 'Press release, 17 April 2024; one four-sentence footnote is the entire method.',
      ru: 'Пресс-релиз, 17 апреля 2024; весь метод — одна сноска из четырёх предложений.',
    },
    url: 'https://www.intc.com/news-events/press-releases/detail/1691/intel-builds-worlds-largest-neuromorphic-system-to',
  },
  {
    label: 'NorthPole',
    full: { en: 'IBM NorthPole (12 nm neural inference processing unit)', ru: 'IBM NorthPole (12 нм, нейронный инференс-процессор)' },
    headline: {
      en: '571 frames per joule on ResNet50, at 42,460 FPS and 74 W board power.',
      ru: '571 кадр на джоуль на ResNet50, при 42 460 FPS и 74 Вт мощности платы.',
    },
    source: { en: 'Science 382, 329–335 (2023), Table 1.', ru: 'Science 382, 329–335 (2023), таблица 1.' },
    url: 'https://www.science.org/doi/10.1126/science.adh1174',
  },
  {
    label: 'BrainScaleS-2',
    full: { en: 'BrainScaleS-2 (analog, Heidelberg), 256-246-10 SNN on one chip', ru: 'BrainScaleS-2 (аналоговый, Гейдельберг), SNN 256-246-10 на одном кристалле' },
    headline: {
      en: '2.4 µJ per classified image at 97.6% accuracy — derived from ~200 mW and throughput, not metered.',
      ru: '2,4 мкДж на классифицированное изображение при 97,6% точности — выведено из ~200 мВт и пропускной способности, а не измерено счётчиком.',
    },
    source: { en: 'PNAS 119(4):e2109194119 (2022).', ru: 'PNAS 119(4):e2109194119 (2022).' },
    url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC8794842/',
  },
  {
    label: 'NeuRRAM',
    full: { en: 'NeuRRAM (48-core RRAM compute-in-memory chip)', ru: 'NeuRRAM (48-ядерный RRAM-чип со счётом в памяти)' },
    headline: {
      en: 'Peak MVM energy efficiency 43 TOPS/W, at 1-bit input / 4-bit weight / 3-bit output.',
      ru: 'Пиковая энергоэффективность MVM 43 TOPS/W, при 1-битном входе / 4-битном весе / 3-битном выходе.',
    },
    source: { en: 'Nature 608, 504–512 (2022), Extended Data Table 1.', ru: 'Nature 608, 504–512 (2022), Extended Data, таблица 1.' },
    url: 'https://doi.org/10.1038/s41586-022-04992-8',
  },
  {
    label: 'SpiNNaker2',
    full: { en: 'SpiNNaker2, pruned EGRU language model on one chip', ru: 'SpiNNaker2, прореженная языковая модель EGRU на одном кристалле' },
    headline: {
      en: '65.3 mJ per inference against 1.1935 J on an A100, at equal test perplexity.',
      ru: '65,3 мДж на инференс против 1,1935 Дж на A100, при равной тестовой перплексии.',
    },
    source: { en: 'arXiv:2312.09084, Table II; AICAS 2024 version of record.', ru: 'arXiv:2312.09084, таблица II; версия записи AICAS 2024.' },
    url: 'https://arxiv.org/abs/2312.09084',
  },
  {
    label: 'Xylo',
    full: { en: 'NeuroBench v1.0 system track — acoustic scene classification on SynSense Xylo Audio 2', ru: 'NeuroBench v1.0, системный трек — классификация акустических сцен на SynSense Xylo Audio 2' },
    headline: {
      en: '0.028 mJ per inference at 79.90% accuracy, 84 ms per one-second sample.',
      ru: '0,028 мДж на инференс при 79,90% точности, 84 мс на односекундный отсчёт.',
    },
    source: { en: 'Nature Communications 16:1545 (2025), Table 6.', ru: 'Nature Communications 16:1545 (2025), таблица 6.' },
    url: 'https://www.nature.com/articles/s41467-025-56739-4',
  },
  {
    label: 'MLPerf H200',
    control: true,
    full: {
      en: 'MLPerf Inference v4.1 + Power — NVIDIA H200 ×8, ResNet50-v1.5, Offline, closed division (the control)',
      ru: 'MLPerf Inference v4.1 + Power — NVIDIA H200 ×8, ResNet50-v1.5, Offline, закрытый дивизион (контроль)',
    },
    headline: {
      en: '556,234 samples/s at 76.076% Top-1, with a mean of 4,638.26 W AC over 761 one-second samples.',
      ru: '556 234 отсчёта/с при 76,076% Top-1, при среднем 4 638,26 Вт переменного тока за 761 односекундный отсчёт.',
    },
    source: { en: 'Submitted result artifacts, mlcommons/inference_results_v4.1.', ru: 'Артефакты поданного результата, mlcommons/inference_results_v4.1.' },
    url: 'https://github.com/mlcommons/inference_results_v4.1',
  },
]

/**
 * One row per field of `record`, in that order, one cell per entry of `systems`.
 * qa/passport-figures.mjs asserts both alignments, so a field added to the record
 * cannot silently acquire a blank row here.
 */
const S = 'stated' as const
const P = 'partial' as const
const A = 'absent' as const

export const coverage: Cell[][] = [
  [A, A, A, P, A, A, P], //  1. Artifact identity
  [P, P, P, P, P, P, P], //  2. Stimulus identity and sampling plan
  [A, P, P, P, A, A, S], //  3. Activity
  [P, A, P, P, A, P, P], //  4. Device instance and population
  [A, P, A, P, A, A, P], //  5. Environment
  [P, P, P, P, P, S, S], //  6. Measurement boundary and operating point
  [P, P, P, S, P, P, P], //  7. Model and timing configuration
  [P, P, P, P, P, P, P], //  8. System configuration
  [A, P, P, P, A, P, P], //  9. Build and host arithmetic
  [P, A, P, P, P, P, P], // 10. Interface representation
  [A, P, P, P, P, P, P], // 11. Adaptation and state at start
  [A, A, P, A, A, A, P], // 12. Uncertainty
  [A, A, A, P, A, P, P], // 13. Specification version and manifest
  [A, P, P, P, P, S, P], // 14. Reference implementation
]

const flat = coverage.flat()
export const tally = {
  cells: flat.length,
  stated: flat.filter((c) => c === 'stated').length,
  partial: flat.filter((c) => c === 'partial').length,
  absent: flat.filter((c) => c === 'absent').length,
  /** Verdicts reached without opening a source. Zero, and the figure says so. */
  unchecked: 0,
}

/** The four fields that are absent or near-absent across the whole set, control included. */
export const blindSpots = [0, 4, 11, 12]

export const survey: { h: Bi; b: Bi }[] = [
  {
    h: { en: 'What came back', ru: 'Что вернулось' },
    b: {
      en: `Ninety-eight cells: ${tally.stated} stated, ${tally.partial} partial, ${tally.absent} absent, none unchecked. No result states more than two of the fourteen fields and four of the seven state none at all. Of the seven headline figures, two carry any statistical qualifier whatever.`,
      ru: `Девяносто восемь клеток: ${tally.stated} раскрыто, ${tally.partial} частично, ${tally.absent} отсутствует, ни одной непроверенной. Ни один результат не раскрывает больше двух полей из четырнадцати, а четыре из семи не раскрывают ни одного. Из семи заглавных чисел статистическую оговорку несут два.`,
    },
  },
  {
    h: { en: 'The shape matters more than the tally', ru: 'Форма важнее счёта' },
    b: {
      en: 'The gaps are not spread evenly, they are stacked in four fields — artifact identity, environment, uncertainty, and specification manifest — which are empty or near-empty across the board. The fields the community argues about most, measurement boundary and system configuration, are the best served: all seven say something about their envelope and their parts. Nobody hashes what they deployed, nobody records the temperature, and almost nobody reports an error bar.',
      ru: 'Пробелы распределены не ровно — они собраны в четырёх полях: тождество артефакта, среда, неопределённость и манифест спецификации. Они пусты или почти пусты у всех. Поля, о которых сообщество спорит больше всего, — граница измерения и конфигурация системы — обслужены лучше прочих: все семь что-то говорят о своём контуре и своих частях. Никто не хеширует то, что развернул, никто не записывает температуру, и почти никто не приводит доверительный интервал.',
    },
  },
  {
    h: { en: 'This refutes half our framing', ru: 'Это опровергает половину нашей рамки' },
    b: {
      en: 'The control has zero absent cells — and still only two stated ones. So this is not simply neuromorphic reporting being behind: about half this document restates disclosure norms one benchmark body already enforces and most papers do not, and the other half asks for things that body does not ask for either. Both halves are worth having. They should not be sold as one claim, and until now they were.',
      ru: 'У контроля ноль отсутствующих клеток — и всё равно лишь две раскрытые. Значит, дело не сводится к отставанию нейроморфной отчётности: примерно половина этого документа пересказывает нормы раскрытия, которые одна бенчмарк-организация уже применяет, а большинство статей — нет, а вторая половина просит того, чего не просит и она. Обе половины стоят того, чтобы быть. Но продавать их как одно утверждение нельзя, а до сих пор именно так и было.',
    },
  },
  {
    h: { en: 'Nobody here was careless', ru: 'Небрежных здесь нет' },
    b: {
      en: 'The strongest published record in the set is NeuRRAM, and it is the persuasive one precisely because it is scrupulous: programming voltages, an acceptance range, average pulses per cell, a 99% yield, a settling delay chosen so that conductance relaxation is captured rather than dodged, and an exclusion caveat stated twice. It still fails the uncertainty field outright — 43 TOPS/W is one unrepeated reading, on an unstated number of chips, at an unstated temperature. That sentence is the whole argument for the record, and it can be made without blaming anyone.',
      ru: 'Сильнейшая опубликованная запись в наборе — NeuRRAM, и убедительна она именно потому, что добросовестна: напряжения программирования, диапазон приёмки, среднее число импульсов на ячейку, 99% выхода годных, задержка установления, выбранная так, чтобы релаксация проводимости была захвачена, а не обойдена, и оговорка об исключении, произнесённая дважды. И всё равно поле неопределённости провалено начисто: 43 TOPS/W — это один неповторённый отсчёт, на неназванном числе кристаллов, при неназванной температуре. В этой фразе — всё обоснование записи, и произнести её можно, никого не обвиняя.',
    },
  },
  {
    h: { en: 'A correction to the third block', ru: 'Поправка к третьему блоку' },
    b: {
      en: 'That block first read "on four fields there is no standard to catch up to." It was wrong, and wrong in this page\'s own characteristic way: it generalised from a control of one. A later sweep of bodies outside the survey found a requirement for all four. Two I read first-hand — MLPerf\'s model-info.json names the starting weights, by filename rather than by digest, which is the real delta and a smaller one than was claimed; and the NeurIPS checklist asks at item 7 for error bars or another statement of significance. Two I did not: SPECpower_ssj2008 §2.9 is reported to enforce a minimum ambient temperature, and ACM artifact badging to cover availability and manifest. Those two came from search results rather than from the rules, and should be read before anyone leans on them. One field the sweep found nowhere: which die was measured, and how many.',
      ru: 'Сначала в том блоке стояло: «по четырём полям догонять нечего». Это неверно — и неверно ровно тем способом, о котором вся страница: обобщение с контроля из одного. Более поздний обход организаций за пределами выборки нашёл требование по всем четырём. Два источника я прочитал сам: model-info.json в MLPerf называет исходные веса — по имени файла, а не по хешу, и вот это и есть настоящая разница, и она меньше заявленной; чек-лист NeurIPS пунктом 7 требует доверительных интервалов или иного указания значимости. Два — не читал: §2.9 правил SPECpower_ssj2008, по сообщениям, требует минимальной температуры в помещении, а бейджи артефактов ACM покрывают доступность и манифест. Эти два взяты из поисковой выдачи, а не из самих правил, и их стоит прочитать, прежде чем на них опираться. Одного поля обход не нашёл нигде: какой именно кристалл измеряли и сколько их.',
    },
  },
]

/** What this survey does not establish. Carried beside the result, not below it. */
export const limits: Bi = {
  en: 'Three genuinely gated sources were never read: one supplementary appendix behind a 403, a vendor-gated toolchain, and the licence-gated semantics of the control\'s power-meter uncertainty tuple. Three verdicts sit on a boundary and a reasonable reviewer could move them one step. And several absences are properties of the publication surface, not of the organisation: Intel, IBM and SynSense demonstrably hold information they did not publish. This measures what was disclosed, which is the right thing to measure, and it is never a claim about what the engineers knew.',
  ru: 'Три по-настоящему закрытых источника не прочитал никто: приложение за 403, тулчейн под доступом вендора и лицензионно закрытая семантика кортежа неопределённости у измерителя мощности контроля. Три вердикта стоят на границе, и разумный рецензент сдвинул бы их на шаг. И часть отсутствий — свойство поверхности публикации, а не организации: Intel, IBM и SynSense заведомо располагают тем, чего не опубликовали. Здесь измеряется раскрытое — и это правильный предмет измерения, — но это никогда не утверждение о том, что знали инженеры.',
}
