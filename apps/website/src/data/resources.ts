// SOURCE OF TRUTH for every public resource in the Trinity / t27 corpus.
//
// Standing instruction, 2026-08-09: "мой сайт это источник правды для всех ресурсов".
// Every other surface — GitHub profile README, LinkedIn, Habr, Reddit, slide decks —
// must be reconciled AGAINST this file, not the other way round.
//
// Rules for editing:
//   1. `verified` is the date the entry was checked against the live resource. Never bump
//      it without actually re-checking. An unchecked entry keeps its old date.
//   2. `status: 'live'` means the URL was opened and returned the claimed thing.
//      'broken' means it was opened and did not. 'unverified' means nobody looked.
//   3. `note` carries the discrepancy when a resource is described wrongly elsewhere.
//   4. Never describe an unmerged pull request as merged, and never claim an arXiv ID
//      that does not exist.

export type ResourceKind =
  | 'paper'
  | 'dataset'
  | 'repo'
  | 'channel'
  | 'identity'
  | 'service'

export type ResourceStatus = 'live' | 'broken' | 'unverified'

export interface Resource {
  kind: ResourceKind
  title: string
  href: string
  /** Stable identifier: arXiv ID, DOI, handle, ORCID. */
  id?: string
  /** ISO date this row was last checked against the live resource. */
  verified: string
  status: ResourceStatus
  /** A discrepancy, a caveat, or what makes this row load-bearing. */
  note?: string
  /** Русское примечание для страницы /resources. */
  noteRu?: string
}

export const CORPUS_VERIFIED = '2026-08-09'

export const papers: Resource[] = [
  {
    kind: 'paper',
    title:
      'GoldenFloat: A Phi-Derived Static-Split Floating-Point Family from GF4 to GF1024 with a Lucas-Exact Integer Identity',
    href: 'https://arxiv.org/abs/2606.05017',
    id: 'arXiv:2606.05017v3',
    verified: '2026-08-09',
    status: 'live',
    note: 'v3, 22 Jun 2026, 20 pp, cs.AR primary + cs.MS. v1 = 19 pp, v2 = 20 pp.',
    noteRu: "v3, 22 июня 2026 года, 20 страниц, основная рубрика cs.AR плюс cs.MS. v1 — 19 страниц, v2 — 20 страниц.",
  },
  {
    kind: 'paper',
    title:
      'Golden Ruler: A Numeric Format Catalog with Bit-Exact Conformance Vectors for FP8, BF16, MXFP4, and Microscaling Formats',
    href: 'https://arxiv.org/abs/2606.09686',
    id: 'arXiv:2606.09686',
    verified: '2026-09-05',
    status: 'live',
    note:
      'cs.AR primary. v3 (new title, 19 pp) submitted 4 Sep 2026, announces Mon 7 Sep 2026; before the announcement the arXiv page still carries the v2 title, and the versioned v3 identifier does not resolve until then. The format count is a catalog invariant that grows with each version (109 formats at v3; 83 at v2) — do not hard-code it. The 84-format title of v1 is historical.',
    noteRu:
      'Основная рубрика cs.AR. v3 (новый заголовок, 19 страниц) подана 4 сентября 2026 года, анонс в понедельник 7 сентября 2026 года; до анонса страница arXiv ещё несёт заголовок v2, а версионный идентификатор v3 до этого не открывается. Число форматов в каталоге растёт от версии к версии (109 форматов в v3; 83 в v2) — не зашивать его в тексты. Заголовок v1 про 84 формата — историческая запись.',
  },
  {
    kind: 'paper',
    title: 'Ternary Network Floats',
    href: 'https://github.com/gHashTag/trinity-fpga/tree/main/research/arxiv_tnf',
    id: 'MICPRO-D-26-00839',
    verified: '2026-09-05',
    status: 'live',
    note:
      'Journal manuscript, under review at Microprocessors and Microsystems (Elsevier), submitted 3 Sep 2026 (MICPRO-D-26-00839). No arXiv preprint. The link is to the source directory, not a PDF.',
    noteRu:
      'Журнальная рукопись, на рецензии в Microprocessors and Microsystems (Elsevier), подана 3 сентября 2026 года (MICPRO-D-26-00839). Препринта на arXiv нет. Ссылка ведёт в каталог с исходниками, а не на PDF.',
  },
]

export const datasets: Resource[] = [
  {
    kind: 'dataset',
    title: 'GoldenFloat: φ-Optimal Floating-Point Formats for Ternary Computing (T27)',
    href: 'https://doi.org/10.5281/zenodo.19456875',
    id: '10.5281/zenodo.19456875',
    verified: '2026-08-09',
    status: 'live',
    note:
      'v0.1.0, 2026-04-07, 22 views / 9 downloads. The GitHub profile README calls this "t27 language spec" — WRONG, it is a GoldenFloat record. Also overlaps arXiv:2606.05017 with a different version number and no visible cross-link.',
    noteRu: "v0.1.0, 7 апреля 2026 года, 22 просмотра и 9 скачиваний. В профиле GitHub это названо «спецификацией языка t27» — неверно: запись относится к GoldenFloat. Она также пересекается с arXiv:2606.05017, но имеет другой номер версии и не содержит видимой перекрёстной ссылки.",
  },
  {
    kind: 'dataset',
    title: 'Trinity S³AI Framework — Complete Research Collection v5.0',
    href: 'https://doi.org/10.5281/zenodo.19227879',
    id: '10.5281/zenodo.19227879',
    verified: '2026-08-09',
    status: 'live',
    note:
      '2026-03-26, 54 views / 12 downloads. The GitHub profile README calls this "Trinity v9.0" — WRONG, the record says v5.0.',
    noteRu: "26 марта 2026 года, 54 просмотра и 12 скачиваний. В профиле GitHub это названо «Trinity v9.0» — неверно: в записи указана версия v5.0.",
  },
  {
    kind: 'dataset',
    title: 'gHashTag/trinity: Trinity v2.0.2 — FPGA Autoregressive Ternary LLM',
    href: 'https://doi.org/10.5281/zenodo.18947017',
    id: '10.5281/zenodo.18947017',
    verified: '2026-08-09',
    status: 'live',
    note:
      '2026-03-11, 141 views / 12 downloads. Description matches the README. ✓ Concept DOI 10.5281/zenodo.18939351.',
    noteRu: "11 марта 2026 года, 141 просмотр и 12 скачиваний. Описание совпадает с README. Концептуальный DOI: 10.5281/zenodo.18939351.",
  },

  // The B-series: seven records the GitHub profile never mentioned. Found via the
  // related_identifiers of the v5.0 collection, not from any list we maintained.
  {
    kind: 'dataset',
    title: 'Trinity B001: Ternary Neural Networks — Complete Scientific Framework',
    href: 'https://doi.org/10.5281/zenodo.19227865',
    id: '10.5281/zenodo.19227865',
    verified: '2026-08-09',
    status: 'live',
    note: 'v5.0, 2026-03-26, 69 views.',
    noteRu: "v5.0, 26 марта 2026 года, 69 просмотров.",
  },
  {
    kind: 'dataset',
    title: 'Trinity B002: Zero-DSP FPGA Architecture for Ternary Inference',
    href: 'https://doi.org/10.5281/zenodo.19227867',
    id: '10.5281/zenodo.19227867',
    verified: '2026-08-09',
    status: 'live',
    note:
      'v5.0, 2026-03-26, 54 views. Overlaps the unpublished FPL paper "Zero-DSP Ternary Transformer Inference on a $30 FPGA" — check for self-overlap before submitting.',
    noteRu: "v5.0, 26 марта 2026 года, 54 просмотра. Есть пересечение с неопубликованной статьёй FPL «Zero-DSP Ternary Transformer Inference on a $30 FPGA» — перед отправкой нужно проверить самопересечение.",
  },
  {
    kind: 'dataset',
    title: 'Trinity B003: TRI-27 ISA — Ternary Instruction Set with Coptic Alphabet',
    href: 'https://doi.org/10.5281/zenodo.19227869',
    id: '10.5281/zenodo.19227869',
    verified: '2026-08-09',
    status: 'live',
    note:
      'v5.0, 2026-03-26, 64 views. This — not 19456875 — is the record closest to "t27 language spec".',
    noteRu: "v5.0, 26 марта 2026 года, 64 просмотра. Именно эта запись, а не 19456875, ближе всего к описанию «спецификация языка t27».",
  },
  {
    kind: 'dataset',
    title: 'Trinity B004: Queen Lotus Cycle — Autonomous Orchestration',
    href: 'https://doi.org/10.5281/zenodo.19227871',
    id: '10.5281/zenodo.19227871',
    verified: '2026-08-09',
    status: 'live',
    note: 'v5.0, 2026-03-26, 54 views.',
    noteRu: "v5.0, 26 марта 2026 года, 54 просмотра.",
  },
  {
    kind: 'dataset',
    title: 'Trinity B005: Tri Language — Linear Types, Effects, Dual Targets',
    href: 'https://doi.org/10.5281/zenodo.19227873',
    id: '10.5281/zenodo.19227873',
    verified: '2026-08-09',
    status: 'live',
    note: 'v5.0, 2026-03-26, 49 views.',
    noteRu: "v5.0, 26 марта 2026 года, 49 просмотров.",
  },
  {
    kind: 'dataset',
    title: 'Trinity B006: Sacred GF16/TF3 — Phi-Based Arithmetic for Ternary Computing',
    href: 'https://doi.org/10.5281/zenodo.19227875',
    id: '10.5281/zenodo.19227875',
    verified: '2026-08-09',
    status: 'live',
    note:
      'v5.0, 2026-03-26, 54 views. Overlaps the unpublished arXiv draft "Sacred GF16/TF3-9 Arithmetic on Artix-7".',
    noteRu: "v5.0, 26 марта 2026 года, 54 просмотра. Есть пересечение с неопубликованным черновиком arXiv «Sacred GF16/TF3-9 Arithmetic on Artix-7».",
  },
  {
    kind: 'dataset',
    title: 'Trinity B007: VSA Operations for Ternary Computing v5.0',
    href: 'https://doi.org/10.5281/zenodo.19227877',
    id: '10.5281/zenodo.19227877',
    verified: '2026-08-09',
    status: 'live',
    note:
      'v5.0, 2026-03-26, **228 views — the most-viewed record in the corpus**, and it appears on no profile, README or CV.',
    noteRu: "v5.0, 26 марта 2026 года, 228 просмотров — наибольшее число просмотров среди записей корпуса; при этом упоминания нет ни в профиле, ни в README, ни в резюме.",
  },
]

export const upstream: Resource[] = [
  {
    kind: 'repo',
    title: 'trabucayre/openFPGALoader #663 — QMTech XC7A100T (FGG676) board support',
    href: 'https://github.com/trabucayre/openFPGALoader/pull/663',
    verified: '2026-08-10',
    status: 'live',
    note: 'MERGED. The maintainer took the board integration, declined the CI workflow with a reason, and asked for the bitstream work to be split out — which became #682.',
    noteRu: "СМЕРЖЕН. Сопровождающий принял интеграцию платы, обоснованно отклонил workflow CI и попросил вынести работу с битстримом отдельно — так появился PR #682.",
  },
  {
    kind: 'repo',
    title: 'trabucayre/openFPGALoader #682 — package-specific FGG676 spiOverJtag bitstream',
    href: 'https://github.com/trabucayre/openFPGALoader/pull/682',
    verified: '2026-08-10',
    status: 'live',
    note: 'MERGED — "Applied. Thanks!" The split the maintainer asked for in #663.',
    noteRu: "СМЕРЖЕН — «Применено. Спасибо!». Это отдельная работа с битстримом, которую сопровождающий попросил вынести из PR #663.",
  },
  {
    kind: 'repo',
    title: 'openXC7/nextpnr-xilinx #109 — set_multicycle_path -setup (XDC parser + timing)',
    href: 'https://github.com/openXC7/nextpnr-xilinx/pull/109',
    verified: '2026-08-10',
    status: 'live',
    note: 'MERGED 2026-08-09 — "LGTM, thanks for the contribution!"',
    noteRu: "СМЕРЖЕН 9 августа 2026 года — «LGTM, спасибо за вклад!».",
  },
  {
    kind: 'repo',
    title: '#110 — raise clock-buffer preplace BFS cap so SRCC clock pins can route',
    href: 'https://github.com/openXC7/nextpnr-xilinx/pull/110',
    verified: '2026-08-10',
    status: 'live',
    note: 'MERGED 2026-08-09 — "LGTM, thanks for the contribution!"',
    noteRu: "СМЕРЖЕН 9 августа 2026 года — «LGTM, спасибо за вклад!».",
  },
  {
    kind: 'repo',
    title: '#111 — preplace fabric-driven global buffers instead of aborting placement',
    href: 'https://github.com/openXC7/nextpnr-xilinx/pull/111',
    verified: '2026-08-10',
    status: 'live',
    note: 'MERGED 2026-08-10 — "I merged this. I am actually thinking about making a regression test suite for nextpnr-xilinx and your example above would be a nice start."',
    noteRu: "СМЕРЖЕН 10 августа 2026 года — «Я это смержил. Думаю добавить набор регрессионных тестов для nextpnr-xilinx, и ваш пример хорошо для этого подходит».",
  },
  {
    kind: 'repo',
    title: "#112 — don't emit a conflicting width bit for the unused port of an SDP BRAM",
    href: 'https://github.com/openXC7/nextpnr-xilinx/pull/112',
    verified: '2026-08-10',
    status: 'live',
    note: 'MERGED 2026-08-10.',
    noteRu: "СМЕРЖЕН 10 августа 2026 года.",
  },
  {
    kind: 'repo',
    title: '#113 — preplace the single-site configuration primitives (STARTUPE2, ICAPE2, ...)',
    href: 'https://github.com/openXC7/nextpnr-xilinx/pull/113',
    verified: '2026-08-10',
    status: 'live',
    note: 'MERGED 2026-08-10.',
    noteRu: "СМЕРЖЕН 10 августа 2026 года.",
  },
  {
    kind: 'repo',
    title: '#115 — initialise all four IFF flops for an IDDR, not just Q1/Q2',
    href: 'https://github.com/openXC7/nextpnr-xilinx/pull/115',
    verified: '2026-08-10',
    status: 'live',
    note: 'MERGED 2026-08-09 — "LGTM, this is merged. Thanks for the contribution!" The underlying IDDR capture issue stays open in the toolchain.',
    noteRu: "СМЕРЖЕН 9 августа 2026 года — «LGTM, это смержено. Спасибо за вклад!». Исходная проблема захвата IDDR в тулчейне всё ещё открыта.",
  },
]

export const channels: Resource[] = [
  {
    kind: 'channel',
    title: 'Habr — @raoffonom',
    href: 'https://habr.com/ru/users/raoffonom/',
    verified: '2026-08-09',
    status: 'live',
    note:
      'Strongest social channel: 12 articles, best one at 7.8K reach / 19 bookmarks / 20 comments. Two further posts were pulled — one flagged as machine-written, one at -8 votes.',
    noteRu: "Канал с наибольшим охватом среди проверенных: 12 статей, максимальный охват одной публикации — 7,8 тыс., 19 добавлений в закладки и 20 комментариев. Ещё две публикации сняты: одну пометили как написанную машиной, другая получила −8 голосов.",
  },
  {
    kind: 'channel',
    title: 'LinkedIn — /in/neurocoder',
    href: 'https://www.linkedin.com/in/neurocoder/',
    verified: '2026-08-09',
    status: 'live',
    note: '612 followers. Last post: 461 impressions, 1 reaction.',
    noteRu: "612 подписчиков. Последняя публикация: 461 показ и 1 реакция.",
  },
  {
    kind: 'channel',
    title: 'X — @t27_dev',
    href: 'https://x.com/t27_dev',
    verified: '2026-08-09',
    status: 'live',
    note:
      '118 followers, 145 posts, joined Apr 2019. Formerly @koshasuperstar — renamed, not a separate account.',
    noteRu: "118 подписчиков, 145 публикаций, аккаунт создан в апреле 2019 года. Ранее использовался хэндл @koshasuperstar — это переименование, а не отдельный аккаунт.",
  },
  {
    kind: 'channel',
    title: 'X — @t27_lang',
    href: 'https://x.com/t27_lang',
    verified: '2026-08-09',
    status: 'unverified',
    note:
      'This is the handle the site footer links. The GitHub README links @t27_dev instead. Pick one.',
    noteRu: "Это хэндл, на который ссылается подвал сайта. В README GitHub указан @t27_dev вместо него. Нужно выбрать один вариант.",
  },
  {
    kind: 'channel',
    title: 'Telegram — t.me/t27_lang (project channel)',
    href: 'https://t.me/t27_lang',
    verified: '2026-08-09',
    status: 'unverified',
    note: 'Subscriber count not measured.',
    noteRu: "Число подписчиков не измерялось.",
  },
  {
    kind: 'channel',
    title: 'Telegram — t.me/t27_dev (personal account, NOT a channel)',
    href: 'https://t.me/t27_dev',
    verified: '2026-08-09',
    status: 'live',
    note:
      't.me/s/t27_dev returns only a bio. The GitHub README Telegram badge points here, so it leads to a DM box rather than a broadcast channel.',
    noteRu: "t.me/s/t27_dev возвращает только биографию. Значок Telegram в README GitHub ведёт сюда, то есть открывает личные сообщения, а не канал вещания.",
  },
  {
    kind: 'channel',
    title: 'Reddit — r/t27ai',
    href: 'https://www.reddit.com/r/t27ai/',
    verified: '2026-08-09',
    status: 'live',
    note:
      'PUBLIC as of 2026-08-09 (verified: subreddit_type "public", 1 subscriber). Was restricted from creation on 27 Mar 2026 until a review request was approved. Two posts, both by the owner, silent four months — it now needs content, not permissions.',
    noteRu: "ПУБЛИЧЕН на 9 августа 2026 года (проверено: тип сообщества «public», 1 подписчик). До одобрения запроса на проверку создание было ограничено с 27 марта 2026 года. Две публикации, обе от владельца, четыре месяца без активности — теперь нужны материалы, а не разрешения.",
  },
  {
    kind: 'channel',
    title: 'Telegram — t.me/t27_lang (project channel)',
    href: 'https://t.me/t27_lang',
    verified: '2026-08-09',
    status: 'live',
    note:
      '18 subscribers. Best post 166 views — the Russian Knuth/Setun piece; PhD monograph post 91. Same pattern as Habr: culturally-anchored Russian framing outperforms English announcements.',
    noteRu: "18 подписчиков. Пост с наибольшим охватом набрал 166 просмотров — это русскоязычный текст о Кнуте и Сетуни; пост о докторской монографии — 91 просмотр. Как и на Habr, культурно привязанная русская подача работает лучше англоязычных анонсов.",
  },
  {
    kind: 'channel',
    title: 'X — @trinity_cli',
    href: 'https://twitter.com/trinity_cli',
    verified: '2026-09-05',
    status: 'broken',
    note:
      'Opened 2026-09-05: twitter.com/trinity_cli and x.com/trinity_cli both return 404 (controls x.com/t27_dev and x.com/t27_lang return 200). A third X handle, found only in the r/t27ai sidebar. X is now split three ways: @t27_dev (118 followers, the real history), @t27_lang (site footer), @trinity_cli (subreddit).',
    noteRu: "Проверено 5 сентября 2026 года: twitter.com/trinity_cli и x.com/trinity_cli отвечают 404 (контрольные x.com/t27_dev и x.com/t27_lang — 200). Третий хэндл X, найденный только в боковой панели r/t27ai. Сейчас присутствуют три адреса: @t27_dev (118 подписчиков, основная история), @t27_lang (подвал сайта) и @trinity_cli (сабреддит).",
  },
  {
    kind: 'channel',
    title: 'Zenodo community — trinity',
    href: 'https://zenodo.org/communities/trinity',
    verified: '2026-08-09',
    status: 'unverified',
    note: 'Linked only from the r/t27ai sidebar; absent from the profile, the site and the CV.',
    noteRu: "Ссылка есть только в боковой панели r/t27ai; в профиле, на сайте и в резюме её нет.",
  },
  {
    kind: 'channel',
    title: 'Reddit — u/Open-Elderberry699',
    href: 'https://www.reddit.com/user/Open-Elderberry699/',
    verified: '2026-08-09',
    status: 'live',
    note:
      'Auto-generated username carrying real FPGA posts in r/FPGA and r/Zig. Reputation cannot accrue to a name nobody recognises.',
    noteRu: "Автоматически созданное имя пользователя с реальными публикациями о FPGA в r/FPGA и r/Zig. Репутация не накапливается вокруг имени, которое никто не узнаёт.",
  },
  {
    kind: 'channel',
    title: 'dev.to — @serverlesskiy',
    href: 'https://dev.to/serverlesskiy',
    verified: '2026-08-09',
    status: 'broken',
    note:
      '/ghashtag redirects here. The profile still links twitter.com/koshasuperstar — a dead handle.',
    noteRu: "/ghashtag перенаправляет сюда. В профиле по-прежнему указана ссылка twitter.com/koshasuperstar — это неработающий хэндл.",
  },
  {
    kind: 'channel',
    title: 'Medium — @raoffonom',
    href: 'https://medium.com/@raoffonom',
    verified: '2026-08-09',
    status: 'live',
    note: '56 followers, 7 posts, dormant since Nov 2021.',
    noteRu: "56 подписчиков, 7 публикаций, без обновлений с ноября 2021 года.",
  },
  {
    kind: 'channel',
    title: 'GitHub — gHashTag',
    href: 'https://github.com/gHashTag',
    verified: '2026-08-09',
    status: 'live',
    note:
      '89 followers, 217 repositories total / 187 public. The profile README still says 210 total / 186 public / 86 followers.',
    noteRu: "89 подписчиков, всего 217 репозиториев и 187 публичных. В README профиля по-прежнему указаны старые значения: 210 всего, 186 публичных и 86 подписчиков.",
  },
]

export const identities: Resource[] = [
  {
    kind: 'identity',
    title: 'ORCID 0009-0008-4294-6159',
    href: 'https://orcid.org/0009-0008-4294-6159',
    id: '0009-0008-4294-6159',
    verified: '2026-07-28',
    status: 'unverified',
  },
  {
    kind: 'identity',
    title: 'arXiv author identifier',
    href: 'https://arxiv.org/a/0009-0008-4294-6159',
    id: 'arXiv author id 0009-0008-4294-6159',
    verified: '2026-09-05',
    status: 'live',
    note:
      'The ORCID-keyed author page lists exactly the two arXiv papers (2606.05017, 2606.09686). The older /a/vasilev_d_1 address returns "Not Found" (303 to /a/vasilev_d_1.html, then 404) and must not be linked.',
    noteRu: "Страница автора по ORCID перечисляет ровно две статьи arXiv (2606.05017, 2606.09686). Старый адрес /a/vasilev_d_1 возвращает «Not Found» (303 на /a/vasilev_d_1.html, затем 404), ссылаться на него нельзя.",
  },
  {
    kind: 'identity',
    title: 'Contact — admin@t27.ai',
    href: 'mailto:admin@t27.ai',
    verified: '2026-08-09',
    status: 'live',
  },
]

/**
 * Claims this programme has withdrawn.
 *
 * Kept as a first-class list, not folded into `discrepancies`. A discrepancy is a row a
 * reader should treat with suspicion; a retraction is one the authors have already settled
 * against themselves. Conflating them would understate both.
 *
 * Source: gHashTag/claim-audit-lab, CASE-00 — the maintainers' self-audit, which is the
 * first case in a lab whose other cases examine other people's phi claims.
 */
export const retractions: Resource[] = [
  {
    kind: 'paper',
    title: 'delta_CP = 3/phi^2 as a phi-structured value of the CP-violating phase in neutrino oscillation',
    href: 'https://github.com/gHashTag/claim-audit-lab/blob/main/cases/CASE-00-self-audit.md',
    id: 'CASE-00 [Retracted]',
    verified: '2026-08-10',
    status: 'live',
    note:
      'WITHDRAWN by the authors. An independent arithmetic check showed the algebraic identity does not deliver the claimed numerical match at the precision required. Marked never to be restated. Listed here because a programme that retracts its own physics claim on arithmetic should say so where it can be found, not only in a repository.',
    noteRu: "ОТОЗВАНО авторами. Независимая арифметическая проверка показала, что алгебраическое тождество не даёт заявленного численного совпадения с требуемой точностью. Утверждение помечено как не подлежащее повторной публикации. Запись оставлена здесь, потому что программа, отзывающая собственное физическое утверждение после арифметической проверки, должна указывать это там, где утверждение можно найти, а не только в репозитории.",
  },
]

export const allResources = (): Resource[] => [
  ...papers,
  ...retractions,
  ...datasets,
  ...upstream,
  ...channels,
  ...identities,
]

/** Rows a reader should treat with suspicion. Rendered first, on purpose. */
export const discrepancies = () =>
  allResources().filter((r) => r.status === 'broken' || /WRONG|dead|does not|Pick one/i.test(r.note ?? ''))
