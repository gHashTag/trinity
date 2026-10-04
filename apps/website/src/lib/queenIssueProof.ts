import {issueProofPolicy as policy} from './queenIssueProof.generated.ts';

export type IssueProof = {commit:string;specUrl:string;ciUrl:string;gdsUrl:string;observedAt:number};
type Row = {repo:string;number:number;state:string;coverage:'unknown'|'t27';proof?:IssueProof};
type Fetcher=typeof fetch;
type Run = {id?:number;head_sha?:string;event?:string;path?:string;status?:string;conclusion?:string;html_url?:string;repository?:{full_name?:string}};
export type IssueProofPolicy={REPO:string;ISSUES:readonly number[];SPEC:string;SEAL:string;VECTORS:string;VERIFIER:string;MAKEFILE:string;WORKFLOW:string;GDS_WORKFLOW:string;SPEC_HASH:string;SEAL_HASH:string;VECTORS_HASH:string;VERIFIER_HASH:string;MAKEFILE_HASH:string;WORKFLOW_HASH:string;VECTOR_COUNT:number;CACHE_MS:number;ACCEPT:readonly number[]};
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
function supportsIssueProof(repo:string):boolean{return repo===policy.REPO;}
function invalidateIssueProof(repo:string):void{cache.delete(repo);}
async function repositoryProof(repo:string,signal:AbortSignal,fetcher:Fetcher):Promise<IssueProof>{
  const held=cache.get(repo);
  if(held&&Date.now()-held.observedAt<policy.CACHE_MS)return held;
  cache.delete(repo); // A failed refresh must not reuse an old positive verdict.
  const api=`https://api.github.com/repos/${repo}`;
  const head=await (await read(`${api}/commits/HEAD`,signal,fetcher)).json() as {sha?:string};
  const commit=head.sha;
  if(!commit||!/^[a-f0-9]{40}$/.test(commit))throw new Error('proof commit identity');
  const paths=[policy.SPEC,policy.SEAL,policy.VECTORS,policy.VERIFIER,policy.WORKFLOW,policy.MAKEFILE];
  const hashes=[policy.SPEC_HASH,policy.SEAL_HASH,policy.VECTORS_HASH,policy.VERIFIER_HASH,policy.WORKFLOW_HASH,policy.MAKEFILE_HASH];
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
  const ci=acceptedRun(runs,repo,commit,policy.WORKFLOW),gds=acceptedRun(runs,repo,commit,policy.GDS_WORKFLOW);
  if(!ci||!gds)throw new Error('canonical CI or GDS is not successful at current HEAD');
  const proof={commit,specUrl:`https://github.com/${repo}/blob/${commit}/${policy.SPEC}`,ciUrl:ci.html_url!,gdsUrl:gds.html_url!,observedAt:Date.now()};
  cache.set(repo,proof);
  return proof;
}

/** Supported exact evidence only; failures retain the observed GitHub lifecycle. */
async function proveWorldIssues<T extends Row>(rows:T[],repo:string,signal:AbortSignal,fetcher:Fetcher=fetch):Promise<T[]>{
  // Reopened/unsupported observations cannot retain a previous positive proof.
  rows=rows.map(row=>({...row,coverage:'unknown' as const,proof:undefined}));
  if(!supportsIssueProof(repo)||!rows.some(r=>r.repo===repo&&r.state==='closed'&&(policy.ISSUES as readonly number[]).includes(r.number)))return rows;
  let proof:IssueProof;
  try{proof=await repositoryProof(repo,signal,fetcher);}catch{return rows.map(r=>({...r,coverage:'unknown' as const,proof:undefined}));}
  if(signal.aborted)return rows;
  return rows.map(row=>{
    const mask=Number(row.state==='closed')+2*Number(row.repo===repo&&(policy.ISSUES as readonly number[]).includes(row.number))+4+8;
    return policy.ACCEPT[mask]===1?{...row,coverage:'t27' as const,proof}:row;
  });
}
return {supportsIssueProof,invalidateIssueProof,proveWorldIssues};
}
export const {supportsIssueProof,invalidateIssueProof,proveWorldIssues}=createIssueProofReader(policy);
