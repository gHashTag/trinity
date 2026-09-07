import {useEffect,useMemo,useRef,useState,type Ref,type CSSProperties} from 'react';
import {useSearchParams} from 'react-router-dom';
import {QueenCombBabylon} from './QueenCombBabylon';
import {catalogUniverse,catalogFocus,catalogFocusHash,catalogPortalSize,catalogSpecSelection,type CatalogController} from './queenCatalogData';
import {QueenCatalogInspector,QueenCatalogSpec} from './QueenCatalogInspector';
import {atlasAgentPacket,type UniverseAtlas,type AtlasIssue} from '../lib/queenUniverseAtlas';
import type {CombHandle} from './queenHud';
import type {HiveDisplayProjection,HiveDisplay} from './queenHiveDisplay';
import type {WorldIssue} from './queenRepositoryWorld';
import './QueenCatalogHive.css';

export function QueenCatalogHive({atlas,lang,handleRef,foundationVisible=true,fitInset=0,onInspect}:{atlas:UniverseAtlas;lang:'ru'|'en';handleRef:Ref<CombHandle>;foundationVisible?:boolean;fitInset?:number;onInspect?:()=>void}) {
  const ru=lang==='ru';
  const [params,setParams]=useSearchParams(),focus=catalogFocus(`#/queen?${params}`,atlas),repo=focus?.repo??null;
  const [observed,setObserved]=useState<Record<string,WorldIssue>>({});
  const world=useMemo(()=>catalogUniverse(atlas,Object.values(observed)),[atlas,observed]),map=world.map;
  const issueRows=world.displays.filter(row=>row?.repo===repo);
  const cards=useMemo(()=>world.displays.map(row=>row?{number:row.number,title:row.title,column:row.state}:null),[world]);
  const issueKey=focus?.number?`${repo}#${focus.number}`:null;
  const [specPath,setSpecPath]=useState<string|null>(null);
  const control=useRef<CatalogController>(null);
  const [selected,setSelected]=useState<number|null>(null),[projections,setProjections]=useState<HiveDisplayProjection[]>([]),[query,setQuery]=useState(''),[limit,setLimit]=useState(8),[packet,setPacket]=useState(''),[copied,setCopied]=useState(false);
  const [regionProjections,setRegionProjections]=useState<HiveDisplayProjection[]>([]);
  const resource=selected===null?null:map.cells[selected];
  const spec=resource?.kind==='spec'?atlas.specs.find(s=>s.id===resource.specId):null;
  const selection=useMemo(()=>catalogSpecSelection(map,selected),[map,selected]);
  const linked=resource?atlas.issues.filter(i=>resource.kind==='repo'?i.repo===resource.repo:i.hits.some(h=>h.specId===resource.specId)):[];
  const options=useMemo(()=>map.cells.flatMap((resource,index)=>{
    const issue=world.displays[index],row=resource??issue;
    if(!row)return [];
    const label=issue?`${issue.repo} #${issue.number} · ${issue.title}`:resource?.kind==='spec'?`${resource.sourceRepo??'CORE'} · ${resource.title}`:resource!.title;
    return label.toLowerCase().includes(query.toLowerCase())?[{row,index,label}]:[];
  }),[map,world.displays,query]);
  const optionNodes=useMemo(()=>options.map(({row,index,label})=><option key={row.key} value={index} data-lang-exempt={row.kind==='issue'||row.kind==='epic'?'github-title':undefined}>{row.kind==='repo'?'⬡ ':''}{label}</option>),[options]);
  function select(index:number|null){setSelected(index);setLimit(8);setPacket('');setCopied(false);if(index===null){home();return;}const row=map.cells[index];if(row?.kind==='repo')enter(row.repo);if(row?.kind==='spec')setParams(p=>{const next=new URLSearchParams(p);next.delete('world');next.delete('task');return next;});onInspect?.();}
  function enter(nextRepo:string,number:number|null=null){setSpecPath(null);setPacket('');setCopied(false);if(nextRepo===repo&&number===focus?.number)return;setParams(p=>{const next=new URLSearchParams(p);next.set('world',nextRepo);if(number===null)next.delete('task');else next.set('task',String(number));return next;},{replace:nextRepo===repo});onInspect?.();}
  function home(){setSpecPath(null);setPacket('');setCopied(false);setParams(p=>{const next=new URLSearchParams(p);next.delete('world');next.delete('task');return next;});}
  function openIssue(row:HiveDisplay){enter(row.repo,row.number);}
  const previousRepo=useRef(repo);
  useEffect(()=>{if(previousRepo.current&&!repo&&resource?.kind!=='spec')control.current?.overview();previousRepo.current=repo;},[repo,resource?.kind]);
  function project(next:HiveDisplayProjection[],regions:HiveDisplayProjection[]){
    const equal=(a:HiveDisplayProjection[],b:HiveDisplayProjection[])=>a.length===b.length&&a.every((p,i)=>p.index===b[i].index&&Math.abs(p.x-b[i].x)<.2&&Math.abs(p.y-b[i].y)<.2&&Math.abs(p.width-b[i].width)<.2);
    setProjections(prev=>equal(prev,next)?prev:next);setRegionProjections(prev=>equal(prev,regions)?prev:regions);
  }
  async function copy(issue:AtlasIssue){const text=atlasAgentPacket(atlas,issue);setPacket(text);setCopied(false);try{await navigator.clipboard.writeText(text);setCopied(true);}catch{/* The same packet remains selectable locally. */}}
  function copyGameLink(){if(!focus)return;const text=new URL(catalogFocusHash(focus),location.href).href;setPacket(text);setCopied(false);void navigator.clipboard.writeText(text).then(()=>setCopied(true)).catch(()=>{});}
  return <div className="queen-catalog-layer" data-catalog-map="shared-universe" data-catalog-focus={repo??'shared-core'}>
    <QueenCombBabylon sceneKey="shared-universe" cards={cards} workers={null} displays={world.displays} inspectIssueKey={issueKey} inspectCatalogKey={issueKey?null:repo} onDisplaySelect={openIssue} signalHealth={{board:'stale',activity:'unknown'}} catalogLayer={map} catalogControlRef={control} onCatalogPick={select} onCatalogProject={project} pickIndex={selected} handleRef={handleRef} fitInset={fitInset} lang={lang} layers={{foundation:foundationVisible,castle:false,code:false}}/>
    <div className="queen27-hive-law queen-catalog-law">
      <span>{repo??'TRI-27 · S³AI DNA'}</span><span>{repo?issueRows.length:world.displays.filter(Boolean).length} issues</span><span>{atlas.specs.length} .t27</span><span>{map.regions?.length} {ru?'репозиториев':'repositories'}</span>
      <small>{ru?'Публичный снимок, не live · золото = спека, не закрытая issue':'Public snapshot, not live · gold = spec, not a resolved issue'}</small>
    </div>
    <div className="queen-hive-inspect-tools queen-catalog-tools">
      <input aria-label={ru?'Найти спеку, репозиторий или задачу':'Find spec, repository or issue'} placeholder=".t27 / repo / #issue" value={query} onChange={e=>setQuery(e.target.value)}/>
      <select disabled={!foundationVisible} aria-label={ru?'Спеки, репозитории и задачи на карте':'Specs, repositories and issues on map'} value={selected!==null&&options.some(o=>o.index===selected)?selected:''} onChange={e=>control.current?.inspect(Number(e.target.value),true)}><option value="" disabled>{ru?'Все соты':'All cells'} · {options.length}</option>{optionNodes}</select>
      <button disabled={selected===null} onClick={()=>{if(selected!==null)control.current?.inspect(selected,true);}}>{ru?'Крупный план':'Inspect cell'}</button>
      <button onClick={()=>control.current?.overview()}>{ru?'Вся карта':'Whole map'}</button>
    </div>
    <div className="queen-hive-displays queen-catalog-labels">{foundationVisible&&projections.map(p=>{const row=map.cells[p.index];if(!row)return null;const repo=row.kind==='repo',size=catalogPortalSize(p.width),rgb=repo?(row.open===null?'187 150 255':row.open>0?'255 77 94':'100 220 255'):'255 212 90';return <button key={row.key} className={`queen-hive-display queen-catalog-cell ${repo?'is-source':''}`} data-catalog-cell={row.key} data-kind={row.kind} data-placement={row.kind==='spec'?row.placement:undefined} data-related={selection.indices.includes(p.index)} data-lod={repo&&!size.readable?'overview':'title'} aria-label={row.title} title={row.title} data-focused={p.index===selected} onClick={()=>control.current?.inspect(p.index)} onPointerEnter={()=>control.current?.hover(p.index)} onPointerLeave={()=>control.current?.hover(null)} style={{left:p.x,top:p.y,...(!repo?{width:p.width*.94,height:p.height*.94}:{width:size.width,height:size.height}),'--hive-task-rgb':rgb} as CSSProperties}>
      <span className="queen-hive-display-content"><strong>{repo?row.repo.split('/')[1]:row.title.split('/').at(-1)}</strong><small>{repo?`${row.count} .t27`:'.t27'}</small>{repo&&<small>{row.open??'?'} {ru?'открыто':'open'}</small>}</span>
    </button>;})}
      {foundationVisible&&regionProjections.map(p=>{const row=map.cells[p.index];if(row?.kind!=='repo')return null;return <button key={row.key} className="queen-catalog-region" data-catalog-region={row.repo} onClick={()=>control.current?.inspect(p.index,true)} style={{left:p.x,top:Math.max(24,p.y),maxWidth:Math.max(90,Math.min(200,p.width))}}><strong>{row.repo.split('/')[1]}</strong><small className="queen-catalog-gold">{row.count} .t27</small><small>{world.displays.filter(i=>i?.repo===row.repo).length} issues · {ru?'приблизить':'zoom in'}</small></button>;})}
    </div>
    {resource&&(!repo||!focus?.number)&&<aside className="queen-catalog-detail" aria-label={ru?'Выбранная сота':'Selected cell'}>
      <button className="queen-catalog-close" aria-label={ru?'Закрыть детали':'Close details'} onClick={()=>control.current?.overview()}>×</button>
      <h3>{resource.title}</h3>
      {resource.kind==='repo'?<><button className="queen-catalog-enter" onClick={()=>{if(selected!==null)control.current?.inspect(selected,true);}}>{ru?'Рассмотреть задачи репозитория':'Inspect repository issues'} →</button><button onClick={copyGameLink}>{ru?'Копировать ссылку':'Copy game link'}</button><p>{resource.count} .t27 · {resource.open??'?'} {ru?'открытых задач':'open issues'}</p></>:<><p>{ru?'Одна спека: общее ядро ↔ репозиторий-источник. Золотая линия связывает её соты.':'One spec: shared core ↔ source repository. The gold line connects its cells.'}</p><div className="queen-catalog-spec-links"><button onClick={()=>{if(selected!==null)control.current?.inspect(selected);}}>{ru?'Показать связь':'Show connection'}</button>{selection.indices.map(index=>{const cell=map.cells[index];return cell?.kind==='spec'?<button key={cell.key} data-spec-jump={cell.placement} onClick={()=>control.current?.inspect(index,true)}>{cell.placement==='core'?(ru?'Ядро':'Core'):cell.sourceRepo}</button>:null;})}</div>{spec?.sources.map(s=><div key={`${s.repo}:${s.path}`}><button onClick={()=>enter(s.repo)}>{s.repo}</button><br/><button onClick={()=>setSpecPath(s.path)}>{s.path}</button></div>)}</>}
      <p>{ru?'Совпадение со спекой не закрывает issue. Нужны генерация, тесты и ревью.':'A spec match does not close an issue. Generation, tests and review are required.'}</p>
      <h4>{ru?'Связанные задачи':'Related issues'} · {linked.length}</h4>
      {linked.slice(0,limit).map(i=><div className="queen-catalog-issue" key={i.key}><button data-lang-exempt="github-title" onClick={()=>enter(i.repo,i.number)}>{i.repo} #{i.number} · {i.title}</button><small>{i.hits.some(h=>h.relation==='reference'&&(!spec||h.specId===spec.id))?(ru?'Ссылка / символ · не подтверждено':'Path / symbol · unverified'):(ru?'Кандидат / связь не подтверждена':'Candidate / relation unverified')}</small><button className="queen-catalog-copy" onClick={()=>void copy(i)}>COPY TO AGENT</button></div>)}
      {linked.length>limit&&<button onClick={()=>setLimit(n=>n+8)}>{ru?'Ещё задачи':'More issues'}</button>}
      {packet&&<><p role="status">{copied?(ru?'Скопировано':'Copied'):(ru?'Скопируйте пакет ниже':'Copy the packet below')}</p><textarea readOnly aria-label="Agent packet" value={packet}/></>}
      <small>{ru?'Наблюдение':'Observed'}: {new Date(atlas.at).toLocaleString(lang)} · {ru?'не live':'not live'}</small>
    </aside>}
    {repo&&focus?.number&&<QueenCatalogInspector key={issueKey} atlas={atlas} repo={repo} number={focus.number} lang={lang} onClose={()=>enter(repo)} onSpec={setSpecPath} onObserved={row=>setObserved(prev=>prev[row.key]===row?prev:{...prev,[row.key]:row})}/>}
    {repo&&packet&&<div className="queen-catalog-share" role="status"><button onClick={()=>setPacket('')} aria-label={ru?'Закрыть':'Close'}>×</button><span>{copied?(ru?'Скопировано':'Copied'):(ru?'Скопируйте ссылку':'Copy this link')}</span><input readOnly aria-label={ru?'Ссылка на игру':'Game link'} value={packet}/></div>}
    {specPath&&<QueenCatalogSpec key={specPath} atlas={atlas} path={specPath} lang={lang} onClose={()=>setSpecPath(null)}/>}
  </div>;
}
