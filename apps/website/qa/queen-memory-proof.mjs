import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {createIssueProofReader,supportsIssueProof} from '../src/lib/queenIssueProof.ts';
import {memoryIssueProofPolicy as production} from '../src/lib/queenMemoryIssueProof.generated.ts';
import {hiveTaskPaint} from '../src/components/queenHiveDisplay.ts';

const repo=production.REPO,commit='d'.repeat(40),signal=new AbortController().signal;
const hash=s=>createHash('sha256').update(s).digest('hex');
function fixture(){
  const spec=production.ISSUES.map(n=>`; https://github.com/${repo}/issues/${n}`).join('\n');
  const seal={spec_path:production.SPEC,spec_hash:`sha256:${hash(spec)}`,...Object.fromEntries(['c','zig','rust','verilog'].map(b=>[`gen_hash_${b}`,`sha256:${'a'.repeat(64)}`]))};
  const matrix={spec_path:production.SPEC,spec_hash:seal.spec_hash,vectors:[{input:[true,true,true,4,8,4],expected:true}]};
  const files=new Map([[production.SPEC,spec],[production.SEAL,JSON.stringify(seal)],[production.VECTORS,JSON.stringify(matrix)],...['VERIFIER','WORKFLOW','MAKEFILE'].map(k=>[production[k],`${k} fixture`]),...production.EXTRA_PATHS.map(p=>[p,`retained evidence ${p}`])]);
  const policy={...production,VECTOR_COUNT:1,...Object.fromEntries(['SPEC','SEAL','VECTORS','VERIFIER','WORKFLOW','MAKEFILE'].map(k=>[`${k}_HASH`,hash(files.get(production[k]))])),EXTRA_HASHES:production.EXTRA_PATHS.map(p=>hash(files.get(p)))};
  const run={id:77,head_sha:commit,event:'push',path:production.WORKFLOW,status:'completed',conclusion:'success',html_url:`https://github.com/${repo}/actions/runs/77`,repository:{full_name:repo}};
  let calls=0;
  const fetcher=async(url,options)=>{
    calls++;assert.equal(options.credentials,'omit');assert.equal(options.cache,'no-store');
    if(url.endsWith('/commits/HEAD'))return Response.json({sha:commit});
    if(url.includes('/actions/runs?'))return Response.json({workflow_runs:[run]});
    const prefix=`https://raw.githubusercontent.com/${repo}/${commit}/`;
    assert.ok(url.startsWith(prefix));const body=files.get(url.slice(prefix.length));
    return new Response(body??'missing',{status:body===undefined?404:200});
  };
  return {files,run,fetcher,reader:createIssueProofReader(policy),calls:()=>calls};
}
const row=(number=115,state='closed')=>({key:`${repo}#${number}`,repo,number,state,kind:'issue',title:'Attention',closedAt:'2026-10-04T01:46:13Z',children:[],coverage:'unknown'});
let cases=0;
async function check(label,mutate,expected='unknown',issue=row()){
  const f=fixture();mutate?.(f);
  const result=(await f.reader.proveWorldIssues([issue],repo,signal,f.fetcher))[0];
  assert.equal(result.coverage,expected,label);assert.equal(Boolean(result.proof),expected==='t27',label);
  if(expected==='t27'){
    assert.equal(hiveTaskPaint(result).tone,'honey');
    assert.equal(result.proof.gdsUrl,undefined,'retained FPGA evidence is not GDS');
    assert.equal(result.proof.evidenceUrl,`https://github.com/${repo}/blob/${commit}/${production.EVIDENCE_PATH}`);
  }else assert.notEqual(hiveTaskPaint(result).tone,'honey',label);
  cases++;
}
assert.equal(supportsIssueProof(repo),true);
await check('complete retained attention proof',null,'t27');
await check('complete linked proof task',null,'t27',row(122));
await check('other issue cannot inherit attention proof',null,'unknown',row(114));
await check('reopened issue cannot inherit proof',null,'unknown',row(115,'open'));
for(const path of [production.SPEC,production.SEAL,production.VECTORS,production.VERIFIER,production.WORKFLOW,production.MAKEFILE,...production.EXTRA_PATHS]){
  await check(`changed ${path}`,f=>f.files.set(path,f.files.get(path)+' changed'));
  await check(`missing ${path}`,f=>f.files.delete(path));
}
for(const change of [r=>r.head_sha='c'.repeat(40),r=>r.event='pull_request',r=>r.status='in_progress',r=>r.conclusion='failure',r=>r.path='unrelated.yml',r=>r.repository.full_name='another/fork'])await check('wrong canonical run',f=>change(f.run));
const f=fixture(),accepted=(await f.reader.proveWorldIssues([row()],repo,signal,f.fetcher))[0];
f.reader.invalidateIssueProof(repo);
const missing=async()=>new Response('unavailable',{status:403});
assert.equal((await f.reader.proveWorldIssues([accepted],repo,signal,missing))[0].coverage,'unknown','failed refresh cannot keep an old proof');cases++;
{
  // #1392: a check that began before the reset cannot bring the old proof back.
  const g=fixture();let arrive,release;const arrived=new Promise(r=>arrive=r),gate=new Promise(r=>release=r);
  const slow=async(url,options)=>{if(url.includes('/actions/runs?')){arrive();await gate;}return g.fetcher(url,options);};
  const a=g.reader.proveWorldIssues([row()],repo,signal,slow);
  await arrived;g.reader.invalidateIssueProof(repo);
  assert.equal((await g.reader.proveWorldIssues([row()],repo,signal,missing))[0].coverage,'unknown');
  release();
  assert.equal((await a)[0].coverage,'unknown','superseded Memory check ends as unknown');
  assert.equal((await g.reader.proveWorldIssues([row()],repo,signal,missing))[0].coverage,'unknown','superseded Memory check did not refill the cache');
  cases+=2;
}
const matrix=JSON.parse(readFileSync(new URL('../conformance/queen_memory_issue_proof.json',import.meta.url)));
for(const v of matrix.vectors)assert.equal(production.ACCEPT[v.mask],v.expected);
assert.equal(matrix.vectors.length,16);
console.log(`Memory issue proof reader: ${cases} cases and ${matrix.vectors.length} conformance vectors PASS`);
