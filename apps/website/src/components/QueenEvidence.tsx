import { queenEvidence as e } from '../lib/queenEvidence.generated';
import './QueenEvidence.css';

export function QueenEvidence({ lang }: { lang: 'en' | 'ru' }) {
  const ru = lang === 'ru';
  const report = `https://github.com/${e.REPO}/tree/${e.MERGE}/${e.REPORT_PATH}`;
  const number = (value: number) => value.toLocaleString(ru ? 'ru-RU' : 'en-US');
  const seconds = (clocks: number) => (clocks / e.CLOCK_HZ).toFixed(2);
  const share = (clocks: number) => (100 * clocks / e.TOTAL_CLOCKS).toFixed(2);
  const levels = ru ? ['Исполняемая спецификация', 'Симуляция с эталоном', 'Проверки CI', 'Захват с физической платы', 'Внешнее подтверждение'] : ['Executable specification', 'Simulation against an oracle', 'CI checks', 'Physical board capture', 'External confirmation'];
  return <details className="queen-evidence">
    <summary><strong>{ru ? 'Подтверждённые результаты' : 'Verified results'}</strong><span>AX7203 · {number(e.VALUES_TOTAL)} {ru ? 'точных значений' : 'exact values'}</span></summary>
    <div className="queen-evidence-body">
      <section aria-label={ru ? 'Проверка на FPGA' : 'FPGA evidence'}>
        <h3>FFN · AX7203 <time dateTime={e.DATE}>{e.DATE}</time></h3>
        <p>{ru ? 'Два вектора (seed27 и zero): ' : 'Two vectors (seed27 and zero): '}{e.RUNS} × {number(e.VALUES_PER_RUN)} = {number(e.VALUES_TOTAL)} {ru ? 'промежуточных значений точно совпали с целочисленным эталоном. Насыщений нет.' : 'stage values match the integer oracle exactly. No saturations.'}</p>
        <dl>
          <div><dt>{ru ? 'Вычисление' : 'Compute'}</dt><dd>{seconds(e.COMPUTE_CLOCKS)} s · {share(e.COMPUTE_CLOCKS)}%</dd></div>
          <div><dt>{ru ? 'Ожидание DDR3' : 'DDR3 wait'}</dt><dd>{share(e.MEMORY_CLOCKS)}%</dd></div>
          <div><dt>{ru ? 'Вывод UART' : 'UART report'}</dt><dd>{share(e.REPORT_CLOCKS)}%</dd></div>
          <div><dt>{ru ? 'Весь прогон seed27' : 'Full seed27 run'}</dt><dd>{seconds(e.TOTAL_CLOCKS)} s</dd></div>
        </dl>
        <p className="queen-evidence-note">{ru ? 'Время = такты / 60 000 000; доли = такты / все такты seed27. Q16.16/Q32.32, слой 0. Не проверены ActQuant/bf16, attention, residual и полный инференс модели. Повреждённые CRC-кадры повторно запрошены и исключены из проверки.' : 'Time = clocks / 60,000,000; shares use the seed27 total. Layer 0, Q16.16/Q32.32. ActQuant/bf16, attention, residuals and full-model inference are outside this check. CRC-rejected frames were re-requested and excluded from verification.'}</p>
        <nav aria-label={ru ? 'Источники FFN' : 'FFN sources'}><a href={report} target="_blank" rel="noopener noreferrer">{ru ? 'Захваты и независимая проверка' : 'Captures and independent replay'}</a><a href={`https://github.com/${e.REPO}/pull/93`} target="_blank" rel="noopener noreferrer">PR #93</a><a href={`https://github.com/${e.REPO}/pull/95`} target="_blank" rel="noopener noreferrer">PR #95</a></nav>
      </section>
      <section aria-label="Ternary Check Live">
        <h3>Ternary Check Live <time dateTime={e.SCAN_DATE}>{e.SCAN_DATE}</time></h3>
        <p>{number(e.SCAN_MODELS)} {ru ? 'модель' : 'models'} · {number(e.SCAN_REPOSITORIES)} {ru ? 'репозиториев' : 'repositories'} · {number(e.SCAN_FILES)} {ru ? 'файлов GGUF' : 'GGUF files'}</p>
        <p className="queen-evidence-note">{ru ? 'Снимок проверки заголовков на закреплённых версиях ридеров. Проверяет совместимость загрузки, не качество или скорость модели. Актуальные результаты и версии — в таблице.' : 'Header compatibility snapshot against pinned readers. This checks loading compatibility, not model quality or speed. The table carries current results and reader revisions.'}</p>
        <nav aria-label={ru ? 'Проверить GGUF' : 'Check GGUF'}><a href={e.LIVE_URL} target="_blank" rel="noopener noreferrer">{ru ? 'Открыть таблицу' : 'Open live table'}</a><a href={`${e.LIVE_URL}check.html`} target="_blank" rel="noopener noreferrer">{ru ? 'Проверить файл в браузере' : 'Check a file in the browser'}</a><a href={`https://github.com/${e.REPO}/blob/master/docs/live/findings.md`} target="_blank" rel="noopener noreferrer">{ru ? 'Журнал находок и ответы' : 'Findings and responses'}</a></nav>
      </section>
      <section className="queen-evidence-levels" aria-label={ru ? 'Уровни доказательств' : 'Evidence levels'}>
        <h3>{ru ? 'Что подтверждает отметка' : 'What an evidence level means'}</h3>
        <dl>{e.LEVELS.map((level, i) => <div key={level}><dt>{level}</dt><dd>{levels[i]}</dd></div>)}</dl>
        <p className="queen-evidence-note">{ru ? 'Каждый уровень требует собственного источника. Легенда не присваивает отметки сотам; наличие спеки не подтверждает CI, железо или ответ внешнего владельца.' : 'Each level needs its own receipt. This legend does not assign levels to cells; a spec alone does not establish CI, board evidence or an external owner response.'}</p>
      </section>
    </div>
  </details>;
}
