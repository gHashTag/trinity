// TRI DEV KIT: the numbers behind #/devkit and the devkit blog post, kept in one place.
//
// Source: `tri devkit flow --build` recorded at /term/devkit-flow/ (flow.json of that run,
// 2026-10-03 11:31 +07, load 12.6 on 8 cpus). Wall seconds on one laptop: they move with
// load, so ratios are the quotable part, not the absolute times.

export const FLOW = {
  recorded: '2026-10-03',
  design: 'trinet_node_v2_ax7203',
  part: 'xc7a200tfbg484-2',
  fasmLines: 121587,
  load: '12.6 on 8 cpus',
  cast: 'term/devkit-flow/session.cast',
  share: 'https://t27.ai/term/devkit-flow/',
}

export interface Layer {
  id: string
  name: string
  tool: string
  s: number
  t27?: { tool: string; s: number; identical: boolean }
}

export const LAYERS: Layer[] = [
  { id: 'L1', name: 'Synthesis', tool: 'yosys', s: 12.69 },
  { id: 'L2', name: 'Place & route', tool: 'nextpnr-xilinx', s: 70.09 },
  { id: 'L3', name: 'FASM → frames', tool: 'fasm2frames.py', s: 33.86, t27: { tool: 'bitwalk --fasm', s: 0.42, identical: true } },
  { id: 'L4', name: 'Frames → .bit', tool: 'xc7frames2bit', s: 0.22, t27: { tool: 'bitwalk --write', s: 0.25, identical: true } },
]

export const flowBefore = LAYERS.reduce((a, l) => a + l.s, 0)
export const flowAfter = LAYERS.reduce((a, l) => a + (l.t27 ? l.t27.s : l.s), 0)
export const savedPerBuild = flowBefore - flowAfter

/** The whole flow if one more not-yet-rewritten layer took 0 s: the most its rewrite could give. */
export function ceiling(l: Layer): { flow: number; x: number } {
  const flow = flowAfter - l.s
  return { flow, x: flowBefore / flow }
}

export const WORKING_DAYS = 230

export function hoursPerYear(savedS: number, buildsPerDay: number, people: number): number {
  return (savedS * buildsPerDay * WORKING_DAYS * people) / 3600
}

// Crowd Supply campaigns of open FPGA hardware, read from their pages on 2026-10-03.
export const CROWD = [
  { name: 'Glasgow revC', by: '1BitSquared', href: 'https://www.crowdsupply.com/1bitsquared/glasgow', raised: 458567, backers: 2321, goal: 25000, price: '$179' },
  { name: 'ULX3S', by: 'Radiona', href: 'https://www.crowdsupply.com/radiona/ulx3s', raised: 239437, backers: 1162, goal: 15000, price: '$155–275' },
  { name: 'iCEBreaker', by: '1BitSquared', href: 'https://www.crowdsupply.com/1bitsquared/icebreaker-fpga', raised: 155931, backers: 1188, goal: 15000, price: '$80' },
]

// GitHub stars and forks, read through the API on 2026-10-03.
export const FIELD = [
  { name: 'Vivado', href: 'https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html', stars: null, what: 'The vendor flow. Closed source; the reference every open flow is compared against.' },
  { name: 'openXC7', href: 'https://github.com/openXC7/nextpnr-xilinx', stars: 71, what: 'yosys + nextpnr-xilinx + prjxray for Xilinx 7-series. The flow this kit builds on; L1 and L2 are its tools.' },
  { name: 'F4PGA / prjxray', href: 'https://github.com/f4pga/prjxray', stars: 921, what: 'The 7-series bit database and fasm2frames. Last push 2025-06-05.' },
  { name: 'fpga-assembler', href: 'https://github.com/lromor/fpga-assembler', stars: 29, what: 'A C++ rewrite of FASM-to-bitstream, active. The same L3/L4 job as bitwalk, from code rather than specs.' },
  { name: 'LiteX', href: 'https://github.com/enjoy-digital/litex', stars: 4140, what: 'SoC builder with an openXC7 backend. A user of the flow, not a replacement for a layer.' },
  { name: 'openFPGALoader', href: 'https://github.com/trabucayre/openFPGALoader', stars: 1746, what: 'The common open loader (L5). Not rewritten here.' },
  { name: 'yosys', href: 'https://github.com/YosysHQ/yosys', stars: 4785, what: 'Open synthesis (L1). 1,170 forks; a mature project with a large community.' },
  { name: 'nextpnr', href: 'https://github.com/YosysHQ/nextpnr', stars: 1763, what: 'Open place and route (L2). nextpnr-xilinx is its 7-series fork.' },
]
