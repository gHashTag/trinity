import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const w=await import('../src/components/queenRepositoryWorld.ts');
assert.equal(w.parseWorldRepository('https://github.com/gHashTag/t27.git/'),'ghashtag/t27');
assert.equal(w.parseWorldRepository(' gHashTag/trios '),'ghashtag/trios');
for(const value of ['https://evil.test/a/b','https://github.com/a/b/issues','https://github.com/u:p@github.com/a/b','a/..','a/b?x=1','a/b#x','javascript:alert(1)','a/b/c']) assert.equal(w.parseWorldRepository(value),null,value);
assert.deepEqual(w.savedWorlds('{"token":"secret"}'),w.PINNED_WORLDS);
assert.deepEqual(w.savedWorlds('["other/repo","OTHER/repo","evil/.."]'),[...w.PINNED_WORLDS,'other/repo']);
const issue=(n=1)=>({number:n,title:'Real title',state:'open',html_url:`https://github.com/ghashtag/t27/issues/${n}`,updated_at:'2026-09-07T00:00:00Z',labels:[]});
const rows=w.githubWorldIssues('ghashtag/t27',[issue(),{...issue(2),pull_request:{}},{...issue(3),state:'closed'},{...issue(4),html_url:'https://github.com/other/repo/issues/4'}]);
assert.equal(rows.length,2); assert.equal(rows[0].key,'ghashtag/t27#1'); assert.equal(rows[1].coverage,'unknown'); assert.equal(rows[1].state,'closed');
assert.equal(w.githubWorldIssues('ghashtag/t27',[{...issue(),labels:[{name:'running'},{name:'t27'}]}])[0].state,'open');
assert.throws(()=>w.githubWorldMetadata('ghashtag/t27',{full_name:'other/repo',private:false}),/repository-mismatch/);
assert.throws(()=>w.githubWorldMetadata('ghashtag/t27',{full_name:'gHashTag/t27',private:true}),/public-only/);
assert.equal(w.githubWorldMetadata('ghashtag/t27',{full_name:'gHashTag/t27',private:false,description:'Compiler',has_issues:true}).repo,'ghashtag/t27');
const requested=[];const fetcher=async(url,opts)=>{requested.push({url,opts});return new Response(JSON.stringify([issue()]),{headers:{link:'<https://api.github.com/repos/ghashtag/t27/issues?page=2>; rel="next"'}});};
const page=await w.loadWorldIssues('ghashtag/t27',1,new AbortController().signal,fetcher);
assert.equal(page.hasMore,true);assert.equal(page.rows.length,1);assert.equal(requested[0].opts.credentials,'omit');
assert.match(requested[0].url,/per_page=100/);assert.equal(requested[0].opts.headers.Authorization,undefined);
await assert.rejects(w.loadWorldIssues('ghashtag/t27',1,new AbortController().signal,async()=>new Response('{}',{status:403,headers:{'x-ratelimit-remaining':'0'}})),/rate-limit/);
await assert.rejects(w.loadWorldIssues('ghashtag/t27',0,new AbortController().signal,fetcher),/invalid-page/);
assert.equal(w.mergeWorldIssues(rows,[{...rows[0],title:'Updated'}]).length,2);
assert.equal(w.mergeWorldIssues(rows,[{...rows[0],title:'Updated'}])[0].title,'Updated');
const specific=(overrides={})=>async()=>new Response(JSON.stringify({number:1258,title:'FIFO spec',html_url:'https://github.com/gHashTag/t27/issues/1258',state:'open',...overrides}),{status:200});
assert.equal((await w.loadWorldIssue('ghashtag/t27',1258,new AbortController().signal,specific())).number,1258,'deep links can load issues outside the first backlog page');
assert.equal(await w.loadWorldIssue('ghashtag/t27',1258,new AbortController().signal,specific({state:'closed'})),null,'closed issues cannot appear as current open backlog');
const detail=await w.loadWorldIssueDetails('ghashtag/t27',1258,new AbortController().signal,specific({state:'closed',body:'<script>untrusted()</script>',assignees:[{login:'real-agent'},{login:'<script>'}]}));
assert.equal(detail.state,'closed','inspector preserves lifecycle instead of resurrecting open tasks');
assert.deepEqual(detail.assignees,['real-agent']);assert.equal(detail.coverage,'unknown');
assert.equal(detail.body,'<script>untrusted()</script>','content stays text, not executable markup');
await assert.rejects(w.loadWorldIssue('ghashtag/t27',1258,new AbortController().signal,specific({pull_request:{}})),/issue-identity/);
await assert.rejects(w.loadWorldIssue('ghashtag/t27',1258,new AbortController().signal,specific({html_url:'https://github.com/other/repo/issues/1258'})),/issue-identity/);
// Reopening a cell must not spend one of the sixty reads an hour anonymous
// GitHub allows a visitor. Measured through the fetcher rather than asserted
// about in prose: the second look makes no request, a deliberate reload does,
// and a different number is a different cell.
const cached=new AbortController().signal;let reads=0;
const counted=(overrides={})=>async(url,opts)=>{reads++;return specific(overrides)(url,opts);};
assert.equal((await w.loadWorldIssueDetailsCached('ghashtag/t27',1258,cached,false,counted())).number,1258);
assert.equal(reads,1);
assert.equal((await w.loadWorldIssueDetailsCached('ghashtag/t27',1258,cached,false,counted({title:'Never read'}))).title,'FIFO spec','a second look at the same cell within the minute costs no GitHub read');
assert.equal(reads,1);
assert.equal((await w.loadWorldIssueDetailsCached('ghashtag/t27',1258,cached,true,counted({title:'Reloaded'}))).title,'Reloaded','a deliberate reload asks GitHub again');
assert.equal(reads,2);
let others=0;
const another=async()=>{others++;return new Response(JSON.stringify({number:1259,title:'Another cell',state:'open',html_url:'https://github.com/gHashTag/t27/issues/1259'}),{status:200});};
assert.equal((await w.loadWorldIssueDetailsCached('ghashtag/t27',1259,cached,false,another)).number,1259);
assert.equal(others,1,'the cache is keyed by cell and cannot answer for a number it never read');
// #1392: a refresh starts from nothing. A failed fresh read leaves no row
// behind for the next look to reuse, and a read superseded by a newer one for
// the same cell never writes the cache.
const failing=async()=>{reads++;return new Response('{}',{status:503});};
await assert.rejects(w.loadWorldIssueDetailsCached('ghashtag/t27',1258,cached,true,failing),/github-503/);
const afterFailure=reads;
assert.equal((await w.loadWorldIssueDetailsCached('ghashtag/t27',1258,cached,false,counted({title:'Read again'}))).title,'Read again','a failed refresh removed the old row instead of serving it');
assert.equal(reads,afterFailure+1);
{
  let arrive,release;const arrived=new Promise(r=>arrive=r),gate=new Promise(r=>release=r);
  const slow=async(url,opts)=>{arrive();await gate;return specific({number:1260,html_url:'https://github.com/gHashTag/t27/issues/1260',title:'Superseded'})(url,opts);};
  const a=w.loadWorldIssueDetailsCached('ghashtag/t27',1260,cached,false,slow);
  await arrived;
  await assert.rejects(w.loadWorldIssueDetailsCached('ghashtag/t27',1260,cached,true,async()=>new Response('{}',{status:503})),/github-503/);
  release();
  const late=await a;assert.equal(late.coverage,'unknown');assert.equal(late.proof,undefined,'a superseded read returns no proof');
  let again=0;
  await w.loadWorldIssueDetailsCached('ghashtag/t27',1260,cached,false,async(url,opts)=>{again++;return specific({number:1260,html_url:'https://github.com/gHashTag/t27/issues/1260',title:'Fresh'})(url,opts);});
  assert.equal(again,1,'the superseded read did not refill the cache');
}
// RETAIN: only a successful, latest refresh keeps an observed positive; the
// lifecycle survives as the last observation.
const positive={key:'dmitrii-f-t27/trinity-memory#115',repo:'dmitrii-f-t27/trinity-memory',number:115,title:'Attention',kind:'issue',state:'closed',closedAt:null,updatedAt:null,children:[],coverage:'t27',proof:{commit:'c'.repeat(40),specUrl:'s',ciUrl:'c',observedAt:1}};
for(const [ok,latest,kept] of [[false,false,false],[true,false,false],[false,true,false],[true,true,true]]){
  const r=w.retainObservation(positive,ok,latest);
  assert.equal(r.coverage,kept?'t27':'unknown');assert.equal(Boolean(r.proof),kept);assert.equal(r.state,'closed','lifecycle stays');
}
assert.deepEqual(w.withdrawWorldProof({[positive.key]:positive,'other/repo#1':{...positive,key:'other/repo#1',repo:'other/repo'}},positive.repo)[positive.key].coverage,'unknown');
assert.equal(w.withdrawWorldProof({'other/repo#1':{...positive,key:'other/repo#1',repo:'other/repo'}},positive.repo)['other/repo#1'].coverage,'t27','other worlds keep their own observation');
const ui=readFileSync(new URL('../src/pages/QueenUniverse.tsx',import.meta.url),'utf8');
assert.match(ui,/<RepositoryWorld key=\{repo\} repo=\{repo\}/,'switches unmount the old source');
assert.match(ui,/workers=\{null\} events=\{EMPTY_EVENTS\}/,'a public map cannot inherit runtime agents or review events');
assert.match(ui,/return\(\)=>request.current\?\.abort\(\)/,'unmount aborts in-flight world reads');
assert.match(ui,/queenRepositoryPicker===true/,'sign-in stays gated until the actual service supports the picker');
assert.doesNotMatch(ui,/localStorage\.(?:get|set)Item\([^)]*(?:token|secret)/i);
const css=readFileSync(new URL('../src/pages/QueenUniverse.css',import.meta.url),'utf8');
assert.doesNotMatch(css,/\.queen-universe button[\s:{]/,'world toolbar styles cannot override native issue-card buttons');
assert.match(css,/\.queen-universe :is\(\.queen-universe-nav,\.queen-world-dialog\) \.queen-world-connect\s*\{/,'green connection CTA must outrank the generic toolbar button rule');
console.log('Repository worlds: PASS (identity, public-only, no PRs, no invented telemetry, pagination, credentials, rate limits)');
