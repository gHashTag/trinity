import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {join} from 'node:path';
import {SITE,loadCompiler,constsOf,checkSchema,compilerErrors,verdictOf,sha256} from './agents-from-specs.mjs';
import {runSpecTests} from './viewport-from-spec.mjs';
// Which commit an issue proof may name while the CI of a new HEAD is still running (issue #1563).
// specs/queen/proof_commit.t27 is the only source of the walk table and of its two bounds;
// src/lib/queenProofCommit.generated.ts and conformance/queen_proof_commit.json are written
// from it, and --check fails when either is stale or the seal is missing.
const source='specs/queen/proof_commit.t27',moduleName='queen_proof_commit';
const text=readFileSync(join(SITE,source),'utf8');
const analyze=await loadCompiler(readFileSync(join(SITE,'public/t27/t27_compiler.wasm')));
const analysis=analyze(text),v=verdictOf(analysis),constants=constsOf(analysis);
if(compilerErrors(analysis).length||!v.typecheckOk||!v.hirOk||v.discarded||analysis.ast?.name!==moduleName)throw new Error('Proof commit spec rejected');
const problems=checkSchema(constants,{MAX_BEHIND:'u32',PENDING_GRACE_MS:'u32',WALK:'arr-u8'},{},source);
if(problems.length)throw new Error(problems.join('; '));
const fields=Object.fromEntries(Object.entries(constants).map(([k,x])=>[k,x.value]));
const result=runSpecTests(analysis,fields);
if(result.tests!==3||result.asserts!==8||result.failures.length)throw new Error(JSON.stringify(result));
// WALK[state * 2 + skippable]: a success selects, a failure stops, a pending commit is skipped only while skippable.
// The expected table is derived here from those three rules, not copied from the spec.
const expected=[];
for(const state of [0,1,2])for(const skippable of [0,1])expected.push(state===1?1:state===2?2:skippable?0:2);
if(fields.WALK.length!==6||fields.WALK.some((x,i)=>x!==expected[i]))throw new Error('Incomplete WALK table');
// A wait of minutes is expected; a day or more would keep a stale proof alive, and zero would never skip.
if(fields.MAX_BEHIND<1||fields.MAX_BEHIND>10)throw new Error('MAX_BEHIND outside 1..10');
if(fields.PENDING_GRACE_MS<600000||fields.PENDING_GRACE_MS>86400000)throw new Error('PENDING_GRACE_MS outside 10 minutes..24 hours');
if(process.argv.includes('--check')){
  const seal=JSON.parse(readFileSync(join(SITE,`.trinity/seals/queen_${moduleName}.json`),'utf8'));
  if(seal.spec_path!==source||seal.spec_hash!==`sha256:${sha256(Buffer.from(text))}`||seal.tests?.blocked||seal.tests?.failed||seal.tests?.passed!==seal.tests?.total||seal.tests?.total!==3)throw new Error('Missing or stale native proof commit seal');
}
const outputs={
  'src/lib/queenProofCommit.generated.ts':`// GENERATED from ${source}; sha256 ${sha256(Buffer.from(text))}\nexport const proofCommitPolicy = ${JSON.stringify(fields,null,2)} as const;\n`,
  [`conformance/${moduleName}.json`]:JSON.stringify({spec_path:source,spec_hash:sha256(Buffer.from(text)),vectors:fields.WALK.map((exp,mask)=>({table:'WALK',mask,expected:exp}))},null,2)+'\n',
};
for(const [path,bytes] of Object.entries(outputs)){
  if(process.argv.includes('--check')){if(readFileSync(join(SITE,path),'utf8')!==bytes)throw new Error(`Stale ${path}`);}
  else {mkdirSync(join(SITE,path,'..'),{recursive:true});writeFileSync(join(SITE,path),bytes);}
}
console.log(`Proof commit spec: ${result.tests} tests, ${result.asserts} assertions; 6 conformance rows`);
