import type { HiveDisplay } from './queenHiveDisplay';

export const PINNED_WORLDS = ['ghashtag/trios', 'ghashtag/t27'];
export const WORLD_STORAGE = 'queen.public-worlds.v1';
export const COLLAB_ORIGIN = 'https://t27-github-collab-production.up.railway.app';
export function parseWorldRepository(input: string): string | null {
  let value=input.trim();
  if(value.startsWith('https://')) {
    try { const u=new URL(value); if(u.hostname!=='github.com'||u.port||u.username||u.password||u.search||u.hash) return null; value=u.pathname.slice(1).replace(/\/$/,''); }
    catch { return null; }
  }
  value=value.replace(/\.git$/,'').toLowerCase();
  const parts=value.split('/');
  if(parts.length!==2||! /^[a-z0-9](?:[a-z0-9-]{0,37}[a-z0-9])?$/.test(parts[0])||! /^[a-z0-9_.-]{1,100}$/.test(parts[1])||['.','..'].includes(parts[1])) return null;
  return value;
}
export function savedWorlds(raw: string | null): string[] {
  try { const values:unknown=JSON.parse(raw??'[]'); return [...new Set([...PINNED_WORLDS,...(Array.isArray(values)?values.filter(v=>typeof v==='string').map(parseWorldRepository).filter((v):v is string=>v!==null):[])])].slice(0,20); }
  catch { return [...PINNED_WORLDS]; }
}
function object(value: unknown): Record<string,unknown> { return value!==null&&typeof value==='object'&&!Array.isArray(value)?value as Record<string,unknown>:{}; }
export type WorldIssue = HiveDisplay & { updatedAt:string|null; body?:string; assignees?:string[] };
export type WorldMetadata = { repo:string; description:string; issuesEnabled:boolean };
export function githubWorldMetadata(repo:string,raw:unknown):WorldMetadata {
  const value=object(raw);
  if(typeof value.full_name!=='string'||parseWorldRepository(value.full_name)!==repo) throw new Error('repository-mismatch');
  if(value.private!==false) throw new Error('public-only');
  return {repo,description:typeof value.description==='string'?value.description:'',issuesEnabled:value.has_issues===true};
}
export function githubWorldIssues(repo:string,raw:unknown):WorldIssue[] {
  if(!Array.isArray(raw)) throw new Error('invalid-response');
  const rows=new Map<number,WorldIssue>();
  for(const item of raw) {
    const v=object(item), n=v.number;
    if(v.pull_request!==undefined||!Number.isSafeInteger(n)||Number(n)<1||typeof v.title!=='string'||!['open','closed'].includes(String(v.state))) continue;
    const expected=`https://github.com/${repo}/issues/${n}`;
    if(typeof v.html_url!=='string'||v.html_url.toLowerCase()!==expected) continue;
    rows.set(Number(n),{key:`${repo}#${n}`,repo,number:Number(n),title:v.title,body:typeof v.body==='string'?v.body.slice(0,100_000):'',kind:object(v.type).name==='Epic'?'epic':'issue',state:v.state==='closed'&&v.state_reason==='not_planned'?'dropped':String(v.state),closedAt:typeof v.closed_at==='string'?v.closed_at:null,updatedAt:typeof v.updated_at==='string'?v.updated_at:null,children:[],coverage:'unknown'});
  }
  return [...rows.values()].sort((a,b)=>a.number-b.number);
}
export function mergeWorldIssues(previous:WorldIssue[],next:WorldIssue[]):WorldIssue[] {
  return [...new Map([...previous,...next].map(row=>[row.key,row])).values()].sort((a,b)=>a.number-b.number);
}
type Fetcher=typeof fetch;
async function githubRead(repo:string,suffix:string,signal:AbortSignal,fetcher:Fetcher=fetch) {
  if(parseWorldRepository(repo)!==repo) throw new Error('invalid-repository');
  const response=await fetcher(`https://api.github.com/repos/${repo}${suffix}`,{signal,credentials:'omit',headers:{Accept:'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28'}});
  if(!response.ok) throw new Error(response.status===403||response.status===429?'rate-limit':response.status===404?'not-found':`github-${response.status}`);
  return response;
}
export async function loadWorldMetadata(repo:string,signal:AbortSignal,fetcher:Fetcher=fetch) {
  return githubWorldMetadata(repo,await (await githubRead(repo,'',signal,fetcher)).json());
}
export async function loadWorldIssues(repo:string,page:number,signal:AbortSignal,fetcher:Fetcher=fetch) {
  if(!Number.isInteger(page)||page<1||page>100) throw new Error('invalid-page');
  const response=await githubRead(repo,`/issues?state=all&sort=created&direction=asc&per_page=100&page=${page}`,signal,fetcher);
  const raw:unknown=await response.json();
  const link=response.headers.get('link');
  return {rows:githubWorldIssues(repo,raw),hasMore:link?link.includes('rel="next"'):Array.isArray(raw)&&raw.length===100};
}
export async function loadWorldBacklog(repo:string,page:number,signal:AbortSignal,fetcher:Fetcher=fetch) {
  if(!Number.isInteger(page)||page<1||page>100)throw new Error('invalid-page');
  const response=await githubRead(repo,`/issues?state=open&sort=created&direction=asc&per_page=100&page=${page}`,signal,fetcher);
  const raw:unknown=await response.json(),link=response.headers.get('link');
  return {rows:githubWorldIssues(repo,raw).filter(r=>r.state==='open'),hasMore:link?link.includes('rel="next"'):Array.isArray(raw)&&raw.length===100};
}
export async function loadWorldIssue(repo:string,number:number,signal:AbortSignal,fetcher:Fetcher=fetch) {
  const row=await loadWorldIssueDetails(repo,number,signal,fetcher);
  return row.state==='open'?row:null;
}
/** Inspector preserves closed issues; backlog callers keep the open-only wrapper. */
export async function loadWorldIssueDetails(repo:string,number:number,signal:AbortSignal,fetcher:Fetcher=fetch) {
  if(!Number.isSafeInteger(number)||number<1)throw new Error('invalid-issue');
  const response=await githubRead(repo,`/issues/${number}`,signal,fetcher),raw:unknown=await response.json();
  const row=githubWorldIssues(repo,[raw]).find(i=>i.number===number);
  if(!row)throw new Error('issue-identity');
  const assignees=object(raw).assignees;
  row.assignees=Array.isArray(assignees)?assignees.flatMap(a=>{const login=object(a).login;return typeof login==='string'&&/^[a-z0-9-]+$/i.test(login)?[login]:[];}):[];
  return row;
}
