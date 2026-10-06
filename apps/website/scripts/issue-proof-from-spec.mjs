import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {join} from 'node:path';
import {SITE,loadCompiler,constsOf,checkSchema,compilerErrors,verdictOf,sha256} from './agents-from-specs.mjs';
import {runSpecTests} from './viewport-from-spec.mjs';
for (const [source,moduleName,exportName,target] of [
  ['specs/queen/issue_proof.t27','queen_issue_proof','issueProofPolicy','queenIssueProof'],
  ['specs/queen/memory_issue_proof.t27','queen_memory_issue_proof','memoryIssueProofPolicy','queenMemoryIssueProof'],
]) {
const text=readFileSync(join(SITE,source),'utf8');
const analyze=await loadCompiler(readFileSync(join(SITE,'public/t27/t27_compiler.wasm')));
const analysis=analyze(text),v=verdictOf(analysis),constants=constsOf(analysis);
if(compilerErrors(analysis).length||!v.typecheckOk||!v.hirOk||v.discarded||analysis.ast?.name!==moduleName)throw new Error('Issue proof spec rejected');
const schema={REPO:'str',ISSUES:'arr-u32',SPEC:'str',SPEC_HASH:'str',SEAL:'str',SEAL_HASH:'str',VECTORS:'str',VECTORS_HASH:'str',VERIFIER:'str',VERIFIER_HASH:'str',MAKEFILE:'str',MAKEFILE_HASH:'str',WORKFLOW:'str',WORKFLOW_HASH:'str',VECTOR_COUNT:'u32',CACHE_MS:'u32',ACCEPT:'arr-u8'};
// The Memory policy lists several sealed specs ("groups") and which of them each closed issue needs.
const memorySchema={REPO:'str',WORKFLOW:'str',WORKFLOW_HASH:'str',MAKEFILE:'str',MAKEFILE_HASH:'str',GLOBAL_PATHS:'arr',GLOBAL_HASHES:'arr',GROUP_NAMES:'arr',GROUP_SPEC:'arr',GROUP_SPEC_HASH:'arr',GROUP_SEAL:'arr',GROUP_SEAL_HASH:'arr',GROUP_VECTORS:'arr',GROUP_VECTORS_HASH:'arr',GROUP_VECTOR_COUNT:'arr-u32',GROUP_EVIDENCE:'arr',GROUP_PATHS:'arr',GROUP_PATH_HASHES:'arr',GROUP_PATH_OWNER:'arr-u32',ISSUE_NUMBERS:'arr-u32',ISSUE_GROUPS:'arr-u32',CACHE_MS:'u32',ACCEPT:'arr-u8'};
const profileSchema=moduleName==='queen_issue_proof'
  ? {...schema,GDS_WORKFLOW:'str',GDS_WORKFLOW_HASH:'str'}
  : memorySchema;
const problems=checkSchema(constants,profileSchema,{},source);
if(problems.length)throw new Error(problems.join('; '));
const fields=Object.fromEntries(Object.entries(constants).map(([k,v])=>[k,v.value]));
const result=runSpecTests(analysis,fields);
if(result.tests!==2||result.asserts!==19||result.failures.length)throw new Error(JSON.stringify(result));
if(fields.ACCEPT.length!==16||fields.ACCEPT.some((v,i)=>v!==Number(i===15)))throw new Error('Incomplete acceptance truth table');
if(process.argv.includes('--check')){
  const seal=JSON.parse(readFileSync(join(SITE,`.trinity/seals/queen_${moduleName}.json`),'utf8'));
  if(seal.spec_path!==source||seal.spec_hash!==`sha256:${sha256(Buffer.from(text))}`||seal.tests?.blocked)throw new Error('Missing or stale native issue proof seal');
}
for(const [k,v] of Object.entries(fields))if(k.endsWith('_HASH')||k.endsWith('_HASHES'))for(const h of [].concat(v))if(!/^[a-f0-9]{64}$/.test(h))throw new Error(`Invalid ${k}`);
if(Boolean(fields.GDS_WORKFLOW)!==Boolean(fields.GDS_WORKFLOW_HASH))throw new Error('Incomplete GDS binding');
if(moduleName==='queen_memory_issue_proof'){
  const G=fields.GROUP_SPEC.length,same=(a,b,what)=>{if(fields[a].length!==fields[b].length)throw new Error(`Incomplete ${what}`);};
  for(const k of ['GROUP_NAMES','GROUP_SPEC_HASH','GROUP_SEAL','GROUP_SEAL_HASH','GROUP_VECTORS','GROUP_VECTORS_HASH','GROUP_VECTOR_COUNT','GROUP_EVIDENCE'])same('GROUP_SPEC',k,`group table ${k}`);
  same('GLOBAL_PATHS','GLOBAL_HASHES','shared file binding');same('GROUP_PATHS','GROUP_PATH_HASHES','group file binding');same('GROUP_PATHS','GROUP_PATH_OWNER','group file owner');same('ISSUE_NUMBERS','ISSUE_GROUPS','issue to group table');
  if(fields.GROUP_VECTOR_COUNT.some(n=>n<1)||new Set(fields.GROUP_SPEC).size!==G||new Set(fields.GROUP_NAMES).size!==G)throw new Error('Invalid group table');
  if(fields.GROUP_PATH_OWNER.some(o=>o>=G)||fields.ISSUE_GROUPS.some(o=>o>=G))throw new Error('Group index out of range');
  const pairs=fields.ISSUE_NUMBERS.map((n,i)=>`${n}:${fields.ISSUE_GROUPS[i]}`);
  if(new Set(pairs).size!==pairs.length)throw new Error('Duplicate issue to group pair');
  for(let g=0;g<G;g++)if(!fields.ISSUE_GROUPS.includes(g))throw new Error(`Group ${g} names no issue`);
  for(const e of fields.GROUP_EVIDENCE)if(e&&!fields.GROUP_PATHS.includes(e))throw new Error('Evidence link must be hash bound');
}
const outputs={
  [`src/lib/${target}.generated.ts`]:`// GENERATED from ${source}; sha256 ${sha256(Buffer.from(text))}\nexport const ${exportName} = ${JSON.stringify(fields,null,2)} as const;\n`,
  [`conformance/${moduleName}.json`]:JSON.stringify({spec_path:source,spec_hash:sha256(Buffer.from(text)),vectors:fields.ACCEPT.map((expected,mask)=>({mask,expected}))},null,2)+'\n',
};
for(const [path,bytes] of Object.entries(outputs)){
  if(process.argv.includes('--check')){if(readFileSync(join(SITE,path),'utf8')!==bytes)throw new Error(`Stale ${path}`);}
  else {mkdirSync(join(SITE,path,'..'),{recursive:true});writeFileSync(join(SITE,path),bytes);}
}
console.log(`Issue proof spec: ${result.tests} tests, ${result.asserts} assertions; 16 conformance rows`);
}
// When a verdict may be published or kept (issue #1392): shared by both policies.
{
const source='specs/queen/issue_proof_refresh.t27',moduleName='queen_issue_proof_refresh';
const text=readFileSync(join(SITE,source),'utf8');
const analyze=await loadCompiler(readFileSync(join(SITE,'public/t27/t27_compiler.wasm')));
const analysis=analyze(text),v=verdictOf(analysis),constants=constsOf(analysis);
if(compilerErrors(analysis).length||!v.typecheckOk||!v.hirOk||v.discarded||analysis.ast?.name!==moduleName)throw new Error('Issue proof refresh spec rejected');
const problems=checkSchema(constants,{PUBLISH:'arr-u8',RETAIN:'arr-u8'},{},source);
if(problems.length)throw new Error(problems.join('; '));
const fields=Object.fromEntries(Object.entries(constants).map(([k,v])=>[k,v.value]));
const result=runSpecTests(analysis,fields);
if(result.tests!==2||result.asserts!==12||result.failures.length)throw new Error(JSON.stringify(result));
// Only the all-true row may publish or retain a positive; anything less is unknown.
for(const [name,size] of [['PUBLISH',8],['RETAIN',4]])if(fields[name].length!==size||fields[name].some((x,i)=>x!==Number(i===size-1)))throw new Error(`Incomplete ${name} truth table`);
if(process.argv.includes('--check')){
  const seal=JSON.parse(readFileSync(join(SITE,`.trinity/seals/queen_${moduleName}.json`),'utf8'));
  if(seal.spec_path!==source||seal.spec_hash!==`sha256:${sha256(Buffer.from(text))}`||seal.tests?.blocked||seal.tests?.failed)throw new Error('Missing or stale native issue proof refresh seal');
}
const outputs={
  'src/lib/queenIssueProofRefresh.generated.ts':`// GENERATED from ${source}; sha256 ${sha256(Buffer.from(text))}\nexport const issueProofRefreshPolicy = ${JSON.stringify(fields,null,2)} as const;\n`,
  [`conformance/${moduleName}.json`]:JSON.stringify({spec_path:source,spec_hash:sha256(Buffer.from(text)),vectors:[...fields.PUBLISH.map((expected,mask)=>({table:'PUBLISH',mask,expected})),...fields.RETAIN.map((expected,mask)=>({table:'RETAIN',mask,expected}))]},null,2)+'\n',
};
for(const [path,bytes] of Object.entries(outputs)){
  if(process.argv.includes('--check')){if(readFileSync(join(SITE,path),'utf8')!==bytes)throw new Error(`Stale ${path}`);}
  else {mkdirSync(join(SITE,path,'..'),{recursive:true});writeFileSync(join(SITE,path),bytes);}
}
console.log(`Issue proof refresh spec: ${result.tests} tests, ${result.asserts} assertions; 12 conformance rows`);
}
