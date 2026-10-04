import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const policy=JSON.parse(readFileSync(resolve(root,'scripts/ci-gate.generated.json')));
const vectors=JSON.parse(readFileSync(resolve(root,'conformance/ci_corona_pr_gate.json')));
assert.equal(vectors.spec_hash,policy.spec_hash);
const brain=readFileSync(resolve(root,'.github/workflows/brain-ci.yml'),'utf8');
const dev=readFileSync(resolve(root,'.github/workflows/dev-enforcement.yml'),'utf8');
function stepCondition(text,name){
    const start=text.indexOf(`- name: ${name}\n`);assert.ok(start>=0,`Missing step ${name}`);
    const part=text.slice(start);const end=part.slice(1).search(/\n\s+- name:/);
    return (end<0?part:part.slice(0,end+1)).match(/^\s+if:\s*(.*)$/m)?.[1]??'true';
}
function condition(expression,{pr,same,action='opened',failed=true,merged=true}){
    const values={
        "github.event_name == 'pull_request'":pr,
        'github.event.pull_request.head.repo.full_name == github.repository':same,
        "github.event.action == 'opened'":action==='opened',
        "github.event.action == 'synchronize'":action==='synchronize',
        "github.event.action == 'closed'":action==='closed',
        'github.event.pull_request.merged == true':merged,
        'github.event.pull_request.merged != true':!merged,
        'failure()':failed,
    };
    let boolean=expression;
    for(const [atom,value] of Object.entries(values))boolean=boolean.split(atom).join(String(value));
    assert.match(boolean,/^(?:true|false|[ ()!&|])+$/,`Unexpected expression ${expression}`);
    return Function(`return (${boolean})`)();
}
for(const name of ['Comment Health on PR','Comment Stress Test on PR','Critical State Notification']){
    const expression=stepCondition(brain,name);
    for(const {mask,expected} of vectors.notifications){
        assert.equal(Number(condition(expression,{pr:!!(mask&1),same:!!(mask&2)})),expected,`${name}: writable-PR mask${mask}`);
    }
}
for(const [name,action,merged] of [['Mark in progress','opened',false],['Mark completed on merge','closed',true],['Drop in-progress on a close without merge','closed',false]]){
    const expression=stepCondition(dev,name);
    for(const {mask,expected} of vectors.notifications){
        assert.equal(Number(!!(mask&1)&&condition(expression,{pr:!!(mask&1),same:!!(mask&2),action,merged})),expected,`${name}: writable-PR mask${mask}`);
    }
}
assert.match(brain,/BRAIN_HEALTH_THRESHOLD:\s*"80"/);
assert.match(brain,/zig build test-\$\{\{ matrix\.region \}\} -Dci=true --summary all/);
assert.match(brain,/zig build test-brain -Dci=true --summary all/);
assert.match(brain,/zig build test-brain-stress -Dci=true --summary all/);
assert.match(brain,/\.\/zig-out\/bin\/tri stress --health/);
const {gateVerdict}=await import('../scripts/ci-brain-gate.mjs');
const jobs=policy.BRAIN_JOBS.split(',');
for(const {mask,expected} of vectors.brain){
    for(const failed of ['failure','cancelled','skipped']){
        const results=Object.fromEntries(jobs.map((job,i)=>[job,{result:mask&(1<<i)?'success':failed}]));
        assert.equal(Number(gateVerdict(results).accepted),expected,`Brain mask${mask},${failed}`);
    }
}
assert.equal(gateVerdict({}).accepted,false);
for(const absent of jobs){
    const results=Object.fromEntries(jobs.filter(j=>j!==absent).map(j=>[j,{result:'success'}]));
    assert.equal(gateVerdict(results).accepted,false,`Missing ${absent}`);
}
const {checkModelEvidence}=await import('../scripts/docs-model-consistency.mjs');
const documentation=readFileSync(resolve(root,'docs/DOCUMENTATION_INDEX.md'),'utf8');
const files=new Set([policy.TJEPA_SOURCE,policy.TJEPA_TRAINER]);
assert.equal(checkModelEvidence({revision:policy.TRAINING_REV,files,documentation}),true);
assert.throws(()=>checkModelEvidence({revision:'0'.repeat(40),files,documentation}),/revision/);
assert.throws(()=>checkModelEvidence({revision:policy.TRAINING_REV,files:new Set([policy.TJEPA_SOURCE]),documentation}),/Missing/);
assert.throws(()=>checkModelEvidence({revision:policy.TRAINING_REV,files,documentation:'implemented locally'}),/Documentation/);
console.log('CI gate:68 consumed conformance vectors; fork-write, all six required phases and missing/cancelled/skipped regressions PASS');
