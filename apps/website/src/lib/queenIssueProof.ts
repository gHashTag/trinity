import {issueProofPolicy as policy} from './queenIssueProof.generated.ts';
import {memoryIssueProofPolicy} from './queenMemoryIssueProof.generated.ts';
import {t27IssueProofPolicy} from './queenT27IssueProof.generated.ts';
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
export type GroupedIssueProofPolicy={REPO:string;WORKFLOW:string;WORKFLOW_HASH:string;MAKEFILE:string;MAKEFILE_HASH:string;GLOBAL_PATHS:readonly string[];GLOBAL_HASHES:readonly string[];GROUP_NAMES:readonly string[];GROUP_SPEC:readonly string[];GROUP_SPEC_HASH:readonly string[];GROUP_SEAL:readonly string[];GROUP_SEAL_HASH:readonly string[];GROUP_VECTORS:readonly string[];GROUP_VECTORS_HASH:readonly string[];GROUP_VECTOR_COUNT:readonly number[];GROUP_EVIDENCE:readonly string[];GROUP_WORKFLOW:readonly string[];GROUP_PATHS:readonly string[];GROUP_PATH_HASHES:readonly string[];GROUP_PATH_OWNER:readonly number[];ISSUE_NUMBERS:readonly number[];ISSUE_GROUPS:readonly number[];CACHE_MS:number;ACCEPT:readonly number[]};
type GroupProof={specUrl:string;evidenceUrl?:string;ciUrl?:string};
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
async function verifyGroup(g:number,repo:string,commit:string,runs:unknown,signal:AbortSignal,fetcher:Fetcher):Promise<GroupProof|null>{
  try{
    // A group with its own workflow (the evidence replay) also needs that workflow green at this head.
    const own=policy.GROUP_WORKFLOW[g]?acceptedRun(runs,repo,commit,policy.GROUP_WORKFLOW[g]):null;
    if(policy.GROUP_WORKFLOW[g]&&!own)return null;
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
    return {specUrl:`https://github.com/${repo}/blob/${commit}/${spec}`,...(evidence?{evidenceUrl:`https://github.com/${repo}/blob/${commit}/${evidence}`}:{}),...(own?{ciUrl:own.html_url!}:{})};
  }catch{return null;}
}
async function verify(repo:string,signal:AbortSignal,fetcher:Fetcher):Promise<RepoProof>{
  const api=`https://api.github.com/repos/${repo}`;
  const head=await (await read(`${api}/commits/HEAD`,signal,fetcher)).json() as {sha?:string};
  const commit=head.sha;
  if(!commit||!/^[a-f0-9]{40}$/.test(commit))throw new Error('proof commit identity');
  const shared=[[policy.MAKEFILE,policy.MAKEFILE_HASH],[policy.WORKFLOW,policy.WORKFLOW_HASH],...policy.GLOBAL_PATHS.map((p,i)=>[p,policy.GLOBAL_HASHES[i]])];
  if(policy.GLOBAL_PATHS.length!==policy.GLOBAL_HASHES.length||policy.GROUP_PATHS.length!==policy.GROUP_PATH_HASHES.length||policy.GROUP_PATHS.length!==policy.GROUP_PATH_OWNER.length||policy.ISSUE_NUMBERS.length!==policy.ISSUE_GROUPS.length||policy.GROUP_WORKFLOW.length!==policy.GROUP_SPEC.length)throw new Error('incomplete proof policy');
  await Promise.all(shared.map(([path,hash])=>exact(repo,commit,path,hash,signal,fetcher)));
  const runs=await (await read(`${api}/actions/runs?head_sha=${commit}&event=push&per_page=100`,signal,fetcher)).json();
  const ci=acceptedRun(runs,repo,commit,policy.WORKFLOW);
  if(!ci)throw new Error('canonical required CI is not successful at current HEAD');
  const groups=await Promise.all(policy.GROUP_SPEC.map((_,g)=>verifyGroup(g,repo,commit,runs,signal,fetcher)));
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
    return {...row,coverage:'t27' as const,proof:{commit:proof!.commit,specUrl:found[0].specUrl,...(found.length>1?{specUrls:found.map(g=>g.specUrl)}:{}),ciUrl:found[0].ciUrl??proof!.ciUrl,...(evidenceUrl?{evidenceUrl}:{}),observedAt:proof!.observedAt}};
  });
}
return {supportsIssueProof,invalidateIssueProof,proveWorldIssues};
}
/**
 * t27 policy: a repository whose closed issues are delivered by merged PRs with
 * sealed specs. Nothing is pinned by hash: the rule is read against the live head
 * (see specs/queen/t27_issue_proof.t27). The issue to PR to spec index is a hint on
 * its own branch; every claim in it is re-read from GitHub. Anything unreadable,
 * rate limited or stale leaves the issue unknown, never green.
 */
export type MergedPrPolicy={REPO:string;INDEX_REPO:string;INDEX_REF:string;INDEX_PATH:string;REQUIRED_CHECKS:readonly string[];REQUIRED_CHECK_COUNT:number;MAX_PR_LOOKUPS:number;CACHE_MS:number;ACCEPT:readonly number[]};
type IndexSpec={path:string;seal:string};
type IndexPr={pr:number;sha:string;specs:IndexSpec[]};
type PrFacts={merged:boolean;mergeSha:string;headSha:string;body:string;checks:boolean};
type Snapshot={commit:string;index:Record<string,IndexPr[]>;observedAt:number;files:Map<string,Promise<ArrayBuffer|null>>;budget:{left:number}};
const closingLine=(body:string,n:number)=>new RegExp(`\\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\\s+#${n}(?![0-9])`,'i').test(body);
export function createMergedPrSpecReader(policy:MergedPrPolicy){
const cache=new Map<string,Snapshot>();
const generation=new Map<string,number>();
const flights=new Map<string,{ticket:number;controller:AbortController;snapshot:Promise<Snapshot|null>}>();
// A merged PR never changes: its facts are kept for the session, keyed by the merge commit the index names.
const prFacts=new Map<string,PrFacts>();
const advance=(repo:string)=>{const next=(generation.get(repo)??0)+1;generation.set(repo,next);return next;};
const supportsIssueProof=(repo:string)=>repo===policy.REPO;
function invalidateIssueProof(repo:string):void{advance(repo);cache.delete(repo);flights.get(repo)?.controller.abort();flights.delete(repo);}
const sha40=(v:unknown):v is string=>typeof v==='string'&&/^[a-f0-9]{40}$/.test(v);
async function snapshotOf(repo:string,signal:AbortSignal,fetcher:Fetcher):Promise<Snapshot>{
  const api=`https://api.github.com/repos/${repo}`;
  const head=await (await read(`${api}/commits/HEAD`,signal,fetcher)).json() as {sha?:string};
  if(!sha40(head.sha))throw new Error('proof commit identity');
  const raw=await (await read(`https://raw.githubusercontent.com/${policy.INDEX_REPO}/${policy.INDEX_REF}/${policy.INDEX_PATH}`,signal,fetcher)).json() as {repo?:string;issues?:Record<string,unknown>};
  if(raw.repo!==repo||typeof raw.issues!=='object'||!raw.issues)throw new Error('proof index identity');
  const index:Record<string,IndexPr[]>={};
  for(const [n,list] of Object.entries(raw.issues)){
    if(!/^[1-9][0-9]*$/.test(n)||!Array.isArray(list))continue;
    const entries:IndexPr[]=[];
    for(const e of list as Record<string,unknown>[]){
      const specs=Array.isArray(e?.specs)?(e.specs as Record<string,unknown>[]).filter(s=>typeof s?.path==='string'&&typeof s?.seal==='string').map(s=>({path:s.path as string,seal:s.seal as string})):[];
      if(Number.isSafeInteger(e?.pr)&&sha40(e?.sha))entries.push({pr:e.pr as number,sha:e.sha as string,specs});
    }
    if(entries.length)index[n]=entries;
  }
  return {commit:head.sha,index,observedAt:Date.now(),files:new Map(),budget:{left:policy.MAX_PR_LOOKUPS}};
}
async function snapshot(repo:string,signal:AbortSignal,fetcher:Fetcher):Promise<Snapshot|null>{
  const held=cache.get(repo);
  if(held&&Date.now()-held.observedAt<policy.CACHE_MS)return held;
  cache.delete(repo); // A failed refresh must not reuse an old positive verdict.
  let flight=flights.get(repo);
  if(!flight||flight.ticket!==generation.get(repo)){
    const ticket=advance(repo),controller=new AbortController();
    const found=snapshotOf(repo,controller.signal,fetcher).then(s=>{
      if(!publishesProof(true,generation.get(repo)===ticket,!controller.signal.aborted))return null;
      cache.set(repo,s);
      return s;
    }).finally(()=>{if(flights.get(repo)?.ticket===ticket)flights.delete(repo);});
    flight={ticket,controller,snapshot:found};
    flights.set(repo,flight);
  }
  const s=await flight.snapshot;
  return publishesProof(s!==null,generation.get(repo)===flight.ticket,!signal.aborted)?s:null;
}
const file=(s:Snapshot,repo:string,path:string,signal:AbortSignal,fetcher:Fetcher):Promise<ArrayBuffer|null>=>{
  let held=s.files.get(path);
  if(!held){held=read(`https://raw.githubusercontent.com/${repo}/${s.commit}/${path}`,signal,fetcher).then(r=>r.arrayBuffer()).catch(()=>null);s.files.set(path,held);}
  return held;
};
async function specSealed(s:Snapshot,repo:string,spec:IndexSpec,signal:AbortSignal,fetcher:Fetcher):Promise<boolean>{
  if(!/^specs\/.+\.t27$/.test(spec.path)||!/^\.trinity\/seals\/[^/]+\.json$/.test(spec.seal))return false;
  const [text,sealBytes]=await Promise.all([file(s,repo,spec.path,signal,fetcher),file(s,repo,spec.seal,signal,fetcher)]);
  if(!text||!sealBytes)return false;
  try{
    const seal=JSON.parse(new TextDecoder().decode(sealBytes)),t=seal.tests;
    return seal.spec_path===spec.path&&seal.spec_hash===`sha256:${await hex(text)}`&&!!t&&!t.blocked&&!t.failed&&Number.isSafeInteger(t.total)&&t.total>0&&t.passed===t.total;
  }catch{return false;}
}
async function facts(s:Snapshot,repo:string,entry:IndexPr,signal:AbortSignal,fetcher:Fetcher):Promise<PrFacts|null>{
  const key=`${entry.pr}:${entry.sha}`,held=prFacts.get(key);
  if(held)return held;
  if(s.budget.left<2)return null; // The anonymous API allowance is small; stay unknown rather than guess.
  s.budget.left-=2;
  const api=`https://api.github.com/repos/${repo}`;
  const pull=await (await read(`${api}/pulls/${entry.pr}`,signal,fetcher)).json() as {merged?:boolean;merge_commit_sha?:string;head?:{sha?:string};body?:string|null};
  if(pull.merged!==true||pull.merge_commit_sha!==entry.sha||!sha40(pull.head?.sha))return null;
  const runs=await (await read(`${api}/commits/${pull.head!.sha}/check-runs?per_page=100`,signal,fetcher)).json() as {check_runs?:{id?:number;name?:string;status?:string;conclusion?:string}[]};
  const all=Array.isArray(runs.check_runs)?runs.check_runs:[];
  const green=policy.REQUIRED_CHECKS.every(name=>{
    const latest=all.filter(r=>r?.name===name&&Number.isSafeInteger(r.id)).sort((a,b)=>b.id!-a.id!)[0];
    return latest?.status==='completed'&&latest.conclusion==='success';
  });
  const result={merged:true,mergeSha:entry.sha,headSha:pull.head!.sha!,body:typeof pull.body==='string'?pull.body:'',checks:green};
  prFacts.set(key,result); // Only a read that completed is kept; a failed read is retried on the next view.
  return result;
}
async function proveIssue(s:Snapshot,repo:string,n:number,signal:AbortSignal,fetcher:Fetcher):Promise<{mask:number;specUrls:string[];prUrl:string}|null>{
  const entries=s.index[String(n)];
  if(!entries)return null;
  let sealed=true,closed=true,green=true;
  const specUrls:string[]=[];
  for(const e of entries){
    if(!e.specs.length)sealed=false; // A PR without a spec proves nothing for this rule.
    for(const sp of e.specs){
      if(!await specSealed(s,repo,sp,signal,fetcher))sealed=false;
      else specUrls.push(`https://github.com/${repo}/blob/${s.commit}/${sp.path}`);
    }
  }
  if(!sealed)return {mask:0,specUrls:[],prUrl:''};
  for(const e of entries){
    let f:PrFacts|null=null;
    try{f=await facts(s,repo,e,signal,fetcher);}catch{f=null;}
    if(!f||!closingLine(f.body,n))closed=false;
    else if(!f.checks)green=false;
  }
  return {mask:2*Number(closed)+4*Number(sealed)+8*Number(green),specUrls:[...new Set(specUrls)],prUrl:`https://github.com/${repo}/pull/${entries[0].pr}`};
}
async function proveWorldIssues<T extends Row>(rows:T[],repo:string,signal:AbortSignal,fetcher:Fetcher=fetch):Promise<T[]>{
  rows=rows.map(row=>({...row,coverage:'unknown' as const,proof:undefined}));
  if(!supportsIssueProof(repo)||!rows.some(r=>r.repo===repo&&r.state==='closed'))return rows;
  let snap:Snapshot|null;
  try{snap=await snapshot(repo,signal,fetcher);}catch{return rows;}
  if(!snap||signal.aborted)return rows;
  const out:T[]=[];
  for(const row of rows){
    if(row.repo!==repo||row.state!=='closed'||!snap.index[String(row.number)]){out.push(row);continue;}
    let verdict:Awaited<ReturnType<typeof proveIssue>>=null;
    try{verdict=await proveIssue(snap,repo,row.number,signal,fetcher);}catch{verdict=null;}
    if(signal.aborted){return rows;}
    if(!verdict||policy.ACCEPT[1+verdict.mask]!==1){out.push(row);continue;}
    out.push({...row,coverage:'t27' as const,proof:{commit:snap.commit,specUrl:verdict.specUrls[0],...(verdict.specUrls.length>1?{specUrls:verdict.specUrls}:{}),ciUrl:`${verdict.prUrl}/checks`,observedAt:snap.observedAt}});
  }
  return out;
}
return {supportsIssueProof,invalidateIssueProof,proveWorldIssues};
}
const readers=[createIssueProofReader(policy),createGroupedIssueProofReader(memoryIssueProofPolicy),createMergedPrSpecReader(t27IssueProofPolicy as unknown as MergedPrPolicy)];
export function supportsIssueProof(repo:string){return readers.some(r=>r.supportsIssueProof(repo));}
export function invalidateIssueProof(repo:string){for(const reader of readers)reader.invalidateIssueProof(repo);}
export async function proveWorldIssues<T extends Row>(rows:T[],repo:string,signal:AbortSignal,fetcher:Fetcher=fetch):Promise<T[]>{
  const reader=readers.find(r=>r.supportsIssueProof(repo));
  return reader?reader.proveWorldIssues(rows,repo,signal,fetcher):rows.map(row=>({...row,coverage:'unknown' as const,proof:undefined}));
}
