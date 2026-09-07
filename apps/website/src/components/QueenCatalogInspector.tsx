import {useEffect,useRef,useState} from 'react';
import {atlasAgentPacket,type UniverseAtlas} from '../lib/queenUniverseAtlas';
import {catalogFocusHash} from './queenCatalogData';
import {loadWorldIssueDetails,type WorldIssue} from './queenRepositoryWorld';
import {specExplorerHash} from '../lib/specCatalog';

const detailsCache=new Map<string,{at:number;row:WorldIssue}>();
export function QueenCatalogInspector({atlas,repo,number,lang,onClose,onSpec,onObserved}:{atlas:UniverseAtlas;repo:string;number:number;lang:'ru'|'en';onClose:()=>void;onSpec:(path:string)=>void;onObserved:(row:WorldIssue)=>void}) {
  const ru=lang==='ru',key=`${repo}#${number}`,snapshot=atlas.issues.find(i=>i.key===key);
  const [row,setRow]=useState<WorldIssue|null>(null),[error,setError]=useState(false),[retry,setRetry]=useState(0),[copied,setCopied]=useState(false),[copyText,setCopyText]=useState('');
  const observe=useRef(onObserved);useEffect(()=>{observe.current=onObserved;},[onObserved]);
  useEffect(()=>{
    const abort=new AbortController();
    const cached=detailsCache.get(key);
    const result=cached&&Date.now()-cached.at<60_000&&!retry?Promise.resolve(cached.row):loadWorldIssueDetails(repo,number,abort.signal);
    result.then(next=>{
      if(abort.signal.aborted)return;
      if(detailsCache.size>=100)detailsCache.delete(detailsCache.keys().next().value!);
      detailsCache.set(key,{at:Date.now(),row:next});setRow(next);observe.current(next);
    }).catch(()=>{if(!abort.signal.aborted)setError(true);});
    return()=>abort.abort();
  },[repo,number,key,retry]);
  async function copy(text:string){setCopyText(text);setCopied(false);try{await navigator.clipboard.writeText(text);setCopied(true);}catch{/* selectable fallback */}}
  const packet=()=>atlasAgentPacket(atlas,snapshot??{key,repo,number,title:row?.title??'',hits:[]})+
    `\nPublic issue observation (not a task lease): ${JSON.stringify(row?{key:row.key,title:row.title,state:row.state,updatedAt:row.updatedAt,assignees:row.assignees??null}:null)}\nCheck assignments and active PRs before taking work. Coordinate ownership in the existing issue; this copy action does not reserve it.\n`;
  return <aside className="queen-catalog-detail queen-catalog-collaboration" aria-label={ru?'Совместная работа над задачей':'Issue collaboration'}>
    <button className="queen-catalog-close" aria-label={ru?'Закрыть детали':'Close details'} onClick={onClose}>×</button>
    <small>{repo} #{number}</small><h3 data-lang-exempt="github-title">{row?.title??snapshot?.title??`#${number}`}</h3>
    <p>{row?`${ru?'GitHub':'GitHub'}: ${row.state} · ${ru?'Покрытие T27 не подтверждено':'T27 coverage unverified'}`:ru?'Снимок каталога · текущее состояние проверяется':'Catalog snapshot · checking current state'}</p>
    {row&&<p>{ru?'Назначены в GitHub':'GitHub assignees'}: {row.assignees?.join(', ')||(ru?'нет · это не резервирование':'none · not a reservation')}</p>}
    {error&&<p role="alert">{ru?'GitHub недоступен или достигнут лимит. Снимок сохранён.':'GitHub unavailable or rate-limited. Snapshot retained.'}<button onClick={()=>{setError(false);setRetry(n=>n+1);}}>{ru?'Повторить':'Retry'}</button></p>}
    <button className="queen-catalog-copy" onClick={()=>void copy(packet())}>COPY TO AGENT</button>
    <div className="queen-catalog-actions"><button onClick={()=>void copy(new URL(catalogFocusHash({repo,number}),location.href).href)}>{ru?'Ссылка на соту':'Share cell'}</button><button onClick={()=>void copy(`https://github.com/${repo}/issues/${number}`)}>{ru?'Ссылка GitHub':'Copy GitHub URL'}</button></div>
    <p>{ru?'Пакет не назначает задачу. Перед работой проверьте исполнителя и открытые PR.':'The packet does not claim work. Check assignees and open PRs before starting.'}</p>
    <details open><summary>{ru?'Описание GitHub':'GitHub description'}</summary><pre data-lang-exempt="github-content">{row?.body??(error?(ru?'Описание не загружено':'Description not loaded'):(ru?'Загрузка…':'Loading…'))}</pre></details>
    <h4>{ru?'Связанные спеки · не доказательство':'Related specs · not proof'} · {snapshot?.hits.length??0}</h4>
    {snapshot?.hits.map(hit=>{const spec=atlas.specs.find(s=>s.id===hit.specId);return <div className="queen-catalog-issue" key={hit.specId}>{spec?.sources.map(s=><button key={`${s.repo}:${s.path}`} onClick={()=>onSpec(s.path)}>{s.repo} · {s.path}</button>)}<small>{hit.relation==='reference'?(ru?'Путь / символ, не подтверждено':'Path / symbol, unverified'):(ru?'Кандидат, не подтверждено':'Candidate, unverified')}</small></div>;})}
    {copyText&&<><p role="status">{copied?(ru?'Скопировано':'Copied'):(ru?'Скопируйте текст ниже':'Copy the text below')}</p><textarea aria-label={ru?'Контекст для совместной работы':'Collaboration context'} readOnly value={copyText}/></>}
  </aside>;
}

export function QueenCatalogSpec({atlas,path,lang,onClose}:{atlas:UniverseAtlas;path:string;lang:'ru'|'en';onClose:()=>void}) {
  const ru=lang==='ru',spec=atlas.specs.find(s=>s.sources.some(src=>src.path===path));
  return <section className="queen-catalog-spec" aria-label={ru?'Центральный каталог спек':'Central spec catalog'}>
    <header><strong>Spec Explorer · /specs</strong><button onClick={onClose}>{ru?'← Назад к карте':'← Back to map'}</button></header>
    <p>{ru?'Единый каталог /specs · исходник, анализ и генерация. Правки здесь — черновик, не принятая спека.':'One /specs catalog · source, analysis and generation. Edits here are a draft, not an accepted spec.'}</p>
    {spec?<iframe title={ru?'Обозреватель спецификации T27':'T27 Spec Explorer'} src={`./${specExplorerHash(path,{embedded:true,sha256:spec.id})}`} sandbox="allow-scripts allow-same-origin" allow="clipboard-write"/>:<p role="alert">{ru?'Спека отсутствует в каталоге карты.':'Spec is missing from the map catalog.'}</p>}
  </section>;
}
