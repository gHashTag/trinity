import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {createIssueProofReader} from '../src/lib/queenIssueProof.ts';
import {issueProofPolicy as production} from '../src/lib/queenIssueProof.generated.ts';
import {hiveTaskPaint} from '../src/components/queenHiveDisplay.ts';

// Public HTTP boundary fixtures with real SHA-256, no network and no fake digest.
const hash=text=>createHash('sha256').update(text).digest('hex');
const sha='a'.repeat(40),signal=new AbortController().signal,repo=production.REPO;
const row=(overrides={})=>({key:`${repo}#1`,repo,number:1,title:'Phase A',kind:'issue',state:'closed',closedAt:'2026-10-03T13:05:56Z',children:[],coverage:'unknown',...overrides});
function fixture({source,seal:editSeal,vectors:editVectors}={}) {
  const spec=source??production.ISSUES.map(n=>`; https://github.com/${repo}/issues/${n}`).join('\n');
  const seal={spec_path:production.SPEC,spec_hash:`sha256:${hash(spec)}`,...Object.fromEntries(['c','rust','verilog','zig'].map(b=>[`gen_hash_${b}`,`sha256:${'b'.repeat(64)}`]))};
  const vectors={spec_path:production.SPEC,spec_hash:seal.spec_hash,vectors:[{expected:false},{expected:true}]};
  editSeal?.(seal);editVectors?.(vectors);
  const files=new Map([[production.SPEC,spec],[production.SEAL,JSON.stringify(seal)],[production.VECTORS,JSON.stringify(vectors)],[production.VERIFIER,'verifier fixture'],[production.WORKFLOW,'workflow fixture'],[production.MAKEFILE,'make fixture']]);
  const policy={...production,VECTOR_COUNT:2,...Object.fromEntries(['SPEC','SEAL','VECTORS','VERIFIER','WORKFLOW','MAKEFILE'].map(k=>[`${k}_HASH`,hash(files.get(production[k]))]))};
  const runs=[production.WORKFLOW,production.GDS_WORKFLOW].map((path,i)=>({id:i+1,head_sha:sha,event:'push',path,status:'completed',conclusion:'success',html_url:`https://github.com/${repo}/actions/runs/${i+1}`,repository:{full_name:repo}}));
  const reads=[];
  const fetcher=async(url,opts)=>{
    reads.push({url,opts});assert.equal(opts.credentials,'omit');assert.equal(opts.cache,'no-store');assert.equal(opts.headers.Authorization,undefined);
    if(url.endsWith('/commits/HEAD'))return Response.json({sha});
    if(url.includes('/actions/runs?'))return Response.json({workflow_runs:runs});
    const prefix=`https://raw.githubusercontent.com/${repo}/${sha}/`;
    assert.ok(url.startsWith(prefix),'all evidence is pinned to the resolved SHA');
    const bytes=files.get(url.slice(prefix.length));
    return new Response(bytes??'missing',{status:bytes===undefined?404:200});
  };
  return {files,runs,reads,fetcher,reader:createIssueProofReader(policy)};
}
let cases=0;
async function check(label,mutate,expected='unknown',options){
  const f=fixture(options);mutate?.(f);
  const result=(await f.reader.proveWorldIssues([row()],repo,signal,f.fetcher))[0];
  assert.equal(result.coverage,expected,label);
  assert.equal(Boolean(result.proof),expected==='t27',label);
  if(expected==='t27'){assert.equal(result.proof.commit,sha);assert.equal(hiveTaskPaint(result).tone,'honey');}
  else assert.notEqual(hiveTaskPaint(result).tone,'honey');
  cases++;
}
await check('complete canonical evidence',null,'t27');
for(const path of [production.SPEC,production.SEAL,production.VECTORS,production.VERIFIER,production.WORKFLOW,production.MAKEFILE]){
  await check(`tampered ${path}`,f=>f.files.set(path,f.files.get(path)+' changed'));
  await check(`missing ${path}`,f=>f.files.delete(path));
}
for(const edit of [r=>r.head_sha='c'.repeat(40),r=>r.event='pull_request',r=>r.repository.full_name='someone/fork',r=>r.status='in_progress',r=>r.conclusion='failure',r=>r.html_url='https://evil.test/fake',r=>r.path='some-other.yml'])await check('wrong CI identity/result',f=>edit(f.runs[0]));
await check('GDS failure',f=>f.runs[1].conclusion='failure');
await check('newest failed run supersedes older successful run',f=>f.runs.push({...f.runs[0],id:3,html_url:`https://github.com/${repo}/actions/runs/3`,conclusion:'failure'}));
await check('missing issue binding',null,'unknown',{source:`; https://github.com/${repo}/issues/123`});
await check('seal has stale source',null,'unknown',{seal:s=>s.spec_hash=`sha256:${'c'.repeat(64)}`});
await check('seal blocked tests',null,'unknown',{seal:s=>s.tests={blocked:'missing compiler'}});
await check('seal missing backend',null,'unknown',{seal:s=>delete s.gen_hash_rust});
await check('vectors missing cases',null,'unknown',{vectors:v=>v.vectors.pop()});
await check('vectors bound to another source',null,'unknown',{vectors:v=>v.spec_hash=`sha256:${'c'.repeat(64)}`});
await check('anonymous rate limit',f=>f.fetcher=async()=>new Response('rate limited',{status:403}));
await check('invalid head',f=>f.fetcher=async()=>Response.json({sha:'main'}));
const f=fixture();
const accepted=(await f.reader.proveWorldIssues([row()],repo,signal,f.fetcher))[0];
const before=f.reads.length;
await f.reader.proveWorldIssues([row()],repo,signal,f.fetcher);assert.equal(f.reads.length,before,'minute cache avoids repeated anonymous reads');
f.reader.invalidateIssueProof(repo);
const unavailable=async()=>new Response('limited',{status:429});
assert.equal((await f.reader.proveWorldIssues([accepted],repo,signal,unavailable))[0].coverage,'unknown','failed refresh removes a cached positive');
assert.equal((await f.reader.proveWorldIssues([{...accepted,state:'open'}],repo,signal,f.fetcher))[0].coverage,'unknown','reopening removes proof');
assert.equal((await f.reader.proveWorldIssues([row({number:99})],repo,signal,f.fetcher))[0].coverage,'unknown','other issues never inherit proof');
const unbound=fixture();await unbound.reader.proveWorldIssues([row({repo:'another/repo'})],'another/repo',signal,unbound.fetcher);assert.equal(unbound.reads.length,0);
cases+=5;
const matrix=JSON.parse(readFileSync(new URL('../conformance/queen_issue_proof.json',import.meta.url)));
assert.equal(matrix.vectors.length,16);
for(const v of matrix.vectors)assert.equal(production.ACCEPT[v.mask],v.expected,`conformance mask ${v.mask}`);
console.log(`Issue proof reader: ${cases} cases and ${matrix.vectors.length} conformance vectors PASS`);
