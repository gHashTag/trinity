import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import * as d from '../src/components/queenCatalogData.ts';
import {hexRing,spiralAxial} from '../src/components/queenHud.ts';
const atlas=JSON.parse(readFileSync('public/t27/universe-atlas.json','utf8'));
const {map,displays}=d.catalogUniverse(atlas);
assert.equal(map.specLinks?.length,atlas.specs.reduce((n,s)=>n+new Set(s.sources.map(p=>p.repo)).size,0),'Every source spec needs a real paired placement');
assert.equal(map.cells.filter(c=>c?.kind==='spec'&&c.placement==='core').length,atlas.specs.length);
assert.equal(new Set(map.cells.filter(c=>c?.kind==='spec').map(c=>c.specId)).size,atlas.specs.length,'Placements do not multiply canonical spec count');
assert.equal(displays.filter(Boolean).length,atlas.issues.length,'Gold resources never become fake issues');
for(const region of map.regions){
  const specs=atlas.specs.filter(s=>s.sources.some(p=>p.repo===region.repo));
  assert.equal(region.specIndices.length,specs.length);
  const gold=new Set(region.specIndices.map(i=>map.cells[i].specId));
  assert.deepEqual(gold,new Set(specs.map(s=>s.id)));
  const ring=i=>hexRing(spiralAxial(region.slots.indexOf(i)));
  const goldRing=Math.max(...region.specIndices.map(ring));
  assert(region.indices.every(i=>ring(i)>goldRing),'Issues occupy hex rings outside the repository gold core');
}
for(const [core,source] of map.specLinks){
  assert.equal(map.cells[core].placement,'core');assert.equal(map.cells[source].placement,'source');
  assert.equal(map.cells[core].specId,map.cells[source].specId);
  for(const i of [core,source]){
    const selected=d.catalogSpecSelection(map,i);
    assert(selected.indices.includes(core)&&selected.indices.includes(source));
    assert(selected.links.some(([a,b])=>a===core&&b===source));
    assert(selected.indices.every(j=>map.cells[j].specId===map.cells[i].specId));
    const p=map.positions[i];assert.equal(d.catalogCellAt(map,p.x,p.y),i);
    const view=d.catalogConnectionView(map,i,6000,4000);
    for(const j of selected.indices){const end=map.positions[j];assert(Math.abs(end.x-view.x)<6000/view.zoom);assert(Math.abs(end.y-view.y)<4000/view.zoom);}
  }
}
assert.deepEqual(d.catalogSpecSelection(map,null),{indices:[],links:[]});
// Test-only fan-out fixture: one identity can have several contributing repos.
const shared=structuredClone(atlas),first=shared.specs[0];
const second=shared.worlds.find(w=>!first.sources.some(s=>s.repo===w.repo));
first.sources.push({repo:second.repo,path:'specs/test-only/shared-mirror.t27'});second.specCount++;
const fanout=d.catalogUniverse(shared).map;
const central=fanout.cells.findIndex(c=>c?.kind==='spec'&&c.placement==='core'&&c.specId===first.id);
const selected=d.catalogSpecSelection(fanout,central);
assert.equal(selected.indices.length,3);assert.equal(selected.links.length,2);
assert.equal(new Set(fanout.cells.filter(c=>c?.kind==='spec').map(c=>c.specId)).size,atlas.specs.length);
for(const i of selected.indices)assert.deepEqual(d.catalogSpecSelection(fanout,i),selected);
for(const [w,h] of [[6000,4000],[4000,6000],[4000,3000]]){
  const view=d.catalogConnectionView(fanout,central,w,h);
  for(const i of selected.indices){const p=fanout.positions[i];assert(Math.abs(p.x-view.x)<w/view.zoom);assert(Math.abs(p.y-view.y)<h/view.zoom);}
}
for(const inset of [{right:.5,bottom:0},{right:0,bottom:.7}]){
  const w=6000,h=4000,view=d.catalogConnectionView(fanout,central,w,h,inset);
  for(const i of selected.indices){const p=fanout.positions[i],x=(p.x-view.x)*view.zoom,y=(p.y-view.y)*view.zoom;assert(x>-w&&x<w*(1-2*inset.right),'Connection stays left of inspector');assert(y<h&&y>h*(2*inset.bottom-1),'Connection stays above mobile inspector');}
}
console.log(`Spec mirrors: PASS (${atlas.specs.length} canonical specs, ${map.specLinks.length} source placements and exact two-way provenance links)`);
