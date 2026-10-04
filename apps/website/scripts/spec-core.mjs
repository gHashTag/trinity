#!/usr/bin/env node
// Read-only source discovery. Only index writes the derived public artifact;
// --out creates a NEW report and refuses to overwrite previous evidence.
import {readFileSync,writeFileSync,renameSync,realpathSync} from 'node:fs';
import {resolve,dirname,sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import ts from 'typescript';
// Publisher uses Node 20: erase types from the same pure engine, without
// maintaining a duplicate JavaScript implementation or requiring a newer runtime.
const engineSource=readFileSync(new URL('../src/lib/sharedSpecCore.ts',import.meta.url),'utf8');
const engine=ts.transpileModule(engineSource,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const {buildCore,matchIssue,coreImpact,agentPacket,validCoreRepo}=await import(`data:text/javascript;base64,${Buffer.from(engine).toString('base64')}`);
const site=resolve(dirname(fileURLToPath(import.meta.url)),'..'),args=process.argv.slice(2),command=args.shift()??'help';
const hash=b=>createHash('sha256').update(b).digest('hex');
const value=key=>{const i=args.indexOf(key);return i<0?undefined:args[i+1];};
const output=value('--out');
function emit(data){const text=typeof data==='string'?data:JSON.stringify(data,null,2);if(output)writeFileSync(resolve(output),text+'\n',{flag:'wx'});else process.stdout.write(text+'\n');}
function gh(params){return JSON.parse(execFileSync('gh',params,{encoding:'utf8',maxBuffer:30*1024*1024,timeout:120000}));}
function index(){
  const bytes=readFileSync(resolve(site,'public/t27/manifest.json')),manifest=JSON.parse(bytes),root=realpathSync(resolve(site,'public/t27/files'));
  const inputs=manifest.specs.map(s=>{const path=realpathSync(resolve(root,s.path));if(!path.startsWith(root+sep))throw new Error('Source escapes corpus');const bytes=readFileSync(path);return {...s,text:bytes.toString('utf8'),hash:hash(bytes)};});
  const core=buildCore(inputs,{...manifest.generatedFrom,dirty:manifest.generatedFrom.specsOrCompilerDirty,manifestSha256:hash(bytes),indexerSha256:hash(readFileSync(resolve(site,'src/lib/sharedSpecCore.ts'))),repos:manifest.repos,duplicatesPreviouslySkipped:manifest.duplicatesSkipped,healthSource:'vendored manifest claim, not issue acceptance',importResolution:'lexical/path discovery, not compiler linking'});
  const dest=resolve(site,'public/t27/shared-core.json'),temp=`${dest}.${process.pid}.tmp`;
  writeFileSync(temp,JSON.stringify(core)+'\n',{flag:'wx'});renameSync(temp,dest);
  return {specs:core.specs.length,aliases:core.specs.reduce((n,s)=>n+s.sources.length,0),collisions:core.collisions.length,imports:core.dependencies.length,resolved:core.dependencies.filter(d=>d.to).length,ambiguous:core.dependencies.filter(d=>d.status==='ambiguous').length,missing:core.dependencies.filter(d=>d.status==='missing').length,manifestSha256:core.provenance.manifestSha256};
}
try {
  if(command==='index')emit(index());
  else if(command==='scan'||command==='rescore'){
    const core=JSON.parse(readFileSync(resolve(site,'public/t27/shared-core.json'))),repos=args.flatMap((arg,i)=>arg==='--repo'?[args[i+1]?.toLowerCase()]:[]);
    if(command==='scan'&&(!repos.length||repos.some(repo=>!repo||!validCoreRepo(repo))))throw new Error('Use --repo owner/repo (repeat for each public world)');
    const limit=Number(value('--limit')??500);if(!Number.isInteger(limit)||limit<1||limit>1000)throw new Error('limit must be 1..1000');
    const snapshots=[],analyses=[];
    let observedAt=null;
    if(command==='rescore'){
      if(!value('--report'))throw new Error('--report required');const prior=JSON.parse(readFileSync(resolve(value('--report'))));
      if(prior.provenance.manifestSha256!==core.provenance.manifestSha256)throw new Error('Corpus changed; scan again');
      observedAt=prior.observedAt??prior.at;
      snapshots.push(...prior.snapshots);for(const a of prior.analyses)analyses.push({issue:a.issue,hits:matchIssue(core,a.issue)});
    }
    for(const repo of [...new Set(repos)]){
      const meta=gh(['repo','view',repo,'--json','nameWithOwner,isPrivate']);
      if(meta.isPrivate!==false||meta.nameWithOwner.toLowerCase()!==repo)throw new Error('Only exact public repositories may enter this report');
      const rows=gh(['issue','list','--repo',repo,'--state','open','--limit',String(limit),'--json','number,title,body,state,url']);
      snapshots.push({repo,loaded:rows.length,limit,complete:rows.length<limit,source:'GitHub open issues'});
      for(const row of rows){if(row.url?.toLowerCase()!==`https://github.com/${repo}/issues/${row.number}`)throw new Error('Issue identity mismatch');const issue={repo,number:row.number,title:row.title,body:row.body,state:row.state};analyses.push({issue,hits:matchIssue(core,issue)});}
    }
    const ranked=core.specs.map(spec=>{const impact=coreImpact(core,spec.id,analyses);return {specId:spec.id,sources:spec.sources,issues:impact.issues,dependentSpecs:impact.specIds.length-1};}).filter(r=>r.issues.length).sort((a,b)=>b.issues.length-a.issues.length||a.specId.localeCompare(b.specId));
    const at=new Date().toISOString();
    emit({version:1,at,observedAt:observedAt??at,provenance:core.provenance,snapshots,coverage:'UNVERIFIED discovery only',summary:{issues:analyses.length,withCandidates:analyses.filter(a=>a.hits.length).length,withoutCandidates:analyses.filter(a=>!a.hits.length).length,verifiedCoverage:0},sharedOpportunities:ranked.slice(0,30),analyses});
  }else if(command==='impact'||command==='packet'){
    const report=value('--report');if(!report)throw new Error('--report is required');
    const core=JSON.parse(readFileSync(resolve(site,'public/t27/shared-core.json'))),data=JSON.parse(readFileSync(resolve(report)));
    if(data.provenance.manifestSha256!==core.provenance.manifestSha256||data.provenance.indexerSha256!==core.provenance.indexerSha256)throw new Error('Report/catalog mismatch; scan or rescore again');
    if(command==='impact'){const id=value('--spec');if(!core.specs.some(s=>s.id===id))throw new Error('Unknown --spec SHA256');emit(coreImpact(core,id,data.analyses));}
    else {const id=value('--issue'),entry=data.analyses.find(a=>`${a.issue.repo}#${a.issue.number}`===id);if(!entry)throw new Error('Unknown --issue owner/repo#number');emit(agentPacket(core,entry.issue,entry.hits));}
  }else if(command==='help')emit('Shared spec core (discovery, not acceptance)\n  npm run core -- index\n  npm run core -- scan --repo ghashtag/t27 --repo ghashtag/trios --limit 500 --out /absolute/new-report.json\n  npm run core -- impact --report /absolute/report.json --spec SHA256\n  npm run core -- packet --report /absolute/report.json --issue ghashtag/t27#123\nNo source rewrite, GitHub writes, secrets or worker dispatch.');
  else throw new Error('Unknown command; use help');
}catch(error){console.error(`spec-core: ${error.message}`);process.exitCode=1;}
