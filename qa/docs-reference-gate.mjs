import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createServer} from 'node:http';
import {policy,httpClass,markdownReferences,resolveReference,probeURL,audit} from '../scripts/docs-reference-check.mjs';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const vectors=JSON.parse(readFileSync(resolve(root,'conformance/ci_docs_reference_gate.json')));
assert.equal(vectors.spec_hash,policy.spec_hash);assert.equal(vectors.vectors.length,14);
for(const vector of vectors.vectors)assert.equal(httpClass(vector.status),vector.expected);
assert.notEqual(httpClass(403),policy.VERIFIED);assert.notEqual(httpClass(429),policy.VERIFIED);assert.equal(httpClass(404),policy.BROKEN);
assert.deepEqual(markdownReferences('```md\n[example](missing.md)\n```\n[real][ref]\n\n[ref]: /api/vsa\n![icon](image.svg)\n<a href="next.md">next</a>').map(r=>r.url),['/api/vsa','image.svg','next.md']);
assert.deepEqual(markdownReferences('Visit https://example.org/read and www.example.org/help.\n\n`https://example.org/code`\n```txt\nhttps://example.org/code-block\n```').map(r=>r.url),['https://example.org/read','http://www.example.org/help']);
const base=mkdtempSync(resolve(tmpdir(),'trinity-docs-gate-'));
const routes=new Set(['/docs/api/vsa']);
try{
    for(const file of ['docs/docs/api/vsa.md','docs/build/api/vsa/index.html','docs/static/logo.svg','README.md']){mkdirSync(dirname(resolve(base,file)),{recursive:true});writeFileSync(resolve(base,file),'fixture');}
    const fixture=(file,url)=>resolveReference(file,url,{base,routes});
    assert.equal(fixture('docs/docs/api/vsa.md','/api/vsa').classification,policy.VERIFIED);
    assert.equal(fixture('docs/docs/api/vsa.md','/docs/api/vsa').classification,policy.VERIFIED);
    assert.equal(fixture('docs/docs/api/vsa.md','/logo.svg').classification,policy.VERIFIED);
    assert.equal(fixture('docs/docs/api/vsa.md','../../../README.md').classification,policy.VERIFIED);
    assert.equal(fixture('README.md','missing.md').classification,policy.BROKEN);
    assert.equal(fixture('README.md','../outside.md').classification,policy.BROKEN);
    assert.equal(fixture('README.md','bad%ZZ.md').classification,policy.BROKEN);
    assert.equal(fixture('README.md','https://user:password@example.com').classification,policy.BROKEN);
    assert.equal(fixture('README.md','http://localhost:3000/').classification,policy.UNKNOWN);
    for(const host of ['127.0.0.1','192.168.1.1','10.0.0.1','172.16.0.1','[::1]','[fd00::1]'])assert.equal(fixture('README.md',`http://${host}/`).external,undefined,`Private example ${host} must not be probed`);
    rmSync(resolve(base,'docs/build/api/vsa/index.html'));
    assert.equal(fixture('README.md','/api/vsa').classification,policy.BROKEN,'a catalog entry alone is not a built route');
    writeFileSync(resolve(base,'README.md'),'[broken](missing.md)');
    const report=await audit({base,files:['README.md'],routes});assert.equal(report.accepted,false);assert.equal(report.counts.broken,1);
}finally{rmSync(base,{recursive:true,force:true});}
const server=createServer((request,response)=>{
    if(request.url==='/loop'){response.writeHead(302,{location:'/loop'});response.end();return;}
    if(request.url==='/redirect'){response.writeHead(302,{location:'/200'});response.end();return;}
    if(request.url==='/private'){response.writeHead(302,{location:'http://localhost:12345/'});response.end();return;}
    response.writeHead(Number(request.url.slice(1)));response.end('measured fixture');
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const origin=`http://127.0.0.1:${server.address().port}`;
try{
    for(const status of [200,202,203,400,401,403,404,410,429,503]){const observed=await probeURL(`${origin}/${status}`,{allowPrivate:true});assert.equal(observed.status,status);assert.equal(observed.classification,httpClass(status));assert.ok(observed.observedAt);}
    assert.equal((await probeURL(`${origin}/redirect`,{allowPrivate:true})).status,200);
    assert.equal((await probeURL(`${origin}/loop`,{allowPrivate:true})).classification,policy.BROKEN);
    assert.equal((await probeURL('http://localhost:12345/')).reason,'local/private endpoint example; not probed');
}finally{await new Promise(resolve=>server.close(resolve));}
console.log('Docs gate:14 conformance vectors; actual HTTP/redirect fixtures and missing-target/parser regressions PASS. Fixtures do not establish public URL availability.');
