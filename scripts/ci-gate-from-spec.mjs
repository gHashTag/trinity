import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {loadCompiler,constsOf,checkSchema,compilerErrors,verdictOf,sha256} from '../apps/website/scripts/agents-from-specs.mjs';
import {runSpecTests} from '../apps/website/scripts/viewport-from-spec.mjs';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const source='specs/ci/corona_pr_gate.t27';
const text=readFileSync(resolve(root,source),'utf8');
const analyze=await loadCompiler(readFileSync(resolve(root,'apps/website/public/t27/t27_compiler.wasm')));
const analysis=analyze(text),verdict=verdictOf(analysis),constants=constsOf(analysis);
if(compilerErrors(analysis).length||!verdict.typecheckOk||!verdict.hirOk||verdict.discarded||analysis.ast?.name!=='ci_corona_pr_gate')throw new Error('CI gate spec rejected');
const schema={COMMENT_ALLOWED:'arr-u8',BRAIN_JOBS:'str',HEALTH_THRESHOLD:'u32',BRAIN_ACCEPT:'arr-u8',TRAINING_REPO:'str',TRAINING_REV:'str',TJEPA_SOURCE:'str',TJEPA_TRAINER:'str',DOCS_SOURCE_ROOT:'str',DOCS_BUILD_ROOT:'str'};
const problems=checkSchema(constants,schema,{},source);
if(problems.length)throw new Error(problems.join('; '));
const fields=Object.fromEntries(Object.entries(constants).map(([key,constant])=>[key,constant.value]));
const result=runSpecTests(analysis,fields);
if(result.tests!==2||result.asserts!==14||result.failures.length)throw new Error(JSON.stringify(result));
if(fields.COMMENT_ALLOWED.length!==4||fields.COMMENT_ALLOWED.some((v,i)=>v!==Number(i===3)))throw new Error('Incomplete notification table');
if(fields.BRAIN_ACCEPT.length!==64||fields.BRAIN_ACCEPT.some((v,i)=>v!==Number(i===63))||fields.BRAIN_JOBS.split(',').length!==6)throw new Error('Incomplete strict Brain gate');
if(!/^[a-f0-9]{40}$/.test(fields.TRAINING_REV))throw new Error('Training source is not pinned');
const hash=sha256(Buffer.from(text));
const outputs={
    'scripts/ci-gate.generated.json':JSON.stringify({spec_path:source,spec_hash:hash,...fields},null,2)+'\n',
    'conformance/ci_corona_pr_gate.json':JSON.stringify({spec_path:source,spec_hash:hash,notifications:fields.COMMENT_ALLOWED.map((expected,mask)=>({mask,expected})),brain:fields.BRAIN_ACCEPT.map((expected,mask)=>({mask,expected}))},null,2)+'\n',
};
for(const [path,bytes] of Object.entries(outputs)){
    if(process.argv.includes('--check')){
        if(readFileSync(resolve(root,path),'utf8')!==bytes)throw new Error(`Stale ${path}`);
    }else{
        mkdirSync(dirname(resolve(root,path)),{recursive:true});writeFileSync(resolve(root,path),bytes);
    }
}
if(process.argv.includes('--check')){
    const seal=JSON.parse(readFileSync(resolve(root,'.trinity/seals/ci_ci_corona_pr_gate.json'),'utf8'));
    if(seal.spec_path!==source||seal.spec_hash!==`sha256:${hash}`||seal.tests?.blocked)throw new Error('Missing or stale native CI gate seal');
}
console.log(`CI gate spec: ${result.tests} tests/${result.asserts} assertions;68 conformance vectors`);
