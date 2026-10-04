#!/usr/bin/env node
// tri-help-casts.mjs -- record `tri <command> --help` for every command of one tri, as asciicast v2.
//
// Meant for CI (.github/workflows/tri-help-casts.yml), not a laptop: one process per command, hundreds of
// them. For each command of qa/tri-commands/<cli>.json it runs `<bin> <name> --help` with no secrets in the
// environment and a per-command timeout, and writes <out>/<id>/session.cast + meta.json in the shape
// termgif.py publish leaves under public/term/<id>/ (commands, exit_codes), plus <out>/index.json.
//
// It publishes nothing. A recording reaches a card only after a person copies it under public/term/,
// runs `termgif.py check` on it and regenerates the cards; the generators then attach it to a card only
// when the command name belongs to one tri alone (meta.json does not say which binary ran), and
// agents-from-specs refuses any CAST whose exit code is not 0. index.json lists which runs could go.
// Staged: the prompt and the typing. Real: every byte the command printed, at the time it printed it.
//
// Run:  node scripts/tri-help-casts.mjs --cli t27|trinity|trios --bin PATH --out DIR [--only a,b] [--timeout-ms 20000]
import { spawn } from 'node:child_process'
import { mkdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { CLIS, readSnapshot } from './tri-commands.mjs'

const TYPE_STEP_S = 0.04
const WIDTH = 100
const HEIGHT = 30

export const castId = (cli, name) => `help-${cli}-${name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '')}`

// The environment a recorded command sees: PATH and locale only, so no token of the runner reaches it.
export function bareEnv(env = process.env) {
  const keep = ['PATH', 'LANG', 'LC_ALL']
  const out = Object.fromEntries(keep.filter((k) => env[k] !== undefined).map((k) => [k, env[k]]))
  return { ...out, HOME: '/tmp/tri-help-home', TERM: 'xterm-256color', COLUMNS: String(WIDTH), LINES: String(HEIGHT), NO_COLOR: '1' }
}

// Staged prompt and typing, then the real output events and the exit event, as asciicast v2 lines.
export function castLines({ title, command, chunks, exit, timestamp }) {
  const header = { version: 2, width: WIDTH, height: HEIGHT, timestamp, title, commands: [command] }
  const events = [[0, 'o', '$ ']]
  let t = 0.3
  for (const ch of command) { events.push([Number(t.toFixed(4)), 'o', ch]); t += TYPE_STEP_S }
  events.push([Number(t.toFixed(4)), 'o', '\r\n'])
  const start = t + 0.1
  let last = start
  for (const c of chunks) { last = Number((start + c.at).toFixed(4)); events.push([last, 'o', c.text.replace(/\r?\n/g, '\r\n')]) }
  events.push([Number((last + 0.05).toFixed(4)), 'x', String(exit)])
  return [JSON.stringify(header), ...events.map((e) => JSON.stringify(e))].join('\n') + '\n'
}

function runOne(bin, name, timeoutMs) {
  return new Promise((resolve) => {
    const t0 = process.hrtime.bigint()
    const at = () => Number(process.hrtime.bigint() - t0) / 1e9
    const chunks = []
    const child = spawn(bin, [name, '--help'], { env: bareEnv(), stdio: ['ignore', 'pipe', 'pipe'] })
    const take = (buf) => chunks.push({ at: at(), text: buf.toString('utf8') })
    child.stdout.on('data', take)
    child.stderr.on('data', take)
    const timer = setTimeout(() => child.kill('SIGKILL'), timeoutMs)
    child.on('error', (e) => { clearTimeout(timer); resolve({ chunks: [{ at: at(), text: `${e.message}\n` }], exit: 'spawn-error', real: at() }) })
    child.on('close', (code, signal) => {
      clearTimeout(timer)
      const timedOut = signal === 'SIGKILL'
      resolve({ chunks, exit: timedOut ? 'timeout' : String(code ?? signal), real: at() })
    })
  })
}

async function main() {
  const arg = (k) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : undefined }
  const cli = arg('--cli'), bin = arg('--bin'), out = arg('--out')
  const timeoutMs = Number(arg('--timeout-ms') ?? 20000)
  const onlyList = (arg('--only') ?? '').split(',').filter(Boolean)
  const only = onlyList.length > 0 ? onlyList : null
  const argsOk = Boolean(CLIS[cli]) && Boolean(bin) && Boolean(out)
  if (!argsOk) { console.error('usage: tri-help-casts.mjs --cli t27|trinity|trios --bin PATH --out DIR [--only a,b] [--timeout-ms N]'); process.exit(2) }
  const snap = readSnapshot(cli)
  const commands = snap.commands.filter((c) => !only || only.includes(c.name))
  const index = []
  for (const c of commands) {
    const id = castId(cli, c.name)
    const command = `tri ${c.name} --help`
    const r = await runOne(bin, c.name, timeoutMs)
    const title = `${command} (${snap.repo}@${snap.commit.slice(0, 12)})`
    const recorded = new Date().toISOString().replace('T', ' ').slice(0, 16) + ' UTC'
    const dir = join(out, id)
    mkdirSync(dir, { recursive: true })
    writeFileSync(join(dir, 'session.cast'), castLines({ title, command, chunks: r.chunks, exit: r.exit, timestamp: Math.floor(Date.now() / 1000) }))
    const meta = {
      id, title,
      desc: `The --help output of \`tri ${c.name}\`, recorded in CI from ${snap.repo}@${snap.commit.slice(0, 12)}.`,
      url: `https://t27.ai/term/${id}/`,
      recorded, real_s: Number(r.real.toFixed(1)), shown_s: Number(r.real.toFixed(1)),
      commands: [command], exit_codes: [r.exit], redacted: [],
      cli, repo: snap.repo, commit: snap.commit,
      recordedBy: 'apps/website/scripts/tri-help-casts.mjs (.github/workflows/tri-help-casts.yml)',
    }
    writeFileSync(join(dir, 'meta.json'), JSON.stringify(meta, null, 2) + '\n')
    const publishable = r.exit === '0'
    index.push({ id, command, exit: r.exit, publishable })
    console.log(`${publishable ? 'ok  ' : 'skip'} ${id} exit ${r.exit}`)
  }
  writeFileSync(join(out, 'index.json'), JSON.stringify({ cli, repo: snap.repo, commit: snap.commit, recorded: index.length, publishable: index.filter((x) => x.publishable).length, runs: index }, null, 2) + '\n')
  console.log(`tri-help-casts: ${index.length} recorded for ${cli}, ${index.filter((x) => x.publishable).length} exited 0`)
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main()
