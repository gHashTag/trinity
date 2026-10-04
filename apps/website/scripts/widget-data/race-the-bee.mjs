#!/usr/bin/env node
// race-the-bee.mjs -- snapshot of who lands patches on gHashTag/t27: the Queen's bees or a person.
//
// Writes public/widgets/race-the-bee/data.json, which the widget reads; the page itself makes no
// call to GitHub. Every number on the page comes from this file, and this file comes from
// `gh api graphql` GETs at the time stamped in `snapshotAt`. Run it again to refresh.
//
// THE RULE, stated once (the spec repeats it as K_RULE_* for the page):
//   bee   = a pull request whose head branch is `queen-<N>`. Those branches are written by a bee
//           the Queen dispatched and published by tools/queen/publish.py in gHashTag/t27.
//   human = every other pull request. A person opened the session; that person may well have
//           used an AI assistant (claude/ and codex/ branches), so "human" means human-steered,
//           not hand-typed.
//
// WHAT IS MEASURED
//   lanes:     merged PRs in the window that close a gHashTag/t27 issue, split by the rule, with
//              hours from the issue being opened to the PR being merged.
//   contested: closed issues in the window that had PRs from BOTH lanes (merged or not) -- the
//              only thing in the data that resembles a race.
//   open:      open issues with a `## Boundary` section (the Queen's own rule, needs_boundary.py),
//              so a bee could be dispatched to them too, with no open PR closing them. For each,
//              whether a `queen-<N>` branch already exists on the remote (a bee has started).
//
// Usage: node scripts/widget-data/race-the-bee.mjs [--days 7] [--open 12]
import { execFileSync } from 'node:child_process'
import { mkdirSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const REPO = 'gHashTag/t27'
const [OWNER, NAME] = REPO.split('/')
const SITE = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const OUT = join(SITE, 'public/widgets/race-the-bee/data.json')
const BEE_BRANCH = /^queen-(\d+)$/
const BOUNDARY = /^##[ \t]+(Boundary|\u0413\u0440\u0430\u043d\u0438\u0446\u044b)/m

const arg = (name, dflt) => {
  const i = process.argv.indexOf(name)
  return i > 0 ? Number(process.argv[i + 1]) : dflt
}
const DAYS = arg('--days', 7)
const OPEN_SHOWN = arg('--open', 12)

const gh = (args) => JSON.parse(execFileSync('gh', args, { encoding: 'utf8', timeout: 180000, maxBuffer: 80 * 1024 * 1024 }))
const graphql = (query, vars) => gh(['api', 'graphql', '-f', `query=${query}`, ...Object.entries(vars).flatMap(([k, v]) => ['-F', `${k}=${v}`])]).data

export const laneOf = (headRefName) => (BEE_BRANCH.test(headRefName) ? 'bee' : 'human')
const hours = (from, to) => Math.round(((Date.parse(to) - Date.parse(from)) / 3600000) * 10) / 10
const median = (xs) => {
  if (!xs.length) return null
  const s = [...xs].sort((a, b) => a - b)
  const m = s.length >> 1
  return s.length % 2 ? s[m] : Math.round(((s[m - 1] + s[m]) / 2) * 10) / 10
}
const ascii = (s) => String(s).replace(/[^\x20-\x7e]/g, '?')

const PR_FIELDS = `number title headRefName createdAt mergedAt closedAt state url
  author { login }
  closingIssuesReferences(first: 5) { nodes { number title createdAt closedAt url repository { nameWithOwner } } }`

function searchPrs(q) {
  const out = []
  let after = null
  for (;;) {
    const d = graphql(`query($q: String!, $after: String) { search(query: $q, type: ISSUE, first: 100, after: $after) {
      issueCount pageInfo { hasNextPage endCursor } nodes { ... on PullRequest { ${PR_FIELDS} } } } }`, after ? { q, after } : { q })
    out.push(...d.search.nodes)
    if (!d.search.pageInfo.hasNextPage) break
    after = d.search.pageInfo.endCursor
  }
  return out
}

/** Search caps at 1000 results, so the window is walked one day at a time. */
function prsClosedSince(sinceIso, untilIso) {
  const seen = new Map()
  for (let t = Date.parse(sinceIso); t < Date.parse(untilIso); t += 86400000) {
    const a = new Date(t).toISOString().slice(0, 10)
    for (const pr of searchPrs(`repo:${REPO} is:pr is:closed closed:${a}..${a}`)) seen.set(pr.number, pr)
  }
  return [...seen.values()]
}

function openPrs() {
  const out = []
  let after = null
  for (;;) {
    const d = graphql(`query($o: String!, $n: String!, $after: String) { repository(owner: $o, name: $n) {
      pullRequests(states: OPEN, first: 100, after: $after) { pageInfo { hasNextPage endCursor } nodes { ${PR_FIELDS} } } } }`,
    after ? { o: OWNER, n: NAME, after } : { o: OWNER, n: NAME })
    const p = d.repository.pullRequests
    out.push(...p.nodes)
    if (!p.pageInfo.hasNextPage) break
    after = p.pageInfo.endCursor
  }
  return out
}

function openIssues() {
  const out = []
  let after = null
  for (;;) {
    const d = graphql(`query($o: String!, $n: String!, $after: String) { repository(owner: $o, name: $n) {
      issues(states: OPEN, first: 100, after: $after, orderBy: { field: CREATED_AT, direction: DESC }) {
        pageInfo { hasNextPage endCursor } nodes { number title createdAt url body labels(first: 20) { nodes { name } } } } } }`,
    after ? { o: OWNER, n: NAME, after } : { o: OWNER, n: NAME })
    const p = d.repository.issues
    out.push(...p.nodes)
    if (!p.pageInfo.hasNextPage) break
    after = p.pageInfo.endCursor
  }
  return out
}

function beeBranches() {
  const refs = gh(['api', '--paginate', `repos/${REPO}/git/matching-refs/heads/queen-`, '--jq', '[.[].ref]'])
  // --paginate with --jq prints one array per page; gh joins them as separate JSON values.
  return new Set((Array.isArray(refs) ? refs.flat() : []).map((r) => r.replace('refs/heads/', '')))
}

function main() {
  const snapshotAt = new Date().toISOString().replace(/\.\d+Z$/, 'Z')
  const since = new Date(Date.parse(snapshotAt) - DAYS * 86400000).toISOString().replace(/\.\d+Z$/, 'Z')
  const closed = prsClosedSince(since, snapshotAt)
  const own = (i) => i.repository.nameWithOwner === REPO

  // Lanes: merged PRs in the window that close an issue of this repository.
  const landed = []
  for (const pr of closed) {
    if (!pr.mergedAt || Date.parse(pr.mergedAt) < Date.parse(since)) continue
    const issue = pr.closingIssuesReferences.nodes.find(own)
    if (!issue) continue
    landed.push({
      pr: pr.number, prUrl: pr.url, issue: issue.number, issueUrl: issue.url, title: ascii(issue.title).slice(0, 110),
      lane: laneOf(pr.headRefName), branch: ascii(pr.headRefName), author: pr.author?.login ?? 'ghost',
      issueOpened: issue.createdAt, merged: pr.mergedAt,
      hoursIssueToMerge: hours(issue.createdAt, pr.mergedAt), hoursPrToMerge: hours(pr.createdAt, pr.mergedAt),
    })
  }
  landed.sort((a, b) => Date.parse(b.merged) - Date.parse(a.merged))
  const lane = (l) => {
    const rows = landed.filter((r) => r.lane === l)
    return {
      merged: rows.length,
      medianHoursIssueToMerge: median(rows.map((r) => r.hoursIssueToMerge)),
      medianHoursPrToMerge: median(rows.map((r) => r.hoursPrToMerge)),
      authors: [...new Set(rows.map((r) => r.author))].sort(),
      // Workload context: machine-filed "Port <file> ... to specs/port/..." tasks are most of a bee's day.
      portTasks: rows.filter((r) => /^Port /.test(r.title)).length,
    }
  }

  // Contested: an issue with PRs from both lanes among the PRs closed in the window and the open ones.
  const opens = openPrs()
  const byIssue = new Map()
  for (const pr of [...closed, ...opens]) {
    for (const i of pr.closingIssuesReferences.nodes.filter(own)) {
      const e = byIssue.get(i.number) ?? { issue: i.number, issueUrl: i.url, title: ascii(i.title).slice(0, 110), prs: [] }
      e.prs.push({ pr: pr.number, url: pr.url, lane: laneOf(pr.headRefName), state: pr.mergedAt ? 'merged' : pr.state.toLowerCase(), opened: pr.createdAt, merged: pr.mergedAt ?? null })
      byIssue.set(i.number, e)
    }
  }
  const contested = [...byIssue.values()].filter((e) => new Set(e.prs.map((p) => p.lane)).size === 2)
  // The lane whose PR merged first; both may have merged (the second one landing on top).
  for (const e of contested) {
    e.prs.sort((a, b) => Date.parse(a.opened) - Date.parse(b.opened))
    const m = e.prs.filter((p) => p.merged).sort((a, b) => Date.parse(a.merged) - Date.parse(b.merged))[0]
    e.firstMergedBy = m ? m.lane : null
    e.openedFirstBy = e.prs[0].lane
  }
  contested.sort((a, b) => b.issue - a.issue)

  // Open issues both lanes could take.
  const claimed = new Set(opens.flatMap((pr) => pr.closingIssuesReferences.nodes.filter(own).map((i) => i.number)))
  const branches = beeBranches()
  const issues = openIssues()
  const withBoundary = issues.filter((i) => BOUNDARY.test(i.body ?? ''))
  const free = withBoundary.filter((i) => !claimed.has(i.number))
  const rows = free.map((i) => ({
    issue: i.number, url: i.url, title: ascii(i.title).slice(0, 110), opened: i.createdAt,
    beeBranch: branches.has(`queen-${i.number}`),
    labels: i.labels.nodes.map((l) => ascii(l.name)),
  }))
  const untouched = rows.filter((r) => !r.beeBranch)

  const data = {
    snapshotAt, since, days: DAYS, repo: REPO,
    rule: { bee: 'head branch matches ^queen-<N>$', human: 'any other head branch' },
    lanes: { bee: lane('bee'), human: lane('human') },
    landed,
    contested,
    open: {
      total: issues.length,
      withBoundary: withBoundary.length,
      withoutOpenPr: free.length,
      beeBranchExists: rows.length - untouched.length,
      untouched: untouched.length,
      shown: untouched.slice(0, OPEN_SHOWN),
    },
    queenBranchesOnRemote: branches.size,
  }
  mkdirSync(dirname(OUT), { recursive: true })
  writeFileSync(OUT, JSON.stringify(data, null, 1) + '\n')
  const L = data.lanes
  console.log(`race-the-bee: ${snapshotAt}, last ${DAYS} days: bee ${L.bee.merged} merged (median ${L.bee.medianHoursIssueToMerge} h), human ${L.human.merged} (median ${L.human.medianHoursIssueToMerge} h), contested ${contested.length}; open ${issues.length}, boundary ${withBoundary.length}, no PR ${free.length}, untouched ${untouched.length}`)
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main()
