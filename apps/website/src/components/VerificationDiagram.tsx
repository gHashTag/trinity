import { memo } from 'react'
import { useI18n } from '../i18n/context'

/**
 * The argument for this service, drawn.
 *
 * The service rests on one idea that is hard to convey in a paragraph: a
 * testbench written from the same assumptions as the design agrees with the
 * design's bugs, so the check has to be derived independently. That is a claim
 * about the *shape* of the process, which is exactly what a diagram carries
 * better than prose — two paths from one specification, meeting at a comparison,
 * versus one path checking itself.
 *
 * Drawn as inline SVG rather than an image so it inherits the page's colours,
 * scales without a second asset, and stays readable to a screen reader through
 * its title and description.
 */

const EN = {
  usualTitle: 'The usual way',
  usualNote: 'One source of truth. A wrong assumption passes both.',
  thisTitle: 'How I check it',
  thisNote: 'Two independent derivations. A wrong assumption diverges.',
  spec: 'Specification',
  specSub: 'what it should do',
  rtl: 'Your RTL',
  rtlSub: 'your reading of it',
  tb: 'Testbench',
  tbSub: 'written from the RTL',
  model: 'Reference model',
  modelSub: 'written from the spec, not your code',
  agree: 'Agrees',
  agreeSub: 'including on the bug',
  compare: 'Bit-exact comparison',
  compareSub: 'per pipeline stage, known-answer vectors',
  stages: [
    ['Simulate', 'iverilog'],
    ['Synthesise', 'latch + resource check'],
    ['Place & route', 'real device'],
    ['Board', 'same vectors again'],
  ],
  caption: 'Simulation agreement does not prove silicon agreement — synthesis, place-and-route and timing all get a vote, so the vectors run again on the board.',
  scrollHint: 'Scroll the diagram sideways to see both halves.',
  alt: 'Two diagrams side by side. On the left, the usual approach: a specification produces the RTL, and a testbench written from that RTL agrees with it, including on any bug. On the right, this approach: the specification independently produces both the RTL and a reference model, which are compared bit-exactly per pipeline stage, then carried through simulation, synthesis, place-and-route and a run on the board.',
}

const RU: typeof EN = {
  usualTitle: 'Как делают обычно',
  usualNote: 'Один источник истины. Неверная предпосылка проходит оба.',
  thisTitle: 'Как проверяю я',
  thisNote: 'Два независимых вывода. Неверная предпосылка расходится.',
  spec: 'Спецификация',
  specSub: 'что должно делать',
  rtl: 'Ваш RTL',
  rtlSub: 'ваше её прочтение',
  tb: 'Тестбенч',
  tbSub: 'написан по RTL',
  model: 'Эталонная модель',
  modelSub: 'написана по спецификации, не по коду',
  agree: 'Сходится',
  agreeSub: 'в том числе на баге',
  compare: 'Побитовая сверка',
  compareSub: 'по ступеням, векторы с известным ответом',
  stages: [
    ['Симуляция', 'iverilog'],
    ['Синтез', 'защёлки и ресурсы'],
    ['Разводка', 'реальное устройство'],
    ['Плата', 'те же векторы снова'],
  ],
  caption: 'Согласие в симуляции не доказывает согласия на кремнии: синтез, разводка и тайминг тоже имеют голос — поэтому векторы прогоняются на плате заново.',
  scrollHint: 'Схема прокручивается по горизонтали — так видны обе половины.',
  alt: 'Две схемы рядом. Слева обычный подход: из спецификации получается RTL, а тестбенч, написанный по этому RTL, с ним соглашается — включая любой баг. Справа этот подход: из спецификации независимо получаются и RTL, и эталонная модель, которые сверяются побитово по ступеням конвейера, а затем проходят симуляцию, синтез, разводку и прогон на плате.',
}

function Box({
  x, y, w = 150, h = 46, title, sub, tone = 'plain',
}: {
  x: number; y: number; w?: number; h?: number; title: string; sub?: string
  tone?: 'plain' | 'accent' | 'muted'
}) {
  const stroke = tone === 'accent' ? 'var(--accent)' : 'var(--border)'
  const fill = tone === 'muted' ? 'rgba(127,127,127,0.06)' : 'rgba(127,127,127,0.10)'
  const titleFill = tone === 'accent' ? 'var(--accent)' : 'var(--text)'
  return (
    <g>
      <rect x={x} y={y} width={w} height={h} rx={9} fill={fill} stroke={stroke} strokeWidth={tone === 'accent' ? 1.6 : 1} />
      <text x={x + w / 2} y={sub ? y + 20 : y + h / 2 + 4} textAnchor="middle" fill={titleFill} fontSize="12.5" fontWeight="600">
        {title}
      </text>
      {sub && (
        <text x={x + w / 2} y={y + 34} textAnchor="middle" fill="var(--muted)" fontSize="10">
          {sub}
        </text>
      )}
    </g>
  )
}

function Arrow({ x1, y1, x2, y2, dashed = false, label }: { x1: number; y1: number; x2: number; y2: number; dashed?: boolean; label?: string }) {
  return (
    <g>
      <line
        x1={x1} y1={y1} x2={x2} y2={y2}
        stroke={dashed ? 'var(--muted)' : 'var(--accent)'}
        strokeWidth={1.4}
        strokeDasharray={dashed ? '5 4' : undefined}
        markerEnd={dashed ? 'url(#tipMuted)' : 'url(#tipAccent)'}
        opacity={dashed ? 0.8 : 1}
      />
      {label && (
        <text x={(x1 + x2) / 2 + 6} y={(y1 + y2) / 2 - 5} fill="var(--muted)" fontSize="9.5">
          {label}
        </text>
      )}
    </g>
  )
}

export default memo(function VerificationDiagram() {
  const { lang } = useI18n()
  const c = lang === 'ru' ? RU : EN

  return (
    <figure style={{ margin: '0 0 1rem', maxWidth: '100%' }}>
      {/* The diagram cannot reflow, and scaled to a phone its 9px labels would be
          unreadable, so on a narrow screen it scrolls rather than shrinks. The hint
          below says so, because a silent scroll container reads as a cropped image. */}
      <div style={{ overflowX: 'auto', width: '100%' }}>
        <svg
          viewBox="0 0 900 470"
          role="img"
          aria-labelledby="vdiag-title vdiag-desc"
          style={{ width: '100%', maxWidth: '900px', minWidth: '580px', height: 'auto', display: 'block', margin: '0 auto' }}
        >
          <title id="vdiag-title">{c.thisTitle}</title>
          <desc id="vdiag-desc">{c.alt}</desc>

          <defs>
            <marker id="tipAccent" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
              <path d="M 0 0 L 10 5 L 0 10 z" fill="var(--accent)" />
            </marker>
            <marker id="tipMuted" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
              <path d="M 0 0 L 10 5 L 0 10 z" fill="var(--muted)" />
            </marker>
          </defs>

          {/* ── Left: the usual way, drawn faintly because it is the thing being argued against ── */}
          <text x="20" y="26" fill="var(--muted)" fontSize="11" letterSpacing="1.6" style={{ textTransform: 'uppercase' }}>
            {c.usualTitle}
          </text>
          <line x1="20" y1="36" x2="330" y2="36" stroke="var(--border)" strokeWidth="1" />

          <g opacity="0.62">
            <Box x={95} y={54} title={c.spec} sub={c.specSub} tone="muted" />
            <Arrow x1={170} y1={100} x2={170} y2={126} dashed />
            <Box x={95} y={128} title={c.rtl} sub={c.rtlSub} tone="muted" />
            <Arrow x1={170} y1={174} x2={170} y2={200} dashed label={c.tbSub} />
            <Box x={95} y={202} title={c.tb} tone="muted" />
            <Arrow x1={170} y1={248} x2={170} y2={274} dashed />
            <Box x={95} y={276} title={c.agree} sub={c.agreeSub} tone="muted" />
          </g>
          <text x="175" y="352" textAnchor="middle" fill="var(--muted)" fontSize="10.5">
            {c.usualNote.length > 46 ? c.usualNote.slice(0, c.usualNote.indexOf('.') + 1) : c.usualNote}
          </text>
          <text x="175" y="366" textAnchor="middle" fill="var(--muted)" fontSize="10.5">
            {c.usualNote.length > 46 ? c.usualNote.slice(c.usualNote.indexOf('.') + 2) : ''}
          </text>

          {/* divider */}
          <line x1="368" y1="20" x2="368" y2="400" stroke="var(--border)" strokeWidth="1" strokeDasharray="3 5" />

          {/* ── Right: two independent derivations from one specification ── */}
          <text x="404" y="26" fill="var(--accent)" fontSize="11" letterSpacing="1.6" style={{ textTransform: 'uppercase' }}>
            {c.thisTitle}
          </text>
          <line x1="404" y1="36" x2="880" y2="36" stroke="var(--accent)" strokeWidth="1" opacity="0.5" />

          <Box x={567} y={54} title={c.spec} sub={c.specSub} tone="accent" />

          {/* the split: one spec, two independent readings */}
          <line x1="642" y1="100" x2="642" y2="114" stroke="var(--accent)" strokeWidth="1.4" />
          <line x1="492" y1="114" x2="792" y2="114" stroke="var(--accent)" strokeWidth="1.4" />
          <Arrow x1={492} y1={114} x2={492} y2={150} />
          <Arrow x1={792} y1={114} x2={792} y2={150} />

          <Box x={417} y={152} title={c.rtl} sub={c.rtlSub} />
          <Box x={717} y={152} title={c.model} sub={c.modelSub} tone="accent" />

          <Arrow x1={492} y1={198} x2={492} y2={232} />
          <Arrow x1={792} y1={198} x2={792} y2={232} />
          <line x1="492" y1="232" x2="792" y2="232" stroke="var(--accent)" strokeWidth="1.4" />
          <Arrow x1={642} y1={232} x2={642} y2={252} />

          <Box x={532} y={254} w={220} h={48} title={c.compare} sub={c.compareSub} tone="accent" />

          {/* the four stages the vectors travel through */}
          <Arrow x1={642} y1={302} x2={642} y2={324} />
          {c.stages.map(([name, note], i) => {
            const x = 404 + i * 122
            return (
              <g key={name}>
                <rect x={x} y={326} width={110} height={40} rx={8} fill="rgba(127,127,127,0.10)" stroke="var(--border)" />
                <text x={x + 55} y={344} textAnchor="middle" fill="var(--text)" fontSize="11" fontWeight="600">{name}</text>
                <text x={x + 55} y={357} textAnchor="middle" fill="var(--muted)" fontSize="9">{note}</text>
                {i < 3 && <Arrow x1={x + 110} y1={346} x2={x + 120} y2={346} />}
              </g>
            )
          })}

          <text x="642" y="398" textAnchor="middle" fill="var(--accent)" fontSize="10.5" fontWeight="600">
            {c.thisNote}
          </text>
        </svg>
      </div>
      <p className="diagram-scroll-hint" style={{ fontSize: '0.75rem', opacity: 0.6, margin: '0.5rem 0 0', textAlign: 'center' }}>
        {c.scrollHint}
      </p>
      <figcaption style={{ fontSize: '0.86rem', lineHeight: 1.5, color: 'var(--muted)', marginTop: '0.75rem', maxWidth: '60ch', marginLeft: 'auto', marginRight: 'auto' }}>
        {c.caption}
      </figcaption>
    </figure>
  )
})
