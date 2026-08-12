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

const scaleFieldWidth: Post = {
  slug: 'scale-field-width-already-published',
  title: 'The scale field does not need eight bits, and we were not the first to say so',
  summary:
    'Four bits cover the shared scale on every checkpoint measured -- bit-identical to E8M0, zero blocks truncated out of 20,462,464. The observation was published first by someone else; what is ours is the proof around it, and the constant does not survive contact with activations.',
  date: '2026-08-11',
  readingMinutes: 9,
  tags: ['Number formats', 'MXFP4', 'Quantisation', 'Prior art'],
  receipts: [
    { label: 'Chhugani et al., Unveiling the Potential of Quantization with MXFP4 (arXiv:2603.08713), section 3.3 -- the prior publication of the 4-bit-suffices observation', href: 'https://arxiv.org/abs/2603.08713' },
    { label: 'Dettmers et al., QLoRA: Efficient Finetuning of Quantized LLMs (NeurIPS 2023) -- double quantisation, 0.5 to 0.127 bits per parameter', href: 'https://arxiv.org/abs/2305.14314' },
    { label: 'Rouhani et al., With Shared Microexponents, A Little Shifting Goes a Long Way (ISCA 2023) -- multi-level exponent splitting', href: 'https://arxiv.org/abs/2302.08007' },
    { label: 'OCP Microscaling Formats (MX) Specification v1.0 -- the E8M0 shared scale this measures against', href: 'https://www.opencompute.org/documents/ocp-microscaling-formats-mx-v1-0-spec-final-pdf' },
  ],
  openQuestions: [
    'The observation that four bits suffice for the scale exponent is not ours: Chhugani et al. (arXiv:2603.08713, section 3.3) published it on larger models. What is presented here as new is the theory around it -- the sufficiency proof, the R < S < R+2 bound, and the separation of sufficiency from necessity.',
    'Necessity was NOT established per tensor, only in the worst case. A counterexample exists in which a truncated scale field returns the same dequantised weights, so \'b_min bits are required\' is false as a per-tensor statement.',
    'Activation spans are sample-dependent and were still growing between measurement windows. The five-bit figure for activations is a lower bound on what a longer run would report, not a converged number.',
    'The binade-grid phase ambiguity is worth one code either way and has not been eliminated: Pythia\'s R = 7.33 gives S = 8 at one phase and S = 9 at another.',
    'The five checkpoints are small (SmolLM2, Qwen, Pythia, OPT, GPT-2). The prior work reports the same conclusion on Llama-3.1-8B and Qwen3-8B, so the direction agrees at scale, but nothing here was measured at that size.',
  ],
  published: true,
  body: [
    { kind: 'h', text: 'The claim, and who published it first' },
    { kind: 'p', text: 'The result this line of work was built around is that the shared scale in a block format does not need an eight-bit exponent. Measured on five checkpoints at block size 32, the minimum sufficient width is b_min = 3, 4, 3, 4, 4. A four-bit field truncates zero blocks out of 20,462,464 and is bit-identical to E8M0 in every tensor of every model. Not approximately sufficient -- identical.' },
    { kind: 'p', text: 'The observation is already published. Chhugani et al., "Unveiling the Potential of Quantization with MXFP4" (arXiv:2603.08713, submitted 30 January 2026), section 3.3: "for nearly all weight tensors and over 98% of activation tensors, a 4-bit exponent suffices to capture the scaling factor\'s dynamic range". They evaluate Llama-3.1-8B-Instruct and Qwen3-8B, among others. That is the same finding, on larger models, published first.' },
    { kind: 'p', text: 'So the measurement here is a replication on five smaller checkpoints, and it is written up as one. Reporting it as a discovery would have been the easy mistake, and the expensive one: the reviewer who knows the field finds the prior work in one search and stops reading.' },
    { kind: 'h', text: 'One thing the prior work does not do' },
    { kind: 'p', text: 'The paper observes the redundancy and then goes the other way. It keeps E8M0 for fine-grained 1x16 block scaling and adds a separate macro-block scale with an eight-bit mantissa at 1x128 granularity, explicitly to avoid the hardware cost of implementing E4M3 natively. It does not propose narrowing the scale field. The observation is theirs; the prescription that follows from it is not in that paper.' },
    { kind: 'h', text: 'The idea is older than either of us, and it is already in silicon' },
    { kind: 'ul', items: ['QLoRA double quantisation (NeurIPS 2023) makes the same observation one level down, quantising the quantisation constants and taking 0.5 bits per parameter to 0.127.', 'NVFP4 on Blackwell already implements the architecture the theorem prescribes: a per-tensor FP32 anchor plus a narrow per-block E4M3. The anchor is the bias that makes a narrow field possible. That is a shipped design, not a proposal.', 'Shared Microexponents / MSFP (ISCA 2023) is an entire paper about splitting exponents across levels.'] },
    { kind: 'h', text: 'What survives as ours: the theory, not the observation' },
    { kind: 'p', text: 'b_min = ceil(log2 S(W,K)), with a sufficiency proof and bit-identity to E8M0 rather than an empirical threshold. The bound R < S < R+2 relating the real span to the integer code count, checked on all 3,780 tensor-K pairs without a single exception. And, stated separately because it is the part that is easy to overclaim: necessity holds only in the worst case, not per tensor. A counterexample is constructed -- a truncated scale can give back the same dequantised weights.' },
    { kind: 'p', text: 'There is also a phase ambiguity in the binade grid worth one code either way. Pythia is the live example: R = 7.33 gives S = 8, and at a different phase the same span gives S = 9. A rule that reads the span and rounds will disagree with itself depending on where the grid happens to sit.' },
    { kind: 'h', text: 'The limits are part of the claim' },
    { kind: 'p', text: 'Block size moves the answer. b_min against K = 1..256:' },
    { kind: 'table', head: ['model', 'K = 1, 2, 4, 8, 16, 32, 64, 128, 256'], rows: [['SmolLM2', '5, 5, 4, 4, 3, 3, 3, 3, 3'], ['Qwen', '5, 5, 4, 4, 4, 4, 3, 3, 3'], ['Pythia', '5, 5, 4, 4, 4, 3, 3, 3, 3'], ['OPT', '5, 5, 4, 4, 4, 4, 4, 4, 4'], ['GPT-2', '5, 5, 5, 4, 4, 4, 4, 4, 4']] },
    { kind: 'p', text: 'Four bits suffice for all five at K >= 8, and do not at K <= 2 -- and for GPT-2 not at K = 4 either. A constant quoted without its block size is not a constant.' },
    { kind: 'h', text: 'Activations break the constant' },
    { kind: 'p', text: 'MX shares one encoding between weights and activations, so the weight figure is not the whole answer. At layer inputs OPT needs five bits: twelve of seventy-two layers exceed four, the worst being decoder.layers.7.fc2 with a span of 30. The mechanism is not outliers. The input is post-ReLU, and blocks of near-zeros drag the lower bound down by about 28 binades -- it is the bottom tail that widens the span, not the top.' },
    { kind: 'p', text: 'Spans also depend on the sample and keep growing between windows, so any activation figure is a lower bound on what a longer run would report.' },
    { kind: 'h', text: 'What is left standing' },
    { kind: 'p', text: '"E8M0 is over-provisioned" survives: five is less than eight on every model measured. The constant does not survive as a single number. It is four bits for weights, and five once activations share the encoding.' },
  ],
  ru: {
    title: 'Полю масштаба не нужны восемь бит, и сказали это не мы первыми',
    summary:
      'Четырёх бит хватает на общий масштаб во всех измеренных чекпоинтах — побитово идентично E8M0, ноль обрезанных блоков из 20 462 464. Наблюдение опубликовано раньше и не нами; нашим остаётся доказательство вокруг него, а константа не переживает встречи с активациями.',
    openQuestions: [
      'Наблюдение, что четырёх бит достаточно для экспоненты масштаба, — не наше: Chhugani et al. (arXiv:2603.08713, раздел 3.3) опубликовали его на моделях крупнее. Новым здесь подаётся теория вокруг него — доказательство достаточности, граница R < S < R+2 и разделение достаточности и необходимости.',
      'Необходимость НЕ установлена по тензорам, только в худшем случае. Существует контрпример, где обрезанное поле масштаба возвращает те же деквантованные веса, поэтому «требуется b_min бит» ложно как утверждение о каждом тензоре.',
      'Спаны активаций зависят от выборки и продолжали расти между окнами измерения. Пятибитная цифра по активациям — нижняя оценка, а не сошедшееся значение.',
      'Фазовая неоднозначность бинадной сетки стоит одного кода в любую сторону и не устранена: у Pythia R = 7.33 даёт S = 8 при одной фазе и S = 9 при другой.',
      'Пять чекпоинтов невелики (SmolLM2, Qwen, Pythia, OPT, GPT-2). Предшествующая работа сообщает тот же вывод на Llama-3.1-8B и Qwen3-8B, то есть направление совпадает и на масштабе, но здесь на таком размере ничего не измерялось.',
    ],
    body: [
      { kind: 'h', text: 'Заявление и кто опубликовал его первым' },
      { kind: 'p', text: 'Результат, вокруг которого строилась эта линия работы: общий масштаб в блочном формате не нуждается в восьмибитной экспоненте. Замерено на пяти чекпоинтах при размере блока 32, минимальная достаточная ширина b_min = 3, 4, 3, 4, 4. Четырёхбитное поле обрезает ноль блоков из 20 462 464 и побитово идентично E8M0 в каждом тензоре каждой модели. Не приблизительно достаточно — идентично.' },
      { kind: 'p', text: 'Наблюдение уже опубликовано. Chhugani et al., «Unveiling the Potential of Quantization with MXFP4» (arXiv:2603.08713, подана 30 января 2026), раздел 3.3: «for nearly all weight tensors and over 98% of activation tensors, a 4-bit exponent suffices to capture the scaling factor\'s dynamic range». Они оценивают в том числе Llama-3.1-8B-Instruct и Qwen3-8B. Это то же самое наблюдение, на моделях крупнее, опубликованное раньше.' },
      { kind: 'p', text: 'Поэтому здешний замер — репликация на пяти меньших чекпоинтах, и он так и подан. Выдать его за открытие было бы лёгкой ошибкой и дорогой: рецензент, знающий область, находит предшествующую работу одним поиском и перестаёт читать.' },
      { kind: 'h', text: 'Чего предшествующая работа не делает' },
      { kind: 'p', text: 'Статья замечает избыточность и идёт в другую сторону. Она оставляет E8M0 на мелком блоке 1×16 и добавляет отдельный макроблочный масштаб с восьмибитной мантиссой на 1×128 — прямо ради того, чтобы не платить за аппаратный E4M3. Сузить поле масштаба она не предлагает. Наблюдение — их; предписание, которое из него следует, в той статье не сформулировано.' },
      { kind: 'h', text: 'Идея старше нас обоих и уже в кремнии' },
      { kind: 'ul', items: ['QLoRA double quantisation (NeurIPS 2023) делает то же наблюдение уровнем ниже, квантуя сами константы квантования: 0.5 бита на параметр превращаются в 0.127.', 'NVFP4 на Blackwell уже реализует архитектуру, которую предписывает теорема: пер-тензорный якорь FP32 плюс узкий пер-блочный E4M3. Якорь и есть тот сдвиг, который делает узкое поле возможным. Это внедрённая конструкция, а не предложение.', 'Shared Microexponents / MSFP (ISCA 2023) — целая статья о разделении экспонент по уровням.'] },
      { kind: 'h', text: 'Что остаётся нашим: теория, а не наблюдение' },
      { kind: 'p', text: 'b_min = ⌈log₂ S(W,K)⌉ — с доказательством достаточности и побитовой идентичностью E8M0, а не эмпирическим порогом. Граница R < S < R+2, связывающая вещественный спан с целым числом кодов, проверена на всех 3780 парах тензор-K без единого исключения. И отдельно, потому что именно здесь легко переусердствовать: необходимость выполняется только в худшем случае, не по тензорам. Построен контрпример — обрезанное поле масштаба может вернуть те же деквантованные веса.' },
      { kind: 'p', text: 'Есть также фазовая неоднозначность бинадной сетки ценой в один код в любую сторону. Pythia — живой пример: R = 7.33 даёт S = 8, а при другой фазе тот же спан даёт S = 9. Правило, которое читает спан и округляет, будет расходиться само с собой в зависимости от того, где стоит сетка.' },
      { kind: 'h', text: 'Границы — часть заявления' },
      { kind: 'p', text: 'Размер блока меняет ответ. b_min при K = 1…256:' },
      { kind: 'table', head: ['модель', 'K = 1, 2, 4, 8, 16, 32, 64, 128, 256'], rows: [['SmolLM2', '5, 5, 4, 4, 3, 3, 3, 3, 3'], ['Qwen', '5, 5, 4, 4, 4, 4, 3, 3, 3'], ['Pythia', '5, 5, 4, 4, 4, 3, 3, 3, 3'], ['OPT', '5, 5, 4, 4, 4, 4, 4, 4, 4'], ['GPT-2', '5, 5, 5, 4, 4, 4, 4, 4, 4']] },
      { kind: 'p', text: 'Четырёх бит хватает всем пяти при K ≥ 8 и не хватает при K ≤ 2, а у GPT-2 — и при K = 4. Константа, названная без размера блока, не константа.' },
      { kind: 'h', text: 'Активации ломают константу' },
      { kind: 'p', text: 'MX делит одну кодировку между весами и активациями, поэтому цифра по весам — не весь ответ. На входах слоёв OPT требует пяти бит: двенадцать слоёв из семидесяти двух выше четырёх, худший — decoder.layers.7.fc2 со спаном 30. Механизм — не выбросы. Вход постReLU, и блоки почти-нулей утягивают нижнюю границу вниз примерно на 28 бинад: спан расширяет нижний хвост, а не верхний.' },
      { kind: 'p', text: 'Спаны к тому же зависят от выборки и продолжали расти между окнами измерения, поэтому любая цифра по активациям — нижняя оценка того, что показал бы более длинный прогон.' },
      { kind: 'h', text: 'Что остаётся в силе' },
      { kind: 'p', text: '«E8M0 переобеспечено» выживает: пять меньше восьми на каждой измеренной модели. Константа как одно число не выживает. Это четыре бита для весов и пять, как только кодировку делят активации.' },
    ],
  },
}

// Written after a night spent wiring three of my own repositories together and
// finding that the green one was the broken one. Every number below came out of
// a CI log the same night; the pull requests are linked and their states are
// named exactly, including the two that are still open.
const greenCiUnusable: Post = {
  slug: 'green-ci-does-not-mean-usable',
  title: 'A green CI does not mean the library builds for you',
  summary:
    'A Zig package with passing CI could not be compiled by any consumer. Lazy analysis means a test run proves only what the tests happen to touch — one line exposed five hidden errors in one package, and sixteen in the package under it.',
  date: '2026-08-11',
  readingMinutes: 11,
  tags: ['Zig', 'CI', 'Verification', 'Static analysis'],
  receipts: [
    { label: 'zig-golden-float #97 — 16 defects, CI green on 0.15.2 · MERGED 2026-08-11', href: 'https://github.com/gHashTag/zig-golden-float/pull/97' },
    { label: 'zig-hdc #2 — full-surface analysis, 5 drift errors · OPEN', href: 'https://github.com/gHashTag/zig-hdc/pull/2' },
    { label: 'trinity #701 — the consumer that surfaced it · OPEN', href: 'https://github.com/gHashTag/trinity/pull/701' },
  ],
  openQuestions: [
    'Which copy of src/vsa/* is canonical is undecided. The two packages carry their own and they have diverged, so repairing one does not repair the other.',
    'zig-hdc is still red. Its five errors are in its own copy of files that were repaired in the package below it.',
    'refAllDeclsRecursive forces analysis, not execution. It proves the surface compiles; it says nothing about whether any of it is correct.',
    'Whether the same gap exists in other lazily-analysed languages was not tested. The claim here is about Zig, measured on Zig.',
  ],
  body: [
    { kind: 'p', text: 'A package of mine had passing CI and could not be used by anybody. Not "was awkward to use" — could not be compiled by a consumer at all. The tests were real, they ran, and they were green, and the thing they were green about was not the thing anybody needed.' },
    { kind: 'p', text: 'The cause is a language feature, not a mistake: Zig analyses top-level declarations lazily. A declaration nothing references is never handed to the compiler. So `zig build test` proves that the declarations the tests happen to reference compile — and says nothing whatsoever about the rest of the public surface.' },
    { kind: 'h', text: 'How it surfaced' },
    { kind: 'p', text: 'I was repairing a third repository whose build had failed for four months, and part of the repair was to depend on this package instead of on files that a refactor had moved out from under it. The dependency resolved. Then the compiler reported an error inside the dependency itself:' },
    { kind: 'code', text: "no field named 'allocator' in struct 'ternary.hybrid.HybridBigInt'\n  at .zig-cache/p/zig_hdc-.../src/vsa/core.zig:30:35" },
    { kind: 'p', text: 'That file belongs to the package with the green CI. It expects a field on a type from the version of its own dependency that it pins, and that field is not there. Its tests never referenced the function containing the line, so the line was never compiled, so the CI never had an opinion about it.' },
    { kind: 'h', text: 'One line changes what the CI is measuring' },
    { kind: 'code', text: 'test "every public declaration of this module is analysed" {\n    @import("std").testing.refAllDeclsRecursive(@This());\n}' },
    { kind: 'p', text: 'With that in the module root, the whole public surface goes through the compiler. The package immediately reported five distinct errors, all of which had been there the entire time:' },
    { kind: 'ul', items: [
      "no field named 'allocator' in struct HybridBigInt",
      "expected type '*HybridBigInt', found '*const HybridBigInt'",
      "expected optional type, found '[59049]i8'",
      "incompatible types: 'u32' and 'i32'",
      'member function expected 1 argument(s), found 2',
    ] },
    { kind: 'p', text: 'Nothing was fixed by adding the test. Only the instrument changed.' },
    { kind: 'h', text: 'The package underneath had never been built at all' },
    { kind: 'p', text: 'Two of those errors pointed downwards, into the package that this one depends on. So I looked there, and found something worse than a blind spot: that repository had no workflow that runs `zig build`. Not a weak one — none. Its CI built documentation and language bindings.' },
    { kind: 'p', text: 'Adding one, pinned to the Zig version its consumers actually use, produced a package that spans three incompatible versions of the language at once:' },
    { kind: 'table', head: ['Targets', 'Evidence'], rows: [
      ['0.14', 'Io.getStdOut, atomic.fence, fmt.fmtSliceHexLower, OpenFlags.read — all removed in 0.15'],
      ['0.15', 'what minimum_zig_version in the manifest claims'],
      ['0.16', 'tools/gen/* use std.Io, std.Io.Dir and std.process.Init, and say so in their own comments'],
    ] },
    { kind: 'p', text: 'The version claim in the manifest was not a lie anybody told. It was a number written once and never checked again, because nothing checked it.' },
    { kind: 'h', text: 'What the repair looked like' },
    { kind: 'p', text: 'Sixteen defects, in five waves. A compiler stops at the first failure in a unit, so each round of fixes exposes the next round: 11 errors, then 5, then 3, then 2, then one runtime panic, then zero. Four were the removed APIs above. The other twelve were ordinary defects that had simply never been compiled:' },
    { kind: 'ul', items: [
      'A checksum multiplied a u64 by a floating-point golden ratio and then called @intFromFloat on the u64 result. It now multiplies by 2^64/phi, which is what phi is in integer hashing.',
      'A switch on a runtime value with comptime_float arms.',
      'Two functions declared const pointers and delegated to functions that must mutate, because the value caches its own unpacked form.',
      '@abs of an i32 is a u32, and the modulus beside it was signed.',
      'A u2 shifted by a usize. Zig types a shift amount by the width of what is shifted, so a u2 admits only a u1 — a bit offset of 0, 2, 4 or 6 could not be used there at all.',
      'A manual sign extension that or-ed 0xF800 into an i11, a value that does not fit in one, guarded by an if that was handed a u8 where a bool belongs.',
      'A test that computed @rem(i, 3) - 1 with an unsigned i, so its first iteration underflowed.',
    ] },
    { kind: 'p', text: 'One number in that list is worth pausing on. Six sites assigned an i8 into an i2. The compiler named three. Fixing the three it named would have left the other three standing, and the next person would have met them as a fresh mystery — so the rule is to grep for the pattern rather than to work the error list.' },
    { kind: 'p', text: 'After the last wave: 267 tests pass and that repository has a green build for the first time in its life.' },
    { kind: 'h', text: 'The finding underneath the finding' },
    { kind: 'p', text: 'Re-pinning the first package against the repaired second one changed nothing. Not a caching artefact — pinning the exact merge commit produced the same hash the CDN had already served. The reason is duller and more serious than a stale tarball:' },
    { kind: 'quote', text: 'Both packages carry their own copy of src/vsa/concurrency.zig, src/vsa/core.zig and src/vsa/common.zig, and the copies have diverged.' },
    { kind: 'p', text: 'The migration that broke the third repository did not move that code into one home. It left a second copy behind, and the two drifted independently. Fixing one cannot fix the other, because they are different files with the same names.' },
    { kind: 'p', text: 'That turns the remaining repair into a decision rather than a patch, and it is not one to take at four in the morning: either the consumer drops its copies and takes them from the package below, or the duplication is deliberate and gets written down as such. Applying the same five fixes to the second copy would turn the CI green and entrench two maintained copies of the same code — which is exactly how the divergence happened.' },
    { kind: 'h', text: 'What to take from it' },
    { kind: 'p', text: 'The general shape is not about Zig. A test suite measures the code it reaches. In a language with lazy analysis the unreached part is not merely untested — it is uncompiled, and the difference matters because a consumer reaching it gets a compile error rather than a wrong answer. A green badge on such a package is a statement about the tests, and a reader takes it as a statement about the library.' },
    { kind: 'p', text: 'The cheap countermeasure is one line per package. The expensive part is being willing to look at what it says.' },
    { kind: 'h', text: 'Addendum, 12 August: the third package' },
    { kind: 'p', text: 'The claim above was drawn from two repositories. A third was swept afterwards and it is the clearest case yet, because there was nothing subtle about it at all: zig-half had no workflow that built anything, and six separate things were wrong, each of which alone makes the package unusable.' },
    { kind: 'ul', items: [
      'Its manifest gave the name as a string where 0.15 requires an enum literal, and carried no fingerprint — so nothing could depend on it.',
      'Its build script declared `pub fn test(b: *std.Build)`. In Zig, `test` is a keyword. That file has never compiled, and it also never called standardTargetOptions, passed two arguments to installArtifact, and read b.step as a field.',
      'Its module root — the surface every consumer imports — re-exported everything as `pub use module.{ A, B as C };`. That is Rust. Zig has no `use` statement and no `as` aliasing, so the root has never been valid Zig either.',
      'Four files inside src/ imported "src/x.zig", which resolves to src/src/x.zig.',
      'Six of those re-exports named symbols their module does not export.',
      'One file still used std.io.getStdOut, removed in 0.15.',
    ] },
    { kind: 'p', text: 'Five Rust-shaped blocks became sixty-seven ordinary Zig re-exports with the aliases preserved, and the package now builds and tests green on 0.15.2 for the first time in its life. What makes it worth adding here is not the repair but the arithmetic: three packages swept, three that could not be used by anybody, and in every case the reason nobody knew was the same — no workflow ever asked.' },
  ],
  published: true,
  ru: {
    title: 'Зелёный CI не значит, что библиотека соберётся у вас',
    summary:
      'Пакет на Zig с проходящими тестами не мог собрать ни один потребитель. Ленивый анализ означает, что тесты доказывают лишь то, до чего дотянулись: одна строка вскрыла пять скрытых ошибок в одном пакете и шестнадцать в том, что под ним.',
    openQuestions: [
      'Какая из копий src/vsa/* каноническая — не решено. Оба пакета несут свою, и они разошлись, поэтому починка одной не чинит другую.',
      'zig-hdc всё ещё красный. Его пять ошибок — в собственных копиях файлов, исправленных в пакете уровнем ниже.',
      'refAllDeclsRecursive заставляет анализировать, а не исполнять. Он доказывает, что поверхность компилируется, и ничего не говорит о том, верна ли она.',
      'Есть ли тот же разрыв в других языках с ленивым анализом — не проверялось. Утверждение здесь про Zig и измерено на Zig.',
    ],
    body: [
      { kind: 'p', text: 'У меня был пакет с проходящим CI, которым не мог воспользоваться никто. Не «неудобно пользоваться» — потребитель не мог его скомпилировать вообще. Тесты были настоящие, они запускались и были зелёными, и то, о чём они были зелёными, не было тем, что кому-то нужно.' },
      { kind: 'p', text: 'Причина — свойство языка, а не чья-то оплошность: Zig анализирует объявления верхнего уровня лениво. Объявление, на которое никто не ссылается, компилятору не передаётся никогда. Поэтому `zig build test` доказывает, что компилируются те объявления, до которых случайно дотянулись тесты, — и ровно ничего не говорит об остальной публичной поверхности.' },
      { kind: 'h', text: 'Как это всплыло' },
      { kind: 'p', text: 'Я чинил третий репозиторий, чья сборка падала четыре месяца, и частью починки было подключить этот пакет вместо файлов, которые рефакторинг вынес из-под сборки. Зависимость разрешилась. И компилятор сообщил об ошибке внутри самой зависимости:' },
      { kind: 'code', text: "no field named 'allocator' in struct 'ternary.hybrid.HybridBigInt'\n  в .zig-cache/p/zig_hdc-.../src/vsa/core.zig:30:35" },
      { kind: 'p', text: 'Этот файл принадлежит пакету с зелёным CI. Он ждёт поля у типа из той версии собственной зависимости, которую сам же и закрепил, и поля там нет. Его тесты никогда не ссылались на функцию, содержащую эту строку, поэтому строка не компилировалась, поэтому у CI не было о ней мнения.' },
      { kind: 'h', text: 'Одна строка меняет то, что измеряет CI' },
      { kind: 'code', text: 'test "every public declaration of this module is analysed" {\n    @import("std").testing.refAllDeclsRecursive(@This());\n}' },
      { kind: 'p', text: 'С ней в корне модуля вся публичная поверхность проходит через компилятор. Пакет немедленно выдал пять разных ошибок, и все они были там всё это время:' },
      { kind: 'ul', items: [
        'нет поля allocator в структуре HybridBigInt',
        "ожидался тип '*HybridBigInt', получен '*const HybridBigInt'",
        "ожидался опциональный тип, получен '[59049]i8'",
        "несовместимые типы: 'u32' и 'i32'",
        'метод ожидает 1 аргумент, передано 2',
      ] },
      { kind: 'p', text: 'Добавление теста ничего не починило. Изменился только прибор.' },
      { kind: 'h', text: 'Пакет под ним не собирали ни разу' },
      { kind: 'p', text: 'Две из этих ошибок указывали вниз, в пакет, от которого этот зависит. Я посмотрел туда и нашёл кое-что хуже слепого пятна: в том репозитории **нет ни одного воркфлоу, который запускает `zig build`**. Не слабый — ни одного. Его CI собирал документацию и языковые привязки.' },
      { kind: 'p', text: 'Добавленный воркфлоу, закреплённый на той версии Zig, которой реально пользуются потребители, показал пакет, разъезжающийся сразу по трём несовместимым версиям языка:' },
      { kind: 'table', head: ['Целится в', 'Свидетельство'], rows: [
        ['0.14', 'Io.getStdOut, atomic.fence, fmt.fmtSliceHexLower, OpenFlags.read — всё убрано в 0.15'],
        ['0.15', 'то, что заявляет minimum_zig_version в манифесте'],
        ['0.16', 'tools/gen/* используют std.Io, std.Io.Dir и std.process.Init и прямо пишут об этом в своих комментариях'],
      ] },
      { kind: 'p', text: 'Заявление о версии в манифесте — не чья-то ложь. Это число, написанное однажды и больше не проверявшееся, потому что его никто не проверял.' },
      { kind: 'h', text: 'Как выглядела починка' },
      { kind: 'p', text: 'Шестнадцать дефектов, пятью волнами. Компилятор останавливается на первой ошибке в единице трансляции, поэтому каждый круг правок вскрывает следующий: 11 ошибок, потом 5, потом 3, потом 2, потом одна паника во время выполнения, потом ноль. Четыре — те самые убранные API. Остальные двенадцать — обычные дефекты, которые просто ни разу не компилировали:' },
      { kind: 'ul', items: [
        'Контрольная сумма умножала u64 на золотое сечение в плавающей точке и затем звала @intFromFloat от результата типа u64. Теперь умножает на 2^64/phi — то, чем phi и является в целочисленном хешировании.',
        'switch по рантайм-значению с ветвями типа comptime_float.',
        'Две функции объявляли константные указатели и делегировали туда, где нужна мутация: значение кэширует собственную распакованную форму.',
        '@abs от i32 даёт u32, а модуль рядом был знаковый.',
        'Сдвиг u2 на usize. Zig типизирует величину сдвига по ширине сдвигаемого, поэтому u2 допускает только u1 — смещение 0, 2, 4 или 6 там нельзя было использовать вообще.',
        'Ручное расширение знака, которое вписывало 0xF800 в i11, куда это значение не влезает, под условием, которому подсунули u8 вместо bool.',
        'Тест, считавший @rem(i, 3) - 1 при беззнаковом i: первая же итерация уходила в переполнение.',
      ] },
      { kind: 'p', text: 'На одном числе из этого списка стоит остановиться. Мест, где i8 присваивался в i2, было шесть. Компилятор назвал три. Починка названных оставила бы стоять остальные три, и следующий человек встретил бы их как свежую загадку, — поэтому правило простое: искать по образцу, а не работать по списку ошибок.' },
      { kind: 'p', text: 'После последней волны: 267 тестов проходят, и у этого репозитория зелёная сборка впервые за его жизнь.' },
      { kind: 'h', text: 'Находка под находкой' },
      { kind: 'p', text: 'Перепривязка первого пакета к починенному второму не изменила ничего. И это не артефакт кэша: закрепление точного коммита слияния дало тот же хеш, что CDN уже отдавал. Причина скучнее и серьёзнее устаревшего архива:' },
      { kind: 'quote', text: 'Оба пакета несут собственные копии src/vsa/concurrency.zig, src/vsa/core.zig и src/vsa/common.zig, и копии разошлись.' },
      { kind: 'p', text: 'Тот перенос, который сломал третий репозиторий, не собрал этот код в один дом. Он оставил второй экземпляр, и они разъехались независимо. Починка одного не может починить другой, потому что это разные файлы с одинаковыми именами.' },
      { kind: 'p', text: 'Это превращает оставшийся ремонт в решение, а не в патч, и такое не принимают в четыре утра: либо потребитель отказывается от своих копий и берёт их из пакета ниже, либо дублирование объявляется намеренным и записывается как таковое. Применить те же пять правок ко второй копии значило бы сделать CI зелёным и закрепить две поддерживаемые копии одного кода — то есть ровно то, из-за чего расхождение и возникло.' },
      { kind: 'h', text: 'Что отсюда забрать' },
      { kind: 'p', text: 'Общая форма не про Zig. Набор тестов измеряет тот код, до которого он дотягивается. В языке с ленивым анализом недостигнутая часть не просто не протестирована — она не скомпилирована, и разница существенна: потребитель, дотянувшийся до неё, получает ошибку компиляции, а не неверный ответ. Зелёный значок на таком пакете — утверждение о тестах, а читатель принимает его за утверждение о библиотеке.' },
      { kind: 'p', text: 'Дешёвая мера противодействия — одна строка на пакет. Дорогая часть — готовность прочитать то, что она скажет.' },
      { kind: 'h', text: 'Дополнение от 12 августа: третий пакет' },
      { kind: 'p', text: 'Утверждение выше было сделано по двум репозиториям. Третий обследован позже, и он самый ясный из всех — потому что в нём не было ничего тонкого: у zig-half не было ни одного воркфлоу, который бы что-то собирал, и шесть отдельных вещей были не так, каждой из которых поодиночке хватает, чтобы пакетом нельзя было пользоваться.' },
      { kind: 'ul', items: [
        'Манифест давал имя строкой там, где 0.15 требует enum-литерал, и не имел fingerprint — то есть зависеть от пакета не мог никто.',
        'Скрипт сборки объявлял `pub fn test(b: *std.Build)`. В Zig `test` — ключевое слово. Этот файл никогда не компилировался; он к тому же не вызывал standardTargetOptions, передавал два аргумента в installArtifact и читал b.step как поле.',
        'Корень модуля — поверхность, которую импортирует каждый потребитель, — переэкспортировал всё через `pub use module.{ A, B as C };`. Это Rust. В Zig нет ни `use`, ни `as`, так что корень тоже никогда не был правильным Zig.',
        'Четыре файла внутри src/ импортировали "src/x.zig", что разрешается в src/src/x.zig.',
        'Шесть из этих реэкспортов называли символы, которых их модуль не экспортирует.',
        'Один файл всё ещё использовал std.io.getStdOut, убранный в 0.15.',
      ] },
      { kind: 'p', text: 'Пять блоков в форме Rust стали шестьюдесятью семью обычными реэкспортами Zig с сохранёнными псевдонимами, и пакет впервые в своей жизни собирается и проходит тесты на 0.15.2. Ценность этого дополнения не в починке, а в арифметике: обследованы три пакета, три оказались непригодны к использованию, и в каждом случае причина, по которой этого не знали, была одна — ни один воркфлоу ни разу не спросил.' },
    ],
  },
}

// The sequel to greenCiUnusable, and it only exists because that post's open
// questions got answered. The numbers are from the CI logs of the three
// repositories named; the pull requests are linked with their states.
const repairDoesNotPropagate: Post = {
  slug: 'a-repair-reaches-only-the-copy-it-lands-in',
  title: 'Sixteen defects fixed, zero of them reached the consumer',
  summary:
    'Two repositories carried the same six files under the same names. Repairing one changed nothing downstream, and no instrument in either could report why — because each copy compiles entirely on its own.',
  date: '2026-08-12',
  readingMinutes: 7,
  tags: ['Zig', 'Modularity', 'CI', 'Verification'],
  receipts: [
    { label: 'zig-golden-float #97 — 16 defects repaired · MERGED 2026-08-11', href: 'https://github.com/gHashTag/zig-golden-float/pull/97' },
    { label: 'zig-hdc #3 — one implementation, CI green · MERGED 2026-08-12', href: 'https://github.com/gHashTag/zig-hdc/pull/3' },
    { label: 'zig-hdc #2 — the earlier attempt, closed as superseded', href: 'https://github.com/gHashTag/zig-hdc/pull/2' },
  ],
  openQuestions: [
    'gHashTag/trinity, the consumer that started this, is still red. Its pin predates the repair and its own build has other causes, so nothing here claims that chain is finished.',
    'Listing re-exported names one by one has a cost this post does not pretend away: a symbol added upstream does not appear downstream until somebody adds it. usingnamespace, which would have avoided that, was removed in Zig 0.15.',
    'Whether the eighteen files that stayed behind should also live upstream was not decided. They have no counterpart there today; that is a fact about today, not an argument.',
  ],
  body: [
    { kind: 'p', text: 'I spent a night repairing sixteen defects in a package, watched its CI go green for the first time in its life, re-pinned the package that depends on it — and the consumer did not improve by a single error. Not one.' },
    { kind: 'p', text: 'The first explanation to reach for is a stale artefact. It was not that: pinning the exact merge commit produced the same hash the CDN had already served, so the bytes arriving were the repaired bytes.' },
    { kind: 'h', text: 'Both repositories owned the same files' },
    { kind: 'p', text: 'The consumer carried its own src/vsa/core.zig, common.zig, concurrency.zig, 10k_vsa.zig, hrr.zig and fpga_bind.zig. So did the package below it. Same names, same purpose, separate files, edited independently since the migration that split them apart.' },
    { kind: 'quote', text: 'The fixes went into different files with the same names. Nothing was wrong with the repair; it simply landed somewhere else.' },
    { kind: 'p', text: 'That is why no instrument reported it. Each copy compiles on its own. The package below went green because its copies were repaired; the consumer stayed red because its copies were not; and neither build has any way to notice that the other exists.' },
    { kind: 'h', text: 'The decision was arithmetic, not taste' },
    { kind: 'p', text: 'Choosing which copy to keep looks like a judgement call, and it stopped being one after five minutes of measurement: comparing the two public surfaces symbol by symbol, they are identical apart from a single constant. Neither is more capable. Nothing is lost by keeping either — so the direction follows the dependency that already exists, and the copies that build and pass 267 tests win over the copies that do not.' },
    { kind: 'p', text: 'Each duplicated file became a re-export rather than a deletion. Twenty-three relative imports across the consumer keep working unchanged, nothing else in the tree moves, and re-divergence stops being discouraged and becomes impossible: there is one implementation behind the path now.' },
    { kind: 'h', text: 'What the deduplication then exposed' },
    { kind: 'p', text: 'With one implementation in place and refAllDeclsRecursive forcing the whole public surface through the compiler, three more things surfaced, none of them caused by the change:' },
    { kind: 'ul', items: [
      'src/vsa.zig re-exported concurrency.LockFreePool, a name that has never existed in either copy. It referred to nothing, and nothing complained, because lazy analysis never asked what it pointed at.',
      'The pin predated the repair, so the sixteen fixed defects were still arriving through the dependency.',
      'text_encoding.zig passed an allocator to bundle2 and to add at nine call sites, against an API that had moved without it, and bound a const where add needs a mutable pointer.',
    ] },
    { kind: 'p', text: 'Every one of those had been in the repository for as long as the files had, invisible for the same reason: nothing referenced them, so nothing compiled them.' },
    { kind: 'h', text: 'The general form' },
    { kind: 'p', text: 'Parnas gave the criterion in 1972 and the reason he gave was changeability: each design decision should have exactly one home. The corollary is arithmetic. A decision living in n places must be repaired n times; the repairs do not propagate; and no instrument inside either copy reports the omission, because each compiles or fails entirely on its own.' },
    { kind: 'p', text: 'So divergence is not a risk that duplication carries. It is what duplication is. The question a copy raises is not whether the two will drift but how long before somebody notices, and the answer here was four months and a consumer that could not build.' },
    { kind: 'p', text: 'None of which makes vendoring wrong. A pinned copy is a deliberate trade — insulation from an upstream you do not control, paid for in repairs you now owe twice — and it is defensible when it is chosen and written down. What has no defence is duplication nobody decided on, which is exactly what a migration leaves behind when it copies rather than moves.' },
  ],
  published: true,
  ru: {
    title: 'Шестнадцать дефектов исправлены, до потребителя не дошёл ни один',
    summary:
      'Два репозитория несли одни и те же шесть файлов под одними именами. Починка одного не изменила ничего внизу по цепочке, и ни один прибор не мог сказать почему — потому что каждая копия компилируется сама по себе.',
    openQuestions: [
      'gHashTag/trinity, потребитель, с которого всё началось, всё ещё красный. Его закрепление старше починки, и у его сборки есть другие причины, так что ничто здесь не утверждает, что цепочка завершена.',
      'Перечисление реэкспортируемых имён поимённо имеет цену, и этот пост её не прячет: символ, добавленный наверху, не появится внизу, пока его туда не добавят. usingnamespace, который избавил бы от этого, убран в Zig 0.15.',
      'Должны ли восемнадцать оставшихся файлов тоже жить наверху — не решено. Сегодня у них там нет соответствия; это факт о сегодня, а не аргумент.',
    ],
    body: [
      { kind: 'p', text: 'Я провёл ночь, исправляя шестнадцать дефектов в пакете, увидел, как его CI впервые в жизни позеленел, перезакрепил пакет, который от него зависит, — и у потребителя не убавилось ни одной ошибки. Ни одной.' },
      { kind: 'p', text: 'Первое объяснение, к которому тянется рука, — устаревший архив. Дело не в нём: закрепление точного коммита слияния дало тот же хеш, что CDN уже отдавал, значит приходили именно починенные байты.' },
      { kind: 'h', text: 'Оба репозитория владели одними и теми же файлами' },
      { kind: 'p', text: 'У потребителя были свои src/vsa/core.zig, common.zig, concurrency.zig, 10k_vsa.zig, hrr.zig и fpga_bind.zig. И у пакета под ним — тоже. Одинаковые имена, одинаковое назначение, разные файлы, правившиеся независимо с того переноса, который их разделил.' },
      { kind: 'quote', text: 'Правки легли в разные файлы с одинаковыми именами. С починкой всё было в порядке — она просто оказалась не там.' },
      { kind: 'p', text: 'Поэтому ни один прибор об этом не сообщил. Каждая копия компилируется сама по себе. Пакет внизу позеленел, потому что починили его копии; потребитель остался красным, потому что его — нет; и ни у одной сборки нет способа заметить, что вторая вообще существует.' },
      { kind: 'h', text: 'Решение было арифметикой, а не вкусом' },
      { kind: 'p', text: 'Выбор, какую копию оставить, выглядит как суждение — и перестаёт им быть после пяти минут измерения: если сверить обе публичные поверхности символ за символом, они совпадают с точностью до одной константы. Ни одна не богаче. Терять нечего ни при каком выборе — поэтому направление задаёт уже существующая зависимость, и копии, которые собираются и проходят 267 тестов, побеждают копии, которые не собираются.' },
      { kind: 'p', text: 'Каждый дублирующийся файл стал реэкспортом, а не удалением. Двадцать три относительных импорта у потребителя продолжают работать как работали, остальное дерево не двигается, а повторное расхождение перестаёт быть нежелательным и становится невозможным: за путём теперь одна реализация.' },
      { kind: 'h', text: 'Что вскрылось после развязки' },
      { kind: 'p', text: 'Когда реализация осталась одна, а refAllDeclsRecursive прогнал через компилятор всю публичную поверхность, всплыли ещё три вещи — и ни одна из них не вызвана этой правкой:' },
      { kind: 'ul', items: [
        'src/vsa.zig реэкспортировал concurrency.LockFreePool — имя, которого никогда не было ни в одной копии. Оно указывало в никуда, и никто не возражал, потому что ленивый анализ ни разу не спросил, куда именно.',
        'Закрепление было старше починки, поэтому шестнадцать исправленных дефектов по-прежнему приходили через зависимость.',
        'text_encoding.zig передавал аллокатор в bundle2 и в add в девяти местах — API уехал без него, — и связывал const там, где add требует изменяемый указатель.',
      ] },
      { kind: 'p', text: 'Всё это лежало в репозитории ровно столько же, сколько сами файлы, и было невидимо по одной причине: на это никто не ссылался, значит это не компилировалось.' },
      { kind: 'h', text: 'Общая форма' },
      { kind: 'p', text: 'Парнас сформулировал критерий в 1972 году, и причина у него была именно изменяемость: у каждого проектного решения должен быть ровно один дом. Следствие — арифметическое. Решение, живущее в n местах, требует n починок; починки не распространяются; и ни один прибор внутри любой из копий не сообщит о пропуске, потому что каждая компилируется или падает сама по себе.' },
      { kind: 'p', text: 'Значит расхождение — не риск, который несёт дублирование. Расхождение и есть дублирование. Копия ставит вопрос не о том, разойдутся ли двое, а о том, через сколько это заметят; здесь ответ — четыре месяца и потребитель, который не собирался.' },
      { kind: 'p', text: 'Ничто из этого не делает вендоринг неправильным. Закреплённая копия — осознанный размен: изоляция от чужого репозитория, за которую платят починками в двойном размере, — и он защитим, когда выбран и записан. Не имеет защиты дублирование, о котором никто не принимал решения, — а именно его оставляет за собой перенос, который копирует вместо того, чтобы перемещать.' },
    ],
  },
}

const zeroOfSixHundredForty: Post = {
  slug: 'a-suite-that-runs-nothing-exits-zero',
  title: 'Zero of six hundred and forty',
  summary:
    'A package declared 640 tests and ran none of them, and the exit code was 0. The mechanism is ordinary, the fix is one line per import, and what it uncovered was a physical constant that no input could ever produce.',
  date: '2026-08-12',
  readingMinutes: 9,
  tags: ['verification', 'zig', 'vacuity'],
  receipts: [
    { label: 'zig-golden-float #98 — the unresolvable import, merged', href: 'https://github.com/gHashTag/zig-golden-float/pull/98' },
    { label: 'zig-golden-float #99 — export packed_vsa, submitted', href: 'https://github.com/gHashTag/zig-golden-float/pull/99' },
    { label: 'zig-physics #4 — 0 tests were running out of 640, submitted', href: 'https://github.com/gHashTag/zig-physics/pull/4' },
    { label: 'zig-physics #3 — the Barbero–Immirzi range, open', href: 'https://github.com/gHashTag/zig-physics/issues/3' },
    { label: 'trinity-training #1 — no test step existed, submitted', href: 'https://github.com/gHashTag/trinity-training/pull/1' },
  ],
  openQuestions: [
    'Coverage after the fix is partial and I have not measured how partial. In zig-physics 254 tests became reachable out of 640 declared; the remaining 386 live in files that no root reaches, and I have not established whether they would pass.',
    'The Barbero–Immirzi projection is refuted, not repaired. Choosing a different mapping from E8 coordinates to γ is a physics decision, and any mapping I picked would be fitted to the assertion it had to satisfy.',
    'trinity-training builds and its five module roots run tests on the target toolchain, but those roots do not reach all 104 files. I report the count CI produces, not the 672 declared.',
    'One package, zig-knowledge-graph, is still unusable: three files importing four that do not exist. The four exist upstream; the shim is not written yet.',
  ],
  published: true,
  body: [
    { kind: 'p', text: 'The line that matters in this whole piece is four words long, and a compiler printed it:' },
    { kind: 'code', text: '$ zig test src/root.zig\nAll 0 tests passed.' },
    { kind: 'p', text: 'There are 640 test blocks in that repository, spread over 87 files. None of them ran. The exit code was 0, the build step was green, and every gate reading that exit code was correct to pass it.' },
    { kind: 'h', text: 'How a test suite runs nothing' },
    { kind: 'p', text: 'Zig analyses a top-level declaration only when something references it. Each physics domain in that package has a root file, and each root file says exactly this:' },
    { kind: 'code', text: 'pub const formulas = @import("formulas.zig");' },
    { kind: 'p', text: 'Nothing referenced `formulas`. So the declaration was never analysed, so `formulas.zig` was never part of the compilation, so its test blocks did not exist — not skipped, not failed, absent. The same holds for anything those files import in turn, all the way down.' },
    { kind: 'p', text: 'The repair is one reference per import:' },
    { kind: 'code', text: 'test {\n    _ = formulas;\n}' },
    { kind: 'p', text: 'Nine files needed it. The measurement moved from "All 0 tests passed" to 253 passed, 1 skipped, 254 total. The one that could not pass is the subject of the last section.' },
    { kind: 'h', text: 'Why nothing had asked' },
    { kind: 'p', text: 'I swept five packages this week. Not one of them had a workflow that runs `zig build`. That is the whole explanation, and it is duller than the alternatives — no clever bug, no race, no version skew. The compiler was never asked the question, so it never gave the answer.' },
    {
      kind: 'table',
      head: ['Package', 'What stopped it', 'Where it stopped'],
      rows: [
        ['zig-half', 'Six faults; the module root was written in Rust syntax', 'Never compiled'],
        ['zig-physics', 'The manifest was JSON, not ZON', 'Line 1, column 7'],
        ['trinity-training', 'Dependency pinned to 0.2.0; upstream is 2.1.0', 'Before compilation, at fetch'],
        ['zig-knowledge-graph', 'No build script; dependency declared without a hash', 'Nothing to run'],
        ['zig-hdc', 'An import path that escapes the module root', 'Only when finally exported'],
      ],
    },
    { kind: 'p', text: 'Five packages, five unusable by anybody, and the reason is identical every time. The manifest error in zig-physics is the clearest: `{.name: "zig-physics", version: "0.1.0"}` is JSON. ZON is not JSON. `zig build` stopped at the first line and never reached a single one of the 87 source files behind it.' },
    { kind: 'h', text: 'One token, underneath all of it' },
    { kind: 'p', text: 'The last package took the longest because its failure was one level up. A file called `vsa_jit.zig` could not be exported, and five separate roots in another repository depended on it. The blocker turned out to be a single import:' },
    { kind: 'code', text: 'const arm64 = @import("../../jit_arm64.zig");' },
    { kind: 'p', text: 'From `src/vm/`, that path leaves the module root. It cannot resolve — not on my machine, not in CI, not anywhere, and not at any point in the file\'s history. `jit_arm64.zig` was sitting in the same directory the whole time. The fix is deleting five characters.' },
    { kind: 'p', text: 'It survived because nothing exported the file that contained it. This is the part worth keeping: **adding an export is a verification act.** It moves code from present to reachable, and reachable is the only category a compiler checks. The export in that pull request is the durable half of the change; the path fix alone would rot the same way.' },
    { kind: 'h', text: 'Five copies, and the wrong one compiled' },
    { kind: 'p', text: 'That file exists five times across three repositories — twice in the upstream package, once in each of two consumers. I expected the copy that compiled to be the authoritative one. It was the stale one.' },
    { kind: 'p', text: 'The stale copy called a two-argument `dotProduct` and read a plain field. The copy that failed to compile called the three-argument form and unwrapped an optional — because it had been updated for a newer dependency, and then the two files it needed were left behind in the migration. It compiled nowhere, and it was the newer of the two.' },
    { kind: 'p', text: 'So "it builds" tells you a copy agrees with the dependency sitting next to it. It does not tell you which copy should win. Deciding by build result would have propagated the older interface into the newer code, and the build would have gone green on the way.' },
    { kind: 'h', text: 'What the tests found once they could run' },
    { kind: 'p', text: 'One test failed the moment it became reachable: a prediction of the Barbero–Immirzi parameter, the coupling that fixes the area spectrum in loop quantum gravity. The assertion is that γ lands between 0.1 and 0.5, which is the right physics — entropy matching for black holes puts it near 0.2375.' },
    { kind: 'p', text: 'The projection computes γ from two coordinates of an E8 root, as |c₄| + |c₅| scaled by φ⁻¹. But every E8 root is a permutation of (±1, ±1, 0⁶) or (±½)⁸ with an even number of minus signs, so that sum is 0, 1 or 2 and nothing else. The image of the function is three numbers:' },
    {
      kind: 'table',
      head: ['|c₄| + |c₅|', 'γ produced', 'inside (0.1, 0.5)?'],
      rows: [
        ['0', '0.436992 — the fallback branch', 'yes'],
        ['1', '0.618034', 'no'],
        ['2', '1.236068', 'no'],
      ],
    },
    { kind: 'p', text: 'The target, 0.2375, is not among them and cannot be. The only admissible value is the fallback taken when both coordinates are zero — the answer is physical exactly when the projection has no input.' },
    { kind: 'p', text: 'No test run was needed to establish that. The domain is a finite structured set, so the image can be computed directly and compared with the specified range; the ranges are disjoint, and that is a proof, not a sample. It is worth naming as a technique, because it is cheaper than testing and strictly stronger: when the reachable range misses the admissible one, no input passes.' },
    { kind: 'p', text: 'I filed it and marked the test skipped with a pointer, rather than deleting it or widening the bound. The assertion is correct and the projection is what has to change. Writing a replacement formula would mean fitting it to the assertion it must satisfy — a model that agrees with its own test by construction, which is the thing this whole service exists to refuse.' },
    { kind: 'h', text: 'The instrument lied in both directions' },
    { kind: 'p', text: 'Three times in one session my local toolchain reported something false about these repositories, and it is worth being precise about the direction, because only one of the three is the failure people expect.' },
    { kind: 'p', text: 'Twice it raised a false alarm: `testing.refAllDeclsRecursive` and `std.time.timestamp` both exist in the 0.15.2 these packages target and were removed afterwards, so a local 0.16 reported failures that do not exist for the target. Once it gave false assurance in the other direction: code reaching for the C allocator passes on macOS, where libc is always linked, and fails on the Linux target with "C allocator is only available when linking against libc". A CI run caught that one; nothing local would have.' },
    { kind: 'p', text: 'Two false alarms and one false assurance, from one ruler, in one afternoon. The rule that follows is not "trust CI" — it is that a measurement is uninterpretable without naming the instrument, and that a differing instrument errs in both directions rather than conservatively in one.' },
    { kind: 'h', text: 'What this changes about the free check' },
    { kind: 'p', text: 'The structural run on this site already refuses to treat an empty result as a pass — an empty flop count fails rather than reading as zero. This week added the sharper version of the same rule to the packages it now watches: a step that fails when fewer than 200 tests run, because a suite that runs nothing also exits 0, and no verdict distinguishes the two.' },
    { kind: 'p', text: 'That is the general shape. A verdict is one bit and cannot carry its own vacuity. Whenever a check can pass by not happening, the count of what happened has to be measured separately and gated on — and if you have never seen your own gate fail, you do not yet know that it can.' },
  ],
  ru: {
    title: 'Ноль из шестисот сорока',
    summary:
      'Пакет объявлял 640 тестов и не выполнил ни одного, а код возврата был 0. Механизм самый обыкновенный, починка — одна строка на импорт, а под ней обнаружилась физическая константа, которую не даёт ни один вход.',
    openQuestions: [
      'Покрытие после починки частичное, и насколько — я не измерял. В zig-physics стали досягаемы 254 теста из 640 объявленных; оставшиеся 386 лежат в файлах, до которых не дотягивается ни один корень, и прошли бы они — неизвестно.',
      'Проекция Барберо–Иммирци опровергнута, а не исправлена. Выбор другого отображения координат E8 в γ — решение физическое, и любое, которое выбрал бы я, оказалось бы подогнано под то самое утверждение, которому обязано удовлетворять.',
      'trinity-training собирается, и пять корней его модулей выполняют тесты на целевом тулчейне, но эти корни не покрывают все 104 файла. Я привожу число, которое выдаёт CI, а не 672 объявленных.',
      'Один пакет, zig-knowledge-graph, по-прежнему непригоден: три файла импортируют четыре несуществующих. Все четыре есть в апстриме, прослойка ещё не написана.',
    ],
    body: [
      { kind: 'p', text: 'Главная строка всего текста состоит из четырёх слов, и напечатал её компилятор:' },
      { kind: 'code', text: '$ zig test src/root.zig\nAll 0 tests passed.' },
      { kind: 'p', text: 'В том репозитории 640 тестовых блоков в 87 файлах. Не выполнился ни один. Код возврата — 0, шаг сборки зелёный, и каждый гейт, читавший этот код, пропустил его совершенно правильно.' },
      { kind: 'h', text: 'Как набор тестов не выполняет ничего' },
      { kind: 'p', text: 'Zig анализирует объявление верхнего уровня только тогда, когда на него кто-то ссылается. У каждого физического домена в пакете есть корневой файл, и в каждом написано ровно это:' },
      { kind: 'code', text: 'pub const formulas = @import("formulas.zig");' },
      { kind: 'p', text: 'На `formulas` не ссылался никто. Значит, объявление не анализировалось, значит, `formulas.zig` не входил в компиляцию, значит, его тестовых блоков не существовало — не пропущены, не упали, а отсутствуют. То же верно и для всего, что эти файлы импортируют дальше, до самого низа.' },
      { kind: 'p', text: 'Починка — одна ссылка на импорт:' },
      { kind: 'code', text: 'test {\n    _ = formulas;\n}' },
      { kind: 'p', text: 'Понадобилась она в девяти файлах. Измерение сдвинулось с «All 0 tests passed» до 253 прошедших, 1 пропущенного, 254 всего. Тот, что пройти не мог, — предмет последнего раздела.' },
      { kind: 'h', text: 'Почему никто не спросил' },
      { kind: 'p', text: 'За эту неделю я обследовал пять пакетов. Ни у одного не было воркфлоу, запускающего `zig build`. Это и есть всё объяснение, и оно скучнее любой альтернативы: ни хитрого бага, ни гонки, ни расхождения версий. Компилятору просто не задали вопрос — он и не дал ответа.' },
      {
        kind: 'table',
        head: ['Пакет', 'Что остановило', 'Где остановилось'],
        rows: [
          ['zig-half', 'Шесть дефектов; корень модуля написан синтаксисом Rust', 'Не компилировался никогда'],
          ['zig-physics', 'Манифест на JSON, а не на ZON', 'Строка 1, столбец 7'],
          ['trinity-training', 'Зависимость закреплена на 0.2.0, апстрим — 2.1.0', 'До компиляции, на загрузке'],
          ['zig-knowledge-graph', 'Нет сборочного скрипта; зависимость без хеша', 'Запускать нечего'],
          ['zig-hdc', 'Путь импорта, уходящий выше корня модуля', 'Только когда наконец экспортировали'],
        ],
      },
      { kind: 'p', text: 'Пять пакетов, пять непригодных к использованию кем бы то ни было, и причина каждый раз одна и та же. Ошибка манифеста в zig-physics — самая наглядная: `{.name: "zig-physics", version: "0.1.0"}` — это JSON. ZON — не JSON. `zig build` остановился на первой строке и не дошёл ни до одного из 87 файлов за ней.' },
      { kind: 'h', text: 'Один токен в основании всего' },
      { kind: 'p', text: 'Последний пакет занял больше всего времени, потому что его отказ был уровнем выше. Файл `vsa_jit.zig` не удавалось экспортировать, а от него зависели пять корней в другом репозитории. Виновником оказался единственный импорт:' },
      { kind: 'code', text: 'const arm64 = @import("../../jit_arm64.zig");' },
      { kind: 'p', text: 'Из `src/vm/` этот путь выходит за корень модуля. Он не может разрешиться — ни у меня, ни в CI, ни где-либо ещё, и ни в один момент истории файла. `jit_arm64.zig` всё это время лежал в той же папке. Починка — удалить пять символов.' },
      { kind: 'p', text: 'Он уцелел потому, что содержащий его файл никто не экспортировал. Вот что стоит унести с собой: **добавление экспорта — это акт верификации.** Оно переводит код из «присутствует» в «досягаем», а досягаемое — единственная категория, которую компилятор проверяет. Экспорт в том PR — долговечная половина правки; починка пути без него сгнила бы точно так же.' },
      { kind: 'h', text: 'Пять копий, и компилировалась не та' },
      { kind: 'p', text: 'Этот файл существует пять раз в трёх репозиториях — дважды в апстриме и по разу у двух потребителей. Я ожидал, что авторитетной окажется та копия, которая компилируется. Она оказалась отставшей.' },
      { kind: 'p', text: 'Отставшая копия вызывала двухаргументный `dotProduct` и читала обычное поле. Копия, которая не компилировалась, вызывала трёхаргументную форму и разворачивала optional — потому что её обновили под новую зависимость, а два нужных ей файла при переносе оставили позади. Она не собиралась нигде — и была новее.' },
      { kind: 'p', text: 'То есть «оно собирается» говорит лишь о том, что копия согласована с зависимостью, лежащей рядом. О том, какая копия должна победить, оно не говорит ничего. Решение по результату сборки протащило бы старый интерфейс в новый код — и сборка по дороге была бы зелёной.' },
      { kind: 'h', text: 'Что тесты нашли, когда смогли выполниться' },
      { kind: 'p', text: 'Один тест упал в ту же секунду, как стал досягаем: предсказание параметра Барберо–Иммирци — той связи, что фиксирует спектр площади в петлевой квантовой гравитации. Утверждение — что γ лежит между 0.1 и 0.5, и это верная физика: согласование энтропии чёрных дыр даёт около 0.2375.' },
      { kind: 'p', text: 'Проекция считает γ из двух координат корня E8 как |c₄| + |c₅|, умноженное на φ⁻¹. Но каждый корень E8 — это перестановка (±1, ±1, 0⁶) либо (±½)⁸ с чётным числом минусов, поэтому сумма равна 0, 1 или 2 и ничему больше. Область значений функции — три числа:' },
      {
        kind: 'table',
        head: ['|c₄| + |c₅|', 'полученная γ', 'внутри (0.1, 0.5)?'],
        rows: [
          ['0', '0.436992 — аварийная ветвь', 'да'],
          ['1', '0.618034', 'нет'],
          ['2', '1.236068', 'нет'],
        ],
      },
      { kind: 'p', text: 'Цели 0.2375 среди них нет и быть не может. Единственное допустимое значение — запасная ветвь, срабатывающая, когда обе координаты нулевые: ответ физичен ровно тогда, когда проекции нечего проецировать.' },
      { kind: 'p', text: 'Чтобы это установить, прогон не нужен. Область определения — конечное структурированное множество, поэтому образ вычисляется напрямую и сравнивается с заданным диапазоном; диапазоны не пересекаются, и это доказательство, а не выборка. Приём стоит назвать отдельно, потому что он дешевле тестирования и строго сильнее: если достижимая область значений не пересекает допустимую, не проходит ни один вход.' },
      { kind: 'p', text: 'Я завёл issue и пометил тест пропущенным со ссылкой — не удалил и не расширил границу. Утверждение верное, менять надо проекцию. Написать замену формулы означало бы подогнать её под то утверждение, которому она обязана удовлетворять, — получилась бы модель, согласная с собственным тестом по построению, а именно от этого вся услуга и отказывается.' },
      { kind: 'h', text: 'Прибор соврал в обе стороны' },
      { kind: 'p', text: 'Трижды за одну сессию локальный тулчейн сообщил об этих репозиториях неправду, и направление стоит назвать точно, потому что только одно из трёх — та ошибка, которой ждут.' },
      { kind: 'p', text: 'Дважды это была ложная тревога: `testing.refAllDeclsRecursive` и `std.time.timestamp` существуют в 0.15.2, на которую эти пакеты нацелены, и удалены позже, — локальный 0.16 сообщал об отказах, которых для цели нет. Один раз — ложное спокойствие в обратную сторону: код, тянущийся к C-аллокатору, проходит на macOS, где libc линкуется всегда, и падает на Linux с «C allocator is only available when linking against libc». Это поймал прогон CI; локально не поймало бы ничто.' },
      { kind: 'p', text: 'Две ложные тревоги и одно ложное спокойствие, от одного прибора, за один вечер. Отсюда следует не «доверяйте CI», а то, что измерение неинтерпретируемо без названного прибора и что отличающийся прибор ошибается в обе стороны, а не консервативно в одну.' },
      { kind: 'h', text: 'Что это меняет в бесплатной проверке' },
      { kind: 'p', text: 'Структурный прогон на этом сайте уже отказывается считать пустой результат прохождением: пустой счёт триггеров — отказ, а не ноль. На этой неделе к пакетам, за которыми он теперь следит, добавилась более острая версия того же правила: шаг падает, если выполнилось меньше 200 тестов, — потому что набор, не выполнивший ничего, тоже завершается нулём, и никакой вердикт этих двух случаев не различает.' },
      { kind: 'p', text: 'Такова общая форма. Вердикт — это один бит, и собственную пустоту он в себе не несёт. Везде, где проверка может пройти, не состоявшись, счётчик состоявшегося приходится мерить отдельно и на нём же ставить гейт, — а если вы никогда не видели, как ваш гейт падает, вы ещё не знаете, что он умеет.' },
    ],
  },
}

const eachHalfImportedTheOther: Post = {
  slug: 'each-half-imported-the-other',
  title: 'Each half imported the other',
  summary:
    'One directory was split across two repositories and both kept flat imports of the other. Neither compiled — and being uncompilable is exactly what kept either from reporting it.',
  date: '2026-08-12',
  readingMinutes: 8,
  tags: ['verification', 'zig', 'dependencies'],
  receipts: [
    { label: 'zig-knowledge-graph #2 — the near half, merged', href: 'https://github.com/gHashTag/zig-knowledge-graph/pull/2' },
    { label: 'zig-knowledge-graph #1 — the split, open', href: 'https://github.com/gHashTag/zig-knowledge-graph/issues/1' },
    { label: 'zig-knowledge-graph #3 — the two binaries, open', href: 'https://github.com/gHashTag/zig-knowledge-graph/issues/3' },
    { label: 'zig-golden-float #99 — the far half, merged', href: 'https://github.com/gHashTag/zig-golden-float/pull/99' },
    { label: 'trinity-training #2 — the self-invalidating pin, merged', href: 'https://github.com/gHashTag/trinity-training/pull/2' },
  ],
  openQuestions: [
    'Only the library was made to build. `kg_cli` and `kg_server` are a Zig 0.14 to 0.15 migration across roughly 1300 lines — filed as #3, not attempted here, and until it is done those two tools remain what they have always been: unrunnable.',
    'I do not know how many other pairs in this fleet have the same shape. The one I found, I found by accident, while fixing something else.',
    'The library builds and its seven tests pass. Seven is a small number for a graph store, and nothing here establishes that the seven cover anything in particular.',
  ],
  published: true,
  body: [
    { kind: 'p', text: 'A package with three source files would not build. Its manifest declared a dependency by URL with no hash, so the fetch could not start; there was no build script at all, so there was nothing to run if it had. Underneath both, four imports:' },
    { kind: 'code', text: 'const vsa         = @import("vsa.zig");\nconst hybrid      = @import("hybrid.zig");\nconst packed_vsa  = @import("packed_vsa.zig");\nconst packed_trit = @import("packed_trit.zig");' },
    { kind: 'p', text: 'None of those four files are in that repository. They are in a different one — the numeric library it depends on. And that library\u2019s own `packed_vsa.zig` opened with this:' },
    { kind: 'code', text: 'const Entity = @import("knowledge_graph.zig").Entity;' },
    { kind: 'p', text: 'Which is not there either. It is back in the first repository.' },
    { kind: 'h', text: 'The shape of it' },
    { kind: 'p', text: 'One directory was divided into two repositories, and on both sides the flat relative imports were left exactly as they were, each now pointing at a sibling that had moved to the other side. The result is symmetric: neither half compiles, and each is missing precisely what the other kept.' },
    { kind: 'p', text: 'The part worth naming is why it lasted. **Being uncompilable is what stopped either half from reporting the other missing.** A dangling import is found by a compiler; a compiler runs on a package that builds; neither package built. The fault disabled the only instrument that could have observed it, and so it stayed dormant — not found late because it was subtle, but not found at all, because nothing that could see it was able to start.' },
    { kind: 'p', text: 'It surfaced by accident. I was exporting an unrelated declaration in the numeric library, and exporting it made the compiler analyse a file it had never analysed. Four more broken paths fell out immediately, and one of them named the other repository.' },
    { kind: 'h', text: 'A pin that breaks itself, demonstrated twice' },
    { kind: 'p', text: 'A sibling package had this in its manifest:' },
    { kind: 'code', text: '.url  = "…/zig-golden-float/archive/refs/heads/main.tar.gz",\n.hash = "golden_float-0.2.0-h7LKhdEX…",' },
    { kind: 'p', text: 'A moving reference and a content hash. Upstream was at 2.1.0. The pin had been broken since the first merge after it was written, and the failure lands at fetch — before a compiler reads anything — so it presents as an unbuildable package rather than as a stale dependency.' },
    { kind: 'p', text: 'I re-pinned it, and it went green. Then I merged one commit upstream, and it broke again inside the hour. That second break is the useful part: it turns an argument into a demonstration. A reference that keeps moving beside a hash that keeps asserting is not a pin, it is a scheduled failure. Both packages now pin to a commit tarball.' },
    { kind: 'h', text: 'My own guard measured itself' },
    { kind: 'p', text: 'Last week I added a step that refuses a test suite running fewer than 200 tests, because a suite that runs nothing also exits 0. It failed. The suite was green.' },
    { kind: 'p', text: 'The step ran `zig test src/root.zig` directly, which bypasses the `link_libc` the build script sets. On Linux that is an immediate compile error, so no count was parsed, so the guard reported the suite as empty — while the step directly above it had just run 253 tests successfully. The guard had stopped measuring the artefact and started measuring its own way of reaching it.' },
    { kind: 'p', text: 'The fix is one invocation, read twice: run `zig build test` once, `tee` it, take the exit code from the run and the count from the same output. A check that re-derives its input by a route the build does not take will eventually report on the route.' },
    { kind: 'h', text: 'A write that succeeded and a read that could not' },
    { kind: 'p', text: 'Making the library build surfaced a defect in it. Zig 0.15 changed `File.writer` to take a buffer. The save routine was written against the unbuffered interface — and after the type changed it still compiled, still ran, still returned success. The tail of every file it wrote stayed in memory.' },
    { kind: 'p', text: 'So `save()` reported having written a graph that `load()` could not read, and the call that reports success is the same call that loses the data. Nothing in the type system asks for the flush; the first component in a position to notice is the reader, and only if someone runs it.' },
    { kind: 'h', text: 'Where I was wrong' },
    { kind: 'p', text: 'When the two binaries failed to compile, I said in the pull request that these were artefacts of my local toolchain being 0.16 rather than the 0.15.2 the package targets — `std.io.getStdOut`, `ArrayList.init`, the `std.fs` reorganisation. I had been right about that three times already this week, which is presumably why I reached for it a fourth.' },
    { kind: 'p', text: 'CI on 0.15.2 reported the same errors. They are real: the binaries were written against 0.14 and never migrated. I corrected it in the next commit message and filed the migration as its own issue. Worth publishing rather than quietly amending, because the failure mode is specific and I expect to repeat it — a diagnosis that has been correct several times running stops being checked and starts being assumed.' },
    { kind: 'h', text: 'What it took' },
    {
      kind: 'table',
      head: ['', 'Before', 'After'],
      rows: [
        ['build.zig', 'did not exist', 'library module, per-root test target'],
        ['manifest', 'no fingerprint, dependency without a hash', 'ZON, fingerprint, pinned to a commit'],
        ['the four imports', 'files in another repository', 'the dependency module'],
        ['workflow', 'none', 'zig build + zig build test on 0.15.2'],
        ['tests', 'unrunnable', '7 passed'],
      ],
    },
    { kind: 'p', text: 'Seven tests is not much, and I would rather say so than let the green stand in for more than it is. What changed is narrower and worth stating exactly: a package that no one could depend on can now be depended on, and a compiler has read its source for the first time.' },
  ],
  ru: {
    title: 'Каждая половина импортировала другую',
    summary:
      'Одну папку разделили на два репозитория, и обе сохранили плоские импорты друг друга. Не компилировалась ни одна — и именно невозможность собраться мешала любой из них сообщить о проблеме.',
    openQuestions: [
      'Собрана только библиотека. `kg_cli` и `kg_server` — это миграция с Zig 0.14 на 0.15 примерно по 1300 строкам; заведена как #3, здесь не делалась, и до неё эти два инструмента остаются тем, чем были всегда: незапускаемыми.',
      'Сколько ещё пар во флоте имеют ту же форму — я не знаю. Найденную нашёл случайно, чиня совсем другое.',
      'Библиотека собирается, семь тестов проходят. Семь — немного для хранилища графа, и ничто здесь не говорит, что именно эти семь покрывают.',
    ],
    body: [
      { kind: 'p', text: 'Пакет из трёх файлов не собирался. Манифест объявлял зависимость по URL без хеша, поэтому загрузка не могла начаться; сборочного скрипта не было вовсе, так что запускать было бы нечего и в случае успеха. Под обоими — четыре импорта:' },
      { kind: 'code', text: 'const vsa         = @import("vsa.zig");\nconst hybrid      = @import("hybrid.zig");\nconst packed_vsa  = @import("packed_vsa.zig");\nconst packed_trit = @import("packed_trit.zig");' },
      { kind: 'p', text: 'Ни одного из этих четырёх файлов в том репозитории нет. Они в другом — в числовой библиотеке, от которой пакет зависит. А её собственный `packed_vsa.zig` начинался так:' },
      { kind: 'code', text: 'const Entity = @import("knowledge_graph.zig").Entity;' },
      { kind: 'p', text: 'Которого нет уже там. Он остался в первом репозитории.' },
      { kind: 'h', text: 'Форма' },
      { kind: 'p', text: 'Одну папку разделили на два репозитория, и с обеих сторон плоские относительные импорты оставили как были — теперь каждый смотрит на соседа, ушедшего на другую сторону. Итог симметричен: не компилируется ни одна половина, и каждой не хватает ровно того, что сохранила вторая.' },
      { kind: 'p', text: 'Назвать стоит другое — почему это держалось так долго. **Именно невозможность собраться мешала любой половине сообщить о пропаже другой.** Висячий импорт находит компилятор; компилятор работает на пакете, который собирается; не собирался ни один. Дефект отключил единственный прибор, способный его увидеть, и потому оставался спящим — не «нашли поздно, потому что тонко», а не нашли вообще, потому что ничто наблюдающее не могло запуститься.' },
      { kind: 'p', text: 'Всплыло случайно. Я экспортировал в числовой библиотеке постороннее объявление, и экспорт заставил компилятор проанализировать файл, которого он не анализировал никогда. Тут же выпали ещё четыре сломанных пути, и один из них назвал другой репозиторий.' },
      { kind: 'h', text: 'Привязка, которая ломает себя сама — показано дважды' },
      { kind: 'p', text: 'У соседнего пакета в манифесте было вот это:' },
      { kind: 'code', text: '.url  = "…/zig-golden-float/archive/refs/heads/main.tar.gz",\n.hash = "golden_float-0.2.0-h7LKhdEX…",' },
      { kind: 'p', text: 'Подвижная ссылка и хеш содержимого. Апстрим был на 2.1.0. Привязка была сломана с первого же мержа после её написания, а отказ приходится на загрузку — до того, как компилятор что-либо прочтёт, — поэтому выглядит она как несобираемый пакет, а не как устаревшая зависимость.' },
      { kind: 'p', text: 'Я перепривязал, стало зелено. Потом слил один коммит вверху — и оно сломалось снова, в тот же час. Этот второй слом и есть ценное: он превращает довод в демонстрацию. Ссылка, которая продолжает двигаться, рядом с хешем, который продолжает утверждать, — это не привязка, а отложенный отказ. Оба пакета теперь привязаны к архиву коммита.' },
      { kind: 'h', text: 'Мой собственный гейт мерил сам себя' },
      { kind: 'p', text: 'На прошлой неделе я добавил шаг, который отвергает набор тестов, если выполнилось меньше двухсот: набор, не выполнивший ничего, тоже завершается нулём. Шаг упал. Набор был зелёным.' },
      { kind: 'p', text: 'Шаг звал `zig test src/root.zig` напрямую, минуя `link_libc`, который выставляет сборочный скрипт. На Linux это немедленная ошибка компиляции — значит, счётчик не распарсился, значит, гейт объявил набор пустым, тогда как шагом выше только что успешно отработали 253 теста. Гейт перестал мерить артефакт и начал мерить собственный способ до него добраться.' },
      { kind: 'p', text: 'Починка — один запуск, прочитанный дважды: выполнить `zig build test`, пропустить через `tee`, взять код возврата из запуска и счётчик из того же вывода. Проверка, которая добывает свой вход маршрутом, отличным от сборочного, рано или поздно доложит о маршруте.' },
      { kind: 'h', text: 'Запись, которая удалась, и чтение, которое не смогло' },
      { kind: 'p', text: 'Сборка библиотеки вскрыла дефект уже в ней. Zig 0.15 сделал `File.writer` принимающим буфер. Процедура сохранения была написана под небуферизованный интерфейс — и после смены типа она по-прежнему компилировалась, выполнялась и возвращала успех. Хвост каждого записанного файла оставался в памяти.' },
      { kind: 'p', text: 'То есть `save()` докладывал, что записал граф, который `load()` прочитать не мог, — и вызов, сообщающий об успехе, есть тот же вызов, который теряет данные. Ничто в системе типов не требует сброса буфера; первым, кто в состоянии заметить, оказывается читатель — и только если его кто-нибудь запустит.' },
      { kind: 'h', text: 'Где я ошибся' },
      { kind: 'p', text: 'Когда два бинарника не собрались, я написал в pull request, что это артефакты моего локального 0.16 против целевой 0.15.2 — `std.io.getStdOut`, `ArrayList.init`, реорганизация `std.fs`. На этой неделе я уже трижды оказывался прав именно так, чем, видимо, и объясняется четвёртый раз.' },
      { kind: 'p', text: 'CI на 0.15.2 выдал те же ошибки. Они настоящие: бинарники написаны под 0.14 и не мигрированы. Я исправил это в следующем сообщении коммита и завёл миграцию отдельным issue. Публикую, а не правлю тихо, потому что механизм конкретный и я ожидаю его повторения: диагноз, оказавшийся верным несколько раз подряд, перестают проверять и начинают предполагать.' },
      { kind: 'h', text: 'Чего это стоило' },
      {
        kind: 'table',
        head: ['', 'Было', 'Стало'],
        rows: [
          ['build.zig', 'не существовал', 'модуль библиотеки, тест-цель на корень'],
          ['манифест', 'без отпечатка, зависимость без хеша', 'ZON, отпечаток, привязка к коммиту'],
          ['четыре импорта', 'файлы в другом репозитории', 'модуль зависимости'],
          ['воркфлоу', 'нет', 'zig build + zig build test на 0.15.2'],
          ['тесты', 'незапускаемы', '7 прошли'],
        ],
      },
      { kind: 'p', text: 'Семь тестов — немного, и я предпочту сказать это прямо, чем позволить зелёному означать больше, чем он означает. Изменилось узкое и стоит назвать точно: пакет, от которого никто не мог зависеть, теперь пригоден в зависимости, а компилятор впервые прочитал его исходники.' },
    ],
  },
}

export const posts: Post[] = [eachHalfImportedTheOther, zeroOfSixHundredForty, repairDoesNotPropagate, greenCiUnusable, scaleFieldWidth, openGigabitEthernet]

export const publishedPosts = () => posts.filter((p) => p.published)

export const postBySlug = (slug: string) => posts.find((p) => p.slug === slug)
