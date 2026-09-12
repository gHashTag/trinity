import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {catalogHive,catalogIssueRows,catalogFocus,catalogFocusHash,catalogPortalSize} from '../src/components/queenCatalogData.ts';
import {placeHiveDisplays} from '../src/components/queenHiveDisplay.ts';
const atlas=JSON.parse(readFileSync('public/t27/universe-atlas.json','utf8'));
const manifest=JSON.parse(readFileSync('public/t27/manifest.json','utf8'));
const map=catalogHive(atlas);
assert.equal(map.cells[0],null,'Queen owns the center, never an invented issue');
const specs=map.cells.filter(c=>c?.kind==='spec'),repos=map.cells.filter(c=>c?.kind==='repo');
// The counts were pinned (760 specs, 5 repositories) when every source was typed into a
// script by hand. The world scan adds repositories as it finds them, so the pin moved to
// what must hold whatever the scan found: one cell per canonical spec of the snapshot,
// one portal per repository that actually contributed bytes, and the five founding
// sources always among them. The manifest ties the numbers to vendored files.
const contributing=atlas.worlds.filter(w=>w.specCount>0).map(w=>w.repo).sort();
assert.equal(specs.length,atlas.specs.length,'every canonical spec gets exactly one core cell');
assert.equal(new Set(atlas.specs.map(s=>s.id)).size,manifest.specs.length-(manifest.duplicatesInCatalog??0)||atlas.specs.length,'canonical specs are the distinct vendored bytes');
assert.deepEqual(repos.map(r=>r.repo).sort(),contributing,'a portal for each repository with .t27 bytes in the catalog, no other');
for(const founding of ['ghashtag/t27','ghashtag/tri-net','ghashtag/trinity','ghashtag/trinity-fpga','ghashtag/tt-trinity-corona'])assert.ok(contributing.includes(founding),`${founding} is a founding source and must stay on the map`);
assert.ok(repos.length>=5);
assert.equal(new Set(map.cells.filter(Boolean).map(c=>c.key)).size,specs.length+repos.length);
assert.ok(map.cells.filter(Boolean).every(c=>!('number' in c)),'resources never masquerade as issues');
assert.equal(map.edges.length,atlas.specs.reduce((n,s)=>n+new Set(s.sources.map(src=>src.repo)).size,0),'one edge per spec per contributing repository');
for(const [a,b] of map.edges){assert.equal(map.cells[a].kind,'spec');assert.equal(map.cells[b].kind,'repo');assert.ok(map.cells[a].sources.includes(map.cells[b].repo));}
assert.deepEqual(catalogHive({...atlas,specs:[...atlas.specs].reverse(),worlds:[...atlas.worlds].reverse()}),map);
assert.ok(repos.every(r=>r.count>0));
const issues=catalogIssueRows(atlas,'ghashtag/trinity-fpga');
assert.equal(issues.length,atlas.issues.filter(i=>i.repo==='ghashtag/trinity-fpga').length);
assert.ok(issues.length>0,'the snapshot carries trinity-fpga open issues');
assert.ok(issues.every(i=>i.repo==='ghashtag/trinity-fpga'&&i.key===`${i.repo}#${i.number}`&&i.state==='open'&&i.coverage==='unknown'&&i.updatedAt===null));
assert.equal(catalogIssueRows(atlas,'other/repo').length,0);
const oldClosed={...issues[0],key:`${issues[0].repo}#999999`,number:999999,state:'closed'};
assert.equal(catalogIssueRows(atlas,issues[0].repo,[oldClosed]).at(-1).state,'closed','a historical shared link gets its actual closed cell');
assert.equal(catalogIssueRows(atlas,issues[0].repo,[{...oldClosed,repo:'other/repo'}]).length,issues.length,'foreign same-number detail cannot cross source boundaries');
const first=placeHiveDisplays(new Map(),issues.slice(1),100);
const merged=placeHiveDisplays(first.ledger,issues,100);
for(const [key,cell] of first.ledger)assert.equal(merged.ledger.get(key),cell,'adding an older issue cannot move established cells');
const focus={repo:issues[0].repo,number:issues[0].number};
assert.deepEqual(catalogFocus(catalogFocusHash(focus),atlas),focus);
for(const hash of ['#/queen?world=other%2Frepo&task=1','#/queen?world=ghashtag%2Ftrinity-fpga&task=-1','#/queen?world=ghashtag%2Ftrinity-fpga&task=1.5','#/queen?world=ghashtag%2Ftrinity-fpga&task=1e2'])assert.equal(catalogFocus(hash,atlas),null);
assert.deepEqual(catalogFocus(catalogFocusHash({repo:focus.repo,number:null}),atlas),{repo:focus.repo,number:null});
const source=readFileSync('src/components/QueenCombBabylon.tsx','utf8');
assert.ok(source.includes('catalogLayer'),'the shared data layer must use the existing Babylon renderer');
const ui=readFileSync('src/components/QueenCatalogHive.tsx','utf8');
assert.doesNotMatch(ui,/target="_blank"|window\.open/,'the collaboration flow stays inside the game');
const css=readFileSync('src/pages/Queen.css','utf8');
const surface=css.match(/\.queen-hive-display:is\(\[data-kind="spec"\],\[data-task-tone="honey"\]\) \{([^}]+)\}/)[1];
assert.doesNotMatch(surface,/gradient|blur\(/);assert.match(surface,/backdrop-filter:none/);
assert.match(surface,/background:rgb\(var\(--hive-task-rgb\) \/ \.035\)/,'yellow faces match the light outer portals');
assert.match(source,/if\(tone==='honey'&&catalogRef.current\)material.alpha=\.035/,'the GPU face must also be transparent');
assert.doesNotMatch(source,/catalogGlass\.alpha/,'zoom must not restore the opaque golden face');
assert.equal(catalogPortalSize(4).width,16,'zooming out shrinks portals with the hive');
assert.equal(catalogPortalSize(4).readable,false,'tiny portals do not draw overflowing labels');
assert.equal(catalogPortalSize(40).width,136);assert.equal(catalogPortalSize(NaN).width,0);
console.log(`Catalog hive: PASS (${specs.length} real specs, ${repos.length} contributing repos, exact source edges, no fake issue identity)`);
