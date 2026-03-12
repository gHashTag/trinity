---
name: agents
description: Agent swarm development dashboard — live Railway containers, issue queue, PR pipeline, JSONL events, pool utilization, and queue drain status. Use when checking agent dev tasks, spawning status, or monitoring issues #315-#319.
argument-hint: [focus] (status, queue, events, pools, spawn <N>, full)
---

# 🤖 Agent Swarm Observatory

## 📡 Railway Service Pools (Live)
!`curl -s -X POST "https://backboard.railway.com/graphql/v2" -H "Authorization: Bearer $(grep RAILWAY_API_TOKEN /Users/playra/trinity-w1/.env | cut -d= -f2)" -H "Content-Type: application/json" -d '{"query":"query($id:String!){project(id:$id){services{edges{node{id name deployments(first:1){edges{node{status createdAt}}}}}}}}","variables":{"id":"aa0efa7f-95e6-4466-8de6-43945a031365"}}' 2>/dev/null | python3 -c "
import sys,json,datetime
d=json.load(sys.stdin)
nodes=[e['node'] for e in d['data']['project']['services']['edges']]
total=len(nodes)
agents=[n for n in nodes if n['name'].startswith('agent-')]
pool0='acfee27a-74e8-4436-961c-698ae93508ca'
pool1='12c2bdf9-d124-4a45-93ad-22921e842d1b'
p0=[n for n in nodes if n['id']==pool0]
p1=[n for n in nodes if n['id']==pool1]
def st(n):
    if n['deployments']['edges']:
        return n['deployments']['edges'][0]['node']['status']
    return 'NO_DEPLOY'
print(json.dumps({
    'total_services': total,
    'pool_0_ubuntu': {'id': pool0[:8], 'status': st(p0[0]) if p0 else 'NOT_FOUND'},
    'pool_1_agents_anywhere': {'id': pool1[:8], 'status': st(p1[0]) if p1 else 'NOT_FOUND'},
    'agent_services': [{'name':n['name'],'status':st(n)} for n in agents],
    'active_building': len([n for n in nodes if st(n) in ('DEPLOYING','BUILDING')]),
    'slots_used': len(agents),
    'slots_free': 10-len(agents)
}, indent=2))
" 2>/dev/null || echo "⚠️ Railway API unavailable"`

## 📋 Agent Issues (agent:spawn + agent:queued)
!`echo "=== SPAWNING ==="; gh issue list --repo gHashTag/trinity --label "agent:spawn" --state open --limit 20 --json number,title,labels,assignees,createdAt --jq '.[] | "#\(.number) \(.title) [\(.labels | map(.name) | join(","))] \(.createdAt[:10])"' 2>&1 || echo "gh unavailable"; echo ""; echo "=== QUEUED ==="; gh issue list --repo gHashTag/trinity --label "agent:queued" --state open --limit 20 --json number,title,createdAt --jq '.[] | "#\(.number) \(.title) \(.createdAt[:10])"' 2>&1 || echo "none"`

## 🔀 Agent PRs (feat/issue- branches)
!`gh pr list --repo gHashTag/trinity --state open --limit 15 --json number,title,headRefName,statusCheckRollup --jq '.[] | select(.headRefName | startswith("feat/issue-")) | "#\(.number) [\(.headRefName)] \(.title) checks:\(.statusCheckRollup | if . then (. | map(.conclusion // .status) | join(",")) else "none" end)"' 2>&1 || echo "No agent PRs"`

## 📡 Recent Events (last 25 lines)
!`if [ -f /Users/playra/trinity-w1/.trinity/cloud_events.jsonl ]; then tail -25 /Users/playra/trinity-w1/.trinity/cloud_events.jsonl | python3 -c "
import sys,json
for line in sys.stdin:
    line=line.strip()
    if not line: continue
    try:
        e=json.loads(line)
        ts=e.get('timestamp','?')[:19]
        typ=e.get('type','?')
        iss=e.get('issue','?')
        msg=e.get('message',e.get('event',''))
        emoji={'spawn':'🚀','kill':'💀','heartbeat':'💓','error':'❌','pr':'🔀','build':'🔨','test':'🧪','complete':'✅','queued':'⏳'}.get(typ,'📌')
        print(f'{ts} {emoji} #{iss} [{typ}] {msg}')
    except: print(line)
" 2>/dev/null; else echo "No cloud events yet"; fi`

## 🔄 GitHub Actions (agent workflows)
!`gh run list --repo gHashTag/trinity --workflow agent-spawn.yml --limit 5 --json databaseId,status,conclusion,createdAt,headBranch --jq '.[] | "\(.createdAt[:16]) \(if .conclusion == "success" then "✅" elif .conclusion == "failure" then "❌" elif .status == "in_progress" then "🔄" else "⏳" end) \(.status)/\(.conclusion // "—") \(.headBranch // "—")"' 2>&1 || echo "No spawn runs"; echo "---"; gh run list --repo gHashTag/trinity --workflow agent-queue-drain.yml --limit 3 --json status,conclusion,createdAt --jq '.[] | "\(.createdAt[:16]) \(if .conclusion == "success" then "✅" else "⏳" end) drain: \(.status)/\(.conclusion // "—")"' 2>&1 || echo "No drain runs"`

## 🏗️ Container Image
!`gh api user/packages/container/trinity-agent/versions --jq '.[0] | "📦 trinity-agent:latest — updated \(.updated_at[:10]) tags: \(.metadata.container.tags | join(","))"' 2>/dev/null || echo "⚠️ GHCR package not accessible"`

## 📊 Local Agent State
!`if [ -f /Users/playra/trinity-w1/.trinity/cloud_agents.json ]; then cat /Users/playra/trinity-w1/.trinity/cloud_agents.json | python3 -c "
import sys,json,datetime
d=json.load(sys.stdin)
agents=d if isinstance(d,list) else d.get('agents',[])
active=[a for a in agents if a.get('active',False)]
inactive=[a for a in agents if not a.get('active',False)]
print(f'Active: {len(active)}/{len(agents)}')
for a in active:
    iss=a.get('issue','?')
    sid=a.get('service_id','?')[:8]
    ts=a.get('created_at','?')
    print(f'  🟢 #{iss} svc:{sid} started:{ts}')
for a in inactive[-3:]:
    iss=a.get('issue','?')
    print(f'  ⚪ #{iss} (done)')
" 2>/dev/null; else echo "No local state file"; fi`

## 🎯 Issue → Pool Mapping (round-robin)
!`echo "Pool 0 (ubuntu/acfee27a): even issues"; echo "Pool 1 (Agents Anywhere/12c2bdf9): odd issues"; echo "---"; gh issue list --repo gHashTag/trinity --label "agent:spawn" --state open --limit 20 --json number,title --jq '.[] | "#\(.number) → Pool \(.number % 2) \(if .number % 2 == 0 then "(ubuntu)" else "(Agents Anywhere)" end) — \(.title[:60])"' 2>&1 || echo "gh unavailable"`

## Task

Analyze the data above and present a **rich Agent Swarm dashboard** with emojis.

Focus area: $ARGUMENTS (default: status)

### Dashboard Format

ALWAYS output the full dashboard — never compress to one line. Use this format:

```
🤖 ═══════════════════════════════════════════════════
   TRINITY AGENT SWARM — DEVELOPMENT OBSERVATORY
   ═══════════════════════════════════════════════════

📡 SERVICE POOLS
   Pool 0 (ubuntu):           [status emoji] [deployment status]
   Pool 1 (Agents Anywhere):  [status emoji] [deployment status]
   Active builds: N | Free slots: N/10

📋 ISSUE QUEUE
   🚀 Spawning:
     #N — title — pool — status
   ⏳ Queued:
     #N — title — waiting since [date]

   Queue depth: N spawning + N queued = N total

🔀 AGENT PRs
   #N — [branch] — title — checks: [status]
   ...
   Open: N | Merged today: N

📡 LIVE EVENTS (last 10)
   [timestamp] [emoji] #issue [type] message
   ...

🔄 GITHUB ACTIONS
   agent-spawn: [last 5 runs with status]
   queue-drain: [last 3 runs with status]

🗺️ POOL MAPPING (round-robin: issue# % 2)
   Pool 0 (even): #316, #318, ...
   Pool 1 (odd):  #315, #317, #319, ...
   ⚠️ Contention: N issues compete for Pool X

📦 INFRASTRUCTURE
   GHCR image: [status + last updated]
   Local state: N active / N total agents
   Events log: N entries

🎯 RECOMMENDATIONS
   [dynamic recommendations based on current state — see rules below]

⏱️ ESTIMATED PIPELINE
   [time estimate for queue drain based on 2 pools × ~1h per agent]
```

### Recommendation Rules

**If both pools DEPLOYING/BUILDING:**
→ "⚠️ Both pools busy. Queue drain runs every 5min. ETA for next slot: ~Xmin"
→ Show which issues are running vs queued

**If 1 pool free:**
→ "🟢 Pool N free — next queued issue #M will auto-spawn via drain"
→ "💡 Manual: `tri cloud spawn <N>` to skip queue"

**If both pools free + queued issues:**
→ "🟢🟢 Both pools idle! Queue drain should trigger in ≤5min"
→ "💡 Manual: add `agent:spawn` label or run `tri cloud spawn <N>`"

**If both pools free + no queued issues:**
→ "✅ All clear. Ready for new agent tasks."
→ Suggest: check `gh issue list --label agent:spawn`

**Contention warnings:**
→ If >2 issues map to same pool: "⚠️ Pool X has N issues queued — sequential processing ~Nh"
→ Suggest rebalancing or manual spawn on other pool

### Queue ETA Calculation
- Each agent takes ~1h (AGENT_TIMEOUT=3600s)
- 2 pools = 2 parallel agents
- Queue ETA = ceil(queued_issues / 2) × 1h
- Show: "⏱️ 5 issues ÷ 2 pools = ~3h total (2+2+1)"

### Issue Status Tracking
For each tracked issue, show:
- 🔵 SPAWNING — container starting
- 🟢 RUNNING — claude code active
- 🟡 SELF-REVIEW — build/test/format
- 🔀 PR CREATED — waiting for review
- ✅ MERGED — done
- ❌ FAILED — needs attention
- ⏳ QUEUED — waiting for pool slot

### If focus=spawn <N>
Trigger: `tri cloud spawn <N>` and show result.

### If focus=events
Show full event log (last 50 lines) with parsed JSONL.

### If focus=pools
Deep dive into Railway API: service details, deployment history, env vars check.
