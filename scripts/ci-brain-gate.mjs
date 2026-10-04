import {readFileSync,appendFileSync} from 'node:fs';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const policy=JSON.parse(readFileSync(resolve(root,'scripts/ci-gate.generated.json')));
const jobs=policy.BRAIN_JOBS.split(',');
export function gateVerdict(results){
    let mask=0;
    const phases=jobs.map((job,i)=>{
        const value=results?.[job]?.result;
        const result=['success','failure','cancelled','skipped'].includes(value)?value:'not-measured';
        if(result==='success')mask|=1<<i;
        return {job,result};
    });
    return {phases,mask,accepted:policy.BRAIN_ACCEPT[mask]===1};
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
    const verdict=gateVerdict(JSON.parse(process.env.BRAIN_RESULTS??'{}'));
    const report='# Brain CI report\n\n| Required phase | Actual result |\n|---|---|\n'+verdict.phases.map(({job,result})=>`| ${job} | ${result} |`).join('\n')+'\n\n'+(verdict.accepted?'All six required phases succeeded.':'Merge blocked: a required phase failed, was cancelled/skipped or did not produce a result.')+'\n';
    process.stdout.write(report);
    if(process.env.GITHUB_STEP_SUMMARY)appendFileSync(process.env.GITHUB_STEP_SUMMARY,report);
    process.exitCode=verdict.accepted?0:1;
}
