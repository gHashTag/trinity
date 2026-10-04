// The PASSPORT's figures must not drift from the PASSPORT's prose.
//
// The page argues that a result is worthless without the record of how it was
// taken. The failure mode that argument invites is a chart: a number gets
// corrected in a paragraph and left standing in a drawing, and the page then
// does the exact thing it accuses others of. This gate makes that impossible by
// construction — every quantity a figure plots carries the literal the prose
// prints for it, and the literal is checked against the prose here, in both
// languages.
//
// It also pins the survey's shape. The seven-record matrix is a claim about
// other people's published work; if a cell moves, the totals and the sentences
// that quote them have to move deliberately, not silently.
//
// Node 22 needs --experimental-strip-types to import the TypeScript modules.

import { readFileSync } from "node:fs";
import { cases, record, marked, questions, anchorNote, meta, standing, MARK } from "../src/content/passport.ts";
import { axes, plotted, area } from "../src/content/passportExamples.ts";
import { systems, coverage, tally, blindSpots, survey, limits } from "../src/content/passportRecords.ts";

const fails = [];
let checks = 0;
const check = (cond, msg) => { checks += 1; if (!cond) fails.push(msg); };

const page = readFileSync(new URL("../src/pages/Passport.tsx", import.meta.url), "utf8");
const figs = readFileSync(new URL("../src/components/PassportFigures.tsx", import.meta.url), "utf8");

// ---- 1. Every plotted number is still the number the prose prints -----------
// Scoped to the case prose, because that is where these quantities are stated;
// matching against the whole file would let a comment keep a figure alive.
const proseEn = cases.flatMap((c) => [c.title.en, c.setup.en, c.finding.en, c.moral.en]).join("  ");
const proseRu = cases.flatMap((c) => [c.title.ru, c.setup.ru, c.finding.ru, c.moral.ru]).join("  ");

const quantities = [
  ...plotted.flatMap((p) => [[`case ${p.case} metric`, p.metricSE], [`case ${p.case} artifact`, p.artifactPct]]),
  ["case 3 LUTs, implementation 1", area.lut.a],
  ["case 3 LUTs, implementation 2", area.lut.b],
  ["case 3 LUT ratio", area.lut.ratio],
  ["case 3 DSP48, implementation 1", area.dsp.a],
  ["case 3 DSP48, implementation 2", area.dsp.b],
];
for (const [what, q] of quantities) {
  check(proseEn.includes(q.print), `${what}: the figure plots "${q.print}" and the English prose no longer says it`);
  check(proseRu.includes(q.printRu ?? q.print), `${what}: the figure plots "${q.printRu ?? q.print}" and the Russian prose no longer says it`);
}
// A value of 0 must be zero by measurement, not by an empty string parsing as one.
check(plotted[0].artifactPct.value === 0 && plotted[0].artifactPct.print !== "0", "case 1's artifact separation is zero because the weights were one file, and says so in words");
check(plotted.every((p) => p.metricSE.value <= axes.metric.max && p.artifactPct.value <= axes.artifact.max), "every plotted point fits inside the axes it is drawn against");

// ---- 2. The table's footing is read off the table ---------------------------
const surviving = record.filter((r) => r.anchoredTo.some((a) => a !== "withdrawn")).length;
const onlyWithdrawn = record.filter((r) => r.anchoredTo.length > 0 && r.anchoredTo.every((a) => a === "withdrawn")).length;
check(marked.fields === record.length && marked.fields === 14, "fourteen fields, counted from the array and not typed beside it");
check(marked.measured === surviving && marked.measured === 5, "five fields rest on a case that still stands");
check(marked.onWithdrawn === onlyWithdrawn && marked.onWithdrawn === 1, "one field rests only on the count this document withdrew");
check(marked.measured + marked.onWithdrawn === 6, "six fields are marked in total — the sent document says four, and that is the defect this derivation exists to prevent");
check(record.every((r) => r.anchoredTo.every((a) => ["1", "2", "3", "withdrawn"].includes(a))), "every anchor names a case that exists");
for (const q of [questions[1].en, questions[1].ru]) {
  check(q.includes(String(marked.fields)) && q.includes(String(marked.measured)) && q.includes(String(marked.onWithdrawn)), "the open question quotes the derived counts, in both languages");
}
check(anchorNote.en.includes(MARK.onWithdrawn) && anchorNote.ru.includes(MARK.onWithdrawn), "the note explains the second mark, in both languages");
check(MARK.anchored !== MARK.onWithdrawn, "the two marks are two different glyphs");
check(/onWithdrawn \? MARK\.onWithdrawn : MARK\.anchored/.test(page), "the table renders the two marks apart, reading both from MARK");

// The defect this pair exists to stop, and the reason MARK is a constant at all:
// the sent document's open question called the withdrawn-anchor field †, while
// the table drew ‡ for it and the note underneath said that row is counted apart
// from the † rows. Prose contradicting its own table, in a document whose thesis
// is that prose must not. Typing the glyph anywhere but MARK lets it happen again.
for (const [lang, q] of [["English", questions[1].en], ["Russian", questions[1].ru]]) {
  check(q.includes(MARK.onWithdrawn), `${lang}: the open question gives the withdrawn-anchor field its own mark, not †`);
  const anchoredMarks = q.split(MARK.anchored).length - 1;
  check(anchoredMarks === 2, `${lang}: † appears for the ${marked.measured} anchored fields and once to say the sixth is not one of them`);
}
check(!page.includes(`'${MARK.anchored}'`) && !page.includes(`'${MARK.onWithdrawn}'`), "the page types neither glyph as a literal");

// ---- 3. The survey matrix lines up with the table it tests ------------------
check(coverage.length === record.length, `the matrix has ${coverage.length} rows for ${record.length} fields`);
check(coverage.every((row) => row.length === systems.length), "every row has one cell per surveyed record");
check(coverage.every((row) => row.every((c) => ["stated", "partial", "absent"].includes(c))), "every cell is one of the three verdicts");
check(tally.cells === 98 && tally.stated === 5 && tally.partial === 65 && tally.absent === 28, `the survey found 5 / 65 / 28 of 98; it now reads ${tally.stated} / ${tally.partial} / ${tally.absent} of ${tally.cells}`);
check(tally.stated + tally.partial + tally.absent === tally.cells, "the three verdicts account for every cell");
check(tally.unchecked === 0, "no cell was left unchecked; if one is, the figure must stop claiming otherwise");

// The finding the page turns on: the control is the only column with no gaps,
// and it is still not a column of stated fields. Both halves of that sentence
// are load-bearing, so both are pinned.
const controls = systems.filter((s) => s.control);
check(controls.length === 1, "exactly one record is the control");
const absentByCol = systems.map((_, i) => coverage.filter((row) => row[i] === "absent").length);
const clean = absentByCol.map((n, i) => (n === 0 ? i : -1)).filter((i) => i >= 0);
check(clean.length === 1 && systems[clean[0]].control === true, "the control is the only record with no absent field — the page's claim that half this document has no standard to catch up to rests on exactly this");
const controlStated = coverage.filter((row) => row[systems.indexOf(controls[0])] === "stated").length;
check(controlStated === 2, `the control states 2 of 14 fields, not more; it now states ${controlStated}`);

// ---- 4. The banded rows are the rows that are actually empty ----------------
const nearEmpty = coverage.map((row, i) => (row.filter((c) => c === "absent").length >= 4 ? i : -1)).filter((i) => i >= 0);
check(JSON.stringify(nearEmpty) === JSON.stringify([...blindSpots]), `the banded rows must be the near-empty ones; empty rows are [${nearEmpty}] and the band marks [${blindSpots}]`);
check(blindSpots.every((i) => i >= 0 && i < record.length), "every banded row indexes a real field");

// ---- 5. Every surveyed record is checkable by the reader --------------------
for (const s of systems) {
  check(/^https:\/\/\S+$/.test(s.url), `${s.label}: needs a resolvable https source, not "${s.url}"`);
  check(s.source.en.length > 10 && s.source.ru.length > 10, `${s.label}: names where the record was read, in both languages`);
  check(page.includes("target=\"_blank\"") && page.includes("s.url"), "the page links each source out");
}

// ---- 6. Nothing ships half-translated ---------------------------------------
const bilingual = (node, path, seen = new Set()) => {
  if (!node || typeof node !== "object" || seen.has(node)) return;
  seen.add(node);
  const keys = Object.keys(node);
  if (keys.length === 2 && keys.includes("en") && keys.includes("ru")) {
    check(typeof node.en === "string" && node.en.trim().length > 0, `${path}: English is empty`);
    check(typeof node.ru === "string" && node.ru.trim().length > 0, `${path}: Russian is empty`);
    return;
  }
  for (const [k, v] of Object.entries(node)) bilingual(v, `${path}.${k}`, seen);
};
bilingual({ axes, plotted, area }, "passportExamples");
bilingual({ systems, survey, limits }, "passportRecords");

// ---- 7. The figures are mounted, not merely written -------------------------
for (const f of ["FigureSeparation", "FigureArea", "FigureFooting", "FigureCoverage"]) {
  check(figs.includes(`export function ${f}`), `${f} is defined`);
  check(new RegExp(`<${f}\\s`).test(page), `${f} is rendered on the page — an unmounted figure is a file, not a figure`);
}
// No figure may carry a quantity of its own: the drawings interpolate from the
// content modules, and a bare decimal in the SVG would mean someone typed one.
check(/import \{ meta, record, standing, type Bi \} from '\.\.\/content\/passport'/.test(figs), "the figures read the record, not a copy of it");
check(/import \{ systems, coverage, tally, blindSpots/.test(figs), "the matrix reads the survey, not a copy of it");

// ---- 8. The refuted sentence stays refuted ----------------------------------
// The survey once concluded, from a control of one, that four fields had no
// standard to catch up to. A later sweep found a requirement for all four. The
// page carries that correction; this keeps the original from creeping back and
// keeps the correction from being deleted along with the embarrassment.
{
  const all = [...survey.flatMap((s) => [s.h.en, s.h.ru, s.b.en, s.b.ru]), figs].join("  ");
  const correction = survey[survey.length - 1];
  check(survey.length === 5, `the survey carries its correction as a block of its own; it has ${survey.length}`);
  check(/correction/i.test(correction.h.en) && /оправк/i.test(correction.h.ru), "the last block says it is a correction, in both languages");
  for (const cited of ["model-info.json", "NeurIPS", "SPECpower_ssj2008", "ACM"]) {
    check(correction.b.en.includes(cited), `the correction names ${cited}, so a reader can go and check it`);
  }
  check(/first-hand/.test(correction.b.en) && /прочитал сам/.test(correction.b.ru), "the correction separates what was read from what was taken off a search result — two of the four were not opened");
  // Everywhere else, including inside the figure captions.
  const claimEn = all.split(correction.b.en).join(" ");
  const claimRu = all.split(correction.b.ru).join(" ");
  check(!/no (existing )?standard to catch up to/i.test(claimEn), "the refuted sentence is not restated anywhere outside the correction");
  check(!/догонять нечего/i.test(claimRu), "the refuted sentence is not restated in Russian outside the correction");
}

// ---- 9. Figure 1's two text bands do not land on the same baseline ----------
// Found by looking at it: the x-axis title was drawn at Y1+40 and the case
// glosses began at 356, and Y1 is 318 — so the title was printed through the
// first gloss. Nothing above could catch it, because both strings were correct.
{
  const y1 = Number(/const X0 = \d+, X1 = \d+, Y0 = \d+, Y1 = (\d+)/.exec(figs)?.[1]);
  const title = Number(/y=\{Y1 \+ (\d+)\} textAnchor="middle" fontSize="12" fill=\{INK\}/.exec(figs)?.[1]);
  const gloss = Number(/y=\{(\d+) \+ i \* (?:19)\} fontSize="11\.5"/.exec(figs)?.[1]);
  const box = Number(/export function FigureSeparation[\s\S]*?\n  const H = (\d+)/.exec(figs)?.[1]);
  check(Number.isFinite(y1) && Number.isFinite(title) && Number.isFinite(gloss) && Number.isFinite(box), "figure 1's layout constants are still readable from the source");
  check(gloss - (y1 + title) >= 12, `figure 1: the glosses start at ${gloss} and the axis title sits at ${y1 + title} — they must not share a line`);
  check(box - (gloss + 19) >= 10, `figure 1: the last gloss baseline is ${gloss + 19} and the plot ends at ${box} — descenders would be clipped`);
}

// ---- 10. Every plate carries its standing inside the frame ------------------
// The caption does not travel. A plate gets dragged into a slide deck and the
// figcaption stays behind, and what is left is a chart that looks like a
// finished result. Both facts that stop that misreading -- this is proposed and
// not approved, and the cases are not neuromorphic -- must be inside the SVG,
// and must be interpolated from content rather than typed into the drawing,
// because a retyped standing is exactly the drift this whole gate exists for.
{
  const stampH = Number(/const STAMP_H = (\d+)/.exec(figs)?.[1]);
  const stamps = figs.match(/<FigureStamp lang=\{lang\} y=\{H\} \/>/g) ?? [];
  const boxes = figs.match(/viewBox=\{`0 0 700 \$\{H \+ STAMP_H\}`\}/g) ?? [];
  check(figs.includes("function FigureStamp("), "the stamp is a component, so there is one of it and not four");
  check(stamps.length === 4, `all four plates are stamped; ${stamps.length} are`);
  check(boxes.length === 4, `all four plates make room for the band they stamp into; ${boxes.length} do`);
  check(Number.isFinite(stampH) && stampH >= 40, `the band is ${stampH} units — two 9.5pt lines and a rule do not fit in less`);
  check(/\{pick\(meta\.status, lang\)\}/.test(figs), "the stamp prints meta.status, so a change of standing reaches the plates");
  check(/\{pick\(standing\[0\]\.h, lang\)\}/.test(figs), "the stamp prints the first standing limit, the one that says these cases are not neuromorphic");
  check(/\{meta\.submitted\}/.test(figs), "the stamp dates the plate — a loose figure with no date is undatable");
  for (const literal of [meta.status.en, meta.status.ru, standing[0].h.en, standing[0].h.ru]) {
    check(!figs.includes(literal), `"${literal.slice(0, 40)}..." is interpolated, not retyped into the drawing`);
  }
  check(standing[0].h.en === "The cases are not neuromorphic", `standing limit 1 is still the transfer limit; it now reads "${standing[0].h.en}" and the stamp would be quoting the wrong one`);
}

// ---- 11. The plates and the prose are the same colour -----------------------
// The figures hard-code GOLD; the stylesheet asked for var(--accent, #d4af37).
// Those were two different colours for as long as the figures existed, because
// index.css sets --accent to green on :root and a fallback only fires when the
// variable is undefined. Nothing could catch it: both files were internally
// consistent and neither named the other. So name them here, together.
{
  const css = readFileSync(new URL("../src/pages/passport.css", import.meta.url), "utf8");
  const svgGold = /const GOLD = '(#[0-9a-fA-F]{6})'/.exec(figs)?.[1];
  const declared = [...css.matchAll(/--accent: (#[0-9a-fA-F]{6});/g)].map((m) => m[1]);
  const scoped = /\.pp \{[^}]*--accent: (#[0-9a-fA-F]{6});[^}]*\}/.exec(css)?.[1];
  const fallbacks = [...css.matchAll(/var\(--accent, (#[0-9a-fA-F]{6})\)/g)].map((m) => m[1]);
  check(svgGold === "#d4af37", `the plates draw in gold; they now draw ${svgGold}`);
  check(declared.length === 1, `--accent is declared once in this stylesheet, on .pp; it is declared ${declared.length} times`);
  check(scoped === svgGold, `.pp sets --accent to ${scoped} and the plates draw ${svgGold} — one page, one accent`);
  check(fallbacks.length > 0 && fallbacks.every((f) => f === svgGold), `every var(--accent, …) fallback names ${svgGold}; they name ${[...new Set(fallbacks)].join(", ")}`);

  // A plate is 700 viewBox units wide and asks for 40rem so its 11-unit labels
  // stay legible, which only works if the box it sits in is allowed to scroll.
  // .pp-sec is a flex container, so every child defaults to min-width: auto and
  // refuses to shrink; the page then takes the sideways scroll instead. Naming
  // .pp-scroll and .pp-fig was not enough -- figures 1 and 2 are wrapped with
  // their case, and the wrapper was the flex item. The audit that would catch
  // this needs a Chrome binary this machine does not have, so pin the rule.
  check(/\.pp-sec > \*,\n\.pp-scroll,\n\.pp-fig \{ min-width: 0; max-width: 100%; \}/.test(css), "every child of .pp-sec may shrink — a named subset of them was the bug, not the fix");
  check(/\.pp-fig-plate \{ overflow-x: auto; \}/.test(css), "the plate is the box that scrolls; without it min-width on the svg just widens the page");
  check(/\.pp-fig-plate svg \{[^}]*min-width: 40rem/.test(css), "the plate keeps the drawing at a legible width rather than scaling 700 units into 269px");
}

// self-test: the contract must be able to fail
check(coverage.flat().filter((c) => c === "absent").length !== 0, "self-test");

if (fails.length) { for (const f of fails) console.log("  ✗ " + f); console.log(`Passport figures contract: FAIL (${fails.length})`); process.exit(1); }
console.log(`Passport figures contract: PASS (${checks} checks)`);
