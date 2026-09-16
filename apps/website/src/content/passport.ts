// The PASSPORT: the record that must travel with a reported result.
//
// This is the text of a comment submitted for team review to the OCP
// AI-HW-SW-CoDesign working group (neuromorphic computing position statement),
// written at Hesham El-Bakoury's request on 16 September 2026, and the three
// measured cases from our own work that it rests on.
//
// It is the single source: /passport renders it as a page, the Queen's shell
// renders the same object as a view, and the working group reads the same
// sentences the site shows. Nothing here is generated from a scan; every number
// is quoted from a named file, and the four figures that could not be sourced
// were withdrawn rather than restated (see `withdrawn`).
//
// Standing: this is a PROPOSED subsection. Nobody has agreed to include it.

export type PassportTag = 'measured' | 'argued' | 'withdrawn'

export interface Bi {
  en: string
  ru: string
}

export const meta = {
  title: { en: 'PASSPORT', ru: 'ПАСПОРТ' },
  subtitle: {
    en: 'What must travel with a result',
    ru: 'Что обязано ехать вместе с результатом',
  },
  author: 'Dmitrii Vasilev, Trinity S3AI — ORCID 0009-0008-4294-6159',
  venue: {
    en: 'Comment submitted for team review, OCP neuromorphic computing position statement (AI-HW-SW-CoDesign).',
    ru: 'Комментарий, поданный на рассмотрение группы, позиционный документ OCP по нейроморфным вычислениям (AI-HW-SW-CoDesign).',
  },
  submitted: '2026-09-16',
  status: {
    en: 'Proposed, not approved. Nobody has agreed to include it.',
    ru: 'Предложено, не принято. Никто не согласился это включать.',
  },
}

/** Read before anything else: the three limits a reviewer should not have to discover. */
export const standing: { n: string; h: Bi; b: Bi }[] = [
  {
    n: '1',
    h: { en: 'The cases are not neuromorphic', ru: 'Случаи не нейроморфные' },
    b: {
      en: 'Two come from a language-model training pipeline; one concerns arithmetic datapaths on FPGA fabric and says nothing about spiking workloads. They transfer by analogy of failure mode, not by direct evidence. Every field resting on a case is marked †; unmarked fields rest on the argument alone and are not backed here by a measurement.',
      ru: 'Два взяты из конвейера обучения языковой модели; один — про арифметические датапуты на FPGA и ничего не говорит о спайковых нагрузках. Они переносятся по аналогии режима отказа, а не прямым свидетельством. Каждое поле, опирающееся на случай, помечено †; непомеченные держатся только на рассуждении и здесь измерением не подкреплены.',
    },
  },
  {
    n: '2',
    h: { en: 'No fabricated part is involved', ru: 'Ни одной изготовленной микросхемы' },
    b: {
      en: 'The hardware figures are post-route utilization reported by the implementation tools for one Xilinx Artix-7 XC7A200T target. They are not silicon measurements and are not presented as any.',
      ru: 'Аппаратные числа — это post-route утилизация, сообщённая инструментами имплементации для одной мишени Xilinx Artix-7 XC7A200T. Это не измерения на кремнии и не выдаются за них.',
    },
  },
  {
    n: '3',
    h: { en: 'One figure has been withdrawn', ru: 'Одно число отозвано' },
    b: {
      en: 'The 5 September draft quoted a specific count of defective rows in a published conformance vector set. That count could not be re-established from the record, so it does not appear here. The versioning practice it illustrated stands on its own; the number does not.',
      ru: 'В черновике от 5 сентября приводилось конкретное число дефектных строк в опубликованном наборе conformance-векторов. Восстановить это число по записям не удалось, поэтому здесь его нет. Практика версионирования, которую оно иллюстрировало, держится сама; число — нет.',
    },
  },
]

export const scope: Bi = {
  en: 'This specifies the record, not the measurement. No metric definitions, no workload suite, no instrumentation or method, no thresholds. It claims no completeness for the field list.',
  ru: 'Здесь задаётся запись, а не измерение. Ни определений метрик, ни набора нагрузок, ни аппаратуры и метода, ни порогов. Полнота списка полей не утверждается.',
}

export const problem: Bi[] = [
  {
    en: 'Outside the disclosure rules of established benchmark bodies, a result is commonly published as a number, a unit, a workload name and a part name. Two such records can differ because the systems differ or because the conditions did, and can agree because the systems agree or because the metric could not separate them — and nothing in the record says which.',
    ru: 'Вне правил раскрытия, принятых в устоявшихся бенчмарк-организациях, результат публикуется как число, единица, имя нагрузки и имя микросхемы. Две такие записи могут расходиться потому, что различаются системы, — или потому, что различались условия; и совпадать потому, что системы совпали, — или потому, что метрика не смогла их разделить. И в самой записи не сказано, что именно произошло.',
  },
  {
    en: 'A digital CMOS datapath is signed off so that its function is device-independent and its timing sits inside characterized margins, so two parts of one type may be treated as one part. Where weights are held as analog or memristive physical quantities, no equivalent characterization yet exists, and the device instance becomes part of what is measured. For digital event-driven parts the requirement is weaker, not absent.',
    ru: 'Цифровой КМОП-датапуть подписывают так, что его функция не зависит от экземпляра, а тайминг лежит внутри охарактеризованных запасов, — поэтому две микросхемы одного типа можно считать одной. Там, где веса хранятся как аналоговые или мемристивные физические величины, равноценной характеризации пока нет, и экземпляр прибора становится частью измеряемого. Для цифровых событийных микросхем требование слабее, но не отсутствует.',
  },
  {
    en: 'Energy inherits this: energy efficiency being a byproduct of event-driven, in-memory processing rather than its cause, an energy figure follows the activity the stimulus induced.',
    ru: 'Энергия это наследует: поскольку энергоэффективность — следствие событийной обработки в памяти, а не её причина, число по энергии следует за активностью, которую вызвал стимул.',
  },
]

/** The three failures, in both directions: two records that lie apart, two that lie together, one that is not comparable at all. */
export const cases: {
  n: string
  kind: Bi
  title: Bi
  setup: Bi
  finding: Bi
  moral: Bi
  source: string
}[] = [
  {
    n: '1',
    kind: { en: 'False difference', ru: 'Ложное различие' },
    title: {
      en: 'One set of weights read as two models',
      ru: 'Один набор весов прочитан как две модели',
    },
    setup: {
      en: 'One set of model weights — a single SHA-256, re-hashed from two locations and identical — was evaluated under one sampling plan (40 windows, 5,160 of 100,000 validation bytes) against two different validation corpora.',
      ru: 'Один набор весов модели — единственный SHA-256, пересчитанный из двух мест и совпавший, — прогнан по одному плану выборки (40 окон, 5 160 из 100 000 валидационных байт) на двух разных валидационных корпусах.',
    },
    finding: {
      en: 'The readings were 2.6385 and 2.9193 bits per byte, at per-reading standard errors of 0.0424 and 0.0469: a separation of 0.2808, or 4.44 times the combined standard error of 0.0632. A reader given only the two numbers would conclude that two different models had been measured. The weights were identical to the byte.',
      ru: 'Отсчёты: 2.6385 и 2.9193 бита на байт при стандартных ошибках 0.0424 и 0.0469 — расхождение 0.2808, то есть 4.44 совокупной стандартной ошибки (0.0632). Читатель, которому дали только два числа, заключит, что измеряли две разные модели. Веса совпадали побайтово.',
    },
    moral: {
      en: 'The stimulus digest separates this from a difference between models.',
      ru: 'Хеш стимула отделяет это от различия между моделями.',
    },
    source: 'IGLA evaluation record; weights SHA-256 re-hashed from two locations',
  },
  {
    n: '2',
    kind: { en: 'False agreement', ru: 'Ложное согласие' },
    title: {
      en: '43.70% of parameters differ behind a metric that does not move',
      ru: '43,70% параметров различаются за метрикой, которая не шелохнулась',
    },
    setup: {
      en: 'With an identical seed, a pinned compiler toolchain (rustc 1.96.0), a pinned dependency graph and corpora pinned by SHA-256, one training procedure was run on one instruction set architecture and then on another.',
      ru: 'При одинаковом сиде, закреплённом тулчейне компилятора (rustc 1.96.0), закреплённом графе зависимостей и корпусах, закреплённых по SHA-256, одна и та же процедура обучения выполнена на одной архитектуре набора команд, а затем на другой.',
    },
    finding: {
      en: '93,071 of 212,992 parameters differed — 43.70 percent, at relative L2 distance 0.4756. The headline metric moved 0.0030 bits per byte, 0.084 of the standard error reported for that reading. The step-0 checkpoint was byte-identical on both targets, so initialization is excluded and the divergence enters within the first ten gradient steps.',
      ru: '93 071 из 212 992 параметров разошлись — 43,70 процента при относительном L2-расстоянии 0.4756. Заглавная метрика сдвинулась на 0.0030 бита на байт — 0.084 стандартной ошибки этого отсчёта. Чекпойнт на шаге 0 побайтово совпал на обеих мишенях, значит инициализация исключена и расхождение входит в первые десять шагов градиента.',
    },
    moral: {
      en: 'Metric-level agreement is not evidence of artifact-level or device-level identity. Whether the artifacts also differ in behavior is a separate question; the number answers neither it nor the prior one — whether they differ at all.',
      ru: 'Согласие на уровне метрики не есть свидетельство тождества артефактов или приборов. Различаются ли артефакты ещё и поведением — отдельный вопрос; число не отвечает ни на него, ни на предыдущий — различаются ли они вообще.',
    },
    source: 'Cross-ISA reproduction, step-0 checkpoint byte-identical on both targets',
  },
  {
    n: '3',
    kind: { en: 'Unpinned representation', ru: 'Незакреплённое представление' },
    title: {
      en: 'A 5.4× LUT ratio that was not the algorithm',
      ru: 'Отношение 5,4× по LUT, которое не про алгоритм',
    },
    setup: {
      en: 'One arithmetic function was implemented twice and mapped to one XC7A200T target through one open toolchain.',
      ru: 'Одна арифметическая функция реализована дважды и отображена на одну мишень XC7A200T через один открытый тулчейн.',
    },
    finding: {
      en: 'Post-route utilization was 1,179 LUTs with three DSP48 blocks for one implementation and 219 LUTs with none for the other: a LUT ratio of 5.4, the DSP48 usage additional and not commensurable with it. The difference was not the algorithm. In the first, datapath buses were wider than the values they carried; in the second, every width derived from the format parameters.',
      ru: 'Post-route утилизация: 1 179 LUT и три блока DSP48 у одной реализации против 219 LUT и ни одного — у другой: отношение по LUT 5,4, причём расход DSP48 добавочен и с ним несоизмерим. Разница не в алгоритме. В первой шины датапута были шире значений, которые несли; во второй каждая ширина выведена из параметров формата.',
    },
    moral: {
      en: 'Pinning the format and its field widths at each measured interface, by reference to a versioned specification with bit-exact vectors, makes two such implementations comparable.',
      ru: 'Закрепление формата и ширин его полей на каждом измеряемом интерфейсе — ссылкой на версионированную спецификацию с побитово точными векторами — делает две такие реализации сравнимыми.',
    },
    source: 'Two implementations of one function, one XC7A200T target, one open toolchain',
  },
]

/**
 * Which case pays for a field. `'withdrawn'` names the vector-set defect count
 * this document itself withdrew: the field it anchors is still marked †, but the
 * case behind it no longer stands, and the figures say so rather than counting it
 * with the rest.
 */
export type CaseRef = '1' | '2' | '3' | 'withdrawn'

/** The record itself. `anchoredTo` names the cases above that pay for a field (†). */
export const record: { field: Bi; what: Bi; absence: Bi; anchoredTo: CaseRef[] }[] = [
  {
    anchoredTo: ['2'],
    field: { en: 'Artifact identity', ru: 'Тождество артефакта' },
    what: {
      en: 'SHA-256 of the deployed weights, program image and mapped network as placed, taken after deployment; digest of the initial state where the system was trained or adapted',
      ru: 'SHA-256 развёрнутых весов, образа программы и отображённой сети в том виде, как размещена, снятый после развёртывания; хеш начального состояния, если система обучалась или адаптировалась',
    },
    absence: {
      en: '43.70 percent of parameters diverging behind a metric move of 0.084 standard errors',
      ru: '43,70 процента параметров расходятся за сдвигом метрики в 0.084 стандартной ошибки',
    },
  },
  {
    anchoredTo: ['1'],
    field: {
      en: 'Stimulus identity and sampling plan', ru: 'Тождество стимула и план выборки' },
    what: {
      en: 'SHA-256 of the stimulus set or event trace; window, trial and sample counts, and the fraction of the full set covered',
      ru: 'SHA-256 набора стимулов или трассы событий; число окон, испытаний и отсчётов и доля покрытого полного набора',
    },
    absence: {
      en: 'Two readings 4.44 standard errors apart from one set of weights',
      ru: 'Два отсчёта в 4.44 стандартной ошибки друг от друга — от одного набора весов',
    },
  },
  {
    anchoredTo: [],
    field: {
      en: 'Activity', ru: 'Активность' },
    what: {
      en: 'Event or spike count and rate over the measured run, from a named hardware counter or named simulator event, not inferred from nominal sparsity',
      ru: 'Число и частота событий или спайков за измеряемый прогон — с названного аппаратного счётчика или названного события симулятора, а не выведенные из номинальной разреженности',
    },
    absence: {
      en: 'An energy figure set by the stimulus but attributed to the design',
      ru: 'Число по энергии, заданное стимулом, но приписанное конструкции',
    },
  },
  {
    anchoredTo: [],
    field: {
      en: 'Device instance and population', ru: 'Экземпляр прибора и популяция' },
    what: {
      en: 'Part number, board or die serial, calibration and programming state; number of distinct instances measured and the spread across them; where a lot or serial is not disclosed, that is recorded as withheld rather than left blank',
      ru: 'Номер изделия, серийный номер платы или кристалла, состояние калибровки и программирования; число измеренных разных экземпляров и разброс между ними; если партия или серийный номер не раскрываются, это записывается как «не раскрыто», а не оставляется пустым',
    },
    absence: {
      en: 'One selected part reported as the population, on a substrate whose variability is an open challenge',
      ru: 'Один отобранный экземпляр, поданный как популяция, на подложке, чья вариативность — открытая проблема',
    },
  },
  {
    anchoredTo: [],
    field: {
      en: 'Environment', ru: 'Среда' },
    what: {
      en: 'Ambient or junction temperature, stating which and whether measured or nominal; supply voltages; and the tolerance held through the run',
      ru: 'Температура среды или перехода — с указанием, какая и измерена ли она или номинальная; напряжения питания; выдержанный за прогон допуск',
    },
    absence: {
      en: 'Non-idealities and drift reported as architecture',
      ru: 'Неидеальности и дрейф, поданные как архитектура',
    },
  },
  {
    anchoredTo: [],
    field: {
      en: 'Measurement boundary and operating point',
      ru: 'Граница измерения и рабочая точка',
    },
    what: {
      en: 'What lies inside the reported envelope — core, local memory, external memory, host, sensing and encoding — whether static and idle power are included, the measurement plane at both ends of any latency or responsiveness figure, and the task quality achieved',
      ru: 'Что лежит внутри заявленного контура — ядро, локальная память, внешняя память, хост, съём и кодирование; включены ли статическая мощность и мощность простоя; плоскость измерения на обоих концах любого числа по задержке или отзывчивости; и достигнутое качество задачи',
    },
    absence: {
      en: 'Two energy or latency figures whose envelopes differ by more than the effect compared',
      ru: 'Два числа по энергии или задержке, чьи контуры различаются сильнее, чем сравниваемый эффект',
    },
  },
  {
    anchoredTo: [],
    field: {
      en: 'Model and timing configuration', ru: 'Модель и конфигурация времени' },
    what: {
      en: 'Neuron and synapse model, timestep, spike or event encoding, fan-in and fan-out limits, and any elements disabled for yield',
      ru: 'Модель нейрона и синапса, шаг времени, кодирование спайков или событий, пределы fan-in и fan-out и любые элементы, отключённые ради выхода годных',
    },
    absence: {
      en: 'Two encodings of one network compared as two architectures',
      ru: 'Два кодирования одной сети, сравниваемые как две архитектуры',
    },
  },
  {
    anchoredTo: [],
    field: {
      en: 'System configuration', ru: 'Конфигурация системы' },
    what: {
      en: 'Number of parts, topology, partitioning and placement across cores and dies, and traffic crossing the measured boundary',
      ru: 'Число микросхем, топология, разбиение и размещение по ядрам и кристаллам и трафик, пересекающий измеряемую границу',
    },
    absence: {
      en: 'Single-part and multi-chip results recorded identically',
      ru: 'Результаты на одной микросхеме и на многокристальной системе, записанные одинаково',
    },
  },
  {
    anchoredTo: ['2'],
    field: {
      en: 'Build and host arithmetic', ru: 'Сборка и арифметика хоста' },
    what: {
      en: 'Compiler, synthesis and place-and-route versions and seeds; dependency-graph digest; the instruction set architecture of every machine used to train, map or calibrate; contraction and reduction-order settings',
      ru: 'Версии и сиды компилятора, синтеза и place-and-route; хеш графа зависимостей; архитектура набора команд каждой машины, на которой обучали, отображали или калибровали; настройки свёртки и порядка редукции',
    },
    absence: {
      en: 'Artifacts that differ while the recipe reads as identical',
      ru: 'Артефакты, которые различаются, тогда как рецепт читается как одинаковый',
    },
  },
  {
    anchoredTo: ['3'],
    field: {
      en: 'Interface representation', ru: 'Представление на интерфейсе' },
    what: {
      en: 'Number format, field widths, rounding and special-value handling at each measured boundary, by reference to a versioned specification with bit-exact conformance vectors, never a format name alone',
      ru: 'Числовой формат, ширины полей, округление и обработка особых значений на каждой измеряемой границе — ссылкой на версионированную спецификацию с побитово точными conformance-векторами, и никогда одним лишь именем формата',
    },
    absence: {
      en: 'A 5.4× LUT ratio for one function attributed to the design',
      ru: 'Отношение 5,4× по LUT для одной функции, приписанное конструкции',
    },
  },
  {
    anchoredTo: [],
    field: {
      en: 'Adaptation and state at start', ru: 'Адаптация и состояние на старте' },
    what: {
      en: 'Warm or cold start, state retained from prior runs, on-line learning enabled or not, exposure order, updates applied before the run, and the earlier tasks re-measured afterwards',
      ru: 'Горячий или холодный старт, состояние, сохранённое от прежних прогонов, включено ли онлайн-обучение, порядок предъявления, обновления, применённые до прогона, и перемеренные после него прежние задачи',
    },
    absence: {
      en: 'Retention and forgetting reported as one number taken at two points',
      ru: 'Удержание и забывание, поданные как одно число, снятое в двух точках',
    },
  },
  {
    anchoredTo: ['1', '2'],
    field: {
      en: 'Uncertainty', ru: 'Неопределённость' },
    what: {
      en: 'Per-reading standard error, repeat count, and expanded uncertainty with its coverage factor, stating whether the expanded figure derives from the same readings; for multi-instance figures, the between-instance component',
      ru: 'Стандартная ошибка отсчёта, число повторов и расширенная неопределённость с коэффициентом охвата — с указанием, выведена ли расширенная из тех же отсчётов; для многоэкземплярных чисел — межэкземплярная составляющая',
    },
    absence: {
      en: 'A separation of 4.44 standard errors and one of 0.084 read the same way',
      ru: 'Расхождение в 4.44 стандартной ошибки и расхождение в 0.084 читаются одинаково',
    },
  },
  {
    anchoredTo: ['withdrawn'],
    field: {
      en: 'Specification version and manifest', ru: 'Версия спецификации и манифест' },
    what: {
      en: 'Version identifier and manifest digest of the vector set, harness and scoring code; superseded revisions retained rather than overwritten',
      ru: 'Идентификатор версии и хеш манифеста набора векторов, обвязки и кода подсчёта; вытесненные ревизии сохраняются, а не перезаписываются',
    },
    absence: {
      en: 'Published transcripts changing meaning when a vector set is superseded',
      ru: 'Опубликованные протоколы меняют смысл, когда набор векторов вытеснен новым',
    },
  },
  {
    anchoredTo: [],
    field: {
      en: 'Reference implementation', ru: 'Эталонная реализация' },
    what: {
      en: 'The non-event-driven baseline compared against, recorded under the same fields, this one excepted',
      ru: 'Несобытийная база сравнения, записанная по тем же полям, кроме этого',
    },
    absence: {
      en: 'Negative and cross-class results that cannot be checked',
      ru: 'Отрицательные и межклассовые результаты, которые нельзя проверить',
    },
  },
]

export const anchorNote: Bi = {
  en: '† Anchored to one of the three cases. Those cases come from a language-model training pipeline and from an FPGA prototype, not from neuromorphic parts, and transfer by analogy of failure mode. ‡ Anchored only to the vector-set defect count this document has since withdrawn: the field still belongs in the table, but nothing measured is currently paying for it, and it is counted apart from the † rows rather than with them. Unmarked fields follow from the argument and are not, in this document, backed by a measurement.',
  ru: '† Опирается на один из трёх случаев. Эти случаи взяты из конвейера обучения языковой модели и из FPGA-прототипа, а не из нейроморфных микросхем, и переносятся по аналогии режима отказа. ‡ Опирается только на число дефектных векторов, которое этот документ с тех пор отозвал: поле остаётся в таблице по праву, но ничего измеренного за него сейчас не платит, и считается оно отдельно от строк с †, а не вместе с ними. Непомеченные поля следуют из рассуждения и в этом документе измерением не подкреплены.',
}

export const practices: { h: Bi; b: Bi }[] = [
  {
    h: {
      en: 'Records are versioned by addition, never corrected in place',
      ru: 'Записи версионируются добавлением и никогда не правятся на месте',
    },
    b: {
      en: 'Where a published conformance vector set is found to record expected results the implementation cannot produce, the affected files are not overwritten: they remain under their original specification version and SHA-256 manifest, while a regenerated set is published beside them under a new version and manifest. Every transcript already produced therefore stays interpretable, as a correct record of a run against a set now known to be defective. The practice cannot be applied retroactively; it must be in place before it is needed.',
      ru: 'Если в опубликованном наборе conformance-векторов обнаружены ожидаемые результаты, которых реализация выдать не может, затронутые файлы не перезаписываются: они остаются под своей исходной версией спецификации и SHA-256-манифестом, а рядом под новой версией и манифестом публикуется перегенерированный набор. Всякий уже выпущенный протокол поэтому остаётся читаемым — как верная запись прогона по набору, теперь известному как дефектный. Задним числом эту практику применить нельзя; она должна стоять до того, как понадобится.',
    },
  },
  {
    h: {
      en: 'An adapting system has no single result, only a trajectory of which one number is a sample',
      ru: 'У адаптирующейся системы нет одного результата — есть траектория, а число это её отсчёт',
    },
    b: {
      en: 'A retention figure and a forgetting figure are one number taken at two points, reproducible only where the exposure order, the updates applied before measurement, and whether adaptation continued are recorded.',
      ru: 'Число удержания и число забывания — это одно число, снятое в двух точках; воспроизводимо оно лишь там, где записаны порядок предъявления, применённые до измерения обновления и то, продолжалась ли адаптация.',
    },
  },
  {
    h: { en: 'Negative results are reportable', ru: 'Отрицательные результаты подлежат публикации' },
    b: {
      en: 'Where a workload admits no event-driven formulation, the conventional implementation that does carry it, recorded under the same fields, is itself reportable. Accumulated, such records settle from evidence which architectures suit which workloads.',
      ru: 'Там, где нагрузка не допускает событийной формулировки, обычная реализация, которая её всё же несёт, записанная по тем же полям, сама подлежит публикации. Накопившись, такие записи решают по свидетельству, какие архитектуры каким нагрузкам подходят.',
    },
  },
]

export const cost: Bi[] = [
  {
    en: 'Most of this record is emitted by the apparatus already: digests, version strings, tool reports and counter reads that a build and a measurement run produce anyway. Two are not free: the instance count with its spread, and the re-measurement of earlier tasks after adaptation.',
    ru: 'Бóльшую часть этой записи аппарат выдаёт и так: хеши, строки версий, отчёты инструментов и показания счётчиков, которые сборка и прогон производят в любом случае. Два поля не бесплатны: число экземпляров с разбросом и перемер прежних задач после адаптации.',
  },
  {
    en: 'Against the disclosure rules established benchmark bodies already operate, what is added here is the device instance and its calibration state, the observed activity, the pinned interface representation, and non-destructive vector versioning.',
    ru: 'По сравнению с правилами раскрытия, которые устоявшиеся бенчмарк-организации уже применяют, здесь добавлены экземпляр прибора с состоянием калибровки, наблюдённая активность, закреплённое представление на интерфейсе и неразрушающее версионирование векторов.',
  },
  {
    en: 'A result missing a field remains publishable; a comparison against it is not supported. A complete record does not make a measurement a good one — it makes the result comparable, and its absence visible.',
    ru: 'Результат без какого-то поля остаётся публикуемым; сравнение с ним — не обосновано. Полная запись не делает измерение хорошим — она делает результат сравнимым, а его отсутствие видимым.',
  },
]

/**
 * The counts the prose quotes, read off the table rather than typed beside it.
 * The 16 September submission typed them, and got one wrong — see `withdrawn`.
 */
export const marked = {
  fields: record.length,
  /** Fields a case that still stands pays for. */
  measured: record.filter((r) => r.anchoredTo.some((a) => a !== 'withdrawn')).length,
  /**
   * Fields whose only anchor is the COUNT this document withdrew -- the
   * defective-row count in a conformance vector set. No case was withdrawn;
   * all three still stand. Calling it a withdrawn case misnames what was
   * retracted, on a page whose whole subject is naming that correctly.
   */
  onWithdrawn: record.filter((r) => r.anchoredTo.every((a) => a === 'withdrawn') && r.anchoredTo.length > 0).length,
}

/**
 * The two marks, in one place. The table derives its glyph per row; the prose
 * used to type `†` beside it, and drifted -- the sent document's open question
 * called the withdrawn-anchor field `†` while the table drew `‡` and the note
 * below it said that row is counted apart. Prose disagreeing with its own table
 * is the exact defect this document exists to condemn, so the glyph is read
 * from here by both and can no longer be typed twice.
 */
export const MARK = { anchored: '†', onWithdrawn: '‡' } as const

export const questions: Bi[] = [
  {
    en: 'Does the table belong in this position statement at all, or in a separate reporting-requirements deliverable that this statement cites?',
    ru: 'Место ли этой таблице в самом позиционном документе — или в отдельном документе о требованиях к отчётности, на который он ссылается?',
  },
  {
    en: `${marked.fields} fields is a large ask for a first revision. If the team wants a shorter list, which failure is it willing to leave undetectable? I would defend the ${marked.measured} marked ${MARK.anchored} that rest on a case that still stands before the rest; a further ${marked.onWithdrawn} carries ${MARK.onWithdrawn} rather than ${MARK.anchored}, anchored only to a count this document has since withdrawn, and that one I would not defend at all.`,
    ru: `${marked.fields} полей — много для первой редакции. Если группа хочет короче, какой отказ она готова оставить необнаружимым? Я защищал бы прежде всего ${marked.measured} помеченных ${MARK.anchored}, стоящих на случае, который ещё держится; ещё ${marked.onWithdrawn} поле несёт ${MARK.onWithdrawn}, а не ${MARK.anchored}: за ним стоит только число, которое этот документ с тех пор отозвал, и его я защищать не стал бы вовсе.`,
  },
  {
    en: 'The measurement-boundary row has independent support: George Williams raised exactly this objection on the list on 8 September, about an energy figure whose envelope excluded memory fetching until the appendix. I have asked him to co-sign that row. It is his objection before it is my table.',
    ru: 'У строки о границе измерения есть независимая поддержка: Джордж Уильямс поднял ровно это возражение в рассылке 8 сентября — про число по энергии, из чьего контура выборка из памяти была исключена до самого приложения. Я попросил его подписать эту строку вместе со мной. Это его возражение прежде, чем моя таблица.',
  },
  {
    en: 'Is there anyone on the team with a neuromorphic part in hand who would try filling this record for one real result? That is the test the document has not had.',
    ru: 'Есть ли в группе кто-нибудь с нейроморфной микросхемой на руках, кто попробовал бы заполнить эту запись для одного настоящего результата? Это та проверка, которой документ ещё не проходил.',
  },
]

/** Numbers this document used to carry and no longer does. Kept visible on purpose. */
export const withdrawn: { claim: Bi; why: Bi }[] = [
  {
    claim: {
      en: '“1,206 rows out of 18,684” — a defect count in the published vector set',
      ru: '«1 206 строк из 18 684» — число дефектных строк в опубликованном наборе векторов',
    },
    why: {
      en: '18,684 is sourced (18 files × 1,038 rows). 1,206 is in no source: the only statement of the defect count anywhere is a range, between 47 and 86 per file, i.e. 846–1,548. The count is withdrawn; the practice it illustrated stands.',
      ru: '18 684 подтверждено (18 файлов × 1 038 строк). 1 206 нет ни в одном источнике: единственное утверждение о числе дефектов — это диапазон, от 47 до 86 на файл, то есть 846–1 548. Число отозвано; практика, которую оно иллюстрировало, остаётся.',
    },
  },
  {
    claim: {
      en: '“repaired set” — said of the successor vector set',
      ru: '«исправленный набор» — о наборе-преемнике',
    },
    why: {
      en: 'The successor is a full regeneration, not a targeted repair: the per-rung seed is derived by hashing the version string, so bumping it re-draws the entire stream. 18,297 of 18,684 rows differ. Now reads “regenerated”. A correction is owed on the messages already sent.',
      ru: 'Преемник — полная перегенерация, а не точечная починка: сид ступени выводится хешированием строки версии, поэтому её смена перерисовывает весь поток. Различаются 18 297 строк из 18 684. Теперь читается «перегенерированный». По уже отправленным письмам причитается поправка.',
    },
  },
  {
    claim: {
      en: 'An arXiv reference cited in the 5 September draft',
      ru: 'Ссылка на arXiv, приведённая в черновике от 5 сентября',
    },
    why: {
      en: 'It could not be verified. A document about provenance does not carry an unchecked citation.',
      ru: 'Проверить её не удалось. Документ о происхождении данных не носит непроверенную ссылку.',
    },
  },
  {
    claim: {
      en: '“the four marked †” — the count of anchored fields, as submitted on 16 September',
      ru: '«четыре помеченных †» — число опирающихся полей, как подано 16 сентября',
    },
    why: {
      en: `The table marks six, not four. Five rest on a case that still stands — artifact identity and build arithmetic on case 2, stimulus identity on case 1, interface representation on case 3, uncertainty on cases 1 and 2. The sixth, specification version and manifest, is anchored only to the defective-vector-set count this document itself withdrew, so its † is worth less than the others and is now counted apart. The counts on this page are read off the table (see \`marked\`) and can no longer drift from it; the sent document still says four, and a correction is owed on it.`,
      ru: `Таблица помечает шесть, а не четыре. Пять стоят на случае, который ещё держится: тождество артефакта и арифметика сборки — на случае 2, тождество стимула — на случае 1, представление на интерфейсе — на случае 3, неопределённость — на случаях 1 и 2. Шестое, версия спецификации и манифест, опирается только на число дефектных векторов, которое этот документ сам и отозвал, — его † стоит меньше прочих и теперь считается отдельно. Числа на этой странице читаются из самой таблицы (см. \`marked\`) и разойтись с ней больше не могут; в отправленном документе по-прежнему стоит «четыре», и по нему причитается поправка.`,
    },
  },
]
