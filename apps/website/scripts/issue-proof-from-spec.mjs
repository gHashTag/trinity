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
const problems=checkSchema(constants,schema,{GDS_WORKFLOW:'str',GDS_WORKFLOW_HASH:'str',EXTRA_PATHS:'arr',EXTRA_HASHES:'arr',EVIDENCE_PATH:'str'},source);
if(problems.length)throw new Error(problems.join('; '));
const fields=Object.fromEntries(Object.entries(constants).map(([k,v])=>[k,v.value]));
const result=runSpecTests(analysis,fields);
if(result.tests!==2||result.asserts!==19||result.failures.length)throw new Error(JSON.stringify(result));
if(fields.ACCEPT.length!==16||fields.ACCEPT.some((v,i)=>v!==Number(i===15)))throw new Error('Incomplete acceptance truth table');
if(process.argv.includes('--check')){
  const seal=JSON.parse(readFileSync(join(SITE,`.trinity/seals/queen_${moduleName}.json`),'utf8'));
  if(seal.spec_path!==source||seal.spec_hash!==`sha256:${sha256(Buffer.from(text))}`||seal.tests?.blocked)throw new Error('Missing or stale native issue proof seal');
}
for(const [k,v] of Object.entries(fields))if(k.endsWith('_HASH')&&!/^[a-f0-9]{64}$/.test(v))throw new Error(`Invalid ${k}`);
if(Boolean(fields.GDS_WORKFLOW)!==Boolean(fields.GDS_WORKFLOW_HASH))throw new Error('Incomplete GDS binding');
if((fields.EXTRA_PATHS?.length??0)!==(fields.EXTRA_HASHES?.length??0))throw new Error('Incomplete extra evidence binding');
for(const h of fields.EXTRA_HASHES??[])if(!/^[a-f0-9]{64}$/.test(h))throw new Error('Invalid extra evidence hash');
if(fields.EVIDENCE_PATH&&!fields.EXTRA_PATHS?.includes(fields.EVIDENCE_PATH))throw new Error('Evidence link must be hash bound');
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
