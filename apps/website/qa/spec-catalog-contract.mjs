import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {specExplorerHash,canonicalSpecUrl,resolveManifestSpec} from '../src/lib/specCatalog.ts';
import {loadSpecSource,analyzeCached} from '../src/lib/t27Compiler.ts';
import {atlasAgentPacket} from '../src/lib/queenUniverseAtlas.ts';

const manifest=JSON.parse(readFileSync('public/t27/manifest.json','utf8'));
const atlas=JSON.parse(readFileSync('public/t27/universe-atlas.json','utf8'));
const hello='specs/demos/hello_world.t27';
assert.equal(canonicalSpecUrl(hello),'https://t27.ai/#/specs?spec=specs%2Fdemos%2Fhello_world.t27');
let count=0;
for(const spec of atlas.specs)for(const source of spec.sources){
  const entry=resolveManifestSpec(manifest,source.path);
  assert.equal(entry.path,source.path);
  assert.equal(entry.repo,source.repo.split('/')[1]);
  const url=new URL(canonicalSpecUrl(source.path));
  assert.equal(new URLSearchParams(url.hash.split('?')[1]).get('spec'),source.path);
  const bytes=readFileSync('public/t27/files/'+entry.path);
  assert.equal(createHash('sha256').update(bytes).digest('hex'),spec.id);
  count++;
}
assert.equal(count,manifest.specs.length,'every central catalog source is represented on the hive');
assert.equal(resolveManifestSpec(manifest,null).path,hello);
for(const path of ['missing.t27','../secret.t27','https://evil.test/x.t27','a/../x.t27','x.t27#other','/x.t27']){
  assert.throws(()=>resolveManifestSpec(manifest,path),'invalid/unknown deep links must not substitute hello_world');
}
assert.throws(()=>resolveManifestSpec({...manifest,specs:[manifest.specs[0],manifest.specs[0]]},hello));
const hash='a'.repeat(64),link=specExplorerHash(hello,{embedded:true,sha256:hash});
assert.equal(new URLSearchParams(link.split('?')[1]).get('embed'),'1');
assert.equal(new URLSearchParams(link.split('?')[1]).get('sha256'),hash);
assert.throws(()=>specExplorerHash(hello,{sha256:'wrong'}));
const packet=atlasAgentPacket(atlas,atlas.issues.find(i=>i.hits.length));
assert.match(packet,/https:\/\/t27.ai\/#\/specs\?spec=/,'agent reuse evidence must carry canonical catalog links');

const fetchOriginal=globalThis.fetch;
const bytes=readFileSync('public/t27/files/'+hello),sha=createHash('sha256').update(bytes).digest('hex');
let sourceFetches=0;
try{
  globalThis.fetch=async(url,options)=>{
    if(url==='t27/t27_compiler.wasm')return new Response(readFileSync('public/t27/t27_compiler.wasm'),{headers:{'Content-Type':'application/wasm'}});
    assert.equal(options?.credentials,'omit');
    if(url==='t27/manifest.json')return new Response(JSON.stringify(manifest));
    assert.equal(url,'t27/files/specs/demos/hello_world.t27');sourceFetches++;
    return new Response(bytes);
  };
  assert.equal(await loadSpecSource(hello,sha),bytes.toString());
  await assert.rejects(loadSpecSource(hello,'b'.repeat(64)),/SHA-256/);
  const before=sourceFetches;
  await assert.rejects(loadSpecSource('missing.t27'),/catalog/i);
  assert.equal(sourceFetches,before,'unknown source paths never fetch arbitrary content');
  const compiled=await analyzeCached(hello,bytes.toString());
  assert.equal((await analyzeCached(hello,bytes.toString())),compiled,'identical source reuses its analysis');
  const revised=bytes.toString()+'\n// revised source\n';
  const updated=await analyzeCached(hello,revised);
  assert.equal(updated.sourceBytes,Buffer.byteLength(revised),'same path with new bytes must not reuse old analysis');
}finally{globalThis.fetch=fetchOriginal;}
const viewer=readFileSync('src/components/QueenCatalogInspector.tsx','utf8').split('export function QueenCatalogSpec')[1];
assert.match(viewer,/<iframe/);assert.match(viewer,/specExplorerHash/);
assert.doesNotMatch(viewer,/fetch\(|<pre|window\.open|_blank/,'the hive embeds the central Explorer, not another source implementation');
console.log(`Central spec catalog: PASS (${count} exact source links, identity, SHA pinning, fail-closed paths, embedded Explorer)`);
