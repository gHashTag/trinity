import {HEX_R,S_CELL,hexCellCount,hexRingStart,hexRingsFor,hexToWorld,spiralAxial,hexIndexAt} from './queenHud.ts';
import {keyWorldAtlas,type UniverseAtlas} from '../lib/queenUniverseAtlas.ts';
import type {WorldIssue} from './queenRepositoryWorld.ts';
import {hiveFocusZoom} from './queenHiveDisplay.ts';

export type CatalogCell = {kind:'spec';key:string;specId:string;placement:'core'|'source';sourceRepo?:string;title:string;sources:string[];count:1}
  | {kind:'repo';key:string;title:string;repo:string;count:number;open:number|null};
export interface CatalogPosition {x:number;y:number;scale:number}
export interface CatalogRegion {repo:string;portalIndex:number;x:number;y:number;radius:number;focusRadius:number;scale:number;indices:number[];specIndices:number[];slots:number[]}
export interface CatalogHive {cells:(CatalogCell|null)[];edges:[number,number][];signature:string;positions?:CatalogPosition[];regions?:CatalogRegion[];coreCount?:number;specLinks?:[number,number][]}
export interface CatalogController {inspect(index:number,focus?:boolean):void;overview():void;hover(index:number|null):void}

/** Portal labels follow map scale; fixed-size plates must never cover a zoomed-out hive. */
export function catalogPortalSize(cellWidth:number):{width:number;height:number;readable:boolean} {
  const width=Number.isFinite(cellWidth)?Math.max(0,Math.min(136,cellWidth*4)):0;
  return {width,height:width*152/136,readable:width>=72};
}

export function catalogIssueRows(atlas:UniverseAtlas,repo:string,observed:WorldIssue[]=[]):WorldIssue[] {
  if(!atlas.worlds.some(w=>w.repo===repo&&w.specCount>0))return [];
  const rows:WorldIssue[]=atlas.issues.filter(i=>i.repo===repo).map(i=>({
    key:i.key,repo:i.repo,number:i.number,title:i.title,kind:'issue',state:'open',
    closedAt:null,updatedAt:null,children:[],coverage:'unknown',
  }));
  const updates=observed.filter(i=>i.repo===repo&&i.key===`${repo}#${i.number}`&&Number.isSafeInteger(i.number)&&i.number>0);
  return [...new Map([...rows,...updates].map(row=>[row.key,row])).values()].sort((a,b)=>a.number-b.number);
}
export type CatalogFocus={repo:string;number:number|null};
export function catalogFocus(hash:string,atlas:UniverseAtlas):CatalogFocus|null {
  if(hash.split('?')[0]!=='#/queen')return null;
  const p=new URLSearchParams(hash.split('?')[1]??''),repo=p.get('world'),raw=p.get('task');
  if(!repo||!atlas.worlds.some(w=>w.repo===repo&&w.specCount>0))return null;
  if(raw!==null&&(!/^[1-9]\d*$/.test(raw)||!Number.isSafeInteger(Number(raw))))return null;
  return {repo,number:raw===null?null:Number(raw)};
}
export function catalogFocusHash(focus:CatalogFocus):string {
  const p=new URLSearchParams({world:focus.repo});if(focus.number!==null)p.set('task',String(focus.number));
  return `#/queen?${p}`;
}

/** Resource identity is NOT issue identity. Queen keeps index zero. */
export function catalogHive(input:UniverseAtlas):CatalogHive {
  const atlas=keyWorldAtlas(input),specs=[...atlas.specs].sort((a,b)=>a.id.localeCompare(b.id));
  const worlds=[...atlas.worlds].sort((a,b)=>a.repo.localeCompare(b.repo));
  const ring=hexRingsFor(specs.length+1)+1;
  if(worlds.length>6*ring)throw new Error('Contributor ring capacity exceeded');
  const cells:(CatalogCell|null)[]=Array(hexCellCount(ring)).fill(null),repoCells=new Map<string,number>();
  worlds.forEach((w,i)=>{const index=hexRingStart(ring)+Math.floor(i*6*ring/worlds.length);repoCells.set(w.repo,index);cells[index]={kind:'repo',key:w.repo,title:w.repo,repo:w.repo,count:w.specCount,open:w.backlog.error?null:w.backlog.total};});
  const edges:[number,number][]=[];
  specs.forEach((s,i)=>{const sources=[...new Set(s.sources.map(src=>src.repo))].sort();cells[i+1]={kind:'spec',key:s.id,specId:s.id,placement:'core',title:s.sources[0].path,sources,count:1};for(const repo of sources){const to=repoCells.get(repo);if(to===undefined)throw new Error('Missing source portal');edges.push([i+1,to]);}});
  return {cells,edges,signature:JSON.stringify([cells.map(c=>c?.key??null),worlds.map(w=>[w.repo,w.specCount,w.backlog.total,w.backlog.error])])};
}

/** One coordinate space. Focus never changes membership or replaces the core. */
export function catalogUniverse(input:UniverseAtlas,observed:WorldIssue[]=[]) {
  const atlas=keyWorldAtlas(input),core=catalogHive(atlas);
  const cells=[...core.cells],positions:CatalogPosition[]=cells.map((_,i)=>({...hexToWorld(spiralAxial(i)),scale:1}));
  const displays:(WorldIssue|null)[]=cells.map(()=>null),regions:CatalogRegion[]=[];
  const specLinks:[number,number][]=[],coreById=new Map(core.cells.flatMap((c,i)=>c?.kind==='spec'?[[c.specId,i] as const]:[]));
  const coreRadius=Math.max(...positions.map(p=>Math.hypot(p.x,p.y)))+HEX_R;
  core.cells.forEach((portal,portalIndex)=>{
    if(portal?.kind!=='repo')return;
    const rows=catalogIssueRows(atlas,portal.repo,observed);
    // Reserve the snapshot's slots: a newly observed older issue appends instead of shifting existing cells.
    const snapshot=catalogIssueRows(atlas,portal.repo),byKey=new Map(rows.map(r=>[r.key,r]));
    const ordered=[...snapshot.map(r=>byKey.get(r.key)!),...observed.filter(r=>r.repo===portal.repo&&byKey.has(r.key)&&!snapshot.some(s=>s.key===r.key))];
    const unique=[...new Map(ordered.map(r=>[r.key,r])).values()];
    const specs=[...atlas.specs].filter(s=>s.sources.some(src=>src.repo===portal.repo)).sort((a,b)=>a.id.localeCompare(b.id));
    // Repository gold owns the inner rings. Issue slots start outside that core.
    const issueStart=hexCellCount(hexRingsFor(specs.length+1));
    const scale=.55,ring=hexRingsFor(Math.max(issueStart+snapshot.length+64,issueStart+unique.length));
    const radius=(S_CELL*ring+HEX_R)*scale;
    const origin=positions[portalIndex],length=Math.hypot(origin.x,origin.y)||1;
    const distance=coreRadius+radius+S_CELL*2;
    const region:CatalogRegion={repo:portal.repo,portalIndex,x:origin.x/length*distance,y:origin.y/length*distance,radius,focusRadius:HEX_R*scale,scale,indices:[],specIndices:[],slots:[-1]};
    const append=(local:number,resource:CatalogCell|null,row:WorldIssue|null)=>{
      const point=hexToWorld(spiralAxial(local)),index=cells.length;
      region.slots[local]=index;cells.push(resource);displays.push(row);
      positions.push({x:region.x+point.x*scale,y:region.y+point.y*scale,scale});
      region.focusRadius=Math.max(region.focusRadius,(Math.hypot(point.x,point.y)+HEX_R)*scale);
      return index;
    };
    for(let local=1;local<issueStart+unique.length;local++){
      const spec=specs[local-1],row=local>=issueStart?unique[local-issueStart]:null;
      const resource:CatalogCell|null=spec?{kind:'spec',key:JSON.stringify(['source',portal.repo,spec.id]),specId:spec.id,placement:'source',sourceRepo:portal.repo,title:spec.sources.find(s=>s.repo===portal.repo)!.path,sources:[portal.repo],count:1}:null;
      const index=append(local,resource,row);
      if(spec){region.specIndices.push(index);specLinks.push([coreById.get(spec.id)!,index]);}
      if(row)region.indices.push(index);
    }
    regions.push(region);
  });
  const map:CatalogHive={...core,cells,positions,regions,specLinks,coreCount:core.cells.length,signature:JSON.stringify([core.signature,regions,specLinks,displays.map(r=>r?.key??null)])};
  return {map,displays};
}

/** Same region transform as rendering/projection; empty space cannot select a neighbouring repo. */
export function catalogCellAt(map:CatalogHive,x:number,y:number):number {
  for(const region of map.regions??[]){
    if(Math.hypot(x-region.x,y-region.y)>region.radius)continue;
    const local=hexIndexAt((x-region.x)/region.scale,(y-region.y)/region.scale,region.slots.length);
    return local>0?region.slots[local]??-1:-1;
  }
  return hexIndexAt(x,y,map.coreCount??map.cells.length);
}

export function catalogSpecSelection(map:CatalogHive,index:number|null):{indices:number[];links:[number,number][]} {
  const row=index===null?null:map.cells[index];if(row?.kind!=='spec')return {indices:[],links:[]};
  const indices=map.cells.flatMap((cell,i)=>cell?.kind==='spec'&&cell.specId===row.specId?[i]:[]);
  const selected=new Set(indices);
  return {indices,links:(map.specLinks??[]).filter(([a,b])=>selected.has(a)&&selected.has(b))};
}

export function catalogConnectionView(map:CatalogHive,index:number,halfWidth:number,halfHeight:number,inset={right:0,bottom:0}) {
  const {indices}=catalogSpecSelection(map,index),points=indices.flatMap(i=>map.positions?.[i]?[map.positions[i]]:[]);
  if(!points.length)return null;
  const minX=Math.min(...points.map(p=>p.x-HEX_R*p.scale)),maxX=Math.max(...points.map(p=>p.x+HEX_R*p.scale));
  const minY=Math.min(...points.map(p=>p.y-HEX_R*p.scale)),maxY=Math.max(...points.map(p=>p.y+HEX_R*p.scale));
  const zoom=Math.min(128,Math.max(.5,Math.min(halfWidth*2*(1-inset.right)/(maxX-minX+S_CELL),halfHeight*2*(1-inset.bottom)/(maxY-minY+S_CELL))*.78));
  return {x:(minX+maxX)/2+inset.right*halfWidth/zoom,y:(minY+maxY)/2-inset.bottom*halfHeight/zoom,zoom};
}

/** Region and cell close-ups share the exact camera sizing contract on desktop and mobile. */
export function catalogFocusView(map:CatalogHive,index:number,halfWidth:number,halfHeight:number,width:number,height:number,inset={right:0,bottom:0}) {
  const position=map.positions?.[index];if(!position)return null;
  const region=map.regions?.find(r=>r.portalIndex===index);
  const zoom=region?
    Math.min(128,Math.max(.5,Math.min(halfWidth,halfHeight)/(region.focusRadius*1.12))):
    hiveFocusZoom(S_CELL*position.scale*width/(halfWidth*2),width*(1-inset.right),height*(1-inset.bottom));
  return {x:(region?.x??position.x)+(region?0:inset.right*halfWidth/zoom),y:(region?.y??position.y)-(region?0:inset.bottom*halfHeight/zoom),zoom};
}
