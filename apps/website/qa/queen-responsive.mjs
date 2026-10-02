import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {HivePointers} from '../src/components/queenHivePointers.ts';
const p=new HivePointers();
p.down(1,100,100);assert.equal(p.move(1,102,101),null);assert.equal(p.suppressClick,false);
const pan=p.move(1,120,110);assert.deepEqual(pan,{from:{x:102,y:101},to:{x:120,y:110},scale:1});assert(p.suppressClick);
p.up(1);p.down(1,100,100);p.down(2,200,100);assert(p.suppressClick);
const pinch=p.move(2,300,100);assert.equal(pinch.scale,2);assert.deepEqual(pinch.from,{x:150,y:100});assert.deepEqual(pinch.to,{x:200,y:100});
p.up(2);assert.equal(p.move(1,110,100).scale,1);p.up(1);
p.down(3,10,10);assert.equal(p.suppressClick,false);p.up(3,true);assert(p.suppressClick);
p.down(4,10,10);p.up(4);assert.equal(p.suppressClick,false,'Normal tap and keyboard selection remain available');
p.down(5,10,10);p.cancel();assert.equal(p.move(5,200,100),null,'Lost pointer-up cannot leave the map dragging');assert(p.suppressClick);
const css=readFileSync('src/components/QueenCatalogHive.css','utf8');
assert.match(css,/\.queen-catalog-toolbar/,'Toolbar gets a measured flow layout');
assert.match(css,/grid-template-rows:\s*minmax\(0,\s*1fr\)/,'Embedded canvas has no fixed row floor');
assert.match(css,/font-size:\s*1rem/,'Touch form text remains readable');
const page=readFileSync('src/pages/Queen.tsx','utf8'),hive=readFileSync('src/components/QueenCatalogHive.tsx','utf8');
assert.match(page,/boardView\s*===\s*"comb"\s*&&\s*!sharedCatalog\s*&&\s*<QueenContext/,'Legacy context lives only on the old comb: not over the catalog, not over any other view');
assert.match(hive,/!specPath&&resource/);assert.match(hive,/!specPath&&repo&&focus\?\.number/);
assert(!hive.includes('className="queen-catalog-share"'),'Copy feedback stays in the current card');
// Calm bare mode does not ride on the Fullscreen API: the Telegram Mini App's
// WebView has none, and that is where the map stayed 499px of 812.
assert.match(page,/framed\s*&&\s*!embedded\s*&&\s*window\.matchMedia\("\(max-width: 900px\)"\)/,'A framed phone board starts bare');
assert.match(page,/\$\{bare \? " is-bare" : ""\}/,'Bare follows the page state, not only document.fullscreenElement');
assert.match(page,/className="queen27-hud-more"/,'The board owns its "more" button');
const pageCss=readFileSync('src/pages/Queen.css','utf8');
assert.match(pageCss,/\.is-bare \.queen27-hud-viewport > :is\(\.queen27-hud-top,/,'Bare hides the panels that live inside the viewport');
assert.match(pageCss,/\.is-bare:not\(\.is-tools\) \.queen27-hud-vp-head > :not\(\.queen27-hud-vp-title\)/,'A calm head shows the sector name only');
console.log('Responsive contract: PASS (pointer state machine, flow layout, readable controls, single context, calm bare mode)');
