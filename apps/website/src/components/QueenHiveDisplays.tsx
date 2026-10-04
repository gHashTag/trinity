import { useEffect, useMemo, useRef, type CSSProperties } from 'react';
import type { HudEvent } from './queenHud';
import { HIVE_TASK_PALETTE, hiveEventSignal, hiveTaskPaint, hiveTaskCounts, hiveDisplayEvents, hiveDisplayLod, hiveEpicProgress, hiveIssueUrl, type HiveDisplay, type HiveDisplayProjection, type HiveSignalHealth } from './queenHiveDisplay';

export interface HiveDisplayController { inspect(index: number): void; overview(): void; hover(index: number | null): void }
const WORDS = {
  // GitHub titles are quoted source, never silently translated or renamed.
  en: { inspect:'Inspect cell', overview:'Whole hive', choose:'Choose issue or epic', issue:'Issue', epic:'Epic', events:'Latest events', empty:'No events in the public feed', open:'Open in GitHub', children:'Children complete', unknown:'Coverage unknown', hint:'Tap a cell to inspect · wheel / + − to zoom', closed:'Closed', openState:'Open', running:'Running', review:'Review', backlog:'Backlog', blocked:'Blocked', dropped:'Dropped', dispatch:'Dispatched', progress:'Progress', tool:'Tool', result:'Result', usage:'Usage', error:'Error', finished:'Finished', reviewEvent:'Queen review' },
  ru: { inspect:'Рассмотреть соту', overview:'Весь улей', choose:'Выбрать задачу или эпик', issue:'Задача', epic:'Эпик', events:'Последние события', empty:'В публичной ленте нет событий', open:'Открыть в GitHub', children:'Завершено задач', unknown:'Покрытие неизвестно', hint:'Тап по соте — крупный план · колесо / + − — масштаб', closed:'Закрыто', openState:'Открыто', running:'В работе', review:'Ревью', backlog:'Беклог', blocked:'Блокер', dropped:'Отложено', dispatch:'Назначена', progress:'Прогресс', tool:'Инструмент', result:'Результат', usage:'Метрики', error:'Ошибка', finished:'Завершена', reviewEvent:'Ревью Queen' },
};

const TASK_WORDS = {
  en: { problem:'Goal pending', blocked:'Blocker / failure', active:'Running', review:'Queen review', paused:'Paused', honey:'Honey · T27', work:'Needs work', proof:'T27 proof needed', running:'In progress', verified:'T27 verified', guide:'Signals', fill:'Cell fill · current task state', event:'Inner ring · fresh event, not completion', accepted:'Review approved', result:'Result received', live:'Live', stale:'Stale · last known data', unknown:'No data yet', board:'Board', activity:'Events', note:'Honey requires completion and T27 proof. A closed issue alone is not proof. Honey outer rim means hover/selection only. Signals also carry symbols/text; reduced-motion keeps them static.' },
  ru: { problem:'Цель не достигнута', blocked:'Блокер / ошибка', active:'Выполняется', review:'Ревью Королевы', paused:'Пауза', honey:'Мёд · T27', work:'Нужна работа', proof:'Нужно доказательство T27', running:'В работе', verified:'T27 подтверждено', guide:'Сигналы', fill:'Заливка соты · состояние задачи', event:'Внутренний контур · новое событие, не завершение', accepted:'Ревью принято', result:'Получен результат', live:'Связь есть', stale:'Устарело · последние известные данные', unknown:'Данных ещё нет', board:'Карта', activity:'События', note:'Мёд требует завершения и доказательства T27. Одного закрытия issue недостаточно. Медовый внешний контур — только наведение/выбор. Цвет дублируется символами и текстом; при уменьшении движения сигналы статичны.' },
};

export function QueenHiveTaskLegend({ rows, lang, health }: { rows: readonly (HiveDisplay | null)[]; lang: 'ru' | 'en'; health: HiveSignalHealth }) {
  const counts = hiveTaskCounts(rows);
  const words = TASK_WORDS[lang];
  const tones = Object.keys(HIVE_TASK_PALETTE) as (keyof typeof HIVE_TASK_PALETTE)[];
  return <div className="queen27-hive-law queen-hive-task-law" role="group" aria-label={words.fill}>
    <details className="queen-hive-signal-guide" onKeyDown={event=>{if(event.key==='Escape') event.currentTarget.open=false;}}>
      <summary>{words.guide}</summary>
      <div className="queen-hive-signal-panel">
        <h4>{words.fill}</h4>
        {tones.map(tone=><p key={tone} style={{color:HIVE_TASK_PALETTE[tone].hex}}><b>{HIVE_TASK_PALETTE[tone].symbol}</b> {words[tone]} <strong>{counts[tone]}</strong></p>)}
        <h4>{words.event}</h4>
        {(['blocked','accepted','review','result','active'] as const).map(tone=><p key={tone} data-event-tone={tone}>{({blocked:'!',accepted:'✓',review:'◇',result:'↓',active:'→'})[tone]} {tone==='active' ? (lang==='ru'?'Назначение / прогресс / инструмент':'Dispatch / progress / tool') : words[tone]}</p>)}
        <p className="queen-hive-signal-note">{words.note}</p>
      </div>
    </details>
    {tones.filter(tone=>counts[tone]>0 || tone==='honey').map(tone => <span key={tone} data-task-tone={tone} title={words[tone]} aria-label={`${words[tone]}: ${counts[tone]}`} style={{ '--hive-task-rgb': HIVE_TASK_PALETTE[tone].rgb } as CSSProperties}>
      <i aria-hidden="true">{HIVE_TASK_PALETTE[tone].symbol}</i><b>{counts[tone]}</b>
    </span>)}
    {(health.board!=='live'||health.activity!=='live') && <small className="queen-hive-link-health" role="status">{words.board}: {words[health.board]} · {words.activity}: {words[health.activity]}</small>}
  </div>;
}

export function QueenHiveDisplays({ rows, projections, selected, events, lang, controller, onIssueOpen, controls=true, showRepository=false }: {
  rows: readonly (HiveDisplay | null)[]; projections: HiveDisplayProjection[]; selected: number | null;
  events: readonly HudEvent[]; lang: 'ru' | 'en'; controller: HiveDisplayController | null;
  onIssueOpen?: (row:HiveDisplay)=>void;
  controls?: boolean; showRepository?: boolean;
}) {
  const c = { ...WORDS[lang], sourceTitle: lang === 'ru' ? 'Заголовок GitHub — на языке оригинала' : 'GitHub title — original language' };
  const layerRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const layer = layerRef.current; if(!layer) return;
    const onWheel = (event: WheelEvent) => {
      const content = (event.target as Element).closest('.queen-hive-display-content');
      // Read overflowing card text normally; Ctrl+wheel always goes to the map.
      if (content && content.scrollHeight > content.clientHeight && !event.ctrlKey) return;
      event.preventDefault();
      layer.parentElement?.querySelector('canvas')?.dispatchEvent(new WheelEvent('wheel', { clientX:event.clientX,clientY:event.clientY,deltaY:event.deltaY,deltaMode:event.deltaMode,ctrlKey:event.ctrlKey,cancelable:true }));
    };
    layer.addEventListener('wheel',onWheel,{passive:false});
    return () => layer.removeEventListener('wheel',onWheel);
  }, []);
  const available = useMemo(() => rows.flatMap((row,index) => row ? [{row,index}] : []), [rows]);
  const optionNodes = useMemo(() => available.map(({row,index}) => <option key={row.key} value={index} data-lang-exempt="github-title">{row.kind === 'epic' ? '⬡ ' : ''}#{row.number} {row.title}</option>), [available]);
  const allRows = useMemo(() => available.map(v=>v.row), [available]);
  const defaultIndex = useMemo(() => {
    const byNumber = new Map(available.map(v => [v.row.number,v.index]));
    for (const event of [...events].sort((a,b)=>Date.parse(b.at)-Date.parse(a.at))) if(event.issue !== null && byNumber.has(event.issue)) return byNumber.get(event.issue) ?? null;
    return available.at(-1)?.index ?? null;
  }, [available,events]);
  const inspect = (index: number | null) => { if(index !== null) controller?.inspect(index); };
  const stateLabel = (state: string) => ({closed:c.closed,done:c.closed,open:c.openState,running:c.running,review:c.review,backlog:c.backlog,blocked:c.blocked,dropped:c.dropped}[state] ?? state);
  const eventLabel = (event: HudEvent) => event.kind === 'review' ? c.reviewEvent : c[event.kind];
  return <>
    {controls&&<div className="queen-hive-inspect-tools">
      <select aria-label={c.choose} title={c.sourceTitle} value={selected ?? ''} onChange={e => inspect(Number(e.target.value))}>
        <option value="" disabled>{c.choose}</option>
        {optionNodes}
      </select>
      <button type="button" disabled={!controller || defaultIndex === null} onClick={() => inspect(selected ?? defaultIndex)}>{c.inspect}</button>
      <button type="button" onClick={() => controller?.overview()}>{c.overview}</button>
    </div>}
    <div className="queen-hive-displays" ref={layerRef} data-display-count={projections.length}>
      {projections.map(p => {
        const row = rows[p.index]; if (!row) return null;
        const focused = selected === p.index;
        const paint = hiveTaskPaint(row)!;
        const palette = HIVE_TASK_PALETTE[paint.tone];
        const lod = hiveDisplayLod(p.width);
        const recent = hiveDisplayEvents(row, events);
        const progress = row.kind === 'epic' ? hiveEpicProgress(row, allRows) : {done:0,total:0};
        const url = hiveIssueUrl(row.repo,row.number);
        return <article key={row.key} className="queen-hive-display" data-issue={row.number} data-repo={row.repo} data-kind={row.kind} data-lod={lod} data-focused={focused} data-task-tone={paint.tone}
          onClick={event => { if(!(event.target as Element).closest('a,button')) inspect(p.index); }}
          onPointerEnter={() => controller?.hover(p.index)} onPointerLeave={() => controller?.hover(null)}
          style={{left:p.x,top:p.y,width:p.width*.94,height:p.height*.94,'--hive-task-rgb':palette.rgb} as CSSProperties}>
          <div className="queen-hive-display-content">
            {showRepository&&<small className="queen-hive-display-repository">{row.repo}</small>}
            <button type="button" className="queen-hive-display-heading" aria-label={`${c.inspect}: #${row.number} ${row.title}`} onClick={() => inspect(p.index)}>
              <span>{row.kind === 'epic' ? c.epic : c.issue}</span><strong>#{row.number}</strong>
            </button>
            <span className="queen-hive-display-state">{stateLabel(row.state)}</span>
            <span className="queen-hive-task-status"><b aria-hidden="true">{paint.reason==='proof'?'?':palette.symbol}</b> {TASK_WORDS[lang][paint.reason]}</span>
            {(lod === 'title' || lod === 'detail') && <h3 data-lang-exempt="github-title" title={c.sourceTitle}>{row.title}</h3>}
            {lod === 'detail' && <>
              <p className="queen-hive-display-coverage">{c.unknown}</p>
              {row.kind === 'epic' && <div className="queen-hive-epic-progress"><span>{c.children}: {progress.done}/{progress.total}</span>{progress.total > 0 && <progress aria-label={c.children} max={progress.total} value={progress.done}/>}</div>}
              <div className="queen-hive-display-events"><h4>{c.events}</h4>{recent.length ? <ul>{recent.map(e=>{const signal=hiveEventSignal(e);return <li key={`${e.issue}:${e.id}`} data-event-tone={signal.tone}><span><b aria-hidden="true">{signal.symbol}</b> #{e.issue} · {eventLabel(e)}{e.state ? ` · ${e.state}` : ''}</span><time dateTime={e.at}>{new Date(e.at).toLocaleTimeString(lang,{hour:'2-digit',minute:'2-digit',second:'2-digit'})}</time></li>;})}</ul>:<p>{c.empty}</p>}</div>
              {url && (onIssueOpen?<button type="button" onClick={()=>onIssueOpen(row)}>{lang==='ru'?'Обсудить / передать агенту':'Collaborate / hand off'}</button>:<a href={url} target="_blank" rel="noopener noreferrer">{c.open} ↗</a>)}
            </>}
          </div>
        </article>;
      })}
    </div>
    {controls&&<p className="queen-hive-zoom-hint">{c.hint}</p>}
  </>;
}
