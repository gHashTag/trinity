import type { Block } from '../types'

export const body: Block[] = [
    { kind: 'h', text: 'What happened, in one paragraph' },
    { kind: 'p', text:
      'On 18 July 2026 a payload left node .13, crossed the air to .12, crossed the air again to .10, and arrived byte-exact. No Ethernet anywhere in the path, and no host in the relay: the middle node demodulated the capture, recovered the payload set, and re-emitted regenerated DBPSK entirely on its own chip. Four P201 Mini boards, each a Zynq-7020 with an AD9361. The coverage seal computed at the origin, at the first hop and at the second hop was the same value, 0x9DBE2510.' },
    { kind: 'h', text: 'Why the seal is the point and the radio is not' },
    { kind: 'p', text:
      'A radio link that carries bytes intact is ordinary engineering; commercial mesh radios do it better and have done for years. What is unusual is that each hop leaves a receipt, and that the receipts agree. The seal commits to the distinct payload set, so a relay cannot silently drop, duplicate or invent traffic and still produce the same value. Three independent witnesses in a separate four-node run each computed 0xCDB1F3B1 from their own capture, without coordination.' },
    { kind: 'p', text:
      'That turns a delivery into an auditable event. The question a mesh usually cannot answer is who relayed what, and whether the relay is telling the truth about it. Here the answer is a number that three parties derived separately and that a fourth can recompute from the recorded samples.' },
    { kind: 'h', text: 'The defect the run found' },
    { kind: 'p', text:
      'One frame with bit errors passed the correlation threshold of 0.9 and produced a phantom payload, which changed the seal. That is exactly the failure a seal exists to expose, and it did. The fix is a majority filter across repeated frames rather than a single-frame decision. Recording it matters more than the result it spoils: a provenance mechanism that has never caught anything has not been tested.' },
    { kind: 'h', text: 'The shortest description of it is an accountant' },
    { kind: 'p', text:
      'Calling this verifiable compute is abstract enough to need explaining. The concrete description is bookkeeping: a node issues a receipt for the bytes it carried and the work it did, signs it with its own key, and a settlement aggregator checks eight invariants before admitting a payout. The coverage seal is the checksum on the entry. Double-entry, in hardware.' },
    { kind: 'p', text:
      'That also says how it grows. The property that matters is not that many nodes can join but that agreement is checkable without collusion - three witnesses computed the same seal from their own captures, separately. Each new node is one more independent witness, and any two can be reconciled pairwise without a central ledger. A network where each node is its neighbour\'s accountant, and the books reconcile without trust between them.' },
    { kind: 'p', text:
      'The limit is equally concrete: this is four nodes, not forty. How convergence and capacity behave as the count rises has never been measured, and the demodulation is still an offline batch. Today the chain proves provenance; it is not yet a live link.' },
    { kind: 'h', text: 'The other half: compute that can be checked' },
    { kind: 'p', text:
      'A receipt for delivery is worth little without a receipt for the work. GF-T16 multiplication was placed and routed through the open flow, flashed to an ALINX AX7203 and checked over UART: five of five bit-exact against an independent software oracle, then a two-term dot product three of three. Ed25519 receipts are produced on the ARM core against the node key, and the settlement aggregator enforces eight invariants before a payout is admitted.' },
    { kind: 'p', text:
      'The whole path from Verilog to bitstream runs without a vendor licence. That is not a cost argument. It means the toolchain itself can be inspected, and a third party can rebuild the bitstream and get the same bits rather than taking a vendor binary on trust.' },
    { kind: 'h', text: 'Where this is genuinely useful, in civilian terms' },
    { kind: 'p', text:
      'Contested environmental measurement. When a community disputes an emissions or water-quality reading, the argument is rarely about physics; it is about whether the number came from the instrument it claims to. A sealed chain from sensor through relays to the archive answers that without either side trusting the other.' },
    { kind: 'p', text:
      'Paid relay in rural and remote coverage. If a household relays traffic for its neighbours, somebody has to be paid for bytes actually carried. Metered receipts signed by the relaying node, aggregated under invariants, are the settlement primitive that makes community-owned coverage a business rather than charity.' },
    { kind: 'p', text:
      'Disaster relief on borrowed hardware. In the first days after an event the mesh is assembled from whatever is at hand, owned by strangers. You need to route through a node without trusting its owner, and afterwards to reconstruct what went where. Per-hop receipts give both.' },
    { kind: 'p', text:
      'Regulated telemetry with an audit obligation. Utilities, grid operators and industrial monitoring already log everything; what they lack is evidence that a log was not edited between the meter and the report. A seal three parties compute independently is cheaper than a trusted appliance.' },
    { kind: 'p', text:
      'Scientific instrumentation that has to be re-runnable. Bit-exact numeric formats with published conformance vectors, on a toolchain anyone can install, mean a computation done on this hardware in 2026 can be reproduced on other hardware later. That sounds like a weak claim only to someone who has never tried to reproduce a decade-old FPGA result.' },
    { kind: 'h', text: 'What we are not claiming' },
    { kind: 'p', text:
      'This is not a competitor to Doodle Labs, Silvus or Persistent Systems on radio performance. Against a published comparison across eight metrics, tri-net wins exactly one - openness of the wire specification, where 107 published .t27 files stand against nothing comparable from any of the six - and has no measurement at all on throughput, multi-hop falloff, self-healing time or power. An honest scoreboard is why the rest of this page can be believed.' },
    { kind: 'h', text: 'Roadmap for partners' },
    { kind: 'p', text:
      'Stage one, now: toolchain regression. Twenty-six patches are merged into openXC7/nextpnr-xilinx, more than from any other contributor, and every one came from a real design failing rather than from a synthetic test. What we offer a toolchain project is a standing set of industrial designs run against each release, delivered as patches with reproductions. What we need is the status of a regression target.' },
    { kind: 'p', text:
      'Stage two, next: a measured link. The gap that blocks every commercial conversation is the absence of a throughput number. The work is a payload sweep across hop counts with frame-error rate measured directly rather than inferred, plus a convergence timing harness. It needs no new hardware and is the highest-value experiment outstanding.' },
    { kind: 'p', text:
      'Stage three, with a vendor: real-time demodulation. The four-node result is offline batch processing. Moving it into the fabric is a known amount of work on a known part, and the budget has room - roughly 35,000 LUTs, 84,000 flip-flops and 208 DSP slices are free on the Zynq-7020 after the current design.' },
    { kind: 'p', text:
      'Stage four, with a fabricator: silicon. There is no die and no route to one after the TTSKY26b withdrawal, so every silicon-anchored claim is marked as having no route. A partner here changes the roadmap; nothing else does.' },
    { kind: 'p', text:
      'For stage one the relationship already exists in the form of merged code, and the ask is only to formalise it. For the rest the honest position is that we have the evidence discipline and the open flow, and we are missing the measurements a buyer needs. Those measurements are cheap. Saying so is the fastest way to find someone who wants them made.' },
  ]

export const ruBody: Block[] = [
      { kind: 'h', text: 'Что произошло, одним абзацем' },
      { kind: 'p', text:
        '18 июля 2026 года полезная нагрузка ушла с узла .13, прошла по воздуху на .12, снова по воздуху на .10 и пришла байт-в-байт. Ethernet в тракте нет нигде, и хоста в ретрансляторе нет: средний узел демодулировал захват, восстановил набор нагрузок и заново излучил DBPSK целиком на своём кристалле. Четыре платы P201 Mini, в каждой Zynq-7020 и AD9361. Печать покрытия, посчитанная в источнике, на первом скачке и на втором, дала одно значение - 0x9DBE2510.' },
      { kind: 'h', text: 'Почему дело в печати, а не в радиоканале' },
      { kind: 'p', text:
        'Радиоканал, переносящий байты без порчи, - обычная инженерия; серийные mesh-радиостанции делают это лучше и давно. Необычно другое: каждый скачок оставляет квитанцию, и квитанции сходятся. Печать фиксирует набор различных нагрузок, поэтому ретранслятор не может втихую потерять, продублировать или выдумать трафик и получить то же значение. В отдельном четырёхузловом прогоне три независимых свидетеля посчитали 0xCDB1F3B1 каждый по своему захвату, не сговариваясь.' },
      { kind: 'p', text:
        'Это превращает доставку в событие, поддающееся аудиту. Вопрос, на который сеть обычно ответить не может, - кто что ретранслировал и говорит ли он об этом правду. Здесь ответ - число, которое три стороны получили порознь, а четвёртая может пересчитать по записанным отсчётам.' },
      { kind: 'h', text: 'Дефект, который нашёл прогон' },
      { kind: 'p', text:
        'Один кадр с битовыми ошибками прошёл порог корреляции 0,9 и породил фантомную нагрузку, изменившую печать. Это ровно тот отказ, который печать и должна обнаруживать, и она его обнаружила. Лечится мажоритарным фильтром по повторам вместо решения по одному кадру. Записать это важнее полученного результата: механизм происхождения, ни разу ничего не поймавший, не проверен.' },
      { kind: 'h', text: 'Короче всего это описывается словом «бухгалтер»' },
      { kind: 'p', text:
        'Называть это проверяемыми вычислениями - абстракция, которую приходится объяснять. Конкретное описание - учёт: узел выписывает квитанцию за перенесённые байты и выполненную работу, подписывает её своим ключом, а сводящий агрегатор проверяет восемь инвариантов, прежде чем допустить выплату. Печать покрытия - контрольная сумма проводки. Двойная запись, только в железе.' },
      { kind: 'p', text:
        'Отсюда же видно, как это растёт. Существенно не то, что узлов может быть много, а что согласие проверяется без сговора: три свидетеля посчитали одну и ту же печать каждый по своему захвату, порознь. Каждый новый узел - ещё один независимый свидетель, и любые два сводятся попарно, без центрального реестра. Сеть, где каждый узел - бухгалтер соседа, и книги сходятся без доверия между ними.' },
      { kind: 'p', text:
        'Граница столь же конкретна: это четыре узла, а не сорок. Как ведут себя сходимость и ёмкость при росте числа - не измерялось, а демодуляция остаётся пакетной. Сегодня цепочка доказывает происхождение данных, но ещё не работает как живой канал.' },
      { kind: 'h', text: 'Вторая половина: вычисление, которое можно сверить' },
      { kind: 'p', text:
        'Квитанция за доставку немного стоит без квитанции за работу. Умножение GF-T16 разведено открытым потоком, прошито в ALINX AX7203 и сверено по UART: пять из пяти побитово против независимого программного эталона, затем скалярное произведение из двух слагаемых - три из трёх. Квитанции Ed25519 выпускаются на ядре ARM ключом узла, а агрегатор расчёта проверяет восемь инвариантов, прежде чем допустить выплату.' },
      { kind: 'p', text:
        'Весь путь от Verilog до битстрима идёт без вендорской лицензии. Это не про стоимость. Это значит, что сам инструментарий можно проверить, а третья сторона может пересобрать битстрим и получить те же биты, а не принимать вендорский двоичный файл на веру.' },
      { kind: 'h', text: 'Где это действительно нужно, в гражданском обороте' },
      { kind: 'p', text:
        'Спорное экологическое измерение. Когда сообщество оспаривает показание по выбросам или качеству воды, спор идёт не о физике, а о том, вышло ли число из того прибора, на который ссылаются. Запечатанная цепочка от датчика через ретрансляторы в архив отвечает на это, не требуя, чтобы стороны доверяли друг другу.' },
      { kind: 'p', text:
        'Оплачиваемая ретрансляция в сельском и удалённом покрытии. Если домохозяйство пропускает трафик соседей, кто-то должен получать плату за реально перенесённые байты. Метрируемые квитанции, подписанные ретранслирующим узлом и сведённые под инвариантами, - это и есть примитив расчёта, превращающий общинное покрытие из благотворительности в дело.' },
      { kind: 'p', text:
        'Ликвидация последствий на чужом оборудовании. В первые дни сеть собирают из того, что под рукой, и владеют этим посторонние люди. Нужно маршрутизировать через узел, не доверяя его хозяину, а потом восстановить, что куда прошло. Поскачковые квитанции дают и то, и другое.' },
      { kind: 'p', text:
        'Регулируемая телеметрия с обязанностью аудита. Коммунальные и сетевые операторы и без того пишут журналы; чего им не хватает - свидетельства, что журнал не правили между счётчиком и отчётом. Печать, которую три стороны считают независимо, дешевле доверенного устройства.' },
      { kind: 'p', text:
        'Научные приборы, чей результат обязан быть повторяемым. Побитовые числовые форматы с опубликованными векторами соответствия, на инструментарии, который может поставить любой, означают, что вычисление 2026 года воспроизведут на другом железе позже. Слабым это утверждение кажется лишь тому, кто не пробовал воспроизвести результат на ПЛИС десятилетней давности.' },
      { kind: 'h', text: 'Чего мы не утверждаем' },
      { kind: 'p', text:
        'Это не конкурент Doodle Labs, Silvus или Persistent Systems по радиохарактеристикам. В опубликованном сравнении по восьми метрикам tri-net выигрывает ровно одну - открытость спецификации, где 107 опубликованных файлов .t27 стоят против ничего сопоставимого у всех шести, - и не имеет измерения вовсе по пропускной способности, спаду на скачках, времени самовосстановления и питанию. Честное табло и есть причина, по которой остальному на этой странице можно верить.' },
      { kind: 'h', text: 'Дорожная карта для партнёров' },
      { kind: 'p', text:
        'Ступень первая, сейчас: регрессия инструментария. Двадцать шесть патчей слиты в openXC7/nextpnr-xilinx - больше, чем у любого другого участника, - и каждый вырос из отказа на реальном дизайне, а не из синтетического теста. Проекту инструментария мы предлагаем постоянный набор промышленных дизайнов, прогоняемых на каждом выпуске, с патчами и воспроизведением. Нужен нам статус регрессионного полигона.' },
      { kind: 'p', text:
        'Ступень вторая, следующая: измеренный канал. Разговор с покупателем упирается в отсутствие числа пропускной способности. Работа - развёртка нагрузки по числу скачков с прямым измерением частоты ошибок кадра вместо вывода из косвенного, плюс стенд времени сходимости. Нового железа не требует и остаётся самым ценным незакрытым опытом.' },
      { kind: 'p', text:
        'Ступень третья, с вендором: демодуляция в реальном времени. Четырёхузловой результат - офлайновая пакетная обработка. Перенос в ткань - известный объём работы на известном кристалле, и место есть: около 35 000 LUT, 84 000 триггеров и 208 блоков DSP свободны на Zynq-7020 после текущего дизайна.' },
      { kind: 'p', text:
        'Ступень четвёртая, с изготовителем: кремний. Кристалла нет и маршрута к нему после отзыва TTSKY26b нет, поэтому всякое утверждение, привязанное к кремнию, помечено как без маршрута. Партнёр здесь меняет дорожную карту; ничто иное её не меняет.' },
      { kind: 'p', text:
        'Для первой ступени отношения уже существуют в виде слитого кода, и просьба лишь о том, чтобы их оформить. Для остальных честная позиция такова: у нас есть дисциплина доказательств и открытый поток, и не хватает измерений, которые нужны покупателю. Эти измерения дёшевы. Сказать об этом прямо - самый быстрый способ найти того, кому они нужны.' },
    ]
