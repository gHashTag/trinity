import type {UniverseAtlas} from './queenUniverseAtlas';
type Spec=UniverseAtlas['specs'][number];
export function treasurySources(spec:Spec){return [...new Set(spec.sources.map(s=>s.repo))].sort();}
/** Axial packing is navigation, not a dependency or astronomical coordinate. */
export function treasuryCells(specs:Spec[]) {
  const sorted=[...specs].sort((a,b)=>a.id.localeCompare(b.id)),cells:{id:string;x:number;y:number;repos:string[];path:string;paths:string[]}[]=[];
  const directions=[[1,0],[1,-1],[0,-1],[-1,0],[-1,1],[0,1]];
  for(let ring=5;cells.length<sorted.length;ring++){
    let q=-ring,r=ring;
    for(const [dq,dr] of directions)for(let step=0;step<ring&&cells.length<sorted.length;step++){
      const spec=sorted[cells.length];cells.push({id:spec.id,x:Math.sqrt(3)*18*(q+r/2),y:27*r,repos:treasurySources(spec),path:spec.sources[0].path,paths:spec.sources.map(s=>s.path)});q+=dq;r+=dr;
    }
  }
  return cells;
}
