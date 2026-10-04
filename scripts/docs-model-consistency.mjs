import {readFileSync,existsSync,statSync,appendFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const policy=JSON.parse(readFileSync(resolve(root,'scripts/ci-gate.generated.json')));
if(!/^[A-Za-z0-9-]+\/[A-Za-z0-9._-]+$/.test(policy.TRAINING_REPO)||!/^[a-f0-9]{40}$/.test(policy.TRAINING_REV))throw new Error('Invalid pinned model source');
export function checkModelEvidence({revision,files,documentation}){
    if(revision!==policy.TRAINING_REV)throw new Error('Training revision does not match the spec');
    for(const path of [policy.TJEPA_SOURCE,policy.TJEPA_TRAINER]){
        if(!files.has(path))throw new Error(`Missing migrated T-JEPA source: ${path}`);
        const link=`https://github.com/${policy.TRAINING_REPO}/blob/${policy.TRAINING_REV}/${path}`;
        if(!documentation.includes(link))throw new Error(`Documentation does not identify pinned moved source: ${path}`);
    }
    if(!documentation.includes('Moved to trinity-training'))throw new Error('Documentation still claims the model is implemented here');
    return true;
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
    if(process.argv[2]==='--policy'){
        const output=`repo=${policy.TRAINING_REPO}\nrev=${policy.TRAINING_REV}\n`;
        if(process.env.GITHUB_OUTPUT)appendFileSync(process.env.GITHUB_OUTPUT,output);
        process.stdout.write(output);
    }else if(process.argv[2]==='--check'&&process.argv[3]){
        const checkout=resolve(process.argv[3]);
        const revision=execFileSync('git',['-C',checkout,'rev-parse','HEAD'],{encoding:'utf8'}).trim();
        const files=new Set([policy.TJEPA_SOURCE,policy.TJEPA_TRAINER].filter(p=>existsSync(resolve(checkout,p))&&statSync(resolve(checkout,p)).isFile()&&statSync(resolve(checkout,p)).size>0));
        checkModelEvidence({revision,files,documentation:readFileSync(resolve(root,'docs/DOCUMENTATION_INDEX.md'),'utf8')});
        console.log(`T-JEPA moved source verified at ${policy.TRAINING_REPO}@${revision}; no local model implementation or model-inference test is claimed.`);
    }else throw new Error('Use --policy or --check <pinned-training-checkout>');
}
