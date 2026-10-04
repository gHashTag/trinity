import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {loadCompiler,constsOf,checkSchema,compilerErrors,verdictOf,sha256} from '../apps/website/scripts/agents-from-specs.mjs';
import {runSpecTests} from '../apps/website/scripts/viewport-from-spec.mjs';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const source='specs/ci/docs_reference_gate.t27',text=readFileSync(resolve(root,source),'utf8');
const analyze=await loadCompiler(readFileSync(resolve(root,'apps/website/public/t27/t27_compiler.wasm')));
const analysis=analyze(text),verdict=verdictOf(analysis),constants=constsOf(analysis);
if(compilerErrors(analysis).length||!verdict.typecheckOk||!verdict.hirOk||verdict.discarded||analysis.ast?.name!=='ci_docs_reference_gate')throw new Error('Docs reference spec rejected');
const schema={DOCS_BASE:'str',DOCS_TREE_ROOT:'str',ROOT_DOCUMENTS:'str',MARKDOWN_EXTENSIONS:'str',GFM_AUTOLINKS:'u32',DOCS_CONTENT_ROOT:'str',DOCS_STATIC_ROOT:'str',DOCS_BUILD_ROOT:'str',BROKEN:'u32',VERIFIED:'u32',UNKNOWN:'u32',HTTP_VERIFIED_MIN:'u32',HTTP_VERIFIED_MAX:'u32',HTTP_STATUS:'arr-u32',HTTP_CLASS:'arr-u8',TIMEOUT_MS:'u32',CONCURRENCY:'u32',MAX_REDIRECTS:'u32'};
const problems=checkSchema(constants,schema,{},source);if(problems.length)throw new Error(problems.join('; '));
const fields=Object.fromEntries(Object.entries(constants).map(([key,constant])=>[key,constant.value]));
const result=runSpecTests(analysis,fields);if(result.tests!==3||result.asserts!==17||result.failures.length)throw new Error(JSON.stringify(result));
if(fields.HTTP_STATUS.length!==14||fields.HTTP_CLASS.length!==14||new Set(fields.HTTP_STATUS).size!==14)throw new Error('Incomplete HTTP conformance table');
const hash=sha256(Buffer.from(text));
const outputs={
    'scripts/docs-gate.generated.json':JSON.stringify({spec_path:source,spec_hash:hash,...fields},null,2)+'\n',
    'conformance/ci_docs_reference_gate.json':JSON.stringify({spec_path:source,spec_hash:hash,vectors:fields.HTTP_STATUS.map((status,i)=>({status,expected:fields.HTTP_CLASS[i]}))},null,2)+'\n',
};
for(const [path,bytes] of Object.entries(outputs)){
    if(process.argv.includes('--check')){if(readFileSync(resolve(root,path),'utf8')!==bytes)throw new Error(`Stale ${path}`);}
    else{mkdirSync(dirname(resolve(root,path)),{recursive:true});writeFileSync(resolve(root,path),bytes);}
}
if(process.argv.includes('--check')){
    const seal=JSON.parse(readFileSync(resolve(root,'.trinity/seals/ci_ci_docs_reference_gate.json'),'utf8'));
    if(seal.spec_path!==source||seal.spec_hash!==`sha256:${hash}`||seal.tests?.blocked)throw new Error('Missing or stale native docs reference seal');
}
console.log(`Docs reference spec:${result.tests} tests/${result.asserts} assertions;14 HTTP vectors`);
