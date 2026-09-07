import { useEffect, useMemo, useRef } from 'react';
import type { HudEvent } from './queenHud';
import { hiveDisplayEvents, hiveDisplayLod, hiveEpicProgress, hiveIssueUrl, type HiveDisplay, type HiveDisplayProjection } from './queenHiveDisplay';

export interface HiveDisplayController { inspect(index: number): void; overview(): void; hover(index: number | null): void }
const WORDS = {
  en: { inspect:'Inspect cell', overview:'Whole hive', choose:'Choose issue or epic', issue:'Issue', epic:'Epic', events:'Latest events', empty:'No events in the public feed', open:'Open in GitHub', children:'Children complete', unknown:'Coverage unknown', hint:'Tap a cell to inspect · wheel / + − to zoom', closed:'Closed', openState:'Open', running:'Running', review:'Review', backlog:'Backlog', blocked:'Blocked', dropped:'Dropped', dispatch:'Dispatched', progress:'Progress', tool:'Tool', result:'Result', usage:'Usage', error:'Error', finished:'Finished', reviewEvent:'Queen review' },
  ru: { inspect:'Рассмотреть соту', overview:'Весь улей', choose:'Выбрать задачу или эпик', issue:'Задача', epic:'Эпик', events:'Последние события', empty:'В публичной ленте нет событий', open:'Открыть в GitHub', children:'Завершено задач', unknown:'Покрытие неизвестно', hint:'Тап по соте — крупный план · колесо / + − — масштаб', closed:'Закрыто', openState:'Открыто', running:'В работе', review:'Ревью', backlog:'Беклог', blocked:'Блокер', dropped:'Отложено', dispatch:'Назначена', progress:'Прогресс', tool:'Инструмент', result:'Результат', usage:'Метрики', error:'Ошибка', finished:'Завершена', reviewEvent:'Ревью Queen' },
};

export function QueenHiveDisplays({ rows, projections, selected, events, lang, controller }: {
  rows: readonly (HiveDisplay | null)[]; projections: HiveDisplayProjection[]; selected: number | null;
  events: readonly HudEvent[]; lang: 'ru' | 'en'; controller: HiveDisplayController | null;
}) {
  const c = WORDS[lang];
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
  const optionNodes = useMemo(() => available.map(({row,index}) => <option key={row.key} value={index}>{row.kind === 'epic' ? '⬡ ' : ''}#{row.number} {row.title}</option>), [available]);
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
    <div className="queen-hive-inspect-tools">
      <select aria-label={c.choose} value={selected ?? ''} onChange={e => inspect(Number(e.target.value))}>
        <option value="" disabled>{c.choose}</option>
        {optionNodes}
      </select>
      <button type="button" disabled={!controller || defaultIndex === null} onClick={() => inspect(selected ?? defaultIndex)}>{c.inspect}</button>
      <button type="button" onClick={() => controller?.overview()}>{c.overview}</button>
    </div>
    <div className="queen-hive-displays" ref={layerRef} data-display-count={projections.length}>
      {projections.map(p => {
        const row = rows[p.index]; if (!row) return null;
        const focused = selected === p.index;
        const lod = hiveDisplayLod(p.width);
        const recent = hiveDisplayEvents(row, events);
        const progress = row.kind === 'epic' ? hiveEpicProgress(row, allRows) : {done:0,total:0};
        const url = hiveIssueUrl(row.repo,row.number);
        return <article key={row.key} className="queen-hive-display" data-issue={row.number} data-kind={row.kind} data-lod={lod} data-focused={focused}
          onClick={event => { if(!(event.target as Element).closest('a,button')) inspect(p.index); }}
          onPointerEnter={() => controller?.hover(p.index)} onPointerLeave={() => controller?.hover(null)}
          style={{left:p.x,top:p.y,width:p.width*.94,height:p.height*.94}}>
          <div className="queen-hive-display-content">
            <button type="button" className="queen-hive-display-heading" aria-label={`${c.inspect}: #${row.number} ${row.title}`} onClick={() => inspect(p.index)}>
              <span>{row.kind === 'epic' ? c.epic : c.issue}</span><strong>#{row.number}</strong>
            </button>
            <span className="queen-hive-display-state">{stateLabel(row.state)}</span>
            {(lod === 'title' || lod === 'detail') && <h3>{row.title}</h3>}
            {lod === 'detail' && <>
              <p className="queen-hive-display-coverage">{c.unknown}</p>
              {row.kind === 'epic' && <div className="queen-hive-epic-progress"><span>{c.children}: {progress.done}/{progress.total}</span>{progress.total > 0 && <progress aria-label={c.children} max={progress.total} value={progress.done}/>}</div>}
              <div className="queen-hive-display-events"><h4>{c.events}</h4>{recent.length ? <ul>{recent.map(e=><li key={`${e.issue}:${e.id}`}><span>#{e.issue} · {eventLabel(e)}{e.state ? ` · ${e.state}` : ''}</span><time dateTime={e.at}>{new Date(e.at).toLocaleTimeString(lang,{hour:'2-digit',minute:'2-digit',second:'2-digit'})}</time></li>)}</ul>:<p>{c.empty}</p>}</div>
              {url && <a href={url} target="_blank" rel="noopener noreferrer">{c.open} ↗</a>}
            </>}
          </div>
        </article>;
      })}
    </div>
    <p className="queen-hive-zoom-hint">{c.hint}</p>
  </>;
}
