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


const goldenIdentity: Post = {
  slug: 'phi-identity-machine-checked',
  title: 'phi^2 + 1/phi^2 = 3, checked every way I could think of',
  summary:
    'An exact identity, six proof steps machine-verified, and a search over 1,476,000 candidates ' +
    'that found no other root \u2014 plus what the identity does not license.',
  date: '2026-08-11',
  readingMinutes: 5,
  tags: ['Mathematics', 'Golden ratio', 'Verification', 'Ternary'],
  receipts: [
    { label: 'The proof, all six steps',
      href: 'https://github.com/gHashTag/trinity/blob/main/docs/docs/math-foundations/proofs.md' },
    { label: 'Lucas numbers L(2n) \u2014 the family this belongs to (OEIS A000032)',
      href: 'https://oeis.org/A000032' },
    { label: 'Euclid, Elements VI, Definition 3 \u2014 where the ratio is first defined',
      href: 'https://mathcs.clarku.edu/~djoyce/java/elements/bookVI/defVI3.html' },
  ],
  openQuestions: [
    'This is the n=1 case of the standard Lucas identity phi^(2n) + phi^(-2n) = L(2n). It is ' +
    'textbook mathematics, cited here rather than claimed \u2014 Euclid defined the ratio and ' +
    'the identity follows from its quadratic.',
    'Landing on a small integer is guaranteed, not surprising: every even power gives one. ' +
    'phi^2+phi^-2 through phi^16+phi^-16 are 3, 7, 18, 47, 123, 322, 843, 2207.',
    'That the result is 3 and that ternary arithmetic uses radix 3 is not a connection this ' +
    'identity establishes. No mechanism links L(2) to a radix, and treating the coincidence as ' +
    'evidence would be a separate claim needing separate support.',
  ],
  body: [
    { kind: 'p', text:
      'The identity is two lines from the definition. What follows is what happened when I ' +
      'stopped trusting that and checked it mechanically instead.' },
    { kind: 'h', text: 'The identity' },
    { kind: 'code', text:
      'phi = (1 + sqrt(5)) / 2\nphi^2 = phi + 1        (the defining quadratic)\n' +
      '1/phi = phi - 1\n1/phi^2 = (phi-1)^2 = 2 - phi\n\n' +
      'phi^2 + 1/phi^2 = (phi + 1) + (2 - phi) = 3' },
    { kind: 'p', text:
      'phi cancels identically. This is exact algebra in Q(sqrt 5), not a numerical near-hit.' },
    { kind: 'h', text: 'Checked four ways' },
    { kind: 'ul', items: [
      'Decimal at 80 digits: the sum differs from 3 by 1e-79, which is the rounding of an irrational division and nothing else.',
      'mpmath at 60, 210 and 1000 digits: the difference is exactly 0.0 at every precision.',
      'sympy symbolically: simplify(phi**2 + 1/phi**2) returns the integer 3. There is no residual to hide at any precision.',
      'Every one of the six written steps verified independently \u2014 so the proof is not a correct conclusion reached by a broken argument.',
    ] },
    { kind: 'h', text: 'And the converse, which is the part worth having' },
    { kind: 'p', text:
      'Solving x^2 + 1/x^2 = 3 gives exactly four roots: phi, 1/phi, -phi, -1/phi. Clearing ' +
      'denominators gives x^4 - 3x^2 + 1, which factors as (x^2-x-1)(x^2+x-1).' },
    { kind: 'p', text:
      'Since the expression is invariant under x -> -x and under x -> 1/x, phi is the unique ' +
      'solution up to the expression\u2019s own symmetry group. The identity pins down phi ' +
      'rather than merely holding for it.' },
    { kind: 'p', text:
      'A numerical net was run as well \u2014 1,476,000 candidates of the form (p + q*sqrt(d))/r ' +
      'across p, q, d, r ranges \u2014 and produced no non-golden solution, as the degree-4 ' +
      'factorisation requires.' },
    { kind: 'h', text: 'What it does not license' },
    { kind: 'p', text:
      'The identity is logically equivalent to the definition, not additional to it: x^4-3x^2+1 ' +
      'factors into the two quadratics, so "x^2+1/x^2=3" and "x^2=x+1" are the same statement. ' +
      'It carries no information beyond how phi is defined.' },
    { kind: 'p', text:
      'And landing on a small integer is guaranteed. Every even power does: 3, 7, 18, 47, 123, ' +
      '322, 843, 2207 \u2014 the Lucas numbers. The 3 is L(2), the trace of phi^2 over the ' +
      'rationals. It is not a number phi happens to reach.' },
    { kind: 'p', text:
      'So the identity is exact, the proof is sound, phi is pinned down, and none of that is ' +
      'evidence for anything about radix 3. Those are four separate statements and only the ' +
      'first three are established here.' },
  ],
  published: true,
}

const benchReadout: Post = {
  slug: 'readout-that-cannot-be-misread',
  title: 'Four rules for a measurement rig whose readout cannot be misread',
  summary:
    'A readout whose mapping to state is unestablished is not an instrument \u2014 four rules ' +
    'written after a week of hardware debugging where the rig lied and the design was fine.',
  date: '2026-08-11',
  readingMinutes: 6,
  tags: ['FPGA', 'Hardware', 'Debugging', 'Measurement'],
  receipts: [
    { label: 'The rules, with the failures that produced each',
      href: 'https://github.com/gHashTag/trinity-fpga/blob/main/docs/HW_CAMPAIGN_AX7203_2026_07_30.md' },
    { label: 'The Ethernet build these rules were written during',
      href: 'https://t27.ai/#/blog/open-gigabit-ethernet-artix7' },
  ],
  openQuestions: [
    'These come from one board (AX7203, Artix-7) and one week. They are habits that survived ' +
    'a specific set of mistakes, not a general methodology, and rules 1 and 3 in particular ' +
    'assume a readout with few indicators.',
    'Rule 4 (A/B/A) costs a third run every time. Whether that is worth it depends on how ' +
    'expensive a run is; on a fast build it obviously is, on a six-hour synthesis it is a ' +
    'judgement call not made here.',
  ],
  body: [
    { kind: 'p', text:
      'Every rule below exists because I got a reading, believed it, and it was the rig talking ' +
      'rather than the design. None of them is about a particular chip.' },
    { kind: 'h', text: '1. Calibrate the readout before the experiment, never after' },
    { kind: 'p', text:
      'Drive a fixed asymmetric pattern and look at it. 4\u2019b0011 is the minimum useful one: ' +
      'it fixes both the polarity and the index mapping in a single observation.' },
    { kind: 'code', text:
      'active-HIGH : led0,led1 lit    led2,led3 dark\n' +
      'active-LOW  : led0,led1 dark   led2,led3 lit' },
    { kind: 'p', text:
      'What happened without it: a design drove led = {2\u2019b00, s2, s1} and the two hardwired ' +
      'zeros came back lit. The board is active-low, so "all four lit" meant all four bits zero ' +
      '\u2014 the opposite of the reading I first took. I concluded "both edges capture" when the ' +
      'data said neither does.' },
    { kind: 'quote', text:
      'A readout whose mapping to state is not established is not an instrument.' },
    { kind: 'h', text: '2. A sticky-OR cannot tell "never captured" from "captured zero"' },
    { kind: 'p', text: 'Both leave it at 0. Report AND as well as OR over the same window.' },
    { kind: 'table',
      head: ['OR', 'AND', 'state'],
      rows: [
        ['0', '0', 'stuck low'],
        ['1', '1', 'stuck high'],
        ['1', '0', 'toggling'],
        ['0', '1', 'impossible \u2014 a consistency check on the rig itself'],
      ] },
    { kind: 'p', text:
      'Initialise the AND register to 1 and the OR to 0. Then the AND leaving 1 also proves the ' +
      'clock ran, which is a second thing the OR cannot show. The fourth row is the useful one: ' +
      'it can never occur, so if it does, the rig is broken and not the design.' },
    { kind: 'h', text: '3. Numbering ambiguity silently inverts conclusions' },
    { kind: 'p', text:
      'Readings arrived as "LED 0 / 1 / 3 / 4", then "LED 1 / 2 / 3 / 4" \u2014 mixed 0-based and ' +
      '1-based with one index skipped. I mapped both to led[0..3] without noticing, and the two ' +
      'mappings give opposite answers to the question being asked.' },
    { kind: 'p', text: 'Design the readout so the answer does not depend on which indicator is which:' },
    { kind: 'ul', items: [
      'one indicator, distinguishable rates \u2014 dark, slow, fast \u2014 rather than positions',
      'or a serial pattern on one pin, read once and decoded unambiguously',
      'or ask for the reading explicitly: "which of the four leftmost, counting from the left, are lit"',
    ] },
    { kind: 'h', text: '4. A/B/A, always' },
    { kind: 'p', text:
      'Run the baseline, run the change, run the baseline again. If the two baselines disagree, ' +
      'the rig moved and the middle run means nothing. It costs a third run and it is the only ' +
      'thing that separates "the change did something" from "something changed".' },
    { kind: 'h', text: 'The one that stings' },
    { kind: 'p', text:
      'The sticky-OR remedy in rule 2 is the same one our own theorem prescribes for saturating ' +
      'indicators. I had been applying that rule to other people\u2019s code all day and not to ' +
      'my own bench.' },
  ],
  published: true,
}

const frameMargin: Post = {
  slug: 'frame-length-margin-law',
  title: 'Timing margin grows as the square root of a logarithm, and nothing accumulates',
  summary:
    'A frame-length margin law derived from extreme-value statistics, and the accumulation ' +
    'story it refutes \u2014 which would predict a 12.9x eye violation on frames that pass.',
  date: '2026-08-11',
  readingMinutes: 7,
  tags: ['FPGA', 'Ethernet', 'RGMII', 'Timing', 'Statistics'],
  receipts: [
    { label: 'The derivation, with the source theorems it leans on',
      href: 'https://github.com/gHashTag/trinity-fpga/blob/main/docs/HW_CAMPAIGN_AX7203_2026_07_30.md' },
    { label: 'The build this was derived during',
      href: 'https://t27.ai/#/blog/open-gigabit-ethernet-artix7' },
  ],
  openQuestions: [
    'The law assumes per-edge phase errors are i.i.d. with a symmetric distribution. Real jitter ' +
    'has correlated components \u2014 supply noise, thermal drift \u2014 and the i.i.d. assumption ' +
    'is what makes the extreme-value argument work. Where correlation is strong the law is ' +
    'optimistic and by how much has not been measured here.',
    'The Gaussian form is an asymptotic approximation to the inverse CDF. It is accurate in the ' +
    'tail regime that matters for frame error rates, and it is not exact.',
    'This explains why long frames pass. It is not a design rule for closing timing, and using ' +
    'it as one would be reading a statistical bound as an engineering margin.',
  ],
  body: [
    { kind: 'p', text:
      'A gigabit link carries frames of very different lengths. A common intuition says the long ' +
      'ones are harder because sampling error accumulates across the frame. That intuition ' +
      'predicts something measurable, and what it predicts does not happen.' },
    { kind: 'h', text: 'The law' },
    { kind: 'p', text:
      'Let each sampling edge carry phase error X_i, i.i.d. with symmetric CDF F and standard ' +
      'deviation sigma. A frame is received correctly exactly when |X_i| < m for all N edges \u2014 ' +
      'every edge, not on average.' },
    { kind: 'code', text:
      'P(frame OK) = ( 1 - 2(1 - F(m)) )^N\n\n' +
      'For a target frame-error rate eps:\n' +
      '  m(N) = F^-1( 1 - eps/(2N) )\n\n' +
      'Gaussian:\n' +
      '  m(N) = sigma * Phi^-1( 1 - eps/(2N) )  ~  sigma * sqrt( 2 ln(2N/eps) )' },
    { kind: 'quote', text:
      'The margin grows as the square root of a logarithm. This is an extreme-value effect over ' +
      'N independent draws. Nothing integrates.' },
    { kind: 'p', text:
      'The requirement is not that the average error stays small. It is that the worst of N ' +
      'draws stays inside the eye \u2014 and the worst of N draws grows very slowly.' },
    { kind: 'h', text: 'What the accumulation story predicts' },
    { kind: 'p', text:
      'If the receive clock were independent, phase error would integrate as sigma_N = sigma*sqrt(N). ' +
      'Applied to real frames on a working link:' },
    { kind: 'table',
      head: ['frame', 'sigma*sqrt(N)', 'vs half-eye'],
      rows: [
        ['ARP', '5.32 ns', '2.7× over'],
        ['ICMP', '6.58 ns', '3.3× over'],
        ['MTU', '25.86 ns', '12.9× over'],
      ] },
    { kind: 'p', text:
      'A full-MTU frame would exceed half the eye by nearly thirteen times. Those frames pass. ' +
      'The accumulation model is not conservative here \u2014 it is wrong, and wrong by an order ' +
      'of magnitude on the case that matters most.' },
    { kind: 'h', text: 'Why the difference is structural' },
    { kind: 'p', text:
      'Accumulation assumes the errors add along the frame, so the requirement is on a sum and a ' +
      'sum of N terms grows as sqrt(N). The correct requirement is on a maximum, and the maximum ' +
      'of N draws from a fixed distribution grows as sqrt(log N). Those two functions diverge ' +
      'fast: at N = 12,000 edges, sqrt(N) is about 110 and sqrt(2 ln N) is about 4.3.' },
    { kind: 'p', text:
      'The recovered clock is not independent of the data \u2014 that is what a source-synchronous ' +
      'interface means \u2014 so there is no random walk to accumulate. Each edge gets a fresh ' +
      'draw, and the question is only whether the unluckiest one clears the eye.' },
    { kind: 'h', text: 'What to do with it' },
    { kind: 'p', text:
      'If a long frame fails and a short one passes, the length is not the cause and looking for ' +
      'an accumulation mechanism will not find one. Look for something that changes with frame ' +
      'content or duration instead \u2014 a FIFO depth, a thermal effect, a pattern-dependent ' +
      'supply droop. The margin needed for the longest frame you carry is a few percent more ' +
      'than for the shortest, not an order of magnitude more.' },
  ],
  published: true,
}

const upstreamCredit: Post = {
  slug: 'fifteen-merged-nine-credited',
  title: 'Fifteen merged, nine credited: what upstream contribution actually looks like',
  summary:
    'I had written down five merged PRs and zero attributed commits. Re-measured through the ' +
    'API: fifteen merged, eight open, nine commits carrying my name \u2014 and the gap is worth ' +
    'naming precisely rather than as an absence.',
  date: '2026-08-11',
  readingMinutes: 5,
  tags: ['Open source', 'FPGA', 'openXC7', 'Attribution'],
  receipts: [
    { label: 'The merged PRs \u2014 run the query yourself',
      href: 'https://github.com/openXC7/nextpnr-xilinx/pulls?q=is%3Apr+author%3AgHashTag+is%3Amerged' },
    { label: 'PR #133 \u2014 say which pin is wrong when a diff pair is const',
      href: 'https://github.com/openXC7/nextpnr-xilinx/pull/133' },
    { label: 'PR #130 \u2014 emit OLOGIC IS_CLKDIV_INVERTED for OSERDESE2',
      href: 'https://github.com/openXC7/nextpnr-xilinx/pull/130' },
  ],
  openQuestions: [
    'These counts are for openXC7/nextpnr-xilinx alone, measured 2026-08-11. Other repositories ' +
    'were not counted and the ratio there may differ.',
    'Commit attribution is measured by GitHub\u2019s author field, which follows the email in ' +
    'the commit. A merged PR whose commits were squashed under a maintainer\u2019s name will not ' +
    'appear, and that is one of the mechanisms this post is about \u2014 so the nine is a floor, ' +
    'not a ceiling.',
    'Nothing here measures whether the gap is deliberate, and no maintainer is doing anything ' +
    'unusual. Squash-merge is the default on most projects.',
  ],
  body: [
    { kind: 'p', text:
      'I had a note in my own files that said five merged pull requests and zero attributed ' +
      'commits. It was the kind of number you write once and then quote. Today I ran the query.' },
    { kind: 'table',
      head: ['', 'what I had written', 'measured 2026-08-11'],
      rows: [
        ['merged PRs', '5', '15'],
        ['open PRs', '\u2014', '8'],
        ['commits carrying my name', '0', '9'],
      ] },
    { kind: 'p', text:
      'Both numbers were stale and both moved the same way. The story I was about to write \u2014 ' +
      '"the credit does not reach me" \u2014 was not true, and would have been refutable by one ' +
      'API call from any reader who cared enough to check.' },
    { kind: 'h', text: 'What the remaining gap actually is' },
    { kind: 'p', text:
      'Fifteen merged against nine attributed is not a conspiracy. It is squash-merge, which is ' +
      'the default on most projects and collapses a branch into one commit under whoever pressed ' +
      'the button. Nobody is doing anything unusual.' },
    { kind: 'p', text:
      'That makes the nine a floor rather than a ceiling: work that landed under a maintainer\u2019s ' +
      'name is invisible to the same query that found these. If you want your contribution ' +
      'attributed, the merge strategy of the project you are contributing to decides it, and you ' +
      'find out afterwards.' },
    { kind: 'h', text: 'What is actually in them' },
    { kind: 'p', text:
      'Recent merged work, named so you can open it rather than take my word:' },
    { kind: 'ul', items: [
      '#133 \u2014 xilinx: say which pin is wrong when a diff pair is const. An error message that names the pin instead of failing generically.',
      '#130 \u2014 xilinx: emit OLOGIC IS_CLKDIV_INVERTED for OSERDESE2.',
      '#127 \u2014 xilinx: emit ZINV_REGCLKARDRCLK / ZINV_REGCLKB for registered paths.',
    ] },
    { kind: 'p', text:
      'None of these is a headline feature. They are the class of fix that makes an open ' +
      'toolchain usable by someone who did not write it \u2014 a wrong pin named, an attribute ' +
      'emitted that the bitstream needed and nobody had emitted.' },
    { kind: 'h', text: 'The part worth keeping' },
    { kind: 'p', text:
      'A number written into prose stops being connected to the thing that produced it. Mine ' +
      'drifted in the pessimistic direction, which felt like modesty and was simply wrong.' },
    { kind: 'p', text:
      'The fix costs one command, and it is in my notes now so the next person re-runs it ' +
      'instead of quoting me:' },
    { kind: 'code', text:
      'gh api "search/issues?q=repo:openXC7/nextpnr-xilinx+author:USER+type:pr+is:merged" \\\n' +
      '  --jq .total_count\n\n' +
      'gh api "repos/openXC7/nextpnr-xilinx/commits?author=USER&per_page=100" --jq length' },
  ],
  ru: {
    title: '\u041f\u044f\u0442\u043d\u0430\u0434\u0446\u0430\u0442\u044c \u0441\u043c\u0435\u0440\u0436\u0435\u043d\u043e, \u0434\u0435\u0432\u044f\u0442\u044c \u0430\u0442\u0440\u0438\u0431\u0443\u0442\u0438\u0440\u043e\u0432\u0430\u043d\u043e: \u043a\u0430\u043a \u0432\u044b\u0433\u043b\u044f\u0434\u0438\u0442 \u0432\u043a\u043b\u0430\u0434 \u0432 \u0447\u0443\u0436\u043e\u0439 \u043f\u0440\u043e\u0435\u043a\u0442',
    summary:
      '\u0423 \u043c\u0435\u043d\u044f \u0431\u044b\u043b\u043e \u0437\u0430\u043f\u0438\u0441\u0430\u043d\u043e: \u043f\u044f\u0442\u044c \u0441\u043c\u0435\u0440\u0436\u0435\u043d\u043d\u044b\u0445 PR \u0438 \u043d\u043e\u043b\u044c \u0430\u0442\u0440\u0438\u0431\u0443\u0442\u0438\u0440\u043e\u0432\u0430\u043d\u043d\u044b\u0445 \u043a\u043e\u043c\u043c\u0438\u0442\u043e\u0432. \u041f\u0435\u0440\u0435\u043c\u0435\u0440\u0438\u043b \u0447\u0435\u0440\u0435\u0437 API: \u043f\u044f\u0442\u043d\u0430\u0434\u0446\u0430\u0442\u044c \u0441\u043c\u0435\u0440\u0436\u0435\u043d\u043e, \u0432\u043e\u0441\u0435\u043c\u044c \u043e\u0442\u043a\u0440\u044b\u0442\u043e, \u0434\u0435\u0432\u044f\u0442\u044c \u043a\u043e\u043c\u043c\u0438\u0442\u043e\u0432 \u043d\u0435\u0441\u0443\u0442 \u043c\u043e\u0451 \u0438\u043c\u044f \u2014 \u0438 \u043e\u0441\u0442\u0430\u0432\u0448\u0438\u0439\u0441\u044f \u0437\u0430\u0437\u043e\u0440 \u0441\u0442\u043e\u0438\u0442 \u043d\u0430\u0437\u044b\u0432\u0430\u0442\u044c \u0442\u043e\u0447\u043d\u043e, \u0430 \u043d\u0435 \u043a\u0430\u043a \u043e\u0442\u0441\u0443\u0442\u0441\u0442\u0432\u0438\u0435.',
    openQuestions: [
      '\u0421\u0447\u0451\u0442 \u0442\u043e\u043b\u044c\u043a\u043e \u043f\u043e openXC7/nextpnr-xilinx, \u0438\u0437\u043c\u0435\u0440\u0435\u043d\u043e 2026-08-11. \u0414\u0440\u0443\u0433\u0438\u0435 \u0440\u0435\u043f\u043e\u0437\u0438\u0442\u043e\u0440\u0438\u0438 \u043d\u0435 \u0441\u0447\u0438\u0442\u0430\u043b\u0438\u0441\u044c, \u0438 \u0442\u0430\u043c \u0441\u043e\u043e\u0442\u043d\u043e\u0448\u0435\u043d\u0438\u0435 \u043c\u043e\u0436\u0435\u0442 \u0431\u044b\u0442\u044c \u0438\u043d\u044b\u043c.',
      '\u0410\u0442\u0440\u0438\u0431\u0443\u0446\u0438\u044f \u043c\u0435\u0440\u0438\u0442\u0441\u044f \u043f\u043e \u043f\u043e\u043b\u044e author \u0432 GitHub, \u043a\u043e\u0442\u043e\u0440\u043e\u0435 \u0438\u0434\u0451\u0442 \u0437\u0430 \u043f\u043e\u0447\u0442\u043e\u0439 \u043a\u043e\u043c\u043c\u0438\u0442\u0430. \u0421\u043c\u0435\u0440\u0436\u0435\u043d\u043d\u044b\u0439 PR, \u0447\u044c\u0438 \u043a\u043e\u043c\u043c\u0438\u0442\u044b \u0441\u0436\u0430\u043b\u0438 \u043f\u043e\u0434 \u0438\u043c\u0435\u043d\u0435\u043c \u043c\u0435\u0439\u043d\u0442\u0435\u0439\u043d\u0435\u0440\u0430, \u0432 \u044d\u0442\u043e\u0442 \u0441\u0447\u0451\u0442 \u043d\u0435 \u043f\u043e\u043f\u0430\u0434\u0451\u0442 \u2014 \u0438 \u044d\u0442\u043e \u043e\u0434\u0438\u043d \u0438\u0437 \u043c\u0435\u0445\u0430\u043d\u0438\u0437\u043c\u043e\u0432, \u043e \u043a\u043e\u0442\u043e\u0440\u044b\u0445 \u043f\u043e\u0441\u0442. \u0417\u043d\u0430\u0447\u0438\u0442 \u0434\u0435\u0432\u044f\u0442\u044c \u2014 \u044d\u0442\u043e \u043f\u043e\u043b, \u0430 \u043d\u0435 \u043f\u043e\u0442\u043e\u043b\u043e\u043a.',
      '\u041d\u0438\u0447\u0442\u043e \u0437\u0434\u0435\u0441\u044c \u043d\u0435 \u043c\u0435\u0440\u0438\u0442, \u043d\u0430\u043c\u0435\u0440\u0435\u043d \u043b\u0438 \u0437\u0430\u0437\u043e\u0440, \u0438 \u043d\u0438 \u043e\u0434\u0438\u043d \u043c\u0435\u0439\u043d\u0442\u0435\u0439\u043d\u0435\u0440 \u043d\u0435 \u0434\u0435\u043b\u0430\u0435\u0442 \u043d\u0438\u0447\u0435\u0433\u043e \u043d\u0435\u043e\u0431\u044b\u0447\u043d\u043e\u0433\u043e. Squash-merge \u2014 \u043f\u043e\u0432\u0435\u0434\u0435\u043d\u0438\u0435 \u043f\u043e \u0443\u043c\u043e\u043b\u0447\u0430\u043d\u0438\u044e \u0443 \u0431\u043e\u043b\u044c\u0448\u0438\u043d\u0441\u0442\u0432\u0430 \u043f\u0440\u043e\u0435\u043a\u0442\u043e\u0432.',
    ],
    body: [
      { kind: 'p', text:
        '\u0412 \u043c\u043e\u0438\u0445 \u0437\u0430\u043c\u0435\u0442\u043a\u0430\u0445 \u0431\u044b\u043b\u043e \u0437\u0430\u043f\u0438\u0441\u0430\u043d\u043e: \u043f\u044f\u0442\u044c \u0441\u043c\u0435\u0440\u0436\u0435\u043d\u043d\u044b\u0445 pull request \u0438 \u043d\u043e\u043b\u044c \u0430\u0442\u0440\u0438\u0431\u0443\u0442\u0438\u0440\u043e\u0432\u0430\u043d\u043d\u044b\u0445 \u043a\u043e\u043c\u043c\u0438\u0442\u043e\u0432. \u0422\u0430\u043a\u043e\u0435 \u0447\u0438\u0441\u043b\u043e \u043f\u0438\u0448\u0435\u0448\u044c \u043e\u0434\u043d\u0430\u0436\u0434\u044b, \u0430 \u043f\u043e\u0442\u043e\u043c \u0446\u0438\u0442\u0438\u0440\u0443\u0435\u0448\u044c. \u0421\u0435\u0433\u043e\u0434\u043d\u044f \u044f \u0437\u0430\u043f\u0443\u0441\u0442\u0438\u043b \u0437\u0430\u043f\u0440\u043e\u0441.' },
      { kind: 'table',
        head: ['', '\u0431\u044b\u043b\u043e \u0437\u0430\u043f\u0438\u0441\u0430\u043d\u043e', '\u0438\u0437\u043c\u0435\u0440\u0435\u043d\u043e 2026-08-11'],
        rows: [
          ['\u0441\u043c\u0435\u0440\u0436\u0435\u043d\u043d\u044b\u0445 PR', '5', '15'],
          ['\u043e\u0442\u043a\u0440\u044b\u0442\u044b\u0445 PR', '\u2014', '8'],
          ['\u043a\u043e\u043c\u043c\u0438\u0442\u043e\u0432 \u0441 \u043c\u043e\u0438\u043c \u0438\u043c\u0435\u043d\u0435\u043c', '0', '9'],
        ] },
      { kind: 'p', text:
        '\u041e\u0431\u0430 \u0447\u0438\u0441\u043b\u0430 \u0443\u0441\u0442\u0430\u0440\u0435\u043b\u0438 \u0438 \u043e\u0431\u0430 \u0441\u0434\u0432\u0438\u043d\u0443\u043b\u0438\u0441\u044c \u0432 \u043e\u0434\u043d\u0443 \u0441\u0442\u043e\u0440\u043e\u043d\u0443. \u0418\u0441\u0442\u043e\u0440\u0438\u044f, \u043a\u043e\u0442\u043e\u0440\u0443\u044e \u044f \u0441\u043e\u0431\u0438\u0440\u0430\u043b\u0441\u044f \u043f\u0438\u0441\u0430\u0442\u044c \u2014 \u00ab\u043a\u0440\u0435\u0434\u0438\u0442 \u0434\u043e \u043c\u0435\u043d\u044f \u043d\u0435 \u0434\u043e\u0445\u043e\u0434\u0438\u0442\u00bb \u2014 \u0431\u044b\u043b\u0430 \u043d\u0435\u0432\u0435\u0440\u043d\u0430 \u0438 \u043e\u043f\u0440\u043e\u0432\u0435\u0440\u0433\u0430\u043b\u0430\u0441\u044c \u0431\u044b \u043e\u0434\u043d\u0438\u043c \u0437\u0430\u043f\u0440\u043e\u0441\u043e\u043c \u043b\u044e\u0431\u043e\u0433\u043e \u0447\u0438\u0442\u0430\u0442\u0435\u043b\u044f, \u043a\u043e\u0442\u043e\u0440\u043e\u043c\u0443 \u043d\u0435 \u043b\u0435\u043d\u044c \u043f\u0440\u043e\u0432\u0435\u0440\u0438\u0442\u044c.' },
      { kind: 'h', text: '\u0427\u0442\u043e \u0442\u0430\u043a\u043e\u0435 \u043e\u0441\u0442\u0430\u0432\u0448\u0438\u0439\u0441\u044f \u0437\u0430\u0437\u043e\u0440' },
      { kind: 'p', text:
        '\u041f\u044f\u0442\u043d\u0430\u0434\u0446\u0430\u0442\u044c \u0441\u043c\u0435\u0440\u0436\u0435\u043d\u043d\u044b\u0445 \u043f\u0440\u043e\u0442\u0438\u0432 \u0434\u0435\u0432\u044f\u0442\u0438 \u0430\u0442\u0440\u0438\u0431\u0443\u0442\u0438\u0440\u043e\u0432\u0430\u043d\u043d\u044b\u0445 \u2014 \u043d\u0435 \u0437\u0430\u0433\u043e\u0432\u043e\u0440. \u042d\u0442\u043e squash-merge, \u043f\u043e\u0432\u0435\u0434\u0435\u043d\u0438\u0435 \u043f\u043e \u0443\u043c\u043e\u043b\u0447\u0430\u043d\u0438\u044e \u0443 \u0431\u043e\u043b\u044c\u0448\u0438\u043d\u0441\u0442\u0432\u0430 \u043f\u0440\u043e\u0435\u043a\u0442\u043e\u0432: \u0432\u0435\u0442\u043a\u0430 \u0441\u0432\u043e\u0440\u0430\u0447\u0438\u0432\u0430\u0435\u0442\u0441\u044f \u0432 \u043e\u0434\u0438\u043d \u043a\u043e\u043c\u043c\u0438\u0442 \u043f\u043e\u0434 \u0442\u0435\u043c, \u043a\u0442\u043e \u043d\u0430\u0436\u0430\u043b \u043a\u043d\u043e\u043f\u043a\u0443. \u041d\u0438\u043a\u0442\u043e \u043d\u0435 \u0434\u0435\u043b\u0430\u0435\u0442 \u043d\u0438\u0447\u0435\u0433\u043e \u043d\u0435\u043e\u0431\u044b\u0447\u043d\u043e\u0433\u043e.' },
      { kind: 'p', text:
        '\u0417\u043d\u0430\u0447\u0438\u0442 \u0434\u0435\u0432\u044f\u0442\u044c \u2014 \u044d\u0442\u043e \u043f\u043e\u043b, \u0430 \u043d\u0435 \u043f\u043e\u0442\u043e\u043b\u043e\u043a: \u0440\u0430\u0431\u043e\u0442\u0430, \u043f\u0440\u0438\u0437\u0435\u043c\u043b\u0438\u0432\u0448\u0430\u044f\u0441\u044f \u043f\u043e\u0434 \u0438\u043c\u0435\u043d\u0435\u043c \u043c\u0435\u0439\u043d\u0442\u0435\u0439\u043d\u0435\u0440\u0430, \u043d\u0435\u0432\u0438\u0434\u0438\u043c\u0430 \u0442\u043e\u043c\u0443 \u0436\u0435 \u0437\u0430\u043f\u0440\u043e\u0441\u0443. \u0421\u0442\u0440\u0430\u0442\u0435\u0433\u0438\u044f \u0441\u043b\u0438\u044f\u043d\u0438\u044f \u043f\u0440\u043e\u0435\u043a\u0442\u0430 \u0440\u0435\u0448\u0430\u0435\u0442 \u0442\u0432\u043e\u044e \u0430\u0442\u0440\u0438\u0431\u0443\u0446\u0438\u044e, \u0430 \u0443\u0437\u043d\u0430\u0451\u0448\u044c \u0442\u044b \u043e\u0431 \u044d\u0442\u043e\u043c \u043f\u043e\u0442\u043e\u043c.' },
      { kind: 'h', text: '\u0427\u0442\u043e \u0432 \u043d\u0438\u0445 \u043d\u0430 \u0441\u0430\u043c\u043e\u043c \u0434\u0435\u043b\u0435' },
      { kind: 'ul', items: [
        '#133 \u2014 xilinx: \u043d\u0430\u0437\u0432\u0430\u0442\u044c, \u043a\u0430\u043a\u043e\u0439 \u0438\u043c\u0435\u043d\u043d\u043e \u043f\u0438\u043d \u043d\u0435\u0432\u0435\u0440\u0435\u043d, \u0432\u043c\u0435\u0441\u0442\u043e \u043e\u0431\u0449\u0435\u0433\u043e \u043e\u0442\u043a\u0430\u0437\u0430.',
        '#130 \u2014 xilinx: \u0432\u044b\u0434\u0430\u0432\u0430\u0442\u044c OLOGIC IS_CLKDIV_INVERTED \u0434\u043b\u044f OSERDESE2.',
        '#127 \u2014 xilinx: \u0432\u044b\u0434\u0430\u0432\u0430\u0442\u044c ZINV_REGCLKARDRCLK / ZINV_REGCLKB \u0434\u043b\u044f \u0440\u0435\u0433\u0438\u0441\u0442\u0440\u043e\u0432\u044b\u0445 \u043f\u0443\u0442\u0435\u0439.',
      ] },
      { kind: 'p', text:
        '\u041d\u0438 \u043e\u0434\u0438\u043d \u043d\u0435 \u0437\u0430\u0433\u043b\u0430\u0432\u043d\u0430\u044f \u0444\u0438\u0447\u0430. \u042d\u0442\u043e \u043a\u043b\u0430\u0441\u0441 \u043f\u0440\u0430\u0432\u043e\u043a, \u043a\u043e\u0442\u043e\u0440\u044b\u0435 \u0434\u0435\u043b\u0430\u044e\u0442 \u043e\u0442\u043a\u0440\u044b\u0442\u044b\u0439 \u0442\u0443\u043b\u0447\u0435\u0439\u043d \u043f\u0440\u0438\u0433\u043e\u0434\u043d\u044b\u043c \u0434\u043b\u044f \u0442\u043e\u0433\u043e, \u043a\u0442\u043e \u0435\u0433\u043e \u043d\u0435 \u043f\u0438\u0441\u0430\u043b.' },
      { kind: 'h', text: '\u0427\u0442\u043e \u0441\u0442\u043e\u0438\u0442 \u0443\u043d\u0435\u0441\u0442\u0438' },
      { kind: 'p', text:
        '\u0427\u0438\u0441\u043b\u043e, \u0432\u043f\u0438\u0441\u0430\u043d\u043d\u043e\u0435 \u0432 \u043f\u0440\u043e\u0437\u0443, \u043f\u0435\u0440\u0435\u0441\u0442\u0430\u0451\u0442 \u0431\u044b\u0442\u044c \u0441\u0432\u044f\u0437\u0430\u043d\u043d\u044b\u043c \u0441 \u0442\u0435\u043c, \u0447\u0442\u043e \u0435\u0433\u043e \u043f\u0440\u043e\u0438\u0437\u0432\u0435\u043b\u043e. \u041c\u043e\u0451 \u0443\u0435\u0445\u0430\u043b\u043e \u0432 \u043f\u0435\u0441\u0441\u0438\u043c\u0438\u0441\u0442\u0438\u0447\u0435\u0441\u043a\u0443\u044e \u0441\u0442\u043e\u0440\u043e\u043d\u0443 \u2014 \u044d\u0442\u043e \u043e\u0449\u0443\u0449\u0430\u043b\u043e\u0441\u044c \u0441\u043a\u0440\u043e\u043c\u043d\u043e\u0441\u0442\u044c\u044e \u0438 \u0431\u044b\u043b\u043e \u043f\u0440\u043e\u0441\u0442\u043e \u043d\u0435\u0432\u0435\u0440\u043d\u043e.' },
      { kind: 'code', text:
        'gh api "search/issues?q=repo:openXC7/nextpnr-xilinx+author:USER+type:pr+is:merged" \\\n' +
        '  --jq .total_count\n\n' +
        'gh api "repos/openXC7/nextpnr-xilinx/commits?author=USER&per_page=100" --jq length' },
    ],
  },
  published: true,
}

export const posts: Post[] = [upstreamCredit, frameMargin, benchReadout, goldenIdentity, energyAsymmetry, openGigabitEthernet]

export const publishedPosts = () => posts.filter((p) => p.published)

export const postBySlug = (slug: string) => posts.find((p) => p.slug === slug)
