import {issueProofPolicy as policy} from './queenIssueProof.generated.ts';
import {memoryIssueProofPolicy} from './queenMemoryIssueProof.generated.ts';
import {issueProofRefreshPolicy as refresh} from './queenIssueProofRefresh.generated.ts';

export type IssueProof = {commit:string;specUrl:string;specUrls?:string[];ciUrl:string;gdsUrl?:string;evidenceUrl?:string;observedAt:number};
type Row = {repo:string;number:number;state:string;coverage:'unknown'|'t27';proof?:IssueProof};
type Fetcher=typeof fetch;
type Run = {id?:number;head_sha?:string;event?:string;path?:string;status?:string;conclusion?:string;html_url?:string;repository?:{full_name?:string}};
export type IssueProofPolicy={REPO:string;ISSUES:readonly number[];SPEC:string;SEAL:string;VECTORS:string;VERIFIER:string;MAKEFILE:string;WORKFLOW:string;GDS_WORKFLOW?:string;SPEC_HASH:string;SEAL_HASH:string;VECTORS_HASH:string;VERIFIER_HASH:string;MAKEFILE_HASH:string;WORKFLOW_HASH:string;GDS_WORKFLOW_HASH?:string;EXTRA_PATHS?:readonly string[];EXTRA_HASHES?:readonly string[];EVIDENCE_PATH?:string;VECTOR_COUNT:number;CACHE_MS:number;ACCEPT:readonly number[]};
/** specs/queen/issue_proof_refresh.t27 PUBLISH: verified, current generation, live caller. */
export function publishesProof(verified:boolean,current:boolean,live:boolean):boolean{
  return refresh.PUBLISH[Number(verified)+2*Number(current)+4*Number(live)]===1;
}
const hex=async(bytes:ArrayBuffer)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),x=>x.toString(16).padStart(2,'0')).join('');

async function read(url:string,signal:AbortSignal,fetcher:Fetcher):Promise<Response>{
  const response=await fetcher(url,{signal,credentials:'omit',cache:'no-store',headers:{Accept:'application/vnd.github+json'}});
  if(!response.ok)throw new Error(`proof read ${response.status}`);
  return response;
}
function acceptedRun(raw:unknown,repo:string,commit:string,path:string):Run|null{
  const runs=(raw as {workflow_runs?:Run[]})?.workflow_runs;
  if(!Array.isArray(runs))return null;
  const relevant=runs.filter(r=>r&&r.head_sha===commit&&r.event==='push'&&r.path===path&&r.repository?.full_name?.toLowerCase()===repo&&Number.isSafeInteger(r.id));
  const latest=relevant.sort((a,b)=>b.id!-a.id!)[0];
  if(latest?.status!=='completed'||latest.conclusion!=='success'||latest.html_url?.toLowerCase()!==`https://github.com/${repo}/actions/runs/${latest.id}`)return null;
  return latest;
}

/** Policy comes from the checked-in spec; never from a URL or API response. */
export function createIssueProofReader(policy:IssueProofPolicy){
const cache=new Map<string,IssueProof>();
// Deleting a cache entry does not stop a check already on its way to refill it.
// Every check carries the generation it began in; invalidate and each new check
// advance it, and only a check that is still current may publish (#1392).
const generation=new Map<string,number>();
const flights=new Map<string,{ticket:number;controller:AbortController;proof:Promise<IssueProof|null>}>();
const advance=(repo:string)=>{const next=(generation.get(repo)??0)+1;generation.set(repo,next);return next;};
function supportsIssueProof(repo:string):boolean{return repo===policy.REPO;}
function invalidateIssueProof(repo:string):void{advance(repo);cache.delete(repo);flights.get(repo)?.controller.abort();flights.delete(repo);}
async function repositoryProof(repo:string,signal:AbortSignal,fetcher:Fetcher):Promise<IssueProof|null>{
  const held=cache.get(repo);
  if(held&&Date.now()-held.observedAt<policy.CACHE_MS)return held;
  cache.delete(repo); // A failed refresh must not reuse an old positive verdict.
  let flight=flights.get(repo);
  if(!flight||flight.ticket!==generation.get(repo)){
    // Callers of one generation share its single check, so two views of one world agree.
    const ticket=advance(repo),controller=new AbortController();
    const proof=verify(repo,controller.signal,fetcher).then(found=>{
      if(!publishesProof(true,generation.get(repo)===ticket,!controller.signal.aborted))return null;
      cache.set(repo,found);
      return found;
    }).finally(()=>{if(flights.get(repo)?.ticket===ticket)flights.delete(repo);});
    flight={ticket,controller,proof};
    flights.set(repo,flight);
  }
  const found=await flight.proof;
  return publishesProof(found!==null,generation.get(repo)===flight.ticket,!signal.aborted)?found:null;
}
async function verify(repo:string,signal:AbortSignal,fetcher:Fetcher):Promise<IssueProof>{
  const api=`https://api.github.com/repos/${repo}`;
  const head=await (await read(`${api}/commits/HEAD`,signal,fetcher)).json() as {sha?:string};
  const commit=head.sha;
  if(!commit||!/^[a-f0-9]{40}$/.test(commit))throw new Error('proof commit identity');
  const paths=[policy.SPEC,policy.SEAL,policy.VECTORS,policy.VERIFIER,policy.WORKFLOW,policy.MAKEFILE];
  const hashes=[policy.SPEC_HASH,policy.SEAL_HASH,policy.VECTORS_HASH,policy.VERIFIER_HASH,policy.WORKFLOW_HASH,policy.MAKEFILE_HASH];
  if(policy.GDS_WORKFLOW){paths.push(policy.GDS_WORKFLOW);hashes.push(policy.GDS_WORKFLOW_HASH!);}
  paths.push(...(policy.EXTRA_PATHS??[]));hashes.push(...(policy.EXTRA_HASHES??[]));
  if(paths.length!==hashes.length)throw new Error('incomplete proof policy');
  const files=await Promise.all(paths.map(async(path,i)=>{
    const bytes=await (await read(`https://raw.githubusercontent.com/${repo}/${commit}/${path}`,signal,fetcher)).arrayBuffer();
    if(await hex(bytes)!==hashes[i])throw new Error(`proof hash mismatch: ${path}`);
    return new TextDecoder().decode(bytes);
  }));
  const seal=JSON.parse(files[1]),vectors=JSON.parse(files[2]);
  if(seal.spec_path!==policy.SPEC||seal.spec_hash!==`sha256:${policy.SPEC_HASH}`||seal.tests?.blocked||
     vectors.spec_path!==policy.SPEC||vectors.spec_hash!==seal.spec_hash||vectors.vectors?.length!==policy.VECTOR_COUNT||
     !['zig','rust','c','verilog'].every(b=>/^sha256:[a-f0-9]{64}$/.test(seal[`gen_hash_${b}`]??'')))throw new Error('incomplete native evidence');
  for(const n of policy.ISSUES)if(!new RegExp(`https://github.com/${repo}/issues/${n}(?![0-9])`,'i').test(files[0]))throw new Error('issue not bound to spec');
  const runs=await (await read(`${api}/actions/runs?head_sha=${commit}&event=push&per_page=100`,signal,fetcher)).json();
  const ci=acceptedRun(runs,repo,commit,policy.WORKFLOW),gds=policy.GDS_WORKFLOW?acceptedRun(runs,repo,commit,policy.GDS_WORKFLOW):null;
  if(!ci||(policy.GDS_WORKFLOW&&!gds))throw new Error('canonical required CI is not successful at current HEAD');
  const proof={commit,specUrl:`https://github.com/${repo}/blob/${commit}/${policy.SPEC}`,ciUrl:ci.html_url!,...(gds?{gdsUrl:gds.html_url!}:{}),...(policy.EVIDENCE_PATH?{evidenceUrl:`https://github.com/${repo}/blob/${commit}/${policy.EVIDENCE_PATH}`} : {}),observedAt:Date.now()};
  return proof;
}

/** Supported exact evidence only; failures retain the observed GitHub lifecycle. */
async function proveWorldIssues<T extends Row>(rows:T[],repo:string,signal:AbortSignal,fetcher:Fetcher=fetch):Promise<T[]>{
  // Reopened/unsupported observations cannot retain a previous positive proof.
  rows=rows.map(row=>({...row,coverage:'unknown' as const,proof:undefined}));
  if(!supportsIssueProof(repo)||!rows.some(r=>r.repo===repo&&r.state==='closed'&&(policy.ISSUES as readonly number[]).includes(r.number)))return rows;
  let proof:IssueProof|null;
  try{proof=await repositoryProof(repo,signal,fetcher);}catch{return rows;}
  if(!proof||signal.aborted)return rows;
  return rows.map(row=>{
    const mask=Number(row.state==='closed')+2*Number(row.repo===repo&&(policy.ISSUES as readonly number[]).includes(row.number))+4+8;
    return policy.ACCEPT[mask]===1?{...row,coverage:'t27' as const,proof}:row;
  });
}
return {supportsIssueProof,invalidateIssueProof,proveWorldIssues};
}

/**
 * Memory policy: one reader for a repository whose closed issues are delivered by
 * several sealed specs. Each group is a spec with its seal, vectors and pinned
 * files; an issue is covered only when every group that names it verifies, and a
 * failing group leaves only its own issues unknown. Shared files (Makefile,
 * workflow, gate script, compiler pin) and the canonical push CI guard them all.
 */
export type GroupedIssueProofPolicy={REPO:string;WORKFLOW:string;WORKFLOW_HASH:string;MAKEFILE:string;MAKEFILE_HASH:string;GLOBAL_PATHS:readonly string[];GLOBAL_HASHES:readonly string[];GROUP_NAMES:readonly string[];GROUP_SPEC:readonly string[];GROUP_SPEC_HASH:readonly string[];GROUP_SEAL:readonly string[];GROUP_SEAL_HASH:readonly string[];GROUP_VECTORS:readonly string[];GROUP_VECTORS_HASH:readonly string[];GROUP_VECTOR_COUNT:readonly number[];GROUP_EVIDENCE:readonly string[];GROUP_PATHS:readonly string[];GROUP_PATH_HASHES:readonly string[];GROUP_PATH_OWNER:readonly number[];ISSUE_NUMBERS:readonly number[];ISSUE_GROUPS:readonly number[];CACHE_MS:number;ACCEPT:readonly number[]};
type GroupProof={specUrl:string;evidenceUrl?:string};
type RepoProof={commit:string;ciUrl:string;observedAt:number;groups:(GroupProof|null)[]};
export function createGroupedIssueProofReader(policy:GroupedIssueProofPolicy){
const cache=new Map<string,RepoProof>();
const generation=new Map<string,number>();
const flights=new Map<string,{ticket:number;controller:AbortController;proof:Promise<RepoProof|null>}>();
const advance=(repo:string)=>{const next=(generation.get(repo)??0)+1;generation.set(repo,next);return next;};
const supportsIssueProof=(repo:string)=>repo===policy.REPO;
function invalidateIssueProof(repo:string):void{advance(repo);cache.delete(repo);flights.get(repo)?.controller.abort();flights.delete(repo);}
const exact=async(repo:string,commit:string,path:string,expected:string,signal:AbortSignal,fetcher:Fetcher):Promise<string>=>{
  const bytes=await (await read(`https://raw.githubusercontent.com/${repo}/${commit}/${path}`,signal,fetcher)).arrayBuffer();
  if(await hex(bytes)!==expected)throw new Error(`proof hash mismatch: ${path}`);
  return new TextDecoder().decode(bytes);
};
async function verifyGroup(g:number,repo:string,commit:string,signal:AbortSignal,fetcher:Fetcher):Promise<GroupProof|null>{
  try{
    const spec=policy.GROUP_SPEC[g],extras=policy.GROUP_PATHS.map((path,i)=>({path,hash:policy.GROUP_PATH_HASHES[i],owner:policy.GROUP_PATH_OWNER[i]})).filter(e=>e.owner===g);
    const [text,seal,vectors]=await Promise.all([
      exact(repo,commit,spec,policy.GROUP_SPEC_HASH[g],signal,fetcher),
      exact(repo,commit,policy.GROUP_SEAL[g],policy.GROUP_SEAL_HASH[g],signal,fetcher).then(JSON.parse),
      exact(repo,commit,policy.GROUP_VECTORS[g],policy.GROUP_VECTORS_HASH[g],signal,fetcher).then(JSON.parse),
      ...extras.map(e=>exact(repo,commit,e.path,e.hash,signal,fetcher)),
    ]);
    if(seal.spec_path!==spec||seal.spec_hash!==`sha256:${policy.GROUP_SPEC_HASH[g]}`||seal.tests?.blocked||
       vectors.spec_path!==spec||(vectors.spec_hash!==undefined&&vectors.spec_hash!==seal.spec_hash)||vectors.vectors?.length!==policy.GROUP_VECTOR_COUNT[g]||
       !['zig','rust','c','verilog'].every(b=>/^sha256:[a-f0-9]{64}$/.test(seal[`gen_hash_${b}`]??'')))return null;
    for(let i=0;i<policy.ISSUE_NUMBERS.length;i++)if(policy.ISSUE_GROUPS[i]===g&&!new RegExp(`https://github.com/${repo}/issues/${policy.ISSUE_NUMBERS[i]}(?![0-9])`,'i').test(text))return null;
    const evidence=policy.GROUP_EVIDENCE[g];
    return {specUrl:`https://github.com/${repo}/blob/${commit}/${spec}`,...(evidence?{evidenceUrl:`https://github.com/${repo}/blob/${commit}/${evidence}`}:{})};
  }catch{return null;}
}
async function verify(repo:string,signal:AbortSignal,fetcher:Fetcher):Promise<RepoProof>{
  const api=`https://api.github.com/repos/${repo}`;
  const head=await (await read(`${api}/commits/HEAD`,signal,fetcher)).json() as {sha?:string};
  const commit=head.sha;
  if(!commit||!/^[a-f0-9]{40}$/.test(commit))throw new Error('proof commit identity');
  const shared=[[policy.MAKEFILE,policy.MAKEFILE_HASH],[policy.WORKFLOW,policy.WORKFLOW_HASH],...policy.GLOBAL_PATHS.map((p,i)=>[p,policy.GLOBAL_HASHES[i]])];
  if(policy.GLOBAL_PATHS.length!==policy.GLOBAL_HASHES.length||policy.GROUP_PATHS.length!==policy.GROUP_PATH_HASHES.length||policy.GROUP_PATHS.length!==policy.GROUP_PATH_OWNER.length||policy.ISSUE_NUMBERS.length!==policy.ISSUE_GROUPS.length)throw new Error('incomplete proof policy');
  await Promise.all(shared.map(([path,hash])=>exact(repo,commit,path,hash,signal,fetcher)));
  const runs=await (await read(`${api}/actions/runs?head_sha=${commit}&event=push&per_page=100`,signal,fetcher)).json();
  const ci=acceptedRun(runs,repo,commit,policy.WORKFLOW);
  if(!ci)throw new Error('canonical required CI is not successful at current HEAD');
  const groups=await Promise.all(policy.GROUP_SPEC.map((_,g)=>verifyGroup(g,repo,commit,signal,fetcher)));
  return {commit,ciUrl:ci.html_url!,observedAt:Date.now(),groups};
}
async function repositoryProof(repo:string,signal:AbortSignal,fetcher:Fetcher):Promise<RepoProof|null>{
  const held=cache.get(repo);
  if(held&&Date.now()-held.observedAt<policy.CACHE_MS)return held;
  cache.delete(repo); // A failed refresh must not reuse an old positive verdict.
  let flight=flights.get(repo);
  if(!flight||flight.ticket!==generation.get(repo)){
    const ticket=advance(repo),controller=new AbortController();
    const proof=verify(repo,controller.signal,fetcher).then(found=>{
      if(!publishesProof(true,generation.get(repo)===ticket,!controller.signal.aborted))return null;
      cache.set(repo,found);
      return found;
    }).finally(()=>{if(flights.get(repo)?.ticket===ticket)flights.delete(repo);});
    flight={ticket,controller,proof};
    flights.set(repo,flight);
  }
  const found=await flight.proof;
  return publishesProof(found!==null,generation.get(repo)===flight.ticket,!signal.aborted)?found:null;
}
async function proveWorldIssues<T extends Row>(rows:T[],repo:string,signal:AbortSignal,fetcher:Fetcher=fetch):Promise<T[]>{
  rows=rows.map(row=>({...row,coverage:'unknown' as const,proof:undefined}));
  const named=(n:number)=>policy.ISSUE_NUMBERS.includes(n);
  if(!supportsIssueProof(repo)||!rows.some(r=>r.repo===repo&&r.state==='closed'&&named(r.number)))return rows;
  let proof:RepoProof|null;
  try{proof=await repositoryProof(repo,signal,fetcher);}catch{return rows;}
  if(!proof||signal.aborted)return rows;
  return rows.map(row=>{
    if(row.repo!==repo||!named(row.number))return row;
    const needed=policy.ISSUE_GROUPS.filter((_,i)=>policy.ISSUE_NUMBERS[i]===row.number).map(g=>proof!.groups[g]);
    if(!needed.length||needed.some(g=>!g))return row;
    const mask=Number(row.state==='closed')+2+4+8;
    if(policy.ACCEPT[mask]!==1)return row;
    const found=needed as GroupProof[],evidenceUrl=found.find(g=>g.evidenceUrl)?.evidenceUrl;
    return {...row,coverage:'t27' as const,proof:{commit:proof!.commit,specUrl:found[0].specUrl,...(found.length>1?{specUrls:found.map(g=>g.specUrl)}:{}),ciUrl:proof!.ciUrl,...(evidenceUrl?{evidenceUrl}:{}),observedAt:proof!.observedAt}};
  });
}
return {supportsIssueProof,invalidateIssueProof,proveWorldIssues};
}
const readers=[createIssueProofReader(policy),createGroupedIssueProofReader(memoryIssueProofPolicy)];
export function supportsIssueProof(repo:string){return readers.some(r=>r.supportsIssueProof(repo));}
export function invalidateIssueProof(repo:string){for(const reader of readers)reader.invalidateIssueProof(repo);}
export async function proveWorldIssues<T extends Row>(rows:T[],repo:string,signal:AbortSignal,fetcher:Fetcher=fetch):Promise<T[]>{
  const reader=readers.find(r=>r.supportsIssueProof(repo));
  return reader?reader.proveWorldIssues(rows,repo,signal,fetcher):rows.map(row=>({...row,coverage:'unknown' as const,proof:undefined}));
}
