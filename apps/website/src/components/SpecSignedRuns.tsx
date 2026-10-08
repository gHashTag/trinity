// Signed runs on silicon of the Verilog THIS spec compiles to, exactly as t27c judged them
// (gHashTag/t27#7723). The judgment is data written by `t27c run-record --json` and vendored
// with the corpus (docs/reports/silicon-runs/index.json, cited by specs/verified/silicon_runs.t27).
// Nothing here re-judges a receipt: every verdict word on this panel is t27c's own.
import { memo, useEffect, useState } from 'react'
import { useI18n } from '../i18n/context'

interface Receipt { file: string; auth: string; device_dna: string | null; seeds: number[] | null; verdict_word: number | null; toolchain: string | null; key_id: string | null }
interface Run { spec: string; receipts_dir: string; challenge: string | null; judged_by: string; authentication: string; die: string; independence: string; citable: boolean; first_missing: string; receipts: Receipt[] }

let index: Promise<Run[]> | null = null
const loadRuns = (): Promise<Run[]> =>
  (index ??= fetch('t27/files/docs/reports/silicon-runs/index.json', { credentials: 'omit' })
    .then((r) => (r.ok ? r.json() : [])).catch(() => []))

const T = {
  en: { title: 'SIGNED RUNS ON SILICON', note: 'Verilog compiled from this spec, run on the die. Judged by', citable: 'citable', notCitable: 'not citable', auth: 'auth', die: 'die', indep: 'independence', seeds: 'seeds', key: 'key', pass: 'PASS', fail: 'FAIL', verify: 'Re-check it yourself:' },
  ru: { title: 'ПОДПИСАННЫЕ ПРОГОНЫ НА КРЕМНИИ', note: 'Verilog, скомпилированный из этой спеки, выполнен на кристалле. Вердикт вынес', citable: 'можно цитировать', notCitable: 'нельзя цитировать', auth: 'подпись', die: 'кристалл', indep: 'независимость', seeds: 'сиды', key: 'ключ', pass: 'ВЕРНО', fail: 'ОШИБКА', verify: 'Перепроверьте сами:' },
}
const MONO = "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace"

function SpecSignedRunsImpl({ specPath }: { specPath: string }) {
  const { lang } = useI18n()
  const t = lang === 'ru' ? T.ru : T.en
  const [runs, setRuns] = useState<Run[]>([])
  useEffect(() => {
    let live = true
    loadRuns().then((all) => { if (live) setRuns(all.filter((r) => r.spec === specPath)) })
    return () => { live = false }
  }, [specPath])
  if (!runs.length) return null
  return (
    <div style={{ marginTop: 18, paddingTop: 14, borderTop: '1px solid #1d2a20', font: `11px/1.7 ${MONO}`, color: '#d7e0d8' }}>
      <div style={{ font: `600 12px ${MONO}`, color: '#FFD700', letterSpacing: '.08em', marginBottom: 8 }}>{t.title}</div>
      {runs.map((run) => (
        <div key={run.receipts_dir} style={{ marginBottom: 14 }}>
          <div style={{ color: '#8b9490' }}>{t.note} {run.judged_by} · {run.receipts_dir}</div>
          <div>
            <span style={{ color: run.citable ? '#00FF88' : '#a87a4a' }}>{run.citable ? t.citable : `${t.notCitable}: ${run.first_missing}`}</span>
            {' · '}{t.auth} {run.authentication} · {t.die} {run.die}
          </div>
          <div style={{ color: '#8b9490' }}>{t.indep}: {run.independence}</div>
          {run.receipts.map((r) => (
            <div key={r.file}>
              {t.seeds} {r.seeds?.join(',') ?? '-'} · DNA {r.device_dna ?? '-'} · {r.verdict_word === 0 ? t.pass : r.verdict_word === 1 ? t.fail : '-'} · {r.auth} · {t.key} {r.key_id ?? '-'} · {r.toolchain ?? '-'}
            </div>
          ))}
          <div style={{ color: '#8b9490' }}>{t.verify} <code>t27c run-record {run.spec}{run.challenge ? ` --challenge ${run.challenge}` : ''} --receipts {run.receipts_dir}</code></div>
        </div>
      ))}
    </div>
  )
}

export const SpecSignedRuns = memo(SpecSignedRunsImpl)
