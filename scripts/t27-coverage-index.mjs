#!/usr/bin/env node
// Builds the issue to PR to spec index the Queen reads for gHashTag/t27 (specs/queen/t27_issue_proof.t27).
// The index is a hint only: the browser reader re-reads every claim (merged PR, closing line,
// spec at head, seal hash and tests, required checks) from GitHub before it paints a cell.
// Usage: node scripts/t27-coverage-index.mjs --seals <checkout>/.trinity/seals --out issues.json
//          [--prev issues.json] [--author LOGIN ...] [--since ISO] [--repo gHashTag/t27]
import {readFileSync,readdirSync,writeFileSync,existsSync} from 'node:fs';
import {join} from 'node:path';

const args=process.argv.slice(2),opt=(k,d)=>{const i=args.indexOf(k);return i<0?d:args[i+1];};
const many=k=>args.flatMap((a,i)=>a===k?[args[i+1]]:[]);
const repo=opt('--repo','gHashTag/t27'),sealsDir=opt('--seals'),out=opt('--out'),prev=opt('--prev'),since=opt('--since');
const authors=new Set(many('--author'));
if(!sealsDir||!out)throw new Error('--seals and --out are required');
const token=process.env.GH_TOKEN||process.env.GITHUB_TOKEN||'';
const gh=async path=>{
  for(let attempt=0;;attempt++){
    const r=await fetch(`https://api.github.com/repos/${repo}${path}`,{headers:{Accept:'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28',...(token?{Authorization:`Bearer ${token}`}:{})}});
    if(r.ok)return r.json();
    if(attempt<3&&(r.status>=500||r.status===429||r.status===403))await new Promise(f=>setTimeout(f,2000*(attempt+1)));
    else throw new Error(`${path}: ${r.status}`);
  }
};
// Same keyword rule as the reader: a closing keyword directly before the issue number.
export const closes=body=>[...new Set([...(body??'').matchAll(/\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+#([1-9][0-9]*)(?![0-9])/gi)].map(m=>Number(m[1])))];

// spec path -> seal file, from the seals checked out at the head.
const sealOf=new Map();
for(const name of readdirSync(sealsDir).filter(n=>n.endsWith('.json'))){
  try{const d=JSON.parse(readFileSync(join(sealsDir,name),'utf8'));if(typeof d.spec_path==='string'&&!sealOf.has(d.spec_path))sealOf.set(d.spec_path,`.trinity/seals/${name}`);}catch{}
}
const index=prev&&existsSync(prev)?JSON.parse(readFileSync(prev,'utf8')):{repo,generated_at:null,watermark:null,issues:{}};
if(index.repo!==repo)throw new Error('previous index belongs to another repository');
const from=since??index.watermark??'1970-01-01T00:00:00Z';
let newest=from,seen=0;
for(let page=1;page<=100;page++){
  const prs=await gh(`/pulls?state=closed&sort=updated&direction=desc&per_page=100&page=${page}`);
  if(!prs.length)break;
  let older=true;
  for(const pr of prs){
    if(pr.updated_at>from)older=false; else continue;
    if(pr.updated_at>newest)newest=pr.updated_at;
    if(!pr.merged_at||!pr.merge_commit_sha)continue;
    if(authors.size&&!authors.has(pr.user?.login))continue;
    const issues=closes(pr.body);
    // Drop what this PR claimed before, so an edited description cannot leave a stale claim behind.
    for(const [n,list] of Object.entries(index.issues)){const kept=list.filter(e=>e.pr!==pr.number);if(kept.length)index.issues[n]=kept;else delete index.issues[n];}
    if(!issues.length)continue;
    const files=[];
    for(let fp=1;;fp++){const part=await gh(`/pulls/${pr.number}/files?per_page=100&page=${fp}`);files.push(...part);if(part.length<100)break;}
    const specs=files.filter(f=>f.filename.endsWith('.t27')&&f.status!=='removed').map(f=>({path:f.filename,seal:sealOf.get(f.filename)})).filter(s=>s.seal);
    // A spec of this PR without a seal is simply not listed: the PR then lists fewer specs than it touched
    // and the reader cannot prove it, so the issue stays unknown until the spec is sealed.
    const touched=files.filter(f=>f.filename.endsWith('.t27')&&f.status!=='removed').length;
    for(const n of issues)(index.issues[n]??=[]).push({pr:pr.number,sha:pr.merge_commit_sha,specs:touched===specs.length?specs:[]});
    seen++;
  }
  if(older)break;
}
index.watermark=newest;index.generated_at=new Date().toISOString();
index.issues=Object.fromEntries(Object.entries(index.issues).sort((a,b)=>Number(a[0])-Number(b[0])));
writeFileSync(out,JSON.stringify(index,null,1)+'\n');
console.log(`index: ${Object.keys(index.issues).length} issues; ${seen} PRs read since ${from}`);
