import {useEffect,useMemo,useRef,useState} from 'react';
import {TrinityLogo} from './TrinityLogo';
import {treasuryCells} from '../lib/queenSpecTreasury';
import type {UniverseAtlas} from '../lib/queenUniverseAtlas';
import './QueenSpecTreasury.css';

const hex=(radius:number)=>Array.from({length:6},(_,i)=>{const a=(30+i*60)*Math.PI/180;return `${Math.cos(a)*radius},${Math.sin(a)*radius}`;}).join(' ');
const CELL_HEX=hex(16),QUEEN_HEX=hex(110);
export function QueenSpecTreasury({atlas,selected,onSelect,lang}:{atlas:UniverseAtlas;selected:string;onSelect:(id:string)=>void;lang:'en'|'ru'}) {
  const ru=lang==='ru',cells=useMemo(()=>treasuryCells(atlas.specs),[atlas.specs]),[query,setQuery]=useState(''),[camera,setCamera]=useState({x:0,y:0,zoom:1}),[allLinks,setAllLinks]=useState(false);
  const drag=useRef<{x:number;y:number;cx:number;cy:number;moved:boolean}|null>(null),svg=useRef<SVGSVGElement>(null);
  const [viewport,setViewport]=useState({width:800,height:480});
  useEffect(()=>{const element=svg.current;if(!element)return;const observer=new ResizeObserver(([entry])=>setViewport({width:entry.contentRect.width,height:entry.contentRect.height}));observer.observe(element);return()=>observer.disconnect();},[]);
  const radius=Math.max(600,...cells.map(c=>Math.hypot(c.x,c.y)+170));
  const fitScale=Math.max(radius*2/Math.max(80,viewport.width-152),radius*2/Math.max(80,viewport.height-118));
  const width=fitScale*viewport.width,height=fitScale*viewport.height;
  const portals=atlas.worlds.map((w,i)=>{const a=(-90+i*360/atlas.worlds.length)*Math.PI/180;return {...w,x:Math.cos(a)*(radius-40),y:Math.sin(a)*(radius-40)};});
  const active=cells.find(c=>c.id===selected),matches=cells.filter(c=>c.paths.some(path=>path.toLowerCase().includes(query.toLowerCase())));
  // Keep source names legible and tappable in CSS pixels at every zoom level.
  const sourceScale=Math.max(width/(camera.zoom*Math.max(1,viewport.width)),height/(camera.zoom*Math.max(1,viewport.height)));
  const visibleIds=new Set(matches.map(c=>c.id));
  function choose(id:string,focus=false){onSelect(id);const cell=cells.find(c=>c.id===id);if(focus&&cell)setCamera({x:cell.x,y:cell.y,zoom:4});}
  function zoom(delta:number){setCamera(c=>({...c,zoom:Math.max(1,Math.min(8,c.zoom+delta))}));}
  return <div className="queen-spec-treasury" aria-label={ru?'Общая карта спек':'Shared spec map'}>
    <header><h2>{ru?'Сокровищница Королевы':'Queen’s treasury'} <b>{cells.length} .t27</b></h2><p>{ru?'Каждая сота — существующая спека. Линия ведёт к её исходному репозиторию. Золото здесь — ресурс, не закрытая issue.':'Each cell is an existing spec. Its line leads to its source repository. Gold here means a resource, not a closed issue.'}</p></header>
    <div className="treasury-controls"><label htmlFor="treasury-search">{ru?'Найти спеку':'Find a spec'}</label><input id="treasury-search" value={query} onChange={e=>setQuery(e.target.value)} placeholder="specs/… .t27"/><select aria-label={ru?'Выбрать спеку':'Choose a spec'} value={matches.some(c=>c.id===selected)?selected:''} onChange={e=>choose(e.target.value,true)}><option value="">{matches.length} .t27</option>{matches.map(c=><option key={c.id} value={c.id}>{c.path}</option>)}</select></div>
    <div className="treasury-viewport">
      <svg ref={svg} viewBox={`${camera.x-width/(2*camera.zoom)} ${camera.y-height/(2*camera.zoom)} ${width/camera.zoom} ${height/camera.zoom}`} aria-label={ru?'Соты спек вокруг Королевы и связи с репозиториями':'Spec cells around the Queen and repository source edges'} role="img"
        onPointerDown={e=>{if(e.button!==0)return;drag.current={x:e.clientX,y:e.clientY,cx:camera.x,cy:camera.y,moved:false};}}
        onPointerMove={e=>{const d=drag.current;if(!d||!svg.current||!e.buttons)return;const dx=e.clientX-d.x,dy=e.clientY-d.y;if(Math.abs(dx)+Math.abs(dy)>5)d.moved=true;if(d.moved){e.currentTarget.setPointerCapture(e.pointerId);const rect=svg.current.getBoundingClientRect(),factor=Math.max(width/camera.zoom/rect.width,height/camera.zoom/rect.height);setCamera(c=>({...c,x:d.cx-dx*factor,y:d.cy-dy*factor}));}}}
        onPointerUp={e=>{if(e.currentTarget.hasPointerCapture(e.pointerId))e.currentTarget.releasePointerCapture(e.pointerId);}}
        onPointerCancel={()=>{drag.current=null;}}>
        {portals.map(p=><g key={p.repo}><path className="treasury-trunk" d={`M 0 0 L ${p.x} ${p.y}`}/><text className="treasury-edge-count" x={p.x*.7} y={p.y*.7}>{p.specCount} .t27</text></g>)}
        {allLinks&&cells.flatMap(c=>c.repos.map(repo=>{const p=portals.find(p=>p.repo===repo);return p?<path key={`${c.id}:${repo}`} className="treasury-edge" d={`M ${c.x} ${c.y} L ${p.x} ${p.y}`}/>:null;}))}
        {cells.map(c=><g key={c.id} data-spec-cell={c.id} transform={`translate(${c.x} ${c.y})`} className={`treasury-cell ${c.id===selected?'is-selected':''} ${query&&!visibleIds.has(c.id)?'is-muted':''}`} onClick={()=>{if(drag.current?.moved){drag.current=null;return;}choose(c.id);}}><title>{c.path} → {c.repos.join(', ')}</title><polygon points={CELL_HEX}/>{camera.zoom>=3&&<text fontSize="3.7" textAnchor="middle" y="1">{c.path.split('/').at(-1)?.slice(0,15)}</text>}</g>)}
        {active?.repos.map(repo=>{const p=portals.find(p=>p.repo===repo);return p?<path key={repo} data-source-edge={repo} className="treasury-edge-selected" d={`M ${active.x} ${active.y} L ${p.x} ${p.y}`}/>:null;})}
        <g className="treasury-queen"><polygon points={QUEEN_HEX}/><foreignObject x="-70" y="-56" width="140" height="112"><div className="treasury-queen-logo"><TrinityLogo withLabel={false} height="96px"/></div></foreignObject></g>
        {portals.map(p=><a key={p.repo} href={`#/queen?repo=${encodeURIComponent(p.repo)}`} aria-label={`${ru?'Открыть мир':'Open world'} ${p.repo}`}><g transform={`translate(${p.x} ${p.y}) scale(${sourceScale})`} data-spec-source={p.repo} className={`treasury-portal ${active?.repos.includes(p.repo)?'is-linked':''}`}><rect x="-66" y="-23" width="132" height="46" rx="6"/><text textAnchor="middle" y="-3">{p.repo.split('/')[1]}</text><text className="treasury-portal-count" textAnchor="middle" y="15">{p.specCount} .t27 ↗</text></g></a>)}
      </svg>
      <div className="treasury-zoom"><button onClick={()=>zoom(-1)} disabled={camera.zoom<=1} aria-label={ru?'Уменьшить карту спек':'Zoom out specs'}>−</button><output>{camera.zoom.toFixed(0)}×</output><button onClick={()=>zoom(1)} disabled={camera.zoom>=8} aria-label={ru?'Увеличить карту спек':'Zoom in specs'}>＋</button><button onClick={()=>setCamera({x:0,y:0,zoom:1})}>{ru?'Вся карта':'Fit map'}</button><button aria-pressed={allLinks} onClick={()=>setAllLinks(v=>!v)}>{ru?'Все связи':'All links'}</button></div>
    </div>
    <p className="treasury-caption">{active?`${active.path} → ${active.repos.join(', ')}`:ru?'Выберите соту или спеку в списке. Перетаскивайте поле для перемещения.':'Select a cell or a spec from the list. Drag the field to pan.'}</p>
  </div>;
}
