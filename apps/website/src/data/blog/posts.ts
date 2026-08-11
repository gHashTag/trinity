// Blog posts for t27.ai/#/blog
//
// Articles are published HERE FIRST. Every other channel (Habr, LinkedIn, X,
// r/t27ai) links back to this page — the owned surface is the canonical one.
//
// Honesty rules that apply to every post in this file:
//   - a pull request's state is named exactly: merged ones say merged, open ones say
//     "submitted upstream". Never a blanket claim over a mixed set. Re-check before
//     publishing — states move, and a stale one here is worse than in a draft:
//       gh api "repos/openXC7/nextpnr-xilinx/pulls?state=all&per_page=20" \
//         --jq '.[]|select(.user.login=="gHashTag")|"#\(.number) merged=\(.merged_at != null)"'
//   - a design is not a fabricated chip
//   - unsolved defects stay in the text
//   - no scale claims in titles

export type Block =
  | { kind: 'p'; text: string }
  | { kind: 'h'; text: string }
  | { kind: 'ul'; items: string[] }
  | { kind: 'ol'; items: string[] }
  | { kind: 'quote'; text: string }
  | { kind: 'code'; text: string }
  | { kind: 'table'; head: string[]; rows: string[][] }

export interface Post {
  slug: string
  title: string
  /** One sentence. Shown on the index and used as the meta description. */
  summary: string
  date: string
  readingMinutes: number
  tags: string[]
  /** Verifiable artefacts a reader can open. Every post must have at least one. */
  receipts: { label: string; href: string }[]
  /** What is NOT proven. Rendered prominently. A post without this is marketing. */
  openQuestions: string[]
  body: Block[]
  /** Set false while the text still has gaps; the index will not list it. */
  published: boolean
  /**
   * Russian version of the post, applied wholesale when the reader has chosen ru.
   *
   * All-or-nothing on purpose. A Russian title over an English body is worse than
   * an English title: the reader commits to reading and then finds they cannot.
   * So a post is bilingual only once every field here is filled, and until then
   * it stays English for everyone, which is at least honest about what it is.
   *
   * The honesty rules at the top of this file bind the translation too. A hedge
   * that softens in Russian -- "submitted upstream" becoming "accepted", "inferred"
   * becoming "measured" -- is a false claim in a second language, and harder to
   * catch because fewer readers check it.
   */
  ru?: {
    title: string
    summary: string
    openQuestions: string[]
    body: Block[]
  }
}

const openGigabitEthernet: Post = {
  slug: 'open-gigabit-ethernet-artix7',
  title: 'Gigabit Ethernet on Artix-7 without a vendor toolchain',
  summary:
    'RGMII at gigabit through Yosys, nextpnr-xilinx and Project X-Ray with no vendor tools — the six blockers that had to be patched, the one still open, and what the workaround costs.',
  date: '2026-08-09',
  readingMinutes: 12,
  tags: ['FPGA', 'Open source', 'Ethernet', 'Artix-7', 'openXC7'],
  receipts: [
    { label: 'openXC7/nextpnr-xilinx #109 — set_multicycle_path · MERGED 2026-08-09', href: 'https://github.com/openXC7/nextpnr-xilinx/pull/109' },
    { label: '#110 — clock-buffer preplace BFS cap · MERGED 2026-08-09', href: 'https://github.com/openXC7/nextpnr-xilinx/pull/110' },
    { label: '#111 — fabric-driven global buffers · MERGED 2026-08-10', href: 'https://github.com/openXC7/nextpnr-xilinx/pull/111' },
    { label: '#112 — SDP BRAM unused-port width bit · MERGED 2026-08-10', href: 'https://github.com/openXC7/nextpnr-xilinx/pull/112' },
    { label: '#113 — single-site configuration primitives · MERGED 2026-08-10', href: 'https://github.com/openXC7/nextpnr-xilinx/pull/113' },
    { label: '#115 — IDDR IFF flop initialisation · MERGED 2026-08-09', href: 'https://github.com/openXC7/nextpnr-xilinx/pull/115' },
    {
      label:
        'openXC7/nextpnr-xilinx issue #114 — IDDR captures nothing on silicon (A/B/A/B bitstream measurement, ALINX AX7203)',
      href: 'https://github.com/openXC7/nextpnr-xilinx/issues/114',
    },
    {
      label: 'openXC7/nextpnr-xilinx issue #65 — SAME_EDGE_PIPELINED unsupported (janrinze, Mar 2025)',
      href: 'https://github.com/openXC7/nextpnr-xilinx/issues/65',
    },
    {
      label:
        'Shah, Hung, Wolf, Bazanski, Gisselquist, Milanović — Yosys+nextpnr: an Open Source Framework from Verilog to Bitstream for Commercial FPGAs (FCCM 2019), arXiv:1903.10407',
      href: 'https://arxiv.org/abs/1903.10407',
    },
  ],
  openQuestions: [
    'The link negotiates on 23 of 48 power-ups (48%, 95% interval 34-62%), independent of the RTL across four designs. Cause open: every hypothesis inside the FPGA is eliminated; the switch, the PHY strap resistors sampled at reset and the cabling remain. The cheapest untried experiment needs no code — two boards back-to-back with no switch.',
    'All six patches are OPEN on openXC7/nextpnr-xilinx — submitted upstream, none merged as of 2026-08-09.',
    'Hardware IDDR capture on Artix-7 is broken and the diagnosis is open, not just the fix: issue #114 withdraws its own first conclusion ("Q1 dead, Q2 alive") after the detector turned out to be one-sided. Both outputs are inert in every edge mode tried. The receive path uses fabric DDR capture as a workaround.',
    'Sigma ~= 470 ps was never measured. It is derived from the five-step skew span via the frame-length law, so it cannot then be used to corroborate that law. An independent jitter measurement is the one experiment that would settle it; near 50 ps would falsify the explanation.',
    'Frame-error rate was never measured directly, only inferred from whether the link came up. The three skew data points are right-censored at tap 31 and cannot discriminate between the candidate models.',
  ],
  // Every [FILL IN] is closed as of 2026-08-10, sourced from the primary write-up and
  // openXC7 issue #114. Publishing is the author's call, not the loop's.
  published: true,
  body: [
    { kind: 'h', text: 'The frame, before anything else' },
    {
      kind: 'p',
      text:
        'What works: three ALINX AX7203 boards exchange frames of a custom protocol over gigabit RGMII, with no operating system at either end and no vendor licence anywhere in the flow, which runs natively on a laptop. Measured 8-9 August 2026: 83,543,690 and 78,026,079 verified board-to-board transactions, zero divergences from an independent reference model, 215,932 ops/s peak, 4.71 and 4.74 microsecond hardware round trips. Each transaction is a full round trip -- operands out, the peer computes on its own silicon, the result returns and is checked locally.',
    },
    {
      kind: 'p',
      text:
        'What does not: a node negotiates its link on roughly half of power-ups — 23 of 48, a 95% interval of about 34-62%, and independent of what the RTL does across four structurally different designs. Every hypothesis inside the FPGA has been eliminated by measurement. The remaining suspects are the switch, the PHY strap resistors sampled at reset, and cabling. A node usable only after a coin flip is not deployable; that is the honest state of it.',
    },
    {
      kind: 'p',
      text:
        'What is not mine: the flow itself. Yosys is YosysHQ. nextpnr is YosysHQ and David Shah — the framework paper is Shah, Hung, Wolf, Bazanski, Gisselquist and Milanović at FCCM 2019 (arXiv:1903.10407), and it covers Lattice iCE40 and ECP5; Xilinx 7-series came later through nextpnr-xilinx. Project X-Ray and the xc7 bitstream database are SymbiFlow/F4PGA. The Xilinx port and Artix-7 support are openXC7, funded by NLnet. I did not build this stack. I found six places where it broke on my design and sent six patches.',
    },

    { kind: 'h', text: 'Why RGMII and not SerDes' },
    {
      kind: 'p',
      text:
        'openXC7 has funded work on gigabit transceivers, but that targets GTP/GTX — high-speed serial lanes, aimed at 10G. Different problem. RGMII is source-synchronous DDR over ordinary user I/O on general-purpose registers. Cheaper, closer to a typical dev board with a gigabit PHY, and therefore it stresses primitives rather than transceivers: ODDR/IDDR, clock buffers, clock management.',
    },
    {
      kind: 'p',
      text:
        'Board: ALINX AX7203, part xc7a200tfbg484-2. The 125 MHz RGMII receive clock arrives on an SRCC pin (B17) and reaches a BUFG. Toolchain: nextpnr-xilinx at stable-backports (f8e7643) plus the open patches below, Yosys 0.63, prjxray via the regymm/openxc7 image, on a macOS arm64 host.',
    },

    { kind: 'h', text: 'Blocker 1 — the router gave up before trying half the options' },
    {
      kind: 'p',
      text:
        'Path search from an SRCC pin to a clock buffer stopped at 50,000 iterations. The chip database holds more than 75,000 valid paths. The cap was set below the size of the search space, so "unroutable" actually meant "unfinished". The fix is one constant.',
    },
    {
      kind: 'quote',
      text:
        'The path existed in the chip database the whole time: 75,492 wires. The search gave up at 50,000. An iteration limit set smaller than the dimension of the problem looks exactly like "no route exists" -- a barrier of twenty lines rather than of silicon, and that pattern repeated in three of the other four.',
    },

    { kind: 'h', text: 'Blockers 2-5 — four ways a build dies quietly' },
    {
      kind: 'ul',
      items: [
        'A global clock buffer driven from the fabric aborted placement instead of being pre-placed (#111).',
        'set_multicycle_path was parsed and silently dropped — no error, no effect. The worst kind of failure: the constraint looks applied (#109).',
        'A simple-dual-port BRAM emitted conflicting width bits for the port I was not using, and the bitstream was never produced at all (#112).',
        'STARTUPE2, ICAPE2 and relatives exist once per die but had no pre-placement (#113).',
      ],
    },

    { kind: 'h', text: 'Blocker 6 — the one that is still open' },
    {
      kind: 'p',
      text:
        'The hardware IDDR block does not capture at all. Place-and-route succeeds, timing is met, the FASM is well-formed and the bitstream configures — the data simply never appears. Reported upstream as issue #114 with an A/B/A/B bitstream flip on one board: a raw-pin build reads in-band status 0xD (1000 Mb/s, full duplex) and counts frames, while the IDDR build sees none. #115 initialises all four IFF flops rather than only Q1/Q2, which closes part of the configuration problem but not this. The receive path therefore uses fabric DDR capture instead.',
    },
    {
      kind: 'p',
      text:
        'The diagnosis itself is still open. A pre-existing report, issue #65 from janrinze in March 2025, records that SAME_EDGE_PIPELINED is rejected outright — prjxray only encodes SAME and OPPOSITE for IFF.DDR_CLK_EDGE — so the input DDR path has been thin here for a while.',
    },

    { kind: 'h', text: 'The instrument was wrong before the conclusion was' },
    {
      kind: 'p',
      text:
        'The first version of this report said "Q1 is dead, Q2 works". That was wrong, and the reason is worth more than the finding.',
    },
    {
      kind: 'p',
      text:
        'Liveness was detected with a sticky OR: seen <= seen | q. That cannot distinguish a toggling output from one stuck at 1 — both end up 0xF. Adding the complementary sticky zero, zero <= zero | ~q, changes the picture entirely: an output is only really capturing if it has been observed both high and low.',
    },
    {
      kind: 'table',
      head: ['Emitted IFF.DDR_CLK_EDGE', 'Q1', 'Q2'],
      rows: [
        ['SAME_EDGE', 'ever-1 0x0, ever-0 0xF -> stuck LOW', 'ever-1 0xF, ever-0 0x0 -> stuck HIGH'],
        ['neither bit emitted', 'stuck HIGH', 'stuck HIGH'],
        ['OPPOSITE_EDGE', 'never high', 'never high'],
      ],
    },
    {
      kind: 'p',
      text:
        'Byte assembly confirms it: sampling early in a frame, where the Ethernet preamble 0x55 must appear, yields F0 under SAME_EDGE and FF with no edge bits — constant levels, never 0x55. So the corrected finding is simpler and worse than the first one: both outputs are inert in every edge mode tried, while the pin demonstrably carries gigabit traffic.',
    },
    {
      kind: 'quote',
      text:
        'A one-sided detector cannot tell alive from stuck. If an instrument can only ever report one of its two possible answers, it is not measuring — and it will agree with you every time.',
    },

    { kind: 'h', text: 'What the workaround costs: jitter, and a dependence on frame size' },
    {
      kind: 'p',
      text:
        'Moving capture into the fabric is what exposed an effect invisible with a hardware IDDR: link stability depends on frame size. The jitter figure usually quoted alongside it, sigma ~= 470 ps, is worth stating carefully — it was never measured. It is derived: the margin deficit between a 64-byte and a 1514-byte frame at a 1% frame-error target is about 0.64 sigma, the observed span is five 0.06 ns steps or roughly 300 ps, and equating the two gives sigma ~= 470 ps ~= 0.12 UI. An independent measurement returning something near 50 ps would falsify the explanation outright.',
    },
    {
      kind: 'table',
      head: ['Frame', 'Size', 'Minimum working skew step'],
      rows: [
        ['ARP', 'short', '26'],
        ['ICMP', '98 bytes', '30'],
        ['Full MTU', '1514 bytes', '31 (the maximum)'],
      ],
    },
    {
      kind: 'p',
      text:
        'Jitter accumulates along the frame, so the required timing margin grows monotonically with frame length in bits. A full MTU frame only comes up at the last available step — the margin is exhausted, which is one more reason power-on is unreliable.',
    },
    {
      kind: 'quote',
      text:
        'Calibrate skew to the longest frame you will ever send. A link tuned on ARP will drop its first full frame, and it will look like a flaky network rather than a calibration error.',
    },

    { kind: 'h', text: 'The margin law — and why "jitter accumulates" is the wrong mechanism' },
    {
      kind: 'p',
      text:
        'The rule above is right. The explanation I first gave for it was not, and the numbers say so clearly enough that it is worth writing down properly.',
    },
    {
      kind: 'p',
      text:
        'Setup. RGMII at 1000BASE-T runs a 125 MHz clock, double data rate, four bits per edge — one unit interval UI = 4 ns, and a frame of B bytes is captured in N = 2B sampling edges. Let each edge carry a phase error X_i, i.i.d., symmetric, with standard deviation sigma. The frame is received correctly exactly when every edge lands inside the margin: |X_i| < m for all i.',
    },
    {
      kind: 'quote',
      text:
        'Theorem 1 (frame-length margin law). P(frame OK) = (1 - 2(1 - F(m)))^N. For a target frame-error rate eps, the required margin is m(N) = F^-1(1 - eps/(2N)); for Gaussian error, m(N) = sigma * Phi^-1(1 - eps/(2N)), which is asymptotically sigma * sqrt(2 ln(2N/eps)).',
    },
    {
      kind: 'p',
      text:
        'So the margin does grow monotonically with frame length — but as sqrt(log N), not as sqrt(N). This is an extreme-value effect over N independent draws, not accumulation. Nothing integrates: RGMII forwards the clock alongside the data, so each edge is sampled afresh and phase error has no memory from one edge to the next.',
    },
    {
      kind: 'quote',
      text:
        'Corollary 1 (the random-walk model is refuted). If the receive clock were independent, phase error would integrate as sigma_N = sigma * sqrt(N). At sigma = 470 ps and MTU (N = 3028), that is 25.9 ns against a 2.0 ns half-eye — over by a factor of 13. The link demonstrably works, so jitter here does not accumulate.',
    },
    {
      kind: 'quote',
      text:
        'Corollary 2 (feasibility bound). A link is feasible for N-edge frames only if sigma < (UI/2) / Phi^-1(1 - eps/(2N)). At UI = 4 ns and MTU that ceiling is 430 ps for a 1% frame-error rate and 318 ps for 1e-6.',
    },
    {
      kind: 'h',
      text: 'Reading 470 ps as a per-edge sigma appears to violate that bound — and that reading was wrong',
    },
    {
      kind: 'p',
      text:
        'Taken as an i.i.d. per-edge RMS, sigma = 470 ps exceeds the MTU ceiling by 9% at a 1% frame-error rate and by 48% at 1e-6, and centring perfectly (m = UI/2 = 2 ns) gives m/sigma = 4.26, so P(edge error) = 2.1e-5. Propagated over a frame that predicts:',
    },
    {
      kind: 'table',
      head: ['Frame', 'Edges N', 'Predicted frame-error rate at ideal centring'],
      rows: [
        ['ARP 64 B', '128', '0.27%'],
        ['ICMP 98 B', '196', '0.41%'],
        ['512 B', '1024', '2.11%'],
        ['1024 B', '2048', '4.19%'],
        ['MTU 1514 B', '3028', '6.13%'],
      ],
    },
    {
      kind: 'p',
      text:
        'A 6% loss rate on full frames would be survivable — TCP retransmits and the link still looks up. But it is not what a working gigabit link looks like, and the resolution turns out to be simpler than any of that.',
    },
    { kind: 'h', text: 'Theorem 2 — the dual-Dirac split, and the contradiction dissolves' },
    {
      kind: 'p',
      text:
        'The standard decomposition splits jitter into a bounded deterministic part and an unbounded Gaussian random part, and combines them at a target bit-error rate: TJ = DJ_pp + 2n * RJ_rms, with n = 6.4 at 1e-10, 7.0 at 1e-12, 7.6 at 1e-14. A scope quotes total jitter. I had read 470 ps as a per-edge RMS sigma. Those are not the same number.',
    },
    {
      kind: 'table',
      head: ['Target BER', 'n', 'RJ_rms if DJ_pp = 0', 'RJ_rms if DJ_pp = 300 ps'],
      rows: [
        ['1e-10', '6.4', '36.7 ps', '13.3 ps'],
        ['1e-12', '7.0', '33.6 ps', '12.1 ps'],
        ['1e-14', '7.6', '30.9 ps', '11.2 ps'],
      ],
    },
    {
      kind: 'p',
      text:
        'Eye opening = 4000 - 470 = 3530 ps, which is 88% of the unit interval. Comfortably feasible. Read as an i.i.d. per-edge RMS, 470 ps implies a random component about 14x larger than the dual-Dirac decomposition allows at 1e-12. The feasibility violation was an artefact of my reading, not a property of the link. Corollary 2 remains true as stated; its premise simply does not hold here.',
    },
    {
      kind: 'quote',
      text:
        'So the first question to ask about any jitter figure is: RMS or peak-to-peak, and at what BER? Everything downstream turns on that one answer.',
    },
    { kind: 'h', text: 'Theorem 3 — bounded deterministic jitter, offered as a hypothesis and not a law' },
    {
      kind: 'p',
      text:
        'If the random component is only ~30 ps RMS it cannot explain frame-length dependence at all. Something bounded and pattern-dependent must: inter-symbol interference and duty-cycle distortion are functions of the bit pattern, not of elapsed time. A short ARP frame may never exercise the worst-case pattern; an MTU frame probably does. With p the per-edge probability of hitting a near-worst pattern, m(N) = s_inf - (s_inf - s0)(1-p)^N, which saturates rather than diverging — and the observed 26, 30, 31 does decelerate.',
    },
    {
      kind: 'p',
      text:
        'That fit is worth nothing as evidence and I want to be explicit about why. Three parameters against three points is exact by construction. Two diagnostics say so: the fitted ceiling lands on exactly 31.00 taps, but the MTU point is censored at 31, so any saturating model is forced there; and the fitted s0 comes out at -73 taps, a negative delay, which is what an over-parameterised fit looks like when nothing constrains it. Theorem 3 is a mechanism hypothesis with a prediction — 128 B should need about tap 30.8, and 256 B and above should already be pinned at 31. It is falsified if 256 B works comfortably at tap 28.',
    },
    { kind: 'h', text: 'The experiment to run first: vary content, not length' },
    {
      kind: 'p',
      text:
        'A length sweep is confounded by the censored tap range. Payload content is not. Hold the frame at 1514 bytes and vary only the payload — all-zeros, all-ones, PRBS-7, PRBS-31, and a deliberate worst-case ISI pattern (a long run followed by an isolated transition) — 1e5 frames each at a fixed tap.',
    },
    {
      kind: 'ul',
      items: [
        'Frame-error rate depends strongly on content: ISI dominates, and the fix is equalisation or better capture rather than more skew range.',
        'Frame-error rate is independent of content: the mechanism is random jitter after all, and the 470 ps figure needs re-measuring as an RMS.',
        'It depends on both: decompose properly with a dual-Dirac scope measurement.',
      ],
    },
    {
      kind: 'p',
      text:
        'This needs no wider tap range and no new hardware, which is what makes it the first test rather than the third.',
    },
    {
      kind: 'p',
      text:
        'The three measured points cannot settle it. Fitting step against ln N gives consecutive slopes of 9.39 and 0.37 — a factor of 26 apart; against sqrt(N) it is 1.49 and 0.02, a factor of 61. Neither functional form fits, and the reason is visible in the data: the MTU point sits at tap 31, the maximum of the range, so it is right-censored. Its true required skew may be larger than the hardware can express.',
    },
    {
      kind: 'h', text: 'The experiment that would settle it',
    },
    {
      kind: 'p',
      text:
        'Sweep the payload at 64, 128, 256, 512, 1024 and 1514 bytes at the best tap, 1e5 frames each, and measure frame-error rate directly instead of inferring it from whether the link comes up.',
    },
    {
      kind: 'ul',
      items: [
        'FER rising roughly linearly in N, from ~0.3% to ~6% — the i.i.d. model holds and sigma is real.',
        'FER roughly flat in N — the errors are correlated or systematic, and 470 ps is not per-edge random jitter.',
        'FER exploding faster than linearly — something does integrate, and the forwarded clock is not doing its job.',
      ],
    },
    {
      kind: 'p',
      text:
        'A widened tap range would also uncensor the MTU point. Until then the practical rule stands on its own evidence — calibrate to the longest frame — while the mechanism behind it stays open.',
    },

    { kind: 'h', text: 'Reproduction' },
    {
      kind: 'code',
      text: [
        '# synthesis',
        "yosys -p 'synth_xilinx -flatten -nowidelut -family xc7 -json <top>.json' <sources>.v",
        '',
        '# place and route',
        'nextpnr-xilinx --chipdb <part>.bin --xdc <constraints>.xdc \\',
        '               --json <top>.json --write <top>_routed.json --fasm <top>.fasm',
        '',
        '# bitstream',
        'python3 fasm2frames.py --part <part> --db-root <prjxray-db> <top>.fasm > <top>.frames',
        'xc7frames2bit --part_file <part>.yaml --frm_file <top>.frames --output_file <top>.bit',
        '',
        '# flash',
        'openFPGALoader -b <board> <top>.bit',
      ].join('\n'),
    },
    {
      kind: 'p',
      text:
        'The transmit skew is a PHY register written over MDIO, in steps of 0.06 ns; the 26-to-31 span is five steps, about 300 ps. Three traps in this flow are worth knowing: synth_xilinx takes -family xc7, not -arch; prjxray fasm2frames must run in-tree with PYTHONPATH set, because it is usually not pip-installed; and --db-root is the family directory, never the part directory. One more cost real time: a failed fasm2frames still leaves a partial .frames, from which xc7frames2bit will happily build a normal-looking 9.7 MB bitstream that flashes with done=1 and leaves the board silent. Check the exit status, not the file size — and done=1 means configuration completed, not that your design is on the board.',
    },

    { kind: 'h', text: 'What this means' },
    {
      kind: 'p',
      text:
        'A fully open cycle — synthesis, place and route, bitstream, flashing, all local and unlicensed — takes gigabit Ethernet to a working state on Artix-7. Six places where it could not are now described and patched; one blocker remains open and is worked around at the cost of jitter.',
    },
    {
      kind: 'p',
      text:
        'This is not a replacement for Vivado. It is a report that on one class of design the open flow reaches the end, plus the exact list of what has to be fixed to get there.',
    },
  ],
  ru: {
    title: 'Gigabit Ethernet на Artix-7 без вендорского тулчейна',
    summary:
      'RGMII на гигабите через Yosys, nextpnr-xilinx и Project X-Ray без вендорских инструментов — шесть блокеров, которые пришлось пропатчить, один оставшийся открытым, и во что обходится обходной путь.',
    openQuestions: [
      'Линк поднимается на 23 включениях из 48 (48%, 95-процентный интервал 34-62%), независимо от RTL на четырёх разных дизайнах. Причина открыта: все гипотезы внутри FPGA исключены; остаются свитч, strap-резисторы PHY, читаемые в момент сброса, и кабель. Самый дешёвый непроведённый опыт не требует кода — две платы напрямую, без свитча.',
      'Все шесть патчей на openXC7/nextpnr-xilinx OPEN — отправлены наверх, ни один не влит по состоянию на 2026-08-09.',
      'Аппаратный захват IDDR на Artix-7 не работает, и открыт сам диагноз, а не только починка: issue #114 отзывает собственный первый вывод («Q1 мёртв, Q2 жив») после того, как детектор оказался односторонним. Оба выхода инертны во всех испробованных режимах фронта. Приёмный тракт использует захват DDR на фабрике как обходной путь.',
      'Sigma ~= 470 пс никогда не измерялась. Она выведена из размаха перекоса в пять шагов через закон длины кадра, а значит не может служить подтверждением этого же закона. Независимое измерение джиттера — тот единственный опыт, который закрыл бы вопрос; значение около 50 пс опровергло бы объяснение.',
      'Частота ошибок по кадрам не измерялась напрямую, а только выводилась из того, поднялся ли линк. Три точки по перекосу цензурированы справа на отсчёте 31 и не позволяют различить конкурирующие модели.',
    ],
    body: [
      { kind: 'h', text: 'Рамка, прежде всего остального' },
      { kind: 'p', text: 'Что работает: три платы ALINX AX7203 обмениваются кадрами собственного протокола по гигабитному RGMII, без операционной системы на обоих концах и без единой вендорской лицензии во всём потоке, который идёт прямо на ноутбуке. Измерено 8-9 августа 2026: 83 543 690 и 78 026 079 проверенных транзакций между платами, ноль расхождений с независимой эталонной моделью, пик 215 932 оп/с, аппаратный круговой обмен 4.71 и 4.74 микросекунды. Каждая транзакция — полный круг: операнды уходят, сосед считает на своём кремнии, результат возвращается и проверяется локально.' },
      { kind: 'p', text: 'Что не работает: узел поднимает линк примерно на половине включений — 23 из 48, 95-процентный интервал около 34-62%, и независимо от того, что делает RTL, на четырёх структурно разных дизайнах. Все гипотезы внутри FPGA исключены измерением. Остаются свитч, strap-резисторы PHY, читаемые в момент сброса, и кабель. Узел, пригодный только после подбрасывания монеты, не разворачивают; таково честное состояние дел.' },
      { kind: 'p', text: 'Что не моё: сам поток. Yosys — это YosysHQ. nextpnr — YosysHQ и Дэвид Шах; статья о фреймворке — Shah, Hung, Wolf, Bazanski, Gisselquist, Milanović, FCCM 2019 (arXiv:1903.10407), и она о Lattice iCE40 и ECP5; Xilinx 7-й серии появился позже, через nextpnr-xilinx. Project X-Ray и база битстримов xc7 — SymbiFlow/F4PGA. Порт под Xilinx и поддержка Artix-7 — это openXC7, профинансированный NLnet. Я этот стек не строил. Я нашёл шесть мест, где он ломался на моём дизайне, и отправил шесть патчей.' },
      { kind: 'h', text: 'Почему RGMII, а не SerDes' },
      { kind: 'p', text: 'openXC7 финансировал работу над гигабитными трансиверами, но это про GTP/GTX — высокоскоростные последовательные линии, нацеленные на 10G. Другая задача. RGMII — это source-synchronous DDR по обычным пользовательским выводам на регистрах общего назначения. Дешевле, ближе к типовой отладочной плате с гигабитным PHY, и потому нагружает примитивы, а не трансиверы: ODDR/IDDR, буферы тактов, управление тактированием.' },
      { kind: 'p', text: 'Плата: ALINX AX7203, кристалл xc7a200tfbg484-2. Приёмный такт RGMII 125 МГц приходит на вывод SRCC (B17) и доходит до BUFG. Тулчейн: nextpnr-xilinx на stable-backports (f8e7643) плюс открытые патчи ниже, Yosys 0.63, prjxray через образ regymm/openxc7, хост macOS arm64.' },
      { kind: 'h', text: 'Блокер 1 — роутер сдался, не перебрав и половины вариантов' },
      { kind: 'p', text: 'Поиск пути от вывода SRCC до буфера тактов останавливался на 50 000 итераций. В базе кристалла таких путей больше 75 000. Предел был выставлен ниже размера пространства поиска, поэтому «неразводимо» на деле означало «недосчитано». Починка — одна константа.' },
      { kind: 'quote', text: 'Путь всё это время лежал в базе кристалла: 75 492 провода. Поиск сдавался на 50 000. Предел итераций, поставленный меньше размерности задачи, выглядит ровно как «маршрута не существует» — барьер в двадцать строк, а не в кремнии, и этот же рисунок повторился в трёх случаях из остальных четырёх.' },
      { kind: 'h', text: 'Блокеры 2-5 — четыре способа тихо уронить сборку' },
      { kind: 'ul', items: ['Глобальный буфер тактов, ведомый с фабрики, ронял размещение вместо преразмещения (#111).', 'set_multicycle_path разбирался и молча отбрасывался — ни ошибки, ни эффекта. Худший вид отказа: ограничение выглядит применённым (#109).', 'Simple-dual-port BRAM выдавал конфликтующие биты разрядности для порта, который я не использовал, и битстрим не создавался вовсе (#112).', 'STARTUPE2, ICAPE2 и родственники существуют в единственном экземпляре на кристалл, но не имели преразмещения (#113).'] },
      { kind: 'h', text: 'Блокер 6 — тот, что остаётся открытым' },
      { kind: 'p', text: 'Аппаратный блок IDDR не захватывает вообще. Размещение и разводка проходят, тайминг сходится, FASM корректен, битстрим конфигурирует — данные просто не появляются. Отправлено наверх как issue #114 с A/B/A/B-подменой битстрима на одной плате: сборка с сырым выводом читает внутриполосный статус 0xD (1000 Мбит/с, полный дуплекс) и считает кадры, а сборка с IDDR не видит ни одного. #115 инициализирует все четыре триггера IFF, а не только Q1/Q2, и закрывает часть проблемы конфигурации, но не эту. Поэтому приёмный тракт использует захват DDR на фабрике.' },
      { kind: 'p', text: 'Открыт и сам диагноз. Ранее заведённый отчёт, issue #65 от janrinze за март 2025, фиксирует, что SAME_EDGE_PIPELINED отвергается сразу — prjxray кодирует для IFF.DDR_CLK_EDGE только SAME и OPPOSITE, — так что входной тракт DDR здесь давно тонок.' },
      { kind: 'h', text: 'Прибор был неверен раньше, чем вывод' },
      { kind: 'p', text: 'Первая версия этого отчёта говорила: «Q1 мёртв, Q2 работает». Это было неверно, и причина стоит больше самой находки.' },
      { kind: 'p', text: 'Живость определялась залипающим ИЛИ: seen <= seen | q. Так нельзя отличить переключающийся выход от залипшего в единице — оба дают 0xF. Добавление симметричного залипающего нуля, zero <= zero | ~q, меняет картину целиком: выход действительно захватывает, только если его видели и в высоком, и в низком состоянии.' },
      { kind: 'table', head: ['Выданный IFF.DDR_CLK_EDGE', 'Q1', 'Q2'], rows: [['SAME_EDGE', 'был-1 0x0, был-0 0xF -> залип НИЗКО', 'был-1 0xF, был-0 0x0 -> залип ВЫСОКО'], ['ни один бит не выдан', 'залип ВЫСОКО', 'залип ВЫСОКО'], ['OPPOSITE_EDGE', 'никогда не высокий', 'никогда не высокий']] },
      { kind: 'p', text: 'Сборка байтов это подтверждает: выборка в начале кадра, где обязана появиться преамбула Ethernet 0x55, даёт F0 при SAME_EDGE и FF без битов фронта — постоянные уровни, никогда не 0x55. Так что исправленный вывод проще и хуже первого: оба выхода инертны во всех испробованных режимах фронта, тогда как вывод заведомо несёт гигабитный трафик.' },
      { kind: 'quote', text: 'Односторонний детектор не отличает живое от залипшего. Если прибор способен выдать только один из двух своих возможных ответов, он не измеряет — и будет соглашаться с вами каждый раз.' },
      { kind: 'h', text: 'Во что обходится обходной путь: джиттер и зависимость от длины кадра' },
      { kind: 'p', text: 'Перенос захвата на фабрику и обнажил эффект, невидимый при аппаратном IDDR: устойчивость линка зависит от размера кадра. Цифру джиттера, которую обычно приводят рядом, sigma ~= 470 пс, надо называть аккуратно — она никогда не измерялась. Она выведена: дефицит запаса между кадром 64 байта и кадром 1514 байт при целевой частоте ошибок 1% составляет около 0.64 sigma, наблюдаемый размах — пять шагов по 0.06 нс, то есть примерно 300 пс, и приравнивание одного к другому даёт sigma ~= 470 пс ~= 0.12 UI. Независимое измерение, давшее бы что-то около 50 пс, опровергло бы объяснение начисто.' },
      { kind: 'table', head: ['Кадр', 'Размер', 'Минимальный рабочий шаг перекоса'], rows: [['ARP', 'короткий', '26'], ['ICMP', '98 байт', '30'], ['Полный MTU', '1514 байт', '31 (максимум)']] },
      { kind: 'p', text: 'Джиттер накапливается вдоль кадра, поэтому требуемый запас по времени растёт монотонно с длиной кадра в битах. Кадр полного MTU поднимается только на последнем доступном шаге — запас исчерпан, и это ещё одна причина ненадёжности включения.' },
      { kind: 'quote', text: 'Калибруйте перекос по самому длинному кадру, который когда-либо отправите. Линк, настроенный на ARP, потеряет первый же полный кадр, и это будет выглядеть как капризная сеть, а не как ошибка калибровки.' },
      { kind: 'h', text: 'Закон запаса — и почему «джиттер накапливается» неверный механизм' },
      { kind: 'p', text: 'Правило выше верно. Объяснение, которое я дал ему сперва, — нет, и цифры говорят это достаточно ясно, чтобы записать как следует.' },
      { kind: 'p', text: 'Постановка. RGMII на 1000BASE-T идёт с тактом 125 МГц, двойной скоростью данных, по четыре бита на фронт — единичный интервал UI = 4 нс, а кадр в B байт захватывается за N = 2B фронтов выборки. Пусть каждый фронт несёт фазовую ошибку X_i, независимую и одинаково распределённую, симметричную, со стандартным отклонением sigma. Кадр принят верно ровно тогда, когда каждый фронт попадает внутрь запаса: |X_i| < m для всех i.' },
      { kind: 'quote', text: 'Теорема 1 (закон запаса по длине кадра). P(кадр цел) = (1 - 2(1 - F(m)))^N. Для целевой частоты ошибок по кадрам eps требуемый запас равен m(N) = F^-1(1 - eps/(2N)); для гауссовой ошибки m(N) = sigma * Phi^-1(1 - eps/(2N)), что асимптотически равно sigma * sqrt(2 ln(2N/eps)).' },
      { kind: 'p', text: 'То есть запас действительно растёт монотонно с длиной кадра — но как sqrt(log N), а не как sqrt(N). Это эффект экстремального значения на N независимых испытаниях, а не накопление. Ничего не интегрируется: RGMII передаёт такт рядом с данными, поэтому каждый фронт выбирается заново и фазовая ошибка не помнит предыдущего.' },
      { kind: 'quote', text: 'Следствие 1 (модель случайного блуждания опровергнута). Если бы приёмный такт был независимым, фазовая ошибка интегрировалась бы как sigma_N = sigma * sqrt(N). При sigma = 470 пс и MTU (N = 3028) это 25.9 нс против полуглаза в 2.0 нс — превышение в 13 раз. Линк заведомо работает, значит джиттер здесь не накапливается.' },
      { kind: 'quote', text: 'Следствие 2 (граница осуществимости). Линк осуществим для кадров в N фронтов только если sigma < (UI/2) / Phi^-1(1 - eps/(2N)). При UI = 4 нс и MTU этот потолок равен 430 пс для частоты ошибок 1% и 318 пс для 1e-6.' },
      { kind: 'h', text: 'Чтение 470 пс как sigma на фронт нарушает эту границу — и это чтение было неверным' },
      { kind: 'p', text: 'Взятая как независимое СКЗ на фронт, sigma = 470 пс превышает потолок MTU на 9% при частоте ошибок 1% и на 48% при 1e-6, а идеальное центрирование (m = UI/2 = 2 нс) даёт m/sigma = 4.26, то есть P(ошибка фронта) = 2.1e-5. В пересчёте на кадр это предсказывает:' },
      { kind: 'table', head: ['Кадр', 'Фронтов N', 'Предсказанная частота ошибок при идеальном центрировании'], rows: [['ARP 64 Б', '128', '0.27%'], ['ICMP 98 Б', '196', '0.41%'], ['512 Б', '1024', '2.11%'], ['1024 Б', '2048', '4.19%'], ['MTU 1514 Б', '3028', '6.13%']] },
      { kind: 'p', text: 'Потери 6% на полных кадрах пережить можно — TCP переспросит, и линк по-прежнему выглядит поднятым. Но рабочий гигабитный линк выглядит не так, и разрешение оказывается проще всего этого.' },
      { kind: 'h', text: 'Теорема 2 — разделение по dual-Dirac, и противоречие растворяется' },
      { kind: 'p', text: 'Стандартное разложение делит джиттер на ограниченную детерминированную часть и неограниченную гауссову случайную и складывает их при целевой частоте битовых ошибок: TJ = DJ_pp + 2n * RJ_rms, где n = 6.4 при 1e-10, 7.0 при 1e-12, 7.6 при 1e-14. Осциллограф показывает полный джиттер. Я же прочитал 470 пс как СКЗ на фронт. Это не одно и то же число.' },
      { kind: 'table', head: ['Целевая BER', 'n', 'RJ_rms при DJ_pp = 0', 'RJ_rms при DJ_pp = 300 пс'], rows: [['1e-10', '6.4', '36.7 пс', '13.3 пс'], ['1e-12', '7.0', '33.6 пс', '12.1 пс'], ['1e-14', '7.6', '30.9 пс', '11.2 пс']] },
      { kind: 'p', text: 'Раскрыв глаза: 4000 - 470 = 3530 пс, то есть 88% единичного интервала. Вполне осуществимо. Прочитанные как независимое СКЗ на фронт, 470 пс подразумевают случайную составляющую примерно в 14 раз большую, чем допускает разложение dual-Dirac при 1e-12. Нарушение осуществимости было артефактом моего чтения, а не свойством линка. Следствие 2 остаётся верным как сформулировано; просто его посылка здесь не выполняется.' },
      { kind: 'quote', text: 'Поэтому первый вопрос к любой цифре джиттера: это СКЗ или размах, и при какой BER? Всё дальнейшее зависит от этого одного ответа.' },
      { kind: 'h', text: 'Теорема 3 — ограниченный детерминированный джиттер, предлагается как гипотеза, а не как закон' },
      { kind: 'p', text: 'Если случайная составляющая всего около 30 пс СКЗ, она не объясняет зависимость от длины кадра вовсе. Объяснять должно что-то ограниченное и зависящее от рисунка: межсимвольная интерференция и искажение скважности — функции битового рисунка, а не прошедшего времени. Короткий кадр ARP может ни разу не задеть худший рисунок; кадр MTU, скорее всего, задевает. При p — вероятности задеть почти худший рисунок на фронт — получаем m(N) = s_inf - (s_inf - s0)(1-p)^N, что насыщается, а не расходится, и наблюдаемые 26, 30, 31 действительно замедляются.' },
      { kind: 'p', text: 'Эта подгонка ничего не стоит как доказательство, и я хочу прямо сказать почему. Три параметра против трёх точек совпадают по построению. Об этом говорят две диагностики: подогнанный потолок ложится ровно на 31.00 отсчёта, но точка MTU цензурирована на 31, поэтому любая насыщающаяся модель туда и приедет; а подогнанное s0 выходит -73 отсчёта, отрицательная задержка, — так выглядит переопределённая подгонка, когда её ничто не ограничивает. Теорема 3 — гипотеза о механизме с предсказанием: 128 Б должны требовать около отсчёта 30.8, а 256 Б и выше уже упираться в 31. Она опровергается, если 256 Б спокойно работают на отсчёте 28.' },
      { kind: 'h', text: 'Опыт, который надо ставить первым: менять содержимое, а не длину' },
      { kind: 'p', text: 'Развёртка по длине запутана цензурированным диапазоном отсчётов. Содержимое полезной нагрузки — нет. Держите кадр на 1514 байтах и меняйте только нагрузку — все нули, все единицы, PRBS-7, PRBS-31 и намеренно худший для МСИ рисунок (длинная серия, за которой одиночный переход) — по 1e5 кадров на каждый при фиксированном отсчёте.' },
      { kind: 'ul', items: ['Частота ошибок сильно зависит от содержимого: доминирует МСИ, и лечится это выравниванием или лучшим захватом, а не расширением диапазона перекоса.', 'Частота ошибок от содержимого не зависит: механизм всё-таки случайный джиттер, и цифру 470 пс надо перемерять как СКЗ.', 'Зависит и от того, и от другого: раскладывать как следует, измерением dual-Dirac на осциллографе.'] },
      { kind: 'p', text: 'Для этого не нужен ни более широкий диапазон отсчётов, ни новое железо, — потому это и первый опыт, а не третий.' },
      { kind: 'p', text: 'Три измеренные точки вопрос не решают. Подгонка шага против ln N даёт последовательные наклоны 9.39 и 0.37 — разница в 26 раз; против sqrt(N) это 1.49 и 0.02, разница в 61 раз. Ни одна функциональная форма не ложится, и причина видна в самих данных: точка MTU стоит на отсчёте 31, максимуме диапазона, то есть цензурирована справа. Её истинный требуемый перекос может быть больше, чем железо способно выразить.' },
      { kind: 'h', text: 'Опыт, который закрыл бы вопрос' },
      { kind: 'p', text: 'Прогнать нагрузку на 64, 128, 256, 512, 1024 и 1514 байтах при лучшем отсчёте, по 1e5 кадров на точку, и измерять частоту ошибок по кадрам напрямую, а не выводить её из того, поднялся ли линк.' },
      { kind: 'ul', items: ['FER растёт примерно линейно по N, с ~0.3% до ~6% — независимая модель верна и sigma реальна.', 'FER примерно постоянна по N — ошибки коррелированы или систематичны, и 470 пс не есть случайный джиттер на фронт.', 'FER растёт быстрее линейного — что-то всё же интегрируется, и переданный такт свою работу не делает.'] },
      { kind: 'p', text: 'Расширенный диапазон отсчётов заодно снял бы цензуру с точки MTU. До тех пор практическое правило стоит на собственных основаниях — калибровать по самому длинному кадру, — а механизм за ним остаётся открытым.' },
      { kind: 'h', text: 'Воспроизведение' },
      { kind: 'code', text: '# синтез\nyosys -p \'synth_xilinx -flatten -nowidelut -family xc7 -json <top>.json\' <sources>.v\n\n# размещение и разводка\nnextpnr-xilinx --chipdb <part>.bin --xdc <constraints>.xdc \\\\\n               --json <top>.json --write <top>_routed.json --fasm <top>.fasm\n\n# битстрим\npython3 fasm2frames.py --part <part> --db-root <prjxray-db> <top>.fasm > <top>.frames\nxc7frames2bit --part_file <part>.yaml --frm_file <top>.frames --output_file <top>.bit\n\n# прошивка\nopenFPGALoader -b <board> <top>.bit' },
      { kind: 'p', text: 'Перекос передачи — это регистр PHY, записываемый по MDIO, с шагом 0.06 нс; размах с 26 до 31 — пять шагов, около 300 пс. Три ловушки этого потока стоит знать: synth_xilinx принимает -family xc7, а не -arch; prjxray fasm2frames должен запускаться внутри дерева с выставленным PYTHONPATH, потому что его обычно не ставят через pip; и --db-root — это каталог семейства, никогда не каталог кристалла. Ещё одна стоит реального времени: упавший fasm2frames всё равно оставляет частичный .frames, из которого xc7frames2bit преспокойно соберёт нормальный на вид битстрим в 9.7 МБ, который прошьётся с done=1 и оставит плату немой. Проверяйте код возврата, а не размер файла, — и done=1 означает, что конфигурация завершилась, а не что ваш дизайн на плате.' },
      { kind: 'h', text: 'Что это значит' },
      { kind: 'p', text: 'Полностью открытый цикл — синтез, размещение и разводка, битстрим, прошивка, всё локально и без лицензий — доводит гигабитный Ethernet на Artix-7 до рабочего состояния. Шесть мест, где он не мог этого сделать, описаны и пропатчены; один блокер остаётся открытым и обходится ценой джиттера.' },
      { kind: 'p', text: 'Это не замена Vivado. Это отчёт о том, что на одном классе дизайнов открытый поток доходит до конца, плюс точный список того, что для этого нужно починить.' },
    ],
  },
}


const energyAsymmetry: Post = {
  slug: 'energy-asymmetry-activations',
  title: 'Half of your activations are negative. They carry 1.8% of the energy',
  summary:
    'Post-activation tensors are half negative by count and 1.8–6.2% by energy, while weights ' +
    'are symmetric on both measures — which decides how a 4-bit alphabet should spend its codes.',
  date: '2026-08-11',
  readingMinutes: 6,
  tags: ['Quantisation', 'Transformers', 'Numeric formats', '4-bit'],
  receipts: [
    { label: 'The measurement, with the table',
      href: 'https://github.com/gHashTag/trinity-fpga/blob/main/research/block/ENERGY_ASYMMETRY_2026-08-09.md' },
    { label: 'The comparison it predicts (BlockDialect, DialectFP4)',
      href: 'https://github.com/gHashTag/trinity-fpga/blob/main/research/block/ASYM_VS_BLOCKDIALECT_2026-08-09.md' },
    { label: 'DialectFP4, the competitor — arXiv:2501.01144',
      href: 'https://arxiv.org/abs/2501.01144' },
  ],
  openQuestions: [
    'Measured on SmolLM2-135M and Qwen2.5-0.5B only. Two small models is not a general result, ' +
    'and nothing here shows the ratio holds at 7B or beyond.',
    'The energy share is reported for GELU and SiLU/SwiGLU. Other activations were not measured, ' +
    'and ReLU is trivially 0% because it has no negative outputs at all.',
    'The advantage on activations (1.17×–1.46×) comes with a loss on weights (0.94×). Whether a ' +
    'mixed alphabet — asymmetric for activations, symmetric for weights — is worth its control ' +
    'cost in hardware has not been measured.',
  ],
  body: [
    { kind: 'p', text:
      'This is an observation about transformers, not about any particular numeric format. It ' +
      'takes two lines to check on a model you already have.' },
    { kind: 'h', text: 'The table' },
    { kind: 'table',
      head: ['source', 'fraction < 0', 'energy < 0'],
      rows: [
        ['ReLU', '0.0%', '0.0%'],
        ['GELU', '49.9%', '1.8%'],
        ['SiLU / SwiGLU', '50.1%', '6.2%'],
        ['after LayerNorm', '49.8%', '50.3%'],
        ['weights', '50.0%', '50.4%'],
      ] },
    { kind: 'p', text:
      'Two columns describing the same tensor. For weights they agree. For GELU outputs they ' +
      'differ by a factor of twenty-seven.' },
    { kind: 'h', text: 'What it means' },
    { kind: 'p', text:
      'One-sidedness is a property of a tensor\u2019s energy, not of its count. GELU passes ' +
      'almost half its values into the negative region, but they sit near zero: nearly ' +
      'everything carrying magnitude is positive.' },
    { kind: 'p', text:
      'The count view says the distribution is symmetric, so spend the sign bit evenly. The ' +
      'energy view says the negative half is nearly empty. A quantiser that allocates on the ' +
      'count spends half its code space on 2% of the signal.' },
    { kind: 'p', text:
      'Note where the disagreement stops. Weights and post-LayerNorm tensors are symmetric on ' +
      'both measures, so the rule is not \u201ctransformers are one-sided\u201d but the sharper ' +
      'one: post-activation tensors are, and only by energy. The same network needs different ' +
      'treatment for weights and activations at the same layer.' },
    { kind: 'h', text: 'It predicts a result, in both directions' },
    { kind: 'p', text:
      'An asymmetric 4-bit alphabet, compared against DialectFP4 using the codebook from that ' +
      'paper\u2019s own Figure 4 and its scale rule, wins on every activation class and loses ' +
      'on weights:' },
    { kind: 'table',
      head: ['source', 'BlockDialect', 'asymmetric k=4', 'advantage'],
      rows: [
        ['GELU', '1.80×', '2.11×', '1.17×'],
        ['SiLU / SwiGLU', '2.51×', '3.02×', '1.20×'],
        ['ReLU', '1.64×', '2.39×', '1.46×'],
        ['weights', '1.59×', '1.49×', '0.94×'],
      ] },
    { kind: 'p', text:
      'The loss is in the table on purpose. It wins exactly where the asymmetry exists and pays ' +
      'about 6% where it does not — which is a prediction landing, not a lucky sweep.' },
    { kind: 'h', text: 'Check it on your own model' },
    { kind: 'code', text:
      '(x < 0).float().mean()              # fraction negative\n' +
      '(x[x<0]**2).sum() / (x**2).sum()    # energy share of the negative half' },
    { kind: 'p', text:
      'If the second number is much smaller than the first, you have the same asymmetry and ' +
      'your quantiser does not know about it. If they are equal — as they will be for weights — ' +
      'an asymmetric alphabet has nothing to offer you, and that is visible before you build one.' },
  ],
  published: true,
}

const blockAxisLost: Post = {
  slug: 'block-axis-decided-against-us',
  title: 'I attacked one axis three times and lost three times. Here is the table',
  summary:
    'Block-scaled 4-bit quantisation: MXFP4 at 1.514x fp32, plain int4 at 2.132x, and our own ' +
    'TNF4 last at 2.535x \u2014 with the reason in the row and the axis closed on a measurement.',
  date: '2026-08-11',
  readingMinutes: 7,
  tags: ['Quantisation', '4-bit', 'MXFP4', 'Numeric formats', 'Negative result'],
  receipts: [
    { label: 'The verdict, with the full table',
      href: 'https://github.com/gHashTag/trinity-fpga/blob/main/research/block/BLOCK_AXIS_VERDICT_2026-08-10.md' },
    { label: 'Why a fourth attempt is not warranted',
      href: 'https://github.com/gHashTag/trinity-fpga/blob/main/research/frontier/BLOCK_AXIS_CLOSED_2026-08-10.md' },
    { label: 'The five bugs that made earlier comparisons flatter us',
      href: 'https://github.com/gHashTag/trinity-fpga/blob/main/research/block/FINDINGS.md' },
  ],
  openQuestions: [
    'Measured on SmolLM2-135M, wikitext-2, 40 windows of 2048 tokens, block 32. One model. ' +
    'Nothing here shows the ordering holds at larger scale, and it may not.',
    'The comparison is weights-only quantisation of linear layers. Activation quantisation was ' +
    'not part of this axis and is measured separately.',
    'MXFP4 wins here; that says nothing about axes where the exponent is not hoisted out of ' +
    'the block. The claim is about this axis, not about the format overall.',
  ],
  body: [
    { kind: 'p', text:
      'Block-scaled 4-bit quantisation. I built a ternary format and checked whether it beats ' +
      'MXFP4 on the block axis. It does not \u2014 in any of three attempts.' },
    { kind: 'h', text: 'The measurement' },
    { kind: 'p', text:
      'SmolLM2-135M, wikitext-2, 40 windows of 2048 tokens, block of 32 along the contraction ' +
      'axis, E8M0 shared scale \u2014 the one the MX specification itself defines. Baseline ' +
      'perplexity 14.4874, verified in band before any comparison ran.' },
    { kind: 'table',
      head: ['candidate', 'magnitudes', 'ppl', 'vs fp32'],
      rows: [
        ['MXFP4 (E2M1 + E8M0)', '8 / 8', '21.9397', '1.514×'],
        ['int4 uniform + E8M0', '8 / 8', '30.8859', '2.132×'],
        ['TNF4 (ours)', '7 / 8', '36.7214', '2.535×'],
      ] },
    { kind: 'p', text:
      'Our format is last. Plain int4 is ahead of it too.' },
    { kind: 'h', text: 'Seven magnitudes against eight' },
    { kind: 'p', text:
      'TNF4 is a ternary-exponent float and it pays a packing remainder: at four bits it gets ' +
      'seven representable magnitudes where E2M1 gets eight. One magnitude is not a rounding ' +
      'detail at four bits \u2014 it is 12.5% of the alphabet.' },
    { kind: 'p', text:
      'E2M1 gets its eighth from a subnormal. That is the same subnormal I once omitted from my ' +
      'own implementation of E2M1, when I built it from memory instead of from the spec \u2014 ' +
      'which meant I was comparing my format against a weakened version of the competitor.' },
    { kind: 'h', text: 'Three attacks' },
    { kind: 'ol', items: [
      'TNF4, a ternary exponent. Lost.',
      'Constant-ratio ladders from the multiply-free hierarchy. Lost.',
      'Two-segment ladders built to imitate E2M1\u2019s non-constant spacing. Lost.',
    ] },
    { kind: 'p', text:
      'There will not be a fourth, and the reason is a measurement rather than fatigue: E2M1\u2019s ' +
      'non-constant spacing does on this task exactly what it is there for, and constant-ratio ' +
      'constructions do not reproduce it.' },
    { kind: 'h', text: 'What this means for the format' },
    { kind: 'p', text:
      'The block axis is closed. Not "we have not managed it yet" \u2014 closed, with numbers and ' +
      'with the reason stated. The format lives on other axes, and claims about it no longer ' +
      'include this one.' },
    { kind: 'h', text: 'If you are measuring against MX' },
    { kind: 'ul', items: [
      'Take the shared scale from their specification, not from a description of it.',
      'Verify your baseline perplexity in band before you run the comparison, not after.',
      'Count representable magnitudes on both sides. Seven against eight is a result, not a detail.',
    ] },
    { kind: 'p', text:
      'Each of those is something I once got wrong here.' },
  ],
  published: true,
}

export const posts: Post[] = [blockAxisLost, energyAsymmetry, openGigabitEthernet]

export const publishedPosts = () => posts.filter((p) => p.published)

export const postBySlug = (slug: string) => posts.find((p) => p.slug === slug)
