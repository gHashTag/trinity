import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {join} from 'node:path';
import {SITE,loadCompiler,constsOf,checkSchema,compilerErrors,verdictOf,sha256} from './agents-from-specs.mjs';
import {runSpecTests} from './viewport-from-spec.mjs';
// How the catalog map pages through the issues of one repository world (issue #1513).
// specs/queen/world_pages.t27 is the only source of the page ceiling and of the two
// truth tables; src/lib/queenWorldPages.generated.ts and conformance/queen_world_pages.json
// are written from it, and --check fails when either is stale or the seal is missing.
const source='specs/queen/world_pages.t27',moduleName='queen_world_pages';
const text=readFileSync(join(SITE,source),'utf8');
const analyze=await loadCompiler(readFileSync(join(SITE,'public/t27/t27_compiler.wasm')));
const analysis=analyze(text),v=verdictOf(analysis),constants=constsOf(analysis);
if(compilerErrors(analysis).length||!v.typecheckOk||!v.hirOk||v.discarded||analysis.ast?.name!==moduleName)throw new Error('World pages spec rejected');
const problems=checkSchema(constants,{PER_PAGE:'u32',MAX_PAGES:'u32',NEXT:'arr-u8',COMPLETE:'arr-u8',DROP_UNSEEN:'arr-u8'},{},source);
if(problems.length)throw new Error(problems.join('; '));
const fields=Object.fromEntries(Object.entries(constants).map(([k,x])=>[k,x.value]));
const result=runSpecTests(analysis,fields);
if(result.tests!==2||result.asserts!==28||result.failures.length)throw new Error(JSON.stringify(result));
// Only the all-true row requests a page or marks the world complete; anything less is not.
for(const [name,size] of [['NEXT',16],['COMPLETE',8]])if(fields[name].length!==size||fields[name].some((x,i)=>x!==Number(i===size-1)))throw new Error(`Incomplete ${name} truth table`);
if(fields.DROP_UNSEEN.length!==2||fields.DROP_UNSEEN[0]!==0||fields.DROP_UNSEEN[1]!==1)throw new Error('Incomplete DROP_UNSEEN table');
// GitHub's issues endpoint caps a page at 100 records and rejects page 0.
if(fields.PER_PAGE!==100||fields.MAX_PAGES<1||fields.MAX_PAGES>100)throw new Error('Page limits outside what the endpoint allows');
if(process.argv.includes('--check')){
  const seal=JSON.parse(readFileSync(join(SITE,`.trinity/seals/queen_${moduleName}.json`),'utf8'));
  if(seal.spec_path!==source||seal.spec_hash!==`sha256:${sha256(Buffer.from(text))}`||seal.tests?.blocked||seal.tests?.failed||seal.tests?.passed!==seal.tests?.total||seal.tests?.total!==2)throw new Error('Missing or stale native world pages seal');
}
const table=(name)=>fields[name].map((expected,mask)=>({table:name,mask,expected}));
const outputs={
  'src/lib/queenWorldPages.generated.ts':`// GENERATED from ${source}; sha256 ${sha256(Buffer.from(text))}\nexport const worldPagesPolicy = ${JSON.stringify(fields,null,2)} as const;\n`,
  [`conformance/${moduleName}.json`]:JSON.stringify({spec_path:source,spec_hash:sha256(Buffer.from(text)),vectors:[...table('NEXT'),...table('COMPLETE'),...table('DROP_UNSEEN')]},null,2)+'\n',
};
for(const [path,bytes] of Object.entries(outputs)){
  if(process.argv.includes('--check')){if(readFileSync(join(SITE,path),'utf8')!==bytes)throw new Error(`Stale ${path}`);}
  else {mkdirSync(join(SITE,path,'..'),{recursive:true});writeFileSync(join(SITE,path),bytes);}
}
console.log(`World pages spec: ${result.tests} tests, ${result.asserts} assertions; 26 conformance rows`);
