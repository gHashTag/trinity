import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { SITE, loadCompiler, constsOf, checkSchema, compilerErrors, verdictOf, sha256 } from './agents-from-specs.mjs';
import { runSpecTests } from './viewport-from-spec.mjs';
const source = 'public/t27/files/specs/ui/queen_evidence.t27';
const output = 'src/lib/queenEvidence.generated.ts';
const text = readFileSync(join(SITE, source), 'utf8');
const analyze = await loadCompiler(readFileSync(join(SITE, 'public/t27/t27_compiler.wasm')));
const analysis = analyze(text), verdict = verdictOf(analysis);
if (compilerErrors(analysis).length || !verdict.typecheckOk || !verdict.hirOk || verdict.discarded) throw new Error('Evidence spec compiler rejected input');
const constants = constsOf(analysis);
const schema = { REPO:'str', DATE:'str', MERGE:'str', REPORT_PATH:'str', RUNS:'u32', VALUES_PER_RUN:'u32', VALUES_TOTAL:'u32', CLOCK_HZ:'u32', COMPUTE_CLOCKS:'u32', TOTAL_CLOCKS:'u32', MEMORY_CLOCKS:'u32', REPORT_CLOCKS:'u32', SCAN_DATE:'str', SCAN_REPOSITORIES:'u32', SCAN_MODELS:'u32', SCAN_FILES:'u32', LIVE_URL:'str', LEVELS:'arr' };
const problems = checkSchema(constants, schema, {}, source);
if (problems.length || analysis.ast?.name !== 'ui_queen_evidence' || /[^\x00-\x7f]/.test(text)) throw new Error(`Invalid evidence spec: ${problems.join('; ')}`);
const fields = Object.fromEntries(Object.entries(constants).map(([key, value]) => [key, value.value]));
const tests = runSpecTests(analysis, fields);
if (!tests.tests || tests.failures.length) throw new Error(JSON.stringify(tests));
for (const [key, value] of Object.entries(fields)) {
  if (key.endsWith('CLOCKS') || key.startsWith('VALUES_') || key === 'RUNS' || key === 'CLOCK_HZ' || /^SCAN_(REPOSITORIES|MODELS|FILES)$/.test(key)) {
    if (!Number.isSafeInteger(value) || value <= 0) throw new Error(`Invalid count: ${key}`);
  }
}
if (!/^[a-f0-9]{40}$/.test(fields.MERGE)) throw new Error('Evidence requires a full commit SHA');
const generated = `// GENERATED from ${source}; sha256 ${sha256(Buffer.from(text))}\n// Run node scripts/queen-evidence-from-spec.mjs; do not edit by hand.\nexport const queenEvidence = ${JSON.stringify(fields, null, 2)} as const;\n`;
if (process.argv.includes('--check')) {
  if (readFileSync(join(SITE, output), 'utf8') !== generated) throw new Error('Stale Queen evidence');
} else writeFileSync(join(SITE, output), generated);
console.log(`Queen evidence: ${tests.tests} spec tests, ${tests.asserts} assertions passed; output ${process.argv.includes('--check') ? 'current' : 'written'}`);
