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
  },
  {
    kind: 'paper',
    title:
      'An 83-Format Numeric Catalog with Bit-Exact Conformance Vectors: A Vendor-Neutral Reference for FP8, BF16, MXFP4, and Microscaling Formats',
    href: 'https://arxiv.org/abs/2606.09686',
    id: 'arXiv:2606.09686v2',
    verified: '2026-08-09',
    status: 'live',
    note: '83 formats, not 84. The 84-format title is v1 only and is historical.',
  },
  {
    kind: 'paper',
    title: 'Cognitive framework',
    href: 'https://arxiv.org/abs/2605.28405',
    id: 'arXiv:2605.28405v1',
    verified: '2026-07-28',
    status: 'unverified',
    note: 'v1, 27 May 2026, 32 pp, cs.AI. Not re-opened in the 2026-08-09 pass.',
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
  },
  {
    kind: 'dataset',
    title: 'Trinity B004: Queen Lotus Cycle — Autonomous Orchestration',
    href: 'https://doi.org/10.5281/zenodo.19227871',
    id: '10.5281/zenodo.19227871',
    verified: '2026-08-09',
    status: 'live',
    note: 'v5.0, 2026-03-26, 54 views.',
  },
  {
    kind: 'dataset',
    title: 'Trinity B005: Tri Language — Linear Types, Effects, Dual Targets',
    href: 'https://doi.org/10.5281/zenodo.19227873',
    id: '10.5281/zenodo.19227873',
    verified: '2026-08-09',
    status: 'live',
    note: 'v5.0, 2026-03-26, 49 views.',
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
  },
  {
    kind: 'repo',
    title: 'trabucayre/openFPGALoader #682 — package-specific FGG676 spiOverJtag bitstream',
    href: 'https://github.com/trabucayre/openFPGALoader/pull/682',
    verified: '2026-08-10',
    status: 'live',
    note: 'MERGED — "Applied. Thanks!" The split the maintainer asked for in #663.',
  },
  {
    kind: 'repo',
    title: 'openXC7/nextpnr-xilinx #109 — set_multicycle_path -setup (XDC parser + timing)',
    href: 'https://github.com/openXC7/nextpnr-xilinx/pull/109',
    verified: '2026-08-10',
    status: 'live',
    note: 'MERGED 2026-08-09 — "LGTM, thanks for the contribution!"',
  },
  {
    kind: 'repo',
    title: '#110 — raise clock-buffer preplace BFS cap so SRCC clock pins can route',
    href: 'https://github.com/openXC7/nextpnr-xilinx/pull/110',
    verified: '2026-08-10',
    status: 'live',
    note: 'MERGED 2026-08-09 — "LGTM, thanks for the contribution!"',
  },
  {
    kind: 'repo',
    title: '#111 — preplace fabric-driven global buffers instead of aborting placement',
    href: 'https://github.com/openXC7/nextpnr-xilinx/pull/111',
    verified: '2026-08-10',
    status: 'live',
    note: 'MERGED 2026-08-10 — "I merged this. I am actually thinking about making a regression test suite for nextpnr-xilinx and your example above would be a nice start."',
  },
  {
    kind: 'repo',
    title: "#112 — don't emit a conflicting width bit for the unused port of an SDP BRAM",
    href: 'https://github.com/openXC7/nextpnr-xilinx/pull/112',
    verified: '2026-08-10',
    status: 'live',
    note: 'MERGED 2026-08-10.',
  },
  {
    kind: 'repo',
    title: '#113 — preplace the single-site configuration primitives (STARTUPE2, ICAPE2, ...)',
    href: 'https://github.com/openXC7/nextpnr-xilinx/pull/113',
    verified: '2026-08-10',
    status: 'live',
    note: 'MERGED 2026-08-10.',
  },
  {
    kind: 'repo',
    title: '#115 — initialise all four IFF flops for an IDDR, not just Q1/Q2',
    href: 'https://github.com/openXC7/nextpnr-xilinx/pull/115',
    verified: '2026-08-10',
    status: 'live',
    note: 'MERGED 2026-08-09 — "LGTM, this is merged. Thanks for the contribution!" The underlying IDDR capture issue stays open in the toolchain.',
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
  },
  {
    kind: 'channel',
    title: 'LinkedIn — /in/neurocoder',
    href: 'https://www.linkedin.com/in/neurocoder/',
    verified: '2026-08-09',
    status: 'live',
    note: '612 followers. Last post: 461 impressions, 1 reaction.',
  },
  {
    kind: 'channel',
    title: 'X — @t27_dev',
    href: 'https://x.com/t27_dev',
    verified: '2026-08-09',
    status: 'live',
    note:
      '118 followers, 145 posts, joined Apr 2019. Formerly @koshasuperstar — renamed, not a separate account.',
  },
  {
    kind: 'channel',
    title: 'X — @t27_lang',
    href: 'https://x.com/t27_lang',
    verified: '2026-08-09',
    status: 'unverified',
    note:
      'This is the handle the site footer links. The GitHub README links @t27_dev instead. Pick one.',
  },
  {
    kind: 'channel',
    title: 'Telegram — t.me/t27_lang (project channel)',
    href: 'https://t.me/t27_lang',
    verified: '2026-08-09',
    status: 'unverified',
    note: 'Subscriber count not measured.',
  },
  {
    kind: 'channel',
    title: 'Telegram — t.me/t27_dev (personal account, NOT a channel)',
    href: 'https://t.me/t27_dev',
    verified: '2026-08-09',
    status: 'live',
    note:
      't.me/s/t27_dev returns only a bio. The GitHub README Telegram badge points here, so it leads to a DM box rather than a broadcast channel.',
  },
  {
    kind: 'channel',
    title: 'Reddit — r/t27ai',
    href: 'https://www.reddit.com/r/t27ai/',
    verified: '2026-08-09',
    status: 'live',
    note:
      'PUBLIC as of 2026-08-09 (verified: subreddit_type "public", 1 subscriber). Was restricted from creation on 27 Mar 2026 until a review request was approved. Two posts, both by the owner, silent four months — it now needs content, not permissions.',
  },
  {
    kind: 'channel',
    title: 'Telegram — t.me/t27_lang (project channel)',
    href: 'https://t.me/t27_lang',
    verified: '2026-08-09',
    status: 'live',
    note:
      '18 subscribers. Best post 166 views — the Russian Knuth/Setun piece; PhD monograph post 91. Same pattern as Habr: culturally-anchored Russian framing outperforms English announcements.',
  },
  {
    kind: 'channel',
    title: 'X — @trinity_cli',
    href: 'https://twitter.com/trinity_cli',
    verified: '2026-08-09',
    status: 'unverified',
    note:
      'A third X handle, found only in the r/t27ai sidebar. X is now split three ways: @t27_dev (118 followers, the real history), @t27_lang (site footer), @trinity_cli (subreddit).',
  },
  {
    kind: 'channel',
    title: 'Zenodo community — trinity',
    href: 'https://zenodo.org/communities/trinity',
    verified: '2026-08-09',
    status: 'unverified',
    note: 'Linked only from the r/t27ai sidebar; absent from the profile, the site and the CV.',
  },
  {
    kind: 'channel',
    title: 'Reddit — u/Open-Elderberry699',
    href: 'https://www.reddit.com/user/Open-Elderberry699/',
    verified: '2026-08-09',
    status: 'live',
    note:
      'Auto-generated username carrying real FPGA posts in r/FPGA and r/Zig. Reputation cannot accrue to a name nobody recognises.',
  },
  {
    kind: 'channel',
    title: 'dev.to — @serverlesskiy',
    href: 'https://dev.to/serverlesskiy',
    verified: '2026-08-09',
    status: 'broken',
    note:
      '/ghashtag redirects here. The profile still links twitter.com/koshasuperstar — a dead handle.',
  },
  {
    kind: 'channel',
    title: 'Medium — @raoffonom',
    href: 'https://medium.com/@raoffonom',
    verified: '2026-08-09',
    status: 'live',
    note: '56 followers, 7 posts, dormant since Nov 2021.',
  },
  {
    kind: 'channel',
    title: 'GitHub — gHashTag',
    href: 'https://github.com/gHashTag',
    verified: '2026-08-09',
    status: 'live',
    note:
      '89 followers, 217 repositories total / 187 public. The profile README still says 210 total / 186 public / 86 followers.',
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
    href: 'https://arxiv.org/a/vasilev_d_1',
    verified: '2026-08-09',
    status: 'broken',
    note:
      'Returns "Not Found". The three arXiv papers do not resolve to one author page, so nothing can link to a single publication list.',
  },
  {
    kind: 'identity',
    title: 'Contact — admin@t27.ai',
    href: 'mailto:admin@t27.ai',
    verified: '2026-08-09',
    status: 'live',
  },
]

export const allResources = (): Resource[] => [
  ...papers,
  ...datasets,
  ...upstream,
  ...channels,
  ...identities,
]

/** Rows a reader should treat with suspicion. Rendered first, on purpose. */
export const discrepancies = () =>
  allResources().filter((r) => r.status === 'broken' || /WRONG|dead|does not|Pick one/i.test(r.note ?? ''))
