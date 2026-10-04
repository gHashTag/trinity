#!/usr/bin/env node
// Measure what the t27 stack is written in, for the ROADMAP tab.
//
// The game's goal is one language: everything below the interface in .t27,
// generated to its target (law L0 PURPOSE, gHashTag/t27 docs/T27-CONSTITUTION.md
// section 2). A roadmap toward that is
// only honest if it starts from a count anyone can reproduce, so this reads the
// files git TRACKS in each repository that runs app.t27.ai, at a named commit,
// from GitHub's tree API - sizes without a checkout. The first version cloned
// all nine repositories and filled the laptop it ran on (2026-09-21: 255 MiB
// left); a count must not cost the machine that takes it.
//
// The unit is BYTES of source, the unit GitHub's own language statistics use.
// Vendored trees, build output, lockfiles and minified bundles are skipped:
// nobody writes them by hand, so nobody rewrites them.
//
//   GH_TOKEN=$(gh auth token) node scripts/roadmap-stack.mjs > public/roadmap/stack.json
//
// BrowserOS is counted only under trios/agent-server, the part deployed as
// api.t27.ai.

// What each repository IS in the running system, read from Railway's service
// records and the app's own nginx and Dockerfile on 2026-09-21.
const REPOS = [
  { repo: 'gHashTag/BrowserOS', ref: 'feat/queen-supervisor', sub: 'trios/agent-server', role: 'Queen and bees: scheduler, dispatch, reviews (api.t27.ai)' },
  { repo: 'gHashTag/999-multibots-telegraf', role: 'The app at app.t27.ai, the Telegram bot, render and gateway' },
  // zig-pkg/ is vendored dependencies (raylib alone is 17 MB of C), output/ is
  // generated, and the website's public/ holds copies of specs served as data.
  { repo: 'gHashTag/trinity', role: 'The Queen board (app.t27.ai/queen) and the Zig core', skip: /^(zig-pkg|trinity\/output|output)\/|(^|\/)public\// },
  { repo: 'gHashTag/t27', role: 'The language: t27c, the specs, the swarm’s tasks and tools' },
  { repo: 'gHashTag/trios', role: 'The macOS app and its Rust rings' },
  { repo: 'gHashTag/trios-railway', role: 'Railway service for trios' },
  { repo: 'gHashTag/t27-github-collab', role: 'GitHub collaboration service' },
  { repo: 'gHashTag/vibee-gleam', role: 'VIBEE API and Telegram bridge (Fly.io)' },
  // The Pages repo is a DEPLOY of the board: hashed bundles under assets/ and a
  // mirror of the specs under t27/. Counting them counted the board twice and
  // .t27 twice (measured 2026-09-21: 95 MB, 76% JavaScript). Only what is
  // written there by hand is counted.
  { repo: 'gHashTag/gHashTag.github.io', role: 'The site at t27.ai (a deploy of the board)', skip: /^(assets|t27)\// },
]

const LANGUAGE = {
  t27: 'T27',
  ts: 'TypeScript', tsx: 'TypeScript', mts: 'TypeScript', cts: 'TypeScript',
  js: 'JavaScript', jsx: 'JavaScript', mjs: 'JavaScript', cjs: 'JavaScript',
  py: 'Python', rs: 'Rust', zig: 'Zig', swift: 'Swift', go: 'Go',
  gleam: 'Gleam', erl: 'Erlang', ex: 'Elixir', exs: 'Elixir',
  c: 'C', h: 'C', cpp: 'C++', cc: 'C++', hpp: 'C++', m: 'Objective-C', mm: 'Objective-C',
  v: 'Verilog', sv: 'Verilog', vhd: 'VHDL', vhdl: 'VHDL',
  sh: 'Shell', bash: 'Shell', zsh: 'Shell', fish: 'Shell',
  sql: 'SQL', css: 'CSS', scss: 'CSS', html: 'HTML', vue: 'Vue', svelte: 'Svelte',
  kt: 'Kotlin', java: 'Java', rb: 'Ruby', php: 'PHP', lua: 'Lua', nix: 'Nix',
  toml: 'Config', yaml: 'Config', yml: 'Config',
}
const NAMED = { Dockerfile: 'Docker', Makefile: 'Make', Justfile: 'Make' }
const SKIP = /(^|\/)(node_modules|dist|build|out|target|vendor|third_party|\.next|coverage|__generated__|generated|zig-cache|\.zig-cache|zig-out|zig-pkg)\//
const SKIP_FILE = /(\.min\.(js|css)$)|(-lock\.(json|yaml)$)|(\.lock$)|(\.map$)/

const token = process.env.GH_TOKEN || process.env.GITHUB_TOKEN
async function gh(path) {
  const response = await fetch(`https://api.github.com${path}`, {
    headers: {
      accept: 'application/vnd.github+json',
      'user-agent': 'roadmap-stack',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
  })
  if (!response.ok) throw new Error(`GET ${path}: ${response.status}`)
  return response.json()
}

function languageOf(path) {
  const name = path.slice(path.lastIndexOf('/') + 1)
  if (NAMED[name]) return NAMED[name]
  const dot = name.lastIndexOf('.')
  if (dot <= 0) return null
  return LANGUAGE[name.slice(dot + 1).toLowerCase()] ?? null
}

const repos = []
for (const r of REPOS) {
  try {
    const meta = await gh(`/repos/${r.repo}`)
    const ref = r.ref ?? meta.default_branch
    const commit = (await gh(`/repos/${r.repo}/commits/${encodeURIComponent(ref)}`)).sha
    const tree = await gh(`/repos/${r.repo}/git/trees/${commit}?recursive=1`)
    const languages = {}
    for (const entry of tree.tree) {
      if (entry.type !== 'blob') continue
      const path = entry.path
      if (r.sub && !path.startsWith(`${r.sub}/`)) continue
      if (r.skip?.test(path)) continue
      if (SKIP.test(path) || SKIP_FILE.test(path)) continue
      const lang = languageOf(path)
      if (!lang || !entry.size) continue
      languages[lang] ??= { files: 0, bytes: 0 }
      languages[lang].files++
      languages[lang].bytes += entry.size
    }
    repos.push({ repo: r.repo, ref, sub: r.sub ?? null, role: r.role, commit, truncated: !!tree.truncated, languages })
    console.error(`counted ${r.repo}@${commit.slice(0, 7)}${tree.truncated ? ' (TRUNCATED by the API)' : ''}`)
  } catch (error) {
    console.error(`skipped ${r.repo}: ${error.message}`)
  }
}

const totals = {}
for (const r of repos) {
  for (const [lang, v] of Object.entries(r.languages)) {
    totals[lang] ??= { files: 0, bytes: 0 }
    totals[lang].files += v.files
    totals[lang].bytes += v.bytes
  }
}

process.stdout.write(
  `${JSON.stringify(
    {
      measuredAt: new Date().toISOString(),
      unit: 'bytes',
      method:
        'GitHub tree API at the named commit: every tracked file, by extension; vendored trees, build output, lockfiles and minified files excluded; Config, Docker and Make counted but never rewrite targets',
      repos,
      totals,
    },
    null,
    1,
  )}\n`,
)
