import type { Block } from '../types'

export const body: Block[] = [
  {
    kind: 'p',
    text: "IGLA's board-sized model, tern_tc, has 9.08M parameters. 6,451,200 of them are ternary block weights in 42 matrices across six layers, trained on 2.0B tokens of code to 0.7613 validation bits per byte. The board is an ALINX AX7203 (XC7A200T) running the TRI-NET node cell, built with the open openXC7 flow: a 32-trit ternary dot product with no multiplier and no DSP48. It answers each job with the result, the job's nonce, a node id and a SipHash-2-4 tag over all of them. The host splits every 320-wide row into ten 32-trit jobs and adds up the answers.",
  },
  {
    kind: 'h',
    text: 'What the board did',
  },
  {
    kind: 'table',
    head: ['Run (AX7203, 1,144,744 baud)', 'Jobs', 'Rows bit-exact', 'Receipt tags compared?', 'Time'],
    rows: [
      ['Random 320x320 ternary matvec', '3,200', '320 / 320', 'yes', '0.67 s'],
      ['Layer 0 wq, trained weights', '12,800', '1,280 / 1,280', 'no', '2.7 s'],
      ['wq, wo, gate, up in all six layers', '284,160', '28,416 / 28,416', 'no', '62.4 s'],
    ],
  },
  {
    kind: 'p',
    text: "The activations were ternary vectors, not the model's int8 activations. So this shows the trained weight matrices computed exactly. It is not a forward pass of the model.",
  },
  {
    kind: 'h',
    text: 'The receipts in the last two rows were never compared',
  },
  {
    kind: 'p',
    text: "The layer harness built each receipt's preimage and then dropped it, and the key it loaded was never used. It counted status byte 0x01 as authentication. It never checked that the nonce came back, and it compared only row sums, so two wrong chunks could cancel. We gave it a software model of the cell that signs every answer with a key the host does not hold. It printed 'receipts authenticated 160/160' and PASS.",
  },
  {
    kind: 'p',
    text: "What stands: every row value in the table matched the CPU oracle, and the random-matrix run did compare its tags. What is withdrawn until the board reruns: '284,160 receipts authenticated under node0's key'.",
  },
  {
    kind: 'h',
    text: 'The fixed harness, and seven ways to make it fail',
  },
  {
    kind: 'p',
    text: "A response now counts only if all five of these hold. Its status is 0x01. Its nonce was issued by this run and answered once. Its node id matches the first answer. Its SipHash tag recomputes under the key. Its y equals that chunk's dot product. A row passes only if every chunk passed and their sum equals the row dot computed directly from the model's int8 weights, not from the packed wire bytes. Each check is shown able to fail:",
  },
  {
    kind: 'table',
    head: ['What the cell does wrong', 'Harness verdict'],
    rows: [
      ['signs with another key', 'rejected: tag'],
      ['returns a wrong answer and signs it validly', 'rejected: lie'],
      ['flips one tag bit', 'rejected: tag'],
      ['answers with a nonce the run never issued', 'rejected: fabricated'],
      ['answers as another node id', 'rejected: node'],
      ['drops a response', 'rejected: short read, run stops'],
      ['was never keyed (status 0x04)', 'no credit, though y is right'],
    ],
  },
  {
    kind: 'h',
    text: 'The same bytes through the RTL',
  },
  {
    kind: 'p',
    text: "The cell's own source, trinet_node_core.v and trinet_siphash24.v, unchanged, was simulated in Icarus Verilog at UART bit level. The key was installed over the wire exactly as on the board. The weights are random ternary values in tern_tc's exact shapes, because the trained model file is not in this environment.",
  },
  {
    kind: 'table',
    head: ['RTL run', 'Jobs', 'Rows bit-exact', 'Receipts verified'],
    rows: [
      ['Layer 0, all seven matrices, w_down as 27 chunks', '67,200', '5,632 / 5,632', '67,200 / 67,200'],
      ['Layer 5 w_down, int8 activations (6 digit planes)', '51,840', '320 / 320', '51,840 / 51,840'],
      ['Layer 0 wk, node never keyed', '640', '0 / 64', '0 / 640 (status 0x04)'],
      ['Layer 0 wk, checked under a different key', '1,280', '0 / 128', '0 / 1,280'],
    ],
  },
  {
    kind: 'h',
    text: 'Two items booked as new hardware need none',
  },
  {
    kind: 'p',
    text: 'w_down was left out because its input is 864 wide and the plan called for a wider cell. It does not need one: 864 = 27 x 32, so it is 27 jobs per row on the same cell. wk and wv have 320-wide inputs and were simply skipped. Together that is all 42 ternary matrices and all 6,451,200 weights on the existing bitstream.',
  },
  {
    kind: 'p',
    text: 'int8 activations were Stage B.3, which planned new RTL. Every integer from -364 to 364 is a sum of six balanced-ternary digits: q = sum of 3^k d_k with each d_k in {-1, 0, +1}. So w.q = sum of 3^k (w.d_k), and each w.d_k is an ordinary ternary job. Six jobs per chunk replace a new datapath. The cell stays ternary, and the host applies the powers of three in the open.',
  },
  {
    kind: 'h',
    text: 'What this is not',
  },
  {
    kind: 'ul',
    items: [
      'Not a forward pass. Embeddings, norms, attention, the softmax and the head run nowhere on the board.',
      'Not fast. At the measured 4,560 jobs/s, one token takes about 44 s with ternary activations (201,600 jobs) and about 265 s with int8 (1,209,600 jobs). Both times are derived, not measured. The UART makes this a verification instrument, not an inference engine.',
      "Not a public proof. SipHash is a shared-key MAC: it tells the key holder which node answered. A third party cannot check a receipt with it, and it does not stop an operator forging their own.",
    ],
  },
  {
    kind: 'h',
    text: 'Next',
  },
  {
    kind: 'ol',
    items: [
      'Rerun the fixed harness on the board: one command, all 42 matrices, about 403,200 jobs, about 90 s at the measured rate.',
      'Real activations: dump the int8 inputs tc_infer computes for a real prompt, and run a whole layer with them.',
      'Leave the UART: move to Ethernet or a USB FIFO, and measure it on the board.',
      'Make receipts checkable by anyone: publish a Merkle root of each run, and add random re-execution or Freivalds checks. Both are cheap for ternary matvecs.',
      'Measure power on a bench supply. Without it there is no energy comparison to publish.',
    ],
  },
]

export const ruBody: Block[] = [
  {
    kind: 'p',
    text: 'Модель IGLA размером с плату, tern_tc, — это 9,08M параметров. Из них 6 451 200 — тернарные веса блоков: 42 матрицы в шести слоях. Модель обучена на 2,0 млрд токенов кода до 0,7613 бит на байт на валидации. Плата — ALINX AX7203 (XC7A200T) с ячейкой узла TRI-NET, собранной открытым тулчейном openXC7. Ячейка считает тернарное скалярное произведение на 32 трита без умножителя и без DSP48. На каждую задачу она отвечает результатом, nonce задачи, id узла и тегом SipHash-2-4 по всему этому. Хост режет каждую строку шириной 320 на десять задач по 32 трита и складывает ответы.',
  },
  {
    kind: 'h',
    text: 'Что сделала плата',
  },
  {
    kind: 'table',
    head: ['Прогон (AX7203, 1 144 744 бод)', 'Задач', 'Строк бит-точно', 'Теги квитанций сверялись?', 'Время'],
    rows: [
      ['Случайный тернарный matvec 320x320', '3 200', '320 / 320', 'да', '0,67 с'],
      ['Слой 0, wq, обученные веса', '12 800', '1 280 / 1 280', 'нет', '2,7 с'],
      ['wq, wo, gate, up во всех шести слоях', '284 160', '28 416 / 28 416', 'нет', '62,4 с'],
    ],
  },
  {
    kind: 'p',
    text: 'Активации были тернарными векторами, а не int8-активациями модели. Это показывает, что обученные матрицы весов считаются точно. Прямым проходом модели это не является.',
  },
  {
    kind: 'h',
    text: 'Квитанции в двух последних строках никто не сверял',
  },
  {
    kind: 'p',
    text: 'Харнесс слоя собирал прообраз каждой квитанции и выбрасывал его, а загруженный ключ не использовался вовсе. Аутентификацией он считал байт статуса 0x01. Возврат nonce он не проверял и сравнивал только суммы строк, так что две ошибки в кусках могли взаимно погаситься. Мы подключили к нему программную модель ячейки, которая подписывает каждый ответ ключом, которого у хоста нет. Он напечатал «receipts authenticated 160/160» и PASS.',
  },
  {
    kind: 'p',
    text: 'Что остаётся в силе: каждое значение строк в таблице совпало с CPU-оракулом, а прогон случайной матрицы свои теги сверял. Что отозвано до повторного прогона на плате: «284 160 квитанций аутентифицировано под ключом node0».',
  },
  {
    kind: 'h',
    text: 'Исправленный харнесс и семь способов его завалить',
  },
  {
    kind: 'p',
    text: 'Теперь ответ засчитывается, только если выполнены все пять условий. Статус равен 0x01. Nonce выдан этим прогоном, и ответ на него пришёл один раз. Id узла совпадает с первым ответом. Тег SipHash пересчитывается под ключом. y равен скалярному произведению этого куска. Строка проходит, только если прошли все её куски и их сумма равна скалярному произведению строки, посчитанному прямо по int8-весам модели, а не по упакованным байтам провода. Для каждой проверки показано, что она умеет падать:',
  },
  {
    kind: 'table',
    head: ['Что ячейка делает не так', 'Вердикт харнесса'],
    rows: [
      ['подписывает чужим ключом', 'отвергнуто: tag'],
      ['отдаёт неверный ответ с корректной подписью', 'отвергнуто: lie'],
      ['портит один бит тега', 'отвергнуто: tag'],
      ['отвечает nonce, которого прогон не выдавал', 'отвергнуто: fabricated'],
      ['отвечает от имени другого узла', 'отвергнуто: node'],
      ['теряет ответ', 'отвергнуто: short read, прогон останавливается'],
      ['ключ так и не установлен (статус 0x04)', 'не засчитано, хотя y верный'],
    ],
  },
  {
    kind: 'h',
    text: 'Те же байты через RTL',
  },
  {
    kind: 'p',
    text: 'Собственные исходники ячейки, trinet_node_core.v и trinet_siphash24.v, без изменений, симулированы в Icarus Verilog на уровне битов UART. Ключ ставился по проводу ровно так же, как на плате. Веса — случайные тернарные значения точно в формах tern_tc, потому что файла обученной модели в этом окружении нет.',
  },
  {
    kind: 'table',
    head: ['Прогон RTL', 'Задач', 'Строк бит-точно', 'Квитанций проверено'],
    rows: [
      ['Слой 0, все семь матриц, w_down по 27 кускам', '67 200', '5 632 / 5 632', '67 200 / 67 200'],
      ['Слой 5, w_down, int8-активации (6 разрядов)', '51 840', '320 / 320', '51 840 / 51 840'],
      ['Слой 0, wk, ключ не установлен', '640', '0 / 64', '0 / 640 (статус 0x04)'],
      ['Слой 0, wk, проверка под другим ключом', '1 280', '0 / 128', '0 / 1 280'],
    ],
  },
  {
    kind: 'h',
    text: 'Две задачи, записанные в новое железо, его не требуют',
  },
  {
    kind: 'p',
    text: 'w_down пропустили, потому что у неё вход шириной 864, и по плану для неё нужна была ячейка шире. Не нужна: 864 = 27 x 32, то есть это 27 задач на строку на той же ячейке. У wk и wv вход шириной 320, их просто пропустили. Вместе это все 42 тернарные матрицы и все 6 451 200 весов на текущем битстриме.',
  },
  {
    kind: 'p',
    text: 'int8-активации числились за Stage B.3, где планировался новый RTL. Любое целое от -364 до 364 — это сумма шести сбалансированно-троичных разрядов: q = сумма 3^k d_k, где каждый d_k из {-1, 0, +1}. Значит, w.q = сумма 3^k (w.d_k), и каждое w.d_k — обычная тернарная задача. Шесть задач на кусок заменяют новый тракт данных. Ячейка остаётся тернарной, а степени тройки хост применяет открыто.',
  },
  {
    kind: 'h',
    text: 'Чем это не является',
  },
  {
    kind: 'ul',
    items: [
      'Это не прямой проход. Эмбеддинги, нормы, внимание, softmax и голова на плате не выполняются.',
      'Это не быстро. При измеренных 4 560 задачах/с один токен занимает около 44 с с тернарными активациями (201 600 задач) и около 265 с с int8 (1 209 600 задач). Оба времени выведены, а не измерены. Из-за UART это инструмент проверки, а не движок вывода.',
      'Это не публичное доказательство. SipHash — MAC с общим ключом: он сообщает владельцу ключа, какой узел ответил. Третья сторона не может им проверить квитанцию, и он не мешает оператору подделать свои собственные.',
    ],
  },
  {
    kind: 'h',
    text: 'Дальше',
  },
  {
    kind: 'ol',
    items: [
      'Перезапустить исправленный харнесс на плате: одна команда, все 42 матрицы, около 403 200 задач, около 90 с при измеренной скорости.',
      'Реальные активации: выгрузить int8-входы, которые tc_infer считает для настоящего промпта, и прогнать с ними целый слой.',
      'Уйти с UART: перейти на Ethernet или USB FIFO и измерить это на плате.',
      'Сделать квитанции проверяемыми для всех: публиковать корень Меркла каждого прогона и добавить случайное перевычисление или проверки Фрейвалдса. Для тернарных matvec и то и другое стоит дёшево.',
      'Измерить мощность от лабораторного блока питания. Без этого публиковать сравнение по энергии нечем.',
    ],
  },
]
