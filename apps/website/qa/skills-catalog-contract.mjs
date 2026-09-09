// The Skill Explorer's catalog, held to the same standard as the spec one:
// one public address per skill, bytes pinned by hash, an allowlist that is the
// only door to publication, and a fail-closed resolver that never substitutes
// the featured skill for a deep link it does not recognise.
//
//   node --experimental-strip-types qa/skills-catalog-contract.mjs
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {validSkillId,skillExplorerHash,canonicalSkillUrl,resolveManifestSkill} from '../src/lib/skillsCatalog.ts';
import {loadSkillSource} from '../src/lib/skillsLoader.ts';

const manifest=JSON.parse(readFileSync('public/skills/manifest.json','utf8'));
const core=JSON.parse(readFileSync('public/skills/skills-core.json','utf8'));
const publish=JSON.parse(readFileSync('public/skills/publish.json','utf8'));
const baseline=JSON.parse(readFileSync('public/skills/link-baseline.json','utf8'));
const specPaths=new Set(JSON.parse(readFileSync('public/t27/manifest.json','utf8')).specs.map(s=>s.path));

const guards='999-multibots-telegraf/blind-guards';
assert.equal(canonicalSkillUrl(guards),'https://t27.ai/#/skills?skill=999-multibots-telegraf%2Fblind-guards');
const pinned=skillExplorerHash(guards,{embedded:true,sha256:'a'.repeat(64)});
assert.equal(new URLSearchParams(pinned.split('?')[1]).get('embed'),'1');
assert.throws(()=>skillExplorerHash(guards,{sha256:'wrong'}));

// Every published skill: on the allowlist, on disk, and byte-identical to what
// the manifest says it is. The allowlist check runs here as well as in the
// prebuild index because this is the file a reviewer reads before merging.
const allowed=new Set(Object.entries(publish).flatMap(([repo,dirs])=>dirs.map(dir=>`${repo}/${dir}`)));
for(const skill of manifest.skills){
  assert.ok(validSkillId(skill.id),`${skill.id} must be a safe two-segment id`);
  assert.equal(skill.id,`${skill.repo}/${skill.dir}`);
  assert.equal(skill.path,`${skill.repo}/${skill.dir}/${skill.source}`);
  assert.ok(allowed.has(skill.id),`${skill.id} is published without being on the allowlist`);
  const file='public/skills/files/'+skill.path;
  assert.ok(existsSync(file),`${skill.id} has no vendored file`);
  assert.equal(createHash('sha256').update(readFileSync(file)).digest('hex'),skill.sha256,`${skill.id} bytes drifted from the manifest`);
  assert.equal(resolveManifestSkill(manifest,skill.id),skill);
  const url=new URL(canonicalSkillUrl(skill.id));
  assert.equal(new URLSearchParams(url.hash.split('?')[1]).get('skill'),skill.id);
}
assert.equal(manifest.skillCount,manifest.skills.length);
assert.equal(core.skillCount,manifest.skills.length);
assert.equal(resolveManifestSkill(manifest,null).id,manifest.featured);
assert.throws(()=>resolveManifestSkill({...manifest,skills:[manifest.skills[0],manifest.skills[0]]},manifest.skills[0].id));
for(const id of ['nope','../x','a/b/c','a%2Fb','x?y=1']){
  assert.throws(()=>resolveManifestSkill(manifest,id),`a malformed deep link must not silently open ${manifest.featured}`);
}

// The index's claims, checked against the manifest they were derived from.
const STATUSES=new Set(['resolved','ambiguous','missing']);
let declaredRefs=0;
for(const skill of manifest.skills)for(const ref of skill.specRefs){
  assert.ok(STATUSES.has(ref.status),`${skill.id} carries an unknown ref status`);
  assert.ok(['frontmatter','site','body'].includes(ref.via));
  if(!ref.declared)continue;
  declaredRefs++;
  assert.equal(ref.status,'resolved',`${skill.id} declares ${ref.text}, which does not resolve`);
  assert.ok(specPaths.has(ref.to),`${skill.id} resolves to a path outside the spec corpus`);
}
const inverted={};
for(const [id,paths] of Object.entries(core.skillToSpecs)){
  assert.ok(manifest.skills.some(s=>s.id===id),`skills-core credits ${id}, which is not published`);
  for(const path of paths){
    assert.ok(specPaths.has(path),`${path} is credited to a skill but is not in the spec corpus`);
    (inverted[path]??=[]).push(id);
  }
}
for(const path of Object.keys(inverted))inverted[path].sort();
assert.deepEqual(core.specToSkills,inverted,'skillToSpecs and specToSkills must be exact inverses');
assert.deepEqual(core.coverage.specsWithSkill,Object.keys(core.specToSkills).sort());
assert.ok(core.coverage.skillsUnbound.length<=baseline.unbound,'unbound skills may not drift past the baseline');
assert.equal(core.coverage.skillsBroken.length,0);
assert.equal(core.coverage.skillsBound.length+core.coverage.skillsUnbound.length+core.coverage.skillsBroken.length,manifest.skills.length);

// Loading a body: same origin, no credentials, no path the catalog did not name.
const fetchOriginal=globalThis.fetch;
const featured=resolveManifestSkill(manifest,null);
const bytes=readFileSync('public/skills/files/'+featured.path);
let sourceFetches=0;
try{
  globalThis.fetch=async(url,options)=>{
    assert.equal(options?.credentials,'omit');
    if(url==='skills/manifest.json')return new Response(JSON.stringify(manifest));
    assert.equal(url,'skills/files/'+featured.path.split('/').map(encodeURIComponent).join('/'));
    sourceFetches++;
    return new Response(bytes);
  };
  assert.equal(await loadSkillSource(featured.id,featured.sha256),bytes.toString());
  await assert.rejects(loadSkillSource(featured.id,'b'.repeat(64)),/SHA-256/);
  const before=sourceFetches;
  await assert.rejects(loadSkillSource('ghost/missing'),/catalog/i);
  await assert.rejects(loadSkillSource('x?y=1'),/Invalid catalog skill id/);
  assert.equal(sourceFetches,before,'an unknown id never fetches arbitrary content');
}finally{globalThis.fetch=fetchOriginal;}

console.log(`Skill catalog: PASS (${manifest.skills.length} published of ${manifest.skills.length+manifest.withheld}, ${declaredRefs} declared refs, ${core.coverage.skillsBound.length} bound / ${core.coverage.skillsUnbound.length} unbound within baseline ${baseline.unbound}, ${core.coverage.specsWithSkill.length} specs credited, SHA pinning, allowlist, fail-closed ids)`);
