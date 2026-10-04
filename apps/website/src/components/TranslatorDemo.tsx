'use client';

// One t27 source, compiled in the browser by the real t27 compiler
// (public/t27/t27_compiler.wasm), shown in each backend it emits.
//
// Until 2026-10-04 this panel was a "Universal Translator" between Python, C++,
// Go, VHDL, Coptic CIS and seven more, and whatever was picked it printed the
// same hard-coded Verilog module after a 1.5 s timer. t27c reads only t27 and
// writes only the backends in TARGET_IDS, so the panel now asks the compiler
// instead of claiming for it. The backend list is TARGET_IDS -- the ids the
// compiler keys its output by -- not a list kept here.

import { useCallback, useEffect, useState, type CSSProperties } from 'react';
import { Link } from 'react-router-dom';
import { useI18n } from '../i18n/context';
import {
  analyzeEdited,
  TARGET_IDS,
  TARGET_LABEL,
  type T27Analysis,
  type TargetId,
} from '../lib/t27Compiler';

const UI = {
  en: {
    source: 't27 source',
    output: 'Compiler output',
    compile: 'Compile',
    compiling: 'Compiling...',
    reset: 'Reset sample',
    parseFailed: 'The source does not parse',
    backendFailed: 'This backend refused the source',
    notCompiled: 'Not compiled yet',
    compiled: 'compiled',
    of: 'of',
    backends: 'backends',
    lead: 'The t27 compiler, running in your browser. It reads t27 and writes these backends, nothing else.',
    explorer: 'Every spec in the corpus, layer by layer',
  },
  ru: {
    source: 'Исходник t27',
    output: 'Вывод компилятора',
    compile: 'Скомпилировать',
    compiling: 'Компиляция...',
    reset: 'Вернуть пример',
    parseFailed: 'Исходник не разбирается',
    backendFailed: 'Этот бэкенд не принял исходник',
    notCompiled: 'Ещё не скомпилировано',
    compiled: 'скомпилировано',
    of: 'из',
    backends: 'бэкендов',
    lead: 'Компилятор t27 прямо в браузере. Он читает t27 и пишет только эти бэкенды.',
    explorer: 'Все спецификации корпуса, слой за слоем',
  },
} as const;

// Checked against the wasm compiler on 2026-10-04: parses with nothing
// discarded, typechecks clean, and every backend in TARGET_IDS accepts it.
const SAMPLE = `module trit_mul;

; A trit is -1, 0 or +1, so multiplying two of them is a sign
; comparison -- no multiplier needed. Edit this and recompile.

fn trit_mul(a: i8, b: i8) -> i8 {
    if a == 0 { return 0; }
    if b == 0 { return 0; }
    if a == b { return 1; }
    return -1;
}

; on_comb is the module's hardware surface: in Verilog its
; parameters become input ports and its result an output.
fn on_comb(a: i8, b: i8) -> i8 {
    return trit_mul(a, b);
}

test same_sign { assert trit_mul(-1, -1) == 1; }
test opposite_sign { assert trit_mul(1, -1) == -1; }
test zero_absorbs { assert trit_mul(0, 1) == 0; }
`;

// Inline, like the rest of QuantumLab: this site has no Tailwind, so the
// utility classes the old panel was written in styled nothing -- and its one
// real class, `fade`, waits for a `.visible` ancestor QuantumLab never sets,
// which kept the old panel at opacity 0 for as long as it existed.
const mono = "var(--mono, 'JetBrains Mono', ui-monospace, monospace)";
const S = {
  wrap: { maxWidth: 1100, margin: '0 auto', padding: '0 1rem 9rem', color: 'var(--text)', textAlign: 'left' },
  lead: {
    fontSize: 14,
    color: 'var(--text)',
    background: 'rgba(0, 0, 0, 0.72)',
    border: '1px solid var(--border)',
    borderRadius: 10,
    padding: '10px 14px',
    margin: '0 0 14px',
  },
  grid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 420px), 1fr))', gap: 16 },
  panel: {
    background: 'rgba(5, 8, 12, 0.9)',
    border: '1px solid rgba(255, 255, 255, 0.12)',
    borderRadius: 12,
    padding: 14,
    minWidth: 0,
    display: 'flex',
    flexDirection: 'column',
  },
  head: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    flexWrap: 'wrap',
    gap: 8,
    borderBottom: '1px solid var(--border)',
    paddingBottom: 8,
    marginBottom: 10,
  },
  label: { fontSize: 12, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--muted)' },
  count: { fontSize: 12, color: 'var(--muted)' },
  row: { display: 'flex', gap: 6 },
  button: (on: boolean): CSSProperties => ({
    background: 'transparent',
    border: `1px solid ${on ? 'var(--accent)' : 'rgba(255, 255, 255, 0.18)'}`,
    color: on ? 'var(--accent)' : 'var(--muted)',
    borderRadius: 6,
    padding: '4px 10px',
    fontSize: 12,
    cursor: 'pointer',
  }),
  editor: {
    width: '100%',
    height: 380,
    background: 'transparent',
    color: 'var(--text)',
    fontFamily: mono,
    fontSize: 13,
    lineHeight: 1.5,
    border: 'none',
    outline: 'none',
    resize: 'vertical',
  },
  output: {
    height: 380,
    overflow: 'auto',
    margin: 0,
    fontFamily: mono,
    fontSize: 12,
    lineHeight: 1.45,
    whiteSpace: 'pre',
  },
} satisfies Record<string, CSSProperties | ((on: boolean) => CSSProperties)>;

export default function TranslatorDemo() {
  const { lang } = useI18n();
  const ui = lang === 'ru' ? UI.ru : UI.en;

  const [code, setCode] = useState(SAMPLE);
  const [target, setTarget] = useState<TargetId>('verilog');
  const [result, setResult] = useState<T27Analysis | null>(null);
  const [failure, setFailure] = useState('');
  const [busy, setBusy] = useState(false);

  const compile = useCallback(async (source: string) => {
    setBusy(true);
    setFailure('');
    try {
      setResult(await analyzeEdited(source));
    } catch (err) {
      setResult(null);
      setFailure(err instanceof Error ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  }, []);

  useEffect(() => {
    void compile(SAMPLE);
  }, [compile]);

  const okCount = result ? TARGET_IDS.filter((id) => result.targets[id]?.ok).length : 0;
  const selected = result?.targets[target];

  let output: string;
  if (failure) output = failure;
  else if (!result) output = ui.notCompiled;
  else if (result.astError) output = `${ui.parseFailed}:\n${result.astError}`;
  else if (selected?.ok) output = selected.code ?? '';
  else output = `${ui.backendFailed}:\n${selected?.error ?? ''}`;

  const failed = Boolean(failure || result?.astError || (result && !selected?.ok));

  return (
    <div style={S.wrap}>
      <p style={S.lead}>{ui.lead}</p>

      <div style={S.grid}>
        <div style={S.panel}>
          <div style={S.head}>
            <span style={S.label}>{ui.source}</span>
            <span style={S.row}>
              <button
                type="button"
                onClick={() => {
                  setCode(SAMPLE);
                  void compile(SAMPLE);
                }}
                style={S.button(false)}
              >
                {ui.reset}
              </button>
              <button type="button" onClick={() => void compile(code)} disabled={busy} style={S.button(true)}>
                {busy ? ui.compiling : ui.compile}
              </button>
            </span>
          </div>
          <textarea
            data-lang-exempt
            value={code}
            onChange={(e) => setCode(e.target.value)}
            spellCheck={false}
            wrap="off"
            aria-label={ui.source}
            style={S.editor}
          />
        </div>

        <div style={S.panel}>
          <div style={S.head}>
            <span style={S.label}>{ui.output}</span>
            <span style={S.count}>
              {result ? `${okCount} ${ui.of} ${TARGET_IDS.length} ${ui.backends} ${ui.compiled}` : ''}
            </span>
          </div>
          <div style={{ ...S.row, flexWrap: 'wrap', marginBottom: 10 }} role="tablist" aria-label={ui.output}>
            {TARGET_IDS.map((id) => {
              const state = result?.targets[id];
              return (
                <button
                  key={id}
                  type="button"
                  role="tab"
                  aria-selected={id === target}
                  onClick={() => setTarget(id)}
                  style={S.button(id === target)}
                >
                  {state && !state.ok ? '\u2715 ' : ''}
                  {TARGET_LABEL[id]}
                </button>
              );
            })}
          </div>
          <pre data-lang-exempt style={{ ...S.output, color: failed ? '#f87171' : 'var(--accent)' }}>
            {output}
          </pre>
        </div>
      </div>

      <p style={{ textAlign: 'center', marginTop: 16 }}>
        <Link to="/specs" style={{ color: 'var(--accent)', fontSize: 14 }}>
          {ui.explorer} →
        </Link>
      </p>
    </div>
  );
}
