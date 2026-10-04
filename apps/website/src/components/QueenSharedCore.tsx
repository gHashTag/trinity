import {useCallback,useEffect,useMemo,useRef,useState} from 'react';
import {agentPacket,coreImpact,matchIssue,validCorePath,type SharedCore} from '../lib/sharedSpecCore';
import {loadWorldBacklog,loadWorldIssue,loadWorldMetadata,mergeWorldIssues,type WorldIssue} from './queenRepositoryWorld';
import './QueenSharedCore.css';
import {TrinityLogo} from './TrinityLogo';

const UI={
  en:{title:'Shared spec core',intro:'One catalog for every world. Discover reuse before writing another implementation.',catalog:'specs',collisions:'module-name collisions',missing:'unresolved imports',dirty:'Catalog contains uncommitted source changes. Health is a snapshot claim, not acceptance.',loading:'Loading catalog and public backlog…',failed:'Could not load catalog/backlog. Check GitHub availability or rate limits, then retry.',retry:'Retry',partial:'Partial open backlog',complete:'All open-issue pages loaded',more:'Load more issues',choose:'Choose an issue',none:'No open issues on loaded pages.',noMatch:'No defensible match found. Search the catalog manually or propose a missing shared capability.',candidate:'Reuse candidate · unverified',reference:'Explicit reference · unverified',copy:'COPY TO AGENT',copied:'Copied',copyError:'Clipboard unavailable. Select and copy the review packet below.',source:'Inspect spec',health:'Catalog health',affected:'candidate issues on loaded pages',dependents:'dependent specs',meaning:'These links do not prove coverage and do not change hive colors.',links:'Dependency review',from:'from',missingLabel:'No target found',ambiguous:'Ambiguous target',resolved:'Unique path match',provenance:'Catalog snapshot',backlog:'issues loaded',why:'Match evidence',packet:'Agent review packet',impact:'Shared opportunities',impactNote:'Ranked within the loaded backlog, not all repositories. Import edges are lexical/path matches, not compiled links.',noneImpact:'No shared opportunities found in this slice.',search:'Search issue titles',healthNote:'ok does not mean production-ready. Inspect source, generated code and consumer tests.'},
  ru:{title:'Общее ядро спек',intro:'Один каталог для всех миров. Ищем переиспользование до создания новой реализации.',catalog:'спек',collisions:'совпадений имён модулей',missing:'неразрешённых импортов',dirty:'В каталоге есть незакоммиченные изменения. Его состояние — снимок, не доказательство приёмки.',loading:'Загружаю каталог и публичный бэклог…',failed:'Не удалось загрузить каталог/бэклог. Проверьте доступность GitHub или лимиты и повторите.',retry:'Повторить',partial:'Часть открытого бэклога',complete:'Все страницы открытых задач загружены',more:'Загрузить ещё задачи',choose:'Выбрать задачу',none:'На загруженных страницах нет открытых задач.',noMatch:'Обоснованных совпадений не найдено. Проверьте каталог вручную или предложите недостающую общую возможность.',candidate:'Кандидат на переиспользование · не проверено',reference:'Явная ссылка · не проверено',copy:'COPY TO AGENT',copied:'Скопировано',copyError:'Буфер обмена недоступен. Выделите и скопируйте пакет ниже.',source:'Открыть спеку',health:'Состояние в каталоге',affected:'задач-кандидатов на загруженных страницах',dependents:'зависимых спек',meaning:'Эти связи не доказывают покрытие и не меняют цвет сот.',links:'Проверка зависимостей',from:'из',missingLabel:'Цель не найдена',ambiguous:'Неоднозначная цель',resolved:'Уникальное совпадение пути',provenance:'Снимок каталога',backlog:'задач загружено',why:'Основание связи',packet:'Пакет проверки для агента',impact:'Общие точки улучшения',impactNote:'Рейтинг по загруженному бэклогу, не по всем репозиториям. Импорты сопоставлены по тексту и пути, не проверены компилятором.',noneImpact:'В этом срезе общих точек пока не найдено.',search:'Поиск по названиям задач',healthNote:'ok не означает готовность к production. Проверьте спеку, сгенерированный код и тесты потребителя.'},
};

export function QueenSharedCore({repo,lang,initialIssue}:{repo:string;lang:'en'|'ru';initialIssue?:number}) {
  const c=UI[lang],abort=useRef<AbortController|null>(null),cooldown=useRef(0);
  const [core,setCore]=useState<SharedCore|null>(null),[rows,setRows]=useState<WorldIssue[]>([]),[page,setPage]=useState(0),[more,setMore]=useState(false),[busy,setBusy]=useState(true),[error,setError]=useState(false),[selected,setSelected]=useState(initialIssue?`${repo}#${initialIssue}`:''),[search,setSearch]=useState(''),[copied,setCopied]=useState(false),[copyError,setCopyError]=useState(false),[targetMissing,setTargetMissing]=useState(false);
  const load=useCallback(async(next:number,initial=false)=>{
    if(!initial&&Date.now()<cooldown.current)return;cooldown.current=Date.now()+1000;
    abort.current?.abort();const request=new AbortController();abort.current=request;setBusy(true);setError(false);
    try {
      await loadWorldMetadata(repo,request.signal);
      const [response,backlog,target]=await Promise.all([fetch('t27/shared-core.json',{signal:request.signal,credentials:'omit'}),loadWorldBacklog(repo,next,request.signal),next===1&&initialIssue?loadWorldIssue(repo,initialIssue,request.signal):Promise.resolve(null)]);
      if(!response.ok)throw new Error('catalog');const data:SharedCore=await response.json();
      if(data.version!==1||!Array.isArray(data.specs)||!data.specs.every(s=>/^[a-f0-9]{64}$/.test(s.id)&&s.sources.every(source=>validCorePath(source.path))))throw new Error('catalog');
      if(request.signal.aborted)return;
      setCore(prev=>prev?.provenance.manifestSha256===data.provenance.manifestSha256&&prev?.provenance.indexerSha256===data.provenance.indexerSha256?prev:data);setRows(prev=>mergeWorldIssues(next===1?[]:prev,[...backlog.rows,...(target?[target]:[])]));setPage(next);setMore(backlog.hasMore);if(next===1)setTargetMissing(Boolean(initialIssue&&!target));
    }catch(e){if(!request.signal.aborted){setError(true);if(e instanceof Error&&e.message==='rate-limit')cooldown.current=Date.now()+60_000;}}
    finally{if(!request.signal.aborted)setBusy(false);}
  },[repo,initialIssue]);
  useEffect(()=>{void load(1,true);return()=>abort.current?.abort();},[load]);
  const analyses=useMemo(()=>core?rows.map(issue=>({issue,hits:matchIssue(core,issue)})):[],[core,rows]);
  const visible=analyses.filter(a=>`${a.issue.number} ${a.issue.title}`.toLowerCase().includes(search.toLowerCase()));
  const active=visible.find(a=>a.issue.key===selected)??visible[0];
  const opportunities=useMemo(()=>{
    if(!core)return [];
    const ids=[...new Set(analyses.flatMap(a=>a.hits.map(h=>h.specId)))];
    return ids.map(id=>({spec:core.specs.find(s=>s.id===id)!,impact:coreImpact(core,id,analyses)})).filter(v=>v.impact.issues.length>1).sort((a,b)=>b.impact.issues.length-a.impact.issues.length||a.spec.id.localeCompare(b.spec.id)).slice(0,8);
  },[core,analyses]);
  const packet=core&&active?agentPacket(core,active.issue,active.hits):'';
  async function copy(){try{await navigator.clipboard.writeText(packet);setCopied(true);setCopyError(false);}catch{setCopyError(true);}}
  return <section className="queen-shared-core" aria-label={c.title} data-core-repository={repo}>
    <header><TrinityLogo withLabel={false} height="40px"/><h1>{c.title}</h1><p>{c.intro}</p><code>{repo}</code></header>
    <p className="core-boundary">{c.meaning}</p>
    {targetMissing&&<p role="status">{lang==='ru'?'Выбранная задача больше не открыта. Показан актуальный бэклог.':'The selected issue is no longer open. Showing the current backlog.'}</p>}
    {busy&&!core&&<p role="status">{c.loading}</p>}
    {error&&<p role="alert">{c.failed} <button onClick={()=>void load(page? page:1)} disabled={busy}>{c.retry}</button></p>}
    {core&&<>
      <div className="core-summary"><span><b>{core.specs.length}</b> {c.catalog}</span><span><b>{core.collisions.length}</b> {c.collisions}</span><span><b>{core.dependencies.filter(d=>!d.to).length}</b> {c.missing}</span><span><b>{rows.length}</b> {c.backlog}</span></div>
      <p className="core-provenance">{c.provenance}: <code>{String(core.provenance.commit).slice(0,12)}</code> · {core.provenance.dirty?c.dirty:c.healthNote}</p>
      <div className="core-toolbar"><span>{more?c.partial:c.complete}</span>{more&&<button disabled={busy||page>=100} onClick={()=>void load(page+1)}>{c.more}</button>}<a href="#/specs" target="_blank" rel="noopener noreferrer">{c.source} ↗</a></div>
      <div className="core-layout">
        <aside><label htmlFor="core-issue-search">{c.search}</label><input id="core-issue-search" value={search} onChange={e=>setSearch(e.target.value)}/><label htmlFor="core-issue-select">{c.choose}</label><select id="core-issue-select" value={active?.issue.key??''} onChange={e=>{setSelected(e.target.value);setCopied(false);}}>{visible.map(a=><option key={a.issue.key} value={a.issue.key}>#{a.issue.number} {a.issue.title}</option>)}</select>
          <h2>{c.impact}</h2><p>{c.impactNote}</p>{opportunities.length?opportunities.map(o=><details key={o.spec.id}><summary><code>{o.spec.sources[0].path}</code><br/>{o.impact.issues.length} {c.affected}</summary>{o.impact.issues.map(i=><button key={i.key} onClick={()=>{setSelected(i.key);setSearch('');setCopied(false);}}>{i.key}</button>)}</details>):<p>{c.noneImpact}</p>}
        </aside>
        <div className="core-results">{!active?<p>{c.none}</p>:<>
          <h2><a href={`https://github.com/${repo}/issues/${active.issue.number}`} target="_blank" rel="noopener noreferrer" data-lang-exempt="github-title">#{active.issue.number} {active.issue.title}</a></h2>
          <button className="core-copy" onClick={()=>void copy()}>{copied?c.copied:c.copy}</button>{copyError&&<p role="alert">{c.copyError}</p>}
          {!active.hits.length&&<p>{c.noMatch}</p>}
          {active.hits.map(hit=>{const spec=core.specs.find(s=>s.id===hit.specId)!,impact=coreImpact(core,spec.id,analyses),deps=core.dependencies.filter(d=>d.from===spec.id);return <article key={spec.id} data-core-coverage="unverified">
            <strong>{hit.relation==='reference'?c.reference:c.candidate}</strong>
            {spec.sources.map(s=><p key={`${s.repo}:${s.path}`}><a href={`#/specs?spec=${encodeURIComponent(s.path)}`} target="_blank" rel="noopener noreferrer"><code>{s.path}</code> ↗</a><br/><small>{c.from} {s.repo} · {c.health}: {s.health}</small></p>)}
            <code className="core-hash">sha256:{spec.id}</code>
            <p>{c.why}: {hit.reasons.map(r=>r.value).join(' · ')}</p><p>{impact.issues.length} {c.affected} · {impact.specIds.length-1} {c.dependents}</p>
            {deps.length>0&&<details><summary>{c.links} ({deps.length})</summary><ul>{deps.map((d,i)=><li key={i}><code>{d.name}:{d.line}</code> — {d.to?c.resolved:d.status==='ambiguous'?c.ambiguous:c.missingLabel}</li>)}</ul></details>}
          </article>;})}
          <details><summary>{c.packet}</summary><textarea readOnly aria-label={c.packet} value={packet}/></details>
        </>}</div>
      </div>
    </>}
  </section>;
}
