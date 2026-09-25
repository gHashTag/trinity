import type { Block } from '../types'

export const body: Block[] = [
  {
    kind: 'p',
    text: 'The design question a token forces is who gets the first coins for free. The usual answer is a pre-mine: a founder allocation, a treasury, a liquidity reserve, all minted at deploy. We deleted that. One hundred percent of TRI is mined by accepted work. At genesis the minted supply is zero, and the only way a TRI comes into existence is that a verifier accepted a .t27 spec or a node returned a correct, receipt-backed job.',
  },
  {
    kind: 'p',
    text: 'This is not a marketing stance. It is what makes the token honest rather than speculative, and it changes the legal picture: there is no sale, so there is no buyer handing over money in expectation of profit. The closest precedent — the original Gram token on this same network — was killed by the SEC precisely because it was sold. TRI is not sold. It is panned.',
  },
  {
    kind: 'h',
    text: 'The one hard fact',
  },
  {
    kind: 'p',
    text: 'A blockchain cannot run t27c. So the chain cannot itself check that a spec was accepted. Every honest design for minting-on-work is therefore about who the chain trusts to say the work happened, and how wrong that party can be. We refused to paper over this. The trust model is versioned, weakest-but-shippable first, and labelled for what it is.',
  },
  {
    kind: 'table',
    head: ['Version', 'Mechanism', 'Trust assumption'],
    rows: [
      ['V1 attestor quorum', 'M-of-N signatures are the only mint authority', 'an honest majority of the attestor set — not trustless'],
      ['V2 optimistic', 'mints after a challenge window unless a fraud proof is posted', 'at least one honest challenger, plus a bond'],
      ['V3 receipt proof', 'a succinct proof of acceptance, verified on-chain', 'the proof system only'],
    ],
  },
  {
    kind: 'p',
    text: 'V1 is what ships first, and it is only as decentralised as its attestor set. We will say that in public, and never say "trustless". The FPGA path may reach V3 sooner than the software path, because a board already signs its result, and checking a signature on-chain is far cheaper than proving a compiler run.',
  },
  {
    kind: 'h',
    text: 'What is actually built, and tested',
  },
  {
    kind: 'p',
    text: 'The mint rule is a golden oracle in Zig: it verifies M-of-N real ed25519 signatures over the attestation digest, refuses a spent nonce (no double-mint, including across chains via one shared nonce set), and refuses a mint that would cross the 3^21 cap. It is tested with real keys and real signatures, so the security properties are executed, not asserted in prose.',
  },
  {
    kind: 'code',
    text: 'All 11 tests passed.\n  genesis minted supply is zero\n  a valid M-of-N quorum mints exactly the amount\n  a sub-quorum / repeated / non-attestor signature mints nothing\n  a spent nonce is refused — no double-mint\n  the same global nonce cannot mint on a second chain\n  a TON quorum does not authorise a Solana mint\n  a mint over the cap is refused and consumes no nonce\n  digest matches the cross-language golden vector',
  },
  {
    kind: 'p',
    text: 'The two chain minters — a TON jetton contract and a Solana program — must reproduce that oracle exactly. The Solana side is verified host-side with cargo test: the attestation digest is byte-identical across Zig, Python and Rust (one golden vector, 9ce2cee5…), and the Ed25519 instruction parser and quorum count behave as the oracle does. A divergence is a bug in the contract, not the oracle.',
  },
  {
    kind: 'h',
    text: '10 Billion Token Twin Experiment: FP vs Ternary 100M',
  },
  {
    kind: 'p',
    text: 'To test whether the quality gap between full-precision and ternary weights narrows with dataset scale, we completed a controlled twin experiment: two identical 100M parameter models (pair_fp in FP16 and pair_tern in BitNet b1.58 ternary), trained on the exact same 10.0 billion tokens of code.',
  },
  {
    kind: 'table',
head: ['Model', 'Precision', 'Tokens', 'Val Loss', 'Val BPB'],
    rows: [
      ['pair_fp', 'FP16 (16-bit)', '10.0B', '1.1354', '0.4217'],
      ['pair_tern', 'Ternary {-1,0,1}', '10.0B', '1.2718', '0.4722'],
    ],
  },
  {
    kind: 'p',
    text: 'The ternary model achieves 0.4722 bits/byte on held-out code streams — a tight +0.0505 bpb gap (+12.0% loss) against FP16 at full 10B token scale, while running purely on additions rather than matrix multiplications.',
  },
  {
    kind: 'h',
    text: 'What this does not establish',
  },
  {
    kind: 'p',
    text: 'Nothing here is deployed. No contract, key, or mint exists on any live network. The reference contracts are unaudited. Whether the attestor quorum is honest is a governance choice nobody has made yet, and the compliant issuance path — a foundation entity, counsel, the treatment of secondary trading — is the first task this decision creates, not a thing it settles. The token funds no development: development is funded by hardware sales and grants, and the team earns TRI the same way everyone does, by getting its work accepted.',
  },
]

export const ruBody: Block[] = [
  {
    kind: 'p',
    text: 'Токен всегда ставит один вопрос: кому достанутся первые монеты бесплатно. Обычный ответ — премайн: доля основателя, казна, резерв ликвидности, всё начеканено при деплое. Мы это удалили. Сто процентов TRI намывается за принятую работу. На старте начеканено ноль, и единственный способ появления TRI — это что проверяющий принял спеку .t27 или узел вернул верную задачу с квитанцией.',
  },
  {
    kind: 'p',
    text: 'Это не маркетинг. Именно это делает токен обеспеченным, а не спекулятивным, и это меняет юридическую картину: продажи нет, значит нет и покупателя, отдающего деньги в расчёте на прибыль. Ближайший прецедент — исходный токен Gram на этой же сети — SEC убила именно за то, что он продавался. TRI не продаётся. Его намывают.',
  },
  {
    kind: 'h',
    text: 'Один твёрдый факт',
  },
  {
    kind: 'p',
    text: 'Блокчейн не может запустить t27c. Поэтому цепочка не может сама проверить, что спека принята. Любой честный дизайн чеканки за работу сводится к вопросу: кому цепочка доверяет слова о том, что работа была, и насколько сильно этот кто-то может ошибаться. Мы это не спрятали. Модель доверия версионирована, самая слабая-но-рабочая первой, и помечена тем, что она есть.',
  },
  {
    kind: 'table',
    head: ['Версия', 'Механизм', 'Допущение о доверии'],
    rows: [
      ['V1 кворум аттестаторов', 'M-из-N подписей — единственное право чеканки', 'честное большинство аттестаторов — не трастлесс'],
      ['V2 оптимистичный', 'чеканит после окна оспаривания, если нет доказательства мошенничества', 'хотя бы один честный наблюдатель и залог'],
      ['V3 доказательство квитанции', 'краткое доказательство приёмки, проверяемое на контракте', 'только система доказательств'],
    ],
  },
  {
    kind: 'p',
    text: 'Первой выходит V1, и она децентрализована ровно настолько, насколько честен её набор аттестаторов. Мы будем говорить это прямо и никогда не скажем «трастлесс». FPGA-путь может дойти до V3 раньше софтверного: плата уже подписывает результат, а проверить подпись на контракте гораздо дешевле, чем доказать запуск компилятора.',
  },
  {
    kind: 'h',
    text: 'Что реально собрано и проверено',
  },
  {
    kind: 'p',
    text: 'Правило чеканки — золотой оракул на Zig: он проверяет M-из-N настоящих подписей ed25519 над дайджестом аттестации, отклоняет потраченный nonce (нет двойной чеканки, в том числе между цепями через общий набор nonce) и отклоняет чеканку, которая перешагнёт потолок 3^21. Он проверен настоящими ключами и подписями — свойства безопасности исполняются, а не декларируются словами.',
  },
  {
    kind: 'code',
    text: 'All 11 tests passed.\n  генезис = 0\n  валидный кворум M-из-N чеканит ровно сумму\n  недокворум / повтор / чужая подпись → ноль\n  потраченный nonce отклонён — нет двойной чеканки\n  тот же nonce не чеканит на второй цепи\n  кворум TON не годится для Solana\n  выход за потолок отклонён, nonce не тратится\n  дайджест совпал с межъязыковым золотым вектором',
  },
  {
    kind: 'p',
    text: 'Два контракта — jetton на TON и программа на Solana — должны воспроизводить этот оракул точно. Solana-сторона проверена на хосте через cargo test: дайджест аттестации бит-в-бит совпадает у Zig, Python и Rust (один золотой вектор, 9ce2cee5…), а разбор ed25519-инструкции и подсчёт кворума ведут себя как оракул. Расхождение — это баг контракта, а не оракула.',
  },
  {
    kind: 'h',
    text: 'Близнецовый эксперимент на 10 млрд токенов: FP vs Тернарная 100M',
  },
  {
    kind: 'p',
    text: 'Чтобы проверить, сужается ли разрыв в качестве между полной точностью и тернарными весами с объёмом данных, мы завершили контрольный эксперимент: две идентичные модели на 100 млн параметров (pair_fp в FP16 и pair_tern в тернарном BitNet b1.58), обученные на одних и тех же 10.0 миллиардах токенов кода.',
  },
  {
    kind: 'table',
    head: ['Модель', 'Точность весов', 'Токены', 'Val Loss', 'Val BPB'],
    rows: [
      ['pair_fp', 'FP16 (16 бит)', '10.0 млрд', '1.1354', '0.4217'],
      ['pair_tern', 'Тернарная {-1,0,1}', '10.0 млрд', '1.2718', '0.4722'],
    ],
  },
  {
    kind: 'p',
    text: 'Тернарная модель достигает 0.4722 бит на байт на отложенном коде — плотный разрыв всего в +0.0505 bpb (+12.0% по лоссу) против FP16 на полном масштабе 10 млрд токенов, работая исключительно на сложениях вместо умножений.',
  },
  {
    kind: 'h',
    text: 'Что это не устанавливает',
  },
  {
    kind: 'p',
    text: 'Ничего не задеплоено. Ни контракта, ни ключа, ни чеканки в живой сети нет. Эталонные контракты без аудита. Честен ли набор аттестаторов — это решение об управлении, которое ещё никто не принял, а легальный контур выпуска — фонд, юрист, режим вторичного рынка — это первая задача, которую создаёт решение, а не то, что оно закрывает. Токен не финансирует разработку: её финансируют продажа плат и гранты, а команда зарабатывает TRI как все — принятой работой.',
  },
]
