// The typecheck must not get worse. It is allowed to stay bad.
//
// `npm run build` used to be `tsc -b && vite build`, which was a lie in both
// directions: it never ran in the deploy path (Pages builds from the committed
// bundle), and it did not actually gate anything -- so 231 errors accumulated
// unseen. Among them, seven React branches whose conditions were statically
// false: a whole interactive panel that rendered nothing, in production, for
// as long as the annotation had been wrong.
//
// Deleting the typecheck would lose that signal. Fixing all 221 in one pass
// would be a rewrite. A ratchet keeps the signal and bounds the work: the
// count may fall, never rise. Lower it whenever it falls.
import { execSync } from 'node:child_process';
const BASELINE = 221;  // 2026-08-10, after the FormulaDiscoverySection Mode fix
let out = '';
try { out = execSync('npx tsc -b --pretty false', { encoding: 'utf8' }); }
catch (e) { out = (e.stdout || '') + (e.stderr || ''); }
const n = (out.match(/error TS\d+/g) || []).length;
if (n > BASELINE) {
  console.error(`\n  typecheck regressed: ${n} errors, baseline ${BASELINE}.`);
  console.error(out.split('\n').filter(l => l.includes('error TS')).slice(0, 15).join('\n'));
  process.exit(1);
}
if (n < BASELINE) console.log(`  ${n} errors — below the ${BASELINE} baseline. Lower it.`);
else console.log(`  ${n} errors — at baseline, not worse.`);
