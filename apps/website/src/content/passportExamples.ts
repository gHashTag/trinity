// The quantities the PASSPORT's figures plot, and nothing else.
//
// Every entry carries the exact string that content/passport.ts prints for it in
// prose. qa/passport-figures.mjs asserts that string still occurs in that prose,
// in both languages, so a number cannot be corrected in the text and left
// standing in a drawing. A document whose thesis is that a result must travel
// with its provenance cannot ship a chart that quietly disagrees with its own
// paragraph.
//
// Nothing here is new evidence. Each number is already stated in `cases`; this
// module only gives the drawings a machine-readable handle on it.

import type { Bi } from './passport'

/** One plotted number, with the literal the prose uses for it. */
export interface Qty {
  value: number
  /** Exactly as passport.ts prints it in English. */
  print: string
  /** Exactly as passport.ts prints it in Russian, where the two differ. */
  printRu?: string
}

const q = (value: number, print: string, printRu?: string): Qty => ({ value, print, printRu })

/**
 * Figure 1 plots each case on two axes that readers habitually collapse into
 * one: how far apart the headline metric fell, and how far apart the artifacts
 * actually were. The two cases land in opposite corners.
 */
export const axes = {
  /** Horizontal: separation of the two readings, in combined standard errors. */
  metric: {
    label: {
      en: 'Separation of the two readings, in combined standard errors',
      ru: 'Расхождение двух отсчётов, в совокупных стандартных ошибках',
    } as Bi,
    max: 5,
  },
  /** Vertical: how much of the artifact differed, in percent of parameters. */
  artifact: {
    label: {
      en: 'Parameters that differ between the two artifacts',
      ru: 'Параметры, различающиеся между двумя артефактами',
    } as Bi,
    max: 50,
  },
}

export const plotted: {
  case: string
  kind: Bi
  metricSE: Qty
  artifactPct: Qty
  gloss: Bi
}[] = [
  {
    case: '1',
    kind: { en: 'False difference', ru: 'Ложное различие' },
    metricSE: q(4.44, '4.44'),
    // Zero by measurement, not by assumption: one SHA-256, re-hashed from two
    // locations and identical. The prose says "identical to the byte".
    artifactPct: q(0, 'identical to the byte', 'совпадали побайтово'),
    gloss: {
      en: 'One set of weights, read as two models: 2.6385 against 2.9193 bits per byte.',
      ru: 'Один набор весов, прочитанный как две модели: 2.6385 против 2.9193 бита на байт.',
    },
  },
  {
    case: '2',
    kind: { en: 'False agreement', ru: 'Ложное согласие' },
    metricSE: q(0.084, '0.084'),
    artifactPct: q(43.7, '43.70', '43,70'),
    gloss: {
      en: '93,071 of 212,992 parameters differ behind a metric that did not move.',
      ru: '93 071 из 212 992 параметров различаются за метрикой, которая не шелохнулась.',
    },
  },
]

/**
 * Figure 2: case 3. One function, one XC7A200T, one open toolchain, two
 * implementations. The DSP48 column is drawn apart from the LUT bars on
 * purpose — the prose says the DSP48 usage is "additional and not
 * commensurable" with the LUT ratio, and a stacked bar would say otherwise.
 */
export const area = {
  target: 'XC7A200T',
  lut: {
    label: { en: 'LUTs, post-route', ru: 'LUT, post-route' } as Bi,
    a: q(1179, '1,179', '1 179'),
    b: q(219, '219'),
    ratio: q(5.4, '5.4', '5,4'),
  },
  dsp: {
    label: { en: 'DSP48 blocks', ru: 'Блоки DSP48' } as Bi,
    a: q(3, 'three', 'три'),
    b: q(0, 'none', 'ни одного'),
    caveat: {
      en: 'Additional, and not commensurable with the LUT ratio.',
      ru: 'Добавочен и с отношением по LUT несоизмерим.',
    } as Bi,
  },
  implementations: [
    {
      en: 'Datapath buses wider than the values they carried',
      ru: 'Шины датапута шире значений, которые несли',
    } as Bi,
    {
      en: 'Every width derived from the format parameters',
      ru: 'Каждая ширина выведена из параметров формата',
    } as Bi,
  ],
}
