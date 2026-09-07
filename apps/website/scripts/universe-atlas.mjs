#!/usr/bin/env node
// Public reads only. No credentials, issue bodies or private repositories in the UI artifact.
import {readFileSync,writeFileSync,renameSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import {matchIssue} from '../src/lib/sharedSpecCore.ts';
import {discoverWorlds,buildAtlas,keyWorldAtlas} from '../src/lib/queenUniverseAtlas.ts';
const site=resolve(dirname(fileURLToPath(import.meta.url)),'..'),args=process.argv.slice(2),command=args.shift();
const arg=k=>{const i=args.indexOf(k);return i<0?undefined:args[i+1];};
const gh=args=>JSON.parse(execFileSync('gh',args,{encoding:'utf8',timeout:60000,maxBuffer:60*1024*1024}));
const core=JSON.parse(readFileSync(resolve(site,'public/t27/shared-core.json')));
function emit(data){const out=arg('--out');if(!out)throw new Error('--out /absolute/NEW-report.json is required');writeFileSync(resolve(out),JSON.stringify(data,null,2)+'\n',{flag:'wx'});}
try{
  if(command==='scan'){
    const owner=arg('--owner')??'gHashTag',limit=Number(arg('--limit')??2000);
    if(!/^[A-Za-z0-9][A-Za-z0-9-]{0,38}$/.test(owner)||!Number.isInteger(limit)||limit<1||limit>10000||!arg('--out'))throw new Error('Valid --owner, --limit 1..10000 and new --out required');
    const pages=gh(['api',`users/${owner}/repos?per_page=100&type=owner&sort=full_name`,'--paginate','--slurp']);
    const inventory=pages.flat().filter(r=>r.private===false),readmes=[],readmeFailures=[],attempted=new Set();
    let worlds=discoverWorlds(inventory,core,readmes);
    for(let round=0;round<4;round++){
      const pending=worlds.filter(w=>!attempted.has(w.repo));if(!pending.length)break;
      for(const {repo} of pending){attempted.add(repo);try{const r=gh(['api',`repos/${repo}/readme`]);readmes.push({repo,url:r.html_url,text:Buffer.from(r.content,'base64').toString('utf8')});}catch{readmeFailures.push(repo);}}
      worlds=discoverWorlds(inventory,core,readmes);
    }
    const snapshots=[],analyses=[];
    const discovery={owner,inventory:inventory.length,inventoryPages:pages.length,inventoryComplete:true,readmeFailures,unexpandedWorlds:worlds.filter(w=>!attempted.has(w.repo)).map(w=>w.repo),scope:'Public owner inventory: explicit project descriptions/namespaces, related README outbound links (four expansion rounds), explicit seeds and vendored catalog sources. Not all GitHub; no private repos, enrolled players or presence.',strandClassification:'INFERENCE from repository name/description; navigation taxonomy only',readmes:readmes.map(({repo,url})=>({repo,url}))};
    for(const world of worlds){
      const observedAt=new Date().toISOString();
      let total=null,loaded=0,complete=false,error=null;
      try{
        const metadata=gh(['repo','view',world.repo,'--json','isPrivate,nameWithOwner,issues']);
        if(metadata.isPrivate!==false||metadata.nameWithOwner.toLowerCase()!==world.repo)throw new Error('identity');
        total=metadata.issues.totalCount;
        const rows=world.issuesEnabled?gh(['issue','list','--repo',world.repo,'--state','open','--limit',String(limit),'--json','number,title,body,state,url']):[];
        const local=[];
        for(const r of rows){if(r.url?.toLowerCase()!==`https://github.com/${world.repo}/issues/${r.number}`||r.state!=='OPEN')throw new Error('identity');const issue={repo:world.repo,number:r.number,title:r.title,body:r.body,state:r.state};local.push({issue,hits:matchIssue(core,issue)});}
        analyses.push(...local);loaded=local.length;complete=loaded===total;
      }catch{error='GitHub read failed or identity changed';total=null;}
      snapshots.push({repo:world.repo,total,loaded,complete,error,observedAt});
      console.error(`${world.repo}: ${error?'UNKNOWN':`${loaded}/${total}${complete?' complete':' PARTIAL'}`}`);
    }
    const report={version:1,at:new Date().toISOString(),provenance:core.provenance,discovery,worlds,snapshots,analyses};
    buildAtlas(core,report);emit(report);
    console.log(JSON.stringify({worlds:worlds.length,issues:analyses.length,completeWorlds:snapshots.filter(s=>s.complete).length,unknownWorlds:snapshots.filter(s=>s.error).length}));
  }else if(command==='build'){
    if(!arg('--report'))throw new Error('--report required');
    const report=JSON.parse(readFileSync(resolve(arg('--report')))),atlas=keyWorldAtlas(buildAtlas(core,report)),dest=resolve(site,'public/t27/universe-atlas.json'),temp=`${dest}.${process.pid}.tmp`;
    writeFileSync(temp,JSON.stringify(atlas)+'\n',{flag:'wx'});renameSync(temp,dest);
    console.log(JSON.stringify({worlds:atlas.worlds.length,owners:atlas.owners.length,players:atlas.players,issues:atlas.issues.length,sharedOpportunities:atlas.opportunities.length}));
  }else console.log('Universe atlas (public discovery, never acceptance)\n  npm run atlas -- scan --owner gHashTag --limit 2000 --out /absolute/NEW.json\n  npm run atlas -- build --report /absolute/report.json\nReports never overwritten. Build only updates a derived local artifact. No deployment.');
}catch(e){console.error(`universe-atlas: ${e.message}`);process.exitCode=1;}
