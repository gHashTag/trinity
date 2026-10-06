import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {createGroupedIssueProofReader,supportsIssueProof} from '../src/lib/queenIssueProof.ts';
import {memoryIssueProofPolicy as production} from '../src/lib/queenMemoryIssueProof.generated.ts';
import {hiveTaskPaint} from '../src/components/queenHiveDisplay.ts';

// Memory proof: one sealed spec per group, an issue is covered only when every
// group that names it verifies. Public HTTP boundary fixtures with real SHA-256.
const repo=production.REPO,commit='d'.repeat(40),signal=new AbortController().signal;
const hash=s=>createHash('sha256').update(s).digest('hex');
const G=production.GROUP_SPEC.length;
const issuesOf=g=>production.ISSUE_NUMBERS.filter((_,i)=>production.ISSUE_GROUPS[i]===g);
const groupsOf=n=>production.ISSUE_GROUPS.filter((_,i)=>production.ISSUE_NUMBERS[i]===n);
const extrasOf=g=>production.GROUP_PATHS.filter((_,i)=>production.GROUP_PATH_OWNER[i]===g);
const numbers=[...new Set(production.ISSUE_NUMBERS)];
function fixture(){
  const files=new Map(),groups=[];
  for(let g=0;g<G;g++){
    const spec=issuesOf(g).map(n=>`// Coverage: https://github.com/${repo}/issues/${n}`).join('\n');
    const seal={spec_path:production.GROUP_SPEC[g],spec_hash:`sha256:${hash(spec)}`,...Object.fromEntries(['c','zig','rust','verilog'].map(b=>[`gen_hash_${b}`,`sha256:${'a'.repeat(64)}`]))};
    const withHash=g%2===0; // formats and memory vectors carry no spec hash, evidence claims do
    const vectors={spec_path:production.GROUP_SPEC[g],...(withHash?{spec_hash:seal.spec_hash}:{}),vectors:[{expected:true}]};
    files.set(production.GROUP_SPEC[g],spec);files.set(production.GROUP_SEAL[g],JSON.stringify(seal));files.set(production.GROUP_VECTORS[g],JSON.stringify(vectors));
    for(const p of extrasOf(g))files.set(p,`pinned ${p}`);
    groups.push({spec,seal,vectors});
  }
  for(const p of [production.MAKEFILE,production.WORKFLOW,...production.GLOBAL_PATHS])files.set(p,`shared ${p}`);
  const policy={...production,
    MAKEFILE_HASH:hash(files.get(production.MAKEFILE)),WORKFLOW_HASH:hash(files.get(production.WORKFLOW)),
    GLOBAL_HASHES:production.GLOBAL_PATHS.map(p=>hash(files.get(p))),
    GROUP_SPEC_HASH:production.GROUP_SPEC.map(p=>hash(files.get(p))),GROUP_SEAL_HASH:production.GROUP_SEAL.map(p=>hash(files.get(p))),
    GROUP_VECTORS_HASH:production.GROUP_VECTORS.map(p=>hash(files.get(p))),GROUP_VECTOR_COUNT:production.GROUP_SPEC.map(()=>1),
    GROUP_PATH_HASHES:production.GROUP_PATHS.map(p=>hash(files.get(p)))};
  const run={id:77,head_sha:commit,event:'push',path:production.WORKFLOW,status:'completed',conclusion:'success',html_url:`https://github.com/${repo}/actions/runs/77`,repository:{full_name:repo}};
  const fetcher=async(url,options)=>{
    assert.equal(options.credentials,'omit');assert.equal(options.cache,'no-store');
    if(url.endsWith('/commits/HEAD'))return Response.json({sha:commit});
    if(url.includes('/actions/runs?'))return Response.json({workflow_runs:[run]});
    const prefix=`https://raw.githubusercontent.com/${repo}/${commit}/`;
    assert.ok(url.startsWith(prefix));const body=files.get(url.slice(prefix.length));
    return new Response(body??'missing',{status:body===undefined?404:200});
  };
  return {files,run,fetcher,reader:createGroupedIssueProofReader(policy),policy};
}
const row=(number,state='closed')=>({key:`${repo}#${number}`,repo,number,state,kind:'issue',title:`Issue ${number}`,closedAt:'2026-10-04T01:46:13Z',children:[],coverage:'unknown'});
let cases=0;
async function prove(f,list){return Object.fromEntries((await f.reader.proveWorldIssues(list.map(n=>typeof n==='number'?row(n):n),repo,signal,f.fetcher)).map(r=>[r.number,r]));}
function expectCovered(result,n,label){
  assert.equal(result[n].coverage,'t27',`${label}: #${n}`);assert.equal(hiveTaskPaint(result[n]).tone,'honey',`${label}: #${n}`);
  const need=groupsOf(n);
  assert.equal(result[n].proof.commit,commit);assert.equal(result[n].proof.gdsUrl,undefined,'no GDS claim');
  assert.equal(result[n].proof.specUrl,`https://github.com/${repo}/blob/${commit}/${production.GROUP_SPEC[need[0]]}`);
  assert.equal(result[n].proof.specUrls?.length??1,need.length,`${label}: one spec link per group #${n}`);
  const evidence=need.map(g=>production.GROUP_EVIDENCE[g]).find(Boolean);
  assert.equal(result[n].proof.evidenceUrl,evidence?`https://github.com/${repo}/blob/${commit}/${evidence}`:undefined);
}
function expectUnknown(result,n,label){assert.equal(result[n].coverage,'unknown',`${label}: #${n}`);assert.equal(result[n].proof,undefined);assert.notEqual(hiveTaskPaint(result[n]).tone,'honey',`${label}: #${n}`);}
async function check(label,mutate,affected){
  const f=fixture();mutate?.(f);
  const result=await prove(f,numbers);
  for(const n of numbers){if(affected.includes(n))expectUnknown(result,n,label);else expectCovered(result,n,label);cases++;}
}
assert.equal(supportsIssueProof(repo),true);
assert.equal(supportsIssueProof('another/repo'),false);
await check('complete proof covers every named issue',null,[]);
{
  const f=fixture(),result=await prove(f,[114,999]);
  expectUnknown(result,114,'an issue no group names');expectUnknown(result,999,'an issue no group names');cases+=2;
}
{
  const f=fixture(),result=await prove(f,[row(115,'open'),row(3,'open')]);
  expectUnknown(result,115,'reopened');expectUnknown(result,3,'reopened');cases+=2;
}
// A broken group leaves only the issues that need it unknown; the others keep their proof.
// A file pinned by several groups (the shared evidence tool) breaks each of them.
const ownersOf=path=>[...new Set([...production.GROUP_SPEC.map((_,g)=>g).filter(g=>[production.GROUP_SPEC[g],production.GROUP_SEAL[g],production.GROUP_VECTORS[g]].includes(path)),...production.GROUP_PATHS.map((p,i)=>p===path?production.GROUP_PATH_OWNER[i]:-1).filter(g=>g>=0)])];
for(const path of new Set([...production.GROUP_SPEC,...production.GROUP_SEAL,...production.GROUP_VECTORS,...production.GROUP_PATHS])){
  const owners=ownersOf(path),affected=numbers.filter(n=>groupsOf(n).some(g=>owners.includes(g)));
  await check(`changed ${path}`,f=>f.files.set(path,f.files.get(path)+' changed'),affected);
  await check(`missing ${path}`,f=>f.files.delete(path),affected);
}
for(let g=0;g<G;g++){
  const affected=numbers.filter(n=>groupsOf(n).includes(g));
  await check(`seal of ${production.GROUP_NAMES[g]} for another spec`,f=>{const s=JSON.parse(f.files.get(production.GROUP_SEAL[g]));s.spec_path='specs/other.t27';f.files.set(production.GROUP_SEAL[g],JSON.stringify(s));f.reader=createGroupedIssueProofReader({...f.policy,GROUP_SEAL_HASH:f.policy.GROUP_SEAL_HASH.map((h,i)=>i===g?hash(f.files.get(production.GROUP_SEAL[g])):h)});},affected);
  await check(`blocked seal tests of ${production.GROUP_NAMES[g]}`,f=>{const s=JSON.parse(f.files.get(production.GROUP_SEAL[g]));s.tests={blocked:'does not compile'};f.files.set(production.GROUP_SEAL[g],JSON.stringify(s));f.reader=createGroupedIssueProofReader({...f.policy,GROUP_SEAL_HASH:f.policy.GROUP_SEAL_HASH.map((h,i)=>i===g?hash(f.files.get(production.GROUP_SEAL[g])):h)});},affected);
  await check(`vector count of ${production.GROUP_NAMES[g]}`,f=>{f.reader=createGroupedIssueProofReader({...f.policy,GROUP_VECTOR_COUNT:f.policy.GROUP_VECTOR_COUNT.map((c,i)=>i===g?2:c)});},affected);
  const issue=issuesOf(g)[0];
  await check(`spec of ${production.GROUP_NAMES[g]} stops naming #${issue}`,f=>{const text=f.files.get(production.GROUP_SPEC[g]).replace(`issues/${issue}`,'issues/0');f.files.set(production.GROUP_SPEC[g],text);f.reader=createGroupedIssueProofReader({...f.policy,GROUP_SPEC_HASH:f.policy.GROUP_SPEC_HASH.map((h,i)=>i===g?hash(text):h),GROUP_SEAL_HASH:f.policy.GROUP_SEAL_HASH});},numbers.filter(n=>groupsOf(n).includes(g)));
}
// Shared files and the canonical run guard every group.
for(const path of [production.MAKEFILE,production.WORKFLOW,...production.GLOBAL_PATHS]){
  await check(`changed ${path}`,f=>f.files.set(path,f.files.get(path)+' changed'),numbers);
  await check(`missing ${path}`,f=>f.files.delete(path),numbers);
}
for(const change of [r=>r.head_sha='c'.repeat(40),r=>r.event='pull_request',r=>r.status='in_progress',r=>r.conclusion='failure',r=>r.path='unrelated.yml',r=>r.repository.full_name='another/fork'])await check('wrong canonical run',f=>change(f.run),numbers);
// A failed refresh cannot keep an old proof, and a superseded check cannot refill the cache (#1392).
{
  const f=fixture(),accepted=await prove(f,numbers);
  f.reader.invalidateIssueProof(repo);
  const missing=async()=>new Response('unavailable',{status:403});
  const after=await f.reader.proveWorldIssues(Object.values(accepted),repo,signal,missing);
  for(const r of after){assert.equal(r.coverage,'unknown','failed refresh cannot keep an old proof');cases++;}
}
{
  const g=fixture();let arrive,release;const arrived=new Promise(r=>arrive=r),gate=new Promise(r=>release=r);
  const missing=async()=>new Response('unavailable',{status:403});
  const slow=async(url,options)=>{if(url.includes('/actions/runs?')){arrive();await gate;}return g.fetcher(url,options);};
  const a=g.reader.proveWorldIssues([row(115)],repo,signal,slow);
  await arrived;g.reader.invalidateIssueProof(repo);
  assert.equal((await g.reader.proveWorldIssues([row(115)],repo,signal,missing))[0].coverage,'unknown');
  release();
  assert.equal((await a)[0].coverage,'unknown','superseded Memory check ends as unknown');
  assert.equal((await g.reader.proveWorldIssues([row(115)],repo,signal,missing))[0].coverage,'unknown','superseded Memory check did not refill the cache');
  cases+=2;
}
const matrix=JSON.parse(readFileSync(new URL('../conformance/queen_memory_issue_proof.json',import.meta.url)));
for(const v of matrix.vectors)assert.equal(production.ACCEPT[v.mask],v.expected);
assert.equal(matrix.vectors.length,16);
console.log(`Memory issue proof reader: ${G} groups, ${numbers.length} issues, ${cases} cases and ${matrix.vectors.length} conformance vectors PASS`);
