/**
 * The specs a course teaches from: every path in a specs/course/*.t27
 * LESSON_SPECS, relative to public/t27/files.
 *
 * The world scan (sync-t27-specs.mjs) rebuilds public/t27/files from the
 * scanned repositories and wipes the rest. A course pins the bytes it
 * teaches, and on 2026-10-08 that cost the site its publisher: the scan
 * (#1535) deleted the 33 lesson specs that live nowhere but here (basics/,
 * part of fpga/) and replaced seven lesson versions of t27 specs with
 * t27 master's, which this site's compiler does not read clean. The course
 * check refused all 47, and t27.ai stopped taking new builds.
 *
 * The scan now carries these files across its wipe (scripts/sync-t27-specs.mjs).
 * A scanned copy still wins when it is teachable -- t27's newer version of a
 * lesson spec should reach the lesson -- and the course keeps its own copy only
 * where the scan brought nothing or something a lesson cannot show.
 */
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { verdictOf } from './agents-from-specs.mjs'

/** Every backend a lesson spec must print; course-from-spec checks the same list. */
export const LESSON_BACKENDS = ['c', 'js', 'rust', 'ts', 'verilog', 'verilog_hir', 'zig']

/** What course-from-spec --check calls clean: typechecks, nothing discarded, every backend prints. */
export function teachable(analysis) {
  if (!analysis) return false
  const v = verdictOf(analysis)
  return v.typecheckOk && !v.errors && !v.discarded && v.hirOk && LESSON_BACKENDS.every((b) => analysis.targets?.[b]?.ok)
}

const DECL = /\bLESSON_SPECS\s*:\s*\[\d*\]\s*str\s*=\s*\[([^\]]*)\]/

/** Paths named by one course spec's LESSON_SPECS, in its order. */
export function lessonSpecsOf(text) {
  const m = DECL.exec(text)
  return m ? [...m[1].matchAll(/"([^"]+)"/g)].map((x) => x[1]) : []
}

/** Every lesson spec of every course in `courseDir`, once each, sorted. */
export function lessonSpecPaths(courseDir) {
  const paths = new Set()
  for (const name of readdirSync(courseDir).filter((n) => n.endsWith('.t27')).sort())
    for (const p of lessonSpecsOf(readFileSync(join(courseDir, name), 'utf8'))) paths.add(p)
  return [...paths].sort()
}
