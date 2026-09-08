import { lazy, Suspense, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { QueenLoading } from '../components/QueenLoading';
import { createPortal } from 'react-dom';
import { useSearchParams } from 'react-router-dom';
import { useI18n } from '../i18n/context';
import { TrinityLogo } from '../components/TrinityLogo';
import {validateAtlas,type UniverseAtlas} from '../lib/queenUniverseAtlas';
import { placeHiveDisplays } from '../components/queenHiveDisplay';
import { hexField, type CombHandle } from '../components/queenHud';
import { COLLAB_ORIGIN, PINNED_WORLDS, WORLD_STORAGE, loadWorldIssues, loadWorldMetadata, mergeWorldIssues, parseWorldRepository, savedWorlds, type WorldIssue, type WorldMetadata } from '../components/queenRepositoryWorld';
import './Queen.css';
import './QueenUniverse.css';

const Runtime=lazy(()=>import('./Queen'));
const Atlas=lazy(()=>import('../components/QueenUniverseAtlas').then(m=>({default:m.QueenUniverseAtlas})));
const SharedCore=lazy(()=>import('../components/QueenSharedCore').then(m=>({default:m.QueenSharedCore})));
const Hive=lazy(()=>import('../components/QueenCombBabylon').then(m=>({default:m.QueenCombBabylon})));
const EMPTY_EVENTS: never[]=[];
const WORDS={
  ru:{worlds:'Миры',connect:'＋ Репозиторий',choose:'Выбрать мир',title:'Подключить свой мир',close:'Закрыть',public:'Публичный репозиторий GitHub',placeholder:'owner/repo или https://github.com/owner/repo',open:'Подключить карту',checking:'Проверяю GitHub…',local:'Карты сохраняются на этом устройстве. Подключение карты не даёт агентам права менять код.',login:'Войти через GitHub',authNote:'Выбор своих публичных репозиториев через существующий Railway OAuth. Токен остаётся в HttpOnly cookie сервера.',authPending:'Вход ожидает обновления t27-github-collab. Публичную карту можно открыть по ссылке ниже.',private:'Приватные репозитории пока не поддерживаются: доступ к ним не запрашивается.',loading:'Загружаю карту GitHub…',snapshot:'Снимок GitHub',notRuntime:'Queen runtime не подключён к этому миру',scope:'Только задачи этого репозитория. Пчёлы, ревью и FPGA других миров сюда не переносятся.',refresh:'Обновить',more:'Загрузить ещё',partial:'Показана часть задач',complete:'Все страницы загружены',issues:'задач',empty:'В репозитории нет задач',disabled:'Issues отключены в GitHub',failed:'Не удалось загрузить карту',stale:'Последний снимок сохранён; обновление не удалось',noActivity:'События Queen не подключены',fit:'Весь мир',repo:'Открыть GitHub',source:'Последние обновления GitHub',noEvents:'Это время обновления issue, не журнал работы пчёл.',rate:'Лимит GitHub исчерпан или доступ ограничен. Попробуйте позже.',invalid:'Укажите точный публичный репозиторий owner/repo.',missing:'Репозиторий не найден или закрыт.',retry:'Повторить',remove:'Убрать из списка',hive:'Соты',list:'Список'},
  en:{worlds:'Worlds',connect:'＋ Repository',choose:'Choose world',title:'Connect your world',close:'Close',public:'Public GitHub repository',placeholder:'owner/repo or https://github.com/owner/repo',open:'Connect map',checking:'Checking GitHub…',local:'Maps are saved on this device. Connecting a map does not authorize agents to change code.',login:'Sign in with GitHub',authNote:'Choose your public repositories through the existing Railway OAuth service. Its token stays in a server HttpOnly cookie.',authPending:'Sign-in awaits the t27-github-collab update. You can open a public map by URL below.',private:'Private repositories are not supported yet; no private access is requested.',loading:'Loading GitHub world…',snapshot:'GitHub snapshot',notRuntime:'Queen runtime is not connected to this world',scope:'Only this repository’s issues. Other worlds’ Bees, reviews and FPGA data are never reused.',refresh:'Refresh',more:'Load more',partial:'Partial issue map',complete:'All pages loaded',issues:'issues',empty:'This repository has no issues',disabled:'GitHub Issues are disabled',failed:'Could not load this map',stale:'Last snapshot retained; refresh failed',noActivity:'Queen events not connected',fit:'Whole world',repo:'Open GitHub',source:'Latest GitHub updates',noEvents:'Issue update times, not a Bee activity log.',rate:'GitHub rate limit or access restriction. Try again later.',invalid:'Enter an exact public owner/repo repository.',missing:'Repository not found or private.',retry:'Retry',remove:'Remove from list',hive:'Hive',list:'List'},
};
type Copy=typeof WORDS.en|typeof WORDS.ru;
function errorCopy(error:string,c:Copy) { return error==='rate-limit'?c.rate:error==='not-found'||error==='public-only'?c.missing:error==='invalid-repository'?c.invalid:c.failed; }
function readSaved() { try{return savedWorlds(localStorage.getItem(WORLD_STORAGE));}catch{return [...PINNED_WORLDS];} }

export default function QueenUniverse() {
  const {lang:rawLang}=useI18n(),lang=rawLang==='ru'?'ru':'en',c=WORDS[lang];
  const [params,setParams]=useSearchParams();
  const repo=parseWorldRepository(params.get('repo')??'')??PINNED_WORLDS[0];
  const coreView=params.get('view')==='core';
  // The home is the original full-screen hive. Keep the draft atlas opt-in;
  // it must never replace the user's game map again.
  const atlasView=params.get('view')==='atlas';
  const commonHive=!params.has('repo')&&!coreView&&!atlasView;
  const issueNumber=Number(params.get('issue'));
  const [atlas,setAtlas]=useState<UniverseAtlas|null>(null),[atlasError,setAtlasError]=useState(false),[atlasRetry,setAtlasRetry]=useState(0);
  const [saved,setSaved]=useState(readSaved);
  const worlds=useMemo(()=>[...new Set([...(atlas?.worlds.map(w=>w.repo)??[PINNED_WORLDS[1]]),...(commonHive?[]:[repo])])], [repo,atlas,commonHive]);
  const [input,setInput]=useState(''),[error,setError]=useState<string|null>(null),[busy,setBusy]=useState(false),[authReady,setAuthReady]=useState(false);
  const dialog=useRef<HTMLDialogElement>(null),pending=useRef<AbortController|null>(null);
  useEffect(()=>{document.body.classList.add('queen-universe-shell');return()=>{document.body.classList.remove('queen-universe-shell');pending.current?.abort();};},[]);
  useEffect(()=>{try{localStorage.setItem(WORLD_STORAGE,JSON.stringify([...new Set([...saved,repo])]));}catch{/* optional local preference */}},[saved,repo]);
  useEffect(()=>{const abort=new AbortController();fetch('t27/universe-atlas.json',{signal:abort.signal,credentials:'omit'}).then(async r=>{if(!r.ok)throw new Error('atlas');return validateAtlas(await r.json());}).then(data=>{if(!abort.signal.aborted){setAtlas(data);setAtlasError(false);}}).catch(()=>{if(!abort.signal.aborted)setAtlasError(true);});return()=>abort.abort();},[atlasRetry]);
  useEffect(()=>{const abort=new AbortController();fetch(`${COLLAB_ORIGIN}/health`,{signal:abort.signal,credentials:'omit'}).then(r=>r.ok?r.json():null).then(v=>setAuthReady(v?.capabilities?.queenRepositoryPicker===true)).catch(()=>{});return()=>abort.abort();},[]);
  function choose(value:string) { setParams(p=>{const n=new URLSearchParams(p);n.delete('issue');n.delete('task');if(!coreView&&atlas?.worlds.some(w=>w.repo===value&&w.specCount>0)){n.delete('repo');n.delete('view');n.set('world',value);}else{n.set('repo',value);n.delete('world');if(n.get('view')==='atlas')n.delete('view');}return n;}); }
  async function connect() {
    const next=parseWorldRepository(input);if(!next){setError('invalid-repository');return;}
    pending.current?.abort();const abort=new AbortController();pending.current=abort;setBusy(true);setError(null);
    try{await loadWorldMetadata(next,abort.signal);if(abort.signal.aborted)return;setSaved(v=>[...new Set([...v,next])].slice(-20));choose(next);dialog.current?.close();setInput('');}
    catch(e){if(!abort.signal.aborted)setError(e instanceof Error?e.message:'load-failed');}
    finally{if(!abort.signal.aborted)setBusy(false);}
  }
  const [slot, setSlot] = useState<HTMLElement | null>(null);
  useEffect(() => {
    const find = () => setSlot(document.getElementById('queen-worlds-slot'));
    find();
    const observer = new MutationObserver(find);   // the shell mounts after this
    observer.observe(document.body, { childList: true, subtree: true });
    return () => observer.disconnect();
  }, []);

  // The worlds belong on the map: a repository is a place there, and its tasks
  // are its cells. The shell offers a slot in the map's own control row; with
  // the shell absent — the world and list pages — the nav renders where it is.
  const nav = <nav className="queen-universe-nav" aria-label={c.worlds}>
      <span>◈ {c.worlds}</span>
      <select aria-label={c.choose} value={commonHive?(worlds.includes(params.get('world')??'')?params.get('world')!:''):repo} onChange={e=>e.target.value?choose(e.target.value):setParams(new URLSearchParams())}><option value="">{lang==='ru'?'Все репозитории · общая карта':'All repositories · shared map'}</option>{worlds.map(world=><option key={world} value={world}>{world}</option>)}</select>
      {repo!==PINNED_WORLDS[1]&&<button className="queen-world-shortcut" onClick={()=>choose(PINNED_WORLDS[1])}>T27 ↗</button>}
      <button className="queen-world-connect" onClick={()=>dialog.current?.showModal()}>{c.connect}</button>
      <button aria-pressed={atlasView} onClick={()=>setParams(new URLSearchParams())}>{lang==='ru'?'◈ Главная игры':'◈ Game home'}</button>
      <button aria-pressed={coreView} onClick={()=>setParams(p=>{const n=new URLSearchParams(p);if(coreView)n.delete('view');else n.set('view','core');return n;})}>{coreView?(lang==='ru'?'← Карта':'← Map'):(lang==='ru'?'Общее ядро':'Shared core')}</button>
    </nav>;

  // Where the nav goes when there is no slot yet.
  //
  // The Runtime is the HUD, and the HUD is what offers the slot in the map's
  // control row. Between this component rendering and that chunk mounting —
  // the atlas fetch, then the lazy import — the nav has nowhere to go, and
  // rendered here meanwhile it is a strip across the top of the page: the
  // layout this HUD replaced, arriving on every reload and then vanishing.
  // Hiding it only while the atlas loaded was half the window; the second half
  // is the shell's own chunk, which is the part that blinks. On the pages that
  // have no shell — a repository world, the atlas, the shared core — it still
  // renders where it is, because there it is the only place it has.
  const shellIsComing = !atlasView && !coreView && repo === PINNED_WORLDS[0];

  return <div className="queen-universe" data-world={repo}>
    {slot ? createPortal(nav, slot) : shellIsComing ? null : nav}
    <div className="queen-universe-content"><Suspense fallback={<p role="status">{c.loading}</p>}>
      {/* Loading is not failing. This paragraph carried the error class either
          way, so every cold load opened with the failure colour on a black
          page — which reads as "it did not load", because that is what it
          looks like. */}
      {commonHive&&!atlas?(atlasError?<p className="queen-world-error" role="alert">{c.failed}<button onClick={()=>setAtlasRetry(n=>n+1)}>{c.retry}</button></p>:<QueenLoading title={c.loading} facts={[`${worlds.length} ${lang==='ru'?'миров':'worlds'}`]}/>):atlasView?<Atlas key={repo} atlas={atlas} error={atlasError} retry={()=>setAtlasRetry(n=>n+1)} lang={lang} initialRepo={repo} saved={saved}/>:coreView?<SharedCore key={`${repo}:${issueNumber}`} repo={repo} lang={lang} initialIssue={Number.isSafeInteger(issueNumber)&&issueNumber>0?issueNumber:undefined}/>:repo===PINNED_WORLDS[0]?<Runtime key={repo} sharedCatalog={commonHive?atlas??undefined:undefined}/>:<RepositoryWorld key={repo} repo={repo} lang={lang}/>}
    </Suspense></div>
    <dialog className="queen-world-dialog" ref={dialog} aria-labelledby="world-connect-title">
      <header><h2 id="world-connect-title">{c.title}</h2><button onClick={()=>dialog.current?.close()} aria-label={c.close}>×</button></header>
      {authReady?<a className="queen-world-connect" href={`${COLLAB_ORIGIN}/queen/connect`} target="_blank" rel="noopener noreferrer">{c.login} ↗</a>:<p className="queen-world-auth-pending">{c.authPending}</p>}
      <p>{c.authNote}</p>
      <form onSubmit={e=>{e.preventDefault();void connect();}}>
        <label htmlFor="world-repo-input">{c.public}</label>
        <input id="world-repo-input" value={input} onChange={e=>setInput(e.target.value)} placeholder={c.placeholder} autoComplete="off" maxLength={200} required/>
        {error&&<p role="alert">{errorCopy(error,c)}</p>}
        <button className="queen-world-connect" disabled={busy}>{busy?c.checking:c.open}</button>
      </form>
      <p>{c.local}</p><p>{c.private}</p>
      {saved.filter(w=>!PINNED_WORLDS.includes(w)).map(w=><p key={w} className="queen-world-saved"><span>{w}</span><button onClick={()=>{setSaved(v=>v.filter(r=>r!==w));if(repo===w)choose(PINNED_WORLDS[0]);}} aria-label={`${c.remove}: ${w}`}>×</button></p>)}
    </dialog>
  </div>;
}

function RepositoryWorld({repo,lang}:{repo:string;lang:'en'|'ru'}) {
  const c=WORDS[lang],handle=useRef<CombHandle>(null),request=useRef<AbortController|null>(null),nextAllowed=useRef(0);
  const [snapshot,setSnapshot]=useState<{meta:WorldMetadata;rows:WorldIssue[];page:number;hasMore:boolean;at:string}|null>(null);
  const [error,setError]=useState<string|null>(null),[busy,setBusy]=useState(true),[view,setView]=useState<'hive'|'list'>('hive');
  const rows=snapshot?.rows??EMPTY_EVENTS;
  const [placement,setPlacement]=useState(()=>({rows, ...placeHiveDisplays(new Map(),rows,hexField(rows.length+1).cellCount)}));
  let displays=placement.placed;
  if(placement.rows!==rows){const next=placeHiveDisplays(placement.ledger,rows,hexField(rows.length+1).cellCount);displays=next.placed;setPlacement({rows,...next});}
  const cards=useMemo(()=>displays.map(r=>r?{number:r.number,title:r.title,column:r.state}:null),[displays]);
  const load=useCallback(async(page:number,initial=false) => {
    if(!initial&&Date.now()<nextAllowed.current)return;nextAllowed.current=Date.now()+1000;
    request.current?.abort();const abort=new AbortController();request.current=abort;setBusy(true);setError(null);
    try {
      const meta=await loadWorldMetadata(repo,abort.signal);
      const result=meta.issuesEnabled?await loadWorldIssues(repo,page,abort.signal):{rows:[],hasMore:false};
      if(abort.signal.aborted)return;
      setSnapshot(prev=>({meta,rows:page===1?result.rows:mergeWorldIssues(prev?.rows??[],result.rows),page,hasMore:result.hasMore,at:new Date().toISOString()}));
    } catch(e) {if(!abort.signal.aborted){const code=e instanceof Error?e.message:'load-failed';setError(code);if(code==='rate-limit')nextAllowed.current=Date.now()+60_000;}}
    finally{if(!abort.signal.aborted)setBusy(false);}
  },[repo]);
  useEffect(()=>{void load(1,true);return()=>request.current?.abort();},[load]);
  return <main className="queen-repository-world" data-world-repository={repo}>
    <header className="queen-world-header"><TrinityLogo withLabel={false} height="40px"/><div><h1>{repo}</h1><p>{c.snapshot} · {c.notRuntime}</p></div><a href={`https://github.com/${repo}`} target="_blank" rel="noopener noreferrer">{c.repo} ↗</a></header>
    <div className="queen-world-tools"><span>{snapshot?`${rows.length} ${c.issues} · ${snapshot.hasMore?c.partial:c.complete}`:c.loading}</span>
      <button aria-pressed={view==='hive'} onClick={()=>setView('hive')}>{c.hive}</button><button aria-pressed={view==='list'} onClick={()=>setView('list')}>{c.list}</button>
      <button onClick={()=>handle.current?.fit()} disabled={view!=='hive'||!snapshot}>{c.fit}</button>
      <button onClick={()=>void load(1)} disabled={busy}>{c.refresh}</button>
      {snapshot?.hasMore&&<button disabled={busy||snapshot.page>=100} onClick={()=>void load(snapshot.page+1)}>{c.more}</button>}
    </div>
    {error&&<p className="queen-world-error" role="alert">{snapshot?c.stale:c.failed}: {errorCopy(error,c)}</p>}
    <div className="queen-world-stage" data-source="github-public" aria-busy={busy}>
      {!snapshot?<p role="status">{busy?c.loading:c.failed}</p>:rows.length===0?<p>{snapshot.meta.issuesEnabled?c.empty:c.disabled}</p>:view==='hive'?<Suspense fallback={<p>{c.loading}</p>}><Hive displays={displays} cards={cards} workers={null} events={EMPTY_EVENTS} handleRef={handle} lang={lang} signalHealth={{board:error?'stale':'live',activity:'unknown'}} layers={{foundation:true,castle:false,code:false}}/></Suspense>:<div className="queen-world-list">{rows.map(row=><a key={row.key} href={`https://github.com/${repo}/issues/${row.number}`} target="_blank" rel="noopener noreferrer"><b>#{row.number}</b><span data-lang-exempt="github-title">{row.title}</span><small>{row.state==='closed'?(lang==='ru'?'Закрыта · T27 не подтверждено':'Closed · T27 unproven'):row.state==='dropped'?(lang==='ru'?'Отложена':'Paused'):(lang==='ru'?'Открыта':'Open')}</small></a>)}</div>}
    </div>
    <footer><span>{c.scope}</span><time dateTime={snapshot?.at}>{snapshot?new Date(snapshot.at).toLocaleTimeString(lang):'—'}</time></footer>
  </main>;
}
