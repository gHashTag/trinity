// Blog posts for t27.ai/#/blog
//
// Articles are published HERE FIRST. Every other channel (Habr, LinkedIn, X,
// r/t27ai) links back to this page — the owned surface is the canonical one.
//
// Honesty rules that apply to every post in this file:
//   - an unmerged pull request is "submitted upstream", never "merged"
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
    { label: 'openXC7/nextpnr-xilinx #109 — set_multicycle_path', href: 'https://github.com/openXC7/nextpnr-xilinx/pull/109' },
    { label: '#110 — clock-buffer preplace BFS cap', href: 'https://github.com/openXC7/nextpnr-xilinx/pull/110' },
    { label: '#111 — fabric-driven global buffers', href: 'https://github.com/openXC7/nextpnr-xilinx/pull/111' },
    { label: '#112 — SDP BRAM unused-port width bit', href: 'https://github.com/openXC7/nextpnr-xilinx/pull/112' },
    { label: '#113 — single-site configuration primitives', href: 'https://github.com/openXC7/nextpnr-xilinx/pull/113' },
    { label: '#115 — IDDR IFF flop initialisation', href: 'https://github.com/openXC7/nextpnr-xilinx/pull/115' },
    {
      label:
        'Shah, Hung, Wolf, Bazanski, Gisselquist, Milanović — Yosys+nextpnr: an Open Source Framework from Verilog to Bitstream for Commercial FPGAs (FCCM 2019), arXiv:1903.10407',
      href: 'https://arxiv.org/abs/1903.10407',
    },
  ],
  openQuestions: [
    'The link comes up intermittently at power-on. The cause is not yet known.',
    'All six patches are OPEN on openXC7/nextpnr-xilinx — submitted upstream, none merged as of 2026-08-09.',
    'Hardware IDDR capture on Artix-7 is still broken in the toolchain; the receive path uses fabric DDR capture as a workaround.',
    'Is the 470 ps figure an RMS or a peak-to-peak total, and at what BER? Theorem 2 shows the answer decides whether the link is comfortably feasible (88% eye open) or marginal. Not yet re-measured.',
    'Frame-error rate was never measured directly, only inferred from whether the link came up. The three skew data points are right-censored at tap 31 and cannot discriminate between the candidate models.',
  ],
  published: false, // TODO: flip to true once the [FILL IN] blocks below are closed
  body: [
    { kind: 'h', text: 'The frame, before anything else' },
    {
      kind: 'p',
      text:
        'What works: an RGMII link at gigabit, built by Yosys -> nextpnr-xilinx -> Project X-Ray, with no vendor utility anywhere in the flow, running on a laptop. Millions of frames pass reliably.',
    },
    {
      kind: 'p',
      text:
        'What does not: the link comes up intermittently at power-on, and I do not yet know why. [FILL IN: fraction of successful power-on link-ups.]',
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
    { kind: 'p', text: 'Board: [FILL IN: board model, xc7aNNNt part, PHY].' },

    { kind: 'h', text: 'Blocker 1 — the router gave up before trying half the options' },
    {
      kind: 'p',
      text:
        'Path search from an SRCC pin to a clock buffer stopped at 50,000 iterations. The chip database holds more than 75,000 valid paths. The cap was set below the size of the search space, so "unroutable" actually meant "unfinished". The fix is one constant.',
    },
    {
      kind: 'quote',
      text:
        'Worth remembering as a class of bug: an iteration limit set smaller than the dimension of the problem looks exactly like "no route exists".',
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
        'The hardware IDDR block did not capture data. This remains open in the toolchain. #115 initialises all four IFF flops rather than only Q1/Q2, which closes part of the initialisation problem, but the receive path still had to move: RGMII receive is done with fabric DDR capture instead of the hardware IDDR.',
    },

    { kind: 'h', text: 'What the workaround costs: jitter, and a dependence on frame size' },
    {
      kind: 'p',
      text:
        'Moving capture into the fabric raised jitter to sigma ~= 470 ps. That exposed an effect invisible with hardware IDDR: link stability depends on frame size.',
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
        '[FILL IN: exact <part>, <board>, <constraints>, and how the skew step is set. Without them this section is useless; with invented values it is harmful.]',
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
}

export const posts: Post[] = [openGigabitEthernet]

export const publishedPosts = () => posts.filter((p) => p.published)

export const postBySlug = (slug: string) => posts.find((p) => p.slug === slug)
