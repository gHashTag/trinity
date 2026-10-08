import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {createIssueProofReader,createGroupedIssueProofReader} from '../src/lib/queenIssueProof.ts';
import {issueProofPolicy as production} from '../src/lib/queenIssueProof.generated.ts';
import {proofCommitPolicy as walk} from '../src/lib/queenProofCommit.generated.ts';

// Issue #1563: while the CI of a new HEAD is still running, a proof may cite the newest older commit that
// passed, if (and only if) the pinned evidence is the pinned bytes at HEAD too. Fixtures with real SHA-256,
// a replaced fetch, no network. The walk itself is the WALK table of specs/queen/proof_commit.t27.
const hash=text=>createHash('sha256').update(text).digest('hex');
const signal=new AbortController().signal;
const SHAS=['a','b','c','d','e','f'].map(c=>c.repeat(40)); // [0] is the default-branch HEAD, the rest are older
const ago=ms=>new Date(Date.now()-ms).toISOString();
const MIN=60000,GRACE=walk.PENDING_GRACE_MS;
let cases=0;

// ci[sha]: success | failure | in_progress | cancelled | none (no run exists). Missing keys mean none.
function runsFor(sha,state,paths){
  if(!state||state==='none')return [];
  const base=1000*(SHAS.indexOf(sha)+1);
  return paths.map((path,i)=>({id:base+i,head_sha:sha,event:'push',path,status:state==='in_progress'?'in_progress':'completed',conclusion:state==='in_progress'?null:state,html_url:null,repository:{full_name:null},_path:path}));
}
// Public HTTP boundary: every GitHub URL is recorded, every raw file is pinned to the commit in its path.
function router({repo,dates,ci,filesAt,workflows}){
  const calls={api:0,runs:0,list:0,raw:0};
  const commitJson=i=>({sha:SHAS[i],commit:{committer:{date:dates[i]===null?undefined:ago(dates[i]??(i+1)*10*MIN)}}});
  const fetcher=async(url,opts)=>{
    assert.equal(opts.credentials,'omit');assert.equal(opts.cache,'no-store');assert.equal(opts.headers.Authorization,undefined);
    if(url.startsWith('https://api.github.com/'))calls.api++;
    if(url.endsWith('/commits/HEAD'))return Response.json(commitJson(0));
    const list=url.match(/\/commits\?sha=([a-f0-9]{40})&per_page=(\d+)$/);
    if(list){calls.list++;assert.equal(list[1],SHAS[0],'older commits are listed from HEAD');return Response.json(SHAS.slice(0,Number(list[2])).map((_,i)=>commitJson(i)));}
    if(url.includes('/actions/runs?')){
      calls.runs++;const sha=url.match(/head_sha=([a-f0-9]{40})/)[1];
      const runs=runsFor(sha,ci[sha],workflows(sha)).map(r=>({...r,html_url:`https://github.com/${repo}/actions/runs/${r.id}`,repository:{full_name:repo}}));
      return Response.json({workflow_runs:runs});
    }
    const m=url.match(new RegExp(`^https://raw.githubusercontent.com/${repo}/([a-f0-9]{40})/(.+)$`));
    assert.ok(m,`unexpected URL ${url}`);calls.raw++;
    const bytes=filesAt(m[1]).get(m[2]);
    return new Response(bytes??'missing',{status:bytes===undefined?404:200});
  };
  return {fetcher,calls};
}

// ---- Corona-style reader (one spec, canonical + GDS workflow) ----
const repo=production.REPO;
const row=(n=production.ISSUES[0])=>({key:`${repo}#${n}`,repo,number:n,title:'Phase A',kind:'issue',state:'closed',closedAt:'2026-10-03T13:05:56Z',children:[],coverage:'unknown'});
function single({ci={},dates={},tamper={}}={}){
  const spec=production.ISSUES.map(n=>`; https://github.com/${repo}/issues/${n}`).join('\n');
  const seal={spec_path:production.SPEC,spec_hash:`sha256:${hash(spec)}`,...Object.fromEntries(['c','rust','verilog','zig'].map(b=>[`gen_hash_${b}`,`sha256:${'b'.repeat(64)}`]))};
  const vectors={spec_path:production.SPEC,spec_hash:seal.spec_hash,vectors:[{expected:false},{expected:true}]};
  const files=new Map([[production.SPEC,spec],[production.SEAL,JSON.stringify(seal)],[production.VECTORS,JSON.stringify(vectors)],[production.VERIFIER,'verifier fixture'],[production.WORKFLOW,'workflow fixture'],[production.GDS_WORKFLOW,'GDS workflow fixture'],[production.MAKEFILE,'make fixture']]);
  const policy={...production,VECTOR_COUNT:2,...Object.fromEntries(['SPEC','SEAL','VECTORS','VERIFIER','WORKFLOW','GDS_WORKFLOW','MAKEFILE'].map(k=>[`${k}_HASH`,hash(files.get(production[k]))]))};
  const filesAt=sha=>tamper[sha]?new Map([...files,[tamper[sha],files.get(tamper[sha])+' changed']]):files;
  const r=router({repo,dates,ci,filesAt,workflows:()=>[production.WORKFLOW,production.GDS_WORKFLOW]});
  return {...r,reader:createIssueProofReader(policy)};
}
async function corona(label,options,expected){
  const f=single(options);
  const out=(await f.reader.proveWorldIssues([row()],repo,signal,f.fetcher))[0];
  assert.equal(out.coverage,expected.commit?'t27':'unknown',label);
  if(expected.commit){
    assert.equal(out.proof.commit,SHAS[expected.commit.index],`${label}: proof names the cited commit`);
    assert.ok(out.proof.specUrl.includes(`/blob/${SHAS[expected.commit.index]}/`),`${label}: spec link is at the cited commit`);
    assert.ok(out.proof.ciUrl.endsWith(`/actions/runs/${1000*(expected.commit.index+1)}`),`${label}: CI link is the run of the cited commit`);
  }else assert.equal(out.proof,undefined,label);
  if(expected.maxApi!==undefined)assert.ok(f.calls.api<=expected.maxApi,`${label}: ${f.calls.api} API requests, at most ${expected.maxApi}`);
  if(expected.api!==undefined)assert.equal(f.calls.api,expected.api,`${label}: API requests`);
  cases++;
  return f;
}
const at=index=>({commit:{index}});
const none={};
// HEAD green: the normal case, two API requests, no older commit is ever listed.
{const f=await corona('HEAD green',{ci:{[SHAS[0]]:'success'}},{...at(0),api:2});assert.equal(f.calls.list,0);}
// HEAD pending in each of its four forms, the previous commit green.
for(const pending of ['none','in_progress','cancelled'])await corona(`HEAD ${pending}, previous green`,{ci:{[SHAS[0]]:pending,[SHAS[1]]:'success'}},{...at(1),api:4});
await corona('two pending, third green',{ci:{[SHAS[1]]:'in_progress',[SHAS[2]]:'success'}},{...at(2),maxApi:walk.MAX_BEHIND+3});
await corona('a cancelled run in the middle is only pending',{ci:{[SHAS[0]]:'in_progress',[SHAS[1]]:'cancelled',[SHAS[2]]:'success'}},at(2));
await corona('the last commit inside the bound may be the green one',{ci:{[SHAS[walk.MAX_BEHIND]]:'success'}},at(walk.MAX_BEHIND));
// A failure is never skipped, wherever it is.
await corona('HEAD failed, previous green',{ci:{[SHAS[0]]:'failure',[SHAS[1]]:'success'}},none);
await corona('HEAD pending, previous failed, older green',{ci:{[SHAS[1]]:'failure',[SHAS[2]]:'success'}},none);
await corona('HEAD green and the previous one green too: HEAD is cited',{ci:{[SHAS[0]]:'success',[SHAS[1]]:'success'}},at(0));
// The bounds: age and depth. An unknown date is not young.
await corona('HEAD pending longer than the grace',{dates:{0:GRACE+MIN},ci:{[SHAS[1]]:'success'}},none);
await corona('HEAD pending just inside the grace',{dates:{0:GRACE-MIN},ci:{[SHAS[1]]:'success'}},at(1));
await corona('HEAD pending with no commit date',{dates:{0:null},ci:{[SHAS[1]]:'success'}},none);
await corona('a skipped middle commit older than the grace',{dates:{0:MIN,1:GRACE+MIN},ci:{[SHAS[2]]:'success'}},none);
{
  const f=await corona('everything pending to the end of the bound',{dates:Object.fromEntries(SHAS.map((_,i)=>[i,MIN])),ci:{[SHAS[walk.MAX_BEHIND+1]]:'success'}},{...none,maxApi:walk.MAX_BEHIND+3});
  assert.equal(f.calls.runs,walk.MAX_BEHIND+1,'no commit beyond MAX_BEHIND is read');
}
// A list longer than the one asked for is not read past the bound: the green commit at index MAX_BEHIND + 1 stays out of reach.
{
  const f=single({dates:Object.fromEntries(SHAS.map((_,i)=>[i,MIN])),ci:{[SHAS[walk.MAX_BEHIND+1]]:'success'}});
  const generous=async(url,opts)=>url.includes('/commits?sha=')?Response.json(SHAS.map(sha=>({sha,commit:{committer:{date:ago(MIN)}}}))):f.fetcher(url,opts);
  assert.equal((await f.reader.proveWorldIssues([row()],repo,signal,generous))[0].coverage,'unknown','list longer than asked');
  assert.equal(f.calls.runs,walk.MAX_BEHIND+1,'no commit beyond MAX_BEHIND is read');cases++;
}
// The pinned evidence must be the pinned bytes at HEAD too, with or without CI there.
for(const path of [production.SPEC,production.SEAL,production.VECTORS,production.VERIFIER,production.WORKFLOW,production.GDS_WORKFLOW,production.MAKEFILE]){
  await corona(`HEAD pending, ${path} changed at HEAD`,{tamper:{[SHAS[0]]:path},ci:{[SHAS[1]]:'success'}},none);
  await corona(`HEAD pending, ${path} changed at the cited commit`,{tamper:{[SHAS[1]]:path},ci:{[SHAS[1]]:'success'}},none);
}
// A failed list of older commits, a list that does not start at HEAD, and a rate limit all end as unknown.
{
  const f=single({ci:{[SHAS[1]]:'success'}});
  const limited=async(url,opts)=>url.includes('/commits?sha=')?new Response('limited',{status:403}):f.fetcher(url,opts);
  assert.equal((await f.reader.proveWorldIssues([row()],repo,signal,limited))[0].coverage,'unknown','list of older commits rate limited');cases++;
  const g=single({ci:{[SHAS[1]]:'success'}});
  const wrong=async(url,opts)=>url.includes('/commits?sha=')?Response.json([{sha:SHAS[3]},{sha:SHAS[1]}]):g.fetcher(url,opts);
  assert.equal((await g.reader.proveWorldIssues([row()],repo,signal,wrong))[0].coverage,'unknown','list that does not start at HEAD');cases++;
}

// ---- Grouped (Memory-style) reader: several specs, one with its own replay workflow ----
const mrepo='example/memory';
const issues=[10,11],G=2;
function grouped({ci={},replay={},dates={},tamper={}}={}){
  const text=['specs/a.t27','specs/b.t27'].map((p,g)=>`; https://github.com/${mrepo}/issues/${issues[g]}`);
  const files=new Map([['Makefile','make'],['.github/workflows/ci.yml','ci wf'],['tools/gate.py','gate'],['.github/workflows/replay.yml','replay wf']]);
  ['a','b'].forEach((n,g)=>{
    const spec=text[g],seal={spec_path:`specs/${n}.t27`,spec_hash:`sha256:${hash(spec)}`,...Object.fromEntries(['c','rust','verilog','zig'].map(b=>[`gen_hash_${b}`,`sha256:${'b'.repeat(64)}`]))};
    files.set(`specs/${n}.t27`,spec);files.set(`seals/${n}.json`,JSON.stringify(seal));
    files.set(`vectors/${n}.json`,JSON.stringify({spec_path:`specs/${n}.t27`,spec_hash:seal.spec_hash,vectors:[{},{}]}));
  });
  const H=p=>hash(files.get(p));
  const policy={REPO:mrepo,WORKFLOW:'.github/workflows/ci.yml',WORKFLOW_HASH:H('.github/workflows/ci.yml'),MAKEFILE:'Makefile',MAKEFILE_HASH:H('Makefile'),
    GLOBAL_PATHS:['tools/gate.py'],GLOBAL_HASHES:[H('tools/gate.py')],GROUP_NAMES:['a','b'],
    GROUP_SPEC:['specs/a.t27','specs/b.t27'],GROUP_SPEC_HASH:['specs/a.t27','specs/b.t27'].map(H),
    GROUP_SEAL:['seals/a.json','seals/b.json'],GROUP_SEAL_HASH:['seals/a.json','seals/b.json'].map(H),
    GROUP_VECTORS:['vectors/a.json','vectors/b.json'],GROUP_VECTORS_HASH:['vectors/a.json','vectors/b.json'].map(H),GROUP_VECTOR_COUNT:[2,2],
    GROUP_EVIDENCE:['',''],GROUP_WORKFLOW:['','.github/workflows/replay.yml'],GROUP_PATHS:['.github/workflows/replay.yml'],GROUP_PATH_HASHES:[H('.github/workflows/replay.yml')],GROUP_PATH_OWNER:[1],
    ISSUE_NUMBERS:issues,ISSUE_GROUPS:[0,1],CACHE_MS:60000,ACCEPT:Array.from({length:16},(_,i)=>Number(i===15))};
  const filesAt=sha=>tamper[sha]?new Map([...files,[tamper[sha],files.get(tamper[sha])+' changed']]):files;
  // Both workflows per commit: the canonical one follows ci[], the replay one follows replay[] (default: the same as ci[]).
  const r=router({repo:mrepo,dates,ci:{},filesAt,workflows:()=>[]});
  const fetcher=async(url,opts)=>{
    if(url.includes('/actions/runs?')){
      r.calls.api++;r.calls.runs++;const sha=url.match(/head_sha=([a-f0-9]{40})/)[1];
      const mk=(path,state,k)=>runsFor(sha,state,[path]).map(x=>({...x,id:x.id+k,html_url:`https://github.com/${mrepo}/actions/runs/${x.id+k}`,repository:{full_name:mrepo}}));
      return Response.json({workflow_runs:[...mk('.github/workflows/ci.yml',ci[sha],0),...mk('.github/workflows/replay.yml',replay[sha]??ci[sha],500)]});
    }
    return r.fetcher(url,opts);
  };
  return {...r,fetcher,reader:createGroupedIssueProofReader(policy)};
}
async function memory(label,options,expected){
  const f=grouped(options);
  const out=await f.reader.proveWorldIssues(issues.map(n=>({...row(n),repo:mrepo,key:`${mrepo}#${n}`})),mrepo,signal,f.fetcher);
  issues.forEach((n,i)=>{
    const want=expected[n];
    assert.equal(out[i].coverage,want?'t27':'unknown',`${label}: #${n}`);
    if(want){assert.equal(out[i].proof.commit,SHAS[want.index],`${label}: #${n} cites the passed commit`);assert.ok(out[i].proof.specUrl.includes(`/blob/${SHAS[want.index]}/`),`${label}: #${n} spec link`);}
    cases++;
  });
  return f;
}
const both=index=>({10:{index},11:{index}});
{const f=await memory('HEAD green',{ci:{[SHAS[0]]:'success'}},both(0));assert.equal(f.calls.api,2);}
await memory('HEAD pending, previous green',{ci:{[SHAS[1]]:'success'}},both(1));
await memory('the replay still runs at HEAD but passed at the cited commit',{ci:{[SHAS[0]]:'in_progress',[SHAS[1]]:'success'}},both(1));
await memory('the replay failed at the cited commit: only its group is unknown',{ci:{[SHAS[1]]:'success'},replay:{[SHAS[1]]:'failure'}},{10:{index:1}});
await memory('a group file changed at HEAD: only its group is unknown',{ci:{[SHAS[1]]:'success'},tamper:{[SHAS[0]]:'specs/a.t27'}},{11:{index:1}});
await memory('the replay workflow changed at HEAD: its group is unknown',{ci:{[SHAS[1]]:'success'},tamper:{[SHAS[0]]:'.github/workflows/replay.yml'}},{10:{index:1}});
await memory('a shared file changed at HEAD: everything is unknown',{ci:{[SHAS[1]]:'success'},tamper:{[SHAS[0]]:'tools/gate.py'}},{});
await memory('the workflow file changed at HEAD: everything is unknown',{ci:{[SHAS[1]]:'success'},tamper:{[SHAS[0]]:'.github/workflows/ci.yml'}},{});
await memory('HEAD failed',{ci:{[SHAS[0]]:'failure',[SHAS[1]]:'success'}},{});
await memory('HEAD pending longer than the grace',{dates:{0:GRACE+MIN},ci:{[SHAS[1]]:'success'}},{});
await memory('three pending, fourth green',{ci:{[SHAS[3]]:'success'}},both(3));

const matrix=JSON.parse(readFileSync(new URL('../conformance/queen_proof_commit.json',import.meta.url)));
for(const v of matrix.vectors)assert.equal(walk.WALK[v.mask],v.expected);
assert.equal(matrix.vectors.length,6);
console.log(`Proof commit: ${cases} cases and ${matrix.vectors.length} conformance vectors PASS`);
