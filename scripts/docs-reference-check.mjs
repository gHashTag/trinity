import {readFileSync,existsSync,statSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve,dirname,relative,extname,posix} from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import {fromMarkdown} from '../docs/node_modules/mdast-util-from-markdown/index.js';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
export const policy=JSON.parse(readFileSync(resolve(root,'scripts/docs-gate.generated.json')));
export function httpClass(status){
    const index=policy.HTTP_STATUS.indexOf(status);
    if(index>=0)return policy.HTTP_CLASS[index];
    return status>=policy.HTTP_VERIFIED_MIN&&status<=policy.HTTP_VERIFIED_MAX?policy.VERIFIED:policy.UNKNOWN;
}
export function markdownReferences(text){
    const ast=fromMarkdown(text),definitions=new Map(),references=[];
    function walk(node,visitor){visitor(node);for(const child of node.children??[])walk(child,visitor);}
    walk(ast,node=>{if(node.type==='definition')definitions.set(node.identifier.toLowerCase(),node.url);});
    walk(ast,node=>{
        let url;
        if(node.type==='link'||node.type==='image')url=node.url;
        else if(node.type==='linkReference'||node.type==='imageReference')url=definitions.get(node.identifier.toLowerCase());
        if(url!==undefined)references.push({url,line:node.position?.start.line??1});
        if(node.type==='html')for(const match of node.value.matchAll(/\b(?:href|src)\s*=\s*["']([^"']+)["']/gi))references.push({url:match[1],line:node.position?.start.line??1});
    });
    return references;
}
function within(base,path){const rel=relative(base,path);return rel===''||(!rel.startsWith('..')&&!rel.startsWith('/'));}
function targetExists(path){return existsSync(path)&&(statSync(path).isFile()||statSync(path).isDirectory());}
export function routeCatalog(base=root){
    const file=resolve(base,'docs/.docusaurus/routes.js');
    if(!existsSync(file))throw new Error('Build docsite first: generated Docusaurus routes missing');
    return new Set([...readFileSync(file,'utf8').matchAll(/\bpath:\s*'([^']+)'/g)].map(m=>m[1].replace(/\/$/,'')||'/'));
}
function builtRoute(path,base,routes){
    const full=(path.startsWith(policy.DOCS_BASE)?path:policy.DOCS_BASE+path.replace(/^\//,'')).replace(/\/$/,'');
    if(!routes.has(full))return null;
    const suffix=full.slice(policy.DOCS_BASE.length-1).replace(/^\//,'');
    const built=resolve(base,policy.DOCS_BUILD_ROOT,suffix,'index.html');
    return within(resolve(base,policy.DOCS_BUILD_ROOT),built)&&targetExists(built)?relative(base,built):null;
}
export function resolveReference(file,url,{base=root,routes=routeCatalog(base)}={}){
    const result=(classification,reason,target)=>({classification,reason,...(target?{target}:{})});
    if(!url||url.startsWith('#'))return result(policy.UNKNOWN,'fragment only; anchor not measured');
    if(/^(?:mailto|tel):/i.test(url))return result(policy.UNKNOWN,'non-HTTP example; delivery not measured');
    if(/^https?:\/\//i.test(url)||url.startsWith('//')){
        let parsed;try{parsed=new URL(url.startsWith('//')?'https:'+url:url);}catch{return result(policy.BROKEN,'malformed URL');}
        if(parsed.username||parsed.password)return result(policy.BROKEN,'credentials are forbidden in documentation URLs');
        if(parsed.hostname==='localhost'||/^(?:127\.|0\.|10\.|192\.168\.|172\.(?:1[6-9]|2\d|3[01])\.)/.test(parsed.hostname)||/^\[(?:::1|fc|fd|fe80:)/i.test(parsed.hostname)||parsed.hostname.endsWith('.local'))return result(policy.UNKNOWN,'local/private endpoint example; not probed');
        return {classification:policy.UNKNOWN,reason:'external URL not yet probed',external:parsed.href};
    }
    if(/^[a-z][a-z\d+.-]*:/i.test(url))return result(policy.UNKNOWN,'non-HTTP protocol; not measured');
    let path;try{path=decodeURIComponent(url.split(/[?#]/,1)[0]);}catch{return result(policy.BROKEN,'malformed URL encoding');}
    const physical=path.startsWith('/')?resolve(base,'.'+path):resolve(base,dirname(file),path);
    if(!within(base,physical))return result(policy.BROKEN,'path escapes repository');
    if(targetExists(physical))return result(policy.VERIFIED,'source target exists',relative(base,physical));
    if(path.startsWith('/')){
        const route=builtRoute(path,base,routes);
        if(route)return result(policy.VERIFIED,'built docsite route exists',route);
        const asset=resolve(base,policy.DOCS_STATIC_ROOT,'.'+path);
        if(within(resolve(base,policy.DOCS_STATIC_ROOT),asset)&&targetExists(asset))return result(policy.VERIFIED,'docsite static asset exists',relative(base,asset));
    }else if(file.startsWith(policy.DOCS_CONTENT_ROOT+'/')){
        for(const suffix of ['.md','.mdx','/index.md','/README.md'])if(targetExists(physical+suffix))return result(policy.VERIFIED,'docsite source target exists',relative(base,physical+suffix));
        const from=posix.dirname(file.slice(policy.DOCS_CONTENT_ROOT.length));
        const route=builtRoute(posix.normalize(posix.join(from,path)).replace(/\.mdx?$/,''),base,routes);
        if(route)return result(policy.VERIFIED,'built relative docsite route exists',route);
    }
    return result(policy.BROKEN,'missing source target or built docsite route',relative(base,physical));
}
export async function probeURL(url,{fetcher=fetch,allowPrivate=false,timeout=policy.TIMEOUT_MS}={}){
    const observedAt=new Date().toISOString();let current=url;
    for(let redirects=0;redirects<=policy.MAX_REDIRECTS;redirects++){
        const checked=resolveReference('README.md',current,{routes:new Set()});
        if(checked.classification===policy.BROKEN||(!checked.external&&!allowPrivate))return {...checked,observedAt};
        try{
            const response=await fetcher(current,{redirect:'manual',credentials:'omit',signal:AbortSignal.timeout(timeout),headers:{'user-agent':'Trinity-docs-reference-check/1.0','accept':'*/*'}});
            const status=response.status,location=response.headers.get('location');
            await response.body?.cancel();
            if(status>=300&&status<400&&location){current=new URL(location,current).href;continue;}
            return {classification:httpClass(status),reason:httpClass(status)===policy.VERIFIED?'HTTP response measured':httpClass(status)===policy.BROKEN?'definitive broken HTTP reference':'HTTP access not confirmed',status,observedAt,finalURL:current};
        }catch(error){return {classification:policy.UNKNOWN,reason:'network access not confirmed',error:error.name,observedAt,finalURL:current};}
    }
    return {classification:policy.BROKEN,reason:'redirect limit exceeded',observedAt,finalURL:current};
}
export async function audit({base=root,external=false,files,routes=routeCatalog(base)}={}){
    files??=execFileSync('git',['ls-files','-z'],{cwd:base,encoding:'utf8'}).split('\0').filter(f=>policy.MARKDOWN_EXTENSIONS.split(',').includes(extname(f))&&(f.startsWith(policy.DOCS_TREE_ROOT+'/')||policy.ROOT_DOCUMENTS.split(',').includes(f)));
    const records=[];
    for(const file of files)for(const reference of markdownReferences(readFileSync(resolve(base,file),'utf8')))records.push({file,...reference,...resolveReference(file,reference.url,{base,routes})});
    const urls=[...new Set(records.map(r=>r.external).filter(Boolean))],probes=new Map();let next=0;
    if(external)await Promise.all(Array.from({length:policy.CONCURRENCY},async()=>{while(next<urls.length){const url=urls[next++];probes.set(url,await probeURL(url));}}));
    for(const record of records)if(probes.has(record.external))Object.assign(record,probes.get(record.external));
    const counts={verified:0,broken:0,unknown:0};for(const record of records)counts[record.classification===policy.VERIFIED?'verified':record.classification===policy.BROKEN?'broken':'unknown']++;
    return {spec_path:policy.spec_path,spec_hash:policy.spec_hash,observedAt:new Date().toISOString(),files:files.length,externalURLs:urls.length,externalProbed:probes.size,anchorsMeasured:false,counts,accepted:counts.broken===0,allReferencesVerified:counts.broken===0&&counts.unknown===0,records};
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
    const report=await audit({external:process.argv.includes('--external')});
    const index=process.argv.indexOf('--report');if(index>=0){const path=resolve(root,process.argv[index+1]);mkdirSync(dirname(path),{recursive:true});writeFileSync(path,JSON.stringify(report,null,2)+'\n');}
    console.log(`Documentation targets:${report.files} files;${report.counts.verified} verified,${report.counts.broken} broken,${report.counts.unknown} UNKNOWN;external probes:${report.externalProbed}/${report.externalURLs};anchors not measured`);
    for(const record of report.records.filter(r=>r.classification===policy.BROKEN))console.error(`${record.file}:${record.line} ${record.url} — ${record.reason}`);
    if(process.env.GITHUB_STEP_SUMMARY)writeFileSync(process.env.GITHUB_STEP_SUMMARY,`\n## Documentation reference evidence\n\nVerified targets: ${report.counts.verified}. Broken targets: ${report.counts.broken}. **Unconfirmed targets: ${report.counts.unknown}**. External probes: ${report.externalProbed}/${report.externalURLs}. Anchors were not measured. See the uploaded JSON for individual observations. This does not establish that every link is available.\n`,{flag:'a'});
    process.exitCode=report.accepted?0:1;
}
