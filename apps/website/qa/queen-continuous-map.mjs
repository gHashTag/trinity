import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import * as data from '../src/components/queenCatalogData.ts';
import {HEX_R,S_CELL,hexToWorld,spiralAxial} from '../src/components/queenHud.ts';
import {hiveEpicProgress} from '../src/components/queenHiveDisplay.ts';

assert.equal(typeof data.catalogUniverse,'function','All repositories need one persistent map, not a selected-repo field');
const atlas=JSON.parse(await readFile(new URL('../public/t27/universe-atlas.json',import.meta.url),'utf8'));
const world=data.catalogUniverse(atlas),core=data.catalogHive(atlas);
assert.deepEqual(world.map.cells.slice(0,core.cells.length),core.cells);
assert.deepEqual(world.map.edges,core.edges);
assert.equal(world.map.regions.length,atlas.worlds.filter(w=>w.specCount>0).length);
assert.equal(world.displays.filter(Boolean).length,atlas.issues.length);
assert.deepEqual(new Set(world.displays.filter(Boolean).map(i=>i.key)),new Set(atlas.issues.map(i=>i.key)));
assert.equal(new Set(world.displays.filter(Boolean).map(i=>i.key)).size,atlas.issues.length);
world.map.positions.forEach((p,index)=>{
  assert.equal(data.catalogCellAt(world.map,p.x,p.y),index,`pick/projection identity ${index}`);
  if(index<core.cells.length)assert.deepEqual({x:p.x,y:p.y},hexToWorld(spiralAxial(index)));
});
assert.equal(data.catalogCellAt(world.map,1e8,1e8),-1);
const positions=world.map.positions;
const fieldWidth=Math.max(...positions.map(p=>p.x+HEX_R*p.scale))-Math.min(...positions.map(p=>p.x-HEX_R*p.scale));
const fieldHeight=Math.max(...positions.map(p=>p.y+HEX_R*p.scale))-Math.min(...positions.map(p=>p.y-HEX_R*p.scale));
for(const [width,height] of [[1440,800],[390,600],[390,300]]){
  const halfWidth=Math.max(fieldWidth,fieldHeight*width/height)/2*1.2,halfHeight=halfWidth*height/width;
  for(const region of world.map.regions){
    const view=data.catalogFocusView(world.map,region.portalIndex,halfWidth,halfHeight,width,height);
    for(const i of region.indices){const p=positions[i];assert(Math.abs(p.x-view.x)+HEX_R*p.scale<halfWidth/view.zoom);assert(Math.abs(p.y-view.y)+HEX_R*p.scale<halfHeight/view.zoom);}
    for(const i of region.indices){const view=data.catalogFocusView(world.map,i,halfWidth,halfHeight,width,height),p=positions[i];assert.equal(view.x,p.x);assert.equal(view.y,p.y);const projected=S_CELL*p.scale*width/(halfWidth*2)*view.zoom;assert(projected>=Math.min(260,width*.84,height*.74),'Close-up stays readable at the actual viewport');}
  }
}
for(const region of world.map.regions){
  assert.equal(world.map.cells[region.portalIndex].repo,region.repo);
  assert.equal(region.indices.length,atlas.issues.filter(i=>i.repo===region.repo).length);
  assert(region.indices.every(i=>world.displays[i]?.repo===region.repo));
  const closestCore=Math.min(...world.map.positions.slice(0,core.cells.length).map(p=>Math.hypot(p.x-region.x,p.y-region.y)-HEX_R));
  assert(closestCore>region.radius,'Repository region must not cover the shared core');
  for(const other of world.map.regions)if(region!==other)assert(Math.hypot(region.x-other.x,region.y-other.y)>region.radius+other.radius,'Repository regions must not overlap');
}
const issue=world.displays.find(Boolean),updated=data.catalogUniverse(atlas,[{...issue,state:'closed',title:'Observed title'}]);
const epic={...issue,kind:'epic',children:[{number:7,state:'open'}]};
assert.equal(hiveEpicProgress(epic,[{...issue,number:7,state:'open'},{...issue,repo:'another/repo',number:7,state:'closed'}]).done,0,'Another repository cannot complete this epic child');
const before=new Map(world.displays.flatMap((row,i)=>row?[[row.key,world.map.positions[i]]]:[]));
updated.displays.forEach((row,i)=>{if(row)assert.deepEqual(updated.map.positions[i],before.get(row.key),'Observation must not teleport other cells');});
assert.equal(updated.displays.find(i=>i?.key===issue.key).state,'closed');
const extra={...issue,key:`${issue.repo}#999999`,number:999999,state:'closed'};
const extended=data.catalogUniverse(atlas,[extra]);
for(const [i,row] of extended.displays.entries())if(row&&before.has(row.key))assert.deepEqual(extended.map.positions[i],before.get(row.key),'An observed old issue appends without moving snapshot cells');
assert.equal(extended.displays.filter(Boolean).length,atlas.issues.length+1);
const component=await readFile(new URL('../src/components/QueenCatalogHive.tsx',import.meta.url),'utf8');
assert.match(component,/sceneKey="shared-universe"/);
assert.match(component,/catalogLayer=\{map\}/);
assert.match(component,/displays=\{world\.displays\}/);
assert.doesNotMatch(component,/catalogLayer=\{repo\?|sceneKey=\{repo/);
console.log(`PASS continuous map: ${world.map.regions.length} repositories, ${world.displays.filter(Boolean).length} distinct issues, ${atlas.specs.length} specs, picking + non-overlap + stable observation updates`);
