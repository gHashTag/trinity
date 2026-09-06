// The hardware record for a spec's format: what has been synthesized, what has
// been proven, and what has actually run on the board.
//
// The hard rule this file exists to enforce: a claim is shown at the strength it
// was earned, and the difference between "this spec declares it", "a SAT engine
// proved it", "a bitstream exists" and "a board returned the right bits over a
// wire" is never smoothed over. Formats with no hardware run say so plainly
// instead of rendering an empty timeline that reads like a pending one.

import { memo } from 'react'
import { useI18n } from '../i18n/context'
import {
  CHAIN, DEVICE, FAMILY_SPECS, FAMILY_TOTALS, FORMAL_PROVEN, SPEC_TO_FORMAT,
  TOOLCHAIN, siliconFor,
} from '../data/siliconHistory'
import type { Level, OpKind, SiliconCell } from '../data/siliconHistory'

const C = {
  bg: '#0B0D0C',
  panel: '#11150F',
  wire: '#1d2a20',
  green: '#00FF88',
  gold: '#FFD700',
  amber: '#a87a4a',
  dim: '#8b9490',
  ink: '#d7e0d8',
} as const

const MONO = "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace"

const T = {
  en: {
    title: 'HARDWARE HISTORY',
    none: 'No hardware run. Nothing generated from this spec has been synthesized, flashed or measured — and the Verilog the compiler emits for it is a module shell, so there is nothing yet to place.',
    familyIntro: 'This spec describes the catalog rather than one format. Catalog-wide totals:',
    onSilicon: 'measured on silicon',
    ofCatalog: 'of 83 catalog formats',
    decodeHw: 'decode, on silicon',
    addHw: 'ADD, on silicon',
    mulHw: 'MUL, on silicon',
    swOnly: 'software bit-exact',
    structural: 'structural by design — not convertible without a format decision',
    chainTitle: 'Evidence chain — a cell counts only with all four',
    device: 'Device',
    toolchain: 'Toolchain',
    oracle: 'Golden oracle',
    ops: 'Operations',
    caught: 'What the hardware caught',
    levels: {
      silicon: 'on silicon',
      prepared: 'bitstream ready, not yet flashed',
      formal: 'proven by SAT over all inputs',
      declared: 'declared only',
    } as Record<Level, string>,
    formalNote: 'Proven by SAT over the whole input space, against an oracle written independently of the design:',
    disclaimer:
      'These results are for hand-written RTL of the same format, not for the Verilog this spec compiles to. The spec and the core describe the same number format; they are not the same artifact. Every figure is transcribed from the published evidence chain on EPIC #199 — CI run, bitstream SHA-256, JTAG flash, UART log.',
  },
  ru: {
    title: 'ИСТОРИЯ НА ЖЕЛЕЗЕ',
    none: 'Запусков на железе нет. Ничего сгенерированного из этой спеки не синтезировалось, не прошивалось и не измерялось, а Verilog, который компилятор для неё выдаёт, — это оболочка модуля, размещать пока нечего.',
    familyIntro: 'Эта спека описывает каталог, а не один формат. Итоги по каталогу:',
    onSilicon: 'измерено на кристалле',
    ofCatalog: 'из 83 форматов каталога',
    decodeHw: 'декодирование, на кристалле',
    addHw: 'ADD, на кристалле',
    mulHw: 'MUL, на кристалле',
    swOnly: 'битточно программно',
    structural: 'структурные по замыслу — без решения по формату не переводятся',
    chainTitle: 'Цепочка доказательств — ячейка засчитывается только при всех четырёх',
    device: 'Плата',
    toolchain: 'Инструменты',
    oracle: 'Эталон',
    ops: 'Операции',
    caught: 'Что поймало железо',
    levels: {
      silicon: 'на кристалле',
      prepared: 'битстрим готов, не прошит',
      formal: 'доказано SAT на всех входах',
      declared: 'только объявлено',
    } as Record<Level, string>,
    formalNote: 'Доказано SAT на всём пространстве входов против эталона, написанного независимо от схемы:',
    disclaimer:
      'Эти результаты относятся к написанному вручную RTL того же формата, а не к Verilog, в который компилируется эта спека. Спека и ядро описывают один и тот же числовой формат, но это разные артефакты. Все цифры перенесены из опубликованной цепочки доказательств в EPIC #199 — прогон CI, SHA-256 битстрима, прошивка по JTAG, лог UART.',
  },
}

const LEVEL_COLOR: Record<Level, string> = {
  silicon: C.green,
  prepared: C.gold,
  formal: '#c792ea',
  declared: C.dim,
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginTop: 4 }}>
      <span style={{ color: C.dim, minWidth: 92 }}>{label}</span>
      <span style={{ color: C.ink }}>{value}</span>
    </div>
  )
}

function OpCell({ cell, lang, formal }: { cell: SiliconCell; lang: 'en' | 'ru'; formal: boolean }) {
  const t = lang === 'ru' ? T.ru : T.en
  const color = LEVEL_COLOR[cell.level]
  return (
    <div style={{
      border: `1px solid ${color}55`, borderRadius: 4, padding: '9px 11px',
      background: C.panel, minWidth: 156, flex: '1 1 156px',
    }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
        <span style={{ font: `600 12px ${MONO}`, color }}>{cell.op}</span>
        {cell.codes && (
          <span style={{ font: `11px ${MONO}`, color: C.ink }}>{cell.codes}</span>
        )}
      </div>
      <div style={{ font: `9.5px ${MONO}`, color, marginTop: 4, opacity: 0.85 }}>
        {t.levels[cell.level]}
      </div>
      {formal && (
        <div style={{ font: `9.5px ${MONO}`, color: LEVEL_COLOR.formal, marginTop: 3 }}>
          {t.levels.formal}
        </div>
      )}
      {cell.note && (
        <div style={{ font: `9.5px ${MONO}`, color: C.dim, marginTop: 3 }}>
          {cell.note[lang]}
        </div>
      )}
    </div>
  )
}

function SpecSiliconHistoryImpl({ specPath }: { specPath: string }) {
  const { lang } = useI18n()
  const l: 'en' | 'ru' = lang === 'ru' ? 'ru' : 'en'
  const t = l === 'ru' ? T.ru : T.en

  const record = siliconFor(specPath)
  const isFamily = FAMILY_SPECS.has(specPath)
  const formatKey = SPEC_TO_FORMAT[specPath]
  const proven: OpKind[] = (formatKey && FORMAL_PROVEN[formatKey]) || []

  const head = (
    <div style={{
      display: 'flex', alignItems: 'baseline', gap: 12, flexWrap: 'wrap',
      borderBottom: `1px solid ${C.wire}`, paddingBottom: 10, marginBottom: 12,
    }}>
      <span style={{ font: `600 12px ${MONO}`, color: C.gold, letterSpacing: '.08em' }}>
        {t.title}
      </span>
      {record && (
        <span style={{ font: `10px ${MONO}`, color: C.dim }}>{record.format}</span>
      )}
    </div>
  )

  // Nothing has been through the board for this spec. Say it, rather than
  // rendering an empty frame that reads as "in progress".
  if (!record && !isFamily) {
    return (
      <div style={{ marginTop: 18, paddingTop: 14, borderTop: `1px solid ${C.wire}` }}>
        {head}
        <p style={{ font: `11px/1.8 ${MONO}`, color: C.dim, margin: 0, maxWidth: '68ch' }}>
          {t.none}
        </p>
      </div>
    )
  }

  return (
    <div style={{ marginTop: 18, paddingTop: 14, borderTop: `1px solid ${C.wire}` }}>
      {head}

      {isFamily && (
        <>
          <p style={{ font: `11px/1.8 ${MONO}`, color: C.dim, margin: '0 0 10px', maxWidth: '68ch' }}>
            {t.familyIntro}
          </p>
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            {[
              { n: `${FAMILY_TOTALS.tierE}/${FAMILY_TOTALS.catalog}`, l: t.onSilicon, c: C.green },
              { n: String(FAMILY_TOTALS.decodeHw), l: t.decodeHw, c: C.green },
              { n: String(FAMILY_TOTALS.addHw), l: t.addHw, c: C.green },
              { n: String(FAMILY_TOTALS.mulHw), l: t.mulHw, c: C.green },
              { n: String(FAMILY_TOTALS.swBitexact), l: t.swOnly, c: C.dim },
              { n: String(FAMILY_TOTALS.structural), l: t.structural, c: C.amber },
            ].map((s) => (
              <div key={s.l} style={{
                border: `1px solid ${C.wire}`, borderRadius: 4, padding: '9px 11px',
                background: C.panel, minWidth: 150, flex: '1 1 150px',
              }}>
                <div style={{ font: `600 15px ${MONO}`, color: s.c }}>{s.n}</div>
                <div style={{ font: `9.5px/1.5 ${MONO}`, color: C.dim, marginTop: 3 }}>{s.l}</div>
              </div>
            ))}
          </div>
        </>
      )}

      {record && (
        <>
          <div style={{ font: `10px ${MONO}`, color: C.dim, marginBottom: 7 }}>{t.ops}</div>
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            {record.cells.map((c) => (
              <OpCell key={c.op} cell={c} lang={l} formal={proven.includes(c.op)} />
            ))}
          </div>

          {proven.length > 0 && (
            <div style={{ font: `10px/1.7 ${MONO}`, color: LEVEL_COLOR.formal, marginTop: 10 }}>
              {t.formalNote} {proven.join(', ')}
            </div>
          )}

          {record.caseStudy && (
            <div style={{
              marginTop: 14, padding: '10px 12px', background: C.panel,
              border: `1px solid ${C.wire}`, borderLeft: `2px solid ${C.amber}`, borderRadius: 4,
            }}>
              <div style={{ font: `600 10px ${MONO}`, color: C.amber, letterSpacing: '.06em' }}>
                {t.caught}
              </div>
              <p style={{ font: `11px/1.8 ${MONO}`, color: C.ink, margin: '6px 0 0', maxWidth: '72ch' }}>
                {record.caseStudy[l]}
              </p>
            </div>
          )}

          <div style={{ font: `10px ${MONO}`, color: C.dim, margin: '16px 0 7px' }}>
            {t.chainTitle}
          </div>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
            {CHAIN.map((s, i) => (
              <span key={s.id} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{
                  font: `10px ${MONO}`, color: C.green, border: `1px solid ${C.green}44`,
                  borderRadius: 3, padding: '4px 9px', background: C.panel,
                }}>
                  {s[l]}
                </span>
                {i < CHAIN.length - 1 && <span style={{ color: C.wire }}>→</span>}
              </span>
            ))}
          </div>
        </>
      )}

      <div style={{ font: `10px/1.7 ${MONO}`, marginTop: 16 }}>
        <Row label={t.device} value={`${DEVICE.board} · ${DEVICE.part} · IDCODE ${DEVICE.idcode}`} />
        <Row label="" value={`${DEVICE.clock} · ${DEVICE.uart}`} />
        <Row label={t.toolchain} value={`${TOOLCHAIN.synth} → ${TOOLCHAIN.pnr} → ${TOOLCHAIN.db} · ${TOOLCHAIN.flash}`} />
        <Row label={t.oracle} value={TOOLCHAIN.oracle} />
      </div>

      <p style={{
        font: `10px/1.75 ${MONO}`, color: C.amber, margin: '14px 0 0',
        paddingTop: 10, borderTop: `1px solid ${C.wire}`, maxWidth: '76ch',
      }}>
        {t.disclaimer}
      </p>
    </div>
  )
}

export const SpecSiliconHistory = memo(SpecSiliconHistoryImpl)
