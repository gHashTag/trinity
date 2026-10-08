import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
// Issue #1513: the catalog map read page 1 of a repository's issues and never asked for page 2.
// Driven through a fake fetcher that answers like GitHub's issues endpoint: issues and pull requests
// mixed, 100 records to a page, a Link header only when another page exists.
const pages=await import('../src/components/queenWorldPages.ts');
const w=await import('../src/components/queenRepositoryWorld.ts');
const {worldPagesPolicy:policy}=await import('../src/lib/queenWorldPages.generated.ts');
const MAX=policy.MAX_PAGES;
const REPO='other/world';
const live=()=>new AbortController().signal;

// --- the policy: spec, generated constants, conformance vectors -----------------------------------
const specText=readFileSync(new URL('../specs/queen/world_pages.t27',import.meta.url));
const vectors=JSON.parse(readFileSync(new URL('../conformance/queen_world_pages.json',import.meta.url),'utf8'));
assert.equal(vectors.spec_hash,createHash('sha256').update(specText).digest('hex'),'conformance vectors belong to this spec');
assert.equal(vectors.vectors.length,16+8+2);
assert.equal(MAX,5);assert.equal(policy.PER_PAGE,100);
for(const v of vectors.vectors){
  const bit=(mask,i)=>Boolean(mask&(1<<i));
  const got=v.table==='NEXT'?pages.wantsNextPage(bit(v.mask,0),bit(v.mask,1),bit(v.mask,2)?1:MAX,bit(v.mask,3))
    :v.table==='COMPLETE'?pages.worldComplete(bit(v.mask,0),bit(v.mask,1),bit(v.mask,2))
    :pages.dropsUnseen(Boolean(v.mask));
  assert.equal(got,v.expected===1,`${v.table}[${v.mask}]`);
}
assert.equal(pages.WORLD_MAX_PAGES,MAX);

// --- a GitHub-shaped fake -------------------------------------------------------------------------
// Records are numbered 1..total; `isIssue(n)` says which ones are issues, the rest are pull requests.
function listing({total,isIssue,repo=REPO,failPage=null,alwaysNext=false,omitLink=false,state=()=>'open',title=n=>`Issue ${n}`}){
  const log=[];let inFlight=0,overlap=false;
  const fetcher=async(url,opts)=>{
    assert.equal(opts.credentials,'omit');assert.equal(opts.headers.Authorization,undefined);
    const m=/\/issues\?state=all&sort=created&direction=asc&per_page=100&page=(\d+)$/.exec(url);
    if(!m)return new Response('unavailable',{status:503}); // proof reads of a supported world: not under test here
    const page=Number(m[1]);
    if(inFlight++)overlap=true;
    await new Promise(r=>setTimeout(r,1));
    inFlight--;
    log.push(page);
    if(page===failPage)return new Response('{}',{status:403,headers:{'x-ratelimit-remaining':'0'}});
    const records=[];
    for(let n=(page-1)*100+1;n<=Math.min(total,page*100);n++)records.push(isIssue(n)
      ?{number:n,title:title(n),state:state(n),html_url:`https://github.com/${repo}/issues/${n}`,updated_at:'2026-10-07T00:00:00Z'}
      :{number:n,title:`PR ${n}`,state:'open',pull_request:{},html_url:`https://github.com/${repo}/pull/${n}`});
    const more=alwaysNext||page*100<total;
    const headers=omitLink?{}:{link:more?`<https://api.github.com/repositories/1/issues?page=${page+1}>; rel="next"`:`<https://api.github.com/repositories/1/issues?page=${page-1}>; rel="prev"`};
    return new Response(JSON.stringify(records),{headers});
  };
  return {fetcher,log,overlapped:()=>overlap};
}
async function load(spec,{repo=REPO,signal=live(),onRead}={}){
  const fake=listing({...spec,repo}),reads=[];
  const result=await pages.readWorldPages(repo,signal,r=>{reads.push(r);onRead?.(r);},fake.fetcher);
  return {fake,reads,result};
}

// --- the measured case: trinity-memory has 47 issues in the first 100 records and 13 more on page 2 -
const memory='dmitrii-f-t27/trinity-memory';
const memoryIssue=n=>n<=100?!(n%2===0||n===1||n===3||n===5):n>=103&&n<=127&&n%2===1;
{
  const first=await w.loadWorldIssues(memory,1,live(),listing({total:131,isIssue:memoryIssue,repo:memory}).fetcher);
  assert.equal(first.rows.length,47,'page 1 alone shows 47 issues');
  assert.equal(first.hasMore,true);
  const {fake,reads,result}=await load({total:131,isIssue:memoryIssue},{repo:memory});
  assert.deepEqual(fake.log,[1,2],'the second page is requested');
  assert.equal(result.rows.length,60,'both pages: 47 + 13 issues');
  assert.equal(result.rows.filter(r=>r.number>=103).length,13);
  assert.ok(result.rows.every(r=>r.repo===memory&&r.state==='open'));
  assert.equal(result.complete,true);assert.equal(result.done,true);assert.equal(result.pages,2);assert.equal(result.error,null);
  assert.deepEqual(reads.map(r=>[r.pages,r.done,r.complete,r.rows.length]),[[1,false,false,47],[2,true,true,60]],'page 1 is shown at once, the world is complete only at the end');
  assert.equal(fake.overlapped(),false,'pages are read one at a time');
}

// --- pages: mixed pull requests, Link header, three pages ------------------------------------------
{
  const {fake,reads,result}=await load({total:231,isIssue:n=>n%3!==0});
  assert.deepEqual(fake.log,[1,2,3]);
  assert.equal(result.rows.length,231-Math.floor(231/3),'every issue of three pages, no pull request');
  assert.deepEqual(result.rows.map(r=>r.number),[...result.rows.map(r=>r.number)].sort((a,b)=>a-b),'rows stay in issue order');
  assert.deepEqual(reads.map(r=>[r.pages,r.done]),[[1,false],[2,false],[3,true]]);
  assert.equal(result.complete,true);
  assert.ok(reads.slice(0,-1).every(r=>!r.complete),'a world is never complete while a page is still announced');
}
// A single short page: one request, complete.
{
  const {fake,result}=await load({total:12,isIssue:()=>true});
  assert.deepEqual(fake.log,[1]);assert.equal(result.rows.length,12);assert.equal(result.complete,true);
}
// No Link header at all: a full page means "maybe more", a short page means the end (the old fallback).
{
  const {fake,result}=await load({total:130,isIssue:()=>true,omitLink:true});
  assert.deepEqual(fake.log,[1,2]);assert.equal(result.rows.length,130);assert.equal(result.complete,true);
}
// An exact multiple of 100 with a Link header that says the end: no empty extra page.
{
  const {fake,result}=await load({total:200,isIssue:()=>true});
  assert.deepEqual(fake.log,[1,2]);assert.equal(result.complete,true);
}

// --- the ceiling -------------------------------------------------------------------------------------
{
  const {fake,reads,result}=await load({total:10_000,isIssue:()=>true});
  assert.deepEqual(fake.log,Array.from({length:MAX},(_,i)=>i+1),`exactly ${MAX} pages are requested, never page ${MAX+1}`);
  assert.equal(result.rows.length,MAX*100);
  assert.equal(result.done,true);assert.equal(result.complete,false,'a capped world is partial');assert.equal(result.error,null);
  assert.equal(reads.at(-1).pages,MAX);
}
{
  // The ceiling is reached by a server that never stops announcing pages.
  const {fake,result}=await load({total:50,isIssue:()=>true,alwaysNext:true});
  assert.ok(fake.log.length<=MAX);assert.equal(result.complete,false);
}
// Exactly MAX full pages and no next page: complete, and still no page MAX+1.
{
  const {fake,result}=await load({total:MAX*100,isIssue:()=>true});
  assert.equal(fake.log.length,MAX);assert.equal(result.complete,true);
}

// --- the first failure stops the loading -------------------------------------------------------------
{
  const {fake,reads,result}=await load({total:300,isIssue:()=>true,failPage:2});
  assert.deepEqual(fake.log,[1,2],'page 3 is not requested after page 2 failed');
  assert.equal(result.rows.length,100,'the rows of page 1 are kept');
  assert.equal(result.complete,false);assert.equal(result.done,true);assert.equal(result.pages,1);assert.equal(result.error,'rate-limit');
  assert.deepEqual(reads.map(r=>[r.done,r.complete,r.error]),[[false,false,null],[true,false,'rate-limit']]);
}
{
  const {fake,result}=await load({total:300,isIssue:()=>true,failPage:3});
  assert.deepEqual(fake.log,[1,2,3]);assert.equal(result.rows.length,200);assert.equal(result.complete,false);
}
{
  // Page 1 failing is the old failure: nothing was read, the caller withdraws proof.
  const reads=[];
  await assert.rejects(pages.readWorldPages(REPO,live(),r=>reads.push(r),listing({total:300,isIssue:()=>true,failPage:1}).fetcher),/rate-limit/);
  assert.equal(reads.length,0);
}
// An unreadable body of a later page is a failure too.
{
  let calls=0;
  const bad=async(url,opts)=>{calls++;return calls===1?listing({total:300,isIssue:()=>true}).fetcher(url,opts):new Response('not json',{status:200});};
  const result=await pages.readWorldPages(REPO,live(),()=>{},bad);
  assert.equal(result.complete,false);assert.equal(result.rows.length,100);assert.equal(calls,2);
}

// --- aborting ----------------------------------------------------------------------------------------
{
  const controller=new AbortController(),fake=listing({total:300,isIssue:()=>true}),reads=[];
  const result=await pages.readWorldPages(REPO,controller.signal,r=>{reads.push(r);controller.abort();},fake.fetcher);
  assert.deepEqual(fake.log,[1],'an aborted load requests nothing more');
  assert.equal(result.complete,false);
}
{
  // Aborted while the last page is in flight: even though the pages ran out, a dead caller does not complete a world.
  const controller=new AbortController(),fake=listing({total:50,isIssue:()=>true});
  const result=await pages.readWorldPages(REPO,controller.signal,()=>{},async(url,opts)=>{const r=await fake.fetcher(url,opts);controller.abort();return r;});
  assert.equal(result.complete,false);
}
{
  // A fetch rejected because the signal aborted rejects the load, whatever page it was.
  const controller=new AbortController();let n=0;
  await assert.rejects(pages.readWorldPages(REPO,controller.signal,()=>{},async(url,opts)=>{
    if(++n===2){controller.abort();throw new DOMException('aborted','AbortError');}
    return listing({total:300,isIssue:()=>true}).fetcher(url,opts);
  }),/aborted/);
}

// --- merging across pages: one row per issue ----------------------------------------------------------
{
  const fake=listing({total:150,isIssue:()=>true,title:n=>`Issue ${n}`});
  const overlap=async(url,opts)=>{
    const r=await fake.fetcher(url,opts);
    if(!/page=2$/.test(url))return r;
    // Page 2 repeats #100 (the list shifted) with a newer title and also lists #7 again.
    const rows=await r.json();
    return new Response(JSON.stringify([{...rows[0],number:100,title:'Issue 100 renamed',html_url:`https://github.com/${REPO}/issues/100`},{...rows[1],number:7,title:'Issue 7 again',html_url:`https://github.com/${REPO}/issues/7`},...rows]),{headers:r.headers});
  };
  const result=await pages.readWorldPages(REPO,live(),()=>{},overlap);
  assert.equal(result.rows.length,150,'duplicates across pages are merged by key');
  assert.equal(new Set(result.rows.map(r=>r.key)).size,150);
  assert.equal(result.rows.find(r=>r.number===100).title,'Issue 100 renamed','the later read wins');
  assert.deepEqual(result.rows.map(r=>r.number),Array.from({length:150},(_,i)=>i+1));
}

// --- a supported world whose proof cannot be read: the pages still load, nothing is invented ----------
{
  // Every non-listing read answers 503, so the Memory reader cannot verify; closed issues stay unknown.
  const {result}=await load({total:131,isIssue:memoryIssue,state:n=>n>=103?'closed':'open'},{repo:memory});
  assert.equal(result.rows.length,60);
  assert.ok(result.rows.every(r=>r.coverage==='unknown'&&r.proof===undefined),'no proof without a verified read');
  assert.equal(result.rows.filter(r=>r.state==='closed').length,13,'the newest issues are on the map, closed');
}

// --- folding a read into the map: what a partial load does to what an earlier visit showed ------------
const row=(n,extra={})=>({key:`${memory}#${n}`,repo:memory,number:n,title:`Issue ${n}`,kind:'issue',state:'closed',closedAt:null,updatedAt:null,children:[],coverage:'unknown',...extra});
const honey=(n,at=1)=>row(n,{coverage:'t27',proof:{commit:'c'.repeat(40),specUrl:'s',ciUrl:'c',observedAt:at}});
const read=(rows,over={})=>({rows,pages:1,done:true,complete:false,error:null,...over});
{
  // Earlier visit: #5 (page 1) and #115 (page 2) had proof; another world has one too.
  const other={key:'other/repo#1',repo:'other/repo',number:1,title:'x',kind:'issue',state:'closed',closedAt:null,updatedAt:null,children:[],coverage:'t27',proof:{commit:'d'.repeat(40),specUrl:'s',ciUrl:'c',observedAt:1}};
  const before={[`${memory}#5`]:honey(5,1),[`${memory}#115`]:honey(115,1),[other.key]:other};
  const fresh5=honey(5,2);
  // While the load runs nothing unseen is touched.
  const running=pages.applyWorldRead(before,memory,read([fresh5],{done:false}));
  assert.equal(running[`${memory}#115`].proof.observedAt,1,'an unseen row is not touched while pages are still coming');
  assert.equal(running[`${memory}#5`].proof.observedAt,2);
  // Page 2 failed: #5 was read again and keeps its new proof; #115 was not, so its proof is withdrawn and its lifecycle stays.
  const failed=pages.applyWorldRead(before,memory,read([fresh5],{error:'rate-limit'}));
  assert.equal(failed[`${memory}#5`].coverage,'t27');assert.equal(failed[`${memory}#5`].proof.observedAt,2,'a row this load read keeps what this load proved');
  assert.equal(failed[`${memory}#115`].coverage,'unknown');assert.equal(failed[`${memory}#115`].proof,undefined,'an old positive is not shown as new');
  assert.equal(failed[`${memory}#115`].state,'closed','the lifecycle stays as the last observation');
  assert.equal(failed[other.key],other,'another world is untouched');
  // The ceiling stopped a load that did not fail: the same, the world is partial.
  const capped=pages.applyWorldRead(before,memory,read([fresh5],{pages:MAX}));
  assert.equal(capped[`${memory}#115`].proof,undefined);
  // The whole world was read and #115 is not in it any more: the row goes.
  const complete=pages.applyWorldRead(before,memory,read([fresh5],{complete:true}));
  assert.equal(Object.hasOwn(complete,`${memory}#115`),false);
  assert.equal(complete[other.key],other);
  // New rows append after the existing ones, so map slots do not shift while pages arrive.
  const grown=pages.applyWorldRead(before,memory,read([fresh5,row(103),row(105)],{done:false}));
  assert.deepEqual(Object.keys(grown),[`${memory}#5`,`${memory}#115`,other.key,`${memory}#103`,`${memory}#105`]);
  // Applying the same read twice changes nothing.
  assert.deepEqual(pages.applyWorldRead(grown,memory,read([fresh5,row(103),row(105)],{done:false})),grown);
}

// --- the hive uses it, keeps the #1392 failure path, and no longer reads page 1 only -------------------
const ui=readFileSync(new URL('../src/components/QueenCatalogHive.tsx',import.meta.url),'utf8');
assert.doesNotMatch(ui,/loadWorldIssues\(/,'the hive no longer reads page 1 only');
assert.match(ui,/readWorldPages\(repo,request\.signal,/);
assert.match(ui,/setObserved\(prev=>applyWorldRead\(prev,repo,read\)\)/);
assert.match(ui,/if\(read\.done\)setCompleteWorlds\(prev=>\[\.\.\.prev\.filter\(r=>r!==repo\),\.\.\.\(read\.complete\?\[repo\]:\[\]\)\]\)/,'a world is complete only when the load ended complete');
assert.match(ui,/if\(!request\.signal\.aborted\)setObserved\(prev=>withdrawWorldProof\(prev,repo\)\)/,'a failed first page still withdraws proof (#1392)');
assert.match(ui,/if\(!request\.signal\.aborted\)setCompleteWorlds\(prev=>prev\.filter\(r=>r!==repo\)\)/,'a failed load leaves the world partial');
assert.doesNotMatch(ui,/hasMore/,'completeness is decided by the spec, not by the first page');
assert.match(ui,/if\(!repo\|\|!supportsIssueProof\(repo\)\)return;/,'worlds without issue proof are not read');
console.log(`World pages: PASS (policy tables, ${MAX}-page ceiling, Link header, mixed pull requests, failure on page 2, abort, merge, partial-load proof)`);
