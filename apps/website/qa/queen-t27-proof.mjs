import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {createMergedPrSpecReader,supportsIssueProof} from '../src/lib/queenIssueProof.ts';
import {t27IssueProofPolicy as production} from '../src/lib/queenT27IssueProof.generated.ts';

// t27 proof: a closed issue is covered by a merged PR that closed it, sealed current specs and green required checks.
// Public HTTP boundary fixtures with real SHA-256; the API allowance is modelled, not assumed.
const repo=production.REPO,commit='e'.repeat(40),mergeSha='1'.repeat(40),headSha='2'.repeat(40),signal=new AbortController().signal;
const hash=s=>createHash('sha256').update(s).digest('hex');
const row=(number,state='closed',r=repo)=>({key:`${r}#${number}`,repo:r,number,state,kind:'issue',title:`Issue ${number}`,closedAt:'2026-10-07T01:00:00Z',children:[],coverage:'unknown'});
const green=()=>production.REQUIRED_CHECKS.map((name,i)=>({id:10+i,name,status:'completed',conclusion:'success'}));
function fixture(over={}){
  const spec='// spec of issue 7001\nmodule m {}\n';
  const seal={spec_path:'specs/port/m.t27',spec_hash:`sha256:${hash(spec)}`,tests:{failed:0,passed:3,total:3,failing:[]}};
  const f={reads:[],apiReads:0,files:new Map([['specs/port/m.t27',spec],['.trinity/seals/m.json',JSON.stringify(seal)]]),
    index:{repo,issues:{7001:[{pr:900,sha:mergeSha,specs:[{path:'specs/port/m.t27',seal:'.trinity/seals/m.json'}]}],7002:[{pr:901,sha:mergeSha,specs:[]}]}},
    pull:{merged:true,merge_commit_sha:mergeSha,head:{sha:headSha},body:'Adds the port.\n\nCloses #7001'},
    runs:green(),limited:false,headFail:false,...over};
  f.fetcher=async(url,options)=>{
    assert.equal(options.credentials,'omit');assert.equal(options.cache,'no-store');
    f.reads.push(url);
    if(url.startsWith('https://api.github.com/')){
      f.apiReads++;
      if(f.limited)return new Response('limit',{status:403});
      if(url.endsWith('/commits/HEAD'))return f.headFail?new Response('x',{status:500}):Response.json({sha:commit});
      if(/\/pulls\/\d+$/.test(url))return f.pull?Response.json(f.pull):new Response('no',{status:404});
      if(url.includes(`/commits/${headSha}/check-runs`))return Response.json({check_runs:f.runs});
      return new Response('unexpected',{status:404});
    }
    if(url===`https://raw.githubusercontent.com/${production.INDEX_REPO}/${production.INDEX_REF}/${production.INDEX_PATH}`)return Response.json(f.index);
    const prefix=`https://raw.githubusercontent.com/${repo}/${commit}/`;
    assert.ok(url.startsWith(prefix),url);const body=f.files.get(url.slice(prefix.length));
    return new Response(body??'missing',{status:body===undefined?404:200});
  };
  f.reader=createMergedPrSpecReader(production);
  f.seal=seal;f.spec=spec;
  return f;
}
let cases=0;
async function status(f,n,state='closed',r=repo){cases++;return (await f.reader.proveWorldIssues([row(n,state,r)],r,signal,f.fetcher))[0];}
assert.equal(supportsIssueProof(repo),true);assert.equal(supportsIssueProof('another/repo'),false);
// Accepted: merged PR with Closes, current seal with tests, required checks green.
{const f=fixture(),r=await status(f,7001);
 assert.equal(r.coverage,'t27');assert.equal(r.proof.commit,commit);assert.match(r.proof.specUrl,/blob\/e{40}\/specs\/port\/m\.t27$/);assert.match(r.proof.ciUrl,/\/pull\/900\/checks$/);
 // The minute cache and the per-PR record avoid repeated anonymous API reads.
 const before=f.apiReads;await status(f,7001);assert.equal(f.apiReads,before,'second view reads no API');}
// An old spec hash: the file changed after sealing.
{const f=fixture();f.files.set('specs/port/m.t27',f.spec+'// edited\n');assert.equal((await status(f,7001)).coverage,'unknown','stale seal');}
// Seal records zero tests, blocked tests, a failing test, partial pass, or another spec.
for(const [name,tests] of [['zero tests',{failed:0,passed:0,total:0}],['blocked',{blocked:'does not compile'}],['failing',{failed:1,passed:2,total:3}],['partial',{failed:0,passed:2,total:3}],['no tests field',undefined],['blocked with counts',{failed:0,passed:3,total:3,blocked:'does not compile'}],['failed marker with counts',{failed:1,passed:3,total:3}]]){
  const f=fixture();f.files.set('.trinity/seals/m.json',JSON.stringify({...f.seal,tests}));assert.equal((await status(f,7001)).coverage,'unknown',name);}
{const f=fixture();f.files.set('.trinity/seals/m.json',JSON.stringify({...f.seal,spec_path:'specs/port/other.t27'}));assert.equal((await status(f,7001)).coverage,'unknown','seal of another spec');}
// A required check not green, missing, or only queued.
for(const [name,runs] of [['failed',green().map((r,i)=>i?r:{...r,conclusion:'failure'})],['missing',green().slice(1)],['queued',green().map((r,i)=>i?r:{...r,status:'queued',conclusion:null})]]){
  const f=fixture({runs});assert.equal((await status(f,7001)).coverage,'unknown',`checks ${name}`);}
// A later green re-run of the same check outranks an earlier failure; an earlier green does not hide a later failure.
{const f=fixture({runs:[...green(),{id:99,name:production.REQUIRED_CHECKS[0],status:'completed',conclusion:'failure'}]});assert.equal((await status(f,7001)).coverage,'unknown','latest run wins');}
{const f=fixture({runs:[{id:1,name:production.REQUIRED_CHECKS[0],status:'completed',conclusion:'failure'},...green()]});assert.equal((await status(f,7001)).coverage,'t27','later re-run wins');}
// PR not merged, merged under another commit, or no closing line.
{const f=fixture({pull:{merged:false,merge_commit_sha:null,head:{sha:headSha},body:'Closes #7001'}});assert.equal((await status(f,7001)).coverage,'unknown','unmerged PR');}
{const f=fixture({pull:{merged:false,merge_commit_sha:mergeSha,head:{sha:headSha},body:'Closes #7001'}});assert.equal((await status(f,7001)).coverage,'unknown','unmerged PR with a merge-looking sha');}
{const f=fixture({pull:{merged:true,merge_commit_sha:mergeSha,head:{sha:headSha},body:'Closes #7002'}});assert.equal((await status(f,7002)).coverage,'unknown','compiler-only PR with a closing line still has no spec');}
{const f=fixture({pull:{merged:true,merge_commit_sha:'3'.repeat(40),head:{sha:headSha},body:'Closes #7001'}});assert.equal((await status(f,7001)).coverage,'unknown','index names another merge commit');}
for(const body of ['Refs #7001','Closes #70010','closes #7001x?','',null]){const f=fixture({pull:{merged:true,merge_commit_sha:mergeSha,head:{sha:headSha},body}});const r=await status(f,7001);assert.equal(r.coverage,body==='closes #7001x?'?'t27':'unknown',`body ${body}`);}
// A compiler-only PR (no spec) and an issue absent from the index stay unknown; other states and repos never inherit proof.
{const f=fixture();assert.equal((await status(f,7002)).coverage,'unknown','no spec');assert.equal((await status(f,7003)).coverage,'unknown','not in index');
 assert.equal((await status(f,7001,'open')).coverage,'unknown','reopened');}
{const f=fixture();await status(f,7001,'closed','another/repo');assert.equal(f.reads.length,0,'other repositories are never read');}
// A missing spec at head, a malformed index, an index of another repository, no head.
{const f=fixture();f.files.delete('specs/port/m.t27');assert.equal((await status(f,7001)).coverage,'unknown','spec deleted');}
{const f=fixture({index:{repo:'another/repo',issues:{7001:[{pr:900,sha:mergeSha,specs:[]}]}}});assert.equal((await status(f,7001)).coverage,'unknown','foreign index');}
{const f=fixture({index:{repo,issues:{7001:'nope'}}});assert.equal((await status(f,7001)).coverage,'unknown','malformed entry');}
{const f=fixture({index:{repo,issues:{7001:[{pr:900,sha:mergeSha,specs:[{path:'../x.t27',seal:'.trinity/seals/m.json'}]}]}}});assert.equal((await status(f,7001)).coverage,'unknown','path outside specs');}
{const f=fixture({index:{repo,issues:{7001:[{pr:900,sha:mergeSha,specs:[{path:'specs/port/m.t27',seal:'../seal.json'}]}]}}});assert.equal((await status(f,7001)).coverage,'unknown','seal path outside seals');}
{const f=fixture({headFail:true});assert.equal((await status(f,7001)).coverage,'unknown','head unreadable');}
// Rate limit: the row stays unknown, a cached positive is not reused after a failed refresh, and the next view recovers.
{const f=fixture({limited:true});assert.equal((await status(f,7001)).coverage,'unknown','API limited');f.limited=false;f.reader.invalidateIssueProof(repo);assert.equal((await status(f,7001)).coverage,'t27','recovers when the allowance returns');}
{const f=fixture(),ok=await status(f,7001);assert.equal(ok.coverage,'t27');f.reader.invalidateIssueProof(repo);f.limited=true;assert.equal((await f.reader.proveWorldIssues([ok],repo,signal,f.fetcher))[0].coverage,'unknown','failed refresh removes a positive');}
// The lookup budget: more PRs than allowed in one view leave the surplus unknown instead of exhausting the allowance.
{const issues={},files=new Map();
 const n=production.MAX_PR_LOOKUPS;
 for(let i=0;i<n;i++){issues[8000+i]=[{pr:1000+i,sha:mergeSha,specs:[{path:'specs/port/m.t27',seal:'.trinity/seals/m.json'}]}];}
 const f=fixture({index:{repo,issues}});f.pull.body=Array.from({length:n},(_,i)=>`Closes #${8000+i}`).join('\n');
 const rows=Array.from({length:n},(_,i)=>row(8000+i));cases+=n;
 const out=await f.reader.proveWorldIssues(rows,repo,signal,f.fetcher);
 const covered=out.filter(r=>r.coverage==='t27').length;
 assert.ok(covered>0&&covered<=n/2,`budget bounds covered rows (${covered})`);
 assert.ok(f.apiReads<=1+production.MAX_PR_LOOKUPS,`API reads stay within the budget (${f.apiReads})`);}
// Conformance of the acceptance table.
const matrix=JSON.parse(readFileSync(new URL('../conformance/queen_t27_issue_proof.json',import.meta.url)));
assert.equal(matrix.vectors.length,16);
for(const v of matrix.vectors)assert.equal(production.ACCEPT[v.mask],v.expected,`conformance mask ${v.mask}`);
console.log(`t27 issue proof reader: ${cases} cases and ${matrix.vectors.length} conformance vectors PASS`);
